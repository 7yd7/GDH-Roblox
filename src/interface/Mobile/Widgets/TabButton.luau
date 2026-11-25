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
local PressFlow = nil

local function init()
    if not Theme then
        Theme = importMobileModule("Theme")
    end
    if not Animate then
        Animate = importMobileModule("Animate")
    end
    if not PressFlow then
        PressFlow = importMobileModule("PressFlow")
    end
end

export type TabButtonConfig = {
    Parent: Instance,
    Title: string,
    Order: number?,
    OnActivated: (() -> ())?,
}

local function TabButton(config: TabButtonConfig): any
    init()

    local layout = Theme.Layout
    local colors = Theme.Colors

    local holder = Instance.new("Frame")
    holder.Name = config.Title
    holder.BackgroundTransparency = 1
    holder.BorderSizePixel = 0
    holder.Size = UDim2.fromOffset(layout.TabW, layout.TabH)
    holder.LayoutOrder = config.Order or 0
    holder.Parent = config.Parent

    local button = Instance.new("TextButton")
    button.Name = config.Title
    button.AutoButtonColor = false
    button.BackgroundColor3 = colors.TabInactive
    button.BorderSizePixel = 0
    button.AnchorPoint = Vector2.new(0.5, 0.5)
    button.Position = UDim2.fromScale(0.5, 0.5)
    button.Size = UDim2.fromScale(1, 1)
    button.FontFace = Theme.GetFace()
    button.Text = config.Title
    button.TextColor3 = colors.TabInactiveText
    button.TextSize = layout.TabTextSize
    button.TextTruncate = Enum.TextTruncate.AtEnd
    button.Parent = holder

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, layout.TabCorner)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = colors.MenuStroke
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = button

    local feedback = Animate.HoldFeedback(button, button, {
        Grow = 1.15,
        GrowTime = 0.15,
        ReleaseTime = 0.6,
        ReleaseStyle = Enum.EasingStyle.Elastic,
    })

    local target = {
        Node = button,
        Activate = function()
            if typeof(config.OnActivated) == "function" then
                config.OnActivated()
            end
        end,
        PressIn = feedback.Press,
        PressOut = feedback.Reverse,
        Release = feedback.Release,
    }
    PressFlow.Register(target)

    button.InputBegan:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            PressFlow.Begin(target, input)
        end
    end)

    button.Activated:Connect(function()
        if typeof(config.OnActivated) == "function" then
            config.OnActivated()
        end
    end)

    local function SetActive(active: boolean)
        button.BackgroundColor3 = if active then colors.TabActive else colors.TabInactive
        button.TextColor3 = if active then colors.TabActiveText else colors.TabInactiveText
        stroke.Transparency = if active then 1 else 0
    end

    local function Destroy()
        feedback.Destroy()
        pcall(function()
            holder:Destroy()
        end)
    end

    return {
        Button = button,
        SetActive = SetActive,
        Destroy = Destroy,
    }
end

return TabButton
