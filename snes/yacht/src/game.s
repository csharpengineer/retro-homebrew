; The game screen and turn flow, following tandy1000/yacht/src/game.asm play_game.
.INCLUDE "build/gfx/game_consts.inc"

.DEFINE HILITE_HDMA $1300       ; window table for the scorecard row highlight
.DEFINE CARD_ROW0   3           ; text row of the first box
.DEFINE COL_P0      13          ; rightmost digit of player 0's scores (and of its name)
.DEFINE COL_P1      17          ; the card's column rules sit at x=87 and x=116 (game.js)
.DEFINE PANEL_COL   20          ; right-hand panel text starts here
.DEFINE ROW_BANNER  1
.DEFINE ROW_ROLLS   16
.DEFINE ROW_TOT0    18
.DEFINE ROW_TOT1    20
.DEFINE ROW_STATUS  23
.DEFINE TUMBLE_FRAMES 24

.SECTION "Game" FREE

GameRun:
  lda title_choice
  sta game_mode
  lda #1
  sta in_game
  sta game_state
  stz quit_game
  stz paused
  stz dim_all
  stz tumble_t
  stz cur
  stz focus
  ldx #0
  A16
  lda #EMPTY
@clr:
  sta scores,x
  inx
  inx
  cpx #NUM_CATS*4
  bne @clr
  A8
  jsr ClearDice
  jsr ScreenOff
  jsr GameSetup
  jsr DrawBoard
  jsr GameFadeIn

@turn:
  jsr StartTurn
  jsr IsAi
  bcs @ai
  jsr HumanTurn
  bra @after
@ai:
  jsr AiTurn
@after:
  lda quit_game
  bne @exit
  jsr ApplyScore
  lda quit_game       ; (a button during the demo)
  bne @exit
  jsr BoardFull
  bcs @over
  lda cur
  eor #1
  sta cur
  bra @turn
@over:
  jsr GameOver
@exit:
  lda #AC_STOP
  jsr AudioCmd
  jsr GameFadeOut
  stz in_game
  rts

; ---------------------------------------------------------------- setup

GameSetup:
  lda #$09
  sta BGMODE
  lda #$50
  sta BG1SC
  lda #$54
  sta BG2SC
  lda #$58
  sta BG3SC
  stz BG12NBA
  lda #$04
  sta BG34NBA
  lda #$63
  sta OBSEL
  lda #$17
  sta TM
  stz TS
  jsr ScrollReset
  ; a warm glow on the scorecard row under the cursor: add a color inside window 1
  lda #$10
  sta CGWSEL
  lda #$01            ; add, on BG1 only
  sta CGADSUB
  lda #$27
  sta COLDATA
  lda #$45
  sta COLDATA
  lda #$80
  sta COLDATA
  lda #$20
  sta WOBJSEL
  ldx #GameBgChr
  stx dma_src
  lda #:GameBgChr
  sta dma_bank
  ldy #$0000
  ldx #GameBgChrEnd-GameBgChr
  jsr LoadVram
  ldx #GameBg1Map
  stx dma_src
  lda #:GameBg1Map
  sta dma_bank
  ldy #$5000
  ldx #2048
  jsr LoadVram
  ldx #GameBg2Map
  stx dma_src
  lda #:GameBg2Map
  sta dma_bank
  ldy #$5400
  ldx #2048
  jsr LoadVram
  ldx #GameSprChr
  stx dma_src
  lda #:GameSprChr
  sta dma_bank
  ldy #$6000
  ldx #GameSprChrEnd-GameSprChr
  jsr LoadVram
  jsr LoadFont
  ldx #GamePal
  stx dma_src
  lda #:GamePal
  sta dma_bank
  lda #32
  ldx #448
  jsr SetColors
  ; HDMA channel 4: the highlight window. Channels 1-3 stay off.
  lda #$01
  sta $4340
  lda #<WH0
  sta $4341
  ldx #HILITE_HDMA
  stx $4342
  stz $4344
  stz hilite_on
  jsr BuildHilite
  lda #$10
  sta hdma_en
  rts

GameFadeIn:
  stz tmp3
@l:
  jsr GameSprites
  jsr WaitFrame
  lda tmp3
  sta inidisp_v
  inc tmp3
  lda tmp3
  cmp #16
  bne @l
  rts

GameFadeOut:
  lda #15
  sta tmp3
@l:
  jsr GameSprites
  jsr WaitFrame
  lda tmp3
  sta inidisp_v
  dec tmp3
  bpl @l
  rts

; ---------------------------------------------------------------- turn helpers

ClearDice:
  ldx #0
