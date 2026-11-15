; ---------------------------------------------------------------------------
; Board drawing, title screen, game flow, computer opponent, files, self test.
; Included by yacht.asm.
; ---------------------------------------------------------------------------

; AL=player BX=x. Shows a score, or a preview in red for the player on turn.
draw_cell:
    push ax
    push bx
    push dx
    mov [cell_x], bx
    mov [cell_p], al
    mov bl, [row_cat]
    xor bh, bh
    or al, al
    jz .p
    add bx, NUM_CATS
.p:
    shl bx, 1
    mov ax, [scores + bx]
    mov dx, [row_y]
    add dx, 2
    mov bx, [cell_x]
    cmp ax, EMPTY
    je .empty
    push ax
    mov ah, C_BLACK
    mov al, [row_bg]
    call set_colors
    pop ax
    call draw_num
    jmp .x
.empty:
    mov al, [cell_p]
    cmp al, [cur]
    jne .x
    cmp byte [rolls_left], 3
    je .x
    mov al, [row_cat]
    call score_cat
    push ax
    mov ah, C_RED
    mov al, [row_bg]
    call set_colors
    pop ax
    call draw_num
.x:
    pop dx
    pop bx
    pop ax
    ret

draw_totals:
    mov bx, 4
    mov dx, TOTAL_Y
    mov cx, 176
    mov si, 13
    mov al, C_BLACK
    call fill_rect
    mov ax, (C_WHITE << 8) | C_BLACK
    call set_colors
    mov si, str_total
    mov bx, 8
    mov dx, TOTAL_Y + 3
    call draw_str
    xor al, al
    call player_total
    mov bx, COL_P0
    call draw_num
    mov al, 1
    call player_total
    mov bx, COL_P1
    call draw_num
    ret

draw_dice:
    push si
    xor si, si
.l:
    call draw_die
    inc si
    cmp si, 5
    jb .l
    pop si
    ret

; SI=die index. Preserves all registers.
draw_die:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov [die_i], si
    mov bx, si
    shl bx, 1
    mov ax, [die_x + bx]
    mov [die_px], ax
    mov ax, [die_y + bx]
    mov [die_py], ax
    mov al, [dice + si]
    mov [die_f], al
    mov ah, C_WHITE
    cmp byte [held + si], 0
    je .a
    mov ah, C_YELLOW
.a:
    cmp byte [die_f], 0
    jne .b
    mov ah, C_DGRAY
.b:
    mov al, ah
    mov bx, [die_px]
    mov dx, [die_py]
    mov cx, 34
    mov si, 30
    call fill_rect
    ; rounded corners
    mov al, C_BLUE
    mov cx, 2
    mov si, 2
    call fill_rect
    add bx, 32
    call fill_rect
    add dx, 28
    call fill_rect
    sub bx, 32
    call fill_rect
    ; pips
    mov al, [die_f]
    or al, al
    jz .label
    xor ah, ah
    mov bx, ax
    shl bx, 1
    mov ax, [pip_masks + bx]
    mov [pip_bits], ax
    xor di, di                  ; grid row
.pr:
    xor si, si                  ; grid column
.pc:
    shr word [pip_bits], 1
    jnc .pn
    mov bl, [pip_x + si]
    xor bh, bh
    add bx, [die_px]
    mov dl, [pip_y + di]
    xor dh, dh
    add dx, [die_py]
    push si
    mov cx, 6
    mov si, 6
    mov al, C_BLACK
    call fill_rect
    pop si
.pn:
    inc si
    cmp si, 3
    jb .pc
    inc di
    cmp di, 3
    jb .pr
.label:
    mov si, [die_i]
    mov bx, [die_px]
    add bx, 2
    mov dx, [die_py]
    add dx, 32
    cmp byte [held + si], 0
    je .free
    mov ax, (C_BLACK << 8) | C_YELLOW
    call set_colors
    mov si, str_hold
    call draw_str
    jmp .x
.free:
    mov ax, (C_LCYAN << 8) | C_BLUE
    call set_colors
    mov ax, si
    add al, '1'
    mov [label_num + 2], al
    mov si, label_num
    call draw_str
.x:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_rolls:
    mov ax, (C_WHITE << 8) | C_BLUE
    call set_colors
    mov si, str_rolls
    mov bx, 186
    mov dx, 112
    call draw_str
    mov al, [rolls_left]
    xor ah, ah
    mov bx, 270
    call draw_num
    ret

