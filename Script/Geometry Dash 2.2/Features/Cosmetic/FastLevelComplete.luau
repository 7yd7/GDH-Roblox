local RunService = game:GetService("RunService")

local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local okUtil, Util = pcall(function()
    return genv.Import("Geometry Dash 2.2/Features/Cosmetic/Util")
end)
if not okUtil or type(Util) ~= "table" then
    Util = nil
end

local Feature = {}
local enabled = false
local hook = Util and Util.NewHook() or nil
local multiplier = 6
local watcher = nil

local function flagSetting(key, default)
    local store = genv.GDH_HACK_SETTINGS_STATE
    local state = type(store) == "table" and store["fast level complete"] or nil
    local value = type(state) == "table" and state[key] or nil
    if type(value) == "boolean" then
        return value
    end
    return default
end

local function targetMultiplier()
    return flagSetting("very_fast", false) and 30 or 6
end

local function apply(newMultiplier)
    multiplier = newMultiplier
    if not hook then
        return
    end
    hook:Restore()
    if enabled then
        hook:Wrap("EndSystem", "advancePresentation", function(original, self, dt)
            return original(self, dt * multiplier)
        end)
    end
end

local function watch()
    if watcher then
        return
    end
    watcher = RunService.Heartbeat:Connect(function()
        if not enabled then
            return
        end
        local wanted = targetMultiplier()
        if wanted ~= multiplier then
            apply(wanted)
        end
    end)
end

function Feature.Set(state)
    enabled = state == true
    apply(targetMultiplier())
    if enabled then
        watch()
    elseif watcher then
        watcher:Disconnect()
        watcher = nil
    end
end

function Feature.IsEnabled()
    return enabled
end

function Feature.Setup(window)
    window:AddToggle({
        Name = "Fast Level Complete",
        Default = false,
        Description = "Speed up the level complete sequence",
        Settings = {
            { Kind = "Toggle", Text = "Very fast", Key = "very_fast", Default = false },
        },
        Callback = function(state)
            Feature.Set(state)
        end,
    })
end

return Feature
