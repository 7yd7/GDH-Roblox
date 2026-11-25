local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local okUtil, Util = pcall(function()
    return genv.Import("Geometry Dash 2.2/Features/Level/Util")
end)
if not okUtil or type(Util) ~= "table" then
    Util = nil
end

local CoinsInPractice = {}
local enabled = false
local hook = Util and Util.NewHook() or nil

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

local function markCoin(layer, id)
    local level = layer and layer.level
    if type(level) ~= "table" then
        return
    end
    local coinNo = nil
    local native = level.native
    if type(native) == "table" and type(native.coinIndex) == "table" then
        coinNo = native.coinIndex[id]
    end
    if coinNo == nil and type(level._userCoinIndex) == "table" then
        coinNo = level._userCoinIndex[id]
    end

    local runtime = getRuntime()
    local state = runtime and runtime.layer and runtime.layer.state or layer.state
    local endSystem = level._endSystem
        or (runtime and runtime.layer and runtime.layer.ending)
        or layer.ending
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
end

local function wrapper(original, self, source, id, ...)
    local level = self and self.level
    local objectType = self and type(self.N) == "table" and type(self.N.type) == "table"
        and self.N.type[id] or nil
    if not enabled or level == nil or level.practice ~= true
        or (objectType ~= 22 and objectType ~= 31) then
        return original(self, source, id, ...)
    end
    local practice = level.practice
    level.practice = false
    local results = table.pack(pcall(original, self, source, id, ...))
    level.practice = practice
    if results[1] then
        pcall(markCoin, self, id)
        return table.unpack(results, 2, results.n)
    end
    error(results[2])
end

function CoinsInPractice.Set(state)
    enabled = state == true
    if not hook then
        return
    end
    if enabled then
        hook:Wrap("LogicRuntime", "collect", wrapper)
    else
        hook:Restore()
    end
end

function CoinsInPractice.IsEnabled()
    return enabled
end

function CoinsInPractice.Setup(window)
    window:AddToggle({
        Name = "Coins In Practice",
        Default = false,
        Description = "Count coins collected in practice mode",
        Cheating = true,
        Callback = function(state)
            CoinsInPractice.Set(state)
        end,
    })
end

return CoinsInPractice
