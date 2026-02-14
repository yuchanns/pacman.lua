local flow = require "core.flow"

local NUM_DOTS <const> = 244 -- 240 small dots + 4 pills
local NUM_LIVES <const> = 3

local round = 0
local num_dots_eaten = 0
local num_lives = NUM_LIVES
local num_ghosts_eaten = 0

local pos

return function(ctx)
    local config = assert(ctx.world.config)
    local colors = assert(config.colors)
    local resources = assert(ctx.world.resources)
    local state = assert(ctx.world.state)

    if pos == nil then
        pos = function(tx, ty, ox, oy)
            return tx * config.tile + (ox or 0), ty * config.tile + (oy or 0)
        end
    end

    local entities = ctx.entities
    assert(#entities == 1, "expected exactly one entity in game state, got " .. tostring(#entities))
    local e = entities[1]

    -- clear the "PLAYER ONE" text
    e.texts[#e.texts + 1] = {
        text = "         ",
        x = 9,
        y = 14,
    }

    -- Pacman has eaten all dots, start a new round
    if num_dots_eaten >= NUM_DOTS then
        round = round + 1
        num_dots_eaten = 0
        e.map.status = "init"
    else
        -- previous round was lost
        num_lives = num_lives - 1
    end

    assert(num_lives >= 0)

    state.freeze = true

    do
        local x, y = pos(13, 25, 0, 8)
        e.spawns[#e.spawns + 1] = {
            kind = "player",
            args = {
                x = x,
                y = y,
                dir = "left",
                visible = true,
                config = config,
                resources = resources,
            },
        }
    end

    num_ghosts_eaten = 0

    e.texts[#e.texts + 1] = {
        text = "READY!",
        x = 11,
        y = 20,
        color = assert(colors.COLOR_PACMAN),
    }

    flow.sleep(2 * config.tps - 4)

    state.freeze = false

    -- clear the "READY!" text
    e.texts[#e.texts + 1] = {
        text = "       ",
        x = 11,
        y = 20,
    }

    return flow.state.idle, ctx
end
