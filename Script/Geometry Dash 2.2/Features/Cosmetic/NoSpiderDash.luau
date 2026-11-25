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

local function apply()
    if not hook then
        return
    end
    if enabled then
        hook:Set("RendererPlayerFx", "playSpiderDashEffect", Util.Noop)
        hook:Set("RendererPlayerFx", "_spiderDash", Util.Noop)
    else
        hook:Restore()
    end
end

function Feature.Set(state)
    enabled = state == true
    apply()
end

function Feature.IsEnabled()
    return enabled
end

function Feature.Setup(window)
    window:AddToggle({
        Name = "No Spider Dash",
        Default = false,
        Description = "Remove spider dash visuals",
        Callback = function(state)
            Feature.Set(state)
        end,
    })
end

return Feature
