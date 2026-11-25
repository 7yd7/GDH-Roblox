local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local UI = genv.GDH_UI
if typeof(UI) ~= "table" then
    return
end

local Theme = UI.Theme
local Widget = UI.Widget
local RunService = game:GetService("RunService")

local function S(n: number): number
    return math.floor(n * (Theme.ScreenScale or 1) + 0.5)
end

local settingsWindow = UI:CreateWindow({
    Title = "GDH Settings",
    Order = 9999,
    Keybindable = false,
    Size = UDim2.fromOffset(S(235), S(290)),
    ZIndex = 2,
    AutoHeight = true,
})

local searchRow = settingsWindow:AddInputRow({
    Hint = "Search",
})

local settingsWin = settingsWindow._window

local function contentRows(win): { Instance }
    local content = win:GetContentFrame()
    local rows: { Instance } = {}
    if not content then
        return rows
    end
    for _, rowChild in content:GetChildren() do
        if rowChild:IsA("GuiObject") then
            table.insert(rows, rowChild)
        end
    end
    table.sort(rows, function(a, b)
        return a.LayoutOrder < b.LayoutOrder
    end)
    return rows
end

local function rowHay(row): string
    local parts: { string } = { row.Name }
    local rowName = row:GetAttribute("WidgetName")
    if rowName ~= nil then
        table.insert(parts, tostring(rowName))
    end
    for _, descendant in row:GetDescendants() do
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
            local descendantText = descendant.Text
            if descendantText ~= nil and descendantText ~= "" then
                table.insert(parts, descendantText)
            end
        elseif descendant:IsA("TextBox") then
            local descendantPlaceholder = descendant.PlaceholderText
            if descendantPlaceholder ~= nil and descendantPlaceholder ~= "" then
                table.insert(parts, descendantPlaceholder)
            end
        end
    end
    return string.lower(table.concat(parts, " "))
end

local alphaValues = setmetatable({}, { __mode = "k" })
local alphaTargets = setmetatable({}, { __mode = "k" })
local alphaBases = setmetatable({}, { __mode = "k" })
local alphaConn = nil

local function captureAlphaBases(desc)
    if alphaBases[desc] ~= nil then
        return alphaBases[desc]
    end
    if UI._isAnimating then
        return nil
    end
    local bases = {}
    if desc:IsA("GuiObject") then
        local attrBG = desc:GetAttribute("_baseBG")
        local rawBG = if attrBG ~= nil then attrBG else desc.BackgroundTransparency
        bases.BG = math.min(rawBG, desc.BackgroundTransparency)
    end
    if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
        local attrText = desc:GetAttribute("_baseText")
        local rawText = if attrText ~= nil then attrText else desc.TextTransparency
        bases.Text = math.min(rawText, desc.TextTransparency)
    end
    if desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
        local attrImage = desc:GetAttribute("_baseImage")
        local rawImage = if attrImage ~= nil then attrImage else desc.ImageTransparency
        bases.Image = math.min(rawImage, desc.ImageTransparency)
    end
    if desc:IsA("UIStroke") then
        local attrStroke = desc:GetAttribute("_baseStroke")
        local rawStroke = if attrStroke ~= nil then attrStroke else desc.Transparency
        bases.Stroke = math.min(rawStroke, desc.Transparency)
    end
    alphaBases[desc] = bases
    return bases
end

