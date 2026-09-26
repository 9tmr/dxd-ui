local function input()
    active = type(isrbxactive) ~= "function" or isrbxactive()
    down = active and ismouse1pressed()
    click = down and not previousDown
    previousDown = down
    mx, my = mouse.X, mouse.Y
    if not down or not active then
        drag = nil
        slide = nil
    end
    local wasCapture = capture ~= nil
    if capture and active then
        for k = 8, 254 do
            local held = iskeypressed(k)
            if held and not capture.keys[k] and k ~= 16 and k ~= 17 and k ~= 18 then
                if k ~= 27 then
                    app:SetKeybind(k)
                end
                capture = nil
                break
            end
            capture.keys[k] = held
        end
    end
    local menuKey = active and iskeypressed(app.Keybind)
    if menuKey and not previousKey and not wasCapture then
        if app.Visible then
            app:Hide()
        else
            app:Show()
        end
    end
    previousKey = menuKey
    local pressed = {}
    for _, k in ipairs({ 9, 13, 32, 27, 37, 39 }) do
        local held = active and iskeypressed(k)
        pressed[k] = held and not heldKeys[k]
        heldKeys[k] = held
    end
    if wasCapture or not active or not app.Visible then
        return
    end
    if pressed[27] then
        if confirm then
            confirm = nil
        elseif popup then
            popup = nil
        elseif capture then
            capture = nil
        else
            app:Hide()
        end
        focusId = nil
        return
    end
    if pressed[9] and app.Keybind ~= 9 and #previousFocus > 0 then
        keyboardMode = true
        local direction = (iskeypressed(0xA0) or iskeypressed(0x10)) and -1 or 1
        local index = direction == 1 and 0 or 1
        for i, f in ipairs(previousFocus) do
            if f.id == focusId then
                index = i
                break
            end
        end
        index = (index - 1 + direction) % #previousFocus + 1
        focusId = previousFocus[index].id
    end
    for _, f in ipairs(previousFocus) do
        if f.id == focusId then
            if (pressed[13] and app.Keybind ~= 13) or (pressed[32] and app.Keybind ~= 32) then
                keyboardMode = true
                fire(f.fn)
            elseif pressed[37] and f.adjust then
                fire(f.adjust, -1)
            elseif pressed[39] and f.adjust then
                fire(f.adjust, 1)
            end
            break
        end
    end
