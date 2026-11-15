#!/bin/sh
# Builds and runs the native tests of the game logic (src/core) with the host
# gcc. Run inside WSL/Linux, or through ../../build.sh test from Git Bash.
cd "$(dirname "$0")" || exit 1
mkdir -p ../../build/native
fails=0
for t in test_*.c; do
  exe=../../build/native/${t%.c}
  gcc -std=c11 -O2 -Wall -Wextra -Werror -o "$exe" "$t" ../../src/core/*.c || { echo "FAIL $t (build)"; fails=$((fails+1)); continue; }
  if "$exe" > "$exe.log" 2>&1; then tail -1 "$exe.log" | sed 's/^/PASS /'; else
    grep FAIL "$exe.log" | head -20; tail -1 "$exe.log" | sed 's/^/FAIL /'; fails=$((fails+1)); fi
done
[ $fails -eq 0 ] || { echo "$fails failed"; exit 1; }
