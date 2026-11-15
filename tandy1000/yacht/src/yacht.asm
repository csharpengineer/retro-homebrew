; ---------------------------------------------------------------------------
; YACHT - the classic dice game, for the Tandy 1000 SL
;
; Native 8086 code, assembled with NASM to a DOS .COM program.
; Hardware used directly:
;   Video   320x200 16-color mode, palette registers, vertical retrace sync
;   Sound   SN76496 three tone voices plus noise, driven by a timer interrupt
;   Speech  8-bit DAC fed by 8237 DMA channel 1 while the game keeps running
;   Timer   8253 reprogrammed to 72.8 Hz, BIOS clock still chained at 18.2 Hz
;   Disk    speech data and the best score, through DOS file calls
;
; Run YACHT /T for the built-in scoring self test.
; ---------------------------------------------------------------------------
cpu 8086
org 100h

%include "notes.inc"
%include "speech.inc"

VIDSEG      equ 0B800h
SN          equ 0C0h            ; SN76496 sound chip
DAC_CTRL    equ 0C4h            ; Tandy DAC control
DAC_DATA    equ 0C5h
DAC_FLO     equ 0C6h            ; sample rate divider, low byte
DAC_FHI     equ 0C7h            ; divider high nibble, amplitude high bits
DAC_RATE    equ 447             ; 3579545 / 447 = 8008 Hz
NUM_CATS    equ 12
EMPTY       equ 0FFFFh

C_BLACK     equ 0
C_BLUE      equ 1
C_RED       equ 4
C_BROWN     equ 6
C_LGRAY     equ 7
C_DGRAY     equ 8
C_LCYAN     equ 11
C_YELLOW    equ 14
C_WHITE     equ 15

CAT_FULL    equ 6
CAT_FOUR    equ 7
CAT_LITTLE  equ 8
CAT_BIG     equ 9
CAT_CHOICE  equ 10
CAT_YACHT   equ 11

ROW_TOP     equ 15
ROW_STEP    equ 13
TOTAL_Y     equ ROW_TOP + NUM_CATS * ROW_STEP
COL_P0      equ 120
COL_P1      equ 152

section .text

; ---------------------------------------------------------------------------
; Entry
; ---------------------------------------------------------------------------
start:
    cld
    ; DOS leaves old memory contents here, so working storage starts cleared
    mov di, bss_start
    mov cx, bss_end - bss_start
    xor al, al
    rep stosb
    mov si, 81h
.parse:
    lodsb
    cmp al, 0Dh
    je .parsed
    cmp al, '/'
    jne .parse
    lodsb
    or al, 20h
    cmp al, 't'
    jne .parse
    jmp selftest
.parsed:
    call load_best
    mov ax, 0009h               ; 320x200, 16 colors
    int 10h
    mov ax, VIDSEG
    mov es, ax
    call build_rows
    call capture_font
    call load_speech
    call seed_rng
    call hook_timer
.menu:
    call title_screen
    cmp al, 0FFh
    je .quit
    mov [game_mode], al
    call play_game
    jmp .menu
.quit:
    call chip_silence
    call unhook_timer
    mov ax, 0003h
    int 10h
    mov dx, msg_bye
    mov ah, 9
    int 21h
    mov ax, 4C00h
    int 21h

; ---------------------------------------------------------------------------
; Video setup
; ---------------------------------------------------------------------------

; Fills row_off with the address of each scan line. The mode interleaves four
; banks of 8K, so line y lives at (y AND 3) * 2000h + (y / 4) * 160.
build_rows:
    xor cx, cx
    mov si, row_off
.l:
    mov ax, cx
    shr ax, 1
    shr ax, 1
    mov dx, 160
    mul dx
    mov bx, cx
    and bx, 3
    shl bx, 1
    add ax, [bank_tbl + bx]
    mov [si], ax
    add si, 2
    inc cx
    cmp cx, 200
    jb .l
    ret

; Borrows the machine's own font: the BIOS draws each character in the corner
; of the screen and the pixels are read back into a one-bit table.
capture_font:
    mov byte [cur_char], 32
    mov word [font_ptr], font_tbl
.ch:
    mov ah, 2
    xor bh, bh
    xor dx, dx
    int 10h
    mov ah, 9
    mov al, [cur_char]
    xor bh, bh
    mov bl, C_WHITE
    mov cx, 1
    int 10h
    xor bx, bx
    mov si, [font_ptr]
.row:
    mov di, [row_off + bx]
    xor dl, dl
    mov cx, 4
