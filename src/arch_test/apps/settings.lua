--[[
    "Settings application for dOS"
    
    @module settings
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

-- All panels should be like that...
local DisplayPanel = require("./settings/panels/display_manager")

--- CONFIG

local ICONS = {
    Search = 15999597350,
    System = 3120635703,
    Personalization = 10910211661,
    Security = 17783082088,
    Debug = 71503984286896,
    Power = 13321880274,
    Display = 17550816694,
}

--- HELPERS

function M.save_settings(dOS, modified_settings)
    if not dOS.disk then return end

    local settings_json, err = JSONEncode(modified_settings)
    if settings_json then
        local success, write_err = pcall(
            dOS.disk.Write,
            dOS.disk,
            dOS.SETTINGS_DISK_FILE,
            settings_json
        )
        if success then
            print("[Settings] Data saved.")
        else
            warn(`[Settings] SAVE_ERROR: Disk Write failed. Error: '{write_err}'.`)
        end
    else
        warn(`[Settings] SAVE_ERROR: JSONEncode failed. Error: '{err}'.`)
    end
end

function M.load_settings(dOS)
    if not dOS.disk then return end

    local read_success, data = pcall(dOS.disk.Read, dOS.disk, dOS.SETTINGS_DISK_FILE)
    if read_success then
        local decode_success, decoded = pcall(JSONDecode, data)
        if decode_success and decoded then
            dOS.os_settings = decoded
            print("[Settings] Data loaded.")
        else
            warn(`[Settings] LOAD_ERROR: JSONDecode failed. Error: '{decoded}'.`)
        end
    else
        warn(`[Settings] LOAD_ERROR: Disk Read failed. Error: '{data}'`)
    end
end

local function define_setting(id, label, description, setting_type, config)
    return {
        id = id,
        label = label,
        desc = description,
        type = setting_type,
        config = config or {},
    }
end

--- API

function M.create(dOS, _)
    local window_frame, main_container = dOS.create_basic_window(
        dOS,
        "Settings",
        700,
        500,
        true,
        true,
        true,
        true,
        500,
        350
    )
    if not window_frame then return end

    -- application state
    local state = {
        current_page = "System",
        search_query = "",
        temp_settings = dOS.TableFuncs.deepcopy(dOS.os_settings),
        control_cache = {},
    }

    --- ANIM

    local function animate_in(element, delay)
        local tween_info = dOS.TweenInfo.new(
            0.5,
            Enum.EasingStyle.Quint,
            Enum.EasingDirection.Out,
            delay or 0
        )

        local final_pos = element.Position
        element.Position += UDim2.fromOffset(30, 10)

        local function apply_fade(obj, is_root)
            local goals = {}

            if is_root then
                goals.Position = final_pos
            end

            if obj:IsA("GuiObject") then
                goals.BackgroundTransparency = obj.BackgroundTransparency
                obj.BackgroundTransparency = 1
            end

            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                goals.TextTransparency = obj.TextTransparency
                obj.TextTransparency = 1
            end

            if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                goals.ImageTransparency = obj.ImageTransparency
                obj.ImageTransparency = 1
            end

            dOS.Tween.new(obj, goals, tween_info):Play()
        end

        apply_fade(element, true)
        for _, child in ipairs(element:GetDescendants()) do
            if child:IsA("GuiObject") then
                apply_fade(child, false)
            end
        end
    end

    local function animate_out(element, callback)
        local properties = { Position = element.Position + UDim2.fromOffset(20, 0) }

        properties.BackgroundTransparency = 1

        if element:IsA("ImageLabel") or element:IsA("ImageButton") then
            properties.ImageTransparency = 1
        end

        if element:IsA("TextLabel") or element:IsA("TextButton") or element:IsA("TextBox") then
            properties.TextTransparency = 1
        end

        local tween = dOS.Tween.new(
            element,
            properties,
            dOS.TweenInfo.new(
                0.3,
                Enum.EasingStyle.Quint,
                Enum.EasingDirection.In
            )
        )

        if callback then
            tween.OnComplete = callback
        end

        tween:Play()
    end

    --- LAYOUT

    local sidebar = dOS.create_gui_element(dOS, "Frame", {
        Parent = main_container,
        Size = UDim2.new(0, 220, 1, 0),
        BackgroundColor3 = dOS.THEME.CALC_DISPLAY_BG,
        BorderSizePixel = 0,
    })

    local selection_indicator = dOS.create_gui_element(dOS, "Frame", {
        Parent = sidebar,
        Size = UDim2.new(1, -20, 0, 40),
        Position = UDim2.fromOffset(10, -50),
        BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
        BorderSizePixel = 0,
        ZIndex = 1,
    })

    dOS.create_gui_element(dOS, "UICorner", {
        Parent = selection_indicator,
        CornerRadius = UDim.new(0, 6),
    })

    local active_tab_tween = nil

    local content_area = dOS.create_gui_element(dOS, "ScrollingFrame", {
        Parent = main_container,
        Size = UDim2.new(1, -220, 1, 0),
        Position = UDim2.fromOffset(220, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 6,
        CanvasSize = UDim2.new(0, 0, 0, 0),
    })

    local padding = dOS.create_gui_element(dOS, "UIPadding", {
        Parent = content_area,
        PaddingTop = UDim.new(0, 20),
        PaddingBottom = UDim.new(0, 20),
        PaddingLeft = UDim.new(0, 20),
        PaddingRight = UDim.new(0, 20),
    })

    local content_layout = dOS.create_gui_element(dOS, "UIListLayout", {
        Parent = content_area,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),
    })

    content_layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        content_area.CanvasSize = UDim2.fromOffset(
            0,
            content_layout.AbsoluteContentSize.Y
                + padding.PaddingTop.Offset
                + padding.PaddingBottom.Offset
        )
    end)

    local render_content

    --- PAGES

    local PAGES = {
        {
            id = "System",
            icon = ICONS.System,
            items = {
                define_setting(
                    "owner_username",
                    "Owner Name",
                    "The name displayed in system menus.",
                    "input"
                ),
                define_setting(
                    "global_text_scaled",
                    "Text Scaling",
                    "Automatically scale text to fit containers.",
                    "toggle"
                ),
                define_setting(
                    "global_font_size",
                    "Font Size",
                    "Base font size for the OS (Default: 14).",
                    "number",
                    { min = 8, max = 32 }
                ),
                define_setting(
                    "global_lerp_factor",
                    "Animation Speed",
                    "Window drag smoothness (0.1 - 1.0).",
                    "number",
                    { min = 0.1, max = 1.0 }
                ),
            },
        },
        {
            id = "Personalization",
            icon = ICONS.Personalization,
            items = {
                define_setting(
                    "desktop_bg_img_id",
                    "Desktop Wallpaper",
                    "Roblox Asset ID for the background.",
                    "number",
                    { min = 0, max = 10 ^ 15 }
                ),
                define_setting(
                    "transparentTB",
                    "Transparent Taskbar",
                    "Make the taskbar see-through.",
                    "toggle"
                ),
                define_setting(
                    "start_menu_height",
                    "Start Menu Height",
                    "Height of the start menu in pixels.",
                    "number",
                    { min = 300, max = 800 }
                ),
                define_setting(
                    "round_corners",
                    "Round Corners",
                    "Use round corners for most of the UI Elements.",
                    "toggle"
                ),
                define_setting(
                    "theme_selector",
                    "Theme & Appearance",
                    "Select a built-in or custom theme. Changes apply after reboot.",
                    "large_dropdown",
                    { is_theme_selector = true }
                ),
                define_setting(
                    "taskbar_position",
                    "Taskbar Position",
                    "Edge of the screen where the taskbar is docked. Requires reboot.",
                    "cycle_button",
                    { options = { "Bottom", "Top", "Left", "Right" } }
                ),
                define_setting(
                    "taskbar_hide_fullscreen",
                    "Auto-hide on Fullscreen",
                    "Hide the taskbar when a window is maximized.",
                    "toggle"
                ),
                define_setting(
                    "taskbar_large_tabs",
                    "Show App Titles in Taskbar",
                    "Display the application title next to the icon in each tab.",
                    "toggle"
                ),
                define_setting(
                    "taskbar_combine",
                    "Combine Taskbar Buttons",
                    "Controls when tabs are collapsed to icon-only mode.",
                    "cycle_button",
                    { options = { "Never", "When Full", "Always" } }
                ),
            },
        },
        {
            id = "Security",
            icon = ICONS.Security,
            items = {
                define_setting(
                    "lockscreen_bg_img_id",
                    "Lock Screen Background",
                    "Image ID for lock screen (0 = use desktop wallpaper).",
                    "number",
                    { min = 0, max = 10 ^ 15 }
                ),
                define_setting(
                    "lockscreen_scale_type",
                    "Background Scale Type",
                    "How the image fits the screen.",
                    "cycle_button",
                    { options = { "Crop", "Fit", "Stretch", "Tile" } }
                ),
                define_setting(
                    "password_auth",
                    "Password Authentication",
                    "Unlock with a keyboard password.",
                    "large_dropdown",
                    {
                        items = {
                            define_setting(
                                "set_password",
                                "Set Password",
                                "Configure or change your password.",
                                "action",
                                {
                                    callback = function()
                                        dOS.RequestStringAsync(
                                            dOS,
                                            "Enter new password:",
                                            "",
                                            function(password)
                                                if
                                                    password ~= ""
                                                    and (
                                                        not dOS.NotificationManager.update_p
                                                        or dOS.NotificationManager.update_p == 100
                                                    )
                                                then
                                                    if dOS.LockScreenManager then
                                                        dOS.NotificationManager.push(
                                                            dOS,
                                                            "Security",
                                                            "Configuring the new password...",
                                                            ICONS.Security,
                                                            dOS.NotificationManager.GENERIC_SFX.INFO_SYSTEM,
                                                            "progress_bar"
                                                        )

                                                        dOS.LockScreenManager.lockscreen_state.auth_data.keyboard_password_hash = dOS.Hasher.hash(
                                                            dOS,
                                                            password,
                                                            nil,
                                                            function(p)
                                                                dOS.NotificationManager.update_p = p
                                                            end
                                                        )

                                                        dOS.LockScreenManager.save_auth_data(dOS)
                                                        dOS.NotificationManager.push(
                                                            dOS,
                                                            "Security",
                                                            "Password set successfully",
                                                            ICONS.Security,
                                                            dOS.NotificationManager.GENERIC_SFX.INFO_SYSTEM
                                                        )
                                                    end
                                                end
                                            end
                                        )
                                    end,
                                    btn_text = function()
                                        return (
                                            dOS.LockScreenManager
                                            and dOS.LockScreenManager.lockscreen_state.auth_data.keyboard_password_hash
                                        ) and "Change" or "Set"
                                    end,
                                    color = Color3.fromRGB(0, 120, 215),
                                }
                            ),
                            define_setting(
                                "remove_password",
                                "Remove Password",
                                "Disable password authentication.",
                                "action",
                                {
                                    callback = function()
                                        if dOS.LockScreenManager then
                                            dOS.LockScreenManager.lockscreen_state.auth_data.keyboard_password_hash = nil
                                            dOS.LockScreenManager.save_auth_data(dOS)
                                            dOS.NotificationManager.push(
                                                dOS,
                                                "Security",
                                                "Password removed",
                                                ICONS.Security,
                                                dOS.NotificationManager.GENERIC_SFX.INFO_SYSTEM
                                            )
                                        end
                                    end,
                                    btn_text = "Remove",
                                    color = Color3.fromRGB(180, 50, 50),
                                    enabled_check = function()
                                        return dOS.LockScreenManager
                                            and dOS.LockScreenManager.lockscreen_state.auth_data.keyboard_password_hash ~= nil
                                    end,
                                }
                            ),
                        },
                    }
                ),
                define_setting(
                    "cursor_auth",
                    "CursorID™ Authentication",
                    "Unlock by hovering your registered cursor.",
                    "large_dropdown",
                    {
                        items = {
                            define_setting(
                                "scan_cursor",
                                "Scan Cursor",
                                "Register your cursor for biometric unlock.",
                                "action",
                                {
                                    callback = function(x, y)
                                        if
                                            not dOS.LockScreenManager
                                            or not dOS.LockScreenManager.lockscreen_state.auth_data.keyboard_password_hash
                                        then
                                            dOS.NotificationManager.push(
                                                dOS,
                                                "Security",
                                                "Could not scan cursor.\nAdd a keyboard passwd first.",
                                                dOS.NotificationManager.GENERIC_ICONS.ERROR,
                                                dOS.NotificationManager.GENERIC_SFX.ERROR
                                            )
                                            return
                                        end

                                        local cursor_object = nil
                                        for _, cursor in pairs(dOS.screen:GetCursors()) do
                                            if (Vector2.new(x, y) - Vector2.new(cursor.X, cursor.Y)).Magnitude < 5 then
                                                cursor_object = cursor
                                                break
                                            end
                                        end

                                        if not cursor_object then return end

                                        local encrypted_id = dOS.CHACHA.CHACHA_256(
                                            dOS.CHACHA.encrypt,
                                            dOS.SHA256.hash(
                                                dOS.LockScreenManager.lockscreen_state.auth_data.keyboard_password_hash
                                            ),
                                            tostring(cursor_object.UserId)
                                        )

                                        dOS.LockScreenManager.lockscreen_state.auth_data.cursor_id = encrypted_id
                                        dOS.LockScreenManager.save_auth_data(dOS)
                                        dOS.NotificationManager.push(
                                            dOS,
                                            "Security",
                                            `Successfully set CursorID™ unlock for player '{cursor_object.Player}'`,
                                            ICONS.Security,
                                            dOS.NotificationManager.GENERIC_SFX.INFO_SYSTEM
                                        )
                                    end,
                                    btn_text = function()
                                        return (
                                            dOS.LockScreenManager
                                            and dOS.LockScreenManager.lockscreen_state.auth_data.cursor_id
                                        ) and "Re-scan" or "Scan"
                                    end,
                                    color = Color3.fromRGB(100, 50, 200),
                                }
                            ),
                            define_setting(
                                "remove_cursor",
                                "Remove Cursor",
                                "Disable CursorID™ authentication.",
                                "action",
                                {
                                    callback = function()
                                        if dOS.LockScreenManager then
                                            dOS.LockScreenManager.lockscreen_state.auth_data.cursor_id = nil
                                            dOS.LockScreenManager.save_auth_data(dOS)
                                            dOS.NotificationManager.push(
                                                dOS,
                                                "Security",
                                                "Cursor removed",
                                                ICONS.Security,
                                                dOS.NotificationManager.GENERIC_SFX.INFO_SYSTEM
                                            )
                                        end
                                    end,
                                    btn_text = "Remove",
                                    color = Color3.fromRGB(180, 50, 50),
                                    enabled_check = function()
                                        return dOS.LockScreenManager
                                            and dOS.LockScreenManager.lockscreen_state.auth_data.cursor_id ~= nil
                                    end,
                                }
                            ),
                        },
                    }
                ),
                define_setting(
                    "disk_auth",
                    "Secret Disk Authentication",
                    "Unlock using an encrypted hardware key.",
                    "large_dropdown",
                    {
                        items = {
                            define_setting(
                                "setup_disk",
                                "Setup Disk",
                                "Create or change your secret disk key.",
                                "action",
                                {
                                    callback = function()
                                        if
                                            not dOS.LockScreenManager
                                            or not dOS.LockScreenManager.lockscreen_state.auth_data.keyboard_password_hash
                                        then
                                            dOS.NotificationManager.push(
                                                dOS,
                                                "Security",
                                                "Cannot set-up the disk.\nAdd a keyboard passwd first.",
                                                dOS.NotificationManager.GENERIC_ICONS.ERROR,
                                                dOS.NotificationManager.GENERIC_SFX.ERROR
                                            )
                                            return
                                        end

                                        local disks = dOS.HardwareManager.requestNewHardware(
                                            "Disk",
                                            true,
                                            true
                                        )

                                        if not disks then
                                            dOS.NotificationManager.push(
                                                dOS,
                                                "Error",
                                                "No disk detected",
                                                dOS.NotificationManager.GENERIC_ICONS.ERROR,
                                                dOS.NotificationManager.GENERIC_SFX.ERROR
                                            )
                                            return
                                        end

                                        dOS.OpenFileDialog({
                                            mode = "open",
                                            type = "folder",
                                            callback = function(selection)
                                                local disk_id = selection.disk_id
                                                if not disk_id or selection.path_on_disk then
                                                    dOS.NotificationManager.push(
                                                        dOS,
                                                        "Error",
                                                        "Invalid disk.",
                                                        dOS.NotificationManager.GENERIC_ICONS.ERROR,
                                                        dOS.NotificationManager.GENERIC_SFX.ERROR
                                                    )
                                                    return
                                                end

                                                local disk_ref
                                                for _, disk in disks do
                                                    if disk.id == disk_id then
                                                        disk_ref = disk.obj
                                                    end
                                                end

                                                if not disk_ref then
                                                    dOS.NotificationManager.push(
                                                        dOS,
                                                        "Error",
                                                        "Disk not found.",
                                                        dOS.NotificationManager.GENERIC_ICONS.ERROR,
                                                        dOS.NotificationManager.GENERIC_SFX.ERROR
                                                    )
                                                    return
                                                end

                                                if disk_ref.GUID == dOS.disk.GUID then
                                                    dOS.MessageBox.error(
                                                        dOS,
                                                        "Access Denied",
                                                        "Cannot open from system disk."
                                                    )
                                                    return
                                                end

                                                local function generate_secret_key()
                                                    local chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!@#$%^&*()"
                                                    local key = ""
                                                    for _ = 1, 300 do
                                                        key ..= chars:sub(
                                                            math.random(1, #chars),
                                                            math.random(1, #chars)
                                                        )
                                                    end
                                                    return key
                                                end

                                                local secret_key = `{generate_secret_key()}|{dOS.SHA256.hash(disk_ref.GUID)}`
                                                local encrypted_key = dOS.CHACHA.CHACHA_256(
                                                    dOS.CHACHA.encrypt,
                                                    dOS.SHA256.hash(
                                                        dOS.LockScreenManager.lockscreen_state.auth_data.keyboard_password_hash
                                                    ),
                                                    secret_key
                                                )
                                                local disk_path = "$dOS_secret_key.bin"
                                                local success = pcall(
                                                    disk_ref.Write,
                                                    disk_ref,
                                                    disk_path,
                                                    encrypted_key
                                                )

                                                if success and dOS.LockScreenManager then
                                                    dOS.LockScreenManager.lockscreen_state.auth_data.disk_secret_key = secret_key
                                                    dOS.LockScreenManager.lockscreen_state.auth_data.disk_device_path = disk_path
                                                    dOS.LockScreenManager.save_auth_data(dOS)
                                                    dOS.NotificationManager.push(
                                                        dOS,
                                                        "Security",
                                                        "Secret disk created",
                                                        ICONS.Security,
                                                        dOS.NotificationManager.GENERIC_SFX.INFO_SYSTEM
                                                    )
                                                else
                                                    dOS.NotificationManager.push(
                                                        dOS,
                                                        "Error",
                                                        "Failed to write disk",
                                                        dOS.NotificationManager.GENERIC_ICONS.ERROR,
                                                        dOS.NotificationManager.GENERIC_SFX.ERROR
                                                    )
                                                end
                                            end,
                                        })

                                        for _, disk in ipairs(disks) do
                                            dOS.HardwareManager.freeHardware(disk)
                                        end
                                    end,
                                    btn_text = function()
                                        return (
                                            dOS.LockScreenManager
                                            and dOS.LockScreenManager.lockscreen_state.auth_data.disk_secret_key
                                        ) and "Change" or "Setup"
                                    end,
                                    color = Color3.fromRGB(200, 100, 0),
                                }
                            ),
                            define_setting(
                                "remove_disk",
                                "Remove Disk",
                                "Disable secret disk authentication.",
                                "action",
                                {
                                    callback = function()
                                        if dOS.LockScreenManager then
                                            dOS.LockScreenManager.lockscreen_state.auth_data.disk_secret_key = nil
                                            dOS.LockScreenManager.lockscreen_state.auth_data.disk_device_path = nil
                                            dOS.LockScreenManager.save_auth_data(dOS)
                                            dOS.NotificationManager.push(
                                                dOS,
                                                "Security",
                                                "Secret disk removed",
                                                ICONS.Security,
                                                dOS.NotificationManager.GENERIC_SFX.INFO_SYSTEM
                                            )
                                        end
                                    end,
                                    btn_text = "Remove",
                                    color = Color3.fromRGB(180, 50, 50),
                                    enabled_check = function()
                                        return dOS.LockScreenManager
                                            and dOS.LockScreenManager.lockscreen_state.auth_data.disk_secret_key ~= nil
                                    end,
                                }
                            ),
                        },
                    }
                ),
                define_setting(
                    "test_lockscreen",
                    "Test Lock Screen",
                    "Try out your configured lock screen.",
                    "action",
                    {
                        callback = function()
                            if dOS.LockScreenManager then
                                dOS.LockScreenManager.show_lock_screen(dOS)
                            else
                                dOS.NotificationManager.push(
                                    dOS,
                                    "Error",
                                    "LockScreen not initialized",
                                    dOS.NotificationManager.GENERIC_ICONS.ERROR,
                                    dOS.NotificationManager.GENERIC_SFX.ERROR
                                )
                            end
                        end,
                        btn_text = "Lock Now",
                        color = Color3.fromRGB(58, 134, 255),
                    }
                ),
            },
        },
        {
            id = "Display",
            icon = ICONS.Display,
            items = {
                define_setting(
                    "display_arrangement",
                    "Arrange Displays",
                    "Drag screens left/right or top/bottom to set their order. Right-click a screen to make it primary.",
                    "large_dropdown",
                    { is_display_manager = true }
                ),
            },
        },
        {
            id = "Debug",
            icon = ICONS.Debug,
            items = {
                define_setting(
                    "show_capture_overlay",
                    "Show Capture Overlay",
                    "Shows the Capture Frame whenever you drag a Window or a Slider.",
                    "toggle"
                ),
            },
        },
        {
            id = "Power & Reset",
            icon = ICONS.Power,
            items = {
                define_setting(
                    "save_reboot",
                    "Save & Reboot",
                    "Apply changes and restart dOS.",
                    "action",
                    {
                        callback = function()
                            M.save_settings(dOS, state.temp_settings)
                            dOS.rebootOS()
                        end,
                        btn_text = "Restart",
                        color = dOS.THEME.ACCENT_BUTTON_BG,
                    }
                ),
                define_setting(
                    "factory_reset",
                    "Factory Reset",
                    "Wipe all data and Poweroff",
                    "action",
                    {
                        callback = function()
                            dOS.RequestConfirmAsync(
                                dOS,
                                "WIPE ALL DATA? This cannot be undone.",
                                false,
                                function(yes)
                                    if yes then
                                        dOS.RequestStringAsync(
                                            dOS,
                                            "Type 'Reset all my data.' to continue.",
                                            "",
                                            function(text)
                                                if text == "Reset all my data." then
                                                    dOS.shared.SETTINGS_reset_canceled = false

                                                    dOS.MessageBox.info(
                                                        dOS,
                                                        "FACTORY RESET",
                                                        "Wiping in 5 seconds...",
                                                        {
                                                            {
                                                                text = "CANCEL",
                                                                callback = function()
                                                                    dOS.shared.SETTINGS_reset_canceled = true
                                                                end,
                                                            },
                                                        },
                                                        true
                                                    )

                                                    task.wait(5)

                                                    if not dOS.shared.SETTINGS_reset_canceled then
                                                        dOS.disk:Clear()
                                                        Microcontroller:Shutdown()
                                                    end
                                                    dOS.shared.SETTINGS_reset_canceled = nil
                                                end

                                                dOS.NotificationManager.push(
                                                    dOS,
                                                    "Operation canceled",
                                                    "Your data is safe.",
                                                    dOS.NotificationManager.GENERIC_ICONS.SUCCESS,
                                                    dOS.NotificationManager.GENERIC_SFX.SUCCESS
                                                )
                                            end
                                        )
                                    else
                                        dOS.NotificationManager.push(
                                            dOS,
                                            "Operation canceled",
                                            "Your data is safe.",
                                            dOS.NotificationManager.GENERIC_ICONS.SUCCESS,
                                            dOS.NotificationManager.GENERIC_SFX.SUCCESS
                                        )
                                    end
                                end
                            )
                        end,
                        btn_text = "Reset",
                        color = Color3.fromRGB(200, 50, 50),
                    }
                ),
            },
        },
    }

    --- RENDERING

    local function create_control(item, control_area, is_sub_item)
        local control_id = item.id
        local size_config = is_sub_item
            and {
                width = UDim2.new(0.9, 0, 0, 32),
                anchor = Vector2.new(1, 0.5),
                pos = UDim2.new(1, -10, 0.5, 0),
            }
            or {
                width = UDim2.new(0.9, -15, 0, 30),
                anchor = Vector2.new(1, 0.5),
                pos = UDim2.new(1, -15, 0.5, 0),
            }

        if item.type == "toggle" then
            local is_on = state.temp_settings[item.id]
            local btn

            btn = dOS.create_gui_element(dOS, "TextButton", {
                Parent = control_area,
                Text = is_on and "On" or "Off",
                Size = size_config.width,
                AnchorPoint = size_config.anchor,
                Position = size_config.pos,
                BackgroundColor3 = is_on and dOS.THEME.ACCENT_BUTTON_BG or dOS.THEME.CALC_BUTTON_BG,
                OnClick = function()
                    state.temp_settings[item.id] = not state.temp_settings[item.id]
                    btn.Text = state.temp_settings[item.id] and "On" or "Off"
                    btn.BackgroundColor3 = state.temp_settings[item.id]
                        and dOS.THEME.ACCENT_BUTTON_BG
                        or dOS.THEME.CALC_BUTTON_BG
                end,
            })

            dOS.create_gui_element(dOS, "UICorner", {
                Parent = btn,
                CornerRadius = UDim.new(0, 4),
            })

            state.control_cache[control_id] = btn
            return btn
        elseif item.type == "input" or item.type == "number" then
            local value = state.temp_settings[item.id]
            local btn

            btn = dOS.create_gui_element(dOS, "TextButton", {
                Parent = control_area,
                Text = (item.type == "number") and value or tostring(value),
                TextColor3 = Color3.fromRGB(255, 255, 255),
                Size = size_config.width,
                AnchorPoint = size_config.anchor,
                Position = size_config.pos,
                BackgroundColor3 = dOS.THEME.TEXT_BOX_DARK,
                AutoButtonColor = true,
                OnClick = function()
                    if item.type == "number" then
                        dOS.RequestNumberAsync(
                            dOS,
                            "Set " .. item.label,
                            value,
                            function(n)
                                if n then
                                    if item.config.min then
                                        n = math.max(item.config.min, n)
                                    end
                                    if item.config.max then
                                        n = math.min(item.config.max, n)
                                    end
                                    state.temp_settings[item.id] = n
                                    btn.Text = n -- pass number directly; no text filter
                                end
                            end
                        )
                    else
                        dOS.RequestStringAsync(
                            dOS,
                            "Set " .. item.label,
                            tostring(value),
                            function(s)
                                if s then
                                    state.temp_settings[item.id] = s
                                    btn.Text = s
                                end
                            end
                        )
                    end
                end,
            })

            dOS.create_gui_element(dOS, "UICorner", {
                Parent = btn,
                CornerRadius = UDim.new(0, 4),
            })

            state.control_cache[control_id] = btn
            return btn
        elseif item.type == "action" then
            local button_text = type(item.config.btn_text) == "function"
                and item.config.btn_text()
                or item.config.btn_text
            local is_enabled = not item.config.enabled_check or item.config.enabled_check()

            local btn
            btn = dOS.create_gui_element(dOS, "TextButton", {
                Parent = control_area,
                Text = button_text,
                Size = is_sub_item and size_config.width or UDim2.new(0.8, 0, 0, 35),
                AnchorPoint = size_config.anchor,
                Position = is_sub_item and size_config.pos or UDim2.new(1, -15, 0.5, 0),
                BackgroundColor3 = is_enabled
                    and (item.config.color or dOS.THEME.ACCENT_BUTTON_BG)
                    or dOS.THEME.CALC_BUTTON_BG,
                TextColor3 = is_enabled and Color3.fromRGB(255, 255, 255) or dOS.THEME.TEXT_DIM,
            })

            if is_enabled then
                btn.MouseButton1Down:Connect(item.config.callback)
            end

            dOS.create_gui_element(dOS, "UICorner", {
                Parent = btn,
                CornerRadius = UDim.new(0, 4),
            })

            state.control_cache[control_id] = btn
            return btn
        elseif item.type == "cycle_button" then
            local options = item.config.options or {}
            local current_value = state.temp_settings[item.id]

            if not current_value or type(current_value) ~= "string" then
                current_value = options[1] or "None"
                state.temp_settings[item.id] = current_value
            end

            local btn
            btn = dOS.create_gui_element(dOS, "TextButton", {
                Parent = control_area,
                Text = current_value,
                Size = size_config.width,
                AnchorPoint = size_config.anchor,
                Position = size_config.pos,
                BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
                TextXAlignment = Enum.TextXAlignment.Center,
                OnClick = function()
                    local index = table.find(options, current_value) or 1
                    index = (index % #options) + 1
                    current_value = options[index]
                    state.temp_settings[item.id] = current_value
                    btn.Text = current_value
                    if item.config.on_change then
                        pcall(item.config.on_change, current_value)
                    end
                end,
            })

            dOS.create_gui_element(dOS, "UICorner", {
                Parent = btn,
                CornerRadius = UDim.new(0, 4),
            })

            state.control_cache[control_id] = btn
            return btn
        else
            warn(`[Setting->create_control]: Unknown type '{item.type}'.`)
            dOS.MessageBox.error("Settings", `Unknown type '{item.type}'.`)
            return nil
        end
    end

    --- THEME

    -- built-in theme display names and preview palettes
    local THEME_NAMES = { "Purple", "Blue", "GrayBlue", "Green" }
    local THEME_PALETTES = {
        Purple = {
            bg = Color3.fromRGB(65, 45, 100),
            bar = Color3.fromRGB(75, 50, 115),
            accent = Color3.fromRGB(133, 89, 188),
            btn = Color3.fromRGB(120, 80, 170),
            txt = Color3.fromRGB(230, 220, 250),
        },
        Blue = {
            bg = Color3.fromRGB(45, 55, 72),
            bar = Color3.fromRGB(52, 65, 85),
            accent = Color3.fromRGB(110, 160, 210),
            btn = Color3.fromRGB(70, 105, 150),
            txt = Color3.fromRGB(225, 232, 240),
        },
        GrayBlue = {
            bg = Color3.fromRGB(42, 46, 54),
            bar = Color3.fromRGB(48, 52, 60),
            accent = Color3.fromRGB(104, 140, 175),
            btn = Color3.fromRGB(75, 100, 130),
            txt = Color3.fromRGB(235, 240, 245),
        },
        Green = {
            bg = Color3.fromRGB(38, 44, 41),
            bar = Color3.fromRGB(45, 52, 48),
            accent = Color3.fromRGB(110, 190, 155),
            btn = Color3.fromRGB(76, 130, 110),
            txt = Color3.fromRGB(230, 245, 235),
        },
    }

    local function serialize_palette(palette)
        local serialized = {}
        for key, value in pairs(palette) do
            if typeof(value) == "Color3" then
                serialized[key] = {
                    r = math.round(value.R * 255),
                    g = math.round(value.G * 255),
                    b = math.round(value.B * 255),
                }
            else
                serialized[key] = value
            end
        end
        return serialized
    end

    local function deserialize_palette(serialized)
        if not serialized then return {} end
        local palette = {}
        for key, value in pairs(serialized) do
            if type(value) == "table" and value.r ~= nil then
                palette[key] = Color3.fromRGB(value.r, value.g, value.b)
            else
                palette[key] = value
            end
        end
        return palette
    end

    local custom_themes_list = {}
    if state.temp_settings.custom_themes then
        custom_themes_list = state.temp_settings.custom_themes
    else
        state.temp_settings.custom_themes = custom_themes_list
    end

    --- DISPLAY

    --- PREVIEW

    local function apply_preview_palette(elements, palette)
        if not palette or not elements then return end

        local tween_info = dOS.TweenInfo.new(
            0.35,
            Enum.EasingStyle.Quint,
            Enum.EasingDirection.Out
        )

        if elements.desktop then
            dOS.Tween.new(
                elements.desktop,
                { BackgroundColor3 = palette.bg },
                tween_info
            ):Play()
        end

        if elements.titlebar then
            dOS.Tween.new(
                elements.titlebar,
                { BackgroundColor3 = palette.bar },
                tween_info
            ):Play()
        end

        if elements.taskbar then
            dOS.Tween.new(
                elements.taskbar,
                { BackgroundColor3 = palette.bar },
                tween_info
            ):Play()
        end

        if elements.window then
            dOS.Tween.new(
                elements.window,
                {
                    BackgroundColor3 = palette.bg:Lerp(
                        Color3.fromRGB(255, 255, 255),
                        0.07
                    ),
                },
                tween_info
            ):Play()
        end

        if elements.accent1 then
            dOS.Tween.new(
                elements.accent1,
                { BackgroundColor3 = palette.accent },
                tween_info
            ):Play()
        end

        if elements.btn1 then
            dOS.Tween.new(
                elements.btn1,
                { BackgroundColor3 = palette.btn },
                tween_info
            ):Play()
        end

        if elements.btn2 then
            dOS.Tween.new(
                elements.btn2,
                { BackgroundColor3 = palette.btn },
                tween_info
            ):Play()
        end

        if elements.txt1 then
            dOS.Tween.new(
                elements.txt1,
                { TextColor3 = palette.txt },
                tween_info
            ):Play()
        end

        if elements.txt2 then
            dOS.Tween.new(
                elements.txt2,
                {
                    TextColor3 = palette.txt:Lerp(
                        Color3.fromRGB(100, 100, 100),
                        0.35
                    ),
                },
                tween_info
            ):Play()
        end
    end

    local function build_theme_preview(parent)
        local elements = {}

        local desktop = dOS.create_gui_element(dOS, "Frame", {
            Parent = parent,
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = dOS.THEME.WINDOW_BG,
            BorderSizePixel = 0,
        })
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = desktop,
            CornerRadius = UDim.new(0, 6),
        })
        elements.desktop = desktop

        local taskbar = dOS.create_gui_element(dOS, "Frame", {
            Parent = desktop,
            Size = UDim2.new(1, 0, 0, 14),
            Position = UDim2.new(0, 0, 1, -14),
            BackgroundColor3 = dOS.THEME.TITLE_BAR_BG,
            BorderSizePixel = 0,
        })
        elements.taskbar = taskbar

        local start_dot = dOS.create_gui_element(dOS, "Frame", {
            Parent = taskbar,
            Size = UDim2.fromOffset(8, 8),
            Position = UDim2.new(0, 3, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = dOS.THEME.ACCENT,
            BorderSizePixel = 0,
        })
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = start_dot,
            CornerRadius = UDim.new(0.5, 0),
        })
        elements.accent1 = start_dot

        local window = dOS.create_gui_element(dOS, "Frame", {
            Parent = desktop,
            Size = UDim2.fromScale(0.65, 0.72),
            Position = UDim2.fromOffset(8, 8),
            BackgroundColor3 = dOS.THEME.WINDOW_BG,
            BorderSizePixel = 0,
        })
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = window,
            CornerRadius = UDim.new(0, 4),
        })
        elements.window = window

        local titlebar = dOS.create_gui_element(dOS, "Frame", {
            Parent = window,
            Size = UDim2.new(1, 0, 0, 12),
            BackgroundColor3 = dOS.THEME.TITLE_BAR_BG,
            BorderSizePixel = 0,
        })
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = titlebar,
            CornerRadius = UDim.new(0, 4),
        })
        elements.titlebar = titlebar

        elements.txt1 = dOS.create_gui_element(dOS, "TextLabel", {
            Parent = titlebar,
            Text = "Settings",
            Size = UDim2.new(1, -10, 1, 0),
            Position = UDim2.fromOffset(5, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = dOS.THEME.TEXT_LIGHT,
            BackgroundTransparency = 1,
            TextSize = 7,
            Font = dOS.FONT_BOLD,
        })

        elements.btn1 = dOS.create_gui_element(dOS, "Frame", {
            Parent = window,
            Size = UDim2.new(0.42, 0, 0, 10),
            Position = UDim2.fromOffset(5, 18),
            BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
            BorderSizePixel = 0,
        })
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = elements.btn1,
            CornerRadius = UDim.new(0, 3),
        })

        elements.btn2 = dOS.create_gui_element(dOS, "Frame", {
            Parent = window,
            Size = UDim2.new(0.42, 0, 0, 10),
            Position = UDim2.fromOffset(5, 32),
            BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
            BorderSizePixel = 0,
        })
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = elements.btn2,
            CornerRadius = UDim.new(0, 3),
        })

        elements.txt2 = dOS.create_gui_element(dOS, "TextLabel", {
            Parent = window,
            Text = "dOS Theme Preview",
            Size = UDim2.new(1, -10, 0, 10),
            Position = UDim2.fromOffset(5, 48),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = dOS.THEME.TEXT_DIM,
            BackgroundTransparency = 1,
            TextSize = 6,
        })

        return elements
    end

    --- EDITOR

    local COLOR_GROUPS = {
        {
            name = "Backgrounds",
            keys = {
                {
                    key = "DESKTOP_BG",
                    label = "Desktop Background",
                    hint = "Main desktop background color",
                },
                {
                    key = "TASKBAR_BG",
                    label = "Taskbar Background",
                    hint = "Bottom bar background",
                },
                {
                    key = "WINDOW_BG",
                    label = "Window Background",
                    hint = "Main window content area",
                },
                {
                    key = "TITLE_BAR_BG",
                    label = "Title Bar",
                    hint = "Window title bar background",
                },
            },
        },
        {
            name = "Buttons & Accents",
            keys = {
                {
                    key = "ACCENT_BUTTON_BG",
                    label = "Accent Button",
                    hint = "Primary action buttons",
                },
                {
                    key = "ACCENT_BUTTON_HOVER",
                    label = "Accent Button Hover",
                    hint = "Hover state",
                },
                {
                    key = "ACCENT",
                    label = "Accent Color",
                    hint = "General accent / glow",
                },
                {
                    key = "BORDER_HIGHLIGHT",
                    label = "Border Highlight",
                    hint = "Active border color",
                },
                {
                    key = "BORDER_DARK",
                    label = "Border Dark",
                    hint = "Subtle border color",
                },
            },
        },
        {
            name = "Text & Input",
            keys = {
                {
                    key = "TEXT_LIGHT",
                    label = "Primary Text",
                    hint = "Main readable text",
                },
                {
                    key = "TEXT_DARK",
                    label = "Dark Text",
                    hint = "Text on light surfaces",
                },
                {
                    key = "TEXT_DIM",
                    label = "Dimmed Text",
                    hint = "Secondary / hint text",
                },
                {
                    key = "TEXT_BOX_DARK",
                    label = "Input Background",
                    hint = "Text field background",
                },
                {
                    key = "TEXT_BOX_LIGHT",
                    label = "Input Foreground",
                    hint = "Text field text color",
                },
            },
        },
        {
            name = "Start Menu",
            keys = {
                {
                    key = "START_MENU_BG",
                    label = "Background",
                    hint = "Outer start menu frame",
                },
                {
                    key = "START_MENU_CONTENT_BG",
                    label = "Content BG",
                    hint = "Inner content area",
                },
                {
                    key = "START_MENU_TILE_BG",
                    label = "Tile BG",
                    hint = "App tile default color",
                },
                {
                    key = "START_MENU_TILE_HOVER",
                    label = "Tile Hover",
                    hint = "App tile hover color",
                },
                {
                    key = "START_BUTTON_BG",
                    label = "Start Button",
                    hint = "Start button color",
                },
                {
                    key = "START_BUTTON_HOVER",
                    label = "Start Btn Hover",
                    hint = "Start button hover",
                },
                {
                    key = "START_MENU_BOTTOM_BAR",
                    label = "Bottom Bar",
                    hint = "Bottom bar of start menu",
                },
            },
        },
        {
            name = "Calculator",
            keys = {
                {
                    key = "CALC_DISPLAY_BG",
                    label = "Display BG",
                    hint = "Calculator display area",
                },
                {
                    key = "CALC_BUTTON_BG",
                    label = "Button BG",
                    hint = "Number buttons",
                },
                {
                    key = "CALC_BUTTON_HOVER",
                    label = "Button Hover",
                    hint = "Button hover state",
                },
                {
                    key = "CALC_OP_BUTTON_BG",
                    label = "Operator Button",
                    hint = "Operator buttons",
                },
                {
                    key = "CALC_OP_BUTTON_HOVER",
                    label = "Operator Hover",
                    hint = "Operator button hover",
                },
            },
        },
        {
            name = "Lock Screen",
            keys = {
                {
                    key = "LOCKSCREEN_BG",
                    label = "Background",
                    hint = "Lock screen background",
                },
                {
                    key = "LOCKSCREEN_OVERLAY",
                    label = "Overlay",
                    hint = "Dark overlay on wallpaper",
                },
                {
                    key = "LOCKSCREEN_CARD_BG",
                    label = "Card BG",
                    hint = "Login card background",
                },
                {
                    key = "LOCKSCREEN_CARD_BORDER",
                    label = "Card Border",
                    hint = "Login card border",
                },
                {
                    key = "LOCKSCREEN_INPUT_BG",
                    label = "Input BG",
                    hint = "Password field background",
                },
                {
                    key = "LOCKSCREEN_BUTTON_PRIMARY",
                    label = "Primary Button",
                    hint = "Main action button",
                },
                {
                    key = "LOCKSCREEN_BUTTON_SECONDARY",
                    label = "Secondary Button",
                    hint = "Cancel / back button",
                },
                {
                    key = "LOCKSCREEN_SUCCESS",
                    label = "Success",
                    hint = "Unlock success indicator",
                },
                {
                    key = "LOCKSCREEN_ERROR",
                    label = "Error",
                    hint = "Wrong password indicator",
                },
                {
                    key = "LOCKSCREEN_ACCENT",
                    label = "Accent",
                    hint = "Lock screen accent glow",
                },
                {
                    key = "LOCKSCREEN_WAIT_TEXT_BG",
                    label = "Wait Text BG",
                    hint = "Waiting pill background",
                },
            },
        },
        {
            name = "Explorer & Other",
            keys = {
                {
                    key = "EXPLORER_NAV_BTN",
                    label = "Nav Button",
                    hint = "Navigation buttons",
                },
                {
                    key = "EXPLORER_NAV_BTN_SELECTED",
                    label = "Nav Selected",
                    hint = "Selected nav button",
                },
                {
                    key = "EXPLORER_NAV_BTN_BORDER",
                    label = "Nav Border",
                    hint = "Nav button border",
                },
                {
                    key = "SETTINGS_LABEL_BG",
                    label = "Settings Label",
                    hint = "Settings section header",
                },
                {
                    key = "MSGBOX_OVERLAY_COLOR",
                    label = "Dialog Overlay",
                    hint = "Dark overlay behind dialog",
                },
                {
                    key = "MSGBOX_BG",
                    label = "Dialog BG",
                    hint = "Message dialog background",
                },
            },
        },
    }

    local function open_custom_theme_editor(edit_name, edit_palette_serialized)
        local pages = {}
        for _, group in ipairs(COLOR_GROUPS) do
            for _, entry in ipairs(group.keys) do
                table.insert(pages, { type = "pick", group = group, entry = entry })
            end
            table.insert(pages, { type = "viz", group = group })
        end
        table.insert(pages, { type = "save" })

        local edit_palette = {}
        if edit_palette_serialized then
            edit_palette = deserialize_palette(edit_palette_serialized)
        else
            for key, value in pairs(dOS.THEME) do
                edit_palette[key] = value
            end
        end

        -- count existing themes to suggest a name
        local existing_count = 0
        for _ in pairs(custom_themes_list) do
            existing_count += 1
        end
        local theme_name = edit_name or ("Custom " .. tostring(existing_count + 1))

        local editor_win, editor_container = dOS.create_basic_window(
            dOS,
            "Theme Editor",
            540,
            460,
            true,
            true,
            true,
            true,
            460,
            360
        )
        if not editor_win then return end

        -- header
        local header = dOS.create_gui_element(dOS, "Frame", {
            Parent = editor_container,
            Size = UDim2.new(1, 0, 0, 42),
            BackgroundColor3 = dOS.THEME.TITLE_BAR_BG,
            BorderSizePixel = 0,
        })

        local group_label = dOS.create_gui_element(dOS, "TextLabel", {
            Parent = header,
            Text = "",
            Size = UDim2.new(1, -80, 1, 0),
            Position = UDim2.fromOffset(10, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = dOS.THEME.TEXT_LIGHT,
            Font = dOS.FONT_BOLD,
            TextSize = 13,
            BackgroundTransparency = 1,
        })

        local page_counter = dOS.create_gui_element(dOS, "TextLabel", {
            Parent = header,
            Text = "",
            Size = UDim2.new(0, 65, 1, 0),
            Position = UDim2.new(1, -72, 0, 0),
            TextColor3 = dOS.THEME.TEXT_DIM,
            BackgroundTransparency = 1,
            TextSize = 11,
        })

        local progress_bg = dOS.create_gui_element(dOS, "Frame", {
            Parent = header,
            Size = UDim2.new(1, 0, 0, 3),
            Position = UDim2.new(0, 0, 1, -3),
            BackgroundColor3 = dOS.THEME.BORDER_DARK,
            BorderSizePixel = 0,
        })

        local progress_fill = dOS.create_gui_element(dOS, "Frame", {
            Parent = progress_bg,
            Size = UDim2.fromScale(0, 1),
            BackgroundColor3 = dOS.THEME.ACCENT,
            BorderSizePixel = 0,
        })

        -- page area
        local page_area = dOS.create_gui_element(dOS, "Frame", {
            Parent = editor_container,
            Size = UDim2.new(1, 0, 1, -86),
            Position = UDim2.fromOffset(0, 42),
            BackgroundTransparency = 1,
            ClipsDescendants = true,
        })

        -- bottom nav bar
        local nav_bar = dOS.create_gui_element(dOS, "Frame", {
            Parent = editor_container,
            Size = UDim2.new(1, 0, 0, 44),
            Position = UDim2.new(0, 0, 1, -44),
            BackgroundColor3 = dOS.THEME.CALC_DISPLAY_BG,
            BorderSizePixel = 0,
        })

        local nav_back_btn = dOS.create_gui_element(dOS, "TextButton", {
            Parent = nav_bar,
            Text = "← Back",
            Size = UDim2.fromOffset(80, 28),
            Position = UDim2.fromOffset(10, 8),
            BackgroundColor3 = dOS.THEME.CALC_BUTTON_BG,
            TextColor3 = dOS.THEME.TEXT_LIGHT,
            TextSize = 12,
        })
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = nav_back_btn,
            CornerRadius = UDim.new(0, 5),
        })

        local nav_hint = dOS.create_gui_element(dOS, "TextLabel", {
            Parent = nav_bar,
            Text = "Set a color to advance ->",
            Size = UDim2.new(1, -100, 1, 0),
            Position = UDim2.fromOffset(96, 0),
            TextColor3 = dOS.THEME.TEXT_DIM,
            BackgroundTransparency = 1,
            TextSize = 11,
        })

        -- navigation
        local current_idx = 1
        local current_page_frame = nil
        local show_page

        local function update_header(index)
            local page_info = pages[index]
            if page_info.type == "pick" then
                group_label.Text = page_info.group.name .. "  -  " .. page_info.entry.label
                nav_hint.Text = "Drag slider, then 'Set Color ->'"
            elseif page_info.type == "viz" then
                group_label.Text = page_info.group.name .. "  -  Preview"
                nav_hint.Text = "← Back to redo   |   Continue ->"
            else
                group_label.Text = "Save Your Theme"
                nav_hint.Text = "← Back to rename"
            end

            page_counter.Text = index .. " / " .. #pages

            dOS.Tween.new(
                progress_fill,
                { Size = UDim2.fromScale(index / #pages, 1) },
                dOS.TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            ):Play()
        end

        -- color picker page
        local function make_pick_page(entry)
            local existing = edit_palette[entry.key]
            local current_color = (typeof(existing) == "Color3") and existing or Color3.fromRGB(100, 100, 100)
            local red = math.round(current_color.R * 255)
            local green = math.round(current_color.G * 255)
            local blue = math.round(current_color.B * 255)

            local page = dOS.create_gui_element(dOS, "Frame", {
                Parent = page_area,
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
            })
            dOS.create_gui_element(dOS, "UIPadding", {
                Parent = page,
                PaddingLeft = UDim.new(0, 14),
                PaddingRight = UDim.new(0, 14),
                PaddingTop = UDim.new(0, 12),
            })

            -- color swatch
            local swatch = dOS.create_gui_element(dOS, "Frame", {
                Parent = page,
                Size = UDim2.fromOffset(88, 88),
                Position = UDim2.fromOffset(0, 0),
                BackgroundColor3 = current_color,
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = swatch,
                CornerRadius = UDim.new(0, 8),
            })

            local hex_label = dOS.create_gui_element(dOS, "TextLabel", {
                Parent = page,
                Text = string.format("#%02X%02X%02X", red, green, blue),
                Size = UDim2.fromOffset(88, 18),
                Position = UDim2.fromOffset(0, 92),
                TextColor3 = dOS.THEME.TEXT_DIM,
                BackgroundTransparency = 1,
                TextSize = 11,
            })

            -- labels top right of swatch
            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = page,
                Text = entry.label,
                Size = UDim2.new(1, -102, 0, 24),
                Position = UDim2.fromOffset(102, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                Font = dOS.FONT_BOLD,
                TextColor3 = dOS.THEME.TEXT_LIGHT,
                BackgroundTransparency = 1,
                TextSize = 14,
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = page,
                Text = entry.hint,
                Size = UDim2.new(1, -102, 0, 18),
                Position = UDim2.fromOffset(102, 28),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = dOS.THEME.TEXT_DIM,
                BackgroundTransparency = 1,
                TextSize = 11,
            })

            -- update swatch + hex when slider changes
            local function update_display()
                dOS.Tween.new(
                    swatch,
                    { BackgroundColor3 = Color3.fromRGB(red, green, blue) },
                    dOS.TweenInfo.new(0.1)
                ):Play()
                hex_label.Text = string.format("#%02X%02X%02X", red, green, blue)
            end

            -- channel labels + sliders
            local channel_colors = {
                R = Color3.fromRGB(210, 80, 80),
                G = Color3.fromRGB(80, 190, 100),
                B = Color3.fromRGB(80, 130, 230),
            }
            local slider_y_start = 56
            local slider_step = 26
            local label_x = 102
            local slider_x = 118
            local slider_width = UDim2.new(1, -120, 0, 12)

            for channel_index, channel in ipairs({ "R", "G", "B" }) do
                local slider_y = slider_y_start + (channel_index - 1) * slider_step

                dOS.create_gui_element(dOS, "TextLabel", {
                    Parent = page,
                    Text = channel,
                    Size = UDim2.fromOffset(14, 14),
                    Position = UDim2.fromOffset(label_x, slider_y - 1),
                    TextColor3 = channel_colors[channel],
                    Font = dOS.FONT_BOLD,
                    BackgroundTransparency = 1,
                    TextSize = 13,
                })

                local initial_value = channel == "R" and red or (channel == "G" and green or blue)

                dOS.create_slider(
                    dOS,
                    page,
                    UDim2.fromOffset(slider_x, slider_y),
                    slider_width,
                    0,
                    255,
                    initial_value,
                    function(value)
                        local rounded = math.round(value)
                        if channel == "R" then
                            red = rounded
                        elseif channel == "G" then
                            green = rounded
                        else
                            blue = rounded
                        end
                        update_display()
                    end
                )
            end

            -- set color button
            local set_btn
            set_btn = dOS.create_gui_element(dOS, "TextButton", {
                Parent = page,
                Text = "Set Color  ->",
                Size = UDim2.new(1, 0, 0, 34),
                Position = UDim2.new(0, 0, 1, -46),
                BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
                TextColor3 = dOS.THEME.TEXT_LIGHT,
                Font = dOS.FONT_BOLD,
                TextSize = 13,
                OnClick = function()
                    edit_palette[entry.key] = Color3.fromRGB(red, green, blue)
                    show_page(current_idx + 1, 1)
                end,
                OnEnter = function()
                    dOS.Tween.new(
                        set_btn,
                        { BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_HOVER },
                        dOS.TweenInfo.new(0.18)
                    ):Play()
                end,
                OnLeave = function()
                    dOS.Tween.new(
                        set_btn,
                        { BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG },
                        dOS.TweenInfo.new(0.18)
                    ):Play()
                end,
            })

            dOS.create_gui_element(dOS, "UICorner", {
                Parent = set_btn,
                CornerRadius = UDim.new(0, 6),
            })

            return page
        end

        local function get_color(key)
            return edit_palette[key] or dOS.THEME[key] or Color3.fromRGB(100, 100, 100)
        end

        local VIZ_BUILDERS = {}

        -- backgrounds
        VIZ_BUILDERS["Backgrounds"] = function(container)
            local desktop = dOS.create_gui_element(dOS, "Frame", {
                Parent = container,
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = get_color("DESKTOP_BG"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = desktop,
                CornerRadius = UDim.new(0, 6),
            })

            dOS.create_gui_element(dOS, "Frame", {
                Parent = desktop,
                Size = UDim2.new(1, 0, 0, 14),
                Position = UDim2.new(0, 0, 1, -14),
                BackgroundColor3 = get_color("TASKBAR_BG"),
                BorderSizePixel = 0,
            })

            local window = dOS.create_gui_element(dOS, "Frame", {
                Parent = desktop,
                Size = UDim2.fromScale(0.6, 0.65),
                Position = UDim2.fromOffset(8, 8),
                BackgroundColor3 = get_color("WINDOW_BG"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = window,
                CornerRadius = UDim.new(0, 4),
            })

            local title_bar = dOS.create_gui_element(dOS, "Frame", {
                Parent = window,
                Size = UDim2.new(1, 0, 0, 13),
                BackgroundColor3 = get_color("TITLE_BAR_BG"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = title_bar,
                CornerRadius = UDim.new(0, 4),
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = title_bar,
                Text = "Window Title",
                Size = UDim2.new(1, -8, 1, 0),
                Position = UDim2.fromOffset(5, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = get_color("TEXT_LIGHT"),
                BackgroundTransparency = 1,
                TextSize = 7,
                Font = dOS.FONT_BOLD,
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = desktop,
                Text = "Desktop",
                Size = UDim2.new(1, 0, 0, 12),
                Position = UDim2.fromScale(0.32, 0.08),
                TextColor3 = get_color("TEXT_LIGHT"),
                BackgroundTransparency = 1,
                TextSize = 8,
            })
        end

        -- buttons & accents
        VIZ_BUILDERS["Buttons & Accents"] = function(container)
            local background = dOS.create_gui_element(dOS, "Frame", {
                Parent = container,
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = get_color("WINDOW_BG"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = background,
                CornerRadius = UDim.new(0, 6),
            })

            local labels = { "Accent Btn", "Hover", "Accent", "Border Hi", "Border" }
            local colors = {
                "ACCENT_BUTTON_BG",
                "ACCENT_BUTTON_HOVER",
                "ACCENT",
                "BORDER_HIGHLIGHT",
                "BORDER_DARK",
            }

            for index, label_text in ipairs(labels) do
                local button = dOS.create_gui_element(dOS, "Frame", {
                    Parent = background,
                    Size = UDim2.fromOffset(82, 20),
                    Position = UDim2.fromOffset(4 + (index - 1) * 88, 30),
                    BackgroundColor3 = get_color(colors[index]),
                    BorderSizePixel = 0,
                })
                dOS.create_gui_element(dOS, "UICorner", {
                    Parent = button,
                    CornerRadius = UDim.new(0, 4),
                })

                dOS.create_gui_element(dOS, "TextLabel", {
                    Parent = button,
                    Text = label_text,
                    Size = UDim2.fromScale(1, 1),
                    TextColor3 = get_color("TEXT_LIGHT"),
                    BackgroundTransparency = 1,
                    TextSize = 7,
                })
            end

            local dot = dOS.create_gui_element(dOS, "Frame", {
                Parent = background,
                Size = UDim2.fromOffset(18, 18),
                Position = UDim2.fromOffset(8, 60),
                BackgroundColor3 = get_color("ACCENT"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = dot,
                CornerRadius = UDim.new(0.5, 0),
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = background,
                Text = "← Accent color",
                Size = UDim2.new(1, -32, 0, 18),
                Position = UDim2.fromOffset(30, 61),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = get_color("TEXT_DIM") or get_color("TEXT_LIGHT"),
                BackgroundTransparency = 1,
                TextSize = 8,
            })
        end

        -- text & input
        VIZ_BUILDERS["Text & Input"] = function(container)
            local background = dOS.create_gui_element(dOS, "Frame", {
                Parent = container,
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = get_color("WINDOW_BG"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = background,
                CornerRadius = UDim.new(0, 6),
            })

            local samples = {
                {
                    text = "Primary Text",
                    color = "TEXT_LIGHT",
                    y = 8,
                    size = 11,
                    bold = true,
                },
                {
                    text = "Dark Text sample",
                    color = "TEXT_DARK",
                    y = 26,
                    size = 9,
                    bold = false,
                },
                {
                    text = "Dimmed / secondary",
                    color = "TEXT_DIM",
                    y = 40,
                    size = 9,
                    bold = false,
                },
            }

            for _, sample in ipairs(samples) do
                dOS.create_gui_element(dOS, "TextLabel", {
                    Parent = background,
                    Text = sample.text,
                    Size = UDim2.new(1, -14, 0, 16),
                    Position = UDim2.fromOffset(8, sample.y),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextColor3 = get_color(sample.color),
                    BackgroundTransparency = 1,
                    TextSize = sample.size,
                    Font = sample.bold and dOS.FONT_BOLD or dOS.FONT_REGULAR,
                })
            end

            local input_box = dOS.create_gui_element(dOS, "Frame", {
                Parent = background,
                Size = UDim2.new(1, -16, 0, 18),
                Position = UDim2.fromOffset(8, 64),
                BackgroundColor3 = get_color("TEXT_BOX_DARK"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = input_box,
                CornerRadius = UDim.new(0, 3),
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = input_box,
                Text = "Text field…",
                Size = UDim2.new(1, -8, 1, 0),
                Position = UDim2.fromOffset(4, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = get_color("TEXT_BOX_LIGHT"),
                BackgroundTransparency = 1,
                TextSize = 8,
            })
        end

        -- start menu
        VIZ_BUILDERS["Start Menu"] = function(container)
            local desktop = dOS.create_gui_element(dOS, "Frame", {
                Parent = container,
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = get_color("DESKTOP_BG"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = desktop,
                CornerRadius = UDim.new(0, 6),
            })

            local taskbar = dOS.create_gui_element(dOS, "Frame", {
                Parent = desktop,
                Size = UDim2.new(1, 0, 0, 14),
                Position = UDim2.new(0, 0, 1, -14),
                BackgroundColor3 = get_color("TASKBAR_BG"),
                BorderSizePixel = 0,
            })

            local start_button = dOS.create_gui_element(dOS, "Frame", {
                Parent = taskbar,
                Size = UDim2.fromOffset(28, 10),
                Position = UDim2.fromOffset(2, 2),
                BackgroundColor3 = get_color("START_BUTTON_BG"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = start_button,
                CornerRadius = UDim.new(0, 3),
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = start_button,
                Text = "Start",
                Size = UDim2.fromScale(1, 1),
                TextColor3 = get_color("TEXT_LIGHT"),
                BackgroundTransparency = 1,
                TextSize = 6,
            })

            local panel = dOS.create_gui_element(dOS, "Frame", {
                Parent = desktop,
                Size = UDim2.fromScale(0.55, 0.75),
                Position = UDim2.new(0, 2, 1, -89),
                BackgroundColor3 = get_color("START_MENU_BG"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = panel,
                CornerRadius = UDim.new(0, 5),
            })

            local content = dOS.create_gui_element(dOS, "Frame", {
                Parent = panel,
                Size = UDim2.new(1, 0, 1, -14),
                Position = UDim2.fromOffset(0, 14),
                BackgroundColor3 = get_color("START_MENU_CONTENT_BG"),
                BorderSizePixel = 0,
            })

            for tile_index = 0, 5 do
                local column = tile_index % 3
                local row = math.floor(tile_index / 3)
                local tile = dOS.create_gui_element(dOS, "Frame", {
                    Parent = content,
                    Size = UDim2.fromOffset(22, 18),
                    Position = UDim2.fromOffset(3 + column * 25, 3 + row * 21),
                    BackgroundColor3 = get_color("START_MENU_TILE_BG"),
                    BorderSizePixel = 0,
                })
                dOS.create_gui_element(dOS, "UICorner", {
                    Parent = tile,
                    CornerRadius = UDim.new(0, 3),
                })
            end

            -- bottom bar
            dOS.create_gui_element(dOS, "Frame", {
                Parent = panel,
                Size = UDim2.new(1, 0, 0, 14),
                BackgroundColor3 = get_color("START_MENU_BOTTOM_BAR"),
                BorderSizePixel = 0,
            })
        end

        VIZ_BUILDERS["Calculator"] = function(container)
            local background = dOS.create_gui_element(dOS, "Frame", {
                Parent = container,
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = get_color("WINDOW_BG"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = background,
                CornerRadius = UDim.new(0, 6),
            })

            local display = dOS.create_gui_element(dOS, "Frame", {
                Parent = background,
                Size = UDim2.new(1, -12, 0, 24),
                Position = UDim2.fromOffset(6, 6),
                BackgroundColor3 = get_color("CALC_DISPLAY_BG"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = display,
                CornerRadius = UDim.new(0, 4),
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = display,
                Text = 1234,
                Size = UDim2.new(1, -6, 1, 0),
                Position = UDim2.fromOffset(3, 0),
                TextXAlignment = Enum.TextXAlignment.Right,
                TextColor3 = get_color("TEXT_LIGHT"),
                BackgroundTransparency = 1,
                TextSize = 10,
                Font = dOS.FONT_BOLD,
            })

            local button_width, button_height, gap = 24, 16, 3
            local grid = {
                { "C", "%", "/", "*" },
                { 7, 8, 9, "-" },
                { 4, 5, 6, "+" },
                { 1, 2, 3, "=" },
                { 0, ".", "DEL" },
            }

            for row_index, row_data in ipairs(grid) do
                local visual_column = 0

                for _, label in ipairs(row_data) do
                    local is_operator = table.find(
                        { "/", "*", "-", "+", "=", "C", "%", "DEL" },
                        label
                    ) ~= nil

                    local current_width = button_width
                    local cols_taken = 1
                    if label == 0 then
                        current_width = (button_width * 2) + gap
                        cols_taken = 2
                    end

                    local button = dOS.create_gui_element(dOS, "Frame", {
                        Parent = background,
                        Size = UDim2.fromOffset(current_width, button_height),
                        Position = UDim2.fromOffset(
                            6 + visual_column * (button_width + gap),
                            36 + (row_index - 1) * (button_height + gap)
                        ),
                        BackgroundColor3 = is_operator
                            and get_color("CALC_OP_BUTTON_BG")
                            or get_color("CALC_BUTTON_BG"),
                        BorderSizePixel = 0,
                    })

                    dOS.create_gui_element(dOS, "UICorner", {
                        Parent = button,
                        CornerRadius = UDim.new(0, 3),
                    })

                    dOS.create_gui_element(dOS, "TextLabel", {
                        Parent = button,
                        Text = label,
                        Size = UDim2.fromScale(1, 1),
                        TextColor3 = get_color("TEXT_LIGHT"),
                        BackgroundTransparency = 1,
                        TextSize = 7,
                    })

                    visual_column = visual_column + cols_taken
                end
            end
        end

        VIZ_BUILDERS["Lock Screen"] = function(container)
            local background = dOS.create_gui_element(dOS, "Frame", {
                Parent = container,
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = get_color("LOCKSCREEN_BG"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = background,
                CornerRadius = UDim.new(0, 6),
            })

            local overlay = dOS.create_gui_element(dOS, "Frame", {
                Parent = background,
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = get_color("LOCKSCREEN_OVERLAY"),
                BackgroundTransparency = 0.6,
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = overlay,
                CornerRadius = UDim.new(0, 6),
            })

            local card = dOS.create_gui_element(dOS, "Frame", {
                Parent = background,
                Size = UDim2.fromOffset(120, 88),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                BackgroundColor3 = get_color("LOCKSCREEN_CARD_BG"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = card,
                CornerRadius = UDim.new(0, 7),
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = card,
                Text = "dOS Lock Screen",
                Size = UDim2.new(1, -8, 0, 14),
                Position = UDim2.fromOffset(4, 6),
                TextColor3 = get_color("TEXT_LIGHT") or Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                TextSize = 8,
                Font = dOS.FONT_BOLD,
            })

            local input_field = dOS.create_gui_element(dOS, "Frame", {
                Parent = card,
                Size = UDim2.new(1, -12, 0, 16),
                Position = UDim2.fromOffset(6, 26),
                BackgroundColor3 = get_color("LOCKSCREEN_INPUT_BG"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = input_field,
                CornerRadius = UDim.new(0, 4),
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = input_field,
                Text = "Password",
                Size = UDim2.new(1, -6, 1, 0),
                Position = UDim2.fromOffset(3, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = get_color("TEXT_DIM") or Color3.fromRGB(180, 180, 180),
                BackgroundTransparency = 1,
                TextSize = 7,
            })

            local primary_button = dOS.create_gui_element(dOS, "Frame", {
                Parent = card,
                Size = UDim2.fromOffset(50, 14),
                Position = UDim2.fromOffset(6, 50),
                BackgroundColor3 = get_color("LOCKSCREEN_BUTTON_PRIMARY"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = primary_button,
                CornerRadius = UDim.new(0, 3),
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = primary_button,
                Text = "Unlock",
                Size = UDim2.fromScale(1, 1),
                TextColor3 = get_color("TEXT_LIGHT") or Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                TextSize = 7,
            })

            local secondary_button = dOS.create_gui_element(dOS, "Frame", {
                Parent = card,
                Size = UDim2.fromOffset(50, 14),
                Position = UDim2.fromOffset(62, 50),
                BackgroundColor3 = get_color("LOCKSCREEN_BUTTON_SECONDARY"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = secondary_button,
                CornerRadius = UDim.new(0, 3),
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = secondary_button,
                Text = "Cancel",
                Size = UDim2.fromScale(1, 1),
                TextColor3 = get_color("TEXT_LIGHT") or Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                TextSize = 7,
            })

            local success_dot = dOS.create_gui_element(dOS, "Frame", {
                Parent = card,
                Size = UDim2.fromOffset(8, 8),
                Position = UDim2.fromOffset(6, 72),
                BackgroundColor3 = get_color("LOCKSCREEN_SUCCESS"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = success_dot,
                CornerRadius = UDim.new(0.5, 0),
            })

            local error_dot = dOS.create_gui_element(dOS, "Frame", {
                Parent = card,
                Size = UDim2.fromOffset(8, 8),
                Position = UDim2.fromOffset(20, 72),
                BackgroundColor3 = get_color("LOCKSCREEN_ERROR"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = error_dot,
                CornerRadius = UDim.new(0.5, 0),
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = card,
                Text = "✓ / ✗  indicators",
                Size = UDim2.new(1, -34, 0, 10),
                Position = UDim2.fromOffset(32, 71),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = get_color("TEXT_DIM") or Color3.fromRGB(180, 180, 180),
                BackgroundTransparency = 1,
                TextSize = 6,
            })
        end

        VIZ_BUILDERS["Explorer & Other"] = function(container)
            local background = dOS.create_gui_element(dOS, "Frame", {
                Parent = container,
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = get_color("WINDOW_BG"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = background,
                CornerRadius = UDim.new(0, 6),
            })

            local navigation = dOS.create_gui_element(dOS, "Frame", {
                Parent = background,
                Size = UDim2.fromOffset(52, 100),
                Position = UDim2.fromOffset(0, 0),
                BackgroundColor3 = get_color("CALC_DISPLAY_BG") or get_color("WINDOW_BG"),
                BorderSizePixel = 0,
            })

            local nav_items = { "📁 Home", "💾 A:", "🗑 Trash" } -- aAAaAa Emojis

            for nav_index, nav_name in ipairs(nav_items) do
                local is_selected = (nav_index == 1)
                local nav_row = dOS.create_gui_element(dOS, "Frame", {
                    Parent = navigation,
                    Size = UDim2.new(1, 0, 0, 16),
                    Position = UDim2.fromOffset(0, (nav_index - 1) * 18),
                    BackgroundColor3 = is_selected
                        and get_color("EXPLORER_NAV_BTN_SELECTED")
                        or get_color("EXPLORER_NAV_BTN"),
                    BorderSizePixel = 0,
                })
                dOS.create_gui_element(dOS, "UICorner", {
                    Parent = nav_row,
                    CornerRadius = UDim.new(0, 3),
                })

                dOS.create_gui_element(dOS, "TextLabel", {
                    Parent = nav_row,
                    Text = nav_name,
                    Size = UDim2.new(1, -4, 1, 0),
                    Position = UDim2.fromOffset(3, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextColor3 = get_color("TEXT_LIGHT"),
                    BackgroundTransparency = 1,
                    TextSize = 6,
                })
            end

            local overlay = dOS.create_gui_element(dOS, "Frame", {
                Parent = background,
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = get_color("MSGBOX_OVERLAY_COLOR"),
                BackgroundTransparency = 0.65,
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = overlay,
                CornerRadius = UDim.new(0, 6),
            })

            local message_box = dOS.create_gui_element(dOS, "Frame", {
                Parent = background,
                Size = UDim2.fromOffset(150, 60),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.55),
                BackgroundColor3 = get_color("MSGBOX_BG"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = message_box,
                CornerRadius = UDim.new(0, 6),
            })

            local msgbox_title = dOS.create_gui_element(dOS, "Frame", {
                Parent = message_box,
                Size = UDim2.new(1, 0, 0, 14),
                BackgroundColor3 = get_color("TITLE_BAR_BG"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = msgbox_title,
                CornerRadius = UDim.new(0, 6),
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = msgbox_title,
                Text = "Message",
                Size = UDim2.new(1, -6, 1, 0),
                Position = UDim2.fromOffset(5, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = get_color("TEXT_LIGHT"),
                BackgroundTransparency = 1,
                TextSize = 7,
                Font = dOS.FONT_BOLD,
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = message_box,
                Text = "Message box.",
                Size = UDim2.new(1, -10, 0, 16),
                Position = UDim2.fromOffset(5, 18),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = get_color("TEXT_LIGHT"),
                BackgroundTransparency = 1,
                TextSize = 7,
            })

            local ok_button = dOS.create_gui_element(dOS, "Frame", {
                Parent = message_box,
                Size = UDim2.fromOffset(40, 13),
                Position = UDim2.fromOffset(8, 42),
                BackgroundColor3 = get_color("ACCENT_BUTTON_BG"),
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = ok_button,
                CornerRadius = UDim.new(0, 3),
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = ok_button,
                Text = "OK",
                Size = UDim2.fromScale(1, 1),
                TextColor3 = get_color("TEXT_LIGHT"),
                BackgroundTransparency = 1,
                TextSize = 7,
            })
        end

        -- visualization page builder
        local function make_viz_page(group)
            local page = dOS.create_gui_element(dOS, "Frame", {
                Parent = page_area,
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
            })

            dOS.create_gui_element(dOS, "UIPadding", {
                Parent = page,
                PaddingLeft = UDim.new(0, 14),
                PaddingRight = UDim.new(0, 14),
                PaddingTop = UDim.new(0, 10),
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = page,
                Text = `✓  "{group.name}" complete`,
                Size = UDim2.new(1, 0, 0, 22),
                Position = UDim2.fromOffset(0, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = dOS.THEME.ACCENT,
                Font = dOS.FONT_BOLD,
                BackgroundTransparency = 1,
                TextSize = 13,
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = page,
                Text = "Preview how your colors look. Continue or redo this group.",
                Size = UDim2.new(1, 0, 0, 14),
                Position = UDim2.fromOffset(0, 26),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = dOS.THEME.TEXT_DIM,
                BackgroundTransparency = 1,
                TextSize = 10,
            })

            local preview_frame = dOS.create_gui_element(dOS, "Frame", {
                Parent = page,
                Size = UDim2.new(1, 0, 0, 148),
                Position = UDim2.fromOffset(0, 46),
                BackgroundColor3 = dOS.THEME.CALC_DISPLAY_BG,
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = preview_frame,
                CornerRadius = UDim.new(0, 8),
            })

            local inner = dOS.create_gui_element(dOS, "Frame", {
                Parent = preview_frame,
                Size = UDim2.new(1, -16, 1, -16),
                Position = UDim2.fromOffset(8, 8),
                BackgroundTransparency = 1,
            })

            local builder = VIZ_BUILDERS[group.name]
            if builder then
                builder(inner)
            else
                -- fallback
                local viz_elements = build_theme_preview(inner)
                apply_preview_palette(viz_elements, {
                    bg = get_color("WINDOW_BG"),
                    bar = get_color("TITLE_BAR_BG"),
                    accent = get_color("ACCENT"),
                    btn = get_color("ACCENT_BUTTON_BG"),
                    txt = get_color("TEXT_LIGHT"),
                })
            end

            local redo_btn = dOS.create_gui_element(dOS, "TextButton", {
                Parent = page,
                Text = "↩ Redo group",
                Size = UDim2.new(0.44, 0, 0, 32),
                Position = UDim2.new(0, 0, 1, -44),
                BackgroundColor3 = dOS.THEME.CALC_BUTTON_BG,
                TextColor3 = dOS.THEME.TEXT_LIGHT,
                TextSize = 12,
                OnClick = function()
                    for page_index, page_data in ipairs(pages) do
                        if page_data.type == "pick" and page_data.group == group then
                            show_page(page_index, -1)
                            return
                        end
                    end
                end,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = redo_btn,
                CornerRadius = UDim.new(0, 6),
            })

            local continue_btn
            continue_btn = dOS.create_gui_element(dOS, "TextButton", {
                Parent = page,
                Text = "Continue ->",
                Size = UDim2.new(0.52, 0, 0, 32),
                Position = UDim2.new(0.48, 0, 1, -44),
                BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
                TextColor3 = dOS.THEME.TEXT_LIGHT,
                Font = dOS.FONT_BOLD,
                TextSize = 12,
                OnClick = function()
                    show_page(current_idx + 1, 1)
                end,
                OnEnter = function()
                    dOS.Tween.new(
                        continue_btn,
                        { BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_HOVER },
                        dOS.TweenInfo.new(0.18)
                    ):Play()
                end,
                OnLeave = function()
                    dOS.Tween.new(
                        continue_btn,
                        { BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG },
                        dOS.TweenInfo.new(0.18)
                    ):Play()
                end,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = continue_btn,
                CornerRadius = UDim.new(0, 6),
            })

            return page
        end

        local function make_save_page()
            local page = dOS.create_gui_element(dOS, "Frame", {
                Parent = page_area,
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
            })
            dOS.create_gui_element(dOS, "UIPadding", {
                Parent = page,
                PaddingLeft = UDim.new(0, 14),
                PaddingRight = UDim.new(0, 14),
                PaddingTop = UDim.new(0, 12),
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = page,
                Text = "Theme Complete!",
                Size = UDim2.new(1, 0, 0, 26),
                Position = UDim2.fromOffset(0, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = dOS.THEME.ACCENT,
                Font = dOS.FONT_BOLD,
                BackgroundTransparency = 1,
                TextSize = 16,
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = page,
                Text = "Name your theme and save. Select it in Personalization.",
                Size = UDim2.new(1, 0, 0, 18),
                Position = UDim2.fromOffset(0, 30),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = dOS.THEME.TEXT_DIM,
                BackgroundTransparency = 1,
                TextSize = 11,
            })

            local name_btn
            name_btn = dOS.create_gui_element(dOS, "TextButton", {
                Parent = page,
                Text = theme_name,
                Size = UDim2.new(1, 0, 0, 30),
                Position = UDim2.fromOffset(0, 54),
                BackgroundColor3 = dOS.THEME.TEXT_BOX_DARK,
                TextColor3 = dOS.THEME.TEXT_LIGHT,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextSize = 12,
                OnClick = function()
                    dOS.RequestStringAsync(
                        dOS,
                        "Enter theme name:",
                        theme_name,
                        function(new_name)
                            if new_name and new_name ~= "" then
                                theme_name = new_name
                                name_btn.Text = new_name
                            end
                        end
                    )
                end,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = name_btn,
                CornerRadius = UDim.new(0, 5),
            })
            dOS.create_gui_element(dOS, "UIPadding", {
                Parent = name_btn,
                PaddingLeft = UDim.new(0, 10),
            })

            local final_preview = dOS.create_gui_element(dOS, "Frame", {
                Parent = page,
                Size = UDim2.new(1, 0, 0, 120),
                Position = UDim2.fromOffset(0, 92),
                BackgroundColor3 = dOS.THEME.CALC_DISPLAY_BG,
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = final_preview,
                CornerRadius = UDim.new(0, 8),
            })

            local final_view = build_theme_preview(final_preview)

            apply_preview_palette(final_view, {
                bg = edit_palette.WINDOW_BG or dOS.THEME.WINDOW_BG,
                bar = edit_palette.TITLE_BAR_BG or dOS.THEME.TITLE_BAR_BG,
                accent = edit_palette.ACCENT or dOS.THEME.ACCENT,
                btn = edit_palette.ACCENT_BUTTON_BG or dOS.THEME.ACCENT_BUTTON_BG,
                txt = edit_palette.TEXT_LIGHT or dOS.THEME.TEXT_LIGHT,
            })

            local save_btn
            save_btn = dOS.create_gui_element(dOS, "TextButton", {
                Parent = page,
                Text = "Save Theme",
                Size = UDim2.new(1, 0, 0, 34),
                Position = UDim2.new(0, 0, 1, -46),
                BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
                TextColor3 = dOS.THEME.TEXT_LIGHT,
                Font = dOS.FONT_BOLD,
                TextSize = 14,
                OnClick = function()
                    local name = theme_name
                    custom_themes_list[name] = serialize_palette(edit_palette)
                    state.temp_settings.custom_themes = custom_themes_list

                    if not state.temp_settings.selected_theme_name then
                        state.temp_settings.global_theme = 4
                        state.temp_settings.selected_theme_name = name
                    end

                    dOS.Tween.new(
                        save_btn,
                        { BackgroundColor3 = Color3.fromRGB(80, 180, 100) },
                        dOS.TweenInfo.new(0.35)
                    ):Play()

                    task.delay(0.4, function()
                        save_btn.Text = "Saved!"
                        task.delay(0.9, function()
                            if editor_win and editor_win.Parent then
                                editor_win:Destroy()
                            end
                        end)
                    end)

                    if dOS.NotificationManager and dOS.NotificationManager.push then
                        dOS.NotificationManager.push(
                            dOS,
                            "Theme Saved",
                            `'{name}' saved. Select it in Personalization.`,
                            ICONS.Personalization,
                            nil
                        )
                    end
                end,
                OnEnter = function()
                    dOS.Tween.new(
                        save_btn,
                        { BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_HOVER },
                        dOS.TweenInfo.new(0.18)
                    ):Play()
                end,
                OnLeave = function()
                    dOS.Tween.new(
                        save_btn,
                        { BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG },
                        dOS.TweenInfo.new(0.18)
                    ):Play()
                end,
            })

            dOS.create_gui_element(dOS, "UICorner", {
                Parent = save_btn,
                CornerRadius = UDim.new(0, 6),
            })

            return page
        end

        local is_transitioning = false

        show_page = function(index, direction)
            index = math.clamp(index, 1, #pages)
            if is_transitioning then return end

            is_transitioning = true

            local old_frame = current_page_frame
            current_page_frame = nil

            current_idx = index
            update_header(index)

            if old_frame and old_frame.Parent then
                local exit_x = direction == 1 and -1 or 1

                dOS.Tween.new(
                    old_frame,
                    { Position = UDim2.fromScale(exit_x, 0) },
                    dOS.TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                ):Play()

                task.delay(0.21, function()
                    if old_frame and old_frame.Parent then
                        old_frame:Destroy()
                    end
                end)
            end

            local function build_new()
                local page_data = pages[index]
                local new_frame

                if page_data.type == "pick" then
                    new_frame = make_pick_page(page_data.entry)
                elseif page_data.type == "viz" then
                    new_frame = make_viz_page(page_data.group)
                else
                    new_frame = make_save_page()
                end

                local enter_x = direction == 1 and 1 or -1
                new_frame.Position = UDim2.fromScale(enter_x, 0)

                dOS.Tween.new(
                    new_frame,
                    { Position = UDim2.fromOffset(0, 0) },
                    dOS.TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                ):Play()
                current_page_frame = new_frame

                task.delay(0.28, function()
                    task.wait()
                    is_transitioning = false
                end)
            end

            build_new()
        end

        nav_back_btn.MouseButton1Click:Connect(function()
            if current_idx > 1 then
                show_page(current_idx - 1, -1)
            end
        end)

        local keyboard_connection
        if dOS.keyboard then
            keyboard_connection = dOS.keyboard.TextInputted:Connect(function(text)
                if text and text:byte(1) == 28 then
                    if current_idx > 1 then
                        show_page(current_idx - 1, -1)
                    end
                end
            end)

            editor_win.Destroying:Connect(function()
                pcall(function() keyboard_connection:Disconnect() end)
            end)
        end

        show_page(1, 1)
    end

    --- SELECTOR

    local function build_theme_selector_content(content_container, preview_elements_ref)
        -- track selection state locally
        local current_theme_index = (state.temp_settings.global_theme or 0) + 1
        if current_theme_index < 1 or current_theme_index > #THEME_NAMES then
            current_theme_index = 1
        end

        local current_custom_name = state.temp_settings.selected_theme_name
        local custom_rows = {}

        local function get_current_palette()
            if
                state.temp_settings.global_theme == 4
                and current_custom_name
                and custom_themes_list[current_custom_name]
            then
                local palette = deserialize_palette(custom_themes_list[current_custom_name])

                return {
                    bg = palette.WINDOW_BG or dOS.THEME.WINDOW_BG,
                    bar = palette.TITLE_BAR_BG or dOS.THEME.TITLE_BAR_BG,
                    accent = palette.ACCENT or dOS.THEME.ACCENT,
                    btn = palette.ACCENT_BUTTON_BG or dOS.THEME.ACCENT_BUTTON_BG,
                    txt = palette.TEXT_LIGHT or dOS.THEME.TEXT_LIGHT,
                }
            end

            return THEME_PALETTES[THEME_NAMES[current_theme_index]] or THEME_PALETTES.Purple
        end

        local preview_panel = dOS.create_gui_element(dOS, "Frame", {
            Parent = content_container,
            Size = UDim2.new(1, 0, 0, 112),
            Position = UDim2.fromOffset(0, 0),
            BackgroundColor3 = dOS.THEME.CALC_DISPLAY_BG,
            BorderSizePixel = 0,
        })
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = preview_panel,
            CornerRadius = UDim.new(0, 8),
        })

        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = preview_panel,
            Text = "Theme Preview",
            Size = UDim2.new(1, -10, 0, 14),
            Position = UDim2.fromOffset(8, 4),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = dOS.THEME.TEXT_DIM,
            BackgroundTransparency = 1,
            TextSize = 10,
        })

        local preview_inner = dOS.create_gui_element(dOS, "Frame", {
            Parent = preview_panel,
            Size = UDim2.new(1, -14, 1, -20),
            Position = UDim2.fromOffset(7, 18),
            BackgroundTransparency = 1,
        })

        preview_elements_ref.elements = build_theme_preview(preview_inner)
        apply_preview_palette(
            preview_elements_ref.elements,
            get_current_palette()
        )

        local cycle_row = dOS.create_gui_element(dOS, "Frame", {
            Parent = content_container,
            Size = UDim2.new(1, 0, 0, 50),
            Position = UDim2.fromOffset(0, 120),
            BackgroundColor3 = dOS.THEME.CALC_DISPLAY_BG,
            BorderSizePixel = 0,
        })
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = cycle_row,
            CornerRadius = UDim.new(0, 8),
        })

        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = cycle_row,
            Text = "Built-in Theme",
            Size = UDim2.new(0.5, 0, 0, 18),
            Position = UDim2.fromOffset(10, 6),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = dOS.THEME.TEXT_DIM,
            BackgroundTransparency = 1,
            TextSize = 11,
        })

        local theme_name_label = dOS.create_gui_element(dOS, "TextLabel", {
            Parent = cycle_row,
            Text = THEME_NAMES[current_theme_index],
            Size = UDim2.new(0.5, 0, 0, 22),
            Position = UDim2.fromOffset(10, 24),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = dOS.THEME.TEXT_LIGHT,
            Font = dOS.FONT_BOLD,
            BackgroundTransparency = 1,
            TextSize = 13,
        })

        local prev_button = dOS.create_gui_element(dOS, "TextButton", {
            Parent = cycle_row,
            Text = "◀",
            Size = UDim2.fromOffset(30, 30),
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -40, 0.5, 0),
            BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
            TextColor3 = dOS.THEME.TEXT_LIGHT,
            TextSize = 13,
        })
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = prev_button,
            CornerRadius = UDim.new(0, 5),
        })

        local next_button = dOS.create_gui_element(dOS, "TextButton", {
            Parent = cycle_row,
            Text = "▶",
            Size = UDim2.fromOffset(30, 30),
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -4, 0.5, 0),
            BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
            TextColor3 = dOS.THEME.TEXT_LIGHT,
            TextSize = 13,
        })
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = next_button,
            CornerRadius = UDim.new(0, 5),
        })

        local function cycle_to(index)
            current_theme_index = ((index - 1) % #THEME_NAMES) + 1
            state.temp_settings.global_theme = current_theme_index - 1
            state.temp_settings.selected_theme_name = nil
            current_custom_name = nil
            theme_name_label.Text = THEME_NAMES[current_theme_index]

            dOS.Tween.new(
                theme_name_label,
                { TextColor3 = dOS.THEME.ACCENT },
                dOS.TweenInfo.new(0.15)
            ):Play()

            task.delay(0.25, function()
                dOS.Tween.new(
                    theme_name_label,
                    { TextColor3 = dOS.THEME.TEXT_LIGHT },
                    dOS.TweenInfo.new(0.3)
                ):Play()
            end)

            for _, data in pairs(custom_rows) do
                data.btn.Text = "Select"
                dOS.Tween.new(
                    data.btn,
                    { BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG },
                    dOS.TweenInfo.new(0.25)
                ):Play()
                dOS.Tween.new(
                    data.row,
                    { BackgroundColor3 = dOS.THEME.TEXT_BOX_DARK },
                    dOS.TweenInfo.new(0.25)
                ):Play()
            end

            if preview_elements_ref.elements then
                apply_preview_palette(
                    preview_elements_ref.elements,
                    get_current_palette()
                )
            end
        end

        prev_button.MouseButton1Click:Connect(function()
            cycle_to(current_theme_index - 1)
        end)

        next_button.MouseButton1Click:Connect(function()
            cycle_to(current_theme_index + 1)
        end)

        local custom_header = dOS.create_gui_element(dOS, "Frame", {
            Parent = content_container,
            Size = UDim2.new(1, 0, 0, 40),
            Position = UDim2.fromOffset(0, 178),
            BackgroundColor3 = dOS.THEME.CALC_DISPLAY_BG,
            BorderSizePixel = 0,
        })
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = custom_header,
            CornerRadius = UDim.new(0, 8),
        })

        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = custom_header,
            Text = "Custom Themes",
            Size = UDim2.fromScale(0.55, 1),
            Position = UDim2.fromOffset(10, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = dOS.THEME.TEXT_LIGHT,
            Font = dOS.FONT_BOLD,
            BackgroundTransparency = 1,
            TextSize = 13,
        })

        local new_button
        new_button = dOS.create_gui_element(dOS, "TextButton", {
            Parent = custom_header,
            Text = "+ New",
            Size = UDim2.fromOffset(62, 26),
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -6, 0.5, 0),
            BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
            TextColor3 = dOS.THEME.TEXT_LIGHT,
            TextSize = 12,
            OnClick = function()
                open_custom_theme_editor(nil, nil)
            end,
            OnEnter = function()
                dOS.Tween.new(
                    new_button,
                    { BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_HOVER },
                    dOS.TweenInfo.new(0.18)
                ):Play()
            end,
            OnLeave = function()
                dOS.Tween.new(
                    new_button,
                    { BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG },
                    dOS.TweenInfo.new(0.18)
                ):Play()
            end,
        })
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = new_button,
            CornerRadius = UDim.new(0, 5),
        })

        -- saved custom theme rows
        local sorted_names = {}
        for name in pairs(custom_themes_list) do
            table.insert(sorted_names, name)
        end
        table.sort(sorted_names)

        for custom_index, custom_name in ipairs(sorted_names) do
            local row_y = 226 + (custom_index - 1) * 48
            local is_selected = (current_custom_name == custom_name)

            local row = dOS.create_gui_element(dOS, "Frame", {
                Parent = content_container,
                Size = UDim2.new(1, 0, 0, 42),
                Position = UDim2.fromOffset(0, row_y),
                BackgroundColor3 = is_selected
                    and dOS.THEME.ACCENT_BUTTON_BG:Lerp(Color3.fromRGB(0, 0, 0), 0.3)
                    or dOS.THEME.TEXT_BOX_DARK,
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = row,
                CornerRadius = UDim.new(0, 7),
            })

            local palette = deserialize_palette(custom_themes_list[custom_name])
            for swatch_index, swatch_key in ipairs({
                "WINDOW_BG",
                "TITLE_BAR_BG",
                "ACCENT",
                "ACCENT_BUTTON_BG",
                "TEXT_LIGHT",
            }) do
                local swatch = dOS.create_gui_element(dOS, "Frame", {
                    Parent = row,
                    Size = UDim2.fromOffset(12, 12),
                    Position = UDim2.fromOffset(8 + (swatch_index - 1) * 16, 15),
                    BackgroundColor3 = palette[swatch_key] or Color3.fromRGB(100, 100, 100),
                    BorderSizePixel = 0,
                })
                dOS.create_gui_element(dOS, "UICorner", {
                    Parent = swatch,
                    CornerRadius = UDim.new(0.5, 0),
                })
            end

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = row,
                Text = custom_name,
                Size = UDim2.fromScale(0.38, 1),
                Position = UDim2.fromOffset(96, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = dOS.THEME.TEXT_LIGHT,
                BackgroundTransparency = 1,
                TextSize = 12,
                Font = dOS.FONT_BOLD,
            })

            local delete_button = dOS.create_gui_element(dOS, "TextButton", {
                Parent = row,
                Text = "Del",
                Size = UDim2.fromOffset(36, 26),
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -6, 0.5, 0),
                BackgroundColor3 = Color3.fromRGB(180, 50, 50),
                TextColor3 = dOS.THEME.TEXT_LIGHT,
                TextSize = 11,
                OnClick = function()
                    dOS.RequestConfirmAsync(
                        dOS,
                        "Delete custom theme '" .. custom_name .. "'?",
                        false,
                        function(yes)
                            if yes then
                                custom_themes_list[custom_name] = nil
                                state.temp_settings.custom_themes = custom_themes_list

                                if current_custom_name == custom_name then
                                    cycle_to(1)
                                end

                                dOS.Tween.new(
                                    row,
                                    {
                                        Position = UDim2.fromOffset(-300, row.Position.Y.Offset),
                                        BackgroundTransparency = 1,
                                    },
                                    dOS.TweenInfo.new(0.3)
                                ):Play()

                                for _, child in ipairs(row:GetDescendants()) do
                                    if child:IsA("GuiObject") and child.BackgroundTransparency ~= nil then
                                        dOS.Tween.new(
                                            child,
                                            { BackgroundTransparency = 1 },
                                            dOS.TweenInfo.new(0.3)
                                        ):Play()
                                    end

                                    if child:IsA("TextLabel") or child:IsA("TextButton") then
                                        dOS.Tween.new(
                                            child,
                                            { TextTransparency = 1 },
                                            dOS.TweenInfo.new(0.3)
                                        ):Play()
                                    end
                                end

                                task.delay(0.3, function()
                                    row:Destroy()
                                end)

                                local deleted_index = custom_rows[custom_name].index
                                custom_rows[custom_name] = nil

                                for _, data in pairs(custom_rows) do
                                    if data.index > deleted_index then
                                        data.index = data.index - 1
                                        local new_y = 226 + (data.index - 1) * 48
                                        dOS.Tween.new(
                                            data.row,
                                            { Position = UDim2.fromOffset(0, new_y) },
                                            dOS.TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                                        ):Play()
                                    end
                                end

                                local old_height = content_container.Size.Y.Offset
                                local new_height = old_height - 48
                                local dropdown_card = content_container.Parent

                                dOS.Tween.new(
                                    content_container,
                                    { Size = UDim2.new(1, -30, 0, new_height) },
                                    dOS.TweenInfo.new(0.3)
                                ):Play()

                                dOS.Tween.new(
                                    dropdown_card,
                                    { Size = UDim2.new(1, 0, 0, 70 + new_height + 15) },
                                    dOS.TweenInfo.new(0.3)
                                ):Play()
                            end
                        end
                    )
                end,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = delete_button,
                CornerRadius = UDim.new(0, 5),
            })

            local edit_button = dOS.create_gui_element(dOS, "TextButton", {
                Parent = row,
                Text = "Edit",
                Size = UDim2.fromOffset(42, 26),
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -46, 0.5, 0),
                BackgroundColor3 = dOS.THEME.CALC_BUTTON_BG,
                TextColor3 = dOS.THEME.TEXT_LIGHT,
                TextSize = 11,
                OnClick = function()
                    open_custom_theme_editor(
                        custom_name,
                        custom_themes_list[custom_name]
                    )
                end,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = edit_button,
                CornerRadius = UDim.new(0, 5),
            })

            local select_button
            select_button = dOS.create_gui_element(dOS, "TextButton", {
                Parent = row,
                Text = is_selected and "✓ On" or "Select",
                Size = UDim2.fromOffset(58, 26),
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -92, 0.5, 0),
                BackgroundColor3 = is_selected and dOS.THEME.ACCENT or dOS.THEME.ACCENT_BUTTON_BG,
                TextColor3 = dOS.THEME.TEXT_LIGHT,
                TextSize = 11,
                OnClick = function()
                    current_custom_name = custom_name
                    state.temp_settings.global_theme = 4
                    state.temp_settings.selected_theme_name = custom_name

                    for name, data in pairs(custom_rows) do
                        if name == custom_name then
                            data.btn.Text = "✓ On"
                            dOS.Tween.new(
                                data.btn,
                                { BackgroundColor3 = dOS.THEME.ACCENT },
                                dOS.TweenInfo.new(0.25)
                            ):Play()
                            dOS.Tween.new(
                                data.row,
                                {
                                    BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG:Lerp(
                                        Color3.fromRGB(0, 0, 0),
                                        0.3
                                    ),
                                },
                                dOS.TweenInfo.new(0.25)
                            ):Play()
                        else
                            data.btn.Text = "Select"
                            dOS.Tween.new(
                                data.btn,
                                { BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG },
                                dOS.TweenInfo.new(0.25)
                            ):Play()
                            dOS.Tween.new(
                                data.row,
                                { BackgroundColor3 = dOS.THEME.TEXT_BOX_DARK },
                                dOS.TweenInfo.new(0.25)
                            ):Play()
                        end
                    end

                    if preview_elements_ref.elements then
                        apply_preview_palette(
                            preview_elements_ref.elements,
                            get_current_palette()
                        )
                    end
                end,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = select_button,
                CornerRadius = UDim.new(0, 5),
            })

            custom_rows[custom_name] = {
                row = row,
                btn = select_button,
                index = custom_index,
            }

            -- slide row in
            row.Position = UDim2.fromOffset(-160, row_y)
            dOS.Tween.new(
                row,
                { Position = UDim2.fromOffset(0, row_y) },
                dOS.TweenInfo.new(
                    0.28 + custom_index * 0.04,
                    Enum.EasingStyle.Quint,
                    Enum.EasingDirection.Out
                )
            ):Play()
        end

        -- animate top blocks in
        preview_panel.Position = UDim2.fromOffset(-180, 0)
        dOS.Tween.new(
            preview_panel,
            { Position = UDim2.fromOffset(0, 0) },
            dOS.TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        ):Play()

        cycle_row.Position = UDim2.fromOffset(-180, 120)
        dOS.Tween.new(
            cycle_row,
            { Position = UDim2.fromOffset(0, 120) },
            dOS.TweenInfo.new(0.36, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        ):Play()

        custom_header.Position = UDim2.fromOffset(-180, 178)
        dOS.Tween.new(
            custom_header,
            { Position = UDim2.fromOffset(0, 178) },
            dOS.TweenInfo.new(0.40, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        ):Play()

        -- calculate total height
        local custom_count = 0
        for _ in pairs(custom_themes_list) do
            custom_count += 1
        end

        return 226 + custom_count * 48 + 10
    end

    --- CARDS

    local function render_setting_card(item)
        local card = dOS.create_gui_element(dOS, "Frame", {
            Parent = content_area,
            Size = UDim2.new(1, 0, 0, 70),
            BackgroundColor3 = dOS.THEME.WINDOW_BG:Lerp(Color3.fromRGB(255, 255, 255), 0.05),
            BorderColor3 = dOS.THEME.BORDER_HIGHLIGHT,
            BorderSizePixel = 2,
        })
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = card,
            CornerRadius = UDim.new(0, 6),
        })

        -- labels
        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = card,
            Text = item.label,
            Size = UDim2.new(0.6, 0, 0, 25),
            Position = UDim2.fromOffset(15, 10),
            TextXAlignment = Enum.TextXAlignment.Left,
            Font = dOS.FONT_BOLD,
            BackgroundTransparency = 1,
        })

        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = card,
            Text = item.desc,
            Size = UDim2.new(0.6, 0, 0, 20),
            Position = UDim2.fromOffset(15, 35),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = dOS.THEME.TEXT_DIM,
            BackgroundTransparency = 1,
            TextSize = 12,
        })

        -- control area
        local control_area = dOS.create_gui_element(dOS, "Frame", {
            Parent = card,
            Size = UDim2.fromScale(0.35, 1),
            Position = UDim2.fromScale(0.65, 0),
            BackgroundTransparency = 1,
        })

        if item.type == "large_dropdown" then
            local is_expanded = false
            local content_height = 0
            local preview_elements_ref = {}
            local panel_gen = 0

            local function _bump_gen()
                panel_gen = panel_gen + 1
                return panel_gen
            end

            local function _current_gen()
                return panel_gen
            end

            if not item.config.is_theme_selector and item.config.items then
                for _, sub_item in ipairs(item.config.items) do
                    content_height += (sub_item.type == "cycle_button" and 80 or 70) + 10
                end
            end

            card.Size = UDim2.new(1, 0, 0, 70)

            local header_btn = dOS.create_gui_element(dOS, "TextButton", {
                Parent = card,
                Size = UDim2.new(1, 0, 0, 70),
                BackgroundTransparency = 1,
                Text = "",
                ZIndex = 2,
            })

            local arrow = dOS.create_gui_element(dOS, "TextLabel", {
                Parent = header_btn,
                Size = UDim2.fromOffset(20, 20),
                Position = UDim2.new(1, -35, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Text = "▶",
                TextSize = 14,
                Font = dOS.FONT_BOLD,
                TextColor3 = dOS.THEME.TEXT_DIM,
                BackgroundTransparency = 1,
                ZIndex = 3,
            })

            local content_container = dOS.create_gui_element(dOS, "Frame", {
                Parent = card,
                Size = UDim2.new(1, -30, 0, 0),
                Position = UDim2.fromOffset(15, 70),
                BackgroundTransparency = 1,
                ClipsDescendants = true,
                ZIndex = 2,
            })

            header_btn.MouseButton1Click:Connect(function()
                is_expanded = not is_expanded
                local my_gen = _bump_gen()

                if is_expanded then
                    if item.config.is_display_manager then
                        local lifecycle = { gen = _current_gen, bump = _bump_gen }
                        content_height = DisplayPanel.build(
                            dOS,
                            content_container,
                            lifecycle
                        )
                    elseif item.config.is_theme_selector then
                        content_height = build_theme_selector_content(
                            content_container,
                            preview_elements_ref
                        )
                    else
                        local y_position = 0
                        for sub_index, sub_item in ipairs(item.config.items or {}) do
                            local sub_card = dOS.create_gui_element(dOS, "Frame", {
                                Parent = content_container,
                                Size = UDim2.new(1, 0, 0, sub_item.type == "cycle_button" and 80 or 70),
                                Position = UDim2.fromOffset(0, y_position),
                                BackgroundColor3 = dOS.THEME.CALC_DISPLAY_BG,
                                BorderColor3 = dOS.THEME.BORDER,
                                BorderSizePixel = 1,
                                ZIndex = 3,
                            })

                            dOS.create_gui_element(dOS, "UICorner", {
                                Parent = sub_card,
                                CornerRadius = UDim.new(0, 6),
                            })

                            dOS.create_gui_element(dOS, "TextLabel", {
                                Parent = sub_card,
                                Text = sub_item.label,
                                Size = UDim2.new(0.5, 0, 0, 25),
                                Position = UDim2.fromOffset(15, 10),
                                TextXAlignment = Enum.TextXAlignment.Left,
                                Font = dOS.FONT_BOLD,
                                TextSize = 13,
                                BackgroundTransparency = 1,
                                ZIndex = 4,
                            })

                            dOS.create_gui_element(dOS, "TextLabel", {
                                Parent = sub_card,
                                Text = sub_item.desc,
                                Size = UDim2.new(0.5, 0, 0, 20),
                                Position = UDim2.fromOffset(15, 35),
                                TextXAlignment = Enum.TextXAlignment.Left,
                                TextColor3 = dOS.THEME.TEXT_DIM,
                                TextSize = 11,
                                BackgroundTransparency = 1,
                                ZIndex = 4,
                            })

                            local sub_control_area = dOS.create_gui_element(dOS, "Frame", {
                                Parent = sub_card,
                                Size = UDim2.fromScale(0.45, 1),
                                Position = UDim2.fromScale(0.55, 0),
                                BackgroundTransparency = 1,
                                ZIndex = 4,
                            })

                            create_control(sub_item, sub_control_area, true)

                            sub_card.Position = UDim2.fromOffset(-300, y_position)
                            dOS.Tween.new(
                                sub_card,
                                { Position = UDim2.fromOffset(0, y_position) },
                                dOS.TweenInfo.new(
                                    0.3 + (sub_index * 0.05),
                                    Enum.EasingStyle.Quint,
                                    Enum.EasingDirection.Out
                                )
                            ):Play()

                            y_position += (sub_item.type == "cycle_button" and 80 or 70) + 10
                        end
                    end

                    dOS.Tween.new(
                        content_container,
                        { Size = UDim2.new(1, -30, 0, content_height) },
                        dOS.TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                    ):Play()

                    dOS.Tween.new(
                        card,
                        { Size = UDim2.new(1, 0, 0, 70 + content_height + 15) },
                        dOS.TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                    ):Play()

                    dOS.Tween.new(
                        arrow,
                        { Rotation = 90 },
                        dOS.TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                    ):Play()
                else
                    -- collapse
                    for _, child in ipairs(content_container:GetChildren()) do
                        dOS.Tween.new(
                            child,
                            {
                                Position = child.Position + UDim2.fromOffset(50, 0),
                                BackgroundTransparency = 1,
                            },
                            dOS.TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                        ):Play()

                        for _, inner_child in ipairs(child:GetDescendants()) do
                            if inner_child:IsA("TextLabel") or inner_child:IsA("TextButton") then
                                dOS.Tween.new(
                                    inner_child,
                                    { TextTransparency = 1 },
                                    dOS.TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                                ):Play()
                            end

                            if
                                (inner_child:IsA("TextButton") or inner_child:IsA("Frame"))
                                and inner_child.BackgroundTransparency ~= nil
                            then
                                dOS.Tween.new(
                                    inner_child,
                                    { BackgroundTransparency = 1 },
                                    dOS.TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                                ):Play()
                            end
                        end
                    end

                    preview_elements_ref.elements = nil

                    task.delay(0.2, function()
                        if _current_gen() ~= my_gen then return end

                        dOS.Tween.new(
                            content_container,
                            { Size = UDim2.new(1, -30, 0, 0) },
                            dOS.TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                        ):Play()

                        local card_tween = dOS.Tween.new(
                            card,
                            { Size = UDim2.new(1, 0, 0, 70) },
                            dOS.TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                        )

                        card_tween.OnComplete = function()
                            if _current_gen() ~= my_gen then return end
                            for _, child in ipairs(content_container:GetChildren()) do
                                child:Destroy()
                            end
                        end

                        card_tween:Play()

                        dOS.Tween.new(
                            arrow,
                            { Rotation = 0 },
                            dOS.TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                        ):Play()
                    end)
                end
            end)
        else
            create_control(item, control_area, false)
        end

        return card
    end

    --- SIDEBAR

    local function render_sidebar()
        for _, child in pairs(sidebar:GetChildren()) do
            if child ~= selection_indicator then
                child:Destroy()
            end
        end

        local search_container = dOS.create_gui_element(dOS, "Frame", {
            Parent = sidebar,
            Size = UDim2.new(1, -20, 0, 40),
            Position = UDim2.fromOffset(10, 10),
            BackgroundColor3 = dOS.THEME.TEXT_BOX_DARK,
            BorderSizePixel = 0,
        })
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = search_container,
            CornerRadius = UDim.new(0, 6),
        })

        local search_icon = dOS.create_gui_element(dOS, "ImageLabel", {
            Parent = search_container,
            Image = ICONS.Search,
            Size = UDim2.fromOffset(20, 20),
            Position = UDim2.new(0, 10, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundTransparency = 1,
            ImageColor3 = dOS.THEME.TEXT_DIM,
        })

        dOS.Tween.new(
            search_icon,
            { ImageTransparency = 0.3 },
            dOS.TweenInfo.new(
                1.5,
                Enum.EasingStyle.Sine,
                Enum.EasingDirection.InOut,
                -1,
                true
            )
        ):Play()

        local search_input
        search_input = dOS.create_gui_element(dOS, "TextButton", {
            Parent = search_container,
            Text = state.search_query == "" and "Find a setting" or state.search_query,
            TextColor3 = state.search_query == "" and dOS.THEME.TEXT_DIM or dOS.THEME.TEXT_LIGHT,
            Size = UDim2.new(1, -40, 1, 0),
            Position = UDim2.fromOffset(40, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,

            OnEnter = function()
                dOS.Tween.new(
                    search_container,
                    {
                        BackgroundColor3 = dOS.THEME.BORDER_HIGHLIGHT,
                        BackgroundTransparency = 0.1,
                    },
                    dOS.TweenInfo.new(0.2)
                ):Play()

                dOS.Tween.new(
                    search_icon,
                    {
                        Size = UDim2.fromOffset(24, 24),
                        ImageColor3 = dOS.THEME.TEXT_LIGHT,
                    },
                    dOS.TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                ):Play()

                dOS.Tween.new(
                    search_input,
                    { TextColor3 = dOS.THEME.TEXT_LIGHT },
                    dOS.TweenInfo.new(0.2)
                ):Play()
            end,

            OnLeave = function()
                dOS.Tween.new(
                    search_container,
                    {
                        BackgroundColor3 = dOS.THEME.TEXT_BOX_DARK,
                        BackgroundTransparency = 0,
                    },
                    dOS.TweenInfo.new(0.2)
                ):Play()

                dOS.Tween.new(
                    search_icon,
                    {
                        Size = UDim2.fromOffset(20, 20),
                        ImageColor3 = dOS.THEME.TEXT_DIM,
                    },
                    dOS.TweenInfo.new(0.2)
                ):Play()

                dOS.Tween.new(
                    search_input,
                    {
                        TextColor3 = state.search_query == ""
                            and dOS.THEME.TEXT_DIM
                            or dOS.THEME.TEXT_LIGHT,
                    },
                    dOS.TweenInfo.new(0.2)
                ):Play()
            end,

            OnClick = function()
                dOS.RequestStringAsync(
                    dOS,
                    "Search Settings:",
                    state.search_query,
                    function(query)
                        state.search_query = query or ""
                        render_sidebar()
                        render_content()
                    end
                )
            end,
        })

        local list_start_y = 60
        for _, page in ipairs(PAGES) do
            local is_active = (state.current_page == page.id) and (state.search_query == "")
            local current_button_y = list_start_y

            if is_active and selection_indicator.Position.Y.Offset == -50 then
                selection_indicator.Position = UDim2.fromOffset(10, current_button_y)
            end

            local button = dOS.create_gui_element(dOS, "TextButton", {
                Parent = sidebar,
                Text = "",
                Size = UDim2.new(1, -20, 0, 40),
                Position = UDim2.fromOffset(10, current_button_y),
                BackgroundTransparency = 1,
                ZIndex = 3,
                OnClick = function()
                    if state.current_page == page.id and state.search_query == "" then
                        return
                    end

                    state.current_page = page.id
                    state.search_query = ""

                    local distance = math.abs(
                        selection_indicator.Position.Y.Offset - current_button_y
                    )
                    local duration = math.min(0.3 + (distance * 0.0015), 1)

                    if active_tab_tween then
                        active_tab_tween:Cancel()
                    end

                    active_tab_tween = dOS.Tween.new(
                        selection_indicator,
                        { Position = UDim2.fromOffset(10, current_button_y) },
                        dOS.TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                    )
                    active_tab_tween:Play()

                    render_content()
                end,
            })

            dOS.create_gui_element(dOS, "ImageLabel", {
                Parent = button,
                Image = page.icon,
                Size = UDim2.fromOffset(20, 20),
                Position = UDim2.new(0, 10, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                ImageColor3 = dOS.THEME.TEXT_LIGHT,
                ZIndex = 2,
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = button,
                Text = page.id,
                Size = UDim2.new(1, -50, 1, 0),
                Position = UDim2.fromOffset(40, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundTransparency = 1,
                Font = dOS.FONT_BOLD,
                TextColor3 = dOS.THEME.TEXT_LIGHT,
                ZIndex = 2,
            })

            list_start_y += 45
        end
    end

    --- CONTENT

    render_content = function()
        content_area.CanvasPosition = Vector2.new(0, 0)
        local old_items = {}

        for _, child in pairs(content_area:GetChildren()) do
            if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                table.insert(old_items, child)
            end
        end

        for _, item in ipairs(old_items) do
            animate_out(item, function()
                item:Destroy()
            end)
        end

        state.control_cache = {}

        task.delay(0.3, function()
            for _, child in pairs(content_area:GetChildren()) do
                if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                    child:Destroy()
                end
            end

            local items_to_show = {}

            if state.search_query ~= "" then
                local search_title = dOS.create_gui_element(dOS, "TextLabel", {
                    Parent = content_area,
                    Text = `Search Results for '{state.search_query}'`,
                    Size = UDim2.new(1, 0, 0, 30),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Font = dOS.FONT_BOLD,
                    BackgroundTransparency = 1,
                    TextColor3 = dOS.THEME.TEXT_LIGHT,
                })
                animate_in(search_title, 0)

                local query = state.search_query:lower()
                for _, page in ipairs(PAGES) do
                    for _, page_item in ipairs(page.items) do
                        if
                            page_item.label:lower():find(query)
                            or page_item.desc:lower():find(query)
                        then
                            table.insert(items_to_show, page_item)
                        end
                    end
                end
            else
                local category_title = dOS.create_gui_element(dOS, "TextLabel", {
                    Parent = content_area,
                    Text = state.current_page,
                    Size = UDim2.new(1, 0, 0, 40),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Font = dOS.FONT_BOLD,
                    TextSize = 24,
                    BackgroundTransparency = 1,
                    TextColor3 = dOS.THEME.TEXT_LIGHT,
                })
                animate_in(category_title, 0)

                for _, page in ipairs(PAGES) do
                    if page.id == state.current_page then
                        items_to_show = page.items
                        break
                    end
                end
            end

            local stagger_delay = 0
            for _, page_item in ipairs(items_to_show) do
                local card = render_setting_card(page_item)
                if card then
                    animate_in(card, stagger_delay)
                    stagger_delay += 0.07
                end
            end

            if state.search_query == "" then
                dOS.create_gui_element(dOS, "Frame", {
                    Parent = content_area,
                    Size = UDim2.new(1, 0, 0, 20),
                    BackgroundTransparency = 1,
                })

                local reminder = dOS.create_gui_element(dOS, "TextLabel", {
                    Parent = content_area,
                    Text = "Note: Changes are temporary until you click 'Save & Reboot' in the Power menu.",
                    Size = UDim2.new(1, 0, 0, 30),
                    TextColor3 = dOS.THEME.TEXT_DIM,
                    BackgroundTransparency = 1,
                    TextSize = 12,
                })

                animate_in(reminder, stagger_delay + 0.2)
            end
        end)
    end

    task.spawn(function()
        render_sidebar()
        render_content()
    end)
end

return M

-- EOF