end
local function renderNavigation()
    local navW = compact and 48 or 164
    local sidebarW = compact and 60 or 180
    box("sidebar", 10, 10, sidebarW, H - 20, mix(tint, black, 0.25), 0.97, 12, 16)
    box("sidebarRule", sidebarW + 10, 24, 1, H - 48, ink, 0.07, 0, 17)
    box("brandBadge", compact and 22 or 26, 25, 34, 34, accent, 0.12, 9, 22)
    if not bitmap("avatar", avatarBytes, compact and 23 or 27, 26, 32, 32, 1, 8, 24) then
        icon("brandCrown", "crown", compact and 29 or 33, 32, accent, 1, 25, 0, 0.9)
    end
    if not compact then
        label("brandName", "DxD", 70, 23, 27, ink, 1, true)
        label("brandSub", "OCCULT RESEARCH CLUB", 27, 74, 8, muted, 1, true)
    end
    local navCount = math.max(1, math.floor((H - 250) / 51))
    navCount = math.min(6, navCount)
    tabOffset = clamp(tabOffset, 0, math.max(0, #app.Tabs - navCount))
    for i = 1, math.min(navCount, #app.Tabs - tabOffset) do
        local tab = app.Tabs[i + tabOffset]
        local py = 108 + (i - 1) * 51
        local over = interactive(tab.Id .. "nav", 18, py, navW, 43, function()
            tab:Select()
        end)
        local weight = ease(tab.Id .. "active", selected == tab and 1 or 0)
        box(tab.Id .. "navbg", 18, py, navW, 43, accent, weight * 0.13 + (over and 0.06 or 0), 8, 32)
        box(tab.Id .. "rail", 18, py + 12, 2, 19, accent, weight, 1, 34)
        icon(tab.Id .. "icon", tab.Icon, compact and 31 or 30, py + 11, mix(muted, accent, weight), 1, 35)
        if not compact then
            label(
                tab.Id .. "title",
                short(tab.Title, 18),
                60,
                py + 15,
                12,
                mix(muted, ink, weight),
                1,
                selected == tab,
                35
            )
        end
    end
    if #app.Tabs > navCount then
        local ny = 108 + navCount * 51
        smallButton("navPrev", "up", compact and 24 or 35, ny, function()
            tabOffset = math.max(0, tabOffset - 1)
        end, false, tabOffset == 0)
        smallButton("navNext", "down", compact and 24 or 113, ny + (compact and 36 or 0), function()
            tabOffset = math.min(#app.Tabs - navCount, tabOffset + 1)
        end, false, tabOffset + navCount >= #app.Tabs)
    end
    if not compact and H >= 520 then
        box("sideFootRule", 26, H - 127, 146, 1, ink, 0.07, 0, 22)
        label("sideFootLabel", "HIGH SCHOOL", 27, H - 107, 9, muted, 1, true)
        label("sideFootName", "DxD", 26, H - 86, 23, ink, 1, true)
        label("sideFootEdition", "CRIMSON EDITION  /  01", 27, H - 52, 8, accent, 1, true)
    else
        icon("sideMoon", "moon", 30, H - 76, accent, 0.7, 24)
    end
end
local function render()
    local now = tick()
    dt = clamp(now - last, 0, 0.1)
    last = now
    frame = frame + 1
    if not app.Alive then
        return
    end
    local camera = world.CurrentCamera
    local vp = camera and camera.ViewportSize or V(1280, 720)
    -- Drawings target the desktop host. Narrow viewports still receive reflowed layouts.
    W = math.min(920, math.max(300, vp.X - 32))
    H = math.min(580, math.max(410, vp.Y - 32))
    S = math.min(1, (vp.X - 16) / W, (vp.Y - 16) / H)
    compact = W < 710
    contentLeft = compact and 88 or 210
    contentWidth = W - contentLeft - 28
    rowHeight = contentWidth < 470 and 114 or 86
    pageSize = math.max(1, math.floor((H - 171) / rowHeight))
    if frame == 1 then
        x = (vp.X - W * S) / 2
        y = (vp.Y - H * S) / 2
    end
    if click and hit(compact and 75 or 196, 10, W - (compact and 128 or 250), 76) then
        drag = { mx - x, my - y }
        click = false
    end
    if drag and down then
        x = mx - drag[1]
        y = my - drag[2]
    end
    x = clamp(x, 8, math.max(8, vp.X - W * S - 8))
    y = clamp(y, 8, math.max(8, vp.Y - H * S - 8))
    a = ease("open", app.Visible and 1 or 0, 15)
    contentA = ease("content", 1, 16)
    if not app.ReducedMotion and app.Visible and active then
        motionClock = motionClock + dt
    end
    local blend = app.ReducedMotion and 1 or 1 - math.exp(-dt * 10)
    local theme = themes[targetTheme]
    tint = mix(tint, theme.Base, blend)
    ink = mix(ink, theme.Text, blend)
    muted = mix(muted, theme.Muted, blend)
    accent = mix(accent, theme.Accent, blend)
    if app._SyncSettings then
        app:_SyncSettings()
    end
    focusItems = {}
    if a > 0.005 then
        for j = 3, 1, -1 do
            box("shadow" .. j, -j * 4, j * 3, W + j * 8, H + j * 3, black, 0.10, 16 + j * 3, 5 + j)
        end
        box("outerRim", -1, -1, W + 2, H + 2, mix(ink, accent, 0.3), 0.23, 16, 9)
        box("base", 0, 0, W, H, tint, app.Opacity, 15, 10)
        box("topAccent", 202, 0, W - 260, 1, accent, 0.65, 0, 12)
        if app.Effects and app.Quality ~= "Low" then
            local count = app.Quality == "High" and 14 or 7
            for j = 1, count do
                local px = contentLeft + ((j * 89.1 + motionClock * (2 + j % 3)) % contentWidth)
                local py = 96 + ((j * 59.6 - motionClock * (2 + j % 2)) % (H - 133))
                box(
                    "dust" .. j,
                    px,
                    py,
                    1.5,
                    1.5,
                    accent,
                    (0.12 + 0.13 * math.sin(motionClock + j) ^ 2) * app.EffectStrength,
                    1,
                    15
                )
            end
            if reactUntil > motionClock then
                sigil("reaction", W - 37, 30, 13, (reactUntil - motionClock) * 0.45, 19)
            end
        end
        renderNavigation()
        label(
            "sectionEyebrow",
            selected == home and "THE OCCULT RESEARCH CLUB"
                or "KUOH ACADEMY / " .. string.upper(short(selected.Title, 24)),
            contentLeft,
            25,
            9,
            accent,
            contentA,
            true
        )
        label("sectionTitle", selected.Title, contentLeft - 1, 44, 27, ink, contentA, true)
        label(
            "sectionSub",
            short(selected.Subtitle, math.floor((contentWidth - 8) / 6)),
            contentLeft,
            79,
            11,
            muted,
            contentA
        )
        smallButton("hideUI", "close", W - 49, 23, function()
            app:Hide()
        end)
        if selected == home and #home.Controls == 0 then
            renderHome()
        elseif selected == members and #members.Controls == 0 then
            renderMembers()
        else
            renderControls()
        end
        if not app.Alive then
            return
        end
        renderCompanions()
        renderPopup()
        renderConfirm()
        if capture then
            box("captureVeil", contentLeft, 107, contentWidth, H - 140, tint, 0.95, 10, 80)
            icon("captureKey", "key", contentLeft + 20, 139, accent, 1, 84, 0, 1.5)
            label("captureTitle", "Press a key", contentLeft + 20, 196, 23, ink, 1, true, 84)
            label(
                "captureHint",
                "Escape cancels without changing your binding.",
                contentLeft + 20,
                233,
                11,
                muted,
                1,
                false,
                84
            )
        end
        box("footerRule", contentLeft, H - 22, contentWidth, 1, ink, 0.06, 0, 22)
        label("footer", "DXD 1.0", contentLeft, H - 15, 8, muted, 0.8, true)
        label(
            "footerKey",
            short(keyName(app.Keybind):upper() .. "  TO TOGGLE", compact and 23 or 34),
            compact and contentLeft + 66 or W - 187,
            H - 15,
            8,
            muted,
            0.8
        )
    end
    renderNotices(now, vp)
    previousFocus = focusItems
    -- Keep active objects cached; release drawings unused for >10 seconds.
    for id, e in pairs(pool) do
        if e.frame ~= frame then
            e.d.Visible = false
            e.stale = (e.stale or 0) + dt
            if e.stale > 10 then
                pcall(function()
                    e.raw:Remove()
                end)
                pool[id] = nil
            end
        else
            e.stale = 0
        end
    end
end
function app:GetDiagnostics()
    local drawingCount = 0
    for _ in pairs(pool) do
        drawingCount = drawingCount + 1
    end
    return {
        Drawings = drawingCount,
        Frame = frame,
        Width = W,
        Height = H,
        Compact = compact,
        PageSize = pageSize,
        Selected = selected.Title,
        LastError = self.LastError,
    }
end
