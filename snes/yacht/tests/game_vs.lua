-- A whole game against the Skipper: every human score matches the rules,
-- the card fills, and the best score becomes the human's total.
function test()
  set_limit(120000)
  start_game(0)
  check(v8("game_mode") == 1, "menu line 0 should be the Skipper, got mode " .. v8("game_mode"))
  wait_human()
  -- box names leave a blank column before the first score column
  for c = 0, 11 do
    local row = bg3_row(3 + 2 * c)
    check(row:sub(12, 12) == " ", "box " .. c .. " name runs into the scores: '" .. row:sub(2, 14) .. "'")
  end
  local turns = 0
  while true do
    local s = wait_human()
    if s == 2 then break end
    check(v8("cur") == 0, "a human turn for player " .. v8("cur") .. " in a Skipper game")
    local cat, d, got = human_turn(3, 0, turns == 5 and "game_choose" or nil)
    local want = ref_score(d, cat)
    check(got == want, string.format("box %d scored %d for dice %d%d%d%d%d, want %d", cat, got, d[1], d[2], d[3], d[4], d[5], want))
    turns = turns + 1
    if turns == 6 then wait(20) shot("game_mid") end
  end
  check(turns == 12, "human played " .. turns .. " turns, want 12")
  check(board_full(), "game over with empty boxes")
  -- the result is on screen the moment the game says it's over
  check(screen_has("GAME OVER"), "game over state before the result reached the screen")
  check(v16("best") == total(0), "best is " .. v16("best") .. ", human total is " .. total(0))
  -- mashing A can't skip the result: it stays up at least half a second
  local n = 0
  while v8("in_game") == 1 and n < 600 do
    if n % 2 == 0 then hold(1, { "a" }) else release(1) end
    if n == 10 then shot("game_over") end
    wait(1)
    n = n + 1
  end
  release(1)
  check(n >= 30, "the result screen was skipped after " .. n .. " frames")
  wait_until(function() return v8("title_choice") == 0xFF end, 400, "back to the title")
end
