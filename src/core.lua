-- DxD UI. REM's control contract, cached Drawing objects and easing are retained.
-- The build supplies assetData before this file. No runtime asset requests occur.
local env = getfenv()
assert(type(Drawing) == "table" and type(Drawing.new) == "function", "DxD requires the Matcha Drawing API")
assert(type(Drawing.Fonts) == "table", "DxD requires Drawing.Fonts")
assert(
    type(iskeypressed) == "function" and type(ismouse1pressed) == "function",
    "DxD requires Matcha input APIs"
)
assert(
    Vector2 and Color3 and game and task and type(task.spawn) == "function",
    "DxD: incomplete Matcha runtime"
)
local run = game:GetService("RunService")
local world = game:GetService("Workspace")
local player = game:GetService("Players").LocalPlayer
assert(run and run.RenderStepped and player, "DxD: wait for a local player and RenderStepped")
local mouse = player:GetMouse()
local V, RGB = Vector2.new, Color3.fromRGB
local unpackArgs = table.unpack or unpack
local function finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end
local function clamp(n, lo, hi)
    return math.max(lo, math.min(hi, n))
end
local function mix(a, b, t)
    return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
local function short(s, n)
    s = tostring(s or ""):gsub("[%z\1-\31]", " ")
    if #s <= n then
        return s
    end
    local p = n - 3
    -- Avoid cutting a UTF-8 continuation sequence at a byte boundary.
    while p > 0 and s:byte(p + 1) and s:byte(p + 1) >= 128 and s:byte(p + 1) < 192 do
        p = p - 1
    end
    return s:sub(1, p) .. "..."
end
local themes = {
    {
        Name = "Gremory",
        Accent = RGB(244, 91, 117),
        Text = RGB(248, 238, 237),
        Muted = RGB(185, 165, 172),
        Base = RGB(19, 15, 22),
    },
    {
        Name = "Himejima",
        Accent = RGB(189, 150, 255),
        Text = RGB(245, 239, 255),
        Muted = RGB(178, 167, 194),
        Base = RGB(18, 15, 26),
    },
    {
        Name = "Twilight",
        Accent = RGB(232, 188, 126),
        Text = RGB(255, 245, 227),
        Muted = RGB(187, 175, 152),
        Base = RGB(21, 19, 21),
    },
    {
        Name = "Obsidian",
        Accent = RGB(201, 210, 229),
        Text = RGB(246, 248, 252),
        Muted = RGB(173, 180, 195),
        Base = RGB(13, 16, 22),
    },
}
local characters = {
    {
        Id = "rias",
        Name = "Rias Gremory",
        Short = "Rias",
        Role = "KING",
        House = "HOUSE OF GREMORY",
        Theme = "Gremory",
        Title = "The crimson heir.",
        Description = "President of the Occult Research Club.",
        Detail = "Composure. Conviction. The power of destruction.",
    },
    {
        Id = "akeno",
        Name = "Akeno Himejima",
        Short = "Akeno",
        Role = "QUEEN",
        House = "THUNDER & LIGHTNING",
        Theme = "Himejima",
        Title = "Grace before thunder.",
        Description = "Vice-president of the Occult Research Club.",
        Detail = "A quiet smile. A storm waiting to awaken.",
    },
}
local app = {
    Version = "1.0.0",
    Alive = true,
    Visible = true,
    Tabs = {},
    Theme = "Gremory",
    Character = "rias",
    Quality = "Balanced",
    Effects = true,
    ReducedMotion = false,
    EffectStrength = 0.65,
    Opacity = 0.97,
    Keybind = 0xA1,
    AvatarStatus = "unavailable",
    AssetStatus = {},
    Characters = characters,
    LastError = nil,
}
local black, white = RGB(0, 0, 0), RGB(255, 255, 255)
local pool, animations, notices = {}, { open = 0, content = 0 }, {}
local sequence, frame, connection = 0, 0, nil
local x, y, W, H, S = 100, 100, 920, 580, 1
local a, contentA, dt, last, motionClock, visitTime = 0, 0, 0, tick(), 0, 0
local mx, my, down, click, active = 0, 0, false, false, true
local previousDown, previousKey = false, false
local drag, slide, popup, capture, confirm = nil, nil, nil, nil, nil
local selected, home, members, settings, controls
local tabOffset, targetTheme, focusId = 0, 1, nil
local focusItems, previousFocus, heldKeys = {}, {}, {}
local actionQueue = {}
local compact, contentLeft, contentWidth, pageSize, rowHeight = false, 202, 692, 4, 82
local tint, ink, muted, accent = themes[1].Base, themes[1].Text, themes[1].Muted, themes[1].Accent
local avatarBytes, characterBytes, imageErrors = nil, {}, {}
local reactUntil, keyboardMode = 0, false
local function uid()
    sequence = sequence + 1
    return "dxd" .. sequence
