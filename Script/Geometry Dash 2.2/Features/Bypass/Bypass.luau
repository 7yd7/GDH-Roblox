local enabled = false
local rules = nil
local originalAccess = nil
local originalPolicy = nil
local originalCanStart = nil

local function getRules()
    if rules then
        return rules
    end
    local ok, mod = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local pr = port and port:FindFirstChild("ProgressionRules")
        return pr and require(pr) or nil
    end)
    if ok and type(mod) == "table" and type(mod.access) == "function"
        and type(mod.policy) == "function" and type(mod.canStart) == "function"
    then
        rules = mod
    end
    return rules
end

local function apply()
    local mod = getRules()
    if not mod then
        return
    end
    if enabled then
        if originalAccess == nil then
            originalAccess = mod.access
            originalPolicy = mod.policy
            originalCanStart = mod.canStart
        end
        mod.access = function(self, ...)
            local ok, result = pcall(originalAccess, self, ...)
            if ok and type(result) == "table" then
                result.allowed = true
                result.reason = nil
                result.enforced = false
                return result
            end
            return { allowed = true, enforced = false }
        end
        mod.policy = function(self, ...)
            local ok, result = pcall(originalPolicy, self, ...)
            if ok and type(result) == "table" then
                result.enforced = {
                    officialCoinGates = false,
                    towerFloorOrder = false,
                    challengeVault = false,
                }
                return result
            end
            return {
                enforced = {
                    officialCoinGates = false,
                    towerFloorOrder = false,
                    challengeVault = false,
                },
            }
        end
        mod.canStart = function(self, ...)
            local ok, allowed, reason, info = pcall(originalCanStart, self, ...)
            if not ok then
                return true, nil, { allowed = true }
            end
            if type(info) ~= "table" then
                info = {}
            end
            info.allowed = true
            info.reason = nil
            return true, nil, info
        end
    elseif originalAccess ~= nil then
        mod.access = originalAccess
        mod.policy = originalPolicy
        mod.canStart = originalCanStart
        originalAccess, originalPolicy, originalCanStart = nil, nil, nil
    end
end

local MainLevels = {}

function MainLevels.Set(state)
    enabled = state == true
    apply()
end

function MainLevels.IsEnabled()
    return enabled
end

function MainLevels.Setup(window)
    window:AddToggle({
        Name = "Main Levels",
        Default = false,
        Description = "Make every main level playable",
        Callback = function(state)
            MainLevels.Set(state)
        end,
    })
end

return MainLevels
