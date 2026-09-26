local function renderHome()
    local c = currentCharacter()
    local px = contentLeft
    local py = 108
    local wide = contentWidth >= 540 and H >= 540
    local artW = wide and 270 or contentWidth < 220 and 0 or math.min(132, math.floor(contentWidth * 0.38))
    local artH = artW * 4 / 3
    local artX = px + contentWidth - artW
    local artY = wide and 107 or 117
    local enter = ease("character", 1, 10)
    local drift = (app.ReducedMotion or app.Quality == "Low") and 0 or math.sin(motionClock * 0.9) * 1.5
    local parallax = (app.ReducedMotion or not active or not app.Effects) and 0
        or clamp((mx - x) / S / W - 0.5, -0.5, 0.5) * 3
    if artW > 0 then
        portrait(
            "heroPortrait",
            c.Id,
            artX + parallax,
            artY + drift + (1 - enter) * 8,
            artW,
            artH,
            contentA * enter
        )
    end
    if wide then
        label("portraitTagline", c.Title, artX + 18, artY + 181, 17, ink, contentA, true, 27)
        label(
            "portraitAbout",
            c.Id == "rias" and "President of the" or "Vice-president of the",
            artX + 18,
            artY + 214,
            11,
            muted,
            contentA,
            false,
            27
        )
        label("portraitClub", "Occult Research Club", artX + 18, artY + 232, 11, muted, contentA, false, 27)
        box("portraitDivider", artX + 18, artY + 264, artW - 36, 1, ink, 0.09, 0, 27)
        label("portraitRole", c.House, artX + 20, artY + artH - 77, 10, accent, contentA, true, 27)
        label("portraitName", c.Name, artX + 19, artY + artH - 55, 24, ink, contentA, true, 27)
        label(
            "portraitNumber",
            c.Role .. " / 0" .. (c.Id == "rias" and "1" or "2"),
            artX + 20,
            artY + artH - 23,
            10,
            muted,
            contentA,
            false,
            27
        )
        local over = interactive("react", artX, artY, artW, artH, function()
            reactUntil = motionClock + 1.3
            app:Notify({ Title = c.Short .. " is ready", Content = "Your club, your rules.", Duration = 2 })
        end)
        if app.Effects then
            sigil(
                "heroCircle",
                artX + artW / 2,
                artY + artH - 19,
                59,
                (over and 0.17 or 0.08) * contentA,
                26,
                0.25
            )
        end
    end
    local textWidth = wide and contentWidth - artW - 24 or contentWidth - artW - 18
    label("homeEyebrow", "KUOH ACADEMY  /  AFTER HOURS", px, py + 6, wide and 10 or 8, accent, contentA, true)
    label(
        "homeTitle1",
        "Welcome to",
        px - 2,
        py + 38,
        wide and 35 or contentWidth < 280 and 19 or 23,
        ink,
        contentA,
        true
    )
    label(
        "homeTitle2",
        "the club.",
        px - 2,
        py + 81,
        wide and 43 or contentWidth < 280 and 25 or 29,
        ink,
        contentA,
        true
    )
    box("homeUnderline", px, py + 139, 43, 2, accent, contentA, 0, 26)
    if wide then
        label("homeCopy1", "A little mystery. A little magic.", px, py + 164, 13, muted, contentA)
        label("homeCopy2", "Make the night your own.", px, py + 185, 13, muted, contentA)
        button("homeMembers", "Meet the members", px, py + 228, math.min(textWidth, 195), function()
            members:Select()
        end, true, "right")
        label("homeSelection", "YOUR COMPANION", px, py + 301, 9, muted, contentA, true)
        icon("homeCrown", "crown", px, py + 327, accent, contentA, 40, 0, 0.85)
        label("homeCompanion", c.Name, px + 29, py + 329, 14, ink, contentA, true)
    else
        button(
            "homeMembers",
            "Members",
            px,
            py + (H < 500 and 145 or 169),
            math.min(textWidth, 146),
            function()
                members:Select()
            end,
            true,
            "right"
        )
        if H >= 500 then
            label("homeCompanion", c.Name, px, py + 225, 15, ink, contentA, true)
            label(
                "homeCopy1",
                short("Your own corner of Kuoh Academy.", math.floor(contentWidth / 6)),
                px,
                py + 253,
                12,
                muted,
                contentA
            )
        end
    end
    local cardY = H - 106
    local cardW = (contentWidth - 12) / 2
    local cards = {
        {
            id = "homeControls",
            title = "Your controls",
            sub = "Tune the atmosphere",
            glyph = "sliders",
            target = controls,
        },
        {
            id = "homeSettings",
            title = "Make it yours",
            sub = "Display & preferences",
            glyph = "gear",
            target = settings,
        },
    }
    for i, card in ipairs(cards) do
        local cx = px + (i - 1) * (cardW + 12)
        local over = interactive(card.id, cx, cardY, cardW, 66, function()
            card.target:Select()
        end)
        box(card.id .. "rim", cx, cardY, cardW, 66, ink, 0.09, 10, 22)
        box(
            card.id .. "bg",
            cx + 1,
            cardY + 1,
            cardW - 2,
            64,
            mix(tint, white, over and 0.06 or 0.025),
            1,
            9,
            23
        )
        if wide then
            icon(card.id .. "icon", card.glyph, cx + 15, cardY + 23, accent, 1, 34)
        end
        local tx = cx + (wide and 47 or 12)
        label(card.id .. "title", card.title, tx, cardY + 15, 12, ink, contentA, true, 34)
        label(
            card.id .. "sub",
            short(card.sub, math.floor((cardW - (wide and 55 or 20)) / 5.8)),
            tx,
            cardY + 37,
            10,
            muted,
            contentA,
            false,
            34
        )
    end
