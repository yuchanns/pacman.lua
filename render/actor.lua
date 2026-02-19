local tiny = require "core.tiny"
local util = require "core.util"

local matpq = require "soluna.material.perspective_quad"

local sprites = util.cache(function(sprite)
    return util.cache(function(scale_x)
        return util.cache(function(scale_y)
            return util.cache(function(color)
                return matpq.sprite(sprite, {
                    color = color,
                    scale_x = scale_x,
                    scale_y = scale_y,
                })
            end)
        end)
    end)
end)

local function cache(tbl)
    local sprite = tbl.sprite
    local scale_x = tbl.scale_x or 1
    local scale_y = tbl.scale_y or 1
    local color = tbl.color or 0x00000000
    return sprites[sprite][scale_x][scale_y][color]
end

local function process(system, e)
    local batch = assert(system.world.resources.batch)

    if not e.visible or not e.sprite then
        return
    end

    local color = e.color
    local actor = e.actor
    local pos = actor.pos

    local scale_x = pos.sx
    local scale_y = pos.sy
    local x = pos.x + pos.ox
    local y = pos.y + pos.oy
    for i = 1, #e.sprite do
        local tbl = e.sprite[i]
        batch:add(cache {
            sprite = tbl.sprite,
            scale_x = tbl.sx or scale_x,
            scale_y = tbl.sy or scale_y,
            color = tbl.color or color,
        }, x, y)
    end
end

return tiny.processingSystem {
    filter = tiny.requireAll "actor",
    priority = 2,

    process = process,
}