.pair:
    mov al, [es:di]
    inc di
    shl dl, 1
    test al, 0F0h
    jz .a
    or dl, 1
.a:
    shl dl, 1
    test al, 0Fh
    jz .b
    or dl, 1
.b:
    loop .pair
    mov [si], dl
    inc si
    add bx, 2
    cmp bx, 16
    jb .row
    mov [font_ptr], si
    inc byte [cur_char]
    cmp byte [cur_char], 127
    jb .ch
    ret

; ---------------------------------------------------------------------------
; Drawing primitives. ES stays on video memory. X positions and widths are
; even, so every operation lands on whole bytes.
; ---------------------------------------------------------------------------

; BX=x DX=y CX=width SI=height AL=color. Preserves all registers.
fill_rect:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    and al, 0Fh
    mov ah, al
    mov bp, cx
    mov cl, 4
    shl ah, cl
    or al, ah
    mov cx, bp
    shr cx, 1
    shr bx, 1
    mov bp, cx
.row:
    mov di, dx
    shl di, 1
    mov di, [row_off + di]
    add di, bx
    mov cx, bp
    rep stosb
    inc dx
    dec si
    jnz .row
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; AH=foreground AL=background. Builds the two-pixel lookup used by draw_char.
set_colors:
    push ax
    push bx
    push cx
    mov bl, ah
    mov bh, al
    mov cl, 4
    mov al, bh
    shl al, cl
    or al, bh
    mov [pair_tbl], al
    mov al, bh
    shl al, cl
    or al, bl
    mov [pair_tbl + 1], al
    mov al, bl
    shl al, cl
    or al, bh
    mov [pair_tbl + 2], al
    mov al, bl
    shl al, cl
    or al, bl
    mov [pair_tbl + 3], al
    pop cx
    pop bx
    pop ax
    ret

; AL=character BX=x DX=y. Preserves all registers.
draw_char:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    sub al, 32
    jb .done
    cmp al, 95
    jae .done
    xor ah, ah
    shl ax, 1
    shl ax, 1
    shl ax, 1
    add ax, font_tbl
    mov si, ax
    shr bx, 1
    mov [xbyte], bx
    mov byte [rowcnt], 8
.row:
    mov bx, dx
    shl bx, 1
    mov di, [row_off + bx]
    add di, [xbyte]
    lodsb
    mov ah, al
    mov bx, pair_tbl
    mov cx, 4
.p:
    rol ah, 1
    rol ah, 1
    mov al, ah
    and al, 3
    xlatb
    stosb
    loop .p
    inc dx
    dec byte [rowcnt]
    jnz .row
.done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; SI=zero-terminated string BX=x DX=y. Preserves all registers.
draw_str:
    push ax
    push bx
    push si
.l:
    lodsb
    or al, al
    jz .e
    call draw_char
    add bx, 8
    jmp .l
.e:
    pop si
    pop bx
    pop ax
    ret

; AX=value BX=x DX=y. Right-aligned in three characters.
draw_num:
    push ax
    push cx
    push dx
    push si
    push bp
    mov bp, dx
    mov si, numbuf + 3
    mov byte [si], 0
    mov cx, 10
.d:
    xor dx, dx
    div cx
    add dl, '0'
    dec si
    mov [si], dl
    or ax, ax
    jnz .d
.pad:
    cmp si, numbuf
    je .out
    dec si
    mov byte [si], ' '
    jmp .pad
.out:
    mov dx, bp
    mov si, numbuf
    call draw_str
    pop bp
    pop si
    pop dx
    pop cx
    pop ax
    ret

; SI=string BX=x DX=y AL=color. Draws at 4x scale.
draw_big:
    push ax
    push bx
    push cx
    push dx
    push si
    mov [big_color], al
.ch:
    lodsb
    or al, al
    jz .e
    call big_char
    add bx, 32
    jmp .ch
.e:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

big_char:
    push ax
    push bx
    push cx
    push dx
    push si
    sub al, 32
    xor ah, ah
    shl ax, 1
    shl ax, 1
    shl ax, 1
    add ax, font_tbl
    mov si, ax
    mov [big_x], bx
    mov byte [big_rows], 8
.r:
    lodsb
    mov [big_bits], al
    mov bx, [big_x]
    mov byte [big_cols], 8
.c:
    shl byte [big_bits], 1
    jnc .n
    push si
    mov al, [big_color]
    mov cx, 4
    mov si, 4
    call fill_rect
    pop si
