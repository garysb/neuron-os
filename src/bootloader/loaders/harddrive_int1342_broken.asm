; Hard drive loader
mov ax,1000h									; Update segment registers
mov ds,ax										;
mov es,ax										;

; jump to our main execution
jmp 0x1000:harddrive

; String variables
hextable			db '0123456789ABCDEF'
msg_hardrive		db 'Checking hardive', 13, 10, 0
msg_drive			db 'Getting drive info', 13, 10, 0
msg_extensions		db 'Check for extensions', 13, 10, 0
msg_haveextensions	db 'Extensions enabled', 13, 10, 0
msg_noextensions	db 'No extension support', 13, 10, 0
msg_read			db 'Error reading drive', 13, 10, 0
msg_reboot			db 'Press any key to reboot', 13, 10, 0
msg_jump			db 'Jumping to kernel', 13, 10, 0
msg_reading			db 'Reading drive', 13, 10, 0

; Data obtained from int 13h 08h
boot_drive			db 80h						; The drive to boot from
drive_partition		db 0						; The drive partition
drive_extensions	db 0						; Boolean of if extensions are enabled
drive_lsr			resb 1						; LBA sectors read

; Data obtained from int 13h 48h
drive_cylinders		resw 2						; Cylinders per drive
drive_heads			resw 2						; The number of heads on the drive
drive_spt			resw 2						; Sectors per track
drive_sectors		resw 4						; Total sectors on drive (used to hold spt)
drive_bytes			resw 1						; The number of bytes per sector

; Setup the DAP (Disk Address Packet)
dap:
					db 10h						; 00h      - 1 byte  - size of DAP = 16 = 10h
					db 0						; 01h      - 1 byte  - unused, should be zero
					dw 0						; 02h..03h - 2 bytes - number of sectors to read 0..127 (=007Fh)
					dd 0						; 04h..07h - 4 bytes - transfer buffer
					dq 0						; 08h..0Fh - 8 bytes - start sector (1st sector of drive is number 0)
					dq 0						; 10h..18h - 8 bytes - only used if 0hh (transfer buffer) is FFFFh:FFFFh

; Our main execution stack
harddrive:
	; Display a message
	mov si,msg_hardrive							; Set source index to msg_harddrive
	call print_string							; Call the print procedure

	; Get information about the drive
	call check_extensions						; Check if we have interrupt extensions
	call drive_details							; Get the hardware details of the drive

	; Setup our DAP then read sectors
	mov [dap+3],WORD 1							; Set the quantity of sectors to read
	mov [dap+4],DWORD 6000h						; Set storage buffer [6000:8000]
	mov [dap+15],WORD 1							; Set the start sector
	call read_sectors							; Read the sectors into memory

	mov si,msg_jump								; Set source index to msg_jump
	call print_string							; Call the print procedure

	;jmp 6000h:0									; Jump to the segment where the kernel sits
	jmp reboot
	;jmp ext2									; Start checking fat32 filesystem

; Check if this computer supports extended drive interrupts
check_extensions:
	mov ah,0x41									; AH = 41h
	mov bx,0x55aa								; BX = 55AAh
	mov dl,[boot_drive]							; DL = drive (80h-FFh)
	int 13h										; IBM/MS INT 13 Extensions - INSTALLATION CHECK
	jc error_extensions							; No extension support, report an error

	; Check if int13h 41h set bx to aa55h, if so, extensions installed
	cmp bx,0xaa55								; BX = AA55h if installed
	jne error_extensions						; Extension not installed, report an error

	; Check the extension type, we want bit 0 for AH=42h-44h,47h,48h support
	test cl,1									; Test cl's first bit for a value
	jz error_extensions							; Wrong extension type, report an error

	; Save the result and return to caller
	mov BYTE [drive_extensions], 1				; Drive extensions enabled from now on
	mov si,msg_haveextensions					; Set source index to msg_haveextensions
	call print_string							; Call the show procedure
	ret											; Return to caller

; Fetch the hard drive parameters from the bios
drive_details:
	; Display a message
	mov si,msg_drive							; Set source index to msg_drive
	call print_string							; Call the print procedure

	; Call the extended interrupt
	mov ah,48h									; int13 48h, get drive parameters
	mov dl,[boot_drive]							; Get boot drive in dl
	int 13h										; Request drive parameters from the bios
	jc error_read								; We couldnt get drive details

	; Read our results into memory
	mov eax,DWORD [si+04h]						; Copy cylinder count to eax
	mov [drive_cylinders],eax					; Copy the cylinder count into memory
	mov eax,DWORD [si+08h]						; Copy head count to eax
	mov [drive_heads],eax						; Copy the head count into memory
	mov eax,DWORD [si+0Ch]						; Copy sectors per track to eax
	mov [drive_spt],eax							; Copy the sectors per track into memory
	mov eax,DWORD [si+10h]						; Copy total sectors to eax
	mov [drive_sectors],eax						; Copy the sectors into memory
	mov eax,DWORD [si+12h]						; Copy total sectors to eax
	mov [drive_sectors+02h],eax					; Copy the sectors into memory
	mov ax,WORD [si+10h]						; Copy byte size per sector to eax
	mov [drive_bytes],ax						; Copy byte size per sector into memory

	ret											; Return to the caller

