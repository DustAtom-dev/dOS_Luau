--[[
    "2048 game for dOS"
    
    @module 2048
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
    SIZE = 4,
    CELL_MIN = 50, -- minimum tile side in pixels
    CELL_MAX = 130, -- maximum tile side in pixels
    GAP = 10, -- gap between tiles and board border
    HEADER_H = 52,
    WIN_W = 464,
    WIN_H = 564,
    MIN_W = 280,
    MIN_H = 340,
    TWEEN_MOVE = 0.10, -- tile slide duration (seconds)
    TWEEN_POP = 0.15, -- merge / spawn pop duration (seconds)
}

--- COLORS

local C = {
    WIN_BG = Color3.fromRGB(11, 11, 19),
    HDR_BG = Color3.fromRGB(7, 7, 14),
    CELL_EMPTY = Color3.fromRGB(30, 32, 52),
    ACCENT = Color3.fromRGB(99, 102, 241),
    ACCENT_HOV = Color3.fromRGB(122, 125, 255),
    ANIM_OFF = Color3.fromRGB(36, 38, 64),
    TXT_MAIN = Color3.fromRGB(240, 240, 255),
    TXT_DIM = Color3.fromRGB(110, 110, 155),
    SCORE_GRN = Color3.fromRGB(74, 222, 128),
    DIVIDER = Color3.fromRGB(38, 38, 62),
    WIN_GOLD = Color3.fromRGB(250, 204, 21),
    DANGER = Color3.fromRGB(239, 68, 68),
    OVERLAY_BG = Color3.fromRGB(8, 8, 16),
}

-- per-value tile colors
-- values above 2048 fall back to TILE_DEFAULT
local TILE_STYLE = {
    [2] = {
        bg = Color3.fromRGB(74, 78, 122),
        fg = Color3.fromRGB(215, 218, 255),
    },
    [4] = {
        bg = Color3.fromRGB(98, 103, 160),
        fg = Color3.fromRGB(225, 228, 255),
    },
    [8] = {
        bg = Color3.fromRGB(205, 118, 52),
        fg = Color3.fromRGB(255, 242, 225),
    },
    [16] = {
        bg = Color3.fromRGB(222, 91, 42),
        fg = Color3.fromRGB(255, 240, 220),
    },
    [32] = {
        bg = Color3.fromRGB(218, 60, 60),
        fg = Color3.fromRGB(255, 235, 235),
    },
    [64] = {
        bg = Color3.fromRGB(200, 42, 88),
        fg = Color3.fromRGB(255, 225, 238),
    },
    [128] = {
        bg = Color3.fromRGB(188, 150, 20),
        fg = Color3.fromRGB(255, 246, 200),
    },
    [256] = {
        bg = Color3.fromRGB(210, 172, 28),
        fg = Color3.fromRGB(255, 250, 210),
    },
    [512] = {
        bg = Color3.fromRGB(32, 178, 205),
        fg = Color3.fromRGB(205, 248, 255),
    },
    [1024] = {
        bg = Color3.fromRGB(46, 210, 172),
        fg = Color3.fromRGB(210, 255, 248),
    },
    [2048] = {
        bg = Color3.fromRGB(238, 214, 74),
        fg = Color3.fromRGB(65, 50, 8),
    },
}

local TILE_DEFAULT = {
    bg = Color3.fromRGB(122, 58, 195),
    fg = Color3.fromRGB(255, 235, 255),
}

--- SAVING

local function save_best(dOS, score)
    if not dOS.disk then return false end

    local ok, err = pcall(
        dOS.disk.Write,
        dOS.disk,
        dOS.GAMES_DATA.GLOBAL_GAMES_DATA_FOLDER
            .. dOS.GAMES_DATA["2048_DISK_FILE"],
        tostring(score)
    )

    if not ok then warn("[2048] SAVE: " .. tostring(err)) end

    return ok
end

local function load_best(dOS)
    if not dOS.disk then return 0 end

    local ok, data = pcall(
        dOS.disk.Read,
        dOS.disk,
        dOS.GAMES_DATA.GLOBAL_GAMES_DATA_FOLDER
            .. dOS.GAMES_DATA["2048_DISK_FILE"]
    )

    if not ok or not data then return 0 end

    return tonumber(data)
end

--- GAME

local function init_grid()
    local g = {}

    for y = 1, CONFIG.SIZE do
        g[y] = {}

        for x = 1, CONFIG.SIZE do
            g[y][x] = 0
        end
    end

    return g
end

local function spawn_tile(grid)
    local empty = {}

    for y = 1, CONFIG.SIZE do
        for x = 1, CONFIG.SIZE do
            if grid[y][x] == 0 then empty[#empty + 1] = { x = x, y = y } end
        end
    end

    if #empty == 0 then return nil, nil end

    local pick = empty[math.random(1, #empty)]
    grid[pick.y][pick.x] = math.random() < 0.9 and 2 or 4

    return pick.x, pick.y
end

local function process_line(tiles, positions)
    local nz = {}

    for _, t in ipairs(tiles) do
        if t.v ~= 0 then nz[#nz + 1] = t end
    end

    local moves = {}
    local score = 0
    local slot = 1
    local i = 1

    while i <= #nz do
        local p = positions[slot]

        if nz[i + 1] and nz[i].v == nz[i + 1].v then
            local mv = nz[i].v * 2
            score = score + mv

            moves[#moves + 1] = {
                fx = nz[i].gx,
                fy = nz[i].gy,
                tx = p.gx,
                ty = p.gy,
                follower = false,
                merged_val = mv,
            }

            moves[#moves + 1] = {
                fx = nz[i + 1].gx,
                fy = nz[i + 1].gy,
                tx = p.gx,
                ty = p.gy,
                follower = true,
                merged_val = 0,
            }

            i = i + 2
        else
            moves[#moves + 1] = {
                fx = nz[i].gx,
                fy = nz[i].gy,
                tx = p.gx,
                ty = p.gy,
                follower = false,
                merged_val = 0,
            }

            i = i + 1
        end

        slot = slot + 1
    end

    return moves, score
end

local function slide(grid, dir)
    local S = CONFIG.SIZE
    local new_grid = init_grid()
    local all_moves = {}
    local total = 0

    local function make_line(xs, ys)
        local tiles, positions = {}, {}

        for i = 1, #xs do
            tiles[i] = { gx = xs[i], gy = ys[i], v = grid[ys[i]][xs[i]] }
            positions[i] = { gx = xs[i], gy = ys[i] }
        end

        return tiles, positions
    end

    local function add_line(xs, ys)
        local moves, score = process_line(make_line(xs, ys))
        total = total + score

        for _, m in ipairs(moves) do
            all_moves[#all_moves + 1] = m

            if not m.follower then
                new_grid[m.ty][m.tx] = m.merged_val > 0 and m.merged_val
                    or grid[m.fy][m.fx]
            end
        end
    end

    if dir == "left" or dir == "right" then
        for y = 1, S do
            local xs, ys, j = {}, {}, 1

            if dir == "left" then
                for x = 1, S do
                    xs[x] = x
                    ys[x] = y
                end
            else
                for x = S, 1, -1 do
                    xs[j] = x
                    ys[j] = y
                    j = j + 1
                end
            end

            add_line(xs, ys)
        end
    else
        for x = 1, S do
            local xs, ys, j = {}, {}, 1

            if dir == "up" then
                for y = 1, S do
                    xs[y] = x
                    ys[y] = y
                end
            else
                for y = S, 1, -1 do
                    xs[j] = x
                    ys[j] = y
                    j = j + 1
                end
            end

            add_line(xs, ys)
        end
    end

    return new_grid, all_moves, total
end

local function check_win(grid)
    for y = 1, CONFIG.SIZE do
        for x = 1, CONFIG.SIZE do
            if grid[y][x] == 2048 then return true end
        end
    end

    return false
end

local function check_dead(grid)
    local S = CONFIG.SIZE

    for y = 1, S do
        for x = 1, S do
            if grid[y][x] == 0 then return false end

            if x < S and grid[y][x] == grid[y][x + 1] then return false end

            if y < S and grid[y][x] == grid[y + 1][x] then return false end
        end
    end

    return true
end

--- BOARD

local function compute_layout(avail_w, avail_h)
    local g = CONFIG.GAP
    local S = CONFIG.SIZE
    local cs_w = math.floor((avail_w - (S + 1) * g) / S)
    local cs_h = math.floor((avail_h - (S + 1) * g) / S)
    local cs = math.max(
        CONFIG.CELL_MIN,
        math.min(CONFIG.CELL_MAX, math.min(cs_w, cs_h))
    )
    local bw = S * cs + (S + 1) * g -- board side
    local ox = math.max(0, math.floor((avail_w - bw) / 2))
    local oy = math.max(0, math.floor((avail_h - bw) / 2))

    return cs, g, ox, oy
end

local function tile_px(gx, gy, layout)
    local g = layout.gap

    return layout.ox + g + (gx - 1) * (layout.cs + g),
        layout.oy + g + (gy - 1) * (layout.cs + g)
end

--- RENDERING

local function tile_font_size(cs, value)
    local d = #tostring(value)

    if d <= 2 then
        return math.floor(cs * 0.50)
    elseif d == 3 then
        return math.floor(cs * 0.40)
    elseif d == 4 then
        return math.floor(cs * 0.33)
    else
        return math.floor(cs * 0.27)
    end
end

local function create_tile_frame(dOS, state, ui, gx, gy, value, animate_pop)
    local lay = state.layout
    local cs = lay.cs
    local px, py = tile_px(gx, gy, lay)
    local style = TILE_STYLE[value] or TILE_DEFAULT
    local corner = math.max(4, math.floor(cs * 0.10))

    local init_sz, init_px, init_py = cs, px, py

    if animate_pop then
        local small = math.floor(cs * 0.68)
        local offset = math.floor((cs - small) / 2)

        init_sz = small
        init_px = px + offset
        init_py = py + offset
    end

    local frame = dOS.create_gui_element(dOS, "Frame", {
        Parent = ui.game_area,
        Size = UDim2.fromOffset(init_sz, init_sz),
        Position = UDim2.fromOffset(init_px, init_py),
        BackgroundColor3 = style.bg,
        BorderSizePixel = 0,
        ZIndex = 3,
    })

    dOS.create_gui_element(dOS, "UICorner", {
        Parent = frame,
        CornerRadius = UDim.new(0, corner),
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = frame,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = value,
        TextColor3 = style.fg,
        TextSize = tile_font_size(cs, value),
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 4,
    })

    if not ui.tile_frames[gy] then ui.tile_frames[gy] = {} end

    ui.tile_frames[gy][gx] = frame

    if animate_pop then
        local info = dOS.TweenInfo.new(
            CONFIG.TWEEN_POP,
            Enum.EasingStyle.Back,
            Enum.EasingDirection.Out
        )

        local t = dOS.Tween.new(frame, {
            Size = UDim2.fromOffset(cs, cs),
            Position = UDim2.fromOffset(px, py),
        }, info)

        t:Play()
        state.active_tweens[#state.active_tweens + 1] = t
    end

    return frame
end

local function rebuild_tiles(dOS, state, ui, merge_set)
    local S = CONFIG.SIZE

    for y = 1, S do
        if ui.tile_frames[y] then
            for x = 1, S do
                local f = ui.tile_frames[y][x]

                if f then f:Destroy() end
            end
        end

        ui.tile_frames[y] = {}
    end

    for y = 1, S do
        for x = 1, S do
            local v = state.grid[y][x]

            if v ~= 0 then
                local pop = state.anim_enabled
                    and merge_set[y * (S + 1) + x] == true

                create_tile_frame(dOS, state, ui, x, y, v, pop)
            end
        end
    end
end

local function relayout(state, ui)
    if not ui.bg_cells or not ui.game_area then return end

    local sz = ui.game_area.AbsoluteSize
    local cs, gap, ox, oy = compute_layout(sz.X, sz.Y)
    state.layout = { cs = cs, gap = gap, ox = ox, oy = oy }

    for _, t in ipairs(state.active_tweens) do
        pcall(t.Cancel, t)
    end

    state.active_tweens = {}
    state.gen = state.gen + 1
    state.anim_busy = false

    local corner = math.max(4, math.floor(cs * 0.10))
    local S = CONFIG.SIZE

    for y = 1, S do
        for x = 1, S do
            local px, py = tile_px(x, y, state.layout)
            local bg = ui.bg_cells[y][x]

            bg.Size = UDim2.fromOffset(cs, cs)
            bg.Position = UDim2.fromOffset(px, py)

            local uc = bg:FindFirstChildOfClass("UICorner")
            if uc then uc.CornerRadius = UDim.new(0, corner) end
        end
    end

    for y = 1, S do
        if ui.tile_frames[y] then
            for x = 1, S do
                local f = ui.tile_frames[y][x]

                if f then
                    local px, py = tile_px(x, y, state.layout)

                    f.Size = UDim2.fromOffset(cs, cs)
                    f.Position = UDim2.fromOffset(px, py)

                    local lbl = f:FindFirstChildOfClass("TextLabel")
                    if lbl then
                        lbl.TextSize = tile_font_size(cs, state.grid[y][x])
                    end

                    local uc = f:FindFirstChildOfClass("UICorner")
                    if uc then uc.CornerRadius = UDim.new(0, corner) end
                end
            end
        end
    end
end

--- UI

local function refresh_header(state, ui)
    ui.score_num.Text = state.score
    ui.best_num.Text = state.best_score
end

local function set_overlay(state, ui, phase)
    if phase == "NONE" then
        ui.overlay.Visible = false
        return
    end

    ui.overlay.Visible = true
    ui.overlay_num.Visible = (phase == "MENU")
    ui.overlay_title.Visible = (phase ~= "MENU")

    if phase == "MENU" then
        ui.overlay_btn_lbl.Text = "PLAY"
        local has_best = state.best_score > 0

        ui.overlay_sub_lbl.Visible = has_best
        ui.overlay_sub_num.Visible = has_best

        if has_best then
            ui.overlay_sub_lbl.Text = "BEST"
            ui.overlay_sub_num.Text = state.best_score
            ui.overlay_sub_num.TextColor3 = C.WIN_GOLD
        end
    elseif phase == "WIN" then
        ui.overlay_title.Text = "YOU WIN"
        ui.overlay_title.TextColor3 = C.WIN_GOLD
        ui.overlay_btn_lbl.Text = "KEEP GOING"
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

local function build_ui(dOS, ca, state, ui)
    ca.BackgroundColor3 = C.WIN_BG
    ca.ClipsDescendants = true

    -- header

    local hdr = dOS.create_gui_element(dOS, "Frame", {
        Parent = ca,
        Size = UDim2.new(1, 0, 0, CONFIG.HEADER_H),
        BackgroundColor3 = C.HDR_BG,
        BorderSizePixel = 0,
        ZIndex = 5,
    })

    dOS.create_gui_element(dOS, "Frame", {
        Parent = hdr,
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = C.DIVIDER,
        BorderSizePixel = 0,
        ZIndex = 6,
    })

    local function make_thingy(parent, pos, caption, val_color)
        local thing = dOS.create_gui_element(dOS, "Frame", {
            Parent = parent,
            Size = UDim2.fromOffset(72, CONFIG.HEADER_H),
            Position = pos,
            BackgroundColor3 = C.HDR_BG,
            BorderSizePixel = 0,
            ZIndex = 6,
        })

        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = thing,
            Size = UDim2.new(1, 0, 0, 14),
            Position = UDim2.fromOffset(0, 8),
            BackgroundTransparency = 1,
            Text = caption,
            TextColor3 = C.TXT_DIM,
            TextSize = 10,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 7,
        })

        return dOS.create_gui_element(dOS, "TextLabel", {
            Parent = thing,
            Size = UDim2.new(1, 0, 0, 26),
            Position = UDim2.fromOffset(0, 20),
            BackgroundTransparency = 1,
            Text = 0,
            TextColor3 = val_color,
            TextSize = 20,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 7,
        })
    end

    -- score label anchored to the left
    -- best score anchored to the right
    ui.score_num =
        make_thingy(hdr, UDim2.fromOffset(14, 0), "SCORE", C.SCORE_GRN)
    ui.best_num =
        make_thingy(hdr, UDim2.new(1, -(14 + 72), 0, 0), "BEST", C.WIN_GOLD)

    local ab
    ab = dOS.create_gui_element(dOS, "TextButton", {
        Parent = hdr,
        Size = UDim2.fromOffset(58, 26),
        Position = UDim2.new(0.5, -29, 0.5, -13),
        BackgroundColor3 = C.ACCENT,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 6,
        OnEnter = function()
            ab.BackgroundColor3 = state.anim_enabled and C.ACCENT_HOV
                or C.ANIM_OFF
        end,
        OnLeave = function()
            ab.BackgroundColor3 = state.anim_enabled and C.ACCENT or C.ANIM_OFF
        end,
    })

    dOS.create_gui_element(dOS, "UICorner", {
        Parent = ab,
        CornerRadius = UDim.new(0, 7),
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = ab,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "ANIM",
        TextColor3 = C.TXT_MAIN,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 7,
    })

    ui.anim_btn = ab

    ui.game_area = dOS.create_gui_element(dOS, "Frame", {
        Parent = ca,
        Size = UDim2.new(1, 0, 1, -CONFIG.HEADER_H),
        Position = UDim2.fromOffset(0, CONFIG.HEADER_H),
        BackgroundColor3 = C.WIN_BG,
        BorderSizePixel = 0,
        ZIndex = 2,
        ClipsDescendants = true,
    })

    -- never destroyed
    ui.bg_cells = {}
    ui.tile_frames = {}

    for y = 1, CONFIG.SIZE do
        ui.bg_cells[y] = {}
        ui.tile_frames[y] = {}

        for x = 1, CONFIG.SIZE do
            local bg = dOS.create_gui_element(dOS, "Frame", {
                Parent = ui.game_area,
                Size = UDim2.fromOffset(18, 18), -- placeholder
                Position = UDim2.fromOffset(0, 0),
                BackgroundColor3 = C.CELL_EMPTY,
                BorderSizePixel = 0,
                ZIndex = 2,
            })

            dOS.create_gui_element(dOS, "UICorner", {
                Parent = bg,
                CornerRadius = UDim.new(0, 4),
            })

            ui.bg_cells[y][x] = bg
        end
    end

    ui.overlay = dOS.create_gui_element(dOS, "Frame", {
        Parent = ui.game_area,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = C.OVERLAY_BG,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        ZIndex = 20,
        Visible = false,
    })

    ui.overlay_num = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = ui.overlay,
        Size = UDim2.new(1, 0, 0, 60),
        Position = UDim2.fromOffset(0, 42),
        BackgroundTransparency = 1,
        Text = 2048,
        TextColor3 = C.WIN_GOLD,
        TextSize = 54,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 21,
    })

    ui.overlay_title = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = ui.overlay,
        Size = UDim2.new(1, 0, 0, 48),
        Position = UDim2.fromOffset(0, 48),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = C.TXT_MAIN,
        TextSize = 38,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 21,
        Visible = false,
    })

    ui.overlay_sub_lbl = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = ui.overlay,
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.fromOffset(0, 122),
        BackgroundTransparency = 1,
        Text = "BEST",
        TextColor3 = C.TXT_DIM,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 21,
        Visible = false,
    })

    ui.overlay_sub_num = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = ui.overlay,
        Size = UDim2.new(1, 0, 0, 32),
        Position = UDim2.fromOffset(0, 138),
        BackgroundTransparency = 1,
        Text = 0,
        TextColor3 = C.WIN_GOLD,
        TextSize = 28,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 21,
        Visible = false,
    })

    local ob
    ob = dOS.create_gui_element(dOS, "TextButton", {
        Parent = ui.overlay,
        Size = UDim2.fromOffset(148, 40),
        Position = UDim2.new(0.5, -74, 1, -58),
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
end

--- CONTROL

local function start_game(dOS, state, ui)
    for _, t in ipairs(state.active_tweens) do
        pcall(t.Cancel, t)
    end

    state.active_tweens = {}
    state.grid = init_grid()
    state.score = 0
    state.phase = "PLAYING"
    state.anim_busy = false
    state.won_already = false
    state.gen = state.gen + 1

    spawn_tile(state.grid)
    spawn_tile(state.grid)

    set_overlay(state, ui, "NONE")
    rebuild_tiles(dOS, state, ui, {})
    refresh_header(state, ui)
    relayout(state, ui)
end

local function handle_input(dir, dOS, state, ui)
    if state.anim_busy or state.phase ~= "PLAYING" then return end

    local new_grid, moves, score_gain = slide(state.grid, dir)

    local changed = false
    for y = 1, CONFIG.SIZE do
        for x = 1, CONFIG.SIZE do
            if new_grid[y][x] ~= state.grid[y][x] then
                changed = true
                break
            end
        end

        if changed then break end
    end

    if not changed then return end

    state.anim_busy = true
    state.gen = state.gen + 1
    local my_gen = state.gen

    local S = CONFIG.SIZE
    local merge_set = {}

    for _, m in ipairs(moves) do
        if m.merged_val > 0 then merge_set[m.ty * (S + 1) + m.tx] = true end
    end

    -- animation

    if state.anim_enabled then
        local move_info = dOS.TweenInfo.new(
            CONFIG.TWEEN_MOVE,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        )

        for _, m in ipairs(moves) do
            local frame = ui.tile_frames[m.fy] and ui.tile_frames[m.fy][m.fx]

            if frame then
                -- follower is under the leader
                frame.ZIndex = m.follower and 3 or 4
                local px, py = tile_px(m.tx, m.ty, state.layout)

                local t = dOS.Tween.new(
                    frame,
                    { Position = UDim2.fromOffset(px, py) },
                    move_info
                )
                t:Play()

                state.active_tweens[#state.active_tweens + 1] = t
            end
        end

        task.wait(CONFIG.TWEEN_MOVE + 0.02)
        if state.gen ~= my_gen then return end
    end

    ---

    state.grid = new_grid
    state.score = state.score + score_gain

    if state.score > state.best_score then state.best_score = state.score end

    state.active_tweens = {}

    rebuild_tiles(dOS, state, ui, merge_set)
    refresh_header(state, ui)

    local nx, ny = spawn_tile(state.grid)
    if nx then
        create_tile_frame(
            dOS,
            state,
            ui,
            nx,
            ny,
            state.grid[ny][nx],
            state.anim_enabled
        )
    end

    if state.anim_enabled then
        task.wait(CONFIG.TWEEN_POP + 0.02)
        if state.gen ~= my_gen then return end
    end

    -- check win or death

    if not state.won_already and check_win(state.grid) then
        state.won_already = true
        state.phase = "WIN"
        save_best(dOS, state.best_score)
        state.anim_busy = false
        set_overlay(state, ui, "WIN")

        return
    end

    if check_dead(state.grid) then
        state.phase = "DEAD"
        save_best(dOS, state.best_score)
        state.anim_busy = false
        set_overlay(state, ui, "DEAD")

        return
    end

    state.anim_busy = false
end

--- API

local KEY_MAP = {
    [Enum.KeyCode.W] = "up",
    [Enum.KeyCode.S] = "down",
    [Enum.KeyCode.A] = "left",
    [Enum.KeyCode.D] = "right",
    [Enum.KeyCode.Up] = "up",
    [Enum.KeyCode.Down] = "down",
    [Enum.KeyCode.Left] = "left",
    [Enum.KeyCode.Right] = "right",
}

function M.create(dOS)
    if not dOS.keyboard then
        dOS.MessageBox.error(
            dOS,
            "Hardware error",
            "2048 requires a Keyboard.\nPlease connect one and retry."
        )
    end

    local window_frame, content_area = dOS.create_basic_window(
        dOS,
        "2048",
        CONFIG.WIN_W,
        CONFIG.WIN_H,
        true,
        true,
        true,
        true,
        CONFIG.MIN_W,
        CONFIG.MIN_H
    )

    if not window_frame then return end

    local state = {
        grid = init_grid(),
        score = 0,
        best_score = load_best(dOS),
        phase = "MENU",
        anim_enabled = true,
        anim_busy = false,
        won_already = false,
        gen = 0,
        active_tweens = {},
        layout = { cs = 80, gap = CONFIG.GAP, ox = 0, oy = 0 },
        keyboard_conn = nil,
    }

    local ui = {
        anim_btn = nil,
        overlay_btn = nil,
    }

    build_ui(dOS, content_area, state, ui)
    relayout(state, ui)
    set_overlay(state, ui, "MENU")
    refresh_header(state, ui)

    ui.anim_btn.MouseButton1Click:Connect(function()
        state.anim_enabled = not state.anim_enabled
        ui.anim_btn.BackgroundColor3 = state.anim_enabled and C.ACCENT
            or C.ANIM_OFF
    end)

    ui.overlay_btn.MouseButton1Click:Connect(function()
        if state.phase == "MENU" or state.phase == "DEAD" then
            start_game(dOS, state, ui)
        elseif state.phase == "WIN" then
            state.phase = "PLAYING" -- continue beyond 2048
            set_overlay(state, ui, "NONE")
        end
    end)

    if dOS.keyboard then
        state.keyboard_conn = dOS.keyboard.UserInput:Connect(
            function(input, _userId)
                if input.UserInputState ~= Enum.UserInputState.Begin then
                    return
                end

                local dir = KEY_MAP[input.KeyCode]
                if dir then task.spawn(handle_input, dir, dOS, state, ui) end
            end
        )
    end

    content_area
        :GetPropertyChangedSignal("AbsoluteSize")
        :Connect(function() relayout(state, ui) end)

    window_frame.Destroying:Connect(function()
        if state.keyboard_conn then
            pcall(state.keyboard_conn.Disconnect, state.keyboard_conn)
        end

        for _, t in ipairs(state.active_tweens) do
            pcall(t.Cancel, t)
        end
    end)
end

return M

-- EOF