.n:
    add bx, 4
    dec byte [big_cols]
    jnz .c
    add dx, 4
    dec byte [big_rows]
    jnz .r
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

wait_vsync:
    push ax
    push cx
    push dx
    mov dx, 3DAh
    mov cx, 0FFFFh
.a:
    in al, dx
    test al, 8
    jz .b
    loop .a
.b:
    mov cx, 0FFFFh
.c:
    in al, dx
    test al, 8
    jnz .d
    loop .c
.d:
    pop dx
    pop cx
    pop ax
    ret

; AL=palette entry AH=color. Tandy palette registers sit at index 10h and up.
pal_set:
    push ax
    push dx
    add al, 10h
    mov dx, 3DAh
    out dx, al
    mov al, ah
    mov dx, 3DEh
    out dx, al
    pop dx
    pop ax
    ret

; Rotates the three water colors, which makes the sea appear to move.
pal_cycle:
    mov ax, [ticks]
    sub ax, [pal_next]
    js .r
    mov ax, [ticks]
    add ax, 12
    mov [pal_next], ax
    mov bl, [pal_phase]
    inc bl
    cmp bl, 3
    jb .s
    xor bl, bl
.s:
    mov [pal_phase], bl
    xor bh, bh
    mov ah, [wave_seq + bx]
    mov al, 1
    call pal_set
    mov ah, [wave_seq + bx + 1]
    mov al, 9
    call pal_set
    mov ah, [wave_seq + bx + 2]
    mov al, 3
    call pal_set
.r:
    ret

pal_reset:
    mov ax, 0101h
    call pal_set
    mov ax, 0909h
    call pal_set
    mov ax, 0303h
    call pal_set
    ret

; ---------------------------------------------------------------------------
; Timer interrupt: music, noise, speech timing and the game clock
; ---------------------------------------------------------------------------
hook_timer:
    cli
    push es
    xor ax, ax
    mov es, ax
    mov ax, [es:20h]
    mov [old8], ax
    mov ax, [es:22h]
    mov [old8 + 2], ax
    mov word [es:20h], timer_isr
    mov [es:22h], cs
    pop es
    mov al, 36h
    out 43h, al
    xor al, al
    out 40h, al
    mov al, 40h                 ; divisor 16384 = 72.8 Hz
    out 40h, al
    sti
    ret

unhook_timer:
    cli
    mov al, 36h
    out 43h, al
    xor al, al
    out 40h, al
    out 40h, al
    push es
    xor ax, ax
    mov es, ax
    mov ax, [old8]
    mov [es:20h], ax
    mov ax, [old8 + 2]
    mov [es:22h], ax
    pop es
    sti
    ret

timer_isr:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push cs
    pop ds
    cld
    inc word [ticks]
    call music_tick
    call noise_tick
    cmp word [spk_ticks], 0
    je .chain
    dec word [spk_ticks]
    jnz .chain
    call dac_stop
.chain:
    dec byte [chain_cnt]
    jnz .eoi
    mov byte [chain_cnt], 4
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    jmp far [cs:old8]           ; every fourth tick goes to the BIOS clock
.eoi:
    mov al, 20h
    out 20h, al
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    iret

; BX = voice * 2 throughout the music driver.
music_tick:
    cmp byte [music_on], 0
    je .r
    xor bx, bx
.v:
    mov si, [v_ptr + bx]
    or si, si
    jz .n
    cmp word [v_left + bx], 0
    jne .tick
.fetch:
    lodsb
    cmp al, 0FFh
    jne .note
    cmp byte [tune_loop], 0
    je .stopv
    mov si, [v_start + bx]
    jmp .fetch
.stopv:
    mov word [v_ptr + bx], 0
    mov word [v_vol + bx], 15
    call voice_vol
    jmp .n
.note:
    mov ah, al
    lodsb
    xor cx, cx
    mov cl, al
    mov [v_left + bx], cx
    mov [v_ptr + bx], si
    or ah, ah
    jz .rest
    mov al, ah
    call voice_tone
    mov ax, [v_base + bx]
    mov [v_vol + bx], ax
    mov word [v_age + bx], 0
    call voice_vol
    jmp .tick
.rest:
    mov word [v_vol + bx], 15
    call voice_vol
.tick:
    dec word [v_left + bx]
    inc word [v_age + bx]
    test word [v_age + bx], 3
    jnz .n
    mov ax, [v_vol + bx]
    cmp ax, 15
    je .n
    mov cx, [v_base + bx]
    add cx, 5
    cmp ax, cx
    jae .n
    inc word [v_vol + bx]
    call voice_vol
