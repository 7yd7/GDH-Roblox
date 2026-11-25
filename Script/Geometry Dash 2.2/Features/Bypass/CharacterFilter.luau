local enabled = false
local catalogue = nil
local original = nil

local function getCatalogue()
    if catalogue then
        return catalogue
    end
    local ok, mod = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local cat = port and port:FindFirstChild("Catalogue")
        return cat and require(cat) or nil
    end)
    if ok and type(mod) == "table" and type(mod.isSelectable) == "function" then
        catalogue = mod
    end
    return catalogue
end

local function apply()
    local mod = getCatalogue()
    if not mod then
        return
    end
    if enabled then
        if original == nil then
            original = mod.isSelectable
        end
        mod.isSelectable = function(self, ...)
            local ok, result = pcall(original, self, ...)
            if ok and type(result) == "table" then
                result.allowed = true
                result.selectable = true
                return result
            end
            return true
        end
    elseif original ~= nil then
        mod.isSelectable = original
        original = nil
    end
end

local CharacterFilter = {}

function CharacterFilter.Set(state)
    enabled = state == true
    apply()
end

function CharacterFilter.IsEnabled()
    return enabled
end

function CharacterFilter.Setup(window)
    window:AddToggle({
        Name = "Character Filter",
        Default = false,
        Description = "Allow every character to be selected",
        Callback = function(state)
            CharacterFilter.Set(state)
        end,
    })
end

return CharacterFilter
