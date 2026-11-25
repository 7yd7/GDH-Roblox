local Theme = {}

Theme.Colors = {

    WindowBG           = Color3.fromRGB(26, 26, 73),
    WindowBGAlpha      = 250 / 255,
    WindowBGTransparent = 0.04,

    HeaderBG           = Color3.fromRGB(46, 46, 99),

    TextPrimary        = Color3.fromRGB(190, 190, 197),
    TextSecondary      = Color3.fromRGB(180, 180, 189),
    TextDanger         = Color3.fromRGB(225, 115, 121),
    TextDark           = Color3.fromRGB(0, 0, 0),
    TextMuted          = Color3.fromRGB(140, 140, 155),
    TextDisabled       = Color3.fromRGB(148, 158, 210),

    ButtonBG           = Color3.fromRGB(213, 196, 255),
    ButtonBGHover      = Color3.fromRGB(228, 215, 255),
    ButtonBGActive     = Color3.fromRGB(185, 165, 240),
    ButtonText         = Color3.fromRGB(26, 26, 73),
    ButtonForeground   = Color3.fromRGB(26, 26, 73),
    ButtonTextHover    = Color3.fromRGB(36, 36, 90),
    ButtonTextActive   = Color3.fromRGB(18, 18, 55),
    ButtonActiveText   = Color3.fromRGB(33, 33, 78),

    AccentPrimary      = Color3.fromRGB(213, 196, 255),
    AccentDark         = Color3.fromRGB(33, 33, 78),
    AccentGlow         = Color3.fromRGB(160, 140, 220),

    ResizeHandle       = Color3.fromRGB(70, 70, 131),
    ScrollBar          = Color3.fromRGB(164, 164, 181),

    Separator          = Color3.fromRGB(104, 104, 191),
    SeparatorAlpha     = 0,

    ToggleTrackOff        = Color3.fromRGB(71, 71, 131),
    ToggleTrackOffHover   = Color3.fromRGB(104, 104, 191),
    ToggleTrackOffHeld    = Color3.fromRGB(55, 55, 110),
    ToggleTrackOn         = Color3.fromRGB(213, 196, 255),
    ToggleTrackOnHover    = Color3.fromRGB(228, 215, 255),
    ToggleTrackOnHeld     = Color3.fromRGB(185, 165, 240),
    ToggleKnobOff         = Color3.fromRGB(199, 212, 250),
    ToggleKnobOffHover    = Color3.fromRGB(224, 235, 255),
    ToggleKnobOffHeld     = Color3.fromRGB(148, 158, 210),
    ToggleKnobOn          = Color3.fromRGB(33, 33, 78),
    ToggleKnobOnHover     = Color3.fromRGB(46, 46, 99),
    ToggleKnobOnHeld      = Color3.fromRGB(22, 22, 58),
    ToggleKnobShadowAlpha = 0x2E / 255,
    ToggleKnobOutlineAlpha = 0.45,

    RadioRingOff        = Color3.fromRGB(133, 133, 191),
    RadioRingOffHover   = Color3.fromRGB(163, 163, 212),
    RadioRingOffHeld    = Color3.fromRGB(100, 100, 160),
    RadioRingOn         = Color3.fromRGB(213, 196, 255),
    RadioRingOnHover    = Color3.fromRGB(228, 215, 255),
    RadioRingOnHeld     = Color3.fromRGB(185, 165, 240),
    RadioDotOn          = Color3.fromRGB(213, 196, 255),
    RadioDotOnHover     = Color3.fromRGB(228, 215, 255),
    RadioDotOnHeld      = Color3.fromRGB(185, 165, 240),
    RadioLayerOff       = Color3.fromRGB(199, 212, 250),
    RadioLayerOn        = Color3.fromRGB(213, 196, 255),
    RadioLayerAlpha     = 0x14 / 255,
    RadioLayerAlphaHeld = 0x1F / 255,

    SliderBG           = Color3.fromRGB(71, 71, 131),
    SliderBGHover      = Color3.fromRGB(104, 104, 191),
    SliderBGHeld       = Color3.fromRGB(213, 196, 255),
    SliderText         = Color3.fromRGB(199, 212, 250),
    SliderTextHover    = Color3.fromRGB(224, 235, 255),
    SliderTextHeld     = Color3.fromRGB(26, 26, 73),

    ComboBG             = Color3.fromRGB(71, 71, 131),
    ComboBGHover        = Color3.fromRGB(104, 104, 191),
    ComboBGActive       = Color3.fromRGB(55, 55, 110),
    PopupBG             = Color3.fromRGB(26, 26, 73),
    PopupSelected       = Color3.fromRGB(71, 71, 131),
    PopupRowHover       = Color3.fromRGB(104, 104, 191),

    DroplistArrow      = "rbxassetid://110347693095273",
    DroplistBG         = Color3.fromRGB(27, 27, 74),
    DroplistStroke     = Color3.fromRGB(49, 49, 68),

    PopupBorder        = Color3.fromRGB(64, 64, 64),
    PopupBG            = Color3.fromRGB(26, 26, 72),
    PopupBGTransparency = 0.04,

    PopupWindowBG      = Color3.fromRGB(32, 32, 78),
    PopupWindowStroke  = Color3.fromRGB(60, 60, 65),

    TooltipBG           = Color3.fromRGB(33, 33, 78),
    TooltipFG           = Color3.fromRGB(213, 196, 255),
    TooltipBorder       = Color3.fromRGB(213, 196, 255),

    CloseIcon          = "rbxassetid://107165388866879",
    InfoIcon           = "rbxassetid://116359281861345",

    PanelBG            = "rbxassetid://92603007246770",
    HeaderBGImage      = "rbxassetid://73912669848896",
    PopupGlow          = "",
    PopupGlowColor     = Color3.fromRGB(0x78, 0x64, 0xF0),
    PopupGlowEdge      = 100 / 255,
}

