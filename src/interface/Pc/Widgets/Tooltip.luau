local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")

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

local Theme = nil
local Animate = nil

local function initTheme()
    if not Theme then
        Theme = importPcModule("Theme")
    end
    if not Animate then
        Animate = importPcModule("Animate")
    end
end

export type TooltipTarget = GuiObject | { GuiObject }

export type TooltipConfig = {
    Text: string,
    Target: TooltipTarget?,
    Parent: Instance?,
    Delay: number?,
}

local Tooltip = {}

local _activeScreenGui: ScreenGui? = nil
local _container: Frame? = nil
local _box: Frame? = nil
local _shadow: Frame? = nil
local _stroke: UIStroke? = nil
local _label: TextLabel? = nil

local _currentText: string = ""
local _currentTargets: TooltipTarget? = nil
local _isHovered: boolean = false
local _hoverDelayTimer: number = 0
local _animProgress: number = 0
local _renderConn: RBXScriptConnection? = nil
local _pendingText: string? = nil
local _pendingTargets: TooltipTarget? = nil

local _currentPos: Vector2? = nil

local DEFAULT_HOVER_DELAY = 1.0
local ANIM_IN_DURATION = 0.20
local ANIM_OUT_DURATION = 0.16
local SLIDE_START_OFFSET_Y = 12.0
local CURSOR_OFFSET = Vector2.new(14, 10)
local SCREEN_MARGIN = 8

local function getGuiMousePosition(): Vector2
    local inset = GuiService:GetGuiInset()
    local loc = UserInputService:GetMouseLocation()
    return Vector2.new(loc.X - inset.X, loc.Y - inset.Y)
end

local function isMouseInsideTargets(targets: TooltipTarget?, mousePos: Vector2): boolean
    if not targets then
        return false
    end
    if typeof(targets) == "table" and not (typeof(targets) == "Instance") then
        for _, obj in targets :: { GuiObject } do
            if typeof(obj) == "Instance" and obj:IsA("GuiObject") and obj:IsDescendantOf(game) and obj.Visible then
                local p = obj.AbsolutePosition
                local s = obj.AbsoluteSize
                if mousePos.X >= p.X and mousePos.X <= (p.X + s.X)
                    and mousePos.Y >= p.Y and mousePos.Y <= (p.Y + s.Y) then
                    return true
                end
            end
        end
        return false
    elseif typeof(targets) == "Instance" and (targets :: Instance):IsA("GuiObject") then
        local obj = targets :: GuiObject
        if not obj:IsDescendantOf(game) or not obj.Visible then
            return false
        end
        local p = obj.AbsolutePosition
        local s = obj.AbsoluteSize
        return mousePos.X >= p.X and mousePos.X <= (p.X + s.X)
            and mousePos.Y >= p.Y and mousePos.Y <= (p.Y + s.Y)
    end
    return false
end

local function getRepresentativeGuiObject(targets: TooltipTarget?): GuiObject?
    if not targets then return nil end
    if typeof(targets) == "table" and not (typeof(targets) == "Instance") then
        for _, obj in targets :: { GuiObject } do
            if typeof(obj) == "Instance" and obj:IsA("GuiObject") then
                return obj
            end
        end
        return nil
    elseif typeof(targets) == "Instance" and (targets :: Instance):IsA("GuiObject") then
        return targets :: GuiObject
    end
    return nil
end

local function findHostScreenGui(targets: TooltipTarget?): ScreenGui?
    local target = getRepresentativeGuiObject(targets)
    if target and target:IsDescendantOf(game) then
        local sg = target:FindFirstAncestorWhichIsA("ScreenGui")
        if sg then
            return sg
        end
    end
    local genv = (typeof(getgenv) == "function" and getgenv())
        or (typeof(_G) == "table" and _G)
        or {}
    if genv.GDH_PC_SCREEN_GUI and genv.GDH_PC_SCREEN_GUI:IsDescendantOf(game) then
        return genv.GDH_PC_SCREEN_GUI
    end
    local player = game:GetService("Players").LocalPlayer
    if player then
        local pg = player:FindFirstChildOfClass("PlayerGui")
        if pg then
            local gdh = pg:FindFirstChild("GDH")
            if gdh and gdh:IsA("ScreenGui") then
                return gdh
            end
            return pg:FindFirstChildWhichIsA("ScreenGui")
        end
    end
    return nil
end

