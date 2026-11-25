local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local UI = genv.GDH_UI
if typeof(UI) ~= "table" then
    return
end

local Theme = UI.Theme
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local runtime: any = nil
local wrappersReady = false
local originalAudioPitch: any = nil

local speed = { value = 1, enabled = false }
local speedAudio = { enabled = false }
local characterSpeed = {
    humanoid = nil,
    walkSpeed = nil,
}

local Save = nil
local SaveImport = genv.Import
if typeof(SaveImport) == "function" then
    pcall(function()
        Save = SaveImport("Function/Save")
    end)
end
if Save == nil then
    Save = genv.GDH_Save
end

local function S(n: number): number
    return math.floor(n * (Theme.ScreenScale or 1) + 0.5)
end

local function getRuntime(): any
    if runtime ~= nil then
        return runtime
    end
    local ok, moduleValue = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local node = port and port:FindFirstChild("ClientRuntime")
        return node and require(node) or nil
    end)
    if ok and typeof(moduleValue) == "table" then
        runtime = moduleValue
    end
    return runtime
end

local function isPlaying(): boolean
    local rt = getRuntime()
    local layer = rt ~= nil and rt.layer or nil
    return typeof(layer) == "table" and typeof(layer.state) == "table"
end

local function getHumanoid(): Humanoid?
    local character = Players.LocalPlayer and Players.LocalPlayer.Character
    if typeof(character) ~= "Instance" then
        return nil
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if typeof(humanoid) == "Instance" then
        return humanoid :: Humanoid
    end
    return nil
end

local function captureCharacterSpeed(humanoid: Humanoid)
    if characterSpeed.humanoid == humanoid then
        return
    end
    characterSpeed.humanoid = humanoid
    characterSpeed.walkSpeed = humanoid.WalkSpeed
end

local function restoreCharacterSpeed()
    local humanoid = characterSpeed.humanoid
    if typeof(humanoid) == "Instance" and humanoid.Parent ~= nil then
        pcall(function()
            humanoid.WalkSpeed = characterSpeed.walkSpeed
        end)
    end
    characterSpeed.humanoid = nil
    characterSpeed.walkSpeed = nil
end

local function applyCharacterSpeed()
    local humanoid = getHumanoid()
    if humanoid == nil then
        return
    end
    captureCharacterSpeed(humanoid)
    local multiplier = math.max(0.001, tonumber(speed.value) or 1)
    pcall(function()
        humanoid.WalkSpeed = characterSpeed.walkSpeed * multiplier
    end)
end

local function ensureWrappers(): boolean
    if wrappersReady then
        return true
    end
    local rt = getRuntime()
    if rt == nil or typeof(rt.audioPitch) ~= "function" then
        return false
    end
    originalAudioPitch = rt.audioPitch
    rt.audioPitch = function(...: any)
        if speed.enabled and isPlaying() then
            if speedAudio.enabled then
                return speed.value
            end
            return 1
        end
        return originalAudioPitch(...)
    end
    wrappersReady = true
    return true
end

local function setRuntimeTimeSpeed(target: number): ()
    if not ensureWrappers() then
        return
    end
    target = tonumber(target) or 1
    if target <= 0 then
        target = 0.001
    end
    local layer = typeof(runtime.layer) == "table" and runtime.layer or nil
    if runtime.timeSpeed == target
        and (target == 1 or (layer ~= nil and layer.usedSpeedChange == true))
    then
        return
    end
    pcall(function()
        runtime.timeSpeed = target
    end)
    if layer ~= nil then
        pcall(function()
            layer.usedSpeedChange = target ~= 1
        end)
    end
    pcall(function()
        local view = runtime.timeSpeedView
        if typeof(view) == "table" and typeof(view.refresh) == "function"
            and typeof(view.root) == "Instance" and view.root.Parent ~= nil
        then
            view.refresh()
        end
    end)
    pcall(function()
        if typeof(runtime.testModeLabel) == "function" then
            runtime.testModeLabel()
        end
    end)
end

local function resetGameSpeed(): ()
    setRuntimeTimeSpeed(1)
end

local function applyGameSpeed(): ()
    if not speed.enabled or not isPlaying() then
        resetGameSpeed()
        return
    end
    setRuntimeTimeSpeed(speed.value)
