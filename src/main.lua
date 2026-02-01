local ltask = require "ltask"
local soluna = require "soluna"
local font = require "soluna.font"
local file = require "soluna.file"
local flow = require "src.core.flow"
local anim8 = require "src.core.anim8"
local viewport = require "src.visual.viewport"
local game_state = require "src.gameplay.state"

local SPRITES = soluna.load_sprites "assets/sprites.dl"

local function init_font()
    local data = assert(file.load "assets/fonts/pacman.ttf")
    font.import(data)
end

init_font()

local TICKS_PER_SECOND <const> = 60
local TICK <const> = 1 / TICKS_PER_SECOND
local MAX_DT <const> = 0.25

local last_t
local accumulator = 0.0

---@type Callback
local callback = {}

---@type Args
local args = ...
local BATCH <const> = args.batch
local BASE_WIDTH <const> = args.width
local BASE_HEIGHT <const> = args.height

anim8.init(BATCH)

viewport.init {
    batch = BATCH,
    sprites = SPRITES,
    width = BASE_WIDTH,
    height = BASE_HEIGHT,
}

local function game_start()
    local game = {}

    local states = {
        "init",
        "round_init"
    }

    for i = 1, #states do
        local state = states[i]
        game[state] = require("src.gameplay." .. state)
    end

    function game.idle()
        print "idle"

        flow.sleep(58)

        return flow.state.idle
    end

    flow.load(game)

    flow.enter(flow.state.init, {
        w = BASE_WIDTH,
        h = BASE_HEIGHT,
        tps = TICKS_PER_SECOND,
    })
end

game_start()

---@type fun(tick: number)
local game_tick; do
    function game_tick(_tick)
        flow.update()

        game_state:update()
    end
end

function callback.frame(_count)
    local now_t = ltask.counter()
    if not last_t then
        last_t = now_t
    end

    local dt = now_t - last_t
    last_t = now_t

    if dt > MAX_DT then
        dt = MAX_DT
    end
    accumulator = accumulator + dt
    while accumulator >= TICK do
        game_tick(TICK)
        accumulator = accumulator - TICK
    end
    anim8.update(dt)

    viewport.draw()
end

function callback.window_resize(w, h)
    viewport.resize(w, h)

    viewport.draw()
end

function callback.key(keycode, state)
    game_state:key(keycode, state)
end

return callback
