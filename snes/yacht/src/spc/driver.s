; YACHT sound driver for the SPC700. Assembled with wla-spc700 to a raw
; binary loaded at $0200; tools/spcimage.js appends the tables and samples.
;
; Commands from the CPU: port 0 = command (bit 7 toggles so repeats show),
; ports 1-3 = argument. The driver echoes port 0 when the command is done.
;   1 music (port1 = tune)       2 sound effect (port1 = effect)
;   3 play voice (ports 1-2 = pitch)  4 stop music
;   5 mute (port1 = 0/1)         6 load voice (ports 1-2 = length), then
;     3 bytes per handshake on ports 1-3 with a counter on port 0
; Status out: port 1 bit 0 = a voice clip is playing. Port 0 reads $55 once
; the driver is ready, before the first command.
; State for the tests: $E0 tune ($FF none), $E1 voice playing, $E2 muted, $E3 last key-on.

.MEMORYMAP
  SLOTSIZE $10000
  DEFAULTSLOT 0
  SLOT 0 $0000
.ENDME
.ROMBANKSIZE $10000
.ROMBANKS 1

; tables placed by tools/spcimage.js
.DEFINE DIR_PAGE  $10       ; sample directory at $1000
.DEFINE TUNES     $1100     ; 8 tunes x 4 stream pointers
.DEFINE TUNELOOP  $1140     ; 8 loop flags
.DEFINE SFXTAB    $1150     ; 8 effects x 2 stream pointers (channels 4 and 5)
.DEFINE INSTR     $1170     ; 16 instruments x 8: srcn, adsr1, adsr2, vol, noise
.DEFINE PITCH     $1200     ; 64 pitches (16-bit), index = Tandy note number
.DEFINE VOICE_SRCN 63

; direct page
.DEFINE ch_ptr    $00       ; word per channel (x = channel*2)
.DEFINE ch_left   $10
.DEFINE ch_inst   $20
.DEFINE ch_on     $30
.DEFINE ch_start  $40
.DEFINE last_cmd  $50
.DEFINE loopflag  $51
.DEFINE kon       $52
.DEFINE kof       $53
.DEFINE tmp       $54
.DEFINE tmp2      $55
.DEFINE ptr       $56       ; word
.DEFINE remain    $58       ; word
.DEFINE three     $5A       ; word constant 3
.DEFINE counter   $5C
.DEFINE flg       $5D       ; DSP FLG without the noise clock
.DEFINE noisebits $5E
.DEFINE duck      $5F
.DEFINE voiceon   $60
.DEFINE muted     $61
.DEFINE chan      $62
.DEFINE tick_kof  $63       ; key-offs from the last tick, held until the next
.DEFINE ST_TUNE   $E0
.DEFINE ST_VOICE  $E1
.DEFINE ST_MUTED  $E2
.DEFINE ST_KON    $E3

; DSP registers
.DEFINE MVOLL $0C
.DEFINE MVOLR $1C
.DEFINE EVOLL $2C
.DEFINE EVOLR $3C
.DEFINE KON   $4C
.DEFINE KOF   $5C
.DEFINE FLG   $6C
.DEFINE ENDX  $7C
.DEFINE EFB   $0D
.DEFINE PMON  $2D
.DEFINE NON   $3D
.DEFINE EON   $4D
.DEFINE DIR   $5D
.DEFINE ESA   $6D
.DEFINE EDL   $7D

.MACRO DSPW ; register, then A = value
  mov $F2,#\1
  mov $F3,a
.ENDM

.BANK 0 SLOT 0
.ORG $0200

Start:
  clrp
  mov x,#$EF
  mov sp,x
  ; clear direct page $00-$EF
  mov a,#0
  mov x,#0
@clr:
  mov (x)+,a
  cmp x,#$F0
  bne @clr
  mov a,#$FF
  mov ST_TUNE,a
  mov three,#3
  mov three+1,#0
  ; DSP: silent and echo writes off while it settles
  mov a,#$60
  DSPW FLG
  mov a,#$FF
  DSPW KOF
  mov a,#0
  DSPW KOF
  DSPW MVOLL
  DSPW MVOLR
  DSPW EVOLL
  DSPW EVOLR
  DSPW PMON
  DSPW NON
  DSPW EON
  DSPW EFB
  mov a,#DIR_PAGE
  DSPW DIR
  mov a,#$E8          ; echo buffer $E800-$FFFF (6 KB)
  DSPW ESA
  mov a,#3
  DSPW EDL
  ; voices: volume 0
  mov x,#0
