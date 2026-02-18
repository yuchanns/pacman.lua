local tiny = require "core.tiny"

local function process(system, e)
    if not e.visible or not e.actor.anim then
        return
    end
    local state = system.world.state
    local anims = e.actor.anim
    local position = e.actor.pos
    local motion = e.motion or {}
    local cd = e.actor.dir
    if not cd then
        return
    end

    position.sx = cd == "left" and -1 or 1
    position.sy = cd == "up" and -1 or 1
    local dist = motion.distance or 0

    for idx, anim in ipairs(anims) do
        local active = (cd == "up" or cd == "down") and anim.v or anim.h
        local other = (active == anim.h) and anim.v or anim.h

        other:pause()

        if state.freeze then
            active:pause()
        elseif motion.blocked then
            active:pauseAtStart()
        elseif not motion.moved then
            active:pause()
        else
            active:resume()
            if dist > 0 then
                active:update(dist / 4)
            end
        end

        if not e.sprite then
            e.sprite = {}
        end

        e.sprite[idx] = {
            sprite = active.frames[active.position],
            color = anim.color,
        }
    end
end

return tiny.processingSystem {
    filter = tiny.requireAll "actor",
    priority = 5,

    process = process,
}
