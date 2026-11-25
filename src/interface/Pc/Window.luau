local Theme = nil
local Animate = nil

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
    return require(script.Parent[name])
end

local Window = {}
Window.__index = Window

local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local function popupLog(message: string)
    local log = getgenv().GDH_POPUP_LOG
    if log == nil then
        log = {}
        getgenv().GDH_POPUP_LOG = log
    end
    table.insert(log, string.format("%.2f %s", os.clock(), message))
    if #log > 240 then
        table.remove(log, 1)
    end
end

local function textWidth(text: string, size: number): number
    local font = Theme.GetFontFace()
    local ok, bounds = pcall(function()
        return TextService:GetTextBoundsAsync(text, font, size, Vector2.new(10000, size * 2))
    end)
    if ok and bounds then
        return math.ceil(bounds.X)
    end
    return #text * math.floor(size * 0.58 + 0.5)
end

export type WindowConfig = {
    Title: string,
    Position: UDim2?,
    Size: UDim2?,
    MinSize: Vector2?,
    Visible: boolean?,
    Parent: Instance?,
    ZIndex: number?,

    Popup: boolean?,
    AutoHeight: boolean?,
    HideCloseButton: boolean?,
    FitWidth: boolean?,
}

function Window.new(config: WindowConfig)
    local self = setmetatable({}, Window)

    if not Theme then
        Theme = importPcModule("Theme")
    end
    if not Animate then
        Animate = importPcModule("Animate")
    end

    self._title = config.Title or "Window"
    self._collapsed = false
    self._popup = if config.Popup ~= nil then config.Popup else false
    self._openedAt = nil
    self._outsideIgnore = nil
    self._resizeHeld = false
    self._elements = {}
    self._connections = {}
    self._hideClose = config.HideCloseButton == true
    self._popupCenterConn = nil
    self._minSize = config.MinSize or Vector2.new(Theme.Layout.WindowMinWidth, Theme.Layout.WindowMinHeight)
    self._autoHeight = if config.AutoHeight ~= nil then config.AutoHeight else false
    self._autoHeightByConfig = self._autoHeight
    self._autoHeightSettled = false
    self._autoHeightSettleConn = nil
    self._onHeightChanged = nil
    self._fitWidth = config.FitWidth == true

    local zIndex = config.ZIndex or 1

    local root = Instance.new("Frame")
    root.Name = self._title
    root.Active = true
    root.BackgroundTransparency = 1
    root.BorderSizePixel = 0
    root.Position = config.Position or UDim2.fromOffset(157, 65)
    if self._popup then

        root.Size = UDim2.fromOffset(
            if config.Size ~= nil then config.Size.X.Offset else Theme.Layout.PopupWidth,
            0
        )
        root.AutomaticSize = Enum.AutomaticSize.Y
    else
        root.Size = config.Size or UDim2.fromOffset(
            Theme.Layout.WindowDefaultWidth, Theme.Layout.WindowDefaultHeight)
    end
    root.Visible = if config.Visible ~= nil then config.Visible else true
    root.ZIndex = zIndex

    self._initialPosition = root.Position
    self._initialSize = root.Size
    self._naturalSize = root.Size
    self._defaultSize = root.Size
    self._userMoved = false

    root:SetAttribute("GDHWindow", true)
    self.Root = root

    local down

    down = Instance.new("Frame")
    down.Name = "down"
    down.Active = true
    down.BackgroundTransparency = 1
    down.BorderSizePixel = 0
    down.ClipsDescendants = true
    down.Position = UDim2.fromOffset(
        0, (if self._popup then 0 else Theme.Layout.HeaderHeight + 1))
    if self._popup then
        down.Size = UDim2.new(1, 0, 0, 0)
        down.AutomaticSize = Enum.AutomaticSize.Y
        root.ClipsDescendants = false
    else
        down.Size = UDim2.new(1, 0, 1, -(Theme.Layout.HeaderHeight + 1))
        root.ClipsDescendants = true
    end

    if self._popup then
        local rect = Instance.new("Frame")
        rect.Name = "Rectangle 4"
        rect.Active = true
        rect.BackgroundColor3 = Theme.Colors.PopupWindowBG
        rect.BackgroundTransparency = 0
        rect.BorderSizePixel = 0
        rect.Size = UDim2.fromScale(1, 1)
        rect.ZIndex = zIndex
        local rectCorner = Instance.new("UICorner")
        rectCorner.CornerRadius = UDim.new(0, Theme.Layout.PopupCorner)
        rectCorner.Parent = rect
        local rectStroke = Instance.new("UIStroke")
        rectStroke.Thickness = Theme.Layout.PopupStrokeThickness
        rectStroke.Color = Theme.Colors.PopupWindowStroke
        rectStroke.Parent = rect
        rect.Parent = root
        self._background = rect
    else
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
        self._background = background
    end

    down.ZIndex = zIndex
    down.Parent = root
    self._down = down

    if not self._popup then
        local resizeHandle = Instance.new("Frame")
        resizeHandle.Name = "size"
        resizeHandle.Active = true
        resizeHandle.BackgroundColor3 = Theme.Colors.ResizeHandle
        resizeHandle.BackgroundTransparency = Theme.Colors.WindowBGTransparent
        resizeHandle.BorderSizePixel = 0
        resizeHandle.Position = UDim2.new(1, -30, 1, -7)
        resizeHandle.Rotation = Theme.Layout.ResizeRotation
        resizeHandle.Size = Theme.Layout.ResizeSize
        resizeHandle.ZIndex = zIndex + 5
        resizeHandle.Parent = down
        self._resizeHandle = resizeHandle
    end

    local list
    if self._popup then
        local content = Instance.new("Frame")
        content.Position = UDim2.new(0, Theme.Layout.ListPaddingX, 0, Theme.Layout.ListPaddingY)
        content.Size = UDim2.new(1, -(Theme.Layout.ListPaddingX * 2), 0, 0)
        content.AutomaticSize = Enum.AutomaticSize.Y

        local bottomPad = Instance.new("UIPadding")
        bottomPad.PaddingBottom = UDim.new(0, Theme.Layout.ListPaddingY)
        bottomPad.Parent = content
        list = content
    else
        local scroll = Instance.new("ScrollingFrame")
        scroll.Position = UDim2.fromOffset(Theme.Layout.ListPaddingX, Theme.Layout.ListPaddingY)
        scroll.Size = UDim2.new(1, -(Theme.Layout.ListPaddingX * 2), 1, -(Theme.Layout.ListPaddingY * 2))
        scroll.ScrollBarThickness = 0
        scroll.CanvasSize = UDim2.fromScale(0, 0)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.ScrollingEnabled = false
        list = scroll
    end
    list.Name = "List"
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.ZIndex = zIndex + 1
    list.Parent = self._down
    self._list = list

    if not self._popup then
        self:_setupSmoothScroll(list :: ScrollingFrame)
    end

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, Theme.Layout.RowPadding)
    listLayout.Parent = list
    self._listLayout = listLayout

    if not self._popup and self._autoHeight then
        self:_startAutoHeightSettle()
    end

    if not self._popup then
    local top = Instance.new("Frame")
    top.Name = "Top"
    top.Active = true
    top.BackgroundTransparency = 1
    top.BorderSizePixel = 0
    top.Size = UDim2.new(1, 0, 0, Theme.Layout.HeaderHeight)
    top.ZIndex = zIndex + 2
    top.Parent = root
    self._top = top

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
    self._headerBG = headerBG

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Active = false
    titleLabel.BackgroundTransparency = 1
    titleLabel.BorderSizePixel = 0

    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.Size = UDim2.new(1, 0, 1, -2)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    titleLabel.FontFace = Theme.GetFontFace()
    titleLabel.Text = self._title
    titleLabel.TextColor3 = Theme.Colors.TextPrimary
    titleLabel.TextSize = Theme.Font.Title
    titleLabel.TextTransparency = Theme.Colors.WindowBGTransparent
    titleLabel.TextWrapped = true
    titleLabel.TextYAlignment = Enum.TextYAlignment.Center
    titleLabel.ZIndex = zIndex + 4
    titleLabel.Parent = top
    self._titleLabel = titleLabel

    if not self._hideClose then
        local closeBtn = Instance.new("ImageButton")
        closeBtn.Name = "Close/Open"
        closeBtn.BackgroundTransparency = 1
        closeBtn.BorderSizePixel = 0
        closeBtn.AnchorPoint = Vector2.new(1, 0.5)
        closeBtn.Position = UDim2.new(1, -8, 0.5, 0)
        closeBtn.Size = Theme.Layout.CloseButtonSize
        closeBtn.Image = Theme.Colors.CloseIcon
        closeBtn.ZIndex = zIndex + 5
        closeBtn.Parent = top
        self._closeBtn = closeBtn

        local closeAspect = Instance.new("UIAspectRatioConstraint")
        closeAspect.AspectRatio = Theme.Layout.CloseAspect
        closeAspect.Parent = closeBtn
    end
    end

    self:_setupDrag()
    if self._popup then
        self:_setupOutsideClose()
    else
        self:_setupResize()
        self:_setupCollapse()
    end

    if config.Parent then
        root.Parent = config.Parent
    end

    return self
