local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or {}

local Import = genv.Import
if not Import then return end

local KeyPop = {}

type KeyPopOptions = {
    name: string?,
    hint: string?,
    parent: Instance?,
    side: string?,
    gap: number?,
    height: number?,
    font: Font?,
    color: Color3?,
}

local function textWidth(text: string, font: Font, size: number): number
    if typeof(text) ~= "string" or text == "" then
        return 0
    end
    local ok, bounds = pcall(function()
        return TextService:GetTextSize(text, size, font, Vector2.new(2000, 0))
    end)
    if ok and typeof(bounds) == "TextBounds" then
        return math.max(bounds.X, 0)
    end

    return math.max(size * 0.55 * #text, 0)
end

local function defaultFont(): Font
    local ok, face = pcall(function()
        return Import.Font("Assets/GD/PUSAB___.otf", "Pusab")
    end)
    if ok and face ~= nil then
        return face
    end
    return Font.fromEnum(Enum.Font.GothamBlack)
end

function KeyPop.Update(frame: Frame, parent: Instance, opts: KeyPopOptions?)
    if frame.Parent == nil or parent.Parent == nil then
        return
    end

    local px = parent.AbsolutePosition.X
    local py = parent.AbsolutePosition.Y
    local pw = parent.AbsoluteSize.X
    local ph = parent.AbsoluteSize.Y
    if pw <= 0 or ph <= 0 then
        return
    end

    local side = (opts and opts.side) or "right"
    local gap = math.max(0, (opts and typeof(opts.gap) == "number" and opts.gap) or 4)
    local fw = frame.Size.X.Offset
    local fh = frame.Size.Y.Offset

    local X, Y
    if side == "left" then
        X = px - fw - gap
        Y = py + ph / 2 - fh / 2
    elseif side == "top" then
        X = px + pw / 2 - fw / 2
        Y = py - fh - gap
    elseif side == "bottom" then
        X = px + pw / 2 - fw / 2
        Y = py + ph + gap
    else
        X = px + pw + gap
        Y = py + ph / 2 - fh / 2
    end

    frame.Position = UDim2.new(0, X - px, 0, Y - py)
end

function KeyPop.Create(parent: Instance, opts: KeyPopOptions): Frame?
    if not parent then
        return nil
    end

    local name = (typeof(opts.name) == "string" and opts.name ~= "" and opts.name)
        or parent.Name
        or ""
    local hint = typeof(opts.hint) == "string" and opts.hint or ""
    local side = opts.side or "right"
    local gap = math.max(0, typeof(opts.gap) == "number" and opts.gap or 4)
    local popHeight = math.max(14, typeof(opts.height) == "number" and opts.height or 26)
    local font = opts.font or defaultFont()

    local padX = 8
    local lineH = popHeight * 0.5
    local nameSize = popHeight * 0.7
    local hintSize = popHeight * 0.55

    local nameW = textWidth(name, font, nameSize)
    local hintW = textWidth(hint, font, hintSize)
    local width = math.max(nameW, hintW) + padX * 2

    local frame = Instance.new("Frame")
    frame.Name = "KeyPop"
    frame.AnchorPoint = Vector2.new(0, 0)
    frame.Size = UDim2.new(0, width, 0, popHeight)
    frame.BackgroundColor3 = opts.color or Color3.fromRGB(10, 10, 10)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.ZIndex = (parent.ZIndex or 0) + 3
    frame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    nameLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
    nameLabel.Size = UDim2.new(0.96, 0, lineH, 0)
    nameLabel.FontFace = font
    nameLabel.TextSize = nameSize
    nameLabel.Text = name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
    nameLabel.TextYAlignment = Enum.TextYAlignment.Center
    nameLabel.BackgroundTransparency = 1
    nameLabel.BorderSizePixel = 0
    nameLabel.Parent = frame

    local hintLabel = Instance.new("TextLabel")
    hintLabel.Name = "Hint"
    hintLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    hintLabel.Position = UDim2.new(0.5, 0, 0.75, 0)
    hintLabel.Size = UDim2.new(0.96, 0, lineH * 0.8, 0)
    hintLabel.FontFace = font
    hintLabel.TextSize = hintSize
    hintLabel.Text = hint
    hintLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
    hintLabel.TextXAlignment = Enum.TextXAlignment.Center
    hintLabel.TextYAlignment = Enum.TextYAlignment.Center
    hintLabel.BackgroundTransparency = 1
    hintLabel.BorderSizePixel = 0
    hintLabel.Parent = frame

    do
        local frames = 12
        local conn: RBXScriptConnection? = nil
        conn = RunService.RenderStepped:Connect(function()
            frames -= 1
            if frames <= 0 or frame.Parent == nil or parent.Parent == nil then
                if conn then
                    conn:Disconnect()
                end
                return
            end
            KeyPop.Update(frame, parent, opts)
        end)
    end

    KeyPop.Update(frame, parent, opts)
    return frame
end

return KeyPop
