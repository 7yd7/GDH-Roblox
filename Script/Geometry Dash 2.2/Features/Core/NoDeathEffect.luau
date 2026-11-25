local RunService = game:GetService("RunService")

local NoDeathEffect = {}

local enabled = false
local runtime = nil
local audio = nil
local legacyFx = nil
local originalPlay = nil
local originalLegacyDeath = nil
local watchConn = nil
local proto = nil
local protoSaved = nil

local function getRuntime()
    if runtime then
        return runtime
    end
    local ok, mod = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local rt = port and port:FindFirstChild("ClientRuntime")
        return rt and require(rt) or nil
    end)
    if ok and type(mod) == "table" and type(mod.hacks) == "table" then
        runtime = mod
    end
    return runtime
end

local function getModules()
    if audio and legacyFx then
        return true
    end
    local ok, a, f = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local am = port and port:FindFirstChild("AudioAssets")
        local fm = port and port:FindFirstChild("RendererPlayerFx")
        return am and require(am) or nil, fm and require(fm) or nil
    end)
    if ok and type(a) == "table" and type(a.play) == "function"
        and type(f) == "table" and type(f.DEATH) == "table"
    then
        audio, legacyFx = a, f
        return true
    end
    return false
end

local function restoreProto()
    if not protoSaved then
        return
    end
    local p = protoSaved.proto
    p._startDeathShatter = protoSaved.shatter
    p._startDefaultDeath = protoSaved.default
    protoSaved = nil
    proto = nil
end

local function patchProto()
    local mod = getRuntime()
    local h = mod and mod.hacks
    local o = h and h.o
    if type(o) ~= "table" or type(o.renderer) ~= "function" then
        return
    end
    local ok, renderer = pcall(o.renderer)
    if not ok or type(renderer) ~= "table" then
        return
    end
    local mt = getmetatable(renderer)
    local p = type(mt) == "table" and mt.__index or nil
    if type(p) ~= "table" or p == proto then
        return
    end
    restoreProto()
    proto = p
    protoSaved = {
        proto = p,
        shatter = p._startDeathShatter,
        default = p._startDefaultDeath,
    }
    p._startDeathShatter = function() end
    p._startDefaultDeath = function() end
end

local function apply()
    if enabled then
        if getModules() then
            if originalPlay == nil then
                originalPlay = audio.play
                originalLegacyDeath = legacyFx.DEATH
            end
            audio.play = function(self, sound, name, loop, ...)
                if type(name) == "string" and name:lower():find("explode", 1, true) then
                    return false
                end
                if type(sound) == "string" and sound:lower():find("explode", 1, true) then
                    return false
                end
                return originalPlay(self, sound, name, loop, ...)
            end
            legacyFx.DEATH = {}
        end
        patchProto()
        if not watchConn then
            watchConn = RunService.RenderStepped:Connect(function()
                if enabled then
                    patchProto()
                end
            end)
        end
    else
        if watchConn then
            watchConn:Disconnect()
            watchConn = nil
        end
        restoreProto()
        if originalPlay ~= nil then
            audio.play = originalPlay
            legacyFx.DEATH = originalLegacyDeath
            originalPlay, originalLegacyDeath = nil, nil
        end
    end
end

function NoDeathEffect.Set(state)
    enabled = state == true
    apply()
end

function NoDeathEffect.IsEnabled()
    return enabled
end

function NoDeathEffect.Setup(window)
    window:AddToggle({
        Name = "No Death Effect",
        Default = false,
        Description = "Remove the death explosion sound and shatter effect",
        Callback = function(state)
            NoDeathEffect.Set(state)
        end,
    })
end

return NoDeathEffect
