--[[
    "Widget primitives module for dOS"
    
    @module gui
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

local _G_SFX_IDS = {
    6895079853,
    123690431798959,
    109932640832596,
    6976441148,
    16941256079,
    9114183565,
    18211662781,
    9113009987,
    101503662514198,
    9113880220,
    9112955724,
    136521773415332,
}

local function _is_virtual_screen(dOS, t)
    if not t then
        return false
    end

    if dOS and dOS.DWM and dOS.DWM.is_virtual_screen then
        return dOS.DWM.is_virtual_screen(t)
    end

    local s, r = pcall(function()
        return t.__dwm_virtual_screen__
    end)

    return s and r == true
end

function M.create_gui_element(dOS, type_str, props)
    -- resolve virtual screen proxies to real hardware
    if props and props.Parent then
        if _is_virtual_screen(dOS, props.Parent) then
            local dwm_state = dOS.DWM and dOS.DWM._state
            if dwm_state then
                local resolved_hw = dwm_state._screen_hw_override
                    or (
                        dwm_state.screens[dwm_state.primary_id]
                        and dwm_state.screens[dwm_state.primary_id].hw
                    )
                if resolved_hw then
                    props.Parent = resolved_hw
                end
            end
        end
    end

    local target_screen = dOS and dOS.screen
    if _is_virtual_screen(dOS, target_screen) then
        local dwm_state = dOS.DWM and dOS.DWM._state
        if dwm_state then
            local resolved_hw = dwm_state._screen_hw_override
                or (
                    dwm_state.screens[dwm_state.primary_id]
                    and dwm_state.screens[dwm_state.primary_id].hw
                )
            if resolved_hw then
                target_screen = resolved_hw
            end
        end
    end

    if not target_screen or not target_screen.CreateElement then
        logError(
            `[create_gui_element] HARDWARE_ERROR: No target_screen ('{target_screen}') or no target_screen.CreateElement.`
        )
        return nil
    end

    if
        not dOS.os_settings.round_corners
        and type_str == "UICorner"
        and props.CornerRadius ~= UDim.new(1, 0)
    then
        return
    end

    if type_str == "RealUICorner" then
        type_str = "UICorner"
    end

    local is_fake_frame = (type_str == "Frame")
    if is_fake_frame then
        type_str = "TextButton"
        props.Text = props.Text or ""
    end

    if type_str == "RealFrame" then
        type_str = "Frame"
    end

    local creation_props = props.Properties or {}
    if
        type_str ~= "UIListLayout"
        and type_str ~= "UIGridLayout"
        and type_str ~= "UIPadding"
        and type_str ~= "UICorner"
        and type_str ~= "UIGradient"
        and type_str ~= "UIStroke"
    then
        creation_props.Visible = props.Visible == nil and true or props.Visible
        creation_props.Active = props.Active == nil and true or props.Active
    end

    if props.Size then
        creation_props.Size = props.Size
    end

    if props.AutomaticSize then
        creation_props.AutomaticSize = props.AutomaticSize
    end

    if props.Position then
        creation_props.Position = props.Position
    end

    if props.BackgroundColor3 then
        creation_props.BackgroundColor3 = props.BackgroundColor3
    end

    if props.BorderSizePixel then
        creation_props.BorderSizePixel = props.BorderSizePixel
    end

    if props.ZIndex then
        creation_props.ZIndex = props.ZIndex
    end

    if props.ClipsDescendants then
        creation_props.ClipsDescendants = props.ClipsDescendants
    end

    if creation_props.Parent then
        creation_props.Parent = nil
    end

    if
        type_str == "TextLabel"
        or type_str == "TextButton"
        or type_str == "TextBox"
    then
        creation_props.Text = props.Text or type_str

        if typeof(props.TextColor3) == "Color3" then
            creation_props.TextColor3 = props.TextColor3
        elseif
            type(props.TextColor3) == "string"
            and props.TextColor3:match("^#?%x%x%x%x%x%x$")
        then
            creation_props.TextColor3 = Color3.fromHex(props.TextColor3)
            props.TextColor3 = creation_props.TextColor3
        elseif props.TextColor3 ~= nil then
            warn(
                `[GUI]: Invalid \`TextColor3\` value ('{props.TextColor3}') for {type_str} {`'{props.Name}'` or "(Unamed)"}.`
            )
            creation_props.TextColor3 = Color3.new(0, 0, 0)
            props.TextColor3 = Color3.new(0, 0, 0)
        end

        if props.TextWrapped then
            creation_props.TextWrapped = props.TextWrapped
        end

        if props.TextTruncate then
            creation_props.TextTruncate = props.TextTruncate
        else
            creation_props.TextTruncate = Enum.TextTruncate.AtEnd
        end

        if props.RichText ~= false then
            creation_props.RichText = true
        end
    end

    local element = target_screen:CreateElement(type_str, creation_props)
    if not element then
        return nil
    end

    if props.Parent and props.Parent ~= target_screen then
        element.Parent = props.Parent
    end

    if props.Name then
        element.Name = props.Name
    end

    -- frame
    if type_str == "RealFrame" then
        element.BackgroundTransparency = props.BackgroundTransparency == nil
                and 0
            or props.BackgroundTransparency
        element.BorderSizePixel = props.BorderSizePixel or 1
        element.BorderColor3 = props.BorderColor3 or dOS.THEME.BORDER_DARK

    -- button
    elseif type_str == "TextButton" or type_str == "Button" then
        element.TextColor3 = props.TextColor3 or dOS.THEME.TEXT_DARK

        if element.TextTransparency then
            element.TextTransparency = props.TextTransparency
        end

        element.Font = props.Font or dOS.FONT_BOLD
        element.TextXAlignment = props.TextXAlignment
            or Enum.TextXAlignment.Center
        element.TextYAlignment = props.TextYAlignment
            or Enum.TextYAlignment.Center

        if props.TextSize then
            element.TextScaled = dOS.os_settings.global_text_scaled
            element.TextSize = props.TextSize
        elseif
            dOS.os_settings.global_text_scaled == false
            and dOS.os_settings.global_font_size
        then
            element.TextScaled = dOS.os_settings.global_text_scaled
            element.TextSize = dOS.os_settings.global_font_size
        else
            element.TextScaled = props.TextScaled == nil and true
                or props.TextScaled
        end

        element.AutoButtonColor = if props.AutoButtonColor == nil
            then false
            else props.AutoButtonColor

        element.BackgroundColor3 = props.BackgroundColor3
            or dOS.THEME.ACCENT_BUTTON_BG

        if props.BorderColor3 or props.BorderColor then
            element.BorderColor3 = props.BorderColor3
        end

        if element.Active then
            element.Active = props.Active
        end

        if element.BorderSizePixel then
            element.BorderSizePixel = props.BorderSizePixel == nil and 1
                or props.BorderSizePixel
        end

        if is_fake_frame then
            element.BackgroundTransparency = props.BackgroundTransparency == nil
                    and 0
                or props.BackgroundTransparency
            element.BorderColor3 = props.BorderColor3 or dOS.THEME.BORDER_DARK
        else
            -- round corners when enabled
            -- HACK HACK HACK
            if dOS.os_settings.round_corners then
                M.create_gui_element(dOS, "UICorner", {
                    Parent = element,
                    CornerRadius = UDim.new(0, 4),
                })
            end
        end
    elseif type_str == "TextBox" then
        element.TextColor3 = props.TextColor3 or dOS.THEME.TEXT_LIGHT
        element.Font = props.Font or dOS.FONT_REGULAR
        element.TextXAlignment = props.TextXAlignment
            or Enum.TextXAlignment.Left
        element.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Top
        element.TextWrapped = props.TextWrapped or false
        element.BackgroundTransparency = props.BackgroundTransparency == nil
                and 0
            or props.BackgroundTransparency
        element.BackgroundColor3 = props.BackgroundColor3
            or dOS.THEME.CALC_DISPLAY_BG
        element.TextEditable = props.TextEditable or false
        element.ClearTextOnFocus = props.ClearTextOnFocus or false

        if props.TextSize then
            element.TextScaled = dOS.os_settings.global_text_scaled
            element.TextSize = props.TextSize
        else
            element.TextScaled = props.TextScaled == nil and true
                or props.TextScaled
        end
    elseif type_str == "ImageButton" or type_str == "ImageLabel" then
        if type_str ~= "ImageLabel" and element.AutoButtonColor then
            if props.DisableHoverEffect then
                element.AutoButtonColor = false
            else
                element.AutoButtonColor = if props.AutoButtonColor == nil
                    then true
                    else props.AutoButtonColor
            end
        end

        element.BackgroundTransparency = props.BackgroundTransparency == nil
                and 1
            or props.BackgroundTransparency

        if props.Image then
            element.Image = "rbxassetid://" .. tostring(props.Image)
        end

        if props.ScaleType then
            element.ScaleType = props.ScaleType
        end

        if props.TileSize then
            element.TileSize = props.TileSize
        end

        if props.AnchorPoint then
            element.AnchorPoint = props.AnchorPoint
        end

        if props.ImageColor3 then
            element.ImageColor3 = props.ImageColor3
        end

        if props.BorderSizePixel then
            element.BorderSizePixel = props.BorderSizePixel
        end

        if props.BorderColor3 then
            element.BorderColor3 = props.BorderColor3
        end

        if props.ImageTransparency then
            element.ImageTransparency = props.ImageTransparency
        end

        if props.HoverImage then
            element.HoverImageContent = "rbxassetid://"
                .. tostring(props.HoverImage)
        end

        if props.PressedImage then
            element.PressedImageContent = "rbxassetid://"
                .. tostring(props.PressedImage)
        end
    elseif type_str == "TextLabel" then
        element.TextColor3 = props.TextColor3 or dOS.THEME.TEXT_LIGHT
        element.Font = props.Font or dOS.FONT_REGULAR
        element.TextXAlignment = props.TextXAlignment
            or Enum.TextXAlignment.Center
        element.TextYAlignment = props.TextYAlignment
            or Enum.TextYAlignment.Center
        element.Visible = props.Visible or true
        element.TextTransparency = props.TextTransparency or 0

        -- labels are transparent by default
        element.BackgroundTransparency = props.BackgroundTransparency == nil
                and 1
            or props.BackgroundTransparency

        if props.TextSize then
            element.TextScaled = dOS.os_settings.global_text_scaled
            element.TextSize = props.TextSize
        elseif
            dOS.os_settings.global_text_scaled == false
            and dOS.os_settings.global_font_size
        then
            element.TextScaled = dOS.os_settings.global_text_scaled
            element.TextSize = dOS.os_settings.global_font_size
        else
            element.TextScaled = props.TextScaled == nil and true
                or props.TextScaled
        end
    elseif type_str == "ScrollingFrame" then
        element.BorderSizePixel = props.BorderSizePixel
        element.ScrollBarThickness = props.ScrollBarThickness or 1
        element.ScrollingDirection = props.ScrollingDirection
            or Enum.ScrollingDirection.Y

        if element.BorderColor3 then
            element.BorderColor3 = props.BorderColor3
                or dOS.THEME.CALC_OP_BUTTON_BG
        end

        if element.BorderColor then
            element.BorderColor = props.BorderColor
                or dOS.THEME.CALC_OP_BUTTON_BG
        end

        element.ScrollBarImageColor3 = props.ScrollBarImageColor3
            or dOS.THEME.CALC_OP_BUTTON_HOVER

        if props.ScrollBarImageTransparency then
            element.ScrollBarImageTransparency =
                props.ScrollBarImageTransparency
        end

        if element.BackgroundColor3 and not props.BackgroundTransparency then
            element.BackgroundColor3 = props.BackgroundColor3
                or dOS.THEME.TASKBAR_BG
        end

        if props.CanvasSize then
            element.CanvasSize = props.CanvasSize
        end

        if props.AutomaticCanvasSize then
            element.AutomaticCanvasSize = props.AutomaticCanvasSize
        end

        if props.TopImage then
            element.TopImage = props.TopImage
        end

        if props.MidImage then
            element.MidImage = props.MidImage
        end

        if props.BottomImage then
            element.BottomImage = props.BottomImage
        end
    elseif type_str == "UIListLayout" then
        element.SortOrder = props.SortOrder or Enum.SortOrder.LayoutOrder
        element.Padding = props.Padding or UDim.new(0, 0)

        if props.FillDirection then
            element.FillDirection = props.FillDirection
        end

        if props.HorizontalAlignment then
            element.HorizontalAlignment = props.HorizontalAlignment
        end

        if props.VerticalAlignment then
            element.VerticalAlignment = props.VerticalAlignment
        end
    elseif type_str == "UIGridLayout" then
        element.CellSize = props.CellSize
        element.CellPadding = props.CellPadding
        element.SortOrder = props.SortOrder or Enum.SortOrder.LayoutOrder
    elseif type_str == "UIPadding" then
        element.PaddingTop = props.PaddingTop or UDim.new(0, 0)
        element.PaddingRight = props.PaddingRight or UDim.new(0, 0)
        element.PaddingLeft = props.PaddingLeft or UDim.new(0, 0)
    elseif type_str == "UICorner" then
        element.CornerRadius = props.CornerRadius or UDim.new(0, 3)
    elseif type_str == "UIStroke" then
        if props.Color then
            element.Color = props.Color
        end

        if props.Thickness then
            element.Thickness = props.Thickness
        end

        if props.Transparency then
            element.Transparency = props.Transparency
        end
    elseif type_str == "CanvasGroup" then
        if props.Size then
            element.Size = props.Size
        end

        if props.GroupTransparency then
            element.GroupTransparency = props.GroupTransparency
        end
    elseif type_str == "UIGradient" then
        element.Color = props.color
            or ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(0.5, dOS.THEME.ACCENT_BUTTON_HOVER),
                ColorSequenceKeypoint.new(1, dOS.THEME.ACCENT_BUTTON_HOVER),
            })

        if props.Rotation then
            element.Rotation = props.Rotation
        end

        element.Transparency = props.Transparency
            or NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.4, 0),
                NumberSequenceKeypoint.new(1, 0.3),
            })
    else
        if type_str ~= "Frame" then
            warn(`[GUI System]: Unknown type "{type_str}".`)
        end
    end

    if props.OnClick and element.MouseButton1Click then
        element.MouseButton1Click:Connect(function()
            if
                dOS.speaker
                and dOS.speaker.Audio
                and dOS.audio_player_data.is_playing == false
                and _G_SFX_IDS
            then
                dOS.speaker.Audio = _G_SFX_IDS[math.random(1, #_G_SFX_IDS)]
                task.wait()
                dOS.speaker:Trigger()
            end
            props.OnClick()
        end)
    end

    if
        not props.DisableHoverEffect
        and (props.HoverColor or props.OnEnter or props.OnLeave)
    then
        if dOS.HoverManager then
            dOS.HoverManager.register(element, {
                HoverColor = props.HoverColor,
                BackgroundColor3 = props.BackgroundColor3,
                OnEnter = props.OnEnter,
                OnLeave = props.OnLeave,
            })
        end
    end

    if props.ZIndex then
        element.ZIndex = props.ZIndex
    end

    if props.Size then
        element.Size = props.Size
    end

    if props.Position then
        element.Position = props.Position
    end

    if props.AnchorPoint then
        element.AnchorPoint = props.AnchorPoint
    end

    if props.BackgroundTransparency and element.BackgroundTransparency then
        element.BackgroundTransparency = props.BackgroundTransparency
    end

    -- last check for unknown props
    local EXCLUDED_PROPS = {
        "DisableHoverEffect",
        "OnClick",
        "HoverColor",
        "OnEnter",
        "OnLeave",
    }

    local function isCustom(p)
        for _, excludedProp in ipairs(EXCLUDED_PROPS) do
            if tostring(p) == excludedProp then
                return true
            end
        end

        return false
    end

    for prop, value in pairs(props) do
        if
            pcall(function()
                return element[prop] and element[prop] ~= nil
            end)
            or isCustom(prop)
        then
            continue
        end

        if tostring(prop) == "Properties" then
            for subProp, subVal in ipairs(value) do
                if
                    pcall(function()
                        return element[subProp] and element[subProp] ~= nil
                    end)
                then
                    continue
                end

                local success, assign_error = pcall(function()
                    element[subProp] = subVal
                end)

                if not success then
                    logError(
                        string.format(
                            "[create_gui_element] DIRECT_ASSIGN_ERR: Could not assign '%s[%s] = %s'. Error:\n%s",
                            tostring(element),
                            tostring(subProp),
                            tostring(subVal),
                            tostring(assign_error)
                        )
                    )
                else
                    print(
                        string.format(
                            "[create_gui_element] Unknown property '%s' on element '%s' assigned successfully.",
                            tostring(subProp),
                            tostring(element)
                        )
                    )
                end
            end

            continue
        end

        local success, assign_error = pcall(function()
            element[prop] = value
        end)

        if not success then
            logError(
                string.format(
                    "[create_gui_element] DIRECT_ASSIGN_ERR: Could not assign '%s[%s] = %s'. Error:\n%s",
                    tostring(element),
                    tostring(prop),
                    tostring(value),
                    tostring(assign_error)
                )
            )
        else
            print(
                string.format(
                    "[create_gui_element] Unknown property '%s' on element '%s' assigned successfully.",
                    tostring(prop),
                    tostring(element)
                )
            )
        end
    end

    return element
end

function M.create_slider(
    dOS,
    parent,
    position,
    size,
    min_val,
    max_val,
    current_val,
    callback
)
    local track = M.create_gui_element(dOS, "Frame", {
        Parent = parent,
        Size = size,
        Position = position,
        BackgroundColor3 = dOS.THEME.CALC_DISPLAY_BG,
    })

    local handle = M.create_gui_element(dOS, "TextButton", {
        Parent = track,
        Text = "",
        Size = UDim2.fromOffset(10, size.Y.Offset + 10),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
    })

    local function update_handle_position(value)
        local percent = (value - min_val) / (max_val - min_val)
        percent = math.clamp(percent, 0, 1)
        handle.Position = UDim2.fromScale(percent, 0.5)
    end

    handle.MouseButton1Down:Connect(function(x, y)
        local cursor_object = nil

        if dOS and dOS.DWM and dOS.DWM._state then
            for _, ctx in pairs(dOS.DWM._state.screens) do
                pcall(function()
                    for _, cursor in pairs(ctx.hw:GetCursors()) do
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
                end)

                if cursor_object then
                    break
                end
            end
        end

        if
            not cursor_object
            and dOS
            and dOS.screen
            and dOS.screen.GetCursors
        then
            pcall(function()
                for _, cursor in pairs(dOS.screen:GetCursors()) do
                    if
                        (Vector2.new(x, y) - Vector2.new(cursor.X, cursor.Y)).Magnitude
                        < 50
                    then
                        cursor_object = cursor
                        break
                    end
                end
            end)
        end

        if not cursor_object then
            return
        end

        -- capture shield via DragManager
        dOS.DragManager.start_slider_drag(dOS, handle, function(cursor_x)
            local relative_x = cursor_x - track.AbsolutePosition.X
            local percent = math.clamp(relative_x / track.AbsoluteSize.X, 0, 1)
            local new_val = min_val + (max_val - min_val) * percent

            update_handle_position(new_val)

            if callback then
                callback(new_val)
            end
        end, cursor_object)
    end)

    -- stop dragging if released while hovering
    handle.MouseButton1Up:Connect(function()
        dOS.DragManager.stop_drag(dOS)
    end)

    track.MouseButton1Up:Connect(function()
        dOS.DragManager.stop_drag(dOS)
    end)

    parent.MouseButton1Up:Connect(function()
        dOS.DragManager.stop_drag(dOS)
    end)

    update_handle_position(current_val)
    return track
end

return M

-- EOF