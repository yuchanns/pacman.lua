local archetype = require "gameplay.prefabs.archetypes.player"

local M = {}

M.new = archetype.new

function M.reset(e, args)
    local config = assert(args.config, "missing player config")
    local colors = assert(config.colors, "missing player colors")
    args.color = assert(colors.COLOR_PACMAN)
    archetype.reset(e, args)
end

return M