@vv:
  mov a,x
  mov $F2,a
  mov $F3,#0
  inc a
  mov $F2,a
  mov $F3,#0
  mov a,x
  clrc
  adc a,#$10
  mov x,a
  cmp x,#$80
  bne @vv
  ; timer 0: 8000 / 110 = 72.7 ticks a second, the Tandy tempo; clear the ports
  mov $FA,#110
  mov $F1,#$31
  ; wait ~250 ms for the echo length to take effect before echo writes start
  mov y,#20
@settle:
  mov a,$FD
  beq @settle
  dbnz y,@settle
  ; a soft echo for the music channels
  mov x,#0
@fir:
  mov a,x
  xcn a
  or a,#$0F
  mov $F2,a
  mov a,!FirTable+x
  mov $F3,a
  inc x
  cmp x,#8
  bne @fir
  mov a,#$38
  DSPW EFB
  mov a,#$18
  DSPW EVOLL
  DSPW EVOLR
  mov a,#$0F
  DSPW EON
  mov flg,#$00        ; sound on, echo writes on
  mov a,flg
  DSPW FLG
  mov a,#$60
  DSPW MVOLL
  DSPW MVOLR
  ; ready: from now on any change of port 0 is a command
  mov a,$F4
  mov last_cmd,a
  mov $F4,#$55

Main:
  mov a,$FD
  beq @nocmdtick
  call !Tick
@nocmdtick:
  mov a,$F4
  cmp a,$F4           ; two reads must agree: a port read while the CPU writes it can glitch
  bne @voice
  cmp a,last_cmd
  beq @voice
  call !Command
@voice:
  ; voice clip finished?
  mov a,voiceon
  beq @status
  mov $F2,#ENDX
  mov a,$F3
  and a,#$80
  beq @status
  call !VoiceDone
@status:
  mov a,voiceon
  mov $F5,a
  bra Main

; ------------------------------------------------------------ commands

Command:
  mov last_cmd,a
  and a,#$7F
  cmp a,#1
  bne @c2
  call !CmdMusic
  bra @ack
@c2:
  cmp a,#2
  bne @c3
  call !CmdSfx
  bra @ack
@c3:
  cmp a,#3
  bne @c4
  call !CmdVoice
  bra @ack
@c4:
  cmp a,#4
  bne @c5
  call !StopMusic
  bra @ack
@c5:
  cmp a,#5
  bne @c6
  call !CmdMute
  bra @ack
@c6:
  cmp a,#6
  bne @ack
  jmp !CmdLoad
@ack:
  mov a,last_cmd
  mov $F4,a
  ret

CmdMusic:
  call !StopMusic
  mov a,$F5
  and a,#7
  mov ST_TUNE,a
  mov y,a
  mov a,!TUNELOOP+y
  mov loopflag,a
  mov a,ST_TUNE
  asl a
  asl a
  asl a               ; tune * 8
  mov y,a
  mov x,#0
@ch:
  mov a,!TUNES+y
  mov ch_ptr+x,a
  mov ch_start+x,a
  mov tmp,a
  inc y
  mov a,!TUNES+y
  mov ch_ptr+1+x,a
  mov ch_start+1+x,a
  or a,tmp
  mov ch_on+x,a       ; non-zero pointer: channel plays
  mov a,#0
  mov ch_left+x,a
  inc y
  inc x
  inc x
  cmp x,#8
  bne @ch
  ret

StopMusic:
  mov a,#$0F
  call !KeyOff
  mov a,#0
  mov ch_on+0,a
  mov ch_on+2,a
  mov ch_on+4,a
  mov ch_on+6,a
  mov a,#$FF
  mov ST_TUNE,a
  ret

CmdSfx:
  mov a,$F5
  and a,#7
  asl a
  asl a               ; effect * 4
  mov y,a
  mov x,#8            ; channels 4 and 5
