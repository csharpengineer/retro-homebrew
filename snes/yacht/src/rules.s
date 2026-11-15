; Scoring and the random generator, translated from tandy1000/yacht/src/yacht.asm,
; except the straights: the SNES boxes are poker-dice Small (any four in a row,
; 30) and Large (five in a row, 40) instead of Yacht's Little (1-5) and Big (2-6).
; All routines: called with A 8-bit, X/Y 16-bit; they return the same way.
.SECTION "Rules" FREE

; Tallies the five dice into counts[1..6] and sum. Clobbers A, X, Y.
CountDice:
  ldx #6
@zero:
  stz counts,x
  dex
  bpl @zero
  stz sum
  stz sum+1
  ldy #0
@next:
  A16
  lda dice,y
  and #$00FF
  tax
  clc
  adc sum
  sta sum
  A8
  inc counts,x
  iny
  cpy #5
  bne @next
  rts

; A = category 0-11. Returns the score for the current dice in res16.
; Clobbers A, X, Y, tmp0.
ScoreCat:
  pha
  jsr CountDice
  pla
  stz res16
  stz res16+1
  cmp #CAT_FULL
  bcs @special
  ; Ones to Sixes: face times how many dice show it.
  inc a
  sta WRMPYA
  A16
  and #$00FF
  tax
  A8
  lda counts,x
  sta WRMPYB
  nop                 ; the multiplier needs 8 cycles
  nop
  nop
  nop
  A16
  lda RDMPYL
  sta res16
  A8
  rts

@special:
  cmp #CAT_FULL
  beq @full
  cmp #CAT_FOUR
  beq @four
  cmp #CAT_LITTLE
  beq @little
  cmp #CAT_BIG
  beq @big
  cmp #CAT_CHOICE
  beq @choice
  ; Yacht: five of one face.
  ldx #6
@yacht:
  lda counts,x
  cmp #5
  beq @fifty
  dex
  bne @yacht
  rts
@fifty:
  lda #50
  sta res16
  rts

@choice:
  A16
  lda sum
  sta res16
  A8
  rts

@full:
  ; Exactly three of one face and two of another. Five alike doesn't count.
  stz tmp0
  ldx #6
@fl:
  lda counts,x
  cmp #3
  bne @f2
  lda tmp0
  ora #1
  sta tmp0
  bra @fnext
@f2:
  cmp #2
  bne @fnext
  lda tmp0
  ora #2
  sta tmp0
@fnext:
  dex
  bne @fl
  lda tmp0
  cmp #3
  bne @zero
  bra @choice

@four:
  ; Four or more of a face scores four of them.
  ldx #6
@ol:
  lda counts,x
  cmp #4
  bcs @ofound
  dex
  bne @ol
  rts
@ofound:
  A16
  txa
  asl a
  asl a
  sta res16
  A8
  rts

@little:
  ; Small straight: any four faces in a row (1-4, 2-5 or 3-6) score 30.
  ldx #1
@lw:
  lda counts,x
  beq @lnext
  lda counts+1,x
  beq @lnext
  lda counts+2,x
  beq @lnext
  lda counts+3,x
  beq @lnext
  lda #30
  sta res16
  rts
@lnext:
  inx
  cpx #4
  bne @lw
  rts

@big:
  ; Large straight: five in a row (1-5 or 2-6) scores 40.
  ldx #1
@bw:
  lda counts,x
  beq @bnext
  lda counts+1,x
  beq @bnext
  lda counts+2,x
  beq @bnext
  lda counts+3,x
  beq @bnext
  lda counts+4,x
  beq @bnext
  lda #40
  sta res16
  rts
@bnext:
  inx
  cpx #3
  bne @bw
  rts

@zero:
  stz res16
  stz res16+1
  rts

; A = player. Returns the total of that player's filled boxes in res16.
; Clobbers A, X, Y.
PlayerTotal:
  ldx #0
  cmp #0
  beq @p0
  ldx #NUM_CATS*2
@p0:
  ldy #NUM_CATS
  A16
  stz res16
@loop:
  lda scores,x
  cmp #EMPTY
  beq @skip
  clc
  adc res16
  sta res16
@skip:
  inx
  inx
  dey
  bne @loop
  A8
  rts

; Next value of the generator: seed = seed * 25173 + 13849 (mod 65536),
; the same sequence as the Tandy version. Returns it in res16. Clobbers A.
; seed * $6255 mod $10000 = lo*$55 + ((hi*$55 + lo*$62) << 8)
Rand:
  lda seed
  sta WRMPYA
  lda #$62
  sta WRMPYB
  nop
  nop
  nop
  nop
  lda RDMPYL          ; low byte of lo*$62
  sta tmp0+1          ; becomes part of the high byte
  lda #$55
  sta WRMPYB          ; lo*$55 (WRMPYA still holds lo)
  nop
  nop
  nop
  nop
  A16
  lda RDMPYL
  sta tmp1            ; lo*$55, full 16 bits
  A8
  lda seed+1
  sta WRMPYA
  lda #$55
  sta WRMPYB          ; hi*$55
  nop
  nop
  nop
  nop
  lda RDMPYL
  clc
  adc tmp0+1          ; (hi*$55 + lo*$62) & $FF
  sta tmp0+1
  stz tmp0
  A16
  lda tmp0            ; that byte << 8
  clc
  adc tmp1
  clc
  adc #13849
  sta seed
  sta res16
  A8
  rts

; Seeds the generator when a game starts: from the test hook if an emulator
; test set one, otherwise from the frame count and player input timing.
SeedRng:
  A16
  lda TEST_SEED
  bne @set
  lda entropy
  eor frame
  bne @set
  lda #1234
@set:
  sta seed
  A8
  rts

; Returns A = a die face 1-6: the high word of rand * 6, plus one. Clobbers tmp0-tmp2.
Roll1:
  jsr Rand
  A16
  lda res16
  and #$00FF          ; low byte times 6
  sta tmp2
  asl a
  clc
  adc tmp2
  asl a
  xba
  and #$00FF          ; its carry into the high byte
  sta tmp2
  lda res16
  xba
  and #$00FF          ; high byte times 6
  sta tmp1
  asl a
  clc
  adc tmp1
  asl a
  clc
  adc tmp2
  xba
  and #$00FF
  inc a
  A8
  rts

.ENDS
