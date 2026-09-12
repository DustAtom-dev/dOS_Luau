--[[
    "ChaCha20 KDF Hasher for dOS"
    
    @module hasher
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

M.ITERATIONS = 200
M.SALT_SIZE = 16

--- UTILS

local function hex_to_raw(hex)
    return (
        hex:gsub(
            "..",
            function(cc) return string.char(tonumber(cc, 16) or 0) end
        )
    )
end

local function raw_to_hex(str)
    return (
        str:gsub(
            ".",
            function(c) return string.format("%02x", string.byte(c)) end
        )
    )
end

@native
local function prepare_key(password)
    local key = table.create(32, 0)

    for i = 1, #password do
        local idx = ((i - 1) % 32) + 1
        key[idx] = bit32.bxor(key[idx], string.byte(password, i))
    end

    local hex = table.create(32)

    for i = 1, 32 do
        hex[i] = string.format("%02x", key[i])
    end

    return table.concat(hex)
end

local function iter_nonce(i)
    -- 4-byte be counter || 8 zero bytes
    return string.format("%08x0000000000000000", i)
end

--- API

@native
function M.hash(dOS, password, salt, callb_per_p)
    if not salt then
        local s = table.create(M.SALT_SIZE)
        for i = 1, M.SALT_SIZE do
            s[i] = string.char(math.random(0, 255))
        end
        salt = table.concat(s)
    end

    local chacha_key_hex = prepare_key(password)

    local current_block = salt
    local last_p = -1
    local CHACHA = dOS.CHACHA

    for i = 1, M.ITERATIONS do
        local hex_out = CHACHA.CHACHA_256(
            CHACHA.encrypt,
            chacha_key_hex,
            current_block,
            iter_nonce(i)
        )

        -- strip nonce prefix
        current_block = hex_to_raw(hex_out:sub(25))

        -- progress callback
        if callb_per_p then
            local p = math.floor((i / M.ITERATIONS) * 100)
            if p ~= last_p then
                callb_per_p(p)
                last_p = p
            end
        end
    end

    return string.format(
        "$dOS$%d$%s$%s",
        M.ITERATIONS,
        raw_to_hex(salt),
        raw_to_hex(current_block)
    )
end

function M.verify(dOS, password, stored_hash_str, callb_per_p)
    if not stored_hash_str or not stored_hash_str:match("^%$dOS%$") then
        return false
    end

    local iterations_str, salt_hex =
        stored_hash_str:match("^%$dOS%$(%d+)%$(%w+)%$%w+$")
    if not iterations_str then return false end

    local salt = hex_to_raw(salt_hex)
    local old_iter = M.ITERATIONS
    M.ITERATIONS = tonumber(iterations_str)

    local calculated = M.hash(dOS, password, salt, callb_per_p)

    M.ITERATIONS = old_iter

    return calculated == stored_hash_str
end

return M

-- EOF