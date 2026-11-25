local RunService = game:GetService("RunService")

local Util = {}
local callbacks = {}
local simulation = nil
local originalNew = nil
local hooked = false
local watchConn = nil
local moduleCache = {}

function Util.Get(path)
    if moduleCache[path] ~= nil then
        return moduleCache[path]
    end
    local ok, mod = pcall(function()
        local node = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        for part in path:gmatch("[^/]+") do
            node = node and node:FindFirstChild(part)
            if not node then
                return nil
            end
        end
        return node and require(node) or nil
    end)
    if ok and type(mod) == "table" then
        moduleCache[path] = mod
        return mod
    end
    return nil
end

function Util.NewHook()
    local hook = { entries = {} }

    function hook:Set(path, name, replacement)
        local mod = Util.Get(path)
        if type(mod) ~= "table" or type(mod[name]) ~= "function" then
            return false
        end
        local byName = self.entries[mod]
        if not byName then
            byName = {}
            self.entries[mod] = byName
        end
        if byName[name] == nil then
            byName[name] = mod[name]
        end
        mod[name] = replacement
        return true
    end

    function hook:Wrap(path, name, wrapper)
        local mod = Util.Get(path)
        if type(mod) ~= "table" or type(mod[name]) ~= "function" then
            return false
        end
        local byName = self.entries[mod]
        local original = byName and byName[name] or mod[name]
        return self:Set(path, name, function(...)
            return wrapper(original, ...)
        end)
    end

    function hook:Restore()
        for mod, byName in pairs(self.entries) do
            for name, original in pairs(byName) do
                mod[name] = original
            end
        end
        table.clear(self.entries)
    end

    return hook
end

function Util.Noop()
end

local function getSimulationModule()
    local ok, mod = pcall(function()
        local port = game:GetService("ReplicatedStorage"):FindFirstChild("GDPort")
        local sim = port and port:FindFirstChild("Simulation")
        return sim and require(sim) or nil
    end)
    if ok and type(mod) == "table" and type(mod.new) == "function" then
        return mod
    end
    return nil
end

local function tryHook()
    if hooked then
        return true
    end
    local mod = getSimulationModule()
    if not mod then
        return false
    end
    originalNew = mod.new
    mod.new = function(...)
        local instance = originalNew(...)
        simulation = instance
        for _, callback in ipairs(callbacks) do
            pcall(callback, instance)
        end
        return instance
    end
    hooked = true
    if watchConn then
        watchConn:Disconnect()
        watchConn = nil
    end
    return true
end

function Util.OnLevelStart(callback)
    if type(callback) ~= "function" then
        return
    end
    callbacks[#callbacks + 1] = callback
    if not tryHook() and not watchConn then
        watchConn = RunService.RenderStepped:Connect(function()
            tryHook()
        end)
    end
end

function Util.GetSimulation()
    return simulation
end

return Util
