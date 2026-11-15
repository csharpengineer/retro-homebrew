-- Holding L+R at power-on runs the self-test: 23 checks, none failing.
function test()
  enter_selftest()
  local runs, fails = read16(0x7E1F02), read16(0x7E1F04)
  check(runs == 23, "checks run = " .. runs .. ", want 23")
  check(fails == 0, fails .. " checks failed")
  -- The generator is the Tandy one: after 6000 rolls from 1234 the seed must match.
  local s = 1234
  for _ = 1, 6000 do s = (s * 25173 + 13849) % 65536 end
  check(v16("seed") == s, string.format("seed %04X after 6000 rolls, Tandy sequence gives %04X", v16("seed"), s))
  wait(10)
  shot("selftest")
end
