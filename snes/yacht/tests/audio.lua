-- Sound: the title tune plays, "Welcome aboard" is spoken, and muting stops the
-- voice at once and keeps later clips quiet, even after a reset.
-- Driver state in sound RAM: $E0 tune ($FF none), $E1 voice playing, $E2 muted.
local SPC = emu.memType.spcRam
local function st(a) return readmem(a, SPC) end

function test()
  wait_until(function() return v8("title_choice") == 0xFF end, 300, "title screen")
  wait_until(function() return st(0xE0) == 0 end, 120, "the title tune (driver tune 0)")
  wait_until(function() return st(0xE1) == 1 end, 120, "the welcome voice to start")
  check(st(0xE2) == 0, "driver muted at power-on")
  -- the chip really makes sound: voice 7 (speech) and the music voices 0-3
  local DSP = emu.memType.spcDspRegisters
  local heard = { [0] = 0, 0, 0, 0, [7] = 0 }
  for _ = 1, 30 do
    for v, _ in pairs(heard) do
      local out = readmem(v * 16 + 9, DSP)
      if readmem(v * 16 + 8, DSP) > 0 and out ~= 0 then heard[v] = heard[v] + 1 end
    end
    wait(1)
  end
  check(heard[7] > 0, "the speech voice never produced output")
  check(heard[0] > 0 and heard[1] > 0, "melody/bass silent during the title tune")
  check(st(0xE1) == 1, "welcome voice ended too soon to test muting")
  press(1, { "select" }, 2)
  check(st(0xE1) == 0, "voice still playing after mute")
  check(st(0xE2) == 1, "driver not muted")
  local kon = readmem(0x4C, emu.memType.spcDspRegisters)
  check(kon & 0x80 == 0, "voice 7 keyed on while muted")
  -- muted means silent: the DSP's own mute bit (FLG bit 6) also stops the echo,
  -- and the clip is really keyed off (its envelope falls to 0)
  check(readmem(0x6C, DSP) & 0x40 ~= 0, "FLG mute bit not set while muted (echo still audible)")
  wait(3)
  check(readmem(0x78, DSP) == 0, "voice 7 envelope still " .. readmem(0x78, DSP) .. " after mute: key-off missed")

  emu.reset()
  wait(10)
  wait_until(function() return v8("title_choice") == 0xFF end, 300, "title after reset")
  wait_until(function() return st(0xE2) == 1 end, 120, "the saved mute to reach the driver")
  for _ = 1, 120 do
    check(st(0xE1) == 0, "a voice played while muted")
    wait(1)
  end
  -- sound back on
  wait(20)
  press(1, { "select" }, 2)
  check(st(0xE2) == 0, "unmute didn't reach the driver")
  check(readmem(0x6C, emu.memType.spcDspRegisters) & 0x40 == 0, "FLG mute bit still set after unmute")
end
