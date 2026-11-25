local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local okUtil, GamepassUtil = pcall(function()
    return genv.Import("Geometry Dash 2.2/Features/Level/GamepassUtil")
end)
if not okUtil or type(GamepassUtil) ~= "table" then
    GamepassUtil = nil
end

local UnlockNoclipGamepass = {}

function UnlockNoclipGamepass.Set(state)
    if GamepassUtil then
        return GamepassUtil.Set("noclip", state)
    end
    return false
end

function UnlockNoclipGamepass.IsEnabled()
    return GamepassUtil ~= nil and GamepassUtil.IsEnabled("noclip")
end

function UnlockNoclipGamepass.Setup(window)
    window:AddToggle({
        Name = "Unlock Noclip Gamepass",
        Cheating = false,
        Default = false,
        Description = "Unlock the Noclip gamepass so it can be used; disabling it refunds the unlock",
        Callback = function(state)
            UnlockNoclipGamepass.Set(state)
        end,
    })
end

return UnlockNoclipGamepass