.n:
    add bx, 2
    cmp bx, 6
    jb .v
.r:
    ret

; AL=note index. Sends the 10-bit divider as two bytes.
voice_tone:
    xor ah, ah
    shl ax, 1
    mov di, ax
    mov dx, [notes_tbl + di]
    mov al, bl
    mov cl, 4
    shl al, cl
    or al, 80h
    mov ah, dl
    and ah, 0Fh
    or al, ah
    out SN, al
    mov ax, dx
    mov cl, 4
    shr ax, cl
    and al, 3Fh
    out SN, al
    ret

voice_vol:
    mov ax, [v_vol + bx]
    cmp byte [mute], 0
    je .o
    mov al, 15
.o:
    mov ah, bl
    mov cl, 4
    shl ah, cl
    or al, ah
    or al, 90h
    out SN, al
    ret

noise_tick:
    cmp byte [noise_new], 0
    je .decay
    mov byte [noise_new], 0
    mov al, 0E5h                ; white noise, medium shift rate
    out SN, al
.decay:
    mov al, [noise_vol]
    cmp al, 15
    jae .r
    mov ah, al
    add ah, 4
    cmp ah, 15
    jbe .s
    mov ah, 15
.s:
    mov [noise_vol], ah
    cmp byte [mute], 0
    je .o
    mov al, 15
.o:
    or al, 0F0h
    out SN, al
.r:
    ret

sfx_click:
    mov byte [noise_vol], 3
    mov byte [noise_new], 1
    ret

; SI=three voice pointers AL=1 to loop.
play_tune:
    push ax
    push bx
    cli
    mov byte [music_on], 0
    mov [tune_loop], al
    xor bx, bx
.v:
    mov ax, [si + bx]
    mov [v_ptr + bx], ax
    mov [v_start + bx], ax
    mov word [v_left + bx], 0
    mov word [v_vol + bx], 15
    add bx, 2
    cmp bx, 6
    jb .v
    call chip_tones_off
    mov byte [music_on], 1
    sti
    pop bx
    pop ax
    ret

stop_tune:
    cli
    mov byte [music_on], 0
    call chip_tones_off
    sti
    ret

chip_tones_off:
    mov al, 9Fh
    out SN, al
    mov al, 0BFh
    out SN, al
    mov al, 0DFh
    out SN, al
    ret

chip_silence:
    call stop_tune
    mov al, 0FFh
    out SN, al
    cli
    call dac_stop
    mov word [spk_ticks], 0
    sti
    ret

toggle_mute:
    xor byte [mute], 1
    cmp byte [mute], 0
    je .r
    call chip_tones_off
.r:
    ret

; ---------------------------------------------------------------------------
; Speech: DMA channel 1 streams samples to the DAC with no CPU involvement.
; ---------------------------------------------------------------------------

; Loads YACHT.SPK into a 64K-aligned block, because a DMA transfer cannot
; cross a 64K page.
load_speech:
    mov byte [spk_ok], 0
    mov ax, cs
    add ax, 1000h + 0FFFh
    and ax, 0F000h
    mov [spk_seg], ax
    mov bx, ax
    add bx, 1000h
    cmp bx, [ds:2]              ; top of memory from the PSP
    ja .r
    mov dx, name_spk
    mov ax, 3D00h
    int 21h
    jc .r
    mov bx, ax
    push ds
    mov cx, 0FFF0h
    xor dx, dx
    mov ds, [spk_seg]
    mov ah, 3Fh
    int 21h
    pop ds
    pushf
    mov ah, 3Eh
    int 21h
    popf
    jc .r
    push ds
    mov ds, [spk_seg]
    xor si, si
    lodsw
    pop ds
    cmp ax, 16
    ja .r
    mov [spk_count], ax
    push ds
    push es
    push cs
    pop es
    mov cx, ax
    shl cx, 1
    add cx, ax
    mov di, spk_tbl
    mov ds, [cs:spk_seg]
    mov si, 2
    rep movsw
    pop es
    pop ds
    mov ax, [spk_seg]
    mov cl, 12
    shr ax, cl
    mov [spk_page], ax
    mov byte [spk_ok], 1
.r:
    ret

