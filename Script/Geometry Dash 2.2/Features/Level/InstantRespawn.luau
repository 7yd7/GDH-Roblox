local RunService = game:GetService("RunService")

local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local InstantRespawn = {}
local enabled = false
local hookedRuntime = false
local restarting = false

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

local function respawnNow(runtime)
    if restarting then
        return
    end
    restarting = true
    pcall(function()
        if type(runtime.restartCheckpoint) == "function" then
            runtime.restartCheckpoint()
        end
    end)
    restarting = false
end

local function hookRuntime()
    local runtime = getRuntime()
    if not runtime or type(runtime.afterTick) ~= "function" then
        return
    end
    if genv.GDH_INSTANT_RESPAWN_HOOKED == runtime then
        hookedRuntime = true
        return
    end

    local original = runtime.afterTick
    genv.GDH_INSTANT_RESPAWN_ORIG_AT = original
    runtime.afterTick = function(...)
        local results = table.pack(original(...))

        if enabled and not restarting then
            local layer = runtime.layer
            local state = layer and layer.state
            local ending = layer and layer.ending
            local isComplete = type(state) == "table" and state.complete == true
            local isFinished = type(ending) == "table"
                and (ending.finished == true or ending.completeFrame ~= nil)
            if type(state) == "table" and state.dead == true
                and not isComplete and not isFinished
            then
                respawnNow(runtime)
            end
        end

        return table.unpack(results, 1, results.n)
    end

    genv.GDH_INSTANT_RESPAWN_HOOKED = runtime
    hookedRuntime = true
end

function InstantRespawn.Set(state)
    enabled = state == true
    if enabled then
        hookRuntime()
    end
end

function InstantRespawn.IsEnabled()
    return enabled
end

function InstantRespawn.Setup(window)
    hookRuntime()

    if not hookedRuntime then
        local conn
        conn = RunService.RenderStepped:Connect(function()
            hookRuntime()
            if hookedRuntime and conn then
                conn:Disconnect()
            end
        end)
    end

    window:AddToggle({
        Name = "Instant Respawn",
        Default = false,
        Description = "Respawn immediately after death, skipping the death wait and animation.",
        Callback = function(state)
            InstantRespawn.Set(state)
        end,
    })
end

return InstantRespawn
