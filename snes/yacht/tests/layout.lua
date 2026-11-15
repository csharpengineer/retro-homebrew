-- Things fit where they are drawn: the title menu inside its dark panel, a
-- version number on the title, the dice centered in the felt tray, the player
-- names over their score columns, and the roll counters inside their plaque.
local function span(row)            -- first and last non-blank text column, 0-based
  local s = bg3_row(row)
  local a, b = s:find("%S"), nil
  if not a then return nil end
  for i = #s, 1, -1 do if s:sub(i, i) ~= " " then b = i break end end
  return a - 1, b - 1
end

-- Visible small (16x16) sprites in OAM: in the game these are only the roll counters.
local function small_sprites()
  local OAM, out = emu.memType.snesSpriteRam, {}
  for i = 0, 127 do
    local x, y = readmem(i * 4, OAM), readmem(i * 4 + 1, OAM)
    local hi = readmem(512 + (i >> 2), OAM) >> ((i & 3) * 2)
    if hi & 1 == 1 then x = x - 256 end
    if hi & 2 == 0 and y < 224 and x > -16 then out[#out + 1] = { x = x, y = y } end
  end
  return out
end

-- Last column (1-based) holding a digit in the first 20 columns of a text row.
local function last_digit(row)
  local r, last = bg3_row(row), nil
  for i = 1, 20 do if r:sub(i, i):match("%d") then last = i end end
  return last
end

function test()
  set_limit(20000)
  wait_until(function() return v8("title_choice") == 0xFF end, 200, "title screen")
  wait(20)
  -- menu panel: the third entry of the window table holds its left and right edges
  local w = addr("TitleWindow")
  local left, right = read8(w + 7), read8(w + 8)
  for _, row in ipairs({ 19, 21, 23, 25 }) do
    local a, b = span(row)
    check(a, "menu row " .. row .. " is empty")
    check(b * 8 + 8 <= right - 4, string.format("menu row %d ends at x=%d, panel ends at %d", row, b * 8 + 8, right))
    check(a * 8 - 16 >= left + 4, string.format("menu row %d starts at x=%d: no room for the cursor in a panel from %d", row, a * 8, left))
  end
  check(screen_has("V1."), "no version number on the title")
  shot("layout_title")

  start_game(0)
  wait_human()
  -- dice: as much felt above the top row as below the bottom row's shadow
  local dy = addr("DieY")
  local top = read8(dy) - 28                      -- tray felt starts at y=28
  local bottom = 110 - (read8(dy + 3) + 33)       -- and ends at y=110; shadow bottom is 33 below
  check(top >= 4, "top row of dice touches the tray edge (" .. top .. " px)")
  check(math.abs(top - bottom) <= 4, string.format("dice off-center in the tray: %d px above, %d below", top, bottom))
  -- roll counters: three, inside the plaque (felt x 158-249), right of ROLLS
  local _, rolls_end = bg3_row(16):find("ROLLS", 1, true)
  local pips = small_sprites()
  check(#pips == 3, #pips .. " roll counters on screen, want 3")
  for _, p in ipairs(pips) do
    check(p.x + 2 >= rolls_end * 8, "a roll counter overlaps ROLLS at x=" .. p.x)
    check(p.x + 14 <= 249, "a roll counter runs off the plaque at x=" .. p.x)
  end
  -- names over their columns: the last letter of each name is over the last digit
  press(1, { "x" }, 2)
  wait_human()
  local _, you_end = bg3_row(1):find("YOU", 1, true)
  local skp_start, skp_end = bg3_row(1):find("SKP", 1, true)
  check(you_end and skp_end, "names missing from the scorecard header")
  -- the card's column rules are at x=87 and x=116 (tools/art/game.js)
  local you_start = bg3_row(1):find("YOU", 1, true)
  check((you_start - 1) * 8 >= 88 and you_end * 8 <= 116, "YOU crosses a column rule")
  check((skp_start - 1) * 8 >= 117, "SKP crosses the column rule")
  local d = last_digit(3)                         -- the Ones preview for the human
  check(d == you_end, string.format("YOU ends in column %d, its scores in %d", you_end - 1, (d or 0) - 1))
  shot("layout_game")
  -- the Skipper's scores line up under SKP
  if v8("focus") == 0 then press(1, { "down" }, 2) end
  press(1, { "a" }, 2)
  wait_until(function() return v8("cur") == 1 end, 600, "the Skipper's turn")
  wait_human()
  for c = 0, 11 do
    if score_of(1, c) ~= EMPTY then
      local last = last_digit(3 + 2 * c)
      check(last == skp_end, string.format("Skipper's score in column %d, SKP ends in %d", (last or 0) - 1, skp_end - 1))
    end
  end
end
