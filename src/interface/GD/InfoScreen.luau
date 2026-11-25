--!strict

local Players = game:GetService("Players")

local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local Import = genv.Import
if not Import then return {} end

local InfoScreen = {}

function InfoScreen.Show(config: any?)
    local popup = Import("Function/Popup_GD")
    if typeof(popup) ~= "table" or typeof(popup.Show) ~= "function" then
        return nil
    end

    local cfg = if typeof(config) == "table" then config else {}
    local preset = {
        Name = "GDH_InfoScreen",
        Title = "Info",
        ButtonText = "OK",
        Width = 0.34,
        Height = 0.40,
        Dim = 0.41,
    }
    for k, v in pairs(cfg) do
        preset[k] = v
    end
    if typeof(preset.Body) ~= "string" then
        local toggleKeyName = "G"
        local lib = genv.GDH_UI
        if lib and lib._toggleKey then
            toggleKeyName = string.upper(lib._toggleKey.Name)
        end
        preset.Body = string.format(
            'Press <font color="#66FF66"><b>"%s"</b></font> to open\nthe GDH interface.',
            toggleKeyName
        )
    end

    return popup.Show(preset)
end

function InfoScreen.ShowOnce(config: any?)
    local shown = false
    if typeof(isfile) == "function" and typeof(readfile) == "function" then
        pcall(function()
            if isfile("GDH/info_shown.txt") then
                shown = true
            end
        end)
    end
    if shown then return nil end

    local screen = InfoScreen.Show(config)

    if typeof(writefile) == "function" and typeof(isfolder) == "function" and typeof(makefolder) == "function" then
        pcall(function()
            if not isfolder("GDH") then makefolder("GDH") end
            writefile("GDH/info_shown.txt", "1")
        end)
    end

    return screen
end

return InfoScreen