end

function Window:_setupDrag()
    local GuiService = game:GetService("GuiService")
    local UIS = game:GetService("UserInputService")

    local dragging = false
    local dragStart: Vector2
    local startPos: UDim2

    local function host(): BasePlayerGui?
        local node: Instance? = self.Root
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
        local loc = UIS:GetMouseLocation()
        return Vector2.new(loc.X - inset.X, loc.Y - inset.Y)
    end

    local function isTopmostUnderPointer(pt: Vector2): boolean
        local okT, under = pcall(function()
            return host():GetGuiObjectsAtPosition(pt.X, pt.Y)
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
        return bestRoot == nil or bestRoot == self.Root
    end

    local function raiseAboveAll()
        Window._zTopCounter = math.max(
            (Window._zTopCounter or 0), self.Root.ZIndex) + 1
        self.Root.ZIndex = Window._zTopCounter
    end

    local focusConn = self.Root.InputBegan:Connect(function(input: InputObject)
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
            raiseAboveAll()
        end
    end)
    table.insert(self._connections, focusConn)

    local function beginDrag(input: InputObject)
        dragging = true
        dragStart = input.Position
        startPos = self.Root.Position
    end

    if self._top then
    local conn1 = self._top.InputBegan:Connect(function(input)
        if self._resizeHeld then
            return
        end

        local okI, pt = pcall(function()
            return pointInGuiSpace(input)
        end)
        if okI and typeof(pt) == "Vector2" then
            local localX = pt.X - self._top.AbsolutePosition.X
            local localY = pt.Y - self._top.AbsolutePosition.Y
            if not self._popup and not self._collapsed
                and (localY < Theme.Layout.ResizeEdgeWidth
                    or (localX < Theme.Layout.ResizeCornerSize
                        and localY < Theme.Layout.ResizeCornerSize)) then
                return
            end
        end
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
            raiseAboveAll()
        end
    end)
    table.insert(self._connections, conn1)
    end

    local connBody = self._down.InputBegan:Connect(function(input)
        if self._resizeHeld then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and
           input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local pt = pointInGuiSpace(input)

        local inX = pt.X - self._down.AbsolutePosition.X
        local scrollbarW = if self._list:IsA("ScrollingFrame")
            then self._list.ScrollBarThickness
            else 0
        if inX >= self._down.AbsoluteSize.X - (scrollbarW + 2) then
            return
        end

        local okH, under = pcall(function()
            return host():GetGuiObjectsAtPosition(pt.X, pt.Y)
        end)
        if okH and under then
            for _, obj in (under :: { Instance }) do
                if self._resizeHandle and obj == self._resizeHandle then
                    return
                end
                if (obj:IsDescendantOf(self.Root) or obj == self.Root)
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
        raiseAboveAll()
    end)

    local conn2 = game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
                         input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            self.Root.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    local conn3 = game:GetService("UserInputService").InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                if self.Root.Position ~= startPos then
                    self._userMoved = true
                    self._initialPosition = self.Root.Position
                end
            end
        end
    end)

    table.insert(self._connections, conn1)
    table.insert(self._connections, connBody)
    table.insert(self._connections, conn2)
    table.insert(self._connections, conn3)
