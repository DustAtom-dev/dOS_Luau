--[[
    "Table utilities module for dOS"
    
    @module tables
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

function M.deepcopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == "table" then
        if copies[orig] then return copies[orig] end
        copy = {}
        copies[orig] = copy
        for orig_key, orig_value in next, orig, nil do
            copy[M.deepcopy(orig_key, copies)] = M.deepcopy(orig_value, copies)
        end
        setmetatable(copy, M.deepcopy(getmetatable(orig), copies))
    else
        copy = orig
    end
    return copy
end

function M.printTable(t, indent, visited)
    indent = indent or ""
    visited = visited or {}

    if visited[t] then
        print(indent .. "*recursive reference*")
        return
    end
    visited[t] = true

    for key, value in pairs(t) do
        local formattedKey = tostring(key)
        if type(value) == "table" then
            print(indent .. formattedKey .. " = {")
            M.printTable(value, indent .. "  ", visited)
            print(indent .. "}")
        else
            print(indent .. formattedKey .. " = " .. tostring(value))
        end
    end
end

function M.countOccurrences(t, target)
    local count = 0
    for _, v in pairs(t) do
        if v == target then
            count += 1
        end
    end

    return count
end

return M

-- EOF