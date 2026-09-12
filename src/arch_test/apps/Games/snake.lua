--[[
    "Snake game for dOS"
    
    @module snake
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


--- CONFIG

local M = {}

local CONFIG = {
    GRID_W = 20,
    GRID_H = 20,
    CELL = 14, -- cell size in pixels
    GAP = 1, -- gap between cells in pixels
    SPEED_INIT = 0.18, -- starting tick interval (seconds)
    SPEED_STEP = 0.004, -- interval reduction per food eaten
    SPEED_MIN = 0.065, -- fastest possible tick interval
}

--- GEOMETRY

local STRIDE = CONFIG.CELL + CONFIG.GAP
local GAME_W = CONFIG.GRID_W * STRIDE - CONFIG.GAP
local GAME_H = CONFIG.GRID_H * STRIDE - CONFIG.GAP
local SIDE_PAD = 16
local HEADER_H = 50
local WIN_W = GAME_W + SIDE_PAD * 2
local WIN_H = HEADER_H + GAME_H + 40

--- COLORS

local C = {
    WIN_BG = Color3.fromRGB(11, 11, 19),
    HDR_BG = Color3.fromRGB(7, 7, 14),
    CELL_EMPTY = Color3.fromRGB(51, 51, 67),
    S_HEAD = Color3.fromRGB(74, 222, 128),
    S_BODY_A = Color3.fromRGB(46, 180, 99),
    S_BODY_B = Color3.fromRGB(27, 128, 68),
    S_TAIL = Color3.fromRGB(17, 88, 46),
    S_DEAD = Color3.fromRGB(239, 68, 68),
    FOOD = Color3.fromRGB(251, 113, 27),
    ACCENT = Color3.fromRGB(99, 102, 241),
    ACCENT_HOV = Color3.fromRGB(122, 125, 255),
    TXT_MAIN = Color3.fromRGB(240, 240, 255),
    TXT_DIM = Color3.fromRGB(110, 110, 155),
    SCORE_GRN = Color3.fromRGB(74, 222, 128),
    OVERLAY_BG = Color3.fromRGB(8, 8, 16),
    WIN_GOLD = Color3.fromRGB(250, 204, 21),
    DANGER = Color3.fromRGB(239, 68, 68),
    DIVIDER = Color3.fromRGB(38, 38, 62),
}

--- SAVING

local function save_score(dOS, score)
    if not dOS.disk then
        warn("[Snake] SAVE: No system disk found.")
        return false
    end

    local ok, err = pcall(
        dOS.disk.Write,
        dOS.disk,
        dOS.GAMES_DATA.GLOBAL_GAMES_DATA_FOLDER
            .. dOS.GAMES_DATA.SNAKE_DISK_FILE,
        tostring(score)
    )

    if not ok then warn("[Snake] SAVE: Failed - " .. tostring(err)) end

    return ok
end

local function load_score(dOS)
    if not dOS.disk then return false end

    local ok, data = pcall(
        dOS.disk.Read,
        dOS.disk,
        dOS.GAMES_DATA.GLOBAL_GAMES_DATA_FOLDER
            .. dOS.GAMES_DATA.SNAKE_DISK_FILE
    )

    if not ok or not data then return false end

    return tonumber(data) or false
end

--- GAME

local function place_food(state)
    local occupied = {}

    for _, seg in ipairs(state.snake) do
        occupied[seg.y * CONFIG.GRID_W + seg.x] = true
    end

    local empty = {}

    for y = 1, CONFIG.GRID_H do
        for x = 1, CONFIG.GRID_W do
            if not occupied[y * CONFIG.GRID_W + x] then
                empty[#empty + 1] = { x = x, y = y }
            end
        end
    end

    if #empty == 0 then return end

    local pick = empty[math.random(1, #empty)]
    state.food.x, state.food.y = pick.x, pick.y
end

local function set_direction(state, vec)
    if state.phase ~= "PLAYING" then return end

    if vec.x == -state.direction.x and vec.y == -state.direction.y then
        return
    end

    state.next_dir = vec
end

local function reset_state(state)
    state.snake = {}
    state.direction = { x = 1, y = 0 }
    state.next_dir = { x = 1, y = 0 }
    state.food = { x = 0, y = 0 }
    state.score = 0
    state.speed = CONFIG.SPEED_INIT
    state.phase = "PLAYING"
    state.gen = state.gen + 1

    local mid = math.floor(CONFIG.GRID_H / 2)

    for i = 3, 1, -1 do
        state.snake[#state.snake + 1] = { x = i, y = mid }
    end

    place_food(state)
end

local function game_tick(dOS, state)
    state.direction = state.next_dir

    local head = state.snake[1]
    local nx = head.x + state.direction.x
    local ny = head.y + state.direction.y

    -- wall collision
    if nx < 1 or nx > CONFIG.GRID_W or ny < 1 or ny > CONFIG.GRID_H then
        state.phase = "DEAD"
        return
    end

    -- self collision
    local len = #state.snake

    for i = 1, len - 1 do
        if state.snake[i].x == nx and state.snake[i].y == ny then
            state.phase = "DEAD"
            return
        end
    end

    table.insert(state.snake, 1, { x = nx, y = ny })

    if nx == state.food.x and ny == state.food.y then
        state.score = state.score + 1
        state.speed =
            math.max(CONFIG.SPEED_MIN, state.speed - CONFIG.SPEED_STEP)

        if state.score > state.high_score then
            state.high_score = state.score
        end

        -- win
        if #state.snake >= CONFIG.GRID_W * CONFIG.GRID_H then
            state.phase = "WIN"
            save_score(dOS, state.high_score)
            return
        end

        place_food(state)
    else
        table.remove(state.snake)
    end
end

--- RENDERING

local function snake_seg_color(total, idx, is_dead)
    if is_dead then return C.S_DEAD end

    if idx == 1 then return C.S_HEAD end

    local t = (idx - 1) / math.max(total - 1, 1)

    if t < 0.33 then
        return C.S_BODY_A
    elseif t < 0.66 then
        return C.S_BODY_B
    else
        return C.S_TAIL
    end
end

local function render_grid(state, ui)
    for y = 1, CONFIG.GRID_H do
        for x = 1, CONFIG.GRID_W do
            ui.cells[y][x].BackgroundColor3 = C.CELL_EMPTY
        end
    end

    local total = #state.snake
    local is_dead = state.phase == "DEAD"

    for idx, seg in ipairs(state.snake) do
        local row = ui.cells[seg.y]

        if row and row[seg.x] then
            row[seg.x].BackgroundColor3 = snake_seg_color(total, idx, is_dead)
        end
    end

    if state.food.x > 0 then
        local row = ui.cells[state.food.y]

        if row and row[state.food.x] then
            row[state.food.x].BackgroundColor3 = C.FOOD
        end
    end
end

local function refresh_scores(state, ui)
    ui.score_val.Text = state.score
    ui.best_val.Text = state.high_score
end

local function set_overlay(state, ui, phase)
    if phase == "NONE" then
        ui.overlay.Visible = false
        return
    end

    ui.overlay.Visible = true

    if phase == "MENU" then
        ui.overlay_title.Text = "SNAKE"
        ui.overlay_title.TextColor3 = C.TXT_MAIN
        ui.overlay_btn_lbl.Text = "PLAY"

        local show_hs = state.high_score > 0
        ui.overlay_sub_lbl.Visible = show_hs
        ui.overlay_sub_num.Visible = show_hs

        if show_hs then
            ui.overlay_sub_lbl.Text = "BEST"
            ui.overlay_sub_num.Text = state.high_score
            ui.overlay_sub_num.TextColor3 = C.WIN_GOLD
        end
    elseif phase == "WIN" then
        ui.overlay_title.Text = "YOU WIN"
        ui.overlay_title.TextColor3 = C.WIN_GOLD
        ui.overlay_btn_lbl.Text = "PLAY AGAIN"
        ui.overlay_sub_lbl.Visible = true
        ui.overlay_sub_num.Visible = true
        ui.overlay_sub_lbl.Text = "SCORE"
        ui.overlay_sub_num.Text = state.score
        ui.overlay_sub_num.TextColor3 = C.WIN_GOLD
    elseif phase == "DEAD" then
        ui.overlay_title.Text = "GAME OVER"
        ui.overlay_title.TextColor3 = C.DANGER
        ui.overlay_btn_lbl.Text = "PLAY AGAIN"
        ui.overlay_sub_lbl.Visible = true
        ui.overlay_sub_num.Visible = true
        ui.overlay_sub_lbl.Text = "SCORE"
        ui.overlay_sub_num.Text = state.score
        ui.overlay_sub_num.TextColor3 = C.TXT_MAIN
    end
end

--- UI

local function build_ui(dOS, ca, ui)
    ca.BackgroundColor3 = C.WIN_BG
    ca.ClipsDescendants = true

    -- header

    local hdr = dOS.create_gui_element(dOS, "Frame", {
        Parent = ca,
        Size = UDim2.new(1, 0, 0, HEADER_H),
        Position = UDim2.fromOffset(0, 0),
        BackgroundColor3 = C.HDR_BG,
        BorderSizePixel = 0,
        ZIndex = 2,
    })

    dOS.create_gui_element(dOS, "Frame", {
        Parent = hdr,
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = C.DIVIDER,
        BorderSizePixel = 0,
        ZIndex = 3,
    })

    local function make_stat_pill(parent, x_offset, caption)
        local pill = dOS.create_gui_element(dOS, "Frame", {
            Parent = parent,
            Size = UDim2.fromOffset(86, 38),
            Position = UDim2.new(0, x_offset, 0.5, -19),
            BackgroundColor3 = C.WIN_BG,
            BorderSizePixel = 0,
            ZIndex = 3,
        })

        dOS.create_gui_element(
            dOS,
            "UICorner",
            { Parent = pill, CornerRadius = UDim.new(0, 6) }
        )

        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = pill,
            Size = UDim2.new(1, 0, 0, 14),
            Position = UDim2.fromOffset(0, 4),
            BackgroundTransparency = 1,
            Text = caption,
            TextColor3 = C.TXT_DIM,
            TextSize = 10,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 4,
        })

        local val = dOS.create_gui_element(dOS, "TextLabel", {
            Parent = pill,
            Size = UDim2.new(1, 0, 0, 20),
            Position = UDim2.fromOffset(0, 17),
            BackgroundTransparency = 1,
            Text = 0,
            TextColor3 = C.SCORE_GRN,
            TextSize = 19,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 4,
        })

        return val
    end

    ui.score_val = make_stat_pill(hdr, SIDE_PAD, "SCORE")
    ui.best_val = make_stat_pill(hdr, WIN_W - SIDE_PAD - 86, "BEST")
    ui.best_val.TextColor3 = C.TXT_DIM

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = hdr,
        Size = UDim2.fromOffset(100, HEADER_H),
        Position = UDim2.new(0.5, -50, 0, 0),
        BackgroundTransparency = 1,
        Text = "SNAKE",
        TextColor3 = C.DIVIDER,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 3,
    })

    local gx = math.floor((WIN_W - GAME_W) / 2)

    local grid_cont = dOS.create_gui_element(dOS, "Frame", {
        Parent = ca,
        Size = UDim2.fromOffset(GAME_W, GAME_H),
        Position = UDim2.fromOffset(gx, HEADER_H),
        BackgroundColor3 = C.WIN_BG,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 2,
    })

    ui.cells = {}

    for y = 1, CONFIG.GRID_H do
        ui.cells[y] = {}

        for x = 1, CONFIG.GRID_W do
            local cell = dOS.create_gui_element(dOS, "Frame", {
                Parent = grid_cont,
                Size = UDim2.fromOffset(CONFIG.CELL, CONFIG.CELL),
                Position = UDim2.fromOffset((x - 1) * STRIDE, (y - 1) * STRIDE),
                BackgroundColor3 = C.CELL_EMPTY,
                BorderSizePixel = 0,
                ZIndex = 2,
            })

            dOS.create_gui_element(
                dOS,
                "UICorner",
                { Parent = cell, CornerRadius = UDim.new(0, CONFIG.CELL) }
            )

            ui.cells[y][x] = cell
        end
    end

    ui.overlay = dOS.create_gui_element(dOS, "Frame", {
        Parent = grid_cont,
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, 0),
        BackgroundColor3 = C.OVERLAY_BG,
        BackgroundTransparency = 0.10,
        BorderSizePixel = 0,
        ZIndex = 20,
        Visible = false,
    })

    ui.overlay_title = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = ui.overlay,
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.fromOffset(0, 68),
        BackgroundTransparency = 1,
        Text = "SNAKE",
        TextColor3 = C.TXT_MAIN,
        TextSize = 38,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 21,
    })

    ui.overlay_sub_lbl = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = ui.overlay,
        Size = UDim2.new(1, 0, 0, 16),
        Position = UDim2.fromOffset(0, 128),
        BackgroundTransparency = 1,
        Text = "SCORE",
        TextColor3 = C.TXT_DIM,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 21,
        Visible = false,
    })

    ui.overlay_sub_num = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = ui.overlay,
        Size = UDim2.new(1, 0, 0, 32),
        Position = UDim2.fromOffset(0, 146),
        BackgroundTransparency = 1,
        Text = 0,
        TextColor3 = C.TXT_MAIN,
        TextSize = 28,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 21,
        Visible = false,
    })

    local ob

    ob = dOS.create_gui_element(dOS, "TextButton", {
        Parent = ui.overlay,
        Size = UDim2.fromOffset(128, 40),
        Position = UDim2.new(0.5, -64, 0, 200),
        BackgroundColor3 = C.ACCENT,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 21,
        OnEnter = function() ob.BackgroundColor3 = C.ACCENT_HOV end,
        OnLeave = function() ob.BackgroundColor3 = C.ACCENT end,
    })

    dOS.create_gui_element(
        dOS,
        "UICorner",
        { Parent = ob, CornerRadius = UDim.new(0, 9) }
    )

    ui.overlay_btn = ob

    ui.overlay_btn_lbl = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = ob,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "PLAY",
        TextColor3 = C.TXT_MAIN,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 22,
    })
