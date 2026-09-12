--[[
    "Cursor Manager application for dOS"
    
    @module cursor_mgr
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
        "Cursor Manager",
        400,
        500,
        true,
        true,
        true,
        true
    )
    if not win_frame then
        return
    end

    --- CONFIG

    local config_frame = dOS.create_gui_element(dOS, "Frame", {
        Parent = content_area,
        Size = UDim2.new(1, 0, 0, 115),
        BackgroundColor3 = dOS.THEME.TASKBAR_BG,
        BorderSizePixel = 0,
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = config_frame,
        Text = "Owner Configuration",
        Size = UDim2.new(1, -10, 0, 25),
        Position = UDim2.fromOffset(5, 5),
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = dOS.FONT_BOLD,
    })

    local owner_input = dOS.create_gui_element(dOS, "TextButton", {
        Parent = config_frame,
        Text = dOS.os_settings.owner_username or "Click to set Owner",
        Size = UDim2.new(1, -20, 0, 30),
        Position = UDim2.fromOffset(10, 35),
        BackgroundColor3 = dOS.THEME.TEXT_BOX_DARK,
        TextColor3 = dOS.THEME.TEXT_LIGHT,
    })

    owner_input.MouseButton1Click:Connect(function()
        dOS.RequestStringAsync(
            dOS,
            "Enter Owner Username:",
            dOS.os_settings.owner_username or "",
            function(name)
                if name ~= "" then
                    dOS.os_settings.owner_username = name
                    owner_input.Text = name
                    -- HACK
                    -- FIXME
                    require("./settings.lua").save_settings(dOS, dOS.os_settings)
                end
            end
        )
    end)

    --- HEADER

    local list_header = dOS.create_gui_element(dOS, "Frame", {
        Parent = content_area,
        Size = UDim2.new(1, 0, 0, 30),
        Position = UDim2.fromOffset(0, 115),
        BackgroundColor3 = dOS.THEME.TITLE_BAR_BG,
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = list_header,
        Text = "Active Cursors",
        Size = UDim2.fromScale(1, 1),
        Font = dOS.FONT_BOLD,
    })

    --- LIST

    local scroll_frame = dOS.create_gui_element(dOS, "ScrollingFrame", {
        Parent = content_area,
        Size = UDim2.new(1, 0, 1, -145),
        Position = UDim2.fromOffset(0, 145),
        BackgroundTransparency = 1,
    })

    dOS.create_gui_element(dOS, "UIListLayout", {
        Parent = scroll_frame,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
    })

    dOS.create_gui_element(
        dOS,
        "UIPadding",
        { Parent = scroll_frame, PaddingTop = UDim.new(0, 5) }
    )

    --- HELPERS

    local function is_cursor_owner(x, y)
        for _, cursor in pairs(dOS.screen:GetCursors()) do
            local distance = (Vector2.new(x, y) - Vector2.new(
                cursor.X,
                cursor.Y
            )).Magnitude

            if distance < 10 then
                return cursor.Player == dOS.os_settings.owner_username
            end
        end

        return nil
    end

    --- REFRESH

    local cursor_rows = {}

    local function refresh_list()
        if not win_frame.Parent then
            return
        end

        local cursors = dOS.screen:GetCursors()
        local hidden = dOS.CursorManager.cursor_manager.hidden_users
        local active_uids = {}

        -- create or update rows
        for _, cursor_data in pairs(cursors) do
            local user_id = cursor_data.UserId
            local username = cursor_data.Player
            active_uids[user_id] = true
            local is_hidden = hidden[user_id]

            if not cursor_rows[user_id] then
                -- create new row
                local row_frame = dOS.create_gui_element(dOS, "Frame", {
                    Parent = scroll_frame,
                    Size = UDim2.new(1, -10, 0, 40),
                    BackgroundColor3 = dOS.THEME.CALC_DISPLAY_BG,
                })

                local name_label = dOS.create_gui_element(dOS, "TextLabel", {
                    Parent = row_frame,
                    Text = username .. (is_hidden and " (Hidden)" or ""),
                    Size = UDim2.fromScale(0.6, 1),
                    Position = UDim2.fromOffset(10, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextColor3 = is_hidden and dOS.THEME.TEXT_DIM
                        or dOS.THEME.TEXT_LIGHT,
                })

                local toggle_btn = dOS.create_gui_element(dOS, "TextButton", {
                    Parent = row_frame,
                    Text = is_hidden and "Show" or "Hide",
                    Size = UDim2.new(0.3, 0, 0, 30),
                    Position = UDim2.new(0.65, 0, 0, 5),
                    BackgroundColor3 = is_hidden and dOS.THEME.ACCENT_BUTTON_BG
                        or Color3.fromRGB(255, 80, 80),
                })

                toggle_btn.MouseButton1Down:Connect(function(click_x, click_y)
                    if not is_cursor_owner(click_x, click_y) then
                        return
                    end

                    hidden[user_id] = not hidden[user_id]
                    refresh_list()
                end)

                cursor_rows[user_id] = {
                    frame = row_frame,
                    name_label = name_label,
                    action_btn = toggle_btn,
                    last_hidden_state = is_hidden,
                }
            else
                -- update existing row if state changed
                local row_data = cursor_rows[user_id]

                if row_data.last_hidden_state ~= is_hidden then
                    row_data.name_label.Text = username
                        .. (is_hidden and " (Hidden)" or "")
                    row_data.name_label.TextColor3 = is_hidden
                            and dOS.THEME.TEXT_DIM
                        or dOS.THEME.TEXT_LIGHT

                    row_data.action_btn.Text = is_hidden and "Show" or "Hide"
                    row_data.action_btn.BackgroundColor3 = is_hidden
                            and dOS.THEME.ACCENT_BUTTON_BG
                        or Color3.fromRGB(255, 80, 80)

                    row_data.last_hidden_state = is_hidden
                end
            end
        end

        -- cleanup
        for user_id, row_data in pairs(cursor_rows) do
            if not active_uids[user_id] then
                row_data.frame:Destroy()
                cursor_rows[user_id] = nil
            end
        end

        -- update canvas size
        local row_count = 0
        for _ in pairs(cursor_rows) do
            row_count += 1
        end
        scroll_frame.CanvasSize = UDim2.fromOffset(0, row_count * 45)
    end

    --- MAINLOOP

    refresh_list()
    task.spawn(function()
        while win_frame.Parent do
            task.wait(1)
            refresh_list()
        end
    end)
end

return M

-- EOF