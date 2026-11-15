; Title screen: sunset scene, menu, attract mode.
; Returns A = game mode (0 two players, 1 vs Skipper, 2 demo), also in title_choice.
.INCLUDE "build/gfx/title_consts.inc"

.DEFINE SEA_HDMA0  $1000
.DEFINE SEA_HDMA1  $1100
.DEFINE CLOUD_HDMA $1200
.DEFINE IDLE_FRAMES 1200          ; 20 seconds, then the demo plays
.DEFINE MENU_ROW   19
.DEFINE MENU_COL   10          ; menu text column; the cursor die sits 16 px left of it

.SECTION "Title" FREE

TitleRun:
  lda #$FF
  sta title_choice
  jsr ScreenOff
  jsr TitleSetup
  stz menu_sel
  A16
  stz idle
  stz t_frame
  stz cloud_x
  lda #300
  sta gull1_x
  lda #380
  sta gull2_x
  A8
  stz glint_t
  stz spark_t
  stz fade_out
  jsr TitleMenuText
  jsr TitleAnimate
  ldx #TUNE_TITLE
  lda #AC_MUSIC
  jsr AudioCmd
  lda welcomed
  bne @loop
  inc welcomed
  ldx #SPK_WELCOME
  lda #AC_VOICE
  jsr AudioCmd

@loop:
  jsr WaitFrame
  jsr TitleAnimate
  ; brightness: fade in over 16 frames, fade out when leaving
  lda fade_out
  bne @fading
  A16
  lda t_frame
  cmp #15
  A8
  bcs @full
  lda t_frame
  sta inidisp_v
  bra @input
@full:
  lda #$0F
  sta inidisp_v
  bra @input
@fading:
  lda inidisp_v
  bne @dim
  jmp @leave
@dim:
  dec inidisp_v
  jmp @loop

@input:
  A16
  lda pad1
  ora pad2
  clc
  adc entropy
  adc frame
  sta entropy
  lda pad1
  ora pad2
  beq @still
  stz idle
  bra @keys
@still:
  inc idle
  lda idle
  cmp #IDLE_FRAMES
  bcc @keys
  A8
  lda #2              ; nobody touched it: play the demo
  sta pick_mode
  bra @go
@keys:
  A16
  lda pad1_new
  ora pad2_new
  sta tmp3
  and #BTN_SELECT
  A8
  beq @nosel
  jsr ToggleMute      ; Select: sound on/off (saved)
@nosel:
  A16
  lda tmp3
  and #BTN_UP
  A8
  beq @noup
  lda menu_sel
  beq @wrapup
  dec menu_sel
  bra @moved
@wrapup:
  lda #2
  sta menu_sel
  bra @moved
@noup:
  A16
  lda tmp3
  and #BTN_DOWN
  A8
  beq @nodown
  lda menu_sel
  inc a
  cmp #3
  bcc @setdown
  lda #0
@setdown:
  sta menu_sel
@moved:
  ldx #SFX_TICK
  lda #AC_SFX
  jsr AudioCmd
  jsr TitleMenuText
  jmp @loop
@nodown:
  A16
  lda tmp3
  and #BTN_A|BTN_START
  A8
  bne @chosen
  jmp @loop
@chosen:
  A16
  lda menu_sel
  and #$00FF
  tax
  A8
  lda MenuModes.w,x
  sta pick_mode
  ldx #SFX_SELECT
  lda #AC_SFX
  jsr AudioCmd
@go:
  lda #1
  sta fade_out
  jmp @loop

@leave:
  lda #AC_STOP        ; the tune ends with the title (as on the Tandy)
  jsr AudioCmd
  jsr SeedRng
  lda pick_mode
  sta title_choice
  rts

MenuModes:
  .db 1, 0, 2         ; Skipper, two players, demo: same order as the Tandy menu

