local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local function importMobile(name: string): any
    local Import = genv.Import
    if Import then
        local module = Import("interface/Mobile/" .. name)
        if module ~= nil then
            return module
        end
    end
    local widgetsPrefix = "Widgets/"
    if string.sub(name, 1, #widgetsPrefix) == widgetsPrefix then
        return require(script.Parent.Widgets[string.sub(name, #widgetsPrefix + 1)])
    end
    return require(script.Parent[name])
end

return function()
    local UI = genv.GDH_UI
    if typeof(UI) ~= "table" then
        return
    end

    if typeof(genv.GDH_MOBILE_KILL) == "function" then
        pcall(genv.GDH_MOBILE_KILL)
    end
    genv.GDH_MOBILE_KILL = nil

    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")

    local Theme = importMobile("Theme")
    local Animate = importMobile("Animate")
    local ToggleCell = importMobile("Widgets/Toggle")
    local TabButton = importMobile("Widgets/TabButton")
    local OverlayButton = importMobile("Widgets/OverlayButton")
    local ButtonRowCell = importMobile("Widgets/Button")
    local NumberInputCell = importMobile("Widgets/NumberInput")
    local SliderCell = importMobile("Widgets/Slider")
    local DropdownCell = importMobile("Widgets/Dropdown")
    local RadioCell = importMobile("Widgets/Radio")
    local TextInputCell = importMobile("Widgets/TextInput")
    local ReplayTab = importMobile("Widgets/Replay")
    local InfoPopup = importMobile("Widgets/InfoPopup")
    local SettingsTab = importMobile("Widgets/Settings")
    local SearchTab = importMobile("Widgets/Search")
    local HackSettings = importMobile("Widgets/HackSettings")
    local FitText = importMobile("FitText")
    local Keyboard = genv.GDH_Keyboard
    if typeof(Keyboard) ~= "table" and typeof(genv.Import) == "function" then
        pcall(function()
            Keyboard = genv.Import("Function/Keyboard")
        end)
    end
    if typeof(Keyboard) ~= "table" then
        Keyboard = { Protect = function() end }
    end

    local replayTabTitle = "Replay Engine"
    local settingsTabTitle = "Settings"
    local searchTabTitle = "Search"

    local applyFitRef: (() -> ())? = nil

    local settingsState = genv.GDH_MOBILE_SETTINGS
    if typeof(settingsState) ~= "table" then
        settingsState = {
            IconScale = 0.5,
            MinOpacity = 0.8,
            NotifyUpdates = true,
        }
        genv.GDH_MOBILE_SETTINGS = settingsState
    end
    if typeof(settingsState.IconScale) ~= "number" then
        settingsState.IconScale = 0.5
    end
    if typeof(settingsState.MinOpacity) ~= "number" then
        settingsState.MinOpacity = 0.8
    end
    if typeof(settingsState.NotifyUpdates) ~= "boolean" then
        settingsState.NotifyUpdates = true
    end

    local connections: { RBXScriptConnection } = {}
    local viewportConn: RBXScriptConnection? = nil

    local layout = Theme.Layout
    local colors = Theme.Colors

    local isOpen = false
    local isAnimating = false
    local activeTweens: { Tween } = {}
    local fitScaleBase = 1
    local currentTabTitle: string? = nil

    local tabOrder: { string } = {}
    local tabGroups: { [string]: { any } } = {}
    local tabMeta: { [string]: { any } } = {}
    local tabApis: { [string]: any } = {}
    local tabCounter = 0
    local rowOrder = 0

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "GDH Mobile"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 998
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui:SetAttribute("GDHUI", true)

    local root = Instance.new("Frame")
    root.Name = "Mobile"
    root.BackgroundTransparency = 1
    root.BorderSizePixel = 0
    root.Size = UDim2.fromScale(1, 1)
    root.Parent = screenGui

    local mobileVersionStr = "v1.0"
    local mobileInfoJson = genv.GDH_PACKAGE and genv.GDH_PACKAGE["src/info.json"]
    if typeof(mobileInfoJson) == "string" and mobileInfoJson ~= "" then
        local okDecode, decoded = pcall(function()
            return game:GetService("HttpService"):JSONDecode(mobileInfoJson)
        end)
        if okDecode and typeof(decoded) == "table"
            and typeof(decoded.version) == "string"
            and decoded.version ~= ""
        then
            mobileVersionStr = decoded.version
        end
    end

    local mobileBadge = Instance.new("Frame")
    mobileBadge.Name = "VersionBadge"
    mobileBadge.Active = true
    mobileBadge.BorderSizePixel = 0
    mobileBadge.BackgroundTransparency = 1
    mobileBadge.AnchorPoint = Vector2.new(1, 1)
    mobileBadge.Position = UDim2.new(1, -10, 1, -10)
    mobileBadge.Size = UDim2.fromOffset(334, 69)
    mobileBadge.ZIndex = 5
    mobileBadge.Visible = false
    mobileBadge.Parent = root

    local mobileRect11 = Instance.new("Frame")
    mobileRect11.Name = "Rectangle 11"
    mobileRect11.Active = true
    mobileRect11.BorderSizePixel = 0
    mobileRect11.BackgroundColor3 = Color3.fromRGB(183, 155, 209)
    mobileRect11.Size = UDim2.fromOffset(114, 60)
    mobileRect11.Position = UDim2.fromOffset(5, 7)
    mobileRect11.Parent = mobileBadge
    local mobileRect11Corner = Instance.new("UICorner")
    mobileRect11Corner.CornerRadius = UDim.new(0, 61)
    mobileRect11Corner.Parent = mobileRect11

    local mobileGdhText = Instance.new("TextLabel")
    mobileGdhText.Name = "GDH"
    mobileGdhText.TextWrapped = true
    mobileGdhText.Active = true
    mobileGdhText.BorderSizePixel = 0
    mobileGdhText.TextSize = 40
    mobileGdhText.FontFace = Theme.GetFace()
    mobileGdhText.TextColor3 = Color3.fromRGB(40, 27, 69)
    mobileGdhText.BackgroundTransparency = 1
    mobileGdhText.Size = UDim2.fromOffset(114, 60)
    mobileGdhText.Text = "GDH"
    mobileGdhText.Position = UDim2.fromOffset(5, 7)
    mobileGdhText.Parent = mobileBadge

    local mobileReleaseText = Instance.new("TextLabel")
    mobileReleaseText.Name = "Release"
    mobileReleaseText.TextWrapped = true
    mobileReleaseText.Active = true
    mobileReleaseText.BorderSizePixel = 0
    mobileReleaseText.TextSize = 34
    mobileReleaseText.FontFace = Theme.GetFace()
    mobileReleaseText.TextColor3 = Color3.fromRGB(191, 175, 184)
    mobileReleaseText.BackgroundTransparency = 1
    mobileReleaseText.Size = UDim2.fromOffset(206, 36)
    mobileReleaseText.Text = mobileVersionStr
    mobileReleaseText.Position = UDim2.fromOffset(124, 18)
    mobileReleaseText.Parent = mobileBadge

    local backdrop = Instance.new("TextButton")
    backdrop.Name = "Backdrop"
    backdrop.Text = ""
    backdrop.AutoButtonColor = false
    backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
    backdrop.BackgroundTransparency = 1
    backdrop.BorderSizePixel = 0
    backdrop.Size = UDim2.fromScale(1, 1)
    backdrop.ZIndex = 1
    backdrop.Visible = false
    backdrop.Parent = root

    local menu = Instance.new("Frame")
    menu.Name = "Menu"
    menu.Active = true
    menu.BackgroundTransparency = 1
    menu.BorderSizePixel = 0
    menu.AnchorPoint = Vector2.new(0.5, 0.5)
    menu.Position = UDim2.fromScale(0.5, 0.5)
    menu.Size = UDim2.fromOffset(layout.MenuW, layout.MenuH)
    menu.ZIndex = 2
    menu.Visible = false
    menu.Parent = root

    local fit = Instance.new("UIScale")
    fit.Name = "Fit"
    fit.Scale = 1
    fit.Parent = menu

    local background = Instance.new("Frame")
    background.Name = "Background"
    background.Active = true
    background.BackgroundColor3 = colors.MenuBG
    background.BorderSizePixel = 0
    background.Position = UDim2.fromOffset(2, 0)
    background.Size = UDim2.fromOffset(layout.BgW, layout.BgH)
    background.ZIndex = 1
    background.Parent = menu

    local backgroundCorner = Instance.new("UICorner")
    backgroundCorner.CornerRadius = UDim.new(0, layout.BgCorner)
    backgroundCorner.Parent = background

    local backgroundStroke = Instance.new("UIStroke")
    backgroundStroke.Thickness = layout.BgStroke
    backgroundStroke.Color = colors.MenuStroke
    backgroundStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    backgroundStroke.Parent = background

    local sidebar = Instance.new("ScrollingFrame")
    sidebar.Name = "Windows"
    sidebar.Active = true
    sidebar.BackgroundColor3 = colors.SidebarBG
    sidebar.BorderSizePixel = 0
    sidebar.Position = UDim2.fromOffset(layout.SidebarX, layout.SidebarY)
    sidebar.Size = UDim2.fromOffset(layout.SidebarW, layout.SidebarH)
    sidebar.ScrollBarThickness = 0
    sidebar.ScrollBarImageTransparency = 1
    sidebar.ScrollingDirection = Enum.ScrollingDirection.Y
    sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sidebar.CanvasSize = UDim2.fromScale(0, 0)
    sidebar.ElasticBehavior = Enum.ElasticBehavior.Always
    sidebar.Selectable = false
    sidebar.ZIndex = 2
    sidebar.Parent = menu

    local sidebarCorner = Instance.new("UICorner")
    sidebarCorner.CornerRadius = UDim.new(0, layout.SidebarCorner)
    sidebarCorner.Parent = sidebar

    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    sidebarLayout.Padding = UDim.new(0, layout.SidebarPad)
    sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sidebarLayout.Parent = sidebar

    local line = Instance.new("Frame")
    line.Name = "Line"
    line.BackgroundColor3 = Color3.new(1, 1, 1)
    line.BackgroundTransparency = 1
    line.BorderSizePixel = 0
    line.Size = UDim2.fromOffset(100, 0)
    line.LayoutOrder = 1
    line.Parent = sidebar

    local bottomLine = Instance.new("Frame")
    bottomLine.Name = "Line"
    bottomLine.BackgroundColor3 = Color3.new(1, 1, 1)
    bottomLine.BackgroundTransparency = 1
    bottomLine.BorderSizePixel = 0
    bottomLine.Size = UDim2.fromOffset(100, 0)
    bottomLine.LayoutOrder = 9999
    bottomLine.Parent = sidebar

    local list = Instance.new("ScrollingFrame")
    list.Name = "list"
    list.Active = true
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.Position = UDim2.fromOffset(layout.ListX, layout.ListY)
    list.Size = UDim2.fromOffset(layout.ListW, layout.ListH)
    list.ScrollBarThickness = 0
    list.ScrollBarImageTransparency = 1
    list.ScrollingDirection = Enum.ScrollingDirection.Y
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.CanvasSize = UDim2.fromScale(0, 0)
    list.ElasticBehavior = Enum.ElasticBehavior.Always
    list.Selectable = false
    list.ZIndex = 2
    list.Parent = menu

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, layout.ListPad)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = list

    local toggleMenu: () -> ()

    local overlay: any = nil
    local showOverlay = UserInputService.TouchEnabled
        and not UserInputService.KeyboardEnabled
        and not UserInputService.MouseEnabled
    if showOverlay then
        overlay = OverlayButton({
            Root = root,
            Size = layout.IconBase,
            MinOpacity = settingsState.MinOpacity,
            OnActivated = function()
                toggleMenu()
            end,
        })
    end

    local function refreshTabStyles()
        for title, api in tabApis do
            api.SetActive(title == currentTabTitle)
        end
    end

    local pairKinds = {
        Toggle = true,
        Radio = true,
        IntInput = true,
        FloatInput = true,
    }

    local function notifyFn(text: string, duration: number?)
        InfoPopup.Show(root, "Info", tostring(text), fit.Scale)
    end

    local settingsHacks: { [string]: boolean } = {}
    local hackSettingLabels: { [string]: Instance } = {}

    local function hackStateFor(name: string): { any }
        local store = genv.GDH_MOBILE_HACK_SETTINGS
        if typeof(store) ~= "table" then
            store = {}
            genv.GDH_MOBILE_HACK_SETTINGS = store
        end
        local state = (store :: { any })[name]
        if typeof(state) ~= "table" then
            state = {}
            (store :: { any })[name] = state
        end
        return state :: { any }
    end

    local function storedTitleColor(name: string): Color3?
        local store = genv.GDH_MOBILE_HACK_SETTINGS
        if typeof(store) ~= "table" then
            return nil
        end
        local state = (store :: { any })[name]
        if typeof(state) == "table" and typeof((state :: { any }).TitleColor) == "Color3" then
            return (state :: { any }).TitleColor :: Color3
        end
        return nil
    end

    local function popupToggleItem(row: Instance): any?
        local text = row:GetAttribute("GDHSettingText")
        if typeof(text) ~= "string" or text == "" then
            text = ""
            local title = row:FindFirstChild("Title")
            if typeof(title) == "Instance"
                and ((title :: Instance):IsA("TextLabel") or (title :: Instance):IsA("TextButton"))
            then
                text = (title :: TextButton).Text
            end
        end
        if typeof(text) ~= "string" or text == "" then
            return nil
        end
        local api = nil
        local apis = genv.GDH_ToggleRowApis
        if typeof(apis) == "table" then
            api = apis[row]
        end
        local function getState(): boolean
            if typeof(api) == "table" and typeof(api.GetState) == "function" then
                local ok, state = pcall(api.GetState)
                if ok and typeof(state) == "boolean" then
                    return state
                end
            end
            return row:GetAttribute("State") == true
        end
        local function setState(on: boolean)
            if typeof(api) == "table" and typeof(api.SetState) == "function" then
                pcall(api.SetState, on)
                return
            end
            row:SetAttribute("State", on)
        end
        return {
            Kind = "Toggle",
            Text = text,
            Get = getState,
            Set = setState,
            Row = row,
        }
    end

    local function popupValueItem(entry: any): any?
        local row = entry.Row
        if typeof(row) ~= "Instance" then
            return nil
        end
        local kind = tostring(entry.Kind or "")
        return {
            Kind = if kind == "FloatInput" then "Float" else "Int",
            Text = tostring(entry.Name or ""),
            Get = entry.Get,
            Set = entry.Set,
            Min = entry.Min,
            Max = entry.Max,
            Default = entry.Default,
            Row = row,
        }
    end

    local function popupColorItem(row: Instance): any?
        local apis = genv.GDH_SETTING_ROW_APIS
        if typeof(apis) ~= "table" then
            return nil
        end
        local api = (apis :: { any })[row]
        if typeof(api) ~= "table"
            or typeof(api.Get) ~= "function"
            or typeof(api.Set) ~= "function"
        then
            return nil
        end
        local text = row:GetAttribute("GDHSettingText")
        if typeof(text) ~= "string" or text == "" then
            text = "Color"
        end
        return {
            Kind = "Color",
            Text = text :: string,
            Get = api.Get,
            Set = api.Set,
            Row = row,
        }
    end

    local function buildPopupMirrorItems(popup: any): { any }
        local items: { any } = {}
        local popupWin = popup.Window
        if typeof(popupWin) ~= "table" then
            popupWin = popup._window
        end
        if typeof(popupWin) ~= "table" then
            popupWin = popup
        end
        local rows = popupWin._mobileRows
        if typeof(rows) == "table" then
            for _, entry in rows :: { any } do
                if typeof(entry) ~= "table" then
                    continue
                end
                local row = entry.Row
                if typeof(row) ~= "Instance" then
                    continue
                end
                local rowInstance = row :: Instance
                local kind = tostring(entry.Kind or "")
                if rowInstance:GetAttribute("GDHSettingKind") == "Color" then
                    local item = popupColorItem(rowInstance)
                    if item ~= nil then
                        table.insert(items, item)
                    end
                elseif kind == "Toggle" then
                    local item = popupToggleItem(rowInstance)
                    if item ~= nil then
                        table.insert(items, item)
                    end
                elseif kind == "IntInput" or kind == "FloatInput" then
                    local item = popupValueItem(entry)
                    if item ~= nil then
                        table.insert(items, item)
                    end
                elseif kind == "Slider" then
                    table.insert(items, {
                        Kind = "Slider",
                        Text = tostring(entry.Name or ""),
                        Name = entry.Name,
                        Suffix = entry.Suffix,
                        Min = entry.Min,
                        Max = entry.Max,
                        Increment = entry.Increment,
                        Precision = entry.Precision,
                        HasToggle = entry.HasToggle,
                        Row = rowInstance,
                    })
                elseif kind == "ButtonRow" then
                    local buttons = entry.Buttons
                    if typeof(buttons) == "table" and #buttons > 0 then
                        local button = buttons[1]
                        if typeof(button) == "table" then
                            table.insert(items, {
                                Kind = "Button",
                                Text = tostring(button.Text or ""),
                                Fire = button.Fire,
                                Row = rowInstance,
                            })
                        end
                    end
                elseif kind == "Label" then
                    local text = ""
                    if rowInstance:IsA("TextLabel") then
                        text = (rowInstance :: TextLabel).Text
                    end
                    if typeof(text) == "string" and text ~= "" then
                        table.insert(items, { Kind = "Label", Text = text })
                    end
                elseif kind == "Separator" then
                    table.insert(items, { Kind = "Separator" })
                end
            end
            return items
        end

        local contentFrame: Instance? = nil
        if typeof(popupWin) == "table" and typeof(popupWin.GetContentFrame) == "function" then
            local ok, frame = pcall(function()
                return popupWin:GetContentFrame()
            end)
            if ok and typeof(frame) == "Instance" then
                contentFrame = frame
            end
        end
        if contentFrame == nil then
            return items
        end
        for _, node in (contentFrame :: Instance):GetChildren() do
            if typeof(node) ~= "Instance" then
                continue
            end
            local nodeInstance = node :: Instance
            if nodeInstance:GetAttribute("WidgetType") == "Toggle" then
                local item = popupToggleItem(nodeInstance)
                if item ~= nil then
                    table.insert(items, item)
                end
            elseif nodeInstance:IsA("TextLabel") then
                local text = (nodeInstance :: TextLabel).Text
                if typeof(text) == "string" and text ~= "" then
                    table.insert(items, {
                        Kind = "Label",
                        Text = text,
                    })
                end
            else
                for _, inner in nodeInstance:GetDescendants() do
                    if typeof(inner) == "Instance" and (inner :: Instance):GetAttribute("WidgetType") == "Toggle" then
                        local item = popupToggleItem(inner :: Instance)
                        if item ~= nil then
                            table.insert(items, item)
                        end
                    end
                end
            end
        end
        return items
    end

    local function buildHackSettings(entry: any): any?
        local name = tostring(entry.Name or "")
        local lowerName = string.lower(name)
        local pcRow = entry.Row

        local popup = nil
        if typeof(pcRow) == "Instance" then
            local showPopups = genv.GDH_SHOW_POPUPS
            if typeof(showPopups) == "table" then
                local target = (showPopups :: { any })[pcRow :: Instance]
                if typeof(target) == "table" then
                    popup = target
                end
            end
        end

        local assets = Theme.GetAssets()
        local items: { any } = {}
        local title = name

        if popup ~= nil then
            local popupWin = popup.Window
            if typeof(popupWin) ~= "table" then
                popupWin = popup._window
            end
            if typeof(popupWin) == "table" then
                local popupTitle = popupWin._title
                if typeof(popupTitle) == "string" and popupTitle ~= "" then
                    title = popupTitle
                end
            end
            items = buildPopupMirrorItems(popup)
        else
            return nil
        end

        local settingsConfig: { any } = {
            Image = if typeof(assets.Settings) == "string" then assets.Settings else "",
            Title = title,
            Items = items,
            Notify = notifyFn,
        }
        settingsConfig.Activate = function()
            HackSettings.Show({
                Overlay = menu,
                Root = root,
                Fit = fit,
                Title = title,
                Items = items,
                Notify = notifyFn,
            })
        end
        return settingsConfig
    end

    local function refreshTabContent()
        for _, child in list:GetChildren() do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
        rowOrder = 0
        if currentTabTitle == replayTabTitle then
            ReplayTab({
                List = list,
                Overlay = menu,
                Root = root,
                Fit = fit,
                Notify = notifyFn,
            })
            return
        end
        if currentTabTitle == settingsTabTitle then
            SettingsTab({
                List = list,
                Overlay = menu,
                Root = root,
                Fit = fit,
                Notify = notifyFn,
                Icon = overlay,
                ApplyIcon = function()
                    local callback = applyFitRef
                    if typeof(callback) == "function" then
                        callback()
                    end
                end,
            })
            return
        end
        if currentTabTitle == searchTabTitle then
            SearchTab({
                List = list,
                Notify = notifyFn,
                BuildSettings = buildHackSettings,
                Host = root,
                Root = root,
                FitScale = fit,
            })
            return
        end
        local entries = tabGroups[currentTabTitle :: string]
        if entries == nil then
            local emptyLabel = Instance.new("TextLabel")
            emptyLabel.Name = "Empty"
            emptyLabel.BackgroundTransparency = 1
            emptyLabel.BorderSizePixel = 0
            emptyLabel.Size = UDim2.fromOffset(layout.ListW, 40)
            emptyLabel.FontFace = Theme.GetFace()
            emptyLabel.Text = "No rows found"
            emptyLabel.TextColor3 = colors.TextPrimary
            emptyLabel.TextSize = layout.EmptySize
            emptyLabel.Parent = list
            return
        end
        local rowFrame: Frame? = nil
        local cellCount = 0
        local rowListLayout: UIListLayout? = nil

        local function buildRowFrame(): Frame
            rowOrder += 1
            local frame = Instance.new("Frame")
            frame.Name = "Row" .. rowOrder
            frame.BackgroundTransparency = 1
            frame.BorderSizePixel = 0
            frame.Size = UDim2.fromOffset(layout.ListW, layout.RowH)
            frame.LayoutOrder = rowOrder
            local rowList = Instance.new("UIListLayout")
            rowList.FillDirection = Enum.FillDirection.Horizontal
            rowList.Padding = UDim.new(0, 0)
            rowList.SortOrder = Enum.SortOrder.LayoutOrder
            rowList.Parent = frame
            frame.Parent = list
            return frame
        end

        local function buildFullRow(height: number?): Frame
            rowOrder += 1
            local frame = Instance.new("Frame")
            frame.Name = "Row" .. rowOrder
            frame.BackgroundTransparency = 1
            frame.BorderSizePixel = 0
            frame.Size = UDim2.new(1, 0, 0, height or layout.RowH)
            frame.LayoutOrder = rowOrder
            frame.Parent = list
            rowFrame = nil
            cellCount = 0
            rowListLayout = nil
            return frame
        end

        local function beginCell(): Frame
            if rowFrame == nil or cellCount >= 2 then
                rowFrame = buildRowFrame()
                rowListLayout = (rowFrame :: Frame):FindFirstChildOfClass("UIListLayout")
                cellCount = 0
            end
            cellCount += 1
            if rowListLayout ~= nil then
                rowListLayout.HorizontalAlignment = if cellCount == 1
                    then Enum.HorizontalAlignment.Center
                    else Enum.HorizontalAlignment.Left
            end
            return rowFrame :: Frame
        end

        local function buildLabelRow(parent: Frame, entry: any)
            local text = ""
            local textColor = colors.TextPrimary
            local textSize = layout.LabelSize
            local source = entry.Row
            if typeof(source) == "Instance" and (source :: Instance):IsA("TextLabel") then
                local sourceLabel = source :: TextLabel
                text = sourceLabel.Text
                textColor = sourceLabel.TextColor3
                textSize = layout.LabelSize
            end
            parent.Size = UDim2.new(1, 0, 0, layout.RowH)
            parent.AutomaticSize = Enum.AutomaticSize.None
            local label = Instance.new("TextLabel")
            label.Name = "LabelText"
            label.BackgroundTransparency = 1
            label.BorderSizePixel = 0
            label.Size = UDim2.new(1, 0, 1, 0)
            label.AutomaticSize = Enum.AutomaticSize.None
            label.FontFace = Theme.GetFace()
            label.Text = text
            label.TextColor3 = textColor
            label.TextSize = textSize
            label.TextWrapped = false
            label.TextTruncate = Enum.TextTruncate.None
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = parent
            FitText.fit(label, {
                Base = textSize,
                Min = layout.LabelMinSize,
            })
        end

        local function buildSeparatorRow(entry: any)
            local source = entry.Row
            local text = ""
            local pcHeight = 0
            if typeof(source) == "Instance" then
                local sourceRow = source :: Instance
                local textChild = sourceRow:FindFirstChild("Text")
                if textChild ~= nil and textChild:IsA("TextLabel") then
                    text = textChild.Text
                end
                pcHeight = sourceRow.Size.Y.Offset
            end
            local height = 18
            if pcHeight > 0 then
                height = math.clamp(pcHeight, 14, 48)
            end
            if text ~= "" then
                height = math.max(height, 22)
            end
            local parent = buildFullRow(height)
            local line = Instance.new("Frame")
            line.Name = "Line"
            line.BackgroundColor3 = colors.Separator
            line.BackgroundTransparency = 0.55
            line.BorderSizePixel = 0
            line.AnchorPoint = Vector2.new(0, 0.5)
            line.Position = UDim2.new(0, 0, 0.5, 0)
            line.Size = UDim2.new(1, 0, 0, 2)
            line.Parent = parent
            if text ~= "" then
                local label = Instance.new("TextLabel")
                label.Name = "SepText"
                label.BackgroundColor3 = colors.MenuBG
                label.BackgroundTransparency = 0
                label.BorderSizePixel = 0
                label.AnchorPoint = Vector2.new(0.5, 0.5)
                label.Position = UDim2.new(0.5, 0, 0.5, 0)
                label.AutomaticSize = Enum.AutomaticSize.X
                label.Size = UDim2.new(0, 0, 1, 0)
                label.FontFace = Theme.GetFace()
                label.Text = text
                label.TextColor3 = colors.TextPrimary
                label.TextTransparency = 0.35
                label.TextSize = 18
                label.Parent = parent
            end
        end

        local prevKind: string? = nil
        for i = 1, #entries do
            local entry = entries[i]
            local kind = tostring(entry.Kind or "Toggle")
            local nextEntry = entries[i + 1]
            local nextKind = if nextEntry ~= nil then tostring(nextEntry.Kind or "Toggle") else nil
            if pairKinds[kind] == true then
                local parent = beginCell()
                local split: string? = nil
                if cellCount == 2 then
                    if prevKind ~= nil and pairKinds[prevKind] == true then
                        split = "right"
                    end
                elseif nextKind ~= nil and pairKinds[nextKind] == true then
                    split = "left"
                end
                if kind == "Toggle" then
                    local cellApi = ToggleCell({
                        Row = entry.Row,
                        Name = entry.Name,
                        Description = entry.Description or (typeof(entry.Row) == "Instance" and entry.Row:GetAttribute("Description")),
                        Parent = parent,
                        Notify = notifyFn,
                        SliderSplit = split,
                        Host = root,
                        Root = root,

                        FitScale = fit,
                        Settings = buildHackSettings(entry),
                    })
                    local lowerName = string.lower(tostring(entry.Name or ""))
                    if settingsHacks[lowerName] == true and typeof(cellApi.Label) == "Instance" then
                        local cellLabel = cellApi.Label :: TextLabel
                        hackSettingLabels[lowerName] = cellLabel
                        local storedColor = storedTitleColor(lowerName)
                        if storedColor ~= nil then
                            cellLabel.TextColor3 = storedColor :: Color3
                        end
                    end
                elseif kind == "Radio" then
                    RadioCell({
                        Row = entry.Row,
                        Name = entry.Name,
                        Parent = parent,
                        Notify = notifyFn,
                        SliderSplit = split,
                    })
                else
                    NumberInputCell({
                        Parent = parent,
                        IsFloat = kind == "FloatInput",
                        Name = entry.Name,
                        Min = entry.Min,
                        Max = entry.Max,
                        Default = entry.Default,
                        Get = entry.Get,
                        Set = entry.Set,
                        SliderSplit = split,
                    })
                end
            elseif kind == "ButtonRow" then
                local win = entry.Window
                local fullWidth = typeof(win) == "table" and tostring(win._title or "") == "Shortcuts"
                ButtonRowCell({
                    Parent = buildFullRow(),
                    Buttons = entry.Buttons,
                    FullWidth = fullWidth,
                })
            elseif kind == "Label" then
                buildLabelRow(buildFullRow(), entry)
            elseif kind == "Separator" then
                buildSeparatorRow(entry)
            elseif kind == "Padding" then
                buildFullRow(math.max(6, math.min(tonumber(entry.Height) or 5, 60)))
            elseif kind == "Slider" then
                SliderCell({
                    Parent = buildFullRow(),
                    Row = entry.Row,
                    Name = entry.Name,
                    Suffix = entry.Suffix,
                    Min = entry.Min,
                    Max = entry.Max,
                    Increment = entry.Increment,
                    Precision = entry.Precision,
                    HasToggle = entry.HasToggle,
                })
            elseif kind == "Dropdown" then
                DropdownCell({
                    Parent = buildFullRow(),
                    Row = entry.Row,
                    Options = entry.Options,
                    Overlay = menu,
                    Fit = fit,
                })
            elseif kind == "TextInput" then
                TextInputCell({
                    Parent = buildFullRow(),
                    Pill = entry.Pill,
                    Hint = entry.Hint,
                    OnArrow = entry.OnArrow,
                })
            end
            prevKind = kind
        end
    end

    local function makeTabButton(title: string): any
        tabCounter += 1
        local api = TabButton({
            Parent = sidebar,
            Title = title,
            Order = 1 + tabCounter,
            OnActivated = function()
                if currentTabTitle ~= title then
                    currentTabTitle = title
                    refreshTabStyles()
                    refreshTabContent()
                end
            end,
        })
        tabApis[title] = api
        return api
    end

    local function buildTabs()
        table.clear(tabOrder)
        table.clear(tabGroups)
        table.clear(tabMeta)
        local noOrderSeq = 0

        local function noteTab(title: string, win: any?)
            if tabGroups[title] == nil then
                tabGroups[title] = {}
                table.insert(tabOrder, title)
            end
            local order = if typeof(win) == "table" then (win :: any)._order else nil
            local meta = tabMeta[title]
            if typeof(order) == "number" then
                local candidate = {
                    hasOrder = true,
                    order = order :: number,
                    subOrder = if typeof((win :: any)._subOrder) == "number"
                        then (win :: any)._subOrder :: number else 0,
                    index = if typeof((win :: any)._index) == "number"
                        then (win :: any)._index :: number else math.huge,
                }
                if meta == nil or meta.hasOrder ~= true
                    or candidate.order < meta.order
                    or (candidate.order == meta.order and candidate.subOrder < meta.subOrder)
                    or (candidate.order == meta.order and candidate.subOrder == meta.subOrder
                        and candidate.index < meta.index)
                then
                    tabMeta[title] = candidate
                end
            elseif meta == nil then
                noOrderSeq += 1
                tabMeta[title] = {
                    hasOrder = false,
                    order = math.huge,
                    subOrder = 0,
                    index = math.huge,
                    seq = noOrderSeq,
                }
            end
        end

        local hacks = UI._keybindHacks
        if typeof(hacks) == "table" then
            for _, entry in hacks do
                if typeof(entry) == "table" then
                    local win = entry.Window
                    local row = entry.Row
                    if typeof(row) == "Instance" and (row :: Instance).Parent ~= nil
                        and typeof(win) == "table"
                        and typeof(win.Root) == "Instance"
                        and (win.Root :: Instance).Parent ~= nil
                        and typeof(win._title) == "string"
                        and (win._title :: string) ~= "GDH Settings"
                        and (win._title :: string) ~= "Search"
                    then
                        local title = win._title :: string
                        noteTab(title, win)
                        table.insert(tabGroups[title], entry)
                    end
                end
            end
        end
        noteTab(searchTabTitle, nil)
        noteTab(replayTabTitle, nil)
        noteTab(settingsTabTitle, nil)

        table.sort(tabOrder, function(a, b)
            local ma = tabMeta[a]
            local mb = tabMeta[b]
            local ha = ma ~= nil and ma.hasOrder == true
            local hb = mb ~= nil and mb.hasOrder == true
            if ha ~= hb then
                return ha
            end
            if ha and hb then
                if ma.order ~= mb.order then
                    return ma.order < mb.order
                end
                if ma.subOrder ~= mb.subOrder then
                    return ma.subOrder < mb.subOrder
                end
                if ma.index ~= mb.index then
                    return ma.index < mb.index
                end
                return a < b
            end
            local sa = if ma ~= nil then ma.seq or math.huge else math.huge
            local sb = if mb ~= nil then mb.seq or math.huge else math.huge
            if sa ~= sb then
                return sa < sb
            end
            return a < b
        end)

        for _, api in tabApis do
            api.Destroy()
        end
        table.clear(tabApis)
        for _, title in tabOrder do
            makeTabButton(title)
        end
        if currentTabTitle == nil or tabGroups[currentTabTitle :: string] == nil then
            currentTabTitle = tabOrder[1]
        end
        refreshTabStyles()
        refreshTabContent()
    end

    local function computeFitScale(): number
        local cam = workspace.CurrentCamera
        local vp = (cam and cam.ViewportSize) or Vector2.new(1280, 720)
        local factor = math.min(vp.X * 0.82 / layout.MenuW, vp.Y * 0.82 / layout.MenuH)
        return math.clamp(factor, 0.25, 2.0)
    end

    local function applyFit()
        fitScaleBase = computeFitScale()
        if not isOpen and not isAnimating then
            fit.Scale = fitScaleBase
        end
        local iconScale = settingsState.IconScale
        if typeof(iconScale) ~= "number" then
            iconScale = 0.5
        end
        local nextIconSize = math.floor(layout.IconBase * math.clamp(fitScaleBase, 0.55, 1.6) * (iconScale / 0.5) + 0.5)
        if overlay ~= nil then
            overlay.SetSize(nextIconSize)
        end
    end
    applyFitRef = applyFit

    local function watchViewport()
        local cam = workspace.CurrentCamera
        if viewportConn ~= nil then
            pcall(function()
                viewportConn:Disconnect()
            end)
            viewportConn = nil
        end
        if cam ~= nil then
            viewportConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyFit)
        end
    end

    local closing = false

    local function openMenu()
        if isOpen or closing then
            return
        end
        isOpen = true
        buildTabs()
        for _, tween in activeTweens do
            pcall(function()
                tween:Cancel()
            end)
        end
        table.clear(activeTweens)
        backdrop.Visible = true
        backdrop.BackgroundTransparency = 1
        menu.Visible = true
        if mobileBadge ~= nil then
            mobileBadge.Visible = true
        end
        isAnimating = true
        fit.Scale = fitScaleBase * 0.5
        local scaleTween = Animate.Tween(fit, 0.8, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, {
            Scale = fitScaleBase,
        })
        local backdropTween = Animate.Tween(backdrop, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
            BackgroundTransparency = 0.45,
        })
        table.insert(activeTweens, scaleTween)
        table.insert(activeTweens, backdropTween)
        scaleTween.Completed:Connect(function(state)
            if state == Enum.PlaybackState.Completed then
                isAnimating = false
            end
        end)
    end

    local function closeMenu()
        if not isOpen or closing then
            return
        end
        isOpen = false
        closing = true
        for _, tween in activeTweens do
            pcall(function()
                tween:Cancel()
            end)
        end
        table.clear(activeTweens)

        menu.Visible = false
        backdrop.Visible = false
        backdrop.BackgroundTransparency = 1
        fit.Scale = fitScaleBase * 0.5
        if mobileBadge ~= nil then
            mobileBadge.Visible = false
        end
        isAnimating = false
        closing = false
    end

    toggleMenu = function()
        if isOpen then
            closeMenu()
        else
            openMenu()
        end
    end
    genv.GDH_MOBILE_TOGGLE = toggleMenu

    local originalNotify: any = UI.Notify
    if typeof(originalNotify) == "function" then
        UI.Notify = function(self: any, text: any, duration: number?)
            if isOpen then
                InfoPopup.Show(root, "Info", tostring(text), fit.Scale)
            else
                originalNotify(self, text, duration)
            end
        end
    else
        originalNotify = nil
    end

    local function mobileKill()
        for _, conn in connections do
            pcall(function()
                conn:Disconnect()
            end)
        end
        table.clear(connections)
        if viewportConn ~= nil then
            pcall(function()
                viewportConn:Disconnect()
            end)
            viewportConn = nil
        end
        if overlay ~= nil then
            overlay.Destroy()
        end
        pcall(function()
            screenGui:Destroy()
        end)
        if originalNotify ~= nil then
            UI.Notify = originalNotify
        end
        if genv.GDH_MOBILE_KILL == mobileKill then
            genv.GDH_MOBILE_KILL = nil
        end
        if genv.GDH_MOBILE_TOGGLE == toggleMenu then
            genv.GDH_MOBILE_TOGGLE = nil
        end
        genv.GDH_MOBILE_UI = nil
    end
    genv.GDH_MOBILE_KILL = mobileKill
    genv.GDH_MOBILE_UI = screenGui

    local pcGui = UI._screenGui
    if typeof(pcGui) == "Instance" then
        table.insert(connections, (pcGui :: Instance).Destroying:Connect(function()
            mobileKill()
        end))
    end

    local parent: Instance? = nil
    if typeof(pcGui) == "Instance" and (pcGui :: Instance).Parent ~= nil then
        parent = (pcGui :: Instance).Parent
    end
    if parent == nil then
        local okCore, coreGui = pcall(function()
            return game:GetService("CoreGui")
        end)
        if okCore and coreGui ~= nil then
            local okFolder, folder = pcall(function()
                local found: Instance? = nil
                for _, child in coreGui:GetChildren() do
                    if child:IsA("Folder") and child:GetAttribute("GDHUI") == true then
                        found = child
                        break
                    end
                end
                if found == nil then
                    local okGuid, guid = pcall(function()
                        return game:GetService("HttpService"):GenerateGUID(false)
                    end)
                    local suffix = if okGuid and typeof(guid) == "string"
                        then guid:gsub("-", "")
                        else tostring(math.random(1, 0x7fffffff))
                    found = Instance.new("Folder")
                    found.Name = "__ui_" .. suffix
                    found:SetAttribute("GDHUI", true)
                    found.Parent = coreGui
                end
                return found
            end)
            if okFolder and folder ~= nil then
                parent = folder
            end
        end
    end
    if parent == nil then
        local player = Players.LocalPlayer
        if player ~= nil then
            parent = player:FindFirstChildOfClass("PlayerGui")
            if parent == nil then
                parent = player:WaitForChild("PlayerGui", 10)
            end
        end
    end
    if parent ~= nil then
        screenGui.Parent = parent
        Keyboard.Protect(screenGui)
    end

    table.insert(connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchViewport))
    watchViewport()
    applyFit()

    task.defer(function()
        local size = root.AbsoluteSize
        if overlay == nil or size.X <= 0 or size.Y <= 0 then
            return
        end
        local margin = overlay.GetSize() * 0.5 + 14
        overlay.SetCenter(Vector2.new(margin, size.Y - margin))
    end)
end
