; ---------------------------------------------------------------------------
; Tables, text, music and working storage. Included by yacht.asm.
; ---------------------------------------------------------------------------
section .data

%include "notes_tbl.inc"

bank_tbl:   dw 0, 2000h, 4000h, 6000h
wave_cols:  db 1, 9, 3
wave_seq:   db 1, 9, 3, 1, 9, 3
sun_tbl:    db 6, 10, 12, 13, 14, 14, 14, 14, 14, 14, 13, 12, 10, 6, 0
cloud_tbl:  dw 20, 44, 44,  28, 40, 24,  12, 48, 60
            dw 226, 60, 50,  236, 56, 24,  218, 64, 66
            dw 0

; Grid positions inside a die. The die is 34 by 30 pixels.
pip_x:      db 6, 14, 22
pip_y:      db 5, 12, 19
pip_masks:  dw 0
            dw 000010000b               ; 1
            dw 100000001b               ; 2
            dw 100010001b               ; 3
            dw 101000101b               ; 4
            dw 101010101b               ; 5
            dw 101101101b               ; 6
die_x:      dw 186, 232, 278, 208, 254
die_y:      dw 18, 18, 18, 64, 64

; What each box typically earns. The Skipper fills the box that beats this
; figure by the most, so a poor roll lands in the cheapest box.
ai_expect:  db 2, 5, 8, 11, 14, 17, 15, 12, 8, 8, 21, 6

cat_names:  dw c_ones, c_twos, c_threes, c_fours, c_fives, c_sixes
            dw c_full, c_four, c_little, c_big, c_choice, c_yacht
c_ones:     db 'Ones', 0
c_twos:     db 'Twos', 0
c_threes:   db 'Threes', 0
c_fours:    db 'Fours', 0
c_fives:    db 'Fives', 0
c_sixes:    db 'Sixes', 0
c_full:     db 'Full House', 0
c_four:     db 'Four of Kind', 0
c_little:   db 'Little Strt', 0
c_big:      db 'Big Straight', 0
c_choice:   db 'Choice', 0
c_yacht:    db 'Yacht', 0

msg_bye:    db 'Thanks for sailing with YACHT!', 13, 10, '$'
msg_test:   db 'YACHT self test', 13, 10, '$'
msg_run:    db ' checks run, $'
msg_failed: db ' failed', 13, 10, '$'
name_spk:   db 'YACHT.SPK', 0
name_best:  db 'YACHT.HI', 0

str_yacht:      db 'YACHT', 0
str_scorecard:  db 'SCORECARD', 0
str_total:      db 'TOTAL', 0
str_hold:       db 'HOLD', 0
str_rolls:      db 'ROLLS LEFT', 0
str_best:       db 'BEST SCORE', 0
str_nospeech:   db 'NO VOICE', 0
label_p1:       db ' P1', 0
label_p2:       db ' P2', 0
label_you:      db 'YOU', 0
label_skp:      db 'SKP', 0
str_your_turn:  db 'YOUR TURN - SPACE TO ROLL', 0
str_p1_turn:    db 'PLAYER 1 - SPACE TO ROLL', 0
str_p2_turn:    db 'PLAYER 2 - SPACE TO ROLL', 0
str_again:      db 'SPACE ROLLS AGAIN, 1-5 HOLDS A DIE', 0
str_choose:     db 'CHOOSE A BOX, ENTER TO SCORE', 0
str_ai_turn:    db 'THE SKIPPER IS ROLLING', 0
str_you_win:    db 'YOU WIN! PRESS A KEY', 0
str_skp_wins:   db 'THE SKIPPER WINS. PRESS A KEY', 0
str_p1_wins:    db 'PLAYER 1 WINS! PRESS A KEY', 0
str_p2_wins:    db 'PLAYER 2 WINS! PRESS A KEY', 0
str_tie:        db 'A TIE! PRESS A KEY', 0

menu_lines: db '1  PLAY THE SKIPPER', 0
            db '2  TWO PLAYERS', 0
            db '3  WATCH A DEMO GAME', 0
            db 'M  SOUND ON OR OFF', 0
            db 'ESC  QUIT TO DOS', 0, 0
