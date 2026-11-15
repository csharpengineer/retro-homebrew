# YACHT for the Super Nintendo — design

> **Since v1.1:** the straights are Small (any four in a row, 30) and Large (five in a row, 40), not Yacht's Little/Big; X rolls and A holds; "Four alike!" is spoken. See `snes/yacht/README.txt`.

> Layout note: written when this work lived in a Tandy repo as `yacht/` and `snes/`. In this repo those are `tandy1000/yacht/` and `snes/yacht/`.

Date: 2026-11-14
Branch: `snes-yacht`
Source game: `yacht/` (Tandy 1000 SL version, 8086 assembly, NASM)

## Intent

Port the Tandy 1000 YACHT game to the Super Nintendo as a real cartridge ROM
(`.sfc`) that runs on the owner's flash cart, a Super EverDrive V2 clone
(OS v6, CPLD v20, NTSC console). It should play like the Tandy version.

The owner's words: keep it close to the Tandy version, but improve the
resolution. Full artistic license. "I'd love to be surprised." So the bar is
not a faithful screen-for-screen copy: it's the same game, presented as a
polished SNES game would be. Showing off what the SNES can do that the Tandy
couldn't is part of the point.

On "resolution": the SNES's usual mode is 256×224, which is fewer pixels across
than the Tandy's 320×200. The improvement comes from color and detail: 256
colors on screen chosen from 32,768 instead of 16 fixed colors, shaded and
antialiased art, smooth sprite animation, and per-scanline effects. Hi-res
512-pixel mode was considered and rejected (see Approaches).

## Goals

- **Same game.** Same rules and scoring as `yacht/src/yacht.asm` `score_cat`:
  - Ones through Sixes score the face times how many dice show it.
  - Full House scores the sum of the dice, but only for an exact 3+2. Five
    of a kind doesn't count.
  - Four of a Kind scores 4 × the face, if at least four dice match. Five
    of a kind counts.
  - Little Straight (1-2-3-4-5) and Big Straight (2-3-4-5-6) score 30.
  - Choice scores the sum of the dice.
  - Yacht (five of a kind) scores 50.
  - There's no upper-section bonus, and the total is the sum of all 12 boxes.
- **Turn structure:** three rolls per turn, with dice held between rolls.
- **Same modes:** play the Skipper (computer), two players, and a demo game
  (computer against computer).
- **Same Skipper:** port the computer opponent's hold and pick logic from
  `yacht/src/game.asm` (`ai_turn` through `ai_holds`, and the `ai_expect`
  table in `data.asm`) so it makes the same decisions on the same dice.
- **Same voice lines:** the ten phrases in `yacht/tools/speech.txt`, spoken
  at the same moments as in the Tandy version.
- **Same music cues:** title tune, win, lose, "good roll". Their melodies come
  from `data.asm` (`tune_title`, `tune_win`, `tune_lose`, `tune_good`). They
  can be re-arranged with richer instruments.
- **Best score:** kept across power-offs in battery-backed cartridge save
  RAM. The owner's cart copies that to the SD card, under `SPED\SAVE`.
- **Sound on/off toggle,** like the Tandy's M key.
- **A scoring self-test,** the equivalent of `YACHT /T`. It must run
  automatically in an emulator, and anyone must be able to reach it on real
  hardware.
- **Looks beautiful.** Polished, shaded pixel art in the nautical theme the
  Tandy version set: sky, sun, clouds, sea and a boat on the title. The game
  screen should feel like a game table.

### Behaviour fixed by the Tandy source (port exactly)
- **Skipper:** on a tie between boxes, the Skipper takes the first one.
- **Best score:** counts human scores only.
  - Against the Skipper, it's the human's total.
  - With two players, it's the higher of the two totals.
  - The demo game never counts.
- **Sound:**
  - A zero score plays `tune_bad`.
  - Sound off also silences the voice.
  - "Straight!" is spoken only when the box scores more than zero.
- **Holding:** you can't hold a die before the first roll of a turn, or
  after the last.

## Non-goals

- PAL consoles. It should not crash on one, but it's only tuned for NTSC timing.
- More than two human players, or networking.
- Anything Tandy- or DOS-specific: the floppy image, the `.SPK` file, DeskMate.
- Changing the rules, or adding variants such as an upper bonus or Yahtzee
  rules.
