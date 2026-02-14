org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

;
; FAT12 HEADER
;
jmp short start
nop

bdb_oem:                     db 'MSWIN4.1' ; 8 bites
bdb_bytes_per_sector:        dw 512
bdb_sectors_per_cluster:     db 1
bdb_reserved_sectors:        dw 1
bdb_fat_count:               db 2
bdb_dir_entries_count:       dw 0E0h
bdb_total_sectors:           dw 2880       ; 2880*512=1.44mb
bdb_media_descriptor_type:   db 0F0h
bdb_sectors_per_fat:         dw 9
bdb_sectors_per_track:       dw 18
bdb_heads:                   dw 2
bdb_hidden_sectors:          dd 0
bdb_large_sector_count:      dd 0

; extended boot sector or sum
ebr_drive_number:            db 0
                             db 0          ; reserved bite
ebr_signature:               db 29h
ebr_volume_id:               db 12h, 34h, 56h, 78h
ebr_volume_label:            db '   label   ' ;11 bites with spaces 
ebr_system_id:               db 'FAT12   ' ; 8 bites



start:
  jmp main

; prints a string to the screen
; params: ds:si points to strin
puts:
  ;save regs that will be modified
  push si
  push ax

.loop:
  lodsb ; loads next character in al
  or al, al ;verify if next character is null
  jz .done

  mov ah, 0x0e ; call bios interup NOW
  mov bh, 0
  int 0x10

  jmp .loop

.done:
  pop ax
  pop si
  ret

main:

  ; setup data segmens
  mov ax, 0
  mov ds, ax
  mov es, ax

  ; setup stack
  mov ss, ax
  mov sp, 0x7C00
  
  ;read smtn from floppy
  mov [ebr_drive_number], dl

  mov ax, 1
  mov cl, 1
  mov bx, 0x7E00
  call disk_read

  ; print msg
  mov si, msg_hello
  call puts

  cli
  hlt

floppy_error:
  
  mov si, msg_read_failed
  call puts
  jmp wait_key_and_reboot
  
wait_key_and_reboot:
  mov ah, 0
  int 16h ; wait for keypres
  jmp 0FFFFh:0 ; should reboot but idk

.halt:
  cli
  hlt

;
;
; Disk routines
;

; Converts a LBA address to a CHS one
lba_to_chs:

  push ax
  push dx

  xor dx, dx ;dx = 0
  div word [bdb_sectors_per_track]

  inc dx
  mov cx, dx

  xor dx, dx
  div word [bdb_heads]

  mov dh, dl
  mov ch, al
  shl ah, 6
  or cl, ah

  pop ax
  mov dl, al
  pop ax
  ret

;
; Reads sectors
;
disk_read:

  ; save all to stack
  push ax
  push bx
  push cx
  push dx
  push di

  push cx
  call lba_to_chs
  pop ax
  
  ; floppy disks are real fucky and sometimes unreliable
  ; so we restart it a couple of times :)
  mov ah, 02h
  mov di, 3 ; times to restart in register di

.retry:
  pusha
  stc

  int 13h
  jnc .done

  ; read failed
  popa
  call disk_reset
  dec di
  test di, di
  jnz .retry

.fail:
  ; fail after attemps
  jmp floppy_error

.done:
  popa

  pop di ; restore in opposite order bc stack ofc
  pop dx
  pop cx
  pop bx
  pop ax
  ret

disk_reset:
  pusha
  mov ah, 0
  stc
  int 13h
  jc floppy_error
  popa
  ret

msg_hello: db 'Hello world!', ENDL, 0
msg_read_failed: db 'Uh oh! after all the attempts read from floppy disk failed', ENDL, 0


times 510-($-$$) db 0
dw 0AA55h
