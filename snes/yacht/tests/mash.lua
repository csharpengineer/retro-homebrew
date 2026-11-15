-- Mashing buttons while the Skipper plays never makes extra rolls or breaks the turn.
-- Also: scoring a zero (Yacht on the first roll) plays the "bad" tune.
function test()
  set_limit(60000)
  start_game(0)
  wait_human()
  -- turn 1: one roll, then Up from the first box wraps to Yacht
  local cat, d, got = human_turn(1, 1)
  check(cat == 11, "Up from Ones should wrap to Yacht, cursor was " .. cat)
  check(got == ref_score(d, 11), "Yacht scored " .. got)
  check(got == 0, "with seed $1234 the first roll is not a Yacht, so this scores 0 (got " .. got .. ")")
  wait(2)
  check(v8("last_tune") == 2, "a zero score should play the bad tune, last tune " .. v8("last_tune"))
  -- the Skipper's turn: mash A, B, Y every other frame
  wait_until(function() return v8("cur") == 1 end, 300, "the Skipper's turn")
  local last = v8("rolls_left")
  local n = 0
  while v8("cur") == 1 and n < 3000 do
    if n % 2 == 0 then hold(1, { "a", "b", "y" }) else release(1) end
    wait(1)
    local r = v8("rolls_left")
    check(r <= 3, "rolls_left = " .. r)
    check(not (r < last and last - r > 1), "rolls_left jumped from " .. last .. " to " .. r)
    check(v8("paused") == 0, "pausing during the Skipper's turn")
    last = r
    n = n + 1
  end
  release(1)
  check(v8("cur") == 0, "the Skipper's turn never ended")
  check(score_of(1, 0) ~= EMPTY or total(1) >= 0, "Skipper scored nothing")
  local filled = 0
  for c = 0, 11 do if score_of(1, c) ~= EMPTY then filled = filled + 1 end end
  check(filled == 1, "the Skipper filled " .. filled .. " boxes in one turn")
end