; Read sectors using extended read (using int 13h ah=42h)
read_sectors:
	; Display a message
	mov si,msg_reading							; Set source index to msg_read
	call print_string							; Call the print procedure
	mov si,dap									; Point to our Disk Address Packet
	mov dl,[boot_drive]							; Set the boot drive
	mov ah,42h									; Int 13h, AH = 42h - Extended Read

; 	; Debug dap
; 	mov dl,[dap]
; 	call print_hex
; 	mov dl,[dap+1]
; 	call print_hex
; 	mov dl,[dap+2]
; 	call print_hex
; 	mov dl,[dap+3]
; 	call print_hex
; 	mov dl,[dap+4]
; 	call print_hex
; 	mov dl,[dap+5]
; 	call print_hex
; 	mov dl,[dap+6]
; 	call print_hex
; 	mov dl,[dap+7]
; 	call print_hex
; 	mov dl,[dap+8]
; 	call print_hex
; 	mov dl,[dap+9]
; 	call print_hex
; 	mov dl,[dap+0ah]
; 	call print_hex
; 	mov dl,[dap+0bh]
; 	call print_hex
; 	mov dl,[dap+0ch]
; 	call print_hex
; 	mov dl,[dap+0dh]
; 	call print_hex
; 	mov dl,[dap+0eh]
; 	call print_hex
; 	mov dl,[dap+0fh]
; 	call print_hex

	int 13h										; Call BIOS
	;jc error_read								; If the read failed then abort
	mov dl,ah									; Copy the status into dl
	call print_hex								; Display the read result
	ret											; Return to caller

;-------------------------------------------------------------------------------
; UTILITY FUNCTIONS
;-------------------------------------------------------------------------------
; Print a message on the display
print_string:
	mov bx,1									; BH=0, BL=1 (blue)
	cld											; Clear read direction
	lodsb										; Load the next character
	or al,al									; Test for a NUL character
	jz short print_done							; We found a null char, return to caller
	mov ah,0x0E									; BIOS teletype
	mov bh,0x00									; display page 0
	mov bl,0x07									; text attribute
	int 0x10									; invoke BIOS
	jmp short print_string
print_done:
	ret

; Print ASCII character
print_char:
	pushad										; Save the registers
	mov bx,1									; BH=0, BL=1 (blue)
	mov ah,0x0e									; BIOS teletype
	int 0x10									; Invoke BIOS
	popad										; Restore registers
	ret											; Return to caller

; Print out a hex value
print_hex:
	; Load the table location into bx
	lea bx,[hextable]							; Load the address of the hextable

	; Display the first hex value
	mov al,dl									; Load the hex value
	shr al,4									; Leave high part only
	xlat										; Get hex digit
	mov ah,0eh									; teletype sub-function
	int 10h										; Call the interrupt

	; Display the second hex value
	mov al,dl
	and al,0fh									; Leave low part only
	xlat										; Get hex digit
	mov ah,0eh									; Teletype sub-function
	int 10h										; Call the interrupt

	ret											; Return to caller

;-------------------------------------------------------------------------------
; ERROR MESSAGES
;-------------------------------------------------------------------------------
; Wait for a keypress, then reboot
reboot:
	; Call the reboot interrupt
	xor ax,ax									; Clear out ax
	int 16h										; Wait for a keypress
	int 19h										; Reboot

; Misc error occured
error_reboot:
	; Display the standard reboot message
	mov si,msg_reboot							; Set source index to msg_reboot
	call print_string							; Call the show procedure
	jmp short reboot							; Jump to reboot

; Error while reading drive
error_read:
	; Display the unable to read message
	mov si,msg_read								; Set source index to msg_read
	call print_string							; Call the show procedure
	jmp short reboot							; Jump to reboot

; No extension support
error_extensions:
	; Display the no extensions support message
	mov si,msg_noextensions						; Set source index to msg_noextensions
	call print_string							; Call the show procedure
	jmp short reboot							; Jump to reboot

; Load the filesystem reader
;%include "src/bootloader/filesystems/ext2.asm"