draw_help:
    mov ax, (C_LCYAN << 8) | C_BLUE
    call set_colors
    mov si, help_lines
    mov dx, 126
.l:
    mov bx, 186
    call draw_str
.skip:
    lodsb
    or al, al
    jnz .skip
    add dx, 10
    cmp byte [si], 0
    jne .l
    ret

; SI=message. Preserves SI.
set_status:
    push si
    xor bx, bx
    mov dx, 186
    mov cx, 320
    mov si, 14
    mov al, C_BLACK
    call fill_rect
    mov ax, (C_YELLOW << 8) | C_BLACK
    call set_colors
    pop si
    mov bx, 8
    mov dx, 189
    call draw_str
    ret

; ---------------------------------------------------------------------------
; Title screen
; ---------------------------------------------------------------------------
draw_title:
    ; sky
    xor bx, bx
    xor dx, dx
    mov cx, 320
    mov si, 112
    mov al, C_LCYAN
    call fill_rect
    ; clouds
    mov si, cloud_tbl
.cl:
    lodsw
    or ax, ax
    jz .sun
    mov bx, ax
    lodsw
    mov dx, ax
    lodsw
    mov cx, ax
    push si
    mov si, 4
    mov al, C_WHITE
    call fill_rect
    pop si
    jmp .cl
.sun:
    mov di, sun_tbl
    mov dx, 4
.sl:
    mov al, [di]
    or al, al
    jz .sea
    xor ah, ah
    mov cx, ax
    shl cx, 1
    mov bx, 272
    sub bx, ax
    and bx, 0FFFEh
    mov si, 2
    mov al, C_YELLOW
    call fill_rect
    inc di
    add dx, 2
    jmp .sl
.sea:
    ; water: dashes in the three cycling colors
    mov dx, 112
    xor di, di                  ; band phase
.band:
    xor bx, bx
    mov ax, di
.dash:
    push ax
    push bx
    mov bx, ax
    mov al, [wave_cols + bx]
    pop bx
    mov cx, 32
    mov si, 4
    call fill_rect
    pop ax
    inc ax
    cmp ax, 3
    jb .nw
    xor ax, ax
.nw:
    add bx, 32
    cmp bx, 320
    jb .dash
    add dx, 4
    inc di
    cmp di, 3
    jb .nb
    xor di, di
.nb:
    cmp dx, 200
    jb .band
    ; mast and flag
    mov bx, 158
    mov dx, 40
    mov cx, 2
    mov si, 68
    mov al, C_BROWN
    call fill_rect
    mov bx, 160
    mov cx, 12
    mov si, 6
    mov al, C_RED
    call fill_rect
    ; mainsail
    xor di, di
.ms:
    mov cx, di
    add cx, 2
    and cx, 0FFFEh
    mov bx, 162
    mov dx, di
    add dx, 48
    mov si, 1
    mov al, C_WHITE
    call fill_rect
    inc di
    cmp di, 56
    jb .ms
    ; jib
    xor di, di
.jib:
    mov cx, di
    mov ax, di
    shr ax, 1
    shr ax, 1
    sub cx, ax
    add cx, 2
    and cx, 0FFFEh
    mov bx, 156
    sub bx, cx
    mov dx, di
    add dx, 54
    mov si, 1
    mov al, C_LGRAY
    call fill_rect
    inc di
    cmp di, 50
    jb .jib
    ; hull
    xor di, di
.hull:
    mov ax, di
    shl ax, 1
    mov bx, 100
    add bx, ax
    mov cx, 120
    shl ax, 1
    sub cx, ax
    mov dx, di
    add dx, 106
    mov si, 1
    mov al, C_RED
    cmp di, 2
    jae .hc
    mov al, C_WHITE
.hc:
    call fill_rect
    inc di
    cmp di, 12
    jb .hull
    ; name, with a drop shadow
    mov si, str_yacht
    mov bx, 82
    mov dx, 6
    mov al, C_BLACK
    call draw_big
    mov bx, 80
    mov dx, 4
    mov al, C_RED
    call draw_big
    ; menu panel
    mov bx, 56
    mov dx, 126
    mov cx, 208
    mov si, 66
    mov al, C_BLACK
    call fill_rect
    mov ax, (C_WHITE << 8) | C_BLACK
    call set_colors
    mov si, menu_lines
    mov dx, 130
.ml:
    mov bx, 68
    call draw_str
