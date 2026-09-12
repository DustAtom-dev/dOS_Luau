--[[
    "In-Game chatting application for dOS"
    
    @module chat
    @version 1.4
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

--- HELPERS

local function derive_channel_key(dOS, password)
    return dOS.SHA256.hash(password or "")
end

local function ensure_channel_key(dOS, channel_data)
    if not channel_data.password_hash then
        channel_data.password_hash = derive_channel_key(dOS, "")
    end
end

--- SAVING

local function save_chat_data(dOS)
    if not dOS.disk then return end
    dOS._G_CHAT_DATA.connections = {}

    local persistent = { channels = {} }

    for channel_id, channel_data in pairs(dOS._G_CHAT_DATA.channels) do
        ensure_channel_key(dOS, channel_data)
        local key = channel_data.password_hash

        local ok_json, json_msg = pcall(JSONEncode, channel_data.messages or {})
        if not ok_json then
            warn("[dOS Connect] Save: JSONEncode failed for " .. channel_id)
            continue
        end

        local encrypted =
            dOS.CHACHA.CHACHA_256(dOS.CHACHA.encrypt, key, json_msg)
        if not encrypted then
            warn("[dOS Connect] Save: Encrypt failed for " .. channel_id)
            continue
        end

        persistent.channels[channel_id] = {
            name = channel_data.name,
            password_hash = key,
            messages = encrypted,
        }
    end

    local ok_outer, json_str = pcall(JSONEncode, persistent)
    if not ok_outer or not json_str then
        warn("[dOS Connect] Save: Outer JSONEncode failed.")
        return
    end

    local ok_write, write_err =
        pcall(dOS.disk.Write, dOS.disk, dOS.CHAT_DISK_FILE, json_str)
    if not ok_write then
        warn("[dOS Connect] Save: Disk write error: " .. tostring(write_err))
    end
end

function M.load_chat_data(dOS)
    if not dOS.disk then return end

    local ok_read, raw = pcall(dOS.disk.Read, dOS.disk, dOS.CHAT_DISK_FILE)
    if not ok_read or not raw then
        warn("[dOS Connect] Load: Disk read failed.")
        return
    end

    local ok_outer, persistent = pcall(JSONDecode, raw)
    if not ok_outer or type(persistent) ~= "table" then
        warn("[dOS Connect] Load: Outer JSONDecode failed (old format?).")
        return
    end

    if type(persistent.channels) == "table" then
        for channel_id, channel_data in pairs(persistent.channels) do
            local key = channel_data.password_hash
                or derive_channel_key(dOS, "")
            local messages = {}

            if channel_data.messages and channel_data.messages ~= "" then
                local decrypted = dOS.CHACHA.CHACHA_256(
                    dOS.CHACHA.decrypt,
                    key,
                    channel_data.messages
                )
                if decrypted then
                    local ok_msg, decoded = pcall(JSONDecode, decrypted)
                    if ok_msg and type(decoded) == "table" then
                        messages = decoded
                    else
                        warn(
                            "[dOS Connect] Load: Message decode failed for "
                                .. channel_id
                        )
                    end
                else
                    warn(
                        "[dOS Connect] Load: Decrypt failed for "
                            .. channel_id
                            .. " (wrong password hash?)"
                    )
                end
            end

            dOS._G_CHAT_DATA.channels[channel_id] = {
                name = channel_data.name,
                password_hash = key,
                messages = messages,
            }
        end
    end
end

--- API

function M.create(dOS)
    if not dOS.modem then
        dOS.MessageBox.error(
            dOS,
            "Modem Not Found",
            "dOS Connect requires a Modem component and restart."
        )
        return
    end

    for _, channel_data in pairs(dOS._G_CHAT_DATA.channels) do
        ensure_channel_key(dOS, channel_data)
    end

    local win_frame, content_area = dOS.create_basic_window(
        dOS,
        "dOS Connect",
        820,
        580,
        true,
        true,
        true,
        true,
        300,
        200
    )
    if not win_frame then return end

    -- layout
    local MAX_MSG_LEN = 300
    local SIDEBAR_W = 220
    local HEADER_H = 46 -- channel header bar height
    local LOAD_BAR_H = 3 -- loading progress bar height
    local INPUT_H = 58 -- input area height
    local ITEM_H = 40 -- channel list item stride (button + gap)
    local ITEM_BTN_H = 34 -- channel list button height
    local MSG_GAP = 8 -- vertical gap between message frames
    local CONTENT_Y = 24 -- y-offset inside a message frame for the body
    local IMAGE_H = 150 -- height of an image message preview

    -- tweens
    local function ti_fast()
        return dOS.TweenInfo.new(
            0.14,
            Enum.EasingStyle.Quart,
            Enum.EasingDirection.Out
        )
    end

    -- overshoot bounce for the indicator
    local function ti_bounce()
        return dOS.TweenInfo.new(
            0.48,
            Enum.EasingStyle.Back,
            Enum.EasingDirection.Out
        )
    end

    local function ti_fade()
        return dOS.TweenInfo.new(
            0.22,
            Enum.EasingStyle.Sine,
            Enum.EasingDirection.Out
        )
    end

    -- state
    local ui = {}
    local state = {
        is_active = true,
        current_channel_id = "dOS-General",
        context_menu = nil,
        channel_y_map = {}, -- channel_id -> Y in the scroll list
        render_token = 0, -- incremented every draw_message_area call
        channel_click_lock = false, -- debounce for channel switching
        input_lock = false, -- debounce for message input
    }

    -- fwd decls
    local draw_channel_list, draw_message_area

    -- left pane

    local left_pane = dOS.create_gui_element(dOS, "Frame", {
        Parent = content_area,
        Size = UDim2.new(0, SIDEBAR_W, 1, 0),
        BackgroundColor3 = dOS.THEME.START_MENU_CONTENT_BG,
        ClipsDescendants = true,
    })

    -- sidebar header
    local sidebar_header = dOS.create_gui_element(dOS, "Frame", {
        Parent = left_pane,
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = dOS.THEME.TASKBAR_BG,
    })

    dOS.create_gui_element(dOS, "UIStroke", {
        Parent = sidebar_header,
        Color = Color3.fromRGB(55, 55, 68),
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = sidebar_header,
        Text = "Channels",
        Size = UDim2.new(1, -72, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = dOS.FONT_BOLD,
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        TextSize = 13,
        BackgroundTransparency = 1,
    })

    -- add channel button
    local plus_channel_btn = dOS.create_gui_element(dOS, "TextButton", {
        Parent = sidebar_header,
        Text = "+",
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.new(1, -58, 0.5, -13),
        BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_HOVER,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = dOS.FONT_BOLD,
        TextSize = 17,
    })

    dOS.create_gui_element(
        dOS,
        "UICorner",
        { Parent = plus_channel_btn, CornerRadius = UDim.new(0, 6) }
    )

    -- remove channel button
    local minus_channel_btn = dOS.create_gui_element(dOS, "TextButton", {
        Parent = sidebar_header,
        Text = "-",
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.new(1, -28, 0.5, -13),
        BackgroundColor3 = Color3.fromRGB(175, 55, 55),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = dOS.FONT_BOLD,
        TextSize = 17,
    })

    dOS.create_gui_element(
        dOS,
        "UICorner",
        { Parent = minus_channel_btn, CornerRadius = UDim.new(0, 6) }
    )

    -- channel list
    ui.channel_list = dOS.create_gui_element(dOS, "ScrollingFrame", {
        Parent = left_pane,
        Size = UDim2.new(1, 0, 1, -48 - 48),
        Position = UDim2.fromOffset(0, 48),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = dOS.THEME.ACCENT_BUTTON_HOVER,
        ClipsDescendants = true,
    })

    -- left-edge indicator
    ui.active_indicator = dOS.create_gui_element(dOS, "Frame", {
        Parent = ui.channel_list,
        Size = UDim2.fromOffset(3, ITEM_BTN_H),
        Position = UDim2.fromOffset(0, 8),
        BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_HOVER,
        ZIndex = 6,
        BorderSizePixel = 0,
    })

    dOS.create_gui_element(
        dOS,
        "UICorner",
        { Parent = ui.active_indicator, CornerRadius = UDim.new(0, 3) }
    )

    -- anonymous toggle
    local user_panel = dOS.create_gui_element(dOS, "TextButton", {
        Parent = left_pane,
        Text = "",
        Size = UDim2.new(1, 0, 0, 48),
        Position = UDim2.new(0, 0, 1, -48),
        BackgroundColor3 = dOS.THEME.TASKBAR_BG,
    })

    dOS.create_gui_element(dOS, "UIStroke", {
        Parent = user_panel,
        Color = Color3.fromRGB(55, 55, 68),
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })

    local anon_icon = dOS.create_gui_element(dOS, "Frame", {
        Parent = user_panel,
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(0, 10, 0.5, -14),
        BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_HOVER,
    })

    dOS.create_gui_element(
        dOS,
        "UICorner",
        { Parent = anon_icon, CornerRadius = UDim.new(1, 0) }
    )

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = anon_icon,
        Text = "?",
        Size = UDim2.fromScale(1, 1),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = dOS.FONT_BOLD,
        TextSize = 14,
        BackgroundTransparency = 1,
    })

    local username_label = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = user_panel,
        Text = dOS._G_CHAT_DATA.anonymous_username and "Anonymous: ON"
            or "Anonymous: OFF",
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.fromOffset(46, 0),
        BackgroundTransparency = 1,
        TextColor3 = dOS.THEME.TEXT_DIM,
        TextSize = 11,
    })

    -- right pane

    local right_pane = dOS.create_gui_element(dOS, "Frame", {
        Parent = content_area,
        Size = UDim2.new(1, -SIDEBAR_W, 1, 0),
        Position = UDim2.fromOffset(SIDEBAR_W, 0),
        BackgroundColor3 = dOS.THEME.DESKTOP_BG,
    })

    -- channel header
    local channel_header = dOS.create_gui_element(dOS, "Frame", {
        Parent = right_pane,
        Size = UDim2.new(1, 0, 0, HEADER_H),
        BackgroundColor3 = dOS.THEME.TASKBAR_BG,
    })

    dOS.create_gui_element(dOS, "UIStroke", {
        Parent = channel_header,
        Color = Color3.fromRGB(55, 55, 68),
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })

    -- encryption icon
    dOS.create_gui_element(dOS, "ImageLabel", {
        Parent = channel_header,
        Image = 70907649101353,
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.fromOffset(12, 15),
        BackgroundTransparency = 1,
    })

    ui.channel_name_label = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = channel_header,
        Text = "#  "
            .. (
                (dOS._G_CHAT_DATA.channels[state.current_channel_id] or {}).name
                or state.current_channel_id
            ),
        Size = UDim2.new(1, -120, 1, 0),
        Position = UDim2.fromOffset(36, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = dOS.FONT_BOLD,
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        TextSize = 14,
        BackgroundTransparency = 1,
    })

    -- loading bar stays visible while scrolling
    local load_bar_wrap = dOS.create_gui_element(dOS, "Frame", {
        Parent = right_pane,
        Size = UDim2.new(1, 0, 0, LOAD_BAR_H),
        Position = UDim2.fromOffset(0, HEADER_H),
        BackgroundColor3 = Color3.fromRGB(38, 38, 52),
        BackgroundTransparency = 1,
        ZIndex = 40,
        ClipsDescendants = true,
    })

    local load_bar_fill = dOS.create_gui_element(dOS, "Frame", {
        Parent = load_bar_wrap,
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_HOVER,
        BackgroundTransparency = 0,
        ZIndex = 41,
    })

    dOS.create_gui_element(dOS, "UIGradient", {
        Parent = load_bar_fill,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.5, dOS.THEME.ACCENT_BUTTON_HOVER),
            ColorSequenceKeypoint.new(1, dOS.THEME.ACCENT_BUTTON_HOVER),
        }),
        Rotation = 0,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.4, 0),
            NumberSequenceKeypoint.new(1, 0.3),
        }),
    })

    ui.message_area = dOS.create_gui_element(dOS, "ScrollingFrame", {
        Parent = right_pane,
        Size = UDim2.new(1, 0, 1, -(HEADER_H + LOAD_BAR_H + INPUT_H)),
        Position = UDim2.fromOffset(0, HEADER_H + LOAD_BAR_H),
        BackgroundTransparency = 1,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = dOS.THEME.ACCENT_BUTTON_HOVER,
        ClipsDescendants = true,
    })

    local input_bar = dOS.create_gui_element(dOS, "Frame", {
        Parent = right_pane,
        Size = UDim2.new(1, -20, 0, 42),
        Position = UDim2.new(0, 10, 1, -(INPUT_H - 8)),
        BackgroundColor3 = dOS.THEME.START_MENU_CONTENT_BG,
    })

    dOS.create_gui_element(
        dOS,
        "UICorner",
        { Parent = input_bar, CornerRadius = UDim.new(0, 12) }
    )

    dOS.create_gui_element(dOS, "UIStroke", {
        Parent = input_bar,
        Color = Color3.fromRGB(65, 65, 85),
        Thickness = 1,
    })

    local input_button = dOS.create_gui_element(dOS, "TextButton", {
        Parent = input_bar,
        Text = "    Write a message...",
        TextColor3 = dOS.THEME.TEXT_DIM,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -92, 1, 0),
        BackgroundTransparency = 1,
        TextSize = 12,
    })

    local image_button = dOS.create_gui_element(dOS, "TextButton", {
        Parent = input_bar,
        Text = "IMG",
        Size = UDim2.fromOffset(78, 30),
        Position = UDim2.new(1, -84, 0.5, -15),
        BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_HOVER,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 11,
        Font = dOS.FONT_BOLD,
    })

    dOS.create_gui_element(
        dOS,
        "UICorner",
        { Parent = image_button, CornerRadius = UDim.new(0, 8) }
    )

    -- open animation
    do
        local op = content_area.Position
        content_area.Position =
            UDim2.new(op.X.Scale, op.X.Offset, op.Y.Scale, op.Y.Offset + 20)

        dOS.Tween
            .new(
                content_area,
                {
                    Position = UDim2.new(
                        op.X.Scale,
                        op.X.Offset,
                        op.Y.Scale,
                        op.Y.Offset
                    ),
                },
                dOS.TweenInfo.new(
                    0.38,
                    Enum.EasingStyle.Quart,
                    Enum.EasingDirection.Out
                )
            )
            :Play()
    end

    -- loading bar helpers

    local function begin_loading(total)
        load_bar_fill.Size = UDim2.fromScale(0, 1)
        load_bar_fill.BackgroundTransparency = 0
        load_bar_wrap.BackgroundTransparency = 0.45

        return function(loaded)
            if total > 0 then
                load_bar_fill.Size =
                    UDim2.fromScale(math.clamp(loaded / total, 0, 1), 1)
            end
        end
    end

    local function finish_loading(token)
        task.wait(0.04)
        if state.render_token ~= token then return end

        load_bar_fill.Size = UDim2.fromScale(1, 1)
        task.wait(0.08)

        dOS.Tween
            .new(load_bar_wrap, { BackgroundTransparency = 1 }, ti_fade())
            :Play()
        dOS.Tween
            .new(load_bar_fill, { BackgroundTransparency = 1 }, ti_fade())
            :Play()

        task.wait(0.24)
        -- reset for next render
        load_bar_fill.BackgroundTransparency = 0
        load_bar_fill.Size = UDim2.fromScale(0, 1)
    end

    -- core

    local function send_message(msg_table)
        if msg_table.content and #msg_table.content > MAX_MSG_LEN then
            dOS.MessageBox.error(
                dOS,
                "Message Error",
                "Message not sent: too long."
            )
            return
        end

        -- uid
        -- TODO: improve this 
        --        |
        --        |
        --        |
        --       \ /
        local unique_id = 0
        while unique_id == dOS._G_CHAT_DATA.last_received_id do
            unique_id = math.random() * 10 ^ 16
        end

        local sender
        if dOS._G_CHAT_DATA.anonymous_username then
            sender = "Anonymous"
        else
            local ok, result = pcall(
                function() return dOS.InputHandler.last_input_username end
            )
            sender = (ok and result) and result or "Unknown"
        end

        msg_table.UNIQUE_ID = unique_id
        msg_table.target_channel_id = state.current_channel_id
        msg_table.sender = sender
        msg_table.timestamp = os.time()

        local ok_json, json_msg = pcall(JSONEncode, msg_table)
        if not ok_json then
            warn("[dOS Connect] Send: JSONEncode failed.")
            return
        end

        local channel = dOS._G_CHAT_DATA.channels[state.current_channel_id]
        ensure_channel_key(dOS, channel)

        local encrypted = dOS.CHACHA.CHACHA_256(
            dOS.CHACHA.encrypt,
            channel.password_hash,
            json_msg
        )
        if not encrypted then
            dOS.MessageBox.error(
                dOS,
                "Encryption Error",
                "Could not encrypt message."
            )
            return
        end

        local ok_env, envelope = pcall(
            JSONEncode,
            { cid = state.current_channel_id, data = encrypted }
        )
        if not ok_env then
            warn("[dOS Connect] Send: Envelope encode failed.")
            return
        end

        dOS.modem:Configure({ NetworkID = "M1" })
        task.wait(0.1)

        pcall(dOS.modem.SendMessage, dOS.modem, envelope)
        print("[dOS Connect] Sent. cid=" .. state.current_channel_id)
    end

    local function calc_msg_slot(msg, area_w, font_size)
        if msg.type == "IMAGE_MESSAGE" then
            -- header + image + 12px padding
            local fh = CONTENT_Y + IMAGE_H + 12
            return fh, fh + MSG_GAP
        end

        local content = msg.content or ""
        local chars_per_ln =
            math.max(1, math.floor((area_w - 44) / (font_size * 0.6)))
        local single_lh = font_size + 2
        local lines = 0

        for line in content:gmatch("([^\n]*)") do
            lines += 1
            if #line > chars_per_ln then
                lines += math.floor(#line / chars_per_ln)
            end
        end

        local text_h = lines * 0.5 * single_lh + 10
        local fh = CONTENT_Y + text_h + 10

        return fh, fh + MSG_GAP
    end

    -- renderers

    draw_message_area = function()
        state.render_token += 1
        local my_token = state.render_token

        -- wipe old message frames
        for _, child in pairs(ui.message_area:GetChildren()) do
            if child:IsA("GuiObject") then child:Destroy() end
        end

        -- refresh channel header
        local ch = dOS._G_CHAT_DATA.channels[state.current_channel_id]
        if ui.channel_name_label then
            ui.channel_name_label.Text =
                `#  {(ch and (ch.name or state.current_channel_id) or state.current_channel_id)}`
        end

        local messages = ch and ch.messages or {}
        local msg_count = #messages

        local report_progress = begin_loading(msg_count)

        if msg_count == 0 then
            ui.message_area.CanvasSize = UDim2.fromOffset(0, 0)
            ui.message_area.CanvasPosition = Vector2.zero

            local t = my_token
            task.spawn(function() finish_loading(t) end)
            return
        end

        local area_w = ui.message_area.AbsoluteSize.X
        local font_size = dOS.os_settings.global_font_size

        -- pre-compute layout
        local frame_heights = {} -- [i] = frame height for messages[i]
        local y_positions = {} -- [i] = absolute Y in canvas
        local canvas_h = 10 -- top padding

        for i = 1, msg_count do
            local fh, slot = calc_msg_slot(messages[i], area_w, font_size)
            frame_heights[i] = fh
            y_positions[i] = canvas_h
            canvas_h += slot
        end

        canvas_h += 12 -- bottom padding

        -- for scroll to bottom to work
        ui.message_area.CanvasSize = UDim2.fromOffset(0, canvas_h)
        ui.message_area.CanvasPosition = Vector2.new(
            0,
            math.max(0, canvas_h - ui.message_area.AbsoluteSize.Y)
        )

        -- reverse render
        for rev = 0, msg_count - 1 do
            if state.render_token ~= my_token or not state.is_active then
                return
            end

            local i = msg_count - rev
            local msg = messages[i]
            local y = y_positions[i]
            local fh = frame_heights[i]

            -- message frame
            local msg_frame
            msg_frame = dOS.create_gui_element(dOS, "Frame", {
                Parent = ui.message_area,
                Size = UDim2.new(1, -20, 0, fh),
                Position = UDim2.fromOffset(10, y),
                BackgroundColor3 = dOS.THEME.START_MENU_CONTENT_BG,
                BackgroundTransparency = 0.62,
                AutoButtonColor = true,
            })

            dOS.create_gui_element(dOS, "UICorner", {
                Parent = msg_frame,
                CornerRadius = UDim.new(0, 9),
            })

            -- slide-in
            if rev == 0 then
                local op = msg_frame.Position
                msg_frame.Position = UDim2.new(
                    op.X.Scale,
                    op.X.Offset + 24,
                    op.Y.Scale,
                    op.Y.Offset
                )
                msg_frame.BackgroundTransparency = 1

                dOS.Tween
                    .new(
                        msg_frame,
                        {
                            Position = UDim2.new(
                                op.X.Scale,
                                op.X.Offset,
                                op.Y.Scale,
                                op.Y.Offset
                            ),
                            BackgroundTransparency = 0.62,
                        },
                        dOS.TweenInfo.new(
                            0.28,
                            Enum.EasingStyle.Quart,
                            Enum.EasingDirection.Out
                        )
                    )
                    :Play()
            end

            -- header row
            local header_row = dOS.create_gui_element(dOS, "Frame", {
                Parent = msg_frame,
                Size = UDim2.new(1, -10, 0, 16),
                Position = UDim2.fromOffset(10, 5),
                BackgroundTransparency = 1,
                ClipsDescendants = false,
            })

            dOS.create_gui_element(dOS, "UIListLayout", {
                Parent = header_row,
                FillDirection = Enum.FillDirection.Horizontal,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 0),
                VerticalAlignment = Enum.VerticalAlignment.Center,
            })

            local time_data = os.date("*t", msg.timestamp or 0)
            local seg_order = 0

            local function make_seg(text_val, bold)
                seg_order += 1
                local seg = dOS.create_gui_element(dOS, "TextLabel", {
                    Parent = header_row,
                    Text = text_val,
                    Font = bold and dOS.FONT_BOLD or dOS.FONT_REGULAR,
                    TextColor3 = bold and dOS.THEME.ACCENT_BUTTON_HOVER
                        or dOS.THEME.TEXT_DIM,
                    TextSize = font_size - 2,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Size = UDim2.fromScale(0, 1),
                    AutomaticSize = Enum.AutomaticSize.X,
                    BackgroundTransparency = 1,
                    LayoutOrder = seg_order,
                })
                return seg
            end

            -- build [ HH : MM ]
            make_seg("[", false)
            make_seg(time_data.hour, false)
            make_seg(":", false)
            make_seg(time_data.min, false)
            make_seg("] ", false)
            make_seg(msg.sender .. ":", true)

            -- action buttons
            local msg_action_btn
            do
                local ACTION_BTN_SIZE = 18
                local ACTION_BTN_GAP = 4
                local ACTION_BTN_Y = 5 -- v aligned with the header

                local function make_action_btn(image_id, slot, on_click)
                    local offset = (ACTION_BTN_SIZE + ACTION_BTN_GAP) * slot
                    local btn = dOS.create_gui_element(dOS, "ImageButton", {
                        Parent = msg_frame,
                        Image = image_id,
                        Size = UDim2.fromOffset(
                            ACTION_BTN_SIZE,
                            ACTION_BTN_SIZE
                        ),
                        Position = UDim2.new(1, -offset, 0, ACTION_BTN_Y),
                        BackgroundTransparency = 1,
                        ZIndex = 5,
                    })
                    btn.MouseButton1Click:Connect(on_click)
                    return btn
                end
                msg_action_btn = make_action_btn

                -- timestamp
                make_action_btn(4950659818, 1, function()
                    local _, pop = dOS.create_basic_window(
                        dOS,
                        "Timestamp",
                        200,
                        100,
                        true,
                        true,
                        false,
                        false,
                        -1
                    )

                    dOS.create_gui_element(dOS, "TextBox", {
                        Parent = pop,
                        Size = UDim2.fromScale(1, 1),
                        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
                        TextColor3 = dOS.THEME.TEXT_LIGHT,
                        Text = msg.timestamp,
                        TextScaled = true,
                        ClearTextOnFocus = false,
                        TextXAlignment = Enum.TextXAlignment.Center,
                        TextYAlignment = Enum.TextYAlignment.Center,
                    })
                end)

                -- user id
                make_action_btn(90301797579386, 2, function()
                    local _, pop = dOS.create_basic_window(
                        dOS,
                        "UserID",
                        200,
                        100,
                        true,
                        true,
                        false,
                        false,
                        -1
                    )

                    dOS.create_gui_element(dOS, "TextBox", {
                        Parent = pop,
                        Size = UDim2.fromScale(1, 1),
                        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
                        TextColor3 = dOS.THEME.TEXT_LIGHT,
                        Text = dOS._Players:GetUserId(msg.sender),
                        TextScaled = true,
                        ClearTextOnFocus = false,
                        TextXAlignment = Enum.TextXAlignment.Center,
                        TextYAlignment = Enum.TextYAlignment.Center,
                    })
                end)

                -- username
                make_action_btn(128851059336118, 3, function()
                    local _, pop = dOS.create_basic_window(
                        dOS,
                        "Username",
                        200,
                        100,
                        true,
                        true,
                        false,
                        false,
                        -1
                    )

                    dOS.create_gui_element(dOS, "TextBox", {
                        Parent = pop,
                        Size = UDim2.fromScale(1, 1),
                        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
                        TextColor3 = dOS.THEME.TEXT_LIGHT,
                        Text = msg.sender,
                        TextScaled = true,
                        ClearTextOnFocus = false,
                        TextXAlignment = Enum.TextXAlignment.Center,
                        TextYAlignment = Enum.TextYAlignment.Center,
                    })
                end)
            end

            -- message body
            if msg.type == "IMAGE_MESSAGE" then
                local img_wrap = dOS.create_gui_element(dOS, "Frame", {
                    Parent = msg_frame,
                    Size = UDim2.fromOffset(200, IMAGE_H),
                    Position = UDim2.fromOffset(10, CONTENT_Y),
                    BackgroundColor3 = dOS.THEME.CALC_DISPLAY_BG,
                })

                dOS.create_gui_element(
                    dOS,
                    "UICorner",
                    { Parent = img_wrap, CornerRadius = UDim.new(0, 6) }
                )

                -- TODO: make it conditional if WOS fix their api
                -- image failed to load
                dOS.create_gui_element(dOS, "ImageLabel", {
                    Parent = img_wrap,
                    Image = 132584257436077,
                    Size = UDim2.fromOffset(20, 20),
                    Position = UDim2.fromScale(0.5, 0.5),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                })

                -- image
                dOS.create_gui_element(dOS, "ImageLabel", {
                    Parent = img_wrap,
                    Image = tonumber(msg.image_id),
                    Size = UDim2.fromScale(1, 1),
                    Position = UDim2.fromScale(0.5, 0.5),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                })

                -- image id
                msg_action_btn(76311199408449, 4, function()
                    local _, pop = dOS.create_basic_window(
                        dOS,
                        "ImageID",
                        200,
                        100,
                        true,
                        true,
                        false,
                        false
                    )

                    dOS.create_gui_element(dOS, "TextBox", {
                        Parent = pop,
                        Size = UDim2.fromScale(1, 1),
                        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
                        TextColor3 = dOS.THEME.TEXT_LIGHT,
                        Text = tonumber(msg.image_id),
                        TextScaled = true,
                        ClearTextOnFocus = false,
                    })
                end)

                msg_frame.Size = UDim2.new(1, -20, 0, CONTENT_Y + IMAGE_H + 12)
            else
                -- text message
                local content = msg.content or ""
                local chars_per_ln =
                    math.max(1, math.floor((area_w - 44) / (font_size * 0.6)))
                local single_lh = font_size + 2
                local lines = 0

                for line in content:gmatch("([^\n]*)") do
                    lines += 1
                    if #line > chars_per_ln then
                        lines += math.floor(#line / chars_per_ln)
                    end
                end

                local text_h = lines * 0.5 * single_lh + 10

                dOS.create_gui_element(dOS, "TextBox", {
                    Parent = msg_frame,
                    Text = content,
                    BackgroundTransparency = 1,
                    TextEditable = false,
                    TextSize = font_size,
                    TextColor3 = dOS.THEME.TEXT_LIGHT,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    Size = UDim2.new(1, -20, 0, text_h),
                    Position = UDim2.fromOffset(10, CONTENT_Y),
                })

                msg_frame.Size = UDim2.new(1, -20, 0, CONTENT_Y + text_h + 10)
            end

            report_progress(rev + 1)
            task.wait()
        end

        if state.render_token ~= my_token then return end
        local t = my_token
        task.spawn(function() finish_loading(t) end)
    end

    draw_channel_list = function()
        for _, child in pairs(ui.channel_list:GetChildren()) do
            if child ~= ui.active_indicator then child:Destroy() end
        end

        local y_cursor = 6
        state.channel_y_map = {}

        for channel_id, channel_data in pairs(dOS._G_CHAT_DATA.channels) do
            local is_active = (channel_id == state.current_channel_id)
            local cap_y = y_cursor
            state.channel_y_map[channel_id] = cap_y

            local chan_btn
            chan_btn = dOS.create_gui_element(dOS, "TextButton", {
                Parent = ui.channel_list,
                Text = "",
                Size = UDim2.new(1, -12, 0, ITEM_BTN_H),
                Position = UDim2.fromOffset(8, cap_y),
                BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_HOVER,
                BackgroundTransparency = is_active and 0.68 or 1,
                ZIndex = 2,
                AutoButtonColor = true,
            })

            dOS.create_gui_element(
                dOS,
                "UICorner",
                { Parent = chan_btn, CornerRadius = UDim.new(0, 7) }
            )

            local has_pw = channel_data.password_hash
                and channel_data.password_hash
                    ~= derive_channel_key(dOS, "")

            dOS.create_gui_element(dOS, "ImageLabel", {
                Parent = chan_btn,
                -- lock icon if has_pw, hashtag icon otherwise
                Image = if has_pw then 13967666260 else 13649324397,
                ImageColor3 = has_pw and Color3.fromRGB(220, 170, 80)
                    or (
                        is_active and dOS.THEME.TEXT_LIGHT or dOS.THEME.TEXT_DIM
                    ),
                Size = UDim2.fromOffset(14, 14),
                Position = UDim2.new(0, 8, 0.5, -7),
                BackgroundTransparency = 1,
                ZIndex = 3,
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = chan_btn,
                Text = channel_data.name or channel_id,
                Size = UDim2.new(1, -30, 1, 0),
                Position = UDim2.fromOffset(26, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundTransparency = 1,
                Font = is_active and dOS.FONT_BOLD or dOS.FONT_REGULAR,
                TextColor3 = is_active and dOS.THEME.TEXT_LIGHT
                    or dOS.THEME.TEXT_DIM,
                TextSize = 12,
                ZIndex = 3,
            })

            chan_btn.MouseButton1Click:Connect(function()
                -- debounce
                if state.channel_click_lock then return end

                state.channel_click_lock = true
                state.current_channel_id = channel_id

                draw_channel_list()

                local target_y = state.channel_y_map[channel_id] or cap_y
                dOS.Tween
                    .new(
                        ui.active_indicator,
                        { Position = UDim2.fromOffset(0, target_y + 2) },
                        ti_bounce()
                    )
                    :Play()

                draw_message_area()

                -- lock through bounce + TICK
                task.wait(0.52)
                task.wait()
                state.channel_click_lock = false
            end)

            y_cursor += ITEM_H
        end

        ui.channel_list.CanvasSize = UDim2.fromOffset(0, y_cursor + 6)
    end

    -- events

    local multiple_instances = false

    local function is_connected(conn_id)
        for _, existing in ipairs(dOS._G_CHAT_DATA.connections) do
            if existing == conn_id then
                warn(
                    "[dOS Connect] CONFLICT: "
                        .. conn_id
                        .. " already registered."
                )
                multiple_instances = true
                return true
            end
        end
        return false
    end

    -- send text
    if not is_connected("input_button") then
        input_button.MouseButton1Click:Connect(function()
            if state.input_lock then return end
            state.input_lock = true

            dOS.RequestStringAsync(dOS, "Send a message", "", function(text)
                if text ~= "" then
                    send_message({ type = "TEXT_MESSAGE", content = text })
                end
                state.input_lock = false
            end)
        end)

        table.insert(dOS._G_CHAT_DATA.connections, "input_button")
    end

    -- send image
    if not is_connected("image_button") then
        image_button.MouseButton1Click:Connect(function()
            dOS.RequestStringAsync(dOS, "Enter Asset ID", "", function(id)
                if tonumber(id) then
                    send_message({ type = "IMAGE_MESSAGE", image_id = id })
                end
            end)
        end)

        table.insert(dOS._G_CHAT_DATA.connections, "image_button")
    end

    -- anonymous toggle
    if not is_connected("user_panel") then
        user_panel.MouseButton1Click:Connect(function()
            dOS._G_CHAT_DATA.anonymous_username =
                not dOS._G_CHAT_DATA.anonymous_username

            username_label.Text = dOS._G_CHAT_DATA.anonymous_username
                    and "Anonymous: ON"
                or "Anonymous: OFF"

            local col = dOS._G_CHAT_DATA.anonymous_username
                    and Color3.fromRGB(215, 130, 25)
                or dOS.THEME.ACCENT_BUTTON_HOVER

            dOS.Tween
                .new(anon_icon, { BackgroundColor3 = col }, ti_fast())
                :Play()
        end)

        table.insert(dOS._G_CHAT_DATA.connections, "user_panel")
    end

    -- add channel
    if not is_connected("plus_channel_btn") then
        plus_channel_btn.MouseButton1Click:Connect(function()
            dOS.RequestStringAsync(dOS, "Network", "", function(channel_id)
                if
                    channel_id == "" or dOS._G_CHAT_DATA.channels[channel_id]
                then
                    return
                end

                dOS.RequestStringAsync(
                    dOS,
                    "Name",
                    channel_id,
                    function(channel_name)
                        dOS.RequestStringAsync(
                            dOS,
                            "Passwd (nothing = public)",
                            "",
                            function(password)
                                dOS._G_CHAT_DATA.channels[channel_id] = {
                                    name = channel_name,
                                    password_hash = derive_channel_key(
                                        dOS,
                                        password
                                    ),
                                    messages = {},
                                }

                                draw_channel_list()

                                -- snap indicator to active channel
                                local snap_y = state.channel_y_map[state.current_channel_id]
                                    or 6
                                ui.active_indicator.Position =
                                    UDim2.fromOffset(0, snap_y + 2)
                            end
                        )
                    end
                )
            end)
        end)

        table.insert(dOS._G_CHAT_DATA.connections, "plus_channel_btn")
    end

    -- remove / clear channel
    if not is_connected("minus_channel_btn") then
        minus_channel_btn.MouseButton1Click:Connect(function()
            if state.current_channel_id == "dOS-General" then
                dOS.MessageBox.show(dOS, {
                    type = "Default",
                    title = "Confirmation",
                    message = "Delete ALL messages in dOS-General?\nThis cannot be undone.",
                    buttons = {
                        {
                            text = "Confirm",
                            callback = function()
                                dOS._G_CHAT_DATA.channels[state.current_channel_id].messages =
                                    {}
                                save_chat_data(dOS)
                                draw_channel_list()

                                local snap_y = state.channel_y_map[state.current_channel_id]
                                    or 6
                                ui.active_indicator.Position =
                                    UDim2.fromOffset(0, snap_y + 2)

                                draw_message_area()
                            end,
                        },
                        { text = "Cancel" },
                    },
                })
                return
            end

            dOS._G_CHAT_DATA.channels[state.current_channel_id] = nil
            state.current_channel_id = "dOS-General"

            draw_channel_list()

            local snap_y = state.channel_y_map[state.current_channel_id] or 6
            ui.active_indicator.Position = UDim2.fromOffset(0, snap_y + 2)

            draw_message_area()
        end)

        table.insert(dOS._G_CHAT_DATA.connections, "minus_channel_btn")
    end

    -- cleanup
    if not is_connected("win_frame") then
        win_frame.Destroying:Connect(function()
            state.is_active = false
            dOS._G_CHAT_DATA.redraw_function = nil
            dOS._G_CHAT_DATA.active_channel = nil
            dOS._G_CHAT_DATA.connections = {}
            save_chat_data(dOS)
        end)

        table.insert(dOS._G_CHAT_DATA.connections, "win_frame")
    end

    if multiple_instances then
        dOS.MessageBox.warning(
            dOS,
            "Window Conflict",
            "Another instance is already open.\nThis window is Read-Only.",
            nil,
            true
        )
    end

    if not multiple_instances then
        dOS._G_CHAT_DATA.redraw_function = draw_message_area
        dOS._G_CHAT_DATA.active_channel = state.current_channel_id
    end

    draw_channel_list()

    local init_y = state.channel_y_map[state.current_channel_id] or 6
    ui.active_indicator.Position = UDim2.fromOffset(0, init_y + 2)

    draw_message_area()
end

return M

-- EOF