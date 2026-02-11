local map = require "src.gameplay.map"

local M = {
    freeze = {
        ---@type boolean
        ready = false
    },
    actors = {
        pacman = {
            ---@type boolean
            visible = false,
            anim = nil,
            ---@type boolean
            moved = false,
        },
        ghosts = {}
    },
    tick = 0,
}

local KEY_RIGHT <const> = 262
local KEY_LEFT <const> = 263
local KEY_DOWN <const> = 264
local KEY_UP <const> = 265
local KEY_H <const> = 72
local KEY_J <const> = 74
local KEY_K <const> = 75
local KEY_L <const> = 76

function M:key(keycode, state)
    if state == 0 then
        return
    end
    if self.freeze.ready then
        return
    end
    local p = self.actors.pacman
    if not p then
        return
    end
    if keycode == KEY_LEFT or keycode == KEY_H then
        p.want_dir = "left"
    elseif keycode == KEY_RIGHT or keycode == KEY_L then
        p.want_dir = "right"
    elseif keycode == KEY_UP or keycode == KEY_K then
        p.want_dir = "up"
    elseif keycode == KEY_DOWN or keycode == KEY_J then
        p.want_dir = "down"
    end
end

function M:update()
    self.tick = self.tick + 1
    if self.freeze.ready then
        return
    end
    local p = self.actors.pacman
    if not p then
        return
    end
    if not p.visible then
        return
    end

    local wanted = p.want_dir or p.dir
    local allow_cornering = true

    local cx = p.x + map.TILE
    local cy = p.y + map.TILE

    local px, py = p.x, p.y

    local steps = (self.tick % 8 ~= 0) and 2 or 0

    p.moved = false
    for _ = 1, steps do
        if map.can_move(cx, cy, wanted, allow_cornering) then
            p.want_dir = nil
            p.dir = wanted
        end
        if map.can_move(cx, cy, p.dir, allow_cornering) then
            cx, cy = map.move(cx, cy, p.dir, allow_cornering)
            p.moved = true
        else
            break
        end
    end

    if p.moved and p.anim then
        local dist = math.abs(px - cx) + math.abs(py - cy)
        p.anim.h:update(dist / 4)
        p.anim.v:update(dist / 4)
    end

    p.x, p.y = cx - map.TILE, cy - map.TILE
end

return M
