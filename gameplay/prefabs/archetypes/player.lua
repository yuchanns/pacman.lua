local anim8 = require "core.anim8"
local M = {}

function M.new()
    return {
        player = true,
        controllable = true,
        profile = "player",
        position = {
            x = 0,
            y = 0,
            offset_x = 0,
            offset_y = 0,
            scale_x = 1,
            scale_y = 1,
        },
        input = {
            requested_dir = nil,
        },
        direction = {
            current = "left",
            wanted = nil,
        },
        motion = {
            moved = false,
            distance = 0,
            blocked = false,
            allow_cornering = true,
        },
        animation = {
            h = nil,
            v = nil,
        },
        render_item = {
            sprite = nil,
            visible = false,
            color = nil,
        },
    }
end

---@param e table
---@param args table
function M.reset(e, args)
    local position = e.position
    local direction = e.direction
    local motion = e.motion
    local animation = e.animation

    local config = args.config
    local resources = args.resources

    e.render_item = e.render_item and {} or nil
    e.render_item.visible = args.visible
    e.render_item.color = args.color

    position.x = assert(args.x, "missing player x")
    position.y = assert(args.y, "missing player y")
    position.offset_x = args.offset_x or config.tile
    position.offset_y = args.offset_y or config.tile
    position.scale_x = args.scale_x or 1
    position.scale_y = args.scale_y or 1

    direction.current = args.dir or direction.current or "left"
    direction.wanted = nil

    motion.moved = false
    motion.distance = 0
    motion.blocked = false

    if resources then
        local sprites = assert(resources.sprites, "missing sprites")
        animation.h = anim8.newAnimation({
            sprites.pacman,
            sprites.pacman_r_1,
            sprites.pacman_r_2,
            sprites.pacman_r_1,
        }, 1)
        animation.v = anim8.newAnimation({
            sprites.pacman,
            sprites.pacman_d_1,
            sprites.pacman_d_2,
            sprites.pacman_d_1,
        }, 1)
    end
end

return M
