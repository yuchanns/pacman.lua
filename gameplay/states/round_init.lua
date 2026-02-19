local flow = require "core.flow"

local NUM_DOTS <const> = 244 -- 240 small dots + 4 pills
local NUM_LIVES <const> = 3

local round = 0
local num_dots_eaten = 0
local num_lives = NUM_LIVES
local num_ghosts_eaten = 0

return function(ctx)
    local config = assert(ctx.world.config)
    local colors = assert(config.colors)
    local state = assert(ctx.world.state)
    local commands = assert(state.commands)

    local entities = ctx.entities
    assert(#entities == 1, "expected exactly one entity in game state, got " .. tostring(#entities))
    local e = entities[1]

    -- clear the "PLAYER ONE" text
    commands.texts {
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

    num_ghosts_eaten = 0

    commands.texts {
        text = "READY!",
        x = 11,
        y = 20,
        color = assert(colors.COLOR_PACMAN),
    }

    commands.spawns {
        kind = "pacman",
        args = {
            visible = true,
            input = {},
        },
    }

    commands.spawns {
        kind = "blinky",
        args = {
            visible = true,
            -- state = "scatter",
            state = "house",
            dot_counter = 0,
        },
    }

    commands.spawns {
        kind = "pinky",
        args = {
            visible = true,
            state = "house",
            dot_counter = 0,
        },
    }

    commands.spawns {
        kind = "inky",
        args = {
            visible = true,
            state = "house",
            dot_counter = 0,
        },
    }

    commands.spawns {
        kind = "clyde",
        args = {
            visible = true,
            state = "house",
            dot_counter = 0,
        },
    }

    flow.sleep(2 * config.tps - 4)

    state.freeze = false

    -- clear the "READY!" text
    commands.texts {
        text = "      ",
        x = 11,
        y = 20,
    }

    return flow.state.idle, ctx
end
