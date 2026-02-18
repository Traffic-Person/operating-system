org 0x8000
bits 16

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov ah, 0x0E
    mov al, '2'
    int 0x10

    call enable_a20
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:pmode_entry

enable_a20:
    in al, 0x92
    or al, 2
    out 0x92, al
    ret

gdt_start:
    dq 0x0000000000000000
    dq 0x00CF9A000000FFFF
    dq 0x00CF92000000FFFF
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

bits 32
pmode_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
    mov esp, 0x7C00

    mov edi, 0xB8000
    mov word [edi],   0x0F50
    mov word [edi+2], 0x0F4A

    ; read first byte at 0x8400 and show it on screen
    movzx eax, byte [0x8400]
    add eax, 0x0F00
    mov word [edi+4], ax

    ; read second byte
    movzx eax, byte [0x8401]
    add eax, 0x0F00
    mov word [edi+6], ax

    mov eax, 0x00008400
    jmp eax

times 1024-($-$$) db 0
