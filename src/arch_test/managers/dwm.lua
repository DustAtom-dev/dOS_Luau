--[[
    "Desktop Window Manager module for dOS"
    
    @module dwm
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


local M = { _virtual_screen = nil }

--- STATE

local function _fresh_state()
    return {
        screens = {}, -- [id] = ScreenContext
        screen_by_hw = {}, -- [hw] = ScreenContext
        win_screen = {}, -- [Frame] = screen_id
        primary_id = 1,
        initialized = false,
        virtual_width = 0,
        virtual_height = 0,
        screen_order = {},
        screen_grid = { rows = {} },
        last_start_screen_id = nil,
        _screen_hw_override = nil, -- temp target for create_gui_element
    }
end

M._state = _fresh_state()

--- PROXY

function M.make_screen_proxy(dOS, ctx)
    return setmetatable({
        screen = ctx.hw,
        screen_dimensions = ctx.dimensions,
        program_holder_frame = ctx.program_holder,
    }, {
        __index = function(_, key)
            if key == "taskbar_frame" then
                return ctx.taskbar_frame
            end

            return dOS[key]
        end,
    })
end

--- VIRTUAL SCREEN

local VIRTUAL_SCREEN_MULTI_EVENTS = {
    CursorMoved = true,
    CursorEntered = true,
    CursorLeft = true,
}

local VS_SENTINEL_KEY = "__dwm_virtual_screen__"
local VS_SENTINEL_VAL = true

local function _make_multi_event(event_name)
    return {
        Connect = function(_, fn)
            local conns = {}

            for _, ctx in pairs(M._state.screens) do
                local ok, c = pcall(function()
                    return ctx.hw[event_name]:Connect(fn)
                end)
                if ok and c then
                    table.insert(conns, c)
                end
            end

            local mc = {}

            function mc:Disconnect()
                for _, c2 in ipairs(conns) do
                    pcall(function()
                        c2:Disconnect()
                    end)
                end
            end

            mc.Unbind = mc.Disconnect

            return mc
        end,
    }
end

function M.make_virtual_screen()
    local vs = { [VS_SENTINEL_KEY] = VS_SENTINEL_VAL }

    setmetatable(vs, {
        __index = function(_, key)
            -- multi event proxy
            if VIRTUAL_SCREEN_MULTI_EVENTS[key] then
                return _make_multi_event(key)
            end

            -- GetPropertyChangedSignal proxy
            if key == "GetPropertyChangedSignal" then
                return function(_, prop)
                    return {
                        Connect = function(_, fn)
                            local conns = {}

                            for _, ctx in pairs(M._state.screens) do
                                local ok, c = pcall(function()
                                    return ctx.hw:GetPropertyChangedSignal(prop):Connect(fn)
                                end)
                                if ok and c then
                                    table.insert(conns, c)
                                end
                            end

                            local mc = {}

                            function mc:Disconnect()
                                for _, c2 in ipairs(conns) do
                                    pcall(function()
                                        c2:Disconnect()
                                    end)
                                end
                            end

                            mc.Unbind = mc.Disconnect

                            return mc
                        end,
                    }
                end
            end

            -- ClearElements on every screen
            if key == "ClearElements" then
                return function(_)
                    for _, ctx in pairs(M._state.screens) do
                        pcall(function()
                            ctx.hw:ClearElements()
                        end)
                    end
                end
            end

            -- GetCursors on every screen
            if key == "GetCursors" then
                return function(_)
                    local all_cursors = {}

                    for sid, ctx in pairs(M._state.screens) do
                        local ok, curs = pcall(function()
                            return ctx.hw:GetCursors()
                        end)
                        if ok and curs then
                            for k, c in pairs(curs) do
                                all_cursors[k .. "_S" .. sid] = c
                                all_cursors[k] = c
                            end
                        end
                    end

                    return all_cursors
                end
            end

            -- forward to the primary (or override) hw
            local hw = M._state._screen_hw_override
                or (
                    M._state.screens[M._state.primary_id]
                    and M._state.screens[M._state.primary_id].hw
                )

            if not hw then
                return nil
            end

            local v = hw[key]
            if type(v) == "function" then
                -- `:` calls pass the proxy as the first arg, drop it and
                -- call the real method with hw as self
                return function(_, ...)
                    return v(hw, ...)
                end
            end

            return v
        end,

        __newindex = function(_, key, val)
            -- never let the sentinel get overwritten
            if key == VS_SENTINEL_KEY then
                return
            end

            local hw = M._state._screen_hw_override
                or (
                    M._state.screens[M._state.primary_id]
                    and M._state.screens[M._state.primary_id].hw
                )

            if hw then
                hw[key] = val
            end
        end,
    })

    return vs
end

function M.is_virtual_screen(t)
    local s, r = pcall(function()
        return t[VS_SENTINEL_KEY]
    end)

    if not s then
        return false
    end

    return type(t) == "table" and r == VS_SENTINEL_VAL
end

--- HELPERS

local TB = 44

local function _ph_geom(pos)
    if pos == "Bottom" then
        return UDim2.new(1, 0, 1, -TB), UDim2.fromOffset(0, 0)
    elseif pos == "Top" then
        return UDim2.new(1, 0, 1, -TB), UDim2.fromOffset(0, TB)
    elseif pos == "Left" then
        return UDim2.new(1, -TB, 1, 0), UDim2.fromOffset(TB, 0)
    else
        return UDim2.new(1, -TB, 1, 0), UDim2.fromOffset(0, 0)
    end
end

local function _create_bg(dOS, ctx)
    local proxy = M.make_screen_proxy(dOS, ctx)
    local bg

    if
        dOS.os_settings.desktop_bg_img_id
        and dOS.os_settings.desktop_bg_img_id > 0
    then
        bg = dOS.create_gui_element(proxy, "ImageLabel", {
            Name = "DesktopBackground",
            ZIndex = dOS.Z_INDEX.DESKTOP,
            Image = dOS.os_settings.desktop_bg_img_id,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            Active = true,
        })
    else
        bg = dOS.create_gui_element(proxy, "Frame", {
            Name = "DesktopBackground",
            ZIndex = dOS.Z_INDEX.DESKTOP,
            BackgroundColor3 = dOS.THEME.DESKTOP_BG,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            Active = true,
        })
    end

    ctx.desktop_bg = bg

    return bg
end

local function _wire_primary_click(dOS, ctx)
    local bg = ctx.desktop_bg
    if not bg or not bg.InputBegan then
        return
    end

    bg.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end

        if dOS.active_window_frame and dOS.active_window_frame.Parent then
            dOS.active_window_frame.ZIndex = dOS.Z_INDEX.WINDOW_INACTIVE
            dOS.active_window_frame = nil
        end

        if dOS.start_menu_frame and dOS.start_menu_frame.Parent then
            dOS.start_menu_frame:Destroy()
            dOS.start_menu_frame = nil
        end
    end)
end

local function _create_secondary_ph(dOS, ctx)
    local proxy = M.make_screen_proxy(dOS, ctx)
    local pos = dOS.os_settings.taskbar_position or "Bottom"
    local sz, p = _ph_geom(pos)

    local ph = dOS.create_gui_element(proxy, "Frame", {
        Name = "ProgramHolder_S" .. ctx.id,
        ZIndex = dOS.Z_INDEX.WINDOW_INACTIVE - 1,
        BackgroundTransparency = 1,
        Size = sz,
        Position = p,
    })

    ctx.program_holder = ph

    return ph
end

local function _rebuild_flat_order()
    local flat = {}

    for _, row in ipairs(M._state.screen_grid.rows) do
        for _, sid in ipairs(row) do
            table.insert(flat, sid)
        end
    end

    M._state.screen_order = flat
end

local function _normalise_grid()
    local seen = {}

    for r = #M._state.screen_grid.rows, 1, -1 do
        local row = M._state.screen_grid.rows[r]
        for c = #row, 1, -1 do
            local sid = row[c]
            if not M._state.screens[sid] or seen[sid] then
                table.remove(row, c)
            else
                seen[sid] = true
            end
        end
        if #row == 0 then
            table.remove(M._state.screen_grid.rows, r)
        end
    end

    for sid in pairs(M._state.screens) do
        if not seen[sid] then
            local last = M._state.screen_grid.rows[#M._state.screen_grid.rows]
            if not last then
                last = {}
                table.insert(M._state.screen_grid.rows, last)
            end
            table.insert(last, sid)
        end
    end
end

local function _recalc_offsets()
    _normalise_grid()

    local total_w, total_h = 0, 0
    local y = 0

    for r, row in ipairs(M._state.screen_grid.rows) do
        local x = 0
        local row_h = 0

        for c, sid in ipairs(row) do
            local ctx = M._state.screens[sid]
            if ctx then
                ctx.screen_x_offset = x
                ctx.screen_y_offset = y
                ctx.row_index = r
                ctx.col_index = c

                x = x + ctx.dimensions.X
                if ctx.dimensions.Y > row_h then
                    row_h = ctx.dimensions.Y
                end
            end
        end

        if x > total_w then
            total_w = x
        end

        y = y + row_h
    end

    total_h = y

    M._state.virtual_width = total_w
    M._state.virtual_height = total_h

    _rebuild_flat_order()
end

--- COORDS

function M.to_virtual_x(sid, lx)
    local ctx = M._state.screens[sid]
    return ctx and (ctx.screen_x_offset + lx) or lx
end

function M.to_virtual_y(sid, ly)
    local ctx = M._state.screens[sid]
    return ctx and (ctx.screen_y_offset + ly) or ly
end

function M.from_virtual_pos(vx, vy)
    for _, row in ipairs(M._state.screen_grid.rows) do
        local first = row[1] and M._state.screens[row[1]]

        if first then
            local row_top = first.screen_y_offset
            local row_bot = row_top

            for _, sid in ipairs(row) do
                local ctx = M._state.screens[sid]
                if ctx then
                    local h = ctx.screen_y_offset + ctx.dimensions.Y
                    if h > row_bot then
                        row_bot = h
                    end
                end
            end

            if vy >= row_top and vy < row_bot then
                local last_match

                for _, sid in ipairs(row) do
                    local ctx = M._state.screens[sid]
                    if ctx and vx >= ctx.screen_x_offset then
                        last_match = ctx
                    end
                end

                if last_match then
                    return last_match.id,
                        vx - last_match.screen_x_offset,
                        vy - last_match.screen_y_offset
                end

                if first then
                    return first.id,
                        vx - first.screen_x_offset,
                        vy - first.screen_y_offset
                end
            end
        end
    end

    -- fallback
    local p = M._state.screens[M._state.primary_id]
    if p then
        return p.id, vx - p.screen_x_offset, vy - p.screen_y_offset
    end

    return M._state.primary_id, vx, vy
end

function M.from_virtual_x(vx)
    -- first row with a tile starting at or before vx
    for _, row in ipairs(M._state.screen_grid.rows) do
        local match

        for _, sid in ipairs(row) do
            local ctx = M._state.screens[sid]
            if ctx and vx >= ctx.screen_x_offset then
                match = ctx
            end
        end

        if match then
            return match.id, vx - match.screen_x_offset
        end
    end

    local p = M._state.screens[M._state.primary_id]
    if p then
        return p.id, vx - p.screen_x_offset
    end

    return M._state.primary_id, vx
end

function M.get_neighbors(sid)
    local out = { left = nil, right = nil, top = nil, bottom = nil }

    for r, row in ipairs(M._state.screen_grid.rows) do
        for c, this_sid in ipairs(row) do
            if this_sid == sid then
                out.left = row[c - 1]
                out.right = row[c + 1]

                local function _pick_in_row(other_row, col_target)
                    if not other_row then
                        return nil
                    end

                    if other_row[col_target] then
                        return other_row[col_target]
                    end

                    if #other_row > 0 then
                        return other_row[math.min(col_target, #other_row)]
                    end

                    return nil
                end

                out.top = _pick_in_row(M._state.screen_grid.rows[r - 1], c)
                out.bottom = _pick_in_row(M._state.screen_grid.rows[r + 1], c)

                return out
            end
        end
    end

    return out
end

--- QUERIES

function M.get_primary_ctx()
    return M._state.screens[M._state.primary_id]
end

function M.get_screen_ctx_by_id(id)
    return M._state.screens[id]
end

function M.get_screen_ctx_for_hw(hw)
    return M._state.screen_by_hw[hw]
end

function M.get_screen_count()
    local n = 0

    for _ in pairs(M._state.screens) do
        n += 1
    end

    return n
end

function M.get_screen_hw_for_window(dOS, wf)
    local sid = M._state.win_screen[wf]
    if sid then
        local ctx = M._state.screens[sid]
        if ctx then
            return ctx.hw
        end
    end

    return dOS.screen
end

--- WINDOWS

function M.register_window(_, wf, sid)
    local s = sid or M._state.primary_id
    M._state.win_screen[wf] = s

    local ctx = M._state.screens[s]
    if ctx then
        ctx.windows[wf] = true
    end
end

function M.unregister_window(_, wf)
    local sid = M._state.win_screen[wf]
    if sid then
        local ctx = M._state.screens[sid]
        if ctx then
            ctx.windows[wf] = nil
        end
    end

    M._state.win_screen[wf] = nil
end

--- BROADCAST

function M.broadcast(dOS, fn)
    for _, ctx in pairs(M._state.screens) do
        local proxy = M.make_screen_proxy(dOS, ctx)
        fn(ctx, proxy)
    end
end

--- MOVE

function M.move_window_to_screen(dOS, wf, target_id)
    if not wf or not wf.Parent then
        return
    end

    local meta = dOS.window_metadata and dOS.window_metadata[wf]
    if not meta then
        return
    end

    local tgt = M._state.screens[target_id]
    if not tgt or not tgt.program_holder then
        return
    end

    local src_id = M._state.win_screen[wf] or M._state.primary_id
    if src_id == target_id then
        return
    end

    local src = M._state.screens[src_id]
    local ph_abs = tgt.program_holder.AbsoluteSize
    local win_abs = wf.AbsoluteSize

    -- src local -> virtual -> target local
    local virt_x = (src and src.screen_x_offset or 0) + wf.Position.X.Offset
    local virt_y = (src and src.screen_y_offset or 0) + wf.Position.Y.Offset
    local new_local_x = virt_x - tgt.screen_x_offset
    local new_local_y = virt_y - tgt.screen_y_offset

    wf.Parent = tgt.program_holder
    wf.Position = UDim2.fromOffset(
        math.clamp(new_local_x, 0, math.max(0, ph_abs.X - win_abs.X)),
        math.clamp(new_local_y, 0, math.max(0, ph_abs.Y - win_abs.Y))
    )

    meta.screen_id = target_id
    M._state.win_screen[wf] = target_id

    if src then
        src.windows[wf] = nil
    end

    tgt.windows[wf] = true

    local dm = dOS.DragManager and dOS.DragManager.drag_manager
    if dm and dm.is_dragging and dm.window == wf then
        dm.source_screen_id = target_id
        dm.cached_parent_size = tgt.program_holder.AbsoluteSize
        dm.cached_window_size = wf.AbsoluteSize
        dm.start_cursor_pos = dm.latest_cursor_pos
        dm.start_window_pos = wf.Position
        dm.start_virtual_x = dm.latest_virtual_x
        dm.start_virtual_y = dm.latest_virtual_y
    end

    if dOS.TaskbarManager and dOS.TaskbarManager.refresh_mirror_taskbars then
        dOS.TaskbarManager.refresh_mirror_taskbars(dOS)
    end
end

--- TRANSFER

function M.transfer_window_animated(dOS, wf, target_id)
    if not wf or not wf.Parent then
        return
    end

    local meta = dOS.window_metadata and dOS.window_metadata[wf]
    if not meta or meta._transferring then
        return
    end

    local tgt = M._state.screens[target_id]
    if not tgt or not tgt.program_holder then
        return
    end

    local src_id = M._state.win_screen[wf] or M._state.primary_id
    if src_id == target_id then
        return
    end

    local src = M._state.screens[src_id]

    meta._transferring = true
    wf.Active = false

    local orig_size = wf.AbsoluteSize
    local orig_bg = wf.BackgroundColor3
    local orig_alpha = wf.BackgroundTransparency
    local accent = dOS.THEME and dOS.THEME.ACCENT or Color3.fromRGB(100, 149, 237)

    local cx = wf.Position.X.Offset + orig_size.X / 2
    local cy = wf.Position.Y.Offset + orig_size.Y / 2

    wf.AnchorPoint = Vector2.new(0.5, 0.5)
    wf.Position = UDim2.fromOffset(cx, cy)
    wf.Size = UDim2.fromOffset(orig_size.X, orig_size.Y)

    local tiny_w = math.max(4, math.floor(orig_size.X * 0.08))
    local tiny_h = math.max(4, math.floor(orig_size.Y * 0.08))

    local p1 = dOS.TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

    dOS.Tween.new(wf, {
        Size = UDim2.fromOffset(tiny_w, tiny_h),
        BackgroundTransparency = 1,
    }, p1):Play()

    task.delay(0.11, function()
        if not wf or not wf.Parent then
            return
        end

        dOS.Tween.new(wf, {
            BackgroundColor3 = accent,
        }, dOS.TweenInfo.new(0.09, Enum.EasingStyle.Linear)):Play()
    end)

    task.wait(0.23)

    if not wf or not wf.Parent then
        if meta then
            meta._transferring = false
        end
        return
    end

    meta.screen_id = target_id
    M._state.win_screen[wf] = target_id

    if src then
        src.windows[wf] = nil
    end

    tgt.windows[wf] = true

    wf.Parent = tgt.program_holder
    wf.AnchorPoint = Vector2.new(0.5, 0.5)
    wf.Position = UDim2.fromScale(0.5, 0.5)
    wf.Size = UDim2.fromOffset(tiny_w, tiny_h)
    wf.BackgroundTransparency = 1

    local p2 = dOS.TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

    dOS.Tween.new(wf, {
        Size = UDim2.fromOffset(orig_size.X, orig_size.Y),
        BackgroundTransparency = orig_alpha,
        BackgroundColor3 = accent,
    }, p2):Play()

    task.delay(0.15, function()
        if not wf or not wf.Parent then
            return
        end

        dOS.Tween.new(wf, {
            BackgroundColor3 = orig_bg,
        }, dOS.TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)):Play()
    end)

    task.wait(0.36)

    if not wf or not wf.Parent then
        if meta then
            meta._transferring = false
        end
        return
    end

    local ph_abs = tgt.program_holder.AbsoluteSize
    local fx = math.clamp(
        ph_abs.X / 2 - orig_size.X / 2,
        0,
        math.max(0, ph_abs.X - orig_size.X)
    )
    local fy = math.clamp(
        ph_abs.Y / 2 - orig_size.Y / 2,
        0,
        math.max(0, ph_abs.Y - orig_size.Y)
    )

    wf.AnchorPoint = Vector2.new(0, 0)
    wf.Position = UDim2.fromOffset(fx, fy)
    wf.Size = UDim2.fromOffset(orig_size.X, orig_size.Y)
    wf.BackgroundColor3 = orig_bg

    meta.restore_position = wf.Position
    meta.restore_size = wf.Size
    meta._transferring = false
    wf.Active = true

    if dOS.TaskbarManager and dOS.TaskbarManager.refresh_mirror_taskbars then
        dOS.TaskbarManager.refresh_mirror_taskbars(dOS)
    end

    print(
        string.format(
            "[DWM] Window '%s': screen %d -> %d",
            wf.Name,
            src_id,
            target_id
        )
    )
end

--- PRIMARY

function M.switch_primary(dOS, new_id)
    if new_id == M._state.primary_id then
        return
    end

    local new_ctx = M._state.screens[new_id]
    if not new_ctx then
        return
    end

    local old_id = M._state.primary_id
    local old_ctx = M._state.screens[old_id]

    print(string.format("[DWM] switch_primary: %d -> %d", old_id, new_id))

    local tm = dOS.TaskbarManager.taskbar_manager
    local mirror = tm.mirrors and tm.mirrors[new_id]

    if mirror then
        if mirror.frame and mirror.frame.Parent then
            pcall(function()
                mirror.frame:Destroy()
            end)
        end
        if tm.mirrors then
            tm.mirrors[new_id] = nil
        end
    end

    local tm_special = tm.__Special
    local on_start_raw = tm._on_start_click

    dOS.TaskbarManager.reset()

    M._state.primary_id = new_id
    if old_ctx then
        old_ctx.is_primary = false
    end
    new_ctx.is_primary = true

    dOS.screen_dimensions = new_ctx.dimensions

    M._state._screen_hw_override = nil

    -- rebuild the wrapped start so it closes over the new state
    local _raw_start_ref = on_start_raw
    local new_wrapped_start = function()
        if not _raw_start_ref then
            return
        end

        local sid = M._state.last_start_screen_id or 1
        M._state.last_start_screen_id = nil

        local ctx2 = M._state.screens[sid]
        if ctx2 and not ctx2.is_primary then
            local prev_d = dOS.screen_dimensions
            M._state._screen_hw_override = ctx2.hw
            dOS.screen_dimensions = ctx2.dimensions

            local ok, err = pcall(_raw_start_ref)
            M._state._screen_hw_override = nil
            dOS.screen_dimensions = prev_d

            if not ok then
                warn("[DWM] switch_primary wrapped_start error: " .. tostring(err))
            end
        else
            M._state._screen_hw_override = nil
            _raw_start_ref()
        end
    end

    local old_new_ph = new_ctx.program_holder

    local tb, ph = dOS.TaskbarManager.init(dOS, tm_special, new_wrapped_start)
    if not tb or not ph then
        warn("[DWM] switch_primary: TaskbarManager.init failed on new primary.")
        return
    end

    new_ctx.taskbar_frame = tb
    new_ctx.program_holder = ph
    dOS.taskbar_frame = tb
    dOS.program_holder_frame = ph

    dOS.TaskbarManager.taskbar_manager._on_start_click = new_wrapped_start

    if old_new_ph and old_new_ph ~= ph then
        for wf in pairs(new_ctx.windows) do
            if wf and wf.Parent == old_new_ph then
                wf.Parent = ph
            end
        end

        if old_new_ph.Parent then
            pcall(function()
                old_new_ph:Destroy()
            end)
        end
    end

    if dOS.window_metadata then
        for wf in pairs(dOS.window_metadata) do
            if wf and wf.Parent then
                local found_sid

                for sid, ctx in pairs(M._state.screens) do
                    if wf.Parent == ctx.program_holder then
                        found_sid = sid
                        break
                    end
                end

                if found_sid then
                    local prev_sid = M._state.win_screen[wf]
                    if prev_sid and prev_sid ~= found_sid then
                        local prev_ctx = M._state.screens[prev_sid]
                        if prev_ctx then
                            prev_ctx.windows[wf] = nil
                        end
                    end

                    M._state.win_screen[wf] = found_sid
                    local found_ctx = M._state.screens[found_sid]
                    if found_ctx then
                        found_ctx.windows[wf] = true
                    end

                    if dOS.window_metadata[wf] then
                        dOS.window_metadata[wf].screen_id = found_sid
                    end
                end
            end
        end
    end

    _wire_primary_click(dOS, new_ctx)

    if old_ctx then
        if dOS.TaskbarManager.create_mirror_taskbar then
            dOS.TaskbarManager.create_mirror_taskbar(dOS, old_ctx)
        end
    end

    if dOS.DragManager and dOS.DragManager.BindInputEventsForScreen then
        pcall(dOS.DragManager.BindInputEventsForScreen, dOS, new_ctx)
    end

    for _, wf in ipairs(dOS.all_windows) do
        if wf and wf.Parent then
            task.spawn(dOS.TaskbarManager.on_window_opened, dOS, wf)
        end
    end

    if
        dOS.VirtualDesktopManager
        and dOS.VirtualDesktopManager.create_taskbar_button
    then
        task.spawn(function()
            task.wait(0.1)
            dOS.VirtualDesktopManager.create_taskbar_button(dOS)

            for _, ctx in pairs(M._state.screens) do
                if not ctx.is_primary and ctx.taskbar_frame then
                    local proxy = M.make_screen_proxy(dOS, ctx)
                    dOS.VirtualDesktopManager.create_taskbar_button(proxy)
                end
            end
        end)
    end

    print(string.format("[DWM] Primary is now screen %d.", new_id))
end

--- DISCONNECT

function M.disconnect_screen(dOS, screen_id)
    if screen_id == M._state.primary_id then
        warn("[DWM] Cannot disconnect the primary screen.")
        return
    end

    local ctx = M._state.screens[screen_id]
    if not ctx then
        return
    end

    print("[DWM] Disconnecting screen " .. screen_id)

    local primary_id = M._state.primary_id

    local wins_to_move = {}
    for wf in pairs(ctx.windows) do
        table.insert(wins_to_move, wf)
    end

    for _, wf in ipairs(wins_to_move) do
        if wf and wf.Parent then
            M.move_window_to_screen(dOS, wf, primary_id)
        end
    end

    local tm = dOS.TaskbarManager.taskbar_manager
    local mirror = tm.mirrors and tm.mirrors[screen_id]

    if mirror then
        if mirror.frame and mirror.frame.Parent then
            pcall(function()
                mirror.frame:Destroy()
            end)
        end
        if tm.mirrors then
            tm.mirrors[screen_id] = nil
        end
    end

    if ctx.cursor_conn then
        pcall(function()
            ctx.cursor_conn:Disconnect()
        end)
        ctx.cursor_conn = nil
    end

    if ctx.capture_shield and ctx.capture_shield.Parent then
        pcall(function()
            ctx.capture_shield:Destroy()
        end)
        ctx.capture_shield = nil
    end

    pcall(function()
        ctx.hw:ClearElements()
    end)

    M._state.screens[screen_id] = nil
    M._state.screen_by_hw[ctx.hw] = nil

    for wf in pairs(ctx.windows) do
        M._state.win_screen[wf] = nil
    end

    for i = #M._state.screen_order, 1, -1 do
        if M._state.screen_order[i] == screen_id then
            table.remove(M._state.screen_order, i)
        end
    end

    for r = #M._state.screen_grid.rows, 1, -1 do
        local row = M._state.screen_grid.rows[r]
        for c = #row, 1, -1 do
            if row[c] == screen_id then
                table.remove(row, c)
            end
        end
        if #row == 0 then
            table.remove(M._state.screen_grid.rows, r)
        end
    end

    _recalc_offsets()

    if dOS.TaskbarManager and dOS.TaskbarManager.refresh_mirror_taskbars then
        dOS.TaskbarManager.refresh_mirror_taskbars(dOS)
    end

    print("[DWM] Screen " .. screen_id .. " disconnected.")
end

--- CONNECT

function M.connect_screens(dOS)
    local all_wrappers = dOS.HardwareManager.requestAllScreens()
    local added = 0

    for _, hw_w in ipairs(all_wrappers) do
        if M._state.screen_by_hw[hw_w.obj] then
            continue
        end

        local max_id = 0
        for id in pairs(M._state.screens) do
            if id > max_id then
                max_id = id
            end
        end

        local new_id = max_id + 1
        local dims = hw_w.obj:GetDimensions() or Vector2.new(800, 600)

        local ctx = {
            id = new_id,
            hw = hw_w.obj,
            guid = hw_w.guid,
            dimensions = dims,
            screen_x_offset = M._state.virtual_width,
            is_primary = false,
            desktop_bg = nil,
            program_holder = nil,
            taskbar_frame = nil,
            capture_shield = nil,
            cursor_conn = nil,
            windows = {},
        }

        M._state.screens[new_id] = ctx
        M._state.screen_by_hw[hw_w.obj] = ctx

        if #M._state.screen_grid.rows == 0 then
            table.insert(M._state.screen_grid.rows, { new_id })
        else
            table.insert(M._state.screen_grid.rows[1], new_id)
        end

        _create_bg(dOS, ctx)
        _create_secondary_ph(dOS, ctx)

        if dOS.TaskbarManager.create_mirror_taskbar then
            dOS.TaskbarManager.create_mirror_taskbar(dOS, ctx)
        end

        if
            dOS.VirtualDesktopManager
            and dOS.VirtualDesktopManager.create_taskbar_button
        then
            task.spawn(function()
                task.wait(0.1)
                local proxy = M.make_screen_proxy(dOS, ctx)
                dOS.VirtualDesktopManager.create_taskbar_button(proxy)
            end)
        end

        if dOS.DragManager and dOS.DragManager.BindInputEventsForScreen then
            pcall(dOS.DragManager.BindInputEventsForScreen, dOS, ctx)
        end

        local ls = dOS.LockScreenManager
            and dOS.LockScreenManager.lockscreen_state

        if ls and ls.is_locked then
            local proxy = M.make_screen_proxy(dOS, ctx)
            local ov = dOS.create_gui_element(proxy, "Frame", {
                Name = "LockScreen_Secondary_S" .. new_id,
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = Color3.new(0, 0, 0),
                BackgroundTransparency = 0,
                ZIndex = dOS.Z_INDEX.LOCKSCREEN,
                BorderSizePixel = 0,
            })

            if ov then
                dOS.create_gui_element(proxy, "TextLabel", {
                    Parent = ov,
                    Text = "Screen Locked",
                    TextColor3 = Color3.new(1, 1, 1),
                    BackgroundTransparency = 1,
                    Size = UDim2.fromScale(1, 1),
                    TextSize = 24,
                    Font = dOS.FONT_BOLD,
                    ZIndex = dOS.Z_INDEX.LOCKSCREEN + 1,
                })
                table.insert(ls.secondary_overlays, ov)
            end
        end

        added += 1
        print(
            string.format(
                "[DWM] Connected new screen %d: %s %dx%d",
                new_id,
                hw_w.name,
                dims.X,
                dims.Y
            )
        )
    end

    if added > 0 then
        _recalc_offsets()
    end

    return added
end

--- REORDER

function M.reorder_screens(_, new_order)
    if #new_order ~= #M._state.screen_order then
        warn("[DWM] reorder_screens: count mismatch")
        return
    end

    M._state.screen_grid = { rows = { new_order } }
    _recalc_offsets()
    print("[DWM] Screen order: " .. table.concat(new_order, " -> "))
end

function M.reorder_screens_2d(_, grid)
    if type(grid) ~= "table" or type(grid.rows) ~= "table" then
        warn("[DWM] reorder_screens_2d: invalid grid")
        return
    end

    -- copy so callers can keep mutating their table
    local copy = { rows = {} }
    for _, row in ipairs(grid.rows) do
        local r = {}
        for _, sid in ipairs(row) do
            table.insert(r, sid)
        end
        if #r > 0 then
            table.insert(copy.rows, r)
        end
    end

    M._state.screen_grid = copy
    _recalc_offsets()

    -- one line per row
    for r, row in ipairs(copy.rows) do
        print(string.format("[DWM] Row %d: %s", r, table.concat(row, " -> ")))
    end
end

--- BACKGROUND

function M.refresh_desktop_backgrounds(dOS)
    for _, ctx in pairs(M._state.screens) do
        if ctx.desktop_bg and ctx.desktop_bg.Parent then
            pcall(function()
                ctx.desktop_bg:Destroy()
            end)
            ctx.desktop_bg = nil
        end

        _create_bg(dOS, ctx)

        if ctx.is_primary then
            _wire_primary_click(dOS, ctx)
        end
    end
end

--- LOCKSCREEN

local function _create_secondary_lock_overlays(dOS)
    if
        dOS.LockScreenManager
        and dOS.LockScreenManager.update_secondary_overlays
    then
        dOS.LockScreenManager.update_secondary_overlays(dOS)
    end
end

--- INIT

function M.init(dOS, special_for_tb, on_start_click, on_desktop_ready)
    M._state = _fresh_state()
    dOS.DWM = M
    dOS.screens = M._state.screens

    if not dOS._boot_screen_hw then
        if not M.is_virtual_screen(dOS.screen) then
            dOS._boot_screen_hw = dOS.screen
        end
    end

    if not M._virtual_screen then
        M._virtual_screen = M.make_virtual_screen()
    end

    local vs = M._virtual_screen
    dOS.screen = vs

    if not dOS._cge_wrapped_by_dwm then
        local _orig_cge = dOS.create_gui_element

        dOS.create_gui_element = function(dOS_arg, class, props, ...)
            if props and M.is_virtual_screen(props.Parent) then
                local hw = M._state._screen_hw_override
                    or (
                        M._state.screens[M._state.primary_id]
                        and M._state.screens[M._state.primary_id].hw
                    )

                if hw then
                    props.Parent = hw
                end
            end

            return _orig_cge(dOS_arg, class, props, ...)
        end

        dOS._cge_wrapped_by_dwm = true
    end

    local all_wrappers = dOS.HardwareManager.requestAllScreens()
    if #all_wrappers == 0 then
        warn("[DWM] FATAL: No screens found.")
        return false
    end

    local function _is_boot_screen(hw_w)
        if dOS._boot_screen_hw then
            return hw_w.obj == dOS._boot_screen_hw
        end
        return false
    end

    local sorted = {}
    local primary_found = false

    for _, hw_w in ipairs(all_wrappers) do
        if _is_boot_screen(hw_w) then
            table.insert(sorted, 1, hw_w)
            primary_found = true
        else
            table.insert(sorted, hw_w)
        end
    end

    if not primary_found and #sorted > 0 then
        dOS._boot_screen_hw = sorted[1].obj
    end

    local x_off = 0
    for i, hw_w in ipairs(sorted) do
        local dims = hw_w.obj:GetDimensions()
        if not dims then
            dims = (i == 1) and dOS.screen_dimensions or Vector2.new(800, 600)
            warn(
                string.format(
                    "[DWM] GetDimensions() failed for screen %d.",
                    i
                )
            )
        end

        local ctx = {
            id = i,
            hw = hw_w.obj,
            guid = hw_w.guid,
            dimensions = dims,
            screen_x_offset = x_off,
            screen_y_offset = 0,
            row_index = 1,
            col_index = i,
            is_primary = (i == 1),
            desktop_bg = nil,
            program_holder = nil,
            taskbar_frame = nil,
            capture_shield = nil,
            cursor_conn = nil,
            windows = {},
        }

        M._state.screens[i] = ctx
        M._state.screen_by_hw[hw_w.obj] = ctx

        if not M._state.screen_grid.rows[1] then
            M._state.screen_grid.rows[1] = {}
        end

        table.insert(M._state.screen_grid.rows[1], i)
        x_off += dims.X

        print(
            string.format(
                "[DWM] Screen %d: %s guid=%s %dx%d%s vx=%d",
                i,
                hw_w.name,
                hw_w.guid,
                dims.X,
                dims.Y,
                i == 1 and " [PRIMARY]" or "",
                ctx.screen_x_offset
            )
        )
    end

    _recalc_offsets()

    local primary_ctx_init = M._state.screens[1]
    if primary_ctx_init then
        dOS.screen_dimensions = primary_ctx_init.dimensions
    end

    for _, ctx in ipairs(M._state.screens) do
        _create_bg(dOS, ctx)
    end

    local _raw_start = on_start_click
    local _wrapped_start = function()
        if not _raw_start then
            return
        end

        local sid = M._state.last_start_screen_id or 1
        M._state.last_start_screen_id = nil

        local ctx = M._state.screens[sid]
        if ctx and not ctx.is_primary then
            local prev_d = dOS.screen_dimensions
            M._state._screen_hw_override = ctx.hw
            dOS.screen_dimensions = ctx.dimensions

            local ok, err = pcall(_raw_start)
            M._state._screen_hw_override = nil
            dOS.screen_dimensions = prev_d

            if not ok then
                warn("[DWM] _wrapped_start error: " .. tostring(err))
            end
        else
            M._state._screen_hw_override = nil
            _raw_start()
        end
    end

    local primary_ctx = M._state.screens[1]
    local tb, ph = dOS.TaskbarManager.init(dOS, special_for_tb, _wrapped_start)
    if not tb or not ph then
        warn("[DWM] FATAL: TaskbarManager.init() failed.")
        return false
    end

    primary_ctx.taskbar_frame = tb
    primary_ctx.program_holder = ph
    dOS.taskbar_frame = tb
    dOS.program_holder_frame = ph
    dOS.TaskbarManager.taskbar_manager._on_start_click = _wrapped_start

    _wire_primary_click(dOS, primary_ctx)

    for i = 2, #M._state.screens do
        local ctx = M._state.screens[i]
        _create_secondary_ph(dOS, ctx)

        if dOS.TaskbarManager.create_mirror_taskbar then
            dOS.TaskbarManager.create_mirror_taskbar(dOS, ctx)
        end
    end

    if dOS.DragManager.BindInputEventsForScreen then
        for _, ctx in ipairs(M._state.screens) do
            local ok, err =
                pcall(dOS.DragManager.BindInputEventsForScreen, dOS, ctx)

            if not ok then
                warn(
                    string.format(
                        "[DWM] BindInputEventsForScreen screen %d: %s",
                        ctx.id,
                        tostring(err)
                    )
                )
            end
        end
    end

    _create_secondary_lock_overlays(dOS)

    M._state.initialized = true

    print(
        string.format(
            "[DWM] Ready. %d screen(s), vw=%dpx",
            M.get_screen_count(),
            M._state.virtual_width
        )
    )

    if on_desktop_ready then
        on_desktop_ready()
    end

    return true
end

--- SHUTDOWN

function M.shutdown(dOS)
    for sid, ctx in pairs(M._state.screens) do
        if sid == M._state.primary_id then
            continue
        end

        if ctx.cursor_conn then
            pcall(function()
                ctx.cursor_conn:Disconnect()
            end)
            ctx.cursor_conn = nil
        end

        if ctx.desktop_bg and ctx.desktop_bg.Parent then
            pcall(function()
                ctx.desktop_bg:Destroy()
            end)
            ctx.desktop_bg = nil
        end

        if ctx.taskbar_frame and ctx.taskbar_frame.Parent then
            pcall(function()
                ctx.taskbar_frame:Destroy()
            end)
            ctx.taskbar_frame = nil
        end

        if ctx.program_holder and ctx.program_holder.Parent then
            pcall(function()
                ctx.program_holder:Destroy()
            end)
            ctx.program_holder = nil
        end

        if ctx.capture_shield and ctx.capture_shield.Parent then
            pcall(function()
                ctx.capture_shield:Destroy()
            end)
            ctx.capture_shield = nil
        end
    end

    M._state = _fresh_state()

    if dOS then
        dOS.DWM = nil
        dOS.screens = nil
    end

    print("[DWM] Shutdown.")
end

return M

-- EOF