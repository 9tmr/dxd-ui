-- Run dxd.lua first in the same Matcha environment.
local UI = DxD
assert(UI and UI.Alive, "Run dxd.lua first")

local Main = UI:AddTab({
    Title = "My workspace",
    Icon = "script",
    Subtitle = "A working example of the reusable control API.",
})

Main:AddToggle({
    Title = "Ambient effects",
    Description = "Control the interface's own ambient effects.",
    Default = UI.Effects,
    Callback = function(enabled)
        UI:SetEffects(enabled)
    end,
})

Main:AddSlider({
    Title = "Panel opacity",
    Description = "Adjust the interface from 70 to 100 percent.",
    Min = 70,
    Max = 100,
    Step = 1,
    Default = UI.Opacity * 100,
    Callback = function(percent)
        UI:SetOpacity(percent / 100)
    end,
})

Main:AddDropdown({
    Title = "Character",
    Description = "Switch your companion and signature palette.",
    Options = { "Rias", "Akeno" },
    Default = UI.Character == "rias" and "Rias" or "Akeno",
    Callback = function(name)
        UI:SetCharacter(name == "Rias" and "rias" or "akeno")
    end,
})

Main:AddButton({
    Title = "Save preferences",
    Description = "Save the interface's current settings to this device.",
    ButtonText = "Save",
    Callback = function()
        local ok, message = UI:SaveSettings()
        UI:Notify({
            Title = ok and "Saved" or "Could not save",
            Content = message,
            Type = ok and "success" or "error",
        })
    end,
})

Main:AddLabel({
    Title = "Ready for your own callbacks",
    Description = "Extra controls paginate automatically. Values survive tab changes.",
})

Main:Select()
