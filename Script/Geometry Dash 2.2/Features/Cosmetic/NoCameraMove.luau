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
local captureHook = Util and Util.NewHook() or nil
local patched = setmetatable({}, { __mode = "k" })
local bases = setmetatable({}, { __mode = "k" })

local function hold(self)
    if type(self) ~= "table" then
        return
    end
    local base = bases[self]
    if not base then
        base = {
            camX = self.camX,
            camY = self.camY,
            viewX = self.viewX,
            viewY = self.viewY,
            layerX = self.layerX,
            layerY = self.layerY,
        }
        bases[self] = base
    end
    self.camX = base.camX
    self.camY = base.camY
    self.viewX = base.viewX
    self.viewY = base.viewY
    self.layerX = base.layerX
    self.layerY = base.layerY
end

local function patch(camera)
    if type(camera) ~= "table" or patched[camera] then
        return
    end
    patched[camera] = true
    local original = camera.update
    if type(original) ~= "function" then
        return
    end
    camera.update = function(self, ...)
        local result = original(self, ...)
        if enabled then
            hold(self)
        end
        return result
    end
end

if captureHook then
    captureHook:Wrap("CameraModel", "new", function(original, ...)
        local result = table.pack(original(...))
        local camera = result[1]
        if type(camera) == "table" then
            patch(camera)
        end
        return table.unpack(result, 1, result.n)
    end)
end

function Feature.Set(state)
    enabled = state == true
    if not enabled then
        table.clear(bases)
    end
end

function Feature.IsEnabled()
    return enabled
end

function Feature.Setup(window)
    window:AddToggle({
        Name = "No Camera Move",
        Default = false,
        Description = "Keep the camera from following the player",
        Callback = function(state)
            Feature.Set(state)
        end,
    })
end

return Feature
