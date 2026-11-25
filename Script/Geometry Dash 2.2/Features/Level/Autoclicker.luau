local RunService = game:GetService("RunService")

local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local Autoclicker = {}
local enabled = false
local conn = nil
local pushing = false
local frames = 0
local held = {}

local function getRuntime()
    local ok, mod = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local rt = port and port:FindFirstChild("ClientRuntime")
        return rt and require(rt) or nil
    end)
    if ok and type(mod) == "table" then
        return mod
    end
    return nil
end

local function setting(key, default)
    local store = genv.GDH_HACK_SETTINGS_STATE
    local state = type(store) == "table" and store["autoclicker"] or nil
    local value = type(state) == "table" and state[key] or nil
    if type(value) == "number" then
        return value
    end
    return default
end

local function flag(key, default)
    local store = genv.GDH_HACK_SETTINGS_STATE
    local state = type(store) == "table" and store["autoclicker"] or nil
    local value = type(state) == "table" and state[key] or nil
    if type(value) == "boolean" then
        return value
    end
    return default
end

local function targets()
    local runtime = getRuntime()
    local pass = runtime and runtime.layer and runtime.layer.pass
    if type(pass) ~= "table" then
        return nil, nil
    end
    local p1 = flag("first_player", true) and pass.p1 or nil
    local p2 = flag("second_player", false) and pass.p2 or nil
    if type(p1) ~= "table" and type(p2) ~= "table" then
        return nil, nil
    end
    return p1, p2
end

local function releaseAll()
    for player in pairs(held) do
        pcall(function()
            player:releaseButton(1)
        end)
    end
    table.clear(held)
end

local function setPush(state)
    local p1, p2 = targets()
    if state then
        for index = 1, 2 do
            local player = index == 1 and p1 or p2
            if type(player) == "table" then
                pcall(function()
                    player:pushButton(1)
                end)
                held[player] = true
            end
        end
    else
        releaseAll()
    end
end

local function start()
    if conn then
        return
    end
    pushing = false
    frames = 0
    conn = RunService.Heartbeat:Connect(function()
        if not enabled then
            releaseAll()
            return
        end
        local runtime = getRuntime()
        local okScreen, screen = pcall(function()
            return runtime.snapshot and runtime.snapshot().screen
        end)
        if not okScreen or screen ~= "playing" then
            releaseAll()
            return
        end
        frames += 1
        local pushLength = math.max(0, math.floor(setting("push_length", 4)))
        local releaseLength = math.max(0, math.floor(setting("release_length", 4)))
        if pushing then
            if frames >= pushLength then
                pushing = false
                frames = 0
                setPush(false)
            end
        elseif frames >= releaseLength then
            pushing = true
            frames = 0
            setPush(true)
        end
    end)
end

function Autoclicker.Set(state)
    enabled = state == true
    if enabled then
        start()
    else
        releaseAll()
        if conn then
            conn:Disconnect()
            conn = nil
        end
    end
end

function Autoclicker.IsEnabled()
    return enabled
end

function Autoclicker.Setup(window)
    window:AddToggle({
        Name = "Autoclicker",
        Default = false,
        Description = "Automatically holds and releases the jump button",
        Cheating = true,
        Settings = {
            { Kind = "Int", Text = "Push Length", Key = "push_length", Min = 0, Max = 1000, Default = 4, Increment = 1, Precision = 0 },
            { Kind = "Int", Text = "Release Length", Key = "release_length", Min = 0, Max = 1000, Default = 4, Increment = 1, Precision = 0 },
            { Kind = "Toggle", Text = "First Player", Key = "first_player", Default = true },
            { Kind = "Toggle", Text = "Second Player", Key = "second_player", Default = false },
        },
        Callback = function(state)
            Autoclicker.Set(state)
        end,
    })
end

return Autoclicker
