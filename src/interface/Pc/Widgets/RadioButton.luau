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
local TooltipWidget = importWidget("Tooltip")
local _rowApis = setmetatable({}, { __mode = "k" })

local _radioGroups = setmetatable({}, { __mode = "k" })

local moduleGenv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}
moduleGenv.GDH_RadioButtonApis = _rowApis
export type RadioButtonConfig = {
    Name: string,
    Group: string,
    Default: boolean?,
    Cheating: boolean?,
    Description: string?,
    Inline: boolean?,
    LayoutOrder: number?,
    Callback: ((boolean) -> ())?,
}

_radioGroups = _radioGroups
    or setmetatable({}, { __mode = "k" })

local function RadioButton(config: RadioButtonConfig): Frame
    init()

    local active = if config.Default ~= nil then config.Default else false

    local row = Instance.new("Frame")
    row.Name = config.Name
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.LayoutOrder = config.LayoutOrder or 0

    local H = Theme.Layout.ToggleHeight
    local ORr = H * 0.5
    local BW = 2
    local IR = ORr * 0.5

    local SR = ORr * Theme.Layout.RadioLayerScale
    local zoneY = (Theme.Layout.RowHeight - H) / 2

    local sink = Theme.Layout.RadioSink
    local centerY = zoneY + H * 0.5 + sink

    if config.Inline then
        local labelW = measureTextWidth(config.Name, Theme.Font.Body)
        row.Size = UDim2.fromOffset(H + 4 + labelW, Theme.Layout.RowHeight)
    else
        row.Size = UDim2.new(1, 0, 0, Theme.Layout.RowHeight)
    end

    local layer = Instance.new("Frame")
    layer.Name = "Layer"
    layer.BackgroundColor3 = Theme.Colors.RadioLayerOff
    layer.BackgroundTransparency = 1
    layer.BorderSizePixel = 0
    layer.AnchorPoint = Vector2.new(0.5, 0.5)
    layer.Position = UDim2.fromOffset(ORr, centerY)
    layer.Size = UDim2.fromOffset(SR * 2, SR * 2)
    local layerCorner = Instance.new("UICorner")
    layerCorner.CornerRadius = UDim.new(1, 0)
    layerCorner.Parent = layer
    layer.Parent = row

    local ring = Instance.new("Frame")
    ring.Name = "Ring"
    ring.BackgroundTransparency = 1
    ring.BorderSizePixel = 0
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = UDim2.fromOffset(ORr, centerY)
    local ringCorner = Instance.new("UICorner")
    ringCorner.CornerRadius = UDim.new(1, 0)
    ringCorner.Parent = ring
    local ringStroke = Instance.new("UIStroke")
    ringStroke.Color = Theme.Colors.RadioRingOff
    ringStroke.Thickness = BW
    ringStroke.Parent = ring
    ring.Parent = row

    local dotShadow = Instance.new("Frame")
    dotShadow.Name = "DotShadow"
    dotShadow.BackgroundColor3 = Color3.new(0, 0, 0)
    dotShadow.BackgroundTransparency = 1
    dotShadow.BorderSizePixel = 0
    dotShadow.AnchorPoint = Vector2.new(0.5, 0.5)
    dotShadow.Position = UDim2.fromOffset(ORr, centerY + 1)
    local dotShadowCorner = Instance.new("UICorner")
    dotShadowCorner.CornerRadius = UDim.new(1, 0)
    dotShadowCorner.Parent = dotShadow
    dotShadow.Parent = row

    local dot = Instance.new("Frame")
    dot.Name = "Dot"
    dot.BackgroundColor3 = Theme.Colors.RadioDotOn
    dot.BorderSizePixel = 0
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Position = UDim2.fromOffset(ORr, centerY)
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = dot
    dot.Parent = row

    local title = Instance.new("TextButton")
    title.Name = "Title"
    title.AutoButtonColor = false
    title.BackgroundTransparency = 1
    title.BorderSizePixel = 0
    title.Position = UDim2.fromOffset(H + 4, 3 + sink)
    title.Size = UDim2.fromOffset(0, 15)
    title.AutomaticSize = Enum.AutomaticSize.X
    title.FontFace = Theme.GetFontFace()
    title.Text = config.Name
    title.TextColor3 = if config.Cheating then Theme.Colors.TextDanger else Theme.Colors.TextSecondary
    title.TextSize = Theme.Font.Body
    title.TextTransparency = Theme.Colors.WindowBGTransparent
    title.TextWrapped = false
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextYAlignment = Enum.TextYAlignment.Top
    title.ZIndex = 2
    title.Parent = row

    local clickZone = Instance.new("TextButton")
    clickZone.Name = "ClickZone"
    clickZone.Text = ""
    clickZone.AutoButtonColor = false
    clickZone.BackgroundTransparency = 1
    clickZone.BorderSizePixel = 0
    clickZone.Position = UDim2.fromOffset(0, zoneY + sink)
    clickZone.Size = UDim2.fromOffset(H, H)
    clickZone.ZIndex = 2
    clickZone.Parent = row

    if config.Description and config.Description ~= "" then
        TooltipWidget.Attach({ clickZone, title }, config.Description)
    end

    local t = if active then 1 else 0
    local th, tHeld = 0, 0
    local targetT = t
    local targetHov, targetHeld = 0, 0

    local function mix(a: Color3, b: Color3, mixT: number): Color3
        return Color3.new(
            a.R + (b.R - a.R) * mixT,
            a.G + (b.G - a.G) * mixT,
            a.B + (b.B - a.B) * mixT
        )
    end

    local function apply()

        local ringBase = mix(Theme.Colors.RadioRingOff, Theme.Colors.RadioRingOn, t)
        local ringHov = mix(Theme.Colors.RadioRingOffHover, Theme.Colors.RadioRingOnHover, t)
        local ringHeld = mix(Theme.Colors.RadioRingOffHeld, Theme.Colors.RadioRingOnHeld, t)
        ringStroke.Color = mix(mix(ringBase, ringHov, th), ringHeld, tHeld)

        local ringW = BW + t * 0.4
        local rMid = ORr - ringW * 0.5
        ringStroke.Thickness = ringW
        local rD = math.floor(rMid * 2 + 0.5)
        ring.Size = UDim2.fromOffset(rD, rD)

        local dotR = IR * t * (1 - tHeld * 0.12)
        local dotD = math.floor(dotR * 2 + 0.5)
        dotD += dotD % 2
        dot.Size = UDim2.fromOffset(dotD, dotD)
        dotShadow.Size = UDim2.fromOffset(dotD + 2, dotD + 2)
        dotShadow.BackgroundTransparency = 1 - 0.15 * t
        dot.Visible = dotR > 0.5
        dotShadow.Visible = dotR > 0.5

        local dotTarget = mix(mix(Theme.Colors.RadioDotOn, Theme.Colors.RadioDotOnHover, th),
            Theme.Colors.RadioDotOnHeld, tHeld)
        dot.BackgroundColor3 = Color3.new(0, 0, 0):Lerp(dotTarget, t)
        dot.BackgroundTransparency = 1 - t
        dot:SetAttribute("_baseBG", 1 - t)
        dotShadow:SetAttribute("_baseBG", 1 - 0.15 * t)

        layer.BackgroundColor3 = mix(Theme.Colors.RadioLayerOff, Theme.Colors.RadioLayerOn, t)
        local layerA = Theme.Colors.RadioLayerAlpha
            + (Theme.Colors.RadioLayerAlphaHeld - Theme.Colors.RadioLayerAlpha) * tHeld
        local layerVis = math.max(0, math.min(1, layerA * (th + tHeld * 0.5)))
        layer.BackgroundTransparency = 1 - layerVis
    end

    local loopConn: RBXScriptConnection? = nil
    local function ensureLoop()
        if loopConn then
            return
        end
        local conn: RBXScriptConnection
        conn = RunService.RenderStepped:Connect(function(dt: number)
            local settled = true

            local function approach(val: number, target: number, speed: number): number

                local nextVal = val + (target - val) * (1 - math.exp(-dt * speed))
                if math.abs(nextVal - target) < 0.0005 then
                    return target
                end
                settled = false
                return nextVal
            end

            t = approach(t, targetT, Theme.Animation.ToggleSpeed)
            th = approach(th, targetHov, Theme.Animation.ToggleHoverSpeed)
            tHeld = approach(tHeld, targetHeld, Theme.Animation.ToggleHeldSpeed)

            apply()

            if conn ~= nil and settled
                and t == targetT and th == targetHov and tHeld == targetHeld
            then
                loopConn = nil
                conn:Disconnect()
            end
        end)
        loopConn = conn
    end

    local group = _radioGroups[config.Group]
    if not group then
        group = setmetatable({}, { __mode = "k" })
        _radioGroups[config.Group] = group
    end

    local function setActiveState(newState: boolean, fire: boolean)
        if active ~= newState then
            active = newState
            targetT = if active then 1 else 0
            row:SetAttribute("Active", active)
            dot:SetAttribute("_baseBG", if active then 0 else 1)
            dotShadow:SetAttribute("_baseBG", if active then 0.85 else 1)
            ensureLoop()
            if fire and active and config.Callback then
                config.Callback(true)
            end
        end
    end

    local function deselect()
        setActiveState(false, false)
    end

    local function select()
        if active then
            return
        end
        for otherRow, otherApi in group do
            if otherRow ~= row then
                (otherApi :: { _deselect: () -> () })._deselect()
            end
        end
        setActiveState(true, true)
    end

    local hovered = {}
    local function syncHover()
        targetHov = if next(hovered) ~= nil then 1 else 0
        ensureLoop()
    end
    local function bindClickable(el: TextButton, key: string)
        el.Activated:Connect(select)
        el.MouseEnter:Connect(function()
            hovered[key] = true
            syncHover()
        end)
        el.MouseLeave:Connect(function()
            hovered[key] = nil
            syncHover()
        end)
        el.MouseButton1Down:Connect(function()
            targetHeld = 1
            ensureLoop()
        end)
        el.MouseButton1Up:Connect(function()
            targetHeld = 0
            ensureLoop()
        end)
    end
    bindClickable(clickZone, "zone")
    bindClickable(title, "title")

    local inputConn = UserInputService.InputEnded:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            if targetHeld ~= 0 then
                targetHeld = 0
                ensureLoop()
            end
        end
    end)

    local api = {}
    api._deselect = deselect
    api.Refresh = apply
    function api.SetActive(newState: boolean)
        setActiveState(newState, true)
    end
    function api.GetActive(): boolean
        return active
    end

    group[row] = api
    row.Destroying:Connect(function()
        if loopConn then
            loopConn:Disconnect()
            loopConn = nil
        end
        inputConn:Disconnect()
        group[row] = nil
    end)

    row:SetAttribute("Active", active)
    row:SetAttribute("Group", config.Group)
    row:SetAttribute("WidgetType", "RadioButton")
    dot:SetAttribute("_baseBG", if active then 0 else 1)
    dotShadow:SetAttribute("_baseBG", if active then 0.85 else 1)
    _rowApis[row] = api
    apply()

    row:GetPropertyChangedSignal("Visible"):Connect(function()
        if row.Visible then
            apply()
        end
    end)

    row.AncestryChanged:Connect(function()
        if row.Parent ~= nil and row.Visible then
            apply()
        end
    end)

    return row
end

return RadioButton
