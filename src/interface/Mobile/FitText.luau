export type FitConfig = {
    Base: number?,
    Min: number?,
}

local FitText = {}

local function availableWidth(label: TextLabel): number
    local ok, size = pcall(function()
        return label.AbsoluteSize
    end)
    if not ok or typeof(size) ~= "Vector2" then
        return 0
    end
    return size.X
end

function FitText.fit(label: TextLabel, config: FitConfig?): ()
    local base = if config ~= nil and config.Base ~= nil then config.Base else 35
    local minSize = if config ~= nil and config.Min ~= nil then config.Min else 14
    local decided = false

    pcall(function()
        label.AutomaticSize = Enum.AutomaticSize.None
        label.TextWrapped = false
        label.TextTruncate = Enum.TextTruncate.None
        label.TextScaled = false
        label.TextSize = base
    end)

    local measure = Instance.new("TextLabel")
    measure.Name = "FitMeasure"
    measure.BackgroundTransparency = 1
    measure.TextTransparency = 1
    measure.BorderSizePixel = 0
    measure.AnchorPoint = Vector2.new(0, 0)
    measure.Position = UDim2.fromOffset(0, 0)
    measure.Size = UDim2.fromOffset(4000, base + 10)
    measure.FontFace = label.FontFace
    measure.TextSize = base
    measure.TextTruncate = Enum.TextTruncate.None
    measure.TextWrapped = false
    measure.TextXAlignment = Enum.TextXAlignment.Left
    measure.Text = label.Text
    measure.Parent = label.Parent

    local function releaseMeasure(): ()
        pcall(function()
            measure:Destroy()
        end)
    end

    local function textWidth(): number
        local ok, bounds = pcall(function()
            return measure.TextBounds
        end)
        if not ok or typeof(bounds) ~= "Vector2" then
            return 0
        end
        return bounds.X
    end

    local function applySize(size: number): ()
        label.TextSize = size
        measure.TextSize = size
    end

    local function verify(): ()
        if not decided then
            return
        end
        local width = textWidth()
        local avail = availableWidth(label)
        if width <= 0 or avail <= 0 then
            return
        end
        if width <= avail then
            releaseMeasure()
            return
        end
        local current = label.TextSize
        if current <= minSize then
            return
        end
        applySize(math.max(minSize, current - 1))
    end

    local function decide(): ()
        if decided then
            return
        end
        local width = textWidth()
        local avail = availableWidth(label)
        if width <= 0 or avail <= 0 then
            return
        end
        decided = true
        if width <= avail then
            releaseMeasure()
            return
        end
        applySize(math.max(minSize, math.floor(base * avail / width * 0.98)))
        task.delay(0.15, verify)
        task.delay(0.4, verify)
        task.delay(0.7, verify)
        task.delay(1.1, verify)
    end

    measure:GetPropertyChangedSignal("TextBounds"):Connect(decide)
    task.defer(decide)
    task.delay(0.3, decide)
    task.delay(1, decide)
end

return FitText
