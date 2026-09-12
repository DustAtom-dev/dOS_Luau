--[[
    "Window module for dOS"
    
    @module window
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

--- CURSOR

local function _hw_for_node(dOS, node)
    if not (dOS.DWM and dOS.DWM._state) then
        return dOS.screen
    end

    local n = node
    while n do
        local sid = dOS.DWM._state.win_screen[n]
        if sid then
            local ctx = dOS.DWM._state.screens[sid]
            if ctx and ctx.hw then
                return ctx.hw
            end
        end
        n = n.Parent
    end

    local primary = dOS.DWM._state.screens[dOS.DWM._state.primary_id]
    return (primary and primary.hw) or dOS.screen
end

local function _find_cursor(dOS, x, y, tol_or_node, maybe_tol)
    -- back-compat -- old form (dOS, x, y, tol)
    local prefer_node, tol
    if type(tol_or_node) == "number" or tol_or_node == nil then
        tol = tol_or_node or 50
        prefer_node = nil
    else
        prefer_node = tol_or_node
        tol = maybe_tol or 50
    end

    local ref = Vector2.new(x, y)

    local function _scan(hw)
        if not hw then
            return nil
        end

        local ok, cursors = pcall(function()
            return hw:GetCursors()
        end)

        if not ok or not cursors then
            return nil
        end

        for _, cursor in pairs(cursors) do
            if (ref - Vector2.new(cursor.X, cursor.Y)).Magnitude < tol then
                return cursor
            end
        end

        return nil
    end

    -- prefer the click target's screen
    if prefer_node then
        local hit = _scan(_hw_for_node(dOS, prefer_node))
        if hit then
            return hit
        end
    end

    -- else search all screens
    local hws = { dOS.screen }
    if dOS.DWM and dOS.DWM._state then
        for _, ctx in pairs(dOS.DWM._state.screens) do
            if ctx.hw ~= dOS.screen then
                table.insert(hws, ctx.hw)
            end
        end
    end

    for _, hw in ipairs(hws) do
        local hit = _scan(hw)
        if hit then
            return hit
        end
    end

    return nil
end

local function _dims_for_window(dOS, win_frame)
    if dOS.DWM then
        local meta = dOS.window_metadata and dOS.window_metadata[win_frame]
        local sid = meta and meta.screen_id
        if sid then
            local ctx = dOS.DWM.get_screen_ctx_by_id(sid)
            if ctx then
                return ctx.dimensions
            end
        end
    end

    return dOS.screen_dimensions
end

--- FOCUS

function M.set_active_window(dOS, win_frame)
    if not win_frame or not win_frame.Parent then
        return
    end

    if win_frame == dOS.active_window_frame then
        return
    end

    if dOS.active_window_frame and dOS.active_window_frame.Parent then
        dOS.active_window_frame.ZIndex = dOS.Z_INDEX.WINDOW_INACTIVE
    end

    win_frame.ZIndex = dOS.Z_INDEX.WINDOW_ACTIVE
    dOS.active_window_frame = win_frame

    if dOS.TaskbarManager then
        dOS.TaskbarManager.on_window_focused(dOS, win_frame)
    end
end

--- CREATE

local window_id_counter = 0

function M.create_basic_window(
    dOS,
    title_text,
    width,
    height,
    is_closable,
    is_draggable,
    is_maximizable,
    is_minimizable,
    min_width,
    min_height,
    app_metadata
)
    if not dOS then
        return nil
    end

    window_id_counter += 1
    local window_id = "dOS_Window_" .. window_id_counter

    local creation_screen_id = (
        dOS.DWM
        and dOS.DWM._state
        and dOS.DWM._state.primary_id
    ) or 1

    local initial_x = (dOS.program_holder_frame.AbsoluteSize.X / 2)
        - (width / 2)
        + math.random(-30, 30)
    local initial_y = (dOS.program_holder_frame.AbsoluteSize.Y / 2)
        - (height / 2)
        + math.random(-30, 30)

    local win_frame = dOS.create_gui_element(dOS, "Frame", {
        Name = window_id,
        Parent = dOS.program_holder_frame,
        ZIndex = dOS.Z_INDEX.WINDOW_INACTIVE,
        BackgroundColor3 = dOS.THEME.WINDOW_BG,
        BorderColor3 = dOS.THEME.BORDER_HIGHLIGHT,
        Active = true,
    })

    if not win_frame then
        return nil, nil
    end

    dOS.create_gui_element(dOS, "UICorner", {
        Name = "WindowCorner",
        Parent = win_frame,
        CornerRadius = UDim.new(0, 10),
    })

    win_frame.AnchorPoint = Vector2.new(0.5, 0.5)
    win_frame.Size = UDim2.fromOffset(0, 0)
    win_frame.Position =
        UDim2.fromOffset(initial_x + width / 2, initial_y + height / 2)
    win_frame.ClipsDescendants = true
    win_frame.BackgroundTransparency = 1

    local open_info =
        dOS.TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    dOS.Tween
        .new(
            win_frame,
            {
                Size = UDim2.fromOffset(width, height),
                BackgroundTransparency = 0,
            },
            open_info
        )
        :Play()

    task.spawn(function()
        task.wait(0.5)
        if not win_frame or not win_frame.Parent then
            return
        end
        win_frame.AnchorPoint = Vector2.new(0, 0)
        win_frame.Position = UDim2.fromOffset(initial_x, initial_y)
    end)

    dOS.window_metadata[win_frame] = {
        title = title_text,
        is_draggable = is_draggable,
        is_maximizable = is_maximizable,
        is_minimizable = is_minimizable,
        is_closable = is_closable,
        is_maximized = false,
        is_minimized = false,
        restore_position = UDim2.fromOffset(initial_x, initial_y),
        restore_size = UDim2.fromOffset(width, height),
        taskbar_icon = app_metadata and app_metadata.icon_id or nil,
        maximize_button = nil,
        min_width = min_width or 150,
        min_height = min_height or 100,
        app_module_key = app_metadata and app_metadata.module_key or nil,
        app_category = app_metadata and app_metadata.category or nil,
        screen_id = creation_screen_id,
    }

    table.insert(dOS.all_windows, win_frame)

    -- register with DWM
    if dOS.DWM then
        dOS.DWM.register_window(dOS, win_frame, creation_screen_id)
    end

    task.wait()
    local title_bar_height = 28

    local title_bar = dOS.create_gui_element(dOS, "TextButton", {
        Name = "TitleBar",
        Text = "",
        Parent = win_frame,
        BackgroundColor3 = dOS.THEME.TITLE_BAR_BG,
        Size = UDim2.new(1, 0, 0, title_bar_height),
        Position = UDim2.fromOffset(0, 0),
        Active = true,
    })
    title_bar.ClipsDescendants = true

    task.wait()

    local content_area = dOS.create_gui_element(dOS, "Frame", {
        Name = "ContentArea",
        Parent = win_frame,
        BackgroundColor3 = dOS.THEME.WINDOW_BG,
        Size = UDim2.new(1, 0, 1, -title_bar_height),
        Position = UDim2.fromOffset(0, title_bar_height),
    })

    task.wait()

    if not title_bar or not content_area then
        win_frame:Destroy()
        return nil, nil
    end

    -- resize handles
    local RESIZE_THICK = 8

    -- TODO: make them outside the window no in because it can overlap with scrollbars
    local function setup_resize(dir, sz, rp)
        local h = dOS.create_gui_element(dOS, "TextButton", {
            Parent = win_frame,
            Name = "Resize_" .. dir,
            Text = "",
            BackgroundTransparency = 1,
            Size = sz,
            Position = rp,
            ZIndex = dOS.Z_INDEX.WINDOW_ACTIVE + 2,
            Active = true,
        })

        h.MouseButton1Down:Connect(function(x, y)
            if dOS.window_metadata[win_frame].is_maximized then
                return
            end

            dOS.DragManager.stop_drag(dOS)
            M.set_active_window(dOS, win_frame)

            local cursor_object = _find_cursor(dOS, x, y, win_frame)
            if cursor_object then
                dOS.DragManager.start_resize(dOS, win_frame, dir, cursor_object)
            end
        end)

        h.MouseButton1Up:Connect(function()
            dOS.DragManager.stop_drag(dOS)
        end)
    end

    if (min_width or 150) > 0 and (min_height or 100) > 0 then
        setup_resize(
            "X",
            UDim2.new(0, RESIZE_THICK, 1, -RESIZE_THICK),
            UDim2.new(1, -RESIZE_THICK, 0, 0)
        )
        setup_resize(
            "Y",
            UDim2.new(1, -RESIZE_THICK, 0, RESIZE_THICK),
            UDim2.new(0, 0, 1, -RESIZE_THICK)
        )
        setup_resize(
            "XY",
            UDim2.fromOffset(RESIZE_THICK * 2, RESIZE_THICK * 2),
            UDim2.new(1, -RESIZE_THICK * 2, 1, -RESIZE_THICK * 2)
        )

        local rv = dOS.create_gui_element(dOS, "Frame", {
            Parent = win_frame,
            Size = UDim2.fromOffset(10, 10),
            Position = UDim2.new(1, -10, 1, -10),
            BackgroundColor3 = dOS.THEME.BORDER_HIGHLIGHT,
            BackgroundTransparency = 0.5,
            ZIndex = dOS.Z_INDEX.WINDOW_ACTIVE + 1,
        })

        dOS.create_gui_element(
            dOS,
            "UICorner",
            { Parent = rv, CornerRadius = UDim.new(0, 2) }
        )
    end

    -- title bar buttons
    local button_offset = 4
    local button_size = title_bar_height - 8

    if is_closable then
        local close_btn = dOS.create_gui_element(dOS, "ImageButton", {
            Parent = title_bar,
            Image = 136968209449975,
            Size = UDim2.fromOffset(button_size, button_size),
            Position = UDim2.new(1, -button_offset - button_size, 0, 4 * 6),
            BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
            OnClick = function()
                M.close_window(dOS, win_frame)
            end,
        })

        local old_off = button_offset
        button_offset += button_size + 4

        task.spawn(function()
            task.wait()
            dOS.Tween
                .new(
                    close_btn,
                    {
                        Position = UDim2.new(1, -old_off - button_size, 0, 4),
                        BackgroundTransparency = 0,
                    },
                    dOS.TweenInfo.new(
                        0.8,
                        Enum.EasingStyle.Bounce,
                        Enum.EasingDirection.Out
                    )
                )
                :Play()
        end)
    end

    task.wait()

    if is_maximizable then
        local max_btn = dOS.create_gui_element(dOS, "TextButton", {
            Parent = title_bar,
            Text = "☐",
            Size = UDim2.fromOffset(button_size, button_size),
            Position = UDim2.new(1, -button_offset - button_size, 0, 4 * 6),
            BackgroundTransparency = 1,
            OnClick = function()
                M.handle_maximize_window(dOS, win_frame)
            end,
            Active = true,
        })

        dOS.window_metadata[win_frame].maximize_button = max_btn
        local old_off = button_offset
        button_offset += button_size + 4

        task.spawn(function()
            task.wait(0.3)
            dOS.Tween
                .new(
                    max_btn,
                    {
                        Position = UDim2.new(1, -old_off - button_size, 0, 4),
                        BackgroundTransparency = 0,
                    },
                    dOS.TweenInfo.new(
                        0.8,
                        Enum.EasingStyle.Bounce,
                        Enum.EasingDirection.Out
                    )
                )
                :Play()
        end)
    end

    task.wait()

    if is_minimizable then
        local min_btn = dOS.create_gui_element(dOS, "TextButton", {
            Parent = title_bar,
            Text = "—",
            Size = UDim2.fromOffset(button_size, button_size),
            Position = UDim2.new(1, -button_offset - button_size, 0, 4 * 6),
            BackgroundTransparency = 1,
            OnClick = function()
                M.handle_minimize_window(dOS, win_frame)
            end,
            Active = true,
        })

        local old_off = button_offset
        button_offset += button_size + 4

        task.spawn(function()
            task.wait(0.6)
            dOS.Tween
                .new(
                    min_btn,
                    {
                        Position = UDim2.new(1, -old_off - button_size, 0, 4),
                        BackgroundTransparency = 0,
                    },
                    dOS.TweenInfo.new(
                        0.8,
                        Enum.EasingStyle.Bounce,
                        Enum.EasingDirection.Out
                    )
                )
                :Play()
        end)
    end

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = title_bar,
        Name = "TitleLabel",
        Text = title_text,
        ZIndex = 1,
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        Font = dOS.FONT_BOLD,
        TextSize = dOS.os_settings.global_font_size + 2,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -button_offset - 10, 1, 0),
        Position = UDim2.fromOffset(8, 0),
    })

    -- title bar drag
    if is_draggable then
        title_bar.MouseButton1Down:Connect(function(x, y)
            M.set_active_window(dOS, win_frame)
            if dOS.window_metadata[win_frame].is_maximized then
                return
            end

            local cursor_object = _find_cursor(dOS, x, y, win_frame)
            if cursor_object then
                dOS.DragManager.start_drag(dOS, win_frame, cursor_object)
            end
        end)

        title_bar.MouseButton1Up:Connect(function()
            dOS.DragManager.stop_drag(dOS)
        end)
    end

    -- cleanup
    task.wait()

    win_frame.Destroying:Connect(function()
        if dOS.TaskbarManager then
            dOS.TaskbarManager.on_window_closed(dOS, win_frame)
        end

        for i, w in ipairs(dOS.all_windows) do
            if w == win_frame then
                table.remove(dOS.all_windows, i)
                break
            end
        end

        if dOS.active_window_frame == win_frame then
            dOS.active_window_frame = nil
        end

        if dOS.drag_manager.window == win_frame then
            dOS.DragManager.stop_drag(dOS)
        end

        if dOS.DWM then
            dOS.DWM.unregister_window(dOS, win_frame)
        end

        dOS.window_metadata[win_frame] = nil
    end)

    M.set_active_window(dOS, win_frame)

    task.spawn(function()
        task.wait(0.55)
        if win_frame and win_frame.Parent and dOS.TaskbarManager then
            dOS.TaskbarManager.on_window_opened(dOS, win_frame)
        end
    end)

    return win_frame, content_area
