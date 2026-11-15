-- Two players with only controller 1 plugged in: controller 1 plays both turns.
function test()
  set_limit(120000)
  start_game(1)
  check(v8("game_mode") == 0, "menu line 1 should be two players, got mode " .. v8("game_mode"))
  local turns = { [0] = 0, [1] = 0 }
  while true do
    if wait_human() == 2 then break end
    local _, _, _, player = human_turn(1)
    turns[player] = turns[player] + 1
  end
  check(turns[0] == 12 and turns[1] == 12, "turns " .. turns[0] .. "/" .. turns[1] .. ", want 12/12")
  check(board_full(), "game over with empty boxes")
  local hi = math.max(total(0), total(1))
  check(v16("best") == hi, "best " .. v16("best") .. ", want the higher total " .. hi)
end
