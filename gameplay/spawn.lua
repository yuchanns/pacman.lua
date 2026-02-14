local tiny = require "core.tiny"
local file = require "soluna.file"

local prefabs = {}

local function init()
    for name in file.dir "gameplay/prefabs" do
        if name:match "%.lua$" then
            local kind = name:sub(1, -5)
            local prefab = require("gameplay.prefabs." .. kind)
            assert(prefab.new and prefab.reset, "prefab must have new and reset methods: " .. kind)
            prefabs[kind] = prefab
        end
    end
end

local function process(system, e)
    local spawns = e.spawns
    local world = system.world

    for i = 1, #spawns do
        local spawn = assert(spawns[i])
        spawns[i] = nil
        local kind, args = spawn.kind, spawn.args
        local prefab = assert(prefabs[kind], "prefab not found: " .. tostring(kind))
        local ent = prefab.new()
        prefab.reset(ent, args or {})

        tiny.add(world, ent)
    end
end

return tiny.processingSystem {
    filter = tiny.requireAll "spawns",
    priority = 3,

    onAddToWorld = init(),

    process = process,
}
