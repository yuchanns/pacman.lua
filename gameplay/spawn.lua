local tiny = require "core.tiny"
local file = require "soluna.file"
local datalist = require "soluna.datalist"
local anim8 = require "core.anim8"

local profiles = {}

local function init()
    profiles = datalist.parse(assert(file.load "assets/profiles.dl"))
end

local function update(system)
    local queue = system.world.state.commands.queue_spawns
    if #queue == 0 then return end
    local world = system.world
    local sprites = world.resources.sprites

    for i = 1, #queue do
        local spawn = assert(queue[i])
        queue[i] = nil
        local kind, args = spawn.kind, spawn.args
        local profile = assert(profiles[kind], "unknown spawn kind: " .. tostring(kind))
        for k, v in pairs(args) do
            profile[k] = v
        end
        local anims = profile.actor.anim or {}
        for _, anim in ipairs(anims) do
            local duration = anim.duration or 1
            local hframes = anim.h
            local vframes = anim.v
            do
                local frames = {}
                for j = 1, #hframes do
                    frames[#frames + 1] = assert(sprites[hframes[j]])
                end
                anim.h = anim8.newAnimation(frames, duration)
            end
            do
                local frames = {}
                for j = 1, #vframes do
                    frames[#frames + 1] = assert(sprites[vframes[j]])
                end
                anim.v = anim8.newAnimation(frames, duration)
            end
        end

        tiny.add(world, profile)
    end
end

return tiny.system {
    priority = 3,

    onAddToWorld = init(),

    update = update,
}
