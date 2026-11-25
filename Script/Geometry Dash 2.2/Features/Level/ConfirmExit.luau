local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local ConfirmExit = {}
local enabled = false
local original = nil

local function getRuntime()
    local ok, mod = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local rt = port and port:FindFirstChild("ClientRuntime")
        return rt and require(rt) or nil
    end)
    if ok and type(mod) == "table" then
        return mod
    end
    return nil
end

local function getView(runtime, create)
    local screens = runtime and runtime.MenuScreens
    local view = screens and screens.views and screens.views.options
    if view ~= nil and not view.destroyed and not view.closed then
        return view, false
    end
    if create and type(runtime.showOptions) == "function" then
        pcall(runtime.showOptions)
        view = screens and screens.views and screens.views.options
        if view ~= nil and not view.destroyed and not view.closed then
            return view, true
        end
    end
    return nil, false
end

local function apply(value)
    local runtime = getRuntime()
    if runtime == nil then
        return
    end
    local view, created = getView(runtime, true)
    if view == nil then
        return
    end
    if type(view.values) == "table" and type(view.values.confirmExit) == "boolean" then
        view.values.confirmExit = value
    end
    pcall(function()
        if type(view.options) == "table" and type(view.options.set) == "function" then
            view.options.set("confirmExit", value)
        end
        if type(view.setValue) == "function" then
            view:setValue("confirmExit", value)
        end
    end)
    if created then
        pcall(function()
            view:close()
        end)
    end
end

function ConfirmExit.Set(state)
    local nextEnabled = state == true
    if nextEnabled and not enabled then
        local runtime = getRuntime()
        local view, created = getView(runtime, true)
        if view ~= nil and type(view.values) == "table"
            and type(view.values.confirmExit) == "boolean" then
            original = view.values.confirmExit
        end
        if created then
            pcall(function()
                view:close()
            end)
        end
        apply(true)
    elseif not nextEnabled and enabled then
        apply(original == true)
        original = nil
    end
    enabled = nextEnabled
end

function ConfirmExit.IsEnabled()
    return enabled
end

function ConfirmExit.Setup(window)
    window:AddToggle({
        Name = "Confirm Exit",
        Default = false,
        Description = "Always require confirmation before exiting a level",
        Callback = function(state)
            ConfirmExit.Set(state)
        end,
    })
end

return ConfirmExit
