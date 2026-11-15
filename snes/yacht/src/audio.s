; Sound: uploads the SPC700 driver at power-on and sends it commands.
; See src/spc/driver.s for the protocol.
.DEFINE AC_MUSIC 1
.DEFINE AC_SFX   2
.DEFINE AC_VOICE 3
.DEFINE AC_STOP  4
.DEFINE AC_MUTE  5
.DEFINE AC_LOAD  6

; Tune ids, in this order: title, score, bad, good, yacht, win, lose
.DEFINE TUNE_TITLE 0
.DEFINE TUNE_SCORE 1
.DEFINE TUNE_BAD   2
.DEFINE TUNE_GOOD  3
.DEFINE TUNE_YACHT 4
.DEFINE TUNE_WIN   5
.DEFINE TUNE_LOSE  6

; Voice clips, in the order of tandy1000/yacht/tools/speech.txt
.DEFINE SPK_YACHT     0
.DEFINE SPK_FULLHOUSE 1
.DEFINE SPK_FOUR      2
.DEFINE SPK_STRAIGHT  3
.DEFINE SPK_YOUWIN    4
.DEFINE SPK_SKIPPER   5
.DEFINE SPK_TIE       6
.DEFINE SPK_WELCOME   7
.DEFINE SPK_P1WINS    8
.DEFINE SPK_P2WINS    9

; Sound effects
.DEFINE SFX_TICK   0
.DEFINE SFX_SELECT 1
.DEFINE SFX_ROLL   2
.DEFINE SFX_HOLD   3
.DEFINE SFX_SCORE  4

.DEFINE VOICE_PITCH $0600       ; 12 kHz clips: 4096 * 12000 / 32000

.SECTION "Audio" FREE

; Loads the driver image into sound RAM at $0200 through the IPL boot ROM
; and starts it. Called once at power-on.
AudioInit:
  ldx #SpcImage
  stx apu_ptr
  lda #:SpcImage
  sta apu_ptr+2
  A16
@ready:
  lda APUIO0
  cmp #$BBAA          ; the IPL ROM is waiting
  bne @ready
  A8
  ldx #$0200
  stx APUIO2          ; destination
  lda #$01
  sta APUIO1          ; data follows
  lda #$CC
  sta APUIO0
@kick:
  cmp APUIO0
  bne @kick
  ldy #0
@byte:
  lda [apu_ptr],y
  sta APUIO1
  tya                 ; low byte of the index is the handshake counter
  sta APUIO0
@ack:
  cmp APUIO0
  bne @ack
  iny
  cpy #SpcImageEnd-SpcImage
  bne @byte
  ; start the driver at $0200
  ldx #$0200
  stx APUIO2
  stz APUIO1
  tya
  clc
  adc #2
  bne @nz
  inc a
@nz:
  sta APUIO0
  sta apu_last
@go:
  cmp APUIO0
  bne @go
  ; the driver says $55 when it has set up the DSP (about a quarter second)
  lda #$55
  ldy #12
@outer:
  ldx #0
@ready2:
  cmp APUIO0
  beq @done
  dex
  bne @ready2
  dey
  bne @outer
@done:
  rts

; A = command, X = argument. Preserves nothing but the register sizes.
AudioCmd:
  cmp #AC_MUSIC
  bne @notmusic
  pha
  txa
  sta last_tune       ; (tests read it)
  pla
@notmusic:
  cmp #AC_VOICE
  bne Send
  jmp AudioVoice

; Sends A = command with X = argument (ports 1-2) and waits for the driver.
Send:
  stx APUIO1
  ora apu_toggle
  cmp apu_last        ; the driver acts on a change of port 0
  bne @new
  eor #$80
@new:
  sta apu_last
  and #$80
  eor #$80
  sta apu_toggle      ; flip for next time
  lda apu_last
  sta APUIO0
  ; wait for the echo, up to about a second, so a silent APU can't hang the game
  ldy #6
@outer:
  ldx #0
@wait:
  cmp APUIO0
  beq @done
  dex
  bne @wait
  dey
  bne @outer
@done:
  rts

; X = voice clip. Streams it into the driver's voice buffer, then plays it.
AudioVoice:
  lda muted
  beq @on
  rts
@on:
  A16
  txa
  and #$00FF
  sta tmp0
  asl a
  asl a
  clc
  adc tmp0            ; clip * 5
  tax
  lda VoiceClips.w,x
  sta apu_ptr
  lda VoiceClips.w+3,x
  sta apu_len
  A8
  lda VoiceClips.w+2,x
  sta apu_ptr+2
  ; "load": length in ports 1-2
  ldx apu_len
  lda #AC_LOAD
  jsr Send
  ; 3 bytes per handshake; the counter on port 0 runs 1..255, 1..
  lda #1
  sta apu_count
  ldy #0
@chunk:
  lda [apu_ptr],y
  sta APUIO1
  iny
  lda [apu_ptr],y
  sta APUIO2
  iny
  lda [apu_ptr],y
  sta APUIO3
  iny
  lda apu_count
  sta APUIO0
  ldx #0
@ack:
  cmp APUIO0
  beq @acked
  dex
  bne @ack
  sta apu_last        ; the driver stopped answering: give up on this clip
  rts
@acked:
  inc a
  bne @nz
  inc a
@nz:
  sta apu_count
  cpy apu_len
  bcc @chunk
  ; the last counter value is now on port 0; Send avoids repeating it
  lda apu_count
  dec a
  bne @last
  lda #255
@last:
  sta apu_last
  lda #AC_VOICE
  ldx #VOICE_PITCH
  jmp Send

; Waits (drawing frames) until the voice clip has finished, at most 6 seconds.
WaitVoice:
  ldx #360
@l:
  lda APUIO1
  and #$01
  beq @r
  phx
  jsr GameFrame
  plx
  lda quit_game
  bne @r
  dex
  bne @l
@r:
  rts

.INCLUDE "build/gfx/voice.inc"

.ENDS

.SECTION "SpcImage" SUPERFREE
SpcImage:
  .INCBIN "build/spc/image.bin"
SpcImageEnd:
.ENDS

.INCLUDE "build/gfx/voice_data.inc"
