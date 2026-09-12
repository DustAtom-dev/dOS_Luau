--[[
    "3D rendering demonstration application for dOS"
    
    @module demo3d
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

local Engine3D = require("../libs/engine3d")
local OBJParser = require("../libs/obj_parser")

--- API

function M.create(dOS)
    local win_frame, content_area = dOS.create_basic_window(
        dOS,
        "3D Demo",
        700,
        550,
        true,
        true,
        true,
        true
    )
    if not win_frame then
        return
    end

    --- STATE

    local state = {
        running = true, -- whether the render loop is active
        cam_yaw = 0, -- horizontal rotation in radians
        cam_pitch = 0, -- vertical rotation in radians
        cam_dist = 8, -- distance from camera to origin
        is_dragging = false, -- whether user is currently dragging
        drag_start = Vector2.new(0, 0), -- initial drag position
        last_yaw = 0, -- yaw at drag start
        last_pitch = 0, -- pitch at drag start
        dragger_id = nil, -- cursor ID of the dragger
    }

    --- VIEWPORT

    local viewport = dOS.create_gui_element(dOS, "Frame", {
        Parent = content_area,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(15, 15, 25),
    })
    viewport.ClipsDescendants = true
    viewport.Active = true

    local engine = Engine3D.new(dOS, viewport)

    --- SHAPES

    local function clear_scene()
        engine:Clear()
    end

    local function load_cube()
        clear_scene()

        local size = 1.5
        local verts = {
            Vector3.new(-size, -size, -size),
            Vector3.new(size, -size, -size),
            Vector3.new(size, -size, size),
            Vector3.new(-size, -size, size),
            Vector3.new(-size, size, -size),
            Vector3.new(size, size, -size),
            Vector3.new(size, size, size),
            Vector3.new(-size, size, size),
        }
        local edges = {
            { 1, 2 },
            { 2, 3 },
            { 3, 4 },
            { 4, 1 },
            { 5, 6 },
            { 6, 7 },
            { 7, 8 },
            { 8, 5 },
            { 1, 5 },
            { 2, 6 },
            { 3, 7 },
            { 4, 8 },
        }

        for _, edge in ipairs(edges) do
            engine:AddLine(
                verts[edge[1]],
                verts[edge[2]],
                Color3.fromRGB(100, 200, 255),
                2
            )
        end

        for _, v in ipairs(verts) do
            engine:AddPoint(v, Color3.new(1, 1, 1), 5)
        end
    end

    local function load_pyramid()
        clear_scene()

        local size, height = 2, 2
        local base = {
            Vector3.new(-size, -height, -size),
            Vector3.new(size, -height, -size),
            Vector3.new(size, -height, size),
            Vector3.new(-size, -height, size),
        }
        local apex = Vector3.new(0, height, 0)

        for i = 1, 4 do
            local next_i = (i % 4) + 1

            engine:AddLine(
                base[i],
                base[next_i],
                Color3.fromRGB(255, 100, 100),
                2
            )
            engine:AddLine(base[i], apex, Color3.fromRGB(255, 200, 100), 2)
            engine:AddPoint(base[i], Color3.new(1, 1, 1), 5)
        end

        engine:AddPoint(apex, Color3.new(1, 1, 1), 5)
    end

    local function load_sphere(complex)
        clear_scene()

        local radius = 2.5
        local rings = 40
        local segments = 25

        if complex then
            rings *= 1.5
            segments *= 2
        end

        for i = 0, rings do
            local phi = math.pi * (i / rings)
            local y = radius * math.cos(phi)
            local ringRadius = radius * math.sin(phi)

            local prevPoint = nil
            local firstPoint = nil

            for j = 0, segments do
                local theta = 2 * math.pi * (j / segments)
                local x = ringRadius * math.cos(theta)
                local z = ringRadius * math.sin(theta)
                local point = Vector3.new(x, y, z)

                if j % 2 == 0 then
                    engine:AddPoint(point, Color3.fromRGB(100, 255, 100), 3)
                end

                if prevPoint then
                    engine:AddLine(
                        prevPoint,
                        point,
                        Color3.fromRGB(50, 150, 50),
                        1
                    )
                end

                if j == 0 then
                    firstPoint = point
                end

                prevPoint = point
            end

            if prevPoint and firstPoint then
                engine:AddLine(
                    prevPoint,
                    firstPoint,
                    Color3.fromRGB(50, 150, 50),
                    1
                )
            end
        end
    end

    local function load_torus()
        clear_scene()

        local majorRadius = 2.5
        local tubeRadius = 1
        local segmentsMain = 40
        local segmentsTube = 12

        for i = 0, segmentsMain - 1 do
            local theta = 2 * math.pi * (i / segmentsMain)

            local prevPoint = nil
            local firstPoint = nil

            for j = 0, segmentsTube - 1 do
                local phi = 2 * math.pi * (j / segmentsTube)

                local x = (majorRadius + tubeRadius * math.cos(phi))
                    * math.cos(theta)
                local z = (majorRadius + tubeRadius * math.cos(phi))
                    * math.sin(theta)
                local y = tubeRadius * math.sin(phi)

                local point = Vector3.new(x, y, z)
                engine:AddPoint(point, Color3.fromRGB(200, 100, 255), 3)

                if prevPoint then
                    engine:AddLine(
                        prevPoint,
                        point,
                        Color3.fromRGB(100, 50, 150),
                        1
                    )
                end

                if j == 0 then
                    firstPoint = point
                end

                prevPoint = point
            end

            if prevPoint and firstPoint then
                engine:AddLine(
                    prevPoint,
                    firstPoint,
                    Color3.fromRGB(100, 50, 150),
                    1
                )
            end
        end
    end

    --- OBJ

    local function load_obj_from_url(url)
        if not dOS.modem then
            dOS.dOS.MessageBox.error(dOS, "Error", "No Modem found.")
            return
        end

        clear_scene()

        local data
        local url_lines = 0

        for _ in url:gmatch("[^\r\n]+") do
            url_lines += 1
        end

        if url_lines <= 1 then
            local success
            success, data = pcall(function()
                return dOS.modem:GetAsync(url, true)
            end)

            if not success then
                dOS.dOS.MessageBox.error(
                    dOS,
                    "Error",
                    "Failed to download OBJ.\n" .. tostring(data)
                )
                return
            end
        else
            data = url
        end

        task.spawn(function()
            local model_data = OBJParser.parse(data, 3)
            local verts = model_data.verts

            for faceIndex, face in ipairs(model_data.faces) do
                local num_verts = #face

                for i = 1, num_verts do
                    local idx1 = face[i].v
                    local idx2 = face[(i % num_verts) + 1].v

                    local p1 = verts[idx1]
                    local p2 = verts[idx2]

                    if p1 and p2 then
                        engine:AddLine(p1, p2, Color3.fromRGB(0, 255, 255), 1)
                    end
                end

                if #verts < 200 then
                    for i = 1, num_verts do
                        local idx = face[i].v
                        if verts[idx] then
                            engine:AddPoint(verts[idx], Color3.new(1, 1, 1), 2)
                        end
                    end
                end

                if faceIndex % 50 == 0 then
                    task.wait()
                end
            end

            print(
                `dOS 3D: Loaded {#verts} vertices and {#model_data.faces} faces.`
            )
        end)
    end

    --- UI

    local dropdown_frame_height = 30 * 6 + 10

    local menu_frame = dOS.create_gui_element(dOS, "Frame", {
        Parent = viewport,
        Size = UDim2.fromOffset(120, dropdown_frame_height),
        Position = UDim2.fromOffset(10, 45),
        BackgroundColor3 = dOS.THEME.WINDOW_BG,
        BorderColor3 = dOS.THEME.BORDER_HIGHLIGHT,
        ZIndex = 10,
    })
    menu_frame.Visible = false
    menu_frame.ClipsDescendants = true

    dOS.create_gui_element(dOS, "UICorner", {
        Parent = menu_frame,
        CornerRadius = UDim.new(0, 8),
    })

    local is_menu_animating = false

    dOS.create_gui_element(dOS, "TextButton", {
        Parent = viewport,
        Text = "Shapes ▼",
        Size = UDim2.fromOffset(120, 30),
        Position = UDim2.fromOffset(10, 10),
        ZIndex = 11,
        OnClick = function()
            if is_menu_animating then
                return
            end

            is_menu_animating = true

            local info = dOS.TweenInfo.new(
                0.25,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            )

            if menu_frame.Visible then
                local tween = dOS.Tween.new(
                    menu_frame,
                    { Size = UDim2.fromOffset(120, 0) },
                    info
                )
                tween:Play()

                task.delay(0.25, function()
                    menu_frame.Visible = false
                    is_menu_animating = false
                end)
            else
                menu_frame.Size = UDim2.fromOffset(120, 0)
                menu_frame.Visible = true

                local tween = dOS.Tween.new(
                    menu_frame,
                    { Size = UDim2.fromOffset(120, dropdown_frame_height) },
                    info
                )
                tween:Play()

                task.delay(0.25, function()
                    is_menu_animating = false
                end)
            end
        end,
    })

    dOS.create_gui_element(dOS, "UIListLayout", {
        Parent = menu_frame,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    })

    local function add_shape_btn(text, callback)
        dOS.create_gui_element(dOS, "TextButton", {
            Parent = menu_frame,
            Text = text,
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            TextColor3 = dOS.THEME.TEXT_LIGHT,
            HoverColor = dOS.THEME.START_MENU_TILE_HOVER,
            ZIndex = 11,
            OnClick = function()
                callback()
                menu_frame.Visible = false
            end,
        })
    end

    add_shape_btn("Cube", load_cube)
    add_shape_btn("Pyramid", load_pyramid)
    add_shape_btn("Sphere", load_sphere)
    add_shape_btn("Sphere^2 (⚠️LAG)", function()
        load_sphere(true)
    end)
    add_shape_btn("Torus", load_torus)
    add_shape_btn("Load OBJ (URL)", function()
        dOS.RequestStringAsync(
            dOS,
            "Enter raw .obj URL or content:\n\n⚠️ Only use low poly models (< 800 faces)",
            "",
            function(url)
                if url and url ~= "" then
                    load_obj_from_url(url)
                else
                    clear_scene()
                end
            end
        )
    end)

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = viewport,
        Text = "Zoom",
        Size = UDim2.fromOffset(50, 20),
        Position = UDim2.new(1, -160, 0, 10),
        TextColor3 = dOS.THEME.TEXT_DIM,
        BackgroundTransparency = 1,
    })

    local initial_slider_val = 23 - state.cam_dist

    dOS.create_slider(
        dOS,
        viewport,
        UDim2.new(1, -100, 0, 15),
        UDim2.fromOffset(90, 10),
        0.5,
        21.5,
        initial_slider_val,
        function(val)
            state.cam_dist = 23 - val
        end
    )

    --- CONTROL

    viewport.MouseButton1Down:Connect(function(x, y)
        local cursors = dOS.screen:GetCursors()

        for _, cursor in pairs(cursors) do
            if
                (Vector2.new(cursor.X, cursor.Y) - Vector2.new(x, y)).Magnitude
                < 10
            then
                state.is_dragging = true
                state.dragger_id = cursor.UserId
                state.drag_start = Vector2.new(cursor.X, cursor.Y)
                state.last_yaw = state.cam_yaw
                state.last_pitch = state.cam_pitch
                break
            end
        end
    end)

    dOS.screen.CursorMoved:Connect(function(cursor)
        if state.is_dragging and cursor.UserId == state.dragger_id then
            local delta = Vector2.new(cursor.X, cursor.Y) - state.drag_start
            local sensitivity = 0.01

            state.cam_yaw = state.last_yaw - (delta.X * sensitivity)
            state.cam_pitch = math.clamp(
                state.last_pitch + (delta.Y * sensitivity),
                -1.5,
                1.5
            )
        end
    end)

    viewport.MouseButton1Up:Connect(function()
        state.is_dragging = false
        state.dragger_id = nil
    end)

    --- MAINLOOP

    load_cube()

    task.spawn(function()
        while state.running and win_frame.Parent do
            local x = math.sin(state.cam_yaw)
                * math.cos(state.cam_pitch)
                * state.cam_dist
            local y = math.sin(state.cam_pitch) * state.cam_dist
            local z = math.cos(state.cam_yaw)
                * math.cos(state.cam_pitch)
                * state.cam_dist

            local cam_pos = Vector3.new(x, y, z)
            local look_at = Vector3.new(0, 0, 0)

            engine:SetCamera(CFrame.lookAt(cam_pos, look_at))
            engine:Render()

            task.wait()
        end
    end)

    win_frame.Destroying:Connect(function()
        state.running = false
        engine:Clear()
    end)
end

return M

-- EOF