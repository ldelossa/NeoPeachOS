; tells the compiler all instructions should be produced for 16 bit mode.
BITS 16

; create .text.bootloader section for ELF debugging
section .text.bootloader

jmp start;

gdt_start:
	dq 0x0 		; mandatory null segment descriptor
gdt_code:
CODE_SEGMENT equ (gdt_code - gdt_start);
	dw 0xFFFF	; limit set to 4Gb
	dw 0x0		; base[0]
	db 0x0		; base[1]
	db 10011010b	; access byte: ring 0 access, exec bit
	db 11001111b	; flags|limit: flags(page granularity, 32bit segment)
	db 0x0 		; base[2]
	; Data segment descriptor
gdt_data:
DATA_SEGMENT equ (gdt_data - gdt_start)
	dw 0xFFFF	; limit set to 4Gb
	dw 0x0		; base[0]
	db 0x0		; base[1]
	db 10010010b	; access byte: ring 0 access, data bit
	db 11001111b	; flags|limit: flags(page granularity, 32bit segment)
	db 0x0 		; base[2]
gdt_end:

gdt_descriptor:
	dw (gdt_end - gdt_start) - 1
	dd gdt_start

global start ; using global here makes it available to debugger if an elf file
			 ; is created
start:
	cli		 ; clear interrupts
	mov ax, 0x0
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, 0x7C00

	sti		 ; enables interrupt

	mov 	si, message
	mov 	ah, 0x0E ; holds bios routine selector for printing
.loop:
	lodsb	; load byte si -> al and increment si
	cmp		al, 0
	je		protected_mode_switch
	int 0x10
	jmp .loop

global protected_mode_switch
protected_mode_switch:
	cli		; clear interrupts
	lgdt	[gdt_descriptor]
	mov eax, cr0
	or eax, 0x1
	mov cr0, eax

	jmp CODE_SEGMENT:idle_32

; 32 bit mode from here on out...
[BITS 32]
idle_32:
	; finish register setup
	mov ax, DATA_SEGMENT
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax
	mov ebp, 0x00200000
	mov esp, ebp

	jmp $

global message
message: db 'Hello World!', 0

; boot signature must be placed at offset 510 (the 511 byte of the sector).
; calculate size of current section ($ - $$) and subtract this from the total
; zero padding necessary to get to 511 byte.
times 510 - ($ - $$) db 0
; write the boot signature word
dw 0xAA55 ; NASM will interpret this as little endian, so flip it, so when it
		  ; writes it to our image its in the correct order.

section .sector_two
INCBIN "./src/boot/sector_two.bin"
db 0
; pad out second sector
times 512 - ($ - $$) db 0
