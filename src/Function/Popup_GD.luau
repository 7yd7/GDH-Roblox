local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")

local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local Import = genv.Import
if not Import then return {} end

local Popup_GD = {}

export type Style = {
    before: string?,
    highlight: string?,
    after: string?,
    line2: string?,
    color: string?,
    bold: boolean?,
    quote: boolean?,
    separator: string?,
}

export type PopupConfig = {
    Name: string?,
    Parent: Instance?,
    DisplayOrder: number?,
    Width: number?,
    Height: number?,
    Size: UDim2?,
    PanelWidth: number?,
    PanelHeight: number?,
    PanelSize: UDim2?,
    Title: string?,
    Body: string?,
    ButtonText: string?,
    Dim: number?,
    OnClose: (() -> ())?,
}

local DEFAULT_COLOR = "#66FF66"
local REFERENCE_X = 1920
local REFERENCE_Y = 1080
local MIN_FIT = 0.62

local function applyResponsive(panel: Instance?)
    if not panel then return end
    local responsive = panel:FindFirstChild("Responsive")
    if not responsive then return end
    local camera = workspace.CurrentCamera
    local vp = camera and camera.ViewportSize or Vector2.new(REFERENCE_X, REFERENCE_Y)
    local designW = panel:GetAttribute("GDHDesignW") or REFERENCE_X * 0.34
    local designH = panel:GetAttribute("GDHDesignH") or REFERENCE_Y * 0.40
    local fit = math.clamp(math.min(vp.X / REFERENCE_X, vp.Y / REFERENCE_Y), MIN_FIT, 1.35)
    fit = math.min(fit, (vp.X - 40) / math.max(designW, 1), (vp.Y - 40) / math.max(designH, 1))
    responsive.Scale = math.max(fit, 0.25)
end

function Popup_GD.Text(style: Style | string, ...): string
    local args = table.pack(...)

    if typeof(style) == "string" then
        if args.n == 0 or string.find(style, "<", 1, true) ~= nil then
            return style
        end
    end

    local o: Style
    if typeof(style) == "table" then
        o = style
    else
        o = {
            before    = if typeof(style) == "string" then style else "",
            highlight = if typeof(args[1]) == "string" then args[1] else nil,
            after     = if typeof(args[2]) == "string" then args[2] else nil,
            line2     = if typeof(args[3]) == "string" then args[3] else nil,
            color     = if typeof(args[4]) == "string" then args[4] else nil,
        }
    end

    local before = if typeof(o.before) == "string" then o.before else ""
    local word = if typeof(o.highlight) == "string" then o.highlight else ""
    local afterText = if typeof(o.after) == "string" then o.after else ""
    local secondLine = if typeof(o.line2) == "string" then o.line2 else ""
    local textColor = if typeof(o.color) == "string" then o.color else DEFAULT_COLOR
    local bold = if typeof(o.bold) == "boolean" then o.bold else true
    local quote = if typeof(o.quote) == "boolean" then o.quote else true
    local separator = if typeof(o.separator) == "string" then o.separator else "\n"

    local shown = if quote then ('"' .. word .. '"') else word
    if bold then
        shown = "<b>" .. shown .. "</b>"
    end

    local result = before .. '<font color="' .. textColor .. '">' .. shown .. "</font>" .. afterText
    if secondLine ~= "" then
        result ..= separator .. secondLine
    end
    return result
end

Popup_GD.Format = Popup_GD.Text

local fontPusab: Font = Font.fromEnum(Enum.Font.GothamBlack)
do
    local ok, face = pcall(Import.Font, "Assets/GD/PUSAB___.otf", "Pusab")
    if ok and face ~= nil then
        fontPusab = face
    end
end

local fontBody: Font = Font.new("rbxasset://fonts/families/GoogleSans.json", Enum.FontWeight.Regular)
do
    local ok, fontAsset = pcall(Import.Asset, "GoogleSans-Regular.ttf")
    if ok and typeof(fontAsset) == "string" and fontAsset ~= "" then
        local okFont, face = pcall(Font.new, fontAsset, Enum.FontWeight.Regular)
        if okFont and face ~= nil then
            fontBody = face
        end
    end
