--[[
    "Virtual Desktop Manager module for dOS"
    
    @module vdm
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

--- TYPES

--- CONFIG

local CFG = {
	Z_SCRIM = 9000,
	Z_OVERLAY = 9100,
	Z_CARD = 9200,
	Z_CTX_DISMISS = 9300,
	Z_CONTEXT = 9400,
	Z_GHOST = 9500,
	Z_CAPTURE = 9600,

	OVERLAY_H_FRAC = 0.62,
	HEADER_H = 36,
	DOCK_H = 54,
	SCROLL_BAR_W = 5,

	CARD_W = 172,
	CARD_H = 108,
	CARD_GAP = 14,
	CARD_TITLE_H = 22,
	HOVER_SHIFT = 12,

	TAB_W = 114,
	TAB_H = 36,
	TAB_GAP = 7,
	MAX_DESKTOPS = 9,
	ADD_BTN_W = 36,

	CTX_W = 182,
	CTX_ITEM_H = 32,
	CTX_PAD = 8,

	CTX_ICON_MOVE = 112459446074747,
	CTX_ICON_STAR = 14488863746,
	CTX_ICON_CLOSE = 109058392374604,
	CTX_ICON_RENAME = 101708694952341,
	CTX_ICON_LEFT = 12338896667,
	CTX_ICON_RIGHT = 12338895277,
	CTX_ICON_ADD = 88065133864491,

	ADD_DESKTOP_ICON = 11800831615,
	CLOSE_BUTTON_ICON = 136968209449975,
	TASKBAR_ICON = 121294895170873,

	DRAG_PX = 50,
	DRAG_WINDOW = 0.30,

	CTX_DEBOUNCE = 0.22,
	OPEN_DEBOUNCE = 0.35,

	T_OPEN = 0.46,
	T_CLOSE = 0.28,
	T_CTX_OPEN = 0.26,
	T_CTX_CLOSE = 0.16,
	T_CARD_ENTER = 0.44,
	T_HOVER = 0.18,
	T_SHIFT = 0.20,
	T_CASCADE = 0.055,
}

--- STATE

local function _new_state()
	return {
		desktops = {},
		active_di = 1,
		preview_di = 1,

		overlay = nil,
		scrim = nil,
		cards_scroll = nil,
		dock_scroll = nil,
		header_status = nil,
		context = nil,
		ctx_dismiss = nil,
		capture_shield = nil,
		taskbar_btns = {},
		active_screen_hw = nil,

		win_di = {},
		cdrag = { active = false, win_frame = nil, uid = nil, ghost = nil },
		tdrag = { active = false, from_di = nil, uid = nil, ghost = nil },
		is_open = false,
		card_elems = {},

		_cursor_conn = nil,
		_last_ctx_t = 0,
		_last_open_t = 0,
		_ovy = 0,
		_init_dos = nil,
		_orig_create = nil,
		_orig_unmin = nil,
	}
end

local S = _new_state()
M._state = S

--- FWD DCLS

local _redraw
local _redraw_cards
local _redraw_dock

--- UTILS

local function _alive(obj)
	if obj == nil then return false end
	local ok, p = pcall(function() return obj.Parent end)
	return ok and p ~= nil
end

local function _get(obj, k)
	if obj == nil then return nil end
	local ok, v = pcall(function() return (obj :: any)[k] end)
	return if ok then v else nil
end

local function _set(obj, k, v)
	if obj == nil then return false end
	local ok = pcall(function() (obj :: any)[k] = v end)
	return ok
end

local function _destroy(obj)
	if _alive(obj) then pcall(function() obj:Destroy() end) end
end

local function _clear(frame)
	if not _alive(frame) then return end
	local ok, ch = pcall(function() return frame:GetChildren() end)
	if ok and ch then
		for _, c in ipairs(ch) do
			pcall(function() c:Destroy() end)
		end
	end
end

local function _disc(conn)
	if conn then pcall(function() conn:Disconnect() end) end
end

local function _nearest_cursor(dOS, x, y, tol)
	local threshold = tol or 80
	local screen = dOS.screen
	local ok, cursors = pcall(function() return screen:GetCursors() end)
	if not ok or not cursors then return nil end

	for _, c in pairs(cursors) do
		local dx = c.X - x
		local dy = c.Y - y
		if math.sqrt(dx * dx + dy * dy) < threshold then return c end
	end
	return nil
end

local function _hit(x, y, elem)
	local ok1, p = pcall(function() return (elem :: GuiObject).AbsolutePosition end)
	local ok2, sz = pcall(function() return (elem :: GuiObject).AbsoluteSize end)
	if not (ok1 and ok2) then return false end

	local pos = p :: Vector2
	local size = sz :: Vector2
	return x >= pos.X and x <= pos.X + size.X and y >= pos.Y and y <= pos.Y + size.Y
end

local function _to_local(sx, sy)
	if not _alive(S.overlay) then return sx, sy end
	local ok, ap = pcall(function() return (S.overlay :: GuiObject).AbsolutePosition end)
	if not ok then return sx, sy end

	local v = ap :: Vector2
	return sx - v.X, sy - v.Y
end

--- DATA

local function _new_desktop(name)
	return { name = name, windows = {} }
end

local function _assign(win, di)
	local old = S.win_di[win]
	if old and S.desktops[old] then S.desktops[old].windows[win] = nil end
	S.win_di[win] = di
	if S.desktops[di] then S.desktops[di].windows[win] = true end
end

local function _track_window(win)
	if not _alive(win) then return end
	_assign(win, S.active_di)

	pcall(function()
		win.Destroying:Connect(function()
			for _, desk in ipairs(S.desktops) do
				desk.windows[win] = nil
			end
			S.win_di[win] = nil
		end)
	end)
end

local function _apply_visibility(dOS)
	for di, desktop in ipairs(S.desktops) do
		local show = di == S.active_di
		for wf in pairs(desktop.windows) do
			if _alive(wf) then
				local meta = dOS.window_metadata and dOS.window_metadata[wf]
				if meta and not meta.is_minimized then _set(wf, "Visible", show) end
			end
		end
	end
end

local function _update_status_label()
	local desk = S.desktops[S.active_di]
	if _alive(S.header_status) and desk then _set(S.header_status, "Text", "● " .. desk.name) end
end

--- ANIMATION

local function _tw(dOS, inst, props, dur, style, dir)
	if not _alive(inst) then return end
	local ti = dOS.TweenInfo.new(dur, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out)
	pcall(function() dOS.Tween.new(inst, props, ti):Play() end)
end

local function _fluid(dOS, inst, props, dur)
	_tw(dOS, inst, props, dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
end

local function _smooth(dOS, inst, props, dur)
	_tw(dOS, inst, props, dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

--- DRAG

local function _stop_drags()
	_destroy(S.cdrag.ghost)
	S.cdrag = { active = false, win_frame = nil, uid = nil, ghost = nil }
	_destroy(S.tdrag.ghost)
	S.tdrag = { active = false, from_di = nil, uid = nil, ghost = nil }

	if _alive(S.capture_shield) then
		_set(S.capture_shield, "Visible", false)
		_set(S.capture_shield, "Active", false)
	end
end

local function _enable_shield()
	if _alive(S.capture_shield) then
		_set(S.capture_shield, "Visible", true)
		_set(S.capture_shield, "Active", true)
	end
end

local function _make_ghost(dOS, w, h, label)
	if not _alive(S.overlay) then return nil end

	local g = dOS.create_gui_element(dOS, "Frame", {
		Parent = S.overlay,
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		ZIndex = CFG.Z_GHOST,
	})
	if not g then return nil end

	dOS.create_gui_element(dOS, "UICorner", { Parent = g, CornerRadius = UDim.new(0, 10) })
	dOS.create_gui_element(dOS, "UIStroke", {
		Parent = g,
		Color = dOS.THEME.BORDER_HIGHLIGHT,
		Thickness = 2,
	})
	dOS.create_gui_element(dOS, "Frame", {
		Parent = g,
		Size = UDim2.fromScale(1, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		ZIndex = CFG.Z_GHOST + 1,
	})
	dOS.create_gui_element(dOS, "TextLabel", {
		Parent = g,
		Text = label,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Color3.new(1, 1, 1),
		Font = dOS.FONT_BOLD,
		TextSize = 12,
		BackgroundTransparency = 1,
		TextWrapped = true,
		ZIndex = CFG.Z_GHOST + 2,
	})
	return g
end

local function _ghost_pos(cx, cy, half_w, half_h)
	local lx, ly = _to_local(cx, cy)
	return UDim2.fromOffset(lx - half_w, ly - half_h)
end

local function _resolve_drop(dOS, x, y)
	if S.cdrag.active then
		local wf = S.cdrag.win_frame
		if wf and _alive(wf) and _alive(S.dock_scroll) then
			for di = 1, #S.desktops do
				local tab = S.dock_scroll:FindFirstChild("VDMT_" .. di)
				if tab and _hit(x, y, tab) then
					if di ~= S.win_di[wf] then M.move_window(dOS, wf, di) end
					break
				end
			end
		end
	end

	if S.tdrag.active then
		local from = S.tdrag.from_di
		if _alive(S.dock_scroll) and from then
			local ok_p, dp = pcall(function() return (S.dock_scroll :: GuiObject).AbsolutePosition end)
			local ok_c, cp = pcall(function() return (S.dock_scroll :: ScrollingFrame).CanvasPosition end)
			if ok_p and ok_c then
				local canvas_off = (cp :: Vector2).X
				local rel_x = x - (dp :: Vector2).X + canvas_off
				local to_di = math.clamp(math.floor(rel_x / (CFG.TAB_W + CFG.TAB_GAP)) + 1, 1, #S.desktops)
				if to_di ~= (from :: number) then
					_stop_drags()
					M.reorder(dOS, from :: number, to_di)
					return
				end
			end
		end
	end

	_stop_drags()
	task.spawn(_redraw, dOS)
end

-- CONTEXT MENU

local function _close_ctx(dOS)
	local ctx = S.context
	if not ctx then return end
	S.context = nil

	if _alive(S.ctx_dismiss) then
		_set(S.ctx_dismiss, "Visible", false)
		_set(S.ctx_dismiss, "Active", false)
	end

	if _alive(ctx) then
		local ti = dOS.TweenInfo.new(CFG.T_CTX_CLOSE, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		pcall(function()
			dOS.Tween.new(ctx, {
				Size = UDim2.fromOffset(CFG.CTX_W, 0),
				BackgroundTransparency = 1,
			}, ti):Play()
		end)
		task.delay(CFG.T_CTX_CLOSE + 0.05, function() _destroy(ctx) end)
	end
end

local function _open_ctx(dOS, items, sx, sy)
	if #items == 0 then return end
	if not _alive(S.overlay) then return end
	if type(sx) ~= "number" or type(sy) ~= "number" then return end

	local now = tick()
	if now - S._last_ctx_t < CFG.CTX_DEBOUNCE then return end
	S._last_ctx_t = now

	_close_ctx(dOS)

	local lx, ly = _to_local(sx, sy)

	local real_n = 0
	local sep_n = 0
	for _, it in ipairs(items) do
		if it.separator then
			sep_n += 1
		else
			real_n += 1
		end
	end
	local total_h = real_n * CFG.CTX_ITEM_H + sep_n * 12 + CFG.CTX_PAD * 2

	local ov_ok, ov_sz = pcall(function() return (S.overlay :: GuiObject).AbsoluteSize end)
	local ov_size = if ov_ok then ov_sz :: Vector2 else Vector2.new(800, 600)
	local px = math.clamp(lx, 4, ov_size.X - CFG.CTX_W - 4)
	local py = math.clamp(ly, 4, ov_size.Y - total_h - 4)

	if not _alive(S.ctx_dismiss) then
		local dis = dOS.create_gui_element(dOS, "TextButton", {
			Parent = S.overlay,
			Name = "VDM_CtxDismiss",
			Text = "",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = CFG.Z_CTX_DISMISS,
			Active = false,
			Visible = false,
			BorderSizePixel = 0,
		})
		if dis then dis.MouseButton1Click:Connect(function() _close_ctx(dOS) end) end
		S.ctx_dismiss = dis
	end

	if _alive(S.ctx_dismiss) then
		_set(S.ctx_dismiss, "Visible", true)
		_set(S.ctx_dismiss, "Active", true)
	end

	local ctx = dOS.create_gui_element(dOS, "Frame", {
		Parent = S.overlay,
		Name = "VDM_Context",
		Position = UDim2.fromOffset(px, py),
		Size = UDim2.fromOffset(CFG.CTX_W, 0),
		BackgroundColor3 = dOS.THEME.WINDOW_BG,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = CFG.Z_CONTEXT,
		BorderSizePixel = 0,
	})
	if not ctx then return end

	dOS.create_gui_element(dOS, "UICorner", { Parent = ctx, CornerRadius = UDim.new(0, 9) })
	dOS.create_gui_element(dOS, "UIStroke", {
		Parent = ctx,
		Color = dOS.THEME.BORDER_HIGHLIGHT,
		Thickness = 1,
	})
	dOS.create_gui_element(dOS, "Frame", {
		Parent = ctx,
		Size = UDim2.new(1, -4, 0, 1),
		Position = UDim2.fromOffset(2, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		ZIndex = CFG.Z_CONTEXT + 1,
	})
	S.context = ctx

	local cur_y = CFG.CTX_PAD
	for _, item in ipairs(items) do
		if item.separator then
			dOS.create_gui_element(dOS, "Frame", {
				Parent = ctx,
				Size = UDim2.new(1, -16, 0, 1),
				Position = UDim2.fromOffset(8, cur_y + 5),
				BackgroundColor3 = dOS.THEME.BORDER_HIGHLIGHT,
				BackgroundTransparency = 0.40,
				BorderSizePixel = 0,
				ZIndex = CFG.Z_CONTEXT + 1,
			})
			cur_y += 12
		else
			local is_danger = item.danger == true
			local text_color = if is_danger then Color3.fromRGB(255, 72, 72) else dOS.THEME.TEXT_LIGHT
			local has_icon = (item.icon ~= nil)
			local text_offset = has_icon and 30 or 12

			local row = dOS.create_gui_element(dOS, "TextButton", {
				Parent = ctx,
				Text = "",
				Size = UDim2.new(1, 0, 0, CFG.CTX_ITEM_H),
				Position = UDim2.fromOffset(0, cur_y),
				BackgroundColor3 = dOS.THEME.WINDOW_BG,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = CFG.Z_CONTEXT + 1,
			})
			if row then
				dOS.create_gui_element(dOS, "UICorner", {
					Parent = row,
					CornerRadius = UDim.new(0, 5),
				})

				if has_icon then
					dOS.create_gui_element(dOS, "ImageLabel", {
						Parent = row,
						Image = item.icon,
						Size = UDim2.fromOffset(16, 16),
						Position = UDim2.new(0, 8, 0.5, -8),
						BackgroundTransparency = 1,
						ImageColor3 = text_color,
						ZIndex = CFG.Z_CONTEXT + 2,
					})
				end

				dOS.create_gui_element(dOS, "TextLabel", {
					Parent = row,
					Text = item.label or "",
					Size = UDim2.new(1, -text_offset - 8, 1, 0),
					Position = UDim2.fromOffset(text_offset, 0),
					TextColor3 = text_color,
					TextXAlignment = Enum.TextXAlignment.Left,
					Font = dOS.FONT_REGULAR,
					TextSize = 13,
					BackgroundTransparency = 1,
					ZIndex = CFG.Z_CONTEXT + 2,
				})

				dOS.HoverManager.register(row, {
					HoverColor = dOS.THEME.ACCENT_BUTTON_BG,
					BackgroundColor3 = dOS.THEME.WINDOW_BG,
					OnEnter = function() _smooth(dOS, row, { BackgroundTransparency = 0.55 }, 0.09) end,
					OnLeave = function() _smooth(dOS, row, { BackgroundTransparency = 1 }, 0.09) end,
				})

				local action = item.action
				row.MouseButton1Click:Connect(function()
					_close_ctx(dOS)
					if action then task.spawn(action) end
				end)
			end
			cur_y += CFG.CTX_ITEM_H
		end
	end

	local ti_open = dOS.TweenInfo.new(CFG.T_CTX_OPEN, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	pcall(function()
		dOS.Tween.new(ctx, {
			Size = UDim2.fromOffset(CFG.CTX_W, total_h),
			BackgroundTransparency = 0.06,
		}, ti_open):Play()
	end)
end

local function _shift_neighbors(dOS, hovered_idx, active)
	for i, entry in ipairs(S.card_elems) do
		if i ~= hovered_idx and _alive(entry.frame) then
			local offset = 0
			if active then offset = if i < hovered_idx then -CFG.HOVER_SHIFT else CFG.HOVER_SHIFT end
			_smooth(dOS, entry.frame, {
				Position = UDim2.fromOffset(entry.base_x + offset, CFG.CARD_GAP),
			}, CFG.T_SHIFT)
		end
	end
end

-- CARD

local function _build_card(dOS, win_frame, card_di, px, idx, simple_hover)
	local meta = dOS.window_metadata and dOS.window_metadata[win_frame]
	if not meta then return end
	local title = meta.title or ((_get(win_frame, "Name") :: string?) or "Window")

	local delay = (idx - 1) * CFG.T_CASCADE

	local card = dOS.create_gui_element(dOS, "TextButton", {
		Parent = S.cards_scroll,
		Name = "VDMC_" .. ((_get(win_frame, "Name") :: string?) or tostring(idx)),
		Text = "",
		Size = UDim2.fromOffset(CFG.CARD_W, CFG.CARD_H),
		Position = UDim2.fromOffset(px, CFG.CARD_GAP + 16), -- 16px start offset
		BackgroundColor3 = dOS.THEME.TITLE_BAR_BG,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = CFG.Z_CARD,
		BackgroundTransparency = 1,
		AutoButtonColor = simple_hover,
	})
	if not card then return end

	dOS.create_gui_element(dOS, "UICorner", { Parent = card, CornerRadius = UDim.new(0, 10) })
	dOS.create_gui_element(dOS, "UIStroke", {
		Parent = card,
		Color = dOS.THEME.BORDER_HIGHLIGHT,
		Thickness = 1,
	})

	task.delay(delay, function()
		if not _alive(card) then return end
		_fluid(dOS, card, {
			Position = UDim2.fromOffset(px, CFG.CARD_GAP),
			BackgroundTransparency = 0,
		}, CFG.T_CARD_ENTER)
	end)

	S.card_elems[idx] = { frame = card, base_x = px, idx = idx }

	local tbar = dOS.create_gui_element(dOS, "Frame", {
		Parent = card,
		Size = UDim2.new(1, 0, 0, CFG.CARD_TITLE_H),
		BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
		BorderSizePixel = 0,
		ZIndex = CFG.Z_CARD + 1,
	})
	if tbar then
		dOS.create_gui_element(dOS, "UICorner", {
			Parent = tbar,
			CornerRadius = UDim.new(0, 10),
		})
		local DOT_COLORS = {
			Color3.fromRGB(222, 75, 65),
			Color3.fromRGB(235, 185, 45),
			Color3.fromRGB(68, 200, 80),
		}
		for di, col in ipairs(DOT_COLORS) do
			local dot = dOS.create_gui_element(dOS, "Frame", {
				Parent = tbar,
				Size = UDim2.fromOffset(7, 7),
				Position = UDim2.new(1, -(8 + (di - 1) * 13), 0.5, -4),
				BackgroundColor3 = col,
				BorderSizePixel = 0,
				ZIndex = CFG.Z_CARD + 2,
			})
			if dot then
				dOS.create_gui_element(dOS, "UICorner", {
					Parent = dot,
					CornerRadius = UDim.new(1, 0),
				})
			end
		end
	end

	-- title
	dOS.create_gui_element(dOS, "TextLabel", {
		Parent = card,
		Text = title,
		Size = UDim2.new(1, -10, 0, CFG.CARD_TITLE_H),
		Position = UDim2.fromOffset(8, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Font = dOS.FONT_BOLD,
		TextSize = 11,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = CFG.Z_CARD + 2,
	})

	if dOS.DWM and dOS.DWM._state then
		local win_sid = dOS.DWM._state.win_screen and dOS.DWM._state.win_screen[win_frame]
		if win_sid and win_sid > 1 then
			dOS.create_gui_element(dOS, "TextLabel", {
				Parent = card,
				Name = "ScreenBadge",
				Text = "S" .. win_sid,
				TextColor3 = Color3.new(1, 1, 1),
				BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG or Color3.fromRGB(80, 120, 220),
				BackgroundTransparency = 0,
				Size = UDim2.fromOffset(22, 14),
				Position = UDim2.new(1, -26, 0, 4),
				TextSize = 10,
				Font = dOS.FONT_BOLD,
				ZIndex = (card.ZIndex or 1) + 3,
				BorderSizePixel = 0,
			})
		end
	end

	local LINE_WS = { 0.74, 0.52, 0.68, 0.38 }
	for li, lw in ipairs(LINE_WS) do
		dOS.create_gui_element(dOS, "Frame", {
			Parent = card,
			Size = UDim2.new(lw, 0, 0, 3),
			Position = UDim2.fromOffset(8, CFG.CARD_TITLE_H + 8 + (li - 1) * 14),
			BackgroundColor3 = dOS.THEME.TEXT_DIM,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			ZIndex = CFG.Z_CARD + 1,
		})
	end

	if dOS.active_window_frame == win_frame then
		local dot_active = dOS.create_gui_element(dOS, "Frame", {
			Parent = card,
			Size = UDim2.fromOffset(7, 7),
			Position = UDim2.fromOffset(8, 6),
			BackgroundColor3 = Color3.fromRGB(68, 228, 124),
			BorderSizePixel = 0,
			ZIndex = CFG.Z_CARD + 3,
		})
		if dot_active then
			dOS.create_gui_element(dOS, "UICorner", {
				Parent = dot_active,
				CornerRadius = UDim.new(1, 0),
			})
		end
	end

	if meta.is_minimized then
		local badge = dOS.create_gui_element(dOS, "Frame", {
			Parent = card,
			Size = UDim2.fromOffset(20, 14),
			Position = UDim2.new(1, -24, 1, -19),
			BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
			BackgroundTransparency = 0.30,
			BorderSizePixel = 0,
			ZIndex = CFG.Z_CARD + 3,
		})
		if badge then
			dOS.create_gui_element(dOS, "UICorner", {
				Parent = badge,
				CornerRadius = UDim.new(0, 4),
			})
			dOS.create_gui_element(dOS, "TextLabel", {
				Parent = badge,
				Text = "--",
				Size = UDim2.fromScale(1, 1),
				TextColor3 = Color3.new(1, 1, 1),
				Font = dOS.FONT_BOLD,
				TextSize = 10,
				BackgroundTransparency = 1,
				ZIndex = CFG.Z_CARD + 4,
			})
		end
	end

	if not simple_hover then
		dOS.HoverManager.register(card, {
			HoverColor = dOS.THEME.WINDOW_BG,
			BackgroundColor3 = dOS.THEME.TITLE_BAR_BG,
			OnEnter = function()
				_shift_neighbors(dOS, idx, true)
				_smooth(dOS, card, {
					Size = UDim2.fromOffset(CFG.CARD_W + 9, CFG.CARD_H + 9),
				}, CFG.T_HOVER)
			end,
			OnLeave = function()
				_shift_neighbors(dOS, idx, false)
				_smooth(dOS, card, {
					Size = UDim2.fromOffset(CFG.CARD_W, CFG.CARD_H),
				}, CFG.T_HOVER)
			end,
		})
	end

	card.MouseButton1Click:Connect(function()
		if S.cdrag.active then return end
		_smooth(dOS, card, { Size = UDim2.fromOffset(CFG.CARD_W - 4, CFG.CARD_H - 4) }, 0.06)
		task.delay(0.06, function()
			if not _alive(card) then return end
			M.close(dOS)
			if card_di ~= S.active_di then M.switch_to_desktop(dOS, card_di) end
			task.spawn(function()
				task.wait(CFG.T_CLOSE + 0.06)
				if not _alive(win_frame) then return end
				local m = dOS.window_metadata and dOS.window_metadata[win_frame]
				if m and m.is_minimized then
					dOS.Window.handle_unminimize_window(dOS, win_frame)
				else
					dOS.Window.set_active_window(dOS, win_frame)
				end
			end)
		end)
	end)

	card.MouseButton2Up:Connect(function(mx, my)
		local ctx_items = {}
		for di, desk in ipairs(S.desktops) do
			if di ~= card_di then
				local di_copy = di
				table.insert(ctx_items, {
					icon = CFG.CTX_ICON_MOVE,
					label = desk.name,
					action = function() M.move_window(dOS, win_frame, di_copy) end,
				})
			end
		end

		if #ctx_items > 0 then table.insert(ctx_items, { separator = true } :: any) end
		if card_di ~= S.active_di then
			table.insert(ctx_items, {
				icon = CFG.CTX_ICON_STAR,
				label = "Bring to Active Desktop",
				action = function() M.move_window(dOS, win_frame, S.active_di) end,
			})
			table.insert(ctx_items, { separator = true } :: any)
		end

		table.insert(ctx_items, {
			icon = CFG.CTX_ICON_CLOSE,
			label = "Close Window",
			danger = true,
			action = function()
				dOS.Window.close_window(dOS, win_frame)
				task.delay(0.72, function()
					if S.is_open then task.spawn(_redraw_cards, dOS) end
				end)
			end,
		})
		_open_ctx(dOS, ctx_items, mx, my)
	end)

	card.MouseButton1Down:Connect(function(mx, my)
		if S.cdrag.active or S.tdrag.active then return end
		local cursor = _nearest_cursor(dOS, mx, my)
		if not cursor then return end

		local uid = cursor.UserId
		local start = Vector2.new(cursor.X, cursor.Y)
		local t0 = os.clock()
		local conn

		local screen = dOS.screen :: any
		conn = screen.CursorMoved:Connect(function(c)
			if c.UserId ~= uid then return end
			if os.clock() - t0 > CFG.DRAG_WINDOW then
				_disc(conn)
				conn = nil
				return
			end
			if (Vector2.new(c.X, c.Y) - start).Magnitude >= CFG.DRAG_PX then
				_disc(conn)
				conn = nil
				local ghost = _make_ghost(dOS, CFG.CARD_W, CFG.CARD_H, title)
				if not ghost then return end
				S.cdrag = { active = true, win_frame = win_frame, uid = uid, ghost = ghost }
				_set(ghost, "Position", _ghost_pos(c.X, c.Y, CFG.CARD_W / 2, CFG.CARD_H / 2))
				_enable_shield()
			end
		end)

		task.delay(CFG.DRAG_WINDOW + 0.05, function()
			_disc(conn)
			conn = nil
		end)
	end)
end

--- TAB

local function _build_tab(dOS, di)
	local desktop = S.desktops[di]
	if not desktop then return end
	if not _alive(S.dock_scroll) then return end

	local tab_x = (di - 1) * (CFG.TAB_W + CFG.TAB_GAP) + CFG.TAB_GAP
	local tab_y = (CFG.DOCK_H - CFG.TAB_H) / 2
	local is_act = di == S.active_di
	local is_prev = di == S.preview_di

	local tab_bg = if is_act then dOS.THEME.ACCENT_BUTTON_BG else dOS.THEME.TITLE_BAR_BG

	local tab = dOS.create_gui_element(dOS, "TextButton", {
		Parent = S.dock_scroll,
		Name = "VDMT_" .. di,
		Text = "",
		Size = UDim2.fromOffset(CFG.TAB_W, CFG.TAB_H),
		Position = UDim2.fromOffset(tab_x, tab_y),
		BackgroundColor3 = tab_bg,
		BorderSizePixel = 0,
		ZIndex = CFG.Z_CARD,
		AutoButtonColor = true,
	})
	if not tab then return end

	dOS.create_gui_element(dOS, "UICorner", { Parent = tab, CornerRadius = UDim.new(0, 8) })

	if is_prev then
		dOS.create_gui_element(dOS, "UIStroke", {
			Parent = tab,
			Color = if is_act then Color3.new(1, 1, 1) else dOS.THEME.ACCENT_BUTTON_BG,
			Thickness = 2,
		})
	end

	local wcount = 0
	for wf in pairs(desktop.windows) do
		if _alive(wf) then
			wcount += 1
		end
	end

	dOS.create_gui_element(dOS, "TextLabel", {
		Parent = tab,
		Text = desktop.name,
		Size = UDim2.new(1, if wcount > 0 then -28 else -10, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		TextColor3 = if is_act then Color3.new(1, 1, 1) else dOS.THEME.TEXT_LIGHT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = if is_act then dOS.FONT_BOLD else dOS.FONT_REGULAR,
		TextSize = 12,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = CFG.Z_CARD + 1,
	})

	if wcount > 0 then
		local badge = dOS.create_gui_element(dOS, "Frame", {
			Parent = tab,
			Size = UDim2.fromOffset(19, 19),
			Position = UDim2.new(1, -23, 0.5, -10),
			BackgroundColor3 = if is_act then Color3.new(1, 1, 1) else dOS.THEME.TEXT_DIM,
			BackgroundTransparency = if is_act then 0.70 else 0.42,
			BorderSizePixel = 0,
			ZIndex = CFG.Z_CARD + 1,
		})
		if badge then
			dOS.create_gui_element(dOS, "UICorner", {
				Parent = badge,
				CornerRadius = UDim.new(1, 0),
			})
			dOS.create_gui_element(dOS, "TextLabel", {
				Parent = badge,
				Text = wcount,
				Size = UDim2.fromScale(1, 1),
				TextColor3 = if is_act then dOS.THEME.ACCENT_BUTTON_BG else dOS.THEME.TEXT_LIGHT,
				Font = dOS.FONT_BOLD,
				TextSize = 10,
				BackgroundTransparency = 1,
				ZIndex = CFG.Z_CARD + 2,
			})
		end
	end

	if is_prev and not is_act then
		local pdot = dOS.create_gui_element(dOS, "Frame", {
			Parent = tab,
			Size = UDim2.fromOffset(5, 5),
			Position = UDim2.new(0.5, -3, 1, -7),
			BackgroundColor3 = dOS.THEME.TEXT_LIGHT,
			BorderSizePixel = 0,
			ZIndex = CFG.Z_CARD + 2,
		})
		if pdot then
			dOS.create_gui_element(dOS, "UICorner", {
				Parent = pdot,
				CornerRadius = UDim.new(1, 0),
			})
		end
	end

	tab.MouseButton1Click:Connect(function()
		if S.tdrag.active or S.cdrag.active then return end
		if S.preview_di == di then
			M.switch_to_desktop(dOS, di)
			M.close(dOS)
		else
			S.preview_di = di
			_redraw_cards(dOS)
			_redraw_dock(dOS)
		end
	end)

	tab.MouseButton2Up:Connect(function(mx, my)
		local ctx_items = {}
		table.insert(ctx_items, {
			icon = CFG.CTX_ICON_RENAME,
			label = "Rename",
			action = function()
				dOS.RequestStringAsync(dOS, "New name:", desktop.name, function(n)
					if n and n ~= "" and S.desktops[di] then
						S.desktops[di].name = string.sub(n, 1, 22)
						if S.is_open then task.spawn(_redraw, dOS) end
					end
				end)
			end,
		})

		if di > 1 then
			table.insert(ctx_items, {
				icon = CFG.CTX_ICON_LEFT,
				label = "Move Left",
				action = function() M.reorder(dOS, di, di - 1) end,
			})
		end

		if di < #S.desktops then
			table.insert(ctx_items, {
				icon = CFG.CTX_ICON_RIGHT,
				label = "Move Right",
				action = function() M.reorder(dOS, di, di + 1) end,
			})
		end

		table.insert(ctx_items, {
			icon = CFG.CTX_ICON_ADD,
			label = "New Desktop",
			action = function() M.create_desktop(dOS) end,
		})

		if #S.desktops > 1 then
			table.insert(ctx_items, { separator = true } :: any)
			table.insert(ctx_items, {
				icon = CFG.CTX_ICON_CLOSE,
				label = "Delete Desktop",
				danger = true,
				action = function() M.delete_desktop(dOS, di) end,
			})
		end

		_open_ctx(dOS, ctx_items, mx, my)
	end)

	tab.MouseButton1Down:Connect(function(mx, my)
		if S.tdrag.active or S.cdrag.active then return end
		local cursor = _nearest_cursor(dOS, mx, my)
		if not cursor then return end

		local uid = cursor.UserId
		local start = Vector2.new(cursor.X, cursor.Y)
		local t0 = os.clock()
		local conn

		local screen = dOS.screen :: any
		conn = screen.CursorMoved:Connect(function(c)
			if c.UserId ~= uid then return end
			if os.clock() - t0 > CFG.DRAG_WINDOW / 2 then
				_disc(conn)
				conn = nil
				return
			end
			if (Vector2.new(c.X, c.Y) - start).Magnitude >= CFG.DRAG_PX then
				_disc(conn)
				conn = nil
				local ghost = _make_ghost(dOS, CFG.TAB_W, CFG.TAB_H, desktop.name)
				if not ghost then return end
				S.tdrag = { active = true, from_di = di, uid = uid, ghost = ghost }
				_set(ghost, "Position", _ghost_pos(c.X, c.Y, CFG.TAB_W / 2, CFG.TAB_H / 2))
				_enable_shield()
			end
		end)

		task.delay(CFG.DRAG_WINDOW + 0.05, function()
			_disc(conn)
			conn = nil
		end)
	end)
end

--- REDRAW

_redraw_cards = function(dOS)
	if not _alive(S.cards_scroll) then return end
	_clear(S.cards_scroll)
	S.card_elems = {}

	local desktop = S.desktops[S.preview_di]
	if not desktop then return end

	local valid = {}
	for wf in pairs(desktop.windows) do
		if _alive(wf) then table.insert(valid, wf) end
	end
	table.sort(valid, function(a, b) return tostring(a) < tostring(b) end)

	local total_canvas_w = #valid * (CFG.CARD_W + CFG.CARD_GAP) + CFG.CARD_GAP
	local frame_w = 0
	local ok_sz, fsz = pcall(function() return (S.cards_scroll :: GuiObject).AbsoluteSize end)
	if ok_sz then frame_w = (fsz :: Vector2).X end

	local simple_hover = total_canvas_w > frame_w and frame_w > 0

	local cur_x = CFG.CARD_GAP
	for i, wf in ipairs(valid) do
		_build_card(dOS, wf, S.preview_di, cur_x, i, simple_hover)
		cur_x += CFG.CARD_W + CFG.CARD_GAP
	end

	if #valid == 0 then
		dOS.create_gui_element(dOS, "TextLabel", {
			Parent = S.cards_scroll,
			Text = "No windows on this desktop.",
			Size = UDim2.fromScale(1, 1),
			TextColor3 = dOS.THEME.TEXT_DIM,
			BackgroundTransparency = 1,
			TextSize = 14,
			ZIndex = CFG.Z_CARD,
		})
	end

	pcall(function()
		(S.cards_scroll :: ScrollingFrame).CanvasSize = UDim2.fromOffset(math.max(total_canvas_w, 0), 0)
	end)
end

_redraw_dock = function(dOS)
	if not _alive(S.dock_scroll) then return end
	_clear(S.dock_scroll)

	for di = 1, #S.desktops do
		_build_tab(dOS, di) -- AutoButtonColor
	end

	local dock_canvas_w = #S.desktops * (CFG.TAB_W + CFG.TAB_GAP)
		+ CFG.TAB_GAP
		+ (if #S.desktops < CFG.MAX_DESKTOPS then CFG.ADD_BTN_W + CFG.TAB_GAP else 0)

	-- "+" New Desktop button
	if #S.desktops < CFG.MAX_DESKTOPS then
		local add_x = #S.desktops * (CFG.TAB_W + CFG.TAB_GAP) + CFG.TAB_GAP
		local add_btn = dOS.create_gui_element(dOS, "ImageButton", {
			Parent = S.dock_scroll,
			Name = "VDM_AddTab",
			Image = CFG.ADD_DESKTOP_ICON,
			Size = UDim2.fromOffset(CFG.ADD_BTN_W, CFG.TAB_H),
			Position = UDim2.fromOffset(add_x, (CFG.DOCK_H - CFG.TAB_H) / 2),
			BackgroundColor3 = dOS.THEME.TITLE_BAR_BG,
			BorderSizePixel = 0,
			ZIndex = CFG.Z_CARD,
			AutoButtonColor = true,
		})
		if add_btn then
			dOS.create_gui_element(dOS, "UICorner", {
				Parent = add_btn,
				CornerRadius = UDim.new(0, 8),
			})
			add_btn.MouseButton1Click:Connect(function() M.create_desktop(dOS) end)
		end
	end

	pcall(function()
		(S.dock_scroll :: ScrollingFrame).CanvasSize = UDim2.fromOffset(dock_canvas_w, 0)
	end)
end

_redraw = function(dOS)
	_redraw_cards(dOS)
	_redraw_dock(dOS)
end

-- API

function M.open(dOS)
	if S.is_open then
		if S.active_screen_hw and dOS and S.active_screen_hw ~= dOS.screen then
			M.close(S._last_dos or dOS)
			task.wait(CFG.T_CLOSE + 0.05)
		else
			return
		end
	end

	local now = tick()
	if now - S._last_open_t < CFG.OPEN_DEBOUNCE then return end
	S._last_open_t = now

	if not (dOS and _get(dOS.screen, "GetCanvas")) then
		warn("[VDM] open() called with invalid dOS")
		return
	end

	S.is_open = true
	S.active_screen_hw = dOS.screen
	S._last_dos = dOS
	S.preview_di = S.active_di

	local sdims = dOS.screen_dimensions or Vector2.new(800, 600)
	local OVH = math.floor(sdims.Y * CFG.OVERLAY_H_FRAC)
	local OVY = sdims.Y - OVH - 36
	S._ovy = OVY

	local scrim = dOS.create_gui_element(dOS, "TextButton", {
		Parent = dOS.screen,
		Name = "VDM_Scrim",
		Text = "",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = CFG.Z_SCRIM,
		Active = false,
		BorderSizePixel = 0,
	})
	if scrim then scrim.MouseButton1Click:Connect(function() M.close(dOS) end) end
	S.scrim = scrim

	-- overlay
	local ov = dOS.create_gui_element(dOS, "Frame", {
		Parent = dOS.screen,
		Name = "VDM_Overlay",
		Size = UDim2.new(1, 0, 0, OVH),
		Position = UDim2.fromOffset(0, sdims.Y),
		BackgroundColor3 = dOS.THEME.WINDOW_BG,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = CFG.Z_OVERLAY,
	})
	if not ov then
		S.is_open = false
		warn("[VDM] Failed to create overlay")
		_destroy(scrim)
		S.scrim = nil
		return
	end
	S.overlay = ov

	local accent = dOS.create_gui_element(dOS, "Frame", {
		Parent = ov,
		Size = UDim2.fromOffset(0, 2),
		BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		ZIndex = CFG.Z_OVERLAY + 5,
	})
	dOS.create_gui_element(dOS, "Frame", {
		Parent = ov,
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
		BackgroundTransparency = 0.92,
		BorderSizePixel = 0,
		ZIndex = CFG.Z_OVERLAY + 1,
	})

	local header = dOS.create_gui_element(dOS, "Frame", {
		Parent = ov,
		Name = "VDM_Header",
		Size = UDim2.new(1, 0, 0, CFG.HEADER_H),
		Position = UDim2.fromOffset(0, 2),
		BackgroundColor3 = dOS.THEME.TITLE_BAR_BG,
		BorderSizePixel = 0,
		ZIndex = CFG.Z_OVERLAY + 2,
	})
	if header then
		dOS.create_gui_element(dOS, "TextLabel", {
			Parent = header,
			Text = "Virtual Desktops",
			Size = UDim2.fromScale(0.45, 1),
			Position = UDim2.fromOffset(12, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = dOS.THEME.TEXT_LIGHT,
			Font = dOS.FONT_BOLD,
			TextSize = 13,
			BackgroundTransparency = 1,
			ZIndex = CFG.Z_OVERLAY + 3,
		})

		local active_name = (S.desktops[S.active_di] and S.desktops[S.active_di].name) or "Desktop 1"
		local status_lbl = dOS.create_gui_element(dOS, "TextLabel", {
			Parent = header,
			Name = "VDM_Status",
			Text = active_name,
			Size = UDim2.fromScale(0.4, 1),
			Position = UDim2.fromScale(0.3, 0),
			TextColor3 = dOS.THEME.ACCENT_BUTTON_BG,
			Font = dOS.FONT_BOLD,
			TextSize = 11,
			BackgroundTransparency = 1,
			ZIndex = CFG.Z_OVERLAY + 3,
		})
		S.header_status = status_lbl

		local CBTN = CFG.HEADER_H - 10
		local close_btn = dOS.create_gui_element(dOS, "ImageButton", {
			Parent = header,
			Image = CFG.CLOSE_BUTTON_ICON,
			Size = UDim2.fromOffset(CBTN, CBTN),
			Position = UDim2.new(1, -(CBTN + 6), 0.5, -(CBTN / 2)),
			BackgroundColor3 = Color3.fromRGB(200, 50, 40),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = CFG.Z_OVERLAY + 4,
		})
		if close_btn then
			dOS.create_gui_element(dOS, "UICorner", {
				Parent = close_btn,
				CornerRadius = UDim.new(0, 5),
			})
			close_btn.MouseButton1Click:Connect(function() M.close(dOS) end)
		end
	end

	local cards_h = OVH - CFG.HEADER_H - CFG.DOCK_H - 14
	local cards = dOS.create_gui_element(dOS, "ScrollingFrame", {
		Parent = ov,
		Name = "VDM_CardsScroll",
		Size = UDim2.new(1, -10, 0, cards_h),
		Position = UDim2.fromOffset(5, CFG.HEADER_H + 6),
		BackgroundTransparency = 1,
		ScrollBarThickness = CFG.SCROLL_BAR_W,
		ScrollBarImageColor3 = dOS.THEME.BORDER_HIGHLIGHT,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.fromOffset(0, 0),
		ZIndex = CFG.Z_CARD - 1,
		BorderSizePixel = 0,
	})
	S.cards_scroll = cards

	dOS.create_gui_element(dOS, "Frame", {
		Parent = ov,
		Name = "VDM_DockBG",
		Size = UDim2.new(1, 0, 0, CFG.DOCK_H),
		Position = UDim2.new(0, 0, 1, -CFG.DOCK_H),
		BackgroundColor3 = dOS.THEME.TITLE_BAR_BG,
		BackgroundTransparency = 0.10,
		BorderSizePixel = 0,
		ZIndex = CFG.Z_CARD - 2,
	})
	dOS.create_gui_element(dOS, "Frame", {
		Parent = ov,
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -CFG.DOCK_H),
		BackgroundColor3 = dOS.THEME.BORDER_HIGHLIGHT,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = CFG.Z_CARD - 1,
	})

	local dock = dOS.create_gui_element(dOS, "ScrollingFrame", {
		Parent = ov,
		Name = "VDM_DockScroll",
		Size = UDim2.new(1, 0, 0, CFG.DOCK_H),
		Position = UDim2.new(0, 0, 1, -CFG.DOCK_H),
		BackgroundTransparency = 1,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.fromOffset(0, 0),
		ZIndex = CFG.Z_CARD,
		BorderSizePixel = 0,
	})
	S.dock_scroll = dock

	local shield = dOS.create_gui_element(dOS, "TextButton", {
		Parent = ov,
		Name = "VDM_Shield",
		Text = "",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = CFG.Z_CAPTURE,
		Active = false,
		Visible = false,
	})
	S.capture_shield = shield
	if shield then shield.MouseButton1Up:Connect(function(mx, my) _resolve_drop(dOS, mx, my) end) end

	_redraw(dOS)

	local screen = dOS.screen :: any
	S._cursor_conn = screen.CursorMoved:Connect(function(c)
		if not _alive(S.overlay) then return end
		if S.cdrag.active and c.UserId == S.cdrag.uid and _alive(S.cdrag.ghost) then
			_set(S.cdrag.ghost, "Position", _ghost_pos(c.X, c.Y, CFG.CARD_W / 2, CFG.CARD_H / 2))
		end
		if S.tdrag.active and c.UserId == S.tdrag.uid and _alive(S.tdrag.ghost) then
			_set(S.tdrag.ghost, "Position", _ghost_pos(c.X, c.Y, CFG.TAB_W / 2, CFG.TAB_H / 2))
		end
	end)

	local ti_in = dOS.TweenInfo.new(CFG.T_OPEN, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	if scrim then pcall(function() dOS.Tween.new(scrim, { BackgroundTransparency = 0.48 }, ti_in):Play() end) end
	pcall(function() dOS.Tween.new(ov, { Position = UDim2.fromOffset(0, OVY) }, ti_in):Play() end)

	if accent then
		task.delay(
			CFG.T_OPEN * 0.6,
			function() _fluid(dOS, accent, { Size = UDim2.new(1, 0, 0, 2) }, CFG.T_OPEN * 0.45) end
		)
	end
end

function M.close(dOS)
	if not S.is_open then return end
	S.is_open = false

	_disc(S._cursor_conn)
	S._cursor_conn = nil

	_close_ctx(dOS)
	_stop_drags()

	local ov = S.overlay
	local scrim = S.scrim
	local sdims = dOS.screen_dimensions or Vector2.new(800, 600)
	local ti_out = dOS.TweenInfo.new(CFG.T_CLOSE, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

	if _alive(ov) then
		pcall(function() dOS.Tween.new(ov, { Position = UDim2.fromOffset(0, sdims.Y) }, ti_out):Play() end)
	end
	if _alive(scrim) then
		pcall(function() dOS.Tween.new(scrim, { BackgroundTransparency = 1 }, ti_out):Play() end)
	end

	S.overlay = nil
	S.scrim = nil
	S.cards_scroll = nil
	S.dock_scroll = nil
	S.capture_shield = nil
	S.ctx_dismiss = nil
	S.context = nil
	S.header_status = nil
	S.card_elems = {}
	S.active_screen_hw = nil
	S._last_dos = nil

	task.delay(CFG.T_CLOSE + 0.06, function()
		_destroy(ov)
		_destroy(scrim)
	end)
end

function M.switch_to_desktop(dOS, di)
	if not S.desktops[di] then
		warn("[VDM] switch_to_desktop: invalid di=" .. tostring(di))
		return
	end
	if di == S.active_di then return end

	S.active_di = di
	_apply_visibility(dOS)
	_update_status_label()

	if dOS.TaskbarManager then dOS.TaskbarManager.update_layout(dOS) end
	if S.is_open then
		S.preview_di = di
		task.spawn(_redraw, dOS)
	end
end

function M.create_desktop(dOS, name)
	if #S.desktops >= CFG.MAX_DESKTOPS then
		dOS.NotificationManager.push(
			dOS,
			"VDM",
			"Max desktop count reached.",
			dOS.NotificationManager.GENERIC_ICONS.ERROR,
			dOS.NotificationManager.GENERIC_ICONS.ERROR
		)
		return nil
	end

	local label = name or ("Desktop " .. (#S.desktops + 1))
	table.insert(S.desktops, _new_desktop(label))
	local new_di = #S.desktops

	M.switch_to_desktop(dOS, new_di)
	if S.is_open then
		S.preview_di = new_di
		task.spawn(_redraw, dOS)
	end
	return new_di
end

function M.delete_desktop(dOS, di)
	if #S.desktops <= 1 then return end
	if not S.desktops[di] then
		warn("[VDM] delete_desktop: invalid di=" .. tostring(di))
		return
	end

	local target = if di > 1 then di - 1 else 2
	for wf in pairs(S.desktops[di].windows) do
		if _alive(wf) then _assign(wf, target) end
	end
	table.remove(S.desktops, di)

	for wf, wdi in pairs(S.win_di) do
		if wdi > di then S.win_di[wf] = wdi - 1 end
	end

	if S.active_di > di then
		S.active_di -= 1
	elseif S.active_di == di then
		S.active_di = math.max(1, di - 1)
	end

	S.preview_di = math.clamp(if S.preview_di > di then S.preview_di - 1 else S.preview_di, 1, #S.desktops)
	_apply_visibility(dOS)
	_update_status_label()

	if dOS.TaskbarManager then dOS.TaskbarManager.update_layout(dOS) end
	if S.is_open then task.spawn(_redraw, dOS) end
end

function M.reorder(dOS, from_di, to_di)
	if from_di == to_di then return end
	if not (S.desktops[from_di] and S.desktops[to_di]) then
		warn("[VDM] reorder: invalid indices " .. from_di .. " -> " .. to_di)
		return
	end

	from_di = math.clamp(from_di, 1, #S.desktops)
	to_di = math.clamp(to_di, 1, #S.desktops)

	local desktop = table.remove(S.desktops, from_di)
	table.insert(S.desktops, to_di, desktop)

	local new_map = {}
	for wf, wdi in pairs(S.win_di) do
		if wdi == from_di then
			new_map[wf] = to_di
		elseif from_di < to_di and wdi > from_di and wdi <= to_di then
			new_map[wf] = wdi - 1
		elseif from_di > to_di and wdi >= to_di and wdi < from_di then
			new_map[wf] = wdi + 1
		else
			new_map[wf] = wdi
		end
	end
	S.win_di = new_map

	local function remap(idx)
		if idx == from_di then return to_di end
		if from_di < to_di and idx > from_di and idx <= to_di then return idx - 1 end
		if from_di > to_di and idx >= to_di and idx < from_di then return idx + 1 end
		return idx
	end

	S.active_di = remap(S.active_di)
	S.preview_di = remap(S.preview_di)

	_stop_drags()
	if S.is_open then task.spawn(_redraw, dOS) end
end

function M.move_window(dOS, win_frame, target_di)
	if not _alive(win_frame) then return end
	if not S.desktops[target_di] then
		warn("[VDM] move_window: invalid target_di=" .. tostring(target_di))
		return
	end

	local src_di = S.win_di[win_frame]
	if src_di == target_di then return end

	_assign(win_frame, target_di)

	local meta = dOS.window_metadata and dOS.window_metadata[win_frame]
	if meta and not meta.is_minimized then _set(win_frame, "Visible", target_di == S.active_di) end

	local desk = S.desktops[target_di]
	dOS.NotificationManager.push(
		dOS,
		"VDM",
		"Moved to " .. (if desk then desk.name else "Desktop " .. target_di),
		dOS.NotificationManager.GENERIC_ICONS.INFO_GENERIC,
		dOS.NotificationManager.GENERIC_SFX.INFO_GENERIC
	)

	if S.is_open then task.spawn(_redraw, dOS) end
	if dOS.TaskbarManager and dOS.TaskbarManager.update_layout then dOS.TaskbarManager.update_layout(dOS) end
end

function M.create_taskbar_button(dOS)
	if not dOS then
		warn("[VDM] create_taskbar_button: nil dOS")
		return
	end
	if not _alive(dOS.taskbar_frame) then
		warn("[VDM] create_taskbar_button: taskbar_frame not ready")
		return
	end

	S.taskbar_btns = S.taskbar_btns or {}
	if S.taskbar_btns[dOS.taskbar_frame] and _alive(S.taskbar_btns[dOS.taskbar_frame]) then return end

	local tm_state = dOS.TaskbarManager and dOS.TaskbarManager.taskbar_manager
	local btn_pos = (tm_state and tm_state.vdm_btn_pos) or UDim2.new(0, (dOS.shared.START_W or 350) + 4, 0.5, -14)
	local btn_size = (tm_state and tm_state.vdm_btn_size) or UDim2.fromOffset(36, 28)

	local btn = dOS.create_gui_element(dOS, "ImageButton", {
		Parent = dOS.taskbar_frame,
		Name = "VDM_TaskbarBtn",
		Image = CFG.TASKBAR_ICON,
		ScaleType = Enum.ScaleType.Tile,
		Size = btn_size,
		Position = btn_pos,
		BackgroundColor3 = dOS.THEME.TITLE_BAR_BG,
		BorderSizePixel = 0,
		ZIndex = (dOS.Z_INDEX["WINDOW_ACTIVE"] or 10) + 1,
	})
	if not btn then
		warn("[VDM] create_taskbar_button: failed to create button")
		return
	end

	dOS.create_gui_element(dOS, "UICorner", { Parent = btn, CornerRadius = UDim.new(0, 5) })
	dOS.HoverManager.register(btn, {
		HoverColor = dOS.THEME.ACCENT_BUTTON_BG,
		BackgroundColor3 = dOS.THEME.TITLE_BAR_BG,
	})

	btn.MouseButton1Click:Connect(function()
		if S.is_open then
			if S.active_screen_hw and S.active_screen_hw ~= dOS.screen then
				M.open(dOS)
			else
				M.close(dOS)
			end
		else
			M.open(dOS)
		end
	end)

	S.taskbar_btns[dOS.taskbar_frame] = btn
end

function M.reset(dOS)
	_disc(S._cursor_conn)
	S._cursor_conn = nil

	local stored_dos = S._init_dos
	local d = dOS or stored_dos
	if d then
		if S._orig_create then
			pcall(function() d.create_basic_window = S._orig_create end)
		end
		if S._orig_unmin then
			pcall(function() d.Window.handle_unminimize_window = S._orig_unmin end)
		end
	end

	S.overlay = nil
	S.scrim = nil
	S.cards_scroll = nil
	S.dock_scroll = nil
	S.capture_shield = nil
	S.ctx_dismiss = nil
	S.context = nil
	S.header_status = nil

	if S.taskbar_btns then
		for _, b in pairs(S.taskbar_btns) do
			_destroy(b)
		end
	end

	S.taskbar_btns = {}
	S.active_screen_hw = nil
	S._last_dos = nil
	S.card_elems = {}

	S.cdrag = { active = false, win_frame = nil, uid = nil, ghost = nil }
	S.tdrag = { active = false, from_di = nil, uid = nil, ghost = nil }

	S.is_open = false
	S._last_ctx_t = 0
	S._last_open_t = 0

	S.desktops = { _new_desktop("Desktop 1") }
	S.active_di = 1
	S.preview_di = 1
	S.win_di = {}

	S._init_dos = nil
	S._orig_create = nil
	S._orig_unmin = nil
end

function M.init(dOS)
	if not dOS then
		warn("[VDM] init() called with nil dOS")
		return
	end
	if not dOS.screen then
		warn("[VDM] init() called before screen is ready")
		return
	end

	S._init_dos = dOS

	dOS.VDM = M

	if #S.desktops == 0 then table.insert(S.desktops, _new_desktop("Desktop 1")) end

	if dOS.all_windows then
		for _, wf in ipairs(dOS.all_windows) do
			if not S.win_di[wf] and _alive(wf) then _track_window(wf) end
		end
	end

	local orig_create = dOS.create_basic_window
	S._orig_create = orig_create
	dOS.create_basic_window = function(...)
		local wf, ca = orig_create(...)
		if wf then _track_window(wf) end
		return wf, ca
	end

	local orig_unmin = dOS.Window.handle_unminimize_window
	S._orig_unmin = orig_unmin
	dOS.Window.handle_unminimize_window = function(d, wf)
		local di = wf and S.win_di[wf]
		if di and di ~= S.active_di then
			S.active_di = di
			_apply_visibility(d)
			_update_status_label()
		end
		orig_unmin(d, wf)
	end

	print("[VDM] Virtual Desktop Manager initialized.")
end

function M.on_dwm_ready(dOS)
	if S._init_dos then return end

	M.init(dOS)
	M.create_taskbar_button(dOS)
end

return M

-- EOF