-- All coordinates are logical UI pixels. Compact mode reflows; it does not shrink text.
local function button(id, title, px, py, w, fn, primary, glyph, modal, disabled)
    local over = interactive(id, px, py, w, 38, fn, nil, modal, disabled)
    local hover = ease(id .. "hover", over and 1 or 0)
    local opacity = disabled and 0.35 or 1
    local layer = confirm and 90 or modal and 77 or 31
    box(id .. "rim", px, py, w, 38, primary and accent or ink, (primary and 0.8 or 0.12) * opacity, 8, layer)
    box(
        id .. "body",
        px + 1,
        py + 1,
        w - 2,
        36,
        primary and accent or mix(tint, white, 0.055 + hover * 0.04),
        (primary and 0.9 or 1) * opacity,
        7,
        layer + 1
    )
    label(id .. "text", title, px + 13, py + 11, 12, primary and tint or ink, opacity, true, layer + 4)
    if glyph then
        icon(id .. "glyph", glyph, px + w - 29, py + 9, primary and tint or accent, opacity, layer + 4)
    end
    return over
end
local function smallButton(id, glyph, px, py, fn, modal, disabled)
    local over = interactive(id, px, py, 34, 34, fn, nil, modal, disabled)
    box(
        id .. "body",
        px,
        py,
        34,
        34,
        ink,
        disabled and 0.025 or 0.045 + ease(id .. "hover", over and 0.06 or 0),
        8,
        modal and 77 or 32
    )
    icon(
        id .. "icon",
        glyph,
        px + 7,
        py + 7,
        disabled and muted or accent,
        disabled and 0.3 or 1,
        modal and 80 or 35
    )
end
local function sigil(id, cx, cy, r, opacity, z, tilt)
    local count = app.Quality == "Low" and 20 or app.Quality == "High" and 48 or 32
    local rotation = app.ReducedMotion and 0 or motionClock * 0.07
    for ring = 1, 2 do
        local radius = r * (ring == 1 and 1 or 0.82)
        for j = 1, count do
            local p = (j - 1) * math.pi * 2 / count + rotation
            local q = j * math.pi * 2 / count + rotation
            line(
                id .. ring .. "_" .. j,
                cx + math.cos(p) * radius,
                cy + math.sin(p) * radius * (tilt or 1),
                cx + math.cos(q) * radius,
                cy + math.sin(q) * radius * (tilt or 1),
                accent,
                opacity,
                z,
                1
            )
        end
    end
    for j = 1, 6 do
        local p = j * math.pi / 3 + rotation
        local q = p + math.pi * 2 / 3
        line(
            id .. "star" .. j,
            cx + math.cos(p) * r * 0.7,
            cy + math.sin(p) * r * 0.7 * (tilt or 1),
            cx + math.cos(q) * r * 0.7,
            cy + math.sin(q) * r * 0.7 * (tilt or 1),
            accent,
            opacity * 0.8,
            z,
            1
        )
    end
end
local function portrait(id, character, px, py, w, h, opacity)
    local bytes = asset(artworkId(character))
    local imageH = math.min(h, w * 224 / 400)
    local imageW = imageH * 400 / 224
    box(id .. "under", px, py, w, h, mix(tint, accent, 0.07), opacity, 12, 21)
    if not bitmap(id, bytes, px + (w - imageW) / 2, py, imageW, imageH, opacity, 12, 22) then
        sigil(id .. "fallback", px + w / 2, py + h * 0.45, math.min(w, h) * 0.28, 0.35 * opacity, 24)
        icon(id .. "crown", "crown", px + w / 2 - 10, py + h * 0.45 - 10, accent, opacity, 25, 0, 1.8)
        label(
            id .. "fallbackText",
            "Portrait unavailable",
            px + 18,
            py + h - 40,
            12,
            muted,
            opacity,
            false,
            25
        )
    end
end
local function currentCharacter()
    for _, c in ipairs(characters) do
        if c.Id == app.Character then
            return c
        end
    end
    return characters[1]
end
local function beginCapture()
    capture = { keys = {} }
    popup = nil
    focusId = nil
    for k = 8, 254 do
        capture.keys[k] = iskeypressed(k)
    end
end
local function numberText(n)
    return string.format("%.2f", n):gsub("%.?0+$", "")
