local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local Import = genv.Import
if not Import then

    Import = require(script.Parent["Function"]["Import"])
end

local Popup_GD = Import("Function/Popup_GD")
genv.GDH_POPUP_GD = Popup_GD

local Conceal = Import("Function/Conceal")
Conceal.Install()

local UserInputService = game:GetService("UserInputService")
local UI = genv.GDH_UI

local toggleKeyName = "G"
if UI and UI._toggleKey then
    toggleKeyName = string.upper(UI._toggleKey.Name)
end

local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local device = if isTouch then "touch screen" else "keyboard"
local action = if isTouch then "tap" else "press"
local target = if isTouch then "the GDH button" else ('' .. toggleKeyName .. '')

genv.GDH_INFO_TEXT = Popup_GD.Text(
    'Hi! It seems you\'re using a <font color="#ff0000"><b>' .. device .. '</b></font>.\nTo '
    .. 'Open interface you need to\n' .. action .. ' <font color="#FFFF00"><b>' .. target .. '</b></font> in this game.'
)

genv.GDH_READY_TEXT = Popup_GD.Text(
    'GDH is already running.\n'
    .. 'The interface is ready.\n'
    .. action .. ' <font color="#FFFF00"><b>' .. target .. '</b></font> to open it.'
)

if UI and UI._screenGui and UI._screenGui.Parent then
    task.defer(function()
        local okInfo, InfoScreen = pcall(Import, "interface/GD/InfoScreen")
        if okInfo and InfoScreen and typeof(InfoScreen.Show) == "function" then
            InfoScreen.Show({
                Name = "GDH_InfoScreen",
                Title = "Ready",
                ButtonText = "OK",
                Width = 0.34,
                Height = 0.40,
                Dim = 0.41,
                PanelWidth = 0.42,
                Body = genv.GDH_READY_TEXT,
            })
        end
    end)
    return
end

local GDH_UI = Import("interface/Pc/init")

UI = GDH_UI.CreateLib({
    Title = "GDH",
    ToggleKey = Enum.KeyCode.G,
})

genv.GDH_UI = UI
if UI and UI._screenGui then
    Conceal.Register(UI._screenGui)
    Conceal.Register(UI._screenGui.Parent)
end

task.defer(function()
    local okInfo, InfoScreen = pcall(Import, "interface/GD/InfoScreen")
    if okInfo and InfoScreen and typeof(InfoScreen.ShowOnce) == "function" then
        InfoScreen.ShowOnce({
            Name = "GDH_InfoScreen",
            Title = "Info",
            ButtonText = "OK",
            Width = 0.34,
            Height = 0.40,
            Dim = 0.41,
            PanelWidth = 0.42,
            Body = genv.GDH_INFO_TEXT,
        })
    end
end)

local MobileBoot = Import("interface/Mobile/init")
if typeof(MobileBoot) == "function" then
    task.spawn(function()
        local okMobile, errMobile = pcall(MobileBoot)
        if not okMobile then
            warn("[GDH] Mobile init: " .. tostring(errMobile))
        elseif genv.GDH_MOBILE_UI then
            Conceal.Register(genv.GDH_MOBILE_UI)
            Conceal.Register(genv.GDH_MOBILE_UI.Parent)
        end
    end)
end

