--[[
    "Drawing application for dOS"
    
    @module paint
    @author DustAtom

    Copyright (C) 2026  DustAtom  <DustAtom.dev@proton.me>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]


local M = {}

--- CONFIG

local CELL_SIZE = 8
local LOAD_BATCH = 60
local DESTROY_BATCH = 300
local FILL_YIELD = 400
local MAX_UNDO = 5000

local MIN_GRID = 10
local MAX_GRID_W = 200
local MAX_GRID_H = 150
local DEFAULT_GRID_W = 80
local DEFAULT_GRID_H = 60

local TOOLBAR_W = 54
local PALETTE_H = 50
local BTN_SZ = 22
local BTN_GAP = 4
local BTN_COL_GAP = 4
local MIN_WIN_W = 380
local MIN_WIN_H = 390
local PAN_STEP = 50

local CANVAS_OUTSIDE_BG = Color3.fromRGB(28, 28, 32)

local ZOOM_LEVELS = { 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0 }
local ZOOM_BATCH = 1000 -- cells resized per task.wait() during zoom

--- TOOLS

local T_PEN = "pen"
local T_BRUSH = "brush"
local T_ERASER = "eraser"
local T_BUCKET = "bucket"
local T_LINE = "line"
local T_RECT = "rect"
local T_CIRCLE = "circle"
local T_TRI = "triangle"
local T_SELECT = "select"
local T_PAN = "pan"

local TOOL_LABEL = {
    [T_PEN] = "Pen",
    [T_BRUSH] = "Brush",
    [T_ERASER] = "Eraser",
    [T_BUCKET] = "Fill",
    [T_LINE] = "Line",
    [T_RECT] = "Rect",
    [T_CIRCLE] = "Oval",
    [T_TRI] = "Triangle",
    [T_SELECT] = "Select",
    [T_PAN] = "Pan",
}

local TOOL_IMAGE = {
    [T_PEN] = 16417282974,
    [T_BRUSH] = 75689799554689,
    [T_ERASER] = 91610802455390,
    [T_BUCKET] = 12334709462,
    [T_LINE] = 9863091318,
    [T_RECT] = 95566897034484,
    [T_CIRCLE] = 125576396288773,
    [T_TRI] = 2866597030,
    [T_SELECT] = 99463159552749,
    [T_PAN] = 127589342625914,
}

local TOOL_PAIRS = {
    { T_PEN, T_BRUSH },
    { T_ERASER, T_BUCKET },
    { T_LINE, T_RECT },
    { T_CIRCLE, T_TRI },
    { T_SELECT, T_PAN },
}

--- COLORS

local PALETTE = {
    Color3.fromRGB(0, 0, 0),
    Color3.fromRGB(255, 255, 255),
    Color3.fromRGB(120, 120, 120),
    Color3.fromRGB(200, 200, 200),
    Color3.fromRGB(220, 50, 50),
    Color3.fromRGB(255, 130, 40),
    Color3.fromRGB(245, 210, 0),
    Color3.fromRGB(60, 200, 60),
    Color3.fromRGB(20, 120, 20),
    Color3.fromRGB(40, 200, 200),
    Color3.fromRGB(30, 80, 220),
    Color3.fromRGB(15, 30, 120),
    Color3.fromRGB(140, 30, 160),
    Color3.fromRGB(230, 50, 230),
    Color3.fromRGB(255, 170, 200),
    Color3.fromRGB(160, 90, 50),
    Color3.fromRGB(220, 180, 0),
    Color3.fromRGB(90, 140, 90),
    Color3.fromRGB(40, 160, 240),
    Color3.fromRGB(70, 80, 200),
}

--- TYPES

-- parsed .paint file before it is applied to the canvas

-- undo / redo

-- key = r*100001+c

-- save

-- UI

--- GEOMETRY

local function line_pts(r1, c1, r2, c2)
    local out = {}
    local dr = math.abs(r2 - r1)
    local dc = math.abs(c2 - c1)
    local sr = r1 < r2 and 1 or -1
    local sc = c1 < c2 and 1 or -1
    local e = dr - dc
    local r, c = r1, c1

    while true do
        table.insert(out, { r, c })
        if r == r2 and c == c2 then break end
        local e2 = 2 * e
        if e2 > -dc then
            e -= dc
            r += sr
        end
        if e2 < dr then
            e += dr
            c += sc
        end
    end

    return out
end

local function disk_pts(cr, cc, radius)
    local out = {}
    local r2 = radius * radius

    for dr = -radius, radius do
        for dc = -radius, radius do
            if dr * dr + dc * dc <= r2 then
                table.insert(out, { cr + dr, cc + dc })
            end
        end
    end

    return out
end

local function rect_pts(r1, c1, r2, c2)
    local out = {}
    local rmin, rmax = math.min(r1, r2), math.max(r1, r2)
    local cmin, cmax = math.min(c1, c2), math.max(c1, c2)

    for c = cmin, cmax do
        table.insert(out, { rmin, c })
        table.insert(out, { rmax, c })
    end
    for r = rmin + 1, rmax - 1 do
        table.insert(out, { r, cmin })
        table.insert(out, { r, cmax })
    end

    return out
end

local function circle_pts(cr, cc, radius)
    local out, seen = {}, {}

    local function add(r, c)
        local k = r * 100000 + c
        if not seen[k] then
            seen[k] = true
            table.insert(out, { r, c })
        end
    end

    local x, y, d = 0, radius, 1 - radius
    while x <= y do
        add(cr + y, cc + x)
        add(cr - y, cc + x)
        add(cr + y, cc - x)
        add(cr - y, cc - x)
        add(cr + x, cc + y)
        add(cr - x, cc + y)
        add(cr + x, cc - y)
        add(cr - x, cc - y)
        if d < 0 then
            d += 2 * x + 3
        else
            d += 2 * (x - y) + 5
            y -= 1
        end
        x += 1
    end

    return out
end

local function triangle_pts(r1, c1, r2, c2)
    local dr = r2 - r1
    local dc = c2 - c1
    local len = math.sqrt(dr * dr + dc * dc)
    if len < 1 then return { { r1, c1 } } end

    local half = len * 0.55
    local pnr = -dc / len * half
    local pnc = dr / len * half
    local b1r = math.floor(r2 + pnr + 0.5)
    local b1c = math.floor(c2 + pnc + 0.5)
    local b2r = math.floor(r2 - pnr + 0.5)
    local b2c = math.floor(c2 - pnc + 0.5)

    local out = {}
    for _, pt in ipairs(line_pts(r1, c1, b1r, b1c)) do
        table.insert(out, pt)
    end
    for _, pt in ipairs(line_pts(r1, c1, b2r, b2c)) do
        table.insert(out, pt)
    end
    for _, pt in ipairs(line_pts(b1r, b1c, b2r, b2c)) do
        table.insert(out, pt)
    end

    return out
end

-- expand shape outline by extra_radius for thick strokes (size > 1)
local function expand_pts(pts, extra_radius)
    if extra_radius <= 0 then return pts end
    local seen = {}
    local out = {}

    for _, pt in ipairs(pts) do
        for _, dp in ipairs(disk_pts(pt[1], pt[2], extra_radius)) do
            local k = dp[1] * 100001 + dp[2]
            if not seen[k] then
                seen[k] = true
                table.insert(out, dp)
            end
        end
    end

    return out
end

--- CORE

local function colors_close(a, b)
    return math.abs(a.R - b.R) < 0.005
        and math.abs(a.G - b.G) < 0.005
        and math.abs(a.B - b.B) < 0.005
end

local function set_cell_color(state, r, c, col)
    if r < 1 or r > state.grid_h or c < 1 or c > state.grid_w then return end
    state.colors[r][c] = col
    local cell = state.cells[r][c]
    if cell then (cell :: any).BackgroundColor3 = col end
end

local function paint_cell(state, r, c, col)
    if r < 1 or r > state.grid_h or c < 1 or c > state.grid_w then return end
    if state.delta_recording then
        local k = r * 100001 + c
        if not state.delta_before[k] then
            state.delta_before[k] = state.colors[r][c]
        end
    end
    set_cell_color(state, r, c, col)
end

local function paint_list(state, pts, col)
    for _, pt in ipairs(pts) do
        paint_cell(state, pt[1], pt[2], col)
    end
end

-- preview functions use set_cell_color so they are invisible to the delta recorder
local function apply_preview(state, pts, col)
    for _, pt in ipairs(state.preview_cells) do
        local k = pt[1] .. "_" .. pt[2]
        local sv = state.preview_saved[k]
        if sv then set_cell_color(state, pt[1], pt[2], sv) end
    end
    state.preview_cells = {}
    state.preview_saved = {}

    for _, pt in ipairs(pts) do
        local r, c = pt[1], pt[2]
        if r >= 1 and r <= state.grid_h and c >= 1 and c <= state.grid_w then
            local k = r .. "_" .. c
            if not state.preview_saved[k] then
                state.preview_saved[k] = state.colors[r][c]
            end
            table.insert(state.preview_cells, { r, c })
            set_cell_color(state, r, c, col)
        end
    end
end

local function clear_preview(state)
    for _, pt in ipairs(state.preview_cells) do
        local k = pt[1] .. "_" .. pt[2]
        local sv = state.preview_saved[k]
        if sv then set_cell_color(state, pt[1], pt[2], sv) end
    end
    state.preview_cells = {}
    state.preview_saved = {}
end

local function flood_fill(state, sr, sc, replace)
    if sr < 1 or sr > state.grid_h or sc < 1 or sc > state.grid_w then
        return
    end
    local target = state.colors[sr][sc]
    if colors_close(target, replace) then return end

    local queue = { { sr, sc } }
    local visited = {}
    local function key(r, c) return r * 100001 + c end
    visited[key(sr, sc)] = true

    local step = 0
    local head = 1

    while head <= #queue do
        local pt = queue[head]
        head += 1
        local r, c = pt[1], pt[2]

        if
            r >= 1
            and r <= state.grid_h
            and c >= 1
            and c <= state.grid_w
            and colors_close(state.colors[r][c], target)
        then
            paint_cell(state, r, c, replace)
            step += 1
            if step % FILL_YIELD == 0 then task.wait() end

            for _, nb in ipairs({
                { r - 1, c },
                { r + 1, c },
                { r, c - 1 },
                { r, c + 1 },
            }) do
                local k = key(nb[1], nb[2])
                if not visited[k] then
                    visited[k] = true
                    table.insert(queue, nb)
                end
            end
        end
    end
end

--- HISTORY

local function commit_delta(state)
    local entry = {}
    for k, before_col in pairs(state.delta_before) do
        local r = math.floor(k / 100001)
        local c = k - r * 100001
        local after_col = state.colors[r][c]
        if not colors_close(before_col, after_col) then
            table.insert(
                entry,
                { r = r, c = c, before = before_col, after = after_col }
            )
        end
    end

    state.delta_recording = false
    state.delta_before = {}

    if #entry > 0 then
        table.insert(state.undo_stack, entry)
        while #state.undo_stack > MAX_UNDO do
            table.remove(state.undo_stack, 1)
        end
        state.redo_stack = {}
        if state.on_history_changed then state.on_history_changed() end
    end
end

local function apply_entry(state, entry, use_before)
    for _, ch in ipairs(entry) do
        local col = use_before and ch.before or ch.after
        set_cell_color(state, ch.r, ch.c, col)
    end
end

local function undo(state)
    if #state.undo_stack == 0 then return end
    local entry = table.remove(state.undo_stack)
    apply_entry(state, entry, true)
    table.insert(state.redo_stack, entry)
    if state.on_history_changed then state.on_history_changed() end
end

local function redo_action(state)
    if #state.redo_stack == 0 then return end
    local entry = table.remove(state.redo_stack)
    apply_entry(state, entry, false)
    table.insert(state.undo_stack, entry)
    if state.on_history_changed then state.on_history_changed() end
end

--- IO

-- save format: DOSPAINT1\nW H\nRRGGBB:count,... (RLE, row-major order)
local function serialize_canvas(state)
    local parts = {}
    local cur_hex = ""
    local count = 0

    for r = 1, state.grid_h do
        for c = 1, state.grid_w do
            local col = state.colors[r][c]
            local h = string.format(
                "%02X%02X%02X",
                math.floor(col.R * 255 + 0.5),
                math.floor(col.G * 255 + 0.5),
                math.floor(col.B * 255 + 0.5)
            )
            if h == cur_hex then
                count += 1
            else
                if count > 0 then
                    table.insert(parts, cur_hex .. ":" .. count)
                end
                cur_hex = h
                count = 1
            end
        end
    end

    if count > 0 then table.insert(parts, cur_hex .. ":" .. count) end

    return "DOSPAINT1\n"
        .. state.grid_w
        .. " "
        .. state.grid_h
        .. "\n"
        .. table.concat(parts, ",")
end

local function parse_canvas_data(data)
    local lines = {}
    for line in data:gmatch("([^\n]+)") do
        table.insert(lines, line)
    end

    if #lines < 3 then return false, "Invalid file (too few lines)." end
    if lines[1] ~= "DOSPAINT1" then return false, "Not a dOS Paint file." end

    local ws, hs = lines[2]:match("(%d+) (%d+)")
    if not ws then return false, "Bad dimension header." end
    local w, h = tonumber(ws) :: number, tonumber(hs) :: number

    -- build a flat parsed grid
    local grid = {}
    for r = 1, h do
        grid[r] = {}
    end

    local idx = 1
    for entry in lines[3]:gmatch("([^,]+)") do
        local hex_str, cnt_str = entry:match("(%x%x%x%x%x%x):(%d+)")
        if not hex_str then
            return false, "Corrupted entry near cell " .. tostring(idx) .. "."
        end
        local cnt = tonumber(cnt_str) or 0
        local col = Color3.new(
            (tonumber("0x" .. hex_str:sub(1, 2)) :: number) / 255,
            (tonumber("0x" .. hex_str:sub(3, 4)) :: number) / 255,
            (tonumber("0x" .. hex_str:sub(5, 6)) :: number) / 255
        )
        for _ = 1, cnt do
            local r = math.ceil(idx / w)
            local c = ((idx - 1) % w) + 1
            if r >= 1 and r <= h and c >= 1 and c <= w then grid[r][c] = col end
            idx += 1
        end
    end

    return true, { w = w, h = h, grid = grid } :: any
end

local function apply_canvas_to_state(state, parsed, scale)
    state.delta_recording = true
    state.delta_before = {}

    if scale then
        for r = 1, state.grid_h do
            for c = 1, state.grid_w do
                local sr = math.max(
                    1,
                    math.min(
                        parsed.h,
                        math.floor((r - 1) * parsed.h / state.grid_h) + 1
                    )
                )
                local sc = math.max(
                    1,
                    math.min(
                        parsed.w,
                        math.floor((c - 1) * parsed.w / state.grid_w) + 1
                    )
                )
                paint_cell(state, r, c, parsed.grid[sr][sc])
            end
        end
    else
        for r = 1, state.grid_h do
            for c = 1, state.grid_w do
                paint_cell(state, r, c, parsed.grid[r][c])
            end
        end
    end

    commit_delta(state)
end

--- HITTEST

local function cursor_to_cell(state, mx, my)
    local vp = state.canvas_viewport
    if not vp then return nil, nil end

    local eff = CELL_SIZE * state.zoom
    local rx = mx - vp.AbsolutePosition.X + state.pan_x
    local ry = my - vp.AbsolutePosition.Y + state.pan_y
    if rx < 0 or ry < 0 then return nil, nil end

    local col = math.floor(rx / eff) + 1
    local row = math.floor(ry / eff) + 1
    if col < 1 or col > state.grid_w or row < 1 or row > state.grid_h then
        return nil, nil
    end

    return row, col
end

local function clamp_pan(state)
    local vp = state.canvas_viewport
    if not vp then return end

    local eff = CELL_SIZE * state.zoom
    local maxX = math.max(0, state.grid_w * eff - vp.AbsoluteSize.X)
    local maxY = math.max(0, state.grid_h * eff - vp.AbsoluteSize.Y)
    state.pan_x = math.clamp(state.pan_x, 0, maxX)
    state.pan_y = math.clamp(state.pan_y, 0, maxY)
end

local function update_overflow_arrows(state)
    local vp = state.canvas_viewport
    if not vp then return end

    local eff = CELL_SIZE * state.zoom
    local maxX = math.max(0, state.grid_w * eff - vp.AbsoluteSize.X)
    local maxY = math.max(0, state.grid_h * eff - vp.AbsoluteSize.Y)

    if state.arrow_right then
        (state.arrow_right :: any).Visible = maxX > 0 and state.pan_x < maxX
    end
    if state.arrow_down then
        (state.arrow_down :: any).Visible = maxY > 0 and state.pan_y < maxY
    end
end

local function apply_pan(state)
    local inner = state.canvas_inner
    if inner then
        inner.Position = UDim2.fromOffset(-state.pan_x, -state.pan_y)
    end
    update_overflow_arrows(state)
end

local refresh_sel_overlay

local function apply_zoom(state)
    local inner = state.canvas_inner
    if not inner then return end

    local eff = CELL_SIZE * state.zoom
    inner.Size = UDim2.fromOffset(state.grid_w * eff, state.grid_h * eff)

    task.spawn(function()
        local count = 0
        for r = 1, state.grid_h do
            for c = 1, state.grid_w do
                local cell = state.cells[r][c]
                if cell then
                    (cell :: any).Size = UDim2.fromOffset(eff, eff);
                    (cell :: any).Position =
                        UDim2.fromOffset((c - 1) * eff, (r - 1) * eff)
                end
                count += 1
                if count % ZOOM_BATCH == 0 then task.wait() end
            end
        end
        clamp_pan(state)
        apply_pan(state)
        refresh_sel_overlay(state)
    end)
end

local function zoom_canvas(state, new_zoom, zoom_num_lbl)
    local vp = state.canvas_viewport
    if not vp then return end

    local old_eff = CELL_SIZE * state.zoom
    local new_eff = CELL_SIZE * new_zoom

    local cx = (state.pan_x + vp.AbsoluteSize.X * 0.5) / old_eff
    local cy = (state.pan_y + vp.AbsoluteSize.Y * 0.5) / old_eff
    state.zoom = new_zoom

    state.pan_x = cx * new_eff - vp.AbsoluteSize.X * 0.5
    state.pan_y = cy * new_eff - vp.AbsoluteSize.Y * 0.5
    clamp_pan(state)

    if zoom_num_lbl then zoom_num_lbl.Text = math.floor(new_zoom * 100) end
    apply_zoom(state)
end

refresh_sel_overlay = function(state)
    local ov = state.sel_overlay
    if not ov then return end

    local sel = state.selection
    if not sel then
        (ov :: any).Visible = false
        return
    end

    local eff = CELL_SIZE * state.zoom

    local r1 = math.min(sel.r1, sel.r2)
    local c1 = math.min(sel.c1, sel.c2)
    local r2 = math.max(sel.r1, sel.r2)
    local c2 = math.max(sel.c1, sel.c2);

    (ov :: any).Position = UDim2.fromOffset((c1 - 1) * eff, (r1 - 1) * eff);
    (ov :: any).Size =
        UDim2.fromOffset((c2 - c1 + 1) * eff, (r2 - r1 + 1) * eff);
    (ov :: any).Visible = true
end

--- INPUT

local function on_press(state, mx, my, player)
    if state.drawing and state.draw_user ~= player then return end
    if state.delta_recording then return end

    -- clear selection if we click with a drawing tool
    if state.tool ~= T_SELECT and state.selection ~= nil then
        state.selection = nil
        refresh_sel_overlay(state)
    end

    state.drawing = true
    state.draw_user = player

    if state.tool == T_PAN then
        state.panning = true
        state.pan_start_mx = mx
        state.pan_start_my = my
        state.pan_start_x = state.pan_x
        state.pan_start_y = state.pan_y
        return
    end

    -- start delta recording for all drawing tools except bucket
    if state.tool ~= T_SELECT and state.tool ~= T_BUCKET then
        state.delta_recording = true
        state.delta_before = {}
    end

    local r, c = cursor_to_cell(state, mx, my)

    if state.tool == T_PEN then
        state.last_cell = r and { r, c } or nil
        if r then paint_cell(state, r, c, state.color) end
    elseif state.tool == T_BRUSH then
        state.last_cell = r and { r, c } or nil
        if r then paint_list(state, disk_pts(r, c, state.size), state.color) end
    elseif state.tool == T_ERASER then
        state.last_cell = r and { r, c } or nil
        if r then
            paint_list(state, disk_pts(r, c, state.size), state.bg_color)
        end
    elseif state.tool == T_BUCKET then
        if r then
            state.delta_recording = true
            state.delta_before = {}
            state.drawing = false
            state.draw_user = nil
            task.spawn(function()
                flood_fill(state, r, c, state.color)
                commit_delta(state)
            end)
        end
    elseif
        state.tool == T_LINE
        or state.tool == T_RECT
        or state.tool == T_CIRCLE
        or state.tool == T_TRI
    then
        state.start_cell = r and { r, c } or nil
    elseif state.tool == T_SELECT then
        if r then
            state.selection = { r1 = r, c1 = c, r2 = r, c2 = c }
            refresh_sel_overlay(state)
        end
    end
end

local function on_move(state, mx, my)
    if not state.drawing then return end

    if
        state.tool == T_PAN
        and state.panning
        and state.pan_start_mx ~= nil
        and state.pan_start_x ~= nil
    then
        state.pan_x = (state.pan_start_x :: number)
            - (mx - (state.pan_start_mx :: number))
        state.pan_y = (state.pan_start_y :: number)
            - (my - (state.pan_start_my :: number))
        clamp_pan(state)
        apply_pan(state)
        return
    end

    local r, c = cursor_to_cell(state, mx, my)
    local thick = state.size - 1

    if state.tool == T_PEN then
        if r then
            local last = state.last_cell
            if last then
                paint_list(state, line_pts(last[1], last[2], r, c), state.color)
            else
                paint_cell(state, r, c, state.color)
            end
            state.last_cell = { r, c }
        end
    elseif state.tool == T_BRUSH then
        if r then
            paint_list(state, disk_pts(r, c, state.size), state.color)
            state.last_cell = { r, c }
        end
    elseif state.tool == T_ERASER then
        if r then
            paint_list(state, disk_pts(r, c, state.size), state.bg_color)
            state.last_cell = { r, c }
        end
    elseif state.tool == T_LINE then
        if r and state.start_cell then
            local s = state.start_cell
            apply_preview(
                state,
                expand_pts(line_pts(s[1], s[2], r, c), thick),
                state.color
            )
        end
    elseif state.tool == T_RECT then
        if r and state.start_cell then
            local s = state.start_cell
            apply_preview(
                state,
                expand_pts(rect_pts(s[1], s[2], r, c), thick),
                state.color
            )
        end
    elseif state.tool == T_CIRCLE then
        if r and state.start_cell then
            local s = state.start_cell
            local rad = math.floor(math.sqrt((r - s[1]) ^ 2 + (c - s[2]) ^ 2))
            apply_preview(
                state,
                expand_pts(circle_pts(s[1], s[2], rad), thick),
                state.color
            )
        end
    elseif state.tool == T_TRI then
        if r and state.start_cell then
            local s = state.start_cell
            apply_preview(
                state,
                expand_pts(triangle_pts(s[1], s[2], r, c), thick),
                state.color
            )
        end
    elseif state.tool == T_SELECT then
        if r and state.selection then
            state.selection.r2 = r
            state.selection.c2 = c
            refresh_sel_overlay(state)
        end
    end
end

local function on_release(state, mx, my)
    if not state.drawing then return end

    if state.tool == T_PAN then
        state.panning = false
        state.pan_start_mx = nil
        state.pan_start_my = nil
        state.drawing = false
        state.draw_user = nil
        return
    end

    local r, c = cursor_to_cell(state, mx, my)
    local thick = state.size - 1

    if state.tool == T_LINE and r and state.start_cell then
        local s = state.start_cell
        clear_preview(state)
        paint_list(
            state,
            expand_pts(line_pts(s[1], s[2], r, c), thick),
            state.color
        )
    elseif state.tool == T_RECT and r and state.start_cell then
        local s = state.start_cell
        clear_preview(state)
        paint_list(
            state,
            expand_pts(rect_pts(s[1], s[2], r, c), thick),
            state.color
        )
    elseif state.tool == T_CIRCLE and r and state.start_cell then
        local s = state.start_cell
        local rad = math.floor(math.sqrt((r - s[1]) ^ 2 + (c - s[2]) ^ 2))
        clear_preview(state)
        paint_list(
            state,
            expand_pts(circle_pts(s[1], s[2], rad), thick),
            state.color
        )
    elseif state.tool == T_TRI and r and state.start_cell then
        local s = state.start_cell
        clear_preview(state)
        paint_list(
            state,
            expand_pts(triangle_pts(s[1], s[2], r, c), thick),
            state.color
        )
    end

    -- if it's a single-cell click with select tool, deselect everything
    if state.tool == T_SELECT and state.selection then
        if
            state.selection.r1 == state.selection.r2
            and state.selection.c1 == state.selection.c2
        then
            state.selection = nil
            refresh_sel_overlay(state)
        end
    end

    -- commit the stroke delta (shapes, pen, brush, eraser)
    if state.delta_recording then commit_delta(state) end
    state.drawing = false
    state.draw_user = nil
    state.last_cell = nil
    state.start_cell = nil
end

--- CLEANUP

local function destroy_cells_async(dOS, state, on_done)
    local scr_z = dOS.Z_INDEX.MSGBOX_OVERLAY :: number
    local dlg_z = dOS.Z_INDEX.MSGBOX :: number

    local dim = dOS.create_gui_element(dOS, "Frame", {
        Name = "CleanupDim",
        Parent = dOS.screen,
        ZIndex = scr_z,
        BackgroundColor3 = dOS.THEME.MSGBOX_OVERLAY_COLOR,
        BackgroundTransparency = 0.55,
        Size = UDim2.fromScale(1, 1),
    })

    local dlg = dOS.create_gui_element(dOS, "Frame", {
        Name = "CleanupDialog",
        Parent = dOS.screen,
        ZIndex = dlg_z,
        BackgroundColor3 = dOS.THEME.MSGBOX_BG or dOS.THEME.WINDOW_BG,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(340, 90),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
    })

    if dlg then
        dOS.create_gui_element(
            dOS,
            "UICorner",
            { Parent = dlg, CornerRadius = UDim.new(0, 10) }
        )
    end

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = dlg,
        ZIndex = dlg_z + 1,
        Text = "Cleaning up canvas…",
        TextSize = 13,
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 22),
        Position = UDim2.fromOffset(10, 8),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local pb_track = dOS.create_gui_element(dOS, "Frame", {
        Parent = dlg,
        ZIndex = dlg_z + 1,
        BackgroundColor3 = dOS.THEME.CALC_DISPLAY_BG,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -20, 0, 18),
        Position = UDim2.fromOffset(10, 36),
    })

    local pb_fill = dOS.create_gui_element(dOS, "Frame", {
        Parent = pb_track,
        ZIndex = dlg_z + 2,
        BackgroundColor3 = dOS.THEME.ACCENT,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(0, 1),
    })

    local pct_num = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = dlg,
        ZIndex = dlg_z + 2,
        Text = 0,
        TextSize = 11,
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(36, 16),
        Position = UDim2.new(1, -56, 0, 62),
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = dlg,
        ZIndex = dlg_z + 2,
        Text = "%",
        TextSize = 11,
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.new(1, -20, 0, 62),
    })

    local total = state.grid_w * state.grid_h
    local destroyed = 0

    task.spawn(function()
        for r = 1, state.grid_h do
            for c = 1, state.grid_w do
                local cell = state.cells[r][c]
                if cell then
                    pcall(function() (cell :: any):Destroy() end)
                    state.cells[r][c] = nil
                end

                destroyed += 1
                if destroyed % DESTROY_BATCH == 0 then
                    local frac = destroyed / total
                    if pb_fill and pb_fill.Parent then
                        pb_fill.Size = UDim2.fromScale(frac, 1)
                    end
                    if pct_num and pct_num.Parent then
                        pct_num.Text = math.floor(frac * 100)
                    end
                    task.wait()
                end
            end
        end

        if pb_fill and pb_fill.Parent then
            pb_fill.Size = UDim2.fromScale(1, 1)
        end
        if pct_num and pct_num.Parent then pct_num.Text = 100 end

        task.wait(0.25)
        if dim and dim.Parent then dim:Destroy() end
        if dlg and dlg.Parent then dlg:Destroy() end
        on_done()
    end)
