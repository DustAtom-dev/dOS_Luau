--[[
    "Display manager setting panel for dOS"
    
    @module display_manager
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


-- TODO: Scrap this piece of garbage code

local M = {}

local TILE_H_BASE = 78 -- visual base
local TILE_MIN_W = 64
local TILE_MAX_W = 180
local TILE_GAP_X = 10
local TILE_GAP_Y = 12
local CANVAS_PAD = 14
local LABEL_H = 22

--- HELPERS

local function _screen_id_for(dOS, node)
    if not (dOS.DWM and dOS.DWM._state) then
        return 1
    end

    local n = node
    while n do
        local sid = dOS.DWM._state.win_screen[n]
        if sid then
            return sid
        end
        n = n.Parent
    end

    return dOS.DWM._state.primary_id or 1
end

local function _offset_x(dOS, sid)
    local ctx = dOS.DWM and dOS.DWM.get_screen_ctx_by_id(sid)
    return ctx and ctx.screen_x_offset or 0
end

local function _offset_y(dOS, sid)
    local ctx = dOS.DWM and dOS.DWM.get_screen_ctx_by_id(sid)
    return ctx and ctx.screen_y_offset or 0
end

local function _read_grid(dOS)
    if not (dOS.DWM and dOS.DWM._state) then
        return { {} }
    end

    local grid = dOS.DWM._state.screen_grid
    if grid and grid.rows and #grid.rows > 0 then
        local copy = {}
        for _, row in ipairs(grid.rows) do
            local r = {}
            for _, sid in ipairs(row) do
                table.insert(r, sid)
            end
            table.insert(copy, r)
        end
        return copy
    end

    -- fallback
    local row = {}
    for _, sid in ipairs(dOS.DWM._state.screen_order or {}) do
        table.insert(row, sid)
    end

    return { row }
end

local function _layout_grid(dOS, grid_rows, canvas_w)
    local rows_out = {}
    local total_h = CANVAS_PAD

    for _, row in ipairs(grid_rows) do
        local tile_total = math.max(80, canvas_w - TILE_GAP_X * (#row + 1))
        local sum_w = 0
        local per_screen_dim_w = {}

        for _, sid in ipairs(row) do
            local ctx = dOS.DWM and dOS.DWM.get_screen_ctx_by_id(sid)
            local w = ctx and ctx.dimensions.X or 800
            per_screen_dim_w[sid] = w
            sum_w = sum_w + w
        end

        local row_h_for_this_row = 0
        local out_row = {}

        for _, sid in ipairs(row) do
            local prop = per_screen_dim_w[sid] / math.max(1, sum_w)
            local tw = math.clamp(
                math.floor(tile_total * prop),
                TILE_MIN_W,
                TILE_MAX_W
            )

            local ctx = dOS.DWM and dOS.DWM.get_screen_ctx_by_id(sid)
            local aspect_h = ctx
                    and (TILE_H_BASE * (ctx.dimensions.Y / math.max(
                        1,
                        ctx.dimensions.X
                    )) * (tw / TILE_H_BASE))
                or TILE_H_BASE

            local th = math.clamp(math.floor(aspect_h), 40, TILE_H_BASE * 1.6)
            table.insert(out_row, { sid = sid, tw = tw, th = th })

            if th > row_h_for_this_row then
                row_h_for_this_row = th
            end
        end

        out_row._h = row_h_for_this_row
        out_row._y = total_h
        table.insert(rows_out, out_row)

        total_h = total_h + row_h_for_this_row + TILE_GAP_Y
    end

    total_h = total_h + CANVAS_PAD - TILE_GAP_Y
    return rows_out, total_h
end

--- API

function M.build(dOS, container, lifecycle)
    lifecycle = lifecycle
        or { gen = function() return 0 end, bump = function() return 0 end }

    local owner_gen = lifecycle.gen()

    local function _alive()
        return lifecycle.gen() == owner_gen and container and container.Parent
    end

    -- no DWM
    if not dOS.DWM or dOS.DWM.get_screen_count() < 2 then
        local info = dOS.create_gui_element(dOS, "TextLabel", {
            Parent = container,
            Text = "Only one display detected.\nConnect a second screen to use multi-display settings.",
            Size = UDim2.new(1, 0, 0, 60),
            Position = UDim2.fromOffset(-300, 0),
            TextColor3 = dOS.THEME.TEXT_DIM,
            BackgroundTransparency = 1,
            TextSize = 13,
            TextWrapped = true,
        })

        if info then
            dOS.Tween
                .new(
                    info,
                    { Position = UDim2.fromOffset(0, 0) },
                    dOS.TweenInfo.new(
                        0.3,
                        Enum.EasingStyle.Quint,
                        Enum.EasingDirection.Out
                    )
                )
                :Play()
        end

        local connect_btn = dOS.create_gui_element(dOS, "TextButton", {
            Parent = container,
            Text = "Scan for Displays",
            Size = UDim2.fromOffset(160, 32),
            Position = UDim2.fromOffset(0, 68),
            BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 13,
            BorderSizePixel = 0,
        })

        if connect_btn then
            dOS.create_gui_element(
                dOS,
                "UICorner",
                { Parent = connect_btn, CornerRadius = UDim.new(0, 5) }
            )

            connect_btn.MouseButton1Click:Connect(function()
                if not _alive() then return end

                if dOS.DWM then
                    local added = dOS.DWM.connect_screens(dOS)

                    if added and added > 0 then
                        dOS.NotificationManager.push(
                            dOS,
                            "Display",
                            "Found " .. added .. " new display(s)."
                        )

                        -- rebuild
                        lifecycle.bump()
                        for _, child in pairs(container:GetChildren()) do
                            pcall(function() child:Destroy() end)
                        end
                        M.build(dOS, container, lifecycle)
                    else
                        dOS.NotificationManager.push(
                            dOS,
                            "Display",
                            "No new displays found.",
                            nil
                        )
                    end
                end
            end)
        end

        return 110
    end

    -- header
    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = container,
        Text = "Drag to arrange  •  Right-click to set as primary  •  Drop above/below to stack",
        Size = UDim2.new(1, 0, 0, LABEL_H),
        Position = UDim2.fromOffset(0, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = dOS.FONT_BOLD,
        TextSize = 12,
        BackgroundTransparency = 1,
        TextColor3 = dOS.THEME.TEXT_DIM,
    })

    local canvas = dOS.create_gui_element(dOS, "Frame", {
        Parent = container,
        Name = "ArrangementCanvas",
        Size = UDim2.new(1, 0, 0, 200),
        Position = UDim2.fromOffset(0, LABEL_H + 4),
        BackgroundColor3 = dOS.THEME.CALC_DISPLAY_BG,
        BorderSizePixel = 0,
    })

    dOS.create_gui_element(
        dOS,
        "UICorner",
        { Parent = canvas, CornerRadius = UDim.new(0, 8) }
    )

    -- vertical drop indicator
    local drop_v = dOS.create_gui_element(dOS, "Frame", {
        Parent = canvas,
        Name = "DropIndicator_V",
        Size = UDim2.fromOffset(4, 60),
        Position = UDim2.fromOffset(-9999, 0),
        BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
        BackgroundTransparency = 1,
        ZIndex = (canvas.ZIndex or 1) + 5,
        BorderSizePixel = 0,
    })

    if drop_v then
        dOS.create_gui_element(
            dOS,
            "UICorner",
            { Parent = drop_v, CornerRadius = UDim.new(0, 2) }
        )
    end

    -- horizontal drop indicator
    local drop_h = dOS.create_gui_element(dOS, "Frame", {
        Parent = canvas,
        Name = "DropIndicator_H",
        Size = UDim2.new(1, -CANVAS_PAD * 2, 0, 4),
        Position = UDim2.fromOffset(-9999, 0),
        BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
        BackgroundTransparency = 1,
        ZIndex = (canvas.ZIndex or 1) + 5,
        BorderSizePixel = 0,
    })

    if drop_h then
        dOS.create_gui_element(
            dOS,
            "UICorner",
            { Parent = drop_h, CornerRadius = UDim.new(0, 2) }
        )
    end

    local grid = _read_grid(dOS)

    -- tile_entries[i] = { sid, frame, home_x, home_y, tw, th, row, col }
    local tile_entries = {}
    local layout_canvas_w = 440

    -- drag state
    local drag = {
        active = false,
        entry = nil,
        base_col = nil,
        start_vx = 0,
        start_vy = 0, -- virtual cursor at press
        orig_x = 0,
        orig_y = 0, -- tile's canvas position at press
        cursor_conns = {},
        shields = {},
    }

    local function _teardown_drag()
        for _, c in ipairs(drag.cursor_conns) do
            pcall(function() c:Disconnect() end)
        end
        drag.cursor_conns = {}

        for _, s in ipairs(drag.shields) do
            if s and s.Parent then
                pcall(function() s:Destroy() end)
            end
        end
        drag.shields = {}

        if drop_v and drop_v.Parent then
            dOS.Tween
                .new(
                    drop_v,
                    { BackgroundTransparency = 1 },
                    dOS.TweenInfo.new(0.12)
                )
                :Play()
        end

        if drop_h and drop_h.Parent then
            dOS.Tween
                .new(
                    drop_h,
                    { BackgroundTransparency = 1 },
                    dOS.TweenInfo.new(0.12)
                )
                :Play()
        end

        drag.active = false
        drag.entry = nil
        drag.base_col = nil
    end

    local _rebuild_tiles -- forward decl

    local function _compute_drop_target(drag_cx, drag_cy)
        -- find the row whose vertical band contains drag_cy
        local target_row_idx = nil

        for i = 1, #grid do
            local sample_sid = grid[i][1]
            local entry

            for _, e in ipairs(tile_entries) do
                if e.sid == sample_sid then
                    entry = e
                    break
                end
            end

            if entry then
                local top = entry.home_y - TILE_GAP_Y / 2
                local bot = entry.home_y + entry.th + TILE_GAP_Y / 2

                if drag_cy >= top and drag_cy < bot then
                    target_row_idx = i
                    break
                end
            end
        end

        if target_row_idx then
            -- figure out col by X center
            local row = grid[target_row_idx]
            local col = #row + 1

            for c, sid in ipairs(row) do
                if not (drag.entry and sid == drag.entry.sid) then
                    local entry

                    for _, e in ipairs(tile_entries) do
                        if e.sid == sid then
                            entry = e
                            break
                        end
                    end

                    if entry then
                        local cx = entry.home_x + entry.tw / 2
                        if drag_cx < cx then
                            col = c
                            break
                        end
                    end
                end
            end

            return "h", target_row_idx, col
        end

        -- find the row above/below
        local insert_row = #grid + 1

        for i = 1, #grid do
            local sample_sid = grid[i][1]
            local entry

            for _, e in ipairs(tile_entries) do
                if e.sid == sample_sid then
                    entry = e
                    break
                end
            end

            if entry then
                local top = entry.home_y
                if drag_cy < top then
                    insert_row = i
                    break
                end
            end
        end

        return "v", insert_row, 1
    end

    local function _show_drop_indicator(mode, row_idx, col_idx)
        if mode == "h" then
            -- vertical bar between cols within row_idx
            local row = grid[row_idx]
            local x

            if col_idx <= 1 then
                -- before first tile
                local first_sid = row[1]
                local first_entry

                for _, e in ipairs(tile_entries) do
                    if e.sid == first_sid then
                        first_entry = e
                        break
                    end
                end

                x = first_entry and (first_entry.home_x - TILE_GAP_X / 2 - 2)
                    or CANVAS_PAD

            elseif col_idx > #row then
                local last_sid = row[#row]
                local last_entry

                for _, e in ipairs(tile_entries) do
                    if e.sid == last_sid then
                        last_entry = e
                        break
                    end
                end

                x = last_entry
                        and (last_entry.home_x + last_entry.tw + TILE_GAP_X / 2 - 2)
                    or (layout_canvas_w - CANVAS_PAD)

            else
                local before_sid = row[col_idx]
                local before_entry

                for _, e in ipairs(tile_entries) do
                    if e.sid == before_sid then
                        before_entry = e
                        break
                    end
                end

                x = before_entry and (before_entry.home_x - TILE_GAP_X / 2 - 2)
                    or CANVAS_PAD
            end

            local sample_sid = row[1]
            local sample_entry

            for _, e in ipairs(tile_entries) do
                if e.sid == sample_sid then
                    sample_entry = e
                    break
                end
            end

            local y = sample_entry and (sample_entry.home_y - 4) or CANVAS_PAD
            local h = sample_entry and (sample_entry.th + 8) or TILE_H_BASE

            if drop_v and drop_v.Parent then
                drop_v.Size = UDim2.fromOffset(4, h)
                dOS.Tween
                    .new(drop_v, {
                        Position = UDim2.fromOffset(x, y),
                        BackgroundTransparency = 0,
                    }, dOS.TweenInfo.new(
                        0.08,
                        Enum.EasingStyle.Quad
                    ))
                    :Play()
            end

            if drop_h and drop_h.Parent then
                drop_h.BackgroundTransparency = 1
            end

        else
            -- horizontal bar at the new row's Y position
            local y

            if row_idx <= 1 then
                y = CANVAS_PAD - 4

            elseif row_idx > #grid then
                local last_sid = grid[#grid][1]
                local last_entry

                for _, e in ipairs(tile_entries) do
                    if e.sid == last_sid then
                        last_entry = e
                        break
                    end
                end

                y = last_entry
                        and (last_entry.home_y + last_entry.th + TILE_GAP_Y / 2 - 2)
                    or 200

            else
                local before_sid = grid[row_idx][1]
                local before_entry

                for _, e in ipairs(tile_entries) do
                    if e.sid == before_sid then
                        before_entry = e
                        break
                    end
                end

                y = before_entry and (before_entry.home_y - TILE_GAP_Y / 2 - 2)
                    or CANVAS_PAD
            end

            if drop_h and drop_h.Parent then
                dOS.Tween
                    .new(drop_h, {
                        Position = UDim2.fromOffset(CANVAS_PAD, y),
                        BackgroundTransparency = 0,
                    }, dOS.TweenInfo.new(
                        0.08,
                        Enum.EasingStyle.Quad
                    ))
                    :Play()
            end

            if drop_v and drop_v.Parent then
                drop_v.BackgroundTransparency = 1
            end
        end
    end

    _rebuild_tiles = function()
        if not _alive() then
            _teardown_drag()
            return
        end

        for _, e in ipairs(tile_entries) do
            if e.frame and e.frame.Parent then
                pcall(function() e.frame:Destroy() end)
            end
        end
        tile_entries = {}

        local cw = canvas.AbsoluteSize.X
        if cw < 10 then cw = layout_canvas_w end
        layout_canvas_w = cw

        local laid, total_h = _layout_grid(dOS, grid, cw)

        -- update canvas height
        canvas.Size = UDim2.new(1, 0, 0, math.max(120, total_h))

        for r, row in ipairs(laid) do
            local x = CANVAS_PAD

            for c, slot in ipairs(row) do
                local sid = slot.sid
                local tw, th = slot.tw, slot.th
                local ctx = dOS.DWM.get_screen_ctx_by_id(sid)

                if ctx then
                    local is_primary = (sid == dOS.DWM._state.primary_id)
                    local base_col = is_primary and dOS.THEME.ACCENT_BUTTON_BG
                        or dOS.THEME.TITLE_BAR_BG
                    local hover_col = base_col:Lerp(Color3.new(1, 1, 1), 0.15)

                    local tile = dOS.create_gui_element(dOS, "TextButton", {
                        Parent = canvas,
                        Name = "ScreenTile_" .. sid,
                        Text = "",
                        Size = UDim2.fromOffset(tw, th),
                        Position = UDim2.fromOffset(x, row._y),
                        BackgroundColor3 = base_col,
                        ZIndex = (canvas.ZIndex or 1) + 2,
                        BorderSizePixel = 0,
                    })

                    if tile then
                        dOS.create_gui_element(
                            dOS,
                            "UICorner",
                            { Parent = tile, CornerRadius = UDim.new(0, 6) }
                        )

                        dOS.create_gui_element(dOS, "TextLabel", {
                            Parent = tile,
                            Text = sid,
                            Size = UDim2.fromScale(1, 0.55),
                            AnchorPoint = Vector2.new(0.5, 0.5),
                            Position = UDim2.fromScale(0.5, 0.42),
                            TextColor3 = Color3.new(1, 1, 1),
                            Font = dOS.FONT_BOLD,
                            TextSize = 22,
                            BackgroundTransparency = 1,
                            ZIndex = (tile.ZIndex or 1) + 1,
                        })

                        local sub = is_primary and "Primary"
                            or (ctx.dimensions.X .. "x" .. ctx.dimensions.Y)

                        dOS.create_gui_element(dOS, "TextLabel", {
                            Parent = tile,
                            Text = sub,
                            Size = UDim2.new(1, -4, 0, 14),
                            Position = UDim2.new(0, 2, 1, -16),
                            TextColor3 = Color3.new(1, 1, 1),
                            TextSize = 10,
                            BackgroundTransparency = 1,
                            ZIndex = (tile.ZIndex or 1) + 1,
                        })

                        local entry = {
                            sid = sid,
                            frame = tile,
                            home_x = x,
                            home_y = row._y,
                            tw = tw,
                            th = th,
                            row = r,
                            col = c,
                        }
                        table.insert(tile_entries, entry)

                        tile.MouseButton1Down:Connect(function(lx, ly)
                            if not _alive() then return end
                            if drag.active then return end
                            if not (dOS.DWM and dOS.DWM._state) then return end

                            local press_sid = _screen_id_for(dOS, tile)

                            drag.active = true
                            drag.entry = entry
                            drag.base_col = base_col
                            drag.start_vx = lx + _offset_x(dOS, press_sid)
                            drag.start_vy = ly + _offset_y(dOS, press_sid)
                            drag.orig_x = tile.Position.X.Offset
                            drag.orig_y = tile.Position.Y.Offset

                            tile.ZIndex = (canvas.ZIndex or 1) + 10

                            dOS.Tween
                                .new(
                                    tile,
                                    { BackgroundColor3 = hover_col },
                                    dOS.TweenInfo.new(0.10)
                                )
                                :Play()

                            -- commit reorder on release
                            local function _commit()
                                if not drag.active then return end

                                local dragged_entry = drag.entry
                                _teardown_drag()

                                if not _alive() then return end

                                local cx_drop = dragged_entry.frame.Position.X.Offset
                                    + dragged_entry.tw / 2
                                local cy_drop = dragged_entry.frame.Position.Y.Offset
                                    + dragged_entry.th / 2

                                local mode, row_idx, col_idx =
                                    _compute_drop_target(cx_drop, cy_drop)

                                -- remove dragged sid from current row
                                local src_r, src_c
                                for r2, row2 in ipairs(grid) do
                                    for c2, sid2 in ipairs(row2) do
                                        if sid2 == dragged_entry.sid then
                                            src_r, src_c = r2, c2
                                            break
                                        end
                                    end
                                    if src_r then break end
                                end

                                if src_r then
                                    table.remove(grid[src_r], src_c)

                                    -- adjust insertion row if it was an upstream row entry
                                    if
                                        mode == "h"
                                        and row_idx == src_r
                                        and col_idx > src_c
                                    then
                                        col_idx = col_idx - 1
                                    end

                                    if #grid[src_r] == 0 then
                                        table.remove(grid, src_r)
                                        if row_idx > src_r then
                                            row_idx = row_idx - 1
                                        end
                                    end
                                end

                                if mode == "h" then
                                    if row_idx < 1 then row_idx = 1 end

                                    if row_idx > #grid then
                                        table.insert(
                                            grid,
                                            { dragged_entry.sid }
                                        )
                                    else
                                        if col_idx < 1 then col_idx = 1 end
                                        if col_idx > #grid[row_idx] + 1 then
                                            col_idx = #grid[row_idx] + 1
                                        end
                                        table.insert(
                                            grid[row_idx],
                                            col_idx,
                                            dragged_entry.sid
                                        )
                                    end
                                else
                                    if row_idx < 1 then row_idx = 1 end
                                    if row_idx > #grid + 1 then
                                        row_idx = #grid + 1
                                    end

                                    table.insert(
                                        grid,
                                        row_idx,
                                        { dragged_entry.sid }
                                    )
                                end

                                dOS.DWM.reorder_screens_2d(dOS, { rows = grid })

                                grid = _read_grid(dOS)

                                task.spawn(function()
                                    task.wait(0.12)
                                    if _alive() then _rebuild_tiles() end
                                end)
                            end

                            local function _on_move(vx, vy)
                                if not drag.active then return end
                                if not _alive() then
                                    _teardown_drag()
                                    return
                                end

                                local dx = vx - drag.start_vx
                                local dy = vy - drag.start_vy
                                local new_x = drag.orig_x + dx
                                local new_y = drag.orig_y + dy

                                -- clamp inside canvas bounds
                                local cw2 = canvas.AbsoluteSize.X > 10
                                        and canvas.AbsoluteSize.X
                                    or layout_canvas_w
                                local ch2 = canvas.AbsoluteSize.Y > 10
                                        and canvas.AbsoluteSize.Y
                                    or 200

                                new_x = math.clamp(
                                    new_x,
                                    0,
                                    math.max(0, cw2 - entry.tw)
                                )
                                new_y = math.clamp(
                                    new_y,
                                    0,
                                    math.max(0, ch2 - entry.th)
                                )

                                tile.Position = UDim2.fromOffset(new_x, new_y)

                                -- drop preview
                                local drag_cx = new_x + entry.tw / 2
                                local drag_cy = new_y + entry.th / 2
                                local mode, row_idx, col_idx =
                                    _compute_drop_target(drag_cx, drag_cy)

                                _show_drop_indicator(mode, row_idx, col_idx)
                            end

                            for _, ctx2 in pairs(dOS.DWM._state.screens) do
                                local proxy =
                                    dOS.DWM.make_screen_proxy(dOS, ctx2)

                                local sh = dOS.create_gui_element(
                                    proxy,
                                    "TextButton",
                                    {
                                        Name = "DisplayArrangeShield_S"
                                            .. ctx2.id,
                                        Text = "",
                                        Size = UDim2.fromScale(1, 1),
                                        BackgroundTransparency = 1,
                                        ZIndex = 1999999,
                                        Active = true,
                                    }
                                )

                                if sh then
                                    table.insert(drag.shields, sh)
                                    sh.MouseButton1Up:Connect(_commit)
                                end

                                local sid_local = ctx2.id
                                local ok, conn = pcall(function()
                                    return ctx2.hw.CursorMoved:Connect(
                                        function(cursor)
                                            _on_move(
                                                cursor.X
                                                    + _offset_x(dOS, sid_local),
                                                cursor.Y
                                                    + _offset_y(dOS, sid_local)
                                            )
                                        end
                                    )
                                end)

                                if ok and conn then
                                    table.insert(drag.cursor_conns, conn)
                                end
                            end
                        end)

                        -- right click promote to primary
                        tile.MouseButton2Click:Connect(function()
                            if not _alive() then return end
                            if sid == dOS.DWM._state.primary_id then return end

                            dOS.DWM.switch_primary(dOS, sid)

                            task.spawn(function()
                                task.wait(0.1)
                                if _alive() then _rebuild_tiles() end
                            end)

                            dOS.NotificationManager.push(
                                dOS,
                                "Display",
                                "Screen "
                                    .. sid
                                    .. " is now the primary display."
                            )
                        end)

                        x = x + tw + TILE_GAP_X
                    end
                end
            end
        end
    end

    do
        local conn
        conn = canvas.AncestryChanged:Connect(function()
            if canvas.Parent then return end

            if conn then
                pcall(function() conn:Disconnect() end)
                conn = nil
            end

            _teardown_drag()
            tile_entries = {}
        end)
    end

    -- wait one frame for AbsoluteSize
    task.spawn(function()
        task.wait()
        if _alive() then _rebuild_tiles() end
    end)

    local reserved_canvas_h = math.max(
        200,
        TILE_H_BASE * #grid + TILE_GAP_Y * (#grid + 1) + CANVAS_PAD * 2
    )
    local y = LABEL_H + 4 + reserved_canvas_h + 6

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = container,
        Text = "Left-drag: reorder (any direction)  •  Right-click: set primary  •  Blue = primary",
        Size = UDim2.new(1, 0, 0, 18),
        Position = UDim2.fromOffset(0, y),
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundTransparency = 1,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    y = y + 22

    -- identify
    local identify_btn = dOS.create_gui_element(dOS, "TextButton", {
        Parent = container,
        Text = "Identify Displays",
        Size = UDim2.fromOffset(150, 30),
        Position = UDim2.fromOffset(0, y),
        BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 13,
        BorderSizePixel = 0,
    })

    if identify_btn then
        dOS.create_gui_element(
            dOS,
            "UICorner",
            { Parent = identify_btn, CornerRadius = UDim.new(0, 5) }
        )

        identify_btn.MouseButton1Click:Connect(function()
            if not _alive() then return end

            for _, sid in ipairs(dOS.DWM._state.screen_order) do
                local ctx = dOS.DWM.get_screen_ctx_by_id(sid)

                if ctx then
                    local proxy = dOS.DWM.make_screen_proxy(dOS, ctx)
                    local flash = dOS.create_gui_element(proxy, "Frame", {
                        Name = "IdentifyFlash_S" .. sid,
                        Size = UDim2.fromScale(1, 1),
                        BackgroundColor3 = Color3.new(0, 0, 0),
                        BackgroundTransparency = 0.30,
                        ZIndex = 9999995,
                        BorderSizePixel = 0,
                    })

                    if flash then
                        dOS.create_gui_element(proxy, "TextLabel", {
                            Parent = flash,
                            Text = sid,
                            TextColor3 = Color3.new(1, 1, 1),
                            BackgroundTransparency = 1,
                            Size = UDim2.fromScale(1, 1),
                            TextSize = 80,
                            Font = dOS.FONT_BOLD,
                            ZIndex = 9999996,
                        })

                        task.spawn(function()
                            task.wait(2)
                            if flash and flash.Parent then
                                dOS.Tween
                                    .new(
                                        flash,
                                        { BackgroundTransparency = 1 },
                                        dOS.TweenInfo.new(0.4)
                                    )
                                    :Play()

                                task.wait(0.5)
                                if flash and flash.Parent then
                                    pcall(function() flash:Destroy() end)
                                end
                            end
                        end)
                    end
                end
            end
        end)
    end

    y = y + 38

    -- individual screen controls
    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = container,
        Text = "Individual Screen Controls",
        Size = UDim2.new(1, 0, 0, LABEL_H),
        Position = UDim2.fromOffset(0, y),
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = dOS.FONT_BOLD,
        TextSize = 12,
        BackgroundTransparency = 1,
        TextColor3 = dOS.THEME.TEXT_DIM,
    })

    y = y + LABEL_H + 4

    for _, sid in ipairs(dOS.DWM._state.screen_order) do
        if sid ~= dOS.DWM._state.primary_id then
            local ctx = dOS.DWM.get_screen_ctx_by_id(sid)

            if ctx then
                local row = dOS.create_gui_element(dOS, "Frame", {
                    Parent = container,
                    Size = UDim2.new(1, 0, 0, 36),
                    Position = UDim2.fromOffset(0, y),
                    BackgroundColor3 = dOS.THEME.CALC_DISPLAY_BG,
                    BorderSizePixel = 0,
                })

                if row then
                    dOS.create_gui_element(
                        dOS,
                        "UICorner",
                        { Parent = row, CornerRadius = UDim.new(0, 6) }
                    )

                    dOS.create_gui_element(dOS, "TextLabel", {
                        Parent = row,
                        Text = "Screen "
                            .. sid
                            .. "   ("
                            .. ctx.dimensions.X
                            .. "x"
                            .. ctx.dimensions.Y
                            .. ")",
                        Size = UDim2.fromScale(0.5, 1),
                        Position = UDim2.fromOffset(10, 0),
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextColor3 = dOS.THEME.TEXT_LIGHT,
                        BackgroundTransparency = 1,
                        TextSize = 13,
                    })

                    local disc_btn = dOS.create_gui_element(dOS, "TextButton", {
                        Parent = row,
                        Text = "Disconnect",
                        Size = UDim2.fromOffset(100, 24),
                        Position = UDim2.new(1, -112, 0.5, 0),
                        AnchorPoint = Vector2.new(0, 0.5),
                        BackgroundColor3 = Color3.fromRGB(180, 50, 50),
                        TextColor3 = Color3.new(1, 1, 1),
                        TextSize = 12,
                        BorderSizePixel = 0,
                    })

                    if disc_btn then
                        dOS.create_gui_element(
                            dOS,
                            "UICorner",
                            { Parent = disc_btn, CornerRadius = UDim.new(0, 4) }
                        )

                        local captured_sid = sid
                        disc_btn.MouseButton1Click:Connect(function()
                            if not _alive() then return end

                            dOS.DWM.disconnect_screen(dOS, captured_sid)
                            dOS.NotificationManager.push(
                                dOS,
                                "Display",
                                "Screen " .. captured_sid .. " disconnected."
                            )

                            -- full rebuild of the panel
                            lifecycle.bump()
                            for _, child in pairs(container:GetChildren()) do
                                pcall(function() child:Destroy() end)
                            end
                            M.build(dOS, container, lifecycle)
                        end)
                    end

                    y = y + 42
                end
            end
        end
    end

    -- connect button
    local scan_btn = dOS.create_gui_element(dOS, "TextButton", {
        Parent = container,
        Text = "+ Connect New Display",
        Size = UDim2.fromOffset(190, 30),
        Position = UDim2.fromOffset(0, y),
        BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 13,
        BorderSizePixel = 0,
    })

    if scan_btn then
        dOS.create_gui_element(
            dOS,
            "UICorner",
            { Parent = scan_btn, CornerRadius = UDim.new(0, 5) }
        )

        scan_btn.MouseButton1Click:Connect(function()
            if not _alive() then return end

            if dOS.DWM then
                local added = dOS.DWM.connect_screens(dOS)

                if added and added > 0 then
                    dOS.NotificationManager.push(
                        dOS,
                        "Display",
                        "Connected " .. added .. " new display(s)."
                    )

                    lifecycle.bump()
                    for _, child in pairs(container:GetChildren()) do
                        pcall(function() child:Destroy() end)
                    end
                    M.build(dOS, container, lifecycle)
                else
                    dOS.NotificationManager.push(
                        dOS,
                        "Display",
                        "No new displays found.",
                        nil
                    )
                end
            end
        end)
    end

    y = y + 38

    -- slide in
    for _, child in pairs(container:GetChildren()) do
        if child and child.Parent then
            local orig = child.Position
            child.Position = orig + UDim2.fromOffset(-280, 0)
            dOS.Tween
                .new(
                    child,
                    { Position = orig },
                    dOS.TweenInfo.new(
                        0.28,
                        Enum.EasingStyle.Quint,
                        Enum.EasingDirection.Out
                    )
                )
                :Play()
        end
    end

    return y + 10
end

return M

-- EOF