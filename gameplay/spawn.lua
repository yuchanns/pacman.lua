local tiny = require "core.tiny"
local anim8 = require "core.anim8"
local file = require "soluna.file"
local datalist = require "soluna.datalist"
local util = require "core.util"

local profiles = {}
---@type SpriteBundle
local sprites

local function init(_, world)
    profiles = datalist.parse(assert(file.load "assets/profiles.dl"))
    profiles["templates"] = nil

    setmetatable(profiles, {
        __index = function(_, kind)
            error("unknown spawn kind: " .. tostring(kind))
        end
    })

    sprites = assert(world.resources.sprites)
end

local animation = util.cache(function(duration)
    return util.cache(function(source_frames)
        local frames = {}
        for j = 1, #source_frames do
            local frame = source_frames[j]
            frames[j] = assert(sprites[frame], "unknown sprite: " .. tostring(frame))
        end
        return anim8.newAnimation(frames, duration)
    end)
end)

local function update(system)
    local queue = system.world.state.commands.queue_spawns
    if #queue == 0 then return end
    local world = system.world

    for i = 1, #queue do
        local spawn = assert(queue[i])
        queue[i] = nil
        local kind, args = spawn.kind, spawn.args
        local profile = util.deepcopy(profiles[kind])
        for k, v in pairs(args) do
            profile[k] = v
        end

        assert(profile.actor, "spawn kind missing actor: " .. tostring(kind))

        for _, anim in ipairs(profile.actor.anim or {}) do
            local duration = anim.duration or 1
            local dirs = anim.dirs or {}
            for dir, data in pairs(dirs) do
                dirs[dir] = {
                    animation = animation[duration][data.frames],
                    sx = data.sx or 1,
                    sy = data.sy or 1,
                }
            end
        end

        tiny.add(world, profile)
    end
end

return tiny.system {
    priority = 3,

    onAddToWorld = init,

    update = update,
}
