local flow = require "core.flow"

return function(ctx)
    local state = ctx.world.state
    local commands = state.commands

    state.freeze = false

    -- clear the "READY!" text
    commands.texts {
        text = "      ",
        x = 11,
        y = 20,
    }

    return flow.state.idle, ctx
end
