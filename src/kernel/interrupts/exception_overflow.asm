; vim: set ts=8 sw=8 sts=8 noexpandtab nowrap:
;------------------------------------------------------------------------------
; Overflow exception
;
exception_overflow:
	mov rdi,000b8F00h			; Display our data in the bottom right of the screen
	mov eax,40344030h			; Display 'DE' with red background, black writing
	mov [rdi],eax				; Move our text onto the display
	;iret
	jmp halt				; Halt the system

