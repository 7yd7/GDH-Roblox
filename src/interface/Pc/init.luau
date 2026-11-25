local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

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
    return require(script.Parent[name])
end

local Theme = importPcModule("Theme")
local Animate = importPcModule("Animate")
local Window = importPcModule("Window")
local Widget = importPcModule("Widget")

local function importFunctionModule(name: string): any
    local genv = (typeof(getgenv) == "function" and getgenv())
        or (typeof(_G) == "table" and _G)
        or {}
    local Import = genv.Import
    if Import then
        local module = Import("Function/" .. name)
        if module ~= nil then
            return module
        end
    end
    return require(script.Parent.Parent.Parent["Function"][name])
end

local Save = importFunctionModule("Save")
local Keyboard = importFunctionModule("Keyboard")

local AUTO_PADDING_X = 10
local AUTO_PADDING_Y = 10
local AUTO_SPACING_Y = 10

local function parseOrder(value: number | string?): (number?, number)
    if typeof(value) == "number" then
        return value, 0
    end
    if typeof(value) ~= "string" then
        return nil, 0
    end
    local baseText, subText = string.match(value, "^%s*(%d+%.?%d*)%s*%-%s*(%d+)%s*$")
    if baseText ~= nil then
        return tonumber(baseText), tonumber(subText) or 0
    end
    return tonumber(string.match(value, "^%s*(%d+%.?%d*)%s*$") or ""), 0
end

local GDH_UI = {}
GDH_UI.__index = GDH_UI

GDH_UI.Theme = Theme
GDH_UI.Animate = Animate
GDH_UI.Window = Window
GDH_UI.Widget = Widget

export type LibConfig = {
    Title: string?,
    ToggleKey: Enum.KeyCode?,
    Parent: Instance?,
}

function GDH_UI.CreateLib(config: LibConfig?)
    config = config or {}

    Theme.ApplyScreenScale()

    local lib = setmetatable({}, GDH_UI)
    lib._windows = {}
    lib._keybindHacks = {}
    lib._visible = false
    lib._fadeProgress = 0.0
    lib._targetProgress = 0.0
    lib._fadeTweenId = nil
    lib._fadeTargets = nil
    lib._isAnimating = false
    lib._isFadingIn = false
    lib._connections = {}
    lib._autoSeq = 0
    lib._horizontalCenter = false
    lib._toggleKey = config.ToggleKey or Enum.KeyCode.G

    local genv = (typeof(getgenv) == "function" and getgenv())
        or (typeof(_G) == "table" and _G)
        or {}

    genv.GDH_MODAL_OPEN = 0

    if genv.Import and genv.Import.Asset then
        Theme.InitFont(genv.Import.Asset)
    end

    local function runtimeFolderName(): string
        local ok, guid = pcall(function()
            return game:GetService("HttpService"):GenerateGUID(false)
        end)
        local suffix = if ok and typeof(guid) == "string" then guid:gsub("-", "") else tostring(math.random(1, 0x7fffffff))
        return "__ui_" .. suffix
    end

    local function createRuntimeFolder(container: Instance): Folder
        local folder = Instance.new("Folder")
        folder.Name = runtimeFolderName()
        folder:SetAttribute("GDHUI", true)
        folder.Parent = container
        return folder
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = config.Title or "GDH"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 999
    screenGui.Enabled = false
    screenGui:SetAttribute("GDHUI", true)

    local parent = config.Parent
    if not parent then
        local player = game:GetService("Players").LocalPlayer
        if player then
            local playerGui = player:FindFirstChildOfClass("PlayerGui")
                or player:WaitForChild("PlayerGui", 10)
            if playerGui ~= nil then
                local ok, folder = pcall(createRuntimeFolder, playerGui)
                if ok and folder ~= nil then
                    parent = folder
                else
                    parent = playerGui
                end
            end
        end
    end
    if not parent then
        local okCore, coreGui = pcall(function()
            return game:GetService("CoreGui")
        end)
        if okCore and coreGui ~= nil then
            local okFolder, folder = pcall(createRuntimeFolder, coreGui)
            if okFolder and folder ~= nil then
                parent = folder
            end
        end
    end
    screenGui.Parent = parent
    lib._screenGui = screenGui
    genv.GDH_PC_SCREEN_GUI = screenGui
    genv.GDH_GUI_FOLDER = parent
    Keyboard.Protect(screenGui)

    local versionStr = "v1.0"
    local infoJson = genv.GDH_PACKAGE and genv.GDH_PACKAGE["src/info.json"]
    if typeof(infoJson) == "string" and infoJson ~= "" then
        local okDecode, decoded = pcall(function()
            return game:GetService("HttpService"):JSONDecode(infoJson)
        end)
        if okDecode and typeof(decoded) == "table"
            and typeof(decoded.version) == "string"
            and decoded.version ~= ""
        then
            versionStr = decoded.version
        end
    end

    local badge = Instance.new("Frame")
    badge.Name = "VersionBadge"
    badge.BackgroundTransparency = 1
    badge.AnchorPoint = Vector2.new(1, 1)
    badge.Position = UDim2.new(1, -10, 1, -10)
    badge.Size = UDim2.fromOffset(246, 52)
    badge.Parent = screenGui

    local rect10 = Instance.new("Frame")
    rect10.Name = "Rectangle 10"
    rect10.Active = true
    rect10.BorderSizePixel = 0
    rect10.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    rect10.Size = UDim2.fromOffset(246, 52)
    rect10.BackgroundTransparency = 0.5
    rect10.Parent = badge
    local rect10Corner = Instance.new("UICorner")
    rect10Corner.CornerRadius = UDim.new(0, 25)
    rect10Corner.Parent = rect10

    local rect11 = Instance.new("Frame")
    rect11.Name = "Rectangle 11"
    rect11.Active = true
    rect11.BorderSizePixel = 0
    rect11.BackgroundColor3 = Color3.fromRGB(194, 178, 225)
    rect11.Size = UDim2.fromOffset(73, 38)
    rect11.Position = UDim2.fromOffset(10, 7)
    rect11.Parent = badge
    local rect11Corner = Instance.new("UICorner")
    rect11Corner.CornerRadius = UDim.new(0, 25)
    rect11Corner.Parent = rect11

    local gdhText = Instance.new("TextLabel")
    gdhText.Name = "GDH"
    gdhText.TextWrapped = true
    gdhText.Active = true
    gdhText.BorderSizePixel = 0
    gdhText.TextSize = 34
    gdhText.FontFace = Theme.GetFontFace()
    gdhText.TextColor3 = Color3.fromRGB(54, 52, 96)
    gdhText.BackgroundTransparency = 1
    gdhText.Size = UDim2.new(1, 0, 1, -3)
    gdhText.Text = "GDH"
    gdhText.Position = UDim2.new(0, 0, 0, 0)
    gdhText.Parent = rect11

    local releaseText = Instance.new("TextLabel")
    releaseText.Name = "Release"
    releaseText.TextWrapped = false
    releaseText.Active = true
    releaseText.BorderSizePixel = 0
    releaseText.TextSize = 33
    releaseText.TextXAlignment = Enum.TextXAlignment.Left
    releaseText.FontFace = Theme.GetFontFace()
    releaseText.TextColor3 = Color3.fromRGB(181, 168, 209)
    releaseText.BackgroundTransparency = 1
    releaseText.Size = UDim2.fromOffset(154, 38)
    releaseText.Text = versionStr
    releaseText.Position = UDim2.new(0, 92, 0, 5)
    releaseText.Parent = badge

    local function layoutBadge()
        if badge.Parent == nil then
            return
        end
        local gdhWidth = math.clamp(math.ceil(gdhText.TextBounds.X) + 8, 73, 82)
        rect11.Size = UDim2.fromOffset(gdhWidth, 38)
        releaseText.Size = UDim2.fromOffset(4096, 38)
        local releaseWidth = math.max(1, math.ceil(releaseText.TextBounds.X))
        local badgeWidth = math.max(100, 92 + releaseWidth + 10)
        releaseText.Size = UDim2.fromOffset(releaseWidth, 38)
        badge.Size = UDim2.fromOffset(badgeWidth, 52)
        rect10.Size = UDim2.fromOffset(badgeWidth, 52)
    end

    lib._badge = badge
    lib._badgeReflow = layoutBadge
    layoutBadge()
    task.defer(layoutBadge)

    local noticeGui = Instance.new("ScreenGui")
    noticeGui.Name = "GDH Notices"
    noticeGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    noticeGui.ResetOnSpawn = false
    noticeGui.DisplayOrder = 1000
    noticeGui.Parent = parent

    local noticeHost = Instance.new("Frame")
    noticeHost.Name = "Notices"
    noticeHost.AnchorPoint = Vector2.new(1, 1)
    noticeHost.AutomaticSize = Enum.AutomaticSize.Y
    noticeHost.BackgroundTransparency = 1
    noticeHost.BorderSizePixel = 0
    noticeHost.Position = UDim2.new(1, -18, 1, -18)
    noticeHost.Size = UDim2.fromOffset(245, 0)
    noticeHost.ZIndex = 100000
    noticeHost.Parent = noticeGui

    local noticeList = Instance.new("UIListLayout")
    noticeList.FillDirection = Enum.FillDirection.Vertical
    noticeList.SortOrder = Enum.SortOrder.LayoutOrder
    noticeList.Padding = UDim.new(0, 8)
    noticeList.VerticalAlignment = Enum.VerticalAlignment.Bottom
    noticeList.Parent = noticeHost

    lib._notices = {}
    lib._noticeConns = {}
    lib._noticeHost = noticeHost
    lib._noticeGui = noticeGui

    local toggleConn = UserInputService.InputBegan:Connect(function(input)
        if Keyboard.IsTyping() then
            return
        end
        if input.KeyCode == lib._toggleKey then
            if typeof(genv.GDH_MODAL_OPEN) == "number" and (genv.GDH_MODAL_OPEN :: number) > 0 then
                return
            end
            lib:Toggle()
        end
    end)
    table.insert(lib._connections, toggleConn)

    local cursorState = {
        forced = false,
        iconEnabled = nil,
    }

    local function readMouseProp(getter: () -> any): any
        local ok, value = pcall(getter)
        if ok then
            return value
        end
        return nil
    end

    local function isCameraLooking(): boolean
        local pressed = readMouseProp(function()
            return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        end)
        return pressed == true
    end

    local function forceCursor(allowBehavior: boolean)
        if not cursorState.forced then
            cursorState.iconEnabled = readMouseProp(function()
                return UserInputService.MouseIconEnabled
            end)
            cursorState.forced = true
        end

        local icon = readMouseProp(function()
            return UserInputService.MouseIconEnabled
        end)
        if icon ~= true then
            pcall(function()
                UserInputService.MouseIconEnabled = true
            end)
        end

        if allowBehavior then
            local behavior = readMouseProp(function()
                return UserInputService.MouseBehavior
            end)
            if behavior ~= Enum.MouseBehavior.Default then
                pcall(function()
                    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                end)
            end
        end
    end

    local function releaseCursor()
        if not cursorState.forced then
            return
        end
        cursorState.forced = false
        local icon = cursorState.iconEnabled
        cursorState.iconEnabled = nil

        pcall(function()
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end)

        if icon ~= nil and icon ~= true then
            pcall(function()
                UserInputService.MouseIconEnabled = icon
            end)
        end
    end

    local cursorConn = RunService.RenderStepped:Connect(function()
        if lib._visible and lib._screenGui.Enabled then
            forceCursor(not isCameraLooking())
        else
            releaseCursor()
        end
    end)
    table.insert(lib._connections, cursorConn)

    lib._forceCursor = forceCursor
    lib._releaseCursor = releaseCursor

    return lib
