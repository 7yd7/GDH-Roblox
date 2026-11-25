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

local UserInputService = game:GetService("UserInputService")

local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

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

local activeClose: any? = nil

export type DropdownConfig = {
    Parent: Instance,
    Row: any?,
    Options: any?,
    Overlay: any?,
    Fit: any?,
}

local function DropdownCell(config: DropdownConfig): Frame
    init()

    local layout = Theme.Layout
    local colors = Theme.Colors

    local options: { string } = {}
    if typeof(config.Options) == "table" then
        for _, option in config.Options :: { any } do
            table.insert(options, tostring(option))
        end
    end

    local pcApi = nil
    local apis = genv.GDH_DropdownRowApis
    if typeof(apis) == "table" and typeof(config.Row) == "Instance" then
        local api = apis[config.Row :: Instance]
        if typeof(api) == "table" then
            pcApi = api
        end
    end

    local value = 1
    if typeof(pcApi) == "table" and typeof(pcApi.GetValue) == "function" then
        local ok, current = pcall(pcApi.GetValue)
        if ok and typeof(current) == "number" then
            value = current
        end
    end
    if (value < 1 or value > #options) and typeof(config.Row) == "Instance" then
        local attr = (config.Row :: Instance):GetAttribute("Value")
        if typeof(attr) == "number" then
            value = attr
        end
    end
    value = math.clamp(value, 1, math.max(1, #options))

    local row = Instance.new("Frame")
    row.Name = "Dropdown"
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, layout.RowH)
    row.Parent = config.Parent

    local box = Instance.new("TextButton")
    box.Name = "ValueBox"
    box.Text = ""
    box.AutoButtonColor = false
    box.BackgroundColor3 = colors.SwitchTrackOff
    box.BorderSizePixel = 0
    box.AnchorPoint = Vector2.new(0, 0.5)
    box.Position = UDim2.new(0, 0, 0.5, 0)
    box.Size = UDim2.new(1, 0, 0, layout.BoxH)
    box.Parent = row

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, layout.BoxCorner)
    boxCorner.Parent = box

    local valueText = Instance.new("TextLabel")
    valueText.Name = "Value"
    valueText.BackgroundTransparency = 1
    valueText.BorderSizePixel = 0
    valueText.Position = UDim2.fromOffset(14, 0)
    valueText.Size = UDim2.new(1, -52, 1, 0)
    valueText.FontFace = Theme.GetFace()
    valueText.TextSize = layout.LabelSize
    valueText.TextColor3 = colors.TextPrimary
    valueText.TextTruncate = Enum.TextTruncate.AtEnd
    valueText.TextXAlignment = Enum.TextXAlignment.Left
    valueText.Parent = box
    FitText.fit(valueText, {
        Base = layout.LabelSize,
        Min = layout.LabelMinSize,
    })

    local arrow = Instance.new("TextLabel")
    arrow.Name = "Arrow"
    arrow.BackgroundTransparency = 1
    arrow.BorderSizePixel = 0
    arrow.AnchorPoint = Vector2.new(1, 0.5)
    arrow.Position = UDim2.new(1, -10, 0.5, 0)
    arrow.Size = UDim2.fromOffset(28, layout.BoxH)
    arrow.FontFace = Theme.GetFace()
    arrow.Text = "▾"
    arrow.TextColor3 = colors.TextPrimary
    arrow.TextSize = 24
    arrow.Parent = box

    local popup: Frame? = nil
    local outsideConn: RBXScriptConnection? = nil
    local menuConn: RBXScriptConnection? = nil

    local function closePopup()
        if outsideConn ~= nil then
            pcall(function()
                outsideConn:Disconnect()
            end)
            outsideConn = nil
        end
        local current = popup
        popup = nil
        if activeClose == closePopup then
            activeClose = nil
        end
        if current ~= nil then
            pcall(function()
                current:Destroy()
            end)
        end
    end

    local function setValue(i: number, fire: boolean)
        value = math.clamp(i, 1, math.max(1, #options))
        valueText.Text = options[value] or ""
        if fire and typeof(pcApi) == "table" and typeof(pcApi.SetValue) == "function" then
            pcall(pcApi.SetValue, value)
        end
    end

    local function hitRect(px: number, py: number, sx: number, sy: number, pos: Vector3): boolean
        return pos.X >= px and pos.X <= px + sx
            and pos.Y >= py and pos.Y <= py + sy
    end

    local function openPopup()
        if popup ~= nil then
            return
        end
        if typeof(activeClose) == "function" then
            pcall(activeClose :: any)
        end
        local menu = config.Overlay
        if typeof(menu) ~= "Instance" then
            return
        end
        local menuFrame = menu :: Frame
        local scale = 1
        local fit = config.Fit
        if typeof(fit) == "Instance" then
            local ok, s = pcall(function()
                return (fit :: any).Scale
            end)
            if ok and typeof(s) == "number" and s > 0 then
                scale = s
            end
        end

        local boxAbs = box.AbsolutePosition
        local menuAbs = menuFrame.AbsolutePosition
        local localX = (boxAbs.X - menuAbs.X) / scale
        local localY = (boxAbs.Y - menuAbs.Y) / scale
        local boxW = box.AbsoluteSize.X / scale
        local boxH = box.AbsoluteSize.Y / scale

        local itemH = layout.DropItemH
        local padY = 6
        local fullH = padY * 2 + #options * itemH
        local popupH = math.min(fullH, layout.DropMaxH)
        local menuH = menuFrame.AbsoluteSize.Y / scale

        local newY = localY + boxH + 4
        if newY + popupH > menuH then
            newY = localY - popupH - 4
        end
        if newY < 0 then
            newY = 0
        end

        local frame = Instance.new("Frame")
        frame.Name = "DropPopup"
        frame.BackgroundColor3 = colors.SidebarBG
        frame.BorderSizePixel = 0
        frame.Position = UDim2.fromOffset(localX, newY)
        frame.Size = UDim2.fromOffset(boxW, popupH)
        frame.ZIndex = 50
        frame.Parent = menuFrame

        local frameCorner = Instance.new("UICorner")
        frameCorner.CornerRadius = UDim.new(0, layout.BoxCorner)
        frameCorner.Parent = frame

        local frameStroke = Instance.new("UIStroke")
        frameStroke.Color = colors.MenuStroke
        frameStroke.Thickness = 2
        frameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        frameStroke.Parent = frame

        local scroll = Instance.new("ScrollingFrame")
        scroll.Name = "Items"
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.ScrollBarThickness = 0
        scroll.ScrollingDirection = Enum.ScrollingDirection.Y
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.CanvasSize = UDim2.fromScale(0, 0)
        scroll.ElasticBehavior = Enum.ElasticBehavior.Always
        scroll.ZIndex = 51
        scroll.Parent = frame

        local scrollLayout = Instance.new("UIListLayout")
        scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
        scrollLayout.Parent = scroll

        local index = 0
        for _, optionText in options do
            index += 1
            local selected = index == value
            local item = Instance.new("TextButton")
            item.Name = "Item" .. index
            item.Text = ""
            item.AutoButtonColor = false
            item.BorderSizePixel = 0
            item.Size = UDim2.new(1, 0, 0, itemH)
            item.LayoutOrder = index
            item.ZIndex = 52
            item.BackgroundColor3 = colors.TabActive
            item.BackgroundTransparency = if selected then 0.25 else 1
            item.Parent = scroll

            local itemText = Instance.new("TextLabel")
            itemText.Name = "Text"
            itemText.BackgroundTransparency = 1
            itemText.BorderSizePixel = 0
            itemText.Position = UDim2.fromOffset(14, 0)
            itemText.Size = UDim2.new(1, -24, 1, 0)
            itemText.FontFace = Theme.GetFace()
            itemText.Text = optionText
            itemText.TextColor3 = if selected then colors.TabActiveText else colors.TextPrimary
            itemText.TextSize = layout.LabelSize
            itemText.TextTruncate = Enum.TextTruncate.AtEnd
            itemText.TextXAlignment = Enum.TextXAlignment.Left
            itemText.ZIndex = 53
            itemText.Parent = item
            FitText.fit(itemText, {
                Base = layout.LabelSize,
                Min = layout.LabelMinSize,
            })

            local itemIndex = index
            item.Activated:Connect(function()
                setValue(itemIndex, true)
                closePopup()
            end)
        end

        popup = frame
        activeClose = closePopup

        outsideConn = UserInputService.InputBegan:Connect(function(input: InputObject)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch
            then
                return
            end
            local current = popup
            if current == nil then
                return
            end
            local overBox = hitRect(
                box.AbsolutePosition.X, box.AbsolutePosition.Y,
                box.AbsoluteSize.X, box.AbsoluteSize.Y, input.Position)
            local overList = hitRect(
                current.AbsolutePosition.X, current.AbsolutePosition.Y,
                current.AbsoluteSize.X, current.AbsoluteSize.Y, input.Position)
            if not overBox and not overList then
                closePopup()
            end
        end)
    end

    box.Activated:Connect(function()
        if popup ~= nil then
            closePopup()
        else
            openPopup()
        end
    end)

    local menu = config.Overlay
    if typeof(menu) == "Instance" then
        menuConn = (menu :: Instance):GetPropertyChangedSignal("Visible"):Connect(function()
            if (menu :: Instance).Visible == false then
                closePopup()
            end
        end)
    end

    row.Destroying:Connect(function()
        if menuConn ~= nil then
            pcall(function()
                menuConn:Disconnect()
            end)
            menuConn = nil
        end
        closePopup()
    end)

    valueText.Text = options[value] or ""

    return row
end

return DropdownCell
