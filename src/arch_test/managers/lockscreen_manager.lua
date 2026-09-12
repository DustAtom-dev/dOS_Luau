--[[
    "LockScreen manager module for dOS"
    
    @module lockscreen_manager
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

--- CONST
local LOCKSCREEN_ANIM_DURATION = 0.65
local CURSOR_HOVER_DURATION = 2.5
local CURSOR_BOX_SIZE = 100

local ICON_IDS = {
	KEY = 14565902150,
	CURSOR = 133564765934536,
	CD = 78038742680517,
}

M.lockscreen_state = {
	is_locked = false,
	container = nil,
	background_image = nil,
	dark_overlay = nil,

	clock_hours = nil,
	clock_colon = nil,
	clock_minutes = nil,
	date_label = nil,

	password_container = nil,
	user_avatar = nil,
	password_dots_label = nil,
	clear_password_btn = nil,

	auth_data = {
		keyboard_password_hash = nil,
		cursor_id = nil,
		disk_secret_key = nil,
		disk_device_path = nil,
	},

	connections = {},
	secondary_overlays = {},
	keyboard_buffer = "",
	is_password_phase = false,
	selected_method = "password", -- "password", "cursor", "disk"
}

function M.init(dOS)
	M.lockscreen_state.auth_data = {
		keyboard_password_hash = nil,
		cursor_id = nil,
		disk_secret_key = nil,
		disk_device_path = nil,
	}
	M.load_auth_data(dOS)
	print("[LockScreen] Initialized")
end

function M.load_auth_data(dOS)
	if not dOS.disk then
		return
	end

	local success, data_str = pcall(dOS.disk.Read, dOS.disk, "/dOS_lockscreen_auth.json")
	if success then
		if not data_str then
			return
		end

		local checksum = data_str:match("|(.*)")
		local to_decode = data_str:match("(.*)|.*")

		if dOS.SHA256.hash(to_decode) == checksum then
			local decode_success, auth_data = pcall(JSONDecode, to_decode)
			if decode_success then
				M.lockscreen_state.auth_data = auth_data
				print("[LockScreen] Auth data loaded")
			else
				warn(`[LockScreen] LOAD_ERROR: Unable to load auth data. JSONDecode error: '{auth_data}'.`)
			end
		else
			warn("[LockScreen] LOAD_ERROR: Unable to load auth data. Data corrupt or tampered.")
		end
	else
		warn(`[LockScreen] LOAD_ERROR: Unable to load auth data: Disk Read unhandled exception. Error: '{data_str}'`)
	end
end

function M.save_auth_data(dOS)
	if not dOS.disk then
		return
	end

	local json_str, jerr = JSONEncode(M.lockscreen_state.auth_data)

	if json_str then
		local s, werr =
			pcall(dOS.disk.Write, dOS.disk, "/dOS_lockscreen_auth.json", `{json_str}|{dOS.SHA256.hash(json_str)}`)
		if s then
			print("[LockScreen] Auth data saved.")
		else
			warn(`[LockScreen] SAVE_ERROR: Unable to save auth data: Disk Write unhandled exception. Error: '{werr}'.`)
		end
	else
		warn(`[LockScreen] SAVE_ERROR: Unable to save auth data: JSONEncode unhandled exception. Error: '{jerr}'.`)
	end
end

function M.update_secondary_overlays(dOS)
	if not M.lockscreen_state.is_locked then
		return
	end

	M.lockscreen_state.secondary_overlays = M.lockscreen_state.secondary_overlays or {}
	if not dOS.DWM then
		return
	end

	for _, sec_overlay in ipairs(M.lockscreen_state.secondary_overlays) do
		if sec_overlay and sec_overlay.Parent then
			pcall(function()
				sec_overlay:Destroy()
			end)
		end
	end
	M.lockscreen_state.secondary_overlays = {}

	dOS.DWM.broadcast(dOS, function(ctx, proxy)
		if ctx.is_primary then
			return
		end

		local overlay = dOS.create_gui_element(proxy, "Frame", {
			Name = "LockScreen_Secondary_S" .. ctx.id,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0,
			ZIndex = dOS.Z_INDEX.LOCKSCREEN,
			BorderSizePixel = 0,
		})
		if not overlay then
			return
		end

		dOS.create_gui_element(proxy, "TextLabel", {
			Parent = overlay,
			Text = "Screen Locked",
			TextColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			TextSize = 24,
			Font = dOS.FONT_BOLD,
			ZIndex = dOS.Z_INDEX.LOCKSCREEN + 1,
		})
		table.insert(M.lockscreen_state.secondary_overlays, overlay)
	end)
end

function M.show_lock_screen(dOS)
	if M.lockscreen_state.is_locked then
		return
	end

	M.lockscreen_state.is_locked = true
	M.lockscreen_state.is_password_phase = false
	dOS.shared.LOCKSCREEN_aes_running = false

	-- container
	M.lockscreen_state.container = dOS.create_gui_element(dOS, "Frame", {
		Parent = dOS.screen,
		Name = "LockScreenContainer",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = dOS.THEME.LOCKSCREEN_BG,
		BorderSizePixel = 0,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN,
	})

	-- TODO: handle lock screen on secondary displays instead of a black overlay
	M.lockscreen_state.secondary_overlays = {}
	if dOS.DWM then
		M.update_secondary_overlays(dOS)
	end

	local img = dOS.os_settings.lockscreen_bg_img_id
	M.lockscreen_state.background_image = dOS.create_gui_element(
		dOS,
		"ImageLabel",
		{
			Parent = M.lockscreen_state.container,
			Size = UDim2.fromScale(1, 1),
			Image = if not img or img == 0 then
				dOS.os_settings.desktop_bg_img_id
			else img,
			ScaleType = dOS.os_settings.lockscreen_scale_type
				or Enum.ScaleType.Crop,
			BackgroundColor3 = dOS.THEME.WINDOW_BG,
			BorderSizePixel = 0,
			ZIndex = dOS.Z_INDEX.LOCKSCREEN + 1,
		}
	)

	M.lockscreen_state.dark_overlay = dOS.create_gui_element(dOS, "RealFrame", {
		Parent = M.lockscreen_state.container,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 2,
	})

	local clock_container = dOS.create_gui_element(dOS, "Frame", {
		Parent = M.lockscreen_state.container,
		Size = UDim2.fromScale(1, 0.4),
		Position = UDim2.fromScale(0, 0.3),
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 3,
	})

	local time_frame = dOS.create_gui_element(dOS, "Frame", {
		Parent = clock_container,
		Size = UDim2.fromOffset(400, 120),
		Position = UDim2.new(0.5, -200, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 3,
	})

	M.lockscreen_state.clock_hours = dOS.create_gui_element(dOS, "TextLabel", {
		Parent = time_frame,
		Size = UDim2.fromScale(0.4, 1),
		Position = UDim2.fromScale(0, 0),
		Text = tonumber(os.date("%I")),
		TextSize = 80,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 3,
	})

	M.lockscreen_state.clock_colon = dOS.create_gui_element(dOS, "TextLabel", {
		Parent = time_frame,
		Size = UDim2.fromScale(0.2, 1),
		Position = UDim2.fromScale(0.4, 0),
		Text = ":",
		TextSize = 80,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 3,
	})

	M.lockscreen_state.clock_minutes = dOS.create_gui_element(dOS, "TextLabel", {
		Parent = time_frame,
		Size = UDim2.fromScale(0.4, 1),
		Position = UDim2.fromScale(0.6, 0),
		Text = tonumber(os.date("%M")),
		TextSize = 80,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 3,
	})

	M.lockscreen_state.date_label = dOS.create_gui_element(dOS, "TextLabel", {
		Parent = clock_container,
		Size = UDim2.fromScale(1, 0.2),
		Position = UDim2.fromScale(0, 0.7),
		Text = os.date("%A, %B %d"),
		TextSize = 18,
		Font = Enum.Font.Gotham,
		TextColor3 = Color3.fromRGB(240, 240, 240),
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 3,
	})

	local hint_container = dOS.create_gui_element(dOS, "Frame", {
		Parent = M.lockscreen_state.container,
		Size = UDim2.fromOffset(300, 60),
		Position = UDim2.new(0.5, -150, 0.85, 0),
		BackgroundColor3 = dOS.THEME.LOCKSCREEN_CARD_BG,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 2,
	})

	dOS.create_gui_element(dOS, "UICorner", {
		Parent = hint_container,
		CornerRadius = UDim.new(0, 12),
	})

	local hint_label = dOS.create_gui_element(dOS, "TextLabel", {
		Parent = hint_container,
		Size = UDim2.fromScale(1, 1),
		Text = "Press Enter or click to unlock",
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = Color3.fromRGB(220, 220, 220),
		BackgroundTransparency = 1,
		TextTransparency = 0.3,
	})

	-- pulse for hint
	task.spawn(function()
		while
			M.lockscreen_state.is_locked
			and not M.lockscreen_state.is_password_phase
			and hint_label
			and hint_label.Parent
		do
			dOS.Tween
				.new(hint_label, {
					TextTransparency = 0,
				}, dOS.TweenInfo.new(
					1.5,
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut
				))
				:Play()

			task.wait(1.5)

			if
				not M.lockscreen_state.is_locked
				or M.lockscreen_state.is_password_phase
			then
				break
			end

			dOS.Tween
				.new(hint_label, {
					TextTransparency = 0.5,
				}, dOS.TweenInfo.new(
					1.5,
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut
				))
				:Play()

			task.wait(1.5)
		end
	end)

	local clock_thread = task.spawn(function()
		while
			M.lockscreen_state.is_locked
			and M.lockscreen_state.clock_hours
			and M.lockscreen_state.clock_hours.Parent
		do
			if M.lockscreen_state.clock_hours then
				local current_hours = tonumber(os.date("%I"))
				local current_minutes = tonumber(os.date("%M"))

				if M.lockscreen_state.clock_hours.Text ~= current_hours then
					M.lockscreen_state.clock_hours.Text = current_hours
				end

				if M.lockscreen_state.clock_minutes.Text ~= current_minutes then
					M.lockscreen_state.clock_minutes.Text = current_minutes
				end

				M.lockscreen_state.date_label.Text = os.date("%A, %B %d")
			end

			local seconds_until_next_minute = 60 - (tonumber(os.date("%S")) or 0)
			task.wait(seconds_until_next_minute)
		end
	end)
	M.lockscreen_state.connections["clock_thread"] = clock_thread

	-- TODO: fix that it does not work instantly and sometimes not at all
	local click_detector = dOS.create_gui_element(dOS, "TextButton", {
		Parent = M.lockscreen_state.container,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 1,
	})

	local click_conn = click_detector.MouseButton1Click:Connect(function()
		if not M.lockscreen_state.is_password_phase then
			M.transition_to_password_phase(dOS)
		end
	end)
	M.lockscreen_state.connections["click"] = click_conn

	-- this works if the click detector is broken
	local enter_conn = dOS.keyboard.TextInputted:Connect(function(text)
		if text == "\n" and not M.lockscreen_state.is_password_phase then
			M.transition_to_password_phase(dOS)
		end
	end)
	M.lockscreen_state.connections["enter"] = enter_conn

	-- ~~animations!!!~~
	M.lockscreen_state.container.BackgroundTransparency = 1
	M.lockscreen_state.background_image.ImageTransparency = 1
	M.lockscreen_state.clock_hours.TextTransparency = 1
	M.lockscreen_state.clock_colon.TextTransparency = 1
	M.lockscreen_state.clock_minutes.TextTransparency = 1
	M.lockscreen_state.date_label.TextTransparency = 1
	hint_container.BackgroundTransparency = 1
	hint_label.TextTransparency = 1

	dOS.Tween
		.new(M.lockscreen_state.container, {
			BackgroundTransparency = 0,
		}, dOS.TweenInfo.new(
			LOCKSCREEN_ANIM_DURATION,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.Out
		))
		:Play()

	dOS.Tween
		.new(M.lockscreen_state.background_image, {
			ImageTransparency = 0,
		}, dOS.TweenInfo.new(
			LOCKSCREEN_ANIM_DURATION,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.Out
		))
		:Play()

	local text_anim_duration = LOCKSCREEN_ANIM_DURATION * 1.2

	dOS.Tween
		.new(M.lockscreen_state.clock_hours, {
			TextTransparency = 0,
		}, dOS.TweenInfo.new(
			text_anim_duration,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.Out,
			0.1
		))
		:Play()

	dOS.Tween
		.new(M.lockscreen_state.clock_colon, {
			TextTransparency = 0,
		}, dOS.TweenInfo.new(
			text_anim_duration,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.Out,
			0.15
		))
		:Play()

	dOS.Tween
		.new(M.lockscreen_state.clock_minutes, {
			TextTransparency = 0,
		}, dOS.TweenInfo.new(
			text_anim_duration,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.Out,
			0.2
		))
		:Play()

	dOS.Tween
		.new(M.lockscreen_state.date_label, {
			TextTransparency = 0,
		}, dOS.TweenInfo.new(
			text_anim_duration * 1.2,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.Out,
			0.3
		))
		:Play()

	dOS.Tween
		.new(hint_container, {
			BackgroundTransparency = 0.8,
		}, dOS.TweenInfo.new(
			text_anim_duration,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.Out,
			0.4
		))
		:Play()

	dOS.Tween
		.new(hint_label, {
			TextTransparency = 0.3,
		}, dOS.TweenInfo.new(
			text_anim_duration,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.Out,
			0.5
		))
		:Play()

	task.wait(text_anim_duration)
	task.wait()

	print("[LockScreen] Lock screen shown")
end

function M.transition_to_password_phase(dOS)
	if M.lockscreen_state.is_password_phase then
		return
	end

	M.lockscreen_state.is_password_phase = true

	-- TODO: find a way to do blur
	dOS.Tween
		.new(M.lockscreen_state.dark_overlay, {
			BackgroundTransparency = 0.5,
		}, dOS.TweenInfo.new(
			LOCKSCREEN_ANIM_DURATION,
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.Out
		))
		:Play()

	dOS.Tween
		.new(
			M.lockscreen_state.clock_hours.Parent,
			{
				-- 380/2: password_containerY/2 because clock already centered
				Position = UDim2.new(0.5, -200, 0, -(380 / 2)),
			},
			dOS.TweenInfo.new(
				LOCKSCREEN_ANIM_DURATION * 1.5 + LOCKSCREEN_ANIM_DURATION * 0.3,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			)
		)
		:Play()

	task.delay(LOCKSCREEN_ANIM_DURATION * 0.3, function()
		M.create_password_ui(dOS)
	end)
end

function M.create_password_ui(dOS)
	M.lockscreen_state.password_container = dOS.create_gui_element(dOS, "Frame", {
		Parent = M.lockscreen_state.container,
		Size = UDim2.fromOffset(380, 420),
		Position = UDim2.new(0.5, -190, 1, 0), -- below screen
		BackgroundColor3 = dOS.THEME.LOCKSCREEN_CARD_BG,
		BorderSizePixel = 0,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 5,
	})

	dOS.create_gui_element(dOS, "UICorner", {
		Parent = M.lockscreen_state.password_container,
		CornerRadius = UDim.new(0, 16),
	})

	dOS.create_gui_element(dOS, "UIStroke", {
		Parent = M.lockscreen_state.password_container,
		Color = dOS.THEME.LOCKSCREEN_CARD_BORDER,
		Thickness = 1,
		Transparency = 0.5,
	})

	if M.lockscreen_state.auth_data.keyboard_password_hash then
		M.lockscreen_state.selected_method = "password"
	elseif M.lockscreen_state.auth_data.cursor_id then
		M.lockscreen_state.selected_method = "cursor"
	elseif M.lockscreen_state.auth_data.disk_secret_key then
		M.lockscreen_state.selected_method = "disk"
	else
		M.lockscreen_state.selected_method = "none"
	end

	M.render_password_method(dOS)

	dOS.Tween
		.new(M.lockscreen_state.password_container, {
			Position = UDim2.new(0.5, -190, 0.5, -210),
		}, dOS.TweenInfo.new(
			LOCKSCREEN_ANIM_DURATION,
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.Out
		))
		:Play()
end

function M.render_password_method(dOS)
	for _, child in ipairs(M.lockscreen_state.password_container:GetChildren()) do
		if child.Name ~= "UICorner" and child.Name ~= "UIStroke" then
			child:Destroy()
		end
	end

	M.lockscreen_state.keyboard_buffer = ""

	local header = dOS.create_gui_element(dOS, "Frame", {
		Parent = M.lockscreen_state.password_container,
		Size = UDim2.new(1, 0, 0, 110),
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 6,
	})

	M.lockscreen_state.user_avatar = dOS.create_gui_element(dOS, "Frame", {
		Parent = header,
		Size = UDim2.fromOffset(70, 70),
		Position = UDim2.new(0.5, -35, 0, 10),
		BackgroundColor3 = dOS.THEME.LOCKSCREEN_INPUT_BG,
		BorderSizePixel = 0,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 6,
	})

	dOS.create_gui_element(dOS, "UICorner", {
		Parent = M.lockscreen_state.user_avatar,
		CornerRadius = UDim.new(1, 0),
	})

	dOS.create_gui_element(dOS, "TextLabel", {
		Parent = M.lockscreen_state.user_avatar,
		Size = UDim2.fromScale(1, 1),
		Text = string.sub(dOS.os_settings.owner_username or "U", 1, 1):upper(),
		TextSize = 32,
		Font = dOS.FONT_BOLD,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 7,
	})

	dOS.create_gui_element(dOS, "TextLabel", {
		Parent = header,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 85),
		Text = dOS.os_settings.owner_username or "User",
		TextSize = 18,
		Font = dOS.FONT_BOLD,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 6,
	})

	local content = dOS.create_gui_element(dOS, "Frame", {
		Parent = M.lockscreen_state.password_container,
		Size = UDim2.new(1, -40, 0, 230),
		Position = UDim2.fromOffset(20, 120),
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 6,
	})

	if M.lockscreen_state.selected_method == "password" then
		M.render_password_input(dOS, content)
	elseif M.lockscreen_state.selected_method == "cursor" then
		M.render_cursor_input(dOS, content)
	elseif M.lockscreen_state.selected_method == "disk" then
		M.render_disk_input(dOS, content)
	else
		M.render_no_methods(dOS, content)
	end

	M.render_method_selector(dOS)
end

local function show_verification_animation(dOS, parent)
	local overlay = dOS.create_gui_element(dOS, "Frame", {
		Parent = parent,
		Name = "VerificationOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 10,
	})

	dOS.Tween
		.new(overlay, {
			BackgroundTransparency = 0.6,
		}, dOS.TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
		:Play()

	local loading_card = dOS.create_gui_element(dOS, "Frame", {
		Parent = overlay,
		Size = UDim2.fromOffset(200, 200),
		Position = UDim2.new(0.5, -100, 0.5, -100),
		BackgroundColor3 = dOS.THEME.LOCKSCREEN_CARD_BG,
		BorderSizePixel = 0,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 11,
		ClipsDescendants = true,
	})

	dOS.create_gui_element(dOS, "UICorner", {
		Parent = loading_card,
		CornerRadius = UDim.new(0, 20),
	})

	dOS.create_gui_element(dOS, "UIStroke", {
		Parent = loading_card,
		Color = dOS.THEME.LOCKSCREEN_CARD_BORDER,
		Thickness = 2,
		Transparency = 0.3,
	})

	local spinner_container = dOS.create_gui_element(dOS, "Frame", {
		Parent = loading_card,
		Size = UDim2.fromOffset(80, 80),
		Position = UDim2.new(0.5, -40, 0.5, -55),
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 12,
	})

	local arc_colors = {
		dOS.THEME.LOCKSCREEN_BUTTON_PRIMARY,
		Color3.fromRGB(100, 150, 255),
		Color3.fromRGB(80, 120, 200),
	}

	local arcs = {}
	for i = 1, 3 do
		local arc = dOS.create_gui_element(dOS, "Frame", {
			Parent = spinner_container,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0, 0),
			BackgroundTransparency = 1,
			Rotation = (i - 1) * 120,
			ZIndex = dOS.Z_INDEX.LOCKSCREEN + 12,
		})

		local segment = dOS.create_gui_element(dOS, "Frame", {
			Parent = arc,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = arc_colors[i],
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			ZIndex = dOS.Z_INDEX.LOCKSCREEN + 12,
		})

		dOS.create_gui_element(dOS, "RealUICorner", {
			Parent = segment,
			CornerRadius = UDim.new(1, 0),
		})

		dOS.create_gui_element(dOS, "UIGradient", {
			Parent = segment,
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 0.3),
				NumberSequenceKeypoint.new(0.7, 0.3),
				NumberSequenceKeypoint.new(1, 1),
			}),
		})

		table.insert(arcs, arc)
	end

	-- """glow"""
	local glow = dOS.create_gui_element(dOS, "Frame", {
		Parent = spinner_container,
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(0.5, -20, 0.5, -20),
		BackgroundColor3 = dOS.THEME.LOCKSCREEN_BUTTON_PRIMARY,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 13,
	})

	dOS.create_gui_element(dOS, "RealUICorner", {
		Parent = glow,
		CornerRadius = UDim.new(1, 0),
	})

	dOS.create_gui_element(dOS, "TextLabel", { -- verify_text
		Parent = loading_card,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 130),
		Text = "Verifying...",
		TextWrapped = false,
		TextSize = 16,
		Font = dOS.FONT_BOLD,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 12,
	})

	local wait_text = dOS.create_gui_element(dOS, "TextLabel", {
		Parent = loading_card,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 160),
		Text = "Please wait",
		TextWrapped = false,
		TextSize = 14,
		Font = dOS.FONT_REGULAR,
		TextColor3 = Color3.fromRGB(200, 200, 200),
		BackgroundColor3 = dOS.THEME.LOCKSCREEN_WAIT_TEXT_BG,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 12,
	})

	loading_card.Size = UDim2.fromOffset(0, 0)
	dOS.Tween
		.new(loading_card, {
			Size = UDim2.fromOffset(200, 200),
		}, dOS.TweenInfo.new(
			0.35,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		))
		:Play()

	local rotation_thread = task.spawn(function()
		while overlay and overlay.Parent do
			for i, arc in ipairs(arcs) do
				dOS.Tween
					.new(arc, {
						Rotation = arc.Rotation + 360,
					}, dOS.TweenInfo.new(
						1.5 - (i * 0.2),
						Enum.EasingStyle.Linear,
						Enum.EasingDirection.Out
					))
					:Play()
			end

			task.wait(1.5)
		end
	end)

	local glow_thread = task.spawn(function()
		while overlay and overlay.Parent do
			dOS.Tween
				.new(glow, {
					Size = UDim2.fromOffset(50, 50),
					Position = UDim2.new(0.5, -25, 0.5, -25),
					BackgroundTransparency = 0.5,
				}, dOS.TweenInfo.new(
					0.8,
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut
				))
				:Play()

			task.wait(0.8)

			if not (overlay and overlay.Parent) then
				break
			end

			dOS.Tween
				.new(glow, {
					Size = UDim2.fromOffset(40, 40),
					Position = UDim2.new(0.5, -20, 0.5, -20),
					BackgroundTransparency = 0.7,
				}, dOS.TweenInfo.new(
					0.8,
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut
				))
				:Play()

			task.wait(0.8)
		end
	end)

	-- animated dots
	local wait_text_thread = task.spawn(function()
		while overlay and overlay.Parent do
			dOS.Tween
				.new(wait_text, {
					TextTransparency = 0.5,
				}, dOS.TweenInfo.new(
					1,
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut
				))
				:Play()

			task.wait(1)

			if not (overlay and overlay.Parent) then
				break
			end

			dOS.Tween
				.new(wait_text, {
					TextTransparency = 0,
				}, dOS.TweenInfo.new(
					1,
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut
				))
				:Play()

			task.wait(1)
		end
	end)

	return overlay,
		function()
			-- cleanup
			if rotation_thread then
				task.cancel(rotation_thread)
			end

			if glow_thread then
				task.cancel(glow_thread)
			end

			if wait_text_thread then
				task.cancel(wait_text_thread)
			end

			dOS.Tween
				.new(loading_card, {
					Size = UDim2.fromOffset(0, 0),
				}, dOS.TweenInfo.new(
					0.25,
					Enum.EasingStyle.Back,
					Enum.EasingDirection.In
				))
				:Play()

			dOS.Tween
				.new(overlay, {
					BackgroundTransparency = 1,
				}, dOS.TweenInfo.new(
					0.25,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				))
				:Play()

			task.delay(0.25, function()
				if overlay and overlay.Parent then
					overlay:Destroy()
				end
			end)
		end
