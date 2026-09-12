--[[
    "Audio Player application for dOS"
    
    @module audio_player
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

--- SAVING

function M.save_audio_player_data(dOS)
    if not dOS.disk then
        return
    end

    local data_json, err_enc = JSONEncode(dOS.audio_player_data)
    if data_json then
        dOS.disk:Write(dOS.AUDIO_PLAYER_DISK_FILE, data_json)
        print("[Audio Player] SAVE: Saved audio player data.")
    else
        warn(
            `[Audio Player] SAVE_ERROR: Failed to save audio player data. Error: '{err_enc}'.`
        )
    end
end

function M.load_audio_player_data(dOS)
    if not dOS.disk then
        return
    end

    local data_json = dOS.disk:Read(dOS.AUDIO_PLAYER_DISK_FILE)
    if data_json and type(data_json) == "string" then
        local success_dec, decoded_data = pcall(JSONDecode, data_json)
        if success_dec and decoded_data then
            for key, value in pairs(decoded_data) do
                dOS.audio_player_data[key] = value
            end

            print(
                "[Audio Player] LOAD_DATA: Audio player data loaded successfully."
            )
        end
    end
end

--- API

function M.create(dOS)
    local win_frame, content_area = dOS.create_basic_window(
        dOS,
        "Audio Player",
        650,
        450,
        true,
        true,
        true,
        true,
        500,
        350
    )
    if not win_frame then
        return
    end

    --- STATE

    local state = {
        current_view = "playlists",
        loaded_sound_obj = nil,
        is_paused = false,
        is_looping = false,
        current_song_data = nil,
        update_loop_running = true,

        -- slider state
        is_dragging_scrubber = false,
        dragger_id = nil,

        -- window refs
        settings_window = nil,

        -- optimization
        last_paused_state = nil,
        last_shuffle_state = nil,
        last_loop_state = nil,
    }

    if dOS.audio_player_data.is_shuffle == nil then
        dOS.audio_player_data.is_shuffle = false
    end

    --- UI

    -- left panel (playlists)
    local left_panel = dOS.create_gui_element(dOS, "Frame", {
        Parent = content_area,
        Size = UDim2.new(0, 200, 1, 0),
        BackgroundColor3 = dOS.THEME.CALC_DISPLAY_BG,
        BorderSizePixel = 0,
    })

    local playlist_list = dOS.create_gui_element(dOS, "ScrollingFrame", {
        Parent = left_panel,
        Size = UDim2.new(1, 0, 1, -40),
        Position = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 4,
    })

    dOS.create_gui_element(dOS, "UIPadding", {
        Parent = playlist_list,
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 5),
        PaddingTop = UDim.new(0, 5),
    })

    local back_button = dOS.create_gui_element(dOS, "TextButton", {
        Parent = left_panel,
        Text = "< Playlists",
        Size = UDim2.new(1, -10, 0, 30),
        Position = UDim2.new(0, 5, 1, -35),
        BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
    })

    -- right panel (controls)
    local right_panel = dOS.create_gui_element(dOS, "Frame", {
        Parent = content_area,
        Size = UDim2.new(1, -200, 1, 0),
        Position = UDim2.fromOffset(200, 0),
        BackgroundTransparency = 1,
    })

    dOS.create_gui_element(dOS, "UIListLayout", {
        Parent = right_panel,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
    })

    dOS.create_gui_element(dOS, "UIPadding", {
        Parent = right_panel,
        PaddingTop = UDim.new(0, 20),
        PaddingBottom = UDim.new(0, 20),
        PaddingLeft = UDim.new(0, 20),
        PaddingRight = UDim.new(0, 20),
    })

    -- elements
    local song_title_label = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = right_panel,
        Text = "No Song Playing",
        Size = UDim2.new(1, 0, 0, 40),
        TextSize = dOS.os_settings.global_font_size + 6,
        Font = dOS.FONT_BOLD,
        TextWrapped = true,
        LayoutOrder = 1,
    })

    local time_label = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = right_panel,
        Text = "N/A",
        Size = UDim2.new(1, 0, 0, 20),
        TextColor3 = dOS.THEME.TEXT_DIM,
        LayoutOrder = 2,
    })

    local scrubber_container = dOS.create_gui_element(dOS, "Frame", {
        Parent = right_panel,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        LayoutOrder = 3,
    })

    local controls_frame = dOS.create_gui_element(dOS, "Frame", {
        Parent = right_panel,
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1,
        LayoutOrder = 4,
    })

    dOS.create_gui_element(dOS, "UIListLayout", {
        Parent = controls_frame,
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        Padding = UDim.new(0, 10),
    })

    local options_frame = dOS.create_gui_element(dOS, "Frame", {
        Parent = right_panel,
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        LayoutOrder = 5,
    })

    dOS.create_gui_element(dOS, "UIListLayout", {
        Parent = options_frame,
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        Padding = UDim.new(0, 10),
    })

    local function create_control_button(parent, text, callback, width)
        return dOS.create_gui_element(dOS, "TextButton", {
            Parent = parent,
            Text = text,
            Size = UDim2.fromOffset(width or 50, 40),
            OnClick = callback,
        })
    end

    --- SETTINGS

    local function open_settings_window()
        if state.settings_window and state.settings_window.Parent then
            dOS.set_active_window(dOS, state.settings_window)
            return
        end

        local settings_window, settings_content = dOS.create_basic_window(
            dOS,
            "Playback Settings",
            350,
            220,
            true,
            true,
            false,
            true,
            -1,
            -1
        )
        state.settings_window = settings_window

        dOS.create_gui_element(dOS, "UIListLayout", {
            Parent = settings_content,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 15),
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
        })

        dOS.create_gui_element(dOS, "UIPadding", {
            Parent = settings_content,
            PaddingTop = UDim.new(0, 15),
        })

        local function create_settings_row(
            name,
            min,
            max,
            default_val,
            current_val,
            callback
        )
            local setting_row = dOS.create_gui_element(dOS, "Frame", {
                Parent = settings_content,
                Size = UDim2.new(0.9, 0, 0, 60),
                BackgroundColor3 = dOS.THEME.CALC_DISPLAY_BG,
                BorderColor3 = dOS.THEME.BORDER_HIGHLIGHT,
            })

            dOS.create_gui_element(dOS, "UICorner", {
                Parent = setting_row,
                CornerRadius = UDim.new(0, 8),
            })

            -- top bar: label | value | reset
            local top_bar = dOS.create_gui_element(dOS, "Frame", {
                Parent = setting_row,
                Size = UDim2.new(1, 0, 0, 25),
                BackgroundTransparency = 1,
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = top_bar,
                Text = name,
                Size = UDim2.fromScale(0.5, 1),
                Position = UDim2.fromOffset(5, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                Font = dOS.FONT_BOLD,
            })

            local value_label = dOS.create_gui_element(dOS, "TextLabel", {
                Parent = top_bar,
                Text = tonumber(string.format("%.2f", current_val)),
                Size = UDim2.fromScale(0.3, 1),
                Position = UDim2.fromScale(0.5, 0),
                TextXAlignment = Enum.TextXAlignment.Right,
                TextColor3 = dOS.THEME.ACCENT_BUTTON_BG,
            })

            dOS.create_gui_element(dOS, "TextButton", {
                Parent = top_bar,
                Text = "🗑️",
                Size = UDim2.fromOffset(25, 25),
                Position = UDim2.new(1, -25, 0, 0),
                BackgroundTransparency = 1,
                TextColor3 = dOS.THEME.TEXT_DIM,
                OnClick = function()
                    value_label.Text =
                        tonumber(string.format("%.2f", default_val))
                    callback(default_val)
                end,
            })

            -- bottom bar: min | slider | max
            local bottom_bar = dOS.create_gui_element(dOS, "Frame", {
                Parent = setting_row,
                Size = UDim2.new(1, 0, 0, 30),
                Position = UDim2.fromOffset(0, 30),
                BackgroundTransparency = 1,
            })

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = bottom_bar,
                Text = min,
                Size = UDim2.fromScale(0.15, 1),
                TextColor3 = dOS.THEME.TEXT_DIM,
            })

            -- slider
            local slider_track = dOS.create_slider(
                dOS,
                bottom_bar,
                UDim2.new(0.15, 0, 0.5, -5),
                UDim2.new(0.7, 0, 0, 10),
                min,
                max,
                current_val,
                function(v)
                    value_label.Text = tonumber(string.format("%.2f", v))
                    callback(v)
                end
            )

            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = bottom_bar,
                Text = max,
                Size = UDim2.fromScale(0.15, 1),
                Position = UDim2.fromScale(0.85, 0),
                TextColor3 = dOS.THEME.TEXT_DIM,
            })

            -- hook reset to update slider
            local reset_btn = top_bar:FindFirstChild("TextButton")
            reset_btn.MouseButton1Click:Connect(function()
                local handle = slider_track:FindFirstChild("TextButton")
                if handle then
                    local pct = (default_val - min) / (max - min)
                    handle.Position = UDim2.fromScale(pct, 0.5)
                end
            end)
        end

        create_settings_row(
            "Volume",
            0,
            1,
            0.5,
            dOS.audio_player_data.volume or 0.5,
            function(v)
                dOS.audio_player_data.volume = v
                dOS.speaker.Volume = v
            end
        )

        create_settings_row(
            "Pitch",
            0.1,
            2,
            1.0,
            dOS.audio_player_data.pitch or 1,
            function(v)
                dOS.audio_player_data.pitch = v
                if state.loaded_sound_obj then
                    state.loaded_sound_obj.Pitch = v
                end
            end
        )

        settings_window.Destroying:Connect(function()
            M.save_audio_player_data(dOS)
            state.settings_window = nil
        end)
    end

    --- PLAYBACK

    local play_sound, refresh_view

    local function stop_sound()
        if state.loaded_sound_obj then
            pcall(function()
                state.loaded_sound_obj:Stop()
            end)
            pcall(function()
                state.loaded_sound_obj:Destroy()
            end)
            state.loaded_sound_obj = nil
        end

        if dOS.speaker then
            dOS.speaker:ClearSounds()
        end

        state.is_paused = false
        state.last_paused_state = nil
    end

    local function play_next(show_notification)
        stop_sound()

        local playlist_name = dOS.audio_player_data.current_playlist
        if not playlist_name then
            return
        end

        local playlist = dOS.audio_player_data.playlists[playlist_name]
        if not playlist or #playlist == 0 then
            return
        end

        local index = dOS.audio_player_data.current_song_index
        if dOS.audio_player_data.is_shuffle then
            index = math.random(1, #playlist)
        else
            index += 1
            if index > #playlist then
                index = 1
            end
        end

        dOS.audio_player_data.current_song_index = index

        local song_data = playlist[index]
        if song_data then
            play_sound(song_data, show_notification)
        end
    end

    local function play_prev()
        stop_sound()

        local playlist_name = dOS.audio_player_data.current_playlist
        if not playlist_name then
            return
        end

        local playlist = dOS.audio_player_data.playlists[playlist_name]

        local index = dOS.audio_player_data.current_song_index - 1
        if index < 1 then
            index = #playlist
        end

        dOS.audio_player_data.current_song_index = index

        local song_data = playlist[index]
        if song_data then
            play_sound(song_data)
        end
    end

    -- scrubber track
    local scrubber_track = dOS.create_slider(
        dOS,
        scrubber_container,
        UDim2.new(0, 0, 0.5, -5),
        UDim2.new(1, 0, 0, 10),
        0,
        100,
        0,
        function(val_percent)
            if state.loaded_sound_obj and state.current_song_data then
                local total_len = state.current_song_data.length or 100
                local target_time = (val_percent / 100) * total_len
                state.loaded_sound_obj.TimePosition = target_time
            end
        end
    )

    -- global release detection
    -- if it works one day I LOVE WOS
    -- TODO: spam mawesome to fix this more
    dOS.screen.CursorReleased:Connect(function(cursor)
        if state.is_dragging_scrubber and cursor.UserId == state.dragger_id then
            state.is_dragging_scrubber = false
            state.dragger_id = nil
        end
    end)

    -- local detection
    scrubber_track.MouseButton1Down:Connect(function()
        local cursor = dOS.screen:GetCursor()
        if cursor then
            state.is_dragging_scrubber = true
            state.dragger_id = cursor.UserId
        end
    end)

    scrubber_track.MouseButton1Up:Connect(function()
        state.is_dragging_scrubber = false
    end)

    play_sound = function(song_data, show_notification)
        if not dOS.speaker then
            return
        end

        stop_sound()

        state.current_song_data = song_data
        song_title_label.Text = song_data.title or "Unknown"

        -- reset slider to 0
        local handle = scrubber_track:FindFirstChild("TextButton")
        if handle then
            handle.Position = UDim2.fromScale(0, 0.5)
        end

        local asset_link = "rbxassetid://" .. tostring(song_data.id)
        local sound_obj = dOS.speaker:LoadSound(asset_link)

        if not sound_obj then
            song_title_label.Text = "Error: Failed to Load"
            return
        end

        state.loaded_sound_obj = sound_obj
        sound_obj.Looped = state.is_looping
        sound_obj.Pitch = dOS.audio_player_data.pitch or 1
        dOS.speaker.Volume = dOS.audio_player_data.volume or 0.5
        sound_obj:Play()

        if show_notification then
            dOS.NotificationManager.push(
                dOS,
                "Now Playing...",
                song_data.title or "Unknown",
                2812182644,
                dOS.NotificationManager.GENERIC_SFX.INFO_GENERIC
            )
        end
    end

    --- CONTROL

    create_control_button(controls_frame, "⏮", play_prev)

    local btn_play = create_control_button(controls_frame, "⏸", function()
        if state.loaded_sound_obj then
            if state.is_paused then
                state.loaded_sound_obj:Play()
                state.is_paused = false
            else
                state.loaded_sound_obj:Pause()
                state.is_paused = true
            end
        end
    end)

    create_control_button(controls_frame, "⏹", function()
        stop_sound()
        song_title_label.Text = "Stopped"
        time_label.Text = "N/A"
    end)

    create_control_button(controls_frame, "⏭", function()
        play_next(true)
    end)

    local btn_shuffle = create_control_button(
        options_frame,
        "Shuffle",
        function()
            dOS.audio_player_data.is_shuffle =
                not dOS.audio_player_data.is_shuffle
        end,
        70
    )

    local btn_loop = create_control_button(options_frame, "Loop", function()
        state.is_looping = not state.is_looping
        if state.loaded_sound_obj then
            state.loaded_sound_obj.Looped = state.is_looping
        end
    end, 60)

    create_control_button(options_frame, "⚙", open_settings_window, 40)

    --- RENDER

    task.spawn(function()
        while win_frame.Parent and state.update_loop_running do
            if state.is_paused ~= state.last_paused_state then
                btn_play.Text = state.is_paused and "▶" or "⏸"
                state.last_paused_state = state.is_paused
            end

            if dOS.audio_player_data.is_shuffle ~= state.last_shuffle_state then
                btn_shuffle.BackgroundColor3 = dOS.audio_player_data.is_shuffle
                        and dOS.THEME.ACCENT_BUTTON_HOVER
                    or dOS.THEME.ACCENT_BUTTON_BG
                state.last_shuffle_state = dOS.audio_player_data.is_shuffle
            end

            if state.is_looping ~= state.last_loop_state then
                btn_loop.BackgroundColor3 = state.is_looping
                        and dOS.THEME.ACCENT_BUTTON_HOVER
                    or dOS.THEME.ACCENT_BUTTON_BG
                state.last_loop_state = state.is_looping
            end

            -- timer + slider
            if state.loaded_sound_obj and state.current_song_data then
                local cur = state.loaded_sound_obj.TimePosition
                local max = state.current_song_data.length or 0

                time_label.Text = tonumber(string.format("%.0f", cur))

                if max > 0 and cur >= max - 1 and not state.is_looping then
                    play_next(true)
                end

                -- slider visual if not dragging
                if not state.is_dragging_scrubber then
                    local safe_max = (max > 0) and max or 1
                    local handle = scrubber_track:FindFirstChild("TextButton")
                    if handle then
                        local pct = math.clamp(cur / safe_max, 0, 1)
                        handle.Position = UDim2.fromScale(pct, 0.5)
                    end
                end
            end

            task.wait(0.2)
        end
    end)

    --- VIEW

    refresh_view = function()
        -- clear previous items
        for _, child in pairs(playlist_list:GetChildren()) do
            if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                child:Destroy()
            end
        end

        -- re-add layout
        dOS.create_gui_element(
            dOS,
            "UIListLayout",
            { Parent = playlist_list, Padding = UDim.new(0, 5) }
        )

        -- re-add padding
        dOS.create_gui_element(dOS, "UIPadding", {
            Parent = playlist_list,
            PaddingLeft = UDim.new(0, 10),
            PaddingTop = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 5),
        })

        if state.current_view == "playlists" then
            dOS.create_gui_element(dOS, "TextButton", {
                Parent = playlist_list,
                Text = "+ New Playlist",
                Size = UDim2.new(1, -10, 0, 30),
                TextColor3 = Color3.fromRGB(100, 255, 100),
                OnClick = function()
                    dOS.RequestStringAsync(
                        dOS,
                        "Playlist Name:",
                        "My Playlist",
                        function(name)
                            if
                                name
                                and name ~= ""
                                and not dOS.audio_player_data.playlists[name]
                            then
                                dOS.audio_player_data.playlists[name] = {}
                                M.save_audio_player_data(dOS)
                                refresh_view()
                            end
                        end
                    )
                end,
            })

            for name, _ in pairs(dOS.audio_player_data.playlists) do
                local row = dOS.create_gui_element(dOS, "Frame", {
                    Parent = playlist_list,
                    Size = UDim2.new(1, -10, 0, 30),
                    BackgroundTransparency = 1,
                })

                dOS.create_gui_element(dOS, "TextButton", {
                    Parent = row,
                    Text = name,
                    Size = UDim2.fromScale(0.8, 1),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    OnClick = function()
                        state.current_view = name
                        refresh_view()
                    end,
                })

                dOS.create_gui_element(dOS, "TextButton", {
                    Parent = row,
                    Text = "X",
                    Size = UDim2.fromScale(0.2, 1),
                    Position = UDim2.fromScale(0.8, 0),
                    TextColor3 = Color3.fromRGB(255, 100, 100),
                    OnClick = function()
                        local confirm = dOS.MessageBox.show(dOS, {
                            type = "Default",
                            title = "Confirmation",
                            message = `Delete playlist '{name}' ?`,
                            buttons = { "Yes", "No" },
                            steal_focus = true,
                        })

                        if confirm == "Yes" then
                            dOS.audio_player_data.playlists[name] = nil
                            M.save_audio_player_data(dOS)
                            refresh_view()
                        end
                    end,
                })
            end
        else
            local playlist = dOS.audio_player_data.playlists[state.current_view]

            dOS.create_gui_element(dOS, "TextButton", {
                Parent = playlist_list,
                Text = "+ Add Song",
                Size = UDim2.new(1, -10, 0, 30),
                TextColor3 = Color3.fromRGB(100, 255, 100),
                OnClick = function()
                    dOS.RequestStringAsync(
                        dOS,
                        "Song Title:",
                        "New Song",
                        function(title)
                            dOS.RequestStringAsync(
                                dOS,
                                "Asset ID:",
                                "",
                                function(id)
                                    dOS.RequestNumberAsync(
                                        dOS,
                                        "Length (Sec) [Optional]:",
                                        180,
                                        function(len)
                                            table.insert(
                                                playlist,
                                                {
                                                    title = title,
                                                    id = id,
                                                    length = len,
                                                }
                                            )
                                            M.save_audio_player_data(dOS)
                                            refresh_view()
                                        end
                                    )
                                end
                            )
                        end
                    )
                end,
            })

            for i, song in ipairs(playlist) do
                local row = dOS.create_gui_element(dOS, "Frame", {
                    Parent = playlist_list,
                    Size = UDim2.new(1, -10, 0, 30),
                    BackgroundTransparency = 1,
                })

                dOS.create_gui_element(dOS, "TextButton", {
                    Parent = row,
                    Text = song.title,
                    Size = UDim2.fromScale(0.6, 1),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    OnClick = function()
                        dOS.audio_player_data.current_playlist =
                            state.current_view
                        dOS.audio_player_data.current_song_index = i
                        play_sound(song)
                    end,
                })

                -- edit button
                dOS.create_gui_element(dOS, "TextButton", {
                    Parent = row,
                    Text = "Edit",
                    TextColor3 = Color3.fromRGB(0, 255, 0),
                    Size = UDim2.fromScale(0.2, 1),
                    Position = UDim2.fromScale(0.6, 0),
                    OnClick = function()
                        dOS.RequestStringAsync(
                            dOS,
                            "Edit Title:",
                            song.title,
                            function(new_title)
                                dOS.RequestNumberAsync(
                                    dOS,
                                    "Edit Length:",
                                    song.length or 180,
                                    function(new_length)
                                        song.title = new_title
                                        song.length = new_length
                                        M.save_audio_player_data(dOS)
                                        refresh_view()
                                    end
                                )
                            end
                        )
                    end,
                })

                -- delete button
                dOS.create_gui_element(dOS, "TextButton", {
                    Parent = row,
                    Text = "X",
                    Size = UDim2.fromScale(0.2, 1),
                    Position = UDim2.fromScale(0.8, 0),
                    TextColor3 = Color3.fromRGB(255, 100, 100),
                    OnClick = function()
                        table.remove(playlist, i)
                        M.save_audio_player_data(dOS)
                        refresh_view()
                    end,
                })
            end
        end
    end

    back_button.MouseButton1Click:Connect(function()
        state.current_view = "playlists"
        refresh_view()
    end)

    refresh_view()

    if dOS.audio_player_data.default_playlist_prompt_happened == false then
        dOS.RequestConfirmAsync(
            dOS,
            "Add Default Playlist?",
            true,
            function(yes)
                if yes then
                    dOS.audio_player_data.playlists["Default Playlist"] = {
                        {
                            title = "Candyland",
                            id = 118939739460633,
                            length = 200,
                        },
                        {
                            title = "Paradise Falls",
                            id = 1837879082,
                            length = 162,
                        },
                        {
                            title = "Bossa Me (a)",
                            id = 1837768517,
                            length = 142,
                        },
                        {
                            title = "8-Bit Euphoria",
                            id = 119220775302653,
                            length = 190,
                        },
                        {
                            title = "Chasing 8-Bit Coins",
                            id = 129069266097289,
                            length = 163,
                        },
                        {
                            title = "Lazy Sunday",
                            id = 1842241530,
                            length = 178,
                        },
                        {
                            title = "Raining Tacos",
                            id = 142376088,
                            length = 92,
                        },
                    }
                    dOS.audio_player_data.default_playlist_prompt_happened =
                        true
                    M.save_audio_player_data(dOS)
                    refresh_view()
                end
            end
        )
    end

    win_frame.Destroying:Connect(function()
        stop_sound()
        state.update_loop_running = false
        if state.settings_window and state.settings_window.Parent then
            state.settings_window:Destroy()
        end
    end)
end

return M

-- EOF