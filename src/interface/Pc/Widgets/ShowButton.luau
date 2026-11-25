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

export type ShowButtonConfig = {
    Image: string?,
    Size: number?,
    LayoutOrder: number?,
    Callback: (() -> ())?,
}

local function ShowButton(config: ShowButtonConfig): ImageButton
    init()

    local sizeH = config.Size or 18
    local btn = Instance.new("ImageButton")
    btn.Name = "Show"
    btn.BackgroundTransparency = 1
    btn.BorderSizePixel = 0
    btn.Selectable = false
    btn.Image = config.Image or "rbxassetid://116359281861345"
    btn.Size = UDim2.fromOffset(sizeH, sizeH)
    btn.LayoutOrder = config.LayoutOrder or 0

    if config.Callback then
        btn.Activated:Connect(function()
            config.Callback()
        end)
    end

    btn:SetAttribute("WidgetType", "ShowButton")
    return btn
end

return ShowButton
