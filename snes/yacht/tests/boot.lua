-- The ROM boots, NMI runs every frame, and init clears work RAM.
function test()
  wait(30)
  check(v16("frame") >= 25, "frame counter is " .. v16("frame") .. " after 30 frames")
  for a = 0x7E2000, 0x7E3FFF do
    if read8(a) ~= 0 then fail(string.format("WRAM %06X = %02X after init", a, read8(a))) end
  end
  shot("boot")
end
