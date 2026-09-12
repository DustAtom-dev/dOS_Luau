--[[
    "Drag manager module for dOS"
    
    @module drag_manager
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
local fromOffset = UDim2.fromOffset
local clamp = math.clamp

local EDGE_ZONE = 40
local EDGE_HOLD_S = 0.55
local EDGE_GLOW_W = 6
local EDGE_GLOW_Z = 1999998
local TRANSFER_COOLDOWN = 1.5

--- STATE

M.drag_manager = {
    is_dragging = false,
    is_resizing = false,
    resize_dir = nil,
    window = nil,
    start_window_pos = nil,
    start_window_size = nil,
    latest_cursor_pos = nil,
    cached_window_size = nil,
    cached_parent_size = nil,
    dragger_id = nil,
    start_cursor_pos = { X = nil, Y = nil },

    source_screen_id = 1,
    start_virtual_x = 0,
    latest_virtual_x = 0,
    latest_virtual_y = 0,
    latest_cursor_pos_virtual = nil,
    last_transfer_time = 0,

    capture_shield = nil,

    active_slider = {
        is_dragging = false,
        dragger_id = nil,
        handle = nil,
        callback = nil,
    },
    taskbar_drag = {
        active = false,
        callback = nil,
        cursor_conn = nil,
    },

    edge_transfer = {
        hold_start = 0,
        target_id = nil,
        side = nil,
        indicator = nil,
        fill = nil,
    },

    custom_callback = nil,
    cb_taskbar_on_end = nil,
}

--- SHIELDS

local function _set_all_shields(dOS, state)
    local alpha = 1
    if state and dOS.os_settings and dOS.os_settings.show_capture_overlay then
        alpha = 0.5
    end

    if dOS.DWM and dOS.DWM._state then
        for _, ctx in pairs(dOS.DWM._state.screens) do
            local s = ctx.capture_shield
            if s then
                s.Visible = state
                s.Active = state
                s.BackgroundTransparency = alpha
            end
        end
    else
        local s = M.drag_manager.capture_shield
        if s then
            s.Visible = state
            s.Active = state
            s.BackgroundTransparency = alpha
        end
    end
end

--- EDGE

local function _show_edge_indicator(dOS, ctx, side)
    local dm = M.drag_manager

    if dm.edge_transfer.indicator and dm.edge_transfer.indicator.Parent then
        pcall(function()
            dm.edge_transfer.indicator:Destroy()
        end)
    end

    dm.edge_transfer.indicator = nil
    dm.edge_transfer.fill = nil

    if not ctx or not dOS.DWM then
        return
    end

    local proxy = dOS.DWM.make_screen_proxy(dOS, ctx)
    local accent = (dOS.THEME and dOS.THEME.ACCENT)
        or Color3.fromRGB(100, 149, 237)

    local bar_size, bar_pos
    if side == "left" then
        bar_size = UDim2.new(0, EDGE_GLOW_W, 1, 0)
        bar_pos = UDim2.fromOffset(0, 0)
    elseif side == "right" then
        bar_size = UDim2.new(0, EDGE_GLOW_W, 1, 0)
        bar_pos = UDim2.new(1, -EDGE_GLOW_W, 0, 0)
    elseif side == "top" then
        bar_size = UDim2.new(1, 0, 0, EDGE_GLOW_W)
        bar_pos = UDim2.fromOffset(0, 0)
    else -- "bottom"
        bar_size = UDim2.new(1, 0, 0, EDGE_GLOW_W)
        bar_pos = UDim2.new(0, 0, 1, -EDGE_GLOW_W)
    end

    local bar = dOS.create_gui_element(proxy, "Frame", {
        Name = "EdgeTransferIndicator",
        Position = bar_pos,
        Size = bar_size,
        BackgroundColor3 = accent,
        BackgroundTransparency = 0.45,
        ZIndex = EDGE_GLOW_Z,
        BorderSizePixel = 0,
    })

    if not bar then
        return
    end

    -- fill grows along the long axis
    local fill_props
    if side == "left" or side == "right" then
        fill_props = {
            Parent = bar,
            Size = UDim2.fromScale(1, 0),
            Position = UDim2.fromScale(0, 1),
            AnchorPoint = Vector2.new(0, 1),
        }
    else
        fill_props = {
            Parent = bar,
            Size = UDim2.fromScale(0, 1),
            Position = UDim2.fromScale(0, 0),
            AnchorPoint = Vector2.new(0, 0),
        }
    end

    fill_props.BackgroundColor3 = accent
    fill_props.BackgroundTransparency = 0
    fill_props.ZIndex = EDGE_GLOW_Z + 1
    fill_props.BorderSizePixel = 0

    local fill = dOS.create_gui_element(proxy, "Frame", fill_props)

    dm.edge_transfer.indicator = bar
    dm.edge_transfer.fill = fill
    dm.edge_transfer._axis = (side == "left" or side == "right") and "y" or "x"
end

local function _update_edge_progress(t)
    local et = M.drag_manager.edge_transfer
    local fill = et.fill
    if not (fill and fill.Parent) then
        return
    end

    t = math.clamp(t, 0, 1)
    if et._axis == "x" then
        fill.Size = UDim2.fromScale(t, 1)
    else
        fill.Size = UDim2.fromScale(1, t)
    end
end

local function _hide_edge_indicator()
    local et = M.drag_manager.edge_transfer

    if et.indicator and et.indicator.Parent then
        pcall(function()
            et.indicator:Destroy()
        end)
    end

    et.indicator = nil
    et.fill = nil
    et.hold_start = 0
    et.target_id = nil
    et.side = nil
end

--- VIRTUAL

local function _to_vx(dOS, screen_id, local_x)
    if dOS.DWM then
        return dOS.DWM.to_virtual_x(screen_id, local_x)
    end
    return local_x
end

local function _to_vy(dOS, screen_id, local_y)
    if dOS.DWM and dOS.DWM.to_virtual_y then
        return dOS.DWM.to_virtual_y(screen_id, local_y)
    end
    return local_y
end

local function _get_neighbors_4(dOS, src_id)
    if not dOS.DWM then
        return {}
    end

    if dOS.DWM.get_neighbors then
        return dOS.DWM.get_neighbors(src_id)
    end

    -- fallback
    local order = dOS.DWM._state and dOS.DWM._state.screen_order or {}
    for i, sid in ipairs(order) do
        if sid == src_id then
            return {
                left = order[i - 1],
                right = order[i + 1],
            }
        end
    end

    return {}
end

--- DRAG

function M.start_drag(dOS, window, cursor, screen_ctx_hint)
    local dm = M.drag_manager

    if dm.is_dragging or dm.is_resizing or dm.taskbar_drag.active then
        return
    end

    -- find the source screen
    local src_id
    if screen_ctx_hint then
        src_id = screen_ctx_hint.id
    elseif dOS.DWM and cursor then
        for sid, ctx in pairs(dOS.DWM._state.screens) do
            local ok, curs = pcall(function()
                return ctx.hw:GetCursors()
            end)
            if ok and curs then
                for _, c in pairs(curs) do
                    if c == cursor then
                        src_id = sid
                        break
                    end
                end
            end
            if src_id then
                break
            end
        end

        if not src_id then
            local meta = dOS.window_metadata and dOS.window_metadata[window]
            src_id = (meta and meta.screen_id) or dOS.DWM._state.primary_id or 1
        end
    elseif dOS.DWM then
        local meta = dOS.window_metadata and dOS.window_metadata[window]
        src_id = (meta and meta.screen_id) or dOS.DWM._state.primary_id or 1
    else
        src_id = 1
    end

    -- write the fixed id back
    if dOS.window_metadata and dOS.window_metadata[window] then
        dOS.window_metadata[window].screen_id = src_id
    end

    if dOS.DWM and dOS.DWM._state then
        dOS.DWM._state.win_screen[window] = src_id
    end

    local ph = nil
    if dOS.DWM then
        local ctx = dOS.DWM.get_screen_ctx_by_id(src_id)
        ph = ctx and ctx.program_holder
    end
    ph = ph or dOS.program_holder_frame

    local vx = _to_vx(dOS, src_id, cursor.X)
    local vy = _to_vy(dOS, src_id, cursor.Y)

    dm.is_dragging = true
    dm.window = window
    dm.dragger_id = cursor.UserId
    dm.start_cursor_pos = cursor
    dm.latest_cursor_pos = cursor
    dm.start_window_pos = window.Position
    dm.cached_window_size = window.AbsoluteSize
    dm.cached_parent_size = ph and ph.AbsoluteSize or dOS.screen_dimensions
    dm.source_screen_id = src_id
    dm.start_virtual_x = vx
    dm.latest_virtual_x = vx
    dm.start_virtual_y = vy
    dm.latest_virtual_y = vy
    dm.last_transfer_time = dm.last_transfer_time or 0

    window.ZIndex = dOS.Z_INDEX.WINDOW_DRAGGING
    _set_all_shields(dOS, true)
end

--- RESIZE

function M.start_resize(dOS, window, dir, cursor)
    local dm = M.drag_manager

    if dm.is_dragging or dm.is_resizing or dm.taskbar_drag.active then
        return
    end

    local meta = dOS.window_metadata and dOS.window_metadata[window]
    local src_id = (meta and meta.screen_id)
        or (dOS.DWM and dOS.DWM._state.primary_id)
        or 1

    local vx = _to_vx(dOS, src_id, cursor.X)
    local vy = _to_vy(dOS, src_id, cursor.Y)

    dm.is_resizing = true
    dm.resize_dir = dir
    dm.window = window
    dm.dragger_id = cursor.UserId
    dm.start_cursor_pos = cursor
    dm.latest_cursor_pos = cursor
    dm.start_window_size = window.Size
    dm.start_virtual_x = vx
    dm.latest_virtual_x = vx
    dm.start_virtual_y = vy
    dm.latest_virtual_y = vy

    window.ZIndex = dOS.Z_INDEX.WINDOW_DRAGGING
    _set_all_shields(dOS, true)
end

--- SLIDER

function M.start_slider_drag(dOS, handle, callback, cursor)
    local dm = M.drag_manager

    if dm.active_slider.is_dragging then
        return
    end

    dm.active_slider.is_dragging = true
    dm.active_slider.dragger_id = cursor.UserId
    dm.active_slider.handle = handle
    dm.active_slider.callback = callback

    _set_all_shields(dOS, true)
end

function M.start_taskbar_drag(dOS, callback, cb_on_end)
    local dm = M.drag_manager

    dm.taskbar_drag.active = true
    dm.taskbar_drag.callback = callback
    dm.cb_taskbar_on_end = cb_on_end

    _set_all_shields(dOS, true)

    if dm.taskbar_drag.cursor_conn then
        pcall(function()
            dm.taskbar_drag.cursor_conn:Disconnect()
        end)
        dm.taskbar_drag.cursor_conn = nil
    end

    dm.taskbar_drag.cursor_conn = dOS.screen.CursorMoved:Connect(function(c)
        if dm.taskbar_drag.active and dm.taskbar_drag.callback then
            dm.taskbar_drag.callback(c.X, c.Y)
        end
    end)
end

function M.stop_taskbar_drag(dOS)
    local dm = M.drag_manager

    dm.taskbar_drag.active = false
    dm.taskbar_drag.callback = nil

    if dm.taskbar_drag.cursor_conn then
        pcall(function()
            dm.taskbar_drag.cursor_conn:Disconnect()
        end)
        dm.taskbar_drag.cursor_conn = nil
    end

    if dm.cb_taskbar_on_end then
        pcall(dm.cb_taskbar_on_end)
        dm.cb_taskbar_on_end = nil
    end

    _set_all_shields(dOS, false)
end

--- STOP

function M.stop_drag(dOS)
    local dm = M.drag_manager

    if dm.window then
        dm.window.ZIndex = dOS.Z_INDEX.WINDOW_ACTIVE
    end

    _hide_edge_indicator()

    dm.is_dragging = false
    dm.is_resizing = false
    dm.window = nil
    dm.dragger_id = nil
    dm.source_screen_id = 1
    dm.active_slider.is_dragging = false
    dm.active_slider.dragger_id = nil
    dm.active_slider.callback = nil
    dm.taskbar_drag.active = false
    dm.taskbar_drag.callback = nil

    if dm.taskbar_drag.cursor_conn then
        pcall(function()
            dm.taskbar_drag.cursor_conn:Disconnect()
        end)
        dm.taskbar_drag.cursor_conn = nil
    end

    if dm.cb_taskbar_on_end then
        pcall(dm.cb_taskbar_on_end)
        dm.cb_taskbar_on_end = nil
    end

    _set_all_shields(dOS, false)

    if dm.custom_callback then
        dm.custom_callback()
    end

    dm.custom_callback = nil
end

--- MAINLOOP

function M.SpawnRenderLoop(dOS)
    task.spawn(function()
        local dm = M.drag_manager

        while true do
            -- window drag
            if dm.is_dragging and dm.window and dm.latest_cursor_pos then
                local dx = dm.latest_virtual_x - dm.start_virtual_x
                local syv = dm.start_virtual_y or (dm.start_cursor_pos.Y or 0)
                local dy = dm.latest_virtual_y - syv

                local tx = dm.start_window_pos.X.Offset + dx
                local ty = dm.start_window_pos.Y.Offset + dy

                local cx = dm.window.Position.X.Offset
                local cy = dm.window.Position.Y.Offset

                local lf = dOS.os_settings.global_lerp_factor
                local ps = dm.cached_parent_size
                local ws = dm.cached_window_size

                dm.window.Position = fromOffset(
                    clamp(cx + (tx - cx) * lf, 0, ps.X - ws.X),
                    clamp(cy + (ty - cy) * lf, 0, ps.Y - ws.Y)
                )

                -- cross screen edge transfer
                local multi = dOS.DWM and M.drag_manager.source_screen_id
                if multi then
                    -- snap to the screen that actually contains the cursor
                    local current_screen_id
                    if dOS.DWM.from_virtual_pos then
                        current_screen_id = dOS.DWM.from_virtual_pos(
                            dm.latest_virtual_x,
                            dm.latest_virtual_y
                        )
                    else
                        current_screen_id = dOS.DWM.from_virtual_x(dm.latest_virtual_x)
                    end

                    if
                        current_screen_id
                        and current_screen_id ~= dm.source_screen_id
                    then
                        local wf = dm.window
                        dOS.DWM.move_window_to_screen(
                            dOS,
                            wf,
                            current_screen_id
                        )
                        continue
                    end

                    local et = dm.edge_transfer
                    local now = os.clock()
                    local on_cd = (now - dm.last_transfer_time) < TRANSFER_COOLDOWN

                    if not on_cd then
                        local win_x = dm.window.Position.X.Offset
                        local win_y = dm.window.Position.Y.Offset
                        local ph_w = ps.X
                        local ph_h = ps.Y
                        local win_w = ws.X
                        local win_h = ws.Y
                        local src_id = dm.source_screen_id

                        local nb = _get_neighbors_4(dOS, src_id)
                        local target_id, edge_side

                        if win_x >= ph_w - win_w - EDGE_ZONE and nb.right then
                            target_id = nb.right
                            edge_side = "right"
                        elseif win_x <= EDGE_ZONE and nb.left then
                            target_id = nb.left
                            edge_side = "left"
                        elseif win_y <= EDGE_ZONE and nb.top then
                            target_id = nb.top
                            edge_side = "top"
                        elseif
                            win_y >= ph_h - win_h - EDGE_ZONE and nb.bottom
                        then
                            target_id = nb.bottom
                            edge_side = "bottom"
                        end

                        if target_id then
                            local src_ctx = dOS.DWM.get_screen_ctx_by_id(src_id)
                            if et.target_id ~= target_id then
                                et.hold_start = now
                                et.target_id = target_id
                                et.side = edge_side
                                _show_edge_indicator(dOS, src_ctx, edge_side)
                            else
                                local elapsed = now - et.hold_start
                                if elapsed >= EDGE_HOLD_S then
                                    -- transfer
                                    local wf = dm.window
                                    M.stop_drag(dOS)
                                    dm.last_transfer_time = os.clock()

                                    task.spawn(function()
                                        if wf and wf.Parent and dOS.DWM then
                                            dOS.DWM.transfer_window_animated(
                                                dOS,
                                                wf,
                                                target_id
                                            )
                                        end
                                    end)

                                    task.wait()
                                    continue
                                else
                                    _update_edge_progress(elapsed / EDGE_HOLD_S)
                                end
                            end
                        else
                            if et.target_id then
                                _hide_edge_indicator()
                            end
                        end
                    end
                end

            -- window resize
            elseif dm.is_resizing and dm.window and dm.latest_cursor_pos then
                local meta = dOS.window_metadata[dm.window]
                local min_w = meta and meta.min_width or 150
                local min_h = meta and meta.min_height or 100

                local dx = dm.latest_virtual_x - dm.start_virtual_x
                local syv = dm.start_virtual_y or (dm.start_cursor_pos.Y or 0)
                local dy = dm.latest_virtual_y - syv

                local tw = dm.start_window_size.X.Offset
                local th = dm.start_window_size.Y.Offset
                local dir = dm.resize_dir
                local lf = dOS.os_settings.global_lerp_factor

                if dir == "X" or dir == "XY" then
                    tw = math.max(min_w, tw + dx)
                end

                if dir == "Y" or dir == "XY" then
                    th = math.max(min_h, th + dy)
                end

                local cw = dm.window.Size.X.Offset
                local ch = dm.window.Size.Y.Offset

                dm.window.Size = fromOffset(
                    cw + (tw - cw) * lf,
                    ch + (th - ch) * lf
                )
            end

            task.wait()
        end
    end)
end

--- INPUT

local function _on_cursor_moved(dOS, screen_ctx, cursor)
    local dm = M.drag_manager
    local uid = cursor.UserId
    local cx = cursor.X
    local cy = cursor.Y
    local vx = _to_vx(dOS, screen_ctx.id, cx)
    local vy = _to_vy(dOS, screen_ctx.id, cy)

    if (dm.is_dragging or dm.is_resizing) and uid == dm.dragger_id then
        dm.latest_cursor_pos = cursor
        dm.latest_virtual_x = vx
        dm.latest_virtual_y = vy
        dm.latest_cursor_pos_virtual = {
            X = vx,
            Y = vy,
            UserId = uid,
        }
    elseif
        dm.active_slider.is_dragging and uid == dm.active_slider.dragger_id
    then
        if dm.active_slider.callback then
            dm.active_slider.callback(cx)
        end
    elseif dm.taskbar_drag.active then
        local sw = screen_ctx.dimensions.X
        local sh = screen_ctx.dimensions.Y
        if cx < 0 or cx > sw or cy < 0 or cy > sh then
            M.stop_drag(dOS)
        end
    end
end

function M.BindInputEventsForScreen(dOS, screen_ctx)
    local proxy = (dOS.DWM and dOS.DWM.make_screen_proxy(dOS, screen_ctx))
        or dOS

    local shield = dOS.create_gui_element(proxy, "TextButton", {
        Name = "DragCaptureShield_S" .. tostring(screen_ctx.id),
        Text = "",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 2000000,
        Active = false,
        Visible = false,
    })

    if shield then
        screen_ctx.capture_shield = shield
        if screen_ctx.is_primary then
            M.drag_manager.capture_shield = shield
        end

        shield.MouseButton1Up:Connect(function()
            M.stop_drag(dOS)
            M.stop_taskbar_drag(dOS)
        end)
    else
        warn(
            "[DragManager] No capture shield for screen "
                .. tostring(screen_ctx.id)
        )
    end

    local conn = screen_ctx.hw.CursorMoved:Connect(function(cursor)
        _on_cursor_moved(dOS, screen_ctx, cursor)
    end)
    screen_ctx.cursor_conn = conn
end

function M.BindInputEventsOnce(dOS)
    if not dOS.screen then
        return
    end

    if dOS.DWM and dOS.DWM._state and dOS.DWM._state.initialized then
        return
    end

    M.BindInputEventsForScreen(dOS, {
        id = 1,
        hw = dOS.screen,
        dimensions = dOS.screen_dimensions or Vector2.new(800, 600),
        is_primary = true,
        screen_x_offset = 0,
        program_holder = dOS.program_holder_frame,
        capture_shield = nil,
        cursor_conn = nil,
    })
end

return M

-- EOF