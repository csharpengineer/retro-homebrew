#!/bin/sh
# Builds build/yacht.z64. Run from Git Bash on Windows: the art and sound are
# made by Node scripts (tools/), the voice by Windows speech, and the ROM by
# libdragon inside WSL (distro $WSL_DISTRO, default Ubuntu; libdragon at
# $N64_INST, default /opt/libdragon).
#   ./build.sh        the ROM
#   ./build.sh test   also the native tests, the autotest ROM and the emulator test
cd "$(dirname "$0")" || exit 1
DISTRO="${WSL_DISTRO:-Ubuntu}"
N64="${N64_INST:-/opt/libdragon}"
HERE=$(pwd -W 2>/dev/null || pwd)
wslrun() { wsl.exe -d "$DISTRO" --cd "$HERE" -- bash -lc "export N64_INST=$N64; $1"; }

for s in art/font art/dice art/game art/title audio; do node tools/$s.js || exit 1; done
# the voice is rendered once, and again only when the phrases change
mkdir -p build/speech
node tools/voice.js --lines > build/speech/want.txt || exit 1
if ! cmp -s build/speech/want.txt build/speech/rendered.txt; then sh tools/speech.sh || exit 1; fi
node tools/voice.js || exit 1
# drop converted files whose source asset is gone, so the ROM never carries them
for f in build/fs/*; do
  [ -e "$f" ] || continue
  b=$(basename "$f"); b=${b%.*}
  [ -e "build/assets/$b.png" ] || [ -e "build/assets/$b.wav" ] || rm -f "$f"
done

wslrun "make -j8 && mv yacht.z64 build/" || exit 1
echo "built build/yacht.z64"

if [ "$1" = test ]; then
  wslrun "sh tests/native/run.sh" || exit 1
  wslrun "make -j8 AUTOTEST=1 && mv yacht_test.z64 build/" || exit 1
  sh tests/emu.sh || exit 1
fi
