; vim: set ts=8 sw=8 sts=8 noexpandtab nowrap:
BITS 64						; Set the operand size to 64 bits
CPU x64						; Set the cpu to 586 mode (minimum for rdmsr & wrmsr)
DEFAULT ABS					; Set relation to absolute instead of RIP relative

SECTION .bss ;vstart=0x100000
;------------------------------------------------------------------------------
; Reserve our interrupt descriptor table space. (4KB in size)
;
IDT:
	resb 16*256
IDT_end:

SECTION .data ;vstart=0x150000
;------------------------------------------------------------------------------
; Create the interrupt descriptor table register values [IDT]limit
;
IDT_pointer:
	dw IDT_end - IDT - 1
	dq IDT
SECTION .text
;------------------------------------------------------------------------------
; Tell nasm that the entry memory location is set to 7C00. This is the default
; location that "most" BIOS's copy the first sector off the boot drive (held in
; the DL register). We then set the default operand size to 16 bits and jump
; to our starting code. The jump is done to ensure that the BIOS's that use a
; sector of 07C0 instead of 0h dont cause problems.
;
IDT_init:
	; Create a descriptor for our default exception handler
	mov rax,exception_default		; Store the location of default_exception
	mov ax,8E00h				; Set the present bit to 1, and type to 1110
	shl rax,16				; Shift the top two data blocks into place
	mov ax,cs				; Set the code segment
	shl rax,16				; Move the code segment into place
	mov rbx,exception_default		; Store the default_exception into rbx
	mov ax,bx				; Copy the 0-15 of default_exception into place
	shr rbx,32				; Move the top half of default_exception into place
	mov rdi,IDT				; Store the address in RDI
	mov ecx,32				; Set the default interrupts (32 of them)

; Loop through the first 32 interrupts and add the default exception handler
.IDT_exceptions:
	mov [rdi],rax				; Copy the bottom half of the idt into position
	mov [rdi+8],rbx				; Copy the top half into position
	add rdi,16				; Increase pointer position to the next interrupt vector
	loop .IDT_exceptions			; If this isnt the last interrupt, loop to add another

	; Create a descriptor for our default interrupt handler
	mov rax,interrupt_default		; Store the location of default_exception
	mov ax,8E00h				; Set the present bit to 1, and type to 1110
	shl rax,16				; Shift the top two data blocks into place
	mov ax,cs				; Set the code segment
	shl rax,16				; Move the code segment into place
	mov rbx,interrupt_default		; Store the default_exception into rbx
	mov ax,bx				; Copy the 0-15 of default_exception into place
	shr rbx,32				; Move the top half of default_exception into place
	mov ecx,224				; Set the default interrupts (224 of them)

; Loop through the remaining interrupts and add the default interrupt handler
.IDT_interrupts:
	mov [rdi],rax				; Copy the bottom half of the idt into position
	mov [rdi+8],rbx				; Copy the top half into position
	add rdi,16				; Increase pointer position to the next interrupt vector
	loop .IDT_interrupts			; If this isnt the last interrupt, loop to add another

; ; Divide by zero interrupt
; 	; Create a descriptor for our default exception handler
; 	mov rax,exception_dividebyzero		; Store the location of default_exception
; 	mov ax,8E00h				; Set the present bit to 1, and type to 1110
; 	shl rax,16				; Shift the top two data blocks into place
; 	mov ax,cs				; Set the code segment
; 	shl rax,16				; Move the code segment into place
; 	mov rbx,exception_dividebyzero		; Store the default_exception into rbx
; 	mov ax,bx				; Copy the 0-15 of default_exception into place
; 	shr rbx,32				; Move the top half of default_exception into place
; 	mov rdi,IDT				; Store the address in RDI
; 	mov [rdi],rax				; Copy the bottom half of the idt into position
; 	mov [rdi+8],rbx				; Copy the top half into position

; ; Debug Exception interrupt
; 	; Create a descriptor for our default exception handler
; 	mov rax,exception_debug			; Store the location of default_exception
; 	mov ax,8E00h				; Set the present bit to 1, and type to 1110
; 	shl rax,16				; Shift the top two data blocks into place
; 	mov ax,cs				; Set the code segment
; 	shl rax,16				; Move the code segment into place
; 	mov rbx,exception_debug			; Store the default_exception into rbx
; 	mov ax,bx				; Copy the 0-15 of default_exception into place
; 	shr rbx,32				; Move the top half of default_exception into place
; 	mov rdi,IDT				; Store the address in RDI
; 	mov [rdi+16],rax			; Copy the bottom half of the idt into position
; 	mov [rdi+24],rbx			; Copy the top half into position