end

local function isTypingForShortcuts(): boolean
    local keyboard = genv.GDH_Keyboard
    if typeof(keyboard) == "table" and typeof(keyboard.IsTyping) == "function" then
        local ok, result = pcall(keyboard.IsTyping)
        if ok then
            return result == true
        end
    end
    return game:GetService("UserInputService"):GetFocusedTextBox() ~= nil
end

local framerateWindow = UI:CreateWindow({
    Title = "Framerate",
    Order = 9997,
    AutoHeight = true,
    Searchable = false,
    Keybindable = false,
    Size = UDim2.fromOffset(S(202), S(305)),
})

local fps = { value = 240, enabled = false, baseline = nil }
local tps = { value = 240, enabled = false }
local lockDelta = { value = 240, enabled = false }
local pitch = { value = 0, enabled = false }
local syncTpsWithLock = true
if Save ~= nil then
    local savedSync = Save.ToggleState("Framerate::Sync TPS with Lock DT", "Global")
    if savedSync ~= nil then
        syncTpsWithLock = savedSync
    end
end

local PITCH_EFFECT_NAME = "GDHPitchShift"

local tpsSlider: Frame? = nil
local lockSlider: Frame? = nil

local function setFpsCap(cap: number): boolean
    if type(setfpscap) == "function" then
        local ok = pcall(setfpscap :: any, cap)
        if ok then
            return true
        end
    end
    if type(setfps) == "function" then
        local ok = pcall(setfps :: any, cap)
        if ok then
            return true
        end
    end
    return false
end

local function getFpsCap(): number?
    if type(getfpscap) == "function" then
        local ok, value = pcall(function()
            return (getfpscap :: any)()
        end)
        if ok and type(value) == "number" then
            return value
        end
    end
    return nil
end

local function refreshSpeedAudio(): ()
    applyGameSpeed()
end

local function applyPitchToSound(sound: Sound)
    local existing = sound:FindFirstChild(PITCH_EFFECT_NAME)
    if pitch.enabled and pitch.value ~= 0 then
        local octave = 2 ^ (pitch.value / 12)
        octave = math.clamp(octave, 0.5, 2)
        if existing == nil then
            local effect = Instance.new("PitchShiftSoundEffect")
            effect.Name = PITCH_EFFECT_NAME
            effect.Octave = octave
            effect.Parent = sound
        elseif existing:IsA("PitchShiftSoundEffect") then
            existing.Octave = octave
        end
    elseif existing ~= nil then
        existing:Destroy()
    end
end

local function refreshPitch()
    for _, descendant in game:GetDescendants() do
        if descendant:IsA("Sound") then
            applyPitchToSound(descendant)
        end
    end
end

local function applySpeed(): ()
    if not speed.enabled then
        resetGameSpeed()
        restoreCharacterSpeed()
        return
    end
    if getRuntime() == nil then
        resetGameSpeed()
        applyCharacterSpeed()
        return
    end
    restoreCharacterSpeed()
    applyGameSpeed()
end

local speedWatchTimer = 0
local speedWatchConn = RunService.Heartbeat:Connect(function(dt: number)
    speedWatchTimer += dt
    if speedWatchTimer < 0.2 then
        return
    end
    speedWatchTimer = 0
    if not speed.enabled then
        resetGameSpeed()
        restoreCharacterSpeed()
        return
    end
    if getRuntime() == nil then
        resetGameSpeed()
        applyCharacterSpeed()
        return
    end
    restoreCharacterSpeed()
    if isPlaying() then
        if ensureWrappers() and math.abs(runtime.timeSpeed - speed.value) > 0.001 then
            applyGameSpeed()
        end
    else
        resetGameSpeed()
    end
end)

local respawnConn = Players.LocalPlayer.CharacterAdded:Connect(function()
    if speed.enabled then
        task.defer(applySpeed)
    end
end)

local soundWatchConn = game.DescendantAdded:Connect(function(descendant)
    if not descendant:IsA("Sound") then
        return
    end
    task.defer(function()
        if typeof(descendant) ~= "Instance" then
            return
        end
        if pitch.enabled then
            applyPitchToSound(descendant :: Sound)
        end
    end)
end)

