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

export type SeparatorConfig = {
    Text: string?,
    Height: number?,
    LayoutOrder: number?,
    Color: Color3?,
    Transparency: number?,
}

local function Separator(configOrTextOrHeight: (string | number | SeparatorConfig)?, layoutOrder: number?): Frame
    init()

    local text: string? = nil
    local customHeight: number? = nil
    local customOrder = layoutOrder

    if typeof(configOrTextOrHeight) == "string" then
        text = configOrTextOrHeight
    elseif typeof(configOrTextOrHeight) == "number" then
        customHeight = configOrTextOrHeight
    elseif typeof(configOrTextOrHeight) == "table" then
        text = configOrTextOrHeight.Text
        customHeight = configOrTextOrHeight.Height
        customOrder = configOrTextOrHeight.LayoutOrder or customOrder
    end

    local sepHeight = customHeight or Theme.Layout.SeparatorHeight or 10

    local container = Instance.new("Frame")
    container.Name = "Separator"
    container.Active = false
    container.Selectable = false
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.Size = UDim2.new(1, 0, 0, sepHeight)
    container.LayoutOrder = customOrder or 0

    local sepColor = Theme.Colors.Separator
    local sepAlpha = Theme.Colors.SeparatorAlpha or 0.35

    if text and text ~= "" then

        local textWidth = measureTextWidth(text, Theme.Font.Small)
        local pad = 8

        local lineLeft = Instance.new("Frame")
        lineLeft.Name = "LineLeft"
        lineLeft.Active = false
        lineLeft.Selectable = false
        lineLeft.BackgroundColor3 = sepColor
        lineLeft.BackgroundTransparency = sepAlpha
        lineLeft.BorderSizePixel = 0
        lineLeft.AnchorPoint = Vector2.new(0, 0.5)
        lineLeft.Position = UDim2.new(0, 0, 0.5, 0)
        lineLeft.Size = UDim2.new(0.5, -(textWidth / 2 + pad), 0, 1)
        lineLeft.Parent = container

        local label = Instance.new("TextLabel")
        label.Name = "Text"
        label.Active = false
        label.Selectable = false
        label.BackgroundTransparency = 1
        label.BorderSizePixel = 0
        label.AnchorPoint = Vector2.new(0.5, 0.5)
        label.Position = UDim2.new(0.5, 0, 0.5, 0)
        label.Size = UDim2.new(0, textWidth, 1, 0)
        label.FontFace = Theme.GetFontFace()
        label.Text = text
        label.TextColor3 = Theme.Colors.TextMuted or Theme.Colors.TextSecondary
        label.TextSize = Theme.Font.Small
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.Parent = container

        local lineRight = Instance.new("Frame")
        lineRight.Name = "LineRight"
        lineRight.Active = false
        lineRight.Selectable = false
        lineRight.BackgroundColor3 = sepColor
        lineRight.BackgroundTransparency = sepAlpha
        lineRight.BorderSizePixel = 0
        lineRight.AnchorPoint = Vector2.new(1, 0.5)
        lineRight.Position = UDim2.new(1, 0, 0.5, 0)
        lineRight.Size = UDim2.new(0.5, -(textWidth / 2 + pad), 0, 1)
        lineRight.Parent = container
    else

        local line = Instance.new("Frame")
        line.Name = "Line"
        line.Active = false
        line.Selectable = false
        line.BackgroundColor3 = sepColor
        line.BackgroundTransparency = sepAlpha
        line.BorderSizePixel = 0
        line.AnchorPoint = Vector2.new(0, 0.5)
        line.Position = UDim2.new(0, 0, 0.5, 0)
        line.Size = UDim2.new(1, 0, 0, 1)
        line.Parent = container
    end

    return container
end

return Separator
