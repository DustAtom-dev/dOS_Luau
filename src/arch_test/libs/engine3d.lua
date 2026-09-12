--[[
    "3D wireframe engine for dOS"
    
    @module engine3d
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

local Engine = {}
Engine.__index = Engine

-- math utils
local function get_screen_coords(cam_cf, point_vec3, screen_size, fov)
    -- object space
    local obj_space = cam_cf:PointToObjectSpace(point_vec3)

    -- behind camera
    if obj_space.Z > 0 then return nil end -- clipped

    -- perspective projection
    local fov_factor = math.tan(math.rad(fov) / 2)
    local aspect_ratio = screen_size.X / screen_size.Y

    -- ndc
    local ndc_x = (obj_space.X / -obj_space.Z) / (fov_factor * aspect_ratio)
    local ndc_y = (obj_space.Y / -obj_space.Z) / fov_factor

    -- screen coords
    local screen_x = (ndc_x + 1) * 0.5 * screen_size.X
    local screen_y = (1 - ndc_y) * 0.5 * screen_size.Y

    return Vector2.new(screen_x, screen_y), -obj_space.Z
end

function M.new(dOS, parent_frame)
    local self = setmetatable({}, Engine)
    self.dOS = dOS
    self.parent = parent_frame

    self.camera_cf = CFrame.new(0, 0, 5) -- default camera
    self.fov = 70

    self.objects = {}

    return self
end

-- add point
function Engine:AddPoint(pos_vec3, color, size)
    local dot = self.dOS.create_gui_element(self.dOS, "Frame", {
        Parent = self.parent,
        BackgroundColor3 = color or Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 2,
    })

    table.insert(self.objects, {
        type = "point",
        pos = pos_vec3,
        size = size or 4,
        gui = dot,
    })
    return dot
end

-- add line
function Engine:AddLine(pos_a, pos_b, color, thickness)
    local line = self.dOS.create_gui_element(self.dOS, "Frame", {
        Parent = self.parent,
        BackgroundColor3 = color or Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 1,
    })

    table.insert(self.objects, {
        type = "line",
        p1 = pos_a,
        p2 = pos_b,
        thickness = thickness or 2,
        gui = line,
    })
    return line
end

-- clear
function Engine:Clear()
    for _, obj in ipairs(self.objects) do
        if obj.gui then obj.gui:Destroy() end
    end
    self.objects = {}
end

-- set camera
function Engine:SetCamera(cframe) self.camera_cf = cframe end

-- render frame
function Engine:Render()
    local screen_size = self.parent.AbsoluteSize

    for _, obj in ipairs(self.objects) do
        if obj.type == "point" then
            local screen_pos, depth = get_screen_coords(
                self.camera_cf,
                obj.pos,
                screen_size,
                self.fov
            )

            if screen_pos then
                obj.gui.Visible = true
                -- scale by depth
                local scale = math.clamp(10 / depth, 0.5, 2)
                local s = obj.size * scale

                obj.gui.Size = UDim2.fromOffset(s, s)
                obj.gui.Position =
                    UDim2.fromOffset(screen_pos.X - s / 2, screen_pos.Y - s / 2)
            else
                obj.gui.Visible = false
            end
        elseif obj.type == "line" then
            local s1 =
                get_screen_coords(self.camera_cf, obj.p1, screen_size, self.fov)
            local s2 =
                get_screen_coords(self.camera_cf, obj.p2, screen_size, self.fov)

            if s1 and s2 then
                obj.gui.Visible = true
                local center = (s1 + s2) / 2
                local dist = (s2 - s1).Magnitude
                local angle = math.atan2(s2.Y - s1.Y, s2.X - s1.X)

                obj.gui.Size = UDim2.fromOffset(dist, obj.thickness)
                obj.gui.Position = UDim2.fromOffset(center.X, center.Y)
                obj.gui.Rotation = math.deg(angle)
                obj.gui.AnchorPoint = Vector2.new(0.5, 0.5)
            else
                obj.gui.Visible = false
            end
        end
    end
end

return M

-- EOF