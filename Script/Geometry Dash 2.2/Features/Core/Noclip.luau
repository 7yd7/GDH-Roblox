local RunService = game:GetService("RunService")

local Noclip = {}
local enabled = false
local runtime = nil
local watchConn = nil
local appliedLayer = nil
local saved = nil

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

local function restore()
    if not saved then
        return
    end
    local pass = saved.pass
    if pass then
        pass.noDeath = saved.noDeath
        if pass.p1 then
            pass.p1.canRunIntoBlocks = saved.p1
        end
        if pass.p2 then
            pass.p2.canRunIntoBlocks = saved.p2
        end
    end
    saved = nil
    appliedLayer = nil
end

local function tick()
    if not enabled then
        return
    end
    local mod = getRuntime()
    local layer = mod and mod.layer
    local pass = layer and layer.pass
    if not pass or not pass.p1 or not pass.p2 then
        if appliedLayer then
            restore()
        end
        return
    end
    if layer ~= appliedLayer then
        restore()
        saved = {
            pass = pass,
            noDeath = pass.noDeath,
            p1 = pass.p1.canRunIntoBlocks,
            p2 = pass.p2.canRunIntoBlocks,
        }
        appliedLayer = layer
    end
    if pass.noDeath ~= true then
        pass.noDeath = true
    end
    if pass.p1.canRunIntoBlocks ~= true then
        pass.p1.canRunIntoBlocks = true
    end
    if pass.p2.canRunIntoBlocks ~= true then
        pass.p2.canRunIntoBlocks = true
    end
end

function Noclip.Set(state)
    enabled = state == true
    if enabled then
        if not watchConn then
            watchConn = RunService.RenderStepped:Connect(tick)
        end
        local mod = getRuntime()
        if mod then
            tick()
        end
    else
        if watchConn then
            watchConn:Disconnect()
            watchConn = nil
        end
        restore()
    end
    return enabled
end

function Noclip.IsEnabled()
    return enabled
end

function Noclip.Setup(window)
    window:AddToggle({
        Name = "Noclip",
        Cheating = true,
        Default = false,
        Description = "Pass through blocks without the game detecting it",
        Callback = function(state)
            Noclip.Set(state)
        end,
    })
end

return Noclip
