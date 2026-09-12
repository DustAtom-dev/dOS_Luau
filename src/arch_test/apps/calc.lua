--[[
    "Calculator application for dOS"
    
    @module calc
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
local MX = 10 --      horizontal margin
local PAD = 4 --      button gap
local TAB_H = 30 --   tab thingy height
local DISP_H = 100 -- display area height
local SECT_H = 14 --  section label height
local MAX_LEN = 14 -- max display characters

local WIN_W = 270 --  initial window width
local WIN_H = 440 --  initial window height
local MIN_W = 200 --  minimum resizable width
local MIN_H = 360 --  minimum resizable height

local MODES = { "STD", "SCI", "PRG" }

--- UTILS
local function to_int(n)
    return n >= 0 and math.floor(n) or math.ceil(n)
end

local function to_bin_str(n)
    n = math.abs(to_int(n))
    if n == 0 then
        return "0"
    end

    local s = ""
    while n > 0 do
        s = (n % 2 == 1 and "1" or "0") .. s
        n = math.floor(n / 2)
    end

    return s
end

local function fmt(n)
    if type(n) ~= "number" or n ~= n or math.abs(n) == math.huge then
        return tostring(n)
    end

    if n == math.floor(n) and math.abs(n) < 1e13 then
        return tostring(math.floor(n))
    end

    return string.format("%.10g", n)
end

--- STATE
local function make_state()
    return {
        text = "0",
        curr = "",
        prev = "",
        op = nil,
        reset = true,
    }
end

local function refresh(dOS, disp, s, sub)
    local t = tostring(s.text):sub(1, MAX_LEN)

    -- push number if possible, else string
    local function push_smart(obj, str)
        local n = tonumber(str)
        if n and tostring(n) == str then
            obj.Text = n
        else
            obj.Text = str
        end
    end

    push_smart(disp, t)

    if disp.TextBounds.X > disp.AbsoluteSize.X - 8 then
        disp.TextScaled = true
    else
        disp.TextScaled = false
        disp.TextSize = dOS.os_settings.global_font_size + 14
    end

    if sub then
        local n = tonumber(t) or 0
        local ia = to_int(math.abs(n))
        local ng = n < 0 and "-" or ""

        push_smart(sub.hex, ng .. string.format("%X", ia))
        push_smart(sub.dec, tostring(to_int(n)))
        push_smart(sub.oct, ng .. string.format("%o", ia))
        push_smart(sub.bin, ng .. to_bin_str(n))
    end
end

local function refresh_panel(dOS, panel, disp, s, sub)
    for _, child in ipairs(panel:GetChildren()) do
        local c1 = child.Name:sub(1, 1)
        if c1 == "_" or c1 == "#" then
            refresh(dOS, disp, s, sub)
            return
        end
    end
end

--- OPS
local function do_chain(dOS, disp, s, sub)
    local a, b = tonumber(s.prev), tonumber(s.curr)
    if not (s.op and a and b) then
        return
    end

    local ok, r = pcall(s.op, a, b)
    if ok and type(r) == "number" and r == r and math.abs(r) ~= math.huge then
        s.text = fmt(r):sub(1, MAX_LEN)
        s.prev = r
    else
        s.text = "Error"
        s.prev = ""
    end

    s.curr = ""
    refresh(dOS, disp, s, sub)
end

local function op_digit(dOS, disp, s, d, sub)
    local ds = tostring(d)

    if s.reset then
        s.curr = ""
        s.reset = false
    end

    if #s.curr >= MAX_LEN then
        return
    end

    if ds == "." then
        if s.curr:find("%.") then
            return
        end
        if s.curr == "" then
            s.curr = "0"
        end
    end

    s.curr ..= ds
    s.text = s.curr
    refresh(dOS, disp, s, sub)
end

local function op_setop(dOS, disp, s, fn, ch, sub)
    if s.curr == "" and s.prev == "" then
        return
    end

    if s.curr ~= "" and not s.reset then
        if s.op and s.prev ~= "" then
            do_chain(dOS, disp, s, sub)
        else
            s.prev = tonumber(s.curr) or s.curr
            s.curr = ""
        end
    end

    if s.prev ~= "" then
        s.op = fn
        s.text = fmt(s.prev) .. " " .. ch -- format for display
        refresh(dOS, disp, s, sub)
        s.reset = true
    end
end

local function op_calc(dOS, disp, s, sub)
    if not s.op or s.prev == "" or s.curr == "" then
        return
    end

    do_chain(dOS, disp, s, sub)
    s.op = nil
    s.reset = true
end

local function op_clr(dOS, disp, s, sub)
    s.text = "0"
    s.curr = ""
    s.prev = ""
    s.op = nil
    s.reset = true
    refresh(dOS, disp, s, sub)
end

local function op_del(dOS, disp, s, sub)
    if s.reset or s.curr == "" then
        return
    end

    s.curr = s.curr:sub(1, -2)
    s.text = s.curr == "" and "0" or s.curr
    refresh(dOS, disp, s, sub)
end

local function op_pct(dOS, disp, s, sub)
    local tgt = s.curr ~= "" and "curr" or "prev"
    local n = tonumber(s[tgt])
    if not n then
        return
    end

    local res = n / 100
    s[tgt] = res
    s.text = fmt(res):sub(1, MAX_LEN)
    refresh(dOS, disp, s, sub)
end

local function op_unary(dOS, disp, s, fn, sub)
    local src = s.curr ~= "" and s.curr or s.prev
    local n = tonumber(src)
    if not n then
        return
    end

    local ok, r = pcall(fn, n)
    if ok and type(r) == "number" and r == r and math.abs(r) ~= math.huge then
        s.curr = r
        s.text = fmt(r):sub(1, MAX_LEN)
        s.reset = true
    else
        s.text = "Error"
    end

    refresh(dOS, disp, s, sub)
end

local function op_const(dOS, disp, s, val, sub)
    s.curr = val
    s.text = fmt(val):sub(1, MAX_LEN)
    s.reset = true
    refresh(dOS, disp, s, sub)
end

--- UI

local function mkbtn(dOS, parent, label, bg, fn)
    local name_str = type(label) == "number" and tostring(label) or label

    return dOS.create_gui_element(dOS, "TextButton", {
        Name = "B_" .. name_str:gsub("[^%w]", "_"),
        Parent = parent,
        Text = label,
        Size = UDim2.fromOffset(10, 10),
        Position = UDim2.fromOffset(0, 0),
        BackgroundColor3 = bg,
        AutoButtonColor = true,
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        Font = dOS.THEME.FONT_BOLD,
        TextSize = 12,
        OnClick = fn,
    })
end

local function mk_sect(dOS, parent, text)
    return dOS.create_gui_element(dOS, "TextLabel", {
        Name = "_" .. text:upper():gsub("[^%w]", "_"),
        Parent = parent,
        Text = text:upper(),
        Size = UDim2.fromOffset(10, SECT_H),
        Position = UDim2.fromOffset(PAD, 0),
        BackgroundTransparency = 1,
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        TextTransparency = 0.4,
        Font = dOS.THEME.FONT_BOLD,
        TextSize = 8,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
end

local function new_panel(dOS, container, name)
    return dOS.create_gui_element(dOS, "Frame", {
        Name = name,
        Parent = container,
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1,
    })
end

--- LAYOUT

local function make_simple_relayout(slots, n_cols, n_rows)
    return function(pw, ph)
        local bh = math.max(10, math.floor((ph - PAD * (n_rows + 1)) / n_rows))
        local bw = math.max(10, math.floor((pw - PAD * (n_cols + 1)) / n_cols))
        local ts = math.clamp(math.floor(bh * 0.40), 9, 20)

        for _, sl in ipairs(slots) do
            local span = sl.span or 1
            sl.gui.Position = UDim2.fromOffset(
                PAD + (sl.col - 1) * (bw + PAD),
                PAD + (sl.row - 1) * (bh + PAD)
            )
            sl.gui.Size = UDim2.fromOffset(bw * span + PAD * (span - 1), bh)
            sl.gui.TextSize = ts
        end
    end
end

local function make_sectioned_relayout(sects, slots, n_cols)
    return function(pw, ph)
        local total_rows = 0
        for _, sec in ipairs(sects) do
            total_rows += sec.n_rows
        end

        local overhead = #sects * (SECT_H + PAD)
        local bh = math.max(
            10,
            math.floor((ph - overhead - PAD * (total_rows + 1)) / total_rows)
        )
        local bw = math.max(10, math.floor((pw - PAD * (n_cols + 1)) / n_cols))
        local ts = math.clamp(math.floor(bh * 0.40), 9, 20)

        -- section label y-starts
        local sy = {}
        local cy = PAD

        for i, sec in ipairs(sects) do
            sy[i] = cy
            sec.label.Position = UDim2.fromOffset(PAD, cy)
            sec.label.Size = UDim2.fromOffset(pw - PAD * 2, SECT_H)
            cy += SECT_H + PAD + sec.n_rows * (bh + PAD)
        end

        for _, sl in ipairs(slots) do
            local span = sl.span or 1
            local x = PAD + (sl.col - 1) * (bw + PAD)
            local y = sy[sl.si] + SECT_H + PAD + (sl.row - 1) * (bh + PAD)

            sl.gui.Position = UDim2.fromOffset(x, y)
            sl.gui.Size = UDim2.fromOffset(bw * span + PAD * (span - 1), bh)
            sl.gui.TextSize = ts
        end
    end
end

local function make_standard(dOS, cont, disp, s, sub)
    local pnl = new_panel(dOS, cont, "PanelSTD")
    local D, O = dOS.THEME.CALC_BUTTON_BG, dOS.THEME.CALC_OP_BUTTON_BG

    local slots = {}
    local function add(label, col, row, bg, fn, span)
        local btn = mkbtn(dOS, pnl, label, bg, fn)
        table.insert(slots, { gui = btn, col = col, row = row, span = span })
        task.wait()
    end

    -- row 1
    add("C", 1, 1, D, function()
        op_clr(dOS, disp, s, sub)
    end)
    add("%", 2, 1, O, function()
        op_pct(dOS, disp, s, sub)
    end) -- % is O
    add("DEL", 3, 1, D, function()
        op_del(dOS, disp, s, sub)
    end)
    add("÷", 4, 1, O, function()
        op_setop(dOS, disp, s, function(a, b)
            if b == 0 then
                return "Error"
            end
            return a / b
        end, "÷", sub)
    end)

    -- row 2
    add(7, 1, 2, D, function()
        op_digit(dOS, disp, s, 7, sub)
    end)
    add(8, 2, 2, D, function()
        op_digit(dOS, disp, s, 8, sub)
    end)
    add(9, 3, 2, D, function()
        op_digit(dOS, disp, s, 9, sub)
    end)
    add("×", 4, 2, O, function()
        op_setop(dOS, disp, s, function(a, b)
            return a * b
        end, "×", sub)
    end)

    -- row 3
    add(4, 1, 3, D, function()
        op_digit(dOS, disp, s, 4, sub)
    end)
    add(5, 2, 3, D, function()
        op_digit(dOS, disp, s, 5, sub)
    end)
    add(6, 3, 3, D, function()
        op_digit(dOS, disp, s, 6, sub)
    end)
    add("−", 4, 3, O, function()
        op_setop(dOS, disp, s, function(a, b)
            return a - b
        end, "−", sub)
    end)

    -- row 4
    add(1, 1, 4, D, function()
        op_digit(dOS, disp, s, 1, sub)
    end)
    add(2, 2, 4, D, function()
        op_digit(dOS, disp, s, 2, sub)
    end)
    add(3, 3, 4, D, function()
        op_digit(dOS, disp, s, 3, sub)
    end)
    add("+", 4, 4, O, function()
        op_setop(dOS, disp, s, function(a, b)
            return a + b
        end, "+", sub)
    end)

    -- row 5
    -- 0 spans 2 cols
    add(0, 1, 5, D, function()
        op_digit(dOS, disp, s, 0, sub)
    end, 2)
    add(".", 3, 5, D, function()
        op_digit(dOS, disp, s, ".", sub)
    end)
    add("=", 4, 5, O, function()
        op_calc(dOS, disp, s, sub)
    end)

    return pnl, make_simple_relayout(slots, 4, 5)
end

local function make_scientific(dOS, cont, disp, s, sub)
    local pnl = new_panel(dOS, cont, "PanelSCI")
    local D, O = dOS.THEME.CALC_BUTTON_BG, dOS.THEME.CALC_OP_BUTTON_BG
    local RAD = math.pi / 180
    local PI = math.pi
    local EU = math.exp(1)

    local lbl1 = mk_sect(dOS, pnl, "Trigonometry")
    local lbl2 = mk_sect(dOS, pnl, "Functions")
    local lbl3 = mk_sect(dOS, pnl, "Numpad")

    local sects = {
        { label = lbl1, n_rows = 2 }, -- sin/cos/tan/C + asin/acos/atan/DEL
        { label = lbl2, n_rows = 2 }, -- log/ln/√/x²   + π/e/^/1/x
        { label = lbl3, n_rows = 4 }, -- numpad
    }

    local slots = {}
    local function add(label, col, row, si, bg, fn)
        local btn = mkbtn(dOS, pnl, label, bg, fn)
        table.insert(slots, { gui = btn, col = col, row = row, si = si })
        task.wait()
    end

    -- trig
    add("sin", 1, 1, 1, D, function()
        op_unary(dOS, disp, s, function(x)
            return math.sin(x * RAD)
        end, sub)
    end)
    add("cos", 2, 1, 1, D, function()
        op_unary(dOS, disp, s, function(x)
            return math.cos(x * RAD)
        end, sub)
    end)
    add("tan", 3, 1, 1, D, function()
        op_unary(dOS, disp, s, function(x)
            return math.tan(x * RAD)
        end, sub)
    end)
    add("C", 4, 1, 1, D, function()
        op_clr(dOS, disp, s, sub)
    end)
    add("asin", 1, 2, 1, D, function()
        op_unary(dOS, disp, s, function(x)
            return math.deg(math.asin(x))
        end, sub)
    end)
    add("acos", 2, 2, 1, D, function()
        op_unary(dOS, disp, s, function(x)
            return math.deg(math.acos(x))
        end, sub)
    end)
    add("atan", 3, 2, 1, D, function()
        op_unary(dOS, disp, s, function(x)
            return math.deg(math.atan(x))
        end, sub)
    end)
    add("DEL", 4, 2, 1, D, function()
        op_del(dOS, disp, s, sub)
    end)

    -- functions
    add("log", 1, 1, 2, D, function()
        op_unary(dOS, disp, s, math.log10, sub)
    end)
    add("ln", 2, 1, 2, D, function()
        op_unary(dOS, disp, s, math.log, sub)
    end)
    add("√", 3, 1, 2, D, function()
        op_unary(dOS, disp, s, math.sqrt, sub)
    end)
    add("x²", 4, 1, 2, D, function()
        op_unary(dOS, disp, s, function(x)
            return x * x
        end, sub)
    end)
    add("π", 1, 2, 2, D, function()
        op_const(dOS, disp, s, PI, sub)
    end)
    add("e", 2, 2, 2, D, function()
        op_const(dOS, disp, s, EU, sub)
    end)
    add("^", 3, 2, 2, O, function()
        op_setop(dOS, disp, s, function(a, b)
            return a ^ b
        end, "^", sub)
    end)
    add("1/x", 4, 2, 2, O, function()
        op_unary(dOS, disp, s, function(x)
            if x == 0 then
                return "Error"
            end
            return 1 / x
        end, sub)
    end)

    -- numpad
    add(7, 1, 1, 3, D, function()
        op_digit(dOS, disp, s, 7, sub)
    end)
    add(8, 2, 1, 3, D, function()
        op_digit(dOS, disp, s, 8, sub)
    end)
    add(9, 3, 1, 3, D, function()
        op_digit(dOS, disp, s, 9, sub)
    end)
    add("÷", 4, 1, 3, O, function()
        op_setop(dOS, disp, s, function(a, b)
            if b == 0 then
                return "Error"
            end
            return a / b
        end, "÷", sub)
    end)
    add(4, 1, 2, 3, D, function()
        op_digit(dOS, disp, s, 4, sub)
    end)
    add(5, 2, 2, 3, D, function()
        op_digit(dOS, disp, s, 5, sub)
    end)
    add(6, 3, 2, 3, D, function()
        op_digit(dOS, disp, s, 6, sub)
    end)
    add("×", 4, 2, 3, O, function()
        op_setop(dOS, disp, s, function(a, b)
            return a * b
        end, "×", sub)
    end)
    add(1, 1, 3, 3, D, function()
        op_digit(dOS, disp, s, 1, sub)
    end)
    add(2, 2, 3, 3, D, function()
        op_digit(dOS, disp, s, 2, sub)
    end)
    add(3, 3, 3, 3, D, function()
        op_digit(dOS, disp, s, 3, sub)
    end)
    add("−", 4, 3, 3, O, function()
        op_setop(dOS, disp, s, function(a, b)
            return a - b
        end, "−", sub)
    end)
    add(0, 1, 4, 3, D, function()
        op_digit(dOS, disp, s, 0, sub)
    end)
    add(".", 2, 4, 3, D, function()
        op_digit(dOS, disp, s, ".", sub)
    end)
    add("+", 3, 4, 3, O, function()
        op_setop(dOS, disp, s, function(a, b)
            return a + b
        end, "+", sub)
    end)
    add("=", 4, 4, 3, O, function()
        op_calc(dOS, disp, s, sub)
    end)

    return pnl, make_sectioned_relayout(sects, slots, 4)
end

local function make_programmer(dOS, cont, disp, s, sub)
    local pnl = new_panel(dOS, cont, "PanelPRG")
    local D, O = dOS.THEME.CALC_BUTTON_BG, dOS.THEME.CALC_OP_BUTTON_BG
    local I = to_int

    local lbl1 = mk_sect(dOS, pnl, "Bitwise Logic")
    local lbl2 = mk_sect(dOS, pnl, "Shifts & Edit")
    local lbl3 = mk_sect(dOS, pnl, "Numpad")

    local sects = {
        { label = lbl1, n_rows = 1 }, -- AND OR XOR NOT
        { label = lbl2, n_rows = 1 }, -- << >> DEL C
        { label = lbl3, n_rows = 4 }, -- numpad
    }

    local slots = {}
    local function add(label, col, row, si, bg, fn)
        local btn = mkbtn(dOS, pnl, label, bg, fn)
        table.insert(slots, { gui = btn, col = col, row = row, si = si })
        task.wait()
    end

    -- bitwise
    add("AND", 1, 1, 1, O, function()
        op_setop(dOS, disp, s, function(a, b)
            return bit32.band(I(a), I(b))
        end, "AND", sub)
    end)
    add("OR", 2, 1, 1, O, function()
        op_setop(dOS, disp, s, function(a, b)
            return bit32.bor(I(a), I(b))
        end, "OR", sub)
    end)
    add("XOR", 3, 1, 1, O, function()
        op_setop(dOS, disp, s, function(a, b)
            return bit32.bxor(I(a), I(b))
        end, "XOR", sub)
    end)
    add("NOT", 4, 1, 1, O, function()
        op_unary(dOS, disp, s, function(x)
            return bit32.bnot(I(x))
        end, sub)
    end)

    -- shifts & edit
    add("<<", 1, 1, 2, O, function()
        op_setop(dOS, disp, s, function(a, b)
            return bit32.lshift(I(a), I(b))
        end, "<<", sub)
    end)
    add(">>", 2, 1, 2, O, function()
        op_setop(dOS, disp, s, function(a, b)
            return bit32.rshift(I(a), I(b))
        end, ">>", sub)
    end)
    add("DEL", 3, 1, 2, D, function()
        op_del(dOS, disp, s, sub)
    end)
    add("C", 4, 1, 2, D, function()
        op_clr(dOS, disp, s, sub)
    end)

    -- integer numpad
    add(7, 1, 1, 3, D, function()
        op_digit(dOS, disp, s, 7, sub)
    end)
    add(8, 2, 1, 3, D, function()
        op_digit(dOS, disp, s, 8, sub)
    end)
    add(9, 3, 1, 3, D, function()
        op_digit(dOS, disp, s, 9, sub)
    end)
    add("÷", 4, 1, 3, O, function()
        op_setop(dOS, disp, s, function(a, b)
            if b == 0 then
                return "Error"
            end
            return I(a / b)
        end, "÷", sub)
    end)
    add(4, 1, 2, 3, D, function()
        op_digit(dOS, disp, s, 4, sub)
    end)
    add(5, 2, 2, 3, D, function()
        op_digit(dOS, disp, s, 5, sub)
    end)
    add(6, 3, 2, 3, D, function()
        op_digit(dOS, disp, s, 6, sub)
    end)
    add("×", 4, 2, 3, O, function()
        op_setop(dOS, disp, s, function(a, b)
            return I(a) * I(b)
        end, "×", sub)
    end)
    add(1, 1, 3, 3, D, function()
        op_digit(dOS, disp, s, 1, sub)
    end)
    add(2, 2, 3, 3, D, function()
        op_digit(dOS, disp, s, 2, sub)
    end)
    add(3, 3, 3, 3, D, function()
        op_digit(dOS, disp, s, 3, sub)
    end)
    add("−", 4, 3, 3, O, function()
        op_setop(dOS, disp, s, function(a, b)
            return I(a) - I(b)
        end, "−", sub)
    end)
    add(0, 1, 4, 3, D, function()
        op_digit(dOS, disp, s, 0, sub)
    end)
    add("+", 2, 4, 3, O, function()
        op_setop(dOS, disp, s, function(a, b)
            return I(a) + I(b)
        end, "+", sub)
    end)
    add("=", 3, 4, 3, O, function()
        op_calc(dOS, disp, s, sub)
    end)
    add("MOD", 4, 4, 3, O, function()
        op_setop(dOS, disp, s, function(a, b)
            if b == 0 then
                return "Error"
            end
            return I(a) % I(b)
        end, "MOD", sub)
    end)

    return pnl, make_sectioned_relayout(sects, slots, 4)
end

--- API
function M.create(dOS)
    local win, content = dOS.create_basic_window(
        dOS,
        "Calculator",
        WIN_W,
        WIN_H,
        true,
        true,
        true,
        true,
        MIN_W,
        MIN_H
    )
    if not win then
        return
    end

    -- loading overlay
    local loading_frame = dOS.create_gui_element(dOS, "Frame", {
        Name = "LoadingOverlay",
        Parent = content,
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, 0),
        BackgroundColor3 = dOS.THEME.WINDOW_BG,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 100,
    })

    local splash_img = dOS.create_gui_element(dOS, "ImageLabel", {
        Name = "SplashImage",
        Parent = loading_frame,
        Image = 85861816563977,
        ImageColor3 = dOS.THEME.START_MENU_GENERIC_APP_ICON,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.4, 0.4),
        ScaleType = Enum.ScaleType.Fit,
        BackgroundTransparency = 1,
        ImageTransparency = 1,
        ZIndex = 101,
    })

    dOS.Tween
        .new(
            splash_img,
            { ImageTransparency = 0, Size = UDim2.fromScale(0.5, 0.5) },
            dOS.TweenInfo.new(
                0.22,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.InOut
            )
        )
        :Play()

    local state = make_state()

    -- fwd decls
    local display, disp_frame = nil
    local panels = {}
    local relayouts = {}
    local sub_labels = nil
    local current_idx = 1
    local tweening = false
    local tab_btns = {}
    local indicator = nil
    local pnl_cont = nil

    -- tab switch
    local TI_SLIDE = dOS.TweenInfo.new(
        0.28,
        Enum.EasingStyle.Quart,
        Enum.EasingDirection.Out
    )

    local function switch_to(idx)
        if idx == current_idx or tweening then
            return
        end
        tweening = true

        local dir = idx > current_idx and 1 or -1
        local pw = math.max(1, pnl_cont.AbsoluteSize.X)
        local outgoing = current_idx

        -- snap incoming panel to entry side
        panels[idx].Visible = true
        panels[idx].Position = UDim2.fromOffset(dir * pw, 0)

        -- show/hide prg sub-labels
        if sub_labels then
            local show = (idx == 3)
            for _, child in ipairs(disp_frame:GetChildren()) do
                if child.Name:find("Prefix_") or child.Name:find("_Sub_") then
                    child.Visible = show
                end
            end
        end

        -- restore filtered "_" / "#" texts
        for _, child in ipairs(panels[idx]:GetChildren()) do
            if child:IsA("TextButton") then
                local txt = tostring(child.Text)
                if txt:match("^[_#]+$") then
                    child.Text = txt
                end
            end
        end

        -- slide panels
        dOS.Tween
            .new(
                panels[outgoing],
                { Position = UDim2.fromOffset(-dir * pw, 0) },
                TI_SLIDE
            )
            :Play()

        dOS.Tween
            .new(panels[idx], { Position = UDim2.fromOffset(0, 0) }, TI_SLIDE)
            :Play()

        -- slide indicator underline
        local new_tab_w = math.max(1, math.floor(content.AbsoluteSize.X / #MODES))
        dOS.Tween
            .new(
                indicator,
                { Position = UDim2.fromOffset((idx - 1) * new_tab_w, TAB_H - 2) },
                TI_SLIDE
            )
            :Play()

        current_idx = idx

        task.delay(0.32, function()
            tweening = false
            panels[outgoing].Visible = false
            -- only names starting with "_" or "#"
            refresh_panel(dOS, panels[current_idx], display, state, sub_labels)
        end)
    end

    --- RELAYOUT
    local function do_relayout()
        local cw = content.AbsoluteSize.X
        local ch = content.AbsoluteSize.Y

        -- tab buttons + underline
        local new_tab_w = math.max(1, math.floor(cw / #MODES))
        for i, btn in ipairs(tab_btns) do
            btn.Size = UDim2.fromOffset(new_tab_w, TAB_H - 2)
            btn.Position = UDim2.fromOffset((i - 1) * new_tab_w, 0)
        end

        indicator.Size = UDim2.fromOffset(new_tab_w, 2)
        indicator.Position =
            UDim2.fromOffset((current_idx - 1) * new_tab_w, TAB_H - 2)

        -- panel size from content
        local pw = math.max(1, cw - MX * 2)
        local ph = math.max(1, ch - TAB_H - DISP_H - 4)

        -- re-anchor hidden panels beyond clip
        for i, pnl in ipairs(panels) do
            if i ~= current_idx and not pnl.Visible then
                pnl.Position = UDim2.fromOffset(pw, 0)
            end
        end

        for _, rl in ipairs(relayouts) do
            rl(pw, ph)
        end
    end

    -- tab bar
    local tab_bar = dOS.create_gui_element(dOS, "Frame", {
        Name = "TabBar",
        Parent = content,
        Size = UDim2.new(1, 0, 0, TAB_H),
        Position = UDim2.fromOffset(0, 0),
        BackgroundColor3 = dOS.THEME.WINDOW_BG,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
    })

    local init_tab_w = math.floor(WIN_W / #MODES)

    indicator = dOS.create_gui_element(dOS, "Frame", {
        Name = "Indicator",
        Parent = tab_bar,
        Size = UDim2.fromOffset(init_tab_w, 2),
        Position = UDim2.fromOffset(0, TAB_H - 2),
        BackgroundColor3 = dOS.THEME.ACCENT or Color3.fromRGB(80, 160, 255),
        BorderSizePixel = 0,
    })

    for i, label in ipairs(MODES) do
        local i_cap = i
        local btn = dOS.create_gui_element(dOS, "TextButton", {
            Name = "Tab_" .. label,
            Parent = tab_bar,
            Text = label,
            Size = UDim2.fromOffset(init_tab_w, TAB_H - 2),
            Position = UDim2.fromOffset((i - 1) * init_tab_w, 0),
            BackgroundTransparency = 1,
            TextColor3 = dOS.THEME.TEXT_LIGHT,
            Font = dOS.THEME.FONT_BOLD,
            TextSize = 11,
            OnClick = function()
                switch_to(i_cap)
            end,
        })
        tab_btns[i] = btn
        task.wait()
    end

    -- display area
    disp_frame = dOS.create_gui_element(dOS, "Frame", {
        Name = "DisplayArea",
        Parent = content,
        Size = UDim2.new(1, 0, 0, DISP_H),
        Position = UDim2.fromOffset(0, TAB_H),
        BackgroundTransparency = 1,
    })

    display = dOS.create_gui_element(dOS, "TextBox", {
        Name = "Display",
        Parent = disp_frame,
        Text = 0,
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        ClearTextOnFocus = false,
        TextEditable = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Font = dOS.THEME.FONT_BOLD,
        TextSize = dOS.os_settings.global_font_size + 14,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.new(1, -MX * 2, 0, 52),
        Position = UDim2.fromOffset(MX, 2),
        Properties = { ClipsDescendants = true },
    })

    dOS.create_gui_element(dOS, "Frame", {
        Name = "DispSep",
        Parent = disp_frame,
        Size = UDim2.new(1, -MX * 2, 0, 1),
        Position = UDim2.fromOffset(MX, 54),
        BackgroundColor3 = dOS.THEME.TEXT_LIGHT,
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
    })

    do
        local keys = { "hex", "dec", "oct", "bin" }
        local sub = {}

        for i, key in ipairs(keys) do
            local y_pos = 56 + (i - 1) * 11

            -- prefix - left aligned
            dOS.create_gui_element(dOS, "TextLabel", {
                Name = "Prefix_" .. key:upper(),
                Parent = disp_frame,
                Text = key:upper(),
                TextColor3 = dOS.THEME.TEXT_LIGHT,
                TextTransparency = 0.6,
                BackgroundTransparency = 1,
                Font = dOS.THEME.FONT_BOLD,
                TextSize = 9,
                TextXAlignment = Enum.TextXAlignment.Left,
                Size = UDim2.fromOffset(40, 11),
                Position = UDim2.fromOffset(MX, y_pos),
                Visible = false, -- Controlled by switch_to
            })

            -- value - right aligned
            local val_lbl = dOS.create_gui_element(dOS, "TextLabel", {
                Name = "_Sub_" .. key:upper(),
                Parent = disp_frame,
                Text = 0,
                TextColor3 = dOS.THEME.TEXT_LIGHT,
                TextTransparency = 0.35,
                BackgroundTransparency = 1,
                Font = dOS.THEME.FONT_BOLD,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Right,
                Size = UDim2.new(1, -MX * 2, 0, 11),
                Position = UDim2.fromOffset(MX, y_pos),
                Visible = false, -- Controlled by switch_to
            })

            sub[key] = val_lbl
            task.wait()
        end

        sub_labels = sub
    end

    -- panel container
    pnl_cont = dOS.create_gui_element(dOS, "Frame", {
        Name = "PanelsCont",
        Parent = content,
        Size = UDim2.new(1, -MX * 2, 1, -(TAB_H + DISP_H + 4)),
        Position = UDim2.fromOffset(MX, TAB_H + DISP_H + 4),
        BackgroundTransparency = 1,
        Properties = { ClipsDescendants = true },
    })

    -- build panels
    local rl1, rl2, rl3
    panels[1], rl1 = make_standard(dOS, pnl_cont, display, state, nil)
    panels[2], rl2 = make_scientific(dOS, pnl_cont, display, state, nil)
    panels[3], rl3 = make_programmer(dOS, pnl_cont, display, state, sub_labels)
    relayouts = { rl1, rl2, rl3 }

    panels[2].Position = UDim2.fromOffset(WIN_W, 0)
    panels[2].Visible = false
    panels[3].Position = UDim2.fromOffset(WIN_W, 0)
    panels[3].Visible = false

    -- initial layout

    if sub_labels then
        for _, lbl in pairs(sub_labels) do
            lbl.Visible = false
        end
    end

    task.wait()
    do_relayout()

    local TI_FADE =
        dOS.TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    dOS.Tween.new(loading_frame, { BackgroundTransparency = 1 }, TI_FADE):Play()
    dOS.Tween.new(splash_img, { ImageTransparency = 1 }, TI_FADE):Play()

    task.delay(0.25, function()
        loading_frame.Visible = false
        splash_img.Visible = false
    end)

    content:GetPropertyChangedSignal("AbsoluteSize"):Connect(do_relayout)
end

return M

-- EOF