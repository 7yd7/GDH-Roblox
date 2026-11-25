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
        hook:Wrap("GameplayHUD", "nativePercentText", function(original, value, ...)
            local ok, result = pcall(original, value, true)
            if ok then
                return result
            end
            return tostring(value) .. "%"
        end)
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
        Name = "Accurate Percentage",
        Default = false,
        Description = "Show exact percent with two decimals",
        Callback = function(state)
            Feature.Set(state)
        end,
    })
end

return Feature
