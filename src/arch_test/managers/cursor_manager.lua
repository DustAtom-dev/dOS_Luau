--[[
    "Cursor manager module for dOS"
    
    @module cursor_manager
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

M.cursor_manager = {
    -- visuals[screen_id][uid] = { frame, img, label, loader, updated, current_text }
    visuals = {},
    hidden_users = {}, -- [UserId] = boolean
    thread = nil,

    CURSOR_ICON = 8679825641,
    LOADING_ICON = 131133453790059,
    CURSOR_SIZE = 60,
    OWNER_COLOR = Color3.fromRGB(255, 50, 50),
    DEFAULT_COLOR = Color3.fromRGB(255, 255, 255),

    baseline_tick = 0.033,
    threshold_busy_bg = 0.06,
    threshold_busy_wait = 0.2,
    last_tick_time = 0,

    current_visual_state = 0, -- 0: none, 1: bg, 2: wait
    state_expiry_time = 0,
    min_display_time = 1.0,
}

--- CALIBRATION

function M.calibrate_latency(_)
    print("[CursorManager] Calibrating server latency...")

    local samples = 0
    local total_time = 0
    local start_time = os.clock()

    while os.clock() - start_time < 3 do
        local t0 = os.clock()
        task.wait()
        total_time = total_time + (os.clock() - t0)
        samples += 1
    end

    local avg = total_time / samples

    M.cursor_manager.baseline_tick = avg
    M.cursor_manager.threshold_busy_bg = avg * 3
    M.cursor_manager.threshold_busy_wait = avg * 6

    print(
        string.format(
            "[CursorManager] Calibration: Avg=%.4fs | BG=>%.4fs | Wait=>%.4fs",
            avg,
            M.cursor_manager.threshold_busy_bg,
            M.cursor_manager.threshold_busy_wait
        )
    )
end

--- INIT

function M.init(dOS)
    task.spawn(M.calibrate_latency)

    M.cursor_manager.last_tick_time = os.clock()

    M.cursor_manager.thread = task.spawn(function()
        while true do
            if dOS.screen then
                M.update_cursors(dOS)
            end

            task.wait()
        end
    end)
end

function M.shutdown()
    if M.cursor_manager.thread then
        pcall(task.cancel, M.cursor_manager.thread)
    end

    M.cursor_manager.visuals = {}
    M.cursor_manager.hidden_users = {}
    M.cursor_manager.thread = nil
    M.cursor_manager.last_tick_time = 0
    M.cursor_manager.current_visual_state = 0
    M.cursor_manager.state_expiry_time = 0
end

function M.refresh_all_visuals()
    for _, screen_visuals in pairs(M.cursor_manager.visuals) do
        for _, vis in pairs(screen_visuals) do
            if vis.frame then
                pcall(function()
                    vis.frame:Destroy()
                end)
            end
        end
    end

    M.cursor_manager.visuals = {}
end

--- VISUALS

local function _create_cursor_visual(dOS, screen_proxy, uid, username)
    local cm = M.cursor_manager
    local size = cm.CURSOR_SIZE

    local container = dOS.create_gui_element(screen_proxy, "ImageLabel", {
        Name = "CursorVisual_" .. uid,
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
        ZIndex = dOS.Z_INDEX.CURSOR,
        ClipsDescendants = false,
    })

    local img = dOS.create_gui_element(screen_proxy, "ImageLabel", {
        Parent = container,
        Image = cm.CURSOR_ICON,
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1,
        ZIndex = dOS.Z_INDEX.CURSOR,
    })

    local label = dOS.create_gui_element(screen_proxy, "TextLabel", {
        Parent = container,
        Text = username,
        Size = UDim2.fromOffset(100, 15),
        AutomaticSize = Enum.AutomaticSize.X,
        Position = UDim2.fromOffset(size * 0.5, size),
        BackgroundTransparency = 0.5,
        BackgroundColor3 = Color3.new(0, 0, 0),
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 10,
        ZIndex = dOS.Z_INDEX.CURSOR + 1,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    dOS.create_gui_element(screen_proxy, "UIPadding", {
        Parent = label,
        PaddingLeft = UDim.new(0, 2),
    })

    local loader = dOS.create_gui_element(screen_proxy, "ImageLabel", {
        Parent = container,
        Image = cm.LOADING_ICON,
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = dOS.Z_INDEX.CURSOR + 2,
    })

    return {
        frame = container,
        img = img,
        label = label,
        loader = loader,
        updated = true,
        current_text = username,
    }
end

--- LAG

local function _tick_lag_state()
    local cm = M.cursor_manager
    local now = os.clock()
    local dt = now - cm.last_tick_time
    cm.last_tick_time = now

    local raw_state = 0

    if dt > cm.threshold_busy_wait then
        raw_state = 2
    elseif dt > cm.threshold_busy_bg then
        raw_state = 1
    end

    if raw_state > cm.current_visual_state then
        cm.current_visual_state = raw_state
        cm.state_expiry_time = now + cm.min_display_time
    elseif now > cm.state_expiry_time then
        cm.current_visual_state = raw_state
    end

    return cm.current_visual_state
end

--- RENDER

local function _apply_lag_visuals(vis, lag_state, size)
    if lag_state == 0 then
        vis.img.Visible = true
        vis.loader.Visible = false
    elseif lag_state == 1 then
        vis.img.Visible = true
        vis.loader.Visible = true
        vis.loader.Position = UDim2.fromOffset(size * 0.6, 15)
    else
        vis.img.Visible = false
        vis.loader.Visible = true
        vis.loader.Position = UDim2.fromOffset((size - 16) / 2, (size - 16) / 2)
    end

    if vis.loader.Visible then
        vis.loader.Rotation = (vis.loader.Rotation + 15) % 360
    end
end

--- UPDATE

local function _update_screen(
    dOS,
    screen_id,
    screen_hw,
    screen_proxy,
    owner_name,
    lag_state
)
    local cm = M.cursor_manager
    local size = cm.CURSOR_SIZE

    -- make sure the screen has a sub table
    if not cm.visuals[screen_id] then
        cm.visuals[screen_id] = {}
    end

    local sv = cm.visuals[screen_id]

    for _, vis in pairs(sv) do
        vis.updated = false
    end

    local cursors = screen_hw:GetCursors()

    for _, c in pairs(cursors) do
        local uid = c.UserId
        local username = c.Player

        if cm.hidden_users[uid] then
            if sv[uid] then
                sv[uid].frame.Visible = false
                sv[uid].updated = true
            end
            continue
        end

        local vis = sv[uid]

        if not vis then
            vis = _create_cursor_visual(dOS, screen_proxy, uid, username)
            sv[uid] = vis
        end

        vis.frame.Position = UDim2.fromOffset(c.X - size * 0.5, c.Y - size * 0.5)
        vis.frame.Visible = true
        vis.updated = true

        _apply_lag_visuals(vis, lag_state, size)

        -- label text and color
        local target_color = (username == owner_name) and cm.OWNER_COLOR
            or cm.DEFAULT_COLOR

        if vis.current_text ~= username then
            vis.label.Text = username
            vis.current_text = username
        end

        if vis.img.ImageColor3 ~= target_color then
            vis.img.ImageColor3 = target_color
            vis.label.TextColor3 = target_color
        end
    end

    for uid, vis in pairs(sv) do
        if not vis.updated then
            pcall(function()
                vis.frame:Destroy()
            end)
            sv[uid] = nil
        end
    end
end

--- API

function M.update_cursors(dOS)
    local owner_name = dOS.os_settings.owner_username or ""
    local lag_state = _tick_lag_state()

    if dOS.DWM and dOS.DWM._state and #dOS.DWM._state.screens > 1 then
        for _, ctx in ipairs(dOS.DWM._state.screens) do
            local proxy = dOS.DWM.make_screen_proxy(dOS, ctx)
            _update_screen(dOS, ctx.id, ctx.hw, proxy, owner_name, lag_state)
        end
    end
end

return M

-- EOF