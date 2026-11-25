local RunService = game:GetService("RunService")

local GamepassUtil = {}

local KEYS = {
    noclip = "noclip",
    menu = "menu",
    speed = "speed",
}

local states = {
    noclip = { enabled = false, saved = nil },
    menu = { enabled = false, saved = nil },
    speed = { enabled = false, saved = nil },
}

local runtime = nil
local watchConn = nil
local appliedHacks = nil
local newHacksWrapped = false

local function getRuntime()
    if runtime then
        return runtime
    end
    local ok, mod = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local rt = port and port:FindFirstChild("ClientRuntime")
        return rt and require(rt) or nil
    end)
    if ok and type(mod) == "table" then
        runtime = mod
    end
    return runtime
end

local function changed(hacks)
    if type(hacks) ~= "table" or type(hacks._changed) ~= "function" then
        return
    end
    pcall(function()
        hacks:_changed()
    end)
end

local function apply(key)
    local state = states[key]
    local hacks = getRuntime()
    hacks = hacks and hacks.hacks
    if not state or type(hacks) ~= "table" or type(hacks.owned) ~= "table" then
        return
    end
    if type(hacks.known) ~= "table" then
        hacks.known = {}
    end

    if state.enabled then
        if state.saved and state.saved.hacks ~= hacks then
            state.saved = nil
        end
        if not state.saved then
            state.saved = {
                hacks = hacks,
                owned = hacks.owned[key],
                known = hacks.known[key],
                noclip = hacks.noclip,
            }
        end
        hacks.owned[key] = true
        hacks.known[key] = true
        if key == "noclip" then
            hacks.noclip = true
        end
    elseif state.saved and state.saved.hacks == hacks then
        if state.saved.owned == nil then
            hacks.owned[key] = nil
        else
            hacks.owned[key] = state.saved.owned
        end
        if state.saved.known == nil then
            hacks.known[key] = nil
        else
            hacks.known[key] = state.saved.known
        end
        if key == "noclip" then
            hacks.noclip = state.saved.noclip
        end
        state.saved = nil
    else
        return
    end

    changed(hacks)
end

local function applyEnabled(hacks)
    appliedHacks = hacks
    for key, state in pairs(states) do
        if state.enabled then
            apply(key)
        end
    end
end

local function tick()
    local rt = getRuntime()
    local hacks = rt and rt.hacks
    if hacks ~= appliedHacks then
        applyEnabled(hacks)
    end
end

local function watch()
    if watchConn then
        return
    end
    watchConn = RunService.Heartbeat:Connect(tick)

    local rt = getRuntime()
    if not rt or newHacksWrapped or type(rt.newHacks) ~= "function" then
        return
    end
    local original = rt.newHacks
    rt.newHacks = function(...)
        local hacks = original(...)
        task.spawn(function()
            applyEnabled(hacks)
        end)
        return hacks
    end
    newHacksWrapped = true
end

function GamepassUtil.Set(name, state)
    local key = KEYS[name]
    if not key then
        return false
    end
    states[key].enabled = state == true
    watch()
    apply(key)
    return states[key].enabled
end

function GamepassUtil.IsEnabled(name)
    local key = KEYS[name]
    return key ~= nil and states[key].enabled
end

return GamepassUtil
