local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local CheatIndicator = {}
local enabled = false
local gui = nil
local label = nil
local conn = nil
local elapsed = 0

local function collectNames()
    local root = CoreGui:FindFirstChild("GDH")
    local names = {}
    if root == nil then
        return names
    end
    local function scan(instance)
        pcall(function()
            for _, child in ipairs(instance:GetChildren()) do
                if child:GetAttribute("GDHToggleRow") == true
                    and child:GetAttribute("Cheating") == true
                    and child:GetAttribute("State") == true then
                    names[#names + 1] = tostring(child.Name)
                end
                scan(child)
            end
        end)
    end
    scan(root)
    table.sort(names)
    return names
end

local function update()
    if label == nil then
        return
    end
    local names = collectNames()
    if #names == 0 then
        label.Visible = false
        return
    end
    label.Text = "Cheats: " .. table.concat(names, ", ")
    label.Visible = true
end

local function stop()
    if conn then
        conn:Disconnect()
        conn = nil
    end
    if gui then
        pcall(function()
            gui:destroy()
        end)
        gui = nil
    end
    label = nil
end

local function start()
    if conn then
        return
    end
    local ok, screenGui, textLabel = pcall(function()
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "GDHCheatIndicator"
        screenGui.ResetOnSpawn = false
        screenGui.IgnoreGuiInset = true
        screenGui.Parent = CoreGui

        local textLabel = Instance.new("TextLabel")
        textLabel.Name = "CheatList"
        textLabel.AnchorPoint = Vector2.new(0.5, 0)
        textLabel.Position = UDim2.new(0.5, 0, 0, 4)
        textLabel.Size = UDim2.new(0, 460, 0, 22)
        textLabel.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
        textLabel.BackgroundTransparency = 0.2
        textLabel.BorderSizePixel = 0
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
        textLabel.TextSize = 14
        textLabel.TextXAlignment = Enum.TextXAlignment.Center
        textLabel.Visible = false
        textLabel.Parent = screenGui
        return screenGui, textLabel
    end)
    if not ok then
        return
    end
    gui, label = screenGui, textLabel
    conn = RunService.Heartbeat:Connect(function(dt)
        if not enabled then
            return
        end
        elapsed += dt
        if elapsed >= 0.2 then
            elapsed = 0
            update()
        end
    end)
    update()
end

function CheatIndicator.Set(state)
    enabled = state == true
    if enabled then
        start()
    else
        stop()
    end
end

function CheatIndicator.IsEnabled()
    return enabled
end

function CheatIndicator.Setup(window)
    window:AddToggle({
        Name = "Cheat Indicator",
        Default = false,
        Description = "Show a label listing active cheat toggles",
        Callback = function(state)
            CheatIndicator.Set(state)
        end,
    })
end

return CheatIndicator
