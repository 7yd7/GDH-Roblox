local Conceal = {}

local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local hidden = setmetatable({}, { __mode = "k" })
local installed = false

local function ours(): boolean
    local ok, value = pcall(function()
        return typeof(checkcaller) == "function" and checkcaller() == true
    end)
    return ok and value == true
end

local function marked(instance: Instance): boolean
    local ok, value = pcall(function()
        return instance:GetAttribute("GDHUI") == true
    end)
    return ok and value == true
end

local function isHidden(value: any): boolean
    if typeof(value) ~= "Instance" then
        return false
    end
    local node: Instance? = value
    while node ~= nil do
        if hidden[node] == true or marked(node) then
            return true
        end
        node = node.Parent
    end
    return false
end

local function filterList(value: any): any
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for _, item in ipairs(value) do
        if not isHidden(item) then
            result[#result + 1] = item
        end
    end
    return result
end

local function methodName(): string
    local ok, value = pcall(function()
        if typeof(getnamecallmethod) ~= "function" then
            return ""
        end
        return getnamecallmethod() or ""
    end)
    if ok and typeof(value) == "string" then
        return value
    end
    return ""
end

function Conceal.Register(instance: any): ()
    if typeof(instance) ~= "Instance" then
        return
    end
    hidden[instance] = true
    pcall(function()
        (instance :: Instance):SetAttribute("GDHUI", true)
    end)
end

function Conceal.Install(): ()
    if installed or genv.GDH_CONCEAL_HOOKED == true then
        installed = true
        return
    end

    local original: any = nil
    local ok = pcall(function()
        original = hookmetamethod(game, "__namecall", function(self: Instance, ...: any)
            if ours() then
                return (original :: any)(self, ...)
            end

            local method = methodName()
            if method == "GetChildren" or method == "GetDescendants" then
                return filterList((original :: any)(self, ...))
            end
            if method == "FindFirstChild"
                or method == "WaitForChild"
                or method == "FindFirstChildOfClass"
                or method == "FindFirstChildWhichIsA"
            then
                local result = (original :: any)(self, ...)
                if isHidden(result) then
                    return nil
                end
                return result
            end
            return (original :: any)(self, ...)
        end)
    end)

    if ok and typeof(original) == "function" then
        genv.GDH_CONCEAL_HOOKED = true
        installed = true
    end
end

return Conceal
