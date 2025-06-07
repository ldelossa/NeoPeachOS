SRC_DIR=./src
BUILD_DIR=./build
BIN_DIR=./bin

# boot-loader #
#
# the boot-loader depends on kernel.bin which launches the kernel build
# recipe.
#
# kernel.bin will be appended to the final boot.bin image as additional sectors.

# creates the final binary image for CPU execution
$(BIN_DIR)/boot.bin: $(SRC_DIR)/boot/boot
	x86_64-linux-gnu-objcopy -O binary $< $@

# creates boot loader elf file, this can be passed to GDB to reflect locations
# of important symbols.
$(SRC_DIR)/boot/boot: $(SRC_DIR)/boot/boot.o
	x86_64-linux-gnu-ld -g -T $(SRC_DIR)/boot/boot.lds -o $@ $<

$(SRC_DIR)/boot/boot.o: $(SRC_DIR)/boot/boot.asm $(SRC_DIR)/boot/boot.lds $(SRC_DIR)/boot/ata_32.asm $(BIN_DIR)/kernel.bin
	nasm -f elf64 -F dwarf -g -o $@ $<

# kernel #
# our kernel.bin will be appended to boot.bin via the INCBIN nasm directive.

# creates final kernel image for CPU execution
$(BIN_DIR)/kernel.bin: $(SRC_DIR)/kernel/kernel
	x86_64-linux-gnu-objcopy -O binary $< $@

$(SRC_DIR)/kernel/kernel: $(SRC_DIR)/kernel/kernel.o
	x86_64-linux-gnu-ld -g -T $(SRC_DIR)/kernel/kernel.lds -o $@ $<

$(SRC_DIR)/kernel/kernel.o: $(SRC_DIR)/kernel/kernel.asm $(SRC_DIR)/kernel/kernel.lds
	nasm -f elf64 -F dwarf -g -o $@ $<

.PHONY:
clean:
	rm -rf $(SRC_DIR)/boot/*.o
	rm -rf $(SRC_DIR)/boot/boot
	rm -rf $(BIN_DIR)/boot.bin
	rm -rf $(SRC_DIR)/kernel/*.o
	rm -rf $(SRC_DIR)/kernel/kernel
	rm -rf $(BIN_DIR)/kernel.bin

.PHONY:
run:
	qemu-system-x86_64 -nographic ./bin/boot.bin

run-debug:
	qemu-system-x86_64 -nographic -s -S ./bin/boot.bin

debug:
	lldb -o "gdb-remote 0.0.0.0:1234" ./src/boot/boot
