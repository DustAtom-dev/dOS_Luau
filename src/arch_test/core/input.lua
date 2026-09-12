--[[
    "GUI input dialogs module for dOS"
    
    @module input
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

M.InputHandler = {
    isActive = false,
    onCompleteCallback = nil,
    last_input_username = nil,
    uiElements = {
        scrim = nil,
        frame = nil,
    },
    -- secondary-screen scrims
    secondary_scrims = {},
}

M.active_prompt_tweens = {}

--- DESTROY

function M.destroy_prompt_ui(dOS)
    if not M.InputHandler.isActive then
        return
    end

    M.InputHandler.isActive = false

    for _, tween in pairs(M.active_prompt_tweens) do
        tween:Cancel()
    end
    M.active_prompt_tweens = {}

    local scrim = M.InputHandler.uiElements.scrim
    local frame = M.InputHandler.uiElements.frame
    local tween_info = dOS.TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    if frame then
        dOS.Tween.new(frame, { BackgroundTransparency = 1 }, tween_info):Play()
    end

    if scrim then
        dOS.Tween.new(scrim, { BackgroundTransparency = 1 }, tween_info):Play()
    end

    -- fade out secondary scrims
    for _, sec_scrim in ipairs(M.InputHandler.secondary_scrims) do
        if sec_scrim and sec_scrim.Parent then
            dOS.Tween.new(sec_scrim, { BackgroundTransparency = 1 }, tween_info):Play()
        end
    end

    task.wait(0.2)

    for _, element in pairs(M.InputHandler.uiElements) do
        if element and element.Parent then
            element:Destroy()
        end
    end

    for _, sec_scrim in ipairs(M.InputHandler.secondary_scrims) do
        if sec_scrim and sec_scrim.Parent then
            pcall(function()
                sec_scrim:Destroy()
            end)
        end
    end

    M.InputHandler.onCompleteCallback = nil
    M.InputHandler.uiElements = {}
    M.InputHandler.secondary_scrims = {}
end

--- UI

local function create_prompt_ui(dOS, prompt_message)
    -- destroy any existing prompt
    if M.InputHandler.isActive then
        for _, element in pairs(M.InputHandler.uiElements) do
            if element and element.Parent then
                element:Destroy()
            end
        end

        for _, sec_scrim in ipairs(M.InputHandler.secondary_scrims) do
            if sec_scrim and sec_scrim.Parent then
                pcall(function()
                    sec_scrim:Destroy()
                end)
            end
        end

        M.InputHandler.uiElements = {}
        M.InputHandler.secondary_scrims = {}
    end

    local tween_info = dOS.TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    -- primary scrim
    local scrim = dOS.create_gui_element(dOS, "Frame", {
        Name = "InputScrim",
        Parent = dOS.screen,
        ZIndex = dOS.Z_INDEX.MSGBOX_OVERLAY,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = dOS.THEME.MSGBOX_OVERLAY_COLOR,
        BackgroundTransparency = 1,
    })

    -- secondary scrims
    if dOS.DWM then
        dOS.DWM.broadcast(dOS, function(ctx, proxy)
            if ctx.is_primary then
                return
            end

            local sec_scrim = dOS.create_gui_element(proxy, "Frame", {
                Name = "InputScrim_S" .. ctx.id,
                ZIndex = dOS.Z_INDEX.MSGBOX_OVERLAY,
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = dOS.THEME.MSGBOX_OVERLAY_COLOR,
                BackgroundTransparency = 1,
            })

            if sec_scrim then
                table.insert(M.InputHandler.secondary_scrims, sec_scrim)
                dOS.Tween.new(sec_scrim, { BackgroundTransparency = 0.55 }, tween_info):Play()
            end
        end)
    end

    -- dialog frame
    local prompt_width, prompt_height = 450, 160
    local final_pos = UDim2.fromScale(0.5, 0.5)
    local start_pos = UDim2.new(0.5, 0, 0.5, -20)

    local frame = dOS.create_gui_element(dOS, "Frame", {
        Name = "InputFrame",
        Parent = dOS.screen,
        ZIndex = dOS.Z_INDEX.MSGBOX,
        Size = UDim2.fromOffset(prompt_width, prompt_height),
        Position = start_pos,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = dOS.THEME.WINDOW_BG,
        BorderColor3 = dOS.THEME.BORDER_HIGHLIGHT,
        BackgroundTransparency = 1,
    })

    dOS.create_gui_element(dOS, "UICorner", {
        Parent = frame,
        CornerRadius = UDim.new(0, 12),
    })

    M.InputHandler.uiElements = { scrim = scrim, frame = frame }

    dOS.create_gui_element(dOS, "Frame", {
        Parent = frame,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = dOS.THEME.TITLE_BAR_BG,
        BorderColor3 = dOS.THEME.BORDER_HIGHLIGHT,
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = frame,
        Text = "Input Required",
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -20, 0, 30),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = frame,
        Text = prompt_message,
        Position = UDim2.new(0.5, 0, 0.5, -15),
        Size = UDim2.new(1, -20, 0, 40),
        AnchorPoint = Vector2.new(0.5, 0.5),
        TextSize = dOS.os_settings.global_font_size + 2,
        TextWrapped = true,
    })

    -- cancel button
    local cancelBtn = dOS.create_gui_element(dOS, "TextButton", {
        Name = "CancelButton",
        Parent = frame,
        Text = "Cancel",
        Size = UDim2.fromOffset(80, 25),
        Position = UDim2.new(1, -10, 1, -10),
        AnchorPoint = Vector2.new(1, 1),
        BackgroundColor3 = Color3.fromRGB(200, 50, 50),
        TextColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    })

    dOS.create_gui_element(dOS, "UICorner", {
        Parent = cancelBtn,
        CornerRadius = UDim.new(0, 4),
    })

    cancelBtn.MouseButton1Click:Connect(function()
        M.destroy_prompt_ui(dOS)
    end)

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = frame,
        Text = "Press Enter to submit.",
        Position = UDim2.new(0, 10, 1, -22),
        Size = UDim2.new(0.5, 0, 0, 20),
        AnchorPoint = Vector2.new(0, 0.5),
        TextColor3 = dOS.THEME.TEXT_DIM,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = dOS.os_settings.global_font_size - 2,
    })

    -- animate in
    local frame_anim = dOS.Tween.new(
        frame,
        { Position = final_pos, BackgroundTransparency = 0 },
        tween_info
    )
    local scrim_anim = dOS.Tween.new(
        scrim,
        { BackgroundTransparency = 0.5 },
        tween_info
    )

    table.insert(M.active_prompt_tweens, frame_anim)
    table.insert(M.active_prompt_tweens, scrim_anim)

    frame_anim:Play()
    scrim_anim:Play()
