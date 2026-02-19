local tiny = require "core.tiny"

local function process(system, e)
    if not e.visible or not e.actor.anim then
        return
    end
    local state = system.world.state
    local anims = e.actor.anim
    local position = e.actor.pos
    local cd = e.actor.dir
    if not cd then
        return
    end

    position.sx = cd == "left" and -1 or 1
    position.sy = cd == "up" and -1 or 1

    for idx, anim in ipairs(anims) do
        local active = (cd == "up" or cd == "down") and anim.v or anim.h
        local other = (active == anim.h) and anim.v or anim.h

        other:pause()

        if state.freeze or e.blocked then
            active:pauseAtStart()
        else
            active:resume()
        end
        active:update(1 / 4)

        if not e.sprite then
            e.sprite = {}
        end

        local sx, sy

        if anim.dir then
            sx = anim.dir == "left" and -1 or 1 
            sy = anim.dir == "up" and -1 or 1
        end

        e.sprite[idx] = {
            sprite = active.frames[active.position],
            color = anim.color,
            sx = sx,
            sy = sy,
        }
    end
end

return tiny.processingSystem {
    filter = tiny.requireAll "actor",
    priority = 5,

    process = process,
}