end

local function collectFadeTargets(self)
    local targets = {}
    local function addInstance(root: Instance)
        for _, desc in root:GetDescendants() do
            if desc:IsA("UIStroke") then
                local baseStroke = desc:GetAttribute("_baseStroke")
                if baseStroke == nil then
                    baseStroke = desc.Transparency
                    desc:SetAttribute("_baseStroke", baseStroke)
                end
                table.insert(targets, {
                    kind = 1,
                    obj = desc,
                    base = baseStroke,
                })
            elseif desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
                local baseBG = desc:GetAttribute("_baseBG")
                if baseBG == nil then
                    baseBG = desc.BackgroundTransparency
                    desc:SetAttribute("_baseBG", baseBG)
                end
                local baseText = desc:GetAttribute("_baseText")
                if baseText == nil then
                    baseText = desc.TextTransparency
                    desc:SetAttribute("_baseText", baseText)
                end
                table.insert(targets, {
                    kind = 2,
                    obj = desc,
                    baseBG = if baseBG < 0.999 then baseBG else nil,
                    baseText = baseText,
                })
            elseif desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
                local baseBG = desc:GetAttribute("_baseBG")
                if baseBG == nil then
                    baseBG = desc.BackgroundTransparency
                    desc:SetAttribute("_baseBG", baseBG)
                end
                local baseImage = desc:GetAttribute("_baseImage")
                if baseImage == nil then
                    baseImage = desc.ImageTransparency
                    desc:SetAttribute("_baseImage", baseImage)
                end
                table.insert(targets, {
                    kind = 3,
                    obj = desc,
                    baseBG = if baseBG < 0.999 then baseBG else nil,
                    baseImage = baseImage,
                })
            elseif desc:IsA("GuiObject") then
                local baseBG = desc:GetAttribute("_baseBG")
                if baseBG == nil then
                    baseBG = desc.BackgroundTransparency
                    desc:SetAttribute("_baseBG", baseBG)
                end
                if baseBG < 0.999 then
                    table.insert(targets, {
                        kind = 4,
                        obj = desc,
                        baseBG = baseBG,
                    })
                end
            end
        end
    end

    for _, win in self._windows do
        if win and win.Root then
            addInstance(win.Root)
        end
    end
    if self._badge then
        addInstance(self._badge)
    end
    return targets
end

local function applyFadeProgress(targets, p: number)
    local invP = 1 - p
    for i = 1, #targets do
        local item = targets[i]
        local obj = item.obj
        if obj.Parent ~= nil then
            local kind = item.kind
            if kind == 1 then
                obj.Transparency = item.base + (1 - item.base) * invP
            elseif kind == 2 then
                if item.baseBG ~= nil then
                    obj.BackgroundTransparency = item.baseBG + (1 - item.baseBG) * invP
                end
                obj.TextTransparency = item.baseText + (1 - item.baseText) * invP
            elseif kind == 3 then
                if item.baseBG ~= nil then
                    obj.BackgroundTransparency = item.baseBG + (1 - item.baseBG) * invP
                end
                obj.ImageTransparency = item.baseImage + (1 - item.baseImage) * invP
            elseif kind == 4 then
                obj.BackgroundTransparency = item.baseBG + (1 - item.baseBG) * invP
            end
        end
    end
end

function GDH_UI:Toggle()
    local targetProgress = if self._targetProgress == 1 then 0 else 1
    self._targetProgress = targetProgress
    if targetProgress == 1 then
        Keyboard.ReleaseTraps()
    end

    if self._fadeTweenId ~= nil then
        Animate.CancelTween(self._fadeTweenId)
        self._fadeTweenId = nil
    end

    local startProgress = self._fadeProgress or (if targetProgress == 0 then 1 else 0)

    if self._fadeTargets == nil then
        self._fadeTargets = collectFadeTargets(self)
    end
    local targets = self._fadeTargets

    if targetProgress == 1 and startProgress < 0.001 then
        applyFadeProgress(targets, startProgress)
    end

    local distance = math.abs(targetProgress - startProgress)
    if distance < 0.001 then
        self._fadeProgress = targetProgress
        self._isAnimating = false
        self._fadeTargets = nil
        if targetProgress == 0 then
            self._screenGui.Enabled = false
            self._visible = false
            self._releaseCursor()
        else
            self._screenGui.Enabled = true
            self._visible = true
            self._forceCursor(true)
        end
        return
    end

    self._isAnimating = true

    if targetProgress == 1 then
        self._screenGui.Enabled = true
        self._visible = true
        for _, win in self._windows do
            if win._popup then
                win:SetVisible(false)
            else
                win:SetVisible(true)
            end
        end
    else
        self._visible = false
        Widget.CloseAllDropdowns()
    end

    local baseDuration = Theme.Animation.UIToggleDuration or 0.12
    local duration = math.clamp(baseDuration * distance, 0.02, baseDuration)

    self._fadeTweenId = Animate.Tween({
        Duration = duration,
        EasingFunction = Animate.Easing.EaseOutQuad,
        OnStep = function(t)
            local currentP = startProgress + (targetProgress - startProgress) * t
            self._fadeProgress = currentP
            applyFadeProgress(targets, currentP)
        end,
        OnComplete = function()
            self._fadeTweenId = nil
            self._fadeProgress = targetProgress
            self._isAnimating = false
            self._fadeTargets = nil

            applyFadeProgress(targets, targetProgress)

            if targetProgress == 0 then
                self._screenGui.Enabled = false
                self._visible = false
                self._releaseCursor()
            else
                self._screenGui.Enabled = true
                self._visible = true

                local genv = (typeof(getgenv) == "function" and getgenv())
                    or (typeof(_G) == "table" and _G)
                    or {}
                local rApis = genv.GDH_RadioButtonApis
                if typeof(rApis) == "table" then
                    for _, api in rApis do
                        if typeof(api) == "table" and typeof(api.Refresh) == "function" then
                            api.Refresh()
                        end
                    end
                end
            end
        end,
    })
