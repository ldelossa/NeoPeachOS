; BUS 1 ports

; PIO read/write data register
B1_DATA equ 0x1F0
; R: error buffer, W: feature buffer
B1_ERR_FEAT equ 0x1F1
; configure sector count for r/w
B1_SEC_COUNT equ 0x1F2
; LBA low bits
B1_LBA_LO equ 0x1F3
; LBA middle bits
B1_LBA_MID equ 0x1F4
; LBA high bits
B1_LBA_HI equ 0x1F5
; drive select/addressing/LBA extended bits register.
B1_DRIVE_SELECT equ 0x1F6
; alternative status port
B1_ALT_STATUS equ 0x3F6
; command port
B1_COMMAND equ 0x1F7

; Master drive with LBA mode selected
; 0 LBA bits specified
MASTER_DRIVE equ 0xE0

; LBA address kernel begins at (second sector)
KERNEL_LBA equ 0x1
; Load address of kernel
KERNEL_LOAD_ADDR equ 0x100000

; our kernel at this point is known to be one sector large and loaded to
; the 1MB boundary of '0x100000'.
;
; once the kernel becomes more complex we can give it a header in its binary
; image which encodes large or how many sectors the kernel occupies, read this
; and dynamically load the kernel. For now, lets keep it simple.
global ata_load_kernel
ata_load_kernel:
	; configure drive and LBA addressing mode
	mov dx, B1_DRIVE_SELECT
	mov al, MASTER_DRIVE
	out dx, al

	; configure number of sectors to read
	mov dx, B1_SEC_COUNT
	mov al, 0x1
	out dx, al

	; configure LBA of 0x1
	mov dx, B1_LBA_LO
	mov al, KERNEL_LBA
	out dx, al

	mov dx, B1_LBA_MID
	mov al, 0x0
	out dx, al

	mov dx, B1_LBA_HI
	mov al, 0x0
	out dx, al

	; send read command
	mov dx, B1_COMMAND
	mov al, 0x20
	out dx, al

	; we may have asked the bus to change disks as part of our read operation,
	; as per the ATA spec, delay here for 400ns by reading the status reg 14
	; times
	mov dx, B1_ALT_STATUS
	mov bl, 0xE
.delay:
	in 	eax, dx
	dec bl
	jnz .delay

	; ensure busy bit is cleared and no error
	call ata_wait_ready
	; ensure drq bit is set, indicating data is ready
	call ata_wait_drq

	; begin reading PIO data
	; the PIO data register is 16 bits large
	; we can use 'rep insw' to repeat the read of a word a set number of times
	mov dx,  B1_DATA 			; insw port
	mov edi, KERNEL_LOAD_ADDR	; insw load address
	mov cx,	 256				; rep counter, (512 bytes / 2 byte words)
	rep insw					; start copy, will repeat until cx is 0

	ret

; polls until BSY bit is set to 0 and DRDY is set to 1.
; checks if ERR bit is set, if so jumps to abort, if not returns to caller.
global ata_wait_ready
ata_wait_ready:
	mov dx, B1_ALT_STATUS
	in 	al, dx
	mov bl, al

	and	bl, 0xC0 ; mask out BSY and DRDY bits
	cmp	bl, 0x40 ; we only want the DRDY bit to be on

	jne ata_wait_ready ; if we are busy or not ready

	; now we can check the error bit
	mov bl, al
	and bl, 0x1
	cmp bl, 0x1
	je	abort

	ret

; polls until DRQ bit is set indicating our drive has data to read.
global ata_wait_drq
ata_wait_drq:
	mov dx, B1_ALT_STATUS
	in 	al, dx
	mov bl, al

	and	bl, 0x08
	cmp	bl, 0x08

	jne ata_wait_drq
	ret

abort:
	; todo, print out an error message and hang the system, we have not
	; implemented serial output yet.
	jmp $