end

function Window:_setupResize()
    local UIS = game:GetService("UserInputService")
    local resizing = false
    local edgeMode = "RB"
    local startMouse: Vector2? = nil
    local startPos: Vector3? = nil
    local startSize: Vector2
    local startPosX, startPosY = 0, 0
    local startPosScaleX, startPosScaleY = 0, 0
    local baseZ = self.Root.ZIndex

    local function makeZone(name: string, pos: UDim2, size: UDim2): TextButton
        local zone = Instance.new("TextButton")
        zone.Name = name
        zone.Text = ""
        zone.BackgroundTransparency = 1
        zone.BorderSizePixel = 0
        zone.Position = pos
        zone.Size = size
        zone.ZIndex = baseZ + 1
        zone.Parent = self.Root
        return zone
    end

    local function makeTopZone(name: string, pos: UDim2, size: UDim2): TextButton
        local zone = Instance.new("TextButton")
        zone.Name = name
        zone.Text = ""
        zone.BackgroundTransparency = 1
        zone.BorderSizePixel = 0
        zone.Position = pos
        zone.Size = size
        zone.ZIndex = baseZ + 3
        zone.Parent = self._top
        return zone
    end

    local w = Theme.Layout.ResizeEdgeWidth
    local cs = Theme.Layout.ResizeCornerSize
    local rightEdge = makeZone("ResizeRight",
        UDim2.new(1, -w, 0, 0),
        UDim2.new(0, w, 1, 0))
    local leftEdge = makeZone("ResizeLeft",
        UDim2.fromOffset(0, 0),
        UDim2.new(0, w, 1, 0))
    local bottomEdge = makeZone("ResizeBottom",
        UDim2.new(0, w, 1, -w),
        UDim2.new(1, -w * 2, 0, w))
    local corner = makeZone("ResizeCornerBR",
        UDim2.new(1, -cs, 1, -cs),
        UDim2.new(0, cs, 0, cs))
    local blCorner = makeZone("ResizeCornerBL",
        UDim2.new(0, 0, 1, -cs),
        UDim2.new(0, cs, 0, cs))
    local topEdge = makeTopZone("ResizeTop",
        UDim2.fromOffset(0, 0),
        UDim2.new(1, 0, 0, w))
    local tlCorner = makeTopZone("ResizeCornerTL",
        UDim2.fromOffset(0, 0),
        UDim2.new(0, cs, 0, cs))

    local zones = {
        { self._resizeHandle, "RB" },
        { rightEdge,          "R" },
        { leftEdge,           "L" },
        { bottomEdge,         "B" },
        { corner,             "RB" },
        { blCorner,           "LB" },
        { topEdge,            "T" },
        { tlCorner,           "LT" },
    }

    local function beginResize(input: InputObject, mode: string)
        if self._collapsed then
            return
        end
        self._resizeHeld = true
        resizing = true
        edgeMode = mode
        if input.UserInputType == Enum.UserInputType.Touch then
            startPos = input.Position
            startMouse = nil
        else
            startMouse = UIS:GetMouseLocation()
            startPos = nil
        end
        startSize = Vector2.new(self.Root.Size.X.Offset, self.Root.Size.Y.Offset)
        startPosX = self.Root.Position.X.Offset
        startPosY = self.Root.Position.Y.Offset
        startPosScaleX = self.Root.Position.X.Scale
        startPosScaleY = self.Root.Position.Y.Scale
    end

    for _, pair in zones do
        local zone: GuiObject = pair[1]
        local mode: string = pair[2]
        local conn = zone.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or
               input.UserInputType == Enum.UserInputType.Touch then
                beginResize(input, mode)
            end
        end)
        table.insert(self._connections, conn)
    end

    local conn2 = UIS.InputChanged:Connect(function(input)
        if not resizing then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or
           input.UserInputType == Enum.UserInputType.Touch then
            local delta: Vector2?
            if input.UserInputType == Enum.UserInputType.Touch and startPos then
                delta = input.Position - startPos
            elseif startMouse then
                delta = UIS:GetMouseLocation() - startMouse
            end
            if delta then
                local dx = delta.X
                local dy = delta.Y
                local w0 = startSize.X
                local h0 = startSize.Y
                local x0 = startPosX
                local y0 = startPosY
                local minW = self._minSize.X
                local minH = self._minSize.Y
                local newW = w0
                local newH = h0
                local newX = x0
                local newY = y0
                if string.find(edgeMode, "R") then
                    newW = math.floor(math.max(minW, w0 + dx) + 0.5)
                end
                if string.find(edgeMode, "L") then
                    newW = math.floor(math.max(minW, w0 - dx) + 0.5)
                    newX = x0 + (w0 - newW)
                end
                if string.find(edgeMode, "B") then
                    newH = math.floor(math.max(minH, h0 + dy) + 0.5)
                end
                if string.find(edgeMode, "T") then
                    newH = math.floor(math.max(minH, h0 - dy) + 0.5)
                    newY = y0 + (h0 - newH)
                end
                self.Root.Position = UDim2.new(startPosScaleX, math.floor(newX + 0.5), startPosScaleY, math.floor(newY + 0.5))
                self.Root.Size = UDim2.fromOffset(newW, newH)
            end
        end
    end)

    local conn3 = UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            if resizing then
                resizing = false
                self._resizeHeld = false
                if self.Root.Size.Y.Offset ~= startSize.Y then
                    self._autoHeight = false
                end
            end
        end
    end)

    table.insert(self._connections, conn2)
    table.insert(self._connections, conn3)
