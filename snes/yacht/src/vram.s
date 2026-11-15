; Video memory helpers. Load* routines run with the screen blanked (forced
; blank or NMI); the shadows below are pushed to the PPU by the NMI handler.
.SECTION "Vram" FREE

; DMA to VRAM. dma_src/dma_bank = source, Y = VRAM word address, X = bytes.
LoadVram:
  lda #$80
  sta VMAIN
  sty VMADDL
  lda #$01            ; two registers, $2118/$2119
  sta DMAP0
  lda #<VMDATAL
  sta BBAD0
  bra DmaGo

; DMA to CGRAM. dma_src/dma_bank = source, A = first color, X = bytes.
LoadCgram:
  sta CGADD
  lda #$00
  sta DMAP0
  lda #<CGDATA
  sta BBAD0
DmaGo:
  ldy dma_src
  sty A1T0L
  lda dma_bank
  sta A1B0
  stx DAS0L
  lda #$01
  sta MDMAEN
  rts

; Copies X bytes from dma_src/dma_bank into the CGRAM shadow at color A,
; to be uploaded at the next NMI.
SetColors:
  A16
  and #$00FF
  asl a
  tay
  A8
  stx tmp0
  ldx #0
@l:
  phy
  txy
  lda [dma_src],y
  ply
  sta cg_shadow,y
  iny
  inx
  cpx tmp0
  bne @l
  lda #1
  sta cg_dirty
  rts

; Turns the screen off (forced blank) and stops HDMA.
ScreenOff:
  lda #$80
  sta inidisp_v
  stz hdma_en
  jsr WaitFrame
  lda #$80
  sta INIDISP
  stz HDMAEN
  rts

; All BG scroll registers to 0 across and -1 down, so BG row 0 lands on the
; first visible line (HDMA line numbers then match the art).
ScrollReset:
  ldx #0
@l:
  stz BG1HOFS,x
  stz BG1HOFS,x
  lda #$FF
  sta BG1VOFS,x
  sta BG1VOFS,x
  inx
  inx
  cpx #8
  bne @l
  rts

ScreenOn:
  lda #$0F
  sta inidisp_v
  jmp WaitFrame

; Fills the OAM shadow with hidden sprites.
ClearSprites:
  ldx #0
@l:
  stz oam_shadow,x
  lda #$F0
  sta oam_shadow+1,x
  stz oam_shadow+2,x
  stz oam_shadow+3,x
  inx
  inx
  inx
  inx
  cpx #512
  bne @l
  ldx #0
@h:
  stz oam_shadow+512,x
  inx
  cpx #32
  bne @h
  rts

; NMI part: OAM, CGRAM and the BG3 text map. Called with A8 XY16, DB=0.
NmiVideo:
  ; OAM shadow, 544 bytes
  stz OAMADDL
  stz OAMADDH
  lda #$00
  sta DMAP0
  lda #<OAMDATA
  sta BBAD0
  ldx #oam_shadow
  stx A1T0L
  stz A1B0
  ldx #544
  stx DAS0L
  lda #$01
  sta MDMAEN
  lda cg_dirty
  beq @nocg
  stz cg_dirty
  stz CGADD
  lda #<CGDATA
  sta BBAD0
  ldx #cg_shadow
  stx A1T0L
  ldx #512
  stx DAS0L
  lda #$01
  sta MDMAEN
@nocg:
  lda text_dirty
  beq @notext
  stz text_dirty
  lda #$80
  sta VMAIN
  ldx #$5800
  stx VMADDL
  lda #$01
  sta DMAP0
  lda #<VMDATAL
  sta BBAD0
  ldx #text_shadow
  stx A1T0L
  ldx #2048
  stx DAS0L
  lda #$01
  sta MDMAEN
@notext:
  rts

.ENDS
