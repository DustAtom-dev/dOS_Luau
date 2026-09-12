--[[
    "HTML Renderer module for dOS"
    
    @module html_renderer
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


local Renderer = {}

local HTML_COLORS = {
    white = Color3.new(1, 1, 1),
    black = Color3.new(0, 0, 0),
    red = Color3.new(1, 0, 0),
    green = Color3.fromRGB(0, 128, 0),
    blue = Color3.new(0, 0, 1),
    yellow = Color3.new(1, 1, 0),
    cyan = Color3.new(0, 1, 1),
    magenta = Color3.new(1, 0, 1),

    gray = Color3.fromRGB(128, 128, 128),
    grey = Color3.fromRGB(128, 128, 128),
    silver = Color3.fromRGB(192, 192, 192),
    maroon = Color3.fromRGB(128, 0, 0),
    olive = Color3.fromRGB(128, 128, 0),
    lime = Color3.fromRGB(0, 255, 0),
    aqua = Color3.fromRGB(0, 255, 255),
    teal = Color3.fromRGB(0, 128, 128),
    navy = Color3.fromRGB(0, 0, 128),
    fuchsia = Color3.fromRGB(255, 0, 255),
    purple = Color3.fromRGB(128, 0, 128),
    orange = Color3.fromRGB(255, 165, 0),
    pink = Color3.fromRGB(255, 192, 203),
    brown = Color3.fromRGB(165, 42, 42),
    gold = Color3.fromRGB(255, 215, 0),
    coral = Color3.fromRGB(255, 127, 80),
    salmon = Color3.fromRGB(250, 128, 114),
    khaki = Color3.fromRGB(240, 230, 140),
    violet = Color3.fromRGB(238, 130, 238),
    indigo = Color3.fromRGB(75, 0, 130),
    crimson = Color3.fromRGB(220, 20, 60),

    lightgray = Color3.fromRGB(211, 211, 211),
    lightgrey = Color3.fromRGB(211, 211, 211),
    darkgray = Color3.fromRGB(169, 169, 169),
    darkgrey = Color3.fromRGB(169, 169, 169),
    dimgray = Color3.fromRGB(105, 105, 105),
    dimgrey = Color3.fromRGB(105, 105, 105),
    whitesmoke = Color3.fromRGB(245, 245, 245),
    gainsboro = Color3.fromRGB(220, 220, 220),

    lightblue = Color3.fromRGB(173, 216, 230),
    skyblue = Color3.fromRGB(135, 206, 235),
    deepskyblue = Color3.fromRGB(0, 191, 255),
    dodgerblue = Color3.fromRGB(30, 144, 255),
    cornflowerblue = Color3.fromRGB(100, 149, 237),
    steelblue = Color3.fromRGB(70, 130, 180),
    royalblue = Color3.fromRGB(65, 105, 225),
    darkblue = Color3.fromRGB(0, 0, 139),
    midnightblue = Color3.fromRGB(25, 25, 112),

    lightgreen = Color3.fromRGB(144, 238, 144),
    limegreen = Color3.fromRGB(50, 205, 50),
    forestgreen = Color3.fromRGB(34, 139, 34),
    seagreen = Color3.fromRGB(46, 139, 87),
    darkgreen = Color3.fromRGB(0, 100, 0),

    lightcoral = Color3.fromRGB(240, 128, 128),
    indianred = Color3.fromRGB(205, 92, 92),
    firebrick = Color3.fromRGB(178, 34, 34),
    darkred = Color3.fromRGB(139, 0, 0),
    tomato = Color3.fromRGB(255, 99, 71),
    orangered = Color3.fromRGB(255, 69, 0),

    transparent = nil,
}

local BLOCK_ELEMENTS = {
    address = true,
    article = true,
    aside = true,
    blockquote = true,
    center = true,
    dd = true,
    details = true,
    dialog = true,
    dir = true,
    div = true,
    dl = true,
    dt = true,
    fieldset = true,
    figcaption = true,
    figure = true,
    footer = true,
    form = true,
    h1 = true,
    h2 = true,
    h3 = true,
    h4 = true,
    h5 = true,
    h6 = true,
    header = true,
    hgroup = true,
    hr = true,
    li = true,
    main = true,
    menu = true,
    nav = true,
    noscript = true,
    ol = true,
    p = true,
    pre = true,
    section = true,
    search = true,
    table = true,
    tbody = true,
    td = true,
    tfoot = true,
    th = true,
    thead = true,
    tr = true,
    ul = true,
    canvas = true,
    video = true,
    audio = true,
    iframe = true,
}

local INLINE_ELEMENTS = {
    a = true,
    abbr = true,
    acronym = true,
    b = true,
    bdi = true,
    bdo = true,
    big = true,
    br = true,
    cite = true,
    code = true,
    data = true,
    del = true,
    dfn = true,
    em = true,
    i = true,
    ins = true,
    kbd = true,
    mark = true,
    q = true,
    rp = true,
    rt = true,
    ruby = true,
    s = true,
    samp = true,
    small = true,
    span = true,
    strike = true,
    strong = true,
    sub = true,
    sup = true,
    time = true,
    tt = true,
    u = true,
    var = true,
    wbr = true,
}

local PREFORMATTED_ELEMENTS = {
    pre = true,
    code = true,
    textarea = true,
}

local function parseColor(value)
    if not value then return nil end
    if typeof(value) == "Color3" then return value end

    value = tostring(value):gsub("^%s+", ""):gsub("%s+$", ""):lower()

    if value == "transparent" or value == "none" then return nil end
    if HTML_COLORS[value] ~= nil then return HTML_COLORS[value] end

    local hex = value:match("^#([%da-f]+)$")
    if hex then
        if #hex == 3 then
            hex = `{hex:sub(1, 1):rep(2)}{hex:sub(2, 2):rep(2)}{hex:sub(3, 3):rep(2)}`
        end
        if #hex == 6 then
            return Color3.fromRGB(
                tonumber(hex:sub(1, 2), 16) or 0,
                tonumber(hex:sub(3, 4), 16) or 0,
                tonumber(hex:sub(5, 6), 16) or 0
            )
        end
    end

    local r, g, b = value:match("rgba?%s*%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
    if r then return Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b)) end

    return nil
end

local _StyleResolver = nil

local function createContext(dOS, options)
    options = options or {}

    return {
        dOS = dOS,
        options = options,
        onNavigate = options.onNavigate or function(url) print("Navigate:", url) end,
        onFormSubmit = options.onFormSubmit or function(_, data) print("Submit:", data) end,
        onImageClick = options.onImageClick,
        forms = {},
        currentFormId = nil,
        listStack = {},
        orderCounter = 0,
        formCounter = 0,
        computedStyle = {},
        parentWidth = 800,
        parentHeight = 600,
        preserveWhitespace = false,
        pendingBottomMargin = 0,
    }
end

local function shallowCopyContext(ctx)
    return table.clone(ctx)
end

local function getNextOrder(context)
    context.orderCounter += 1
    return context.orderCounter
end

local function num(v, default)
    default = default or 0
    if type(v) == "number" then
        if v ~= v then return default end -- NaN guard
        return v
    end

    if type(v) == "string" then
        local n = tonumber(v)
        if n then return n end

        n = tonumber(v:match("^%-?%d*%.?%d+"))
        if n then return n end

        local kw = v:lower()
        if kw == "auto"
            or kw == "none"
            or kw == "normal"
            or kw == "inherit"
            or kw == "initial"
            or kw == "unset"
        then
            return default
        end
    end

    return default
end

local function numOrNil(v)
    if type(v) == "number" then return v end

    if type(v) == "string" then
        local n = tonumber(v)
        if n then return n end

        n = tonumber(v:match("^%-?%d*%.?%d+"))
        if n then return n end

        local kw = v:lower()
        if kw == "auto"
            or kw == "none"
            or kw == "normal"
            or kw == "inherit"
            or kw == "initial"
            or kw == "unset"
        then
            return nil
        end
    end

    return nil
end

local function createSpacer(dOS, parent, height, order)
    return dOS.create_gui_element(dOS, "Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        LayoutOrder = order,
    })
end

local function emitTopMargin(dOS, parent, marginTop, context)
    local pending = context.pendingBottomMargin or 0
    local effective = math.max(marginTop, pending) - pending
    context.pendingBottomMargin = 0

    if effective > 0 then
        createSpacer(dOS, parent, effective, getNextOrder(context))
    end

    return effective
end

local function scheduleBottomMargin(marginBottom, context)
    context.pendingBottomMargin = math.max(context.pendingBottomMargin or 0, marginBottom)
end

local function flushBottomMargin(dOS, parent, context)
    local pending = context.pendingBottomMargin or 0
    if pending > 0 then
        createSpacer(dOS, parent, pending, getNextOrder(context))
        context.pendingBottomMargin = 0
    end
end

local function getFont(dOS, style)
    local isMono = style.fontFamily == "monospace"
        or style.fontFamily == "courier"
        or style.fontFamily == "consolas"
    local isBold = style.fontWeight == "bold"
        or style.fontWeight == "700"
        or style.fontWeight == "800"
        or style.fontWeight == "900"
    local isItalic = style.fontStyle == "italic"

    if isMono then return Enum.Font.Code end
    if isBold then return (dOS.FONT_BOLD or Enum.Font.GothamBold) end
    if isItalic then return (dOS.FONT_REGULAR or Enum.Font.GothamMedium) end
    return (dOS.FONT_REGULAR or Enum.Font.Gotham)
end

local function getTextAlignment(style)
    local a = style.textAlign

    if a == "center" then return Enum.TextXAlignment.Center end
    if a == "right" then return Enum.TextXAlignment.Right end
    return Enum.TextXAlignment.Left
end

local function urlEncode(str)
    if not str then return "" end

    str = str:gsub("\n", "\r\n")
    str = str:gsub(
        "([^%w %-._~])",
        function(c) return string.format("%%%02X", string.byte(c)) end
    )

    return str:gsub(" ", "+")
end

local function stripRichText(text)
    text = text:gsub("<[^>]+>", "")
    text = text:gsub("&amp;", "&")
        :gsub("&lt;", "<")
        :gsub("&gt;", ">")
        :gsub("&quot;", '"')
        :gsub("&apos;", "'")

    return text
end