end

--- CLOSE

function M.close_window(dOS, win_frame)
    if not win_frame or not win_frame.Parent then
        return
    end

    local size = win_frame.AbsoluteSize
    local pos = win_frame.Position

    win_frame.Position = UDim2.new(
        0,
        pos.X.Offset
            + pos.X.Scale * win_frame.Parent.AbsoluteSize.X
            + size.X * (win_frame.AnchorPoint.X + 0.5),
        0,
        pos.Y.Offset
            + pos.Y.Scale * win_frame.Parent.AbsoluteSize.Y
            + size.Y * (win_frame.AnchorPoint.Y + 0.5)
    )
    win_frame.AnchorPoint = Vector2.new(0.5, 0.5)

    local info =
        dOS.TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

    dOS.Tween
        .new(
            win_frame,
            { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 },
            info
        )
        :Play()

    task.wait(0.5)

    local meta = dOS.window_metadata and dOS.window_metadata[win_frame]
    local hook = meta and meta.pre_close_hook

    if hook then
        hook(function()
            if win_frame and win_frame.Parent then
                win_frame:Destroy()
            end
        end)
    else
        if win_frame and win_frame.Parent then
            win_frame:Destroy()
        end
    end
end

--- MINIMIZE

function M.handle_minimize_window(dOS, win_frame)
    local meta = dOS.window_metadata[win_frame]
    if not meta or meta.is_minimized then
        return
    end

    win_frame.ClipsDescendants = true
    meta.restore_position = win_frame.Position
    meta.restore_size = win_frame.Size

    local target_pos
    local tab_center = dOS.TaskbarManager
        and dOS.TaskbarManager.get_tab_screen_position(dOS, win_frame)

    if tab_center then
        target_pos = UDim2.fromOffset(tab_center.X, tab_center.Y)
    else
        local dims = _dims_for_window(dOS, win_frame)
        local pos_name = dOS.os_settings.taskbar_position or "Bottom"
        local win_x = win_frame.Position.X.Offset + win_frame.AbsoluteSize.X / 2
        local win_y = win_frame.Position.Y.Offset + win_frame.AbsoluteSize.Y / 2

        if pos_name == "Bottom" then
            target_pos = UDim2.fromOffset(win_x, dims.Y + 10)
        elseif pos_name == "Top" then
            target_pos = UDim2.fromOffset(win_x, -60)
        elseif pos_name == "Left" then
            target_pos = UDim2.fromOffset(-60, win_y)
        else
            target_pos = UDim2.fromOffset(dims.X + 10, win_y)
        end
    end

    local cx = win_frame.Position.X.Offset + win_frame.AbsoluteSize.X / 2
    local cy = win_frame.Position.Y.Offset + win_frame.AbsoluteSize.Y / 2

    win_frame.AnchorPoint = Vector2.new(0.5, 0.5)
    win_frame.Position = UDim2.fromOffset(cx, cy)

    local info =
        dOS.TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

    dOS.Tween
        .new(
            win_frame,
            {
                Position = target_pos,
                Size = UDim2.fromOffset(40, 20),
                BackgroundTransparency = 1,
            },
            info
        )
        :Play()

    task.spawn(function()
        task.wait(0.3)
        if not win_frame or not win_frame.Parent then
            return
        end

        meta.is_minimized = true
        win_frame.Visible = false
        win_frame.AnchorPoint = Vector2.new(0, 0)
        win_frame.Position = meta.restore_position
        win_frame.Size = meta.restore_size
        win_frame.BackgroundTransparency = 0

        if dOS.TaskbarManager then
            dOS.TaskbarManager.on_window_minimized(dOS, win_frame)
        end
    end)
