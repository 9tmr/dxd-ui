-- Existing anime media and permission-confirmed sprites; never generated artwork.
local artwork = {
    rias = {
        { Name = "Anime loop", Id = "rias" },
        { Name = "Opening frame", Id = "rias_still" },
        { Name = "Closing frame", Id = "rias_end" },
    },
    akeno = {
        { Name = "Golden evening", Id = "akeno" },
        { Name = "Quiet moment", Id = "akeno_evening" },
        { Name = "Blue sky", Id = "akeno_sky" },
        { Name = "Anime loop", Id = "akeno_motion" },
        { Name = "Opening frame", Id = "akeno_motion_still" },
        { Name = "Closing frame", Id = "akeno_motion_end" },
    },
}
app.RiasArtwork, app.AkenoArtwork = "Anime loop", "Golden evening"
app.RiasCompanion, app.AkenoCompanion = true, true
app.CompanionOrder, app.AnimatedMedia = "Rias first", true
local companionReaction = { rias = -100, akeno = -100 }
local function artworkId(character)
    local name = character == "rias" and app.RiasArtwork or app.AkenoArtwork
    for _, entry in ipairs(artwork[character] or {}) do
        if entry.Name == name then
            return entry.Id
        end
    end
    return character
end
function app:GetArtworkOptions(character)
    local result = {}
    for _, entry in ipairs(artwork[character] or {}) do
        result[#result + 1] = entry.Name
    end
    return result
end
function app:SetArtwork(character, name)
    for _, entry in ipairs(artwork[character] or {}) do
        if entry.Name == name then
            self[character == "rias" and "RiasArtwork" or "AkenoArtwork"] = name
            return true
        end
    end
    return false, "Unknown character artwork."
end
function app:SetRiasArtwork(value)
    return self:SetArtwork("rias", value)
end
function app:SetAkenoArtwork(value)
    return self:SetArtwork("akeno", value)
end
function app:SetCompanionEnabled(character, enabled)
    if not artwork[character] or type(enabled) ~= "boolean" then
        return false
    end
    self[character == "rias" and "RiasCompanion" or "AkenoCompanion"] = enabled
    return true
end
function app:SetRiasCompanion(value)
    return self:SetCompanionEnabled("rias", value)
end
function app:SetAkenoCompanion(value)
    return self:SetCompanionEnabled("akeno", value)
end
function app:SetCompanionOrder(value)
    if value ~= "Rias first" and value ~= "Akeno first" then
        return false
    end
    self.CompanionOrder = value
    return true
end
function app:SetAnimatedMedia(value)
    if type(value) ~= "boolean" then
        return false
    end
    self.AnimatedMedia = value
    return true
end
function app:ReactCompanion(character)
    if not artwork[character] then
        return false
    end
    companionReaction[character] = motionClock
    return true
end
local function renderCompanions()
    local order = app.CompanionOrder == "Rias first" and { "rias", "akeno" } or { "akeno", "rias" }
    local available = math.max(36, y / S - 5)
    local height = math.min(112, available)
    local slot = 0
    for _, character in ipairs(order) do
        if app[character == "rias" and "RiasCompanion" or "AkenoCompanion"] then
            local record = assetData[character .. "_pixel"]
            local width = height * record.Width / record.Height
            slot = slot + 1
            local px = W - 55 - (3 - slot) * (height * 0.85 + 8)
            local elapsed = motionClock - companionReaction[character]
            local jump = elapsed >= 0 and elapsed < 0.7 and math.sin(elapsed / 0.7 * math.pi) * 12 or 0
            local drift = math.sin(motionClock * 1.8 + slot) * 1.2
            if app.ReducedMotion or app.Quality == "Low" or not app.Effects then
                jump, drift = 0, 0
            end
            local py = math.max(-y / S + 2, -height - jump + drift + 2)
            local id = "companion_" .. character
            local over = interactive(id, px, py, width, height, function()
                app:ReactCompanion(character)
                app:Notify({
                    Title = character == "rias" and "Rias Gremory" or "Akeno Himejima",
                    Content = "Right here with you.",
                    Duration = 2,
                })
            end)
            bitmap(id, asset(character .. "_pixel"), px, py, width, height, 1, 0, 58)
            if over or elapsed < 0.7 then
                label(
                    id .. "name",
                    character == "rias" and "RIAS" or "AKENO",
                    px,
                    py + height + 3,
                    9,
                    accent,
                    1,
                    true,
                    59
                )
            end
        end
    end
end
