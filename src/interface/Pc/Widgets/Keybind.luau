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

local _pillApis = setmetatable({}, { __mode = "k" })
local _rowHandlers = setmetatable({}, { __mode = "k" })

local MODIFIER_KEYS = {
    [Enum.KeyCode.LeftShift] = "Shift",
    [Enum.KeyCode.RightShift] = "Shift",
    [Enum.KeyCode.LeftControl] = "Ctrl",
    [Enum.KeyCode.RightControl] = "Ctrl",
    [Enum.KeyCode.LeftAlt] = "Alt",
    [Enum.KeyCode.RightAlt] = "Alt",
    [Enum.KeyCode.LeftMeta] = "Win",
    [Enum.KeyCode.RightMeta] = "Win",
}

export type RowConfig = {
    Label: string,
    LayoutOrder: number?,
    Width: UDim2?,
    OnClick: (() -> ())?,
}

export type OverlayConfig = {
    LayoutOrder: number?,
}

export type KeybindConfig = {
    Label: string,
    Key: string,
    LayoutOrder: number?,
    Callback: ((Enum.KeyCode?) -> ())?,
}

local function IsModifier(keyCode: Enum.KeyCode?): boolean
    return keyCode ~= nil and MODIFIER_KEYS[keyCode] ~= nil
end

local function HeldModifiers(): { string }
    local seen: { [string]: boolean } = {}
    local list: { string } = {}
    for keyCode, label in MODIFIER_KEYS do
        if UserInputService:IsKeyDown(keyCode)
            and seen[label] ~= true
        then
            seen[label] = true
            table.insert(list, label)
        end
    end
    table.sort(list)
    return list
end

local function ModsLabel(mods: { string }?): string
    if mods == nil or #mods == 0 then
        return ""
    end
    return table.concat(mods, "+") .. "+"
end

local function BindLabel(keyCode: Enum.KeyCode?, mods: { string }?): string
    if keyCode == nil then
        return "None"
    end
    local own = MODIFIER_KEYS[keyCode]
    if own ~= nil then
        return own
    end
    return ModsLabel(mods) .. keyCode.Name
end

local function ModsEqual(a: { string }?, b: { string }?): boolean
    local left = a or {}
    local right = b or {}
    if #left ~= #right then
        return false
    end
    for index, value in left do
        if right[index] ~= value then
            return false
        end
    end
    return true
end

