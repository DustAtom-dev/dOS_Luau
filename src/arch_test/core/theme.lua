--[[
    "Theming module for dOS"
    
    @module theme
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

local THEMES = {
    PURPLE = {
        -- main backgrounds
        DESKTOP_BG = Color3.fromRGB(60, 40, 90),
        TASKBAR_BG = Color3.fromRGB(45, 30, 75),
        WINDOW_BG = Color3.fromRGB(65, 45, 100),
        TITLE_BAR_BG = Color3.fromRGB(75, 50, 115),

        -- start menu
        START_MENU_BG = Color3.fromRGB(55, 45, 85),
        START_MENU_CONTENT_BG = Color3.fromRGB(45, 35, 75),
        START_MENU_TILE_BG = Color3.fromRGB(80, 70, 110),
        START_MENU_TILE_HOVER = Color3.fromRGB(135, 95, 255),
        START_MENU_GENERIC_APP_ICON = Color3.fromRGB(140, 100, 190)
            :Lerp(Color3.new(0.4, 0, 0.7), 0.2),
        START_BUTTON_BG = Color3.fromRGB(120, 80, 170),
        START_BUTTON_HOVER = Color3.fromRGB(140, 100, 190),
        START_MENU_BOTTOM_BAR = Color3.fromRGB(35, 20, 65),

        -- lock screen
        LOCKSCREEN_OVERLAY = Color3.fromRGB(15, 20, 30),
        LOCKSCREEN_CARD_BG = Color3.fromRGB(25, 35, 50),
        LOCKSCREEN_CARD_BORDER = Color3.fromRGB(45, 45, 52),
        LOCKSCREEN_INPUT_BG = Color3.fromRGB(35, 45, 65),
        LOCKSCREEN_WAIT_TEXT_BG = Color3.fromRGB(170, 126, 223),
        LOCKSCREEN_BUTTON_PRIMARY = Color3.fromRGB(104, 58, 255),
        LOCKSCREEN_BUTTON_SECONDARY = Color3.fromRGB(38, 38, 45),
        LOCKSCREEN_SUCCESS = Color3.fromRGB(52, 199, 89),
        LOCKSCREEN_ERROR = Color3.fromRGB(255, 69, 58),
        LOCKSCREEN_BG = Color3.fromRGB(15, 20, 30),
        LOCKSCREEN_ACCENT = Color3.fromRGB(0, 150, 255),

        -- standard buttons
        ACCENT_BUTTON_BG = Color3.fromRGB(120, 80, 170),
        ACCENT_BUTTON_HOVER = Color3.fromRGB(140, 100, 190),

        -- special ui elements
        CALC_DISPLAY_BG = Color3.fromRGB(30, 20, 50),
        SETTINGS_LABEL_BG = Color3.fromRGB(55, 35, 85),

        -- calculator buttons
        CALC_BUTTON_BG = Color3.fromRGB(85, 60, 125),
        CALC_BUTTON_HOVER = Color3.fromRGB(105, 75, 145),
        CALC_OP_BUTTON_BG = Color3.fromRGB(100, 70, 150),
        CALC_OP_BUTTON_HOVER = Color3.fromRGB(120, 85, 170),

        -- explorer
        EXPLORER_NAV_BTN = Color3.fromRGB(78, 55, 115),
        EXPLORER_NAV_BTN_SELECTED = Color3.fromRGB(110, 85, 180),
        EXPLORER_NAV_BTN_BORDER = Color3.fromRGB(50, 35, 75),

        -- text colors
        TEXT_LIGHT = Color3.fromRGB(230, 220, 250),
        TEXT_DARK = Color3.fromRGB(30, 20, 50),
        TEXT_DIM = Color3.fromRGB(180, 170, 200),
        TEXT_BOX_DARK = Color3.fromRGB(45, 25, 80),
        TEXT_BOX_LIGHT = Color3.fromRGB(85, 65, 120),

        -- borders and accents
        BORDER_HIGHLIGHT = Color3.fromRGB(90, 65, 130),
        BORDER_DARK = Color3.fromRGB(35, 20, 60),
        ACCENT = Color3.fromRGB(133, 89, 188),

        -- message box
        MSGBOX_OVERLAY_COLOR = Color3.fromRGB(0, 0, 0),
        MSGBOX_BG = Color3.fromRGB(55, 35, 85),
    },

    BLUE = {
        -- main backgrounds
        DESKTOP_BG = Color3.fromRGB(35, 45, 60),
        TASKBAR_BG = Color3.fromRGB(28, 35, 48),
        WINDOW_BG = Color3.fromRGB(45, 55, 72),
        TITLE_BAR_BG = Color3.fromRGB(52, 65, 85),

        -- start menu
        START_MENU_BG = Color3.fromRGB(40, 50, 68),
        START_MENU_CONTENT_BG = Color3.fromRGB(32, 42, 58),
        START_MENU_TILE_BG = Color3.fromRGB(60, 75, 95),
        START_MENU_TILE_HOVER = Color3.fromRGB(85, 125, 170),
        START_MENU_GENERIC_APP_ICON = Color3.fromRGB(90, 120, 160)
            :Lerp(Color3.new(0.2, 0.2, 0.8), 0.2),
        START_BUTTON_BG = Color3.fromRGB(70, 100, 140),
        START_BUTTON_HOVER = Color3.fromRGB(90, 120, 160),
        START_MENU_BOTTOM_BAR = Color3.fromRGB(25, 30, 42),

        -- lock screen
        LOCKSCREEN_OVERLAY = Color3.fromRGB(20, 25, 32),
        LOCKSCREEN_CARD_BG = Color3.fromRGB(38, 48, 62),
        LOCKSCREEN_CARD_BORDER = Color3.fromRGB(60, 70, 85),
        LOCKSCREEN_INPUT_BG = Color3.fromRGB(48, 58, 75),
        LOCKSCREEN_WAIT_TEXT_BG = Color3.fromRGB(150, 175, 200),
        LOCKSCREEN_BUTTON_PRIMARY = Color3.fromRGB(75, 110, 155),
        LOCKSCREEN_BUTTON_SECONDARY = Color3.fromRGB(45, 50, 58),
        LOCKSCREEN_SUCCESS = Color3.fromRGB(75, 160, 120),
        LOCKSCREEN_ERROR = Color3.fromRGB(180, 85, 85),
        LOCKSCREEN_BG = Color3.fromRGB(20, 25, 32),
        LOCKSCREEN_ACCENT = Color3.fromRGB(100, 150, 190),

        -- standard buttons
        ACCENT_BUTTON_BG = Color3.fromRGB(70, 105, 150),
        ACCENT_BUTTON_HOVER = Color3.fromRGB(90, 125, 175),

        -- special ui elements
        CALC_DISPLAY_BG = Color3.fromRGB(30, 38, 52),
        SETTINGS_LABEL_BG = Color3.fromRGB(50, 62, 82),

        -- calculator buttons
        CALC_BUTTON_BG = Color3.fromRGB(65, 78, 98),
        CALC_BUTTON_HOVER = Color3.fromRGB(85, 100, 125),
        CALC_OP_BUTTON_BG = Color3.fromRGB(75, 95, 125),
        CALC_OP_BUTTON_HOVER = Color3.fromRGB(95, 115, 150),

        -- explorer
        EXPLORER_NAV_BTN = Color3.fromRGB(55, 68, 88),
        EXPLORER_NAV_BTN_SELECTED = Color3.fromRGB(80, 110, 150),
        EXPLORER_NAV_BTN_BORDER = Color3.fromRGB(45, 55, 75),

        -- text colors
        TEXT_LIGHT = Color3.fromRGB(225, 232, 240),
        TEXT_DARK = Color3.fromRGB(25, 32, 45),
        TEXT_DIM = Color3.fromRGB(165, 175, 190),
        TEXT_BOX_DARK = Color3.fromRGB(35, 45, 60),
        TEXT_BOX_LIGHT = Color3.fromRGB(65, 80, 105),

        -- borders and accents
        BORDER_HIGHLIGHT = Color3.fromRGB(80, 95, 115),
        BORDER_DARK = Color3.fromRGB(28, 35, 48),
        ACCENT = Color3.fromRGB(110, 160, 210),

        -- message box
        MSGBOX_OVERLAY_COLOR = Color3.fromRGB(0, 0, 0),
        MSGBOX_BG = Color3.fromRGB(45, 58, 80),
    },

    GRAY_BLUE = {
        -- main backgrounds
        DESKTOP_BG = Color3.fromRGB(36, 40, 48),
        TASKBAR_BG = Color3.fromRGB(30, 33, 40),
        WINDOW_BG = Color3.fromRGB(42, 46, 54),
        TITLE_BAR_BG = Color3.fromRGB(48, 52, 60),

        -- start menu
        START_MENU_BG = Color3.fromRGB(38, 42, 50),
        START_MENU_CONTENT_BG = Color3.fromRGB(32, 35, 42),
        START_MENU_TILE_BG = Color3.fromRGB(52, 58, 68),
        START_MENU_TILE_HOVER = Color3.fromRGB(65, 72, 85),
        START_MENU_GENERIC_APP_ICON = Color3.fromRGB(85, 110, 140)
            :Lerp(Color3.new(0.2, 0.5, 0.8), 0.2),
        START_BUTTON_BG = Color3.fromRGB(70, 95, 125),
        START_BUTTON_HOVER = Color3.fromRGB(85, 110, 140),
        START_MENU_BOTTOM_BAR = Color3.fromRGB(30, 32, 38),

        -- lock screen
        LOCKSCREEN_OVERLAY = Color3.fromRGB(22, 25, 30),
        LOCKSCREEN_CARD_BG = Color3.fromRGB(48, 54, 64),
        LOCKSCREEN_CARD_BORDER = Color3.fromRGB(65, 72, 82),
        LOCKSCREEN_INPUT_BG = Color3.fromRGB(38, 42, 50),
        LOCKSCREEN_WAIT_TEXT_BG = Color3.fromRGB(190, 200, 215),
        LOCKSCREEN_BUTTON_PRIMARY = Color3.fromRGB(80, 105, 135),
        LOCKSCREEN_BUTTON_SECONDARY = Color3.fromRGB(60, 65, 75),
        LOCKSCREEN_SUCCESS = Color3.fromRGB(100, 170, 120),
        LOCKSCREEN_ERROR = Color3.fromRGB(190, 100, 100),
        LOCKSCREEN_BG = Color3.fromRGB(28, 31, 38),
        LOCKSCREEN_ACCENT = Color3.fromRGB(110, 140, 175),

        -- standard buttons
        ACCENT_BUTTON_BG = Color3.fromRGB(75, 100, 130),
        ACCENT_BUTTON_HOVER = Color3.fromRGB(90, 115, 150),

        -- special ui elements
        CALC_DISPLAY_BG = Color3.fromRGB(30, 34, 42),
        SETTINGS_LABEL_BG = Color3.fromRGB(55, 60, 72),

        -- calculator buttons
        CALC_BUTTON_BG = Color3.fromRGB(52, 58, 68),
        CALC_BUTTON_HOVER = Color3.fromRGB(65, 72, 85),
        CALC_OP_BUTTON_BG = Color3.fromRGB(62, 70, 82),
        CALC_OP_BUTTON_HOVER = Color3.fromRGB(75, 85, 100),

        -- explorer
        EXPLORER_NAV_BTN = Color3.fromRGB(48, 52, 62),
        EXPLORER_NAV_BTN_SELECTED = Color3.fromRGB(60, 68, 80),
        EXPLORER_NAV_BTN_BORDER = Color3.fromRGB(36, 48, 62),

        -- text colors
        TEXT_LIGHT = Color3.fromRGB(235, 240, 245),
        TEXT_DARK = Color3.fromRGB(35, 40, 45),
        TEXT_DIM = Color3.fromRGB(165, 175, 190),
        TEXT_BOX_DARK = Color3.fromRGB(34, 38, 46),
        TEXT_BOX_LIGHT = Color3.fromRGB(250, 252, 255),

        -- borders and accents
        BORDER_HIGHLIGHT = Color3.fromRGB(70, 78, 92),
        BORDER_DARK = Color3.fromRGB(28, 32, 40),
        ACCENT = Color3.fromRGB(104, 140, 175),

        -- message box
        MSGBOX_OVERLAY_COLOR = Color3.fromRGB(0, 0, 0),
        MSGBOX_BG = Color3.fromRGB(45, 50, 60),
    },

    GREEN = {
        -- main backgrounds
        DESKTOP_BG = Color3.fromRGB(30, 35, 33),
        TASKBAR_BG = Color3.fromRGB(25, 30, 28),
        WINDOW_BG = Color3.fromRGB(38, 44, 41),
        TITLE_BAR_BG = Color3.fromRGB(45, 52, 48),

        -- start menu
        START_MENU_BG = Color3.fromRGB(35, 40, 38),
        START_MENU_CONTENT_BG = Color3.fromRGB(28, 32, 30),
        START_MENU_TILE_BG = Color3.fromRGB(55, 65, 60),
        START_MENU_TILE_HOVER = Color3.fromRGB(70, 85, 78),
        START_MENU_GENERIC_APP_ICON = Color3.fromRGB(80, 125, 105)
            :Lerp(Color3.new(0.1, 0.6, 0.2), 0.2),
        START_BUTTON_BG = Color3.fromRGB(60, 100, 85),
        START_BUTTON_HOVER = Color3.fromRGB(80, 125, 105),
        START_MENU_BOTTOM_BAR = Color3.fromRGB(22, 26, 24),

        -- lock screen
        LOCKSCREEN_OVERLAY = Color3.fromRGB(18, 22, 20),
        LOCKSCREEN_CARD_BG = Color3.fromRGB(45, 52, 48),
        LOCKSCREEN_CARD_BORDER = Color3.fromRGB(60, 70, 65),
        LOCKSCREEN_INPUT_BG = Color3.fromRGB(32, 38, 35),
        LOCKSCREEN_WAIT_TEXT_BG = Color3.fromRGB(200, 215, 205),
        LOCKSCREEN_BUTTON_PRIMARY = Color3.fromRGB(75, 120, 100),
        LOCKSCREEN_BUTTON_SECONDARY = Color3.fromRGB(55, 62, 58),
        LOCKSCREEN_SUCCESS = Color3.fromRGB(120, 200, 150),
        LOCKSCREEN_ERROR = Color3.fromRGB(200, 100, 100),
        LOCKSCREEN_BG = Color3.fromRGB(25, 30, 28),
        LOCKSCREEN_ACCENT = Color3.fromRGB(100, 160, 135),

        -- standard buttons
        ACCENT_BUTTON_BG = Color3.fromRGB(76, 130, 110),
        ACCENT_BUTTON_HOVER = Color3.fromRGB(96, 150, 130),

        -- special ui elements
        CALC_DISPLAY_BG = Color3.fromRGB(25, 30, 28),
        SETTINGS_LABEL_BG = Color3.fromRGB(55, 65, 60),

        -- calculator buttons
        CALC_BUTTON_BG = Color3.fromRGB(55, 65, 60),
        CALC_BUTTON_HOVER = Color3.fromRGB(70, 80, 75),
        CALC_OP_BUTTON_BG = Color3.fromRGB(65, 85, 75),
        CALC_OP_BUTTON_HOVER = Color3.fromRGB(80, 105, 95),

        -- explorer
        EXPLORER_NAV_BTN = Color3.fromRGB(55, 68, 62),
        EXPLORER_NAV_BTN_SELECTED = Color3.fromRGB(70, 88, 80),
        EXPLORER_NAV_BTN_BORDER = Color3.fromRGB(35, 45, 40),

        -- text colors
        TEXT_LIGHT = Color3.fromRGB(230, 245, 235),
        TEXT_DARK = Color3.fromRGB(25, 30, 28),
        TEXT_DIM = Color3.fromRGB(165, 180, 172),
        TEXT_BOX_DARK = Color3.fromRGB(28, 34, 31),
        TEXT_BOX_LIGHT = Color3.fromRGB(250, 255, 252),

        -- borders and accents
        BORDER_HIGHLIGHT = Color3.fromRGB(70, 85, 78),
        BORDER_DARK = Color3.fromRGB(25, 32, 28),
        ACCENT = Color3.fromRGB(110, 190, 155),

        -- message box
        MSGBOX_OVERLAY_COLOR = Color3.fromRGB(0, 0, 0),
        MSGBOX_BG = Color3.fromRGB(45, 55, 50),
    },
}

M.Themes = {
    Purple = 0,
    Blue = 1,
    GrayBlue = 2,
    Green = 3,
    Custom = 4,
}

function M.applyTheme(dOS, theme, customPalette)
    if theme == M.Themes.Purple or not theme then
        M.THEME = dOS.TableFuncs.deepcopy(THEMES.PURPLE)
    elseif theme == M.Themes.Blue then
        M.THEME = dOS.TableFuncs.deepcopy(THEMES.BLUE)
    elseif theme == M.Themes.GrayBlue then
        M.THEME = dOS.TableFuncs.deepcopy(THEMES.GRAY_BLUE)
    elseif theme == M.Themes.Green then
        M.THEME = dOS.TableFuncs.deepcopy(THEMES.GREEN)
    elseif theme == M.Themes.Custom and customPalette then
        M.THEME = dOS.TableFuncs.deepcopy(customPalette)
    end

    dOS.THEME = M.THEME

    print("[Theme]: Theme applied.")
end

M.THEME = {}

M.Z_INDEX = {
    DESKTOP = 1,
    WINDOW_INACTIVE = 15,
    WINDOW_ACTIVE = 16,
    WINDOW_DRAGGING = 17,
    START_MENU = 20,
    NOTIFICATION_CONTAINER = 29,
    TASKBAR = 40,
    MSGBOX_OVERLAY = 98,
    MSGBOX = 99,
    LOCKSCREEN = 9973,
    CURSOR = 9998,
}

return M

-- EOF