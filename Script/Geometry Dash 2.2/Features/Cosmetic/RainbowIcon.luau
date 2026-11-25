local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local RainbowIcon = {}
local enabled = false
local runtime = nil
local conn = nil
local guiConn = nil
local entries = {}
local labels = {}
local phase = 0

local function getRuntime()
    if runtime then
        return runtime
    end
    local ok, mod = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local rt = port and port:FindFirstChild("ClientRuntime")
        return rt and require(rt) or nil
    end)
    if ok and type(mod) == "table" then
        runtime = mod
    end
    return runtime
end

local function getFxList()
    local rt = getRuntime()
    local presentation = rt and rt.layer and rt.layer.presentation
    local fx = presentation and presentation.fx
    if type(fx) == "table" then
        return fx
    end
    return nil
end

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function hsv(h, s, v)
    h = h % 1
    s = clamp(s, 0, 1)
    v = clamp(v, 0, 1)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    local r, g, b
    if i == 0 then
        r, g, b = v, t, p
    elseif i == 1 then
        r, g, b = q, v, p
    elseif i == 2 then
        r, g, b = p, v, t
    elseif i == 3 then
        r, g, b = p, q, v
    elseif i == 4 then
        r, g, b = t, p, v
    else
        r, g, b = v, p, q
    end
    return {
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5),
    }
end

local function toColor3(value)
    return Color3.fromRGB(
        clamp(value[1], 0, 255),
        clamp(value[2], 0, 255),
        clamp(value[3], 0, 255)
    )
end

local function copyColor(value)
    if typeof(value) == "Color3" then
        return { value.R * 255, value.G * 255, value.B * 255 }
    end
    if type(value) == "table" then
        return { value[1] or 255, value[2] or 255, value[3] or 255 }
    end
    return { 255, 255, 255 }
end

local function settings()
    local store = genv.GDH_HACK_SETTINGS_STATE
    if type(store) ~= "table" then
        return nil
    end
    local state = store["rainbow icon"]
    if type(state) ~= "table" then
        return nil
    end
    return state
end

local function numberSetting(key, default)
    local state = settings()
    local value = state and state[key]
    if type(value) == "number" then
        return value
    end
    return default
end

local function flagSetting(key, default)
    local state = settings()
    local value = state and state[key]
    if type(value) == "boolean" then
        return value
    end
    return default
end

local function readTrail(fx)
    local trail = fx.trail
    if type(trail) ~= "table" then
        return nil
    end
    return {
        trail.startR, trail.startG, trail.startB,
        trail.endR, trail.endG, trail.endB,
    }
end

local function restoreTrail(fx, saved)
    if not saved or type(fx.trail) ~= "table" then
        return
    end
    pcall(function()
        fx.trail:setStartColor(saved[1], saved[2], saved[3], 1)
        fx.trail:setEndColor(saved[4], saved[5], saved[6], 1)
    end)
end

local function paintTrail(fx, first, second)
    if type(fx.trail) ~= "table" then
        return
    end
    pcall(function()
        fx.trail:setStartColor(first[1] / 255, first[2] / 255, first[3] / 255, 1)
        fx.trail:setEndColor(second[1] / 255, second[2] / 255, second[3] / 255, 1)
    end)
end

local function waveSaved(entry, index, wave)
    local saved = entry.waveSaved[index]
    if not saved then
        saved = { r = wave.r, g = wave.g, b = wave.b }
        entry.waveSaved[index] = saved
    end
    return saved
end

local function restoreWaves(entry)
    local waves = entry.fx.waves
    if type(waves) ~= "table" or type(waves.list) ~= "table" then
        return
    end
    for index, wave in ipairs(waves.list) do
        if type(wave) == "table" then
            local saved = entry.waveSaved[index]
            if saved then
                wave.r = saved.r
                wave.g = saved.g
                wave.b = saved.b
            end
        end
    end
end

local function paintWaves(entry, first, second)
    local waves = entry.fx.waves
    if type(waves) ~= "table" or type(waves.list) ~= "table" then
        return
    end
    for index, wave in ipairs(waves.list) do
        if type(wave) == "table" then
            waveSaved(entry, index, wave)
            local color = wave.first and first or second
            wave.r = color[1] / 255
            wave.g = color[2] / 255
            wave.b = color[3] / 255
        end
    end
end

local function captureFx(fx, index)
    if type(fx) ~= "table" or type(fx.updateGlowColor) ~= "function" then
        return nil
    end
    local entry = entries[index]
    if not entry or entry.fx ~= fx then
        entries[index] = {
            fx = fx,
            first = copyColor(fx.mainColor),
            second = copyColor(fx.secondColor),
            glow = copyColor(fx.glowColor),
            trail = readTrail(fx),
            waveSaved = {},
        }
    end
    return entries[index]
end

local function findPlayerOwner(instance: Instance): Instance?
    local node = instance.Parent
    while node and node.Parent do
        if node.Name:match("^Player") and node.Parent.Name == "Players" then
            return node
        end
        node = node.Parent
    end
    return nil
end

local function layerKind(instance: Instance, owner: Instance): string
    local best = -math.huge
    local second = -math.huge
    for _, child in ipairs(owner:GetChildren()) do
        local target: Instance? = nil
        if child:IsA("ImageLabel") then
            target = child
        else
            target = child:FindFirstChildOfClass("ImageLabel", true)
        end
        if target and target:IsA("GuiObject") then
            local z = target.ZIndex
            if z > best then
                second = best
                best = z
            elseif z > second then
                second = z
            end
        end
    end
    local z = instance:IsA("GuiObject") and instance.ZIndex or -1
    if z >= best then
        return "primary"
    end
    if z >= second then
        return "secondary"
    end
    return "glow"
