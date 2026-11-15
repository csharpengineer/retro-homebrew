-- The demo game plays itself to the end and never touches the best score.
function test()
  set_limit(40000)
  start_game(2)
  check(v8("game_mode") == 2, "menu line 2 should be the demo")
  wait_until(function() return v8("game_state") == 2 end, 30000, "the demo game to finish")
  check(board_full(), "demo ended with empty boxes")
  check(v16("best") == 0, "the demo changed the best score to " .. v16("best"))
  wait_until(function() return v8("title_choice") == 0xFF end, 900, "the demo to return to the title")
end
