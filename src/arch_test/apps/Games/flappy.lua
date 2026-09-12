--[[
    "Flappy Bird game for dOS"
    
    @module flappy
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


-- TODO: Do not make it tick based.

local M = {}

--- SAVING

local function save_score(dOS, score)
    if not dOS.disk then
        warn(
            "[Flappy Bird] SAVE_DATA: No system disk found. Cannot save score."
        )
        return false
    end

    local success, err = pcall(
        dOS.disk.Write,
        dOS.disk,
        dOS.GAMES_DATA.GLOBAL_GAMES_DATA_FOLDER
            .. dOS.GAMES_DATA.FLAPPY_BIRD_DISK_FILE,
        tostring(score)
    )

    if success then
        print("[Flappy Bird] SAVE_DATA: Score saved successfully.")
        return true
    else
        warn("[Flappy Bird] SAVE_DATA: Failed to save score. More info:")
        warn("err = '" .. tostring(err) .. "'.")
    end

    return false
end

local function load_score(dOS)
    if not dOS.disk then
        warn(
            "[Flappy Bird] LOAD_DATA: No system disk found. Cannot load score."
        )
        return false
    end

    local success, data = pcall(
        dOS.disk.Read,
        dOS.disk,
        dOS.GAMES_DATA.GLOBAL_GAMES_DATA_FOLDER
            .. dOS.GAMES_DATA.FLAPPY_BIRD_DISK_FILE
    )

    if not success or not data then
        warn("[Flappy Bird] LOAD_DATA: Failed to load score. More info:")
        warn(
            "success = '"
                .. tostring(success)
                .. "'; data = '"
                .. tostring(data)
                .. "'."
        )
        return false
    end

    return tonumber(data)
end

--- API

function M.create(dOS)
    local window_frame, content_area = dOS.create_basic_window(
        dOS,
        "Flappy dOS",
        800,
        600,
        true,
        false,
        false,
        false,
        -1,
        -1
    )

    if not window_frame then return end

    task.spawn(function()
        task.wait(0.6)
        task.wait()
        require("../../core/window").handle_maximize_window(dOS, window_frame)
    end)

    local high_score = load_score(dOS)
    if not high_score then
        warn(
            "[Flappy Bird] LOAD_DATA: Could not load score. high_score = "
                .. tostring(high_score)
        )
        high_score = "Unavailable."
    end

    local game_config = {
        gravity = 0.5,
        jump_velocity = -10,
        bird_x = 80,
        pipe_speed = 5,
        pipe_width = 100,
        pipe_spawn_interval = 120,
        background_speed = 1.5,

        taskbar_height = 35,
        titlebar_height = 35,
        min_pipe_height = 50,
        min_gap = content_area.AbsoluteSize.Y * 0.35,
        max_gap = content_area.AbsoluteSize.Y * 0.99,
        top_pipe_being_longer_than_the_bottom_pipe_probablility = 0.5,
    }

    local asset_ids = {
        bird = 105647529100766,
        pipe_top = 132171476738986,
        pipe_bottom = 123518569270325,
        background = 149868773,
    }

    local game_state = {
        is_active = true,
        is_game_over = true,
        bird_position_y = content_area.AbsoluteSize.Y / 2,
        bird_velocity_y = 0,
        pipes = {},
        score = 0,
        pipe_spawn_timer = 0,
    }

    local ui_elements = {}

    local input_layer = dOS.create_gui_element(dOS, "Frame", {
        Parent = content_area,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
    })

    ui_elements.background_1 = dOS.create_gui_element(dOS, "ImageLabel", {
        Parent = content_area,
        ZIndex = 1,
        Image = asset_ids.background,
        Size = UDim2.new(1, 5, 1, 0),
        Position = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1,
    })

    ui_elements.background_2 = dOS.create_gui_element(dOS, "ImageLabel", {
        Parent = content_area,
        ZIndex = 1,
        Image = asset_ids.background,
        Size = UDim2.new(1, 5, 1, 0),
        Position = UDim2.fromScale(1, 0),
        BackgroundTransparency = 1,
    })

    ui_elements.bird = dOS.create_gui_element(dOS, "ImageLabel", {
        Parent = content_area,
        ZIndex = 3,
        Image = asset_ids.bird,
        Size = UDim2.fromOffset(48, 34),
        Position = UDim2.fromOffset(
            game_config.bird_x,
            game_state.bird_position_y
        ),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
    })

    ui_elements.score_label = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = content_area,
        ZIndex = 4,
        Text = 0,
        Size = UDim2.new(1, 0, 0, 50),
        Position = UDim2.fromOffset(0, 10),
        Font = dOS.FONT_BOLD,
        TextSize = 40,
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        BackgroundTransparency = 1,
    })

    ui_elements.game_over_label = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = content_area,
        ZIndex = 5,
        Text = "Game Over\nRight-Click to Restart",
        Visible = false,
        Size = UDim2.fromScale(1, 1),
        Font = dOS.FONT_BOLD,
        TextSize = 30,
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.5,
    })

    --- HELPERS

    local function reset_game()
        game_state.is_game_over = false
        game_state.bird_position_y = content_area.AbsoluteSize.Y / 2
        game_state.bird_velocity_y = 0
        game_state.score = 0
        game_state.pipe_spawn_timer = 0
        ui_elements.score_label.Text = 0
        ui_elements.game_over_label.Visible = false

        for _, pipe in ipairs(game_state.pipes) do
            pipe.top_pipe:Destroy()
            pipe.bottom_pipe:Destroy()
        end

        game_state.pipes = {}
    end

    local function check_collision(ax, ay, aw, ah, bx, by, bw, bh)
        return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
    end

    --- CONTROL

    input_layer.MouseButton1Up:Connect(function()
        if not game_state.is_game_over then
            game_state.bird_velocity_y = game_config.jump_velocity
        end
    end)

    input_layer.MouseButton2Click:Connect(function()
        if game_state.is_game_over then reset_game() end
    end)

    --- MAINLOOP

    task.spawn(function()
        while game_state.is_active and window_frame and window_frame.Parent do
            if not game_state.is_game_over then
                -- update physics
                game_state.bird_velocity_y += game_config.gravity
                game_state.bird_position_y += game_state.bird_velocity_y
                ui_elements.bird.Position = UDim2.fromOffset(
                    game_config.bird_x,
                    game_state.bird_position_y
                )

                -- scroll bg
                local bg1_pos = ui_elements.background_1.Position
                local bg2_pos = ui_elements.background_2.Position

                ui_elements.background_1.Position = UDim2.new(
                    bg1_pos.X.Scale,
                    bg1_pos.X.Offset - game_config.background_speed,
                    0,
                    0
                )
                ui_elements.background_2.Position = UDim2.new(
                    bg2_pos.X.Scale,
                    bg2_pos.X.Offset - game_config.background_speed,
                    0,
                    0
                )

                if
                    ui_elements.background_1.AbsolutePosition.X
                    <= -ui_elements.background_1.AbsoluteSize.X
                then
                    ui_elements.background_1.Position =
                        UDim2.new(1, -game_config.background_speed * 2, 0, 0)
                end

                if
                    ui_elements.background_2.AbsolutePosition.X
                    <= -ui_elements.background_2.AbsoluteSize.X
                then
                    ui_elements.background_2.Position =
                        UDim2.new(1, -game_config.background_speed * 2, 0, 0)
                end

                -- pipes
                for i = #game_state.pipes, 1, -1 do
                    local pipe = game_state.pipes[i]
                    pipe.x -= game_config.pipe_speed
                    pipe.top_pipe.Position = UDim2.fromOffset(pipe.x, 0)
                    pipe.bottom_pipe.Position = UDim2.new(0, pipe.x, 1, 0)

                    -- check if bird passed the pipe
                    if
                        not pipe.scored
                        and pipe.x + game_config.pipe_width
                            < game_config.bird_x
                    then
                        game_state.score += 1
                        ui_elements.score_label.Text = game_state.score
                        pipe.scored = true
                    end

                    -- despawn pipes
                    if pipe.x < -game_config.pipe_width then
                        pipe.top_pipe:Destroy()
                        pipe.bottom_pipe:Destroy()
                        table.remove(game_state.pipes, i)
                    end
                end

                -- new pipes
                game_state.pipe_spawn_timer += 1
                if
                    game_state.pipe_spawn_timer
                    > game_config.pipe_spawn_interval
                then
                    game_state.pipe_spawn_timer = 0

                    local playable_height = content_area.AbsoluteSize.Y
                    local gap_height =
                        math.random(game_config.min_gap, game_config.max_gap)
                    local pipe_zone_height = playable_height - gap_height
                    local top_pipe_height, bottom_pipe_height

                    if
                        math.random()
                        < game_config.top_pipe_being_longer_than_the_bottom_pipe_probablility
                    then
                        top_pipe_height = math.random(
                            game_config.min_pipe_height,
                            pipe_zone_height - game_config.min_pipe_height
                        )
                        bottom_pipe_height = pipe_zone_height - top_pipe_height
                    else
                        bottom_pipe_height = math.random(
                            game_config.min_pipe_height,
                            pipe_zone_height - game_config.min_pipe_height
                        )
                        top_pipe_height = pipe_zone_height - bottom_pipe_height
                    end

                    local spawn_x = content_area.AbsoluteSize.X

                    local top_pipe = dOS.create_gui_element(dOS, "ImageLabel", {
                        Parent = content_area,
                        ZIndex = 2,
                        Image = asset_ids.pipe_top,
                        Size = UDim2.fromOffset(
                            game_config.pipe_width,
                            top_pipe_height
                        ),
                        Position = UDim2.fromOffset(spawn_x, 0),
                        ScaleType = Enum.ScaleType.Stretch,
                    })

                    local bottom_pipe =
                        dOS.create_gui_element(dOS, "ImageLabel", {
                            Parent = content_area,
                            ZIndex = 2,
                            Image = asset_ids.pipe_bottom,
                            Size = UDim2.fromOffset(
                                game_config.pipe_width,
                                bottom_pipe_height
                            ),
                            Position = UDim2.fromOffset(
                                spawn_x,
                                playable_height
                            ),
                            AnchorPoint = Vector2.new(0, 1),
                            ScaleType = Enum.ScaleType.Stretch,
                        })

                    table.insert(game_state.pipes, {
                        top_pipe = top_pipe,
                        bottom_pipe = bottom_pipe,
                        x = spawn_x,
                        scored = false,
                    })
                end

                -- border collision
                local bird_abs_pos = ui_elements.bird.AbsolutePosition
                local bird_abs_size = ui_elements.bird.AbsoluteSize
                local bird_bounds = {
                    x = bird_abs_pos.X,
                    y = bird_abs_pos.Y,
                    width = bird_abs_size.X,
                    height = bird_abs_size.Y,
                }

                if
                    bird_bounds.y < game_config.titlebar_height
                    or bird_bounds.y + bird_bounds.height
                        > content_area.AbsoluteSize.Y + game_config.taskbar_height / 3
                then
                    game_state.is_game_over = true
                end

                -- pipe collision
                for _, pipe in ipairs(game_state.pipes) do
                    local top_abs_pos = pipe.top_pipe.AbsolutePosition
                    local top_abs_size = pipe.top_pipe.AbsoluteSize

                    local top_bounds = {
                        x = top_abs_pos.X,
                        y = top_abs_pos.Y,
                        width = top_abs_size.X,
                        height = top_abs_size.Y,
                    }

                    local bottom_abs_pos = pipe.bottom_pipe.AbsolutePosition
                    local bottom_abs_size = pipe.bottom_pipe.AbsoluteSize

                    local bottom_bounds = {
                        x = bottom_abs_pos.X,
                        y = bottom_abs_pos.Y,
                        width = bottom_abs_size.X,
                        height = bottom_abs_size.Y,
                    }

                    if
                        check_collision(
                            bird_bounds.x,
                            bird_bounds.y,
                            bird_bounds.width,
                            bird_bounds.height,
                            top_bounds.x,
                            top_bounds.y,
                            top_bounds.width,
                            top_bounds.height
                        )
                        or check_collision(
                            bird_bounds.x,
                            bird_bounds.y,
                            bird_bounds.width,
                            bird_bounds.height,
                            bottom_bounds.x,
                            bottom_bounds.y,
                            bottom_bounds.width,
                            bottom_bounds.height
                        )
                    then
                        game_state.is_game_over = true
                        break
                    end
                end

                -- game over
                if game_state.is_game_over then
                    ui_elements.game_over_label.Visible = true

                    local is_new_high_score = type(high_score) ~= "number"
                        or game_state.score > high_score

                    if is_new_high_score then
                        if save_score(dOS, game_state.score) then
                            high_score = game_state.score
                        else
                            warn(
                                "[Flappy Bird] SAVE_DATA: save_score returned\
                                 false! game_state.score = '"
                                    .. game_state.score
                                    .. "'."
                            )
                        end
                    end
                end
            end

            task.wait()
        end
    end)

    window_frame.Destroying:Connect(function() game_state.is_active = false end)
end

return M

-- EOF
