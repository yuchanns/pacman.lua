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

---@generic T
---@param list T[]
---@param match (fun(v: T): boolean) | string
---@param what string?
---@return T
function util.ensure_only(list, match, what)
    assert(type(list) == "table", "list must be a table")
    if what == nil then
        what = type(match) == "string" and match or "<predicate>"
    end
    assert(type(what) == "string" and what ~= "", "what must be a non-empty string")

    local fn
    if type(match) == "string" then
        local key = match
        fn = function(v)
            return v ~= nil and v[key] ~= nil
        end
    else
        assert(type(match) == "function", "match must be a function or a string")
        fn = match
    end

    local hit
    local count = 0
    for i = 1, #list do
        local v = list[i]
        if fn(v) then
            hit = hit or v
            count = count + 1
        end
    end

    assert(count == 1, "expected exactly one entity with " .. what .. ", found " .. count)
    return hit
end

return util