@ch:
  mov a,!SFXTAB+y
  mov tmp,a
  inc y
  mov a,!SFXTAB+y
  inc y
  mov tmp2,a
  or a,tmp
  beq @skip
  mov a,tmp
  mov ch_ptr+x,a
  mov a,tmp2
  mov ch_ptr+1+x,a
  mov a,#1
  mov ch_on+x,a
  mov a,#0
  mov ch_left+x,a
@skip:
  inc x
  inc x
  cmp x,#12
  bne @ch
  ret

CmdMute:
  mov a,$F5
  and a,#1
  mov muted,a
  mov ST_MUTED,a
  beq @on
  mov a,#0
  DSPW MVOLL
  DSPW MVOLR
  mov a,flg
  or a,#$40           ; the DSP's mute: silences the echo return too
  mov flg,a
  DSPW FLG
  mov a,#$80          ; stop the voice clip
  call !KeyOff
  jmp !VoiceDone
@on:
  mov a,flg
  and a,#$BF
  mov flg,a
  DSPW FLG
  mov a,#$60
  DSPW MVOLL
  DSPW MVOLR
  ret

; Keys off the voices in A. The DSP looks at KOF only every 64 cycles, so the
; bits stay set for ~100 cycles before going back to the tick's own key-offs.
KeyOff:
  or a,tick_kof
  DSPW KOF
  mov y,#16
@hold:
  dbnz y,@hold
  mov a,tick_kof
  DSPW KOF
  ret

; Plays the clip in the voice buffer on voice 7 at pitch ports 1-2.
CmdVoice:
  mov a,muted
  bne @r
  mov a,#VOICE_SRCN
  DSPW $74            ; voice 7 SRCN
  mov a,#$00
  DSPW $75            ; ADSR off: GAIN controls the level
  mov a,#$7F
  DSPW $77            ; GAIN: full, direct
  mov a,#$70
  DSPW $70
  DSPW $71            ; volume L/R
  mov a,$F5
  DSPW $72
  mov a,$F6
  DSPW $73            ; pitch
  mov a,#$80
  DSPW KON
  mov voiceon,#1
  mov ST_VOICE,#1
  mov duck,#1
  call !Reduck
@r:
  ret

VoiceDone:
  mov voiceon,#0
  mov ST_VOICE,#0
  mov duck,#0
  jmp !Reduck

; Receives a voice clip into $A800: ports 1-2 = length. Acknowledges, then
; takes 3 bytes per handshake (counter on port 0: 1, 2, ... 255, 1, ...).
CmdLoad:
  mov a,$F5
  mov remain,a
  mov a,$F6
  mov remain+1,a
  mov ptr,#$00
  mov ptr+1,#$A8
  mov counter,#1
  mov a,last_cmd
  mov $F4,a           ; ready
@wait:
  mov a,$FD
  beq @nt
  call !Tick
@nt:
  mov a,$F4
  cmp a,counter
  bne @wait
  mov y,#0
  mov a,$F5
  mov [ptr]+y,a
  inc y
  mov a,$F6
  mov [ptr]+y,a
  inc y
  mov a,$F7
  mov [ptr]+y,a
  mov a,counter
  mov $F4,a           ; got them
  mov last_cmd,a
  mov a,ptr
  clrc
  adc a,#3
  mov ptr,a
  adc ptr+1,#0
  inc counter
  bne @nz
  inc counter
@nz:
  movw ya,remain
  subw ya,three
  movw remain,ya
  bmi @done
  bne @wait
@done:
  ret

; ------------------------------------------------------------ music

; One tick: advance every playing channel.
Tick:
  mov a,#0            ; release the last tick's key-offs (held ~14 ms, long enough)
  mov tick_kof,a
  DSPW KOF
  mov kon,#0
  mov kof,#0
  mov x,#0
@ch:
  mov a,ch_on+x
  beq @next
  mov a,ch_left+x
  beq @fetch
  dec ch_left+x
  bne @next
@fetch:
  call !Fetch
@next:
  inc x
  inc x
  cmp x,#12
  bne @ch
  mov a,kof
  mov tick_kof,a
  DSPW KOF            ; stays set until the next tick
  mov a,kon
  mov ST_KON,a
  DSPW KON
  ret

