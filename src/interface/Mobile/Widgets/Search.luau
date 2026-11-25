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
local ToggleCell = nil
local RadioCell = nil

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
	if not ToggleCell then
		ToggleCell = importMobileModule("Widgets/Toggle")
	end
	if not RadioCell then
		RadioCell = importMobileModule("Widgets/Radio")
	end
end

export type SearchConfig = {
	List: Instance,
	Notify: any?,
	BuildSettings: any?,
	Host: Instance?,
	Root: Instance?,
	FitScale: any?,
}

local function SearchTab(config: SearchConfig)
	init()

	local layout = Theme.Layout
	local colors = Theme.Colors

	local list = config.List
	if typeof(list) ~= "Instance" then
		return
	end

	local notifyFn = if typeof(config.Notify) == "function" then config.Notify :: any else nil

	local searchState = genv.GDH_MOBILE_SEARCH
	if typeof(searchState) ~= "table" then
		searchState = {
			Query = "",
		}
		genv.GDH_MOBILE_SEARCH = searchState
	end
	if typeof(searchState.Query) ~= "string" then
		searchState.Query = ""
	end

	local rowOrder = 0

	local function buildPlainRow(height: number): Frame
		rowOrder += 1
		local frame = Instance.new("Frame")
		frame.Name = "SearchRow" .. rowOrder
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Size = UDim2.new(1, 0, 0, height)
		frame.LayoutOrder = rowOrder
		frame.Parent = list
		return frame
	end

	local searchBar = buildPlainRow(64)

	local box = Instance.new("TextBox")
	box.Name = "Query"
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.BackgroundColor3 = colors.InputBG
	box.BorderSizePixel = 0
	box.Position = UDim2.new(0.4, -1, 0.5, 0)
	box.Size = UDim2.fromOffset(480, 60)
	box.FontFace = Theme.GetFace()
	box.TextColor3 = colors.TextPrimary
	box.PlaceholderColor3 = Color3.fromRGB(165, 165, 205)
	box.PlaceholderText = "Search hack..."
	box.Text = searchState.Query
	box.TextSize = layout.BoxTextSize
	box.ClearTextOnFocus = false
	box.ClipsDescendants = true
	box.TextXAlignment = Enum.TextXAlignment.Center
	box.Parent = searchBar

	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, layout.InputCorner)
	boxCorner.Parent = box

	local searchBtn = Instance.new("TextButton")
	searchBtn.Name = "SearchButton"
	searchBtn.AutoButtonColor = false
	searchBtn.BackgroundColor3 = colors.TabInactive
	searchBtn.BorderSizePixel = 0
	searchBtn.AnchorPoint = Vector2.new(1, 0.5)
	searchBtn.Position = UDim2.new(1, -15, 0.5, 0)
	searchBtn.Size = UDim2.fromOffset(155, 50)
	searchBtn.FontFace = Theme.GetFace()
	searchBtn.Text = "Search"
	searchBtn.TextColor3 = colors.TabInactiveText
	searchBtn.TextSize = layout.TabTextSize
	searchBtn.TextTruncate = Enum.TextTruncate.AtEnd
	searchBtn.Parent = searchBar

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, layout.TabCorner)
	btnCorner.Parent = searchBtn

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Thickness = 2
	btnStroke.Color = colors.MenuStroke
	btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	btnStroke.Parent = searchBtn
	pcall(function()
		btnStroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	end)

	local btnFeedback = Animate.HoldFeedback(searchBtn, searchBtn, {
		Grow = 1.15,
		GrowTime = 0.15,
		ReleaseTime = 0.6,
		ReleaseStyle = Enum.EasingStyle.Elastic,
	})
	local btnTarget = {
		Node = searchBtn,
		PressIn = btnFeedback.Press,
		PressOut = btnFeedback.Reverse,
		Release = btnFeedback.Release,
	}
	PressFlow.Register(btnTarget)

	searchBtn.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			PressFlow.Begin(btnTarget, input)
		end
	end)

	local resultsHolder = Instance.new("Frame")
	resultsHolder.Name = "Results"
	resultsHolder.BackgroundTransparency = 1
	resultsHolder.BorderSizePixel = 0
	resultsHolder.Size = UDim2.new(1, 0, 0, 0)
	resultsHolder.LayoutOrder = rowOrder + 1
	resultsHolder.AutomaticSize = Enum.AutomaticSize.Y
	local resultsLayout = Instance.new("UIListLayout")
	resultsLayout.Padding = UDim.new(0, 4)
	resultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	resultsLayout.Parent = resultsHolder
	resultsHolder.Parent = list

	local resultOrder = 0
	local resultRow: Frame? = nil
	local resultCellCount = 0
	local resultListLayout: UIListLayout? = nil

	local function beginResultCell(): Frame
		if resultRow == nil or resultCellCount >= 2 then
			resultOrder += 1
			local frame = Instance.new("Frame")
			frame.Name = "ResultRow" .. resultOrder
			frame.BackgroundTransparency = 1
			frame.BorderSizePixel = 0
			frame.Size = UDim2.fromOffset(layout.ListW, layout.RowH)
			frame.LayoutOrder = resultOrder
			frame.Parent = resultsHolder
			local rowList = Instance.new("UIListLayout")
			rowList.FillDirection = Enum.FillDirection.Horizontal
			rowList.Padding = UDim.new(0, 0)
			rowList.SortOrder = Enum.SortOrder.LayoutOrder
			rowList.Parent = frame
			resultRow = frame
			resultListLayout = rowList
			resultCellCount = 0
		end
		resultCellCount += 1
		if resultListLayout ~= nil then
			resultListLayout.HorizontalAlignment = if resultCellCount == 1
				then Enum.HorizontalAlignment.Center
				else Enum.HorizontalAlignment.Left
		end
		return resultRow :: Frame
	end

	local function buildResultHint(text: string)
		resultOrder += 1
		local row = Instance.new("Frame")
		row.Name = "ResultRow" .. resultOrder
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Size = UDim2.fromOffset(layout.ListW, 40)
		row.LayoutOrder = resultOrder
		row.Parent = resultsHolder
		local label = Instance.new("TextLabel")
		label.Name = "Hint"
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Size = UDim2.new(1, 0, 1, 0)
		label.FontFace = Theme.GetFace()
		label.Text = text
		label.TextColor3 = colors.TextPrimary
		label.TextSize = 26
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Parent = row
	end

	local function trimmedLower(text: any): string
		local value = if typeof(text) == "string" then text else tostring(text or "")
		value = string.gsub(value, "^%s+", "")
		value = string.gsub(value, "%s+$", "")
		return string.lower(value)
	end

	local function resultLabelOf(entry: any): string
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
		return ""
	end

	local function collectMatches(query: string): { any }
		local matches: { any } = {}
		local UI = genv.GDH_UI
		if typeof(UI) ~= "table" then
			return matches
		end
		local hacks = UI._keybindHacks
		if typeof(hacks) ~= "table" then
			return matches
		end
		for _, entry in hacks :: { any } do
			if typeof(entry) ~= "table" then
				continue
			end
			local win = entry.Window
			if typeof(win) ~= "table" or win._popup == true then
				continue
			end
			local root = win.Root
			if typeof(root) == "Instance"
				and (root :: Instance):GetAttribute("GDHSearchExclude") == true
			then
				continue
			end
			if tostring(win._title or "") == "Invisible" then
				continue
			end
			local kind = tostring(entry.Kind or "")
			if kind ~= "Toggle" and kind ~= "Radio" then
				continue
			end
			local row = entry.Row
			if typeof(row) ~= "Instance" or (row :: Instance).Parent == nil then
				continue
			end
			if (row :: Instance):GetAttribute("GDHNoSearch") == true then
				continue
			end
			local label = resultLabelOf(entry)
			if label ~= "" and string.find(string.lower(label), query, 1, true) ~= nil then
				table.insert(matches, entry)
			end
		end
		return matches
	end

	local function refresh()
		for _, child in resultsHolder:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		resultOrder = 0
		resultRow = nil
		resultCellCount = 0
		resultListLayout = nil

		searchState.Query = box.Text
		local query = trimmedLower(box.Text)

		if query == "" then
			buildResultHint("Type a query and press Search")
			return
		end

		local matches = collectMatches(query)
		if #matches == 0 then
			buildResultHint("No hacks found matching query")
			return
		end
		local prevMatchKind: string? = nil
		for index, entry in matches do
			local kind = tostring(entry.Kind or "Toggle")
			local nextEntry = matches[index + 1]
			local nextKind = if nextEntry ~= nil then tostring(nextEntry.Kind or "Toggle") else nil
			local parent = beginResultCell()
			local split: string? = nil
			if resultCellCount == 2 then
				if prevMatchKind == "Toggle" or prevMatchKind == "Radio" then
					split = "right"
				end
			elseif nextKind == "Toggle" or nextKind == "Radio" then
				split = "left"
			end
			prevMatchKind = kind
			if kind == "Radio" then
				RadioCell({
					Row = entry.Row,
					Name = entry.Name,
					Parent = parent,
					Notify = notifyFn,
					SliderSplit = split,
				})
			else
				local settingsConfig = nil
				if typeof(config.BuildSettings) == "function" then
					local ok, built = pcall(config.BuildSettings :: any, entry)
					if ok and typeof(built) == "table" then
						settingsConfig = built
					end
				end
				ToggleCell({
					Row = entry.Row,
					Name = entry.Name,
					Description = entry.Description,
					Parent = parent,
					Notify = notifyFn,
					SliderSplit = split,
					Settings = settingsConfig,
					Host = config.Host,
					Root = config.Root,
					FitScale = config.FitScale,
				})
			end
		end
	end

	searchBtn.Activated:Connect(function()
		refresh()
	end)

	refresh()
end

return SearchTab
