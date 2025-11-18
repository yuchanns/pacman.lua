local ltask = require "ltask"
local soluna = require "soluna"
local layout = require "soluna.layout"
local util = require "src.core.util"
local flow = require "src.core.flow"
local anim8 = require "src.core.anim8"

local SPRITES = soluna.load_sprites "assets/sprites.dl"

local TICK = 1 / 60
local MAX_DT = 0.25
local DISPLAY_TILE_X <const> = 28
local DISPLAY_TILE_Y <const> = 36

local last_cs
local accumulator = 0.0

---@type Callback
local callback = {}

---@type Args
local args = ...
local BATCH = args.batch
local BASE_WIDTH <const> = args.width
local BASE_HEIGHT <const> = args.height

anim8.init(BATCH)

local viewport = {
    ---@type number
    scale = 1,
    ---@type number
    offset_x = 0,
    ---@type number
    offset_y = 0,
}

---@param f fun()
---@return fun()
function viewport:draw(f)
    return function()
        BATCH:layer(self.scale, self.offset_x, self.offset_y)
        f()
        BATCH:layer()
    end
end

function viewport:resize(w, h)
    if not w or not h then
        return
    end
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
    ---@type number
    local scale = math.min(w / ref_w, h / ref_h)
    if scale <= 0 then
        scale = 1
    end
    self.scale = scale
    self.offset_x = (1.0 - scale) * (w * 0.5)
    self.offset_y = (1.0 - scale) * (h * 0.5)
end

local blinky = anim8.new({
    SPRITES.blinky_anime_r_1,
    SPRITES.blinky_anime_r_2,
    SPRITES.blinky_anime_d_1,
    SPRITES.blinky_anime_d_2,
    SPRITES.blinky_anime_l_1,
    SPRITES.blinky_anime_l_2,
    SPRITES.blinky_anime_u_1,
    SPRITES.blinky_anime_u_2,
}, 0.12)

local doms = util.cache(function(k)
    local filename = "assets/layouts/" .. k .. ".dl"
    return layout.load(filename)
end)

local layout_pos = util.cache(function(k)
    return (layout.calc(doms[k]))
end)

local hud = {
    tiles = {}
}

local function game_init_playfield()
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
    for y = 1, DISPLAY_TILE_Y do
        for x = 1, DISPLAY_TILE_X do
            local sprite
            if y >= 4 and y <= 34 then
                local i = y - 3
                local line = assert(tiles[i])
                local c = line:sub(x, x)
                if c == "." then
                    sprite = SPRITES.tile_10
                elseif c ~= "" then
                    sprite = SPRITES["tile_" .. c]
                end
            end
            table.insert(hud.tiles, {
                sprite = sprite,
                x = (x - 1) * 16,
                y = (y - 1) * 16,
            })
        end
    end
end

-- see @assets/layouts/hud.dl > region : map
function hud.map(self)
    BATCH:layer(self.x, self.y)
    -- in the middle of the map, draw blinky animation
    blinky:draw((13 * 16), (16 * 16))
    for _idx, tile in ipairs(hud.tiles) do
        if tile.sprite then
            BATCH:add(tile.sprite, tile.x, tile.y)
        end
    end
    BATCH:layer()
end

---@type table<string, table> & string[]
local layouts = { "hud" }
layouts.hud = hud

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

viewport:resize(BASE_WIDTH, BASE_HEIGHT)
layouts:resize(BASE_WIDTH, BASE_HEIGHT)

local draw = viewport:draw(function()
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
end)

local game = {}

function game.init()
    viewport:resize(BASE_WIDTH, BASE_HEIGHT)
    layouts:resize(BASE_WIDTH, BASE_HEIGHT)

    game_init_playfield()

    return flow.state.idle
end

function game.idle()
    print "idle"

    flow.sleep(58)

    return flow.state.idle
end

flow.load(game)

flow.enter(flow.state.init)

---@type fun(tick: number)
local game_tick; do
    function game_tick(tick)
        flow.update()

        anim8.update(tick)
    end
end

function callback.frame(_count)
    local _, now_cs = ltask.now()
    if not last_cs then
        last_cs = now_cs
    end

    local dt = (now_cs - last_cs) / 100.0
    last_cs = now_cs

    if dt > MAX_DT then
        dt = MAX_DT
    end
    accumulator = accumulator + dt
    while accumulator >= TICK do
        game_tick(TICK)
        accumulator = accumulator - TICK
    end

    draw()
end

function callback.window_resize(w, h)
    viewport:resize(w, h)
    layouts:resize(w, h)

    draw()
end

return callback
