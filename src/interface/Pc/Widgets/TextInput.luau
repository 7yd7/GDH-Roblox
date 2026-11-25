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

local _rowApis = setmetatable({}, { __mode = "k" })

local moduleGenv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}
moduleGenv.GDH_TextRowApis = _rowApis
export type TextInputConfig = {
    Hint: string?,
    Text: string?,
    LayoutOrder: number?,
    Callback: ((string) -> ())?,
}

local function TextInput(config: TextInputConfig): Frame
    init()

    local H = Theme.Layout.ComboHeight

    local pill = Instance.new("Frame")
    pill.Name = "TextInput" .. (config.Hint or "")
    pill.BackgroundColor3 = Theme.Colors.ComboBG
    pill.BackgroundTransparency = 0
    pill.BorderSizePixel = 0
    pill.Size = UDim2.fromOffset(Theme.Layout.ComboWidth, H)
    pill.LayoutOrder = config.LayoutOrder or 0
    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = UDim.new(0, Theme.Layout.DroplistCorner)
    pillCorner.Parent = pill

    local field = Instance.new("TextBox")
    field.Name = "Field"
    field.BackgroundTransparency = 1
    field.BorderSizePixel = 0
    field.Position = UDim2.fromOffset(6, 0)
    field.Size = UDim2.new(1, -12, 1, 0)
    field.FontFace = Theme.GetFontFace()
    field.Text = config.Text or ""
    field.TextColor3 = Theme.Colors.TextPrimary
    field.PlaceholderText = config.Hint or ""
    field.PlaceholderColor3 = Theme.Colors.TextDisabled
    field.TextSize = 14
    field.TextXAlignment = Enum.TextXAlignment.Left
    field.TextYAlignment = Enum.TextYAlignment.Center
    field.ClearTextOnFocus = false
    field.ZIndex = 2
    field.Parent = pill

    field.FocusLost:Connect(function(enterPressed: boolean)
        pill:SetAttribute("Value", field.Text)
        if enterPressed and config.Callback then
            config.Callback(field.Text)
        end
    end)

    local function apiSetText(text: string)
        field.Text = text
        pill:SetAttribute("Value", text)
    end
    function apiGetValue(): string
        return field.Text
    end
    local function apiSubmit(text: string)
        apiSetText(text)
        if config.Callback then
            config.Callback(text)
        end
    end

    pill:SetAttribute("Value", field.Text)
    pill:SetAttribute("WidgetType", "TextInput")
    _rowApis[pill] = { GetValue = apiGetValue, SetText = apiSetText, Submit = apiSubmit }
    return pill
end

return TextInput
