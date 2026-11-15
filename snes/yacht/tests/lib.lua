-- Test helpers. The prelude written by run.sh defines TEST_NAME, TEST_OUT, ADDR.
-- A test is the body of function test(), run as a coroutine, one resume per frame.
local MEM = emu.memType.snesMemory
local held = { [1] = {}, [2] = {} }   -- buttons held per controller port
local co, frames, limit = nil, 0, 100000

local function result(msg)
  local h = io.open(TEST_OUT .. "results/" .. TEST_NAME .. ".txt", "w")
  if h then h:write(msg) h:close() end
end
function fail(msg) result("FAIL: " .. msg) print("FAIL: " .. msg) emu.stop(1) error("stopped", 0) end
function pass() result("PASS") emu.stop(0) error("stopped", 0) end
function check(cond, msg) if not cond then fail(msg) end end
function addr(name) local a = ADDR[name]; if not a then fail("no symbol " .. name) end return a end

function wait(n) for _ = 1, (n or 1) do coroutine.yield() end end
function wait_until(fn, max, what)
  for _ = 1, max do if fn() then return end coroutine.yield() end
  fail("timed out waiting for " .. (what or "condition"))
end
function frame_count() return frames end
function set_limit(n) limit = n end

function read8(a) return emu.read(a, MEM, false) end
function read16(a) return emu.read16(a, MEM, false) end
function write8(a, v) emu.write(a, v, MEM) end
function write16(a, v) emu.write16(a, v, MEM) end
function readmem(a, t) return emu.read(a, t, false) end
function writemem(a, v, t) emu.write(a, v, t) end
function v8(name) return read8(addr(name)) end
function v16(name) return read16(addr(name)) end

-- buttons: list of names: a b x y l r select start up down left right
function hold(port, buttons) local t = {} for _, b in ipairs(buttons) do t[b] = true end held[port] = t end
function release(port) held[port] = {} end
function press(port, buttons, n) hold(port, buttons) wait(n or 2) release(port) wait(n or 2) end

-- Saves the current frame as raw RGB (takeScreenshot is blank in the headless
-- runner); run.sh turns build/shots/*.raw into PNGs.
function shot(name)
  local size = emu.getScreenSize()
  local buf = emu.getScreenBuffer()
  local h = io.open(TEST_OUT .. "shots/" .. name .. ".raw", "wb")
  if not h then return end
  h:write(string.format("%d %d\n", size.width, size.height))
  local parts = {}
  for i = 1, #buf do
    local c = buf[i]
    parts[#parts + 1] = string.char((c >> 16) & 255, (c >> 8) & 255, c & 255)
    if #parts == 4096 then h:write(table.concat(parts)) parts = {} end
  end
  h:write(table.concat(parts))
  h:close()
end

function start_test()
  co = coroutine.create(test)
  emu.addEventCallback(function()
    -- Mesen 2.1.1 takes the controller port as the third argument (the second is ignored)
    for port = 1, 2 do emu.setInput(held[port], 0, port - 1) end
  end, emu.eventType.inputPolled)
  emu.addEventCallback(function()
    frames = frames + 1
    if frames > limit then fail("frame limit " .. limit .. " reached") end
    if coroutine.status(co) == "dead" then return end
    local ok, err = coroutine.resume(co)
    if not ok and err ~= "stopped" then fail("script error: " .. tostring(err)) end
    if coroutine.status(co) == "dead" and ok then pass() end
  end, emu.eventType.endFrame)
end
