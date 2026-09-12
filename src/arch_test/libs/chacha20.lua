--[[
    "ChaCha20 stream cipher (RFC 7539) algorithm for dOS"
    
    @module chacha20
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

--- BIT32

local bit = bit32
local bxor = bit.bxor
local bor = bit.bor
local band = bit.band
local lshift = bit.lshift
local rshift = bit.rshift

--- CONSTANTS

local C0 = 0x61707865 -- "expa"
local C1 = 0x3320646e -- "nd 3"
local C2 = 0x79622d32 -- "2-by"
local C3 = 0x6b206574 -- "te k"

--- UTILS

@native
local function rot32(v, n)
    return band(bor(lshift(v, n), rshift(v, 32 - n)), 0xFFFFFFFF)
end

@native
local function u32LE(b, i)
    return bor(
        b[i] or 0,
        lshift(b[i + 1] or 0, 8),
        lshift(b[i + 2] or 0, 16),
        lshift(b[i + 3] or 0, 24)
    )
end

@native
local function w32LE(b, i, v)
    b[i] = band(v, 0xFF)
    b[i + 1] = band(rshift(v, 8), 0xFF)
    b[i + 2] = band(rshift(v, 16), 0xFF)
    b[i + 3] = band(rshift(v, 24), 0xFF)
end

@native
local function hexToBytes(hex)
    local t = {}
    for i = 1, #hex, 2 do
        t[#t + 1] = tonumber(hex:sub(i, i + 1), 16) or 0
    end
    return t
end

local function bytesToHex(t)
    local out = table.create(#t)
    for i = 1, #t do
        out[i] = string.format("%02x", t[i])
    end
    return table.concat(out)
end

local function strToBytes(s)
    local t = table.create(#s)
    for i = 1, #s do
        t[i] = s:byte(i)
    end
    return t
end

local function bytesToStr(t)
    local c = table.create(#t)
    for i = 1, #t do
        c[i] = string.char(t[i])
    end
    return table.concat(c)
end

local function randomBytes(n)
    local t = table.create(n)
    for i = 1, n do
        t[i] = math.random(0, 255)
    end
    return t
end

--- CIPHER

@native
local function QR(s, a, b, c, d)
    local sa, sb, sc, sd = s[a], s[b], s[c], s[d]

    sa = band(sa + sb, 0xFFFFFFFF)
    sd = rot32(bxor(sd, sa), 16)
    sc = band(sc + sd, 0xFFFFFFFF)
    sb = rot32(bxor(sb, sc), 12)
    sa = band(sa + sb, 0xFFFFFFFF)
    sd = rot32(bxor(sd, sa), 8)
    sc = band(sc + sd, 0xFFFFFFFF)
    sb = rot32(bxor(sb, sc), 7)

    s[a], s[b], s[c], s[d] = sa, sb, sc, sd
end

@native
local function chachaBlock(key, nonce, ctr)
    -- initial state
    local s = {
        C0,
        C1,
        C2,
        C3,
        u32LE(key, 1),
        u32LE(key, 5),
        u32LE(key, 9),
        u32LE(key, 13),
        u32LE(key, 17),
        u32LE(key, 21),
        u32LE(key, 25),
        u32LE(key, 29),
        band(ctr, 0xFFFFFFFF),
        u32LE(nonce, 1),
        u32LE(nonce, 5),
        u32LE(nonce, 9),
    }

    -- snapshot initial state
    local s0, s1, s2, s3 = s[1], s[2], s[3], s[4]
    local s4, s5, s6, s7 = s[5], s[6], s[7], s[8]
    local s8, s9, s10, s11 = s[9], s[10], s[11], s[12]
    local s12, s13, s14, s15 = s[13], s[14], s[15], s[16]

    -- double rounds
    for _ = 1, 10 do
        -- column rounds
        QR(s, 1, 5, 9, 13)
        QR(s, 2, 6, 10, 14)
        QR(s, 3, 7, 11, 15)
        QR(s, 4, 8, 12, 16)
        -- diagonal rounds
        QR(s, 1, 6, 11, 16)
        QR(s, 2, 7, 12, 13)
        QR(s, 3, 8, 9, 14)
        QR(s, 4, 5, 10, 15)
    end

    -- add initial state
    s[1] = band(s[1] + s0, 0xFFFFFFFF)
    s[2] = band(s[2] + s1, 0xFFFFFFFF)
    s[3] = band(s[3] + s2, 0xFFFFFFFF)
    s[4] = band(s[4] + s3, 0xFFFFFFFF)
    s[5] = band(s[5] + s4, 0xFFFFFFFF)
    s[6] = band(s[6] + s5, 0xFFFFFFFF)
    s[7] = band(s[7] + s6, 0xFFFFFFFF)
    s[8] = band(s[8] + s7, 0xFFFFFFFF)
    s[9] = band(s[9] + s8, 0xFFFFFFFF)
    s[10] = band(s[10] + s9, 0xFFFFFFFF)
    s[11] = band(s[11] + s10, 0xFFFFFFFF)
    s[12] = band(s[12] + s11, 0xFFFFFFFF)
    s[13] = band(s[13] + s12, 0xFFFFFFFF)
    s[14] = band(s[14] + s13, 0xFFFFFFFF)
    s[15] = band(s[15] + s14, 0xFFFFFFFF)
    s[16] = band(s[16] + s15, 0xFFFFFFFF)

    -- serialize to bytes
    local out = table.create(64)
    for i = 1, 16 do
        w32LE(out, (i - 1) * 4 + 1, s[i])
    end
    return out
end

@native
local function chachaXOR(key, nonce, data)
    local len = #data
    local output = table.create(len)
    local ctr = 1 -- RFC 7539

    local i = 1
    while i <= len do
        local block = chachaBlock(key, nonce, ctr)
        ctr = ctr + 1

        local blockEnd = math.min(i + 63, len)
        local bi = 1
        for j = i, blockEnd do
            output[j] = bxor(data[j] or 0, block[bi] or 0)
            bi = bi + 1
        end

        i += 64

        task.wait()
    end

    return output
end

--- API

M.encrypt = true

M.decrypt = false

@native
function M.CHACHA_256(mode, keyHex, data, nonceHex)
    if type(keyHex) ~= "string" or #keyHex ~= 64 then
        logError(
            "[ChaCha20] The secret key must be a 64-char hex string (32 bytes). "
                .. "Got: "
                .. tostring(keyHex and #keyHex or "nil")
        )
        return
    end

    local key = hexToBytes(keyHex)

    -- encrypt
    if mode == M.encrypt then
        local nonce
        if nonceHex then
            if #nonceHex ~= 24 then
                logError(
                    "[ChaCha20] Fixed nonce must be exactly 24 hex chars (12 bytes). Got "
                        .. #nonceHex
                )
                return
            end
            nonce = hexToBytes(nonceHex)
        else
            nonce = randomBytes(12)
        end

        local plainBytes = strToBytes(data)
        local cipherBytes = chachaXOR(key, nonce, plainBytes)

        -- nonce is first 24 hex chars
        return `{bytesToHex(nonce)}{bytesToHex(cipherBytes)}`

    -- decrypt
    else
        -- 24 hex chars = 12 nonce bytes
        if #data < 24 then
            logError(
                "[ChaCha20] Ciphertext too short to contain a 12-byte nonce. "
                    .. "Got "
                    .. #data
                    .. " hex chars (need >= 24)."
            )
            return
        end

        local nonce = hexToBytes(data:sub(1, 24))
        local cipherBytes = hexToBytes(data:sub(25))
        local plainBytes = chachaXOR(key, nonce, cipherBytes)

        return bytesToStr(plainBytes)
    end
end

return M

-- EOF