end

function M.render_password_input(dOS, parent)
	dOS.create_gui_element(dOS, "TextLabel", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 0),
		Text = "Enter your password",
		TextSize = 14,
		Font = dOS.FONT_REGULAR,
		TextColor3 = Color3.fromRGB(200, 200, 200),
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 6,
	})

	local password_field = dOS.create_gui_element(dOS, "Frame", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.fromOffset(0, 35),
		BackgroundColor3 = dOS.THEME.LOCKSCREEN_INPUT_BG,
		BorderSizePixel = 0,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 6,
	})

	dOS.create_gui_element(dOS, "UICorner", {
		Parent = password_field,
		CornerRadius = UDim.new(0, 8),
	})

	dOS.create_gui_element(dOS, "UIStroke", {
		Parent = password_field,
		Color = dOS.THEME.LOCKSCREEN_CARD_BORDER,
		Thickness = 1,
		Transparency = 0.5,
	})

	M.lockscreen_state.password_dots_label = dOS.create_gui_element(
		dOS,
		"TextLabel",
		{
			Parent = password_field,
			Size = UDim2.new(1, -80, 1, 0),
			Position = UDim2.fromOffset(15, 0),
			Text = "",
			TextSize = 18,
			Font = dOS.FONT_REGULAR,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			ZIndex = dOS.Z_INDEX.LOCKSCREEN + 7,
		}
	)

	M.lockscreen_state.clear_password_btn = dOS.create_gui_element(dOS, "TextButton", {
		Parent = password_field,
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -38, 0.5, -14),
		Text = "X",
		TextSize = 14,
		Font = dOS.FONT_BOLD,
		TextColor3 = Color3.fromRGB(180, 180, 180),
		BackgroundColor3 = Color3.fromRGB(60, 60, 70),
		BorderSizePixel = 0,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 7,
		OnClick = function()
			M.lockscreen_state.keyboard_buffer = ""
			M.update_password_dots(dOS)
		end,
	})

	dOS.create_gui_element(dOS, "UICorner", {
		Parent = M.lockscreen_state.clear_password_btn,
		CornerRadius = UDim.new(1, 0),
	})

	local status_label = dOS.create_gui_element(dOS, "TextLabel", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 95),
		Text = "",
		TextSize = 13,
		Font = dOS.FONT_REGULAR,
		TextColor3 = dOS.THEME.LOCKSCREEN_ERROR,
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 6,
	})

	local function on_enter_clicked()
		if M.lockscreen_state.keyboard_buffer == "" or dOS.shared.LOCKSCREEN_aes_running then
			return
		end

		dOS.shared.LOCKSCREEN_aes_running = true

		-- _: verification_overlay
		local _, cleanup_animation = show_verification_animation(
			dOS,
			M.lockscreen_state.password_container
		)

		task.wait(0.1)

		local password = string.gsub(
			M.lockscreen_state.keyboard_buffer,
			"\n",
			""
		)
		local is_valid = dOS.Hasher.verify(
			dOS,
			password,
			M.lockscreen_state.auth_data.keyboard_password_hash
		)

		cleanup_animation()

		if is_valid then
			status_label.Text = ""
			M.lockscreen_state.keyboard_buffer = ""
			task.wait(0.3)
			M.unlock(dOS)
		else
			status_label.Text = "Incorrect password. Try again."
			M.lockscreen_state.keyboard_buffer = ""
			M.update_password_dots(dOS)

			-- shake animation
			local original_pos = password_field.Position
			for i = 1, 6 do
				dOS.Tween
					.new(password_field, {
						Position = original_pos + UDim2.fromOffset(i % 2 == 0 and -10 or 10, 0),
					}, dOS.TweenInfo.new(0.15, Enum.EasingStyle.Linear, Enum.EasingDirection.Out))
					:Play()

				task.wait(0.15)
			end

			dOS.Tween
				.new(password_field, {
					Position = original_pos,
				}, dOS.TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
				:Play()
		end

		dOS.shared.LOCKSCREEN_aes_running = false
	end

	local enter_btn = dOS.create_gui_element(dOS, "TextButton", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 135),
		Text = "Unlock",
		TextSize = 15,
		Font = dOS.FONT_BOLD,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundColor3 = dOS.THEME.LOCKSCREEN_BUTTON_PRIMARY,
		BorderSizePixel = 0,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 6,
		OnClick = on_enter_clicked,
	})

	dOS.create_gui_element(dOS, "UICorner", {
		Parent = enter_btn,
		CornerRadius = UDim.new(0, 8),
	})

	local keyboard_conn = dOS.keyboard.TextInputted:Connect(function(text)
		if text == "\n" then
			on_enter_clicked()
			return
		end

		if text:match("^[%c]$") and text ~= "\n" then
			return
		end

		text = string.sub(text, 1, -2)

		if #text < 50 then
			M.lockscreen_state.keyboard_buffer = text
			M.update_password_dots(dOS)
			status_label.Text = ""
		end
	end)

	M.lockscreen_state.connections["password_keyboard"] = keyboard_conn
	M.update_password_dots(dOS)
