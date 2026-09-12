--[[
    "HTML Parser module for dOS"
    
    @module html_parser
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


--- NODES

local NodeType = {
    DOCUMENT = "document",
    ELEMENT = "element",
    TEXT = "text",
    COMMENT = "comment",
    DOCTYPE = "doctype",
    CDATA = "cdata",
}

--- MARKERS

-- active formatting list marker
local SCOPE_MARKER = { type = "marker", name = "scope_marker" }

--- ELEMENTS

-- void elements (no children)
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
    param = true,
    command = true,
    keygen = true,
}

-- raw text elements
local RAW_TEXT_ELEMENTS = {
    script = true,
    style = true,
}

-- "special" category
local SPECIAL_ELEMENTS = {
    address = true,
    applet = true,
    area = true,
    article = true,
    aside = true,
    base = true,
    basefont = true,
    bgsound = true,
    blockquote = true,
    body = true,
    br = true,
    button = true,
    caption = true,
    center = true,
    col = true,
    colgroup = true,
    dd = true,
    details = true,
    dir = true,
    div = true,
    dl = true,
    dt = true,
    embed = true,
    fieldset = true,
    figcaption = true,
    figure = true,
    footer = true,
    form = true,
    frame = true,
    frameset = true,
    h1 = true,
    h2 = true,
    h3 = true,
    h4 = true,
    h5 = true,
    h6 = true,
    head = true,
    header = true,
    hgroup = true,
    hr = true,
    html = true,
    iframe = true,
    img = true,
    input = true,
    keygen = true,
    li = true,
    link = true,
    listing = true,
    main = true,
    marquee = true,
    menu = true,
    meta = true,
    nav = true,
    noembed = true,
    noframes = true,
    noscript = true,
    object = true,
    ol = true,
    p = true,
    param = true,
    plaintext = true,
    pre = true,
    script = true,
    search = true,
    section = true,
    select = true,
    source = true,
    style = true,
    summary = true,
    table = true,
    tbody = true,
    td = true,
    template = true,
    textarea = true,
    tfoot = true,
    th = true,
    thead = true,
    title = true,
    tr = true,
    track = true,
    ul = true,
    wbr = true,
    xmp = true,
}

-- formatting elements
local FORMATTING_ELEMENTS = {
    a = true,
    b = true,
    big = true,
    code = true,
    em = true,
    font = true,
    i = true,
    nobr = true,
    s = true,
    small = true,
    strike = true,
    strong = true,
    tt = true,
    u = true,
}

-- block-level elements
local BLOCK_ELEMENTS = {
    address = true,
    article = true,
    aside = true,
    blockquote = true,
    center = true,
    details = true,
    dialog = true,
    dir = true,
    div = true,
    dl = true,
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
    ol = true,
    p = true,
    pre = true,
    section = true,
    search = true,
    table = true,
    ul = true,
}

-- heading elements
local HEADING_ELEMENTS = {
    h1 = true,
    h2 = true,
    h3 = true,
    h4 = true,
    h5 = true,
    h6 = true,
}

-- head elements
local HEAD_ELEMENTS = {
    base = true,
    basefont = true,
    bgsound = true,
    link = true,
    meta = true,
    title = true,
    style = true,
    script = true,
    noscript = true,
    template = true,
}

-- table elements
local TABLE_ELEMENTS = {
    table = true,
    caption = true,
    colgroup = true,
    col = true,
    thead = true,
    tbody = true,
    tfoot = true,
    tr = true,
    td = true,
    th = true,
}

-- table sections
local TABLE_SECTIONS = {
    thead = true,
    tbody = true,
    tfoot = true,
}

-- table cells
local TABLE_CELLS = {
    td = true,
    th = true,
}

-- list item containers
local LIST_CONTAINERS = {
    ul = true,
    ol = true,
    menu = true,
}

-- definition lists
local DL_ELEMENTS = {
    dt = true,
    dd = true,
}

-- scope markers
local SCOPE_MARKERS = {
    applet = true,
    caption = true,
    html = true,
    table = true,
    td = true,
    th = true,
    marquee = true,
    object = true,
    template = true,
}

-- list item scope markers
local LIST_SCOPE_MARKERS = {
    applet = true,
    caption = true,
    html = true,
    table = true,
    td = true,
    th = true,
    marquee = true,
    object = true,
    template = true,
    ol = true,
    ul = true,
}

-- button scope markers
local BUTTON_SCOPE_MARKERS = {
    applet = true,
    caption = true,
    html = true,
    table = true,
    td = true,
    th = true,
    marquee = true,
    object = true,
    template = true,
    button = true,
}

-- table scope markers
local TABLE_SCOPE_MARKERS = {
    html = true,
    table = true,
    template = true,
}

-- select scope
local SELECT_SCOPE_MARKERS = {
    option = true,
    optgroup = true,
}

--- IMPLICIT

local IMPLICIT_CLOSE_RULES = {
    p = {
        closedBy = {
            address = true,
            article = true,
            aside = true,
            blockquote = true,
            center = true,
            details = true,
            dialog = true,
            dir = true,
            div = true,
            dl = true,
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
            ol = true,
            p = true,
            pre = true,
            section = true,
            search = true,
            table = true,
            ul = true,
        },
        closedByEnd = {
            body = true,
            html = true,
            div = true,
            article = true,
            section = true,
            aside = true,
            nav = true,
            header = true,
            footer = true,
            main = true,
            td = true,
            th = true,
            li = true,
            dd = true,
            dt = true,
            blockquote = true,
            figure = true,
            figcaption = true,
            details = true,
            dialog = true,
            form = true,
            fieldset = true,
        },
    },

    li = {
        closedBy = { li = true },
        closedByEnd = { ul = true, ol = true, menu = true },
    },

    dt = {
        closedBy = { dt = true, dd = true },
        closedByEnd = { dl = true },
    },

    dd = {
        closedBy = { dt = true, dd = true },
        closedByEnd = { dl = true },
    },

    tr = {
        closedBy = { tr = true },
        closedByEnd = { table = true, thead = true, tbody = true, tfoot = true },
    },

    td = {
        closedBy = { td = true, th = true },
        closedByEnd = {
            tr = true,
            table = true,
            thead = true,
            tbody = true,
            tfoot = true,
        },
    },

    th = {
        closedBy = { td = true, th = true },
        closedByEnd = {
            tr = true,
            table = true,
            thead = true,
            tbody = true,
            tfoot = true,
        },
    },

    thead = {
        closedBy = { tbody = true, tfoot = true },
        closedByEnd = { table = true },
    },

    tbody = {
        closedBy = { tbody = true, tfoot = true },
        closedByEnd = { table = true },
    },

    tfoot = {
        closedBy = { tbody = true },
        closedByEnd = { table = true },
    },

    option = {
        closedBy = { option = true, optgroup = true },
        closedByEnd = { select = true, datalist = true, optgroup = true },
    },

    optgroup = {
        closedBy = { optgroup = true },
        closedByEnd = { select = true, datalist = true },
    },

    caption = {
        closedBy = {
            colgroup = true,
            thead = true,
            tbody = true,
            tfoot = true,
            tr = true,
        },
        closedByEnd = { table = true },
    },

    colgroup = {
        closedBy = { thead = true, tbody = true, tfoot = true, tr = true },
        closedByEnd = { table = true },
    },

    rp = {
        closedBy = { rp = true, rt = true },
        closedByEnd = { ruby = true },
    },

    rt = {
        closedBy = { rp = true, rt = true },
        closedByEnd = { ruby = true },
    },

    head = {
        closedBy = { body = true },
        closedByEnd = { html = true },
    },

    body = {
        closedBy = {},
        closedByEnd = { html = true },
    },
}

--- NODE

local Node = {}
Node.__index = Node

function Node.new(nodeType)
    local self = setmetatable({}, Node)

    self.nodeType = nodeType
    self.nodeName = ""
    self.nodeValue = nil
    self.parentNode = nil
    self.childNodes = {}
    self.attributes = {}

    -- computed
    self.firstChild = nil
    self.lastChild = nil
    self.previousSibling = nil
    self.nextSibling = nil

    -- element-specific
    self.tagName = nil
    self.id = nil
    self.className = nil
    self.classList = {}

    -- position
    self.line = nil
    self.column = nil

    -- token reference (adoption agency)
    self._token = nil

    return self
end

function Node.createDocument()
    local doc = Node.new(NodeType.DOCUMENT)
    doc.nodeName = "#document"
    doc.doctype = nil
    doc.documentElement = nil
    doc.head = nil
    doc.body = nil
    return doc
end

function Node.createElement(tagName, attributes, token)
    local elem = Node.new(NodeType.ELEMENT)

    tagName = tagName:lower()
    elem.tagName = tagName
    elem.nodeName = tagName:upper()
    elem.attributes = attributes or {}
    elem._token = token

    -- extract id and class
    if elem.attributes.id then
        elem.id = elem.attributes.id
    end

    if elem.attributes.class then
        elem.className = elem.attributes.class
        for class in elem.attributes.class:gmatch("%S+") do
            table.insert(elem.classList, class)
        end
    end

    -- mark void elements
    elem.isVoid = VOID_ELEMENTS[tagName] or false

    return elem
end

function Node.createText(content)
    local text = Node.new(NodeType.TEXT)
    text.nodeName = "#text"
    text.nodeValue = content
    text.textContent = content
    return text
end

function Node.createComment(content)
    local comment = Node.new(NodeType.COMMENT)
    comment.nodeName = "#comment"
    comment.nodeValue = content
    return comment
end

function Node.createDoctype(value)
    local doctype = Node.new(NodeType.DOCTYPE)
    doctype.nodeName = "html"
    doctype.nodeValue = value
    doctype.name = value:match("^%s*(%S+)") or "html"
    return doctype
end

function Node.createCDATA(content)
    local cdata = Node.new(NodeType.CDATA)
    cdata.nodeName = "#cdata-section"
    cdata.nodeValue = content
    return cdata
end

--- METHODS

function Node:_updateChildReferences()
    local children = self.childNodes
    local count = #children

    self.firstChild = children[1] or nil
    self.lastChild = children[count] or nil

    for i, child in ipairs(children) do
        child.previousSibling = children[i - 1] or nil
        child.nextSibling = children[i + 1] or nil
    end
end

function Node:appendChild(child)
    if child.parentNode then
        child.parentNode:removeChild(child)
    end

    child.parentNode = self
    table.insert(self.childNodes, child)

    self:_updateChildReferences()

    -- update document references
    if self.nodeType == NodeType.DOCUMENT then
        if child.nodeType == NodeType.DOCTYPE then
            self.doctype = child
        elseif child.tagName == "html" then
            self.documentElement = child
        end
    end

    return child
end

function Node:insertBefore(newChild, refChild)
    if not refChild then
        return self:appendChild(newChild)
    end

    if newChild.parentNode then
        newChild.parentNode:removeChild(newChild)
    end

    newChild.parentNode = self

    for i, child in ipairs(self.childNodes) do
        if child == refChild then
            table.insert(self.childNodes, i, newChild)
            self:_updateChildReferences()
            return newChild
        end
    end

    -- not found -> append
    return self:appendChild(newChild)
end

function Node:removeChild(child)
    for i, node in ipairs(self.childNodes) do
        if node == child then
            table.remove(self.childNodes, i)
            child.parentNode = nil
            self:_updateChildReferences()
            return child
        end
    end

    return nil
end

function Node:replaceChild(newChild, oldChild)
    for i, node in ipairs(self.childNodes) do
        if node == oldChild then
            if newChild.parentNode then
                newChild.parentNode:removeChild(newChild)
            end

            newChild.parentNode = self
            self.childNodes[i] = newChild
            oldChild.parentNode = nil

            self:_updateChildReferences()
            return oldChild
        end
    end

    return nil
end

function Node:hasChildNodes()
    return #self.childNodes > 0
end

function Node:cloneNode(deep)
    local clone

    if self.nodeType == NodeType.ELEMENT then
        local attrsCopy = table.clone(self.attributes)
        clone = Node.createElement(self.tagName, attrsCopy, self._token)
    elseif self.nodeType == NodeType.TEXT then
        clone = Node.createText(self.nodeValue)
    elseif self.nodeType == NodeType.COMMENT then
        clone = Node.createComment(self.nodeValue)
    elseif self.nodeType == NodeType.DOCTYPE then
        clone = Node.createDoctype(self.nodeValue or "html")
    elseif self.nodeType == NodeType.CDATA then
        clone = Node.createCDATA(self.nodeValue)
    elseif self.nodeType == NodeType.DOCUMENT then
        clone = Node.createDocument()
    else
        clone = Node.new(self.nodeType)
    end

    if deep then
        for _, child in ipairs(self.childNodes) do
            clone:appendChild(child:cloneNode(true))
        end
    end

    return clone
end

function Node:getAttribute(name)
    if self.nodeType ~= NodeType.ELEMENT then
        return nil
    end

    return self.attributes[name:lower()]
end

function Node:setAttribute(name, value)
    if self.nodeType ~= NodeType.ELEMENT then
        return
    end

    name = name:lower()
    self.attributes[name] = value

    if name == "id" then
        self.id = value
    elseif name == "class" then
        self.className = value
        self.classList = {}
        for class in value:gmatch("%S+") do
            table.insert(self.classList, class)
        end
    end
end

function Node:removeAttribute(name)
    if self.nodeType ~= NodeType.ELEMENT then
        return
    end

    name = name:lower()
    self.attributes[name] = nil

    if name == "id" then
        self.id = nil
    elseif name == "class" then
        self.className = nil
        self.classList = {}
    end
end

function Node:hasAttribute(name)
    if self.nodeType ~= NodeType.ELEMENT then
        return false
    end

    return self.attributes[name:lower()] ~= nil
end

function Node:hasClass(className)
    for _, class in ipairs(self.classList) do
        if class == className then
            return true
        end
    end

    return false
end

function Node:getTextContent()
    if self.nodeType == NodeType.TEXT or self.nodeType == NodeType.CDATA then
        return self.nodeValue or ""
    end

    if
        self.nodeType == NodeType.COMMENT
        or self.nodeType == NodeType.DOCTYPE
    then
        return ""
    end

    local parts = {}
    for _, child in ipairs(self.childNodes) do
        table.insert(parts, child:getTextContent())
    end

    return table.concat(parts)
end

function Node:setTextContent(text)
    self.childNodes = {}
    self.firstChild = nil
    self.lastChild = nil

    if text and text ~= "" then
        self:appendChild(Node.createText(text))
    end
end

function Node:getInnerHTML()
    local parts = {}

    for _, child in ipairs(self.childNodes) do
        table.insert(parts, child:getOuterHTML())
    end

    return table.concat(parts)
end

function Node:getOuterHTML()
    if self.nodeType == NodeType.TEXT then
        local text = self.nodeValue or ""
        text = text:gsub("&", "&amp;")
        text = text:gsub("<", "&lt;")
        text = text:gsub(">", "&gt;")
        return text
    end

    if self.nodeType == NodeType.COMMENT then
        return "<!--" .. (self.nodeValue or "") .. "-->"
    end

    if self.nodeType == NodeType.DOCTYPE then
        return "<!DOCTYPE " .. (self.name or "html") .. ">"
    end

    if self.nodeType == NodeType.CDATA then
        return "<![CDATA[" .. (self.nodeValue or "") .. "]]>"
    end

    if self.nodeType == NodeType.DOCUMENT then
        return self:getInnerHTML()
    end

    if self.nodeType ~= NodeType.ELEMENT then
        return ""
    end

    -- element serialization
    local parts = { "<", self.tagName }

    -- add attributes
    for name, value in pairs(self.attributes) do
        if value == true then
            table.insert(parts, " ")
            table.insert(parts, name)
        else
            table.insert(parts, " ")
            table.insert(parts, name)
            table.insert(parts, '="')
            local escaped = tostring(value):gsub('"', "&quot;")
            table.insert(parts, escaped)
            table.insert(parts, '"')
        end
    end

    table.insert(parts, ">")

    if self.isVoid then
        return table.concat(parts)
    end

    table.insert(parts, self:getInnerHTML())

    table.insert(parts, "</")
    table.insert(parts, self.tagName)
    table.insert(parts, ">")

    return table.concat(parts)
end

--- QUERY

function Node:getElementById(id)
    if self.id == id then
        return self
    end

    for _, child in ipairs(self.childNodes) do
        local found = child:getElementById(id)
        if found then
            return found
        end
    end

    return nil
end

function Node:getElementsByTagName(tagName, results)
    results = results or {}
    tagName = tagName:lower()
    local matchAll = (tagName == "*")

    if self.nodeType == NodeType.ELEMENT then
        if matchAll or self.tagName == tagName then
            table.insert(results, self)
        end
    end

    for _, child in ipairs(self.childNodes) do
        child:getElementsByTagName(tagName, results)
    end

    return results
end

function Node:getElementsByClassName(className, results)
    results = results or {}

    if self.nodeType == NodeType.ELEMENT and self:hasClass(className) then
        table.insert(results, self)
    end

    for _, child in ipairs(self.childNodes) do
        child:getElementsByClassName(className, results)
    end

    return results
end

function Node:querySelector(selector)
    local results = self:querySelectorAll(selector)
    return results[1]
end

function Node:querySelectorAll(selector)
    local results = {}

    local tagName = selector:match("^([%w%-]+)")
    local id = selector:match("#([%w%-_]+)")
    local classes = {}

    for class in selector:gmatch("%.([%w%-_]+)") do
        table.insert(classes, class)
    end

    self:_querySelectorRecursive(tagName, id, classes, results)

    return results
end

function Node:_querySelectorRecursive(tagName, id, classes, results)
    if self.nodeType == NodeType.ELEMENT then
        local matches = true

        if tagName and self.tagName ~= tagName:lower() then
            matches = false
        end

        if matches and id and self.id ~= id then
            matches = false
        end

        if matches then
            for _, class in ipairs(classes) do
                if not self:hasClass(class) then
                    matches = false
                    break
                end
            end
        end

        if matches then
            table.insert(results, self)
        end
    end

    for _, child in ipairs(self.childNodes) do
        child:_querySelectorRecursive(tagName, id, classes, results)
    end
end

function Node:closest(selector)
    local current = self

    while current do
        if current.nodeType == NodeType.ELEMENT then
            if current:matches(selector) then
                return current
            end
        end
        current = current.parentNode
    end

    return nil
end

function Node:matches(selector)
    if self.nodeType ~= NodeType.ELEMENT then
        return false
    end

    local tagName = selector:match("^([%w%-]+)")
    local id = selector:match("#([%w%-_]+)")
    local classes = {}

    for class in selector:gmatch("%.([%w%-_]+)") do
        table.insert(classes, class)
    end

    if tagName and self.tagName ~= tagName:lower() then
        return false
    end

    if id and self.id ~= id then
        return false
    end

    for _, class in ipairs(classes) do
        if not self:hasClass(class) then
            return false
        end
    end

    return true
end

function Node:getAncestors()
    local ancestors = {}
    local current = self.parentNode

    while current and current.nodeType ~= NodeType.DOCUMENT do
        table.insert(ancestors, current)
        current = current.parentNode
    end

    return ancestors
end

function Node:contains(node)
    if node == self then
        return true
    end

    for _, child in ipairs(self.childNodes) do
        if child:contains(node) then
            return true
        end
    end

    return false
end

function Node:getIndex()
    if not self.parentNode then
        return nil
    end

    for i, child in ipairs(self.parentNode.childNodes) do
        if child == self then
            return i
        end
    end

    return nil
end

--- PARSER

local Parser = {}
Parser.__index = Parser

function Parser.new(tokens, tokenTypes)
    local self = setmetatable({}, Parser)

    -- input
    self.tokens = tokens or {}
    self.tokenTypes = tokenTypes or {}
    self.position = 1

    -- document structure
    self.document = nil
    self.openElements = {}

    -- active formatting list
    self.activeFormattingElements = {}

    -- special element references
    self.htmlElement = nil
    self.headElement = nil
    self.bodyElement = nil

    -- configuration
    self.yieldInterval = 200
    self.preserveComments = false
    self.preserveWhitespace = false

    -- parsing state
    self.insertionMode = "initial"
    self.framesetOk = true
    self.fosterParenting = false

    return self
end

--- CONFIG

function Parser:setPreserveComments(preserve)
    self.preserveComments = preserve
end

function Parser:setPreserveWhitespace(preserve)
    self.preserveWhitespace = preserve
end

function Parser:setYieldInterval(interval)
    self.yieldInterval = interval
end

--- CURSOR

function Parser:currentToken()
    return self.tokens[self.position]
end

function Parser:peekToken(offset)
    offset = offset or 1
    return self.tokens[self.position + offset]
end

function Parser:advance()
    self.position = self.position + 1
end

function Parser:isAtEnd()
    local token = self:currentToken()
    return token == nil or token.type == self.tokenTypes.EOF
end

--- STACK

function Parser:currentElement()
    return self.openElements[#self.openElements]
end

function Parser:getElementAt(index)
    return self.openElements[index]
end

function Parser:pushElement(element)
    table.insert(self.openElements, element)
end

function Parser:popElement()
    return table.remove(self.openElements)
end

function Parser:removeFromStack(element)
    for i = #self.openElements, 1, -1 do
        if self.openElements[i] == element then
            table.remove(self.openElements, i)
            return
        end
    end
end

function Parser:hasInStack(tagName)
    for i = #self.openElements, 1, -1 do
        if self.openElements[i].tagName == tagName then
            return true
        end
    end

    return false
end

function Parser:getStackIndex(tagName)
    for i = #self.openElements, 1, -1 do
        if self.openElements[i].tagName == tagName then
            return i
        end
    end

    return nil
end

function Parser:getStackIndexOf(element)
    for i = #self.openElements, 1, -1 do
        if self.openElements[i] == element then
            return i
        end
    end

    return nil
end

function Parser:insertInStackAt(index, element)
    table.insert(self.openElements, index, element)
end

function Parser:replaceInStack(oldElement, newElement)
    for i = 1, #self.openElements do
        if self.openElements[i] == oldElement then
            self.openElements[i] = newElement
            return
        end
    end
end

function Parser:hasInScope(tagName, scopeMarkers)
    scopeMarkers = scopeMarkers or SCOPE_MARKERS

    for i = #self.openElements, 1, -1 do
        local elem = self.openElements[i]
        if elem.tagName == tagName then
            return true
        end
        if scopeMarkers[elem.tagName] then
            return false
        end
    end

    return false
end

function Parser:hasInListItemScope(tagName)
    return self:hasInScope(tagName, LIST_SCOPE_MARKERS)
end

function Parser:hasInButtonScope(tagName)
    return self:hasInScope(tagName, BUTTON_SCOPE_MARKERS)
end

function Parser:hasInTableScope(tagName)
    return self:hasInScope(tagName, TABLE_SCOPE_MARKERS)
end

function Parser:hasInSelectScope(tagName)
    for i = #self.openElements, 1, -1 do
        local elem = self.openElements[i]
        if elem.tagName == tagName then
            return true
        end
        if not SELECT_SCOPE_MARKERS[elem.tagName] then
            return false
        end
    end

    return false
end

function Parser:popUntil(tagName)
    while #self.openElements > 0 do
        local elem = self:popElement()
        if elem.tagName == tagName then
            break
        end
    end
end

function Parser:popUntilOneOf(tagSet)
    while #self.openElements > 0 do
        local elem = self:popElement()
        if tagSet[elem.tagName] then
            break
        end
    end
end

function Parser:generateImpliedEndTags(exclude)
    local implied = {
        dd = true,
        dt = true,
        li = true,
        optgroup = true,
        option = true,
        p = true,
        rb = true,
        rp = true,
        rt = true,
        rtc = true,
    }

    while #self.openElements > 0 do
        local current = self:currentElement()
        if
            current
            and implied[current.tagName]
            and current.tagName ~= exclude
        then
            self:popElement()
        else
            break
        end
    end
end

function Parser:generateImpliedEndTagsThoroughly()
    local implied = {
        caption = true,
        colgroup = true,
        dd = true,
        dt = true,
        li = true,
        optgroup = true,
        option = true,
        p = true,
        rb = true,
        rp = true,
        rt = true,
        rtc = true,
        tbody = true,
        td = true,
        tfoot = true,
        th = true,
        thead = true,
        tr = true,
    }

    while #self.openElements > 0 do
        local current = self:currentElement()
        if current and implied[current.tagName] then
            self:popElement()
        else
            break
        end
    end
end

--- FORMATTING

function Parser:pushActiveFormattingElement(element)
    local matchCount = 0
    local removeIndex = nil

    for i = #self.activeFormattingElements, 1, -1 do
        local entry = self.activeFormattingElements[i]

        -- stop at markers
        if entry == SCOPE_MARKER then
            break
        end

        -- same tag and attributes?
        if entry.tagName == element.tagName then
            local sameAttrs = true

            -- compare attributes
            for name, value in pairs(element.attributes) do
                if entry.attributes[name] ~= value then
                    sameAttrs = false
                    break
                end
            end

            if sameAttrs then
                for name, _ in pairs(entry.attributes) do
                    if element.attributes[name] == nil then
                        sameAttrs = false
                        break
                    end
                end
            end

            if sameAttrs then
                matchCount = matchCount + 1
                if matchCount >= 3 then
                    removeIndex = i
                end
            end
        end
    end

    if removeIndex then
        table.remove(self.activeFormattingElements, removeIndex)
    end

    table.insert(self.activeFormattingElements, element)
end

function Parser:pushActiveFormattingMarker()
    table.insert(self.activeFormattingElements, SCOPE_MARKER)
end

function Parser:removeFromActiveFormatting(element)
    for i = #self.activeFormattingElements, 1, -1 do
        if self.activeFormattingElements[i] == element then
            table.remove(self.activeFormattingElements, i)
            return
        end
    end
end

function Parser:getActiveFormattingIndex(element)
    for i = #self.activeFormattingElements, 1, -1 do
        if self.activeFormattingElements[i] == element then
            return i
        end
    end

    return nil
end

function Parser:getActiveFormattingElement(tagName)
    for i = #self.activeFormattingElements, 1, -1 do
        local entry = self.activeFormattingElements[i]

        if entry == SCOPE_MARKER then
            return nil, nil
        end

        if entry.tagName == tagName then
            return entry, i
        end
    end

    return nil, nil
end

function Parser:clearActiveFormattingToMarker()
    while #self.activeFormattingElements > 0 do
        local entry = table.remove(self.activeFormattingElements)
        if entry == SCOPE_MARKER then
            break
        end
    end
end

function Parser:reconstructActiveFormatting()
    if #self.activeFormattingElements == 0 then
        return
    end

    local lastEntry =
        self.activeFormattingElements[#self.activeFormattingElements]

    if lastEntry == SCOPE_MARKER then
        return
    end

    if self:getStackIndexOf(lastEntry) then
        return
    end

    -- step backwards
    local entryIndex = #self.activeFormattingElements

    while entryIndex > 1 do
        entryIndex = entryIndex - 1
        local entry = self.activeFormattingElements[entryIndex]

        if entry == SCOPE_MARKER or self:getStackIndexOf(entry) then
            entryIndex = entryIndex + 1
            break
        end
    end

    -- reconstruct forward
    while entryIndex <= #self.activeFormattingElements do
        local entry = self.activeFormattingElements[entryIndex]

        if entry ~= SCOPE_MARKER then
            -- new element with the same token
            local newElement = Node.createElement(
                entry.tagName,
                self:copyAttributes(entry.attributes),
                entry._token
            )

            -- insert into tree
            self:insertElement(newElement)

            -- replace in the list
            self.activeFormattingElements[entryIndex] = newElement
        end

        entryIndex = entryIndex + 1
    end
end

function Parser:copyAttributes(attrs)
    return table.clone(attrs)
end

--- ADOPTION

function Parser:isSpecialElement(tagName)
    return SPECIAL_ELEMENTS[tagName] or false
end

function Parser:isFormattingElement(tagName)
    return FORMATTING_ELEMENTS[tagName] or false
end

function Parser:runAdoptionAgency(tagName)
    if not FORMATTING_ELEMENTS[tagName] then
        return false
    end

    local outerLoopCounter = 0

    while outerLoopCounter < 8 do
        outerLoopCounter = outerLoopCounter + 1

        local formattingElement, formattingListIndex =
            self:getActiveFormattingElement(tagName)

        if not formattingElement then
            -- not found -> let "any other end tag" handle it
            return false
        end

        local formattingStackIndex = self:getStackIndexOf(formattingElement)

        if not formattingStackIndex then
            -- parse error -> remove from the list
            self:removeFromActiveFormatting(formattingElement)
            return true
        end

        if not self:hasInScope(tagName) then
            return true
        end

        local furthestBlock = nil
        local furthestBlockIndex = nil

        for i = formattingStackIndex + 1, #self.openElements do
            local elem = self.openElements[i]
            if self:isSpecialElement(elem.tagName) then
                furthestBlock = elem
                furthestBlockIndex = i
                break
            end
        end

        if not furthestBlock then
            -- pop up to the formatting element
            while #self.openElements >= formattingStackIndex do
                self:popElement()
            end

            -- remove from the list
            self:removeFromActiveFormatting(formattingElement)

            return true
        end

        local commonAncestor = self.openElements[formattingStackIndex - 1]

        local bookmark = formattingListIndex

        local node = furthestBlock
        local nodeStackIndex = furthestBlockIndex
        local lastNode = furthestBlock

        local innerLoopCounter = 0

        while true do
            innerLoopCounter = innerLoopCounter + 1
            nodeStackIndex = nodeStackIndex - 1
            node = self.openElements[nodeStackIndex]

            if node == formattingElement then
                break
            end

            local nodeFormattingIndex = self:getActiveFormattingIndex(node)

            if innerLoopCounter > 3 and nodeFormattingIndex then
                self:removeFromActiveFormatting(node)
                nodeFormattingIndex = nil
            end

            if not nodeFormattingIndex then
                self:removeFromStack(node)
            else
                local newElement = Node.createElement(
                    node.tagName,
                    self:copyAttributes(node.attributes),
                    node._token
                )
                newElement.line = node.line
                newElement.column = node.column

                self.activeFormattingElements[nodeFormattingIndex] = newElement

                self.openElements[nodeStackIndex] = newElement

                node = newElement

                if lastNode == furthestBlock then
                    bookmark = nodeFormattingIndex + 1
                end

                if lastNode.parentNode then
                    lastNode.parentNode:removeChild(lastNode)
                end
                node:appendChild(lastNode)

                lastNode = node
            end
        end

        if lastNode.parentNode then
            lastNode.parentNode:removeChild(lastNode)
        end

        self:insertNodeAtAppropriatePlace(lastNode, commonAncestor)

        local newFormattingElement = Node.createElement(
            formattingElement.tagName,
            self:copyAttributes(formattingElement.attributes),
            formattingElement._token
        )
        newFormattingElement.line = formattingElement.line
        newFormattingElement.column = formattingElement.column

        while #furthestBlock.childNodes > 0 do
            local child = furthestBlock.childNodes[1]
            furthestBlock:removeChild(child)
            newFormattingElement:appendChild(child)
        end

        furthestBlock:appendChild(newFormattingElement)

        self:removeFromActiveFormatting(formattingElement)

        if bookmark > #self.activeFormattingElements + 1 then
            bookmark = #self.activeFormattingElements + 1
        end

        table.insert(
            self.activeFormattingElements,
            bookmark,
            newFormattingElement
        )

        self:removeFromStack(formattingElement)

        -- insert below furthest block
        local furthestBlockStackIndex = self:getStackIndexOf(furthestBlock)
        if furthestBlockStackIndex then
            self:insertInStackAt(
                furthestBlockStackIndex + 1,
                newFormattingElement
            )
        else
            self:pushElement(newFormattingElement)
        end
    end

    return true
end

function Parser:insertNodeAtAppropriatePlace(node, overrideTarget)
    local target = overrideTarget or self:currentElement()

    if not target then
        if self.document then
            self.document:appendChild(node)
        end
        return
    end

    -- check foster parenting
    if self.fosterParenting then
        self:fosterParent(node)
        return
    end

    -- normal case: append
    target:appendChild(node)
end

--- FOSTER

function Parser:isInTableContext()
    for i = #self.openElements, 1, -1 do
        local tag = self.openElements[i].tagName
        if tag == "table" then
            return true
        end
        if tag == "html" then
            return false
        end
    end

    return false
end

function Parser:isTableContent(tagName)
    return TABLE_ELEMENTS[tagName] or false
end

function Parser:isTableSection(tagName)
    return TABLE_SECTIONS[tagName] or false
end

function Parser:isTableCell(tagName)
    return TABLE_CELLS[tagName] or false
end

function Parser:isRawTextElement(tagName)
    return RAW_TEXT_ELEMENTS[tagName] or false
end

function Parser:getFosterParentTarget()
    -- find the last table in the stack
    local lastTableIndex = nil
    local lastTable = nil

    for i = #self.openElements, 1, -1 do
        if self.openElements[i].tagName == "table" then
            lastTableIndex = i
            lastTable = self.openElements[i]
            break
        end
    end

    if not lastTable then
        -- no table -> last element, body, or html
        return self:currentElement() or self.bodyElement or self.htmlElement,
            nil
    end

    -- foster parent = element before the table
    if lastTableIndex > 1 then
        local parent = self.openElements[lastTableIndex - 1]
        return parent, lastTable
    end

    -- else the table's parent
    if lastTable.parentNode then
        return lastTable.parentNode, lastTable
    end

    -- fallback
    return self.document, nil
end

function Parser:fosterParent(node)
    local parent, insertBefore = self:getFosterParentTarget()

    if insertBefore and insertBefore.parentNode == parent then
        parent:insertBefore(node, insertBefore)
    else
        parent:appendChild(node)
    end
end

function Parser:shouldFosterParentText()
    local current = self:currentElement()
    if not current then
        return false
    end

    local tag = current.tagName
    return tag == "table"
        or tag == "tbody"
        or tag == "thead"
        or tag == "tfoot"
        or tag == "tr"
end

--- INSERT

function Parser:insertElement(element)
    -- foster parenting
    if self.fosterParenting then
        self:fosterParent(element)
    else
        local parent = self:currentElement()

        if parent then
            parent:appendChild(element)
        elseif self.document then
            self.document:appendChild(element)
        end
    end

    -- track special elements
    if element.tagName == "html" then
        self.htmlElement = element
        if self.document then
            self.document.documentElement = element
        end
    elseif element.tagName == "head" then
        self.headElement = element
        if self.document then
            self.document.head = element
        end
    elseif element.tagName == "body" then
        self.bodyElement = element
        if self.document then
            self.document.body = element
        end
    end

    -- push non-void elements
    if not element.isVoid then
        self:pushElement(element)
    end

    -- add formatting elements
    if FORMATTING_ELEMENTS[element.tagName] then
        self:pushActiveFormattingElement(element)
    end
end

function Parser:insertText(content)
    -- skip whitespace-only text
    if not self.preserveWhitespace and not content:match("%S") then
        -- but allow it in certain contexts
        local current = self:currentElement()
        if current then
            local tag = current.tagName
            if
                tag ~= "pre"
                and tag ~= "textarea"
                and tag ~= "script"
                and tag ~= "style"
            then
                return
            end
        else
            return
        end
    end

    self:reconstructActiveFormatting()

    if self:shouldFosterParentText() then
        if content:match("%S") then
            local textNode = Node.createText(content)
            self:fosterParent(textNode)
        end
        return
    end

    local parent = self:currentElement() or self.document
    if not parent then
        return
    end

    -- merge with previous text node
    local lastChild = parent.lastChild
    if lastChild and lastChild.nodeType == NodeType.TEXT then
        lastChild.nodeValue = lastChild.nodeValue .. content
        lastChild.textContent = lastChild.nodeValue
    else
        local textNode = Node.createText(content)
        parent:appendChild(textNode)
    end
end

function Parser:insertComment(content)
    if not self.preserveComments then
        return
    end

    local parent = self:currentElement() or self.document
    if parent then
        local comment = Node.createComment(content)
        parent:appendChild(comment)
    end
end

--- CLOSING

function Parser:closeImplicitlyBeforeOpen(tagName)
    while #self.openElements > 0 do
        local current = self:currentElement()
        if not current then
            break
        end

        local rules = IMPLICIT_CLOSE_RULES[current.tagName]
        if rules and rules.closedBy and rules.closedBy[tagName] then
            self:popElement()
        else
            break
        end
    end

    -- nested headings
    if HEADING_ELEMENTS[tagName] then
        local current = self:currentElement()
        if current and HEADING_ELEMENTS[current.tagName] then
            self:popElement()
        end
    end

    -- <li>
    if tagName == "li" then
        self:closeImplicitlyForListItem()
    end

    -- <dt> / <dd>
    if tagName == "dt" or tagName == "dd" then
        self:closeImplicitlyForDefinitionListItem()
    end
end

function Parser:closeImplicitlyForListItem()
    for i = #self.openElements, 1, -1 do
        local elem = self.openElements[i]

        if elem.tagName == "li" then
            while #self.openElements >= i do
                self:popElement()
            end
            break
        elseif
            SPECIAL_ELEMENTS[elem.tagName] and not LIST_CONTAINERS[elem.tagName]
        then
            break
        end
    end
end

function Parser:closeImplicitlyForDefinitionListItem()
    for i = #self.openElements, 1, -1 do
        local elem = self.openElements[i]

        if DL_ELEMENTS[elem.tagName] then
            while #self.openElements >= i do
                self:popElement()
            end
            break
        elseif SPECIAL_ELEMENTS[elem.tagName] and elem.tagName ~= "dl" then
            break
        end
    end
end

function Parser:closeImplicitlyForEndTag(tagName)
    self:generateImpliedEndTags(tagName)

    for i = #self.openElements, 1, -1 do
        local elem = self.openElements[i]
        local rules = IMPLICIT_CLOSE_RULES[elem.tagName]

        if rules and rules.closedByEnd and rules.closedByEnd[tagName] then
            while #self.openElements >= i do
                self:popElement()
            end
        end
    end
end

--- PROCESS

function Parser:processDoctype(token)
    local doctype = Node.createDoctype(token.value or "html")
    doctype.line = token.line
    doctype.column = token.column

    if self.document then
        self.document.doctype = doctype
        self.document:appendChild(doctype)
    end
end

function Parser:processComment(token)
    self:insertComment(token.value)
end

function Parser:processStartTag(token)
    local tagName = token.tagName
    local attributes = token.attributes or {}

    -- ensure <html> exists
    if not self.htmlElement and tagName ~= "html" then
        self:ensureHtmlElement()
    end

    -- <html>
    if tagName == "html" then
        if not self.htmlElement then
            local html = Node.createElement("html", attributes, token)
            html.line = token.line
            html.column = token.column

            self.document:appendChild(html)
            self.htmlElement = html
            self.document.documentElement = html
            self:pushElement(html)
        else
            for name, value in pairs(attributes) do
                if not self.htmlElement.attributes[name] then
                    self.htmlElement:setAttribute(name, value)
                end
            end
        end
        return
    end

    -- <head>
    if tagName == "head" then
        if not self.headElement then
            self:ensureHtmlElement()

            local head = Node.createElement("head", attributes, token)
            head.line = token.line
            head.column = token.column

            self.htmlElement:appendChild(head)
            self.headElement = head
            self.document.head = head
            self:pushElement(head)
        end
        return
    end

    -- <body>
    if tagName == "body" then
        if not self.bodyElement then
            self:ensureHtmlElement()

            -- ensure head exists first
            if not self.headElement then
                local head = Node.createElement("head")
                self.htmlElement:appendChild(head)
                self.headElement = head
                self.document.head = head
            end

            self:closeHeadIfOpen()

            local body = Node.createElement("body", attributes, token)
            body.line = token.line
            body.column = token.column

            self.htmlElement:appendChild(body)
            self.bodyElement = body
            self.document.body = body
            self:pushElement(body)
        else
            -- merge attributes into existing <body>
            for name, value in pairs(attributes) do
                if not self.bodyElement.attributes[name] then
                    self.bodyElement:setAttribute(name, value)
                end
            end
        end
        return
    end

    -- where to insert
    if HEAD_ELEMENTS[tagName] and not self.bodyElement then
        self:ensureHeadElement()
    elseif not HEAD_ELEMENTS[tagName] or self.bodyElement then
        self:ensureBodyElement()
    end

    -- reconstruct formatting first
    if not SPECIAL_ELEMENTS[tagName] or FORMATTING_ELEMENTS[tagName] then
        self:reconstructActiveFormatting()
    end

    -- implicit closing
    self:closeImplicitlyBeforeOpen(tagName)

    -- <a>
    if tagName == "a" then
        local existingAnchor, _ = self:getActiveFormattingElement("a")
        if existingAnchor then
            -- run adoption agency on it
            self:runAdoptionAgency("a")
            -- remove from list and stack
            self:removeFromActiveFormatting(existingAnchor)
            self:removeFromStack(existingAnchor)
        end
    end

    -- <button>
    if tagName == "button" then
        if self:hasInScope("button") then
            self:generateImpliedEndTags()
            self:popUntil("button")
        end
    end

    -- <table>
    if tagName == "table" then
        self:pushActiveFormattingMarker()
    end

    -- table cells and rows
    if self:isTableCell(tagName) then
        if self:hasInTableScope("td") then
            self:closeImplicitlyForEndTag("td")
            self:popUntil("td")
        elseif self:hasInTableScope("th") then
            self:closeImplicitlyForEndTag("th")
            self:popUntil("th")
        end
    end

    if tagName == "tr" then
        if self:hasInTableScope("tr") then
            self:clearActiveFormattingToMarker()
            self:popUntil("tr")
        end
    end

    if self:isTableSection(tagName) then
        for _, section in ipairs({ "thead", "tbody", "tfoot" }) do
            if self:hasInTableScope(section) then
                self:clearActiveFormattingToMarker()
                self:popUntil(section)
                break
            end
        end
    end

    -- <applet>/<marquee>/<object>
    if tagName == "applet" or tagName == "marquee" or tagName == "object" then
        self:reconstructActiveFormatting()
        self:pushActiveFormattingMarker()
    end

    -- create and insert
    local element = Node.createElement(tagName, attributes, token)
    element.line = token.line
    element.column = token.column

    self:insertElement(element)
end

function Parser:processEndTag(token)
    local tagName = token.tagName

    -- </html>
    if tagName == "html" then
        return
    end

    -- </head>
    if tagName == "head" then
        if self.headElement and self:hasInStack("head") then
            self:popUntil("head")
        end
        return
    end

    -- </body>
    if tagName == "body" then
        if not self:hasInScope("body") then
            return
        end
        return
    end

    -- formatting elements: adoption agency
    if FORMATTING_ELEMENTS[tagName] then
        if self:runAdoptionAgency(tagName) then
            return
        end
    end

    -- </applet>, </marquee>, </object>
    if tagName == "applet" or tagName == "marquee" or tagName == "object" then
        if self:hasInScope(tagName) then
            self:generateImpliedEndTags()
            self:popUntil(tagName)
            self:clearActiveFormattingToMarker()
        end
        return
    end

    -- </table>
    if tagName == "table" then
        if self:hasInTableScope("table") then
            self:popUntil("table")
            self:clearActiveFormattingToMarker()
        end
        return
    end

    -- table sections
    if TABLE_SECTIONS[tagName] then
        if self:hasInTableScope(tagName) then
            self:clearActiveFormattingToMarker()
            self:popUntil(tagName)
        end
        return
    end

    -- </tr>
    if tagName == "tr" then
        if self:hasInTableScope("tr") then
            self:clearActiveFormattingToMarker()
            self:popUntil("tr")
        end
        return
    end

    -- table cells
    if TABLE_CELLS[tagName] then
        if self:hasInTableScope(tagName) then
            self:generateImpliedEndTags()
            self:popUntil(tagName)
            self:clearActiveFormattingToMarker()
        end
        return
    end

    -- implicit closing
    self:closeImplicitlyForEndTag(tagName)

    -- pop any other end tag
    for i = #self.openElements, 1, -1 do
        local elem = self.openElements[i]

        if elem.tagName == tagName then
            self:generateImpliedEndTags(tagName)

            while #self.openElements >= i do
                self:popElement()
            end
            return
        end

        if self:isSpecialElement(elem.tagName) then
            return
        end
    end
end

function Parser:processText(token)
    local text = token.value

    if not text or text == "" then
        return
    end

    -- inside head context?
    local isInHeadContent = false
    for i = #self.openElements, 1, -1 do
        local tag = self.openElements[i].tagName
        if tag == "head" then
            isInHeadContent = true
            break
        elseif tag == "body" or tag == "html" then
            break
        end
    end

    -- only build body outside head content
    if not isInHeadContent then
        local current = self:currentElement()
        if not current or current.tagName == "html" then
            self:ensureBodyElement()
        end
    end

    self:insertText(text)
end

function Parser:processRawText(token)
    local text = token.value

    if not text or text == "" then
        return
    end

    local parent = self:currentElement()
    if parent then
        local textNode = Node.createText(text)
        parent:appendChild(textNode)
    end
end

function Parser:processCDATA(token)
    local parent = self:currentElement() or self.document
    if parent then
        local cdataNode = Node.createCDATA(token.value)
        cdataNode.line = token.line
        cdataNode.column = token.column
        parent:appendChild(cdataNode)
    end
end

--- HELPERS

function Parser:ensureHtmlElement()
    if not self.htmlElement then
        local html = Node.createElement("html")
        self.document:appendChild(html)
        self.htmlElement = html
        self.document.documentElement = html
        self:pushElement(html)
    end
end

function Parser:ensureHeadElement()
    self:ensureHtmlElement()

    if not self.headElement then
        local head = Node.createElement("head")
        self.htmlElement:appendChild(head)
        self.headElement = head
        self.document.head = head
        self:pushElement(head)
    end
end

function Parser:closeHeadIfOpen()
    if self:hasInStack("head") then
        self:popUntil("head")
    end
end

function Parser:ensureBodyElement()
    self:ensureHtmlElement()

    -- ensure head exists before body
    if not self.headElement then
        local head = Node.createElement("head")
        -- insert head before html's children
        local firstChild = self.htmlElement.firstChild
        if firstChild then
            self.htmlElement:insertBefore(head, firstChild)
        else
            self.htmlElement:appendChild(head)
        end
        self.headElement = head
        self.document.head = head
    end

    self:closeHeadIfOpen()

    if not self.bodyElement then
        local body = Node.createElement("body")
        self.htmlElement:appendChild(body)
        self.bodyElement = body
        self.document.body = body
        self:pushElement(body)
    end
end

function Parser:parse()
    self.document = Node.createDocument()
    self.openElements = {}
    self.activeFormattingElements = {}

    local tokenCount = 0
    local TT = self.tokenTypes

    while not self:isAtEnd() do
        local token = self:currentToken()

        if not token then
            break
        end

        if token.type == TT.DOCTYPE then
            self:processDoctype(token)
        elseif token.type == TT.COMMENT then
            self:processComment(token)
        elseif token.type == TT.START_TAG then
            self:processStartTag(token)
        elseif token.type == TT.END_TAG then
            self:processEndTag(token)
        elseif token.type == TT.TEXT then
            self:processText(token)
        elseif token.type == TT.RAW_TEXT then
            self:processRawText(token)
        elseif token.type == TT.CDATA then
            self:processCDATA(token)
        end

        self:advance()
        tokenCount += 1

        if tokenCount % self.yieldInterval == 1 then
            task.wait()
        end
    end

    -- close remaining elements
    while #self.openElements > 0 do
        self:popElement()
    end

    return self.document
end

--- API

function Parser.getNodeTypes()
    return NodeType
end

function Parser.getNodeClass()
    return Node
end

function Parser.getVoidElements()
    return VOID_ELEMENTS
end

function Parser.getBlockElements()
    return BLOCK_ELEMENTS
end

function Parser.getSpecialElements()
    return SPECIAL_ELEMENTS
end

function Parser.getFormattingElements()
    return FORMATTING_ELEMENTS
end

function Parser.parseTokens(tokens, tokenTypes, options)
    local parser = Parser.new(tokens, tokenTypes)

    if options then
        if options.preserveComments then
            parser:setPreserveComments(true)
        end
        if options.preserveWhitespace then
            parser:setPreserveWhitespace(true)
        end
        if options.yieldInterval then
            parser:setYieldInterval(options.yieldInterval)
        end
    end

    return parser:parse()
end

function Parser.create(tokens, tokenTypes, options)
    local parser = Parser.new(tokens, tokenTypes)

    if options then
        if options.preserveComments then
            parser:setPreserveComments(true)
        end
        if options.preserveWhitespace then
            parser:setPreserveWhitespace(true)
        end
        if options.yieldInterval then
            parser:setYieldInterval(options.yieldInterval)
        end
    end

    return parser
end

function Parser.parseHTML(html, Lexer, options)
    options = options or {}

    local lexer = Lexer.new(html)

    if options.skipWhitespaceOnlyText then
        lexer:setSkipWhitespaceOnlyText(true)
    end

    local tokens = lexer:tokenize()
    local tokenTypes = Lexer.getTokenTypes()

    return Parser.parseTokens(tokens, tokenTypes, options)
end

return Parser

-- EOF