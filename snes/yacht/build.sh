#!/bin/sh
# Builds build/yacht.sfc. Needs WLA-DX and Node.
cd "$(dirname "$0")" || exit 1
W="${WLA_DX:-$HOME/tools/wla-dx/wla_dx_v10.7_Win64}"   # WLA-DX v10.7
mkdir -p build/gfx build/preview
for f in tools/art/*.js; do node "$f" || exit 1; done
# sound: driver, then the sound RAM image, then the voice clips
mkdir -p build/spc
"$W/wla-spc700.exe" -o build/spc/driver.o src/spc/driver.s || exit 1
printf '[objects]
build/spc/driver.o
' > build/spc/link.txt
"$W/wlalink.exe" -b build/spc/link.txt build/spc/driver.bin || exit 1
node tools/spcimage.js || exit 1
[ -f build/speech/welcome.wav ] || tools/speech.sh || exit 1
node tools/voice.js > build/voice.log || exit 1
"$W/wla-65816.exe" -I src -o build/main.o src/main.s || exit 1
"$W/wlalink.exe" -S -v link.txt build/yacht.sfc > build/link.log || { cat build/link.log; exit 1; }
node tools/checkrom.js build/yacht.sfc || exit 1
