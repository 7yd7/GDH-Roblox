local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local UI = genv.GDH_UI
if typeof(UI) ~= "table" then
    return
end

local UserInputService = game:GetService("UserInputService")
local Theme = UI.Theme
local Widget = UI.Widget
local Keybind = Widget.Keybind

local Save = nil
local SaveImport = genv.Import
if SaveImport ~= nil then
    pcall(function()
        Save = SaveImport("Function/Save")
    end)
end
if Save == nil then
    Save = genv.GDH_Save
end

local Keyboard = nil
if typeof(genv.Import) == "function" then
    pcall(function()
        Keyboard = genv.Import("Function/Keyboard")
    end)
end
if typeof(Keyboard) ~= "table" then
    Keyboard = genv.GDH_Keyboard
end
local isTyping = function(): boolean
    if typeof(Keyboard) == "table" and typeof(Keyboard.IsTyping) == "function" then
        local ok, result = pcall(Keyboard.IsTyping)
        if ok then
            return result == true
        end
    end
    local focused = UserInputService:GetFocusedTextBox()
    return focused ~= nil and focused.TextEditable ~= false
end

local function S(n: number): number
    return math.floor(n * (Theme.ScreenScale or 1) + 0.5)
end

local keybindActions: { any } = {}
local knownActionIds: { [string]: boolean } = {}
if typeof(genv.GDH_KeybindActions) == "table" then
    for _, action in genv.GDH_KeybindActions do
        if typeof(action) == "table" and typeof(action.Id) == "string" then
            table.insert(keybindActions, action)
            knownActionIds[action.Id] = true
        end
    end
end

local modulePopups: { [string]: any } = {}
local modulePopupActionIds: { [string]: { [string]: boolean } } = {}
local syncKeybindActions: (() -> ())? = nil

local keybindsWindow = UI:CreateWindow({
    Title = "Keybinds",

    Order = "9995-2",
    AutoHeight = true,
    Searchable = false,
    Size = UDim2.fromOffset(S(270), S(165)),
})

local moduleState = {
    Shortcuts = false,
    Framerate = false,
    ["Replay Engine"] = false,
}
local hackBinds: { [Instance]: any } = setmetatable({}, { __mode = "k" })
local actionBinds: { [string]: any } = {}
local toggleUIBind = { Key = Enum.KeyCode.G :: Enum.KeyCode?, Mods = {} }
local actionRowApis: { [string]: { any } } = {}
local pendingHackBinds: { [string]: any } = {}

if Save ~= nil then
    local savedToggleUI = Save.ToggleUIBind("Global")
    if savedToggleUI ~= nil then
        toggleUIBind = savedToggleUI
    end
    for id, bind in Save.AllActionBinds("Global") do
        actionBinds[id] = bind
    end
    local allHackBinds = Save.AllHackBinds()
    for scope, list in allHackBinds do
        for id, bind in list do
            pendingHackBinds[id] = { Scope = scope, Bind = bind }
        end
    end
end

local overlays: { [Instance]: any } = {}
local recording: any = nil

local CANCEL_KEYS = {
    [Enum.KeyCode.Escape] = true,
    [Enum.KeyCode.Backspace] = true,
    [Enum.KeyCode.Delete] = true,
}

UI._toggleKey = nil

local function bindText(bind: any): string
    if bind == nil or bind.Key == nil then
        return "None"
    end
    return Keybind.BindLabel(bind.Key, bind.Mods)
end

local function pillApiOf(row: Instance): any?
    local apis = Keybind.PillApis
    if typeof(apis) ~= "table" then
        return nil
    end
    return apis[row]
end

local function syncActionRowTexts(id: string)
    local rows = actionRowApis[id]
    if rows == nil then
        return
    end
    local text = bindText(actionBinds[id])
    for _, entry in rows do
        local api = entry.Api
        if typeof(api) == "table" and typeof(api.SetKeyText) == "function" then
            api.SetKeyText(text)
        end
        local win = entry.Window
        if typeof(win) == "table" and typeof(win.FitContentWidth) == "function" then
            pcall(function()
                win:FitContentWidth()
            end)
        end
    end
end

local function startRecording(kind: string, target: any)
    if target.Api == nil then
        return
    end
    local rec = {
        Kind = kind :: string,
        Target = target :: any,
        Row = target.Row,
        Id = target.Id,
        Action = target.Action,
        Scope = target.Scope,
        TargetApi = target.Api,
    }
    rec.Restore = target.Api.GetKeyText()
    target.Api.SetKeyText("...")
    recording = rec
