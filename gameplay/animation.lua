local tiny = require "core.tiny"

local function process(system, e)
    if not e.visible or not e.actor.anim then
        return
    end
    local state = system.world.state
    local anims = e.actor.anim
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
        if state.freeze or e.blocked then
            active.animation:pauseAtStart()
        else
            active.animation:resume()
        end
        active.animation:update(1 / 4)

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

    process = process,
}
