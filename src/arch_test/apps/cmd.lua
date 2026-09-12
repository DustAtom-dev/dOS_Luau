--[[
    "Command-line terminal application for dOS"
    
    @module cmd
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

--- INIT

function M.create(dOS, __Special)
    local win_frame, content_area = dOS.create_basic_window(
        dOS,
        "dOS Command Prompt",
        600,
        400,
        true,
        true,
        true,
        true
    )

    if not win_frame then
        return
    end

    local ui = {}
    local state = {
        output_buffer = {
            "dOS Command-line [Version "
                .. (dOS.os_settings.version or "Unknown")
                .. "]",
            "",
        },
        is_active = true,
        env = { USER = "DefaultUser", PROMPT = "$ " },
    }

    --- RENDER

    ui.scroll_frame = dOS.create_gui_element(dOS, "ScrollingFrame", {
        Parent = content_area,
        Name = "OutputFrame",
        ZIndex = 1,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(10, 10, 15),
        BorderSizePixel = 0,
        ScrollBarThickness = 6,
    })

    local function redraw_output()
        if not win_frame or not win_frame.Parent then
            return
        end

        for _, child in pairs(ui.scroll_frame:GetChildren()) do
            if child.Name == "Line" then
                child:Destroy()
            end
        end

        local line_height = dOS.os_settings.global_font_size + 4
        local y_pos = 5

        for _, line_text in ipairs(state.output_buffer) do
            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = ui.scroll_frame,
                Name = "Line",
                ZIndex = 2,
                Text = line_text,
                TextSize = dOS.os_settings.global_font_size,
                TextColor3 = dOS.THEME.TEXT_LIGHT,
                Font = "Code",
                TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -10, 0, line_height),
                Position = UDim2.fromOffset(5, y_pos),
            })
            y_pos += line_height
        end

        ui.scroll_frame.CanvasSize = UDim2.fromOffset(0, y_pos)
        ui.scroll_frame.CanvasPosition = Vector2.new(0, y_pos)
    end

    --- AUDIO

    local dos_audio_commands = {}

    dos_audio_commands.help = function()
        return "dOS Audio: --play <id>, --pitch <num>, --volume <num>, --stop"
    end

    dos_audio_commands["--play"] = function(args)
        local id = tonumber(args[1])
        if id and dOS.speaker then
            dOS.speaker.Audio = id
            task.wait(0.1)
            dOS.speaker:Trigger()
            return "Playing: " .. id
        else
            return "Usage: --play <ID>"
        end
    end

    dos_audio_commands["--pitch"] = function(args)
        local pitch = tonumber(args[1])
        if pitch and pitch >= 0.5 and pitch <= 2 and dOS.speaker then
            dOS.audio_player_data.pitch = pitch
            dOS.speaker.Pitch = pitch
            __Special.save_audio_player_data(dOS)
            return "Pitch: " .. pitch
        else
            return "Usage: --set <0.5-2.0>"
        end
    end

    dos_audio_commands["--volume"] = function(args)
        local volume = tonumber(args[1])
        if volume and volume >= 0 and volume <= 1 and dOS.speaker then
            dOS.audio_player_data.volume = volume
            dOS.speaker.Volume = volume
            __Special.save_audio_player_data(dOS)
            return "Volume: " .. volume
        else
            return "Usage: --set <0.0-1.0>"
        end
    end

    dos_audio_commands["--stop"] = function()
        if dOS.speaker and dOS.speaker.Audio then
            dOS.speaker.Audio = 0
            dOS.speaker:ClearSounds()
            return "dOS_Audio: Audio stopped."
        else
            return "dOS_Audio: No speaker detected."
        end
    end

    --- COMMANDS

    local commands = {}

    commands.help = function()
        return "dOS Commands: help, cls, echo, set, env, time, dos-audio, reboot, poweroff, run"
    end

    commands.cls = function()
        state.output_buffer = {
            "dOS Command-line [Version "
                .. (dOS.os_settings.version or "Unknown")
                .. "]",
        }
        return ""
    end

    commands.echo = function(args)
        return table.concat(args, " ")
    end

    commands.env = function()
        local lines = {}
        for key, value in pairs(state.env) do
            table.insert(lines, key .. "=" .. tostring(value))
        end
        return table.concat(lines, "\n")
    end

    commands.time = function()
        return os.date("%H:%M:%S")
    end

    commands.reboot = function()
        dOS.rebootOS()
        return ""
    end

    commands.poweroff = function()
        dOS.shutdownOS()
        return ""
    end

    commands.set = function(args)
        local input_str = table.concat(args, " ")
        local var_name, var_value = input_str:match("([%w_]+)%s*=%s*(.*)")
        if var_name and var_value then
            var_value = var_value:match('^"(.*)"$')
                or tonumber(var_value)
                or var_value
            state.env[var_name] = var_value
            return var_name .. " set."
        else
            return "Usage: set <var> = <value>"
        end
    end

    commands["dos-audio"] = function(args)
        if #args == 0 then
            return dos_audio_commands.help()
        end

        local sub_cmd = args[1]:lower()
        if dos_audio_commands[sub_cmd] then
            table.remove(args, 1)
            return dos_audio_commands[sub_cmd](args)
        else
            return "'" .. sub_cmd .. "' is not valid."
        end
    end

    commands.sudo = function(args)
        if
            table.concat(args, " ") == "rm -rf /"
            or table.concat(args, " ") == "rm -rf /*"
        then
            return "Do not even try."
        else
            return "'sudo' is recognized."
        end
    end

    commands.run = function(args)
        if not args[1] then
            return "Usage: run <disk_id:/filename.lua>"
        end

        dOS.setup_fenv_win(dOS, args[1])
        return ""
    end

    --- INPUT

    local function substitute_variables(text)
        return text:gsub(
            "$([%w_]+)",
            function(var_name)
                return tostring(state.env[var_name] or "nil")
            end
        )
    end

    local function parse_and_execute(input_line)
        local substituted_line = substitute_variables(input_line)
        table.insert(
            state.output_buffer,
            state.env["PROMPT"] .. substituted_line
        )

        local args = {}
        for word in string.gmatch(substituted_line, "%S+") do
            table.insert(args, word)
        end

        if #args == 0 then
            redraw_output()
            return
        end

        local command = table.remove(args, 1) or ""
        command = command:lower()
        local result = nil

        if commands[command] then
            result = commands[command](args)
        elseif command ~= "" then
            result = "'" .. command .. "' is not recognized."
        end

        if result then
            for line in string.gmatch(tostring(result), "[^\n]+") do
                table.insert(state.output_buffer, line)
            end
        end

        redraw_output()
    end

    local function start_real_input_loop()
        task.spawn(function()
            while state.is_active and win_frame and win_frame.Parent do
                local connection
                connection = dOS.keyboard.TextInputted:Connect(function(text)
                    if connection then
                        connection:Disconnect()
                    end

                    if
                        state.is_active
                        and dOS.active_window_frame == win_frame
                    then
                        local command_line = text:sub(1, -2)
                        if command_line == "" then
                            redraw_output()
                        else
                            parse_and_execute(command_line)
                        end
                    end

                    if state.is_active then
                        start_real_input_loop()
                    end
                end)
                break
            end
        end)
    end

    win_frame.Destroying:Connect(function()
        state.is_active = false
    end)

    redraw_output()
    start_real_input_loop()
end

return M

-- EOF