--[[
    "3D object file parser for dOS"
    
    @module obj_parser
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

function M.parse(data, scale_factor)
    scale_factor = scale_factor or 1

    local obj_data = {
        verts = {}, -- v
        uvs = {}, -- vt
        normals = {}, -- vn
        faces = {}, -- f
    }

    -- yield counter
    local line_count = 0

    for line in data:gmatch("[^\r\n]+") do
        line_count = line_count + 1
        if line_count % 200 == 0 then task.wait() end

        -- trim whitespace
        line = line:match("^%s*(.-)%s*$")

        -- vertices
        if line:match("^v%s") then
            local x, y, z =
                line:match("^v%s+([%d%.%-]+)%s+([%d%.%-]+)%s+([%d%.%-]+)")
            if x then
                table.insert(
                    obj_data.verts,
                    Vector3.new(
                        tonumber(x) * scale_factor,
                        tonumber(y) * scale_factor,
                        tonumber(z) * scale_factor
                    )
                )
            end

        -- texture coords
        elseif line:match("^vt%s") then
            local u, v = line:match("^vt%s+([%d%.%-]+)%s+([%d%.%-]+)")
            if u then
                table.insert(
                    obj_data.uvs,
                    Vector2.new(tonumber(u), tonumber(v))
                )
            end

        -- normals
        elseif line:match("^vn%s") then
            local x, y, z =
                line:match("^vn%s+([%d%.%-]+)%s+([%d%.%-]+)%s+([%d%.%-]+)")
            if x then
                table.insert(
                    obj_data.normals,
                    Vector3.new(tonumber(x), tonumber(y), tonumber(z))
                )
            end

        -- faces
        elseif line:match("^f%s") then
            local face_indices = {}

            -- each segment
            for segment in line:gmatch("%S+") do
                if segment ~= "f" then
                    -- v/vt/vn format
                    local v_idx, vt_idx, vn_idx =
                        segment:match("^(%d+)/?(%d*)/?(%d*)")

                    if v_idx then
                        table.insert(face_indices, {
                            v = tonumber(v_idx),
                            vt = tonumber(vt_idx), -- may be nil
                            vn = tonumber(vn_idx), -- may be nil
                        })
                    end
                end
            end

            if #face_indices >= 3 then
                table.insert(obj_data.faces, face_indices)
            end
        end
    end

    return obj_data
end

return M

-- EOF