; AL=clip number.
speak:
    push ax
    push bx
    push cx
    push dx
    cmp byte [spk_ok], 0
    je .x
    cmp byte [mute], 0
    jne .x
    xor ah, ah
    cmp ax, [spk_count]
    jae .x
    mov cx, 6
    mul cx
    mov bx, ax
    add bx, spk_tbl
    cli
    mov al, 3
    out DAC_CTRL, al
    mov al, 5                   ; mask channel 1
    out 0Ah, al
    out 0Ch, al                 ; reset the byte flip-flop
    mov al, 49h                 ; single mode, memory to device, channel 1
    out 0Bh, al
    mov ax, [bx + 2]
    out 02h, al
    mov al, ah
    out 02h, al
    mov ax, [spk_page]
    out 83h, al
    mov ax, [bx + 4]
    dec ax
    out 03h, al
    mov al, ah
    out 03h, al
    mov al, 1                   ; unmask channel 1
    out 0Ah, al
    mov al, DAC_RATE & 0FFh
    out DAC_FLO, al
    mov al, 0E0h | (DAC_RATE >> 8)
    out DAC_FHI, al
    mov al, 7                   ; DMA to DAC, enabled
    out DAC_CTRL, al
    mov ax, [bx + 4]
    xor dx, dx
    mov cx, 110                 ; samples per timer tick
    div cx
    add ax, 3
    mov [spk_ticks], ax
    sti
.x:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

dac_stop:
    mov al, 3
    out DAC_CTRL, al
    mov al, 80h
    out DAC_DATA, al
    mov al, 5
    out 0Ah, al
    ret

wait_speech:
    cmp word [spk_ticks], 0
    jne wait_speech
    ret

; ---------------------------------------------------------------------------
; Time and randomness
; ---------------------------------------------------------------------------

; CX=ticks at 72.8 per second.
wait_ticks:
    push ax
    mov ax, [ticks]
    add ax, cx
.l:
    cmp ax, [ticks]
    jns .l
    pop ax
    ret

; CX=ticks. Sets quit_game if Esc is pressed while waiting.
ai_wait:
    push ax
    push dx
    mov dx, [ticks]
    add dx, cx
.l:
    mov ah, 1
    int 16h
    jz .t
    xor ah, ah
    int 16h
    cmp al, 27
    jne .m
    mov byte [quit_game], 1
    jmp .x
.m:
    or al, 20h
    cmp al, 'm'
    jne .t
    call toggle_mute
.t:
    cmp dx, [ticks]
    jns .l
.x:
    pop dx
    pop ax
    ret

seed_rng:
    xor ah, ah
    int 1Ah
    in al, 40h
    xor dh, al
    mov [seed], dx
    ret

; Returns AX=next 16-bit random value.
rand:
    push cx
    push dx
    mov ax, [seed]
    mov cx, 25173
    mul cx
    add ax, 13849
    mov [seed], ax
    pop dx
    pop cx
    ret

; Returns AX=1 to 6, taken from the high bits of the generator.
roll1:
    push cx
    push dx
    call rand
    mov cx, 6
    mul cx
    mov ax, dx
    inc ax
    pop dx
    pop cx
    ret

; ---------------------------------------------------------------------------
; Scoring
; ---------------------------------------------------------------------------

; Tallies the five dice into counts[0..6] and sum.
count_dice:
    push ax
    push bx
    push cx
    push si
    xor ax, ax
    mov [counts], ax
    mov [counts + 2], ax
    mov [counts + 4], ax
    mov [counts + 6], al
    mov [sum], ax
    mov si, dice
    mov cx, 5
    xor bx, bx
.l:
    lodsb
    mov bl, al
    inc byte [counts + bx]
    xor ah, ah
    add [sum], ax
    loop .l
    pop si
    pop cx
    pop bx
    pop ax
    ret

; AL=category. Returns AX=score for the current dice.
score_cat:
    push bx
    push cx
    call count_dice
    cmp al, CAT_FULL
    jae .special
    inc al
    mov bl, al
    xor bh, bh
    mov al, [counts + bx]
    mul bl
    jmp .done
.special:
    cmp al, CAT_FULL
    je .full
    cmp al, CAT_FOUR
    je .four
    cmp al, CAT_LITTLE
    je .little
    cmp al, CAT_BIG
    je .big
    cmp al, CAT_CHOICE
    je .choice
    mov bx, 6                   ; yacht
.yl:
    cmp byte [counts + bx], 5
    je .yes
    dec bx
    jnz .yl
    jmp .zero
.yes:
    mov ax, 50
    jmp .done
.choice:
    mov ax, [sum]
    jmp .done
.full:
    xor cx, cx
    mov bx, 6
.fl:
    mov al, [counts + bx]
    cmp al, 3
    jne .f2
    or cl, 1
