local HttpService = game:GetService("HttpService")

local Save: any = {}

local SAVE_EXTENSION = ".json"
local COMMIT_DELAY = 0.4

local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local function importSibling(name: string): any
    local Import = genv.Import
    if Import then
        local module = Import("Function/" .. name)
        if module ~= nil then
            return module
        end
    end
    return require(script.Parent[name])
end

local Storage = importSibling("Storage")

local SCALAR_SECTIONS: { [string]: string } = {
    Toggles = "boolean",
    Sliders = "number",
    Radios = "boolean",
    Dropdowns = "string",
    Inputs = "number",
    Texts = "string",
}

local stores: { [string]: any } = {
    Global = {
        Scope = "Global",
        Subpath = "",
        FileName = "Global" .. SAVE_EXTENSION,
        FsDir = "GDH",
    },
    Map = {
        Scope = "Map",
        Subpath = "Saves",
        FileName = tostring(game.PlaceId) .. SAVE_EXTENSION,
        FsDir = "GDH/Saves",
    },
}

local function storeOf(scope: any): any
    if scope == "Global" then
        return stores.Global
    end
    return stores.Map
end

local function blankData(): { any }
    local data: { any } = {
        Place = {
            Id = game.PlaceId,
            Name = game.Name,
        },
        Keybinds = {
            Hacks = {},
            Actions = {},
            ToggleUI = nil,
            Custom = {},
        },
    }
    for section in SCALAR_SECTIONS do
        data[section] = {}
    end
    return data
end

local storeData: { [string]: { any } } = {}
local dataReady = false
local commitToken = 0

local function decodeJson(text: string): any?
    if typeof(text) ~= "string" or text == "" then
        return nil
    end
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(text)
    end)
    if ok and typeof(decoded) == "table" then
        return decoded
    end
    return nil
end

local function readStoredText(store: any): string?
    if typeof(Storage) == "table" and typeof(Storage.Read) == "function" then
        local ok, text = pcall(function()
            return Storage:Read(store.Subpath, store.FileName)
        end)
        if ok and typeof(text) == "string" and text ~= "" then
            return text :: string
        end
    end
    if typeof(readfile) == "function" and typeof(isfile) == "function" then
        local filePath = store.FsDir .. "/" .. store.FileName
        local okIs, exists = pcall(function()
            return (isfile :: any)(filePath)
        end)
        if okIs and exists == true then
            local okRead, content = pcall(readfile, filePath)
            if okRead and typeof(content) == "string" then
                return content
            end
        end
    end
    return nil
end

local function normalizeBind(value: any): any?
    if typeof(value) ~= "table" then
        return nil
    end
    local key = (value :: { any }).Key
    if typeof(key) ~= "EnumItem" then
        return nil
    end
    local mods: { string } = {}
    local rawMods = (value :: { any }).Mods
    if typeof(rawMods) == "table" then
        for _, mod in rawMods :: { any } do
            if typeof(mod) == "string" and mod ~= "" then
                table.insert(mods, mod :: string)
            end
        end
    end
    return { Key = key :: Enum.KeyCode, Mods = mods }
end

local function bindFromJson(value: any): any?
    if typeof(value) ~= "table" then
        return nil
    end
    local keyName = (value :: { any }).Key
    if typeof(keyName) ~= "string" or keyName == "" then
        return nil
    end
    local keyCode: any = nil
    pcall(function()
        keyCode = Enum.KeyCode[keyName :: string]
    end)
    if keyCode == nil then
        return nil
    end
    return normalizeBind({ Key = keyCode, Mods = (value :: { any }).Mods })
end

local function bindToJson(value: any): any?
    if typeof(value) ~= "table" then
        return nil
    end
    local key = (value :: { any }).Key
    if typeof(key) ~= "EnumItem" then
        return nil
    end
    local mods: { string } = {}
    local rawMods = (value :: { any }).Mods
    if typeof(rawMods) == "table" then
        for _, mod in rawMods :: { any } do
            if typeof(mod) == "string" and mod ~= "" then
                table.insert(mods, mod :: string)
            end
        end
    end
    return { Key = (key :: EnumItem).Name, Mods = mods }
end

