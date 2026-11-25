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
local ButtonWidget = importWidget("Button")

export type PopupConfig = {
    Title: string?,
    Items: { string }?,
    FooterButtons: { string }?,
    ListWidth: number?,
    ListHeight: number?,
    Host: Instance?,
    OnSelect: ((string) -> ())?,
    OnButton: ((string) -> ())?,
}

local function Popup(config: PopupConfig): { Open: () -> (), Close: () -> (), Frame: Frame }
    init()

    local PAD = 10
    local headerH = Theme.Layout.HeaderHeight
    local listW = config.ListWidth or 400
    local listH = config.ListHeight or 500
    local footers = config.FooterButtons or { "Open Folder", "Close" }
    local baseZ = 50
    local BTN_GAP = 4

    local winW = listW + PAD * 2
    local winH = headerH + PAD + listH + PAD + #footers * Theme.Layout.ButtonHeight
        + (#footers - 1) * BTN_GAP + PAD

    local modal = Instance.new("Frame")
    modal.Name = "Popup" .. (config.Title or "")
    modal.BackgroundTransparency = 1
    modal.BorderSizePixel = 0
    modal.Size = UDim2.new(1, 0, 1, 0)
    modal.Visible = false
    modal.ZIndex = baseZ

    local overlay = Instance.new("TextButton")
    overlay.Name = "Dim"
    overlay.Text = ""
    overlay.AutoButtonColor = false
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 1 - (0x7F / 255)
    overlay.BorderSizePixel = 0
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.ZIndex = baseZ
    overlay.Parent = modal

    local GLOW_SPREAD = 250
    local GLOW_INNER_ALPHA = 0x64 / 255
    local GLOW_LAYERS = 14
    local glowColor = Color3.fromRGB(0x78, 0x64, 0xF0)
    for layer = GLOW_LAYERS, 1, -1 do
        local off = GLOW_SPREAD * layer / GLOW_LAYERS
        local halo = Instance.new("Frame")
        halo.Name = "Glow" .. layer
        halo.BackgroundColor3 = glowColor
        halo.BackgroundTransparency = 1 - GLOW_INNER_ALPHA * (1 - layer / GLOW_LAYERS)
        halo.BorderSizePixel = 0
        halo.AnchorPoint = Vector2.new(0.5, 0.5)
        halo.Position = UDim2.fromScale(0.5, 0.5)
        halo.Size = UDim2.fromOffset(winW + off * 2, winH + off * 2)
        local haloCorner = Instance.new("UICorner")
        haloCorner.CornerRadius = UDim.new(0, 12 + off)
        haloCorner.Parent = halo
        halo.ZIndex = baseZ
        halo.Parent = modal
    end

    local win = Instance.new("Frame")
    win.Name = "Window"
    win.BackgroundColor3 = Theme.Colors.PopupBG
    win.BackgroundTransparency = 1 - 0.98
    win.BorderSizePixel = 0
    win.AnchorPoint = Vector2.new(0.5, 0.5)
    win.Position = UDim2.fromScale(0.5, 0.5)
    win.Size = UDim2.fromOffset(winW, winH)
    win.ClipsDescendants = true
    win.ZIndex = baseZ + 1
    local winCorner = Instance.new("UICorner")
    winCorner.CornerRadius = UDim.new(0, 12)
    winCorner.Parent = win
    win.Parent = modal

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.BackgroundColor3 = Theme.Colors.HeaderBG
    header.BorderSizePixel = 0
    header.Size = UDim2.new(1, 0, 0, headerH)
    header.ZIndex = baseZ + 2
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.BorderSizePixel = 0
    title.Size = UDim2.new(1, 0, 1, 0)
    title.FontFace = Theme.GetFontFace()
    title.Text = config.Title or ""
    title.TextColor3 = Theme.Colors.TextPrimary
    title.TextSize = Theme.Font.Title
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.TextYAlignment = Enum.TextYAlignment.Center
    title.ZIndex = baseZ + 3
    title.Parent = header
    header.Parent = win

    local list = Instance.new("ScrollingFrame")
    list.Name = "List"
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.Position = UDim2.fromOffset(PAD, headerH + PAD)
    list.Size = UDim2.fromOffset(listW, listH)
    list.CanvasSize = UDim2.fromScale(0, 0)
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.ScrollBarThickness = Theme.Layout.ScrollBarWidth
    list.ScrollBarImageColor3 = Theme.Colors.ResizeHandle
    list.ScrollBarImageTransparency = 0.3
    list.ZIndex = baseZ + 2
    list.Parent = win

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, BTN_GAP)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = list

    local isAnimating = false
    local ANIM_DURATION = 0.25

    local function close()
        if isAnimating then return end
        isAnimating = true

        Animate.Tween({
            Duration = ANIM_DURATION * 0.8,
            EasingFunction = Animate.Easing.EaseInOutQuad,
            OnStep = function(t)
                local s = Animate.Lerp(1, 0.9, t)
                win.Size = UDim2.fromOffset(
                    math.floor(winW * s), math.floor(winH * s))
                overlay.BackgroundTransparency = Animate.Lerp(
                    1 - (0x7F / 255), 1, t)
                win.BackgroundTransparency = Animate.Lerp(1 - 0.98, 1, t)
            end,
            OnComplete = function()
                modal.Visible = false
                win.Size = UDim2.fromOffset(winW, winH)
                overlay.BackgroundTransparency = 1 - (0x7F / 255)
                win.BackgroundTransparency = 1 - 0.98
                isAnimating = false
            end,
        })
    end

    local function open()
        if isAnimating then return end
        if not modal.Parent then
            local hostGui = config.Host
                or game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
            if hostGui then
                modal.Parent = hostGui
            end
        end

        isAnimating = true
        modal.Visible = true

        Animate.Tween({
            Duration = ANIM_DURATION,
            EasingFunction = Animate.Easing.EaseOutBack,
            OnStep = function(t)
                local s = Animate.Lerp(0.85, 1, t)
                win.Size = UDim2.fromOffset(
                    math.floor(winW * s), math.floor(winH * s))
                overlay.BackgroundTransparency = Animate.Lerp(
                    1, 1 - (0x7F / 255), t)
            end,
            OnComplete = function()
                win.Size = UDim2.fromOffset(winW, winH)
                isAnimating = false
            end,
        })
    end

    local itemOrder = 0
    for _, itemName in (config.Items or {}) do
        itemOrder += 1
        local pill = ButtonWidget({
            Text = itemName,
            LayoutOrder = itemOrder,
            Callback = function()
                if config.OnSelect then
                    config.OnSelect(itemName)
                end
                close()
            end,
        })
        pill.ZIndex = baseZ + 3
        pill.Parent = list
    end

    local footerY = headerH + PAD + listH + PAD
    for i, buttonName in footers do
        local pill = ButtonWidget({
            Text = buttonName,
            Callback = function()
                if buttonName == "Close" then
                    close()
                end
                if config.OnButton then
                    config.OnButton(buttonName)
                end
            end,
        })
        pill.Position = UDim2.fromOffset(
            PAD, footerY + (i - 1) * (Theme.Layout.ButtonHeight + BTN_GAP))
        pill.ZIndex = baseZ + 3
        pill.Parent = win
    end

    return {
        Open = open,
        Close = close,
        Frame = modal,
    }
end

return Popup