.mskip:
    lodsb
    or al, al
    jnz .mskip
    add dx, 10
    cmp byte [si], 0
    jne .ml
    mov ax, (C_YELLOW << 8) | C_BLACK
    call set_colors
    mov si, str_best
    mov bx, 68
    mov dx, 181
    call draw_str
    mov ax, [best]
    mov bx, 156
    call draw_num
    cmp byte [spk_ok], 0
    jne .voice
    mov si, str_nospeech
    mov bx, 192
    call draw_str
.voice:
    ret

; Returns AL=game mode, or 0FFh to quit.
title_screen:
    call draw_title
    mov si, tune_title
    mov al, 1
    call play_tune
    mov al, SPK_WELCOME
    call speak
.loop:
    call wait_vsync
    call pal_cycle
    mov ah, 1
    int 16h
    jz .loop
    xor ah, ah
    int 16h
    cmp al, '1'
    je .vs
    cmp al, '2'
    je .two
    cmp al, '3'
    je .demo
    cmp al, 27
    je .quit
    or al, 20h
    cmp al, 'm'
    jne .loop
    call toggle_mute
    jmp .loop
.vs:
    mov al, 1
    jmp .go
.two:
    xor al, al
    jmp .go
.demo:
    mov al, 2
    jmp .go
.quit:
    mov al, 0FFh
.go:
    push ax
    call stop_tune
    call wait_vsync
    call pal_reset
    pop ax
    ret

; ---------------------------------------------------------------------------
; Game flow
; ---------------------------------------------------------------------------
play_game:
    mov byte [quit_game], 0
    mov bx, scores
    mov cx, NUM_CATS * 2
.clr:
    mov word [bx], EMPTY
    add bx, 2
    loop .clr
    mov byte [cur], 0
    mov byte [show_cursor], 0
    call clear_dice
    call draw_board
.turn:
    call start_turn
    call is_ai
    jc .ai
    call human_turn
    jmp .after
.ai:
    call ai_turn
.after:
    cmp byte [quit_game], 0
    jne .exit
    call apply_score
    cmp byte [quit_game], 0
    jne .exit
    call board_full
    jc .over
    xor byte [cur], 1
    jmp .turn
.over:
    call game_over
.exit:
    call stop_tune
    ret

clear_dice:
    xor ax, ax
    mov [dice], ax
    mov [dice + 2], ax
    mov [dice + 4], al
    mov [held], ax
    mov [held + 2], ax
    mov [held + 4], al
    mov byte [rolls_left], 3
    ret

start_turn:
    call clear_dice
    mov byte [show_cursor], 0
    call draw_header
    call draw_rows
    call draw_totals
    call draw_dice
    call draw_rolls
    ret

; Sets carry when the player on turn is played by the computer.
is_ai:
    cmp byte [game_mode], 2
    je .yes
    cmp byte [game_mode], 1
    jne .no
    cmp byte [cur], 1
    je .yes
.no:
    clc
    ret
.yes:
    stc
    ret

; Sets carry when every box on the card is filled.
board_full:
    mov bx, scores
    mov cx, NUM_CATS * 2
.l:
    cmp word [bx], EMPTY
    je .no
    add bx, 2
    loop .l
    stc
    ret
.no:
    clc
    ret

first_open:
    xor al, al
.l:
    call slot_of
    cmp word [bx], EMPTY
    je .f
    inc al
    cmp al, NUM_CATS
    jb .l
    xor al, al
.f:
    mov [cursor], al
    ret

; AL=+1 or -1. Moves the cursor to the next open box.
move_cursor:
    mov ah, al
    mov al, [cursor]
    mov [cursor_old], al
.l:
    add al, ah
    cmp al, 0FFh
    jne .hi
    mov al, NUM_CATS - 1
.hi:
    cmp al, NUM_CATS
    jb .chk
    xor al, al
.chk:
    call slot_of
    cmp word [bx], EMPTY
    jne .l
    mov [cursor], al
    call draw_row
    mov al, [cursor_old]
    call draw_row
    ret

human_turn:
    call first_open
    mov byte [show_cursor], 1
    call draw_rows
    mov si, str_your_turn
    cmp byte [game_mode], 1
    je .st
    mov si, str_p1_turn
    cmp byte [cur], 0
    je .st
    mov si, str_p2_turn
.st:
    call set_status
