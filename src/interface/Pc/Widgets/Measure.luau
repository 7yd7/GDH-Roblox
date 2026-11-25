local TextService = game:GetService("TextService")

local function importPcModule(name: string)
    local genv = (typeof(getgenv) == "function" and getgenv())
        or (typeof(_G) == "table" and _G)
        or {}
    local Import = genv.Import
    if Import then
        local module = Import("interface/Pc/" .. name)
        if module ~= nil then
            return module
        end
    end
    local parent = script.Parent
    if parent.Name == "Widgets" then
        parent = parent.Parent
    end
    return require(parent[name])
end

local Theme = nil
local function init()
    if not Theme then
        Theme = importPcModule("Theme")
    end
end

local function measureTextWidth(text: string, size: number): number
    init()
    local font = Theme.GetFontFace()
    local ok, bounds = pcall(function()
        return TextService:GetTextBoundsAsync(text, font, size, Vector2.new(10000, size * 2))
    end)
    if ok and bounds then
        return math.ceil(bounds.X)
    end
    return #text * math.floor(size * 0.58 + 0.5)
end

return measureTextWidth
