local RunService = game:GetService("RunService")

local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local StraightFlyBot = {}
local enabled = false
local conn = nil
local states = setmetatable({}, { __mode = "k" })

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

local function numberSetting(key, default)
    local store = genv.GDH_HACK_SETTINGS_STATE
    local state = type(store) == "table" and store["straight fly bot"] or nil
    local value = type(state) == "table" and state[key] or nil
    if type(value) == "number" then
        return value
    end
    return default
end

local function flagSetting(key, default)
    local store = genv.GDH_HACK_SETTINGS_STATE
    local state = type(store) == "table" and store["straight fly bot"] or nil
    local value = type(state) == "table" and state[key] or nil
    if type(value) == "boolean" then
        return value
    end
    return default
end

local function release(player)
    local entry = states[player]
    if type(entry) ~= "table" or not entry.holding then
        return
    end
    pcall(function()
        player:releaseButton(1)
    end)
    entry.holding = false
end

local function releaseAll()
    for player, entry in pairs(states) do
        if type(entry) == "table" and entry.holding then
            pcall(function()
                player:releaseButton(1)
            end)
            entry.holding = false
        end
    end
end

local function push(player)
    local entry = states[player]
    if type(entry) ~= "table" or entry.holding then
        return
    end
    pcall(function()
        player:pushButton(1)
    end)
    entry.holding = true
end

local function start()
    if conn then
        return
    end
    conn = RunService.Heartbeat:Connect(function()
        if not enabled then
            releaseAll()
            return
        end
        local runtime = getRuntime()
        local pass = runtime and runtime.layer and runtime.layer.pass
        local okScreen, screen = pcall(function()
            return runtime.snapshot and runtime.snapshot().screen
        end)
        if type(pass) ~= "table" or not okScreen or screen ~= "playing" then
            releaseAll()
            return
        end

        local accuracy = math.max(0, numberSetting("y_accuracy", 40))
        for index = 1, 2 do
            local player = index == 1 and pass.p1 or pass.p2
            local selected = index == 1
                and flagSetting("first_player", true)
                or flagSetting("second_player", false)
            if type(player) ~= "table" or not selected
                or player.isDead == true or player.isShip ~= true
            then
                if type(player) == "table" then
                    release(player)
                    local old = states[player]
                    if type(old) == "table" then
                        old.target = nil
                    end
                end
                continue
            end

            local entry = states[player]
            if type(entry) ~= "table" then
                entry = {}
                states[player] = entry
            end
            local y = tonumber(player.y)
            if y == nil then
                release(player)
                continue
            end
            if entry.target == nil then
                entry.target = y
            end
            local delta = entry.target - y
            if delta > accuracy then
                push(player)
            elseif delta < -accuracy then
                release(player)
            end
        end
    end)
end

function StraightFlyBot.Set(state)
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

function StraightFlyBot.IsEnabled()
    return enabled
end

function StraightFlyBot.Setup(window)
    window:AddToggle({
        Name = "Straight Fly Bot",
        Default = false,
        Description = "Keeps the ship flying level by holding and releasing jump",
        Cheating = true,
        Settings = {
            { Kind = "Float", Text = "Y Accuracy", Key = "y_accuracy", Min = 0, Max = 1000, Default = 40, Increment = 0.5, Precision = 1 },
            { Kind = "Toggle", Text = "First Player", Key = "first_player", Default = true },
            { Kind = "Toggle", Text = "Second Player", Key = "second_player", Default = false },
        },
        Callback = function(state)
            StraightFlyBot.Set(state)
        end,
    })
end

return StraightFlyBot