end

--- REQUEST

local function RequestInputAsync(dOS, prompt, onComplete)
    if M.InputHandler.isActive then
        print("dOS_WARN: Another input request is already active. Ignoring.")
        return
    end

    M.InputHandler.isActive = true
    M.InputHandler.onCompleteCallback = onComplete
    create_prompt_ui(dOS, prompt)
end

--- KEYBOARD

function M.BindKeyboardOnStart(dOS)
    if dOS.keyboard and dOS.keyboard ~= nil then
        pcall(function()
            dOS.keyboard.TextInputted:Disconnect()
        end)

        dOS.keyboard.TextInputted:Connect(function(text, player)
            if not M.InputHandler.isActive then
                return
            end

            M.InputHandler.last_input_username = player
            local callback = M.InputHandler.onCompleteCallback

            M.destroy_prompt_ui(dOS)

            if callback then
                local cleaned_text = text:sub(1, -2)
                task.spawn(function()
                    callback(cleaned_text)
                end)
            end
        end)
    end
end

--- WRAPPERS

function M.RequestStringAsync(dOS, prompt_msg, default_val, onComplete)
    RequestInputAsync(dOS, prompt_msg, function(input)
        if input == "" then
            onComplete(default_val)
        else
            onComplete(input)
        end
    end)
end

function M.RequestNumberAsync(dOS, prompt_msg, default_val, onComplete)
    M.RequestStringAsync(dOS, prompt_msg, default_val, function(str_val)
        local num = tonumber(str_val)
        if num ~= nil then
            onComplete(num)
        else
            onComplete(default_val)
        end
    end)
end

function M.RequestConfirmAsync(dOS, prompt_msg, default_val_bool, onComplete)
    local default_char = default_val_bool and "y" or "n"
    local y_n = (default_char == "y") and " (Y/n)" or " (y/N)"

    M.RequestStringAsync(dOS, prompt_msg .. y_n, default_char, function(str_val)
        local confirmed = str_val and str_val:lower():sub(1, 1) == "y"
        if not confirmed and str_val:sub(1, 1) == "" and default_char == "y" then
            confirmed = true
        end
        onComplete(confirmed)
    end)
end

return M

-- EOF