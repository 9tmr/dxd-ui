home = app:AddTab({
    Title = "Clubroom",
    Icon = "home",
    Subtitle = "A place to belong. A world beyond the ordinary.",
})
app.Home = home
members = app:AddTab({
    Title = "Members",
    Icon = "members",
    Subtitle = "Two personalities. One extraordinary club.",
})
app.Members = members
controls = app:AddTab({
    Title = "Atmosphere",
    Icon = "sliders",
    Subtitle = "Set the mood for your own corner of Kuoh.",
})
app.Controls = controls
settings = app:AddTab({ Title = "Settings", Icon = "gear", Subtitle = "Fine-tune your experience." })
app.Settings = settings
local bindings = {}
local function bind(control, field, multiplier)
    bindings[#bindings + 1] = { control = control, field = field, multiplier = multiplier or 1 }
    return control
end
bind(
    controls:AddToggle({
        Title = "Ambient effects",
        Description = "Quiet embers and summoning-circle accents.",
        Default = true,
        Callback = function(v)
            app:SetEffects(v)
        end,
    }),
    "Effects"
)
bind(
    controls:AddSlider({
        Title = "Effect intensity",
        Description = "A subtle glow or a little more magic.",
        Min = 0,
        Max = 100,
        Default = 65,
        Step = 5,
        Callback = function(v)
            app:SetEffectStrength(v / 100)
        end,
    }),
    "EffectStrength",
    100
)
bind(
    controls:AddSlider({
        Title = "Panel opacity",
        Description = "Keep your clubroom comfortably readable.",
        Min = 70,
        Max = 100,
        Default = 97,
        Step = 1,
        Callback = function(v)
            app:SetOpacity(v / 100)
        end,
    }),
    "Opacity",
    100
)
controls:AddButton({
    Title = "Summoning pulse",
    Description = "Give your companion a moment in the spotlight.",
    ButtonText = "Summon",
    Callback = function()
        reactUntil = motionClock + 1.5
        home:Select()
        app:Notify({ Title = currentCharacter().Name, Content = "The clubroom is yours.", Type = "success" })
    end,
})
bind(
    settings:AddDropdown({
        Title = "Signature palette",
        Description = "An identity for every kind of evening.",
        Options = { "Gremory", "Himejima", "Twilight", "Obsidian" },
        Default = "Gremory",
        Callback = function(v)
            app:SetTheme(v)
        end,
    }),
    "Theme"
)
bind(
    settings:AddDropdown({
        Title = "Graphics quality",
        Description = "Low: still artwork. High: richer ambient detail.",
        Options = { "Low", "Balanced", "High" },
        Default = "Balanced",
        Callback = function(v)
            app:SetQuality(v)
        end,
    }),
    "Quality"
)
bind(
    settings:AddToggle({
        Title = "Reduced motion",
        Description = "Stop ambient movement and instant transitions.",
        Default = false,
        Callback = function(v)
            app:SetReducedMotion(v)
        end,
    }),
    "ReducedMotion"
)
settings:_add("keybind", { Title = "Menu keybind", Description = "Record a key. Escape cancels." })
settings:AddButton({
    Title = "Save preferences",
    Description = "Save this look on this device.",
    ButtonText = "Save",
    Callback = function()
        local ok, message = app:SaveSettings()
        app:Notify({
            Title = ok and "Preferences saved" or "Could not save",
            Content = message,
            Type = ok and "success" or "error",
        })
    end,
})
settings:AddButton({
    Title = "Restore saved preferences",
    Description = "Load the last settings you saved.",
    ButtonText = "Restore",
    Callback = function()
        local ok, message = app:LoadSettings()
        app:Notify({
            Title = ok and "Preferences restored" or "Could not restore",
            Content = message,
            Type = ok and "success" or "error",
        })
    end,
})
settings:AddButton({
    Title = "Reset appearance",
    Description = "Return to the original crimson edition.",
    ButtonText = "Reset",
    Callback = function()
        app:Confirm({
            Title = "Reset appearance?",
            Content = "Restore the default look. Your saved file stays as it is.",
            Callback = function()
                app:ResetSettings()
                app:Notify({
                    Title = "Appearance reset",
                    Content = "Welcome back to crimson.",
                    Type = "success",
                })
            end,
        })
    end,
})
settings:AddButton({
    Title = "Test notification",
    Description = "Check the notification style and placement.",
    ButtonText = "Preview",
    Callback = function()
        app:Notify({
            Title = "Everything is ready",
            Content = "A little magic, delivered quietly.",
            Type = "success",
        })
    end,
})
settings:AddLabel({
    Title = "Keyboard navigation",
    Description = "Tab: focus. Enter/Space: activate. Arrows: adjust. Esc: back.",
    Icon = "key",
})
settings:AddLabel({
    Title = "Local by design",
    Description = "No account, telemetry, or background downloads.",
    Icon = "info",
})
settings:AddButton({
    Title = "Unload interface",
    Description = "Remove the drawings and disconnect the renderer.",
    ButtonText = "Unload",
    Callback = function()
        app:Confirm({
            Title = "Leave the clubroom?",
            Content = "The interface will unload. Run your loader to return.",
            Callback = function()
                app:Destroy()
            end,
        })
    end,
})
local gallery = app:AddTab({
    Title = "Artwork",
    Icon = "layers",
    Subtitle = "Your anime media. Your two pixel companions.",
})
app.Gallery = gallery
for _, spec in ipairs({
    { Title = "Pixel Rias", Field = "RiasCompanion", Method = "SetRiasCompanion" },
    { Title = "Pixel Akeno", Field = "AkenoCompanion", Method = "SetAkenoCompanion" },
}) do
    bind(
        gallery:AddToggle({
            Title = spec.Title,
            Description = "Show this companion on the window. Click to react.",
            Default = true,
            Callback = function(v)
                app[spec.Method](app, v)
            end,
        }),
        spec.Field
    )
end
bind(
    gallery:AddDropdown({
        Title = "Companion positions",
        Description = "Swap their places. Either companion can be disabled.",
        Options = { "Rias first", "Akeno first" },
        Default = "Rias first",
        Callback = function(v)
            app:SetCompanionOrder(v)
        end,
    }),
    "CompanionOrder"
)
bind(
    gallery:AddToggle({
        Title = "Animated pictures",
        Description = "Play anime loops. Low quality and reduced motion pause them.",
        Default = true,
        Callback = function(v)
            app:SetAnimatedMedia(v)
        end,
    }),
    "AnimatedMedia"
)
for _, character in ipairs({ "rias", "akeno" }) do
    local field = character == "rias" and "RiasArtwork" or "AkenoArtwork"
    bind(
        gallery:AddDropdown({
            Title = character == "rias" and "Rias picture" or "Akeno picture",
            Description = "Choose a clip or still. Opening/closing are frames of the same clip.",
            Options = app:GetArtworkOptions(character),
            Default = app[field],
            Callback = function(v)
                app:SetArtwork(character, v)
            end,
        }),
        field
    )
end
bind(
    gallery:AddDropdown({
        Title = "Artwork palette",
        Description = "Change the UI colors independently of the selected picture.",
        Options = { "Gremory", "Himejima", "Twilight", "Obsidian" },
        Default = "Gremory",
        Callback = function(v)
            app:SetTheme(v)
        end,
    }),
    "Theme"
)
gallery:AddButton({
    Title = "Preview selection",
    Description = "Open the clubroom with your selected member and artwork.",
    ButtonText = "Preview",
    Callback = function()
        home:Select()
    end,
})
function app:_SyncSettings()
    for _, b in ipairs(bindings) do
        local value = self[b.field]
        if type(value) == "number" then
            value = value * b.multiplier
        end
        b.control.Value = value
    end
end
