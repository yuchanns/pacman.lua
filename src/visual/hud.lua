local font = require "soluna.font"
local matmask = require "soluna.material.mask"
local mattext = require "soluna.material.text"

local palette = require "src.visual.palette"
local util = require "src.core.util"
local state = require "src.gameplay.state"
local anim8 = require "src.core.anim8"

---@type Batch?
local BATCH
---@type SpriteBundle?
local SPRITES

local DISPLAY_TILE_X <const> = 28
local DISPLAY_TILE_Y <const> = 36
local TILE_PIXEL_SIZE <const> = 16

---@type integer?
local FONT_ID

local TEXT = util.cache(function(color)
    assert(FONT_ID, "FONT_ID not initialized, call hud.init first")

    local block = mattext.block(font.cobj(), FONT_ID, TILE_PIXEL_SIZE, color, "LT")
    return block
end)

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
    self.tiles[y * DISPLAY_TILE_X + x + 1].sprite = block(text, #text * TILE_PIXEL_SIZE, TILE_PIXEL_SIZE)
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
        local c = palette.COLOR_PACMAN
        p.anim = {
            h = anim8.new({
                matmask.mask(SPRITES.pacman, c),
                matmask.mask(SPRITES.pacman_r_1, c),
                matmask.mask(SPRITES.pacman_r_2, c),
                matmask.mask(SPRITES.pacman_r_1, c),
            }, 0.06),
            v = anim8.new({
                matmask.mask(SPRITES.pacman, c),
                matmask.mask(SPRITES.pacman_d_1, c),
                matmask.mask(SPRITES.pacman_d_2, c),
                matmask.mask(SPRITES.pacman_d_1, c),
            }, 0.06),
        }
    end
    if p.visible then
        local anim = (p.dir == "up" or p.dir == "down") and p.anim.v or p.anim.h
        local rot = (p.dir == "left" or p.dir == "up") and math.pi or 0
        local pivotX, pivotY = p.x + TILE_PIXEL_SIZE, p.y + TILE_PIXEL_SIZE;
        (p.anim.h == anim and p.anim.v or p.anim.h):pause()
        if state.freeze.ready then
            anim:pause()
        else
            anim:resume()
        end
        BATCH:layer(1, rot, pivotX, pivotY)
        anim:draw(-TILE_PIXEL_SIZE, -TILE_PIXEL_SIZE)
        BATCH:layer()
    end

    BATCH:layer()
end

function hud:init_playfield()
    assert(SPRITES, "SPRITES not initialized, call hud.init first")
    self:clear()
    local tiles <const> = {
        "0UUUUUUUUUUUU45UUUUUUUUUUUU1",
        "L............rl............R",
        "L.ebbf.ebbbf.rl.ebbbf.ebbf.R",
        "LPr  l.r   l.rl.r   l.r  lPR",
        "L.guuh.guuuh.gh.guuuh.guuh.R",
        "L..........................R",
        "L.ebbf.ef.ebbbbbbf.ef.ebbf.R",
        "L.guuh.rl.guuyxuuh.rl.guuh.R",
        "L......rl....rl....rl......R",
        "2BBBBf.rzbbf rl ebbwl.eBBBB3",
        "     L.rxuuh gh guuyl.R     ",
        "     L.rl          rl.R     ",
        "     L.rl mjs--tjn rl.R     ",
        "UUUUUh.gh i      q gh.gUUUUU",
        "      .   i      q   .      ",
        "BBBBBf.ef i      q ef.eBBBBB",
        "     L.rl okkkkkkp rl.R     ",
        "     L.rl          rl.R     ",
        "     L.rl ebbbbbbf rl.R     ",
        "0UUUUh.gh guuyxuuh gh.gUUUU1",
        "L............rl............R",
        "L.ebbf.ebbbf.rl.ebbbf.ebbf.R",
        "L.guyl.guuuh.gh.guuuh.rxuh.R",
        "LP..rl.......  .......rl..PR",
        "6bf.rl.ef.ebbbbbbf.ef.rl.eb8",
        "7uh.gh.rl.guuyxuuh.rl.gh.gu9",
        "L......rl....rl....rl......R",
        "L.ebbbbwzbbf.rl.ebbwzbbbbf.R",
        "L.guuuuuuuuh.gh.guuuuuuuuh.R",
        "L..........................R",
        "2BBBBBBBBBBBBBBBBBBBBBBBBBB3",
    }
    local default_color = palette.COLOR_FRIGHTENED
    local sprite_overrides <const> = {
        ["."] = "tile_10",
    }
    local color_overrides <const> = {
        ["."] = palette.COLOR_DOT,
        P = palette.COLOR_DOT,
        ["-"] = palette.COLOR_PINKY,
    }
    for y = 1, DISPLAY_TILE_Y do
        for x = 1, DISPLAY_TILE_X do
            local sprite
            if y >= 4 and y <= 34 then
                local i = y - 3
                local line = assert(tiles[i])
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
                x = (x - 1) * TILE_PIXEL_SIZE,
                y = (y - 1) * TILE_PIXEL_SIZE,
            })
        end
    end
end

return hud
