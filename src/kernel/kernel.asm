; kernel runs in 32 bit mode
[BITS 32]

CODE_SEGMENT equ 0x08
DATA_SEGMENT equ 0x10

global _start
_start:
	jmp $

times 512-($-$$) db 0
