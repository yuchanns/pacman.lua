local util = {}

---@generic K, V
---@param f fun(key: K): V
---@return table<K, V>
function util.cache(f)
    local meta
    if type(f) == "function" then
        meta = {}
        ---@param self table
        ---@param k any
        meta.__index = function(self, k)
            local v = f(k)
            self[k] = v
            return v
        end
    else
        meta = getmetatable(f)
    end

    return setmetatable({}, meta)
end

---@generic K, V
---@param value any
---@param seen table<K, V> | nil
local function deepcopy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    local cached = seen[value]
    if cached then
        return cached
    end
    local copied = {}
    seen[value] = copied
    for k, v in pairs(value) do
        copied[deepcopy(k, seen)] = deepcopy(v, seen)
    end
    return copied
end

util.deepcopy = deepcopy

return util
