local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local okUtil, Util = pcall(function()
    return genv.Import("Geometry Dash 2.2/Features/Cosmetic/Util")
end)
if not okUtil or type(Util) ~= "table" then
    Util = nil
end

local Feature = {}
local enabled = false
local hook = Util and Util.NewHook() or nil
local hidden = {}

local function hide(value)
    if type(value) ~= "table" then
        return
    end
    if hidden[value] == nil and type(value.setVisible) == "function" then
        hidden[value] = value.visibleFlag
        pcall(function()
            value:setVisible(false)
        end)
    end
    value.visible = false
end

local function restore()
    for value, flag in pairs(hidden) do
        if type(value.setVisible) == "function" then
            pcall(function()
                value:setVisible(flag == nil and true or flag)
            end)
        end
    end
    table.clear(hidden)
end

local function apply()
    if not hook then
        return
    end
    if enabled then
        hook:Wrap("RendererPlayerFx", "frame", function(original, self, ...)
            local result = original(self, ...)
            if type(self) == "table" then
                hide(self.dash)
            end
            return result
        end)
    else
        hook:Restore()
        restore()
    end
end

function Feature.Set(state)
    enabled = state == true
    apply()
end

function Feature.IsEnabled()
    return enabled
end

function Feature.Setup(window)
    window:AddToggle({
        Name = "No Dash Fire",
        Default = false,
        Description = "Remove dash fire visuals",
        Callback = function(state)
            Feature.Set(state)
        end,
    })
end

return Feature