local function estimateTextHeight(text, fontSize, containerWidth)
    if not text or text == "" then return 0 end

    local plain = stripRichText(text)
    fontSize = num(fontSize, 14)
    containerWidth = math.max(1, num(containerWidth, 800))

    local charsPerLine = math.max(1, math.floor(containerWidth / (fontSize * 0.55)))
    local lines = 0

    for line in (plain .. "\n"):gmatch("([^\n]*)\n") do
        lines = lines + math.max(1, math.ceil(#line / charsPerLine))
    end

    lines = math.max(1, lines)
    return math.ceil(lines * fontSize * 1.35)
end

local RT_ESCAPE = {
    ["&"] = "&amp;",
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ['"'] = "&quot;",
}

local function escapeRichText(s)
    return (s:gsub('[&<>"]', RT_ESCAPE))
end

local function color3ToHex(c)
    return string.format(
        "#%02X%02X%02X",
        math.floor(c.R * 255 + 0.5),
        math.floor(c.G * 255 + 0.5),
        math.floor(c.B * 255 + 0.5)
    )
end

local function buildRichText(node, parentStyle, context)
    if node.nodeType == "text" then
        local text = node.nodeValue or ""
        if not context.preserveWhitespace then text = text:gsub("%s+", " ") end
        return escapeRichText(text)
    end

    if node.nodeType ~= "element" then return "" end

    local tag = node.tagName
    if tag == "br" then return "\n" end
    if tag == "wbr" then return "" end

    local parts = {}
    for _, child in ipairs(node.childNodes or {}) do
        parts[#parts + 1] = buildRichText(child, parentStyle, context)
    end

    local inner = table.concat(parts)
    if inner == "" then return "" end

    local fs = parentStyle.fontSize or 14

    if tag == "b" or tag == "strong" then
        return `<b>{inner}</b>`
    elseif tag == "i"
        or tag == "em"
        or tag == "var"
        or tag == "cite"
        or tag == "dfn"
        or tag == "address"
    then
        return `<i>{inner}</i>`
    elseif tag == "u" or tag == "ins" then
        return `<u>{inner}</u>`
    elseif tag == "s" or tag == "del" or tag == "strike" then
        return `<s>{inner}</s>`
    elseif tag == "small" then
        local sz = math.max(8, math.floor(fs * 0.8))
        return string.format('<font size="%d">%s</font>', sz, inner)
    elseif tag == "big" then
        local sz = math.floor(fs * 1.25)
        return string.format('<font size="%d">%s</font>', sz, inner)
    elseif tag == "sub" or tag == "sup" then
        local sz = math.max(8, math.floor(fs * 0.75))
        return string.format('<font size="%d">%s</font>', sz, inner)
    elseif tag == "code" or tag == "kbd" or tag == "samp" or tag == "tt" then
        return `<font color="#888888">{inner}"</font>"`
    elseif tag == "mark" then
        return `<b>{inner}</b>`
    elseif tag == "q" then
        return `\u{201C}{inner}\u{201D}`
    elseif tag == "abbr" or tag == "acronym" then
        return `<u>{inner}</u>`
    elseif tag == "a" then
        return `<font color="#0066CC"><u>{inner}</u></font>`
    elseif tag == "span"
        or tag == "bdi"
        or tag == "bdo"
        or tag == "time"
        or tag == "data"
        or tag == "ruby"
        or tag == "rp"
        or tag == "rt"
    then
        local result = inner
        local cs = node.computedStyle or parentStyle or {}

        local td = cs.textDecoration
        if td == "line-through" then
            result = `<s>{result}</s>`
        elseif td == "underline" then
            result = `<u>{result}</u>`
        end

        if cs.fontStyle == "italic" then result = `<i>{result}</i>` end

        local fw = cs.fontWeight
        if fw == "bold" or fw == "700" or fw == "800" or fw == "900" then
            result = `<b>{result}</b>`
        end

        local csFs = cs.fontSize
        if csFs and type(csFs) == "number" and math.abs(csFs - fs) > 1 then
            result = string.format(
                '<font size="%d">%s</font>',
                math.max(8, math.floor(csFs)),
                result
            )
        end

        local fgColor = cs.color
        if fgColor and typeof(fgColor) == "Color3" then
            result = string.format(
                '<font color="%s">%s</font>',
                color3ToHex(fgColor),
                result
            )
        end

        local colorAttr = node:getAttribute("color")
        if colorAttr then
            local c = parseColor(colorAttr)
            if c then
                result = string.format(
                    '<font color="%s">%s</font>',
                    color3ToHex(c),
                    result
                )
            end
        end

        return result
    else
        return inner -- unknown inline: just its content
    end
end

local renderNode
local renderChildren

local function renderInlineFlow(element, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle
    local fs = num(style.fontSize, 14)

    local color = style.color
    if typeof(color) ~= "Color3" then color = parseColor(color) end
    color = color or (dOS.THEME and dOS.THEME.TEXT_DARK) or Color3.new(0, 0, 0)

    local totalHeight = 0

    local richParts = {}
    local links = {}

    local function flushSegment()
        local text = table.concat(richParts):gsub("^%s+", ""):gsub("%s+$", "")
        richParts = {}
        local captured = links
        links = {}

        if text == "" then return end

        local h = estimateTextHeight(text, fs, context.parentWidth)

        local segColor = color
        if #captured > 0 then segColor = Color3.fromRGB(0, 102, 204) end

        local props = {
            Parent = parent,
            Text = text,
            RichText = true,
            TextColor3 = segColor,
            TextSize = fs,
            Font = getFont(dOS, style),
            TextXAlignment = getTextAlignment(style),
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            Size = UDim2.new(1, 0, 0, h),
            BackgroundTransparency = 1,
            LayoutOrder = getNextOrder(context),
        }

        if #captured > 0 then
            props.AutoButtonColor = false
            props.OnClick = function()
                if context.onNavigate then
                    context.onNavigate(captured[1].href, captured[1].target)
                end
            end
            dOS.create_gui_element(dOS, "TextButton", props)
        else
            dOS.create_gui_element(dOS, "TextLabel", props)
        end

        totalHeight += h
    end

    local function visit(node)
        if node.nodeType == "text" then
            local text = node.nodeValue or ""
            if not context.preserveWhitespace then
                text = text:gsub("%s+", " ")
            end
            richParts[#richParts + 1] = escapeRichText(text)
        elseif node.nodeType == "element" then
            local tag = node.tagName

            if tag == "br" then
                richParts[#richParts + 1] = "\n"
            elseif tag == "img" or BLOCK_ELEMENTS[tag] then
                flushSegment()
                totalHeight = totalHeight + renderNode(node, parent, context)
            elseif tag == "a" then
                local href = node:getAttribute("href") or "#"
                local target = node:getAttribute("target")
                table.insert(links, { href = href, target = target })
                richParts[#richParts + 1] = buildRichText(node, style, context)
            elseif INLINE_ELEMENTS[tag] then
                richParts[#richParts + 1] = buildRichText(node, style, context)
            else
                flushSegment()
                totalHeight += renderNode(node, parent, context)
            end
        end
    end

    for _, child in ipairs(element.childNodes or {}) do
        visit(child)
    end
    flushSegment() -- flush the final segment

    return totalHeight
end

local function renderPositioned(element, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle

    local containingBlock = context.absoluteParent or parent

    local topV = numOrNil(style.top)
    local leftV = numOrNil(style.left)
    local rightV = numOrNil(style.right)
    local botV = numOrNil(style.bottom)
    local wVal = numOrNil(style.width)
    local hVal = numOrNil(style.height)

    local posX = leftV
        or (
            rightV
                and math.max(
                    0,
                    (context.parentWidth or 800) - (rightV + (wVal or 100))
                )
            or 0
        )
    local posY = topV
        or (
            botV
                and math.max(
                    0,
                    (context.parentHeight or 600) - (botV + (hVal or 50))
                )
            or 0
        )

    local bgColor = style.backgroundColor
    if typeof(bgColor) ~= "Color3" then bgColor = nil end

    local opacity = num(style.opacity, 1)
    local bgAlpha = style.backgroundColorOpacity
    local bgTransp = bgColor and (1 - (bgAlpha ~= nil and bgAlpha or opacity)) or 1
    bgTransp = math.clamp(bgTransp, 0, 1)

    local paddingTop = num(style.paddingTop ~= nil and style.paddingTop or style.padding, 0)
    local paddingBottom = num(style.paddingBottom ~= nil and style.paddingBottom or style.padding, 0)
    local paddingLeft = num(style.paddingLeft ~= nil and style.paddingLeft or style.padding, 0)
    local paddingRight = num(style.paddingRight ~= nil and style.paddingRight or style.padding, 0)

    local borderRadius = num(
        style.borderTopLeftRadius ~= nil and style.borderTopLeftRadius or style.borderRadius,
        0
    )
    local borderW = num(style.borderWidth, 0)
    if borderW == 0 then
        borderW = math.max(
            num(style.borderTopWidth, 0),
            num(style.borderRightWidth, 0),
            num(style.borderBottomWidth, 0),
            num(style.borderLeftWidth, 0)
        )
    end
    local borderColor = style.borderTopColor or style.borderColor

    local zRaw = style.zIndex
    local zIdx = 2
    if type(zRaw) == "number" then
        zIdx = math.clamp(math.floor(zRaw), 1, 10)
    elseif type(zRaw) == "string" then
        zIdx = math.clamp(tonumber(zRaw) or 2, 1, 10)
    end

    local innerW = wVal and (wVal - paddingLeft - paddingRight)
        or math.max(50, (context.parentWidth or 800) - paddingLeft - paddingRight)

    local absFrame = dOS.create_gui_element(dOS, "Frame", {
        Parent = containingBlock,
        Name = (element.tagName or "abs") .. "_abs",
        Size = wVal and UDim2.fromOffset(wVal, hVal or 50)
            or UDim2.fromOffset(innerW + paddingLeft + paddingRight, hVal or 50),
        Position = UDim2.fromOffset(posX, posY),
        BackgroundColor3 = bgColor or Color3.new(1, 1, 1),
        BackgroundTransparency = bgTransp,
        BorderSizePixel = borderW,
        BorderColor3 = (typeof(borderColor) == "Color3" and borderColor) or Color3.fromRGB(200, 200, 200),
        ZIndex = zIdx,
        ClipsDescendants = style.overflow == "hidden" or style.overflowX == "hidden",
    })

    if borderRadius > 0 then
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = absFrame,
            CornerRadius = UDim.new(0, borderRadius),
        })
    end

    local flowFrame = dOS.create_gui_element(dOS, "Frame", {
        Parent = absFrame,
        Name = "_flow",
        Size = UDim2.new(1, -(paddingLeft + paddingRight), 0, 0),
        Position = UDim2.fromOffset(paddingLeft, paddingTop),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    dOS.create_gui_element(dOS, "UIListLayout", {
        Parent = flowFrame,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    })

    local cc = shallowCopyContext(context)
    cc.orderCounter = 0
    cc.parentWidth = innerW
    cc.pendingBottomMargin = 0
    cc.absoluteParent = absFrame

    local contentH = renderInlineFlow(element, flowFrame, cc)
    flushBottomMargin(dOS, flowFrame, cc)

    local totalH = contentH + paddingTop + paddingBottom
    flowFrame.Size = UDim2.new(1, -(paddingLeft + paddingRight), 0, contentH)

    if not hVal then
        absFrame.Size = UDim2.new(absFrame.Size.X.Scale, absFrame.Size.X.Offset, 0, totalH)
    end

    return 0
end

local function renderContainer(element, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle

    local bgColor = style.backgroundColor
    if typeof(bgColor) ~= "Color3" then bgColor = nil end
    local opacity = num(style.opacity, 1)
    local bgAlpha = style.backgroundColorOpacity -- rgba() alpha from StyleResolver
    local bgTransp = bgColor and (1 - (bgAlpha ~= nil and bgAlpha or opacity)) or 1
    bgTransp = math.clamp(bgTransp, 0, 1)

    local paddingTop = num(style.paddingTop ~= nil and style.paddingTop or style.padding, 0)
    local paddingBottom = num(style.paddingBottom ~= nil and style.paddingBottom or style.padding, 0)
    local paddingLeft = num(style.paddingLeft ~= nil and style.paddingLeft or style.padding, 0)
    local paddingRight = num(style.paddingRight ~= nil and style.paddingRight or style.padding, 0)
    local marginTop = num(style.marginTop, 0)
    local marginBottom = num(style.marginBottom, 0)
    local marginLeft = num(style.marginLeft, 0)

    local radTL = num(style.borderTopLeftRadius ~= nil and style.borderTopLeftRadius or style.borderRadius, 0)
    local radTR = num(style.borderTopRightRadius ~= nil and style.borderTopRightRadius or style.borderRadius, 0)
    local radBR = num(style.borderBottomRightRadius ~= nil and style.borderBottomRightRadius or style.borderRadius, 0)
    local radBL = num(style.borderBottomLeftRadius ~= nil and style.borderBottomLeftRadius or style.borderRadius, 0)
    local borderRadius = math.max(radTL, radTR, radBR, radBL)

    local borderW = num(style.borderWidth, 0)
    if borderW == 0 then
        borderW = math.max(
            num(style.borderTopWidth, 0),
            num(style.borderRightWidth, 0),
            num(style.borderBottomWidth, 0),
            num(style.borderLeftWidth, 0)
        )
    end
    local borderColor = style.borderTopColor or style.borderColor

    local cssPosition = style.position
    if cssPosition == "absolute" or cssPosition == "fixed" or cssPosition == "sticky" then
        return renderPositioned(element, parent, context)
    end

    if marginTop > 0 then
        emitTopMargin(dOS, parent, marginTop, context)
    end

    local container = dOS.create_gui_element(dOS, "Frame", {
        Parent = parent,
        Name = element.tagName or "container",
        Size = UDim2.new(1, -marginLeft, 0, 0),
        Position = marginLeft > 0 and UDim2.fromOffset(marginLeft, 0) or UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = bgColor or Color3.new(1, 1, 1),
        BackgroundTransparency = bgTransp,
        BorderSizePixel = borderW,
        BorderColor3 = (typeof(borderColor) == "Color3" and borderColor)
            or (dOS.THEME and dOS.THEME.BORDER_DARK)
            or Color3.fromRGB(200, 200, 200),
        LayoutOrder = getNextOrder(context),
        ClipsDescendants = style.overflow == "hidden"
            or style.overflowX == "hidden"
            or style.overflowY == "hidden",
    })

    if borderRadius > 0 then
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = container,
            CornerRadius = UDim.new(0, borderRadius),
        })
    end

    local display = style.display or "block"
    local flowFrame = dOS.create_gui_element(dOS, "Frame", {
        Parent = container,
        Name = "_flow",
        Size = UDim2.new(1, -(paddingLeft + paddingRight), 0, 0),
        Position = UDim2.fromOffset(paddingLeft, paddingTop),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    if display == "flex" or display == "inline-flex" then
        local flexDir = style.flexDirection or "row"
        local isRow = flexDir == "row" or flexDir == "row-reverse"
        local fillDir = isRow and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical

        local JUSTIFY_MAP = {
            ["flex-start"] = isRow and Enum.HorizontalAlignment.Left or Enum.VerticalAlignment.Top,
            ["flex-end"] = isRow and Enum.HorizontalAlignment.Right or Enum.VerticalAlignment.Bottom,
            center = isRow and Enum.HorizontalAlignment.Center or Enum.VerticalAlignment.Center,
            ["space-between"] = isRow and Enum.HorizontalAlignment.Left or Enum.VerticalAlignment.Top,
            ["space-around"] = isRow and Enum.HorizontalAlignment.Center or Enum.VerticalAlignment.Center,
            ["space-evenly"] = isRow and Enum.HorizontalAlignment.Center or Enum.VerticalAlignment.Center,
            normal = isRow and Enum.HorizontalAlignment.Left or Enum.VerticalAlignment.Top,
        }

        local ALIGN_MAP = {
            ["flex-start"] = isRow and Enum.VerticalAlignment.Top or Enum.HorizontalAlignment.Left,
            ["flex-end"] = isRow and Enum.VerticalAlignment.Bottom or Enum.HorizontalAlignment.Right,
            center = isRow and Enum.VerticalAlignment.Center or Enum.HorizontalAlignment.Center,
            stretch = isRow and Enum.VerticalAlignment.Top or Enum.HorizontalAlignment.Left,
            normal = isRow and Enum.VerticalAlignment.Top or Enum.HorizontalAlignment.Left,
        }

        local jc = style.justifyContent or "flex-start"
        local ai = style.alignItems or "flex-start"
        local gapPx = num(style.columnGap ~= nil and style.columnGap or style.gap, 0)
        if not isRow then
            gapPx = num(style.rowGap ~= nil and style.rowGap or style.gap, 0)
        end

        local layoutProps = {
            Parent = flowFrame,
            FillDirection = fillDir,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, gapPx),
            Wraps = style.flexWrap == "wrap" or style.flexWrap == "wrap-reverse",
        }

        if isRow then
            layoutProps.HorizontalAlignment = JUSTIFY_MAP[jc] or Enum.HorizontalAlignment.Left
            layoutProps.VerticalAlignment = ALIGN_MAP[ai] or Enum.VerticalAlignment.Top
        else
            layoutProps.HorizontalAlignment = ALIGN_MAP[ai] or Enum.HorizontalAlignment.Left
            layoutProps.VerticalAlignment = JUSTIFY_MAP[jc] or Enum.VerticalAlignment.Top
        end
        dOS.create_gui_element(dOS, "UIListLayout", layoutProps)
    else
        dOS.create_gui_element(dOS, "UIListLayout", {
            Parent = flowFrame,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 2),
            HorizontalAlignment = style.textAlign == "center"
                    and Enum.HorizontalAlignment.Center
                or Enum.HorizontalAlignment.Left,
        })
    end

    local cc = shallowCopyContext(context)
    cc.orderCounter = 0
    cc.parentWidth = context.parentWidth - paddingLeft - paddingRight - marginLeft
    cc.pendingBottomMargin = 0

    if cssPosition == "relative" then
        cc.absoluteParent = container
        cc.absoluteParentOffsetX = paddingLeft
        cc.absoluteParentOffsetY = paddingTop
    end

    local childH = renderInlineFlow(element, flowFrame, cc)
    flushBottomMargin(dOS, flowFrame, cc)

    local totalH = childH + paddingTop + paddingBottom
    flowFrame.Size = UDim2.new(1, -(paddingLeft + paddingRight), 0, childH)
    container.Size = UDim2.new(1, -marginLeft, 0, totalH)

    if context.StyleResolver and element.computedStyle then
        context.StyleResolver.applyAnimations(container, element, dOS)
    end

    if marginBottom > 0 then
        scheduleBottomMargin(marginBottom, context)
    end

    return totalH + marginTop + marginBottom
end

local function renderHeading(element, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle
    local fs = num(style.fontSize, 24)
    local tag = element.tagName

    local marginTop = num(style.marginTop, 10)
    local marginBottom = num(style.marginBottom, 8)

    local color = style.color
    if typeof(color) ~= "Color3" then color = parseColor(color) end
    color = color or (dOS.THEME and dOS.THEME.TEXT_DARK) or Color3.new(0, 0, 0)

    if marginTop > 0 then
        emitTopMargin(dOS, parent, marginTop, context)
    end

    local hFrame = dOS.create_gui_element(dOS, "Frame", {
        Parent = parent,
        Name = tag,
        Size = UDim2.fromScale(1, 0),
        BackgroundTransparency = 1,
        LayoutOrder = getNextOrder(context),
    })
    dOS.create_gui_element(dOS, "UIListLayout", {
        Parent = hFrame,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    })

    local cc = shallowCopyContext(context)
    cc.orderCounter = 0

    local contentH = renderInlineFlow(element, hFrame, cc)

    if contentH == 0 then
        local text = element:getTextContent()
        if text:match("%S") then
            contentH = estimateTextHeight(text, fs, context.parentWidth)
            dOS.create_gui_element(dOS, "TextLabel", {
                Parent = hFrame,
                Text = text,
                TextColor3 = color,
                TextSize = fs,
                Font = dOS.FONT_BOLD or Enum.Font.GothamBold,
                TextXAlignment = getTextAlignment(style),
                TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true,
                Size = UDim2.new(1, 0, 0, contentH),
                BackgroundTransparency = 1,
                LayoutOrder = getNextOrder(cc),
            })
        end
    end

    hFrame.Size = UDim2.new(1, 0, 0, contentH)

    if tag == "h1" or tag == "h2" then
        local lineColor = color
        dOS.create_gui_element(dOS, "Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = lineColor,
            BackgroundTransparency = 0.6,
            BorderSizePixel = 0,
            LayoutOrder = getNextOrder(context),
        })
    end

    if marginBottom > 0 then
        scheduleBottomMargin(marginBottom, context)
    end

    return contentH + marginTop + marginBottom
end

local function renderParagraph(element, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle

    local marginTop = num(style.marginTop, 8)
    local marginBottom = num(style.marginBottom, 8)

    if marginTop > 0 then
        emitTopMargin(dOS, parent, marginTop, context)
    end

    local pFrame = dOS.create_gui_element(dOS, "Frame", {
        Parent = parent,
        Name = "p",
        Size = UDim2.fromScale(1, 0),
        BackgroundTransparency = 1,
        LayoutOrder = getNextOrder(context),
    })
    dOS.create_gui_element(dOS, "UIListLayout", {
        Parent = pFrame,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    })

    local cc = shallowCopyContext(context)
    cc.orderCounter = 0

    local contentH = renderInlineFlow(element, pFrame, cc)
    pFrame.Size = UDim2.new(1, 0, 0, contentH)

    if marginBottom > 0 then
        scheduleBottomMargin(marginBottom, context)
    end

    return contentH + marginTop + marginBottom
end

local function renderAnchor(element, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle
    local fs = num(style.fontSize, 14)

    local href = element:getAttribute("href") or "#"
    local target = element:getAttribute("target")

    local color = style.color or Color3.fromRGB(0, 102, 204)
    if typeof(color) ~= "Color3" then
        color = parseColor(color) or Color3.fromRGB(0, 102, 204)
    end

    local innerParts = {}
    for _, child in ipairs(element.childNodes or {}) do
        innerParts[#innerParts + 1] = buildRichText(child, style, context)
    end

    local innerRich = table.concat(innerParts)
    local plain = element:getTextContent()
    if plain == "" then return 0 end

    local displayText = string.format(
        '<font color="%s"><u>%s</u></font>',
        color3ToHex(color),
        innerRich ~= "" and innerRich or escapeRichText(plain)
    )

    local h = estimateTextHeight(plain, fs, context.parentWidth)

    dOS.create_gui_element(dOS, "TextButton", {
        Parent = parent,
        Text = displayText,
        RichText = true,
        TextColor3 = color,
        TextSize = fs,
        Font = getFont(dOS, style),
        TextXAlignment = getTextAlignment(style),
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Size = UDim2.new(1, 0, 0, h),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        LayoutOrder = getNextOrder(context),
        OnClick = function()
            if context.onNavigate then context.onNavigate(href, target) end
        end,
    })

    return h
end

local function renderImage(element, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle

    local src = element:getAttribute("src") or ""
    local alt = element:getAttribute("alt") or "Image"

    local imgW = numOrNil(style.width) or tonumber(element:getAttribute("width"))
    local imgH = numOrNil(style.height) or tonumber(element:getAttribute("height")) or 150

    local assetId = src:match("rbxassetid://(%d+)")
    if not assetId and not src:find("://") then
        assetId = src:match("^%s*(%d+)%s*$")
    end

    if assetId then
        dOS.create_gui_element(dOS, "ImageLabel", {
            Parent = parent,
            Image = "rbxassetid://" .. assetId,
            Size = imgW and UDim2.fromOffset(imgW, imgH) or UDim2.new(1, 0, 0, imgH),
            ScaleType = Enum.ScaleType.Fit,
            BackgroundTransparency = 1,
            LayoutOrder = getNextOrder(context),
        })
    else
        local ph = dOS.create_gui_element(dOS, "Frame", {
            Parent = parent,
            Size = imgW and UDim2.fromOffset(imgW, imgH) or UDim2.new(1, 0, 0, imgH),
            BackgroundColor3 = Color3.fromRGB(230, 230, 230),
            BorderSizePixel = 1,
            BorderColor3 = Color3.fromRGB(180, 180, 180),
            LayoutOrder = getNextOrder(context),
        })
        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = ph,
            Text = `\xf0\x9f\x96\xbc {alt}`, -- 🖼 (UTF-8)
            Size = UDim2.fromScale(1, 1),
            TextColor3 = Color3.fromRGB(100, 100, 100),
            TextWrapped = true,
            BackgroundTransparency = 1,
        })
    end

    return imgH
end

local function renderBreak(_, parent, context)
    local dOS = context.dOS
    local fs = num(context.computedStyle.fontSize, 14)
    createSpacer(dOS, parent, fs, getNextOrder(context))
    return fs
end

local function renderHorizontalRule(_, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle

    local marginTop = num(style.marginTop, 10)
    local marginBottom = num(style.marginBottom, 10)
    local ruleH = num(style.height, 2)

    if marginTop > 0 then
        emitTopMargin(dOS, parent, marginTop, context)
    end

    dOS.create_gui_element(dOS, "Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, ruleH),
        BackgroundColor3 = (
            typeof(style.backgroundColor) == "Color3" and style.backgroundColor
        ) or Color3.fromRGB(200, 200, 200),
        BorderSizePixel = 0,
        LayoutOrder = getNextOrder(context),
    })

    if marginBottom > 0 then
        scheduleBottomMargin(marginBottom, context)
    end

    return ruleH + marginTop + marginBottom
end

local function renderList(element, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle
    local listTag = element.tagName

    local display = style.display or "block"
    if display == "flex"
        or display == "inline-flex"
        or display == "inline"
        or display == "inline-block"
    then
        return renderContainer(element, parent, context)
    end

    local marginTop = num(style.marginTop, 8)
    local marginBottom = num(style.marginBottom, 8)
    local marginLeft = num(style.marginLeft, 20)
    local paddingLeft = num(style.paddingLeft ~= nil and style.paddingLeft or style.padding, 0)

    local indent = paddingLeft > 0 and paddingLeft or marginLeft

    table.insert(context.listStack, {
        type = listTag,
        counter = 0,
        style = element:getAttribute("type") or (listTag == "ol" and "decimal" or "disc"),
        start = tonumber(element:getAttribute("start")) or 1,
    })

    local listStyleType = style.listStyleType or (listTag == "ol" and "decimal" or "disc")
    local noBullets = listStyleType == "none"
    if noBullets then
        context.listStack[#context.listStack].style = "none"
        indent = 0
    end

    if marginTop > 0 then
        emitTopMargin(dOS, parent, marginTop, context)
    end

    local container = dOS.create_gui_element(dOS, "Frame", {
        Parent = parent,
        Name = listTag,
        Size = UDim2.new(1, -indent, 0, 0),
        Position = indent > 0 and UDim2.fromOffset(indent, 0) or UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        LayoutOrder = getNextOrder(context),
    })
    dOS.create_gui_element(dOS, "UIListLayout", {
        Parent = container,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    })

    local cc = shallowCopyContext(context)
    cc.orderCounter = 0
    cc.parentWidth = context.parentWidth - indent

    local childH = renderChildren(element, container, cc)
    container.Size = UDim2.new(1, -indent, 0, childH)

    table.remove(context.listStack)

    if marginBottom > 0 then
        scheduleBottomMargin(marginBottom, context)
    end

    return childH + marginTop + marginBottom
end

local function renderListItem(element, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle
    local fs = num(style.fontSize, 14)

    local display = style.display or "list-item"
    if display == "inline" or display == "inline-block" then
        local bgColor = style.backgroundColor
        if typeof(bgColor) ~= "Color3" then bgColor = nil end

        local paddingTop = num(style.paddingTop ~= nil and style.paddingTop or style.padding, 0)
        local paddingBottom = num(style.paddingBottom ~= nil and style.paddingBottom or style.padding, 0)
        local paddingLeft = num(style.paddingLeft ~= nil and style.paddingLeft or style.padding, 0)
        local paddingRight = num(style.paddingRight ~= nil and style.paddingRight or style.padding, 0)
        local borderRadius = num(
            style.borderTopLeftRadius ~= nil and style.borderTopLeftRadius or style.borderRadius,
            0
        )
        local borderW = num(style.borderWidth, 0)
        local borderColor = style.borderColor or style.borderTopColor

        local liText = element:getTextContent()
        local wVal = numOrNil(style.width)
        local textW = wVal or (#liText * fs * 0.55 + paddingLeft + paddingRight + 16)
        textW = math.max(textW, 40)
        local hVal = num(style.height, 0)
        local textH = estimateTextHeight(liText, fs, textW - paddingLeft - paddingRight)
        local totalH = math.max(hVal, textH + paddingTop + paddingBottom, fs + 8)

        local liFrame = dOS.create_gui_element(dOS, "Frame", {
            Parent = parent,
            Name = "li_inline",
            Size = UDim2.fromOffset(textW, totalH),
            BackgroundColor3 = bgColor or Color3.new(1, 1, 1),
            BackgroundTransparency = bgColor and (1 - num(style.opacity, 1)) or 1,
            BorderSizePixel = borderW,
            BorderColor3 = (typeof(borderColor) == "Color3" and borderColor) or Color3.fromRGB(200, 200, 200),
            LayoutOrder = getNextOrder(context),
            ClipsDescendants = false,
        })

        if borderRadius > 0 then
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = liFrame,
                CornerRadius = UDim.new(0, borderRadius),
            })
        end

        if paddingLeft > 0 or paddingTop > 0 then
            dOS.create_gui_element(dOS, "UIPadding", {
                Parent = liFrame,
                PaddingTop = UDim.new(0, paddingTop),
                PaddingBottom = UDim.new(0, paddingBottom),
                PaddingLeft = UDim.new(0, paddingLeft),
                PaddingRight = UDim.new(0, paddingRight),
            })
        end

        dOS.create_gui_element(dOS, "UIListLayout", {
            Parent = liFrame,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 0),
        })

        local cc = shallowCopyContext(context)
        cc.orderCounter = 0
        cc.parentWidth = textW - paddingLeft - paddingRight
        renderInlineFlow(element, liFrame, cc)

        return totalH
    end

    local listCtx = context.listStack[#context.listStack]
    local BULLET_W = 22 -- pixels reserved for the bullet

    local noBullets = listCtx and listCtx.style == "none"

    if listCtx then
        listCtx.counter = listCtx.counter + 1
    end

    local bulletText = "\xe2\x80\xa2" -- • (UTF-8 U+2022)
    if listCtx and not noBullets then
        if listCtx.type == "ol" then
            local n = (listCtx.start or 1) + listCtx.counter - 1
            local s = listCtx.style

            if s == "lower-alpha" then
                bulletText = string.char(96 + (n - 1) % 26 + 1) .. "."
            elseif s == "upper-alpha" then
                bulletText = string.char(64 + (n - 1) % 26 + 1) .. "."
            elseif s == "lower-roman" then
                local rom = {
                    "i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x",
                    "xi", "xii", "xiii", "xiv", "xv", "xvi", "xvii", "xviii", "xix", "xx",
                }
                bulletText = (rom[n] or tostring(n)) .. "."
            elseif s == "upper-roman" then
                local rom = {
                    "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
                    "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX",
                }
                bulletText = (rom[n] or tostring(n)) .. "."
            else
                bulletText = tostring(n) .. "."
            end
        else
            local s = listCtx.style
            if s == "circle" then
                bulletText = "\xe2\x97\x8b" -- ○
            elseif s == "square" then
                bulletText = "\xe2\x96\xa0" -- ■
            end
        end
    end

    local color = style.color
    if typeof(color) ~= "Color3" then color = parseColor(color) end
    color = color or (dOS.THEME and dOS.THEME.TEXT_DARK) or Color3.new(0, 0, 0)

    local liFrame = dOS.create_gui_element(dOS, "Frame", {
        Parent = parent,
        Name = "li",
        Size = UDim2.fromScale(1, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = false,
        LayoutOrder = getNextOrder(context),
    })

    if not noBullets then
        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = liFrame,
            Text = bulletText,
            TextColor3 = color,
            TextSize = fs,
            Font = dOS.FONT_REGULAR or Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextYAlignment = Enum.TextYAlignment.Top,
            Size = UDim2.fromOffset(BULLET_W - 4, fs + 4),
            Position = UDim2.fromOffset(-BULLET_W, 0),
            BackgroundTransparency = 1,
        })
    end

    local contentFrame = dOS.create_gui_element(dOS, "Frame", {
        Parent = liFrame,
        Size = UDim2.fromScale(1, 0),
        BackgroundTransparency = 1,
    })
    dOS.create_gui_element(dOS, "UIListLayout", {
        Parent = contentFrame,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    })

    local cc = shallowCopyContext(context)
    cc.orderCounter = 0

    local contentH = renderInlineFlow(element, contentFrame, cc)
    contentH = math.max(contentH, fs + 4)
    contentFrame.Size = UDim2.new(1, 0, 0, contentH)
    liFrame.Size = UDim2.new(1, 0, 0, contentH)

    return contentH
end

local function renderTable(element, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle

    local marginTop = num(style.marginTop, 8)
    local marginBottom = num(style.marginBottom, 8)

    local rows = element:getElementsByTagName("tr")
    local colCount = 0

    for _, row in ipairs(rows) do
        local cells = 0
        for _, cell in ipairs(row.childNodes) do
            if cell.tagName == "td" or cell.tagName == "th" then
                cells = cells + (tonumber(cell:getAttribute("colspan")) or 1)
            end
        end
        colCount = math.max(colCount, cells)
    end

    if colCount == 0 then colCount = 1 end
    if marginTop > 0 then
        emitTopMargin(dOS, parent, marginTop, context)
    end

    local tableFrame = dOS.create_gui_element(dOS, "Frame", {
        Parent = parent,
        Name = "table",
        Size = UDim2.fromScale(1, 0),
        BackgroundTransparency = 1,
        LayoutOrder = getNextOrder(context),
    })
    dOS.create_gui_element(dOS, "UIListLayout", {
        Parent = tableFrame,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    })

    local totalH = 0
    local rowOrder = 0

    local captionEl = element:querySelector("caption")
    if captionEl then
        local captionText = captionEl:getTextContent()
        local captionH = estimateTextHeight(
            captionText,
            num(style.fontSize, 14),
            context.parentWidth
        ) + 8

        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = tableFrame,
            Text = captionText,
            TextColor3 = style.color or (dOS.THEME and dOS.THEME.TEXT_DARK) or Color3.new(0, 0, 0),
            TextSize = num(style.fontSize, 14),
            Font = dOS.FONT_BOLD or Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            Size = UDim2.new(1, 0, 0, captionH),
            BackgroundTransparency = 1,
            LayoutOrder = 0,
        })

        totalH += captionH
    end

    local function renderSection(section)
        if not section then return end

        for _, row in ipairs(section.childNodes) do
            if row.tagName == "tr" then
                rowOrder = rowOrder + 1
                local rowFrame = dOS.create_gui_element(dOS, "Frame", {
                    Parent = tableFrame,
                    Name = "tr",
                    Size = UDim2.fromScale(1, 0),
                    BackgroundTransparency = 1,
                    LayoutOrder = rowOrder,
                })

                local xFrac = 0
                local rowH = 30
                local cellW = 1 / colCount

                for _, cell in ipairs(row.childNodes) do
                    if cell.tagName == "td" or cell.tagName == "th" then
                        local colspan = tonumber(cell:getAttribute("colspan")) or 1
                        local thisFrac = cellW * colspan
                        local isHeader = cell.tagName == "th"
                        local pad = 8
                        local cellDefBg = isHeader and Color3.fromRGB(240, 240, 240) or nil

                        local cellFrame = dOS.create_gui_element(dOS, "Frame", {
                            Parent = rowFrame,
                            Name = cell.tagName,
                            Size = UDim2.fromScale(thisFrac, 1),
                            Position = UDim2.fromScale(xFrac, 0),
                            BackgroundColor3 = cellDefBg or Color3.new(1, 1, 1),
                            BackgroundTransparency = cellDefBg and 0 or 1,
                            BorderSizePixel = 1,
                            BorderColor3 = Color3.fromRGB(200, 200, 200),
                        })

                        dOS.create_gui_element(dOS, "UIPadding", {
                            Parent = cellFrame,
                            PaddingTop = UDim.new(0, pad),
                            PaddingBottom = UDim.new(0, pad),
                            PaddingLeft = UDim.new(0, pad),
                            PaddingRight = UDim.new(0, pad),
                        })

                        local cellText = cell:getTextContent()
                        local cellFs = num(style.fontSize, 14)
                        local cellW_px = context.parentWidth * thisFrac - pad * 2
                        local textH = estimateTextHeight(cellText, cellFs, cellW_px)

                        dOS.create_gui_element(dOS, "TextLabel", {
                            Parent = cellFrame,
                            Text = cellText,
                            TextColor3 = style.color or (dOS.THEME and dOS.THEME.TEXT_DARK) or Color3.new(0, 0, 0),
                            TextSize = cellFs,
                            Font = isHeader and (dOS.FONT_BOLD or Enum.Font.GothamBold)
                                or (dOS.FONT_REGULAR or Enum.Font.Gotham),
                            TextXAlignment = isHeader and Enum.TextXAlignment.Center
                                or Enum.TextXAlignment.Left,
                            TextYAlignment = Enum.TextYAlignment.Top,
                            TextWrapped = true,
                            Size = UDim2.fromScale(1, 1),
                            BackgroundTransparency = 1,
                        })

                        rowH = math.max(rowH, textH + pad * 2)
                        xFrac = xFrac + thisFrac
                    end
                end

                rowFrame.Size = UDim2.new(1, 0, 0, rowH)
                totalH = totalH + rowH
            end
        end
    end

    local thead = element:querySelector("thead")
    local tbody = element:querySelector("tbody")
    local tfoot = element:querySelector("tfoot")

    if thead or tbody or tfoot then
        renderSection(thead)
        renderSection(tbody)
        renderSection(tfoot)
    else
        renderSection(element)
    end

    tableFrame.Size = UDim2.new(1, 0, 0, totalH)

    if marginBottom > 0 then
        scheduleBottomMargin(marginBottom, context)
    end

    return totalH + marginTop + marginBottom
end

local function renderPreformatted(element, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle

    local marginTop = num(style.marginTop, 8)
    local marginBottom = num(style.marginBottom, 8)
    local padding = num(style.padding, 10)
    local fs = num(style.fontSize, 14)

    local text = element:getTextContent()
    local color = style.color
    if typeof(color) ~= "Color3" then color = parseColor(color) end
    color = color or (dOS.THEME and dOS.THEME.TEXT_DARK) or Color3.new(0, 0, 0)

    local lineCount = 1
    for _ in text:gmatch("\n") do
        lineCount = lineCount + 1
    end
    local h = lineCount * math.ceil(fs * 1.2) + padding * 2

    if marginTop > 0 then
        emitTopMargin(dOS, parent, marginTop, context)
    end

    local container = dOS.create_gui_element(dOS, "Frame", {
        Parent = parent,
        Name = "pre",
        Size = UDim2.new(1, 0, 0, h),
        BackgroundColor3 = style.backgroundColor or Color3.fromRGB(245, 245, 245),
        BorderSizePixel = 1,
        BorderColor3 = Color3.fromRGB(200, 200, 200),
        LayoutOrder = getNextOrder(context),
    })
    dOS.create_gui_element(dOS, "UIPadding", {
        Parent = container,
        PaddingTop = UDim.new(0, padding),
        PaddingBottom = UDim.new(0, padding),
        PaddingLeft = UDim.new(0, padding),
        PaddingRight = UDim.new(0, padding),
    })
    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = container,
        Text = text,
        TextColor3 = color,
        TextSize = fs,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = false,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
    })

    if marginBottom > 0 then
        scheduleBottomMargin(marginBottom, context)
    end

    return h + marginTop + marginBottom
end

local function renderBlockquote(element, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle

    local marginTop = num(style.marginTop, 10)
    local marginBottom = num(style.marginBottom, 10)
    local marginLeft = num(style.marginLeft, 40)
    local paddingLeft = num(style.paddingLeft, 10)
    local borderW = num(style.borderLeftWidth, 4)
    local borderColor = style.borderLeftColor or Color3.fromRGB(200, 200, 200)

    if marginTop > 0 then
        emitTopMargin(dOS, parent, marginTop, context)
    end

    local container = dOS.create_gui_element(dOS, "Frame", {
        Parent = parent,
        Name = "blockquote",
        Size = UDim2.new(1, -marginLeft, 0, 0),
        Position = UDim2.fromOffset(marginLeft, 0),
        BackgroundTransparency = 1,
        LayoutOrder = getNextOrder(context),
    })

    dOS.create_gui_element(dOS, "Frame", {
        Parent = container,
        Size = UDim2.new(0, borderW, 1, 0),
        Position = UDim2.fromOffset(-paddingLeft, 0),
        BackgroundColor3 = borderColor,
        BorderSizePixel = 0,
    })

    dOS.create_gui_element(dOS, "UIListLayout", {
        Parent = container,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    })

    local cc = shallowCopyContext(context)
    cc.orderCounter = 0
    cc.parentWidth = context.parentWidth - marginLeft - paddingLeft
    cc.pendingBottomMargin = 0
    cc.computedStyle = {}
    for k, v in pairs(context.computedStyle) do
        cc.computedStyle[k] = v
    end
    cc.computedStyle.fontStyle = "italic"

    local childH = renderChildren(element, container, cc)
    flushBottomMargin(dOS, container, cc)
    container.Size = UDim2.new(1, -marginLeft, 0, childH)

    if marginBottom > 0 then
        scheduleBottomMargin(marginBottom, context)
    end

    return childH + marginTop + marginBottom
end

local function renderFieldset(element, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle

    local marginTop = num(style.marginTop, 8)
    local marginBottom = num(style.marginBottom, 8)
    local padding = 10
    local fs = num(style.fontSize, 14)

    local legendEl = element:querySelector("legend")
    local legendText = legendEl and legendEl:getTextContent() or ""
    local legendH = legendText ~= "" and (fs + 8) or 0

    if marginTop > 0 then
        emitTopMargin(dOS, parent, marginTop, context)
    end

    local outer = dOS.create_gui_element(dOS, "Frame", {
        Parent = parent,
        Name = "fieldset",
        Size = UDim2.fromScale(1, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 1,
        BorderColor3 = Color3.fromRGB(180, 180, 180),
        LayoutOrder = getNextOrder(context),
        ClipsDescendants = false,
    })

    if legendText ~= "" then
        local legendBg = dOS.create_gui_element(dOS, "Frame", {
            Parent = outer,
            Size = UDim2.fromOffset(#legendText * fs * 0.55 + 16, legendH),
            Position = UDim2.fromOffset(padding, -legendH / 2),
            BackgroundColor3 = style.backgroundColor or Color3.new(1, 1, 1),
            BorderSizePixel = 0,
        })
        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = legendBg,
            Text = legendText,
            TextColor3 = style.color or (dOS.THEME and dOS.THEME.TEXT_DARK) or Color3.new(0, 0, 0),
            TextSize = fs,
            Font = dOS.FONT_BOLD or Enum.Font.GothamBold,
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
        })
    end

    local innerTop = math.floor(legendH / 2) + 4
    local innerFrame = dOS.create_gui_element(dOS, "Frame", {
        Parent = outer,
        Size = UDim2.new(1, -padding * 2, 0, 0),
        Position = UDim2.fromOffset(padding, innerTop),
        BackgroundTransparency = 1,
    })
    dOS.create_gui_element(dOS, "UIListLayout", {
        Parent = innerFrame,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    })

    local cc = shallowCopyContext(context)
    cc.orderCounter = 0
    cc.parentWidth = context.parentWidth - padding * 2

    local innerH = 0
    for _, child in ipairs(element.childNodes or {}) do
        if child.tagName ~= "legend" then
            innerH = innerH + renderNode(child, innerFrame, cc)
        end
    end

    innerFrame.Size = UDim2.new(1, -padding * 2, 0, innerH)
    local totalH = innerTop + innerH + padding
    outer.Size = UDim2.new(1, 0, 0, totalH)

    if marginBottom > 0 then
        scheduleBottomMargin(marginBottom, context)
    end

    return totalH + marginTop + marginBottom
end

local function renderFigure(element, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle

    local marginTop = num(style.marginTop, 10)
    local marginBottom = num(style.marginBottom, 10)
    local marginLeft = num(style.marginLeft, 20)
    local marginRight = num(style.marginRight, 20)
    local fs = num(style.fontSize, 14)

    local figcaption = element:querySelector("figcaption")

    if marginTop > 0 then
        emitTopMargin(dOS, parent, marginTop, context)
    end

    local container = dOS.create_gui_element(dOS, "Frame", {
        Parent = parent,
        Name = "figure",
        Size = UDim2.new(1, -(marginLeft + marginRight), 0, 0),
        Position = UDim2.fromOffset(marginLeft, 0),
        BackgroundTransparency = 1,
        LayoutOrder = getNextOrder(context),
    })
    dOS.create_gui_element(dOS, "UIListLayout", {
        Parent = container,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    })

    local cc = shallowCopyContext(context)
    cc.orderCounter = 0
    cc.parentWidth = context.parentWidth - marginLeft - marginRight

    local contentH = 0
    for _, child in ipairs(element.childNodes or {}) do
        if child.tagName ~= "figcaption" then
            contentH = contentH + renderNode(child, container, cc)
        end
    end

    local captionH = 0
    if figcaption then
        local captionText = figcaption:getTextContent()
        captionH = estimateTextHeight(captionText, fs - 1, cc.parentWidth) + 4
        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = container,
            Text = "<i>" .. escapeRichText(captionText) .. "</i>",
            RichText = true,
            TextColor3 = Color3.fromRGB(80, 80, 80),
            TextSize = fs - 1,
            Font = dOS.FONT_REGULAR or Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            Size = UDim2.new(1, 0, 0, captionH),
            BackgroundTransparency = 1,
            LayoutOrder = getNextOrder(cc),
        })
    end

    local totalH = contentH + captionH + (figcaption and 4 or 0)
    container.Size = UDim2.new(1, -(marginLeft + marginRight), 0, totalH)

    if marginBottom > 0 then
        scheduleBottomMargin(marginBottom, context)
    end

    return totalH + marginTop + marginBottom
end

local function renderDetails(element, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle

    local marginTop = num(style.marginTop, 8)
    local marginBottom = num(style.marginBottom, 8)
    local padding = num(style.padding, 8)
    local fs = num(context.computedStyle.fontSize, 14)

    local isOpen = element:hasAttribute("open")
    local summaryEl = element:querySelector("summary")
    local summaryText = summaryEl and summaryEl:getTextContent() or "Details"

    if marginTop > 0 then
        emitTopMargin(dOS, parent, marginTop, context)
    end

    local outer = dOS.create_gui_element(dOS, "Frame", {
        Parent = parent,
        Name = "details",
        Size = UDim2.fromScale(1, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 1,
        BorderColor3 = Color3.fromRGB(200, 200, 200),
        LayoutOrder = getNextOrder(context),
    })

    local summaryH = fs + padding * 2
    local summaryBtn
    summaryBtn = dOS.create_gui_element(dOS, "TextButton", {
        Parent = outer,
        Text = (isOpen and "\xe2\x96\xbc " or "\xe2\x96\xb6 ") .. summaryText, -- ▼ / ▶
        TextColor3 = style.color or (dOS.THEME and dOS.THEME.TEXT_DARK) or Color3.new(0, 0, 0),
        TextSize = fs,
        Font = dOS.FONT_BOLD or Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, summaryH),
        BackgroundTransparency = 1,
    })
    dOS.create_gui_element(dOS, "UIPadding", {
        Parent = summaryBtn,
        PaddingLeft = UDim.new(0, padding),
    })

    local contentFrame = dOS.create_gui_element(dOS, "Frame", {
        Parent = outer,
        Size = UDim2.fromScale(1, 0),
        Position = UDim2.fromOffset(0, summaryH),
        BackgroundTransparency = 1,
        Visible = isOpen,
    })
    dOS.create_gui_element(dOS, "UIPadding", {
        Parent = contentFrame,
        PaddingTop = UDim.new(0, padding),
        PaddingLeft = UDim.new(0, padding),
        PaddingRight = UDim.new(0, padding),
        PaddingBottom = UDim.new(0, padding),
    })
    dOS.create_gui_element(dOS, "UIListLayout", {
        Parent = contentFrame,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    })

    local cc = shallowCopyContext(context)
    cc.orderCounter = 0

    local innerH = 0
    for _, child in ipairs(element.childNodes or {}) do
        if child.tagName ~= "summary" then
            innerH = innerH + renderNode(child, contentFrame, cc)
        end
    end
    local contentFrameH = innerH + padding * 2
    contentFrame.Size = UDim2.new(1, 0, 0, isOpen and contentFrameH or 0)

    local totalH = summaryH + (isOpen and contentFrameH or 0)
    outer.Size = UDim2.new(1, 0, 0, totalH)

    summaryBtn.OnClick = function()
        isOpen = not isOpen
        summaryBtn.Text = (isOpen and "\xe2\x96\xbc " or "\xe2\x96\xb6 ") .. summaryText
        contentFrame.Visible = isOpen
        contentFrame.Size = UDim2.new(1, 0, 0, isOpen and contentFrameH or 0)
        outer.Size = UDim2.new(1, 0, 0, summaryH + (isOpen and contentFrameH or 0))
    end

    if marginBottom > 0 then
        scheduleBottomMargin(marginBottom, context)
    end

    return totalH + marginTop + marginBottom
end

local function renderDefinitionList(element, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle
    local fs = num(style.fontSize, 14)

    local marginTop = num(style.marginTop, 8)
    local marginBottom = num(style.marginBottom, 8)

    if marginTop > 0 then
        emitTopMargin(dOS, parent, marginTop, context)
    end

    local container = dOS.create_gui_element(dOS, "Frame", {
        Parent = parent,
        Name = "dl",
        Size = UDim2.fromScale(1, 0),
        BackgroundTransparency = 1,
        LayoutOrder = getNextOrder(context),
    })
    dOS.create_gui_element(dOS, "UIListLayout", {
        Parent = container,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    })

    local cc = shallowCopyContext(context)
    cc.orderCounter = 0
    cc.pendingBottomMargin = 0

    local totalChildH = 0
    for _, child in ipairs(element.childNodes or {}) do
        if child.nodeType == "element" then
            local ctag = child.tagName

            if ctag == "dt" then
                local dtText = child:getTextContent()
                if dtText:match("%S") then
                    local dtMarginTop = 6
                    emitTopMargin(dOS, container, dtMarginTop, cc)
                    local dtH = estimateTextHeight(dtText, fs, cc.parentWidth)

                    dOS.create_gui_element(dOS, "TextLabel", {
                        Parent = container,
                        Text = dtText,
                        TextColor3 = style.color or (dOS.THEME and dOS.THEME.TEXT_DARK) or Color3.new(0, 0, 0),
                        TextSize = fs,
                        Font = dOS.FONT_BOLD or Enum.Font.GothamBold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextYAlignment = Enum.TextYAlignment.Top,
                        TextWrapped = true,
                        Size = UDim2.new(1, 0, 0, dtH),
                        BackgroundTransparency = 1,
                        LayoutOrder = getNextOrder(cc),
                    })

                    totalChildH = totalChildH + dtH + dtMarginTop
                end
            elseif ctag == "dd" then
                local ddIndent = 40
                local ddText = child:getTextContent()

                if ddText:match("%S") then
                    local ddW = cc.parentWidth - ddIndent
                    local ddH = estimateTextHeight(ddText, fs, ddW) + 2
                    local ddFrame = dOS.create_gui_element(dOS, "Frame", {
                        Parent = container,
                        Name = "dd",
                        Size = UDim2.new(1, -ddIndent, 0, ddH),
                        Position = UDim2.fromOffset(ddIndent, 0),
                        BackgroundTransparency = 1,
                        LayoutOrder = getNextOrder(cc),
                    })
                    dOS.create_gui_element(dOS, "TextLabel", {
                        Parent = ddFrame,
                        Text = ddText,
                        TextColor3 = style.color or (dOS.THEME and dOS.THEME.TEXT_DARK) or Color3.new(0, 0, 0),
                        TextSize = fs,
                        Font = dOS.FONT_REGULAR or Enum.Font.Gotham,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextYAlignment = Enum.TextYAlignment.Top,
                        TextWrapped = true,
                        Size = UDim2.fromScale(1, 1),
                        BackgroundTransparency = 1,
                    })

                    totalChildH = totalChildH + ddH + 2
                end
            elseif child.nodeType ~= "text" :: any then
                totalChildH = totalChildH + renderNode(child, container, cc)
            end
        end
    end

    container.Size = UDim2.new(1, 0, 0, totalChildH)

    if marginBottom > 0 then
        scheduleBottomMargin(marginBottom, context)
    end

    return totalChildH + marginTop + marginBottom
end

local function renderForm(element, parent, context)
    context.formCounter = (context.formCounter or 0) + 1
    local formId = "form_" .. context.formCounter

    context.forms[formId] = {
        action = element:getAttribute("action") or "",
        method = ((element:getAttribute("method") or "GET")):upper(),
        inputs = {},
    }

    context.currentFormId = formId
    local h = renderContainer(element, parent, context)
    context.currentFormId = nil

    return h
end

local function renderInput(element, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle

    local inputType = (element:getAttribute("type") or "text"):lower()
    local name = element:getAttribute("name") or ""
    local value = element:getAttribute("value") or ""
    local placeholder = element:getAttribute("placeholder") or ""
    local disabled = element:hasAttribute("disabled")
    local readonly = element:hasAttribute("readonly")
    local checked = element:hasAttribute("checked")
    local height = num(style.height, 30)
    local width = numOrNil(style.width)
    local fs = num(style.fontSize, 14)

    if context.currentFormId and context.forms[context.currentFormId] then
        context.forms[context.currentFormId].inputs[name] = value
    end

    if inputType == "hidden" then return 0 end

    local container = dOS.create_gui_element(dOS, "Frame", {
        Parent = parent,
        Name = "input_" .. inputType,
        Size = width and UDim2.fromOffset(width, height) or UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        LayoutOrder = getNextOrder(context),
    })

    if inputType == "text"
        or inputType == "password"
        or inputType == "email"
        or inputType == "search"
        or inputType == "tel"
        or inputType == "url"
        or inputType == "number"
    then
        local displayText = value ~= "" and value or placeholder
        if inputType == "password" and value ~= "" then
            displayText = ("\xe2\x80\xa2"):rep(#value) -- •
        end

        local inputBtn
        inputBtn = dOS.create_gui_element(dOS, "TextButton", {
            Parent = container,
            Text = displayText,
            TextColor3 = value ~= "" and (style.color or Color3.new(0, 0, 0)) or Color3.fromRGB(150, 150, 150),
            TextSize = fs,
            Font = dOS.FONT_REGULAR or Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = disabled and Color3.fromRGB(240, 240, 240) or Color3.new(1, 1, 1),
            BorderSizePixel = 1,
            BorderColor3 = Color3.fromRGB(180, 180, 180),

            OnClick = function()
                if disabled or readonly then return end
                dOS.RequestStringAsync(
                    dOS,
                    "Enter " .. name .. ":",
                    value,
                    function(newVal)
                        if newVal then
                            value = newVal
                            element:setAttribute("value", newVal)
                            inputBtn.Text = inputType == "password"
                                    and ("\xe2\x80\xa2"):rep(#newVal)
                                or newVal
                            inputBtn.TextColor3 = style.color or Color3.new(0, 0, 0)
                            if context.currentFormId and context.forms[context.currentFormId] then
                                context.forms[context.currentFormId].inputs[name] = newVal
                            end
                        end
                    end
                )
            end,
        })
        dOS.create_gui_element(dOS, "UIPadding", {
            Parent = inputBtn,
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
        })

    elseif inputType == "submit"
        or inputType == "reset"
        or inputType == "button"
    then
        local label = value ~= "" and value
            or (
                inputType == "submit" and "Submit"
                or inputType == "reset" and "Reset"
                or "Button"
            )

        local btnBg = style.backgroundColor
        if typeof(btnBg) ~= "Color3" then btnBg = nil end
        if not btnBg then
            btnBg = (dOS.THEME and dOS.THEME.ACCENT_BUTTON_BG) or Color3.fromRGB(228, 228, 231)
        end

        local btnTextColor = style.color
        if typeof(btnTextColor) ~= "Color3" then btnTextColor = nil end
        if not btnTextColor then
            local lum = btnBg.R * 0.299 + btnBg.G * 0.587 + btnBg.B * 0.114
            btnTextColor = lum > 0.5 and Color3.fromRGB(30, 30, 30) or Color3.fromRGB(250, 250, 250)
        end

        local btnRadTL = num(style.borderTopLeftRadius ~= nil and style.borderTopLeftRadius or style.borderRadius, 4)
        local btnRadTR = num(style.borderTopRightRadius ~= nil and style.borderTopRightRadius or style.borderRadius, 4)
        local btnBorderRadius = math.max(
            btnRadTL,
            btnRadTR,
            num(style.borderBottomRightRadius ~= nil and style.borderBottomRightRadius or style.borderRadius, 4),
            num(style.borderBottomLeftRadius ~= nil and style.borderBottomLeftRadius or style.borderRadius, 4)
        )

        local submitBtn = dOS.create_gui_element(dOS, "TextButton", {
            Parent = container,
            Text = label,
            TextColor3 = disabled and Color3.fromRGB(150, 150, 150) or btnTextColor,
            TextSize = fs,
            Font = dOS.FONT_BOLD or Enum.Font.GothamBold,
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = disabled and Color3.fromRGB(210, 210, 210) or btnBg,
            BorderSizePixel = 1,
            BorderColor3 = Color3.new(
                math.max(0, btnBg.R - 0.1),
                math.max(0, btnBg.G - 0.1),
                math.max(0, btnBg.B - 0.1)
            ),

            AutoButtonColor = not style.backgroundColor,
            OnClick = function()
                if disabled then return end
                if inputType == "submit" and context.currentFormId then
                    local form = context.forms[context.currentFormId]
                    if form then
                        if context.onFormSubmit then
                            context.onFormSubmit(form, form.inputs)
                        elseif context.onNavigate then
                            local q = ""
                            for k, v in pairs(form.inputs) do
                                q = q
                                    .. (q == "" and "?" or "&")
                                    .. urlEncode(k)
                                    .. "="
                                    .. urlEncode(v)
                            end
                            context.onNavigate(form.action .. q)
                        end
                    end
                elseif inputType == "reset" and context.currentFormId then
                    local form = context.forms[context.currentFormId]
                    if form then
                        for k in pairs(form.inputs) do
                            form.inputs[k] = ""
                        end
                    end
                end
            end,
        })

        if btnBorderRadius > 0 then
            dOS.create_gui_element(dOS, "UICorner", {
                Parent = submitBtn,
                CornerRadius = UDim.new(0, btnBorderRadius),
            })
        end

        dOS.create_gui_element(dOS, "UIPadding", {
            Parent = submitBtn,
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12),
        })

    elseif inputType == "checkbox" then
        container.Size = UDim2.fromOffset(24, 24)

        local cb
        cb = dOS.create_gui_element(dOS, "TextButton", {
            Parent = container,
            Text = checked and "\xe2\x9c\x93" or "", -- ✓
            TextColor3 = (dOS.THEME and dOS.THEME.TEXT_DARK) or Color3.new(0, 0, 0),
            TextSize = 16,
            Font = dOS.FONT_BOLD or Enum.Font.GothamBold,
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 1,
            BorderColor3 = Color3.fromRGB(180, 180, 180),

            OnClick = function()
                if disabled then return end
                checked = not checked
                cb.Text = checked and "\xe2\x9c\x93" or ""
                if context.currentFormId and context.forms[context.currentFormId] then
                    context.forms[context.currentFormId].inputs[name] = checked
                            and (value ~= "" and value or "on")
                        or ""
                end
            end,
        })

        return 24

    elseif inputType == "radio" then
        container.Size = UDim2.fromOffset(24, 24)

        local rb
        rb = dOS.create_gui_element(dOS, "TextButton", {
            Parent = container,
            Text = checked and "\xe2\x97\x8f" or "", -- ●
            TextColor3 = (dOS.THEME and dOS.THEME.TEXT_DARK) or Color3.new(0, 0, 0),
            TextSize = 12,
            Font = dOS.FONT_BOLD or Enum.Font.GothamBold,
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 1,
            BorderColor3 = Color3.fromRGB(180, 180, 180),

            OnClick = function()
                if disabled then return end
                checked = true
                rb.Text = "\xe2\x97\x8f"
                if context.currentFormId and context.forms[context.currentFormId] then
                    context.forms[context.currentFormId].inputs[name] = value
                end
            end,
        })
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = rb,
            CornerRadius = UDim.new(0.5, 0),
        })

        return 24

    elseif inputType == "color" then
        container.Size = UDim2.fromOffset(40, 30)

        dOS.create_gui_element(dOS, "Frame", {
            Parent = container,
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = parseColor(value ~= "" and value or "#000000") or Color3.new(0, 0, 0),
            BorderSizePixel = 1,
            BorderColor3 = Color3.fromRGB(180, 180, 180),
        })

        return 30

    elseif inputType == "range" then
        local minV = tonumber(element:getAttribute("min")) or 0
        local maxV = tonumber(element:getAttribute("max")) or 100
        local curV = tonumber(value) or ((minV + maxV) / 2)

        if dOS.create_slider then
            dOS.create_slider(
                dOS,
                container,
                UDim2.new(0, 0, 0.5, -5),
                UDim2.new(1, 0, 0, 10),
                minV,
                maxV,
                curV,
                function(newV)
                    if context.currentFormId and context.forms[context.currentFormId] then
                        context.forms[context.currentFormId].inputs[name] = tostring(newV)
                    end
                end
            )
        end
    end

    return height
end

local function renderButton(element, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle
    local btnType = (element:getAttribute("type") or "button"):lower()
    local fs = num(style.fontSize, 14)
    local disabled = element:hasAttribute("disabled")

    local label = element:getTextContent()

    local richParts = {}
    for _, child in ipairs(element.childNodes or {}) do
        richParts[#richParts + 1] = buildRichText(child, style, context)
    end

    local richLabel = table.concat(richParts)
    local useRich = richLabel ~= "" and richLabel ~= label

    local h = num(style.height, 34)
    local cssW = numOrNil(style.width)

    local marginTop = num(style.marginTop, 4)
    local marginBottom = num(style.marginBottom, 4)
    local marginLeft = num(style.marginLeft, 0)

    if marginTop > 0 then
        emitTopMargin(dOS, parent, marginTop, context)
    end

    local bgColor = style.backgroundColor
    if typeof(bgColor) ~= "Color3" then bgColor = nil end
    local bgAlpha = style.backgroundColorOpacity
    local opacity = num(style.opacity, 1)
    local bgTransp = bgColor and math.clamp(1 - (bgAlpha ~= nil and bgAlpha or opacity), 0, 1) or 0

    local finalBg = bgColor
    if not finalBg then
        finalBg = (dOS.THEME and dOS.THEME.ACCENT_BUTTON_BG) or Color3.fromRGB(228, 228, 231)
    end

    local textColor = style.color
    if typeof(textColor) ~= "Color3" then textColor = parseColor(textColor) end
    if not textColor then
        if finalBg then
            local lum = finalBg.R * 0.299 + finalBg.G * 0.587 + finalBg.B * 0.114
            textColor = lum > 0.5 and Color3.fromRGB(30, 30, 30) or Color3.fromRGB(250, 250, 250)
        else
            textColor = (dOS.THEME and dOS.THEME.TEXT_DARK) or Color3.new(0, 0, 0)
        end
    end

    local pl = num(style.paddingLeft ~= nil and style.paddingLeft or style.padding, 14)
    local pr = num(style.paddingRight ~= nil and style.paddingRight or style.padding, 14)
    local pt = num(style.paddingTop ~= nil and style.paddingTop or style.padding, 6)
    local pb = num(style.paddingBottom ~= nil and style.paddingBottom or style.padding, 6)

    local borderW = num(style.borderWidth, 0)
    if borderW == 0 then
        borderW = math.max(
            num(style.borderTopWidth, 0),
            num(style.borderRightWidth, 0),
            num(style.borderBottomWidth, 0),
            num(style.borderLeftWidth, 0)
        )
    end

    local borderColor = style.borderTopColor or style.borderColor or style.borderBottomColor
    if typeof(borderColor) ~= "Color3" then borderColor = nil end

    if not borderColor and borderW == 0 then
        borderW = 1
        borderColor = finalBg
                and Color3.new(
                    math.max(0, finalBg.R - 0.15),
                    math.max(0, finalBg.G - 0.15),
                    math.max(0, finalBg.B - 0.15)
                )
            or Color3.fromRGB(180, 180, 180)
    end

    local radTL = num(style.borderTopLeftRadius ~= nil and style.borderTopLeftRadius or style.borderRadius, 4)
    local radTR = num(style.borderTopRightRadius ~= nil and style.borderTopRightRadius or style.borderRadius, 4)
    local radBR = num(style.borderBottomRightRadius ~= nil and style.borderBottomRightRadius or style.borderRadius, 4)
    local radBL = num(style.borderBottomLeftRadius ~= nil and style.borderBottomLeftRadius or style.borderRadius, 4)
    local borderRadius = math.max(radTL, radTR, radBR, radBL)

    local autoW = #label * fs * 0.55 + pl + pr + 8
    local sizeUDim = cssW and UDim2.fromOffset(cssW, h) or UDim2.fromOffset(math.max(60, autoW), h)

    local btn = dOS.create_gui_element(dOS, "TextButton", {
        Parent = parent,
        Text = useRich and richLabel or label,
        RichText = useRich,
        TextColor3 = disabled and Color3.fromRGB(160, 160, 160) or textColor,
        TextSize = fs,
        Font = dOS.FONT_BOLD or Enum.Font.GothamBold,
        TextWrapped = true,
        Size = sizeUDim,
        Position = marginLeft > 0 and UDim2.fromOffset(marginLeft, 0) or UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = disabled and Color3.fromRGB(210, 210, 210) or finalBg,
        BackgroundTransparency = disabled and 0 or bgTransp,
        BorderSizePixel = borderW,
        BorderColor3 = borderColor or Color3.fromRGB(180, 180, 180),
        AutoButtonColor = not bgColor, -- hover only without a custom bg
        LayoutOrder = getNextOrder(context),

        OnClick = function()
            if disabled then return end
            if btnType == "submit" and context.currentFormId then
                local form = context.forms[context.currentFormId]
                if form and context.onFormSubmit then
                    context.onFormSubmit(form, form.inputs)
                end
            end
        end,
    })

    dOS.create_gui_element(dOS, "UIPadding", {
        Parent = btn,
        PaddingLeft = UDim.new(0, pl),
        PaddingRight = UDim.new(0, pr),
        PaddingTop = UDim.new(0, pt),
        PaddingBottom = UDim.new(0, pb),
    })

    if borderRadius > 0 then
        dOS.create_gui_element(dOS, "UICorner", {
            Parent = btn,
            CornerRadius = UDim.new(0, borderRadius),
        })
    end

    if marginBottom > 0 then
        scheduleBottomMargin(marginBottom, context)
    end

    return h + marginTop + marginBottom
end

local function renderSelect(element, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle
    local name = element:getAttribute("name") or ""
    local disabled = element:hasAttribute("disabled")
    local h = num(style.height, 30)
    local fs = num(style.fontSize, 14)

    local options = element:getElementsByTagName("option")
    local selVal, selText = "", "Select\xe2\x80\xa6" -- …

    for _, opt in ipairs(options) do
        if opt:hasAttribute("selected") then
            selVal = opt:getAttribute("value") or opt:getTextContent()
            selText = opt:getTextContent()
            break
        end
    end

    if selVal == "" and #options > 0 then
        selVal = options[1]:getAttribute("value") or options[1]:getTextContent()
        selText = options[1]:getTextContent()
    end

    if context.currentFormId and context.forms[context.currentFormId] then
        context.forms[context.currentFormId].inputs[name] = selVal
    end

    local btn
    btn = dOS.create_gui_element(dOS, "TextButton", {
        Parent = parent,
        Text = selText .. " \xe2\x96\xbe", -- ▾
        TextColor3 = (dOS.THEME and dOS.THEME.TEXT_DARK) or Color3.new(0, 0, 0),
        TextSize = fs,
        Font = dOS.FONT_REGULAR or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, h),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 1,
        BorderColor3 = Color3.fromRGB(180, 180, 180),
        LayoutOrder = getNextOrder(context),

        OnClick = function()
            if disabled or #options == 0 then return end

            local cur = 1
            for i, opt in ipairs(options) do
                if opt:getTextContent() == selText then
                    cur = i
                    break
                end
            end

            cur = (cur % #options) + 1
            selText = options[cur]:getTextContent()
            selVal = options[cur]:getAttribute("value") or selText
            btn.Text = selText .. " \xe2\x96\xbe"

            if context.currentFormId and context.forms[context.currentFormId] then
                context.forms[context.currentFormId].inputs[name] = selVal
            end
        end,
    })
    dOS.create_gui_element(dOS, "UIPadding", {
        Parent = btn,
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
    })

    return h
end

local function renderTextarea(element, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle
    local name = element:getAttribute("name") or ""
    local rows = tonumber(element:getAttribute("rows")) or 4
    local val = element:getTextContent()
    local placeholder = element:getAttribute("placeholder") or ""
    local disabled = element:hasAttribute("disabled")
    local readonly = element:hasAttribute("readonly")
    local fs = num(style.fontSize, 14)
    local h = rows * math.ceil(fs * 1.4) + 16

    if context.currentFormId and context.forms[context.currentFormId] then
        context.forms[context.currentFormId].inputs[name] = val
    end

    local btn
    btn = dOS.create_gui_element(dOS, "TextButton", {
        Parent = parent,
        Text = val ~= "" and val or placeholder,
        TextColor3 = val ~= ""
                and ((dOS.THEME and dOS.THEME.TEXT_DARK) or Color3.new(0, 0, 0))
            or Color3.fromRGB(150, 150, 150),
        TextSize = fs,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Size = UDim2.new(1, 0, 0, h),
        BackgroundColor3 = disabled and Color3.fromRGB(240, 240, 240) or Color3.new(1, 1, 1),
        BorderSizePixel = 1,
        BorderColor3 = Color3.fromRGB(180, 180, 180),
        LayoutOrder = getNextOrder(context),

        OnClick = function()
            if disabled or readonly then return end
            dOS.RequestStringAsync(dOS, "Enter text:", val, function(newVal)
                if newVal then
                    val = newVal
                    btn.Text = newVal
                    btn.TextColor3 = (dOS.THEME and dOS.THEME.TEXT_DARK) or Color3.new(0, 0, 0)
                    if context.currentFormId and context.forms[context.currentFormId] then
                        context.forms[context.currentFormId].inputs[name] = newVal
                    end
                end
            end)
        end,
    })
    dOS.create_gui_element(dOS, "UIPadding", {
        Parent = btn,
        PaddingTop = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
    })

    return h
end

local function renderLabel(element, parent, context)
    local dOS = context.dOS
    local style = context.computedStyle
    local fs = num(style.fontSize, 14)

    local color = style.color
    if typeof(color) ~= "Color3" then color = parseColor(color) end
    color = color or (dOS.THEME and dOS.THEME.TEXT_DARK) or Color3.new(0, 0, 0)

    local richParts = {}
    for _, child in ipairs(element.childNodes or {}) do
        richParts[#richParts + 1] = buildRichText(child, style, context)
    end

    local richText = table.concat(richParts)
    local plain = element:getTextContent()
    if plain == "" then return 0 end

    local h = estimateTextHeight(plain, fs, context.parentWidth)
    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = parent,
        Text = richText ~= "" and richText or plain,
        RichText = richText ~= "",
        TextColor3 = color,
        TextSize = fs,
        Font = getFont(dOS, style),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.new(1, 0, 0, h),
        BackgroundTransparency = 1,
        LayoutOrder = getNextOrder(context),
    })

    return h
end

function renderChildren(node, parent, context)
    local totalH = 0

    for _, child in ipairs(node.childNodes or {}) do
        totalH = totalH + renderNode(child, parent, context)

        if context.orderCounter % 40 == 0 then
            if task and task.wait then task.wait() end
        end
    end

    return totalH
end

renderNode = function(node, parent, context)
    if not node then return 0 end

    local nodeType = node.nodeType
    if nodeType == "document" then
        return renderInlineFlow(node, parent, context)
    end

    if nodeType == "text" then
        local text = node.nodeValue or ""
        if not context.preserveWhitespace then
            text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        end
        if text == "" then return 0 end

        local dOS = context.dOS
        local style = context.computedStyle
        local fs = num(style.fontSize, 14)
        local color = style.color
        if typeof(color) ~= "Color3" then color = parseColor(color) end
        color = color or (dOS.THEME and dOS.THEME.TEXT_DARK) or Color3.new(0, 0, 0)

        local h = estimateTextHeight(text, fs, context.parentWidth)
        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = parent,
            Text = escapeRichText(text),
            RichText = true,
            TextColor3 = color,
            TextSize = fs,
            Font = getFont(dOS, style),
            TextXAlignment = getTextAlignment(style),
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            Size = UDim2.new(1, 0, 0, h),
            BackgroundTransparency = 1,
            LayoutOrder = getNextOrder(context),
        })
        return h
    end

    if nodeType == "comment" or nodeType == "doctype" then return 0 end

    if nodeType == "cdata" then
        node.nodeValue = node.nodeValue or ""
        return renderNode(
            { nodeType = "text", nodeValue = node.nodeValue },
            parent,
            context
        )
    end

    if nodeType ~= "element" then return 0 end

    local tag = node.tagName

    if tag == "head"
        or tag == "meta"
        or tag == "link"
        or tag == "script"
        or tag == "template"
    then
        return 0
    end

    if tag == "style" then return 0 end

    if tag == "html" then return renderInlineFlow(node, parent, context) end
    if tag == "body" then
        if node.computedStyle then
            context.computedStyle = node.computedStyle
        end
        return renderInlineFlow(node, parent, context)
    end

    local parentStyle = context.computedStyle or {}
    context.computedStyle = node.computedStyle or parentStyle

    local prevPreserveWhitespace = context.preserveWhitespace
    if PREFORMATTED_ELEMENTS[tag] then context.preserveWhitespace = true end

    local h = 0

    if tag == "h1"
        or tag == "h2"
        or tag == "h3"
        or tag == "h4"
        or tag == "h5"
        or tag == "h6"
    then
        h = renderHeading(node, parent, context)
    elseif tag == "p" then
        h = renderParagraph(node, parent, context)
    elseif tag == "a" then
        h = renderAnchor(node, parent, context)
    elseif tag == "img" then
        h = renderImage(node, parent, context)
    elseif tag == "br" then
        h = renderBreak(node, parent, context)
    elseif tag == "hr" then
        h = renderHorizontalRule(node, parent, context)
    elseif tag == "ul" or tag == "ol" or tag == "menu" then
        local listDisp = context.computedStyle
                and (context.computedStyle.display or "block")
            or "block"

        if listDisp == "flex"
            or listDisp == "inline-flex"
            or listDisp == "inline"
            or listDisp == "inline-block"
        then
            h = renderContainer(node, parent, context)
        else
            h = renderList(node, parent, context)
        end
    elseif tag == "li" then
        h = renderListItem(node, parent, context)
    elseif tag == "table" then
        h = renderTable(node, parent, context)
    elseif tag == "pre" then
        h = renderPreformatted(node, parent, context)
    elseif tag == "blockquote" then
        h = renderBlockquote(node, parent, context)
    elseif tag == "details" then
        h = renderDetails(node, parent, context)
    elseif tag == "fieldset" then
        h = renderFieldset(node, parent, context)
    elseif tag == "figure" then
        h = renderFigure(node, parent, context)
    elseif tag == "form" then
        h = renderForm(node, parent, context)
    elseif tag == "input" then
        h = renderInput(node, parent, context)
    elseif tag == "button" then
        h = renderButton(node, parent, context)
    elseif tag == "select" then
        h = renderSelect(node, parent, context)
    elseif tag == "textarea" then
        h = renderTextarea(node, parent, context)
    elseif tag == "label" then
        h = renderLabel(node, parent, context)
    elseif tag == "dl" then
        h = renderDefinitionList(node, parent, context)

    elseif tag == "code" then
        local _dOS = context.dOS
        local text = node:getTextContent()
        local fs = num(context.computedStyle.fontSize, 14)
        local codeH = estimateTextHeight(text, fs, context.parentWidth) + 4

        local codeFrame = _dOS.create_gui_element(_dOS, "Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, codeH),
            BackgroundColor3 = context.computedStyle.backgroundColor or Color3.fromRGB(240, 240, 240),
            BorderSizePixel = 0,
            LayoutOrder = getNextOrder(context),
        })
        _dOS.create_gui_element(_dOS, "UIPadding", {
            Parent = codeFrame,
            PaddingLeft = UDim.new(0, 4),
            PaddingRight = UDim.new(0, 4),
        })
        _dOS.create_gui_element(_dOS, "TextLabel", {
            Parent = codeFrame,
            Text = text,
            TextColor3 = context.computedStyle.color or Color3.fromRGB(80, 80, 80),
            TextSize = fs,
            Font = Enum.Font.Code,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
        })
        h = codeH

    elseif INLINE_ELEMENTS[tag] then
        h = renderInlineFlow(node, parent, context)
    elseif BLOCK_ELEMENTS[tag] then
        h = renderContainer(node, parent, context)
    else
        h = renderChildren(node, parent, context)
    end

    context.computedStyle = parentStyle
    context.preserveWhitespace = prevPreserveWhitespace

    return h
end

function Renderer.render(dOS, document, parentFrame, options)
    options = options or {}

    local context = createContext(dOS, options)
    context.parentWidth = (
        parentFrame.AbsoluteSize.X > 0 and parentFrame.AbsoluteSize.X
    ) or 800
    context.parentHeight = (
        parentFrame.AbsoluteSize.Y > 0 and parentFrame.AbsoluteSize.Y
    ) or 600

    context.computedStyle = {
        color = (dOS.THEME and dOS.THEME.TEXT_DARK) or Color3.new(0, 0, 0),
        fontSize = (dOS.os_settings and dOS.os_settings.global_font_size) or 14,
        fontWeight = "normal",
        fontStyle = "normal",
        textAlign = "left",
        display = "block",
    }

    context.StyleResolver = options.StyleResolver or _StyleResolver
    context.absoluteParent = parentFrame

    if not parentFrame:FindFirstChildOfClass("UIListLayout") then
        dOS.create_gui_element(dOS, "UIListLayout", {
            Parent = parentFrame,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 2),
        })
    end

    local totalH = renderNode(document, parentFrame, context)
    flushBottomMargin(dOS, parentFrame, context)
    return totalH
end

function Renderer.renderHTML(
    dOS,
    html,
    parentFrame,
    options,
    HTMLLexer,
    HTMLParser,
    CSSLexer,
    CSSParser,
    StyleResolver
)
    options = options or {}

    local document = HTMLParser.parseHTML(html, HTMLLexer, { skipWhitespaceOnlyText = true })

    local cssom = nil
    if CSSLexer and CSSParser and document.head then
        local cssText = ""

        local ok, _ = pcall(function()
            for _, styleTag in ipairs(document.head:getElementsByTagName("style")) do
                cssText = cssText .. styleTag:getTextContent() .. "\n"
            end
        end)

        if not ok then cssText = "" end

        if cssText ~= "" then
            local ok2, result2 = pcall(function()
                return CSSParser.parseCSS(cssText, CSSLexer)
            end)
            if ok2 then cssom = result2 end
        end
    end

    if StyleResolver then
        local viewport = {
            width = (
                parentFrame.AbsoluteSize.X > 0 and parentFrame.AbsoluteSize.X
            ) or 800,
            height = (
                parentFrame.AbsoluteSize.Y > 0 and parentFrame.AbsoluteSize.Y
            ) or 600,
            type = "screen",
        }

        StyleResolver.resolveTree(document, cssom, CSSLexer, CSSParser, {
            dOS = dOS,
            viewport = viewport,
        })

        options.StyleResolver = StyleResolver
    end

    return Renderer.render(dOS, document, parentFrame, options)
end

function Renderer.setStyleResolver(sr)
    _StyleResolver = sr
end

return Renderer

-- EOF