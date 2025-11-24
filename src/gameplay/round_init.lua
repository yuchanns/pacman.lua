local hud = require "src.visual.hud"
local flow = require "src.core.flow"
local palette = require "src.visual.palette"

local NUM_DOTS <const> = 244 -- 240 small dots + 4 pills
local NUM_LIVES <const> = 3
local round = 0
local num_dots_eaten = 0
local num_lives = NUM_LIVES
local num_ghosts_eaten = 0

return function()
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

    num_ghosts_eaten = 0

    hud:text("READY!", 11, 20, palette.COLOR_PACMAN)

    return flow.state.idle
end