end

function M.update_password_dots(dOS)
	if not M.lockscreen_state.password_dots_label then
		return
	end

	local dots = string.rep("●", #M.lockscreen_state.keyboard_buffer)
	M.lockscreen_state.password_dots_label.Text = dots

	if M.lockscreen_state.clear_password_btn then
		M.lockscreen_state.clear_password_btn.Visible =
			#M.lockscreen_state.keyboard_buffer > 0

		if #M.lockscreen_state.keyboard_buffer > 0 then
			dOS.Tween
				.new(M.lockscreen_state.clear_password_btn, {
					TextColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundColor3 = Color3.fromRGB(80, 80, 90),
				}, dOS.TweenInfo.new(
					0.2,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				))
				:Play()
		end
	end
end

function M.render_cursor_input(dOS, parent)
	dOS.create_gui_element(dOS, "TextLabel", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 0),
		Text = "Hover your cursor in the box below",
		TextSize = 14,
		Font = dOS.FONT_REGULAR,
		TextColor3 = Color3.fromRGB(200, 200, 200),
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 6,
	})

	local hover_start_time = nil
	local progress_bar
	local active_progress_tween = nil
	local cursor_box

	cursor_box = dOS.create_gui_element(dOS, "Frame", {
		Parent = parent,
		Size = UDim2.fromOffset(CURSOR_BOX_SIZE, CURSOR_BOX_SIZE),
		Position = UDim2.new(0.5, -CURSOR_BOX_SIZE / 2, 0, 45),
		BackgroundColor3 = dOS.THEME.LOCKSCREEN_INPUT_BG,
		BorderSizePixel = 0,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 6,
		OnEnter = function(pname)
			if not pname then
				warn(`[LockScreen]: Failed to scan cursor! pname is '{pname}'.`)
				return
			end

			local current_cursor_id = dOS._Players:GetUserId(pname)
			hover_start_time = tick()

			if active_progress_tween then
				active_progress_tween:Cancel()
			end

			active_progress_tween = dOS.Tween.new(progress_bar, {
				Size = UDim2.fromScale(1, 1),
			}, dOS.TweenInfo.new(
				CURSOR_HOVER_DURATION,
				Enum.EasingStyle.Linear,
				Enum.EasingDirection.Out
			))
			active_progress_tween:Play()

			task.delay(CURSOR_HOVER_DURATION, function()
				if
					hover_start_time
					and (tick() - hover_start_time) >= CURSOR_HOVER_DURATION
					and not dOS.shared.LOCKSCREEN_aes_running
				then
					dOS.shared.LOCKSCREEN_aes_running = true

					local decrypted_id = if M.lockscreen_state.auth_data.cursor_id then
						tonumber(
							dOS.CHACHA.CHACHA_256(
								dOS.CHACHA.decrypt,
								dOS.SHA256.hash(
									M.lockscreen_state.auth_data.keyboard_password_hash
								),
								M.lockscreen_state.auth_data.cursor_id
							)
						)
					else nil

					dOS.shared.LOCKSCREEN_aes_running = false

					if progress_bar then
						progress_bar.BackgroundTransparency = 1
					end

					if current_cursor_id == decrypted_id then
						dOS.Tween
							.new(cursor_box, {
								BackgroundColor3 = dOS.THEME.LOCKSCREEN_SUCCESS,
							}, dOS.TweenInfo.new(
								0.3,
								Enum.EasingStyle.Quint,
								Enum.EasingDirection.Out
							))
							:Play()

						task.wait(0.5)
						M.unlock(dOS)
					else
						dOS.Tween
							.new(cursor_box, {
								BackgroundColor3 = dOS.THEME.LOCKSCREEN_ERROR,
							}, dOS.TweenInfo.new(
								0.3,
								Enum.EasingStyle.Quint,
								Enum.EasingDirection.Out
							))
							:Play()

						task.wait(1)

						dOS.Tween
							.new(cursor_box, {
								BackgroundColor3 = dOS.THEME.LOCKSCREEN_INPUT_BG,
							}, dOS.TweenInfo.new(
								0.3,
								Enum.EasingStyle.Quint,
								Enum.EasingDirection.Out
							))
							:Play()

						task.wait(0.3)

						if progress_bar then
							progress_bar.Size = UDim2.fromScale(0, 1)
							progress_bar.BackgroundTransparency = 0.6
						end
					end
				end
			end)
		end,
		OnLeave = function()
			hover_start_time = nil

			if active_progress_tween then
				active_progress_tween:Cancel()
				active_progress_tween = nil
			end

			-- reset progress bar
			dOS.Tween
				.new(progress_bar, {
					Size = UDim2.fromScale(0, 1),
				}, dOS.TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
				:Play()
		end,
	})

	dOS.create_gui_element(dOS, "UICorner", {
		Parent = cursor_box,
		CornerRadius = UDim.new(0, 8),
	})

	dOS.create_gui_element(dOS, "UIStroke", {
		Parent = cursor_box,
		Color = dOS.THEME.LOCKSCREEN_CARD_BORDER,
		Thickness = 1,
		Transparency = 0.5,
	})

	dOS.create_gui_element(dOS, "TextLabel", {
		Parent = cursor_box,
		Size = UDim2.fromScale(1, 1),
		Text = "Hover here with your authorized cursor",
		TextSize = 12,
		Font = dOS.FONT_REGULAR,
		TextColor3 = Color3.fromRGB(180, 180, 180),
		BackgroundTransparency = 1,
		TextWrapped = true,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 7,
	})

	progress_bar = dOS.create_gui_element(dOS, "Frame", {
		Parent = cursor_box,
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = dOS.THEME.LOCKSCREEN_BUTTON_PRIMARY,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 8,
	})

	dOS.create_gui_element(dOS, "UICorner", {
		Parent = progress_bar,
		CornerRadius = UDim.new(0, 8),
	})
end

function M.render_disk_input(dOS, parent)
	local current_disk_index = 1
	local available_disks = {}
	local previous_disks_count = 0
	local is_animating = false

	dOS.create_gui_element(dOS, "TextLabel", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 0),
		Text = "Insert your authorized disk",
		TextSize = 14,
		Font = dOS.FONT_REGULAR,
		TextColor3 = Color3.fromRGB(200, 200, 200),
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 6,
	})

	local status_label = dOS.create_gui_element(dOS, "TextLabel", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 35),
		Text = "Waiting for disk...",
		TextSize = 13,
		Font = dOS.FONT_REGULAR,
		TextColor3 = dOS.THEME.LOCKSCREEN_ACCENT,
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 6,
	})

	local carousel_container = dOS.create_gui_element(dOS, "Frame", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 120),
		Position = UDim2.fromOffset(0, 75),
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 6,
	})

	local disk_icon
	local old_disk_image_color

	local function disk_icon_OnLeave()
		if not dOS.shared.LOCKSCREEN_aes_running then
			dOS.Tween
				.new(disk_icon, {
					Size = UDim2.fromOffset(90, 90),
					Position = UDim2.new(0.5, -45, 0, 0),
					ImageColor3 = old_disk_image_color
						or dOS.THEME.LOCKSCREEN_ACCENT,
				}, dOS.TweenInfo.new(
					0.2,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				))
				:Play()
		end
	end

	disk_icon = dOS.create_gui_element(dOS, "ImageButton", {
		Parent = carousel_container,
		Size = UDim2.fromOffset(90, 90),
		Position = UDim2.new(0.5, -45, 0, 0),
		Image = ICON_IDS.CD,
		BackgroundTransparency = 1,
		ImageColor3 = dOS.THEME.LOCKSCREEN_ACCENT,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 7,
		OnEnter = function()
			if
				not is_animating
				and not dOS.shared.LOCKSCREEN_aes_running
				and #available_disks > 0
			then
				dOS.Tween
					.new(disk_icon, {
						Size = UDim2.fromOffset(100, 100),
						Position = UDim2.new(0.5, -50, 0, -5),
						ImageColor3 = disk_icon.ImageColor3:Lerp(
							Color3.new(1, 1, 1),
							0.3
						) or dOS.THEME.LOCKSCREEN_BUTTON_PRIMARY,
					}, dOS.TweenInfo.new(
						0.2,
						Enum.EasingStyle.Quad,
						Enum.EasingDirection.Out
					))
					:Play()
			end
		end,
		OnLeave = disk_icon_OnLeave,
	})

	local disk_name_label = dOS.create_gui_element(dOS, "TextLabel", {
		Parent = disk_icon,
		Size = UDim2.fromScale(1, 0.4),
		Position = UDim2.fromScale(0, 0.55),
		Text = "",
		TextSize = 11,
		Font = dOS.FONT_BOLD,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		TextWrapped = true,
		TextScaled = false,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 8,
	})

	local disk_indicator = dOS.create_gui_element(dOS, "TextLabel", {
		Parent = carousel_container,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 95),
		Text = "",
		TextSize = 11,
		Font = dOS.FONT_REGULAR,
		TextColor3 = Color3.fromRGB(180, 180, 180),
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 7,
	})

	local left_arrow
	left_arrow = dOS.create_gui_element(dOS, "TextButton", {
		Parent = carousel_container,
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(0, 10, 0.5, -40),
		Text = "◀",
		TextSize = 20,
		Font = dOS.FONT_BOLD,
		TextColor3 = Color3.fromRGB(200, 200, 200),
		BackgroundColor3 = dOS.THEME.LOCKSCREEN_INPUT_BG,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 7,
		OnEnter = function()
			if not is_animating and not dOS.shared.LOCKSCREEN_aes_running then
				dOS.Tween
					.new(left_arrow, {
						BackgroundTransparency = 0,
						TextColor3 = Color3.fromRGB(255, 255, 255),
					}, dOS.TweenInfo.new(
						0.15,
						Enum.EasingStyle.Quad,
						Enum.EasingDirection.Out
					))
					:Play()
			end
		end,
		OnLeave = function()
			dOS.Tween
				.new(left_arrow, {
					BackgroundTransparency = 0.3,
					TextColor3 = Color3.fromRGB(200, 200, 200),
				}, dOS.TweenInfo.new(
					0.15,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				))
				:Play()
		end,
	})

	dOS.create_gui_element(dOS, "UICorner", {
		Parent = left_arrow,
		CornerRadius = UDim.new(1, 0),
	})

	local right_arrow
	right_arrow = dOS.create_gui_element(dOS, "TextButton", {
		Parent = carousel_container,
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -50, 0.5, -40),
		Text = "▶",
		TextSize = 20,
		Font = dOS.FONT_BOLD,
		TextColor3 = Color3.fromRGB(200, 200, 200),
		BackgroundColor3 = dOS.THEME.LOCKSCREEN_INPUT_BG,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 7,
		OnEnter = function()
			if not is_animating and not dOS.shared.LOCKSCREEN_aes_running then
				dOS.Tween
					.new(right_arrow, {
						BackgroundTransparency = 0,
						TextColor3 = Color3.fromRGB(255, 255, 255),
					}, dOS.TweenInfo.new(
						0.15,
						Enum.EasingStyle.Quad,
						Enum.EasingDirection.Out
					))
					:Play()
			end
		end,
		OnLeave = function()
			dOS.Tween
				.new(right_arrow, {
					BackgroundTransparency = 0.3,
					TextColor3 = Color3.fromRGB(200, 200, 200),
				}, dOS.TweenInfo.new(
					0.15,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				))
				:Play()
		end,
	})

	dOS.create_gui_element(dOS, "UICorner", {
		Parent = right_arrow,
		CornerRadius = UDim.new(1, 0),
	})

	local function verify_disk(disk_wrapper)
		if dOS.shared.LOCKSCREEN_aes_running then
			return
		end

		local disk_path = M.lockscreen_state.auth_data.disk_device_path
			or "$dOS_secret_key.bin"
		local success, encrypted_key = pcall(
			disk_wrapper.obj.Read,
			disk_wrapper.obj,
			disk_path
		)

		if success then
			if not encrypted_key or encrypted_key == "" then
				status_label.Text = `Incorrect key`
				status_label.TextColor3 = dOS.THEME.LOCKSCREEN_ERROR
				return
			end

			dOS.shared.LOCKSCREEN_aes_running = true
			status_label.Text = `Verifying Disk...`
			status_label.TextColor3 = dOS.THEME.LOCKSCREEN_ACCENT

			if disk_icon then
				disk_icon_OnLeave()
			end

			local rotation_animation_thread = task.spawn(function()
				while
					disk_icon
					and disk_icon.Parent
					and M.lockscreen_state.selected_method == "disk"
					and dOS.shared.LOCKSCREEN_aes_running
				do
					dOS.Tween
						.new(disk_icon, {
							Rotation = 360,
						}, dOS.TweenInfo.new(
							2,
							Enum.EasingStyle.Quad,
							Enum.EasingDirection.InOut
						))
						:Play()

					task.wait(2)

					if disk_icon and disk_icon.Parent then
						disk_icon.Rotation = 0
					end
				end
			end)

			local decrypted = dOS.CHACHA.CHACHA_256(
				dOS.CHACHA.decrypt,
				dOS.SHA256.hash(
					M.lockscreen_state.auth_data.keyboard_password_hash
				),
				encrypted_key
			)
			dOS.shared.LOCKSCREEN_aes_running = false

			if type(rotation_animation_thread) == "thread" then
				task.cancel(rotation_animation_thread)
			end

			if
				decrypted == M.lockscreen_state.auth_data.disk_secret_key
				and decrypted:match("|(.*)") == dOS.SHA256.hash(
					disk_wrapper.obj.GUID
				)
			then
				status_label.Text = "Disk verified"
				status_label.TextColor3 = dOS.THEME.LOCKSCREEN_SUCCESS

				dOS.Tween
					.new(disk_icon, {
						ImageColor3 = dOS.THEME.LOCKSCREEN_SUCCESS,
						Rotation = 0,
					}, dOS.TweenInfo.new(
						0.3,
						Enum.EasingStyle.Quint,
						Enum.EasingDirection.Out
					))
					:Play()

				task.wait(0.7)
				M.unlock(dOS)
			else
				dOS.Tween
					.new(disk_icon, {
						Rotation = 0,
					}, dOS.TweenInfo.new(
						0.3,
						Enum.EasingStyle.Quint,
						Enum.EasingDirection.Out
					))
					:Play()

				status_label.Text = `Incorrect key`
				status_label.TextColor3 = dOS.THEME.LOCKSCREEN_ERROR
			end
		else
			warn(`[LockScreen] READ_ERR: Failed to read disk #{disk_wrapper.id}, err: '{encrypted_key}'.`)
			status_label.Text = `Failed to read Disk`
			status_label.TextColor3 = dOS.THEME.LOCKSCREEN_ERROR
		end
	end

	local function update_disk_display(should_auto_verify)
		if #available_disks == 0 then
			disk_name_label.Text = ""
			disk_indicator.Text = ""
			return
		end

		local current_disk = available_disks[current_disk_index]

		-- FIXME
		-- `name` is unrealiable for sone reasons...
		-- stylua: ignore
		local lets = {
			"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
			"N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
		}

		disk_name_label.Text = if current_disk.id <= #lets
			then lets[current_disk.id] .. ":"
			else `Disk {current_disk.id}`
		disk_indicator.Text = `Disk {current_disk_index}/{#available_disks}`
		disk_icon.ImageColor3 = current_disk.obj.Color
			or dOS.THEME.LOCKSCREEN_ACCENT
		old_disk_image_color = disk_icon.ImageColor3

		if should_auto_verify then
			verify_disk(current_disk)
		end
	end

	local function slide_disk(direction)
		if is_animating or dOS.shared.LOCKSCREEN_aes_running then
			return
		end

		is_animating = true

		status_label.Text = "Click disk to verify"
		status_label.TextColor3 = dOS.THEME.LOCKSCREEN_ACCENT

		local slide_offset = direction == "left" and -150 or 150
		local original_pos = disk_icon.Position

		-- slide out both icon and text
		dOS.Tween
			.new(disk_icon, {
				Position = UDim2.new(0.5, slide_offset, 0, 0),
				ImageTransparency = 1,
			}, dOS.TweenInfo.new(
				0.2,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.In
			))
			:Play()

		dOS.Tween
			.new(disk_name_label, {
				TextTransparency = 1,
			}, dOS.TweenInfo.new(
				0.2,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.In
			))
			:Play()

		dOS.Tween
			.new(disk_indicator, {
				TextTransparency = 1,
			}, dOS.TweenInfo.new(
				0.2,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.In
			))
			:Play()

		task.wait(0.2)

		-- index update
		if direction == "left" then
			current_disk_index = current_disk_index - 1
			if current_disk_index < 1 then
				current_disk_index = #available_disks
			end
		else
			current_disk_index = current_disk_index + 1
			if current_disk_index > #available_disks then
				current_disk_index = 1
			end
		end

		update_disk_display(false)

		disk_icon.Position = UDim2.new(0.5, -slide_offset, 0, 0)

		-- slide in
		dOS.Tween
			.new(disk_icon, {
				Position = original_pos,
				ImageTransparency = 0,
			}, dOS.TweenInfo.new(
				0.25,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			))
			:Play()

		dOS.Tween
			.new(disk_name_label, {
				TextTransparency = 0,
			}, dOS.TweenInfo.new(
				0.25,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			))
			:Play()

		dOS.Tween
			.new(disk_indicator, {
				TextTransparency = 0,
			}, dOS.TweenInfo.new(
				0.25,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			))
			:Play()

		task.wait(0.25)
		is_animating = false
	end

	disk_icon.MouseButton1Click:Connect(function()
		if
			is_animating
			or dOS.shared.LOCKSCREEN_aes_running
			or #available_disks == 0
		then
			return
		end

		verify_disk(available_disks[current_disk_index])
	end)

	left_arrow.MouseButton1Click:Connect(function()
		slide_disk("left")
	end)

	right_arrow.MouseButton1Click:Connect(function()
		slide_disk("right")
	end)

	local function check_disk()
		local disks = dOS.HardwareManager.requestNewHardware("Disk", true, true)
		if
			next(disks) == nil
			or (disks[1].guid == dOS.disk.GUID and #disks == 1)
		then
			return
		end

		-- filter out system disk
		local new_available_disks = {}
		for _, disk_wrapper in ipairs(disks) do
			if disk_wrapper.guid ~= dOS.disk.GUID then
				table.insert(new_available_disks, disk_wrapper)
			end
		end

		if #new_available_disks == 0 then
			return
		end

		if #new_available_disks ~= previous_disks_count then
			available_disks = new_available_disks
			previous_disks_count = #available_disks
			current_disk_index = 1

			if #available_disks > 1 then
				left_arrow.Visible = true
				right_arrow.Visible = true
				status_label.Text = "Click disk to verify"
			else
				left_arrow.Visible = false
				right_arrow.Visible = false
				status_label.Text = "Click disk to verify"
			end

			-- start immediatly if there is only one disk
			update_disk_display(#available_disks == 1)
		end
	end

	task.spawn(function()
		while
			M.lockscreen_state.password_container
			and M.lockscreen_state.selected_method == "disk"
		do
			if
				not dOS.shared.LOCKSCREEN_aes_running
				and not is_animating
			then
				check_disk()
			end

			task.wait(5)
			task.wait()
		end
	end)
end

function M.render_no_methods(dOS, parent)
	dOS.create_gui_element(dOS, "TextLabel", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 100),
		Position = UDim2.fromOffset(0, 30),
		Text = "No unlock methods configured\n\nConfigure security in Settings",
		TextSize = 14,
		Font = dOS.FONT_REGULAR,
		TextColor3 = Color3.fromRGB(180, 180, 180),
		BackgroundTransparency = 1,
		TextWrapped = true,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 6,
	})

	local bypass_btn = dOS.create_gui_element(dOS, "TextButton", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 150),
		Text = "Unlock (Dev Mode)",
		TextSize = 15,
		Font = dOS.FONT_BOLD,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundColor3 = dOS.THEME.LOCKSCREEN_BUTTON_PRIMARY,
		BorderSizePixel = 0,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 6,
		OnClick = function()
			M.unlock(dOS)
		end,
	})

	dOS.create_gui_element(dOS, "UICorner", {
		Parent = bypass_btn,
		CornerRadius = UDim.new(0, 8),
	})