@l:
  stz dice,x
  stz held,x
  inx
  cpx #5
  bne @l
  lda #3
  sta rolls_left
  rts

StartTurn:
  jsr ClearDice
  stz hilite_on
  stz focus
  stz die_sel
  jsr DrawBoard
  rts

; Carry set when the player on turn is the computer.
IsAi:
  lda game_mode
  cmp #2
  beq @yes
  cmp #1
  bne @no
  lda cur
  cmp #1
  beq @yes
@no:
  clc
  rts
@yes:
  sec
  rts

; Carry set when every box on the card is filled.
BoardFull:
  ldx #0
  A16
@l:
  lda scores,x
  cmp #EMPTY
  beq @no
  inx
  inx
  cpx #NUM_CATS*4
  bne @l
  A8
  sec
  rts
@no:
  A8
  clc
  rts

; Puts the cursor on the first open box of the player on turn.
FirstOpen:
  stz cursor
@l:
  lda cursor
  jsr IsOpen
  bcs @r
  inc cursor
  lda cursor
  cmp #NUM_CATS
  bne @l
  stz cursor
@r:
  rts

; A = 1 or $FF. Moves the cursor to the next open box, wrapping around.
MoveCursor:
  sta tmp3
  lda cursor
@l:
  clc
  adc tmp3
  cmp #$FF
  bne @hi
  lda #NUM_CATS-1
@hi:
  cmp #NUM_CATS
  bcc @chk
  lda #0
@chk:
  jsr IsOpen
  bcc @l
  sta cursor
  rts

; Returns A16-safe: new presses for whoever controls the player on turn.
; Player 1 (cur 0) uses controller 1; player 2 uses controller 2, or
; controller 1 when no second controller is plugged in.
TurnPad:
  lda game_mode
  bne @both           ; vs Skipper or demo: either controller
  lda cur
  beq @p1
  lda pad2_on
  beq @p1             ; one controller: it plays both sides
  A16
  lda pad2_new
  sta turn_pad
  A8
  rts
@p1:
  A16
  lda pad1_new
  sta turn_pad
  A8
  rts
@both:
  A16
  lda pad1_new
  ora pad2_new
  sta turn_pad
  A8
  rts

; ---------------------------------------------------------------- one frame

; Draws the sprites, waits for the frame, and handles mute (any time).
; During the demo any button ends it (quit_game).
GameFrame:
  jsr GameSprites
  jsr WaitFrame
  A16
  lda pad1_new
  ora pad2_new
  and #BTN_SELECT
  A8
  beq @nomute
  jsr ToggleMute
@nomute:
  lda game_mode
  cmp #2
  bne @r
  A16
  lda pad1_new
  ora pad2_new
  A8
  beq @r
  lda #1
  sta quit_game
@r:
  rts

GameDelay:          ; X = frames; returns early if the game is being quit
@l:
  phx
  jsr GameFrame
  plx
  lda quit_game
  bne @r
  dex
  bne @l
@r:
  rts

; ---------------------------------------------------------------- human turn

HumanTurn:
  jsr FirstOpen
  jsr StatusYourTurn
@k:
  stz game_state
  jsr GameFrame
  jsr TurnPad
  A16
  lda turn_pad
  A8
  bne @key
  bra @k
@key:
  A16
  lda turn_pad
  and #BTN_START
  A8
  beq @nopause
  jsr Pause
  lda quit_game
  beq @k
  rts
@nopause:
  lda focus
  beq @tray
  jmp @card

@tray:
  ; X rolls. A makes the first roll too (nothing to hold yet); after that A
  ; holds or releases the die under the cursor, so it can't reroll by mistake.
  A16
  lda turn_pad
  and #BTN_X
  A8
  bne @roll
  A16
  lda turn_pad
  and #BTN_A
  A8
  beq @t1
  lda rolls_left
  cmp #3
  beq @roll
  jmp @hold
@roll:
  lda rolls_left
  bne @doroll
  jmp @k
@doroll:
  jsr RollDice
  lda rolls_left
  bne @again
  lda #1
  sta focus
  jsr ShowHilite
  jsr StatusChoose
  jmp @k
@again:
  jsr StatusAgain
  jmp @k
@t1:
  A16
  lda turn_pad
  and #BTN_LEFT|BTN_L
  A8
  beq @t2
  lda die_sel
  bne @dl
  lda #5
@dl:
  dec a
  sta die_sel
  ldx #SFX_TICK
  lda #AC_SFX
  jsr AudioCmd
  jmp @k
@t2:
  A16
  lda turn_pad
  and #BTN_RIGHT|BTN_R
  A8
  beq @t3
  lda die_sel
  inc a
  cmp #5
  bcc @dr
  lda #0
