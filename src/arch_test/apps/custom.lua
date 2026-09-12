--[[
    "Runtime application runner for dOS"
    
    @module custom
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


-- TODO: make it actually safe

local M = {}

local CFG = {
    MAX_GUI_ELEMENTS = 1000,
    CPU_INTERRUPT_S = 0.085, -- fires when a thread uses this much CPU without yielding
    KILL_STRIKES = 10, -- consecutive interrupt fires before kill
}

local ALLOWED_GUI_TYPES = {
    Frame = true,
    TextLabel = true,
    TextButton = true,
    TextBox = true,
    ImageLabel = true,
    ImageButton = true,
    ScrollingFrame = true,
    UICorner = true,
    UIPadding = true,
    UIListLayout = true,
    UIGridLayout = true,
    UIStroke = true,
    UISizeConstraint = true,
}

-- properties the runtime always controls
local RUNTIME_PROPS = { Parent = true, ClipsDescendants = true }

-- hardware classes accessible from the sandbox
local SANDBOX_HARDWARE = { Disk = true, Speaker = true }

-- source patterns rejected before loadstring
local BLOCKED_PATTERNS = {
    "setfenv",
    "getfenv",
    "loadstring",
    "dofile",
    "loadfile",
    "debug%.",
    "rawget%s*%(%s*_G",
    "pilot%.",
    "Network:Get",
}

-- path parsing: accepts "42:/path" or "disk42:/path"
local function parse_disk_path(raw)
    local id, path = raw:match("^(%d+):(/.+)$")
    if id then
        return tonumber(id), path
    end

    id, path = raw:match("^[Dd]isk(%d+):(/.+)$")
    if id then
        return tonumber(id), path
    end

    return nil, nil
end

local function analyse_code(code)
    for _, pat in ipairs(BLOCKED_PATTERNS) do
        if code:find(pat) then
            return pat
        end
    end

    return nil
end

local function new_tracker(name)
    return {
        name = name,
        gui_count = 0,
        strikes = 0,
        killed = false,
        kill_reason = "",
        cancel_interrupt = nil,
    }
end

local function build_sandbox(dOS, name, user_area, tracker)
    local safe_math = table.freeze({
        abs = math.abs,
        ceil = math.ceil,
        floor = math.floor,
        max = math.max,
        min = math.min,
        sqrt = math.sqrt,
        sin = math.sin,
        cos = math.cos,
        tan = math.tan,
        atan2 = math.atan2,
        exp = math.exp,
        log = math.log,
        pi = math.pi,
        huge = math.huge,
        random = math.random,
        clamp = math.clamp,
        round = math.round,
        modf = math.modf,
    })

    local safe_task = table.freeze({
        wait = function(t)
            if tracker.killed then
                error("dOS: terminated", 0)
            end

            task.wait(t or 0)
            tracker.strikes = 0

            if tracker.killed then
                error("dOS: terminated", 0)
            end
        end,
    })

    local safe_string = table.freeze({
        len = string.len,
        sub = string.sub,
        rep = string.rep,
        upper = string.upper,
        lower = string.lower,
        format = string.format,
        find = string.find,
        match = string.match,
        gmatch = string.gmatch,
        gsub = string.gsub,
        byte = string.byte,
        char = string.char,
        reverse = string.reverse,
    })

    local safe_table = table.freeze({
        insert = table.insert,
        remove = table.remove,
        concat = table.concat,
        sort = table.sort,
        unpack = table.unpack,
        move = table.move,
        freeze = table.freeze,
        clone = table.clone,
    })

    local safe_net = table.freeze({
        GetPart = function(class)
            if not SANDBOX_HARDWARE[class] then
                error("dOS: hardware '" .. class .. "' not permitted", 2)
            end
            return dOS.HardwareManager.requestNewHardware(class, false, false)
        end,

        GetParts = function(class)
            if not SANDBOX_HARDWARE[class] then
                error("dOS: hardware '" .. class .. "' not permitted", 2)
            end
            return dOS.HardwareManager.requestNewHardware(class, true, false)
        end,
    })

    local gui_api = {}

    gui_api.CreateElement = function(type_str, props)
        if not ALLOWED_GUI_TYPES[type_str] then
            error("dOS: GUI type '" .. type_str .. "' not permitted", 2)
        end

        if tracker.gui_count >= CFG.MAX_GUI_ELEMENTS then
            error("dOS: GUI quota exceeded", 2)
        end

        local safe = {}
        for k, v in pairs(props or {}) do
            if not RUNTIME_PROPS[k] and typeof(v) ~= "Instance" then
                safe[k] = v
            end
        end

        safe.Parent = user_area
        safe.ClipsDescendants = true

        if safe.Size then
            local s = safe.Size
            safe.Size = UDim2.new(
                math.clamp(s.X.Scale, 0, 1),
                s.X.Offset,
                math.clamp(s.Y.Scale, 0, 1),
                s.Y.Offset
            )
        end

        if safe.Position then
            local p = safe.Position
            safe.Position = UDim2.new(
                math.clamp(p.X.Scale, 0, 1),
                p.X.Offset,
                math.clamp(p.Y.Scale, 0, 1),
                p.Y.Offset
            )
        end

        local elem = dOS.create_gui_element(dOS, type_str, safe)
        tracker.gui_count += 1
        return elem
    end

    gui_api.DestroyElement = function(elem)
        if typeof(elem) ~= "Instance" then
            return
        end

        if not elem:IsDescendantOf(user_area) then
            error("dOS: cannot destroy elements outside sandbox", 2)
        end

        tracker.gui_count = math.max(0, tracker.gui_count - 1)
        elem:Destroy()
    end

    gui_api.GetQuota = function()
        return tracker.gui_count, CFG.MAX_GUI_ELEMENTS
    end

    gui_api.GetRemainingQuota = function()
        return CFG.MAX_GUI_ELEMENTS - tracker.gui_count
    end

    local sandbox = {
        pcall = pcall,
        xpcall = xpcall,
        tostring = tostring,
        tonumber = tonumber,
        type = type,
        typeof = typeof,
        pairs = pairs,
        ipairs = ipairs,
        next = next,
        select = select,
        assert = assert,
        error = error,
        setmetatable = setmetatable,
        getmetatable = getmetatable,
        rawget = rawget,
        rawset = rawset,
        rawequal = rawequal,
        rawlen = rawlen,
        unpack = table.unpack,

        math = safe_math,
        string = safe_string,
        table = safe_table,
        task = safe_task,
        os = table.freeze({ clock = os.clock, time = os.time }),

        Vector2 = Vector2,
        Vector3 = Vector3,
        UDim = UDim,
        UDim2 = UDim2,
        Color3 = Color3,
        Rect = Rect,
        Enum = Enum,

        Network = safe_net,
        gui = gui_api,
        APP_NAME = name,

        print = function(...)
            local parts = {}
            for i = 1, select("#", ...) do
                parts[i] = tostring(select(i, ...))
            end
            print("[" .. name .. "] " .. table.concat(parts, "\t"))
        end,

        warn = function(...)
            local parts = {}
            for i = 1, select("#", ...) do
                parts[i] = tostring(select(i, ...))
            end
            warn("[" .. name .. "] " .. table.concat(parts, "\t"))
        end,
    }

    return setmetatable(sandbox, {
        __index = function()
            return nil
        end,
        __newindex = rawset,
        __metatable = "locked",
    })
end

function M.setup_fenv_win(dOS, raw_file_path)
    local disk_id, file_path = parse_disk_path(raw_file_path)
    if not disk_id then
        print("dOS: invalid path: " .. tostring(raw_file_path))
        return
    end

    local disk
    local disks = dOS.HardwareManager.requestNewHardware("Disk", true, true)

    for _, d in ipairs(disks) do
        if d.id == disk_id then
            disk = d.obj
        end
    end

    if not disk then
        dOS.HardwareManager.freeHardware(disks)
        print(`dOS: disk {disk_id} no found.`)
        return
    end

    local ok, code = pcall(disk.Read, disk, file_path)
    dOS.HardwareManager.freeHardware(disks)

    if not ok or type(code) ~= "string" or #code == 0 then
        print("dOS: read failed (" .. file_path .. "): " .. tostring(code))
        return
    end

    local threat = analyse_code(code)
    if threat then
        warn("dOS: BLOCKED " .. file_path .. " -- pattern: " .. threat)
        dOS.MessageBox.error(dOS, "Blocked", "See console.")
        return
    end

    local chunk, compile_err = loadstring(code, "@" .. file_path)
    if not chunk then
        print("dOS: compile error in " .. file_path .. ": " .. tostring(compile_err))
        dOS.MessageBox.error(dOS, "Compile Error", "See console.")
        return
    end

    M.create_program_runner_app(dOS, file_path, chunk)
end

function M.create_program_runner_app(dOS, program_name, program_fn)
    local win_frame, content = dOS.create_basic_window(
        dOS,
        program_name,
        500,
        400,
        true,
        true,
        true,
        true,
        100,
        100
    )

    if not win_frame then
        warn("dOS: window creation failed for " .. program_name)
        return
    end

    local user_area = dOS.create_gui_element(dOS, "Frame", {
        Parent = content,
        Size = UDim2.new(1, 0, 1, -20),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    })

    local state_label = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = content,
        Size = UDim2.new(0.75, 0, 0, 20),
        Position = UDim2.new(0, 0, 1, -20),
        BackgroundColor3 = Color3.fromRGB(22, 22, 26),
        TextColor3 = Color3.fromRGB(150, 200, 150),
        Text = "RUNNING",
        TextSize = 11,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local strike_label = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = content,
        Size = UDim2.new(0.25, 0, 0, 20),
        Position = UDim2.new(0.75, 0, 1, -20),
        BackgroundColor3 = Color3.fromRGB(22, 22, 26),
        TextColor3 = Color3.fromRGB(100, 100, 110),
        Text = 0,
        TextSize = 11,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local tracker = new_tracker(program_name)

    local function set_state(text, r, g, b)
        if state_label then
            state_label.Text = text
            state_label.TextColor3 = Color3.fromRGB(r, g, b)
        end
    end

    local function set_strikes(n)
        if strike_label then
            strike_label.Text = n
        end
    end

    local function kill(reason)
        if tracker.killed then
            return
        end

        tracker.killed = true
        tracker.kill_reason = reason

        if tracker.cancel_interrupt then
            tracker.cancel_interrupt()
            tracker.cancel_interrupt = nil
        end

        warn("dOS: KILL " .. program_name .. " -- " .. reason)
        set_state("KILLED", 200, 80, 80)
        dOS.MessageBox.error(dOS, "Killed", "See console.")
    end

    tracker.cancel_interrupt = pilot.setInterrupt(
        CFG.CPU_INTERRUPT_S,
        function()
            if tracker.killed then
                return
            end

            tracker.strikes += 1
            set_strikes(tracker.strikes)
            set_state("THROTTLED", 210, 160, 60)
            warn("dOS: interrupt #" .. tracker.strikes .. " on " .. program_name)

            if tracker.strikes >= CFG.KILL_STRIKES then
                kill("CPU budget exceeded " .. CFG.KILL_STRIKES .. " consecutive intervals")
            end
        end
    )

    setfenv(program_fn, build_sandbox(dOS, program_name, user_area, tracker))

    task.spawn(function()
        local ok, err = pcall(program_fn)

        if tracker.cancel_interrupt then
            tracker.cancel_interrupt()
            tracker.cancel_interrupt = nil
        end

        if not ok and not tracker.killed then
            warn("dOS: crash in " .. program_name .. ": " .. tostring(err))
            set_state("CRASHED", 200, 80, 80)
            dOS.MessageBox.error(dOS, "Crashed", "See console.")
        elseif not tracker.killed then
            set_state("Done", 140, 200, 140)
            set_strikes(0)
        end
    end)
end

return M

-- EOF