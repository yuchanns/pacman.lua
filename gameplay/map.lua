local tiny = require "core.tiny"
local matmask = require "soluna.material.mask"

local CMD = setmetatable({}, {
    __index = function(_, k)
        error("unknown map status: " .. tostring(k))
    end,
})

local sprite_overrieds <const> = {
    ["."] = "tile_10",
}
local default_color
local color_overrides
local map_offset_y
local map_rows

---@type table
local TILES

function CMD.init(map, world)
    map.tiles = {}

    local sprites = assert(world.resources.sprites)
    local config = assert(world.config)

    for y = 1, config.display_tile_y do
        for x = 1, config.display_tile_x do
            local sprite
            if y > map_offset_y and y <= map_offset_y + map_rows then
                local i = y - map_offset_y
                local line = assert(TILES[i])
                local c = line:sub(x, x)
                if c ~= "" then
                    local sprite_id = sprite_overrieds[c] or ("tile_" .. c)
                    local base_sprite = sprites[sprite_id]
                    if base_sprite then
                        assert(math.type(base_sprite) == "integer")
                        local color = color_overrides[c] or default_color
                        sprite = matmask.mask(base_sprite, color)
                    end
                end
            end
            table.insert(map.tiles, {
                sprite = sprite,
                x = (x - 1) * config.tile,
                y = (y - 1) * config.tile,
            })
        end
    end
    map.status = nil
end

local function process(system, e)
    local world = system.world
    local map = e.map
    if not map.status then
        return
    end
    CMD[map.status](map, assert(world))
end

local function init(_, world)
    local config = assert(world.config)
    local resources = assert(world.resources)
    TILES = resources.tiles
    map_offset_y = assert(config.map_offset_y)
    map_rows = assert(config.map_rows)

    local colors = assert(config.colors)
    default_color = assert(colors.COLOR_FRIGHTENED)
    color_overrides = {
        ["."] = assert(colors.COLOR_DOT),
        P = assert(colors.COLOR_DOT),
        ["-"] = assert(colors.COLOR_PINKY),
    }
end

return tiny.processingSystem {
    filter = tiny.requireAll "map",

    priority = 2,

    onAddToWorld = init,

    process = process,
}