end

function Window:_setupCollapse()
    local conn = self._closeBtn.Activated:Connect(function()
        self:ToggleCollapse()
    end)
    table.insert(self._connections, conn)
end

function Window:_setupSmoothScroll(scroll: ScrollingFrame)
    local UIS = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local GuiService = game:GetService("GuiService")

    local state = { t = 0, y = 0, a = 0 }
    self._smooth = state
    self._smoothHover = false
    self._smoothDrag = false

    local bar = Instance.new("Frame")
    bar.Name = "ScrollBar"
    bar.Active = true
    bar.Visible = false
    bar.BackgroundColor3 = Theme.Colors.ScrollBar
    bar.BackgroundTransparency = 1
    bar.BorderSizePixel = 0
    bar.AnchorPoint = Vector2.new(0, 0)
    bar.Size = UDim2.fromOffset(4, 8)
    bar.ZIndex = scroll.ZIndex + 1
    bar.Parent = self._down

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(1, 0)
    barCorner.Parent = bar

    local scrollbarSize = Theme.Layout.ScrollBarSize
    local barWidth = math.floor(scrollbarSize * 0.55 + 0.5)
    local padY = math.floor(Theme.Layout.ListPaddingY * 0.35 + 0.5)

    local function mousePos(): (number, number)
        local loc = UIS:GetMouseLocation()
        local inset = GuiService:GetGuiInset()
        return loc.X - inset.X, loc.Y - inset.Y
    end

    local function mouseInScroll(): boolean
        local mx, my = mousePos()
        local pos = scroll.AbsolutePosition
        local size = scroll.AbsoluteWindowSize
        return mx >= pos.X and mx <= pos.X + size.X
            and my >= pos.Y and my <= pos.Y + size.Y
    end

    local function scrollToMouse()
        local _, my = mousePos()
        local viewH = scroll.AbsoluteWindowSize.Y
        local barHeight = bar.AbsoluteSize.Y
        local span = math.max(1, viewH - barHeight - padY * 2)
        local frac = math.clamp((my - scroll.AbsolutePosition.Y - padY) / span, 0, 1)
        local maxY = math.max(0, scroll.AbsoluteCanvasSize.Y - viewH)
        state.t = frac * maxY
    end

    local smoothConn: RBXScriptConnection? = nil

    local function ensureLoop()
        if smoothConn ~= nil then
            return
        end
        local conn: RBXScriptConnection
        conn = RunService.RenderStepped:Connect(function(dt: number)
            local viewH = scroll.AbsoluteWindowSize.Y
            local canvasH = scroll.AbsoluteCanvasSize.Y
            local maxY = math.max(0, canvasH - viewH)

            state.t = math.clamp(state.t, 0, maxY)

            local k = math.min(1, dt * 8)
            state.y += (state.t - state.y) * k
            if math.abs(state.y - state.t) < 0.2 then
                state.y = state.t
            end
            state.y = math.clamp(state.y, 0, maxY)

            if maxY > 0 then
                scroll.CanvasPosition = Vector2.new(0, state.y)
            end

            local alphaTarget = 0
            if maxY > 0
                and (self._smoothHover or self._smoothDrag
                    or math.abs(state.y - state.t) > 0.5)
            then
                alphaTarget = 1
            end

            local alphaK = math.min(1, dt * 10)
            state.a += (alphaTarget - state.a) * alphaK
            if state.a < 0.01 then
                state.a = 0
            end

            if maxY > 0 and state.a > 0.01 then
                local frac = state.y / math.max(1, maxY)
                local barHeight = math.max(
                    scrollbarSize,
                    (viewH / math.max(canvasH, viewH)) * (viewH - padY * 2)
                )
                barHeight = math.floor(barHeight + 0.5)
                local track = math.max(0, viewH - barHeight - padY * 2)
                local x = scroll.AbsolutePosition.X
                    + scroll.AbsoluteWindowSize.X
                    - barWidth
                    - padY
                    - self._down.AbsolutePosition.X
                local y = scroll.AbsolutePosition.Y
                    + padY
                    + frac * track
                    - self._down.AbsolutePosition.Y
                bar.Size = UDim2.fromOffset(barWidth, barHeight)
                bar.Position = UDim2.fromOffset(x, y)
                bar.BackgroundTransparency = 1 - state.a
                bar.Visible = true
            else
                bar.Visible = false
            end

            local busy = self._smoothHover
                or self._smoothDrag
                or math.abs(state.y - state.t) > 0.001
                or math.abs(state.a - alphaTarget) > 0.001
            if not busy then
                smoothConn = nil
                conn:Disconnect()
            end
        end)
        smoothConn = conn
    end

    local enterConn = self.Root.MouseEnter:Connect(function()
        self._smoothHover = true
        ensureLoop()
    end)
    local leaveConn = self.Root.MouseLeave:Connect(function()
        self._smoothHover = false
        ensureLoop()
    end)

    local touchDragPos: number? = nil

    local wheelConn = UIS.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            if self._smoothDrag or mouseInScroll() then
                local delta = input.Position.Z
                if delta == 0 then
                    delta = input.Position.Y
                end
                state.t -= delta * 40
                ensureLoop()
            end
        end
    end)

    local moveConn = UIS.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            if self._smoothDrag then
                scrollToMouse()
                ensureLoop()
            end
        elseif input.UserInputType == Enum.UserInputType.Touch
            and touchDragPos ~= nil
            and self._touchPanBlock ~= true
        then
            local dy = input.Position.Y - touchDragPos
            touchDragPos = input.Position.Y
            state.t -= dy
            ensureLoop()
        end
    end)

    local function pointOnButton(): boolean
        local mx, my = mousePos()
        for _, descendant in scroll:GetDescendants() do
            if descendant:IsA("GuiButton") then
                local pos = descendant.AbsolutePosition
                local size = descendant.AbsoluteSize
                if mx >= pos.X and mx <= pos.X + size.X
                    and my >= pos.Y and my <= pos.Y + size.Y
                then
                    return true
                end
            end
        end
        return false
    end

    local touchBeginConn = scroll.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            if pointOnButton() then
                return
            end
            touchDragPos = input.Position.Y
            self._smoothHover = true
            ensureLoop()
        end
    end)

    local touchEndConn = UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            touchDragPos = nil
            self._smoothHover = false
            ensureLoop()
        end
    end)

    local dragEndConn = UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self._smoothDrag = false
            ensureLoop()
        end
    end)

    local barConn = bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self._smoothDrag = true
            scrollToMouse()
            ensureLoop()
        end
    end)

    table.insert(self._connections, enterConn)
    table.insert(self._connections, leaveConn)
    table.insert(self._connections, wheelConn)
    table.insert(self._connections, moveConn)
    table.insert(self._connections, dragEndConn)
    table.insert(self._connections, barConn)
    table.insert(self._connections, touchBeginConn)
    table.insert(self._connections, touchEndConn)
