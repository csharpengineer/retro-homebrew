-- Battery save RAM: garbage on first power-on resets to defaults; the best
-- score and the sound setting survive a reset.
local SRAM = emu.memType.snesSaveRam

local function sram(i) return readmem(i, SRAM) end

function test()
  -- case 1: random bytes in save RAM (what a new cart holds), then power on
  local r = 77
  for i = 0, 0x7FF do r = (r * 1103515245 + 12345) % 2147483648; writemem(i, (r // 65536) % 256, SRAM) end
  emu.reset()
  wait(10)                             -- let init clear RAM before looking
  wait_until(function() return v8("title_choice") == 0xFF end, 200, "title after reset")
  check(v16("best") == 0, "garbage save gave best = " .. v16("best"))
  check(v8("muted") == 0, "garbage save gave muted = " .. v8("muted"))
  check(sram(0) == 0x59 and sram(1) == 0x43 and sram(2) == 0x48 and sram(3) == 0x54, "save RAM not re-signed YCHT")

  -- case 2: a best score and muting survive a reset
  wait(40)                             -- let the title finish loading
  write16(addr("best"), 123)
  press(1, { "select" }, 3)            -- Select toggles sound and saves
  check(v8("muted") == 1, "Select on the title should mute")
  emu.reset()
  wait(10)                             -- let init clear RAM before looking
  wait_until(function() return v8("title_choice") == 0xFF end, 200, "title after second reset")
  check(v16("best") == 123, "best after reset = " .. v16("best") .. ", want 123")
  check(v8("muted") == 1, "muted after reset = " .. v8("muted") .. ", want 1")

  -- case 3: one flipped byte (bad checksum) falls back to defaults
  writemem(4, sram(4) ~ 0x10, SRAM)
  emu.reset()
  wait(10)                             -- let init clear RAM before looking
  wait_until(function() return v8("title_choice") == 0xFF end, 200, "title after third reset")
  check(v16("best") == 0, "corrupt save kept best = " .. v16("best"))
end
