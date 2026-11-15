YACHT for the Super Nintendo
============================

The Tandy 1000 YACHT game (../../tandy1000/yacht), rebuilt as a SNES cartridge: same rules,
same Skipper, same voice lines and tunes, new art and sound.

Playing
-------
Copy build/yacht.sfc to the flash cart's SD card and pick it from the menu.

  Title     Up/Down choose, A or Start begins. Select turns sound on/off.
            Leave it alone for 20 seconds and the Skipper plays a demo game.
  Dice      A rolls (three rolls a turn). Left/Right (or L/R) pick a die,
            Y holds or releases it. Down moves to the scorecard.
  Card      Up/Down pick a box (red numbers show what it would score),
            A scores it, B goes back to the dice while rolls remain.
  Your turn Start pauses (B in the pause quits to the title).
  Any time  Select turns sound on/off.
  Demo      Any button returns to the title.

Two players: player 1 uses controller 1, player 2 controller 2 (or
controller 1 if there is no second controller).

The best score and the sound setting are kept in the cart's battery save.

Self test: hold L and R while switching on. It runs the same 22 checks as
YACHT /T on the Tandy and should say "0 FAILED".

Building
--------
Needs WLA-DX v10.7 ($HOME/tools/wla-dx, or set WLA_DX), Mesen 2 for the tests
($HOME/tools/mesen2, or set MESEN_DIR), Node, and Windows (the voice
clips are rendered with Windows speech the first time).

  ./build.sh              builds build/yacht.sfc
  node --test tools/test  checks the graphics and sample converters
  tests/run.sh            runs every emulator test in Mesen 2 (headless)
  tests/run.sh title      runs one

Everything the game shows or plays is made by the scripts in tools/: the art
is drawn in code (tools/art/*.js, with previews in build/preview), the music
is read straight from the Tandy source, the instruments are synthesized.

Files
-----
  src/main.s        power-on, main loop          src/game.s     game screen and turns
  src/title.s       title screen and menu        src/rules.s    scoring, dice
  src/skipper.s     the computer opponent        src/save.s     battery save
  src/audio.s       talks to the sound driver    src/spc/       the SPC700 sound driver
  src/selftest.s    the L+R self test            tests/         Mesen test scripts
