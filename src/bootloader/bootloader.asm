; vim: set ts=4 sw=4 nowrap:

;------------------------------------------------------------------------------
; Tell nasm that the entry memory location is set to 7C00. This is the default
; location that "most" BIOS's copy the first sector off the boot drive (held in
; the DL register). We then set the default operand size to 16 bits and set the
; cpu type to use.
;
[MAP SECTIONS bootloader.map]					; Generate a segment map file for us
ORG 00007C00h									; Set the segment offset to 07C0
BITS 16											; Set the operand size to 16 bits
CPU 586											; Set the cpu to 586 mode (minimum for rdmsr & wrmsr)

SECTION .data									; The following section contains user data
;------------------------------------------------------------------------------
; Messages presented to the user (.data)
;  In order to get the strings to display nicely on their own lines, we add the
;  0Dh (Carriage return) and 0Ah (New line) hex values onto the end of all of
;  the strings. We then null terminate the string (00h) to inform the print
;  function that the string has ended.
;
msg_diskerr		db 'Read error', 0Dh, 0Ah, 00h
msg_reboot		db 'Press key', 0Dh, 0Ah, 00h
boot_drive		resb 1							; Boot drive from BIOS in DL register

;------------------------------------------------------------------------------
;Global Descriptor Table
;
gdt:
dq 0x0000000000000000							;Null Descriptor

.code equ $ - gdt
dq 0x0020980000000000

.data equ $ - gdt
dq 0x0000900000000000

.pointer:
	dw $-gdt-1									;16-bit Size (Limit)
	dq gdt										;64-bit Base Address
												;Changed from "dd gdt"
												;Ref: Intel System Programming Manual V1 - 2.1.1.1

SECTION .bss
;------------------------------------------------------------------------------
; Data obtained from int 13h 48h (.bss)
;
drive_lsr			resb 1						; LBA sectors read
drive_cylinders		resd 1						; Cylinders per drive (start 0)
drive_heads			resd 1						; The number of heads on the drive (start 0)
drive_spt			resd 1						; Sectors per track (start 1)
drive_sectors		resq 1						; Total sectors on drive (heads*cylinders*sectors)
drive_bytes			resw 1						; The number of bytes per sector (normally 512 bytes)

;------------------------------------------------------------------------------
; Main code execution stack. Jumped to from the first instruction located in
; the memory position 0x7C00.
;
SECTION .text									; Code/text section starts here
boot_loader:
	; Sanitize our registers to avoid any random errors
	mov [boot_drive],dl							;Save boot drive provided by bios
	cli											; Disable interrupts
	xor bx,bx									; Clear BX
	mov es,bx									; Clear ES
	mov fs,bx									; Clear FS
	mov gs,bx									; Clear GS
	mov ds,bx									; Set data segment to 0h
	mov ss,bx									; Set stack segment to 0h
	mov sp,7B00h								; Set the stack to run down from 7b00h
	sti											; Re-enable interrupts

jmp 0:.run										; Clear the code segment
.run:											; by jumping here

;------------------------------------------------------------------------------
; Read drive parameters from the bios interrupt 13h using the extended call to
; function 48h. This returns details on the CHS values and sector byte size
; information. FIXME: Should check int 13h 41h first to check for extensions.
;
; Sets:
;	[drive_cylinders]							- Drive cylinder count starting from zero
;	[drive_heads]								- Drive heads count starting from zero
;	[drive_spt]									- Drive sectors per track starting from one
;	[drive_sectors]								- Drive total sectors starting from one
;	[drive_bytes]								- Drive sector size in bytes
;
drive_details:
	; Call the extended interrupt
	xor eax,eax									; Clear EAX (starts with AA55h)
	mov ah,48h									; int13 48h, get drive parameters
	mov dl,[boot_drive]							; Get boot drive in dl
	int 13h										; Request drive parameters from the bios
	jc error_reboot								; We couldnt get drive details

	; Read our results into memory
	; FIXME: This needs to be remade to probably use movsw
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
	mov ax,WORD [si+18h]						; Copy byte size per sector to eax
	mov [drive_bytes],ax						; Copy byte size per sector into memory

