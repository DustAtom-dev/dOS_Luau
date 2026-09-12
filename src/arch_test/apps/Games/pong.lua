--[[
    "Pong game for dOS"
    
    @module pong
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

--- CONFIG

local CONFIG = {
    FIELD_W = 400,
    FIELD_H = 260,
    PADDLE_W = 8,
    PADDLE_H = 52,
    PADDLE_MARGIN = 14,
    PLAYER_SPEED = 235, -- px / sec
    AI_SPEED = 178, -- px / sec
    BALL_SIZE = 10,
    BALL_SPEED_INI = 162, -- px / sec at serve
    BALL_SPEED_INC = 10, -- speed added per paddle hit
    BALL_SPEED_MAX = 335,
    WIN_SCORE = 7, -- points required to win a match
    POINT_PAUSE = 0.85, -- seconds between a goal and the next serve
    BALL_MAX_ANGLE = 62, -- °, maximum deflection angle off a paddle
}

--- GEOMETRY

local HEADER_H = 50
local HINT_H = 24
local WIN_W = CONFIG.FIELD_W
local WIN_H = HEADER_H + CONFIG.FIELD_H + HINT_H + 40

--- COLORS

local C = {
    WIN_BG = Color3.fromRGB(10, 10, 18),
    HDR_BG = Color3.fromRGB(6, 6, 13),
    FIELD_BG = Color3.fromRGB(10, 10, 18),
    NET = Color3.fromRGB(28, 28, 50),
    PADDLE = Color3.fromRGB(230, 230, 255),
    BALL_COL = Color3.fromRGB(255, 255, 255),
    SCORE_DIM = Color3.fromRGB(22, 22, 44),
    TXT_MAIN = Color3.fromRGB(240, 240, 255),
    TXT_DIM = Color3.fromRGB(100, 100, 145),
    ACCENT = Color3.fromRGB(99, 102, 241),
    ACCENT_HOV = Color3.fromRGB(122, 125, 255),
    DIVIDER = Color3.fromRGB(30, 30, 54),
    WIN_GOLD = Color3.fromRGB(250, 204, 21),
    DANGER = Color3.fromRGB(239, 68, 68),
    OVERLAY_BG = Color3.fromRGB(8, 8, 15),
}

--- SAVING

local function save_wins(dOS, wins)
    if not dOS.disk then
        warn("[Pong] SAVE: No system disk found.")
        return false
    end

    local ok, err = pcall(
        dOS.disk.Write,
        dOS.disk,
        dOS.GAMES_DATA.GLOBAL_GAMES_DATA_FOLDER .. dOS.GAMES_DATA.PONG_DISK_FILE,
        tostring(wins)
    )

    if not ok then warn("[Pong] SAVE: Failed - " .. tostring(err)) end

    return ok
end

local function load_wins(dOS)
    if not dOS.disk then return false end

    local ok, data = pcall(
        dOS.disk.Read,
        dOS.disk,
        dOS.GAMES_DATA.GLOBAL_GAMES_DATA_FOLDER .. dOS.GAMES_DATA.PONG_DISK_FILE
    )

    if not ok or not data then return false end

    return tonumber(data) or false
end

--- GAME

local function reset_ball(state, toward_player)
    local b = state.ball

    b.x = CONFIG.FIELD_W / 2
    b.y = CONFIG.FIELD_H / 2

    local angle = (math.random() - 0.5) * math.rad(40) -- ±20° vertical spread
    local spd = CONFIG.BALL_SPEED_INI
    local dir = toward_player and -1 or 1

    b.vx = dir * spd * math.cos(angle)
    b.vy = spd * math.sin(angle)
end

local function reset_paddles(state)
    local mid = (CONFIG.FIELD_H - CONFIG.PADDLE_H) / 2

    state.paddles.player.y = mid
    state.paddles.ai.y = mid
end

local function update(dt, state)
    -- player paddle
    local p = state.paddles.player

    if state.held[Enum.KeyCode.W] or state.held[Enum.KeyCode.Up] then
        p.y = math.clamp(
            p.y - CONFIG.PLAYER_SPEED * dt,
            0,
            CONFIG.FIELD_H - CONFIG.PADDLE_H
        )
    elseif state.held[Enum.KeyCode.S] or state.held[Enum.KeyCode.Down] then
        p.y = math.clamp(
            p.y + CONFIG.PLAYER_SPEED * dt,
            0,
            CONFIG.FIELD_H - CONFIG.PADDLE_H
        )
    end

    -- ai paddle
    local ai = state.paddles.ai
    local ai_target = state.ball.y - CONFIG.PADDLE_H / 2

    if ai.y < ai_target - 1 then
        ai.y = math.min(ai_target, ai.y + CONFIG.AI_SPEED * dt)
    elseif ai.y > ai_target + 1 then
        ai.y = math.max(ai_target, ai.y - CONFIG.AI_SPEED * dt)
    end

    ai.y = math.clamp(ai.y, 0, CONFIG.FIELD_H - CONFIG.PADDLE_H)

    -- ball movement
    local b = state.ball

    b.x = b.x + b.vx * dt
    b.y = b.y + b.vy * dt

    local half = CONFIG.BALL_SIZE / 2

    -- wall bounce
    if b.y - half <= 0 then
        b.y = half
        b.vy = math.abs(b.vy)
    elseif b.y + half >= CONFIG.FIELD_H then
        b.y = CONFIG.FIELD_H - half
        b.vy = -math.abs(b.vy)
    end

    -- player paddle hit
    local pp_x = CONFIG.PADDLE_MARGIN + CONFIG.PADDLE_W -- right face of player paddle

    if
        b.vx < 0
        and b.x - half <= pp_x
        and b.x - half > CONFIG.PADDLE_MARGIN - 2
        and b.y + half > p.y
        and b.y - half < p.y + CONFIG.PADDLE_H
    then
        local rel = math.clamp(
            (b.y - (p.y + CONFIG.PADDLE_H / 2)) / (CONFIG.PADDLE_H / 2),
            -1,
            1
        )
        local spd = math.min(
            CONFIG.BALL_SPEED_MAX,
            math.sqrt(b.vx ^ 2 + b.vy ^ 2) + CONFIG.BALL_SPEED_INC
        )
        local ang = rel * math.rad(CONFIG.BALL_MAX_ANGLE)

        b.vx = spd * math.cos(ang)
        b.vy = spd * math.sin(ang)
        b.x = pp_x + half + 1 -- nudge clear to avoid tunnelling
    end

    -- ai paddle hit
    local ap_x = CONFIG.FIELD_W - CONFIG.PADDLE_MARGIN - CONFIG.PADDLE_W -- left face of AI paddle

    if
        b.vx > 0
        and b.x + half >= ap_x
        and b.x + half < ap_x + CONFIG.PADDLE_W + 2
        and b.y + half > ai.y
        and b.y - half < ai.y + CONFIG.PADDLE_H
    then
        local rel = math.clamp(
            (b.y - (ai.y + CONFIG.PADDLE_H / 2)) / (CONFIG.PADDLE_H / 2),
            -1,
            1
        )
        local spd = math.min(
            CONFIG.BALL_SPEED_MAX,
            math.sqrt(b.vx ^ 2 + b.vy ^ 2) + CONFIG.BALL_SPEED_INC
        )
        local ang = rel * math.rad(CONFIG.BALL_MAX_ANGLE)

        b.vx = -(spd * math.cos(ang))
        b.vy = spd * math.sin(ang)
        b.x = ap_x - half - 1
    end

    -- goal detection
    if b.x + half < -12 then
        state.scores.ai = state.scores.ai + 1
        state.last_scorer = "ai"
        state.phase = "POINT"
    elseif b.x - half > CONFIG.FIELD_W + 12 then
        state.scores.player = state.scores.player + 1
        state.last_scorer = "player"
        state.phase = "POINT"
    end
end

--- RENDERING

local function render(state, ui)
    local half = CONFIG.BALL_SIZE / 2

    ui.ball.Position = UDim2.fromOffset(
        math.round(state.ball.x - half),
        math.round(state.ball.y - half)
    )

    ui.paddle_player.Position = UDim2.fromOffset(
        CONFIG.PADDLE_MARGIN,
        math.round(state.paddles.player.y)
    )

    local ap_x = CONFIG.FIELD_W - CONFIG.PADDLE_MARGIN - CONFIG.PADDLE_W
    ui.paddle_ai.Position =
        UDim2.fromOffset(ap_x, math.round(state.paddles.ai.y))

    ui.score_player.Text = state.scores.player
    ui.score_ai.Text = state.scores.ai
    ui.bg_score_player.Text = state.scores.player
    ui.bg_score_ai.Text = state.scores.ai
end

local function set_overlay(state, ui, phase)
    if phase == "NONE" then
        ui.overlay.Visible = false
        return
    end

    ui.overlay.Visible = true

    if phase == "MENU" then
        ui.overlay_title.Text = "PONG"
        ui.overlay_title.TextColor3 = C.TXT_MAIN
        ui.overlay_btn_lbl.Text = "PLAY"
        local show_w = state.total_wins > 0

        ui.overlay_sub_lbl.Visible = show_w
        ui.overlay_sub_num.Visible = show_w

        if show_w then
            ui.overlay_sub_lbl.Text = "WINS"
            ui.overlay_sub_num.Text = state.total_wins
            ui.overlay_sub_num.TextColor3 = C.WIN_GOLD
        end
    elseif phase == "WIN" then
        ui.overlay_title.Text = "YOU WIN"
        ui.overlay_title.TextColor3 = C.WIN_GOLD
        ui.overlay_btn_lbl.Text = "PLAY AGAIN"
        ui.overlay_sub_lbl.Visible = true
        ui.overlay_sub_num.Visible = true
        ui.overlay_sub_lbl.Text = "TOTAL WINS"
        ui.overlay_sub_num.Text = state.total_wins
        ui.overlay_sub_num.TextColor3 = C.WIN_GOLD
    elseif phase == "LOSE" then
        ui.overlay_title.Text = "YOU LOSE"
        ui.overlay_title.TextColor3 = C.DANGER
        ui.overlay_btn_lbl.Text = "PLAY AGAIN"
        ui.overlay_sub_lbl.Visible = true
        ui.overlay_sub_num.Visible = true
        ui.overlay_sub_lbl.Text = "TOTAL WINS"
        ui.overlay_sub_num.Text = state.total_wins
        ui.overlay_sub_num.TextColor3 = C.TXT_DIM
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

    local function make_score_block(parent, x_off, caption)
        local block = dOS.create_gui_element(dOS, "Frame", {
            Parent = parent,
            Size = UDim2.fromOffset(70, 38),
            Position = UDim2.new(0, x_off, 0.5, -19),
            BackgroundColor3 = C.WIN_BG,
            BorderSizePixel = 0,
            ZIndex = 3,
        })

        dOS.create_gui_element(dOS, "UICorner", {
            Parent = block,
            CornerRadius = UDim.new(0, 6),
        })

        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = block,
            Size = UDim2.new(1, 0, 0, 13),
            Position = UDim2.fromOffset(0, 4),
            BackgroundTransparency = 1,
            Text = caption,
            TextColor3 = C.TXT_DIM,
            TextSize = 9,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 4,
        })

        local num = dOS.create_gui_element(dOS, "TextLabel", {
            Parent = block,
            Size = UDim2.new(1, 0, 0, 20),
            Position = UDim2.fromOffset(0, 17),
            BackgroundTransparency = 1,
            Text = 0,
            TextColor3 = C.TXT_MAIN,
            TextSize = 18,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 4,
        })

        return num
    end

    ui.score_player = make_score_block(hdr, 16, "YOU")
    ui.score_ai = make_score_block(hdr, WIN_W - 86, "CPU")

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = hdr,
        Size = UDim2.fromOffset(80, HEADER_H),
        Position = UDim2.new(0.5, -40, 0, 0),
        BackgroundTransparency = 1,
        Text = "PONG",
        TextColor3 = C.DIVIDER,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 3,
    })

    local field = dOS.create_gui_element(dOS, "Frame", {
        Parent = ca,
        Size = UDim2.fromOffset(CONFIG.FIELD_W, CONFIG.FIELD_H),
        Position = UDim2.fromOffset(0, HEADER_H),
        BackgroundColor3 = C.FIELD_BG,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 2,
    })

    -- center net
    local dash_h = 10
    local dash_gap = 7
    local n_dashes = math.floor(CONFIG.FIELD_H / (dash_h + dash_gap))
    local net_total = n_dashes * dash_h + (n_dashes - 1) * dash_gap
    local net_y0 = math.floor((CONFIG.FIELD_H - net_total) / 2)
    local net_cx = CONFIG.FIELD_W / 2 - 1

    for i = 0, n_dashes - 1 do
        dOS.create_gui_element(dOS, "Frame", {
            Parent = field,
            Size = UDim2.fromOffset(2, dash_h),
            Position = UDim2.fromOffset(
                net_cx,
                net_y0 + i * (dash_h + dash_gap)
            ),
            BackgroundColor3 = C.NET,
            BorderSizePixel = 0,
            ZIndex = 2,
        })
    end

    -- watermark scores
    ui.bg_score_player = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = field,
        Size = UDim2.fromOffset(90, 110),
        Position = UDim2.fromOffset(
            CONFIG.FIELD_W / 4 - 45,
            CONFIG.FIELD_H / 2 - 55
        ),
        BackgroundTransparency = 1,
        Text = 0,
        TextColor3 = C.SCORE_DIM,
        TextSize = 100,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 2,
    })

    ui.bg_score_ai = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = field,
        Size = UDim2.fromOffset(90, 110),
        Position = UDim2.fromOffset(
            CONFIG.FIELD_W * 3 / 4 - 45,
            CONFIG.FIELD_H / 2 - 55
        ),
        BackgroundTransparency = 1,
        Text = 0,
        TextColor3 = C.SCORE_DIM,
        TextSize = 100,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 2,
    })

    ui.paddle_player = dOS.create_gui_element(dOS, "Frame", {
        Parent = field,
        Size = UDim2.fromOffset(CONFIG.PADDLE_W, CONFIG.PADDLE_H),
        Position = UDim2.fromOffset(
            CONFIG.PADDLE_MARGIN,
            (CONFIG.FIELD_H - CONFIG.PADDLE_H) / 2
        ),
        BackgroundColor3 = C.PADDLE,
        BorderSizePixel = 0,
        ZIndex = 4,
    })

    dOS.create_gui_element(dOS, "UICorner", {
        Parent = ui.paddle_player,
        CornerRadius = UDim.new(0, 3),
    })

    local ap_x = CONFIG.FIELD_W - CONFIG.PADDLE_MARGIN - CONFIG.PADDLE_W
    ui.paddle_ai = dOS.create_gui_element(dOS, "Frame", {
        Parent = field,
        Size = UDim2.fromOffset(CONFIG.PADDLE_W, CONFIG.PADDLE_H),
        Position = UDim2.fromOffset(
            ap_x,
            (CONFIG.FIELD_H - CONFIG.PADDLE_H) / 2
        ),
        BackgroundColor3 = C.PADDLE,
        BorderSizePixel = 0,
        ZIndex = 4,
    })

    dOS.create_gui_element(dOS, "UICorner", {
        Parent = ui.paddle_ai,
        CornerRadius = UDim.new(0, 3),
    })

    ui.ball = dOS.create_gui_element(dOS, "Frame", {
        Parent = field,
        Size = UDim2.fromOffset(CONFIG.BALL_SIZE, CONFIG.BALL_SIZE),
        Position = UDim2.fromOffset(
            CONFIG.FIELD_W / 2 - CONFIG.BALL_SIZE / 2,
            CONFIG.FIELD_H / 2 - CONFIG.BALL_SIZE / 2
        ),
        BackgroundColor3 = C.BALL_COL,
        BorderSizePixel = 0,
        ZIndex = 5,
    })

    dOS.create_gui_element(dOS, "UICorner", {
        Parent = ui.ball,
        CornerRadius = UDim.new(0, 2),
    })

    ui.overlay = dOS.create_gui_element(dOS, "Frame", {
        Parent = field,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = C.OVERLAY_BG,
        BackgroundTransparency = 0.10,
        BorderSizePixel = 0,
        ZIndex = 20,
        Visible = false,
    })

    ui.overlay_title = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = ui.overlay,
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.fromOffset(0, 60),
        BackgroundTransparency = 1,
        Text = "PONG",
        TextColor3 = C.TXT_MAIN,
        TextSize = 38,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 21,
    })

    ui.overlay_sub_lbl = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = ui.overlay,
        Size = UDim2.new(1, 0, 0, 15),
        Position = UDim2.fromOffset(0, 118),
        BackgroundTransparency = 1,
        Text = "WINS",
        TextColor3 = C.TXT_DIM,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 21,
        Visible = false,
    })

    ui.overlay_sub_num = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = ui.overlay,
        Size = UDim2.new(1, 0, 0, 30),
        Position = UDim2.fromOffset(0, 135),
        BackgroundTransparency = 1,
        Text = 0,
        TextColor3 = C.TXT_MAIN,
        TextSize = 26,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 21,
        Visible = false,
    })

    local ob
    ob = dOS.create_gui_element(dOS, "TextButton", {
        Parent = ui.overlay,
        Size = UDim2.fromOffset(128, 40),
        Position = UDim2.new(0.5, -64, 0, 180),
        BackgroundColor3 = C.ACCENT,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 21,
        OnEnter = function() ob.BackgroundColor3 = C.ACCENT_HOV end,
        OnLeave = function() ob.BackgroundColor3 = C.ACCENT end,
    })

    dOS.create_gui_element(dOS, "UICorner", {
        Parent = ob,
        CornerRadius = UDim.new(0, 9),
    })

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

    local hint = dOS.create_gui_element(dOS, "Frame", {
        Parent = ca,
        Size = UDim2.new(1, 0, 0, HINT_H),
        Position = UDim2.fromOffset(0, HEADER_H + CONFIG.FIELD_H),
        BackgroundColor3 = C.HDR_BG,
        BorderSizePixel = 0,
        ZIndex = 2,
    })

    dOS.create_gui_element(dOS, "Frame", {
        Parent = hint,
        Size = UDim2.new(1, -32, 0, 1),
        Position = UDim2.fromOffset(16, 0),
        BackgroundColor3 = C.DIVIDER,
        BorderSizePixel = 0,
        ZIndex = 3,
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = hint,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "W / S  or  ARROW KEYS  to move",
        TextColor3 = C.TXT_DIM,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 3,
    })
