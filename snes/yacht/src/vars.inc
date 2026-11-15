; Work RAM variables. Everything below $2000 is reachable from bank $00
; with direct page $0000. Fixed test addresses live at $7E1F00 and up.
.ENUM $0000 EXPORT
  tmp0        dw      ; scratch, any routine may clobber
  tmp1        dw
  tmp2        dw
  tmp3        dw
  res16       dw      ; 16-bit result of rules routines
  frame       dw      ; increments every NMI
  nmi_ready   db      ; main loop sets it when the frame's shadow data is ready
  pad1        dw      ; held buttons, controller 1
  pad2        dw
  pad1_new    dw      ; newly pressed this frame
  pad2_new    dw
  pad1_last   dw
  pad1_acc    dw      ; presses gathered by NMI, collected by WaitFrame
  pad2_acc    dw
  pad2_last   dw
  pad2_on     db      ; 1 while a controller is plugged into port 2 (read in NMI)
  pad2_seen   dw      ; 1 once controller 2 has pressed anything
  inidisp_v   db      ; brightness written in NMI
  dma_src     dw      ; 24-bit source pointer for DMA helpers (with dma_bank)
  dma_bank    db
  apu_ptr     dsb 3   ; long pointer for sound uploads (must stay in the direct page)
  apu_len     dw
  apu_last    db      ; last value written to APU port 0
  apu_toggle  db
  apu_count   db
  cg_dirty    db      ; NMI uploads cg_shadow when set
  text_dirty  db      ; NMI uploads text_shadow when set
  regs_dirty  db      ; NMI writes the four shadows below when set
  tm_v        db
  cgwsel_v    db
  cgadsub_v   db
  coldata_v   db

  ; ---- game state (same meaning as the Tandy version) ----
  dice        dsb 5   ; faces 1-6, 0 = not rolled yet
  dice_pad    db      ; keeps 16-bit reads of dice[4] inside our own data
  held        dsb 5   ; 1 = held
  rolls_left  db
  counts      dsb 7   ; counts[1..6] for the current dice
  sum         dw      ; sum of the current dice
  scores      dsw 24  ; player 0 boxes 0-11, then player 1; $FFFF = empty
  cur         db      ; player on turn
  game_mode   db      ; 0 two players, 1 vs Skipper, 2 demo
  seed        dw      ; random generator state
  best        dw
  muted       db

  ; ---- video / sprites ----
  hdma_en     db      ; NMI writes it to HDMAEN
  sea_ptr     dw      ; HDMA table for the title sea, swapped each frame
  oam_next    dw      ; next free byte in oam_shadow
  spr_x       dw      ; metasprite position (x is 16-bit signed)
  spr_y       db

  ; ---- title ----
  title_choice db     ; $FF while the title runs, then the chosen mode
  pick_mode   db
  menu_sel    db
  idle        dw
  t_frame     dw
  cloud_x     dw
  gull1_x     dw
  gull2_x     dw
  glint_t     db
  spark_t     db
  fade_out    db
  welcomed    db
  entropy     dw
  last_tune   db      ; last music request (tests read it)

  ; ---- game ----
  in_game     db      ; 1 while the game screen runs
  game_state  db      ; 0 waiting for a human, 1 busy, 2 game over
  quit_game   db
  paused      db
  focus       db      ; 0 dice tray, 1 scorecard
  cursor      db      ; scorecard box
  chosen      db
  hilite_on   db
  dim_all     db
  spr_attr    db
  spr_big     db
  die_sel     dw      ; (word: only the low byte is ever written)
  tumble_t    dw
  end_tune    dw
  end_clip    dw
  end_msg     dw
  last_score  dw
  tot0        dw
  tot1        dw
  turn_pad    dw
  cell_pos    dw
  spr_tile    dw

  ; ---- Skipper working storage ----
  ai_best_v   dw
  ai_best_c   db
  ai_c        db
  ai_dl       db
  ai_dh       db
  ai_f        db
  ai_w        db
  ai_bw       db
  ai_bf       db

  ; ---- self test ----
  st_index    dw
  st_count    dw
  st_fail     dw
  st_loop     dw
  st_faces    dsw 7
.ENDE

; Shadows of PPU memory, copied by the NMI handler (fixed places in low RAM).
.ENUM $0300 EXPORT
  oam_shadow  dsb 544 ; 128 sprites x 4 bytes, then the 32-byte high table
  cg_shadow   dsb 512 ; all 256 colors
.ENDE
.ENUM $0800 EXPORT
  text_shadow dsb 2048 ; BG3 tilemap, 32x32 entries
.ENDE

.DEFINE VERSION_STR "V1.1"   ; shown on the title; also VERSION in header.inc
.DEFINE STACK_TOP $1EFF
.DEFINE EMPTY     $FFFF
.DEFINE NUM_CATS  12
.DEFINE CAT_FULL   6
.DEFINE CAT_FOUR   7
.DEFINE CAT_LITTLE 8
.DEFINE CAT_BIG    9
.DEFINE CAT_CHOICE 10
.DEFINE CAT_YACHT  11

; Fixed addresses read by the emulator tests (bank $00 mirrors of $7E1Fxx).
.DEFINE TEST_RESULT $1F00   ; $5A5A when done, then checks run, then failures
.DEFINE ORACLE      $1F10   ; mailbox, layout in tests/yacht_ref.lua
.DEFINE O_CMD    ORACLE+0
.DEFINE O_DICE   ORACLE+1
.DEFINE O_ROLLS  ORACLE+6
.DEFINE O_OPEN   ORACLE+7
.DEFINE O_SCORES ORACLE+19
.DEFINE O_HOLDS  ORACLE+43
.DEFINE O_PICK   ORACLE+48
.DEFINE O_SAT    ORACLE+49
.DEFINE O_DONE   ORACLE+50
.DEFINE TEST_SEED   $1F80   ; non-zero: seed the game with it (tests only)
