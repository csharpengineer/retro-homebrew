-- Reference rules. Faces, Full House, Four Alike, Choice and Yacht as in tandy1000/yacht
-- score_cat; the straights are the poker-dice kind (the SNES boxes are Small and Large).
-- Not a test on its own: run.sh skips files starting with "yacht_".
-- Categories: 0-5 faces, 6 full house, 7 four alike, 8 small straight (any four
-- in a row, 30), 9 large straight (five in a row, 40), 10 choice, 11 yacht.
function ref_score(d, cat)
  local counts, sum = { 0, 0, 0, 0, 0, 0 }, 0
  for i = 1, 5 do counts[d[i]] = counts[d[i]] + 1; sum = sum + d[i] end
  if cat <= 5 then return counts[cat + 1] * (cat + 1) end
  if cat == 6 then
    local three, two = false, false
    for f = 1, 6 do
      if counts[f] == 3 then three = true end
      if counts[f] == 2 then two = true end
    end
    return (three and two) and sum or 0
  end
  if cat == 7 then
    for f = 6, 1, -1 do if counts[f] >= 4 then return f * 4 end end
    return 0
  end
  if cat == 8 then
    for first = 1, 3 do
      if counts[first] > 0 and counts[first + 1] > 0 and counts[first + 2] > 0 and counts[first + 3] > 0 then
        return 30
      end
    end
    return 0
  end
  if cat == 9 then
    for first = 1, 2 do
      local run = true
      for f = first, first + 4 do if counts[f] ~= 1 then run = false end end
      if run then return 40 end
    end
    return 0
  end
  if cat == 10 then return sum end
  for f = 6, 1, -1 do if counts[f] == 5 then return 50 end end
  return 0
end

-- Oracle mailbox at $7E1F10 (see snes/src/vars.inc).
ORACLE = 0x7E1F10
O_CMD, O_DICE, O_ROLLS, O_OPEN, O_SCORES, O_HOLDS, O_PICK, O_SAT, O_DONE = 0, 1, 6, 7, 19, 43, 48, 49, 50

function oracle_call(cmd, dice, rolls, open)
  for i = 1, 5 do write8(ORACLE + O_DICE + i - 1, dice[i]) end
  write8(ORACLE + O_ROLLS, rolls or 0)
  for c = 0, 11 do write8(ORACLE + O_OPEN + c, (open and open[c + 1]) and 1 or 0) end
  write8(ORACLE + O_DONE, 0)
  write8(ORACLE + O_CMD, cmd)
  wait_until(function() return read8(ORACLE + O_DONE) == 0xA5 end, 30, "oracle reply")
end

function enter_selftest()
  hold(1, { "l", "r" })
  wait_until(function() return read16(0x7E1F00) == 0x5A5A end, 900, "self-test to finish")
  release(1)
end
