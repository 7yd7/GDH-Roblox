local RunService = game:GetService("RunService")

local Animate = {}
Animate.__index = Animate

local Easing = {}

function Easing.Linear(t: number): number
    return t
end

function Easing.EaseInQuad(t: number): number
    return t * t
end

function Easing.EaseOutQuad(t: number): number
    return t * (2 - t)
end

function Easing.EaseInOutQuad(t: number): number
    if t < 0.5 then
        return 2 * t * t
    end
    return -1 + (4 - 2 * t) * t
end

function Easing.EaseOutCubic(t: number): number
    local f = t - 1
    return f * f * f + 1
end

function Easing.EaseInOutCubic(t: number): number
    if t < 0.5 then
        return 4 * t * t * t
    end
    local f = 2 * t - 2
    return 0.5 * f * f * f + 1
end

function Easing.EaseOutExpo(t: number): number
    if t >= 1 then return 1 end
    return 1 - math.pow(2, -10 * t)
end

function Easing.EaseOutBack(t: number): number
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
end

function Easing.EaseOutElastic(t: number): number
    if t == 0 or t == 1 then return t end
    local c4 = (2 * math.pi) / 3
    return math.pow(2, -10 * t) * math.sin((t * 10 - 0.75) * c4) + 1
end

function Easing.Spring(t: number): number
    return 1 - math.exp(-6 * t) * math.cos(8 * t)
end

Animate.Easing = Easing

function Animate.Lerp(a: number, b: number, t: number): number
    return a + (b - a) * math.clamp(t, 0, 1)
end

function Animate.LerpUDim2(a: UDim2, b: UDim2, t: number): UDim2
    t = math.clamp(t, 0, 1)
    return UDim2.new(
        a.X.Scale + (b.X.Scale - a.X.Scale) * t,
        math.floor(a.X.Offset + (b.X.Offset - a.X.Offset) * t),
        a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t,
        math.floor(a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t)
    )
end

function Animate.LerpColor3(a: Color3, b: Color3, t: number): Color3
    t = math.clamp(t, 0, 1)
    return Color3.new(
        a.R + (b.R - a.R) * t,
        a.G + (b.G - a.G) * t,
        a.B + (b.B - a.B) * t
    )
end

function Animate.SmoothDamp(current: number, target: number, speed: number, dt: number): number
    local factor = math.clamp(dt * speed, 0, 1)
    return current + (target - current) * factor
end

export type TweenConfig = {
    Duration: number?,
    EasingFunction: ((number) -> number)?,
    OnStep: ((number) -> ())?,
    OnComplete: (() -> ())?,
}

local ActiveTweens: {[string]: RBXScriptConnection} = {}
local TweenCounter = 0

function Animate.Tween(config: TweenConfig): string
    TweenCounter += 1
    local id = "tween_" .. TweenCounter

    local duration = config.Duration or 0.2
    local easingFn = config.EasingFunction or Easing.EaseOutQuad
    local onStep = config.OnStep
    local onComplete = config.OnComplete

    local elapsed = 0

    local connection: RBXScriptConnection
    connection = RunService.RenderStepped:Connect(function(dt)
        if ActiveTweens[id] ~= connection then
            connection:Disconnect()
            return
        end

        elapsed += dt
        local rawT = math.clamp(elapsed / math.max(duration, 0.001), 0, 1)
        local easedT = easingFn(rawT)

        if onStep then
            onStep(easedT)
        end

        if rawT >= 1 then
            ActiveTweens[id] = nil
            connection:Disconnect()
            if onComplete then
                onComplete()
            end
        end
    end)

    ActiveTweens[id] = connection
    return id
end

function Animate.CancelTween(id: string)
    local conn = ActiveTweens[id]
    if conn then
        ActiveTweens[id] = nil
        conn:Disconnect()
    end
end

