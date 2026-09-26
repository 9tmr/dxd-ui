-- Deterministic Matcha Drawing test double. This is not a native-runtime emulator.
-- Rendering properties and lifecycle are checked; GPU/audio/host compatibility require Matcha.
local unpackValues = table.unpack or unpack
local runtime = {
    now = 0,
    drawings = {},
    events = {},
    threads = {},
    keys = {},
    mouse = { X = 0, Y = 0 },
    down = false,
    active = true,
    warnings = {},
    errors = {},
    printed = {},
    networkRequests = 0,
    imageAttempts = 0,
    failImages = false,
}
_G.__runtime = runtime

local function finite(number)
    return type(number) == "number" and number == number and number ~= math.huge and number ~= -math.huge
end

local Vector = {}
Vector.__index = Vector
Vector.__type = "Vector2"
function Vector.__eq(a, b)
    return a.X == b.X and a.Y == b.Y
end
function Vector.__add(a, b)
    return Vector2.new(a.X + b.X, a.Y + b.Y)
end
function Vector.__sub(a, b)
    return Vector2.new(a.X - b.X, a.Y - b.Y)
end
function Vector.__mul(a, b)
    if type(a) == "number" then
        return Vector2.new(a * b.X, a * b.Y)
    end
    return Vector2.new(a.X * b, a.Y * b)
end
function Vector.__div(a, b)
    return Vector2.new(a.X / b, a.Y / b)
end
Vector2 = {
    new = function(x, y)
        assert(finite(x) and finite(y), "Vector2 coordinates must be finite")
        return setmetatable({ X = x, Y = y }, Vector)
    end,
}

local Color = {}
Color.__index = Color
Color.__type = "Color3"
function Color.__eq(a, b)
    return a.R == b.R and a.G == b.G and a.B == b.B
end
function Color:Lerp(other, alpha)
    return Color3.new(
        self.R + (other.R - self.R) * alpha,
        self.G + (other.G - self.G) * alpha,
        self.B + (other.B - self.B) * alpha
    )
end
Color3 = {
    new = function(r, g, b)
        assert(finite(r) and finite(g) and finite(b), "Color3 channels must be finite")
        return setmetatable({ R = r, G = g, B = b }, Color)
    end,
    fromRGB = function(r, g, b)
        return Color3.new(r / 255, g / 255, b / 255)
    end,
}

function typeof(value)
    local metatable = type(value) == "table" and getmetatable(value)
    return metatable and metatable.__type or type(value)
end
function getfenv()
    return _G
end
function getgenv()
    return _G
end
function tick()
    return runtime.now
end
os.clock = tick
function isrbxactive()
    return runtime.active
end
function ismouse1pressed()
    return runtime.down
end
function iskeypressed(key)
    return runtime.keys[key] == true
end
function getmousepos()
    return Vector2.new(runtime.mouse.X, runtime.mouse.Y)
