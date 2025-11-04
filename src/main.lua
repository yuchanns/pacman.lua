local ltask = require "ltask"

local TICK = 1 / 60
local MAX_DT = 0.25

local last_cs
local accumulator = 0.0

---@type Callback
local callback = {}

---@type Args
local _args = ...

---@type fun()
local game_tick; do
    local tick_count = 0
    local elapsed = 0.0
    function game_tick()
        tick_count = tick_count + 1
        elapsed = elapsed + TICK
        if tick_count % 60 == 0 then
            print(string.format("ticks=%d, elapsed=%.2f", tick_count, elapsed))
        end
    end
end

function callback.frame(_count)
    local _, now_cs = ltask.now()
    if not last_cs then
        last_cs = now_cs
    end

    local dt = (now_cs - last_cs) / 100.0
    last_cs = now_cs

    if dt > MAX_DT then
        dt = MAX_DT
    end
    accumulator = accumulator + dt
    while accumulator >= TICK do
        game_tick()
        accumulator = accumulator - TICK
    end

    -- render
end

return callback
