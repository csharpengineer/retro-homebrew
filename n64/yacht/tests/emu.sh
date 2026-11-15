#!/bin/sh
# Runs the autotest ROM (make AUTOTEST=1) in ares and checks what it reports:
# the self test, the seeded demo's final board against the SNES's, and that
# the scripted session reaches its end. Screenshots land in build/shots/.
# Needs ares (default /c/tools/ares/ares-v148, or set ARES_DIR). Git Bash.
cd "$(dirname "$0")/.." || exit 1
ARES_DIR="${ARES_DIR:-/c/tools/ares/ares-v148}"
ROM=$(cd . && pwd -W)/build/yacht_test.z64
LOG=build/emu.log
[ -f build/yacht_test.z64 ] || { echo "FAIL: build/yacht_test.z64 missing (build.sh test)"; exit 1; }
rm -f "$LOG"
"$ARES_DIR/ares.exe" --system "Nintendo 64" --setting General/HomebrewMode=true --setting Audio/Mute=true \
  --no-file-prompt "$ROM" > "$LOG" 2>&1 &
pid=$!
for i in $(seq 1 300); do
  grep -q "AUTOTEST DONE" "$LOG" 2>/dev/null && break
  sleep 1
done
kill $pid 2>/dev/null; taskkill //F //IM ares.exe >/dev/null 2>&1
node tools/shots.js "$LOG"
fails=0
check() { if grep -q "$1" "$LOG"; then echo "PASS $2"; else echo "FAIL $2"; fails=$((fails+1)); fi; }
check "^SELFTEST run=23 failed=0" "self test: 23 checks, 0 failed"
# the SNES ROM's demo board for seed 1234 (tests/native/test_game.c GOLDEN)
check "^BOARD 1234 1 4 0 12 0 12 26 20 30 40 24 0 3 6 9 8 0 18 28 8 30 40 23 0$" "demo board matches the SNES"
check "^AUTOTEST DONE" "scripted session finished"
if node tools/pcmcheck.js "$LOG"; then echo "PASS title tune: every instrument on the beat through the loop"; else echo "FAIL title tune timing"; fails=$((fails+1)); fi
[ $fails -eq 0 ] || { echo "$fails failed (log: $LOG)"; exit 1; }
