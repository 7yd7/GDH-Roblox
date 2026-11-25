local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local okUtil, GamepassUtil = pcall(function()
    return genv.Import("Geometry Dash 2.2/Features/Level/GamepassUtil")
end)
if not okUtil or type(GamepassUtil) ~= "table" then
    GamepassUtil = nil
end

local UnlockHackMenuGamepass = {}

function UnlockHackMenuGamepass.Set(state)
    if GamepassUtil then
        return GamepassUtil.Set("menu", state)
    end
    return false
end

function UnlockHackMenuGamepass.IsEnabled()
    return GamepassUtil ~= nil and GamepassUtil.IsEnabled("menu")
end

function UnlockHackMenuGamepass.Setup(window)
    window:AddToggle({
        Name = "Unlock Hack Menu Gamepass",
        Cheating = false,
        Default = false,
        Description = "Unlock the Hack Menu gamepass so it can be used; disabling it refunds the unlock",
        Callback = function(state)
            UnlockHackMenuGamepass.Set(state)
        end,
    })
end

return UnlockHackMenuGamepass
