-- Text reaches the screen: the self-test page prints its results on BG3.
local BG3_MAP = 0x5800          -- VRAM word address of the BG3 tilemap

local function tile_at(row, col)
  local a = (BG3_MAP + row * 32 + col) * 2
  return readmem(a, emu.memType.snesVideoRam) + 256 * readmem(a + 1, emu.memType.snesVideoRam)
end

local function row_text(row)
  local s = ""
  for col = 0, 31 do
    local t = tile_at(row, col) & 0x3FF
    s = s .. string.char(t + 32)
  end
  return s
end

function test()
  enter_selftest()
  wait(5)
  local found = {}
  for row = 0, 27 do
    local s = row_text(row)
    if s:find("SELF TEST", 1, true) then found.title = true end
    if s:find("22 CHECKS RUN", 1, true) then found.runs = true end
    if s:find("0 FAILED", 1, true) then found.failed = true end
  end
  check(found.title, "no SELF TEST heading in the BG3 map")
  check(found.runs, "no '22 CHECKS RUN' line")
  check(found.failed, "no '0 FAILED' line")
  local bgmode = 0
  shot("text")
end