end

local function stopRecording()
    local rec = recording
    recording = nil
    if rec == nil then
        return
    end
    if rec.TargetApi ~= nil then
        rec.TargetApi.SetKeyText(rec.Restore)
    end
end

local function applyRecordingAssign(keyCode: Enum.KeyCode, mods: { string })
    local rec = recording
    recording = nil
    if rec == nil then
        return
    end
    local kind = rec.Kind :: string
    local bind = { Key = keyCode, Mods = mods }
    if kind == "hack" then
        local row = rec.Row :: Instance
        hackBinds[row] = bind
        local api = rec.TargetApi
        if api ~= nil then
            api.SetKeyText(bindText(bind))
        end
        local hackId = rec.Id
        local hackScope = if rec.Scope == "Map" then "Map" else "Global"
        if Save ~= nil and typeof(hackId) == "string" then
            Save.SetHackBind(hackId :: string, bind, hackScope)
            pendingHackBinds[hackId :: string] = { Scope = hackScope, Bind = bind }
        end
    elseif kind == "action" or kind == "ui" then
        local id = rec.Id :: string
        actionBinds[id] = bind
        local api = rec.TargetApi
        if api ~= nil then
            api.SetKeyText(bindText(bind))
        end
        if kind == "action" then
            syncActionRowTexts(id)
        end
        if Save ~= nil then
            if kind == "action" then
                Save.SetActionBind(id, bind, "Global")
            else
                toggleUIBind = bind
                Save.SetToggleUIBind(bind, "Global")
            end
        end
    end
end

local function applyRecordingReset()
    local rec = recording
    recording = nil
    if rec == nil then
        return
    end
    local kind = rec.Kind :: string
    if kind == "hack" then
        local row = rec.Row :: Instance
        hackBinds[row] = nil
        local api = rec.TargetApi
        if api ~= nil then
            api.SetKeyText("None")
        end
        local hackId = rec.Id
        local hackScope = if rec.Scope == "Map" then "Map" else "Global"
        if Save ~= nil and typeof(hackId) == "string" then
            Save.SetHackBind(hackId :: string, nil, hackScope)
            pendingHackBinds[hackId :: string] = nil
        end
    elseif kind == "action" then
        local id = rec.Id :: string
        local action = rec.Action :: any
        local defaultBind = if action ~= nil and action.Default ~= nil
            then { Key = action.Default :: Enum.KeyCode, Mods = {} }
            else nil
        if defaultBind ~= nil then
            actionBinds[id] = defaultBind
        else
            actionBinds[id] = nil
        end
        local api = rec.TargetApi
        if api ~= nil then
            api.SetKeyText(bindText(defaultBind))
        end
        if Save ~= nil then
            Save.SetActionBind(id, defaultBind, "Global")
        end
        syncActionRowTexts(id)
    elseif kind == "ui" then
        toggleUIBind = { Key = Enum.KeyCode.G :: Enum.KeyCode?, Mods = {} }
        local api = rec.TargetApi
        if api ~= nil then
            api.SetKeyText("G")
        end
        if Save ~= nil then
            Save.SetToggleUIBind(toggleUIBind, "Global")
        end
    end
end

local function resolveSavedHackBinds()
    if Save == nil then
        return
    end
    local hacks = UI._keybindHacks
    if typeof(hacks) ~= "table" then
        return
    end
    for _, entry in hacks :: { any } do
        local row = entry.Row
        local id = entry.Id
        if typeof(row) == "Instance" and typeof(id) == "string"
            and hackBinds[row] == nil
        then
            local pending = pendingHackBinds[id]
            if typeof(pending) == "table" then
                local pendingScope = if pending.Scope == "Map" then "Map" else "Global"
                local entryWin = entry.Window
                local entryScope = if typeof(entryWin) == "table"
                    and (entryWin :: any)._scope == "Map"
                    then "Map"
                    else "Global"
                if pendingScope ~= entryScope then
                    continue
                end
                local bind = pending.Bind
                if typeof(bind) == "table" then
                    hackBinds[row] = bind
                    local overlay = overlays[row :: Instance]
                    if typeof(overlay) == "Instance" then
                        local overlayApi = pillApiOf(overlay :: Instance)
                        if overlayApi ~= nil then
                            overlayApi.SetKeyText(bindText(bind))
                        end
                    end
                end
            end
        end
    end
end
genv.GDH_KeybindBindsResolve = resolveSavedHackBinds