end

function GDH_UI:Show()
    if self._targetProgress ~= 1 then
        self:Toggle()
    end
end

function GDH_UI:Hide()
    if self._targetProgress ~= 0 then
        self:Toggle()
    end
end

export type CreateWindowConfig = {
    Title: string,
    Position: UDim2?,

    Order: (number | string)?,
    Row: number?,
    Size: UDim2?,
    MinSize: Vector2?,
    AutoHeight: boolean?,
    Visible: boolean?,
    Searchable: boolean?,
    Keybindable: boolean?,

    Popup: boolean?,
    FitWidth: boolean?,
    ZIndex: number?,
    HideCloseButton: boolean?,
}

function GDH_UI:CreateWindow(config: CreateWindowConfig)
    local ownerUI = self
    local win = Window.new({
        Title = config.Title,
        Position = config.Position,
        Size = config.Size,
        MinSize = config.MinSize,
        AutoHeight = config.AutoHeight,
        Visible = if config.Visible ~= nil then config.Visible else true,
        Popup = config.Popup,
        FitWidth = config.FitWidth,
        ZIndex = config.ZIndex,
        HideCloseButton = config.HideCloseButton,
        Parent = self._screenGui,
    })

    table.insert(self._windows, win)
    self._fadeTargets = nil

    local scopeGenv = (typeof(getgenv) == "function" and getgenv())
        or (typeof(_G) == "table" and _G)
        or {}
    local windowScope = scopeGenv.GDH_SCRIPT_SCOPE
    if windowScope ~= "Global" and windowScope ~= "Map" then
        windowScope = "Global"
    end
    win._scope = windowScope

    if config.Searchable == false then
        win.Root:SetAttribute("GDHSearchExclude", true)
    end

    if config.Keybindable == false then
        win.Root:SetAttribute("GDHKeybindExclude", true)
    end

    if config.Position == nil and config.Popup ~= true then
        win._isAuto = true
        ownerUI._autoSeq += 1
        win._order, win._subOrder = parseOrder(config.Order)
        win._row = config.Row
        win._index = ownerUI._autoSeq
        task.defer(function()
            ownerUI:RefreshAutoLayout()
        end)
    end

    local builder = {}
    builder._window = win
    builder._screenGui = self._screenGui
    builder._layoutOrder = 0

    local windowTitle = tostring(win._title or "Window")
    local radioEntries: { any } = {}

    local function isKeybindsWindow(): boolean
        return win._title == "Keybinds"
    end

    local function widgetSaveKey(prefix: string?, fallback: string): string?
        if isKeybindsWindow() then
            return nil
        end
        if typeof(prefix) == "string" and prefix ~= "" then
            return windowTitle .. "::" .. prefix
        end
        return windowTitle .. "::" .. fallback .. tostring(builder._layoutOrder)
    end

    local function scheduleRadioRestore(saveKey: string?, rb: Instance)
        if saveKey == nil or Save == nil then
            return
        end
        local restoreKey = saveKey :: string
        local restoreRow = rb :: Instance
        task.defer(function()
            if Save.RadioActive(restoreKey, windowScope) ~= true then
                return
            end
            local apis = genv.GDH_RadioButtonApis
            local api = if typeof(apis) == "table" then apis[restoreRow] else nil
            if api ~= nil then
                api.SetActive(true)
            end
        end)
    end

    local function wireRadioSave(cfg: any): string?
        local nameStr = cfg and cfg.Name or nil
        local groupStr = tostring(cfg and cfg.Group or "")
        local saveKey = widgetSaveKey(nameStr, "Radio")
        if saveKey == nil or Save == nil then
            return nil
        end
        local persistKey = saveKey :: string
        table.insert(radioEntries, { Key = persistKey, Group = groupStr })
        local userCallback: any = cfg.Callback
        cfg.Callback = function(state: boolean)
            if state == true then
                Save.SetRadio(persistKey, true, windowScope)
                for _, other in radioEntries do
                    if other.Group == groupStr and other.Key ~= persistKey then
                        Save.SetRadio(other.Key, false, windowScope)
                    end
                end
            end
            if userCallback ~= nil then
                userCallback(state)
            end
        end
        return persistKey
    end

    builder.Root = win.Root
    function builder:Show()
        self._window:Show()
    end
    function builder:Hide()
        self._window:Hide()
    end
    function builder:IsVisible(): boolean
        return self._window.Root.Visible
    end
    function builder:ShowAt(anchor: Vector2, offset: Vector2?)
        self._window:ShowAt(anchor, offset)
    end
    function builder:FitContentWidth()
        self._window:FitPopupWidth()
    end
    function builder:SetOutsideIgnore(instance: Instance?)
        self._window:SetOutsideIgnore(instance)
    end

    function builder:_nextOrder(): number
        self._layoutOrder += 1
        return self._layoutOrder
    end

    local function registerMobileRow(kind: string, row: Instance, extra: { [string]: any }?)
        local win = builder._window
        if win._title == "Keybinds" then
            return
        end
        if typeof(row) ~= "Instance" or (row :: Instance).Parent == nil then
            return
        end
        local entry: { [string]: any } = {
            Kind = kind,
            Window = win,
            Row = row,
        }
        if extra ~= nil then
            for key, value in extra do
                entry[key] = value
            end
        end
        if win._popup == true then
            local list = win._mobileRows
            if typeof(list) ~= "table" then
                list = {}
                win._mobileRows = list
            end
            table.insert(list :: { any }, entry)
            return
        end
        table.insert(ownerUI._keybindHacks, entry)
    end

    local function measureSettingText(text: string, size: number): number
        local ok, bounds = pcall(function()
            return TextService:GetTextBoundsAsync(
                text,
                Theme.GetFontFace(),
                size,
                Vector2.new(10000, size * 2))
        end)
        if ok and bounds then
            return math.ceil(bounds.X)
        end
        return #text * math.floor(size * 0.58 + 0.5)
    end

    function builder:_buildSettingsPopup(row: Instance, name: string?, defs: { any })
        local hackName = tostring(name or "")
        if hackName == "" then
            return
        end
        local lowerName = string.lower(hackName)

        local genv = (typeof(getgenv) == "function" and getgenv())
            or (typeof(_G) == "table" and _G)
            or {}

        local stateStore = genv.GDH_HACK_SETTINGS_STATE
        if typeof(stateStore) ~= "table" then
            stateStore = {}
            genv.GDH_HACK_SETTINGS_STATE = stateStore
        end
        local hackState = (stateStore :: { any })[lowerName]
        if typeof(hackState) ~= "table" then
            hackState = {}
            (stateStore :: { any })[lowerName] = hackState
        end
        local state = hackState :: { any }

        for _, def in defs do
            if typeof(def) == "table" and typeof(def.Key) == "string"
                and state[def.Key] == nil
            then
                local defaultValue = def.Default
                if defaultValue == nil then
                    defaultValue = if tostring(def.Kind or "Toggle") == "Toggle" then false else 0
                end
                state[def.Key] = defaultValue
            end
        end

        local rowsHeight = 0
        for _, def in defs do
            if typeof(def) == "table" then
                local defKind = tostring(def.Kind or "Toggle")
                if defKind == "Separator" then
                    rowsHeight += 10
                elseif defKind == "Label" then
                    rowsHeight += 20
                else
                    rowsHeight += 26
                end
            end
        end
        local screenScale = Theme.ScreenScale or 1
        local bodyFont = Theme.Font.Body
        local maxContentWidth = 0
        for _, def in defs do
            if typeof(def) == "table" then
                local defKind = tostring(def.Kind or "Toggle")
                if defKind ~= "Separator" then
                    local text = tostring(def.Text or def.Key or "")
                    if text ~= "" then
                        local rowWidth = measureSettingText(text, bodyFont)
                        if defKind == "Toggle" or def.Toggle == true then
                            rowWidth += Theme.Layout.ToggleWidth + (Theme.Layout.InlineGapX or 8)
                        end
                        if defKind == "Int" or defKind == "Float" or defKind == "Color" then
                            rowWidth += 24
                        end
                        if rowWidth > maxContentWidth then
                            maxContentWidth = rowWidth
                        end
                    end
                end
            end
        end
        local popupWidth = math.clamp(
            math.ceil(maxContentWidth + Theme.Layout.ListPaddingX * 2 + 12),
            Theme.Layout.WindowMinWidth,
            math.floor(560 * screenScale + 0.5))
        local popupHeight = math.floor((58 + rowsHeight) * screenScale + 0.5)
        popupHeight = math.clamp(popupHeight, 160, 560)

        local popupWin = ownerUI:CreateWindow({
            Title = hackName .. " Settings",
            Popup = true,
            Visible = false,
            Size = UDim2.fromOffset(popupWidth, popupHeight),
            FitWidth = true,
        })

        local colorApis = genv.GDH_SETTING_ROW_APIS
        if typeof(colorApis) ~= "table" then
            colorApis = setmetatable({}, { __mode = "k" })
            genv.GDH_SETTING_ROW_APIS = colorApis
        end
        local apis = colorApis :: { [Instance]: any }

        local colorNames = { "White", "Red", "Green", "Blue", "Yellow" }
        local colorPalette = {
            Color3.fromRGB(255, 255, 255),
            Color3.fromRGB(225, 115, 121),
            Color3.fromRGB(120, 220, 130),
            Color3.fromRGB(120, 180, 255),
            Color3.fromRGB(255, 220, 100),
        }
        local function colorIndexOf(color: any): number
            for i = 1, #colorPalette do
                if colorPalette[i] == color then
                    return i
                end
            end
            return 0
        end
        local function colorHex(color: Color3): string
            return string.format("#%02X%02X%02X",
                math.floor(color.R * 255 + 0.5),
                math.floor(color.G * 255 + 0.5),
                math.floor(color.B * 255 + 0.5))
        end

        for _, def in defs do
            if typeof(def) ~= "table" then
                continue
            end
            local kind = tostring(def.Kind or "Toggle")
            local key = tostring(def.Key or "")
            local text = tostring(def.Text or key)

            if kind == "Separator" then
                popupWin:AddSeparator()
            elseif kind == "Label" then
                if text ~= "" then
                    popupWin:AddLabel({ Text = text })
                end
            elseif kind == "Toggle" then
                local toggleRow = popupWin:AddToggle({
                    Name = text,
                    Default = state[key] == true,
                    Callback = function(newState: boolean)
                        state[key] = newState
                    end,
                })
                toggleRow:SetAttribute("GDHSettingKind", "Toggle")
                toggleRow:SetAttribute("GDHSettingKey", key)
                toggleRow:SetAttribute("GDHSettingText", text)
            elseif kind == "Int" or kind == "Float" then
                local isFloat = kind == "Float"
                local minValue = if typeof(def.Min) == "number" then def.Min :: number else 0
                local maxValue = if typeof(def.Max) == "number"
                    then def.Max :: number
                    else (if isFloat then 1 else 9999)
                local startValue = tonumber(state[key])
                if startValue == nil then
                    startValue = if typeof(def.Default) == "number" then def.Default :: number else minValue
                    state[key] = startValue
                end

                local sliderRow: Instance? = nil
                local toggleKey = key .. "_toggle"
                if state[toggleKey] == nil then
                    state[toggleKey] = if typeof(def.ToggleDefault) == "boolean"
                        then def.ToggleDefault :: boolean
                        else true
                end
                local function applyValue(value: number)
                    state[key] = value
                    local node = sliderRow
                    if typeof(node) == "Instance" then
                        (node :: Instance):SetAttribute("GDHSettingValue", value)
                    end
                end

                sliderRow = popupWin:AddSlider({
                    Name = text,
                    Min = minValue,
                    Max = maxValue,
                    Default = startValue,
                    Increment = if typeof(def.Increment) == "number" then def.Increment :: number
                        else (if isFloat then 0.05 else 1),
                    Precision = if typeof(def.Precision) == "number" then def.Precision :: number
                        else (if isFloat then 2 else 0),
                    Suffix = if typeof(def.Suffix) == "string" then def.Suffix :: string else "",
                    Toggle = def.Toggle == true,
                    ToggleDefault = state[toggleKey] == true,
                    ToggleCallback = function(enabled: boolean)
                        state[toggleKey] = enabled
                    end,
                    Callback = function(value: number)
                        applyValue(value)
                    end,
                })

                local sliderNode = sliderRow :: Instance
                sliderNode:SetAttribute("GDHSettingKind", kind)
                sliderNode:SetAttribute("GDHSettingKey", key)
                sliderNode:SetAttribute("GDHSettingText", text)
                if def.Toggle == true then
                    sliderNode:SetAttribute("GDHSettingToggleKey", toggleKey)
                end
                if typeof(def.Min) == "number" then
                    sliderNode:SetAttribute("GDHSettingMin", def.Min :: number)
                end
                if typeof(def.Max) == "number" then
                    sliderNode:SetAttribute("GDHSettingMax", def.Max :: number)
                end
            elseif kind == "Color" then
                local startColor = state[key]
                if typeof(startColor) ~= "Color3" then
                    startColor = if typeof(def.Default) == "Color3"
                        then def.Default :: Color3
                        else Color3.fromRGB(255, 0, 0)
                    state[key] = startColor
                end

                local colorRow: TextButton? = nil
                local colorPersistKey = windowTitle .. "::" .. key .. "::Color"
                local function applyColor(color: Color3)
                    state[key] = color
                    local index = colorIndexOf(color)
                    local colorName = if index > 0 then colorNames[index] else colorHex(color)
                    local node = colorRow
                    if typeof(node) == "Instance" then
                        local nodeButton = node :: TextButton
                        nodeButton.Text = text .. ": " .. colorName
                        nodeButton:SetAttribute("GDHSettingValue", color)
                    end
                    if Save ~= nil then
                        Save.SetText(colorPersistKey, colorHex(color), windowScope)
                    end
                end

                local startName = if colorIndexOf(startColor) > 0
                    then colorNames[colorIndexOf(startColor)]
                    else colorHex(startColor :: Color3)
                colorRow = popupWin:AddButton({
                    Text = text .. ": " .. startName,
                    Callback = function()
                        local nextIndex = colorIndexOf(state[key]) + 1
                        if nextIndex == 1 or nextIndex > #colorPalette then
                            nextIndex = 2
                        end
                        applyColor(colorPalette[nextIndex])
                    end,
                })

                local colorNode = colorRow :: Instance
                apis[colorNode] = {
                    Get = function(): Color3
                        local value = state[key]
                        if typeof(value) == "Color3" then
                            return value
                        end
                        return startColor :: Color3
                    end,
                    Set = function(color: Color3)
                        applyColor(color)
                    end,
                }
                colorNode:SetAttribute("GDHSettingKind", "Color")
                colorNode:SetAttribute("GDHSettingKey", key)
                colorNode:SetAttribute("GDHSettingText", text)
                if Save ~= nil then
                    local restoreNode = colorNode :: Instance
                    task.defer(function()
                        local savedHex = Save.TextValue(colorPersistKey, windowScope)
                        if typeof(savedHex) ~= "string" or savedHex == "" then
                            return
                        end
                        local hex = string.gsub(savedHex, "^#", "")
                        local okColor, savedColor = pcall(function()
                            return Color3.fromHex(hex)
                        end)
                        if not okColor or typeof(savedColor) ~= "Color3" then
                            return
                        end
                        local settingApis = genv.GDH_SETTING_ROW_APIS
                        local nodeApi = if typeof(settingApis) == "table"
                            then (settingApis :: { [Instance]: any })[restoreNode]
                            else nil
                        if typeof(nodeApi) == "table" and typeof(nodeApi.Set) == "function" then
                            nodeApi.Set(savedColor :: Color3)
                        end
                    end)
                end
            end
        end

        self:AttachShowButton(row, popupWin)
    end

    function builder:AddToggle(cfg: Widget.ToggleConfig): Frame
        cfg.LayoutOrder = self:_nextOrder()
        local nameStr = cfg and cfg.Name or nil
        local saveKey = widgetSaveKey(nameStr, "Toggle")
        local isHack = typeof(nameStr) == "string"
            and (nameStr :: string) ~= ""
            and self._window._popup ~= true
            and not isKeybindsWindow()
        local userCallback: any = cfg.Callback
        if saveKey ~= nil and Save ~= nil then
            local persistKey = saveKey :: string
            cfg.Callback = function(state: boolean)
                Save.SetToggle(persistKey, state, windowScope)
                if userCallback ~= nil then
                    userCallback(state)
                end
            end
        end
        local toggle = Widget.Toggle(cfg)
        toggle.Parent = self._window:GetContentFrame()
        if saveKey ~= nil and Save ~= nil then
            local restoreKey = saveKey :: string
            local restoreRow = toggle :: Instance
            task.defer(function()
                local saved = Save.ToggleState(restoreKey, windowScope)
                if saved ~= nil then
                    local apis = genv.GDH_ToggleRowApis
                    local api = if typeof(apis) == "table" then apis[restoreRow] else nil
                    if api ~= nil and api.GetState() ~= saved then
                        api.SetState(saved)
                    end
                end
                if isHack then
                    local resolve = genv.GDH_KeybindBindsResolve
                    if typeof(resolve) == "function" then
                        resolve()
                    end
                end
            end)
        end
        if isHack then
            table.insert(ownerUI._keybindHacks, {
                Kind = "Toggle",
                Window = self._window,
                Row = toggle,
                Name = nameStr :: string,
                Id = saveKey :: string,
                Description = cfg and cfg.Description,
            })
        elseif self._window._popup == true and typeof(toggle) == "Instance" then
            local popupList = self._window._mobileRows
            if typeof(popupList) ~= "table" then
                popupList = {}
                self._window._mobileRows = popupList
            end
            table.insert(popupList :: { any }, {
                Kind = "Toggle",
                Window = self._window,
                Row = toggle,
            })
        end
        if isHack and typeof(cfg.Settings) == "table" and #(cfg.Settings :: { any }) > 0 then
            self:_buildSettingsPopup(toggle, nameStr, cfg.Settings :: { any })
        end
        return toggle
    end

    function builder:AddButton(cfg: Widget.ButtonConfig): TextButton
        cfg.LayoutOrder = self:_nextOrder()
        local btn = Widget.Button(cfg)
        btn.Parent = self._window:GetContentFrame()
        registerMobileRow("ButtonRow", btn, {
            Buttons = { { Text = cfg.Text, Fire = cfg.Callback } },
        })
        return btn
    end

    function builder:AttachTooltip(target: GuiObject, text: string)
        Widget.Tooltip.Attach(target, text)
    end

    function builder:AttachShowButton(row: Instance, target: (any)): ImageButton
        local btn = Widget.ShowButton({ Callback = function()
            if typeof(target) == "table" and typeof(target.ShowAt) == "function" then
                if target:IsVisible() then
                    target:Hide()
                else

                    local okMouse, anchor = pcall(function()
                        local UIS = game:GetService("UserInputService")
                        local inset = game:GetService("GuiService"):GetGuiInset()
                        local loc = UIS:GetMouseLocation()
                        return Vector2.new(loc.X - inset.X, loc.Y - inset.Y)
                    end)
                    if not okMouse or typeof(anchor) ~= "Vector2" then

                        local origin = self._screenGui.AbsolutePosition
                        anchor = Vector2.new(
                            btn.AbsolutePosition.X - origin.X,
                            btn.AbsolutePosition.Y - origin.Y
                        )
                    end
                    target:ShowAt(anchor, Vector2.new(0, 0))
                end
            elseif typeof(target) == "function" then
                target()
            end
        end })
        btn.AnchorPoint = Vector2.new(0, 0.5)
        btn.Position = UDim2.new(0, 10, 0.5, 0)
        btn.ZIndex = (row.ZIndex or 1) + 2
        btn.Parent = row

        local genv = (typeof(getgenv) == "function" and getgenv())
            or (typeof(_G) == "table" and _G)
            or {}
        if typeof(target) == "table" then
            local showPopups = genv.GDH_SHOW_POPUPS
            if typeof(showPopups) ~= "table" then
                showPopups = {}
                genv.GDH_SHOW_POPUPS = showPopups
            end
            (showPopups :: { any })[row] = target
        end

        local function place()
            local title = row:FindFirstChild("Title")
            if not title or not title:IsA("GuiObject") then
                return
            end
            if title.AbsoluteSize.X <= 0 then
                return
            end
            local rightEdge = (title.AbsolutePosition.X - row.AbsolutePosition.X)
                + title.AbsoluteSize.X
            btn.Position = UDim2.new(0, math.floor(rightEdge + 7), 0.5, 0)
        end

        task.spawn(function()
            for _ = 1, 40 do
                local title = row:FindFirstChild("Title")
                if title and title:IsA("GuiObject") and title.AbsoluteSize.X > 0 then
                    place()
                    title:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
                    break
                end
                task.wait(0.05)
            end
        end)

        if typeof(target) == "table" and target._window ~= nil then
            target._window:SetOutsideIgnore(btn)
        end

        return btn
    end

    function builder:AddSeparator(configOrTextOrHeight: (string | number | Widget.SeparatorConfig)?): Frame
        local sep = Widget.Separator(configOrTextOrHeight, self:_nextOrder())
        sep.Parent = self._window:GetContentFrame()
        registerMobileRow("Separator", sep)
        return sep
    end

    function builder:AddLabel(cfg: Widget.LabelConfig): TextLabel
        cfg.LayoutOrder = self:_nextOrder()
        local lbl = Widget.Label(cfg)
        lbl.Parent = self._window:GetContentFrame()
        registerMobileRow("Label", lbl)
        return lbl
    end

    function builder:AddIntInput(cfg: Widget.IntInputConfig): Frame
        cfg.LayoutOrder = self:_nextOrder()
        local saveKey = widgetSaveKey(cfg and cfg.Label or nil, "IntInput")
        local userCallback: any = cfg.Callback
        if saveKey ~= nil and Save ~= nil then
            local persistKey = saveKey :: string
            cfg.Callback = function(value: number)
                Save.SetInput(persistKey, value, windowScope)
                if userCallback ~= nil then
                    userCallback(value)
                end
            end
        end
        local input = Widget.IntInput(cfg)
        input.Parent = self._window:GetContentFrame()
        if saveKey ~= nil and Save ~= nil then
            local restoreKey = saveKey :: string
            local restoreRow = input :: Instance
            task.defer(function()
                local saved = Save.InputValue(restoreKey, windowScope)
                if typeof(saved) ~= "number" then
                    return
                end
                local boxNode = restoreRow:FindFirstChild("Input")
                if typeof(boxNode) ~= "TextBox" then
                    return
                end
                local boxRef = boxNode :: TextBox
                if tonumber(boxRef.Text) == saved then
                    return
                end
                boxRef.Text = tostring(saved)
                if userCallback ~= nil then
                    userCallback(saved)
                end
            end)
        end
        local inputBox = input:FindFirstChild("Input")
        registerMobileRow("IntInput", input, {
            Name = cfg.Label,
            Min = cfg.Min,
            Max = cfg.Max,
            Default = cfg.Default,
            Get = function(): number?
                if typeof(inputBox) == "TextBox" then
                    return tonumber((inputBox :: TextBox).Text)
                end
                return nil
            end,
            Set = function(value: number)
                if typeof(inputBox) ~= "TextBox" then
                    return
                end
                local boxRef = inputBox :: TextBox
                local clamped = math.clamp(math.floor(value), cfg.Min or 0, cfg.Max or 9999)
                boxRef.Text = tostring(clamped)
                if cfg.Callback then
                    cfg.Callback(clamped)
                end
            end,
        })
        return input
    end

    function builder:AddFloatInput(cfg: Widget.FloatInputConfig): Frame
        cfg.LayoutOrder = self:_nextOrder()
        local saveKey = widgetSaveKey(cfg and cfg.Label or nil, "FloatInput")
        local userCallback: any = cfg.Callback
        if saveKey ~= nil and Save ~= nil then
            local persistKey = saveKey :: string
            cfg.Callback = function(value: number)
                Save.SetInput(persistKey, value, windowScope)
                if userCallback ~= nil then
                    userCallback(value)
                end
            end
        end
        local input = Widget.FloatInput(cfg)
        input.Parent = self._window:GetContentFrame()
        if saveKey ~= nil and Save ~= nil then
            local restoreKey = saveKey :: string
            local restoreRow = input :: Instance
            task.defer(function()
                local saved = Save.InputValue(restoreKey, windowScope)
                if typeof(saved) ~= "number" then
                    return
                end
                local boxNode = restoreRow:FindFirstChild("Input")
                if typeof(boxNode) ~= "TextBox" then
                    return
                end
                local boxRef = boxNode :: TextBox
                if tonumber(boxRef.Text) == saved then
                    return
                end
                boxRef.Text = string.format("%.2f", saved)
                if userCallback ~= nil then
                    userCallback(saved)
                end
            end)
        end
        local inputBox = input:FindFirstChild("Input")
        registerMobileRow("FloatInput", input, {
            Name = cfg.Label,
            Min = cfg.Min,
            Max = cfg.Max,
            Default = cfg.Default,
            Get = function(): number?
                if typeof(inputBox) == "TextBox" then
                    return tonumber((inputBox :: TextBox).Text)
                end
                return nil
            end,
            Set = function(value: number)
                if typeof(inputBox) ~= "TextBox" then
                    return
                end
                local boxRef = inputBox :: TextBox
                local clamped = math.clamp(value, cfg.Min or 0, cfg.Max or 9999)
                boxRef.Text = string.format("%.2f", clamped)
                if cfg.Callback then
                    cfg.Callback(clamped)
                end
            end,
        })
        return input
    end

    function builder:AddSlider(cfg: Widget.SliderConfig): Frame
        cfg.LayoutOrder = self:_nextOrder()
        local saveKey = widgetSaveKey(cfg and cfg.Name or nil, "Slider")
        local userCallback: any = cfg.Callback
        local userToggleCallback: any = cfg.ToggleCallback
        if saveKey ~= nil and Save ~= nil then
            local persistKey = saveKey :: string
            local switchKey = persistKey .. "::Switch"
            cfg.Callback = function(value: number)
                Save.SetSlider(persistKey, value, windowScope)
                if userCallback ~= nil then
                    userCallback(value)
                end
            end
            cfg.ToggleCallback = function(enabled: boolean)
                Save.SetToggle(switchKey, enabled, windowScope)
                if userToggleCallback ~= nil then
                    userToggleCallback(enabled)
                end
            end
        end
        local slider = Widget.Slider(cfg)
        slider.Parent = self._window:GetContentFrame()
        if saveKey ~= nil and Save ~= nil then
            local restoreKey = saveKey :: string
            local restoreSwitchKey = (saveKey :: string) .. "::Switch"
            local restoreRow = slider :: Instance
            task.defer(function()
                local savedSwitch = Save.ToggleState(restoreSwitchKey, windowScope)
                if savedSwitch ~= nil then
                    local switchNode = restoreRow:FindFirstChild("Switch")
                    if typeof(switchNode) == "Instance" then
                        local toggleApis = genv.GDH_ToggleRowApis
                        local switchApi = if typeof(toggleApis) == "table"
                            then toggleApis[switchNode :: Instance]
                            else nil
                        if switchApi ~= nil and switchApi.GetState() ~= savedSwitch then
                            switchApi.SetState(savedSwitch)
                        end
                    end
                end
                local saved = Save.SliderValue(restoreKey, windowScope)
                if saved ~= nil then
                    local apis = genv.GDH_SliderRowApis
                    local api = if typeof(apis) == "table" then apis[restoreRow] else nil
                    if api ~= nil and api.GetValue() ~= saved then
                        api.SetValue(saved)
                    end
                end
            end)
        end
        registerMobileRow("Slider", slider, {
            Name = cfg.Name,
            Suffix = cfg.Suffix,
            Min = cfg.Min,
            Max = cfg.Max,
            Increment = cfg.Increment,
            Precision = cfg.Precision,
            HasToggle = cfg.Toggle == true,
        })
        return slider
    end

    function builder:AddPadding(height: number?): Frame
        local pad = Widget.Padding(height, self:_nextOrder())
        pad.Parent = self._window:GetContentFrame()
        registerMobileRow("Padding", pad, { Height = if height ~= nil then height else 5 })
        return pad
    end

    function builder:AddKeybind(cfg: Widget.KeybindConfig): TextButton
        local kb = Widget.Keybind
        local pill = kb.Row({
            Label = cfg.Label or "Keybind",
            LayoutOrder = self:_nextOrder(),
        })
        local api = kb.PillApis[pill]
        if api ~= nil and cfg.Key ~= nil then
            api.SetKeyText(cfg.Key)
        end
        local userCallback: any = cfg.Callback
        local bindKey = widgetSaveKey(tostring(cfg.Label or "Keybind"), "Keybind")
        local hasPersist = bindKey ~= nil and Save ~= nil
        if cfg.Callback ~= nil and hasPersist then
            local persistKey = bindKey :: string
            cfg.Callback = function(code: Enum.KeyCode?)
                local bind = nil
                if code ~= nil then
                    bind = { Key = code, Mods = {} }
                end
                Save.SetCustomBind(persistKey, bind, windowScope)
                userCallback(code)
            end
        end
        if cfg.Callback ~= nil then
            pill.Activated:Connect(function()
                local recApi = kb.PillApis[pill]
                if recApi == nil then
                    return
                end
                recApi.SetKeyText("...")
                local conn
                conn = UserInputService.InputBegan:Connect(function(input)
                    if Keyboard.IsTyping() then
                        return
                    end
                    if input.UserInputType ~= Enum.UserInputType.Keyboard then
                        return
                    end
                    local code = input.KeyCode
                    if kb.IsModifier(code) then
                        return
                    end
                    conn:Disconnect()
                    if code == Enum.KeyCode.Escape then
                        recApi.SetKeyText("None")
                        cfg.Callback(nil)
                        return
                    end
                    recApi.SetKeyText(kb.BindLabel(code, kb.HeldModifiers()))
                    cfg.Callback(code)
                end)
            end)
        end
        pill.Parent = self._window:GetContentFrame()
        if hasPersist then
            local restoreKey = bindKey :: string
            task.defer(function()
                local saved = Save.CustomBind(restoreKey, windowScope)
                if typeof(saved) ~= "table" or saved.Key == nil then
                    return
                end
                if cfg.Key ~= nil and saved.Key == cfg.Key then
                    return
                end
                if api ~= nil then
                    api.SetKeyText(kb.BindLabel(saved.Key, saved.Mods))
                end
                if userCallback ~= nil then
                    userCallback(saved.Key)
                end
            end)
        end
        return pill
    end

    function builder:AddRadioButton(cfg: Widget.RadioButtonConfig): Frame
        cfg.LayoutOrder = self:_nextOrder()
        local saveKey = wireRadioSave(cfg)
        local rb = Widget.RadioButton(cfg)
        rb.Parent = self._window:GetContentFrame()
        scheduleRadioRestore(saveKey, rb)
        registerMobileRow("Radio", rb, { Name = cfg.Name, Group = cfg.Group })
        return rb
    end

    function builder:AddRadioRow(entries: { Widget.RadioButtonConfig }, offsetX: number?): Frame
        local inset = Theme.Layout.RadioRowInsetX or 10
        local gap = Theme.Layout.InlineGapX or 8

        local prevSlots: { Frame }?
        if offsetX then
            local prev = self._radioRowSlots
            if prev and prev.slots[offsetX] then
                prevSlots = prev.slots :: { Frame }
            end
        end

        local function anchorX(): number
            if offsetX and prevSlots then
                return prevSlots[offsetX :: number].Position.X.Offset
            end
            return inset
        end
        local startX = anchorX()

        local rowFrame = Instance.new("Frame")
        rowFrame.Name = "RadioRow"
        rowFrame.BackgroundTransparency = 1
        rowFrame.BorderSizePixel = 0

        rowFrame.Size = UDim2.new(1, 0, 0, Theme.Layout.RadioRowHeight)
        rowFrame.LayoutOrder = self:_nextOrder()

        local radios: { Frame } = {}
        local names: { string } = {}
        local titles: { TextButton? } = {}
        for i, cfg in entries do
            cfg.Inline = true
            cfg.LayoutOrder = i
            local radioSaveKey = wireRadioSave(cfg)
            local rb = Widget.RadioButton(cfg)

            rb.AutomaticSize = Enum.AutomaticSize.X
            rb.Size = UDim2.new(0, 0, 0, Theme.Layout.RowHeight)
            rb.Position = UDim2.fromOffset(startX, 0)
            rb.Parent = rowFrame
            scheduleRadioRestore(radioSaveKey, rb)
            table.insert(radios, rb)
            registerMobileRow("Radio", rb, { Name = cfg.Name, Group = cfg.Group })
            names[i] = cfg.Name
            local t = rb:FindFirstChild("Title")
            titles[i] = if t and t:IsA("TextButton") then t else nil
        end

        local busy = false
        local function relayout()
            if busy then
                return
            end
            busy = true
            local widths = {}
            for i, rb in radios do
                local w = rb.AbsoluteSize.X
                if w <= 0 then

                    w = Widget.measureTextWidth(names[i], Theme.Font.Body)
                        + Theme.Layout.ToggleHeight + 4
                end
                widths[i] = w
            end

            local x = anchorX()
            for i, rb in radios do
                rb.Position = UDim2.fromOffset(x, 0)
                x += widths[i] + gap
            end
            busy = false
        end

        rowFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
        for i, rb in radios do
            rb:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
            local title = titles[i]
            if title then
                title:GetPropertyChangedSignal("TextBounds"):Connect(relayout)
            end
        end

        if prevSlots then
            prevSlots[offsetX :: number]:GetPropertyChangedSignal("Position")
                :Connect(relayout)
        end
        task.defer(relayout)

        rowFrame.Parent = self._window:GetContentFrame()

        self._radioRowSlots = { rowFrame = rowFrame, slots = radios }
        return rowFrame
    end

    function builder:AddInputRow(cfg: Widget.TextInputConfig & {
        Arrow: boolean?, OnArrow: (() -> ())?, ArrowDirection: string?,
    }): Frame
        local container = Instance.new("Frame")
        container.Name = "InputRow"
        container.BackgroundTransparency = 1
        container.BorderSizePixel = 0
        container.Size = UDim2.new(1, 0, 0, Theme.Layout.RowHeight)
        container.LayoutOrder = self:_nextOrder()

        local H = Theme.Layout.ComboHeight
        local rightInset = 0

        if cfg.Arrow then
            local AH = H
            rightInset = AH + (Theme.Layout.PairGapX or 4)
            local ab = Widget.ArrowButton({
                Name = "select",
                Direction = cfg.ArrowDirection or "Down",
                Callback = cfg.OnArrow,
            })
            ab.AnchorPoint = Vector2.new(1, 0)
            ab.Position = UDim2.new(1, 0, 0, (Theme.Layout.RowHeight - AH) / 2)
            ab.Parent = container
        end

        local input = Widget.TextInput(cfg)
        input.Size = UDim2.new(1, -rightInset, 0, H)
        input.Position = UDim2.fromOffset(0, (Theme.Layout.RowHeight - H) / 2)
        input.Parent = container

        local textKey = widgetSaveKey(cfg and cfg.Hint or nil, "Text")
        if textKey ~= nil and Save ~= nil then
            local persistKey = textKey :: string
            input:GetAttributeChangedSignal("Value"):Connect(function()
                local value = input:GetAttribute("Value")
                if typeof(value) == "string" then
                    Save.SetText(persistKey, value, windowScope)
                end
            end)
        end

        container.Parent = self._window:GetContentFrame()
        if textKey ~= nil and Save ~= nil then
            local restoreKey = textKey :: string
            local restoreRow = input :: Instance
            task.defer(function()
                local saved = Save.TextValue(restoreKey, windowScope)
                if typeof(saved) ~= "string" then
                    return
                end
                local apis = genv.GDH_TextRowApis
                local api = if typeof(apis) == "table" then apis[restoreRow] else nil
                if api ~= nil and api.GetValue() ~= saved then
                    api.SetText(saved)
                end
            end)
        end
        registerMobileRow("TextInput", container, {
            Pill = input,
            Hint = cfg.Hint,
            OnArrow = cfg.OnArrow,
        })
        return container
    end

    function builder:AddButtonRow(cfgs: { Widget.ButtonConfig }): Frame
        local container = Instance.new("Frame")
        container.Name = "ButtonRow"
        container.BackgroundTransparency = 1
        container.BorderSizePixel = 0
        container.Size = UDim2.new(1, 0, 0, Theme.Layout.ButtonHeight)
        container.LayoutOrder = self:_nextOrder()

        local n = math.max(1, #cfgs)
        local gap = Theme.Layout.InlineGapX or 8
        local listLayout = Instance.new("UIListLayout")
        listLayout.FillDirection = Enum.FillDirection.Horizontal
        listLayout.Padding = UDim.new(0, gap)
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Parent = container

        local mobileButtons: { { Text: string, Fire: any } } = {}
        for i, cfg in cfgs do
            cfg.LayoutOrder = i
            cfg.Width = UDim2.new(1 / n, -(gap * (n - 1)) / n, 0, Theme.Layout.ButtonHeight)
            local b = Widget.Button(cfg)
            b.Parent = container
            mobileButtons[i] = { Text = cfg.Text, Fire = cfg.Callback }
        end

        container.Parent = self._window:GetContentFrame()
        registerMobileRow("ButtonRow", container, { Buttons = mobileButtons })
        return container
    end

    function builder:AddPopup(cfg: Widget.PopupConfig): {
        Open: () -> (), Close: () -> (), ShowAt: (Vector2, Vector2?) -> (),
        Frame: Frame, List: ScrollingFrame, Window: any,
    }
        local listWidth = math.floor((cfg.ListWidth or 400) * Theme.ScreenScale)
        local listHeight = math.floor((cfg.ListHeight or 500) * Theme.ScreenScale)
        local popupWin = ownerUI:CreateWindow({
            Title = cfg.Title or "",
            Popup = true,
            Visible = false,
            Size = UDim2.fromOffset(
                listWidth + Theme.Layout.ListPaddingX * 2,
                0),
        })

        local list = Instance.new("ScrollingFrame")
        list.Name = "List"
        list.BackgroundTransparency = 1
        list.BorderSizePixel = 0
        list.Size = UDim2.new(1, 0, 0, listHeight)
        list.CanvasSize = UDim2.fromScale(0, 0)
        list.AutomaticCanvasSize = Enum.AutomaticSize.Y
        list.ScrollBarThickness = Theme.Layout.ScrollBarWidth
        list.ScrollBarImageColor3 = Theme.Colors.ResizeHandle
        list.ScrollBarImageTransparency = 0.3
        list.LayoutOrder = 1
        list.Parent = popupWin:GetContentFrame()

        local listLayout = Instance.new("UIListLayout")
        listLayout.Padding = UDim.new(0, Theme.Layout.RowPadding)
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Parent = list

        local itemOrder = 0
        for _, itemName in (cfg.Items or {}) do
            itemOrder += 1
            local pill = Widget.Button({
                Text = itemName,
                LayoutOrder = itemOrder,
                Callback = function()
                    if cfg.OnSelect then
                        cfg.OnSelect(itemName)
                    end
                    popupWin:Hide()
                end,
            })
            pill.Parent = list
        end

        local footerOrder = 1
        for _, buttonName in (cfg.FooterButtons or {}) do
            footerOrder += 1
            local pill = Widget.Button({
                Text = buttonName,
                LayoutOrder = footerOrder,
                Callback = function()
                    if buttonName == "Close" then
                        popupWin:Hide()
                    end
                    if cfg.OnButton then
                        cfg.OnButton(buttonName)
                    end
                end,
            })
            pill.Parent = popupWin:GetContentFrame()
        end

        return {
            Open = function()
                popupWin:Show()
            end,
            Close = function()
                popupWin:Hide()
            end,
            ShowAt = function(anchor: Vector2, offset: Vector2?)
                popupWin:ShowAt(anchor, offset)
            end,
            ShowCentered = function()
                popupWin:ShowCentered()
            end,
            Frame = popupWin.Root,
            List = list,
            Window = popupWin,
        }
    end

    function builder:AddDropdown(cfg: Widget.DropdownConfig): Frame
        cfg.LayoutOrder = self:_nextOrder()
        local saveKey = widgetSaveKey(cfg and cfg.Label or nil, "Dropdown")
        local userCallback: any = cfg.Callback
        if saveKey ~= nil and Save ~= nil then
            local persistKey = saveKey :: string
            cfg.Callback = function(index: number, optionText: string)
                Save.SetDropdown(persistKey, optionText, windowScope)
                if userCallback ~= nil then
                    userCallback(index, optionText)
                end
            end
        end
        local dd = Widget.Dropdown(cfg)
        dd.Parent = self._window:GetContentFrame()
        if saveKey ~= nil and Save ~= nil then
            local restoreKey = saveKey :: string
            local restoreRow = dd :: Instance
            local restoreOptions = cfg.Options or {}
            task.defer(function()
                local savedText = Save.DropdownValue(restoreKey, windowScope)
                if typeof(savedText) ~= "string" then
                    return
                end
                for index, optionText in restoreOptions do
                    if optionText == savedText then
                        local apis = genv.GDH_DropdownRowApis
                        local api = if typeof(apis) == "table" then apis[restoreRow] else nil
                        if api ~= nil and api.GetValue() ~= index then
                            api.SetValue(index)
                        end
                        break
                    end
                end
            end)
        end
        registerMobileRow("Dropdown", dd, { Options = cfg.Options })
        return dd
    end

    function builder:SetVisible(visible: boolean)
        self._window:SetVisible(visible)
    end

    function builder:SetTitle(title: string)
        self._window:SetTitle(title)
    end

    function builder:SetSearchable(enabled: boolean)
        self._window.Root:SetAttribute("GDHSearchExclude", enabled ~= true)
    end

    function builder:SetKeybindable(enabled: boolean)
        self._window.Root:SetAttribute("GDHKeybindExclude", enabled ~= true)
    end

    function builder:SetRowSearchable(row: Instance, enabled: boolean)
        if typeof(row) == "Instance" and row.Parent ~= nil then
            row:SetAttribute("GDHNoSearch", enabled ~= true)
        end
    end

    function builder:GetContentFrame(): ScrollingFrame
        return self._window:GetContentFrame()
    end

    function builder:Destroy()
        for index = #ownerUI._windows, 1, -1 do
            if ownerUI._windows[index] == self._window then
                table.remove(ownerUI._windows, index)
            end
        end
        self._window:Destroy()
        task.defer(function()
            ownerUI:RefreshAutoLayout()
        end)
    end

    return builder
end

function GDH_UI:RefreshAutoLayout()
    local autoWindows = {}
    for _, win in self._windows do
        if win._isAuto
            and win.Root ~= nil
            and win.Root.Parent ~= nil
            and win._userMoved ~= true
        then
            table.insert(autoWindows, win)
        end
    end
    if #autoWindows == 0 then
        return
    end

    table.sort(autoWindows, function(a, b)
        return (a._index or 0) < (b._index or 0)
    end)

    local columns = {}
    local columnByKey = {}
    for _, win in autoWindows do
        local hasOrder = type(win._order) == "number"
        local key = if hasOrder
            then "order:" .. tostring(win._order)
            else "index:" .. tostring(win._index)
        local column = columnByKey[key]
        if column == nil then
            column = {
                key = if hasOrder then win._order :: number else nil,
                firstIndex = win._index,
                windows = {},
            }
            columnByKey[key] = column
            table.insert(columns, column)
        end
        table.insert(column.windows, win)
    end

    for _, column in columns do
        table.sort(column.windows, function(a, b)
            local aSub = a._subOrder or 0
            local bSub = b._subOrder or 0
            if aSub ~= bSub then
                return aSub < bSub
            end
            local aRow = if type(a._row) == "number" then a._row else a._index
            local bRow = if type(b._row) == "number" then b._row else b._index
            return aRow < bRow
        end)
    end

    table.sort(columns, function(a, b)
        if a.key ~= nil and b.key ~= nil then
            if a.key ~= b.key then
                return a.key < b.key
            end
            return a.firstIndex < b.firstIndex
        end
        if a.key ~= nil then
            return true
        end
        if b.key ~= nil then
            return false
        end
        return a.firstIndex < b.firstIndex
    end)

    local displaySize = self._screenGui.AbsoluteSize
    local displayX = displaySize.X
    local displayY = displaySize.Y
    if displayX <= 0 or displayY <= 0 then
        return
    end

    local columnWidths = {}
    local totalWidth = AUTO_PADDING_X
    local maxHeight = 0
    for columnIndex, column in columns do
        local maxWidth = 0
        local columnHeight = AUTO_PADDING_Y * 2
        for index, win in column.windows do
            local size = win.Root.Size
            if size.X.Offset > maxWidth then
                maxWidth = size.X.Offset
            end
            columnHeight += size.Y.Offset
            if index < #column.windows then
                columnHeight += AUTO_SPACING_Y
            end
        end
        columnWidths[columnIndex] = maxWidth
        totalWidth += maxWidth + AUTO_PADDING_X
        if columnHeight > maxHeight then
            maxHeight = columnHeight
        end
    end

    local fillX = displayX / totalWidth
    local fillY = displayY / maxHeight
    local fillScale = math.min(fillX, fillY)

    local scale: number
    if fillScale < 1 then
        scale = fillScale
    else
        local hiDpiScale = math.min(displayX / 1920, displayY / 1080)
        scale = math.min(hiDpiScale, fillScale, 2.5)
        if scale < 1 then
            scale = 1
        end
    end
    scale = math.max(0.1, math.floor(scale / 0.1) * 0.1)

    local totalScaledWidth = AUTO_PADDING_X * scale
    for columnIndex, column in columns do
        totalScaledWidth += (columnWidths[columnIndex] * scale)
            + (AUTO_PADDING_X * scale)
    end

    local currentX = AUTO_PADDING_X * scale
    if self._horizontalCenter and displayX > totalScaledWidth then
        currentX = (displayX - totalScaledWidth) / 2 + AUTO_PADDING_X * scale
    end

    for columnIndex, column in columns do
        local scaledMaxWidth = columnWidths[columnIndex] * scale
        local currentY = AUTO_PADDING_Y * scale
        for _, win in column.windows do
            local position = UDim2.fromOffset(
                math.floor(currentX + 0.5),
                math.floor(currentY + 0.5))
            win.Root.Position = position
            win._initialPosition = position
            currentY += win.Root.Size.Y.Offset + AUTO_SPACING_Y * scale
        end
        currentX += scaledMaxWidth + AUTO_PADDING_X * scale
    end
end

function GDH_UI:SetHorizontalCenter(enabled: boolean)
    self._horizontalCenter = enabled == true
    self:RefreshAutoLayout()
end

function GDH_UI:SetVersion(version: string)
    local badge = self._badge
    local vLabel = badge and badge:FindFirstChild("Release")
    if vLabel and vLabel:IsA("TextLabel") then
        vLabel.Text = version
        local reflow = self._badgeReflow
        if typeof(reflow) == "function" then
            task.defer(reflow)
        end
    end
end

function GDH_UI:Notify(text: string, duration: number?)
    duration = duration or 5
    local notices = self._notices
    local host = self._noticeHost
    if notices == nil or host == nil then
        return
    end

    self._noticeSeq = (self._noticeSeq or 0) + 1

    local NOTICE_W = 245
    local NOTICE_PAD_Y = 8
    local NOTICE_MIN_H = 33

    local container = Instance.new("Frame")
    container.Name = "Notice"
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.Size = UDim2.fromOffset(NOTICE_W, 0)
    container.LayoutOrder = self._noticeSeq
    container.Parent = host

    local shadow = Instance.new("Frame")
    shadow.Name = "NoticeShadow"
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.82
    shadow.BorderSizePixel = 0
    shadow.AnchorPoint = Vector2.new(0, 1)
    shadow.Position = UDim2.new(0, NOTICE_W + 18 + 2, 1, 3)
    shadow.Size = UDim2.fromOffset(NOTICE_W, 0)
    shadow.ZIndex = 1
    shadow.Parent = container

    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 10)
    shadowCorner.Parent = shadow

    local inner = Instance.new("Frame")
    inner.Name = "NoticeBG"
    inner.Active = true
    inner.BackgroundColor3 = Color3.fromRGB(32, 32, 78)
    inner.BackgroundTransparency = 0
    inner.BorderSizePixel = 0
    inner.AnchorPoint = Vector2.new(0, 1)
    inner.Position = UDim2.new(0, NOTICE_W + 18, 1, 0)
    inner.ClipsDescendants = true
    inner.Size = UDim2.fromScale(1, 1)
    inner.ZIndex = 2
    inner.Parent = container

    local innerCorner = Instance.new("UICorner")
    innerCorner.CornerRadius = UDim.new(0, 10)
    innerCorner.Parent = inner

    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(188, 173, 231)
    stroke.Thickness = 1.5
    pcall(function()
        stroke.StrokeSizingMode = Enum.StrokeSizingMode.FixedSize
    end)
    stroke.Parent = inner

    local label = Instance.new("TextLabel")
    label.Name = "Text"
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.AnchorPoint = Vector2.new(0, 1)
    label.Position = UDim2.new(0, 10, 1, -NOTICE_PAD_Y)
    label.Size = UDim2.new(1, -20, 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.FontFace = Theme.GetFontFace()
    label.Text = text
    label.TextColor3 = Color3.fromRGB(213, 196, 255)
    label.TextSize = Theme.Font.Small
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 3
    label.Parent = inner

    table.insert(notices, container)

    local slideT = 0
    local heightT = 0
    local dying = false
    local expiry = os.clock() + duration
    local conn
    conn = RunService.Heartbeat:Connect(function(dt: number)
        local slideTarget = 0
        local heightTarget = 0
        if not dying then
            slideTarget = 1
            heightTarget = 1
            if os.clock() >= expiry then
                dying = true
            end
        elseif heightT > 0.02 then
            heightTarget = 0
        else
            heightT = 0
            slideTarget = 0
        end
        local factor = math.min(1, dt * 10)
        slideT += (slideTarget - slideT) * factor
        heightT += (heightTarget - heightT) * factor
        if dying and heightT <= 0.01 and slideT <= 0.01 then
            slideT = 0
            heightT = 0
            conn:Disconnect()
            local connIdx = table.find(self._noticeConns or {}, conn)
            if connIdx ~= nil then
                table.remove(self._noticeConns, connIdx)
            end
            local idx = table.find(notices, container)
            if idx ~= nil then
                table.remove(notices, idx)
            end
            container:Destroy()
            return
        end
        local naturalH = label.AbsoluteSize.Y
        local targetH = naturalH > 0 and (naturalH + NOTICE_PAD_Y * 2) or NOTICE_MIN_H
        local slotHeight = math.max(0, targetH * heightT)
        local xOff = (NOTICE_W + 18) * (1 - slideT)
        container.Size = UDim2.fromOffset(NOTICE_W, slotHeight)
        inner.Position = UDim2.new(0, xOff, 1, 0)
        shadow.Position = UDim2.new(0, xOff + 2, 1, 3)
        shadow.Size = UDim2.fromOffset(NOTICE_W, slotHeight)
    end)
    table.insert(self._noticeConns or {}, conn)
end

function GDH_UI:Destroy()
    if self._releaseCursor then
        self._releaseCursor()
    end
    for _, conn in self._connections do
        conn:Disconnect()
    end
    for _, noticeConn in self._noticeConns do
        pcall(function()
            noticeConn:Disconnect()
        end)
    end
    for _, win in self._windows do
        win:Destroy()
    end
    self._noticeGui:Destroy()
    self._screenGui:Destroy()
end

return GDH_UI
