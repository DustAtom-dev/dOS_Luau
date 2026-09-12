--[[
    "Somewhat optimized SHA-256 algorithm implementation for dOS"
    
    @module sha256
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

local band = bit32.band
local bor = bit32.bor
local bxor = bit32.bxor
local rrotate = bit32.rrotate
local rshift = bit32.rshift
local lshift = bit32.lshift

-- constants
local K = {
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
}

-- initial hash values
local H_INIT = {
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
}

@native
function M.hash(input: string | buffer, asRaw: boolean?): string
    local inputType = typeof(input)
    local len: number

    if inputType == "string" then
        len = string.len(input :: string)
    elseif inputType == "buffer" then
        len = buffer.len(input :: buffer)
    else
        logError("SHA256 input must be a string or buffer.")
    end

    -- pad to 64-byte multiple
    local rem = len % 64
    local padded_len = len - rem + (rem < 56 and 64 or 128)

    local buf = buffer.create(padded_len)

    if inputType == "string" then
        buffer.writestring(buf, 0, input :: string)
    else
        buffer.copy(buf, 0, input :: buffer)
    end

    -- append 1 bit
    buffer.writeu8(buf, len, 0x80)

    -- append length in bits
    local bits = len * 8
    local bits_hi = math.floor(bits / 4294967296)
    local bits_lo = bits % 4294967296

    buffer.writeu8(buf, padded_len - 8, rshift(bits_hi, 24))
    buffer.writeu8(buf, padded_len - 7, band(rshift(bits_hi, 16), 0xFF))
    buffer.writeu8(buf, padded_len - 6, band(rshift(bits_hi, 8), 0xFF))
    buffer.writeu8(buf, padded_len - 5, band(bits_hi, 0xFF))

    buffer.writeu8(buf, padded_len - 4, rshift(bits_lo, 24))
    buffer.writeu8(buf, padded_len - 3, band(rshift(bits_lo, 16), 0xFF))
    buffer.writeu8(buf, padded_len - 2, band(rshift(bits_lo, 8), 0xFF))
    buffer.writeu8(buf, padded_len - 1, band(bits_lo, 0xFF))

    -- init hash vars
    local h0, h1, h2, h3, h4, h5, h6, h7 =
        H_INIT[1],
        H_INIT[2],
        H_INIT[3],
        H_INIT[4],
        H_INIT[5],
        H_INIT[6],
        H_INIT[7],
        H_INIT[8]

    local W = table.create(64, 0)

    -- process chunks
    for chunk_start = 0, padded_len - 1, 64 do
        -- message schedule
        for i = 1, 16 do
            local offset = chunk_start + (i - 1) * 4
            -- read big-endian words
            W[i] = bor(
                lshift(buffer.readu8(buf, offset), 24),
                lshift(buffer.readu8(buf, offset + 1), 16),
                lshift(buffer.readu8(buf, offset + 2), 8),
                buffer.readu8(buf, offset + 3)
            )
        end

        for i = 17, 64 do
            local w15 = W[i - 15]
            local s0 = bxor(rrotate(w15, 7), rrotate(w15, 18), rshift(w15, 3))

            local w2 = W[i - 2]
            local s1 = bxor(rrotate(w2, 17), rrotate(w2, 19), rshift(w2, 10))

            W[i] = band(W[i - 16] + s0 + W[i - 7] + s1, 0xFFFFFFFF)
        end

        -- working variables
        local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7

        -- compression
        for i = 1, 64 do
            local S1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
            -- choice
            local ch = bxor(g, band(e, bxor(f, g)))
            local temp1 = band(h + S1 + ch + K[i] + W[i], 0xFFFFFFFF)

            local S0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
            -- majority
            local maj = bxor(band(a, b), band(c, bxor(a, b)))
            local temp2 = band(S0 + maj, 0xFFFFFFFF)

            h = g
            g = f
            f = e
            e = band(d + temp1, 0xFFFFFFFF)
            d = c
            c = b
            b = a
            a = band(temp1 + temp2, 0xFFFFFFFF)
        end

        -- add to hash
        h0 = band(h0 + a, 0xFFFFFFFF)
        h1 = band(h1 + b, 0xFFFFFFFF)
        h2 = band(h2 + c, 0xFFFFFFFF)
        h3 = band(h3 + d, 0xFFFFFFFF)
        h4 = band(h4 + e, 0xFFFFFFFF)
        h5 = band(h5 + f, 0xFFFFFFFF)
        h6 = band(h6 + g, 0xFFFFFFFF)
        h7 = band(h7 + h, 0xFFFFFFFF)
    end

    -- output
    if asRaw then
        -- raw
        local out = buffer.create(32)

        local function write_be(offset: number, val: number)
            buffer.writeu8(out, offset, rshift(val, 24))
            buffer.writeu8(out, offset + 1, band(rshift(val, 16), 0xFF))
            buffer.writeu8(out, offset + 2, band(rshift(val, 8), 0xFF))
            buffer.writeu8(out, offset + 3, band(val, 0xFF))
        end

        write_be(0, h0)
        write_be(4, h1)
        write_be(8, h2)
        write_be(12, h3)
        write_be(16, h4)
        write_be(20, h5)
        write_be(24, h6)
        write_be(28, h7)

        return buffer.tostring(out)
    else
        -- hex
        return string.format(
            "%08x%08x%08x%08x%08x%08x%08x%08x",
            h0,
            h1,
            h2,
            h3,
            h4,
            h5,
            h6,
            h7
        )
    end
end

return M

-- EOF