end

--- CONTROL

local function start_game(dOS, state, ui)
    reset_state(state)
    set_overlay(state, ui, "NONE")
    render_grid(state, ui)
    refresh_scores(state, ui)

    local my_gen = state.gen

    task.spawn(function()
        while state.phase == "PLAYING" and state.gen == my_gen do
            task.wait(state.speed)

            if state.gen ~= my_gen then return end

            game_tick(dOS, state)
            render_grid(state, ui)
            refresh_scores(state, ui)
        end

        if state.gen ~= my_gen then return end

        if state.phase == "DEAD" then
            render_grid(state, ui)
            task.wait(0.6)
            save_score(dOS, state.high_score)
            refresh_scores(state, ui)
        elseif state.phase == "WIN" then
            task.wait(0.4)
            refresh_scores(state, ui)
        end

        set_overlay(state, ui, state.phase == "WIN" and "WIN" or "DEAD")
    end)
end

--- API

local KEY_DIRS = {
    [Enum.KeyCode.W] = { x = 0, y = -1 },
    [Enum.KeyCode.S] = { x = 0, y = 1 },
    [Enum.KeyCode.A] = { x = -1, y = 0 },
    [Enum.KeyCode.D] = { x = 1, y = 0 },
    [Enum.KeyCode.Up] = { x = 0, y = -1 },
    [Enum.KeyCode.Down] = { x = 0, y = 1 },
    [Enum.KeyCode.Left] = { x = -1, y = 0 },
    [Enum.KeyCode.Right] = { x = 1, y = 0 },
}

