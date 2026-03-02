local tiny = require "core.tiny"
local file = require "soluna.file"
local flow = require "core.flow"

local function init(system)
    local states = {}
    for name in file.dir "gameplay/states" do
        if name:match "%.lua$" then
            local state = name:sub(1, -5)
            states[state] = require("gameplay.states." .. state)
        end
    end

    flow.load(states)

    do
        local mt = {
            __index = function(_, k)
                if k == "entity" then
                    local entities = system.entities

                    return assert(#entities == 1 and entities[1],
                        "expected exactly one entity in game state, got " .. tostring(#entities))
                end

                return rawget(system, k)
            end
        }
        setmetatable(system, mt)
    end

    flow.enter(flow.state.init, system)
end

return tiny.system {
    filter = tiny.requireAll "map",

    priority = 1,

    onAddToWorld = init,

    update = flow.update
}
