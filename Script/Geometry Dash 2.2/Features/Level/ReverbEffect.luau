local PRESET = 5

local enabled = false
local audio = nil
local original = nil
local originalPreset = nil

local function getAudio()
    if audio then
        return audio
    end
    local ok, mod = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local a = port and port:FindFirstChild("AudioChannels")
        return a and require(a) or nil
    end)
    if ok and type(mod) == "table" and type(mod.updateReverb) == "function" then
        audio = mod
    end
    return audio
end

local function apply()
    local mod = getAudio()
    if not mod then
        return
    end
    if enabled then
        if original == nil then
            original = mod.updateReverb
            originalPreset = mod.reverbPreset
        end
        mod.updateReverb = function(self, ...)
            local ok = pcall(original, self, PRESET, true)
            if not ok then
                pcall(original, self, PRESET)
            end
        end
        pcall(mod.updateReverb, mod, PRESET, true)
        mod.reverbPreset = PRESET
    elseif original ~= nil then
        mod.updateReverb = original
        original = nil
        pcall(mod.updateReverb, mod, originalPreset or 0, true)
        mod.reverbPreset = originalPreset or 0
        originalPreset = nil
    end
end

local ReverbEffect = {}

function ReverbEffect.Set(state)
    enabled = state == true
    apply()
end

function ReverbEffect.IsEnabled()
    return enabled
end

function ReverbEffect.Setup(window)
    window:AddToggle({
        Name = "Reverb Effect",
        Default = false,
        Description = "Force a reverb effect on all audio",
        Callback = function(state)
            ReverbEffect.Set(state)
        end,
    })
end

return ReverbEffect
