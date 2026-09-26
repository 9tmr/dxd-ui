-- Read only our own non-executable preference file. Loading never starts audio.
app:LoadSettings()
-- Preflight allocation before taking ownership of a running DxD instance.
local ok, probe = pcall(Drawing.new, "Square")
assert(ok and probe, "DxD: Drawing allocation failed; the previous UI was left intact")
probe:Remove()
local previous = env.DxD
if previous and previous.Alive and type(previous.Destroy) == "function" then
    previous:Destroy()
end
env.DxD = app
-- A live unrelated REM instance keeps its global; use the returned app or DxD.
if not env.Rem or env.Rem == previous then
    env.Rem = app
end
local elapsed = 0
connection = run.RenderStepped:Connect(function(delta)
    if not app.Alive then
        return
    end
    -- Poll input every host frame. Painting is capped independently so brief key taps survive.
    local inputOK, inputError = pcall(input)
    if not inputOK then
        app.LastError = tostring(inputError)
        if type(warn) == "function" then
            warn("DxD input stopped safely: " .. tostring(inputError))
        end
        app:Destroy()
        return
    end
    if not app.Alive then
        return
    end
    elapsed = elapsed + (finite(delta) and delta or 1 / 60)
    local fps = (not app.Visible or not active) and 15
        or (app.Quality == "Low" or app.ReducedMotion) and 30
        or 60
    if elapsed < 1 / fps and not click then
        return
    end
    elapsed = 0
    local success, err = pcall(render)
    if not success then
        app.LastError = tostring(err)
        if type(warn) == "function" then
            warn("DxD stopped safely: " .. tostring(err))
        end
        app:Destroy()
    else
        local queued = actionQueue
        actionQueue = {}
        for _, action in ipairs(queued) do
            if app.Alive then
                fire(action)
            end
        end
    end
end)
app:Notify({
    Title = "Welcome to the club",
    Content = keyName(app.Keybind) .. " toggles your interface.",
    Duration = 3,
})
return app