end
local function renderControl(c, py, index)
    local id, px, width = c.Id, contentLeft, contentWidth
    local narrow = width < 470
    local rh = rowHeight - 10
    local enter = ease(
        id .. "appear",
        (app.ReducedMotion or motionClock - visitTime > (index - 1) * 0.035) and 1 or 0,
        16
    )
    local ca = contentA * enter * (c.Disabled and 0.45 or 1)
    py = py + (1 - enter) * 5
    local hover = ease(id .. "cardhover", hit(px, py, width, rh) and 1 or 0)
    box(id .. "rim", px, py, width, rh, ink, 0.09 * ca, 10, 22)
    box(id .. "card", px + 1, py + 1, width - 2, rh - 2, mix(tint, white, 0.035 + hover * 0.015), ca, 9, 23)
    local labelX = px + (narrow and 14 or 50)
    if not narrow then
        box(id .. "badge", px + 12, py + 15, 27, 27, accent, 0.07 * ca, 7, 24)
        icon(id .. "icon", c.Icon, px + 15.5, py + 18.5, accent, ca, 27, 0, 0.85)
    end
    local labelWidth = narrow and width - 28 or width - (c.Kind == "label" and 68 or 260)
    label(
        id .. "title",
        short(c.Title, math.max(12, math.floor(labelWidth / 7.1))),
        labelX,
        py + 13,
        13,
        ink,
        ca,
        true,
        27
    )
    label(
        id .. "description",
        short(c.Description, math.max(12, math.floor(labelWidth / 5.8))),
        labelX,
        py + 36,
        11,
        muted,
        ca,
        false,
        27
    )
    local rx = px + width - 190
    local ry = py + 17
    if narrow then
        rx = px + 14
        ry = py + 61
    end
    local rw = narrow and width - 28 or 174
    if c.Kind == "button" then
        button(id .. "action", c.ButtonText, rx, ry, rw, function()
            fire(c.Callback)
        end, false, "right", false, c.Disabled)
    elseif c.Kind == "toggle" then
        local bx = rx + rw - 47
        interactive(id .. "action", rx, ry, rw, 38, function()
            c:SetValue(not c.Value)
        end, nil, false, c.Disabled)
        local v = ease(id .. "switch", c.Value and 1 or 0)
        label(id .. "state", c.Value and "Enabled" or "Disabled", rx + 4, ry + 12, 11, muted, ca, false, 34)
        box(id .. "switch", bx, ry + 7, 44, 24, mix(muted, accent, v), (0.18 + v * 0.60) * ca, 12, 33)
        box(id .. "knob", bx + 4 + 20 * v, ry + 11, 16, 16, ink, ca, 8, 34)
    elseif c.Kind == "dropdown" then
        local function openDropdown()
            popup = { control = c, x = rx, y = math.min(ry + 42, H - 208), width = rw, offset = 0 }
            focusId = nil
            animations.dropdown = 0
        end
        interactive(id .. "action", rx, ry, rw, 38, openDropdown, function(direction)
            for i, v in ipairs(c.Options) do
                if v == c.Value then
                    c:SetValue(c.Options[clamp(i + direction, 1, #c.Options)])
                    break
                end
            end
        end, false, c.Disabled)
        box(id .. "select", rx, ry, rw, 38, ink, 0.055 * ca, 8, 32)
        label(
            id .. "value",
            short(c.Value, math.floor((rw - 43) / 6.4)),
            rx + 12,
            ry + 12,
            12,
            ink,
            ca,
            true,
            34
        )
        icon(id .. "arrow", "down", rx + rw - 28, ry + 9, accent, ca, 34)
    elseif c.Kind == "keybind" then
        button(
            id .. "action",
            capture and "Press a key..." or keyName(app.Keybind),
            rx,
            ry,
            rw,
            beginCapture,
            false,
            "key"
        )
    elseif c.Kind == "slider" then
        local sx, sw = rx + 3, rw - 6
        interactive(id .. "action", rx, ry, rw, 38, function()
            if not keyboardMode then
                slide = c
                c.SlideX = sx
                c.SlideWidth = sw
            end
        end, function(direction)
            c:SetValue(c.Value + direction * c.Step)
        end, false, c.Disabled)
        if slide == c and down and active and not popup and not capture and not c.Disabled then
            c:SetValue(c.Min + clamp((mx - x - sx * S) / (sw * S), 0, 1) * (c.Max - c.Min))
        end
        label(id .. "min", numberText(c.Min), sx, ry, 10, muted, ca, false, 34)
        label(id .. "value", numberText(c.Value), rx + rw - 47, ry, 12, accent, ca, true, 34)
        local v = ease(id .. "fill", (c.Value - c.Min) / (c.Max - c.Min))
        box(id .. "track", sx, ry + 27, sw, 3, ink, 0.15 * ca, 2, 33)
        box(id .. "fill", sx, ry + 27, sw * v, 3, accent, ca, 2, 34)
        box(id .. "thumb", sx + sw * v - 5, ry + 23, 11, 11, ink, ca, 6, 35)
    end
end
local function renderPopup()
    if not popup then
        return
    end
    local p = popup
    local c = p.control
    local reveal = ease("dropdown", 1, 24)
    local count = math.min(4, #c.Options - p.offset)
    local extra = #c.Options > 4 and 40 or 0
    local height = count * 35 + 12 + extra
    box("popshadow", p.x - 4, p.y + 4, p.width + 8, height + 6, black, 0.5 * reveal, 11, 68)
    box("poprim", p.x - 1, p.y - 1, p.width + 2, height + 2, accent, 0.5 * reveal, 9, 69)
    box("popup", p.x, p.y, p.width, height, mix(tint, white, 0.07), reveal, 8, 70)
    for j = 1, count do
        local value = c.Options[p.offset + j]
        local py = p.y + 6 + (j - 1) * 35
        local over = interactive("option" .. j, p.x + 4, py, p.width - 8, 33, function()
            c:SetValue(value)
            popup = nil
            focusId = c.Id .. "action"
        end, nil, true)
        local chosen = c.Value == value
        box(
            "optionbg" .. j,
            p.x + 4,
            py,
            p.width - 8,
            33,
            accent,
            (chosen and 0.17 or over and 0.10 or 0) * reveal,
            5,
            71
        )
        label(
            "optionvalue" .. j,
            short(value, math.floor((p.width - 40) / 6.2)),
            p.x + 11,
            py + 10,
            12,
            ink,
            reveal,
            chosen,
            74
        )
        if chosen then
            icon("optioncheck" .. j, "check", p.x + p.width - 28, py + 6, accent, reveal, 74)
        end
    end
    if extra > 0 then
        smallButton("optionprev", "left", p.x + p.width - 78, p.y + height - 38, function()
            p.offset = math.max(0, p.offset - 4)
        end, true, p.offset == 0)
        smallButton("optionnext", "right", p.x + p.width - 39, p.y + height - 38, function()
            p.offset = math.min(math.floor((#c.Options - 1) / 4) * 4, p.offset + 4)
        end, true, p.offset + 4 >= #c.Options)
    end
    if click and not hit(p.x, p.y, p.width, height, true) then
        popup = nil
        click = false
    end
end
