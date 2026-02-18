org 0x7C00
bits 16

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov [BOOT_DRIVE], dl

    mov si, message
    call print_str

    ; reset disk
    xor ah, ah
    mov dl, [BOOT_DRIVE]
    int 0x13

    mov ax, 0x0000
    mov es, ax
    mov bx, 0x8000
    mov ah, 0x02
    mov al, 5
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [BOOT_DRIVE]
    int 0x13
    jc diskerr

    jmp 0x0000:0x8000

print_str:
    mov ah, 0x0E
.loop:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .loop
.done:
    ret

diskerr:
    mov si, err
    call print_str
    hlt

message db 'hai', 0
err db 'Disk err', 0
BOOT_DRIVE db 0

times 510-($-$$) db 0
dw 0xAA55
