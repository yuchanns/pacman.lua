local tiny = require "core.tiny"

---@type table
local wutil
---@type table
local TILES
---@type integer
local MAP_OFFSET_Y
---@type integer
local DISPLAY_TILE_X
local NUM_DOTS = 0

local function init(_, world)
    wutil = world.util
    local resources = world.resources
    local config = world.config
    NUM_DOTS = config.num_dots
    TILES = resources.tiles
    MAP_OFFSET_Y = config.map_offset_y
    DISPLAY_TILE_X = config.display_tile_x
end

local function update_dots_eaten(state)
    state.num_dots_eaten = state.num_dots_eaten + 1
    if state.num_dots_eaten >= NUM_DOTS then
        state.round_won = true
    elseif state.num_dots_eaten == 70 or state.num_dots_eaten == 170 then
        state.fruit_active = true
    end
end

local function process(system, e)
    local commands = system.world.state.commands
    local queue = commands.queue_player_move
    if #queue == 0 then
        return
    end

    local state = system.world.state
    local map = e.map
    for i = 1, #queue do
        local pos = queue[i]
        queue[i] = nil

        local cx, cy = pos.x + pos.ox, pos.y + pos.oy
        local tx, ty = wutil.pixel_to_tile_pos(cx, cy)

        local line = assert(TILES[ty - MAP_OFFSET_Y + 1])
        local col = tx + 1
        local c = line:sub(col, col)
        -- eat dot or energizer pill?
        if c == "." or c == "P" then
            local tile_index = ty * DISPLAY_TILE_X + tx + 1
            local tile = assert(map.tiles[tile_index],
                "invalid tile pos: " .. tostring(tx) .. ", " .. tostring(ty))
            if tile.sprite then
                tile.sprite = nil
                update_dots_eaten(state)
                if c == "." then
                    state.score = state.score + 1
                else
                    state.score = state.score + 5
                end
                commands.texts {
                    text = tostring(state.score * 10),
                    x = 6,
                    y = 1,
                    align = "right",
                }
            end
        end
        if state.score > state.hiscore then
            state.hiscore = state.score
            commands.texts {
                text = tostring(state.hiscore * 10),
                x = 16,
                y = 1,
                align = "right",
            }
        end
    end
end

return tiny.processingSystem {
    filter = tiny.requireAll "map",

    priority = 5,

    onAddToWorld = init,

    process = process,
}
