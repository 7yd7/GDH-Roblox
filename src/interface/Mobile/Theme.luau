local MobileTheme = {}

MobileTheme.Colors = {
    MenuBG = Color3.fromRGB(33, 33, 79),
    MenuStroke = Color3.fromRGB(202, 186, 242),
    SidebarBG = Color3.fromRGB(50, 50, 108),
    TabActive = Color3.fromRGB(202, 186, 242),
    TabActiveText = Color3.fromRGB(33, 33, 78),
    TabInactive = Color3.fromRGB(71, 71, 132),
    TabInactiveText = Color3.fromRGB(255, 255, 255),
    TextPrimary = Color3.fromRGB(255, 255, 255),
    SwitchTrackOn = Color3.fromRGB(202, 186, 242),
    SwitchTrackOff = Color3.fromRGB(71, 71, 132),
    SwitchKnobOn = Color3.fromRGB(33, 33, 78),
    SwitchKnobOff = Color3.fromRGB(202, 186, 242),
    ButtonBG = Color3.fromRGB(202, 186, 242),
    ButtonText = Color3.fromRGB(33, 33, 78),
    InputBG = Color3.fromRGB(71, 71, 131),
    RadioRingOff = Color3.fromRGB(133, 133, 191),
    Separator = Color3.fromRGB(104, 104, 191),
    TextDanger = Color3.fromRGB(225, 115, 121),
}

MobileTheme.Layout = {
    MenuW = 943,
    MenuH = 574,
    BgW = 948,
    BgH = 580,
    BgCorner = 44,
    BgStroke = 4,
    SidebarX = 11,
    SidebarY = 9,
    SidebarW = 206,
    SidebarH = 558,
    SidebarCorner = 30,
    SidebarPad = 12,
    ListX = 231,
    ListY = 21,
    ListW = 700,
    ListH = 559,
    ListPad = 8,
    CellGap = 12,
    RowH = 54,
    SwitchW = 80,
    SwitchH = 44,
    SwitchX = 6,
    LabelX = 96,
    LabelInset = 30,
    LabelMinSize = 14,
    LabelSize = 35,
    InfoSize = 22,
    TabW = 175,
    TabH = 53,
    TabCorner = 24,
    TabTextSize = 28,
    EmptySize = 18,
    IconBase = 56,
    ButtonCorner = 16,
    BoxH = 40,
    BoxCorner = 14,
    BoxTextSize = 26,
    InputW = 96,
    InputH = 40,
    InputCorner = 8,
    DropItemH = 44,
    DropMaxH = 260,
    ArrowW = 40,
    SliderBoxW = 100,
    SliderToggleX = 0.6,
}
MobileTheme.Layout.CellW = math.floor((MobileTheme.Layout.ListW - MobileTheme.Layout.CellGap) / 2)

MobileTheme.FontFace = nil
MobileTheme._assets = nil

function MobileTheme.GetFace(): Font
    if MobileTheme.FontFace ~= nil then
        return MobileTheme.FontFace
    end
    local genv = (typeof(getgenv) == "function" and getgenv())
        or (typeof(_G) == "table" and _G)
        or {}
    local Import = genv.Import
    if typeof(Import) == "table" then
        local ok, asset = pcall(function()
            return Import("Assets/GDH/GoogleSans-Regular.ttf")
        end)
        if ok and typeof(asset) == "string" and asset ~= "" then
            local okFont, face = pcall(Font.new, asset, Enum.FontWeight.Regular)
            if okFont and face ~= nil then
                MobileTheme.FontFace = face
                return face
            end
        end
    end
    local UI = genv.GDH_UI
    if typeof(UI) == "table" and typeof(UI.Theme) == "table" and typeof(UI.Theme.GetFontFace) == "function" then
        local okFace, pcFace = pcall(UI.Theme.GetFontFace)
        if okFace and pcFace ~= nil then
            MobileTheme.FontFace = pcFace
            return pcFace
        end
    end
    MobileTheme.FontFace = Font.fromEnum(Enum.Font.GothamMedium)
    return MobileTheme.FontFace
end

function MobileTheme.GetAssets(): { [string]: string? }
    if MobileTheme._assets ~= nil then
        return MobileTheme._assets
    end
    local assets: { [string]: string? } = {}
    local genv = (typeof(getgenv) == "function" and getgenv())
        or (typeof(_G) == "table" and _G)
        or {}
    local Import = genv.Import
    local function tryLoad(key: string, fileName: string)
        if typeof(Import) == "table" and typeof(Import.Asset) == "function" then
            local ok, asset = pcall(Import.Asset, "Assets/GDH/" .. fileName)
            if ok and typeof(asset) == "string" and asset ~= "" then
                assets[key] = asset
            end
        end
    end
    tryLoad("TogglerOn", "GDH_togglerOn.png")
    tryLoad("TogglerOff", "GDH_togglerOff.png")
    tryLoad("Logo", "GDH_logo.png")
    tryLoad("Arrow", "GDH_arrow.png")
    tryLoad("Remove", "GDH_removeBtn.png")
    tryLoad("Import", "GDH_importBtn.png")
    tryLoad("Close", "GDH_closeBtn.png")
    tryLoad("Settings", "GDH_settingsBtn.png")
    tryLoad("Info", "GDH_infoIcon.png")
    tryLoad("ButtonUI", "GDH_buttonUI.png")
    MobileTheme._assets = assets
    return assets
end

return MobileTheme