local function sliderLabelOf(sliderRow: Frame?): TextLabel?
    if sliderRow == nil then
        return nil
    end
    local pill = sliderRow:FindFirstChild("Pill")
    if pill == nil then
        return nil
    end
    local label = pill:FindFirstChild("Value")
    if label and label:IsA("TextLabel") then
        return label :: TextLabel
    end
    return nil
end

local function setSliderText(sliderRow: Frame?, text: string)
    local label = sliderLabelOf(sliderRow)
    if label ~= nil then
        label.Text = text
    end
end

framerateWindow:AddSlider({
    Suffix = " FPS",
    Min = 1,
    Max = math.huge,
    Increment = 1,
    Precision = 2,
    Default = 240,
    Toggle = true,
    ToggleDefault = true,
    ToggleCallback = function(enabled: boolean)
        fps.enabled = enabled
        if enabled then
            if fps.baseline == nil then
                fps.baseline = getFpsCap()
            end
            local applied = setFpsCap(fps.value)
            if not applied then
                UI:Notify("FPS cap not supported here", 4)
            end
        else
            local restore = if fps.baseline ~= nil then fps.baseline else 0
            setFpsCap(restore)
        end
    end,
    Callback = function(value: number)
        fps.value = value
        if fps.enabled then
            setFpsCap(value)
        end
    end,
})

local lastTpsWarn = 0
tpsSlider = framerateWindow:AddSlider({
    Suffix = " TPS",
    Min = 1,
    Max = math.huge,
    Increment = 1,
    Precision = 2,
    Default = 240,
    Toggle = true,
    ToggleDefault = false,
    ToggleCallback = function(enabled: boolean)
        tps.enabled = enabled
        if enabled then
            UI:Notify("TPS row is presentational here", 3)
        end
    end,
    Callback = function(value: number)
        tps.value = value
        if value < 240 then
            local now = os.clock()
            if now - lastTpsWarn > 2 then
                lastTpsWarn = now
                UI:Notify("Warning: TPS below 240 breaks physics!", 5)
            end
        end
        if syncTpsWithLock then
            lockDelta.value = value
            setSliderText(lockSlider, string.format("LockDT: %.2f FPS", lockDelta.value))
            if Save ~= nil then
                Save.SetSlider("Framerate::LockDT", value, "Global")
            end
        end
    end,
})

framerateWindow:AddSeparator()

lockSlider = framerateWindow:AddSlider({
    Name = "LockDT",
    Suffix = " FPS",
    Min = 1,
    Max = math.huge,
    Increment = 1,
    Precision = 2,
    Default = 240,
    Callback = function(value: number)
        lockDelta.value = value
        if syncTpsWithLock then
            tps.value = value
            setSliderText(tpsSlider, string.format("%.2f TPS", tps.value))
            if Save ~= nil then
                Save.SetSlider("Framerate::Slider2", value, "Global")
            end
        end
    end,
})

framerateWindow:AddToggle({
    Name = "Lock Delta Enabled",
    Default = false,
    Callback = function(state)
        lockDelta.enabled = state
    end,
})

framerateWindow:AddSeparator()

local audioScanClock = 0
local speedSlider: Frame? = framerateWindow:AddSlider({
    Name = "Speed",
    Suffix = "x",
    Min = 0,
    Max = 500,
    Increment = 0.01,
    Precision = 2,
    Default = 1,
    Toggle = true,
    ToggleDefault = false,
    ToggleCallback = function(enabled: boolean)
        speed.enabled = enabled
        applySpeed()
    end,
    Callback = function(value: number)
        speed.value = value
        if speed.enabled then
            applyGameSpeed()
            local now = os.clock()
            if now - audioScanClock > 0.25 then
                audioScanClock = now
                refreshSpeedAudio()
            end
        end
    end,
})