Theme.Font = {
    Family    = nil,
    FallbackEnum = Enum.Font.GothamMedium,

    Title     = 15,
    Body      = 15,
    Small     = 13,
    Badge     = 11,
}

Theme.Layout = {
    WindowMinWidth  = 175,
    WindowMinHeight = 100,
    WindowDefaultWidth = 215,
    WindowDefaultHeight = 280,

    WindowRounding  = 12,
    PopupCorner     = 10,
    PopupStrokeThickness = 1.5,
    PopupWidth      = 185,
    PopupGlowSpread = 250,
    ResizeEdgeWidth = 6,
    ResizeCornerSize = 16,

    HeaderHeight    = 24,
    RowHeight       = 24,
    RowPadding      = 4,
    ListPaddingX    = 10,
    ListPaddingY    = 10,

    SeparatorHeight = 10,

    ToggleWidth     = 40,
    ToggleHeight    = 22,
    ToggleKnobInset = 2.5,
    ToggleKnobShrink = 1.2,
    ToggleShadowLift = 0.8,

    RadioSink       = 1,
    RadioLayerScale = 1.4,
    RadioRowHeight  = 26,

    SliderHeight     = 22,

    ButtonCorner    = UDim.new(0, 11),
    ButtonHeight    = 24,
    ButtonPadding   = 4,

    ComboHeight      = 22,
    ComboWidth       = 95,
    ComboItemHeight  = 18,
    ComboPopupPadding = 0,

    DroplistCorner     = 10,
    DroplistPopupPadY  = 5,

    InlineGapX       = 8,
    PairGapX         = 4,
    WindowPaddingX   = 10,
    RadioRowInsetX   = 10,

    ResizeSize      = UDim2.fromOffset(43, 7),
    ResizeRotation  = -45,

    CloseButtonSize = UDim2.fromOffset(13, 11),
    CloseAspect     = 1.182,

    InfoIconSize    = UDim2.fromOffset(22, 22),

    ScrollBarWidth  = 5,
    ScrollBarSize   = 8,
}

local _baseLayout = nil
local _baseFont = nil

