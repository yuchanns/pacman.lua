local ltask = require "ltask"
local soluna = require "soluna"

local SPRITES = soluna.load_sprites "assets/sprites.dl"

local TICK = 1 / 60
local MAX_DT = 0.25

local last_cs
local accumulator = 0.0

---@type Callback
local callback = {}

---@type Args
local args = ...
local BATCH = args.batch

local blinky_anim8 = {
    ---@type table<number, number|userdata|string|nil>
    frames = {
        SPRITES.blinky_anime_r_1,
        SPRITES.blinky_anime_r_2,
        SPRITES.blinky_anime_d_1,
        SPRITES.blinky_anime_d_2,
        SPRITES.blinky_anime_l_1,
        SPRITES.blinky_anime_l_2,
        SPRITES.blinky_anime_u_1,
        SPRITES.blinky_anime_u_2,
    },
    frame_index = 1,
    timer = 0.0,
    frame_duration = 0.12,
}

function blinky_anim8:update(dt)
    self.timer = self.timer + dt
    while self.timer >= self.frame_duration do
        self.timer = self.timer - self.frame_duration
        self.frame_index = self.frame_index + 1
        if self.frame_index > #self.frames then
            self.frame_index = 1
        end
    end
end

---@type fun(tick: number)
local game_tick; do
    local tick_count = 0
    local elapsed = 0.0
    function game_tick(tick)
        tick_count = tick_count + 1
        elapsed = elapsed + tick

        blinky_anim8:update(tick)

        if tick_count % 60 == 0 then
            print(string.format("ticks=%d, elapsed=%.2f", tick_count, elapsed))
        end
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

    -- render
    local current_frame = assert(blinky_anim8.frames[blinky_anim8.frame_index])
    BATCH:add(current_frame, 0, 0)
end

return callback