do
    local actions = genv.GDH_KeybindActions
    if typeof(actions) ~= "table" then
        actions = {}
        genv.GDH_KeybindActions = actions
    end

    local function switchApi(): any
        local row = speedSlider :: Frame?
        if row == nil then
            return nil
        end
        local switch = (row :: Frame):FindFirstChild("Switch")
        if switch == nil then
            return nil
        end
        local apis = genv.GDH_ToggleRowApis
        if typeof(apis) ~= "table" then
            return nil
        end
        return apis[switch]
    end

    local function refreshSpeedLabel()
        if speedSlider ~= nil then
            setSliderText(speedSlider :: Frame, string.format("Speed: %.2fx", speed.value))
        end
    end

    local function adjustSpeedBy(delta: number): boolean
        local nextValue = math.clamp(speed.value + delta, 0, 500)
        if nextValue == speed.value then
            return false
        end
        speed.value = nextValue
        if speed.enabled then
            applyGameSpeed()
        end
        refreshSpeedLabel()
        return true
    end

    table.insert(actions, {
        Id = "Framerate::Speedhack",
        Module = "Framerate",
        Name = "Speedhack",
        Default = nil,
        Callback = function()
            local api = switchApi()
            if api ~= nil then
                api.SetState(not api.GetState())
            end
        end,
    })
    table.insert(actions, {
        Id = "Framerate::Speedhack +0.05x",
        Module = "Framerate",
        Name = "Speedhack +0.05x",
        Default = nil,
        Callback = function()
            if adjustSpeedBy(0.05) then
                UI:Notify(string.format("Speedhack: %.2fx", speed.value))
            end
        end,
    })
    table.insert(actions, {
        Id = "Framerate::Speedhack -0.05x",
        Module = "Framerate",
        Name = "Speedhack -0.05x",
        Default = nil,
        Callback = function()
            if adjustSpeedBy(-0.05) then
                UI:Notify(string.format("Speedhack: %.2fx", speed.value))
            end
        end,
    })

    local UserInputService = game:GetService("UserInputService")
    local speedShortcutConn = UserInputService.InputBegan:Connect(function(input)
        if isTypingForShortcuts() then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end
        if input.KeyCode == Enum.KeyCode.Plus or input.KeyCode == Enum.KeyCode.KeypadPlus then
            if adjustSpeedBy(0.05) then
                UI:Notify(string.format("Speed: %.2fx (+0.05x)", speed.value))
            end
        elseif input.KeyCode == Enum.KeyCode.Minus or input.KeyCode == Enum.KeyCode.KeypadMinus then
            if adjustSpeedBy(-0.05) then
                UI:Notify(string.format("Speed: %.2fx (-0.05x)", speed.value))
            end
        end
    end)
end

local pitchScanClock = 0
framerateWindow:AddSlider({
    Name = "Pitch",
    Suffix = " ST",
    Min = -24,
    Max = 24,
    Increment = 1,
    Precision = 0,
    Default = 0,
    Toggle = true,
    ToggleDefault = false,
    ToggleCallback = function(enabled: boolean)
        pitch.enabled = enabled
        refreshPitch()
    end,
    Callback = function(value: number)
        pitch.value = value
        local now = os.clock()
        if now - pitchScanClock > 0.1 then
            pitchScanClock = now
            refreshPitch()
        end
    end,
})

framerateWindow:AddToggle({
    Name = "Speedhack Audio",
    Default = false,
    Callback = function(state)
        speedAudio.enabled = state
        refreshSpeedAudio()
    end,
})

framerateWindow:AddSeparator()

framerateWindow:AddToggle({
    Name = "Vertical Sync",
    Default = false,
    Callback = function(_state)
    end,
})

framerateWindow:AddToggle({
    Name = "Real Time (Lock Delta)",
    Default = true,
    Callback = function(_state)
    end,
})

framerateWindow:AddToggle({
    Name = "Sync TPS with Lock DT",
    Default = true,
    Callback = function(state)
        syncTpsWithLock = state
        if state then
            lockDelta.value = tps.value
            setSliderText(lockSlider, string.format("LockDT: %.2f FPS", lockDelta.value))
            if Save ~= nil then
                Save.SetSlider("Framerate::LockDT", tps.value, "Global")
            end
        end
    end,
})

fps.enabled = true
if fps.baseline == nil then
    fps.baseline = getFpsCap()
end
task.defer(function()
    if fps.enabled then
        setFpsCap(fps.value)
    end
end)
