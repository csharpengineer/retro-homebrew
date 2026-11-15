; Self test: hold L+R at power-on. The 22 checks of YACHT /T on the Tandy
; (straights reworked, one added: 23), then a mailbox the emulator tests use to ask for scores.
.SECTION "SelfTest" FREE

SelfTest:
  A16
  stz st_count
  stz st_fail
  stz st_index
  A8
@case:
  ldx st_index
  ldy #0
@copy:
  lda TestCases.w,x
  sta dice,y
  inx
  iny
  cpy #5
  bne @copy
  lda TestCases.w,x     ; category
  jsr ScoreCat
  ldx st_index
  A16
  inc st_count
  lda TestCases.w+6,x   ; expected score
  cmp res16
  beq @ok
  inc st_fail
@ok:
  txa
  clc
  adc #8
  sta st_index
  cmp #TestCasesEnd-TestCases
  A8
  bne @case

  ; 6000 rolls from seed 1234 should spread evenly over the six faces.
  A16
  lda #1234
  sta seed
  ldx #12
@clear:
  stz st_faces,x
  dex
  dex
  bpl @clear
  lda #6000
  sta st_loop
  A8
@roll:
  jsr Roll1
  A16
  and #$00FF
  asl a
  tax
  inc st_faces,x
  dec st_loop
  A8
  bne @roll
  ldx #2
@spread:
  A16
  inc st_count
  lda st_faces,x
  cmp #880
  bcc @bad
  cmp #1121
  bcc @good
@bad:
  inc st_fail
@good:
  A8
  inx
  inx
  cpx #14
  bne @spread

  ; Show the results.
  jsr ScreenOff
  jsr TextScreenSetup
  A16
  lda #$2C83          ; deep navy backdrop
  sta cg_shadow
  A8
  ldx #StrSelfTest
  ldy #4*32+4
  lda #1
  jsr PrintAt
  ldx st_count
  ldy #8*32+7
  lda #0
  jsr PrintNum
  ldx #StrChecksRun
  ldy #8*32+8
  lda #0
  jsr PrintAt
  ldx st_fail
  ldy #10*32+7
  lda #5
  ldx st_fail
  beq @green
  lda #2
@green:
  jsr PrintNum
  ldx #StrFailed
  ldy #10*32+8
  lda #0
  jsr PrintAt
  jsr ScreenOn

  A16
  lda st_count
  sta TEST_RESULT+2
  lda st_fail
  sta TEST_RESULT+4
  lda #$5A5A
  sta TEST_RESULT     ; written last: tells the test the numbers are ready
  A8

@serve:
  jsr WaitFrame
  jsr OracleServe
  bra @serve

; Answers one request left in the mailbox by an emulator test.
OracleServe:
  lda O_CMD
  bne @go
  rts
@go:
  ldx #0
@dice:
  lda O_DICE,x
  sta dice,x
  inx
  cpx #5
  bne @dice
  lda O_CMD
  cmp #2
  beq @ai
  cmp #1
  bne @done
  ; command 1: all twelve scores
  stz tmp3
@cat:
  lda tmp3
  jsr ScoreCat
  A16
  lda tmp3
  and #$00FF
  asl a
  tax
  lda res16
  sta O_SCORES,x
  A8
  inc tmp3
  lda tmp3
  cmp #NUM_CATS
  bne @cat
@done:
  stz O_CMD
  lda #$A5
  sta O_DONE
  rts

@ai:
  ; command 2: the Skipper's holds, pick and stop decision for player 0,
  ; with the mailbox's open flags as player 0's empty boxes
  stz cur
  ldx #0
  ldy #0
@open:
  A16
  lda #0
  sta scores,y
  A8
  lda O_OPEN,x
  beq @filled
  A16
  lda #EMPTY
  sta scores,y
  A8
@filled:
  iny
  iny
  inx
  cpx #NUM_CATS
  bne @open
  jsr SkipperHolds
  ldx #0
@h:
  lda held,x
  sta O_HOLDS,x
  inx
  cpx #5
  bne @h
  stz O_SAT
  jsr SkipperSatisfied
  bcc @nsat
  lda #1
  sta O_SAT
@nsat:
  jsr SkipperPick
  sta O_PICK
  bra @done

StrSelfTest:  .db "YACHT  SELF TEST", 0
StrChecksRun: .db " CHECKS RUN", 0
StrFailed:    .db " FAILED", 0

; Five dice, category, expected score: copied from tandy1000/yacht/src/data.asm,
; with the straight cases rewritten for the Small/Large boxes.
TestCases:
  .db 1,1,2,3,4, 0
  .dw 2
  .db 6,6,6,2,1, 5
  .dw 18
  .db 3,3,3,5,5, CAT_FULL
  .dw 19
  .db 3,3,3,3,5, CAT_FULL
  .dw 0
  .db 1,1,1,1,1, CAT_FULL
  .dw 0
  .db 4,4,4,4,1, CAT_FOUR
  .dw 16
  .db 5,5,5,5,5, CAT_FOUR
  .dw 20
  .db 4,4,4,1,1, CAT_FOUR
  .dw 0
  .db 1,2,3,4,5, CAT_LITTLE
  .dw 30
  .db 3,4,1,6,5, CAT_LITTLE
  .dw 30
  .db 1,2,3,5,6, CAT_LITTLE
  .dw 0
  .db 2,3,4,5,6, CAT_BIG
  .dw 40
  .db 1,2,3,4,5, CAT_BIG
  .dw 40
  .db 1,2,3,4,6, CAT_BIG
  .dw 0
  .db 1,3,5,2,6, CAT_CHOICE
  .dw 17
  .db 2,2,2,2,2, CAT_YACHT
  .dw 50
  .db 2,2,2,2,3, CAT_YACHT
  .dw 0
TestCasesEnd:

.ENDS