end

function M.render_method_selector(dOS)
	local methods = {}

	if M.lockscreen_state.auth_data.keyboard_password_hash then
		table.insert(methods, { type = "password", icon = ICON_IDS.KEY })
	end

	if M.lockscreen_state.auth_data.cursor_id then
		table.insert(methods, { type = "cursor", icon = ICON_IDS.CURSOR })
	end

	if M.lockscreen_state.auth_data.disk_secret_key then
		table.insert(methods, { type = "disk", icon = ICON_IDS.CD })
	end

	if #methods <= 1 then
		return
	end

	local selector_frame = dOS.create_gui_element(dOS, "Frame", {
		Parent = M.lockscreen_state.password_container,
		Name = "MethodSelector",
		Size = UDim2.new(1, -40, 0, 60),
		Position = UDim2.fromOffset(20, 355),
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 6,
	})

	dOS.create_gui_element(dOS, "TextLabel", {
		Parent = selector_frame,
		Size = UDim2.new(1, 0, 0, 20),
		Text = "Unlock Method:",
		TextSize = 12,
		Font = dOS.FONT_REGULAR,
		TextColor3 = Color3.fromRGB(180, 180, 180),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 6,
	})

	local method_buttons = dOS.create_gui_element(dOS, "Frame", {
		Parent = selector_frame,
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, 24),
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.LOCKSCREEN + 6,
	})

	for i, method in ipairs(methods) do
		local is_selected = (method.type == M.lockscreen_state.selected_method)

		local tooltip
		local btn = dOS.create_gui_element(dOS, "TextButton", {
			Parent = method_buttons,
			Size = UDim2.fromOffset(36, 36),
			Position = UDim2.fromOffset((i - 1) * 44, 0),
			BackgroundColor3 = is_selected
				and dOS.THEME.LOCKSCREEN_BUTTON_PRIMARY
				or dOS.THEME.LOCKSCREEN_INPUT_BG,
			BorderSizePixel = 0,
			Text = "",
			ZIndex = dOS.Z_INDEX.LOCKSCREEN + 7,
			OnClick = function()
				if M.lockscreen_state.selected_method ~= method.type then
					M.lockscreen_state.selected_method = method.type
					M.render_password_method(dOS)
				end
			end,
			OnEnter = function()
				tooltip.Text = method.type:gsub("^%l", string.upper)
				tooltip.Visible = true

				dOS.Tween
					.new(tooltip, {
						Position = UDim2.new(0.5, -40, 0, -30),
						TextTransparency = 0,
						BackgroundTransparency = 0,
					}, dOS.TweenInfo.new(
						0.15,
						Enum.EasingStyle.Quad,
						Enum.EasingDirection.Out
					))
					:Play()
			end,
			OnLeave = function()
				dOS.Tween
					.new(tooltip, {
						Position = UDim2.new(0.5, -40, 0, -24),
						TextTransparency = 1,
						BackgroundTransparency = 1,
					}, dOS.TweenInfo.new(
						0.15,
						Enum.EasingStyle.Quad,
						Enum.EasingDirection.Out
					))
					:Play()

				task.delay(0.15, function()
					if tooltip then
						tooltip.Visible = false
					end
				end)
			end,
		})

		dOS.create_gui_element(dOS, "UICorner", {
			Parent = btn,
			CornerRadius = UDim.new(1, 0),
		})

		dOS.create_gui_element(dOS, "ImageLabel", {
			Parent = btn,
			Size = UDim2.fromOffset(20, 20),
			Position = UDim2.new(0.5, -10, 0.5, -10),
			Image = method.icon,
			BackgroundTransparency = 1,
			ImageColor3 = Color3.fromRGB(255, 255, 255),
			ZIndex = dOS.Z_INDEX.LOCKSCREEN + 8,
		})

		tooltip = dOS.create_gui_element(dOS, "TextLabel", {
			Parent = btn,
			Size = UDim2.fromOffset(80, 24),
			Position = UDim2.new(0.5, -40, 0, -24),
			Text = method.type:gsub("^%l", string.upper),
			TextSize = 10,
			Font = dOS.FONT_REGULAR,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundColor3 = Color3.fromRGB(40, 40, 40),
			BorderSizePixel = 0,
			Visible = false,
			TextTransparency = 1,
			BackgroundTransparency = 1,
			ZIndex = dOS.Z_INDEX.LOCKSCREEN + 9,
		})

		dOS.create_gui_element(dOS, "UICorner", {
			Parent = tooltip,
			CornerRadius = UDim.new(0, 4),
		})
	end
