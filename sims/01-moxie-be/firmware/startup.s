	.text
	.p2align	1
	.global	_start

_start:
	ldi.l	$sp,__ram_top

	ldi.l   $r0,__data_start
	ldi.l	$r1,0x12345678
	st.l    ($r0),$r1

	ldo.b	$r1, 0($r0)
	ldo.b	$r2, 1($r0)
	ldo.b	$r3, 2($r0)
	ldo.b	$r4, 3($r0)
	sto.b   0($r0),$r1
	sto.b   1($r0),$r2
	sto.b   2($r0),$r3
	sto.b   3($r0),$r4

	ldo.l   $r1, 0($r0);
	
_loop:
	jmpa     _loop

