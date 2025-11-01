---@type Callback
local callback = {}

---@type Args
local _args = ...

function callback.frame(count)
    count = count or 0
    print("Frame count: " .. count)
end

return callback
