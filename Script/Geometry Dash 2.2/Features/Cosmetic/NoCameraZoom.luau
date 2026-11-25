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

local function patch(camera)
    if type(camera) ~= "table" or patched[camera] then
        return
    end
    patched[camera] = true
    local original = camera.updateZoom
    if type(original) ~= "function" then
        return
    end
    camera.updateZoom = function(self, zoom, duration, ...)
        if enabled then
            local result = original(self, 1, 0, ...)
            if type(self) == "table" then
                self.zoom = 1
                self.zoomTarget = 1
                self.lastZoom = 1
            end
            return result
        end
        return original(self, zoom, duration, ...)
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
end

function Feature.IsEnabled()
    return enabled
end

function Feature.Setup(window)
    window:AddToggle({
        Name = "No Camera Zoom",
        Default = false,
        Description = "Keep the camera zoom fixed at normal",
        Callback = function(state)
            Feature.Set(state)
        end,
    })
end

return Feature
