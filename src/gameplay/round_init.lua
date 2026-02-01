local hud = require "src.visual.hud"
local flow = require "src.core.flow"
local palette = require "src.visual.palette"
local state = require "src.gameplay.state"
local map = require "src.gameplay.map"

local function pos(tx, ty, ox, oy)
    return tx * map.TILE + (ox or 0), ty * map.TILE + (oy or 0)
end
local NUM_DOTS <const> = 244 -- 240 small dots + 4 pills
local NUM_LIVES <const> = 3
local round = 0
local num_dots_eaten = 0
local num_lives = NUM_LIVES
local num_ghosts_eaten = 0

return function(args)
    -- clear the "PLAYER ONE" text
    hud:text("         ", 9, 14)

    --  Pacman has eaten all dots, start a new round
    if num_dots_eaten >= NUM_DOTS then
        round = round + 1
        num_dots_eaten = 0
        hud:init_playfield()
    else
        -- previous round was lost
        num_lives = num_lives - 1
    end
    assert(num_lives >= 0)

    state.freeze.ready = true

    do
        local x, y = pos(13, 25, 0, 8)
        state.actors.pacman = {
            x = x,
            y = y,
            dir = "left",
            visible = true,
        }
    end

    num_ghosts_eaten = 0

    hud:text("READY!", 11, 20, palette.COLOR_PACMAN)

    flow.sleep(2 * args.tps - 4)

    state.freeze.ready = false
    hud:text("       ", 11, 20)

    return flow.state.idle
end
