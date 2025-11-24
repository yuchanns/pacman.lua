local layout = require "soluna.layout"
local util = require "src.core.util"
local hud = require "src.visual.hud"

---@type Batch?
local BATCH

---@type number?
local BASE_WIDTH
---@type number?
local BASE_HEIGHT

---@type number, number, number
local offset_x, offset_y, scale = 0, 0, 1

---@class Layouts : string[]
---@field [string] table
local layouts = { "hud" }
layouts.hud = hud

local doms = util.cache(function(k)
    local filename = "assets/layouts/" .. k .. ".dl"
    return layout.load(filename)
end)

local layout_pos = util.cache(function(k)
    return (layout.calc(doms[k]))
end)

function layouts:resize(w, h)
    for i = 1, #self do
        local name = self[i]
        layout_pos[name] = nil
        local d = doms[name]
        local screen = d["screen"]
        screen.width = w
        screen.height = h
    end
end

local viewport = {}

---@param args Args
local function init(args)
    BATCH = args.batch
    BASE_WIDTH = args.width
    BASE_HEIGHT = args.height
end

---@param args Args
function viewport.init(args)
    hud.init(args)

    init(args)
end

function viewport.draw()
    assert(BATCH, "Batch is not initialized. Call viewport.init() first.")

    BATCH:layer(scale, offset_x, offset_y)
    for i = 1, #layouts do
        local name = layouts[i]
        local pos = layout_pos[name]
        for _idx, obj in ipairs(pos) do
            if obj.region then
                local f = layouts[name][obj.region]
                if type(f) == "function" then
                    f(obj)
                end
            end
        end
    end
    BATCH:layer()
end

function viewport.resize(w, h)
    if not w or not h then
        return
    end
    assert(BASE_WIDTH and BASE_WIDTH, "BASE_WIDTH is not set. Call viewport.init() first.")

    layouts:resize(w, h)
    local border <const> = 20
    w = w - border
    h = h - border
    if w <= 0 or h <= 0 then
        viewport.scale = 1
        viewport.offset_x = 0
        viewport.offset_y = 0
        return
    end
    local ref_w = BASE_WIDTH > 0 and BASE_WIDTH or w
    local ref_h = BASE_HEIGHT > 0 and BASE_HEIGHT or h
    scale = math.min(w / ref_w, h / ref_h)
    if scale <= 0 then
        scale = 1
    end
    offset_x = (1.0 - scale) * (w * 0.5)
    offset_y = (1.0 - scale) * (h * 0.5)
end

return viewport
