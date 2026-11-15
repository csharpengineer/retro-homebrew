-- Any button leaves the demo (and the attract-mode demo) back to the title.
function test()
  set_limit(20000)
  start_game(2)
  wait(400)                                  -- well into the Skipper's turns
  check(v8("in_game") == 1, "demo ended on its own too soon")
  press(1, { "b" }, 2)
  wait_until(function() return v8("in_game") == 0 end, 240, "a button to leave the demo")
  wait_until(function() return v8("title_choice") == 0xFF end, 120, "the title after leaving the demo")
end