end

function M.handle_unminimize_window(dOS, win_frame)
    local meta = dOS.window_metadata[win_frame]
    if not meta or not meta.is_minimized then
        return
    end

    meta.is_minimized = false
    win_frame.Visible = true

    local dims = _dims_for_window(dOS, win_frame)
    local pos_name = dOS.os_settings.taskbar_position or "Bottom"
    local start_pos

    if pos_name == "Bottom" then
        start_pos =
            UDim2.fromOffset(meta.restore_position.X.Offset, dims.Y - 50)
    elseif pos_name == "Top" then
        start_pos = UDim2.fromOffset(meta.restore_position.X.Offset, 50)
    elseif pos_name == "Left" then
        start_pos = UDim2.fromOffset(50, meta.restore_position.Y.Offset)
    else
        start_pos =
            UDim2.fromOffset(dims.X - 50, meta.restore_position.Y.Offset)
    end

    win_frame.Position = start_pos
    win_frame.Size = UDim2.fromOffset(80, 40)
    win_frame.BackgroundTransparency = 1

    local info = dOS.TweenInfo.new(
        0.32,
        Enum.EasingStyle.Quint,
        Enum.EasingDirection.Out
    )

    dOS.Tween
        .new(
            win_frame,
            {
                Position = meta.restore_position,
                Size = meta.restore_size,
                BackgroundTransparency = 0,
            },
            info
        )
        :Play()

    M.set_active_window(dOS, win_frame)

    if dOS.TaskbarManager then
        dOS.TaskbarManager.on_window_unminimized(dOS, win_frame)
    end
end

--- MAXIMIZE

function M.handle_maximize_window(dOS, win_frame)
    local meta = dOS.window_metadata[win_frame]
    if not meta then
        return
    end

    local info = dOS.TweenInfo.new(
        0.25,
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.InOut
    )
    local goal = {}

    if meta.is_maximized then
        goal.Position = meta.restore_position
        goal.Size = meta.restore_size
        meta.is_maximized = false

        if meta.maximize_button then
            meta.maximize_button.Text = "☐"
        end

        if dOS.TaskbarManager then
            dOS.TaskbarManager.on_window_unmaximized(dOS, win_frame)
        end
    else
        meta.restore_position = win_frame.Position
        meta.restore_size = win_frame.Size
        goal.Position = UDim2.fromOffset(0, 0)
        goal.Size = UDim2.fromScale(1, 1)
        meta.is_maximized = true

        if meta.maximize_button then
            meta.maximize_button.Text = "⿻"
        end

        if dOS.TaskbarManager then
            dOS.TaskbarManager.on_window_maximized(dOS, win_frame)
        end
    end

    dOS.Tween.new(win_frame, goal, info):Play()
end

return M

-- EOF