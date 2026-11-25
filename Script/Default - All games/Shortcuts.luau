local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local UI = genv.GDH_UI
if typeof(UI) ~= "table" then
    return
end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Theme = UI.Theme

local function S(n: number): number
    return math.floor(n * (Theme.ScreenScale or 1) + 0.5)
end

local function notify(text: string, duration: number?)
    local current = genv.GDH_UI
    if typeof(current) == "table" and typeof(current.Notify) == "function" then
        current:Notify(text, duration)
    end
end

local function localPlayer(): Player?
    local player = Players.LocalPlayer
    if player ~= nil then
        return player
    end
    return nil
end

local function rejoin()
    task.spawn(function()
        local player = localPlayer()
        if player == nil then
            notify("Rejoin failed: player unavailable", 3)
            return
        end
        local ok, err = pcall(function()
            TeleportService:Teleport(game.PlaceId, player)
        end)
        if not ok then
            notify("Rejoin failed: " .. tostring(err), 4)
        end
    end)
end

local function serverHop()
    task.spawn(function()
        local player = localPlayer()
        if player == nil then
            notify("Server hop failed: player unavailable", 3)
            return
        end
        notify("Finding a new server...", 2)
        local ok, err = pcall(function()
            local url = string.format(
                "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
                game.PlaceId
            )
            local raw = game:HttpGet(url)
            if typeof(raw) ~= "string" or raw == "" then
                error("server list unavailable")
            end
            local decoded = HttpService:JSONDecode(raw)
            local servers = if typeof(decoded) == "table" then decoded.data else nil
            if typeof(servers) ~= "table" then
                error("server list unavailable")
            end
            local candidates = {}
            for _, server in servers do
                if typeof(server) == "table" and typeof(server.id) == "string"
                    and server.id ~= "" and server.id ~= game.JobId
                then
                    local playing = tonumber(server.playing)
                    local maxPlayers = tonumber(server.maxPlayers)
                    if playing ~= nil and maxPlayers ~= nil and playing < maxPlayers then
                        table.insert(candidates, server.id)
                    end
                end
            end
            if #candidates == 0 then
                error("no open servers found")
            end
            local pick = candidates[math.random(1, #candidates)]
            TeleportService:TeleportToPlaceInstance(game.PlaceId, pick, player)
        end)
        if not ok then
            notify("Server hop failed: " .. tostring(err), 4)
        end
    end)
end

local function openMobileUI()
    local toggle = genv.GDH_MOBILE_TOGGLE
    if typeof(toggle) ~= "function" then
        notify("Mobile UI is not available", 3)
        return
    end
    local ok, err = pcall(toggle)
    if not ok then
        notify("Mobile UI failed: " .. tostring(err), 4)
    end
end

local function resetCharacter()
    local player = localPlayer()
    local character = if player ~= nil then player.Character else nil
    local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
    if humanoid == nil then
        notify("Reset failed: character unavailable", 3)
        return
    end
    local ok, err = pcall(function()
        humanoid.Health = 0
    end)
    if not ok then
        notify("Reset failed: " .. tostring(err), 4)
    end
end

local function restartScript()
    local restart = genv.GDH_Restart
    if typeof(restart) ~= "function" then
        notify("Restart is not available", 3)
        return
    end
    notify("Restarting GDH...", 2)
    task.defer(restart)
end

local shortcutsWindow = UI:CreateWindow({
    Title = "Shortcuts",
    Order = 9998,
    AutoHeight = true,
    Searchable = false,
    Keybindable = false,
    Size = UDim2.fromOffset(S(202), S(170)),
})

shortcutsWindow:AddButton({
    Text = "Rejoin",
    Description = "Reconnect to the current game",
    Callback = rejoin,
})

shortcutsWindow:AddButton({
    Text = "Server Hop",
    Description = "Join a different public server",
    Callback = serverHop,
})

shortcutsWindow:AddButton({
    Text = "Reset Character",
    Description = "Reset your character",
    Callback = resetCharacter,
})

shortcutsWindow:AddButton({
    Text = "Open Mobile UI",
    Description = "Toggle the mobile interface",
    Callback = openMobileUI,
})

shortcutsWindow:AddButton({
    Text = "Restart Script",
    Description = "Restart the GDH UI and scripts",
    Callback = restartScript,
})

do
    local actions = genv.GDH_KeybindActions
    if typeof(actions) ~= "table" then
        actions = {}
        genv.GDH_KeybindActions = actions
    end

    local known: { [string]: boolean } = {}
    for _, action in actions do
        if typeof(action) == "table" and typeof(action.Id) == "string" then
            known[action.Id] = true
        end
    end

    local entries = {
        { Id = "Shortcuts::Rejoin", Name = "Rejoin", Callback = rejoin },
        { Id = "Shortcuts::ServerHop", Name = "Server Hop", Callback = serverHop },
        { Id = "Shortcuts::ResetCharacter", Name = "Reset Character", Callback = resetCharacter },
        { Id = "Shortcuts::MobileUI", Name = "Open Mobile UI", Callback = openMobileUI },
        { Id = "Shortcuts::Restart", Name = "Restart Script", Callback = restartScript },
    }
    for _, entry in entries do
        if known[entry.Id] ~= true then
            known[entry.Id] = true
            table.insert(actions, {
                Id = entry.Id,
                Module = "Shortcuts",
                Name = entry.Name,
                Default = nil,
                Callback = entry.Callback,
            })
        end
    end

    local sync = genv.GDH_KeybindActionsSync
    if typeof(sync) == "function" then
        sync()
    else
        task.defer(function()
            local deferredSync = genv.GDH_KeybindActionsSync
            if typeof(deferredSync) == "function" then
                deferredSync()
            end
        end)
    end
end
