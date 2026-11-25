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

export type SliderConfig = {
    Parent: Instance,
    Row: any?,
    Name: any?,
    Suffix: any?,
    Min: any?,
    Max: any?,
    Increment: any?,
    Precision: any?,
    HasToggle: any?,
    Center: boolean?,
}

local function SliderCell(config: SliderConfig): Frame
    init()

    local layout = Theme.Layout
    local colors = Theme.Colors

    local minV = if typeof(config.Min) == "number" then config.Min :: number else -math.huge
    local maxV = if typeof(config.Max) == "number" then config.Max :: number else math.huge
    local increment = 1
    if typeof(config.Increment) == "number" and (config.Increment :: number) > 0 then
        increment = config.Increment :: number
    end
    local precision = 2
    if typeof(config.Precision) == "number" then
        precision = math.clamp(config.Precision :: number, 0, 6)
    end
    local suffix = if typeof(config.Suffix) == "string" then config.Suffix :: string else ""
    local nameText = if typeof(config.Name) == "string" then config.Name :: string else ""
    local trimmedName = nameText:gsub("^%s+", ""):gsub("%s+$", "")
    local suffixText = suffix:gsub("^%s+", ""):gsub("%s+$", "")
    local labelText = trimmedName
    if suffixText ~= "" then
        if labelText ~= "" then
            labelText = labelText .. " " .. suffixText
        else
            labelText = suffixText
        end
    end
    local toggleTitle = ""
    if trimmedName ~= "" then
        toggleTitle = trimmedName .. " Enabled"
    elseif suffixText ~= "" then
        toggleTitle = suffixText .. " Enabled"
    end

    local pcApi = nil
    local apis = genv.GDH_SliderRowApis
    if typeof(apis) == "table" and typeof(config.Row) == "Instance" then
        local api = apis[config.Row :: Instance]
        if typeof(api) == "table" then
            pcApi = api
        end
    end

    local startV: number? = nil
    if typeof(pcApi) == "table" and typeof(pcApi.GetValue) == "function" then
        local ok, value = pcall(pcApi.GetValue)
        if ok and typeof(value) == "number" then
            startV = value
        end
    end
    if startV == nil then
        if minV > -math.huge then
            startV = minV
        elseif maxV < math.huge then
            startV = maxV
        else
            startV = 0
        end
    end
    local value: number = math.clamp(startV :: number, minV, maxV)

    local hasToggle = config.HasToggle == true
    local labelScale = if hasToggle then layout.SliderToggleX else 1
    local labelInset = if hasToggle then 12 else 0

    local row = Instance.new("Frame")
    row.Name = "Slider"
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, layout.RowH)
    row.Parent = config.Parent

    local centerMode = config.Center == true
    local centerAutoWidth = true
    local contentHost: Instance = row
    if centerMode then
        local holder = Instance.new("Frame")
        holder.Name = "Content"
        holder.BackgroundTransparency = 1
        holder.BorderSizePixel = 0
        if hasToggle then
            centerAutoWidth = false
            holder.AnchorPoint = Vector2.new(0, 0.5)
            holder.Position = UDim2.new(0, 8, 0.5, 0)
            holder.Size = UDim2.new(labelScale, -16, 1, 0)
        else
            holder.AnchorPoint = Vector2.new(0.5, 0.5)
            holder.Position = UDim2.fromScale(0.5, 0.5)
            holder.Size = UDim2.new(0, 0, 1, 0)
            holder.AutomaticSize = Enum.AutomaticSize.X
        end
        holder.Parent = row
        local holderLayout = Instance.new("UIListLayout")
        holderLayout.FillDirection = Enum.FillDirection.Horizontal
        holderLayout.Padding = UDim.new(0, 12)
        holderLayout.SortOrder = Enum.SortOrder.LayoutOrder
        holderLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        holderLayout.Parent = holder
        contentHost = holder
    end

    local box = Instance.new("TextBox")
    box.Name = "Value"
    box.BackgroundColor3 = colors.InputBG
    box.BorderSizePixel = 0
    box.Position = UDim2.fromOffset(0, (layout.RowH - layout.InputH) / 2)
    box.Size = UDim2.fromOffset(layout.SliderBoxW, layout.InputH)
    box.FontFace = Theme.GetFace()
    box.TextColor3 = colors.TextPrimary
    box.TextSize = 24
    box.TextXAlignment = Enum.TextXAlignment.Center
    box.ClearTextOnFocus = false
    box.ClipsDescendants = true
    if centerMode then
        box.LayoutOrder = 1
    end
    box.Parent = if centerMode then contentHost else row

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, layout.InputCorner)
    boxCorner.Parent = box

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    if centerMode then
        if centerAutoWidth then
            label.AutomaticSize = Enum.AutomaticSize.X
            label.Size = UDim2.new(0, 0, 1, 0)
        else
            label.AutomaticSize = Enum.AutomaticSize.None
            label.Size = UDim2.new(1, -(layout.SliderBoxW + 12), 1, 0)
        end
        label.LayoutOrder = 2
    else
        label.Position = UDim2.fromOffset(layout.SliderBoxW + 12, 0)
        label.Size = UDim2.new(labelScale, -(layout.SliderBoxW + 12 + labelInset), 1, 0)
    end
    label.FontFace = Theme.GetFace()
    label.Text = labelText
    label.TextColor3 = colors.TextPrimary
    label.TextSize = layout.LabelSize
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = if centerMode then contentHost else row
    if not centerMode then
        FitText.fit(label, {
            Base = layout.LabelSize,
            Min = layout.LabelMinSize,
        })
    end

    local function valueString(): string
        return string.format("%." .. precision .. "f", value)
    end

    local function applyValue(raw: number, fire: boolean)
        local v = math.clamp(raw, minV, maxV)
        if increment > 0 then
            local base = if minV > -math.huge then minV else 0
            local rel = math.floor((v - base) / increment + 0.5)
            v = math.clamp(base + rel * increment, minV, maxV)
        end
        value = v
        box.Text = valueString()
        if fire and typeof(pcApi) == "table" and typeof(pcApi.SetValue) == "function" then
            pcall(pcApi.SetValue, v)
        end
    end

    box.FocusLost:Connect(function()
        local num = tonumber(box.Text)
        if num == nil then
            box.Text = valueString()
            return
        end
        applyValue(num, true)
    end)

    if hasToggle then
        local pcSwitch = nil
        if typeof(config.Row) == "Instance" then
            pcSwitch = (config.Row :: Instance):FindFirstChild("Switch")
        end
        local toggleApi = nil
        local tapis = genv.GDH_ToggleRowApis
        if typeof(tapis) == "table" and typeof(pcSwitch) == "Instance" then
            toggleApi = tapis[pcSwitch :: Instance]
        end

        local cell = Instance.new("TextButton")
        cell.Name = "ToggleCell"
        cell.Text = ""
        cell.AutoButtonColor = false
        cell.BackgroundTransparency = 1
        cell.BorderSizePixel = 0
        cell.AnchorPoint = Vector2.new(0, 0.5)
        cell.Position = UDim2.new(layout.SliderToggleX, 0, 0.5, 0)
        cell.Size = UDim2.new(1 - layout.SliderToggleX, 0, 1, 0)
        cell.Parent = row

        local switchNode: GuiObject
        local applyState: (boolean) -> ()

        local assets = Theme.GetAssets()
        if assets.TogglerOn ~= nil and assets.TogglerOff ~= nil then
            local image = Instance.new("ImageButton")
            image.Name = "Switch"
            image.AutoButtonColor = false
            image.AnchorPoint = Vector2.new(0.5, 0.5)
            image.BackgroundTransparency = 1
            image.BorderSizePixel = 0
            image.Position = UDim2.fromOffset(layout.SwitchX + layout.SwitchW / 2, layout.RowH / 2)
            image.Size = UDim2.fromOffset(layout.SwitchW, layout.SwitchH)
            image.Parent = cell
            switchNode = image
            applyState = function(state: boolean)
                image.Image = if state then assets.TogglerOn :: string else assets.TogglerOff :: string
            end
        else
            local track = Instance.new("TextButton")
            track.Name = "Switch"
            track.Text = ""
            track.AutoButtonColor = false
            track.AnchorPoint = Vector2.new(0.5, 0.5)
            track.BackgroundColor3 = colors.SwitchTrackOff
            track.BorderSizePixel = 0
            track.Position = UDim2.fromOffset(layout.SwitchX + layout.SwitchW / 2, layout.RowH / 2)
            track.Size = UDim2.fromOffset(layout.SwitchW, layout.SwitchH)
            local trackCorner = Instance.new("UICorner")
            trackCorner.CornerRadius = UDim.new(1, 0)
            trackCorner.Parent = track
            local inset = 3
            local knob = Instance.new("Frame")
            knob.Name = "Knob"
            knob.BackgroundColor3 = colors.SwitchKnobOff
            knob.BorderSizePixel = 0
            knob.Position = UDim2.fromOffset(inset, inset)
            knob.Size = UDim2.fromOffset(layout.SwitchH - inset * 2, layout.SwitchH - inset * 2)
            local knobCorner = Instance.new("UICorner")
            knobCorner.CornerRadius = UDim.new(1, 0)
            knobCorner.Parent = knob
            knob.Parent = track
            track.Parent = cell
            switchNode = track
            applyState = function(state: boolean)
                local targetX = if state then layout.SwitchW - layout.SwitchH + inset else inset
                Animate.Tween(knob, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
                    BackgroundColor3 = if state then colors.SwitchTrackOn else colors.SwitchTrackOff,
                })
                Animate.Tween(knob, 0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out, {
                    Position = UDim2.fromOffset(targetX, inset),
                    BackgroundColor3 = if state then colors.SwitchKnobOn else colors.SwitchKnobOff,
                })
            end
        end

        local title = Instance.new("TextLabel")
        title.Name = "Title"
        title.BackgroundTransparency = 1
        title.BorderSizePixel = 0
        title.Position = UDim2.fromOffset(layout.LabelX, 0)
        title.Size = UDim2.new(1, -(layout.LabelX + 8), 1, 0)
        title.FontFace = Theme.GetFace()
        title.Text = toggleTitle
        title.TextColor3 = colors.TextPrimary
        title.TextSize = layout.LabelSize
        title.TextTruncate = Enum.TextTruncate.AtEnd
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = cell
        FitText.fit(title, {
            Base = layout.LabelSize,
            Min = layout.LabelMinSize,
        })

        local function stateGetter(): boolean
            if typeof(toggleApi) == "table" and typeof(toggleApi.GetState) == "function" then
                local ok, state = pcall(toggleApi.GetState)
                if ok and typeof(state) == "boolean" then
                    return state
                end
            end
            if typeof(pcSwitch) == "Instance" then
                return (pcSwitch :: Instance):GetAttribute("State") == true
            end
            return false
        end

        local feedback = Animate.HoldFeedback(switchNode, switchNode, {
            Grow = 1.18,
            GrowTime = 0.15,
            ReleaseTime = 0.6,
            ReleaseStyle = Enum.EasingStyle.Elastic,
        })

        local function flip()
            local nextState = not stateGetter()
            if typeof(toggleApi) == "table" and typeof(toggleApi.SetState) == "function" then
                pcall(toggleApi.SetState, nextState)
            elseif typeof(pcSwitch) == "Instance" then
                local switchRow = pcSwitch :: Instance
                switchRow:SetAttribute("State", nextState)
            end
            applyState(stateGetter())
        end

        local target = {
            Node = switchNode,
            Activate = flip,
            PressIn = feedback.Press,
            PressOut = feedback.Reverse,
            Release = feedback.Release,
        }
        PressFlow.Register(target)

        local pressStart: Vector3? = nil
        local pressTime = 0

        local function isOverSwitch(pos: Vector3): boolean
            local abs = switchNode.AbsolutePosition
            local size = switchNode.AbsoluteSize
            return pos.X >= abs.X and pos.X <= abs.X + size.X
                and pos.Y >= abs.Y and pos.Y <= abs.Y + size.Y
        end

        switchNode.InputBegan:Connect(function(input: InputObject)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch
            then
                return
            end
            pressStart = input.Position
            pressTime = os.clock()
            PressFlow.Begin(target, input)
        end)

        switchNode.InputEnded:Connect(function(input: InputObject)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch
            then
                return
            end
            local start = pressStart
            local elapsed = os.clock() - pressTime
            pressStart = nil
            if start == nil then
                return
            end
            if not isOverSwitch(input.Position) then
                return
            end
            if elapsed > 0.3 then
                return
            end
            local delta = Vector2.new(input.Position.X - start.X, input.Position.Y - start.Y)
            if delta.Magnitude > 20 then
                return
            end
            flip()
        end)

        applyState(stateGetter())
    end

    applyValue(value, false)

    return row
end

return SliderCell
