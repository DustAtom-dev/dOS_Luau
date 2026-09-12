--[[
    "HTML Lexer module for dOS"
    
    @module html_lexer
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
    DOCTYPE = "DOCTYPE", -- <!DOCTYPE ...>
    COMMENT = "COMMENT", -- <!-- ... -->
    CDATA = "CDATA", -- <![CDATA[ ... ]]>
    START_TAG = "START_TAG", -- <tagname ...>
    END_TAG = "END_TAG", -- </tagname>
    TEXT = "TEXT", -- text content
    RAW_TEXT = "RAW_TEXT", -- script/style content
    EOF = "EOF", -- end of input
}

--- ELEMENTS

-- no children, no closing tag
local VOID_ELEMENTS = {
    area = true,
    base = true,
    br = true,
    col = true,
    embed = true,
    hr = true,
    img = true,
    input = true,
    link = true,
    meta = true,
    source = true,
    track = true,
    wbr = true,
    -- obsolete but still
    param = true,
    command = true,
    keygen = true,
}

-- content is plain text
local RAW_TEXT_ELEMENTS = {
    script = true,
    style = true,
    -- rcdata elements (entities decoded, no tags)
    textarea = true,
    title = true,
}

local TRULY_RAW_ELEMENTS = {
    script = true,
    style = true,
}

--- ENTITIES

local NAMED_ENTITIES = {
    -- ascii
    amp = "\038", -- &
    lt = "\060", -- <
    gt = "\062", -- >
    quot = "\034", -- "
    apos = "\039", -- '

    -- latin supplement
    nbsp = "\194\160", -- non-breaking space
    iexcl = "\194\161", -- ¡
    cent = "\194\162", -- ¢
    pound = "\194\163", -- £
    curren = "\194\164", -- ¤
    yen = "\194\165", -- ¥
    brvbar = "\194\166", -- ¦
    sect = "\194\167", -- §
    uml = "\194\168", -- ¨
    copy = "\194\169", -- ©
    ordf = "\194\170", -- ª
    laquo = "\194\171", -- «
    ["not"] = "\194\172", -- ¬
    shy = "\194\173", -- soft hyphen
    reg = "\194\174", -- ®
    macr = "\194\175", -- ¯
    deg = "\194\176", -- °
    plusmn = "\194\177", -- ±
    sup2 = "\194\178", -- ²
    sup3 = "\194\179", -- ³
    acute = "\194\180", -- ´
    micro = "\194\181", -- µ
    para = "\194\182", -- ¶
    middot = "\194\183", -- ·
    cedil = "\194\184", -- ¸
    sup1 = "\194\185", -- ¹
    ordm = "\194\186", -- º
    raquo = "\194\187", -- »
    frac14 = "\194\188", -- ¼
    frac12 = "\194\189", -- ½
    frac34 = "\194\190", -- ¾
    iquest = "\194\191", -- ¿

    -- latin extended a
    Agrave = "\195\128",
    Aacute = "\195\129",
    Acirc = "\195\130",
    Atilde = "\195\131",
    Auml = "\195\132",
    Aring = "\195\133",
    AElig = "\195\134",
    Ccedil = "\195\135",
    Egrave = "\195\136",
    Eacute = "\195\137",
    Ecirc = "\195\138",
    Euml = "\195\139",
    Igrave = "\195\140",
    Iacute = "\195\141",
    Icirc = "\195\142",
    Iuml = "\195\143",
    ETH = "\195\144",
    Ntilde = "\195\145",
    Ograve = "\195\146",
    Oacute = "\195\147",
    Ocirc = "\195\148",
    Otilde = "\195\149",
    Ouml = "\195\150",
    times = "\195\151", -- ×
    Oslash = "\195\152",
    Ugrave = "\195\153",
    Uacute = "\195\154",
    Ucirc = "\195\155",
    Uuml = "\195\156",
    Yacute = "\195\157",
    THORN = "\195\158",
    szlig = "\195\159",
    agrave = "\195\160",
    aacute = "\195\161",
    acirc = "\195\162",
    atilde = "\195\163",
    auml = "\195\164",
    aring = "\195\165",
    aelig = "\195\166",
    ccedil = "\195\167",
    egrave = "\195\168",
    eacute = "\195\169",
    ecirc = "\195\170",
    euml = "\195\171",
    igrave = "\195\172",
    iacute = "\195\173",
    icirc = "\195\174",
    iuml = "\195\175",
    eth = "\195\176",
    ntilde = "\195\177",
    ograve = "\195\178",
    oacute = "\195\179",
    ocirc = "\195\180",
    otilde = "\195\181",
    ouml = "\195\182",
    divide = "\195\183", -- ÷
    oslash = "\195\184",
    ugrave = "\195\185",
    uacute = "\195\186",
    ucirc = "\195\187",
    uuml = "\195\188",
    yacute = "\195\189",
    thorn = "\195\190",
    yuml = "\195\191",

    -- greek letters
    Alpha = "\206\145",
    Beta = "\206\146",
    Gamma = "\206\147",
    Delta = "\206\148",
    Epsilon = "\206\149",
    Zeta = "\206\150",
    Eta = "\206\151",
    Theta = "\206\152",
    Iota = "\206\153",
    Kappa = "\206\154",
    Lambda = "\206\155",
    Mu = "\206\156",
    Nu = "\206\157",
    Xi = "\206\158",
    Omicron = "\206\159",
    Pi = "\206\160",
    Rho = "\206\161",
    Sigma = "\206\163",
    Tau = "\206\164",
    Upsilon = "\206\165",
    Phi = "\206\166",
    Chi = "\206\167",
    Psi = "\206\168",
    Omega = "\206\169",
    alpha = "\206\177",
    beta = "\206\178",
    gamma = "\206\179",
    delta = "\206\180",
    epsilon = "\206\181",
    zeta = "\206\182",
    eta = "\206\183",
    theta = "\206\184",
    iota = "\206\185",
    kappa = "\206\186",
    lambda = "\206\187",
    mu = "\206\188",
    nu = "\206\189",
    xi = "\206\190",
    omicron = "\206\191",
    pi = "\207\128",
    rho = "\207\129",
    sigmaf = "\207\130",
    sigma = "\207\131",
    tau = "\207\132",
    upsilon = "\207\133",
    phi = "\207\134",
    chi = "\207\135",
    psi = "\207\136",
    omega = "\207\137",

    -- math and technical
    forall = "\226\136\128", -- ∀
    part = "\226\136\130", -- ∂
    exist = "\226\136\131", -- ∃
    empty = "\226\136\133", -- ∅
    nabla = "\226\136\135", -- ∇
    isin = "\226\136\136", -- ∈
    notin = "\226\136\137", -- ∉
    ni = "\226\136\139", -- ∋
    prod = "\226\136\143", -- ∏
    sum = "\226\136\145", -- ∑
    minus = "\226\136\146", -- −
    lowast = "\226\136\151", -- ∗
    radic = "\226\136\154", -- √
    prop = "\226\136\157", -- ∝
    infin = "\226\136\158", -- ∞
    ang = "\226\136\160", -- ∠
    ["and"] = "\226\136\167", -- ∧
    ["or"] = "\226\136\168", -- ∨
    cap = "\226\136\169", -- ∩
    cup = "\226\136\170", -- ∪
    int = "\226\136\171", -- ∫
    there4 = "\226\136\180", -- ∴
    sim = "\226\136\188", -- ∼
    cong = "\226\137\133", -- ≅
    asymp = "\226\137\136", -- ≈
    ne = "\226\137\160", -- ≠
    equiv = "\226\137\161", -- ≡
    le = "\226\137\164", -- ≤
    ge = "\226\137\165", -- ≥
    sub = "\226\138\130", -- ⊂
    sup = "\226\138\131", -- ⊃
    nsub = "\226\138\132", -- ⊄
    sube = "\226\138\134", -- ⊆
    supe = "\226\138\135", -- ⊇
    oplus = "\226\138\149", -- ⊕
    otimes = "\226\138\151", -- ⊗
    perp = "\226\138\165", -- ⊥
    sdot = "\226\139\133", -- ⋅

    -- punctuation and symbols
    bull = "\226\128\162", -- •
    hellip = "\226\128\166", -- …
    prime = "\226\128\178", -- ′
    Prime = "\226\128\179", -- ″
    oline = "\226\128\190", -- ‾
    frasl = "\226\129\132", -- ⁄
    trade = "\226\132\162", -- ™
    larr = "\226\134\144", -- ←
    uarr = "\226\134\145", -- ↑
    rarr = "\226\134\146", -- →
    darr = "\226\134\147", -- ↓
    harr = "\226\134\148", -- ↔
    crarr = "\226\134\181", -- ↵
    lArr = "\226\135\144", -- ⇐
    uArr = "\226\135\145", -- ⇑
    rArr = "\226\135\146", -- ⇒
    dArr = "\226\135\147", -- ⇓
    hArr = "\226\135\148", -- ⇔

    -- currency
    euro = "\226\130\172", -- €

    -- quotation
    lsquo = "\226\128\152", -- '
    rsquo = "\226\128\153", -- '
    sbquo = "\226\128\154", -- ‚
    ldquo = "\226\128\156", -- "
    rdquo = "\226\128\157", -- "
    bdquo = "\226\128\158", -- „
    dagger = "\226\128\160", -- †
    Dagger = "\226\128\161", -- ‡
    permil = "\226\128\176", -- ‰

    -- card suits
    spades = "\226\153\160", -- ♠
    clubs = "\226\153\163", -- ♣
    hearts = "\226\153\165", -- ♥
    diams = "\226\153\166", -- ♦

    -- spacing
    ensp = "\226\128\130", -- en space
    emsp = "\226\128\131", -- em space
    thinsp = "\226\128\137", -- thin space
    zwnj = "\226\128\140", -- zero-width non-joiner
    zwj = "\226\128\141", -- zero-width joiner
    lrm = "\226\128\142", -- left-to-right mark
    rlm = "\226\128\143", -- right-to-left mark
    ndash = "\226\128\147", -- –
    mdash = "\226\128\148", -- —
}

--- HELPERS

local function codePointToUTF8(codePoint)
    if codePoint < 0 then
        return "\239\191\189" -- replacement character
    elseif codePoint < 0x80 then
        return string.char(codePoint)
    elseif codePoint < 0x800 then
        return string.char(
            0xC0 + math.floor(codePoint / 0x40),
            0x80 + (codePoint % 0x40)
        )
    elseif codePoint < 0x10000 then
        return string.char(
            0xE0 + math.floor(codePoint / 0x1000),
            0x80 + (math.floor(codePoint / 0x40) % 0x40),
            0x80 + (codePoint % 0x40)
        )
    elseif codePoint < 0x110000 then
        return string.char(
            0xF0 + math.floor(codePoint / 0x40000),
            0x80 + (math.floor(codePoint / 0x1000) % 0x40),
            0x80 + (math.floor(codePoint / 0x40) % 0x40),
            0x80 + (codePoint % 0x40)
        )
    else
        return "\239\191\189" -- replacement character
    end
end

local function isWhitespace(char)
    return char == " "
        or char == "\t"
        or char == "\n"
        or char == "\r"
        or char == "\f"
end

local function isTagNameStart(char)
    if not char then
        return false
    end

    return char:match("[A-Za-z]") ~= nil
end

local function isTagNameChar(char)
    if not char then
        return false
    end

    return char:match("[A-Za-z0-9%-_:.]") ~= nil
end

local function isAttributeNameStart(char)
    if not char then
        return false
    end

    return char:match("[A-Za-z_:]") ~= nil or char:byte() > 127
end

local function isAttributeNameChar(char)
    if not char then
        return false
    end

    local excluded = {
        ['"'] = true,
        ["'"] = true,
        ["="] = true,
        ["<"] = true,
        [">"] = true,
        ["/"] = true,
    }

    return not isWhitespace(char) and not excluded[char]
end

--- LEXER

function Lexer.new(source)
    local self = setmetatable({}, Lexer)

    self.source = source or ""
    self.length = #self.source

    self.position = 1
    self.line = 1
    self.column = 1

    self.tokenStart = 1
    self.tokenLine = 1
    self.tokenColumn = 1

    self.tokens = {}

    self.yieldInterval = 2000
    self.decodeEntities = true
    self.skipWhitespaceOnlyText = false

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
    local pos = self.position + offset

    if pos < 1 or pos > self.length then
        return nil
    end

    return self.source:sub(pos, pos)
end

function Lexer:peekString(len)
    local endPos = math.min(self.position + len - 1, self.length)
    return self.source:sub(self.position, endPos)
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

        local char = self.source:sub(self.position, self.position)

        if char == "\n" then
            self.line = self.line + 1
            self.column = 1
        elseif char == "\r" then
            -- \r\n counts as one line break
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

function Lexer:matchString(str, caseSensitive)
    local substr = self:peekString(#str)

    if caseSensitive then
        return substr == str
    end

    return substr:lower() == str:lower()
end

--- EMIT

function Lexer:createToken(tokenType, value, extra)
    local token = {
        type = tokenType,
        value = value,
        line = self.tokenLine,
        column = self.tokenColumn,
        position = self.tokenStart,
    }

    if extra then
        for key, val in pairs(extra) do
            token[key] = val
        end
    end

    return token
end

function Lexer:emit(token)
    table.insert(self.tokens, token)
end

--- DECODE

function Lexer:decodeCharacterReference()
    self:advance() -- skip '&'

    local refContent = ""
    local maxLen = 32 -- max entity length

    -- collect until ';' or invalid char
    while not self:isAtEnd() and #refContent < maxLen do
        local char = self:current()

        if char == ";" then
            self:advance() -- consume ';'
            break
        elseif isWhitespace(char) or char == "<" or char == "&" then
            -- invalid reference -> literal text
            return "&" .. refContent
        else
            refContent = refContent .. char
            self:advance()
        end
    end

    if refContent == "" then
        return "&"
    end

    local hadSemicolon = (
        self.source:sub(self.position - 1, self.position - 1) == ";"
    )

    if not hadSemicolon then
        -- no semicolon -> return as literal
        return "&" .. refContent
    end

    -- numeric reference
    if refContent:sub(1, 1) == "#" then
        local codePoint = nil

        if refContent:sub(2, 2):lower() == "x" then
            -- hex -> &#xHHHH;
            local hexValue = refContent:sub(3)
            if hexValue:match("^[0-9A-Fa-f]+$") then
                codePoint = tonumber(hexValue, 16)
            end
        else
            -- decimal -> &#DDDD;
            local decValue = refContent:sub(2)
            if decValue:match("^[0-9]+$") then
                codePoint = tonumber(decValue, 10)
            end
        end

        if codePoint then
            -- special cases
            if codePoint == 0 then
                return "\239\191\189" -- replacement character
            elseif codePoint >= 0xD800 and codePoint <= 0xDFFF then
                return "\239\191\189" -- surrogate pairs are invalid
            elseif codePoint > 0x10FFFF then
                return "\239\191\189" -- out of unicode range
            else
                return codePointToUTF8(codePoint)
            end
        else
            return "&" .. refContent .. ";"
        end
    end

    -- named reference
    local decoded = NAMED_ENTITIES[refContent]
    if decoded then
        return decoded
    end

    -- case insensitive match
    decoded = NAMED_ENTITIES[refContent:lower()]
    if decoded then
        return decoded
    end

    -- unknown entity -> return as is
    return "&" .. refContent .. ";"
end

--- TAGS

function Lexer:parseTagName()
    local name = ""

    while not self:isAtEnd() and isTagNameChar(self:current()) do
        name = name .. self:current()
        self:advance()
    end

    return name:lower()
end

function Lexer:parseAttributeValue()
    local char = self:current()
    local value = ""

    if char == '"' or char == "'" then
        local quote = char
        self:advance() -- skip opening quote

        while not self:isAtEnd() do
            char = self:current()

            if char == quote then
                self:advance() -- skip closing quote
                break
            elseif char :: any == "&" and self.decodeEntities then
                value = value .. self:decodeCharacterReference()
            else
                value = value .. char
                self:advance()
            end
        end
    else
        -- unquoted value
        while not self:isAtEnd() do
            char = self:current()

            if isWhitespace(char) or char == ">" or char == "/" then
                break
            elseif char == "&" and self.decodeEntities then
                value = value .. self:decodeCharacterReference()
            else
                value = value .. char
                self:advance()
            end
        end
    end

    return value
end

function Lexer:parseAttributes()
    local attributes = {}

    while not self:isAtEnd() do
        self:skipWhitespace()

        local char = self:current()

        -- end of attributes
        if char == ">" or char == "/" or char == nil then
            break
        end

        -- parse attribute name
        if not isAttributeNameStart(char) then
            -- invalid char -> skip
            self:advance()

            -- skip junk until the next valid attribute
            local skipped = false
            while not self:isAtEnd() do
                char = self:current()
                if
                    isWhitespace(char)
                    or char == ">"
                    or char == "/"
                    or isAttributeNameStart(char)
                then
                    break
                end
                self:advance()
                skipped = true
            end

            if not skipped then
                break -- prevent infinite loop
            end
        else
            -- valid attribute name start
            local attrName = ""

            while not self:isAtEnd() and isAttributeNameChar(self:current()) do
                attrName = attrName .. self:current()
                self:advance()
            end

            -- lowercase attribute name
            attrName = attrName:lower()

            self:skipWhitespace()

            -- check for value
            if self:current() == "=" then
                self:advance() -- skip '='
                self:skipWhitespace()

                local attrValue = self:parseAttributeValue()
                attributes[attrName] = attrValue
            else
                -- boolean attribute
                attributes[attrName] = true
            end
        end
    end

    return attributes
end

function Lexer:parseStartTag()
    self:markTokenStart()

    self:advance() -- skip '<'

    local tagName = self:parseTagName()
    local attributes = self:parseAttributes()

    self:skipWhitespace()

    -- check for self-closing
    local isSelfClosing = false
    if self:current() == "/" then
        isSelfClosing = true
        self:advance()
        self:skipWhitespace()
    end

    -- skip closing '>'
    if self:current() == ">" then
        self:advance()
    end

    -- void elements are always self-closing
    local isVoid = VOID_ELEMENTS[tagName] or false

    return self:createToken(TokenType.START_TAG, tagName, {
        tagName = tagName,
        attributes = attributes,
        selfClosing = isSelfClosing,
        void = isVoid,
    })
end

function Lexer:parseEndTag()
    self:markTokenStart()

    self:advance(2) -- skip '</'

    self:skipWhitespace() -- some browsers allow whitespace here

    local tagName = self:parseTagName()

    -- skip trailing content until '>'
    while not self:isAtEnd() and self:current() ~= ">" do
        self:advance()
    end

    -- skip closing '>'
    if self:current() == ">" then
        self:advance()
    end

    return self:createToken(TokenType.END_TAG, tagName, {
        tagName = tagName,
    })
end

function Lexer:parseRawText(tagName)
    self:markTokenStart()

    local content = ""
    local endPattern = "</" .. tagName

    while not self:isAtEnd() do
        -- check for closing tag (case-insensitive)
        if self:matchString(endPattern) then
            -- verify it's followed by > or whitespace
            local afterTag = self:peek(#endPattern)
            if
                afterTag == ">"
                or afterTag == "/"
                or isWhitespace(afterTag)
                or afterTag == nil
            then
                break
            end
        end

        content = content .. self:current()
        self:advance()
    end

    return self:createToken(TokenType.RAW_TEXT, content, {
        tagName = tagName,
    })
end

--- SPECIAL

function Lexer:parseDoctype()
    self:markTokenStart()

    self:advance(9) -- skip '<!DOCTYPE'

    local content = ""

    while not self:isAtEnd() and self:current() ~= ">" do
        content = content .. self:current()
        self:advance()
    end

    -- skip closing '>'
    if self:current() == ">" then
        self:advance()
    end

    -- trim whitespace
    content = content:match("^%s*(.-)%s*$")

    return self:createToken(TokenType.DOCTYPE, content)
end

function Lexer:parseComment()
    self:markTokenStart()

    self:advance(4) -- skip '<!--'

    local content = ""

    while not self:isAtEnd() do
        if self:matchString("-->", true) then
            self:advance(3) -- skip '-->'
            break
        elseif self:matchString("--!>", true) then
            -- incorrect but common comment end
            self:advance(4)
            break
        else
            content = content .. self:current()
            self:advance()
        end
    end

    return self:createToken(TokenType.COMMENT, content)
end

function Lexer:parseCDATA()
    self:markTokenStart()

    self:advance(9) -- skip '<![CDATA['

    local content = ""

    while not self:isAtEnd() do
        if self:matchString("]]>", true) then
            self:advance(3) -- skip ']]>'
            break
        else
            content = content .. self:current()
            self:advance()
        end
    end

    return self:createToken(TokenType.CDATA, content)
end

function Lexer:skipProcessingInstruction()
    self:advance(2) -- skip '<?'

    while not self:isAtEnd() do
        if self:matchString("?>", true) then
            self:advance(2)
            break
        elseif self:current() == ">" then
            -- malformed, but recover
            self:advance()
            break
        else
            self:advance()
        end
    end
end

function Lexer:skipBogusComment()
    while not self:isAtEnd() and self:current() ~= ">" do
        self:advance()
    end

    if self:current() == ">" then
        self:advance()
    end
end

--- TEXT

function Lexer:parseText()
    self:markTokenStart()

    local content = ""

    while not self:isAtEnd() do
        local char = self:current()

        if char == "<" then
            break
        elseif char == "&" and self.decodeEntities then
            content = content .. self:decodeCharacterReference()
        else
            content = content .. char
            self:advance()
        end
    end

    return self:createToken(TokenType.TEXT, content)
end

--- MAINLOOP

function Lexer:tokenize()
    self.tokens = {}
    local rawTextTag = nil -- tracks raw text element
    local tokenCount = 0

    while not self:isAtEnd() do
        -- raw text mode
        if rawTextTag then
            local rawToken = self:parseRawText(rawTextTag)
            if rawToken.value ~= "" then
                self:emit(rawToken)
                tokenCount = tokenCount + 1
            end
            rawTextTag = nil
            -- parse the end tag
        end

        local char = self:current()

        if char == "<" then
            local nextChar = self:peek(1)

            if nextChar == "!" then
                -- DOCTYPE, comment, CDATA, or bogus
                if self:matchString("<!DOCTYPE") then
                    self:emit(self:parseDoctype())
                    tokenCount = tokenCount + 1
                elseif self:matchString("<!--") then
                    self:emit(self:parseComment())
                    tokenCount = tokenCount + 1
                elseif self:matchString("<![CDATA[") then
                    self:emit(self:parseCDATA())
                    tokenCount = tokenCount + 1
                else
                    -- bogus comment or unknown construct
                    self:skipBogusComment()
                end
            elseif nextChar == "/" then
                -- end tag
                local endTag = self:parseEndTag()
                self:emit(endTag)
                tokenCount = tokenCount + 1
            elseif nextChar == "?" then
                -- processing instruction (skip)
                self:skipProcessingInstruction()
            elseif isTagNameStart(nextChar) then
                -- start tag
                local startTag = self:parseStartTag()
                self:emit(startTag)
                tokenCount = tokenCount + 1

                -- check for raw text element
                if
                    TRULY_RAW_ELEMENTS[startTag.tagName]
                    and not startTag.selfClosing
                    and not startTag.void
                then
                    rawTextTag = startTag.tagName
                end
            else
                self:markTokenStart()
                local content = "<"
                self:advance() -- nom nom nom the '<'

                -- consume text until next '<'
                while not self:isAtEnd() do
                    local c = self:current()
                    if c == "<" then
                        break
                    elseif c == "&" and self.decodeEntities then
                        content = content .. self:decodeCharacterReference()
                    else
                        content = content .. c
                        self:advance()
                    end
                end

                -- merge with previous text token
                if
                    #self.tokens > 0
                    and self.tokens[#self.tokens].type == TokenType.TEXT
                then
                    self.tokens[#self.tokens].value = self.tokens[#self.tokens].value
                        .. content
                else
                    self:emit(self:createToken(TokenType.TEXT, content))
                    tokenCount = tokenCount + 1
                end
            end
        else
            -- text content
            local textToken = self:parseText()
            if textToken.value ~= "" then
                -- skip whitespace-only text if configured
                if
                    not self.skipWhitespaceOnlyText
                    or textToken.value:match("%S")
                then
                    self:emit(textToken)
                    tokenCount = tokenCount + 1
                end
            end
        end

        -- cpu yield
        if tokenCount % self.yieldInterval == 1 then
            if task and task.wait then
                task.wait()
            end
        end
    end

    -- add EOF token
    self:markTokenStart()
    self:emit(self:createToken(TokenType.EOF, ""))

    return self.tokens
end

--- API

function Lexer.getTokenTypes()
    return TokenType
end

function Lexer.getVoidElements()
    return VOID_ELEMENTS
end

function Lexer.getRawTextElements()
    return RAW_TEXT_ELEMENTS
end

function Lexer:setDecodeEntities(decode)
    self.decodeEntities = decode
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

function Lexer:setSkipWhitespaceOnlyText(skip)
    self.skipWhitespaceOnlyText = skip
end

function Lexer.parse(source)
    local lexer = Lexer.new(source)
    local tokens = lexer:tokenize()
    return tokens, TokenType
end

function Lexer.create(source, options)
    local lexer = Lexer.new(source)

    if options then
        if options.decodeEntities ~= nil then
            lexer:setDecodeEntities(options.decodeEntities)
        end
        if options.yieldInterval then
            lexer:setYieldInterval(options.yieldInterval)
        end
        if options.skipWhitespaceOnlyText ~= nil then
            lexer:setSkipWhitespaceOnlyText(options.skipWhitespaceOnlyText)
        end
    end

    return lexer
end

return Lexer

-- EOF