end
getmouseposition = getmousepos
function warn(message)
    runtime.warnings[#runtime.warnings + 1] = tostring(message)
end
function print(...)
    local values = { ... }
    for index, value in ipairs(values) do
        values[index] = tostring(value)
    end
    runtime.printed[#runtime.printed + 1] = table.concat(values, " ")
end

Drawing = { Fonts = { UI = 0, System = 0, Plex = 1, Monospace = 2, SystemBold = 3 } }
function Drawing.new(kind)
    assert(
        kind == "Square"
            or kind == "Text"
            or kind == "Line"
            or kind == "Image"
            or kind == "Circle"
            or kind == "Triangle"
            or kind == "Quad",
        "Unsupported drawing: " .. tostring(kind)
    )
    if kind == "Image" then
        runtime.imageAttempts = runtime.imageAttempts + 1
        assert(not runtime.failImages, "Simulated unavailable Image drawing capability")
    end
    local entry =
        { kind = kind, properties = { Visible = false, Transparency = 1, ZIndex = 0 }, removed = false }
    runtime.drawings[#runtime.drawings + 1] = entry
    local object = setmetatable({}, {
        __index = function(_, key)
            if key == "Remove" or key == "Destroy" then
                return function()
                    entry.removed = true
                    entry.properties.Visible = false
                end
            end
            if key == "TextBounds" then
                return Vector2.new(
                    #tostring(entry.properties.Text or "") * (entry.properties.Size or 13) * 0.55,
                    entry.properties.Size or 13
                )
            end
            return entry.properties[key]
        end,
        __newindex = function(_, key, value)
            assert(not entry.removed, "A removed drawing was modified")
            if key == "Transparency" then
                assert(
                    finite(value) and value >= 0 and value <= 1,
                    "Drawing.Transparency must be finite and between 0 and 1"
                )
            end
            if key == "Size" and type(value) == "number" then
                assert(finite(value) and value >= 0, "Drawing.Size must be non-negative")
            end
            if key == "Size" and type(value) == "table" then
                assert(value.X >= 0 and value.Y >= 0, "Drawing dimensions must be non-negative")
            end
            if key == "Thickness" or key == "Radius" or key == "Rounding" or key == "Corner" then
                assert(finite(value) and value >= 0, "Invalid drawing dimension " .. key)
            end
            entry.properties[key] = value
        end,
    })
    return object
end

local function event(name)
    local listeners = {}
    runtime.events[name] = listeners
    return {
        Connect = function(_, callback)
            local connection = { Connected = true }
            function connection:Disconnect()
                self.Connected = false
            end
            listeners[#listeners + 1] = { callback = callback, connection = connection }
            return connection
        end,
    }
end

local services = {
    RunService = {
        RenderStepped = event("RenderStepped"),
        Heartbeat = event("Heartbeat"),
        Stepped = event("Stepped"),
    },
    Workspace = { CurrentCamera = { ViewportSize = Vector2.new(1440, 900) } },
    Players = {
        LocalPlayer = {
            UserId = 12345,
            Name = "TestPlayer",
            DisplayName = "Test Player",
            GetMouse = function()
                return runtime.mouse
            end,
        },
    },
    HttpService = {
        JSONEncode = function(_, value)
            return __json_encode(value)
        end,
        JSONDecode = function(_, value)
            return __json_decode(value)
        end,
        GenerateGUID = function()
            return "test-session-0001"
        end,
    },
}
workspace = services.Workspace
game = {
    GetService = function(_, name)
        assert(services[name], "Service unavailable in test runtime: " .. tostring(name))
        return services[name]
    end,
    HttpGet = function()
        runtime.networkRequests = runtime.networkRequests + 1
        error("Network disabled in deterministic tests")
    end,
    IsLoaded = function()
        return true
    end,
}
function request()
    runtime.networkRequests = runtime.networkRequests + 1
    return { StatusCode = 503, Body = "" }
end
http_request = request

local function resumeThread(item, ...)
    if item.cancelled or coroutine.status(item.thread) == "dead" then
        return
    end
    local ok, delay = coroutine.resume(item.thread, ...)
    if not ok then
        runtime.errors[#runtime.errors + 1] = tostring(delay)
        item.cancelled = true
    elseif coroutine.status(item.thread) ~= "dead" then
        item.at = runtime.now + (tonumber(delay) or 0)
    end
end
task = {}
function task.spawn(callback, ...)
    local item = { thread = coroutine.create(callback), at = runtime.now }
    runtime.threads[#runtime.threads + 1] = item
    resumeThread(item, ...)
    return item.thread
end
function task.defer(callback, ...)
    local args = { ... }
    local item = {
        thread = coroutine.create(function()
            callback(unpackValues(args))
        end),
        at = runtime.now + 0.00001,
    }
    runtime.threads[#runtime.threads + 1] = item
    return item.thread
end
function task.delay(seconds, callback, ...)
    local args = { ... }
    local item = {
        thread = coroutine.create(function()
            callback(unpackValues(args))
        end),
        at = runtime.now + seconds,
    }
    runtime.threads[#runtime.threads + 1] = item
    return item.thread
end
function task.wait(seconds)
    local _, main = coroutine.running()
    if main then
        return seconds or 0
    end
    return coroutine.yield(seconds or 1 / 60)
end
function task.cancel(thread)
    for _, item in ipairs(runtime.threads) do
        if item.thread == thread then
            item.cancelled = true
        end
    end
end
wait = task.wait

function __step(seconds)
    seconds = seconds or 1 / 60
    runtime.now = runtime.now + seconds
    for _, item in ipairs(runtime.threads) do
        if not item.cancelled and item.at <= runtime.now then
            resumeThread(item)
        end
    end
    for _, name in ipairs({ "Stepped", "Heartbeat", "RenderStepped" }) do
        for _, listener in ipairs(runtime.events[name]) do
            if listener.connection.Connected then
                local ok, message = pcall(listener.callback, seconds)
                if not ok then
                    runtime.errors[#runtime.errors + 1] = tostring(message)
                end
            end
        end
    end
end
function __settle(frames)
    for _ = 1, frames or 90 do
        __step(1 / 60)
    end
end
function __move(x, y)
    runtime.mouse.X = x
    runtime.mouse.Y = y
end
function __press(x, y)
    __move(x, y)
    runtime.down = true
    __step(1 / 60)
end
function __release()
    runtime.down = false
    __step(1 / 60)
end
function __click(x, y)
    __press(x, y)
    __release()
end
function __key(code, held)
    runtime.keys[code] = held == true
end
function __resize(width, height)
    workspace.CurrentCamera.ViewportSize = Vector2.new(width, height)
end
function __setActive(active)
    runtime.active = active == true
end

function __stats()
    local stats = {
        created = #runtime.drawings,
        live = 0,
        visible = 0,
        connections = 0,
        tasks = 0,
        warnings = runtime.warnings,
        errors = runtime.errors,
        networkRequests = runtime.networkRequests,
        imageAttempts = runtime.imageAttempts,
    }
    for _, drawing in ipairs(runtime.drawings) do
        if not drawing.removed then
            stats.live = stats.live + 1
            if drawing.properties.Visible then
                stats.visible = stats.visible + 1
            end
        end
    end
    for _, listeners in pairs(runtime.events) do
        for _, listener in ipairs(listeners) do
            if listener.connection.Connected then
                stats.connections = stats.connections + 1
            end
        end
    end
    for _, item in ipairs(runtime.threads) do
        if not item.cancelled and coroutine.status(item.thread) ~= "dead" then
            stats.tasks = stats.tasks + 1
        end
    end
    return stats
end
function __capture()
    local snapshot = {
        width = workspace.CurrentCamera.ViewportSize.X,
        height = workspace.CurrentCamera.ViewportSize.Y,
        time = runtime.now,
        drawings = {},
        stats = __stats(),
    }
    for index, drawing in ipairs(runtime.drawings) do
        if not drawing.removed and drawing.properties.Visible then
            local item = { kind = drawing.kind, index = index }
            for key, value in pairs(drawing.properties) do
                item[key] = value
            end
            snapshot.drawings[#snapshot.drawings + 1] = item
        end
    end
    return snapshot
end
