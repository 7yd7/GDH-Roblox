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
    local widgetsPrefix = "Widgets/"
    if string.sub(name, 1, #widgetsPrefix) == widgetsPrefix then
        return require(parent.Widgets[string.sub(name, #widgetsPrefix + 1)])
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
local InfoPopup = nil

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
    if not InfoPopup then
        InfoPopup = importMobileModule("Widgets/InfoPopup")
    end
end

local function rowApiOf(row: Instance): any?
    local apis = genv.GDH_ToggleRowApis
    if typeof(apis) ~= "table" then
        return nil
    end
    local api = apis[row]
    if api ~= nil then
        return api
    end
    local switch = row:FindFirstChild("Switch")
    if switch ~= nil then
        return apis[switch]
    end
    return nil
end

export type ToggleCellConfig = {
    Row: any?,
    Name: string?,
    Parent: Instance,
    Notify: ((string, number?) -> ())?,
    SliderSplit: string?,
    Settings: any?,
    Center: boolean?,
    Host: Instance?,
    Root: Instance?,
    FitScale: any?,
    Description: string?,
}

local function ToggleCell(config: ToggleCellConfig): any
    init()

    local layout = Theme.Layout
    local colors = Theme.Colors
    local sliderSplit = config.SliderSplit
    local settingsConfig = config.Settings
    local gearSize = 46
    local infoSize = 30

    local pcRow = config.Row
    local cheating = false
    if typeof(pcRow) == "Instance" then
        cheating = (pcRow :: Instance):GetAttribute("Cheating") == true
    end
    local cell = Instance.new("TextButton")
    cell.Name = "Cell"
    cell.Text = ""
    cell.AutoButtonColor = false
    cell.BackgroundTransparency = 1
    cell.BorderSizePixel = 0
    if sliderSplit == "left" then
        cell.Size = UDim2.new(layout.SliderToggleX, -50, 0, layout.RowH)
    elseif sliderSplit == "right" then
        cell.Size = UDim2.new(1 - layout.SliderToggleX, 0, 0, layout.RowH)
    else
        cell.Size = UDim2.fromOffset(layout.CellW, layout.RowH)
    end
    cell.Parent = config.Parent

    local centerMode = config.Center == true
    local contentHost: Instance = cell
    if centerMode then
        cell.Size = UDim2.new(1, 0, 0, layout.RowH)
        local holder = Instance.new("Frame")
        holder.Name = "Content"
        holder.BackgroundTransparency = 1
        holder.BorderSizePixel = 0
        holder.AnchorPoint = Vector2.new(0.5, 0.5)
        holder.Position = UDim2.fromScale(0.5, 0.5)
        holder.Size = UDim2.new(0, 0, 1, 0)
        holder.AutomaticSize = Enum.AutomaticSize.X
        holder.Parent = cell
        local holderLayout = Instance.new("UIListLayout")
        holderLayout.FillDirection = Enum.FillDirection.Horizontal
        holderLayout.Padding = UDim.new(0, 8)
        holderLayout.SortOrder = Enum.SortOrder.LayoutOrder
        holderLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        holderLayout.Parent = holder
        contentHost = holder
    end

    local stateGetter: () -> boolean = function()
        if typeof(pcRow) ~= "Instance" then
            return false
        end
        local api = rowApiOf(pcRow :: Instance)
        if typeof(api) == "table" and typeof(api.GetState) == "function" then
            local ok, state = pcall(api.GetState)
            if ok and typeof(state) == "boolean" then
                return state
            end
        end
        return (pcRow :: Instance):GetAttribute("State") == true
    end

    local assets = Theme.GetAssets()
    local switchNode: GuiObject
    local applyState: (boolean) -> ()

    if assets.TogglerOn ~= nil and assets.TogglerOff ~= nil then
        local image = Instance.new("ImageButton")
        image.Name = "Switch"
        image.AutoButtonColor = false
        image.AnchorPoint = Vector2.new(0.5, 0.5)
        image.BackgroundTransparency = 1
        image.BorderSizePixel = 0
        image.Position = UDim2.fromOffset(layout.SwitchX + layout.SwitchW / 2, layout.RowH / 2)
        image.Size = UDim2.fromOffset(layout.SwitchW, layout.SwitchH)
        image.LayoutOrder = 1
        image.Parent = contentHost
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
        track.LayoutOrder = 1
        track.Parent = contentHost
        switchNode = track
        applyState = function(state: boolean)
            local targetX = if state then layout.SwitchW - layout.SwitchH + inset else inset
            Animate.Tween(track, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
                BackgroundColor3 = if state then colors.SwitchTrackOn else colors.SwitchTrackOff,
            })
            Animate.Tween(knob, 0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out, {
                Position = UDim2.fromOffset(targetX, inset),
                BackgroundColor3 = if state then colors.SwitchKnobOn else colors.SwitchKnobOff,
            })
        end
    end

    applyState(stateGetter())

    local hasInfo = false
    local descText = ""
    if typeof(config.Description) == "string" and config.Description ~= "" then
        hasInfo = true
        descText = config.Description
    elseif typeof(pcRow) == "Instance" then
        local desc = (pcRow :: Instance):GetAttribute("Description")
        if typeof(desc) == "string" and desc ~= "" then
            hasInfo = true
            descText = desc
        else
            for _, child in (pcRow :: Instance):GetDescendants() do
                local d = child:GetAttribute("Description")
                if typeof(d) == "string" and d ~= "" then
                    hasInfo = true
                    descText = d
                    break
                end
            end
        end
    end

    local hasSettings = typeof(settingsConfig) == "table"

    local labelBox: Frame? = nil
    if not centerMode and (hasSettings or hasInfo) then
        local box = Instance.new("Frame")
        box.Name = "LabelBox"
        box.BackgroundTransparency = 1
        box.BorderSizePixel = 0
        box.ZIndex = 2
        box.Position = UDim2.fromOffset(layout.LabelX, 0)
        local iconMargin = 8
        local reserve = 0
        if hasSettings then
            reserve = reserve + gearSize
        end
        if hasInfo then
            reserve = reserve + infoSize
            if hasSettings then
                reserve = reserve + 7
            end
        end
        box.Size = UDim2.new(1, -(layout.LabelX + iconMargin + reserve), 1, 0)
        box.Parent = cell
        labelBox = box
    end

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    if centerMode then
        label.AutomaticSize = Enum.AutomaticSize.X
        label.Size = UDim2.new(0, 0, 1, 0)
        label.LayoutOrder = 2
        label.Parent = contentHost
    elseif labelBox ~= nil then
        label.Size = UDim2.new(1, 0, 1, 0)
        label.Parent = labelBox
    else
        label.Position = UDim2.fromOffset(layout.LabelX, 0)
        label.Size = UDim2.new(1, -(layout.LabelX + layout.LabelInset), 1, 0)
        label.Parent = cell
    end
    label.FontFace = Theme.GetFace()
    label.Text = tostring(config.Name or "")
    label.TextColor3 = if cheating then colors.TextDanger else colors.TextPrimary
    label.TextSize = layout.LabelSize
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.TextXAlignment = Enum.TextXAlignment.Left
    if not centerMode then
        FitText.fit(label, {
            Base = layout.LabelSize,
            Min = layout.LabelMinSize,
        })
    end

    local feedback = Animate.HoldFeedback(switchNode, switchNode, {
        Grow = 1.18,
        GrowTime = 0.15,
        ReleaseTime = 0.6,
        ReleaseStyle = Enum.EasingStyle.Elastic,
    })

    local cleanupConnections: { RBXScriptConnection } = {}

    local function toggle()
        if typeof(pcRow) ~= "Instance" then
            return
        end
        local row = pcRow :: Instance
        local api = rowApiOf(row)
        if typeof(api) == "table" and typeof(api.SetState) == "function" then
            local ok = pcall(function()
                api.SetState(not stateGetter())
            end)
            if ok then
                return
            end
        end
        row:SetAttribute("State", not stateGetter())
    end

    local target = {
        Node = switchNode,
        Activate = toggle,
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
        toggle()
    end)

    if typeof(pcRow) == "Instance" then
        local row = pcRow :: Instance

        local attrConn = row:GetAttributeChangedSignal("State"):Connect(function()
            applyState(stateGetter())
        end)
        table.insert(cleanupConnections, attrConn)
    end

    local function currentFitScale(): number
        local value = config.FitScale
        local scale = 1
        if typeof(value) == "Instance" and (value :: Instance):IsA("UIScale") then
            scale = (value :: UIScale).Scale
        elseif typeof(value) == "number" then
            scale = value :: number
        end
        if scale <= 0 then
            return 1
        end
        return scale
    end

    local gearNode: ImageButton? = nil
    local infoNode: ImageButton? = nil

    if hasSettings then
        local settingsTable = settingsConfig :: any
        local gearImage = Instance.new("ImageButton")
        gearImage.Name = "Settings"
        gearImage.AutoButtonColor = false
        gearImage.BackgroundTransparency = 1
        gearImage.BorderSizePixel = 0
        gearImage.AnchorPoint = Vector2.new(0, 0.5)
        gearImage.Size = UDim2.fromOffset(gearSize, gearSize)
        local gearAsset = tostring(settingsTable.Image or "")
        if gearAsset ~= "" then
            gearImage.Image = gearAsset
            gearImage.ScaleType = Enum.ScaleType.Fit
        end
        if labelBox ~= nil then
            local infoExtra = 0
            if hasInfo then
                infoExtra = infoSize + 7
            end
            gearImage.Visible = false
            gearImage.Position = UDim2.new(1, -(gearSize + infoExtra), 0.5, 0)
            gearImage.Parent = labelBox
        else
            gearImage.Position = UDim2.new(1, 7, 0.5, 0)
            gearImage.Parent = label
        end
        gearNode = gearImage

        local gearFeedback = Animate.HoldFeedback(gearImage, gearImage, {
            Grow = 1.18,
            GrowTime = 0.15,
            ReleaseTime = 0.6,
            ReleaseStyle = Enum.EasingStyle.Elastic,
        })

        local function gearActivate()
            local activate = settingsTable.Activate
            if typeof(activate) == "function" then
                pcall(activate :: any)
            end
        end

        local gearTarget = {
            Node = gearImage,
            Activate = gearActivate,
            PressIn = gearFeedback.Press,
            PressOut = gearFeedback.Reverse,
            Release = gearFeedback.Release,
        }
        PressFlow.Register(gearTarget)

        gearImage.InputBegan:Connect(function(input: InputObject)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                PressFlow.Begin(gearTarget, input)
            end
        end)

        gearImage.Activated:Connect(function()
            gearActivate()
        end)
    end

    if hasInfo then
        local infoImage = Instance.new("ImageButton")
        infoImage.Name = "Info"
        infoImage.AutoButtonColor = false
        infoImage.BackgroundTransparency = 1
        infoImage.BorderSizePixel = 0
        infoImage.AnchorPoint = Vector2.new(0, 0.5)
        infoImage.Size = UDim2.fromOffset(infoSize, infoSize)

        local infoAsset = ""
        local mobileAssets = Theme.GetAssets and Theme.GetAssets()
        if mobileAssets and typeof(mobileAssets.Info) == "string" and mobileAssets.Info ~= "" then
            infoAsset = mobileAssets.Info
        else
            local modGenv = (typeof(getgenv) == "function" and getgenv()) or (typeof(_G) == "table" and _G) or {}
            local Import = modGenv.Import
            if typeof(Import) == "table" and typeof(Import.Asset) == "function" then
                local ok, asset = pcall(Import.Asset, "Assets/GDH/GDH_infoIcon.png")
                if ok and typeof(asset) == "string" and asset ~= "" then
                    infoAsset = asset
                end
            end
        end
        if infoAsset == "" then
            infoAsset = "rbxassetid://116359281861345"
        end
        infoImage.Image = infoAsset
        infoImage.ScaleType = Enum.ScaleType.Fit
        if labelBox ~= nil then
            infoImage.Visible = false
            infoImage.Position = UDim2.new(1, -infoSize, 0.5, 0)
            infoImage.Parent = labelBox
        else
            local infoOffset = 7
            if hasSettings then
                infoOffset = 7 + gearSize + 7
            end
            infoImage.Position = UDim2.new(1, infoOffset, 0.5, 0)
            infoImage.Parent = label
        end
        infoNode = infoImage

        local infoFeedback = Animate.HoldFeedback(infoImage, infoImage, {
            Grow = 1.18,
            GrowTime = 0.15,
            ReleaseTime = 0.6,
            ReleaseStyle = Enum.EasingStyle.Elastic,
        })

        local function infoActivate()
            local host = config.Host
                or config.Root
                or cell:FindFirstAncestor("Menu")
                or cell:FindFirstAncestor("GDH Mobile")
                or cell:FindFirstAncestorWhichIsA("ScreenGui")
                or cell.Parent
            local titleText = tostring(config.Name or (pcRow and pcRow.Name) or "Info")
            local scale = currentFitScale()
            if InfoPopup and typeof(InfoPopup.Show) == "function" and host then
                InfoPopup.Show(host, titleText, descText, scale)
            end
        end

        local infoTarget = {
            Node = infoImage,
            Activate = infoActivate,
            PressIn = infoFeedback.Press,
            PressOut = infoFeedback.Reverse,
            Release = infoFeedback.Release,
        }
        PressFlow.Register(infoTarget)

        infoImage.InputBegan:Connect(function(input: InputObject)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                PressFlow.Begin(infoTarget, input)
            end
        end)

        infoImage.Activated:Connect(function()
            infoActivate()
        end)
    end

    local function syncTrailingIcons(): ()
        if labelBox == nil then
            return
        end
        local boxW = labelBox.AbsoluteSize.X
        local textW = label.TextBounds.X
        if boxW <= 0 or textW <= 0 then
            return
        end
        local scale = currentFitScale()
        local textEnd = math.min(textW, boxW) / scale + 8
        if gearNode ~= nil then
            local gearIcon = gearNode :: ImageButton
            gearIcon.Position = UDim2.new(0, textEnd, 0.5, 0)
            gearIcon.Visible = true
        end
        if infoNode ~= nil then
            local infoIcon = infoNode :: ImageButton
            local infoX = textEnd
            if hasSettings then
                infoX = infoX + gearSize + 7
            end
            infoIcon.Position = UDim2.new(0, infoX, 0.5, 0)
            infoIcon.Visible = true
        end
    end

    syncTrailingIcons()
    if labelBox ~= nil then
        local boundsConn = label:GetPropertyChangedSignal("TextBounds"):Connect(syncTrailingIcons)
        table.insert(cleanupConnections, boundsConn)
        task.defer(syncTrailingIcons)
        task.delay(0.3, syncTrailingIcons)
        task.delay(1, syncTrailingIcons)
    end

    local function Destroy()
        feedback.Destroy()
        for _, conn in cleanupConnections do
            pcall(function()
                conn:Disconnect()
            end)
        end
        table.clear(cleanupConnections)
        pcall(function()
            cell:Destroy()
        end)
    end

    cell.Destroying:Connect(Destroy)

    return {
        Cell = cell,
        Label = label,
        Apply = applyState,
        Destroy = Destroy,
    }
end

return ToggleCell
