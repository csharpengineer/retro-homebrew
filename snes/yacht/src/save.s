; Battery save RAM at $70:0000: "YCHT", best (2 bytes), muted, reserved,
; then a checksum: the sum of those 8 bytes, XOR $A55A. Anything that doesn't
; check out (a new cart holds random bytes) resets to defaults.
.DEFINE SRAM $700000
.DEFINE SAVE_KEY $A55A

.SECTION "Save" FREE

; Called once at power-on.
SaveLoad:
  jsr SaveSum
  A16
  cmp SRAM+8
  A8
  bne @fresh
  lda SRAM
  cmp #$59
  bne @fresh
  lda SRAM+1
  cmp #$43
  bne @fresh
  lda SRAM+2
  cmp #$48
  bne @fresh
  lda SRAM+3
  cmp #$54
  bne @fresh
  A16
  lda SRAM+4
  sta best
  A8
  lda SRAM+6
  and #$01
  sta muted
  tax
  lda #AC_MUTE
  jmp AudioCmd
@fresh:
  stz best
  stz best+1
  stz muted
  jmp SaveWrite

; Writes the best score and the sound setting.
SaveWrite:
  lda #$59
  sta SRAM
  lda #$43
  sta SRAM+1
  lda #$48
  sta SRAM+2
  lda #$54
  sta SRAM+3
  A16
  lda best
  sta SRAM+4
  A8
  lda muted
  sta SRAM+6
  lda #0
  sta SRAM+7
  jsr SaveSum
  A16
  sta SRAM+8
  A8
  rts

; Returns A (16-bit, A8 on return) = checksum of the first 8 save bytes.
SaveSum:
  A16
  lda #0
  ldx #0
@l:
  sta tmp0
  lda SRAM,x
  and #$00FF
  clc
  adc tmp0
  inx
  cpx #8
  bne @l
  eor #SAVE_KEY
  A8
  rts

.ENDS
