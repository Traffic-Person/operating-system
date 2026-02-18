# Flavortown OS Makefile
# Build stage1 + stage2 + C kernel + combine into os.img

# Cross-compiler
CC=i686-elf-gcc
LD=i686-elf-ld
OBJCOPY=i686-elf-objcopy
NASM=nasm
QEMU=qemu-system-i386

# Files
BOOT_SRC=src/boot/boot.asm
STAGE2_SRC=src/boot/boot2.asm
KERNEL_SRC=src/kernel.c
LINKER=linker.ld

BOOT_BIN=boot.bin
STAGE2_BIN=boot2.bin
KERNEL_OBJ=kernel.o
KERNEL_ELF=kernel.elf
KERNEL_BIN=kernel.bin
OS_IMG=os.img

# Flags
CFLAGS=-ffreestanding -m32 -O0 -Wall -Wextra
NASMFLAGS=-f bin

# Default target
all: $(OS_IMG)

# Stage1 bootloader
$(BOOT_BIN): $(BOOT_SRC)
	$(NASM) $(NASMFLAGS) $< -o $@

# Stage2 loader
$(STAGE2_BIN): $(STAGE2_SRC)
	$(NASM) $(NASMFLAGS) $< -o $@

# C kernel object
$(KERNEL_OBJ): $(KERNEL_SRC)
	$(CC) $(CFLAGS) -c $< -o $@

# Link kernel
$(KERNEL_ELF): $(KERNEL_OBJ) $(LINKER)
	$(LD) -m elf_i386 -T $(LINKER) -o $@ $(KERNEL_OBJ)

# Convert kernel ELF to binary
$(KERNEL_BIN): $(KERNEL_ELF)
	$(OBJCOPY) -O binary $< $@

# Combine bootloader + stage2 + kernel into one disk image
$(OS_IMG): $(BOOT_BIN) $(STAGE2_BIN) $(KERNEL_BIN)
	cat $(BOOT_BIN) $(STAGE2_BIN) $(KERNEL_BIN) > $@

# Run in QEMU
run: $(OS_IMG)
	$(QEMU) -drive format=raw,file=$(OS_IMG),snapshot=on

# Clean everything
clean:
	rm -f $(BOOT_BIN) $(STAGE2_BIN) $(KERNEL_OBJ) $(KERNEL_ELF) $(KERNEL_BIN) $(OS_IMG)