end
local function ease(id, target, rate)
    local v = animations[id]
    if v == nil then
        v = target
    end
    v = app.ReducedMotion and target or v + (target - v) * (1 - math.exp(-dt * (rate or 14)))
    animations[id] = v
    return v
end
local function obj(id, kind)
    local e = pool[id]
    if not e then
        local raw = Drawing.new(kind)
        local cache = {}
        local d = setmetatable({}, {
            __index = function(_, key)
                return cache[key]
            end,
            __newindex = function(_, key, value)
                if cache[key] ~= value then
                    -- Size is used by the reference; newer hosts may expose FontSize only.
                    if kind == "Text" and key == "Size" then
                        local ok = pcall(function()
                            raw.Size = value
                        end)
                        if not ok then
                            raw.FontSize = value
                        end
                    else
                        raw[key] = value
                    end
                    cache[key] = value
                end
            end,
        })
        e = { d = d, raw = raw, kind = kind }
        pool[id] = e
        if kind == "Square" then
            d.Filled = true
        elseif kind == "Text" then
            d.Outline = false
        end
    end
    e.frame = frame
    return e.d
end
local function rect(id, px, py, w, h, c, opacity, r, z)
    local d = obj(id, "Square")
    d.Position = V(px, py)
    d.Size = V(math.max(0, w), math.max(0, h))
    d.Color = c
    d.Transparency = clamp(opacity, 0, 1)
    d.Corner = r or 0
    d.ZIndex = z or 20
    d.Visible = opacity > 0.005 and w > 0 and h > 0
end
local function box(id, px, py, w, h, c, opacity, r, z)
    rect(id, x + px * S, y + py * S, w * S, h * S, c, a * opacity, (r or 10) * S, z)
end
local function textRaw(id, value, px, py, size, c, opacity, bold, z)
    local d = obj(id, "Text")
    d.Text = tostring(value)
    d.Position = V(px, py)
    d.Size = math.floor(size + 0.5)
    d.Font = bold and Drawing.Fonts.SystemBold or Drawing.Fonts.System
    d.Color = c
    d.Transparency = clamp(opacity, 0, 1)
    d.ZIndex = z or 40
    d.Visible = opacity > 0.005
end
local function label(id, value, px, py, size, c, opacity, bold, z)
    textRaw(id, value, x + px * S, y + py * S, size * S, c, a * (opacity or 1), bold, z)
end
local function line(id, x1, y1, x2, y2, c, opacity, z, thickness)
    local d = obj(id, "Line")
    d.From = V(x + x1 * S, y + y1 * S)
    d.To = V(x + x2 * S, y + y2 * S)
    d.Thickness = math.max(1, (thickness or 1.4) * S)
    d.Color = c
    d.Transparency = clamp(a * opacity, 0, 1)
    d.ZIndex = z or 35
    d.Visible = a * opacity > 0.005