local function Row(config: RowConfig): TextButton
    init()

    local labelPrefix = (config.Label or "") .. ": "
    local keyText = "None"

    local btn = Instance.new("TextButton")
    btn.Name = "KeybindRow"
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.BackgroundTransparency = 1
    btn.BorderSizePixel = 0
    btn.Size = config.Width or UDim2.new(1, 0, 0, Theme.Layout.ButtonHeight)
    btn.Selectable = false
    btn.LayoutOrder = config.LayoutOrder or 0

    local bg = Instance.new("Frame")
    bg.Name = "Rectangle 1"
    bg.Active = true
    bg.BackgroundColor3 = Theme.Colors.ButtonBG
    bg.BackgroundTransparency = Theme.Colors.WindowBGTransparent
    bg.BorderSizePixel = 0
    bg.Size = UDim2.fromScale(1, 1)
    bg.Parent = btn

    local corner = Instance.new("UICorner")
    corner.CornerRadius = Theme.Layout.ButtonCorner
    corner.Parent = bg

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Active = true
    title.BackgroundTransparency = 1
    title.BorderSizePixel = 0
    title.Size = UDim2.new(1, 0, 1, -2)
    title.FontFace = Theme.GetFontFace()
    title.Text = labelPrefix .. keyText
    title.TextColor3 = Theme.Colors.ButtonText
    title.TextSize = Theme.Font.Body
    title.TextTransparency = Theme.Colors.WindowBGTransparent
    title.TextWrapped = true
    title.ZIndex = 2
    title.Parent = btn

    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.BackgroundColor3 = Color3.new(0, 0, 0)
    shadow.BackgroundTransparency = 1
    shadow.BorderSizePixel = 0
    shadow.Position = UDim2.fromOffset(1, 2)
    shadow.Size = UDim2.fromScale(1, 1)
    shadow.ZIndex = 0
    shadow.Parent = btn
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = Theme.Layout.ButtonCorner
    shadowCorner.Parent = shadow

    local baseRadius = Theme.Layout.ButtonCorner.Offset
    local tHeld = 0
    local targetHeld = 0
    local th = 0
    local targetTh = 0
    local loopConn: RBXScriptConnection? = nil
    local function ensureLoop()
        if loopConn then
            return
        end
        local conn: RBXScriptConnection
        conn = RunService.RenderStepped:Connect(function(dt: number)
            local settled = true
            local speed = if targetHeld == 1 then 10 else 6
            local nextHeld = tHeld + (targetHeld - tHeld) * math.min(1, dt * speed)
            if math.abs(nextHeld - targetHeld) < 0.004 then
                tHeld = targetHeld
            else
                tHeld = nextHeld
                settled = false
            end

            local nextTh = th
                + (targetTh - th) * math.min(1, dt * Theme.Animation.ToggleHoverSpeed)
            if math.abs(nextTh - targetTh) < 0.004 then
                th = targetTh
            else
                th = nextTh
                settled = false
            end

            local eased = math.clamp(tHeld, 0, 1)
            eased = eased * eased * eased * (eased * (eased * 6 - 15) + 10)

            corner.CornerRadius = UDim.new(
                0, math.floor(baseRadius * (1 - eased * 0.8) + 0.5))
            shadowCorner.CornerRadius = corner.CornerRadius
            shadow.BackgroundTransparency = 1 - 0.14 * (1 - eased)
            bg.BackgroundColor3 = Theme.Colors.ButtonBG
                :Lerp(Theme.Colors.ButtonBGHover, th)
                :Lerp(Theme.Colors.ButtonBGActive, eased)
            title.TextColor3 = Theme.Colors.ButtonText
                :Lerp(Theme.Colors.ButtonTextHover, th)
                :Lerp(Theme.Colors.ButtonTextActive, eased)

            if conn ~= nil and settled and tHeld == targetHeld then
                loopConn = nil
                conn:Disconnect()
            end
        end)
        loopConn = conn
    end

    btn.MouseButton1Down:Connect(function()
        targetTh = 1
        targetHeld = 1
        ensureLoop()
    end)
    btn.MouseButton1Up:Connect(function()
        targetHeld = 0
        ensureLoop()
    end)
    btn.MouseEnter:Connect(function()
        targetTh = 1
        ensureLoop()
    end)
    btn.MouseLeave:Connect(function()
        targetTh = 0
        targetHeld = 0
        ensureLoop()
    end)

    if config.OnClick then
        btn.Activated:Connect(function()
            config.OnClick()
        end)
    end

    btn.Destroying:Connect(function()
        if loopConn ~= nil then
            loopConn:Disconnect()
            loopConn = nil
        end
        _pillApis[btn] = nil
        _rowHandlers[btn] = nil
    end)

    local api = {
        Button = btn,
        Title = title,
        SetKeyText = function(text: string)
            keyText = text
            title.Text = labelPrefix .. keyText
        end,
        GetKeyText = function(): string
            return keyText
        end,
    }
    _pillApis[btn] = api
    return btn
end