function Theme.ApplyScreenScale(force: number?): number
    local cam = workspace.CurrentCamera
    local vp = (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
    local factor = force or math.clamp(vp.X / 1920, 0.78, 1.45)
    Theme.ScreenScale = factor

    local function scaleNumber(n: number): number
        return math.max(1, math.floor(n * factor + 0.5))
    end
    if _baseLayout == nil then
        _baseLayout = {}
        for baseKey, baseValue in pairs(Theme.Layout) do
            _baseLayout[baseKey] = baseValue
        end
    end
    if _baseFont == nil then
        _baseFont = {}
        for baseKey, baseValue in pairs(Theme.Font) do
            _baseFont[baseKey] = baseValue
        end
    end
    for key, baseValue in pairs(_baseLayout) do
        if typeof(baseValue) == "number" then

            if baseValue >= 4 and baseValue == math.floor(baseValue) then
                Theme.Layout[key] = scaleNumber(baseValue)
            end
        elseif typeof(baseValue) == "UDim2" then
            Theme.Layout[key] = UDim2.new(
                baseValue.X.Scale, scaleNumber(baseValue.X.Offset),
                baseValue.Y.Scale, scaleNumber(baseValue.Y.Offset))
        elseif typeof(baseValue) == "UDim" then
            Theme.Layout[key] = UDim.new(
                baseValue.Scale, scaleNumber(baseValue.Offset))
        end
    end
    for key, baseValue in pairs(_baseFont) do
        if typeof(baseValue) == "number" then
            Theme.Font[key] = scaleNumber(baseValue)
        end
    end
    return factor
end

Theme.Animation = {
    DurationMS         = 100,
    FadeDuration       = 0.15,
    CollapseDuration   = 0.20,
    SlideDuration      = 0.25,
    SearchHighlight    = 16.0,
    UIToggleDuration   = 0.10,

    ToggleSpeed        = 14,
    ToggleHoverSpeed   = 9,
    ToggleHeldSpeed    = 18,
}

local _animSpeedKeys = {
    "ToggleSpeed",
    "ToggleHoverSpeed",
    "ToggleHeldSpeed",
}
local _baseAnimSpeeds = {}
for _, animSpeedKey in ipairs(_animSpeedKeys) do
    _baseAnimSpeeds[animSpeedKey] = Theme.Animation[animSpeedKey]
end

local _animDurationKeys = {
    "UIToggleDuration",
}
local _baseAnimDurations = {}
for _, animDurationKey in ipairs(_animDurationKeys) do
    _baseAnimDurations[animDurationKey] = Theme.Animation[animDurationKey]
end

function Theme.SetAnimationDuration(ms: number?)
    local msValue = if ms ~= nil then ms else Theme.Animation.DurationMS
    msValue = math.clamp(msValue, 0, 500)
    Theme.Animation.DurationMS = msValue
    local speedFactor = if msValue > 0 then 100 / msValue else 1e9
    local durationFactor = msValue / 100
    for animSpeedKey, animSpeedBase in pairs(_baseAnimSpeeds) do
        Theme.Animation[animSpeedKey] = animSpeedBase * speedFactor
    end
    for animDurationKey, animDurationBase in pairs(_baseAnimDurations) do
        Theme.Animation[animDurationKey] = animDurationBase * durationFactor
    end
end

function Theme.InitFont(importFn: (string) -> string)
    if importFn then
        local ok, fontAsset = pcall(importFn, "GoogleSans-Regular.ttf")
        if ok and fontAsset and fontAsset ~= "" then
            Theme.Font.Family = Font.new(fontAsset, Enum.FontWeight.Regular)
        end
        local glowOk, glowAsset = pcall(importFn, "GDH_Glow.png")
        if glowOk and glowAsset and glowAsset ~= "" then
            Theme.Colors.PopupGlow = glowAsset
        end
    end
end

function Theme.GetFontFace(): Font
    if Theme.Font.Family then
        return Theme.Font.Family
    end
    return Font.fromEnum(Theme.Font.FallbackEnum)
end

return Theme