end
local paths = {
    crown = {
        { 1, 5, 5, 10 },
        { 5, 10, 10, 3 },
        { 10, 3, 15, 10 },
        { 15, 10, 19, 5 },
        { 19, 5, 17, 17 },
        { 17, 17, 3, 17 },
        { 3, 17, 1, 5 },
        { 5, 14, 15, 14 },
    },
    home = {
        { 1, 9, 10, 1 },
        { 10, 1, 19, 9 },
        { 4, 8, 4, 18 },
        { 4, 18, 16, 18 },
        { 16, 18, 16, 8 },
        { 8, 18, 8, 12 },
        { 8, 12, 12, 12 },
        { 12, 12, 12, 18 },
    },
    members = {
        { 6, 2, 6, 7 },
        { 6, 7, 10, 7 },
        { 10, 7, 10, 2 },
        { 10, 2, 6, 2 },
        { 2, 18, 2, 12 },
        { 2, 12, 14, 12 },
        { 14, 12, 14, 18 },
        { 15, 3, 18, 3 },
        { 18, 3, 18, 8 },
        { 17, 12, 19, 12 },
        { 19, 12, 19, 18 },
    },
    gear = {
        { 3, 3, 17, 3 },
        { 17, 3, 17, 17 },
        { 17, 17, 3, 17 },
        { 3, 17, 3, 3 },
        { 7, 7, 13, 7 },
        { 13, 7, 13, 13 },
        { 13, 13, 7, 13 },
        { 7, 13, 7, 7 },
        { 10, 0, 10, 3 },
        { 10, 17, 10, 20 },
        { 0, 10, 3, 10 },
        { 17, 10, 20, 10 },
    },
    script = { { 6, 4, 2, 10 }, { 2, 10, 6, 16 }, { 14, 4, 18, 10 }, { 18, 10, 14, 16 }, { 12, 3, 8, 17 } },
    spark = {
        { 10, 1, 12, 8 },
        { 12, 8, 19, 10 },
        { 19, 10, 12, 12 },
        { 12, 12, 10, 19 },
        { 10, 19, 8, 12 },
        { 8, 12, 1, 10 },
        { 1, 10, 8, 8 },
        { 8, 8, 10, 1 },
    },
    bolt = {
        { 11, 1, 3, 11 },
        { 3, 11, 9, 11 },
        { 9, 11, 8, 19 },
        { 8, 19, 17, 8 },
        { 17, 8, 11, 8 },
        {
            11,
            8,
            11,
            1,
        },
    },
    power = {
        { 10, 1, 10, 10 },
        { 5, 4, 2, 8 },
        { 2, 8, 2, 14 },
        { 2, 14, 6, 18 },
        { 6, 18, 14, 18 },
        { 14, 18, 18, 14 },
        { 18, 14, 18, 8 },
        { 18, 8, 15, 4 },
    },
    sliders = {
        { 2, 5, 6, 5 },
        { 10, 5, 18, 5 },
        { 6, 2, 6, 8 },
        { 10, 2, 10, 8 },
        { 6, 2, 10, 2 },
        { 6, 8, 10, 8 },
        { 2, 15, 11, 15 },
        { 15, 15, 18, 15 },
        { 11, 12, 15, 12 },
        { 11, 18, 15, 18 },
        { 11, 12, 11, 18 },
        { 15, 12, 15, 18 },
    },
    layers = {
        { 2, 6, 10, 2 },
        { 10, 2, 18, 6 },
        { 18, 6, 10, 10 },
        { 10, 10, 2, 6 },
        { 2, 11, 10, 15 },
        { 10, 15, 18, 11 },
        { 2, 15, 10, 19 },
        { 10, 19, 18, 15 },
    },
    close = { { 5, 5, 15, 15 }, { 15, 5, 5, 15 } },
    down = { { 5, 7, 10, 12 }, { 10, 12, 15, 7 } },
    up = { { 5, 12, 10, 7 }, { 10, 7, 15, 12 } },
    left = { { 12, 5, 7, 10 }, { 7, 10, 12, 15 } },
    right = { { 7, 5, 12, 10 }, { 12, 10, 7, 15 } },
    check = { { 4, 10, 8, 14 }, { 8, 14, 16, 5 } },
    key = {
        { 3, 6, 17, 6 },
        { 17, 6, 17, 15 },
        { 17, 15, 3, 15 },
        { 3, 15, 3, 6 },
        { 6, 10, 7, 10 },
        { 10, 10, 11, 10 },
        { 13, 10, 14, 10 },
        { 7, 13, 13, 13 },
    },
    info = { { 10, 5, 10, 6 }, { 10, 9, 10, 15 }, { 8, 15, 12, 15 } },
    moon = {
        { 14, 2, 7, 3 },
        { 7, 3, 3, 8 },
        { 3, 8, 4, 15 },
        { 4, 15, 10, 19 },
        { 10, 19, 17, 16 },
        { 17, 16, 12, 15 },
        { 12, 15, 8, 11 },
        { 8, 11, 9, 6 },
        { 9, 6, 14, 2 },
    },
}
paths.rem = paths.crown
local function validIcon(value)
    if value == nil or type(value) == "string" then
        return value
    end
    assert(type(value) == "table" and #value > 0 and #value <= 64, "Custom icons require 1..64 line segments")
    local copy = {}
    for i, p in ipairs(value) do
        assert(type(p) == "table" and #p == 4, "Each icon segment requires four coordinates")
        copy[i] = {}
        for j = 1, 4 do
            assert(
                finite(p[j]) and math.abs(p[j]) <= 100,
                "Icon coordinates must be finite and within -100..100"
            )
            copy[i][j] = p[j]
        end
    end
    return copy
end
local function icon(id, name, px, py, c, opacity, z, angle, scale)
    local strokes = type(name) == "table" and name or paths[name] or paths.script
    local cs, sn = math.cos(angle or 0), math.sin(angle or 0)
    scale = scale or 1
    for i, p in ipairs(strokes) do
        local ax, ay, bx, by =
            (p[1] - 10) * scale, (p[2] - 10) * scale, (p[3] - 10) * scale, (p[4] - 10) * scale
        line(
            id .. i,
            px + 10 + ax * cs - ay * sn,
            py + 10 + ax * sn + ay * cs,
            px + 10 + bx * cs - by * sn,
            py + 10 + bx * sn + by * cs,
            c,
            opacity,
            z
        )
    end
end
local function bitmap(id, bytes, px, py, w, h, opacity, r, z)
    if not bytes or imageErrors[id] then
        return false
    end
    local ok = pcall(function()
        local d = obj(id, "Image")
        d.Data = bytes
        d.Position = V(x + px * S, y + py * S)
        d.Size = V(w * S, h * S)
        d.Color = white
        d.Rounding = (r or 0) * S
        d.Transparency = clamp(a * opacity, 0, 1)
        d.ZIndex = z or 22
        d.Visible = a * opacity > 0.005
    end)
    if not ok then
        imageErrors[id] = true
        if pool[id] then
            pcall(function()
                pool[id].raw:Remove()
            end)
            pool[id] = nil
        end
    end
    return ok
end
local function asset(id)
    local record = assetData[id]
    if not record then
        return nil
    end
    local index = 1
    if app.AnimatedMedia and not app.ReducedMotion and app.Quality ~= "Low" and active then
        local position = motionClock % record.Duration
        for i, entry in ipairs(record.Frames) do
            position = position - entry.Duration
            if position < 0 then
                index = i
                break
            end
        end
    end
    local key = id .. ":" .. index
    if characterBytes[key] then
        return characterBytes[key]
    end
    if app.AssetStatus[key] == "failed" then
        return nil
    end
    local ok, bytes = pcall(function()
        assert(type(base64decode) == "function", "base64decode unavailable")
        return base64decode(record.Frames[index].Data)
    end)
    if ok and type(bytes) == "string" and bytes:sub(1, 8) == "\137PNG\13\10\26\10" then
        characterBytes[key] = bytes
        app.AssetStatus[id] = "ready"
        return bytes
    end
    app.AssetStatus[id] = "failed"
    app.AssetStatus[key] = "failed"
    return nil
end
local function hit(px, py, w, h, modal)
    return active
        and app.Visible
        and a > 0.9
        and (modal or (not popup and not capture and not confirm))
        and mx >= x + px * S
        and mx <= x + (px + w) * S
        and my >= y + py * S
        and my <= y + (py + h) * S
end
local function fire(fn, ...)
    if type(fn) ~= "function" or not app.Alive then
        return
    end
    local args, n = { ... }, select("#", ...)
    task.spawn(function()
        if not app.Alive then
            return
        end
        local ok, err = pcall(function()
            fn(unpackArgs(args, 1, n))
        end)
        if not ok and app.Alive then
            app.LastError = tostring(err)
            app:Notify({ Title = "Callback failed", Content = tostring(err), Type = "error" })
        end
    end)
end
function app:Notify(options, message)
    if not self.Alive then
        return nil
    end
    if type(options) ~= "table" then
        options = { Title = options, Content = message }
    end
    local duration = tonumber(options.Duration)
    if not finite(duration) then
        duration = 4
    end
    local n = {
        id = uid(),
        title = short(options.Title or "Occult Research Club", 40),
        message = short(options.Content or "", 72),
        kind = options.Type or "info",
        duration = clamp(duration, 1, 20),
        time = tick(),
    }
    notices[#notices + 1] = n
    if #notices > 3 then
        local old = table.remove(notices, 1)
        animations[old.id] = nil
    end
    return n.id
end
function app:SetTheme(name)
    local aliases = { purple = "Himejima", green = "Twilight", blue = "Obsidian", black = "Obsidian" }
    name = aliases[tostring(name):lower()] or name
    for i, t in ipairs(themes) do
        if t.Name:lower() == tostring(name):lower() then
            targetTheme = i
            self.Theme = t.Name
            return true
        end
    end
    return false, "Unknown theme"
end
function app:SetCharacter(id)
    for _, c in ipairs(characters) do
        if c.Id == id then
            self.Character = id
            self:SetTheme(c.Theme)
            animations.character = 0
            reactUntil = motionClock + 1
            return true
        end
    end
    return false, "Unknown character"
end
function app:SetAvatarData(bytes)
    assert(
        type(bytes) == "string" and #bytes > 0 and #bytes < 2000000,
        "Expected image bytes smaller than 2 MB"
    )
    avatarBytes = bytes
    self.AvatarStatus = "ready"
    imageErrors.avatar = nil
end
local function keyName(k)
    local names = {
        [0xA0] = "Left Shift",
        [0xA1] = "Right Shift",
        [0xA2] = "Left Ctrl",
        [0xA3] = "Right Ctrl",
        [0xA4] = "Left Alt",
        [0xA5] = "Right Alt",
        [0x2D] = "Insert",
        [0x24] = "Home",
        [0x23] = "End",
        [0x20] = "Space",
        [0x09] = "Tab",
        [0x0D] = "Enter",
        [0x2E] = "Delete",
    }
    if names[k] then
        return names[k]
    end
    if k >= 0x70 and k <= 0x87 then
        return "F" .. (k - 0x6F)
    end
    if k >= 0x30 and k <= 0x5A then
        return string.char(k)
    end
    return string.format("Key 0x%02X", k)
end
function app:SetKeybind(vk)
    assert(
        finite(vk) and vk >= 8 and vk <= 254 and vk == math.floor(vk) and vk ~= 27,
        "Use a VK key code (8..254), except Escape"
    )
    self.Keybind = vk
    previousKey = iskeypressed(vk)
    return true
end
function app:Show()
    if self.Alive then
        self.Visible = true
    end
end
function app:Hide()
    self.Visible = false
    popup = nil
    capture = nil
    confirm = nil
    drag = nil
    slide = nil
end
function app:Destroy()
    if not self.Alive then
        return
    end
    self.Alive = false
    if connection then
        connection:Disconnect()
        connection = nil
    end
    if self._DestroyAudio then
        self:_DestroyAudio()
    end
    for _, e in pairs(pool) do
        pcall(function()
            e.raw:Remove()
        end)
    end
    pool = {}
    animations = {}
    notices = {}
    characterBytes = {}
    focusItems = {}
    previousFocus = {}
    actionQueue = {}
    popup = nil
    capture = nil
    confirm = nil
    slide = nil
    drag = nil
    for _, tab in ipairs(self.Tabs) do
        for _, c in ipairs(tab.Controls) do
            c.Callback = nil
        end
    end
    if env.DxD == self then
        env.DxD = nil
    end
    if env.Rem == self then
        env.Rem = nil
    end
end
local Tab = {}
Tab.__index = Tab
local Control = {}
Control.__index = Control
function Control:GetValue()
    return self.Value
end
function Control:SetValue(value, silent)
    assert(app.Alive, "DxD has been destroyed")
    if self.Kind == "toggle" then
        value = not not value
    elseif self.Kind == "slider" then
        assert(finite(value), "Slider value must be a finite number")
        value = clamp(value, self.Min, self.Max)
        value = self.Min + math.floor((value - self.Min) / self.Step + 0.5) * self.Step
        value = clamp(value, self.Min, self.Max)
    elseif self.Kind == "dropdown" then
        local found = false
        for _, item in ipairs(self.Options) do
            if item == value then
                found = true
                break
            end
        end
        assert(found, "Dropdown value must be one of its Options")
    end
    local changed = self.Value ~= value
    self.Value = value
    if changed and not silent then
        fire(self.Callback, value)
    end
    return self
end
function Tab:_add(kind, o)
    assert(app.Alive, "DxD has been destroyed")
    o = o or {}
    assert(type(o) == "table", "Control options must be a table")
    assert(o.Callback == nil or type(o.Callback) == "function", "Callback must be a function")
    local c = setmetatable({
        Id = uid(),
        Kind = kind,
        Title = short(o.Title or kind, 80),
        Description = short(o.Description or "", 160),
        Callback = o.Callback,
        Disabled = o.Disabled == true,
    }, Control)
    c.Icon = validIcon(o.Icon)
        or ({
            button = "bolt",
            toggle = "power",
            slider = "sliders",
            dropdown = "layers",
            keybind = "key",
            label = "spark",
        })[kind]
    c.ButtonText = short(o.ButtonText or "Run", 18)
    c.Min = o.Min or 0
    c.Max = o.Max or 100
    c.Step = o.Step or 1
    if kind == "slider" then
        assert(
            finite(c.Min) and finite(c.Max) and finite(c.Step) and c.Max > c.Min and c.Step > 0,
            "Slider requires finite Max > Min and Step > 0"
        )
    end
    c.Options = {}
    if kind == "dropdown" then
        assert(
            type(o.Options) == "table" and #o.Options > 0 and #o.Options <= 128,
            "Dropdown requires 1..128 Options"
        )
        for i, v in ipairs(o.Options) do
            assert(type(v) == "string", "Dropdown Options must be strings")
            c.Options[i] = v
        end
    end
    c.Value = o.Default
    if kind == "toggle" then
        c.Value = not not o.Default
    elseif kind == "slider" then
        c:SetValue(o.Default or c.Min, true)
    elseif kind == "dropdown" then
        c:SetValue(o.Default or c.Options[1], true)
    end
    animations[c.Id .. "appear"] = 0
    self.Controls[#self.Controls + 1] = c
    return c
end
function Tab:AddButton(o)
    return self:_add("button", o)
end
function Tab:AddToggle(o)
    return self:_add("toggle", o)
end
function Tab:AddSlider(o)
    return self:_add("slider", o)
end
function Tab:AddDropdown(o)
    return self:_add("dropdown", o)
end
function Tab:AddLabel(o)
    if type(o) == "string" then
        o = { Title = o }
    end
    return self:_add("label", o)
end
local function replayTab(tab)
    animations.content = 0
    contentA = 0
    visitTime = motionClock
    popup = nil
    slide = nil
    capture = nil
    focusId = nil
    for _, c in ipairs(tab.Controls) do
        animations[c.Id .. "appear"] = 0
    end
end
function Tab:Select()
    assert(app.Alive, "DxD has been destroyed")
    if selected ~= self then
        selected = self
        replayTab(self)
    end
    for i, t in ipairs(app.Tabs) do
        if t == self then
            tabOffset = math.max(0, i - 5)
        end
    end
    return self
end
function app:AddTab(o)
    assert(self.Alive, "DxD has been destroyed")
    if type(o) == "string" then
        o = { Title = o }
    end
    o = o or {}
    assert(type(o) == "table", "Tab options must be a table")
    local tab = setmetatable({
        Id = uid(),
        Title = short(o.Title or "Tab", 32),
        Subtitle = short(o.Subtitle or "Your controls, beautifully in place.", 90),
        Icon = validIcon(o.Icon) or "script",
        Controls = {},
        Page = 1,
    }, Tab)
    self.Tabs[#self.Tabs + 1] = tab
    if not selected then
        selected = tab
    end
    return tab
end
function app:Confirm(options)
    assert(type(options) == "table" and type(options.Callback) == "function", "Confirm requires a Callback")
    confirm = {
        Title = short(options.Title or "Are you sure?", 50),
        Content = short(options.Content or "", 95),
        Callback = options.Callback,
    }
    focusId = nil
    popup = nil
end
local function interactive(id, px, py, w, h, fn, adjust, modal, disabled)
    local allowed = not disabled and (modal or (not popup and not capture and not confirm))
    if allowed then
        focusItems[#focusItems + 1] = { id = id, fn = fn, adjust = adjust }
    end
    local over = allowed and hit(px, py, w, h, modal)
    -- Apply mouse actions after the drawing pass, so unload cannot allocate new objects mid-frame.
    if over and click then
        click = false
        keyboardMode = false
        focusId = id
        actionQueue[#actionQueue + 1] = fn
    end
    if allowed and focusId == id and keyboardMode then
        box(
            id .. "focus",
            px - 2,
            py - 2,
            w + 4,
            h + 4,
            accent,
            0.9,
            10,
            confirm and 88 or modal and 75 or 29
        )
        box(id .. "focusinner", px, py, w, h, tint, 1, 8, confirm and 89 or modal and 76 or 30)
    end
    return over
end