end

local panelImage = ""
local buttonImage = ""
task.spawn(function()
    local ok1, img1 = pcall(Import, "Assets/GD/square01_001-uhd.png")
    if ok1 and img1 and img1 ~= "" then panelImage = img1 end
    local ok2, img2 = pcall(Import, "Assets/GD/Button.png")
    if ok2 and img2 and img2 ~= "" then buttonImage = img2 end
end)

local function toggleKeyName(): string
    local lib = genv.GDH_UI
    if lib and lib._toggleKey then
        return string.upper(lib._toggleKey.Name)
    end
    return "G"
end

local function defaultBody(): string
    if typeof(genv.GDH_INFO_TEXT) == "string" and genv.GDH_INFO_TEXT ~= "" then
        return genv.GDH_INFO_TEXT
    end
    return string.format(
        'Press <font color="#66FF66"><b>"%s"</b></font> to open\nthe GDH interface.',
        toggleKeyName()
    )
end

function Popup_GD.Create(config: PopupConfig?): ScreenGui?
    local cfg = config or {}

    local player = Players.LocalPlayer
    local playerGui = cfg.Parent
    if not playerGui then
        playerGui = player and player:FindFirstChildOfClass("PlayerGui")
    end
    if not playerGui then return nil end

    local screenName = (typeof(cfg.Name) == "string" and cfg.Name ~= "" and cfg.Name) or "GDH_Popup_GD"
    local existing = playerGui:FindFirstChild(screenName)
    if existing then existing:Destroy() end

    local width = if typeof(cfg.Width) == "number" then cfg.Width else 0.34
    local height = if typeof(cfg.Height) == "number" then cfg.Height else 0.40
    local panelScaleX = if typeof(cfg.PanelWidth) == "number" then cfg.PanelWidth else width
    local panelScaleY = if typeof(cfg.PanelHeight) == "number" then cfg.PanelHeight else height
    local dim = if typeof(cfg.Dim) == "number" then cfg.Dim else 0.41

    local titleText = if typeof(cfg.Title) == "string" then cfg.Title else "Info"
    local bodyText = if typeof(cfg.Body) == "string" then cfg.Body else defaultBody()
    local buttonText = if typeof(cfg.ButtonText) == "string" then cfg.ButtonText else "OK"

    local TITLE_SCALE = 0.10
    local OK_SCALE_W = 0.26
    local OK_SCALE_H = 0.215

    local tweenRefs: { Tween } = {}

    local screen = Instance.new("ScreenGui")
    screen.Name = screenName
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.DisplayOrder = if typeof(cfg.DisplayOrder) == "number" then cfg.DisplayOrder else 999
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true

    local root = Instance.new("Frame")
    root.Name = "Root"
    root.BackgroundTransparency = 1
    root.BorderSizePixel = 0
    root.Size = UDim2.fromScale(1, 1)
    root.Parent = screen

    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel = 0
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.ZIndex = 1
    overlay.Parent = root

    local FALLBACK_PANEL = "rbxassetid://103304293139416"

    local panel = Instance.new("ImageLabel")
    panel.Name = "Panel"
    panel.Active = true
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.Image = if panelImage ~= "" then panelImage else FALLBACK_PANEL
    panel.ScaleType = Enum.ScaleType.Slice
    panel.SliceCenter = Rect.new(80, 80, 240, 240)
    panel.SliceScale = 0.667
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    local backgroundSize = if cfg.PanelSize ~= nil then cfg.PanelSize
        elseif cfg.Size ~= nil then cfg.Size
        else UDim2.fromScale(panelScaleX, panelScaleY)
    local designW = backgroundSize.X.Scale * REFERENCE_X + backgroundSize.X.Offset
    local designH = backgroundSize.Y.Scale * REFERENCE_Y + backgroundSize.Y.Offset
    panel:SetAttribute("GDHDesignW", designW)
    panel:SetAttribute("GDHDesignH", designH)
    panel.Size = UDim2.fromOffset(designW, designH)
    panel.ZIndex = 2
    panel.Parent = root

    local responsive = Instance.new("UIScale")
    responsive.Name = "Responsive"
    responsive.Scale = 1
    responsive.Parent = panel
    applyResponsive(panel)

    local camera = workspace.CurrentCamera
    local resizeConn = nil
    if camera then
        resizeConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            applyResponsive(panel)
        end)
    end

    local fit = Instance.new("UIScale")
    fit.Name = "Fit"
    fit.Scale = 1
    fit.Parent = panel

    if panelImage == "" then
        task.spawn(function()
            local waited = 0
            while panelImage == "" and waited < 5 do
                task.wait(0.2)
                waited += 0.2
            end
            if panelImage ~= "" and panel.Parent then
                panel.Image = panelImage
            end
        end)
    end

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.BorderSizePixel = 0
    title.AnchorPoint = Vector2.new(0.5, 0)
    title.Position = UDim2.new(0.5, 0, 0.14, 0)
    title.Size = UDim2.new(0.8, 0, TITLE_SCALE, 0)
    title.FontFace = fontPusab
    title.Text = titleText
    title.TextScaled = true
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.TextYAlignment = Enum.TextYAlignment.Center
    title.TextWrapped = true
    title.ZIndex = 3
    title.Parent = panel

    local titleGradient = Instance.new("UIGradient")
    titleGradient.Rotation = 90
    titleGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(253, 162, 13)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 227, 72)),
    })
    titleGradient.Parent = title

    local titleStroke = Instance.new("UIStroke")
    titleStroke.Color = Color3.new(0, 0, 0)
    titleStroke.Thickness = 3
    titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    titleStroke.Parent = title

    local body = Instance.new("TextLabel")
    body.Name = "Body"
    body.BackgroundTransparency = 1
    body.BorderSizePixel = 0
    body.AnchorPoint = Vector2.new(0.5, 0)
    body.Position = UDim2.new(0.5, 0, 0.29, 0)
    body.Size = UDim2.new(0.86, 0, 0.39, 0)
    body.FontFace = fontBody
    body.RichText = true
    body.Text = bodyText
    body.TextScaled = true
    body.TextColor3 = Color3.fromRGB(255, 255, 255)
    body.TextXAlignment = Enum.TextXAlignment.Center
    body.TextYAlignment = Enum.TextYAlignment.Center
    body.TextWrapped = true
    body.ZIndex = 3
    body.Parent = panel

    local okBtnImage = Instance.new("ImageButton")
    okBtnImage.Name = "OK"
    okBtnImage.BackgroundColor3 = Color3.fromRGB(106, 190, 48)
    okBtnImage.BackgroundTransparency = if buttonImage ~= "" then 1 else 0
    okBtnImage.BorderSizePixel = 0
    okBtnImage.AnchorPoint = Vector2.new(0.5, 1)
    okBtnImage.Position = UDim2.new(0.5, 0, 1, -40)
    okBtnImage.Size = UDim2.new(OK_SCALE_W, 0, OK_SCALE_H, 0)
    okBtnImage.Image = if buttonImage ~= "" then buttonImage else ""
    okBtnImage.ScaleType = Enum.ScaleType.Slice
    okBtnImage.SliceCenter = Rect.new(24, 24, 160, 77)
    okBtnImage.ZIndex = 4
    okBtnImage.Parent = panel

    if buttonImage == "" then
        task.spawn(function()
            local waited = 0
            while buttonImage == "" and waited < 5 do
                task.wait(0.2)
                waited += 0.2
            end
            if buttonImage ~= "" and okBtnImage.Parent then
                okBtnImage.Image = buttonImage
                okBtnImage.BackgroundTransparency = 1
            end
        end)
    end

    local okLabel = Instance.new("TextLabel")
    okLabel.Name = "Label"
    okLabel.BackgroundTransparency = 1
    okLabel.BorderSizePixel = 0
    okLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    okLabel.Position = UDim2.new(0.5, 0, 0.5, 5)
    okLabel.Size = UDim2.new(1, -60, 1, -45)
    okLabel.FontFace = fontPusab
    okLabel.Text = buttonText
    okLabel.TextScaled = true
    okLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    okLabel.TextXAlignment = Enum.TextXAlignment.Center
    okLabel.TextYAlignment = Enum.TextYAlignment.Bottom
    okLabel.ZIndex = 5
    okLabel.Parent = okBtnImage

    local okStroke = Instance.new("UIStroke")
    okStroke.Color = Color3.new(0, 0, 0)
    okStroke.Thickness = 3
    okStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    okStroke.Parent = okLabel

    local okGradient = Instance.new("UIGradient")
    okGradient.Rotation = titleGradient.Rotation
    okGradient.Color = titleGradient.Color
    okGradient.Parent = okLabel

    local BODY_GAP = 10
    local held = false
    local layoutHold = false
    local lastOkTopScale: number? = nil

    local function layoutBody()
        local panelSize = panel.AbsoluteSize
        if panelSize.X <= 0 or panelSize.Y <= 0 then return end
        local panelPos = panel.AbsolutePosition
        local titleBottom = title.AbsolutePosition.Y - panelPos.Y + title.AbsoluteSize.Y
        local okTop
        if layoutHold and lastOkTopScale ~= nil then
            okTop = lastOkTopScale * panelSize.Y
        else
            okTop = okBtnImage.AbsolutePosition.Y - panelPos.Y
            lastOkTopScale = okTop / panelSize.Y
        end
        local topScale = (titleBottom + BODY_GAP) / panelSize.Y
        local bottomScale = (okTop - BODY_GAP) / panelSize.Y
        if bottomScale <= topScale + 0.05 then return end
        body.Position = UDim2.new(0.5, 0, topScale, 0)
        body.Size = UDim2.new(0.86, 0, bottomScale - topScale, 0)
    end

    task.defer(layoutBody)

    local layoutConn: RBXScriptConnection? = nil
    layoutConn = RunService.RenderStepped:Connect(function()
        if screen.Parent == nil then
            if layoutConn then layoutConn:Disconnect() end
            return
        end
        layoutBody()
    end)
    screen.Destroying:Connect(function()
        if layoutConn then layoutConn:Disconnect() end
        if resizeConn then resizeConn:Disconnect() end

        for _, t in tweenRefs do
            pcall(function() t:Cancel() end)
        end
        table.clear(tweenRefs)
    end)

    local baseResponsiveScale = responsive.Scale
    responsive.Scale = baseResponsiveScale * 0.5
    screen.Parent = playerGui

    local openScaleTween = TweenService:Create(responsive,
        TweenInfo.new(0.8, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
        { Scale = baseResponsiveScale }
    )
    table.insert(tweenRefs, openScaleTween)
    openScaleTween.Completed:Connect(function(state)
        if state == Enum.PlaybackState.Completed then
            applyResponsive(panel)
        end
    end)
    openScaleTween:Play()

    overlay.BackgroundTransparency = 1
    local overlayTween = TweenService:Create(overlay,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = dim }
    )
    table.insert(tweenRefs, overlayTween)
    overlayTween:Play()

    local okScale = Instance.new("UIScale")
    okScale.Scale = 0.85
    okScale.Parent = okBtnImage

    local okLabelScale = Instance.new("UIScale")
    okLabelScale.Scale = 0.85
    okLabelScale.Parent = okLabel

    local okPopTween = TweenService:Create(okScale,
        TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1 }
    )
    table.insert(tweenRefs, okPopTween)
    okPopTween:Play()
    local okLabelTween = TweenService:Create(okLabelScale,
        TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1 }
    )
    table.insert(tweenRefs, okLabelTween)
    okLabelTween:Play()

    local closing = false
    local function close()
        if closing then return end
        closing = true
        screen:Destroy()
        if typeof(cfg.OnClose) == "function" then
            pcall(cfg.OnClose)
        end
    end
    okBtnImage.Activated:Connect(close)

    local pressScale = okScale
    local basePos = okBtnImage.Position
    local pivotX = okBtnImage.AnchorPoint.X - 0.5
    local pivotY = okBtnImage.AnchorPoint.Y - 0.5
    local sizeXScale = okBtnImage.Size.X.Scale
    local sizeXOffset = okBtnImage.Size.X.Offset
    local sizeYScale = okBtnImage.Size.Y.Scale
    local sizeYOffset = okBtnImage.Size.Y.Offset

    local function posComp(value: number): UDim2
        local f = value - 1
        return UDim2.new(
            f * sizeXScale * pivotX,
            f * sizeXOffset * pivotX,
            f * sizeYScale * pivotY,
            f * sizeYOffset * pivotY
        )
    end

    local activePressTweens: { Tween } = {}

    local function stopPressTweens()
        for _, t in activePressTweens do
            pcall(function() t:Cancel() end)
        end
        table.clear(activePressTweens)
    end

    local function press()
        if held then return end
        held = true
        layoutHold = true
        pcall(function() okPopTween:Cancel() end)
        stopPressTweens()
        pressScale.Scale = 1
        okBtnImage.Position = basePos

        table.insert(activePressTweens, TweenService:Create(pressScale,
            TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Scale = 1.14 }
        ))
        table.insert(activePressTweens, TweenService:Create(okBtnImage,
            TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Position = basePos + posComp(1.14) }
        ))
        for _, t in activePressTweens do t:Play() end
    end

    local function releasePress()
        if not held then return end
        held = false
        stopPressTweens()

        local backScale = TweenService:Create(pressScale,
            TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Scale = 1 }
        )
        table.insert(activePressTweens, backScale)
        table.insert(activePressTweens, TweenService:Create(okBtnImage,
            TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Position = basePos }
        ))
        for _, t in activePressTweens do t:Play() end
        backScale.Completed:Connect(function(state)
            if state == Enum.PlaybackState.Completed then
                pressScale.Scale = 1
                okBtnImage.Position = basePos
                layoutHold = false
                task.defer(layoutBody)
            end
        end)
    end

    local function isClick(input: InputObject): boolean
        return input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
    end

    okBtnImage.InputBegan:Connect(function(input)
        if isClick(input) then press() end
    end)
    okBtnImage.InputEnded:Connect(function(input)
        if isClick(input) then releasePress() end
    end)
    okBtnImage.MouseLeave:Connect(releasePress)
    UserInputService.InputEnded:Connect(function(input)
        if isClick(input) then releasePress() end
    end)

    return screen