@dr:
  sta die_sel
  ldx #SFX_TICK
  lda #AC_SFX
  jsr AudioCmd
  jmp @k
@t3:
  A16
  lda turn_pad
  and #BTN_Y          ; (Y still holds, as in the first version)
  A8
  beq @t4
@hold:
  ; holding is allowed between the first and the last roll (as on the Tandy)
  lda rolls_left
  cmp #3
  beq @tk
  cmp #0
  beq @tk
  ldx die_sel
  lda held,x
  eor #1
  sta held,x
  ldx #SFX_HOLD
  lda #AC_SFX
  jsr AudioCmd
@tk:
  jmp @k
@t4:
  A16
  lda turn_pad
  and #BTN_DOWN|BTN_UP
  A8
  beq @tk
  lda rolls_left
  cmp #3
  beq @tk             ; nothing to score before the first roll
  lda #1
  sta focus
  jsr ShowHilite
  jsr StatusChoose
  jmp @k

@card:
  A16
  lda turn_pad
  and #BTN_UP
  A8
  beq @c1
  lda #$FF
  jsr MoveCursor
  bra @moved
@c1:
  A16
  lda turn_pad
  and #BTN_DOWN
  A8
  beq @c2
  lda #1
  jsr MoveCursor
@moved:
  jsr BuildHilite
  ldx #SFX_TICK
  lda #AC_SFX
  jsr AudioCmd
  jmp @k
@c2:
  A16
  lda turn_pad
  and #BTN_B
  A8
  beq @c3
  lda rolls_left
  beq @ck
  stz focus
  stz hilite_on
  jsr BuildHilite
  jsr StatusAgain
@ck:
  jmp @k
@c3:
  A16
  lda turn_pad
  and #BTN_A
  A8
  beq @ck
  lda cursor
  sta chosen
  lda #1
  sta game_state
  rts

ShowHilite:
  lda #1
  sta hilite_on
  jmp BuildHilite

; Start pauses; Start again resumes, B quits to the title.
Pause:
  lda #1
  sta paused
  lda #7
  sta inidisp_v
  jsr StatusPaused
@l:
  jsr GameSprites
  jsr WaitFrame
  A16
  lda pad1_new
  ora pad2_new
  sta tmp3
  and #BTN_START
  A8
  bne @resume
  A16
  lda tmp3
  and #BTN_B
  A8
  beq @l
  lda #1
  sta quit_game
@resume:
  stz paused
  lda #15
  sta inidisp_v
  lda quit_game
  bne @r
  jsr StatusRefresh
@r:
  rts

; Tumbles every die that is not held; the last face shown is the result.
RollDice:
  lda #1
  sta game_state
  dec rolls_left
  lda #TUMBLE_FRAMES
  sta tumble_t
  ldx #SFX_ROLL
  lda #AC_SFX
  jsr AudioCmd
@f:
  lda tumble_t
  and #$03
  bne @show
  ldx #0
@d:
  lda held,x
  bne @n
  phx
  jsr Roll1
  plx
  sta dice,x
@n:
  inx
  cpx #5
  bne @d
@show:
  jsr GameFrame
  dec tumble_t
  bne @f
  jsr DrawCard
  rts

; ---------------------------------------------------------------- the Skipper's turn

AiTurn:
  jsr StatusSkipper
  ldx #25
  jsr GameDelay
@r:
  lda quit_game
  bne @x
  jsr RollDice
  ldx #41
  jsr GameDelay
  lda quit_game
  bne @x
  lda rolls_left
  beq @pick
  jsr SkipperSatisfied
  bcs @pick
  jsr SkipperHolds
  ldx #SFX_HOLD
  lda #AC_SFX
  jsr AudioCmd
  ldx #37
  jsr GameDelay
  bra @r
@pick:
  jsr SkipperPick
  sta chosen
  sta cursor
  jsr ShowHilite
  ldx #33
  jsr GameDelay
@x:
  rts

; ---------------------------------------------------------------- scoring

; Records the chosen box, then reacts with sound and voice (apply_score).
ApplyScore:
  lda #1
  sta game_state
  lda chosen
  jsr ScoreCat
  lda chosen
  jsr SlotOf
  A16
  lda res16
  sta last_score
  sta scores,x
  A8
  stz hilite_on
  jsr BuildHilite
  lda #3
  sta rolls_left
  jsr DrawCard
  jsr StatusScored
  jsr GameFrame       ; the new score reaches the screen before any voice upload
  A16
  lda last_score
  A8
  bne @good
  ldx #TUNE_BAD
  bra @play
