local RunService = game:GetService("RunService")

local IgnoreESC = {}
local enabled = false
local runtime = nil
local original = nil
local hookConn = nil

local function getRuntime()
    if runtime then
        return runtime
    end
    local ok, mod = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local rt = port and port:FindFirstChild("ClientRuntime")
        return rt and require(rt) or nil
    end)
    if ok and type(mod) == "table" and type(mod.escapePressed) == "function" then
        runtime = mod
    end
    return runtime
end

local function hook()
    if not enabled then
        return false
    end
    local rt = getRuntime()
    if not rt then
        if not hookConn then
            hookConn = RunService.RenderStepped:Connect(function()
                if getRuntime() and hookConn then
                    hookConn:Disconnect()
                    hookConn = nil
                    hook()
                end
            end)
        end
        return false
    end
    if original == nil then
        original = rt.escapePressed
        rt.escapePressed = function() end
    end
    return true
end

local function apply()
    if enabled then
        hook()
    elseif original ~= nil and runtime ~= nil then
        runtime.escapePressed = original
        original = nil
    end
end

function IgnoreESC.Set(state)
    enabled = state == true
    apply()
end

function IgnoreESC.IsEnabled()
    return enabled
end

function IgnoreESC.Setup(window)
    window:AddToggle({
        Name = "Ignore ESC",
        Default = false,
        Description = "Stop ESC from opening the pause menu",
        Callback = function(state)
            IgnoreESC.Set(state)
        end,
    })
end

return IgnoreESC
