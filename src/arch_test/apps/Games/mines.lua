--[[
    "Minesweeper game for dOS"
    
    @module mines
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

local DIFF = {
    { label = "EASY", cols = 9, rows = 9, mines = 10 },
    { label = "MEDIUM", cols = 16, rows = 16, mines = 40 },
    { label = "HARD", cols = 30, rows = 16, mines = 99 },
    { label = "EXPERT", cols = 30, rows = 20, mines = 145 },
}

local CONFIG = {
    CELL_MIN = 14,
    CELL_MAX = 42,
    CELL_GAP = 2,
    HEADER_H = 52,
    SIDE_PAD = 14,
    VERT_PAD = 10,
    WIN_W_DEF = 480,
    WIN_H_DEF = 520,
    WIN_MIN_W = 280,
    WIN_MIN_H = 300,
}

--- COLORS

local C = {
    WIN_BG = Color3.fromRGB(11, 11, 19),
    HDR_BG = Color3.fromRGB(7, 7, 14),
    CELL_HIDDEN = Color3.fromRGB(55, 57, 82),
    CELL_REVEAL = Color3.fromRGB(28, 28, 52),
    CELL_HIT = Color3.fromRGB(200, 40, 40),
    CELL_WRONG = Color3.fromRGB(70, 18, 18),
    ACCENT = Color3.fromRGB(99, 102, 241),
    ACCENT_HOV = Color3.fromRGB(122, 125, 255),
    DIFF_IDLE = Color3.fromRGB(35, 37, 62),
    DIFF_HOV = Color3.fromRGB(55, 57, 90),
    TXT_MAIN = Color3.fromRGB(240, 240, 255),
    TXT_DIM = Color3.fromRGB(110, 110, 155),
    OVERLAY_BG = Color3.fromRGB(8, 8, 16),
    WIN_GOLD = Color3.fromRGB(250, 204, 21),
    DANGER = Color3.fromRGB(239, 68, 68),
    DIVIDER = Color3.fromRGB(38, 38, 62),
    FLAG_COL = Color3.fromRGB(251, 113, 27),
    MINE_COL = Color3.fromRGB(210, 210, 235),
    NUM = {
        Color3.fromRGB(100, 150, 255), -- 1  blue
        Color3.fromRGB(74, 222, 128), -- 2  green
        Color3.fromRGB(239, 68, 68), -- 3  red
        Color3.fromRGB(160, 100, 255), -- 4  purple
        Color3.fromRGB(239, 148, 68), -- 5  orange
        Color3.fromRGB(34, 211, 238), -- 6  cyan
        Color3.fromRGB(244, 114, 182), -- 7  pink
        Color3.fromRGB(180, 180, 200), -- 8  grey
    },
}

--- SAVING

local function save_best_times(dOS, best_times)
    if not dOS.disk then return false end

    local parts = {}

    for _, t in ipairs(best_times) do
        parts[#parts + 1] = (t == math.huge) and "0" or tostring(math.floor(t))
    end

    local ok, err = pcall(
        dOS.disk.Write,
        dOS.disk,
        dOS.GAMES_DATA.GLOBAL_GAMES_DATA_FOLDER
            .. dOS.GAMES_DATA.MINESWEEPER_DISK_FILE,
        table.concat(parts, ",")
    )

    if not ok then warn("[Minesweeper] SAVE: Failed - " .. tostring(err)) end

    return ok
end

local function load_best_times(dOS)
    local result = {}

    for i = 1, 4 do
        result[i] = math.huge
    end

    if not dOS.disk then return result end

    local ok, data = pcall(
        dOS.disk.Read,
        dOS.disk,
        dOS.GAMES_DATA.GLOBAL_GAMES_DATA_FOLDER
            .. dOS.GAMES_DATA.MINESWEEPER_DISK_FILE
    )

    if not ok or not data then return result end

    local i = 1

    for part in data:gmatch("[^,]+") do
        local n = tonumber(part)

        if n and n > 0 then result[i] = n end

        i = i + 1

        if i > 4 then break end
    end

    return result
end

--- GAME

local function neighbours(cx, cy, cols, rows)
    local nb = {}

    for dy = -1, 1 do
        for dx = -1, 1 do
            if not (dx == 0 and dy == 0) then
                local nx, ny = cx + dx, cy + dy

                if nx >= 1 and nx <= cols and ny >= 1 and ny <= rows then
                    nb[#nb + 1] = { x = nx, y = ny }
                end
            end
        end
    end

    return nb
end

local function init_grid(cols, rows)
    local grid = {}

    for y = 1, rows do
        grid[y] = {}

        for x = 1, cols do
            grid[y][x] = {
                mine = false,
                revealed = false,
                flagged = false,
                adjacent = 0,
            }
        end
    end

    return grid
end

local function place_mines(grid, cols, rows, mine_count, sx, sy)
    local safe = {}
    safe[sy * (cols + 1) + sx] = true

    for _, nb in ipairs(neighbours(sx, sy, cols, rows)) do
        safe[nb.y * (cols + 1) + nb.x] = true
    end

    local pool = {}

    for y = 1, rows do
        for x = 1, cols do
            if not safe[y * (cols + 1) + x] then
                pool[#pool + 1] = { x = x, y = y }
            end
        end
    end

    for i = 1, math.min(mine_count, #pool) do
        local j = math.random(i, #pool)
        pool[i], pool[j] = pool[j], pool[i]
        grid[pool[i].y][pool[i].x].mine = true
    end

    for y = 1, rows do
        for x = 1, cols do
            if not grid[y][x].mine then
                local count = 0

                for _, nb in ipairs(neighbours(x, y, cols, rows)) do
                    if grid[nb.y][nb.x].mine then count = count + 1 end
                end

                grid[y][x].adjacent = count
            end
        end
    end
end

local function flood_reveal(grid, cols, rows, sx, sy)
    local queue = { { x = sx, y = sy } }
    local head = 1

    while head <= #queue do
        local pos = queue[head]
        head = head + 1
        local cell = grid[pos.y][pos.x]

        if not cell.revealed and not cell.flagged then
            cell.revealed = true

            if cell.adjacent == 0 and not cell.mine then
                for _, nb in ipairs(neighbours(pos.x, pos.y, cols, rows)) do
                    if not grid[nb.y][nb.x].revealed then
                        queue[#queue + 1] = nb
                    end
                end
            end
        end
    end
end

local function check_win(grid, cols, rows, mine_count)
    local revealed = 0

    for y = 1, rows do
        for x = 1, cols do
            if grid[y][x].revealed then revealed = revealed + 1 end
        end
    end

    return revealed == cols * rows - mine_count
end

local function expose_mines(grid, cols, rows)
    for y = 1, rows do
        for x = 1, cols do
            if grid[y][x].mine then grid[y][x].revealed = true end
        end
    end
end

--- BOARD

local function compute_layout(cols, rows, avail_w, avail_h)
    local gap = CONFIG.CELL_GAP
    local cs_w = math.floor((avail_w - CONFIG.SIDE_PAD * 2 + gap) / cols) - gap
    local cs_h = math.floor((avail_h - CONFIG.VERT_PAD * 2 + gap) / rows) - gap
    local cs = math.max(
        CONFIG.CELL_MIN,
        math.min(CONFIG.CELL_MAX, math.min(cs_w, cs_h))
    )
    local stride = cs + gap
    local ox = math.floor((avail_w - (cols * stride - gap)) / 2)
    local oy = math.floor((avail_h - (rows * stride - gap)) / 2)

    return cs, stride, ox, oy
end

local function relayout(state, ui)
    if not ui.cells or not ui.game_area then return end

    local sz = ui.game_area.AbsoluteSize
    local cs, stride, ox, oy =
        compute_layout(state.cols, state.rows, sz.X, sz.Y)
    local txt_sz = math.max(8, math.floor(cs * 0.56))
    local dot_sz = math.max(4, math.floor(cs * 0.38))
    local dot_off = math.floor((cs - dot_sz) / 2)
    local dot_pos = UDim2.fromOffset(dot_off, dot_off)
    local dot_size = UDim2.fromOffset(dot_sz, dot_sz)

    for y = 1, state.rows do
        for x = 1, state.cols do
            local cdata = ui.cells[y][x]

            cdata.btn.Size = UDim2.fromOffset(cs, cs)
            cdata.btn.Position =
                UDim2.fromOffset(ox + (x - 1) * stride, oy + (y - 1) * stride)
            cdata.num_lbl.TextSize = txt_sz
            cdata.flag_dot.Size = dot_size
            cdata.flag_dot.Position = dot_pos
            cdata.mine_dot.Size = dot_size
            cdata.mine_dot.Position = dot_pos
        end
    end
end

--- RENDERING

local function render_cell(cell, cdata, phase, is_hit)
    if cell.revealed then
        if cell.mine then
            cdata.btn.BackgroundColor3 = is_hit and C.CELL_HIT or C.CELL_REVEAL
            cdata.mine_dot.Visible = true
            cdata.flag_dot.Visible = false
            cdata.num_lbl.Visible = false
        else
            cdata.btn.BackgroundColor3 = C.CELL_REVEAL
            cdata.mine_dot.Visible = false
            cdata.flag_dot.Visible = false

            local adj = cell.adjacent

            if adj > 0 then
                cdata.num_lbl.Text = adj
                cdata.num_lbl.TextColor3 = C.NUM[adj] or C.TXT_MAIN
                cdata.num_lbl.Visible = true
            else
                cdata.num_lbl.Visible = false
            end
        end
    elseif cell.flagged then
        cdata.btn.BackgroundColor3 = (phase == "DEAD" and not cell.mine)
                and C.CELL_WRONG
            or C.CELL_HIDDEN
        cdata.flag_dot.Visible = true
        cdata.mine_dot.Visible = false
        cdata.num_lbl.Visible = false
    else
        cdata.btn.BackgroundColor3 = C.CELL_HIDDEN
        cdata.flag_dot.Visible = false
        cdata.mine_dot.Visible = (phase == "DEAD" and cell.mine)
        cdata.num_lbl.Visible = false
    end
end

local function render_grid(state, ui)
    for y = 1, state.rows do
        for x = 1, state.cols do
            render_cell(
                state.grid[y][x],
                ui.cells[y][x],
                state.phase,
                y == state.hit_y and x == state.hit_x
            )
        end
    end
end

local function refresh_header(state, ui)
    ui.mines_num.Text = state.mines - state.flags_placed

    if state.phase == "PLAYING" and state.started then
        ui.time_num.Text = math.floor(os.clock() - state.start_time)
    elseif state.phase == "WIN" or state.phase == "DEAD" then
        ui.time_num.Text = math.floor(state.elapsed)
    else
        ui.time_num.Text = 0
    end
end

--- HELPERS

local function make_stat_pill(parent, dOS, pos, caption, value_color)
    local pill = dOS.create_gui_element(dOS, "Frame", {
        Parent = parent,
        Size = UDim2.fromOffset(72, CONFIG.HEADER_H),
        Position = pos,
        BackgroundColor3 = C.HDR_BG,
        BorderSizePixel = 0,
        ZIndex = 3,
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = pill,
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.fromOffset(0, 8),
        BackgroundTransparency = 1,
        Text = caption,
        TextColor3 = C.TXT_DIM,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 4,
    })

    return dOS.create_gui_element(dOS, "TextLabel", {
        Parent = pill,
        Size = UDim2.new(1, 0, 0, 26),
        Position = UDim2.fromOffset(0, 20),
        BackgroundTransparency = 1,
        Text = 0,
        TextColor3 = value_color,
        TextSize = 21,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 4,
    })
end

--- UI

local function set_overlay(state, ui, phase)
    if phase == "NONE" then
        ui.overlay.Visible = false
        return
    end

    ui.overlay.Visible = true
    ui.diff_container.Visible = (phase == "MENU")

    if phase == "MENU" then
        ui.overlay_title.Text = "MINESWEEPER"
        ui.overlay_title.TextColor3 = C.TXT_MAIN
        ui.overlay_btn_lbl.Text = "PLAY"
        ui.overlay_sub_lbl.Text = "MINES"
        ui.overlay_sub_num.Text = DIFF[state.diff_idx].mines
        ui.overlay_sub_num.TextColor3 = C.FLAG_COL
        ui.overlay_sub_lbl.Visible = true
        ui.overlay_sub_num.Visible = true

        local bt = state.best_times[state.diff_idx]
        local has_best = (bt < math.huge)

        ui.overlay_best_lbl.Visible = has_best
        ui.overlay_best_num.Visible = has_best

        if has_best then ui.overlay_best_num.Text = math.floor(bt) end
    elseif phase == "WIN" then
        ui.overlay_title.Text = "YOU WIN"
        ui.overlay_title.TextColor3 = C.WIN_GOLD
        ui.overlay_btn_lbl.Text = "PLAY AGAIN"
        ui.overlay_sub_lbl.Text = "TIME"
        ui.overlay_sub_num.Text = math.floor(state.elapsed)
        ui.overlay_sub_num.TextColor3 = C.WIN_GOLD
        ui.overlay_sub_lbl.Visible = true
        ui.overlay_sub_num.Visible = true

        local bt = state.best_times[state.diff_idx]
        local has_best = (bt < math.huge)

        ui.overlay_best_lbl.Visible = has_best
        ui.overlay_best_num.Visible = has_best

        if has_best then ui.overlay_best_num.Text = math.floor(bt) end
    elseif phase == "DEAD" then
        ui.overlay_title.Text = "GAME OVER"
        ui.overlay_title.TextColor3 = C.DANGER
        ui.overlay_btn_lbl.Text = "PLAY AGAIN"
        ui.overlay_sub_lbl.Text = "TIME"
        ui.overlay_sub_num.Text = math.floor(state.elapsed)
        ui.overlay_sub_num.TextColor3 = C.TXT_MAIN
        ui.overlay_sub_lbl.Visible = true
        ui.overlay_sub_num.Visible = true
        ui.overlay_best_lbl.Visible = false
        ui.overlay_best_num.Visible = false
    end
end

local function build_ui(dOS, ca, state, ui)
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

    -- mines pill anchored to the left
    ui.mines_num = make_stat_pill(
        hdr,
        dOS,
        UDim2.fromOffset(CONFIG.SIDE_PAD, 0),
        "MINES",
        C.FLAG_COL
    )

    -- restart button
    local rb
    rb = dOS.create_gui_element(dOS, "TextButton", {
        Parent = hdr,
        Size = UDim2.fromOffset(70, 26),
        Position = UDim2.new(0.5, -35, 0.5, -13),
        BackgroundColor3 = Color3.fromRGB(28, 28, 50),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 6,
        OnEnter = function() rb.BackgroundColor3 = Color3.fromRGB(46, 46, 76) end,
        OnLeave = function() rb.BackgroundColor3 = Color3.fromRGB(28, 28, 50) end,
    })

    dOS.create_gui_element(
        dOS,
        "UICorner",
        { Parent = rb, CornerRadius = UDim.new(0, 7) }
    )

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = rb,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "RESTART",
        TextColor3 = C.TXT_DIM,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 7,
    })

    ui.restart_btn = rb

    -- time pill anchored to the right
    ui.time_num = make_stat_pill(
        hdr,
        dOS,
        UDim2.new(1, -(CONFIG.SIDE_PAD + 72), 0, 0),
        "TIME",
        C.TXT_MAIN
    )

    ui.game_area = dOS.create_gui_element(dOS, "Frame", {
        Parent = ca,
        Size = UDim2.new(1, 0, 1, -CONFIG.HEADER_H),
        Position = UDim2.fromOffset(0, CONFIG.HEADER_H),
        BackgroundColor3 = C.WIN_BG,
        BorderSizePixel = 0,
        ZIndex = 2,
        ClipsDescendants = true,
    })

    ui.overlay = dOS.create_gui_element(dOS, "Frame", {
        Parent = ca,
        Size = UDim2.new(1, 0, 1, -CONFIG.HEADER_H),
        Position = UDim2.fromOffset(0, CONFIG.HEADER_H),
        BackgroundColor3 = C.OVERLAY_BG,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        ZIndex = 20,
        Visible = false,
    })

    ui.overlay_title = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = ui.overlay,
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.fromOffset(0, 34),
        BackgroundTransparency = 1,
        Text = "MINESWEEPER",
        TextColor3 = C.TXT_MAIN,
        TextSize = 30,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 21,
    })

    -- difficulty buttons
    local BW, BH, BG = 114, 30, 8

    ui.diff_container = dOS.create_gui_element(dOS, "Frame", {
        Parent = ui.overlay,
        Size = UDim2.fromOffset(BW * 2 + BG, BH * 2 + BG),
        Position = UDim2.new(0.5, -(BW + BG / 2), 0, 94),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 21,
    })

    ui.diff_btns = {}

    for i, d in ipairs(DIFF) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local db

        db = dOS.create_gui_element(dOS, "TextButton", {
            Parent = ui.diff_container,
            Size = UDim2.fromOffset(BW, BH),
            Position = UDim2.fromOffset(col * (BW + BG), row * (BH + BG)),
            BackgroundColor3 = (i == state.diff_idx) and C.ACCENT
                or C.DIFF_IDLE,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 22,
            OnEnter = function()
                if i ~= state.diff_idx then db.BackgroundColor3 = C.DIFF_HOV end
            end,
            OnLeave = function()
                db.BackgroundColor3 = (i == state.diff_idx) and C.ACCENT
                    or C.DIFF_IDLE
            end,
        })

        dOS.create_gui_element(
            dOS,
            "UICorner",
            { Parent = db, CornerRadius = UDim.new(0, 7) }
        )

        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = db,
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = d.label,
            TextColor3 = C.TXT_MAIN,
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 23,
        })

        ui.diff_btns[i] = db
    end

    ui.overlay_sub_lbl = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = ui.overlay,
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.fromOffset(0, 178),
        BackgroundTransparency = 1,
        Text = "MINES",
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
        Position = UDim2.fromOffset(0, 194),
        BackgroundTransparency = 1,
        Text = 0,
        TextColor3 = C.FLAG_COL,
        TextSize = 26,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 21,
        Visible = false,
    })

    ui.overlay_best_lbl = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = ui.overlay,
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.fromOffset(0, 232),
        BackgroundTransparency = 1,
        Text = "BEST",
        TextColor3 = C.TXT_DIM,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 21,
        Visible = false,
    })

    ui.overlay_best_num = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = ui.overlay,
        Size = UDim2.new(1, 0, 0, 22),
        Position = UDim2.fromOffset(0, 248),
        BackgroundTransparency = 1,
        Text = 0,
        TextColor3 = C.WIN_GOLD,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 21,
        Visible = false,
    })

    local ob
    ob = dOS.create_gui_element(dOS, "TextButton", {
        Parent = ui.overlay,
        Size = UDim2.fromOffset(128, 40),
        Position = UDim2.new(0.5, -64, 1, -58),
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

local function build_cells(dOS, state, ui)
    ui.game_area:ClearAllChildren()
    ui.cells = {}

    for y = 1, state.rows do
        ui.cells[y] = {}

        for x = 1, state.cols do
            local btn = dOS.create_gui_element(dOS, "TextButton", {
                Parent = ui.game_area,
                Size = UDim2.fromOffset(18, 18), -- placeholder
                Position = UDim2.fromOffset(0, 0),
                BackgroundColor3 = C.CELL_HIDDEN,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 3,
            })

            dOS.create_gui_element(
                dOS,
                "UICorner",
                { Parent = btn, CornerRadius = UDim.new(0, 3) }
            )

            local num_lbl = dOS.create_gui_element(dOS, "TextLabel", {
                Parent = btn,
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = 0,
                TextColor3 = C.TXT_MAIN,
                TextSize = 10,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = 4,
                Visible = false,
            })

            -- """flag"""
            local flag_dot = dOS.create_gui_element(dOS, "Frame", {
                Parent = btn,
                Size = UDim2.fromOffset(7, 7),
                Position = UDim2.fromOffset(5, 5),
                BackgroundColor3 = C.FLAG_COL,
                BorderSizePixel = 0,
                ZIndex = 4,
                Visible = false,
            })

            dOS.create_gui_element(
                dOS,
                "UICorner",
                { Parent = flag_dot, CornerRadius = UDim.new(1, 0) }
            )

            local mine_dot = dOS.create_gui_element(dOS, "Frame", {
                Parent = btn,
                Size = UDim2.fromOffset(7, 7),
                Position = UDim2.fromOffset(5, 5),
                BackgroundColor3 = C.MINE_COL,
                BorderSizePixel = 0,
                ZIndex = 4,
                Visible = false,
            })

            dOS.create_gui_element(
                dOS,
                "UICorner",
                { Parent = mine_dot, CornerRadius = UDim.new(1, 0) }
            )

            ui.cells[y][x] = {
                btn = btn,
                num_lbl = num_lbl,
                flag_dot = flag_dot,
                mine_dot = mine_dot,
            }
        end
    end
end

local function wire_cells(dOS, state, ui)
    for y = 1, state.rows do
        for x = 1, state.cols do
            local cdata = ui.cells[y][x]
            local btn = cdata.btn

            btn.MouseButton1Click:Connect(function()
                if state.phase ~= "PLAYING" then return end

                local cell = state.grid[y][x]

                if cell.flagged then return end

                if not state.started then
                    state.started = true
                    state.start_time = os.clock()

                    place_mines(
                        state.grid,
                        state.cols,
                        state.rows,
                        state.mines,
                        x,
                        y
                    )
                end

                if cell.revealed then
                    if cell.adjacent <= 0 then return end

                    local flags = 0

                    for _, nb in
                        ipairs(neighbours(x, y, state.cols, state.rows))
                    do
                        if state.grid[nb.y][nb.x].flagged then
                            flags = flags + 1
                        end
                    end

                    if flags ~= cell.adjacent then return end

                    local hit_nb = nil

                    for _, nb in
                        ipairs(neighbours(x, y, state.cols, state.rows))
                    do
                        local nc = state.grid[nb.y][nb.x]

                        if not nc.flagged and not nc.revealed and nc.mine then
                            hit_nb = nb
                            break
                        end
                    end

                    if hit_nb then
                        state.phase = "DEAD"
                        state.hit_x = hit_nb.x
                        state.hit_y = hit_nb.y
                        state.elapsed = os.clock() - state.start_time

                        expose_mines(state.grid, state.cols, state.rows)
                        render_grid(state, ui)
                        refresh_header(state, ui)

                        task.spawn(function()
                            task.wait(0.5)
                            set_overlay(state, ui, "DEAD")
                        end)

                        return
                    end

                    for _, nb in
                        ipairs(neighbours(x, y, state.cols, state.rows))
                    do
                        local nc = state.grid[nb.y][nb.x]

                        if not nc.flagged and not nc.revealed then
                            flood_reveal(
                                state.grid,
                                state.cols,
                                state.rows,
                                nb.x,
                                nb.y
                            )
                        end
                    end

                    render_grid(state, ui)
                    refresh_header(state, ui)

                    if
                        check_win(
                            state.grid,
                            state.cols,
                            state.rows,
                            state.mines
                        )
                    then
                        state.phase = "WIN"
                        state.elapsed = os.clock() - state.start_time

                        if state.elapsed < state.best_times[state.diff_idx] then
                            state.best_times[state.diff_idx] = state.elapsed
                            save_best_times(dOS, state.best_times)
                        end

                        render_grid(state, ui)

                        task.spawn(function()
                            task.wait(0.3)
                            set_overlay(state, ui, "WIN")
                        end)
                    end

                    return
                end

                if cell.mine then
                    state.phase = "DEAD"
                    state.hit_x = x
                    state.hit_y = y
                    state.elapsed = state.started
                            and (os.clock() - state.start_time)
                        or 0

                    expose_mines(state.grid, state.cols, state.rows)
                    render_grid(state, ui)
                    refresh_header(state, ui)

                    task.spawn(function()
                        task.wait(0.5)
                        set_overlay(state, ui, "DEAD")
                    end)

                    return
                end

                flood_reveal(state.grid, state.cols, state.rows, x, y)
                render_grid(state, ui)
                refresh_header(state, ui)

                if
                    check_win(state.grid, state.cols, state.rows, state.mines)
                then
                    state.phase = "WIN"
                    state.elapsed = os.clock() - state.start_time

                    if state.elapsed < state.best_times[state.diff_idx] then
                        state.best_times[state.diff_idx] = state.elapsed
                        save_best_times(dOS, state.best_times)
                    end

                    render_grid(state, ui)

                    task.spawn(function()
                        task.wait(0.3)
                        set_overlay(state, ui, "WIN")
                    end)
                end
            end)

            btn.MouseButton2Click:Connect(function()
                if state.phase ~= "PLAYING" then return end

                local cell = state.grid[y][x]

                if cell.revealed then return end

                cell.flagged = not cell.flagged
                state.flags_placed = state.flags_placed
                    + (cell.flagged and 1 or -1)

                render_cell(cell, cdata, state.phase, false)
                refresh_header(state, ui)
            end)
        end
    end
end

--- CONTROL

local function start_game(state, ui)
    state.grid = init_grid(state.cols, state.rows)
    state.phase = "PLAYING"
    state.started = false
    state.flags_placed = 0
    state.start_time = 0
    state.elapsed = 0
    state.hit_x = 0
    state.hit_y = 0
    state.gen = state.gen + 1

    set_overlay(state, ui, "NONE")
    render_grid(state, ui)
    refresh_header(state, ui)
    relayout(state, ui)

    local my_gen = state.gen

    task.spawn(function()
        while state.gen == my_gen and state.phase == "PLAYING" do
            task.wait(0.5)

            if state.gen == my_gen then refresh_header(state, ui) end
        end
    end)
end

local function select_difficulty(dOS, state, ui, idx)
    state.diff_idx = idx
    state.cols = DIFF[idx].cols
    state.rows = DIFF[idx].rows
    state.mines = DIFF[idx].mines
    state.phase = "MENU"
    state.gen = state.gen + 1 -- kills any running timer heartbeat

    for i, db in ipairs(ui.diff_btns) do
        db.BackgroundColor3 = (i == idx) and C.ACCENT or C.DIFF_IDLE
    end

    build_cells(dOS, state, ui)
    wire_cells(dOS, state, ui)
    relayout(state, ui)
    set_overlay(state, ui, "MENU")
    refresh_header(state, ui)
end

--- API

function M.create(dOS)
    local window_frame, content_area = dOS.create_basic_window(
        dOS,
        "Minesweeper",
        CONFIG.WIN_W_DEF,
        CONFIG.WIN_H_DEF,
        true,
        true,
        true,
        true,
        CONFIG.WIN_MIN_W,
        CONFIG.WIN_MIN_H
    )

    if not window_frame then return end

    local best_times = load_best_times(dOS)
    local d0 = DIFF[2] -- default: Medium

    local state = {
        grid = {},
        phase = "MENU",
        diff_idx = 2,
        cols = d0.cols,
        rows = d0.rows,
        mines = d0.mines,
        flags_placed = 0,
        started = false,
        start_time = 0,
        elapsed = 0,
        hit_x = 0,
        hit_y = 0,
        gen = 0,
        best_times = best_times,
    }

    local ui = { diff_btns = nil, overlay_btn = nil, restart_btn = nil }
    build_ui(dOS, content_area, state, ui)

    for i in ipairs(DIFF) do
        local idx = i
        ui.diff_btns[i].MouseButton1Click:Connect(function()
            if state.diff_idx == idx then return end

            select_difficulty(dOS, state, ui, idx)
        end)
    end

    ui.overlay_btn.MouseButton1Click:Connect(
        function() start_game(state, ui) end
    )

    ui.restart_btn.MouseButton1Click:Connect(function()
        if state.phase == "MENU" then return end

        start_game(state, ui)
    end)

    build_cells(dOS, state, ui)
    wire_cells(dOS, state, ui)
    relayout(state, ui)
    set_overlay(state, ui, "MENU")
    refresh_header(state, ui)

    content_area
        :GetPropertyChangedSignal("AbsoluteSize")
        :Connect(function() relayout(state, ui) end)
end

return M

-- EOF
