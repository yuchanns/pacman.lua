local tiny = require "core.tiny"
local util = require "core.util"
local mattext = require "soluna.material.text"
local font = require "soluna.font"

---@type table<integer, fun(string, integer, integer): userdata>
local TEXT
local DEFAULT_TEXT_COLOR

local function init(system)
    local config = assert(system.world.config)
    local colors = assert(config.colors)
    local font_id = assert(font.name "Pacman Tiles")
    DEFAULT_TEXT_COLOR = assert(colors.COLOR_DEFAULT)

    TEXT = util.cache(function(color)
        local block = mattext.block(font.cobj(), font_id, config.tile, color, "LT")
        return block
    end)
end

local function process(system, e)
    local texts = e.texts
    local tiles = e.map.tiles
    local config = assert(system.world.config)

    for i = 1, #texts do
        local text = assert(texts[i])
        texts[i] = nil

        local x, y = assert(text.x), assert(text.y)
        local color = text.color or DEFAULT_TEXT_COLOR
        local block = TEXT[color]
        tiles[y * config.display_tile_x + x + 1].sprite = block(text.text, #text.text * config.tile, config.tile)
    end
end

return tiny.processingSystem {
    filter = tiny.requireAll("texts", "map"),

    priority = 3,

    onAddToWorld = init,

    process = process,
}
