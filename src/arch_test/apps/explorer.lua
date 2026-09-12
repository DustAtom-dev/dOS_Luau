--[[
    "File Explorer application for dOS"
    
    @module explorer
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

--- ICONS

M._EXPLORER_TILE_ICONS_IDS = {
    disk_icon = 93227366933047,
    json_file_icon = 72574623675660,
    json_value_icon = 85198288974842,
    folder_icon = 17681660580,
    unknown_icon = 16242403464,
    pin_icon = 82008729089381,
    copy_icon = 90434151822042,
    cut_icon = 122418057501769,
    paste_icon = 129353856287806,
    delete_icon = 17307685486,
    delete_permanent_icon = 18155713435,
    properties_icon = 2772096921,
    new_folder_icon = 16307658016,
    new_file_icon = 16242403464,
    edit_icon = 101708694952341,
    run_icon = 9666526825,
    restore_icon = 77323188719204,
    settings_icon = 9405931578,
}

--- SAVING

function M.save_explorer_data(dOS)
    if not dOS.disk then
        warn(
            "[dOS_Explorer_Debug] SAVE_DATA: No system disk found. Cannot save explorer data."
        )
        return
    end

    local savable_data = {
        trash_contents = {},
        pinned_folders = dOS.explorer_data.pinned_folders or {},
        settings = dOS.explorer_data.settings or {},
    }

    for _, item in ipairs(dOS.explorer_data.trash_contents) do
        table.insert(savable_data.trash_contents, {
            original_disk_id = item.original_disk_id,
            original_path = item.original_path,
            name = item.name,
            is_folder = item.is_folder,
        })
    end

    local success_encode, data_json = pcall(JSONEncode, savable_data)
    if success_encode and data_json then
        local success, err =
            pcall(dOS.disk.Write, dOS.disk, dOS.EXPLORER_DISK_FILE, data_json)
        if success then
            print(
                "[dOS_Explorer_Debug] SAVE_DATA: Explorer data saved successfully."
            )
        else
            print(
                `[dOS_Explorer_Debug] SAVE_DATA: Failed to save explorer data. Error: '{err}'.`
            )
        end
    else
        warn(
            "[dOS_Explorer_Debug] SAVE_DATA: Failed to encode explorer data to JSON."
        )
    end
end

function M.load_explorer_data(dOS)
    if not dOS.disk then
        warn(
            "[dOS_Explorer_Debug] LOAD_DATA: No system disk found. Cannot load explorer data."
        )
        return
    end

    local success_read, data_json =
        pcall(dOS.disk.Read, dOS.disk, dOS.EXPLORER_DISK_FILE)
    if not success_read or not data_json then
        warn(
            "[dOS_Explorer_Debug] LOAD_DATA: No explorer data file found. Using defaults."
        )
        dOS.explorer_data.pinned_folders = dOS.explorer_data.pinned_folders
            or {}
        return
    end

    local success_decode, decoded_data = pcall(JSONDecode, data_json)
    if success_decode and decoded_data then
        if decoded_data.trash_contents then
            dOS.explorer_data.trash_contents = decoded_data.trash_contents
        end
        if decoded_data.pinned_folders then
            dOS.explorer_data.pinned_folders = decoded_data.pinned_folders
        else
            dOS.explorer_data.pinned_folders = {}
        end
        if decoded_data.settings then
            dOS.explorer_data.settings = decoded_data.settings
        end
    else
        warn(
            "[dOS_Explorer_Debug] LOAD_DATA: ERROR - Failed to decode explorer data file. Using defaults."
        )
        dOS.explorer_data.pinned_folders = {}
    end
end

--- API

function M.create(dOS, __Special, fileDialogOptions)
    local win_frame, content_area = dOS.create_basic_window(
        dOS,
        "dOS Explorer",
        700,
        500,
        true,
        true,
        true,
        true
    )
    if not win_frame then
        print("[Explorer] FATAL: create_basic_window failed.")
        return nil
    end

    local disks_connected = { nil }

    local ui = {
        icon_view = nil,
        left_pane = nil,
        address_bar = nil,
        confirm_btn = nil,
        selection_label = nil,
    }

    local state = {
        current_path = "root",
        history = { "root" },
        history_index = 1,
        cached_items = {},
        icon_buttons = {},
        context_menu = nil,
        selected_items = {},
        clipboard = { items = {}, mode = nil },
        last_click_time = 0,
        last_click_item = nil,
        double_click_threshold = 0.5,
        drag_state = {
            is_dragging = false,
            drag_items = {},
            drag_start_pos = nil,
            drag_visual = nil,
            drop_target = nil,
            cursor_released = nil,
            drag_animation_tween = nil,
        },
        selection_rect = {
            is_selecting = false,
            start_pos = nil,
            current_pos = nil,
            rect_visual = nil,
            rect_animation_tween = nil,
        },
        cursor_moved_conn = nil,
    }

    local draw_left_pane, draw_right_pane
    local create_context_menu, close_context_menu, show_properties_window, show_settings_window
    local navigate_to, update_nav_buttons
    local calculate_directory_size, calculate_file_size, format_size
    local copy_items, cut_items, paste_items, move_item
    local start_drag, update_drag, end_drag, start_selection_rect, update_selection_rect, end_selection_rect, update_selection_visuals
    local pin_folder, unpin_folder, is_folder_pinned

    local is_dialog = fileDialogOptions ~= nil
    local bottom_bar_height = is_dialog and 50 or 0

    local top_bar = dOS.create_gui_element(dOS, "Frame", {
        Parent = content_area,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = dOS.THEME.TITLE_BAR_BG,
    })

    local back_button = dOS.create_gui_element(dOS, "TextButton", {
        Parent = top_bar,
        Text = "<",
        Size = UDim2.fromOffset(30, 28),
        Position = UDim2.fromOffset(1, 1),
    })

    local forward_button = dOS.create_gui_element(dOS, "TextButton", {
        Parent = top_bar,
        Text = ">",
        Size = UDim2.fromOffset(30, 28),
        Position = UDim2.fromOffset(33, 1),
    })

    local settings_button = dOS.create_gui_element(dOS, "ImageButton", {
        Parent = top_bar,
        Image = M._EXPLORER_TILE_ICONS_IDS.settings_icon,
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(1, -30, 0, 1),
        BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
        HoverColor = dOS.THEME.ACCENT_BUTTON_HOVER,
    })

    settings_button.MouseButton1Click:Connect(
        function() show_settings_window() end
    )

    ui.address_bar = dOS.create_gui_element(dOS, "TextBox", {
        Parent = top_bar,
        Text = state.current_path,
        TextSize = dOS.os_settings.global_font_size,
        TextScaled = dOS.os_settings.global_text_scaled,
        ClearTextOnFocus = false,
        TextEditable = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.new(1, -102, 0, 28),
        Position = UDim2.fromOffset(70, 1),
        BackgroundTransparency = 1,
    })

    ui.left_pane = dOS.create_gui_element(dOS, "ScrollingFrame", {
        Parent = content_area,
        Size = UDim2.new(0, 150, 1, -30),
        Position = UDim2.fromOffset(0, 30),
        BackgroundColor3 = dOS.THEME.WINDOW_BG,
        BorderSizePixel = 1,
    })

    ui.icon_view = dOS.create_gui_element(dOS, "ScrollingFrame", {
        Parent = content_area,
        Size = UDim2.new(1, -150, 1, -30 - bottom_bar_height),
        Position = UDim2.fromOffset(150, 30),
        BackgroundColor3 = dOS.THEME.DESKTOP_BG,
    })

    if is_dialog then
        local dialog_bar = dOS.create_gui_element(dOS, "Frame", {
            Parent = content_area,
            Size = UDim2.new(1, 0, 0, bottom_bar_height),
            Position = UDim2.new(0, 0, 1, -bottom_bar_height),
            BackgroundColor3 = dOS.THEME.TASKBAR_BG,
            BorderSizePixel = 0,
        })

        local action_text = fileDialogOptions.mode == "save" and "Save"
            or "Open"

        ui.confirm_btn = dOS.create_gui_element(dOS, "TextButton", {
            Parent = dialog_bar,
            Text = action_text,
            Size = UDim2.fromOffset(100, 30),
            Position = UDim2.new(1, -110, 0.5, -15),
            BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
            BackgroundTransparency = 0.5,
            TextColor3 = dOS.THEME.TEXT_DIM,
            OnClick = function()
                if
                    #state.selected_items > 0
                    and ui.confirm_btn.BackgroundTransparency == 0
                then
                    task.spawn(
                        function()
                            fileDialogOptions.callback(state.selected_items[1])
                        end
                    )
                    dOS.Window.close_window(dOS, win_frame)
                end
            end,
        })

        dOS.create_gui_element(dOS, "TextButton", {
            Parent = dialog_bar,
            Text = "Cancel",
            Size = UDim2.fromOffset(80, 30),
            Position = UDim2.new(1, -200, 0.5, -15),
            BackgroundTransparency = 1,
            TextColor3 = dOS.THEME.TEXT_DIM,
            OnClick = function() dOS.Window.close_window(dOS, win_frame) end,
        })

        ui.selection_label = dOS.create_gui_element(dOS, "TextLabel", {
            Parent = dialog_bar,
            Text = "Select an item...",
            Size = UDim2.new(1, -220, 1, 0),
            Position = UDim2.fromOffset(10, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = dOS.THEME.TEXT_LIGHT,
        })
    end

    --- HELPERS

    close_context_menu = function()
        if state.context_menu and state.context_menu.Parent then
            state.context_menu:Destroy()
            state.context_menu = nil
        end
    end

    local function find_cursor_near(x, y, threshold)
        threshold = threshold or 5

        for _, cursor in pairs(dOS.screen:GetCursors()) do
            if
                (Vector2.new(x, y) - Vector2.new(cursor.X, cursor.Y)).Magnitude
                < threshold
            then
                return cursor
            end
        end
        return nil
    end

    local function refresh_connected_disks()
        disks_connected = { nil }
        local letters = {
            "A",
            "B",
            "C",
            "D",
            "E",
            "F",
            "G",
            "H",
            "I",
            "J",
            "K",
            "L",
            "M",
            "N",
            "O",
            "P",
            "Q",
            "R",
            "S",
            "T",
            "U",
            "V",
            "W",
            "X",
            "Y",
            "Z",
        }

        local connected_disks =
            dOS.HardwareManager.requestNewHardware("Disk", true, true)
        for idx, disk_wrapper in ipairs(connected_disks) do
            table.insert(disks_connected, {
                name = if idx <= #letters
                    then letters[idx] .. ":"
                    else `Disk {idx}:`,
                id = idx,
                ref = disk_wrapper.obj,
                old_wrap = disk_wrapper,
            })
        end
    end

    local function find_disk_by_id(id)
        for _, wrapper in disks_connected do
            if wrapper and wrapper.id == id then return wrapper end
        end

        warn(`[Explorer->find_disk_by_id]: Failed to find disk with ID {id}.`)
        return {}
    end

    local function join_path(base, component)
        if base:sub(-1) == "/" then
            return base .. component
        else
            return base .. "/" .. component
        end
    end

    format_size = function(bytes)
        if bytes < 1024 then
            return string.format("%d B", bytes)
        elseif bytes < 1024 ^ 2 then
            return string.format("%.2f KB", bytes / 1024)
        elseif bytes < 1024 ^ 3 then
            return string.format("%.2f MB", bytes / (1024 ^ 2))
        else
            return string.format("%.2f GB", bytes / (1024 ^ 3))
        end
    end

    update_nav_buttons = function()
        back_button.BackgroundColor3 = (state.history_index > 1)
                and dOS.THEME.ACCENT_BUTTON_BG
            or dOS.THEME.CALC_BUTTON_BG
        forward_button.BackgroundColor3 = (state.history_index < #state.history)
                and dOS.THEME.ACCENT_BUTTON_BG
            or dOS.THEME.CALC_BUTTON_BG
    end

    navigate_to = function(path)
        print(
            "[dOS_Explorer_Debug] NAVIGATE: To path '" .. tostring(path) .. "'"
        )
        close_context_menu()

        state.selected_items = {}

        if ui.selection_label then
            ui.selection_label.Text = "Select an item..."
        end
        if ui.confirm_btn then
            ui.confirm_btn.BackgroundTransparency = 0.5
            ui.confirm_btn.TextColor3 = dOS.THEME.TEXT_DIM
        end

        state.current_path = path
        if state.history_index < #state.history then
            for i = #state.history, state.history_index + 1, -1 do
                table.remove(state.history, i)
            end
        end

        table.insert(state.history, path)
        state.history_index = #state.history
        ui.address_bar.Text = path
        draw_left_pane()
        draw_right_pane()
        update_nav_buttons()
    end

    back_button.MouseButton1Click:Connect(function()
        if state.history_index > 1 then
            state.history_index -= 1
            state.current_path = state.history[state.history_index]
            ui.address_bar.Text = state.current_path
            draw_left_pane()
            draw_right_pane()
            update_nav_buttons()
        end
    end)

    forward_button.MouseButton1Click:Connect(function()
        if state.history_index < #state.history then
            state.history_index += 1
            state.current_path = state.history[state.history_index]
            ui.address_bar.Text = state.current_path
            draw_left_pane()
            draw_right_pane()
            update_nav_buttons()
        end
    end)

    --- FILES

    calculate_file_size = function(disk_ref, path)
        local success_read, content = pcall(disk_ref.Read, disk_ref, path)
        if success_read and content then return #tostring(content) end
        return 0
    end

    calculate_directory_size = function(disk_ref, path)
        local total_size = 0
        local success_all, data_read = pcall(disk_ref.ReadAll, disk_ref)

        if not success_all or not data_read then return 0 end

        local search_path = path
        if search_path ~= "/" and not search_path:match("/$") then
            search_path ..= "/"
        end

        for key, value in pairs(data_read) do
            local key_str = tostring(key)

            if
                key_str:find(search_path, 1, true) == 1
                and key_str ~= search_path
            then
                if not key_str:match("/$") then
                    total_size += #tostring(value)
                end
            end
        end

        return total_size
    end

    local function create_json_editor_window(item_info)
        print(
            "[dOS_Explorer_Debug] EDITOR: Opening for key '"
                .. item_info.name
                .. "'"
        )
        local editor_win, editor_content = dOS.create_basic_window(
            dOS,
            "Edit Value",
            350,
            220,
            true,
            true,
            false,
            false
        )
        if not editor_win then return end

        local temp_new_value = "Click here to enter a new value..."
        local y_layout = 10
        local label_x = 10
        local value_x = 120
        local value_width = editor_content.AbsoluteSize.X - 15

        local function create_info_row(key, value_text)
            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = editor_content,
                Text = key,
                Size = UDim2.fromOffset(100, 20),
                Position = UDim2.fromOffset(label_x, y_layout),
                TextXAlignment = Enum.TextXAlignment.Left,
                Font = dOS.FONT_BOLD,
            })
            if type(value_text) ~= "number" then
                value_text = tostring(value_text)
            end
            dOS.create_gui_element(dOS, "TextBox", {
                Parent = editor_content,
                Text = value_text,
                TextSize = dOS.os_settings.global_font_size,
                ClearTextOnFocus = false,
                TextEditable = false,
                TextScaled = dOS.os_settings.global_text_scaled,
                Size = UDim2.fromOffset(value_width, 20),
                Position = UDim2.fromOffset(value_x, y_layout),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
                BackgroundTransparency = 1,
            })
            y_layout += 25
        end

        create_info_row("Key:", item_info.name)
        create_info_row("Current Value:", item_info.value)

        dOS.create_gui_element(dOS, "Frame", {
            Parent = editor_content,
            Size = UDim2.new(1, -20, 0.0075, 1),
            Position = UDim2.fromOffset(10, y_layout),
            BackgroundColor3 = dOS.THEME.BORDER_HIGHLIGHT,
            BorderSizePixel = 0,
        })
        y_layout += 10

        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = editor_content,
            Text = "New Value:",
            Size = UDim2.fromOffset(100, 20),
            Position = UDim2.fromOffset(label_x, y_layout),
            TextXAlignment = Enum.TextXAlignment.Left,
            Font = dOS.FONT_BOLD,
        })
        local new_value_button = dOS.create_gui_element(dOS, "TextButton", {
            Parent = editor_content,
            Text = temp_new_value,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Size = UDim2.fromOffset(value_width, 20),
            Position = UDim2.fromOffset(value_x, y_layout),
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundColor3 = dOS.THEME.SETTINGS_LABEL_BG,
            ClipsDescendants = true,
        })
        y_layout += 40

        new_value_button.MouseButton1Click:Connect(function()
            local prompt = "Enter new value for '" .. item_info.name .. "'"
            if
                type(item_info.value) == "boolean"
                or item_info.value == "false"
                or item_info.value == "true"
            then
                prompt ..= " (1 = true, 0 = false)"
            end

            dOS.RequestStringAsync(
                dOS,
                prompt,
                tostring(temp_new_value),
                function(input_str)
                    if
                        type(item_info.value) == "boolean"
                        or item_info.value == "false"
                        or item_info.value == "true"
                    then
                        temp_new_value = (tonumber(input_str) == 1)
                    elseif type(item_info.value) == "number" then
                        temp_new_value = tonumber(input_str) or item_info.value
                    else
                        temp_new_value = input_str
                    end
                    new_value_button.Text = tostring(temp_new_value)
                end
            )
        end)

        local function save_changes()
            local disk_ref = find_disk_by_id(item_info.disk_id).ref
            if not disk_ref then
                warn(
                    "[Explorer] SAVE_ERROR: Could not save the new value while editing a json key. More info:"
                )
                warn("disk_ref = '" .. tostring(disk_ref) .. "'.")
                return
            end

            local success_read, json_str =
                pcall(disk_ref.Read, disk_ref, item_info.file_path)
            if not success_read then
                warn(
                    "[Explorer] SAVE_ERROR: Could not save the new value while editing a json key. More info:"
                )
                warn(
                    "json_str = '"
                        .. tostring(json_str)
                        .. "' while trying to read path '"
                        .. tostring(item_info.file_path)
                        .. "'."
                )
                return
            end

            local success_decode, data_decoded = pcall(JSONDecode, json_str)
            if not success_decode then
                warn(
                    "[Explorer] SAVE_ERROR: Could not save the new value while editing a json key. More info:"
                )
                warn(
                    "data = '"
                        .. tostring(data_decoded)
                        .. "' while trying to decode json_str '"
                        .. tostring(json_str)
                        .. "'."
                )
                return
            end

            local keys = {}
            for k in item_info.key_path:gmatch("[^/]+") do
                table.insert(keys, k)
            end
            local target_table = data_decoded
            for i = 1, #keys - 1 do
                if target_table then target_table = target_table[keys[i]] end
            end

            if target_table then
                target_table[keys[#keys]] = temp_new_value
                local success_encode, new_json = pcall(JSONEncode, data_decoded)
                if success_encode then
                    local success_write, ret = pcall(
                        disk_ref.Write,
                        disk_ref,
                        item_info.file_path,
                        new_json
                    )
                    if not success_write then
                        warn(
                            "[Explorer] SAVE_ERROR: Could not save the new value while editing a json key. More info:"
                        )
                        warn(
                            tostring(ret)
                                .. "\nWhile trying to write on disk("
                                .. tostring(disk_ref)
                                .. ") with path '"
                                .. tostring(item_info.file_path)
                                .. "'."
                        )
                    end
                    draw_right_pane()
                else
                    warn(
                        "[Explorer] SAVE_ERROR: Could not save the new value while editing a json key. More info:"
                    )
                    warn(
                        "success_encode = '"
                            .. tostring(success_encode)
                            .. "' while trying to encode data ('"
                            .. tostring(data_decoded)
                            .. "') to new_json '"
                            .. tostring(new_json)
                            .. "'."
                    )
                end
            else
                warn(
                    "[Explorer] GMATCH_ERROR: Could not save the new value while editing a json key. More info:"
                )
                warn("target_table = '" .. tostring(target_table) .. "'.")
            end
            dOS.Window.close_window(dOS, editor_win)
        end

        dOS.create_gui_element(dOS, "TextButton", {
            Parent = editor_content,
            Text = "Save",
            Size = UDim2.new(0.5, -15, 0, 30),
            Position = UDim2.new(0, 10, 1, -40),
            OnClick = save_changes,
        })
        dOS.create_gui_element(dOS, "TextButton", {
            Parent = editor_content,
            Text = "Cancel",
            Size = UDim2.new(0.5, -15, 0, 30),
            Position = UDim2.new(0.5, 5, 1, -40),
            OnClick = function() editor_win:Destroy() end,
        })
    end

    local function move_to_trash(item_info)
        if
            not item_info
            or not item_info.disk_id
            or not item_info.path_on_disk
        then
            print(
                "[Explorer] ERROR: move_to_trash called with invalid item_info"
            )
            print(`  disk_id: {item_info and item_info.disk_id or "nil"}`)
            print(
                `  path_on_disk: {item_info and item_info.path_on_disk or "nil"}`
            )
            dOS.MessageBox.error(dOS, "Error", "Invalid item information.")
            return
        end

        local disk_ref = find_disk_by_id(item_info.disk_id).ref
        if not disk_ref then
            dOS.MessageBox.error(dOS, "Error", "Disk not found.")
            return
        end

        if disk_ref.GUID == dOS.disk.GUID then
            dOS.MessageBox.error(
                dOS,
                "Access Denied",
                "Cannot delete files from the system disk."
            )
            return
        end

        if item_info.type == "folder" then
            -- recursively collect descendants and fully wipe them from disk
            local success_all, all_data = pcall(disk_ref.ReadAll, disk_ref)
            if not success_all or not all_data then
                dOS.MessageBox.error(
                    dOS,
                    "Error",
                    "Failed to read disk contents."
                )
                return
            end

            local folder_path = item_info.path_on_disk
            if folder_path:sub(-1) ~= "/" then
                folder_path ..= "/"
            end

            -- gather every key under this folder
            local children = {}
            for key, value in pairs(all_data) do
                local key_str = tostring(key)
                if key_str:find(folder_path, 1, true) == 1 then
                    table.insert(children, { path = key_str, content = value })
                end
            end

            -- store entire subtree in trash
            table.insert(dOS.explorer_data.trash_contents, {
                original_disk_id = item_info.disk_id,
                original_path = item_info.path_on_disk,
                name = item_info.name,
                content = nil,
                is_folder = true,
                children = children,
            })

            -- delete every child, then the folder entry
            for _, child in ipairs(children) do
                pcall(disk_ref.Write, disk_ref, child.path, nil)
            end
            pcall(disk_ref.Write, disk_ref, item_info.path_on_disk, nil)

            print(
                `[Explorer] Moved folder '{item_info.name}' to trash ({#children} child entries deleted)`
            )
        else
            -- regular file
            local success_read, content =
                pcall(disk_ref.Read, disk_ref, item_info.path_on_disk)
            if success_read then
                table.insert(dOS.explorer_data.trash_contents, {
                    original_disk_id = item_info.disk_id,
                    original_path = item_info.path_on_disk,
                    name = item_info.name,
                    content = content,
                    is_folder = false,
                })
                pcall(disk_ref.Write, disk_ref, item_info.path_on_disk, nil)
                print(
                    `[Explorer] Moved '{item_info.name}' to trash successfully`
                )
            else
                print(
                    `[Explorer] ERROR: Failed to read file for trash: {item_info.path_on_disk}`
                )
                dOS.MessageBox.error(dOS, "Error", "Failed to read file.")
                return
            end
        end

        M.save_explorer_data(dOS)
        draw_right_pane()
    end

    local function restore_from_trash(item_info, index)
        local disk_ref = find_disk_by_id(item_info.original_disk_id).ref
        if not disk_ref then
            dOS.MessageBox.error(dOS, "Error", "Original disk not found.")
            return
        end

        if item_info.is_folder then
            -- restore the folder entry itself
            pcall(disk_ref.Write, disk_ref, item_info.original_path, nil)
            -- restore every child
            if item_info.children then
                for _, child in ipairs(item_info.children) do
                    pcall(disk_ref.Write, disk_ref, child.path, child.content)
                end
            end
            table.remove(dOS.explorer_data.trash_contents, index)
            M.save_explorer_data(dOS)
            draw_right_pane()
        else
            local success_write = pcall(
                disk_ref.Write,
                disk_ref,
                item_info.original_path,
                item_info.content
            )
            if success_write then
                table.remove(dOS.explorer_data.trash_contents, index)
                M.save_explorer_data(dOS)
                draw_right_pane()
            else
                dOS.MessageBox.error(dOS, "Error", "Could not restore file.")
            end
        end
    end

    local function create_fs_item(is_folder)
        local disk_id, path_on_disk =
            state.current_path:match("disk(%d+):(/.*)")
        if not disk_id then
            dOS.MessageBox.error(
                dOS,
                "Error",
                "Files can only be created on a disk."
            )
            return
        end

        disk_id = tonumber(disk_id)
        local disk_ref = find_disk_by_id(disk_id).ref
        if not disk_ref then
            dOS.MessageBox.error(dOS, "Error", "Disk not found.")
            return
        end

        if disk_ref.GUID == dOS.disk.GUID then
            dOS.MessageBox.error(
                dOS,
                "Error",
                "Cannot write on the System Disk.\nThis disk is read-only."
            )
            return
        end

        local item_type = is_folder and "folder" or "file"
        dOS.RequestStringAsync(
            dOS,
            "Enter name for new " .. item_type .. ":",
            "New" .. item_type,
            function(name)
                if name and name ~= "" then
                    name = dOS.cleanName(name)
                    if not name or name == "" then return end
                    local final_name = is_folder and name .. "/" or name
                    local full_path = (path_on_disk == "/")
                            and ("/" .. final_name)
                        or join_path(path_on_disk, final_name)

                    local success_write =
                        pcall(disk_ref.Write, disk_ref, full_path, "")
                    if success_write then
                        draw_right_pane()
                    else
                        dOS.MessageBox.error(
                            dOS,
                            "Error",
                            "Failed to create " .. item_type .. "."
                        )
                    end
                end
            end
        )
    end

    copy_items = function()
        if #state.selected_items == 0 then return end

        state.clipboard.items = {}
        state.clipboard.mode = "copy"

        for _, item in ipairs(state.selected_items) do
            table.insert(state.clipboard.items, item)
        end

        print(`[Explorer] Copied {#state.clipboard.items} items to clipboard`)
        draw_right_pane()
    end

    cut_items = function()
        if #state.selected_items == 0 then return end

        state.clipboard.items = {}
        state.clipboard.mode = "cut"

        for _, item in ipairs(state.selected_items) do
            table.insert(state.clipboard.items, item)
        end

        print(`[Explorer] Cut {#state.clipboard.items} items to clipboard`)
        draw_right_pane()
    end

    paste_items = function()
        if #state.clipboard.items == 0 or not state.clipboard.mode then
            return
        end

        local disk_id, target_path = state.current_path:match("disk(%d+):(/.*)")
        if not disk_id then
            dOS.MessageBox.error(
                dOS,
                "Error",
                "Can only paste to a disk location."
            )
            return
        end

        disk_id = tonumber(disk_id)
        local target_disk = find_disk_by_id(disk_id).ref
        if not target_disk then
            dOS.MessageBox.error(dOS, "Error", "Target disk not found.")
            return
        end

        if target_disk.GUID == dOS.disk.GUID then
            dOS.MessageBox.error(dOS, "Error", "Cannot paste to system disk.")
            return
        end

        for _, item in ipairs(state.clipboard.items) do
            local source_disk = find_disk_by_id(item.disk_id).ref
            if source_disk then
                if
                    source_disk.GUID == target_disk.GUID
                    and item.type == "folder"
                then
                    local src_path = item.path_on_disk:sub(-1) == "/"
                            and item.path_on_disk
                        or item.path_on_disk .. "/"
                    local dst_path = target_path:sub(-1) == "/" and target_path
                        or target_path .. "/"

                    if dst_path:find(src_path, 1, true) == 1 then
                        local conflictDecision = dOS.MessageBox.error(
                            dOS,
                            "Error",
                            "Cannot paste a folder into its own subfolder.",
                            { "Skip", "Cancel" },
                            true
                        )

                        if not conflictDecision then break end
                        continue
                    end
                end

                local success_read, content =
                    pcall(source_disk.Read, source_disk, item.path_on_disk)
                if success_read and content then
                    local new_path = join_path(target_path, item.name)
                    if item.type == "folder" then
                        new_path ..= "/"
                    end

                    local success_write =
                        pcall(target_disk.Write, target_disk, new_path, content)
                    if success_write then
                        if state.clipboard.mode == "cut" then
                            pcall(
                                source_disk.Write,
                                source_disk,
                                item.path_on_disk,
                                nil
                            )
                        end
                    end
                end
            end
        end

        if state.clipboard.mode == "cut" then
            state.clipboard.items = {}
            state.clipboard.mode = nil
        end

        draw_right_pane()
    end

    move_item = function(item, target_path)
        if not item or not target_path then return end

        local target_disk_id, target_dir = target_path:match("disk(%d+):(/.*)")
        if not target_disk_id then return end

        target_disk_id = tonumber(target_disk_id)
        local source_disk = find_disk_by_id(item.disk_id).ref
        local target_disk = find_disk_by_id(target_disk_id).ref

        if not source_disk or not target_disk then return end
        if target_disk.GUID == dOS.disk.GUID then
            dOS.MessageBox.error(dOS, "Error", "Cannot move to system disk.")
            return
        end
        if source_disk.GUID == dOS.disk.GUID then
            dOS.MessageBox.error(dOS, "Error", "Cannot move from system disk.")
            return
        end

        local new_path = join_path(target_dir, item.name)
        if item.type == "folder" then
            new_path ..= "/"
        end

        if
            source_disk.GUID == target_disk.GUID
            and item.path_on_disk == new_path
        then
            print(
                `[Explorer] Skipping move - source and destination are identical: {new_path}`
            )
            return
        end

        local success_read, content =
            pcall(source_disk.Read, source_disk, item.path_on_disk)
        if not success_read or not content then
            print(
                `[Explorer] ERROR: Failed to read source file: {item.path_on_disk}`
            )
            return
        end

        local success_write =
            pcall(target_disk.Write, target_disk, new_path, content)
        if success_write then
            pcall(source_disk.Write, source_disk, item.path_on_disk, nil)
            print(
                `[Explorer] Moved '{item.name}' from {item.path_on_disk} to {new_path}`
            )
            draw_right_pane()
        else
            print(
                `[Explorer] ERROR: Failed to write to destination: {new_path}`
            )
            dOS.MessageBox.error(
                dOS,
                "Error",
                "Failed to move file to destination."
            )
        end
    end

    --- PINS

    is_folder_pinned = function(path)
        for _, pinned in ipairs(dOS.explorer_data.pinned_folders) do
            if pinned == path then return true end
        end
        return false
    end

    pin_folder = function(item_info)
        if item_info.type ~= "folder" and item_info.type ~= "disk" then
            dOS.MessageBox.error(dOS, "Error", "Only folders can be pinned.")
            return
        end

        if is_folder_pinned(item_info.path) then
            dOS.MessageBox.error(dOS, "Info", "Folder is already pinned.")
            return
        end

        table.insert(dOS.explorer_data.pinned_folders, item_info.path)
        M.save_explorer_data(dOS)
        draw_left_pane()
    end

    unpin_folder = function(path)
        for i, pinned in ipairs(dOS.explorer_data.pinned_folders) do
            if pinned == path then
                table.remove(dOS.explorer_data.pinned_folders, i)
                M.save_explorer_data(dOS)
                draw_left_pane()
                return
            end
        end
    end

    --- DRAG

    start_drag = function(cursor)
        print(
            `[Explorer] start_drag called with {#state.selected_items} selected items`
        )

        if #state.selected_items == 0 then
            print("[Explorer] ERROR: Cannot start drag - no selected items!")
            return
        end

        if
            state.drag_state.drag_animation_tween
            and state.drag_state.drag_animation_tween.Cancel
        then
            pcall(function() state.drag_state.drag_animation_tween:Cancel() end)
            state.drag_state.drag_animation_tween = nil
        end

        state.drag_state.is_dragging = true
        state.drag_state.drag_items = {}
        state.drag_state.drag_start_pos = Vector2.new(cursor.X, cursor.Y)

        for _, item in ipairs(state.selected_items) do
            table.insert(state.drag_state.drag_items, item)
        end

        local drag_count = #state.drag_state.drag_items
        state.drag_state.drag_visual =
            dOS.create_gui_element(dOS, "RealFrame", {
                Parent = content_area,
                Size = UDim2.fromOffset(60, 60),
                Position = UDim2.fromOffset(
                    cursor.X - content_area.AbsolutePosition.X,
                    cursor.Y - content_area.AbsolutePosition.Y
                ),
                BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
                BackgroundTransparency = 1,
                ZIndex = 1000,
            })
        state.drag_state.drag_visual.BorderSizePixel = 2
        state.drag_state.drag_visual.BorderColor3 = dOS.THEME.ACCENT

        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = state.drag_state.drag_visual,
            Text = drag_count > 1 and tostring(drag_count)
                or state.drag_state.drag_items[1].name:sub(1, 10),
            Size = UDim2.fromScale(1, 1),
            TextColor3 = dOS.THEME.TEXT_LIGHT,
            BackgroundTransparency = 1,
            TextScaled = true,
        })

        if not state.drag_state.drag_visual then
            print("[Explorer] ERROR: Failed to create drag visual!")
            state.drag_state.is_dragging = false
            return
        end

        state.drag_state.drag_animation_tween = dOS.Tween
            .new(
                state.drag_state.drag_visual,
                { BackgroundTransparency = 0.3 },
                dOS.TweenInfo.new(
                    0.25,
                    Enum.EasingStyle.Cubic,
                    Enum.EasingDirection.Out
                )
            )
            :Play()

        task.delay(
            0.25,
            function() state.drag_state.drag_animation_tween = nil end
        )

        print(
            `[Explorer] Started dragging {drag_count} items - visual created successfully`
        )
    end

    update_drag = function(cursor)
        if not state.drag_state.is_dragging then return end

        if not state.drag_state.drag_visual then
            print("[Explorer] ERROR in update_drag: drag_visual is nil!")
            return
        end

        state.drag_state.drag_visual.Position = UDim2.fromOffset(
            cursor.X - content_area.AbsolutePosition.X - 30,
            cursor.Y - content_area.AbsolutePosition.Y - 30
        )

        state.drag_state.drop_target = nil
        local cursor_pos = Vector2.new(cursor.X, cursor.Y)

        for _, child in ipairs(ui.icon_view:GetChildren()) do
            if child:IsA("ImageButton") and child.Name:find("IconBtn_") then
                local is_selected = false
                local item_path = child:GetAttribute("ItemPath")
                if item_path then
                    for _, sel_item in ipairs(state.selected_items) do
                        if sel_item.path == item_path then
                            is_selected = true
                            break
                        end
                    end
                end

                if not is_selected then
                    child.BackgroundTransparency = 1
                else
                    child.BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_HOVER
                    child.BackgroundTransparency = 0.4
                end
            end
        end

        for _, child in ipairs(ui.icon_view:GetChildren()) do
            if child:IsA("ImageButton") and child.Name:find("IconBtn_") then
                local abs_pos = child.AbsolutePosition
                local abs_size = child.AbsoluteSize

                if
                    cursor_pos.X >= abs_pos.X
                    and cursor_pos.X <= abs_pos.X + abs_size.X
                    and cursor_pos.Y >= abs_pos.Y
                    and cursor_pos.Y <= abs_pos.Y + abs_size.Y
                then
                    local item_path = child:GetAttribute("ItemPath")
                    if item_path then
                        for _, item in ipairs(state.cached_items or {}) do
                            if
                                item.path == item_path
                                and (
                                    item.type == "folder"
                                    or item.type == "disk"
                                    or item.type == "json_folder"
                                )
                            then
                                state.drag_state.drop_target = item.path
                                child.BackgroundColor3 = dOS.THEME.ACCENT
                                child.BackgroundTransparency = 0.5
                                break
                            end
                        end
                    end
                    break
                end
            end
        end

        for _, child in ipairs(ui.left_pane:GetChildren()) do
            if child:IsA("TextButton") then
                local abs_pos = child.AbsolutePosition
                local abs_size = child.AbsoluteSize

                if
                    cursor_pos.X >= abs_pos.X
                    and cursor_pos.X <= abs_pos.X + abs_size.X
                    and cursor_pos.Y >= abs_pos.Y
                    and cursor_pos.Y <= abs_pos.Y + abs_size.Y
                then
                    local text = child.Text
                    if text == "Trash Can" then
                        state.drag_state.drop_target = "trash"
                        child.BackgroundColor3 = dOS.THEME.ACCENT
                    elseif text:find("disk") then
                        state.drag_state.drop_target = text
                        child.BackgroundColor3 = dOS.THEME.ACCENT
                    end
                end
            end
        end
    end

    end_drag = function()
        if not state.drag_state.is_dragging then return end

        if
            state.drag_state.drag_animation_tween
            and state.drag_state.drag_animation_tween.Cancel
        then
            pcall(function() state.drag_state.drag_animation_tween:Cancel() end)
            state.drag_state.drag_animation_tween = nil
        end

        if
            state.drag_state.drag_visual and state.drag_state.drag_visual.Parent
        then
            state.drag_state.drag_animation_tween = dOS.Tween
                .new(
                    state.drag_state.drag_visual,
                    { BackgroundTransparency = 1 },
                    dOS.TweenInfo.new(
                        0.2,
                        Enum.EasingStyle.Cubic,
                        Enum.EasingDirection.InOut
                    )
                )
                :Play()

            task.delay(0.2, function()
                state.drag_state.drag_animation_tween = nil
                state.drag_state.drag_visual:Destroy()
                state.drag_state.drag_visual = nil
            end)
        end

        if state.drag_state.drop_target then
            print(
                `[Explorer] Dropping items to: {state.drag_state.drop_target}`
            )
            if state.drag_state.drop_target == "trash" then
                for _, item in ipairs(state.drag_state.drag_items) do
                    if item.type ~= "trash_item" then move_to_trash(item) end
                end
            else
                for _, item in ipairs(state.drag_state.drag_items) do
                    if item.type == "trash_item" then
                        restore_from_trash(item, item.index_in_trash)
                    else
                        move_item(item, state.drag_state.drop_target)
                    end
                end
            end
        elseif state.current_path == "trash" then
            -- dropped with no target inside trash view, restore descending
            local to_restore = {}
            for _, item in ipairs(state.drag_state.drag_items) do
                if item.type == "trash_item" then
                    table.insert(to_restore, item)
                end
            end
            table.sort(
                to_restore,
                function(a, b)
                    return (a.index_in_trash or 0) > (b.index_in_trash or 0)
                end
            )
            for _, item in ipairs(to_restore) do
                restore_from_trash(item, item.index_in_trash)
            end
        elseif state.current_path:match("disk(%d+):(/.*)") then
            print(
                `[Explorer] Dropping items to current directory: {state.current_path}`
            )

            for _, item in ipairs(state.drag_state.drag_items) do
                if item.path:match("(disk%d+:.*/)") == state.current_path then
                    print(
                        `[Explorer] Skipping '{item.name}' - already in current directory`
                    )
                else
                    move_item(item, state.current_path)
                end
            end
        else
            print("[Explorer] Drag cancelled - not in a valid drop location")
        end

        state.drag_state.is_dragging = false
        state.drag_state.drag_items = {}
        state.drag_state.drop_target = nil

        for _, child in ipairs(ui.icon_view:GetChildren()) do
            if child:IsA("ImageButton") and child.Name:find("IconBtn_") then
                local is_selected = false
                local item_path = child:GetAttribute("ItemPath")
                if item_path then
                    for _, sel_item in ipairs(state.selected_items) do
                        if sel_item.path == item_path then
                            is_selected = true
                            break
                        end
                    end
                end

                if not is_selected then child.BackgroundTransparency = 1 end
            end
        end
    end

    --- SELECTION

    start_selection_rect = function(cursor)
        if
            state.selection_rect.rect_animation_tween
            and state.selection_rect.rect_animation_tween.Cancel
        then
            pcall(
                function() state.selection_rect.rect_animation_tween:Cancel() end
            )
            state.selection_rect.rect_animation_tween = nil
        end

        if state.selection_rect.rect_visual then
            state.selection_rect.rect_visual:Destroy()
            state.selection_rect.rect_visual = nil
        end

        for _, child in ipairs(ui.icon_view:GetChildren()) do
            if child.Name == "SelectionRect" then
                pcall(function() child:Destroy() end)
            end
        end

        state.selection_rect.is_selecting = true

        local rel_x = cursor.X
            - ui.icon_view.AbsolutePosition.X
            + ui.icon_view.CanvasPosition.X
        local rel_y = cursor.Y
            - ui.icon_view.AbsolutePosition.Y
            + ui.icon_view.CanvasPosition.Y

        state.selection_rect.start_pos = Vector2.new(rel_x, rel_y)
        state.selection_rect.current_pos = state.selection_rect.start_pos

        state.selection_rect.rect_visual =
            dOS.create_gui_element(dOS, "RealFrame", {
                Name = "SelectionRect",
                Parent = ui.icon_view,
                Size = UDim2.fromOffset(0, 0),
                Position = UDim2.fromOffset(rel_x, rel_y),
                BackgroundColor3 = dOS.THEME.ACCENT,
                BackgroundTransparency = 1,
                BorderSizePixel = 1,
                ZIndex = 100,
            })
        state.selection_rect.rect_visual.BorderColor3 =
            dOS.THEME.ACCENT:Lerp(Color3.new(1, 1, 1), 0.4)

        state.selection_rect.rect_animation_tween = dOS.Tween
            .new(
                state.selection_rect.rect_visual,
                { BackgroundTransparency = 0.7 },
                dOS.TweenInfo.new(
                    0.2,
                    Enum.EasingStyle.Sine,
                    Enum.EasingDirection.Out
                )
            )
            :Play()

        task.delay(
            0.2,
            function() state.selection_rect.rect_animation_tween = nil end
        )

        print("[Explorer] Started selection rectangle")
    end

    update_selection_rect = function(cursor)
        if
            not state.selection_rect.is_selecting
            or not state.selection_rect.rect_visual
        then
            return
        end

        local rel_x = cursor.X
            - ui.icon_view.AbsolutePosition.X
            + ui.icon_view.CanvasPosition.X
        local rel_y = cursor.Y
            - ui.icon_view.AbsolutePosition.Y
            + ui.icon_view.CanvasPosition.Y

        state.selection_rect.current_pos = Vector2.new(rel_x, rel_y)

        local start = state.selection_rect.start_pos
        local current = state.selection_rect.current_pos

        local min_x = math.min(start.X, current.X)
        local min_y = math.min(start.Y, current.Y)
        local max_x = math.max(start.X, current.X)
        local max_y = math.max(start.Y, current.Y)

        state.selection_rect.rect_visual.Position =
            UDim2.fromOffset(min_x, min_y)
        state.selection_rect.rect_visual.Size =
            UDim2.fromOffset(max_x - min_x, max_y - min_y)
    end

    end_selection_rect = function()
        if not state.selection_rect.is_selecting then return end
        state.selection_rect.is_selecting = false

        local function clean_up()
            state.selection_rect.rect_animation_tween = dOS.Tween
                .new(
                    state.selection_rect.rect_visual,
                    { BackgroundTransparency = 1 },
                    dOS.TweenInfo.new(
                        0.15,
                        Enum.EasingStyle.Sine,
                        Enum.EasingDirection.InOut
                    )
                )
                :Play()

            task.delay(0.15, function()
                state.selection_rect.rect_animation_tween = nil
                pcall(function() state.selection_rect.rect_visual:Destroy() end)
                state.selection_rect.rect_visual = nil
            end)
        end
        task.wait()

        if
            state.selection_rect.rect_animation_tween
            and state.selection_rect.rect_animation_tween.Cancel
        then
            pcall(
                function() state.selection_rect.rect_animation_tween:Cancel() end
            )
            state.selection_rect.rect_animation_tween = nil
        end

        local start = state.selection_rect.start_pos
        local current = state.selection_rect.current_pos

        if not start or not current then
            if state.selection_rect.rect_visual then clean_up() end

            state.selection_rect.is_selecting = false
            return
        end

        local min_x = math.min(start.X, current.X)
        local min_y = math.min(start.Y, current.Y)
        local max_x = math.max(start.X, current.X)
        local max_y = math.max(start.Y, current.Y)

        print(
            `[Explorer] Selection rect bounds: ({min_x}, {min_y}) to ({max_x}, {max_y})`
        )

        local newly_selected = {}
        for _, child in ipairs(ui.icon_view:GetChildren()) do
            local ok_isa, is_img_btn = pcall(
                function() return child:IsA("ImageButton") end
            )
            if not ok_isa or not is_img_btn then continue end
            if
                type(child.Name) ~= "string" or not child.Name:find("IconBtn_")
            then
                continue
            end

            local item_x = child.Position.X.Offset
            local item_y = child.Position.Y.Offset
            local item_w = child.AbsoluteSize.X
            local item_h = child.AbsoluteSize.Y

            local overlaps = not (
                item_x + item_w < min_x
                or item_x > max_x
                or item_y + item_h < min_y
                or item_y > max_y
            )

            if overlaps then
                print(
                    `[Explorer] Item at ({item_x}, {item_y}) overlaps with selection rect`
                )
                local ok_attr, item_path = pcall(
                    function() return child:GetAttribute("ItemPath") end
                )
                if ok_attr and item_path then
                    for _, item in ipairs(state.cached_items or {}) do
                        if item and item.path == item_path then
                            table.insert(newly_selected, item)
                            print(`[Explorer] Selected item: {item.name}`)
                            break
                        end
                    end
                end
            end
        end

        state.selected_items = newly_selected
        print(
            `[Explorer] Selection complete: {#state.selected_items} items selected`
        )

        if
            state.selection_rect.rect_visual
            and state.selection_rect.rect_visual.Parent
        then
            clean_up()
        end

        state.selection_rect.is_selecting = false
        state.selection_rect.start_pos = nil
        state.selection_rect.current_pos = nil

        update_selection_visuals()
    end

    update_selection_visuals = function()
        for _, child in ipairs(ui.icon_view:GetChildren()) do
            -- too much pcall is always a good thing
            local ok_isa, is_img_btn = pcall(
                function() return child:IsA("ImageButton") end
            )
            if not ok_isa or not is_img_btn then continue end
            if
                type(child.Name) ~= "string" or not child.Name:find("IconBtn_")
            then
                continue
            end

            local ok_attr, item_path = pcall(
                function() return child:GetAttribute("ItemPath") end
            )
            if not ok_attr or not item_path then continue end

            local is_selected = false
            for _, sel_item in ipairs(state.selected_items) do
                if sel_item and sel_item.path == item_path then
                    is_selected = true
                    break
                end
            end

            local is_cut = false
            if state.clipboard.mode == "cut" then
                for _, clip_item in ipairs(state.clipboard.items) do
                    if clip_item and clip_item.path == item_path then
                        is_cut = true
                        break
                    end
                end
            end

            child.BackgroundColor3 = is_selected
                    and dOS.THEME.ACCENT_BUTTON_HOVER
                or dOS.THEME.ACCENT_BUTTON_BG
            child.BackgroundTransparency = is_selected and 0.4 or 1
            child.BorderSizePixel = is_selected and 1 or 0

            -- NOTE: FindFirstChildOfClass could work but im too lazy to check if available
            local img = nil
            local ok_children, children_list = pcall(
                function() return child:GetChildren() end
            )
            if ok_children and children_list then
                for _, c in ipairs(children_list) do
                    local ok_c, c_is_img = pcall(
                        function() return c:IsA("ImageLabel") end
                    )
                    if ok_c and c_is_img then
                        img = c
                        break
                    end
                end
            end

            if img then
                img.ImageTransparency = is_cut and 0.5 or 0
                img.ImageColor3 = is_cut and Color3.fromRGB(150, 150, 150)
                    or Color3.fromRGB(255, 255, 255)
            else
                pcall(function()
                    child.ImageTransparency = is_cut and 0.5 or 0
                    child.ImageColor3 = is_cut and Color3.fromRGB(150, 150, 150)
                        or Color3.fromRGB(255, 255, 255)
                end)
            end
        end
    end

    --- MENU

    local function rename_item(item_info)
        local disk_ref = find_disk_by_id(item_info.disk_id).ref
        if not disk_ref then
            dOS.MessageBox.error(dOS, "Error", "Disk not found.")
            return
        end
        if disk_ref.GUID == dOS.disk.GUID then
            dOS.MessageBox.error(
                dOS,
                "Error",
                "Cannot rename files on the system disk."
            )
            return
        end
        dOS.RequestStringAsync(
            dOS,
            "Enter new name for '" .. item_info.name .. "':",
            item_info.name,
            function(new_name)
                if not new_name or new_name == "" then return end
                new_name = dOS.cleanName(new_name)
                if
                    not new_name
                    or new_name == ""
                    or new_name == item_info.name
                then
                    return
                end

                local old_path = item_info.path_on_disk
                local is_folder = item_info.type == "folder"
                local clean_old = is_folder and old_path:sub(1, -2) or old_path
                local last_slash = clean_old:match(".*/()")
                local parent_path = (last_slash and last_slash > 2)
                        and clean_old:sub(1, last_slash - 1) .. "/"
                    or "/"
                local new_full = is_folder and (new_name .. "/") or new_name
                local new_path = (parent_path == "/") and ("/" .. new_full)
                    or (parent_path .. new_full)
                if new_path == old_path then return end

                if is_folder then
                    local ok, all_data = pcall(disk_ref.ReadAll, disk_ref)
                    if not ok or not all_data then
                        dOS.MessageBox.error(
                            dOS,
                            "Error",
                            "Failed to read disk."
                        )
                        return
                    end
                    local to_move = {}
                    for key, value in pairs(all_data) do
                        local ks = tostring(key)
                        if ks:find(old_path, 1, true) == 1 then
                            table.insert(
                                to_move,
                                {
                                    old_key = ks,
                                    new_key = new_path .. ks:sub(#old_path + 1),
                                    value = value,
                                }
                            )
                        end
                    end
                    for _, e in ipairs(to_move) do
                        pcall(disk_ref.Write, disk_ref, e.new_key, e.value)
                    end
                    for _, e in ipairs(to_move) do
                        pcall(disk_ref.Write, disk_ref, e.old_key, nil)
                    end
                    pcall(disk_ref.Write, disk_ref, old_path, nil)
                    local old_ep = "disk"
                        .. tostring(item_info.disk_id)
                        .. ":"
                        .. old_path
                    local new_ep = "disk"
                        .. tostring(item_info.disk_id)
                        .. ":"
                        .. new_path
                    if state.current_path:find(old_ep, 1, true) == 1 then
                        state.current_path = new_ep
                            .. state.current_path:sub(#old_ep + 1)
                        ui.address_bar.Text = state.current_path
                    end
                else
                    local ok_r, content =
                        pcall(disk_ref.Read, disk_ref, old_path)
                    if not ok_r then
                        dOS.MessageBox.error(
                            dOS,
                            "Error",
                            "Could not read file."
                        )
                        return
                    end
                    local ok_w =
                        pcall(disk_ref.Write, disk_ref, new_path, content)
                    if not ok_w then
                        dOS.MessageBox.error(
                            dOS,
                            "Error",
                            "Could not write renamed file."
                        )
                        return
                    end
                    pcall(disk_ref.Write, disk_ref, old_path, nil)
                end
                state.selected_items = {}
                draw_right_pane()
            end
        )
    end

    create_context_menu = function(cursor, item_info)
        close_context_menu()
        if not cursor then return end

        local rel_x = cursor.X - content_area.AbsolutePosition.X
        local rel_y = cursor.Y - content_area.AbsolutePosition.Y

        local menu_items = {}

        if item_info then
            if item_info.type ~= "trash_item" then
                if item_info.name and item_info.name:match("%.lua$") then
                    table.insert(menu_items, {
                        text = "Run",
                        icon = M._EXPLORER_TILE_ICONS_IDS.run_icon,
                        callback = function()
                            local ret = dOS.setup_fenv_win(dOS, item_info.path)
                            if ret ~= "" and ret ~= nil then
                                dOS.MessageBox.error(dOS, "Error", ret)
                            end
                        end,
                    })
                end

                if
                    item_info.type ~= "json_folder"
                    and item_info.type ~= "json_key"
                then
                    table.insert(menu_items, {
                        text = "Edit",
                        icon = M._EXPLORER_TILE_ICONS_IDS.edit_icon,
                        callback = function()
                            local to_give = item_info
                            to_give["ref"] =
                                find_disk_by_id(item_info.disk_id).ref
                            __Special.Notepad(dOS, to_give)
                        end,
                    })
                end

                if
                    item_info.type == "file"
                    or item_info.type == "folder"
                    or item_info.type == "json_file"
                then
                    table.insert(menu_items, {
                        text = "Rename",
                        icon = M._EXPLORER_TILE_ICONS_IDS.edit_icon,
                        callback = function() rename_item(item_info) end,
                    })
                end

                if
                    (item_info.name and item_info.name:match("%.lua$"))
                    or (
                        item_info.type ~= "json_folder"
                        and item_info.type ~= "json_key"
                    )
                then
                    table.insert(menu_items, { separator = true } :: any)
                end

                if
                    item_info.type ~= "json_folder"
                    and item_info.type ~= "json_key"
                then
                    table.insert(menu_items, {
                        text = "Copy",
                        icon = M._EXPLORER_TILE_ICONS_IDS.copy_icon,
                        callback = function()
                            if #state.selected_items == 0 then
                                state.selected_items = { item_info }
                            end
                            copy_items()
                        end,
                    })

                    table.insert(menu_items, {
                        text = "Cut",
                        icon = M._EXPLORER_TILE_ICONS_IDS.cut_icon,
                        callback = function()
                            if #state.selected_items == 0 then
                                state.selected_items = { item_info }
                            end
                            cut_items()
                        end,
                    })

                    table.insert(menu_items, { separator = true } :: any)
                end

                if item_info.type == "folder" or item_info.type == "disk" then
                    if is_folder_pinned(item_info.path) then
                        table.insert(menu_items, {
                            text = "Unpin",
                            icon = M._EXPLORER_TILE_ICONS_IDS.pin_icon,
                            callback = function() unpin_folder(item_info.path) end,
                        })
                    else
                        table.insert(menu_items, {
                            text = "Pin",
                            icon = M._EXPLORER_TILE_ICONS_IDS.pin_icon,
                            callback = function() pin_folder(item_info) end,
                        })
                    end
                end
            end

            if item_info.type == "trash_item" then
                table.insert(menu_items, {
                    text = "Restore",
                    icon = M._EXPLORER_TILE_ICONS_IDS.restore_icon,
                    callback = function()
                        local targets = {}
                        for _, sel in ipairs(state.selected_items) do
                            if sel.type == "trash_item" then
                                table.insert(targets, sel)
                            end
                        end
                        if #targets == 0 then
                            table.insert(targets, item_info)
                        end
                        table.sort(
                            targets,
                            function(a, b)
                                return (a.index_in_trash or 0)
                                    > (b.index_in_trash or 0)
                            end
                        )
                        for _, t in ipairs(targets) do
                            restore_from_trash(t, t.index_in_trash)
                        end
                    end,
                })
                table.insert(menu_items, {
                    text = "Delete Permanently",
                    icon = M._EXPLORER_TILE_ICONS_IDS.delete_permanent_icon,
                    callback = function()
                        local targets = {}
                        for _, sel in ipairs(state.selected_items) do
                            if sel.type == "trash_item" then
                                table.insert(targets, sel)
                            end
                        end
                        if #targets == 0 then
                            table.insert(targets, item_info)
                        end
                        table.sort(
                            targets,
                            function(a, b)
                                return (a.index_in_trash or 0)
                                    > (b.index_in_trash or 0)
                            end
                        )
                        for _, t in ipairs(targets) do
                            table.remove(
                                dOS.explorer_data.trash_contents,
                                t.index_in_trash
                            )
                        end
                        state.selected_items = {}
                        M.save_explorer_data(dOS)
                        draw_right_pane()
                    end,
                })
            elseif
                item_info.type ~= "json_folder"
                and item_info.type ~= "json_key"
            then
                table.insert(menu_items, {
                    text = "Move to Trash",
                    icon = M._EXPLORER_TILE_ICONS_IDS.delete_icon,
                    callback = function()
                        if #state.selected_items > 1 then
                            for _, selected_item in ipairs(state.selected_items) do
                                move_to_trash(selected_item)
                            end
                        else
                            move_to_trash(item_info)
                        end
                    end,
                })
            end

            -- only add separator above Properties when other entries exist above it
            local last = menu_items[#menu_items]
            if #menu_items > 0 and not (last and last.separator) then
                table.insert(menu_items, { separator = true } :: any)
            end

            table.insert(menu_items, {
                text = "Properties",
                icon = M._EXPLORER_TILE_ICONS_IDS.properties_icon,
                callback = function() show_properties_window(item_info) end,
            })
        else
            table.insert(menu_items, {
                text = "New Folder",
                icon = M._EXPLORER_TILE_ICONS_IDS.new_folder_icon,
                callback = function() create_fs_item(true) end,
            })
            table.insert(menu_items, {
                text = "New File",
                icon = M._EXPLORER_TILE_ICONS_IDS.new_file_icon,
                callback = function() create_fs_item(false) end,
            })

            if #state.clipboard.items > 0 then
                table.insert(menu_items, { separator = true } :: any)
                table.insert(menu_items, {
                    text = "Paste",
                    icon = M._EXPLORER_TILE_ICONS_IDS.paste_icon,
                    callback = function() paste_items() end,
                })
            end
        end

        local menu_height = 10
        for _, item in ipairs(menu_items) do
            if item.separator then
                menu_height += 8
            else
                menu_height += 32
            end
        end

        local menu = dOS.create_gui_element(dOS, "Frame", {
            Parent = content_area,
            ZIndex = dOS.Z_INDEX.WINDOW_ACTIVE + 5,
            Size = UDim2.fromOffset(200, menu_height),
            Position = UDim2.fromOffset(rel_x, rel_y),
            BackgroundColor3 = dOS.THEME.TASKBAR_BG,
            BorderColor3 = dOS.THEME.BORDER_HIGHLIGHT,
            BorderSizePixel = 1,
            BackgroundTransparency = 1,
        })
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = menu,
            CornerRadius = UDim.new(0, 6),
        })
        state.context_menu = menu

        if dOS.explorer_data.settings.show_animations then
            dOS.Tween
                .new(
                    menu,
                    { BackgroundTransparency = 0.05 },
                    dOS.TweenInfo.new(0.15)
                )
                :Play()
        else
            menu.BackgroundTransparency = 0.05
        end

        local y = 5

        for _, item_data in ipairs(menu_items) do
            if item_data.separator then
                dOS.create_gui_element(dOS, "Frame", {
                    Parent = menu,
                    Size = UDim2.new(1, -10, 0, 1),
                    Position = UDim2.fromOffset(5, y),
                    BackgroundColor3 = dOS.THEME.BORDER_HIGHLIGHT,
                    BorderSizePixel = 0,
                })
                y += 8
            else
                local item_frame = dOS.create_gui_element(dOS, "Frame", {
                    Parent = menu,
                    Size = UDim2.new(1, -6, 0, 28),
                    Position = UDim2.fromOffset(3, y),
                    BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                })

                if item_data.icon then
                    dOS.create_gui_element(dOS, "ImageLabel", {
                        Parent = item_frame,
                        Image = item_data.icon,
                        Size = UDim2.fromOffset(20, 20),
                        Position = UDim2.fromOffset(8, 4),
                        BackgroundTransparency = 1,
                        ImageColor3 = dOS.THEME.TEXT_LIGHT,
                    })
                end

                local btn = dOS.create_gui_element(dOS, "TextButton", {
                    Parent = item_frame,
                    Text = item_data.text,
                    Size = UDim2.fromScale(1, 1),
                    Position = UDim2.fromOffset(36, 0),
                    TextColor3 = dOS.THEME.TEXT_LIGHT,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    BackgroundTransparency = 1,
                    TextSize = dOS.os_settings.global_font_size,
                })

                dOS.HoverManager.register(item_frame, {
                    BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
                    HoverColor = dOS.THEME.ACCENT_BUTTON_HOVER,
                    OnEnter = function()
                        if dOS.explorer_data.settings.show_animations then
                            local tween = dOS.Tween.new(
                                item_frame,
                                { BackgroundTransparency = 0.3 },
                                dOS.TweenInfo.new(0.1)
                            )
                            tween:Play()
                            return tween
                        else
                            item_frame.BackgroundTransparency = 0.3
                        end

                        return nil
                    end,
                    OnLeave = function()
                        if dOS.explorer_data.settings.show_animations then
                            local tween = dOS.Tween.new(
                                item_frame,
                                { BackgroundTransparency = 1 },
                                dOS.TweenInfo.new(0.1)
                            )
                            tween:Play()
                            return tween
                        else
                            item_frame.BackgroundTransparency = 1
                        end

                        return nil
                    end,
                })

                btn.MouseButton1Click:Connect(function()
                    close_context_menu()
                    if item_data.callback then item_data.callback() end
                end)

                y += 32
            end
        end
    end

    show_properties_window = function(item_info)
        print(
            "[dOS_Explorer_Debug] PROPERTIES: Showing for '"
                .. item_info.name
                .. "'"
        )
        local prop_win, prop_content = dOS.create_basic_window(
            dOS,
            "Properties",
            300,
            230,
            true,
            true,
            false,
            false
        )
        if not prop_win then return end

        local y = 10
        local function add_prop(k, v)
            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = prop_content,
                Text = k .. ":",
                Size = UDim2.new(0.3, 0, 0, 20),
                Position = UDim2.fromOffset(10, y),
                TextXAlignment = Enum.TextXAlignment.Left,
                Font = dOS.FONT_BOLD,
            })
            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = prop_content,
                Text = v,
                Size = UDim2.new(0.65, 0, 0, 20),
                Position = UDim2.new(0.3, 5, 0, y),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
            })
            y += 25
        end

        add_prop("Name", item_info.name)
        add_prop("Type", item_info.type)
        add_prop("Path", item_info.path or "N/A")
        add_prop("Date", "Not Implemented")

        local size_val_label = dOS.create_gui_element(dOS, "TextLabel", {
            Parent = prop_content,
            Text = "Calculating...",
            Size = UDim2.new(0.65, 0, 0, 20),
            Position = UDim2.new(0.3, 5, 0, y),
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = prop_content,
            Text = "Size:",
            Size = UDim2.new(0.3, 0, 0, 20),
            Position = UDim2.fromOffset(10, y),
            TextXAlignment = Enum.TextXAlignment.Left,
            Font = dOS.FONT_BOLD,
        })

        task.wait()

        task.spawn(function()
            local size_bytes = 0
            local disk_ref = find_disk_by_id(item_info.disk_id).ref

            if disk_ref then
                if item_info.type == "disk" then
                    size_bytes = calculate_directory_size(disk_ref, "/")
                elseif item_info.type == "folder" then
                    local folder_path = item_info.path:match("disk%d+:(/.*)")
                    if folder_path then
                        size_bytes =
                            calculate_directory_size(disk_ref, folder_path)
                    end
                elseif
                    item_info.type == "file"
                    or item_info.type == "json_file"
                then
                    local file_path = item_info.path:match("disk%d+:(/.*)")
                    if file_path then
                        size_bytes = calculate_file_size(disk_ref, file_path)
                    end
                end
            end

            if size_val_label.Parent then
                size_val_label.Text = format_size(size_bytes)
            end
        end)
    end

    show_settings_window = function()
        local settings_win, settings_content = dOS.create_basic_window(
            dOS,
            "Explorer Settings",
            350,
            185,
            true,
            true,
            false,
            false,
            -1
        )
        if not settings_win then return end

        local y = 15

        local function create_toggle_row(label_text, setting_key)
            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = settings_content,
                Text = label_text,
                Size = UDim2.new(0.6, 0, 0, 25),
                Position = UDim2.fromOffset(15, y),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = dOS.THEME.TEXT_LIGHT,
            })
            local toggle_btn = dOS.create_gui_element(dOS, "TextButton", {
                Parent = settings_content,
                Text = dOS.explorer_data.settings[setting_key] and "ON"
                    or "OFF",
                Size = UDim2.fromOffset(60, 25),
                Position = UDim2.new(1, -75, 0, y),
                BackgroundColor3 = dOS.explorer_data.settings[setting_key]
                        and dOS.THEME.ACCENT
                    or dOS.THEME.CALC_BUTTON_BG,
                TextColor3 = dOS.THEME.TEXT_LIGHT,
            })
            toggle_btn.MouseButton1Click:Connect(function()
                dOS.explorer_data.settings[setting_key] = not (
                    dOS.explorer_data.settings[setting_key] or false
                )
                toggle_btn.Text = dOS.explorer_data.settings[setting_key]
                        and "ON"
                    or "OFF"
                toggle_btn.BackgroundColor3 = dOS.explorer_data.settings[setting_key]
                        and dOS.THEME.ACCENT
                    or dOS.THEME.CALC_BUTTON_BG
                M.save_explorer_data(dOS)
            end)
            y += 35
        end

        create_toggle_row("Show Navigation Animations:", "show_animations")

        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = settings_content,
            Text = "View Mode:",
            Size = UDim2.new(0.6, 0, 0, 25),
            Position = UDim2.fromOffset(15, y),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = dOS.THEME.TEXT_LIGHT,
        })
        local view_btn = dOS.create_gui_element(dOS, "TextButton", {
            Parent = settings_content,
            Text = (dOS.explorer_data.settings.view_mode == "list") and "List"
                or "Grid",
            Size = UDim2.fromOffset(60, 25),
            Position = UDim2.new(1, -75, 0, y),
            BackgroundColor3 = dOS.THEME.ACCENT,
            TextColor3 = dOS.THEME.TEXT_LIGHT,
        })
        view_btn.MouseButton1Click:Connect(function()
            dOS.explorer_data.settings.view_mode = (
                dOS.explorer_data.settings.view_mode == "list"
            )
                    and "grid"
                or "list"
            view_btn.Text = (dOS.explorer_data.settings.view_mode == "list")
                    and "List"
                or "Grid"
            M.save_explorer_data(dOS)
            draw_right_pane()
        end)
        y += 45

        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = settings_content,
            Text = "Settings are auto-saved.",
            Size = UDim2.new(1, -30, 0, 20),
            Position = UDim2.fromOffset(15, y),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextColor3 = dOS.THEME.TEXT_DIM,
        })
    end

    --- RENDERING

    draw_left_pane = function()
        for _, c in pairs(ui.left_pane:GetChildren()) do
            c:Destroy()
        end

        local y = 5

        local function add_nav(text, path)
            dOS.create_gui_element(dOS, "TextButton", {
                Parent = ui.left_pane,
                Text = text,
                Size = UDim2.new(1, -10, 0, 25),
                Position = UDim2.fromOffset(5, y),
                TextXAlignment = Enum.TextXAlignment.Center,
                TextColor3 = Color3.new(1, 1, 1),
                BackgroundColor3 = (state.current_path == path)
                        and dOS.THEME.EXPLORER_NAV_BTN_SELECTED
                    or dOS.THEME.EXPLORER_NAV_BTN,
                BorderColor3 = dOS.THEME.EXPLORER_NAV_BTN_BORDER,
                AutoButtonColor = true,
                OnClick = function() navigate_to(path) end,
            })

            y += 30
        end

        add_nav("My Computer", "root")
        add_nav("Trash Can", "trash")

        local sep = dOS.create_gui_element(dOS, "Frame", {
            Parent = ui.left_pane,
            Size = UDim2.new(1, -10, 0, 1),
            Position = UDim2.fromOffset(5, y),
            BackgroundColor3 = dOS.THEME.BORDER_HIGHLIGHT,
            BorderSizePixel = 0,
        })
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = sep,
            CornerRadius = UDim.new(0, 1),
        })
        y += 5

        if #dOS.explorer_data.pinned_folders > 0 then
            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = ui.left_pane,
                Text = "Pinned",
                Size = UDim2.new(1, -10, 0, 20),
                Position = UDim2.fromOffset(5, y),
                TextXAlignment = Enum.TextXAlignment.Left,
                Font = dOS.FONT_BOLD,
                TextColor3 = dOS.THEME.TEXT_DIM,
                BackgroundTransparency = 1,
            })
            y += 25

            for _, pinned_path in ipairs(dOS.explorer_data.pinned_folders) do
                local name = pinned_path:match("([^/]+)/?$") or pinned_path
                add_nav(name, pinned_path)
            end

            local sepa = dOS.create_gui_element(dOS, "Frame", {
                Parent = ui.left_pane,
                Size = UDim2.new(1, -10, 0, 1),
                Position = UDim2.fromOffset(5, y),
                BackgroundColor3 = dOS.THEME.BORDER_HIGHLIGHT,
                BorderSizePixel = 0,
            })
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = sepa,
                CornerRadius = UDim.new(0, 1),
            })
            y += 5
        end

        refresh_connected_disks()
        for _, d in ipairs(disks_connected) do
            add_nav(d.name, "disk" .. d.id .. ":/")
        end

        ui.left_pane.CanvasSize = UDim2.fromOffset(0, y)
    end

    draw_right_pane = function()
        for _, c in pairs(ui.icon_view:GetChildren()) do
            c:Destroy()
        end
        state.icon_buttons = {}

        local background = dOS.create_gui_element(dOS, "Frame", {
            Parent = ui.icon_view,
            ZIndex = 1,
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = dOS.THEME.DESKTOP_BG,
        })

        background.MouseButton2Up:Connect(function(x, y)
            local c = find_cursor_near(x, y, 5)
            create_context_menu(c, nil)
        end)
        background.MouseButton1Click:Connect(function()
            close_context_menu()
            state.selected_items = {}
            update_selection_visuals()
        end)

        local items_to_draw = {}

        if state.current_path == "root" then
            refresh_connected_disks()
            for _, d in ipairs(disks_connected) do
                table.insert(items_to_draw, {
                    type = "disk",
                    name = d.name,
                    disk_id = d.id,
                    path = `disk{d.id}:/`,
                })
            end
        elseif state.current_path == "trash" then
            for i, item in ipairs(dOS.explorer_data.trash_contents) do
                table.insert(items_to_draw, {
                    type = "trash_item",
                    name = item.name,
                    original_path = item.original_path,
                    original_disk_id = item.original_disk_id,
                    content = item.content,
                    is_folder = item.is_folder,
                    children = item.children,
                    index_in_trash = i,
                    path = "trash:" .. i,
                    disk_id = item.original_disk_id,
                    path_on_disk = item.original_path,
                })
            end
        elseif state.current_path:match("disk(%d+):(/.*)") then
            local disk_id, path_on_disk =
                state.current_path:match("disk(%d+):(/.*)")
            disk_id = tonumber(disk_id)

            local disk_wrap = find_disk_by_id(disk_id)
            local disk_ref = disk_wrap.ref
            if not disk_ref then
                print(
                    `[dOS_Explorer_Debug] DRAW_RIGHT: FAILED to get disk ref for disk {disk_wrap.id}.`
                )
                return
            end

            local json_boundary = path_on_disk:find("%.json")
            if json_boundary then
                local file_path = path_on_disk:sub(1, json_boundary + 4)
                local key_path_raw = path_on_disk:sub(json_boundary + 5)
                local key_path = key_path_raw:gsub("^/", "")

                local success_read, json_content =
                    pcall(disk_ref.Read, disk_ref, file_path)
                if success_read and json_content then
                    local success_decode, data_decoded =
                        pcall(JSONDecode, json_content)
                    if success_decode and type(data_decoded) == "table" then
                        local target_table = data_decoded
                        if key_path and key_path ~= "" then
                            for key_segment in key_path:gmatch("[^/]+") do
                                if type(target_table) ~= "table" then
                                    target_table = nil
                                    break
                                end
                                local key = tonumber(key_segment) or key_segment
                                target_table = target_table[key]
                            end
                        end

                        if type(target_table) == "table" then
                            for key, value in pairs(target_table) do
                                local item_type = (type(value) == "table")
                                        and "json_folder"
                                    or "json_value"
                                local item_key = tostring(key)
                                local composed_key_path = (
                                    key_path == "" and item_key
                                    or (key_path .. "/" .. item_key)
                                )
                                table.insert(items_to_draw, {
                                    type = item_type,
                                    name = item_key,
                                    value = value,
                                    path = join_path(
                                        state.current_path,
                                        item_key
                                    ),
                                    disk_id = disk_id,
                                    file_path = file_path,
                                    key_path = composed_key_path,
                                })
                            end
                        end
                    end
                end
            else
                local success_all, data_read = pcall(disk_ref.ReadAll, disk_ref)
                if success_all and data_read then
                    for key, _ in pairs(data_read) do
                        local key_str = tostring(key)
                        if
                            key_str:find(path_on_disk, 1, true)
                            and key_str ~= path_on_disk
                        then
                            local relative_path = key_str:sub(
                                #path_on_disk + (#path_on_disk > 1 and 1 or 0)
                            )
                            if path_on_disk == "/" then
                                relative_path = key_str:sub(2)
                            end

                            local first_slash = relative_path:find("/")
                            if
                                not first_slash
                                or (
                                    first_slash == #relative_path
                                    and relative_path:sub(-1) == "/"
                                )
                            then
                                local is_folder = (relative_path:sub(-1) == "/")
                                local item_type = is_folder and "folder"
                                    or "file"
                                if
                                    type(key_str) == "string"
                                    and key_str:match("%.json$")
                                then
                                    item_type = "json_file"
                                end

                                local display_name = relative_path:gsub("/", "")
                                table.insert(items_to_draw, {
                                    type = item_type,
                                    name = display_name,
                                    path = "disk"
                                        .. tostring(disk_id)
                                        .. ":"
                                        .. key_str,
                                    path_on_disk = key_str,
                                    disk_id = disk_id,
                                })
                            end
                        end
                    end
                else
                    warn(
                        "[dOS_Explorer_Debug] DRAW_RIGHT: disk:ReadAll() FAILED."
                    )
                end
            end
        else
            warn(
                "[Explorer] INVALID_PATH_OR_MISSING_DRIVE_ERROR: Cannot open path '"
                    .. tostring(state.current_path)
                    .. "'!"
            )
            dOS.MessageBox.error(
                dOS,
                "Error",
                "Cannot open path.\nCheck if the drive is still present or the path is correct."
            )
        end

        local function stop_all_drags()
            state.drag_state.cursor_released = true

            if state.drag_state.is_dragging then end_drag() end
            if state.selection_rect.is_selecting then end_selection_rect() end
        end

        state.cached_items = items_to_draw

        -- constants
        local ICON_SIZE = 80
        local PADDING = 15
        local ROW_H = 28 -- list row height
        local ICON_COL_W = 34 -- icon cell width in list mode
        local HEADER_H = 22
        local DIV_W = 6 -- divider handle width

        local view_mode = dOS.explorer_data.settings.view_mode or "grid"
        local container_width = math.max(20, ui.icon_view.AbsoluteSize.X)

        -- column fractions
        local fracs = dOS.explorer_data.settings.list_col_fracs
        if not fracs or type(fracs) ~= "table" then
            fracs = { name = 0.50, type_col = 0.22 }
            dOS.explorer_data.settings.list_col_fracs = fracs
        end

        -- column width calculator
        local function col_px(cw)
            local avail = math.max(60, cw - ICON_COL_W - PADDING)
            local nw = math.max(40, math.floor(fracs.name * avail))
            local tw = math.max(30, math.floor(fracs.type_col * avail))

            if nw + tw > avail - 30 then tw = math.max(30, avail - nw - 30) end
            local pw = math.max(30, avail - nw - tw)
            return nw, tw, pw
        end

        -- element tables
        local col_ref_list = {}

        -- header refs (nil in grid mode)
        local hdr_name_lbl, hdr_type_lbl, hdr_path_lbl, div1, div2

        -- reposition
        local function reposition_all(cw)
            local nw, tw, pw = col_px(cw)
            local name_x = ICON_COL_W
            local type_x = ICON_COL_W + nw
            local path_x = ICON_COL_W + nw + tw
            -- header
            if hdr_name_lbl then
                hdr_name_lbl.Size = UDim2.fromOffset(nw - DIV_W, HEADER_H)
                hdr_name_lbl.Position = UDim2.fromOffset(name_x, 0)
            end
            if hdr_type_lbl then
                hdr_type_lbl.Size = UDim2.fromOffset(tw - DIV_W, HEADER_H)
                hdr_type_lbl.Position = UDim2.fromOffset(type_x, 0)
            end
            if hdr_path_lbl then
                hdr_path_lbl.Size = UDim2.fromOffset(pw, HEADER_H)
                hdr_path_lbl.Position = UDim2.fromOffset(path_x, 0)
            end
            if div1 then div1.Position = UDim2.fromOffset(type_x - DIV_W, 0) end
            if div2 then div2.Position = UDim2.fromOffset(path_x - DIV_W, 0) end
            -- rows
            for _, r in ipairs(col_ref_list) do
                if r.name_lbl and r.name_lbl.Parent then
                    r.name_lbl.Size = UDim2.fromOffset(nw - DIV_W, ROW_H)
                    r.name_lbl.Position = UDim2.fromOffset(name_x, 0)
                end
                if r.type_lbl and r.type_lbl.Parent then
                    r.type_lbl.Size = UDim2.fromOffset(tw - DIV_W, ROW_H)
                    r.type_lbl.Position = UDim2.fromOffset(type_x, 0)
                end
                if r.path_lbl and r.path_lbl.Parent then
                    r.path_lbl.Size = UDim2.fromOffset(pw, ROW_H)
                    r.path_lbl.Position = UDim2.fromOffset(path_x, 0)
                end
            end
        end

        -- header + dividers
        if view_mode == "list" then
            local nw, tw, pw = col_px(container_width)

            local header = dOS.create_gui_element(dOS, "Frame", {
                Parent = ui.icon_view,
                Name = "ListHeader",
                ZIndex = 10,
                Size = UDim2.new(1, 0, 0, HEADER_H),
                Position = UDim2.fromOffset(0, 0),
                BackgroundColor3 = dOS.THEME.TITLE_BAR_BG,
                BorderSizePixel = 0,
            })

            local function make_hdr_lbl(text, x, w)
                return dOS.create_gui_element(dOS, "TextLabel", {
                    Parent = header,
                    Text = text,
                    Size = UDim2.fromOffset(w, HEADER_H),
                    Position = UDim2.fromOffset(x, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextSize = dOS.os_settings.global_font_size,
                    Font = dOS.FONT_BOLD,
                    BackgroundTransparency = 1,
                    TextColor3 = dOS.THEME.TEXT_LIGHT,
                    ClipsDescendants = true,
                })
            end

            hdr_name_lbl = make_hdr_lbl("Name", ICON_COL_W, nw - DIV_W)
            hdr_type_lbl = make_hdr_lbl("Type", ICON_COL_W + nw, tw - DIV_W)
            hdr_path_lbl = make_hdr_lbl("Path", ICON_COL_W + nw + tw, pw)

            -- draggable divider factory
            -- col_index 1 = Name|Type boundary, 2 = Type|Path boundary
            local function make_divider(init_x, col_index)
                local d = dOS.create_gui_element(dOS, "TextButton", {
                    Parent = header,
                    Text = "",
                    Size = UDim2.fromOffset(DIV_W, HEADER_H),
                    Position = UDim2.fromOffset(init_x - DIV_W, 0),
                    BackgroundColor3 = dOS.THEME.BORDER_HIGHLIGHT,
                    BackgroundTransparency = 0.4,
                    BorderSizePixel = 0,
                    ZIndex = 12,
                    AutoButtonColor = false,
                })

                d.MouseButton1Down:Connect(function(cx, cy)
                    local c = find_cursor_near(cx, cy, 5)
                    if not c then return end

                    -- capture current pixel widths at drag start
                    local cw_now = math.max(20, ui.icon_view.AbsoluteSize.X)
                    local avail = math.max(60, cw_now - ICON_COL_W - PADDING)
                    local nw0, tw0 = col_px(cw_now)
                    local start_cX = c.X
                    local col_conn
                    local released = false

                    col_conn = dOS.screen.CursorMoved:Connect(function(cursor)
                        if cursor.UserId ~= c.UserId then return end
                        local delta = cursor.X - start_cX
                        if col_index == 1 then
                            local new_nw = math.max(
                                40,
                                math.min(nw0 + delta, avail - 30 - 30)
                            )
                            fracs.name = new_nw / avail
                        else
                            local nw_cur =
                                math.max(40, math.floor(fracs.name * avail))
                            local new_tw = math.max(
                                30,
                                math.min(tw0 + delta, avail - nw_cur - 30)
                            )
                            fracs.type_col = new_tw / avail
                        end
                        reposition_all(cw_now)
                    end)

                    local function release()
                        if not released then
                            released = true
                            if col_conn then
                                col_conn:Disconnect()
                                col_conn = nil
                            end
                        end
                    end

                    d.MouseButton1Up:Connect(release)
                    -- safety disconnect if released outside the divider
                    task.spawn(function()
                        task.wait(0.05)
                        while not released do
                            local cursors = dOS.screen:GetCursors()
                            local found = false
                            for _, cu in pairs(cursors) do
                                if cu.UserId == c.UserId then
                                    found = true
                                    break
                                end
                            end
                            if not found then
                                release()
                                break
                            end
                            task.wait(0.05)
                        end
                    end)
                end)

                return d
            end

            div1 = make_divider(ICON_COL_W + nw, 1)
            div2 = make_divider(ICON_COL_W + nw + tw, 2)
        end

        -- item loop
        local x, y =
            PADDING, (view_mode == "list") and (HEADER_H + 2) or PADDING

        for idx, item in ipairs(items_to_draw) do
            local imgID
            if item.type == "disk" then
                imgID = M._EXPLORER_TILE_ICONS_IDS.disk_icon
            elseif item.type == "json_file" then
                imgID = M._EXPLORER_TILE_ICONS_IDS.json_file_icon
            elseif item.type == "json_folder" or item.type == "folder" then
                imgID = M._EXPLORER_TILE_ICONS_IDS.folder_icon
            elseif item.type == "json_value" then
                imgID = M._EXPLORER_TILE_ICONS_IDS.json_value_icon
            else
                imgID = M._EXPLORER_TILE_ICONS_IDS.unknown_icon
            end

            local is_selected = false
            for _, si in ipairs(state.selected_items) do
                if si.path == item.path then
                    is_selected = true
                    break
                end
            end

            local is_cut = false
            if state.clipboard.mode == "cut" then
                for _, ci in ipairs(state.clipboard.items) do
                    if ci.path == item.path then
                        is_cut = true
                        break
                    end
                end
            end

            local icon_btn

            if view_mode == "list" then
                icon_btn = dOS.create_gui_element(dOS, "ImageButton", {
                    Parent = ui.icon_view,
                    Name = "IconBtn_" .. idx,
                    ZIndex = 2,
                    Image = "", -- intentionally blank
                    Size = UDim2.new(1, 0, 0, ROW_H),
                    Position = UDim2.fromOffset(0, y),
                    BackgroundColor3 = is_selected
                            and dOS.THEME.ACCENT_BUTTON_HOVER
                        or dOS.THEME.ACCENT_BUTTON_BG,
                    BackgroundTransparency = is_selected and 0.4 or 1,
                    BorderSizePixel = is_selected and 1 or 0,
                    BorderColor3 = Color3.new(1, 1, 1),
                })
                icon_btn:SetAttribute("ItemPath", item.path)
                state.icon_buttons[item.path] = icon_btn

                -- small icon inside the row
                local icon_img = dOS.create_gui_element(dOS, "ImageLabel", {
                    Parent = icon_btn,
                    Image = imgID,
                    Size = UDim2.fromOffset(20, 20),
                    Position = UDim2.fromOffset(8, (ROW_H - 20) / 2),
                    BackgroundTransparency = 1,
                    ImageTransparency = is_cut and 0.5 or 0,
                    ImageColor3 = is_cut and Color3.fromRGB(150, 150, 150)
                        or Color3.fromRGB(255, 255, 255),
                    ZIndex = 3,
                })
                if dOS.explorer_data.settings.show_animations then
                    icon_img.ImageTransparency = 1
                    dOS.Tween
                        .new(
                            icon_img,
                            { ImageTransparency = is_cut and 0.5 or 0 },
                            dOS.TweenInfo.new(
                                0.12,
                                Enum.EasingStyle.Quad,
                                Enum.EasingDirection.Out,
                                idx * 0.008
                            )
                        )
                        :Play()
                end

                -- text columns
                local nw, tw, pw = col_px(container_width)
                local name_lbl = dOS.create_gui_element(dOS, "TextLabel", {
                    Parent = icon_btn,
                    Text = item.name,
                    Size = UDim2.fromOffset(nw - DIV_W, ROW_H),
                    Position = UDim2.fromOffset(ICON_COL_W, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextSize = dOS.os_settings.global_font_size,
                    BackgroundTransparency = 1,
                    TextColor3 = is_cut and dOS.THEME.TEXT_DIM
                        or dOS.THEME.TEXT_LIGHT,
                    ClipsDescendants = true,
                    ZIndex = 3,
                })
                local type_lbl = dOS.create_gui_element(dOS, "TextLabel", {
                    Parent = icon_btn,
                    Text = item.type,
                    Size = UDim2.fromOffset(tw - DIV_W, ROW_H),
                    Position = UDim2.fromOffset(ICON_COL_W + nw, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextSize = dOS.os_settings.global_font_size,
                    BackgroundTransparency = 1,
                    TextColor3 = dOS.THEME.TEXT_DIM,
                    ClipsDescendants = true,
                    ZIndex = 3,
                })
                local path_lbl = dOS.create_gui_element(dOS, "TextLabel", {
                    Parent = icon_btn,
                    Text = item.path_on_disk or "",
                    Size = UDim2.fromOffset(pw, ROW_H),
                    Position = UDim2.fromOffset(ICON_COL_W + nw + tw, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextSize = math.max(
                        9,
                        dOS.os_settings.global_font_size - 2
                    ),
                    BackgroundTransparency = 1,
                    TextColor3 = dOS.THEME.TEXT_DIM,
                    ClipsDescendants = true,
                    ZIndex = 3,
                })

                table.insert(
                    col_ref_list,
                    {
                        name_lbl = name_lbl,
                        type_lbl = type_lbl,
                        path_lbl = path_lbl,
                    }
                )
            else
                -- grid icon
                icon_btn = dOS.create_gui_element(dOS, "ImageButton", {
                    Parent = ui.icon_view,
                    Name = "IconBtn_" .. idx,
                    ZIndex = 2,
                    Image = imgID,
                    Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
                    Position = UDim2.fromOffset(x, y),
                    BackgroundColor3 = is_selected
                            and dOS.THEME.ACCENT_BUTTON_HOVER
                        or dOS.THEME.ACCENT_BUTTON_BG,
                    BackgroundTransparency = is_selected and 0.4 or 1,
                    BorderSizePixel = is_selected and 1 or 0,
                    BorderColor3 = Color3.new(1, 1, 1),
                    ImageTransparency = 1,
                    ImageColor3 = is_cut and Color3.fromRGB(150, 150, 150)
                        or Color3.fromRGB(255, 255, 255),
                })
                icon_btn:SetAttribute("ItemPath", item.path)
                state.icon_buttons[item.path] = icon_btn

                local target_t = is_cut and 0.5 or 0
                if dOS.explorer_data.settings.show_animations then
                    dOS.Tween
                        .new(
                            icon_btn,
                            { ImageTransparency = target_t },
                            dOS.TweenInfo.new(
                                0.2,
                                Enum.EasingStyle.Quad,
                                Enum.EasingDirection.Out,
                                idx * 0.02
                            )
                        )
                        :Play()
                else
                    icon_btn.ImageTransparency = target_t
                end

                dOS.create_gui_element(dOS, "TextLabel", {
                    Parent = icon_btn,
                    Text = #item.name > 18 and (item.name:sub(1, 16) .. "...")
                        or item.name,
                    Size = UDim2.new(1, 0, 0, 20),
                    Position = UDim2.fromOffset(-2, ICON_SIZE),
                    TextWrapped = true,
                    TextSize = 12,
                    BackgroundTransparency = 1,
                })
            end

            -- events
            icon_btn.MouseButton1Click:Connect(function()
                local now = tick()
                local is_double = (
                    now - state.last_click_time
                        < state.double_click_threshold
                    and state.last_click_item
                    and state.last_click_item.path == item.path
                )
                state.last_click_time = now
                state.last_click_item = item

                if is_dialog then
                    local rt = fileDialogOptions.type or "file"
                    local function upd(si)
                        local valid = (rt == "any" or rt == "both")
                            or (rt == "file" and (si.type == "file" or si.type == "json_file" or si.type == "json_value"))
                            or (
                                rt == "folder"
                                and (
                                    si.type == "folder"
                                    or si.type == "disk"
                                    or si.type == "json_folder"
                                )
                            )
                        ui.confirm_btn.BackgroundTransparency = valid and 0
                            or 0.5
                        ui.confirm_btn.TextColor3 = valid
                                and dOS.THEME.TEXT_LIGHT
                            or dOS.THEME.TEXT_DIM
                    end
                    if
                        is_double
                        and (
                            item.type == "folder"
                            or item.type == "disk"
                            or item.type == "json_folder"
                        )
                    then
                        navigate_to(item.path)
                    else
                        state.selected_items = { item }
                        ui.selection_label.Text = "Selected: " .. item.name
                        update_selection_visuals()
                        upd(item)
                    end
                else
                    if is_double then
                        if
                            item.type == "disk"
                            or item.type == "json_file"
                            or item.type == "json_folder"
                            or item.type == "folder"
                        then
                            navigate_to(item.path)
                        elseif item.type == "json_value" then
                            create_json_editor_window(item)
                        end
                    else
                        state.selected_items = { item }
                        update_selection_visuals()
                    end
                end
            end)

            icon_btn.MouseButton2Up:Connect(function(cx, cy)
                local c = find_cursor_near(cx, cy, 5)
                create_context_menu(c, item)
            end)

            icon_btn.MouseButton1Down:Connect(function(cx, cy)
                stop_all_drags()
                if state.current_path:find("%.json") then return end
                state.drag_state.cursor_released = false
                local c = find_cursor_near(cx, cy, 5)
                if not c then return end

                local ix, iy = c.X, c.Y
                local dx, dy = 0, 0
                local in_sel = false
                for _, si in ipairs(state.selected_items) do
                    if si.path == item.path then
                        in_sel = true
                        break
                    end
                end
                if not in_sel then
                    state.selected_items = { item }
                    update_selection_visuals()
                end

                task.spawn(function()
                    local mc = dOS.screen.CursorMoved:Connect(function(cursor)
                        if cursor.UserId ~= c.UserId then return end
                        dx = math.abs(cursor.X - ix)
                        dy = math.abs(cursor.Y - iy)
                    end)
                    task.wait(0.15)
                    task.wait()
                    if mc then
                        mc:Disconnect()
                        mc = nil
                    end
                    if
                        not state.drag_state.cursor_released
                        and (dx > 10 or dy > 10)
                    then
                        local cur = nil
                        for _, cu in pairs(dOS.screen:GetCursors()) do
                            if cu.UserId == c.UserId then
                                cur = cu
                                break
                            end
                        end
                        if cur then start_drag(cur) end
                    end
                end)
            end)

            icon_btn.MouseButton1Up:Connect(stop_all_drags)

            -- advance layout
            if view_mode == "list" then
                y += ROW_H + 1
            else
                x += ICON_SIZE + PADDING
                if x + ICON_SIZE > container_width then
                    x = PADDING
                    y += ICON_SIZE + PADDING + 20
                end
            end
        end

        if view_mode == "list" then
            ui.icon_view.CanvasSize = UDim2.fromOffset(0, y + 4)
        else
            ui.icon_view.CanvasSize = UDim2.fromOffset(0, y + ICON_SIZE + 20)
        end

        background.MouseButton1Down:Connect(function(cx, cy)
            state.drag_state.cursor_released = false

            -- use the cursor nearest to the background's center for multi cursor support
            local c = find_cursor_near(cx, cy, 5)
            if not c then return end

            local initial_x, initial_y = c.X, c.Y
            local delta_x, delta_y = 0, 0
            local has_started_selection = false

            local mouse_moved_conn = dOS.screen.CursorMoved:Connect(
                function(cursor)
                    if cursor.UserId ~= c.UserId then return end
                    delta_x = math.abs(cursor.X - initial_x)
                    delta_y = math.abs(cursor.Y - initial_y)

                    if
                        not has_started_selection
                        and (delta_x > 35 or delta_y > 35)
                    then
                        stop_all_drags()

                        has_started_selection = true
                        start_selection_rect(cursor)
                    end
                end
            )

            task.spawn(function()
                task.wait(0.3)
                if mouse_moved_conn then
                    mouse_moved_conn:Disconnect()
                    mouse_moved_conn = nil
                end
            end)
        end)

        background.MouseButton1Up:Connect(stop_all_drags)
    end

    if state.cursor_moved_conn then state.cursor_moved_conn:Disconnect() end

    state.cursor_moved_conn = dOS.screen.CursorMoved:Connect(function(cursor)
        if state.drag_state.is_dragging then
            update_drag(cursor)
        elseif state.selection_rect.is_selecting then
            update_selection_rect(cursor)
        end
    end)

    print("[Explorer] Cursor event handlers connected successfully")

    win_frame.Destroying:Connect(function()
        M.save_explorer_data(dOS)
        for _, disk_wrapper in ipairs(disks_connected) do
            dOS.HardwareManager.freeHardware(disk_wrapper)
        end
        disks_connected = { nil }

        if state.cursor_moved_conn then state.cursor_moved_conn:Disconnect() end
        state.cursor_moved_conn = nil
        state.drag_state.cursor_released = nil

        if state.drag_state.is_dragging then end_drag() end

        if state.selection_rect.is_selecting then
            state.selection_rect.is_selecting = false
            if
                state.selection_rect.rect_visual
                and state.selection_rect.rect_visual.Parent
            then
                pcall(function() state.selection_rect.rect_visual:Destroy() end)
            end
            state.selection_rect.rect_visual = nil
        end
    end)

    draw_left_pane()
    draw_right_pane()
    update_nav_buttons()

    return win_frame
end

return M

-- EOF