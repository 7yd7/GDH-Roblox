local enabled = false
local checkpoints = nil
local original = nil

local function getCheckpoints()
    if checkpoints then
        return checkpoints
    end
    local ok, mod = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local cp = port and port:FindFirstChild("Checkpoints")
        return cp and require(cp) or nil
    end)
    if ok and type(mod) == "table" and type(mod.new) == "function" then
        checkpoints = mod
    end
    return checkpoints
end

local function apply()
    local mod = getCheckpoints()
    if not mod then
        return
    end
    if enabled then
        if original == nil then
            original = mod.new
        end
        mod.new = function(...)
            local instance = original(...)
            if type(instance) == "table" then
                instance.capacity = math.huge
            end
            return instance
        end
    elseif original ~= nil then
        mod.new = original
        original = nil
    end
end

local CheckpointLimit = {}

function CheckpointLimit.Set(state)
    enabled = state == true
    apply()
end

function CheckpointLimit.IsEnabled()
    return enabled
end

function CheckpointLimit.Setup(window)
    window:AddToggle({
        Name = "Checkpoint Limit",
        Default = false,
        Description = "Store an unlimited number of checkpoints",
        Callback = function(state)
            CheckpointLimit.Set(state)
        end,
    })
end

return CheckpointLimit
