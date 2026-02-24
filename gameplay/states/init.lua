local flow = require "core.flow"

return function(ctx)
    local config = ctx.world.config
    local colors = config.colors
    local commands = ctx.world.state.commands

    local e = assert(ctx.entity)

    e.map.status = "init"

    commands.texts {
        text = "HIGH SCORE",
        x = 9,
        y = 0,
    }
    commands.texts {
        text = "PLAYER ONE",
        x = 9,
        y = 14,
        color = assert(colors.COLOR_GHOST_SCORE),
    }
    commands.texts {
        text = "READY!",
        x = 11,
        y = 20,
        color = assert(colors.COLOR_PACMAN),
    }

    flow.sleep(2 * config.tps - 4)

    return flow.state.round_init, ctx
end
