--[[
    "dOS main entry point"
    
    @module main
    @version 1.1
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


local _SCRIPT_SHOULD_END = false

--- IMPORTS

-- roblox
local _Players = require("players") :: any

-- repr
local _repr = require("repr") :: any

-- libs
local Tween, TweenInfo =
    require("./libs/WoS_Tween_animation_engine").Tween,
    require("./libs/WoS_Tween_animation_engine").TweenInfo
local CHACHA = require("./libs/chacha20")
local Hasher = require("./libs/hasher")
local SHA256 = require("./libs/sha256")
local NET = {
    HTMLLexer = require("./libs/net/html_lexer"),
    HTMLParser = require("./libs/net/html_parser"),
    HTMLRenderer = require("./libs/net/html_renderer"),
    CSSLexer = require("./libs/net/css_lexer"),
    CSSParser = require("./libs/net/css_parser"),
    StyleResolver = require("./libs/net/style_resolver"),
}

-- core
local GUI = require("./core/gui")
local Input = require("./core/input")
local Theme = require("./core/theme")
local Window = require("./core/window")
local MessageBox = require("./core/msgbox")

-- managers
local DragManager = require("./managers/drag_manager")
local TaskbarManager = require("./managers/taskbar_manager")
local CursorManager = require("./managers/cursor_manager")
local NotificationManager = require("./managers/notification_manager")
local HardwareManager = require("./managers/hardware_manager")
local HoverManager = require("./managers/hover_manager")
local LockScreenManager = require("./managers/lockscreen_manager")
local VirtualDesktopManager = require("./managers/vdm")
local DWM = require("./managers/dwm")

-- apps
local Apps = {
    AudioPlayer = require("./apps/audio_player"),
    Calculator = require("./apps/calc"),
    Chat = require("./apps/chat"),
    CommandPrompt = require("./apps/cmd"),
    Explorer = require("./apps/explorer"),
    Browser = require("./apps/browser"),
    Notepad = require("./apps/notepad"),
    Settings = require("./apps/settings.lua"),
    TaskManager = require("./apps/taskmgr"),
    Custom = require("./apps/custom"),
    Demo3D = require("./apps/demo3d"),
    CursorManagerApp = require("./apps/cursor_mgr"),
    Paint = require("./apps/paint"),
}

-- games
local Games = {
    FlappyBird = require("./apps/Games/flappy"),
    Snake = require("./apps/Games/snake"),
    Pong = require("./apps/Games/pong"),
    Minesweeper = require("./apps/Games/mines"),
    ["2048"] = require("./apps/Games/2048"),
}

-- utils
local TableFuncs = require("./utils/tables")

local GAMES_DATA = {
    GLOBAL_GAMES_DATA_FOLDER = "/GamesData/",
    FLAPPY_BIRD_DISK_FILE = "flappy_hs.dat",
    SNAKE_DISK_FILE = "snake_hs.dat",
    PONG_DISK_FILE = "pong_wins.dat",
    MINESWEEPER_DISK_FILE = "minesweeper_times.dat",
    ["2048_DISK_FILE"] = "2048_hs.dat",
}
local START_MENU_DISK_FILE = "/dOS_start_menu.json"
local AUDIO_PLAYER_DISK_FILE = "/dOS_audioplayer.json"
local CHAT_DISK_FILE = "/dOS_connect.json"
local EXPLORER_DISK_FILE = "/dOS_explorer.json"
local SETTINGS_DISK_FILE = "/dOS_settings.json"
local PINNED_TASKBAR_DISK_FILE = "/dOS_pinned_taskbar.json"

local FONT_REGULAR = Enum.Font.SourceSans
local FONT_BOLD = Enum.Font.SourceSansBold

local main
local _MAIN_FUNCTION_ALREADY_FINISHED = false
local _DRAGGING_SPAWNRENDERLOOP_ALREADY_CALLED = false
local _SCREEN_DIMENSIONS_TOO_SMALL = false
local _MIN_SCREEN_DIMENSION_X = 800
local _MIN_SCREEN_DIMENSION_Y = 600

-- TODO: remove horrific all caps variables
local dOS = {
    shared = { START_W = 350 } :: { [any]: any },

    OWNER_ID = 2402559622,
    OWNER_USERNAME = "ctrDorianko21",
    _repr = _repr,
    _Players = _Players,

    -- hw
    disk = nil,
    screen = nil,
    keyboard = nil,
    speaker = nil,
    modem = nil,
    screen_dimensions = Vector2.new(800, 600),

    -- state
    window_metadata = {},
    all_windows = {},
    program_holder_frame = nil,
    active_window_frame = nil,
    start_menu_frame = nil,
    taskbar_frame = nil,

    -- core
    Window = Window,
    MessageBox = MessageBox,
    create_gui_element = GUI.create_gui_element,
    create_basic_window = Window.create_basic_window,
    set_active_window = Window.set_active_window,
    create_slider = GUI.create_slider,
    shutdownOS = nil,
    rebootOS = nil,

    -- managers
    DragManager = DragManager,
    drag_manager = DragManager.drag_manager,
    TaskbarManager = TaskbarManager,
    NotificationManager = NotificationManager,
    CursorManager = CursorManager,
    HardwareManager = HardwareManager,
    HoverManager = HoverManager,
    LockScreenManager = LockScreenManager,
    VirtualDesktopManager = VirtualDesktopManager,
    DWM = DWM,

    -- libs
    Tween = Tween,
    TweenInfo = TweenInfo,
    CHACHA = CHACHA,
    Hasher = Hasher,
    SHA256 = SHA256,
    NET = NET,

    -- TODO: move somewhere else but not here
    -- settings
    SETTINGS_DISK_FILE = SETTINGS_DISK_FILE,
    os_settings = {
        version = "1.1",
        owner_username = "ctrDorianko21",
        global_theme = Theme.Themes.Purple,
        global_text_scaled = false,
        transparentTB = false,
        global_font_size = 14,
        global_lerp_factor = 0.4,
        start_menu_height = 400,
        desktop_bg_img_id = 0,
        show_capture_overlay = false,
        round_corners = false,
        -- taskbar
        taskbar_position = "Bottom",
        taskbar_hide_fullscreen = false,
        taskbar_large_tabs = true,
        taskbar_combine = "Never",
    },
    _DEFAULT_os_settings = nil,

    PINNED_TASKBAR_DISK_FILE = PINNED_TASKBAR_DISK_FILE,
    GAMES_DATA = GAMES_DATA,

    AUDIO_PLAYER_DISK_FILE = AUDIO_PLAYER_DISK_FILE,
    audio_player_data = {
        playlists = {},
        favorites = {},
        current_playlist = nil,
        current_song_index = 1,
        is_playing = false,
        is_shuffle = false,
        loaded_sound = nil,
        pitch = 1.0,
        volume = 0.5,
        default_playlist_prompt_happened = false,
    },
    _DEFAULT_AUDIO_PLAYER_DATA = nil,

    CHAT_DISK_FILE = CHAT_DISK_FILE,
    _G_CHAT_DATA = {
        anonymous_username = false,
        channels = { ["dOS-General"] = { name = "General", messages = {} } },
        last_received_id = 0,

        redraw_function = nil,
        active_channel = "dOS-General",
        connections = {},
    },
    _DEFAULT_CHAT_DATA = nil,

    EXPLORER_DISK_FILE = EXPLORER_DISK_FILE,
    explorer_data = {
        trash_contents = {},
        pinned_folders = {},
        settings = {
            show_animations = true,
            view_mode = "Grid",
        },
    },
    _DEFAULT_EXPLORER_DATA = nil,

    -- theme
    THEME = Theme.THEME,
    Z_INDEX = Theme.Z_INDEX,
    FONT_REGULAR = FONT_REGULAR,
    FONT_BOLD = FONT_BOLD,

    -- the rest
    InputHandler = Input.InputHandler,
    RequestStringAsync = Input.RequestStringAsync,
    RequestNumberAsync = Input.RequestNumberAsync,
    RequestConfirmAsync = Input.RequestConfirmAsync,
    setup_fenv_win = Apps.Custom.setup_fenv_win,
    OpenFileDialog = nil,
    TableFuncs = TableFuncs,
    cleanName = function(s)
        return s:gsub("[^%w%s]+", ""):gsub("^%s*(.-)%s*$", "%1")
    end,
}
dOS._DEFAULT_os_settings = TableFuncs.deepcopy(dOS.os_settings)
dOS._DEFAULT_AUDIO_PLAYER_DATA = TableFuncs.deepcopy(dOS.audio_player_data)
dOS._DEFAULT_EXPLORER_DATA = TableFuncs.deepcopy(dOS.explorer_data)
dOS._DEFAULT_CHAT_DATA = TableFuncs.deepcopy(dOS._G_CHAT_DATA)

local __Special = {
    CMD = {
        save_audio_player_data = Apps.AudioPlayer.save_audio_player_data,
    },
    Explorer = {
        Notepad = Apps.Notepad.create,
    },
    Settings = {
        start_menu_frame = nil,
        destroy_prompt_ui = Input.destroy_prompt_ui,
    },
    TaskbarManager = {},
}

dOS.OpenFileDialog = function(fileDialogOptions)
    Apps.Explorer.create(dOS, __Special.Explorer, fileDialogOptions)
end

--- POWER

local function rebootOS()
    print("[dOS] Rebooting OS...")

    if VirtualDesktopManager and VirtualDesktopManager.reset then
        VirtualDesktopManager.reset(dOS)
    end
    if DragManager and DragManager.stop_drag then DragManager.stop_drag(dOS) end
    if DWM and DWM.shutdown then DWM.shutdown(dOS) end
    if CursorManager and CursorManager.shutdown then
        CursorManager.shutdown()
    end
    -- TODO / NOTIMPLEMENTED
    --[[
    if HoverManager and HoverManager.shutdown then HoverManager.shutdown() end
    if NotificationManager and NotificationManager.shutdown then
        NotificationManager.shutdown()
    end
    ]]
    if TaskbarManager and TaskbarManager.reset then TaskbarManager.reset() end

    Input.destroy_prompt_ui()

    if dOS.screen and dOS.screen.ClearElements then
        dOS.screen:ClearElements()
    end

    dOS.screen, dOS.keyboard, dOS.speaker, dOS.modem, dOS.disk =
        nil, nil, nil, nil, nil
    dOS.screen_dimensions = Vector2.new(800, 600)
    dOS.active_window_frame = nil
    dOS.all_windows = {}
    dOS.window_metadata = {}
    dOS.program_holder_frame = nil
    dOS.taskbar_frame = nil
    dOS.start_menu_frame = nil

    dOS.os_settings = TableFuncs.deepcopy(dOS._DEFAULT_os_settings)
    dOS.audio_player_data = TableFuncs.deepcopy(dOS._DEFAULT_AUDIO_PLAYER_DATA)
    dOS.explorer_data = TableFuncs.deepcopy(dOS._DEFAULT_EXPLORER_DATA)
    dOS._G_CHAT_DATA = TableFuncs.deepcopy(dOS._DEFAULT_CHAT_DATA)

    task.wait(0.1)
    task.spawn(main)
end

local function shutdownOS()
    print("[dOS] Shutting down OS...")

    if DWM and DWM.shutdown then DWM.shutdown(dOS) end
    if dOS.screen and dOS.screen.ClearElements then
        dOS.screen:ClearElements()
    end
    _SCRIPT_SHOULD_END = true
    print("[dOS] System Halted.")

    local s, e = pcall(function() Microcontroller:Shutdown() end)

    if not s or e then coroutine.yield() end
end

dOS.rebootOS, dOS.shutdownOS = rebootOS, shutdownOS

--- NETWORK

function on_global_message_received(raw_msg)
    if not dOS.modem then return end

    -- decode envelope
    local env_ok, envelope = pcall(JSONDecode, raw_msg)

    if
        not env_ok
        or type(envelope) ~= "table"
        or not envelope.cid
        or not envelope.data
    then
        warn(
            "[Main->on_global_message_received]: Invalid or non-envelope message - ignoring."
        )
        return
    end

    local channel_id = envelope.cid
    local channel = dOS._G_CHAT_DATA.channels[channel_id]

    if not channel then
        -- unknown channel, drop
        return
    end

    -- decrypt payload
    if not channel.password_hash then
        channel.password_hash = dOS.SHA256.hash("")
    end

    local s, json_msg = pcall(
        dOS.CHACHA.CHACHA_256,
        dOS.CHACHA.decrypt,
        channel.password_hash,
        envelope.data
    )

    if not s or not json_msg then
        warn(
            "[Main->on_global_message_received]: ChaCha decrypt failed for channel '"
                .. channel_id
                .. "' - wrong password?"
        )
        return
    end

    -- decode inner message
    local success, msg_data = pcall(JSONDecode, json_msg)

    if not success or type(msg_data) ~= "table" then
        warn(
            "[Main->on_global_message_received]: JSONDecode of inner payload failed."
        )
        return
    end

    local network_id = msg_data.target_channel_id

    if
        dOS._G_CHAT_DATA.channels[network_id]
        and msg_data.UNIQUE_ID ~= dOS._G_CHAT_DATA.last_received_id
    then
        dOS._G_CHAT_DATA.last_received_id = msg_data.UNIQUE_ID
        print("[dOS_Network] Received message for channel: " .. network_id)
        table.insert(dOS._G_CHAT_DATA.channels[network_id].messages, msg_data)

        if not dOS._G_CHAT_DATA.redraw_function then
            dOS.NotificationManager.push(
                dOS,
                "Message received !",
                `You have a new message received in {dOS._G_CHAT_DATA.channels[msg_data.target_channel_id].name}.`,
                97155235523143,
                135272730546427
            )
        else
            dOS._G_CHAT_DATA.redraw_function()
        end
    end
end

function initialise_network_listener()
    -- find modem
    if not dOS.modem then
        print("[dOS_Network] Initializing network listener...")

        for i = 0, 16 do
            local m = Network:GetPartFromPort(i, "Modem")

            if m then
                dOS.modem = m
                break
            end
        end

        if dOS.modem then
            print(
                "[dOS_Network] Modem found. Attaching global message listener."
            )
            pcall(function() dOS.modem.MessageSent:Disconnect() end)

            dOS.modem.MessageSent:Connect(on_global_message_received)
            -- set default channel
            dOS.modem:Configure({ NetworkID = "M1" })
        else
            print(
                "[dOS_Network] WARNING: No modem found. Chat will not receive messages."
            )
        end
    end
end

--- GAMES

function create_initial_games_data_folder()
    if dOS.disk then
        local s_r, data_ret =
            pcall(dOS.disk.Read, dOS.disk, GAMES_DATA.GLOBAL_GAMES_DATA_FOLDER)

        if s_r and data_ret then return end

        local s_w, err_write = pcall(
            dOS.disk.Write,
            dOS.disk,
            GAMES_DATA.GLOBAL_GAMES_DATA_FOLDER,
            ""
        )

        if not s_w then
            warn(
                "[Games Data Folder Creation] WRITE_ERROR: Could not create the initial GamesData folder. More info:"
            )
            warn("err = '" .. tostring(err_write) .. "'.")
            MessageBox.error(
                dOS,
                "Error",
                "Could not create the initial GamesData folder.\n\nProgress in games will NOT be saved."
            )
        end
    end
end

--- DESKTOP

function init_desktop_environment()
    if not dOS.screen then
        print("dOS_DEBUG: init_desktop_environment called but screen is nil!")
        return
    end

    -- dwm handles desktop, taskbars and drag binding
    local ok = DWM.init(
        dOS,
        __Special.TaskbarManager,
        create_start_menu,
        function()
            VirtualDesktopManager.init(dOS)
            VirtualDesktopManager.create_taskbar_button(dOS)
            print("dOS_DEBUG: Desktop initialized.")
        end
    )

    if not ok then
        logError(
            "dOS_DEBUG FATAL: DWM.init() failed"
        )
    end
end

--- START MENU

local _G_START_MENU_DATA = {
    all_apps = {
        {
            name = "File Explorer",
            icon_id = 105632605182672,
            is_white = false,
            launch_func = function()
                Apps.Explorer.create(dOS, __Special.Explorer)
            end,
        },
        {
            name = "Command Prompt",
            icon_id = 102551636383591,
            is_white = false,
            launch_func = function()
                Apps.CommandPrompt.create(dOS, __Special.CMD)
            end,
        },
        {
            name = "Notepad",
            icon_id = 113867808348339,
            is_white = false,
            launch_func = function() Apps.Notepad.create(dOS) end,
        },
        {
            name = "Audio Player",
            icon_id = 131505220015256,
            is_white = true,
            launch_func = function() Apps.AudioPlayer.create(dOS) end,
        },
        {
            name = "dOS Connect",
            icon_id = 97155235523143,
            is_white = false,
            launch_func = function() Apps.Chat.create(dOS) end,
        },
        {
            name = "Calculator",
            icon_id = 85861816563977,
            is_white = true,
            launch_func = function() Apps.Calculator.create(dOS) end,
        },
        {
            name = "Settings",
            icon_id = 81072774414061,
            is_white = true,
            launch_func = function()
                Apps.Settings.create(dOS, __Special.Settings)
            end,
        },
        {
            name = "Flappy dOS",
            icon_id = 71283249528204,
            is_white = false,
            launch_func = function() Games.FlappyBird.create(dOS) end,
        },
        {
            name = "Task Manager",
            icon_id = 16221016507,
            is_white = false,
            launch_func = function() Apps.TaskManager.create(dOS) end,
        },
        {
            name = "Web Browser",
            icon_id = 11395780588,
            is_white = true,
            launch_func = function() Apps.Browser.create(dOS) end,
        },
        {
            name = "3D Demo",
            icon_id = 12988752403,
            is_white = true,
            launch_func = function() Apps.Demo3D.create(dOS) end,
        },
        {
            name = "Cursor Manager",
            icon_id = 10366495969,
            is_white = true,
            launch_func = function() Apps.CursorManagerApp.create(dOS) end,
        },
        {
            name = "Snake",
            icon_id = 4795238032,
            is_white = false,
            launch_func = function() Games.Snake.create(dOS) end,
        },
        {
            name = "Pong",
            icon_id = 13814847211,
            is_white = false,
            launch_func = function() Games.Pong.create(dOS) end,
        },
        {
            name = "Minesweeper",
            icon_id = 115513939662410,
            is_white = false,
            launch_func = function() Games.Minesweeper.create(dOS) end,
        },
        {
            name = "2048",
            icon_id = 98413519634736,
            is_white = false,
            launch_func = function() Games["2048"].create(dOS) end,
        },
        {
            name = "Paint",
            icon_id = 31320560,
            is_white = false,
            launch_func = function() Apps.Paint.create(dOS) end,
        },
    },
    layout = {
        {
            folder_name = "Productivity",
            contents = {
                "Calculator",
                "Notepad",
                "File Explorer",
                "Audio Player",
                "dOS Connect",
                "Web Browser",
                "Paint",
            },
        },
        {
            folder_name = "System",
            contents = {
                "Command Prompt",
                "Settings",
                "Task Manager",
                "Cursor Manager",
            },
        },
        {
            folder_name = "Games",
            contents = { "Flappy dOS", "Snake", "Pong", "Minesweeper", "2048" },
        },
    },
}

dOS._app_icon_map = {}

for _, app in ipairs(_G_START_MENU_DATA.all_apps) do
    dOS._app_icon_map[app.name] = app.icon_id
end
__Special.TaskbarManager.start_menu_data = _G_START_MENU_DATA

function save_start_menu_data()
    if not dOS.disk then return end

    local data_to_save = { layout = _G_START_MENU_DATA.layout }
    local success, json_data = pcall(JSONEncode, data_to_save)

    if success then
        pcall(dOS.disk.Write, dOS.disk, START_MENU_DISK_FILE, json_data)
    end
end

function load_start_menu_data()
    if not dOS.disk then return end

    local success, json_data =
        pcall(dOS.disk.Read, dOS.disk, START_MENU_DISK_FILE)

    if success and json_data then
        local s_dec, data = pcall(JSONDecode, json_data)

        if s_dec and data.layout then
            _G_START_MENU_DATA.layout = data.layout
        end
    end
end

-- TODO: shouldn't be in main at all
function create_start_menu()
    local menu_width, menu_height =
        dOS.shared.START_W, dOS.os_settings.start_menu_height
    local anchor =
        dOS.TaskbarManager.get_start_menu_anchor(dOS, menu_width, menu_height)
    local final_position = anchor.final
    local start_position = anchor.start

    if dOS.start_menu_frame and dOS.start_menu_frame.Parent then
        local menu_to_close = dOS.start_menu_frame
        dOS.start_menu_frame = nil

        local tween_info =
            TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        local goal = { Position = anchor.start }
        local close_animation = Tween.new(menu_to_close, goal, tween_info)
        close_animation:Play()

        task.wait(0.25)
        if menu_to_close.Parent then menu_to_close:Destroy() end
        return
    end

    local last_folder_clicked

    dOS.start_menu_frame = GUI.create_gui_element(dOS, "Frame", {
        Name = "StartMenu",
        Parent = dOS.screen,
        ZIndex = Theme.Z_INDEX.START_MENU,
        Size = UDim2.fromOffset(menu_width, menu_height),
        Position = start_position,
    })
    if not dOS.start_menu_frame then return end

    dOS.start_menu_frame.ClipsDescendants = true
    dOS.create_gui_element(dOS, "UICorner", {
        Parent = dOS.start_menu_frame,
        CornerRadius = UDim.new(0, 10),
    })

    local tween_info =
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local goal = { Position = final_position }
    local animation = Tween.new(dOS.start_menu_frame, goal, tween_info)

    animation:Play()

    local state = {
        current_view = "main",
        history = { "main" },
        context_menu = nil,
    }
    local ui = { all_btn = nil }
    local draw_content_area, create_context_menu

    local function get_app_data(name)
        for _, a in ipairs(_G_START_MENU_DATA.all_apps) do
            if a.name == name then return a end
        end
        return nil
    end

    local function close_context_menu()
        if state.context_menu and state.context_menu.Parent then
            state.context_menu:Destroy()
            state.context_menu = nil
        end
    end

    local function navigate(new_view, is_going_back, source)
        close_context_menu()

        if ui.search_bar.TextColor3 ~= Theme.THEME.TEXT_DIM then
            ui.search_bar.Text = "Search..."
            ui.search_bar.TextColor3 = Theme.THEME.TEXT_DIM
        end

        local old_view = state.current_view
        state.current_view = new_view

        if is_going_back then
            table.remove(state.history)
        else
            if
                #state.history > 1
                and state.history[#state.history] ~= old_view
            then
                state.history = { "main" }
            end
            table.insert(state.history, new_view)
        end

        draw_content_area(false, is_going_back, source)
    end

    local function navigate_back()
        if ui.search_bar.TextColor3 ~= Theme.THEME.TEXT_DIM then
            ui.search_bar.Text = "Search..."
            ui.search_bar.TextColor3 = Theme.THEME.TEXT_DIM
        end

        if #state.history > 1 then
            navigate(state.history[#state.history - 1], true)
        end
    end

    -- ui
    ui.content_holder = GUI.create_gui_element(dOS, "Frame", {
        Parent = dOS.start_menu_frame,
        Name = "ContentHolder",
        Size = UDim2.new(1, 0, 1, -40),
        Position = UDim2.fromOffset(0, 0),
        BackgroundColor3 = Theme.THEME.START_MENU_CONTENT_BG,
    })
    ui.search_bar = GUI.create_gui_element(dOS, "TextButton", {
        Parent = ui.content_holder,
        Text = "Search...",
        TextColor3 = Theme.THEME.TEXT_DIM,
        BorderColor3 = Theme.THEME.TEXT_LIGHT,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -20, 0, 30),
        Position = UDim2.fromOffset(10, 10),
        BackgroundColor3 = Theme.THEME.TASKBAR_BG,
        HoverColor = Theme.THEME.BORDER_HIGHLIGHT,
    })
    ui.content_area = GUI.create_gui_element(dOS, "ScrollingFrame", {
        Parent = ui.content_holder,
        Size = UDim2.new(1, 0, 1, -45),
        Position = UDim2.fromOffset(0, 45),
        BackgroundTransparency = 1,
    })
    local bottom_bar = GUI.create_gui_element(dOS, "Frame", {
        Parent = dOS.start_menu_frame,
        ZIndex = Theme.Z_INDEX.START_MENU + 1,
        Size = UDim2.new(1, 0, 0, 40),
        Position = UDim2.new(0, 0, 1, -40),
        BackgroundColor3 = Theme.THEME.TASKBAR_BG,
    })
    GUI.create_gui_element(dOS, "ImageButton", { -- settings button
        Parent = bottom_bar,
        Image = 112502172419483,
        ImageColor3 = Theme.THEME.START_MENU_GENERIC_APP_ICON,
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.fromOffset(10, 5),
        OnClick = function()
            Apps.Settings.create(dOS, __Special.Settings)
            create_start_menu()
        end,
    })
    GUI.create_gui_element(dOS, "ImageButton", { -- reboot button
        Parent = bottom_bar,
        Image = 9613508061,
        ImageColor3 = Theme.THEME.START_MENU_GENERIC_APP_ICON,
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.new(1, -75, 0, 5),
        OnClick = rebootOS,
    })
    GUI.create_gui_element(dOS, "ImageButton", { -- shutdown button
        Parent = bottom_bar,
        Image = 130585682582063,
        ImageColor3 = Theme.THEME.START_MENU_GENERIC_APP_ICON,
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.new(1, -40, 0, 5),
        OnClick = shutdownOS,
    })

    local function open_folder_selection_menu(app_to_add)
        local sel_win, sel_content = Window.create_basic_window(
            dOS,
            "Add to Folder",
            250,
            300,
            true,
            true,
            false,
            false
        )
        local y_pos = 10

        local sel_sFrame = GUI.create_gui_element(dOS, "ScrollingFrame", {
            Parent = sel_content,
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Theme.THEME.WINDOW_BG,
        })

        for _, item in ipairs(_G_START_MENU_DATA.layout) do
            if type(item) == "table" then
                GUI.create_gui_element(dOS, "TextButton", {
                    Parent = sel_sFrame,
                    Text = item.folder_name,
                    Size = UDim2.new(1, -20, 0, 30),
                    Position = UDim2.fromOffset(10, y_pos),
                    OnClick = function()
                        table.insert(item.contents, app_to_add.name)
                        save_start_menu_data()
                        sel_win:Destroy()
                    end,
                })
                y_pos += 35
            end
        end

        GUI.create_gui_element(dOS, "TextButton", {
            Parent = sel_sFrame,
            Text = "New Folder",
            TextColor3 = Theme.THEME.TEXT_LIGHT,
            Size = UDim2.new(1, -20, 0, 30),
            Position = UDim2.fromOffset(10, y_pos),
            OnClick = function()
                Input.RequestStringAsync(
                    dOS,
                    "Enter the name of the folder: ",
                    "",
                    function(name)
                        if name == "" then return end
                        if #name > 18 then
                            MessageBox.error(
                                dOS,
                                "Invalid input",
                                "The maximum name size is 18 characters."
                            )
                            return
                        end

                        local cleaned_string = dOS.cleanName(name)

                        if #cleaned_string <= 0 then
                            MessageBox.error(
                                dOS,
                                "Invalid input",
                                "Do not put special charaters."
                            )
                            return
                        end
                        if cleaned_string ~= name then
                            MessageBox.error(
                                dOS,
                                "Invalid input",
                                "Special characters have been detected and removed."
                            )
                        end

                        table.insert(
                            _G_START_MENU_DATA.layout,
                            { folder_name = cleaned_string, contents = {} }
                        )

                        for _, item in ipairs(_G_START_MENU_DATA.layout) do
                            if
                                type(item) == "table"
                                and item.folder_name == cleaned_string
                            then
                                table.insert(item.contents, app_to_add.name)
                                save_start_menu_data()
                                sel_win:Destroy()
                            end
                        end
                    end
                )
            end,
        })

        sel_sFrame.CanvasSize = UDim2.fromOffset(0, y_pos + 35)
    end

    create_context_menu = function(cursor, item_info, context, item_index)
        close_context_menu()

        if not cursor then return end

        local rel_x, rel_y =
            cursor.X - dOS.start_menu_frame.AbsolutePosition.X,
            cursor.Y - dOS.start_menu_frame.AbsolutePosition.Y
        state.context_menu = GUI.create_gui_element(dOS, "Frame", {
            Parent = dOS.start_menu_frame,
            ZIndex = Theme.Z_INDEX.START_MENU + 5,
            Size = UDim2.fromOffset(140, 100),
            Position = UDim2.fromOffset(rel_x, rel_y),
            BackgroundColor3 = Theme.THEME.TASKBAR_BG,
        })
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = state.context_menu,
            CornerRadius = UDim.new(0, 6),
        })

        local y = 5

        local function add_item(t, cb)
            GUI.create_gui_element(dOS, "TextButton", {
                Parent = state.context_menu,
                Text = t,
                Size = UDim2.new(1, -10, 0, 25),
                Position = UDim2.fromOffset(5, y),
                TextXAlignment = Enum.TextXAlignment.Left,
                OnClick = function()
                    close_context_menu()
                    if cb then cb() end
                end,
            })
            y += 30
        end

        if context == "all_apps" then
            add_item("Pin to Start", function()
                table.insert(_G_START_MENU_DATA.layout, item_info.name)
                save_start_menu_data()
            end)
            add_item(
                "Add to Folder",
                function() open_folder_selection_menu(item_info) end
            )
        elseif context == "main_pinned" then
            add_item("Unpin", function()
                table.remove(_G_START_MENU_DATA.layout, item_index)
                save_start_menu_data()
                draw_content_area(nil, nil, nil, true, true)
            end)
        elseif context == "main_folder" then
            add_item("Remove Folder", function()
                table.remove(_G_START_MENU_DATA.layout, item_index)
                save_start_menu_data()
                draw_content_area(nil, nil, nil, true, true)
            end)
        elseif context == "folder_view" then
            add_item("Remove", function()
                for _, f in ipairs(_G_START_MENU_DATA.layout) do
                    if f.folder_name == state.current_view then
                        table.remove(f.contents, item_index)

                        if #f.contents == 0 then
                            state.current_view =
                                state.history[#state.history - 1]
                            table.remove(state.history, #state.history)
                        end

                        save_start_menu_data()

                        task.wait()
                        draw_content_area(
                            nil,
                            #f.contents == 0,
                            last_folder_clicked,
                            not (#f.contents == 0),
                            true
                        )
                        break
                    end
                end
            end)
        end
        state.context_menu.Size = UDim2.fromOffset(140, y)
    end

    -- drawing
    draw_content_area = function(
        filter_list,
        is_reversing,
        source_element,
        skip_anim,
        is_removing
    )
        local direction = is_reversing and 1 or -1 -- -1 forward, 1 back

        local function destroy_with_animation(obj)
            Tween.new(
                obj,
                { BackgroundTransparency = 1, TextTransparency = 1 },
                TweenInfo.new(
                    0.2,
                    Enum.EasingStyle.Elastic,
                    Enum.EasingDirection.InOut
                )
            ):Play()

            task.spawn(function()
                task.wait(0.2)
                if obj then obj:Destroy() end
            end)
        end

        local function animate_on_creation(obj)
            Tween.new(
                obj,
                { BackgroundTransparency = 0, TextTransparency = 0 },
                TweenInfo.new(
                    0.5,
                    Enum.EasingStyle.Elastic,
                    Enum.EasingDirection.InOut
                )
            ):Play()
        end

        if
            state.current_view == "main"
            or state.current_view == "all_apps"
            or filter_list
        then
            local new_content_frame =
                GUI.create_gui_element(dOS, "ScrollingFrame", {
                    Parent = dOS.start_menu_frame,
                    Size = ui.content_area.Size,
                    Position = UDim2.fromOffset(menu_width * -direction, 45),
                    BackgroundColor3 = Theme.THEME.START_MENU_CONTENT_BG,
                })

            local old_content_frame = ui.content_area
            ui.content_area = new_content_frame

            local anim_time = skip_anim and 0 or 0.25
            tween_info = TweenInfo.new(
                anim_time,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.InOut
            )
            local old_goal =
                { Position = UDim2.fromOffset(menu_width * direction, 45) }
            local new_goal = { Position = UDim2.fromOffset(0, 45) }

            Tween.new(old_content_frame, old_goal, tween_info):Play()
            Tween.new(new_content_frame, new_goal, tween_info):Play()

            task.spawn(function()
                task.wait(anim_time)
                if old_content_frame and old_content_frame.Parent then
                    for _, c in pairs(old_content_frame:GetChildren()) do
                        c:Destroy()
                    end
                    old_content_frame:Destroy()
                end
            end)
        else -- folder
            local old_content_frame = ui.content_area
            local new_content_frame =
                GUI.create_gui_element(dOS, "ScrollingFrame", {
                    Parent = dOS.start_menu_frame,
                    Size = ui.content_area.Size,
                    Position = UDim2.fromOffset(0, 45),
                    BackgroundColor3 = Theme.THEME.START_MENU_CONTENT_BG,
                    BackgroundTransparency = 1,
                })
            ui.content_area = new_content_frame

            local anim_time = skip_anim and 0 or 0.3
            tween_info = TweenInfo.new(
                anim_time,
                Enum.EasingStyle.Quint,
                Enum.EasingDirection.Out
            )

            -- going back to main
            if is_reversing then
                old_content_frame.Parent = dOS.start_menu_frame

                Tween.new(old_content_frame, {
                    Position = source_element.Position
                        + UDim2.fromOffset(0, 45),
                    Size = source_element.Size,
                    BackgroundTransparency = 1,
                }, tween_info):Play()

                new_content_frame.BackgroundTransparency = 1
                Tween.new(
                    new_content_frame,
                    { BackgroundTransparency = 0 },
                    tween_info
                )
                    :Play()

                task.spawn(function()
                    task.wait(anim_time)
                    if old_content_frame and old_content_frame.Parent then
                        old_content_frame:Destroy()
                    end
                end)
            else
                if not is_removing then -- opening a folder
                    new_content_frame.Position = source_element.Position
                        + UDim2.fromOffset(0, 45)
                    new_content_frame.Size = source_element.Size
                    new_content_frame.BackgroundTransparency = 1

                    Tween.new(new_content_frame, {
                        Position = UDim2.fromOffset(0, 45),
                        Size = old_content_frame.Size,
                        BackgroundTransparency = 0,
                    }, tween_info):Play()

                    Tween.new(
                        old_content_frame,
                        { BackgroundTransparency = 1 },
                        tween_info
                    ):Play()

                    task.spawn(function()
                        task.wait(anim_time)
                        if old_content_frame and old_content_frame.Parent then
                            old_content_frame:Destroy()
                        end
                    end)
                else -- removing an item
                    for _, e in pairs(old_content_frame:GetDescendants()) do
                        local s, err = pcall(function()
                            e:Destroy()
                            e = nil
                        end)

                        if not s then
                            print(
                                `[create_start_menu/folder_rm_item] Failed to Destroy the old content of the folder. Error: {err}.`
                            )
                        end
                    end
                end
            end
        end

        if state.current_view ~= "main" then
            GUI.create_gui_element(dOS, "TextButton", {
                Parent = ui.content_area,
                Text = "< Back",
                Size = UDim2.fromOffset(80, 25),
                Position = UDim2.fromOffset(10, 5),
                OnClick = navigate_back,
            })
        end

        if state.current_view == "all_apps" or filter_list then
            if ui.all_btn then
                destroy_with_animation(ui.all_btn)
                ui.all_btn = nil
            end

            local y = 45
            local apps = filter_list or _G_START_MENU_DATA.all_apps
            table.sort(apps, function(a, b) return a.name < b.name end)

            for _, app in ipairs(apps) do
                local item = GUI.create_gui_element(dOS, "TextButton", {
                    Parent = ui.content_area,
                    Text = app.name,
                    Size = UDim2.new(1, -20, 0, 35),
                    Position = UDim2.fromOffset(10, y),
                    AutoButtonColor = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                })
                item.MouseButton1Click:Connect(function()
                    task.spawn(app.launch_func)
                    create_start_menu()
                end)
                item.MouseButton2Click:Connect(
                    function()
                        create_context_menu(
                            dOS.screen:GetCursor(),
                            app,
                            "all_apps"
                        )
                    end
                )
                y += 40
            end
            ui.content_area.CanvasSize = UDim2.fromOffset(0, y)
        else
            local folder_data

            for _, f in ipairs(_G_START_MENU_DATA.layout) do
                if
                    type(f) == "table"
                    and f.folder_name == state.current_view
                then
                    folder_data = f
                    break
                end
            end

            if folder_data then -- folder view
                local y, x, TILE, PAD = 45, 10, 80, 10

                for i, name in ipairs(folder_data.contents) do
                    local app = get_app_data(name)

                    if app then
                        local t = GUI.create_gui_element(dOS, "ImageButton", {
                            Parent = ui.content_area,
                            Image = app.icon_id,
                            ImageColor3 = if app.is_white
                                then Theme.THEME.START_MENU_GENERIC_APP_ICON
                                else nil,
                            Size = UDim2.fromOffset(TILE, TILE),
                            Position = UDim2.fromOffset(x, y),
                        })
                        GUI.create_gui_element(dOS, "TextLabel", {
                            Parent = t,
                            Text = app.name,
                            Size = UDim2.new(1, 10, 0, 20),
                            Position = UDim2.fromOffset(-5.5, TILE - 4),
                            TextSize = 12,
                        })
                        t.MouseButton1Click:Connect(function()
                            task.spawn(app.launch_func)
                            create_start_menu()
                        end)
                        t.MouseButton2Click:Connect(
                            function()
                                create_context_menu(
                                    dOS.screen:GetCursor(),
                                    app,
                                    "folder_view",
                                    i
                                )
                            end
                        )
                        x = x + menu_width / 3 + PAD

                        if x + TILE > menu_width then
                            x = 10
                            y = y + TILE + PAD + 20
                        end
                    end
                end
                ui.content_area.CanvasSize = UDim2.fromOffset(0, y + TILE + 20)
            else -- main view
                local y, x, TILE, PAD = 10, 10, 100, 14
                local has_pinned = false
                local folder_count = 0
                local TILES_PER_COL = 6 -- shows 5 because of padding (i think)

                for i, item in ipairs(_G_START_MENU_DATA.layout) do
                    if type(item) == "table" then
                        local f_btn =
                            GUI.create_gui_element(dOS, "TextButton", {
                                Parent = ui.content_area,
                                Text = item.folder_name,
                                TextColor3 = Theme.THEME.TEXT_LIGHT,
                                Size = UDim2.fromOffset(TILE, TILE),
                                Position = UDim2.fromOffset(x, y),
                                BackgroundColor3 = Theme.THEME.START_MENU_TILE_BG,
                                BackgroundTransparency = 0.5,
                                TextYAlignment = Enum.TextYAlignment.Top,
                                AutoButtonColor = true,
                            })
                        f_btn.MouseButton1Click:Connect(function()
                            last_folder_clicked = f_btn
                            navigate(item.folder_name, false, f_btn)
                        end)
                        f_btn.MouseButton2Click:Connect(
                            function()
                                create_context_menu(
                                    dOS.screen:GetCursor(),
                                    item,
                                    "main_folder",
                                    i
                                )
                            end
                        )

                        local ix, iy = 5, 25

                        for n = 1, math.min(4, #item.contents) do
                            local ad = get_app_data(item.contents[n])

                            if ad then
                                GUI.create_gui_element(dOS, "ImageLabel", {
                                    Parent = f_btn,
                                    ZIndex = 2,
                                    Image = ad.icon_id,
                                    ImageColor3 = if ad.is_white
                                        then Theme.THEME.START_MENU_GENERIC_APP_ICON
                                        else nil,
                                    Size = UDim2.fromOffset(30, 30),
                                    Position = UDim2.fromOffset(ix, iy),
                                    BackgroundTransparency = 1,
                                })
                            end
                            ix += 35

                            if n == 2 then
                                ix = 5
                                iy = 60
                            end
                        end
                        x = x + TILE + PAD

                        if x + TILE > menu_width then
                            x = 10
                            y = y + TILE + PAD
                        end

                        folder_count += 1
                    elseif type(item) == "string" then
                        has_pinned = true
                    end
                end

                if has_pinned then
                    if x ~= 10 then y = y + TILE + PAD end
                    x = 10

                    GUI.create_gui_element(dOS, "Frame", {
                        Parent = ui.content_area,
                        Size = UDim2.new(1, -20, 0, 1),
                        Position = UDim2.fromOffset(10, y),
                        BackgroundColor3 = Theme.THEME.BORDER_HIGHLIGHT,
                    })
                    y += 10

                    for i, name in ipairs(_G_START_MENU_DATA.layout) do
                        if type(name) == "string" then
                            local app = get_app_data(name)

                            if app then
                                local t =
                                    GUI.create_gui_element(dOS, "ImageButton", {
                                        Parent = ui.content_area,
                                        Image = app.icon_id,
                                        ImageColor3 = if app.is_white
                                            then Theme.THEME.START_MENU_GENERIC_APP_ICON
                                            else nil,
                                        Size = UDim2.fromOffset(
                                            TILE * TILES_PER_COL / PAD,
                                            TILE * TILES_PER_COL / PAD
                                        ),
                                        Position = UDim2.fromOffset(x, y),
                                    })
                                GUI.create_gui_element(dOS, "TextLabel", {
                                    Parent = t,
                                    Text = app.name,
                                    Size = UDim2.new(1, 10, 0, 20),
                                    Position = UDim2.fromOffset(
                                        -5.5,
                                        TILE * TILES_PER_COL / PAD - 4
                                    ),
                                    TextSize = 11,
                                })
                                t.MouseButton1Click:Connect(function()
                                    task.spawn(app.launch_func)
                                    create_start_menu()
                                end)
                                t.MouseButton2Click:Connect(
                                    function()
                                        create_context_menu(
                                            dOS.screen:GetCursor(),
                                            app,
                                            "main_pinned",
                                            i
                                        )
                                    end
                                )
                                x += menu_width / TILES_PER_COL + PAD

                                if
                                    x + TILE * TILES_PER_COL / PAD > menu_width
                                then
                                    x = 10
                                    y += TILE * TILES_PER_COL / PAD + PAD + 20
                                end
                            end
                        end
                    end
                end

                if ui.all_btn then
                    ui.all_btn:Destroy()
                    ui.all_btn = nil
                end

                ui.all_btn = GUI.create_gui_element(dOS, "TextButton", {
                    Parent = dOS.start_menu_frame,
                    Text = "All Apps >",
                    Position = UDim2.new(0, 10, 1, -80),
                    Size = UDim2.new(1, -20, 0, 35),
                    BackgroundTransparency = 1,
                    TextTransparency = 1,
                    OnClick = function(all_btn)
                        navigate("all_apps", nil, all_btn)
                    end,
                })
                y += 45
                animate_on_creation(ui.all_btn)

                ui.content_area.CanvasSize = UDim2.fromOffset(
                    0,
                    y
                        + PAD
                        + ((TILE * TILES_PER_COL / PAD + PAD)
                            * (folder_count // 3)
                                + ((folder_count % 3 > 0)
                                    and (TILE * TILES_PER_COL / PAD + PAD)
                                        or 0
                                )
                        )
                        + 35
                )
            end
        end
    end

    ui.content_holder.MouseButton1Click:Connect(close_context_menu)
    ui.search_bar.MouseButton1Click:Connect(function()
        Input.RequestStringAsync(dOS, "Search apps:", "", function(q)
            if q == "" then
                ui.search_bar.Text = "Search..."
                ui.search_bar.TextColor3 = Theme.THEME.TEXT_DIM
                return
            end

            local f = {}

            for _, a in ipairs(_G_START_MENU_DATA.all_apps) do
                if a.name:lower():find(q:lower(), 1, true) then
                    table.insert(f, a)
                end
            end

            local already_in_all_apps = (state.current_view == "all_apps")

            if not already_in_all_apps then navigate("all_apps") end
            draw_content_area(f, false, nil, already_in_all_apps)
            task.spawn(function()
                task.wait(0.5)
                ui.search_bar.Text = q
                ui.search_bar.TextColor3 = Color3.fromRGB(255, 255, 255)
            end)
        end)
    end)
    draw_content_area(nil, nil, nil, true)
end

--- MAIN

local _serpent = nil
local ntamp = nil
local INPUT_KEYBOARD_ALREADY_BOUND = nil

main = function()
    local _primary_settings_disk_found = false
    _serpent = _serpent
        or {
            block = function(data)
                return "-- Serpent not available for: " .. tostring(data)
            end,
        }

    task.wait()

    local hardware_init_ret = HardwareManager.init(
        dOS,
        {
            min_screen_x = _MIN_SCREEN_DIMENSION_X,
            min_screen_y = _MIN_SCREEN_DIMENSION_Y,
        }
    )

    if hardware_init_ret.success then
        _SCREEN_DIMENSIONS_TOO_SMALL = hardware_init_ret.screen_too_small
    else
        print("dOS_DEBUG: Hardware detection failure.")
        error("Hardware detection failure.")
        return
    end

    dOS.screen:ClearElements()

    task.wait()

    if hardware_init_ret.sys_disk then
        dOS.disk = hardware_init_ret.sys_disk
        ntamp = (function()
            local r1 = (function()
                local sr, sd =
                    pcall(dOS.disk.Read, dOS.disk, "/dOS_lockscreen_auth.json")
                return sr and sd and sd ~= "" and sd ~= "{}"
            end)()

            if
                not r1
                and (function()
                        local c = 0

                        for _ in pairs(dOS.disk:ReadAll()) do
                            c += 1
                        end
                        return c
                    end)()
                    > 1
            then
                return false
            elseif r1 then
                return 0
            end

            return true
        end)()

        if not ntamp then error("Tampering detected.", 0) end

        LockScreenManager.load_auth_data(dOS)
        _primary_settings_disk_found = true
    else
        print("dOS_DEBUG: No primary disk found for settings.")
    end

    if not INPUT_KEYBOARD_ALREADY_BOUND then
        Input.BindKeyboardOnStart(dOS)
        INPUT_KEYBOARD_ALREADY_BOUND = true
    end

    if dOS.disk then Apps.Settings.load_settings(dOS) end

    -- apply theme
    if
        dOS.os_settings.global_theme == Theme.Themes.Custom
        and (dOS.os_settings :: any).custom_themes
        and (dOS.os_settings :: any).selected_theme_name
    then
        local raw =
            (dOS.os_settings :: any).custom_themes[(dOS.os_settings :: any).selected_theme_name]
        local palette = {}

        if raw then
            for k, v in pairs(raw) do
                if type(v) == "table" and v.r ~= nil then
                    palette[k] = Color3.fromRGB(v.r, v.g, v.b)
                end
            end
        end
        Theme.applyTheme(dOS, Theme.Themes.Custom, palette)
    else
        Theme.applyTheme(dOS, dOS.os_settings.global_theme)
    end

    LockScreenManager.lock(dOS, init_desktop_environment)

    task.spawn(function()
        task.spawn(CursorManager.init, dOS)
        task.spawn(HoverManager.init, dOS)
        task.spawn(NotificationManager.init, dOS)
        task.spawn(DragManager.SpawnRenderLoop, dOS)
        -- vdm and drag binding are handled inside dwm

        if dOS.disk then
            task.spawn(load_start_menu_data)
            task.spawn(Apps.Explorer.load_explorer_data, dOS)
            task.spawn(Apps.AudioPlayer.load_audio_player_data, dOS)
            task.spawn(Apps.Chat.load_chat_data, dOS)
            task.spawn(initialise_network_listener)
            task.spawn(create_initial_games_data_folder)
        end
    end)

    if not _primary_settings_disk_found then
        warn(
            "dOS_DEBUG: Warning user about the disk error ('_primary_settings_disk_found' = '"
                .. tostring(_primary_settings_disk_found)
                .. "')."
        )
        MessageBox.error(
            dOS,
            "No rom detected",
            "Your data will NOT be saved.",
            {
                { text = "Reboot", callback = rebootOS },
                { text = "Shutdown", callback = shutdownOS },
                { text = "IK BRO", callback = function() end },
            }
        )
    end

    if not (dOS.DWM and dOS.DWM._state and dOS.DWM._state.initialized) then
        local success = pcall(DragManager.BindInputEventsOnce, dOS)

        if not success then
            warn(
                "dOS_DEBUG: Cannot connect Cursor(s), user is using a Screen instead of a TouchScreen."
            )
            MessageBox.error(
                dOS,
                "Error",
                "You are using a Screen, which is not the best for dOS.\n\nTo use all of this OS capabilities, please use a TouchScreen.",
                {
                    { text = "Reboot", callback = rebootOS },
                    { text = "Shutdown", callback = shutdownOS },
                    { text = "IK BRO", callback = function() end },
                }
            )
        end
    end

    if _SCREEN_DIMENSIONS_TOO_SMALL == true then
        warn(
            "dOS_DEBUG: User is using a Screen too small. The minimun size recommended is "
                .. _MIN_SCREEN_DIMENSION_X
                .. " x "
                .. _MIN_SCREEN_DIMENSION_Y
                .. "."
        )
        MessageBox.warning(
            dOS,
            "Warning",
            "You are using a very small screen.\n\nYou might experience display issues.",
            {
                { text = "Reboot", callback = rebootOS },
                { text = "Shutdown", callback = shutdownOS },
                { text = "IK BRO", callback = function() end },
            }
        )
    end

    local missing_modem_prompt_active = false

    while dOS.modem == nil do
        if not missing_modem_prompt_active then
            MessageBox.warning(
                dOS,
                "Warning",
                "No modem detected !\nYou will not receive messages for dOS Connect.\n\nPlease connect one and press Retry.",
                {
                    {
                        text = "Retry",
                        callback = function()
                            initialise_network_listener()
                            missing_modem_prompt_active = nil
                        end,
                    },
                    {
                        text = "Continue anyway",
                        callback = function() dOS.modem = false end,
                    },
                }
            )
            missing_modem_prompt_active = true
        else
            task.wait(1)
        end
    end

    if ntamp == true then
        MessageBox.error(
            dOS,
            "VERY IMPORTANT",
            "You MUST set a NEW PASSWORD before the next restart, or otherwise you WON'T BE ABLE TO BOOT.",
            {
                {
                    text = "Open Settings",
                    callback = function()
                        Apps.Settings.create(dOS, __Special.Settings)
                    end,
                },
            }
        )
    end

    print("dOS_Luau Desktop Initialized.")

    _MAIN_FUNCTION_ALREADY_FINISHED = true
    coroutine.yield()
end

if not _MAIN_FUNCTION_ALREADY_FINISHED then main() end

-- EOF