.k:
    xor ah, ah
    int 16h
    cmp al, 27
    je .esc
    cmp al, ' '
    je .roll
    cmp al, 13
    je .enter
    cmp ah, 48h
    je .up
    cmp ah, 50h
    je .down
    cmp al, '1'
    jb .other
    cmp al, '5'
    jbe .hold
.other:
    or al, 20h
    cmp al, 'm'
    je .mute
    cmp al, 'w'
    je .up
    cmp al, 's'
    je .down
    jmp .k
.mute:
    call toggle_mute
    jmp .k
.up:
    mov al, 0FFh
    call move_cursor
    jmp .k
.down:
    mov al, 1
    call move_cursor
    jmp .k
.roll:
    cmp byte [rolls_left], 0
    je .k
    call roll_dice
    call draw_rows
    mov si, str_again
    cmp byte [rolls_left], 0
    jne .rs
    mov si, str_choose
.rs:
    call set_status
    jmp .k
.hold:
    cmp byte [rolls_left], 3
    je .k
    cmp byte [rolls_left], 0
    je .k
    sub al, '1'
    xor ah, ah
    mov si, ax
    xor byte [held + si], 1
    call draw_die
    call sfx_click
    jmp .k
.enter:
    cmp byte [rolls_left], 3
    je .k
    mov al, [cursor]
    mov [chosen], al
    mov byte [show_cursor], 0
    ret
.esc:
    mov byte [quit_game], 1
    ret

; Tumbles every die that is not held. The last frame is the result.
roll_dice:
    dec byte [rolls_left]
    mov byte [roll_frame], 10
.f:
    xor si, si
.d:
    cmp byte [held + si], 0
    jne .n
    call roll1
    mov [dice + si], al
    call draw_die
.n:
    inc si
    cmp si, 5
    jb .d
    call sfx_click
    mov cx, 4
    call wait_ticks
    dec byte [roll_frame]
    jnz .f
    call draw_rolls
    ret

; Records the chosen box, then reacts with sound and speech.
apply_score:
    mov al, [chosen]
    call score_cat
    mov [last_score], ax
    mov al, [chosen]
    call slot_of
    mov ax, [last_score]
    mov [bx], ax
    mov byte [show_cursor], 0
    mov byte [rolls_left], 3
    call draw_rows
    call draw_totals
    mov bl, [chosen]
    xor bh, bh
    shl bx, 1
    mov si, [cat_names + bx]
    call set_status
    mov ax, [last_score]
    mov bx, 130
    mov dx, 189
    call draw_num
    mov ax, [last_score]
    or ax, ax
    jz .bad
    mov al, [chosen]
    cmp al, CAT_YACHT
    je .yacht
    cmp al, CAT_FULL
    je .full
    cmp al, CAT_FOUR
    je .four
    cmp al, CAT_LITTLE
    je .straight
    cmp al, CAT_BIG
    je .straight
    mov si, tune_score
    jmp .play
.bad:
    mov si, tune_bad
.play:
    xor al, al
    call play_tune
    jmp .wait
.yacht:
    mov si, tune_yacht
    xor al, al
    call play_tune
    mov al, SPK_YACHT
    jmp .say
.full:
    mov al, SPK_FULLHOUSE
    jmp .sayg
.four:
    mov al, SPK_FOUR
    jmp .sayg
.straight:
    mov al, SPK_STRAIGHT
.sayg:
    mov si, tune_good
    push ax
    xor al, al
    call play_tune
    pop ax
.say:
    call speak
.wait:
    mov cx, 70
    call ai_wait
    call wait_speech
    ret

game_over:
    xor al, al
    call player_total
    mov [tot0], ax
    mov al, 1
    call player_total
    mov [tot1], ax
    cmp byte [game_mode], 2
    je .nobest
    mov ax, [tot0]
    cmp byte [game_mode], 1
    je .chk
    cmp ax, [tot1]
    jae .chk
    mov ax, [tot1]
.chk:
    cmp ax, [best]
    jbe .nobest
    mov [best], ax
    call save_best
.nobest:
    mov di, tune_win
    mov ax, [tot0]
    cmp ax, [tot1]
    je .tie
    ja .p0
    mov si, str_p2_wins
    mov al, SPK_P2WINS
    cmp byte [game_mode], 1
    jne .report
    mov si, str_skp_wins
    mov al, SPK_SKIPPER
    mov di, tune_lose
    jmp .report
.p0:
    mov si, str_p1_wins
    mov al, SPK_P1WINS
    cmp byte [game_mode], 1
    jne .report
    mov si, str_you_win
    mov al, SPK_YOUWIN
    jmp .report
