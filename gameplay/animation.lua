local tiny = require "core.tiny"

local function process(system, e)
    local render_item = e.render_item
    if not render_item.visible then
        return
    end
    local state = system.world.state
    local animation = e.animation
    local position = e.position
    local motion = e.motion
    local cd = e.direction.current
    if not cd then
        return
    end

    local active = (cd == "up" or cd == "down") and animation.v or animation.h
    local other = (active == animation.h) and animation.v or animation.h

    other:pause()

    if state.freeze then
        active:pause()
    elseif motion.blocked then
        active:pauseAtStart()
    elseif not motion.moved then
        active:pause()
    else
        active:resume()
        local dist = motion.distance or 0
        if dist > 0 then
            active:update(dist / 4)
        end
    end

    render_item.sprite = active.frames[active.position]
    position.scale_x = cd == "left" and -1 or 1
    position.scale_y = cd == "up" and -1 or 1
end

return tiny.processingSystem {
    filter = tiny.requireAll("animation", "direction", "motion", "render_item"),
    priority = 5,

    process = process,
}
