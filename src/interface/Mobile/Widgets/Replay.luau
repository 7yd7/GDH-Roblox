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

local activeClose: any? = nil

export type ReplayConfig = {
    List: Instance,
    Overlay: any?,
    Root: Instance?,
    Fit: any?,
    Notify: any?,
}

local function ReplayTab(config: ReplayConfig)
    init()

    local layout = Theme.Layout
    local colors = Theme.Colors
    local notifyFn = if typeof(config.Notify) == "function" then config.Notify :: any else nil

    local function notify(text: string)
        if typeof(notifyFn) == "function" then
            pcall(notifyFn :: any, text)
        end
    end

    local state = genv.GDH_MOBILE_REPLAY
    if typeof(state) ~= "table" then
        state = {
            Record = false,
            Play = false,
            Continue = false,
            Name = "",
            AccuracyFix = false,
            YVelocityFix = false,
            IgnoreInput = false,
            Saved = {},
        }
        genv.GDH_MOBILE_REPLAY = state
    end
    if typeof(state.Saved) ~= "table" then
        state.Saved = {}
    end

    local list = config.List
    if typeof(list) ~= "Instance" then
        return
    end

    local Storage = nil
    do
        local Import = genv.Import
        if typeof(Import) == "table" then
            local ok, moduleValue = pcall(function()
                return Import("Function/Storage")
            end)
            if ok and typeof(moduleValue) == "table" then
                Storage = moduleValue
            end
        end
    end

    local function listMacros(): { string }
        local items: { string } = {}
        if Storage ~= nil then
            pcall(function()
                items = (Storage :: any):ListMacros()
            end)
        end
        return items
    end

    local UI = genv.GDH_UI
    local pcRows: any = {
        Modes = {},
        NameApi = nil,
        NameField = nil,
        SaveFire = nil,
        LoadFire = nil,
        ClearFire = nil,
        Labels = {},
        ProToggles = {},
    }

    do
        if typeof(UI) == "table" then
            local hacks = UI._keybindHacks
            if typeof(hacks) == "table" then
                for _, entry in hacks :: { any } do
                    if typeof(entry) == "table" then
                        local win = entry.Window
                        if typeof(win) == "table" and win._title == "Replay Engine" then
                            local kind = tostring(entry.Kind or "")
                            if kind == "Radio" then
                                local row = entry.Row
                                if typeof(row) == "Instance" then
                                    local rowFrame = row :: Instance
                                    local api = nil
                                    local apis = genv.GDH_RadioButtonApis
                                    if typeof(apis) == "table" then
                                        api = apis[rowFrame]
                                    end
                                    pcRows.Modes[tostring(entry.Name or "")] = {
                                        Row = rowFrame,
                                        Api = api,
                                    }
                                end
                            elseif kind == "TextInput" then
                                local pill = entry.Pill
                                if typeof(pill) == "Instance" then
                                    local apis = genv.GDH_TextRowApis
                                    if typeof(apis) == "table" then
                                        pcRows.NameApi = apis[pill :: Instance]
                                    end
                                    pcRows.NameField = (pill :: Instance):FindFirstChild("Field")
                                end
                            elseif kind == "ButtonRow" then
                                local buttons = entry.Buttons
                                if typeof(buttons) == "table" then
                                    for _, button in buttons :: { any } do
                                        if typeof(button) == "table" then
                                            local text = tostring(button.Text or "")
                                            if text == "Save" then
                                                pcRows.SaveFire = button.Fire
                                            elseif text == "Load" then
                                                pcRows.LoadFire = button.Fire
                                            elseif text == "Clear" then
                                                pcRows.ClearFire = button.Fire
                                            end
                                        end
                                    end
                                end
                            elseif kind == "Label" then
                                local row = entry.Row
                                if typeof(row) == "Instance" and (row :: Instance):IsA("TextLabel") then
                                    local label = row :: TextLabel
                                    local text = label.Text
                                    if string.sub(text, 1, 6) == "Frame:" then
                                        pcRows.Labels.Frame = label
                                    elseif string.sub(text, 1, 11) == "Replay Size" then
                                        pcRows.Labels.Size = label
                                    end
                                end
                            end
                        end
                    end
                end
            end
            local windows = UI._windows
            if typeof(windows) == "table" then
                for _, win in windows :: { any } do
                    if typeof(win) == "table" and win._title == "Pro Settings" then
                        local getContent = win.GetContentFrame
                        if typeof(getContent) == "function" then
                            local okContent, content = pcall(function()
                                return win:GetContentFrame()
                            end)
                            if okContent and typeof(content) == "Instance" then
                                for _, node in (content :: Instance):GetDescendants() do
                                    if typeof(node) == "Instance"
                                        and (node :: Instance):GetAttribute("WidgetType") == "Toggle"
                                    then
                                        local rowFrame = node :: Instance
                                        local title = rowFrame:FindFirstChild("Title")
                                        local titleText = ""
                                        if typeof(title) == "Instance" then
                                            local titleNode = title :: Instance
                                            if titleNode:IsA("TextLabel") or titleNode:IsA("TextButton") then
                                                titleText = (titleNode :: TextLabel).Text
                                            end
                                        end
                                        if titleText ~= "" then
                                            local api = nil
                                            local apis = genv.GDH_ToggleRowApis
                                            if typeof(apis) == "table" then
                                                api = apis[rowFrame]
                                            end
                                            pcRows.ProToggles[titleText] = {
                                                Row = rowFrame,
                                                Api = api,
                                            }
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local modeNames = { "Record", "Play", "Continue" }

    local proFallbackKeys = {
        ["Accuracy Fix"] = "AccuracyFix",
        ["Y Velocity Fix"] = "YVelocityFix",
        ["Ignore Inputs on Playback"] = "IgnoreInput",
    }

    local cleanupConns: { RBXScriptConnection } = {}
    local function disconnectAll()
        for _, conn in cleanupConns do
            pcall(function()
                conn:Disconnect()
            end)
        end
        table.clear(cleanupConns)
    end

    local nameBox: TextBox? = nil
    local syncingName = false

    local function trim(text: string): string
        return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
    end

    local function currentName(): string
        local box = nameBox
        if box ~= nil then
            return trim(box.Text)
        end
        return trim(tostring(state.Name or ""))
    end

    local function applyName(text: string)
        state.Name = text
        local api = pcRows.NameApi
        if typeof(api) == "table" and typeof(api.SetText) == "function" then
            pcall(api.SetText, text)
        end
        local field = pcRows.NameField
        if typeof(field) == "Instance" and (field :: Instance):IsA("TextBox") then
            local fieldBox = field :: TextBox
            syncingName = true
            fieldBox.Text = text
            syncingName = false
        end
        local box = nameBox
        if box ~= nil and box.Text ~= text then
            box.Text = text
        end
    end

    local function modeActive(modeName: string): boolean
        local entry = pcRows.Modes[modeName]
        if entry ~= nil and typeof(entry.Row) == "Instance" then
            return (entry.Row :: Instance):GetAttribute("Active") == true
        end
        return state[modeName] == true
    end

    local function setMode(modeName: string, on: boolean)
        local entry = pcRows.Modes[modeName]
        if entry ~= nil and typeof(entry.Api) == "table" and typeof(entry.Api.SetActive) == "function" then
            if on then
                pcall(entry.Api.SetActive, true)
            else
                local disableEntry = pcRows.Modes["Disable"]
                if disableEntry ~= nil and typeof(disableEntry.Api) == "table"
                    and typeof(disableEntry.Api.SetActive) == "function"
                then
                    pcall(disableEntry.Api.SetActive, true)
                end
            end
            return
        end
        for _, name in modeNames do
            state[name] = (name == modeName) and on or false
        end
        for _, name in modeNames do
            local apply = modeApply[name]
            if typeof(apply) == "function" then
                pcall(apply :: any, state[name] == true)
            end
        end
    end

    local function proGet(pcTitle: string): boolean
        local entry = pcRows.ProToggles[pcTitle]
        if entry ~= nil then
            if typeof(entry.Api) == "table" and typeof(entry.Api.GetState) == "function" then
                local ok, result = pcall(entry.Api.GetState)
                if ok and typeof(result) == "boolean" then
                    return result
                end
            end
            if typeof(entry.Row) == "Instance" then
                return (entry.Row :: Instance):GetAttribute("State") == true
            end
        end
        return state[proFallbackKeys[pcTitle] or ""] == true
    end

    local function proSet(pcTitle: string, on: boolean)
        local entry = pcRows.ProToggles[pcTitle]
        if entry ~= nil and typeof(entry.Api) == "table" and typeof(entry.Api.SetState) == "function" then
            pcall(entry.Api.SetState, on)
            return
        end
        state[proFallbackKeys[pcTitle] or ""] = on
        local apply = proApply[pcTitle]
        if typeof(apply) == "function" then
            pcall(apply :: any, on)
        end
    end

    local function fireSave()
        if typeof(pcRows.SaveFire) == "function" then
            applyName(currentName())
            pcall(pcRows.SaveFire :: any)
            return
        end
        local name = currentName()
        if name == "" then
            notify("Enter a replay name first")
            return
        end
        local saved = state.Saved :: { any }
        for i = #saved, 1, -1 do
            if saved[i] == name then
                table.remove(saved, i)
            end
        end
        table.insert(saved, 1, name)
        notify("Replay saved")
    end

    local function fireLoad()
        if typeof(pcRows.LoadFire) == "function" then
            applyName(currentName())
            pcall(pcRows.LoadFire :: any)
            return
        end
        local name = currentName()
        if name == "" then
            notify("Enter a replay name first")
            return
        end
        local found = false
        for _, saved in state.Saved :: { any } do
            if saved == name then
                found = true
                break
            end
        end
        if found then
            notify("Replay loaded")
        else
            notify("Replay not found")
        end
    end

    local function fireClear()
        if typeof(pcRows.ClearFire) == "function" then
            pcall(pcRows.ClearFire :: any)
            return
        end
        notify("Replay cleared")
    end

    local function deleteReplay()
        local name = currentName()
        if name == "" then
            notify("Enter a replay name first")
            return
        end
        if Storage ~= nil then
            local removed = false
            pcall(function()
                removed = (Storage :: any):DeleteMacro(name)
            end)
            if removed then
                notify("Replay deleted")
            else
                notify("Replay not found")
            end
            return
        end
        local saved = state.Saved :: { any }
        local removed = false
        for i = #saved, 1, -1 do
            if saved[i] == name then
                table.remove(saved, i)
                removed = true
            end
        end
        if removed then
            notify("Replay deleted")
        else
            notify("Replay not found")
        end
    end

    local function importReplay()
        if Storage ~= nil then
            notify("Macros folder: Workspace/GDH/Macros")
            return
        end
        notify("Storage unavailable")
    end

    local rowOrder = 0

    local function buildRow(height: number): Frame
        rowOrder += 1
        local frame = Instance.new("Frame")
        frame.Name = "ReplayRow" .. rowOrder
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.Size = UDim2.new(1, 0, 0, height)
        frame.LayoutOrder = rowOrder
        frame.Parent = list
        return frame
    end

    local function buildSpacer(height: number)
        buildRow(height)
    end

    local function buildSlots(count: number, slotW: number, pad: number?): { Frame }
        local frame = buildRow(layout.RowH)
        local rowList = Instance.new("UIListLayout")
        rowList.FillDirection = Enum.FillDirection.Horizontal
        rowList.Padding = UDim.new(0, if pad ~= nil then pad else layout.CellGap)
        rowList.SortOrder = Enum.SortOrder.LayoutOrder
        rowList.Parent = frame
        local slots: { Frame } = {}
        for i = 1, count do
            local slot = Instance.new("Frame")
            slot.Name = "Slot" .. i
            slot.BackgroundTransparency = 1
            slot.BorderSizePixel = 0
            slot.Size = UDim2.fromOffset(slotW, layout.RowH)
            slot.LayoutOrder = i
            slot.Parent = frame
            table.insert(slots, slot)
        end
        return slots
    end

    local frameLabel: TextLabel? = nil
    local sizeLabel: TextLabel? = nil

    local function updateStatus()
        local frameText = frameLabel
        local sizeText = sizeLabel
        if frameText ~= nil then
            frameText.Text = "Frame: 0"
        end
        if sizeText ~= nil then
            sizeText.Text = "Replay Size: 0/0"
        end
    end

    local function makeToggleCell(parent: Frame, text: string, switchX: number, labelX: number, controller: any, order: number?)
        local cell = Instance.new("Frame")
        cell.Name = "ToggleCell"
        cell.BackgroundTransparency = 1
        cell.BorderSizePixel = 0
        cell.Size = UDim2.new(0, 0, 0, layout.RowH)
        cell.AutomaticSize = Enum.AutomaticSize.X
        if order ~= nil then
            cell.LayoutOrder = order
        end
        cell.Parent = parent

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
            image.Position = UDim2.fromOffset(switchX + layout.SwitchW / 2, layout.RowH / 2)
            image.Size = UDim2.fromOffset(layout.SwitchW, layout.SwitchH)
            image.Parent = cell
            switchNode = image
            applyState = function(isOn: boolean)
                image.Image = if isOn then assets.TogglerOn :: string else assets.TogglerOff :: string
            end
        else
            local track = Instance.new("TextButton")
            track.Name = "Switch"
            track.Text = ""
            track.AutoButtonColor = false
            track.AnchorPoint = Vector2.new(0.5, 0.5)
            track.BackgroundColor3 = colors.SwitchTrackOff
            track.BorderSizePixel = 0
            track.Position = UDim2.fromOffset(switchX + layout.SwitchW / 2, layout.RowH / 2)
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
            applyState = function(isOn: boolean)
                local targetX = if isOn then layout.SwitchW - layout.SwitchH + inset else inset
                Animate.Tween(track, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
                    BackgroundColor3 = if isOn then colors.SwitchTrackOn else colors.SwitchTrackOff,
                })
                Animate.Tween(knob, 0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out, {
                    Position = UDim2.fromOffset(targetX, inset),
                    BackgroundColor3 = if isOn then colors.SwitchKnobOn else colors.SwitchKnobOff,
                })
            end
        end

        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.BackgroundTransparency = 1
        label.BorderSizePixel = 0
        label.Position = UDim2.fromOffset(labelX, 0)
        label.Size = UDim2.new(0, 0, 1, 0)
        label.AutomaticSize = Enum.AutomaticSize.X
        label.FontFace = Theme.GetFace()
        label.Text = text
        label.TextColor3 = colors.TextPrimary
        label.TextSize = layout.LabelSize
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = cell

        local feedback = Animate.HoldFeedback(switchNode, switchNode, {
            Grow = 1.18,
            GrowTime = 0.15,
            ReleaseTime = 0.6,
            ReleaseStyle = Enum.EasingStyle.Elastic,
        })

        local function toggle()
            controller.Set(not controller.Get())
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

        if typeof(controller.Sync) == "function" then
            controller.Sync(applyState)
        else
            applyState(controller.Get())
        end
    end

    local modeApply: { [string]: (boolean) -> () } = {}
    local proApply: { [string]: (boolean) -> () } = {}

    local function modeController(modeName: string): any
        return {
            Get = function(): boolean
                return modeActive(modeName)
            end,
            Set = function(on: boolean)
                setMode(modeName, on)
            end,
            Sync = function(apply: (boolean) -> ())
                modeApply[modeName] = apply
                local entry = pcRows.Modes[modeName]
                if entry ~= nil and typeof(entry.Row) == "Instance" then
                    local row = entry.Row :: Instance
                    table.insert(cleanupConns, row:GetAttributeChangedSignal("Active"):Connect(function()
                        apply(row:GetAttribute("Active") == true)
                    end))
                    apply(row:GetAttribute("Active") == true)
                else
                    apply(state[modeName] == true)
                end
            end,
        }
    end

    local function proController(pcTitle: string): any
        return {
            Get = function(): boolean
                return proGet(pcTitle)
            end,
            Set = function(on: boolean)
                proSet(pcTitle, on)
            end,
            Sync = function(apply: (boolean) -> ())
                proApply[pcTitle] = apply
                local entry = pcRows.ProToggles[pcTitle]
                if entry ~= nil and typeof(entry.Row) == "Instance" then
                    local row = entry.Row :: Instance
                    table.insert(cleanupConns, row:GetAttributeChangedSignal("State"):Connect(function()
                        apply(row:GetAttribute("State") == true)
                    end))
                    apply(row:GetAttribute("State") == true)
                else
                    apply(state[proFallbackKeys[pcTitle] or ""] == true)
                end
            end,
        }
    end

    local function makeActionButton(parent: Frame, slotW: number, text: string, fire: () -> ())
        local btn = Instance.new("TextButton")
        btn.Name = "Button"
        btn.AutoButtonColor = false
        btn.BackgroundColor3 = colors.TabInactive
        btn.BorderSizePixel = 0
        btn.AnchorPoint = Vector2.new(0.5, 0.5)
        btn.Position = UDim2.fromScale(0.5, 0.5)
        btn.Size = UDim2.fromOffset(slotW, layout.RowH)
        btn.FontFace = Theme.GetFace()
        btn.Text = text
        btn.TextColor3 = colors.TabInactiveText
        btn.TextSize = layout.LabelSize
        btn.TextTruncate = Enum.TextTruncate.AtEnd
        btn.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 14)
        corner.Parent = btn

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 2
        stroke.Color = colors.MenuStroke
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = btn
        pcall(function()
            stroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
        end)

        local feedback = Animate.HoldFeedback(btn, btn, {
            Grow = 1.15,
            GrowTime = 0.15,
            ReleaseTime = 0.6,
            ReleaseStyle = Enum.EasingStyle.Elastic,
        })

        local target = {
            Node = btn,
            Activate = fire,
            PressIn = feedback.Press,
            PressOut = feedback.Reverse,
            Release = feedback.Release,
        }
        PressFlow.Register(target)

        btn.InputBegan:Connect(function(input: InputObject)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                PressFlow.Begin(target, input)
            end
        end)

        btn.Activated:Connect(function()
            pcall(fire)
        end)
    end

    local function makeIcon(parent: Frame, rightX: number, size: number, image: any, glyph: string, activate: () -> ()): GuiObject
        local btn: GuiObject
        if typeof(image) == "string" and image ~= "" then
            local imageBtn = Instance.new("ImageButton")
            imageBtn.Name = "Icon"
            imageBtn.AutoButtonColor = false
            imageBtn.BackgroundTransparency = 1
            imageBtn.BorderSizePixel = 0
            imageBtn.AnchorPoint = Vector2.new(1, 0.5)
            imageBtn.Position = UDim2.fromOffset(rightX, layout.RowH / 2)
            imageBtn.Size = UDim2.fromOffset(size, size)
            imageBtn.Image = image
            imageBtn.ScaleType = Enum.ScaleType.Fit
            imageBtn.Parent = parent
            btn = imageBtn
        else
            local textBtn = Instance.new("TextButton")
            textBtn.Name = "Icon"
            textBtn.AutoButtonColor = false
            textBtn.BackgroundTransparency = 1
            textBtn.BorderSizePixel = 0
            textBtn.AnchorPoint = Vector2.new(1, 0.5)
            textBtn.Position = UDim2.fromOffset(rightX, layout.RowH / 2)
            textBtn.Size = UDim2.fromOffset(size, size)
            textBtn.FontFace = Theme.GetFace()
            textBtn.Text = glyph
            textBtn.TextColor3 = colors.TextPrimary
            textBtn.TextSize = 24
            textBtn.Parent = parent
            btn = textBtn
        end

        local feedback = Animate.HoldFeedback(btn, btn, {
            Grow = 1.18,
            GrowTime = 0.15,
            ReleaseTime = 0.6,
            ReleaseStyle = Enum.EasingStyle.Elastic,
        })

        local target = {
            Node = btn,
            Activate = activate,
            PressIn = feedback.Press,
            PressOut = feedback.Reverse,
            Release = feedback.Release,
        }
        PressFlow.Register(target)

        btn.InputBegan:Connect(function(input: InputObject)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                PressFlow.Begin(target, input)
            end
        end)

        btn.Activated:Connect(function()
            pcall(activate)
        end)

        return btn
    end

    local pill: Frame? = nil
    local arrowBtn: GuiObject? = nil
    local popup: Frame? = nil
    local menuConn: RBXScriptConnection? = nil

    local function closePopup()
        local current = popup
        popup = nil
        if activeClose == closePopup then
            activeClose = nil
        end
        if current ~= nil then
            pcall(function()
                current:Destroy()
            end)
        end
    end

    local function popupItems(): { string }
        local items: { string } = {}
        local macros = listMacros()
        if #macros > 0 then
            for _, macroId in macros do
                table.insert(items, tostring(macroId))
            end
            return items
        end
        for _, name in state.Saved :: { any } do
            table.insert(items, tostring(name))
        end
        return items
    end

    local function openPopup()
        if popup ~= nil then
            return
        end
        if typeof(activeClose) == "function" then
            pcall(activeClose :: any)
        end
        local menu = config.Overlay
        if typeof(menu) ~= "Instance" then
            return
        end
        local popHost: Instance = if typeof(config.Root) == "Instance" then config.Root :: Instance else menu :: Instance

        local items = popupItems()
        local count = #items
        local popW = math.floor(layout.BgW * 0.65 + 0.5)
        local popH = math.floor(layout.BgH * 0.65 + 0.5)
        local closeW = math.floor(119 * (popW / 1010) + 0.5)
        local closeH = math.floor(closeW / 0.96748 + 0.5)
        local closeX = -math.floor(popW * 0.05158 + 0.5)
        local closeY = -math.floor(popH * 0.07281 + 0.5)

        local container = Instance.new("Frame")
        container.Name = "ReplayPopup"
        container.Active = true
        container.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        container.BackgroundTransparency = 0.45
        container.BorderSizePixel = 0
        container.Position = UDim2.fromScale(0, 0)
        container.Size = UDim2.fromScale(1, 1)
        container.ZIndex = 60
        container.Parent = popHost

        PressFlow.Register({
            Node = container,
        })

        local panel = Instance.new("Frame")
        panel.Name = "Panel"
        panel.Active = true
        panel.BackgroundColor3 = colors.MenuBG
        panel.BorderSizePixel = 0
        panel.AnchorPoint = Vector2.new(0.5, 0.5)
        panel.Position = UDim2.new(0.5, 0, 0.5, 0)
        panel.Size = UDim2.fromOffset(popW, popH)
        panel.ZIndex = 61
        panel.Parent = container

        local panelCorner = Instance.new("UICorner")
        panelCorner.CornerRadius = UDim.new(0, math.floor(layout.BgCorner * (popW / layout.BgW) + 0.5))
        panelCorner.Parent = panel

        local panelStroke = Instance.new("UIStroke")
        panelStroke.Color = colors.MenuStroke
        panelStroke.Thickness = layout.BgStroke
        panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        panelStroke.Parent = panel

        local fitNode = config.Fit
        local fitValue = 1
        if typeof(fitNode) == "Instance" and (fitNode :: Instance):IsA("UIScale") then
            fitValue = (fitNode :: UIScale).Scale
        end

        local popScale = Instance.new("UIScale")
        popScale.Scale = fitValue * 0.55
        popScale.Parent = panel
        Animate.Tween(popScale, 0.8, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, {
            Scale = fitValue,
        })

        local assets = Theme.GetAssets()

        local closeBtn: GuiObject
        if typeof(assets.Close) == "string" and (assets.Close :: string) ~= "" then
            local closeImage = Instance.new("ImageButton")
            closeImage.Name = "Close"
            closeImage.AutoButtonColor = false
            closeImage.BackgroundTransparency = 1
            closeImage.BorderSizePixel = 0
            closeImage.Position = UDim2.fromOffset(closeX, closeY)
            closeImage.Size = UDim2.fromOffset(closeW, closeH)
            closeImage.Image = assets.Close :: string
            closeImage.ScaleType = Enum.ScaleType.Fit
            closeImage.ZIndex = 64
            closeImage.Parent = panel
            closeBtn = closeImage
        else
            local closeText = Instance.new("TextButton")
            closeText.Name = "Close"
            closeText.AutoButtonColor = false
            closeText.BackgroundColor3 = colors.SwitchTrackOff
            closeText.BorderSizePixel = 0
            closeText.Position = UDim2.fromOffset(closeX, closeY)
            closeText.Size = UDim2.fromOffset(closeW, closeH)
            closeText.FontFace = Theme.GetFace()
            closeText.Text = "✕"
            closeText.TextColor3 = colors.TextPrimary
            closeText.TextSize = layout.LabelSize
            closeText.ZIndex = 64
            closeText.Parent = panel
            local closeCorner = Instance.new("UICorner")
            closeCorner.CornerRadius = UDim.new(1, 0)
            closeCorner.Parent = closeText
            closeBtn = closeText
        end

        local closeFeedback = Animate.HoldFeedback(closeBtn, closeBtn, {
            Grow = 1.18,
            GrowTime = 0.15,
            ReleaseTime = 0.6,
            ReleaseStyle = Enum.EasingStyle.Elastic,
        })
        local closeTarget = {
            Node = closeBtn,
            PressIn = closeFeedback.Press,
            PressOut = closeFeedback.Reverse,
            Release = closeFeedback.Release,
        }
        PressFlow.Register(closeTarget)

        closeBtn.InputBegan:Connect(function(input: InputObject)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                PressFlow.Begin(closeTarget, input)
            end
        end)

        closeBtn.Activated:Connect(function()
            closePopup()
        end)

        local titleSize = math.floor(popH * 0.15 + 0.5)
        local titleCenter = math.floor(popH * 0.18 + 0.5)
        local titleH = math.floor(titleSize * 1.15 + 0.5)
        local contentTop = titleCenter + math.floor(titleH / 2) + 12
        local itemTextSize = math.floor(popH * 0.103 + 0.5)

        local title = Instance.new("TextLabel")
        title.Name = "Title"
        title.BackgroundTransparency = 1
        title.BorderSizePixel = 0
        title.Position = UDim2.fromOffset(0, titleCenter - math.floor(titleH / 2))
        title.Size = UDim2.new(1, 0, 0, titleH)
        title.FontFace = Theme.GetFace()
        title.Text = "Select Replay"
        title.TextColor3 = colors.TextPrimary
        title.TextSize = titleSize
        title.TextXAlignment = Enum.TextXAlignment.Center
        title.ZIndex = 62
        title.Parent = panel

        if count == 0 then
            local empty = Instance.new("TextLabel")
            empty.Name = "Empty"
            empty.BackgroundTransparency = 1
            empty.BorderSizePixel = 0
            empty.Position = UDim2.fromOffset(30, contentTop)
            empty.Size = UDim2.new(1, -60, 1, -(contentTop + 24))
            empty.FontFace = Theme.GetFace()
            empty.Text = "No saved replays"
            empty.TextColor3 = colors.RadioRingOff
            empty.TextSize = itemTextSize
            empty.TextXAlignment = Enum.TextXAlignment.Center
            empty.TextYAlignment = Enum.TextYAlignment.Center
            empty.ZIndex = 62
            empty.Parent = panel
        else
            local scroll = Instance.new("ScrollingFrame")
            scroll.Name = "Items"
            scroll.BackgroundTransparency = 1
            scroll.BorderSizePixel = 0
            scroll.Position = UDim2.fromOffset(30, contentTop)
            scroll.Size = UDim2.new(1, -60, 1, -(contentTop + 24))
            scroll.ScrollBarThickness = 0
            scroll.ScrollBarImageTransparency = 1
            scroll.ScrollingDirection = Enum.ScrollingDirection.Y
            scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
            scroll.CanvasSize = UDim2.fromScale(0, 0)
            scroll.ElasticBehavior = Enum.ElasticBehavior.Always
            scroll.Selectable = false
            scroll.ZIndex = 62
            scroll.Parent = panel

            local scrollLayout = Instance.new("UIListLayout")
            scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
            scrollLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            scrollLayout.Padding = UDim.new(0, 20)
            scrollLayout.Parent = scroll

            local lineRow = Instance.new("Frame")
            lineRow.Name = "LineRow"
            lineRow.BackgroundTransparency = 1
            lineRow.BorderSizePixel = 0
            lineRow.Size = UDim2.new(1, 0, 0, 10)
            lineRow.LayoutOrder = 0
            lineRow.ZIndex = 62
            lineRow.Parent = scroll

            local pillW = math.floor(popW * 0.645)
            local pillH = 56

            local index = 0
            for _, itemText in items do
                index += 1
                local slot = Instance.new("Frame")
                slot.Name = "Slot" .. index
                slot.BackgroundTransparency = 1
                slot.BorderSizePixel = 0
                slot.Size = UDim2.fromOffset(pillW, pillH)
                slot.LayoutOrder = index
                slot.ZIndex = 62
                slot.Parent = scroll

                local item = Instance.new("TextButton")
                item.Name = "Item" .. index
                item.Text = ""
                item.AutoButtonColor = false
                item.BorderSizePixel = 0
                item.AnchorPoint = Vector2.new(0.5, 0.5)
                item.Position = UDim2.fromScale(0.5, 0.5)
                item.Size = UDim2.fromScale(1, 1)
                item.ZIndex = 63
                item.BackgroundColor3 = colors.SwitchTrackOff
                item.Parent = slot

                local itemCorner = Instance.new("UICorner")
                itemCorner.CornerRadius = UDim.new(0, 18)
                itemCorner.Parent = item

                local itemStroke = Instance.new("UIStroke")
                itemStroke.Color = colors.MenuStroke
                itemStroke.Thickness = 2
                itemStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                itemStroke.Parent = item

                local labelText = Instance.new("TextLabel")
                labelText.Name = "Text"
                labelText.BackgroundTransparency = 1
                labelText.BorderSizePixel = 0
                labelText.Position = UDim2.fromOffset(20, 0)
                labelText.Size = UDim2.new(1, -40, 1, 0)
                labelText.FontFace = Theme.GetFace()
                labelText.Text = itemText
                labelText.TextColor3 = colors.TextPrimary
                labelText.TextSize = itemTextSize
                labelText.TextTruncate = Enum.TextTruncate.AtEnd
                labelText.TextXAlignment = Enum.TextXAlignment.Center
                labelText.ZIndex = 63
                labelText.Parent = item
                FitText.fit(labelText, {
                    Base = itemTextSize,
                    Min = layout.LabelMinSize,
                })

                local feedback = Animate.HoldFeedback(item, item, {
                    Grow = 1.1,
                    GrowTime = 0.15,
                    ReleaseTime = 0.6,
                    ReleaseStyle = Enum.EasingStyle.Elastic,
                })

                local target = {
                    Node = item,
                    PressIn = feedback.Press,
                    PressOut = feedback.Reverse,
                    Release = feedback.Release,
                }
                PressFlow.Register(target)

                item.InputBegan:Connect(function(input: InputObject)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch
                    then
                        PressFlow.Begin(target, input)
                    end
                end)

                local picked = trim(itemText)
                item.Activated:Connect(function()
                    applyName(picked)
                    closePopup()
                end)
            end
        end

        popup = container
        activeClose = closePopup
    end

    local iconSize = 60
    local iconGap = 8
    local nameBoxW = 430

    local tripleRow = buildRow(layout.RowH)
    local tripleList = Instance.new("UIListLayout")
    tripleList.FillDirection = Enum.FillDirection.Horizontal
    tripleList.Padding = UDim.new(0, 10)
    tripleList.HorizontalAlignment = Enum.HorizontalAlignment.Left
    tripleList.SortOrder = Enum.SortOrder.LayoutOrder
    tripleList.Parent = tripleRow
    makeToggleCell(tripleRow, "Record", 2, 90, modeController("Record"), 1)
    makeToggleCell(tripleRow, "Play", 2, 90, modeController("Play"), 2)
    makeToggleCell(tripleRow, "Continue", 2, 90, modeController("Continue"), 3)

    buildSpacer(6)

    local row = buildRow(layout.RowH)

    local pillFrame = Instance.new("Frame")
    pillFrame.Name = "NamePill"
    pillFrame.BackgroundColor3 = colors.SwitchTrackOff
    pillFrame.BorderSizePixel = 0
    pillFrame.AnchorPoint = Vector2.new(0, 0.5)
    pillFrame.Position = UDim2.new(0, 2, 0.5, 0)
    pillFrame.Size = UDim2.fromOffset(nameBoxW, 60)
    pillFrame.Parent = row
    pill = pillFrame

    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = UDim.new(0, 6)
    pillCorner.Parent = pillFrame

    local box = Instance.new("TextBox")
    box.Name = "Field"
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Position = UDim2.fromOffset(14, 0)
    box.Size = UDim2.new(1, -28, 1, 0)
    box.FontFace = Theme.GetFace()
    box.TextColor3 = colors.TextPrimary
    box.PlaceholderColor3 = colors.RadioRingOff
    box.PlaceholderText = "Replay Name"
    box.Text = tostring(state.Name or "")
    box.TextSize = layout.BoxTextSize
    box.TextXAlignment = Enum.TextXAlignment.Center
    box.ClearTextOnFocus = false
    box.TextTruncate = Enum.TextTruncate.AtEnd
    box.Parent = pillFrame
    nameBox = box

    local pcField = pcRows.NameField
    if typeof(pcField) == "Instance" and (pcField :: Instance):IsA("TextBox") then
        local fieldBox = pcField :: TextBox
        table.insert(cleanupConns, fieldBox:GetPropertyChangedSignal("Text"):Connect(function()
            if syncingName then
                return
            end
            local mirror = nameBox
            if mirror ~= nil then
                mirror.Text = fieldBox.Text
            end
            state.Name = fieldBox.Text
        end))
        if fieldBox.Text ~= "" then
            box.Text = fieldBox.Text
            state.Name = fieldBox.Text
        end
    end

    box:GetPropertyChangedSignal("Text"):Connect(function()
        state.Name = box.Text
    end)
    box.FocusLost:Connect(function()
        applyName(trim(box.Text))
    end)

    local assets = Theme.GetAssets()

    local arrow = makeIcon(row, 2 + nameBoxW + iconGap + iconSize, iconSize, assets.Arrow, "▾", function()
        if popup ~= nil then
            closePopup()
        else
            openPopup()
        end
    end)
    arrowBtn = arrow

    makeIcon(row, 2 + nameBoxW + iconGap * 2 + iconSize * 2, iconSize, assets.Remove, "✕", deleteReplay)
    makeIcon(row, 2 + nameBoxW + iconGap * 3 + iconSize * 3, iconSize, assets.Import, "↓", importReplay)

    buildSpacer(6)

    local buttonSlots = buildSlots(3, 150, 10)
    makeActionButton(buttonSlots[1], 150, "Save", fireSave)
    makeActionButton(buttonSlots[2], 150, "Load", fireLoad)
    makeActionButton(buttonSlots[3], 150, "Clear", fireClear)

    buildSpacer(6)

    local pairSlots = buildSlots(2, layout.CellW)
    makeToggleCell(pairSlots[1], "Accuracy Fix", layout.SwitchX, layout.LabelX, proController("Accuracy Fix"))
    makeToggleCell(pairSlots[2], "Y Velocity Fix", layout.SwitchX, layout.LabelX, proController("Y Velocity Fix"))

    buildSpacer(6)

    local singleRow = buildRow(layout.RowH)
    makeToggleCell(singleRow, "Ignore Input on Playback", layout.SwitchX, layout.LabelX, proController("Ignore Inputs on Playback"))

    buildSpacer(120)

    local statusRow = buildRow(44)
    local frameText = Instance.new("TextLabel")
    frameText.Name = "FrameText"
    frameText.BackgroundTransparency = 1
    frameText.BorderSizePixel = 0
    frameText.Position = UDim2.fromOffset(4, 0)
    frameText.Size = UDim2.new(1, -8, 0, 22)
    frameText.FontFace = Theme.GetFace()
    frameText.Text = "Frame: 0"
    frameText.TextColor3 = colors.TextPrimary
    frameText.TextSize = 24
    frameText.TextXAlignment = Enum.TextXAlignment.Left
    frameText.Parent = statusRow
    frameLabel = frameText

    local sizeText = Instance.new("TextLabel")
    sizeText.Name = "SizeText"
    sizeText.BackgroundTransparency = 1
    sizeText.BorderSizePixel = 0
    sizeText.Position = UDim2.fromOffset(4, 22)
    sizeText.Size = UDim2.new(1, -8, 0, 22)
    sizeText.FontFace = Theme.GetFace()
    sizeText.Text = "Replay Size: 0/0"
    sizeText.TextColor3 = colors.TextPrimary
    sizeText.TextSize = 24
    sizeText.TextXAlignment = Enum.TextXAlignment.Left
    sizeText.Parent = statusRow
    sizeLabel = sizeText

    updateStatus()

    local pcFrameLabel = pcRows.Labels.Frame
    if typeof(pcFrameLabel) == "Instance" and (pcFrameLabel :: Instance):IsA("TextLabel") then
        local source = pcFrameLabel :: TextLabel
        table.insert(cleanupConns, source:GetPropertyChangedSignal("Text"):Connect(function()
            local target = frameLabel
            if target ~= nil then
                target.Text = source.Text
            end
        end))
        local target = frameLabel
        if target ~= nil then
            target.Text = source.Text
        end
    end
    local pcSizeLabel = pcRows.Labels.Size
    if typeof(pcSizeLabel) == "Instance" and (pcSizeLabel :: Instance):IsA("TextLabel") then
        local source = pcSizeLabel :: TextLabel
        table.insert(cleanupConns, source:GetPropertyChangedSignal("Text"):Connect(function()
            local target = sizeLabel
            if target ~= nil then
                target.Text = source.Text
            end
        end))
        local target = sizeLabel
        if target ~= nil then
            target.Text = source.Text
        end
    end

    local nameRow = row
    nameRow.Destroying:Connect(function()
        if menuConn ~= nil then
            pcall(function()
                menuConn:Disconnect()
            end)
            menuConn = nil
        end
        closePopup()
        disconnectAll()
    end)

    local overlay = config.Overlay
    if typeof(overlay) == "Instance" then
        menuConn = (overlay :: Instance):GetPropertyChangedSignal("Visible"):Connect(function()
            if (overlay :: Instance).Visible == false then
                closePopup()
            end
        end)
    end
end

return ReplayTab
