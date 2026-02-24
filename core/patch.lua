local datalist = require "soluna.datalist"
local datalist_parse = datalist.parse

local function get_by_path(root, path)
    local node = root
    for part in path:gmatch "[^.]+" do
        if type(node) ~= "table" then
            error("invalid datalist reference: $(" .. path .. ")")
        end
        local key = tonumber(part) or part
        node = node[key]
        if node == nil then
            error("unknown datalist reference: $(" .. path .. ")")
        end
    end
    return node
end

local function parse(root)
    root = datalist_parse(root)
    assert(type(root) == "table", "datalist root must be a table")

    local visiting_paths = {}

    local resolve_value

    local function resolve_path(path, seen)
        assert(not visiting_paths[path], "cyclic datalist reference: $(" .. path .. ")")
        visiting_paths[path] = true
        local target = get_by_path(root, path)
        local resolved = resolve_value(target, seen)
        visiting_paths[path] = nil
        return resolved
    end

    local function resolve_string(text, seen)
        local whole = text:match "^%$%(([^()]+)%)$"
        if whole then
            return resolve_path(whole, seen)
        end

        return (text:gsub("%$%(([^()]+)%)", function(path)
            local value = resolve_path(path, seen)
            assert(type(value) ~= "table", "cannot interpolate table reference into string: $(" .. path .. ")")
            return tostring(value)
        end))
    end

    resolve_value = function(value, seen)
        local value_type = type(value)
        if value_type == "string" then
            return resolve_string(value, seen)
        end
        if value_type ~= "table" then
            return value
        end

        local cached = seen[value]
        if cached then
            return cached
        end

        local resolved = {}
        seen[value] = resolved
        for k, v in pairs(value) do
            resolved[k] = resolve_value(v, seen)
        end
        return resolved
    end

    return resolve_value(root, {})
end

return function()
    datalist.parse = parse
end
