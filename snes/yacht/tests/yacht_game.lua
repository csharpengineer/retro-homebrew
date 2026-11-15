-- Helpers for driving a game from the title menu (included by run.sh into every test).
-- game_state: 0 waiting for a human, 1 busy (dice tumbling, Skipper, reactions), 2 game over.
EMPTY = 0xFFFF

function score_of(player, cat) return read16(addr("scores") + (player * 12 + cat) * 2) end
function dice_now() local d = {} for i = 1, 5 do d[i] = read8(addr("dice") + i - 1) end return d end

-- From power-on: seed the dice, pick menu line `line` (0 Skipper, 1 two players, 2 demo).
function start_game(line, seed)
  wait_until(function() return v8("title_choice") == 0xFF end, 200, "title screen")
  write16(0x7E1F80, seed or 0x1234)
  wait(30)
  for _ = 1, line do press(1, { "down" }, 3) end
  press(1, { "a" }, 3)
  wait_until(function() return v8("in_game") == 1 end, 300, "the game to start")
end

function wait_human()
  wait_until(function() local s = v8("game_state") return s == 0 or s == 2 end, 4000, "a human turn or game over")
  return v8("game_state")
end

-- A human turn: roll up to `rolls` times, then score the box under the cursor
-- (after `moves` presses of Up). Returns the category, the dice and the score stored.
function human_turn(rolls, moves, shot_name)
  for _ = 1, rolls do
    if v8("rolls_left") == 0 then break end
    press(1, { "a" }, 2)
    wait_human()
  end
  if v8("focus") == 0 then press(1, { "down" }, 2) end     -- move to the scorecard
  for _ = 1, (moves or 0) do press(1, { "up" }, 2) end
  local cat, player = v8("cursor"), v8("cur")
  if shot_name then wait(4) shot(shot_name) end
  local d = dice_now()
  press(1, { "a" }, 2)
  for _ = 1, 120 do
    if score_of(player, cat) ~= EMPTY then return cat, d, score_of(player, cat), player end
    wait(1)
  end
  fail(string.format("box %d of player %d never scored: cur=%d focus=%d cursor=%d state=%d rolls=%d",
    cat, player, v8("cur"), v8("focus"), v8("cursor"), v8("game_state"), v8("rolls_left")))
  return cat, d, score_of(player, cat), player
end

function board_full()
  for p = 0, 1 do for c = 0, 11 do if score_of(p, c) == EMPTY then return false end end end
  return true
end

function total(p)
  local t = 0
  for c = 0, 11 do local s = score_of(p, c) if s ~= EMPTY then t = t + s end end
  return t
end

-- Text on screen: the BG3 tilemap in VRAM (what the player sees, not the shadow).
function bg3_row(row)
  local s = ""
  for col = 0, 31 do
    local a = (0x5800 + row * 32 + col) * 2
    local t = (readmem(a, emu.memType.snesVideoRam) + 256 * readmem(a + 1, emu.memType.snesVideoRam)) & 0x3FF
    s = s .. string.char(t + 32)
  end
  return s
end
function screen_has(text)
  for row = 0, 27 do if bg3_row(row):find(text, 1, true) then return true end end
  return false
end
