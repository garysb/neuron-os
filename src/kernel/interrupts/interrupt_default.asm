;------------------------------------------------------------------------------
; Default interrupt called when we enter an unknown interrupt
;
interrupt_default:
	mov rdi,000b8F98h							; Display our data in the bottom right of the screen
	mov eax,20492044h							; Display 'DI' with green background, black writing
	mov [rdi],eax								; Move our text onto the display
	iretq										; Return from our interrupt