@good:
  lda chosen
  cmp #CAT_YACHT
  beq @yacht
  cmp #CAT_FULL
  beq @full
  cmp #CAT_FOUR
  beq @four
  cmp #CAT_LITTLE
  beq @straight
  cmp #CAT_BIG
  beq @straight
  ldx #TUNE_SCORE
@play:
  lda #AC_MUSIC
  jsr AudioCmd
  bra @wait
@yacht:
  ldx #TUNE_YACHT
  lda #AC_MUSIC
  jsr AudioCmd
  ldx #SPK_YACHT
  bra @say
@full:
  ldx #SPK_FULLHOUSE
  bra @sayg
@four:
  ldx #SPK_FOUR
  bra @sayg
@straight:
  ldx #SPK_STRAIGHT
@sayg:
  phx
  ldx #TUNE_GOOD
  lda #AC_MUSIC
  jsr AudioCmd
  plx
@say:
  lda #AC_VOICE
  jsr AudioCmd
@wait:
  ldx #58
  jsr GameDelay
  jsr WaitVoice
  rts

; ---------------------------------------------------------------- game over

GameOver:
  lda #0
  jsr PlayerTotal
  A16
  lda res16
  sta tot0
  A8
  lda #1
  jsr PlayerTotal
  A16
  lda res16
  sta tot1
  A8
  ; best score: human totals only, never the demo (game_over in game.asm)
  lda game_mode
  cmp #2
  beq @nobest
  cmp #1
  A16
  lda tot0
  bcs @chk            ; vs Skipper (mode 1): the human's total
  cmp tot1            ; two players: the higher total
  bcs @chk
  lda tot1
@chk:
  cmp best
  bcc @nobest16
  beq @nobest16
  sta best
  A8
  jsr SaveWrite
  bra @nobest
@nobest16:
  A8
@nobest:
  ; the result
  A16
  lda tot0
  cmp tot1
  A8
  beq @tie
  bcs @p0
  ; player 1 (index) won
  ldx #StrP2Wins
  ldy #SPK_P2WINS
  lda #TUNE_WIN
  sta end_tune
  lda game_mode
  cmp #1
  bne @report
  ldx #StrSkpWins
  ldy #SPK_SKIPPER
  lda #TUNE_LOSE
  sta end_tune
  bra @report
@p0:
  ldx #StrP1Wins
  ldy #SPK_P1WINS
  lda #TUNE_WIN
  sta end_tune
  lda game_mode
  cmp #1
  bne @report
  ldx #StrYouWin
  ldy #SPK_YOUWIN
  bra @report
@tie:
  ldx #StrTie
  ldy #SPK_TIE
  lda #TUNE_GOOD
  sta end_tune
@report:
  stx end_msg
  sty end_clip
  jsr DrawGameOver
  jsr GameFrame       ; the result, the dimming and the hidden sprites land together
  jsr GameFrame
  lda #2
  sta game_state
  ldx end_tune
  lda #AC_MUSIC
  jsr AudioCmd
  ldx end_clip
  lda #AC_VOICE
  jsr AudioCmd
  lda game_mode
  cmp #2
  beq @demo
  ldx #30             ; half a second before A counts, so a mashed A can't skip it
  jsr GameDelay
@wait:
  jsr GameFrame
  A16
  lda pad1_new
  ora pad2_new
  and #BTN_A|BTN_START
  A8
  beq @wait
  rts
@demo:
  ldx #330
  jsr GameDelay
  rts

; Dims the table and shows the result in the middle of the screen.
DrawGameOver:
  stz hilite_on
  jsr BuildHilite
  jsr ClearText
  ldx #StrGameOver
  ldy #6*32+11
  lda #1
  jsr PrintAt
  jsr NameP0
  ldy #10*32+8
  lda #0
  jsr PrintAt
  ldx tot0
  ldy #10*32+23
  lda #1
  jsr PrintNum
  jsr NameP1
  ldy #12*32+8
  lda #0
  jsr PrintAt
  ldx tot1
  ldy #12*32+23
  lda #1
  jsr PrintNum
  ldx end_msg
  ldy #15*32+8
  lda #5
  jsr PrintAt
  ldx #StrBest
  ldy #18*32+8
  lda #3
  jsr PrintAt
  ldx best
  ldy #18*32+23
  lda #1
  jsr PrintNum
  lda game_mode
  cmp #2
  beq @nopress
  ldx #StrPressA
  ldy #21*32+12
  lda #7
  jsr PrintAt
