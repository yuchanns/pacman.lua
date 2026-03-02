local tiny = require "core.tiny"
local matmask = require "soluna.material.mask"
local util = require "core.util"

local tick = 0

local CMD = setmetatable({}, {
    __index = function(_, k)
        error("unknown map status: " .. tostring(k))
    end,
})

local CACHE_MATMASK = util.cache(function(sprite)
    return util.cache(function(color)
        return matmask.mask(sprite, color)
    end)
end)

local sprite_overrieds <const> = {
    ["."] = "tile_10",
}
---@type integer
local default_color
---@type table
local color_overrides
---@type integer
local map_offset_y
---@type integer
local map_rows

---@type table
local TILES

function CMD.init(map, world)
    map.tiles = {}

    local sprites = world.resources.sprites
    local config = world.config

    for y = 1, config.display_tile_y do
        for x = 1, config.display_tile_x do
            local sprite
            local base_sprite
            if y > map_offset_y and y <= map_offset_y + map_rows then
                local i = y - map_offset_y
                local line = assert(TILES[i])
                local c = line:sub(x, x)
                if c ~= "" then
                    local sprite_id = sprite_overrieds[c] or ("tile_" .. c)
                    base_sprite = sprites[sprite_id]
                    if base_sprite then
                        assert(math.type(base_sprite) == "integer")
                        local color = color_overrides[c] or default_color
                        sprite = CACHE_MATMASK[base_sprite][color]
                    end
                end
            end
            table.insert(map.tiles, {
                sprite = sprite,
                base_sprite = base_sprite,
                x = (x - 1) * config.tile,
                y = (y - 1) * config.tile,
            })
        end
    end
    map.status = "update"
end

function CMD.reset(map, world)
    local sprites = world.resources.sprites
    local config = world.config
    for y = 1, config.display_tile_y do
        for x = 1, config.display_tile_x do
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
                        local sprite = CACHE_MATMASK[base_sprite][color]
                        local tile = map.tiles[(y - 1) * config.display_tile_x + x]
                        tile.sprite = sprite
                        tile.base_sprite = base_sprite
                    end
                end
            end
        end
    end
    map.status = "update"
end

local pill_pos <const> = {
    { x = 1,  y = 6 },
    { x = 26, y = 6 },
    { x = 1,  y = 26 },
    { x = 26, y = 26 },
}

function CMD.update(map, world)
    local config = world.config
    local state = world.state
    -- update the energizer pill colors (blinking/non-blinking)
    for _, pos in ipairs(pill_pos) do
        local x, y = pos.x, pos.y
        local tile = map.tiles[y * config.display_tile_x + x + 1]
        if tile.sprite and tile.base_sprite then
            local color
            if state.freeze then
                color = color_overrides["P"]
            else
                color = ((tick // 8) % 2) == 1 and color_overrides["P"] or 0
            end
            tile.sprite = CACHE_MATMASK[tile.base_sprite][color]
        end
    end
end

local function process(system, e)
    local world = system.world
    local map = e.map
    if not map.status then
        return
    end
    CMD[map.status](map, world)
end

local function init(_, world)
    local config = world.config
    local resources = world.resources
    TILES = resources.tiles
    map_offset_y = config.map_offset_y
    map_rows = config.map_rows

    local colors = config.colors
    default_color = assert(colors.COLOR_FRIGHTENED)
    color_overrides = {
        ["."] = assert(colors.COLOR_DOT),
        P = assert(colors.COLOR_DOT),
        ["-"] = assert(colors.COLOR_PINKY),
    }
end

local function preWrap()
    tick = tick + 1
end

return tiny.processingSystem {
    filter = tiny.requireAll "map",

    priority = 2,

    preWrap = preWrap,

    onAddToWorld = init,

    process = process,
}
