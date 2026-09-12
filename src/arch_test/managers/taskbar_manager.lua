--[[
    "TaskBar manager module for dOS"
    
    @module taskbar_manager
	@version 1.6.2
	@updated 4/5/2026
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


local M = {
	_stop_drag = nil,
	_drag_loop = nil,
	update_layout = nil,
	refresh_mirror_taskbars = nil,
}

--- CONST

local TB_THICKNESS = 44
local TAB_H = 34
local TAB_MAX_W = 160
local TAB_ICON_W = 44
local TAB_PAD = 4
local IND_H = 3
local IND_R = 2
local START_W = 70
local VDM_W = 44
local CLOCK_W = 90
local BADGE_SIZE = 12
local BADGE_MARGIN = 3

local TABS_START_H = START_W + VDM_W + 8

local DRAG_HOLD_S = 0.15
local DRAG_PX = 8
local DRAG_MARGIN = 60

local ANIM_FAST = 0.12
local ANIM_MED = 0.22
local ANIM_SLOW = 0.38

local DRAG_LIFT_RADIUS = 80 -- exponential decay radius (in px)
local DRAG_LIFT_MAX = 8 -- maximum upward lift at distance=0 (in px)
local DRAG_LIFT_LERP = 0.20
local REORDER_COOLDOWN = 0.12

local PREVIEW_W = 180
local PREVIEW_H = 120
local PREVIEW_TITLE_H = 22
local PREVIEW_HOVER_DELAY = 0.5

local C_NEVER = "Never"
local C_ALWAYS = "Always"
local POS_BOTTOM = "Bottom"
local POS_TOP = "Top"
local POS_LEFT = "Left"

local ICON_PIN = 82008729089381
local ICON_UNPIN = 83047670009544
local ICON_MIN = 113219401636939
local ICON_RESTORE = 138072872426546
local ICON_MAX = 115558082558028
local ICON_RESTDOWN = 12105707939
local ICON_CLOSE = 136968209449975
local ICON_CLOSE_ALL = 136968209449975
local ICON_BADGE = 130287246681962

--- STATE

M.taskbar_manager = {
	frame = nil,
	tabs_holder = nil,
	start_button = nil,
	clock_frame = nil,

	window_tabs = {},
	tab_order = {},
	group_tabs = {},
	pinned_apps = {},

	context_menu = nil,
	context_menu_shield = nil,
	preview_popup = nil,
	preview_hover_active = false,

	hidden = false,

	tab_drag = {
		active = false,
		win_frame = nil,
		tab_frame = nil,
		orig_idx = 0,
		cur_idx = 0,
		latest_x = 0,
		latest_y = 0,
		last_swap_x = 0,
		tab_tweens = {},
	},

	vdm_btn_pos = UDim2.new(0, START_W + 4, 0.5, -14),
	vdm_btn_size = UDim2.fromOffset(VDM_W - 8, 28),

	debounce_timers = {},
	tab_pos_tweens = {},

	minimized_apps_holder = nil,
	minimized_windows = {},
	ICON_WIDTH = TAB_MAX_W,
	ICON_PADDING = TAB_PAD,

	-- mirrors[screen_id] = { screen_ctx, proxy, frame, tabs_holder, tab_buttons }
	mirrors = {},
	-- Stored reference so mirror start buttons can invoke the primary start menu.
	_on_start_click = nil,
}

--- HELPERS

local function dp_err(dOS, app: string?)
	dOS.MessageBox.error(dOS, "Error", `Could not open {if app then app else "the requested Application"}.`)
end

local function find_app_in_data(special, title)
	if not special or not special.start_menu_data or not title or title == "" then return nil end
	local all_apps = special.start_menu_data.all_apps

	-- exact
	for _, app in ipairs(all_apps) do
		if app.name == title then return app end
	end

	-- title starts with app name
	for _, app in ipairs(all_apps) do
		local n = #app.name
		if n > 0 and title:sub(1, n) == app.name then return app end
	end

	-- app name starts with title
	for _, app in ipairs(all_apps) do
		local t = #title
		if t > 0 and app.name:sub(1, t) == title then return app end
	end

	-- app name is a substring of title and the other way around
	for _, app in ipairs(all_apps) do
		if title:find(app.name, 1, true) or app.name:find(title, 1, true) then return app end
	end

	-- shared keyword
	for _, app in ipairs(all_apps) do
		for word in app.name:gmatch("%a+") do
			if #word > 4 and title:find(word, 1, true) then return app end
		end
	end

	return nil
end

local function hydrate_pin(pin_data, special)
	if not pin_data then return end
	if not special or not special.start_menu_data then return end

	local search = pin_data.app_name or pin_data.title
	local app = find_app_in_data(special, search)

	-- fallback
	if not app and pin_data.icon_id and pin_data.icon_id > 0 then
		for _, a in ipairs(special.start_menu_data.all_apps) do
			if a.icon_id == pin_data.icon_id then
				app = a
				break
			end
		end
	end

	if app then
		pin_data.launch_func = pin_data.launch_func or app.launch_func
		pin_data.app_name = pin_data.app_name or app.name

		if not pin_data.icon_id or pin_data.icon_id == 0 then pin_data.icon_id = app.icon_id end
	end
end

local function open_app_by_title(dOS, title)
	local tm = M.taskbar_manager
	local special = tm.__Special

	if not special or not special.start_menu_data then
		warn("[TaskbarManager] Start menu data not available for:", title)
		dp_err(dOS, title)
		return
	end

	local app = find_app_in_data(special, title)
	if app and app.launch_func then
		task.spawn(app.launch_func)
		return
	end

	warn("[TaskbarManager] App not found in start menu:", title)
	dp_err(dOS, title)
end

local function debounce(key, delay, callback)
	local tm = M.taskbar_manager

	if tm.debounce_timers[key] then
		tm.debounce_timers[key].deadline = os.clock() + delay
		tm.debounce_timers[key].callback = callback
	else
		tm.debounce_timers[key] = { deadline = os.clock() + delay, callback = callback }
		task.spawn(function()
			while tm.debounce_timers[key] do
				local remaining = tm.debounce_timers[key].deadline - os.clock()

				if remaining <= 0 then
					local cb = tm.debounce_timers[key].callback
					tm.debounce_timers[key] = nil
					if cb then cb() end
					break
				end
				task.wait(math.max(0.016, remaining))
			end
		end)
	end
end

local function cancel_debounce(key) M.taskbar_manager.debounce_timers[key] = nil end

local function cancel_tab_tween(wf)
	local t = M.taskbar_manager.tab_pos_tweens[wf]
	if t then
		pcall(function() t:Cancel() end)
		M.taskbar_manager.tab_pos_tweens[wf] = nil
	end
end

local function set_tab_tween(wf, t)
	cancel_tab_tween(wf)
	M.taskbar_manager.tab_pos_tweens[wf] = t
end

local function cursor_to_slot(local_cx, local_cy, g_off, tw, th, count, is_vertical)
	if count == 0 then return 1 end
	local raw

	if is_vertical then
		raw = (local_cy - g_off - th * 0.5) / (th + TAB_PAD)
	else
		raw = (local_cx - g_off - tw * 0.5) / (tw + TAB_PAD)
	end

	return math.clamp(math.floor(raw + 0.5) + 1, 1, count)
end

local function get_cfg(dOS)
	local s = dOS.os_settings
	return {
		position = s.taskbar_position or POS_BOTTOM,
		hide_fullscreen = s.taskbar_hide_fullscreen or false,
		large_tabs = (s.taskbar_large_tabs ~= false),
		combine = s.taskbar_combine or C_NEVER,
	}
end

local function is_horiz(pos) return pos == POS_BOTTOM or pos == POS_TOP end

local function get_clock_parts()
	local t = os.date("*t", os.time())
	local hour = (t.hour + 4) % 24 -- TODO: HACK: Timezone selection
	return hour, tonumber(string.format("%02d", t.min))
end

local function active_tab_order(dOS)
	local tm = M.taskbar_manager
	local vdm = dOS and dOS.VDM
	if not (vdm and vdm._state and vdm._state.win_di) then return tm.tab_order end

	local active_di = vdm._state.active_di
	local filtered = {}

	for _, wf in ipairs(tm.tab_order) do
		local di = vdm._state.win_di[wf]
		if not di or di == active_di then table.insert(filtered, wf) end
	end

	return filtered
end

local function effective_mode(cfg, dOS)
	if cfg.combine == C_ALWAYS then return "group" end
	if cfg.combine == C_NEVER then return "individual" end

	local tm = M.taskbar_manager
	local tab_count = #active_tab_order(dOS)

	local ghost_count = 0
	for _, pd in pairs(tm.pinned_apps) do
		if pd.ghost_tab and pd.ghost_tab.is_ghost and pd.ghost_tab.tab_frame and pd.ghost_tab.tab_frame.Parent then
			ghost_count += 1
		end
	end

	if tab_count == 0 and ghost_count == 0 then return "individual" end

	local is_vertical = not is_horiz(cfg.position)

	if is_vertical then
		local holder_h = tm.tabs_holder and tm.tabs_holder.AbsoluteSize.Y or 400

		local ghost_section = ghost_count > 0 and (TAB_PAD + ghost_count * (TAB_H + TAB_PAD)) or TAB_PAD
		local tab_section = tab_count * (TAB_H + TAB_PAD)
		local total_h = ghost_section + tab_section
		return (total_h > holder_h) and "group" or "individual"
	else
		local holder_w = tm.tabs_holder and tm.tabs_holder.AbsoluteSize.X or 400

		local ghost_w = tab_count > 0 and TAB_ICON_W or TAB_MAX_W
		local ghost_section = ghost_count > 0 and (TAB_PAD + ghost_count * (ghost_w + TAB_PAD)) or TAB_PAD
		local available = holder_w - ghost_section

		local min_tab_w = TAB_ICON_W + 20
		local tab_section = tab_count * (min_tab_w + TAB_PAD)
		return (tab_section > available) and "group" or "individual"
	end
end

local function compute_groups(dOS)
	local groups = {}
	local group_map = {}

	for _, wf in ipairs(active_tab_order(dOS)) do
		local meta = dOS.window_metadata[wf]
		if meta then
			local key = meta.title
			if not group_map[key] then
				local g = { key = key, wins = {} }
				group_map[key] = g
				table.insert(groups, g)
			end
			table.insert(group_map[key].wins, wf)
		end
	end

	return groups, group_map
end

local function tab_width_individual(cfg, dOS)
	local tm = M.taskbar_manager
	local order = active_tab_order(dOS)
	local count = #order

	if count == 0 then return TAB_MAX_W end
	if not cfg.large_tabs then return TAB_ICON_W end

	local hw = tm.tabs_holder and tm.tabs_holder.AbsoluteSize.X or 400
	local ghost_n = 0
	for _, pd in pairs(tm.pinned_apps) do
		if pd.ghost_tab and pd.ghost_tab.is_ghost and pd.ghost_tab.tab_frame and pd.ghost_tab.tab_frame.Parent then
			ghost_n += 1
		end
	end

	local ghost_used = ghost_n > 0 and (TAB_PAD + ghost_n * (TAB_ICON_W + TAB_PAD)) or TAB_PAD
	local available = hw - ghost_used
	local slot = math.floor((available - TAB_PAD) / count) - TAB_PAD

	return math.clamp(slot, TAB_ICON_W, TAB_MAX_W)
end

local function tab_width_group(cfg, group_count, reserved_px)
	local tm = M.taskbar_manager
	if group_count == 0 then return TAB_MAX_W end
	if not cfg.large_tabs then return TAB_ICON_W end

	local hw = tm.tabs_holder and tm.tabs_holder.AbsoluteSize.X or 400
	local available = hw - (reserved_px or 0)
	local slot = math.floor((available - TAB_PAD) / group_count) - TAB_PAD

	return math.clamp(slot, TAB_ICON_W, TAB_MAX_W)
end

local function resolve_icon_id(dOS, meta)
	if not meta then return nil end

	if meta.taskbar_icon then
		local id = type(meta.taskbar_icon) == "number" and meta.taskbar_icon or tonumber(meta.taskbar_icon)
		if id and id > 0 then return id end
	end

	if dOS._app_icon_map and meta.title then
		local id = dOS._app_icon_map[meta.title]
		if id and type(id) == "number" and id > 0 then return id end

		local title = meta.title

		local best_id, best_len = nil, 0
		for name, icon in pairs(dOS._app_icon_map) do
			local n = #name
			if n > best_len and title:sub(1, n) == name then
				best_id, best_len = icon, n
			end
		end
		if best_id and best_id > 0 then return best_id end

		for name, icon in pairs(dOS._app_icon_map) do
			if title ~= "" and name:sub(1, #title) == title then
				if icon and icon > 0 then return icon end
			end
		end

		for name, icon in pairs(dOS._app_icon_map) do
			if title:find(name, 1, true) or name:find(title, 1, true) then
				if icon and icon > 0 then return icon end
			end
		end
	end

	-- fallback
	local tm = M.taskbar_manager
	if tm and tm.__Special and tm.__Special.start_menu_data and meta.title then
		local app = find_app_in_data(tm.__Special, meta.title)
		if app and type(app.icon_id) == "number" and app.icon_id > 0 then return app.icon_id end
	end

	return nil
end

local function bg_trans(is_focused, is_minimized, is_ghost)
	if is_ghost then return 0.85 end
	if is_focused then return 0.25 end
	if is_minimized then return 0.78 end
	return 0.65
end

local function tab_y() return math.floor((TB_THICKNESS - TAB_H) / 2) end

local function get_sorted_ghosts(tm)
	local list = {}

	for _, pd in pairs(tm.pinned_apps) do
		if pd.ghost_tab and pd.ghost_tab.is_ghost and pd.ghost_tab.tab_frame and pd.ghost_tab.tab_frame.Parent then
			table.insert(list, pd)
		end
	end

	table.sort(list, function(a, b) return (a.position_index or 1) < (b.position_index or 1) end)
	return list
end

local function ghost_section_width(tm, is_vertical)
	local n = 0

	for _, pd in pairs(tm.pinned_apps) do
		if pd.ghost_tab and pd.ghost_tab.is_ghost and pd.ghost_tab.tab_frame and pd.ghost_tab.tab_frame.Parent then
			n += 1
		end
	end
	if n == 0 then return TAB_PAD end

	if is_vertical then
		return TAB_PAD + n * (TAB_H + TAB_PAD)
	else
		return TAB_PAD + n * (TAB_ICON_W + TAB_PAD)
	end
end

local function taskbar_content_overflows(tm, cfg)
	if not tm.tabs_holder then return false end

	local is_vertical = not is_horiz(cfg.position)
	local holder_size = is_vertical and tm.tabs_holder.AbsoluteSize.Y or tm.tabs_holder.AbsoluteSize.X
	local canvas_size = is_vertical and tm.tabs_holder.CanvasSize.Y.Offset or tm.tabs_holder.CanvasSize.X.Offset

	return canvas_size > holder_size + 1 -- +1 for floating point tolerance
end

local function save_pinned_apps(dOS)
	local tm = M.taskbar_manager
	if not dOS.disk then return end

	local s, e = pcall(function()
		local data = {}
		for title, pd in pairs(tm.pinned_apps) do
			data[title] = {
				title = pd.title,
				app_name = pd.app_name,
				icon_id = pd.icon_id,
				position_index = pd.position_index,
			}
		end
		local json = JSONEncode(data)
		dOS.disk:Write(dOS.PINNED_TASKBAR_DISK_FILE, json)
	end)

	if not s then
		warn(`[TaskBar Manager]: Could not save the pin data: '{e}'.`)
		dOS.MessageBox.error(dOS, "Error", "Could not save the TaskBar pins configuration.")
	end
end

local function load_pinned_apps(dOS)
	local tm = M.taskbar_manager
	if not dOS.disk then return end

	local success, data = pcall(function()
		local json = dOS.disk:Read(dOS.PINNED_TASKBAR_DISK_FILE)
		if not json or json == "" then return nil end
		return JSONDecode(json)
	end)

	if success and data and type(data) == "table" then
		for title, pd in pairs(data) do
			if type(pd) == "table" and pd.title then
				tm.pinned_apps[title] = {
					title = pd.title,
					app_name = pd.app_name, -- may be nil
					icon_id = pd.icon_id,
					position_index = pd.position_index or 1,
					ghost_tab = nil,
					launch_func = nil,
				}
			end
		end
	end
end

--- UNDERLINE

local function create_stacked_underline(dOS, parent, zindex)
	local secondary = dOS.create_gui_element(dOS, "Frame", {
		Parent = parent,
		Name = "StackedUnderline",
		Size = UDim2.fromOffset(0, IND_H),
		Position = UDim2.new(0.5, 0, 1, -IND_H - 5),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = dOS.THEME.TEXT_DIM,
		BackgroundTransparency = 1,
		ZIndex = zindex - 1,
		Visible = false,
	})
	dOS.create_gui_element(dOS, "UICorner", { Parent = secondary, CornerRadius = UDim.new(0, IND_R) })
	return secondary
end

local function update_stacked_underline(dOS, gtd, count, tw, mode)
	if not gtd or not gtd.stacked_underline then return end
	local underline = gtd.stacked_underline

	local should_show = (mode == "group" and count > 1)

	if should_show then
		underline.Visible = true
		local main_w = math.max(6, tw and (tw - 14 - 6) or 20)
		local info = dOS.TweenInfo.new(ANIM_MED, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		dOS.Tween.new(underline, { Size = UDim2.fromOffset(main_w, IND_H), BackgroundTransparency = 0.4 }, info):Play()
	else
		if underline.Visible then
			local info = dOS.TweenInfo.new(ANIM_FAST, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			dOS.Tween.new(underline, { Size = UDim2.fromOffset(0, IND_H), BackgroundTransparency = 1 }, info):Play()
			task.delay(ANIM_FAST, function()
				if underline and underline.Parent then underline.Visible = false end
			end)
		end
	end
end

--- MORE ANIMATIONS

local function animate_indicator(dOS, td, state_name, tw)
	if not td or not td.indicator or not td.indicator.Parent then return end
	local ind = td.indicator
	local full = tw or (td.tab_frame and td.tab_frame.AbsoluteSize.X) or 80

	local target_w, target_color, target_trans
	if state_name == "focused" then
		target_w = full - 14
		target_color = dOS.THEME.ACCENT_BUTTON_BG
		target_trans = 0
	elseif state_name == "minimized" then
		target_w = 6
		target_color = dOS.THEME.TEXT_DIM
		target_trans = 0.15
	elseif state_name == "ghost" then
		target_w = 0
		target_color = dOS.THEME.TEXT_DIM
		target_trans = 1
	else
		target_w = 3
		target_color = dOS.THEME.TEXT_DIM
		target_trans = 0.55
	end

	if td.ind_tween then
		pcall(function() td.ind_tween:Cancel() end)
		td.ind_tween = nil
	end

	local ver = (td.anim_ver or 0) + 1
	td.anim_ver = ver

	local s_info = dOS.TweenInfo.new(ANIM_MED, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local c_info = dOS.TweenInfo.new(ANIM_MED, Enum.EasingStyle.Linear)
	local tgt_sz = UDim2.fromOffset(target_w, IND_H)
	local tgt_pos = UDim2.new(0.5, 0, 1, -IND_H - 2)

	local t = dOS.Tween.new(ind, { Size = tgt_sz, Position = tgt_pos }, s_info)
	td.ind_tween = t
	t:Play()
	dOS.Tween.new(ind, { BackgroundColor3 = target_color, BackgroundTransparency = target_trans }, c_info):Play()

	if state_name == "minimized" then
		task.spawn(function()
			task.wait(ANIM_MED + 0.02)
			if td.anim_ver ~= ver or not ind.Parent then return end
			local j1 = dOS.TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local j2 = dOS.TweenInfo.new(0.18, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
			dOS.Tween.new(ind, { Position = UDim2.new(0.5, 0, 1, -IND_H - 7) }, j1):Play()
			task.wait(0.12)

			if td.anim_ver ~= ver or not ind.Parent then return end
			dOS.Tween.new(ind, { Position = tgt_pos }, j2):Play()
		end)
	end
end

local function ind_state_for_win(dOS, wf)
	local meta = dOS.window_metadata[wf]
	if not meta then return "unfocused" end
	if meta.is_minimized then return "minimized" end
	if dOS.active_window_frame == wf then return "focused" end
	return "unfocused"
end

local function ind_state_for_group(dOS, gtd)
	local has_focused = false
	local all_minimized = true
	local has_any_window = #gtd.win_frames > 0

	for _, wf in ipairs(gtd.win_frames) do
		local meta = dOS.window_metadata[wf]
		if not meta then continue end

		if wf == dOS.active_window_frame and not meta.is_minimized then has_focused = true end

		if not meta.is_minimized then all_minimized = false end
	end

	-- focused > minimized (all) > unfocused
	if has_focused then return "focused" end
	if has_any_window and all_minimized then return "minimized" end
	if has_any_window then return "unfocused" end
	return "unfocused"
end

local function apply_icon_pos(td, show_title)
	if not td.icon_elem then return end

	if show_title then
		td.icon_elem.AnchorPoint = Vector2.new(0, 0.5)
		td.icon_elem.Position = UDim2.new(0, 5, 0.5, 0)
	else
		td.icon_elem.AnchorPoint = Vector2.new(0.5, 0.5)
		td.icon_elem.Position = UDim2.fromScale(0.5, 0.5)
	end
end

local function refresh_tab_style(dOS, td, tw, show_title)
	if not td or not td.tab_frame or not td.tab_frame.Parent then return end

	if td.title_label then td.title_label.Visible = show_title end
	apply_icon_pos(td, show_title)

	local state = td.is_ghost and "ghost" or ind_state_for_win(dOS, td.win_frame)
	animate_indicator(dOS, td, state, tw)
end

local function refresh_group_style(dOS, gtd, tw, show_title, mode)
	if not gtd or not gtd.tab_frame or not gtd.tab_frame.Parent then return end

	if gtd.title_label then gtd.title_label.Visible = show_title end
	apply_icon_pos(gtd, show_title)

	if gtd.badge_icon then
		local should_show = (#gtd.win_frames > 1)
		if should_show and not gtd.badge_icon.Visible then
			gtd.badge_icon.Visible = true
			gtd.badge_icon.ImageTransparency = 1
			local info = dOS.TweenInfo.new(ANIM_MED, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			dOS.Tween.new(gtd.badge_icon, { ImageTransparency = 0 }, info):Play()
		elseif not should_show and gtd.badge_icon.Visible then
			local info = dOS.TweenInfo.new(ANIM_FAST, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local badge = gtd.badge_icon
			dOS.Tween.new(badge, { ImageTransparency = 1 }, info):Play()
			task.delay(ANIM_FAST, function()
				if badge and badge.Parent and badge.ImageTransparency >= 0.99 then badge.Visible = false end
			end)
		end
	end

	update_stacked_underline(dOS, gtd, #gtd.win_frames, tw, mode)
	animate_indicator(dOS, gtd, ind_state_for_group(dOS, gtd), tw)
end

--- WINDOW PREVIEW

local function close_preview_popup(dOS)
	local tm = M.taskbar_manager
	tm._preview_generation_active = false

	if not tm.preview_popup or not tm.preview_popup.Parent then
		tm.preview_hover_active = false
		tm.preview_popup = nil
		return
	end
	if tm.preview_hover_active then return end

	local popup = tm.preview_popup
	tm.preview_popup = nil
	tm._preview_animating_out = true

	local cfg = get_cfg(dOS)
	local pos = cfg.position

	local slide_offset_y, slide_offset_x = 0, 0
	if pos == POS_BOTTOM then
		slide_offset_y = 8
	elseif pos == POS_TOP then
		slide_offset_y = -8
	elseif pos == POS_LEFT then
		slide_offset_x = -8
	else
		slide_offset_x = 8
	end

	local children = {}
	for _, child in ipairs(popup:GetChildren()) do
		if child.Name == "PreviewCard" then table.insert(children, child) end
	end

	local stagger_delay = 0.015
	local child_anim_time = 0.06

	for i = #children, 1, -1 do
		local child = children[i]
		local delay_time = (#children - i) * stagger_delay
		task.delay(delay_time, function()
			if not child or not child.Parent then return end
			local out_info = dOS.TweenInfo.new(child_anim_time, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			dOS.Tween
				.new(child, {
					BackgroundTransparency = 1,
					Position = child.Position + UDim2.fromOffset(0, 5),
				}, out_info)
				:Play()
		end)
	end

	local total_child_time = #children * stagger_delay + child_anim_time
	task.delay(math.min(total_child_time * 0.3, 0.05), function()
		if not popup or not popup.Parent then return end

		local current_pos = popup.Position
		local out_info = dOS.TweenInfo.new(0.1, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

		dOS.Tween
			.new(popup, {
				Size = UDim2.fromOffset(popup.AbsoluteSize.X, 0),
				Position = UDim2.new(
					current_pos.X.Scale,
					current_pos.X.Offset + slide_offset_x,
					current_pos.Y.Scale,
					current_pos.Y.Offset + slide_offset_y
				),
				BackgroundTransparency = 1,
			}, out_info)
			:Play()

		task.delay(0.12, function()
			tm._preview_animating_out = false
			if popup and popup.Parent then popup:Destroy() end
		end)
	end)
end

local function generate_thumbnail_async(dOS, win_frame, thumb_container, zindex, generation_id)
	local tm = M.taskbar_manager

	if not win_frame or not win_frame.Parent then return end
	if not thumb_container or not thumb_container.Parent then return end

	local orig_size = win_frame.AbsoluteSize
	local orig_pos = win_frame.AbsolutePosition

	if orig_size.X < 10 or orig_size.Y < 10 then return end

	local container_size = thumb_container.AbsoluteSize
	local target_w = container_size.X - 4
	local target_h = container_size.Y - 4

	local scale_x = target_w / orig_size.X
	local scale_y = target_h / orig_size.Y
	local scale = math.min(scale_x, scale_y, 0.4)

	local thumb_w = math.max(30, math.floor(orig_size.X * scale))
	local thumb_h = math.max(20, math.floor(orig_size.Y * scale))

	local thumb = dOS.create_gui_element(dOS, "Frame", {
		Parent = thumb_container,
		Name = "Thumbnail",
		Size = UDim2.fromOffset(thumb_w, thumb_h),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = dOS.THEME.WINDOW_BG,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = zindex,
		ClipsDescendants = true,
	})
	dOS.create_gui_element(dOS, "UICorner", { Parent = thumb, CornerRadius = UDim.new(0, 2) })

	local all_objects = {}

	local function collect_recursive(parent, depth)
		for _, child in ipairs(parent:GetChildren()) do
			local ok, is_gui = pcall(function() return child:IsA("GuiObject") end)
			if ok and is_gui then
				local vis_ok, visible = pcall(function() return child.Visible end)
				if vis_ok and visible then
					table.insert(all_objects, { obj = child, depth = depth })
					collect_recursive(child, depth + 1)
				end
			end
		end
	end

	collect_recursive(win_frame, 0)
	table.sort(all_objects, function(a, b) return a.depth < b.depth end)

	local batch_size = 6
	local current_index = 1
	local total_objects = #all_objects

	local function process_batch()
		if tm._preview_generation_id ~= generation_id then return end
		if not tm._preview_generation_active then return end
		if not thumb or not thumb.Parent then return end
		if not thumb_container or not thumb_container.Parent then return end

		local batch_end = math.min(current_index + batch_size - 1, total_objects)

		for i = current_index, batch_end do
			local item = all_objects[i]
			if not item then continue end

			local child = item.obj
			local depth = item.depth

			if not child or not child.Parent then continue end

			local pos_ok, child_pos = pcall(function() return child.AbsolutePosition end)
			local size_ok, child_size = pcall(function() return child.AbsoluteSize end)

			if not pos_ok or not size_ok then continue end
			if child_size.X < 1 or child_size.Y < 1 then continue end

			local rel_x = child_pos.X - orig_pos.X
			local rel_y = child_pos.Y - orig_pos.Y

			if rel_x + child_size.X < 0 or rel_x > orig_size.X then continue end
			if rel_y + child_size.Y < 0 or rel_y > orig_size.Y then continue end

			local scaled_x = math.floor(rel_x * scale)
			local scaled_y = math.floor(rel_y * scale)
			local scaled_w = math.max(1, math.floor(child_size.X * scale))
			local scaled_h = math.max(1, math.floor(child_size.Y * scale))

			if scaled_w <= 1 and scaled_h <= 1 then continue end

			if scaled_x < 0 then
				scaled_w = scaled_w + scaled_x
				scaled_x = 0
			end
			if scaled_y < 0 then
				scaled_h = scaled_h + scaled_y
				scaled_y = 0
			end
			scaled_w = math.min(scaled_w, thumb_w - scaled_x)
			scaled_h = math.min(scaled_h, thumb_h - scaled_y)

			if scaled_w < 1 or scaled_h < 1 then continue end

			local clone_props = {
				Parent = thumb,
				Size = UDim2.fromOffset(scaled_w, scaled_h),
				Position = UDim2.fromOffset(scaled_x, scaled_y),
				BorderSizePixel = 0,
				ZIndex = zindex + depth + 1,
				ClipsDescendants = true,
			}

			local bg_ok, bg_color = pcall(function() return child.BackgroundColor3 end)
			local bt_ok, bg_trans_ = pcall(function() return child.BackgroundTransparency end)
			if bg_ok then clone_props.BackgroundColor3 = bg_color end
			if bt_ok then clone_props.BackgroundTransparency = bg_trans_ end

			local rot_ok, rotation = pcall(function() return child.Rotation end)
			if rot_ok and rotation ~= 0 then clone_props.Rotation = rotation end

			local ap_ok, anchor = pcall(function() return child.AnchorPoint end)
			if ap_ok and (anchor.X ~= 0 or anchor.Y ~= 0) then clone_props.AnchorPoint = anchor end

			local clone
			local cc = child.ClassName

			if cc == "TextLabel" or cc == "TextButton" or cc == "TextBox" then
				local text_ok, text = pcall(function() return child.Text end)
				local tc_ok, text_color = pcall(function() return child.TextColor3 end)
				local tt_ok, text_trans = pcall(function() return child.TextTransparency end)
				local ts_ok, text_size = pcall(function() return child.TextSize end)
				local font_ok, font = pcall(function() return child.Font end)
				local xa_ok, x_align = pcall(function() return child.TextXAlignment end)
				local ya_ok, y_align = pcall(function() return child.TextYAlignment end)
				local rt_ok, rich_text = pcall(function() return child.RichText end)
				local lh_ok, line_height = pcall(function() return child.LineHeight end)
				local tsp_ok, text_stroke_color = pcall(function() return child.TextStrokeColor3 end)
				local tspt_ok, text_stroke_trans = pcall(function() return child.TextStrokeTransparency end)

				local scaled_text_size = ts_ok and math.max(4, math.floor(text_size * scale)) or 5

				if text_ok and text ~= "" and #text > 0 and scaled_text_size >= 4 then
					clone_props.Text = text
					if tc_ok then clone_props.TextColor3 = text_color end
					if tt_ok then clone_props.TextTransparency = text_trans end
					if font_ok then clone_props.Font = font end
					if xa_ok then clone_props.TextXAlignment = x_align end
					if ya_ok then clone_props.TextYAlignment = y_align end
					if rt_ok then clone_props.RichText = rich_text end
					if lh_ok then clone_props.LineHeight = line_height end
					if tsp_ok then clone_props.TextStrokeColor3 = text_stroke_color end
					if tspt_ok then clone_props.TextStrokeTransparency = text_stroke_trans end
					clone_props.TextSize = scaled_text_size
					clone_props.TextTruncate = Enum.TextTruncate.AtEnd
					clone_props.TextWrapped = false
					clone_props.TextScaled = false
					clone = dOS.create_gui_element(dOS, "TextLabel", clone_props)
				else
					clone = dOS.create_gui_element(dOS, "Frame", clone_props)
				end
			elseif cc == "ImageLabel" or cc == "ImageButton" then
				local img_ok, img = pcall(function() return child.Image end)
				local ic_ok, img_color = pcall(function() return child.ImageColor3 end)
				local it_ok, img_trans = pcall(function() return child.ImageTransparency end)
				local st_ok, scale_type = pcall(function() return child.ScaleType end)
				local tl_ok, tile_size = pcall(function() return child.TileSize end)
				local sic_ok, slice_center = pcall(function() return child.SliceCenter end)
				local sis_ok, slice_scale = pcall(function() return child.SliceScale end)
				local iro_ok, img_rect_off = pcall(function() return child.ImageRectOffset end)
				local irs_ok, img_rect_size = pcall(function() return child.ImageRectSize end)
				local rp_ok, resample = pcall(function() return child.ResampleMode end)

				local has_image = img_ok
					and img
					and ((type(img) == "number" and img > 0) or (type(img) == "string" and img ~= ""))

				if has_image then
					clone_props.Image = img
					if ic_ok then clone_props.ImageColor3 = img_color end
					if it_ok then clone_props.ImageTransparency = img_trans end
					if st_ok then clone_props.ScaleType = scale_type end
					if tl_ok and scale_type == Enum.ScaleType.Tile then clone_props.TileSize = tile_size end
					if sic_ok and scale_type == Enum.ScaleType.Slice then clone_props.SliceCenter = slice_center end
					if sis_ok and scale_type == Enum.ScaleType.Slice then clone_props.SliceScale = slice_scale end
					if iro_ok then clone_props.ImageRectOffset = img_rect_off end
					if irs_ok then clone_props.ImageRectSize = img_rect_size end
					if rp_ok then clone_props.ResampleMode = resample end
					clone = dOS.create_gui_element(dOS, "ImageLabel", clone_props)
				else
					clone = dOS.create_gui_element(dOS, "Frame", clone_props)
				end
			elseif cc == "Frame" or cc == "ScrollingFrame" or cc == "CanvasGroup" or cc == "ViewportFrame" then
				clone = dOS.create_gui_element(dOS, "Frame", clone_props)
			end

			if clone then
				local corner = child:FindFirstChildOfClass("UICorner")
				if corner then
					local cr_ok, cr = pcall(function() return corner.CornerRadius end)
					if cr_ok and (cr.Offset > 0 or cr.Scale > 0) then
						local scaled_offset = math.max(1, math.floor(cr.Offset * scale))
						dOS.create_gui_element(dOS, "UICorner", {
							Parent = clone,
							CornerRadius = UDim.new(cr.Scale, scaled_offset),
						})
					end
				end

				local stroke = child:FindFirstChildOfClass("UIStroke")
				if stroke then
					local sc_ok, stroke_color = pcall(function() return stroke.Color end)
					local st_ok, stroke_thick = pcall(function() return stroke.Thickness end)
					local str_ok, stroke_trans = pcall(function() return stroke.Transparency end)
					local sap_ok, stroke_apply = pcall(function() return stroke.ApplyStrokeMode end)
					local slj_ok, stroke_join = pcall(function() return stroke.LineJoinMode end)

					local scaled_thickness = st_ok and math.max(1, math.floor(stroke_thick * scale)) or 1

					if scaled_thickness >= 1 then
						local stroke_props = { Parent = clone, Thickness = scaled_thickness }
						if sc_ok then stroke_props.Color = stroke_color end
						if str_ok then stroke_props.Transparency = stroke_trans end
						if sap_ok then stroke_props.ApplyStrokeMode = stroke_apply end
						if slj_ok then stroke_props.LineJoinMode = stroke_join end
						dOS.create_gui_element(dOS, "UIStroke", stroke_props)
					end
				end

				local gradient = child:FindFirstChildOfClass("UIGradient")
				if gradient then
					local gc_ok, grad_color = pcall(function() return gradient.Color end)
					local gt_ok, grad_trans = pcall(function() return gradient.Transparency end)
					local go_ok, grad_offset = pcall(function() return gradient.Offset end)
					local gr_ok, grad_rot = pcall(function() return gradient.Rotation end)

					local grad_props = { Parent = clone }
					if gc_ok then grad_props.Color = grad_color end
					if gt_ok then grad_props.Transparency = grad_trans end
					if go_ok then grad_props.Offset = grad_offset end
					if gr_ok then grad_props.Rotation = grad_rot end
					dOS.create_gui_element(dOS, "UIGradient", grad_props)
				end

				local padding = child:FindFirstChildOfClass("UIPadding")
				if padding then
					local pl_ok, pad_l = pcall(function() return padding.PaddingLeft end)
					local pr_ok, pad_r = pcall(function() return padding.PaddingRight end)
					local pt_ok, pad_t = pcall(function() return padding.PaddingTop end)
					local pb_ok, pad_b = pcall(function() return padding.PaddingBottom end)

					local function scale_udim(u) return UDim.new(u.Scale, math.floor(u.Offset * scale)) end

					local pad_props = { Parent = clone }
					if pl_ok then pad_props.PaddingLeft = scale_udim(pad_l) end
					if pr_ok then pad_props.PaddingRight = scale_udim(pad_r) end
					if pt_ok then pad_props.PaddingTop = scale_udim(pad_t) end
					if pb_ok then pad_props.PaddingBottom = scale_udim(pad_b) end
					dOS.create_gui_element(dOS, "UIPadding", pad_props)
				end
			end
		end

		current_index = batch_end + 1

		if current_index <= total_objects then task.defer(process_batch) end
	end

	if total_objects > 0 then task.defer(process_batch) end
end

local open_context_menu -- fwd decl

local function show_group_preview(dOS, gtd, tab_frame)
	local tm = M.taskbar_manager

	if tm.context_menu and tm.context_menu.Parent then return end
	if tm._preview_animating_out then return end

	tm._preview_generation_active = false

	if tm.preview_popup and tm.preview_popup.Parent then
		tm.preview_hover_active = false
		local old_popup = tm.preview_popup
		tm.preview_popup = nil
		old_popup:Destroy()
	end

	local wins = gtd.win_frames
	if #wins <= 1 then return end

	local cfg = get_cfg(dOS)
	local pos = cfg.position
	local item_count = #wins

	local card_w = PREVIEW_W
	local card_h = PREVIEW_H + PREVIEW_TITLE_H + 10
	local padding = 14
	local card_spacing = 12

	local screen_w = dOS.screen_dimensions.X
	local screen_h = dOS.screen_dimensions.Y
	local max_popup_w = math.min(screen_w * 0.85, 640)
	local max_popup_h = math.min(screen_h * 0.5, 400)

	local cols = 1
	if item_count >= 3 and max_popup_w >= (card_w * 2) + card_spacing + (padding * 2) then cols = 2 end
	if item_count >= 5 and max_popup_w >= (card_w * 3) + (card_spacing * 2) + (padding * 2) then cols = 3 end

	local rows = math.ceil(item_count / cols)

	local content_w = (cols * card_w) + ((cols - 1) * card_spacing) + (padding * 2)
	local content_h = (rows * card_h) + ((rows - 1) * card_spacing) + (padding * 2)

	local needs_scrolling = content_h > max_popup_h

	local popup_w = content_w + (needs_scrolling and 5 or 0)
	local popup_h = needs_scrolling and max_popup_h or content_h

	local tab_ap = tab_frame.AbsolutePosition
	local tab_sz = tab_frame.AbsoluteSize
	local px, py
	local anim_offset_x, anim_offset_y = 0, 0

	if pos == POS_BOTTOM then
		px = math.clamp(tab_ap.X + (tab_sz.X / 2) - (popup_w / 2), 10, screen_w - popup_w - 10)
		py = tab_ap.Y - popup_h - 12
		anim_offset_y = 14
	elseif pos == POS_TOP then
		px = math.clamp(tab_ap.X + (tab_sz.X / 2) - (popup_w / 2), 10, screen_w - popup_w - 10)
		py = tab_ap.Y + tab_sz.Y + 12
		anim_offset_y = -14
	elseif pos == POS_LEFT then
		px = tab_ap.X + tab_sz.X + 12
		py = math.clamp(tab_ap.Y + (tab_sz.Y / 2) - (popup_h / 2), 10, screen_h - popup_h - 10)
		anim_offset_x = -14
	else
		px = tab_ap.X - popup_w - 12
		py = math.clamp(tab_ap.Y + (tab_sz.Y / 2) - (popup_h / 2), 10, screen_h - popup_h - 10)
		anim_offset_x = 14
	end

	py = math.clamp(py, 10, screen_h - popup_h - 10)
	px = math.clamp(px, 10, screen_w - popup_w - 10)

	local tbz = tm.frame and tm.frame.ZIndex or 10
	local popup_z = tbz + 50

	--- ScrollingFrame when scrolling
	local popup

	if needs_scrolling then
		popup = dOS.create_gui_element(dOS, "ScrollingFrame", {
			Parent = dOS.screen,
			Name = "GroupPreviewPopup",
			Size = UDim2.fromOffset(popup_w, 0),
			Position = UDim2.fromOffset(px + anim_offset_x, py + anim_offset_y),
			BackgroundColor3 = dOS.THEME.WINDOW_BG:Lerp(Color3.new(0, 0, 0), 0.1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = popup_z,
			ClipsDescendants = true,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = dOS.THEME.TEXT_DIM,
			ScrollBarImageTransparency = 0.15,
			CanvasSize = UDim2.fromOffset(0, content_h),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
			MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
			BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",

			OnEnter = function()
				tm.preview_hover_active = true
				cancel_debounce("preview_close_" .. gtd.group_key)
			end,
			OnLeave = function()
				tm.preview_hover_active = false
				debounce("preview_close_" .. gtd.group_key, 0.35, function()
					if not tm.preview_hover_active then close_preview_popup(dOS) end
				end)
			end,
		})
	else
		popup = dOS.create_gui_element(dOS, "Frame", {
			Parent = dOS.screen,
			Name = "GroupPreviewPopup",
			Size = UDim2.fromOffset(popup_w, 0),
			Position = UDim2.fromOffset(px + anim_offset_x, py + anim_offset_y),
			BackgroundColor3 = dOS.THEME.WINDOW_BG:Lerp(Color3.new(0, 0, 0), 0.1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = popup_z,
			ClipsDescendants = true,

			OnEnter = function()
				tm.preview_hover_active = true
				cancel_debounce("preview_close_" .. gtd.group_key)
				return nil
			end,
			OnLeave = function()
				tm.preview_hover_active = false
				debounce("preview_close_" .. gtd.group_key, 0.35, function()
					if not tm.preview_hover_active then close_preview_popup(dOS) end
				end)
				return nil
			end,
		})
	end
	dOS.create_gui_element(dOS, "UICorner", { Parent = popup, CornerRadius = UDim.new(0, 14) })
	dOS.create_gui_element(dOS, "UIStroke", {
		Parent = popup,
		Color = dOS.THEME.BORDER_HIGHLIGHT:Lerp(dOS.THEME.ACCENT, 0.12),
		Thickness = 1,
		Transparency = 0.3,
	})

	tm.preview_popup = popup
	tm.preview_hover_active = false

	local generation_id = os.clock()
	tm._preview_generation_id = generation_id
	tm._preview_generation_active = true

	local cards = {}
	for i, wf in ipairs(wins) do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		local card_x = padding + (col * (card_w + card_spacing))
		local card_y = padding + (row * (card_h + card_spacing))

		local meta = dOS.window_metadata[wf]
		local title_text = (meta and meta.title) or "Window"
		local is_minimized = meta and meta.is_minimized
		local is_focused = wf == dOS.active_window_frame and not is_minimized

		local base_bg = dOS.THEME.TASKBAR_BG:Lerp(dOS.THEME.ACCENT, is_focused and 0.2 or 0.08)
		local hover_bg = dOS.THEME.TASKBAR_BG:Lerp(dOS.THEME.ACCENT, 0.32)

		local card = dOS.create_gui_element(dOS, "Frame", {
			Parent = popup,
			Name = "PreviewCard",
			Size = UDim2.fromOffset(card_w, card_h),
			Position = UDim2.fromOffset(card_x, card_y + 12),
			BackgroundColor3 = base_bg,
			BackgroundTransparency = 1,
			ZIndex = popup_z + 1,
		})
		dOS.create_gui_element(dOS, "UICorner", { Parent = card, CornerRadius = UDim.new(0, 12) })
		dOS.create_gui_element(dOS, "UIStroke", {
			Parent = card,
			Color = is_focused and dOS.THEME.ACCENT or dOS.THEME.BORDER_HIGHLIGHT,
			Thickness = 1,
			Transparency = is_focused and 0.35 or 0.6,
		})

		local thumb_holder = dOS.create_gui_element(dOS, "Frame", {
			Parent = card,
			Name = "ThumbHolder",
			Size = UDim2.new(1, -14, 0, PREVIEW_H - 14),
			Position = UDim2.fromOffset(7, 7),
			BackgroundColor3 = dOS.THEME.WINDOW_BG,
			BackgroundTransparency = 0.2,
			ZIndex = popup_z + 2,
			ClipsDescendants = true,
		})
		dOS.create_gui_element(dOS, "UICorner", { Parent = thumb_holder, CornerRadius = UDim.new(0, 8) })

		if is_minimized then
			local overlay = dOS.create_gui_element(dOS, "Frame", {
				Parent = thumb_holder,
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.5,
				ZIndex = popup_z + 20,
			})
			dOS.create_gui_element(dOS, "UICorner", { Parent = overlay, CornerRadius = UDim.new(0, 8) })
			dOS.create_gui_element(dOS, "TextLabel", {
				Parent = overlay,
				Text = "Minimized",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				TextColor3 = dOS.THEME.TEXT_DIM,
				Font = dOS.FONT_REGULAR,
				TextSize = 13,
				ZIndex = popup_z + 21,
			})
		end

		local title_section = dOS.create_gui_element(dOS, "Frame", {
			Parent = card,
			Name = "TitleSection",
			Size = UDim2.new(1, -14, 0, PREVIEW_TITLE_H),
			Position = UDim2.fromOffset(7, PREVIEW_H - 5),
			BackgroundTransparency = 1,
			ZIndex = popup_z + 2,
			ClipsDescendants = true,
		})

		local icon_id = resolve_icon_id(dOS, meta)
		local text_offset = 0

		if icon_id then
			dOS.create_gui_element(dOS, "ImageLabel", {
				Parent = title_section,
				Image = icon_id,
				Size = UDim2.fromOffset(18, 18),
				Position = UDim2.fromScale(0, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				ImageTransparency = is_minimized and 0.4 or 0,
				ZIndex = popup_z + 3,
			})
			text_offset = 24
		end

		dOS.create_gui_element(dOS, "TextLabel", {
			Parent = title_section,
			Text = title_text,
			Size = UDim2.new(1, -text_offset, 1, 0),
			Position = UDim2.fromOffset(text_offset, 0),
			BackgroundTransparency = 1,
			TextColor3 = dOS.THEME.TEXT_LIGHT,
			TextTransparency = is_minimized and 0.4 or 0,
			Font = dOS.FONT_REGULAR,
			TextSize = dOS.os_settings.global_font_size,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = popup_z + 3,
		})

		local click_overlay -- transparent

		if needs_scrolling then
			-- use AutoButtonColor in scroll mode to prevent invalid
			-- offset with regular dOS HoverColor
			click_overlay = dOS.create_gui_element(dOS, "TextButton", {
				Parent = card,
				Name = "ClickOverlay",
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromOffset(0, 0),
				BackgroundColor3 = hover_bg,
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = popup_z + 30,
				AutoButtonColor = true,

				OnEnter = function()
					tm.preview_hover_active = true
					cancel_debounce("preview_close_" .. gtd.group_key)
				end,
				OnLeave = function()
					tm.preview_hover_active = false
					debounce("preview_close_" .. gtd.group_key, 0.35, function()
						if not tm.preview_hover_active then close_preview_popup(dOS) end
					end)
				end,

				OnClick = function()
					tm.preview_hover_active = false
					tm._preview_generation_active = false
					close_preview_popup(dOS)

					task.defer(function()
						local m = dOS.window_metadata[wf]
						if m and m.is_minimized then
							dOS.Window.handle_unminimize_window(dOS, wf)
						else
							dOS.Window.set_active_window(dOS, wf)
						end
					end)
				end,
			})
		else
			click_overlay = dOS.create_gui_element(dOS, "TextButton", {
				Parent = card,
				Name = "ClickOverlay",
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = popup_z + 30,
				AutoButtonColor = false,

				OnEnter = function()
					tm.preview_hover_active = true
					cancel_debounce("preview_close_" .. gtd.group_key)

					local t = dOS.Tween.new(card, {
						BackgroundTransparency = 0.18,
						BackgroundColor3 = hover_bg,
					}, dOS.TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
					t:Play()
					return t
				end,
				OnLeave = function()
					debounce("preview_close_" .. gtd.group_key, 0.35, function()
						if not tm.preview_hover_active then close_preview_popup(dOS) end
					end)

					local t = dOS.Tween.new(card, {
						BackgroundTransparency = 0.38,
						BackgroundColor3 = base_bg,
					}, dOS.TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
					t:Play()
					return t
				end,

				OnClick = function()
					tm.preview_hover_active = false
					tm._preview_generation_active = false
					close_preview_popup(dOS)

					task.defer(function()
						local m = dOS.window_metadata[wf]
						if m and m.is_minimized then
							dOS.Window.handle_unminimize_window(dOS, wf)
						else
							dOS.Window.set_active_window(dOS, wf)
						end
					end)
				end,
			})
		end

		dOS.create_gui_element(dOS, "UICorner", { Parent = click_overlay, CornerRadius = UDim.new(0, 12) })

		-- context menu
		click_overlay.MouseButton2Click:Connect(function()
			tm.preview_hover_active = false
			tm._preview_generation_active = false
			close_preview_popup(dOS)

			local group_tab_frame = gtd.tab_frame

			task.defer(function() open_context_menu(dOS, wf, group_tab_frame, true, wins) end)
		end)

		table.insert(cards, {
			card = card,
			thumb_holder = thumb_holder,
			wf = wf,
			index = i,
			target_y = card_y,
		})
	end

	-- animate in
	task.spawn(function()
		task.wait()
		if not popup or not popup.Parent then return end

		local popup_tween = dOS.TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		dOS.Tween
			.new(popup, {
				Size = UDim2.fromOffset(popup_w, popup_h),
				Position = UDim2.fromOffset(px, py),
				BackgroundTransparency = 0,
			}, popup_tween)
			:Play()

		for _, card_data in ipairs(cards) do
			local card = card_data.card
			local idx = card_data.index
			local target_y = card_data.target_y

			local delay_time = 0.02 + ((idx - 1) * 0.025)

			task.delay(delay_time, function()
				if not card or not card.Parent then return end

				local card_tween = dOS.TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				dOS.Tween
					.new(card, {
						Position = UDim2.fromOffset(card.Position.X.Offset, target_y),
						BackgroundTransparency = 0.38,
					}, card_tween)
					:Play()
			end)
		end

		task.delay(0.06, function()
			if not tm._preview_generation_active then return end
			if tm._preview_generation_id ~= generation_id then return end

			local thumb_index = 1

			local function generate_next()
				if not tm._preview_generation_active then return end
				if tm._preview_generation_id ~= generation_id then return end
				if thumb_index > #cards then return end

				local card_data = cards[thumb_index]
				if card_data and card_data.thumb_holder and card_data.thumb_holder.Parent then
					generate_thumbnail_async(dOS, card_data.wf, card_data.thumb_holder, popup_z + 3, generation_id)
				end

				thumb_index += 1

				if thumb_index <= #cards then task.delay(0.012, generate_next) end
			end

			generate_next()
		end)
	end)
end

--- CONTEXT MENU

local function close_context_menu(dOS)
	local tm = M.taskbar_manager
	if tm.context_menu_shield and tm.context_menu_shield.Parent then
		tm.context_menu_shield:Destroy()
		tm.context_menu_shield = nil
	end
	if not (tm.context_menu and tm.context_menu.Parent) then return end
	local menu = tm.context_menu
	tm.context_menu = nil

	local out = dOS.TweenInfo.new(0.13, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	dOS.Tween.new(menu, { Size = UDim2.fromOffset(menu.AbsoluteSize.X, 0), BackgroundTransparency = 1 }, out):Play()
	task.delay(0.15, function()
		if menu and menu.Parent then menu:Destroy() end
	end)
end

open_context_menu = function(dOS, win_frame, tab_frame, is_group, group_wins)
	close_context_menu(dOS)

	local tm = M.taskbar_manager
	for key in pairs(tm.group_tabs) do
		cancel_debounce("group_preview_" .. key)
	end
	tm.preview_hover_active = false
	close_preview_popup(dOS)

	local meta = dOS.window_metadata[win_frame]
	if not meta then return end

	local cfg = get_cfg(dOS)
	local pos = cfg.position
	local items = {}
	local pinned = meta.taskbar_pinned == true

	items[#items + 1] = {
		label = pinned and "Unpin from taskbar" or "Pin to taskbar",
		icon = pinned and ICON_UNPIN or ICON_PIN,
		action = function()
			meta.taskbar_pinned = not pinned
			local tm_ = M.taskbar_manager
			if not pinned then
				local idx = 1
				for i, wf in ipairs(tm_.tab_order) do
					if wf == win_frame then
						idx = i
						break
					end
				end
				if not tm_.pinned_apps[meta.title] then
					tm_.pinned_apps[meta.title] = {
						icon_id = resolve_icon_id(dOS, meta),
						title = meta.title,
						position_index = idx,
						ghost_tab = nil,
						launch_func = nil,
					}
				else
					tm_.pinned_apps[meta.title].position_index = idx
				end

				hydrate_pin(tm_.pinned_apps[meta.title], tm_.__Special)
			else
				local pd = tm_.pinned_apps[meta.title]
				local ghost_only = pd and pd.ghost_tab and pd.ghost_tab.is_ghost

				if ghost_only and pd.ghost_tab.tab_frame and pd.ghost_tab.tab_frame.Parent then
					local tf = pd.ghost_tab.tab_frame
					local out_info = dOS.TweenInfo.new(ANIM_MED, Enum.EasingStyle.Back, Enum.EasingDirection.In)
					dOS.Tween
						.new(tf, { Size = UDim2.fromOffset(0, TAB_H), BackgroundTransparency = 1 }, out_info)
						:Play()
					task.delay(ANIM_MED + 0.05, function()
						if tf and tf.Parent then tf:Destroy() end
					end)
				end
				tm_.pinned_apps[meta.title] = nil
			end

			close_context_menu(dOS)
			M.update_layout(dOS)
			save_pinned_apps(dOS)
		end,
	}
	items[#items + 1] = { sep = true }

	if not meta.is_minimized then
		if meta.is_minimizable then
			items[#items + 1] = {
				label = "Minimize",
				icon = ICON_MIN,
				action = function()
					close_context_menu(dOS)
					dOS.Window.handle_minimize_window(dOS, win_frame)
				end,
			}
		end
	else
		items[#items + 1] = {
			label = "Restore",
			icon = ICON_RESTORE,
			action = function()
				close_context_menu(dOS)
				dOS.Window.handle_unminimize_window(dOS, win_frame)
			end,
		}
	end

	if meta.is_maximizable then
		if not meta.is_maximized then
			items[#items + 1] = {
				label = "Maximize",
				icon = ICON_MAX,
				action = function()
					close_context_menu(dOS)
					if meta.is_minimized then dOS.Window.handle_unminimize_window(dOS, win_frame) end
					task.spawn(dOS.Window.handle_maximize_window, dOS, win_frame)
				end,
			}
		else
			items[#items + 1] = {
				label = "Restore Down",
				icon = ICON_RESTDOWN,
				action = function()
					close_context_menu(dOS)
					dOS.Window.handle_maximize_window(dOS, win_frame)
				end,
			}
		end
	end

	if meta.is_closable then
		items[#items + 1] = { sep = true }
		if is_group and group_wins and #group_wins > 1 then
			items[#items + 1] = {
				label = "Close all windows",
				icon = ICON_CLOSE_ALL,
				danger = true,
				action = function()
					close_context_menu(dOS)
					for i, wf in ipairs(group_wins) do
						task.spawn(function()
							task.wait(i * 0.05)
							if wf and wf.Parent then dOS.Window.close_window(dOS, wf) end
						end)
					end
				end,
			}
		end
		items[#items + 1] = {
			label = "Close window",
			icon = ICON_CLOSE,
			danger = true,
			action = function()
				close_context_menu(dOS)
				dOS.Window.close_window(dOS, win_frame)
			end,
		}
	end

	local ROW_H = 32
	local SEP_H = 7
	local menu_h = 8

	for _, it in ipairs(items) do
		menu_h += it.sep and SEP_H or ROW_H
	end

	menu_h += 6
	local menu_w = 210

	local tab_ap = tab_frame.AbsolutePosition
	local tab_sz = tab_frame.AbsoluteSize
	local sw, sh = dOS.screen_dimensions.X, dOS.screen_dimensions.Y
	local mx, my

	if pos == POS_BOTTOM then
		mx, my = tab_ap.X, tab_ap.Y - menu_h - 4
	elseif pos == POS_TOP then
		mx, my = tab_ap.X, tab_ap.Y + tab_sz.Y + 4
	elseif pos == POS_LEFT then
		mx, my = tab_ap.X + tab_sz.X + 4, tab_ap.Y
	else
		mx, my = tab_ap.X - menu_w - 4, tab_ap.Y
	end

	mx = math.clamp(mx, 4, sw - menu_w - 4)
	my = math.clamp(my, 4, sh - menu_h - 4)

	local tbz = (M.taskbar_manager.frame and M.taskbar_manager.frame.ZIndex or 10)
	local shield_z = tbz + 9

	local shield = dOS.create_gui_element(dOS, "TextButton", {
		Name = "ContextMenuShield",
		Parent = dOS.screen,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = shield_z,
		Active = true,
	})
	M.taskbar_manager.context_menu_shield = shield
	shield.MouseButton1Click:Connect(function() close_context_menu(dOS) end)
	shield.MouseButton2Click:Connect(function() close_context_menu(dOS) end)

	local menu = dOS.create_gui_element(dOS, "Frame", {
		Name = "TaskbarContextMenu",
		Parent = dOS.screen,
		ZIndex = shield_z + 1,
		BackgroundColor3 = dOS.THEME.WINDOW_BG,
		BorderColor3 = dOS.THEME.BORDER_HIGHLIGHT,
		Size = UDim2.fromOffset(menu_w, 0),
		Position = UDim2.fromOffset(mx, my),
		ClipsDescendants = true,
	})
	dOS.create_gui_element(dOS, "UICorner", { Parent = menu, CornerRadius = UDim.new(0, 8) })
	M.taskbar_manager.context_menu = menu

	local in_info = dOS.TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	dOS.Tween.new(menu, { Size = UDim2.fromOffset(menu_w, menu_h) }, in_info):Play()

	local mz = menu.ZIndex or 1
	local y_c = 4
	for _, it in ipairs(items) do
		if it.sep then
			dOS.create_gui_element(dOS, "Frame", {
				Parent = menu,
				BackgroundColor3 = dOS.THEME.BORDER_HIGHLIGHT,
				BackgroundTransparency = 0.5,
				Size = UDim2.new(1, -20, 0, 1),
				Position = UDim2.fromOffset(10, y_c + 3),
				ZIndex = mz + 1,
			})
			y_c += SEP_H
		else
			local row
			row = dOS.create_gui_element(dOS, "TextButton", {
				Parent = menu,
				Text = "",
				BackgroundTransparency = 1,
				BackgroundColor3 = it.danger and Color3.fromRGB(180, 40, 40) or dOS.THEME.ACCENT_BUTTON_BG,
				Size = UDim2.new(1, -8, 0, ROW_H - 2),
				Position = UDim2.fromOffset(4, y_c),
				ZIndex = mz + 1,

				OnEnter = function()
					local t = dOS.Tween.new(
						row,
						{ BackgroundTransparency = it.danger and 0.25 or 0.65 },
						dOS.TweenInfo.new(0.08)
					)
					t:Play()
					return t
				end,
				OnLeave = function()
					local t = dOS.Tween.new(row, { BackgroundTransparency = 1 }, dOS.TweenInfo.new(0.12))
					t:Play()
					return t
				end,
			})
			dOS.create_gui_element(dOS, "UICorner", { Parent = row, CornerRadius = UDim.new(0, 5) })

			dOS.create_gui_element(dOS, "ImageLabel", {
				Parent = row,
				Image = it.icon,
				Size = UDim2.fromOffset(16, 16),
				Position = UDim2.new(0, 8, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				ImageColor3 = it.danger and Color3.fromRGB(255, 100, 100) or dOS.THEME.TEXT_LIGHT,
				ZIndex = mz + 2,
			})

			dOS.create_gui_element(dOS, "TextLabel", {
				Parent = row,
				Text = it.label,
				Size = UDim2.new(1, -38, 1, 0),
				Position = UDim2.fromOffset(34, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				TextColor3 = it.danger and Color3.fromRGB(255, 110, 110) or dOS.THEME.TEXT_LIGHT,
				Font = dOS.FONT_REGULAR,
				TextSize = dOS.os_settings.global_font_size,
				ZIndex = mz + 2,
			})

			row.MouseButton1Click:Connect(it.action)
			y_c += ROW_H
		end
	end
end

--- TAB FRAME

local setup_pin_drag -- fwd decl
local setup_tab_drag -- fwd decl

local function capture_grab_ratio(tab_frame, cursor)
	if not (tab_frame and cursor) then return 0.5, 0.5 end
	local ap = tab_frame.AbsolutePosition
	local sz = tab_frame.AbsoluteSize
	local gx = (sz.X and sz.X > 0) and math.clamp((cursor.X - ap.X) / sz.X, 0, 1) or 0.5
	local gy = (sz.Y and sz.Y > 0) and math.clamp((cursor.Y - ap.Y) / sz.Y, 0, 1) or 0.5
	return gx, gy
end

local function build_tab_frame(
	dOS,
	icon_id: number,
	title_text: string,
	tw: number,
	show_title: boolean,
	on_click: (() -> ())?,
	on_rclick: (() -> ())?,
	on_hover_enter: (() -> Tween?)?,
	on_hover_leave: (() -> Tween?)?,
	is_ghost: boolean?,
	drag_context,
	th_override -- optional tabs_holder for mirror taskbars - nil = primary
)
	local tm = M.taskbar_manager
	local th = th_override or tm.tabs_holder
	if not th then return nil end

	local mz = th.ZIndex or 1
	local yp = tab_y()
	local itrans = is_ghost and 0.85 or 0.55

	local hover_color = dOS.THEME.TASKBAR_BG:Lerp(dOS.THEME.ACCENT, 0.12)
	local focused_color = dOS.THEME.TASKBAR_BG:Lerp(dOS.THEME.ACCENT, 0.2)

	local hover_state = {
		is_hovered = false,
		use_auto_color = false,
		on_enter = on_hover_enter,
		on_leave = on_hover_leave,
		is_focused = false,
	}

	local tab_frame
	tab_frame = dOS.create_gui_element(dOS, "TextButton", {
		Name = "Tab_" .. title_text,
		Parent = th,
		Text = "",
		Size = UDim2.fromOffset(tw, TAB_H),
		Position = UDim2.fromOffset(-9999, yp),
		BackgroundColor3 = dOS.THEME.TASKBAR_BG,
		BackgroundTransparency = itrans,
		Active = true,
		ZIndex = mz + 1,
		AutoButtonColor = false,

		OnEnter = function()
			hover_state.is_hovered = true
			if hover_state.use_auto_color then return nil end

			if hover_state.on_enter then hover_state.on_enter() end
			if not tab_frame or not tab_frame.Parent then return nil end

			local base_trans = is_ghost and 0.85 or (hover_state.is_focused and 0.25 or 0.65)
			local target_trans = math.max(0.15, base_trans - 0.2)
			local target_color = hover_state.is_focused and focused_color or hover_color

			local t = dOS.Tween.new(
				tab_frame,
				{ BackgroundTransparency = target_trans, BackgroundColor3 = target_color },
				dOS.TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			)
			t:Play()
			return t
		end,
		OnLeave = function()
			hover_state.is_hovered = false
			if hover_state.use_auto_color then return nil end

			if hover_state.on_leave then hover_state.on_leave() end
			if not tab_frame or not tab_frame.Parent then return nil end

			local target_trans = is_ghost and 0.85 or (hover_state.is_focused and 0.25 or 0.65)
			local target_color = hover_state.is_focused and focused_color or dOS.THEME.TASKBAR_BG

			local t = dOS.Tween.new(
				tab_frame,
				{ BackgroundTransparency = target_trans, BackgroundColor3 = target_color },
				dOS.TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			)
			t:Play()
			return t
		end,
	})
	dOS.create_gui_element(dOS, "UICorner", { Parent = tab_frame, CornerRadius = UDim.new(0, 6) })

	local icon_elem
	local icon_trans = is_ghost and 0.5 or 0
	if icon_id then
		icon_elem = dOS.create_gui_element(dOS, "ImageLabel", {
			Parent = tab_frame,
			Image = icon_id,
			Size = UDim2.fromOffset(TAB_H - 12, TAB_H - 12),
			AnchorPoint = show_title and Vector2.new(0, 0.5) or Vector2.new(0.5, 0.5),
			Position = show_title and UDim2.new(0, 5, 0.5, 0) or UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			ImageTransparency = icon_trans,
			ZIndex = mz + 2,
		})
	else
		icon_elem = dOS.create_gui_element(dOS, "TextLabel", {
			Parent = tab_frame,
			Text = string.upper(string.sub(title_text, 1, 1)),
			Size = UDim2.fromOffset(TAB_H - 12, TAB_H - 12),
			AnchorPoint = show_title and Vector2.new(0, 0.5) or Vector2.new(0.5, 0.5),
			Position = show_title and UDim2.new(0, 5, 0.5, 0) or UDim2.fromScale(0.5, 0.5),
			BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
			BackgroundTransparency = 0.25 + (is_ghost and 0.3 or 0),
			TextColor3 = dOS.THEME.TEXT_LIGHT,
			TextTransparency = icon_trans,
			Font = dOS.FONT_BOLD,
			TextSize = 12,
			ZIndex = mz + 2,
		})
		dOS.create_gui_element(dOS, "UICorner", { Parent = icon_elem, CornerRadius = UDim.new(0, 4) })
	end

	local title_label = nil
	if show_title then
		title_label = dOS.create_gui_element(dOS, "TextLabel", {
			Parent = tab_frame,
			Text = title_text,
			Visible = true,
			Size = UDim2.new(1, -(TAB_H + 4 + BADGE_SIZE + BADGE_MARGIN * 2), 1, -(IND_H + 6)),
			Position = UDim2.fromOffset(TAB_H + 2, 0),
			BackgroundTransparency = 1,
			TextColor3 = dOS.THEME.TEXT_LIGHT,
			TextTransparency = is_ghost and 0.5 or 0,
			Font = dOS.FONT_REGULAR,
			TextSize = dOS.os_settings.global_font_size,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = mz + 2,
		})
	end

	local badge_icon = dOS.create_gui_element(dOS, "ImageLabel", {
		Parent = tab_frame,
		Name = "BadgeIcon",
		Image = ICON_BADGE,
		Size = UDim2.fromOffset(BADGE_SIZE, BADGE_SIZE),
		Position = UDim2.new(1, -(BADGE_SIZE + BADGE_MARGIN), 0, BADGE_MARGIN),
		AnchorPoint = Vector2.new(0, 0),
		BackgroundTransparency = 1,
		ImageTransparency = is_ghost and 0.5 or 0,
		Visible = false,
		ZIndex = mz + 3,
	})

	local stacked_underline = create_stacked_underline(dOS, tab_frame, mz + 2)

	local indicator = dOS.create_gui_element(dOS, "Frame", {
		Parent = tab_frame,
		Name = "Indicator",
		Size = UDim2.fromOffset(0, IND_H),
		Position = UDim2.new(0.5, 0, 1, -IND_H - 2),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = dOS.THEME.TEXT_DIM,
		BackgroundTransparency = 1,
		ZIndex = mz + 3,
	})
	dOS.create_gui_element(dOS, "UICorner", { Parent = indicator, CornerRadius = UDim.new(0, IND_R) })

	local _cbs = { click = on_click, rclick = on_rclick }

	tab_frame.MouseButton1Click:Connect(function()
		close_context_menu(dOS)
		M.taskbar_manager.preview_hover_active = false
		close_preview_popup(dOS)
		if _cbs.click then _cbs.click() end
	end)
	tab_frame.MouseButton2Click:Connect(function()
		if _cbs.rclick then _cbs.rclick() end
	end)

	local td_ref = {
		tab_frame = tab_frame,
		icon_elem = icon_elem,
		title_label = title_label,
		badge_icon = badge_icon,
		stacked_underline = stacked_underline,
		indicator = indicator,
		ind_tween = nil,
		anim_ver = 0,
		is_ghost = is_ghost or false,
		_cbs = _cbs,
		_positioned = false,
		_last_title = title_text,
		_hover_state = hover_state,
	}

	if drag_context then
		if drag_context.pin_data then
			setup_pin_drag(dOS, td_ref, drag_context.pin_data,
				drag_context.screen_hw, drag_context.tabs_holder, drag_context.taskbar_frame)
		elseif drag_context.win_frame then
			td_ref.win_frame = drag_context.win_frame
			setup_tab_drag(dOS, td_ref, drag_context.win_frame,
				drag_context.screen_hw, drag_context.tabs_holder, drag_context.taskbar_frame)
		end
	end

	return td_ref
end

local function update_tab_interaction_mode(dOS, td, use_click_for_preview)
	if not td or not td.tab_frame or not td.tab_frame.Parent then return end

	local overflows = taskbar_content_overflows(M.taskbar_manager, get_cfg(dOS))

	if td._hover_state then
		td._hover_state.use_auto_color = overflows
		td.tab_frame.AutoButtonColor = overflows
	end

	td._use_click_for_preview = overflows and use_click_for_preview
end

--- GHOSTS

local function make_ghost_rclick(dOS, title)
	return function()
		close_context_menu(dOS)
		close_preview_popup(dOS)

		local tm = M.taskbar_manager
		local tf_pin = tm.pinned_apps[title]
			and tm.pinned_apps[title].ghost_tab
			and tm.pinned_apps[title].ghost_tab.tab_frame
		if not tf_pin then return end

		local tab_ap = tf_pin.AbsolutePosition
		local cfg2 = get_cfg(dOS)
		local pos = cfg2.position
		local sw, sh = dOS.screen_dimensions.X, dOS.screen_dimensions.Y
		local ROW_H = 32
		local menu_w = 180
		local menu_h = 8 + ROW_H + 6
		local mx = math.clamp(tab_ap.X, 4, sw - menu_w - 4)
		local my
		if pos == POS_BOTTOM then
			my = tab_ap.Y - menu_h - 4
		else
			my = tab_ap.Y + TAB_H + 4
		end
		my = math.clamp(my, 4, sh - menu_h - 4)

		local tbz = (tm.frame and tm.frame.ZIndex or 10)
		local shield_z = tbz + 9

		local shield = dOS.create_gui_element(dOS, "TextButton", {
			Name = "ContextMenuShield",
			Parent = dOS.screen,
			Text = "",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = shield_z,
			Active = true,
		})
		tm.context_menu_shield = shield
		local function do_close()
			if shield and shield.Parent then shield:Destroy() end
			tm.context_menu_shield = nil
			local m = tm.context_menu
			if not (m and m.Parent) then
				tm.context_menu = nil
				return
			end
			tm.context_menu = nil
			local out = dOS.TweenInfo.new(0.13, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			dOS.Tween.new(m, { Size = UDim2.fromOffset(m.AbsoluteSize.X, 0), BackgroundTransparency = 1 }, out):Play()
			task.delay(0.15, function()
				if m and m.Parent then m:Destroy() end
			end)
		end
		shield.MouseButton1Click:Connect(do_close)
		shield.MouseButton2Click:Connect(do_close)

		local menu = dOS.create_gui_element(dOS, "Frame", {
			Name = "TaskbarContextMenu",
			Parent = dOS.screen,
			ZIndex = shield_z + 1,
			BackgroundColor3 = dOS.THEME.WINDOW_BG,
			BorderColor3 = dOS.THEME.BORDER_HIGHLIGHT,
			Size = UDim2.fromOffset(menu_w, 0),
			Position = UDim2.fromOffset(mx, my),
			ClipsDescendants = true,
		})
		dOS.create_gui_element(dOS, "UICorner", { Parent = menu, CornerRadius = UDim.new(0, 8) })
		tm.context_menu = menu

		local in_info = dOS.TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		dOS.Tween.new(menu, { Size = UDim2.fromOffset(menu_w, menu_h) }, in_info):Play()

		local mz = menu.ZIndex or 1
		local row
		row = dOS.create_gui_element(dOS, "TextButton", {
			Parent = menu,
			Text = "",
			BackgroundTransparency = 1,
			BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
			Size = UDim2.new(1, -8, 0, ROW_H - 2),
			Position = UDim2.fromOffset(4, 4),
			ZIndex = mz + 1,
			OnEnter = function() dOS.Tween.new(row, { BackgroundTransparency = 0.65 }, dOS.TweenInfo.new(0.08)):Play() end,
			OnLeave = function() dOS.Tween.new(row, { BackgroundTransparency = 1 }, dOS.TweenInfo.new(0.12)):Play() end,
		})
		dOS.create_gui_element(dOS, "UICorner", { Parent = row, CornerRadius = UDim.new(0, 5) })
		dOS.create_gui_element(dOS, "ImageLabel", {
			Parent = row,
			Image = ICON_UNPIN,
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.new(0, 8, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			ImageColor3 = dOS.THEME.TEXT_LIGHT,
			ZIndex = mz + 2,
		})
		dOS.create_gui_element(dOS, "TextLabel", {
			Parent = row,
			Text = "Unpin from taskbar",
			Size = UDim2.new(1, -38, 1, 0),
			Position = UDim2.fromOffset(34, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			TextColor3 = dOS.THEME.TEXT_LIGHT,
			Font = dOS.FONT_REGULAR,
			TextSize = dOS.os_settings.global_font_size,
			ZIndex = mz + 2,
		})
		row.MouseButton1Click:Connect(function()
			do_close()
			local pd2 = tm.pinned_apps[title]
			tm.pinned_apps[title] = nil
			if pd2 and pd2.ghost_tab and pd2.ghost_tab.tab_frame and pd2.ghost_tab.tab_frame.Parent then
				local old_tf = pd2.ghost_tab.tab_frame
				local out2 = dOS.TweenInfo.new(ANIM_MED, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				dOS.Tween.new(old_tf, { Size = UDim2.fromOffset(0, TAB_H), BackgroundTransparency = 1 }, out2):Play()
				task.delay(ANIM_MED + 0.05, function()
					if old_tf and old_tf.Parent then old_tf:Destroy() end
				end)
			end
			save_pinned_apps(dOS)
			M.update_layout(dOS)
		end)
	end
end

local function create_ghost_tab(dOS, pin_data)
	local tm = M.taskbar_manager
	if not tm.tabs_holder then return nil end
	hydrate_pin(pin_data, tm.__Special)

	local tw = TAB_ICON_W
	local show_t = false

	local function ghost_click()
		hydrate_pin(pin_data, tm.__Special)
		if pin_data.launch_func then
			task.spawn(pin_data.launch_func)
			return
		end
		if tm.__Special and tm.__Special.start_menu_data and pin_data.icon_id and pin_data.icon_id > 0 then
			for _, app in ipairs(tm.__Special.start_menu_data.all_apps) do
				if app.icon_id == pin_data.icon_id and app.launch_func then
					pin_data.launch_func = app.launch_func
					pin_data.app_name = pin_data.app_name or app.name
					task.spawn(app.launch_func)
					return
				end
			end
		end
		open_app_by_title(dOS, pin_data.app_name or pin_data.title)
	end

	local td = build_tab_frame(
		dOS,
		pin_data.icon_id,
		pin_data.title,
		tw,
		show_t,
		ghost_click,
		make_ghost_rclick(dOS, pin_data.title),
		nil,
		nil,
		true,
		{ pin_data = pin_data }
	)

	if not td then return nil end
	td.pinned_title = pin_data.title
	pin_data.ghost_tab = td

	return td
end

--- DRAG

setup_pin_drag = function(dOS, td, pin_data, screen_hw_override, tabs_holder_override, taskbar_frame_override)
	local tm = M.taskbar_manager

	if td._pin_drag_down_conn then
		pcall(function() td._pin_drag_down_conn:Disconnect() end)
		td._pin_drag_down_conn = nil
	end
	if td._pin_drag_up_conn then
		pcall(function() td._pin_drag_up_conn:Disconnect() end)
		td._pin_drag_up_conn = nil
	end
	if td._drag_cursor_conn then
		pcall(function() td._drag_cursor_conn:Disconnect() end)
		td._drag_cursor_conn = nil
	end

	local drag_guard = false
	local mouse_down_pos = nil
	local mouse_down_time = nil
	local mouse_is_down = false
	local dragging_user_id = nil
	local screen_hw = screen_hw_override or dOS.screen

	td.tab_frame.MouseButton1Down:Connect(function(x, y)
		if drag_guard or tm.tab_drag.active then return end
		mouse_down_pos = Vector2.new(x, y)
		mouse_down_time = os.clock()
		mouse_is_down = true
		dragging_user_id = dOS.LocalPlayer and dOS.LocalPlayer.UserId or nil
	end)

	td.tab_frame.MouseButton1Up:Connect(function()
		mouse_is_down = false
		mouse_down_pos = nil
		dragging_user_id = nil
		if tm.tab_drag.active and tm.tab_drag.is_pin then M._stop_drag(dOS) end
	end)

	td._drag_cursor_conn = screen_hw.CursorMoved:Connect(function(cursor)
		if dragging_user_id and cursor.UserId ~= dragging_user_id then return end
		if not mouse_down_pos or not mouse_is_down or drag_guard or tm.tab_drag.active then return end

		local elapsed = os.clock() - mouse_down_time
		if elapsed > DRAG_HOLD_S then
			mouse_down_pos = nil
			mouse_is_down = false
			dragging_user_id = nil
			return
		end

		local dx = math.abs(cursor.X - mouse_down_pos.X)
		local dy = math.abs(cursor.Y - mouse_down_pos.Y)

		if dx >= DRAG_PX or dy >= DRAG_PX then
			drag_guard = true
			mouse_down_pos = nil
			mouse_is_down = false

			local ghosts = get_sorted_ghosts(tm)
			if #ghosts < 2 then
				drag_guard = false
				dragging_user_id = nil
				return
			end
			local pin_idx = 1
			for i, pd in ipairs(ghosts) do
				if pd.title == pin_data.title then
					pin_idx = i
					break
				end
			end
			local grab_x_ratio, grab_y_ratio = capture_grab_ratio(td.tab_frame, cursor)

			tm.tab_drag = {
				active = true,
				is_pin = true,
				pin_title = pin_data.title,
				pin_cur_idx = pin_idx,
				tab_frame = td.tab_frame,
				latest_x = cursor.X,
				latest_y = cursor.Y,
				grab_x_ratio = grab_x_ratio,
				grab_y_ratio = grab_y_ratio,
				tab_tweens = {},
				reorder_debounce = 0,
				user_id = dragging_user_id,
				tabs_holder_ref = tabs_holder_override or nil,
				taskbar_frame_ref = taskbar_frame_override or nil,
			}

			if td.tab_frame and td.tab_frame.Parent then
				local hold_ref = tabs_holder_override or tm.tabs_holder
				td.tab_frame.ZIndex = (hold_ref and hold_ref.ZIndex or 1) + 100
				dOS.Tween.new(td.tab_frame, { BackgroundTransparency = 0.55 }, dOS.TweenInfo.new(0.08)):Play()
			end

			local function _drag_move_cb(cx, cy)
				if not tm.tab_drag.active then return end
				tm.tab_drag.latest_x = cx
				tm.tab_drag.latest_y = cy
				local tb = taskbar_frame_override or tm.frame
				if tb and tb.Parent then
					local tb_ap = tb.AbsolutePosition
					local tb_sz = tb.AbsoluteSize
					local dist_x =
						math.max(0, math.max(tb_ap.X - DRAG_MARGIN - cx, cx - (tb_ap.X + tb_sz.X + DRAG_MARGIN)))
					local dist_y =
						math.max(0, math.max(tb_ap.Y - DRAG_MARGIN - cy, cy - (tb_ap.Y + tb_sz.Y + DRAG_MARGIN)))
					if dist_x > 0 or dist_y > 0 then M._stop_drag(dOS) end
				end
			end

			if dOS.DragManager and dOS.DragManager.start_taskbar_drag and not screen_hw_override then
				local success = pcall(function()
					dOS.DragManager.start_taskbar_drag(dOS, _drag_move_cb, function()
						if tm.tab_drag.active then M._stop_drag(dOS) end
					end)
				end)
				if not success then
					local fallback_conn = screen_hw.CursorMoved:Connect(function(cur)
						if tm.tab_drag.user_id and cur.UserId ~= tm.tab_drag.user_id then return end
						_drag_move_cb(cur.X, cur.Y)
					end)
					tm.tab_drag._fallback_conn = fallback_conn
				end
			else
				local fallback_conn = screen_hw.CursorMoved:Connect(function(cur)
					if tm.tab_drag.user_id and cur.UserId ~= tm.tab_drag.user_id then return end
					_drag_move_cb(cur.X, cur.Y)
				end)
				tm.tab_drag._fallback_conn = fallback_conn
			end

			M._drag_loop(dOS)
			task.spawn(function()
				while tm.tab_drag.active do
					task.wait()
				end
				drag_guard = false
				dragging_user_id = nil
			end)
		end
	end)
end

setup_tab_drag = function(dOS, td, win_frame, screen_hw_override, tabs_holder_override, taskbar_frame_override)
	local tm = M.taskbar_manager
	local drag_guard = false
	local mouse_down_pos = nil
	local mouse_down_time = nil
	local mouse_is_down = false
	local dragging_user_id = nil
	local screen_hw = screen_hw_override or dOS.screen

	td.tab_frame.MouseButton1Down:Connect(function(x, y)
		if drag_guard or tm.tab_drag.active then return end
		mouse_down_pos = Vector2.new(x, y)
		mouse_down_time = os.clock()
		mouse_is_down = true
		dragging_user_id = dOS.LocalPlayer and dOS.LocalPlayer.UserId or nil
	end)

	td.tab_frame.MouseButton1Up:Connect(function()
		mouse_is_down = false
		mouse_down_pos = nil
		dragging_user_id = nil
		if tm.tab_drag.active then M._stop_drag(dOS) end
	end)

	td._drag_cursor_conn = screen_hw.CursorMoved:Connect(function(cursor)
		if dragging_user_id and cursor.UserId ~= dragging_user_id then return end

		if not mouse_down_pos or not mouse_is_down or drag_guard or tm.tab_drag.active then return end

		local elapsed = os.clock() - mouse_down_time
		if elapsed > DRAG_HOLD_S then
			mouse_down_pos = nil
			mouse_is_down = false
			dragging_user_id = nil
			return
		end

		local dx = math.abs(cursor.X - mouse_down_pos.X)
		local dy = math.abs(cursor.Y - mouse_down_pos.Y)

		if dx >= DRAG_PX or dy >= DRAG_PX then
			drag_guard = true
			mouse_down_pos = nil
			mouse_is_down = false

			local idx = nil
			for i, wf in ipairs(tm.tab_order) do
				if wf == win_frame then
					idx = i
					break
				end
			end
			if not idx then
				drag_guard = false
				dragging_user_id = nil
				return
			end
			local grab_x_ratio, grab_y_ratio = capture_grab_ratio(td.tab_frame, cursor)

			tm.tab_drag = {
				active = true,
				win_frame = win_frame,
				tab_frame = td.tab_frame,
				orig_idx = idx,
				cur_idx = idx,
				latest_x = cursor.X,
				latest_y = cursor.Y,
				grab_x_ratio = grab_x_ratio,
				grab_y_ratio = grab_y_ratio,
				tab_tweens = {},
				reorder_debounce = 0,
				user_id = dragging_user_id,
				tabs_holder_ref = tabs_holder_override or nil,
				taskbar_frame_ref = taskbar_frame_override or nil,
			}

			if td.tab_frame and td.tab_frame.Parent then
				local hold_ref = tabs_holder_override or tm.tabs_holder
				td.tab_frame.ZIndex = (hold_ref and hold_ref.ZIndex or 1) + 100
				dOS.Tween.new(td.tab_frame, { BackgroundTransparency = 0.1 }, dOS.TweenInfo.new(0.08)):Play()
			end

			local function _drag_move_cb(cx, cy)
				if not tm.tab_drag.active then return end
				tm.tab_drag.latest_x = cx
				tm.tab_drag.latest_y = cy
				local tb = taskbar_frame_override or tm.frame
				if tb and tb.Parent then
					local tb_ap = tb.AbsolutePosition
					local tb_sz = tb.AbsoluteSize
					local dist_x =
						math.max(0, math.max(tb_ap.X - DRAG_MARGIN - cx, cx - (tb_ap.X + tb_sz.X + DRAG_MARGIN)))
					local dist_y =
						math.max(0, math.max(tb_ap.Y - DRAG_MARGIN - cy, cy - (tb_ap.Y + tb_sz.Y + DRAG_MARGIN)))
					if dist_x > 0 or dist_y > 0 then M._stop_drag(dOS) end
				end
			end

			if dOS.DragManager and dOS.DragManager.start_taskbar_drag then
				local success = pcall(function()
					dOS.DragManager.start_taskbar_drag(dOS, _drag_move_cb, function()
						if tm.tab_drag.active then M._stop_drag(dOS) end
					end)
				end)

				if not success then
					warn("[Taskbar Manager]: DragManager.start_taskbar_drag failed, using fallback.")
					local fallback_conn = dOS.screen.CursorMoved:Connect(function(cur)
						if tm.tab_drag.user_id and cur.UserId ~= tm.tab_drag.user_id then return end
						_drag_move_cb(cur.X, cur.Y)
					end)
					tm.tab_drag._fallback_conn = fallback_conn
				end
			else
				local fallback_conn = dOS.screen.CursorMoved:Connect(function(cur)
					if tm.tab_drag.user_id and cur.UserId ~= tm.tab_drag.user_id then return end
					_drag_move_cb(cur.X, cur.Y)
				end)
				tm.tab_drag._fallback_conn = fallback_conn
			end

			M._drag_loop(dOS)
			task.spawn(function()
				while tm.tab_drag.active do
					task.wait()
				end
				drag_guard = false
				dragging_user_id = nil
			end)
		end
	end)
end

--- TABS

local function create_tab(dOS, win_frame: Instance)
	local tm = M.taskbar_manager
	if not tm.tabs_holder then return nil end
	if tm.window_tabs[win_frame] then return tm.window_tabs[win_frame] end

	local meta = dOS.window_metadata[win_frame]
	if not meta then return nil end

	local cfg = get_cfg(dOS)
	local tw = tab_width_individual(cfg, dOS)
	local show_t = cfg.large_tabs and tw > TAB_ICON_W + 10
	local icon_id = resolve_icon_id(dOS, meta)

	local function on_click()
		local m2 = dOS.window_metadata[win_frame]
		if not m2 then return end
		if m2.is_minimized then
			dOS.Window.handle_unminimize_window(dOS, win_frame)
		elseif dOS.active_window_frame == win_frame then
			if m2.is_minimizable then dOS.Window.handle_minimize_window(dOS, win_frame) end
		else
			dOS.Window.set_active_window(dOS, win_frame)
			if m2.is_minimized then dOS.Window.handle_unminimize_window(dOS, win_frame) end
		end
	end

	local pin_data = tm.pinned_apps[meta.title]
	if pin_data and pin_data.ghost_tab then
		local gt = pin_data.ghost_tab
		if not (gt.tab_frame and gt.tab_frame.Parent) or not gt.is_ghost then
			pin_data.ghost_tab = nil
		end
	end

	if pin_data and pin_data.ghost_tab then
		local td = pin_data.ghost_tab

		-- convert ghost to live
		td.win_frame = win_frame
		td.is_ghost = false

		meta.taskbar_pinned = true

		if td._cbs then
			td._cbs.click = on_click
			td._cbs.rclick = function() open_context_menu(dOS, win_frame, td.tab_frame, false, nil) end
		end

		if td.tab_frame and td.tab_frame.Parent then
			local info = dOS.TweenInfo.new(ANIM_MED, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			dOS.Tween.new(td.tab_frame, { BackgroundTransparency = 0.55 }, info):Play()
			if td.icon_elem then
				if td.icon_elem:IsA("ImageLabel") then
					dOS.Tween.new(td.icon_elem, { ImageTransparency = 0 }, info):Play()
				else
					dOS.Tween.new(td.icon_elem, { TextTransparency = 0, BackgroundTransparency = 0.25 }, info):Play()
				end
			end

			if not td.title_label then
				local mz = tm.tabs_holder and (tm.tabs_holder.ZIndex or 1) or 1
				td.title_label = dOS.create_gui_element(dOS, "TextLabel", {
					Parent = td.tab_frame,
					Text = meta.title,
					Visible = true,
					Size = UDim2.new(1, -(TAB_H + 4 + BADGE_SIZE + BADGE_MARGIN * 2), 1, -(IND_H + 6)),
					Position = UDim2.fromOffset(TAB_H + 2, 0),
					BackgroundTransparency = 1,
					TextColor3 = dOS.THEME.TEXT_LIGHT,
					TextTransparency = 1,
					Font = dOS.FONT_REGULAR,
					TextSize = dOS.os_settings.global_font_size,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextWrapped = false,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = (td.tab_frame.ZIndex or mz + 1) + 1,
				})
			end

			if td.title_label then
				td.title_label.Visible = true
				dOS.Tween.new(td.title_label, { TextTransparency = 0 }, info):Play()
			end
			if td.badge_icon then dOS.Tween.new(td.badge_icon, { ImageTransparency = 0 }, info):Play() end
		end

		tm.window_tabs[win_frame] = td

		local already_in_order = false
		for _, wf in ipairs(tm.tab_order) do
			if wf == win_frame then
				already_in_order = true
				break
			end
		end

		if not already_in_order then
			local insert_pos = pin_data.position_index or (#tm.tab_order + 1)
			insert_pos = math.clamp(insert_pos, 1, #tm.tab_order + 1)
			table.insert(tm.tab_order, insert_pos, win_frame)
		end

		if td._pin_drag_down_conn then
			pcall(function() td._pin_drag_down_conn:Disconnect() end)
			td._pin_drag_down_conn = nil
		end
		if td._pin_drag_up_conn then
			pcall(function() td._pin_drag_up_conn:Disconnect() end)
			td._pin_drag_up_conn = nil
		end
		if td._drag_cursor_conn then
			pcall(function() td._drag_cursor_conn:Disconnect() end)
			td._drag_cursor_conn = nil
		end

		setup_tab_drag(dOS, td, win_frame)
		local updated_tw = tab_width_individual(cfg, dOS)
		animate_indicator(dOS, td, ind_state_for_win(dOS, win_frame), updated_tw)
		return td
	end

	local td
	td = build_tab_frame(
		dOS,
		icon_id,
		meta.title,
		tw,
		show_t,
		on_click,
		function() open_context_menu(dOS, win_frame, td and td.tab_frame, false, nil) end,
		nil,
		nil,
		false,
		{ win_frame = win_frame }
	)
	if not td then return nil end

	tm.window_tabs[win_frame] = td
	tm.tab_order[#tm.tab_order + 1] = win_frame
	return td
end

--- GROUP

local function setup_group_tab_drag(dOS, gtd, screen_hw_override, tabs_holder_override, taskbar_frame_override)
	local tm = M.taskbar_manager
	local drag_guard = false
	local mouse_down_pos = nil
	local mouse_down_time = nil
	local mouse_is_down = false
	local dragging_user_id = nil
	local screen_hw = screen_hw_override or dOS.screen

	gtd.tab_frame.MouseButton1Down:Connect(function(x, y)
		if drag_guard or tm.tab_drag.active then return end
		mouse_down_pos = Vector2.new(x, y)
		mouse_down_time = os.clock()
		mouse_is_down = true
		dragging_user_id = dOS.LocalPlayer and dOS.LocalPlayer.UserId or nil
	end)

	gtd.tab_frame.MouseButton1Up:Connect(function()
		mouse_is_down = false
		mouse_down_pos = nil
		dragging_user_id = nil
		if tm.tab_drag.active then M._stop_drag(dOS) end
	end)

	gtd._drag_cursor_conn = screen_hw.CursorMoved:Connect(function(cursor)
		if dragging_user_id and cursor.UserId ~= dragging_user_id then return end
		if not mouse_down_pos or not mouse_is_down or drag_guard or tm.tab_drag.active then return end

		local elapsed = os.clock() - mouse_down_time
		if elapsed > DRAG_HOLD_S then
			mouse_down_pos = nil
			mouse_is_down = false
			dragging_user_id = nil
			return
		end

		local dx = math.abs(cursor.X - mouse_down_pos.X)
		local dy = math.abs(cursor.Y - mouse_down_pos.Y)

		if dx >= DRAG_PX or dy >= DRAG_PX then
			drag_guard = true
			mouse_down_pos = nil
			mouse_is_down = false

			local group_windows = {}
			for _, wf in ipairs(gtd.win_frames) do
				table.insert(group_windows, wf)
			end

			if #group_windows == 0 then
				drag_guard = false
				dragging_user_id = nil
				return
			end

			local first_idx = nil
			for i, wf in ipairs(tm.tab_order) do
				for _, gwf in ipairs(group_windows) do
					if wf == gwf then
						first_idx = i
						break
					end
				end
				if first_idx then break end
			end

			if not first_idx then
				drag_guard = false
				dragging_user_id = nil
				return
			end
			local grab_x_ratio, grab_y_ratio = capture_grab_ratio(gtd.tab_frame, cursor)

			tm.tab_drag = {
				active = true,
				win_frame = nil,
				tab_frame = gtd.tab_frame,
				orig_idx = first_idx,
				cur_idx = first_idx,
				latest_x = cursor.X,
				latest_y = cursor.Y,
				grab_x_ratio = grab_x_ratio,
				grab_y_ratio = grab_y_ratio,
				tab_tweens = {},
				reorder_debounce = 0,
				user_id = dragging_user_id,
				is_group = true,
				group_key = gtd.group_key,
				group_windows = group_windows,
				tabs_holder_ref = tabs_holder_override or nil,
				taskbar_frame_ref = taskbar_frame_override or nil,
			}

			if gtd.tab_frame and gtd.tab_frame.Parent then
				local hold_ref = tabs_holder_override or tm.tabs_holder
				gtd.tab_frame.ZIndex = (hold_ref and hold_ref.ZIndex or 1) + 100
				dOS.Tween.new(gtd.tab_frame, { BackgroundTransparency = 0.1 }, dOS.TweenInfo.new(0.08)):Play()
			end

			local function _drag_move_cb(cx, cy)
				if not tm.tab_drag.active then return end
				tm.tab_drag.latest_x = cx
				tm.tab_drag.latest_y = cy
				local tb = taskbar_frame_override or tm.frame
				if tb and tb.Parent then
					local tb_ap = tb.AbsolutePosition
					local tb_sz = tb.AbsoluteSize
					local dist_x =
						math.max(0, math.max(tb_ap.X - DRAG_MARGIN - cx, cx - (tb_ap.X + tb_sz.X + DRAG_MARGIN)))
					local dist_y =
						math.max(0, math.max(tb_ap.Y - DRAG_MARGIN - cy, cy - (tb_ap.Y + tb_sz.Y + DRAG_MARGIN)))
					if dist_x > 0 or dist_y > 0 then M._stop_drag(dOS) end
				end
			end

			if dOS.DragManager and dOS.DragManager.start_taskbar_drag and not screen_hw_override then
				local success = pcall(function()
					dOS.DragManager.start_taskbar_drag(dOS, _drag_move_cb, function()
						if tm.tab_drag.active then M._stop_drag(dOS) end
					end)
				end)

				if not success then
					local fallback_conn = screen_hw.CursorMoved:Connect(function(cur)
						if tm.tab_drag.user_id and cur.UserId ~= tm.tab_drag.user_id then return end
						_drag_move_cb(cur.X, cur.Y)
					end)
					tm.tab_drag._fallback_conn = fallback_conn
				end
			else
				local fallback_conn = screen_hw.CursorMoved:Connect(function(cur)
					if tm.tab_drag.user_id and cur.UserId ~= tm.tab_drag.user_id then return end
					_drag_move_cb(cur.X, cur.Y)
				end)
				tm.tab_drag._fallback_conn = fallback_conn
			end

			M._drag_loop(dOS)

			task.spawn(function()
				while tm.tab_drag.active do
					task.wait()
				end
				drag_guard = false
				dragging_user_id = nil
			end)
		end
	end)
end

local function ensure_group_tab(dOS, group, tw, show_title)
	local tm = M.taskbar_manager
	local key = group.key
	local gtd = tm.group_tabs[key]

	if not gtd or not gtd.tab_frame or not gtd.tab_frame.Parent then
		local icon_id = nil
		if group.wins[1] then
			local m = dOS.window_metadata[group.wins[1]]
			if m then icon_id = resolve_icon_id(dOS, m) end
		end

		local function on_click()
			local gtd_ref = tm.group_tabs[key]
			local wins = gtd_ref and gtd_ref.win_frames or {}
			if #wins == 0 then return end

			if gtd_ref and gtd_ref._use_click_for_preview and #wins > 1 then
				if tm.preview_popup and tm.preview_popup.Parent then
					M.taskbar_manager.preview_hover_active = false
					close_preview_popup(dOS)
				else
					show_group_preview(dOS, gtd_ref, gtd_ref.tab_frame)
				end
				return
			end

			if #wins == 1 then
				local wf = wins[1]
				local m2 = dOS.window_metadata[wf]
				if not m2 then return end
				if m2.is_minimized then
					dOS.Window.handle_unminimize_window(dOS, wf)
				elseif dOS.active_window_frame == wf then
					if m2.is_minimizable then dOS.Window.handle_minimize_window(dOS, wf) end
				else
					dOS.Window.set_active_window(dOS, wf)
				end
			else
				local focused = dOS.active_window_frame
				local next_wf = wins[1]
				local found = false
				for _, wf in ipairs(wins) do
					if found then
						next_wf = wf
						break
					end
					if wf == focused then found = true end
				end
				local m2 = dOS.window_metadata[next_wf]
				if m2 and m2.is_minimized then
					dOS.Window.handle_unminimize_window(dOS, next_wf)
				elseif m2 then
					dOS.Window.set_active_window(dOS, next_wf)
				end
			end
		end

		local function on_hover_enter()
			local gtd_ref = tm.group_tabs[key]
			-- don't show preview on hover if in overflow mode
			if gtd_ref and gtd_ref._use_click_for_preview then return end
			if tm.context_menu and tm.context_menu.Parent then return end

			debounce("group_preview_" .. key, PREVIEW_HOVER_DELAY, function()
				if tm.context_menu and tm.context_menu.Parent then return end
				if tm.group_tabs[key] and tm.group_tabs[key].tab_frame and tm.group_tabs[key].tab_frame.Parent then
					show_group_preview(dOS, tm.group_tabs[key], tm.group_tabs[key].tab_frame)
				end
			end)
		end

		local function on_hover_leave()
			cancel_debounce("group_preview_" .. key)
			debounce("preview_close_" .. key, 0.2, function()
				if not M.taskbar_manager.preview_hover_active then close_preview_popup(dOS) end
			end)
		end

		local new_gtd = build_tab_frame(dOS, icon_id, key, tw, show_title, on_click, function()
			local wins2 = tm.group_tabs[key] and tm.group_tabs[key].win_frames or {}
			local target = dOS.active_window_frame
			local in_group = false
			for _, wf in ipairs(wins2) do
				if wf == target then
					in_group = true
					break
				end
			end
			if not in_group then target = wins2[1] end
			if target and tm.group_tabs[key] and tm.group_tabs[key].tab_frame then
				open_context_menu(dOS, target, tm.group_tabs[key].tab_frame, true, wins2)
			end
		end, on_hover_enter, on_hover_leave, false)

		if not new_gtd then return nil end

		new_gtd.group_key = key
		new_gtd.win_frames = {}
		new_gtd._last_title = key
		tm.group_tabs[key] = new_gtd
		gtd = new_gtd

		setup_group_tab_drag(dOS, new_gtd, nil, nil, nil)
	end

	gtd.win_frames = {}
	for _, wf in ipairs(group.wins) do
		table.insert(gtd.win_frames, wf)
	end

	if gtd.title_label and gtd._last_title ~= key then
		gtd.title_label.Text = key
		gtd._last_title = key
	end

	return gtd
end

--- DRAG

function M._drag_loop(dOS)
	task.spawn(function()
		local tm = M.taskbar_manager

		while tm.tab_drag.active do
			task.wait()
			local drag = tm.tab_drag
			if not drag.active then break end

			if not drag.tab_frame or not drag.tab_frame.Parent then
				M._stop_drag(dOS)
				return
			end
			local hold = drag.tabs_holder_ref or tm.tabs_holder
			if not hold then
				M._stop_drag(dOS)
				return
			end

			local cfg = get_cfg(dOS)
			local pos = cfg.position
			local is_vertical = not is_horiz(pos)
			local mode = effective_mode(cfg, dOS)
			if drag.is_group then mode = "group" end

			local tw
			if mode == "group" then
				local groups, _ = compute_groups(dOS)
				tw = tab_width_group(cfg, #groups)
			else
				tw = tab_width_individual(cfg, dOS)
			end
			if drag.tabs_holder_ref then
				tw = TAB_ICON_W
			end

			local hp = hold.AbsolutePosition
			local cx = drag.latest_x
			local cy = drag.latest_y

			local g_off = ghost_section_width(tm, is_vertical)

			local canvas_cx = (cx - hp.X) + hold.CanvasPosition.X
			local canvas_cy = (cy - hp.Y) + hold.CanvasPosition.Y
			local canvas_w = hold.CanvasSize.X.Offset
			local canvas_h = hold.CanvasSize.Y.Offset

			local pin_tw = drag.is_pin and TAB_ICON_W or tw

			local grab_x_ratio = drag.grab_x_ratio or 0.5
			local grab_y_ratio = drag.grab_y_ratio or 0.5
			local new_x, new_y
			if drag.is_pin then
				if is_vertical then
					new_y = math.clamp(canvas_cy - TAB_H * grab_y_ratio, TAB_PAD, math.max(TAB_PAD, g_off - TAB_H - TAB_PAD))
					new_x = math.floor((TB_THICKNESS - pin_tw) / 2)
				else
					new_x = math.clamp(canvas_cx - pin_tw * grab_x_ratio, TAB_PAD, math.max(TAB_PAD, g_off - pin_tw - TAB_PAD))
					new_y = tab_y()
				end
			elseif is_vertical then
				new_y = math.clamp(canvas_cy - TAB_H * grab_y_ratio, g_off, math.max(g_off, canvas_h - TAB_H))
				new_x = math.floor((TB_THICKNESS - tw) / 2)
			else
				new_x = math.clamp(canvas_cx - tw * grab_x_ratio, g_off, math.max(g_off, canvas_w - tw))
				new_y = tab_y()
			end
			drag.tab_frame.Position = UDim2.fromOffset(new_x, new_y)

			local function mirror_dragged_tab(tab_frame, holder_ref, item_w)
				if not (tab_frame and tab_frame.Parent and holder_ref and holder_ref.Parent) then return end
				if tab_frame == drag.tab_frame then return end

				local local_w = item_w or tab_frame.AbsoluteSize.X
				if not local_w or local_w <= 0 then local_w = TAB_ICON_W end
				local hp2 = holder_ref.AbsolutePosition
				local ccx2 = (cx - hp2.X) + holder_ref.CanvasPosition.X
				local ccy2 = (cy - hp2.Y) + holder_ref.CanvasPosition.Y
				local cw2 = holder_ref.CanvasSize.X.Offset
				local ch2 = holder_ref.CanvasSize.Y.Offset
				local gx2 = ghost_section_width(tm, is_vertical)

				local tx, ty
				if drag.is_pin then
					if is_vertical then
						ty = math.clamp(ccy2 - TAB_H * grab_y_ratio, TAB_PAD, math.max(TAB_PAD, gx2 - TAB_H - TAB_PAD))
						tx = math.floor((TB_THICKNESS - local_w) / 2)
					else
						tx = math.clamp(ccx2 - local_w * grab_x_ratio, TAB_PAD, math.max(TAB_PAD, gx2 - local_w - TAB_PAD))
						ty = tab_y()
					end
				elseif is_vertical then
					ty = math.clamp(ccy2 - TAB_H * grab_y_ratio, gx2, math.max(gx2, ch2 - TAB_H))
					tx = math.floor((TB_THICKNESS - local_w) / 2)
				else
					tx = math.clamp(ccx2 - local_w * grab_x_ratio, gx2, math.max(gx2, cw2 - local_w))
					ty = tab_y()
				end

				tab_frame.ZIndex = (holder_ref.ZIndex or 1) + 100
				tab_frame.Position = UDim2.fromOffset(tx, ty)
			end

			if drag.is_pin then
				local pd = tm.pinned_apps[drag.pin_title]
				if pd and pd.ghost_tab then mirror_dragged_tab(pd.ghost_tab.tab_frame, tm.tabs_holder, TAB_ICON_W) end
				for _, mirror in pairs(tm.mirrors) do
					local td_m = mirror.tab_data and mirror.tab_data["ghost_" .. tostring(drag.pin_title or "")]
					if td_m then mirror_dragged_tab(td_m.tab_frame, mirror.tabs_holder, TAB_ICON_W) end
				end
			elseif drag.is_group then
				local gtd_src = tm.group_tabs[drag.group_key]
				if gtd_src then mirror_dragged_tab(gtd_src.tab_frame, tm.tabs_holder, tw) end
				for _, mirror in pairs(tm.mirrors) do
					local td_m = mirror.tab_data and mirror.tab_data["group_" .. tostring(drag.group_key or "")]
					if td_m then mirror_dragged_tab(td_m.tab_frame, mirror.tabs_holder, TAB_ICON_W) end
				end
			elseif drag.win_frame then
				local td_src = tm.window_tabs[drag.win_frame]
				if td_src then mirror_dragged_tab(td_src.tab_frame, tm.tabs_holder, td_src.tab_frame and td_src.tab_frame.AbsoluteSize.X or tw) end
				for _, mirror in pairs(tm.mirrors) do
					local td_m = mirror.tab_data and mirror.tab_data[drag.win_frame]
					if td_m then mirror_dragged_tab(td_m.tab_frame, mirror.tabs_holder, TAB_ICON_W) end
				end
			end

			local now = os.clock()
			local cooldown_ok = (now - (drag.reorder_debounce or 0)) >= REORDER_COOLDOWN

			if drag.is_pin then
				local ghosts = get_sorted_ghosts(tm)
				local pin_count = #ghosts
				local new_pin_idx = cursor_to_slot(canvas_cx, canvas_cy, TAB_PAD, pin_tw, TAB_H, pin_count, is_vertical)

				if new_pin_idx ~= drag.pin_cur_idx and cooldown_ok then
					drag.reorder_debounce = now
					drag.pin_cur_idx = new_pin_idx

					local pin_title = drag.pin_title
					local ordered = {}
					local dragged_pd = nil
					for _, pd in ipairs(ghosts) do
						if pd.title == pin_title then
							dragged_pd = pd
						else
							table.insert(ordered, pd)
						end
					end
					if dragged_pd then
						local ins = math.clamp(new_pin_idx, 1, #ordered + 1)
						table.insert(ordered, ins, dragged_pd)
					end

					for i, pd in ipairs(ordered) do
						pd.position_index = i
					end
				end
			elseif mode == "group" and drag.is_group then
				local groups, _ = compute_groups(dOS)
				local group_count = #groups
				local new_group_idx = cursor_to_slot(canvas_cx, canvas_cy, g_off, tw, TAB_H, group_count, is_vertical)

				if new_group_idx ~= drag.cur_idx and cooldown_ok then
					drag.reorder_debounce = now
					drag.cur_idx = new_group_idx

					local group_order = {}
					local seen_keys = {}
					for _, wf in ipairs(tm.tab_order) do
						local meta = dOS.window_metadata[wf]
						if meta and not seen_keys[meta.title] then
							seen_keys[meta.title] = true
							table.insert(group_order, meta.title)
						end
					end

					local dragged_key = drag.group_key
					for i, key in ipairs(group_order) do
						if key == dragged_key then
							table.remove(group_order, i)
							break
						end
					end
					local insert_pos = math.clamp(new_group_idx, 1, #group_order + 1)
					table.insert(group_order, insert_pos, dragged_key)

					local new_tab_order = {}
					for _, key in ipairs(group_order) do
						for _, wf in ipairs(tm.tab_order) do
							local meta = dOS.window_metadata[wf]
							if meta and meta.title == key then
								local already_added = false
								for _, added_wf in ipairs(new_tab_order) do
									if added_wf == wf then
										already_added = true
										break
									end
								end
								if not already_added then table.insert(new_tab_order, wf) end
							end
						end
					end
					tm.tab_order = new_tab_order
				end
			else
				local count = #tm.tab_order
				local new_idx = cursor_to_slot(canvas_cx, canvas_cy, g_off, tw, TAB_H, count, is_vertical)

				if new_idx ~= drag.cur_idx and cooldown_ok then
					drag.reorder_debounce = now
					local old_idx = drag.cur_idx
					drag.cur_idx = new_idx

					table.remove(tm.tab_order, old_idx)
					table.insert(tm.tab_order, new_idx, drag.win_frame)
				end
			end

			if (now - (drag._last_mirror_refresh or 0)) >= 0.04 then
				drag._last_mirror_refresh = now
				if drag.tabs_holder_ref then
					M.update_layout(dOS)
				else
					M.refresh_mirror_taskbars(dOS)
				end
			end

			if drag.tabs_holder_ref then continue end

			local SPRING_K = 0.16 -- higher = snappier
			local base_perp = is_vertical and math.floor((TB_THICKNESS - tw) / 2) or tab_y()

			if drag.is_pin then
				-- pin mode
				local ghosts = get_sorted_ghosts(tm)
				local pin_title = drag.pin_title
				local pax = TAB_PAD
				for _, pd in ipairs(ghosts) do
					pax += is_vertical and (TAB_H + TAB_PAD) or (pin_tw + TAB_PAD)
					if pd.title == pin_title then continue end
					local gtf = pd.ghost_tab and pd.ghost_tab.tab_frame
					if not (gtf and gtf.Parent) then continue end

					local slot = pax - (is_vertical and (TAB_H + TAB_PAD) or (pin_tw + TAB_PAD))

					local gt = pd.ghost_tab
					gt._drag_cs = gt._drag_cs or (is_vertical and gtf.Position.Y.Offset or gtf.Position.X.Offset)
					gt._drag_cs = gt._drag_cs + (slot - gt._drag_cs) * SPRING_K

					local ap = gtf.AbsolutePosition
					local as_ = gtf.AbsoluteSize
					local ctr = is_vertical and (ap.Y + as_.Y * 0.5) or (ap.X + as_.X * 0.5)
					local dist = math.abs((is_vertical and cy or cx) - ctr)
					local lift_t = DRAG_LIFT_MAX * math.exp(-dist / DRAG_LIFT_RADIUS)
					gt._drag_lift = (gt._drag_lift or 0) + (lift_t - (gt._drag_lift or 0)) * DRAG_LIFT_LERP

					if is_vertical then
						gtf.Position = UDim2.fromOffset(base_perp - gt._drag_lift, math.floor(gt._drag_cs))
					else
						gtf.Position = UDim2.fromOffset(math.floor(gt._drag_cs), base_perp - gt._drag_lift)
					end
				end
			elseif mode == "group" and drag.is_group then
				-- group mode
				local groups2, _ = compute_groups(dOS)
				local gax = g_off
				for _, g in ipairs(groups2) do
					local target_slot = gax
					gax += is_vertical and (TAB_H + TAB_PAD) or (tw + TAB_PAD)
					if g.key == drag.group_key then continue end
					local gtd2 = tm.group_tabs[g.key]
					if not (gtd2 and gtd2.tab_frame and gtd2.tab_frame.Parent) then continue end
					local gtf2 = gtd2.tab_frame

					gtd2._drag_cs = gtd2._drag_cs or (is_vertical and gtf2.Position.Y.Offset or gtf2.Position.X.Offset)
					gtd2._drag_cs = gtd2._drag_cs + (target_slot - gtd2._drag_cs) * SPRING_K

					local ap2 = gtf2.AbsolutePosition
					local as2 = gtf2.AbsoluteSize
					local ctr2 = is_vertical and (ap2.Y + as2.Y * 0.5) or (ap2.X + as2.X * 0.5)
					local d2 = math.abs((is_vertical and cy or cx) - ctr2)
					local l2t = DRAG_LIFT_MAX * math.exp(-d2 / DRAG_LIFT_RADIUS)
					gtd2._drag_lift = (gtd2._drag_lift or 0) + (l2t - (gtd2._drag_lift or 0)) * DRAG_LIFT_LERP

					if is_vertical then
						gtf2.Position = UDim2.fromOffset(base_perp - gtd2._drag_lift, math.floor(gtd2._drag_cs))
					else
						gtf2.Position = UDim2.fromOffset(math.floor(gtd2._drag_cs), base_perp - gtd2._drag_lift)
					end
				end
			else
				-- individual mode
				local iax = g_off
				for _, wf in ipairs(tm.tab_order) do
					local target_slot = iax
					iax += is_vertical and (TAB_H + TAB_PAD) or (tw + TAB_PAD)
					if wf == drag.win_frame then continue end
					local td2 = tm.window_tabs[wf]
					if not (td2 and td2.tab_frame and td2.tab_frame.Parent) then continue end
					local itf = td2.tab_frame

					if drag.tab_tweens[wf] then
						pcall(function() drag.tab_tweens[wf]:Cancel() end)
						drag.tab_tweens[wf] = nil
					end
					cancel_tab_tween(wf)

					td2._drag_cs = td2._drag_cs or (is_vertical and itf.Position.Y.Offset or itf.Position.X.Offset)
					td2._drag_cs = td2._drag_cs + (target_slot - td2._drag_cs) * SPRING_K

					local ap3 = itf.AbsolutePosition
					local as3 = itf.AbsoluteSize
					local ctr3 = is_vertical and (ap3.Y + as3.Y * 0.5) or (ap3.X + as3.X * 0.5)
					local d3 = math.abs((is_vertical and cy or cx) - ctr3)
					local l3t = DRAG_LIFT_MAX * math.exp(-d3 / DRAG_LIFT_RADIUS)
					td2._drag_lift = (td2._drag_lift or 0) + (l3t - (td2._drag_lift or 0)) * DRAG_LIFT_LERP

					if is_vertical then
						itf.Position = UDim2.fromOffset(base_perp - td2._drag_lift, math.floor(td2._drag_cs))
					else
						itf.Position = UDim2.fromOffset(math.floor(td2._drag_cs), base_perp - td2._drag_lift)
					end
				end
			end
		end
	end)
end

function M._stop_drag(dOS)
	local tm = M.taskbar_manager
	if not tm.tab_drag.active then return end

	local tf = tm.tab_drag.tab_frame
	local was_pin = tm.tab_drag.is_pin
	local tabs_holder_ref = tm.tab_drag.tabs_holder_ref

	tm.tab_drag.active = false
	tm.tab_drag.win_frame = nil
	tm.tab_drag.tab_frame = nil
	tm.tab_drag.user_id = nil
	tm.tab_drag.is_group = nil
	tm.tab_drag.group_key = nil
	tm.tab_drag.group_windows = nil
	tm.tab_drag.is_pin = nil
	tm.tab_drag.pin_title = nil
	tm.tab_drag.pin_cur_idx = nil
	tm.tab_drag.tabs_holder_ref = nil
	tm.tab_drag.taskbar_frame_ref = nil

	if tm.tab_drag._fallback_conn then
		pcall(function() tm.tab_drag._fallback_conn:Disconnect() end)
		tm.tab_drag._fallback_conn = nil
	end

	if dOS.DragManager and dOS.DragManager.stop_taskbar_drag then
		pcall(function() dOS.DragManager.stop_taskbar_drag(dOS) end)
	end

	for key, t in pairs(tm.tab_drag.tab_tweens) do
		pcall(function() t:Cancel() end)
		if type(key) ~= "string" then cancel_tab_tween(key) end
	end
	tm.tab_drag.tab_tweens = {}

	if tf and tf.Parent then
		local effective_holder = tabs_holder_ref or tm.tabs_holder
		local tabs_holder_z = effective_holder and effective_holder.ZIndex or 1
		tf.ZIndex = tabs_holder_z + 1
		dOS.Tween.new(tf, { BackgroundTransparency = 0.55 }, dOS.TweenInfo.new(0.1)):Play()
	end

	if was_pin then save_pinned_apps(dOS) end

	for _, mirror in pairs(tm.mirrors) do
		local holder_z = mirror.tabs_holder and (mirror.tabs_holder.ZIndex or 1) or 1
		for _, td_m in pairs(mirror.tab_data or {}) do
			if td_m.tab_frame and td_m.tab_frame.Parent then
				td_m.tab_frame.ZIndex = holder_z + 1
			end
		end
	end

	for _, _td in pairs(tm.window_tabs) do
		_td._drag_cs = nil
		_td._drag_lift = nil
	end
	for _, _gtd in pairs(tm.group_tabs) do
		_gtd._drag_cs = nil
		_gtd._drag_lift = nil
	end
	for _, _pd in pairs(tm.pinned_apps) do
		if _pd.ghost_tab then
			_pd.ghost_tab._drag_cs = nil
			_pd.ghost_tab._drag_lift = nil
		end
	end

	M.update_layout(dOS)
end

--- LAYOUT

function M.update_layout(dOS)
	local tm = M.taskbar_manager
	if not tm.tabs_holder then return end

	local _vdm = dOS and dOS.VDM
	if _vdm and _vdm._state and _vdm._state.win_di then
		local _active_di = _vdm._state.active_di
		for _, wf in ipairs(tm.tab_order) do
			local _di = _vdm._state.win_di[wf]
			if _di and _di ~= _active_di then
				local _td = tm.window_tabs[wf]
				if _td and _td.tab_frame and _td.tab_frame.Parent then _td.tab_frame.Visible = false end
			end
		end
	end

	local dragged_wf = tm.tab_drag.active and tm.tab_drag.win_frame or nil

	local cfg = get_cfg(dOS)
	local pos = cfg.position
	local is_vertical = not is_horiz(pos)
	local mode = effective_mode(cfg, dOS)
	local show_t_fn = function(tw) return cfg.large_tabs and tw > TAB_ICON_W + 10 end
	local tinfo = dOS.TweenInfo.new(ANIM_MED, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

	if mode == "individual" then
		for _, gtd in pairs(tm.group_tabs) do
			if gtd.tab_frame and gtd.tab_frame.Parent then gtd.tab_frame.Visible = false end
		end

		local tw = tab_width_individual(cfg, dOS)
		local show = show_t_fn(tw)

		-- width/title rules for ghosts:
		-- - shrink to icon-only whenever windows exist
		-- - fill the bar when no windows are open
		-- - never show a title when windows exist
		local ghost_tw = TAB_ICON_W
		local ghost_show = false

		local ghosts = get_sorted_ghosts(tm)
		local ax = TAB_PAD
		for _, pd in ipairs(ghosts) do
			local td = pd.ghost_tab
			td.tab_frame.Visible = true


			if td._pin_animating or (tm.tab_drag.active and tm.tab_drag.is_pin and tm.tab_drag.pin_title == pd.title) then
				ax += (is_vertical and (TAB_H + TAB_PAD) or (ghost_tw + TAB_PAD))
				continue
			end

			cancel_tab_tween(pd)

			local target_pos, target_size
			if is_vertical then
				local px = math.floor((TB_THICKNESS - ghost_tw) / 2)
				target_pos = UDim2.fromOffset(px, ax)
				target_size = UDim2.fromOffset(ghost_tw, TAB_H)
			else
				target_pos = UDim2.fromOffset(ax, tab_y())
				target_size = UDim2.fromOffset(ghost_tw, TAB_H)
			end

			local t
			if not td._positioned then
				td._positioned = true
				td.tab_frame.Position = target_pos
				t = dOS.Tween.new(td.tab_frame, { Size = target_size }, tinfo)
			else
				t = dOS.Tween.new(td.tab_frame, { Size = target_size, Position = target_pos }, tinfo)
			end
			set_tab_tween(pd, t)
			t:Play()
			refresh_tab_style(dOS, td, ghost_tw, ghost_show)
			ax += (is_vertical and (TAB_H + TAB_PAD) or (ghost_tw + TAB_PAD))
		end

		for _, wf in ipairs(active_tab_order(dOS)) do
			local td = tm.window_tabs[wf]
			if td and td.tab_frame and td.tab_frame.Parent then
				td.tab_frame.Visible = true

				if wf ~= dragged_wf then
					cancel_tab_tween(wf)

					local target_pos, target_size
					if is_vertical then
						local px = math.floor((TB_THICKNESS - tw) / 2)
						target_pos = UDim2.fromOffset(px, ax)
						target_size = UDim2.fromOffset(tw, TAB_H)
					else
						target_pos = UDim2.fromOffset(ax, tab_y())
						target_size = UDim2.fromOffset(tw, TAB_H)
					end

					local t
					if not td._positioned then
						td._positioned = true
						td.tab_frame.Position = target_pos
						t = dOS.Tween.new(td.tab_frame, { Size = target_size }, tinfo)
					else
						t = dOS.Tween.new(td.tab_frame, { Size = target_size, Position = target_pos }, tinfo)
					end
					set_tab_tween(wf, t)
					t:Play()
				end

				refresh_tab_style(dOS, td, tw, show)
				ax += (is_vertical and (TAB_H + TAB_PAD) or (tw + TAB_PAD))
			end
		end

		if is_vertical then
			tm.tabs_holder.CanvasSize = UDim2.fromOffset(0, ax)
		else
			tm.tabs_holder.CanvasSize = UDim2.fromOffset(ax, 0)
		end
	else
		-- group mode
		for _, td in pairs(tm.window_tabs) do
			if td.tab_frame and td.tab_frame.Parent then td.tab_frame.Visible = false end
		end

		local ghost_tw_grp = TAB_ICON_W
		local ghosts_grp = get_sorted_ghosts(tm)
		local ghost_px = TAB_PAD
		for _, pd in ipairs(ghosts_grp) do
			local td = pd.ghost_tab
			td.tab_frame.Visible = true

			if td._pin_animating or (tm.tab_drag.active and tm.tab_drag.is_pin and tm.tab_drag.pin_title == pd.title) then
				ghost_px += (is_vertical and (TAB_H + TAB_PAD) or (ghost_tw_grp + TAB_PAD))
				continue
			end

			cancel_tab_tween(pd)
			local target_pos, target_size
			if is_vertical then
				local px = math.floor((TB_THICKNESS - ghost_tw_grp) / 2)
				target_pos = UDim2.fromOffset(px, ghost_px)
				target_size = UDim2.fromOffset(ghost_tw_grp, TAB_H)
			else
				target_pos = UDim2.fromOffset(ghost_px, tab_y())
				target_size = UDim2.fromOffset(ghost_tw_grp, TAB_H)
			end
			local t
			if not td._positioned then
				td._positioned = true
				td.tab_frame.Position = target_pos
				t = dOS.Tween.new(td.tab_frame, { Size = target_size }, tinfo)
			else
				t = dOS.Tween.new(td.tab_frame, { Size = target_size, Position = target_pos }, tinfo)
			end
			set_tab_tween(pd, t)
			t:Play()
			refresh_tab_style(dOS, td, ghost_tw_grp, false)
			ghost_px += (is_vertical and (TAB_H + TAB_PAD) or (ghost_tw_grp + TAB_PAD))
		end

		local groups: {
			{
				key: string,
				wins: { Instance },
			}
		}, _ = compute_groups(dOS)

		local reserved_for_ghosts = #ghosts_grp > 0 and ghost_px or 0
		local tw = tab_width_group(cfg, #groups, reserved_for_ghosts)
		local show = show_t_fn(tw)

		local active_keys = {}
		for _, g in ipairs(groups) do
			active_keys[g.key] = true
		end

		for key, gtd in pairs(tm.group_tabs) do
			if not active_keys[key] then
				if gtd.tab_frame and gtd.tab_frame.Parent then
					local out = dOS.TweenInfo.new(ANIM_MED, Enum.EasingStyle.Back, Enum.EasingDirection.In)
					dOS.Tween
						.new(gtd.tab_frame, { Size = UDim2.fromOffset(0, TAB_H), BackgroundTransparency = 1 }, out)
						:Play()
					local gf = gtd.tab_frame
					task.delay(ANIM_MED + 0.05, function()
						if gf and gf.Parent then gf:Destroy() end
					end)
				end
				tm.group_tabs[key] = nil
			end
		end

		local ax = ghost_px
		for _, g in ipairs(groups) do
			local gtd = ensure_group_tab(dOS, g, tw, show)

			if gtd and gtd.tab_frame and gtd.tab_frame.Parent then
				gtd.tab_frame.Visible = true
				local dragging_this_group = tm.tab_drag.active and tm.tab_drag.is_group and tm.tab_drag.group_key == g.key
				if dragging_this_group then
					ax += (is_vertical and (TAB_H + TAB_PAD) or (tw + TAB_PAD))
					continue
				end
				cancel_tab_tween(gtd)

				local target_pos, target_size
				if is_vertical then
					local px = math.floor((TB_THICKNESS - tw) / 2)
					target_pos = UDim2.fromOffset(px, ax)
					target_size = UDim2.fromOffset(tw, TAB_H)
				else
					target_pos = UDim2.fromOffset(ax, tab_y())
					target_size = UDim2.fromOffset(tw, TAB_H)
				end

				local t
				if not gtd._positioned then
					gtd._positioned = true
					gtd.tab_frame.Position = target_pos
					gtd.tab_frame.Size = UDim2.fromOffset(0, TAB_H)
					gtd.tab_frame.BackgroundTransparency = 1

					t = dOS.Tween.new(
						gtd.tab_frame,
						{ Size = target_size, BackgroundTransparency = 0.55 },
						dOS.TweenInfo.new(ANIM_SLOW, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
					)
					gtd._is_animating = true

					local captured_tw = tw
					local captured_show = show
					local captured_mode = mode
					task.delay(ANIM_SLOW + 0.02, function()
						if gtd then
							gtd._is_animating = nil
							if gtd.tab_frame and gtd.tab_frame.Parent then
								refresh_group_style(dOS, gtd, captured_tw, captured_show, captured_mode)
							end
						end
					end)
				else
					t = dOS.Tween.new(gtd.tab_frame, { Size = target_size, Position = target_pos }, tinfo)
				end

				set_tab_tween(gtd, t)
				t:Play()
				if not gtd._is_animating then refresh_group_style(dOS, gtd, tw, show, mode) end

				set_tab_tween(gtd, t)
				t:Play()

				ax += (is_vertical and (TAB_H + TAB_PAD) or (tw + TAB_PAD))
			end
		end

		if is_vertical then
			tm.tabs_holder.CanvasSize = UDim2.fromOffset(0, ax)
		else
			tm.tabs_holder.CanvasSize = UDim2.fromOffset(ax, 0)
		end
	end

	if mode == "individual" then
		for _, wf in ipairs(active_tab_order(dOS)) do
			local td = tm.window_tabs[wf]
			if td then update_tab_interaction_mode(dOS, td, false) end
		end
		for _, pd in pairs(tm.pinned_apps) do
			if pd.ghost_tab then update_tab_interaction_mode(dOS, pd.ghost_tab, false) end
		end
	else
		for _, gtd in pairs(tm.group_tabs) do
			-- groups use click for preview when overflowing to avoid miscalculations due to GAME LIMITATION
			update_tab_interaction_mode(dOS, gtd, true)
		end
	end

	M.refresh_mirror_taskbars(dOS)
end

M.update_taskbar_layout = M.update_layout

--- HELPER ???

local function update_visibility(dOS)
	local tm = M.taskbar_manager
	local cfg = get_cfg(dOS)
	if not (tm.frame and tm.frame.Parent) then return end

	local any_max = false
	if cfg.hide_fullscreen then
		for _, wf in ipairs(dOS.all_windows) do
			if wf and wf.Parent then
				local m = dOS.window_metadata[wf]
				if m and m.is_maximized and not m.is_minimized then
					any_max = true
					break
				end
			end
		end
	end

	local pos = cfg.position
	local info = dOS.TweenInfo.new(ANIM_MED, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

	if any_max and not tm.hidden then
		tm.hidden = true
		local hide_pos
		if pos == POS_BOTTOM then
			hide_pos = UDim2.new(0, 0, 1, TB_THICKNESS)
		elseif pos == POS_TOP then
			hide_pos = UDim2.fromOffset(0, -TB_THICKNESS)
		elseif pos == POS_LEFT then
			hide_pos = UDim2.fromOffset(-TB_THICKNESS, 0)
		else
			hide_pos = UDim2.fromScale(1, 0)
		end
		dOS.Tween.new(tm.frame, { Position = hide_pos }, info):Play()
		if dOS.program_holder_frame then
			dOS.Tween
				.new(dOS.program_holder_frame, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 0) }, info)
				:Play()
		end
	elseif not any_max and tm.hidden then
		tm.hidden = false
		local show_pos, ph_size, ph_pos
		if pos == POS_BOTTOM then
			show_pos = UDim2.new(0, 0, 1, -TB_THICKNESS)
			ph_size = UDim2.new(1, 0, 1, -TB_THICKNESS)
			ph_pos = UDim2.fromOffset(0, 0)
		elseif pos == POS_TOP then
			show_pos = UDim2.new(0, 0, 0, 0)
			ph_size = UDim2.new(1, 0, 1, -TB_THICKNESS)
			ph_pos = UDim2.fromOffset(0, TB_THICKNESS)
		elseif pos == POS_LEFT then
			show_pos = UDim2.new(0, 0, 0, 0)
			ph_size = UDim2.new(1, -TB_THICKNESS, 1, 0)
			ph_pos = UDim2.fromOffset(TB_THICKNESS, 0)
		else
			show_pos = UDim2.new(1, -TB_THICKNESS, 0, 0)
			ph_size = UDim2.new(1, -TB_THICKNESS, 1, 0)
			ph_pos = UDim2.fromOffset(0, 0)
		end
		dOS.Tween.new(tm.frame, { Position = show_pos }, info):Play()
		if dOS.program_holder_frame then
			dOS.Tween.new(dOS.program_holder_frame, { Size = ph_size, Position = ph_pos }, info):Play()
		end
	end
end

--- HOOKS

function M.on_window_opened(dOS, win_frame)
	if not M.taskbar_manager.tabs_holder then return end

	local tm = M.taskbar_manager
	local cfg = get_cfg(dOS)
	local mode = effective_mode(cfg, dOS)
	local meta = dOS.window_metadata[win_frame]

	if mode == "group" then
		local td = create_tab(dOS, win_frame)
		if td then td._positioned = true end
		M.update_layout(dOS)
		return
	end

	local is_ghost_conversion = false
	do
		local pin_data2 = meta and tm.pinned_apps[meta.title]
		if pin_data2 and pin_data2.ghost_tab and pin_data2.ghost_tab.is_ghost then is_ghost_conversion = true end
	end

	local td = create_tab(dOS, win_frame)
	if not td then return end

	if is_ghost_conversion then
		M.update_layout(dOS)
		return
	end

	local tw = tab_width_individual(cfg, dOS)
	local is_vertical = not is_horiz(cfg.position)
	local g_off = ghost_section_width(tm, is_vertical)
	local final_x, final_y

	if is_vertical then
		local px = math.floor((TB_THICKNESS - tw) / 2)
		final_x = px
		final_y = g_off
		for _, wf in ipairs(active_tab_order(dOS)) do
			if wf == win_frame then break end
			final_y += TAB_H + TAB_PAD
		end
	else
		final_x = g_off
		for _, wf in ipairs(active_tab_order(dOS)) do
			if wf == win_frame then break end
			final_x += tw + TAB_PAD
		end
		final_y = tab_y()
	end

	td._positioned = true

	td.tab_frame.Size = UDim2.fromOffset(is_vertical and tw or 0, is_vertical and 0 or TAB_H)
	td.tab_frame.Position = UDim2.fromOffset(final_x, final_y)
	td.tab_frame.BackgroundTransparency = 1

	if td.icon_elem then
		if td.icon_elem:IsA("ImageLabel") then
			td.icon_elem.ImageTransparency = 1
		else
			td.icon_elem.TextTransparency = 1
			td.icon_elem.BackgroundTransparency = 1
		end
	end
	if td.title_label then td.title_label.TextTransparency = 1 end

	local move_info = dOS.TweenInfo.new(ANIM_MED, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local ax_coord = g_off
	for _, wf in ipairs(active_tab_order(dOS)) do
		if wf ~= win_frame then
			local td2 = tm.window_tabs[wf]
			if td2 and td2.tab_frame and td2.tab_frame.Parent then
				cancel_tab_tween(wf)
				local t
				if is_vertical then
					local px = math.floor((TB_THICKNESS - tw) / 2)
					t = dOS.Tween.new(td2.tab_frame, {
						Size = UDim2.fromOffset(tw, TAB_H),
						Position = UDim2.fromOffset(px, ax_coord),
					}, move_info)
				else
					t = dOS.Tween.new(td2.tab_frame, {
						Size = UDim2.fromOffset(tw, TAB_H),
						Position = UDim2.fromOffset(ax_coord, final_y),
					}, move_info)
				end
				set_tab_tween(wf, t)
				t:Play()
			end
		end
		ax_coord += (is_vertical and (TAB_H + TAB_PAD) or (tw + TAB_PAD))
	end

	task.spawn(function()
		task.wait(0.02)
		if not td.tab_frame or not td.tab_frame.Parent then return end

		local expand_info = dOS.TweenInfo.new(ANIM_SLOW, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		dOS.Tween.new(td.tab_frame, { Size = UDim2.fromOffset(tw, TAB_H) }, expand_info):Play()

		local fade_in = dOS.TweenInfo.new(ANIM_FAST, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		dOS.Tween.new(td.tab_frame, { BackgroundTransparency = 0.55 }, fade_in):Play()
		if td.icon_elem then
			if td.icon_elem:IsA("ImageLabel") then
				dOS.Tween.new(td.icon_elem, { ImageTransparency = 0 }, fade_in):Play()
			else
				dOS.Tween
					.new(td.icon_elem, {
						TextTransparency = 0,
						BackgroundTransparency = 0.25,
					}, fade_in)
					:Play()
			end
		end
		if td.title_label then dOS.Tween.new(td.title_label, { TextTransparency = 0 }, fade_in):Play() end

		task.delay(ANIM_FAST, function()
			if td and td.tab_frame and td.tab_frame.Parent then
				animate_indicator(dOS, td, ind_state_for_win(dOS, win_frame), tw)
			end
		end)

		task.wait(ANIM_SLOW)
		if not td.tab_frame or not td.tab_frame.Parent then return end
		M.update_layout(dOS)
	end)
end

function M.on_window_closed(dOS, win_frame)
	local tm = M.taskbar_manager
	local td = tm.window_tabs[win_frame]
	if not td then return end

	local meta = dOS.window_metadata[win_frame]
	local is_pinned = false

	if meta then
		if meta.taskbar_pinned then
			is_pinned = true
		elseif tm.pinned_apps[meta.title] then

			is_pinned = true
			meta.taskbar_pinned = true
		end
	end

	tm.window_tabs[win_frame] = nil
	for i, wf in ipairs(tm.tab_order) do
		if wf == win_frame then
			table.remove(tm.tab_order, i)
			break
		end
	end

	if td._drag_cursor_conn then
		pcall(function() td._drag_cursor_conn:Disconnect() end)
		td._drag_cursor_conn = nil
	end
	if td._screen_up_conn then
		pcall(function() td._screen_up_conn:Disconnect() end)
		td._screen_up_conn = nil
	end

	if is_pinned and meta then
		local has_sibling = false
		for _, other_wf in ipairs(active_tab_order(dOS)) do
			local other_meta = dOS.window_metadata[other_wf]
			if other_meta and other_meta.title == meta.title then
				other_meta.taskbar_pinned = true
				has_sibling = true
				break
			end
		end

		if has_sibling then
			is_pinned = false
		end
	end

	-- remove tab frame / ghost conversion
	if td.tab_frame and td.tab_frame.Parent then
		if is_pinned and meta then
			td.is_ghost = true
			td.win_frame = nil

			if not tm.pinned_apps[meta.title] then
				tm.pinned_apps[meta.title] = {
					icon_id = resolve_icon_id(dOS, meta),
					title = meta.title,
					position_index = 1,
					ghost_tab = nil,
					launch_func = nil,
				}
			end

			hydrate_pin(tm.pinned_apps[meta.title], tm.__Special)
			tm.pinned_apps[meta.title].ghost_tab = td

			if td._cbs then
				local pd_ref = tm.pinned_apps[meta.title]
				td._cbs.click = function()
					if pd_ref.launch_func then
						task.spawn(pd_ref.launch_func)
					else
						open_app_by_title(dOS, pd_ref.app_name or pd_ref.title)
					end
				end
				td._cbs.rclick = make_ghost_rclick(dOS, meta.title)
			end

			setup_pin_drag(dOS, td, tm.pinned_apps[meta.title])

			local cfg = get_cfg(dOS)
			local is_vertical = not is_horiz(cfg.position)
			local pin_tw = TAB_ICON_W
			local ghosts = get_sorted_ghosts(tm)
			local pin_idx = 1
			for i, pd in ipairs(ghosts) do
				if pd.title == meta.title then
					pin_idx = i
					break
				end
			end

			local target_x, target_y
			if is_vertical then
				target_x = math.floor((TB_THICKNESS - pin_tw) / 2)
				target_y = TAB_PAD + (pin_idx - 1) * (TAB_H + TAB_PAD)
			else
				target_x = TAB_PAD + (pin_idx - 1) * (pin_tw + TAB_PAD)
				target_y = tab_y()
			end

			local PIN_SHRINK = 0.14
			local PIN_FLY = 0.24

			if td.title_label then td.title_label.Visible = false end
			if td.stacked_underline then td.stacked_underline.Visible = false end
			if td.badge_icon then td.badge_icon.Visible = false end

			cancel_tab_tween(win_frame)

			local cur_x = td.tab_frame.Position.X.Offset
			local cur_y = td.tab_frame.Position.Y.Offset
			local cur_w = td.tab_frame.Size.X.Offset
			td._pin_animating = true

			local center_x = cur_x + (cur_w - pin_tw) * 0.5
			local pa_info = dOS.TweenInfo.new(PIN_SHRINK, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

			dOS.Tween
				.new(td.tab_frame, {
					Size = UDim2.fromOffset(pin_tw, TAB_H),
					Position = UDim2.fromOffset(center_x, cur_y),
					BackgroundTransparency = 0.85,
				}, pa_info)
				:Play()

			if td.icon_elem then
				if td.icon_elem:IsA("ImageLabel") then
					dOS.Tween
						.new(td.icon_elem, {
							ImageTransparency = 0.5,
						}, pa_info)
						:Play()
				else
					dOS.Tween
						.new(td.icon_elem, {
							TextTransparency = 0.35,
							BackgroundTransparency = 0.55,
						}, pa_info)
						:Play()
				end
			end

			animate_indicator(dOS, td, "ghost", pin_tw)
			M.update_layout(dOS)

			task.spawn(function()
				task.wait(PIN_SHRINK)
				local frame = td.tab_frame
				local ok, alive = pcall(function() return frame ~= nil and frame.Parent ~= nil end)
				if not (ok and alive) then
					td._pin_animating = nil
					return
				end

				local pb_info = dOS.TweenInfo.new(PIN_FLY, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
				dOS.Tween
					.new(frame, {
						Position = UDim2.fromOffset(target_x, target_y),
					}, pb_info)
					:Play()

				task.wait(PIN_FLY)

				local ok2, alive2 = pcall(function() return frame ~= nil and frame.Parent ~= nil end)
				if ok2 and alive2 then
					frame.Position = UDim2.fromOffset(target_x, target_y)
					frame.Size = UDim2.fromOffset(pin_tw, TAB_H)
					if td.title_label then td.title_label.Visible = false end
					if td.badge_icon then td.badge_icon.Visible = false end
				end
				td._pin_animating = nil
			end)
		else
			-- not pinned
			local close_info = dOS.TweenInfo.new(ANIM_MED, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

			dOS.Tween
				.new(td.tab_frame, {
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(0, TAB_H),
				}, close_info)
				:Play()

			if td.icon_elem then
				if td.icon_elem:IsA("ImageLabel") or td.icon_elem:IsA("ImageButton") then
					dOS.Tween
						.new(td.icon_elem, {
							ImageTransparency = 1,
						}, close_info)
						:Play()
				else
					dOS.Tween
						.new(td.icon_elem, {
							TextTransparency = 1,
							BackgroundTransparency = 1,
						}, close_info)
						:Play()
				end
			end

			if td.title_label then
				dOS.Tween
					.new(td.title_label, {
						TextTransparency = 1,
					}, close_info)
					:Play()
			end

			animate_indicator(dOS, td, "ghost", 0)

			if td.badge_icon and td.badge_icon.Visible then
				dOS.Tween
					.new(td.badge_icon, {
						ImageTransparency = 1,
					}, close_info)
					:Play()
			end

			local tf = td.tab_frame
			task.delay(ANIM_MED + 0.05, function()
				if tf and tf.Parent then tf:Destroy() end
			end)
		end
	end

	local layout_delay = is_pinned and 0.48 or (ANIM_MED + 0.12)
	task.delay(layout_delay, function() M.update_layout(dOS) end)

	update_visibility(dOS)
end

function M.on_window_minimized(dOS, win_frame)
	local tm = M.taskbar_manager
	local td = tm.window_tabs[win_frame]
	if td then
		animate_indicator(dOS, td, "minimized", td.tab_frame and td.tab_frame.AbsoluteSize.X or TAB_MAX_W)
		if td.bg_tween then pcall(function() td.bg_tween:Cancel() end) end
		local t = dOS.Tween.new(td.tab_frame, { BackgroundTransparency = 0.75 }, dOS.TweenInfo.new(ANIM_FAST))
		td.bg_tween = t
		t:Play()
		if td.title_label then
			dOS.Tween.new(td.title_label, { TextTransparency = 0.45 }, dOS.TweenInfo.new(ANIM_FAST)):Play()
		end
	end

	for _, gtd in pairs(tm.group_tabs) do
		for _, wf in ipairs(gtd.win_frames) do
			if wf == win_frame then
				animate_indicator(
					dOS,
					gtd,
					ind_state_for_group(dOS, gtd),
					gtd.tab_frame and gtd.tab_frame.AbsoluteSize.X or TAB_MAX_W
				)
				local cfg = get_cfg(dOS)
				update_stacked_underline(
					dOS,
					gtd,
					#gtd.win_frames,
					gtd.tab_frame and gtd.tab_frame.AbsoluteSize.X or TAB_MAX_W,
					effective_mode(cfg, dOS)
				)
				break
			end
		end
	end
	M.refresh_mirror_taskbars(dOS)
	update_visibility(dOS)
end

function M.on_window_unminimized(dOS, win_frame)
	local tm = M.taskbar_manager
	local td = tm.window_tabs[win_frame]

	if td then
		if td.bg_tween then pcall(function() td.bg_tween:Cancel() end) end
		local t = dOS.Tween.new(td.tab_frame, { BackgroundTransparency = 0.55 }, dOS.TweenInfo.new(ANIM_FAST))
		td.bg_tween = t
		t:Play()
		if td.title_label then
			dOS.Tween.new(td.title_label, { TextTransparency = 0 }, dOS.TweenInfo.new(ANIM_FAST)):Play()
		end

		local tw = td.tab_frame and td.tab_frame.AbsoluteSize.X or TAB_MAX_W
		animate_indicator(dOS, td, ind_state_for_win(dOS, win_frame), tw)
	end

	for _, gtd in pairs(tm.group_tabs) do
		for _, wf in ipairs(gtd.win_frames) do
			if wf == win_frame then
				animate_indicator(
					dOS,
					gtd,
					ind_state_for_group(dOS, gtd),
					gtd.tab_frame and gtd.tab_frame.AbsoluteSize.X or TAB_MAX_W
				)
				local cfg = get_cfg(dOS)
				update_stacked_underline(
					dOS,
					gtd,
					#gtd.win_frames,
					gtd.tab_frame and gtd.tab_frame.AbsoluteSize.X or TAB_MAX_W,
					effective_mode(cfg, dOS)
				)
				break
			end
		end
	end
	M.refresh_mirror_taskbars(dOS)
	update_visibility(dOS)
end

function M.on_window_focused(dOS, win_frame)
	local tm = M.taskbar_manager

	for wf, td in pairs(tm.window_tabs) do
		if not wf.Parent then continue end
		local m2 = dOS.window_metadata[wf]
		local focused = wf == win_frame
		local is_min = m2 and m2.is_minimized
		local state = focused and "focused" or (is_min and "minimized" or "unfocused")
		local cur_tw = td.tab_frame and td.tab_frame.AbsoluteSize.X or TAB_MAX_W

		if td._hover_state then td._hover_state.is_focused = focused and not is_min end

		animate_indicator(dOS, td, state, cur_tw)

		if td.bg_tween then pcall(function() td.bg_tween:Cancel() end) end

		local target_trans = bg_trans(focused, is_min, td.is_ghost)
		local target_color = focused and not is_min and dOS.THEME.TASKBAR_BG:Lerp(dOS.THEME.ACCENT, 0.2)
			or dOS.THEME.TASKBAR_BG

		local t = dOS.Tween.new(td.tab_frame, {
			BackgroundTransparency = target_trans,
			BackgroundColor3 = target_color,
		}, dOS.TweenInfo.new(ANIM_MED, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
		td.bg_tween = t
		t:Play()
	end

	for _, gtd in pairs(tm.group_tabs) do
		local cur_tw = gtd.tab_frame and gtd.tab_frame.AbsoluteSize.X or TAB_MAX_W
		local state = ind_state_for_group(dOS, gtd)
		local focused = state == "focused"
		local is_min = state == "minimized"

		if gtd._hover_state then gtd._hover_state.is_focused = focused end

		animate_indicator(dOS, gtd, state, cur_tw)
		local cfg = get_cfg(dOS)
		update_stacked_underline(dOS, gtd, #gtd.win_frames, cur_tw, effective_mode(cfg, dOS))

		if gtd.tab_frame and gtd.tab_frame.Parent then
			local target_trans = bg_trans(focused, is_min, false)
			local target_color = focused and dOS.THEME.TASKBAR_BG:Lerp(dOS.THEME.ACCENT, 0.2) or dOS.THEME.TASKBAR_BG

			dOS.Tween
				.new(gtd.tab_frame, {
					BackgroundTransparency = target_trans,
					BackgroundColor3 = target_color,
				}, dOS.TweenInfo.new(ANIM_MED, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
				:Play()
		end
	end
	M.refresh_mirror_taskbars(dOS)
end

function M.on_window_maximized(dOS, _wf) update_visibility(dOS) end
function M.on_window_unmaximized(dOS, _wf) update_visibility(dOS) end

--- API

function M.get_tab_screen_position(win_frame)
	local tm = M.taskbar_manager
	local td = tm.window_tabs[win_frame]

	if td and td.tab_frame and td.tab_frame.Parent then
		local ap = td.tab_frame.AbsolutePosition
		local sz = td.tab_frame.AbsoluteSize
		return Vector2.new(ap.X + sz.X / 2, ap.Y + sz.Y / 2)
	end

	for _, gtd in pairs(tm.group_tabs) do
		for _, wf in ipairs(gtd.win_frames) do
			if wf == win_frame and gtd.tab_frame and gtd.tab_frame.Parent then
				local ap = gtd.tab_frame.AbsolutePosition
				local sz = gtd.tab_frame.AbsoluteSize
				return Vector2.new(ap.X + sz.X / 2, ap.Y + sz.Y / 2)
			end
		end
	end
	return nil
end

function M.get_start_menu_anchor(dOS, menu_w, menu_h)
	local pos = dOS.os_settings.taskbar_position or POS_BOTTOM
	local tb = dOS.taskbar_frame
	local tb_x = tb and tb.AbsoluteSize.X or TB_THICKNESS
	local tb_y = tb and tb.AbsoluteSize.Y or TB_THICKNESS

	if pos == POS_BOTTOM then
		return { final = UDim2.new(0, 5, 1, -(tb_y + menu_h + 3)), start = UDim2.new(0, 5, 1, 0) }
	elseif pos == POS_TOP then
		return { final = UDim2.fromOffset(5, tb_y + 3), start = UDim2.fromOffset(5, -menu_h) }
	elseif pos == POS_LEFT then
		return {
			final = UDim2.new(0, tb_x + 3, 1, -(menu_h + 3)),
			start = UDim2.new(0, -menu_w, 1, -(menu_h + 3)),
		}
	else
		return {
			final = UDim2.new(1, -(menu_w + tb_x + 3), 1, -(menu_h + 3)),
			start = UDim2.new(1, 3, 1, -(menu_h + 3)),
		}
	end
end

function M.reset()
	local tm = M.taskbar_manager

	for _, td in pairs(tm.window_tabs) do
		if td._drag_cursor_conn then pcall(function() td._drag_cursor_conn:Disconnect() end) end
		if td.tab_frame and td.tab_frame.Parent then td.tab_frame:Destroy() end
	end
	for _, gtd in pairs(tm.group_tabs) do
		if gtd.tab_frame and gtd.tab_frame.Parent then gtd.tab_frame:Destroy() end
	end
	for _, pin_data in pairs(tm.pinned_apps) do
		if pin_data.ghost_tab then
			if pin_data.ghost_tab._drag_cursor_conn then
				pcall(function() pin_data.ghost_tab._drag_cursor_conn:Disconnect() end)
			end
			if pin_data.ghost_tab.tab_frame and pin_data.ghost_tab.tab_frame.Parent then
				pin_data.ghost_tab.tab_frame:Destroy()
			end
		end
	end

	if tm.context_menu_shield and tm.context_menu_shield.Parent then tm.context_menu_shield:Destroy() end
	if tm.context_menu and tm.context_menu.Parent then tm.context_menu:Destroy() end
	if tm.preview_popup and tm.preview_popup.Parent then tm.preview_popup:Destroy() end

	tm.frame = nil
	tm.tabs_holder = nil
	tm.start_button = nil
	tm.clock_frame = nil
	tm.window_tabs = {}
	tm.tab_order = {}
	tm.group_tabs = {}
	tm.pinned_apps = {}
	tm.context_menu = nil
	tm.context_menu_shield = nil
	tm.preview_popup = nil
	tm.preview_hover_active = false
	tm.hidden = false
	tm.tab_drag = {
		active = false,
		win_frame = nil,
		tab_frame = nil,
		orig_idx = 0,
		cur_idx = 0,
		latest_x = 0,
		latest_y = 0,
		last_swap_x = 0,
		tab_tweens = {},
	}
	tm.debounce_timers = {}
	tm.minimized_apps_holder = nil
	tm.minimized_windows = {}
	tm.__Special = nil

	-- Tear down mirror taskbars
	for _, mirror in pairs(tm.mirrors) do
		if mirror.tab_data then
			for _, td in pairs(mirror.tab_data) do
				if td._drag_cursor_conn then
					pcall(function() td._drag_cursor_conn:Disconnect() end)
					td._drag_cursor_conn = nil
				end
				if td.tab_frame and td.tab_frame.Parent then
					pcall(function() td.tab_frame:Destroy() end)
				end
			end
		end
		if mirror.frame and mirror.frame.Parent then pcall(function() mirror.frame:Destroy() end) end
	end
	tm.mirrors = {}
	tm._on_start_click = nil
end

function M.init(
	dOS,
	__Special: {
		start_menu_data: { all_apps: { { name: string, launch_func: () -> (), icon_id: number? } } },
	}?,
	on_start_click
)
	M.reset()

	-- for app launching
	M.taskbar_manager.__Special = __Special

	local cfg = get_cfg(dOS)
	local pos = cfg.position
	local horiz = is_horiz(pos)
	local transp = dOS.os_settings.transparentTB and 1 or 0

	local tb_size, tb_pos, ph_size, ph_pos
	if pos == POS_BOTTOM then
		tb_size = UDim2.new(1, 0, 0, TB_THICKNESS)
		tb_pos = UDim2.new(0, 0, 1, -TB_THICKNESS)
		ph_size = UDim2.new(1, 0, 1, -TB_THICKNESS)
		ph_pos = UDim2.fromOffset(0, 0)
	elseif pos == POS_TOP then
		tb_size = UDim2.new(1, 0, 0, TB_THICKNESS)
		tb_pos = UDim2.new(0, 0, 0, 0)
		ph_size = UDim2.new(1, 0, 1, -TB_THICKNESS)
		ph_pos = UDim2.fromOffset(0, TB_THICKNESS)
	elseif pos == POS_LEFT then
		tb_size = UDim2.new(0, TB_THICKNESS, 1, 0)
		tb_pos = UDim2.new(0, 0, 0, 0)
		ph_size = UDim2.new(1, -TB_THICKNESS, 1, 0)
		ph_pos = UDim2.fromOffset(TB_THICKNESS, 0)
	else
		tb_size = UDim2.new(0, TB_THICKNESS, 1, 0)
		tb_pos = UDim2.new(1, -TB_THICKNESS, 0, 0)
		ph_size = UDim2.new(1, -TB_THICKNESS, 1, 0)
		ph_pos = UDim2.fromOffset(0, 0)
	end

	local tb = dOS.create_gui_element(dOS, "Frame", {
		Name = "Taskbar",
		Parent = dOS.screen,
		ZIndex = dOS.Z_INDEX.TASKBAR,
		BackgroundColor3 = dOS.THEME.TASKBAR_BG,
		BackgroundTransparency = transp,
		BorderSizePixel = 0,
		Size = tb_size,
		Position = tb_pos,
	})
	if not tb then
		logError("[TaskbarManager] Failed to create taskbar frame!")
		return nil, nil
	end

	dOS.create_gui_element(dOS, "Frame", {
		Parent = tb,
		Name = "AccentBorder",
		BackgroundColor3 = dOS.THEME.BORDER_HIGHLIGHT,
		BackgroundTransparency = 0.55,
		Size = horiz and UDim2.new(1, 0, 0, 1) or UDim2.new(0, 1, 1, 0),
		Position = pos == POS_BOTTOM and UDim2.fromOffset(0, 0)
			or pos == POS_TOP and UDim2.new(0, 0, 1, -1)
			or pos == POS_LEFT and UDim2.new(1, -1, 0, 0)
			or UDim2.fromOffset(0, 0),
		ZIndex = (tb.ZIndex or 1) + 1,
	})

	dOS.taskbar_frame = tb
	M.taskbar_manager.frame = tb

	local ph = dOS.create_gui_element(dOS, "Frame", {
		Name = "ProgramHolder",
		Parent = dOS.screen,
		ZIndex = dOS.Z_INDEX.WINDOW_INACTIVE - 1,
		BackgroundTransparency = 1,
		Size = ph_size,
		Position = ph_pos,
	})
	if not ph then
		logError("[TaskbarManager] Failed to create ProgramHolder!")
		return nil, nil
	end
	dOS.program_holder_frame = ph

	local tbz = tb.ZIndex or 1

	if horiz then
		M.taskbar_manager.vdm_btn_pos = UDim2.new(0, START_W + 4, 0.5, -14)
		M.taskbar_manager.vdm_btn_size = UDim2.fromOffset(VDM_W - 8, 28)
	else
		M.taskbar_manager.vdm_btn_pos = UDim2.new(0.5, -((TB_THICKNESS - 12) / 2), 0, 52)
		M.taskbar_manager.vdm_btn_size = UDim2.fromOffset(TB_THICKNESS - 12, VDM_W - 8)
	end

	local tabs_start, tabs_end
	if horiz then
		tabs_start = TABS_START_H -- START_W + VDM_W + 8
		tabs_end = CLOCK_W + 8
	else
		tabs_start = 52 + (VDM_W - 8) + 6 -- = 94
		tabs_end = 48 -- clock
	end

	local tabs_holder = dOS.create_gui_element(dOS, "ScrollingFrame", {
		Name = "TabsHolder",
		Parent = tb,
		ZIndex = tbz + 1,
		Size = horiz and UDim2.new(1, -(tabs_start + tabs_end), 1, 0) or UDim2.new(1, 0, 1, -(tabs_start + tabs_end)),
		Position = horiz and UDim2.fromOffset(tabs_start, 0) or UDim2.fromOffset(0, tabs_start),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollingDirection = horiz and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y,
	})
	M.taskbar_manager.tabs_holder = tabs_holder
	M.taskbar_manager.minimized_apps_holder = tabs_holder

	tb.MouseButton1Up:Connect(function() M._stop_drag(dOS) end)
	tb.MouseButton1Click:Connect(function()
		close_context_menu(dOS)
		M.taskbar_manager.preview_hover_active = false
		close_preview_popup(dOS)
	end)

	local start_btn = dOS.create_gui_element(dOS, "TextButton", {
		Name = "StartButton",
		Parent = tb,
		ZIndex = tbz + 2,
		Text = "dOS",
		TextColor3 = dOS.THEME.TEXT_LIGHT,
		BackgroundColor3 = dOS.THEME.START_BUTTON_BG,
		HoverColor = dOS.THEME.START_BUTTON_HOVER,
		Font = dOS.FONT_BOLD,
		TextSize = dOS.os_settings.global_font_size + 2,
		Size = horiz and UDim2.new(0, START_W, 1, -6) or UDim2.new(1, -6, 0, 40),
		Position = horiz and UDim2.fromOffset(4, 3) or UDim2.fromOffset(3, 4),
		OnClick = function()
			close_context_menu(dOS)
			M.taskbar_manager.preview_hover_active = false
			close_preview_popup(dOS)
			if on_start_click then on_start_click() end
		end,
	})
	dOS.create_gui_element(dOS, "UICorner", { Parent = start_btn, CornerRadius = UDim.new(0, 5) })
	M.taskbar_manager.start_button = start_btn

	local clock = dOS.create_gui_element(dOS, "Frame", {
		Parent = tb,
		Name = "ClockFrame",
		ZIndex = tbz + 1,
		BackgroundTransparency = 1,
		Size = horiz and UDim2.new(0, CLOCK_W, 1, 0) or UDim2.new(1, 0, 0, 44),
		Position = horiz and UDim2.new(1, -(CLOCK_W + 4), 0, 0) or UDim2.new(0, 0, 1, -48),
	})
	M.taskbar_manager.clock_frame = clock

	local cz = clock.ZIndex or 1
	local hour_lbl = dOS.create_gui_element(dOS, "TextLabel", {
		Parent = clock,
		Font = dOS.FONT_REGULAR,
		TextSize = dOS.os_settings.global_font_size,
		TextColor3 = dOS.THEME.TEXT_DIM,
		BackgroundTransparency = 1,
		ZIndex = cz + 1,
		Text = 0,
	})
	local sep_lbl = dOS.create_gui_element(dOS, "TextLabel", {
		Parent = clock,
		Font = dOS.FONT_REGULAR,
		Text = ":",
		TextSize = dOS.os_settings.global_font_size,
		TextColor3 = dOS.THEME.TEXT_DIM,
		BackgroundTransparency = 1,
		ZIndex = cz + 1,
	})
	local min_lbl = dOS.create_gui_element(dOS, "TextLabel", {
		Parent = clock,
		Font = dOS.FONT_REGULAR,
		TextSize = dOS.os_settings.global_font_size,
		TextColor3 = dOS.THEME.TEXT_DIM,
		BackgroundTransparency = 1,
		ZIndex = cz + 1,
		Text = 0,
	})

	if horiz then
		hour_lbl.Size = UDim2.fromScale(0.4, 1)
		hour_lbl.Position = UDim2.fromScale(0, 0)
		sep_lbl.Size = UDim2.fromScale(0.2, 1)
		sep_lbl.Position = UDim2.fromScale(0.4, 0)
		min_lbl.Size = UDim2.fromScale(0.4, 1)
		min_lbl.Position = UDim2.fromScale(0.6, 0)
	else
		sep_lbl.Visible = false
		hour_lbl.Size = UDim2.new(1, 0, 0, 20)
		hour_lbl.Position = UDim2.fromOffset(0, 0)
		min_lbl.Size = UDim2.new(1, 0, 0, 20)
		min_lbl.Position = UDim2.fromOffset(0, 22)
	end

	task.spawn(function()
		while clock and clock.Parent do
			local hour, minute = get_clock_parts()
			hour_lbl.Text = hour
			min_lbl.Text = minute
			task.wait(30)
		end
	end)

	load_pinned_apps(dOS)

	for _, pin_data in pairs(M.taskbar_manager.pinned_apps) do
		hydrate_pin(pin_data, M.taskbar_manager.__Special)
	end

	for _, pin_data in pairs(M.taskbar_manager.pinned_apps) do
		if not pin_data.ghost_tab then create_ghost_tab(dOS, pin_data) end
	end

	M.taskbar_manager._on_start_click = on_start_click

	M.update_layout(dOS)
	return tb, ph
end

local MIRROR_TAB_W  = TAB_ICON_W -- 44 px icon
local MIRROR_IND_H  = IND_H -- 3
local MIRROR_ANIM_T = ANIM_FAST -- 0.12s

function M.refresh_mirror_layout(dOS, screen_id)
	local mirror = M.taskbar_manager.mirrors[screen_id]
	if not mirror or not mirror.tabs_holder or not mirror.tabs_holder.Parent then return end

	local tm = M.taskbar_manager
	local proxy = mirror.proxy
	local horiz = is_horiz(get_cfg(dOS).position)

	local groups_for_mode = compute_groups(dOS)
	local mode = "group"

	local desired = {}
	local desired_map = {}

	local function push_entry(entry)
		table.insert(desired, entry)
		desired_map[entry.key] = entry
	end

	for _, pd in ipairs(get_sorted_ghosts(tm)) do
		push_entry({
			key = "ghost_" .. (pd.title or ""),
			key_string = "ghost_" .. (pd.title or ""),
			kind = "ghost",
			title = pd.title or "",
			icon_id = pd.icon_id or 0,
			wins = {},
			pin_data = pd,
		})
	end

	if mode == "group" then
		local groups = groups_for_mode
		for _, g in ipairs(groups) do
			local icon_id = 0
			if g.wins[1] then
				local meta = dOS.window_metadata[g.wins[1]]
				icon_id = (meta and resolve_icon_id(dOS, meta)) or 0
			end
			push_entry({
				key = "group_" .. g.key,
				key_string = "group_" .. g.key,
				kind = "group",
				title = g.key,
				icon_id = icon_id,
				wins = g.wins,
			})
		end
	else
		for i, wf in ipairs(tm.tab_order) do
			local meta = dOS.window_metadata[wf]
			if meta then
				push_entry({
					key = wf,
					key_string = "win_" .. tostring(i) .. "_" .. tostring(meta.title),
					kind = "window",
					title = meta.title,
					icon_id = resolve_icon_id(dOS, meta) or 0,
					wins = { wf },
					win_frame = wf,
				})
			end
		end
	end

	for key, td in pairs(mirror.tab_data) do
		if not desired_map[key] then
			if td._drag_cursor_conn then
				pcall(function() td._drag_cursor_conn:Disconnect() end)
				td._drag_cursor_conn = nil
			end
			if td.tab_frame and td.tab_frame.Parent then
				local f = td.tab_frame
				dOS.Tween
					.new(f, { Size = UDim2.fromOffset(0, TAB_H), BackgroundTransparency = 1 },
						dOS.TweenInfo.new(MIRROR_ANIM_T, Enum.EasingStyle.Quint, Enum.EasingDirection.In))
					:Play()
				task.delay(MIRROR_ANIM_T + 0.05, function()
					if f and f.Parent then pcall(function() f:Destroy() end) end
				end)
			end
			mirror.tab_data[key] = nil
		end
	end

	local TINFO = dOS.TweenInfo.new(MIRROR_ANIM_T, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local ax = TAB_PAD
	local drag = tm.tab_drag

	for _, entry in ipairs(desired) do
		local key = entry.key
		local wins = entry.wins or {}
		local is_focused = false
		local all_minimized = (#wins > 0)
		for _, wf in ipairs(wins) do
			local m = dOS.window_metadata[wf]
			if wf == dOS.active_window_frame and not (m and m.is_minimized) then is_focused = true end
			if not (m and m.is_minimized) then all_minimized = false end
		end
		local is_minimized = all_minimized and #wins > 0

		if not mirror.tab_data[key] then
			local function get_current_wins()
				local td_ref = mirror.tab_data[key]
				if td_ref and td_ref.win_frames then return td_ref.win_frames end
				return entry.wins or {}
			end

			local function on_click()
				if entry.kind == "ghost" then
					local pd = entry.pin_data
					if not pd then return end
					hydrate_pin(pd, tm.__Special)
					if pd.launch_func then task.spawn(pd.launch_func) else open_app_by_title(dOS, pd.app_name or pd.title) end
					return
				end

				local local_wins = get_current_wins()
				if #local_wins == 0 then return end
				if #local_wins == 1 then
					local wf = local_wins[1]
					local m = dOS.window_metadata[wf]
					if not m then return end
					if m.is_minimized then
						dOS.Window.handle_unminimize_window(dOS, wf)
					elseif dOS.active_window_frame == wf then
						if m.is_minimizable then dOS.Window.handle_minimize_window(dOS, wf) end
					else
						dOS.Window.set_active_window(dOS, wf)
					end
				else
					local focused_wf = dOS.active_window_frame
					local next_wf = local_wins[1]
					local found = false
					for _, wf in ipairs(local_wins) do
						if found then next_wf = wf; break end
						if wf == focused_wf then found = true end
					end
					local m = dOS.window_metadata[next_wf]
					if m and m.is_minimized then dOS.Window.handle_unminimize_window(dOS, next_wf)
					elseif m then dOS.Window.set_active_window(dOS, next_wf) end
				end
			end

			local function on_rclick()
				if entry.kind == "ghost" then
					local ghost_rclick_fn = make_ghost_rclick(proxy, entry.title)
					if ghost_rclick_fn then ghost_rclick_fn() end
					return
				end
				local local_wins = get_current_wins()
				if #local_wins == 0 then return end
				local target_wf = local_wins[1]
				for _, wf in ipairs(local_wins) do
					if dOS.active_window_frame == wf then target_wf = wf; break end
				end
				local td_ref = mirror.tab_data[key]
				if td_ref and td_ref.tab_frame then open_context_menu(proxy, target_wf, td_ref.tab_frame, #local_wins > 1, local_wins) end
			end

			local debounce_key_enter = "mir_" .. tostring(screen_id) .. "_enter_" .. entry.key_string
			local debounce_key_close = "mir_" .. tostring(screen_id) .. "_close_" .. entry.key_string
			local function on_hover_enter()
				local local_wins = get_current_wins()
				if entry.kind ~= "group" or #local_wins <= 1 then return end
				if tm.context_menu and tm.context_menu.Parent then return end
				debounce(debounce_key_enter, PREVIEW_HOVER_DELAY, function()
					if tm.context_menu and tm.context_menu.Parent then return end
					local td_ref = mirror.tab_data[key]
					if not (td_ref and td_ref.tab_frame and td_ref.tab_frame.Parent) then return end
					local wins_now = get_current_wins()
					if #wins_now <= 1 then return end
					show_group_preview(proxy, {
						tab_frame = td_ref.tab_frame,
						win_frames = wins_now,
						group_key = entry.key_string,
						_use_click_for_preview = false,
					}, td_ref.tab_frame)
				end)
			end
			local function on_hover_leave()
				cancel_debounce(debounce_key_enter)
				debounce(debounce_key_close, 0.2, function()
					if not tm.preview_hover_active then close_preview_popup(proxy) end
				end)
			end

			local drag_ctx = nil
			if entry.kind == "ghost" then
				drag_ctx = { pin_data = entry.pin_data, screen_hw = proxy.screen, tabs_holder = mirror.tabs_holder, taskbar_frame = mirror.frame }
			elseif entry.kind == "window" then
				drag_ctx = { win_frame = entry.win_frame, screen_hw = proxy.screen, tabs_holder = mirror.tabs_holder, taskbar_frame = mirror.frame }
			end

			local td = build_tab_frame(proxy, entry.icon_id, entry.title, MIRROR_TAB_W, false,
				on_click, on_rclick, on_hover_enter, on_hover_leave, entry.kind == "ghost", drag_ctx, mirror.tabs_holder)
			if not td then continue end

			if entry.kind == "group" then
				td.group_key = entry.title
				td.win_frames = {}
				for _, wf in ipairs(entry.wins) do table.insert(td.win_frames, wf) end
				setup_group_tab_drag(proxy, td, proxy.screen, mirror.tabs_holder, mirror.frame)
			elseif entry.kind == "window" then
				td.win_frame = entry.win_frame
			end

			mirror.tab_data[key] = td
			td.tab_frame.Size = UDim2.fromOffset(0, TAB_H)
			td.tab_frame.BackgroundTransparency = 1
			td._positioned = false
		else
			local td = mirror.tab_data[key]
			if entry.kind == "group" then
				td.win_frames = {}
				for _, wf in ipairs(entry.wins) do table.insert(td.win_frames, wf) end
			elseif entry.kind == "window" then
				td.win_frame = entry.win_frame
			end
		end

		local td = mirror.tab_data[key]
		if td and td.tab_frame and td.tab_frame.Parent then
			local is_dragged = drag.active
				and ((entry.kind == "ghost" and drag.is_pin and drag.pin_title == entry.title)
					or (entry.kind == "window" and not drag.is_pin and not drag.is_group and drag.win_frame == entry.win_frame)
					or (entry.kind == "group" and drag.is_group and drag.group_key == entry.title))

			local target_pos = horiz
				and UDim2.fromOffset(ax, math.floor((TB_THICKNESS - TAB_H) / 2))
				or UDim2.fromOffset(math.floor((TB_THICKNESS - MIRROR_TAB_W) / 2), ax)
			local target_size = UDim2.fromOffset(MIRROR_TAB_W, TAB_H)

			if not td._positioned then
				td._positioned = true
				td.tab_frame.Position = target_pos
				dOS.Tween
					.new(td.tab_frame, {
						Size = target_size,
						BackgroundTransparency = entry.kind == "ghost" and 0.85 or (is_focused and 0.25 or 0.65),
					}, dOS.TweenInfo.new(ANIM_SLOW, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
					:Play()
			elseif not is_dragged then
				dOS.Tween.new(td.tab_frame, {
					Position = target_pos,
					Size = target_size,
					BackgroundTransparency = entry.kind == "ghost" and 0.85 or (is_focused and 0.25 or 0.65),
				}, TINFO):Play()
			end

			if td.indicator and td.indicator.Parent then
				local ind_w, ind_col, ind_t
				if entry.kind == "ghost" then
					ind_w = 0; ind_col = dOS.THEME.TEXT_DIM; ind_t = 1
				elseif is_focused then
					ind_w = MIRROR_TAB_W - 14; ind_col = dOS.THEME.ACCENT_BUTTON_BG; ind_t = 0
				elseif is_minimized then
					ind_w = 6; ind_col = dOS.THEME.TEXT_DIM; ind_t = 0.15
				else
					ind_w = 3; ind_col = dOS.THEME.TEXT_DIM; ind_t = 0.55
				end
				dOS.Tween.new(td.indicator, {
					Size = UDim2.fromOffset(ind_w, MIRROR_IND_H),
					BackgroundColor3 = ind_col,
					BackgroundTransparency = ind_t,
				}, dOS.TweenInfo.new(MIRROR_ANIM_T, Enum.EasingStyle.Quint)):Play()
			end
		end

		ax += (horiz and (MIRROR_TAB_W + TAB_PAD) or (TAB_H + TAB_PAD))
	end

	if mirror.tabs_holder and mirror.tabs_holder.Parent then
		mirror.tabs_holder.CanvasSize = horiz and UDim2.fromOffset(ax, 0) or UDim2.fromOffset(0, ax)
	end
end
function M.refresh_mirror_taskbars(dOS)
	for screen_id in pairs(M.taskbar_manager.mirrors) do
		M.refresh_mirror_layout(dOS, screen_id)
	end
end


function M.create_mirror_taskbar(dOS, screen_ctx)
	if not dOS.DWM then
		warn("[TaskbarManager] create_mirror_taskbar: DWM not initialised.")
		return
	end

	local existing = M.taskbar_manager.mirrors[screen_ctx.id]
	if existing and existing.frame and existing.frame.Parent then pcall(function() existing.frame:Destroy() end) end
	M.taskbar_manager.mirrors[screen_ctx.id] = nil

	local proxy = dOS.DWM.make_screen_proxy(dOS, screen_ctx)
	local cfg = get_cfg(dOS)
	local pos = cfg.position
	local horiz = is_horiz(pos)
	local transp = dOS.os_settings.transparentTB and 1 or 0

	local tb_size, tb_pos
	if pos == POS_BOTTOM then
		tb_size = UDim2.new(1, 0, 0, TB_THICKNESS)
		tb_pos = UDim2.new(0, 0, 1, -TB_THICKNESS)
	elseif pos == POS_TOP then
		tb_size = UDim2.new(1, 0, 0, TB_THICKNESS)
		tb_pos = UDim2.new(0, 0, 0, 0)
	elseif pos == POS_LEFT then
		tb_size = UDim2.new(0, TB_THICKNESS, 1, 0)
		tb_pos = UDim2.new(0, 0, 0, 0)
	else
		tb_size = UDim2.new(0, TB_THICKNESS, 1, 0)
		tb_pos = UDim2.new(1, -TB_THICKNESS, 0, 0)
	end

	local tb = dOS.create_gui_element(proxy, "Frame", {
		Name = "Taskbar_Mirror_S" .. screen_ctx.id,
		ZIndex = dOS.Z_INDEX.TASKBAR,
		BackgroundColor3 = dOS.THEME.TASKBAR_BG,
		BackgroundTransparency = transp,
		BorderSizePixel = 0,
		Size = tb_size,
		Position = tb_pos,
	})
	if not tb then
		warn("[TaskbarManager] create_mirror_taskbar: frame creation failed for screen " .. screen_ctx.id)
		return
	end

	screen_ctx.taskbar_frame = tb
	local tbz = tb.ZIndex or 1

	dOS.create_gui_element(proxy, "Frame", {
		Parent = tb,
		Name = "AccentBorder",
		BackgroundColor3 = dOS.THEME.BORDER_HIGHLIGHT,
		BackgroundTransparency = 0.55,
		Size = horiz and UDim2.new(1, 0, 0, 1) or UDim2.new(0, 1, 1, 0),
		Position = (pos == POS_BOTTOM) and UDim2.fromOffset(0, 0)
			or (pos == POS_TOP) and UDim2.new(0, 0, 1, -1)
			or (pos == POS_LEFT) and UDim2.new(1, -1, 0, 0)
			or UDim2.fromOffset(0, 0),
		ZIndex = tbz + 1,
	})

	local start_btn = dOS.create_gui_element(proxy, "TextButton", {
		Parent = tb,
		Name = "StartButton_Mirror",
		ZIndex = tbz + 2,
		Text = "dOS",
		TextColor3 = dOS.THEME.TEXT_LIGHT,
		BackgroundColor3 = dOS.THEME.START_BUTTON_BG,
		HoverColor = dOS.THEME.START_BUTTON_HOVER,
		Font = dOS.FONT_BOLD,
		TextSize = dOS.os_settings.global_font_size + 2,
		Size = horiz and UDim2.new(0, START_W, 1, -6) or UDim2.new(1, -6, 0, 40),
		Position = horiz and UDim2.fromOffset(4, 3) or UDim2.fromOffset(3, 4),
		OnClick = function()
			if dOS.DWM then dOS.DWM._state.last_start_screen_id = screen_ctx.id end
			local cb = M.taskbar_manager._on_start_click
			if cb then cb() end
		end,
	})
	dOS.create_gui_element(proxy, "UICorner", { Parent = start_btn, CornerRadius = UDim.new(0, 5) })

	local tabs_start = horiz and TABS_START_H or (52 + (VDM_W - 8) + 6)
	local tabs_end = horiz and (CLOCK_W + 8) or 48

	local tabs_holder = dOS.create_gui_element(proxy, "ScrollingFrame", {
		Parent = tb,
		Name = "TabsHolder_Mirror",
		ZIndex = tbz + 1,
		Size = horiz and UDim2.new(1, -(tabs_start + tabs_end), 1, 0) or UDim2.new(1, 0, 1, -(tabs_start + tabs_end)),
		Position = horiz and UDim2.fromOffset(tabs_start, 0) or UDim2.fromOffset(0, tabs_start),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollingDirection = horiz and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y,
	})

	local clock = dOS.create_gui_element(proxy, "Frame", {
		Parent = tb,
		Name = "ClockFrame_Mirror",
		ZIndex = tbz + 1,
		BackgroundTransparency = 1,
		Size = horiz and UDim2.new(0, CLOCK_W, 1, 0) or UDim2.new(1, 0, 0, 44),
		Position = horiz and UDim2.new(1, -(CLOCK_W + 4), 0, 0) or UDim2.new(0, 0, 1, -48),
	})
	if clock then
		local cz = clock.ZIndex or 1
		local hl = dOS.create_gui_element(proxy, "TextLabel", {
			Parent = clock,
			Font = dOS.FONT_REGULAR,
			TextSize = dOS.os_settings.global_font_size,
			TextColor3 = dOS.THEME.TEXT_DIM,
			BackgroundTransparency = 1,
			ZIndex = cz + 1,
			Text = 0,
		})
		local sl = dOS.create_gui_element(proxy, "TextLabel", {
			Parent = clock,
			Font = dOS.FONT_REGULAR,
			Text = ":",
			TextSize = dOS.os_settings.global_font_size,
			TextColor3 = dOS.THEME.TEXT_DIM,
			BackgroundTransparency = 1,
			ZIndex = cz + 1,
		})
		local ml = dOS.create_gui_element(proxy, "TextLabel", {
			Parent = clock,
			Font = dOS.FONT_REGULAR,
			TextSize = dOS.os_settings.global_font_size,
			TextColor3 = dOS.THEME.TEXT_DIM,
			BackgroundTransparency = 1,
			ZIndex = cz + 1,
			Text = 0,
		})

		if horiz then
			if hl then
				hl.Size = UDim2.fromScale(0.4, 1)
				hl.Position = UDim2.fromScale(0, 0)
			end
			if sl then
				sl.Size = UDim2.fromScale(0.2, 1)
				sl.Position = UDim2.fromScale(0.4, 0)
			end
			if ml then
				ml.Size = UDim2.fromScale(0.4, 1)
				ml.Position = UDim2.fromScale(0.6, 0)
			end
		else
			if sl then sl.Visible = false end
			if hl then
				hl.Size = UDim2.new(1, 0, 0, 20)
				hl.Position = UDim2.fromOffset(0, 0)
			end
			if ml then
				ml.Size = UDim2.new(1, 0, 0, 20)
				ml.Position = UDim2.fromOffset(0, 22)
			end
		end

		task.spawn(function()
			while clock and clock.Parent do
				local hour, minute = get_clock_parts()
				if hl and hl.Parent then hl.Text = hour end
				if ml and ml.Parent then ml.Text = minute end
				task.wait(30)
			end
		end)
	end

	M.taskbar_manager.mirrors[screen_ctx.id] = {
		screen_ctx = screen_ctx,
		proxy = proxy,
		frame = tb,
		tabs_holder = tabs_holder,
		tab_data = {},
	}

	if dOS.VirtualDesktopManager and dOS.VirtualDesktopManager.create_taskbar_button then
		task.spawn(function()
			task.wait(0.05)
			if tb and tb.Parent then
				dOS.VirtualDesktopManager.create_taskbar_button(proxy)
			end
		end)
	end

	M.refresh_mirror_layout(dOS, screen_ctx.id)

	print("[TaskbarManager] Mirror taskbar created for screen " .. screen_ctx.id)
end

return M

-- EOF