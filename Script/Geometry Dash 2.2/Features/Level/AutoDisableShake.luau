local enabled = false
local shake = nil
local original = nil

local function getShake()
    if shake then
        return shake
    end
    local ok, mod = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local s = port and port:FindFirstChild("CameraShake")
        return s and require(s) or nil
    end)
    if ok and type(mod) == "table" and type(mod.trigger) == "function" then
        shake = mod
    end
    return shake
end

local function apply()
    local mod = getShake()
    if not mod then
        return
    end
    if enabled then
        if original == nil then
            original = mod.trigger
        end
        mod.trigger = function() end
    elseif original ~= nil then
        mod.trigger = original
        original = nil
    end
end

local AutoDisableShake = {}

function AutoDisableShake.Set(state)
    enabled = state == true
    apply()
end

function AutoDisableShake.IsEnabled()
    return enabled
end

function AutoDisableShake.Setup(window)
    window:AddToggle({
        Name = "Auto Disable Shake",
        Default = false,
        Description = "Remove camera shake effects",
        Callback = function(state)
            AutoDisableShake.Set(state)
        end,
    })
end

return AutoDisableShake