; ; NMI (Non-Maskable-Interrupt) exception
; 	; Create a descriptor for our default exception handler
; 	mov rax,exception_nmi			; Store the location of default_exception
; 	mov ax,8E00h				; Set the present bit to 1, and type to 1110
; 	shl rax,16				; Shift the top two data blocks into place
; 	mov ax,cs				; Set the code segment
; 	shl rax,16				; Move the code segment into place
; 	mov rbx,exception_nmi			; Store the default_exception into rbx
; 	mov ax,bx				; Copy the 0-15 of default_exception into place
; 	shr rbx,32				; Move the top half of default_exception into place
; 	mov rdi,IDT				; Store the address in RDI
; 	mov [rdi+32],rax			; Copy the bottom half of the idt into position
; 	mov [rdi+40],rbx			; Copy the top half into position

; ; BP (Breakpoint) exception
; 	; Create a descriptor for our default exception handler
; 	mov rax,exception_bp			; Store the location of default_exception
; 	mov ax,8E00h				; Set the present bit to 1, and type to 1110
; 	shl rax,16				; Shift the top two data blocks into place
; 	mov ax,cs				; Set the code segment
; 	shl rax,16				; Move the code segment into place
; 	mov rbx,exception_bp			; Store the default_exception into rbx
; 	mov ax,bx				; Copy the 0-15 of default_exception into place
; 	shr rbx,32				; Move the top half of default_exception into place
; 	mov rdi,IDT				; Store the address in RDI
; 	mov [rdi+48],rax			; Copy the bottom half of the idt into position
; 	mov [rdi+56],rbx			; Copy the top half into position

; ; Overflow exception
; 	; Create a descriptor for our default exception handler
; 	mov rax,exception_overflow		; Store the location of default_exception
; 	mov ax,8E00h				; Set the present bit to 1, and type to 1110
; 	shl rax,16				; Shift the top two data blocks into place
; 	mov ax,cs				; Set the code segment
; 	shl rax,16				; Move the code segment into place
; 	mov rbx,exception_overflow		; Store the default_exception into rbx
; 	mov ax,bx				; Copy the 0-15 of default_exception into place
; 	shr rbx,32				; Move the top half of default_exception into place
; 	mov rdi,IDT				; Store the address in RDI
; 	mov [rdi+64],rax			; Copy the bottom half of the idt into position
; 	mov [rdi+72],rbx			; Copy the top half into position
; 
; ; Invalid opcode exception
; 	; Create a descriptor for our default exception handler
; 	mov rax,exception_opcode		; Store the location of default_exception
; 	mov ax,8E00h				; Set the present bit to 1, and type to 1110
; 	shl rax,16				; Shift the top two data blocks into place
; 	mov ax,cs				; Set the code segment
; 	shl rax,16				; Move the code segment into place
; 	mov rbx,exception_opcode		; Store the default_exception into rbx
; 	mov ax,bx				; Copy the 0-15 of default_exception into place
; 	shr rbx,32				; Move the top half of default_exception into place
; 	mov rdi,IDT				; Store the address in RDI
; 	mov [rdi+96],rax			; Copy the bottom half of the idt into position
; 	mov [rdi+104],rbx			; Copy the top half into position
; 	xor rax,rax

; The interrupt descriptor table should now be ready, so we load it and enable it
.IDT_activate:
	lidt [IDT_pointer]			; Set the IDTR register
	sti					; Enable IRQs (should all be masked in interrupt controller anyway)
	ret					; Return to caller

;------------------------------------------------------------------------------
; Include our diferent interrupt actions
;
%include "src/kernel/interrupts/exception_default.asm"
%include "src/kernel/interrupts/interrupt_default.asm"

%include "src/kernel/interrupts/exception_dividebyzero.asm"
%include "src/kernel/interrupts/exception_debug.asm"
%include "src/kernel/interrupts/exception_nmi.asm"
%include "src/kernel/interrupts/exception_bp.asm"
%include "src/kernel/interrupts/exception_overflow.asm"
%include "src/kernel/interrupts/exception_opcode.asm"

