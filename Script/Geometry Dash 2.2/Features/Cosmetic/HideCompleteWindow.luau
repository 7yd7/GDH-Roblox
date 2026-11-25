local Players = game:GetService("Players")

local HideCompleteWindow = {}
local enabled = false
local watched = {}
local guiConn = nil

local function matches(instance: Instance): boolean
    local fullName = instance:GetFullName()
    if fullName:find("GDH", 1, true) then
        return false
    end
    return instance.Name == "EndSequence_screen" and fullName:find("GDWorld", 1, true) ~= nil
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

local function apply()
    local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        return
    end
    if enabled then
        for _, instance in ipairs(playerGui:GetDescendants()) do
            if instance:IsA("GuiObject") and matches(instance) then
                watch(instance)
            end
        end
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

function HideCompleteWindow.Set(state)
    enabled = state == true
    apply()
end

function HideCompleteWindow.IsEnabled()
    return enabled
end

function HideCompleteWindow.Setup(window)
    window:AddToggle({
        Name = "Hide Complete Window",
        Default = false,
        Description = "Hide the level complete window",
        Callback = function(state)
            HideCompleteWindow.Set(state)
        end,
    })
end

return HideCompleteWindow
