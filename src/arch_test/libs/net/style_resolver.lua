--[[
    "Style Resolver module for dOS"
    
    @module style_resolver
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


local StyleResolver = {}

local NAMED_COLORS = {
    black = Color3.fromRGB(0, 0, 0),
    silver = Color3.fromRGB(192, 192, 192),
    gray = Color3.fromRGB(128, 128, 128),
    grey = Color3.fromRGB(128, 128, 128),
    white = Color3.fromRGB(255, 255, 255),
    maroon = Color3.fromRGB(128, 0, 0),
    red = Color3.fromRGB(255, 0, 0),
    purple = Color3.fromRGB(128, 0, 128),
    fuchsia = Color3.fromRGB(255, 0, 255),
    green = Color3.fromRGB(0, 128, 0),
    lime = Color3.fromRGB(0, 255, 0),
    olive = Color3.fromRGB(128, 128, 0),
    yellow = Color3.fromRGB(255, 255, 0),
    navy = Color3.fromRGB(0, 0, 128),
    blue = Color3.fromRGB(0, 0, 255),
    teal = Color3.fromRGB(0, 128, 128),
    aqua = Color3.fromRGB(0, 255, 255),
    orange = Color3.fromRGB(255, 165, 0),
    rebeccapurple = Color3.fromRGB(102, 51, 153),
    aliceblue = Color3.fromRGB(240, 248, 255),
    antiquewhite = Color3.fromRGB(250, 235, 215),
    aquamarine = Color3.fromRGB(127, 255, 212),
    azure = Color3.fromRGB(240, 255, 255),
    beige = Color3.fromRGB(245, 245, 220),
    bisque = Color3.fromRGB(255, 228, 196),
    blanchedalmond = Color3.fromRGB(255, 235, 205),
    blueviolet = Color3.fromRGB(138, 43, 226),
    brown = Color3.fromRGB(165, 42, 42),
    burlywood = Color3.fromRGB(222, 184, 135),
    cadetblue = Color3.fromRGB(95, 158, 160),
    chartreuse = Color3.fromRGB(127, 255, 0),
    chocolate = Color3.fromRGB(210, 105, 30),
    coral = Color3.fromRGB(255, 127, 80),
    cornflowerblue = Color3.fromRGB(100, 149, 237),
    cornsilk = Color3.fromRGB(255, 248, 220),
    crimson = Color3.fromRGB(220, 20, 60),
    cyan = Color3.fromRGB(0, 255, 255),
    darkblue = Color3.fromRGB(0, 0, 139),
    darkcyan = Color3.fromRGB(0, 139, 139),
    darkgoldenrod = Color3.fromRGB(184, 134, 11),
    darkgray = Color3.fromRGB(169, 169, 169),
    darkgreen = Color3.fromRGB(0, 100, 0),
    darkgrey = Color3.fromRGB(169, 169, 169),
    darkkhaki = Color3.fromRGB(189, 183, 107),
    darkmagenta = Color3.fromRGB(139, 0, 139),
    darkolivegreen = Color3.fromRGB(85, 107, 47),
    darkorange = Color3.fromRGB(255, 140, 0),
    darkorchid = Color3.fromRGB(153, 50, 204),
    darkred = Color3.fromRGB(139, 0, 0),
    darksalmon = Color3.fromRGB(233, 150, 122),
    darkseagreen = Color3.fromRGB(143, 188, 143),
    darkslateblue = Color3.fromRGB(72, 61, 139),
    darkslategray = Color3.fromRGB(47, 79, 79),
    darkslategrey = Color3.fromRGB(47, 79, 79),
    darkturquoise = Color3.fromRGB(0, 206, 209),
    darkviolet = Color3.fromRGB(148, 0, 211),
    deeppink = Color3.fromRGB(255, 20, 147),
    deepskyblue = Color3.fromRGB(0, 191, 255),
    dimgray = Color3.fromRGB(105, 105, 105),
    dimgrey = Color3.fromRGB(105, 105, 105),
    dodgerblue = Color3.fromRGB(30, 144, 255),
    firebrick = Color3.fromRGB(178, 34, 34),
    floralwhite = Color3.fromRGB(255, 250, 240),
    forestgreen = Color3.fromRGB(34, 139, 34),
    gainsboro = Color3.fromRGB(220, 220, 220),
    ghostwhite = Color3.fromRGB(248, 248, 255),
    gold = Color3.fromRGB(255, 215, 0),
    goldenrod = Color3.fromRGB(218, 165, 32),
    greenyellow = Color3.fromRGB(173, 255, 47),
    honeydew = Color3.fromRGB(240, 255, 240),
    hotpink = Color3.fromRGB(255, 105, 180),
    indianred = Color3.fromRGB(205, 92, 92),
    indigo = Color3.fromRGB(75, 0, 130),
    ivory = Color3.fromRGB(255, 255, 240),
    khaki = Color3.fromRGB(240, 230, 140),
    lavender = Color3.fromRGB(230, 230, 250),
    lavenderblush = Color3.fromRGB(255, 240, 245),
    lawngreen = Color3.fromRGB(124, 252, 0),
    lemonchiffon = Color3.fromRGB(255, 250, 205),
    lightblue = Color3.fromRGB(173, 216, 230),
    lightcoral = Color3.fromRGB(240, 128, 128),
    lightcyan = Color3.fromRGB(224, 255, 255),
    lightgoldenrodyellow = Color3.fromRGB(250, 250, 210),
    lightgray = Color3.fromRGB(211, 211, 211),
    lightgreen = Color3.fromRGB(144, 238, 144),
    lightgrey = Color3.fromRGB(211, 211, 211),
    lightpink = Color3.fromRGB(255, 182, 193),
    lightsalmon = Color3.fromRGB(255, 160, 122),
    lightseagreen = Color3.fromRGB(32, 178, 170),
    lightskyblue = Color3.fromRGB(135, 206, 250),
    lightslategray = Color3.fromRGB(119, 136, 153),
    lightslategrey = Color3.fromRGB(119, 136, 153),
    lightsteelblue = Color3.fromRGB(176, 196, 222),
    lightyellow = Color3.fromRGB(255, 255, 224),
    limegreen = Color3.fromRGB(50, 205, 50),
    linen = Color3.fromRGB(250, 240, 230),
    magenta = Color3.fromRGB(255, 0, 255),
    mediumaquamarine = Color3.fromRGB(102, 205, 170),
    mediumblue = Color3.fromRGB(0, 0, 205),
    mediumorchid = Color3.fromRGB(186, 85, 211),
    mediumpurple = Color3.fromRGB(147, 112, 219),
    mediumseagreen = Color3.fromRGB(60, 179, 113),
    mediumslateblue = Color3.fromRGB(123, 104, 238),
    mediumspringgreen = Color3.fromRGB(0, 250, 154),
    mediumturquoise = Color3.fromRGB(72, 209, 204),
    mediumvioletred = Color3.fromRGB(199, 21, 133),
    midnightblue = Color3.fromRGB(25, 25, 112),
    mintcream = Color3.fromRGB(245, 255, 250),
    mistyrose = Color3.fromRGB(255, 228, 225),
    moccasin = Color3.fromRGB(255, 228, 181),
    navajowhite = Color3.fromRGB(255, 222, 173),
    oldlace = Color3.fromRGB(253, 245, 230),
    olivedrab = Color3.fromRGB(107, 142, 35),
    orangered = Color3.fromRGB(255, 69, 0),
    orchid = Color3.fromRGB(218, 112, 214),
    palegoldenrod = Color3.fromRGB(238, 232, 170),
    palegreen = Color3.fromRGB(152, 251, 152),
    paleturquoise = Color3.fromRGB(175, 238, 238),
    palevioletred = Color3.fromRGB(219, 112, 147),
    papayawhip = Color3.fromRGB(255, 239, 213),
    peachpuff = Color3.fromRGB(255, 218, 185),
    peru = Color3.fromRGB(205, 133, 63),
    pink = Color3.fromRGB(255, 192, 203),
    plum = Color3.fromRGB(221, 160, 221),
    powderblue = Color3.fromRGB(176, 224, 230),
    rosybrown = Color3.fromRGB(188, 143, 143),
    royalblue = Color3.fromRGB(65, 105, 225),
    saddlebrown = Color3.fromRGB(139, 69, 19),
    salmon = Color3.fromRGB(250, 128, 114),
    sandybrown = Color3.fromRGB(244, 164, 96),
    seagreen = Color3.fromRGB(46, 139, 87),
    seashell = Color3.fromRGB(255, 245, 238),
    sienna = Color3.fromRGB(160, 82, 45),
    skyblue = Color3.fromRGB(135, 206, 235),
    slateblue = Color3.fromRGB(106, 90, 205),
    slategray = Color3.fromRGB(112, 128, 144),
    slategrey = Color3.fromRGB(112, 128, 144),
    snow = Color3.fromRGB(255, 250, 250),
    springgreen = Color3.fromRGB(0, 255, 127),
    steelblue = Color3.fromRGB(70, 130, 180),
    tan = Color3.fromRGB(210, 180, 140),
    thistle = Color3.fromRGB(216, 191, 216),
    tomato = Color3.fromRGB(255, 99, 71),
    turquoise = Color3.fromRGB(64, 224, 208),
    violet = Color3.fromRGB(238, 130, 238),
    wheat = Color3.fromRGB(245, 222, 179),
    whitesmoke = Color3.fromRGB(245, 245, 245),
    yellowgreen = Color3.fromRGB(154, 205, 50),
}

local function toCamelCase(prop)
    return (prop:gsub("%-(%l)", string.upper))
end

local PROPERTY_ALIASES = {
    ["border-width"] = "borderWidth",
    ["border-color"] = "borderColor",
    ["border-style"] = "borderStyle",
    ["border-radius"] = "borderRadius",
}

local function cssToCamel(prop)
    return PROPERTY_ALIASES[prop] or toCamelCase(prop)
end

local INHERITED_PROPS = {
    color = true,
    cursor = true,
    direction = true,
    visibility = true,
    font = true,
    ["font-family"] = true,
    ["font-size"] = true,
    ["font-style"] = true,
    ["font-variant"] = true,
    ["font-weight"] = true,
    ["font-stretch"] = true,
    ["font-kerning"] = true,
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
    ["text-shadow"] = true,
    ["white-space"] = true,
    ["word-spacing"] = true,
    ["word-break"] = true,
    ["overflow-wrap"] = true,
    ["hyphens"] = true,
    ["tab-size"] = true,
    ["border-collapse"] = true,
    ["border-spacing"] = true,
    ["caption-side"] = true,
    ["empty-cells"] = true,
    ["pointer-events"] = true,
    orphans = true,
    widows = true,
    quotes = true,
    ["writing-mode"] = true,
    ["text-orientation"] = true,
}

local INHERITED_CAMEL = {}
for k in pairs(INHERITED_PROPS) do
    INHERITED_CAMEL[cssToCamel(k)] = true
end

local UA_STYLES = {
    body = {
        display = "block",
        marginTop = 8,
        marginRight = 8,
        marginBottom = 8,
        marginLeft = 8,
    },
    html = { display = "block" },
    head = { display = "none" },
    h1 = {
        display = "block",
        fontSize = 32,
        fontWeight = "bold",
        marginTop = 21,
        marginBottom = 21,
    },
    h2 = {
        display = "block",
        fontSize = 24,
        fontWeight = "bold",
        marginTop = 19,
        marginBottom = 19,
    },
    h3 = {
        display = "block",
        fontSize = 18,
        fontWeight = "bold",
        marginTop = 18,
        marginBottom = 18,
    },
    h4 = {
        display = "block",
        fontSize = 16,
        fontWeight = "bold",
        marginTop = 21,
        marginBottom = 21,
    },
    h5 = {
        display = "block",
        fontSize = 13,
        fontWeight = "bold",
        marginTop = 22,
        marginBottom = 22,
    },
    h6 = {
        display = "block",
        fontSize = 11,
        fontWeight = "bold",
        marginTop = 24,
        marginBottom = 24,
    },
    p = { display = "block", marginTop = 16, marginBottom = 16 },
    div = { display = "block" },
    section = { display = "block" },
    article = { display = "block" },
    aside = { display = "block" },
    header = { display = "block" },
    footer = { display = "block" },
    main = { display = "block" },
    nav = { display = "block" },
    address = { display = "block", fontStyle = "italic" },
    blockquote = {
        display = "block",
        marginTop = 16,
        marginBottom = 16,
        marginLeft = 40,
        marginRight = 40,
        paddingLeft = 10,
        borderLeftWidth = 4,
        borderLeftColor = Color3.fromRGB(200, 200, 200),
    },
    pre = {
        display = "block",
        fontFamily = "monospace",
        whiteSpace = "pre",
        marginTop = 16,
        marginBottom = 16,
        backgroundColor = Color3.fromRGB(245, 245, 245),
        padding = 10,
    },
    code = {
        display = "inline",
        fontFamily = "monospace",
        backgroundColor = Color3.fromRGB(240, 240, 240),
        paddingLeft = 4,
        paddingRight = 4,
    },
    kbd = {
        display = "inline",
        fontFamily = "monospace",
        backgroundColor = Color3.fromRGB(238, 238, 238),
        borderWidth = 1,
        borderColor = Color3.fromRGB(180, 180, 180),
    },
    samp = { display = "inline", fontFamily = "monospace" },
    tt = { display = "inline", fontFamily = "monospace" },
    ul = {
        display = "block",
        listStyleType = "disc",
        marginTop = 16,
        marginBottom = 16,
        paddingLeft = 40,
    },
    ol = {
        display = "block",
        listStyleType = "decimal",
        marginTop = 16,
        marginBottom = 16,
        paddingLeft = 40,
    },
    li = { display = "list-item" },
    dl = { display = "block", marginTop = 16, marginBottom = 16 },
    dt = { display = "block", fontWeight = "bold", marginTop = 8 },
    dd = { display = "block", marginLeft = 40, marginTop = 4, marginBottom = 4 },
    span = { display = "inline" },
    a = {
        display = "inline",
        color = Color3.fromRGB(0, 0, 238),
        textDecoration = "underline",
    },
    strong = { display = "inline", fontWeight = "bold" },
    b = { display = "inline", fontWeight = "bold" },
    em = { display = "inline", fontStyle = "italic" },
    i = { display = "inline", fontStyle = "italic" },
    u = { display = "inline", textDecoration = "underline" },
    s = { display = "inline", textDecoration = "line-through" },
    del = { display = "inline", textDecoration = "line-through" },
    ins = { display = "inline", textDecoration = "underline" },
    mark = { display = "inline", backgroundColor = Color3.fromRGB(255, 255, 0) },
    small = { display = "inline", fontSize = 0.8 }, -- relative factor
    big = { display = "inline", fontSize = 1.2 }, -- relative factor
    sub = { display = "inline", fontSize = 0.83, verticalAlign = "sub" },
    sup = { display = "inline", fontSize = 0.83, verticalAlign = "super" },
    abbr = { display = "inline", textDecoration = "underline" },
    cite = { display = "inline", fontStyle = "italic" },
    dfn = { display = "inline", fontStyle = "italic" },
    var = { display = "inline", fontStyle = "italic" },
    q = { display = "inline" },
    br = { display = "inline" },
    wbr = { display = "inline" },
    hr = {
        display = "block",
        borderTopWidth = 1,
        borderTopColor = Color3.fromRGB(128, 128, 128),
        marginTop = 8,
        marginBottom = 8,
        height = 2,
        backgroundColor = Color3.fromRGB(200, 200, 200),
    },
    img = { display = "inline-block" },
    figure = {
        display = "block",
        marginTop = 16,
        marginBottom = 16,
        marginLeft = 40,
        marginRight = 40,
    },
    figcaption = {
        display = "block",
        fontStyle = "italic",
        textAlign = "center",
        marginTop = 6,
    },
    table = {
        display = "table",
        borderCollapse = "separate",
        marginTop = 8,
        marginBottom = 8,
    },
    caption = {
        display = "table-caption",
        textAlign = "center",
        fontWeight = "bold",
        padding = 8,
    },
    tr = { display = "table-row" },
    td = {
        display = "table-cell",
        padding = 8,
        borderWidth = 1,
        borderColor = Color3.fromRGB(200, 200, 200),
    },
    th = {
        display = "table-cell",
        padding = 8,
        fontWeight = "bold",
        textAlign = "center",
        backgroundColor = Color3.fromRGB(240, 240, 240),
        borderWidth = 1,
        borderColor = Color3.fromRGB(200, 200, 200),
    },
    thead = { display = "table-header-group" },
    tbody = { display = "table-row-group" },
    tfoot = { display = "table-footer-group" },
    colgroup = { display = "table-column-group" },
    col = { display = "table-column" },
    button = {
        display = "inline-block",
        height = 30,
        paddingTop = 6,
        paddingBottom = 6,
        paddingLeft = 12,
        paddingRight = 12,
        backgroundColor = Color3.fromRGB(240, 240, 240),
        borderWidth = 1,
        borderColor = Color3.fromRGB(180, 180, 180),
    },
    input = {
        display = "inline-block",
        height = 28,
        padding = 4,
        borderWidth = 1,
        borderColor = Color3.fromRGB(180, 180, 180),
        backgroundColor = Color3.fromRGB(255, 255, 255),
    },
    select = {
        display = "inline-block",
        height = 28,
        padding = 4,
        borderWidth = 1,
        borderColor = Color3.fromRGB(180, 180, 180),
    },
    textarea = {
        display = "inline-block",
        padding = 8,
        borderWidth = 1,
        borderColor = Color3.fromRGB(180, 180, 180),
        fontFamily = "monospace",
    },
    label = { display = "inline", marginRight = 8 },
    fieldset = {
        display = "block",
        borderWidth = 1,
        borderColor = Color3.fromRGB(180, 180, 180),
        padding = 10,
        marginTop = 8,
        marginBottom = 8,
    },
    legend = {
        display = "block",
        fontWeight = "bold",
        paddingLeft = 4,
        paddingRight = 4,
    },
    form = { display = "block" },
    details = { display = "block", marginTop = 8, marginBottom = 8 },
    summary = { display = "list-item", fontWeight = "bold" },
    dialog = { display = "block" },
    menu = {
        display = "block",
        listStyleType = "disc",
        marginTop = 16,
        marginBottom = 16,
        paddingLeft = 40,
    },
}

local INITIAL = {
    display = "inline",
    visibility = "visible",
    opacity = 1,
    color = Color3.new(0, 0, 0),
    backgroundColor = nil, -- transparent
    backgroundImage = "none",
    backgroundRepeat = "repeat",
    backgroundPosition = "0% 0%",
    backgroundSize = "auto",
    backgroundAttachment = "scroll",
    fontSize = 16,
    fontFamily = "sans-serif",
    fontWeight = "normal",
    fontStyle = "normal",
    fontVariant = "normal",
    lineHeight = "normal",
    letterSpacing = "normal",
    wordSpacing = "normal",
    textAlign = "start",
    textDecoration = "none",
    textTransform = "none",
    textIndent = 0,
    whiteSpace = "normal",
    verticalAlign = "baseline",
    width = "auto",
    height = "auto",
    minWidth = 0,
    minHeight = 0,
    maxWidth = "none",
    maxHeight = "none",
    marginTop = 0,
    marginRight = 0,
    marginBottom = 0,
    marginLeft = 0,
    paddingTop = 0,
    paddingRight = 0,
    paddingBottom = 0,
    paddingLeft = 0,
    borderTopWidth = 0,
    borderRightWidth = 0,
    borderBottomWidth = 0,
    borderLeftWidth = 0,
    borderTopColor = Color3.new(0, 0, 0),
    borderRightColor = Color3.new(0, 0, 0),
    borderBottomColor = Color3.new(0, 0, 0),
    borderLeftColor = Color3.new(0, 0, 0),
    borderTopStyle = "none",
    borderRightStyle = "none",
    borderBottomStyle = "none",
    borderLeftStyle = "none",
    borderTopLeftRadius = 0,
    borderTopRightRadius = 0,
    borderBottomRightRadius = 0,
    borderBottomLeftRadius = 0,
    outlineWidth = 0,
    outlineColor = Color3.new(0, 0, 0),
    outlineStyle = "none",
    position = "static",
    top = "auto",
    right = "auto",
    bottom = "auto",
    left = "auto",
    zIndex = "auto",
    overflow = "visible",
    overflowX = "visible",
    overflowY = "visible",
    flexDirection = "row",
    flexWrap = "nowrap",
    justifyContent = "flex-start",
    alignItems = "stretch",
    alignContent = "stretch",
    alignSelf = "auto",
    flexGrow = 0,
    flexShrink = 1,
    flexBasis = "auto",
    order = 0,
    gap = 0,
    rowGap = 0,
    columnGap = 0,
    gridTemplateColumns = "none",
    gridTemplateRows = "none",
    gridAutoFlow = "row",
    gridAutoColumns = "auto",
    gridAutoRows = "auto",
    cursor = "auto",
    pointerEvents = "auto",
    userSelect = "auto",
    resize = "none",
    boxSizing = "content-box",
    transform = "none",
    transformOrigin = "50% 50%",
    willChange = "auto",
    objectFit = "fill",
    objectPosition = "50% 50%",
    listStyleType = "disc",
    listStylePosition = "outside",
    listStyleImage = "none",
    borderCollapse = "separate",
    borderSpacing = 0,
    tableLayout = "auto",
    emptyCells = "show",
    captionSide = "top",
    direction = "ltr",
    writingMode = "horizontal-tb",
    animationName = "none",
    animationDuration = 0,
    animationTimingFunction = "ease",
    animationDelay = 0,
    animationIterationCount = 1,
    animationDirection = "normal",
    animationFillMode = "none",
    animationPlayState = "running",
    transitionProperty = "none",
    transitionDuration = 0,
    transitionTimingFunction = "ease",
    transitionDelay = 0,
}

local function hslToRgb(h, s, l)
    h = h % 360
    s = math.max(0, math.min(1, s))
    l = math.max(0, math.min(1, l))

    if s == 0 then
        return l, l, l
    end

    local function hue(p, q, t)
        if t < 0 then
            t = t + 1
        end
        if t > 1 then
            t = t - 1
        end
        if t < 1 / 6 then
            return p + (q - p) * 6 * t
        end
        if t < 1 / 2 then
            return q
        end
        if t < 2 / 3 then
            return p + (q - p) * (2 / 3 - t) * 6
        end
        return p
    end

    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q

    return hue(p, q, h / 360 + 1 / 3),
        hue(p, q, h / 360),
        hue(p, q, h / 360 - 1 / 3)
end

local function hwbToRgb(h, w, b)
    w = math.max(0, math.min(1, w))
    b = math.max(0, math.min(1, b))

    if w + b >= 1 then
        local g = w / (w + b)
        return g, g, g
    end

    local r, g, bv = hslToRgb(h, 1, 0.5)
    r = r * (1 - w - b) + w
    g = g * (1 - w - b) + w
    bv = bv * (1 - w - b) + w

    return r, g, bv
end

local function oklabToRgb(L, a, b)
    local l_ = L + 0.3963377774 * a + 0.2158037573 * b
    local m_ = L - 0.1055613458 * a - 0.0638541728 * b
    local s_ = L - 0.0894841775 * a - 1.2914855480 * b

    local l = l_ * l_ * l_
    local m = m_ * m_ * m_
    local s = s_ * s_ * s_

    local R = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    local G = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    local B = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

    local function linearToSrgb(c)
        c = math.max(0, math.min(1, c))
        if c <= 0.0031308 then
            return 12.92 * c
        end
        return 1.055 * (c ^ (1 / 2.4)) - 0.055
    end

    return linearToSrgb(R), linearToSrgb(G), linearToSrgb(B)
end

local function lchToLab(L, C, H)
    local hr = H * math.pi / 180
    return L, C * math.cos(hr), C * math.sin(hr)
end

local function labToXyz(L, a, b)
    local fy = (L + 16) / 116
    local fx = a / 500 + fy
    local fz = fy - b / 200

    local x = (fx ^ 3 > 0.008856 and fx ^ 3 or (fx - 16 / 116) / 7.787) * 0.95047
    local y = (L > 7.9996248 and ((L + 16) / 116) ^ 3 or L / 903.3) * 1.00000
    local z = (fz ^ 3 > 0.008856 and fz ^ 3 or (fz - 16 / 116) / 7.787) * 1.08883

    return x, y, z
end

local function xyzToRgb(x, y, z)
    local R = 3.2406 * x - 1.5372 * y - 0.4986 * z
    local G = -0.9689 * x + 1.8758 * y + 0.0415 * z
    local B = 0.0557 * x - 0.2040 * y + 1.0570 * z

    local function linearToSrgb(c)
        c = math.max(0, math.min(1, c))
        if c <= 0.0031308 then
            return 12.92 * c
        end
        return 1.055 * (c ^ (1 / 2.4)) - 0.055
    end

    return linearToSrgb(R), linearToSrgb(G), linearToSrgb(B)
end

local function evaluateCalcOperands(
    operands,
    parentFontSize,
    rootFontSize,
    viewportW,
    viewportH
)
    if not operands then
        return 0
    end

    local result = 0
    local op = "+"

    for _, item in ipairs(operands) do
        if item.op then
            op = item.op
        else
            local val = 0
            local vt = item.type

            if vt == "number" then
                val = item.value or 0
            elseif vt == "dimension" then
                local v = item.value or 0
                local u = item.unitLower or item.unit or ""

                if u == "px" then
                    val = v
                elseif u == "em" then
                    val = v * (parentFontSize or 16)
                elseif u == "rem" then
                    val = v * (rootFontSize or 16)
                elseif u == "vw" then
                    val = v * (viewportW or 800) / 100
                elseif u == "vh" then
                    val = v * (viewportH or 600) / 100
                elseif u == "pt" then
                    val = v * 1.3333
                elseif u == "cm" then
                    val = v * 37.795
                elseif u == "mm" then
                    val = v * 3.7795
                elseif u == "in" then
                    val = v * 96
                else
                    val = v :: any -- to make Selene shut up
                end
            elseif vt == "percentage" then
                val = (item.value or 0) -- % left for the caller
            elseif
                vt == "calc"
                and item.arguments
                and item.arguments.operands
            then
                val = evaluateCalcOperands(
                    item.arguments.operands,
                    parentFontSize,
                    rootFontSize,
                    viewportW,
                    viewportH
                )
            end

            if op == "+" then
                result = result + val
            elseif op == "-" then
                result = result - val
            elseif op == "*" then
                result = result * val
            elseif op == "/" and val ~= 0 then
                result = result / val
            end
        end
    end

    return result
end

local function resolveColor(val, customProps, _, _, _, _)
    if type(val) == "userdata" then
        return val
    end

    if type(val) ~= "table" then
        if type(val) == "string" then
            local s = val:lower():gsub("^%s+", ""):gsub("%s+$", "")
            if s == "transparent" or s == "none" then
                return nil
            end
            if NAMED_COLORS[s] then
                return NAMED_COLORS[s]
            end

            local hex6 = s:match("^#([%da-f][%da-f][%da-f][%da-f][%da-f][%da-f])$")
            if hex6 then
                return Color3.fromRGB(
                    tonumber(hex6:sub(1, 2), 16),
                    tonumber(hex6:sub(3, 4), 16),
                    tonumber(hex6:sub(5, 6), 16)
                )
            end

            local hex3 = s:match("^#([%da-f][%da-f][%da-f])$")
            if hex3 then
                local r = hex3:sub(1, 1)
                return Color3.fromRGB(
                    tonumber(r .. r, 16),
                    tonumber(hex3:sub(2, 2) .. hex3:sub(2, 2), 16),
                    tonumber(hex3:sub(3, 3) .. hex3:sub(3, 3), 16)
                )
            end

            local rr, gg, bb = s:match("rgba?%s*%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
            if rr then
                return Color3.fromRGB(tonumber(rr), tonumber(gg), tonumber(bb))
            end
        end

        return nil
    end

    local vt = val.type

    if vt == "color" then
        if val.hex then
            local h = val.hex
            if #h == 3 then
                h = h:sub(1, 1):rep(2)
                    .. h:sub(2, 2):rep(2)
                    .. h:sub(3, 3):rep(2)
            end
            if #h == 6 then
                return Color3.fromRGB(
                    tonumber(h:sub(1, 2), 16) or 0,
                    tonumber(h:sub(3, 4), 16) or 0,
                    tonumber(h:sub(5, 6), 16) or 0
                )
            end
            if #h == 8 then
                return Color3.fromRGB(
                    tonumber(h:sub(1, 2), 16) or 0,
                    tonumber(h:sub(3, 4), 16) or 0,
                    tonumber(h:sub(5, 6), 16) or 0
                )
            end
        end

        if val.value and type(val.value) == "string" then
            local s = val.value:lower()
            if NAMED_COLORS[s] then
                return NAMED_COLORS[s]
            end
            if s == "transparent" then
                return nil
            end
        end

        local args = val.arguments
        if not args then
            return nil
        end

        local name = (val.name or ""):lower()

        local function num(v, maxV, defaultV)
            if not v then
                return defaultV or 0
            end
            if type(v) == "number" then
                return math.max(0, math.min(maxV, v))
            end
            if v.type == "percentage" then
                return math.max(0, math.min(maxV, (v.value or 0) / 100 * maxV))
            end
            if v.type == "number" then
                return math.max(0, math.min(maxV, v.value or 0))
            end
            if v.type == "dimension" then
                return math.max(0, math.min(maxV, v.value or 0))
            end
            return defaultV or 0
        end

        local function pct(v, defaultV)
            if not v then
                return defaultV or 0
            end
            if type(v) == "number" then
                return v
            end
            if v.type == "percentage" then
                return (v.value or 0) / 100
            end
            if v.type == "number" then
                return (v.value or 0)
            end
            return defaultV or 0
        end

        if name == "rgb" or name == "rgba" then
            local r = num(args.r, 255, 0) / 255
            local g = num(args.g, 255, 0) / 255
            local b = num(args.b, 255, 0) / 255
            return Color3.new(
                math.clamp(r, 0, 1),
                math.clamp(g, 0, 1),
                math.clamp(b, 0, 1)
            )
        elseif name == "hsl" or name == "hsla" then
            local hv = args.h
            local hDeg = 0
            if hv then
                if hv.type == "dimension" then
                    local u = hv.unitLower or hv.unit or ""
                    if u == "rad" then
                        hDeg = (hv.value or 0) * 180 / math.pi
                    elseif u == "grad" then
                        hDeg = (hv.value or 0) * 0.9
                    elseif u == "turn" then
                        hDeg = (hv.value or 0) * 360
                    else
                        hDeg = hv.value or 0
                    end
                elseif hv.type == "number" then
                    hDeg = hv.value or 0
                end
            end

            local sl = pct(args.s, 1)
            local ll = pct(args.l, 0.5)
            local r, g, b = hslToRgb(hDeg, sl, ll)

            return Color3.new(
                math.clamp(r, 0, 1),
                math.clamp(g, 0, 1),
                math.clamp(b, 0, 1)
            )
        elseif name == "hwb" then
            local hv = args.h
            local hDeg = 0
            if hv then
                hDeg = hv.value or 0
            end

            local w = pct(args.w, 0)
            local bv = pct(args.b, 0)
            local r, g, b = hwbToRgb(hDeg, w, bv)

            return Color3.new(
                math.clamp(r, 0, 1),
                math.clamp(g, 0, 1),
                math.clamp(b, 0, 1)
            )
        elseif name == "oklab" then
            local L = num(args.l, 1, 0)
            local a = num(args.c, 0.5, 0) -- abuse .c for a
            local b = num(args.h, 0.5, 0) -- abuse .h for b

            local r, g, bv = oklabToRgb(L, a, b)
            return Color3.new(
                math.clamp(r, 0, 1),
                math.clamp(g, 0, 1),
                math.clamp(bv, 0, 1)
            )
        elseif name == "oklch" then
            local L = num(args.l, 1, 0)
            local C = num(args.c, 0.5, 0)
            local H = num(args.h, 360, 0)
            local lab_L, lab_a, lab_b =
                L,
                C * math.cos(H * math.pi / 180),
                C * math.sin(H * math.pi / 180)
            local r, g, b = oklabToRgb(lab_L, lab_a, lab_b)

            return Color3.new(
                math.clamp(r, 0, 1),
                math.clamp(g, 0, 1),
                math.clamp(b, 0, 1)
            )
        elseif name == "lab" then
            local L = num(args.l, 100, 0)
            local a = num(args.c, 150, 0)
            local b = num(args.h, 150, 0)
            local x, y, z = labToXyz(L, a, b)
            local r, g, bv = xyzToRgb(x, y, z)

            return Color3.new(
                math.clamp(r, 0, 1),
                math.clamp(g, 0, 1),
                math.clamp(bv, 0, 1)
            )
        elseif name == "lch" then
            local L = num(args.l, 100, 0)
            local C = num(args.c, 150, 0)
            local H = num(args.h, 360, 0)
            local la, lb_a, lb_b = lchToLab(L, C, H)
            local x, y, z = labToXyz(la, lb_a, lb_b)
            local r, g, b = xyzToRgb(x, y, z)

            return Color3.new(
                math.clamp(r, 0, 1),
                math.clamp(g, 0, 1),
                math.clamp(b, 0, 1)
            )
        elseif name == "color-mix" then
            local c1 = args.color1 and resolveColor(args.color1, customProps)
                or Color3.new(0, 0, 0)
            local c2 = args.color2 and resolveColor(args.color2, customProps)
                or Color3.new(1, 1, 1)

            if c1 and c2 then
                return Color3.new(
                    (c1.R + c2.R) / 2,
                    (c1.G + c2.G) / 2,
                    (c1.B + c2.B) / 2
                )
            end

            return c1 or c2
        elseif name == "color" then
            local cs = val.colorspace or (args and args.colorspace) or "srgb"
            local channels = args and args.channels or {}

            if cs == "srgb" or cs == "display-p3" or cs == "a98-rgb" then
                local r = channels[1] and pct(channels[1], 0) or 0
                local g = channels[2] and pct(channels[2], 0) or 0
                local b = channels[3] and pct(channels[3], 0) or 0

                return Color3.new(
                    math.clamp(r, 0, 1),
                    math.clamp(g, 0, 1),
                    math.clamp(b, 0, 1)
                )
            end
        end

        return nil
    end

    if vt == "keyword" then
        local kw = (val.value or ""):lower()
        if kw == "transparent" then
            return nil
        end
        if kw == "currentcolor" then
            return nil
        end -- handled by caller
        return NAMED_COLORS[kw]
    end

    if vt == "var" then
        if customProps and val.arguments then
            local varName = val.arguments.varName
            if varName and customProps[varName] then
                return resolveColor(customProps[varName], customProps)
            end
            if val.arguments.fallback then
                return resolveColor(val.arguments.fallback, customProps)
            end
        end

        return nil
    end

    return nil
end

local function resolveLength(
    val,
    parentFontSize,
    rootFontSize,
    viewportW,
    viewportH,
    parentLength,
    customProps
)
    if type(val) == "number" then
        return val
    end

    if type(val) == "string" then
        if val == "auto" or val == "none" or val == "normal" then
            return val
        end

        local n = tonumber(val)
        if n then
            return n
        end

        local px = val:match("^([%-]?%d+%.?%d*)px$")
        if px then
            return tonumber(px)
        end

        local em = val:match("^([%-]?%d+%.?%d*)em$")
        if em then
            return (tonumber(em) or 0) * (parentFontSize or 16)
        end

        return nil
    end

    if type(val) ~= "table" then
        return nil
    end

    local vt = val.type

    if vt == "keyword" then
        local kw = (val.value or ""):lower()
        if
            kw == "auto"
            or kw == "none"
            or kw == "normal"
            or kw == "inherit"
        then
            return kw
        end

        local n = tonumber(kw)
        if n then
            return n
        end

        return kw
    end

    if vt == "number" then
        return val.value or 0
    end

    if vt == "dimension" then
        local v = val.value or 0
        local u = val.unitLower or (val.unit and val.unit:lower()) or ""

        if u == "px" then
            return v
        elseif u == "pt" then
            return v * 1.3333
        elseif u == "pc" then
            return v * 16
        elseif u == "cm" then
            return v * 37.7953
        elseif u == "mm" then
            return v * 3.77953
        elseif u == "in" then
            return v * 96
        elseif u == "q" then
            return v * 0.9449
        elseif u == "em" then
            return v * (parentFontSize or 16)
        elseif u == "rem" then
            return v * (rootFontSize or 16)
        elseif u == "ex" then
            return v * (parentFontSize or 16) * 0.5
        elseif u == "ch" then
            return v * (parentFontSize or 16) * 0.5
        elseif u == "vw" then
            return v * (viewportW or 800) / 100
        elseif u == "vh" then
            return v * (viewportH or 600) / 100
        elseif u == "vmin" then
            return v * math.min(viewportW or 800, viewportH or 600) / 100
        elseif u == "vmax" then
            return v * math.max(viewportW or 800, viewportH or 600) / 100
        elseif u:match("^[sld]v") then
            local base = u:sub(3)
            if base == "w" then
                return v * (viewportW or 800) / 100
            elseif base == "h" then
                return v * (viewportH or 600) / 100
            else
                return v * math.min(viewportW or 800, viewportH or 600) / 100
            end
        elseif u == "cqw" then
            return v * (viewportW or 800) / 100
        elseif u == "cqh" then
            return v * (viewportH or 600) / 100
        elseif u == "cqmin" then
            return v * math.min(viewportW or 800, viewportH or 600) / 100
        elseif u == "cqmax" then
            return v * math.max(viewportW or 800, viewportH or 600) / 100
        elseif u == "fr" then
            return v -- grid fraction: raw value, renderer handles
        else
            return v
        end
    end

    if vt == "percentage" then
        if parentLength then
            return (val.value or 0) / 100 * parentLength
        end
        return tostring(val.value) .. "%" -- unresolved
    end

    if vt == "calc" then
        local args = val.arguments
        if args and args.operands then
            return evaluateCalcOperands(
                args.operands,
                parentFontSize,
                rootFontSize,
                viewportW,
                viewportH
            )
        end

        return 0
    end

    if vt == "var" then
        if customProps and val.arguments then
            local varName = val.arguments.varName
            if varName and customProps[varName] then
                return resolveLength(
                    customProps[varName],
                    parentFontSize,
                    rootFontSize,
                    viewportW,
                    viewportH,
                    parentLength,
                    customProps
                )
            end
            if val.arguments.fallback then
                return resolveLength(
                    val.arguments.fallback,
                    parentFontSize,
                    rootFontSize,
                    viewportW,
                    viewportH,
                    parentLength,
                    customProps
                )
            end
        end

        return 0
    end

    return nil
end

local function resolveTime(val)
    if type(val) == "number" then
        return val
    end
    if type(val) ~= "table" then
        return 0
    end

    if val.type == "dimension" then
        local v = val.value or 0
        local u = val.unitLower or (val.unit and val.unit:lower()) or ""
        if u == "ms" then
            return v / 1000
        end
        return v -- assume seconds
    end

    if val.type == "number" then
        return val.value or 0
    end

    if val.type == "keyword" then
        return tonumber(val.value) or 0
    end

    return 0
end

local EASING_MAP = {
    ease = { Enum.EasingStyle.Quad, Enum.EasingDirection.InOut },
    linear = { Enum.EasingStyle.Linear, Enum.EasingDirection.In },
    ["ease-in"] = { Enum.EasingStyle.Quad, Enum.EasingDirection.In },
    ["ease-out"] = { Enum.EasingStyle.Quad, Enum.EasingDirection.Out },
    ["ease-in-out"] = { Enum.EasingStyle.Quad, Enum.EasingDirection.InOut },
    ["step-start"] = { Enum.EasingStyle.Bounce, Enum.EasingDirection.In },
    ["step-end"] = { Enum.EasingStyle.Bounce, Enum.EasingDirection.Out },
}

local function resolveEasing(val)
    if type(val) ~= "table" then
        local s = tostring(val):lower()
        return EASING_MAP[s] or EASING_MAP["ease"]
    end

    if val.type == "keyword" then
        local kw = (val.value or ""):lower()
        return EASING_MAP[kw] or EASING_MAP["ease"]
    end

    if val.type == "function" then
        local name = (val.name or ""):lower()
        if name == "cubic-bezier" then
            return { Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut }
        end
        if name == "steps" then
            return { Enum.EasingStyle.Linear, Enum.EasingDirection.In }
        end
        return EASING_MAP[(val.name or ""):lower()] or EASING_MAP["ease"]
    end

    return EASING_MAP["ease"]
end

local function collectCustomProperties(declarations, parentCustomProps)
    local props = {}

    if parentCustomProps then
        for k, v in pairs(parentCustomProps) do
            props[k] = v
        end
    end

    for i = 1, #declarations do
        local d = declarations[i]
        if d.property and d.property:sub(1, 2) == "--" then
            props[d.property] = d.value
        end
    end

    return props
end

local function extractKeyframes(cssom)
    local kfMap = {}
    if not cssom or not cssom.rules then
        return kfMap
    end

    local function scanRules(rules)
        for i = 1, #rules do
            local rule = rules[i]
            if rule.type == "keyframes_rule" then
                local name = rule.name
                if name then
                    kfMap[name] = rule.keyframes or {}
                end
            elseif rule.rules then
                scanRules(rule.rules)
            end
        end
    end

    scanRules(cssom.rules)
    return kfMap
end

local function buildAnimationDescriptors(cs, keyframesMap)
    local name = cs.animationName
    if not name or name == "none" or name == "" then
        return nil
    end

    local names = {}
    for n in name:gmatch("[^,]+") do
        names[#names + 1] = n:gsub("^%s+", ""):gsub("%s+$", "")
    end

    local animations = {}
    for _, animName in ipairs(names) do
        if animName ~= "none" then
            local kf = keyframesMap and keyframesMap[animName]

            local duration = cs.animationDuration
            if type(duration) == "table" then
                duration = duration[1] or 0
            end

            local easing = cs.animationTimingFunction
            local easingPair = resolveEasing(easing)

            local delay = cs.animationDelay
            if type(delay) == "table" then
                delay = delay[1] or 0
            end

            local iterCount = cs.animationIterationCount
            if
                iterCount == "infinite"
                or (type(iterCount) == "number" and iterCount < 0)
            then
                iterCount = true -- WoS Tween looped flag
            end

            local dir = cs.animationDirection
            if type(dir) == "table" then
                dir = dir[1] or "normal"
            end

            animations[#animations + 1] = {
                name = animName,
                keyframes = kf,
                duration = duration or 0,
                easingStyle = easingPair[1],
                easingDirection = easingPair[2],
                delay = delay or 0,
                iterationCount = iterCount or 1,
                direction = dir or "normal",
                fillMode = cs.animationFillMode or "none",
                playState = cs.animationPlayState or "running",
            }
        end
    end

    return #animations > 0 and animations or nil
end

local function buildTransitionDescriptors(cs)
    local prop = cs.transitionProperty
    if not prop or prop == "none" or prop == "" then
        return nil
    end

    local duration = cs.transitionDuration or 0
    if type(duration) == "table" then
        duration = duration[1] or 0
    end
    if duration <= 0 then
        return nil
    end

    local easing = cs.transitionTimingFunction or "ease"
    local easingPair = resolveEasing(easing)

    local delay = cs.transitionDelay or 0
    if type(delay) == "table" then
        delay = delay[1] or 0
    end

    local properties = {}
    if prop == "all" then
        properties[1] = "all"
    else
        for p in prop:gmatch("[^,]+") do
            properties[#properties + 1] = p:gsub("^%s+", ""):gsub("%s+$", "")
        end
    end

    return {
        properties = properties,
        duration = duration,
        easingStyle = easingPair[1],
        easingDirection = easingPair[2],
        delay = delay,
    }
end

local function parseInlineStyleAttribute(styleStr, CSSLexer, CSSParser)
    if not styleStr or styleStr == "" then
        return {}
    end

    local wrapped = "* { " .. styleStr .. " }"
    local ok, result = pcall(function()
        local stylesheet, _ = CSSParser.parseCSS(wrapped, CSSLexer, {
            collapseWhitespace = true,
            yieldInterval = 9999,
        })
        if stylesheet and stylesheet.rules and stylesheet.rules[1] then
            return stylesheet.rules[1].declarations or {}
        end
        return {}
    end)

    if ok then
        return result
    end

    return {}
end

local function applyShorthandToStyle(style, prop, val, pfs, rfs, vw, vh, cp)
    local function len(v)
        return resolveLength(v, pfs, rfs, vw, vh, nil, cp)
    end

    if prop == "margin" or prop == "padding" or prop == "inset" then
        local items
        if
            type(val) == "table"
            and val.type == "list"
            and val.separator == " "
        then
            items = val.items
        elseif type(val) == "table" then
            items = { val }
        else
            return -- can't expand
        end

        local tops, rights, bots, lefts =
            items[1],
            items[2] or items[1],
            items[3] or items[1],
            items[4] or items[2] or items[1]
        local tv, rv, bv, lv = len(tops), len(rights), len(bots), len(lefts)

        if prop == "margin" then
            style.marginTop = tv
            style.marginRight = rv
            style.marginBottom = bv
            style.marginLeft = lv
        elseif prop == "padding" then
            style.paddingTop = tv
            style.paddingRight = rv
            style.paddingBottom = bv
            style.paddingLeft = lv
        elseif prop == "inset" then
            style.top = tv
            style.right = rv
            style.bottom = bv
            style.left = lv
        end
        return true

    elseif prop == "border-radius" then
        local items
        if
            type(val) == "table"
            and val.type == "list"
            and val.separator == " "
        then
            items = val.items
        elseif type(val) == "table" then
            items = { val }
        else
            return false
        end

        local tl = len(items[1]) or 0
        local tr = len(items[2] or items[1]) or 0
        local br = len(items[3] or items[1]) or 0
        local bl = len(items[4] or items[2] or items[1]) or 0

        style.borderTopLeftRadius = tl
        style.borderTopRightRadius = tr
        style.borderBottomRightRadius = br
        style.borderBottomLeftRadius = bl
        return true

    elseif prop == "border" then
        local items
        if
            type(val) == "table"
            and val.type == "list"
            and val.separator == " "
        then
            items = val.items
        elseif type(val) == "table" then
            items = { val }
        else
            return false
        end

        for _, item in ipairs(items) do
            if item.type == "dimension" or item.type == "number" then
                local bw = len(item) or 0
                style.borderTopWidth = bw
                style.borderRightWidth = bw
                style.borderBottomWidth = bw
                style.borderLeftWidth = bw
            elseif
                item.type == "color"
                or (
                    item.type == "keyword"
                    and NAMED_COLORS[(item.value or ""):lower()]
                )
            then
                local bc = resolveColor(item, cp, pfs, rfs, vw, vh)
                if bc then
                    style.borderTopColor = bc
                    style.borderRightColor = bc
                    style.borderBottomColor = bc
                    style.borderLeftColor = bc
                end
            elseif item.type == "keyword" then
                local kw = (item.value or ""):lower()
                if
                    not (
                        kw ~= "none"
                        and kw ~= "hidden"
                        and kw ~= "solid"
                        and kw ~= "dashed"
                        and kw ~= "dotted"
                    )
                then
                    style.borderTopStyle = kw
                    style.borderRightStyle = kw
                    style.borderBottomStyle = kw
                    style.borderLeftStyle = kw
                end
            end
        end
        return true

    elseif prop == "border-width" then
        local items
        if
            type(val) == "table"
            and val.type == "list"
            and val.separator == " "
        then
            items = val.items
        else
            items = { val }
        end

        local t = len(items[1]) or 0
        local r = len(items[2] or items[1]) or 0
        local b = len(items[3] or items[1]) or 0
        local l = len(items[4] or items[2] or items[1]) or 0

        style.borderTopWidth = t
        style.borderRightWidth = r
        style.borderBottomWidth = b
        style.borderLeftWidth = l
        return true

    elseif prop == "border-color" then
        local items
        if
            type(val) == "table"
            and val.type == "list"
            and val.separator == " "
        then
            items = val.items
        else
            items = { val }
        end

        local function bc(v)
            return resolveColor(v, cp, pfs, rfs, vw, vh)
        end

        local t = bc(items[1])
        local r = bc(items[2] or items[1])
        local b = bc(items[3] or items[1])
        local l = bc(items[4] or items[2] or items[1])

        if t then
            style.borderTopColor = t
        end
        if r then
            style.borderRightColor = r
        end
        if b then
            style.borderBottomColor = b
        end
        if l then
            style.borderLeftColor = l
        end
        return true

    elseif prop == "border-style" then
        local items
        if
            type(val) == "table"
            and val.type == "list"
            and val.separator == " "
        then
            items = val.items
        else
            items = { val }
        end

        local function bsv(v)
            return type(v) == "table" and (v.value or "none")
                or (type(v) == "string" and v or "none")
        end

        local t = bsv(items[1])
        local r = bsv(items[2] or items[1])
        local b = bsv(items[3] or items[1])
        local l = bsv(items[4] or items[2] or items[1])

        style.borderTopStyle = t
        style.borderRightStyle = r
        style.borderBottomStyle = b
        style.borderLeftStyle = l
        return true

    elseif prop == "flex" then
        local items
        if
            type(val) == "table"
            and val.type == "list"
            and val.separator == " "
        then
            items = val.items
        else
            items = { val }
        end

        if #items >= 1 then
            local n1 = type(items[1]) == "table" and items[1].value
                or tonumber(items[1])
            if n1 then
                style.flexGrow = n1
            end
        end
        if #items >= 2 then
            local n2 = type(items[2]) == "table" and items[2].value
                or tonumber(items[2])
            if n2 then
                style.flexShrink = n2
            end
        end
        if #items >= 3 then
            style.flexBasis = len(items[3]) or "auto"
        end
        return true

    elseif prop == "flex-flow" then
        local items
        if
            type(val) == "table"
            and val.type == "list"
            and val.separator == " "
        then
            items = val.items
        else
            items = { val }
        end

        for _, item in ipairs(items) do
            local kw = type(item) == "table" and (item.value or "") or ""
            kw = kw:lower()
            if
                kw == "row"
                or kw == "column"
                or kw == "row-reverse"
                or kw == "column-reverse"
            then
                style.flexDirection = kw
            elseif kw == "wrap" or kw == "nowrap" or kw == "wrap-reverse" then
                style.flexWrap = kw
            end
        end
        return true

    elseif prop == "background" then
        local items
        if
            type(val) == "table"
            and val.type == "list"
            and val.separator == " "
        then
            items = val.items
        else
            items = { val }
        end

        for _, item in ipairs(items) do
            if
                item.type == "color"
                or (
                    item.type == "keyword"
                    and NAMED_COLORS[(item.value or ""):lower()]
                )
            then
                style.backgroundColor = resolveColor(item, cp, pfs, rfs, vw, vh)
            elseif item.type == "url" then
                style.backgroundImage = "url(" .. (item.value or "") .. ")"
            elseif
                item.type == "function" and (item.name or ""):find("gradient")
            then
                style.backgroundImage = item.name -- signal gradient to renderer
            end
        end
        return true

    elseif prop == "font" then
        local items
        if
            type(val) == "table"
            and val.type == "list"
            and val.separator == " "
        then
            items = val.items
        else
            items = { val }
        end

        for _, item in ipairs(items) do
            if
                item.type == "dimension"
                or (item.type == "number" and item.value and item.value > 4)
            then
                style.fontSize = len(item) or style.fontSize
            elseif item.type == "string" then
                style.fontFamily = item.value
            elseif item.type == "keyword" then
                local kw = (item.value or ""):lower()
                if kw == "bold" then
                    style.fontWeight = "bold"
                elseif kw == "italic" then
                    style.fontStyle = "italic"
                elseif kw == "small-caps" then
                    style.fontVariant = "small-caps"
                elseif
                    kw == "monospace"
                    or kw == "serif"
                    or kw == "sans-serif"
                    or kw == "cursive"
                    or kw == "fantasy"
                then
                    style.fontFamily = kw
                end
            end
        end
        return true

    elseif prop == "transition" then
        local items
        if
            type(val) == "table"
            and val.type == "list"
            and val.separator == " "
        then
            items = val.items
        else
            items = { val }
        end

        for _, item in ipairs(items) do
            if item.type == "dimension" or item.type == "number" then
                local t = resolveTime(item)
                if not style.transitionDuration then
                    style.transitionDuration = t
                else
                    style.transitionDelay = t
                end
            elseif item.type == "keyword" then
                local kw = (item.value or ""):lower()
                if EASING_MAP[kw] then
                    style.transitionTimingFunction = kw
                elseif kw ~= "none" then
                    style.transitionProperty = kw
                end
            end
        end
        return true

    elseif prop == "animation" then
        local items
        if
            type(val) == "table"
            and val.type == "list"
            and val.separator == " "
        then
            items = val.items
        else
            items = { val }
        end

        for _, item in ipairs(items) do
            if item.type == "dimension" or item.type == "number" then
                local t = resolveTime(item)
                if not style.animationDuration then
                    style.animationDuration = t
                else
                    style.animationDelay = t
                end
            elseif item.type == "keyword" then
                local kw = (item.value or ""):lower()
                if EASING_MAP[kw] then
                    style.animationTimingFunction = kw
                elseif kw == "infinite" then
                    style.animationIterationCount = "infinite"
                elseif kw == "running" or kw == "paused" then
                    style.animationPlayState = kw
                elseif
                    kw == "normal"
                    or kw == "reverse"
                    or kw == "alternate"
                    or kw == "alternate-reverse"
                then
                    style.animationDirection = kw
                elseif
                    kw == "none"
                    or kw == "forwards"
                    or kw == "backwards"
                    or kw == "both"
                then
                    style.animationFillMode = kw
                else
                    style.animationName = kw -- assume it's the name
                end
            end
        end
        return true

    elseif prop == "grid-template" then
        style.gridTemplateRows = "auto"
        style.gridTemplateColumns = "auto"
        return true

    elseif prop == "gap" then
        local items
        if
            type(val) == "table"
            and val.type == "list"
            and val.separator == " "
        then
            items = val.items
        else
            items = { val }
        end

        local rg = len(items[1]) or 0
        local cg = len(items[2] or items[1]) or 0

        style.rowGap = rg
        style.columnGap = cg
        style.gap = rg
        return true

    elseif prop == "overflow" then
        local kw = type(val) == "table" and (val.value or "")
            or tostring(val or "")
        kw = kw:lower()
        style.overflowX = kw
        style.overflowY = kw
        return true

    elseif prop == "outline" then
        local items
        if
            type(val) == "table"
            and val.type == "list"
            and val.separator == " "
        then
            items = val.items
        else
            items = { val }
        end

        for _, item in ipairs(items) do
            if item.type == "dimension" or item.type == "number" then
                style.outlineWidth = len(item) or 0
            elseif
                item.type == "color"
                or (
                    item.type == "keyword"
                    and NAMED_COLORS[(item.value or ""):lower()]
                )
            then
                style.outlineColor = resolveColor(item, cp, pfs, rfs, vw, vh)
                    or style.outlineColor
            elseif item.type == "keyword" then
                local kw = (item.value or ""):lower()
                if
                    kw == "none"
                    or kw == "solid"
                    or kw == "dashed"
                    or kw == "dotted"
                then
                    style.outlineStyle = kw
                end
            end
        end
        return true

    elseif prop == "text-decoration" then
        local items
        if
            type(val) == "table"
            and val.type == "list"
            and val.separator == " "
        then
            items = val.items
        else
            items = { val }
        end

        for _, item in ipairs(items) do
            if item.type == "keyword" then
                local kw = (item.value or ""):lower()
                if
                    kw == "none"
                    or kw == "underline"
                    or kw == "overline"
                    or kw == "line-through"
                then
                    style.textDecoration = kw
                end
            end
        end
        return true
    end

    return false
end

local COLOR_PROPS = {
    color = true,
    ["background-color"] = true,
    ["border-color"] = true,
    ["border-top-color"] = true,
    ["border-right-color"] = true,
    ["border-bottom-color"] = true,
    ["border-left-color"] = true,
    ["outline-color"] = true,
    ["text-decoration-color"] = true,
    ["caret-color"] = true,
    ["accent-color"] = true,
    ["column-rule-color"] = true,
}

local LENGTH_PROPS = {
    width = true,
    height = true,
    ["min-width"] = true,
    ["min-height"] = true,
    ["max-width"] = true,
    ["max-height"] = true,
    ["margin-top"] = true,
    ["margin-right"] = true,
    ["margin-bottom"] = true,
    ["margin-left"] = true,
    ["padding-top"] = true,
    ["padding-right"] = true,
    ["padding-bottom"] = true,
    ["padding-left"] = true,
    ["border-top-width"] = true,
    ["border-right-width"] = true,
    ["border-bottom-width"] = true,
    ["border-left-width"] = true,
    ["border-top-left-radius"] = true,
    ["border-top-right-radius"] = true,
    ["border-bottom-left-radius"] = true,
    ["border-bottom-right-radius"] = true,
    ["border-spacing"] = true,
    ["outline-width"] = true,
    top = true,
    right = true,
    bottom = true,
    left = true,
    ["font-size"] = true,
    ["letter-spacing"] = true,
    ["word-spacing"] = true,
    ["text-indent"] = true,
    ["column-width"] = true,
    ["column-gap"] = true,
    ["row-gap"] = true,
    ["gap"] = true,
    ["line-height"] = true,
    ["flex-basis"] = true,
}

local TIME_PROPS = {
    ["animation-duration"] = true,
    ["animation-delay"] = true,
    ["transition-duration"] = true,
    ["transition-delay"] = true,
}

local NUMBER_PROPS = {
    opacity = true,
    ["flex-grow"] = true,
    ["flex-shrink"] = true,
    order = true,
    ["z-index"] = true,
    orphans = true,
    widows = true,
    ["column-count"] = true,
    ["animation-iteration-count"] = true,
    ["font-weight"] = true,
}

local function applyDeclaration(style, prop, val, pfs, rfs, vw, vh, cp)
    if applyShorthandToStyle(style, prop, val, pfs, rfs, vw, vh, cp) then
        return
    end

    local camel = cssToCamel(prop)

    if type(val) == "table" and val.type == "keyword" then
        local kw = (val.value or ""):lower()
        if kw == "inherit" or kw == "initial" or kw == "unset" then
            return
        end
    end

    if COLOR_PROPS[prop] then
        local c = resolveColor(val, cp, pfs, rfs, vw, vh)
        style[camel] = c -- nil = transparent, intentional

        if prop == "background-color" then
            local alpha = 1
            if
                type(val) == "table"
                and val.type == "color"
                and val.arguments
            then
                local fnName = (val.name or ""):lower()
                local a = val.arguments.a
                if
                    (fnName == "rgba" or fnName == "hsla" or fnName == "hwba")
                    and a
                then
                    if type(a) == "table" then
                        if a.type == "number" then
                            alpha = math.max(0, math.min(1, a.value or 1))
                        elseif a.type == "percentage" then
                            alpha = math.max(0, math.min(1, (a.value or 100) / 100))
                        end
                    elseif type(a) == "number" then
                        alpha = math.max(0, math.min(1, a))
                    end
                end

                local slashAlpha = val.arguments.alpha
                if slashAlpha then
                    if type(slashAlpha) == "table" then
                        if slashAlpha.type == "percentage" then
                            alpha = (slashAlpha.value or 100) / 100
                        elseif slashAlpha.type == "number" then
                            alpha = slashAlpha.value or 1
                        end
                    elseif type(slashAlpha) == "number" then
                        alpha = slashAlpha
                    end
                end

                alpha = math.max(0, math.min(1, alpha))
            end

            style.backgroundColorOpacity = alpha
        end

        return
    end

    if LENGTH_PROPS[prop] then
        local v = resolveLength(val, pfs, rfs, vw, vh, nil, cp)
        if v ~= nil then
            style[camel] = v
        end
        return
    end

    if TIME_PROPS[prop] then
        if type(val) == "table" and val.type == "list" then
            local times = {}
            for _, item in ipairs(val.items or {}) do
                times[#times + 1] = resolveTime(item)
            end
            style[camel] = #times == 1 and times[1] or times
        else
            style[camel] = resolveTime(val)
        end
        return
    end

    if NUMBER_PROPS[prop] then
        if type(val) == "table" then
            if val.type == "number" or val.type == "dimension" then
                style[camel] = val.value
            elseif val.type == "keyword" then
                if prop == "font-weight" then
                    local kw = (val.value or ""):lower()
                    local FW = {
                        thin = 100,
                        extralight = 200,
                        light = 300,
                        normal = 400,
                        medium = 500,
                        semibold = 600,
                        bold = 700,
                        extrabold = 800,
                        black = 900,
                    }
                    style[camel] = FW[kw] and tostring(FW[kw]) or kw
                elseif prop == "animation-iteration-count" then
                    local kw = (val.value or ""):lower()
                    style[camel] = kw == "infinite" and "infinite"
                        or (tonumber(kw) or 1)
                else
                    style[camel] = tonumber(val.value) or val.value
                end
            end
        elseif type(val) == "number" then
            style[camel] = val
        end
        return
    end

    if type(val) == "table" then
        if val.type == "keyword" then
            style[camel] = (val.value or ""):lower()
        elseif val.type == "string" or val.type == "number" then
            style[camel] = val.value
        elseif val.type == "dimension" then
            style[camel] = resolveLength(val, pfs, rfs, vw, vh, nil, cp)
                or val.value
        elseif val.type == "percentage" then
            style[camel] = resolveLength(val, pfs, rfs, vw, vh, nil, cp)
                or (tostring(val.value) .. "%")
        elseif val.type == "color" then
            style[camel] = resolveColor(val, cp, pfs, rfs, vw, vh)
        elseif val.type == "url" then
            style[camel] = "url(" .. (val.value or "") .. ")"
        elseif val.type == "function" then
            style[camel] = val.name
        elseif val.type == "list" then
            if val.items and #val.items > 0 then
                applyDeclaration(
                    style,
                    prop,
                    val.items[1],
                    pfs,
                    rfs,
                    vw,
                    vh,
                    cp
                )
            end
        elseif val.type == "calc" then
            local v = resolveLength(val, pfs, rfs, vw, vh, nil, cp)
            if v then
                style[camel] = v
            end
        elseif val.type == "var" then
            if cp and val.arguments then
                local varName = val.arguments.varName
                local resolved = varName and cp[varName]
                if resolved then
                    applyDeclaration(
                        style,
                        prop,
                        resolved,
                        pfs,
                        rfs,
                        vw,
                        vh,
                        cp
                    )
                    return
                end

                if val.arguments.fallback then
                    applyDeclaration(
                        style,
                        prop,
                        val.arguments.fallback,
                        pfs,
                        rfs,
                        vw,
                        vh,
                        cp
                    )
                end
            end
        end
    elseif type(val) == "string" then
        if val:lower() ~= "inherit" and val:lower() ~= "initial" then
            style[camel] = val
        end
    elseif type(val) == "number" then
        style[camel] = val
    end
end

local function applyPresentationalAttributes(style, element)
    if not element.getAttribute then
        return
    end

    local function attr(n)
        return element:getAttribute(n)
    end

    local bg = attr("bgcolor")
    if bg then
        style.backgroundColor = resolveColor(bg)
    end

    local fgColor = attr("color")
    if fgColor then
        style.color = resolveColor(fgColor) or style.color
    end

    local align = attr("align")
    if align then
        style.textAlign = align:lower()
    end

    local valign = attr("valign")
    if valign then
        style.verticalAlign = valign:lower()
    end

    local w = attr("width")
    if w then
        local n = tonumber(w)
        if n then
            style.width = n
        end
    end

    local h = attr("height")
    if h then
        local n = tonumber(h)
        if n then
            style.height = n
        end
    end

    local border = attr("border")
    if border then
        local n = tonumber(border) or 0
        style.borderTopWidth = n
        style.borderRightWidth = n
        style.borderBottomWidth = n
        style.borderLeftWidth = n
    end

    local cellpadding = attr("cellpadding")
    if cellpadding then
        local n = tonumber(cellpadding) or 0
        style.paddingTop = n
        style.paddingRight = n
        style.paddingBottom = n
        style.paddingLeft = n
    end

    local sz = attr("size") -- font/input size
    if sz and element.tagName == "font" then
        local n = tonumber(sz)
        if n then
            local HTML_FONT_SIZES = { 10, 13, 16, 18, 24, 32, 48 }
            style.fontSize = HTML_FONT_SIZES[math.clamp(n, 1, 7)]
        end
    end

    local face = attr("face")
    if face then
        style.fontFamily = face
    end
end

local function buildComputedStyle(
    element,
    cssom,
    parentStyle,
    keyframesMap,
    CSSParser,
    ctx
)
    local tagName = element.tagName
    local pfs = parentStyle and parentStyle.fontSize or 16
    local rfs = ctx.rootFontSize or 16
    local vw = ctx.viewportW or 800
    local vh = ctx.viewportH or 600

    local style = {}

    if parentStyle then
        for k in pairs(INHERITED_CAMEL) do
            if parentStyle[k] ~= nil then
                style[k] = parentStyle[k]
            end
        end

        if style.color == nil and parentStyle.color then
            style.color = parentStyle.color
        end
    end

    for k, v in pairs(INITIAL) do
        if style[k] == nil then
            style[k] = v
        end
    end

    if tagName and UA_STYLES[tagName] then
        for k, v in pairs(UA_STYLES[tagName]) do
            if k == "fontSize" and type(v) == "number" and v < 5 then
                style[k] = pfs * v
            else
                style[k] = v
            end
        end
    end

    if tagName == "body" then
        if ctx.dOS then
            local d = ctx.dOS
            if style.color == Color3.new(0, 0, 0) then
                style.color = (d.THEME and d.THEME.TEXT_DARK) or style.color
            end
            if d.os_settings and d.os_settings.global_font_size then
                style.fontSize = d.os_settings.global_font_size
            end
        end
    end

    local matchedRules = {}
    if cssom then
        local ok, r = pcall(function()
            return CSSParser.collectMatchingRules(
                cssom,
                element,
                ctx.viewport
            )
        end)

        if ok then
            matchedRules = r
        else
            print(
                "[StyleResolver] collectMatchingRules ERROR on <"
                    .. tostring(tagName)
                    .. ">:",
                tostring(r)
            )
        end
    end

    if
        tagName
        and tagName ~= "head"
        and tagName ~= "meta"
        and tagName ~= "link"
        and tagName ~= "script"
        and tagName ~= "style"
    then
        if #matchedRules > 0 then
            print(
                "[StyleResolver] <"
                    .. tagName
                    .. "> matched "
                    .. #matchedRules
                    .. " CSS rule(s)"
            )
        end
    end

    if #matchedRules > 0 then
        local ok2 = pcall(function()
            CSSParser.sortRulesBySpecificity(matchedRules)
        end)

        if not ok2 then
            table.sort(
                matchedRules,
                function(a, b)
                    return a.sourceIndex < b.sourceIndex
                end
            )
        end
    end

    local normalDecls = {}
    local importantDecls = {}

    for _, entry in ipairs(matchedRules) do
        local rule = entry.rule
        for _, decl in ipairs(rule.declarations or {}) do
            if decl.important then
                importantDecls[#importantDecls + 1] = decl
            else
                normalDecls[#normalDecls + 1] = decl
            end
        end
    end

    local allDecls = {}
    for _, d in ipairs(normalDecls) do
        allDecls[#allDecls + 1] = d
    end
    for _, d in ipairs(importantDecls) do
        allDecls[#allDecls + 1] = d
    end

    local customProps = collectCustomProperties(allDecls, ctx.parentCustomProps)
    ctx.parentCustomProps = customProps -- pass to children

    for _, decl in ipairs(normalDecls) do
        local prop = decl.property
        if prop then
            local val = decl.value

            if type(val) == "table" and val.type == "keyword" then
                local kw = (val.value or ""):lower()
                if kw == "inherit" then
                    local camel = cssToCamel(prop)
                    style[camel] = parentStyle and parentStyle[camel]
                        or INITIAL[camel]
                elseif kw == "initial" then
                    local camel = cssToCamel(prop)
                    style[camel] = INITIAL[camel]
                elseif kw == "unset" then
                    local camel = cssToCamel(prop)
                    if INHERITED_PROPS[prop] then
                        style[camel] = parentStyle and parentStyle[camel]
                            or INITIAL[camel]
                    else
                        style[camel] = INITIAL[camel]
                    end
                elseif kw == "revert" then
                    local camel = cssToCamel(prop)
                    style[camel] = (
                        tagName
                        and UA_STYLES[tagName]
                        and UA_STYLES[tagName][camel]
                    )
                        or (parentStyle and INHERITED_PROPS[prop] and parentStyle[camel])
                        or INITIAL[camel]
                else
                    applyDeclaration(
                        style,
                        prop,
                        val,
                        pfs,
                        rfs,
                        vw,
                        vh,
                        customProps
                    )
                end
            else
                applyDeclaration(
                    style,
                    prop,
                    val,
                    pfs,
                    rfs,
                    vw,
                    vh,
                    customProps
                )
            end
        end
    end

    applyPresentationalAttributes(style, element)

    local inlineStr = element.getAttribute and element:getAttribute("style")
    if inlineStr and inlineStr ~= "" then
        local inlineDecls =
            parseInlineStyleAttribute(inlineStr, ctx.CSSLexer, ctx.CSSParser)

        for _, decl in ipairs(inlineDecls) do
            if decl.property and not decl.important then
                applyDeclaration(
                    style,
                    decl.property,
                    decl.value,
                    style.fontSize or pfs,
                    rfs,
                    vw,
                    vh,
                    customProps
                )
            end
        end

        for _, decl in ipairs(inlineDecls) do
            if decl.property and decl.important then
                applyDeclaration(
                    style,
                    decl.property,
                    decl.value,
                    style.fontSize or pfs,
                    rfs,
                    vw,
                    vh,
                    customProps
                )
            end
        end
    end

    for _, decl in ipairs(importantDecls) do
        local prop = decl.property
        if prop then
            applyDeclaration(
                style,
                prop,
                decl.value,
                style.fontSize or pfs,
                rfs,
                vw,
                vh,
                customProps
            )
        end
    end

    if type(style.fontSize) == "string" then
        local kw = style.fontSize:lower()
        local SIZE_KEYWORDS = {
            ["xx-small"] = 9,
            ["x-small"] = 11,
            small = 13,
            medium = 16,
            large = 18,
            ["x-large"] = 24,
            ["xx-large"] = 32,
            ["xxx-large"] = 48,
            smaller = 0.83,
            larger = 1.2,
        }

        if SIZE_KEYWORDS[kw] then
            local v = SIZE_KEYWORDS[kw]
            style.fontSize = v < 5 and pfs * v or v
        else
            style.fontSize = pfs
        end
    end

    if type(style.fontWeight) == "number" then
        if style.fontWeight >= 700 then
            style.fontWeight = "bold"
        else
            style.fontWeight = "normal"
        end
    end

    if style.borderColor then
        local bc = style.borderColor
        if not style.borderTopColor then
            style.borderTopColor = bc
        end
        if not style.borderRightColor then
            style.borderRightColor = bc
        end
        if not style.borderBottomColor then
            style.borderBottomColor = bc
        end
        if not style.borderLeftColor then
            style.borderLeftColor = bc
        end
        style.borderColor = nil
    end

    if style.borderWidth and type(style.borderWidth) == "number" then
        local bw = style.borderWidth
        if not style.borderTopWidth then
            style.borderTopWidth = bw
        end
        if not style.borderRightWidth then
            style.borderRightWidth = bw
        end
        if not style.borderBottomWidth then
            style.borderBottomWidth = bw
        end
        if not style.borderLeftWidth then
            style.borderLeftWidth = bw
        end
        style.borderWidth = bw -- keep for renderer compat
    end

    if style.borderRadius and type(style.borderRadius) == "number" then
        local br = style.borderRadius
        if not style.borderTopLeftRadius then
            style.borderTopLeftRadius = br
        end
        if not style.borderTopRightRadius then
            style.borderTopRightRadius = br
        end
        if not style.borderBottomRightRadius then
            style.borderBottomRightRadius = br
        end
        if not style.borderBottomLeftRadius then
            style.borderBottomLeftRadius = br
        end
    end

    if style.padding and type(style.padding) == "number" then
        local p = style.padding
        if not style.paddingTop then
            style.paddingTop = p
        end
        if not style.paddingRight then
            style.paddingRight = p
        end
        if not style.paddingBottom then
            style.paddingBottom = p
        end
        if not style.paddingLeft then
            style.paddingLeft = p
        end
        style.padding = p -- keep for renderer compat
    end

    if style.margin and type(style.margin) == "number" then
        local m = style.margin
        if not style.marginTop then
            style.marginTop = m
        end
        if not style.marginRight then
            style.marginRight = m
        end
        if not style.marginBottom then
            style.marginBottom = m
        end
        if not style.marginLeft then
            style.marginLeft = m
        end
    end

    if type(style.opacity) == "string" then
        style.opacity = tonumber(style.opacity) or 1
    end
    style.opacity = math.clamp(style.opacity or 1, 0, 1)

    if style.lineHeight == "normal" then
        style.lineHeight = 1.4
    end
    if type(style.lineHeight) == "number" and style.lineHeight < 5 then
        style.lineHeight = style.lineHeight * (style.fontSize or 16)
    end

    local animations = buildAnimationDescriptors(style, keyframesMap)
    if animations then
        style._animations = animations
    end

    local transitions = buildTransitionDescriptors(style)
    if transitions then
        style._transitions = transitions
    end

    return style
end

local function resolveNodeRecursive(
    node,
    cssom,
    parentStyle,
    keyframesMap,
    ctx,
    depth
)
    depth = depth or 0
    if not node then
        return
    end

    local nodeType = node.nodeType

    if nodeType == "element" then
        local computedStyle = buildComputedStyle(
            node,
            cssom,
            parentStyle,
            keyframesMap,
            ctx.CSSParser,
            ctx
        )
        node.computedStyle = computedStyle

        local child = node.firstChild
        while child do
            resolveNodeRecursive(
                child,
                cssom,
                computedStyle,
                keyframesMap,
                ctx,
                depth + 1
            )
            child = child.nextSibling
        end

    elseif nodeType == "document" or nodeType == nil then
        local rootStyle = {
            fontSize = (
                ctx.dOS
                and ctx.dOS.os_settings
                and ctx.dOS.os_settings.global_font_size
            ) or 16,
            fontFamily = "sans-serif",
            fontWeight = "normal",
            fontStyle = "normal",
            color = (ctx.dOS and ctx.dOS.THEME and ctx.dOS.THEME.TEXT_DARK)
                or Color3.new(0, 0, 0),
            textAlign = "left",
            display = "block",
        }
        node.computedStyle = rootStyle

        local child = node.firstChild
        local childCount = 0
        while child do
            resolveNodeRecursive(
                child,
                cssom,
                rootStyle,
                keyframesMap,
                ctx,
                depth + 1
            )
            child = child.nextSibling
            childCount = childCount + 1
        end

        if childCount == 0 then
            if node.head then
                resolveNodeRecursive(
                    node.head,
                    cssom,
                    rootStyle,
                    keyframesMap,
                    ctx,
                    depth + 1
                )
            end
            if node.body then
                resolveNodeRecursive(
                    node.body,
                    cssom,
                    rootStyle,
                    keyframesMap,
                    ctx,
                    depth + 1
                )
            end
            if
                node.documentElement
                and node.documentElement ~= node.head
                and node.documentElement ~= node.body
            then
                resolveNodeRecursive(
                    node.documentElement,
                    cssom,
                    rootStyle,
                    keyframesMap,
                    ctx,
                    depth + 1
                )
            end
        end
    else
        if parentStyle then
            node.computedStyle = parentStyle
        end
    end

    if depth % 30 == 0 and task and task.wait then
        task.wait()
    end
end

function StyleResolver.resolveTree(
    document,
    cssom,
    CSSLexer,
    CSSParser,
    options
)
    options = options or {}

    print("[StyleResolver] resolveTree() called")
    print("[StyleResolver]   document type   =", type(document))
    print(
        "[StyleResolver]   document.nodeType =",
        tostring(document and document.nodeType)
    )
    print("[StyleResolver]   cssom            =", tostring(cssom))

    if cssom then
        print(
            "[StyleResolver]   cssom.rules count =",
            tostring(cssom.rules and #cssom.rules or 0)
        )
    end

    print("[StyleResolver]   CSSLexer  =", tostring(CSSLexer))
    print("[StyleResolver]   CSSParser =", tostring(CSSParser))

    if CSSParser then
        print(
            "[StyleResolver]   CSSParser.collectMatchingRules =",
            tostring(CSSParser.collectMatchingRules)
        )
        print(
            "[StyleResolver]   CSSParser.sortRulesBySpecificity =",
            tostring(CSSParser.sortRulesBySpecificity)
        )
    end

    local ctx = {
        CSSLexer = CSSLexer,
        CSSParser = CSSParser,
        dOS = options.dOS,
        viewport = options.viewport
            or { width = 800, height = 600, type = "screen" },
        viewportW = (options.viewport and options.viewport.width) or 800,
        viewportH = (options.viewport and options.viewport.height) or 600,
        rootFontSize = options.rootFontSize
            or (options.dOS and options.dOS.os_settings and options.dOS.os_settings.global_font_size)
            or 16,
        parentCustomProps = {},
    }

    local keyframesMap = cssom and extractKeyframes(cssom) or {}
    print("[StyleResolver] @keyframes found:", #(function()
        local t = {}
        for k in pairs(keyframesMap) do
            t[#t + 1] = k
        end
        return t
    end)())

    resolveNodeRecursive(document, cssom, nil, keyframesMap, ctx, 0)

    local function countResolved(node, n)
        n = n or 0
        if not node then
            return n
        end
        if node.computedStyle then
            n = n + 1
        end

        local c = node.firstChild
        while c do
            n = countResolved(c, n)
            c = c.nextSibling
        end

        if not node.firstChild then
            if node.head then
                n = countResolved(node.head, n)
            end
            if node.body then
                n = countResolved(node.body, n)
            end
        end

        return n
    end

    print(
        "[StyleResolver] resolveTree() done. Nodes with computedStyle:",
        countResolved(document)
    )

    return keyframesMap
end

local CSS_TO_ROBLOX_PROP = {
    opacity = {
        "BackgroundTransparency",
        function(v)
            return 1 - (tonumber(v) or 1)
        end,
    },
    backgroundColor = { "BackgroundColor3", function(v) return v end },
    color = { "TextColor3", function(v) return v end },
    fontSize = { "TextSize", function(v) return tonumber(v) or 14 end },
    width = { "_Width", function(v) return tonumber(v) end },
    height = { "_Height", function(v) return tonumber(v) end },
}

local function resolveKeyframeProperty(cssProp, val, nodeStyle)
    local info = CSS_TO_ROBLOX_PROP[cssProp]
    if not info then
        return nil
    end

    local robloxProp, converter = info[1], info[2]
    local rawValue = type(val) == "table" and val
        or { type = "keyword", value = tostring(val) }
    local resolved

    if cssProp == "opacity" then
        if type(val) == "table" then
            resolved = val.value
        else
            resolved = tonumber(val)
        end
    elseif cssProp:find("color") or cssProp:find("Color") then
        resolved = resolveColor(rawValue)
    else
        resolved = resolveLength(
            rawValue,
            nodeStyle and nodeStyle.fontSize or 16,
            16,
            800,
            600
        )
    end

    if resolved == nil then
        return nil
    end

    return { property = robloxProp, value = converter(resolved) }
end

function StyleResolver.applyAnimations(instance, node, dOS)
    if not node or not node.computedStyle then
        return
    end

    local animations = node.computedStyle._animations
    if not animations or not dOS then
        return
    end

    local Tween = dOS.Tween
    local TweenInfo = dOS.TweenInfo
    if not Tween or not TweenInfo then
        return
    end

    for _, anim in ipairs(animations) do
        if anim.playState == "paused" then
            continue
        end

        local kfs = anim.keyframes
        if not kfs or #kfs == 0 then
            continue
        end

        table.sort(kfs, function(a, b)
            local pa = tonumber(a.selector)
                or (a.selector == "from" and 0)
                or (a.selector == "to" and 100)
                or 0
            local pb = tonumber(b.selector)
                or (b.selector == "from" and 0)
                or (b.selector == "to" and 100)
                or 0
            return pa < pb
        end)

        local nodeStyle = node.computedStyle
        local totalDuration = anim.duration or 0
        if totalDuration <= 0 then
            continue
        end

        local _, toFrame = kfs[1], kfs[#kfs]

        local targetProps = {}
        local hasProps = false

        for _, decl in ipairs(toFrame.declarations or {}) do
            local prop = decl.property
            if prop and not prop:match("^%-%-") then
                local info = CSS_TO_ROBLOX_PROP[prop]
                if info then
                    local resolved =
                        resolveKeyframeProperty(prop, decl.value, nodeStyle)
                    if
                        resolved
                        and resolved.property ~= "_Width"
                        and resolved.property ~= "_Height"
                    then
                        targetProps[resolved.property] = resolved.value
                        hasProps = true
                    end
                end
            end
        end

        if not hasProps then
            continue
        end

        local repeatCount = anim.iterationCount
        if repeatCount == "infinite" then
            repeatCount = true
        end

        local reverses = anim.direction == "alternate"
            or anim.direction == "alternate-reverse"

        local tInfo = TweenInfo.new(
            totalDuration,
            anim.easingStyle or Enum.EasingStyle.Quad,
            anim.easingDirection or Enum.EasingDirection.Out,
            anim.delay or 0,
            reverses,
            repeatCount or 1
        )

        local filteredProps = {}
        local ok, _ = pcall(function()
            for prop, value in pairs(targetProps) do
                local cur = (instance :: any)[prop]
                if cur ~= nil and typeof(cur) == typeof(value) then
                    filteredProps[prop] = value
                end
            end
        end)

        if not ok or next(filteredProps) == nil then
            continue
        end

        local tween = Tween.new(instance, filteredProps, tInfo)
        tween:Play()
    end
end

function StyleResolver.applyTransitions(instance, fromStyle, toStyle, dOS)
    if not toStyle or not toStyle._transitions then
        return {}
    end

    local trans = toStyle._transitions
    if not dOS then
        return {}
    end

    local Tween = dOS.Tween
    local TweenInfo = dOS.TweenInfo
    if not Tween or not TweenInfo then
        return {}
    end

    local tweens = {}
    local ROBLOX_PROPS = {
        backgroundColor = "BackgroundColor3",
        color = "TextColor3",
        opacity = "BackgroundTransparency",
        fontSize = "TextSize",
    }

    local targetProps = {}
    local properties = trans.properties or {}
    local checkAll = properties[1] == "all"

    for _, cssProp in
        ipairs(
            checkAll and { "backgroundColor", "color", "opacity", "fontSize" }
                or properties
        )
    do
        local rProp = ROBLOX_PROPS[cssProp]
        if rProp then
            local from = fromStyle and fromStyle[cssProp]
            local to = toStyle[cssProp]

            if from ~= nil and to ~= nil and from ~= to then
                if cssProp == "opacity" then
                    targetProps[rProp] = 1 - (toStyle.opacity or 1)
                else
                    pcall(function()
                        local cur = (instance :: any)[rProp]
                        if cur ~= nil and typeof(cur) == typeof(to) then
                            targetProps[rProp] = to
                        end
                    end)
                end
            end
        end
    end

    if next(targetProps) == nil then
        return {}
    end

    local tInfo = TweenInfo.new(
        trans.duration or 0,
        trans.easingStyle or Enum.EasingStyle.Quad,
        trans.easingDirection or Enum.EasingDirection.Out,
        trans.delay or 0,
        false,
        0
    )

    local tween = Tween.new(instance, targetProps, tInfo)
    tween:Play()
    tweens[#tweens + 1] = tween

    return tweens
end

function StyleResolver.resolveColor(val)
    return resolveColor(val)
end

function StyleResolver.resolveLength(
    val,
    parentFontSize,
    viewportW,
    viewportH
)
    return resolveLength(
        val,
        parentFontSize or 16,
        16,
        viewportW or 800,
        viewportH or 600
    )
end

return StyleResolver

-- EOF