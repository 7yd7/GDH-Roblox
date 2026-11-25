local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local UI = genv.GDH_UI
if typeof(UI) ~= "table" then
    return
end

local Theme = UI.Theme

local function S(n: number): number
    return math.floor(n * (Theme.ScreenScale or 1) + 0.5)
end

local coreWindow = UI:CreateWindow({
    Title = "Core",
    Order = 1,
    Size = UDim2.fromOffset(S(202), S(305)),
    AutoHeight = true,
})

local testToggles = {
    { Name = "Discord RPC", Description = "Status" },
    { Name = "Free Window Resize", Description = "Window resizing" },
    { Name = "No Death Effect" },
    { Name = "No Respawn Blink", Description = "No blink" },
    { Name = "No Transition Old" },
    { Name = "Noclip", Cheating = true, Description = "Disables player collision with all obstacles, spikes, and hazards in the level", Settings = {
        { Kind = "Toggle", Text = "Tint On Death", Key = "tint_on_death", Default = false },
        { Kind = "Color", Text = "Tint Color", Key = "tint_color", Default = Color3.fromRGB(255, 0, 0) },
        { Kind = "Int", Text = "Opacity", Key = "tint_opacity", Min = 0, Max = 255, Default = 100 },
        { Kind = "Float", Text = "Fade Speed", Key = "tint_fade", Min = 0, Max = 1, Default = 0.35 },
        { Kind = "Separator" },
        { Kind = "Toggle", Text = "Player 1", Key = "p1", Default = true },
        { Kind = "Toggle", Text = "Player 2", Key = "p2", Default = true },
        { Kind = "Separator" },
        { Kind = "Toggle", Text = "Limit Accuracy", Key = "limit_acc", Default = false },
        { Kind = "Float", Text = "Min Accuracy %", Key = "limit_acc_val", Min = 0, Max = 100, Default = 80 },
        { Kind = "Separator" },
        { Kind = "Toggle", Text = "Limit Deaths", Key = "limit_deaths", Default = false },
        { Kind = "Int", Text = "Max Deaths", Key = "limit_deaths_val", Min = 0, Max = 100, Default = 5 },
    } },
    { Name = "Practice Music", Description = "Normal song" },
    { Name = "Safe Mode" },
    { Name = "Unlock Icons" },
}

for _, toggleInfo in testToggles do
    coreWindow:AddToggle({
        Name = toggleInfo.Name,
        Cheating = toggleInfo.Cheating,
        Default = false,
        Description = toggleInfo.Description,
        Settings = toggleInfo.Settings,
        Callback = function(state)
            print(toggleInfo.Name .. ":", state)
        end,
    })
end
