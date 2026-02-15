org 0x7C00 ; HEY BIOS HERE IS START
bits 16    ; 16 bit bc x86 processors are backwards compatible


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

  ; setup data segmens
  mov ax, 0
  mov ds, ax
  mov es, ax

  ; setup stack
  mov ss, ax
  mov sp, 0x7C00

  push es
  push word .after
  retf

.after:
  
  

  ;read smtn from floppy
  mov [ebr_drive_number], dl

  

  ; print loading message
  mov si, msg_loading
  call puts

  push es
  mov ah, 08h
  int 13h
  jc floppy_error
  pop es

  and cl, 0x3F ; remove 2 bites from the top
  xor ch, ch
  mov [bdb_sectors_per_track], cx ; sector count

  inc dh
  mov [bdb_heads], dh

  ;read FAT root dir
  mov ax, [bdb_sectors_per_fat]
  mov bl, [bdb_fat_count]
  xor bh, bh
  mul bx
  add ax, [bdb_reserved_sectors]
  push ax

  mov ax, [bdb_sectors_per_fat]
  shl ax, 5
  xor dx, dx
  div word [bdb_bytes_per_sector]

  test dx, dx
  jz .root_dir_after
  inc ax

.root_dir_after:
  
  ; read root dir
  mov cl, al
  pop ax
  mov dl, [ebr_drive_number]
  mov bx, buffer
  call disk_read

  
  ; search for kernel binary
  xor bx, bx
  mov di, buffer


.search_kernel:
  mov si, file_kernel_bin
  mov cx, 11
  push di
  repe cmpsb
  pop di
  je .found_kernel

  add di, 32
  inc bx
  cmp bx, [bdb_dir_entries_count]
  jl .search_kernel

  jmp kernel_not_found_err

.found_kernel:

  mov ax, [di + 26]
  mov [kernel_cluster], ax

  mov ax, [bdb_reserved_sectors]
  mov bx, buffer
  mov cl, [bdb_sectors_per_fat]
  mov dl, [ebr_drive_number]
  call disk_read

  mov bx, KERNEL_LOAD_SEGMENT
  mov es, bx
  mov bx, KERNEL_LOAD_OFFSET

.load_kernel_loop:
  
  mov ax, [kernel_cluster]
  add ax, 31 ;BAD VALUE (hardcoded)

  mov cl, 1
  mov dl, [ebr_drive_number]
  call disk_read

  add bx, [bdb_bytes_per_sector]

  mov ax, [kernel_cluster]
  mov cx, 3
  mul cx
  mov cx, 2
  div cx

  mov si, buffer
  add si, ax
  mov ax, [ds:si] ; next entry

  or dx, dx
  jz .even

.odd:
  shr ax, 4
  jmp .next_cluster_after

.even:
  and ax, 0x0FFF

.next_cluster_after:
  
  cmp ax, 0x0FF8
  jae .read_finish

  mov [kernel_cluster], ax
  jmp .load_kernel_loop

.read_finish:
  mov dl, [ebr_drive_number]

  mov ax, KERNEL_LOAD_SEGMENT
  mov ds, ax
  mov es, ax

  jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET


  jmp wait_key_and_reboot ;shouldnt hapen

  cli
  hlt

floppy_error:
  
  mov si, msg_read_failed
  call puts
  jmp wait_key_and_reboot

kernel_not_found_err:
  mov si, msg_kernel_not_found
  call puts
  jmp wait_key_and_reboot

wait_key_and_reboot:
  mov ah, 0
  int 16h ; wait for keypres
  jmp 0FFFFh:0 ; should reboot but idk

.halt:
  cli
  hlt

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

msg_loading: db 'Loading. . .', ENDL, 0
msg_read_failed: db 'Floppy disk read err', ENDL, 0
msg_kernel_not_found: db 'Kernel binary not found!', ENDL, 0
file_kernel_bin: db 'KERNEL  BIN'
kernel_cluster: dw 0

buffer equ 0x0500

;test: db 11h, 22h, 33h, 44h, 55h
;lmao i got more space than the tutorial guy
;im better ig /j

KERNEL_LOAD_SEGMENT equ 0x2000
KERNEL_LOAD_OFFSET equ 0


times 510-($-$$) db 0
dw 0AA55h