.f2:
    cmp al, 2
    jne .f3
    or cl, 2
.f3:
    dec bx
    jnz .fl
    cmp cl, 3
    jne .zero
    mov ax, [sum]
    jmp .done
.four:
    mov bx, 6
.ol:
    cmp byte [counts + bx], 4
    jae .ofound
    dec bx
    jnz .ol
    jmp .zero
.ofound:
    mov ax, bx
    shl ax, 1
    shl ax, 1
    jmp .done
.little:
    mov bx, 1
    jmp .straight
.big:
    mov bx, 2
.straight:
    mov cx, 5
.sl:
    cmp byte [counts + bx], 1
    jne .zero
    inc bx
    loop .sl
    mov ax, 30
    jmp .done
.zero:
    xor ax, ax
.done:
    pop cx
    pop bx
    ret

; AL=category. Returns BX=offset of the current player's score slot.
slot_of:
    push ax
    xor ah, ah
    mov bx, ax
    cmp byte [cur], 0
    je .p
    add bx, NUM_CATS
.p:
    shl bx, 1
    add bx, scores
    pop ax
    ret

; AL=player. Returns AX=total of the filled categories.
player_total:
    push bx
    push cx
    mov bx, scores
    or al, al
    jz .p
    add bx, NUM_CATS * 2
.p:
    xor ax, ax
    mov cx, NUM_CATS
.l:
    cmp word [bx], EMPTY
    je .s
    add ax, [bx]
.s:
    add bx, 2
    loop .l
    pop cx
    pop bx
    ret

; ---------------------------------------------------------------------------
; Board drawing
; ---------------------------------------------------------------------------
draw_board:
    xor bx, bx
    xor dx, dx
    mov cx, 320
    mov si, 200
    mov al, C_BLUE
    call fill_rect
    call draw_header
    call draw_rows
    call draw_totals
    call draw_dice
    call draw_rolls
    call draw_help
    ret

draw_header:
    push si
    mov bx, 4
    mov dx, 2
    mov cx, 176
    mov si, 12
    mov al, C_RED
    call fill_rect
    mov ax, (C_WHITE << 8) | C_RED
    call set_colors
    mov si, str_scorecard
    mov bx, 8
    mov dx, 4
    call draw_str
    ; column labels, the active player highlighted
    mov si, label_p1
    mov di, label_p2
    cmp byte [game_mode], 1
    jne .names
    mov si, label_you
    mov di, label_skp
.names:
    xor al, al
    mov bx, COL_P0
    call draw_label
    mov si, di
    mov al, 1
    mov bx, COL_P1
    call draw_label
    pop si
    ret

; SI=label BX=x AL=player.
draw_label:
    cmp al, [cur]
    jne .plain
    push ax
    mov ax, (C_BLACK << 8) | C_YELLOW
    call set_colors
    pop ax
    push si
    push ax
    mov dx, 2
    mov cx, 26
    sub bx, 2
    mov si, 12
    mov al, C_YELLOW
    call fill_rect
    add bx, 2
    pop ax
    pop si
    jmp .t
.plain:
    push ax
    mov ax, (C_WHITE << 8) | C_RED
    call set_colors
    pop ax
.t:
    mov dx, 4
    call draw_str
    ret

draw_rows:
    push ax
    xor al, al
.l:
    call draw_row
    inc al
    cmp al, NUM_CATS
    jb .l
    pop ax
    ret

; AL=category.
draw_row:
    push ax
    push bx
    push cx
    push dx
    push si
    mov [row_cat], al
    mov cl, ROW_STEP
    mul cl
    add ax, ROW_TOP
    mov [row_y], ax
    mov dx, ax
    mov ah, C_LGRAY
    cmp byte [show_cursor], 0
    je .bg
    mov al, [row_cat]
    cmp al, [cursor]
    jne .bg
    mov ah, C_YELLOW
.bg:
    mov [row_bg], ah
    mov bx, 4
    mov cx, 176
    mov si, 12
    mov al, ah
    call fill_rect
    mov ah, C_BLACK
    mov al, [row_bg]
    call set_colors
    mov bl, [row_cat]
    xor bh, bh
    shl bx, 1
    mov si, [cat_names + bx]
    mov bx, 8
    mov dx, [row_y]
    add dx, 2
    call draw_str
    mov al, 0
    mov bx, COL_P0
    call draw_cell
    mov al, 1
    mov bx, COL_P1
    call draw_cell
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

%include "game.asm"
%include "data.asm"
