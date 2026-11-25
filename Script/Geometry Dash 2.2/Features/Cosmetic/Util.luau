local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local Util = {}

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

    function hook:SetMany(path, map)
        for name, replacement in pairs(map) do
            self:Set(path, name, replacement)
        end
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

return Util
