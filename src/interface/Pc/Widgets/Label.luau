local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

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

local function importWidget(name: string)
    local genv = (typeof(getgenv) == "function" and getgenv())
        or (typeof(_G) == "table" and _G)
        or {}
    local Import = genv.Import
    if Import then
        local module = Import("interface/Pc/Widgets/" .. name)
        if module ~= nil then
            return module
        end
    end
    local parent = script.Parent
    if parent.Name ~= "Widgets" then
        parent = parent:FindFirstChild("Widgets") or parent
    end
    return require(parent[name])
end

local Theme = nil
local Animate = nil

local function init()
    if not Theme then
        Theme = importPcModule("Theme")
    end
    if not Animate then
        Animate = importPcModule("Animate")
    end
end

local measureTextWidth = importWidget("Measure")

export type LabelConfig = {
    Text: string,
    TextColor: Color3?,
    TextSize: number?,
    LayoutOrder: number?,
}

local function Label(config: LabelConfig): TextLabel
    init()

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.Size = UDim2.new(1, 0, 0, 18)
    label.FontFace = Theme.GetFontFace()
    label.Text = config.Text
    label.TextColor3 = config.TextColor or Theme.Colors.TextPrimary
    label.TextSize = config.TextSize or Theme.Font.Body
    label.TextTransparency = Theme.Colors.WindowBGTransparent
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = config.LayoutOrder or 0

    return label
end

return Label
