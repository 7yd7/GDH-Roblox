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
local Animate = nil
local PressFlow = nil

local function init()
    if not Theme then
        Theme = importMobileModule("Theme")
    end
    if not Animate then
        Animate = importMobileModule("Animate")
    end
    if not PressFlow then
        PressFlow = importMobileModule("PressFlow")
    end
end

export type ButtonSpec = {
    Text: any?,
    Fire: any?,
}

export type ButtonRowConfig = {
    Parent: Instance,
    Buttons: { any }?,
    FullWidth: boolean?,
}

local function ButtonRow(config: ButtonRowConfig): Frame
    init()

    local layout = Theme.Layout
    local colors = Theme.Colors

    local row = Instance.new("Frame")
    row.Name = "Buttons"
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, layout.RowH)
    row.Parent = config.Parent

    local gap = layout.CellGap
    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Horizontal
    list.Padding = UDim.new(0, gap)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = row

    local buttons: { any } = {}
    if typeof(config.Buttons) == "table" then
        for _, item in config.Buttons :: { any } do
            table.insert(buttons, item)
        end
    end
    local count = math.max(1, #buttons)
    local centered = count == 1 and config.FullWidth ~= true
    local width = if centered
        then layout.CellW
        else math.floor((layout.ListW - gap * (count - 1)) / count + 0.5)
    if centered then
        list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    end

    local index = 0
    for _, item in buttons do
        index += 1
        local text = if typeof(item) == "table" then tostring(item.Text or "") else ""
        local fire = if typeof(item) == "table" and typeof(item.Fire) == "function"
            then item.Fire :: (() -> ())
            else nil

        local slot = Instance.new("Frame")
        slot.Name = "Slot" .. index
        slot.BackgroundTransparency = 1
        slot.BorderSizePixel = 0
        slot.Size = UDim2.fromOffset(width, layout.RowH)
        slot.LayoutOrder = index
        slot.Parent = row

        local btn = Instance.new("TextButton")
        btn.Name = "Button" .. index
        btn.AutoButtonColor = false
        btn.BackgroundColor3 = colors.TabInactive
        btn.BorderSizePixel = 0
        btn.AnchorPoint = Vector2.new(0.5, 0.5)
        btn.Position = UDim2.fromScale(0.5, 0.5)
        btn.Size = UDim2.fromScale(1, 1)
        btn.FontFace = Theme.GetFace()
        btn.Text = text
        btn.TextColor3 = colors.TabInactiveText
        btn.TextSize = layout.TabTextSize
        btn.TextTruncate = Enum.TextTruncate.AtEnd
        btn.Parent = slot

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, layout.TabCorner)
        corner.Parent = btn

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 2
        stroke.Color = colors.MenuStroke
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = btn
        pcall(function()
            stroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
        end)

        local feedback = Animate.HoldFeedback(btn, btn, {
            Grow = 1.15,
            GrowTime = 0.15,
            ReleaseTime = 0.6,
            ReleaseStyle = Enum.EasingStyle.Elastic,
        })

        local target = {
            Node = btn,
            Activate = function()
                if typeof(fire) == "function" then
                    pcall(fire)
                end
            end,
            PressIn = feedback.Press,
            PressOut = feedback.Reverse,
            Release = feedback.Release,
        }
        PressFlow.Register(target)

        btn.InputBegan:Connect(function(input: InputObject)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                PressFlow.Begin(target, input)
            end
        end)

        btn.Activated:Connect(function()
            if typeof(fire) == "function" then
                pcall(fire)
            end
        end)
    end

    return row
end

return ButtonRow
