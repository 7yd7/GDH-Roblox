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
local ToggleWidget = importWidget("Toggle")
local TooltipWidget = importWidget("Tooltip")

local _rowApis = setmetatable({}, { __mode = "k" })

local moduleGenv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}
moduleGenv.GDH_SliderRowApis = _rowApis

export type SliderConfig = {
    Name: string?,
    Suffix: string?,
    Min: number?,
    Max: number?,
    Default: number?,
    Increment: number?,
    Precision: number?,
    Toggle: boolean?,
    ToggleDefault: boolean?,
    ToggleCallback: ((boolean) -> ())?,
    LayoutOrder: number?,
    Callback: ((number) -> ())?,
    Description: string?,
}

local function Slider(config: SliderConfig): Frame
    init()

    local minV = config.Min or -math.huge
    local maxV = config.Max or math.huge
    local deltaMode = (minV == -math.huge) or (maxV == math.huge)
    local increment = if config.Increment ~= nil and config.Increment > 0
        then config.Increment
        else 1
    local precision = if config.Precision ~= nil
        then math.clamp(config.Precision, 0, 6)
        else 2
    local suffix = config.Suffix or ""
    local namePrefix = if config.Name ~= nil and config.Name ~= ""
        then config.Name .. ": "
        else ""
    local startV = if config.Default ~= nil then config.Default
        elseif minV > -math.huge then minV
        elseif maxV < math.huge then maxV
        else 0
    local value = math.clamp(startV, minV, maxV)

    local row = Instance.new("Frame")
    row.Name = config.Name or "Slider"
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, Theme.Layout.RowHeight)
    row.LayoutOrder = config.LayoutOrder or 0

    local togW = Theme.Layout.ToggleWidth
    local gap = Theme.Layout.InlineGapX or 8
    local hasToggle = config.Toggle == true
    local pH = Theme.Layout.SliderHeight
    local zoneY = (Theme.Layout.RowHeight - pH) / 2

    local pill = Instance.new("TextButton")
    pill.Name = "Pill"
    pill.AutoButtonColor = false
    pill.BackgroundColor3 = Theme.Colors.SliderBG
    pill.BorderSizePixel = 0
    pill.Position = UDim2.fromOffset(0, zoneY)

    pill.Size = UDim2.new(1, if hasToggle then -(togW + gap) else 0, 0, pH)
    pill.Text = ""
    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = UDim.new(1, 0)
    pillCorner.Parent = pill
    pill.Parent = row

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "Value"
    valueLabel.BackgroundTransparency = 1
    valueLabel.BorderSizePixel = 0
    valueLabel.Size = UDim2.fromScale(1, 1)
    valueLabel.FontFace = Theme.GetFontFace()
    valueLabel.TextSize = 16
    valueLabel.TextColor3 = Theme.Colors.SliderText
    valueLabel.Text = namePrefix .. string.format("%." .. precision .. "f", value) .. suffix
    valueLabel.TextXAlignment = Enum.TextXAlignment.Center
    valueLabel.TextYAlignment = Enum.TextYAlignment.Center
    valueLabel.TextWrapped = false
    valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
    valueLabel.ZIndex = 2
    valueLabel.Parent = pill

    local function norm(): number
        if maxV > minV then
            return (value - minV) / (maxV - minV)
        end
        return 0
    end

    local function applyValue(raw: number, fire: boolean)
        local v = math.clamp(raw, minV, maxV)
        if increment > 0 then

            local base = if minV > -math.huge then minV else 0
            local rel = math.floor((v - base) / increment + 0.5)
            v = math.clamp(base + rel * increment, minV, maxV)
        end
        value = v
        valueLabel.Text = namePrefix .. string.format("%." .. precision .. "f", value) .. suffix
        if fire and config.Callback then
            config.Callback(value)
        end
    end

    local api = {}
    function api.GetValue(): number
        return value
    end
    function api.SetValue(newValue: number)
        applyValue(newValue, true)
    end
    _rowApis[row] = api

    local th, tHeld = 0, 0
    local targetHov, targetHeld = 0, 0
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

            th = approach(th, targetHov, Theme.Animation.ToggleHoverSpeed)
            tHeld = approach(tHeld, targetHeld, Theme.Animation.ToggleHeldSpeed)

            pill.BackgroundColor3 = Theme.Colors.SliderBG
                :Lerp(Theme.Colors.SliderBGHover, th)
                :Lerp(Theme.Colors.SliderBGHeld, tHeld)
            valueLabel.TextColor3 = Theme.Colors.SliderText
                :Lerp(Theme.Colors.SliderTextHover, th)
                :Lerp(Theme.Colors.SliderTextHeld, tHeld)

            if conn ~= nil and settled
                and th == targetHov and tHeld == targetHeld
            then
                loopConn = nil
                conn:Disconnect()
            end
        end)
        loopConn = conn
    end

    local UIS = game:GetService("UserInputService")
    local GuiService = game:GetService("GuiService")
    local hovered, dragging = false, false
    local lastX: number? = nil

    local function pointerGuiPos(): Vector2
        local inset = GuiService:GetGuiInset()
        local loc = UIS:GetMouseLocation()
        return Vector2.new(loc.X - inset.X, loc.Y - inset.Y)
    end

    local function pointerGuiPosOf(input: InputObject): Vector2
        if input.UserInputType == Enum.UserInputType.Touch then
            return input.Position
        end
        return pointerGuiPos()
    end

    local function relFromPoint(pt: Vector2): number
        local innerW = pill.AbsoluteSize.X
        if innerW <= 0 then
            return norm()
        end
        return math.clamp((pt.X - pill.AbsolutePosition.X) / innerW, 0, 1)
    end

    pill.MouseEnter:Connect(function()
        hovered = true
        targetHov = 1
        ensureLoop()
    end)
    pill.MouseLeave:Connect(function()
        hovered = false
        if not dragging then
            targetHov = 0
            ensureLoop()
        end
    end)

    pill.MouseButton1Down:Connect(function()
        dragging = true
        lastX = nil
        targetHov = 1
        targetHeld = 1
        ensureLoop()

        if not deltaMode then
            applyValue(minV + (maxV - minV)
                * relFromPoint(pointerGuiPos()), true)
        end
    end)
    UIS.InputChanged:Connect(function(input: InputObject)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or
           input.UserInputType == Enum.UserInputType.Touch
        then
            if deltaMode then

                local x = pointerGuiPosOf(input).X
                if lastX == nil then
                    lastX = x
                else
                    local dx = x - lastX
                    lastX = x

                    if dx ~= 0 and math.abs(dx) < 400 then
                        applyValue(value + dx * increment, true)
                    end
                end
            else
                applyValue(minV + (maxV - minV)
                    * relFromPoint(pointerGuiPosOf(input)), true)
            end
        end
    end)
    UIS.InputEnded:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch
        then
            if dragging then
                dragging = false
                lastX = nil
                targetHeld = 0
                targetHov = if hovered then 1 else 0
                ensureLoop()
            end
        end
    end)

    UIS.InputChanged:Connect(function(input: InputObject)
        if input.UserInputType ~= Enum.UserInputType.MouseWheel then
            return
        end
        if not hovered then
            return
        end
        local dz = if input.Position.Z > 0 then increment else -increment
        applyValue(value + dz, true)
    end)

    if hasToggle then
        local switch = ToggleWidget({
            Name = "",
            Default = config.ToggleDefault,
            Callback = config.ToggleCallback,
        })
        switch.Name = "Switch"
        switch.Size = UDim2.fromOffset(togW, Theme.Layout.RowHeight)
        switch.Position = UDim2.new(1, -togW, 0, 0)
        switch.Parent = row
    end

    applyValue(value, false)

    if config.Description and config.Description ~= "" then
        TooltipWidget.Attach(row, config.Description)
    end

    return row
end

return Slider
