local UserInputService = game:GetService("UserInputService")

export type PressTarget = {
    Node: GuiObject,
    Bounds: (() -> (Vector3, Vector3))?,
    Activate: (() -> ())?,
    PressIn: (() -> ())?,
    PressOut: (() -> ())?,
    Release: (() -> ())?,
}

local targets: { any } = {}
local session: any = nil
local connected = false

local function hitTest(pos: Vector3): any
    local best: any = nil
    local bestZ = -1
    for _, target in targets do
        local node = target.Node
        if typeof(node) == "Instance" then
            local guiNode = node :: GuiObject
            if guiNode.Parent ~= nil and guiNode.Visible ~= false then
                local abs: any = nil
                local size: any = nil
                local boundsFn = target.Bounds
                if typeof(boundsFn) == "function" then
                    local ok, origin, extent = pcall(boundsFn)
                    if ok and typeof(origin) == "Vector3" and typeof(extent) == "Vector3" then
                        abs = origin
                        size = extent
                    end
                end
                if abs == nil then
                    abs = guiNode.AbsolutePosition
                    size = guiNode.AbsoluteSize
                end
                if pos.X >= abs.X and pos.X <= abs.X + size.X
                    and pos.Y >= abs.Y and pos.Y <= abs.Y + size.Y
                then
                    if guiNode.ZIndex > bestZ then
                        bestZ = guiNode.ZIndex
                        best = target
                    end
                end
            end
        end
    end
    return best
end

local function connect()
    if connected then
        return
    end
    connected = true

    UserInputService.InputChanged:Connect(function(input: InputObject)
        if session == nil then
            return
        end
        local inputType = input.UserInputType
        if inputType ~= session.inputType
            and not (session.inputType == Enum.UserInputType.MouseButton1
                and inputType == Enum.UserInputType.MouseMovement)
        then
            return
        end
        session.last = input.Position
        local hit = hitTest(input.Position)
        if hit ~= session.current then
            local previous = session.current
            session.current = hit
            if previous ~= nil and typeof(previous.PressOut) == "function" then
                pcall(previous.PressOut)
            end
            if hit ~= nil and typeof(hit.PressIn) == "function" then
                pcall(hit.PressIn)
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input: InputObject)
        if session == nil then
            return
        end
        local inputType = input.UserInputType
        if inputType ~= Enum.UserInputType.Touch and inputType ~= Enum.UserInputType.MouseButton1 then
            return
        end
        if inputType ~= session.inputType then
            return
        end
        if (input.Position - session.last).Magnitude > 60 then
            return
        end
        local state = session
        session = nil
        local current = state.current
        if current ~= nil and current ~= state.origin then
            if typeof(current.Release) == "function" then
                pcall(current.Release)
            end
            if typeof(current.Activate) == "function" then
                pcall(current.Activate)
            end
        end
    end)
end

local PressFlow = {}

function PressFlow.Register(target: any): ()
    if typeof(target) ~= "table" then
        return
    end
    connect()
    table.insert(targets, target)
    local node = target.Node
    if typeof(node) == "Instance" then
        local guiNode = node :: GuiObject
        guiNode.Destroying:Connect(function()
            PressFlow.Unregister(target)
        end)
    end
end

function PressFlow.Unregister(target: any): ()
    for index = #targets, 1, -1 do
        if targets[index] == target then
            table.remove(targets, index)
        end
    end
    if session ~= nil and (session.origin == target or session.current == target) then
        session = nil
    end
end

function PressFlow.Begin(target: any, input: InputObject): ()
    if session ~= nil then
        return
    end
    if typeof(target) ~= "table" then
        return
    end
    connect()
    session = {
        origin = target,
        current = target,
        start = input.Position,
        last = input.Position,
        inputType = input.UserInputType,
    }
end

return PressFlow