;------------------------------------------------------------------------------
; Read the kernel into memory starting at the segment offset 7E00h. This leaves
; exactly 512 bytes for this bootloader to be stored into memory. In order for
; this to work, we need to have populated the details about the drive we are
; booting from. We then call read_sectors to copy the data off the drive into
; our memory location.
;
read_kernel:
	mov bx,7E00h								; Set the read buffer offset 7E00h
	mov ax,0h									; Set the read buffer segment to 0h
	mov es,ax									; Commit the read buffer segment
	mov cx,03h									; Number of sectors to read
	mov eax,10									; LBA starting sector to read
	call read_sectors							; Read the data into memory

;------------------------------------------------------------------------------
; Enable the A20 gate using the fast port method (port 92h). We do this to let
; the bootloader load a 2MB page at the start of memory so we can access the
; first 2MBs of memory as if paging was disabled. NOTE: This isnt going to work
; on all systems, but I am not going to speak to the keyboard controller and
; tell it to enable the A20 gate. We might look into using int 15h though.
;
enable_a20:
	in al,92h									; Set port number to 92h
	or al,02h									; Enable the A20 bit
	out 92h,al									; Write the changes out to port 92h

;------------------------------------------------------------------------------
; Build the page table as we need to have paging enabled in order to jump to
; our kernel in 64bit mode. The page table builds a 4 layer translation table
; with one 2MB segment starting a offset 0h. We only need this to access the
; kernel with our far jump.
;
; Layout:	FIXME: CHECK U/S BIT 3rd bit is currently open to all. Refer: p135 Vol.2 AMD64
;	PML4:	dq 0x00000000_0000b00f
;			times 511 dq 0x00000000_00000000
;	PDP:	dq 0x00000000_0000c00f
;			times 511 dq 0x00000000_00000000
;	PD:		dq 0x00000000_0000018f
;			times 511 dq 0x00000000_00000000
;
build_pagetable:
	; Page Map Level-4
	xor bx,bx									; Clear BX to set ES to segment 0h
	mov es,bx									; Copy BX (0h) into ES
	cld											; Clear the direction flag
	mov di,0xa000								; Set the offset to 0xA000 (40960)
	mov ax,0xb00f								; Refer to PML4E in p135 Vol.2 AMD64
	stosw										; Store PMLE4 at [ES:DI]
	xor ax,ax									; Clear ax
	mov cx,0x07ff								; Set counter to 2044
	rep stosw									; Store 4094 bytes of null

	; Page Directory Pointer
	mov ax,0xc00f								; Refer to PDPE in p135 Vol.2 AMD64
	stosw										; Store PDPE at [ES:DI]
	xor ax,ax									; Clear ax
	mov cx,0x07ff								; Set counter to 2044
	rep stosw									; Store 4094 bytes of null

	; Page Directory
	mov ax,0x018f								; Refer to PDE in p135 Vol.2 AMD64
	stosw										; Store PDE at [ES:DI]
	xor ax,ax									; Clear ax
	mov cx,0x07ff								; Set counter to 2044
	rep stosw									; Store 4094 bytes of null

