-- Preferences are data only: configuration files never contain executable Lua.
do
    local CONFIG_FILE = "dxd-ui-v1.cfg"
    local MAX_CONFIG_BYTES = 8192
    local MAX_CONFIG_LINES = 96
    local audioAdapter = nil
    local audioBusy = false
    local pendingAudioCleanup = false
    local volumes = { master = 0.6, music = 0.55, sfx = 0.5 }
    local volumeOrder = { "master", "music", "sfx" }
    local qualityNames = { Low = true, Balanced = true, High = true }
    local defaults = {
        RiasArtwork = "Anime loop",
        AkenoArtwork = "Golden evening",
        RiasCompanion = true,
        AkenoCompanion = true,
        CompanionOrder = "Rias first",
        AnimatedMedia = true,
        Theme = "Gremory",
        Character = "rias",
        Quality = "Balanced",
        ReducedMotion = false,
        Effects = true,
        EffectStrength = 0.65,
        Keybind = 0xA1,
        Opacity = 0.97,
    }

    app.SettingsStatus = "Settings are stored only when you choose Save."
    app.AudioStatus = "No audio adapter connected."
    app.Audio = { playing = false, available = false, volume = volumes }

    local function boundedNumber(value, minimum, maximum)
        return type(value) == "number" and finite(value) and value >= minimum and value <= maximum
    end

    local function settingsResult(ok, message)
        app.SettingsStatus = message
        return ok, message
    end

    local function callAdapter(adapter, method, ...)
        if audioBusy then
            return false, "An audio operation is already in progress."
        end
        audioBusy = true
        local ok, result = pcall(adapter[method], adapter, ...)
        audioBusy = false
        if pendingAudioCleanup then
            pendingAudioCleanup = false
            app:_DestroyAudio()
        end
        if not ok or result == false then
            return false, "The audio adapter could not " .. method .. "."
        end
        return true
    end

    function app:SetQuality(value)
        if type(value) ~= "string" or not qualityNames[value] then
            return false, "Quality must be Low, Balanced, or High."
        end
        self.Quality = value
        return true
    end

    function app:SetReducedMotion(value)
        if type(value) ~= "boolean" then
            return false, "Reduced motion must be a boolean."
        end
        self.ReducedMotion = value
        return true
    end

    function app:SetEffects(value)
        if type(value) ~= "boolean" then
            return false, "Effects must be a boolean."
        end
        self.Effects = value
        return true
    end

    function app:SetEffectStrength(value)
        if not boundedNumber(value, 0, 1) then
            return false, "Effect strength must be a finite number from 0 to 1."
        end
        self.EffectStrength = value
        return true
    end

    function app:SetOpacity(value)
        if not boundedNumber(value, 0.7, 1) then
            return false, "Opacity must be a finite number from 0.7 to 1."
        end
        self.Opacity = value
        return true
    end

    function app:HasAudioAdapter()
        return audioAdapter ~= nil
    end

    function app:_DestroyAudio()
        if audioBusy then
            -- A provider can trigger the application's teardown from its callback.
            pendingAudioCleanup = true
            return true
        end
        local previous = audioAdapter
        audioAdapter = nil
        self.Audio.available = false
        self.Audio.playing = false
        self.AudioStatus = "No audio adapter connected."
        if not previous then
            return true
        end
        local paused = callAdapter(previous, "pause", 0.15)
        local disposed = true
        if type(previous.destroy) == "function" then
            disposed = callAdapter(previous, "destroy")
        end
        if not paused or not disposed then
            self.AudioStatus = "Audio adapter cleanup failed."
            return false, self.AudioStatus
        end
        return true
    end

    function app:SetAudioAdapter(adapter)
        if self.Alive == false and adapter ~= nil then
            return false, "The interface has been destroyed."
        end
        if audioBusy then
            return false, "An audio operation is already in progress."
        end
        if adapter == audioAdapter then
            return true
        end
        if adapter ~= nil then
            if type(adapter) ~= "table" then
                return false, "Audio adapter must be a table or nil."
            end
            for _, method in ipairs({ "play", "pause", "setVolume" }) do
                if type(adapter[method]) ~= "function" then
                    return false, "Audio adapter requires a " .. method .. " method."
                end
            end
            if adapter.destroy ~= nil and type(adapter.destroy) ~= "function" then
                return false, "Audio adapter destroy must be a function when supplied."
            end
        end
        local cleaned, cleanupError = self:_DestroyAudio()
        if not cleaned then
            return false, cleanupError
        end
        if adapter == nil then
            return true
        end
        -- Attach muted/paused; starting playback always requires an explicit call.
        -- Register first so teardown inside an initialization callback can dispose it.
        audioAdapter = adapter
        local paused = callAdapter(adapter, "pause", 0)
        if self.Alive == false or audioAdapter ~= adapter then
            return false, "Audio initialization was interrupted by cleanup."
        end
        if not paused then
            self:_DestroyAudio()
            self.AudioStatus = "Audio adapter could not initialize."
            return false, self.AudioStatus
        end
        for _, channel in ipairs(volumeOrder) do
            local ok = callAdapter(adapter, "setVolume", channel, volumes[channel], 0)
            if self.Alive == false or audioAdapter ~= adapter then
                return false, "Audio initialization was interrupted by cleanup."
            end
            if not ok then
                self:_DestroyAudio()
                self.AudioStatus = "Audio adapter could not initialize volumes."
                return false, self.AudioStatus
            end
        end
        self.Audio.available = true
        self.AudioStatus = "Audio ready."
        return true
    end

    function app:PlayAudio()
        if self.Alive == false then
            return false, "The interface has been destroyed."
        end
        if not audioAdapter then
            self.AudioStatus = "No audio adapter connected."
            return false, self.AudioStatus
        end
        local current = audioAdapter
        local ok, message = callAdapter(current, "play", 0.25)
        if self.Alive == false or audioAdapter ~= current then
            return false, "Audio playback was interrupted by cleanup."
        end
        if ok then
            self.Audio.playing = true
            self.AudioStatus = "Audio playing."
        else
            self.AudioStatus = message
        end
        return ok, self.AudioStatus
    end

    function app:PauseAudio()
        if self.Alive == false then
            return false, "The interface has been destroyed."
        end
        if not audioAdapter then
            self.AudioStatus = "No audio adapter connected."
            return false, self.AudioStatus
        end
        local current = audioAdapter
        local ok, message = callAdapter(current, "pause", 0.2)
        if self.Alive == false or audioAdapter ~= current then
            return false, "Audio playback was interrupted by cleanup."
        end
        if ok then
            self.Audio.playing = false
            self.AudioStatus = "Audio paused."
        else
            self.AudioStatus = message
        end
        return ok, self.AudioStatus
    end

    function app:SetVolume(channel, value)
        if self.Alive == false then
            return false, "The interface has been destroyed."
        end
        if audioBusy then
            return false, "An audio operation is already in progress."
        end
        if type(channel) ~= "string" or volumes[channel] == nil then
            return false, "Volume channel must be master, music, or sfx."
        end
        if not boundedNumber(value, 0, 1) then
            return false, "Volume must be a finite number from 0 to 1."
        end
        if audioAdapter then
            local current = audioAdapter
            local ok, message = callAdapter(current, "setVolume", channel, value, 0.15)
            if self.Alive == false or audioAdapter ~= current then
                return false, "Audio volume update was interrupted by cleanup."
            end
            if not ok then
                self.AudioStatus = message
                return false, message
            end
        end
        volumes[channel] = value
        return true
    end

    local function safeName(value)
        return type(value) == "string" and #value > 0 and #value <= 48 and value:match("^[%w _%-]+$") ~= nil
    end

    local function validKeybind(value)
        return boundedNumber(value, 8, 254) and value == math.floor(value) and value ~= 27
    end

    local settings = {
        { key = "riasArtwork", field = "RiasArtwork", method = "SetRiasArtwork", validate = safeName },
        { key = "akenoArtwork", field = "AkenoArtwork", method = "SetAkenoArtwork", validate = safeName },
        { key = "riasCompanion", field = "RiasCompanion", method = "SetRiasCompanion", kind = "boolean" },
        { key = "akenoCompanion", field = "AkenoCompanion", method = "SetAkenoCompanion", kind = "boolean" },
        {
            key = "companionOrder",
            field = "CompanionOrder",
            method = "SetCompanionOrder",
            validate = safeName,
        },
        { key = "animatedMedia", field = "AnimatedMedia", method = "SetAnimatedMedia", kind = "boolean" },
        -- Character selection applies its house theme; restore the user's theme after it.
        { key = "character", field = "Character", method = "SetCharacter", validate = safeName },
        { key = "theme", field = "Theme", method = "SetTheme", validate = safeName },
        {
            key = "quality",
            field = "Quality",
            method = "SetQuality",
            validate = function(value)
                return qualityNames[value] == true
            end,
        },
        { key = "reducedMotion", field = "ReducedMotion", method = "SetReducedMotion", kind = "boolean" },
        { key = "effects", field = "Effects", method = "SetEffects", kind = "boolean" },
        {
            key = "effectStrength",
            field = "EffectStrength",
            method = "SetEffectStrength",
            kind = "number",
            validate = function(value)
                return boundedNumber(value, 0, 1)
            end,
        },
        {
            key = "keybind",
            field = "Keybind",
            method = "SetKeybind",
            kind = "number",
            validate = validKeybind,
        },
        {
            key = "opacity",
            field = "Opacity",
            method = "SetOpacity",
            kind = "number",
            validate = function(value)
                return boundedNumber(value, 0.7, 1)
            end,
        },
    }
    local allowedKeys = { version = true, masterVolume = true, musicVolume = true, sfxVolume = true }
    for _, setting in ipairs(settings) do
        allowedKeys[setting.key] = true
    end

    local function convertValue(setting, value)
        if setting.kind == "boolean" then
            if value == "true" then
                return true, true
            elseif value == "false" then
                return true, false
            end
            return false
        elseif setting.kind == "number" then
            value = tonumber(value)
        end
        if setting.validate and not setting.validate(value) then
            return false
        end
        return true, value
    end

    function app:SaveSettings()
        if type(env.writefile) ~= "function" then
            return settingsResult(
                false,
                "This host cannot save files. Settings remain active for this session."
            )
        end
        local lines = { "version=1" }
        for _, setting in ipairs(settings) do
            local value = self[setting.field]
            local valid = convertValue(setting, tostring(value))
            if not valid then
                return settingsResult(
                    false,
                    "Could not save invalid " .. setting.key .. ". Use the settings API to update it."
                )
            end
            lines[#lines + 1] = setting.key .. "=" .. tostring(value)
        end
        for _, channel in ipairs(volumeOrder) do
            if not boundedNumber(volumes[channel], 0, 1) then
                return settingsResult(false, "Could not save invalid " .. channel .. " volume.")
            end
            lines[#lines + 1] = channel .. "Volume=" .. tostring(volumes[channel])
        end
        local ok, result = pcall(env.writefile, CONFIG_FILE, table.concat(lines, "\n") .. "\n")
        if not ok or result == false then
            return settingsResult(false, "Settings could not be written. Check your host's file permissions.")
        end
        return settingsResult(true, "Settings saved to " .. CONFIG_FILE .. ".")
    end

    function app:LoadSettings()
        if type(env.readfile) ~= "function" then
            return settingsResult(
                false,
                "This host cannot read settings files. Session settings are available."
            )
        end
        local ok, content = pcall(env.readfile, CONFIG_FILE)
        if not ok or type(content) ~= "string" then
            return settingsResult(false, "No readable saved settings found. Current settings are active.")
        end
        if #content > MAX_CONFIG_BYTES then
            return settingsResult(false, "Saved settings exceed the 8 KB limit. Current settings are active.")
        end
        local entries, duplicates = {}, {}
        local ignored, lineCount = 0, 0
        for line in (content .. "\n"):gmatch("([^\n]*)\n") do
            lineCount = lineCount + 1
            if lineCount > MAX_CONFIG_LINES then
                return settingsResult(
                    false,
                    "Saved settings contain too many lines. Current settings are active."
                )
            end
            line = line:gsub("\r$", "")
            if line:match("%S") and not line:match("^%s*#") then
                local key, value = line:match("^%s*([%a][%w]*)%s*=%s*(.-)%s*$")
                if not key or not allowedKeys[key] or #value > 64 then
                    ignored = ignored + 1
                elseif entries[key] ~= nil then
                    duplicates[key] = true
                    ignored = ignored + 1
                else
                    entries[key] = value
                end
            end
        end
        if entries.version ~= "1" or duplicates.version then
            return settingsResult(
                false,
                "Saved settings have an unsupported or missing version. Current settings are active."
            )
        end
        local applied = 0
        for _, setting in ipairs(settings) do
            local raw = entries[setting.key]
            if raw ~= nil and not duplicates[setting.key] then
                local valid, value = convertValue(setting, raw)
                local called, result = false, false
                if valid then
                    called, result = pcall(self[setting.method], self, value)
                end
                if called and result ~= false then
                    applied = applied + 1
                else
                    ignored = ignored + 1
                end
            end
        end
        for _, channel in ipairs(volumeOrder) do
            local key = channel .. "Volume"
            if entries[key] ~= nil and not duplicates[key] then
                local value = tonumber(entries[key])
                if boundedNumber(value, 0, 1) and self:SetVolume(channel, value) then
                    applied = applied + 1
                else
                    ignored = ignored + 1
                end
            end
        end
        local message = "Loaded " .. applied .. " saved settings."
        if ignored > 0 then
            message = message .. " Skipped " .. ignored .. " invalid or unknown entries."
        end
        return settingsResult(true, message)
    end

    function app:ResetSettings()
        local failed = 0
        for _, setting in ipairs(settings) do
            local ok, result = pcall(self[setting.method], self, defaults[setting.field])
            if not ok or result == false then
                failed = failed + 1
            end
        end
        local volumeDefaults = { master = 0.6, music = 0.55, sfx = 0.5 }
        for _, channel in ipairs(volumeOrder) do
            if not self:SetVolume(channel, volumeDefaults[channel]) then
                failed = failed + 1
            end
        end
        if failed > 0 then
            return settingsResult(
                false,
                "Some settings could not reset. Check the audio adapter before saving."
            )
        end
        return settingsResult(true, "Defaults restored for this session. Choose Save to keep them.")
    end
end