function M.create(dOS)
    if not dOS.keyboard then
        dOS.MessageBox.error(
            dOS,
            "Hardware error",
            "A Keyboard is required for this game to work.\nPlease connect one and retry."
        )
    end

    local window_frame, content_area = dOS.create_basic_window(
        dOS,
        "Snake",
        WIN_W,
        WIN_H,
        true,
        true,
        false,
        true,
        -1,
        -1
    )

    if not window_frame then return end

    local saved_hs = load_score(dOS)
    local state = {
        snake = {},
        direction = { x = 1, y = 0 },
        next_dir = { x = 1, y = 0 },
        food = { x = 0, y = 0 },
        score = 0,
        high_score = type(saved_hs) == "number" and saved_hs or 0,
        speed = CONFIG.SPEED_INIT,
        phase = "MENU",
        gen = 0,
        keyboard_conn = nil,
    }

    local ui = { overlay_btn = nil }
    build_ui(dOS, content_area, ui)
    refresh_scores(state, ui)
    set_overlay(state, ui, "MENU")
    render_grid(state, ui)

    ui.overlay_btn.MouseButton1Click:Connect(
        function() start_game(dOS, state, ui) end
    )

    if dOS.keyboard then
        state.keyboard_conn = dOS.keyboard.UserInput:Connect(
            function(input, _userId)
                if input.UserInputState == Enum.UserInputState.Begin then
                    local vec = KEY_DIRS[input.KeyCode]

                    if vec then set_direction(state, vec) end
                end
            end
        )
    end

    window_frame.Destroying:Connect(function()
        if state.keyboard_conn then
            pcall(state.keyboard_conn.Disconnect, state.keyboard_conn)
        end
    end)
end

return M

-- EOF
