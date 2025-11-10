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

return util