help_lines: db 'SPACE  roll', 0
            db '1-5    hold die', 0
            db 'UP/DN  pick box', 0
            db 'ENTER  score', 0
            db 'M      sound', 0
            db 'ESC    menu', 0, 0

; Five dice, category, expected score.
test_cases:
    db 1,1,2,3,4,  0
    dw 2
    db 6,6,6,2,1,  5
    dw 18
    db 3,3,3,5,5,  CAT_FULL
    dw 19
    db 3,3,3,3,5,  CAT_FULL
    dw 0
    db 1,1,1,1,1,  CAT_FULL
    dw 0
    db 4,4,4,4,1,  CAT_FOUR
    dw 16
    db 5,5,5,5,5,  CAT_FOUR
    dw 20
    db 4,4,4,1,1,  CAT_FOUR
    dw 0
    db 1,2,3,4,5,  CAT_LITTLE
    dw 30
    db 2,3,4,5,6,  CAT_LITTLE
    dw 0
    db 2,3,4,5,6,  CAT_BIG
    dw 30
    db 6,5,4,3,2,  CAT_BIG
    dw 30
    db 1,2,3,4,5,  CAT_BIG
    dw 0
    db 1,3,5,2,6,  CAT_CHOICE
    dw 17
    db 2,2,2,2,2,  CAT_YACHT
    dw 50
    db 2,2,2,2,3,  CAT_YACHT
    dw 0
test_end:

; ---- Music: note, ticks. Ticks run at 72.8 per second. 0FFh ends a voice.
LEN_E equ 10
LEN_Q equ 20
LEN_H equ 40

; "What Shall We Do with the Drunken Sailor", a traditional sea shanty.
%macro MEL_A 0
    db N_A4,LEN_Q, N_A4,LEN_E, N_A4,LEN_E, N_A4,LEN_Q, N_A4,LEN_E, N_A4,LEN_E
%endmacro
%macro MEL_B 0
    db N_A4,LEN_Q, N_D4,LEN_Q, N_F4,LEN_Q, N_A4,LEN_Q
%endmacro
%macro MEL_C 0
    db N_G4,LEN_Q, N_G4,LEN_E, N_G4,LEN_E, N_G4,LEN_Q, N_G4,LEN_E, N_G4,LEN_E
%endmacro
%macro MEL_D 0
    db N_G4,LEN_Q, N_C4,LEN_Q, N_E4,LEN_Q, N_G4,LEN_Q
%endmacro
%macro MEL_END 0
    db N_A4,LEN_Q, N_B4,LEN_Q, N_C5,LEN_Q, N_D5,LEN_Q
    db N_C5,LEN_Q, N_A4,LEN_Q, N_G4,LEN_Q, N_E4,LEN_Q
    db N_D4,LEN_H, N_D4,LEN_H
%endmacro
%macro BASS_D 0
    db N_D3,LEN_H, N_A3,LEN_H
%endmacro
%macro BASS_C 0
    db N_C3,LEN_H, N_G3,LEN_H
%endmacro
%macro BASS_VERSE 0
    BASS_D
    BASS_D
    BASS_C
    BASS_C
    BASS_D
    BASS_D
    BASS_C
    BASS_D
%endmacro
%macro STAB_D 0
    db 0,LEN_E, N_F3,LEN_E, 0,LEN_E, N_A3,LEN_E, 0,LEN_E, N_F3,LEN_E, 0,LEN_E, N_A3,LEN_E
%endmacro
%macro STAB_C 0
    db 0,LEN_E, N_E3,LEN_E, 0,LEN_E, N_G3,LEN_E, 0,LEN_E, N_E3,LEN_E, 0,LEN_E, N_G3,LEN_E
%endmacro
%macro STAB_VERSE 0
    STAB_D
    STAB_D
    STAB_C
    STAB_C
    STAB_D
    STAB_D
    STAB_C
    STAB_D
%endmacro

