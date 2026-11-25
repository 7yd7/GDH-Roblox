local enabled = false
local runtime = nil
local original = nil

local function getRuntime()
    if runtime then
        return runtime
    end
    local ok, mod = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local rt = port and port:FindFirstChild("ClientRuntime")
        return rt and require(rt) or nil
    end)
    if ok and type(mod) == "table" and type(mod.practiceSync) == "function" then
        runtime = mod
    end
    return runtime
end

local function apply()
    local mod = getRuntime()
    if not mod then
        return
    end
    if enabled then
        if original == nil then
            original = mod.practiceSync
        end
        mod.practiceSync = function()
            return true
        end
    elseif original ~= nil then
        mod.practiceSync = original
        original = nil
    end
end

local PracticeMusic = {}

function PracticeMusic.Set(state)
    enabled = state == true
    apply()
end

function PracticeMusic.IsEnabled()
    return enabled
end

function PracticeMusic.Setup(window)
    window:AddToggle({
        Name = "Practice Music",
        Default = false,
        Description = "Play the original level music during Practice",
        Callback = function(state)
            PracticeMusic.Set(state)
        end,
    })
end

return PracticeMusic
