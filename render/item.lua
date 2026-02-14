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

local function cache(sprite, scale_x, scale_y, color)
    return sprites[sprite][scale_x][scale_y][color]
end

local function process(system, e)
    local batch = assert(system.world.resources.batch)

    local render_item = e.render_item
    local position = e.position

    if not render_item.visible or not render_item.sprite then
        return
    end

    local sprite = render_item.sprite

    local color = render_item.color

    local scale_x = position.scale_x
    local scale_y = position.scale_y
    local x = position.x + position.offset_x
    local y = position.y + position.offset_y

    batch:add(cache(sprite, scale_x, scale_y, color), x, y)
end

return tiny.processingSystem {
    filter = tiny.requireAll("render_item", "position"),
    priority = 2,

    process = process,
}