end

--- API

function M.unlock(dOS)
	if not M.lockscreen_state.is_locked then
		return
	end

	for _, conn in pairs(M.lockscreen_state.connections) do
		if type(conn) == "thread" then
			task.cancel(conn)
			continue
		end

		conn:Disconnect()
	end

	M.lockscreen_state.connections = {}
	M.lockscreen_state.keyboard_buffer = ""
	dOS.shared.LOCKSCREEN_aes_running = nil

	-- (0.0s - 0.25s)

	if M.lockscreen_state.user_avatar then
		dOS.Tween
			.new(M.lockscreen_state.user_avatar, {
				BackgroundColor3 = dOS.THEME.LOCKSCREEN_SUCCESS
					or Color3.fromRGB(76, 175, 80),
			}, dOS.TweenInfo.new(
				0.25,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			))
			:Play()
	end

	-- (0.2s - 0.6s)

	if M.lockscreen_state.password_container then
		task.delay(0.2, function()
			if not M.lockscreen_state.password_container then
				return
			end

			local card = M.lockscreen_state.password_container

			for _, descendant in ipairs(card:GetDescendants()) do
				if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
					dOS.Tween
						.new(descendant, {
							TextTransparency = 1,
						}, dOS.TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
						:Play()

					if descendant.BackgroundTransparency < 1 then
						dOS.Tween
							.new(descendant, {
								BackgroundTransparency = 1,
							}, dOS.TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
							:Play()
					end
				elseif descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
					dOS.Tween
						.new(descendant, {
							ImageTransparency = 1,
						}, dOS.TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
						:Play()
				elseif descendant:IsA("Frame") and descendant.BackgroundTransparency < 1 then
					dOS.Tween
						.new(descendant, {
							BackgroundTransparency = 1,
						}, dOS.TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
						:Play()
				elseif descendant:IsA("UIStroke") then
					dOS.Tween
						.new(descendant, {
							Transparency = 1,
						}, dOS.TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
						:Play()
				end
			end

			dOS.Tween
				.new(card, {
					Position = UDim2.new(0.5, -190, 0.5, -230),
					BackgroundTransparency = 1,
				}, dOS.TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In))
				:Play()

			local card_stroke = card:FindFirstChildOfClass("UIStroke")
			if card_stroke then
				dOS.Tween
					.new(card_stroke, {
						Transparency = 1,
					}, dOS.TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
					:Play()
			end
		end)
	end

	-- (0.15s - 0.55s)

	local clock_elements = {
		{ el = M.lockscreen_state.clock_hours, prop = "TextTransparency", delay = 0.15 },
		{ el = M.lockscreen_state.clock_colon, prop = "TextTransparency", delay = 0.20 },
		{ el = M.lockscreen_state.clock_minutes, prop = "TextTransparency", delay = 0.25 },
		{ el = M.lockscreen_state.date_label, prop = "TextTransparency", delay = 0.30 },
	}

	for _, entry in ipairs(clock_elements) do
		if entry.el and entry.el.Parent then
			task.delay(entry.delay, function()
				if entry.el and entry.el.Parent then
					dOS.Tween
						.new(entry.el, {
							[entry.prop] = 1,
						}, dOS.TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
						:Play()
				end
			end)
		end
	end

	-- (0.1s - 0.6s)

	if M.lockscreen_state.dark_overlay then
		task.delay(0.1, function()
			if M.lockscreen_state.dark_overlay and M.lockscreen_state.dark_overlay.Parent then
				dOS.Tween
					.new(M.lockscreen_state.dark_overlay, {
						BackgroundTransparency = 1,
					}, dOS.TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
					:Play()
			end
		end)
	end

	-- (0.35s - 1.0s)

	local total_unlock_duration = 1.0

	task.delay(0.35, function()
		if M.lockscreen_state.background_image and M.lockscreen_state.background_image.Parent then
			dOS.Tween
				.new(M.lockscreen_state.background_image, {
					ImageTransparency = 1,
				}, dOS.TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
				:Play()
		end

		if M.lockscreen_state.container and M.lockscreen_state.container.Parent then
			dOS.Tween
				.new(M.lockscreen_state.container, {
					BackgroundTransparency = 1,
				}, dOS.TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
				:Play()
		end
	end)

	if M.lockscreen_state.container then
		for _, child in ipairs(M.lockscreen_state.container:GetDescendants()) do
			if
				child:IsA("TextLabel")
				and child ~= M.lockscreen_state.clock_hours
				and child ~= M.lockscreen_state.clock_colon
				and child ~= M.lockscreen_state.clock_minutes
				and child ~= M.lockscreen_state.date_label
			then
				task.delay(0.15, function()
					if child and child.Parent then
						dOS.Tween
							.new(child, {
								TextTransparency = 1,
							}, dOS.TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
							:Play()
					end
				end)
			end
		end
	end

	task.delay(total_unlock_duration + 0.05, function()
		if M.lockscreen_state.container then
			pcall(function()
				M.lockscreen_state.container:Destroy()
			end)
		end

		for _, sec_overlay in ipairs(M.lockscreen_state.secondary_overlays) do
			if sec_overlay and sec_overlay.Parent then
				pcall(function()
					sec_overlay:Destroy()
				end)
			end
		end

		M.lockscreen_state.secondary_overlays = {}
		M.lockscreen_state.is_locked = false
		M.lockscreen_state.is_password_phase = false
		M.lockscreen_state.container = nil
		M.lockscreen_state.background_image = nil
		M.lockscreen_state.dark_overlay = nil
		M.lockscreen_state.clock_hours = nil
		M.lockscreen_state.clock_colon = nil
		M.lockscreen_state.clock_minutes = nil
		M.lockscreen_state.date_label = nil
		M.lockscreen_state.password_container = nil
		M.lockscreen_state.user_avatar = nil
		M.lockscreen_state.password_dots_label = nil
		M.lockscreen_state.clear_password_btn = nil

		print("[LockScreen] Unlocked")
	end)
end

function M.lock(dOS, cb)
	M.show_lock_screen(dOS)
	if cb then
		cb()
	end
end

return M

-- EOF