.tie:
    mov si, str_tie
    mov al, SPK_TIE
    mov di, tune_good
.report:
    mov [end_clip], al
    call set_status
    mov si, di
    xor al, al
    call play_tune
    mov al, [end_clip]
    call speak
    cmp byte [game_mode], 2
    je .demo
    xor ah, ah
    int 16h
    ret
.demo:
    mov cx, 400
    call ai_wait
    ret

; ---------------------------------------------------------------------------
; Computer opponent, the Skipper
; ---------------------------------------------------------------------------
ai_turn:
    mov si, str_ai_turn
    call set_status
    mov cx, 30
    call ai_wait
.r:
    cmp byte [quit_game], 0
    jne .x
    call roll_dice
    call draw_rows
    mov cx, 50
    call ai_wait
    cmp byte [rolls_left], 0
    je .pick
    call ai_satisfied
    jc .pick
    call ai_holds
    call draw_dice
    mov cx, 45
    call ai_wait
    jmp .r
.pick:
    call ai_pick
    mov [chosen], al
    mov [cursor], al
    mov byte [show_cursor], 1
    call draw_rows
    mov cx, 40
    call ai_wait
    mov byte [show_cursor], 0
.x:
    ret

; AL=category. Sets carry if it is open and scores above zero now.
ai_scores_now:
    push ax
    call slot_of
    cmp word [bx], EMPTY
    pop ax
    jne .no
    call score_cat
    or ax, ax
    jz .no
    stc
    ret
.no:
    clc
    ret

; Sets carry when the dice are good enough to stop rolling.
ai_satisfied:
    mov al, CAT_YACHT
    call ai_scores_now
    jc .r
    mov al, CAT_LITTLE
    call ai_scores_now
    jc .r
    mov al, CAT_BIG
    call ai_scores_now
    jc .r
    mov al, CAT_FULL
    call ai_scores_now
    jc .r
    mov al, CAT_FOUR
    call slot_of
    cmp word [bx], EMPTY
    jne .no
    mov al, CAT_FOUR
    call score_cat
    cmp ax, 20
    jae .yes
.no:
    clc
.r:
    ret
.yes:
    stc
    ret

; Returns AL=the open box with the best score against its typical value.
ai_pick:
    mov word [best_v], 8000h
    mov byte [best_c], 0
    xor cx, cx
.l:
    mov al, cl
    call slot_of
    cmp word [bx], EMPTY
    jne .n
    mov al, cl
    call score_cat
    mov bx, cx
    mov dl, [ai_expect + bx]
    xor dh, dh
    sub ax, dx
    cmp ax, [best_v]
    jle .n
    mov [best_v], ax
    mov [best_c], cl
.n:
    inc cx
    cmp cx, NUM_CATS
    jb .l
    mov al, [best_c]
    ret

; AL=face. Holds every die showing it.
hold_all:
    xor si, si
.l:
    cmp [dice + si], al
    jne .n
    mov byte [held + si], 1
.n:
    inc si
    cmp si, 5
    jb .l
    ret

; AL=face. Holds the first die showing it.
hold_one:
    xor si, si
.l:
    cmp [dice + si], al
    je .h
    inc si
    cmp si, 5
    jb .l
    ret
.h:
    mov byte [held + si], 1
    ret

; Chooses which dice to keep before the next roll.
ai_holds:
    xor ax, ax
    mov [held], ax
    mov [held + 2], ax
    mov [held + 4], al
    call count_dice
    xor dx, dx                  ; DL=different faces, DH=largest group
    mov bx, 1
.d:
    mov al, [counts + bx]
    or al, al
    jz .dn
    inc dl
    cmp al, dh
    jbe .dn
    mov dh, al
.dn:
    inc bx
    cmp bx, 7
    jb .d
    ; chase a straight
    cmp dl, 4
    jb .nost
    cmp dh, 2
    ja .nost
    mov al, CAT_LITTLE
    call slot_of
    mov cx, [bx]
    mov al, CAT_BIG
    call slot_of
    mov ax, [bx]
    or ax, cx
    cmp ax, EMPTY
    jne .nost
    mov dl, 1                   ; first face to keep
    mov dh, 6                   ; last face to keep
    cmp byte [counts + 1], 0
    je .sh
    cmp byte [counts + 6], 0
    je .sh
    mov al, CAT_BIG
    call slot_of
    cmp word [bx], EMPTY
    jne .droph
    mov dl, 2
    jmp .sh
