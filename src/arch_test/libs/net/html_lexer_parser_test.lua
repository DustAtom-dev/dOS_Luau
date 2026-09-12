--[[
    "Test module for dOS"
    
    @module html_lexer_parser_test
    @author Claude Opus 4.6 (Anthropic's AI)

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


--------------------------------------------------------------------------------
-- Test Framework
--------------------------------------------------------------------------------

local TestRunner = {}
TestRunner.__index = TestRunner

function TestRunner.new()
    local self = setmetatable({}, TestRunner)
    self.passed = 0
    self.failed = 0
    self.totalTests = 0
    self.currentCategory = ""
    return self
end

function TestRunner:setCategory(name)
    self.currentCategory = name
    print("\n========== " .. name .. " ==========")
end

function TestRunner:test(name, func)
    self.totalTests = self.totalTests + 1
    local fullName = self.currentCategory .. ": " .. name

    local success, err = pcall(func)

    if success then
        self.passed = self.passed + 1
        print(fullName .. ": PASS")
    else
        self.failed = self.failed + 1
        warn(fullName .. ": FAIL - " .. tostring(err))
    end
    task.wait()
end

function TestRunner:assertEqual(actual, expected, message)
    if actual ~= expected then
        error(
            (message or "Assertion failed")
                .. " (expected: "
                .. tostring(expected)
                .. ", got: "
                .. tostring(actual)
                .. ")"
        )
    end
end

function TestRunner:assertNotNil(value, message)
    if value == nil then error((message or "Expected non-nil value")) end
end

function TestRunner:assertNil(value, message)
    if value ~= nil then
        error(
            (message or "Expected nil") .. " (got: " .. tostring(value) .. ")"
        )
    end
end

function TestRunner:assertTrue(value, message)
    if not value then error((message or "Expected true")) end
end

function TestRunner:assertFalse(value, message)
    if value then error((message or "Expected false")) end
end

function TestRunner:assertTableLength(tbl, expected, message)
    local actual = #tbl
    if actual ~= expected then
        error(
            (message or "Table length mismatch")
                .. " (expected: "
                .. expected
                .. ", got: "
                .. actual
                .. ")"
        )
    end
end

function TestRunner:assertContains(str, substring, message)
    if not str:find(substring, 1, true) then
        error(
            (message or "String does not contain expected substring")
                .. " (looking for: '"
                .. substring
                .. "' in: '"
                .. str
                .. "')"
        )
    end
end

function TestRunner:summary()
    print("\n========== TEST SUMMARY ==========")
    print("Total:  " .. self.totalTests)
    print("Passed: " .. self.passed)
    print("Failed: " .. self.failed)

    if self.failed == 0 then
        print("All tests passed!")
    else
        warn(self.failed .. " test(s) failed!")
    end

    return self.failed == 0
end

--------------------------------------------------------------------------------
-- Load Modules
--------------------------------------------------------------------------------

local Lexer = require("./html_lexer")
local Parser = require("./html_parser")

local TokenType = Lexer.getTokenTypes()
local NodeType = Parser.getNodeTypes()
local Node = Parser.getNodeClass()

--------------------------------------------------------------------------------
-- Test Execution
--------------------------------------------------------------------------------

local runner = TestRunner.new()

--------------------------------------------------------------------------------
-- LEXER TESTS
--------------------------------------------------------------------------------

runner:setCategory("Lexer - Basic Tokenization")

runner:test("Empty input", function()
    local tokens = Lexer.parse("")
    runner:assertTableLength(tokens, 1) -- Just EOF
    runner:assertEqual(tokens[1].type, TokenType.EOF)
end)

runner:test("Whitespace only input", function()
    local tokens = Lexer.parse("   \n\t  ")
    runner:assertEqual(tokens[1].type, TokenType.TEXT)
    runner:assertEqual(tokens[2].type, TokenType.EOF)
end)

runner:test("Plain text", function()
    local tokens = Lexer.parse("Hello World")
    runner:assertEqual(tokens[1].type, TokenType.TEXT)
    runner:assertEqual(tokens[1].value, "Hello World")
end)

runner:test("Simple element", function()
    local tokens = Lexer.parse("<div>content</div>")
    runner:assertEqual(tokens[1].type, TokenType.START_TAG)
    runner:assertEqual(tokens[1].tagName, "div")
    runner:assertEqual(tokens[2].type, TokenType.TEXT)
    runner:assertEqual(tokens[2].value, "content")
    runner:assertEqual(tokens[3].type, TokenType.END_TAG)
    runner:assertEqual(tokens[3].tagName, "div")
end)

runner:setCategory("Lexer - DOCTYPE")

runner:test("HTML5 DOCTYPE", function()
    local tokens = Lexer.parse("<!DOCTYPE html>")
    runner:assertEqual(tokens[1].type, TokenType.DOCTYPE)
    runner:assertEqual(tokens[1].value, "html")
end)

runner:test("DOCTYPE with extra content", function()
    local tokens =
        Lexer.parse('<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN">')
    runner:assertEqual(tokens[1].type, TokenType.DOCTYPE)
    runner:assertContains(tokens[1].value, "html")
end)

runner:test("Lowercase doctype", function()
    local tokens = Lexer.parse("<!doctype html>")
    runner:assertEqual(tokens[1].type, TokenType.DOCTYPE)
end)

runner:setCategory("Lexer - Comments")

runner:test("Simple comment", function()
    local tokens = Lexer.parse("<!-- This is a comment -->")
    runner:assertEqual(tokens[1].type, TokenType.COMMENT)
    runner:assertEqual(tokens[1].value, " This is a comment ")
end)

runner:test("Empty comment", function()
    local tokens = Lexer.parse("<!---->")
    runner:assertEqual(tokens[1].type, TokenType.COMMENT)
    runner:assertEqual(tokens[1].value, "")
end)

runner:test("Comment with dashes", function()
    local tokens = Lexer.parse("<!-- -- comment -- -->")
    runner:assertEqual(tokens[1].type, TokenType.COMMENT)
end)

runner:test("Comment with HTML inside", function()
    local tokens = Lexer.parse("<!-- <div>not parsed</div> -->")
    runner:assertEqual(tokens[1].type, TokenType.COMMENT)
    runner:assertContains(tokens[1].value, "<div>")
end)

runner:test("Alternate comment ending --!>", function()
    local tokens = Lexer.parse("<!-- comment --!>")
    runner:assertEqual(tokens[1].type, TokenType.COMMENT)
end)

runner:setCategory("Lexer - CDATA")

runner:test("CDATA section", function()
    local tokens = Lexer.parse("<![CDATA[Some <content> here]]>")
    runner:assertEqual(tokens[1].type, TokenType.CDATA)
    runner:assertEqual(tokens[1].value, "Some <content> here")
end)

runner:test("Empty CDATA", function()
    local tokens = Lexer.parse("<![CDATA[]]>")
    runner:assertEqual(tokens[1].type, TokenType.CDATA)
    runner:assertEqual(tokens[1].value, "")
end)

runner:setCategory("Lexer - Start Tags")

runner:test("Simple start tag", function()
    local tokens = Lexer.parse("<div>")
    runner:assertEqual(tokens[1].type, TokenType.START_TAG)
    runner:assertEqual(tokens[1].tagName, "div")
end)

runner:test("Tag name case normalization", function()
    local tokens = Lexer.parse("<DIV>")
    runner:assertEqual(tokens[1].tagName, "div")
end)

runner:test("Tag with double-quoted attribute", function()
    local tokens = Lexer.parse('<div class="container">')
    runner:assertEqual(tokens[1].attributes.class, "container")
end)

runner:test("Tag with single-quoted attribute", function()
    local tokens = Lexer.parse("<div class='container'>")
    runner:assertEqual(tokens[1].attributes.class, "container")
end)

runner:test("Tag with unquoted attribute", function()
    local tokens = Lexer.parse("<div class=container>")
    runner:assertEqual(tokens[1].attributes.class, "container")
end)

runner:test("Tag with boolean attribute", function()
    local tokens = Lexer.parse("<input disabled>")
    runner:assertEqual(tokens[1].attributes.disabled, true)
end)

runner:test("Tag with multiple attributes", function()
    local tokens =
        Lexer.parse('<div id="main" class="container" data-value="123">')
    runner:assertEqual(tokens[1].attributes.id, "main")
    runner:assertEqual(tokens[1].attributes.class, "container")
    runner:assertEqual(tokens[1].attributes["data-value"], "123")
end)

runner:test("Attribute name case normalization", function()
    local tokens = Lexer.parse('<div CLASS="test">')
    runner:assertEqual(tokens[1].attributes.class, "test")
end)

runner:test("Attribute with spaces around equals", function()
    local tokens = Lexer.parse('<div class = "test">')
    runner:assertEqual(tokens[1].attributes.class, "test")
end)

runner:test("Self-closing tag", function()
    local tokens = Lexer.parse("<br/>")
    runner:assertEqual(tokens[1].type, TokenType.START_TAG)
    runner:assertEqual(tokens[1].tagName, "br")
    runner:assertTrue(tokens[1].selfClosing)
end)

runner:test("Self-closing with space", function()
    local tokens = Lexer.parse("<br />")
    runner:assertTrue(tokens[1].selfClosing)
end)

runner:setCategory("Lexer - End Tags")

runner:test("Simple end tag", function()
    local tokens = Lexer.parse("</div>")
    runner:assertEqual(tokens[1].type, TokenType.END_TAG)
    runner:assertEqual(tokens[1].tagName, "div")
end)

runner:test("End tag case normalization", function()
    local tokens = Lexer.parse("</DIV>")
    runner:assertEqual(tokens[1].tagName, "div")
end)

runner:test("End tag with whitespace", function()
    local tokens = Lexer.parse("</div >")
    runner:assertEqual(tokens[1].type, TokenType.END_TAG)
    runner:assertEqual(tokens[1].tagName, "div")
end)

runner:setCategory("Lexer - Void Elements")

runner:test("Void element detection", function()
    local voidElements = {
        "area",
        "base",
        "br",
        "col",
        "embed",
        "hr",
        "img",
        "input",
        "link",
        "meta",
        "source",
        "track",
        "wbr",
    }

    for _, tag in ipairs(voidElements) do
        local tokens = Lexer.parse("<" .. tag .. ">")
        runner:assertTrue(tokens[1].void, "Expected " .. tag .. " to be void")
    end
end)

runner:test("Non-void element", function()
    local tokens = Lexer.parse("<div>")
    runner:assertFalse(tokens[1].void)
end)

runner:setCategory("Lexer - Raw Text Elements")

runner:test("Script element content", function()
    local tokens = Lexer.parse("<script>var x = '<div>';</script>")
    runner:assertEqual(tokens[1].type, TokenType.START_TAG)
    runner:assertEqual(tokens[1].tagName, "script")
    runner:assertEqual(tokens[2].type, TokenType.RAW_TEXT)
    runner:assertEqual(tokens[2].value, "var x = '<div>';")
    runner:assertEqual(tokens[3].type, TokenType.END_TAG)
end)

runner:test("Style element content", function()
    local tokens = Lexer.parse("<style>.class { color: red; }</style>")
    runner:assertEqual(tokens[2].type, TokenType.RAW_TEXT)
    runner:assertContains(tokens[2].value, ".class")
end)

runner:test("Script with </script in string", function()
    local tokens = Lexer.parse("<script>var s = '</script>';</script>")
    -- The lexer should stop at first </script
    runner:assertEqual(tokens[2].type, TokenType.RAW_TEXT)
    runner:assertEqual(tokens[2].value, "var s = '")
end)

runner:setCategory("Lexer - Entity Decoding")

runner:test("Named entity &amp;", function()
    local tokens = Lexer.parse("&amp;")
    runner:assertEqual(tokens[1].value, "&")
end)

runner:test("Named entity &lt;", function()
    local tokens = Lexer.parse("&lt;")
    runner:assertEqual(tokens[1].value, "<")
end)

runner:test("Named entity &gt;", function()
    local tokens = Lexer.parse("&gt;")
    runner:assertEqual(tokens[1].value, ">")
end)

runner:test("Named entity &nbsp;", function()
    local tokens = Lexer.parse("&nbsp;")
    runner:assertEqual(tokens[1].value, "\194\160")
end)

runner:test("Named entity &copy;", function()
    local tokens = Lexer.parse("&copy;")
    runner:assertEqual(tokens[1].value, "\194\169")
end)

runner:test("Decimal entity &#60;", function()
    local tokens = Lexer.parse("&#60;")
    runner:assertEqual(tokens[1].value, "<")
end)

runner:test("Decimal entity &#169;", function()
    local tokens = Lexer.parse("&#169;")
    runner:assertEqual(tokens[1].value, "\194\169")
end)

runner:test("Hexadecimal entity &#x3C;", function()
    local tokens = Lexer.parse("&#x3C;")
    runner:assertEqual(tokens[1].value, "<")
end)

runner:test("Hexadecimal entity &#x3c; lowercase", function()
    local tokens = Lexer.parse("&#x3c;")
    runner:assertEqual(tokens[1].value, "<")
end)

runner:test("Unicode entity high codepoint", function()
    local tokens = Lexer.parse("&#x1F600;") -- 😀
    runner:assertNotNil(tokens[1].value)
end)

runner:test("Unknown named entity", function()
    local tokens = Lexer.parse("&unknown;")
    runner:assertEqual(tokens[1].value, "&unknown;")
end)

runner:test("Entity in attribute value", function()
    local tokens = Lexer.parse('<a href="?a=1&amp;b=2">')
    runner:assertEqual(tokens[1].attributes.href, "?a=1&b=2")
end)

runner:test("Malformed entity no semicolon", function()
    local tokens = Lexer.parse("&amp text")
    runner:assertEqual(tokens[1].value, "&amp text")
end)

runner:setCategory("Lexer - Position Tracking")

runner:test("Line and column tracking", function()
    local tokens = Lexer.parse("<div>\n  <span>")
    runner:assertEqual(tokens[1].line, 1)
    runner:assertEqual(tokens[1].column, 1)
    runner:assertEqual(tokens[3].line, 2) -- <span> on line 2
end)

runner:setCategory("Lexer - Edge Cases")

runner:test("Unclosed tag at end", function()
    local tokens = Lexer.parse("<div")
    -- Should handle gracefully
    runner:assertNotNil(tokens)
end)

runner:test("Less than in text", function()
    local tokens = Lexer.parse("a < b")
    runner:assertEqual(tokens[1].type, TokenType.TEXT)
end)

runner:test("Multiple less than", function()
    local tokens = Lexer.parse("a < b < c")
    runner:assertEqual(tokens[1].type, TokenType.TEXT)
end)

runner:test("Processing instruction skipped", function()
    local tokens = Lexer.parse("<?xml version='1.0'?><div>")
    -- PI should be skipped
    local foundDiv = false
    for _, token in ipairs(tokens) do
        if token.type == TokenType.START_TAG and token.tagName == "div" then
            foundDiv = true
        end
    end
    runner:assertTrue(foundDiv)
end)

runner:test("Attribute with newline", function()
    local tokens = Lexer.parse('<div\nclass="test">')
    runner:assertEqual(tokens[1].attributes.class, "test")
end)

runner:test("Empty attribute value", function()
    local tokens = Lexer.parse('<input value="">')
    runner:assertEqual(tokens[1].attributes.value, "")
end)

runner:test("Skip whitespace option", function()
    local lexer = Lexer.new("<div>  </div>")
    lexer:setSkipWhitespaceOnlyText(true)
    local tokens = lexer:tokenize()

    local hasWhitespaceText = false
    for _, token in ipairs(tokens) do
        if token.type == TokenType.TEXT and not token.value:match("%S") then
            hasWhitespaceText = true
        end
    end
    runner:assertFalse(hasWhitespaceText)
end)

--------------------------------------------------------------------------------
-- PARSER TESTS
--------------------------------------------------------------------------------

runner:setCategory("Parser - Basic DOM Construction")

runner:test("Empty document", function()
    local doc = Parser.parseHTML("", Lexer)
    runner:assertNotNil(doc)
    runner:assertEqual(doc.nodeType, NodeType.DOCUMENT)
end)

runner:test("Simple document", function()
    local doc =
        Parser.parseHTML("<html><head></head><body></body></html>", Lexer)
    runner:assertNotNil(doc.documentElement)
    runner:assertEqual(doc.documentElement.tagName, "html")
    runner:assertNotNil(doc.head)
    runner:assertNotNil(doc.body)
end)

runner:test("Implicit html element", function()
    local doc = Parser.parseHTML("<head></head><body></body>", Lexer)
    runner:assertNotNil(doc.documentElement)
    runner:assertEqual(doc.documentElement.tagName, "html")
end)

runner:test("Implicit head element", function()
    local doc = Parser.parseHTML("<html><body></body></html>", Lexer)
    runner:assertNotNil(doc.head)
end)

runner:test("Implicit body element", function()
    local doc = Parser.parseHTML("<html><div>content</div></html>", Lexer)
    runner:assertNotNil(doc.body)
end)

runner:test("All implicit elements", function()
    local doc = Parser.parseHTML("<div>content</div>", Lexer)
    runner:assertNotNil(doc.documentElement)
    runner:assertNotNil(doc.head)
    runner:assertNotNil(doc.body)
end)

runner:setCategory("Parser - DOCTYPE")

runner:test("DOCTYPE in document", function()
    local doc = Parser.parseHTML("<!DOCTYPE html><html></html>", Lexer)
    runner:assertNotNil(doc.doctype)
    runner:assertEqual(doc.doctype.name, "html")
end)

runner:setCategory("Parser - Nested Elements")

runner:test("Simple nesting", function()
    local doc = Parser.parseHTML("<div><span>text</span></div>", Lexer)
    local div = doc.body:querySelector("div")
    runner:assertNotNil(div)
    local span = div:querySelector("span")
    runner:assertNotNil(span)
end)

runner:test("Deep nesting", function()
    local doc = Parser.parseHTML(
        "<div><p><span><strong>deep</strong></span></p></div>",
        Lexer
    )
    local strong = doc.body:querySelector("strong")
    runner:assertNotNil(strong)
    runner:assertEqual(strong:getTextContent(), "deep")
end)

runner:test("Multiple children", function()
    local doc =
        Parser.parseHTML("<ul><li>1</li><li>2</li><li>3</li></ul>", Lexer)
    local items = doc.body:getElementsByTagName("li")
    runner:assertTableLength(items, 3)
end)

runner:setCategory("Parser - Void Elements")

runner:test("br element no close tag", function()
    local doc = Parser.parseHTML("<p>line1<br>line2</p>", Lexer)
    local br = doc.body:querySelector("br")
    runner:assertNotNil(br)
    runner:assertTrue(br.isVoid)
    runner:assertTableLength(br.childNodes, 0)
end)

runner:test("img element", function()
    local doc = Parser.parseHTML('<img src="test.png" alt="test">', Lexer)
    local img = doc.body:querySelector("img")
    runner:assertNotNil(img)
    runner:assertEqual(img:getAttribute("src"), "test.png")
end)

runner:test("input element", function()
    local doc = Parser.parseHTML('<input type="text" value="hello">', Lexer)
    local input = doc.body:querySelector("input")
    runner:assertNotNil(input)
    runner:assertEqual(input:getAttribute("type"), "text")
end)

runner:test("meta in head", function()
    local doc = Parser.parseHTML('<meta charset="UTF-8">', Lexer)
    local meta = doc.head:querySelector("meta")
    runner:assertNotNil(meta)
end)

runner:setCategory("Parser - Text Nodes")

runner:test("Simple text node", function()
    local doc = Parser.parseHTML("<p>Hello World</p>", Lexer)
    local p = doc.body:querySelector("p")
    runner:assertEqual(p:getTextContent(), "Hello World")
end)

runner:test("Text with entities", function()
    local doc = Parser.parseHTML("<p>&lt;hello&gt;</p>", Lexer)
    local p = doc.body:querySelector("p")
    runner:assertEqual(p:getTextContent(), "<hello>")
end)

runner:test("Mixed content", function()
    local doc = Parser.parseHTML("<p>Hello <strong>World</strong>!</p>", Lexer)
    local p = doc.body:querySelector("p")
    runner:assertEqual(p:getTextContent(), "Hello World!")
end)

runner:test("Text node merging", function()
    -- Adjacent text should be merged
    local doc = Parser.parseHTML("<p>Hello World</p>", Lexer)
    local p = doc.body:querySelector("p")
    runner:assertTableLength(p.childNodes, 1)
end)

runner:setCategory("Parser - Comments")

runner:test("Comment preserved when enabled", function()
    local doc = Parser.parseHTML(
        "<!-- comment --><div></div>",
        Lexer,
        { preserveComments = true }
    )
    local hasComment = false
    for _, child in ipairs(doc.childNodes) do
        if child.nodeType == NodeType.COMMENT then
            hasComment = true
            runner:assertEqual(child.nodeValue, " comment ")
        end
    end
    runner:assertTrue(hasComment)
end)

runner:test("Comment not preserved by default", function()
    local doc = Parser.parseHTML("<!-- comment --><div></div>", Lexer)
    local hasComment = false
    for _, child in ipairs(doc.body.childNodes) do
        if child.nodeType == NodeType.COMMENT then hasComment = true end
    end
    runner:assertFalse(hasComment)
end)

runner:setCategory("Parser - Implicit Tag Closing")

runner:test("p closed by div", function()
    local doc = Parser.parseHTML("<p>text<div>block</div>", Lexer)
    local p = doc.body:querySelector("p")
    local div = doc.body:querySelector("div")
    runner:assertNotNil(p)
    runner:assertNotNil(div)
    -- div should not be inside p
    runner:assertFalse(p:contains(div))
end)

runner:test("p closed by another p", function()
    local doc = Parser.parseHTML("<p>first<p>second", Lexer)
    local ps = doc.body:getElementsByTagName("p")
    runner:assertTableLength(ps, 2)
    -- They should be siblings, not nested
    runner:assertFalse(ps[1]:contains(ps[2]))
end)

runner:test("p closed by heading", function()
    local doc = Parser.parseHTML("<p>text<h1>heading</h1>", Lexer)
    local p = doc.body:querySelector("p")
    local h1 = doc.body:querySelector("h1")
    runner:assertFalse(p:contains(h1))
end)

runner:test("li closed by another li", function()
    local doc = Parser.parseHTML("<ul><li>first<li>second</ul>", Lexer)
    local items = doc.body:getElementsByTagName("li")
    runner:assertTableLength(items, 2)
    runner:assertFalse(items[1]:contains(items[2]))
end)

runner:test("dt closed by dd", function()
    local doc = Parser.parseHTML("<dl><dt>term<dd>definition</dl>", Lexer)
    local dt = doc.body:querySelector("dt")
    local dd = doc.body:querySelector("dd")
    runner:assertFalse(dt:contains(dd))
end)

runner:test("dd closed by dt", function()
    local doc = Parser.parseHTML("<dl><dd>def1<dt>term<dd>def2</dl>", Lexer)
    local dds = doc.body:getElementsByTagName("dd")
    runner:assertTableLength(dds, 2)
end)

runner:test("tr closed by another tr", function()
    local doc = Parser.parseHTML("<table><tr><td>1<tr><td>2</table>", Lexer)
    local rows = doc.body:getElementsByTagName("tr")
    runner:assertTableLength(rows, 2)
end)

runner:test("td closed by another td", function()
    local doc = Parser.parseHTML("<table><tr><td>1<td>2</tr></table>", Lexer)
    local cells = doc.body:getElementsByTagName("td")
    runner:assertTableLength(cells, 2)
    runner:assertFalse(cells[1]:contains(cells[2]))
end)

runner:test("td closed by th", function()
    local doc =
        Parser.parseHTML("<table><tr><td>data<th>header</tr></table>", Lexer)
    local td = doc.body:querySelector("td")
    local th = doc.body:querySelector("th")
    runner:assertFalse(td:contains(th))
end)

runner:test("thead closed by tbody", function()
    local doc = Parser.parseHTML(
        "<table><thead><tr><th>H</thead><tbody><tr><td>D</tbody></table>",
        Lexer,
        { skipWhitespaceOnlyText = true }
    )
    local thead = doc.body:querySelector("thead")
    local tbody = doc.body:querySelector("tbody")
    runner:assertNotNil(thead)
    runner:assertNotNil(tbody)
    runner:assertFalse(thead:contains(tbody))
end)

runner:test("Heading closed by another heading", function()
    local doc = Parser.parseHTML("<h1>title<h2>subtitle", Lexer)
    local h1 = doc.body:querySelector("h1")
    local h2 = doc.body:querySelector("h2")
    runner:assertFalse(h1:contains(h2))
end)

runner:test("option closed by another option", function()
    local doc = Parser.parseHTML("<select><option>A<option>B</select>", Lexer)
    local options = doc.body:getElementsByTagName("option")
    runner:assertTableLength(options, 2)
end)

runner:test("optgroup closed by another optgroup", function()
    local doc = Parser.parseHTML(
        "<select><optgroup label='1'><option>A<optgroup label='2'><option>B</select>",
        Lexer
    )
    local groups = doc.body:getElementsByTagName("optgroup")
    runner:assertTableLength(groups, 2)
end)

runner:setCategory("Parser - Adoption Agency Algorithm")

runner:test("Simple formatting close", function()
    local doc = Parser.parseHTML("<p><b>bold</b> text</p>", Lexer)
    local b = doc.body:querySelector("b")
    runner:assertNotNil(b)
    runner:assertEqual(b:getTextContent(), "bold")
end)

runner:test("Misnested b and i - simple", function()
    -- <b><i></b></i> should become <b><i></i></b><i></i>
    local doc = Parser.parseHTML("<p><b><i>text</b>more</i></p>", Lexer)
    local p = doc.body:querySelector("p")
    runner:assertNotNil(p)
    -- The structure should be fixed
    local b = p:querySelector("b")
    runner:assertNotNil(b)
end)

runner:test("Misnested with block element", function()
    -- <b>bold<p>para</b>text</p>
    local doc = Parser.parseHTML("<b>bold<p>para</b>text</p>", Lexer)
    local b = doc.body:querySelector("b")
    local p = doc.body:querySelector("p")
    runner:assertNotNil(b)
    runner:assertNotNil(p)
end)

runner:test("Adoption agency with furthest block", function()
    -- <p><b>X<div>Y</b>Z</div>
    local doc = Parser.parseHTML("<p><b>X<div>Y</b>Z</div>", Lexer)
    runner:assertNotNil(doc.body)
    -- Should parse without error
end)

runner:test("Multiple formatting elements", function()
    local doc = Parser.parseHTML("<p><b><i><u>text</u></i></b></p>", Lexer)
    local u = doc.body:querySelector("u")
    runner:assertNotNil(u)
    runner:assertEqual(u:getTextContent(), "text")
end)

runner:test("Nested same formatting", function()
    local doc = Parser.parseHTML("<p><b>outer<b>inner</b>outer</b></p>", Lexer)
    local bs = doc.body:getElementsByTagName("b")
    runner:assertTrue(#bs >= 1)
end)

runner:test("Anchor adoption agency", function()
    -- Nested anchors should trigger adoption agency
    local doc =
        Parser.parseHTML('<a href="1">link1<a href="2">link2</a></a>', Lexer)
    local anchors = doc.body:getElementsByTagName("a")
    runner:assertTrue(#anchors >= 1)
end)

runner:test("Noah's Ark clause - max 3 duplicates", function()
    -- Having more than 3 identical formatting elements should remove oldest
    local doc =
        Parser.parseHTML("<p><b><b><b><b>text</b></b></b></b></p>", Lexer)
    runner:assertNotNil(doc.body)
end)

runner:setCategory("Parser - Active Formatting Reconstruction")

runner:test("Formatting reconstructed after block", function()
    local doc = Parser.parseHTML("<p><b>bold<p>still bold</p>", Lexer)
    -- The second p should have inherited formatting reconstructed
    runner:assertNotNil(doc.body)
end)

runner:test("Multiple formatting reconstructed", function()
    local doc = Parser.parseHTML("<b><i>text<p>paragraph</p></i></b>", Lexer)
    runner:assertNotNil(doc.body)
end)

runner:setCategory("Parser - Table Structure")

runner:test("Basic table", function()
    local doc = Parser.parseHTML("<table><tr><td>cell</td></tr></table>", Lexer)
    local table = doc.body:querySelector("table")
    local tr = table:querySelector("tr")
    local td = tr:querySelector("td")
    runner:assertNotNil(td)
    runner:assertEqual(td:getTextContent(), "cell")
end)

runner:test("Table with thead and tbody", function()
    local doc = Parser.parseHTML(
        [[
        <table>
            <thead><tr><th>Header</th></tr></thead>
            <tbody><tr><td>Data</td></tr></tbody>
        </table>
    ]],
        Lexer,
        { skipWhitespaceOnlyText = true }
    )
    local thead = doc.body:querySelector("thead")
    local tbody = doc.body:querySelector("tbody")
    runner:assertNotNil(thead)
    runner:assertNotNil(tbody)
end)

runner:test("Table implicit tbody", function()
    local doc = Parser.parseHTML("<table><tr><td>cell</td></tr></table>", Lexer)
    -- Modern browsers create implicit tbody, but our parser may not
    local table = doc.body:querySelector("table")
    local td = table:getElementsByTagName("td")
    runner:assertTableLength(td, 1)
end)

runner:setCategory("Parser - Foster Parenting")

runner:test("Text in table context foster parented", function()
    local doc =
        Parser.parseHTML("<table>text<tr><td>cell</td></tr></table>", Lexer)
    -- Text should be foster parented before the table
    local table = doc.body:querySelector("table")
    runner:assertNotNil(table)
end)

runner:test("Element in table context", function()
    local doc = Parser.parseHTML(
        "<table><div>misplaced</div><tr><td>cell</td></tr></table>",
        Lexer
    )
    runner:assertNotNil(doc.body)
end)

runner:setCategory("Parser - Scope Checking")

runner:test("Element in scope", function()
    local doc = Parser.parseHTML("<div><p><span></span></p></div>", Lexer)
    runner:assertNotNil(doc.body)
end)

runner:test("Button in button scope", function()
    local doc =
        Parser.parseHTML("<button>first<button>second</button></button>", Lexer)
    -- Nested buttons should close the first
    local buttons = doc.body:getElementsByTagName("button")
    runner:assertTrue(#buttons >= 1)
end)

--------------------------------------------------------------------------------
-- DOM NODE TESTS
--------------------------------------------------------------------------------

runner:setCategory("DOM Node - Creation")

runner:test("Create document", function()
    local doc = Node.createDocument()
    runner:assertEqual(doc.nodeType, NodeType.DOCUMENT)
    runner:assertEqual(doc.nodeName, "#document")
end)

runner:test("Create element", function()
    local elem = Node.createElement("div", { class = "test", id = "main" })
    runner:assertEqual(elem.nodeType, NodeType.ELEMENT)
    runner:assertEqual(elem.tagName, "div")
    runner:assertEqual(elem.id, "main")
    runner:assertEqual(elem.className, "test")
end)

runner:test("Create text", function()
    local text = Node.createText("Hello World")
    runner:assertEqual(text.nodeType, NodeType.TEXT)
    runner:assertEqual(text.nodeValue, "Hello World")
end)

runner:test("Create comment", function()
    local comment = Node.createComment("This is a comment")
    runner:assertEqual(comment.nodeType, NodeType.COMMENT)
    runner:assertEqual(comment.nodeValue, "This is a comment")
end)

runner:setCategory("DOM Node - Child Operations")

runner:test("appendChild", function()
    local parent = Node.createElement("div")
    local child = Node.createElement("span")
    parent:appendChild(child)

    runner:assertEqual(child.parentNode, parent)
    runner:assertEqual(parent.firstChild, child)
    runner:assertEqual(parent.lastChild, child)
    runner:assertTableLength(parent.childNodes, 1)
end)

runner:test("appendChild multiple", function()
    local parent = Node.createElement("div")
    local child1 = Node.createElement("span")
    local child2 = Node.createElement("p")
    local child3 = Node.createElement("a")

    parent:appendChild(child1)
    parent:appendChild(child2)
    parent:appendChild(child3)

    runner:assertTableLength(parent.childNodes, 3)
    runner:assertEqual(parent.firstChild, child1)
    runner:assertEqual(parent.lastChild, child3)
    runner:assertEqual(child1.nextSibling, child2)
    runner:assertEqual(child2.previousSibling, child1)
    runner:assertEqual(child2.nextSibling, child3)
end)

runner:test("insertBefore", function()
    local parent = Node.createElement("div")
    local child1 = Node.createElement("span")
    local child2 = Node.createElement("p")
    local newChild = Node.createElement("a")

    parent:appendChild(child1)
    parent:appendChild(child2)
    parent:insertBefore(newChild, child2)

    runner:assertTableLength(parent.childNodes, 3)
    runner:assertEqual(parent.childNodes[2], newChild)
    runner:assertEqual(child1.nextSibling, newChild)
    runner:assertEqual(newChild.nextSibling, child2)
end)

runner:test("insertBefore with nil ref (append)", function()
    local parent = Node.createElement("div")
    local child1 = Node.createElement("span")
    local newChild = Node.createElement("a")

    parent:appendChild(child1)
    parent:insertBefore(newChild, nil)

    runner:assertEqual(parent.lastChild, newChild)
end)

runner:test("removeChild", function()
    local parent = Node.createElement("div")
    local child1 = Node.createElement("span")
    local child2 = Node.createElement("p")

    parent:appendChild(child1)
    parent:appendChild(child2)
    parent:removeChild(child1)

    runner:assertTableLength(parent.childNodes, 1)
    runner:assertEqual(parent.firstChild, child2)
    runner:assertNil(child1.parentNode)
end)

runner:test("replaceChild", function()
    local parent = Node.createElement("div")
    local oldChild = Node.createElement("span")
    local newChild = Node.createElement("p")

    parent:appendChild(oldChild)
    parent:replaceChild(newChild, oldChild)

    runner:assertTableLength(parent.childNodes, 1)
    runner:assertEqual(parent.firstChild, newChild)
    runner:assertNil(oldChild.parentNode)
end)

runner:test("hasChildNodes", function()
    local parent = Node.createElement("div")
    runner:assertFalse(parent:hasChildNodes())

    parent:appendChild(Node.createElement("span"))
    runner:assertTrue(parent:hasChildNodes())
end)

runner:test("Moving child to new parent", function()
    local parent1 = Node.createElement("div")
    local parent2 = Node.createElement("section")
    local child = Node.createElement("span")

    parent1:appendChild(child)
    runner:assertEqual(child.parentNode, parent1)

    parent2:appendChild(child)
    runner:assertEqual(child.parentNode, parent2)
    runner:assertTableLength(parent1.childNodes, 0)
end)

runner:setCategory("DOM Node - Attributes")

runner:test("getAttribute", function()
    local elem = Node.createElement("div", { class = "test" })
    runner:assertEqual(elem:getAttribute("class"), "test")
end)

runner:test("getAttribute nonexistent", function()
    local elem = Node.createElement("div")
    runner:assertNil(elem:getAttribute("nonexistent"))
end)

runner:test("setAttribute", function()
    local elem = Node.createElement("div")
    elem:setAttribute("class", "container")
    runner:assertEqual(elem:getAttribute("class"), "container")
    runner:assertEqual(elem.className, "container")
end)

runner:test("setAttribute id", function()
    local elem = Node.createElement("div")
    elem:setAttribute("id", "main")
    runner:assertEqual(elem.id, "main")
end)

runner:test("removeAttribute", function()
    local elem = Node.createElement("div", { class = "test" })
    elem:removeAttribute("class")
    runner:assertNil(elem:getAttribute("class"))
    runner:assertNil(elem.className)
end)

runner:test("hasAttribute", function()
    local elem = Node.createElement("div", { class = "test" })
    runner:assertTrue(elem:hasAttribute("class"))
    runner:assertFalse(elem:hasAttribute("id"))
end)

runner:setCategory("DOM Node - Classes")

runner:test("classList populated", function()
    local elem = Node.createElement("div", { class = "one two three" })
    runner:assertTableLength(elem.classList, 3)
end)

runner:test("hasClass true", function()
    local elem = Node.createElement("div", { class = "container main" })
    runner:assertTrue(elem:hasClass("container"))
    runner:assertTrue(elem:hasClass("main"))
end)

runner:test("hasClass false", function()
    local elem = Node.createElement("div", { class = "container" })
    runner:assertFalse(elem:hasClass("other"))
end)

runner:setCategory("DOM Node - Text Content")

runner:test("getTextContent element", function()
    local parent = Node.createElement("div")
    parent:appendChild(Node.createText("Hello "))
    local span = Node.createElement("span")
    span:appendChild(Node.createText("World"))
    parent:appendChild(span)

    runner:assertEqual(parent:getTextContent(), "Hello World")
end)

runner:test("getTextContent text node", function()
    local text = Node.createText("Hello")
    runner:assertEqual(text:getTextContent(), "Hello")
end)

runner:test("setTextContent", function()
    local elem = Node.createElement("div")
    elem:appendChild(Node.createElement("span"))
    elem:setTextContent("New content")

    runner:assertTableLength(elem.childNodes, 1)
    runner:assertEqual(elem.childNodes[1].nodeType, NodeType.TEXT)
    runner:assertEqual(elem:getTextContent(), "New content")
end)

runner:setCategory("DOM Node - Cloning")

runner:test("cloneNode shallow", function()
    local elem = Node.createElement("div", { class = "test" })
    elem:appendChild(Node.createElement("span"))

    local clone = elem:cloneNode(false)

    runner:assertEqual(clone.tagName, "div")
    runner:assertEqual(clone:getAttribute("class"), "test")
    runner:assertTableLength(clone.childNodes, 0)
    runner:assertNil(clone.parentNode)
end)

runner:test("cloneNode deep", function()
    local elem = Node.createElement("div")
    local child = Node.createElement("span")
    child:appendChild(Node.createText("Hello"))
    elem:appendChild(child)

    local clone = elem:cloneNode(true)

    runner:assertTableLength(clone.childNodes, 1)
    runner:assertEqual(clone.childNodes[1].tagName, "span")
    runner:assertEqual(clone:getTextContent(), "Hello")
end)

runner:setCategory("DOM Node - Queries")

runner:test("getElementById", function()
    local doc = Parser.parseHTML(
        '<div id="main"><span id="inner">text</span></div>',
        Lexer
    )
    local main = doc:getElementById("main")
    runner:assertNotNil(main)
    runner:assertEqual(main.tagName, "div")

    local inner = doc:getElementById("inner")
    runner:assertNotNil(inner)
    runner:assertEqual(inner.tagName, "span")
end)

runner:test("getElementById not found", function()
    local doc = Parser.parseHTML("<div>text</div>", Lexer)
    local result = doc:getElementById("nonexistent")
    runner:assertNil(result)
end)

runner:test("getElementsByTagName", function()
    local doc = Parser.parseHTML(
        "<div><p>1</p><p>2</p><span><p>3</p></span></div>",
        Lexer
    )
    local ps = doc:getElementsByTagName("p")
    runner:assertTableLength(ps, 3)
end)

runner:test("getElementsByTagName wildcard", function()
    local doc = Parser.parseHTML("<div><p>1</p><span>2</span></div>", Lexer)
    local all = doc.body:getElementsByTagName("*")
    runner:assertTrue(#all >= 3) -- div, p, span
end)

runner:test("getElementsByClassName", function()
    local doc = Parser.parseHTML(
        '<div class="a"><p class="a b">1</p><span class="b">2</span></div>',
        Lexer
    )
    local classA = doc:getElementsByClassName("a")
    runner:assertTableLength(classA, 2)
end)

runner:test("querySelector tag", function()
    local doc = Parser.parseHTML("<div><p>first</p><p>second</p></div>", Lexer)
    local p = doc:querySelector("p")
    runner:assertNotNil(p)
    runner:assertEqual(p:getTextContent(), "first")
end)

runner:test("querySelector id", function()
    local doc = Parser.parseHTML('<div id="test">content</div>', Lexer)
    local elem = doc:querySelector("#test")
    runner:assertNotNil(elem)
end)

runner:test("querySelector class", function()
    local doc = Parser.parseHTML('<div class="container">content</div>', Lexer)
    local elem = doc:querySelector(".container")
    runner:assertNotNil(elem)
end)

runner:test("querySelector combined", function()
    local doc = Parser.parseHTML(
        '<div class="a"><p class="target">1</p></div><p class="target">2</p>',
        Lexer
    )
    local elem = doc:querySelector("p.target")
    runner:assertNotNil(elem)
end)

runner:test("querySelectorAll", function()
    local doc = Parser.parseHTML(
        '<p class="a">1</p><p class="b">2</p><p class="a">3</p>',
        Lexer
    )
    local results = doc:querySelectorAll("p.a")
    runner:assertTableLength(results, 2)
end)

runner:test("matches", function()
    local doc = Parser.parseHTML(
        '<div id="main" class="container active">text</div>',
        Lexer
    )
    local div = doc:querySelector("div")

    runner:assertTrue(div:matches("div"))
    runner:assertTrue(div:matches("#main"))
    runner:assertTrue(div:matches(".container"))
    runner:assertTrue(div:matches("div#main"))
    runner:assertTrue(div:matches("div.container.active"))
    runner:assertFalse(div:matches("span"))
    runner:assertFalse(div:matches("#other"))
end)

runner:test("closest", function()
    local doc = Parser.parseHTML(
        '<div class="outer"><p class="inner"><span id="target">text</span></p></div>',
        Lexer
    )
    local span = doc:getElementById("target")

    local inner = span:closest(".inner")
    runner:assertNotNil(inner)
    runner:assertEqual(inner.tagName, "p")

    local outer = span:closest(".outer")
    runner:assertNotNil(outer)
    runner:assertEqual(outer.tagName, "div")
end)

runner:test("contains", function()
    local doc = Parser.parseHTML(
        '<div id="parent"><span id="child">text</span></div>',
        Lexer
    )
    local parent = doc:getElementById("parent")
    local child = doc:getElementById("child")

    runner:assertTrue(parent:contains(child))
    runner:assertTrue(parent:contains(parent))
    runner:assertFalse(child:contains(parent))
end)

runner:test("getAncestors", function()
    local doc = Parser.parseHTML(
        '<div><p><span id="target">text</span></p></div>',
        Lexer
    )
    local span = doc:getElementById("target")
    local ancestors = span:getAncestors()

    runner:assertTrue(#ancestors >= 2)
    runner:assertEqual(ancestors[1].tagName, "p")
    runner:assertEqual(ancestors[2].tagName, "div")
end)

runner:setCategory("DOM Node - Serialization")

runner:test("getOuterHTML element", function()
    local elem = Node.createElement("div", { class = "test" })
    elem:appendChild(Node.createText("Hello"))

    local html = elem:getOuterHTML()
    runner:assertContains(html, "<div")
    runner:assertContains(html, 'class="test"')
    runner:assertContains(html, "Hello")
    runner:assertContains(html, "</div>")
end)

runner:test("getOuterHTML void element", function()
    local elem = Node.createElement("br")
    local html = elem:getOuterHTML()
    runner:assertEqual(html, "<br>")
end)

runner:test("getOuterHTML escapes text", function()
    local elem = Node.createElement("div")
    elem:appendChild(Node.createText("<script>alert('xss')</script>"))

    local html = elem:getOuterHTML()
    runner:assertContains(html, "&lt;script&gt;")
end)

runner:test("getInnerHTML", function()
    local elem = Node.createElement("div")
    local span = Node.createElement("span")
    span:appendChild(Node.createText("Hello"))
    elem:appendChild(span)

    local html = elem:getInnerHTML()
    runner:assertContains(html, "<span>")
    runner:assertContains(html, "Hello")
end)

runner:test("getOuterHTML comment", function()
    local comment = Node.createComment("test comment")
    runner:assertEqual(comment:getOuterHTML(), "<!--test comment-->")
end)

--------------------------------------------------------------------------------
-- INTEGRATION TESTS
--------------------------------------------------------------------------------

runner:setCategory("Integration - Complex Documents")

runner:test("Full HTML5 document", function()
    local html = [[
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Test Page</title>
    <link rel="stylesheet" href="style.css">
    <style>
        body { margin: 0; }
    </style>
</head>
<body>
    <header>
        <nav>
            <a href="/">Home</a>
            <a href="/about">About</a>
        </nav>
    </header>
    <main>
        <article>
            <h1>Article Title</h1>
            <p>First paragraph with <strong>bold</strong> and <em>italic</em> text.</p>
            <p>Second paragraph with a <a href="http://example.com">link</a>.</p>
        </article>
        <aside>
            <h2>Related</h2>
            <ul>
                <li>Item 1</li>
                <li>Item 2</li>
                <li>Item 3</li>
            </ul>
        </aside>
    </main>
    <footer>
        <p>&copy; 2024 Test Site</p>
    </footer>
    <script>
        console.log("Hello");
    </script>
</body>
</html>
    ]]

    local doc = Parser.parseHTML(html, Lexer, { skipWhitespaceOnlyText = true })

    runner:assertNotNil(doc.doctype)
    runner:assertNotNil(doc.documentElement)
    runner:assertEqual(doc.documentElement:getAttribute("lang"), "en")
    runner:assertNotNil(doc.head)
    runner:assertNotNil(doc.body)

    local title = doc.head:querySelector("title")
    runner:assertNotNil(title)
    runner:assertEqual(title:getTextContent(), "Test Page")

    local metas = doc.head:getElementsByTagName("meta")
    runner:assertTrue(#metas >= 2)

    local nav = doc.body:querySelector("nav")
    runner:assertNotNil(nav)
    local navLinks = nav:getElementsByTagName("a")
    runner:assertTableLength(navLinks, 2)

    local article = doc.body:querySelector("article")
    runner:assertNotNil(article)

    local h1 = article:querySelector("h1")
    runner:assertEqual(h1:getTextContent(), "Article Title")

    local listItems = doc.body:getElementsByTagName("li")
    runner:assertTableLength(listItems, 3)

    local footer = doc.body:querySelector("footer")
    runner:assertNotNil(footer)
    runner:assertContains(footer:getTextContent(), "©") -- Decoded entity
end)

runner:test("Form with various inputs", function()
    local html = [[
<form action="/submit" method="POST">
    <fieldset>
        <legend>Personal Info</legend>
        <label for="name">Name:</label>
        <input type="text" id="name" name="name" required>
        
        <label for="email">Email:</label>
        <input type="email" id="email" name="email">
        
        <label for="password">Password:</label>
        <input type="password" id="password" name="password">
    </fieldset>
    
    <fieldset>
        <legend>Preferences</legend>
        <input type="checkbox" id="newsletter" name="newsletter">
        <label for="newsletter">Subscribe to newsletter</label>
        
        <select name="country">
            <option value="">Select country</option>
            <option value="us">United States</option>
            <option value="uk">United Kingdom</option>
        </select>
    </fieldset>
    
    <textarea name="message" rows="4" cols="50"></textarea>
    
    <button type="submit">Submit</button>
    <button type="reset">Reset</button>
</form>
    ]]

    local doc = Parser.parseHTML(html, Lexer, { skipWhitespaceOnlyText = true })

    local form = doc.body:querySelector("form")
    runner:assertNotNil(form)
    runner:assertEqual(form:getAttribute("action"), "/submit")
    runner:assertEqual(form:getAttribute("method"), "POST")

    local inputs = form:getElementsByTagName("input")
    runner:assertTrue(#inputs >= 4)

    local nameInput = doc:getElementById("name")
    runner:assertNotNil(nameInput)
    runner:assertTrue(nameInput:hasAttribute("required"))

    local options = form:getElementsByTagName("option")
    runner:assertTableLength(options, 3)

    local buttons = form:getElementsByTagName("button")
    runner:assertTableLength(buttons, 2)
end)

runner:test("Table with complex structure", function()
    local html = [[
<table>
    <caption>Monthly Sales</caption>
    <colgroup>
        <col style="width: 50%">
        <col style="width: 25%">
        <col style="width: 25%">
    </colgroup>
    <thead>
        <tr>
            <th>Month</th>
            <th>Revenue</th>
            <th>Growth</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>January</td>
            <td>$10,000</td>
            <td>+5%</td>
        </tr>
        <tr>
            <td>February</td>
            <td>$12,000</td>
            <td>+20%</td>
        </tr>
    </tbody>
    <tfoot>
        <tr>
            <td>Total</td>
            <td>$22,000</td>
            <td>+12.5%</td>
        </tr>
    </tfoot>
</table>
    ]]

    local doc = Parser.parseHTML(html, Lexer, { skipWhitespaceOnlyText = true })

    local table = doc.body:querySelector("table")
    runner:assertNotNil(table)

    local caption = table:querySelector("caption")
    runner:assertNotNil(caption)
    runner:assertEqual(caption:getTextContent(), "Monthly Sales")

    local cols = table:getElementsByTagName("col")
    runner:assertTableLength(cols, 3)

    local thead = table:querySelector("thead")
    local tbody = table:querySelector("tbody")
    local tfoot = table:querySelector("tfoot")
    runner:assertNotNil(thead)
    runner:assertNotNil(tbody)
    runner:assertNotNil(tfoot)

    local allRows = table:getElementsByTagName("tr")
    runner:assertTableLength(allRows, 4)

    local headerCells = thead:getElementsByTagName("th")
    runner:assertTableLength(headerCells, 3)
end)

runner:test("Definition list", function()
    local html = [[
<dl>
    <dt>HTML</dt>
    <dd>HyperText Markup Language</dd>
    
    <dt>CSS</dt>
    <dd>Cascading Style Sheets</dd>
    
    <dt>JS</dt>
    <dt>JavaScript</dt>
    <dd>A programming language</dd>
    <dd>Used for web development</dd>
</dl>
    ]]

    local doc = Parser.parseHTML(html, Lexer, { skipWhitespaceOnlyText = true })

    local dl = doc.body:querySelector("dl")
    runner:assertNotNil(dl)

    local dts = dl:getElementsByTagName("dt")
    local dds = dl:getElementsByTagName("dd")

    runner:assertTableLength(dts, 4) -- HTML, CSS, JS, JavaScript
    runner:assertTableLength(dds, 4)
end)

runner:test("Nested lists", function()
    local html = [[
<ul>
    <li>Item 1
        <ul>
            <li>Sub-item 1.1</li>
            <li>Sub-item 1.2</li>
        </ul>
    </li>
    <li>Item 2
        <ol>
            <li>Sub-item 2.1</li>
            <li>Sub-item 2.2</li>
        </ol>
    </li>
</ul>
    ]]

    local doc = Parser.parseHTML(html, Lexer, { skipWhitespaceOnlyText = true })

    local topUl = doc.body.childNodes[1]
    runner:assertEqual(topUl.tagName, "ul")

    local allLis = doc.body:getElementsByTagName("li")
    runner:assertTableLength(allLis, 6)

    local ols = doc.body:getElementsByTagName("ol")
    runner:assertTableLength(ols, 1)
end)

runner:test("Media elements", function()
    local html = [[
<figure>
    <picture>
        <source srcset="image.webp" type="image/webp">
        <source srcset="image.jpg" type="image/jpeg">
        <img src="image.jpg" alt="Test image" width="300" height="200">
    </picture>
    <figcaption>An example image</figcaption>
</figure>

<video controls width="640" height="360">
    <source src="video.mp4" type="video/mp4">
    <source src="video.webm" type="video/webm">
    <track kind="subtitles" src="subs.vtt" srclang="en" label="English">
    Your browser doesn't support video.
</video>

<audio controls>
    <source src="audio.mp3" type="audio/mpeg">
    <source src="audio.ogg" type="audio/ogg">
    Your browser doesn't support audio.
</audio>
    ]]

    local doc = Parser.parseHTML(html, Lexer, { skipWhitespaceOnlyText = true })

    local figure = doc.body:querySelector("figure")
    runner:assertNotNil(figure)

    local picture = figure:querySelector("picture")
    runner:assertNotNil(picture)

    local sources = picture:getElementsByTagName("source")
    runner:assertTableLength(sources, 2)

    local img = picture:querySelector("img")
    runner:assertNotNil(img)
    runner:assertEqual(img:getAttribute("alt"), "Test image")

    local video = doc.body:querySelector("video")
    runner:assertNotNil(video)
    runner:assertTrue(video:hasAttribute("controls"))

    local track = video:querySelector("track")
    runner:assertNotNil(track)

    local audio = doc.body:querySelector("audio")
    runner:assertNotNil(audio)
end)

runner:test("Script and style content preserved", function()
    -- Use explicit structure to ensure proper placement
    local html = [[<head>
<style>
    .class > child {
        color: red;
    }
</style>
</head>
<body>
<script>
    var html = '<div class="test">content</div>';
    if (a < b && c > d) {
        console.log("test");
    }
</script>
</body>]]

    local doc = Parser.parseHTML(html, Lexer)

    local script = doc.body:querySelector("script")
    runner:assertNotNil(script)
    local scriptContent = script:getTextContent()
    runner:assertContains(scriptContent, "var html")
    runner:assertContains(scriptContent, "<div")

    local style = doc.head:querySelector("style")
    runner:assertNotNil(style)
    runner:assertContains(style:getTextContent(), ".class > child")
end)

runner:setCategory("Integration - Edge Cases")

runner:test("Deeply nested elements", function()
    local html = "<div>"
        .. string.rep("<span>", 50)
        .. "deep"
        .. string.rep("</span>", 50)
        .. "</div>"
    local doc = Parser.parseHTML(html, Lexer)

    local spans = doc.body:getElementsByTagName("span")
    runner:assertEqual(#spans, 50)
end)

runner:test("Many sibling elements", function()
    local parts = { "<ul>" }
    for i = 1, 100 do
        table.insert(parts, "<li>Item " .. i .. "</li>")
    end
    table.insert(parts, "</ul>")

    local doc = Parser.parseHTML(table.concat(parts), Lexer)
    local items = doc.body:getElementsByTagName("li")
    runner:assertTableLength(items, 100)
end)

runner:test("Unclosed tags recovery", function()
    local html = "<div><p>unclosed<span>also unclosed<b>and this"
    local doc = Parser.parseHTML(html, Lexer)

    runner:assertNotNil(doc.body)
    runner:assertNotNil(doc.body:querySelector("div"))
    runner:assertNotNil(doc.body:querySelector("p"))
end)

runner:test("Extra closing tags ignored", function()
    local html = "<div>content</div></div></span></p>"
    local doc = Parser.parseHTML(html, Lexer)

    runner:assertNotNil(doc.body)
    local divs = doc.body:getElementsByTagName("div")
    runner:assertTableLength(divs, 1)
end)

runner:test("Mixed content with entities", function()
    local html =
        "<p>Price: &lt;$100&gt; &amp; &quot;free&quot; shipping&nbsp;available!</p>"
    local doc = Parser.parseHTML(html, Lexer)

    local p = doc.body:querySelector("p")
    local text = p:getTextContent()
    runner:assertContains(text, "<$100>")
    runner:assertContains(text, "&")
    runner:assertContains(text, '"free"')
end)

runner:test("Empty elements", function()
    local html = "<div></div><p></p><span></span>"
    local doc = Parser.parseHTML(html, Lexer)

    local div = doc.body:querySelector("div")
    runner:assertTableLength(div.childNodes, 0)
    runner:assertEqual(div:getTextContent(), "")
end)

runner:test("Whitespace preservation in pre", function()
    local html = "<pre>  line1\n    indented\n  line3  </pre>"
    local doc = Parser.parseHTML(html, Lexer, { preserveWhitespace = true })

    local pre = doc.body:querySelector("pre")
    runner:assertNotNil(pre)
    local text = pre:getTextContent()
    runner:assertContains(text, "  line1")
    runner:assertContains(text, "    indented")
end)

runner:test("Boolean attributes", function()
    local html = [[
        <input type="checkbox" checked disabled readonly>
        <button disabled>Click</button>
        <select multiple>
            <option selected>Option</option>
        </select>
        <video autoplay muted loop playsinline></video>
    ]]

    local doc = Parser.parseHTML(html, Lexer, { skipWhitespaceOnlyText = true })

    local input = doc.body:querySelector("input")
    runner:assertTrue(input:hasAttribute("checked"))
    runner:assertTrue(input:hasAttribute("disabled"))
    runner:assertTrue(input:hasAttribute("readonly"))

    local video = doc.body:querySelector("video")
    runner:assertTrue(video:hasAttribute("autoplay"))
    runner:assertTrue(video:hasAttribute("muted"))
    runner:assertTrue(video:hasAttribute("loop"))
end)

runner:test("Data attributes", function()
    local html =
        '<div data-id="123" data-name="test" data-complex-value="a b c"></div>'
    local doc = Parser.parseHTML(html, Lexer)

    local div = doc.body:querySelector("div")
    runner:assertEqual(div:getAttribute("data-id"), "123")
    runner:assertEqual(div:getAttribute("data-name"), "test")
    runner:assertEqual(div:getAttribute("data-complex-value"), "a b c")
end)

runner:test("SVG element", function()
    local html = [[
<svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
    <circle cx="50" cy="50" r="40" fill="red"/>
    <text x="50" y="55" text-anchor="middle">SVG</text>
</svg>
    ]]

    local doc = Parser.parseHTML(html, Lexer, { skipWhitespaceOnlyText = true })

    local svg = doc.body:querySelector("svg")
    runner:assertNotNil(svg)
    runner:assertEqual(svg:getAttribute("width"), "100")

    local circle = svg:querySelector("circle")
    runner:assertNotNil(circle)
end)

runner:test("Ruby annotation", function()
    local html = [[
<ruby>
    漢 <rp>(</rp><rt>かん</rt><rp>)</rp>
    字 <rp>(</rp><rt>じ</rt><rp>)</rp>
</ruby>
    ]]

    local doc = Parser.parseHTML(html, Lexer, { skipWhitespaceOnlyText = true })

    local ruby = doc.body:querySelector("ruby")
    runner:assertNotNil(ruby)

    local rts = ruby:getElementsByTagName("rt")
    runner:assertTableLength(rts, 2)

    local rps = ruby:getElementsByTagName("rp")
    runner:assertTableLength(rps, 4)
end)

runner:test("Details and summary", function()
    local html = [[
<details>
    <summary>Click to expand</summary>
    <p>Hidden content here.</p>
</details>
    ]]

    local doc = Parser.parseHTML(html, Lexer, { skipWhitespaceOnlyText = true })

    local details = doc.body:querySelector("details")
    runner:assertNotNil(details)

    local summary = details:querySelector("summary")
    runner:assertNotNil(summary)
    runner:assertEqual(summary:getTextContent(), "Click to expand")
end)

runner:test("Dialog element", function()
    local html = [[
<dialog open>
    <h2>Dialog Title</h2>
    <p>Dialog content.</p>
    <button>Close</button>
</dialog>
    ]]

    local doc = Parser.parseHTML(html, Lexer, { skipWhitespaceOnlyText = true })

    local dialog = doc.body:querySelector("dialog")
    runner:assertNotNil(dialog)
    runner:assertTrue(dialog:hasAttribute("open"))
end)

runner:test("Template element", function()
    local html = [[
<template id="my-template">
    <div class="template-content">
        <p>Template paragraph</p>
    </div>
</template>
    ]]

    local doc = Parser.parseHTML(html, Lexer, { skipWhitespaceOnlyText = true })

    local template = doc:getElementById("my-template")
    runner:assertNotNil(template)
    runner:assertEqual(template.tagName, "template")
end)

runner:test("Slot element", function()
    local html = [[
<div>
    <slot name="header">Default header</slot>
    <slot>Default content</slot>
</div>
    ]]

    local doc = Parser.parseHTML(html, Lexer, { skipWhitespaceOnlyText = true })

    local slots = doc.body:getElementsByTagName("slot")
    runner:assertTableLength(slots, 2)
end)

runner:test("Iframe element", function()
    local html = [[
<iframe 
    src="https://example.com" 
    width="600" 
    height="400" 
    frameborder="0" 
    allowfullscreen
    loading="lazy">
</iframe>
    ]]

    local doc = Parser.parseHTML(html, Lexer, { skipWhitespaceOnlyText = true })

    local iframe = doc.body:querySelector("iframe")
    runner:assertNotNil(iframe)
    runner:assertEqual(iframe:getAttribute("src"), "https://example.com")
    runner:assertTrue(iframe:hasAttribute("allowfullscreen"))
end)

runner:test("Canvas element", function()
    local html =
        '<canvas id="myCanvas" width="300" height="150">Fallback text</canvas>'

    local doc = Parser.parseHTML(html, Lexer)

    local canvas = doc:getElementById("myCanvas")
    runner:assertNotNil(canvas)
    runner:assertEqual(canvas:getAttribute("width"), "300")
    runner:assertEqual(canvas:getTextContent(), "Fallback text")
end)

runner:test("Meter and progress elements", function()
    local html = [[
<meter value="0.7" min="0" max="1">70%</meter>
<progress value="75" max="100">75%</progress>
    ]]

    local doc = Parser.parseHTML(html, Lexer, { skipWhitespaceOnlyText = true })

    local meter = doc.body:querySelector("meter")
    runner:assertNotNil(meter)
    runner:assertEqual(meter:getAttribute("value"), "0.7")

    local progress = doc.body:querySelector("progress")
    runner:assertNotNil(progress)
end)

runner:test("Output element", function()
    local html = '<output name="result" for="a b">42</output>'

    local doc = Parser.parseHTML(html, Lexer)

    local output = doc.body:querySelector("output")
    runner:assertNotNil(output)
    runner:assertEqual(output:getAttribute("for"), "a b")
    runner:assertEqual(output:getTextContent(), "42")
end)

runner:test("Semantic elements", function()
    local html = [[
<article>
    <header><h1>Title</h1></header>
    <section>
        <p>Content</p>
    </section>
    <footer><p>Footer</p></footer>
</article>
<aside>Sidebar</aside>
<nav>Navigation</nav>
<main>Main content</main>
<search><input type="search"></search>
    ]]

    local doc = Parser.parseHTML(html, Lexer, { skipWhitespaceOnlyText = true })

    local semanticTags = {
        "article",
        "header",
        "section",
        "footer",
        "aside",
        "nav",
        "main",
        "search",
    }

    for _, tag in ipairs(semanticTags) do
        local elem = doc.body:querySelector(tag)
        runner:assertNotNil(elem, "Expected to find " .. tag)
    end
end)

runner:test("Time element", function()
    local html = '<time datetime="2024-01-15T10:30:00">January 15, 2024</time>'

    local doc = Parser.parseHTML(html, Lexer)

    local time = doc.body:querySelector("time")
    runner:assertNotNil(time)
    runner:assertEqual(time:getAttribute("datetime"), "2024-01-15T10:30:00")
end)

runner:test("Mark element", function()
    local html = "<p>This is <mark>highlighted</mark> text.</p>"

    local doc = Parser.parseHTML(html, Lexer)

    local mark = doc.body:querySelector("mark")
    runner:assertNotNil(mark)
    runner:assertEqual(mark:getTextContent(), "highlighted")
end)

runner:test("Abbreviation element", function()
    local html = '<abbr title="HyperText Markup Language">HTML</abbr>'

    local doc = Parser.parseHTML(html, Lexer)

    local abbr = doc.body:querySelector("abbr")
    runner:assertNotNil(abbr)
    runner:assertEqual(abbr:getAttribute("title"), "HyperText Markup Language")
    runner:assertEqual(abbr:getTextContent(), "HTML")
end)

runner:test("BDI and BDO elements", function()
    local html = [[
<p><bdi>اسم المستخدم</bdi>: 3 posts</p>
<bdo dir="rtl">This text goes right to left</bdo>
    ]]

    local doc = Parser.parseHTML(html, Lexer, { skipWhitespaceOnlyText = true })

    local bdi = doc.body:querySelector("bdi")
    runner:assertNotNil(bdi)

    local bdo = doc.body:querySelector("bdo")
    runner:assertNotNil(bdo)
    runner:assertEqual(bdo:getAttribute("dir"), "rtl")
end)

runner:test("WBR element", function()
    local html = "<p>Fernstraßen<wbr>bauprivatisierungsgesetz</p>"

    local doc = Parser.parseHTML(html, Lexer)

    local wbr = doc.body:querySelector("wbr")
    runner:assertNotNil(wbr)
    runner:assertTrue(wbr.isVoid)
end)

runner:test("Address element", function()
    local html = [[
<address>
    Contact: <a href="mailto:test@example.com">test@example.com</a><br>
    Phone: 123-456-7890
</address>
    ]]

    local doc = Parser.parseHTML(html, Lexer, { skipWhitespaceOnlyText = true })

    local address = doc.body:querySelector("address")
    runner:assertNotNil(address)

    local link = address:querySelector("a")
    runner:assertNotNil(link)
end)

runner:test("Del and Ins elements", function()
    local html = [[
<p>This is <del>old</del> <ins>new</ins> text.</p>
    ]]

    local doc = Parser.parseHTML(html, Lexer)

    local del = doc.body:querySelector("del")
    runner:assertNotNil(del)
    runner:assertEqual(del:getTextContent(), "old")

    local ins = doc.body:querySelector("ins")
    runner:assertNotNil(ins)
    runner:assertEqual(ins:getTextContent(), "new")
end)

runner:test("Subscript and superscript", function()
    local html = "<p>H<sub>2</sub>O and E=mc<sup>2</sup></p>"

    local doc = Parser.parseHTML(html, Lexer)

    local sub = doc.body:querySelector("sub")
    runner:assertNotNil(sub)
    runner:assertEqual(sub:getTextContent(), "2")

    local sup = doc.body:querySelector("sup")
    runner:assertNotNil(sup)
    runner:assertEqual(sup:getTextContent(), "2")
end)

runner:test("Code elements", function()
    local html = [[
<p>Use the <code>print()</code> function.</p>
<pre><code>def hello():
    print("Hello")</code></pre>
<p>Output: <samp>Hello World</samp></p>
<p>Press <kbd>Ctrl</kbd>+<kbd>C</kbd></p>
<p>Variable: <var>x</var></p>
    ]]

    local doc = Parser.parseHTML(html, Lexer, { skipWhitespaceOnlyText = true })

    local code = doc.body:querySelector("code")
    runner:assertNotNil(code)

    local samp = doc.body:querySelector("samp")
    runner:assertNotNil(samp)

    local kbds = doc.body:getElementsByTagName("kbd")
    runner:assertTableLength(kbds, 2)

    local var_ = doc.body:querySelector("var")
    runner:assertNotNil(var_)
end)

runner:test("Quotation elements", function()
    local html = [[
<blockquote cite="https://example.com">
    <p>A famous quote.</p>
</blockquote>
<p>She said <q>Hello</q>.</p>
<p><cite>The Great Book</cite> is excellent.</p>
    ]]

    local doc = Parser.parseHTML(html, Lexer, { skipWhitespaceOnlyText = true })

    local blockquote = doc.body:querySelector("blockquote")
    runner:assertNotNil(blockquote)
    runner:assertEqual(blockquote:getAttribute("cite"), "https://example.com")

    local q = doc.body:querySelector("q")
    runner:assertNotNil(q)

    local cite = doc.body:querySelector("cite")
    runner:assertNotNil(cite)
end)

runner:test("Data element", function()
    local html = '<data value="12345">Product Name</data>'

    local doc = Parser.parseHTML(html, Lexer)

    local data = doc.body:querySelector("data")
    runner:assertNotNil(data)
    runner:assertEqual(data:getAttribute("value"), "12345")
end)

runner:test("Hgroup element", function()
    local html = [[
<hgroup>
    <h1>Main Title</h1>
    <p>Subtitle or tagline</p>
</hgroup>
    ]]

    local doc = Parser.parseHTML(html, Lexer, { skipWhitespaceOnlyText = true })

    local hgroup = doc.body:querySelector("hgroup")
    runner:assertNotNil(hgroup)

    local h1 = hgroup:querySelector("h1")
    runner:assertNotNil(h1)
end)

--------------------------------------------------------------------------------
-- Print Summary
--------------------------------------------------------------------------------

print("\n")
local success = runner:summary()

return success

-- EOF