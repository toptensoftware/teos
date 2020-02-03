library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.all;
library unisim;
use unisim.vcomponents.all;

entity top is
port 
(
	i_clock_100mhz_unbuffered : in std_logic;
	i_button_b : in std_logic;
	o_leds : out std_logic_vector(7 downto 0);
	o_seven_segment : out std_logic_vector(7 downto 0);
	o_seven_segment_en : out std_logic_vector(2 downto 0);
	o_uart_tx : out std_logic
);
end top;

architecture behavior of top is

	-- Clocking
    signal s_reset : std_logic;
	signal s_cpu_reset_n : std_logic;
	signal s_clock_100mhz : std_logic;
	signal s_clock_80mhz : std_logic;
	signal s_clken_cpu : std_logic;

	-- ROM
	signal s_is_rom_range : std_logic;
	signal s_rom_addr : std_logic_vector(9 downto 0);
	signal s_rom_dout : std_logic_vector(15 downto 0);

	-- RAM
	signal s_is_ram_range : std_logic;
	signal s_ram_addr : std_logic_vector(12 downto 0);
	signal s_ram_din : std_logic_vector(15 downto 0);
	signal s_ram_dout : std_logic_vector(15 downto 0);
	signal s_ram_wr : std_logic;
	signal s_ram_wr_mask : std_logic_vector(1 downto 0);

	-- IO
	signal s_is_io_range : std_logic;
	signal s_io_addr : std_logic_vector(3 downto 0);
	signal s_io_din : std_logic_vector(15 downto 0);
	signal s_io_dout : std_logic_vector(15 downto 0);
	signal s_io_wr : std_logic;
	signal s_io_wr_mask : std_logic_vector(1 downto 0);

	-- CPU
	signal s_cpu_wr : std_logic;
	signal s_cpu_rd : std_logic;
	signal s_cpu_wr_mask : std_logic_vector(1 downto 0);
	signal s_cpu_wait : std_logic;
    signal s_cpu_addr : std_logic_vector(31 downto 0);
    signal s_cpu_dout : std_logic_vector(15 downto 0);
    signal s_cpu_din : std_logic_vector(15 downto 0);

	constant c_big_endian : std_logic := '1';

	signal s_leds : std_logic_vector(7 downto 0);

begin

	-- Reset signal
	s_reset <= '1' when i_button_b = '0' else '0';

	-- Clock Buffer
    clk_ibufg : IBUFG
    port map
    (
		I => i_clock_100mhz_unbuffered,
		O => s_clock_100mhz
	);

	-- Digital Clock Manager
	dcm : entity work.ClockDCM
	port map
	(
		CLK_IN_100MHz => s_clock_100mhz,
		CLK_OUT_100MHz => open,
		CLK_OUT_80MHz => s_clock_80mhz
	);

	-- 40Mhz clock divider
	clock_div_cpu : entity work.ClockDivider
	generic map
	(
		p_period => 2
	)
	port map
	(
		i_clock => s_clock_80mhz,
		i_clken => '1',
		i_reset => s_reset,
		o_clken => s_clken_cpu
	);


	rom : entity work.FirmwareRom
	port map
	(
		i_clock => s_clock_80mhz,
		i_addr => s_rom_addr,
		o_dout => s_rom_dout
	);

	ram : entity work.RamInferred
	generic map
	(
		p_addr_width => 13,			-- 2^13 = 8192 words = 16K
		p_data_width => 16
	)
	port map
	(
		i_clock => s_clock_80mhz,
		i_clken => s_clken_cpu,
		i_addr => s_ram_addr,
		i_data => s_ram_din,
		o_data => s_ram_dout,
		i_write => s_ram_wr,
		i_write_mask => s_ram_wr_mask
	);

	-- ROM Addressing
	s_is_rom_range <= '1' when s_cpu_addr(31 downto 16) = x"0010" else '0';
	s_rom_addr <= s_cpu_addr(10 downto 1);
	
	-- RAM Addressing
	s_is_ram_range <= '1' when s_cpu_addr(31 downto 16) = x"0020" else '0';
	s_ram_addr <= s_cpu_addr(13 downto 1);
	s_ram_din <= s_cpu_dout;
	s_ram_wr <= s_cpu_wr and s_is_ram_range;

	be_mask : if c_big_endian = '1' generate
		s_ram_wr_mask <= s_cpu_wr_mask(0) & s_cpu_wr_mask(1);
	end generate;

	le_mask : if c_big_endian = '0' generate
		s_ram_wr_mask <= s_cpu_wr_mask;
	end generate;

	-- IO Addressing
	s_is_io_range <= '1' when s_cpu_addr(31 downto 16) = x"8000" else '0';
	s_io_addr <= s_cpu_addr(3 downto 0);
	s_io_din <= s_cpu_dout;
	s_io_wr <= s_cpu_wr and s_is_io_range;
	s_io_wr_mask <= s_cpu_wr_mask;

	-- Multiplex CPU input
	s_cpu_wait <= '0';
	s_cpu_din <= 
		s_rom_dout when s_is_rom_range = '1' else
		s_ram_dout when s_is_ram_range = '1' else
		s_io_dout when s_is_io_range = '1' else
		(others => '1');

	-- CPU
	cpu : entity work.moxielite
	generic map
	(
		p_boot_address => x"00100000",
		p_big_endian => c_big_endian
	)
	port map
	(
		i_reset => s_reset,
		i_clock => s_clock_80mhz,
		i_clken => s_clken_cpu,
		i_wait => s_cpu_wait,
		o_addr => s_cpu_addr,
		i_din => s_cpu_din,
		o_dout => s_cpu_dout,
		o_rd => s_cpu_rd,
		o_wr => s_cpu_wr,
		o_wr_mask => s_cpu_wr_mask,
		o_debug => open,
		i_gdb => (others => '0'),
		i_irq => '0',
		i_buserr => '0'
	);


	io : process(s_clock_80mhz)
	begin
		if rising_edge(s_clock_80mhz) then
			if s_reset = '1' then
			
				s_leds <= (others => '0');

			elsif s_clken_cpu = '1' then

				if s_io_wr = '1' then

					if s_io_addr=x"0" then
						s_leds <= s_io_din(7 downto 0);
					end if;

				end if;

			end if;
		end if;
	end process;

	s_io_dout <= 
		s_leds & s_leds when s_io_addr = x"0" 
		else x"FFFF";

	o_leds <= s_leds;
	o_seven_segment <= (others => '1');
	o_seven_segment_en <= (others => '1');
	o_uart_tx <= '1';

end behavior;