local function Overlay(config: OverlayConfig): TextButton
    init()

    local btn = Instance.new("TextButton")
    btn.Name = "KeybindOverlay"
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.BackgroundTransparency = 1
    btn.BorderSizePixel = 0
    btn.Size = UDim2.fromOffset(40, Theme.Layout.ToggleHeight)
    btn.Selectable = false
    btn.LayoutOrder = config.LayoutOrder or 0

    local bg = Instance.new("Frame")
    bg.Name = "Rectangle 1"
    bg.Active = true
    bg.BackgroundColor3 = Theme.Colors.ButtonBG
    bg.BackgroundTransparency = Theme.Colors.WindowBGTransparent
    bg.BorderSizePixel = 0
    bg.Size = UDim2.fromScale(1, 1)
    bg.Parent = btn

    local corner = Instance.new("UICorner")
    local baseRadius = Theme.Layout.ButtonCorner.Offset
    corner.CornerRadius = Theme.Layout.ButtonCorner
    corner.Parent = bg

    local title = Instance.new("TextLabel")
    title.Name = "Text"
    title.Active = true
    title.BackgroundTransparency = 1
    title.BorderSizePixel = 0
    title.Size = UDim2.new(1, 0, 1, -2)
    title.FontFace = Theme.GetFontFace()
    title.Text = "None"
    title.TextColor3 = Theme.Colors.ButtonText
    title.TextSize = 12
    title.TextTransparency = Theme.Colors.WindowBGTransparent
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.ZIndex = 2
    title.Parent = btn

    local tHeld = 0
    local targetHeld = 0
    local th = 0
    local targetTh = 0
    local loopConn: RBXScriptConnection? = nil
    local function ensureLoop()
        if loopConn then
            return
        end
        local conn: RBXScriptConnection
        conn = RunService.RenderStepped:Connect(function(dt: number)
            local settled = true
            local speed = if targetHeld == 1 then 10 else 6
            local nextHeld = tHeld + (targetHeld - tHeld) * math.min(1, dt * speed)
            if math.abs(nextHeld - targetHeld) < 0.004 then
                tHeld = targetHeld
            else
                tHeld = nextHeld
                settled = false
            end

            local nextTh = th
                + (targetTh - th) * math.min(1, dt * Theme.Animation.ToggleHoverSpeed)
            if math.abs(nextTh - targetTh) < 0.004 then
                th = targetTh
            else
                th = nextTh
                settled = false
            end

            local eased = math.clamp(tHeld, 0, 1)
            eased = eased * eased * eased * (eased * (eased * 6 - 15) + 10)

            corner.CornerRadius = UDim.new(
                0, math.floor(baseRadius * (1 - eased * 0.8) + 0.5))
            bg.BackgroundColor3 = Theme.Colors.ButtonBG
                :Lerp(Theme.Colors.ButtonBGHover, th)
                :Lerp(Theme.Colors.ButtonBGActive, eased)
            title.TextColor3 = Theme.Colors.ButtonText
                :Lerp(Theme.Colors.ButtonTextHover, th)
                :Lerp(Theme.Colors.ButtonTextActive, eased)

            if conn ~= nil and settled and tHeld == targetHeld then
                loopConn = nil
                conn:Disconnect()
            end
        end)
        loopConn = conn
    end

    btn.MouseButton1Down:Connect(function()
        targetTh = 1
        targetHeld = 1
        ensureLoop()
    end)
    btn.MouseButton1Up:Connect(function()
        targetHeld = 0
        ensureLoop()
    end)
    btn.MouseEnter:Connect(function()
        targetTh = 1
        ensureLoop()
    end)
    btn.MouseLeave:Connect(function()
        targetTh = 0
        targetHeld = 0
        ensureLoop()
    end)

    btn.Destroying:Connect(function()
        if loopConn ~= nil then
            loopConn:Disconnect()
            loopConn = nil
        end
        _rowHandlers[btn] = nil
    end)

    return btn
end

local KeybindModule = {
    Row = Row,
    Overlay = Overlay,
    IsModifier = IsModifier,
    HeldModifiers = HeldModifiers,
    ModsLabel = ModsLabel,
    BindLabel = BindLabel,
    ModsEqual = ModsEqual,
    PillApis = _pillApis,
}

function KeybindModule.OverlayTextLabel(overlay: TextButton): TextLabel?
    local label = overlay:FindFirstChild("Text")
    if label ~= nil and label:IsA("TextLabel") then
        return label :: TextLabel
    end
    return nil
end

return KeybindModule
