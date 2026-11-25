local enabled = false
local library = nil
local original = nil

local function getLibrary()
    if library then
        return library
    end
    local ok, mod = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local lib = port and port:FindFirstChild("SongLibrary")
        return lib and require(lib) or nil
    end)
    if ok and type(mod) == "table" and type(mod.validId) == "function" then
        library = mod
    end
    return library
end

local function apply()
    local mod = getLibrary()
    if not mod then
        return
    end
    if enabled then
        if original == nil then
            original = mod.validId
        end
        mod.validId = function(value)
            if type(value) == "number" and value == value and value >= 1 then
                return string.format("%d", value)
            end
            if type(value) == "string" then
                local digits = value:match("%d+")
                if digits then
                    return digits
                end
            end
            return original(value)
        end
    elseif original ~= nil then
        mod.validId = original
        original = nil
    end
end

local MusicCustomizer = {}

function MusicCustomizer.Set(state)
    enabled = state == true
    apply()
end

function MusicCustomizer.IsEnabled()
    return enabled
end

function MusicCustomizer.Setup(window)
    window:AddToggle({
        Name = "Music Customizer",
        Default = false,
        Description = "Use any custom song ID in the music picker",
        Callback = function(state)
            MusicCustomizer.Set(state)
        end,
    })
end

return MusicCustomizer
