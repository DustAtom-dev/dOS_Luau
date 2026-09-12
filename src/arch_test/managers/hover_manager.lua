--[[
    "Hover manager module for dOS"
    
    @module hover_manager
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


-- TODO: hover goes wrong inside ScrollingFrames once the user scrolls, the
-- server never sees CanvasPosition changes. Use AutoButtonColor in there or
-- set disable_scrollframe_children

local M = {}

M.registry = {}
M.cursor_states = {} -- { [PlayerName] = currently_hovered_element }
M.active_tweens = {} -- { [element] = { enter_tweens = {}, leave_tweens = {} } }
M.transition_locks = {} -- { [PlayerName] = true } -- stops overlapping transitions

-- config
M.config = {
    disable_scrollframe_children = false,
    warn_on_scrollframe_children = true,
}

function M.init(dOS)
    dOS.HoverManager = M

    if dOS.screen and dOS.screen.CursorMoved then
        dOS.screen.CursorMoved:Connect(function(cursor)
            if cursor then
                M.process_cursor(cursor)
            end
        end)
    end
end

local function is_scrolling_frame(obj)
    if not obj or typeof(obj) ~= "Instance" then
        return false
    end

    local success, result = pcall(function()
        return obj:IsA("ScrollingFrame")
    end)

    return success and result
end

local function is_inside_scrolling_frame(element)
    local current = element.Parent

    while current do
        if typeof(current) == "Instance" and is_scrolling_frame(current) then
            return true, current
        end

        current = current.Parent
    end

    return false, nil
end

function M.register(element, props)
    if not element then
        return
    end

    local inside_scroll, _ = is_inside_scrolling_frame(element) -- _: scroll_parent

    if inside_scroll then
        if M.config.warn_on_scrollframe_children then
            warn(
                string.format(
                    "[HoverManager] WARNING: Element '%s' is inside a ScrollingFrame. "
                        .. "Hover detection will be incorrect after user scrolls. "
                        .. "Consider using AutoButtonColor instead or set disable_scrollframe_children=true.",
                    tostring(element.Name or element)
                )
            )
        end

        if M.config.disable_scrollframe_children then
            return
        end
    end

    M.registry[element] = {
        element = element,
        hoverColor = props.HoverColor,
        defaultColor = props.BackgroundColor3,
        onEnter = props.OnEnter,
        onLeave = props.OnLeave,
    }

    -- tween tracking
    M.active_tweens[element] = {
        enter_tweens = {},
        leave_tweens = {},
    }

    element.Destroying:Connect(function()
        M.cancel_element_tweens(element)

        M.registry[element] = nil
        M.active_tweens[element] = nil

        for player_name, hovered_el in pairs(M.cursor_states) do
            if hovered_el == element then
                M.cursor_states[player_name] = nil
            end
        end
    end)
end

function M.cancel_element_tweens(element)
    local tweens = M.active_tweens[element]
    if not tweens then
        return
    end

    for _, tween in ipairs(tweens.enter_tweens) do
        if tween and tween.Cancel then
            pcall(function()
                tween:Cancel()
            end)
        end
    end

    for _, tween in ipairs(tweens.leave_tweens) do
        if tween and tween.Cancel then
            pcall(function()
                tween:Cancel()
            end)
        end
    end

    table.clear(tweens.enter_tweens)
    table.clear(tweens.leave_tweens)
end

function M.register_tween(element, tween, tween_type)
    if not M.active_tweens[element] then
        M.active_tweens[element] = { enter_tweens = {}, leave_tweens = {} }
    end

    if tween_type == "enter" then
        table.insert(M.active_tweens[element].enter_tweens, tween)
    elseif tween_type == "leave" then
        table.insert(M.active_tweens[element].leave_tweens, tween)
    end

    -- auto cleanup
    task.spawn(function()
        while
            tween.PlaybackState ~= Enum.PlaybackState.Completed
            and tween.PlaybackState ~= Enum.PlaybackState.Cancelled
        do
            task.wait()
        end

        if M.active_tweens[element] then
            local list = tween_type == "enter"
                    and M.active_tweens[element].enter_tweens
                or M.active_tweens[element].leave_tweens

            for i, t in ipairs(list) do
                if t == tween then
                    table.remove(list, i)
                    break
                end
            end
        end
    end)
end

local function safe_get_property(obj, prop_name)
    local success, value = pcall(function()
        return obj[prop_name]
    end)

    return success and value or nil
end

local function is_gui_object(obj)
    if not obj or typeof(obj) ~= "Instance" then
        return false
    end

    local success, result = pcall(function()
        return obj:IsA("GuiObject")
    end)

    return success and result
end

local function is_point_in_bounds(x, y, element)
    local pos = safe_get_property(element, "AbsolutePosition")
    local size = safe_get_property(element, "AbsoluteSize")

    if not pos or not size then
        return false
    end

    return x >= pos.X
        and x <= pos.X + size.X
        and y >= pos.Y
        and y <= pos.Y + size.Y
end

function M.execute_transition(pid, element, action, data)
    while M.transition_locks[pid] do
        task.wait()
    end

    M.transition_locks[pid] = true

    if action == "enter" then
        if data.element and data.element.Parent then
            if M.active_tweens[element] then
                for _, tween in ipairs(M.active_tweens[element].leave_tweens) do
                    if tween and tween.Cancel then
                        pcall(function()
                            tween:Cancel()
                        end)
                    end
                end

                table.clear(M.active_tweens[element].leave_tweens)
            end

            data.defaultColor = data.element.BackgroundColor3

            if data.onEnter then
                local success, result = pcall(function()
                    return data.onEnter(pid)
                end)

                if not success then
                    warn(
                        "[HoverManager] OnEnter callback error for element:",
                        element,
                        result
                    )
                elseif result then
                    if typeof(result) == "table" then
                        if result.Play then
                            M.register_tween(element, result, "enter")
                        else
                            for _, tween in ipairs(result) do
                                if tween and tween.Play then
                                    M.register_tween(element, tween, "enter")
                                end
                            end
                        end
                    end
                end
            end

            if data.hoverColor and data.element.Parent then
                data.element.BackgroundColor3 = data.hoverColor
            end
        end
    elseif action == "leave" then
        if data.element and data.element.Parent then
            if M.active_tweens[element] then
                for _, tween in ipairs(M.active_tweens[element].enter_tweens) do
                    if tween and tween.Cancel then
                        pcall(function()
                            tween:Cancel()
                        end)
                    end
                end

                table.clear(M.active_tweens[element].enter_tweens)
            end

            if data.onLeave then
                local success, result = pcall(function()
                    return data.onLeave(pid)
                end)

                if not success then
                    warn(
                        "[HoverManager] OnLeave callback error for element:",
                        element,
                        result
                    )
                elseif result then
                    if typeof(result) == "table" then
                        if result.Play then
                            M.register_tween(element, result, "leave")
                        else
                            for _, tween in ipairs(result) do
                                if tween and tween.Play then
                                    M.register_tween(element, tween, "leave")
                                end
                            end
                        end
                    end
                end
            end

            if
                data.hoverColor
                and data.defaultColor
                and data.element.Parent
            then
                data.element.BackgroundColor3 = data.defaultColor
            end
        end
    end

    M.transition_locks[pid] = nil
end

function M.process_cursor(cursor)
    if not cursor or type(cursor) ~= "table" or not cursor.X then
        return
    end

    local cx, cy = cursor.X, cursor.Y
    local top_element = nil
    local top_element_zindex = -math.huge
    local pid = cursor.Player

    -- find the topmost element under the cursor
    for element, _ in pairs(M.registry) do
        -- drop dead elements
        if
            not (
                element
                and typeof(element) == "Instance"
                and is_gui_object(element)
            )
        then
            M.registry[element] = nil
            M.active_tweens[element] = nil
            continue
        end

        -- drop parentless elements
        if not element.Parent then
            M.registry[element] = nil
            M.active_tweens[element] = nil
            continue
        end

        local visible = safe_get_property(element, "Visible")
        if not visible then
            continue
        end

        if is_point_in_bounds(cx, cy, element) then
            local element_zindex = safe_get_property(element, "ZIndex") or 0

            -- pick the one on top
            if not top_element then
                top_element = element
                top_element_zindex = element_zindex
            else
                local ok_child, is_child = pcall(function()
                    return element:IsDescendantOf(top_element)
                end)

                if
                    (ok_child and is_child)
                    or (element_zindex > top_element_zindex)
                then
                    top_element = element
                    top_element_zindex = element_zindex
                end
            end
        end
    end

    local last_element = M.cursor_states[pid]

    if top_element ~= last_element then
        -- async so the cursor never waits on tweens
        task.spawn(function()
            -- leave the old element
            if last_element and M.registry[last_element] then
                local data = M.registry[last_element]
                M.execute_transition(pid, last_element, "leave", data)
            end

            -- enter the new one
            if top_element and M.registry[top_element] then
                local data = M.registry[top_element]
                M.execute_transition(pid, top_element, "enter", data)
            end
        end)

        M.cursor_states[pid] = top_element
    end
end

return M

-- EOF