local function ensureOverlay(hostGui: ScreenGui)
    initTheme()
    if _container and _container.Parent == hostGui then
        return
    end

    if _container then
        pcall(function()
            _container:Destroy()
        end)
    end

    _activeScreenGui = hostGui

    local container = Instance.new("Frame")
    container.Name = "GDH_TooltipLayer"
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.Size = UDim2.fromScale(1, 1)
    container.Position = UDim2.fromOffset(0, 0)
    container.ZIndex = 10000
    container.Visible = false
    container.Parent = hostGui
    _container = container

    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 1
    shadow.BorderSizePixel = 0
    shadow.ZIndex = 10001
    shadow.Parent = container
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(1, 0)
    shadowCorner.Parent = shadow
    _shadow = shadow

    local box = Instance.new("Frame")
    box.Name = "Pill"
    box.BackgroundColor3 = Theme.Colors.TooltipBG or Color3.fromRGB(33, 33, 78)
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.ClipsDescendants = false
    box.ZIndex = 10002
    box.Parent = container

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(1, 0)
    boxCorner.Parent = box
    _box = box

    local stroke = Instance.new("UIStroke")
    stroke.Name = "Border"
    stroke.Color = Theme.Colors.TooltipBorder or Color3.fromRGB(213, 196, 255)
    stroke.Thickness = 1
    stroke.Transparency = 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = box
    _stroke = stroke

    local label = Instance.new("TextLabel")
    label.Name = "Text"
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.Size = UDim2.fromScale(1, 1)
    label.Position = UDim2.fromOffset(0, 0)
    label.FontFace = Theme.GetFontFace()
    label.TextSize = Theme.Font.Body or 14
    label.TextColor3 = Theme.Colors.TooltipFG or Color3.fromRGB(213, 196, 255)
    label.TextTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextWrapped = false
    label.ZIndex = 10003
    label.Parent = box
    _label = label
end

local function computeTightWidth(text: string, fontSize: number, screenScale: number, fixedH: number): number
    if not _label then
        return fixedH
    end

    _label.Text = text
    _label.TextSize = fontSize

    local textW = _label.TextBounds.X
    if textW <= 0 then
        local ok, sz = pcall(function()
            return TextService:GetTextSize(
                text,
                fontSize,
                Theme.Font.FallbackEnum or Enum.Font.GothamMedium,
                Vector2.new(10000, 100)
            )
        end)
        if ok and sz and sz.X > 0 then
            textW = sz.X
        else
            textW = #text * math.floor(fontSize * 0.48 + 0.5)
        end
    end

    local padX = math.floor(10 * screenScale + 0.5)
    return math.max(fixedH, math.floor(textW + padX * 2 + 0.5))
end

local function stopRenderLoop()
    if _renderConn then
        _renderConn:Disconnect()
        _renderConn = nil
    end
end

