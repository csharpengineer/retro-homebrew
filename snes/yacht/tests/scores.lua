-- Every one of the 7776 possible rolls scores the same as the Tandy rules, in all 12 boxes.
function test()
  set_limit(60000)
  enter_selftest()
  local d = { 1, 1, 1, 1, 1 }
  for n = 0, 7775 do
    local x = n
    for i = 1, 5 do d[i] = x % 6 + 1; x = x // 6 end
    oracle_call(1, d)
    for c = 0, 11 do
      local got = read16(ORACLE + O_SCORES + c * 2)
      local want = ref_score(d, c)
      if got ~= want then
        fail(string.format("dice %d%d%d%d%d box %d scored %d, want %d", d[1], d[2], d[3], d[4], d[5], c, got, want))
      end
    end
  end
end