local function loadData(store: any)
    local data = storeData[store.Scope]
    local text = readStoredText(store)
    if text == nil then
        return
    end
    local loaded = decodeJson(text :: string)
    if loaded == nil then
        return
    end
    for section, wantType in SCALAR_SECTIONS do
        local sectionData = loaded[section]
        if typeof(sectionData) == "table" then
            for key, value in sectionData :: { any } do
                if typeof(key) == "string" and typeof(value) == wantType then
                    data[section][key] = value
                end
            end
        end
    end
    local keybinds = loaded.Keybinds
    if typeof(keybinds) ~= "table" then
        return
    end
    local hacks = (keybinds :: { any }).Hacks
    if typeof(hacks) == "table" then
        for key, bind in hacks :: { any } do
            if typeof(key) == "string" then
                local clean = bindFromJson(bind)
                if clean ~= nil then
                    data.Keybinds.Hacks[key] = clean
                end
            end
        end
    end
    local actions = (keybinds :: { any }).Actions
    if typeof(actions) == "table" then
        for key, bind in actions :: { any } do
            if typeof(key) == "string" then
                local clean = bindFromJson(bind)
                if clean ~= nil then
                    data.Keybinds.Actions[key] = clean
                end
            end
        end
    end
    local custom = (keybinds :: { any }).Custom
    if typeof(custom) == "table" then
        for key, bind in custom :: { any } do
            if typeof(key) == "string" then
                local clean = bindFromJson(bind)
                if clean ~= nil then
                    data.Keybinds.Custom[key] = clean
                end
            end
        end
    end
    local cleanUI = bindFromJson((keybinds :: { any }).ToggleUI)
    if cleanUI ~= nil then
        data.Keybinds.ToggleUI = cleanUI
    end
end

for _, store in stores do
    storeData[store.Scope] = blankData()
end
for _, store in stores do
    loadData(store)
end
dataReady = true

local function ensureFsDirectory(fsDir: string)
    if typeof(makefolder) ~= "function" or typeof(isfolder) ~= "function" then
        return
    end
    local parts = string.split(fsDir, "/")
    local current = ""
    for _, part in parts do
        current = if current == "" then part else current .. "/" .. part
        local okIs, isDir = pcall(function()
            return (isfolder :: any)(current)
        end)
        if not okIs or isDir ~= true then
            pcall(makefolder, current)
        end
    end
end

local function commitStore(store: any)
    local data = storeData[store.Scope]
    local payload: { any } = {
        Place = {
            Id = game.PlaceId,
            Name = game.Name,
        },
    }
    for section, wantType in SCALAR_SECTIONS do
        local out: { any } = {}
        for key, value in data[section] :: { any } do
            if typeof(key) == "string" and typeof(value) == wantType then
                out[key] = value
            end
        end
        payload[section] = out
    end
    local binds: { any } = {
        Hacks = {},
        Actions = {},
        ToggleUI = nil,
        Custom = {},
    }
    for key, bind in data.Keybinds.Hacks :: { any } do
        local clean = bindToJson(bind)
        if typeof(key) == "string" and clean ~= nil then
            binds.Hacks[key] = clean
        end
    end
    for key, bind in data.Keybinds.Actions :: { any } do
        local clean = bindToJson(bind)
        if typeof(key) == "string" and clean ~= nil then
            binds.Actions[key] = clean
        end
    end
    for key, bind in data.Keybinds.Custom :: { any } do
        local clean = bindToJson(bind)
        if typeof(key) == "string" and clean ~= nil then
            binds.Custom[key] = clean
        end
    end
    binds.ToggleUI = bindToJson(data.Keybinds.ToggleUI)
    payload.Keybinds = binds
    local okEncode, text = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if not okEncode or typeof(text) ~= "string" then
        return
    end
    if typeof(Storage) == "table" and typeof(Storage.Write) == "function" then
        pcall(function()
            Storage:Write(store.Subpath, store.FileName, text :: string)
        end)
    end
    if typeof(writefile) == "function" then
        ensureFsDirectory(store.FsDir)
        pcall(writefile, store.FsDir .. "/" .. store.FileName, text :: string)
    end
end

local function commitAll()
    if not dataReady then
        return
    end
    for _, store in stores do
        commitStore(store)
    end
end

local function scheduleCommit()
    if not dataReady then
        return
    end
    commitToken += 1
    local token = commitToken
    task.delay(COMMIT_DELAY, function()
        if token ~= commitToken then
            return
        end
        commitAll()
    end)
end

local function sectionOf(scope: any, section: string): { any }
    local data = storeData[storeOf(scope).Scope]
    local target = data[section]
    if typeof(target) ~= "table" then
        return {}
    end
    return target :: { any }
end

local function setScalar(scope: any, section: string, key: any, value: any)
    if typeof(key) ~= "string" or key == "" then
        return
    end
    sectionOf(scope, section)[key] = value
    scheduleCommit()
end

local function scalarOf(scope: any, section: string, key: any): any
    if typeof(key) ~= "string" then
        return nil
    end
    return sectionOf(scope, section)[key]
end

