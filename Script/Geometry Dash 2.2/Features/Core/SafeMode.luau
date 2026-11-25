local enabled = false
local session = nil
local runtime = nil
local original = {}

local function getSession()
    if session then
        return session
    end
    local ok, mod = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local pr = port and port:FindFirstChild("ProgressionRules")
        return pr and require(pr) or nil
    end)
    if ok and type(mod) == "table" and type(mod.Session) == "table"
        and type(mod.Session.complete) == "function"
        and type(mod.Session.death) == "function"
    then
        session = mod.Session
    end
    return session
end

local function getRuntime()
    if runtime then
        return runtime
    end
    local ok, mod = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local rt = port and port:FindFirstChild("ClientRuntime")
        return rt and require(rt) or nil
    end)
    if ok and type(mod) == "table" and type(mod.recordDeath) == "function" then
        runtime = mod
    end
    return runtime
end

local function apply()
    local s = getSession()
    if not s then
        return
    end
    if enabled then
        if original.complete == nil then
            original.complete = s.complete
            original.death = s.death
            local rt = getRuntime()
            if rt then
                original.runtime = rt
                original.recordDeath = rt.recordDeath
            end
        end
        s.complete = function()
            return { applied = false }
        end
        s.death = function()
            return { applied = false }
        end
        if original.runtime then
            original.runtime.recordDeath = function()
            end
        end
    else
        if original.complete ~= nil then
            s.complete = original.complete
            s.death = original.death
            if original.runtime then
                original.runtime.recordDeath = original.recordDeath
            end
            original = {}
        end
    end
end

local SafeMode = {}

function SafeMode.Set(state)
    enabled = state == true
    apply()
end

function SafeMode.IsEnabled()
    return enabled
end

function SafeMode.Setup(window)
    window:AddToggle({
        Name = "Safe Mode",
        Default = false,
        Description = "Deaths and wins will not count or save progress",
        Callback = function(state)
            SafeMode.Set(state)
        end,
    })
end

return SafeMode