.droph:
    mov dh, 5
.sh:
    mov bl, dl
    xor bh, bh
.sl:
    cmp byte [counts + bx], 0
    je .sn
    mov al, bl
    call hold_one
.sn:
    inc bl
    cmp bl, dh
    jbe .sl
    ret
.nost:
    ; two pairs chase a full house
    mov al, CAT_FULL
    call slot_of
    cmp word [bx], EMPTY
    jne .face
    xor cl, cl
    mov bx, 1
.pc:
    cmp byte [counts + bx], 2
    jne .pn
    inc cl
.pn:
    inc bx
    cmp bx, 7
    jb .pc
    cmp cl, 2
    jne .face
    mov bx, 1
.ph:
    cmp byte [counts + bx], 2
    jne .phn
    mov al, bl
    call hold_all
.phn:
    inc bx
    cmp bx, 7
    jb .ph
    ret
.face:
    ; keep the most promising group of matching dice
    xor cx, cx                  ; CL=best weight CH=best face
    mov bx, 1
.fl:
    mov al, [counts + bx]
    or al, al
    jz .fn
    shl al, 1
    shl al, 1
    shl al, 1
    add al, bl
    mov dl, al
    push bx
    mov al, bl
    dec al
    call slot_of
    cmp word [bx], EMPTY
    pop bx
    jne .noopen
    add dl, 6
.noopen:
    cmp dl, cl
    jbe .fn
    mov cl, dl
    mov ch, bl
.fn:
    inc bx
    cmp bx, 7
    jb .fl
    mov bl, ch
    xor bh, bh
    cmp byte [counts + bx], 2
    jae .keep
    cmp ch, 5
    jb .none
.keep:
    mov al, ch
    call hold_all
.none:
    ret

; ---------------------------------------------------------------------------
; Disk files
; ---------------------------------------------------------------------------
load_best:
    mov word [best], 0
    mov dx, name_best
    mov ax, 3D00h
    int 21h
    jc .r
    mov bx, ax
    mov dx, best
    mov cx, 2
    mov ah, 3Fh
    int 21h
    mov ah, 3Eh
    int 21h
.r:
    ret

save_best:
    mov dx, name_best
    xor cx, cx
    mov ah, 3Ch
    int 21h
    jc .r
    mov bx, ax
    mov dx, best
    mov cx, 2
    mov ah, 40h
    int 21h
    mov ah, 3Eh
    int 21h
.r:
    ret

; ---------------------------------------------------------------------------
; Self test: YACHT /T
; ---------------------------------------------------------------------------
selftest:
    mov dx, msg_test
    mov ah, 9
    int 21h
    xor bp, bp
    mov word [t_count], 0
    mov si, test_cases
.t:
    cmp si, test_end
    jae .rng
    mov di, dice
    mov cx, 5
    rep movsb
    lodsb
    call score_cat
    mov bx, ax
    lodsw
    inc word [t_count]
    cmp ax, bx
    je .t
    inc bp
    jmp .t
.rng:
    ; 6000 rolls should spread evenly over the six faces
    mov word [seed], 1234
    xor ax, ax
    xor bx, bx
.z:
    mov [t_faces + bx], ax
    add bx, 2
    cmp bx, 14
    jb .z
    mov cx, 6000
.r:
    call roll1
    mov bx, ax
    shl bx, 1
    inc word [t_faces + bx]
    loop .r
    mov bx, 2
.chk:
    inc word [t_count]
    mov ax, [t_faces + bx]
    cmp ax, 880
    jb .bad
    cmp ax, 1120
    jbe .good
.bad:
    inc bp
.good:
    add bx, 2
    cmp bx, 14
    jb .chk
    mov ax, [t_count]
    call print_dec
    mov dx, msg_run
    mov ah, 9
    int 21h
    mov ax, bp
    call print_dec
    mov dx, msg_failed
    mov ah, 9
    int 21h
    mov al, 0
    or bp, bp
    jz .x
    mov al, 1
.x:
    mov ah, 4Ch
    int 21h

; AX=value, printed with DOS.
print_dec:
    mov si, numbuf + 5
    mov byte [si], '$'
    mov cx, 10
.d:
    xor dx, dx
    div cx
    add dl, '0'
    dec si
    mov [si], dl
    or ax, ax
    jnz .d
    mov dx, si
    mov ah, 9
    int 21h
    ret