local function bindsOf(scope: any): { any }
    local data = storeData[storeOf(scope).Scope]
    return data.Keybinds :: { any }
end

function Save.SetToggle(key: string, state: boolean, scope: any?)
    setScalar(scope, "Toggles", key, state == true)
end

function Save.ToggleState(key: string, scope: any?): boolean?
    local value = scalarOf(scope, "Toggles", key)
    if typeof(value) ~= "boolean" then
        return nil
    end
    return value :: boolean
end

function Save.SetSlider(key: string, value: number, scope: any?)
    if typeof(value) ~= "number" then
        return
    end
    setScalar(scope, "Sliders", key, value)
end

function Save.SliderValue(key: string, scope: any?): number?
    local value = scalarOf(scope, "Sliders", key)
    if typeof(value) ~= "number" then
        return nil
    end
    return value :: number
end

function Save.SetRadio(key: string, active: boolean, scope: any?)
    setScalar(scope, "Radios", key, active == true)
end

function Save.RadioActive(key: string, scope: any?): boolean?
    local value = scalarOf(scope, "Radios", key)
    if typeof(value) ~= "boolean" then
        return nil
    end
    return value :: boolean
end

function Save.SetDropdown(key: string, value: any, scope: any?)
    if typeof(value) ~= "string" then
        return
    end
    setScalar(scope, "Dropdowns", key, value)
end

function Save.DropdownValue(key: string, scope: any?): string?
    local value = scalarOf(scope, "Dropdowns", key)
    if typeof(value) ~= "string" then
        return nil
    end
    return value :: string
end

function Save.SetInput(key: string, value: number, scope: any?)
    if typeof(value) ~= "number" then
        return
    end
    setScalar(scope, "Inputs", key, value)
end

function Save.InputValue(key: string, scope: any?): number?
    local value = scalarOf(scope, "Inputs", key)
    if typeof(value) ~= "number" then
        return nil
    end
    return value :: number
end

function Save.SetText(key: string, value: any, scope: any?)
    if typeof(value) ~= "string" then
        return
    end
    setScalar(scope, "Texts", key, value)
end

function Save.TextValue(key: string, scope: any?): string?
    local value = scalarOf(scope, "Texts", key)
    if typeof(value) ~= "string" then
        return nil
    end
    return value :: string
end

function Save.SetHackBind(key: string, bind: any?, scope: any?)
    if typeof(key) ~= "string" or key == "" then
        return
    end
    bindsOf(scope).Hacks[key] = normalizeBind(bind)
    scheduleCommit()
end

function Save.HackBind(key: string, scope: any?): any?
    if typeof(key) ~= "string" then
        return nil
    end
    return normalizeBind(bindsOf(scope).Hacks[key])
end

function Save.AllHackBinds(): { [string]: any }
    local out: { [string]: any } = {}
    for _, store in stores do
        local perScope: { [string]: any } = {}
        for key, bind in storeData[store.Scope].Keybinds.Hacks :: { any } do
            if typeof(key) == "string" then
                local clean = normalizeBind(bind)
                if clean ~= nil then
                    perScope[key] = clean
                end
            end
        end
        out[store.Scope] = perScope
    end
    return out
end

function Save.SetActionBind(key: string, bind: any?, scope: any?)
    if typeof(key) ~= "string" or key == "" then
        return
    end
    bindsOf(scope).Actions[key] = normalizeBind(bind)
    scheduleCommit()
end

function Save.ActionBind(key: string, scope: any?): any?
    if typeof(key) ~= "string" then
        return nil
    end
    return normalizeBind(bindsOf(scope).Actions[key])
end

function Save.AllActionBinds(scope: any?): { [string]: any }
    local out: { [string]: any } = {}
    for key, bind in bindsOf(scope).Actions :: { any } do
        if typeof(key) == "string" then
            local clean = normalizeBind(bind)
            if clean ~= nil then
                out[key] = clean
            end
        end
    end
    return out
end

function Save.SetToggleUIBind(bind: any?, scope: any?)
    bindsOf(scope).ToggleUI = normalizeBind(bind)
    scheduleCommit()
end

function Save.ToggleUIBind(scope: any?): any?
    return normalizeBind(bindsOf(scope).ToggleUI)
end

function Save.SetCustomBind(key: string, bind: any?, scope: any?)
    if typeof(key) ~= "string" or key == "" then
        return
    end
    bindsOf(scope).Custom[key] = normalizeBind(bind)
    scheduleCommit()
end

function Save.CustomBind(key: string, scope: any?): any?
    if typeof(key) ~= "string" then
        return nil
    end
    return normalizeBind(bindsOf(scope).Custom[key])
end

genv.GDH_Save = Save

return Save
