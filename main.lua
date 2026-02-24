require "core.patch" ()
local ltask = require "ltask"
local font = require "soluna.font"
local datalist = require "soluna.datalist"
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

local cfg = datalist.parse(assert(file.load "assets/config.dl"))
local map_rows = #cfg.map.tiles
local map_cols = #cfg.map.tiles[1]
local TPS = cfg.timing.tps
local TICK = 1 / TPS

do
    local world = tiny.world()
    local commands = {}

    do
        local mt = {
            __index = function(_, k)
                error("unknown key: " .. tostring(k))
            end
        }
        setmetatable(world, mt)
        world.resources = setmetatable({
            batch = args.batch,
            sprites = soluna.load_sprites "assets/sprites.dl",
            tiles = cfg.map.tiles,
        }, mt)

        local display_x = cfg.display.x
        local display_y = cfg.display.y
        local tile = cfg.display.tile

        world.config = setmetatable({
            base_width = display_x * tile,
            base_height = display_y * tile,

            display_tile_x = display_x,
            display_tile_y = display_y,
            tile = tile,

            width = args.width,
            height = args.height,

            tps = TPS,
            colors = cfg.colors,
            map_offset_y = cfg.map.display_offset_y,
            map_rows = map_rows,
            map_cols = map_cols,
        }, mt)

        world.state = setmetatable({
            freeze = false,
            commands = commands,
        }, mt)
    end

    do
        local mt = {}
        mt.__index = function(_, k)
            if k:sub(1, 6) == "queue_" then
                return {}
            end
            return function(...)
                local queue = "queue_" .. k
                local q = rawget(commands, queue) or {}
                q[#q + 1] = ...
                commands[queue] = q
            end
        end
        setmetatable(commands, mt)
    end

    tiny_add = function(...)
        tiny.add(world, ...)
    end

    tiny_update = function(dt, system_type)
        tiny.update(world, dt, function(_, system)
            return system.type == system_type
        end)
    end

    callback_key = function(keycode, key_state)
        commands.input {
            keycode = keycode,
            key_state = key_state,
        }
    end

    callback_resize = function(w, h)
        commands.resize {
            width = w,
            height = h,
        }
    end

    callback_resize(args.width, args.height)
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
    local dirs = {
        "gameplay",
        "render",
    }
    for i = 1, #dirs do
        local dir = assert(dirs[i])
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
            system.type = dir
            tiny_add(system)
        end
    end
end

return {
    window_resize = callback_resize,
    key = callback_key,
    frame = callback_frame,
}
