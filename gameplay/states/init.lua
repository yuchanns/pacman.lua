local flow = require "core.flow"

return function(ctx)
    local config = assert(ctx.world.config)
    local colors = assert(config.colors)

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
        color = assert(colors.COLOR_GHOST_SCORE),
    }
    e.texts[#e.texts + 1] = {
        text = "READY!",
        x = 11,
        y = 20,
        color = assert(colors.COLOR_PACMAN),
    }

    flow.sleep(2 * config.tps - 4)

    return flow.state.round_init, ctx
end
