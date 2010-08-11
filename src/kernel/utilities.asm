; vim: set ts=8 sw=8 sts=8 noexpandtab nowrap:
BITS 64						; Set the operand size to 64 bits
CPU x64						; Set the cpu to 586 mode (minimum for rdmsr & wrmsr)
DEFAULT ABS					; Set relation to absolute instead of RIP relative

SECTION .data

SECTION .text
halt:
	hlt

