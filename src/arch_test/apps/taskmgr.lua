--[[
    "Task Manager application for dOS"
    
    @module taskmgr
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

--- API

function M.create(dOS)
    local win_frame, content_area = dOS.create_basic_window(
        dOS,
        "Task Manager",
        250,
        400,
        true,
        true,
        true,
        true,
        250,
        200
    )
    if not win_frame then
        return
    end

    --- UI

    -- top info bar
    local info_bar = dOS.create_gui_element(dOS, "Frame", {
        Parent = content_area,
        Size = UDim2.new(1, 0, 0, 60),
        BackgroundColor3 = dOS.THEME.TASKBAR_BG,
        BorderSizePixel = 0,
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = info_bar,
        Text = "Processes:",
        Size = UDim2.new(0.5, 0, 0, 30),
        Position = UDim2.fromOffset(10, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = dOS.os_settings.global_font_size,
        TextColor3 = dOS.THEME.TEXT_DIM,
    })

    local stats_label_proc = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = info_bar,
        Text = "...",
        Size = UDim2.new(0.5, 0, 0, 30),
        Position = UDim2.new(1, -10, 0, 0),
        AnchorPoint = Vector2.new(1, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextSize = dOS.os_settings.global_font_size,
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        BackgroundTransparency = 1,
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = info_bar,
        Text = "Memory Usage (KB):",
        Size = UDim2.new(0.5, 0, 0, 30),
        Position = UDim2.fromOffset(10, 30),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = dOS.os_settings.global_font_size,
        TextColor3 = dOS.THEME.TEXT_DIM,
    })

    local stats_label_mem = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = info_bar,
        Text = "...",
        Size = UDim2.new(0.5, 0, 0, 30),
        Position = UDim2.new(1, -10, 0, 30),
        AnchorPoint = Vector2.new(1, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextSize = dOS.os_settings.global_font_size,
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        BackgroundTransparency = 1,
    })

    -- list header
    local list_header = dOS.create_gui_element(dOS, "Frame", {
        Parent = content_area,
        Size = UDim2.new(1, 0, 0, 30),
        Position = UDim2.fromOffset(0, 60),
        BackgroundColor3 = dOS.THEME.TITLE_BAR_BG,
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = list_header,
        Text = "Application",
        Size = UDim2.fromScale(0.5, 1),
        Position = UDim2.fromOffset(10, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = dOS.FONT_BOLD,
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = list_header,
        Text = "Actions",
        Size = UDim2.new(0.5, -20, 1, 0),
        Position = UDim2.fromScale(0.5, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
        Font = dOS.FONT_BOLD,
    })

    -- scrollable process list
    local list_scroll = dOS.create_gui_element(dOS, "ScrollingFrame", {
        Parent = content_area,
        Size = UDim2.new(1, 0, 1, -90),
        Position = UDim2.fromOffset(0, 90),
        BackgroundTransparency = 1,
        ScrollBarThickness = 6,
    })

    --- TASKS

    local function refresh_task_list()
        if not list_scroll or not list_scroll.Parent then
            return
        end

        -- clear existing entries
        for _, child in pairs(list_scroll:GetChildren()) do
            child:Destroy()
        end

        local rowYOffset = 5
        local windowCount = 0

        for _, win_ref in ipairs(dOS.all_windows) do
            if not win_ref or not win_ref.Parent then
                continue
            end
            windowCount += 1

            local metadata = dOS.window_metadata[win_ref]
            local title = metadata and metadata.title or win_ref.Name

            local row = dOS.create_gui_element(dOS, "Frame", {
                Parent = list_scroll,
                Size = UDim2.new(1, -10, 0, 40),
                Position = UDim2.fromOffset(5, rowYOffset),
                BackgroundColor3 = dOS.THEME.CALC_DISPLAY_BG,
                BorderColor3 = dOS.THEME.BORDER_HIGHLIGHT,
            })

            dOS.create_gui_element(dOS, "UICorner", {
                Parent = row,
                CornerRadius = UDim.new(0, 6),
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = row,
                Text = title,
                Size = UDim2.new(0.5, -10, 1, 0),
                Position = UDim2.fromOffset(10, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })

            -- kill button
            dOS.create_gui_element(dOS, "TextButton", {
                Parent = row,
                Text = "Kill",
                TextColor3 = Color3.fromRGB(255, 100, 100),
                Size = UDim2.fromOffset(50, 30),
                Position = UDim2.new(1, -60, 0, 5),
                OnClick = function()
                    if win_ref and win_ref.Parent then
                        win_ref:Destroy()
                        refresh_task_list()
                    end
                end,
            })

            -- end task button
            dOS.create_gui_element(dOS, "TextButton", {
                Parent = row,
                Text = "End Task",
                Size = UDim2.fromOffset(80, 30),
                Position = UDim2.new(1, -150, 0, 5),
                OnClick = function()
                    dOS.Window.close_window(dOS, win_ref)
                    task.wait(0.35)
                    refresh_task_list()
                end,
            })

            rowYOffset += 45
        end

        list_scroll.CanvasSize = UDim2.fromOffset(0, rowYOffset)

        -- HACK
        -- WARNING: simulated usage
        -- TODO: remove
        -- memory usage estimation
        -- base OS: ~600KB, per window: ~50KB
        local estimated_mem = 600 + (windowCount * 50)

        stats_label_proc.Text = windowCount
        stats_label_mem.Text = estimated_mem
    end

    refresh_task_list()

    -- auto-refresh loop
    -- TODO: migrate to efficient either:
    -- * Connect() based or like cursor manager
    task.spawn(function()
        while win_frame and win_frame.Parent do
            refresh_task_list()
            task.wait(2)
        end
    end)
end

return M

-- EOF