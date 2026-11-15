-- The title tune ends with the title: no music under the game (only the
-- jingles after scoring), so nothing is left to cut off at the first roll.
local SPC = emu.memType.spcRam
function test()
  set_limit(20000)
  wait_until(function() return v8("title_choice") == 0xFF end, 300, "title screen")
  wait_until(function() return readmem(0xE0, SPC) == 0 end, 120, "the title tune")
  start_game(0)
  check(readmem(0xE0, SPC) == 0xFF, "title tune still playing when the game starts")
  wait_human()
  -- the music voices 0-3 are quiet (envelopes at zero)
  wait(10)
  local DSP = emu.memType.spcDspRegisters
  for v = 0, 3 do
    check(readmem(v * 16 + 8, DSP) == 0, "music voice " .. v .. " still sounding in the game")
  end
end