local function sweepStaleUI(): ()
    local containers: { Instance } = {}
    local okCore, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if okCore and coreGui then
        containers[#containers + 1] = coreGui
    end
    local player = game:GetService("Players").LocalPlayer
    if player then
        local playerGui = player:FindFirstChildOfClass("PlayerGui")
        if playerGui then
            containers[#containers + 1] = playerGui
        end
    end
    for _, container in ipairs(containers) do
        for _, child in ipairs(container:GetChildren()) do
            local marked = child:GetAttribute("GDHUI") == true
            if child:IsA("ScreenGui") and (marked or child.Name == "GDH" or child.Name == "GDH Mobile") then
                pcall(function()
                    child:Destroy()
                end)
            elseif child:IsA("Folder") and (marked or child.Name == "GDH") then
                pcall(function()
                    child:Destroy()
                end)
            end
        end
    end
end

genv.GDH_Kill = function()
    local ui = genv.GDH_UI
    if ui then
        for _, conn in pairs(ui._connections or {}) do
            pcall(function()
                conn:Disconnect()
            end)
        end
        for _, win in pairs(ui._windows or {}) do
            pcall(function()
                win:Destroy()
            end)
        end
        if ui._noticeGui then
            pcall(function()
                ui._noticeGui:Destroy()
            end)
        end
        if ui._screenGui then
            pcall(function()
                ui._screenGui:Destroy()
            end)
        end
    end
    sweepStaleUI()
    genv.GDH_UI = nil
    genv.GDH_Restart = nil
    genv.GDH_Kill = nil
end

genv.GDH_Restart = function()
    local ui = genv.GDH_UI
    if ui then
        for _, conn in pairs(ui._connections or {}) do
            pcall(function()
                conn:Disconnect()
            end)
        end
        for _, win in pairs(ui._windows or {}) do
            pcall(function()
                win:Destroy()
            end)
        end
        if ui._noticeGui then
            pcall(function()
                ui._noticeGui:Destroy()
            end)
        end
        if ui._screenGui then
            pcall(function()
                ui._screenGui:Destroy()
            end)
        end
    end
    sweepStaleUI()
    genv.GDH_UI = nil
    genv.GDH_Kill = nil
    local entry = genv.GDH_MODULES and genv.GDH_MODULES["src/init.luau"]
    if type(entry) == "function" then
        task.defer(entry)
    end
end

local HttpService = game:GetService("HttpService")

local function relativeTo(moduleKey: string, prefix: string): string?
    if string.sub(moduleKey, 1, #prefix) == prefix then
        return string.sub(moduleKey, #prefix + 1)
    end
    return nil
end

local function loadGDHScripts(folderPrefix: string, scriptScope: string?, skip: { [string]: boolean }?): number
    if not genv.GDH_MODULES then
        return 0
    end
    local matching: { string } = {}
    local directKey = string.sub(folderPrefix, 1, #folderPrefix - 1)
    for moduleKey in pairs(genv.GDH_MODULES) do
        local isMatch = (string.sub(moduleKey, 1, #folderPrefix) == folderPrefix
                and string.sub(moduleKey, -5) == ".luau")
            or (moduleKey == directKey and string.sub(directKey, -5) == ".luau")
        local relative = relativeTo(moduleKey, folderPrefix)
        if isMatch and not (skip ~= nil and relative ~= nil and skip[relative]) then
            table.insert(matching, moduleKey)
        end
    end
    table.sort(matching)
    for _, moduleKey in matching do
        local moduleFactory = genv.GDH_MODULES[moduleKey]
        task.spawn(function()
            genv.GDH_SCRIPT_SCOPE = if scriptScope ~= nil then scriptScope else "Map"
            local ok, err = pcall(moduleFactory)
            genv.GDH_SCRIPT_SCOPE = nil
            if not ok then
                warn("[GDH] " .. moduleKey .. ": " .. tostring(err))
            end
        end)
    end
    return #matching
end

local mapIdsText = genv.GDH_PACKAGE and genv.GDH_PACKAGE["Script/ids.json"]
local okMapIds, mapIds = pcall(function()
    return HttpService:JSONDecode(mapIdsText)
end)

local mapFolder: string? = nil
if okMapIds and type(mapIds) == "table" then
    local function matchMapFolder(idValue: any): string?
        if idValue == nil or idValue == 0 then
            return nil
        end
        for _, mapInfo in pairs(mapIds) do
            if type(mapInfo) == "table"
                and mapInfo.path ~= nil
                and mapInfo.path ~= ""
                and tonumber(mapInfo.id) == idValue
            then
                return "Script/" .. mapInfo.path .. "/"
            end
        end
        return nil
    end

    mapFolder = matchMapFolder(game.PlaceId)
        or matchMapFolder(game.GameId)
end
local mapDir = mapFolder and string.match(mapFolder, "^(.*/)[^/]+/$") or nil

local globalOverrides: { [string]: boolean } = {}
if mapDir and genv.GDH_MODULES then
    for moduleKey in pairs(genv.GDH_MODULES) do
        local relative = relativeTo(moduleKey, mapDir)
        if relative ~= nil
            and string.sub(relative, -5) == ".luau"
            and relative ~= "loader.luau"
            and string.sub(relative, 1, 9) ~= "Features/"
        then
            globalOverrides[relative] = true
        end
    end
end

loadGDHScripts("Script/Default - All games/", "Global", globalOverrides)

if mapFolder then
    if loadGDHScripts(mapFolder, "Map") == 0 then
        warn("[GDH] No scripts found in " .. mapFolder)
    end
end

return UI
