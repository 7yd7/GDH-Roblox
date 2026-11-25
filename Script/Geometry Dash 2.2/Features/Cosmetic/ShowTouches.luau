local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local ShowTouches = {}
local enabled = false
local gui = nil
local marks = {}
local beganConn = nil
local endedConn = nil

local function ensureGui()
    if gui then
        return gui
    end
    local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        return nil
    end
    gui = Instance.new("ScreenGui")
    gui.Name = "GDH_ShowTouches"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 100
    gui.Parent = playerGui
    return gui
end

local function addMark(input)
    local screenGui = ensureGui()
    if not screenGui then
        return
    end
    if marks[input] then
        return
    end
    local position = input.Position
    local mark = Instance.new("Frame")
    mark.Size = UDim2.fromOffset(56, 56)
    mark.Position = UDim2.fromOffset(position.X, position.Y)
    mark.AnchorPoint = Vector2.new(0.5, 0.5)
    mark.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    mark.BackgroundTransparency = 0.45
    mark.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = mark
    mark.Parent = screenGui
    marks[input] = mark
end

local function removeMark(input)
    local mark = marks[input]
    if mark then
        pcall(function()
            mark:Destroy()
        end)
        marks[input] = nil
    end
end

local function onInputBegan(input, gameProcessed)
    if not enabled or gameProcessed then
        return
    end
    local inputType = input.UserInputType
    if inputType == Enum.UserInputType.Touch or inputType == Enum.UserInputType.MouseButton1 then
        addMark(input)
    end
end

local function onInputEnded(input)
    removeMark(input)
end

local function apply()
    if enabled then
        ensureGui()
        if not beganConn then
            beganConn = UserInputService.InputBegan:Connect(onInputBegan)
            endedConn = UserInputService.InputEnded:Connect(onInputEnded)
        end
    else
        if beganConn then
            beganConn:Disconnect()
            beganConn = nil
        end
        if endedConn then
            endedConn:Disconnect()
            endedConn = nil
        end
        for input in pairs(marks) do
            removeMark(input)
        end
        if gui then
            pcall(function()
                gui:Destroy()
            end)
            gui = nil
        end
    end
end

function ShowTouches.Set(state)
    enabled = state == true
    apply()
end

function ShowTouches.IsEnabled()
    return enabled
end

function ShowTouches.Setup(window)
    window:AddToggle({
        Name = "Show Touches",
        Default = false,
        Description = "Show a marker wherever you tap or click",
        Callback = function(state)
            ShowTouches.Set(state)
        end,
    })
end

return ShowTouches
