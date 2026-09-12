--[[
    "CSS Lexer module for dOS"
    
    @module css_lexer
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


local Lexer = {}
Lexer.__index = Lexer

--- TOKENS

local TokenType = {
    -- value tokens
    IDENT = "IDENT", -- color background-color --custom
    AT_KEYWORD = "AT_KEYWORD", -- @media @keyframes @import
    HASH = "HASH", -- #id  #ff0000 (flag: id | unrestricted)
    STRING = "STRING", -- "hello" 'world'
    BAD_STRING = "BAD_STRING", -- unclosed string
    URL = "URL", -- url(https://...)
    BAD_URL = "BAD_URL", -- malformed url
    NUMBER = "NUMBER", -- 42 3.14 -1 +.5 (flag: integer | number)
    DIMENSION = "DIMENSION", -- 10px 1.5em 360deg (number + unit)
    PERCENTAGE = "PERCENTAGE", -- 50% 100%
    FUNCTION = "FUNCTION", -- rgb var calc url

    -- structural tokens
    WHITESPACE = "WHITESPACE", -- one or more whitespace chars collapsed
    CDO = "CDO", -- <!--
    CDC = "CDC", -- -->
    COLON = "COLON", -- :
    SEMICOLON = "SEMICOLON", -- ;
    COMMA = "COMMA", -- ,
    LBRACKET = "LBRACKET", -- [
    RBRACKET = "RBRACKET", -- ]
    LPAREN = "LPAREN", -- (
    RPAREN = "RPAREN", -- )
    LBRACE = "LBRACE", -- {
    RBRACE = "RBRACE", -- }

    DELIM = "DELIM", -- + > ~ | ^ $ * = ! . #  ...

    -- Meta
    COMMENT = "COMMENT", -- /* ... */ (only emitted when preserveComments = true)
    EOF = "EOF", -- end of input
}

--- UNITS

-- absolute length units
local ABSOLUTE_UNITS = {
    px = true,
    cm = true,
    mm = true,
    ["in"] = true,
    pt = true,
    pc = true,
    q = true,
}

-- relative length units
local RELATIVE_UNITS = {
    -- font-relative
    em = true,
    rem = true,
    ex = true,
    ch = true,
    cap = true,
    ic = true,
    lh = true,
    rlh = true,
    -- classic viewport
    vw = true,
    vh = true,
    vmin = true,
    vmax = true,
    vi = true,
    vb = true,
    -- small / large / dynamic viewport
    svw = true,
    svh = true,
    svmin = true,
    svmax = true,
    svi = true,
    svb = true,
    lvw = true,
    lvh = true,
    lvmin = true,
    lvmax = true,
    lvi = true,
    lvb = true,
    dvw = true,
    dvh = true,
    dvmin = true,
    dvmax = true,
    dvi = true,
    dvb = true,
    -- flexible
    fr = true,
    -- container query units
    cqw = true,
    cqh = true,
    cqi = true,
    cqb = true,
    cqmin = true,
    cqmax = true,
}

-- angle units
local ANGLE_UNITS = {
    deg = true,
    rad = true,
    grad = true,
    turn = true,
}

-- time units
local TIME_UNITS = {
    s = true,
    ms = true,
}

-- frequency units
local FREQUENCY_UNITS = {
    hz = true,
    khz = true,
}

-- resolution units
local RESOLUTION_UNITS = {
    dpi = true,
    dpcm = true,
    dppx = true,
}

-- container query units
local CONTAINER_UNITS = {
    cqw = true,
    cqh = true,
    cqi = true,
    cqb = true,
    cqmin = true,
    cqmax = true,
}

-- viewport variant units
local VIEWPORT_V_UNITS = {
    svw = true,
    svh = true,
    svi = true,
    svb = true,
    svmin = true,
    svmax = true,
    lvw = true,
    lvh = true,
    lvi = true,
    lvb = true,
    lvmin = true,
    lvmax = true,
    dvw = true,
    dvh = true,
    dvi = true,
    dvb = true,
    dvmin = true,
    dvmax = true,
}

local function classifyUnit(unit)
    if ABSOLUTE_UNITS[unit] or RELATIVE_UNITS[unit] then
        return "length"
    elseif CONTAINER_UNITS[unit] then
        return "length"
    elseif VIEWPORT_V_UNITS[unit] then
        return "length"
    elseif ANGLE_UNITS[unit] then
        return "angle"
    elseif TIME_UNITS[unit] then
        return "time"
    elseif FREQUENCY_UNITS[unit] then
        return "frequency"
    elseif RESOLUTION_UNITS[unit] then
        return "resolution"
    else
        return "unknown"
    end
end

--- HELPERS

local function isWhitespace(c)
    return c == " " or c == "\t" or c == "\n" or c == "\r" or c == "\f"
end

local function isDigit(c)
    return c ~= nil and c >= "0" and c <= "9"
end

local function isHexDigit(c)
    return c ~= nil
        and (
            (c >= "0" and c <= "9")
            or (c >= "a" and c <= "f")
            or (c >= "A" and c <= "F")
        )
end

local function isNameStart(c)
    if c == nil then
        return false
    end
    local b = c:byte()
    -- a-z, A-Z, underscore, or non-ascii
    return (b >= 97 and b <= 122) -- a-z
        or (b >= 65 and b <= 90) -- A-Z
        or b == 95 -- _
        or b >= 128 -- non-ascii
end

local function isNameChar(c)
    if c == nil then
        return false
    end
    local b = c:byte()
    return isNameStart(c) or isDigit(c) or b == 45 -- also allows hyphen (-)
end

local function isValidEscape(a, b)
    return a == "\\" and b ~= "\n" and b ~= "\r" and b ~= "\f" and b ~= nil
end

local function wouldStartIdent(a, b, c)
    if a == "-" then
        -- -name-start or -- (custom property)
        return isNameStart(b) or b == "-" or isValidEscape(b, c)
    elseif isNameStart(a) then
        return true
    elseif a == "\\" then
        return isValidEscape(a, b)
    end
    return false
end

local function wouldStartNumber(a, b, c)
    if a == "+" or a == "-" then
        return isDigit(b) or (b == "." and isDigit(c))
    elseif a == "." then
        return isDigit(b)
    end
    return isDigit(a)
end

--- UNICODE

local function codePointToUTF8(cp)
    if cp <= 0 or (cp >= 0xD800 and cp <= 0xDFFF) or cp > 0x10FFFF then
        return "\239\191\189" -- U+FFFD replacement character
    elseif cp < 0x80 then
        return string.char(cp)
    elseif cp < 0x800 then
        return string.char(0xC0 + math.floor(cp / 0x40), 0x80 + (cp % 0x40))
    elseif cp < 0x10000 then
        return string.char(
            0xE0 + math.floor(cp / 0x1000),
            0x80 + (math.floor(cp / 0x40) % 0x40),
            0x80 + (cp % 0x40)
        )
    else
        return string.char(
            0xF0 + math.floor(cp / 0x40000),
            0x80 + (math.floor(cp / 0x1000) % 0x40),
            0x80 + (math.floor(cp / 0x40) % 0x40),
            0x80 + (cp % 0x40)
        )
    end
end

--- LEXER

function Lexer.new(source)
    local self = setmetatable({}, Lexer)

    -- source
    self.source = source or ""
    self.length = #self.source

    -- cursor
    self.position = 1
    self.line = 1
    self.column = 1

    -- token start snapshot
    self.tokenStart = 1
    self.tokenLine = 1
    self.tokenColumn = 1

    -- output
    self.tokens = {}

    -- configuration
    self.yieldInterval = 2000 -- task.wait() every N tokens (CPU budget)
    self.preserveComments = false -- emit COMMENT tokens when true
    self.collapseWhitespace = true -- merge adjacent whitespace into one token

    return self
end

--- CURSOR

function Lexer:current()
    if self.position > self.length then
        return nil
    end
    return self.source:sub(self.position, self.position)
end

function Lexer:peek(offset)
    offset = offset or 1
    local p = self.position + offset
    if p < 1 or p > self.length then
        return nil
    end
    return self.source:sub(p, p)
end

function Lexer:peekString(len)
    return self.source:sub(
        self.position,
        math.min(self.position + len - 1, self.length)
    )
end

function Lexer:isAtEnd()
    return self.position > self.length
end

function Lexer:advance(count)
    count = count or 1
    for _ = 1, count do
        if self.position > self.length then
            break
        end

        local c = self.source:sub(self.position, self.position)
        if c == "\n" or c == "\f" then
            self.line = self.line + 1
            self.column = 1
        elseif c == "\r" then
            if self:peek(1) ~= "\n" then
                self.line = self.line + 1
                self.column = 1
            end
        else
            self.column = self.column + 1
        end

        self.position = self.position + 1
    end
end

function Lexer:skipWhitespace()
    while not self:isAtEnd() and isWhitespace(self:current()) do
        self:advance()
    end
end

function Lexer:markTokenStart()
    self.tokenStart = self.position
    self.tokenLine = self.line
    self.tokenColumn = self.column
end

function Lexer:matchString(str)
    return self:peekString(#str) == str
end

--- EMIT

function Lexer:createToken(tokenType, value, extra)
    local tok = {
        type = tokenType,
        value = value,
        line = self.tokenLine,
        column = self.tokenColumn,
        position = self.tokenStart,
    }
    if extra then
        for k, v in pairs(extra) do
            tok[k] = v
        end
    end
    return tok
end

function Lexer:emit(token)
    table.insert(self.tokens, token)
end

--- ESCAPES

function Lexer:consumeEscape()
    self:advance() -- skip '\'

    if self:isAtEnd() then
        return "\239\191\189"
    end

    local c = self:current()

    if isHexDigit(c) then
        -- up to 6 hex digits
        local hex = ""
        local limit = 6
        while not self:isAtEnd() and isHexDigit(self:current()) and limit > 0 do
            hex = hex .. self:current()
            self:advance()
            limit = limit - 1
        end
        -- consume one trailing whitespace
        if not self:isAtEnd() and isWhitespace(self:current()) then
            self:advance()
        end
        -- single-hex escapes like \a that map to control chars
        -- are usually typos
        -- keep the literal letter instead
        local cp = tonumber(hex, 16)
        if #hex == 1 and cp and cp < 0x20 and isHexDigit(c) then
            return c:lower()
        end
        return codePointToUTF8(cp or 0xFFFD)
    elseif c == "\n" or c == "\r" or c == "\f" then
        return "\239\191\189"
    else
        -- any other char is literal i guess
        local result = c
        self:advance()
        return result
    end
end

--- IDENT

function Lexer:consumeName()
    local result = ""
    while not self:isAtEnd() do
        local c = self:current()
        if isNameChar(c) then
            result = result .. c
            self:advance()
        elseif isValidEscape(c, self:peek(1)) then
            result = result .. self:consumeEscape()
        else
            break
        end
    end
    return result
end

--- NUMBER

function Lexer:consumeNumeric()
    local raw = ""

    -- optional sign
    local c = self:current()
    if c == "+" or c == "-" then
        raw = raw .. c
        self:advance()
    end

    -- integer part
    while not self:isAtEnd() and isDigit(self:current()) do
        raw = raw .. self:current()
        self:advance()
    end

    -- decimal part
    local flag = "integer"
    if self:current() == "." and isDigit(self:peek(1)) then
        flag = "number"
        raw = raw .. "."
        self:advance() -- consume '.'
        while not self:isAtEnd() and isDigit(self:current()) do
            raw = raw .. self:current()
            self:advance()
        end
    end

    -- exponent part
    local e = self:current()
    if e == "e" or e == "E" then
        local next1 = self:peek(1)
        local next2 = self:peek(2)
        local exponentStartOk = isDigit(next1)
            or ((next1 == "+" or next1 == "-") and isDigit(next2))

        if exponentStartOk then
            flag = "number"
            raw = raw .. e
            self:advance() -- consume 'e'/'E'

            if self:current() == "+" or self:current() == "-" then
                raw = raw .. self:current()
                self:advance()
            end

            while not self:isAtEnd() and isDigit(self:current()) do
                raw = raw .. self:current()
                self:advance()
            end
        end
    end

    return raw, tonumber(raw) or 0, flag
end

--- URL

function Lexer:consumeBareURL()
    self:skipWhitespace()

    local url = ""

    while not self:isAtEnd() do
        local c = self:current()

        if c == ")" then
            self:advance() -- consume ')'
            return TokenType.URL, url
        elseif isWhitespace(c) then
            -- trailing whitespace before ')' is allowed
            self:skipWhitespace()
            if self:current() == ")" then
                self:advance()
                return TokenType.URL, url
            else
                -- not ')' after whitespace -> bad url
                self:consumeBadURLRemnants()
                return TokenType.BAD_URL, url
            end
        elseif c == '"' or c == "'" or c == "(" then
            -- never valid in an unquoted url
            self:consumeBadURLRemnants()
            return TokenType.BAD_URL, url
        elseif c == "\\" then
            if isValidEscape(c, self:peek(1)) then
                url = url .. self:consumeEscape()
            else
                self:consumeBadURLRemnants()
                return TokenType.BAD_URL, url
            end
        else
            url = url .. c
            self:advance()
        end
    end

    -- EOF without closing paren
    return TokenType.BAD_URL, url
end

function Lexer:consumeBadURLRemnants()
    while not self:isAtEnd() do
        local c = self:current()
        if c == ")" then
            self:advance()
            return
        elseif isValidEscape(c, self:peek(1)) then
            self:consumeEscape() -- consume and discard
        else
            self:advance()
        end
    end
end

--- STRING

function Lexer:consumeString()
    local quote = self:current()
    self:advance() -- consume opening quote

    local result = ""

    while not self:isAtEnd() do
        local c = self:current()

        if c == quote then
            self:advance() -- consume closing quote
            return TokenType.STRING, result
        elseif c == "\n" or c == "\r" or c == "\f" then
            -- newline inside a string -> BAD_STRING
            -- leave the newline for the next token
            return TokenType.BAD_STRING, result
        elseif c == "\\" then
            local next = self:peek(1)
            if next == "\n" or next == "\r" or next == "\f" then
                -- escaped newline -> line continuation
                self:advance() -- skip '\'
                self:advance() -- skip newline (\r\n counts as one)
                if next == "\r" and self:current() == "\n" then
                    self:advance()
                end
            elseif next == nil then
                -- EOF after backslash -> replacement char
                result = result .. "\239\191\189"
                self:advance()
            else
                result = result .. self:consumeEscape()
            end
        else
            result = result .. c
            self:advance()
        end
    end

    -- EOF without closing quote -> BAD_STRING
    return TokenType.BAD_STRING, result
end

--- COMMENT

function Lexer:consumeComment()
    self:advance() -- '/'
    self:advance() -- '*'

    local raw = "/*"

    while not self:isAtEnd() do
        local c = self:current()
        if c == "*" and self:peek(1) == "/" then
            raw = raw .. "*/"
            self:advance() -- '*'
            self:advance() -- '/'
            return raw
        end
        raw = raw .. c
        self:advance()
    end

    -- unclosed comment
    return raw
end

--- DISPATCH

function Lexer:nextToken()
    self:markTokenStart()

    if self:isAtEnd() then
        return self:createToken(TokenType.EOF, "")
    end

    local c = self:current()
    local c2 = self:peek(1)
    local c3 = self:peek(2)

    -- comments
    if c == "/" and c2 == "*" then
        local raw = self:consumeComment()
        if self.preserveComments then
            -- strip delimiters
            local inner = raw:sub(3, #raw - 2)
            return self:createToken(TokenType.COMMENT, inner)
        end

        return self:nextToken()
    end

    -- whitespace
    if isWhitespace(c) then
        while not self:isAtEnd() and isWhitespace(self:current()) do
            self:advance()
        end
        return self:createToken(TokenType.WHITESPACE, " ")
    end

    -- string
    if c == '"' or c == "'" then
        local tokType, value = self:consumeString()
        return self:createToken(tokType, value, { quote = c })
    end

    -- hash
    if c == "#" then
        self:advance() -- consume '#'
        if isNameChar(c2) or isValidEscape(c2, c3) then
            -- pure hex names get the "unrestricted" flag so the renderer
            -- can tell colors apart from ids
            local name = self:consumeName()
            local flag
            if name:match("^[0-9a-fA-F]+$") then
                -- all hex digits -> color literal
                flag = "unrestricted"
            elseif isNameStart(name:sub(1, 1)) or name:sub(1, 1) == "-" then
                -- name-start or '-' -> valid ident
                flag = "id"
            else
                flag = "unrestricted" :: any
            end
            return self:createToken(TokenType.HASH, name, { flag = flag })
        else
            -- '#' -> DELIM
            return self:createToken(TokenType.DELIM, "#")
        end
    end

    if c == "+" then
        if wouldStartNumber(c, c2, c3) then
            local raw, num, flag = self:consumeNumeric()
            return self:numericToken(raw, num, flag)
        end
        self:advance()
        return self:createToken(TokenType.DELIM, "+")
    end

    if c == "-" then
        if wouldStartNumber(c, c2, c3) then
            local raw, num, flag = self:consumeNumeric()
            return self:numericToken(raw, num, flag)
        elseif self:matchString("-->") then
            self:advance(3)
            return self:createToken(TokenType.CDC, "-->")
        elseif wouldStartIdent(c, c2, c3) then
            local name = self:consumeName()
            return self:identLike(name)
        end
        self:advance()
        return self:createToken(TokenType.DELIM, "-")
    end

    if c == "." then
        if wouldStartNumber(c, c2, c3) then
            local raw, num, flag = self:consumeNumeric()
            return self:numericToken(raw, num, flag)
        end
        self:advance()
        return self:createToken(TokenType.DELIM, ".")
    end

    if c == "<" then
        if self:matchString("<!--") then
            self:advance(4)
            return self:createToken(TokenType.CDO, "<!--")
        end
        self:advance()
        return self:createToken(TokenType.DELIM, "<")
    end

    if c == "@" then
        self:advance() -- consume '@'
        local c2n = self:current()
        local c3n = self:peek(1)
        local c4n = self:peek(2)
        if wouldStartIdent(c2n, c3n, c4n) then
            local name = self:consumeName()
            return self:createToken(TokenType.AT_KEYWORD, name)
        end
        return self:createToken(TokenType.DELIM, "@")
    end

    if c == "\\" then
        if isValidEscape(c, c2) then
            -- valid escape start -> ident
            local name = self:consumeName()
            return self:identLike(name)
        end
        -- lone backslash is a parse error
        self:advance()
        return self:createToken(TokenType.DELIM, "\\")
    end

    if isDigit(c) then
        local raw, num, flag = self:consumeNumeric()
        return self:numericToken(raw, num, flag)
    end

    if isNameStart(c) then
        local name = self:consumeName()
        return self:identLike(name)
    end

    self:advance()

    if c == ":" then
        return self:createToken(TokenType.COLON, ":")
    end
    if c == ";" then
        return self:createToken(TokenType.SEMICOLON, ";")
    end
    if c == "," then
        return self:createToken(TokenType.COMMA, ",")
    end
    if c == "[" then
        return self:createToken(TokenType.LBRACKET, "[")
    end
    if c == "]" then
        return self:createToken(TokenType.RBRACKET, "]")
    end
    if c == "(" then
        return self:createToken(TokenType.LPAREN, "(")
    end
    if c == ")" then
        return self:createToken(TokenType.RPAREN, ")")
    end
    if c == "{" then
        return self:createToken(TokenType.LBRACE, "{")
    end
    if c == "}" then
        return self:createToken(TokenType.RBRACE, "}")
    end

    return self:createToken(TokenType.DELIM, c)
end

--- NUMERIC

function Lexer:numericToken(raw, num, flag)
    local c = self:current()

    -- percentage
    if c == "%" then
        self:advance()
        return self:createToken(TokenType.PERCENTAGE, num, {
            raw = raw,
            flag = flag,
        })
    end

    -- dimension (ident right after digits)
    local c2n = self:peek(1)
    local c3n = self:peek(2)
    if wouldStartIdent(c, c2n, c3n) then
        local unit = self:consumeName()
        return self:createToken(TokenType.DIMENSION, num, {
            raw = raw,
            flag = flag,
            unit = unit,
            unitLower = unit:lower(),
            unitCategory = classifyUnit(unit:lower()),
        })
    end

    -- plain number
    return self:createToken(TokenType.NUMBER, num, {
        raw = raw,
        flag = flag,
    })
end

--- IDENTLIKE

function Lexer:identLike(name)
    -- '(' follows -> function or url
    if self:current() == "(" then
        self:advance() -- consume '('

        if name:lower() == "url" then
            -- peek past whitespace for a quote
            local look = self.position
            while look <= self.length do
                local byte = self.source:sub(look, look)
                if isWhitespace(byte) then
                    look = look + 1
                else
                    if byte == '"' or byte == "'" then
                        -- url("...") is a function token
                        return self:createToken(TokenType.FUNCTION, name)
                    end
                    break
                end
            end

            -- bare url() -> consume the body
            self:skipWhitespace()
            local tokType, urlValue = self:consumeBareURL()
            return self:createToken(tokType, urlValue, { function_name = name })
        end

        -- generic function
        return self:createToken(TokenType.FUNCTION, name)
    end

    -- plain identifier
    return self:createToken(TokenType.IDENT, name)
end

function Lexer:tokenize()
    self.tokens = {}
    local tokenCount = 0

    while not self:isAtEnd() do
        local tok = self:nextToken()

        if
            not (
                self.collapseWhitespace
                and tok.type == TokenType.WHITESPACE
                and #self.tokens > 0
                and self.tokens[#self.tokens].type == TokenType.WHITESPACE
            )
        then
            self:emit(tok)
            tokenCount = tokenCount + 1
        end

        -- save cpu
        if tokenCount % self.yieldInterval == 0 then
            if task and task.wait then
                task.wait()
            end
        end
    end

    self:markTokenStart()
    self:emit(self:createToken(TokenType.EOF, ""))

    return self.tokens
end

--- CONFIG

function Lexer:setPreserveComments(preserve)
    self.preserveComments = preserve
end

function Lexer:setCollapseWhitespace(collapse)
    self.collapseWhitespace = collapse
end

function Lexer:setYieldInterval(interval)
    self.yieldInterval = interval
end

function Lexer:getPosition()
    return {
        position = self.position,
        line = self.line,
        column = self.column,
    }
end

--- API

function Lexer.getTokenTypes()
    return TokenType
end

function Lexer.getUnitClassifier()
    return classifyUnit
end

function Lexer.parse(source, options)
    local lexer = Lexer.new(source)
    if options then
        if options.preserveComments ~= nil then
            lexer:setPreserveComments(options.preserveComments)
        end
        if options.collapseWhitespace ~= nil then
            lexer:setCollapseWhitespace(options.collapseWhitespace)
        end
        if options.yieldInterval then
            lexer:setYieldInterval(options.yieldInterval)
        end
    end
    local tokens = lexer:tokenize()
    return tokens, TokenType
end

function Lexer.create(source, options)
    local lexer = Lexer.new(source)
    if options then
        if options.preserveComments ~= nil then
            lexer:setPreserveComments(options.preserveComments)
        end
        if options.collapseWhitespace ~= nil then
            lexer:setCollapseWhitespace(options.collapseWhitespace)
        end
        if options.yieldInterval then
            lexer:setYieldInterval(options.yieldInterval)
        end
    end
    return lexer
end

return Lexer

-- EOF