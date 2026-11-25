local RunService = game:GetService("RunService")

local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local AutoKill = {}
local enabled = false
local conn = nil

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

local function getCollision()
    local ok, mod = pcall(function()
        local port = game:GetService("ReplicatedStorage").GDPort
        return port and require(port.CollisionPass) or nil
    end)
    if ok and type(mod) == "table" and type(mod.destroyPlayer) == "function" then
        return mod
    end
    return nil
end

local function settings()
    local store = genv.GDH_HACK_SETTINGS_STATE
    if type(store) ~= "table" then
        return nil
    end
    local state = store["auto kill"]
    if type(state) ~= "table" then
        return nil
    end
    return state
end

local function numberSetting(state, key, default)
    local value = state and state[key]
    if type(value) == "number" then
        return value
    end
    return default
end

local function flagSetting(state, key, default)
    local value = state and state[key]
    if type(value) == "boolean" then
        return value
    end
    return default
end

local function kill()
    if not enabled then
        return
    end
    local runtime = getRuntime()
    local layer = runtime and runtime.layer
    local pass = layer and layer.pass
    if type(pass) ~= "table" or pass.playerDied == true then
        return
    end
    local okScreen, screen = pcall(function()
        return runtime.snapshot and runtime.snapshot().screen
    end)
    if not okScreen or screen ~= "playing" then
        return
    end

    local state = settings()
    local usePercent = flagSetting(state, "threshold_toggle", false)
    local useTime = flagSetting(state, "seconds_toggle", false)
    if usePercent or useTime then
        local shouldKill = false
        if usePercent then
            local threshold = math.clamp(numberSetting(state, "threshold", 50), 0, 100)
            local percent = tonumber(layer.percent) or 0
            if percent >= threshold then
                shouldKill = true
            end
        end
        if useTime and not shouldKill then
            local seconds = math.clamp(numberSetting(state, "seconds", 10), 0, 100)
            local elapsed = 0
            if type(runtime.levelTime) == "function" then
                local okTime, value = pcall(runtime.levelTime)
                if okTime then
                    elapsed = tonumber(value) or 0
                end
            end
            if elapsed >= seconds then
                shouldKill = true
            end
        end
        if not shouldKill then
            return
        end
    end

    local collision = getCollision()
    if not collision then
        return
    end
    pcall(function()
        collision.destroyPlayer(pass, pass.p1, nil)
    end)
end

local function start()
    if conn then
        return
    end
    conn = RunService.Heartbeat:Connect(kill)
end

function AutoKill.Set(state)
    enabled = state == true
    if enabled then
        start()
        task.defer(kill)
    elseif conn then
        conn:Disconnect()
        conn = nil
    end
end

function AutoKill.IsEnabled()
    return enabled
end

function AutoKill.Setup(window)
    window:AddToggle({
        Name = "Auto Kill",
        Default = false,
        Description = "Kill the player, or kill when the chosen percentage or time is reached",
        Settings = {
            {
                Kind = "Float",
                Text = "Percentage",
                Key = "threshold",
                Min = 0,
                Max = 100,
                Default = 50,
                Increment = 1,
                Precision = 0,
                Suffix = "%",
                Toggle = true,
                ToggleDefault = false,
            },
            {
                Kind = "Float",
                Text = "Time (seconds)",
                Key = "seconds",
                Min = 0,
                Max = 100,
                Default = 10,
                Increment = 1,
                Precision = 0,
                Toggle = true,
                ToggleDefault = false,
            },
        },
        Callback = function(state)
            AutoKill.Set(state)
        end,
    })
end

return AutoKill