; Reads events for channel x until one takes time.
Fetch:
  call !NextByte
  cmp a,#$FF
  bne @notend
  ; end of stream: loop the title tune, otherwise stop
  cmp x,#8
  bcs @stop
  mov a,loopflag
  beq @stop
  mov a,ch_start+x
  mov ch_ptr+x,a
  mov a,ch_start+1+x
  mov ch_ptr+1+x,a
  bra Fetch
@stop:
  mov a,#0
  mov ch_on+x,a
  call !ChanBit
  or a,kof
  mov kof,a
  cmp x,#8
  bcs @r
  ; a music channel finished: when all four have, the tune is over
  mov a,ch_on+0
  or a,ch_on+2
  or a,ch_on+4
  or a,ch_on+6
  bne @r
  mov a,#$FF
  mov ST_TUNE,a
@r:
  ret
@notend:
  cmp a,#$81
  bne @notinst
  call !NextByte
  mov ch_inst+x,a
  call !SetInstrument
  bra Fetch
@notinst:
  cmp a,#$80
  bne @note
  ; rest
  call !NextByte
  mov ch_left+x,a
  call !ChanBit
  or a,kof
  mov kof,a
  ret
@note:
  mov tmp,a           ; note number (or noise clock)
  call !NextByte
  mov ch_left+x,a
  ; noise instrument?
  mov a,ch_inst+x
  asl a
  asl a
  asl a
  mov y,a
  mov a,!INSTR+4+y
  beq @tone
  mov a,tmp
  and a,#$1F
  or a,flg
  DSPW FLG
  bra @key
@tone:
  mov a,tmp
  asl a
  mov y,a
  call !VoiceReg      ; A = voice * 16
  or a,#2
  mov $F2,a
  mov a,!PITCH+y
  mov $F3,a
  inc $F2
  mov a,!PITCH+1+y
  mov $F3,a
@key:
  call !ChanBit
  or a,kon
  mov kon,a
  ret

; A = next byte of channel x's stream.
NextByte:
  mov a,[ch_ptr+x]
  inc ch_ptr+x
  bne @r
  inc ch_ptr+1+x
@r:
  ret

; A = the channel's DSP voice bit.
ChanBit:
  mov a,x
  lsr a
  mov y,a
  mov a,!Bits+y
  ret

; A = the channel's DSP voice register base (voice * 16).
VoiceReg:
  mov a,x
  asl a
  asl a
  asl a
  ret

; Loads instrument ch_inst+x into the channel's voice.
SetInstrument:
  mov a,ch_inst+x
  asl a
  asl a
  asl a
  mov y,a
  call !VoiceReg
  or a,#4
  mov $F2,a
  mov a,!INSTR+y
  mov $F3,a           ; SRCN
  inc $F2
  mov a,!INSTR+1+y
  mov $F3,a           ; ADSR1
  inc $F2
  mov a,!INSTR+2+y
  mov $F3,a           ; ADSR2
  ; noise on or off for this voice
  call !ChanBit
  mov tmp2,a
  mov a,!INSTR+4+y
  beq @tone
  mov a,noisebits
  or a,tmp2
  bra @setn
@tone:
  mov a,tmp2
  eor a,#$FF
  and a,noisebits
@setn:
  mov noisebits,a
  DSPW NON
  ; fall through: volume

; Writes the channel's volume (halved twice while a voice clip plays).
SetVolume:
  mov a,ch_inst+x
  asl a
  asl a
  asl a
  mov y,a
  mov a,!INSTR+3+y
  mov tmp2,a
  mov a,duck
  beq @full
  cmp x,#8
  bcs @full
  mov a,tmp2
  lsr a
  lsr a
  mov tmp2,a
@full:
  call !VoiceReg
  mov $F2,a
  mov a,tmp2
  mov $F3,a
  inc $F2
  mov $F3,a
  ret

; Re-applies the music channels' volumes after ducking changes.
Reduck:
  mov x,#0
@l:
  call !SetVolume
  inc x
  inc x
  cmp x,#8
  bne @l
  ret

Bits:     .db $01, $02, $04, $08, $10, $20, $40, $80
FirTable: .db $50, $20, $10, $08, $00, $00, $00, $00
