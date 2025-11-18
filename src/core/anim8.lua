local anim8 = {
    _VERSION     = "anim8 v2.3.1",
    _DESCRIPTION = "An animation library adapted for soluna",
    _URL         = "https://github.com/kikito/anim8",
    _LICENSE     = [[
    MIT LICENSE

    Copyright (c) 2011 Enrique García Cota

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  ]]
}

---@type Batch | nil
local BATCH

---@type table<any, true>
local TRACKED = setmetatable({}, { __mode = "k" })

local function track(animation)
    TRACKED[animation] = true
    return animation
end

local function cloneArray(arr)
    local result = {}
    for i = 1, #arr do result[i] = arr[i] end
    return result
end

local function parseInterval(str)
    if type(str) == "number" then return str, str, 1 end
    str = str:gsub("%s", "")
    local min, max = str:match "^(%d+)-(%d+)$"
    assert(min and max, ("Could not parse interval from %q"):format(str))
    min, max = tonumber(min), tonumber(max)
    local step = min <= max and 1 or -1
    return min, max, step
end

local function parseDurations(durations, frameCount)
    local result = {}
    if type(durations) == "number" then
        for i = 1, frameCount do result[i] = durations end
    else
        local min, max, step
        for key, duration in pairs(durations) do
            assert(type(duration) == "number", "duration should be a number, got " .. tostring(duration))
            min, max, step = parseInterval(key)
            for i = min, max, step do result[i] = duration end
        end
    end

    if #result < frameCount then
        error(("durations table length %d should be >= frame count %d"):format(#result, frameCount))
    end

    return result
end

local function parseIntervals(durations)
    local result, time = { 0 }, 0
    for i = 1, #durations do
        time = time + durations[i]
        result[i + 1] = time
    end
    return result, time
end

local function seekFrameIndex(intervals, timer)
    local high, low, i = #intervals - 1, 1, 1

    while (low <= high) do
        i = math.floor((low + high) / 2)
        if timer >= intervals[i + 1] then
            low = i + 1
        elseif timer < intervals[i] then
            high = i - 1
        else
            return i
        end
    end

    return i
end

---@class Animation
---@field frames any[]
---@field durations number | table<string, number>
---@field intervals number[]
---@field totalDuration number
---@field onLoop fun(self: Animation, loops: number)|string
---@field timer number
---@field position number
---@field status "playing" | "paused"
---@field layered boolean
---@field _sourceFrames any[]|nil
local Animation = {}
local Animationmt = { __index = Animation }
local nop = function() end

local function assertFrames(frames)
    assert(type(frames) == "table", "frames should be a table")
    assert(#frames > 0, "frames table should not be empty")
end

local function normalizeFrames(frames)
    assertFrames(frames)

    local first = frames[1]
    if type(first) ~= "table" then
        return cloneArray(frames), #frames, false, 1
    end

    local layerCount = #frames
    assert(layerCount > 0, "layered frames table should not be empty")

    local frameCount = nil
    local normalized = {}

    for layerIndex = 1, layerCount do
        local layerFrames = frames[layerIndex]
        assert(type(layerFrames) == "table", ("layer %d should be a table"):format(layerIndex))

        if frameCount == nil then
            frameCount = #layerFrames
            assert(frameCount > 0, "layered frames must contain at least one frame")
        else
            assert(#layerFrames == frameCount,
                ("layer %d has %d frames; expected %d"):format(layerIndex, #layerFrames, frameCount))
        end

        for frameIndex = 1, frameCount do
            local sprite = layerFrames[frameIndex]
            assert(sprite ~= nil, ("missing sprite for layer %d frame %d"):format(layerIndex, frameIndex))
            local slot = normalized[frameIndex]
            if slot == nil then
                slot = {}
                normalized[frameIndex] = slot
            end
            slot[#slot + 1] = sprite
        end
    end

    return normalized, frameCount, true, layerCount
end

---@param frames any[]
---@param durations number|table<string, number>
---@param onLoop? fun(self: Animation, loops: number)|string
---@return Animation
local function newAnimation(frames, durations, onLoop)
    local processedFrames, frameCount, layered = normalizeFrames(frames)
    local td = type(durations)
    if (td ~= "number" or durations <= 0) and td ~= "table" then
        error("durations must be a positive number or a table. Was " .. tostring(durations))
    end
    onLoop = onLoop or nop
    durations = parseDurations(durations, frameCount)
    local intervals, totalDuration = parseIntervals(durations)
    return track(setmetatable({
            frames        = processedFrames,
            durations     = durations,
            intervals     = intervals,
            totalDuration = totalDuration,
            onLoop        = onLoop,
            timer         = 0,
            position      = 1,
            status        = "playing",
            layered       = layered,
            _sourceFrames = layered and frames or nil,
        },
        Animationmt
    ))
end

function Animation:clone()
    return newAnimation(self._sourceFrames or self.frames, self.durations, self.onLoop)
end

function Animation:release()
    TRACKED[self] = nil
end

local function callLoop(self, loops)
    if loops == 0 then return end
    local f = type(self.onLoop) == "function" and self.onLoop or self[self.onLoop]
    f(self, loops)
end

function Animation:update(dt)
    if self.status ~= "playing" then return end
    self.timer = self.timer + dt
    local loops = math.floor(self.timer / self.totalDuration)
    if loops ~= 0 then
        self.timer = self.timer - self.totalDuration * loops
        callLoop(self, loops)
    end
    self.position = seekFrameIndex(self.intervals, self.timer)
end

function Animation:pause()
    self.status = "paused"
end

function Animation:resume()
    self.status = "playing"
end

function Animation:gotoFrame(position)
    self.position = position
    self.timer = self.intervals[self.position]
end

function Animation:pauseAtEnd()
    self.position = #self.frames
    self.timer = self.totalDuration
    self:pause()
end

function Animation:pauseAtStart()
    self.position = 1
    self.timer = 0
    self:pause()
end

function Animation:getFrame()
    return self.frames[self.position]
end

local function draw(sprite, x, y)
    assert(BATCH, "anim8.init(batch) must be called before drawing")
    BATCH:add(sprite, x or 0, y or 0)
end

function Animation:draw(x, y)
    local sprite = self:getFrame()
    if sprite then
        if self.layered then
            for i = 1, #sprite do
                draw(sprite[i], x, y)
            end
        else
            draw(sprite, x, y)
        end
    end
end

-----------------------------------------------------------

anim8.new = newAnimation

function anim8.unregister(animation)
    TRACKED[animation] = nil
end

function anim8.update(dt)
    if not dt or dt == 0 then
        return
    end
    for animation in pairs(TRACKED) do
        animation:update(dt)
    end
end

---@param batch Batch
function anim8.init(batch)
    BATCH = batch
end

return anim8
