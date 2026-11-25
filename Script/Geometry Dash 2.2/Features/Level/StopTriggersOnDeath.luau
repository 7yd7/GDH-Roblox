local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local okUtil, Util = pcall(function()
    return genv.Import("Geometry Dash 2.2/Features/Level/Util")
end)
if not okUtil or type(Util) ~= "table" then
    Util = nil
end

local StopTriggersOnDeath = {}
local enabled = false
local hook = Util and Util.NewHook() or nil

local function wrapper()
    if enabled then
        return
    end
end

function StopTriggersOnDeath.Set(state)
    enabled = state == true
    if not hook then
        return
    end
    if enabled then
        hook:Set("LogicRuntime", "playerDied", wrapper)
    else
        hook:Restore()
    end
end

function StopTriggersOnDeath.IsEnabled()
    return enabled
end

function StopTriggersOnDeath.Setup(window)
    window:AddToggle({
        Name = "Stop Triggers On Death",
        Default = false,
        Description = "Prevent death triggers from activating when the player dies",
        Callback = function(state)
            StopTriggersOnDeath.Set(state)
        end,
    })
end

return StopTriggersOnDeath
