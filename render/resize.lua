local tiny = require "core.tiny"

local border <const> = 20

---@type number, number, number
local offset_x, offset_y, scale = 0, 0, 1

local function update(system)
    local resize = assert(system.world.state.resize)

    local config = assert(system.world.config)
    for i = 1, #resize do
        local ev = assert(resize[i])
        resize[i] = nil
        local w, h = ev.width, ev.height
        if w and h then
            config.width = w
            config.height = h
        end
    end

    local w, h = config.width, config.height
    w = w - border
    h = h - border
    if w <= 0 or h <= 0 then
        scale = 1
        offset_x = 0
        offset_y = 0
        return
    end
    local bw = assert(config.base_width)
    local bh = assert(config.base_height)
    scale = math.min(w / bw, h / bh)
    if scale <= 0 then
        scale = 1
    end
    offset_x = (1.0 - scale) * (w * 0.5)
    offset_y = (1.0 - scale) * (h * 0.5)
end

local function preWrap(self)
    local batch = assert(self.world.resources.batch)
    batch:layer(scale, offset_x, offset_y)
end

local function postWrap(self)
    local batch = assert(self.world.resources.batch)
    batch:layer()
end

return tiny.system {
    priority = 999,

    preWrap = preWrap,
    postWrap = postWrap,

    update = update
}
