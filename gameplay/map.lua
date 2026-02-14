local tiny = require "core.tiny"
local matmask = require "soluna.material.mask"

local CMD = setmetatable({}, {
    __index = function(_, k)
        error("unknown map status: " .. tostring(k))
    end,
})

local default_color = 0x2121DE
local sprite_overrieds <const> = {
    ["."] = "tile_10",
}
local color_overrides <const> = {
    ["."] = 0xFFB897,
    P = 0xFFB897,
    ["-"] = 0xFFB8DE,
}

---@type table
local TILES

function CMD.init(map, world)
    map.tiles = {}

    local sprites = assert(world.resources.sprites)
    local config = assert(world.config)

    for y = 1, config.display_tile_y do
        for x = 1, config.display_tile_x do
            local sprite
            if y >= 4 and y <= 34 then
                local i = y - 3
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
    local resources = assert(world.resources)
    TILES = resources.tiles
end

return tiny.processingSystem {
    filter = tiny.requireAll "map",

    priority = 2,

    onAddToWorld = init,

    process = process,
}
