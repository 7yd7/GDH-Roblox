local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local okUtil, Util = pcall(function()
    return genv.Import("Geometry Dash 2.2/Features/Level/Util")
end)
if not okUtil or type(Util) ~= "table" then
    Util = nil
end

local AutoLDM = {}
local enabled = false
local saved = nil
local elapsed = 0

local function apply()
    local ok, quality = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local q = port and port:FindFirstChild("QualityGovernor")
        return q and require(q) or nil
    end)
    if not ok or type(quality) ~= "table" or type(quality.set) ~= "function" then
        return
    end
    if enabled then
        if saved == nil then
            saved = {
                lowDetail = quality.settings and quality.settings.lowDetail,
                extraLDM = quality.settings and quality.settings.extraLDM,
            }
        end
        pcall(function() quality.set("lowDetail", true) end)
        pcall(function() quality.set("extraLDM", true) end)
    elseif saved then
        pcall(function() quality.set("lowDetail", saved.lowDetail == true) end)
        pcall(function() quality.set("extraLDM", saved.extraLDM == true) end)
        saved = nil
    end
end

if Util then
    Util.OnLevelStart(function()
        if enabled then
            apply()
        end
    end)
end

local conn = nil

local function start()
    if conn then
        return
    end
    conn = game:GetService("RunService").Heartbeat:Connect(function(dt)
        if not enabled then
            return
        end
        elapsed += dt
        if elapsed >= 0.5 then
            elapsed = 0
            apply()
        end
    end)
end

function AutoLDM.Set(state)
    enabled = state == true
    if enabled then
        start()
    end
    apply()
end

function AutoLDM.IsEnabled()
    return enabled
end

function AutoLDM.Setup(window)
    window:AddToggle({
        Name = "Auto LDM",
        Default = false,
        Description = "Automatically use low detail mode in levels",
        Callback = function(state)
            AutoLDM.Set(state)
        end,
    })
end

return AutoLDM
