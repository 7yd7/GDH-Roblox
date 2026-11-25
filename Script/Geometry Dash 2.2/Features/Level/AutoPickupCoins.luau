local RunService = game:GetService("RunService")

local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local okUtil, Util = pcall(function()
    return genv.Import("Geometry Dash 2.2/Features/Level/Util")
end)
if not okUtil or type(Util) ~= "table" then
    Util = nil
end

local AutoPickupCoins = {}
local enabled = false
local elapsed = 0

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

local function markCoin(state, endSystem, id, coinNo)
    if type(state) ~= "table" then
        return
    end
    if type(state._collected) ~= "table" then
        state._collected = {}
    end
    if not state._collected[id] then
        state._collected[id] = true
        state.coins = (state.coins or 0) + 1
    end
    if type(state.collectedCoins) ~= "table" then
        state.collectedCoins = {}
    end
    if type(coinNo) == "number" and coinNo >= 1 and coinNo <= 3 then
        state.collectedCoins[tostring(coinNo)] = true
        if type(endSystem) == "table" and type(endSystem.runCoins) == "table" then
            endSystem.runCoins[coinNo] = true
        end
    end
    if type(endSystem) == "table" and type(endSystem.coinCollected) == "function" then
        pcall(endSystem.coinCollected, endSystem, id)
    end
end

local function collect()
    local runtime = getRuntime()
    local layer = runtime and runtime.layer
    local level = layer and layer.level
    if type(level) ~= "table" then
        return
    end

    local state = layer.state
    local endSystem = level._endSystem or layer.ending

    local native = level.native
    local coinIndex = type(native) == "table" and native.coinIndex or nil
    if type(coinIndex) == "table" then
        for id, coinNo in pairs(coinIndex) do
            markCoin(state, endSystem, id, coinNo)
        end
    end

    local userIndex = level._userCoinIndex
    if type(userIndex) == "table" then
        for id, coinNo in pairs(userIndex) do
            markCoin(state, endSystem, id, coinNo)
        end
    end
end

AutoPickupCoins.Collect = collect

if Util then
    Util.OnLevelStart(function()
        if enabled then
            collect()
        end
    end)
end

local conn = nil

local function start()
    if conn then
        return
    end
    conn = RunService.Heartbeat:Connect(function(dt)
        if not enabled then
            return
        end
        elapsed += dt
        if elapsed >= 0.1 then
            elapsed = 0
            collect()
        end
    end)
end

function AutoPickupCoins.Set(state)
    enabled = state == true
    if enabled then
        start()
        collect()
    end
end

function AutoPickupCoins.IsEnabled()
    return enabled
end

function AutoPickupCoins.Setup(window)
    window:AddToggle({
        Name = "Auto Pickup Coins",
        Default = false,
        Description = "Collect every coin in the level automatically",
        Cheating = true,
        Callback = function(state)
            AutoPickupCoins.Set(state)
        end,
    })
end

return AutoPickupCoins
