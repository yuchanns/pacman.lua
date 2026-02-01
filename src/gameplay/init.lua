local flow = require "src.core.flow"
local viewport = require "src.visual.viewport"
local hud = require "src.visual.hud"
local palette = require "src.visual.palette"

return function(args)
    viewport.resize(args.w, args.h)

    hud:init_playfield()
    hud:text("HIGH SCORE", 9, 0)
    hud:text("PLAYER ONE", 9, 14, palette.COLOR_INKY)
    hud:text("READY!", 11, 20, palette.COLOR_PACMAN)

    flow.sleep(2 * args.tps - 4)

    return flow.state.round_init, { tps = args.tps }
end