end

--- CONTROL

local function start_match(dOS, state, ui)
    state.scores = { player = 0, ai = 0 }
    state.phase = "PLAYING"
    state.gen = state.gen + 1

    reset_paddles(state)
    reset_ball(state, math.random() < 0.5)
    set_overlay(state, ui, "NONE")
    render(state, ui)

    local my_gen = state.gen

    task.spawn(function()
        local last = os.clock()

        while state.gen == my_gen do
            task.wait()
            local now = os.clock()
            local dt = math.min(now - last, 0.05)
            last = now

            if state.phase == "PLAYING" then
                update(dt, state)
                render(state, ui)
            elseif state.phase == "POINT" then
                task.wait(CONFIG.POINT_PAUSE)

                if state.gen ~= my_gen then return end

                if state.scores.player >= CONFIG.WIN_SCORE then
                    state.total_wins = state.total_wins + 1
                    save_wins(dOS, state.total_wins)
                    set_overlay(state, ui, "WIN")

                    return
                elseif state.scores.ai >= CONFIG.WIN_SCORE then
                    set_overlay(state, ui, "LOSE")

                    return
                end

                reset_paddles(state)
                reset_ball(state, state.last_scorer == "player")
                state.phase = "PLAYING"
            end
        end
    end)
end

--- API

