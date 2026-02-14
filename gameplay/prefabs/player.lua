local archetype = require "gameplay.prefabs.archetypes.player"

local M = {}

M.new = archetype.new

function M.reset(e, args)
    args.color = 0xFFFF00
    archetype.reset(e, args)
end

return M