- Mouse or Super Scope support.

## Anti-goals (would count as failure even if it technically runs)

- Scores that differ from the Tandy version on the same dice.
- Programmer art: flat colors, uneven fonts, cramped or misaligned layout.
- Crackly, clipped or muffled voice, or music that drowns it out.
- Any slowdown, flicker, or garbage on screen during transitions.
- Working in the emulator but failing on the real cart. Concretely, it must
  not depend on:
  - uninitialized RAM or VRAM;
  - emulator-only timing;
  - a save RAM size or map mode the Super EverDrive doesn't support;
  - a bad header checksum.

## Constraints

- **Hardware:** NTSC SNES with a Super EverDrive V2 clone. The clone writes
  the game to flash when it's loaded, which doesn't matter for the game
  itself.
- **Cartridge format:**
  - LoROM, map mode `$20`, plain (not FastROM).
  - Cartridge type `$02` (ROM + save RAM + battery), save RAM size code `$01`
    (2 KB).
  - ROM size 256 KB or 512 KB, whichever fits.
  - Correct internal header and checksum, and no 512-byte copier header.
- **Audio RAM is 64 KB.** The voice clips at a decent sample rate total more
  than that, so they can't all live in audio RAM at once (see Audio).
- **No paid or proprietary tools.** The repo already builds with NASM, Node
  scripts and a `build.sh`, and the SNES build follows that pattern.
- **Testing:** in an emulator that can be scripted headless, to press
  buttons, read RAM and take screenshots. The owner offered to let us
  download one. Final check on the owner's real hardware.

## Approaches

1. **Hand-written assembly with WLA-DX (chosen).**
   - 65816 code for the game and SPC700 code for a small custom sound
     driver, both assembled by the same toolchain (`wla-65816`, `wla-spc700`,
     `wlalink`).
   - Node scripts generate the art, the palettes and the sound samples.
   - It mirrors how the Tandy version was made: direct hardware, no
     libraries. It gives full control over the per-scanline effects and over
     streaming the voice clips.
   - It needs one toolchain download.
   - Trade-off: the most code to write, and every bug is ours.
2. **C with PVSnesLib.**
   - The game logic would be quicker to write.
   - But its sound driver plays Impulse Tracker modules. That means writing
     music in a tracker format, and it fits the voice clips poorly.
   - Its compiled code is slow, which is fine for a dice game, and it gives
     less control over the effects.
3. **ca65 assembler with Terrific Audio Driver.**
   - Excellent music and sound-effect tooling.
   - But more dependencies, and voice clips longer than audio RAM would need
     working around the driver.

The owner handed the how to us. We chose 1 for control over sound and effects,
the fewest dependencies, and continuity with the Tandy version.

**Hi-res (512 px) considered and rejected.**
- Sprites can't use it, so the dice wouldn't benefit.
- Each tile layer gets fewer colors.
- It blurs on composite video, which is a likely connection for the owner.
- It would complicate everything for little gain.

## How it's built (decided)

### Layout in the repo
- `snes/`, a sibling of `yacht/`, with `src/` (65816 and SPC700 sources),
  `tools/` (Node asset generators and converters), `build.sh`, and `build/`
  (gitignored).
- The output is `snes/build/yacht.sfc`.
- Node scripts use only Node's built-in modules (`zlib` for PNG), matching
  `yacht/tools/`. No npm dependencies.

### Graphics
- **Video mode:** Mode 1, with two 16-color tile layers and one 4-color text
  layer.
- **Sprites:** the dice, cursor, hold markers, boat, birds and so on.
- **Per-scanline color and scroll effects (HDMA):**
  - a sky gradient on the title;
  - sea bands that scroll at different speeds for depth;
  - color cycling for shimmer, which is the Tandy's palette cycling,
    upgraded.
- **All art is generated by Node scripts in `snes/tools/`, drawn in code**,
  not hand-made files. That keeps it reproducible from the repo.
  - The scripts write SNES tile, palette and tilemap data, plus PNG previews
    of every screen and sprite sheet. We use the previews to judge the art.
- **Fonts:** a clean custom 8×8 font for status text, and a larger font for
  headings and numbers.
- **Dice:** rendered with shading, rounded corners and pips with depth.
  - A short tumble animation per roll: rotation frames, a bounce, then
    settling.
  - Held dice are clearly marked.