M.create = function(dOS)
    if not dOS.keyboard then
        dOS.MessageBox.error(
            dOS,
            "Hardware error",
            "Pong requires a keyboard to work.\n Please connect one and retry."
        )
        warn(
            "[Pong] No Keyboard found on the network. Player input will not work."
        )
    end

    local window_frame, content_area = dOS.create_basic_window(
        dOS,
        "Pong",
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

    local saved_wins = load_wins(dOS)

    local state = {
        ball = {
            x = CONFIG.FIELD_W / 2,
            y = CONFIG.FIELD_H / 2,
            vx = 0,
            vy = 0,
        },
        paddles = {
            player = { y = (CONFIG.FIELD_H - CONFIG.PADDLE_H) / 2 },
            ai = { y = (CONFIG.FIELD_H - CONFIG.PADDLE_H) / 2 },
        },
        scores = { player = 0, ai = 0 },
        total_wins = type(saved_wins) == "number" and saved_wins or 0,
        phase = "MENU",
        last_scorer = nil,
        held = {},
        gen = 0,
        keyboard_conn = nil,
    }

    local ui = { overlay_btn = nil }
    build_ui(dOS, content_area, ui)
    set_overlay(state, ui, "MENU")
    render(state, ui)

    ui.overlay_btn.MouseButton1Click:Connect(
        function() start_match(dOS, state, ui) end
    )

    if dOS.keyboard then
        state.keyboard_conn = dOS.keyboard.UserInput:Connect(
            function(input, _userId)
                if input.UserInputState == Enum.UserInputState.Begin then
                    state.held[input.KeyCode] = true
                elseif input.UserInputState == Enum.UserInputState.End then
                    state.held[input.KeyCode] = nil
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