end

function Window:_setupOutsideClose()
    local UIS = game:GetService("UserInputService")
    local GuiService = game:GetService("GuiService")

    local conn = UIS.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        if not self.Root.Visible then
            return
        end

        if self._openedAt and os.clock() - self._openedAt < 0.15 then
            return
        end

        local hostGui: BasePlayerGui? = nil
        do
            local node: Instance? = self.Root
            while node and hostGui == nil do
                if node:IsA("BasePlayerGui") then
                    hostGui = node :: BasePlayerGui
                end
                node = node.Parent
            end
        end
        if not hostGui then
            return
        end
        local ok, under = pcall(function()
            local inset = GuiService:GetGuiInset()
            local pt = UIS:GetMouseLocation()
            return hostGui:GetGuiObjectsAtPosition(pt.X - inset.X, pt.Y - inset.Y)
        end)
        if not ok or typeof(under) ~= "table" then
            return
        end
        local outsideContent = false
        for _, obj in (under :: { Instance }) do

            if obj == self.Root or obj:IsDescendantOf(self.Root) then
                return
            end

            if self._outsideIgnore ~= nil
                and (obj == self._outsideIgnore
                    or obj:IsDescendantOf(self._outsideIgnore))
            then
                return
            end

            outsideContent = true
        end
        if not outsideContent and #under > 0 then
            return
        end
        self:Hide()
    end)
    table.insert(self._connections, conn)