; Prints the menu, the selected line in gold.
TitleMenuText:
  jsr ClearText
  ldx #StrMenu0
  ldy #MENU_ROW*32+MENU_COL
  lda #0
  jsr @pal
  jsr PrintAt
  ldx #StrMenu1
  ldy #(MENU_ROW+2)*32+MENU_COL
  lda #1
  jsr @pal
  jsr PrintAt
  ldx #StrMenu2
  ldy #(MENU_ROW+4)*32+MENU_COL
  lda #2
  jsr @pal
  jsr PrintAt
  ldx #StrBest
  ldy #(MENU_ROW+6)*32+MENU_COL
  lda #3
  jsr PrintAt
  ldx #StrVersion
  ldy #26*32+1
  lda #3
  jsr PrintAt
  ldx best
  ldy #(MENU_ROW+6)*32+MENU_COL+15
  lda #1
  jmp PrintNum
@pal:
  ; A = this line's number -> palette 1 (gold) if selected, else 0
  cmp menu_sel
  beq @sel
  lda #0
  rts
@sel:
  lda #1
  rts

StrMenu0: .db "PLAY THE SKIPPER", 0
StrMenu1: .db "TWO PLAYERS", 0
StrMenu2: .db "WATCH A DEMO", 0
StrBest:  .db "BEST SCORE", 0
StrVersion: .db VERSION_STR, 0

; Loads the scene and sets up the PPU. Screen must be off.
TitleSetup:
  lda #$09            ; mode 1, BG3 text on top
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
  lda #$63            ; sprites 16x16 / 32x32, tiles at $6000
  sta OBSEL
  lda #$17            ; BG1, BG2, BG3, sprites
  sta TM
  stz TS
  jsr ScrollReset
  ; a dim panel behind the menu: subtract a fixed color inside window 1
  lda #$10
  sta CGWSEL
  lda #$A3            ; subtract, on BG1, BG2 and the backdrop
  sta CGADSUB
  lda #$E9
  sta COLDATA
  lda #$20
  sta WOBJSEL

  ldx #TitleBgChr
  stx dma_src
  lda #:TitleBgChr
  sta dma_bank
  ldy #$0000
  ldx #TitleBgChrEnd-TitleBgChr
  jsr LoadVram
  ldx #TitleBg1Map
  stx dma_src
  lda #:TitleBg1Map
  sta dma_bank
  ldy #$5000
  ldx #2048
  jsr LoadVram
  ldx #TitleBg2Map
  stx dma_src
  lda #:TitleBg2Map
  sta dma_bank
  ldy #$5400
  ldx #2048
  jsr LoadVram
  ldx #TitleSprChr
  stx dma_src
  lda #:TitleSprChr
  sta dma_bank
  ldy #$6000
  ldx #TitleSprChrEnd-TitleSprChr
  jsr LoadVram
  jsr LoadFont
  ldx #TitlePal
  stx dma_src
  lda #:TitlePal
  sta dma_bank
  lda #32
  ldx #448
  jsr SetColors
  ; the glitter colors (the art marks them with placeholder colors)
  A16
  lda #SPARK_A
  sta cg_shadow+(TITLE_SPARK_COLOR)*2
  lda #SPARK_B
  sta cg_shadow+(TITLE_SPARK_COLOR+1)*2
  lda #SPARK_C
  sta cg_shadow+(TITLE_SPARK_COLOR+2)*2
  A8

  ; HDMA: 1 sky colors, 2 sea sway, 3 cloud drift, 4 menu panel window
  lda #$03
  sta $4310
  lda #$21
  sta $4311
  ldx #TitleSky
  stx $4312
  lda #:TitleSky
  sta $4314
  lda #$02
  sta $4320
  lda #<BG1HOFS
  sta $4321
  ldx #SEA_HDMA0
  stx $4322
  stz $4324
  lda #$02
  sta $4330
  lda #<BG2HOFS
  sta $4331
  ldx #CLOUD_HDMA
  stx $4332
  stz $4334
  lda #$01
  sta $4340
  lda #<WH0
  sta $4341
  ldx #TitleWindow
  stx $4342
  lda #:TitleWindow
  sta $4344
  ; sea tables: lines 0-127 hold 0, then 96 lines of offsets
  ldx #0
@hdr:
  lda SeaHeader.w,x
  sta SEA_HDMA0,x
  sta SEA_HDMA1,x
  inx
  cpx #7
  bne @hdr
  stz SEA_HDMA0+7+192
  stz SEA_HDMA1+7+192
  ldx #0
@cl:
  lda CloudTable.w,x
  sta CLOUD_HDMA,x
  inx
  cpx #7
  bne @cl
  ldx #SEA_HDMA0
  stx sea_ptr
  lda #$1E
  sta hdma_en
  rts

SeaHeader:  .db $7F, 0, 0, $01, 0, 0, $80|96
CloudTable: .db 72, 0, 0, 1, 0, 0, 0

; Everything that moves on the title, once per frame.
TitleAnimate:
  A16
  inc t_frame
  ; --- sea sway: copy this frame's 96 offsets into the idle buffer
  lda t_frame
  lsr a
  and #$003F
  sta WRMPYA          ; (8-bit write of the low byte)
  A8
  lda #96
  sta WRMPYB
  nop
  nop
  nop
  nop
  ldx RDMPYL          ; phase * 96
  ldy #SEA_HDMA0+7
  A16
  lda sea_ptr
  cmp #SEA_HDMA0
  bne @buf
  ldy #SEA_HDMA1+7
@buf:
  sty tmp0
  lda #96
  sta tmp1
@sea:
  lda TitleWaves.l,x
  and #$00FF
  cmp #$0080
  bcc @p
  ora #$FF00
@p:
  sta $0000,y
  iny
  iny
  inx
  dec tmp1
  bne @sea
  lda tmp0
  sec
  sbc #7
  sta sea_ptr         ; NMI points HDMA channel 2 here
  ; --- clouds drift left, one pixel every 4 frames
  lda t_frame
  and #$0003
  bne @nocloud
  inc cloud_x
  lda cloud_x
  sta CLOUD_HDMA+1
@nocloud:
  A8
  ; --- glitter on the water: rotate its three colors every 6 frames
  inc spark_t
  lda spark_t
  cmp #6
  bcc @nospark
  stz spark_t
  A16
  lda cg_shadow+(TITLE_SPARK_COLOR)*2
  pha
  lda cg_shadow+(TITLE_SPARK_COLOR+1)*2
  sta cg_shadow+(TITLE_SPARK_COLOR)*2
  lda cg_shadow+(TITLE_SPARK_COLOR+2)*2
  sta cg_shadow+(TITLE_SPARK_COLOR+1)*2
  pla
  sta cg_shadow+(TITLE_SPARK_COLOR+2)*2
  A8
  lda #1
  sta cg_dirty
@nospark:
  jsr LogoGlint
  ; --- sprites
  jsr SpritesBegin
  ; menu cursor: a small die that bobs beside the chosen line
  A16
  lda #MENU_COL*8-16
  sta spr_x
  A8
  lda menu_sel
  asl a
  asl a
  asl a
  asl a
  clc
  adc #MENU_ROW*8-5
  sta spr_y
  lda t_frame
  and #$10
  beq @c0
  dec spr_y
@c0:
  ldx #MetaCursor
  jsr DrawMeta
  ; logo (its metasprite is measured from the center)
  A16
  lda #128
  sta spr_x
  A8
  lda #14
  sta spr_y
  ldx #MetaLogo
  jsr DrawMeta
  ; sailboat rocking on the swell
  A16
  lda #4
  sta spr_x
  lda t_frame
  and #$00FF
  tax
  A8
  lda Sine.l,x
  cmp #$80
  ror a
  cmp #$80
  ror a
  cmp #$80
  ror a
  cmp #$80
  ror a
  cmp #$80
  ror a               ; -4..3
  clc
  adc #100
  sta spr_y
  ldx #MetaBoat
  jsr DrawMeta
  ; two gulls gliding right to left
  ldx #gull1_x
  lda #52
  jsr Gull
  ldx #gull2_x
  lda #70
  jsr Gull
  jmp SpritesEnd

; X = address of the gull's x (16-bit), A = its base height.
Gull:
  sta tmp3
  A16
  lda t_frame
  and #$0001
  bne @still
  lda $0000,x
  dec a
  cmp #$FFE0          ; off the left edge: come back from the right
  bne @keep
  lda #300
@keep:
  sta $0000,x
@still:
  lda $0000,x
  sta spr_x
  ; gentle rise and fall
  asl a
  and #$00FF
  phx
  tax
  A8
  lda Sine.l,x
  plx
  cmp #$80
  ror a
  cmp #$80
  ror a
  cmp #$80
  ror a
  cmp #$80
  ror a
  clc
  adc tmp3
  sta spr_y
  ldx #MetaGullLevel
  lda t_frame
  and #$18
  bne @draw
  ldx #MetaGullUp
@draw:
  jmp DrawMeta

; A glint runs across the logo's gold every couple of seconds.
LogoGlint:
  inc glint_t
  lda glint_t
  cmp #120
  bcc @run
  stz glint_t
@run:
  lda glint_t
  lsr a
  lsr a               ; band 0-3 during the first 16 frames
  sta tmp0
  ldx #0              ; entry offset in cg_shadow, from color 131
  ldy #0              ; level*4 + band
@l:
  A16
  phy
  tya
  lsr a
  lsr a
  asl a
  tay                 ; level * 2
  lda LogoLevels.w,y
  sta tmp1
  lda LogoLevelsHi.w,y
  sta tmp2
  ply
  tya
  and #$0003
  A8
  cmp tmp0
  bne @normal
  lda glint_t
  cmp #16
  bcs @normal
  A16
  lda tmp2
  bra @put
@normal:
  A16
  lda tmp1
@put:
  sta cg_shadow+131*2,x
  A8
  inx
  inx
  iny
  cpy #12
  bne @l
  lda #1
  sta cg_dirty
  rts

LogoLevels:   .dw LOGO_LV0, LOGO_LV1, LOGO_LV2
LogoLevelsHi: .dw LOGO_LV0_HI, LOGO_LV1_HI, LOGO_LV2_HI

; Menu panel window: off above line 144, x 52-219 for lines 144-211, then off.
; (12 px around the cursor die and the longest line; tests/layout.lua reads the third entry.)
TitleWindow:
  .db 127, $FF, $00
  .db 17, $FF, $00
  .db 68, MENU_COL*8-28, MENU_COL*8+139
  .db 1, $FF, $00
  .db 0

.INCLUDE "build/gfx/title_meta.inc"

.ENDS

.SECTION "TitleBgChr" SUPERFREE
TitleBgChr:
  .INCBIN "build/gfx/title_bg.chr"
TitleBgChrEnd:
.ENDS
.SECTION "TitleSprChr" SUPERFREE
TitleSprChr:
  .INCBIN "build/gfx/title_spr.chr"
TitleSprChrEnd:
.ENDS
.SECTION "TitleMaps" SUPERFREE
TitleBg1Map:
  .INCBIN "build/gfx/title_bg1.map"
TitleBg2Map:
  .INCBIN "build/gfx/title_bg2.map"
TitlePal:
  .INCBIN "build/gfx/title.pal"
TitleSky:
  .INCBIN "build/gfx/title_sky.hdma"
.ENDS
.SECTION "TitleWaves" SUPERFREE
TitleWaves:
  .INCBIN "build/gfx/title_waves.bin"
Sine:
  .INCBIN "build/gfx/sine.bin"
.ENDS
