--[[
    "CSS Parser module for dOS"
    
    @module css_parser
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


local Parser = {}
Parser.__index = Parser

--- NODES

local NodeType = {
    STYLESHEET = "stylesheet",
    STYLE_RULE = "style_rule",
    IMPORT_RULE = "import_rule",
    CHARSET_RULE = "charset_rule",
    NAMESPACE_RULE = "namespace_rule",
    MEDIA_RULE = "media_rule",
    SUPPORTS_RULE = "supports_rule",
    LAYER_RULE = "layer_rule",
    CONTAINER_RULE = "container_rule",
    SCOPE_RULE = "scope_rule",
    KEYFRAMES_RULE = "keyframes_rule",
    KEYFRAME = "keyframe",
    FONT_FACE_RULE = "font_face_rule",
    PAGE_RULE = "page_rule",
    COUNTER_STYLE_RULE = "counter_style_rule",
    PROPERTY_RULE = "property_rule",
    GENERIC_AT_RULE = "generic_at_rule",
    DECLARATION = "declaration",
    SELECTOR_LIST = "selector_list",
    SELECTOR = "selector",
    MEDIA_QUERY_LIST = "media_query_list",
    MEDIA_QUERY = "media_query",
    MEDIA_CONDITION = "media_condition",
    SUPPORTS_CONDITION = "supports_condition",
}

--- CONSTANTS

local SelectorType = {
    TYPE = "type",
    UNIVERSAL = "universal",
    CLASS = "class",
    ID = "id",
    ATTRIBUTE = "attribute",
    PSEUDO_CLASS = "pseudo_class",
    PSEUDO_ELEMENT = "pseudo_element",
    COMBINATOR = "combinator",
    NESTING = "nesting",
}

local CombinatorType = {
    DESCENDANT = " ",
    CHILD = ">",
    ADJACENT = "+",
    SIBLING = "~",
    COLUMN = "||",
}

local ValueType = {
    KEYWORD = "keyword",
    NUMBER = "number",
    DIMENSION = "dimension",
    PERCENTAGE = "percentage",
    STRING = "string",
    URL = "url",
    COLOR = "color",
    FUNCTION = "function",
    VAR = "var",
    ENV = "env",
    CALC = "calc",
    LIST = "list",
}

local AttributeOperator = {
    EXISTS = "",
    EQUALS = "=",
    INCLUDES = "~=",
    DASH_MATCH = "|=",
    PREFIX = "^=",
    SUFFIX = "$=",
    SUBSTRING = "*=",
}

--- PSEUDO

local _unused_SIMPLE_PSEUDO_CLASSES = {
    active = true,
    ["any-link"] = true,
    blank = true,
    checked = true,
    default = true,
    defined = true,
    disabled = true,
    empty = true,
    enabled = true,
    first = true,
    ["first-child"] = true,
    ["first-of-type"] = true,
    focus = true,
    ["focus-visible"] = true,
    ["focus-within"] = true,
    fullscreen = true,
    hover = true,
    indeterminate = true,
    ["in-range"] = true,
    invalid = true,
    ["last-child"] = true,
    ["last-of-type"] = true,
    left = true,
    link = true,
    ["local-link"] = true,
    ["only-child"] = true,
    ["only-of-type"] = true,
    optional = true,
    ["out-of-range"] = true,
    paused = true,
    ["placeholder-shown"] = true,
    playing = true,
    ["read-only"] = true,
    ["read-write"] = true,
    required = true,
    right = true,
    root = true,
    scope = true,
    target = true,
    ["target-within"] = true,
    valid = true,
    visited = true,
    ["user-invalid"] = true,
    ["user-valid"] = true,
    ["is-valid"] = true,
    ["is-invalid"] = true,
    open = true,
    closed = true,
    modal = true,
    picture_in_picture = true,
    autofill = true,
    future = true,
    past = true,
    playing2 = true,
    paused2 = true,
    muted = true,
    ["volume-locked"] = true,
}

local _unused_FUNCTIONAL_PSEUDO_CLASSES = {
    ["nth-child"] = true,
    ["nth-last-child"] = true,
    ["nth-of-type"] = true,
    ["nth-last-of-type"] = true,
    ["nth-col"] = true,
    ["nth-last-col"] = true,
    ["not"] = true,
    is = true,
    where = true,
    has = true,
    matches = true,
    any = true,
    lang = true,
    dir = true,
    current = true,
    host = true,
    ["host-context"] = true,
    state = true,
    part = true,
    global = true,
    ["has-slotted"] = true,
}

local PSEUDO_ELEMENTS = {
    before = true,
    after = true,
    ["first-line"] = true,
    ["first-letter"] = true,
    marker = true,
    selection = true,
    placeholder = true,
    backdrop = true,
    ["file-selector-button"] = true,
    cue = true,
    ["cue-region"] = true,
    ["spelling-error"] = true,
    ["grammar-error"] = true,
    ["target-text"] = true,
    highlight = true,
    ["scroll-marker"] = true,
    ["scroll-marker-group"] = true,
    ["view-transition"] = true,
    ["view-transition-image-pair"] = true,
    ["view-transition-new"] = true,
    ["view-transition-old"] = true,
}

local FUNCTIONAL_PSEUDO_ELEMENTS = {
    part = true,
    slotted = true,
    highlight = true,
    cue = true,
    ["cue-region"] = true,
    ["scroll-marker"] = true,
    ["view-transition-image-pair"] = true,
    ["view-transition-new"] = true,
    ["view-transition-old"] = true,
}

--- FUNCTIONS

local GLOBAL_KEYWORDS = {
    initial = true,
    inherit = true,
    unset = true,
    revert = true,
    ["revert-layer"] = true,
}

local COLOR_KEYWORDS = {
    -- named colors
    black = true,
    silver = true,
    gray = true,
    grey = true,
    white = true,
    maroon = true,
    red = true,
    purple = true,
    fuchsia = true,
    green = true,
    lime = true,
    olive = true,
    yellow = true,
    navy = true,
    blue = true,
    teal = true,
    aqua = true,
    orange = true,
    rebeccapurple = true,
    aliceblue = true,
    antiquewhite = true,
    aquamarine = true,
    azure = true,
    beige = true,
    bisque = true,
    blanchedalmond = true,
    blueviolet = true,
    brown = true,
    burlywood = true,
    cadetblue = true,
    chartreuse = true,
    chocolate = true,
    coral = true,
    cornflowerblue = true,
    cornsilk = true,
    crimson = true,
    cyan = true,
    darkblue = true,
    darkcyan = true,
    darkgoldenrod = true,
    darkgray = true,
    darkgreen = true,
    darkgrey = true,
    darkkhaki = true,
    darkmagenta = true,
    darkolivegreen = true,
    darkorange = true,
    darkorchid = true,
    darkred = true,
    darksalmon = true,
    darkseagreen = true,
    darkslateblue = true,
    darkslategray = true,
    darkslategrey = true,
    darkturquoise = true,
    darkviolet = true,
    deeppink = true,
    deepskyblue = true,
    dimgray = true,
    dimgrey = true,
    dodgerblue = true,
    firebrick = true,
    floralwhite = true,
    forestgreen = true,
    gainsboro = true,
    ghostwhite = true,
    gold = true,
    goldenrod = true,
    greenyellow = true,
    honeydew = true,
    hotpink = true,
    indianred = true,
    indigo = true,
    ivory = true,
    khaki = true,
    lavender = true,
    lavenderblush = true,
    lawngreen = true,
    lemonchiffon = true,
    lightblue = true,
    lightcoral = true,
    lightcyan = true,
    lightgoldenrodyellow = true,
    lightgray = true,
    lightgreen = true,
    lightgrey = true,
    lightpink = true,
    lightsalmon = true,
    lightseagreen = true,
    lightskyblue = true,
    lightslategray = true,
    lightslategrey = true,
    lightsteelblue = true,
    lightyellow = true,
    limegreen = true,
    linen = true,
    magenta = true,
    mediumaquamarine = true,
    mediumblue = true,
    mediumorchid = true,
    mediumpurple = true,
    mediumseagreen = true,
    mediumslateblue = true,
    mediumspringgreen = true,
    mediumturquoise = true,
    mediumvioletred = true,
    midnightblue = true,
    mintcream = true,
    mistyrose = true,
    moccasin = true,
    navajowhite = true,
    oldlace = true,
    olivedrab = true,
    orangered = true,
    orchid = true,
    palegoldenrod = true,
    palegreen = true,
    paleturquoise = true,
    palevioletred = true,
    papayawhip = true,
    peachpuff = true,
    peru = true,
    pink = true,
    plum = true,
    powderblue = true,
    rosybrown = true,
    royalblue = true,
    saddlebrown = true,
    salmon = true,
    sandybrown = true,
    seagreen = true,
    seashell = true,
    sienna = true,
    skyblue = true,
    slateblue = true,
    slategray = true,
    slategrey = true,
    snow = true,
    springgreen = true,
    steelblue = true,
    tan = true,
    thistle = true,
    tomato = true,
    turquoise = true,
    violet = true,
    wheat = true,
    whitesmoke = true,
    yellowgreen = true,
    -- system colors
    transparent = true,
    currentcolor = true,
    canvas = true,
    canvastext = true,
    linktext = true,
    visitedtext = true,
    activetext = true,
    buttonface = true,
    buttontext = true,
    buttonborder = true,
    field = true,
    fieldtext = true,
    highlight = true,
    highlighttext = true,
    selecteditem = true,
    selecteditemtext = true,
    mark = true,
    marktext = true,
    graytext = true,
    accentcolor = true,
    accentcolortext = true,
}

local COLOR_FUNCTIONS = {
    rgb = true,
    rgba = true,
    hsl = true,
    hsla = true,
    hwb = true,
    lab = true,
    lch = true,
    oklab = true,
    oklch = true,
    color = true,
    ["color-mix"] = true,
    ["color-contrast"] = true,
    ["light-dark"] = true,
    ["device-cmyk"] = true,
}

local MATH_FUNCTIONS = {
    calc = true,
    min = true,
    max = true,
    clamp = true,
    round = true,
    mod = true,
    rem = true,
    sin = true,
    cos = true,
    tan = true,
    asin = true,
    acos = true,
    atan = true,
    atan2 = true,
    pow = true,
    sqrt = true,
    hypot = true,
    log = true,
    exp = true,
    abs = true,
    sign = true,
}

local GRADIENT_FUNCTIONS = {
    ["linear-gradient"] = true,
    ["radial-gradient"] = true,
    ["conic-gradient"] = true,
    ["repeating-linear-gradient"] = true,
    ["repeating-radial-gradient"] = true,
    ["repeating-conic-gradient"] = true,
}

local FILTER_FUNCTIONS = {
    blur = true,
    brightness = true,
    contrast = true,
    ["drop-shadow"] = true,
    grayscale = true,
    ["hue-rotate"] = true,
    invert = true,
    opacity = true,
    saturate = true,
    sepia = true,
}

local TIMING_FUNCTIONS = {
    linear = true,
    ease = true,
    ["ease-in"] = true,
    ["ease-out"] = true,
    ["ease-in-out"] = true,
    ["step-start"] = true,
    ["step-end"] = true,
    steps = true,
    ["cubic-bezier"] = true,
}

local TRANSFORM_FUNCTIONS = {
    -- keys must be lowercase
    matrix = true,
    matrix3d = true,
    translate = true,
    translatex = true,
    translatey = true,
    translatez = true,
    translate3d = true,
    scale = true,
    scalex = true,
    scaley = true,
    scalez = true,
    scale3d = true,
    rotate = true,
    rotatex = true,
    rotatey = true,
    rotatez = true,
    rotate3d = true,
    skew = true,
    skewx = true,
    skewy = true,
    perspective = true,
}

local _unused_AT_RULE_NAMES = {
    charset = true,
    import = true,
    namespace = true,
    media = true,
    supports = true,
    layer = true,
    keyframes = true,
    ["-webkit-keyframes"] = true,
    ["-moz-keyframes"] = true,
    ["-o-keyframes"] = true,
    ["-ms-keyframes"] = true,
    ["font-face"] = true,
    page = true,
    ["counter-style"] = true,
    property = true,
    ["font-feature-values"] = true,
    ["font-palette-values"] = true,
    ["color-profile"] = true,
    ["scroll-timeline"] = true,
    ["view-transition"] = true,
    ["starting-style"] = true,
    document = true,
}

--- MAPS

local _unused_BOX_4_ORDER = { "Top", "Right", "Bottom", "Left" }

local SHORTHAND_PROPERTIES = {
    margin = { "margin-top", "margin-right", "margin-bottom", "margin-left" },
    padding = {
        "padding-top",
        "padding-right",
        "padding-bottom",
        "padding-left",
    },
    inset = { "top", "right", "bottom", "left" },
    border = {
        "border-top-width",
        "border-right-width",
        "border-bottom-width",
        "border-left-width",
        "border-top-style",
        "border-right-style",
        "border-bottom-style",
        "border-left-style",
        "border-top-color",
        "border-right-color",
        "border-bottom-color",
        "border-left-color",
    },
    ["border-width"] = {
        "border-top-width",
        "border-right-width",
        "border-bottom-width",
        "border-left-width",
    },
    ["border-style"] = {
        "border-top-style",
        "border-right-style",
        "border-bottom-style",
        "border-left-style",
    },
    ["border-color"] = {
        "border-top-color",
        "border-right-color",
        "border-bottom-color",
        "border-left-color",
    },
    ["border-top"] = {
        "border-top-width",
        "border-top-style",
        "border-top-color",
    },
    ["border-right"] = {
        "border-right-width",
        "border-right-style",
        "border-right-color",
    },
    ["border-bottom"] = {
        "border-bottom-width",
        "border-bottom-style",
        "border-bottom-color",
    },
    ["border-left"] = {
        "border-left-width",
        "border-left-style",
        "border-left-color",
    },
    ["border-radius"] = {
        "border-top-left-radius",
        "border-top-right-radius",
        "border-bottom-right-radius",
        "border-bottom-left-radius",
    },
    background = {
        "background-color",
        "background-image",
        "background-repeat",
        "background-position",
        "background-size",
        "background-attachment",
        "background-origin",
        "background-clip",
    },
    font = {
        "font-style",
        "font-variant",
        "font-weight",
        "font-stretch",
        "font-size",
        "line-height",
        "font-family",
    },
    transition = {
        "transition-property",
        "transition-duration",
        "transition-timing-function",
        "transition-delay",
    },
    animation = {
        "animation-name",
        "animation-duration",
        "animation-timing-function",
        "animation-delay",
        "animation-iteration-count",
        "animation-direction",
        "animation-fill-mode",
        "animation-play-state",
    },
    flex = { "flex-grow", "flex-shrink", "flex-basis" },
    ["flex-flow"] = { "flex-direction", "flex-wrap" },
    overflow = { "overflow-x", "overflow-y" },
}

local INHERITED_PROPERTIES = {
    color = true,
    cursor = true,
    direction = true,
    visibility = true,
    ["font"] = true,
    ["font-family"] = true,
    ["font-size"] = true,
    ["font-style"] = true,
    ["font-variant"] = true,
    ["font-weight"] = true,
    ["letter-spacing"] = true,
    ["line-height"] = true,
    ["list-style"] = true,
    ["list-style-image"] = true,
    ["list-style-position"] = true,
    ["list-style-type"] = true,
    ["text-align"] = true,
    ["text-decoration"] = true,
    ["text-indent"] = true,
    ["text-transform"] = true,
    ["white-space"] = true,
    ["word-spacing"] = true,
    ["border-collapse"] = true,
    ["border-spacing"] = true,
    ["pointer-events"] = true,
}

--- HELPERS

local function isElementNode(node)
    if not node then
        return false
    end

    local nt = node.nodeType
    if nt == nil then
        return node.tagName ~= nil
    end

    return nt == "element" or nt == 1
end

local function nthChildPosition(element, ofType)
    local pos = 1
    local prev = element.previousSibling
    local tag = element.tagName

    while prev do
        if isElementNode(prev) then
            if not ofType or prev.tagName == tag then
                pos = pos + 1
            end
        end
        prev = prev.previousSibling
    end

    return pos
end

local function nthLastChildPosition(element, ofType)
    local pos = 1
    local nxt = element.nextSibling
    local tag = element.tagName

    while nxt do
        if isElementNode(nxt) then
            if not ofType or nxt.tagName == tag then
                pos = pos + 1
            end
        end
        nxt = nxt.nextSibling
    end

    return pos
end

local function matchesAnPlusB(a, b, pos)
    if a == 0 then
        return pos == b
    end

    local n = (pos - b) / a
    return n >= 0 and math.floor(n) == n
end

local function parseAnPlusB(text)
    if not text then
        return nil, nil
    end

    text = string.gsub(string.lower(text), "%s+", "")

    if text == "odd" then
        return 2, 1
    end

    if text == "even" then
        return 2, 0
    end

    local pure = tonumber(text)
    if pure then
        return 0, pure
    end

    -- [+-]?<digit>*n[+-]<digit>+
    local sA, sB = string.match(text, "^([+%-]?%d*)n([+%-]%d+)$")
    if sA ~= nil then
        local a = (sA == "" or sA == "+") and 1
            or (sA == "-" and -1 or tonumber(sA) or 0)
        return a, tonumber(sB) or 0
    end

    -- [+-]?<digit>*n
    local sA2 = string.match(text, "^([+%-]?%d*)n$")
    if sA2 ~= nil then
        local a = (sA2 == "" or sA2 == "+") and 1
            or (sA2 == "-" and -1 or tonumber(sA2) or 0)
        return a, 0
    end

    return nil, nil
end

--- PARSER

function Parser.new(tokens, tokenTypes)
    local self = setmetatable({}, Parser)
    self.tokens = tokens or {}
    self.TT = tokenTypes or {}
    self.pos = 1
    self.length = #self.tokens
    self.errors = {}
    self.yieldInterval = 200
    self.tokenCount = 0
    return self
end

--- CURSOR

function Parser:current()
    return self.tokens[self.pos]
end

function Parser:tok(offset)
    local idx = self.pos + (offset or 0)
    if idx < 1 or idx > self.length then
        return nil
    end
    return self.tokens[idx]
end

function Parser:advance()
    self.pos = self.pos + 1
    self.tokenCount = self.tokenCount + 1

    -- cpu is trash
    if self.tokenCount % self.yieldInterval == 0 then
        if task and task.wait then
            task.wait()
        end
    end
end

function Parser:isAtEnd()
    return self.pos > self.length or self.tokens[self.pos].type == self.TT.EOF
end

function Parser:skipWS()
    local TT_WS = self.TT.WHITESPACE
    while self.pos <= self.length and self.tokens[self.pos].type == TT_WS do
        self:advance()
    end
end

function Parser:skipWSAndSemis()
    local TT = self.TT
    local TT_WS = TT.WHITESPACE
    local TT_SEMI = TT.SEMICOLON

    while self.pos <= self.length do
        local tt = self.tokens[self.pos].type
        if tt ~= TT_WS and tt ~= TT_SEMI then
            break
        end
        self:advance()
    end
end

function Parser:addError(message, token)
    token = token or self:current()
    self.errors[#self.errors + 1] = {
        message = message,
        line = token and token.line or 0,
        column = token and token.column or 0,
    }
end

--- CONSUMERS

function Parser:consumeBlock()
    local tokens = {}
    local TT = self.TT
    local current = self:current()

    if not current or current.type ~= TT.LBRACE then
        self:addError("Expected '{' to open block")
        return tokens
    end

    self:advance() -- skip opening '{'

    local depth = 1
    local tIdx = 1

    while self.pos <= self.length do
        local t = self:current()
        local tType = t.type

        if tType == TT.LBRACE then
            depth = depth + 1
            tokens[tIdx] = t
            tIdx = tIdx + 1
            self:advance()
        elseif tType == TT.RBRACE then
            depth = depth - 1
            if depth == 0 then
                self:advance() -- consume closing '}'
                break
            end
            tokens[tIdx] = t
            tIdx = tIdx + 1
            self:advance()
        else
            tokens[tIdx] = t
            tIdx = tIdx + 1
            self:advance()
        end
    end

    return tokens
end

function Parser:consumePrelude()
    local tokens = {}
    local TT = self.TT
    local TT_LBRACE = TT.LBRACE
    local TT_SEMI = TT.SEMICOLON
    local TT_EOF = TT.EOF
    local tIdx = 1

    while self.pos <= self.length do
        local t = self:current()
        local tType = t.type

        if tType == TT_LBRACE or tType == TT_SEMI or tType == TT_EOF then
            break
        end

        tokens[tIdx] = t
        tIdx = tIdx + 1
        self:advance()
    end

    return tokens
end

local function trimWhitespace(tokens, TT_WS)
    local startIdx, endIdx = 1, #tokens

    while startIdx <= endIdx and tokens[startIdx].type == TT_WS do
        startIdx = startIdx + 1
    end

    while endIdx >= startIdx and tokens[endIdx].type == TT_WS do
        endIdx = endIdx - 1
    end

    if startIdx > 1 or endIdx < #tokens then
        local trimmed = {}
        for i = startIdx, endIdx do
            trimmed[#trimmed + 1] = tokens[i]
        end
        return trimmed
    end

    return tokens
end

function Parser:splitByTopLevelComma(tokens)
    local segments = {}
    local current = {}
    local depth = 0
    local TT = self.TT

    for i = 1, #tokens do
        local t = tokens[i]
        local tt = t.type

        if
            tt == TT.FUNCTION
            or tt == TT.LPAREN
            or tt == TT.LBRACKET
            or tt == TT.LBRACE
        then
            depth = depth + 1
            current[#current + 1] = t
        elseif tt == TT.RPAREN or tt == TT.RBRACKET or tt == TT.RBRACE then
            if depth > 0 then
                depth = depth - 1
            end
            current[#current + 1] = t
        elseif tt == TT.COMMA and depth == 0 then
            current = trimWhitespace(current, TT.WHITESPACE)
            if #current > 0 then
                segments[#segments + 1] = current
            end
            current = {}
        else
            current[#current + 1] = t
        end
    end

    current = trimWhitespace(current, TT.WHITESPACE)
    if #current > 0 then
        segments[#segments + 1] = current
    end

    return segments
end

function Parser:splitByTopLevelWhitespace(tokens)
    local segments = {}
    local current = {}
    local depth = 0
    local TT = self.TT

    for i = 1, #tokens do
        local t = tokens[i]
        local tt = t.type

        if
            tt == TT.FUNCTION
            or tt == TT.LPAREN
            or tt == TT.LBRACKET
            or tt == TT.LBRACE
        then
            depth = depth + 1
            current[#current + 1] = t
        elseif tt == TT.RPAREN or tt == TT.RBRACKET or tt == TT.RBRACE then
            if depth > 0 then
                depth = depth - 1
            end
            current[#current + 1] = t
        elseif tt == TT.WHITESPACE and depth == 0 then
            if #current > 0 then
                segments[#segments + 1] = current
                current = {}
            end
        else
            current[#current + 1] = t
        end
    end

    if #current > 0 then
        segments[#segments + 1] = current
    end

    return segments
end

function Parser:tokensToString(tokens)
    if not tokens or #tokens == 0 then
        return ""
    end

    local TT = self.TT
    local parts = {}
    local pIdx = 1

    for i = 1, #tokens do
        local t = tokens[i]
        local tt = t.type

        if tt == TT.WHITESPACE then
            parts[pIdx] = " "
        elseif tt == TT.IDENT or tt == TT.DELIM then
            parts[pIdx] = t.value or ""
        elseif tt == TT.AT_KEYWORD then
            parts[pIdx] = "@" .. (t.value or "")
        elseif tt == TT.HASH then
            parts[pIdx] = "#" .. (t.value or "")
        elseif tt == TT.STRING then
            parts[pIdx] = '"' .. (t.value or "") .. '"'
        elseif tt == TT.NUMBER then
            parts[pIdx] = tostring(t.raw or t.value or "")
        elseif tt == TT.DIMENSION then
            parts[pIdx] = tostring(t.raw or t.value or "") .. (t.unit or "")
        elseif tt == TT.PERCENTAGE then
            parts[pIdx] = tostring(t.raw or t.value or "") .. "%"
        elseif tt == TT.URL then
            parts[pIdx] = 'url("' .. (t.value or "") .. '")'
        elseif tt == TT.FUNCTION then
            parts[pIdx] = (t.value or "") .. "("
        elseif tt == TT.COLON then
            parts[pIdx] = ":"
        elseif tt == TT.SEMICOLON then
            parts[pIdx] = ";"
        elseif tt == TT.COMMA then
            parts[pIdx] = ","
        elseif tt == TT.LPAREN then
            parts[pIdx] = "("
        elseif tt == TT.RPAREN then
            parts[pIdx] = ")"
        elseif tt == TT.LBRACKET then
            parts[pIdx] = "["
        elseif tt == TT.RBRACKET then
            parts[pIdx] = "]"
        elseif tt == TT.LBRACE then
            parts[pIdx] = "{"
        elseif tt == TT.RBRACE then
            parts[pIdx] = "}"
        elseif tt == TT.CDO then
            parts[pIdx] = "<!--"
        elseif tt == TT.CDC then
            parts[pIdx] = "-->"
        else
            parts[pIdx] = tostring(t.value or "")
        end

        pIdx = pIdx + 1
    end

    return table.concat(parts)
end

function Parser:parseStylesheet()
    local stylesheet = {
        type = NodeType.STYLESHEET,
        rules = {},
        line = 1,
        column = 1,
    }
    local TT = self.TT
    local rules = stylesheet.rules

    while self.pos <= self.length do
        local t = self:current()
        local tt = t.type

        if
            tt == TT.WHITESPACE
            or tt == TT.CDO
            or tt == TT.CDC
            or tt == TT.SEMICOLON
        then
            self:advance()
        elseif tt == TT.AT_KEYWORD then
            local rule = self:parseAtRule()
            if rule then
                rules[#rules + 1] = rule
            end
        elseif tt == TT.RBRACE then
            self:addError("Unexpected '}' at top-level")
            self:advance()
        elseif tt == TT.EOF then
            break
        else
            local rule = self:parseQualifiedRule()
            if rule then
                rules[#rules + 1] = rule
            end
        end
    end

    return stylesheet
end

--- RULES

function Parser:parseQualifiedRule()
    local TT = self.TT
    local startT = self:current()
    local line = startT and startT.line or 0
    local col = startT and startT.column or 0

    local prelude = {}
    local pIdx = 1

    -- collect everything until '{' or EOF
    while self.pos <= self.length do
        local t = self:current()
        if t.type == TT.LBRACE or t.type == TT.EOF then
            break
        end
        prelude[pIdx] = t
        pIdx = pIdx + 1
        self:advance()
    end

    local current = self:current()
    if not current or current.type ~= TT.LBRACE then
        self:addError("Expected '{' to begin a qualified rule")
        -- skip to next block or semi
        self:skipWSAndSemis()
        return nil
    end

    local blockTokens = self:consumeBlock()
    local declarations = self:parseDeclarationBlockFromTokens(blockTokens)
    local selectorList = self:parseSelectorListFromTokens(prelude)

    -- for unparseable selectors ignore the whole rule
    if
        not selectorList
        or not selectorList.selectors
        or #selectorList.selectors == 0
    then
        return nil
    end

    return {
        type = NodeType.STYLE_RULE,
        selectorList = selectorList,
        declarations = declarations,
        line = line,
        column = col,
    }
end

--- ATRULES

function Parser:parseAtRule()
    local TT = self.TT
    local t = self:current()
    local name = (t.value or ""):lower()
    local line, col = t.line, t.column

    self:advance() -- consume @keyword

    -- simple semicolon terminated at-rules
    if name == "charset" then
        local prelude = self:consumePrelude()
        if self.pos <= self.length and self:current().type == TT.SEMICOLON then
            self:advance()
        end
        return self:buildCharsetRule(prelude, line, col)

    elseif name == "import" then
        local prelude = self:consumePrelude()
        if self.pos <= self.length and self:current().type == TT.SEMICOLON then
            self:advance()
        end
        return self:buildImportRule(prelude, line, col)

    elseif name == "namespace" then
        local prelude = self:consumePrelude()
        if self.pos <= self.length and self:current().type == TT.SEMICOLON then
            self:advance()
        end
        return self:buildNamespaceRule(prelude, line, col)

    elseif name == "layer" then
        local prelude = self:consumePrelude()
        if self.pos <= self.length and self:current().type == TT.LBRACE then
            local block = self:consumeBlock()
            return self:buildLayerRule(prelude, block, line, col)
        else
            if
                self.pos <= self.length
                and self:current().type == TT.SEMICOLON
            then
                self:advance()
            end
            return self:buildLayerRule(prelude, nil, line, col)
        end

    else
        -- block at-rules
        local prelude = self:consumePrelude()

        if self:isAtEnd() or self:current().type ~= TT.LBRACE then
            if
                self.pos <= self.length
                and self:current().type == TT.SEMICOLON
            then
                self:advance()
            end
            return {
                type = NodeType.GENERIC_AT_RULE,
                name = name,
                prelude = prelude,
                block = nil,
                line = line,
                column = col,
            }
        end

        local block = self:consumeBlock()

        if name == "media" then
            return self:buildMediaRule(prelude, block, line, col)

        elseif name == "supports" then
            return self:buildSupportsRule(prelude, block, line, col)

        elseif name == "container" then
            return self:buildContainerRule(prelude, block, line, col)

        elseif name == "scope" then
            return self:buildScopeRule(prelude, block, line, col)

        elseif name == "layer" then
            return self:buildLayerRule(prelude, block, line, col)

        elseif
            name == "keyframes"
            or name == "-webkit-keyframes"
            or name == "-moz-keyframes"
            or name == "-o-keyframes"
            or name == "-ms-keyframes"
        then
            return self:buildKeyframesRule(prelude, block, name, line, col)

        elseif name == "font-face" then
            return self:buildFontFaceRule(block, line, col)

        elseif name == "page" then
            return self:buildPageRule(prelude, block, line, col)

        elseif name == "counter-style" then
            return self:buildCounterStyleRule(prelude, block, line, col)

        elseif name == "property" then
            return self:buildPropertyRule(prelude, block, line, col)

        elseif
            name == "font-feature-values"
            or name == "font-palette-values"
            or name == "color-profile"
            or name == "starting-style"
            or name == "view-transition"
        then
            return {
                type = NodeType.GENERIC_AT_RULE,
                name = name,
                prelude = prelude,
                declarations = self:parseDeclarationBlockFromTokens(block),
                line = line,
                column = col,
            }

        else
            -- generic block at-rule
            local subParser = Parser.new(block, self.TT)
            subParser.yieldInterval = self.yieldInterval
            local subSheet = subParser:parseStylesheet()
            for i = 1, #subParser.errors do
                self.errors[#self.errors + 1] = subParser.errors[i]
            end

            return {
                type = NodeType.GENERIC_AT_RULE,
                name = name,
                prelude = prelude,
                block = block,
                rules = subSheet.rules,
                line = line,
                column = col,
            }
        end
    end
end

--- BUILDERS

function Parser:buildCharsetRule(prelude, line, col)
    local charset = "utf-8"

    for i = 1, #prelude do
        if prelude[i].type == self.TT.STRING then
            charset = prelude[i].value
            break
        end
    end

    return {
        type = NodeType.CHARSET_RULE,
        charset = charset,
        line = line,
        column = col,
    }
end

function Parser:buildImportRule(prelude, line, col)
    local TT = self.TT
    local url, layerName, supports, media = "", nil, nil, nil
    local i, n = 1, #prelude

    while i <= n and prelude[i].type == TT.WHITESPACE do
        i = i + 1
    end

    if i <= n then
        local t = prelude[i]
        if t.type == TT.URL or t.type == TT.STRING then
            url = t.value
            i = i + 1
        elseif t.type == TT.FUNCTION and (t.value or ""):lower() == "url" then
            i = i + 1
            while i <= n and prelude[i].type ~= TT.RPAREN do
                if prelude[i].type == TT.STRING then
                    url = prelude[i].value
                end
                i = i + 1
            end
            if i <= n then
                i = i + 1
            end
        end
    end

    -- optional layer() or layer keyword
    while i <= n and prelude[i].type == TT.WHITESPACE do
        i = i + 1
    end

    if i <= n then
        local t = prelude[i]
        if t.type == TT.FUNCTION and (t.value or ""):lower() == "layer" then
            i = i + 1
            local layerToks, lIdx = {}, 1
            while i <= n and prelude[i].type ~= TT.RPAREN do
                layerToks[lIdx] = prelude[i]
                lIdx = lIdx + 1
                i = i + 1
            end
            if i <= n then
                i = i + 1
            end
            layerName =
                self:tokensToString(layerToks):gsub("^%s+", ""):gsub("%s+$", "")
        elseif t.type == TT.IDENT and (t.value or ""):lower() == "layer" then
            layerName = ""
            i = i + 1
        end
    end

    -- optional supports() clause
    while i <= n and prelude[i].type == TT.WHITESPACE do
        i = i + 1
    end

    if
        i <= n
        and prelude[i].type == TT.FUNCTION
        and (prelude[i].value or ""):lower() == "supports"
    then
        i = i + 1
        local supToks, sIdx = {}, 1
        local depth = 1

        while i <= n do
            local tt = prelude[i].type
            if tt == TT.FUNCTION or tt == TT.LPAREN then
                depth = depth + 1
                supToks[sIdx] = prelude[i]
                sIdx = sIdx + 1
            elseif tt == TT.RPAREN then
                depth = depth - 1
                if depth == 0 then
                    i = i + 1
                    break
                end
                supToks[sIdx] = prelude[i]
                sIdx = sIdx + 1
            else
                supToks[sIdx] = prelude[i]
                sIdx = sIdx + 1
            end
            i = i + 1
        end

        supports = self:buildSupportsConditionFromTokens(supToks)
    end

    -- remaining tokens = media query list
    local mediaTokens, mIdx = {}, 1
    while i <= n do
        if prelude[i].type ~= TT.WHITESPACE or mIdx > 1 then
            mediaTokens[mIdx] = prelude[i]
            mIdx = mIdx + 1
        end
        i = i + 1
    end

    if mIdx > 1 then
        media = self:buildMediaQueryListFromTokens(mediaTokens)
    end

    return {
        type = NodeType.IMPORT_RULE,
        url = url,
        layer = layerName,
        supports = supports,
        media = media,
        line = line,
        column = col,
    }
end

function Parser:buildNamespaceRule(prelude, line, col)
    local TT = self.TT
    local prefix, url = nil, ""
    local i, n = 1, #prelude

    while i <= n and prelude[i].type == TT.WHITESPACE do
        i = i + 1
    end

    if i <= n and prelude[i].type == TT.IDENT then
        prefix = prelude[i].value
        i = i + 1
        while i <= n and prelude[i].type == TT.WHITESPACE do
            i = i + 1
        end
    end

    if i <= n then
        local t = prelude[i]
        if t.type == TT.URL or t.type == TT.STRING then
            url = t.value
        end
    end

    return {
        type = NodeType.NAMESPACE_RULE,
        prefix = prefix,
        url = url,
        line = line,
        column = col,
    }
end

function Parser:buildLayerRule(prelude, blockTokens, line, col)
    local names = {}
    local segments = self:splitByTopLevelComma(prelude)

    for i = 1, #segments do
        local seg = segments[i]
        local parts, pIdx = {}, 1
        for j = 1, #seg do
            local t = seg[j]
            if t.type == self.TT.IDENT then
                parts[pIdx] = t.value
                pIdx = pIdx + 1
            end
        end
        if pIdx > 1 then
            names[#names + 1] = table.concat(parts, ".")
        end
    end

    local rules = {}
    if blockTokens then
        local sub = Parser.new(blockTokens, self.TT)
        sub.yieldInterval = self.yieldInterval
        rules = sub:parseStylesheet().rules
        for i = 1, #sub.errors do
            self.errors[#self.errors + 1] = sub.errors[i]
        end
    end

    return {
        type = NodeType.LAYER_RULE,
        names = names,
        name = names[1],
        rules = rules,
        line = line,
        column = col,
    }
end

function Parser:buildMediaRule(prelude, blockTokens, line, col)
    local media = self:buildMediaQueryListFromTokens(prelude)
    local sub = Parser.new(blockTokens, self.TT)
    sub.yieldInterval = self.yieldInterval
    local rules = sub:parseStylesheet().rules

    for i = 1, #sub.errors do
        self.errors[#self.errors + 1] = sub.errors[i]
    end

    return {
        type = NodeType.MEDIA_RULE,
        media = media,
        rules = rules,
        line = line,
        column = col,
    }
end

function Parser:buildMediaQueryListFromTokens(tokens)
    local list = { type = NodeType.MEDIA_QUERY_LIST, queries = {} }
    local segs = self:splitByTopLevelComma(tokens)

    for i = 1, #segs do
        local q = self:buildMediaQueryFromTokens(segs[i])
        if q then
            list.queries[#list.queries + 1] = q
        end
    end

    return list
end

function Parser:buildMediaQueryFromTokens(tokens)
    local TT = self.TT
    local i, n = 1, #tokens

    while i <= n and tokens[i].type == TT.WHITESPACE do
        i = i + 1
    end

    if i > n then
        return nil
    end

    local query = {
        type = NodeType.MEDIA_QUERY,
        negated = false,
        only = false,
        mediaType = nil,
        conditions = {},
        raw = self:tokensToString(tokens):gsub("^%s+", ""):gsub("%s+$", ""),
    }

    if tokens[i].type == TT.IDENT then
        local kw = (tokens[i].value or ""):lower()
        if kw == "not" then
            query.negated = true
            i = i + 1
            while i <= n and tokens[i].type == TT.WHITESPACE do
                i = i + 1
            end
        elseif kw == "only" then
            query.only = true
            i = i + 1
            while i <= n and tokens[i].type == TT.WHITESPACE do
                i = i + 1
            end
        end
    end

    if i <= n and tokens[i].type == TT.IDENT then
        local kw = (tokens[i].value or ""):lower()
        if kw ~= "and" and kw ~= "or" and kw ~= "not" then
            query.mediaType = kw
            i = i + 1
            while i <= n and tokens[i].type == TT.WHITESPACE do
                i = i + 1
            end
        end
    end

    while i <= n do
        local t = tokens[i]

        if t.type == TT.WHITESPACE or t.type == TT.IDENT then
            i = i + 1 -- skip logical keywords

        elseif t.type == TT.LPAREN then
            i = i + 1
            local featureToks, fIdx = {}, 1
            local depth = 1

            while i <= n do
                local tt = tokens[i].type
                if tt == TT.LPAREN then
                    depth = depth + 1
                    featureToks[fIdx] = tokens[i]
                    fIdx = fIdx + 1
                elseif tt == TT.RPAREN then
                    depth = depth - 1
                    if depth == 0 then
                        i = i + 1
                        break
                    end
                    featureToks[fIdx] = tokens[i]
                    fIdx = fIdx + 1
                else
                    featureToks[fIdx] = tokens[i]
                    fIdx = fIdx + 1
                end
                i = i + 1
            end

            local cond = self:buildMediaConditionFromTokens(featureToks)
            if cond then
                query.conditions[#query.conditions + 1] = cond
            end

        elseif t.type == TT.FUNCTION then
            local funcName = (t.value or ""):lower()
            i = i + 1
            local argToks, aIdx = {}, 1
            local depth = 1

            while i <= n do
                local tt = tokens[i].type
                if tt == TT.FUNCTION or tt == TT.LPAREN then
                    depth = depth + 1
                    argToks[aIdx] = tokens[i]
                    aIdx = aIdx + 1
                elseif tt == TT.RPAREN then
                    depth = depth - 1
                    if depth == 0 then
                        i = i + 1
                        break
                    end
                    argToks[aIdx] = tokens[i]
                    aIdx = aIdx + 1
                else
                    argToks[aIdx] = tokens[i]
                    aIdx = aIdx + 1
                end
                i = i + 1
            end

            query.conditions[#query.conditions + 1] = {
                type = NodeType.MEDIA_CONDITION,
                feature = funcName,
                value = self:parseValueFromTokens(argToks),
            }

        else
            i += 1
        end
    end

    return query
end

function Parser:buildMediaConditionFromTokens(tokens)
    local TT = self.TT
    local i, n = 1, #tokens

    while i <= n and tokens[i].type == TT.WHITESPACE do
        i = i + 1
    end

    if i > n then
        return nil
    end

    local condition = {
        type = NodeType.MEDIA_CONDITION,
        feature = nil,
        value = nil,
    }

    if tokens[i].type == TT.IDENT then
        condition.feature = (tokens[i].value or ""):lower()
        i = i + 1

        while i <= n and tokens[i].type == TT.WHITESPACE do
            i = i + 1
        end

        if i <= n and tokens[i].type == TT.COLON then
            i = i + 1
            while i <= n and tokens[i].type == TT.WHITESPACE do
                i = i + 1
            end

            local valToks, vIdx = {}, 1
            while i <= n do
                valToks[vIdx] = tokens[i]
                vIdx = vIdx + 1
                i = i + 1
            end

            condition.value = self:parseValueFromTokens(valToks)
        end
    else
        condition.raw =
            self:tokensToString(tokens):gsub("^%s+", ""):gsub("%s+$", "")
    end

    return condition
end

function Parser:buildSupportsRule(prelude, blockTokens, line, col)
    local condition = self:buildSupportsConditionFromTokens(prelude)
    local sub = Parser.new(blockTokens, self.TT)
    sub.yieldInterval = self.yieldInterval
    local rules = sub:parseStylesheet().rules

    for i = 1, #sub.errors do
        self.errors[#self.errors + 1] = sub.errors[i]
    end

    return {
        type = NodeType.SUPPORTS_RULE,
        condition = condition,
        rules = rules,
        line = line,
        column = col,
    }
end

function Parser:buildContainerRule(prelude, blockTokens, line, col)
    local TT = self.TT
    local name = nil
    local i, n = 1, #prelude

    -- skip leading whitespace
    while i <= n and prelude[i].type == TT.WHITESPACE do
        i = i + 1
    end

    -- optional container name
    local COND_KEYWORDS = {
        style = true,
        ["not"] = true,
        ["and"] = true,
        ["or"] = true,
    }

    if i <= n and prelude[i].type == TT.IDENT then
        local kw = (prelude[i].value or ""):lower()
        if not COND_KEYWORDS[kw] then
            name = prelude[i].value
            i = i + 1
            while i <= n and prelude[i].type == TT.WHITESPACE do
                i = i + 1
            end
        end
    end

    -- remaining prelude = container condition
    local condToks = {}
    for j = i, n do
        condToks[#condToks + 1] = prelude[j]
    end

    local condRaw =
        self:tokensToString(condToks):gsub("^%s+", ""):gsub("%s+$", "")

    local sub = Parser.new(blockTokens, self.TT)
    sub.yieldInterval = self.yieldInterval
    local rules = sub:parseStylesheet().rules

    for j = 1, #sub.errors do
        self.errors[#self.errors + 1] = sub.errors[j]
    end

    return {
        type = NodeType.CONTAINER_RULE,
        name = name,
        condition = condRaw,
        rules = rules,
        line = line,
        column = col,
    }
end

function Parser:buildScopeRule(prelude, blockTokens, line, col)
    local TT = self.TT
    local startSel = nil
    local endSel = nil
    local i, n = 1, #prelude

    while i <= n and prelude[i].type == TT.WHITESPACE do
        i = i + 1
    end

    -- (<start-selector>)
    if i <= n and prelude[i].type == TT.LPAREN then
        i = i + 1
        local inner, depth = {}, 1

        while i <= n do
            local tt = prelude[i].type
            if tt == TT.LPAREN then
                depth = depth + 1
                inner[#inner + 1] = prelude[i]
            elseif tt == TT.RPAREN then
                depth = depth - 1
                if depth == 0 then
                    i = i + 1
                    break
                end
                inner[#inner + 1] = prelude[i]
            else
                inner[#inner + 1] = prelude[i]
            end
            i = i + 1
        end

        startSel = self:parseSelectorListFromTokens(inner)
        while i <= n and prelude[i].type == TT.WHITESPACE do
            i = i + 1
        end
    end

    -- to (<end-selector>)
    if
        i <= n
        and prelude[i].type == TT.IDENT
        and (prelude[i].value or ""):lower() == "to"
    then
        i = i + 1

        while i <= n and prelude[i].type == TT.WHITESPACE do
            i = i + 1
        end

        if i <= n and prelude[i].type == TT.LPAREN then
            i = i + 1
            local inner, depth = {}, 1

            while i <= n do
                local tt = prelude[i].type
                if tt == TT.LPAREN then
                    depth = depth + 1
                    inner[#inner + 1] = prelude[i]
                elseif tt == TT.RPAREN then
                    depth = depth - 1
                    if depth == 0 then
                        i = i + 1
                        break
                    end
                    inner[#inner + 1] = prelude[i]
                else
                    inner[#inner + 1] = prelude[i]
                end
                i = i + 1
            end

            endSel = self:parseSelectorListFromTokens(inner)
        end
    end

    local sub = Parser.new(blockTokens, self.TT)
    sub.yieldInterval = self.yieldInterval
    local rules = sub:parseStylesheet().rules

    for j = 1, #sub.errors do
        self.errors[#self.errors + 1] = sub.errors[j]
    end

    return {
        type = NodeType.SCOPE_RULE,
        start = startSel,
        ["end"] = endSel,
        rules = rules,
        line = line,
        column = col,
    }
end

function Parser:buildSupportsConditionFromTokens(tokens)
    local TT = self.TT
    local raw = self:tokensToString(tokens):gsub("^%s+", ""):gsub("%s+$", "")
    local condition = {
        type = NodeType.SUPPORTS_CONDITION,
        raw = raw,
        operator = nil,
        tests = {},
    }
    local i, n = 1, #tokens
    local negated = false

    while i <= n do
        local t = tokens[i]

        if t.type == TT.WHITESPACE then
            i = i + 1

        elseif t.type == TT.IDENT then
            local kw = (t.value or ""):lower()
            if kw == "not" then
                negated = true
            elseif kw == "and" or kw == "or" then
                condition.operator = kw
                negated = false
            end
            i = i + 1

        elseif t.type == TT.LPAREN then
            i = i + 1
            local inner, inIdx = {}, 1
            local depth = 1

            while i <= n do
                local tt = tokens[i].type
                if tt == TT.LPAREN then
                    depth = depth + 1
                    inner[inIdx] = tokens[i]
                    inIdx = inIdx + 1
                elseif tt == TT.RPAREN then
                    depth = depth - 1
                    if depth == 0 then
                        i = i + 1
                        break
                    end
                    inner[inIdx] = tokens[i]
                    inIdx = inIdx + 1
                else
                    inner[inIdx] = tokens[i]
                    inIdx = inIdx + 1
                end
                i = i + 1
            end

            local decl, _ = self:parseDeclarationFromTokens(inner, 1, #inner)
            condition.tests[#condition.tests + 1] = {
                negated = negated,
                declaration = decl,
                raw = self:tokensToString(inner)
                    :gsub("^%s+", "")
                    :gsub("%s+$", ""),
            }
            negated = false

        else
            i += 1
        end
    end

    return condition
end

function Parser:buildKeyframesRule(prelude, blockTokens, atName, line, col)
    local TT = self.TT
    local animName = ""

    for i = 1, #prelude do
        if prelude[i].type == TT.IDENT or prelude[i].type == TT.STRING then
            animName = prelude[i].value
            break
        end
    end

    local vendorPrefix = atName:match("^%-(%w+)%-")
    local keyframes = {}
    local i, n = 1, #blockTokens

    while i <= n do
        while i <= n and blockTokens[i].type == TT.WHITESPACE do
            i = i + 1
        end
        if i > n then
            break
        end

        local selToks, sIdx = {}, 1
        while i <= n and blockTokens[i].type ~= TT.LBRACE do
            local tt = blockTokens[i].type
            if tt ~= TT.WHITESPACE or sIdx > 1 then
                selToks[sIdx] = blockTokens[i]
                sIdx = sIdx + 1
            end
            i = i + 1
        end

        if i > n or blockTokens[i].type ~= TT.LBRACE then
            break
        end

        i = i + 1 -- consume '{'

        local declToks, dIdx = {}, 1
        local depth = 1

        while i <= n do
            local tt = blockTokens[i].type
            if tt == TT.LBRACE then
                depth = depth + 1
                declToks[dIdx] = blockTokens[i]
                dIdx = dIdx + 1
            elseif tt == TT.RBRACE then
                depth = depth - 1
                if depth == 0 then
                    i = i + 1
                    break
                end
                declToks[dIdx] = blockTokens[i]
                dIdx = dIdx + 1
            else
                declToks[dIdx] = blockTokens[i]
                dIdx = dIdx + 1
            end
            i = i + 1
        end

        local positions = {}
        for j = 1, #selToks do
            local st = selToks[j]
            if st.type == TT.IDENT then
                local kw = (st.value or ""):lower()
                if kw == "from" then
                    positions[#positions + 1] = 0
                elseif kw == "to" then
                    positions[#positions + 1] = 100
                end
            elseif st.type == TT.PERCENTAGE then
                positions[#positions + 1] = st.value
            end
        end

        if #positions > 0 then
            keyframes[#keyframes + 1] = {
                type = NodeType.KEYFRAME,
                positions = positions,
                declarations = self:parseDeclarationBlockFromTokens(declToks),
            }
        end
    end

    return {
        type = NodeType.KEYFRAMES_RULE,
        name = animName,
        vendorPrefix = vendorPrefix,
        keyframes = keyframes,
        line = line,
        column = col,
    }
end

function Parser:buildFontFaceRule(blockTokens, line, col)
    return {
        type = NodeType.FONT_FACE_RULE,
        declarations = self:parseDeclarationBlockFromTokens(blockTokens),
        line = line,
        column = col,
    }
end

function Parser:buildPageRule(prelude, blockTokens, line, col)
    local TT = self.TT
    local selectors = {}
    local i, n = 1, #prelude

    while i <= n do
        local t = prelude[i]
        if t.type == TT.IDENT then
            selectors[#selectors + 1] = { kind = "named", name = t.value }
        elseif t.type == TT.COLON then
            i = i + 1
            if i <= n and prelude[i].type == TT.IDENT then
                selectors[#selectors + 1] = {
                    kind = "pseudo",
                    name = (prelude[i].value or ""):lower(),
                }
            end
        end
        i = i + 1
    end

    return {
        type = NodeType.PAGE_RULE,
        selectors = selectors,
        declarations = self:parseDeclarationBlockFromTokens(blockTokens),
        line = line,
        column = col,
    }
end

function Parser:buildCounterStyleRule(prelude, blockTokens, line, col)
    local name = ""

    for i = 1, #prelude do
        if prelude[i].type == self.TT.IDENT then
            name = prelude[i].value
            break
        end
    end

    return {
        type = NodeType.COUNTER_STYLE_RULE,
        name = name,
        declarations = self:parseDeclarationBlockFromTokens(blockTokens),
        line = line,
        column = col,
    }
end

function Parser:buildPropertyRule(prelude, blockTokens, line, col)
    local name = ""

    for i = 1, #prelude do
        if prelude[i].type == self.TT.IDENT then
            name = prelude[i].value
            break
        end
    end

    return {
        type = NodeType.PROPERTY_RULE,
        name = name,
        declarations = self:parseDeclarationBlockFromTokens(blockTokens),
        line = line,
        column = col,
    }
end

--- DECLARATIONS

function Parser:parseDeclarationBlockFromTokens(tokens)
    local declarations = {}
    local TT = self.TT
    local i, n = 1, #tokens

    while i <= n do
        -- skip ws and lone semicolons
        while i <= n do
            local tt = tokens[i].type
            if tt == TT.WHITESPACE or tt == TT.SEMICOLON then
                i = i + 1
            else
                break
            end
        end

        if i > n then
            break
        end

        local tt = tokens[i].type

        if tt == TT.AT_KEYWORD then
            -- skip nested at-rules
            while
                i <= n
                and tokens[i].type ~= TT.SEMICOLON
                and tokens[i].type ~= TT.LBRACE
            do
                i = i + 1
            end

            if i <= n and tokens[i].type == TT.LBRACE then
                local depth = 1
                i = i + 1
                while i <= n and depth > 0 do
                    if tokens[i].type == TT.LBRACE then
                        depth = depth + 1
                    elseif tokens[i].type == TT.RBRACE then
                        depth = depth - 1
                    end
                    i = i + 1
                end
            elseif i <= n then
                i = i + 1
            end

        elseif tt == TT.RBRACE then
            break

        else
            local decl, newI = self:parseDeclarationFromTokens(tokens, i, n)
            if decl then
                declarations[#declarations + 1] = decl
            end

            i = newI
            if i <= n and tokens[i].type == TT.SEMICOLON then
                i = i + 1
            end
        end
    end

    return declarations
end

function Parser:parseDeclarationFromTokens(tokens, startI, n)
    local TT = self.TT
    local i = startI

    while i <= n and tokens[i].type == TT.WHITESPACE do
        i = i + 1
    end

    if i > n then
        return nil, i
    end

    local t = tokens[i]
    local line = t.line
    local col = t.column

    if t.type ~= TT.IDENT then
        while i <= n and tokens[i].type ~= TT.SEMICOLON do
            i = i + 1
        end
        return nil, i
    end

    local propName = t.value
    i = i + 1

    while i <= n and tokens[i].type == TT.WHITESPACE do
        i = i + 1
    end

    if i > n or tokens[i].type ~= TT.COLON then
        while i <= n and tokens[i].type ~= TT.SEMICOLON do
            i = i + 1
        end
        return nil, i
    end

    i = i + 1 -- consume ':'

    while i <= n and tokens[i].type == TT.WHITESPACE do
        i = i + 1
    end

    local valStartIndex = i
    local valEndIndex = i - 1

    while i <= n and tokens[i].type ~= TT.SEMICOLON do
        valEndIndex = i
        i = i + 1
    end

    -- trim trailing whitespace
    while
        valEndIndex >= valStartIndex
        and tokens[valEndIndex].type == TT.WHITESPACE
    do
        valEndIndex = valEndIndex - 1
    end

    local important = false

    -- detect !important
    if valEndIndex - valStartIndex >= 1 then
        local last = tokens[valEndIndex]
        local prev = tokens[valEndIndex - 1]

        -- handle space between ! and important
        local bangTok = prev
        local bangIdx = valEndIndex - 1

        if prev.type == TT.WHITESPACE and valEndIndex - valStartIndex >= 2 then
            bangTok = tokens[valEndIndex - 2]
            bangIdx = valEndIndex - 2
        end

        if
            last.type == TT.IDENT
            and (last.value or ""):lower() == "important"
            and bangTok.type == TT.DELIM
            and bangTok.value == "!"
        then
            important = true
            valEndIndex = bangIdx - 1
            while
                valEndIndex >= valStartIndex
                and tokens[valEndIndex].type == TT.WHITESPACE
            do
                valEndIndex = valEndIndex - 1
            end
        end
    end

    -- extract value bounds
    local valueToks, vIdx = {}, 1
    for j = valStartIndex, valEndIndex do
        valueToks[vIdx] = tokens[j]
        vIdx = vIdx + 1
    end

    local rawValue = self:tokensToString(valueToks)
    local value = self:parseValueFromTokens(valueToks)
    local normalised = (propName:sub(1, 2) == "--") and propName
        or propName:lower()

    return {
        type = NodeType.DECLARATION,
        property = normalised,
        value = value,
        important = important,
        raw = rawValue,
        line = line,
        column = col,
    },
        i
end

--- VALUES

local function trimTokenArray(tokens, TT_WS)
    local s, e = 1, #tokens

    while s <= e and tokens[s].type == TT_WS do
        s = s + 1
    end

    while e >= s and tokens[e].type == TT_WS do
        e = e - 1
    end

    if s > e then
        return {}
    end

    if s == 1 and e == #tokens then
        return tokens
    end

    local res, idx = {}, 1
    for i = s, e do
        res[idx] = tokens[i]
        idx = idx + 1
    end

    return res
end

function Parser:parseValueFromTokens(tokens)
    tokens = trimTokenArray(tokens, self.TT.WHITESPACE)

    if #tokens == 0 then
        return { type = ValueType.KEYWORD, value = "" }
    end

    -- comma separated list
    local commaSegs = self:splitByTopLevelComma(tokens)
    if #commaSegs > 1 then
        local items, idx = {}, 1
        for i = 1, #commaSegs do
            items[idx] = self:parseValueFromTokens(commaSegs[i])
            idx = idx + 1
        end
        return { type = ValueType.LIST, separator = ",", items = items }
    end

    -- slash separated list
    local slashIdx = nil
    local depth = 0
    local TT = self.TT

    for i = 1, #tokens do
        local t = tokens[i]
        local tt = t.type

        if
            tt == TT.FUNCTION
            or tt == TT.LPAREN
            or tt == TT.LBRACKET
            or tt == TT.LBRACE
        then
            depth = depth + 1
        elseif tt == TT.RPAREN or tt == TT.RBRACKET or tt == TT.RBRACE then
            if depth > 0 then
                depth = depth - 1
            end
        elseif tt == TT.DELIM and t.value == "/" and depth == 0 then
            slashIdx = i
            break
        end
    end

    if slashIdx then
        local left, right = {}, {}
        local lIdx, rIdx = 1, 1

        for i = 1, #tokens do
            if i < slashIdx then
                left[lIdx] = tokens[i]
                lIdx = lIdx + 1
            elseif i > slashIdx then
                right[rIdx] = tokens[i]
                rIdx = rIdx + 1
            end
        end

        return {
            type = ValueType.LIST,
            separator = "/",
            items = {
                self:parseValueFromTokens(left),
                self:parseValueFromTokens(right),
            },
        }
    end

    -- space separated list
    local spaceSegs = self:splitByTopLevelWhitespace(tokens)
    if #spaceSegs > 1 then
        local items, idx = {}, 1
        for i = 1, #spaceSegs do
            items[idx] = self:parseSingleValueFromTokens(spaceSegs[i])
            idx = idx + 1
        end
        return { type = ValueType.LIST, separator = " ", items = items }
    end

    -- single value
    return self:parseSingleValueFromTokens(tokens)
end

function Parser:parseSingleValueFromTokens(tokens)
    if #tokens == 0 then
        return { type = ValueType.KEYWORD, value = "" }
    end

    local TT = self.TT
    local t = tokens[1]

    -- single token fast paths
    if #tokens == 1 then
        if t.type == TT.IDENT then
            local lower = (t.value or ""):lower()
            if COLOR_KEYWORDS[lower] then
                return { type = ValueType.COLOR, value = lower, keyword = lower }
            end
            return {
                type = ValueType.KEYWORD,
                value = lower,
                global = GLOBAL_KEYWORDS[lower] or false,
            }

        elseif t.type == TT.NUMBER then
            return {
                type = ValueType.NUMBER,
                value = t.value,
                raw = t.raw,
                flag = t.flag,
            }

        elseif t.type == TT.DIMENSION then
            return {
                type = ValueType.DIMENSION,
                value = t.value,
                unit = t.unit,
                unitLower = t.unitLower,
                unitCategory = t.unitCategory,
                raw = t.raw,
                flag = t.flag,
            }

        elseif t.type == TT.PERCENTAGE then
            return { type = ValueType.PERCENTAGE, value = t.value, raw = t.raw }

        elseif t.type == TT.STRING then
            return { type = ValueType.STRING, value = t.value }

        elseif t.type == TT.URL or t.type == TT.BAD_URL then
            return { type = ValueType.URL, value = t.value or "" }

        elseif t.type == TT.HASH then
            return {
                type = ValueType.COLOR,
                value = "#" .. (t.value or ""),
                hex = t.value,
            }

        elseif t.type == TT.DELIM then
            return { type = ValueType.KEYWORD, value = t.value or "" }
        end
    end

    -- function token
    if t.type == TT.FUNCTION then
        local funcName = (t.value or ""):lower()
        local argToks, aIdx = {}, 1
        local depth = 1

        for j = 2, #tokens do
            local ft = tokens[j]
            local ftt = ft.type

            if ftt == TT.FUNCTION or ftt == TT.LPAREN then
                depth = depth + 1
                argToks[aIdx] = ft
                aIdx = aIdx + 1
            elseif ftt == TT.RPAREN then
                depth = depth - 1
                if depth == 0 then
                    break
                end
                argToks[aIdx] = ft
                aIdx = aIdx + 1
            else
                argToks[aIdx] = ft
                aIdx = aIdx + 1
            end
        end

        local isColor = COLOR_FUNCTIONS[funcName] or false
        local isMath = MATH_FUNCTIONS[funcName] or false
        local isGradient = GRADIENT_FUNCTIONS[funcName] or false
        local isTransform = TRANSFORM_FUNCTIONS[funcName] or false
        local isFilter = FILTER_FUNCTIONS[funcName] or false
        local isTiming = TIMING_FUNCTIONS[funcName] or false
        local isVar = funcName == "var"
        local isEnv = funcName == "env"

        local vtype
        if isVar then
            vtype = ValueType.VAR
        elseif isEnv then
            vtype = ValueType.ENV
        elseif isMath then
            vtype = ValueType.CALC
        elseif isColor then
            vtype = ValueType.COLOR
        else
            vtype = ValueType.FUNCTION
        end

        local parsedArgs = self:parseFunctionArguments(funcName, argToks)

        return {
            type = vtype,
            name = funcName,
            arguments = parsedArgs,
            isColor = isColor,
            isMath = isMath,
            isGradient = isGradient,
            isTransform = isTransform,
            isFilter = isFilter,
            isTiming = isTiming,
        }
    end

    -- negative values
    if t.type == TT.DELIM and t.value == "-" and #tokens >= 2 then
        local t2 = tokens[2]
        if t2.type == TT.NUMBER then
            return {
                type = ValueType.NUMBER,
                value = -t2.value,
                raw = "-" .. (t2.raw or ""),
                flag = t2.flag,
            }
        elseif t2.type == TT.DIMENSION then
            return {
                type = ValueType.DIMENSION,
                value = -t2.value,
                unit = t2.unit,
                unitLower = t2.unitLower,
                unitCategory = t2.unitCategory,
                raw = "-" .. (t2.raw or ""),
                flag = t2.flag,
            }
        elseif t2.type == TT.PERCENTAGE then
            return {
                type = ValueType.PERCENTAGE,
                value = -t2.value,
                raw = "-" .. (t2.raw or ""),
            }
        end
    end

    -- paren group
    if t.type == TT.LPAREN then
        local inner, iIdx = {}, 1
        for j = 2, #tokens - 1 do
            inner[iIdx] = tokens[j]
            iIdx = iIdx + 1
        end
        return self:parseValueFromTokens(inner)
    end

    -- fallback to raw keyword
    return {
        type = ValueType.KEYWORD,
        value = self:tokensToString(tokens):gsub("^%s+", ""):gsub("%s+$", ""),
    }
end

--- ARGS

function Parser:parseFunctionArguments(funcName, argToks)
    if funcName == "var" then
        return self:parseVarArgs(argToks)
    elseif funcName == "env" then
        return self:parseEnvArgs(argToks)
    elseif MATH_FUNCTIONS[funcName] then
        return self:parseMathArgs(argToks)
    elseif funcName == "rgb" or funcName == "rgba" then
        return self:parseRgbArgs(argToks)
    elseif funcName == "hsl" or funcName == "hsla" then
        return self:parseHslArgs(argToks)
    elseif funcName == "hwb" then
        return self:parseHwbArgs(argToks)
    elseif
        funcName == "lab"
        or funcName == "lch"
        or funcName == "oklab"
        or funcName == "oklch"
    then
        return self:parseLabLchArgs(argToks)
    elseif funcName == "color" then
        return self:parseColorFunctionArgs(argToks)
    elseif funcName == "color-mix" then
        return self:parseColorMixArgs(argToks)
    elseif GRADIENT_FUNCTIONS[funcName] then
        return self:parseGradientArgs(funcName, argToks)
    elseif funcName == "steps" then
        return self:parseStepsArgs(argToks)
    elseif funcName == "cubic-bezier" then
        return self:parseCubicBezierArgs(argToks)
    else
        -- comma-split each segment (generic)
        local segs = self:splitByTopLevelComma(argToks)
        if #segs == 1 then
            return self:parseValueFromTokens(argToks)
        end

        local items, idx = {}, 1
        for i = 1, #segs do
            items[idx] = self:parseValueFromTokens(segs[i])
            idx = idx + 1
        end

        return { type = ValueType.LIST, separator = ",", items = items }
    end
end

function Parser:parseVarArgs(argToks)
    local TT = self.TT
    local i, n = 1, #argToks

    while i <= n and argToks[i].type == TT.WHITESPACE do
        i = i + 1
    end

    local varName = ""
    if i <= n and argToks[i].type == TT.IDENT then
        varName = argToks[i].value
        i = i + 1
    end

    while i <= n and argToks[i].type == TT.WHITESPACE do
        i = i + 1
    end

    local fallback = nil
    if i <= n and argToks[i].type == TT.COMMA then
        i = i + 1
        local fbToks, fIdx = {}, 1
        while i <= n do
            fbToks[fIdx] = argToks[i]
            fIdx = fIdx + 1
            i = i + 1
        end
        fallback = self:parseValueFromTokens(fbToks)
    end

    return { varName = varName, fallback = fallback }
end

function Parser:parseEnvArgs(argToks)
    -- like var() but for safe-area-insets etc.
    return self:parseVarArgs(argToks)
end

function Parser:parseMathArgs(argToks)
    return {
        raw = self:tokensToString(argToks):gsub("^%s+", ""):gsub("%s+$", ""),
        operands = self:parseMathExpression(argToks),
    }
end

function Parser:parseMathExpression(tokens)
    local TT = self.TT
    local segs = self:splitByTopLevelWhitespace(tokens)
    local result = {}

    for i = 1, #segs do
        local seg = segs[i]
        if #seg == 1 and seg[1].type == TT.DELIM then
            result[#result + 1] = { op = seg[1].value }
        else
            result[#result + 1] = self:parseSingleValueFromTokens(seg)
        end
    end

    return result
end

function Parser:parseRgbArgs(argToks)
    argToks = trimTokenArray(argToks, self.TT.WHITESPACE)
    local TT = self.TT
    local hasComma = false

    for i = 1, #argToks do
        if argToks[i].type == TT.COMMA then
            hasComma = true
            break
        end
    end

    local r, g, b, a

    if hasComma then
        local segs = self:splitByTopLevelComma(argToks)
        r = segs[1] and self:parseSingleValueFromTokens(segs[1])
        g = segs[2] and self:parseSingleValueFromTokens(segs[2])
        b = segs[3] and self:parseSingleValueFromTokens(segs[3])
        a = segs[4] and self:parseSingleValueFromTokens(segs[4])
    else
        local slashIdx = nil
        for i = 1, #argToks do
            if argToks[i].type == TT.DELIM and argToks[i].value == "/" then
                slashIdx = i
                break
            end
        end

        local colorToks, alphaToks = {}, {}
        local cIdx, aIdx = 1, 1

        if slashIdx then
            for i = 1, #argToks do
                if i < slashIdx then
                    colorToks[cIdx] = argToks[i]
                    cIdx = cIdx + 1
                elseif i > slashIdx then
                    alphaToks[aIdx] = argToks[i]
                    aIdx = aIdx + 1
                end
            end
        else
            colorToks = argToks
        end

        local spaceParts = self:splitByTopLevelWhitespace(colorToks)
        r = spaceParts[1] and self:parseSingleValueFromTokens(spaceParts[1])
        g = spaceParts[2] and self:parseSingleValueFromTokens(spaceParts[2])
        b = spaceParts[3] and self:parseSingleValueFromTokens(spaceParts[3])
        if #alphaToks > 0 then
            a = self:parseValueFromTokens(alphaToks)
        end
    end

    return { r = r, g = g, b = b, a = a }
end

function Parser:parseHslArgs(argToks)
    argToks = trimTokenArray(argToks, self.TT.WHITESPACE)
    local TT = self.TT
    local hasComma = false

    for i = 1, #argToks do
        if argToks[i].type == TT.COMMA then
            hasComma = true
            break
        end
    end

    local h, s, l, a

    if hasComma then
        local segs = self:splitByTopLevelComma(argToks)
        h = segs[1] and self:parseSingleValueFromTokens(segs[1])
        s = segs[2] and self:parseSingleValueFromTokens(segs[2])
        l = segs[3] and self:parseSingleValueFromTokens(segs[3])
        a = segs[4] and self:parseSingleValueFromTokens(segs[4])
    else
        local slashIdx = nil
        for i = 1, #argToks do
            if argToks[i].type == TT.DELIM and argToks[i].value == "/" then
                slashIdx = i
                break
            end
        end

        local colorToks, alphaToks = {}, {}
        local cIdx, aIdx = 1, 1

        if slashIdx then
            for i = 1, #argToks do
                if i < slashIdx then
                    colorToks[cIdx] = argToks[i]
                    cIdx = cIdx + 1
                elseif i > slashIdx then
                    alphaToks[aIdx] = argToks[i]
                    aIdx = aIdx + 1
                end
            end
        else
            colorToks = argToks
        end

        local p = self:splitByTopLevelWhitespace(colorToks)
        h = p[1] and self:parseSingleValueFromTokens(p[1])
        s = p[2] and self:parseSingleValueFromTokens(p[2])
        l = p[3] and self:parseSingleValueFromTokens(p[3])
        if #alphaToks > 0 then
            a = self:parseValueFromTokens(alphaToks)
        end
    end

    return { h = h, s = s, l = l, a = a }
end

function Parser:parseHwbArgs(argToks)
    local slashIdx = nil
    local TT = self.TT

    for i = 1, #argToks do
        if argToks[i].type == TT.DELIM and argToks[i].value == "/" then
            slashIdx = i
            break
        end
    end

    local colorToks, alphaToks = {}, {}
    local cIdx, aIdx = 1, 1

    if slashIdx then
        for i = 1, #argToks do
            if i < slashIdx then
                colorToks[cIdx] = argToks[i]
                cIdx = cIdx + 1
            elseif i > slashIdx then
                alphaToks[aIdx] = argToks[i]
                aIdx = aIdx + 1
            end
        end
    else
        colorToks = argToks
    end

    local p = self:splitByTopLevelWhitespace(colorToks)
    return {
        h = p[1] and self:parseSingleValueFromTokens(p[1]),
        w = p[2] and self:parseSingleValueFromTokens(p[2]),
        b = p[3] and self:parseSingleValueFromTokens(p[3]),
        a = #alphaToks > 0 and self:parseValueFromTokens(alphaToks) or nil,
    }
end

function Parser:parseLabLchArgs(argToks)
    local TT = self.TT
    local slashIdx = nil

    for i = 1, #argToks do
        if argToks[i].type == TT.DELIM and argToks[i].value == "/" then
            slashIdx = i
            break
        end
    end

    local colorToks, alphaToks = {}, {}
    local cIdx, aIdx = 1, 1

    if slashIdx then
        for i = 1, #argToks do
            if i < slashIdx then
                colorToks[cIdx] = argToks[i]
                cIdx = cIdx + 1
            elseif i > slashIdx then
                alphaToks[aIdx] = argToks[i]
                aIdx = aIdx + 1
            end
        end
    else
        colorToks = argToks
    end

    local p = self:splitByTopLevelWhitespace(colorToks)
    return {
        l = p[1] and self:parseSingleValueFromTokens(p[1]),
        c = p[2] and self:parseSingleValueFromTokens(p[2]),
        h = p[3] and self:parseSingleValueFromTokens(p[3]),
        a = #alphaToks > 0 and self:parseValueFromTokens(alphaToks) or nil,
    }
end

function Parser:parseColorFunctionArgs(argToks)
    local TT = self.TT
    local i, n = 1, #argToks

    while i <= n and argToks[i].type == TT.WHITESPACE do
        i = i + 1
    end

    local colorspace = ""
    if i <= n and argToks[i].type == TT.IDENT then
        colorspace = (argToks[i].value or ""):lower()
        i = i + 1
    end

    local slashIdx = nil
    for idx = i, n do
        if argToks[idx].type == TT.DELIM and argToks[idx].value == "/" then
            slashIdx = idx
            break
        end
    end

    local channelToks, alphaToks = {}, {}
    local cIdx, aIdx = 1, 1

    if slashIdx then
        for idx = i, n do
            if idx < slashIdx then
                channelToks[cIdx] = argToks[idx]
                cIdx = cIdx + 1
            elseif idx > slashIdx then
                alphaToks[aIdx] = argToks[idx]
                aIdx = aIdx + 1
            end
        end
    else
        for idx = i, n do
            channelToks[cIdx] = argToks[idx]
            cIdx = cIdx + 1
        end
    end

    local channels = {}
    local spaceSegs = self:splitByTopLevelWhitespace(channelToks)
    for j = 1, #spaceSegs do
        channels[#channels + 1] = self:parseSingleValueFromTokens(spaceSegs[j])
    end

    return {
        colorspace = colorspace,
        channels = channels,
        alpha = #alphaToks > 0 and self:parseValueFromTokens(alphaToks) or nil,
    }
end

function Parser:parseColorMixArgs(argToks)
    local segs = self:splitByTopLevelComma(argToks)
    local interpolation = segs[1]
            and self:tokensToString(segs[1]):gsub("^%s+", ""):gsub("%s+$", "")
        or ""
    local color1 = segs[2] and self:parseValueFromTokens(segs[2]) or nil
    local color2 = segs[3] and self:parseValueFromTokens(segs[3]) or nil

    return {
        interpolation = interpolation,
        color1 = color1,
        color2 = color2,
    }
end

function Parser:parseGradientArgs(_, argToks)
    local segs = self:splitByTopLevelComma(argToks)
    local stops = {}

    for i = 1, #segs do
        stops[#stops + 1] = self:parseValueFromTokens(segs[i])
    end

    return { stops = stops }
end

function Parser:parseStepsArgs(argToks)
    local segs = self:splitByTopLevelComma(argToks)
    local count = segs[1] and self:parseSingleValueFromTokens(segs[1]) or nil
    local position = segs[2] and self:parseSingleValueFromTokens(segs[2]) or nil

    return { count = count, position = position }
end

function Parser:parseCubicBezierArgs(argToks)
    local segs = self:splitByTopLevelComma(argToks)

    return {
        p1x = segs[1] and self:parseSingleValueFromTokens(segs[1]) or nil,
        p1y = segs[2] and self:parseSingleValueFromTokens(segs[2]) or nil,
        p2x = segs[3] and self:parseSingleValueFromTokens(segs[3]) or nil,
        p2y = segs[4] and self:parseSingleValueFromTokens(segs[4]) or nil,
    }
end

--- SELECTORS

function Parser:parseSelectorListFromTokens(tokens)
    local list = { type = NodeType.SELECTOR_LIST, selectors = {} }
    local segs = self:splitByTopLevelComma(tokens)

    for i = 1, #segs do
        local sel = self:parseSelectorFromTokens(segs[i])
        if sel then
            list.selectors[#list.selectors + 1] = sel
        end
    end

    return list
end

function Parser:parseSelectorFromTokens(tokens)
    local TT = self.TT
    -- inline trim to avoid allocations
    local s, e = 1, #tokens

    while s <= e and tokens[s].type == TT.WHITESPACE do
        s = s + 1
    end

    while e >= s and tokens[e].type == TT.WHITESPACE do
        e = e - 1
    end

    if s > e then
        return nil
    end

    local selector = {
        type = NodeType.SELECTOR,
        components = {},
        specificity = { 0, 0, 0 },
    }

    local i = s
    local compound = {}

    local function flushCompound()
        if #compound > 0 then
            selector.components[#selector.components + 1] = compound
            compound = {}
        end
    end

    while i <= e do
        local t = tokens[i]
        local tt = t.type

        -- combinators / simple selectors from a DELIM
        if tt == TT.DELIM then
            local v = t.value

            if v == ">" or v == "+" or v == "~" then
                flushCompound()
                -- skip surrounding whitespace
                selector.components[#selector.components + 1] = v
                i = i + 1
                while i <= e and tokens[i].type == TT.WHITESPACE do
                    i = i + 1
                end

            elseif v == "|" then
                if
                    i + 1 <= e
                    and tokens[i + 1].type == TT.DELIM
                    and tokens[i + 1].value == "|"
                then
                    flushCompound()
                    selector.components[#selector.components + 1] = "||"
                    i = i + 2
                    while i <= e and tokens[i].type == TT.WHITESPACE do
                        i = i + 1
                    end
                else
                    compound[#compound + 1] =
                        { type = SelectorType.TYPE, value = "|" }
                    i = i + 1
                end

            elseif v == "*" then
                compound[#compound + 1] = { type = SelectorType.UNIVERSAL }
                i = i + 1

            elseif v == "&" then
                compound[#compound + 1] = { type = SelectorType.NESTING }
                i = i + 1

            elseif v == "." then
                -- '.' DELIM + IDENT (calss selector)
                i = i + 1
                if i <= e and tokens[i].type == TT.IDENT then
                    compound[#compound + 1] = {
                        type = SelectorType.CLASS,
                        value = (tokens[i].value or ""):lower(),
                    }
                    i = i + 1
                else
                    -- lone dot -> unknown
                    compound[#compound + 1] =
                        { type = SelectorType.TYPE, value = "." }
                end

            elseif v == "#" then
                -- lone '#' DELIM with no ident
                i = i + 1

            else
                compound[#compound + 1] =
                    { type = SelectorType.TYPE, value = v }
                i = i + 1
            end

        -- descendant combinator
        elseif tt == TT.WHITESPACE then
            local j = i + 1
            while j <= e and tokens[j].type == TT.WHITESPACE do
                j = j + 1
            end

            if j <= e and tokens[j].type ~= TT.COMMA then
                flushCompound()
                selector.components[#selector.components + 1] = " "
            end
            i = j

        elseif tt == TT.IDENT then
            compound[#compound + 1] =
                { type = SelectorType.TYPE, value = (t.value or ""):lower() }
            i = i + 1

        elseif tt == TT.HASH then
            compound[#compound + 1] = {
                type = SelectorType.ID,
                value = t.value or "",
                flag = t.flag or "id",
            }
            i = i + 1

        elseif tt == TT.LBRACKET then
            i = i + 1
            local attrPart, newI = self:parseAttributeSelector(tokens, i, e)
            if attrPart then
                compound[#compound + 1] = attrPart
            end
            i = newI

        elseif tt == TT.COLON then
            local isPseudoElement = false
            i = i + 1
            if i <= e and tokens[i].type == TT.COLON then
                isPseudoElement = true
                i = i + 1
            end
            local part, newI =
                self:parsePseudoSelector(tokens, i, e, isPseudoElement)
            if part then
                compound[#compound + 1] = part
            end
            i = newI

        else
            i = i + 1
        end
    end

    flushCompound()

    if #selector.components == 0 then
        return nil
    end

    selector.specificity = self:calculateSelectorSpecificity(selector)
    return selector
end

function Parser:parseAttributeSelector(tokens, i, n)
    local TT = self.TT

    while i <= n and tokens[i].type == TT.WHITESPACE do
        i = i + 1
    end

    if i > n then
        return nil, i
    end

    local attrName = ""

    if tokens[i].type == TT.IDENT then
        attrName = (tokens[i].value or ""):lower()
        i = i + 1

        -- '|' is a namespace separator unless followed by '='
        if i <= n and tokens[i].type == TT.DELIM and tokens[i].value == "|" then
            local peekNext = i + 1 <= n and tokens[i + 1]
            if peekNext and peekNext.type == TT.IDENT then
                -- namespace|attrName form
                i = i + 1 -- consume '|'
                attrName = attrName .. "|" .. (tokens[i].value or ""):lower()
                i = i + 1
            end
            -- else '|' belongs to the '|=' operator
        end

    elseif tokens[i].type == TT.DELIM and tokens[i].value == "*" then
        attrName = "*"
        i = i + 1

        if i <= n and tokens[i].type == TT.DELIM and tokens[i].value == "|" then
            i = i + 1
            if i <= n and tokens[i].type == TT.IDENT then
                attrName = "*|" .. (tokens[i].value or ""):lower()
                i = i + 1
            end
        end
    end

    while i <= n and tokens[i].type == TT.WHITESPACE do
        i = i + 1
    end

    local operator = AttributeOperator.EXISTS

    if i <= n and tokens[i].type == TT.DELIM then
        local v = tokens[i].value

        if v == "=" then
            operator = AttributeOperator.EQUALS
            i = i + 1
        elseif v == "~" then
            i = i + 1
            if
                i <= n
                and tokens[i].type == TT.DELIM
                and tokens[i].value == "="
            then
                operator = AttributeOperator.INCLUDES
                i = i + 1
            end
        elseif v == "|" then
            i = i + 1
            if
                i <= n
                and tokens[i].type == TT.DELIM
                and tokens[i].value == "="
            then
                operator = AttributeOperator.DASH_MATCH
                i = i + 1
            end
        elseif v == "^" then
            i = i + 1
            if
                i <= n
                and tokens[i].type == TT.DELIM
                and tokens[i].value == "="
            then
                operator = AttributeOperator.PREFIX
                i = i + 1
            end
        elseif v == "$" then
            i = i + 1
            if
                i <= n
                and tokens[i].type == TT.DELIM
                and tokens[i].value == "="
            then
                operator = AttributeOperator.SUFFIX
                i = i + 1
            end
        elseif v == "*" then
            i = i + 1
            if
                i <= n
                and tokens[i].type == TT.DELIM
                and tokens[i].value == "="
            then
                operator = AttributeOperator.SUBSTRING
                i = i + 1
            end
        end

    elseif i <= n and tokens[i].type == TT.DELIM and tokens[i].value == "!" then
        i = i + 1
        if i <= n and tokens[i].type == TT.DELIM and tokens[i].value == "=" then
            i = i + 1
        end
    end

    while i <= n and tokens[i].type == TT.WHITESPACE do
        i = i + 1
    end

    local attrValue = nil

    if operator ~= AttributeOperator.EXISTS and i <= n then
        local tv = tokens[i]
        if tv.type == TT.STRING then
            attrValue = tv.value
            i = i + 1
        elseif tv.type == TT.IDENT then
            attrValue = (tv.value or ""):lower()
            i = i + 1
        end
    end

    while i <= n and tokens[i].type == TT.WHITESPACE do
        i = i + 1
    end

    local caseFlag = nil

    if i <= n and tokens[i].type == TT.IDENT then
        local kw = (tokens[i].value or ""):lower()
        if kw == "i" or kw == "s" then
            caseFlag = kw
            i = i + 1
            while i <= n and tokens[i].type == TT.WHITESPACE do
                i = i + 1
            end
        end
    end

    if i <= n and tokens[i].type == TT.RBRACKET then
        i = i + 1
    end

    return {
        type = SelectorType.ATTRIBUTE,
        attribute = attrName,
        operator = operator,
        value = attrValue,
        caseFlag = caseFlag,
    },
        i
end

function Parser:parsePseudoSelector(tokens, i, n, isPseudoElement)
    local TT = self.TT

    if i > n then
        return nil, i
    end

    local t = tokens[i]

    if t.type == TT.FUNCTION then
        local name = (t.value or ""):lower()
        i = i + 1

        if FUNCTIONAL_PSEUDO_ELEMENTS[name] then
            isPseudoElement = true
        end

        local argToks, aIdx = {}, 1
        local depth = 1

        while i <= n do
            local at = tokens[i]
            if at.type == TT.FUNCTION or at.type == TT.LPAREN then
                depth = depth + 1
                argToks[aIdx] = at
                aIdx = aIdx + 1
                i = i + 1
            elseif at.type == TT.RPAREN then
                depth = depth - 1
                if depth == 0 then
                    i = i + 1
                    break
                end
                argToks[aIdx] = at
                aIdx = aIdx + 1
                i = i + 1
            else
                argToks[aIdx] = at
                aIdx = aIdx + 1
                i = i + 1
            end
        end

        return {
            type = isPseudoElement and SelectorType.PSEUDO_ELEMENT
                or SelectorType.PSEUDO_CLASS,
            name = name,
            functional = true,
            argument = self:parsePseudoArgument(name, argToks),
        },
            i

    elseif t.type == TT.IDENT then
        local name = (t.value or ""):lower()
        i = i + 1

        if not isPseudoElement and PSEUDO_ELEMENTS[name] then
            isPseudoElement = true
        end

        return {
            type = isPseudoElement and SelectorType.PSEUDO_ELEMENT
                or SelectorType.PSEUDO_CLASS,
            name = name,
            functional = false,
        },
            i
    end

    return nil, i
end

function Parser:parsePseudoArgument(name, argToks)
    if
        name == "nth-child"
        or name == "nth-last-child"
        or name == "nth-of-type"
        or name == "nth-last-of-type"
    then
        local ofIdx = nil

        for i = 1, #argToks do
            if
                argToks[i].type == self.TT.IDENT
                and (argToks[i].value or ""):lower() == "of"
            then
                ofIdx = i
                break
            end
        end

        local nthToks, ofSelToks = argToks, nil

        if ofIdx then
            nthToks, ofSelToks = {}, {}
            local nIdx, oIdx = 1, 1

            for i = 1, #argToks do
                if i < ofIdx then
                    nthToks[nIdx] = argToks[i]
                    nIdx = nIdx + 1
                elseif i > ofIdx then
                    ofSelToks[oIdx] = argToks[i]
                    oIdx = oIdx + 1
                end
            end
        end

        local raw = self:tokensToString(nthToks):gsub("%s+", "")
        local a, b = parseAnPlusB(raw)
        local result = { kind = "anplusb", a = a, b = b, raw = raw }

        if ofSelToks then
            result.ofSelector = self:parseSelectorListFromTokens(ofSelToks)
        end

        return result

    elseif
        name == "not"
        or name == "is"
        or name == "where"
        or name == "has"
        or name == "matches"
    then
        return {
            kind = "selectorList",
            selectorList = self:parseSelectorListFromTokens(argToks),
        }
    end

    return {
        kind = "raw",
        raw = self:tokensToString(argToks):gsub("^%s+", ""):gsub("%s+$", ""),
    }
end

--- SPECIFICITY

function Parser:calculateSelectorSpecificity(selector)
    local a, b, c = 0, 0, 0

    local function processCompound(comp)
        for i = 1, #comp do
            local part = comp[i]
            local st = part.type

            if st == SelectorType.ID then
                a = a + 1

            elseif st == SelectorType.CLASS or st == SelectorType.ATTRIBUTE then
                b = b + 1

            elseif st == SelectorType.PSEUDO_CLASS then
                -- :where contributes 0
                if
                    part.name == "not"
                    or part.name == "is"
                    or part.name == "has"
                then
                    if part.argument and part.argument.selectorList then
                        local maxA, maxB, maxC = 0, 0, 0

                        for _, sel in
                            ipairs(part.argument.selectorList.selectors or {})
                        do
                            local sp = self:calculateSelectorSpecificity(sel)
                            if
                                sp[1] > maxA
                                or (sp[1] == maxA and sp[2] > maxB)
                                or (
                                    sp[1] == maxA
                                    and sp[2] == maxB
                                    and sp[3] > maxC
                                )
                            then
                                maxA, maxB, maxC = sp[1], sp[2], sp[3]
                            end
                        end

                        a = a + maxA
                        b = b + maxB
                        c = c + maxC
                    end
                else
                    b = b + 1
                end

            elseif st == SelectorType.PSEUDO_ELEMENT then
                c = c + 1

            elseif st == SelectorType.TYPE then
                if part.value and part.value ~= "*" then
                    c = c + 1
                end
            end
        end
    end

    for i = 1, #(selector.components or {}) do
        if type(selector.components[i]) == "table" then
            processCompound(selector.components[i])
        end
    end

    return { a, b, c }
end

local function compareSpecificity(spA, spB)
    spA = spA or { 0, 0, 0 }
    spB = spB or { 0, 0, 0 }

    for i = 1, 3 do
        local a, b = spA[i] or 0, spB[i] or 0
        if a > b then
            return 1
        elseif a < b then
            return -1
        end
    end

    return 0
end

--- MATCHING

function Parser.matchesSelectorList(element, selectorList)
    if not selectorList or not selectorList.selectors then
        return false
    end

    for i = 1, #selectorList.selectors do
        if Parser.matchesSelector(element, selectorList.selectors[i]) then
            return true
        end
    end

    return false
end

function Parser.matchesSelector(element, selector)
    local comps = selector and selector.components
    if not comps or #comps == 0 then
        return false
    end

    local compounds, combinators = {}, {}

    for i = 1, #comps do
        if type(comps[i]) == "string" then
            combinators[#combinators + 1] = comps[i]
        else
            compounds[#compounds + 1] = comps[i]
        end
    end

    if
        #compounds == 0
        or not Parser.matchesCompound(element, compounds[#compounds])
    then
        return false
    end

    local current = element

    for idx = #compounds - 1, 1, -1 do
        local comb, comp = combinators[idx], compounds[idx]

        if comb == CombinatorType.DESCENDANT then
            local ancestor, matched = current.parentNode, false
            while ancestor and isElementNode(ancestor) do
                if Parser.matchesCompound(ancestor, comp) then
                    current = ancestor
                    matched = true
                    break
                end
                ancestor = ancestor.parentNode
            end
            if not matched then
                return false
            end

        elseif comb == CombinatorType.CHILD then
            local parent = current.parentNode
            if
                not parent
                or not isElementNode(parent)
                or not Parser.matchesCompound(parent, comp)
            then
                return false
            end
            current = parent

        elseif comb == CombinatorType.ADJACENT then
            local prev = current.previousSibling
            while prev and not isElementNode(prev) do
                prev = prev.previousSibling
            end
            if not prev or not Parser.matchesCompound(prev, comp) then
                return false
            end
            current = prev

        elseif comb == CombinatorType.SIBLING then
            local prev, matched = current.previousSibling, false
            while prev do
                if
                    isElementNode(prev) and Parser.matchesCompound(prev, comp)
                then
                    matched = true
                    current = prev
                    break
                end
                prev = prev.previousSibling
            end
            if not matched then
                return false
            end

        else
            return false
        end
    end

    return true
end

function Parser.matchesCompound(element, compound)
    if not element then
        return false
    end

    -- nodeType can be "element", 1, or absent when tagName exists
    local nt = element.nodeType
    if nt ~= nil and nt ~= "element" and nt ~= 1 then
        return false
    end

    if nt == nil and element.tagName == nil then
        return false
    end

    for i = 1, #compound do
        if not Parser.matchesSimple(element, compound[i]) then
            return false
        end
    end

    return true
end

function Parser.matchesSimple(element, part)
    local st = part.type

    if st == SelectorType.UNIVERSAL then
        return true

    elseif st == SelectorType.TYPE then
        return (
            part.value == "*"
            or element.tagName == part.value
            or (
                element.getAttribute
                and element:getAttribute("tagName") == part.value
            )
        )

    elseif st == SelectorType.ID then
        -- accept .id or getAttribute("id")
        local elId = element.id
        if elId == nil and element.getAttribute then
            elId = element:getAttribute("id")
        end
        return elId == part.value

    elseif st == SelectorType.CLASS then
        -- hasClass helper
        if element.hasClass then
            return element:hasClass(part.value)
        end

        -- direct .className
        local cls = element.className
        if cls == nil and element.getAttribute then
            cls = element:getAttribute("class")
        end

        if cls then
            -- split whitespace separated tokens
            for word in cls:gmatch("%S+") do
                if word:lower() == part.value then
                    return true
                end
            end
        end

        return false

    elseif st == SelectorType.ATTRIBUTE then
        return Parser.matchesAttribute(element, part)

    elseif st == SelectorType.PSEUDO_CLASS then
        return Parser.matchesPseudoClass(element, part)
    end

    return false
end

function Parser.matchesAttribute(element, part)
    if not element.getAttribute or not part.attribute then
        return false
    end

    local attrVal = element:getAttribute(part.attribute)
    local op = part.operator

    if op == AttributeOperator.EXISTS or op == "" then
        return attrVal ~= nil
    end

    if attrVal == nil then
        return false
    end

    local pval = part.value or ""
    if part.caseFlag == "i" then
        attrVal, pval = attrVal:lower(), pval:lower()
    end

    if op == AttributeOperator.EQUALS then
        return attrVal == pval
    elseif op == AttributeOperator.PREFIX then
        return attrVal:sub(1, #pval) == pval
    elseif op == AttributeOperator.SUFFIX then
        return #pval == 0 or attrVal:sub(-#pval) == pval
    elseif op == AttributeOperator.SUBSTRING then
        return attrVal:find(pval, 1, true) ~= nil
    elseif op == AttributeOperator.INCLUDES then
        for word in attrVal:gmatch("%S+") do
            if word == pval then
                return true
            end
        end
        return false
    elseif op == AttributeOperator.DASH_MATCH then
        return attrVal == pval or attrVal:sub(1, #pval + 1) == pval .. "-"
    end

    return false
end

function Parser.matchesPseudoClass(element, part)
    local name = part.name

    -- stateless pseudo classes
    if name == "any-link" or name == "link" then
        local tag = element.tagName or ""
        return tag == "a" or tag == "area" or tag == "link"

    elseif name == "defined" then
        return true

    elseif name == "local-link" then
        return false -- requires runtime URL context
    end

    if name == "root" then
        return not element.parentNode or not isElementNode(element.parentNode)

    elseif name == "first-child" then
        local p = element.previousSibling
        while p and not isElementNode(p) do
            p = p.previousSibling
        end
        return p == nil

    elseif name == "last-child" then
        local n = element.nextSibling
        while n and not isElementNode(n) do
            n = n.nextSibling
        end
        return n == nil

    elseif name == "only-child" then
        local p = element.previousSibling
        while p and not isElementNode(p) do
            p = p.previousSibling
        end

        local n = element.nextSibling
        while n and not isElementNode(n) do
            n = n.nextSibling
        end

        return p == nil and n == nil

    elseif name == "empty" then
        local c = element.firstChild
        while c do
            if
                isElementNode(c)
                or (c.nodeType == 3 and (c.textContent or c.data or "") ~= "")
            then
                return false
            end
            c = c.nextSibling
        end
        return true

    elseif
        name == "nth-child"
        or name == "nth-last-child"
        or name == "nth-of-type"
        or name == "nth-last-of-type"
    then
        if not part.argument or not part.argument.a then
            return false
        end

        local ofType = (name == "nth-of-type" or name == "nth-last-of-type")
        local pos = (name == "nth-last-child" or name == "nth-last-of-type")
                and nthLastChildPosition(element, ofType)
            or nthChildPosition(element, ofType)

        return matchesAnPlusB(part.argument.a, part.argument.b, pos)

    elseif name == "not" and part.argument and part.argument.selectorList then
        return not Parser.matchesSelectorList(
            element,
            part.argument.selectorList
        )

    elseif
        (name == "is" or name == "where")
        and part.argument
        and part.argument.selectorList
    then
        return Parser.matchesSelectorList(element, part.argument.selectorList)

    elseif name == "has" and part.argument and part.argument.selectorList then
        -- :has() looks forward in the DOM
        local function hasDescendantMatch(el, selList)
            local child = el.firstChild
            while child do
                if isElementNode(child) then
                    if Parser.matchesSelectorList(child, selList) then
                        return true
                    end
                    if hasDescendantMatch(child, selList) then
                        return true
                    end
                end
                child = child.nextSibling
            end
            return false
        end

        return hasDescendantMatch(element, part.argument.selectorList)

    elseif name == "any-link" or name == "link" then
        local href = element.href
            or (element.getAttribute and element:getAttribute("href"))

        return (
            element.tagName == "a"
            or element.tagName == "area"
            or element.tagName == "link"
        ) and href ~= nil

    elseif name == "visited" then
        return false -- can't determine visited state

    elseif
        name == "hover"
        or name == "focus"
        or name == "focus-visible"
        or name == "focus-within"
        or name == "active"
    then
        return false

    elseif name == "disabled" then
        local dis = element.disabled
            or (
                element.getAttribute
                and element:getAttribute("disabled") ~= nil
            )
        return dis and true or false

    elseif name == "enabled" then
        local dis = element.disabled
            or (
                element.getAttribute
                and element:getAttribute("disabled") ~= nil
            )
        return not (dis and true or false)

    elseif name == "checked" then
        local ch = element.checked
            or (element.getAttribute and element:getAttribute("checked") ~= nil)
        return ch and true or false

    elseif name == "scope" then
        return true -- assume element is in scope
    end

    return false
end

--- SHORTHAND

local function expandBox4(decl, longhands)
    local val = decl.value
    local items = (val.type == ValueType.LIST and val.separator == " ")
            and val.items
        or (val.value ~= "" and { val } or {})
    local n = #items

    if n == 0 then
        return {}
    end

    local t = items[1]
    local r = items[2] or t
    local b = items[3] or t
    local l = items[4] or items[2] or t

    local vals, result = { t, r, b, l }, {}

    for i = 1, 4 do
        result[i] = {
            type = NodeType.DECLARATION,
            property = longhands[i],
            value = vals[i],
            important = decl.important,
            raw = decl.raw,
            expanded = true,
        }
    end

    return result
end

function Parser.expandShorthand(decl)
    local lh = SHORTHAND_PROPERTIES[decl.property]
    if not lh then
        return nil
    end

    if
        decl.property == "margin"
        or decl.property == "padding"
        or decl.property == "inset"
        or decl.property:match("^border")
    then
        if #lh == 4 then
            return expandBox4(decl, lh)
        end
    end

    local res = {}
    for i = 1, #lh do
        res[i] = {
            type = NodeType.DECLARATION,
            property = lh[i],
            value = decl.value,
            important = decl.important,
            raw = decl.raw,
            expanded = true,
        }
    end

    return res
end

local function evaluateMediaQuery(mediaQuery, viewport)
    if not mediaQuery or not viewport then
        return true
    end

    local mtype = mediaQuery.mediaType
    if mtype and mtype ~= "all" then
        local match = (mtype == (viewport.type or "screen"):lower())
        if mediaQuery.negated then
            match = not match
        end
        if not match then
            return false
        end
    end

    return true
end

function Parser.collectMatchingRules(stylesheet, element, viewport, result)
    result = result or {}

    for i = 1, #(stylesheet.rules or {}) do
        local rule = stylesheet.rules[i]

        if
            rule.type == NodeType.STYLE_RULE
            and Parser.matchesSelectorList(element, rule.selectorList)
        then
            local bestSpec = { 0, 0, 0 }

            for j = 1, #(rule.selectorList.selectors or {}) do
                local sel = rule.selectorList.selectors[j]
                if
                    Parser.matchesSelector(element, sel)
                    and compareSpecificity(
                            sel.specificity or { 0, 0, 0 },
                            bestSpec
                        )
                        > 0
                then
                    bestSpec = sel.specificity
                end
            end

            result[#result + 1] = {
                rule = rule,
                specificity = bestSpec,
                sourceIndex = #result + 1,
            }

        elseif rule.type == NodeType.MEDIA_RULE then
            local active = not viewport

            if viewport then
                for j = 1, #(rule.media and rule.media.queries or {}) do
                    if evaluateMediaQuery(rule.media.queries[j], viewport) then
                        active = true
                        break
                    end
                end
            end

            if active then
                Parser.collectMatchingRules(rule, element, viewport, result)
            end

        elseif rule.rules then -- GENERIC_AT_RULE, SUPPORTS, LAYER
            Parser.collectMatchingRules(rule, element, viewport, result)
        end
    end

    return result
end

function Parser.sortRulesBySpecificity(rules)
    table.sort(rules, function(a, b)
        local cmp = compareSpecificity(a.specificity, b.specificity)
        return cmp ~= 0 and cmp < 0 or a.sourceIndex < b.sourceIndex
    end)
    return rules
end

function Parser.buildCascadedProperties(sortedRules)
    local normal, important = {}, {}

    for i = 1, #sortedRules do
        local decls = sortedRules[i].rule.declarations or {}
        for j = 1, #decls do
            local d = decls[j]
            if d.important then
                important[d.property] = d
            else
                normal[d.property] = d
            end
        end
    end

    return normal, important
end

--- API

function Parser.getNodeTypes()
    return NodeType
end

function Parser.getSelectorTypes()
    return SelectorType
end

function Parser.getCombinatorTypes()
    return CombinatorType
end

function Parser.getValueTypes()
    return ValueType
end

function Parser.getAttributeOperators()
    return AttributeOperator
end

function Parser.getShorthandProperties()
    return SHORTHAND_PROPERTIES
end

function Parser.getInheritedProperties()
    return INHERITED_PROPERTIES
end

function Parser.getAnPlusBParser()
    return parseAnPlusB
end

function Parser.getSpecificityComparator()
    return compareSpecificity
end

function Parser.isShorthand(property)
    return SHORTHAND_PROPERTIES[property] ~= nil
end

function Parser.isInherited(property)
    return INHERITED_PROPERTIES[property] == true
end

function Parser:setYieldInterval(interval)
    self.yieldInterval = interval
end

function Parser:getErrors()
    return self.errors
end

function Parser.parseCSS(css, CSSLexer, options)
    options = options or {}

    local lexer = CSSLexer.create(css, {
        preserveComments = options.preserveComments or false,
        collapseWhitespace = options.collapseWhitespace ~= false,
        yieldInterval = options.yieldInterval or 2000,
    })

    local parser = Parser.new(lexer:tokenize(), CSSLexer.getTokenTypes())
    parser.yieldInterval = options.yieldInterval or 200

    return parser:parseStylesheet(), parser
end

function Parser.getMatchingRules(css, element, CSSLexer, viewport, options)
    local stylesheet = Parser.parseCSS(css, CSSLexer, options)

    return Parser.sortRulesBySpecificity(
        Parser.collectMatchingRules(stylesheet, element, viewport)
    ),
        stylesheet
end

function Parser.create(tokens, tokenTypes, options)
    local parser = Parser.new(tokens, tokenTypes)
    if options and options.yieldInterval then
        parser.yieldInterval = options.yieldInterval
    end
    return parser
end

return Parser

-- EOF