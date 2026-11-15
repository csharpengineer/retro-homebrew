-- The Skipper makes the same choices as the Tandy one (tandy1000/yacht/src/game.asm 895-1127),
-- except for straights, which follow the poker-dice boxes (see yacht_ref.lua).
-- open[c+1] == true means box c is empty for the player on turn.
local EXPECT = { 2, 5, 8, 11, 14, 17, 15, 12, 8, 8, 21, 6 }   -- ai_expect

local function counts_of(d)
  local c = { [0] = 0, 0, 0, 0, 0, 0, 0 }
  for i = 1, 5 do c[d[i]] = c[d[i]] + 1 end
  return c
end

local function scores_now(d, open, cat) return open[cat + 1] and ref_score(d, cat) > 0 end

local function ref_satisfied(d, open)
  -- a small straight only stops him when the large one is filled: with a run
  -- of four held he can still roll for five
  if scores_now(d, open, 11) or scores_now(d, open, 9) or scores_now(d, open, 6)
    or (scores_now(d, open, 8) and not open[10]) then
    return true
  end
  return open[8] and ref_score(d, 7) >= 20
end

local function ref_pick(d, open)
  local best_v, best_c = -32768, 0
  for c = 0, 11 do
    if open[c + 1] then
      local v = ref_score(d, c) - EXPECT[c + 1]
      if v > best_v then best_v, best_c = v, c end
    end
  end
  return best_c
end

local function ref_holds(d, open)
  local h = { 0, 0, 0, 0, 0 }
  local function hold_all(f) for i = 1, 5 do if d[i] == f then h[i] = 1 end end end
  local function hold_one(f) for i = 1, 5 do if d[i] == f then h[i] = 1 return end end end
  local c = counts_of(d)
  local distinct, largest = 0, 0
  for f = 1, 6 do
    if c[f] > 0 then distinct = distinct + 1; if c[f] > largest then largest = c[f] end end
  end
  -- chase a straight: keep one of each face in the run of five (large open) or
  -- four (only small open) worth the most: faces * 2, plus 1 when it already
  -- holds four in a row; ties keep the lower run
  if distinct >= 4 and (open[9] or open[10]) then
    local len = open[10] and 5 or 4
    local best, best_n = 1, -1
    for first = 1, 7 - len do
      local n = 0
      for f = first, first + len - 1 do if c[f] > 0 then n = n + 2 end end
      for s = first, first + len - 4 do
        if c[s] > 0 and c[s + 1] > 0 and c[s + 2] > 0 and c[s + 3] > 0 then n = n + 1 break end
      end
      if n > best_n then best, best_n = first, n end
    end
    for f = best, best + len - 1 do if c[f] > 0 then hold_one(f) end end
    return h
  end
  -- two pairs chase a full house
  if open[7] then
    local pairs = 0
    for f = 1, 6 do if c[f] == 2 then pairs = pairs + 1 end end
    if pairs == 2 then
      for f = 1, 6 do if c[f] == 2 then hold_all(f) end end
      return h
    end
  end
  -- keep the most promising group of matching dice
  local bw, bf = 0, 0
  for f = 1, 6 do
    if c[f] > 0 then
      local w = c[f] * 8 + f
      if open[f] then w = w + 6 end
      if w > bw then bw, bf = w, f end
    end
  end
  if c[bf] >= 2 or bf >= 5 then hold_all(bf) end
  return h
end

local rng = 4321
local function rnd(n) rng = (rng * 1103515245 + 12345) % 2147483648; return (rng // 65536) % n end

local function check_case(d, open, label)
  oracle_call(2, d, 1, open)
  local want_h, want_p, want_s = ref_holds(d, open), ref_pick(d, open), ref_satisfied(d, open)
  local desc = string.format("%s dice %d%d%d%d%d open ", label, d[1], d[2], d[3], d[4], d[5])
  for c = 1, 12 do desc = desc .. (open[c] and "1" or "0") end
  for i = 1, 5 do
    local got = read8(ORACLE + O_HOLDS + i - 1)
    if got ~= want_h[i] then fail(desc .. ": hold die " .. i .. " = " .. got .. ", want " .. want_h[i]) end
  end
  local p = read8(ORACLE + O_PICK)
  if p ~= want_p then fail(desc .. ": picked box " .. p .. ", want " .. want_p) end
  local s = read8(ORACLE + O_SAT)
  if s ~= (want_s and 1 or 0) then fail(desc .. ": satisfied = " .. s) end
  return p
end

local function all_open() local o = {} for c = 1, 12 do o[c] = true end return o end

function test()
  set_limit(40000)
  enter_selftest()
  -- fixed cases
  check(check_case({ 6, 6, 6, 6, 6 }, all_open(), "yacht") == 11, "five sixes should go in Yacht")
  local only_ones = {} for c = 1, 12 do only_ones[c] = (c == 1) end
  check(check_case({ 2, 3, 4, 5, 6 }, only_ones, "forced") == 0, "only Ones open should pick Ones")
  -- 1,1,2,3,4 with only Ones and Twos open: Ones scores 2-2=0, Twos 2-5=-3; Ones wins
  local o2 = {} for c = 1, 12 do o2[c] = (c <= 2) end
  check(check_case({ 1, 1, 2, 3, 4 }, o2, "best") == 0, "should pick Ones")
  -- a tie goes to the first box: 3,3,3,3,3 with only Fours and Fives open both score 0-11 / 0-14,
  -- so use Choice vs Threes: 2,2,2,2,2 Twos 10-5=5, Choice 10-21; build a true tie instead:
  -- Fours (0-11=-11) and Little Straight with dice 6,6,6,6,6 (0-8=-8) vs Big (0-8=-8): Little wins
  local o3 = {} for c = 1, 12 do o3[c] = (c == 9 or c == 10) end
  check(check_case({ 6, 6, 6, 6, 6 }, o3, "tie") == 8, "tie should go to the first box")
  -- 1,3,4,5,6 with both straights open: both runs of five have four faces, but
  -- only 3-6 keeps the small straight he already has, so he holds 3,4,5,6
  oracle_call(2, { 1, 3, 4, 5, 6 }, 1, all_open())
  local want = { 0, 1, 1, 1, 1 }
  for i = 1, 5 do
    check(read8(ORACLE + O_HOLDS + i - 1) == want[i], "with 1,3,4,5,6 die " .. i .. " hold is wrong: should keep 3-6")
  end
  -- random cases
  for n = 1, 3000 do
    local d, open, any = {}, {}, false
    for i = 1, 5 do d[i] = rnd(6) + 1 end
    for c = 1, 12 do open[c] = rnd(3) > 0; any = any or open[c] end
    if not any then open[rnd(12) + 1] = true end
    check_case(d, open, "case " .. n)
  end
end