local function paintAlphaOne(desc, alphaValue: number): boolean
    local bases = captureAlphaBases(desc)
    if bases == nil then
        return false
    end
    local alphaClamped = math.clamp(alphaValue, 0, 1)
    local inv = 1 - alphaClamped
    if desc:IsA("GuiObject") and bases.BG ~= nil then
        desc.BackgroundTransparency = bases.BG + (1 - bases.BG) * inv
    end
    if (desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox"))
        and bases.Text ~= nil
    then
        desc.TextTransparency = bases.Text + (1 - bases.Text) * inv
    end
    if (desc:IsA("ImageLabel") or desc:IsA("ImageButton")) and bases.Image ~= nil then
        desc.ImageTransparency = bases.Image + (1 - bases.Image) * inv
    end
    if desc:IsA("UIStroke") and bases.Stroke ~= nil then
        desc.Transparency = bases.Stroke + (1 - bases.Stroke) * inv
    end
    return true
end

local function paintAlpha(desc, alphaValue: number)
    paintAlphaOne(desc, alphaValue)
    for _, nested in desc:GetDescendants() do
        paintAlphaOne(nested, alphaValue)
    end
end

local function restoreAlphaOne(desc)
    local bases = alphaBases[desc]
    if bases == nil then
        return
    end
    if desc:IsA("GuiObject") and bases.BG ~= nil then
        desc.BackgroundTransparency = bases.BG
    end
    if (desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox"))
        and bases.Text ~= nil
    then
        desc.TextTransparency = bases.Text
    end
    if (desc:IsA("ImageLabel") or desc:IsA("ImageButton")) and bases.Image ~= nil then
        desc.ImageTransparency = bases.Image
    end
    if desc:IsA("UIStroke") and bases.Stroke ~= nil then
        desc.Transparency = bases.Stroke
    end
end

local function restoreAlpha(desc)
    restoreAlphaOne(desc)
    for _, nested in desc:GetDescendants() do
        restoreAlphaOne(nested)
    end
end

local function ensureAlphaLoop()
    if alphaConn ~= nil then
        return
    end
    local wasAnimating = false
    local conn: RBXScriptConnection
    conn = RunService.RenderStepped:Connect(function(dt: number)
        local speed = Theme.Animation.SearchHighlight or 16
        local busy = false
        if UI._isAnimating then
            wasAnimating = true
            busy = true
        else
            if wasAnimating then
                wasAnimating = false
                table.clear(alphaBases)
                table.clear(alphaValues)
            end
            for row, target in alphaTargets do
                local current = alphaValues[row] or 1
                local factor = math.clamp(math.min(dt, 0.033) * speed, 0, 1)
                local nextValue = current + (target - current) * factor
                local settled = math.abs(nextValue - target) < 0.004
                if settled then
                    nextValue = target
                end
                alphaValues[row] = nextValue
                local painted = paintAlpha(row, nextValue)
                if not settled or not painted then
                    busy = true
                end
            end
        end
        if not busy then
            alphaConn = nil
            conn:Disconnect()
        end
    end)
    alphaConn = conn
end

local function applyFilter(rawQuery: string)
    local query = string.lower(rawQuery or "")
    query = string.gsub(query, "^%s+", "")
    query = string.gsub(query, "%s+$", "")

    for _, win in ipairs(UI._windows or {}) do
        pcall(function()
            if win._popup or win == settingsWin then
                return
            end
            local winExcluded = win.Root ~= nil
                and win.Root:GetAttribute("GDHSearchExclude") == true
            for _, row in contentRows(win) do
                if winExcluded or row:GetAttribute("GDHNoSearch") == true then
                    alphaTargets[row] = 1
                elseif row ~= searchRow and query ~= "" then
                    local hay = rowHay(row)
                    if string.find(hay, query, 1, true) == nil then
                        alphaTargets[row] = 0.2
                    else
                        alphaTargets[row] = 1
                    end
                else
                    alphaTargets[row] = 1
                end
            end
        end)
    end
    ensureAlphaLoop()
end

local searchPill = nil
for _, pillChild in searchRow:GetChildren() do
    if pillChild:IsA("GuiObject")
        and string.sub(pillChild.Name, 1, 9) == "TextInput"
    then
        searchPill = pillChild
        break
    end
end
local searchField = if searchPill ~= nil then searchPill:FindFirstChild("Field") else nil
if searchField and searchField:IsA("TextBox") then
    searchField:GetPropertyChangedSignal("Text"):Connect(function()
        applyFilter(searchField.Text)
    end)
end

settingsWindow:AddSlider({
    Name = "Duration Anim",
    Suffix = "ms",
    Min = 0,
    Max = 500,
    Increment = 10,
    Precision = 0,
    Default = Theme.Animation.DurationMS or 100,
    Callback = function(value)
        Theme.SetAnimationDuration(value)
    end,
})

settingsWindow:AddToggle({
    Name = "Horizontal Center",
    Default = false,
    Callback = function(state)
        UI:SetHorizontalCenter(state)
    end,
})

settingsWindow:AddToggle({
    Name = "Notify about updates",
    Default = true,
    Callback = function(_state)
    end,
})

settingsWindow:AddButton({
    Text = "Show Cheat Hack List",
    Callback = function()
        if type(genv.GDH_Restart) == "function" then
            genv.GDH_Restart()
        end
    end,
})

settingsWindow:AddButton({
    Text = "Disable cheating hacks",
    Callback = function()
        if type(genv.GDH_Kill) == "function" then
            genv.GDH_Kill()
        end
    end,
})

settingsWindow:AddSeparator()

settingsWindow:AddButton({
    Text = "Refresh Layout",
    Callback = function()
        for _, win in ipairs(UI._windows or {}) do
            pcall(function()
                win:ResetLayout()
            end)
        end
        UI:RefreshAutoLayout()
        for row in alphaTargets do
            restoreAlpha(row)
        end
        if typeof(Widget) == "table" then
            pcall(function()
                Widget.CloseAllDropdowns()
            end)
        end
    end,
})

settingsWindow:AddButton({
    Text = "Theme Editor",
    Callback = function()
    end,
})
