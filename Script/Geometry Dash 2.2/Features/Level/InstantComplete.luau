local RunService = game:GetService("RunService")

local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local InstantComplete = {}
local enabled = false
local hookedLevelStart = false
local hookedHooks = nil
local watchConn = nil
local hookedAfterTickFn = nil
local hookedAfterTickOrig = nil
local RAMP_SECONDS = 1
local UNITS_PER_SECOND = 311
local LEVEL_TIME_FACTOR = 0.5
local FALLBACK_DELAY_SECONDS = 30
local lastDelayEnabled = false
local rampActive = false
local rampStartX = 0
local rampTargetX = 0
local rampStartTime = 0
local rampFinishAt = 0
local rampDuration = RAMP_SECONDS
local instantPending = false

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

local function settings()
    local store = genv.GDH_HACK_SETTINGS_STATE
    if type(store) ~= "table" then
        return nil
    end
    local state = store["instant complete"]
    if type(state) ~= "table" then
        return nil
    end
    return state
end

local function isDelayEnabled()
    local state = settings()
    return type(state) == "table" and state.delay == true
end

local function computeRampDuration(level, endSystem)
    if not isDelayEnabled() then
        return RAMP_SECONDS
    end
    local units = tonumber(level and level.length)
    if not units or units <= 0 then
        units = tonumber(endSystem and endSystem.portalPosX)
    end
    local seconds
    if units and units > 0 then
        seconds = (units / UNITS_PER_SECOND) * LEVEL_TIME_FACTOR
    else
        seconds = FALLBACK_DELAY_SECONDS
    end
    return math.max(RAMP_SECONDS, seconds)
end

local function collectCoins()
    local ok, coins = pcall(function()
        return genv.Import("Geometry Dash 2.2/Features/Level/AutoPickupCoins")
    end)
    if ok and type(coins) == "table" and type(coins.IsEnabled) == "function"
        and coins.IsEnabled() and type(coins.Collect) == "function"
    then
        pcall(coins.Collect)
    end
end

local function preparePoints()
    local runtime = getRuntime()
    local layer = runtime and runtime.layer
    local level = layer and layer.level
    local logic = layer and layer.logic
    if type(level) ~= "table" or type(logic) ~= "table" then
        return
    end
    if level.isPlatformer ~= true and level.platformer ~= true
        and logic.isPlatformer ~= true
    then
        return
    end

    local total = 0
    for _, coin in ipairs(logic.collectibles or {}) do
        if type(coin) == "table" then
            total += tonumber(coin.points) or 0
        end
    end
    if total <= 0 then
        return
    end

    local settings = level.settings
    if type(settings) ~= "table" or settings.noTimePenalty ~= true then
        total += math.floor((tonumber(logic.attemptTime) or 0) * 1000)
    end

    logic.points = total
    logic.pointsDirty = true
end

local function showCompletionPanel(layer, ending)
    local hooks = layer and layer.hooks
    local presenting = hooks and hooks.presenting
    if type(presenting) ~= "function" or type(debug) ~= "table"
        or type(debug.getupvalue) ~= "function"
        or type(debug.setupvalue) ~= "function"
    then
        return
    end

    local modeIndex, oldMode
    for index = 1, 8 do
        local ok, value = pcall(debug.getupvalue, presenting, index)
        if not ok then
            break
        end
        if value == "playing" or value == "ending" then
            modeIndex, oldMode = index, value
            break
        end
    end
    if not modeIndex then
        return
    end

    local presentation = ending.presentation
    local delay = type(presentation) == "table"
        and tonumber(presentation.panelDelay) or 0
    ending.completeClock = math.max(
        tonumber(ending.completeClock) or 0,
        math.max(10, delay + 0.5)
    )

    pcall(debug.setupvalue, presenting, modeIndex, "ending")
    pcall(presenting)
    pcall(debug.setupvalue, presenting, modeIndex, oldMode or "playing")
end

local function complete()
    local runtime = getRuntime()
    local layer = runtime and runtime.layer
    local ending = layer and layer.ending
    local session = layer and layer.level and layer.level.onlineSession
    if type(ending) ~= "table" or type(ending.levelComplete) ~= "function" then
        return false
    end
    if ending.finished or ending.completeFrame ~= nil then
        return true
    end

    local state = layer and layer.state
    collectCoins()
    preparePoints()
    ending.active = true
    pcall(ending.levelComplete, ending)

    local result = ending.result
    if type(result) == "table" then
        result.saveProgress = true
        result.startPos = false
        result.ignoreDamage = nil
        result.speedChange = nil
    end
    if type(session) == "table" and session.state == "complete" then
        session.state = "running"
        session.best = 0
    end
    if type(state) == "table" then
        state._completionRecorded = nil
    end

    local hooks = layer and layer.hooks
    if type(hooks) == "table" and type(hooks.completeRun) == "function" then
        pcall(hooks.completeRun)
    end
    if type(session) == "table" and type(session.complete) == "function"
        and session.state ~= "complete"
    then
        pcall(session.complete, session, state and state.collectedCoins, result)
    end

    showCompletionPanel(layer, ending)
    return true
end

local function resetRamp()
    rampActive = false
    rampFinishAt = 0
    rampStartX = 0
    rampTargetX = 0
    rampStartTime = 0
    rampDuration = RAMP_SECONDS
    instantPending = false
end

