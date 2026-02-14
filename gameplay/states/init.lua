local flow = require "core.flow"

return function(ctx)
    local config = assert(ctx.world.config)

    local entities = ctx.entities
    assert(#entities == 1, "expected exactly one entity in game state, got " .. tostring(#entities))
    local e = entities[1]

    e.map.status = "init"

    e.texts[#e.texts + 1] = {
        text = "HIGH SCORE",
        x = 9,
        y = 0,
    }
    e.texts[#e.texts + 1] = {
        text = "PLAYER ONE",
        x = 9,
        y = 14,
        color = 0x00FFDE,
    }
    e.texts[#e.texts + 1] = {
        text = "READY!",
        x = 11,
        y = 20,
        color = 0xFFFF00,
    }

    flow.sleep(2 * config.tps - 4)

    return flow.state.round_init, ctx
end
