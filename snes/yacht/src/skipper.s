; The Skipper, the computer opponent. A line-by-line translation of
; tandy1000/yacht/src/game.asm ai_scores_now .. ai_holds; Tandy labels in comments.
.SECTION "Skipper" FREE

; slot_of: A = category. Returns X = byte offset of the player on turn's box. Preserves A.
SlotOf:
  pha
  A16
  and #$00FF
  asl a
  tax
  A8
  lda cur
  beq @p0
  A16
  txa
  clc
  adc #NUM_CATS*2
  tax
  A8
@p0:
  pla
  rts

; A = category. Carry set when the box is still empty. Preserves A; clobbers X.
IsOpen:
  jsr SlotOf
  pha
  A16
  lda scores,x
  cmp #EMPTY
  A8
  beq @yes
  pla
  clc
  rts
@yes:
  pla
  sec
  rts

; ai_scores_now: A = category. Carry set if it is open and scores above zero now.
ScoresNow:
  jsr IsOpen
  bcc @no
  jsr ScoreCat
  A16
  lda res16
  A8
  beq @no
  sec
  rts
@no:
  clc
  rts

; ai_satisfied: carry set when the dice are good enough to stop rolling.
SkipperSatisfied:
  lda #CAT_YACHT
  jsr ScoresNow
  bcs @r
  lda #CAT_LITTLE
  jsr ScoresNow
  bcs @r
  lda #CAT_BIG
  jsr ScoresNow
  bcs @r
  lda #CAT_FULL
  jsr ScoresNow
  bcs @r
  lda #CAT_FOUR
  jsr IsOpen
  bcc @no
  jsr ScoreCat
  A16
  lda res16
  cmp #20
  A8
  bcs @r              ; 20 or more: carry is set
@no:
  clc
@r:
  rts

; ai_pick: returns A = the open box that beats its typical score by the most.
; Ties keep the first box.
SkipperPick:
  A16
  lda #$8000
  sta ai_best_v
  A8
  stz ai_best_c
  stz ai_c
@loop:
  lda ai_c
  jsr IsOpen
  bcc @next
  jsr ScoreCat
  A16
  lda ai_c
  and #$00FF
  tax
  lda AiExpect.w,x
  and #$00FF
  sta tmp0
  lda res16
  sec
  sbc tmp0
  sta tmp1            ; score minus its typical value, signed
  sec
  sbc ai_best_v
  beq @keep           ; equal: the earlier box stays
  bvc @nov
  eor #$8000
@nov:
  bmi @keep           ; less: keep the best so far
  lda tmp1
  sta ai_best_v
  A8
  lda ai_c
  sta ai_best_c
@keep:
  A8
@next:
  inc ai_c
  lda ai_c
  cmp #NUM_CATS
  bne @loop
  lda ai_best_c
  rts

; hold_all: A = face. Holds every die showing it. Clobbers X.
HoldAll:
  ldx #0
@l:
  cmp dice,x
  bne @n
  pha
  lda #1
  sta held,x
  pla
@n:
  inx
  cpx #5
  bne @l
  rts

; hold_one: A = face. Holds the first die showing it. Clobbers X.
HoldOne:
  ldx #0
@l:
  cmp dice,x
  beq @h
  inx
  cpx #5
  bne @l
  rts
@h:
  lda #1
  sta held,x
  rts

; ai_holds: chooses which dice to keep before the next roll.
SkipperHolds:
  stz held
  stz held+1
  stz held+2
  stz held+3
  stz held+4
  jsr CountDice
  stz ai_dl           ; different faces showing
  stz ai_dh           ; largest group
  ldx #1
@d:
  lda counts,x
  beq @dn
  inc ai_dl
  cmp ai_dh
  beq @dn
  bcc @dn
  sta ai_dh
@dn:
  inx
  cpx #7
  bne @d

  ; chase a straight (the Tandy code ORs both boxes and compares with EMPTY)
  lda ai_dl
  cmp #4
  bcc @nost
  lda ai_dh
  cmp #3
  bcs @nost
  lda #CAT_LITTLE
  jsr SlotOf
  A16
  lda scores,x
  sta tmp0
  A8
  lda #CAT_BIG
  jsr SlotOf
  A16
  lda scores,x
  ora tmp0
  cmp #EMPTY
  A8
  bne @nost
  lda #1
  sta ai_dl           ; first face to keep
  lda #6
  sta ai_dh           ; last face to keep
  lda counts+1
  beq @sh
  lda counts+6
  beq @sh
  lda #CAT_BIG
  jsr IsOpen
  bcc @droph
  lda #2
  sta ai_dl
  bra @sh
@droph:
  lda #5
  sta ai_dh
@sh:
  lda ai_dl
  sta ai_f
@sl:
  A16
  lda ai_f
  and #$00FF
  tax
  A8
  lda counts,x
  beq @sn
  lda ai_f
  jsr HoldOne
@sn:
  inc ai_f
  lda ai_f
  cmp ai_dh
  beq @sl
  bcc @sl
  rts

@nost:
  ; two pairs chase a full house
  lda #CAT_FULL
  jsr IsOpen
  bcc @face
  stz tmp0
  ldx #1
@pc:
  lda counts,x
  cmp #2
  bne @pn
  inc tmp0
@pn:
  inx
  cpx #7
  bne @pc
  lda tmp0
  cmp #2
  bne @face
  ldx #1
@ph:
  lda counts,x
  cmp #2
  bne @phn
  phx
  txa
  jsr HoldAll
  plx
@phn:
  inx
  cpx #7
  bne @ph
  rts

@face:
  ; keep the most promising group of matching dice
  stz ai_bw
  stz ai_bf
  lda #1
  sta ai_f
@fl:
  A16
  lda ai_f
  and #$00FF
  tax
  A8
  lda counts,x
  beq @fn
  asl a
  asl a
  asl a
  clc
  adc ai_f
  sta ai_w
  lda ai_f
  dec a
  jsr IsOpen
  bcc @noopen
  lda ai_w
  clc
  adc #6
  sta ai_w
@noopen:
  lda ai_w
  cmp ai_bw
  beq @fn
  bcc @fn
  sta ai_bw
  lda ai_f
  sta ai_bf
@fn:
  inc ai_f
  lda ai_f
  cmp #7
  bne @fl
  A16
  lda ai_bf
  and #$00FF
  tax
  A8
  lda counts,x
  cmp #2
  bcs @keepit
  lda ai_bf
  cmp #5
  bcc @none
@keepit:
  lda ai_bf
  jsr HoldAll
@none:
  rts

; What each box typically earns (ai_expect).
AiExpect:
  .db 2, 5, 8, 11, 14, 17, 15, 12, 8, 8, 21, 6

.ENDS
