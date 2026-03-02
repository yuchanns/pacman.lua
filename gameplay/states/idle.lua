local flow = require "core.flow"

return function(ctx)
    local state = ctx.world.state

    if state.round_won then
        state.round_won = false
        flow.sleep(0)
        return flow.state.round_init, ctx
    end
    return flow.state.idle, ctx
end