end

function Window:Hide()
    self.Root.Visible = false
end

function Window:Show()
    self._openedAt = os.clock()
    if self._popup then
        self:BringToFront()
    end
    self.Root.Visible = true
    if self._fitWidth then
        self:_fitPopupWidthSoon()
    end
end

function Window:_popupCenter()
    local parent = self.Root.Parent
    if parent == nil or not parent:IsA("GuiBase2d") then
        return
    end
    local vp = parent.AbsoluteSize
    local size = self.Root.AbsoluteSize
    local x = math.floor((vp.X - size.X) / 2 + 0.5)
    local y = math.floor((vp.Y - size.Y) / 2 + 0.5)
    self.Root.Position = UDim2.fromOffset(x, y)
end

function Window:_popupCenterWhenSized()
    if self._popupCenterConn ~= nil then
        self._popupCenterConn:Disconnect()
        self._popupCenterConn = nil
    end
    if not self.Root.Visible then
        return
    end
    self:_popupCenter()
    self._popupCenterConn = self.Root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if not self.Root.Visible then
            return
        end
        self:_popupCenter()
    end)
end

function Window:FitPopupWidth(): boolean
    if not self._fitWidth or not self._popup then
        return false
    end
    local list = self._list
    if list == nil then
        return false
    end
    local needed = 0
    for _, child in list:GetChildren() do
        if child:IsA("GuiObject") then
            local label = if child:IsA("TextLabel") or child:IsA("TextButton") then child
                else child:FindFirstChild("Title", true)
            if label == nil or not (label:IsA("TextLabel") or label:IsA("TextButton")) then
                local valueLabel = child:FindFirstChild("Value", true)
                if valueLabel ~= nil and valueLabel:IsA("TextLabel") then
                    label = valueLabel
                end
            end
            if label ~= nil and (label:IsA("TextLabel") or label:IsA("TextButton"))
                and label.Text ~= "" then
                local width = textWidth(label.Text, label.TextSize)
                local toggle = child:FindFirstChild("On", true)
                    or child:FindFirstChild("Toggle", true)
                    or child:FindFirstChild("Switch", true)
                if toggle ~= nil then
                    width += Theme.Layout.ToggleWidth + (Theme.Layout.InlineGapX or 8)
                end
                if label ~= child and label.Name == "Value" then
                    width += 24
                end
                if width > needed then
                    needed = width
                end
            end
        end
    end
    if needed <= 0 then
        return false
    end
    local target = math.clamp(
        math.ceil(needed + Theme.Layout.ListPaddingX * 2 + 12),
        Theme.Layout.WindowMinWidth,
        math.floor(560 * (Theme.ScreenScale or 1) + 0.5))
    if target == self.Root.Size.X.Offset then
        return false
    end
    self.Root.Size = UDim2.fromOffset(target, self.Root.Size.Y.Offset)
    popupLog(string.format("FitPopupWidth win=%s w=%d", self._title, target))
    return true
