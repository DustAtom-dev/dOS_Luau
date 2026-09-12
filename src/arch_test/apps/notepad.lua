--[[
    "Notepad application for dOS"
    
    @module notepad
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

function M.create(dOS, open_file_tab)
    local win_frame, content_area = dOS.create_basic_window(
        dOS,
        "dOS Notepad",
        600,
        500,
        true,
        true,
        true,
        true
    )
    if not win_frame then
        return
    end

    --- STATE

    local disks_connected = {}

    local ui = {
        file_info_label = nil,
    }

    local state = {
        current_disk_id = nil,
        current_path_on_disk = nil,
        is_dirty = false,
        last_saved_text = "",
    }

    local save_file
    local last_edit = nil

    --- UI

    ui.scroll_area = dOS.create_gui_element(dOS, "ScrollingFrame", {
        Parent = content_area,
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 8,
    })

    ui.menu_bar = dOS.create_gui_element(dOS, "ScrollingFrame", {
        Parent = content_area,
        Size = UDim2.new(1, 0, 0, 30),
        ScrollingDirection = Enum.ScrollingDirection.X,
        BackgroundColor3 = dOS.THEME.TITLE_BAR_BG,
    })

    ui.text_area = dOS.create_gui_element(dOS, "TextBox", {
        Parent = ui.scroll_area,
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, 30),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        Text = "",
        TextSize = dOS.os_settings.global_font_size,
        TextScaled = false,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    })

    ui.status_bar = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = content_area,
        Text = "",
        TextSize = dOS.os_settings.global_font_size + 5,
        TextColor3 = Color3.fromRGB(100, 255, 120),
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.new(0, 0, 1, -20),
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundColor3 = dOS.THEME.TASKBAR_BG,
    })

    --- HELPERS

    local function scan_for_disks()
        disks_connected = dOS.HardwareManager.requestNewHardware("Disk", true, true)
    end

    local function findDiskById(id)
        for _, disk in disks_connected do
            if disk.id == id then
                return disk
            end
        end

        warn(`[Notepad->findDiskById]: Failed to find disk with ID {id}.`)
        return {}
    end

    local function update_window_title()
        local file_name = (
            state.current_path_on_disk
            and state.current_path_on_disk:match("([^/]+)$")
        ) or "Untitled"

        local dirty_marker = state.is_dirty and "*" or ""
        ui.file_info_label.Text = file_name .. dirty_marker
    end

    --- FILES

    local function check_for_unsaved_changes(callback_on_safe)
        if not state.is_dirty then
            callback_on_safe()
            return
        end

        dOS.MessageBox.warning(
            dOS,
            "Unsaved Changes",
            "Do you want to save the changes to the current file?",
            {
                {
                    text = "Save",
                    callback = function()
                        save_file(callback_on_safe)
                    end,
                },
                {
                    text = "Don't Save",
                    callback = callback_on_safe,
                },
                {
                    text = "Cancel",
                    callback = function() end,
                },
            }
        )
    end

    local function new_file()
        ui.text_area.Text = ""
        state.current_disk_id = nil
        state.current_path_on_disk = nil
        state.is_dirty = false
        state.last_saved_text = ""
        update_window_title()
    end

    local function open_file()
        dOS.OpenFileDialog({
            mode = "open",
            type = "file",
            callback = function(selection)
                local disk_id, path = selection.disk_id, selection.path_on_disk
                if not disk_id or not path then
                    dOS.MessageBox.error(dOS, "Error", "Invalid file.")
                    return
                end

                scan_for_disks()
                local disk_ref = findDiskById(disk_id).obj
                if not disk_ref then
                    dOS.MessageBox.error(dOS, "Error", "Disk not found.")
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

                local success_read, content = pcall(disk_ref.Read, disk_ref, path)
                if success_read and content then
                    ui.text_area.Text = content
                    state.current_disk_id = disk_id
                    state.current_path_on_disk = path
                    state.is_dirty = false
                    state.last_saved_text = content
                    update_window_title()
                else
                    dOS.MessageBox.error(dOS, "Error", "Could not read file.")
                end
            end,
        })
    end

    local function save_as_file(callback_on_save)
        dOS.OpenFileDialog({
            mode = "save",
            type = "any",
            callback = function(item)
                local function perform_write(disk_id, path, filename)
                    if not disk_id or not path then
                        dOS.NotificationManager.push(
                            dOS,
                            "Notepad",
                            "File not saved: Files can only be saved on a disk.",
                            dOS.NotificationManager.GENERIC_ICONS.ERROR,
                            dOS.NotificationManager.GENERIC_SFX.ERROR
                        )
                        return
                    end

                    scan_for_disks()
                    local disk_ref = findDiskById(disk_id).obj
                    if disk_ref.GUID == dOS.disk.GUID then
                        dOS.NotificationManager.push(
                            dOS,
                            "Notepad",
                            "File not saved: Cannot write to system disk.",
                            dOS.NotificationManager.GENERIC_ICONS.ERROR,
                            dOS.NotificationManager.GENERIC_SFX.ERROR
                        )
                        return
                    end

                    local full_path = (path:sub(-1) == "/")
                            and (path .. filename)
                        or `{path}/{filename}`

                    local to_save
                    if last_edit then
                        to_save = last_edit
                    else
                        logError(
                            "[Notepad] SAVE_ERROR: A filtering error occurred. (last_edit = '"
                                .. tostring(last_edit)
                                .. "')."
                        )
                        dOS.MessageBox.error(
                            dOS,
                            "Error",
                            "A filtering error occurred.\n\nYour file data has NOT been saved."
                        )
                        return
                    end

                    local success_write, err = pcall(disk_ref.Write, disk_ref, full_path, to_save)

                    if success_write then
                        state.current_disk_id = disk_id
                        state.current_path_on_disk = full_path
                        state.is_dirty = false
                        state.last_saved_text = to_save
                        update_window_title()

                        dOS.NotificationManager.push(
                            dOS,
                            "Notepad",
                            "File saved successfully.",
                            dOS.NotificationManager.GENERIC_ICONS.INFO_GENERIC,
                            dOS.NotificationManager.GENERIC_SFX.INFO_GENERIC
                        )

                        if callback_on_save then
                            callback_on_save()
                        end
                    else
                        warn(`[Notepad->save_as_file]: Error, failed to save file, info: '{err}'.`)
                        dOS.NotificationManager.push(
                            dOS,
                            "Notepad",
                            "File not saved: Failed to save file.",
                            dOS.NotificationManager.GENERIC_ICONS.ERROR,
                            dOS.NotificationManager.GENERIC_SFX.ERROR
                        )
                    end
                end

                -- user selected a folder or disk
                if
                    item.type == "folder"
                    or item.type == "disk"
                    or item.is_directory
                then
                    dOS.RequestStringAsync(
                        dOS,
                        "Enter filename:",
                        "untitled.txt",
                        function(name)
                            if name and name ~= "" then
                                perform_write(
                                    item.disk_id,
                                    item.path_on_disk or "/",
                                    name
                                )
                            end
                        end
                    )

                -- user selected an existing file
                else
                    dOS.RequestConfirmAsync(
                        dOS,
                        "Overwrite " .. item.name .. "?",
                        false,
                        function(confirm)
                            if confirm then
                                perform_write(
                                    item.disk_id,
                                    item.path_on_disk,
                                    ""
                                ) -- path already includes name
                            end
                        end
                    )
                end
            end,
        })
    end

    save_file = function(callback_on_save)
        if not state.current_path_on_disk then
            save_as_file(callback_on_save) -- force "Save As" if it's a new file
            return
        end

        local to_save
        local is_filtered = (
            #ui.text_area.Text > 5 and ui.text_area.Text:match("^([#_])%1*$")
        )

        scan_for_disks()
        local disk_ref = findDiskById(state.current_disk_id).obj
        if not disk_ref then
            dOS.MessageBox.error(dOS, "Error", "Original disk not found.")
            return
        end

        if is_filtered then
            if last_edit then
                to_save = last_edit
            else
                logError(
                    "[Notepad] SAVE_ERROR: A filtering error occurred. (ui.text_area.Text got filtered, and last_edit = '"
                        .. tostring(last_edit)
                        .. "')."
                )
                dOS.MessageBox.error(
                    dOS,
                    "Error",
                    "A filtering error occurred.\n\nYour file data has NOT been saved."
                )
                return
            end
        else
            to_save = ui.text_area.Text
        end

        local content = to_save
        local success_write, write_error = pcall(disk_ref.Write, disk_ref, state.current_path_on_disk, content)

        if success_write then
            state.is_dirty = false
            state.last_saved_text = content
            update_window_title()

            if is_filtered then
                dOS.MessageBox.info(
                    dOS,
                    "Information",
                    "It looks like your file was filtered by Roblox.\nWe saved the last unfiltered content available."
                )
            end

            if callback_on_save then
                callback_on_save()
            end
        else
            dOS.MessageBox.error(
                dOS,
                "Error",
                "Failed to write file.\n\nYour file data has NOT been saved."
            )
            warn("[Notepad] SAVE_ERROR: Info: '" .. tostring(write_error) .. "'.")
        end
    end

    local function edit_file()
        dOS.RequestStringAsync(
            dOS,
            "Enter the new content: ",
            "",
            function(new_content_str)
                if new_content_str == "" or new_content_str == nil then
                    return
                end

                if not ui.text_area or not ui.text_area.Text then
                    warn(
                        "[Notepad->edit_file]: The ui.text_area is nowhere to be found! The window has probably been closed."
                    )
                    return
                end

                ui.text_area.Text = new_content_str
                last_edit = new_content_str
            end
        )
    end

    --- MENU

    local menu_x_pos = 5

    local function add_menu_button(text, callback)
        dOS.create_gui_element(dOS, "TextButton", {
            Parent = ui.menu_bar,
            Text = text,
            Size = UDim2.fromOffset(80, 26),
            Position = UDim2.fromOffset(menu_x_pos, 2),
            OnClick = callback,
        })
        menu_x_pos += 85
    end

    -- HACK HACK HACK
    ui.file_info_label = dOS.create_gui_element(dOS, "TextLabel", { -- fileName
        Parent = ui.menu_bar,
        Text = "Untitled",
        Size = UDim2.new(0, 200, 1, 0), -- fixed width so it doesn't break scrolling
        Position = UDim2.fromOffset(menu_x_pos + 390, 0), -- pushed far right on the canvas
        TextColor3 = dOS.THEME.TEXT_DIM,
        TextXAlignment = Enum.TextXAlignment.Right,
        Font = dOS.FONT_REGULAR,
    })

    add_menu_button("New", function()
        check_for_unsaved_changes(new_file)
    end)

    add_menu_button("Open", function()
        check_for_unsaved_changes(open_file)
    end)

    add_menu_button("Edit", edit_file)

    add_menu_button("Save", function()
        save_file(nil)
    end)

    add_menu_button("Save As", function()
        save_as_file(nil)
    end)

    ui.menu_bar.CanvasSize = UDim2.fromOffset(menu_x_pos + 200 - 30, 0)

    --- MAINLOOP

    task.spawn(function()
        while win_frame and win_frame.Parent do
            task.wait(2)

            local line_height = dOS.os_settings.global_font_size - 2

            -- estimate how many chars fit on one line
            if not ui.scroll_area.AbsoluteSize then
                continue
            end

            local chars_per_line = math.floor(
                ui.scroll_area.AbsoluteSize.X
                    / (dOS.os_settings.global_font_size * 0.6)
            )

            local total_lines = 0
            for line in ui.text_area.Text:gmatch("([^\n]*)") do
                total_lines += 1
                -- add extra lines for wrapping
                total_lines += math.floor(#line / chars_per_line)
            end

            local required_height = total_lines * line_height + 20
            local min_height = ui.scroll_area.AbsoluteSize.Y
            local new_height = math.max(required_height, min_height)

            if ui.text_area.AbsoluteSize.Y ~= new_height then
                ui.text_area.Size = UDim2.new(1, 0, 0, new_height)
                ui.scroll_area.CanvasSize = UDim2.fromOffset(0, new_height)
            end

            ui.status_bar.Text = #ui.text_area.Text
            local is_dirty_now = (ui.text_area.Text ~= state.last_saved_text)

            if is_dirty_now ~= state.is_dirty then
                state.is_dirty = is_dirty_now
                update_window_title()
            end
        end

        for _, disk in disks_connected do
            dOS.HardwareManager.freeHardware(disk)
        end
        disks_connected = { nil }
    end)

    --- INIT

    local function open_from_args()
        local disk_id = open_file_tab.disk_id
        local path = open_file_tab.path_on_disk
        if not disk_id or not path then
            dOS.MessageBox.error(dOS, "Error", "Invalid path format.")
            return
        end

        local disk_ref = open_file_tab.ref
        if not disk_ref then
            dOS.MessageBox.error(dOS, "Error", "Disk not found.")
            return
        end

        local success_read, content = pcall(disk_ref.Read, disk_ref, path)
        if success_read and content then
            ui.text_area.Text = content
            state.current_disk_id = disk_id
            state.current_path_on_disk = path
            state.is_dirty = false
            state.last_saved_text = content
            update_window_title()

            -- Pretty print :D
            print("\n")
            local to_print_open =
                `---------------------- FILE '{(state.current_path_on_disk and state.current_path_on_disk:match(
                    "([^/]+)$"
                )) or "Untitled"}' content: ----------------------`
            print(to_print_open)
            print("\n" .. content)
            print("\n")

            local to_print_close = ""
            for _ = 1, #to_print_open do
                to_print_close ..= "-"
            end
            print(to_print_close)
            print("\n")
        else
            dOS.MessageBox.error(dOS, "Error", "Could not read file.")
        end
    end

    if open_file_tab then
        open_from_args()
    end
end

return M

-- EOF