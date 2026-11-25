local enabled = false
local fx = nil
local original = nil

local function getFx()
    if fx then
        return fx
    end
    local ok, mod = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local rf = port and port:FindFirstChild("RendererPlayerFx")
        return rf and require(rf) or nil
    end)
    if ok and type(mod) == "table" and type(mod.blinkVisible) == "function" then
        fx = mod
    end
    return fx
end

local function apply()
    local mod = getFx()
    if not mod then
        return
    end
    if enabled then
        if original == nil then
            original = mod.blinkVisible
        end
        mod.blinkVisible = function()
            return true
        end
    elseif original ~= nil then
        mod.blinkVisible = original
        original = nil
    end
end

local NoRespawnBlink = {}

function NoRespawnBlink.Set(state)
    enabled = state == true
    apply()
end

function NoRespawnBlink.IsEnabled()
    return enabled
end

function NoRespawnBlink.Setup(window)
    window:AddToggle({
        Name = "No Respawn Blink",
        Default = false,
        Description = "Keep the player visible instead of blinking after respawn",
        Callback = function(state)
            NoRespawnBlink.Set(state)
        end,
    })
end

return NoRespawnBlink
