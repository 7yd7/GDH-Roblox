local RunService = game:GetService("RunService")

local ShowHitboxes = {}
local enabled = false
local boxes = nil
local currentGui = nil
local drawConn = nil
local originalMenu = nil
local originalHitboxes = nil

local function getRuntime()
    local ok, mod = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local rt = port and port:FindFirstChild("ClientRuntime")
        return rt and require(rt) or nil
    end)
    if ok and type(mod) == "table" then
        return mod
    end
    return nil
end

local function clearBoxes()
    if boxes then
        pcall(function()
            boxes:destroy()
        end)
        boxes = nil
    end
    currentGui = nil
end

local function stopDrawing()
    if drawConn then
        drawConn:Disconnect()
        drawConn = nil
    end
    clearBoxes()
end

local function startDrawing()
    if drawConn then
        return
    end
    drawConn = RunService.RenderStepped:Connect(function()
        if not enabled then
            return
        end
        local runtime = getRuntime()
        local hacks = runtime and runtime.hacks
        local layer = hacks and hacks.o and hacks.o.layer and hacks.o.layer()
        local renderer = hacks and hacks.o and hacks.o.renderer and hacks.o.renderer()
        local gui = renderer and renderer._worldGui
        if not layer or not renderer or not gui then
            return
        end

        if gui ~= currentGui then
            clearBoxes()
            local ok, mod = pcall(function()
                local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
                return port and require(port.HackHitboxes) or nil
            end)
            if ok and type(mod) == "table" and type(mod.new) == "function" then
                local okBox, created = pcall(mod.new, gui)
                if okBox then
                    boxes = created
                    currentGui = gui
                end
            end
        end

        if boxes then
            pcall(function()
                boxes:draw(layer, renderer)
            end)
        end
    end)
end

local function apply()
    local runtime = getRuntime()
    local hacks = runtime and runtime.hacks
    if type(hacks) ~= "table" then
        return
    end

    if enabled then
        if originalMenu == nil and type(hacks.owned) == "table" then
            originalMenu = hacks.owned.menu
            originalHitboxes = hacks.owned.hitboxes
        end
        if type(hacks.owned) == "table" then
            hacks.owned.menu = true
            hacks.owned.hitboxes = true
        end
        pcall(function()
            hacks:setHitboxes(true)
        end)
        startDrawing()
    else
        stopDrawing()
        pcall(function()
            hacks:setHitboxes(false)
        end)
        if originalMenu ~= nil and type(hacks.owned) == "table" then
            hacks.owned.menu = originalMenu
            hacks.owned.hitboxes = originalHitboxes
            originalMenu, originalHitboxes = nil, nil
        end
    end
end

function ShowHitboxes.Set(state)
    enabled = state == true
    apply()
end

function ShowHitboxes.IsEnabled()
    return enabled
end

function ShowHitboxes.Setup(window)
    window:AddToggle({
        Name = "Show Hitboxes",
        Default = false,
        Description = "Draw player and object hitboxes",
        Callback = function(state)
            ShowHitboxes.Set(state)
        end,
    })
end

return ShowHitboxes