@nopress:
  lda #1
  sta dim_all
  ; the layer and color changes go to the PPU in the same NMI as the text
  lda #$16            ; hide the card: just the table, dimmed, and the text
  sta tm_v
  stz cgwsel_v        ; color math everywhere
  lda #$C2            ; subtract, halved, on the table
  sta cgadsub_v
  lda #$E4
  sta coldata_v
  lda #1
  sta regs_dirty
  rts

; ---------------------------------------------------------------- drawing

DrawBoard:
  jsr ClearText
  ldx #StrScorecard
  ldy #ROW_BANNER*32+1
  lda #6
  jsr PrintAt
  jsr NameP0Short
  ldy #ROW_BANNER*32+COL_P0-2
  lda #6
  jsr PrintAt
  jsr NameP1Short
  ldy #ROW_BANNER*32+COL_P1-2
  lda #6
  jsr PrintAt
  ldx #StrRolls
  ldy #ROW_ROLLS*32+PANEL_COL
  lda #3
  jsr PrintAt
  stz tmp3
@names:
  A16
  lda tmp3
  and #$00FF
  asl a
  tax
  lda CatNames.w,x
  pha
  lda tmp3
  and #$00FF
  asl a
  asl a
  asl a
  asl a
  asl a
  asl a               ; row * 64 = (2 rows) * 32
  clc
  adc #CARD_ROW0*32+1
  tay
  plx
  A8
  lda #6
  jsr PrintAt
  inc tmp3
  lda tmp3
  cmp #NUM_CATS
  bne @names
  jsr DrawCard
  jsr StatusRefresh
  rts

; Scores for both players; previews in red ink for the player on turn.
DrawCard:
  stz tmp3            ; category
@row:
  lda #0
  jsr DrawCell
  lda #1
  jsr DrawCell
  inc tmp3
  lda tmp3
  cmp #NUM_CATS
  bne @row
  jsr DrawTotals
  rts

; A = player, tmp3 = category.
DrawCell:
  sta tmp2
  ; text position: row CARD_ROW0 + 2*cat, column COL_P0 or COL_P1
  A16
  lda tmp3
  and #$00FF
  asl a
  asl a
  asl a
  asl a
  asl a
  asl a
  clc
  adc #CARD_ROW0*32+COL_P0
  sta cell_pos
  A8
  lda tmp2
  beq @p0
  A16
  lda cell_pos
  clc
  adc #COL_P1-COL_P0
  sta cell_pos
  A8
@p0:
  ; blank the two cells
  A16
  lda cell_pos
  dec a
  tay
  A8
  ldx #StrBlank2
  lda #6
  jsr PrintAt
  ; the stored score
  lda cur
  pha
  lda tmp2
  sta cur
  lda tmp3
  jsr SlotOf
  pla
  sta cur
  A16
  lda scores,x
  cmp #EMPTY
  beq @empty
  tax
  A8
  ldy cell_pos
  lda #6
  jmp PrintNum
@empty:
  A8
  ; a preview for the player on turn once the dice are rolled
  lda tmp2
  cmp cur
  bne @r
  lda rolls_left
  cmp #3
  beq @r
  lda tmp3
  jsr ScoreCat
  ldx res16
  ldy cell_pos
  lda #4
  jmp PrintNum
@r:
  rts

DrawTotals:
  lda #0
  jsr PlayerTotal
  jsr NameP0Short
  ldy #ROW_TOT0*32+PANEL_COL+1
  lda #0
  jsr PrintAt
  ldx #StrBlank3
  ldy #ROW_TOT0*32+PANEL_COL+8
  lda #1
  jsr PrintAt
  ldx res16
  ldy #ROW_TOT0*32+PANEL_COL+10
  lda #1
  jsr PrintNum
  lda #1
  jsr PlayerTotal
  jsr NameP1Short
  ldy #ROW_TOT1*32+PANEL_COL+1
  lda #0
  jsr PrintAt
  ldx #StrBlank3
  ldy #ROW_TOT1*32+PANEL_COL+8
  lda #1
  jsr PrintAt
  ldx res16
  ldy #ROW_TOT1*32+PANEL_COL+10
  lda #1
  jsr PrintNum
  ; a marker beside the player on turn
  ldx #StrMarker
  ldy #ROW_TOT0*32+PANEL_COL
  lda cur
  beq @m0
  ldx #StrSpace
@m0:
  lda #1
  jsr PrintAt
  ldx #StrMarker
  ldy #ROW_TOT1*32+PANEL_COL
  lda cur
  bne @m1
  ldx #StrSpace
@m1:
  lda #1
  jmp PrintAt

; Player names. X = string.
NameP0:
  ldx #StrYou
  lda game_mode
  cmp #1
  beq @r
  ldx #StrPlayer1
