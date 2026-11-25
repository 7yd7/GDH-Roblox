local RunService = game:GetService("RunService")

local AutoPractice = {}
local enabled = false
local lastState = nil
local watchConn = nil

local function forcePractice()
    local ok, runtime = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local rt = port and port:FindFirstChild("ClientRuntime")
        return rt and require(rt) or nil
    end)
    if ok and type(runtime) == "table" and type(runtime.setPractice) == "function" then
        pcall(function()
            runtime.setPractice(true)
        end)
    end
end

local function watch()
    if watchConn then
        return
    end
    watchConn = RunService.Heartbeat:Connect(function()
        if not enabled then
            lastState = nil
            return
        end
        local ok, runtime = pcall(function()
            local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
            local rt = port and port:FindFirstChild("ClientRuntime")
            return rt and require(rt) or nil
        end)
        if not ok or type(runtime) ~= "table" or type(runtime.layer) ~= "table" then
            return
        end
        local state = runtime.layer.state
        if state ~= lastState then
            lastState = state
            task.defer(forcePractice)
        end
    end)
end

function AutoPractice.Set(state)
    enabled = state == true
    if enabled then
        watch()
        task.defer(forcePractice)
    else
        lastState = nil
    end
end

function AutoPractice.IsEnabled()
    return enabled
end

function AutoPractice.Setup(window)
    window:AddToggle({
        Name = "Auto Practice Mode",
        Default = false,
        Description = "Start every level in Practice Mode",
        Callback = function(state)
            AutoPractice.Set(state)
        end,
    })
end

return AutoPractice
