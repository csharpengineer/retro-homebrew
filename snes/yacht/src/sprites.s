; Sprites: metasprites written into the OAM shadow each frame.
; A metasprite is: count, then per part dx, dy, tile, attribute, big (0/1).
.SECTION "Sprites" FREE

; Starts a new frame of sprites.
SpritesBegin:
  stz oam_next
  stz oam_next+1
  ldx #0
@hi:
  stz oam_shadow+512,x
  inx
  cpx #32
  bne @hi
  rts

; Hides every sprite slot not used this frame.
SpritesEnd:
  ldx oam_next
@l:
  cpx #512
  bcs @done
  lda #$F0
  sta oam_shadow+1,x
  inx
  inx
  inx
  inx
  bra @l
@done:
  rts

; X = metasprite (bank 0), spr_x = 16-bit signed x, spr_y = y.
; Clobbers A, X, Y, tmp0-tmp2.
DrawMeta:
  lda $0000,x
  sta tmp0            ; parts left
  inx
@part:
  lda tmp0
  beq @done
  ldy oam_next
  cpy #512
  bcs @done
  A16
  lda $0000,x         ; dx, sign-extended
  and #$00FF
  cmp #$0080
  bcc @pos
  ora #$FF00
@pos:
  clc
  adc spr_x
  sta tmp1            ; screen x, 9 bits matter
  A8
  sta oam_shadow,y
  lda $0001,x
  clc
  adc spr_y
  sta oam_shadow+1,y
  lda $0002,x
  sta oam_shadow+2,y
  lda $0003,x
  sta oam_shadow+3,y
  ; high table bits for this sprite: bit 0 = x bit 8, bit 1 = large size
  lda tmp1+1
  and #$01
  sta tmp2
  lda $0004,x
  beq @small
  lda tmp2
  ora #$02
  sta tmp2
@small:
  phx
  A16
  tya
  lsr a
  lsr a               ; sprite number
  pha
  lsr a
  lsr a               ; byte in the high table
  tax
  pla
  and #$0003          ; position within the byte
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
  plx
  A16
  lda oam_next
  clc
  adc #4
  sta oam_next
  txa
  clc
  adc #5
  tax
  A8
  dec tmp0
  bra @part
@done:
  rts

.ENDS