@r:
  rts
NameP1:
  ldx #StrSkipper
  lda game_mode
  cmp #1
  beq @r
  ldx #StrPlayer2
@r:
  rts
NameP0Short:
  ldx #StrYou3
  lda game_mode
  cmp #1
  beq @r
  ldx #StrP1
@r:
  rts
NameP1Short:
  ldx #StrSkp3
  lda game_mode
  cmp #1
  beq @r
  ldx #StrP2
@r:
  rts

; ---------------------------------------------------------------- status panel

; Clears the three status lines, then prints X (line 1) and Y (line 2).
StatusTwo:
  phy
  phx
  ldx #StrBlank12
  ldy #ROW_STATUS*32+PANEL_COL
  lda #0
  jsr PrintAt
  ldx #StrBlank12
  ldy #(ROW_STATUS+1)*32+PANEL_COL
  lda #0
  jsr PrintAt
  ldx #StrBlank12
  ldy #(ROW_STATUS+2)*32+PANEL_COL
  lda #0
  jsr PrintAt
  plx
  ldy #ROW_STATUS*32+PANEL_COL
  lda #7
  jsr PrintAt
  plx
  ldy #(ROW_STATUS+2)*32+PANEL_COL
  lda #3
  jmp PrintAt

; The turn banner at the top right.
Banner:
  phx
  ldx #StrBlank12
  ldy #ROW_BANNER*32+PANEL_COL
  lda #1
  jsr PrintAt
  plx
  ldy #ROW_BANNER*32+PANEL_COL+1
  lda #1
  jmp PrintAt

StatusRefresh:
  jsr IsAi
  bcc @h
  jmp StatusSkipper
@h:
  lda focus
  beq @tray
  jmp StatusChoose
@tray:
  lda rolls_left
  cmp #3
  beq StatusYourTurn
  jmp StatusAgain

StatusYourTurn:
  jsr TurnBanner
  ldx #StrPressA
  ldy #StrToRoll
  jmp StatusTwo
StatusAgain:
  jsr TurnBanner
  ldx #StrAHolds
  ldy #StrXRolls
  jmp StatusTwo
StatusChoose:
  jsr TurnBanner
  ldx #StrPickBox
  ldy #StrBlank
  jsr StatusTwo
  ldx #StrAScores
  ldy #(ROW_STATUS+1)*32+PANEL_COL
  lda #3
  jsr PrintAt
  lda rolls_left
  beq @r              ; rolls left: B goes back to the dice
  ldx #StrBBack
  ldy #(ROW_STATUS+2)*32+PANEL_COL
  lda #3
  jmp PrintAt
@r:
  rts
StatusSkipper:
  ldx #StrSkpTurn
  jsr Banner
  ldx #StrTheSkipper
  ldy #StrIsRolling
  jmp StatusTwo
StatusPaused:
  ldx #StrPaused
  ldy #StrBQuits
  jmp StatusTwo
StatusScored:
  A16
  lda chosen
  and #$00FF
  asl a
  tax
  lda CatNames.w,x
  tax
  A8
  ldy #StrBlank
  jsr StatusTwo
  ldx #StrPlus
  ldy #(ROW_STATUS+2)*32+PANEL_COL
  lda #1
  jsr PrintAt
  ldx last_score
  ldy #(ROW_STATUS+2)*32+PANEL_COL+3
  lda #1
  jmp PrintNum

TurnBanner:
  ldx #StrYourTurn
  lda game_mode
  cmp #1
  beq @b
  ldx #StrP1Turn
  lda cur
  beq @b
  ldx #StrP2Turn
@b:
  jmp Banner

; ---------------------------------------------------------------- highlight window

; Builds the window table: the cursor's row glows while hilite_on is set.
BuildHilite:
  ldx #0
  lda hilite_on
  beq @off
  ; lines before the row: (CARD_ROW0*8 - 4) + cursor*16
  A16
  lda cursor
  and #$00FF
  asl a
  asl a
  asl a
  asl a
  clc
  adc #CARD_ROW0*8-4
  sta tmp0
  A8
  lda tmp0
  cmp #128
  bcc @short
  sec
  sbc #127
  sta tmp0
  lda #127
  jsr @offrun
@short:
  lda tmp0
  beq @band
  jsr @offrun
@band:
  lda #16
  sta HILITE_HDMA,x
  lda #6
  sta HILITE_HDMA+1,x
  lda #148
  sta HILITE_HDMA+2,x
  inx
  inx
  inx
@off:
  lda #1
  jsr @offrun
  stz HILITE_HDMA,x
  rts
