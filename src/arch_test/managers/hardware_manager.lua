--[[
    "Hardware manager module for dOS"
    
    @module hardware_manager
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

local _hardware_connected = {}

local function _scan_hardware()
    _hardware_connected = {}
    local type_counters = {}

    for _, port in ipairs(Network:GetPorts()) do
        for _, part in ipairs((Network :: any):GetPartsFromPort(port)) do
            if part.GUID == Microcontroller.GUID then
                continue
            end

            if not type_counters[part.ClassName] then
                type_counters[part.ClassName] = 0
            end
            type_counters[part.ClassName] += 1

            table.insert(_hardware_connected, {
                obj = part,
                name = part.ClassName,
                id = type_counters[part.ClassName],
                used = false,
                was_used = nil,
                path = port,
                guid = part.GUID,
            })
        end
    end
end

function M.requestNewHardware(className, allOfThem, evenIfUsed)
    local function isMatch(hw, class, ifUsed)
        return hw and hw.obj and hw.name == class and (ifUsed or not hw.used)
    end

    local finds = {}

    if not allOfThem then
        for i = #_hardware_connected, 1, -1 do
            local hw = _hardware_connected[i]

            if not (hw and hw.obj) then
                table.remove(_hardware_connected, i)
            elseif isMatch(hw, className, evenIfUsed) then
                hw.was_used = hw.used
                hw.used = true
                return hw
            end
        end

        print(`[requestNewHardware]: Hardware '{className}' not found in cache. Rescanning...`)
    end

    _scan_hardware()

    for _, hw in ipairs(_hardware_connected) do
        if isMatch(hw, className, evenIfUsed) then
            hw.was_used = hw.used
            hw.used = true

            if allOfThem then
                table.insert(finds, hw)
            else
                return hw
            end
        end
    end

    if allOfThem and #finds > 0 then
        return finds
    end

    warn(`[requestNewHardware]: Hardware '{className}' is not connected or in use.`)

    return allOfThem and {} or nil
end

function M.requestAllScreens()
    _scan_hardware()

    local screens = {}
    local seen = {} -- [guid] = true

    local function _add_class(class_name)
        for _, hw in ipairs(_hardware_connected) do
            if hw.name == class_name and not seen[hw.guid] then
                seen[hw.guid] = true

                -- don't touch the flags of stuff requestNewHardware already claimed
                if not hw.used then
                    hw.was_used = false
                    hw.used = true
                end

                table.insert(screens, hw)
            end
        end
    end

    _add_class("TouchScreen")
    _add_class("Screen")

    return screens
end

function M.freeHardware(hw_wrapper)
    if not hw_wrapper then
        return
    end

    for _, hw in ipairs(_hardware_connected) do
        if hw.guid == hw_wrapper.guid then
            if hw.was_used == nil then
                warn(`[freeHardware] WARNING: Last hardware {hw.id} use state is nil! Defaulting to false.`)
                hw.was_used = false
            end

            hw.used = hw.was_used
            print(`[freeHardware]: Freed hardware '{hw.name}' (ID: {hw.id}); Now {if hw.used then "Used" else "Unused"}.`)

            return
        end
    end
end

function M.init(dOS, screen_requirements)
    local function find_primary_disk(disks)
        for _, disk_w in ipairs(disks) do
            local s, _ = disk_w.obj:Read("$PRIMARY_DISK")
            if s then
                return disk_w
            end
        end

        return nil
    end

    local ret = {
        screen_too_small = nil,
        sys_disk = nil,
        success = nil,
    }

    print("[get_hardware]: Booting Hardware Layer...")
    _scan_hardware()

    local screenWrapper = M.requestNewHardware("TouchScreen") or M.requestNewHardware("Screen")
    local keyboardWrapper = M.requestNewHardware("Keyboard")
    local speakerWrapper = M.requestNewHardware("Speaker")

    local disks_attached = M.requestNewHardware("Disk", true)
    local primary_disk_w

    if #disks_attached > 0 then
        primary_disk_w = find_primary_disk(disks_attached)

        if not primary_disk_w then
            primary_disk_w = disks_attached[1]
            primary_disk_w.obj:Write("$PRIMARY_DISK", "1")

            for i, disk in ipairs(disks_attached) do
                if i == 1 then
                    continue
                end

                M.freeHardware(disk)
            end
        end
    end

    ret.sys_disk = primary_disk_w and primary_disk_w.obj

    dOS.screen = screenWrapper and screenWrapper.obj
    dOS.keyboard = keyboardWrapper and keyboardWrapper.obj
    dOS.speaker = speakerWrapper and speakerWrapper.obj

    if not dOS.screen then
        warn("dOS_DEBUG FATAL: No screen found. System cannot boot.")
        ret.success = false
        return ret
    end

    local dims = dOS.screen:GetDimensions()
    if dims then
        dOS.screen_dimensions = dims
        print(string.format("dOS_DEBUG: Screen dimensions: %dx%d", dims.X, dims.Y))

        if dims.X < screen_requirements.min_screen_x or dims.Y < screen_requirements.min_screen_y then
            ret.screen_too_small = true
        end
    else
        warn("dOS_DEBUG WARNING: GetDimensions() failed on primary screen.")
    end

    if not dOS.keyboard then
        warn("dOS_DEBUG WARNING: No keyboard detected.")
    end

    if not dOS.speaker then
        warn("dOS_DEBUG WARNING: No speaker detected.")
    end

    print("[get_hardware]: Hardware initialization finished.")
    ret.success = true

    return ret
end

return M

-- EOF