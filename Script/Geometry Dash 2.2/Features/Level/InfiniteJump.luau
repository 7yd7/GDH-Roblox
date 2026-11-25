local RunService = game:GetService("RunService")

local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local InfiniteJump = {}
local enabled = false
local conn = nil

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

local function start()
    if conn then
        return
    end
    conn = RunService.Heartbeat:Connect(function()
        if not enabled then
            return
        end
        local runtime = getRuntime()
        local pass = runtime and runtime.layer and runtime.layer.pass
        if type(pass) ~= "table" then
            return
        end
        for index = 1, 2 do
            local player = index == 1 and pass.p1 or pass.p2
            if type(player) == "table" and player.isDead ~= true then
                pcall(function()
                    player.isOnGround = true
                    player.isOnGround2 = true
                    player.isOnGround3 = true
                    player.isOnGround4 = true
                end)
            end
        end
    end)
end

function InfiniteJump.Set(state)
    enabled = state == true
    if enabled then
        start()
    elseif conn then
        conn:Disconnect()
        conn = nil
    end
end

function InfiniteJump.IsEnabled()
    return enabled
end

function InfiniteJump.Setup(window)
    window:AddToggle({
        Name = "Infinite Jump",
        Default = false,
        Description = "Allows jumping again while already in the air",
        Cheating = true,
        Callback = function(state)
            InfiniteJump.Set(state)
        end,
    })
end

return InfiniteJump
