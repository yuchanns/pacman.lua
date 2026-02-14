local ltask = require "ltask"
local font = require "soluna.font"
local file = require "soluna.file"
local tiny = require "core.tiny"
local soluna = require "soluna"

local args = ...

font.import(assert(file.load "assets/fonts/pacman.ttf"))


-- Local version of the functions
local tiny_add
local tiny_update

local callback_resize
local callback_key
local callback_frame

local TPS = 60
local TICK = 1 / TPS

do
    local world = tiny.world()

    world.resources = {
        batch = args.batch,
        sprites = soluna.load_sprites "assets/sprites.dl",
        tiles = {
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
        },
    }

    local display_x = 28
    local display_y = 36
    local tile = 16

    world.config = {
        base_width = display_x * tile,
        base_height = display_y * tile,

        display_tile_x = display_x,
        display_tile_y = display_y,
        tile = tile,

        width = args.width,
        height = args.height,

        tps = TPS,
    }

    world.state = {
        keys = {},
        resize = {},
        freeze = false,
    }

    tiny_add = function(...)
        tiny.add(world, ...)
    end

    tiny_update = function(dt, system_type)
        tiny.update(world, dt, function(_, system)
            return system.system_type == system_type
        end)
    end

    callback_key = function(keycode, key_state)
        local keys = world.state.keys
        keys[#keys + 1] = {
            keycode = keycode,
            key_state = key_state,
        }
    end

    callback_resize = function(w, h)
        local resize = world.state.resize
        resize[#resize + 1] = {
            width = w,
            height = h,
        }
    end
end


do
    local max_dt <const> = 0.25
    local ltask_t
    local accumulator = 0.0

    tiny_add {
        map = {
            tiles = {},
            status = nil,
        },
        texts = {},
        spawns = {},
    }

    callback_frame = function()
        local now_t = ltask.counter()
        if not ltask_t then
            ltask_t = now_t
        end

        local dt = now_t - ltask_t
        ltask_t = now_t

        if dt > max_dt then
            dt = max_dt
        end
        accumulator = accumulator + dt

        while accumulator >= TICK do
            tiny_update(TICK, "gameplay")
            accumulator = accumulator - TICK
        end

        tiny_update(dt, "render")
    end
end

do
    local system_type = {
        "gameplay",
        "render",
    }
    for i = 1, #system_type do
        local dir = assert(system_type[i])
        local systems = {}
        for name in file.dir(dir) do
            if name:match "%.lua$" then
                systems[#systems + 1] = require(dir .. "." .. name:sub(1, -5))
            end
        end
        table.sort(systems, function(a, b)
            return (a.priority or 0) < (b.priority or 0)
        end)
        for j = 1, #systems do
            local system = assert(systems[j])
            system.system_type = dir
            tiny_add(system)
        end
    end
end

return {
    window_resize = callback_resize,
    key = callback_key,
    frame = callback_frame,
}
