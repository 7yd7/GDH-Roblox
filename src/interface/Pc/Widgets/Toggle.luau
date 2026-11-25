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

local moduleGenv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}
moduleGenv.GDH_ToggleRowApis = _rowApis

export type ToggleConfig = {
    Name: string,
    Default: boolean?,
    Cheating: boolean?,
    Description: string?,
    LayoutOrder: number?,
    Callback: ((boolean) -> ())?,
    Settings: { any }?,
}

local function Toggle(config: ToggleConfig): Frame
    init()

    local state = if config.Default ~= nil then config.Default else false

    local row = Instance.new("Frame")
    row.Name = config.Name
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, Theme.Layout.RowHeight)
    row.LayoutOrder = config.LayoutOrder or 0

    local pH = Theme.Layout.ToggleHeight
    local pW = math.floor(pH * 1.8 + 0.5)
    local inset = Theme.Layout.ToggleKnobInset
    local krBase = pH / 2 - inset
    local shrink = Theme.Layout.ToggleKnobShrink
    local lift = Theme.Layout.ToggleShadowLift
    local centerY = pH / 2

    local track = Instance.new("Frame")
    track.Name = if state then "On" else "Off"
    track.Active = false
    track.BackgroundColor3 = Theme.Colors.ToggleTrackOff
    track.BorderSizePixel = 0
    track.Size = UDim2.fromOffset(pW, pH)
    track.Position = UDim2.fromOffset(0, (Theme.Layout.RowHeight - pH) / 2)
    track.Parent = row

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local knobShadow = Instance.new("Frame")
    knobShadow.Name = "KnobShadow"
    knobShadow.BackgroundColor3 = Color3.new(0, 0, 0)
    knobShadow.BackgroundTransparency = 1 - Theme.Colors.ToggleKnobShadowAlpha
    knobShadow.BorderSizePixel = 0
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(1, 0)
    shadowCorner.Parent = knobShadow
    local initKr = krBase * 2
    local initCx = krBase + inset + (pW - pH) * (if state then 1 else 0)
    knobShadow.AnchorPoint = Vector2.new(0.5, 0.5)
    knobShadow.Size = UDim2.fromOffset(initKr + 2, initKr + 2)
    knobShadow.Position = UDim2.fromOffset(initCx, centerY + lift)
    knobShadow.Parent = track

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.BackgroundColor3 = Theme.Colors.ToggleKnobOff
    knob.BorderSizePixel = 0

    local knobStroke = Instance.new("UIStroke")
    knobStroke.Color = Color3.new(0, 0, 0)
    knobStroke.Thickness = 1
    knobStroke.Transparency = 1 - Theme.Colors.ToggleKnobShadowAlpha * Theme.Colors.ToggleKnobOutlineAlpha
    knobStroke.Parent = knob
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Size = UDim2.fromOffset(initKr, initKr)
    knob.Position = UDim2.fromOffset(initCx, centerY)
    knob.Parent = track

    local title = Instance.new("TextButton")
    title.Name = "Title"
    title.AutoButtonColor = false
    title.BackgroundTransparency = 1
    title.BorderSizePixel = 0
    title.Position = UDim2.fromOffset(pW + 4, 3)
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
    clickZone.Position = UDim2.fromOffset(0, (Theme.Layout.RowHeight - pH) / 2)
    clickZone.Size = UDim2.fromOffset(pW, pH)
    clickZone.ZIndex = 2
    clickZone.Parent = row

    if config.Description and config.Description ~= "" then
        row:SetAttribute("Description", config.Description)
        TooltipWidget.Attach({ clickZone, title }, config.Description)
    end

    local t = if state then 1 else 0
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
        local bgBase = mix(Theme.Colors.ToggleTrackOff, Theme.Colors.ToggleTrackOn, t)
        local bgHov = mix(Theme.Colors.ToggleTrackOffHover, Theme.Colors.ToggleTrackOnHover, t)
        local bgHeld = mix(Theme.Colors.ToggleTrackOffHeld, Theme.Colors.ToggleTrackOnHeld, t)
        track.BackgroundColor3 = mix(mix(bgBase, bgHov, th), bgHeld, tHeld)

        local knBase = mix(Theme.Colors.ToggleKnobOff, Theme.Colors.ToggleKnobOn, t)
        local knHov = mix(Theme.Colors.ToggleKnobOffHover, Theme.Colors.ToggleKnobOnHover, t)
        local knHeld = mix(Theme.Colors.ToggleKnobOffHeld, Theme.Colors.ToggleKnobOnHeld, t)
        knob.BackgroundColor3 = mix(mix(knBase, knHov, th), knHeld, tHeld)

        local kr = krBase - shrink * tHeld
        local cx = krBase + inset + (pW - pH) * t
        local d = kr * 2
        local rD = math.floor(d + 0.5)
        local rX = math.floor(cx + 0.5)
        knob.Size = UDim2.fromOffset(rD, rD)
        knob.Position = UDim2.fromOffset(rX, centerY)

        knobShadow.Size = UDim2.fromOffset(rD + 2, rD + 2)
        knobShadow.Position = UDim2.fromOffset(rX, math.floor(centerY + lift + 0.5))
    end

    apply()

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
                if math.abs(nextVal - target) < 0.004 then
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

    local function toggle()
        state = not state
        targetT = if state then 1 else 0
        track.Name = if state then "On" else "Off"
        row:SetAttribute("State", state)
        ensureLoop()
        if config.Callback then
            config.Callback(state)
        end
    end

    local hovered = {}
    local function syncHover()
        targetHov = if next(hovered) ~= nil then 1 else 0
        ensureLoop()
    end
    local function bindClickable(el: TextButton, key: string)
        el.Activated:Connect(toggle)
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

    row.Destroying:Connect(function()
        if loopConn then
            loopConn:Disconnect()
            loopConn = nil
        end
        inputConn:Disconnect()
    end)

    row:SetAttribute("State", state)
    row:SetAttribute("WidgetType", "Toggle")
    row:SetAttribute("GDHToggleRow", true)
    row:SetAttribute("Cheating", config.Cheating == true)

    local api = {}
    function api.SetState(newState: boolean)
        if state ~= newState then
            toggle()
        end
    end
    function api.GetState(): boolean
        return state
    end

    _rowApis[row] = api
    return row
end

return Toggle
