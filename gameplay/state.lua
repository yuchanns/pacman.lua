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

    function states.idle(args)
        print "idle"

        flow.sleep(58)
        return flow.state.idle, args
    end

    flow.load(states)

    flow.enter(flow.state.init, system)
end

return tiny.system {
    filter = tiny.requireAll("map"),

    priority = 1,

    onAddToWorld = init,

    update = flow.update
}