end

function Popup_GD.Root(gui: Instance?): Instance?
    if not gui then return nil end
    return gui:FindFirstChild("Root")
end

function Popup_GD.Panel(gui: Instance?): Instance?
    local root = Popup_GD.Root(gui)
    if not root then return nil end
    return root:FindFirstChild("Panel")
end

local function setDesignSize(panel: Instance?, designW: number, designH: number)
    if not panel then return end
    panel:SetAttribute("GDHDesignW", designW)
    panel:SetAttribute("GDHDesignH", designH)
    panel.Size = UDim2.fromOffset(designW, designH)
    applyResponsive(panel)
end

function Popup_GD.SetPanelSize(gui: Instance?, size: UDim2)
    local panel = Popup_GD.Panel(gui)
    local w = size.X.Scale * REFERENCE_X + size.X.Offset
    local h = size.Y.Scale * REFERENCE_Y + size.Y.Offset
    setDesignSize(panel, w, h)
end

function Popup_GD.SetPanelScale(gui: Instance?, scaleX: number, scaleY: number?)
    local panel = Popup_GD.Panel(gui)
    local h = if typeof(scaleY) == "number"
        then scaleY * REFERENCE_Y
        else (panel and panel:GetAttribute("GDHDesignH") or REFERENCE_Y * 0.40)
    setDesignSize(panel, scaleX * REFERENCE_X, h)
end

Popup_GD.Show = Popup_GD.Create

return Popup_GD
