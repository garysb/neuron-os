; vim: set ts=8 sw=8 sts=8 noexpandtab nowrap:
;------------------------------------------------------------------------------
; Default exception called when we enter an unknown exception
;
exception_default:
	mov rdi,000b8F9Ch			; Display our data in the bottom right of the screen
	mov eax,40454044h			; Display 'DE' with red background, black writing
	mov [rdi],eax				; Move our text onto the display
	;iret
	jmp halt				; Halt the system

