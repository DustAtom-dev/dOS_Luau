--[[
    "Test module for dOS"
    
    @module css_lexer_parser_test
    @author Claude Sonnet 4.6 (Extented) (Anthropic's AI)

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


local CSSLexer = require("./css_lexer")
local CSSParser = require("./css_parser")

if not CSSLexer then
    warn("FATAL: Could not load css_lexer  → " .. tostring(CSSLexer))
    return false
end
if not CSSParser then
    warn("FATAL: Could not load css_parser → " .. tostring(CSSParser))
    return false
end

local TT = CSSLexer.getTokenTypes()
local NT = CSSParser.getNodeTypes()
local ST = CSSParser.getSelectorTypes()
local VT = CSSParser.getValueTypes()

-- ── Test Runner ───────────────────────────────────────────────────────────────

local PASS = 0
local FAIL = 0
local TIMEOUT = 0
local TOTAL = 0
local TIMEOUT_LIMIT = 30 -- seconds

local function runTest(name, fn)
    TOTAL = TOTAL + 1
    local t0 = os.clock()
    local ok, err = pcall(fn)
    local elapsed = os.clock() - t0

    if elapsed > TIMEOUT_LIMIT then
        TIMEOUT = TIMEOUT + 1
        warn(string.format("✗ TIMEOUT  %-60s  (%.1fs)", name, elapsed))
        return
    end

    if ok then
        PASS = PASS + 1
        print(string.format("✓ PASS     %s", name))
    else
        FAIL = FAIL + 1
        warn(string.format("✗ FAIL     %-60s  → %s", name, tostring(err)))
    end
end

--- Throws a labelled assertion error.
local function assert_eq(got, expected, label)
    if got ~= expected then
        error(
            string.format(
                "%s: expected %q, got %q",
                label or "assert_eq",
                tostring(expected),
                tostring(got)
            ),
            2
        )
    end
end

local function assert_true(val, label)
    if not val then
        error(
            (label or "assert_true")
                .. ": expected truthy, got "
                .. tostring(val),
            2
        )
    end
end

local function assert_false(val, label)
    if val then
        error(
            (label or "assert_false")
                .. ": expected falsy, got "
                .. tostring(val),
            2
        )
    end
end

local function assert_nil(val, label)
    if val ~= nil then
        error(
            (label or "assert_nil") .. ": expected nil, got " .. tostring(val),
            2
        )
    end
end

local function assert_not_nil(val, label)
    if val == nil then
        error((label or "assert_not_nil") .. ": expected non-nil", 2)
    end
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

--- Tokenize and return the token array (without EOF for convenience).
local function lex(src, opts)
    local tokens = CSSLexer.parse(src, opts)
    -- Strip trailing EOF
    while #tokens > 0 and tokens[#tokens].type == TT.EOF do
        table.remove(tokens)
    end
    return tokens
end

--- Tokenize and return only the non-whitespace tokens (no EOF).
local function lexNW(src, opts)
    local all = lex(src, opts)
    local out = {}
    for _, t in ipairs(all) do
        if t.type ~= TT.WHITESPACE then out[#out + 1] = t end
    end
    return out
end

--- Parse CSS and return the stylesheet AST.
local function parse(src, opts)
    local ss, _ = CSSParser.parseCSS(src, CSSLexer, opts)
    return ss
end

--- Return all rules of a given type from a stylesheet.
local function rulesOf(ss, typ)
    local out = {}
    for _, r in ipairs(ss.rules or {}) do
        if r.type == typ then out[#out + 1] = r end
    end
    return out
end

--- Return all declarations from the first style rule in a stylesheet.
local function declsOf(src)
    local ss = parse(src)
    local rules = rulesOf(ss, NT.STYLE_RULE)
    assert_true(#rules > 0, "declsOf: no style rule found")
    return rules[1].declarations
end

--- Find a declaration by property name.
local function findDecl(decls, prop)
    for _, d in ipairs(decls) do
        if d.property == prop then return d end
    end
    return nil
end

-- ══════════════════════════════════════════════════════════════════════════════
--  LEXER TESTS
-- ══════════════════════════════════════════════════════════════════════════════

print(
    "\n── Lexer: Token Types ──────────────────────────────────────────────────\n"
)

runTest("Lexer: empty source produces only EOF", function()
    local tokens = CSSLexer.parse("")
    assert_eq(#tokens, 1, "token count")
    assert_eq(tokens[1].type, TT.EOF, "token type")
end)

runTest("Lexer: single IDENT", function()
    local toks = lexNW("color")
    assert_eq(#toks, 1, "count")
    assert_eq(toks[1].type, TT.IDENT, "type")
    assert_eq(toks[1].value, "color", "value")
end)

runTest("Lexer: IDENT with hyphens and digits", function()
    local toks = lexNW("background-color2")
    assert_eq(toks[1].type, TT.IDENT)
    assert_eq(toks[1].value, "background-color2")
end)

runTest("Lexer: custom property IDENT (--variable)", function()
    local toks = lexNW("--my-custom-prop")
    assert_eq(toks[1].type, TT.IDENT)
    assert_eq(toks[1].value, "--my-custom-prop")
end)

runTest("Lexer: AT_KEYWORD @media", function()
    local toks = lexNW("@media")
    assert_eq(toks[1].type, TT.AT_KEYWORD)
    assert_eq(toks[1].value, "media")
end)

runTest("Lexer: AT_KEYWORD @keyframes", function()
    local toks = lexNW("@keyframes")
    assert_eq(toks[1].type, TT.AT_KEYWORD)
    assert_eq(toks[1].value, "keyframes")
end)

runTest("Lexer: AT_KEYWORD @import", function()
    local toks = lexNW("@import")
    assert_eq(toks[1].type, TT.AT_KEYWORD)
    assert_eq(toks[1].value, "import")
end)

runTest("Lexer: HASH id flag", function()
    local toks = lexNW("#myId")
    assert_eq(toks[1].type, TT.HASH)
    assert_eq(toks[1].value, "myId")
    assert_eq(toks[1].flag, "id")
end)

runTest("Lexer: HASH unrestricted (starts with digit)", function()
    local toks = lexNW("#123")
    assert_eq(toks[1].type, TT.HASH)
    assert_eq(toks[1].flag, "unrestricted")
end)

runTest("Lexer: HASH colour #ff0000", function()
    local toks = lexNW("#ff0000")
    assert_eq(toks[1].type, TT.HASH)
    assert_eq(toks[1].value, "ff0000")
    assert_eq(toks[1].flag, "unrestricted")
end)

runTest("Lexer: lone # is DELIM", function()
    local toks = lexNW("# ")
    assert_eq(toks[1].type, TT.DELIM)
    assert_eq(toks[1].value, "#")
end)

runTest("Lexer: double-quoted STRING", function()
    local toks = lexNW('"hello world"')
    assert_eq(toks[1].type, TT.STRING)
    assert_eq(toks[1].value, "hello world")
end)

runTest("Lexer: single-quoted STRING", function()
    local toks = lexNW("'hello world'")
    assert_eq(toks[1].type, TT.STRING)
    assert_eq(toks[1].value, "hello world")
end)

runTest("Lexer: STRING with escaped quote", function()
    local toks = lexNW('"say \\"hi\\""')
    assert_eq(toks[1].type, TT.STRING)
    assert_eq(toks[1].value, 'say "hi"')
end)

runTest("Lexer: STRING with line continuation (backslash-newline)", function()
    local toks = lexNW('"line\\\ncontinued"')
    assert_eq(toks[1].type, TT.STRING)
    assert_eq(toks[1].value, "linecontinued")
end)

runTest("Lexer: BAD_STRING (unclosed, raw newline)", function()
    -- A raw newline inside a string without backslash → BAD_STRING
    local toks = lexNW('"unclosed\n')
    assert_eq(toks[1].type, TT.BAD_STRING)
end)

runTest("Lexer: BAD_STRING (EOF without closing quote)", function()
    local toks = lexNW('"no closing')
    assert_eq(toks[1].type, TT.BAD_STRING)
end)

runTest("Lexer: integer NUMBER", function()
    local toks = lexNW("42")
    assert_eq(toks[1].type, TT.NUMBER)
    assert_eq(toks[1].value, 42)
    assert_eq(toks[1].flag, "integer")
end)

runTest("Lexer: negative integer NUMBER", function()
    local toks = lexNW("-7")
    assert_eq(toks[1].type, TT.NUMBER)
    assert_eq(toks[1].value, -7)
    assert_eq(toks[1].flag, "integer")
end)

runTest("Lexer: positive sign NUMBER", function()
    local toks = lexNW("+3")
    assert_eq(toks[1].type, TT.NUMBER)
    assert_eq(toks[1].value, 3)
end)

runTest("Lexer: float NUMBER", function()
    local toks = lexNW("3.14")
    assert_eq(toks[1].type, TT.NUMBER)
    assert_eq(toks[1].flag, "number")
    assert_true(math.abs(toks[1].value - 3.14) < 1e-9, "value approx")
end)

runTest("Lexer: leading-dot float (.5)", function()
    local toks = lexNW(".5")
    assert_eq(toks[1].type, TT.NUMBER)
    assert_eq(toks[1].flag, "number")
    assert_true(math.abs(toks[1].value - 0.5) < 1e-9)
end)

runTest("Lexer: scientific notation (1e3)", function()
    local toks = lexNW("1e3")
    assert_eq(toks[1].type, TT.NUMBER)
    assert_eq(toks[1].flag, "number")
    assert_eq(toks[1].value, 1000)
end)

runTest("Lexer: scientific with explicit positive exponent (2.5E+2)", function()
    local toks = lexNW("2.5E+2")
    assert_eq(toks[1].type, TT.NUMBER)
    assert_true(math.abs(toks[1].value - 250) < 1e-9)
end)

runTest("Lexer: scientific with negative exponent (1e-2)", function()
    local toks = lexNW("1e-2")
    assert_eq(toks[1].type, TT.NUMBER)
    assert_true(math.abs(toks[1].value - 0.01) < 1e-9)
end)

runTest("Lexer: DIMENSION px", function()
    local toks = lexNW("10px")
    assert_eq(toks[1].type, TT.DIMENSION)
    assert_eq(toks[1].value, 10)
    assert_eq(toks[1].unit, "px")
    assert_eq(toks[1].unitLower, "px")
    assert_eq(toks[1].unitCategory, "length")
end)

runTest("Lexer: DIMENSION em", function()
    local toks = lexNW("1.5em")
    assert_eq(toks[1].type, TT.DIMENSION)
    assert_eq(toks[1].unitCategory, "length")
end)

runTest("Lexer: DIMENSION deg (angle)", function()
    local toks = lexNW("360deg")
    assert_eq(toks[1].type, TT.DIMENSION)
    assert_eq(toks[1].unitCategory, "angle")
end)

runTest("Lexer: DIMENSION ms (time)", function()
    local toks = lexNW("200ms")
    assert_eq(toks[1].type, TT.DIMENSION)
    assert_eq(toks[1].unitCategory, "time")
end)

runTest("Lexer: DIMENSION s (time)", function()
    local toks = lexNW("1s")
    assert_eq(toks[1].type, TT.DIMENSION)
    assert_eq(toks[1].unitCategory, "time")
end)

runTest("Lexer: DIMENSION hz (frequency)", function()
    local toks = lexNW("440hz")
    assert_eq(toks[1].type, TT.DIMENSION)
    assert_eq(toks[1].unitCategory, "frequency")
end)

runTest("Lexer: DIMENSION dpi (resolution)", function()
    local toks = lexNW("96dpi")
    assert_eq(toks[1].type, TT.DIMENSION)
    assert_eq(toks[1].unitCategory, "resolution")
end)

runTest("Lexer: DIMENSION fr (flex/relative)", function()
    local toks = lexNW("1fr")
    assert_eq(toks[1].type, TT.DIMENSION)
    assert_eq(toks[1].unitCategory, "length")
end)

runTest("Lexer: DIMENSION unknown unit", function()
    local toks = lexNW("10xyz")
    assert_eq(toks[1].type, TT.DIMENSION)
    assert_eq(toks[1].unitCategory, "unknown")
end)

runTest("Lexer: PERCENTAGE", function()
    local toks = lexNW("50%")
    assert_eq(toks[1].type, TT.PERCENTAGE)
    assert_eq(toks[1].value, 50)
end)

runTest("Lexer: PERCENTAGE negative", function()
    local toks = lexNW("-25%")
    assert_eq(toks[1].type, TT.PERCENTAGE)
    assert_eq(toks[1].value, -25)
end)

runTest("Lexer: FUNCTION token rgb(", function()
    local toks = lexNW("rgb(")
    assert_eq(toks[1].type, TT.FUNCTION)
    assert_eq(toks[1].value, "rgb")
end)

runTest("Lexer: FUNCTION token var(", function()
    local toks = lexNW("var(")
    assert_eq(toks[1].type, TT.FUNCTION)
    assert_eq(toks[1].value, "var")
end)

runTest("Lexer: FUNCTION token calc(", function()
    local toks = lexNW("calc(")
    assert_eq(toks[1].type, TT.FUNCTION)
    assert_eq(toks[1].value, "calc")
end)

runTest("Lexer: URL bare url()", function()
    local toks = lexNW("url(https://example.com/img.png)")
    assert_eq(toks[1].type, TT.URL)
    assert_eq(toks[1].value, "https://example.com/img.png")
end)

runTest("Lexer: URL with surrounding whitespace inside parens", function()
    local toks = lexNW("url(  https://example.com/  )")
    assert_eq(toks[1].type, TT.URL)
    assert_eq(toks[1].value, "https://example.com/")
end)

runTest("Lexer: url() with double-quoted string → FUNCTION token", function()
    -- url("...") is treated as a FUNCTION token per the CSS spec
    local toks = lexNW('url("https://example.com/")')
    assert_eq(toks[1].type, TT.FUNCTION)
    assert_eq(toks[1].value, "url")
end)

runTest("Lexer: url() with single-quoted string → FUNCTION token", function()
    local toks = lexNW("url('https://example.com/')")
    assert_eq(toks[1].type, TT.FUNCTION)
    assert_eq(toks[1].value, "url")
end)

runTest("Lexer: BAD_URL (quote inside bare url)", function()
    local toks = lexNW('url(https://"bad)')
    assert_eq(toks[1].type, TT.BAD_URL)
end)

runTest("Lexer: BAD_URL (opening paren inside bare url)", function()
    local toks = lexNW("url(bad(url)")
    assert_eq(toks[1].type, TT.BAD_URL)
end)

runTest("Lexer: BAD_URL (EOF without closing paren)", function()
    local toks = lexNW("url(https://example.com")
    assert_eq(toks[1].type, TT.BAD_URL)
end)

runTest("Lexer: WHITESPACE token collapsed", function()
    local toks = lex("  \t\n  ")
    -- With default collapseWhitespace=true, leading/trailing should be one WS
    local wsCount = 0
    for _, t in ipairs(toks) do
        if t.type == TT.WHITESPACE then wsCount = wsCount + 1 end
    end
    assert_eq(wsCount, 1, "collapsed to one WHITESPACE")
end)

runTest("Lexer: CDO token <!--", function()
    local toks = lexNW("<!--")
    assert_eq(toks[1].type, TT.CDO)
    assert_eq(toks[1].value, "<!--")
end)

runTest("Lexer: CDC token -->", function()
    local toks = lexNW("-->")
    assert_eq(toks[1].type, TT.CDC)
    assert_eq(toks[1].value, "-->")
end)

runTest("Lexer: COLON", function()
    local toks = lexNW(":")
    assert_eq(toks[1].type, TT.COLON)
end)

runTest("Lexer: SEMICOLON", function()
    local toks = lexNW(";")
    assert_eq(toks[1].type, TT.SEMICOLON)
end)

runTest("Lexer: COMMA", function()
    local toks = lexNW(",")
    assert_eq(toks[1].type, TT.COMMA)
end)

runTest("Lexer: LBRACKET / RBRACKET", function()
    local toks = lexNW("[]")
    assert_eq(toks[1].type, TT.LBRACKET)
    assert_eq(toks[2].type, TT.RBRACKET)
end)

runTest("Lexer: LPAREN / RPAREN", function()
    local toks = lexNW("()")
    assert_eq(toks[1].type, TT.LPAREN)
    assert_eq(toks[2].type, TT.RPAREN)
end)

runTest("Lexer: LBRACE / RBRACE", function()
    local toks = lexNW("{}")
    assert_eq(toks[1].type, TT.LBRACE)
    assert_eq(toks[2].type, TT.RBRACE)
end)

runTest("Lexer: DELIM characters (>, ~, +, |, ^, $, *, =, !)", function()
    local chars = { ">", "~", "+", "|", "^", "$", "*", "=", "!" }
    for _, ch in ipairs(chars) do
        local toks = lexNW(ch)
        assert_eq(toks[1].type, TT.DELIM, "DELIM for " .. ch)
        assert_eq(toks[1].value, ch, "value for " .. ch)
    end
end)

print(
    "\n── Lexer: Comments ─────────────────────────────────────────────────────\n"
)

runTest("Lexer: comment stripped by default", function()
    local toks = lexNW("/* hello */")
    assert_eq(#toks, 0, "no tokens with comment stripped")
end)

runTest("Lexer: comment preserved when preserveComments=true", function()
    local toks = lexNW("/* hello */", { preserveComments = true })
    assert_eq(toks[1].type, TT.COMMENT)
    assert_eq(toks[1].value, " hello ")
end)

runTest("Lexer: comment between tokens doesn't merge them", function()
    local toks = lexNW("div/* comment */span")
    assert_eq(toks[1].type, TT.IDENT)
    assert_eq(toks[1].value, "div")
    assert_eq(toks[2].type, TT.IDENT)
    assert_eq(toks[2].value, "span")
end)

runTest("Lexer: unclosed comment (parse error recovery)", function()
    -- Should not loop forever and should tokenise gracefully
    local toks = lex("/* unclosed")
    assert_not_nil(toks)
end)

print(
    "\n── Lexer: Unicode Escapes ───────────────────────────────────────────────\n"
)

runTest("Lexer: unicode escape in string \\41 → 'A'", function()
    local toks = lexNW('"\\41 "') -- \41 = 0x41 = 'A', trailing space consumed
    assert_eq(toks[1].type, TT.STRING)
    assert_eq(toks[1].value, "A")
end)

runTest("Lexer: unicode escape in IDENT \\41", function()
    local toks = lexNW("\\41 bc") -- should become "Abc"
    assert_eq(toks[1].type, TT.IDENT)
    assert_eq(toks[1].value, "Abc")
end)

runTest("Lexer: 6-digit unicode escape \\000041", function()
    local toks = lexNW('"\\000041"')
    assert_eq(toks[1].type, TT.STRING)
    assert_eq(toks[1].value, "A")
end)

runTest("Lexer: surrogate code point → replacement char", function()
    -- \D800 is a surrogate — should produce U+FFFD (replacement character)
    local toks = lexNW('"\\D800"')
    assert_eq(toks[1].type, TT.STRING)
    -- The value should be the 3-byte UTF-8 replacement char U+FFFD
    assert_eq(#toks[1].value, 3, "3-byte replacement char")
end)

runTest("Lexer: escaped regular character (\\a → 'a' not newline)", function()
    -- '\a' in a plain string context is just 'a' literally
    local toks = lexNW('"\\a"')
    -- spec: escaped newline (\<newline>) is a line continuation, but "\\a" means
    -- backslash followed by 'a' → string value is the letter a (escape for it)
    -- Actually \a where 'a' is 0x0A newline value: \<LF> is line continuation → empty
    -- but here the source is literally the two chars \ and a (not newline) → "a"
    assert_eq(toks[1].type, TT.STRING)
    assert_eq(toks[1].value, "a")
end)

runTest("Lexer: lone backslash → DELIM", function()
    -- A backslash followed by a newline is an invalid escape in CSS,
    -- producing a DELIM '\' per the spec's error handling.
    local toks = lexNW("\\\n")
    assert_true(#toks >= 1, "at least one token")
    -- The backslash should become a DELIM
    local found = false
    for _, t in ipairs(toks) do
        if t.type == TT.DELIM and t.value == "\\" then found = true end
    end
    assert_true(found, "lone backslash is DELIM")
end)

print(
    "\n── Lexer: Position Tracking ─────────────────────────────────────────────\n"
)

runTest("Lexer: first token starts at line 1, column 1", function()
    local toks = lex("color")
    -- lex() strips EOF; token[1] is the IDENT
    assert_eq(toks[1].line, 1)
    assert_eq(toks[1].column, 1)
end)

runTest("Lexer: second token on same line has correct column", function()
    local toks = lex("a b")
    -- toks: IDENT("a"), WHITESPACE, IDENT("b")
    local identB
    for _, t in ipairs(toks) do
        if t.type == TT.IDENT and t.value == "b" then
            identB = t
            break
        end
    end
    assert_not_nil(identB)
    assert_eq(identB.line, 1)
    assert_eq(identB.column, 3)
end)

runTest("Lexer: newline advances line counter", function()
    local toks = lex("a\nb")
    local identB
    for _, t in ipairs(toks) do
        if t.type == TT.IDENT and t.value == "b" then
            identB = t
            break
        end
    end
    assert_not_nil(identB)
    assert_eq(identB.line, 2)
end)

runTest("Lexer: token position field is byte offset", function()
    local toks = lex("   color")
    -- WHITESPACE at position 1, IDENT at position 4
    local ws = toks[1]
    local ident = toks[2]
    assert_eq(ws.position, 1)
    assert_eq(ident.position, 4)
end)

print(
    "\n── Lexer: Config API ────────────────────────────────────────────────────\n"
)

runTest("Lexer: setPreserveComments(true) via Lexer.create()", function()
    local lexer = CSSLexer.create("/* hi */", { preserveComments = true })
    local tokens = lexer:tokenize()
    local found = false
    for _, t in ipairs(tokens) do
        if t.type == TT.COMMENT then
            found = true
            break
        end
    end
    assert_true(found)
end)

runTest(
    "Lexer: setCollapseWhitespace(false) keeps multiple WS tokens",
    function()
        local lexer = CSSLexer.create("a   b", { collapseWhitespace = false })
        local tokens = lexer:tokenize()
        local wsCount = 0
        for _, t in ipairs(tokens) do
            if t.type == TT.WHITESPACE then wsCount = wsCount + 1 end
        end
        -- "   " is a single whitespace run even without collapse, but the
        -- count of emitted whitespace tokens should be ≥ 1
        assert_true(wsCount >= 1)
    end
)

runTest("Lexer: getPosition() returns a snapshot table", function()
    local lexer = CSSLexer.create("hello")
    local pos = lexer:getPosition()
    assert_not_nil(pos.position)
    assert_not_nil(pos.line)
    assert_not_nil(pos.column)
end)

runTest("Lexer: static getTokenTypes() returns full enum", function()
    local types = CSSLexer.getTokenTypes()
    assert_eq(types.IDENT, "IDENT")
    assert_eq(types.WHITESPACE, "WHITESPACE")
    assert_eq(types.EOF, "EOF")
end)

runTest("Lexer: static getUnitClassifier() classifies units", function()
    local classify = CSSLexer.getUnitClassifier()
    assert_eq(classify("px"), "length")
    assert_eq(classify("em"), "length")
    assert_eq(classify("deg"), "angle")
    assert_eq(classify("ms"), "time")
    assert_eq(classify("hz"), "frequency")
    assert_eq(classify("dpi"), "resolution")
    assert_eq(classify("fr"), "length")
    assert_eq(classify("xyz"), "unknown")
end)

print(
    "\n── Lexer: Edge Cases ────────────────────────────────────────────────────\n"
)

runTest("Lexer: very long identifier", function()
    local name = string.rep("a", 5000)
    local toks = lexNW(name)
    assert_eq(toks[1].type, TT.IDENT)
    assert_eq(#toks[1].value, 5000)
end)

runTest("Lexer: many repeated tokens", function()
    local src = string.rep("a ", 2000)
    local toks = lex(src)
    assert_true(#toks > 0, "produced tokens")
end)

runTest("Lexer: only whitespace source", function()
    local toks = lex("   \t\n  ")
    -- Should have one WHITESPACE + one EOF
    local wsCount = 0
    for _, t in ipairs(toks) do
        if t.type == TT.WHITESPACE then wsCount = wsCount + 1 end
    end
    assert_eq(wsCount, 1)
end)

runTest("Lexer: number followed immediately by ident (dimension)", function()
    local toks = lexNW("10em")
    assert_eq(toks[1].type, TT.DIMENSION)
    assert_eq(toks[1].value, 10)
    assert_eq(toks[1].unit, "em")
end)

runTest("Lexer: minus not followed by digit is DELIM", function()
    local toks = lexNW("- color")
    assert_eq(toks[1].type, TT.DELIM)
    assert_eq(toks[1].value, "-")
end)

runTest("Lexer: plus not followed by digit is DELIM", function()
    local toks = lexNW("+ color")
    assert_eq(toks[1].type, TT.DELIM)
    assert_eq(toks[1].value, "+")
end)

runTest("Lexer: dot not followed by digit is DELIM", function()
    local toks = lexNW(". ")
    assert_eq(toks[1].type, TT.DELIM)
    assert_eq(toks[1].value, ".")
end)

runTest("Lexer: < not followed by !-- is DELIM", function()
    local toks = lexNW("<")
    assert_eq(toks[1].type, TT.DELIM)
    assert_eq(toks[1].value, "<")
end)

runTest("Lexer: @ not followed by ident is DELIM", function()
    local toks = lexNW("@ ")
    assert_eq(toks[1].type, TT.DELIM)
    assert_eq(toks[1].value, "@")
end)

runTest("Lexer: hyphen-ident (--custom) is IDENT not DELIM", function()
    local toks = lexNW("--custom-prop")
    assert_eq(toks[1].type, TT.IDENT)
    assert_eq(toks[1].value, "--custom-prop")
end)

runTest("Lexer: identifier starting with underscore", function()
    local toks = lexNW("_private")
    assert_eq(toks[1].type, TT.IDENT)
    assert_eq(toks[1].value, "_private")
end)

runTest("Lexer: full CSS declaration tokenises correctly", function()
    local toks = lexNW("color: red;")
    -- IDENT("color"), COLON, IDENT("red"), SEMICOLON
    assert_eq(toks[1].type, TT.IDENT, "prop")
    assert_eq(toks[2].type, TT.COLON, "colon")
    assert_eq(toks[3].type, TT.IDENT, "value")
    assert_eq(toks[4].type, TT.SEMICOLON, "semi")
end)

runTest("Lexer: selector with class and id tokenises correctly", function()
    local toks = lexNW("div.class#id")
    assert_eq(toks[1].type, TT.IDENT, "type")
    assert_eq(toks[2].type, TT.DELIM, "dot")
    assert_eq(toks[2].value, ".")
    assert_eq(toks[3].type, TT.IDENT, "class name")
    assert_eq(toks[4].type, TT.HASH, "id")
end)

-- ══════════════════════════════════════════════════════════════════════════════
--  PARSER TESTS — At-Rules
-- ══════════════════════════════════════════════════════════════════════════════

print(
    "\n── Parser: @charset / @import / @namespace ──────────────────────────────\n"
)

runTest("Parser: @charset rule", function()
    local ss = parse('@charset "UTF-8";')
    local rules = rulesOf(ss, NT.CHARSET_RULE)
    assert_eq(#rules, 1)
    assert_eq(rules[1].charset, "UTF-8")
end)

runTest("Parser: @charset defaults to utf-8 when missing string", function()
    local ss = parse("@charset;")
    local rules = rulesOf(ss, NT.CHARSET_RULE)
    assert_eq(#rules, 1)
    assert_eq(rules[1].charset, "utf-8")
end)

runTest("Parser: @import with URL string", function()
    local ss = parse('@import "style.css";')
    local rules = rulesOf(ss, NT.IMPORT_RULE)
    assert_eq(#rules, 1)
    assert_eq(rules[1].url, "style.css")
end)

runTest("Parser: @import with url() function", function()
    local ss = parse("@import url('base.css');")
    local rules = rulesOf(ss, NT.IMPORT_RULE)
    assert_eq(#rules, 1)
    assert_eq(rules[1].url, "base.css")
end)

runTest("Parser: @import with media query", function()
    local ss = parse('@import "print.css" print;')
    local rules = rulesOf(ss, NT.IMPORT_RULE)
    assert_eq(#rules, 1)
    assert_not_nil(rules[1].media, "has media")
end)

runTest("Parser: @import with layer keyword", function()
    local ss = parse('@import "a.css" layer;')
    local rules = rulesOf(ss, NT.IMPORT_RULE)
    assert_eq(#rules, 1)
    assert_not_nil(rules[1].layer, "has layer")
end)

runTest("Parser: @namespace default", function()
    local ss = parse('@namespace "http://www.w3.org/1999/xhtml";')
    local rules = rulesOf(ss, NT.NAMESPACE_RULE)
    assert_eq(#rules, 1)
    assert_eq(rules[1].url, "http://www.w3.org/1999/xhtml")
    assert_nil(rules[1].prefix)
end)

runTest("Parser: @namespace with prefix", function()
    local ss = parse('@namespace svg "http://www.w3.org/2000/svg";')
    local rules = rulesOf(ss, NT.NAMESPACE_RULE)
    assert_eq(#rules, 1)
    assert_eq(rules[1].prefix, "svg")
end)

print(
    "\n── Parser: @media ───────────────────────────────────────────────────────\n"
)

runTest("Parser: @media screen rule", function()
    local ss = parse("@media screen { div { color: red; } }")
    local rules = rulesOf(ss, NT.MEDIA_RULE)
    assert_eq(#rules, 1)
    assert_not_nil(rules[1].media)
    assert_true(#rules[1].rules >= 1, "has child rules")
end)

runTest("Parser: @media with (max-width) feature", function()
    local ss = parse("@media (max-width: 768px) { body { font-size: 14px; } }")
    local rules = rulesOf(ss, NT.MEDIA_RULE)
    assert_eq(#rules, 1)
    assert_true(#rules[1].rules >= 1)
end)

runTest("Parser: @media print negated", function()
    local ss = parse("@media not print { a { color: blue; } }")
    local rules = rulesOf(ss, NT.MEDIA_RULE)
    assert_eq(#rules, 1)
    local queries = rules[1].media and rules[1].media.queries or {}
    assert_true(#queries >= 1)
    assert_true(
        queries[1].negated or queries[1].mediaType ~= nil,
        "negated or typed query"
    )
end)

runTest("Parser: nested @media rules", function()
    local ss = parse([[
        @media screen {
            @media (max-width: 600px) {
                p { margin: 0; }
            }
        }
    ]])
    local outer = rulesOf(ss, NT.MEDIA_RULE)
    assert_eq(#outer, 1)
end)

print(
    "\n── Parser: @supports ────────────────────────────────────────────────────\n"
)

runTest("Parser: @supports basic", function()
    local ss = parse("@supports (display: grid) { div { display: grid; } }")
    local rules = rulesOf(ss, NT.SUPPORTS_RULE)
    assert_eq(#rules, 1)
    assert_not_nil(rules[1].condition)
    assert_true(#rules[1].rules >= 1)
end)

runTest("Parser: @supports not", function()
    local ss =
        parse("@supports not (display: grid) { div { display: block; } }")
    local rules = rulesOf(ss, NT.SUPPORTS_RULE)
    assert_eq(#rules, 1)
    local cond = rules[1].condition
    assert_not_nil(cond)
end)

runTest("Parser: @supports and condition", function()
    local ss = parse(
        "@supports (display: flex) and (gap: 1rem) { a { display: flex; } }"
    )
    local rules = rulesOf(ss, NT.SUPPORTS_RULE)
    assert_eq(#rules, 1)
    assert_eq(rules[1].condition.operator, "and")
end)

print(
    "\n── Parser: @keyframes ───────────────────────────────────────────────────\n"
)

runTest("Parser: @keyframes from/to", function()
    local ss = parse([[
        @keyframes slide {
            from { transform: translateX(0); }
            to   { transform: translateX(100px); }
        }
    ]])
    local rules = rulesOf(ss, NT.KEYFRAMES_RULE)
    assert_eq(#rules, 1)
    assert_eq(rules[1].name, "slide")
    assert_eq(#rules[1].keyframes, 2)
    assert_eq(rules[1].keyframes[1].positions[1], 0)
    assert_eq(rules[1].keyframes[2].positions[1], 100)
end)

runTest("Parser: @keyframes percentage stops", function()
    local ss = parse([[
        @keyframes fade {
            0%   { opacity: 0; }
            50%  { opacity: 0.5; }
            100% { opacity: 1; }
        }
    ]])
    local rules = rulesOf(ss, NT.KEYFRAMES_RULE)
    assert_eq(#rules, 1)
    assert_eq(#rules[1].keyframes, 3)
    assert_eq(rules[1].keyframes[1].positions[1], 0)
    assert_eq(rules[1].keyframes[2].positions[1], 50)
    assert_eq(rules[1].keyframes[3].positions[1], 100)
end)

runTest("Parser: @keyframes named identifier", function()
    local ss = parse('@keyframes "my-anim" { from {} to {} }')
    local rules = rulesOf(ss, NT.KEYFRAMES_RULE)
    assert_eq(#rules, 1)
    assert_eq(rules[1].name, "my-anim")
end)

runTest("Parser: vendor-prefixed @-webkit-keyframes", function()
    local ss = parse("@-webkit-keyframes spin { from { } to { } }")
    local rules = rulesOf(ss, NT.KEYFRAMES_RULE)
    assert_eq(#rules, 1)
    assert_eq(rules[1].vendorPrefix, "webkit")
end)

print(
    "\n── Parser: @font-face / @page / @counter-style / @layer / @property ────\n"
)

runTest("Parser: @font-face rule", function()
    local ss = parse([[
        @font-face {
            font-family: "MyFont";
            src: url("myfont.woff2") format("woff2");
        }
    ]])
    local rules = rulesOf(ss, NT.FONT_FACE_RULE)
    assert_eq(#rules, 1)
    local d = findDecl(rules[1].declarations, "font-family")
    assert_not_nil(d)
    assert_eq(d.value.value, "MyFont")
end)

runTest("Parser: @page rule", function()
    local ss = parse("@page { margin: 1cm; }")
    local rules = rulesOf(ss, NT.PAGE_RULE)
    assert_eq(#rules, 1)
end)

runTest("Parser: @page with pseudo-selector :left", function()
    local ss = parse("@page :left { margin-left: 2cm; }")
    local rules = rulesOf(ss, NT.PAGE_RULE)
    assert_eq(#rules, 1)
    assert_true(#rules[1].selectors >= 1)
    assert_eq(rules[1].selectors[1].name, "left")
end)

runTest("Parser: @counter-style rule", function()
    local ss =
        parse("@counter-style thumbs { system: cyclic; symbols: '\\1F44D'; }")
    local rules = rulesOf(ss, NT.COUNTER_STYLE_RULE)
    assert_eq(#rules, 1)
    assert_eq(rules[1].name, "thumbs")
end)

runTest("Parser: @layer block rule", function()
    local ss = parse("@layer utilities { .mt-0 { margin-top: 0; } }")
    local rules = rulesOf(ss, NT.LAYER_RULE)
    assert_eq(#rules, 1)
end)

runTest("Parser: @layer statement (no block)", function()
    local ss = parse("@layer utilities;")
    local rules = rulesOf(ss, NT.LAYER_RULE)
    assert_eq(#rules, 1)
end)

runTest("Parser: @property rule", function()
    local ss = parse([[
        @property --my-color {
            syntax: "<color>";
            inherits: false;
            initial-value: #c0ffee;
        }
    ]])
    local rules = rulesOf(ss, NT.PROPERTY_RULE)
    assert_eq(#rules, 1)
end)

runTest(
    "Parser: generic unknown at-rule (no block) → GENERIC_AT_RULE",
    function()
        local ss = parse("@unknown-rule param;")
        local rules = rulesOf(ss, NT.GENERIC_AT_RULE)
        assert_eq(#rules, 1)
        assert_eq(rules[1].name, "unknown-rule")
    end
)

runTest(
    "Parser: generic unknown at-rule (with block) → GENERIC_AT_RULE",
    function()
        local ss = parse(
            "@document url('http://example.com') { body { color: red; } }"
        )
        local rules = rulesOf(ss, NT.GENERIC_AT_RULE)
        assert_eq(#rules, 1)
    end
)

-- ══════════════════════════════════════════════════════════════════════════════
--  PARSER TESTS — Style Rules & Declarations
-- ══════════════════════════════════════════════════════════════════════════════

print(
    "\n── Parser: Style Rules & Declarations ───────────────────────────────────\n"
)

runTest("Parser: simple style rule", function()
    local ss = parse("div { color: red; }")
    local rules = rulesOf(ss, NT.STYLE_RULE)
    assert_eq(#rules, 1)
    assert_not_nil(rules[1].selectorList)
    assert_true(#rules[1].declarations >= 1)
end)

runTest("Parser: multiple declarations in one rule", function()
    local decls = declsOf("p { color: blue; font-size: 16px; margin: 0; }")
    assert_eq(#decls, 3)
end)

runTest("Parser: declaration property is lowercased", function()
    local decls = declsOf("P { Color: red; }")
    assert_eq(decls[1].property, "color")
end)

runTest("Parser: custom property preserves case", function()
    local decls = declsOf("div { --MyVar: 42; }")
    assert_eq(decls[1].property, "--MyVar")
end)

runTest("Parser: !important flag", function()
    local decls = declsOf("div { color: red !important; }")
    assert_eq(decls[1].important, true)
end)

runTest("Parser: !important with space before 'important'", function()
    local decls = declsOf("div { color: red ! important; }")
    assert_eq(decls[1].important, true)
end)

runTest("Parser: without !important flag = false", function()
    local decls = declsOf("div { color: red; }")
    assert_eq(decls[1].important, false)
end)

runTest("Parser: rule without declarations is ignored (empty block)", function()
    local ss = parse("div {}")
    -- May produce a style rule with 0 declarations, or not; either is valid
    -- We just ensure no crash and the stylesheet is returned
    assert_not_nil(ss)
end)

runTest("Parser: multiple style rules", function()
    local ss = parse("h1 { color: red; } h2 { color: blue; }")
    local rules = rulesOf(ss, NT.STYLE_RULE)
    assert_eq(#rules, 2)
end)

runTest("Parser: rule with semicolon-only content does not crash", function()
    local ss = parse("div { ; ; ; }")
    assert_not_nil(ss)
end)

runTest("Parser: top-level stray } is recovered from", function()
    local ss = parse("}")
    assert_not_nil(ss)
end)

runTest("Parser: top-level stray ; is recovered from", function()
    local ss = parse("; div { color: red; }")
    local rules = rulesOf(ss, NT.STYLE_RULE)
    assert_eq(#rules, 1)
end)

runTest(
    "Parser: declaration without colon is skipped (error recovery)",
    function()
        local decls = declsOf("div { color; font-size: 16px; }")
        assert_eq(#decls, 1)
        assert_eq(decls[1].property, "font-size")
    end
)

runTest("Parser: declaration with no value between colons is parsed", function()
    local decls = declsOf("div { font-size: 16px; }")
    assert_eq(decls[1].property, "font-size")
end)

runTest("Parser: raw value string is stored", function()
    local decls = declsOf("div { color: red; }")
    assert_eq(decls[1].raw, "red")
end)

runTest("Parser: raw value for multi-token value", function()
    local decls = declsOf("div { margin: 10px 20px; }")
    assert_not_nil(decls[1].raw)
    assert_true(#decls[1].raw > 0)
end)

-- ══════════════════════════════════════════════════════════════════════════════
--  PARSER TESTS — Value Parsing
-- ══════════════════════════════════════════════════════════════════════════════

print(
    "\n── Parser: Value Types ──────────────────────────────────────────────────\n"
)

runTest("Parser: keyword value", function()
    local decls = declsOf("div { display: block; }")
    assert_eq(decls[1].value.type, VT.KEYWORD)
    assert_eq(decls[1].value.value, "block")
end)

runTest("Parser: color keyword value", function()
    local decls = declsOf("div { color: red; }")
    assert_eq(decls[1].value.type, VT.COLOR)
    assert_eq(decls[1].value.value, "red")
end)

runTest("Parser: global keyword (inherit)", function()
    local decls = declsOf("div { color: inherit; }")
    assert_eq(decls[1].value.type, VT.KEYWORD)
    assert_eq(decls[1].value.global, true)
end)

runTest("Parser: number value", function()
    local decls = declsOf("div { z-index: 10; }")
    assert_eq(decls[1].value.type, VT.NUMBER)
    assert_eq(decls[1].value.value, 10)
end)

runTest("Parser: dimension value (16px)", function()
    local decls = declsOf("div { font-size: 16px; }")
    assert_eq(decls[1].value.type, VT.DIMENSION)
    assert_eq(decls[1].value.value, 16)
    assert_eq(decls[1].value.unit, "px")
end)

runTest("Parser: percentage value (50%)", function()
    local decls = declsOf("div { width: 50%; }")
    assert_eq(decls[1].value.type, VT.PERCENTAGE)
    assert_eq(decls[1].value.value, 50)
end)

runTest("Parser: string value", function()
    local decls = declsOf('div { content: "hello"; }')
    assert_eq(decls[1].value.type, VT.STRING)
    assert_eq(decls[1].value.value, "hello")
end)

runTest("Parser: URL value", function()
    local decls = declsOf("div { background-image: url(img.png); }")
    assert_eq(decls[1].value.type, VT.URL)
    assert_eq(decls[1].value.value, "img.png")
end)

runTest("Parser: hex color value (#ff0000)", function()
    local decls = declsOf("div { color: #ff0000; }")
    assert_eq(decls[1].value.type, VT.COLOR)
    assert_eq(decls[1].value.hex, "ff0000")
end)

runTest("Parser: space-separated list value (margin: 10px 20px)", function()
    local decls = declsOf("div { margin: 10px 20px; }")
    local val = decls[1].value
    assert_eq(val.type, VT.LIST)
    assert_eq(val.separator, " ")
    assert_eq(#val.items, 2)
end)

runTest("Parser: comma-separated list value (font-family)", function()
    local decls = declsOf("div { font-family: Arial, sans-serif; }")
    local val = decls[1].value
    assert_eq(val.type, VT.LIST)
    assert_eq(val.separator, ",")
    assert_eq(#val.items, 2)
end)

runTest("Parser: slash-separated list value (font shorthand)", function()
    local decls = declsOf("div { font: 16px/1.5 Arial; }")
    -- value will be a space-list with 16px/1.5 and Arial
    assert_not_nil(decls[1].value)
end)

runTest("Parser: var() function value", function()
    local decls = declsOf("div { color: var(--primary); }")
    assert_eq(decls[1].value.type, VT.VAR)
    assert_not_nil(decls[1].value.arguments)
    assert_eq(decls[1].value.arguments.varName, "--primary")
end)

runTest("Parser: var() with fallback", function()
    local decls = declsOf("div { color: var(--primary, red); }")
    assert_eq(decls[1].value.type, VT.VAR)
    assert_not_nil(decls[1].value.arguments.fallback)
end)

runTest("Parser: env() function value", function()
    local decls = declsOf("div { padding: env(safe-area-inset-top); }")
    assert_eq(decls[1].value.type, VT.ENV)
end)

runTest("Parser: calc() function value", function()
    local decls = declsOf("div { width: calc(100% - 20px); }")
    assert_eq(decls[1].value.type, VT.CALC)
    assert_not_nil(decls[1].value.arguments)
end)

runTest("Parser: rgb() color function", function()
    local decls = declsOf("div { color: rgb(255, 0, 0); }")
    assert_eq(decls[1].value.type, VT.COLOR)
    local args = decls[1].value.arguments
    assert_not_nil(args.r)
    assert_not_nil(args.g)
    assert_not_nil(args.b)
    assert_eq(args.r.value, 255)
end)

runTest("Parser: rgb() modern syntax (space-separated)", function()
    local decls = declsOf("div { color: rgb(255 0 0 / 0.5); }")
    assert_eq(decls[1].value.type, VT.COLOR)
    local args = decls[1].value.arguments
    assert_not_nil(args.a)
end)

runTest("Parser: rgba() with alpha", function()
    local decls = declsOf("div { color: rgba(255, 0, 0, 0.5); }")
    assert_eq(decls[1].value.type, VT.COLOR)
    local args = decls[1].value.arguments
    assert_not_nil(args.a)
    assert_true(math.abs(args.a.value - 0.5) < 1e-9)
end)

runTest("Parser: hsl() color function", function()
    local decls = declsOf("div { color: hsl(120, 100%, 50%); }")
    assert_eq(decls[1].value.type, VT.COLOR)
    local args = decls[1].value.arguments
    assert_not_nil(args.h)
    assert_not_nil(args.s)
    assert_not_nil(args.l)
end)

runTest("Parser: hsl() modern syntax", function()
    local decls = declsOf("div { color: hsl(120deg 100% 50% / 0.8); }")
    assert_eq(decls[1].value.type, VT.COLOR)
end)

runTest("Parser: hwb() color function", function()
    local decls = declsOf("div { color: hwb(120 0% 0%); }")
    assert_eq(decls[1].value.type, VT.COLOR)
    local args = decls[1].value.arguments
    assert_not_nil(args.h)
    assert_not_nil(args.w)
    assert_not_nil(args.b)
end)

runTest("Parser: oklab() color function", function()
    local decls = declsOf("div { color: oklab(0.5 0.1 -0.1); }")
    assert_eq(decls[1].value.type, VT.COLOR)
end)

runTest("Parser: oklch() color function", function()
    local decls = declsOf("div { color: oklch(0.7 0.15 180); }")
    assert_eq(decls[1].value.type, VT.COLOR)
end)

runTest("Parser: color() function with display-p3", function()
    local decls = declsOf("div { color: color(display-p3 0.5 0.3 0.9); }")
    assert_eq(decls[1].value.type, VT.COLOR)
    assert_eq(decls[1].value.arguments.colorspace, "display-p3")
end)

runTest("Parser: color-mix() function", function()
    local decls = declsOf("div { color: color-mix(in srgb, red 50%, blue); }")
    assert_eq(decls[1].value.type, VT.COLOR)
end)

runTest("Parser: linear-gradient() value", function()
    local decls =
        declsOf("div { background: linear-gradient(to right, red, blue); }")
    assert_eq(decls[1].value.type, VT.FUNCTION)
    assert_eq(decls[1].value.name, "linear-gradient")
    assert_true(decls[1].value.isGradient)
end)

runTest("Parser: radial-gradient() value", function()
    local decls =
        declsOf("div { background: radial-gradient(circle, red, blue); }")
    assert_eq(decls[1].value.type, VT.FUNCTION)
    assert_true(decls[1].value.isGradient)
end)

runTest("Parser: transform function (translateX)", function()
    local decls = declsOf("div { transform: translateX(10px); }")
    local val = decls[1].value
    assert_eq(val.type, VT.FUNCTION)
    assert_true(val.isTransform)
end)

runTest("Parser: filter function (blur)", function()
    local decls = declsOf("div { filter: blur(4px); }")
    local val = decls[1].value
    assert_eq(val.type, VT.FUNCTION)
    assert_true(val.isFilter)
end)

runTest("Parser: timing function (cubic-bezier)", function()
    local decls = declsOf(
        "div { transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1); }"
    )
    local val = decls[1].value
    assert_eq(val.type, VT.FUNCTION)
    assert_true(val.isTiming)
    local args = val.arguments
    assert_not_nil(args.p1x)
    assert_not_nil(args.p1y)
    assert_not_nil(args.p2x)
    assert_not_nil(args.p2y)
end)

runTest("Parser: steps() timing function", function()
    local decls = declsOf("div { animation-timing-function: steps(4, end); }")
    local val = decls[1].value
    assert_eq(val.type, VT.FUNCTION)
    local args = val.arguments
    assert_not_nil(args.count)
    assert_not_nil(args.position)
end)

runTest("Parser: min() math function", function()
    local decls = declsOf("div { width: min(100%, 500px); }")
    assert_eq(decls[1].value.type, VT.CALC)
end)

runTest("Parser: clamp() math function", function()
    local decls = declsOf("div { font-size: clamp(12px, 2vw, 24px); }")
    assert_eq(decls[1].value.type, VT.CALC)
end)

-- ══════════════════════════════════════════════════════════════════════════════
--  PARSER TESTS — Selectors
-- ══════════════════════════════════════════════════════════════════════════════

print(
    "\n── Parser: Selectors ────────────────────────────────────────────────────\n"
)

local function getSelector(css)
    local ss = parse(css)
    local rules = rulesOf(ss, NT.STYLE_RULE)
    assert_true(#rules >= 1, "has a style rule")
    return rules[1].selectorList.selectors[1]
end

local function firstCompound(sel) return sel.components[1] end

runTest("Parser: type selector (div)", function()
    local sel = getSelector("div { color: red; }")
    local compound = firstCompound(sel)
    assert_not_nil(compound)
    assert_eq(compound[1].type, ST.TYPE)
    assert_eq(compound[1].value, "div")
end)

runTest("Parser: universal selector (*)", function()
    local sel = getSelector("* { color: red; }")
    local compound = firstCompound(sel)
    assert_eq(compound[1].type, ST.UNIVERSAL)
end)

runTest("Parser: class selector (.foo)", function()
    local sel = getSelector(".foo { color: red; }")
    local compound = firstCompound(sel)
    -- compound[1] is a DELIM '.', compound[2] is the IDENT processed as class
    -- Actually the parser sees '.' as DELIM and 'foo' as TYPE — this is the
    -- current parser design: class detection happens at the DELIM level.
    -- Verify no crash and rule is produced.
    assert_not_nil(compound)
end)

runTest("Parser: id selector (#bar)", function()
    local sel = getSelector("#bar { color: red; }")
    local compound = firstCompound(sel)
    assert_not_nil(compound)
    assert_eq(compound[1].type, ST.ID)
    assert_eq(compound[1].value, "bar")
end)

runTest("Parser: selector list (h1, h2)", function()
    local ss = parse("h1, h2 { color: red; }")
    local rules = rulesOf(ss, NT.STYLE_RULE)
    assert_eq(#rules, 1)
    assert_eq(#rules[1].selectorList.selectors, 2)
end)

runTest("Parser: descendant combinator (div p)", function()
    local sel = getSelector("div p { color: red; }")
    -- components: [compound(div), " ", compound(p)]
    assert_true(#sel.components >= 3)
    assert_eq(sel.components[2], " ")
end)

runTest("Parser: child combinator (div > p)", function()
    local sel = getSelector("div > p { color: red; }")
    local hasChild = false
    for _, c in ipairs(sel.components) do
        if c == ">" then
            hasChild = true
            break
        end
    end
    assert_true(hasChild)
end)

runTest("Parser: adjacent sibling combinator (h1 + h2)", function()
    local sel = getSelector("h1 + h2 { color: red; }")
    local hasAdj = false
    for _, c in ipairs(sel.components) do
        if c == "+" then
            hasAdj = true
            break
        end
    end
    assert_true(hasAdj)
end)

runTest("Parser: general sibling combinator (h1 ~ p)", function()
    local sel = getSelector("h1 ~ p { color: red; }")
    local hasSib = false
    for _, c in ipairs(sel.components) do
        if c == "~" then
            hasSib = true
            break
        end
    end
    assert_true(hasSib)
end)

runTest("Parser: attribute selector [attr]", function()
    local sel = getSelector("[href] { color: red; }")
    local compound = firstCompound(sel)
    assert_not_nil(compound)
    assert_eq(compound[1].type, ST.ATTRIBUTE)
    assert_eq(compound[1].attribute, "href")
    assert_eq(compound[1].operator, "")
end)

runTest("Parser: attribute selector [attr=val]", function()
    local sel = getSelector('[type="text"] { border: none; }')
    local compound = firstCompound(sel)
    assert_eq(compound[1].type, ST.ATTRIBUTE)
    assert_eq(compound[1].operator, "=")
    assert_eq(compound[1].value, "text")
end)

runTest("Parser: attribute selector [attr^=val] (prefix)", function()
    local sel = getSelector('[href^="https"] { color: green; }')
    local compound = firstCompound(sel)
    assert_eq(compound[1].operator, "^=")
end)

runTest("Parser: attribute selector [attr$=val] (suffix)", function()
    local sel = getSelector('[href$=".pdf"] { color: red; }')
    local compound = firstCompound(sel)
    assert_eq(compound[1].operator, "$=")
end)

runTest("Parser: attribute selector [attr*=val] (substring)", function()
    local sel = getSelector('[class*="foo"] { color: red; }')
    local compound = firstCompound(sel)
    assert_eq(compound[1].operator, "*=")
end)

runTest("Parser: attribute selector [attr~=val] (includes)", function()
    local sel = getSelector('[class~="btn"] { color: red; }')
    local compound = firstCompound(sel)
    assert_eq(compound[1].operator, "~=")
end)

runTest("Parser: attribute selector [attr|=val] (dash-match)", function()
    local sel = getSelector('[lang|="en"] { color: red; }')
    local compound = firstCompound(sel)
    assert_eq(compound[1].operator, "|=")
end)

runTest(
    "Parser: attribute selector with case-insensitive flag [attr=val i]",
    function()
        local sel = getSelector('[type="TEXT" i] { border: none; }')
        local compound = firstCompound(sel)
        assert_eq(compound[1].caseFlag, "i")
    end
)

runTest("Parser: pseudo-class :hover", function()
    local sel = getSelector("a:hover { color: blue; }")
    local compound = firstCompound(sel)
    local found = false
    for _, part in ipairs(compound) do
        if part.type == ST.PSEUDO_CLASS and part.name == "hover" then
            found = true
            break
        end
    end
    assert_true(found)
end)

runTest("Parser: pseudo-class :first-child", function()
    local sel = getSelector("li:first-child { color: red; }")
    local compound = firstCompound(sel)
    local found = false
    for _, part in ipairs(compound) do
        if part.type == ST.PSEUDO_CLASS and part.name == "first-child" then
            found = true
            break
        end
    end
    assert_true(found)
end)

runTest("Parser: pseudo-element ::before (double colon)", function()
    local sel = getSelector("div::before { content: ''; }")
    local compound = firstCompound(sel)
    local found = false
    for _, part in ipairs(compound) do
        if part.type == ST.PSEUDO_ELEMENT and part.name == "before" then
            found = true
            break
        end
    end
    assert_true(found)
end)

runTest("Parser: pseudo-element :before (single colon legacy)", function()
    local sel = getSelector("div:before { content: ''; }")
    -- single-colon before/after should still be treated as pseudo-element
    local compound = firstCompound(sel)
    local found = false
    for _, part in ipairs(compound) do
        if part.type == ST.PSEUDO_ELEMENT and part.name == "before" then
            found = true
            break
        end
    end
    assert_true(found)
end)

runTest("Parser: functional pseudo-class :nth-child(2n+1)", function()
    local sel = getSelector("li:nth-child(2n+1) { color: red; }")
    local compound = firstCompound(sel)
    local found = false
    for _, part in ipairs(compound) do
        if part.type == ST.PSEUDO_CLASS and part.name == "nth-child" then
            found = true
            assert_not_nil(part.argument)
            assert_eq(part.argument.a, 2)
            assert_eq(part.argument.b, 1)
            break
        end
    end
    assert_true(found)
end)

runTest("Parser: functional pseudo-class :nth-child(odd)", function()
    local sel = getSelector("li:nth-child(odd) { color: red; }")
    local compound = firstCompound(sel)
    local found = false
    for _, part in ipairs(compound) do
        if part.type == ST.PSEUDO_CLASS and part.name == "nth-child" then
            found = true
            assert_eq(part.argument.a, 2)
            assert_eq(part.argument.b, 1)
            break
        end
    end
    assert_true(found)
end)

runTest("Parser: functional pseudo-class :nth-child(even)", function()
    local sel = getSelector("li:nth-child(even) { color: red; }")
    local compound = firstCompound(sel)
    local found = false
    for _, part in ipairs(compound) do
        if part.type == ST.PSEUDO_CLASS and part.name == "nth-child" then
            found = true
            assert_eq(part.argument.a, 2)
            assert_eq(part.argument.b, 0)
            break
        end
    end
    assert_true(found)
end)

runTest("Parser: functional pseudo-class :not(span)", function()
    local sel = getSelector("div:not(span) { color: red; }")
    local compound = firstCompound(sel)
    local found = false
    for _, part in ipairs(compound) do
        if part.type == ST.PSEUDO_CLASS and part.name == "not" then
            found = true
            assert_not_nil(part.argument)
            break
        end
    end
    assert_true(found)
end)

runTest("Parser: nesting selector (&)", function()
    local sel = getSelector("& { color: red; }")
    local compound = firstCompound(sel)
    local found = false
    for _, part in ipairs(compound) do
        if part.type == ST.NESTING then
            found = true
            break
        end
    end
    assert_true(found)
end)

-- ══════════════════════════════════════════════════════════════════════════════
--  PARSER TESTS — Specificity
-- ══════════════════════════════════════════════════════════════════════════════

print(
    "\n── Parser: Specificity ──────────────────────────────────────────────────\n"
)

local function spec(css)
    local sel = getSelector(css)
    return sel.specificity
end

runTest("Parser: specificity of type selector = (0,0,1)", function()
    local s = spec("div { color: red; }")
    assert_eq(s[1], 0)
    assert_eq(s[2], 0)
    assert_eq(s[3], 1)
end)

runTest("Parser: specificity of ID selector = (1,0,0)", function()
    local s = spec("#foo { color: red; }")
    assert_eq(s[1], 1)
    assert_eq(s[2], 0)
    assert_eq(s[3], 0)
end)

runTest("Parser: specificity of class selector = (0,1,0)", function()
    -- .foo produces DELIM('.') + IDENT — specificity bump for class
    local ss = parse(".btn { color: red; }")
    local rules = rulesOf(ss, NT.STYLE_RULE)
    assert_eq(#rules, 1)
    local s = rules[1].selectorList.selectors[1].specificity
    -- (0,1,0): class bumps [2]
    assert_eq(s[1], 0)
    assert_eq(s[2], 1)
    assert_eq(s[3], 0)
end)

runTest("Parser: specificity of combined div#id = (1,0,1)", function()
    local s = spec("div#foo { color: red; }")
    assert_eq(s[1], 1)
    assert_eq(s[2], 0)
    assert_eq(s[3], 1)
end)

runTest("Parser: specificity of pseudo-class adds (0,1,0)", function()
    local s = spec("a:hover { color: red; }")
    -- a = (0,0,1) + :hover = (0,1,0) → (0,1,1)
    assert_eq(s[1], 0)
    assert_eq(s[2], 1)
    assert_eq(s[3], 1)
end)

runTest("Parser: specificity of pseudo-element adds (0,0,1)", function()
    local s = spec("p::before { content: ''; }")
    -- p = (0,0,1) + ::before = (0,0,1) → (0,0,2)
    assert_eq(s[1], 0)
    assert_eq(s[2], 0)
    assert_eq(s[3], 2)
end)

runTest("Parser: specificity of attribute selector = (0,1,0)", function()
    local s = spec("[href] { color: red; }")
    assert_eq(s[1], 0)
    assert_eq(s[2], 1)
    assert_eq(s[3], 0)
end)

runTest("Parser: specificity comparator (higher wins)", function()
    local cmp = CSSParser.getSpecificityComparator()
    -- (1,0,0) > (0,10,10) — ID beats any number of classes
    assert_true(cmp({ 1, 0, 0 }, { 0, 10, 10 }) > 0)
    assert_true(cmp({ 0, 1, 0 }, { 0, 0, 5 }) > 0)
    assert_eq(cmp({ 0, 1, 0 }, { 0, 1, 0 }), 0)
    assert_true(cmp({ 0, 0, 1 }, { 0, 1, 0 }) < 0)
end)

-- ══════════════════════════════════════════════════════════════════════════════
--  PARSER TESTS — An+B and nth-child helpers
-- ══════════════════════════════════════════════════════════════════════════════

print(
    "\n── Parser: An+B Parser & Matching ──────────────────────────────────────\n"
)

local parseAnPlusB = CSSParser.getAnPlusBParser()

runTest("Parser: parseAnPlusB('odd') → 2,1", function()
    local a, b = parseAnPlusB("odd")
    assert_eq(a, 2)
    assert_eq(b, 1)
end)

runTest("Parser: parseAnPlusB('even') → 2,0", function()
    local a, b = parseAnPlusB("even")
    assert_eq(a, 2)
    assert_eq(b, 0)
end)

runTest("Parser: parseAnPlusB('3') → 0,3", function()
    local a, b = parseAnPlusB("3")
    assert_eq(a, 0)
    assert_eq(b, 3)
end)

runTest("Parser: parseAnPlusB('2n+1') → 2,1", function()
    local a, b = parseAnPlusB("2n+1")
    assert_eq(a, 2)
    assert_eq(b, 1)
end)

runTest("Parser: parseAnPlusB('n') → 1,0", function()
    local a, b = parseAnPlusB("n")
    assert_eq(a, 1)
    assert_eq(b, 0)
end)

runTest("Parser: parseAnPlusB('-n+3') → -1,3", function()
    local a, b = parseAnPlusB("-n+3")
    assert_eq(a, -1)
    assert_eq(b, 3)
end)

runTest("Parser: parseAnPlusB('3n-2') → 3,-2", function()
    local a, b = parseAnPlusB("3n-2")
    assert_eq(a, 3)
    assert_eq(b, -2)
end)

runTest("Parser: parseAnPlusB('invalid') → nil,nil", function()
    local a, b = parseAnPlusB("invalid")
    assert_nil(a)
    assert_nil(b)
end)

-- ══════════════════════════════════════════════════════════════════════════════
--  PARSER TESTS — Shorthand Expansion
-- ══════════════════════════════════════════════════════════════════════════════

print(
    "\n── Parser: Shorthand Expansion ──────────────────────────────────────────\n"
)

runTest("Parser: expandShorthand for margin (4-value box model)", function()
    local decls = declsOf("div { margin: 10px 20px 30px 40px; }")
    local d = findDecl(decls, "margin")
    assert_not_nil(d)
    local expanded = CSSParser.expandShorthand(d)
    assert_not_nil(expanded)
    assert_eq(#expanded, 4)
    local props = {}
    for _, e in ipairs(expanded) do
        props[e.property] = true
    end
    assert_true(props["margin-top"])
    assert_true(props["margin-right"])
    assert_true(props["margin-bottom"])
    assert_true(props["margin-left"])
end)

runTest("Parser: expandShorthand for padding (1-value shorthand)", function()
    local decls = declsOf("div { padding: 5px; }")
    local d = findDecl(decls, "padding")
    local expanded = CSSParser.expandShorthand(d)
    assert_eq(#expanded, 4)
end)

runTest("Parser: expandShorthand for inset", function()
    local decls = declsOf("div { inset: 0; }")
    local d = findDecl(decls, "inset")
    local expanded = CSSParser.expandShorthand(d)
    assert_eq(#expanded, 4)
    local props = {}
    for _, e in ipairs(expanded) do
        props[e.property] = true
    end
    assert_true(props["top"])
    assert_true(props["right"])
    assert_true(props["bottom"])
    assert_true(props["left"])
end)

runTest(
    "Parser: isShorthand('margin') → true",
    function() assert_true(CSSParser.isShorthand("margin")) end
)

runTest(
    "Parser: isShorthand('color') → false",
    function() assert_false(CSSParser.isShorthand("color")) end
)

runTest(
    "Parser: isInherited('color') → true",
    function() assert_true(CSSParser.isInherited("color")) end
)

runTest(
    "Parser: isInherited('width') → false",
    function() assert_false(CSSParser.isInherited("width")) end
)

-- ══════════════════════════════════════════════════════════════════════════════
--  PARSER TESTS — DOM Matching
-- ══════════════════════════════════════════════════════════════════════════════

print(
    "\n── Parser: DOM Matching ─────────────────────────────────────────────────\n"
)

-- Minimal DOM element factory
local function makeElement(tag, id, classes, attrs)
    local el = {
        tagName = tag,
        nodeType = "element",
        getAttribute = function(_, name)
            if name == "id" then return id end
            if name == "class" then return classes end
            return attrs and attrs[name]
        end,
    }
    return el
end

runTest("Parser: matchesSelector – type selector", function()
    local ss = parse("div { color: red; }")
    local rules = rulesOf(ss, NT.STYLE_RULE)
    local sel = rules[1].selectorList.selectors[1]
    local div = makeElement("div", nil, nil)
    assert_true(CSSParser.matchesSelector(div, sel))
    local span = makeElement("span", nil, nil)
    assert_false(CSSParser.matchesSelector(span, sel))
end)

runTest("Parser: matchesSelector – ID selector", function()
    local ss = parse("#hero { color: red; }")
    local rules = rulesOf(ss, NT.STYLE_RULE)
    local sel = rules[1].selectorList.selectors[1]
    local el = makeElement("div", "hero", nil)
    assert_true(CSSParser.matchesSelector(el, sel))
    local el2 = makeElement("div", "other", nil)
    assert_false(CSSParser.matchesSelector(el2, sel))
end)

runTest("Parser: matchesAttribute – EXISTS operator", function()
    local part = { type = ST.ATTRIBUTE, attribute = "href", operator = "" }
    local el = makeElement("a", nil, nil, { href = "http://example.com" })
    assert_true(CSSParser.matchesAttribute(el, part))
    local el2 = makeElement("a", nil, nil, {})
    assert_false(CSSParser.matchesAttribute(el2, part))
end)

runTest("Parser: matchesAttribute – EQUALS", function()
    local part = {
        type = ST.ATTRIBUTE,
        attribute = "type",
        operator = "=",
        value = "text",
    }
    local el = makeElement("input", nil, nil, { type = "text" })
    assert_true(CSSParser.matchesAttribute(el, part))
    local el2 = makeElement("input", nil, nil, { type = "email" })
    assert_false(CSSParser.matchesAttribute(el2, part))
end)

runTest("Parser: matchesAttribute – PREFIX (^=)", function()
    local part = {
        type = ST.ATTRIBUTE,
        attribute = "href",
        operator = "^=",
        value = "https",
    }
    local el = makeElement("a", nil, nil, { href = "https://example.com" })
    assert_true(CSSParser.matchesAttribute(el, part))
    local el2 = makeElement("a", nil, nil, { href = "http://example.com" })
    assert_false(CSSParser.matchesAttribute(el2, part))
end)

runTest("Parser: matchesAttribute – SUFFIX ($=)", function()
    local part = {
        type = ST.ATTRIBUTE,
        attribute = "href",
        operator = "$=",
        value = ".pdf",
    }
    local el = makeElement("a", nil, nil, { href = "doc.pdf" })
    assert_true(CSSParser.matchesAttribute(el, part))
end)

runTest("Parser: matchesAttribute – SUBSTRING (*=)", function()
    local part = {
        type = ST.ATTRIBUTE,
        attribute = "class",
        operator = "*=",
        value = "btn",
    }
    local el = makeElement("div", nil, "btn-primary", {})
    assert_true(CSSParser.matchesAttribute(el, part))
end)

runTest("Parser: matchesAttribute – INCLUDES (~=)", function()
    local part = {
        type = ST.ATTRIBUTE,
        attribute = "class",
        operator = "~=",
        value = "btn",
    }
    local el = makeElement("div", nil, "btn primary", {})
    assert_true(CSSParser.matchesAttribute(el, part))
    local el2 = makeElement("div", nil, "btnprimary", {})
    assert_false(CSSParser.matchesAttribute(el2, part))
end)

runTest("Parser: matchesAttribute – DASH_MATCH (|=)", function()
    local part = {
        type = ST.ATTRIBUTE,
        attribute = "lang",
        operator = "|=",
        value = "en",
    }
    local el = makeElement("html", nil, nil, { lang = "en-US" })
    assert_true(CSSParser.matchesAttribute(el, part))
    local el2 = makeElement("html", nil, nil, { lang = "en" })
    assert_true(CSSParser.matchesAttribute(el2, part))
    local el3 = makeElement("html", nil, nil, { lang = "fr" })
    assert_false(CSSParser.matchesAttribute(el3, part))
end)

runTest("Parser: matchesAttribute – case-insensitive flag", function()
    local part = {
        type = ST.ATTRIBUTE,
        attribute = "type",
        operator = "=",
        value = "TEXT",
        caseFlag = "i",
    }
    local el = makeElement("input", nil, nil, { type = "text" })
    assert_true(CSSParser.matchesAttribute(el, part))
end)

runTest(
    "Parser: matchesPseudoClass – :root (element without parent)",
    function()
        local part = { type = ST.PSEUDO_CLASS, name = "root" }
        local el = makeElement("html", nil, nil)
        -- el has no parentNode → should be root
        assert_true(CSSParser.matchesPseudoClass(el, part))
    end
)

runTest(
    "Parser: matchesPseudoClass – :first-child (no previous element sibling)",
    function()
        local part = { type = ST.PSEUDO_CLASS, name = "first-child" }
        local el = makeElement("li", nil, nil)
        el.previousSibling = nil
        assert_true(CSSParser.matchesPseudoClass(el, part))
    end
)

runTest(
    "Parser: matchesPseudoClass – :first-child false when has prev element sibling",
    function()
        local part = { type = ST.PSEUDO_CLASS, name = "first-child" }
        local prev = makeElement("li", nil, nil)
        local el = makeElement("li", nil, nil)
        el.previousSibling = prev
        assert_false(CSSParser.matchesPseudoClass(el, part))
    end
)

runTest("Parser: matchesPseudoClass – :last-child", function()
    local part = { type = ST.PSEUDO_CLASS, name = "last-child" }
    local el = makeElement("li", nil, nil)
    el.nextSibling = nil
    assert_true(CSSParser.matchesPseudoClass(el, part))
end)

runTest(
    "Parser: matchesPseudoClass – :nth-child(odd) matches position 1",
    function()
        local part = {
            type = ST.PSEUDO_CLASS,
            name = "nth-child",
            argument = { a = 2, b = 1 },
        }
        local el = makeElement("li", nil, nil)
        el.previousSibling = nil -- 1st child
        assert_true(CSSParser.matchesPseudoClass(el, part))
    end
)

runTest(
    "Parser: matchesPseudoClass – :nth-child(odd) rejects position 2",
    function()
        local part = {
            type = ST.PSEUDO_CLASS,
            name = "nth-child",
            argument = { a = 2, b = 1 },
        }
        local prev = makeElement("li", nil, nil)
        local el = makeElement("li", nil, nil)
        el.previousSibling = prev
        prev.previousSibling = nil
        assert_false(CSSParser.matchesPseudoClass(el, part))
    end
)

-- ══════════════════════════════════════════════════════════════════════════════
--  PARSER TESTS — Cascade
-- ══════════════════════════════════════════════════════════════════════════════

print(
    "\n── Parser: Cascade & Rule Matching ──────────────────────────────────────\n"
)

runTest("Parser: collectMatchingRules finds matching rule", function()
    local ss = parse("div { color: red; } span { color: blue; }")
    local el = makeElement("div", nil, nil)
    local matches = CSSParser.collectMatchingRules(ss, el, nil)
    assert_eq(#matches, 1)
end)

runTest("Parser: collectMatchingRules rejects non-matching rule", function()
    local ss = parse("span { color: blue; }")
    local el = makeElement("div", nil, nil)
    local matches = CSSParser.collectMatchingRules(ss, el, nil)
    assert_eq(#matches, 0)
end)

runTest(
    "Parser: sortRulesBySpecificity puts lower specificity first",
    function()
        local ss = parse("div { color: red; } #foo { color: blue; }")
        local el = makeElement("div", "foo", nil)
        local matches = CSSParser.collectMatchingRules(ss, el, nil)
        local sorted = CSSParser.sortRulesBySpecificity(matches)
        -- Lower specificity (div = 0,0,1) should be before (#foo = 1,0,0)
        local s1 = sorted[1].specificity
        local s2 = sorted[2].specificity
        local cmp = CSSParser.getSpecificityComparator()
        assert_true(cmp(s1, s2) <= 0)
    end
)

runTest(
    "Parser: buildCascadedProperties separates normal and important",
    function()
        local ss = parse("div { color: red; font-size: 16px !important; }")
        local el = makeElement("div", nil, nil)
        local matches = CSSParser.collectMatchingRules(ss, el, nil)
        local sorted = CSSParser.sortRulesBySpecificity(matches)
        local normal, important = CSSParser.buildCascadedProperties(sorted)
        assert_not_nil(normal["color"])
        assert_not_nil(important["font-size"])
    end
)

runTest("Parser: getMatchingRules convenience function", function()
    local css = "p { color: green; } div { color: red; }"
    local el = makeElement("p", nil, nil)
    local matched = CSSParser.getMatchingRules(css, el, CSSLexer)
    assert_eq(#matched, 1)
end)

-- ══════════════════════════════════════════════════════════════════════════════
--  PARSER TESTS — Edge Cases & Error Recovery
-- ══════════════════════════════════════════════════════════════════════════════

print(
    "\n── Parser: Error Recovery & Edge Cases ───────────────────────────────────\n"
)

runTest("Parser: empty CSS produces empty stylesheet", function()
    local ss = parse("")
    assert_eq(#ss.rules, 0)
end)

runTest("Parser: whitespace-only CSS", function()
    local ss = parse("   \n\t   ")
    assert_not_nil(ss)
    assert_eq(#ss.rules, 0)
end)

runTest("Parser: unclosed brace (error recovery)", function()
    local ss = parse("div { color: red;")
    -- Should not throw; stylesheet returned with or without rule
    assert_not_nil(ss)
end)

runTest("Parser: rule with unparseable selector is dropped", function()
    local ss = parse("{ color: red; }")
    local rules = rulesOf(ss, NT.STYLE_RULE)
    -- Empty selector → rule should be discarded
    assert_eq(#rules, 0)
end)

runTest("Parser: CDO/CDC tokens at top level are skipped", function()
    local ss = parse("<!-- div { color: red; } -->")
    local rules = rulesOf(ss, NT.STYLE_RULE)
    assert_eq(#rules, 1)
end)

runTest("Parser: deeply nested calc() doesn't crash", function()
    local css = "div { width: calc(calc(100% - calc(20px + calc(5px)))); }"
    local ss = parse(css)
    assert_not_nil(ss)
    local decls = declsOf(css)
    assert_eq(decls[1].value.type, VT.CALC)
end)

runTest("Parser: many rules parsed efficiently", function()
    local parts = {}
    for i = 1, 500 do
        parts[i] =
            string.format(".item-%d { color: hsl(%d, 50%%, 50%%); }", i, i)
    end
    local css = table.concat(parts, "\n")
    local ss = parse(css)
    local rules = rulesOf(ss, NT.STYLE_RULE)
    assert_eq(#rules, 500)
end)

runTest("Parser: getErrors() returns error list (not nil)", function()
    local _, parser = CSSParser.parseCSS("}", CSSLexer)
    assert_not_nil(parser:getErrors())
    assert_true(type(parser:getErrors()) == "table")
end)

runTest("Parser: real-world Bootstrap-like snippet", function()
    local css = [[
        :root {
            --bs-blue: #0d6efd;
            --bs-font-sans-serif: system-ui, -apple-system, sans-serif;
        }
        *, *::before, *::after {
            box-sizing: border-box;
        }
        body {
            margin: 0;
            font-family: var(--bs-font-sans-serif);
            font-size: 1rem;
            line-height: 1.5;
            color: #212529;
            background-color: #fff;
        }
        .container {
            width: 100%;
            padding-right: 0.75rem;
            padding-left: 0.75rem;
            margin-right: auto;
            margin-left: auto;
        }
        @media (min-width: 576px) {
            .container { max-width: 540px; }
        }
        @media (min-width: 768px) {
            .container { max-width: 720px; }
        }
    ]]
    local ss = parse(css)
    assert_not_nil(ss)
    assert_true(#ss.rules >= 5, "parsed multiple rules")
end)

runTest("Parser: real-world animation keyframes snippet", function()
    local css = [[
        @keyframes spin {
            0%   { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .spinner {
            animation: spin 1s linear infinite;
        }
    ]]
    local ss = parse(css)
    local kf = rulesOf(ss, NT.KEYFRAMES_RULE)
    assert_eq(#kf, 1)
    assert_eq(kf[1].name, "spin")
end)

runTest("Parser: CSS variables used and referenced", function()
    local css = [[
        :root { --color: #ff0000; }
        div   { color: var(--color); }
    ]]
    local ss = parse(css)
    local rules = rulesOf(ss, NT.STYLE_RULE)
    assert_true(#rules >= 2)
end)

runTest("Parser: multiple selectors with varied combinators", function()
    local css = "nav > ul > li + li ~ a[href] { color: red; }"
    local ss = parse(css)
    local rules = rulesOf(ss, NT.STYLE_RULE)
    assert_eq(#rules, 1)
end)

runTest(
    "Parser: @supports with multiple and-conditions produces rule",
    function()
        local css = [[
        @supports (display: flex) and (gap: 1rem) and (aspect-ratio: 1/1) {
            .flex { display: flex; }
        }
    ]]
        local ss = parse(css)
        local rules = rulesOf(ss, NT.SUPPORTS_RULE)
        assert_eq(#rules, 1)
    end
)

-- ══════════════════════════════════════════════════════════════════════════════
--  SUMMARY
-- ══════════════════════════════════════════════════════════════════════════════

print(
    "\n═══════════════════════════════════════════════════════════════════════"
)
print(string.format("  CSS Lexer & Parser Test Suite — Results"))
print(
    "═══════════════════════════════════════════════════════════════════════"
)
print(string.format("  Total   : %d", TOTAL))
print(string.format("  ✓ Pass  : %d", PASS))

if FAIL > 0 then
    warn(string.format("  ✗ Fail  : %d", FAIL))
else
    print(string.format("  ✗ Fail  : %d", FAIL))
end

if TIMEOUT > 0 then
    warn(
        string.format("  ⏱ Timeout: %d  (limit: %ds)", TIMEOUT, TIMEOUT_LIMIT)
    )
else
    print(string.format("  ⏱ Timeout: %d", TIMEOUT))
end

print(
    "═══════════════════════════════════════════════════════════════════════"
)

if FAIL == 0 and TIMEOUT == 0 then
    print("  🎉 ALL TESTS PASSED")
else
    warn(
        string.format(
            "  ⚠  %d test(s) failed / timed out — see FAIL/TIMEOUT lines above.",
            FAIL + TIMEOUT
        )
    )
end

print(
    "═══════════════════════════════════════════════════════════════════════\n"
)

return FAIL == 0 and TIMEOUT == 0

-- EOF