end

--- UI

local function build_paint_ui(dOS, win_frame, content_area, state)
    local Z = (win_frame.ZIndex or dOS.Z_INDEX.WINDOW_INACTIVE) :: number

    local function bind_release(obj)
        if not obj then return end
        pcall(function()
            (obj :: any).MouseButton1Up:Connect(
                function(x, y) on_release(state, x, y) end
            )
        end)
    end

    -- save helpers
    local disks_connected = {}
    local save_name_lbl = nil

    local function scan_disks()
        disks_connected =
            dOS.HardwareManager.requestNewHardware("Disk", true, true)
    end

    local function find_disk(id)
        for _, d in disks_connected do
            if d.id == id then return d end
        end
        return nil
    end

    local function update_save_label()
        if not save_name_lbl then return end
        if state.save_path then
            save_name_lbl.Text = state.save_path:match("([^/]+)$")
                or state.save_path
        else
            save_name_lbl.Text = "Unsaved"
        end
    end

    local save_canvas = nil :: any
    local save_as_canvas = nil :: any
    local load_canvas = nil :: any

    -- undo / redo ui
    local undo_btn = nil
    local redo_btn = nil

    local function update_undo_ui()
        if undo_btn then
            undo_btn.BackgroundColor3 = #state.undo_stack > 0
                    and dOS.THEME.ACCENT
                or dOS.THEME.WINDOW_BG
        end
        if redo_btn then
            redo_btn.BackgroundColor3 = #state.redo_stack > 0
                    and dOS.THEME.ACCENT
                or dOS.THEME.WINDOW_BG
        end
    end
    state.on_history_changed = update_undo_ui

    -- left toolbar
    local toolbar = dOS.create_gui_element(dOS, "Frame", {
        Name = "PaintToolbar",
        Parent = content_area,
        ZIndex = Z + 1,
        BackgroundColor3 = dOS.THEME.TASKBAR_BG,
        BorderSizePixel = 0,
        Size = UDim2.new(0, TOOLBAR_W, 1, -PALETTE_H),
        Position = UDim2.fromOffset(0, 0),
    })
    bind_release(toolbar)

    local btn_refs = {}
    local COLOR_SEL = dOS.THEME.ACCENT
    local COLOR_UNSEL = dOS.THEME.TITLE_BAR_BG

    local function set_tool(tool)
        if state.tool ~= tool then
            clear_preview(state)
            state.selection = nil
            refresh_sel_overlay(state)
        end

        state.tool = tool
        state.drawing = false
        state.draw_user = nil
        state.panning = false
        state.last_cell = nil
        state.start_cell = nil

        for t, b in pairs(btn_refs) do
            if b and b.Parent then
                b.BackgroundColor3 = (t == tool) and COLOR_SEL or COLOR_UNSEL
            end
        end
    end

    local TOOLBAR_BOTTOM = 30
    local tool_scroll = dOS.create_gui_element(dOS, "ScrollingFrame", {
        Name = "ToolScroll",
        Parent = toolbar,
        ZIndex = Z + 2,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = dOS.THEME.ACCENT,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Size = UDim2.new(1, 0, 1, -TOOLBAR_BOTTOM),
        Position = UDim2.fromOffset(0, 0),
    })
    bind_release(tool_scroll)

    local pad_left = math.floor((TOOLBAR_W - (BTN_SZ * 2 + BTN_COL_GAP)) / 2)
    local ty = BTN_GAP

    -- tool buttons
    for _, pair in ipairs(TOOL_PAIRS) do
        for col_idx, tool in ipairs(pair) do
            local cap = tool
            local bx = pad_left + (col_idx - 1) * (BTN_SZ + BTN_COL_GAP)
            local by_cap = ty
            local btn

            btn = dOS.create_gui_element(dOS, "ImageButton", {
                Name = "TB_" .. tool,
                Parent = tool_scroll,
                ZIndex = Z + 3,
                Image = TOOL_IMAGE[tool],
                BackgroundColor3 = COLOR_UNSEL,
                BackgroundTransparency = 0,
                AutoButtonColor = true,
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(BTN_SZ, BTN_SZ),
                Position = UDim2.fromOffset(bx, by_cap),
                OnClick = function() set_tool(cap) end,
            })

            if btn then
                dOS.create_gui_element(
                    dOS,
                    "UICorner",
                    { Parent = btn, CornerRadius = UDim.new(0, 3) }
                )
                dOS.create_gui_element(dOS, "TextLabel", {
                    Parent = btn,
                    ZIndex = Z + 4,
                    Text = if TOOL_IMAGE[tool] == 0
                        then string.sub(TOOL_LABEL[tool], 1, 3) .. "..."
                        else "",
                    TextSize = 8,
                    TextColor3 = dOS.THEME.TEXT_LIGHT,
                    BackgroundTransparency = 1,
                    Size = UDim2.fromScale(1, 1),
                })
            end
            btn_refs[tool] = btn
        end
        ty += BTN_SZ + BTN_GAP
    end

    ty += 4
    dOS.create_gui_element(dOS, "Frame", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        BackgroundColor3 = dOS.THEME.BORDER_HIGHLIGHT,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -8, 0, 1),
        Position = UDim2.fromOffset(4, ty),
    })
    ty += 9

    -- undo / redo buttons
    local half_btn = math.floor((TOOLBAR_W - 12) / 2)
    undo_btn = dOS.create_gui_element(dOS, "ImageButton", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        Image = 136962996761231,
        BackgroundColor3 = dOS.THEME.WINDOW_BG,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(half_btn, 20),
        Position = UDim2.fromOffset(4, ty),
        OnClick = function() undo(state) end,
    })
    redo_btn = dOS.create_gui_element(dOS, "ImageButton", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        Image = 77737150195094,
        BackgroundColor3 = dOS.THEME.WINDOW_BG,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(half_btn, 20),
        Position = UDim2.fromOffset(4 + half_btn + 4, ty),
        OnClick = function() redo_action(state) end,
    })
    ty += 24

    ty += 4
    dOS.create_gui_element(dOS, "Frame", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        BackgroundColor3 = dOS.THEME.BORDER_HIGHLIGHT,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -8, 0, 1),
        Position = UDim2.fromOffset(4, ty),
    })
    ty += 9

    -- size
    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        Text = "SIZE",
        TextSize = 9,
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -8, 0, 12),
        Position = UDim2.fromOffset(4, ty),
    })
    ty += 13

    local size_lbl = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        Text = state.size,
        TextSize = 13,
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        BackgroundColor3 = dOS.THEME.CALC_DISPLAY_BG,
        Size = UDim2.new(1, -8, 0, 20),
        Position = UDim2.fromOffset(4, ty),
    })
    ty += 23

    local half = math.floor((TOOLBAR_W - 12) / 2)
    dOS.create_gui_element(dOS, "TextButton", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        Text = "-",
        TextSize = 15,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = dOS.THEME.ACCENT,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(half, 18),
        Position = UDim2.fromOffset(4, ty),
        OnClick = function()
            state.size = math.max(1, state.size - 1)
            if size_lbl then size_lbl.Text = state.size end
        end,
    })
    dOS.create_gui_element(dOS, "TextButton", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        Text = "+",
        TextSize = 15,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = dOS.THEME.ACCENT,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(half, 18),
        Position = UDim2.fromOffset(4 + half + 4, ty),
        OnClick = function()
            state.size = math.min(12, state.size + 1)
            if size_lbl then size_lbl.Text = state.size end
        end,
    })
    ty += 26

    ty += 4
    dOS.create_gui_element(dOS, "Frame", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        BackgroundColor3 = dOS.THEME.BORDER_HIGHLIGHT,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -8, 0, 1),
        Position = UDim2.fromOffset(4, ty),
    })
    ty += 9

    -- pan arrows
    local arr = 14
    local acx = math.floor(TOOLBAR_W / 2)

    dOS.create_gui_element(dOS, "TextButton", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        Text = "▲",
        TextSize = 9,
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundColor3 = dOS.THEME.WINDOW_BG,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(arr, arr),
        Position = UDim2.fromOffset(acx - math.floor(arr / 2), ty),
        OnClick = function()
            state.pan_y -= PAN_STEP
            clamp_pan(state)
            apply_pan(state)
        end,
    })
    ty += arr + 2

    dOS.create_gui_element(dOS, "TextButton", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        Text = "◀",
        TextSize = 9,
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundColor3 = dOS.THEME.WINDOW_BG,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(arr, arr),
        Position = UDim2.fromOffset(acx - arr - 2, ty),
        OnClick = function()
            state.pan_x -= PAN_STEP
            clamp_pan(state)
            apply_pan(state)
        end,
    })
    dOS.create_gui_element(dOS, "TextButton", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        Text = "▶",
        TextSize = 9,
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundColor3 = dOS.THEME.WINDOW_BG,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(arr, arr),
        Position = UDim2.fromOffset(acx + 2, ty),
        OnClick = function()
            state.pan_x += PAN_STEP
            clamp_pan(state)
            apply_pan(state)
        end,
    })
    ty += arr + 2

    dOS.create_gui_element(dOS, "TextButton", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        Text = "▼",
        TextSize = 9,
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundColor3 = dOS.THEME.WINDOW_BG,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(arr, arr),
        Position = UDim2.fromOffset(acx - math.floor(arr / 2), ty),
        OnClick = function()
            state.pan_y += PAN_STEP
            clamp_pan(state)
            apply_pan(state)
        end,
    })
    ty += arr + 8

    ty += 4
    dOS.create_gui_element(dOS, "Frame", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        BackgroundColor3 = dOS.THEME.BORDER_HIGHLIGHT,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -8, 0, 1),
        Position = UDim2.fromOffset(4, ty),
    })
    ty += 9

    -- zoom controls
    -- "ZOOM" static label
    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        Text = "ZOOM",
        TextSize = 9,
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -8, 0, 12),
        Position = UDim2.fromOffset(4, ty),
    })
    ty += 13

    -- current zoom
    local zoom_num_lbl = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        Text = math.floor(state.zoom * 100),
        TextSize = 13,
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        BackgroundColor3 = dOS.THEME.CALC_DISPLAY_BG,
        Size = UDim2.fromOffset(half - 4, 20),
        Position = UDim2.fromOffset(4, ty),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        Text = " %",
        TextSize = 11,
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(16, 20),
        Position = UDim2.fromOffset(4 + half - 4, ty),
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    ty += 23

    -- zoom -/+ button
    dOS.create_gui_element(dOS, "TextButton", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        Text = "-",
        TextSize = 15,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = dOS.THEME.ACCENT,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(half, 18),
        Position = UDim2.fromOffset(4, ty),
        OnClick = function()
            local cur = state.zoom
            for i = #ZOOM_LEVELS, 1, -1 do
                if ZOOM_LEVELS[i] < cur - 0.001 then
                    zoom_canvas(state, ZOOM_LEVELS[i], zoom_num_lbl)
                    break
                end
            end
        end,
    })
    dOS.create_gui_element(dOS, "TextButton", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        Text = "+",
        TextSize = 15,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = dOS.THEME.ACCENT,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(half, 18),
        Position = UDim2.fromOffset(4 + half + 4, ty),
        OnClick = function()
            local cur = state.zoom
            for i = 1, #ZOOM_LEVELS do
                if ZOOM_LEVELS[i] > cur + 0.001 then
                    zoom_canvas(state, ZOOM_LEVELS[i], zoom_num_lbl)
                    break
                end
            end
        end,
    })
    ty += 26

    ty += 4
    dOS.create_gui_element(dOS, "Frame", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        BackgroundColor3 = dOS.THEME.BORDER_HIGHLIGHT,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -8, 0, 1),
        Position = UDim2.fromOffset(4, ty),
    })
    ty += 9

    -- save / load buttons
    local bw = TOOLBAR_W - 8

    dOS.create_gui_element(dOS, "TextButton", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        Text = "Save",
        TextSize = 10,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = dOS.THEME.ACCENT,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(bw, 18),
        Position = UDim2.fromOffset(4, ty),
        OnClick = function() save_canvas(nil) end,
    })
    ty += 22

    dOS.create_gui_element(dOS, "TextButton", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        Text = "Save As",
        TextSize = 10,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = dOS.THEME.ACCENT,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(bw, 18),
        Position = UDim2.fromOffset(4, ty),
        OnClick = function() save_as_canvas(nil) end,
    })
    ty += 22

    dOS.create_gui_element(dOS, "TextButton", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        Text = "Load",
        TextSize = 10,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = dOS.THEME.WINDOW_BG,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(bw, 18),
        Position = UDim2.fromOffset(4, ty),
        OnClick = function() load_canvas() end,
    })
    ty += 26

    save_name_lbl = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = tool_scroll,
        ZIndex = Z + 2,
        Text = "Unsaved",
        TextSize = 8,
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -8, 0, 16),
        Position = UDim2.fromOffset(4, ty),
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    ty += 20

    if tool_scroll then tool_scroll.CanvasSize = UDim2.fromOffset(0, ty) end

    -- clear
    local clr_b = dOS.create_gui_element(dOS, "TextButton", {
        Parent = toolbar,
        ZIndex = Z + 2,
        Text = "Clear",
        TextSize = 11,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = Color3.fromRGB(175, 45, 45),
        BorderSizePixel = 0,
        Size = UDim2.new(1, -8, 0, TOOLBAR_BOTTOM - 4),
        Position = UDim2.new(0, 4, 1, -TOOLBAR_BOTTOM + 2),
        OnClick = function()
            state.delta_recording = true
            state.delta_before = {}
            for r = 1, state.grid_h do
                for c = 1, state.grid_w do
                    paint_cell(state, r, c, state.bg_color)
                end
            end
            commit_delta(state)
            clear_preview(state)
            state.selection = nil
            if state.sel_overlay then
                (state.sel_overlay :: any).Visible = false
            end
        end,
    })
    bind_release(clr_b)

    -- canvas viewport
    local canvas_x = TOOLBAR_W
    local canvas_vp = dOS.create_gui_element(dOS, "Frame", {
        Name = "PaintCanvas",
        Parent = content_area,
        ZIndex = Z + 1,
        BackgroundColor3 = CANVAS_OUTSIDE_BG,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -canvas_x, 1, -PALETTE_H),
        Position = UDim2.fromOffset(canvas_x, 0),
        ClipsDescendants = true,
    })
    state.canvas_viewport = canvas_vp

    local canvas_inner = dOS.create_gui_element(dOS, "Frame", {
        Name = "CanvasInner",
        Parent = canvas_vp,
        ZIndex = Z + 2,
        BackgroundColor3 = state.bg_color,
        BackgroundTransparency = 0,
        Size = UDim2.fromOffset(
            state.grid_w * CELL_SIZE,
            state.grid_h * CELL_SIZE
        ),
        Position = UDim2.fromOffset(0, 0),
    })

    if canvas_inner then
        dOS.create_gui_element(dOS, "UIStroke", {
            Parent = canvas_inner,
            Color = Color3.fromRGB(80, 80, 100),
            Thickness = 1,
        })
    end

    state.canvas_inner = canvas_inner
    bind_release(canvas_vp)
    bind_release(canvas_inner)

    if canvas_inner then
        task.spawn(function()
            local count = 0
            for r = 1, state.grid_h do
                for c = 1, state.grid_w do
                    local cell = state.cells[r][c]
                    if cell then (cell :: any).Parent = canvas_inner end
                    count += 1
                    if count % 500 == 0 then task.wait() end
                end
            end
        end)

        local ov = dOS.create_gui_element(dOS, "Frame", {
            Name = "SelOverlay",
            Parent = canvas_inner,
            ZIndex = Z + 8,
            BackgroundColor3 = Color3.fromRGB(80, 160, 255),
            BackgroundTransparency = 0.65,
            BorderSizePixel = 1,
            BorderColor3 = Color3.fromRGB(80, 160, 255),
            Visible = false,
            Size = UDim2.fromOffset(0, 0),
        })
        state.sel_overlay = ov
    end

    -- overflow arrows
    if canvas_vp then
        local AR_W = 26
        local AR_H = 48

        local arrow_r = dOS.create_gui_element(dOS, "TextLabel", {
            Name = "ArrowRight",
            Parent = canvas_vp,
            ZIndex = Z + 16,
            Text = "▶",
            TextSize = 16,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 0.35,
            Size = UDim2.fromOffset(AR_W, AR_H),
            Position = UDim2.new(1, -AR_W, 0.5, -math.floor(AR_H / 2)),
            Visible = false,
        })
        if arrow_r then
            dOS.create_gui_element(
                dOS,
                "UICorner",
                { Parent = arrow_r, CornerRadius = UDim.new(0, 4) }
            )
        end
        state.arrow_right = arrow_r

        local arrow_d = dOS.create_gui_element(dOS, "TextLabel", {
            Name = "ArrowDown",
            Parent = canvas_vp,
            ZIndex = Z + 16,
            Text = "▼",
            TextSize = 16,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 0.35,
            Size = UDim2.fromOffset(AR_H, AR_W),
            Position = UDim2.new(0.5, -math.floor(AR_H / 2), 1, -AR_W),
            Visible = false,
        })
        if arrow_d then
            dOS.create_gui_element(
                dOS,
                "UICorner",
                { Parent = arrow_d, CornerRadius = UDim.new(0, 4) }
            )
        end
        state.arrow_down = arrow_d
    end

    -- canvas input overlay
    local canvas_overlay = dOS.create_gui_element(dOS, "TextButton", {
        Name = "CanvasOverlay",
        Parent = canvas_vp,
        ZIndex = Z + 10,
        Text = "",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, 0),
    })

    if canvas_overlay then
        pcall(function()
            (canvas_overlay :: any).MouseButton1Down:Connect(
                function(mx, my)
                    local player_name = "primary"
                    pcall(function()
                        local best = nil
                        local best_dist = math.huge
                        for _, cur in pairs(dOS.screen:GetCursors()) do
                            local d = math.abs(cur.X - mx)
                                + math.abs(cur.Y - my)
                            if d < best_dist then
                                best_dist = d
                                best = cur
                            end
                        end
                        if best and best.Player then
                            player_name = tostring(best.Player)
                        end
                    end)
                    on_press(state, mx, my, player_name)
                end
            )
        end)
        bind_release(canvas_overlay)
    end

    bind_release(toolbar)
    bind_release(content_area)
    bind_release(win_frame)

    -- palette bar
    local palette = dOS.create_gui_element(dOS, "Frame", {
        Name = "PaintPalette",
        Parent = content_area,
        ZIndex = Z + 1,
        BackgroundColor3 = dOS.THEME.TASKBAR_BG,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, PALETTE_H),
        Position = UDim2.new(0, 0, 1, -PALETTE_H),
    })
    bind_release(palette)

    local SWATCH_SZ = PALETTE_H - 10
    local act_sw = dOS.create_gui_element(dOS, "Frame", {
        Name = "ActiveSwatch",
        Parent = palette,
        ZIndex = Z + 2,
        BackgroundColor3 = state.color,
        BorderSizePixel = 2,
        BorderColor3 = Color3.fromRGB(255, 255, 255),
        Size = UDim2.fromOffset(SWATCH_SZ, SWATCH_SZ),
        Position = UDim2.fromOffset(4, math.floor((PALETTE_H - SWATCH_SZ) / 2)),
    })
    state.active_swatch = act_sw

    dOS.create_gui_element(dOS, "Frame", {
        Name = "BgSwatch",
        Parent = palette,
        ZIndex = Z + 2,
        BackgroundColor3 = state.bg_color,
        BorderSizePixel = 1,
        BorderColor3 = dOS.THEME.BORDER_HIGHLIGHT,
        Size = UDim2.fromOffset(14, 14),
        Position = UDim2.fromOffset(SWATCH_SZ - 4, PALETTE_H - 18),
    })

    local FIXED_W = SWATCH_SZ + 14
    local sw_sz = 28
    local sw_gap = 3
    local sw_y = math.floor((PALETTE_H - sw_sz) / 2)

    local pal_scroll = dOS.create_gui_element(dOS, "ScrollingFrame", {
        Name = "PaletteScroll",
        Parent = palette,
        ZIndex = Z + 2,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = dOS.THEME.ACCENT,
        ScrollingDirection = Enum.ScrollingDirection.X,
        Size = UDim2.new(1, -FIXED_W, 1, 0),
        Position = UDim2.fromOffset(FIXED_W, 0),
    })
    bind_release(pal_scroll)

    local sx = 2
    for _, col in ipairs(PALETTE) do
        local cap = col
        local sw = dOS.create_gui_element(dOS, "TextButton", {
            Parent = pal_scroll,
            ZIndex = Z + 3,
            Text = "",
            BackgroundColor3 = col,
            BorderSizePixel = 1,
            BorderColor3 = dOS.THEME.BORDER_DARK,
            Size = UDim2.fromOffset(sw_sz, sw_sz),
            Position = UDim2.fromOffset(sx, sw_y),
            OnClick = function()
                state.color = cap
                if act_sw then act_sw.BackgroundColor3 = cap end
            end,
        })
        bind_release(sw)
        sx += sw_sz + sw_gap
    end

    sx += 2
    local cust = dOS.create_gui_element(dOS, "TextButton", {
        Name = "RGBBtn",
        Parent = pal_scroll,
        ZIndex = Z + 3,
        Text = "RGB",
        TextSize = 10,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = dOS.THEME.ACCENT,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(34, sw_sz),
        Position = UDim2.fromOffset(sx, sw_y),
        OnClick = function()
            dOS.RequestStringAsync(
                dOS,
                "Enter R,G,B:",
                "0,0,0",
                function(raw)
                    local rv, gv, bv = raw:match("(%d+)%D+(%d+)%D+(%d+)")
                    if rv then
                        local nc = Color3.fromRGB(
                            math.clamp(tonumber(rv) or 0, 0, 255),
                            math.clamp(tonumber(gv) or 0, 0, 255),
                            math.clamp(tonumber(bv) or 0, 0, 255)
                        )
                        state.color = nc
                        if act_sw then act_sw.BackgroundColor3 = nc end
                    end
                end
            )
        end,
    })
    bind_release(cust)
    sx += 38

    -- fill sel
    local sel_fill = dOS.create_gui_element(dOS, "TextButton", {
        Parent = pal_scroll,
        ZIndex = Z + 3,
        Text = "Fill Sel",
        TextSize = 10,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = dOS.THEME.ACCENT,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(52, sw_sz),
        Position = UDim2.fromOffset(sx, sw_y),
        OnClick = function()
            local sel = state.selection
            if not sel then return end

            local r1 = math.min(sel.r1, sel.r2)
            local c1 = math.min(sel.c1, sel.c2)
            local r2 = math.max(sel.r1, sel.r2)
            local c2 = math.max(sel.c1, sel.c2)

            state.delta_recording = true
            state.delta_before = {}

            for r = r1, r2 do
                for c = c1, c2 do
                    paint_cell(state, r, c, state.color)
                end
            end
            commit_delta(state)

            -- clear selection after filling
            state.selection = nil
            refresh_sel_overlay(state)
        end,
    })
    bind_release(sel_fill)
    sx += 56

    -- clr sel
    local sel_clr = dOS.create_gui_element(dOS, "TextButton", {
        Parent = pal_scroll,
        ZIndex = Z + 3,
        Text = "Clr Sel",
        TextSize = 10,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = Color3.fromRGB(175, 45, 45),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(48, sw_sz),
        Position = UDim2.fromOffset(sx, sw_y),
        OnClick = function()
            local sel = state.selection
            if not sel then return end

            local r1 = math.min(sel.r1, sel.r2)
            local c1 = math.min(sel.c1, sel.c2)
            local r2 = math.max(sel.r1, sel.r2)
            local c2 = math.max(sel.c1, sel.c2)

            state.delta_recording = true
            state.delta_before = {}

            for r = r1, r2 do
                for c = c1, c2 do
                    paint_cell(state, r, c, state.bg_color)
                end
            end
            commit_delta(state)

            -- clear selection after clearing
            state.selection = nil
            refresh_sel_overlay(state)
        end,
    })
    bind_release(sel_clr)
    sx += 52

    if pal_scroll then pal_scroll.CanvasSize = UDim2.fromOffset(sx + 4, 0) end

    -- save / load

    save_as_canvas = function(cb)
        dOS.OpenFileDialog({
            mode = "save",
            type = "any",
            callback = function(item)
                local function do_write(disk_id, full_path)
                    scan_disks()
                    local entry = find_disk(disk_id)
                    if not entry or not entry.obj then
                        dOS.NotificationManager.push(
                            dOS,
                            "Paint",
                            "Disk not found.",
                            dOS.NotificationManager.GENERIC_ICONS.ERROR,
                            dOS.NotificationManager.GENERIC_SFX.ERROR
                        )
                        return
                    end
                    if entry.obj.GUID == dOS.disk.GUID then
                        dOS.NotificationManager.push(
                            dOS,
                            "Paint",
                            "Cannot write to system disk.",
                            dOS.NotificationManager.GENERIC_ICONS.ERROR,
                            dOS.NotificationManager.GENERIC_SFX.ERROR
                        )
                        return
                    end

                    local data = serialize_canvas(state)
                    local ok, err =
                        pcall(entry.obj.Write, entry.obj, full_path, data)
                    if ok then
                        state.save_disk_id = disk_id
                        state.save_path = full_path
                        update_save_label()
                        dOS.NotificationManager.push(
                            dOS,
                            "Paint",
                            "Canvas saved.",
                            dOS.NotificationManager.GENERIC_ICONS.INFO_GENERIC,
                            dOS.NotificationManager.GENERIC_SFX.INFO_GENERIC
                        )
                        if cb then cb() end
                    else
                        warn("[Paint] save_as error: " .. tostring(err))
                        dOS.MessageBox.error(
                            dOS,
                            "Error",
                            "Failed to save canvas."
                        )
                    end
                end

                if
                    item.type == "folder"
                    or item.type == "disk"
                    or item.is_directory
                then
                    dOS.RequestStringAsync(
                        dOS,
                        "Enter filename (.paint):",
                        "canvas.paint",
                        function(name)
                            if not name or name == "" then return end
                            local base = item.path_on_disk or "/"
                            do_write(
                                item.disk_id,
                                base
                                    .. (base:sub(-1) == "/" and "" or "/")
                                    .. name
                            )
                        end
                    )
                else
                    dOS.RequestConfirmAsync(
                        dOS,
                        "Overwrite " .. (item.name or "file") .. "?",
                        false,
                        function(ok)
                            if ok then
                                do_write(item.disk_id, item.path_on_disk)
                            end
                        end
                    )
                end
            end,
        })
    end

    save_canvas = function(cb)
        if not state.save_path or not state.save_disk_id then
            save_as_canvas(cb)
            return
        end

        scan_disks()
        local entry = find_disk(state.save_disk_id)
        if not entry or not entry.obj then
            dOS.MessageBox.error(
                dOS,
                "Error",
                "Original disk not found. Use Save As."
            )
            return
        end

        local data = serialize_canvas(state)
        local ok, err = pcall(entry.obj.Write, entry.obj, state.save_path, data)
        if ok then
            dOS.NotificationManager.push(
                dOS,
                "Paint",
                "Canvas saved.",
                dOS.NotificationManager.GENERIC_ICONS.INFO_GENERIC,
                dOS.NotificationManager.GENERIC_SFX.INFO_GENERIC
            )
            if cb then cb() end
        else
            warn("[Paint] save error: " .. tostring(err))
            dOS.MessageBox.error(dOS, "Error", "Failed to save.")
        end
    end

    load_canvas = function()
        dOS.OpenFileDialog({
            mode = "open",
            type = "file",
            callback = function(selection)
                local disk_id = selection.disk_id
                local path = selection.path_on_disk
                if not disk_id or not path then
                    dOS.MessageBox.error(dOS, "Error", "Invalid selection.")
                    return
                end

                scan_disks()
                local entry = find_disk(disk_id)
                if not entry or not entry.obj then
                    dOS.MessageBox.error(dOS, "Error", "Disk not found.")
                    return
                end

                local ok, content = pcall(entry.obj.Read, entry.obj, path)
                if not ok or not content then
                    dOS.MessageBox.error(dOS, "Error", "Could not read file.")
                    return
                end

                local parse_ok, result = parse_canvas_data(content)
                if not parse_ok then
                    dOS.MessageBox.error(dOS, "Load Error", tostring(result))
                    return
                end
                local parsed = result

                local function finish_load(do_scale)
                    apply_canvas_to_state(state, parsed, do_scale)
                    state.save_disk_id = disk_id
                    state.save_path = path
                    update_save_label()
                    dOS.NotificationManager.push(
                        dOS,
                        "Paint",
                        "Canvas loaded.",
                        dOS.NotificationManager.GENERIC_ICONS.INFO_GENERIC,
                        dOS.NotificationManager.GENERIC_SFX.INFO_GENERIC
                    )
                end

                if parsed.w == state.grid_w and parsed.h == state.grid_h then
                    finish_load(false)
                else
                    -- size mismatch
                    local msg = "File: "
                        .. tostring(parsed.w)
                        .. " x "
                        .. tostring(parsed.h)
                        .. "\nCanvas: "
                        .. tostring(state.grid_w)
                        .. " x "
                        .. tostring(state.grid_h)
                        .. "\n\nRe-render scales the image to fit the current canvas."

                    dOS.MessageBox.warning(dOS, "Size Mismatch", msg, {
                        {
                            text = "Re-render",
                            callback = function() finish_load(true) end,
                        },
                        { text = "Cancel", callback = function() end },
                    })
                end
            end,
        })
    end

    -- init
    set_tool(state.tool)
    update_undo_ui()

    task.spawn(function()
        task.wait()
        update_overflow_arrows(state)
    end)

    -- cursor input
    local c_move = dOS.screen.CursorMoved:Connect(function(cursor)
        if not state.drawing then return end
        if state.draw_user and tostring(cursor.Player) ~= state.draw_user then
            return
        end
        on_move(state, cursor.X, cursor.Y)
    end)

    -- hook
    local meta = dOS.window_metadata and dOS.window_metadata[win_frame]
    if meta then
        meta.pre_close_hook = function(done_cb)
            pcall(function() c_move:Disconnect() end)
            for _, d in disks_connected do
                pcall(dOS.HardwareManager.freeHardware, d)
            end
            disks_connected = {}
            state.drawing = false
            destroy_cells_async(dOS, state, done_cb)
        end
    end

    win_frame.Destroying:Connect(function()
        pcall(function() c_move:Disconnect() end)
    end)
