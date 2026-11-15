YACHT for the Nintendo 64
=========================

The SNES YACHT v1.1 (../../snes/yacht), rebuilt for the N64: the same rules,
Skipper, voice lines and tunes, with real 3D dice tumbling on the felt,
full-colour art and Rumble Pak support. Version 1.0 (shown on the title).

Rules: the SNES's. Small Straight is any four in a row (30), Large Straight
five in a row (40); no upper bonus.

Playing
-------
Copy build/yacht.z64 to the flash cart's SD card and pick it from the menu.
It saves the best score and sound setting to EEPROM 4K; the ROM header says
so, but if the cart asks for a save type, choose EEPROM 4K (4 Kbit).

  Title     Up/Down choose, A or Start picks. "SOUND: ON/OFF" toggles sound.
            Leave it alone for 20 seconds and the Skipper plays a demo game.
  Dice      A makes the first roll. Then Left/Right pick a die, A holds or
            releases it, Z (or R) rolls again (three rolls a turn).
            Down moves to the scorecard.
  Card      Up/Down pick a box (red numbers show what it would score),
            A scores it, B goes back to the dice while rolls remain.
  Your turn Start pauses: A turns the sound on/off, B quits to the title,
            Start carries on.
  Demo      Any button returns to the title.

The D-pad, the C buttons and the analog stick all move the cursors.

Two players: player 1 uses controller 1, player 2 controller 2. With only
controller 1 plugged in, it plays both turns. A Rumble Pak buzzes as your dice
land, and longer for a Yacht.

Self test: hold L and R while switching on. It runs the SNES's 23 checks and
should say "0 FAILED".

Building
--------
From Git Bash on Windows, with Node, WSL Ubuntu holding libdragon (the
toolchain .deb from the libdragon releases in /opt/libdragon, and libdragon's
preview branch built and installed), and ares v148 for the emulator test
(/c/tools/ares/ares-v148, or set ARES_DIR).

  ./build.sh         builds build/yacht.z64
  ./build.sh test    also runs the native tests and the emulator test

The tests:
  tests/native/      the game logic (src/core) compiled for the PC: scoring,
                     the self test, 3000 Skipper decisions against a reference,
                     the controls, pause, best score, two controllers, and five
                     demo games that must match the boards the SNES ROM plays
                     from the same seeds
  tests/emu.sh       runs the AUTOTEST build in ares: self test, a seeded demo
                     (its board must match the SNES's), a few human moves;
                     screenshots of each screen go to build/shots/

Everything the game shows or plays is made by scripts in tools/: the art is
drawn in code (tools/art/*.js, previews in build/preview), the music is read
from the Tandy source through the SNES port's tools/tunes.js and played by a
small synth (tools/audio.js), and the voice is the SNES's list of phrases
rendered with Windows speech (tools/speech.sh, tools/voice.js).

Files
-----
  src/core/         the game: rules, Skipper, the title/turn/score state machine
                    (plain C, no libdragon; it runs in the native tests too)
  src/main.c        power-on and the main loop     src/screens.c  every screen
  src/dice3d.c      the 3D dice and their tumble   src/gfx.c      text, art
  src/audio.c       music, effects and voice       src/input.c    pads, rumble
  src/save.c        EEPROM save                    src/autotest.c emulator test
