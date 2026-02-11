local font = require "soluna.font"
local matmask = require "soluna.material.mask"
local matpq = require "soluna.material.perspective_quad"
local mattext = require "soluna.material.text"

local palette = require "src.visual.palette"
local util = require "src.core.util"
local state = require "src.gameplay.state"
local anim8 = require "src.core.anim8"
local map = require "src.gameplay.map"

---@type Batch?
local BATCH
---@type SpriteBundle?
local SPRITES

---@type integer?
local FONT_ID

local TEXT = util.cache(function(color)
    assert(FONT_ID, "FONT_ID not initialized, call hud.init first")

    local block = mattext.block(font.cobj(), FONT_ID, map.TILE, color, "LT")
    return block
end)

local PACMAN_PQ_STREAM = util.cache(function(key)
    local sprite, sx, sy, color = key:match "^([^|]+)|([^|]+)|([^|]+)|([^|]+)$"
    assert(sprite and sx and sy and color, "Invalid pacman sprite cache key")
    return matpq.sprite(assert(tonumber(sprite)), {
        color = assert(tonumber(color)),
        scale_x = assert(tonumber(sx)),
        scale_y = assert(tonumber(sy)),
    })
end)

local function pacman_sprite(sprite, scale_x, scale_y, color)
    local key = string.format("%d|%g|%g|%u", sprite, scale_x, scale_y, color)
    return PACMAN_PQ_STREAM[key]
end

local hud = {
    tiles = {},
}

---@param args table
function hud.init(args)
    BATCH = args.batch
    SPRITES = args.sprites

    FONT_ID = font.name "Pacman Tiles"
end

---@param text string
---@param x integer
---@param y integer
---@param color integer?
function hud:text(text, x, y, color)
    color = color or palette.COLOR_EYES
    local block = TEXT[color]
    self.tiles[y * map.DISPLAY_TILE_X + x + 1].sprite = block(text, #text * map.TILE, map.TILE)
end

function hud:clear()
    self.tiles = {}
end

-- see @assets/layouts/hud.dl > region : map
function hud.map(self)
    assert(BATCH, "BATCH not initialized, call hud.init first")
    assert(SPRITES)

    BATCH:layer(self.x, self.y)

    for _idx, tile in ipairs(hud.tiles) do
        if tile.sprite then
            BATCH:add(tile.sprite, tile.x, tile.y)
        end
    end

    local p = state.actors.pacman
    if not p.anim then
        p.anim = {
            h = anim8.new({
                SPRITES.pacman,
                SPRITES.pacman_r_1,
                SPRITES.pacman_r_2,
                SPRITES.pacman_r_1,
            }, 1),
            v = anim8.new({
                SPRITES.pacman,
                SPRITES.pacman_d_1,
                SPRITES.pacman_d_2,
                SPRITES.pacman_d_1,
            }, 1),
        }
        anim8.unregister(p.anim.h)
        anim8.unregister(p.anim.v)
    end
    if p.visible then
        local anim = (p.dir == "up" or p.dir == "down") and p.anim.v or p.anim.h
        local other_anim = (p.anim.h == anim and p.anim.v or p.anim.h)
        other_anim:pause()
        if state.freeze.ready then
            anim:pause()
        elseif not p.moved then
            anim:pauseAtStart()
        else
            anim:resume()
        end
        local sprite = anim:getFrame()
        if sprite then
            local scale_x, scale_y = 1, 1
            if p.dir == "left" then
                scale_x = -1
            elseif p.dir == "up" then
                scale_y = -1
            end
            local stream = pacman_sprite(sprite, scale_x, scale_y, palette.COLOR_PACMAN)
            BATCH:add(stream, p.x + map.TILE, p.y + map.TILE)
        end
    end

    BATCH:layer()
end

function hud:init_playfield()
    assert(SPRITES, "SPRITES not initialized, call hud.init first")
    self:clear()
    local default_color = palette.COLOR_FRIGHTENED
    local sprite_overrides <const> = {
        ["."] = "tile_10",
    }
    local color_overrides <const> = {
        ["."] = palette.COLOR_DOT,
        P = palette.COLOR_DOT,
        ["-"] = palette.COLOR_PINKY,
    }
    for y = 1, map.DISPLAY_TILE_Y do
        for x = 1, map.DISPLAY_TILE_X do
            local sprite
            if y >= 4 and y <= 34 then
                local i = y - 3
                local line = assert(map.tiles[i])
                local c = line:sub(x, x)
                if c ~= "" then
                    local sprite_id = sprite_overrides[c] or ("tile_" .. c)
                    local base_sprite = SPRITES[sprite_id]
                    if base_sprite then
                        assert(type(base_sprite) == "number")
                        local color = color_overrides[c] or default_color
                        sprite = matmask.mask(base_sprite, color)
                    end
                end
            end
            table.insert(self.tiles, {
                sprite = sprite,
                x = (x - 1) * map.TILE,
                y = (y - 1) * map.TILE,
            })
        end
    end
end

return hud