local function ensureRenderLoop()
    if _renderConn then
        return
    end

    _renderConn = RunService.RenderStepped:Connect(function(dt: number)
        initTheme()

        local mousePos = getGuiMousePosition()

        if _currentTargets then
            local stillInside = isMouseInsideTargets(_currentTargets, mousePos)
            if not stillInside then
                _isHovered = false
                _currentTargets = nil
            end
        end

        if _isHovered then
            _hoverDelayTimer += dt
            if _hoverDelayTimer >= DEFAULT_HOVER_DELAY then
                _animProgress = math.min(1.0, _animProgress + (dt / ANIM_IN_DURATION))
            end
        else
            _hoverDelayTimer = 0
            _animProgress = math.max(0.0, _animProgress - (dt / ANIM_OUT_DURATION))
        end

        if _animProgress <= 0.001 and not _isHovered then
            if _pendingText ~= nil and _pendingTargets ~= nil then
                _currentText = _pendingText
                _currentTargets = _pendingTargets
                _pendingText = nil
                _pendingTargets = nil
                _currentPos = nil
                _isHovered = true
                _hoverDelayTimer = 0
            else
                if _container then
                    _container.Visible = false
                end
                _currentPos = nil
                stopRenderLoop()
                return
            end
        end

        if _animProgress <= 0.001 then
            if _container then
                _container.Visible = false
            end
            return
        end

        local hostGui = _activeScreenGui or findHostScreenGui(_currentTargets)
        if not hostGui then
            return
        end
        ensureOverlay(hostGui)

        local screenScale = Theme.ScreenScale or 1.0
        local fontSize = Theme.Font.Body or 14
        local fixedH = math.floor(24 * screenScale + 0.5)

        local dynamicW = computeTightWidth(_currentText, fontSize, screenScale, fixedH)

        local disp = hostGui.AbsoluteSize
        local targetX = mousePos.X + CURSOR_OFFSET.X
        local targetY = mousePos.Y + CURSOR_OFFSET.Y

        if targetX + dynamicW > disp.X - SCREEN_MARGIN then
            targetX = mousePos.X - dynamicW - CURSOR_OFFSET.X
        end
        if targetY + fixedH > disp.Y - SCREEN_MARGIN then
            targetY = mousePos.Y - fixedH - CURSOR_OFFSET.Y
        end
        if targetX < SCREEN_MARGIN then targetX = SCREEN_MARGIN end
        if targetY < SCREEN_MARGIN then targetY = SCREEN_MARGIN end

        local targetPos = Vector2.new(targetX, targetY)
        if not _currentPos then
            _currentPos = targetPos
        elseif _isHovered then

            _currentPos = _currentPos:Lerp(targetPos, math.clamp(dt * 20, 0, 1))
        end

        local p = _animProgress
        local easedT = if _isHovered
            then (1.0 - math.pow(1.0 - p, 2.5))
            else math.pow(p, 1.8)

        local slideOffsetY = (1.0 - easedT) * SLIDE_START_OFFSET_Y
        local renderX = math.floor(_currentPos.X + 0.5)
        local renderY = math.floor(_currentPos.Y + slideOffsetY + 0.5)

        _container.Visible = true

        _box.Size = UDim2.fromOffset(dynamicW, fixedH)
        _box.Position = UDim2.fromOffset(renderX, renderY)
        _box.BackgroundTransparency = 1.0 - easedT

        _stroke.Transparency = 1.0 - easedT
        _label.TextTransparency = 1.0 - easedT

        _shadow.Size = UDim2.fromOffset(dynamicW, fixedH)
        _shadow.Position = UDim2.fromOffset(renderX + 2, renderY + 3)
        _shadow.BackgroundTransparency = 1.0 - (0.18 * easedT)
    end)
end

function Tooltip.Show(text: string, targets: TooltipTarget?)
    if not text or text == "" then
        Tooltip.Hide()
        return
    end

    initTheme()

    if _animProgress > 0.001 then
        _pendingText = text
        _pendingTargets = targets
        _isHovered = false
        _hoverDelayTimer = 0
    else
        _currentText = text
        _currentTargets = targets
        _isHovered = true
        _hoverDelayTimer = 0
    end

    local hostGui = findHostScreenGui(targets)
    if hostGui then
        ensureOverlay(hostGui)
    end

    ensureRenderLoop()
end

function Tooltip.Hide()
    _isHovered = false
    _currentTargets = nil
    _pendingText = nil
    _pendingTargets = nil
    ensureRenderLoop()
end

function Tooltip.Attach(targets: TooltipTarget, text: string)
    if not text or text == "" then
        return
    end

    initTheme()

    local targetList: { GuiObject } = {}
    if typeof(targets) == "table" and not (typeof(targets) == "Instance") then
        for _, item in targets :: { any } do
            if typeof(item) == "Instance" and item:IsA("GuiObject") then
                table.insert(targetList, item)
            end
        end
    elseif typeof(targets) == "Instance" and (targets :: Instance):IsA("GuiObject") then
        table.insert(targetList, targets :: GuiObject)
    end

    if #targetList == 0 then
        return
    end

    for _, elem in targetList do
        elem:SetAttribute("Description", text)
    end

    local conns: { RBXScriptConnection } = {}

    local function handlePointerEnter()
        local rep = targetList[1]
        local activeText = (rep and rep:GetAttribute("Description")) or text
        Tooltip.Show(activeText, targetList)
    end

    for _, elem in targetList do
        table.insert(conns, elem.MouseEnter:Connect(handlePointerEnter))
    end

    local first = targetList[1]
    if first then
        table.insert(conns, first.Destroying:Connect(function()
            for _, conn in conns do
                pcall(function() conn:Disconnect() end)
            end
            table.clear(conns)
            if _currentTargets == targetList or _pendingTargets == targetList then
                Tooltip.Hide()
            end
        end))
    end
end

setmetatable(Tooltip, {
    __call = function(_, config: TooltipConfig)
        if config.Target then
            Tooltip.Attach(config.Target, config.Text)
        end
        return Tooltip
    end,
})

return Tooltip