end

local function matches(instance: Instance): boolean
    if not instance:IsA("ImageLabel") or not instance.Parent then
        return false
    end
    local owner = findPlayerOwner(instance)
    if not owner then
        return false
    end
    local node: Instance? = instance.Parent
    while node and node ~= owner do
        node = node.Parent
    end
    if node ~= owner then
        return false
    end
    local fullName = instance:GetFullName()
    if fullName:find("GDH", 1, true) then
        return false
    end
    return fullName:find("GDWorld", 1, true) ~= nil
end

local function watch(instance)
    if labels[instance] then
        return
    end
    labels[instance] = {
        color = instance.ImageColor3,
        owner = findPlayerOwner(instance),
    }
end

local function scan(playerGui)
    for _, instance in ipairs(playerGui:GetDescendants()) do
        if matches(instance) then
            watch(instance)
        end
    end
end

local function step(dt)
    if not enabled then
        return
    end

    local speed = clamp(numberSetting("speed", 0.25), 0.1, 5)
    local saturation = clamp(numberSetting("saturation", 0.7), 0, 1)
    local value = clamp(numberSetting("value", 1), 0, 1)
    phase = (phase + clamp(dt or 1 / 60, 0, 0.1) * speed) % 1

    local first = hsv(phase, saturation, value)
    local second = hsv((phase + 0.18) % 1, saturation, value)
    local firstColor = toColor3(first)
    local secondColor = toColor3(second)

    local usePrimary = flagSetting("primary_color", true)
    local useSecondary = flagSetting("secondary_color", true)
    local useGlow = flagSetting("glow_color", true)
    local useTrail = flagSetting("regular_trail", true)
    local useWave = flagSetting("wave_trail", true)

    local fxs = getFxList()
    if type(fxs) == "table" then
        for index, fx in ipairs(fxs) do
            local entry = captureFx(fx, index)
            if entry then
                pcall(function()
                    local fxFirst = usePrimary and first or entry.first
                    local fxSecond = (useSecondary or useGlow) and second or entry.second
                    entry.fx:updateGlowColor(fxFirst, fxSecond, nil)
                    if not useGlow then
                        entry.fx.glowColor = entry.glow
                    end
                end)
                if useTrail then
                    paintTrail(entry.fx, first, second)
                else
                    restoreTrail(entry.fx, entry.trail)
                end
                if useWave then
                    paintWaves(entry, first, second)
                else
                    restoreWaves(entry)
                end
            end
        end
    end

    for label, data in pairs(labels) do
        if label.Parent == nil then
            labels[label] = nil
            continue
        end
        local owner = data.owner
        if not owner or owner.Parent == nil then
            owner = findPlayerOwner(label)
            data.owner = owner
        end
        local kind = owner and layerKind(label, owner) or "primary"
        local color = nil
        if kind == "primary" and usePrimary then
            color = firstColor
        elseif kind == "secondary" and useSecondary then
            color = secondColor
        elseif kind == "glow" and useGlow then
            color = secondColor
        end
        pcall(function()
            label.ImageColor3 = color or data.color
        end)
    end
end

local function watchGui()
    local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui or guiConn then
        return
    end
    scan(playerGui)
    guiConn = playerGui.DescendantAdded:Connect(function(instance)
        if matches(instance) then
            watch(instance)
        end
    end)
end

local function apply()
    if enabled then
        watchGui()
        if not conn then
            conn = RunService.RenderStepped:Connect(step)
        end
    else
        if conn then
            conn:Disconnect()
            conn = nil
        end
        if guiConn then
            guiConn:Disconnect()
            guiConn = nil
        end
        for label, data in pairs(labels) do
            pcall(function()
                label.ImageColor3 = data.color
            end)
        end
        table.clear(labels)
        for _, entry in pairs(entries) do
            pcall(function()
                entry.fx:updateGlowColor(entry.first, entry.second, nil)
            end)
            entry.fx.glowColor = entry.glow
            restoreTrail(entry.fx, entry.trail)
            restoreWaves(entry)
        end
        table.clear(entries)
    end
end

function RainbowIcon.Set(state)
    enabled = state == true
    apply()
end

function RainbowIcon.IsEnabled()
    return enabled
end

function RainbowIcon.Setup(window)
    window:AddToggle({
        Name = "Rainbow Icon",
        Default = false,
        Description = "Cycle the player icon colors through a rainbow",
        Callback = function(state)
            RainbowIcon.Set(state)
        end,
        Settings = {
            { Kind = "Float", Text = "Speed", Key = "speed", Min = 0.1, Max = 5, Default = 0.25 },
            { Kind = "Float", Text = "Saturation", Key = "saturation", Min = 0, Max = 1, Default = 0.7 },
            { Kind = "Float", Text = "Value", Key = "value", Min = 0, Max = 1, Default = 1 },
            { Kind = "Label", Text = "Apply To" },
            { Kind = "Toggle", Text = "Primary Color", Key = "primary_color", Default = true },
            { Kind = "Toggle", Text = "Secondary Color", Key = "secondary_color", Default = true },
            { Kind = "Toggle", Text = "Glow Color", Key = "glow_color", Default = true },
            { Kind = "Toggle", Text = "Regular Trail", Key = "regular_trail", Default = true },
            { Kind = "Toggle", Text = "Wave Trail", Key = "wave_trail", Default = true },
        },
    })
end

return RainbowIcon
