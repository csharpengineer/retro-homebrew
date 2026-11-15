# YACHT for the Nintendo 64 — design

Date: 2026-11-15
Branch: `n64-yacht`
Source game: `snes/yacht` v1.1 (itself a port of `tandy1000/yacht`)

## Intent

The owner asked: "surprise me with a Nintendo 64 port of Yacht", for an N64
flash cart that is on its way. They handed over every decision, as they did
for the SNES port. So: the same game as SNES v1.1, rebuilt to show off what the
N64 does that the SNES couldn't. That means real 3D dice tumbling on a felt
table, full-colour art, CD-quality voice, and Rumble Pak support.

## Goals

- **Same game as SNES v1.1.** Rules, Skipper, turn flow, voice and tune cues,
  best-score rules and pacing match `snes/yacht`.
  - The full behaviour list was taken from the SNES sources. It covers the
    title menu, buttons per state, the status texts, Skipper delays, each
    sound cue and its condition, pause, game over and the self-test cases.
    It is the reference for the plan.
  - Scoring:
    - Ones to Sixes score face × count.
    - Full House: an exact 3+2 scores the sum.
    - Four Alike: 4 × the face when four or more match.
    - Small Straight: any four in a row, 30.
    - Large Straight: five in a row, 40.
    - Choice: the sum.
    - Yacht: 50.
  - The Skipper uses the same satisfied, pick and hold logic as `snes/yacht/src/skipper.s`.
  - The RNG is the same: seed·25173+13849 mod 65536, and Roll1 = ((r·6)>>16)+1.
  - There are six draws per unheld die per roll, the last one kept. So the
    same seed gives the same game as on the SNES.
- **Modes**: play the Skipper, two players and a watchable demo. The title
  starts the demo by itself after 20 seconds idle.
- **Best score and sound setting** are saved in cartridge EEPROM (4 Kbit).
- **Self-test**: hold L+R at power-on. It runs the same 23 checks and shows
  "N CHECKS RUN / N FAILED".
- **Looks beautiful**, using the same nautical theme:
  - **Title**: sunset sky, layered scrolling sea, a bobbing boat, the YACHT
    logo, and the menu on a dark panel.
  - **Game**: a captain's table, with a scorecard on the left and five real
    3D dice on green felt on the right.
    - The dice are lit and textured, and tumble with a bounce before they
      settle on their faces.
    - Held dice lift and glow.
- **N64 extras**:
  - The Rumble Pak buzzes as the dice land, and longer on a Yacht.
  - The analog stick works as well as the D-pad.
  - Sound on/off moves into the title menu and the pause menu, since the
    N64 has no Select button.

## Non-goals

- Expansion Pak features: the game must run on 4 MB.
- More than two human players, even though the N64 has four ports.
- Changing the rules.

## Anti-goals (count as failure even if it runs)

- Scores or Skipper choices that differ from SNES v1.1 on the same dice.
- Slowdown, tearing or garbage between screens.
- Working in the emulator but failing on the real cart. It must not depend on:
  - uninitialised memory;
  - an emulator-only save type;
  - an Expansion Pak;
  - a bad ROM header.
- Muffled or clipped voice, or music that drowns it out.

## Approaches

1. **C with libdragon (chosen).** This is the standard open-source N64 SDK.
   - It provides the RDP command queue (rdpq), an audio mixer with
     compressed samples, joypad, Rumble and EEPROM, and asset converters
     (mksprite, audioconv64).
   - The game logic is plain C that also compiles on a PC, so it can be unit
     tested in WSL with gcc.
2. **libultra (Nintendo's SDK).** It's proprietary and can't be redistributed.
   Rejected.
3. **Hand-written MIPS assembly** like the SNES port. It would be enormous
   for 3D and audio, for no gain. Rejected.

## How it's built (decided)

- **Layout**: `n64/yacht/`
  - `build.sh` runs the Node asset steps on Windows, then `make` in WSL
    Ubuntu, and writes `build/yacht.z64`.
  - `src/core/`: pure C, no libdragon. It holds rules, RNG, the Skipper, and
    the game state machine driven by abstract input.
  - `src/`: the N64 side, covering video, 3D dice, text, audio, input, save
    and screens.
  - `tools/`: Node scripts with no npm dependencies, as in the other ports.
  - `tests/`: native C unit tests plus an emulator check.
- **Video**:
  - 320×240 at 16-bit colour, triple-buffered, with the VI's antialias
    filter on.
  - Hi-res 640×480 was rejected, because frame and Z buffers would eat
    about 2.5 MB of the 4 MB.
- **Dice**:
  - Our own small 3D transform on the CPU (5 cubes, 60 triangles).
  - They're drawn with rdpq triangles: textured pip faces, a Z-buffer, and
    per-face lighting through the shade colour.
  - The tumble animation spins each die along a random axis, then settles
    on the rotation that shows the rolled face.
  - Soft blob shadows sit on the felt.
- **Art**: drawn in code by Node scripts and written as PNGs, then converted
  by mksprite. That covers backgrounds, panels, the logo, the boat, sea
  layers, die face textures and the font atlas.
- **Text**: a bitmap font atlas drawn by a Node script, based on the SNES
  font. Each glyph is blitted as a textured rectangle with a colour tint.
- **Audio**: libdragon mixer.
  - **Music**: the tunes are read from the Tandy `data.asm`, the same way
    the SNES `tools/tunes.js` does it.
    - A Node synth plays them offline to WAV, with the same instrument
      ideas (steel drum, bass, pluck, shaker).
    - audioconv64 converts the WAVs to compressed wav64.
  - **Voice**: the SAPI phrases from the SNES speech pipeline (with the
    "Four alike!" override), at 22 kHz.
  - **SFX**: tick, select, roll rattle and hold, synthesized.
- **Controls**:

  | Where | A | B | Z / R | Start | D-pad / stick |
  |---|---|---|---|---|---|
  | Title | choose | — | — | choose | Up/Down menu |
  | Dice | first roll, then hold/release | — | roll | pause | Left/Right pick die, Down to card |
  | Card | score box | back to dice (rolls left) | — | pause | Up/Down pick box |
  | Pause | — | quit to title | — | resume | Up/Down: "SOUND ON/OFF" with A |

  Two players: player 1 on port 1 and player 2 on port 2. If port 2 is
  empty, port 1 plays both turns.
- **Save**: 4 Kbit EEPROM, holding "YCHT", the best score, the sound setting
  and a checksum. It falls back to defaults if the save is bad. The ROM
  header declares EEPROM 4K so flash carts pick the right save type.
- **Testing**:
  - **Native**, run in WSL:
    - every scoring case;
    - the Skipper against an independent reference, on 3000 random cases
      plus fixed ones;
    - the RNG and self-test numbers;
    - full scripted games through the state machine with a fixed seed.
  - **Emulator**: ares (v148) with ISViewer logging on.
    - An autotest build runs the self-test and a seeded demo game, then
      prints the results.
    - The test script launches ares, reads the log and checks it.
    - Screenshots of the title, game and game over are reviewed by eye.
  - **Last step**: the owner plays it on the real cart.

## Left to the builder

The art, colours, animation timing within the SNES pacing, the music
arrangement, and the exact file split.