end

--- LOADING

local function load_canvas_async(dOS, grid_w, grid_h, bg_color, on_done)
    local lw, lc = dOS.create_basic_window(
        dOS,
        "dOS Paint -- Building Canvas…",
        430,
        145,
        false,
        false,
        false,
        false,
        430,
        145
    )

    if not lw or not lc then
        on_done({}, {})
        return
    end

    local LZ = (lw.ZIndex or 15) :: number

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = lc,
        ZIndex = LZ + 1,
        Text = "Building canvas...",
        TextSize = 13,
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 22),
        Position = UDim2.fromOffset(10, 6),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local info = dOS.create_gui_element(dOS, "Frame", {
        Parent = lc,
        ZIndex = LZ + 1,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 14),
        Position = UDim2.fromOffset(10, 24),
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = info,
        ZIndex = LZ + 2,
        Text = grid_w,
        TextSize = 10,
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(38, 14),
        Position = UDim2.fromOffset(0, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = info,
        ZIndex = LZ + 2,
        Text = " x ",
        TextSize = 10,
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(20, 14),
        Position = UDim2.fromOffset(38, 0),
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = info,
        ZIndex = LZ + 2,
        Text = grid_h,
        TextSize = 10,
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(38, 14),
        Position = UDim2.fromOffset(58, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = info,
        ZIndex = LZ + 2,
        Text = " cells",
        TextSize = 10,
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(50, 14),
        Position = UDim2.fromOffset(96, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local pb_track = dOS.create_gui_element(dOS, "Frame", {
        Parent = lc,
        ZIndex = LZ + 1,
        BackgroundColor3 = dOS.THEME.CALC_DISPLAY_BG,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -20, 0, 18),
        Position = UDim2.fromOffset(10, 44),
    })

    local pb_fill = dOS.create_gui_element(dOS, "Frame", {
        Parent = pb_track,
        ZIndex = LZ + 2,
        BackgroundColor3 = dOS.THEME.ACCENT,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(0, 1),
    })

    local pct_num = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = lc,
        ZIndex = LZ + 2,
        Text = 0,
        TextSize = 11,
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(36, 16),
        Position = UDim2.new(1, -56, 0, 65),
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = lc,
        ZIndex = LZ + 2,
        Text = "%",
        TextSize = 11,
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.new(1, -20, 0, 65),
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = lc,
        ZIndex = LZ + 1,
        Text = "Pan tool or arrows to navigate large canvases.",
        TextSize = 10,
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 14),
        Position = UDim2.fromOffset(10, 86),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local total = grid_w * grid_h
    local cells = {}
    local colors = {}

    for r = 1, grid_h do
        cells[r] = {}
        colors[r] = {}
    end

    task.spawn(function()
        local created = 0
        for r = 1, grid_h do
            for c = 1, grid_w do
                local cell = dOS.screen:CreateElement("Frame", {
                    BorderSizePixel = 0,
                    BackgroundColor3 = bg_color,
                    Size = UDim2.fromOffset(CELL_SIZE, CELL_SIZE),
                    Position = UDim2.fromOffset(
                        (c - 1) * CELL_SIZE,
                        (r - 1) * CELL_SIZE
                    ),
                    ZIndex = 1,
                })
                cells[r][c] = cell
                colors[r][c] = bg_color
                created += 1

                if created % LOAD_BATCH == 0 then
                    local frac = created / total
                    if pb_fill and pb_fill.Parent then
                        pb_fill.Size = UDim2.fromScale(frac, 1)
                    end
                    if pct_num and pct_num.Parent then
                        pct_num.Text = math.floor(frac * 100)
                    end
                    task.wait()
                end
            end
        end

        if pb_fill and pb_fill.Parent then
            pb_fill.Size = UDim2.fromScale(1, 1)
        end
        if pct_num and pct_num.Parent then pct_num.Text = 100 end

        task.wait(0.2)
        if lw and lw.Parent then dOS.Window.close_window(dOS, lw) end
        task.wait(0.55)
        on_done(cells, colors)
    end)
end

--- API

function M.create(dOS)
    local screen_w = dOS.screen_dimensions.X
    local screen_h = dOS.screen_dimensions.Y
    local SETUP_W, SETUP_H = 400, 220

    local sw_win, sw_con = dOS.create_basic_window(
        dOS,
        "dOS Paint -- New Canvas",
        SETUP_W,
        SETUP_H,
        true,
        true,
        false,
        false,
        SETUP_W,
        SETUP_H
    )
    if not sw_win or not sw_con then return end

    local SZ = (sw_win.ZIndex or 15) :: number

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = sw_con,
        ZIndex = SZ + 1,
        Text = "Create a new canvas",
        TextSize = 14,
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        Font = dOS.FONT_BOLD,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 22),
        Position = UDim2.fromOffset(10, 4),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local gw = DEFAULT_GRID_W
    local gh = DEFAULT_GRID_H

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = sw_con,
        ZIndex = SZ + 1,
        Text = "Width:",
        TextSize = 12,
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(52, 18),
        Position = UDim2.fromOffset(10, 30),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local w_num = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = sw_con,
        ZIndex = SZ + 1,
        Text = gw,
        TextSize = 12,
        TextColor3 = dOS.THEME.ACCENT,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(36, 18),
        Position = UDim2.fromOffset(62, 30),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = sw_con,
        ZIndex = SZ + 1,
        Text = "cells",
        TextSize = 12,
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(40, 18),
        Position = UDim2.fromOffset(98, 30),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    dOS.create_slider(
        dOS,
        sw_con,
        UDim2.fromOffset(10, 50),
        UDim2.fromOffset(SETUP_W - 40, 14),
        MIN_GRID,
        MAX_GRID_W,
        gw,
        function(v)
            gw = math.floor(v)
            if w_num then w_num.Text = gw end
        end
    )

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = sw_con,
        ZIndex = SZ + 1,
        Text = "Height:",
        TextSize = 12,
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(52, 18),
        Position = UDim2.fromOffset(10, 72),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local h_num = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = sw_con,
        ZIndex = SZ + 1,
        Text = gh,
        TextSize = 12,
        TextColor3 = dOS.THEME.ACCENT,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(36, 18),
        Position = UDim2.fromOffset(62, 72),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = sw_con,
        ZIndex = SZ + 1,
        Text = "cells",
        TextSize = 12,
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(40, 18),
        Position = UDim2.fromOffset(98, 72),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    dOS.create_slider(
        dOS,
        sw_con,
        UDim2.fromOffset(10, 92),
        UDim2.fromOffset(SETUP_W - 40, 14),
        MIN_GRID,
        MAX_GRID_H,
        gh,
        function(v)
            gh = math.floor(v)
            if h_num then h_num.Text = gh end
        end
    )

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = sw_con,
        ZIndex = SZ + 1,
        Text = "Tip: each cell is 8 px.  Use Pan tool or arrows for large canvases.",
        TextSize = 10,
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 14),
        Position = UDim2.fromOffset(10, 116),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local launched = false
    dOS.create_gui_element(dOS, "TextButton", {
        Parent = sw_con,
        ZIndex = SZ + 1,
        Text = "Create Canvas",
        TextSize = 13,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = dOS.THEME.ACCENT,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(SETUP_W - 40, 34),
        Position = UDim2.fromOffset(20, 136),
        OnClick = function()
            if launched then return end
            launched = true

            local win_w = math.clamp(
                gw * CELL_SIZE + TOOLBAR_W + 16,
                MIN_WIN_W,
                screen_w - 60
            )
            local win_h = math.clamp(
                gh * CELL_SIZE + PALETTE_H + 32,
                MIN_WIN_H,
                screen_h - 80
            )
            local bg = Color3.fromRGB(255, 255, 255)

            dOS.Window.close_window(dOS, sw_win)
            task.wait(0.3)

            load_canvas_async(
                dOS,
                gw,
                gh,
                bg,
                function(cells, colors)
                    local state = {
                        grid_w = gw,
                        grid_h = gh,
                        cells = cells,
                        colors = colors,
                        bg_color = bg,
                        tool = T_PEN,
                        color = Color3.fromRGB(0, 0, 0),
                        size = 2,
                        drawing = false,
                        draw_user = nil,
                        last_cell = nil,
                        start_cell = nil,
                        preview_cells = {},
                        preview_saved = {},
                        selection = nil,
                        pan_x = 0,
                        pan_y = 0,
                        panning = false,
                        pan_start_mx = nil,
                        pan_start_my = nil,
                        pan_start_x = nil,
                        pan_start_y = nil,
                        zoom = 1.0,

                        -- undo / redo
                        undo_stack = {},
                        redo_stack = {},
                        delta_recording = false,
                        delta_before = {},
                        on_history_changed = nil,

                        -- disk
                        save_disk_id = nil,
                        save_path = nil,

                        -- ui
                        canvas_viewport = nil,
                        canvas_inner = nil,
                        sel_overlay = nil,
                        active_swatch = nil,
                        arrow_right = nil,
                        arrow_down = nil,
                    }

                    local pw, pc = dOS.create_basic_window(
                        dOS,
                        "dOS Paint",
                        win_w,
                        win_h,
                        true,
                        true,
                        true,
                        true,
                        MIN_WIN_W,
                        MIN_WIN_H
                    )

                    if not pw or not pc then
                        for r = 1, gh do
                            for c = 1, gw do
                                local cell = cells[r][c]
                                if cell and cell.Destroy then cell:Destroy() end
                            end
                        end
                        return
                    end

                    task.wait(0.6)
                    build_paint_ui(dOS, pw, pc, state)
                end
            )
        end,
    })
end

return M

-- EOF