@offrun:            ; A = lines with the window shut
  sta HILITE_HDMA,x
  lda #$FF
  sta HILITE_HDMA+1,x
  stz HILITE_HDMA+2,x
  inx
  inx
  inx
  rts

; ---------------------------------------------------------------- sprites

GameSprites:
  jsr SpritesBegin
  lda dim_all
  beq @show
  jmp @end
@show:
  ; selector around the chosen die while a human holds dice
  lda game_state
  bne @nosel
  lda focus
  bne @nosel
  lda rolls_left
  cmp #3
  beq @nosel
  ldx die_sel
  jsr DiePos
  lda held,x
  beq @selup
  lda spr_y
  sec
  sbc #3
  sta spr_y
@selup:
  A16
  lda #TILE_SELECT
  sta spr_tile
  A8
  lda #$34            ; priority 3, palette 2
  sta spr_attr
  lda #1
  sta spr_big
  jsr PutSprite
@nosel:
  ; the dice
  ldx #0
@die:
  phx
  jsr DrawDie
  plx
  inx
  cpx #5
  bne @die
  ; their shadows on the felt
  ldx #0
@shadow:
  phx
  jsr DiePos
  lda spr_y
  clc
  adc #3
  sta spr_y
  A16
  lda #TILE_SHADOW
  sta spr_tile
  A8
  lda #$24            ; priority 2, palette 2
  sta spr_attr
  lda #1
  sta spr_big
  jsr PutSprite
  plx
  inx
  cpx #5
  bne @shadow
  ; rolls left: three small dice, lit or spent, 14 px apart after ROLLS
  ldx #0
@pip:
  A16
  txa
  asl a
  sta tmp2
  asl a
  asl a
  asl a
  sec
  sbc tmp2            ; x * 14
  clc
  adc #(PANEL_COL+5)*8+2
  sta spr_x
  lda #TILE_PIP
  sta spr_tile
  A8
  lda #ROW_ROLLS*8-5
  sta spr_y
  txa
  cmp rolls_left
  lda #$36            ; palette 3: lit
  bcc @lit
  lda #$38            ; palette 4: spent
@lit:
  sta spr_attr
  stz spr_big
  phx
  jsr PutSprite
  plx
  inx
  cpx #3
  bne @pip
@end:
  jmp SpritesEnd

; X = die. Sets spr_x / spr_y to its resting place.
DiePos:
  A16
  txa
  and #$00FF
  tay
  A8
  lda DieX.w,y
  sta spr_x
  stz spr_x+1
  lda DieY.w,y
  sta spr_y
  rts

; X = die index.
DrawDie:
  jsr DiePos
  lda #1
  sta spr_big
  lda #$30            ; priority 3, palette 0
  sta spr_attr
  lda dice,x
  bne @rolled
  ; before the first roll: dice resting at a tilt
  A16
  txa
  and #$0003
  cmp #3
  bcc @t
  lda #0
@t:
  asl a
  tay
  lda TumbleTiles.w,y
  sta spr_tile
  A8
  jmp PutSprite
@rolled:
  lda held,x
  beq @loose
  ; held: lifted, gold, with its HOLD tag
  lda spr_y
  sec
  sbc #3
  sta spr_y
  lda #$32            ; palette 1
  sta spr_attr
  A16
  lda dice,x
  and #$00FF
  dec a
  asl a
  tay
  lda DieTilesHeld.w,y
  sta spr_tile
  A8
  jmp PutSprite
@loose:
  lda tumble_t
  beq @face
  ; tumbling: bounce and spin
  A16
  lda tumble_t
  and #$00FF
  clc
  adc DieBounceOfs.w,x  ; each die on its own rhythm (low byte used)
  and #$000F
  tay
  A8
  lda Bounce.w,y
  clc
  adc spr_y
  sta spr_y
  lda tumble_t
  and #$03
  cmp #3
  beq @face           ; every fourth frame shows the new face
  A16
  txa
  and #$00FF
  clc
  adc tumble_t
  and #$0003
  cmp #3
  bcc @spin
  lda #1
@spin:
  asl a
  tay
  lda TumbleTiles.w,y
  sta spr_tile
  A8
  jmp PutSprite
@face:
  A16
  lda dice,x
  and #$00FF
  dec a
  asl a
  tay
  lda DieTiles.w,y
  sta spr_tile
  A8
  jmp PutSprite