local function beginRamp()
    local runtime = getRuntime()
    local layer = runtime and runtime.layer
    local pass = layer and layer.pass
    local p1 = pass and pass.p1
    local level = layer and layer.level
    local endSystem = level and level._endSystem
    local target = type(endSystem) == "table" and tonumber(endSystem.portalPosX) or nil
    if type(p1) ~= "table" or not target then
        resetRamp()
        return
    end

    local start = tonumber(p1.x) or tonumber(layer.state and layer.state.x) or 0
    rampStartX = start
    rampTargetX = math.max(target, start)
    rampStartTime = os.clock()
    lastDelayEnabled = isDelayEnabled()
    rampDuration = computeRampDuration(level, endSystem)
    rampActive = rampTargetX > start + 1
    rampFinishAt = 0
end

local function armCompletion()
    if isDelayEnabled() then
        beginRamp()
    else
        instantPending = true
    end
end

local function advanceRamp()
    local runtime = getRuntime()
    local layer = runtime and runtime.layer
    local ending = layer and layer.ending
    if type(ending) == "table"
        and (ending.finished == true or ending.completeFrame ~= nil)
    then
        resetRamp()
        return
    end

    local pass = layer and layer.pass
    local p1 = pass and pass.p1
    local state = layer and layer.state
    local level = layer and layer.level
    local endSystem = level and level._endSystem
    if type(p1) ~= "table" or type(state) ~= "table" then
        return
    end

    local useDelay = isDelayEnabled()
    if useDelay ~= lastDelayEnabled then
        lastDelayEnabled = useDelay
        if not useDelay then
            rampActive = false
            instantPending = true
            return
        end
        rampDuration = computeRampDuration(level, endSystem)
        if rampActive then
            rampStartX = tonumber(p1.x) or rampStartX
            rampStartTime = os.clock()
        end
    end
    local elapsed = math.max(0, os.clock() - rampStartTime)
    local mix = math.clamp(elapsed / rampDuration, 0, 1)
    local x = rampStartX + (rampTargetX - rampStartX) * mix
    p1.x = x
    state.x = x

    if pass.playerDied == true then
        pass.playerDied = false
    end
    state.dead = false

    if type(endSystem) == "table" and type(endSystem.percent) == "function" then
        local ok, percent = pcall(
            endSystem.percent,
            endSystem,
            tonumber(state.tick) or 0,
            level._platformerProgress
        )
        if ok and tonumber(percent) then
            layer.percent = math.clamp(tonumber(percent), 0, 100)
        end
    end

    if mix >= 1 then
        rampActive = false
        rampFinishAt = os.clock() + 0.5
    end
end

local function handleTick(original, ...)
    local results = table.pack(original(...))
    if enabled then
        if instantPending then
            if complete() then
                instantPending = false
            end
        elseif rampActive then
            advanceRamp()
        elseif rampFinishAt > 0 and os.clock() >= rampFinishAt then
            rampFinishAt = 0
            complete()
        end
    end
    return table.unpack(results, 1, results.n)
end

local function hookAfterTick()
    local runtime = getRuntime()
    local hooks = runtime and runtime.layer and runtime.layer.hooks
    if type(hooks) ~= "table" or type(hooks.afterTick) ~= "function" then
        return
    end
    local current = hooks.afterTick
    if hookedHooks == hooks and hookedAfterTickFn == current then
        return
    end
    local original = current
    if current == hookedAfterTickFn and type(hookedAfterTickOrig) == "function" then
        original = hookedAfterTickOrig
    end
    local wrapper = function(...)
        return handleTick(original, ...)
    end
    hookedAfterTickOrig = original
    hookedAfterTickFn = wrapper
    hooks.__gdhICOrigAT = original
    hooks.afterTick = wrapper
    hookedHooks = hooks
end

local function startWatch()
    if watchConn then
        return
    end
    watchConn = RunService.Heartbeat:Connect(function()
        if enabled then
            hookAfterTick()
        end
    end)
end

local function hookLevelStart()
    if hookedLevelStart then
        return
    end
    local runtime = getRuntime()
    if not runtime or type(runtime.levelStarted) ~= "function" then
        return
    end
    if genv.GDH_INSTANT_COMPLETE_HOOKED == runtime then
        hookedLevelStart = true
        return
    end

    local original = runtime.levelStarted
    genv.GDH_INSTANT_COMPLETE_ORIG_LS = original
    runtime.levelStarted = function(...)
        local results = table.pack(original(...))
        resetRamp()
        hookAfterTick()
        if enabled then
            armCompletion()
        end
        return table.unpack(results, 1, results.n)
    end

    genv.GDH_INSTANT_COMPLETE_HOOKED = runtime
    hookedLevelStart = true
end

function InstantComplete.Set(state)
    enabled = state == true
    if enabled then
        hookLevelStart()
        startWatch()
        hookAfterTick()
        armCompletion()
    else
        resetRamp()
    end
end

function InstantComplete.IsEnabled()
    return enabled
end

function InstantComplete.Setup(window)
    hookLevelStart()
    startWatch()
    hookAfterTick()

    if not hookedLevelStart then
        local conn
        conn = RunService.RenderStepped:Connect(function()
            hookLevelStart()
            hookAfterTick()
            if hookedLevelStart and conn then
                conn:Disconnect()
            end
        end)
    end

    window:AddToggle({
        Name = "Instant Complete",
        Default = false,
        Cheating = true,
        Settings = {
            {
                Kind = "Label",
                Text = "wait half the level's normal play time so long levels count stars too.",
            },
            {
                Kind = "Toggle",
                Text = "Complete Delay (Half Time)",
                Key = "delay",
                Default = false,
            },
        },
        Callback = function(state)
            InstantComplete.Set(state)
        end,
    })
end

return InstantComplete
