local tiny = require "core.tiny"
local util = require "core.util"
local layout = require "soluna.layout"

local layouts = { "hud" }

local dom = util.cache(function(k)
    local filename = "assets/layouts/" .. k .. ".dl"
    return layout.load(filename)
end)

local pos = util.cache(function(k)
    return (layout.calc(dom[k]))
end)

local function region(name)
    for i = 1, #layouts do
        local p = pos[layouts[i]]
        for _, obj in ipairs(p) do
            if obj.region == name then
                return obj
            end
        end
    end
end

local function preWrap(system)
    local batch = system.world.resources.batch
    local config = system.world.config

    for i = 1, #layouts do
        local name = layouts[i]
        pos[name] = nil
        local d = dom[name]
        local screen = d["screen"]
        screen.width = config.width
        screen.height = config.height
    end

    local world = assert(region "world")

    batch:layer(world.x, world.y)
end

local function postWrap(system)
    local batch = system.world.resources.batch
    batch:layer()
end

local function process(system, e)
    local batch = system.world.resources.batch

    for _, tile in ipairs(e.map.tiles) do
        if tile.sprite then
            batch:add(tile.sprite, tile.x, tile.y)
        end
    end
end

return tiny.processingSystem {
    filter = tiny.requireAll "map",

    priority = 1,

    preWrap = preWrap,
    postWrap = postWrap,

    process = process,
}