end
local function renderMembers()
    if contentWidth < 360 then
        local height = math.min(185, math.floor((H - 166) / 2) - 8)
        for i, c in ipairs(characters) do
            local px = contentLeft
            local py = 108 + (i - 1) * (height + 14)
            local chosen = app.Character == c.Id
            box(
                "memberCompactRim" .. i,
                px - 1,
                py - 1,
                contentWidth + 2,
                height + 2,
                chosen and accent or ink,
                chosen and 0.7 or 0.12,
                12,
                20
            )
            box("memberCompactBody" .. i, px, py, contentWidth, height, mix(tint, white, 0.025), 1, 11, 21)
            local artW = math.min(82, contentWidth * 0.34)
            local artH = artW * 4 / 3
            portrait(
                "memberCompactPortrait" .. i,
                c.Id,
                px + contentWidth - artW - 10,
                py + 8,
                artW,
                artH,
                contentA
            )
            label(
                "memberCompactRole" .. i,
                c.Role .. " / 0" .. i,
                px + 12,
                py + 18,
                9,
                accent,
                contentA,
                true,
                27
            )
            label("memberCompactName" .. i, c.Short, px + 12, py + 44, 23, ink, contentA, true, 27)
            label(
                "memberCompactHouse" .. i,
                c.Id == "rias" and "GREMORY" or "HIMEJIMA",
                px + 12,
                py + 78,
                9,
                muted,
                contentA,
                true,
                27
            )
            button(
                "chooseCompact" .. i,
                chosen and "Selected" or "Select",
                px + 12,
                py + height - 44,
                contentWidth - 24,
                function()
                    if app.Character ~= c.Id then
                        app:SetCharacter(c.Id)
                        app:Notify({
                            Title = c.Name,
                            Content = "Companion and palette updated.",
                            Type = "success",
                        })
                    end
                end,
                chosen,
                chosen and "check" or "right"
            )
        end
        return
    end
    local gap = 16
    local cardW = (contentWidth - gap) / 2
    local py = 108
    local h = math.min(H - 165, 405)
    for i, c in ipairs(characters) do
        local px = contentLeft + (i - 1) * (cardW + gap)
        local chosen = app.Character == c.Id
        box(
            "memberRim" .. i,
            px - 1,
            py - 1,
            cardW + 2,
            h + 2,
            chosen and accent or ink,
            chosen and 0.7 or 0.10,
            12,
            20
        )
        local artH = math.min(h - 115, cardW * 224 / 400)
        local artW = artH * 400 / 224
        box("memberBody" .. i, px, py, cardW, h, mix(tint, white, 0.025), 1, 11, 21)
        portrait("memberPortrait" .. i, c.Id, px + (cardW - artW) / 2, py, artW, artH, contentA)
        if h - artH > 175 then
            label("memberTagline" .. i, c.Title, px + 13, py + artH + 28, 16, ink, contentA, true, 27)
            label("memberHouse" .. i, c.House, px + 13, py + artH + 56, 9, accent, contentA, true, 27)
        end
        local base = py + h - 95
        label("memberRole" .. i, c.Role .. " / 0" .. i, px + 13, base, 9, accent, contentA, true, 27)
        label(
            "memberName" .. i,
            contentWidth < 440 and c.Short or c.Name,
            px + 12,
            base + 19,
            contentWidth < 440 and 18 or 22,
            ink,
            contentA,
            true,
            27
        )
        button("choose" .. i, chosen and "Selected" or "Select", px + 12, py + h - 43, cardW - 24, function()
            if app.Character ~= c.Id then
                app:SetCharacter(c.Id)
                app:Notify({ Title = c.Name, Content = "Companion and palette updated.", Type = "success" })
            end
        end, chosen, chosen and "check" or "right")
    end
    label(
        "membersHint",
        "Selecting a member also sets their signature palette.",
        contentLeft,
        H - 40,
        compact and 9 or 11,
        muted,
        contentA
    )
