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

export type ArrowButtonConfig = {
    Name: string,
    Direction: string?,
    LayoutOrder: number?,
    Callback: (() -> ())?,
}

local function ArrowButton(config: ArrowButtonConfig): ImageButton
    init()

    local H = Theme.Layout.ComboHeight

    local ARROW_IMAGE = "rbxassetid://124876571422197"
    local rotations = {
        Down = 0, Up = 180, Left = 90, Right = -90,
    }

    local btn = Instance.new("ImageButton")
    btn.Name = "ArrowButton" .. (config.Name or "")
    btn.AutoButtonColor = false
    btn.BackgroundTransparency = 1
    btn.BorderSizePixel = 0
    btn.Size = UDim2.fromOffset(H, H)
    btn.Image = ARROW_IMAGE

    btn.ImageColor3 = Color3.fromRGB(255, 255, 255)
    btn.ScaleType = Enum.ScaleType.Fit
    btn.Rotation = rotations[config.Direction or "Down"] or rotations.Down

    btn.Activated:Connect(function()
        if config.Callback then
            config.Callback()
        end
    end)

    btn:SetAttribute("Direction", config.Direction or "Down")
    btn:SetAttribute("WidgetType", "ArrowButton")
    return btn
end

return ArrowButton
