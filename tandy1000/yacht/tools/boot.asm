; Boot sector for the YACHT floppy. The game runs under DOS, so if the disk is
; booted this just explains that and waits for a key.
cpu 8086
org 7C00h
    jmp short entry
    nop
    db 'YACHT1.0'
    dw 512                      ; bytes per sector
    db 2                        ; sectors per cluster
    dw 1                        ; reserved sectors
    db 2                        ; FATs
    dw 112                      ; root entries
    dw 720                      ; total sectors
    db 0FDh                     ; media: 360K
    dw 2                        ; sectors per FAT
    dw 9                        ; sectors per track
    dw 2                        ; heads
    dd 0
entry:
    cli
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 7C00h
    sti
    mov si, msg
.l:
    lodsb
    or al, al
    jz .k
    mov ah, 0Eh
    mov bx, 7
    int 10h
    jmp .l
.k:
    xor ah, ah
    int 16h
    int 19h
msg:
    db 'This disk holds YACHT. Start DOS, then type A:YACHT', 13, 10, 0
    times 510 - ($ - $$) db 0
    dw 0AA55h
