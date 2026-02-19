local tiny = require "core.tiny"

local tick = 0

---@type number, number, number , number
local TILE, HALF_TILE, DISPLAY_PIXELS_X, DISPLAY_PIXELS_Y
local MAP_MIN_X, MAP_MAX_X, MAP_MIN_Y, MAP_MAX_Y

local TILES = {}

local function dir_to_vec(dir)
    if dir == "right" then return 1, 0 end
    if dir == "down" then return 0, 1 end
    if dir == "left" then return -1, 0 end
    if dir == "up" then return 0, -1 end
    return 0, 0
end

local function dist_to_tile_mid(cx, cy)
    local dx = HALF_TILE - (cx % TILE)
    local dy = HALF_TILE - (cy % TILE)
    return dx, dy
end

local function pixel_to_tile_pos(cx, cy)
    local tx = math.floor(cx / TILE)
    local ty = math.floor(cy / TILE)
    return tx, ty
end

local function clamp_tile_pos(tx, ty)
    if tx < MAP_MIN_X then tx = MAP_MIN_X elseif tx > MAP_MAX_X then tx = MAP_MAX_X end
    if ty < MAP_MIN_Y then ty = MAP_MIN_Y elseif ty > MAP_MAX_Y then ty = MAP_MAX_Y end
    return tx, ty
end

local function tile_char_at(tx, ty)
    tx, ty = clamp_tile_pos(tx, ty)
    local row = ty - 2
    local col = tx + 1
    local line = TILES[row]
    return line:sub(col, col)
end

local function is_blocking(tx, ty)
    local c = tile_char_at(tx, ty)
    return not (c == "." or c == "P" or c == " ")
end

local function can_move(cx, cy, wanted_dir, allow_cornering)
    local vx, vy = dir_to_vec(wanted_dir)
    local distx, disty = dist_to_tile_mid(cx, cy)

    local move_dist_mid, perp_dist_mid
    if vy ~= 0 then
        move_dist_mid = disty
        perp_dist_mid = distx
    else
        move_dist_mid = distx
        perp_dist_mid = disty
    end

    local tx, ty = pixel_to_tile_pos(cx, cy)
    local check_tx, check_ty = clamp_tile_pos(tx + vx, ty + vy)
    local blocked = is_blocking(check_tx, check_ty)

    if ((not allow_cornering) and (perp_dist_mid ~= 0)) or (blocked and (move_dist_mid == 0)) then
        return false
    end
    return true
end

local function move(cx, cy, dir, allow_cornering)
    local vx, vy = dir_to_vec(dir)
    cx = cx + vx
    cy = cy + vy

    if allow_cornering then
        local distx, disty = dist_to_tile_mid(cx, cy)
        if vx ~= 0 then
            if disty < 0 then
                cy = cy - 1
            elseif disty > 0 then
                cy = cy + 1
            end
        elseif vy ~= 0 then
            if distx < 0 then
                cx = cx - 1
            elseif distx > 0 then
                cx = cx + 1
            end
        end
    end

    if cx < 0 then
        cx = DISPLAY_PIXELS_X - 1
    elseif cx >= DISPLAY_PIXELS_X then
        cx = 0
    end

    return cx, cy
end

local function process(system, e)
    local state = system.world.state
    if state.freeze or e.state == "house" then
        return
    end

    if not e.visible then
        return
    end

    local actor = e.actor

    local cd = actor.dir
    if not cd then
        return
    end

    if e.input then
        local requested_dir = e.input.requested_dir
        if requested_dir then
            e.wanted = requested_dir
            e.input.requested_dir = nil
        end
    end

    local pos = actor.pos

    local wanted_dir = e.wanted or cd
    local allow_cornering = actor.allow_cornering or false

    local cx = pos.x + pos.ox
    local cy = pos.y + pos.oy

    local steps = (tick % 8 ~= 0) and 2 or 0

    for _ = 1, steps do
        if can_move(cx, cy, wanted_dir, allow_cornering) then
            e.wanted = nil
            actor.dir = wanted_dir
        end

        if can_move(cx, cy, actor.dir, allow_cornering) then
            cx, cy = move(cx, cy, actor.dir, allow_cornering)
        else
            break
        end
    end

    e.blocked = not can_move(cx, cy, actor.dir, allow_cornering)

    pos.x = cx - pos.ox
    pos.y = cy - pos.oy
end

local function init(_, world)
    local config = assert(world.config)
    local resources = assert(world.resources)

    TILE = config.tile
    HALF_TILE = TILE / 2
    DISPLAY_PIXELS_X = config.display_tile_x * TILE
    DISPLAY_PIXELS_Y = config.display_tile_y * TILE

    MAP_MIN_X = 0
    MAP_MAX_X = assert(config.map_cols) - 1
    MAP_MIN_Y = assert(config.map_offset_y)
    MAP_MAX_Y = MAP_MIN_Y + assert(config.map_rows) - 1

    TILES = resources.tiles
end

local function preWrap()
    tick = tick + 1
end

return tiny.processingSystem {
    filter = tiny.requireAll "actor",
    priority = 4,

    onAddToWorld = init,

    preWrap = preWrap,

    process = process,
}