- **Screens:**
  1. Title and menu: a sea scene and the YACHT logo, with play the Skipper,
     two players, and demo.
  2. Game: a scorecard on one side with both players' columns, a dice tray
     on the other, and a status line.
  3. End of game: the result and the best score.
- **Attract mode:** if the title screen sits idle, the demo game starts by
  itself, like a real arcade or console title. Any button returns to the
  title. This is a small addition the Tandy didn't have. Our call.

### Controls
| Button | Action |
|---|---|
| A | roll (or confirm on menu / score the selected box) |
| B | back / cancel |
| Y | toggle hold on the die under a die cursor |
| Left / Right | move the die cursor |
| Up / Down | move the scorecard cursor |
| L / R | quick-hold buttons — builder's call on exact mapping |
| Select | sound on/off |
| Start | pause (or start from title) |

- **A has two jobs: rolling and scoring.** A cursor focus settles which:
  - Focus is on the dice tray while rolls remain, and A rolls.
  - Up/Down moves focus to the scorecard, where A scores the selected box.
  - After the third roll, focus starts on the scorecard.
- In two-player mode, player 1 uses controller 1 and player 2 uses
  controller 2.
- If controller 2 isn't plugged in, controller 1 plays both turns. The
  Tandy version shared one keyboard.
- The exact mapping can change during building if a better one appears,
  but A rolls and Up/Down plus A scores a box. Those match the Tandy's Space,
  arrows and Enter.

### Audio
- **A small custom SPC700 driver** (our own), which:
  - plays music from note sequences on a few channels;
  - plays sound effects on their own channels: dice rattle, hold click,
    cursor tick, score chime, Yacht fanfare;
  - plays one voice clip at a time.
- **Instruments** are short looped samples generated by a Node script.
  Builder's call on which instruments; a warm, slightly tropical set fits
  the sea theme.
- **Voice:**
  - Re-render the ten phrases with Windows SAPI, the same voice as the
    Tandy version (Microsoft David), but at a higher sample rate and 16-bit.
  - Convert to the SNES sound format (BRR) at about 12 kHz. The exact rate
    is the builder's call: as high as the quality and space trade-off
    allows.
  - Clips are uploaded to audio RAM on demand, into a reserved buffer, just
    before they play.
  - Sizing: the ten clips run about 16 seconds in total, roughly 108 KB at
    12 kHz. The longest is about 2 seconds, around 13 KB, so a buffer of
    about 16 KB fits any one clip.
  - The game hides the short upload behind moments that already pause, such
    as the dice settling or the score being chosen. The music ducks while a
    clip plays.
- The BRR encoder is our own Node script.

### Save
- 2 KB of battery save RAM holds:
  - a signature,
  - the best score,
  - the sound on/off setting,
  - a checksum.
- If the signature or checksum is bad, it's reset to defaults.

### Self-test
- Holding L+R while the game boots starts a self-test screen instead of the
  title.
- It runs the 22 checks ported from `yacht/src/game.asm` `selftest`: 16
  scoring cases, plus 6 random-number checks re-targeted at our own
  generator. Then it shows the number run and any failures on screen.
- It also writes a pass/fail result to a fixed RAM address for the emulator
  test script.

### Testing
- **Emulator:** Mesen 2, driven headless by Lua test scripts.
- **Automated checks:**
  - the self-test passes;
  - a scripted game, with fixed button presses and a fixed random seed,
    reaches the end with the expected total;
  - the demo game finishes;
  - the save survives a reset.
- **Screenshots:** of the title, the game and the end screen, reviewed by
  eye for polish.
- **Last step:** the owner plays it on the real cart.

### Toolchain downloads (needs the owner's OK)
- WLA-DX, the Windows release from GitHub (`vhelin/wla-dx`).
- Mesen 2, the Windows release from GitHub (`SourMesen/Mesen2`). The .NET 8
  Desktop runtime it needs is already installed, so nothing system-wide gets
  added.
- Both are installed under a tools folder outside the repo.

## Left to the builder

- Exact art, colors, animation timing and layout, within the theme and the
  anti-goals. The owner wants to be surprised.
- Music arrangement and instrument choice.
- Voice sample rate and the audio RAM budget.
- Exact pacing of the Skipper's turns, which should be readable rather than
  instant.
- Random number source, seeded from frame count and input timing.
- Code structure and file split.
