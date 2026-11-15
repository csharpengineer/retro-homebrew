#!/bin/sh
# Builds the game and its floppy image. Run tools/make_speech.sh first to
# render the speech clips.
cd "$(dirname "$0")" || exit 1
NASM="${NASM:-/c/msys64/ucrt64/bin/nasm.exe}"
mkdir -p build
node tools/gen_notes.js || exit 1
node tools/mkspk.js || exit 1
"$NASM" -f bin -I src/ -o build/YACHT.COM src/yacht.asm || exit 1
"$NASM" -f bin -o build/boot.bin tools/boot.asm || exit 1
node tools/mkdisk.js || exit 1
ls -l build/YACHT.COM build/YACHT.SPK build/YACHT.DSK
