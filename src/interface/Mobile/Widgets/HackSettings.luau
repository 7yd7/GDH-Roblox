local function importMobileModule(name: string)
	local genv = (typeof(getgenv) == "function" and getgenv())
		or (typeof(_G) == "table" and _G)
		or {}
	local Import = genv.Import
	if Import then
		local module = Import("interface/Mobile/" .. name)
		if module ~= nil then
			return module
		end
	end
	local parent = script.Parent
	if parent.Name == "Widgets" then
		parent = parent.Parent
	end
	local widgetsPrefix = "Widgets/"
	if string.sub(name, 1, #widgetsPrefix) == widgetsPrefix then
		return require(parent.Widgets[string.sub(name, #widgetsPrefix + 1)])
	end
	return require(parent[name])
end

local genv = (typeof(getgenv) == "function" and getgenv())
	or (typeof(_G) == "table" and _G)
	or {}

local Theme = nil
local Animate = nil
local PressFlow = nil
local NumberInput = nil
local ToggleCell = nil
local SliderCell = nil
local ButtonRow = nil
local FitText = nil

local function init()
	if not Theme then
		Theme = importMobileModule("Theme")
	end
	if not Animate then
		Animate = importMobileModule("Animate")
	end
	if not PressFlow then
		PressFlow = importMobileModule("PressFlow")
	end
	if not NumberInput then
		NumberInput = importMobileModule("Widgets/NumberInput")
	end
	if not ToggleCell then
		ToggleCell = importMobileModule("Widgets/Toggle")
	end
	if not SliderCell then
		SliderCell = importMobileModule("Widgets/Slider")
	end
	if not ButtonRow then
		ButtonRow = importMobileModule("Widgets/Button")
	end
	if not FitText then
		FitText = importMobileModule("FitText")
	end
end

local activeClose: any? = nil

export type HackSettingsConfig = {
	Overlay: Instance?,
	Root: Instance?,
	Fit: Instance?,
	Title: string?,
	Items: { any }?,
	Notify: ((string, number?) -> ())?,
}

local titleColors: { Color3 } = {
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(225, 115, 121),
	Color3.fromRGB(120, 220, 130),
	Color3.fromRGB(120, 180, 255),
	Color3.fromRGB(255, 220, 100),
}

local titleColorNames: { string } = {
	"White",
	"Red",
	"Green",
	"Blue",
	"Yellow",
}

local HackSettings = {}

function HackSettings.Show(config: HackSettingsConfig)
	init()

	local layout = Theme.Layout
	local colors = Theme.Colors

	local notifyFn = if typeof(config.Notify) == "function" then config.Notify :: any else nil
	local items = config.Items
	if typeof(items) ~= "table" then
		items = {}
	end

	if typeof(activeClose) == "function" then
		pcall(activeClose :: any)
	end
	local previousClose = genv.GDH_MOBILE_POPUP_CLOSE
	if typeof(previousClose) == "function" then
		pcall(previousClose :: any)
	end
	local menu = config.Overlay
	if typeof(menu) ~= "Instance" then
		return
	end
	local popHost: Instance = if typeof(config.Root) == "Instance" then config.Root :: Instance else menu :: Instance

	local popW = 516
	local popH = 477
	local closeW = math.floor(119 * (popW / 1010) + 0.5)
	local closeH = math.floor(closeW / 0.96748 + 0.5)
	local closeX = -math.floor(popW * 0.05158 + 0.5)
	local closeY = -math.floor(popH * 0.07281 + 0.5)

	local popup: Frame? = nil
	local popupConn: RBXScriptConnection? = nil
	local itemSyncConns: { RBXScriptConnection } = {}

	local function closePopup()
		if popupConn ~= nil then
			pcall(function()
				popupConn:Disconnect()
			end)
			popupConn = nil
		end
		for _, conn in itemSyncConns do
			pcall(function()
				conn:Disconnect()
			end)
		end
		table.clear(itemSyncConns)
		if activeClose == closePopup then
			activeClose = nil
		end
		if genv.GDH_MOBILE_POPUP_CLOSE == closePopup then
			genv.GDH_MOBILE_POPUP_CLOSE = nil
		end
		local current = popup
		popup = nil
		if current ~= nil then
			pcall(function()
				current:Destroy()
			end)
		end
	end

	local container = Instance.new("Frame")
	container.Name = "HackSettingsPopup"
	container.Active = true
	container.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	container.BackgroundTransparency = 0.45
	container.BorderSizePixel = 0
	container.Position = UDim2.fromScale(0, 0)
	container.Size = UDim2.fromScale(1, 1)
	container.ZIndex = 60
	container.Parent = popHost

	PressFlow.Register({
		Node = container,
	})

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Active = true
	panel.BackgroundColor3 = colors.MenuBG
	panel.BorderSizePixel = 0
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.Size = UDim2.fromOffset(popW, popH)
	panel.ZIndex = 61
	panel.Parent = container

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, math.floor(layout.BgCorner * (popW / layout.BgW) + 0.5))
	panelCorner.Parent = panel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = colors.MenuStroke
	panelStroke.Thickness = layout.BgStroke
	panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	panelStroke.Parent = panel

	local fitNode = config.Fit
	local fitValue = 1
	if typeof(fitNode) == "Instance" and (fitNode :: Instance):IsA("UIScale") then
		fitValue = (fitNode :: UIScale).Scale
	end

	local popScale = Instance.new("UIScale")
	popScale.Scale = fitValue * 0.55
	popScale.Parent = panel
	Animate.Tween(popScale, 0.8, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, {
		Scale = fitValue,
	})

	local assets = Theme.GetAssets()

	local closeBtn: GuiObject
	if typeof(assets.Close) == "string" and (assets.Close :: string) ~= "" then
		local closeImage = Instance.new("ImageButton")
		closeImage.Name = "Close"
		closeImage.AutoButtonColor = false
		closeImage.BackgroundTransparency = 1
		closeImage.BorderSizePixel = 0
		closeImage.Position = UDim2.fromOffset(closeX, closeY)
		closeImage.Size = UDim2.fromOffset(closeW, closeH)
		closeImage.Image = assets.Close :: string
		closeImage.ScaleType = Enum.ScaleType.Fit
		closeImage.ZIndex = 64
		closeImage.Parent = panel
		closeBtn = closeImage
	else
		local closeText = Instance.new("TextButton")
		closeText.Name = "Close"
		closeText.AutoButtonColor = false
		closeText.BackgroundColor3 = colors.SwitchTrackOff
		closeText.BorderSizePixel = 0
		closeText.Position = UDim2.fromOffset(closeX, closeY)
		closeText.Size = UDim2.fromOffset(closeW, closeH)
		closeText.FontFace = Theme.GetFace()
		closeText.Text = "✕"
		closeText.TextColor3 = colors.TextPrimary
		closeText.TextSize = layout.LabelSize
		closeText.ZIndex = 64
		closeText.Parent = panel
		local closeCorner = Instance.new("UICorner")
		closeCorner.CornerRadius = UDim.new(1, 0)
		closeCorner.Parent = closeText
		closeBtn = closeText
	end

	local closeFeedback = Animate.HoldFeedback(closeBtn, closeBtn, {
		Grow = 1.18,
		GrowTime = 0.15,
		ReleaseTime = 0.6,
		ReleaseStyle = Enum.EasingStyle.Elastic,
	})
	local closeTarget = {
		Node = closeBtn,
		PressIn = closeFeedback.Press,
		PressOut = closeFeedback.Reverse,
		Release = closeFeedback.Release,
	}
	PressFlow.Register(closeTarget)

	closeBtn.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			PressFlow.Begin(closeTarget, input)
		end
	end)

	closeBtn.Activated:Connect(function()
		closePopup()
	end)

	local contentTop = 60
	local itemTextSize = layout.LabelSize

	local titleText = tostring(config.Title or "Settings")
	if string.sub(string.lower(titleText), -8) ~= "settings" then
		titleText = titleText .. " Settings"
	end

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.BorderSizePixel = 0
	title.Position = UDim2.fromOffset(0, 0)
	title.Size = UDim2.new(1, 0, 0, 44)
	title.AutomaticSize = Enum.AutomaticSize.None
	title.FontFace = Theme.GetFace()
	title.Text = titleText
	title.TextColor3 = colors.TextPrimary
	title.TextSize = 36
	title.TextTruncate = Enum.TextTruncate.None
	title.TextWrapped = false
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = 62
	title.Parent = panel
	FitText.fit(title, {
		Base = 36,
		Min = 16,
	})

	if #items == 0 then
		local empty = Instance.new("TextLabel")
		empty.Name = "Empty"
		empty.BackgroundTransparency = 1
		empty.BorderSizePixel = 0
		empty.Position = UDim2.fromOffset(30, contentTop)
		empty.Size = UDim2.new(1, -60, 1, -(contentTop + 24))
		empty.FontFace = Theme.GetFace()
		empty.Text = "No settings available"
		empty.TextColor3 = colors.RadioRingOff
		empty.TextSize = itemTextSize
		empty.TextXAlignment = Enum.TextXAlignment.Center
		empty.TextYAlignment = Enum.TextYAlignment.Center
		empty.ZIndex = 62
		empty.Parent = panel
	else
		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "Items"
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.Position = UDim2.fromOffset(30, contentTop)
		scroll.Size = UDim2.new(1, -60, 1, -contentTop)
		scroll.ScrollBarThickness = 0
		scroll.ScrollBarImageTransparency = 1
		scroll.ScrollingDirection = Enum.ScrollingDirection.Y
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.fromScale(0, 0)
		scroll.ElasticBehavior = Enum.ElasticBehavior.Always
		scroll.Selectable = false
		scroll.ZIndex = 62
		scroll.Parent = panel

		local scrollLayout = Instance.new("UIListLayout")
		scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
		scrollLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		scrollLayout.Padding = UDim.new(0, 20)
		scrollLayout.Parent = scroll

		local index = 0
		for _, item in items :: { any } do
			if typeof(item) ~= "table" then
				continue
			end
			index += 1
			local kind = tostring(item.Kind or "Button")

			local wrapper = Instance.new("Frame")
			wrapper.Name = "Item" .. index
			wrapper.BackgroundTransparency = 1
			wrapper.BorderSizePixel = 0
			wrapper.Size = UDim2.new(1, 0, 0, layout.RowH)
			wrapper.LayoutOrder = index
			wrapper.ZIndex = 62
			wrapper.Parent = scroll

			if kind == "Toggle" then
				ToggleCell({
					Row = item.Row,
					Name = item.Text,
					Parent = wrapper,
					Notify = notifyFn,
					Center = true,
				})
			elseif kind == "Slider" then
				local sliderFrame = SliderCell({
					Parent = wrapper,
					Row = item.Row,
					Name = item.Name,
					Suffix = item.Suffix,
					Min = item.Min,
					Max = item.Max,
					Increment = item.Increment,
					Precision = item.Precision,
					HasToggle = item.HasToggle,
					Center = true,
				})
				local valueBox = sliderFrame:FindFirstChild("Value", true)
				local mirrorRow = item.Row
				if typeof(mirrorRow) == "Instance" and typeof(valueBox) == "TextBox" then
					local precision = 2
					if typeof(item.Precision) == "number" then
						precision = math.clamp(item.Precision :: number, 0, 6)
					end
					table.insert(itemSyncConns, (mirrorRow :: Instance):GetAttributeChangedSignal("GDHSettingValue"):Connect(function()
						local value = (mirrorRow :: Instance):GetAttribute("GDHSettingValue")
						if typeof(value) ~= "number" then
							return
						end
						(valueBox :: TextBox).Text = string.format("%." .. precision .. "f", value)
					end))
				end
			elseif kind == "Color" then
				local getter = item.Get
				local setter = item.Set

				local function colorIndexOf(color: any): number
					for i = 1, #titleColors do
						if titleColors[i] == color then
							return i
						end
					end
					return 0
				end

				local function currentColor(): any
					if typeof(getter) == "function" then
						local ok, value = pcall(getter :: any)
						if ok then
							return value
						end
					end
					return nil
				end

				local function rowText(): string
					local colorIndex = colorIndexOf(currentColor())
					local colorName = "Default"
					if colorIndex > 0 then
						colorName = titleColorNames[colorIndex]
					end
					return tostring(item.Text or "Title Color") .. ": " .. colorName
				end

				local function cycle()
					local nextIndex = colorIndexOf(currentColor()) + 1
					if nextIndex == 1 or nextIndex > #titleColors then
						nextIndex = 2
					end
					if typeof(setter) == "function" then
						pcall(setter :: any, titleColors[nextIndex])
					end
				end

				local buttonFrame = ButtonRow({
					Parent = wrapper,
					Buttons = { { Text = rowText(), Fire = cycle } },
				})

				local function refreshText()
					local slot = buttonFrame:FindFirstChild("Slot1")
					if typeof(slot) ~= "Instance" then
						return
					end
					local node = (slot :: Instance):FindFirstChild("Button1")
					if typeof(node) == "TextButton" then
						(node :: TextButton).Text = rowText()
					end
				end

				local mirrorRow = item.Row
				if typeof(mirrorRow) == "Instance" then
					table.insert(itemSyncConns, (mirrorRow :: Instance):GetAttributeChangedSignal("GDHSettingValue"):Connect(function()
						refreshText()
					end))
				end
			elseif kind == "Int" or kind == "Float" then
				local isFloat = kind == "Float"
				local inputCell = NumberInput({
					Parent = wrapper,
					IsFloat = isFloat,
					Name = tostring(item.Text or ""),
					Min = item.Min,
					Max = item.Max,
					Default = item.Default,
					Get = item.Get,
					Set = item.Set,
					Center = true,
				})

				local mirrorRow = item.Row
				if typeof(mirrorRow) == "Instance" then
					table.insert(itemSyncConns, (mirrorRow :: Instance):GetAttributeChangedSignal("GDHSettingValue"):Connect(function()
						local value = (mirrorRow :: Instance):GetAttribute("GDHSettingValue")
						if typeof(value) ~= "number" then
							return
						end
						local box = inputCell:FindFirstChild("Input", true)
						if typeof(box) == "TextBox" then
							(box :: TextBox).Text = if isFloat
								then string.format("%.2f", value)
								else tostring(math.floor(value + 0.5))
						end
					end))
				end
			elseif kind == "Separator" then
				local height = 18
				local source = item.Row
				if typeof(source) == "Instance" then
					local pcHeight = (source :: Instance).Size.Y.Offset
					if pcHeight > 0 then
						height = math.clamp(pcHeight, 14, 48)
					end
				end
				wrapper.Size = UDim2.new(1, 0, 0, height)
				local line = Instance.new("Frame")
				line.Name = "Line"
				line.BackgroundColor3 = colors.Separator
				line.BackgroundTransparency = 0.55
				line.BorderSizePixel = 0
				line.AnchorPoint = Vector2.new(0, 0.5)
				line.Position = UDim2.new(0, 0, 0.5, 0)
				line.Size = UDim2.new(1, 0, 0, 2)
				line.ZIndex = 62
				line.Parent = wrapper
			elseif kind == "Label" then
				local labelText = Instance.new("TextLabel")
				labelText.Name = "Text"
				labelText.BackgroundTransparency = 1
				labelText.BorderSizePixel = 0
				labelText.Position = UDim2.fromOffset(0, 0)
				labelText.Size = UDim2.new(1, 0, 1, 0)
				labelText.AutomaticSize = Enum.AutomaticSize.None
				labelText.FontFace = Theme.GetFace()
				labelText.Text = tostring(item.Text or "")
				labelText.TextColor3 = colors.TextPrimary
				labelText.TextSize = itemTextSize
				labelText.TextTruncate = Enum.TextTruncate.None
				labelText.TextWrapped = false
				labelText.TextXAlignment = Enum.TextXAlignment.Center
				labelText.ZIndex = 62
				labelText.Parent = wrapper
				FitText.fit(labelText, {
					Base = itemTextSize,
					Min = 14,
				})
			else
				ButtonRow({
					Parent = wrapper,
					Buttons = { { Text = item.Text, Fire = item.Fire } },
				})
			end
		end
	end

	popup = container
	activeClose = closePopup
	genv.GDH_MOBILE_POPUP_CLOSE = closePopup

	popupConn = (menu :: Instance):GetPropertyChangedSignal("Visible"):Connect(function()
		if (menu :: Instance).Visible == false then
			closePopup()
		end
	end)
end

return HackSettings
