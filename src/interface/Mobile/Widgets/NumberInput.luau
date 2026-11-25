local function importMobileModule(name: string)
    local genv = (typeof(getgenv) == "function" and getgenv())
        or (typeof(_G) == "table" and _G)
        or {}
    local Import = genv.Import
    if Import then
        local module = Import("interface/Mobile/" .. name)
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
local FitText = nil

local function init()
    if not Theme then
        Theme = importMobileModule("Theme")
    end
    if not FitText then
        FitText = importMobileModule("FitText")
    end
end

export type NumberInputConfig = {
    Parent: Instance,
    IsFloat: boolean?,
    Name: any?,
    Min: any?,
    Max: any?,
    Default: any?,
    Get: any?,
    Set: any?,
    Center: boolean?,
    SliderSplit: string?,
}

local function NumberInput(config: NumberInputConfig): Frame
    init()

    local layout = Theme.Layout
    local colors = Theme.Colors

    local isFloat = config.IsFloat == true
    local minV = if typeof(config.Min) == "number" then config.Min :: number else 0
    local maxV = if typeof(config.Max) == "number" then config.Max :: number else 9999

    local cell = Instance.new("Frame")
    cell.Name = "NumberInput"
    cell.BackgroundTransparency = 1
    cell.BorderSizePixel = 0
    if config.SliderSplit == "left" then
        cell.Size = UDim2.new(layout.SliderToggleX, -50, 0, layout.RowH)
    elseif config.SliderSplit == "right" then
        cell.Size = UDim2.new(1 - layout.SliderToggleX, 0, 0, layout.RowH)
    else
        cell.Size = UDim2.fromOffset(layout.CellW, layout.RowH)
    end
    cell.Parent = config.Parent

    local centerMode = config.Center == true
    local contentHost: Instance = cell
    if centerMode then
        cell.Size = UDim2.new(1, 0, 0, layout.RowH)
        local holder = Instance.new("Frame")
        holder.Name = "Content"
        holder.BackgroundTransparency = 1
        holder.BorderSizePixel = 0
        holder.AnchorPoint = Vector2.new(0.5, 0.5)
        holder.Position = UDim2.fromScale(0.5, 0.5)
        holder.Size = UDim2.new(0, 0, 1, 0)
        holder.AutomaticSize = Enum.AutomaticSize.X
        holder.Parent = cell
        local holderLayout = Instance.new("UIListLayout")
        holderLayout.FillDirection = Enum.FillDirection.Horizontal
        holderLayout.Padding = UDim.new(0, 8)
        holderLayout.SortOrder = Enum.SortOrder.LayoutOrder
        holderLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        holderLayout.Parent = holder
        contentHost = holder
    end

    local box = Instance.new("TextBox")
    box.Name = "Input"
    box.BackgroundColor3 = colors.InputBG
    box.BorderSizePixel = 0
    box.Position = UDim2.fromOffset(0, (layout.RowH - layout.InputH) / 2)
    box.Size = UDim2.fromOffset(layout.InputW, layout.InputH)
    box.FontFace = Theme.GetFace()
    box.TextColor3 = colors.TextPrimary
    box.TextSize = layout.BoxTextSize
    box.ClearTextOnFocus = false
    box.ClipsDescendants = true
    if centerMode then
        box.LayoutOrder = 1
    end
    box.Parent = if centerMode then contentHost else cell

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, layout.InputCorner)
    boxCorner.Parent = box

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    if centerMode then
        label.AutomaticSize = Enum.AutomaticSize.X
        label.Size = UDim2.new(0, 0, 1, 0)
        label.LayoutOrder = 2
    else
        label.Position = UDim2.fromOffset(layout.InputW + 8, 0)
        label.Size = UDim2.new(1, -(layout.InputW + 12), 1, 0)
    end
    label.FontFace = Theme.GetFace()
    label.Text = tostring(config.Name or "")
    label.TextColor3 = colors.TextPrimary
    label.TextSize = layout.LabelSize
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = if centerMode then contentHost else cell
    if not centerMode then
        FitText.fit(label, {
            Base = layout.LabelSize,
            Min = layout.LabelMinSize,
        })
    end

    local function formatValue(value: number): string
        if isFloat then
            return string.format("%.2f", value)
        end
        return tostring(math.floor(value))
    end

    local startText = formatValue(0)
    if typeof(config.Get) == "function" then
        local ok, value = pcall(config.Get :: any)
        if ok and typeof(value) == "number" then
            startText = formatValue(value)
        end
    elseif typeof(config.Default) == "number" then
        startText = formatValue(config.Default :: number)
    end
    box.Text = startText

    box.FocusLost:Connect(function()
        local value = tonumber(box.Text)
        if value == nil then
            box.Text = startText
            return
        end
        if not isFloat then
            value = math.floor(value)
        end
        value = math.clamp(value, minV, maxV)
        local text = formatValue(value)
        box.Text = text
        startText = text
        if typeof(config.Set) == "function" then
            pcall(config.Set :: any, value)
        end
    end)

    return cell
end

return NumberInput
