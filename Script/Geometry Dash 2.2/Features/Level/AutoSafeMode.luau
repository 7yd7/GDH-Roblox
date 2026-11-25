local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local okSafe, SafeMode = pcall(function()
    return genv.Import("Geometry Dash 2.2/Features/Core/SafeMode")
end)
if not okSafe or type(SafeMode) ~= "table" then
    SafeMode = nil
end

local AutoSafeMode = {}
local enabled = false

local function apply()
    if SafeMode and type(SafeMode.Set) == "function" then
        pcall(function()
            SafeMode.Set(enabled)
        end)
    end
end

function AutoSafeMode.Set(state)
    enabled = state == true
    apply()
end

function AutoSafeMode.IsEnabled()
    return enabled
end

function AutoSafeMode.Setup(window)
    window:AddToggle({
        Name = "Auto Safe Mode",
        Default = false,
        Description = "Enable Safe Mode automatically",
        Callback = function(state)
            AutoSafeMode.Set(state)
        end,
    })
end

return AutoSafeMode
