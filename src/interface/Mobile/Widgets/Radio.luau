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

local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local Theme = nil
local Animate = nil
local PressFlow = nil
local FitText = nil

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
    if not FitText then
        FitText = importMobileModule("FitText")
    end
end

local groups: { [string]: { any } } = {}

export type RadioCellConfig = {
    Row: any?,
    Name: any?,
    Parent: Instance,
    Notify: ((string, number?) -> ())?,
    SliderSplit: string?,
}

local function RadioCell(config: RadioCellConfig): any
    init()

    local layout = Theme.Layout
    local colors = Theme.Colors

    local pcRow = config.Row
    local groupName = ""
    if typeof(pcRow) == "Instance" then
        groupName = tostring((pcRow :: Instance):GetAttribute("Group") or "")
    end

    local cell = Instance.new("TextButton")
    cell.Name = "Cell"
    cell.Text = ""
    cell.AutoButtonColor = false
    cell.BackgroundTransparency = 1
    cell.BorderSizePixel = 0
    if config.SliderSplit == "left" then
        cell.Size = UDim2.new(layout.SliderToggleX, -50, 0, layout.RowH)
    elseif config.SliderSplit == "right" then
        cell.Size = UDim2.new(1 - layout.SliderToggleX, 0, 0, layout.RowH)
    else
        cell.Size = UDim2.fromOffset(layout.CellW, layout.RowH)
    end
    cell.Parent = config.Parent

    local ringSize = 38
    local ring = Instance.new("Frame")
    ring.Name = "Ring"
    ring.BackgroundTransparency = 1
    ring.BorderSizePixel = 0
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = UDim2.fromOffset(layout.SwitchX + layout.SwitchW / 2, layout.RowH / 2)
    ring.Size = UDim2.fromOffset(ringSize, ringSize)
    ring.Parent = cell

    local ringCorner = Instance.new("UICorner")
    ringCorner.CornerRadius = UDim.new(1, 0)
    ringCorner.Parent = ring

    local ringStroke = Instance.new("UIStroke")
    ringStroke.Color = colors.RadioRingOff
    ringStroke.Thickness = 4
    ringStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    ringStroke.Parent = ring

    local dot = Instance.new("Frame")
    dot.Name = "Dot"
    dot.BackgroundColor3 = colors.TabActive
    dot.BorderSizePixel = 0
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Position = UDim2.fromScale(0.5, 0.5)
    dot.Size = UDim2.fromOffset(16, 16)
    dot.Visible = false
    dot.Parent = ring

    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = dot

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.Position = UDim2.fromOffset(layout.LabelX, 0)
    label.Size = UDim2.new(1, -(layout.LabelX + layout.LabelInset), 1, 0)
    label.FontFace = Theme.GetFace()
    label.Text = tostring(config.Name or "")
    label.TextColor3 = colors.TextPrimary
    label.TextSize = layout.LabelSize
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = cell
    FitText.fit(label, {
        Base = layout.LabelSize,
        Min = layout.LabelMinSize,
    })

    local infoBtnRef: TextButton? = nil

    local pcApi = nil
    local apis = genv.GDH_RadioButtonApis
    if typeof(apis) == "table" and typeof(pcRow) == "Instance" then
        pcApi = apis[pcRow :: Instance]
    end

    local function isActive(): boolean
        if typeof(pcApi) == "table" and typeof(pcApi.GetActive) == "function" then
            local ok, active = pcall(pcApi.GetActive)
            if ok and typeof(active) == "boolean" then
                return active
            end
        end
        if typeof(pcRow) == "Instance" then
            return (pcRow :: Instance):GetAttribute("Active") == true
        end
        return false
    end

    local function applyActive()
        local active = isActive()
        dot.Visible = active
        ringStroke.Color = if active then colors.TabActive else colors.RadioRingOff
    end

    local record = {
        Row = pcRow,
        IsActive = isActive,
        Deselect = function()
            if typeof(pcApi) == "table" and typeof(pcApi._deselect) == "function" then
                pcall(pcApi._deselect)
            elseif typeof(pcRow) == "Instance" then
                (pcRow :: Instance):SetAttribute("Active", false)
            end
            applyActive()
        end,
    }

    local list = groups[groupName]
    if list == nil then
        list = {}
        groups[groupName] = list
    end
    table.insert(list, record)

    local function prune()
        local current = groups[groupName]
        if current == nil then
            return
        end
        local alive: { any } = {}
        for _, item in current do
            local rowRef = item.Row
            if typeof(rowRef) == "Instance" and (rowRef :: Instance).Parent ~= nil then
                table.insert(alive, item)
            end
        end
        groups[groupName] = alive
    end

    local function select()
        prune()
        local current = groups[groupName]
        if current ~= nil then
            for _, item in current do
                if item ~= record and typeof(item.Deselect) == "function" then
                    pcall(item.Deselect)
                end
            end
        end
        if typeof(pcApi) == "table" and typeof(pcApi.SetActive) == "function" then
            pcall(pcApi.SetActive, true)
        elseif typeof(pcRow) == "Instance" then
            (pcRow :: Instance):SetAttribute("Active", true)
        end
        applyActive()
    end

    if typeof(pcRow) == "Instance" then
        local desc = (pcRow :: Instance):GetAttribute("Description")
        if typeof(desc) == "string" and desc ~= "" then
            local infoBtn = Instance.new("TextButton")
            infoBtn.Name = "Info"
            infoBtn.BackgroundTransparency = 1
            infoBtn.BorderSizePixel = 0
            infoBtn.AnchorPoint = Vector2.new(1, 0.5)
            infoBtn.Position = UDim2.new(1, -4, 0.5, 0)
            infoBtn.Size = UDim2.fromOffset(layout.InfoSize, layout.InfoSize)
            infoBtn.FontFace = Theme.GetFace()
            infoBtn.Text = "i"
            infoBtn.TextColor3 = colors.MenuStroke
            infoBtn.TextSize = 15
            infoBtn.Parent = cell
            infoBtnRef = infoBtn
            infoBtn.Activated:Connect(function()
                if typeof(config.Notify) == "function" then
                    config.Notify(tostring(desc), 5)
                end
            end)
        end
    end

    local feedback = Animate.HoldFeedback(cell, ring, {
        Grow = 1.18,
        GrowTime = 0.15,
        ReleaseTime = 0.6,
        ReleaseStyle = Enum.EasingStyle.Elastic,
    })

    local target = {
        Node = cell,
        Activate = select,
        PressIn = feedback.Press,
        PressOut = feedback.Reverse,
        Release = feedback.Release,
    }
    PressFlow.Register(target)

    local function isOverCell(pos: Vector3): boolean
        local abs = cell.AbsolutePosition
        local size = cell.AbsoluteSize
        return pos.X >= abs.X and pos.X <= abs.X + size.X
            and pos.Y >= abs.Y and pos.Y <= abs.Y + size.Y
    end

    local function isOverInfo(pos: Vector3): boolean
        local btn = infoBtnRef
        if btn == nil then
            return false
        end
        local absPos = btn.AbsolutePosition
        local absSize = btn.AbsoluteSize
        return pos.X >= absPos.X and pos.X <= absPos.X + absSize.X
            and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y
    end

    local pressStart: Vector3? = nil
    local pressTime = 0
    local pressOnInfo = false

    cell.InputBegan:Connect(function(input: InputObject)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        pressStart = input.Position
        pressTime = os.clock()
        pressOnInfo = isOverInfo(input.Position)
        if not pressOnInfo then
            PressFlow.Begin(target, input)
        end
    end)

    cell.InputEnded:Connect(function(input: InputObject)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        local start = pressStart
        local onInfo = pressOnInfo
        local elapsed = os.clock() - pressTime
        pressStart = nil
        pressOnInfo = false
        if start == nil or onInfo then
            return
        end
        if not isOverCell(input.Position) then
            return
        end
        if elapsed > 0.3 then
            return
        end
        local delta = Vector2.new(input.Position.X - start.X, input.Position.Y - start.Y)
        if delta.Magnitude > 20 then
            return
        end
        select()
    end)

    applyActive()

    return cell
end

return RadioCell
