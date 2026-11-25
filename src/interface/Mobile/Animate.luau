local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Animate = {}

function Animate.Tween(inst: Instance, seconds: number?, style: Enum.EasingStyle?, dir: Enum.EasingDirection?, props: { [string]: any }): Tween
    local info = TweenInfo.new(
        seconds or 0.2,
        style or Enum.EasingStyle.Quad,
        dir or Enum.EasingDirection.Out
    )
    local tween = TweenService:Create(inst, info, props)
    tween:Play()
    return tween
end

function Animate.PopIn(object: Instance, scale: UIScale, delay: number?, from: number?, seconds: number?)
    local fromScale = if from ~= nil then from else 0.85
    local duration = if seconds ~= nil then seconds else 0.25
    task.delay(delay or 0, function()
        if object.Parent == nil or scale.Parent == nil then
            return
        end
        scale.Scale = fromScale
        Animate.Tween(scale, duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
    end)
end

function Animate.FadeText(label: any, delay: number?, seconds: number?)
    task.delay(delay or 0, function()
        if label.Parent ~= nil then
            label.TextTransparency = 1
            Animate.Tween(label, seconds or 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { TextTransparency = 0 })
        end
    end)
end

export type HoldFeedbackConfig = {
    Grow: number?,
    GrowTime: number?,
    GrowStyle: Enum.EasingStyle?,
    Shrink: number?,
    ShrinkDelay: number?,
    ShrinkTime: number?,
    ReleaseTime: number?,
    ReleaseStyle: Enum.EasingStyle?,
    ReleaseInstant: boolean?,
    FullShake: boolean?,
    Filter: ((Vector3) -> boolean)?,
}

function Animate.HoldFeedback(source: any, target: GuiObject, config: HoldFeedbackConfig?): any
    local grow = if config ~= nil and config.Grow ~= nil then config.Grow else 1.14
    local growTime = if config ~= nil and config.GrowTime ~= nil then config.GrowTime else 0.12
    local growStyle = if config ~= nil and config.GrowStyle ~= nil then config.GrowStyle else Enum.EasingStyle.Back
    local shrink = if config ~= nil and config.Shrink ~= nil then config.Shrink else nil
    local shrinkDelay = if config ~= nil and config.ShrinkDelay ~= nil then config.ShrinkDelay else 0.35
    local shrinkTime = if config ~= nil and config.ShrinkTime ~= nil then config.ShrinkTime else 0.45
    local releaseTime = if config ~= nil and config.ReleaseTime ~= nil then config.ReleaseTime else 0.2
    local releaseInstant = if config ~= nil and config.ReleaseInstant == true then true else false
    local fullShake = if config ~= nil and config.FullShake == true then true else false
    local releaseStyle = if config ~= nil and config.ReleaseStyle ~= nil then config.ReleaseStyle else Enum.EasingStyle.Back
    local filter = if config ~= nil and config.Filter ~= nil then config.Filter else nil

    local scale = target:FindFirstChildOfClass("UIScale")
    if scale == nil then
        scale = Instance.new("UIScale")
        scale.Scale = 1
        scale.Parent = target
    end

    local connections: { RBXScriptConnection } = {}
    local held = false
    local token = 0
    local currentTween: Tween? = nil
    local currentPosTween: Tween? = nil
    local growStarted = 0
    local basePos = target.Position
    local pivotX = target.AnchorPoint.X - 0.5
    local pivotY = target.AnchorPoint.Y - 0.5
    local sizeXScale = target.Size.X.Scale
    local sizeXOffset = target.Size.X.Offset
    local sizeYScale = target.Size.Y.Scale
    local sizeYOffset = target.Size.Y.Offset

    local function posComp(scaleValue: number): UDim2
        local f = scaleValue - 1
        return UDim2.new(
            f * sizeXScale * pivotX,
            f * sizeXOffset * pivotX,
            f * sizeYScale * pivotY,
            f * sizeYOffset * pivotY
        )
    end

    local function stopTween()
        if currentTween ~= nil then
            pcall(function()
                currentTween:Cancel()
            end)
            currentTween = nil
        end
        if currentPosTween ~= nil then
            pcall(function()
                currentPosTween:Cancel()
            end)
            currentPosTween = nil
        end
    end

    local function startRelease()
        stopTween()
        if releaseInstant then
            scale.Scale = 1
            target.Position = basePos
            return
        end
        currentTween = Animate.Tween(scale, releaseTime, releaseStyle, Enum.EasingDirection.Out, { Scale = 1 })
        currentPosTween = Animate.Tween(target, releaseTime, releaseStyle, Enum.EasingDirection.Out, { Position = basePos })
    end

    local function release()
        if not held then
            return
        end
        held = false
        token += 1
        local myToken = token
        if fullShake and currentTween ~= nil then
            local remaining = growTime - (os.clock() - growStarted)
            if remaining > 0 then
                task.delay(remaining, function()
                    if myToken ~= token then
                        return
                    end
                    startRelease()
                end)
                return
            end
        end
        startRelease()
    end

    local function press()
        held = true
        token += 1
        local myToken = token
        stopTween()
        if scale.Scale == 1 then
            basePos = target.Position
        end
        growStarted = os.clock()
        currentTween = Animate.Tween(scale, growTime, growStyle, Enum.EasingDirection.Out, { Scale = grow })
        currentPosTween = Animate.Tween(target, growTime, growStyle, Enum.EasingDirection.Out, {
            Position = basePos + posComp(grow),
        })
        if shrink ~= nil then
            task.delay(shrinkDelay, function()
                if not held or myToken ~= token then
                    return
                end
                currentTween = Animate.Tween(scale, shrinkTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = shrink })
                currentPosTween = Animate.Tween(target, shrinkTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
                    Position = basePos + posComp(shrink),
                })
            end)
        end
    end

    local function snap()
        held = false
        token += 1
        stopTween()
        scale.Scale = 1
        target.Position = basePos
    end

    local function reverse()
        held = false
        token += 1
        stopTween()
        currentTween = Animate.Tween(scale, growTime, growStyle, Enum.EasingDirection.Out, { Scale = 1 })
        currentPosTween = Animate.Tween(target, growTime, growStyle, Enum.EasingDirection.Out, { Position = basePos })
    end

    table.insert(connections, source.InputBegan:Connect(function(input: InputObject)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        if filter ~= nil and not filter(input.Position) then
            return
        end
        press()
    end))

    table.insert(connections, UserInputService.InputEnded:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            release()
        end
    end))

    return {
        Scale = scale,
        Press = press,
        Release = release,
        Snap = snap,
        Reverse = reverse,
        Destroy = function()
            for _, conn in connections do
                pcall(function()
                    conn:Disconnect()
                end)
            end
            table.clear(connections)
        end,
    }
end

return Animate