; spr_x (16-bit), spr_y, spr_tile (16-bit), spr_attr, spr_big. Clobbers A, X, Y, tmp2.
PutSprite:
  ldy oam_next
  cpy #512
  bcs @r
  lda spr_x
  sta oam_shadow,y
  lda spr_y
  sta oam_shadow+1,y
  lda spr_tile
  sta oam_shadow+2,y
  lda spr_tile+1
  and #$01
  ora spr_attr
  sta oam_shadow+3,y
  lda spr_x+1
  and #$01
  sta tmp2
  lda spr_big
  beq @small
  lda tmp2
  ora #$02
  sta tmp2
@small:
  A16
  tya
  lsr a
  lsr a
  pha
  lsr a
  lsr a
  tax
  pla
  and #$0003
  tay
  A8
  lda tmp2
@shift:
  cpy #0
  beq @put
  asl a
  asl a
  dey
  bra @shift
@put:
  ora oam_shadow+512,x
  sta oam_shadow+512,x
  A16
  lda oam_next
  clc
  adc #4
  sta oam_next
  A8
@r:
  rts

Bounce:       .db -1, -3, -5, -6, -6, -5, -3, -1, 0, -2, -3, -3, -2, 0, -1, 0
DieBounceOfs: .db 0, 5, 9, 3, 12, 0

; ---------------------------------------------------------------- mute

ToggleMute:
  lda muted
  eor #1
  sta muted
  tax
  lda #AC_MUTE
  jsr AudioCmd
  jmp SaveWrite

; ---------------------------------------------------------------- text

CatNames:
  .dw CnOnes, CnTwos, CnThrees, CnFours, CnFives, CnSixes
  .dw CnFull, CnFour, CnLittle, CnBig, CnChoice, CnYacht
CnOnes:   .db "Ones", 0
CnTwos:   .db "Twos", 0
CnThrees: .db "Threes", 0
CnFours:  .db "Fours", 0
CnFives:  .db "Fives", 0
CnSixes:  .db "Sixes", 0
CnFull:   .db "Full House", 0
CnFour:   .db "Four Alike", 0
CnLittle: .db "Small Str", 0
CnBig:    .db "Large Str", 0
CnChoice: .db "Choice", 0
CnYacht:  .db "Yacht", 0

StrScorecard:  .db "SCORECARD", 0
StrYou3:       .db "YOU", 0
StrSkp3:       .db "SKP", 0
StrP1:         .db " P1", 0
StrP2:         .db " P2", 0
StrYou:        .db "YOU", 0
StrSkipper:    .db "THE SKIPPER", 0
StrPlayer1:    .db "PLAYER 1", 0
StrPlayer2:    .db "PLAYER 2", 0
StrRolls:      .db "ROLLS", 0
StrBlank:      .db 0
StrBlank2:     .db "  ", 0
StrBlank3:     .db "   ", 0
StrBlank12:    .db "            ", 0
StrSpace:      .db " ", 0
StrMarker:     .db ">", 0
StrPlus:       .db " + ", 0
StrYourTurn:   .db "YOUR TURN", 0
StrP1Turn:     .db "PLAYER 1", 0
StrP2Turn:     .db "PLAYER 2", 0
StrSkpTurn:    .db "SKIPPER", 0
StrPressA:     .db "PRESS A", 0
StrToRoll:     .db "TO ROLL", 0
StrAHolds:     .db "A: HOLD", 0
StrXRolls:     .db "X: ROLL", 0
StrBBack:      .db "B: BACK", 0
StrPickBox:    .db "PICK A BOX", 0
StrAScores:    .db "A: SCORE", 0
StrTheSkipper: .db "THE SKIPPER", 0
StrIsRolling:  .db "IS ROLLING", 0
StrPaused:     .db "PAUSED", 0
StrBQuits:     .db "B: QUIT", 0
StrGameOver:   .db "GAME OVER", 0
StrYouWin:     .db "YOU WIN!", 0
StrSkpWins:    .db "THE SKIPPER WINS", 0
StrP1Wins:     .db "PLAYER 1 WINS!", 0
StrP2Wins:     .db "PLAYER 2 WINS!", 0
StrTie:        .db "A TIE!", 0

.INCLUDE "build/gfx/game_dice.inc"

.ENDS

.SECTION "GameBgChr" SUPERFREE
GameBgChr:
  .INCBIN "build/gfx/game_bg.chr"
GameBgChrEnd:
.ENDS
.SECTION "GameSprChr" SUPERFREE
GameSprChr:
  .INCBIN "build/gfx/game_spr.chr"
GameSprChrEnd:
.ENDS
.SECTION "GameMaps" SUPERFREE
GameBg1Map:
  .INCBIN "build/gfx/game_bg1.map"
GameBg2Map:
  .INCBIN "build/gfx/game_bg2.map"
GamePal:
  .INCBIN "build/gfx/game.pal"
.ENDS
