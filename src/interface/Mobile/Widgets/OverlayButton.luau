local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local function importMobileModule(name: string)
    local genv = (typeof(getgenv) == "function" and getgenv())
        or (typeof(_G) == "table" and _G)
        or {}
    local Import = genv.Import
    if Import then
        local module = Import("interface/Mobile/" .. name)
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

local function init()
    if not Theme then
        Theme = importMobileModule("Theme")
    end
    if not Animate then
        Animate = importMobileModule("Animate")
    end
end

export type OverlayButtonConfig = {
    Root: GuiObject,
    Size: number?,
    MinOpacity: number?,
    OnActivated: (() -> ())?,
}

local function OverlayButton(config: OverlayButtonConfig): any
    init()

    local colors = Theme.Colors
    local assets = Theme.GetAssets()
    local root = config.Root

    local iconSize = if config.Size ~= nil then config.Size else Theme.Layout.IconBase

    local idleTransparency = 0.2
    if typeof(config.MinOpacity) == "number" then
        idleTransparency = math.clamp(1 - (config.MinOpacity :: number), 0, 1)
    end

    local buttonImage = assets.ButtonUI
    local hasImage = buttonImage ~= nil and buttonImage ~= ""

    local button = Instance.new("Frame")
    button.Name = "ToggleIcon"
    button.Active = true
    button.AnchorPoint = Vector2.new(0.5, 0.5)
    button.BackgroundColor3 = colors.MenuBG
    button.BackgroundTransparency = if hasImage then 1 else idleTransparency
    button.BorderSizePixel = 0
    button.Position = UDim2.fromOffset(80, 500)
    button.Size = UDim2.fromOffset(iconSize, iconSize)
    button.ZIndex = 20
    button.Parent = root

    if not hasImage then
        local iconCorner = Instance.new("UICorner")
        iconCorner.CornerRadius = UDim.new(1, 0)
        iconCorner.Parent = button
    end

    local iconImage = Instance.new("ImageLabel")
    iconImage.Name = "ButtonImage"
    iconImage.BackgroundTransparency = 1
    iconImage.BorderSizePixel = 0
    iconImage.AnchorPoint = Vector2.new(0.5, 0.5)
    iconImage.Position = UDim2.fromScale(0.5, 0.5)
    iconImage.Size = UDim2.fromScale(1, 1)
    iconImage.ScaleType = Enum.ScaleType.Fit
    iconImage.Image = if hasImage then (buttonImage :: string) else ""
    iconImage.ImageTransparency = idleTransparency
    iconImage.Parent = button

    local function fadeVisual(value: number, seconds: number, style: Enum.EasingStyle)
        Animate.Tween(iconImage, seconds, style, Enum.EasingDirection.Out, {
            ImageTransparency = value,
        })
        if not hasImage then
            Animate.Tween(button, seconds, style, Enum.EasingDirection.Out, {
                BackgroundTransparency = value,
            })
        end
    end

    local target: Vector2? = nil
    local center: Vector2? = nil
    local dragging = false
    local moved = false
    local dragStartInput: Vector2? = nil
    local dragStartCenter: Vector2? = nil

    local connections: { RBXScriptConnection } = {}

    local function clampTarget()
        local t = target
        if t == nil then
            return
        end
        local size = root.AbsoluteSize
        if size.X <= 0 or size.Y <= 0 then
            return
        end
        local r = iconSize * 0.6
        local clampedX = math.clamp(t.X, r, math.max(r, size.X - r))
        local clampedY = math.clamp(t.Y, r, math.max(r, size.Y - r))
        if clampedX ~= t.X or clampedY ~= t.Y then
            target = Vector2.new(clampedX, clampedY)
        end
    end

    local function pressAnim()
        Animate.Tween(button, 0.08, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, {
            Size = UDim2.fromOffset(iconSize * 0.85, iconSize * 0.85),
        })
        fadeVisual(0.05, 0.08, Enum.EasingStyle.Linear)
    end

    local function releaseAnim()
        Animate.Tween(button, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out, {
            Size = UDim2.fromOffset(iconSize, iconSize),
        })
        task.delay(0.8, function()
            if dragging then
                return
            end
            if button.Parent ~= nil then
                fadeVisual(idleTransparency, 0.3, Enum.EasingStyle.Quad)
            end
        end)
    end

    table.insert(connections, RunService.RenderStepped:Connect(function(dt: number)
        local t = target
        local c = center
        if t == nil or c == nil then
            return
        end
        clampTarget()
        t = target :: Vector2
        if (t - c).Magnitude < 0.5 then
            return
        end
        local blend = math.min(1, 12 * dt)
        local nextCenter = c + (t - c) * blend
        center = nextCenter
        button.Position = UDim2.fromOffset(math.floor(nextCenter.X + 0.5), math.floor(nextCenter.Y + 0.5))
    end))

    button.InputBegan:Connect(function(input: InputObject)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        dragging = true
        moved = false
        dragStartInput = Vector2.new(input.Position.X, input.Position.Y)
        dragStartCenter = center
        pressAnim()
    end)

    table.insert(connections, UserInputService.InputChanged:Connect(function(input: InputObject)
        if not dragging then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        local startInput = dragStartInput
        local startCenter = dragStartCenter
        if startInput == nil or startCenter == nil then
            return
        end
        local delta = Vector2.new(input.Position.X, input.Position.Y) - startInput
        local r = iconSize * 0.5
        if not moved and delta.Magnitude <= r then
            return
        end
        moved = true
        target = startCenter + delta
    end))

    table.insert(connections, UserInputService.InputEnded:Connect(function(input: InputObject)
        if not dragging then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        dragging = false
        releaseAnim()
        if not moved then
            if typeof(config.OnActivated) == "function" then
                config.OnActivated()
            end
        end
    end))

    local function Destroy()
        for _, conn in connections do
            pcall(function()
                conn:Disconnect()
            end)
        end
        table.clear(connections)
        pcall(function()
            button:Destroy()
        end)
    end

    button.Destroying:Connect(Destroy)

    return {
        Button = button,
        GetSize = function(): number
            return iconSize
        end,
        SetSize = function(size: number)
            iconSize = size
            if not dragging then
                button.Size = UDim2.fromOffset(size, size)
            end
            clampTarget()
        end,
        SetCenter = function(v: Vector2)
            target = v
            center = v
            button.Position = UDim2.fromOffset(v.X, v.Y)
        end,
        SetMinOpacity = function(opacity: number)
            if typeof(opacity) ~= "number" then
                return
            end
            idleTransparency = math.clamp(1 - opacity, 0, 1)
            if not dragging then
                fadeVisual(idleTransparency, 0.25, Enum.EasingStyle.Quad)
            end
        end,
        GetCenter = function(): Vector2?
            return center
        end,
        ClampTarget = clampTarget,
        Destroy = Destroy,
    }
end

return OverlayButton
