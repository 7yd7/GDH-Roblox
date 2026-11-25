local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local okUtil, GamepassUtil = pcall(function()
    return genv.Import("Geometry Dash 2.2/Features/Level/GamepassUtil")
end)
if not okUtil or type(GamepassUtil) ~= "table" then
    GamepassUtil = nil
end

local UnlockSpeedHackGamepass = {}

function UnlockSpeedHackGamepass.Set(state)
    if GamepassUtil then
        return GamepassUtil.Set("speed", state)
    end
    return false
end

function UnlockSpeedHackGamepass.IsEnabled()
    return GamepassUtil ~= nil and GamepassUtil.IsEnabled("speed")
end

function UnlockSpeedHackGamepass.Setup(window)
    window:AddToggle({
        Name = "Unlock SpeedHack Gamepass",
        Cheating = false,
        Default = false,
        Description = "Unlock the SpeedHack gamepass so it can be used; disabling it refunds the unlock",
        Callback = function(state)
            UnlockSpeedHackGamepass.Set(state)
        end,
    })
end

return UnlockSpeedHackGamepass
