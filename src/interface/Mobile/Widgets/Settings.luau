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

local UserInputService = game:GetService("UserInputService")

local Theme = nil
local Animate = nil
local PressFlow = nil
local NumberInputCell = nil
local InfoPopup = nil
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
	if not NumberInputCell then
		NumberInputCell = importMobileModule("Widgets/NumberInput")
	end
	if not InfoPopup then
		InfoPopup = importMobileModule("Widgets/InfoPopup")
	end
	if not FitText then
		FitText = importMobileModule("FitText")
	end
end

export type SettingsConfig = {
	List: Instance,
	Overlay: any?,
	Root: Instance?,
	Fit: any?,
	Notify: any?,
	Icon: any?,
	ApplyIcon: any?,
}

local function SettingsTab(config: SettingsConfig)
	init()

	local layout = Theme.Layout
	local colors = Theme.Colors

	local list = config.List
	if typeof(list) ~= "Instance" then
		return
	end

	local state = genv.GDH_MOBILE_SETTINGS
	if typeof(state) ~= "table" then
		state = {
			IconScale = 0.5,
			MinOpacity = 0.8,
			NotifyUpdates = true,
		}
		genv.GDH_MOBILE_SETTINGS = state
	end
	if typeof(state.IconScale) ~= "number" then
		state.IconScale = 0.5
	end
	if typeof(state.MinOpacity) ~= "number" then
		state.MinOpacity = 0.8
	end
	if typeof(state.NotifyUpdates) ~= "boolean" then
		state.NotifyUpdates = true
	end

	local fitNode = config.Fit
	local fitValue = 1
	if typeof(fitNode) == "Instance" and (fitNode :: Instance):IsA("UIScale") then
		local scale = (fitNode :: UIScale).Scale
		if typeof(scale) == "number" and scale > 0 then
			fitValue = scale
		end
	end

	local popupHost: Instance = if typeof(config.Root) == "Instance" then config.Root :: Instance else list

	local notifyFn = if typeof(config.Notify) == "function" then config.Notify :: any else nil

	local function showInfo(titleText: string, messageText: string)
		if typeof(InfoPopup) == "table" and typeof(InfoPopup.Show) == "function" then
			pcall(InfoPopup.Show :: any, popupHost, titleText, messageText, fitValue)
			return
		end
		if typeof(notifyFn) == "function" then
			pcall(notifyFn :: any, titleText .. ": " .. messageText)
		end
	end

	local rowOrder = 0

	local function buildRow(height: number): Frame
		rowOrder += 1
		local frame = Instance.new("Frame")
		frame.Name = "SettingsRow" .. rowOrder
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Size = UDim2.new(1, 0, 0, height)
		frame.LayoutOrder = rowOrder
		frame.Parent = list
		return frame
	end

	local function buildSpacer(height: number)
		buildRow(height)
	end

	local function buildSeparator()
		local row = buildRow(18)
		local line = Instance.new("Frame")
		line.Name = "Line"
		line.BackgroundColor3 = colors.Separator
		line.BackgroundTransparency = 0.55
		line.BorderSizePixel = 0
		line.AnchorPoint = Vector2.new(0, 0.5)
		line.Position = UDim2.new(0, 0, 0.5, 0)
		line.Size = UDim2.new(1, 0, 0, 2)
		line.Parent = row
	end

	local popup: Frame? = nil
	local outsideConn: RBXScriptConnection? = nil
	local menuConn: RBXScriptConnection? = nil

	local function closeConfirm()
		if outsideConn ~= nil then
			pcall(function()
				outsideConn:Disconnect()
			end)
			outsideConn = nil
		end
		local current = popup
		popup = nil
		if current ~= nil then
			pcall(function()
				current:Destroy()
			end)
		end
	end

	local function hitRect(px: number, py: number, sx: number, sy: number, pos: Vector3): boolean
		return pos.X >= px and pos.X <= px + sx
			and pos.Y >= py and pos.Y <= py + sy
	end

	local function collectCheats(): { any }
		local rows: { any } = {}
		local UI = genv.GDH_UI
		if typeof(UI) ~= "table" then
			return rows
		end
		local hacks = UI._keybindHacks
		if typeof(hacks) ~= "table" then
			return rows
		end
		for _, entry in hacks :: { any } do
			if typeof(entry) == "table"
				and tostring(entry.Kind or "") == "Toggle"
			then
				local row = entry.Row
				if typeof(row) == "Instance" and (row :: Instance).Parent ~= nil
					and (row :: Instance):GetAttribute("Cheating") == true
				then
					table.insert(rows, entry)
				end
			end
		end
		return rows
	end

	local function cheatLabelOf(entry: any): string
		local name = entry.Name
		if typeof(name) == "string" and name ~= "" then
			return name
		end
		local row = entry.Row
		if typeof(row) == "Instance" then
			local rowFrame = row :: Instance
			local title = rowFrame:FindFirstChild("Title")
			if typeof(title) == "Instance"
				and ((title :: Instance):IsA("TextLabel") or (title :: Instance):IsA("TextButton"))
			then
				local text = (title :: TextLabel).Text
				if typeof(text) == "string" and text ~= "" then
					return text
				end
			end
			return rowFrame.Name
		end
		return "Unknown"
	end

	local function replayEngineActive(): boolean
		local replayState = genv.GDH_MOBILE_REPLAY
		if typeof(replayState) ~= "table" then
			return false
		end
		return replayState.Record == true
			or replayState.Play == true
			or replayState.Continue == true
	end

	local function disableCheats()
		local apis = genv.GDH_ToggleRowApis
		for _, entry in collectCheats() do
			local row = entry.Row
			if typeof(row) == "Instance" then
				local rowFrame = row :: Instance
				if rowFrame:GetAttribute("State") == true then
					local api = if typeof(apis) == "table" then apis[rowFrame] else nil
					if typeof(api) == "table" and typeof(api.SetState) == "function" then
						pcall(api.SetState :: any, false)
					else
						rowFrame:SetAttribute("State", false)
					end
				end
			end
		end
	end

	local function openConfirm()
		if popup ~= nil then
			return
		end
		closeConfirm()

		local popW = math.floor(layout.BgW * 0.65 + 0.5)
		local popH = math.floor(layout.BgH * 0.65 + 0.5)
		local btnW = math.floor(popW * 0.30 + 0.5)
		local btnH = math.floor(popH * 0.215 + 0.5)
		local btnGap = math.floor(popW * 0.02 + 0.5)
		local btnBottom = math.floor(popH * 0.094 + 0.5)
		local btnTextSize = math.floor(popH * 0.11 + 0.5)
		local titleSize = math.floor(popH * 0.15 + 0.5)
		local titleCenter = math.floor(popH * 0.18 + 0.5)
		local titleH = math.floor(titleSize * 1.15 + 0.5)
		local bodySize = math.floor(popH * 0.103 + 0.5)
		local bodyTop = titleCenter + math.floor(titleH / 2) + 12

		local container = Instance.new("Frame")
		container.Name = "ConfirmPopup"
		container.Active = true
		container.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		container.BackgroundTransparency = 0.45
		container.BorderSizePixel = 0
		container.Position = UDim2.fromScale(0, 0)
		container.Size = UDim2.fromScale(1, 1)
		container.ZIndex = 80
		container.Parent = popupHost

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
		panel.ZIndex = 81
		panel.Parent = container

		local panelCorner = Instance.new("UICorner")
		panelCorner.CornerRadius = UDim.new(0, math.floor(layout.BgCorner * (popW / layout.BgW) + 0.5))
		panelCorner.Parent = panel

		local panelStroke = Instance.new("UIStroke")
		panelStroke.Color = colors.MenuStroke
		panelStroke.Thickness = layout.BgStroke
		panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		panelStroke.Parent = panel

		local popScale = Instance.new("UIScale")
		popScale.Scale = fitValue
		popScale.Parent = panel

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.BorderSizePixel = 0
		title.Position = UDim2.fromOffset(0, titleCenter - math.floor(titleH / 2))
		title.Size = UDim2.new(1, 0, 0, titleH)
		title.FontFace = Theme.GetFace()
		title.Text = "Confimation"
		title.TextColor3 = Color3.fromRGB(255, 188, 29)
		title.TextSize = titleSize
		title.TextXAlignment = Enum.TextXAlignment.Center
		title.TextYAlignment = Enum.TextYAlignment.Center
		title.ZIndex = 82
		title.Parent = panel

		local body = Instance.new("TextLabel")
		body.Name = "Body"
		body.BackgroundTransparency = 1
		body.BorderSizePixel = 0
		body.Position = UDim2.fromOffset(30, bodyTop)
		body.Size = UDim2.new(1, -60, 1, -(bodyTop + btnH + btnBottom + 18))
		body.FontFace = Theme.GetFace()
		body.Text = "Are you sure you want to turn off cheating hacks?"
		body.TextColor3 = colors.TextPrimary
		body.TextSize = bodySize
		body.TextWrapped = true
		body.TextXAlignment = Enum.TextXAlignment.Center
		body.TextYAlignment = Enum.TextYAlignment.Center
		body.ZIndex = 82
		body.Parent = panel

		local function makeChoiceBtn(text: string, side: number, activate: () -> ())
			local btn = Instance.new("TextButton")
			btn.Name = text
			btn.AutoButtonColor = false
			btn.BackgroundColor3 = colors.SwitchTrackOff
			btn.BorderSizePixel = 0
			btn.AnchorPoint = if side < 0 then Vector2.new(1, 1) else Vector2.new(0, 1)
			btn.Position = UDim2.new(0.5, side * btnGap, 1, -btnBottom)
			btn.Size = UDim2.fromOffset(btnW, btnH)
			btn.FontFace = Theme.GetFace()
			btn.Text = text
			btn.TextColor3 = colors.TextPrimary
			btn.TextSize = btnTextSize
			btn.ZIndex = 83
			btn.Parent = panel

			local btnCorner = Instance.new("UICorner")
			btnCorner.CornerRadius = UDim.new(0, math.floor(btnH * 0.3 + 0.5))
			btnCorner.Parent = btn

			local btnStroke = Instance.new("UIStroke")
			btnStroke.Color = colors.MenuStroke
			btnStroke.Thickness = 2
			btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			btnStroke.Parent = btn

			local feedback = Animate.HoldFeedback(btn, btn, {
				Grow = 1.1,
				GrowTime = 0.15,
				ReleaseTime = 0.6,
				ReleaseStyle = Enum.EasingStyle.Elastic,
			})
			local target = {
				Node = btn,
				Activate = activate,
				PressIn = feedback.Press,
				PressOut = feedback.Reverse,
				Release = feedback.Release,
			}
			PressFlow.Register(target)

			btn.InputBegan:Connect(function(input: InputObject)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					PressFlow.Begin(target, input)
				end
			end)

			btn.Activated:Connect(function()
				pcall(activate)
			end)
		end

		makeChoiceBtn("No", -1, function()
			closeConfirm()
		end)
		makeChoiceBtn("Yes", 1, function()
			closeConfirm()
			disableCheats()
		end)

		popup = container

		outsideConn = UserInputService.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			if popup == nil then
				return
			end
			local keep = hitRect(
				panel.AbsolutePosition.X, panel.AbsolutePosition.Y,
				panel.AbsoluteSize.X, panel.AbsoluteSize.Y, input.Position)
			if not keep then
				closeConfirm()
			end
		end)
	end

	local function makeToggleRow(text: string, controller: any)
		local row = buildRow(layout.RowH)
		local rowList = Instance.new("UIListLayout")
		rowList.FillDirection = Enum.FillDirection.Horizontal
		rowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rowList.SortOrder = Enum.SortOrder.LayoutOrder
		rowList.Parent = row

		local cell = Instance.new("Frame")
		cell.Name = "ToggleCell"
		cell.BackgroundTransparency = 1
		cell.BorderSizePixel = 0
		cell.Size = UDim2.fromOffset(layout.CellW, layout.RowH)
		cell.LayoutOrder = 1
		cell.Parent = row

		local assets = Theme.GetAssets()
		local switchNode: GuiObject
		local applyState: (boolean) -> ()

		if assets.TogglerOn ~= nil and assets.TogglerOff ~= nil then
			local image = Instance.new("ImageButton")
			image.Name = "Switch"
			image.AutoButtonColor = false
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.BackgroundTransparency = 1
			image.BorderSizePixel = 0
			image.Position = UDim2.fromOffset(layout.SwitchX + layout.SwitchW / 2, layout.RowH / 2)
			image.Size = UDim2.fromOffset(layout.SwitchW, layout.SwitchH)
			image.Parent = cell
			switchNode = image
			applyState = function(isOn: boolean)
				image.Image = if isOn then assets.TogglerOn :: string else assets.TogglerOff :: string
			end
		else
			local track = Instance.new("TextButton")
			track.Name = "Switch"
			track.Text = ""
			track.AutoButtonColor = false
			track.AnchorPoint = Vector2.new(0.5, 0.5)
			track.BackgroundColor3 = colors.SwitchTrackOff
			track.BorderSizePixel = 0
			track.Position = UDim2.fromOffset(layout.SwitchX + layout.SwitchW / 2, layout.RowH / 2)
			track.Size = UDim2.fromOffset(layout.SwitchW, layout.SwitchH)
			local trackCorner = Instance.new("UICorner")
			trackCorner.CornerRadius = UDim.new(1, 0)
			trackCorner.Parent = track
			local inset = 3
			local knob = Instance.new("Frame")
			knob.Name = "Knob"
			knob.BackgroundColor3 = colors.SwitchKnobOff
			knob.BorderSizePixel = 0
			knob.Position = UDim2.fromOffset(inset, inset)
			knob.Size = UDim2.fromOffset(layout.SwitchH - inset * 2, layout.SwitchH - inset * 2)
			local knobCorner = Instance.new("UICorner")
			knobCorner.CornerRadius = UDim.new(1, 0)
			knobCorner.Parent = knob
			knob.Parent = track
			track.Parent = cell
			switchNode = track
			applyState = function(isOn: boolean)
				local targetX = if isOn then layout.SwitchW - layout.SwitchH + inset else inset
				Animate.Tween(track, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
					BackgroundColor3 = if isOn then colors.SwitchTrackOn else colors.SwitchTrackOff,
				})
				Animate.Tween(knob, 0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out, {
					Position = UDim2.fromOffset(targetX, inset),
					BackgroundColor3 = if isOn then colors.SwitchKnobOn else colors.SwitchKnobOff,
				})
			end
		end

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Position = UDim2.fromOffset(layout.LabelX, 0)
		label.Size = UDim2.new(1, -(layout.LabelX + layout.LabelInset), 1, 0)
		label.FontFace = Theme.GetFace()
		label.Text = text
		label.TextColor3 = colors.TextPrimary
		label.TextSize = layout.LabelSize
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = cell
		FitText.fit(label, {
			Base = layout.LabelSize,
			Min = layout.LabelMinSize,
		})

		local feedback = Animate.HoldFeedback(switchNode, switchNode, {
			Grow = 1.18,
			GrowTime = 0.15,
			ReleaseTime = 0.6,
			ReleaseStyle = Enum.EasingStyle.Elastic,
		})

		local function toggle()
			controller.Set(not controller.Get())
		end

		local target = {
			Node = switchNode,
			Activate = toggle,
			PressIn = feedback.Press,
			PressOut = feedback.Reverse,
			Release = feedback.Release,
		}
		PressFlow.Register(target)

		local pressStart: Vector3? = nil
		local pressTime = 0

		local function isOverSwitch(pos: Vector3): boolean
			local abs = switchNode.AbsolutePosition
			local size = switchNode.AbsoluteSize
			return pos.X >= abs.X and pos.X <= abs.X + size.X
				and pos.Y >= abs.Y and pos.Y <= abs.Y + size.Y
		end

		switchNode.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			pressStart = input.Position
			pressTime = os.clock()
			PressFlow.Begin(target, input)
		end)

		switchNode.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local start = pressStart
			local elapsed = os.clock() - pressTime
			pressStart = nil
			if start == nil then
				return
			end
			if not isOverSwitch(input.Position) then
				return
			end
			if elapsed > 0.3 then
				return
			end
			local delta = Vector2.new(input.Position.X - start.X, input.Position.Y - start.Y)
			if delta.Magnitude > 20 then
				return
			end
			toggle()
		end)

		applyState(controller.Get())
	end

	local function makeWideButton(text: string, activate: () -> ()): Frame
		local row = buildRow(layout.RowH)
		local btn = Instance.new("TextButton")
		btn.Name = "Button"
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = colors.TabInactive
		btn.BorderSizePixel = 0
		btn.AnchorPoint = Vector2.new(0.5, 0.5)
		btn.Position = UDim2.fromScale(0.5, 0.5)
		btn.Size = UDim2.new(1, -4, 0, layout.RowH)
		btn.FontFace = Theme.GetFace()
		btn.Text = text
		btn.TextColor3 = colors.TabInactiveText
		btn.TextSize = layout.LabelSize
		btn.TextTruncate = Enum.TextTruncate.AtEnd
		btn.Parent = row

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = colors.MenuStroke
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = btn
		pcall(function()
			stroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
		end)

		local feedback = Animate.HoldFeedback(btn, btn, {
			Grow = 1.1,
			GrowTime = 0.15,
			ReleaseTime = 0.6,
			ReleaseStyle = Enum.EasingStyle.Elastic,
		})

		local target = {
			Node = btn,
			Activate = activate,
			PressIn = feedback.Press,
			PressOut = feedback.Reverse,
			Release = feedback.Release,
		}
		PressFlow.Register(target)

		btn.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				PressFlow.Begin(target, input)
			end
		end)

		btn.Activated:Connect(function()
			pcall(activate)
		end)
		return row
	end

	local function showCheatList()
		local names: { string } = {}
		for _, entry in collectCheats() do
			local row = entry.Row
			if typeof(row) == "Instance" and (row :: Instance):GetAttribute("State") == true then
				table.insert(names, cheatLabelOf(entry))
			end
		end
		if replayEngineActive() then
			table.insert(names, "Replay Engine")
		end
		local text = table.concat(names, ", ")
		if text == "" then
			text = "No cheat hacks enabled"
		end
		showInfo("Cheat Hack Lists", text)
	end

	local function applyIconScale(value: number)
		state.IconScale = value
		local callback = config.ApplyIcon
		if typeof(callback) == "function" then
			pcall(callback :: any)
		end
	end

	local function applyMinOpacity(value: number)
		state.MinOpacity = value
		local icon = config.Icon
		if typeof(icon) == "table" and typeof(icon.SetMinOpacity) == "function" then
			pcall(icon.SetMinOpacity :: any, value)
		end
	end

	local inputsRow = buildRow(layout.RowH)
	local inputsList = Instance.new("UIListLayout")
	inputsList.FillDirection = Enum.FillDirection.Horizontal
	inputsList.Padding = UDim.new(0, 0)
	inputsList.SortOrder = Enum.SortOrder.LayoutOrder
	inputsList.Parent = inputsRow

	NumberInputCell({
		Parent = inputsRow,
		IsFloat = true,
		Name = "Icon Size (0.5 - 3)",
		Min = 0.5,
		Max = 3,
		Default = state.IconScale,
		Get = function(): number
			return state.IconScale
		end,
		Set = applyIconScale,
		SliderSplit = "left",
	})
	NumberInputCell({
		Parent = inputsRow,
		IsFloat = true,
		Name = "Min Opacity (0.25 - 1.f)",
		Min = 0.25,
		Max = 1,
		Default = state.MinOpacity,
		Get = function(): number
			return state.MinOpacity
		end,
		Set = applyMinOpacity,
		SliderSplit = "right",
	})

	buildSeparator()

	makeToggleRow("Notify about updates", {
		Get = function(): boolean
			return state.NotifyUpdates == true
		end,
		Set = function(on: boolean)
			state.NotifyUpdates = on
			if on == false then
				showInfo("Important", "Even if you turn off update popup, please keep GDH updated\n\nIt's still in beta, so updating helps avoid bugs and issues from older versions :(")
			end
		end,
	})

	buildSeparator()

	makeWideButton("Disable cheating hacks", function()
		openConfirm()
	end)

	buildSpacer(4)

	local tailRow = makeWideButton("Show Cheat Hack List", function()
		showCheatList()
	end)

	tailRow.Destroying:Connect(function()
		if menuConn ~= nil then
			pcall(function()
				menuConn:Disconnect()
			end)
			menuConn = nil
		end
		closeConfirm()
	end)

	local overlayMenu = config.Overlay
	if typeof(overlayMenu) == "Instance" then
		menuConn = (overlayMenu :: Instance):GetPropertyChangedSignal("Visible"):Connect(function()
			if (overlayMenu :: Instance).Visible == false then
				closeConfirm()
			end
		end)
	end
end

return SettingsTab