end
local function renderControls()
    if #selected.Controls == 0 then
        sigil("empty", contentLeft + contentWidth / 2, 230, 54, 0.16, 24)
        label("emptyTitle", "A blank page. Your next idea.", contentLeft + 20, 321, 20, ink, contentA, true)
        label(
            "emptyCopy",
            "Add controls to this tab through the Lua API.",
            contentLeft + 20,
            352,
            12,
            muted,
            contentA
        )
        return
    end
    local pages = math.max(1, math.ceil(#selected.Controls / pageSize))
    selected.Page = clamp(selected.Page, 1, pages)
    for i = 1, pageSize do
        local c = selected.Controls[(selected.Page - 1) * pageSize + i]
        if c then
            renderControl(c, 108 + (i - 1) * rowHeight, i)
            if not app.Alive then
                return
            end
        end
    end
    if pages > 1 then
        label("page", string.format("%02d  /  %02d", selected.Page, pages), contentLeft, H - 47, 11, muted, 1)
        smallButton("previousPage", "left", W - 108, H - 60, function()
            selected.Page = math.max(1, selected.Page - 1)
            replayTab(selected)
        end, false, selected.Page == 1)
        smallButton("nextPage", "right", W - 66, H - 60, function()
            selected.Page = math.min(pages, selected.Page + 1)
            replayTab(selected)
        end, false, selected.Page == pages)
    end
end
local function renderConfirm()
    if not confirm then
        return
    end
    local p = confirm
    local width = math.min(430, W - 44)
    local px = (W - width) / 2
    local py = (H - 204) / 2
    box("confirmVeil", 0, 0, W, H, black, 0.74, 15, 80)
    box("confirmRim", px - 1, py - 1, width + 2, 206, accent, 0.6, 13, 81)
    box("confirmBase", px, py, width, 204, tint, 1, 12, 82)
    label("confirmTitle", p.Title, px + 22, py + 25, 22, ink, 1, true, 85)
    local lineWidth = math.floor((width - 44) / 6.5)
    label("confirmContent", short(p.Content, lineWidth), px + 22, py + 66, 12, muted, 1, false, 85)
    button("cancelConfirm", "Cancel", px + 22, py + 136, (width - 54) / 2, function()
        confirm = nil
        focusId = nil
    end, false, nil, true)
    button("acceptConfirm", "Confirm", px + 32 + (width - 54) / 2, py + 136, (width - 54) / 2, function()
        confirm = nil
        focusId = nil
        fire(p.Callback)
    end, true, "right", true)
end
local function renderNotices(now, vp)
    for i = #notices, 1, -1 do
        if now - notices[i].time > notices[i].duration + 0.3 then
            animations[notices[i].id] = nil
            table.remove(notices, i)
        end
    end
    local width = math.min(360, vp.X - 24)
    for i, n in ipairs(notices) do
        local elapsed = now - n.time
        local enter = app.ReducedMotion and 1 or 1 - (1 - clamp(elapsed / 0.3, 0, 1)) ^ 3
        local leave = clamp((elapsed - n.duration) / 0.3, 0, 1)
        local opacity = enter * (1 - leave)
        local tx = vp.X - width - 12 + (1 - opacity) * 30
        local ty = 14 + (i - 1) * 79
        local color = n.kind == "error" and RGB(255, 139, 156)
            or n.kind == "success" and RGB(139, 219, 175)
            or accent
        local id = "notice" .. i
        rect(id .. "rim", tx - 1, ty - 1, width + 2, 70, color, 0.4 * opacity, 10, 100)
        rect(id .. "base", tx, ty, width, 68, tint, 0.98 * opacity, 9, 101)
        rect(id .. "rail", tx, ty + 12, 2, 42, color, opacity, 0, 102)
        textRaw(
            id .. "title",
            short(n.title, math.floor((width - 32) / 7.5)),
            tx + 16,
            ty + 12,
            14,
            ink,
            opacity,
            true,
            104
        )
        textRaw(
            id .. "body",
            short(n.message, math.floor((width - 32) / 6)),
            tx + 16,
            ty + 36,
            11,
            muted,
            opacity,
            false,
            104
        )
        rect(
            id .. "progress",
            tx + 16,
            ty + 61,
            (width - 32) * clamp(1 - elapsed / n.duration, 0, 1),
            1.5,
            color,
            0.7 * opacity,
            1,
            104
        )
    end
end