local function moduleActive(moduleName: any): boolean
    if moduleName == nil then
        return true
    end
    local state = moduleState[moduleName :: string]
    if state == nil then
        return true
    end
    return state
end

local function shouldToggleUI(keyCode: Enum.KeyCode, mods: { any }): boolean
    if toggleUIBind == nil or toggleUIBind.Key == nil then
        return false
    end
    if keyCode ~= toggleUIBind.Key then
        return false
    end
    if not Keybind.ModsEqual(toggleUIBind.Mods, mods) then
        return false
    end
    if recording ~= nil then
        return false
    end
    if typeof(genv.GDH_MODAL_OPEN) == "number" and (genv.GDH_MODAL_OPEN :: number) > 0 then
        return false
    end
    if isTyping() then
        return false
    end
    return true
end

local toggleConn: RBXScriptConnection? = nil
toggleConn = UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end
    if shouldToggleUI(input.KeyCode, Keybind.HeldModifiers()) then
        if typeof(Keyboard) == "table" and typeof(Keyboard.ReleaseTraps) == "function" then
            pcall(Keyboard.ReleaseTraps)
        end
        if typeof(UI.Toggle) == "function" then
            UI:Toggle()
        end
    end
end)

local inputConn: RBXScriptConnection? = nil
inputConn = UserInputService.InputBegan:Connect(function(input)
    if isTyping() then
        return
    end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end
    local keyCode = input.KeyCode

    if recording ~= nil then
        if CANCEL_KEYS[keyCode] then
            applyRecordingReset()
        elseif Keybind.IsModifier(keyCode) then
            return
        else
            applyRecordingAssign(keyCode, Keybind.HeldModifiers())
        end
        return
    end

    local mods = Keybind.HeldModifiers()

    if typeof(syncKeybindActions) == "function" then
        syncKeybindActions()
    end

    for _, action in keybindActions do
        local bind = actionBinds[action.Id :: string]
        if bind ~= nil and bind.Key == keyCode
            and Keybind.ModsEqual(bind.Mods, mods)
        then
            if moduleActive(action.Module) then
                local ok, err = pcall(action.Callback)
                if not ok then
                    warn("Keybinds action error: " .. tostring(err))
                end
            end
        end
    end

    for row, bind in hackBinds do
        if bind ~= nil and bind.Key == keyCode
            and Keybind.ModsEqual(bind.Mods, mods)
        then
            local apis = genv.GDH_ToggleRowApis
            local api = if typeof(apis) == "table" then apis[row] else nil
            if api ~= nil then
                api.SetState(not api.GetState())
            end
        end
    end
end)

keybindsWindow.Root.Destroying:Connect(function()
    if toggleConn ~= nil then
        toggleConn:Disconnect()
        toggleConn = nil
    end
    if inputConn ~= nil then
        inputConn:Disconnect()
        inputConn = nil
    end
end)

local function makeActionPill(targetWindow: any, action: any): Instance
    local id = action.Id :: string
    if actionBinds[id] == nil and action.Default ~= nil then
        actionBinds[id] = { Key = action.Default :: Enum.KeyCode, Mods = {} }
    end
    local pill = Keybind.Row({
        Label = action.Name :: string,
        LayoutOrder = targetWindow:_nextOrder(),
    })
    local api = pillApiOf(pill)
    if api ~= nil then
        api.SetKeyText(bindText(actionBinds[id]))
    end
    local rows = actionRowApis[id]
    if rows == nil then
        rows = {}
        actionRowApis[id] = rows
    end
    table.insert(rows, { Window = targetWindow, Api = api })
    pill.Activated:Connect(function()
        if recording ~= nil then
            return
        end
        startRecording("action", { Api = pillApiOf(pill), Id = id, Action = action })
    end)
    pill.Parent = targetWindow:GetContentFrame()
    return pill
end

local function buildModulePopup(moduleName: string, width: number): any
    local popup = UI:CreateWindow({
        Title = "Keybinds - " .. moduleName,
        Popup = true,
        Visible = false,
        Size = UDim2.fromOffset(S(width), S(120)),
        FitWidth = true,
    })
    if moduleName == "Framerate" then
        popup:AddLabel({ Text = "Speedhack:" })
    end
    modulePopupActionIds[moduleName] = modulePopupActionIds[moduleName] or {}
    for _, action in keybindActions do
        if action.Module == moduleName
            and modulePopupActionIds[moduleName][action.Id] ~= true
        then
            modulePopupActionIds[moduleName][action.Id] = true
            makeActionPill(popup, action)
        end
    end
    if next(modulePopupActionIds[moduleName]) == nil then
        popup._gdhNoActionsLabel = popup:AddLabel({ Text = "No actions registered yet" })
    end
    return popup
