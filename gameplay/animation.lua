local tiny = require "core.tiny"

local DT_PER_PIXEL = 0.0

local function init(_, world)
    local tile = world.config.tile
    DT_PER_PIXEL = 4 / tile
end

local function process(system, e)
    if not e.visible or not e.actor.anim then
        return
    end
    local state = system.world.state
    local anims = e.actor.anim
    local distance = e.actor.distance or 0
    local cd = e.actor.dir
    if not cd then
        return
    end

    if not e.sprite then
        e.sprite = {}
    end

    for idx, anim in ipairs(anims) do
        local dirs = anim.dirs or {}

        for k, v in pairs(dirs) do
            if k ~= cd then
                v.animation:pause()
            end
        end

        local active = assert(dirs[cd], "invalid direction for animation: " .. cd)
        if state.freeze then
            active.animation:pause()
        else
            active.animation:resume()
        end
        if (not state.freeze) and distance > 0 then
            active.animation:update(distance * DT_PER_PIXEL)
        end

        local pos = active.animation.position

        e.sprite[idx] = {
            sprite = active.animation.frames[pos],
            color = anim.color,
            sx = active.sx,
            sy = active.sy,
        }
    end
end

return tiny.processingSystem {
    filter = tiny.requireAll "actor",
    priority = 5,

    onAddToWorld = init,

    process = process,
}
