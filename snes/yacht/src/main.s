; YACHT for the Super Nintendo. Single assembly unit: this file includes the rest.
.INCLUDE "header.inc"
.INCLUDE "hw.inc"
.INCLUDE "vars.inc"

.BANK 0 SLOT 0
.ORG 0
.SECTION "Boot" FORCE

Reset:
  sei
  clc
  xce                 ; native mode
  AXY16
  cld
  ldx #STACK_TOP
  txs
  lda #$0000
  tcd                 ; direct page = $0000
  A8
  phk
  plb                 ; data bank = $00
  lda #$80
  sta INIDISP         ; force blank
  stz NMITIMEN
  stz HDMAEN
  stz MDMAEN

  ; Clear all 128 KB of work RAM with two 64 KB fixed-source DMAs.
  ; Nothing has been pushed yet, so clearing the stack area is safe.
  stz WMADDL
  stz WMADDM
  stz WMADDH
  lda #$08            ; fixed source, A bus -> B bus, one register
  sta DMAP0
  lda #<WMDATA
  sta BBAD0
  ldx #ZeroByte
  stx A1T0L
  lda #:ZeroByte
  sta A1B0
  ldx #$0000          ; 0 = 65536 bytes
  stx DAS0L
  lda #$01
  sta MDMAEN
  stx DAS0L
  sta MDMAEN

  jsr InitPpu
  jsr ClearVram
  jsr ClearCgram
  jsr ClearOam
  jsr ClearSprites    ; the OAM shadow goes to the PPU every frame from now on

  lda #$0F
  sta inidisp_v
  lda #$81            ; NMI on, auto joypad read on
  sta NMITIMEN
  cli

  jsr AudioInit       ; sound driver into the APU
  jsr SaveLoad        ; best score and sound setting from the battery RAM

  ; L+R held at power-on: run the self test instead of the game.
  jsr WaitFrame
  A16
  lda pad1
  and #BTN_L|BTN_R
  cmp #BTN_L|BTN_R
  A8
  bne MainLoop
  jmp SelfTest

MainLoop:
  jsr TitleRun
  jsr GameRun
  bra MainLoop


; Hands the frame to NMI and waits for it to run.
WaitFrame:
  lda #1
  sta nmi_ready
  A16
  lda frame
-:
  cmp frame
  beq -
  ; collect the presses since the last call (the next NMI is a frame away)
  lda pad1_acc
  sta pad1_new
  stz pad1_acc
  lda pad2_acc
  sta pad2_new
  stz pad2_acc
  A8
  rts

InitPpu:
  ; Every PPU register to a known value: nothing may depend on power-on state.
  ldx #$2101
-:
  stz $00,x
  inx
  cpx #$2134
  bne -
  ; Write-twice scroll registers need a second zero.
  stz BG1HOFS
  stz BG1VOFS
  stz BG2HOFS
  stz BG2VOFS
  stz BG3HOFS
  stz BG3VOFS
  stz BG4HOFS
  stz BG4VOFS
  lda #$80
  sta VMAIN           ; increment after high byte
  lda #$30
  sta CGWSEL          ; color math off
  lda #$E0
  sta COLDATA         ; fixed color black
  lda #$FF
  sta WRIO
  rts

ClearVram:
  lda #$80
  sta VMAIN
  ldx #$0000
  stx VMADDL
  lda #$09            ; fixed source, two registers ($2118/$2119)
  sta DMAP0
  lda #<VMDATAL
  sta BBAD0
  ldx #ZeroByte
  stx A1T0L
  lda #:ZeroByte
  sta A1B0
  ldx #$0000
  stx DAS0L
  lda #$01
  sta MDMAEN
  rts

ClearCgram:
  stz CGADD
  lda #$08
  sta DMAP0
  lda #<CGDATA
  sta BBAD0
  ldx #ZeroByte
  stx A1T0L
  lda #:ZeroByte
  sta A1B0
  ldx #512
  stx DAS0L
  lda #$01
  sta MDMAEN
  rts

ClearOam:
  ; All 128 sprites below the visible screen.
  stz OAMADDL
  stz OAMADDH
  ldx #128
-:
  stz OAMDATA         ; x
  lda #$F0
  sta OAMDATA         ; y = 240, off screen
  stz OAMDATA
  stz OAMDATA
  dex
  bne -
  ldx #32
-:
  stz OAMDATA
  dex
  bne -
  rts

EmptyHandler:
  rti

ZeroByte:
  .db 0

.ENDS

.INCLUDE "nmi.s"
.INCLUDE "rules.s"
.INCLUDE "selftest.s"
.INCLUDE "skipper.s"
.INCLUDE "vram.s"
.INCLUDE "text.s"
.INCLUDE "sprites.s"
.INCLUDE "audio.s"
.INCLUDE "title.s"
.INCLUDE "game.s"
.INCLUDE "save.s"
