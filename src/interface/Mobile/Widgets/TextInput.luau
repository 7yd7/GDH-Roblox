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

local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local Theme = nil

local function init()
    if not Theme then
        Theme = importMobileModule("Theme")
    end
end

export type TextInputCellConfig = {
    Parent: Instance,
    Pill: any?,
    Hint: any?,
    OnArrow: any?,
}

local function TextInputCell(config: TextInputCellConfig): Frame
    init()

    local layout = Theme.Layout
    local colors = Theme.Colors

    local pcApi = nil
    local apis = genv.GDH_TextRowApis
    if typeof(apis) == "table" and typeof(config.Pill) == "Instance" then
        pcApi = apis[config.Pill :: Instance]
    end

    local rightInset = 0
    if typeof(config.OnArrow) == "function" then
        rightInset = layout.ArrowW
    end

    local row = Instance.new("Frame")
    row.Name = "TextInput"
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, layout.RowH)
    row.Parent = config.Parent

    local pill = Instance.new("Frame")
    pill.Name = "Pill"
    pill.BackgroundColor3 = colors.SwitchTrackOff
    pill.BorderSizePixel = 0
    pill.AnchorPoint = Vector2.new(0, 0.5)
    pill.Position = UDim2.new(0, 0, 0.5, 0)
    pill.Size = UDim2.new(1, -rightInset, 0, layout.BoxH)
    pill.Parent = row

    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = UDim.new(0, layout.BoxCorner)
    pillCorner.Parent = pill

    local box = Instance.new("TextBox")
    box.Name = "Field"
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Position = UDim2.fromOffset(14, 0)
    box.Size = UDim2.new(1, -28, 1, 0)
    box.FontFace = Theme.GetFace()
    box.TextColor3 = colors.TextPrimary
    box.PlaceholderColor3 = colors.RadioRingOff
    box.PlaceholderText = tostring(config.Hint or "")
    box.TextSize = layout.BoxTextSize
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.ClearTextOnFocus = false
    box.TextTruncate = Enum.TextTruncate.AtEnd
    box.Parent = pill

    local startText = ""
    if typeof(pcApi) == "table" and typeof(pcApi.GetValue) == "function" then
        local ok, text = pcall(pcApi.GetValue)
        if ok and typeof(text) == "string" then
            startText = text
        end
    end
    box.Text = startText

    box.FocusLost:Connect(function(enterPressed: boolean)
        local text = box.Text
        if enterPressed and typeof(pcApi) == "table" and typeof(pcApi.Submit) == "function" then
            pcall(pcApi.Submit, text)
        elseif typeof(pcApi) == "table" and typeof(pcApi.SetText) == "function" then
            pcall(pcApi.SetText, text)
        end
    end)

    if typeof(config.OnArrow) == "function" then
        local arrowBtn = Instance.new("TextButton")
        arrowBtn.Name = "Arrow"
        arrowBtn.Text = "▾"
        arrowBtn.AutoButtonColor = false
        arrowBtn.BackgroundTransparency = 1
        arrowBtn.BorderSizePixel = 0
        arrowBtn.AnchorPoint = Vector2.new(1, 0.5)
        arrowBtn.Position = UDim2.new(1, -4, 0.5, 0)
        arrowBtn.Size = UDim2.fromOffset(layout.ArrowW, layout.BoxH)
        arrowBtn.FontFace = Theme.GetFace()
        arrowBtn.TextColor3 = colors.TextPrimary
        arrowBtn.TextSize = 24
        arrowBtn.Parent = row
        arrowBtn.Activated:Connect(function()
            pcall(config.OnArrow :: any)
        end)
    end

    return row
end

return TextInputCell
