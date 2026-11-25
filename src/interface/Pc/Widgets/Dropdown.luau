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
local _rowApis = setmetatable({}, { __mode = "k" })

local moduleGenv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}
moduleGenv.GDH_DropdownRowApis = _rowApis

local _dropdowns = setmetatable({}, { __mode = "k" })

export type DropdownConfig = {
    Label: string?,
    Options: { string },
    Default: number?,
    Width: number?,
    LayoutOrder: number?,
    Callback: ((number, string) -> ())?,
}

_dropdowns = _dropdowns or setmetatable({}, { __mode = "k" })

local function Dropdown(config: DropdownConfig): Frame
    init()

    local options = config.Options or {}
    local value = math.clamp(config.Default or 1, 1, math.max(1, #options))

    local row = Instance.new("Frame")
    row.Name = "Dropdown" .. (config.Label or "")
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, Theme.Layout.RowHeight)
    row.LayoutOrder = config.LayoutOrder or 0

    local boxH = Theme.Layout.ComboHeight
    local labelReserve = 0
    if config.Label and config.Label ~= "" then
        labelReserve = 4 + measureTextWidth(config.Label, Theme.Font.Small)
    end
    local box = Instance.new("TextButton")
    box.Name = "ValueBox"
    box.Text = ""
    box.AutoButtonColor = false

    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Position = UDim2.fromOffset(0, math.floor((Theme.Layout.RowHeight - boxH) / 2 + 0.5))

    box.Size = UDim2.new(1, -labelReserve, 0, boxH)
    box.Parent = row

    local background = Instance.new("Frame")
    background.Name = "Background"
    background.BackgroundColor3 = Theme.Colors.ComboBG
    background.BackgroundTransparency = 0
    background.BorderSizePixel = 0
    background.Size = UDim2.fromScale(1, 1)
    background.ZIndex = 1
    local backgroundCorner = Instance.new("UICorner")
    backgroundCorner.CornerRadius = UDim.new(0, Theme.Layout.DroplistCorner)
    backgroundCorner.Parent = background
    background.Parent = box

    local arrow = Instance.new("ImageLabel")
    arrow.Name = "Arrow"
    arrow.BackgroundTransparency = 1
    arrow.BorderSizePixel = 0

    arrow.AnchorPoint = Vector2.new(1, 0.5)
    arrow.Position = UDim2.new(1, -6, 0.5, 0)
    arrow.Size = UDim2.new(0, 11, 0, 11)
    arrow.Image = Theme.Colors.DroplistArrow
    arrow.ZIndex = 2
    arrow.Parent = background

   	local valueText = Instance.new("TextLabel")
	valueText.Name = "Value"
	valueText.BackgroundTransparency = 1
	valueText.BorderSizePixel = 0
	valueText.Position = UDim2.fromOffset(6, 0)
	valueText.Size = UDim2.new(1, -22, 1, 0)
	valueText.FontFace = Theme.GetFontFace()
	valueText.Text = options[value] or ""
	valueText.TextColor3 = Theme.Colors.TextPrimary
	valueText.TextSize = 12
	valueText.TextXAlignment = Enum.TextXAlignment.Left
	valueText.TextYAlignment = Enum.TextYAlignment.Center
	valueText.TextTruncate = Enum.TextTruncate.AtEnd
	valueText.ZIndex = 3
	valueText.Parent = box

    if config.Label and config.Label ~= "" then
        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.BackgroundTransparency = 1
        label.BorderSizePixel = 0
        label.AnchorPoint = Vector2.new(1, 0)
        label.Position = UDim2.new(1, 0, 0, 3)
        label.Size = UDim2.fromOffset(math.max(0, labelReserve - 4), 15)
        label.FontFace = Theme.GetFontFace()
        label.Text = config.Label
        label.TextColor3 = Theme.Colors.TextSecondary
        label.TextSize = Theme.Font.Small
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = row
    end

    local hovering = false
    local function setBoxFeedback(state: string)
        if state == "held" then
            background.BackgroundColor3 = Theme.Colors.ComboBGActive
        elseif state == "hover" then
            background.BackgroundColor3 = Theme.Colors.ComboBGHover
        else
            background.BackgroundColor3 = Theme.Colors.ComboBG
        end
    end

    local ITEM_H = Theme.Layout.ComboItemHeight

    local ITEM_GAP = 0
    local padY = Theme.Layout.DroplistPopupPadY
    local popupH = padY * 2 + #options * ITEM_H
    local popup = Instance.new("Frame")
    popup.Name = "ComboPopup"
    popup.BackgroundColor3 = Theme.Colors.DroplistBG
    popup.BackgroundTransparency = 0
    popup.BorderSizePixel = 0

    popup.Position = UDim2.new(0, 0, 1, 0)
    popup.Size = UDim2.new(1, 0, 0, popupH)
    popup.Visible = false
    popup.ZIndex = 5
    popup.Parent = box

    local popupCorner = Instance.new("UICorner")
    popupCorner.CornerRadius = UDim.new(0, Theme.Layout.DroplistCorner)
    popupCorner.Parent = popup

    local popupStroke = Instance.new("UIStroke")
    popupStroke.Color = Theme.Colors.DroplistStroke
    popupStroke.Thickness = 1
    popupStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    popupStroke.Parent = popup
    local popupLayout = Instance.new("UIListLayout")
    popupLayout.Padding = UDim.new(0, ITEM_GAP)
    popupLayout.SortOrder = Enum.SortOrder.LayoutOrder
    popupLayout.Parent = popup

    local popupPad = Instance.new("UIPadding")
    popupPad.PaddingTop = UDim.new(0, padY)
    popupPad.PaddingBottom = UDim.new(0, padY)
    popupPad.Parent = popup

    local itemButtons: { TextButton } = {}
    local hoveredIdx, pressedIdx = {}, {}

    local function styleItem(i: number)
        local btn = itemButtons[i]
        if not btn then
            return
        end
        if i == value or pressedIdx[i] then
            btn.BackgroundColor3 = Theme.Colors.PopupSelected
            btn.BackgroundTransparency = 0
        elseif hoveredIdx[i] then
            btn.BackgroundColor3 = Theme.Colors.PopupRowHover
            btn.BackgroundTransparency = 0
        else
            btn.BackgroundTransparency = 1
        end
    end

    local function refreshItems()
        for i, btn in itemButtons do
            btn:SetAttribute("Index", i)
            styleItem(i)
        end
    end

    for i, optionText in options do
        local item = Instance.new("TextButton")
        item.Name = "Item" .. i
        item.Text = ""
        item.AutoButtonColor = false
        item.BackgroundTransparency = 1
        item.BackgroundColor3 = Theme.Colors.PopupRowHover
        item.BorderSizePixel = 0
        item.Size = UDim2.new(1, 0, 0, ITEM_H)
        item.LayoutOrder = i

        item.Parent = popup

        local itemText = Instance.new("TextLabel")
        itemText.Name = "Text"
        itemText.BackgroundTransparency = 1
        itemText.BorderSizePixel = 0
        itemText.Size = UDim2.new(1, -10, 1, 0)
        itemText.Position = UDim2.fromOffset(5, 0)
        itemText.FontFace = Theme.GetFontFace()
        itemText.Text = optionText
        itemText.TextColor3 = Theme.Colors.TextPrimary
        itemText.TextSize = 12
        itemText.TextXAlignment = Enum.TextXAlignment.Left
        itemText.TextYAlignment = Enum.TextYAlignment.Center
        itemText.TextTruncate = Enum.TextTruncate.AtEnd
        itemText.Parent = item

        item.MouseEnter:Connect(function()
            hoveredIdx[i] = true
            styleItem(i)
        end)
        item.MouseLeave:Connect(function()
            hoveredIdx[i] = nil
            pressedIdx[i] = nil
            styleItem(i)
        end)
        item.MouseButton1Down:Connect(function()
            pressedIdx[i] = true
            styleItem(i)
        end)
        item.MouseButton1Up:Connect(function()
            pressedIdx[i] = nil
            styleItem(i)
        end)

        table.insert(itemButtons, item)
    end

    local open = false
    local outsideConn: RBXScriptConnection? = nil
    local escConn: RBXScriptConnection? = nil
    local rowBaseZ = 1

    local function closePopup(_instant: boolean?)
        if not open then
            return
        end
        open = false
        if outsideConn then
            outsideConn:Disconnect()
            outsideConn = nil
        end
        if escConn then
            escConn:Disconnect()
            escConn = nil
        end
        popup.Visible = false
        row.ZIndex = rowBaseZ
    end

    local function openPopup()
        if open then
            return
        end

        for otherBox, otherApi in _dropdowns do
            if otherBox ~= box then
                (otherApi :: { Close: () -> () }).Close()
            end
        end
        open = true
        refreshItems()

        local clipTop, clipBottom

        local anc = box.Parent
        while anc ~= nil do
            local clips = false
            if anc:IsA("GuiObject") then
                clips = anc.ClipsDescendants or anc:IsA("ScrollingFrame")
            end
            if clips then
                local top = anc.AbsolutePosition.Y
                local bottom = top + anc.AbsoluteSize.Y
                if clipBottom == nil or bottom < clipBottom then
                    clipBottom = bottom
                end
                if clipTop == nil or top > clipTop then
                    clipTop = top
                end
            end
            anc = anc.Parent
        end
        local boxTop = box.AbsolutePosition.Y
        local boxBot = boxTop + box.AbsoluteSize.Y
        local belowFits = clipBottom == nil or (boxBot + 2 + popupH <= clipBottom)
        local aboveFits = clipTop == nil or (clipTop + 2 <= boxTop - popupH)
        if not belowFits and aboveFits then
            popup.Position = UDim2.new(0, 0, 0, -popupH)
        else
            popup.Position = UDim2.new(0, 0, 1, 0)
        end

        rowBaseZ = row.ZIndex
        row.ZIndex = 10

        popup.Visible = true

        outsideConn = UserInputService.InputBegan:Connect(function(input: InputObject)
            local isMain = input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            if not isMain then
                return
            end
            local mouse = UserInputService:GetMouseLocation()
                - game:GetService("GuiService"):GetGuiInset()
            local function hit(px: number, py: number, sx: number, sy: number): boolean
                return mouse.X >= px and mouse.X <= px + sx
                    and mouse.Y >= py and mouse.Y <= py + sy
            end
            local overBox = hit(box.AbsolutePosition.X, box.AbsolutePosition.Y,
                box.AbsoluteSize.X, box.AbsoluteSize.Y)
            local overList = hit(popup.AbsolutePosition.X, popup.AbsolutePosition.Y,
                popup.AbsoluteSize.X, popup.AbsoluteSize.Y)
            if not overBox and not overList then
                closePopup()
            end
        end)

        escConn = UserInputService.InputBegan:Connect(function(input: InputObject)
            if input.KeyCode == Enum.KeyCode.Escape then
                closePopup()
            end
        end)
    end

    local function setValue(i: number, fire: boolean)
        value = math.clamp(i, 1, math.max(1, #options))
        valueText.Text = options[value] or ""
        row:SetAttribute("Value", value)
        row:SetAttribute("ValueText", options[value] or "")
        refreshItems()
        if fire and config.Callback then
            config.Callback(value, options[value] or "")
        end
    end

    local api = { Close = closePopup }
    function api.SetValue(i: number)
        setValue(i, true)
    end
    function api.GetValue(): number
        return value
    end

    local function togglePopup()
        if open then
            closePopup()
        else
            openPopup()
        end
    end

    box.Activated:Connect(togglePopup)

    box.MouseEnter:Connect(function()
        hovering = true
        setBoxFeedback("hover")
    end)
    box.MouseLeave:Connect(function()
        hovering = false
        setBoxFeedback("idle")
    end)
    box.MouseButton1Down:Connect(function()
        setBoxFeedback("held")
    end)
    box.MouseButton1Up:Connect(function()
        setBoxFeedback(if hovering then "hover" else "idle")
    end)

    for i, item in itemButtons do
        item.Activated:Connect(function()
            setValue(i, true)
            closePopup()
        end)
    end

    row.Destroying:Connect(function()
        closePopup(true)
        _dropdowns[box] = nil
    end)
    _dropdowns[box] = api

    row:SetAttribute("Value", value)
    row:SetAttribute("ValueText", options[value] or "")
    row:SetAttribute("WidgetType", "Dropdown")
    _rowApis[row] = api
    return row
end

local function CloseAllDropdowns()

    if not _dropdowns then
        return
    end
    for _, api in _dropdowns do
        if api ~= nil then
            pcall(function()
                (api :: { Close: (boolean?) -> () }).Close(true)
            end)
        end
    end
end

return {
    Dropdown = Dropdown,
    CloseAllDropdowns = CloseAllDropdowns,
}
