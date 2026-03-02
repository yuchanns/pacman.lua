local flow = require "core.flow"

local round = 0
---@type number
local num_lives
local num_ghosts_eaten = 0

return function(ctx)
    local config = ctx.world.config
    local colors = config.colors
    local state = ctx.world.state
    local commands = state.commands

    local e = ctx.entity

    if not num_lives then
        num_lives = config.num_lives
    end

    -- clear the "PLAYER ONE" text
    commands.texts {
        x = 9,
        y = 14,
    }

    -- Pacman has eaten all dots, start a new round
    if state.num_dots_eaten >= config.num_dots then
        round = round + 1
        state.num_dots_eaten = 0
        e.map.status = "reset"
        num_lives = config.num_lives
        state.score = 0
        commands.texts {
            text = "00",
            x = 6,
            y = 1,
            align = "right",
        }
        commands.despawns {}
    else
        -- previous round was lost
        num_lives = num_lives - 1
        state.score = 0
        commands.texts {
            text = "00",
            x = 6,
            y = 1,
            align = "right",
        }
        commands.despawns {}
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
            player = true,
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
    return flow.state.round_started, ctx
end
