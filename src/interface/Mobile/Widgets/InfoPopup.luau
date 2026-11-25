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
	return require(parent[name])
end

local Theme = nil
local Animate = nil
local PressFlow = nil

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
end

local InfoPopup = {}

local current: Frame? = nil
local hostConn: RBXScriptConnection? = nil

function InfoPopup.Close()
	if hostConn ~= nil then
		pcall(function()
			hostConn:Disconnect()
		end)
		hostConn = nil
	end
	local existing = current
	current = nil
	if existing ~= nil then
		pcall(function()
			existing:Destroy()
		end)
	end
end

function InfoPopup.Show(host: Instance, titleText: string, messageText: string, panelScale: number?)
	init()
	InfoPopup.Close()
	if typeof(host) ~= "Instance" then
		return
	end
	local menuFrame = host :: Frame
	if menuFrame.Parent == nil then
		return
	end

	local layout = Theme.Layout
	local colors = Theme.Colors

	local infoW = math.floor(layout.BgW * 0.65 + 0.5)
	local infoH = math.floor(layout.BgH * 0.65 + 0.5)
	local corner = math.floor(layout.BgCorner * (infoW / layout.BgW) + 0.5)
	local okW = math.floor(infoW * 0.18 + 0.5)
	local okH = math.floor(infoH * 0.215 + 0.5)
	local okBottom = math.floor(infoH * 0.094 + 0.5)
	local titleSize = math.floor(infoH * 0.15 + 0.5)
	local titleCenter = math.floor(infoH * 0.18 + 0.5)
	local titleH = math.floor(titleSize * 1.15 + 0.5)
	local bodySize = math.floor(infoH * 0.103 + 0.5)
	local bodyTop = titleCenter + math.floor(titleH / 2) + 12
	local okTextSize = math.floor(infoH * 0.11 + 0.5)

	local container = Instance.new("Frame")
	container.Name = "InfoPopup"
	container.Active = true
	container.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	container.BackgroundTransparency = 0.45
	container.BorderSizePixel = 0
	container.Position = UDim2.fromOffset(-2, -2)
	container.Size = UDim2.new(1, 12, 1, 12)
	container.ZIndex = 70
	container.Parent = menuFrame

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
	panel.Size = UDim2.fromOffset(infoW, infoH)
	panel.ZIndex = 71
	panel.Parent = container

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, corner)
	panelCorner.Parent = panel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = colors.MenuStroke
	panelStroke.Thickness = layout.BgStroke
	panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	panelStroke.Parent = panel

	local popScale = Instance.new("UIScale")
	popScale.Scale = if typeof(panelScale) == "number" and panelScale > 0 then panelScale else 1
	popScale.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.BorderSizePixel = 0
	title.Position = UDim2.fromOffset(0, titleCenter - math.floor(titleH / 2))
	title.Size = UDim2.new(1, 0, 0, titleH)
	title.FontFace = Theme.GetFace()
	title.Text = tostring(titleText or "Info")
	title.TextColor3 = Color3.fromRGB(255, 188, 29)
	title.TextSize = titleSize
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.ZIndex = 72
	title.Parent = panel

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(30, bodyTop)
	body.Size = UDim2.new(1, -60, 1, -(bodyTop + okH + okBottom + 18))
	body.FontFace = Theme.GetFace()
	body.Text = tostring(messageText or "")
	body.TextColor3 = colors.TextPrimary
	body.TextSize = bodySize
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Center
	body.TextYAlignment = Enum.TextYAlignment.Center
	body.ZIndex = 72
	body.Parent = panel

	local okBtn = Instance.new("TextButton")
	okBtn.Name = "OK"
	okBtn.AutoButtonColor = false
	okBtn.BackgroundColor3 = colors.SwitchTrackOff
	okBtn.BorderSizePixel = 0
	okBtn.AnchorPoint = Vector2.new(0.5, 1)
	okBtn.Position = UDim2.new(0.5, 0, 1, -okBottom)
	okBtn.Size = UDim2.fromOffset(okW, okH)
	okBtn.FontFace = Theme.GetFace()
	okBtn.Text = "OK"
	okBtn.TextColor3 = colors.TextPrimary
	okBtn.TextSize = okTextSize
	okBtn.ZIndex = 73
	okBtn.Parent = panel

	local okCorner = Instance.new("UICorner")
	okCorner.CornerRadius = UDim.new(0, math.floor(okH * 0.3 + 0.5))
	okCorner.Parent = okBtn

	local okStroke = Instance.new("UIStroke")
	okStroke.Color = colors.MenuStroke
	okStroke.Thickness = 2
	okStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	okStroke.Parent = okBtn

	local feedback = Animate.HoldFeedback(okBtn, okBtn, {
		Grow = 1.1,
		GrowTime = 0.15,
		ReleaseTime = 0.6,
		ReleaseStyle = Enum.EasingStyle.Elastic,
	})
	local okTarget = {
		Node = okBtn,
		PressIn = feedback.Press,
		PressOut = feedback.Reverse,
		Release = feedback.Release,
	}
	PressFlow.Register(okTarget)

	okBtn.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			PressFlow.Begin(okTarget, input)
		end
	end)

	okBtn.Activated:Connect(function()
		InfoPopup.Close()
	end)

	current = container

	container.Destroying:Connect(function()
		if current == container then
			current = nil
		end
	end)

	hostConn = menuFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if menuFrame.Visible == false then
			InfoPopup.Close()
		end
	end)
end

return InfoPopup
