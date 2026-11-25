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

export type FloatInputConfig = {
    Label: string,
    Default: number?,
    Min: number?,
    Max: number?,
    LayoutOrder: number?,
    Callback: ((number) -> ())?,
}

local function FloatInput(config: FloatInputConfig): Frame
    init()

    local row = Instance.new("Frame")
    row.Name = config.Label
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, 24)
    row.LayoutOrder = config.LayoutOrder or 0

    local inputBox = Instance.new("TextBox")
    inputBox.Name = "Input"
    inputBox.BackgroundColor3 = Color3.fromRGB(71, 71, 131)
    inputBox.BackgroundTransparency = 0
    inputBox.BorderSizePixel = 0
    inputBox.Size = UDim2.fromOffset(60, 22)
    inputBox.FontFace = Theme.GetFontFace()
    inputBox.Text = string.format("%.2f", config.Default or 0)
    inputBox.TextColor3 = Theme.Colors.TextPrimary
    inputBox.TextSize = Theme.Font.Small
    inputBox.ClearTextOnFocus = false
    inputBox.Parent = row

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 4)
    inputCorner.Parent = inputBox

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(66, 2)
    label.Size = UDim2.new(1, -70, 0, 18)
    label.FontFace = Theme.GetFontFace()
    label.Text = config.Label
    label.TextColor3 = Theme.Colors.TextSecondary
    label.TextSize = Theme.Font.Small
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    inputBox.FocusLost:Connect(function()
        local val = tonumber(inputBox.Text)
        if val then
            val = math.clamp(val, config.Min or 0, config.Max or 9999)
            inputBox.Text = string.format("%.2f", val)
            if config.Callback then
                config.Callback(val)
            end
        else
            inputBox.Text = string.format("%.2f", config.Default or 0)
        end
    end)

    return row
end

return FloatInput
