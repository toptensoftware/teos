DEPPATH=../../../shared-teos
CLEAN = firmware/build FirmwareRom.vhd
OTHERSOURCEFILES = FirmwareRom.vhd
TARGETBOARD = mimasv2

build: firmware build-bit

upload: build upload-bit

FirmwareRom.vhd: ./firmware/build/firmware.bin
	@node $(FPGAKIT)/tools/bin2vhdlrom/bin2vhdlrom \
		--bigendian \
		--dataWidth:16 \
		--addrWidth:10 \
		./firmware/build/firmware.bin \
		FirmwareRom.vhd

.PHONY: firmware

firmware:
	@cd firmware; $(MAKE) --no-print-directory 


# Make script
include ../../../../fpgakit/fpgakit.mk