end

local function makeModuleToggle(moduleName: string, popupWidth: number)
    local row = keybindsWindow:AddToggle({
        Name = moduleName,
        Default = false,
        Callback = function(state)
            moduleState[moduleName] = state
        end,
    })
    local popup = buildModulePopup(moduleName, popupWidth)
    modulePopups[moduleName] = popup
    keybindsWindow:AttachShowButton(row, popup)
    return row
end

local function doSyncKeybindActions()
    local registry = genv.GDH_KeybindActions
    if typeof(registry) ~= "table" then
        return
    end
    for _, action in registry do
        if typeof(action) == "table" and typeof(action.Id) == "string"
            and knownActionIds[action.Id] ~= true
        then
            knownActionIds[action.Id] = true
            if typeof(action.Callback) == "function" then
                table.insert(keybindActions, action)
                local moduleName = action.Module
                if typeof(moduleName) == "string" then
                    local popup = modulePopups[moduleName]
                    if popup ~= nil
                        and modulePopupActionIds[moduleName][action.Id] ~= true
                    then
                        modulePopupActionIds[moduleName][action.Id] = true
                        local placeholder = popup._gdhNoActionsLabel
                        if placeholder ~= nil then
                            placeholder:Destroy()
                            popup._gdhNoActionsLabel = nil
                        end
                        makeActionPill(popup, action)
                    end
                end
            end
        end
    end
end

syncKeybindActions = doSyncKeybindActions
genv.GDH_KeybindActionsSync = doSyncKeybindActions

keybindsWindow:AddToggle({
    Name = "Keybinds Mode",
    Default = false,
    Callback = function(state)
        if state then
            resolveSavedHackBinds()
            for _, entry in UI._keybindHacks do
                local row = entry.Row
                local excluded = false
                local entryWin = entry.Window
                if typeof(entryWin) == "table"
                    and entryWin.Root ~= nil
                    and typeof(entryWin.Root) == "Instance"
                then
                    excluded = (entryWin.Root :: Instance):GetAttribute("GDHKeybindExclude") == true
                end
                if typeof(row) == "Instance" and not excluded
                    and (row :: Instance).Parent ~= nil
                    and overlays[row] == nil
                then
                    local rowObj = row :: Instance
                    local replace = Keybind.Row({
                        Label = entry.Name,
                    })
                    replace.Position = UDim2.fromOffset(0, 0)
                    replace.Size = UDim2.new(1, 0, 0, Theme.Layout.RowHeight)
                    replace.ZIndex = 3
                    local api = pillApiOf(replace)
                    if api ~= nil then
                        api.SetKeyText(bindText(hackBinds[rowObj]))
                    end
                    overlays[rowObj] = replace
                    replace.Activated:Connect(function()
                        if recording ~= nil then
                            return
                        end
                        startRecording("hack", {
                            Row = entry.Row,
                            Api = pillApiOf(replace),
                            Name = entry.Name,
                            Id = entry.Id,
                            Scope = entry.Window._scope,
                        })
                    end)
                    replace.Parent = rowObj
                end
            end
        else
            local recordingWasHack = recording ~= nil and recording.Kind == "hack"
            if recordingWasHack then
                stopRecording()
            end
            local toClear: { Instance } = {}
            for rowObj, replace in overlays do
                table.insert(toClear, rowObj :: Instance)
            end
            for _, rowObj in toClear do
                local replace = overlays[rowObj]
                if replace ~= nil then
                    replace:Destroy()
                end
                overlays[rowObj] = nil
            end
        end
    end,
})

makeModuleToggle("Shortcuts", 180)
makeModuleToggle("Framerate", 180)
makeModuleToggle("Replay Engine", 180)

local toggleUiRow = Keybind.Row({
    Label = "Toggle UI",
    LayoutOrder = keybindsWindow:_nextOrder(),
})
local toggleUiApi = pillApiOf(toggleUiRow)
if toggleUiApi ~= nil then
    toggleUiApi.SetKeyText(bindText(toggleUIBind))
end
toggleUiRow.Activated:Connect(function()
    if recording ~= nil then
        return
    end
    startRecording("ui", { Api = pillApiOf(toggleUiRow), Id = "__toggleUI" })
end)
toggleUiRow.Parent = keybindsWindow:GetContentFrame()

doSyncKeybindActions()
resolveSavedHackBinds()