tune_title: dw t_mel, t_bass, t_stab
t_mel:
    MEL_A
    MEL_B
    MEL_C
    MEL_D
    MEL_A
    MEL_END
    db N_A4,LEN_H, N_A4,LEN_Q, N_A4,LEN_Q
    MEL_B
    db N_G4,LEN_H, N_G4,LEN_Q, N_G4,LEN_Q
    MEL_D
    db N_A4,LEN_H, N_A4,LEN_Q, N_A4,LEN_Q
    MEL_END
    db 0FFh
t_bass:
    BASS_VERSE
    BASS_VERSE
    db 0FFh
t_stab:
    STAB_VERSE
    STAB_VERSE
    db 0FFh

tune_score: dw s_a, 0, 0
s_a:    db N_C5,5, N_E5,5, N_G5,9, 0FFh
tune_bad:   dw b_a, 0, 0
b_a:    db N_E4,8, N_C4,14, 0FFh
tune_good:  dw g_a, g_b, 0
g_a:    db N_G4,6, N_C5,6, N_E5,6, N_G5,14, 0FFh
g_b:    db N_E4,12, N_G4,20, 0FFh
tune_yacht: dw y_a, y_b, y_c
y_a:    db N_C5,7, N_C5,7, N_C5,7, N_G5,12, N_E5,7, N_G5,7, N_C6,30, 0FFh
y_b:    db N_E4,21, N_E4,12, N_G4,14, N_G4,30, 0FFh
y_c:    db N_C4,21, N_C4,12, N_E4,14, N_E4,30, 0FFh
tune_win:   dw w_a, w_b, w_c
w_a:    db N_G4,8, N_C5,8, N_E5,8, N_G5,16, N_E5,8, N_G5,30, 0FFh
w_b:    db N_E4,24, N_G4,24, N_C5,30, 0FFh
w_c:    db N_C4,24, N_E4,24, N_G4,30, 0FFh
tune_lose:  dw l_a, l_b, 0
l_a:    db N_G4,14, N_E4,14, N_C4,14, N_G3,30, 0FFh
l_b:    db N_E3,28, N_C3,44, 0FFh

; Loudness per voice, 0 loudest. The tick driver fades each note a little.
v_base:     dw 1, 3, 6

ticks:      dw 0
pal_next:   dw 0
chain_cnt:  db 4
label_num:  db ' [ ]', 0

; ---------------------------------------------------------------------------
section .bss
bss_start:
row_off:    resw 200
font_tbl:   resb 95 * 8
font_ptr:   resw 1
cur_char:   resb 1
pair_tbl:   resb 4
xbyte:      resw 1
rowcnt:     resb 1
numbuf:     resb 8
big_color:  resb 1
big_x:      resw 1
big_rows:   resb 1
big_cols:   resb 1
big_bits:   resb 1
pal_phase:  resb 1

old8:       resw 2
music_on:   resb 1
tune_loop:  resb 1
mute:       resb 1
noise_new:  resb 1
noise_vol:  resb 1
v_ptr:      resw 3
v_start:    resw 3
v_left:     resw 3
v_vol:      resw 3
v_age:      resw 3

spk_ok:     resb 1
spk_seg:    resw 1
spk_page:   resw 1
spk_count:  resw 1
spk_ticks:  resw 1
spk_tbl:    resw 3 * 16

seed:       resw 1
counts:     resb 8
sum:        resw 1
dice:       resb 6
held:       resb 6
scores:     resw NUM_CATS * 2
cur:        resb 1
cursor:     resb 1
cursor_old: resb 1
chosen:     resb 1
rolls_left: resb 1
roll_frame: resb 1
show_cursor: resb 1
game_mode:  resb 1
quit_game:  resb 1
last_score: resw 1
tot0:       resw 1
tot1:       resw 1
best:       resw 1
end_clip:   resb 1
best_v:     resw 1
best_c:     resb 1

row_cat:    resb 1
row_bg:     resb 1
row_y:      resw 1
cell_x:     resw 1
cell_p:     resb 1
die_i:      resw 1
die_px:     resw 1
die_py:     resw 1
die_f:      resb 1
pip_bits:   resw 1

t_count:    resw 1
t_faces:    resw 7
bss_end:
