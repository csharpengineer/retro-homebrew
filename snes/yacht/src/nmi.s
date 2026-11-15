; NMI: runs once per frame at the start of vertical blank.
.SECTION "Nmi" FREE

NmiHandler:
  AXY16
  pha
  phx
  phy
  phd
  phb
  lda #$0000
  tcd
  A8
  phk
  plb
  lda RDNMI           ; acknowledge

  lda nmi_ready
  beq @late           ; main loop still busy: skip the video work this frame
  stz nmi_ready
  lda inidisp_v
  sta INIDISP
  XY16
  jsr NmiVideo
  lda regs_dirty      ; layer / color math changes queued by the main loop
  beq @noregs
  stz regs_dirty
  lda tm_v
  sta TM
  lda cgwsel_v
  sta CGWSEL
  lda cgadsub_v
  sta CGADSUB
  lda coldata_v
  sta COLDATA
@noregs:
  ldx sea_ptr
  stx $4322           ; title sea: the table built for this frame
  lda hdma_en
  sta HDMAEN
@late:
  ; Auto joypad read finishes a few lines into vblank.
-:
  lda HVBJOY
  and #$01
  bne -
  A16
  ; New presses pile up until the main loop collects them in WaitFrame, so a
  ; press is never lost when the main loop runs longer than a frame.
  lda JOY1L
  sta pad1
  eor pad1_last
  and pad1
  ora pad1_acc
  sta pad1_acc
  lda pad1
  sta pad1_last
  lda JOY2L
  sta pad2
  eor pad2_last
  and pad2
  ora pad2_acc
  sta pad2_acc
  lda pad2
  sta pad2_last
  inc frame

  AXY16
  plb
  pld
  ply
  plx
  pla
  rti

.ENDS
