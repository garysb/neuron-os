; vim: set ts=4 sw=4 nowrap:

[MAP SECTIONS kernel.map]						; Generate a segment map file for us
ORG 0000000000007E00h							; Set the segment offset to 07C0
BITS 64											; Set the operand size to 64 bits
CPU x64											; Set the cpu to 586 mode (minimum for rdmsr & wrmsr)
DEFAULT ABS										; Set relation to absolute instead of RIP relative

SECTION .text
;------------------------------------------------------------------------------
; Start of our 64bit code and our kernel
;
startLongMode:
	cli												;Interupts are disabled because no IDT has been set up

;------------------------------------------------------------------------------
; Clear the screen by setting all the data to zeros in B800
;
; clear_screen:
; 	mov rdi,00000000000b8000h					; Start of text frame buffer
; 	mov cx,500									; Loop 500 times (80rows*25cols*2bytes/8bytes)
; 	xor rax,rax									; Clear rax
; .clear_char
; 	mov [rdi],rax								; Clear a 64bit set of chars
; 	add rdi,8									; Increase to the next block
; 	loop .clear_char

	call IDT_init

	; Generate an interrupt
	int 40h

	; Divide by zero error (0)
	;xor eax,eax
	;xor ebx,ebx
	;div ebx

; 	mov edi,000b8000h								;Display:Put long mode kernel here.
; 	mov rax,0x0767076e076f076c
; 	mov [edi+8],rax
;	mov rax,0x0764076f076d0720
;	mov [edi+16],rax
;	mov rax,0x0765076b07200765
;	mov [edi+24],rax
;	mov rax,0x076c0765076e0772
;	mov [edi+32],rax
;	mov rax,0x0772076507680720
;	mov [edi+40],rax
;	mov rax,0x07200720072e0765
;	mov [edi+48],rax
	hlt											; Halt the system

%include "src/kernel/utilities.asm"
%include "src/kernel/interrupts.asm"