;------------------------------------------------------------------------------
; We enter long mode by enabling PAE (Physical-address extensions and also
; enable the Page-Global Enable flag. Once these are enabled, set the address
; of our PML-4 within the CR3 register and set the EFER. We are now ready to
; enable long-mode. Next we activate long-mode by enabling paging and our
; protection simultaneously. Next, we load the Global Descriptor Table and
; execute a long jump to populate the CS register and flush the cache.
;
start_longmode:
	mov eax,10100000b							;Set PAE and PGE
	mov cr4,eax
	mov edx, 0x0000a000							;Point CR3 at PML4
	mov cr3,edx
	mov ecx,0xC0000080							;Specify EFER MSR
	rdmsr										;Enable Long Mode
	or eax,0x00000100
	wrmsr
	mov ebx,cr0									;Activate long mode
	or ebx,0x80000001							;by enabling paging and protection simultaneously
	mov cr0,ebx									;skipping protected mode entirely
	lgdt [gdt.pointer]							;load 80-bit gdt.pointer below
	jmp gdt.code:7E00h							;Load CS with 64 bit segment and flush the instruction cache

;------------------------------------------------------------------------------
; Read segments of data from the boot drive and store it into memory within the
; memory location pointed to by [ES:BX]. FIXME: We should migrate this code to
; use int 13h function 42h to read using LBA mode instead of just imitating it.
;
; Arguments:
;	DI = Retry loop counter						- This decreases every error
;	[ES:BX] = segment:offset					- Output buffer (memory location)
;	CX = sector count							- Number of sectors to read
;	EAX = starting sector						- Sector to start reading from
;
; Sets:
;	[ES:BX]										- Populates memory with sectors
;
read_sectors:
	pushad										; Push registers onto the stack
	xor edx,edx									; Clear edx
	mov ecx,DWORD [BYTE drive_spt]				; Put spt into ecx
	div ecx										; Divide logical by sectors per track
	inc dl										; Sectors numbering starts at 1 not 0
	mov cl,dl									; Sector in CL
	mov edx,eax									; Move track sector to edx
	shr edx,16									; Shift the track sector
	div WORD [BYTE drive_heads]					; Divide logical by number of heads
	mov dh,dl									; Head in DH
	mov dl,[boot_drive]							; Drive number in DL
	mov ch,al									; Cylinder in CX
	ror ah,2									; Low 8 bits of cylinder in CH, high 2 bits
												; in CL shifted to bits 6 & 7
	or cl,ah									; Or with sector number
	mov ax,201h									; Read 1 sector using function 02
	int 13h										; Call disk read interrupt
	jc error_read								; If the read failed then abort
	popad										; Pop our registers off the stack
	inc eax										; Increment Sector to Read
	mov dx,es									; Move the segment position into dx
	add dx,[drive_bytes]						; Increment read buffer for next sector
	mov es,dx									; Save our new buffer position
	loop read_sectors							; Read next sector if need be
	retn										; Return to caller

;------------------------------------------------------------------------------
; Print a message on the display. The argument inside SI needs to point to a
; null terminated string held in memory. When the null character is read, the
; function returns to the caller.
;
; Arguments:
;	SI = message location
;
print:
	lodsb										; Load the next character
	or al,al									; Test for a null character
	jz short .print_done						; We found a null char, return to caller
	mov ah,0Eh									; BIOS teletype
	mov bh,0									; Display page 0
	mov bl,7									; Text attribute
	;int 10h										; Invoke BIOS call
	jmp short print								; Go to next character
.print_done:
	retn										; When done, return to caller

;------------------------------------------------------------------------------
; Displays msg_reboot to the user using the display function above, then waits
; for the user to press a key. Once a key has been pressed, it reboots.
;
error_reboot:
	; Display message to reboot
	mov si,msg_reboot							; Set source index to msg_reboot
	call print									; Call the show procedure

	; Call the reboot interrupt
	xor ax,ax									; Clear register ax
	int 16h										; Wait for user keypress
	int 19h										; Reboot

;------------------------------------------------------------------------------
; When a read error occurs, this function decreases the read error counter.
; When the read counter gets to zero, a message is displayed using the print
; function above, then the key_reboot function is called.
;
; Arguments:
;	DI = Retry loop counter (This decreases with every invocation)
;
; Returns:
;	DI = DI--
;
error_read:
	; Decrease our loop counter and reboot if zero
	dec di										; Decrease our loop counter
	jz error_reboot								; If di zero, break loop and reboot

	; Print the reading message
	mov si,msg_diskerr							; Set source index to msg_disktry
	call print									; Call the show procedure
	jmp read_sectors							; Rerun the read if di not zero

;------------------------------------------------------------------------------
; When loading into the first segment of a disk, we need to ensure that if the
; disk contains a partition table, we dont overwrite it. Now, normally others
; use the line 'times 510-($-$$) db0' followed by 'dw 0AA55h'. The problem with
; this is that you overwrite the partition table sitting at offset 446-510 and
; this makes the drive unusable. I have also left bytes in the range '440-446'
; out as some partition managers (aka. linux fdisk) add extra bits here for an
; unknown reason. (still to be investigated). UPDATE: It seems that windows
; vista stores an id from 440-446. Thats why they are left open.
; You may notice I also dont set the AA55h. When the atcive boot flag is set,
;
;times 440-($-$$) db 0							; ZERO full the mbr to byte 440. (The partition table starts here)
