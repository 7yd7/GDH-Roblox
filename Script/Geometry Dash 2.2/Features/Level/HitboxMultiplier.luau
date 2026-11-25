local RunService = game:GetService("RunService")

local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local okUtil, Util = pcall(function()
    return genv.Import("Geometry Dash 2.2/Features/Level/Util")
end)
if not okUtil or type(Util) ~= "table" then
    Util = nil
end

local HitboxMultiplier = {}
local enabled = false
local hook = Util and Util.NewHook() or nil
local watcher = nil
local activePass = nil
local saved = {}
local multipliers = { player = 1, solid = 1, hazard = 1 }

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

local function numberSetting(key, default)
    local store = genv.GDH_HACK_SETTINGS_STATE
    local state = type(store) == "table" and store["hitbox multiplier"] or nil
    local value = type(state) == "table" and state[key] or nil
    if type(value) == "number" then
        return value
    end
    return default
end

local function readSettings()
    return {
        player = math.clamp(numberSetting("player_multiplier", 1), 0, 10),
        solid = math.clamp(numberSetting("solid_multiplier", 1), 0, 10),
        hazard = math.clamp(numberSetting("hazard_multiplier", 1), 0, 10),
    }
end

local function sameSettings(a, b)
    return a.player == b.player and a.solid == b.solid and a.hazard == b.hazard
end

local function scaleBox(box, scale)
    if type(box) ~= "table" or scale == 1 then
        return box
    end
    local result = {}
    for key, value in pairs(box) do
        result[key] = value
    end
    local cx = (tonumber(box.x0) + tonumber(box.x1) + tonumber(box.x2) + tonumber(box.x3)) / 4
    local cy = (tonumber(box.y0) + tonumber(box.y1) + tonumber(box.y2) + tonumber(box.y3)) / 4
    for index = 0, 3 do
        local xKey, yKey = "x" .. index, "y" .. index
        result[xKey] = cx + ((tonumber(box[xKey]) or cx) - cx) * scale
        result[yKey] = cy + ((tonumber(box[yKey]) or cy) - cy) * scale
    end
    result.oa = (tonumber(box.oa) or 0) * scale
    result.ob = (tonumber(box.ob) or 0) * scale
    return result
end

local function getPass()
    local runtime = getRuntime()
    return runtime and runtime.layer and runtime.layer.pass or nil
end

local function restoreObjects()
    if type(activePass) ~= "table" then
        return
    end
    local pass = activePass
    for id, entry in pairs(saved) do
        rawset(pass.oW, id, entry.w)
        rawset(pass.oH, id, entry.h)
        rawset(pass.oRad, id, entry.rad)
        if type(pass.store) == "table" and type(pass.store.rectDirty) == "table" then
            pass.store.rectDirty[id] = true
        end
    end
    table.clear(saved)
    activePass = nil
end

local function applyObjects()
    local pass = getPass()
    if type(pass) ~= "table" or type(pass.oW) ~= "table" or type(pass.oH) ~= "table" then
        return
    end
    if activePass ~= pass then
        restoreObjects()
        activePass = pass
    end
    for id in pairs(pass.oType or {}) do
        if saved[id] == nil then
            saved[id] = {
                w = rawget(pass.oW, id),
                h = rawget(pass.oH, id),
                rad = type(pass.oRad) == "table" and rawget(pass.oRad, id) or nil,
            }
        end
        local hazard = pass.oType[id] == 2 or pass.oType[id] == 47
        local kind = hazard and multipliers.hazard or multipliers.solid
        local baseW = tonumber(saved[id].w) or tonumber(pass.cW and pass.cW[id]) or 0
        local baseH = tonumber(saved[id].h) or tonumber(pass.cH and pass.cH[id]) or 0
        if baseW > 0 or baseH > 0 then
            rawset(pass.oW, id, baseW * kind)
            rawset(pass.oH, id, baseH * kind)
            if type(pass.oRad) == "table" then
                local baseRad = tonumber(saved[id].rad)
                    or tonumber(pass.cRad and pass.cRad[id]) or 0
                if baseRad > 0 then
                    rawset(pass.oRad, id, baseRad * kind)
                end
            end
            if type(pass.store) == "table" and type(pass.store.rectDirty) == "table" then
                pass.store.rectDirty[id] = true
            end
            pcall(function()
                pass:objectRect(id)
            end)
        end
    end
end

local function restore()
    if hook then
        hook:Restore()
    end
    restoreObjects()
end

local function apply()
    restore()
    if not enabled or not hook then
        return
    end
    hook:Wrap("Player", "getRect", function(original, self, ...)
        local x, y, width, height = original(self, ...)
        return x, y, width * multipliers.player, height * multipliers.player
    end)
    hook:Wrap("CollisionPass", "playerOBB", function(original, self, player, ...)
        return scaleBox(original(self, player, ...), multipliers.player)
    end)
    applyObjects()
end

local function watch()
    if watcher then
        return
    end
    watcher = RunService.Heartbeat:Connect(function()
        if not enabled then
            return
        end
        local wanted = readSettings()
        if not sameSettings(wanted, multipliers) or getPass() ~= activePass then
            multipliers = wanted
            apply()
        end
    end)
end

function HitboxMultiplier.Set(state)
    enabled = state == true
    multipliers = readSettings()
    apply()
    if enabled then
        watch()
    elseif watcher then
        watcher:Disconnect()
        watcher = nil
    end
end

function HitboxMultiplier.IsEnabled()
    return enabled
end

function HitboxMultiplier.Setup(window)
    window:AddToggle({
        Name = "Hitbox Multiplier",
        Default = false,
        Description = "Scale player, solid and hazard hitboxes",
        Cheating = true,
        Settings = {
            { Kind = "Float", Text = "Player Multiplier", Key = "player_multiplier", Min = 0, Max = 10, Default = 1, Increment = 0.05, Precision = 2, Suffix = "x" },
            { Kind = "Float", Text = "Solid Multiplier", Key = "solid_multiplier", Min = 0, Max = 10, Default = 1, Increment = 0.05, Precision = 2, Suffix = "x" },
            { Kind = "Float", Text = "Hazard Multiplier", Key = "hazard_multiplier", Min = 0, Max = 10, Default = 1, Increment = 0.05, Precision = 2, Suffix = "x" },
        },
        Callback = function(state)
            HitboxMultiplier.Set(state)
        end,
    })
end

return HitboxMultiplier
