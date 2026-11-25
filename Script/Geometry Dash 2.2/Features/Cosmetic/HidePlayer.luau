local Players = game:GetService("Players")

local HidePlayer = {}
local enabled = false
local watched = {}
local guiConn = nil

local function matches(instance: Instance): boolean
    local fullName = instance:GetFullName()
    if fullName:find("GDH", 1, true) then
        return false
    end
    local parent = instance.Parent
    return parent ~= nil
        and parent.Name == "Players"
        and instance.Name:match("^Player_%d+$") ~= nil
        and fullName:find("GDWorld", 1, true) ~= nil
end

local function watch(instance)
    if watched[instance] then
        return
    end
    watched[instance] = {
        visible = instance.Visible,
        conn = instance:GetPropertyChangedSignal("Visible"):Connect(function()
            if enabled and instance.Visible then
                instance.Visible = false
            end
        end),
    }
    instance.Visible = false
end

local function scan(playerGui)
    for _, instance in ipairs(playerGui:GetDescendants()) do
        if instance:IsA("GuiObject") and matches(instance) then
            watch(instance)
        end
    end
end

local function apply()
    local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        return
    end
    if enabled then
        scan(playerGui)
        if not guiConn then
            guiConn = playerGui.DescendantAdded:Connect(function(instance)
                if instance:IsA("GuiObject") and matches(instance) then
                    watch(instance)
                end
            end)
        end
    else
        if guiConn then
            guiConn:Disconnect()
            guiConn = nil
        end
        for instance, data in pairs(watched) do
            data.conn:Disconnect()
            pcall(function()
                instance.Visible = data.visible
            end)
        end
        table.clear(watched)
    end
end

function HidePlayer.Set(state)
    enabled = state == true
    apply()
end

function HidePlayer.IsEnabled()
    return enabled
end

function HidePlayer.Setup(window)
    window:AddToggle({
        Name = "Hide Player",
        Default = false,
        Description = "Hide the player icon",
        Callback = function(state)
            HidePlayer.Set(state)
        end,
    })
end

return HidePlayer
