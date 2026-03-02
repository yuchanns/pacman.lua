local tiny = require "core.tiny"

local function process(system, e)
    local queue = system.world.state.commands.queue_despawns
    if #queue == 0 then return end
    tiny.remove(system.world, e)
end

return tiny.processingSystem {
    priority = 3,

    filter = tiny.requireAll "actor",

    process = process,

    postWrap = function(system)
        local queue = system.world.state.commands.queue_despawns
        for i = 1, #queue do
            queue[i] = nil
        end
    end
}