end

function Window:_fitPopupWidthSoon()
    if not self._fitWidth or not self._popup then
        return
    end
    local function pass()
        if not self.Root.Visible then
            return
        end
        local oldWidth = self.Root.Size.X.Offset
        if not self:FitPopupWidth() then
            return
        end
        local grew = self.Root.Size.X.Offset - oldWidth
        local parent = self.Root.Parent
        if parent == nil or not parent:IsA("GuiBase2d") then
            return
        end
        local vp = parent.AbsoluteSize
        local xNow = self.Root.Position.X.Offset
        if xNow + self.Root.Size.X.Offset > vp.X - 2 then
            local shifted = math.floor(xNow - grew + 0.5)
            if shifted < 0 then
                shifted = 0
            end
            self.Root.Position = UDim2.fromOffset(shifted, self.Root.Position.Y.Offset)
        end
    end
    task.defer(pass)
    task.delay(0.15, pass)
end

function Window:ShowCentered()
    popupLog("ShowCentered win=" .. self._title)
    self._openedAt = os.clock()
    self:BringToFront()
    self:_popupCenter()
    self.Root.Visible = true
    self:_popupCenterWhenSized()
    self:_fitPopupWidthSoon()
end

function Window:SetOutsideIgnore(instance: Instance?)
    self._outsideIgnore = instance
end

function Window:ShowAt(anchor: Vector2, offset: Vector2?)
    popupLog("ShowAt win=" .. self._title)
    local off = offset or Vector2.new(8, 6)
    if self._popupCenterConn ~= nil then
        self._popupCenterConn:Disconnect()
        self._popupCenterConn = nil
    end
    local w = self.Root.Size.X.Offset
    local x = anchor.X + off.X
    local y = anchor.Y + off.Y
    local parent = self.Root.Parent
    if parent and parent:IsA("GuiBase2d") then
        local vp = parent.AbsoluteSize

        if x + w > vp.X - 2 then
            local leftX = anchor.X - w - off.X
            x = if leftX >= 0 then leftX else math.max(0, vp.X - w - 2)
        end
        y = math.clamp(y, 0, math.max(0, vp.Y - 24))
    end

    self.Root.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
    self._openedAt = os.clock()

    if self._popup then
        self:BringToFront()
    end
    self.Root.Visible = true

    local function settleClamp()
        if not self.Root.Visible then
            return
        end
        local parentNow = self.Root.Parent
        if parentNow and parentNow:IsA("GuiBase2d") then
            local vp = parentNow.AbsoluteSize
            local yNow = self.Root.Position.Y.Offset
            local overflow = yNow + self.Root.AbsoluteSize.Y - vp.Y
            if overflow > 0 then
                self.Root.Position = UDim2.fromOffset(
                    self.Root.Position.X.Offset,
                    math.max(0, math.floor(yNow - overflow + 0.5))
                )
            end
        end
    end
    task.defer(settleClamp)
    task.delay(0.08, settleClamp)
    self:_fitPopupWidthSoon()
end

function Window:BringToFront()
    Window._zTopCounter = math.max(
        (Window._zTopCounter or 0), self.Root.ZIndex) + 1
    self.Root.ZIndex = Window._zTopCounter
