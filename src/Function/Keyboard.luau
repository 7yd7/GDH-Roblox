local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")

local Keyboard = {}

local attached = setmetatable({}, { __mode = "k" })
local wanted: TextBox? = nil
local wantedUntil = 0
local inputConn: RBXScriptConnection? = nil
local renderConn: RBXScriptConnection? = nil

local function safe(getter: () -> any): any
    local ok, value = pcall(getter)
    if ok then
        return value
    end
    return nil
end

local function devConsoleOpen(): boolean
    return safe(function()
        return StarterGui:GetCore("DevConsoleVisible")
    end) == true
end

local function isFocusTrap(box: any?): boolean
    if typeof(box) ~= "Instance" or not (box :: Instance):IsA("TextBox") then
        return false
    end
    local textBox = box :: TextBox
    if safe(function() return textBox.TextEditable end) == false then
        return true
    end
    if safe(function() return textBox.Visible end) == false then
        return true
    end
    local size = safe(function() return textBox.AbsoluteSize end)
    if typeof(size) == "Vector2" and size.X <= 4 and size.Y <= 4 then
        return true
    end
    return false
end

function Keyboard.IsTyping(): boolean
    if GuiService.MenuIsOpen or devConsoleOpen() then
        return false
    end
    local focused = safe(function()
        return UserInputService:GetFocusedTextBox()
    end)
    if isFocusTrap(focused) then
        return false
    end
    return focused ~= nil
end

function Keyboard.ReleaseTraps(): ()
    if wanted ~= nil and os.clock() < wantedUntil then
        return
    end
    local focused = safe(function()
        return UserInputService:GetFocusedTextBox()
    end)
    if isFocusTrap(focused) then
        pcall(function()
            (focused :: TextBox):ReleaseFocus()
        end)
    end
end

local function contains(box: TextBox, position: Vector3): boolean
    local ok, inside = pcall(function()
        if box.Visible == false then
            return false
        end
        local abs = box.AbsolutePosition
        local size = box.AbsoluteSize
        return position.X >= abs.X and position.X <= abs.X + size.X
            and position.Y >= abs.Y and position.Y <= abs.Y + size.Y
    end)
    return ok and inside == true
end

local function hitTest(position: Vector3): TextBox?
    local hit: TextBox? = nil
    for box in pairs(attached) do
        if contains(box, position) then
            hit = box
        end
    end
    return hit
end

local function focusTarget(target: TextBox): ()
    wanted = target
    wantedUntil = os.clock() + 4
    task.defer(function()
        if wanted ~= target then
            return
        end
        if GuiService.MenuIsOpen or devConsoleOpen() then
            return
        end
        local focused = safe(function()
            return UserInputService:GetFocusedTextBox()
        end)
        if focused == target then
            return
        end
        if focused ~= nil and not isFocusTrap(focused) then
            wanted = nil
            return
        end
        pcall(function()
            target:CaptureFocus()
        end)
    end)
end

local function claim(): ()
    local target = wanted
    if target == nil then
        return
    end
    if os.clock() > wantedUntil or target.Parent == nil or target.Visible == false then
        wanted = nil
        return
    end
    local focused = safe(function()
        return UserInputService:GetFocusedTextBox()
    end)
    if focused == target then
        return
    end
    if focused ~= nil and not isFocusTrap(focused) then
        wanted = nil
        return
    end
    if GuiService.MenuIsOpen or devConsoleOpen() then
        return
    end
    pcall(function()
        target:CaptureFocus()
    end)
end

local function onInput(input: InputObject): ()
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch
    then
        return
    end
    local hit = hitTest(input.Position)
    if hit ~= nil then
        focusTarget(hit)
    elseif wanted ~= nil and not contains(wanted, input.Position) then
        wanted = nil
    end
end

function Keyboard.AttachTextBox(box: any): ()
    if typeof(box) ~= "Instance" or not (box :: Instance):IsA("TextBox") then
        return
    end
    local textBox = box :: TextBox
    if attached[textBox] then
        return
    end
    attached[textBox] = true

    pcall(function()
        textBox.Selectable = true
        textBox.TextEditable = true
    end)

    textBox.InputBegan:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            focusTarget(textBox)
        end
    end)

    textBox.FocusLost:Connect(function(enterPressed: boolean)
        if enterPressed and wanted == textBox then
            wanted = nil
        end
    end)

    textBox.Destroying:Connect(function()
        if wanted == textBox then
            wanted = nil
        end
    end)
end

function Keyboard.Protect(root: Instance): ()
    if typeof(root) ~= "Instance" then
        return
    end
    for _, desc in ipairs((root :: Instance):GetDescendants()) do
        if desc:IsA("TextBox") then
            Keyboard.AttachTextBox(desc)
        end
    end
    (root :: Instance).DescendantAdded:Connect(function(desc: Instance)
        if desc:IsA("TextBox") then
            Keyboard.AttachTextBox(desc)
        end
    end)
end

if inputConn == nil then
    inputConn = UserInputService.InputBegan:Connect(onInput)
end
if renderConn == nil then
    renderConn = RunService.RenderStepped:Connect(claim)
end

local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}
genv.GDH_Keyboard = Keyboard

return Keyboard
