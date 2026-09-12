--[[
    "Web Browser application for dOS"
    
    @module browser
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

function M.create(dOS)
    if dOS.modem == false then
        dOS.MessageBox.error(
            dOS,
            "Hardware Error",
            "Predicated upon your manifested volition to eschew the requisite "
                .. "synchronization of the telecommunicative modem apparatus, "
                .. "the operational efficacy of this digital interface is, "
                .. "by ontological necessity, relegated to a condition of absolute suspension."
        )
        return
    end

    if not dOS.modem then -- Somehow
        dOS.MessageBox.error(dOS, "Hardware Error", "No Modem detected.")
        return
    end

    -- main window
    local winFrame, contentArea = dOS.create_basic_window(
        dOS,
        "dOS Web Browser",
        700,
        500,
        true,
        true,
        true,
        true,
        300,
        300
    )
    if not winFrame then return end

    local STYLESHEET_LENGHT_WARN_THRESHOLD = 5000

    local state = {
        current_url = "http://example.org",
        history = {},
        history_index = 0,
        is_loading = false,
        page_title = "New Tab",
        page_loading_thread = nil,
    }

    -- nav bar
    local navBar = dOS.create_gui_element(dOS, "Frame", {
        Parent = contentArea,
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = dOS.THEME.TITLE_BAR_BG,
        BorderSizePixel = 0,
    })

    local backButton = dOS.create_gui_element(dOS, "ImageButton", {
        Parent = navBar,
        Image = 6993472329, -- ◀
        ImageColor3 = dOS.THEME.ACCENT,
        BorderSizePixel = 4,
        BorderColor3 = dOS.THEME.ACCENT_BUTTON_BG:Lerp(
            Color3.new(0, 0, 0),
            0.2
        ),
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.fromOffset(5, 5),
        HoverColor = dOS.THEME.ACCENT_BUTTON_HOVER,
    })

    local forwardButton = dOS.create_gui_element(dOS, "ImageButton", {
        Parent = navBar,
        Image = 6993462605, -- ▶
        ImageColor3 = dOS.THEME.ACCENT,
        BorderSizePixel = 4,
        BorderColor3 = dOS.THEME.ACCENT_BUTTON_BG:Lerp(
            Color3.new(0, 0, 0),
            0.2
        ),
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.fromOffset(40, 5),
        HoverColor = dOS.THEME.ACCENT_BUTTON_HOVER,
    })

    local refreshButton = dOS.create_gui_element(dOS, "ImageButton", {
        Parent = navBar,
        Image = 9613508061, -- ⟳
        ImageColor3 = dOS.THEME.ACCENT,
        BorderSizePixel = 4,
        BorderColor3 = dOS.THEME.ACCENT_BUTTON_BG:Lerp(
            Color3.new(0, 0, 0),
            0.2
        ),
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.fromOffset(75, 5),
        HoverColor = dOS.THEME.ACCENT_BUTTON_HOVER,
    })

    local homeButton = dOS.create_gui_element(dOS, "ImageButton", {
        Parent = navBar,
        Image = 13060262529, -- ⌂
        ImageColor3 = dOS.THEME.ACCENT,
        BorderSizePixel = 4,
        BorderColor3 = dOS.THEME.ACCENT_BUTTON_BG:Lerp(
            Color3.new(0, 0, 0),
            0.2
        ),
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.fromOffset(110, 5),
        HoverColor = dOS.THEME.ACCENT_BUTTON_HOVER,
    })

    local urlDisplayButton = dOS.create_gui_element(dOS, "TextButton", {
        Parent = navBar,
        Text = state.current_url,
        Size = UDim2.new(1, -195, 0, 30),
        Position = UDim2.fromOffset(145, 5),
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundColor3 = dOS.THEME.TEXT_BOX_DARK,
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    dOS.create_gui_element(dOS, "UIPadding", {
        Parent = urlDisplayButton,
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
    })

    local goButton = dOS.create_gui_element(dOS, "TextButton", {
        Parent = navBar,
        Text = "Go",
        TextColor3 = dOS.THEME.TEXT_LIGHT,
        Size = UDim2.fromOffset(40, 30),
        Position = UDim2.new(1, -45, 0, 5),
        BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
        HoverColor = dOS.THEME.ACCENT_BUTTON_HOVER,
    })

    local viewport = dOS.create_gui_element(dOS, "ScrollingFrame", {
        Parent = contentArea,
        Size = UDim2.new(1, 0, 1, -65),
        Position = UDim2.fromOffset(0, 40),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        ScrollBarThickness = 8,
        ScrollingDirection = Enum.ScrollingDirection.XY,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ElasticBehavior = Enum.ElasticBehavior.Never,
    })

    dOS.create_gui_element(dOS, "UIPadding", {
        Parent = viewport,
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10),
    })

    local statusBar = dOS.create_gui_element(dOS, "Frame", {
        Parent = contentArea,
        Size = UDim2.new(1, 0, 0, 25),
        Position = UDim2.new(0, 0, 1, -25),
        BackgroundColor3 = dOS.THEME.TASKBAR_BG,
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = statusBar,
        Text = "Status:",
        Size = UDim2.fromOffset(45, 25),
        Position = UDim2.fromOffset(5, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = dOS.THEME.TEXT_DIM,
    })

    local statusValue = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = statusBar,
        Text = "Ready",
        Size = UDim2.fromOffset(120, 25),
        Position = UDim2.fromOffset(50, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = dOS.THEME.TEXT_DIM,
    })

    dOS.create_gui_element(dOS, "TextLabel", {
        Parent = statusBar,
        Text = "Ping:",
        Size = UDim2.fromOffset(35, 25),
        Position = UDim2.fromOffset(180, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = dOS.THEME.TEXT_DIM,
    })

    local latencyValue = dOS.create_gui_element(dOS, "TextLabel", {
        Parent = statusBar,
        Text = "-",
        Size = UDim2.fromOffset(60, 25),
        Position = UDim2.fromOffset(215, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = dOS.THEME.TEXT_DIM,
    })

    local load_url

    local function resolve_url(baseUrl, relativeUrl)
        -- already absolute
        if relativeUrl:match("^https?://") then return relativeUrl end

        -- protocol-relative
        if relativeUrl:match("^//") then
            local protocol = baseUrl:match("^(https?):")
            return `{protocol or "http"}:{relativeUrl}`
        end

        -- root-relative
        if relativeUrl:sub(1, 1) == "/" then
            local domain = baseUrl:match("^(https?://[^/]+)")
            return `{domain or baseUrl}{relativeUrl}`
        end

        -- fragment or query only
        if relativeUrl:sub(1, 1) == "#" or relativeUrl:sub(1, 1) == "?" then
            local baseWithoutFragment = baseUrl:gsub("[#?].*$", "")
            return `{baseWithoutFragment}{relativeUrl}`
        end

        -- relative path
        local basePath = baseUrl:match("^(https?://[^?#]+)")
        if basePath then
            -- strip filename from base path
            basePath = basePath:gsub("/[^/]*$", "/")
            return `{basePath}{relativeUrl}`
        end

        return `{baseUrl}/{relativeUrl}`
    end

    local function clear_viewport()
        for _, child in pairs(viewport:GetChildren()) do
            if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                child:Destroy()
            end
        end
    end

    local function update_title(title)
        state.page_title = title or "Untitled"

        -- update window title
        local titleLabel =
            winFrame:FindFirstChild("TitleBar"):FindFirstChild("TitleLabel")
        if titleLabel then
            titleLabel.Text = "dOS Browser - " .. state.page_title
        end
    end

    local function render_page(
        htmlContent,
        httpCode,
        codeColor,
        latency
    )
        clear_viewport()
        task.wait()

        statusValue.Text = "Parsing..."
        statusValue.TextColor3 = dOS.THEME.TEXT_DIM
        task.wait()

        -- parse html
        local lexer = dOS.NET.HTMLLexer.new(htmlContent)
        lexer:setSkipWhitespaceOnlyText(true)
        local tokens = lexer:tokenize()
        local tokenTypes = dOS.NET.HTMLLexer.getTokenTypes()

        task.wait()
        statusValue.Text = "Building DOM..."
        task.wait()

        local parser = dOS.NET.HTMLParser.new(tokens, tokenTypes)
        local document = parser:parse()

        task.wait()
        statusValue.Text = "Rendering..."
        task.wait()

        -- extract page title
        if document.head then
            local titleElement = document.head:querySelector("title")
            if titleElement then update_title(titleElement:getTextContent()) end
        end

        -- collect <style> + fetch <link>

        statusValue.Text = "Loading CSS..."
        statusValue.TextColor3 = dOS.THEME.TEXT_DIM
        task.wait()

        local inlineStyles = {} -- text from <style> tags (in order)
        local externalHrefs = {} -- href values from <link rel="stylesheet"> (in order)
        local seen_hrefs = {} -- dup external hrefs

        local function collectStyleSources(node)
            if not node then return end

            local tag = node.tagName and node.tagName:lower()
            if tag == "style" then
                local text = node:getTextContent()
                if text and text ~= "" then
                    inlineStyles[#inlineStyles + 1] = text
                end
            elseif tag == "link" then
                local rel = (node:getAttribute("rel") or ""):lower()
                local href = node:getAttribute("href") or ""
                if
                    rel:find("stylesheet")
                    and href ~= ""
                    and not seen_hrefs[href]
                then
                    seen_hrefs[href] = true
                    externalHrefs[#externalHrefs + 1] = href
                end
            end

            local child = node.firstChild
            while child do
                collectStyleSources(child)
                child = child.nextSibling
            end
        end

        collectStyleSources(document.documentElement or document)

        for i, s in ipairs(inlineStyles) do
            print(`[Browser]   style[{i}] length = {#s}`)
        end
        print("[Browser]   external <link> hrefs:", #externalHrefs)
        for i, h in ipairs(externalHrefs) do
            print(`[Browser]   href[{i}] = {h}`)
        end

        local fetchedStyles = {}
        for i, href in ipairs(externalHrefs) do
            local absUrl = resolve_url(state.current_url, href)
            statusValue.Text = `CSS {i}/{#externalHrefs}...`
            task.wait()

            local ok, css = pcall(
                function() return dOS.modem:GetAsync(absUrl, true) end
            )
            if ok and type(css) == "string" then
                fetchedStyles[#fetchedStyles + 1] = css
                local len = #css
                print(`[Browser]   fetched stylesheet {i} length = {len}`)

                if len > STYLESHEET_LENGHT_WARN_THRESHOLD then
                    local answer = dOS.MessageBox.warning(
                        dOS,
                        "Warning",
                        "The CSS StyleSheet is very big, do you want to try parsing it ?",
                        { "No", "Yes" },
                        true -- Steal focus
                    )
                    if answer == "No" then
                        fetchedStyles[#fetchedStyles] = nil
                    end
                end
            else
                warn(
                    "[dOS_Browser] Failed to fetch stylesheet:",
                    absUrl,
                    tostring(css)
                )
            end
        end

        -- merge
        local cssText = `{table.concat(fetchedStyles, "\n")}\n{table.concat(
            inlineStyles,
            "\n"
        )}`

        -- parse css into cssom
        local cssom = nil
        if dOS.NET.CSSParser and dOS.NET.CSSLexer then
            local ok, result = pcall(
                function()
                    return dOS.NET.CSSParser.parseCSS(cssText, dOS.NET.CSSLexer)
                end
            )
            if ok then
                cssom = result
                if cssom and cssom.rules and #cssom.rules > 0 then
                    -- first rule for check
                    local r = cssom.rules[1]
                    print(
                        "[Browser]   rule[1] type =",
                        tostring(r.type),
                        "selector =",
                        tostring(
                            r.selectorText
                                or (r.selectorList and r.selectorList[1])
                        )
                    )
                end
            else
                warn("[dOS_Browser] CSSParser error:", tostring(result))
            end
        end

        -- resolve computed styles
        if dOS.NET.StyleResolver and dOS.NET.CSSLexer and dOS.NET.CSSParser then
            statusValue.Text = "Styling..."
            task.wait()
            local viewW = viewport.AbsoluteSize.X
            local viewH = viewport.AbsoluteSize.Y
            local ok, err = pcall(
                function()
                    dOS.NET.StyleResolver.resolveTree(
                        document,
                        cssom,
                        dOS.NET.CSSLexer,
                        dOS.NET.CSSParser,
                        {
                            dOS = dOS,
                            viewport = {
                                width = viewW > 0 and viewW or 680,
                                height = viewH > 0 and viewH or 440,
                            },
                        }
                    )
                end
            )
            if not ok then
                warn(
                    "[dOS_Browser] StyleResolver.resolveTree error:",
                    tostring(err)
                )
            end
        end

        local fadeFrame = dOS.create_gui_element(dOS, "Frame", {
            Parent = viewport,
            Size = UDim2.fromScale(1, 1),
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.new(1, 1, 1),
            ZIndex = 100,
        })

        -- render
        local totalPageHeight =
            dOS.NET.HTMLRenderer.render(dOS, document, viewport, {
                StyleResolver = dOS.NET.StyleResolver,
                -- link navigation callback
                onNavigate = function(href)
                    local newUrl = resolve_url(state.current_url, href)
                    load_url(newUrl)
                end,

                -- form submit callback
                onFormSubmit = function(form, data)
                    local method = form.method or "GET"
                    local action = form.action or state.current_url

                    -- resolve action url
                    local targetUrl = resolve_url(state.current_url, action)

                    if method:upper() == "GET" then
                        -- build query string
                        local query = ""
                        for name, value in pairs(data) do
                            if name and name ~= "" then
                                local separator = query == "" and "?" or "&"
                                query = query
                                    .. separator
                                    .. string.gsub(
                                        name,
                                        "([^%w%-._~])",
                                        function(c)
                                            return string.format(
                                                "%%%02X",
                                                string.byte(c)
                                            )
                                        end
                                    )
                                    .. "="
                                    .. string.gsub(
                                        tostring(value),
                                        "([^%w%-._~])",
                                        function(c)
                                            return string.format(
                                                "%%%02X",
                                                string.byte(c)
                                            )
                                        end
                                    )
                            end
                        end

                        load_url(`{targetUrl}{query}`)
                    else
                        -- post requests -> get
                        print("[Browser] POST form submission to:", targetUrl)
                        print("[Browser] Form data:", data)

                        local query = ""
                        for name, value in pairs(data) do
                            if name and name ~= "" then
                                local separator = query == "" and "?" or "&"
                                query = `{query}{separator}{name}={value}`
                            end
                        end
                        load_url(`{targetUrl}{query}`)
                    end
                end,

                -- image click callback
                onImageClick = function(src, alt)
                    print("[Browser] Image clicked:", src, alt)
                end,
            })

        task.wait()

        -- canvas size
        if totalPageHeight then
            local canvasW = math.max(viewport.AbsoluteSize.X, 800)
            viewport.CanvasSize =
                UDim2.fromOffset(canvasW, totalPageHeight + 50)
        else
            viewport.CanvasSize = UDim2.fromOffset(800, 1000)
        end

        -- scroll to top
        viewport.CanvasPosition = Vector2.new(0, 0)

        -- fade out
        if fadeFrame and fadeFrame.Parent then
            local fadeTween = dOS.Tween.new(
                fadeFrame,
                { BackgroundTransparency = 1 },
                dOS.TweenInfo.new(0.3)
            )
            fadeTween:Play()
            task.delay(0.35, function()
                if fadeFrame and fadeFrame.Parent then fadeFrame:Destroy() end
            end)
        end

        -- update status
        task.wait()
        statusValue.Text = httpCode or "Done"
        statusValue.TextColor3 = codeColor or Color3.fromRGB(100, 200, 100)
        latencyValue.Text = if latency then latency else "-"
    end

    local function show_error_page(errorMessage, errorCode)
        clear_viewport()

        local errorContainer = dOS.create_gui_element(dOS, "Frame", {
            Parent = viewport,
            Size = UDim2.new(1, 0, 0, 200),
            BackgroundTransparency = 1,
            LayoutOrder = 1,
        })

        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = errorContainer,
            Text = errorCode or "Unknown Error",
            TextColor3 = Color3.fromRGB(200, 50, 50),
            TextSize = 24,
            Font = dOS.FONT_BOLD,
            Size = UDim2.new(1, 0, 0, 40),
            Position = UDim2.fromOffset(0, 20),
            BackgroundTransparency = 1,
        })

        dOS.create_gui_element(dOS, "TextLabel", {
            Parent = errorContainer,
            Text = errorMessage or "Failed to load page.",
            TextColor3 = dOS.THEME.TEXT_DARK,
            TextSize = 14,
            Font = dOS.FONT_REGULAR,
            Size = UDim2.new(1, -20, 0, 60),
            Position = UDim2.fromOffset(10, 70),
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Center,
            BackgroundTransparency = 1,
        })

        dOS.create_gui_element(dOS, "TextButton", { -- retryButton
            Parent = errorContainer,
            Text = "Retry",
            TextColor3 = dOS.THEME.TEXT_DARK,
            TextSize = 14,
            Font = dOS.FONT_BOLD,
            Size = UDim2.fromOffset(100, 35),
            Position = UDim2.new(0.5, -50, 0, 140),
            BackgroundColor3 = dOS.THEME.ACCENT_BUTTON_BG,
            OnClick = function() load_url(state.current_url) end,
        })

        update_title("Error")
    end

    load_url = function(url)
        if state.is_loading then return end

        if state.is_loading and state.page_loading_thread then
            pcall(task.cancel, state.page_loading_thread)
        end

        -- ensure protocol
        if not url:match("^https?://") then url = `http://{url}` end

        state.current_url = url
        urlDisplayButton.Text = url

        statusValue.Text = "Connecting..."
        statusValue.TextColor3 = dOS.THEME.TEXT_DIM
        latencyValue.Text = "..."

        -- clear viewport + loading indicator
        clear_viewport()

        local loadingLabel = dOS.create_gui_element(dOS, "TextLabel", {
            Parent = viewport,
            Text = "Loading...",
            TextColor3 = dOS.THEME.TEXT_DIM,
            TextSize = 16,
            Size = UDim2.new(1, 0, 0, 50),
            BackgroundTransparency = 1,
            LayoutOrder = 1,
        })

        state.page_loading_thread = task.spawn(function()
            local startTime = os.clock()
            local success, response = pcall(
                function() return dOS.modem:GetAsync(url, true) end
            )

            local latency = math.round((os.clock() - startTime) * 1000)

            if not success then
                local errorCode = tonumber(response:match("HTTP (%d+)"))
                    or "Network Error"

                statusValue.Text = errorCode
                statusValue.TextColor3 = Color3.fromRGB(255, 100, 100)
                latencyValue.Text = latency

                show_error_page(tostring(response), errorCode)
                warn("[dOS_Browser] Failed to load page:", response)
                return
            end

            -- check for html
            local isHtml = response:match("<!DOCTYPE")
                or response:match("<html")
                or response:match("<HTML")
                or response:match("<head")
                or response:match("<body")
                or response:match("<div")
                or response:match("<p>")
                or response:match("<h%d")

            if isHtml then
                render_page(
                    response,
                    200,
                    Color3.fromRGB(100, 200, 100),
                    latency
                )
            else
                -- raw content
                clear_viewport()

                statusValue.Text = "200 (Raw)"
                statusValue.TextColor3 = Color3.fromRGB(100, 200, 100)
                latencyValue.Text = tostring(latency) .. "ms"

                dOS.create_gui_element(dOS, "TextLabel", {
                    Parent = viewport,
                    Text = response,
                    TextColor3 = dOS.THEME.TEXT_DARK,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    Size = UDim2.new(1, 0, 0, math.max(500, #response * 0.5)),
                    TextWrapped = true,
                    Font = Enum.Font.Code,
                    TextSize = 12,
                    BackgroundTransparency = 1,
                    LayoutOrder = 1,
                })

                viewport.CanvasSize =
                    UDim2.fromOffset(0, math.max(500, #response * 0.5) + 50)
                update_title("Raw Content")
            end

            -- destroy loading indicator
            if loadingLabel and loadingLabel.Parent then
                loadingLabel:Destroy()
            end

            state.is_loading = false
        end)
    end

    -- FIXME: history broken
    local function navigate()
        -- add new page to history
        if
            #state.history == 0
            or state.history[state.history_index] ~= state.current_url
        then
            -- truncate forward history
            while #state.history > state.history_index do
                table.remove(state.history)
            end

            table.insert(state.history, state.current_url)
            state.history_index = #state.history
        end

        load_url(state.current_url)
    end

    -- event handlers
    urlDisplayButton.MouseButton1Click:Connect(function()
        dOS.RequestStringAsync(
            dOS,
            "Enter URL:",
            state.current_url,
            function(input)
                if input and input ~= "" then
                    state.current_url = input
                    navigate()
                end
            end
        )
    end)

    goButton.MouseButton1Click:Connect(navigate)
    refreshButton.MouseButton1Click:Connect(
        function() load_url(state.current_url) end
    )

    backButton.MouseButton1Click:Connect(function()
        if state.history_index > 1 then
            state.history_index = state.history_index - 1
            state.current_url = state.history[state.history_index]
            urlDisplayButton.Text = state.current_url
            load_url(state.current_url)
        end
    end)

    forwardButton.MouseButton1Click:Connect(function()
        if state.history_index < #state.history then
            state.history_index = state.history_index + 1
            state.current_url = state.history[state.history_index]
            urlDisplayButton.Text = state.current_url
            load_url(state.current_url)
        end
    end)

    homeButton.MouseButton1Click:Connect(function()
        state.current_url = "http://example.org"
        navigate()
    end)

    winFrame.Destroying:Connect(function()
        if state.page_loading_thread then
            pcall(task.cancel, state.page_loading_thread)
        end

        state = {
            current_url = "http://example.org",
            history = {},
            history_index = 0,
            is_loading = false,
            page_title = "New Tab",
            page_loading_thread = nil,
        }
    end)

    task.wait()
    navigate()
end

return M

-- EOF