; Text on BG3: the font sits at BG3 tile 0 (space) through 95; the map lives in
; text_shadow and goes to VRAM $5800 in NMI when text_dirty is set.
.SECTION "Text" FREE

; Blanks the whole text layer.
ClearText:
  ldx #0
  A16
@l:
  stz text_shadow,x
  inx
  inx
  cpx #2048
  bne @l
  A8
  lda #1
  sta text_dirty
  rts

; X = zero-terminated string in bank 0, Y = tile index (row*32 + column),
; A = palette 0-7. High priority, so text sits above everything.
PrintAt:
  asl a
  asl a
  ora #$20            ; priority bit (high byte $20)
  sta tmp1            ; attribute byte
  A16
  tya
  asl a
  tay
  A8
@l:
  lda $0000,x
  beq @done
  sec
  sbc #32
  sta text_shadow,y
  lda tmp1
  sta text_shadow+1,y
  inx
  iny
  iny
  bra @l
@done:
  lda #1
  sta text_dirty
  rts

; X = value 0-65535, Y = tile index of the rightmost digit, A = palette.
; Prints right-aligned, without leading zeros.
PrintNum:
  asl a
  asl a
  ora #$20
  sta tmp1
  A16
  tya
  asl a
  tay
  txa
@digit:
  sta WRDIVL
  A8
  lda #10
  sta WRDIVB
  nop                 ; the divider needs 16 cycles
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  lda RDMPYL          ; remainder
  clc
  adc #16             ; '0' is font tile 16
  sta text_shadow,y
  lda tmp1
  sta text_shadow+1,y
  dey
  dey
  A16
  lda RDDIVL          ; quotient
  bne @digit
  A8
  lda #1
  sta text_dirty
  rts

; Sets up a screen that shows only BG3 text over a plain backdrop, and loads
; the font and its palettes. Call with the screen off.
TextScreenSetup:
  lda #$09            ; mode 1, BG3 high priority on top
  sta BGMODE
  lda #$58            ; BG3 map at $5800, 32x32
  sta BG3SC
  lda #$04            ; BG3 tiles at $4000
  sta BG34NBA
  lda #$04
  sta TM
  stz TS
  jsr LoadFont
  jmp ClearText

; Font tiles to VRAM $4000 and the text palettes to colors 0-31 of the shadow.
LoadFont:
  ldx #FontTiles
  stx dma_src
  lda #:FontTiles
  sta dma_bank
  ldy #$4000
  ldx #FontTilesEnd-FontTiles
  jsr LoadVram
  ldx #TextPalettes
  stx dma_src
  lda #:TextPalettes
  sta dma_bank
  lda #0
  ldx #64
  jmp SetColors

.ENDS

.SECTION "FontData" SUPERFREE
FontTiles:
  .INCBIN "build/gfx/font.bin"
FontTilesEnd:
TextPalettes:
  .INCBIN "build/gfx/textpal.bin"
.ENDS