function Animate.FadeIn(gui: GuiObject, duration: number?, easingFn: ((number) -> number)?)
    duration = duration or 0.15
    easingFn = easingFn or Easing.EaseOutQuad

    local targets = {}
    local function collectTransparency(obj: Instance)
        if obj:IsA("GuiObject") then
            table.insert(targets, {
                Object = obj,
                BackgroundStart = obj.BackgroundTransparency,
                BackgroundEnd = if obj:GetAttribute("_FadeTargetBG") then obj:GetAttribute("_FadeTargetBG") else obj.BackgroundTransparency,
            })
        end
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            local t = targets[#targets]
            if t then
                t.TextStart = 1
                t.TextEnd = obj.TextTransparency
            end
        end
        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
            local t = targets[#targets]
            if t then
                t.ImageStart = 1
                t.ImageEnd = obj.ImageTransparency
            end
        end
        for _, child in obj:GetChildren() do
            collectTransparency(child)
        end
    end

    gui.Visible = true
    collectTransparency(gui)

    return Animate.Tween({
        Duration = duration,
        EasingFunction = easingFn,
        OnStep = function(t)
            for _, info in targets do
                if info.BackgroundStart ~= nil then
                    info.Object.BackgroundTransparency = Animate.Lerp(1, info.BackgroundEnd, t)
                end
                if info.TextStart ~= nil then
                    (info.Object :: TextLabel).TextTransparency = Animate.Lerp(info.TextStart, info.TextEnd, t)
                end
                if info.ImageStart ~= nil then
                    (info.Object :: ImageLabel).ImageTransparency = Animate.Lerp(info.ImageStart, info.ImageEnd, t)
                end
            end
        end,
    })
end

function Animate.FadeOut(gui: GuiObject, duration: number?, easingFn: ((number) -> number)?)
    duration = duration or 0.15
    easingFn = easingFn or Easing.EaseOutQuad

    local targets = {}
    local function collectTransparency(obj: Instance)
        if obj:IsA("GuiObject") then
            table.insert(targets, {
                Object = obj,
                BackgroundStart = obj.BackgroundTransparency,
            })
        end
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            local t = targets[#targets]
            if t then
                t.TextStart = (obj :: TextLabel).TextTransparency
            end
        end
        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
            local t = targets[#targets]
            if t then
                t.ImageStart = (obj :: ImageLabel).ImageTransparency
            end
        end
        for _, child in obj:GetChildren() do
            collectTransparency(child)
        end
    end

    collectTransparency(gui)

    return Animate.Tween({
        Duration = duration,
        EasingFunction = easingFn,
        OnStep = function(t)
            for _, info in targets do
                if info.BackgroundStart ~= nil then
                    info.Object.BackgroundTransparency = Animate.Lerp(info.BackgroundStart, 1, t)
                end
                if info.TextStart ~= nil then
                    (info.Object :: TextLabel).TextTransparency = Animate.Lerp(info.TextStart, 1, t)
                end
                if info.ImageStart ~= nil then
                    (info.Object :: ImageLabel).ImageTransparency = Animate.Lerp(info.ImageStart, 1, t)
                end
            end
        end,
        OnComplete = function()
            gui.Visible = false
        end,
    })
end

function Animate.SlideIn(gui: GuiObject, from: string?, duration: number?)
    from = from or "Top"
    duration = duration or 0.25

    local targetPos = gui.Position
    local startPos: UDim2

    if from == "Top" then
        startPos = targetPos - UDim2.fromOffset(0, 30)
    elseif from == "Bottom" then
        startPos = targetPos + UDim2.fromOffset(0, 30)
    elseif from == "Left" then
        startPos = targetPos - UDim2.fromOffset(30, 0)
    elseif from == "Right" then
        startPos = targetPos + UDim2.fromOffset(30, 0)
    else
        startPos = targetPos - UDim2.fromOffset(0, 30)
    end

    gui.Position = startPos
    gui.Visible = true

    return Animate.Tween({
        Duration = duration,
        EasingFunction = Easing.EaseOutCubic,
        OnStep = function(t)
            gui.Position = Animate.LerpUDim2(startPos, targetPos, t)
        end,
    })
end

function Animate.ScalePop(gui: GuiObject, duration: number?)
    duration = duration or 0.2
    local originalSize = gui.Size

    return Animate.Tween({
        Duration = duration,
        EasingFunction = Easing.EaseOutBack,
        OnStep = function(t)
            local scale = Animate.Lerp(0.85, 1, t)
            gui.Size = UDim2.new(
                originalSize.X.Scale * scale,
                math.floor(originalSize.X.Offset * scale),
                originalSize.Y.Scale * scale,
                math.floor(originalSize.Y.Offset * scale)
            )
        end,
    })
end

function Animate.SmoothHeight(gui: GuiObject, targetHeight: number, duration: number?)
    duration = duration or 0.2
    local startHeight = gui.Size.Y.Offset

    return Animate.Tween({
        Duration = duration,
        EasingFunction = Easing.EaseOutCubic,
        OnStep = function(t)
            local h = math.floor(Animate.Lerp(startHeight, targetHeight, t))
            gui.Size = UDim2.new(gui.Size.X.Scale, gui.Size.X.Offset, 0, h)
        end,
    })
end

function Animate.ToggleSwitch(imageLabel: ImageLabel, isOn: boolean, onImage: string, offImage: string, duration: number?)
    duration = duration or 0.15

    return Animate.Tween({
        Duration = duration / 2,
        EasingFunction = Easing.EaseOutQuad,
        OnStep = function(t)
            imageLabel.ImageTransparency = t
        end,
        OnComplete = function()
            imageLabel.Image = if isOn then onImage else offImage
            Animate.Tween({
                Duration = duration / 2,
                EasingFunction = Easing.EaseOutQuad,
                OnStep = function(t)
                    imageLabel.ImageTransparency = 1 - t
                end,
            })
        end,
    })
end

return Animate
