local function importWidget(name: string)
    local genv = (typeof(getgenv) == "function" and getgenv())
        or (typeof(_G) == "table" and _G)
        or {}
    local Import = genv.Import
    if Import then
        local module = Import("interface/Pc/Widgets/" .. name)
        if module ~= nil then
            return module
        end
    end
    local parent = script.Parent
    if parent:FindFirstChild("Widgets") then
        return require(parent.Widgets[name])
    end
    return require(script.Widgets[name])
end

local DropdownModule = importWidget("Dropdown")

local Widget = {
    measureTextWidth = importWidget("Measure"),
    Toggle = importWidget("Toggle"),
    Button = importWidget("Button"),
    ShowButton = importWidget("ShowButton"),
    Separator = importWidget("Separator"),
    Label = importWidget("Label"),
    IntInput = importWidget("IntInput"),
    FloatInput = importWidget("FloatInput"),
    Slider = importWidget("Slider"),
    Padding = importWidget("Padding"),
    Keybind = importWidget("Keybind"),
    TextInput = importWidget("TextInput"),
    ArrowButton = importWidget("ArrowButton"),
    RadioButton = importWidget("RadioButton"),
    Dropdown = DropdownModule.Dropdown,
    CloseAllDropdowns = DropdownModule.CloseAllDropdowns,
    Popup = importWidget("Popup"),
}

return Widget
