local M = {}

local tiles <const> = {
    "0UUUUUUUUUUUU45UUUUUUUUUUUU1",
    "L............rl............R",
    "L.ebbf.ebbbf.rl.ebbbf.ebbf.R",
    "LPr  l.r   l.rl.r   l.r  lPR",
    "L.guuh.guuuh.gh.guuuh.guuh.R",
    "L..........................R",
    "L.ebbf.ef.ebbbbbbf.ef.ebbf.R",
    "L.guuh.rl.guuyxuuh.rl.guuh.R",
    "L......rl....rl....rl......R",
    "2BBBBf.rzbbf rl ebbwl.eBBBB3",
    "     L.rxuuh gh guuyl.R     ",
    "     L.rl          rl.R     ",
    "     L.rl mjs--tjn rl.R     ",
    "UUUUUh.gh i      q gh.gUUUUU",
    "      .   i      q   .      ",
    "BBBBBf.ef i      q ef.eBBBBB",
    "     L.rl okkkkkkp rl.R     ",
    "     L.rl          rl.R     ",
    "     L.rl ebbbbbbf rl.R     ",
    "0UUUUh.gh guuyxuuh gh.gUUUU1",
    "L............rl............R",
    "L.ebbf.ebbbf.rl.ebbbf.ebbf.R",
    "L.guyl.guuuh.gh.guuuh.rxuh.R",
    "LP..rl.......  .......rl..PR",
    "6bf.rl.ef.ebbbbbbf.ef.rl.eb8",
    "7uh.gh.rl.guuyxuuh.rl.gh.gu9",
    "L......rl....rl....rl......R",
    "L.ebbbbwzbbf.rl.ebbwzbbbbf.R",
    "L.guuuuuuuuh.gh.guuuuuuuuh.R",
    "L..........................R",
    "2BBBBBBBBBBBBBBBBBBBBBBBBBB3",
}

local DISPLAY_TILE_X <const> = 28
local DISPLAY_TILE_Y <const> = 36
local TILE <const> = 16
local HALF_TILE <const> = TILE / 2
local DISPLAY_PIXELS_X <const> = DISPLAY_TILE_X * TILE -- 28 * 16 = 448

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
    if tx < 0 then tx = 0 elseif tx > 27 then tx = 27 end
    if ty < 3 then ty = 3 elseif ty > 33 then ty = 33 end
    return tx, ty
end

function tile_char_at(tx, ty)
    tx, ty = clamp_tile_pos(tx, ty)
    local row = ty - 2
    local col = tx + 1
    local line = tiles[row]
    return line:sub(col, col)
end

function is_blocking(tx, ty)
    local c = tile_char_at(tx, ty)
    return not (c == "." or c == "P" or c == " ")
end

M.is_blocking = is_blocking

M.tiles = tiles

M.DISPLAY_TILE_Y = DISPLAY_TILE_Y
M.DISPLAY_TILE_X = DISPLAY_TILE_X
M.TILE = TILE

function M.can_move(cx, cy, wanted_dir, allow_cornering)
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

function M.move(cx, cy, dir, allow_cornering)
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

return M
