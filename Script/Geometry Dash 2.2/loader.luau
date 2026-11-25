local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local UI = genv.GDH_UI
if typeof(UI) ~= "table" then
    return
end

local modules = genv.GDH_MODULES
if typeof(modules) ~= "table" then
    return
end

local FEATURES = "Script/Geometry Dash 2.2/Features/"

local WINDOW_ORDER = {
    Core = 1,
    Bypass = "1-1",
    Cosmetic = 2,
    Level = 3
}

local folders = {}
for key in pairs(modules) do
    if key:sub(1, #FEATURES) == FEATURES then
        local name = key:sub(#FEATURES + 1):match("^([^/]+)/")
        if name and name ~= "" then
            folders[name] = true
        end
    end
end

local names = {}
for name in pairs(folders) do
    names[#names + 1] = name
end
table.sort(names)

local scale = UI.Theme and UI.Theme.ScreenScale or 1
local function px(n: number): number
    return math.floor(n * scale + 0.5)
end

for index, name in ipairs(names) do
    local prefix = FEATURES .. name .. "/"
    local order = WINDOW_ORDER[name] or (10 + index)
    local window = UI:CreateWindow({
        Title = name,
        Order = order,
        Size = UDim2.fromOffset(px(210), px(120)),
        AutoHeight = true,
    })

    local files = {}
    for key in pairs(modules) do
        if key:sub(1, #prefix) == prefix and key:sub(-5) == ".luau" then
            local relative = key:sub(#prefix + 1)
            if not relative:find("/") then
                files[#files + 1] = key
            end
        end
    end
    table.sort(files)

    for _, key in ipairs(files) do
        local ok, feature = pcall(modules[key])
        if ok then
            if typeof(feature) == "table" and typeof(feature.Setup) == "function" then
                pcall(feature.Setup, window)
            end
        else
            warn("[GDH] " .. key .. ": " .. tostring(feature))
        end
    end
end

local MAP_PREFIX = "Script/Geometry Dash 2.2/"
local LOADER_KEY = MAP_PREFIX .. "loader.luau"

for key in pairs(modules) do
    local isMapScript = key:sub(1, #MAP_PREFIX) == MAP_PREFIX
        and key:sub(-5) == ".luau"
        and key:sub(1, #FEATURES) ~= FEATURES
        and key ~= LOADER_KEY
    if isMapScript then
        task.spawn(function()
            local ok, err = pcall(modules[key])
            if not ok then
                warn("[GDH] " .. key .. ": " .. tostring(err))
            end
        end)
    end
end
