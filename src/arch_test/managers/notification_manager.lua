--[[
    "Notification manager module for dOS"
    
    @module notification_manager
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

M.container = nil
M.active_toasts = {}
M.update_p = nil

--- CONFIG

local TOAST_WIDTH = 300
local TOAST_HEIGHT = 70
local PADDING = 10
local DISPLAY_TIME = 8 -- secs

M.GENERIC_ICONS = {
	INFO_SYSTEM = 128381622118300,
	INFO_GENERIC = 7546954294,
	TASK_COMPLETE = 105848363063342,
	ERROR = 81435836476705,
}

M.GENERIC_SFX = {
	INFO_SYSTEM = 478544929,
	INFO_GENERIC = 72538684949111,
	TASK_COMPLETE = 7116606826,
	ERROR = 5914602124,
}

--- API

function M.init(dOS)
	M.container = dOS.create_gui_element(dOS, "RealFrame", {
		Name = "NotificationContainer",
		Parent = dOS.screen,
		Size = UDim2.new(0, TOAST_WIDTH, 1, -45),
		Position = UDim2.new(1, -TOAST_WIDTH - 10, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.NOTIFICATION_CONTAINER,
	})

	dOS.create_gui_element(dOS, "UIListLayout", {
		Parent = M.container,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, PADDING),
	})

	dOS.NotificationManager = M
end

function M.push(dOS, title, message, icon_id, sound_id, type)
	if not M.container then
		return
	end

	local close_toast

	if dOS.speaker and dOS.audio_player_data.is_playing == false and sound_id then
		local old_pitch, old_vol = dOS.speaker.Pitch, dOS.speaker.Volume
		dOS.speaker.Volume = 0.5
		dOS.speaker.Pitch = 1

		local sound_obj = dOS.speaker:LoadSound(`rbxassetid://{sound_id}`)
		if sound_obj then
			pcall(function()
				if sound_obj.length > DISPLAY_TIME then
					warn(`[NotificationManager] LENGHT_SFX_TOO_LONG: Please use sfx of length <= {DISPLAY_TIME} secs.`)
				end
			end)
			sound_obj:Play()
		else
			dOS.speaker.Audio = sound_id
			task.wait()
			dOS.speaker:Trigger()
		end

		task.delay(DISPLAY_TIME, function()
			if sound_obj then
				sound_obj:Destroy()
			end
			dOS.speaker.Volume = old_vol
			dOS.speaker.Pitch = old_pitch
		end)
	end

	local wrapper = dOS.create_gui_element(dOS, "RealFrame", {
		Parent = M.container,
		Name = "ToastWrapper",
		Size = UDim2.new(1, 0, 0, TOAST_HEIGHT),
		BackgroundTransparency = 1,
	})

	local toast = dOS.create_gui_element(dOS, "Frame", {
		Parent = wrapper,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(1.2, 0),
		BackgroundColor3 = dOS.THEME.WINDOW_BG,
		BorderColor3 = dOS.THEME.BORDER_HIGHLIGHT,
		BorderSizePixel = 1,
		BackgroundTransparency = 0.1,
		ZIndex = dOS.Z_INDEX.NOTIFICATION_CONTAINER + 1,
	})

	dOS.create_gui_element(dOS, "UICorner", {
		Parent = toast,
		CornerRadius = UDim.new(0, 8),
	})

	-- icon
	if icon_id then
		dOS.create_gui_element(dOS, "ImageLabel", {
			Parent = toast,
			Image = icon_id,
			Size = UDim2.fromOffset(32, 32),
			Position = UDim2.fromOffset(10, (TOAST_HEIGHT - 32) / 2),
			BackgroundTransparency = 1,
			ZIndex = dOS.Z_INDEX.NOTIFICATION_CONTAINER + 2,
		})
	end

	-- title
	dOS.create_gui_element(dOS, "TextLabel", {
		Parent = toast,
		Text = title,
		Size = UDim2.new(1, -60, 0, 20),
		Position = UDim2.fromOffset(50, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = dOS.FONT_BOLD,
		TextColor3 = dOS.THEME.TEXT_LIGHT,
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.NOTIFICATION_CONTAINER + 2,
	})

	-- message
	dOS.create_gui_element(dOS, "TextLabel", {
		Parent = toast,
		Text = message,
		Size = UDim2.new(1, -60, 0, 30),
		Position = UDim2.fromOffset(50, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = dOS.THEME.TEXT_DIM,
		TextWrapped = true,
		TextSize = 12,
		BackgroundTransparency = 1,
		ZIndex = dOS.Z_INDEX.NOTIFICATION_CONTAINER + 2,
	})

	local close_btn = dOS.create_gui_element(dOS, "TextButton", {
		Parent = toast,
		Text = "X",
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.new(1, -25, 0, 5),
		BackgroundTransparency = 1,
		TextColor3 = dOS.THEME.TEXT_DIM,
		ZIndex = dOS.Z_INDEX.NOTIFICATION_CONTAINER + 2,
	})

	local is_closing = false

	if type == "progress_bar" then
		local bar_bg = dOS.create_gui_element(dOS, "Frame", {
			Parent = toast,
			Name = "ProgressBarBG",
			Size = UDim2.new(1, 0, 0, 4),
			Position = UDim2.new(0, 0, 1, -4),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			ZIndex = dOS.Z_INDEX.NOTIFICATION_CONTAINER + 2,
		})

		dOS.create_gui_element(dOS, "UICorner", {
			Parent = bar_bg,
			CornerRadius = UDim.new(0, 2),
		})

		local bar_fill = dOS.create_gui_element(dOS, "Frame", {
			Parent = bar_bg,
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Color3.fromHSV(0, 0.8, 0.8),
			BorderSizePixel = 0,
			ZIndex = dOS.Z_INDEX.NOTIFICATION_CONTAINER + 3,
		})

		dOS.create_gui_element(dOS, "UICorner", {
			Parent = bar_fill,
			CornerRadius = UDim.new(0, 2),
		})

		task.spawn(function()
			local last_p = -1

			while not is_closing and wrapper.Parent do
				local p = M.update_p or 0

				if p >= 100 then
					task.delay(1, function()
						close_toast()
						M.update_p = nil
					end)
				end

				if p ~= last_p then
					last_p = p
					local ratio = math.clamp(p / 100, 0, 1)
					local color = Color3.fromHSV(0.33 * ratio, 0.8, 0.9)

					dOS.Tween.new(bar_fill, {
						Size = UDim2.fromScale(ratio, 1),
						BackgroundColor3 = color,
					}, dOS.TweenInfo.new(0.2)):Play()
				end

				task.wait()
			end
		end)
	end

	dOS.Tween.new(
		toast,
		{ Position = UDim2.fromScale(0, 0) },
		dOS.TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	):Play()

	close_toast = function()
		if is_closing then
			return
		end
		is_closing = true

		dOS.Tween.new(
			toast,
			{ Position = UDim2.fromScale(1.2, 0) },
			dOS.TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		):Play()

		task.delay(0.4, function()
			dOS.Tween.new(
				wrapper,
				{ Size = UDim2.fromScale(1, 0) },
				dOS.TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			):Play()
		end)

		task.delay(0.6, function()
			if wrapper.Parent then
				wrapper:Destroy()
			end
		end)
	end

	close_btn.MouseButton1Click:Connect(close_toast)

	if type ~= "progress_bar" then
		task.delay(DISPLAY_TIME, close_toast)
	end
end

return M

-- EOF