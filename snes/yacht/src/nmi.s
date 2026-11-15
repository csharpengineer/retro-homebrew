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
  ; Auto joypad read finishes a few lines into vblank. On the short path (main
  ; loop late) we could get here before it has even started, so idle a little
  ; first: the extra port-2 read below must not land inside the auto read.
  ldx #24
-:
  dex
  bne -
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
  ; One more bit from port 2 after the 16 the auto read took: a standard
  ; controller sends 1s from here on, an empty port reads 0. A pad that has
  ; ever pressed a button also counts (some third-party pads send 0s here).
  lda pad2
  beq +
  ldx #1
  stx pad2_seen
+:
  A8
  lda JOYSER1
  and #$01
  ora pad2_seen
  sta pad2_on

  AXY16
  plb
  pld
  ply
  plx
  pla
  rti

.ENDS
