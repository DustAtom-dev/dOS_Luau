--[[
    "Message Box module for dOS"
    
    @module msgbox
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

--- TYPES

--- APPEARANCE

local ICON_IMAGE = {
    Error = 81435836476705,
    Warning = 85147473315465,
    Info = 10030911976,
}

local ICON_TEXT = {
    Error = "X",
    Warning = "!",
    Info = "i",
}

local TYPE_STYLE = {
    Default = { has_icon = false },
    Error = { accent = Color3.fromRGB(192, 40, 27), has_icon = true },
    Warning = { accent = Color3.fromRGB(210, 140, 15), has_icon = true },
    Info = { accent = Color3.fromRGB(22, 130, 214), has_icon = true },
}

-- layout
local L = {
    W = 440,
    H = 210,
    STRIPE = 60,
    ICON_SZ = 28,
    RULE_Y = 50,
    TITLE_Y = 16,
    TITLE_H = 28,
    MSG_Y = 58,
    BTN_H = 32,
    BTN_W = 96,
    BTN_GAP = 8,
    PAD = 14,
    CLOSE_SZ = 22,
}

-- button tweening
local PRESS_T = 0.09

local FOCAL = 450

--- EASING

local function easeOutBack(t)
    local s = 1.70158
    local t1 = t - 1
    return 1 + (s + 1) * t1 * t1 * t1 + s * t1 * t1
end

local function easeInQuad(t)
    return t * t
end

--- PERSPECTIVE

local function perspectiveFrame(W, H, scale, angle_deg)
    local a = math.rad(angle_deg)
    local cos_a = math.cos(a)
    local sin_a = math.sin(a)

    local half_h = (H / 2) * scale
    local X = half_h * sin_a

    X = math.min(X, FOCAL * 0.99)

    local top_proj = half_h * cos_a * FOCAL / (FOCAL + X)
    local bot_proj = half_h * cos_a * FOCAL / (FOCAL - X)

    return W * scale, top_proj + bot_proj, top_proj
end

--- TRANSPARENCY

local function saveOriginalTransparencies(inst)
    if not inst then return end

    local function tag(obj)
        if not obj:IsA("GuiObject") then return end
        if obj:GetAttribute("OrigBgTrans") == nil then
            obj:SetAttribute("OrigBgTrans", obj.BackgroundTransparency)
            if
                obj:IsA("TextLabel")
                or obj:IsA("TextButton")
                or obj:IsA("TextBox")
            then
                obj:SetAttribute("OrigTextTrans", obj.TextTransparency)
            end
            if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                obj:SetAttribute("OrigImgTrans", obj.ImageTransparency)
            end
        end
    end

    tag(inst)
    for _, child in ipairs(inst:GetDescendants()) do
        tag(child)
    end
end

local function setTransparency(frame, use_canvas, t)
    if use_canvas then
        frame.GroupTransparency = t
    else
        -- fallback: recursive fade
        local function applyFade(obj)
            if not obj:IsA("GuiObject") then return end

            local origBg = obj:GetAttribute("OrigBgTrans") or 0
            obj.BackgroundTransparency = origBg + (1 - origBg) * t

            if
                obj:IsA("TextLabel")
                or obj:IsA("TextButton")
                or obj:IsA("TextBox")
            then
                local origText = obj:GetAttribute("OrigTextTrans") or 0
                obj.TextTransparency = origText + (1 - origText) * t
            end
            if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                local origImg = obj:GetAttribute("OrigImgTrans") or 0
                obj.ImageTransparency = origImg + (1 - origImg) * t
            end
        end

        applyFade(frame)
        for _, child in ipairs(frame:GetDescendants()) do
            applyFade(child)
        end
    end
end

local function tw(dOS, inst, props, t, style, dir)
    local info = dOS.TweenInfo.new(
        t,
        style or Enum.EasingStyle.Quad,
        dir or Enum.EasingDirection.Out
    )
    local handle = dOS.Tween.new(inst, props, info)
    handle:Play()
    return handle
end

--- ANIMATIONS

local function animOpen(dOS, frame, overlay, use_canvas)
    local DURATION = 0.45
    local START_SCALE = 0.60
    local START_ANGLE = 35.0
    local SCR_CX = dOS.screen_dimensions.X / 2
    local SCR_CY = dOS.screen_dimensions.Y / 2

    if not use_canvas then saveOriginalTransparencies(frame) end

    do
        local vw, vh, top_y =
            perspectiveFrame(L.W, L.H, START_SCALE, START_ANGLE)
        frame.Size = UDim2.fromOffset(math.floor(vw), math.floor(vh))
        frame.Position = UDim2.fromOffset(
            math.floor(SCR_CX - vw / 2),
            math.floor(SCR_CY - top_y)
        )
        setTransparency(frame, use_canvas, 1)
        if overlay then overlay.BackgroundTransparency = 1 end
    end

    task.spawn(function()
        local start_time = os.clock()
        local elapsed = 0.0

        repeat
            task.wait()
            -- break if closed mid animation
            if frame:GetAttribute("IsClosing") then return end

            elapsed = math.min(os.clock() - start_time, DURATION)
            local t = elapsed / DURATION
            local te = easeOutBack(t)

            local scale = math.min(START_SCALE + (1.0 - START_SCALE) * te, 1.0)
            local angle = START_ANGLE * math.max(1.0 - te, 0.0)

            local vw, vh, top_y = perspectiveFrame(L.W, L.H, scale, angle)
            local fx = math.floor(SCR_CX - vw / 2)
            local fy = math.floor(SCR_CY - top_y)

            frame.Size = UDim2.fromOffset(math.floor(vw), math.floor(vh))
            frame.Position = UDim2.fromOffset(fx, fy)

            setTransparency(frame, use_canvas, math.clamp(1.0 - te, 0, 1))
            if overlay and overlay.Name == "MsgBox_Overlay_Frame" then
                overlay.BackgroundTransparency =
                    math.clamp(1.0 - 0.52 * te, 0.52, 1)
            end
        until elapsed >= DURATION

        frame.Size = UDim2.fromOffset(L.W, L.H)
        local fn_cx = dOS.screen_dimensions.X / 2
        local fn_cy = dOS.screen_dimensions.Y / 2
        frame.Position = UDim2.fromOffset(
            math.floor(fn_cx - L.W / 2),
            math.floor(fn_cy - L.H / 2)
        )

        setTransparency(frame, use_canvas, 0)
        if overlay and overlay.Name == "MsgBox_Overlay_Frame" then
            overlay.BackgroundTransparency = 0.52
        end
    end)
end

local CLOSE_DURATION = 0.40

local function animClose(frame, overlay, use_canvas, onDone)
    local DURATION = CLOSE_DURATION
    local END_SCALE = 0.60

    local start_w, start_h, start_x, start_y

    if frame then
        start_w = frame.AbsoluteSize.X
        start_h = frame.AbsoluteSize.Y
        if start_w == 0 then start_w = L.W end
        if start_h == 0 then start_h = L.H end

        start_x = frame.AbsolutePosition.X
        start_y = frame.AbsolutePosition.Y
        if start_x == 0 and start_y == 0 then
            start_x = frame.Position.X.Offset
            start_y = frame.Position.Y.Offset
        end
    else
        start_w, start_h = L.W, L.H
        start_x, start_y = 0, 0
    end

    local center_x = start_x + start_w / 2
    local center_y = start_y + start_h / 2

    task.spawn(function()
        local start_time = os.clock()
        local elapsed = 0.0

        repeat
            task.wait()
            elapsed = math.min(os.clock() - start_time, DURATION)
            local t = elapsed / DURATION
            local te = easeInQuad(t)

            local scale = 1.0 - (1.0 - END_SCALE) * te
            local vw = math.floor(start_w * scale)
            local vh = math.floor(start_h * scale)
            local fx = math.floor(center_x - vw / 2)
            local fy = math.floor(center_y - vh / 2)

            if frame then
                frame.Size = UDim2.fromOffset(vw, vh)
                frame.Position = UDim2.fromOffset(fx, fy)
                setTransparency(frame, use_canvas, te)
            end

            if overlay and overlay.Name == "MsgBox_Overlay_Frame" then
                overlay.BackgroundTransparency = 0.52 + 0.48 * te
            end
        until elapsed >= DURATION

        if overlay and overlay.Destroy then overlay:Destroy() end
        if onDone then onDone() end
    end)
end

--- CORE

function M.show(dOS, config)
    local msg_type = config.type or "Default"
    local style = TYPE_STYLE[msg_type] or TYPE_STYLE.Default
    local accent = style.accent or dOS.THEME.ACCENT
    local steal = if config.steal_focus == nil
        then false
        else config.steal_focus

    local btns = {}
    local raw = config.buttons
    if raw and #raw > 0 then
        for _, b in ipairs(raw) do
            if type(b) == "string" then
                table.insert(btns, { text = b :: string })
            else
                table.insert(btns, b)
            end
        end
    else
        table.insert(btns, { text = "OK" })
    end

    local wait_thread = if steal then coroutine.running() else nil
    local result_text = nil
    local is_closing = false -- debounce multiple clicks

    local sw = dOS.screen_dimensions.X
    local sh = dOS.screen_dimensions.Y
    local ox = math.floor(sw / 2 - L.W / 2)
    local oy = math.floor(sh / 2 - L.H / 2)

    -- overlay
    local overlay =
        dOS.create_gui_element(dOS, if steal then "Frame" else "RealFrame", {
            Name = `MsgBox_Overlay_{if steal then "Frame" else "RealFrame"}`,
            Parent = dOS.screen,
            ZIndex = dOS.Z_INDEX.MSGBOX_OVERLAY,
            BackgroundColor3 = dOS.THEME.MSGBOX_OVERLAY_COLOR,
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
        })
    if not overlay then return nil end

    -- main frame
    local use_canvas = false
    local frame = nil

    frame = dOS.create_gui_element(dOS, "CanvasGroup", {
        Name = "MsgBox_Frame",
        Parent = overlay,
        ZIndex = dOS.Z_INDEX.MSGBOX,
        BackgroundColor3 = dOS.THEME.MSGBOX_BG,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(L.W, L.H),
        Position = UDim2.fromOffset(ox, oy),
        ClipsDescendants = true,
        GroupTransparency = 1,
    })
    dOS.create_gui_element(dOS, "UICorner", {
        Parent = frame,
        CornerRadius = UDim.new(0, 10),
    })

    if frame then
        use_canvas = true
    else
        frame = dOS.create_gui_element(dOS, "Frame", {
            Name = "MsgBox_Frame",
            Parent = overlay,
            ZIndex = dOS.Z_INDEX.MSGBOX,
            BackgroundColor3 = dOS.THEME.MSGBOX_BG,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(L.W, L.H),
            Position = UDim2.fromOffset(ox, oy),
            ClipsDescendants = true,
        })
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = frame,
            CornerRadius = UDim.new(0, 10),
        })
    end

    if not frame then
        if overlay.Destroy then overlay:Destroy() end
        return nil
    end

    local Z = (frame.ZIndex or dOS.Z_INDEX.MSGBOX) :: number
    local base_fs = (
        dOS.os_settings and dOS.os_settings.global_font_size or 14
    ) :: number

    -- left stripe
    dOS.create_gui_element(dOS, "Frame", {
        Name = "MsgBox_Stripe",
        Parent = frame,
        ZIndex = Z + 1,
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        Size = UDim2.new(0, L.STRIPE, 1, 0),
        Position = UDim2.fromOffset(0, 0),
    })

    -- icon
    if style.has_icon then
        local ix = math.floor((L.STRIPE - L.ICON_SZ) / 2)
        local iy = math.floor(L.H / 2 - L.ICON_SZ / 2)

        dOS.create_gui_element(dOS, "TextLabel", {
            Name = "MsgBox_IconText",
            Parent = frame,
            ZIndex = Z + 1,
            Text = ICON_TEXT[msg_type] or "?",
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Font = dOS.FONT_BOLD,
            TextSize = 20,
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(L.STRIPE, L.ICON_SZ + 4),
            Position = UDim2.fromOffset(0, iy - 2),
        })

        dOS.create_gui_element(dOS, "ImageLabel", {
            Name = "MsgBox_Icon",
            Parent = frame,
            ZIndex = Z + 2,
            Image = ICON_IMAGE[msg_type] or 0,
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(L.ICON_SZ, L.ICON_SZ),
            Position = UDim2.fromOffset(ix, iy),
        })
    end

    -- content area
    local cx2 = L.STRIPE + L.PAD
    local cw = L.W - L.STRIPE - L.PAD * 2

    dOS.create_gui_element(dOS, "TextLabel", {
        Name = "MsgBox_Title",
        Parent = frame,
        ZIndex = Z + 2,
        Text = config.title,
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        Font = dOS.FONT_BOLD,
        TextSize = base_fs + 7,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(cw, L.TITLE_H),
        Position = UDim2.fromOffset(cx2, L.TITLE_Y),
    })

    dOS.create_gui_element(dOS, "Frame", {
        Name = "MsgBox_Rule",
        Parent = frame,
        ZIndex = Z + 2,
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(cw, 1),
        Position = UDim2.fromOffset(cx2, L.RULE_Y),
    })

    local msg_h = L.H - L.MSG_Y - L.BTN_H - 20
    dOS.create_gui_element(dOS, "TextLabel", {
        Name = "MsgBox_Message",
        Parent = frame,
        ZIndex = Z + 2,
        Text = config.message,
        TextWrapped = true,
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        Font = dOS.FONT_BOLD,
        TextSize = base_fs + 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(cw, msg_h),
        Position = UDim2.fromOffset(cx2, L.MSG_Y),
    })

    -- buttons
    local n_btns = #btns
    local total_bw = n_btns * L.BTN_W + (n_btns - 1) * L.BTN_GAP
    local btn_start_x = L.W - total_bw - L.PAD
    local btn_y = L.H - L.BTN_H - 12

    local btn_normal = dOS.THEME.ACCENT or accent
    local btn_press = Color3.new(
        math.max(btn_normal.R - 0.20, 0),
        math.max(btn_normal.G - 0.20, 0),
        math.max(btn_normal.B - 0.20, 0)
    )

    for i, bcfg in ipairs(btns) do
        local bx = btn_start_x + (i - 1) * (L.BTN_W + L.BTN_GAP)
        local btn_ref = nil

        btn_ref = dOS.create_gui_element(dOS, "TextButton", {
            Name = "MsgBox_Btn_" .. bcfg.text,
            Parent = frame,
            ZIndex = Z + 3,
            Text = bcfg.text,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Font = dOS.FONT_BOLD,
            TextSize = 13,
            BackgroundColor3 = btn_normal,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(L.BTN_W, L.BTN_H),
            Position = UDim2.fromOffset(bx, btn_y),
            OnClick = function()
                if is_closing then return end
                is_closing = true
                if frame then frame:SetAttribute("IsClosing", true) end

                result_text = bcfg.text

                if btn_ref then
                    tw(dOS, btn_ref, { BackgroundColor3 = btn_press }, PRESS_T)
                end

                task.delay(PRESS_T + 0.02, function()
                    animClose(frame, overlay, use_canvas, function()
                        if not steal and bcfg.callback then bcfg.callback() end
                    end)

                    if steal and wait_thread then
                        task.delay(CLOSE_DURATION + 0.05, function()
                            coroutine.resume(
                                wait_thread :: thread,
                                result_text
                            )
                        end)
                    end
                end)
            end,
        })
    end

    if not steal then
        dOS.create_gui_element(dOS, "ImageButton", {
            Name = "MsgBox_Close",
            Parent = frame,
            ZIndex = Z + 4,
            Image = 136968209449975,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(L.CLOSE_SZ, L.CLOSE_SZ),
            Position = UDim2.new(1, -(L.CLOSE_SZ + 5), 0, 4),
            OnClick = function()
                if is_closing then return end
                is_closing = true
                if frame then frame:SetAttribute("IsClosing", true) end

                animClose(frame, overlay, use_canvas, nil)
            end,
        })

        local drag = dOS.create_gui_element(dOS, "Frame", {
            Name = "MsgBox_Drag",
            Parent = frame,
            ZIndex = Z + 3,
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(L.W - L.STRIPE - L.CLOSE_SZ - 14, 34),
            Position = UDim2.fromOffset(L.STRIPE, 0),
            Active = true,
        })

        if drag then
            pcall(function()
                drag.MouseButton1Down:Connect(function(x, y)
                    local cursor_object = nil

                    for _, cursor in pairs(dOS.screen:GetCursors()) do
                        if
                            (
                                Vector2.new(x, y)
                                - Vector2.new(cursor.X, cursor.Y)
                            ).Magnitude < 50
                        then
                            cursor_object = cursor
                            break
                        end
                    end

                    if cursor_object and dOS.DragManager then
                        dOS.DragManager.start_drag(dOS, frame, cursor_object)
                    end
                end)

                drag.MouseButton1Up:Connect(function()
                    if dOS.DragManager then dOS.DragManager.stop_drag(dOS) end
                end)
            end)
        end
    end

    if frame then
        pcall(function()
            frame.Destroying:Connect(function()
                if dOS.DragManager and dOS.DragManager.window == frame then
                    dOS.DragManager.stop_drag(dOS)
                end
            end)
        end)
    end

    animOpen(dOS, frame, overlay, use_canvas)

    if steal and wait_thread then
        coroutine.yield()
        return result_text
    end

    return nil
end

--- WRAPPERS

function M.error(dOS, title, message, buttons, steal_focus)
    return M.show(dOS, {
        type = "Error",
        title = title or "Error",
        message = message or "",
        buttons = buttons,
        steal_focus = steal_focus,
    })
end

function M.warning(dOS, title, message, buttons, steal_focus)
    return M.show(dOS, {
        type = "Warning",
        title = title or "Warning",
        message = message or "",
        buttons = buttons,
        steal_focus = steal_focus,
    })
end

function M.info(dOS, title, message, buttons, steal_focus)
    return M.show(dOS, {
        type = "Info",
        title = title or "Information",
        message = message or "",
        buttons = buttons,
        steal_focus = steal_focus,
    })
end

return M

-- EOF