local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

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

local ButtonWidget = importWidget("Button")
local SeparatorWidget = importWidget("Separator")
local measureTextWidth = importWidget("Measure")

local ModalList = {}

local function modalOpenDelta(delta: number)
    local genv = (typeof(getgenv) == "function" and getgenv())
        or (typeof(_G) == "table" and _G)
        or {}
    local count = genv.GDH_MODAL_OPEN
    if typeof(count) ~= "number" then
        count = 0
    end
    count += delta
    if count < 0 then
        count = 0
    end
    genv.GDH_MODAL_OPEN = count
end

export type ModalListConfig = {
    Title: string?,
    ListWidth: number?,
    ListHeight: number?,
    Body: string?,
    BodyWidth: number?,
    FooterButtons: { string }?,
    FooterLayout: string?,
    GlowSpread: number?,
    DimTransparency: number?,
    OnButton: ((string) -> ())?,
    Parent: Instance?,
}

function ModalList.create(config: ModalListConfig): {
    Root: Frame,
    List: ScrollingFrame?,
    Body: TextLabel?,
    SetBody: (string) -> (),
    ShowCentered: () -> (),
    Close: () -> (),
    IsVisible: () -> boolean,
}
    init()

    local titleText = config.Title or "Modal List"
    local bodyMode = config.Body ~= nil
    local glowSpread = config.GlowSpread or Theme.Layout.PopupGlowSpread
    local footers = config.FooterButtons or { "Close" }
    local footerLayout = config.FooterLayout or "Stack"

    local function measureBodyContentWidth(text: string): number
        local maxLine = 0
        for line in string.gmatch(text, "[^\n]+") do
            local w = measureTextWidth(line, Theme.Font.Body)
            if w > maxLine then
                maxLine = w
            end
        end
        maxLine += 2
        local titleWidth = measureTextWidth(titleText, Theme.Font.Title)
        if titleWidth + 8 > maxLine then
            maxLine = titleWidth + 8
        end
        return maxLine
    end

    local listWidth: number
    if bodyMode then
        local bodyWidth: number? = config.BodyWidth
        if bodyWidth == nil then
            bodyWidth = measureBodyContentWidth(config.Body :: string)
        end
        listWidth = math.floor(bodyWidth :: number)
    else
        listWidth = math.floor((config.ListWidth or 400) * Theme.ScreenScale)
    end
    local listHeight = math.floor((config.ListHeight or 500) * Theme.ScreenScale)
    local dimTarget = if config.DimTransparency ~= nil
        then math.clamp(config.DimTransparency, 0, 1)
        else 0.4
    local zIndex = 50

    local root = Instance.new("Frame")
    root.Name = titleText
    root.Active = true
    root.BackgroundTransparency = 1
    root.BorderSizePixel = 0
    root.Size = UDim2.fromOffset(listWidth + Theme.Layout.ListPaddingX * 2, 0)
    root.AutomaticSize = Enum.AutomaticSize.Y
    root.ClipsDescendants = false
    root.Visible = false
    root.ZIndex = zIndex
    root:SetAttribute("GDHWindow", true)

    local down = Instance.new("Frame")
    down.Name = "down"
    down.Active = true
    down.BackgroundTransparency = 1
    down.BorderSizePixel = 0
    down.ClipsDescendants = true
    down.Position = UDim2.fromOffset(0, Theme.Layout.HeaderHeight + 1)
    down.Size = UDim2.new(1, 0, 0, 0)
    down.AutomaticSize = Enum.AutomaticSize.Y

    local background = Instance.new("ImageLabel")
    background.Name = "Background"
    background.Active = true
    background.BackgroundTransparency = 1
    background.BorderSizePixel = 0
    background.Size = UDim2.fromScale(1, 1)
    background.Image = Theme.Colors.PanelBG
    background.ImageTransparency = 0.04
    background.ScaleType = Enum.ScaleType.Slice
    background.SliceCenter = Rect.new(16, 16, 197, 227)
    background.ZIndex = zIndex
    background.Parent = down

    down.ZIndex = zIndex
    down.Parent = root

    local content = Instance.new("Frame")
    content.Name = "List"
    content.Position = UDim2.new(0, Theme.Layout.ListPaddingX, 0, Theme.Layout.ListPaddingY)
    content.Size = UDim2.new(1, -(Theme.Layout.ListPaddingX * 2), 0, 0)
    content.AutomaticSize = Enum.AutomaticSize.Y
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ZIndex = zIndex + 1
    content.Parent = down

    local bottomPad = Instance.new("UIPadding")
    bottomPad.PaddingBottom = UDim.new(0, Theme.Layout.ListPaddingY)
    bottomPad.Parent = content

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Padding = UDim.new(0, Theme.Layout.RowPadding)
    contentLayout.Parent = content

    local scroll: ScrollingFrame? = nil
    local bodyLabel: TextLabel? = nil
    if bodyMode then
        local label = Instance.new("TextLabel")
        label.Name = "Body"
        label.BackgroundTransparency = 1
        label.BorderSizePixel = 0
        label.FontFace = Theme.GetFontFace()
        label.Text = config.Body :: string
        label.TextColor3 = Theme.Colors.TextPrimary
        label.TextSize = Theme.Font.Body
        label.TextTransparency = Theme.Colors.WindowBGTransparent
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Top
        label.TextWrapped = true
        label.Size = UDim2.new(1, 0, 0, 0)
        label.AutomaticSize = Enum.AutomaticSize.Y
        label.LayoutOrder = 1
        label.ZIndex = zIndex + 2
        label.Parent = content
        bodyLabel = label
    else
        scroll = Instance.new("ScrollingFrame")
        local s = scroll :: ScrollingFrame
        s.Name = "Items"
        s.BackgroundTransparency = 1
        s.BorderSizePixel = 0
        s.Size = UDim2.new(1, 0, 0, listHeight)
        s.CanvasSize = UDim2.fromScale(0, 0)
        s.AutomaticCanvasSize = Enum.AutomaticSize.Y
        s.ScrollBarThickness = Theme.Layout.ScrollBarWidth
        s.ScrollBarImageColor3 = Theme.Colors.ResizeHandle
        s.ScrollBarImageTransparency = 0.3
        s.LayoutOrder = 1
        s.ZIndex = zIndex + 2
        s.Parent = content

        local scrollLayout = Instance.new("UIListLayout")
        scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
        scrollLayout.Padding = UDim.new(0, Theme.Layout.RowPadding)
        scrollLayout.Parent = s
    end

    local top = Instance.new("Frame")
    top.Name = "Top"
    top.Active = true
    top.BackgroundTransparency = 1
    top.BorderSizePixel = 0
    top.Size = UDim2.new(1, 0, 0, Theme.Layout.HeaderHeight)
    top.ZIndex = zIndex + 2
    top.Parent = root

    local headerBG = Instance.new("ImageLabel")
    headerBG.Name = "Background"
    headerBG.Active = true
    headerBG.BackgroundTransparency = 1
    headerBG.BorderSizePixel = 0
    headerBG.Size = UDim2.fromScale(1, 1)
    headerBG.Image = Theme.Colors.HeaderBGImage
    headerBG.ImageTransparency = 0
    headerBG.ScaleType = Enum.ScaleType.Slice
    headerBG.SliceCenter = Rect.new(8, 0, 205, 21)
    headerBG.ZIndex = zIndex + 2
    headerBG.Parent = top

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Active = false
    titleLabel.BackgroundTransparency = 1
    titleLabel.BorderSizePixel = 0
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.Size = UDim2.new(1, 0, 1, -2)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    titleLabel.FontFace = Theme.GetFontFace()
    titleLabel.Text = titleText
    titleLabel.TextColor3 = Theme.Colors.TextPrimary
    titleLabel.TextSize = Theme.Font.Title
    titleLabel.TextTransparency = Theme.Colors.WindowBGTransparent
    titleLabel.TextWrapped = true
    titleLabel.TextYAlignment = Enum.TextYAlignment.Center
    titleLabel.ZIndex = zIndex + 4
    titleLabel.Parent = top

    local glow: ImageLabel? = nil
    if Theme.Colors.PopupGlow ~= "" then
        local glowInstance = Instance.new("ImageLabel")
        glowInstance.Name = "GDHGlow"
        glowInstance.BackgroundTransparency = 1
        glowInstance.BorderSizePixel = 0
        glowInstance.Image = Theme.Colors.PopupGlow
        glowInstance.ImageColor3 = Theme.Colors.PopupGlowColor
        glowInstance.ImageTransparency = 1 - Theme.Colors.PopupGlowEdge
        glowInstance.ScaleType = Enum.ScaleType.Slice
        glowInstance.SliceCenter = Rect.new(264, 264, 268, 268)
        glowInstance.SliceScale = math.max(0.05, glowSpread / 250)
        glowInstance.Visible = false
        glow = glowInstance
    end

    local backdrop = Instance.new("Frame")
    backdrop.Name = "ModalDim"
    backdrop.Active = true
    backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
    backdrop.BackgroundTransparency = 1
    backdrop.BorderSizePixel = 0
    backdrop.Size = UDim2.fromScale(1, 1)
    backdrop.Visible = false
    backdrop.ZIndex = math.max(1, zIndex - 2)

    local glowConn: RBXScriptConnection? = nil
    local centerConn: RBXScriptConnection? = nil
    local backdropTweenId: string? = nil
    local dragConns: { RBXScriptConnection } = {}

    local function stopGlowLoop()
        if glowConn ~= nil then
            glowConn:Disconnect()
            glowConn = nil
        end
        local g = glow
        if g ~= nil then
            g.Visible = false
        end
    end

    local function fadeBackdrop(target: number, duration: number)
        local b = backdrop
        if b == nil then
            return
        end
        if backdropTweenId ~= nil then
            Animate.CancelTween(backdropTweenId)
            backdropTweenId = nil
        end
        local startTransparency = b.BackgroundTransparency
        backdropTweenId = Animate.Tween({
            Duration = duration,
            EasingFunction = Animate.Easing.EaseOutQuad,
            OnStep = function(t: number)
                b.BackgroundTransparency = Animate.Lerp(startTransparency, target, t)
            end,
            OnComplete = function()
                backdropTweenId = nil
                if target >= 1 then
                    b.Visible = false
                end
            end,
        })
    end

    local function startGlowLoop()
        local g = glow
        if g == nil or glowConn ~= nil then
            return
        end
        g.Visible = true
        local function update()
            local gNow = glow
            if gNow == nil or not root.Visible or root.Parent == nil then
                stopGlowLoop()
                return
            end
            if gNow.Parent ~= root.Parent then
                gNow.Parent = root.Parent
            end
            gNow.ZIndex = math.max(1, root.ZIndex - 1)
            local b = backdrop
            if b ~= nil then
                b.ZIndex = math.max(1, root.ZIndex - 2)
            end
            local spreadScreen = glowSpread
            gNow.SliceScale = math.max(0.05, spreadScreen / 250)
            gNow.Size = UDim2.fromOffset(
                root.AbsoluteSize.X + spreadScreen * 2,
                root.AbsoluteSize.Y + spreadScreen * 2)
            gNow.Position = UDim2.fromOffset(
                root.Position.X.Offset - spreadScreen,
                root.Position.Y.Offset - spreadScreen)
        end
        glowConn = RunService.RenderStepped:Connect(update)
        update()
    end

    local function raise()
        local parent = root.Parent
        if parent == nil then
            return
        end
        local maxZ = 0
        for _, sibling in parent:GetChildren() do
            if sibling ~= root and sibling ~= glow and sibling ~= backdrop
                and sibling:IsA("GuiObject")
            then
                if sibling.ZIndex > maxZ then
                    maxZ = sibling.ZIndex
                end
            end
        end
        root.ZIndex = math.max(root.ZIndex, maxZ + 1)
    end

    local function center()
        local parent = root.Parent
        if parent == nil or not parent:IsA("GuiBase2d") then
            return
        end
        local vp = parent.AbsoluteSize
        local size = root.AbsoluteSize
        local x = math.floor((vp.X - size.X) / 2 + 0.5)
        local y = math.floor((vp.Y - size.Y) / 2 + 0.5)
        root.Position = UDim2.fromOffset(x, y)
    end

    local function ShowCentered()
        if not root.Visible then
            modalOpenDelta(1)
        end
        raise()
        center()
        root.Visible = true
        local b = backdrop
        if b ~= nil then
            b.ZIndex = math.max(1, root.ZIndex - 2)
            b.Visible = true
            fadeBackdrop(dimTarget, 0.2)
        end
        startGlowLoop()
        if centerConn ~= nil then
            centerConn:Disconnect()
            centerConn = nil
        end
        centerConn = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            if not root.Visible then
                return
            end
            center()
        end)
    end

    local function Close()
        if root.Visible then
            modalOpenDelta(-1)
        end
        root.Visible = false
        stopGlowLoop()
        fadeBackdrop(1, 0.15)
    end

    local function IsVisible(): boolean
        return root.Visible
    end

    local function SetBody(text: string)
        local label = bodyLabel
        if label == nil then
            return
        end
        label.Text = text
        if config.BodyWidth == nil and root.Parent ~= nil then
            local contentWidth = measureBodyContentWidth(text)
            root.Size = UDim2.fromOffset(
                math.floor(contentWidth) + Theme.Layout.ListPaddingX * 2, 0)
        end
    end

    do
        local dragging = false
        local dragStart: Vector2
        local startPos: UDim2

        local function host(): BasePlayerGui?
            local node: Instance? = root
            while node do
                if node:IsA("BasePlayerGui") then
                    return node :: BasePlayerGui
                end
                node = node.Parent
            end
            return nil
        end

        local function pointInGuiSpace(input: InputObject): Vector2
            if input.UserInputType == Enum.UserInputType.Touch then
                return input.Position
            end
            local inset = GuiService:GetGuiInset()
            local loc = UserInputService:GetMouseLocation()
            return Vector2.new(loc.X - inset.X, loc.Y - inset.Y)
        end

        local function isTopmostUnderPointer(pt: Vector2): boolean
            local hostGui = host()
            if hostGui == nil then
                return true
            end
            local okT, under = pcall(function()
                return hostGui:GetGuiObjectsAtPosition(pt.X, pt.Y)
            end)
            if not okT or not under or #under == 0 then
                return true
            end
            local bestZ, bestRoot = nil, nil
            for _, obj in (under :: { Instance }) do
                local node: Instance? = obj
                while node do
                    if node:GetAttribute("GDHWindow") then
                        local z = node.ZIndex
                        if bestZ == nil or z > bestZ then
                            bestZ, bestRoot = z, node
                        end
                        break
                    end
                    node = node.Parent
                end
            end
            return bestRoot == nil or bestRoot == root
        end

        local function beginDrag(input: InputObject)
            dragging = true
            dragStart = input.Position
            startPos = root.Position
        end

        local focusConn = root.InputBegan:Connect(function(input: InputObject)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch
            then
                return
            end
            local okP, ptF = pcall(function()
                return pointInGuiSpace(input)
            end)
            if not okP or typeof(ptF) ~= "Vector2" then
                return
            end
            if isTopmostUnderPointer(ptF) then
                raise()
            end
        end)
        table.insert(dragConns, focusConn)

        local topConn = top.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or
               input.UserInputType == Enum.UserInputType.Touch then
                local okD, ptD = pcall(function()
                    return pointInGuiSpace(input)
                end)
                if okD and typeof(ptD) == "Vector2"
                    and not isTopmostUnderPointer(ptD) then
                    return
                end
                beginDrag(input)
                raise()
            end
        end)
        table.insert(dragConns, topConn)

        local bodyConn = down.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and
               input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            local pt = pointInGuiSpace(input)
            local inX = pt.X - down.AbsolutePosition.X
            local scrollbarW = if scroll ~= nil
                then (scroll :: ScrollingFrame).ScrollBarThickness
                else 0
            if inX >= down.AbsoluteSize.X - (scrollbarW + 2) then
                return
            end
            local okH, under = pcall(function()
                return host():GetGuiObjectsAtPosition(pt.X, pt.Y)
            end)
            if okH and under then
                for _, obj in (under :: { Instance }) do
                    if (obj:IsDescendantOf(root) or obj == root)
                        and (obj:IsA("GuiButton") or obj:IsA("TextBox"))
                    then
                        return
                    end
                end
            end
            if not isTopmostUnderPointer(pt) then
                return
            end
            beginDrag(input)
            raise()
        end)
        table.insert(dragConns, bodyConn)

        local moveConn = UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
                             input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                root.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
        table.insert(dragConns, moveConn)

        local endConn = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or
               input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        table.insert(dragConns, endConn)
    end

    local footerOrder = 1
    if bodyMode then
        local sep = SeparatorWidget({ Height = 10, LayoutOrder = 2 })
        sep.Parent = content
        footerOrder = 2
    end

    if footerLayout == "Row" and #footers > 1 then
        footerOrder += 1
        local row = Instance.new("Frame")
        row.Name = "FooterRow"
        row.BackgroundTransparency = 1
        row.BorderSizePixel = 0
        row.Size = UDim2.new(1, 0, 0, Theme.Layout.ButtonHeight)
        row.LayoutOrder = footerOrder
        row.Parent = content

        local n = math.max(1, #footers)
        local gap = Theme.Layout.InlineGapX or 8
        local rowLayout = Instance.new("UIListLayout")
        rowLayout.FillDirection = Enum.FillDirection.Horizontal
        rowLayout.Padding = UDim.new(0, gap)
        rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
        rowLayout.Parent = row

        local pillOrder = 0
        for _, buttonName in footers do
            pillOrder += 1
            local pill = ButtonWidget({
                Text = buttonName,
                Width = UDim2.new(
                    1 / n, -(gap * (n - 1)) / n, 0, Theme.Layout.ButtonHeight),
                LayoutOrder = pillOrder,
                Callback = function()
                    if buttonName == "Close" then
                        Close()
                    end
                    if config.OnButton ~= nil then
                        config.OnButton(buttonName)
                    end
                end,
            })
            pill.Parent = row
        end
    else
        for _, buttonName in footers do
            footerOrder += 1
            local pill = ButtonWidget({
                Text = buttonName,
                LayoutOrder = footerOrder,
                Callback = function()
                    if buttonName == "Close" then
                        Close()
                    end
                    if config.OnButton ~= nil then
                        config.OnButton(buttonName)
                    end
                end,
            })
            pill.Parent = content
        end
    end

    if config.Parent ~= nil then
        root.Parent = config.Parent
        local g = glow
        if g ~= nil then
            g.Parent = config.Parent
        end
        backdrop.Parent = config.Parent
        local screenGui = root:FindFirstAncestorOfClass("ScreenGui")
        if screenGui ~= nil then
            local uiConn = screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
                if not screenGui.Enabled and root.Visible then
                    Close()
                end
            end)
            table.insert(dragConns, uiConn)
        end
        root.Destroying:Connect(function()
            if root.Visible then
                modalOpenDelta(-1)
            end
        end)
    end

    return {
        Root = root,
        List = scroll,
        Body = bodyLabel,
        SetBody = SetBody,
        ShowCentered = ShowCentered,
        Close = Close,
        IsVisible = IsVisible,
    }
end

return ModalList
