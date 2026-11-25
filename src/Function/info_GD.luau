local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local Import = genv.Import
if typeof(Import) == "function" then
    local ok, module = pcall(Import, "Function/Popup_GD")
    if ok and module ~= nil then
        return module
    end
end

local ok, module = pcall(function()
    return require(script.Parent.Popup_GD)
end)
if ok and module ~= nil then
    return module
end

error("[GDH] info_GD could not load Function/Popup_GD")