end

function Window:_updateAutoHeight(): boolean?
    if self._popup or not self._autoHeight then
        return nil
    end
    if self._collapsed then
        return nil
    end
    local layout = self._listLayout
    if layout == nil then
        return nil
    end
    local contentHeight = layout.AbsoluteContentSize.Y
    if contentHeight <= 0 then
        return nil
    end
    local chrome = Theme.Layout.HeaderHeight + 1
        + (Theme.Layout.ListPaddingY * 2)
        + 1
    local desired = math.floor(contentHeight + chrome + 0.5)
    if desired < Theme.Layout.HeaderHeight then
        desired = Theme.Layout.HeaderHeight
    end
    local camera = workspace.CurrentCamera
    if camera ~= nil then
        local inset = game:GetService("GuiService"):GetGuiInset()
        local maxHeight = camera.ViewportSize.Y - inset.Y - 10
        if desired > maxHeight then
            desired = math.floor(maxHeight)
        end
    end
    if math.abs(self.Root.Size.Y.Offset - desired) < 1 then
        return true
    end
    local newSize = UDim2.fromOffset(self.Root.Size.X.Offset, desired)
    self._expandedHeight = desired
    self._initialSize = newSize
    self._naturalSize = newSize
    self.Root.Size = newSize
    local handler = self._onHeightChanged
    if typeof(handler) == "function" then
        task.defer(handler)
    end
    return false
end

function Window:_startAutoHeightSettle()
    if self._popup or not self._autoHeight then
        return
    end
    local layout = self._listLayout
    if layout == nil then
        return
    end
    local old = self._autoHeightSettleConn
    if old ~= nil then
        old:Disconnect()
    end
    self._autoHeightSettleConn = nil
    self._autoHeightSettled = false

    local conn: RBXScriptConnection? = nil
    local pendingCheck = false
    local function finish()
        self._autoHeightSettled = true
        if conn ~= nil then
            conn:Disconnect()
        end
        if self._autoHeightSettleConn == conn then
            self._autoHeightSettleConn = nil
        end
    end
    local function check()
        if pendingCheck then
            return
        end
        pendingCheck = true
        task.defer(function()
            pendingCheck = false
            if self._autoHeightSettleConn ~= conn then
                return
            end
            local result = self:_updateAutoHeight()
            if result == true then
                finish()
            elseif result == false then
                task.defer(check)
            end
        end)
    end

    conn = layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(check)
    self._autoHeightSettleConn = conn
    table.insert(self._connections, conn)
    check()
end

function Window:ToggleCollapse()
    self._collapsed = not self._collapsed

    if self._collapsed then
        self._expandedHeight = self.Root.Size.Y.Offset
        self._down.Visible = false
        self._list.Visible = false
        self.Root.Size = UDim2.new(
            self.Root.Size.X.Scale, self.Root.Size.X.Offset,
            0, Theme.Layout.HeaderHeight)
    else
        local h = math.max(self._expandedHeight or 0, Theme.Layout.HeaderHeight)
        self.Root.Size = UDim2.new(
            self.Root.Size.X.Scale, self.Root.Size.X.Offset,
            0, h)
        self._down.Visible = true
        self._list.Visible = true
        task.defer(function()
            self:_updateAutoHeight()
        end)
    end

    self._closeBtn.Rotation = if self._collapsed then -90 else 0
end

function Window:ResetLayout()
    if self._collapsed then
        self._collapsed = false
        self._down.Visible = true
        self._list.Visible = true
        self._closeBtn.Rotation = 0
    end
    self.Root.Position = self._initialPosition
    local natural = self._defaultSize or self._naturalSize or self._initialSize
    self.Root.Size = natural
    self._initialSize = natural
    self._naturalSize = natural
    self._userMoved = false
    self._autoHeight = self._autoHeightByConfig == true
    self:BringToFront()
    if self._autoHeight then
        self:_updateAutoHeight()
        self:_startAutoHeightSettle()
    end
end

function Window:GetContentFrame(): ScrollingFrame
    return self._list
end

function Window:SetTitle(title: string)
    self._title = title
    if self._titleLabel ~= nil then
        self._titleLabel.Text = title
    end
end

function Window:SetVisible(visible: boolean)

    if visible then
        self:Show()
    else
        self:Hide()
    end
end

function Window:Destroy()
    for _, conn in self._connections do
        conn:Disconnect()
    end
    self._connections = {}
    if self._popupCenterConn ~= nil then
        self._popupCenterConn:Disconnect()
        self._popupCenterConn = nil
    end
    self.Root:Destroy()
end

return Window
