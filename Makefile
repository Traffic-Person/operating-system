CC=i686-elf-gcc
LD=i686-elf-ld
NASM=nasm
QEMU=qemu-system-i386

BOOT_SRC=src/boot/boot.asm
STAGE2_SRC=src/boot/boot2.asm
KERNEL_SRC=src/kernel.c
LINKER=linker.ld

BOOT_BIN=boot.bin
STAGE2_BIN=boot2.bin
KERNEL_OBJ=kernel.o
KERNEL_BIN=kernel.bin
OS_IMG=os.img

CFLAGS=-ffreestanding -m32 -O0 -Wall -Wextra -ffunction-sections -fdata-sections

all: $(OS_IMG)

$(BOOT_BIN): $(BOOT_SRC)
	$(NASM) -f bin $< -o $@

$(STAGE2_BIN): $(STAGE2_SRC)
	$(NASM) -f bin $< -o $@

$(KERNEL_OBJ): $(KERNEL_SRC)
	$(CC) $(CFLAGS) -c $< -o $@

$(KERNEL_BIN): $(KERNEL_OBJ) $(LINKER)
	$(LD) -m elf_i386 -T $(LINKER) -nostdlib --oformat binary -o $@ $(KERNEL_OBJ)

$(OS_IMG): $(BOOT_BIN) $(STAGE2_BIN) $(KERNEL_BIN)
	cat $(BOOT_BIN) $(STAGE2_BIN) $(KERNEL_BIN) > $@

#run: $(OS_IMG)
#	$(QEMU) -drive format=raw,file=$(OS_IMG),snapshot=on

run: $(OS_IMG)
	$(QEMU) -drive format=raw,file=$(OS_IMG),if=floppy,snapshot=on

clean:
	rm -f $(BOOT_BIN) $(STAGE2_BIN) $(KERNEL_OBJ) $(KERNEL_BIN) $(OS_IMG)
