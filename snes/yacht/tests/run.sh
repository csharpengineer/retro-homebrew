#!/bin/sh
# Runs Lua tests in Mesen's headless test runner against build/yacht.sfc.
# Usage: tests/run.sh            all tests
#        tests/run.sh boot title  named tests
cd "$(dirname "$0")/.." || exit 1
MESEN_DIR="${MESEN_DIR:-$HOME/tools/mesen2}"   # portable Mesen 2.1.1
MESEN="$MESEN_DIR/Mesen.exe"
ROOT=$(cd . && pwd -W 2>/dev/null || pwd)
OUT="$ROOT/build"
mkdir -p build/shots build/results build/lua
[ -f build/yacht.sfc ] || { echo "FAIL: build/yacht.sfc missing"; exit 1; }
if [ $# -eq 0 ]; then set -- $(ls tests/*.lua | grep -vE "lib.lua|/yacht_" | sed 's#tests/##; s#\.lua$##'); fi
fails=0
for t in "$@"; do
  f=build/lua/$t.lua
  {
    echo "TEST_NAME = \"$t\""
    echo "TEST_OUT = \"$OUT/\""
    echo "ADDR = {}"
    # Code labels look like "00:8000 Reset"; exported RAM variables like "0000000a frame".
    grep -E '^[0-9a-fA-F]{2}:[0-9a-fA-F]{4} [A-Za-z_][A-Za-z0-9_]*$' build/yacht.sym |
      awk '{ split($1,a,":"); printf "ADDR[\"%s\"] = 0x%s%s\n", $2, a[1], a[2] }'
    grep -E '^[0-9a-fA-F]{8} [A-Za-z][A-Za-z0-9_]*$' build/yacht.sym |
      awk '{ printf "ADDR[\"%s\"] = 0x%s\n", $2, $1 }'
    cat tests/lib.lua tests/yacht_ref.lua tests/yacht_game.lua tests/$t.lua
    echo "start_test()"
  } > "$f"
  rm -f build/results/$t.txt
  # Random power-on RAM and state, so nothing can lean on leftover memory.
  # Controller 2 is unplugged unless the test starts with "-- port2: pad".
  P2=None
  head -1 tests/$t.lua | grep -q '^-- port2: pad' && P2=SnesController
  node -e '
const fs=require("fs"),p=process.argv[1];const s=JSON.parse(fs.readFileSync(p,"utf8").replace(/^﻿/,""));
s.Snes.RamPowerOnState="Random";s.Snes.EnableRandomPowerOnState=true;s.Snes.Port2.Type=process.argv[2];
s.Debug.ScriptWindow.AllowIoOsAccess=true;
fs.writeFileSync(p,JSON.stringify(s,null,2));' "$MESEN_DIR/settings.json" "$P2" || exit 1
  # every test starts with a fresh cart: no battery save left by an earlier test
  rm -f "$MESEN_DIR/Saves/yacht.srm"
  timeout 300 "$MESEN" --testrunner build/yacht.sfc "$f" > build/results/$t.log 2>&1
  rc=$?
  if [ $rc -eq 0 ]; then echo "PASS $t"; else
    echo "FAIL $t (exit $rc) $(cat build/results/$t.txt 2>/dev/null)"; fails=$((fails+1)); fi
done
node tools/raw2png.js build/shots
[ $fails -eq 0 ] || { echo "$fails failed"; exit 1; }
