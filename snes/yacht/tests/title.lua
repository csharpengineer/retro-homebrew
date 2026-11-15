-- The title screen: menu choice by controller, and the demo starts by itself when idle.
-- title_choice is $FF while the title is up, then the chosen game_mode
-- (0 two players, 1 vs Skipper, 2 demo).
function test()
  wait_until(function() return v8("title_choice") == 0xFF end, 120, "title screen")
  wait(150)
  shot("title")
  check(v8("title_choice") == 0xFF, "title ended without input")
  press(1, { "down" }, 3)
  press(1, { "a" }, 3)
  wait_until(function() return v8("title_choice") ~= 0xFF end, 120, "the menu to take the choice")
  check(v8("title_choice") == 0, "Down then A chose mode " .. v8("title_choice") .. ", want 0 (two players)")

  emu.reset()
  wait(10)
  wait_until(function() return v8("title_choice") == 0xFF end, 120, "title screen after reset")
  wait(600)
  check(v8("title_choice") == 0xFF, "demo started before 20 seconds")
  wait_until(function() return v8("title_choice") == 2 end, 900, "the demo to start after 20 s idle")
end
