local tiny = require "core.tiny"

local KEY_RIGHT <const> = 262
local KEY_LEFT <const> = 263
local KEY_DOWN <const> = 264
local KEY_UP <const> = 265
local KEY_H <const> = 72
local KEY_J <const> = 74
local KEY_K <const> = 75
local KEY_L <const> = 76

local KEY_TO_DIR <const> = {
    [KEY_LEFT] = "left",
    [KEY_H] = "left",
    [KEY_RIGHT] = "right",
    [KEY_L] = "right",
    [KEY_UP] = "up",
    [KEY_K] = "up",
    [KEY_DOWN] = "down",
    [KEY_J] = "down",
}

local function process(system, e)
    local event = assert(system.world.state.keys)
    if #event == 0 then
        return
    end

    local state = system.world.state
    if state.freeze then
        for i = 1, #event do
            event[i] = nil
        end
        return
    end

    local input = e.input
    for i = 1, #event do
        local ev = event[i]
        event[i] = nil
        if ev and ev.key_state ~= 0 then
            local dir = KEY_TO_DIR[ev.keycode]
            if dir then
                input.requested_dir = dir
            end
        end
    end
end

return tiny.processingSystem {
    filter = tiny.requireAll "input",

    process = process,
}
