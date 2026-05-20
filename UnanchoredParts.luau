-- ============================================================================
-- ORBIT ISLAND  |  Full-featured local script
-- Tabs: Shapes • Settings • Protect • Target
-- ============================================================================

-- ── Services ─────────────────────────────────────────────────────────────────
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- ── Island model ─────────────────────────────────────────────────────────────
local IslandModel = workspace:FindFirstChild("Island") and Workspace:WaitForChild("Island")
	or Instance.new("Model", workspace)

-- ── Orbit config ─────────────────────────────────────────────────────────────
local Config = {
	ORBIT_RADIUS = 20,
	ORBIT_HEIGHT = 5,
	ORBIT_SPEED = 0.6,
	Y_WAVE_AMP = 2.0,
	Y_WAVE_SPEED = 1.2,
	HELIX_SPAN = 18,
}
-- Slider UI registry: populated by buildSettingsSliders(), used by applyConfig()
local sliderRegistry = {}
local applyFrac -- forward declaration (used by applyConfig before its definition)
local SHAPES -- forward declaration (used by applyConfig before its definition)
local currentShapeIndex = 1
local shapeButtons = {}
-- Protection state forward declarations (used by serializeConfig/applyConfig before their definitions)
local godEnabled = false
local antiFallEnabled = false
local antiFlingEnabled = false
local setGodmode, setAntiFall, setAntiFling -- forward declarations

local SETTING_DEFS = {
	{ label = "Radius", key = "ORBIT_RADIUS", min = 2, max = 300, step = 1, fmt = "%.0f" },
	{ label = "Height", key = "ORBIT_HEIGHT", min = -20, max = 300, step = 1, fmt = "%.0f" },
	{ label = "Speed", key = "ORBIT_SPEED", min = 0.1, max = 5.0, step = 0.1, fmt = "%.1f" },
	{ label = "Wave Amp", key = "Y_WAVE_AMP", min = 0, max = 15, step = 0.5, fmt = "%.1f" },
	{ label = "Wave Spd", key = "Y_WAVE_SPEED", min = 0.1, max = 5.0, step = 0.1, fmt = "%.1f" },
	{ label = "Helix H", key = "HELIX_SPAN", min = 2, max = 80, step = 2, fmt = "%.0f" },
}

-- ── Colour palette  (dark-navy + electric-blue, mirrors the reference UI) ───
local P = {
	bg = Color3.fromRGB(8, 12, 20), -- window background
	panel = Color3.fromRGB(12, 18, 30), -- content panel
	row = Color3.fromRGB(18, 26, 42), -- element / row
	rowHov = Color3.fromRGB(28, 40, 62), -- hover
	sel = Color3.fromRGB(0, 100, 220), -- selected item
	tabOn = Color3.fromRGB(0, 110, 235), -- active tab
	tabOff = Color3.fromRGB(14, 20, 34), -- inactive tab
	border = Color3.fromRGB(25, 40, 65), -- subtle border
	accent = Color3.fromRGB(0, 130, 255), -- glow / accent blue
	track = Color3.fromRGB(10, 15, 25), -- slider track bg
	fill = Color3.fromRGB(0, 130, 255), -- slider fill / value
	thumb = Color3.fromRGB(100, 175, 255), -- thumb / value labels
	text = Color3.fromRGB(235, 245, 255), -- primary text
	sub = Color3.fromRGB(145, 165, 190), -- secondary / hint text
	green = Color3.fromRGB(0, 70, 40), -- ON / safe
	red = Color3.fromRGB(143, 42, 190), -- danger / fling
	orange = Color3.fromRGB(218, 137, 255), -- warning / active fling
	active = Color3.fromRGB(218, 137, 255), -- keybind-capture state
	ddBg = Color3.fromRGB(10, 16, 28), -- dropdown list bg
	disabled = Color3.fromRGB(28, 35, 48), -- disabled feature
	section = Color3.fromRGB(0, 85, 175), -- section label bar
}

-- ── Layout constants ──────────────────────────────────────────────────────────
-- 4 tabs: Shapes | Settings | Protect | Target
-- Target tab (tallest): SpectateBtn ends at y=284; +8 pad → CONTENT_H=292
-- ContentFrame y=62, h=292 → ends 354; OrbitBtn y=360; h=28 → ends 388; Main=396
local CONTENT_H = 292
local ITEM_H = 30
local SET_ROW_H = 34
local ORBIT_Y = 360
local MAIN_H = 396
local DD_MAX_H = 108
local DD_ITEM_H = 24
-- Dropdown top in Main coords = 62 + 168 + 26 = 256

-- ── UI instances ──────────────────────────────────────────────────────────────
local Gui = Instance.new("ScreenGui")
local Main = Instance.new("Frame")
local TitleLabel = Instance.new("TextLabel")
local TabBar = Instance.new("Frame")
local TabShapes = Instance.new("TextButton")
local TabSettings = Instance.new("TextButton")
local TabProtect = Instance.new("TextButton")
local TabTarget = Instance.new("TextButton")
local TabConfig = Instance.new("TextButton")
local ContentFrame = Instance.new("Frame")
local ShapesContent = Instance.new("ScrollingFrame")
local ShapesLayout = Instance.new("UIListLayout")
local ShapesPadding = Instance.new("UIPadding")
local SettingsContent = Instance.new("Frame")
local SettingsLayout = Instance.new("UIListLayout")
local ProtectContent = Instance.new("Frame")
local TargetContent = Instance.new("Frame")
local OrbitBtn = Instance.new("TextButton")
local LoopFlingBtn = Instance.new("TextButton")
local ConfigContent = Instance.new("ScrollingFrame")
local DropdownList = Instance.new("ScrollingFrame") -- parented to Main

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function mkCorner(inst, r)
	local c = Instance.new("UICorner", inst)
	c.CornerRadius = UDim.new(0, r or 6)
end
local function mkStroke(inst, color, thick, transp)
	local s = Instance.new("UIStroke", inst)
	s.Color = color or P.border
	s.Thickness = thick or 1
	s.Transparency = transp or 0.45
end
local function mkBtn(parent, text, pos, size, color)
	local b = Instance.new("TextButton", parent)
	b.BackgroundColor3 = color or P.row
	b.BorderSizePixel = 0
	b.Position = pos
	b.Size = size
	b.Font = Enum.Font.GothamSemibold
	b.Text = text
	b.TextColor3 = P.text
	b.TextSize = 12
	b.AutoButtonColor = false
	mkCorner(b, 5)
	return b
end
local function mkLabel(parent, text, pos, size, color, align)
	local l = Instance.new("TextLabel", parent)
	l.BackgroundColor3 = color or Color3.fromRGB(0, 0, 0)
	l.BackgroundTransparency = color and 0 or 1
	l.BorderSizePixel = 0
	l.Position = pos
	l.Size = size
	l.Font = Enum.Font.Gotham
	l.Text = text
	l.TextColor3 = P.text
	l.TextSize = 12
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextWrapped = true
	return l
end
local function mkSection(parent, text, yPos)
	local bar = Instance.new("Frame", parent)
	bar.BackgroundColor3 = P.section
	bar.BackgroundTransparency = 0.55
	bar.BorderSizePixel = 0
	bar.Position = UDim2.new(0, 6, 0, yPos)
	bar.Size = UDim2.new(1, -12, 0, 18)
	mkCorner(bar, 3)
	local lbl = Instance.new("TextLabel", bar)
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, -8, 1, 0)
	lbl.Position = UDim2.new(0, 8, 0, 0)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 10
	lbl.TextColor3 = P.accent
	lbl.Text = string.upper(text)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	return bar
end

-- ── Main window ───────────────────────────────────────────────────────────────
Gui.Name = "OrbitGUI"
Gui.Parent = gethui and gethui() or game.CoreGui
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.ResetOnSpawn = false

Main.Parent = Gui
Main.BackgroundColor3 = P.bg
Main.BorderSizePixel = 0
Main.Position = UDim2.new(0.04, 0, 0.15, 0)
Main.Size = UDim2.new(0, 230, 0, MAIN_H)
Main.Active = true
Main.Draggable = true
mkCorner(Main, 10)
mkStroke(Main, P.border, 1.5, 0.3)

TitleLabel.Parent = Main
TitleLabel.BackgroundColor3 = Color3.fromRGB(5, 8, 16)
TitleLabel.BorderSizePixel = 0
TitleLabel.Size = UDim2.new(1, 0, 0, 36)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "Orbit Island"
TitleLabel.TextColor3 = P.text
TitleLabel.TextSize = 14
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
mkCorner(TitleLabel, 10)
-- Blue accent line under title
local accentLine = Instance.new("Frame", Main)
accentLine.BackgroundColor3 = P.accent
accentLine.BorderSizePixel = 0
accentLine.Position = UDim2.new(0, 0, 0, 35)
accentLine.Size = UDim2.new(1, 0, 0, 1)

TabBar.Parent = Main
TabBar.BackgroundColor3 = Color3.fromRGB(8, 12, 22)
TabBar.BorderSizePixel = 0
TabBar.Position = UDim2.new(0, 0, 0, 36)
TabBar.Size = UDim2.new(1, 0, 0, 32)

local function styleTab(btn, txt, x, active)
	btn.Parent = TabBar
	btn.BorderSizePixel = 0
	btn.Position = UDim2.new(x, 2, 0, 2)
	btn.Size = UDim2.new(0.2, -4, 1, -4)
	btn.Font = Enum.Font.GothamBold
	btn.Text = txt
	btn.TextScaled = true
	btn.TextColor3 = active and P.text or P.sub
	btn.BackgroundColor3 = active and P.tabOn or P.tabOff
	btn.AutoButtonColor = false
	mkCorner(btn, 4)
end
styleTab(TabShapes, "SHAPES", 0, true)
styleTab(TabSettings, "SETTINGS", 0.2, false)
styleTab(TabProtect, "PROTECT", 0.4, false)
styleTab(TabTarget, "TARGET", 0.6, false)
styleTab(TabConfig, "CONFIG", 0.8, false)

ContentFrame.Parent = Main
ContentFrame.BackgroundColor3 = P.panel
ContentFrame.BorderSizePixel = 0
ContentFrame.Position = UDim2.new(0, 0, 0, 68)
ContentFrame.Size = UDim2.new(1, 0, 0, CONTENT_H)
ContentFrame.ClipsDescendants = true

-- ── Shapes tab ────────────────────────────────────────────────────────────────
ShapesContent.Parent = ContentFrame
ShapesContent.BackgroundTransparency = 1
ShapesContent.BorderSizePixel = 0
ShapesContent.Size = UDim2.new(1, 0, 1, 0)
ShapesContent.ScrollBarThickness = 4
ShapesContent.ScrollBarImageColor3 = P.accent
ShapesContent.ScrollingDirection = Enum.ScrollingDirection.Y
ShapesContent.CanvasSize = UDim2.new(0, 0, 0, 0)
ShapesLayout.Parent = ShapesContent
ShapesLayout.SortOrder = Enum.SortOrder.LayoutOrder
ShapesLayout.Padding = UDim.new(0, 3)
ShapesPadding.Parent = ShapesContent
ShapesPadding.PaddingTop = UDim.new(0, 4)
ShapesPadding.PaddingBottom = UDim.new(0, 4)
ShapesPadding.PaddingLeft = UDim.new(0, 5)
ShapesPadding.PaddingRight = UDim.new(0, 5)

-- ── Settings tab ──────────────────────────────────────────────────────────────
-- Convert Settings to ScrollingFrame
SettingsContent = Instance.new("ScrollingFrame")
SettingsContent.Parent = ContentFrame
SettingsContent.BackgroundTransparency = 1
SettingsContent.BorderSizePixel = 0
SettingsContent.Size = UDim2.new(1, 0, 1, 0)
SettingsContent.Visible = false
SettingsContent.ScrollBarThickness = 4
SettingsContent.ScrollBarImageColor3 = P.accent
SettingsContent.ScrollingDirection = Enum.ScrollingDirection.Y
SettingsContent.CanvasSize = UDim2.new(0, 0, 0, 0)
SettingsContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
SettingsLayout = Instance.new("UIListLayout")
SettingsLayout.Parent = SettingsContent
SettingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
SettingsLayout.Padding = UDim.new(0, 3)
local stgPad = Instance.new("UIPadding", SettingsContent)
stgPad.PaddingTop = UDim.new(0, 6)
stgPad.PaddingBottom = UDim.new(0, 6)
stgPad.PaddingLeft = UDim.new(0, 6)
stgPad.PaddingRight = UDim.new(0, 6)

-- ── Config tab ──────────────────────────────────────────────────────────────
-- Saved config names list (populated from filesystem on tab open)
local savedConfigNames = {}
local selectedConfigName = nil
local ConfigNameBox -- forward ref

local function mkSectionRow(parent, text, order)
	local bar = Instance.new("Frame", parent)
	bar.LayoutOrder = order
	bar.BackgroundColor3 = P.section
	bar.BackgroundTransparency = 0.55
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(1, 0, 0, 18)
	mkCorner(bar, 3)
	local lbl = Instance.new("TextLabel", bar)
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, -8, 1, 0)
	lbl.Position = UDim2.new(0, 8, 0, 0)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 10
	lbl.TextColor3 = P.accent
	lbl.Text = string.upper(text)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	return bar
end
local function mkScrollBtn(parent, text, order, color)
	local b = Instance.new("TextButton", parent)
	b.LayoutOrder = order
	b.BackgroundColor3 = color or P.row
	b.BorderSizePixel = 0
	b.Size = UDim2.new(1, 0, 0, 28)
	b.Font = Enum.Font.GothamSemibold
	b.Text = text
	b.TextColor3 = P.text
	b.TextSize = 12
	b.AutoButtonColor = false
	mkCorner(b, 5)
	return b
end

ConfigContent.Parent = ContentFrame
ConfigContent.BackgroundTransparency = 1
ConfigContent.BorderSizePixel = 0
ConfigContent.Size = UDim2.new(1, 0, 1, 0)
ConfigContent.Visible = false
ConfigContent.ScrollBarThickness = 4
ConfigContent.ScrollBarImageColor3 = P.accent
ConfigContent.ScrollingDirection = Enum.ScrollingDirection.Y
ConfigContent.CanvasSize = UDim2.new(0, 0, 0, 0)
ConfigContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
local ConfigLayout = Instance.new("UIListLayout", ConfigContent)
ConfigLayout.SortOrder = Enum.SortOrder.LayoutOrder
ConfigLayout.Padding = UDim.new(0, 4)
local cfgTabPad = Instance.new("UIPadding", ConfigContent)
cfgTabPad.PaddingTop = UDim.new(0, 6)
cfgTabPad.PaddingBottom = UDim.new(0, 6)
cfgTabPad.PaddingLeft = UDim.new(0, 6)
cfgTabPad.PaddingRight = UDim.new(0, 6)

-- ── Config Name Input section ────────────────────────────────────────────────
mkSectionRow(ConfigContent, "Config Name", 1)

local nameInputRow = Instance.new("Frame", ConfigContent)
nameInputRow.LayoutOrder = 2
nameInputRow.Size = UDim2.new(1, 0, 0, 28)
nameInputRow.BackgroundTransparency = 1
nameInputRow.BorderSizePixel = 0

ConfigNameBox = Instance.new("TextBox", nameInputRow)
ConfigNameBox.BackgroundColor3 = P.row
ConfigNameBox.BorderSizePixel = 0
ConfigNameBox.Position = UDim2.new(0, 0, 0, 0)
ConfigNameBox.Size = UDim2.new(1, 0, 1, 0)
ConfigNameBox.Font = Enum.Font.Gotham
ConfigNameBox.PlaceholderText = "Enter config name..."
ConfigNameBox.PlaceholderColor3 = P.sub
ConfigNameBox.Text = ""
ConfigNameBox.TextColor3 = P.text
ConfigNameBox.TextSize = 12
ConfigNameBox.TextXAlignment = Enum.TextXAlignment.Left
ConfigNameBox.ClearTextOnFocus = false
mkCorner(ConfigNameBox, 5)
mkStroke(ConfigNameBox, P.border, 1, 0.4)
local cnbPad = Instance.new("UIPadding", ConfigNameBox)
cnbPad.PaddingLeft = UDim.new(0, 8)
cnbPad.PaddingRight = UDim.new(0, 8)

-- ── Save / Load / Delete action row ─────────────────────────────────────────
mkSectionRow(ConfigContent, "Actions", 3)

local actRow = Instance.new("Frame", ConfigContent)
actRow.LayoutOrder = 4
actRow.Size = UDim2.new(1, 0, 0, 28)
actRow.BackgroundTransparency = 1
actRow.BorderSizePixel = 0

local cfgSaveBtn = Instance.new("TextButton", actRow)
cfgSaveBtn.BackgroundColor3 = P.green
cfgSaveBtn.BorderSizePixel = 0
cfgSaveBtn.Position = UDim2.new(0, 0, 0, 0)
cfgSaveBtn.Size = UDim2.new(0.33, -2, 1, 0)
cfgSaveBtn.Font = Enum.Font.GothamBold
cfgSaveBtn.TextSize = 12
cfgSaveBtn.TextColor3 = P.text
cfgSaveBtn.Text = "Save"
cfgSaveBtn.AutoButtonColor = false
mkCorner(cfgSaveBtn, 5)

local cfgLoadBtn = Instance.new("TextButton", actRow)
cfgLoadBtn.BackgroundColor3 = P.sub
cfgLoadBtn.BorderSizePixel = 0
cfgLoadBtn.Position = UDim2.new(0.33, 2, 0, 0)
cfgLoadBtn.Size = UDim2.new(0.34, -2, 1, 0)
cfgLoadBtn.Font = Enum.Font.GothamBold
cfgLoadBtn.TextSize = 12
cfgLoadBtn.TextColor3 = P.text
cfgLoadBtn.Text = "Load"
cfgLoadBtn.AutoButtonColor = false
mkCorner(cfgLoadBtn, 5)

local cfgDelBtn = Instance.new("TextButton", actRow)
cfgDelBtn.BackgroundColor3 = P.red
cfgDelBtn.BorderSizePixel = 0
cfgDelBtn.Position = UDim2.new(0.67, 2, 0, 0)
cfgDelBtn.Size = UDim2.new(0.33, -2, 1, 0)
cfgDelBtn.Font = Enum.Font.GothamBold
cfgDelBtn.TextSize = 12
cfgDelBtn.TextColor3 = P.text
cfgDelBtn.Text = "Del"
cfgDelBtn.AutoButtonColor = false
mkCorner(cfgDelBtn, 5)

-- ── Saved Configs List section ───────────────────────────────────────────────
mkSectionRow(ConfigContent, "Saved Configs", 5)

local cfgListScroll = Instance.new("ScrollingFrame", ConfigContent)
cfgListScroll.LayoutOrder = 6
cfgListScroll.BackgroundColor3 = P.panel
cfgListScroll.BackgroundTransparency = 0.5
cfgListScroll.BorderSizePixel = 0
cfgListScroll.Size = UDim2.new(1, 0, 0, 120)
cfgListScroll.ScrollBarThickness = 4
cfgListScroll.ScrollBarImageColor3 = P.accent
cfgListScroll.ScrollingDirection = Enum.ScrollingDirection.Y
cfgListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
cfgListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
mkCorner(cfgListScroll, 5)
local cfgListLayout = Instance.new("UIListLayout", cfgListScroll)
cfgListLayout.SortOrder = Enum.SortOrder.LayoutOrder
cfgListLayout.Padding = UDim.new(0, 2)
local cfgListPad = Instance.new("UIPadding", cfgListScroll)
cfgListPad.PaddingTop = UDim.new(0, 4)
cfgListPad.PaddingBottom = UDim.new(0, 4)
cfgListPad.PaddingLeft = UDim.new(0, 4)
cfgListPad.PaddingRight = UDim.new(0, 4)

local cfgStatusLbl = Instance.new("TextLabel", ConfigContent)
cfgStatusLbl.LayoutOrder = 7
cfgStatusLbl.BackgroundTransparency = 1
cfgStatusLbl.Size = UDim2.new(1, 0, 0, 16)
cfgStatusLbl.Font = Enum.Font.Gotham
cfgStatusLbl.TextSize = 11
cfgStatusLbl.TextColor3 = P.sub
cfgStatusLbl.Text = ""
cfgStatusLbl.TextXAlignment = Enum.TextXAlignment.Center

-- ── Helper: refresh the list of saved configs ─────────────────────────────
local function refreshConfigList()
	for _, ch in ipairs(cfgListScroll:GetChildren()) do
		if ch:IsA("TextButton") then
			ch:Destroy()
		end
	end
	-- List files from the OrbitIsland folder
	pcall(makefolder, "OrbitIsland")
	local ok, files = pcall(listfiles, "OrbitIsland")
	if not ok or type(files) ~= "table" then
		-- fallback: try listing root
		ok, files = pcall(listfiles, "")
		if not ok or type(files) ~= "table" then
			ok, files = pcall(listfiles)
		end
	end
	if not ok or type(files) ~= "table" then
		files = {}
	end
	savedConfigNames = {}
	local order = 0
	for _, fpath in ipairs(files) do
		local fname = tostring(fpath):match("[^\\/]+$") or tostring(fpath)
		local cfgName = fname:match("^OrbitIsland_(.+)%.txt$")
		if cfgName then
			table.insert(savedConfigNames, cfgName)
			order = order + 1
			local row = Instance.new("TextButton", cfgListScroll)
			row.LayoutOrder = order
			row.BackgroundColor3 = (selectedConfigName == cfgName) and P.sel or P.row
			row.BorderSizePixel = 0
			row.Size = UDim2.new(1, 0, 0, 26)
			row.Font = Enum.Font.Gotham
			row.TextSize = 12
			row.TextColor3 = P.text
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.Text = "  " .. cfgName
			row.AutoButtonColor = false
			mkCorner(row, 4)
			local selName = cfgName
			row.MouseButton1Click:Connect(function()
				selectedConfigName = selName
				ConfigNameBox.Text = selName
				refreshConfigList()
			end)
		end
	end
	if #savedConfigNames == 0 then
		cfgStatusLbl.Text = "No saved configs found"
	else
		cfgStatusLbl.Text = #savedConfigNames .. " config(s) found"
	end
end

-- ── Save button ──────────────────────────────────────────────────────────────
local function serializeConfig()
	local parts = {}
	-- Keybinds
	local ok1, fn = pcall(function()
		return tostring(flyKeybind.Name)
	end)
	local ok2, on = pcall(function()
		return tostring(orbitKeybind.Name)
	end)
	table.insert(parts, "flyKeybind=" .. (ok1 and fn or "F"))
	table.insert(parts, "orbitKeybind=" .. (ok2 and on or "V"))
	-- Selected shape index
	table.insert(parts, "selectedShape=" .. tostring(currentShapeIndex or 1))
	-- All slider/Config values
	for k, v in pairs(Config) do
		table.insert(parts, "Config_" .. tostring(k) .. "=" .. tostring(v))
	end
	-- Protection state
	table.insert(parts, "protect_god=" .. tostring(godEnabled))
	table.insert(parts, "protect_antiFall=" .. tostring(antiFallEnabled))
	table.insert(parts, "protect_antiFling=" .. tostring(antiFlingEnabled))
	return table.concat(parts, "\n")
end

cfgSaveBtn.MouseButton1Click:Connect(function()
	-- Strip to safe filename chars (no spaces, no slashes)
	local raw = (ConfigNameBox.Text or ""):match("^%s*(.-)%s*$")
	local name = raw:gsub("[^%w%-_.]", "")
	if name == "" then
		cfgStatusLbl.Text = "Enter a config name first"
		return
	end
	pcall(makefolder, "OrbitIsland")
	local content = serializeConfig()
	local ok, err = pcall(writefile, "OrbitIsland/OrbitIsland_" .. name .. ".txt", content)
	if ok then
		selectedConfigName = name
		cfgStatusLbl.Text = "Saved: " .. name
		refreshConfigList()
	else
		cfgStatusLbl.Text = "Err: " .. tostring(err):sub(1, 40)
	end
end)

-- ── Load button ──────────────────────────────────────────────────────────────
local function applyConfig(data)
	for _, line in ipairs(string.split(data, "\n")) do
		local k, v = line:match("^(.-)=(.+)$")
		if k and v then
			-- Keybinds
			if k == "flyKeybind" then
				local kc = Enum.KeyCode[v]
				if kc then
					flyKeybind = kc
					if KeybindBtn then
						KeybindBtn.Text = "Key: " .. v
					end
				end
			elseif k == "orbitKeybind" then
				local kc = Enum.KeyCode[v]
				if kc then
					orbitKeybind = kc
					if OrbitKeybindBtn then
						OrbitKeybindBtn.Text = "Key: " .. v
					end
				end

			-- Shape selection
			elseif k == "selectedShape" then
				local idx = tonumber(v)
				local shapeCount = (type(SHAPES) == "table") and #SHAPES or 0
				if idx and idx >= 1 and idx <= shapeCount then
					-- Deselect old
					if type(shapeButtons) == "table" and shapeButtons[currentShapeIndex] then
						shapeButtons[currentShapeIndex].BackgroundColor3 = P.row
					end
					currentShapeIndex = idx
					-- Highlight new
					if type(shapeButtons) == "table" and shapeButtons[idx] then
						shapeButtons[idx].BackgroundColor3 = P.sel
					end
				end

			-- Config slider values
			elseif k:sub(1, 7) == "Config_" then
				local ck = k:sub(8)
				if Config[ck] ~= nil then
					local num = tonumber(v)
					if type(Config[ck]) == "number" and num then
						Config[ck] = num
						-- Refresh slider UI
						local reg = sliderRegistry[ck]
						if reg then
							local frac = (num - reg.def.min) / (reg.def.max - reg.def.min)
							if type(applyFrac) == "function" then
								applyFrac(frac, reg.def, reg.fill, reg.thumb, reg.valLbl)
							end
						end
					elseif type(Config[ck]) == "boolean" then
						Config[ck] = (v == "true")
					end
				end

			-- Protection toggles
			elseif k == "protect_god" then
				if type(setGodmode) == "function" then
					setGodmode(v == "true")
				end
			elseif k == "protect_antiFall" then
				if type(setAntiFall) == "function" then
					setAntiFall(v == "true")
				end
			elseif k == "protect_antiFling" then
				if type(setAntiFling) == "function" then
					setAntiFling(v == "true")
				end
			end
		end
	end
end

cfgLoadBtn.MouseButton1Click:Connect(function()
	local raw = (ConfigNameBox.Text or ""):match("^%s*(.-)%s*$")
	local name = raw:gsub("[^%w%-_.]", "")
	if name == "" then
		cfgStatusLbl.Text = "Enter a config name first"
		return
	end
	local ok, data = pcall(readfile, "OrbitIsland/OrbitIsland_" .. name .. ".txt")
	if not ok or type(data) ~= "string" or data == "" then
		cfgStatusLbl.Text = "Not found: " .. name
		return
	end
	applyConfig(data)
	cfgStatusLbl.Text = "Loaded: " .. name
end)

-- ── Delete button ─────────────────────────────────────────────────────────────
cfgDelBtn.MouseButton1Click:Connect(function()
	local raw = (ConfigNameBox.Text or ""):match("^%s*(.-)%s*$")
	local name = raw:gsub("[^%w%-_.]", "")
	if name == "" then
		cfgStatusLbl.Text = "Enter a config name first"
		return
	end
	local ok, err = pcall(delfile, "OrbitIsland/OrbitIsland_" .. name .. ".txt")
	if ok then
		if selectedConfigName == name then
			selectedConfigName = nil
			ConfigNameBox.Text = ""
		end
		cfgStatusLbl.Text = "Deleted: " .. name
		refreshConfigList()
	else
		cfgStatusLbl.Text = "Err: " .. tostring(err):sub(1, 40)
	end
end)

-- Refresh list when Config tab is opened
TabConfig.MouseButton1Click:Connect(refreshConfigList)

-- ── Protect tab ───────────────────────────────────────────────────────────────
-- Layout:
--   y=6   section header "PROTECTION"
--   y=28  GodBtn
--   y=58  AntiFallBtn
--   y=88  AntiFlingBtn
-- Convert Protect to ScrollingFrame for future-proofing
ProtectContent = Instance.new("ScrollingFrame")
ProtectContent.Parent = ContentFrame
ProtectContent.BackgroundTransparency = 1
ProtectContent.BorderSizePixel = 0
ProtectContent.Size = UDim2.new(1, 0, 1, 0)
ProtectContent.Visible = false
ProtectContent.ScrollBarThickness = 4
ProtectContent.ScrollBarImageColor3 = P.accent
ProtectContent.ScrollingDirection = Enum.ScrollingDirection.Y
ProtectContent.CanvasSize = UDim2.new(0, 0, 0, 0)
ProtectContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
local ProtectLayout = Instance.new("UIListLayout", ProtectContent)
ProtectLayout.SortOrder = Enum.SortOrder.LayoutOrder
ProtectLayout.Padding = UDim.new(0, 4)
local prtPad = Instance.new("UIPadding", ProtectContent)
prtPad.PaddingTop = UDim.new(0, 6)
prtPad.PaddingBottom = UDim.new(0, 6)
prtPad.PaddingLeft = UDim.new(0, 6)
prtPad.PaddingRight = UDim.new(0, 6)

mkSectionRow(ProtectContent, "Protection", 1)
local GodBtn = mkScrollBtn(ProtectContent, " Godmode  |  Off", 2)
local AntiFallBtn = mkScrollBtn(ProtectContent, " Anti-Fall  |  Off", 3)
local AntiFlingBtn = mkScrollBtn(ProtectContent, " Anti-Fling  |  Off", 4)

-- ── Target tab ────────────────────────────────────────────────────────────────
-- y=6   section "ORBIT CENTER"
-- y=28  ModeLabel
-- y=54  PlaceBtn
-- y=84  IslandBtn
-- y=114 section "PLAYER FLING"
-- y=136 PlayerLabel
-- y=162 DropdownBtn (55%) | ClickPlayerBtn (42%)
-- y=192 FlingBtn
-- y=222 LoopFlingBtn
-- y=252 SpectateBtn
-- CONTENT_H = 252+26+14 = 292 ✓
-- Convert Target to ScrollingFrame
TargetContent = Instance.new("ScrollingFrame")
TargetContent.Parent = ContentFrame
TargetContent.BackgroundTransparency = 1
TargetContent.BorderSizePixel = 0
TargetContent.Size = UDim2.new(1, 0, 1, 0)
TargetContent.Visible = false
TargetContent.ScrollBarThickness = 4
TargetContent.ScrollBarImageColor3 = P.accent
TargetContent.ScrollingDirection = Enum.ScrollingDirection.Y
TargetContent.CanvasSize = UDim2.new(0, 0, 0, 0)
TargetContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
local TargetLayout = Instance.new("UIListLayout", TargetContent)
TargetLayout.SortOrder = Enum.SortOrder.LayoutOrder
TargetLayout.Padding = UDim.new(0, 4)
local tgtPad = Instance.new("UIPadding", TargetContent)
tgtPad.PaddingTop = UDim.new(0, 6)
tgtPad.PaddingBottom = UDim.new(0, 6)
tgtPad.PaddingLeft = UDim.new(0, 6)
tgtPad.PaddingRight = UDim.new(0, 6)

mkSectionRow(TargetContent, "Orbit Center", 1)
local ModeLabel = Instance.new("TextLabel", TargetContent)
ModeLabel.LayoutOrder = 2
ModeLabel.BackgroundColor3 = P.row
ModeLabel.BorderSizePixel = 0
ModeLabel.Size = UDim2.new(1, 0, 0, 22)
ModeLabel.Font = Enum.Font.Gotham
ModeLabel.Text = "Mode:  Island  (workspace.Island)"
ModeLabel.TextColor3 = P.sub
ModeLabel.TextSize = 11
ModeLabel.TextXAlignment = Enum.TextXAlignment.Left
mkCorner(ModeLabel, 4)
mkStroke(ModeLabel, P.border, 1, 0.6)
local mlPad = Instance.new("UIPadding", ModeLabel)
mlPad.PaddingLeft = UDim.new(0, 6)
local PlaceBtn = mkScrollBtn(TargetContent, "Click to Place Center", 3)
local IslandBtn = mkScrollBtn(TargetContent, "Reset to Island", 4, P.green)

mkSectionRow(TargetContent, "Player Fling", 5)
local PlayerLabel = Instance.new("TextLabel", TargetContent)
PlayerLabel.LayoutOrder = 6
PlayerLabel.BackgroundColor3 = P.row
PlayerLabel.BorderSizePixel = 0
PlayerLabel.Size = UDim2.new(1, 0, 0, 22)
PlayerLabel.Font = Enum.Font.Gotham
PlayerLabel.Text = "No player selected"
PlayerLabel.TextColor3 = P.sub
PlayerLabel.TextSize = 11
PlayerLabel.TextXAlignment = Enum.TextXAlignment.Left
mkCorner(PlayerLabel, 4)
mkStroke(PlayerLabel, P.border, 1, 0.6)
local plPad = Instance.new("UIPadding", PlayerLabel)
plPad.PaddingLeft = UDim.new(0, 6)

local ddRow = Instance.new("Frame", TargetContent)
ddRow.LayoutOrder = 7
ddRow.Size = UDim2.new(1, 0, 0, 26)
ddRow.BackgroundTransparency = 1
ddRow.BorderSizePixel = 0
local DropdownBtn = mkBtn(ddRow, "Select Player", UDim2.new(0, 0, 0, 0), UDim2.new(0.58, -3, 1, 0))
local ClickPlayerBtn = mkBtn(ddRow, "Click", UDim2.new(0.58, 3, 0, 0), UDim2.new(0.42, -3, 1, 0))

local FlingBtn = mkScrollBtn(TargetContent, "Fling!", 8, P.red)

LoopFlingBtn.Parent = TargetContent
LoopFlingBtn.LayoutOrder = 9
LoopFlingBtn.BackgroundColor3 = P.red
LoopFlingBtn.BorderSizePixel = 0
LoopFlingBtn.Size = UDim2.new(1, 0, 0, 28)
LoopFlingBtn.Font = Enum.Font.GothamBold
LoopFlingBtn.Text = "Loop Fling  |  Off"
LoopFlingBtn.TextColor3 = P.text
LoopFlingBtn.TextSize = 12
LoopFlingBtn.AutoButtonColor = false
mkCorner(LoopFlingBtn, 5)

local SpectateBtn = mkScrollBtn(TargetContent, "Spectate", 10)

-- ── Dropdown overlay (parented to Main, ZIndex above ContentFrame clip) ───────
-- Main coords: top = 62+162+26 = 250
DropdownList.Parent = Main
DropdownList.BackgroundColor3 = P.ddBg
DropdownList.BorderSizePixel = 0
DropdownList.Position = UDim2.new(0, 6, 0, 250)
DropdownList.Size = UDim2.new(0.55, -10, 0, DD_MAX_H)
DropdownList.ScrollBarThickness = 3
DropdownList.ScrollBarImageColor3 = P.accent
DropdownList.ScrollingDirection = Enum.ScrollingDirection.Y
DropdownList.CanvasSize = UDim2.new(0, 0, 0, 0)
DropdownList.Visible = false
DropdownList.ZIndex = 20
mkCorner(DropdownList, 5)
mkStroke(DropdownList, P.accent, 1, 0.55)

-- ── Orbit button ──────────────────────────────────────────────────────────────
OrbitBtn.Parent = Main
OrbitBtn.BackgroundColor3 = P.row
OrbitBtn.BorderSizePixel = 0
OrbitBtn.Position = UDim2.new(0.05, 0, 0, ORBIT_Y)
OrbitBtn.Size = UDim2.new(0.90, 0, 0, 28)
OrbitBtn.Font = Enum.Font.GothamBold
OrbitBtn.Text = "Orbit  |  Off"
OrbitBtn.TextColor3 = P.text
OrbitBtn.TextSize = 13
OrbitBtn.AutoButtonColor = false
mkCorner(OrbitBtn, 6)
mkStroke(OrbitBtn, P.border, 1, 0.55)

-- ── Tab switching ─────────────────────────────────────────────────────────────
local tabBtns = { TabShapes, TabSettings, TabProtect, TabTarget, TabConfig }
local tabPanels = { ShapesContent, SettingsContent, ProtectContent, TargetContent, ConfigContent }
local function switchTab(idx)
	DropdownList.Visible = false
	for i = 1, 5 do
		tabBtns[i].BackgroundColor3 = (i == idx) and P.tabOn or P.tabOff
		tabBtns[i].TextColor3 = (i == idx) and P.text or P.sub
		tabPanels[i].Visible = (i == idx)
	end
end
TabShapes.MouseButton1Click:Connect(function()
	switchTab(1)
end)
TabSettings.MouseButton1Click:Connect(function()
	switchTab(2)
end)
TabProtect.MouseButton1Click:Connect(function()
	switchTab(3)
end)
TabTarget.MouseButton1Click:Connect(function()
	switchTab(4)
end)
TabConfig.MouseButton1Click:Connect(function()
	switchTab(5)
end)

-- ── Toggle-button helper (on/off style) ──────────────────────────────────────
local function setToggleState(btn, on, label)
	if on then
		btn.Text = label .. "  |  On"
		btn.BackgroundColor3 = P.green
	else
		btn.Text = label .. "  |  Off"
		btn.BackgroundColor3 = P.row
	end
end

-- ── State ─────────────────────────────────────────────────────────────────────
local mainVisible = true
local orbitMode = "island"
local customCenter = Vector3.new(0, 0, 0)
local clickMode = nil
local selectedPlayer = nil
local charAddedConn = nil
local spectateConn = nil
local flinging = false
local loopFlinging = false
local spectating = false

-- Protection state (forward-declared above)
local noclipEnabled = false
local godLoopConn, godRespawnConn
local antiFallLoopConn, antiFallRespawnConn
local antiFlingLoopConn
local noclipLoopConn, noclipRespawnConn, noclipAddedConn
local lastSafeCFrame = nil
local isRecovering = false
local NoClipStates = setmetatable({}, { __mode = "k" })

-- Fly state
local flySystemEnabled = true
local toggleOrbit -- forward declaration (used by V keybind)
local flyKeybind = Enum.KeyCode.F
local orbitKeybind = Enum.KeyCode.V
local rebindingOrbit = false
local OrbitKeybindBtn
local rebindingFly = false
local flying = false
local flySpeed = 50
local flySpeedMult = 3
local flyCharacter, flyHumanoid, flyRoot
local flyAttachment, flyLV, flyAO
local FlyBtn, KeybindBtn, FlySystemBtn

-- ── PlayerModule (fly controls) ──────────────────────────────────────────────
local PlayerModule = require(LocalPlayer.PlayerScripts:WaitForChild("PlayerModule"))
local Controls = PlayerModule:GetControls()

-- ============================================================================
-- PROTECTION SYSTEMS (ported from reference script)
-- ============================================================================

-- ── Godmode ───────────────────────────────────────────────────────────────────
local function applyGodProps(char)
	task.spawn(function()
		local hum = char:WaitForChild("Humanoid", 10)
		if hum and godEnabled then
			pcall(function()
				hum.MaxHealth = math.huge
				hum.Health = math.huge
				hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
				hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
				hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			end)
		end
	end)
end
local function restoreGodProps(char)
	local hum = char and char:FindFirstChildWhichIsA("Humanoid")
	if hum then
		pcall(function()
			hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
			hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
			hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
		end)
	end
end
setGodmode = function(on)
	godEnabled = on
	setToggleState(GodBtn, on, " Godmode")
	if on then
		if godLoopConn then
			pcall(function()
				godLoopConn:Disconnect()
			end)
		end
		godLoopConn = RunService.Heartbeat:Connect(function()
			local char = LocalPlayer.Character
			if char and godEnabled then
				local hum = char:FindFirstChildWhichIsA("Humanoid")
				if hum then
					hum.Health = math.huge
					hum.MaxHealth = math.huge
				end
			end
		end)
		if LocalPlayer.Character then
			applyGodProps(LocalPlayer.Character)
		end
		if godRespawnConn then
			pcall(function()
				godRespawnConn:Disconnect()
			end)
		end
		godRespawnConn = LocalPlayer.CharacterAdded:Connect(function(char)
			if godEnabled then
				applyGodProps(char)
			end
		end)
	else
		if godLoopConn then
			pcall(function()
				godLoopConn:Disconnect()
			end)
			godLoopConn = nil
		end
		if godRespawnConn then
			pcall(function()
				godRespawnConn:Disconnect()
			end)
			godRespawnConn = nil
		end
		if LocalPlayer.Character then
			restoreGodProps(LocalPlayer.Character)
		end
	end
end

-- ── Anti-Fall (NDS heartbeat velocity method from reference) ──────────────────
local function hookAntiFall(char)
	task.spawn(function()
		local r = char:WaitForChild("HumanoidRootPart", 10)
		if not r or not antiFallEnabled then
			return
		end
		if antiFallLoopConn then
			pcall(function()
				antiFallLoopConn:Disconnect()
			end)
		end
		local z = Vector3.zero
		antiFallLoopConn = RunService.Heartbeat:Connect(function()
			if not antiFallEnabled or not r.Parent then
				pcall(function()
					antiFallLoopConn:Disconnect()
				end)
				antiFallLoopConn = nil
				return
			end
			local v = r.AssemblyLinearVelocity
			r.AssemblyLinearVelocity = z
			RunService.RenderStepped:Wait()
			r.AssemblyLinearVelocity = v
		end)
	end)
end
setAntiFall = function(on)
	antiFallEnabled = on
	setToggleState(AntiFallBtn, on, " Anti-Fall")
	if on then
		if LocalPlayer.Character then
			hookAntiFall(LocalPlayer.Character)
		end
		if antiFallRespawnConn then
			pcall(function()
				antiFallRespawnConn:Disconnect()
			end)
		end
		antiFallRespawnConn = LocalPlayer.CharacterAdded:Connect(function(char)
			if antiFallEnabled then
				hookAntiFall(char)
			end
		end)
	else
		if antiFallLoopConn then
			pcall(function()
				antiFallLoopConn:Disconnect()
			end)
			antiFallLoopConn = nil
		end
		if antiFallRespawnConn then
			pcall(function()
				antiFallRespawnConn:Disconnect()
			end)
			antiFallRespawnConn = nil
		end
	end
end

-- ── Anti-Fling (velocity anomaly detection from reference) ────────────────────
setAntiFling = function(on)
	antiFlingEnabled = on
	setToggleState(AntiFlingBtn, on, " Anti-Fling")
	if on then
		local char = LocalPlayer.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			lastSafeCFrame = char.HumanoidRootPart.CFrame
		end
		if antiFlingLoopConn then
			pcall(function()
				antiFlingLoopConn:Disconnect()
			end)
		end
		antiFlingLoopConn = RunService.Stepped:Connect(function()
			if not antiFlingEnabled then
				return
			end
			char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildWhichIsA("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local vel = hrp.AssemblyLinearVelocity
				local rotVel = hrp.AssemblyAngularVelocity
				local mag = vel.Magnitude
				local rotMag = rotVel.Magnitude
				if not lastSafeCFrame then
					lastSafeCFrame = hrp.CFrame
				end
				local isControlled = rotMag < 60
				local curState = hum:GetState()
				local isFalling = vel.Y < -50
					and (curState == Enum.HumanoidStateType.Freefall or curState == Enum.HumanoidStateType.FallingDown)
				local maxLin = flying and 1500 or (isControlled and 1000 or 150)
				local maxUp = isControlled and 800 or 250
				local maxDn = isControlled and (isFalling and -5000 or -800) or -350
				local flinged = rotMag > 120 or vel.Y > maxUp or vel.Y < maxDn or mag > maxLin
				if flinged then
					isRecovering = true
					hrp.AssemblyLinearVelocity = Vector3.zero
					hrp.AssemblyAngularVelocity = Vector3.zero
					if lastSafeCFrame then
						hrp.CFrame = lastSafeCFrame
					end
					if
						curState == Enum.HumanoidStateType.Physics
						or curState == Enum.HumanoidStateType.Ragdoll
						or curState == Enum.HumanoidStateType.FallingDown
					then
						hum:ChangeState(Enum.HumanoidStateType.Running)
						hum.PlatformStand = false
					end
				else
					local dist = (hrp.Position - lastSafeCFrame.Position).Magnitude
					if dist > 50 and mag < 100 and not isRecovering then
						lastSafeCFrame = hrp.CFrame
					end
					if isControlled and mag < 900 then
						lastSafeCFrame = hrp.CFrame
						isRecovering = false
					end
				end
			end
		end)
	else
		if antiFlingLoopConn then
			pcall(function()
				antiFlingLoopConn:Disconnect()
			end)
			antiFlingLoopConn = nil
		end
		lastSafeCFrame = nil
		isRecovering = false
	end
end

-- ── Noclip ────────────────────────────────────────────────────────────────────
local function restoreNoclip(char)
	if not char then
		return
	end
	for part, state in pairs(NoClipStates) do
		if part and part.Parent then
			part.CanCollide = state
		end
	end
	for k in pairs(NoClipStates) do
		NoClipStates[k] = nil
	end
end
local function hookNoclip(char)
	if noclipLoopConn then
		pcall(function()
			noclipLoopConn:Disconnect()
		end)
	end
	if noclipAddedConn then
		pcall(function()
			noclipAddedConn:Disconnect()
		end)
	end
	if not noclipEnabled then
		return
	end
	for k in pairs(NoClipStates) do
		NoClipStates[k] = nil
	end
	local parts = {}
	local function regPart(p)
		if p:IsA("BasePart") then
			table.insert(parts, p)
			if NoClipStates[p] == nil then
				NoClipStates[p] = p.CanCollide
			end
		end
	end
	for _, p in ipairs(char:GetDescendants()) do
		regPart(p)
	end
	noclipAddedConn = char.DescendantAdded:Connect(regPart)
	noclipLoopConn = RunService.Stepped:Connect(function()
		if not noclipEnabled or not char.Parent then
			pcall(function()
				noclipLoopConn:Disconnect()
			end)
			return
		end
		for i = 1, #parts do
			local p = parts[i]
			if p.Parent and p.CanCollide then
				p.CanCollide = false
			end
		end
	end)
end
local function setNoclip(on)
	noclipEnabled = on
	-- NoclipBtn removed from UI; noclip engine remains for internal use
	if on then
		if LocalPlayer.Character then
			hookNoclip(LocalPlayer.Character)
		end
		if noclipRespawnConn then
			pcall(function()
				noclipRespawnConn:Disconnect()
			end)
		end
		noclipRespawnConn = LocalPlayer.CharacterAdded:Connect(function(char)
			if noclipEnabled then
				hookNoclip(char)
			end
		end)
	else
		if noclipLoopConn then
			pcall(function()
				noclipLoopConn:Disconnect()
			end)
			noclipLoopConn = nil
		end
		if noclipRespawnConn then
			pcall(function()
				noclipRespawnConn:Disconnect()
			end)
			noclipRespawnConn = nil
		end
		if noclipAddedConn then
			pcall(function()
				noclipAddedConn:Disconnect()
			end)
			noclipAddedConn = nil
		end
		if LocalPlayer.Character then
			restoreNoclip(LocalPlayer.Character)
		end
	end
end

-- ── Protect tab buttons ───────────────────────────────────────────────────────
GodBtn.MouseButton1Click:Connect(function()
	setGodmode(not godEnabled)
end)
AntiFallBtn.MouseButton1Click:Connect(function()
	setAntiFall(not antiFallEnabled)
end)
AntiFlingBtn.MouseButton1Click:Connect(function()
	setAntiFling(not antiFlingEnabled)
end)

-- ============================================================================
-- FLY ENGINE (provided script, NDS fall-damage safe)
-- ============================================================================
local function stopFly()
	flying = false
	local lv, ao, att, root, hum, char = flyLV, flyAO, flyAttachment, flyRoot, flyHumanoid, flyCharacter
	flyLV, flyAO, flyAttachment, flyRoot = nil, nil, nil, nil
	if FlyBtn then
		FlyBtn.Text = "✈  Fly  |  Off"
		FlyBtn.BackgroundColor3 = P.row
	end
	task.spawn(function()
		if lv and lv.Parent then
			lv.VectorVelocity = Vector3.zero
		end
		-- Teleport to ground while frozen (eliminates fall damage entirely)
		if root and root.Parent and char then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { char }
			local hit = workspace:Raycast(root.Position, Vector3.new(0, -2000, 0), params)
			if hit then
				root.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3.5, 0))
			end
		end
		if root and root.Parent then
			root.AssemblyLinearVelocity = Vector3.zero
		end
		if hum then
			pcall(function()
				hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
				hum:SetStateEnabled(Enum.HumanoidStateType.FreeFalling, true)
				hum:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
				hum:ChangeState(Enum.HumanoidStateType.Running)
			end)
		end
		task.wait(0.08)
		if hum then
			pcall(function()
				hum.PlatformStand = false
			end)
		end
		if att and att.Parent then
			att:Destroy()
		end
	end)
end

local function startFly()
	flyCharacter = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	flyHumanoid = flyCharacter:FindFirstChildOfClass("Humanoid")
	flyRoot = flyHumanoid and flyHumanoid.SeatPart or flyCharacter:FindFirstChild("HumanoidRootPart")
	if not flyRoot then
		return
	end
	if flyAttachment then
		flyAttachment:Destroy()
	end
	flyAttachment = Instance.new("Attachment", flyRoot)
	flyLV = Instance.new("LinearVelocity", flyRoot)
	flyLV.Attachment0 = flyAttachment
	flyLV.MaxForce = math.huge
	flyLV.VectorVelocity = Vector3.zero
	flyAO = Instance.new("AlignOrientation", flyRoot)
	flyAO.Attachment0 = flyAttachment
	flyAO.MaxTorque = math.huge
	flyAO.Responsiveness = 200
	flyAO.Mode = Enum.OrientationAlignmentMode.OneAttachment
	if flyHumanoid then
		pcall(function()
			flyHumanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			flyHumanoid:SetStateEnabled(Enum.HumanoidStateType.FreeFalling, false)
			flyHumanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, false)
		end)
	end
	flying = true
	if FlyBtn then
		FlyBtn.Text = "✈  Fly  |  On"
		FlyBtn.BackgroundColor3 = P.green
	end
end

local function toggleFly()
	if not flySystemEnabled then
		return
	end
	if flying then
		stopFly()
	else
		startFly()
	end
end

RunService.RenderStepped:Connect(function()
	if flying and flyRoot and flyLV and flyAO then
		if not flyRoot.Parent then
			stopFly()
			return
		end
		if flyHumanoid then
			flyHumanoid.PlatformStand = not flyHumanoid.SeatPart
			pcall(function()
				flyHumanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
				flyHumanoid:SetStateEnabled(Enum.HumanoidStateType.FreeFalling, false)
				flyHumanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, false)
			end)
		end
		local cam = workspace.CurrentCamera
		local mv = Controls:GetMoveVector()
		local dir = cam.CFrame.LookVector * -mv.Z + cam.CFrame.RightVector * mv.X
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			dir += Vector3.new(0, 1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			dir += Vector3.new(0, -1, 0)
		end
		local spd = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and flySpeed * flySpeedMult * 2
			or flySpeed * flySpeedMult
		flyLV.VectorVelocity = dir.Magnitude > 0 and dir.Unit * spd or Vector3.zero
		flyAO.CFrame = cam.CFrame
	end
end)

-- ============================================================================
-- WORLD OBJECTS
-- ============================================================================
local CenterPart = Instance.new("Part")
CenterPart.Name = "OrbitCenter"
CenterPart.Size = Vector3.new(1, 1, 1)
CenterPart.Anchored = true
CenterPart.CanCollide = false
CenterPart.CastShadow = false
CenterPart.Transparency = 1
CenterPart.Material = Enum.Material.Neon
CenterPart.Parent = Workspace

local CenterHL = Instance.new("Highlight")
CenterHL.FillColor = Color3.fromRGB(59, 218, 10)
CenterHL.FillTransparency = 0.45
CenterHL.OutlineColor = Color3.fromRGB(59, 218, 10)
CenterHL.Adornee = CenterPart
CenterHL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
CenterHL.Parent = CenterPart

local PlayerHL = Instance.new("Highlight")
PlayerHL.FillColor = P.accent
PlayerHL.FillTransparency = 0.35
PlayerHL.OutlineColor = P.accent
PlayerHL.Adornee = nil
PlayerHL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
PlayerHL.Parent = nil

-- ============================================================================
-- PLAYER SELECTION
-- ============================================================================
local function applyHighlight(char)
	if char then
		PlayerHL.Parent = char
	end
end

local function clearSelectedPlayer()
	selectedPlayer = nil
	if charAddedConn then
		charAddedConn:Disconnect()
		charAddedConn = nil
	end
	if spectateConn then
		spectateConn:Disconnect()
		spectateConn = nil
	end
	PlayerHL.Parent = nil
	PlayerLabel.Text = "No player selected"
	PlayerLabel.TextColor3 = P.sub
	DropdownBtn.Text = "Select Player"
	if spectating then
		spectating = false
		SpectateBtn.Text = " Spectate"
		SpectateBtn.BackgroundColor3 = P.row
		pcall(function()
			local h = LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid")
			if h then
				Workspace.CurrentCamera.CameraSubject = h
			end
		end)
	end
	loopFlinging = false
	LoopFlingBtn.Text = " Loop Fling  |  Off"
	LoopFlingBtn.BackgroundColor3 = P.red
end

local function selectPlayer(p)
	if charAddedConn then
		charAddedConn:Disconnect()
		charAddedConn = nil
	end
	if spectateConn then
		spectateConn:Disconnect()
		spectateConn = nil
	end
	selectedPlayer = p
	local dn = p.DisplayName ~= "" and p.DisplayName or p.Name
	DropdownBtn.Text = " " .. dn
	PlayerLabel.Text = "Target:  " .. dn
	PlayerLabel.TextColor3 = Color3.fromRGB(255, 160, 160)
	applyHighlight(p.Character)
	charAddedConn = p.CharacterAdded:Connect(function(char)
		task.wait(0.1)
		applyHighlight(char)
		if spectating then
			task.wait(0.1)
			local h = char:FindFirstChildWhichIsA("Humanoid")
			if h and spectating then
				Workspace.CurrentCamera.CameraSubject = h
			end
		end
	end)
end

Players.PlayerRemoving:Connect(function(p)
	if selectedPlayer == p then
		clearSelectedPlayer()
	end
end)

-- ── Dropdown ──────────────────────────────────────────────────────────────────
local dropdownOpen = false
local function closeDropdown()
	dropdownOpen = false
	DropdownList.Visible = false
end
local function populateAndOpenDropdown()
	for _, c in pairs(DropdownList:GetChildren()) do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end

	-- Build sorted list of other players by DisplayName
	local others = {}
	for _, p in pairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			local dn = p.DisplayName ~= "" and p.DisplayName or p.Name
			table.insert(others, { label = "  " .. dn, player = p, sort = dn:lower() })
		end
	end
	table.sort(others, function(a, b)
		return a.sort < b.sort
	end)

	-- Final entry list: No one • Local Player (display-only) • sorted others
	local localDN = LocalPlayer.DisplayName ~= "" and LocalPlayer.DisplayName or LocalPlayer.Name
	local entries = {
		{ label = "  No one", player = nil, isLocal = false },
	}
	for _, e in ipairs(others) do
		table.insert(entries, e)
	end

	for i, entry in ipairs(entries) do
		local row = Instance.new("TextButton", DropdownList)
		row.Size = UDim2.new(1, 0, 0, DD_ITEM_H)
		row.Position = UDim2.new(0, 0, 0, (i - 1) * DD_ITEM_H)
		row.BorderSizePixel = 0
		row.Font = Enum.Font.Gotham
		row.TextSize = 12
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = entry.label
		row.AutoButtonColor = false
		row.ZIndex = 21
		mkCorner(row, 4)
		if entry.isLocal then
			-- Local Player row: greyed out, not selectable
			row.BackgroundColor3 = P.row
			row.TextColor3 = P.sub
			row.MouseEnter:Connect(function()
				row.BackgroundColor3 = P.row
			end)
			row.MouseLeave:Connect(function()
				row.BackgroundColor3 = P.row
			end)
			-- no click action
		else
			row.BackgroundColor3 = (selectedPlayer == entry.player) and P.sel or P.row
			row.TextColor3 = P.text
			row.MouseEnter:Connect(function()
				if selectedPlayer ~= entry.player then
					row.BackgroundColor3 = P.rowHov
				end
			end)
			row.MouseLeave:Connect(function()
				row.BackgroundColor3 = (selectedPlayer == entry.player) and P.sel or P.row
			end)
			row.MouseButton1Click:Connect(function()
				closeDropdown()
				if entry.player == nil then
					clearSelectedPlayer()
				else
					selectPlayer(entry.player)
				end
			end)
		end
	end
	local total = #entries * DD_ITEM_H
	DropdownList.CanvasSize = UDim2.new(0, 0, 0, total)
	DropdownList.Size = UDim2.new(0.55, -10, 0, math.min(total, DD_MAX_H))
	dropdownOpen = true
	DropdownList.Visible = true
end
DropdownBtn.MouseButton1Click:Connect(function()
	if dropdownOpen then
		closeDropdown()
	else
		populateAndOpenDropdown()
	end
end)

-- ── Target tab button logic ────────────────────────────────────────────────────
local function cancelClickMode()
	clickMode = nil
	PlaceBtn.BackgroundColor3 = P.row
	PlaceBtn.Text = " Click to Place Center"
	ClickPlayerBtn.BackgroundColor3 = P.row
	ClickPlayerBtn.Text = " Click"
end

PlaceBtn.MouseButton1Click:Connect(function()
	if clickMode == "place" then
		cancelClickMode()
	else
		cancelClickMode()
		clickMode = "place"
		PlaceBtn.BackgroundColor3 = P.active
		PlaceBtn.Text = " Placing..."
	end
end)
IslandBtn.MouseButton1Click:Connect(function()
	orbitMode = "island"
	CenterPart.Transparency = 1
	ModeLabel.Text = "Mode:  Island  (workspace.Island)"
	cancelClickMode()
end)
ClickPlayerBtn.MouseButton1Click:Connect(function()
	if clickMode == "player" then
		cancelClickMode()
	else
		cancelClickMode()
		clickMode = "player"
		ClickPlayerBtn.BackgroundColor3 = P.active
		ClickPlayerBtn.Text = "Clicking..."
		closeDropdown()
	end
end)
FlingBtn.MouseButton1Click:Connect(function()
	if flinging then
		return
	end
	if not selectedPlayer or not selectedPlayer.Character then
		PlayerLabel.Text = "⚠  No player selected!"
		PlayerLabel.TextColor3 = p.red
		return
	end
	flinging = true
	FlingBtn.Text = " Flinging..."
	FlingBtn.BackgroundColor3 = P.orange
	spawn(function()
		local t0 = tick()
		while tick() - t0 < 3 do
			RunService.RenderStepped:Wait()
			local char = selectedPlayer and selectedPlayer.Character
			if not char then
				break
			end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if not hrp then
				break
			end
			for _, d in ipairs(orbitParts) do
				if d.anchor and d.anchor.Parent then
					d.anchor.CFrame = CFrame.new(hrp.Position)
				end
			end
		end
		flinging = false
		FlingBtn.Text = "Fling!"
		FlingBtn.BackgroundColor3 = P.red
	end)
end)
LoopFlingBtn.MouseButton1Click:Connect(function()
	if not loopFlinging then
		if not selectedPlayer or not selectedPlayer.Character then
			PlayerLabel.Text = "⚠  No player selected!"
			PlayerLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
			return
		end
		loopFlinging = true
		LoopFlingBtn.Text = " Loop Fling  |  On"
		LoopFlingBtn.BackgroundColor3 = P.orange
		spawn(function()
			while loopFlinging do
				RunService.RenderStepped:Wait()
				local char = selectedPlayer and selectedPlayer.Character
				if not char then
					break
				end
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if not hrp then
					break
				end
				for _, d in ipairs(orbitParts) do
					if d.anchor and d.anchor.Parent then
						d.anchor.CFrame = CFrame.new(hrp.Position)
					end
				end
			end
			loopFlinging = false
			LoopFlingBtn.Text = " Loop Fling  |  Off"
			LoopFlingBtn.BackgroundColor3 = P.red
		end)
	else
		loopFlinging = false
		LoopFlingBtn.Text = " Loop Fling  |  Off"
		LoopFlingBtn.BackgroundColor3 = P.red
	end
end)
SpectateBtn.MouseButton1Click:Connect(function()
	if not spectating then
		if not selectedPlayer then
			PlayerLabel.Text = "⚠  No player selected!"
			PlayerLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
			return
		end
		spectating = true
		SpectateBtn.Text = " Unspectate"
		SpectateBtn.BackgroundColor3 = P.active
		local char = selectedPlayer.Character
		if char then
			local h = char:FindFirstChildWhichIsA("Humanoid")
			if h then
				Workspace.CurrentCamera.CameraSubject = h
			end
		end
	else
		spectating = false
		SpectateBtn.Text = " Spectate"
		SpectateBtn.BackgroundColor3 = P.row
		pcall(function()
			local h = LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid")
			if h then
				Workspace.CurrentCamera.CameraSubject = h
			end
		end)
	end
end)

-- ============================================================================
-- INPUT HANDLER
-- ============================================================================
local Folder -- forward-declared, used in raycast excludes
UserInputService.InputBegan:Connect(function(input, gpe)
	if input.KeyCode == Enum.KeyCode.RightControl then
		mainVisible = not mainVisible
		Main.Visible = mainVisible
		return
	end
	if gpe then
		return
	end
	-- Rebind capture
	if rebindingFly then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			flyKeybind = input.KeyCode
			rebindingFly = false
			if KeybindBtn then
				KeybindBtn.Text = "Key: " .. tostring(flyKeybind.Name)
				KeybindBtn.BackgroundColor3 = P.panel
			end
		end
		return
	end
	-- Fly keybind
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == flyKeybind then
		toggleFly()
		return
	end
	-- Orbit keybind rebind capture
	if rebindingOrbit then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			orbitKeybind = input.KeyCode
			rebindingOrbit = false
			if OrbitKeybindBtn then
				OrbitKeybindBtn.Text = "Key: " .. tostring(orbitKeybind.Name)
				OrbitKeybindBtn.BackgroundColor3 = P.panel
			end
		end
		return
	end
	-- Orbit keybind
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == orbitKeybind then
		toggleOrbit()
		return
	end
	-- Escape
	if input.KeyCode == Enum.KeyCode.Escape then
		cancelClickMode()
		closeDropdown()
		return
	end
	-- Raycast
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		closeDropdown()
		if clickMode == nil then
			return
		end
		local camera = Workspace.CurrentCamera
		local mPos = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mPos.X, mPos.Y)
		local excl = { CenterPart }
		if Folder then
			table.insert(excl, Folder)
		end
		if LocalPlayer.Character then
			table.insert(excl, LocalPlayer.Character)
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = excl
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
		if clickMode == "place" then
			if hit then
				customCenter = hit.Position
				orbitMode = "custom"
				CenterPart.CFrame = CFrame.new(customCenter)
				CenterPart.Transparency = 0
				ModeLabel.Text = "Mode:  Custom Point"
			end
			cancelClickMode()
		elseif clickMode == "player" then
			if hit and hit.Instance then
				for _, p in pairs(Players:GetPlayers()) do
					if p ~= LocalPlayer and p.Character and hit.Instance:IsDescendantOf(p.Character) then
						selectPlayer(p)
						break
					end
				end
			end
			cancelClickMode()
		end
	end
end)

-- ============================================================================
-- PHYSICS HARNESS
-- ============================================================================
Folder = Instance.new("Folder", Workspace)
if not getgenv().Network then
	getgenv().Network = { BaseParts = {}, Velocity = Vector3.new(14.46262424, 14.46262424, 14.46262424) }
	Network.RetainPart = function(p)
		if p:IsA("BasePart") and p:IsDescendantOf(Workspace) then
			table.insert(Network.BaseParts, p)
			p.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0, 0, 0)
			p.CanCollide = false
		end
	end
	local function EnablePartControl()
		LocalPlayer.ReplicationFocus = Workspace
		RunService.Heartbeat:Connect(function()
			sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
			for _, p in pairs(Network.BaseParts) do
				if p:IsDescendantOf(Workspace) then
					p.Velocity = Network.Velocity
				end
			end
		end)
	end
	EnablePartControl()
end

-- ============================================================================
-- SHAPE MATH
-- ============================================================================
local function polygonPoint(a, R, n)
	local s = (2 * math.pi) / n
	local t = (a % s) - s / 2
	if math.abs(math.cos(t)) < 1e-6 then
		t = t + 1e-6
	end
	local r = R * math.cos(s / 2) / math.cos(t)
	return math.cos(a) * r, math.sin(a) * r
end
local function starPoint(a, oR, iR, np)
	local step = math.pi / (np or 5)
	local frac = (a % step) / step
	local seg = math.floor((a % (2 * math.pi)) / step) % 2
	local r = seg == 0 and (oR + (iR - oR) * frac) or (iR + (oR - iR) * frac)
	return math.cos(a) * r, math.sin(a) * r
end
local function rosePoint(a, R, p)
	local r = R * math.abs(math.cos(p * a))
	return math.cos(a) * r, math.sin(a) * r
end
local function spiralPoint(a, R, t)
	local s = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(t * 0.8))
	return math.cos(a) * R * s, math.sin(a) * R * s
end

SHAPES = {
	{
		name = "Circle",
		icon = "⬤",
		fn = function(a, R, i, n, t)
			return math.cos(a) * R, math.sin(a) * R, 0
		end,
	},
	{
		name = "Square",
		icon = "■",
		fn = function(a, R, i, n, t)
			local x, z = polygonPoint(a, R, 4)
			return x, z, 0
		end,
	},
	{
		name = "Triangle",
		icon = "▲",
		fn = function(a, R, i, n, t)
			local x, z = polygonPoint(a, R, 3)
			return x, z, 0
		end,
	},
	{
		name = "Diamond",
		icon = "◆",
		fn = function(a, R, i, n, t)
			local x, z = polygonPoint(a + math.pi / 4, R, 4)
			return x, z, 0
		end,
	},
	{
		name = "Pentagon",
		icon = "⬠",
		fn = function(a, R, i, n, t)
			local x, z = polygonPoint(a, R, 5)
			return x, z, 0
		end,
	},
	{
		name = "Hexagon",
		icon = "⬡",
		fn = function(a, R, i, n, t)
			local x, z = polygonPoint(a, R, 6)
			return x, z, 0
		end,
	},
	{
		name = "Star(5pt)",
		icon = "★",
		fn = function(a, R, i, n, t)
			local x, z = starPoint(a, R, R * 0.42, 5)
			return x, z, 0
		end,
	},
	{
		name = "Star(6pt)",
		icon = "✡",
		fn = function(a, R, i, n, t)
			local x, z = starPoint(a, R, R * 0.50, 6)
			return x, z, 0
		end,
	},
	{
		name = "Figure-8",
		icon = "∞",
		fn = function(a, R, i, n, t)
			return math.cos(a) * R, math.sin(2 * a) * (R * 0.5), 0
		end,
	},
	{
		name = "Flower",
		icon = "✿",
		fn = function(a, R, i, n, t)
			local x, z = rosePoint(a, R, 4)
			return x, z, 0
		end,
	},
	{
		name = "Spiral",
		icon = "🌀",
		fn = function(a, R, i, n, t)
			local x, z = spiralPoint(a, R, t)
			return x, z, 0
		end,
	},
	{
		name = "Helix",
		icon = "🧬",
		fn = function(a, R, i, n, t)
			local frac = (i - 1) / math.max(n - 1, 1)
			return math.cos(a) * R, math.sin(a) * R, (frac * 2 - 1) * (Config.HELIX_SPAN / 2)
		end,
	},
}
-- currentShapeIndex and shapeButtons are forward-declared above

local function buildShapeList()
	for idx, shape in ipairs(SHAPES) do
		local btn = Instance.new("TextButton", ShapesContent)
		btn.LayoutOrder = idx
		btn.Size = UDim2.new(1, 0, 0, ITEM_H)
		btn.BackgroundColor3 = idx == 1 and P.sel or P.row
		btn.BorderSizePixel = 0
		btn.Font = Enum.Font.Gotham
		btn.TextSize = 12
		btn.TextColor3 = P.text
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.Text = "  " .. shape.icon .. "  " .. shape.name
		btn.AutoButtonColor = false
		mkCorner(btn, 5)
		btn.MouseEnter:Connect(function()
			if idx ~= currentShapeIndex then
				btn.BackgroundColor3 = P.rowHov
			end
		end)
		btn.MouseLeave:Connect(function()
			if idx ~= currentShapeIndex then
				btn.BackgroundColor3 = P.row
			end
		end)
		btn.MouseButton1Click:Connect(function()
			if shapeButtons[currentShapeIndex] then
				shapeButtons[currentShapeIndex].BackgroundColor3 = P.row
			end
			currentShapeIndex = idx
			btn.BackgroundColor3 = P.sel
		end)
		shapeButtons[idx] = btn
	end
	ShapesContent.CanvasSize = UDim2.new(0, 0, 0, #SHAPES * ITEM_H + (#SHAPES - 1) * 3 + 8)
end

-- ============================================================================
-- SETTINGS SLIDERS + FLY SECTION
-- ============================================================================
local activeDrag = nil
applyFrac = function(frac, def, fill, thumb, valLbl)
	frac = math.clamp(frac, 0, 1)
	local v =
		math.clamp(math.floor((def.min + frac * (def.max - def.min)) / def.step + 0.5) * def.step, def.min, def.max)
	Config[def.key] = v
	valLbl.Text = string.format(def.fmt, v)
	fill.Size = UDim2.new(frac, 0, 1, 0)
	thumb.Position = UDim2.new(frac, -6, 0.5, -6)
end

local function buildSettingsSliders()
	-- Orbit section header
	local orbitHdrRow = Instance.new("Frame", SettingsContent)
	orbitHdrRow.LayoutOrder = 0
	orbitHdrRow.Size = UDim2.new(1, 0, 0, 20)
	orbitHdrRow.BackgroundColor3 = P.section
	orbitHdrRow.BackgroundTransparency = 0.55
	orbitHdrRow.BorderSizePixel = 0
	mkCorner(orbitHdrRow, 3)
	local orbitHdrLbl = Instance.new("TextLabel", orbitHdrRow)
	orbitHdrLbl.BackgroundTransparency = 1
	orbitHdrLbl.Size = UDim2.new(1, -8, 1, 0)
	orbitHdrLbl.Position = UDim2.new(0, 8, 0, 0)
	orbitHdrLbl.Font = Enum.Font.GothamBold
	orbitHdrLbl.TextSize = 12
	orbitHdrLbl.TextColor3 = P.accent
	orbitHdrLbl.Text = "ORBIT"
	orbitHdrLbl.TextXAlignment = Enum.TextXAlignment.Left

	for idx, def in ipairs(SETTING_DEFS) do
		local row = Instance.new("Frame", SettingsContent)
		row.LayoutOrder = idx
		row.Size = UDim2.new(1, 0, 0, SET_ROW_H)
		row.BackgroundColor3 = P.row
		row.BorderSizePixel = 0
		mkCorner(row, 5)
		local rp = Instance.new("UIPadding", row)
		rp.PaddingLeft = UDim.new(0, 8)
		rp.PaddingRight = UDim.new(0, 8)
		rp.PaddingTop = UDim.new(0, 4)
		local nl = Instance.new("TextLabel", row)
		nl.BackgroundTransparency = 1
		nl.Position = UDim2.new(0, 0, 0, 0)
		nl.Size = UDim2.new(0.55, 0, 0, 14)
		nl.Font = Enum.Font.GothamSemibold
		nl.TextSize = 12
		nl.TextColor3 = P.text
		nl.TextXAlignment = Enum.TextXAlignment.Left
		nl.Text = def.label
		local vl = Instance.new("TextLabel", row)
		vl.BackgroundTransparency = 1
		vl.Position = UDim2.new(0.55, 0, 0, 0)
		vl.Size = UDim2.new(0.45, 0, 0, 14)
		vl.Font = Enum.Font.GothamBold
		vl.TextSize = 12
		vl.TextColor3 = P.thumb
		vl.TextXAlignment = Enum.TextXAlignment.Right
		vl.Text = string.format(def.fmt, Config[def.key])
		local track = Instance.new("Frame", row)
		track.Position = UDim2.new(0, 0, 0, 18)
		track.Size = UDim2.new(1, 0, 0, 8)
		track.BackgroundColor3 = P.track
		track.BorderSizePixel = 0
		mkCorner(track, 4)
		local frac0 = (Config[def.key] - def.min) / (def.max - def.min)
		local fill = Instance.new("Frame", track)
		fill.BackgroundColor3 = P.fill
		fill.BorderSizePixel = 0
		fill.Size = UDim2.new(frac0, 0, 1, 0)
		mkCorner(fill, 4)
		local thumb = Instance.new("TextButton", track)
		thumb.Size = UDim2.new(0, 12, 0, 12)
		thumb.Position = UDim2.new(frac0, -6, 0.5, -6)
		thumb.BackgroundColor3 = P.thumb
		thumb.BorderSizePixel = 0
		thumb.Text = ""
		thumb.ZIndex = 5
		thumb.AutoButtonColor = false
		mkCorner(thumb, 6)
		-- Register slider UI refs for live updates when loading a config
		sliderRegistry[def.key] = { fill = fill, thumb = thumb, valLbl = vl, def = def }
		track.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then
				activeDrag = { def = def, fill = fill, thumb = thumb, valLbl = vl, track = track }
				applyFrac((inp.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, def, fill, thumb, vl)
			end
		end)
		thumb.MouseButton1Down:Connect(function()
			activeDrag = { def = def, fill = fill, thumb = thumb, valLbl = vl, track = track }
		end)
	end

	-- Fly section
	local flyHdrRow = Instance.new("Frame", SettingsContent)
	flyHdrRow.LayoutOrder = 90
	flyHdrRow.Size = UDim2.new(1, 0, 0, 20)
	flyHdrRow.BackgroundColor3 = P.section
	flyHdrRow.BackgroundTransparency = 0.55
	flyHdrRow.BorderSizePixel = 0
	mkCorner(flyHdrRow, 3)
	local flyHdrLbl = Instance.new("TextLabel", flyHdrRow)
	flyHdrLbl.BackgroundTransparency = 1
	flyHdrLbl.Size = UDim2.new(1, -8, 1, 0)
	flyHdrLbl.Position = UDim2.new(0, 8, 0, 0)
	flyHdrLbl.Font = Enum.Font.GothamBold
	flyHdrLbl.TextSize = 12
	flyHdrLbl.TextColor3 = P.accent
	flyHdrLbl.Text = "FLY"
	flyHdrLbl.TextXAlignment = Enum.TextXAlignment.Left

	local flyBtnRow = Instance.new("Frame", SettingsContent)
	flyBtnRow.LayoutOrder = 91
	flyBtnRow.Size = UDim2.new(1, 0, 0, 28)
	flyBtnRow.BackgroundTransparency = 1
	flyBtnRow.BorderSizePixel = 0

	FlySystemBtn = Instance.new("TextButton", flyBtnRow)
	FlySystemBtn.BackgroundColor3 = P.green
	FlySystemBtn.BorderSizePixel = 0
	FlySystemBtn.Position = UDim2.new(0, 0, 0, 0)
	FlySystemBtn.Size = UDim2.new(0.48, 0, 1, 0)
	FlySystemBtn.Font = Enum.Font.GothamBold
	FlySystemBtn.TextSize = 12
	FlySystemBtn.TextColor3 = P.text
	FlySystemBtn.Text = "System: ON"
	FlySystemBtn.AutoButtonColor = false
	mkCorner(FlySystemBtn, 5)
	FlySystemBtn.MouseButton1Click:Connect(function()
		flySystemEnabled = not flySystemEnabled
		if not flySystemEnabled then
			if flying then
				stopFly()
			end
			FlySystemBtn.Text = "System: OFF"
			FlySystemBtn.BackgroundColor3 = P.disabled
			if FlyBtn then
				FlyBtn.BackgroundColor3 = P.disabled
			end
		else
			FlySystemBtn.Text = "System: ON"
			FlySystemBtn.BackgroundColor3 = P.green
			if FlyBtn then
				FlyBtn.Text = "✈  Fly  |  Off"
				FlyBtn.BackgroundColor3 = P.row
			end
		end
	end)

	FlyBtn = Instance.new("TextButton", flyBtnRow)
	FlyBtn.BackgroundColor3 = P.row
	FlyBtn.BorderSizePixel = 0
	FlyBtn.Position = UDim2.new(0.52, 0, 0, 0)
	FlyBtn.Size = UDim2.new(0.48, 0, 1, 0)
	FlyBtn.Font = Enum.Font.GothamBold
	FlyBtn.TextSize = 12
	FlyBtn.TextColor3 = P.text
	FlyBtn.Text = "✈  Fly  |  Off"
	FlyBtn.AutoButtonColor = false
	mkCorner(FlyBtn, 5)
	FlyBtn.MouseButton1Click:Connect(function()
		if flySystemEnabled then
			toggleFly()
		end
	end)

	local kbRow = Instance.new("Frame", SettingsContent)
	kbRow.LayoutOrder = 92
	kbRow.Size = UDim2.new(1, 0, 0, SET_ROW_H + 16)
	kbRow.BackgroundColor3 = P.row
	kbRow.BorderSizePixel = 0
	mkCorner(kbRow, 5)
	local kbPad = Instance.new("UIPadding", kbRow)
	kbPad.PaddingLeft = UDim.new(0, 8)
	kbPad.PaddingRight = UDim.new(0, 8)
	kbPad.PaddingTop = UDim.new(0, 4)
	local kbLbl = Instance.new("TextLabel", kbRow)
	kbLbl.BackgroundTransparency = 1
	kbLbl.Position = UDim2.new(0, 0, 0, 0)
	kbLbl.Size = UDim2.new(0.5, 0, 0, 14)
	kbLbl.Font = Enum.Font.GothamSemibold
	kbLbl.TextSize = 12
	kbLbl.TextColor3 = P.sub
	kbLbl.TextXAlignment = Enum.TextXAlignment.Left
	kbLbl.Text = "Fly Keybind"
	KeybindBtn = Instance.new("TextButton", kbRow)
	KeybindBtn.BackgroundColor3 = P.panel
	KeybindBtn.BorderSizePixel = 0
	KeybindBtn.Position = UDim2.new(0.5, 0, 0, 0)
	KeybindBtn.Size = UDim2.new(0.5, 0, 0, 22)
	KeybindBtn.Font = Enum.Font.GothamBold
	KeybindBtn.TextSize = 12
	KeybindBtn.TextColor3 = P.thumb
	KeybindBtn.Text = "Key: F"
	KeybindBtn.AutoButtonColor = false
	mkCorner(KeybindBtn, 4)
	KeybindBtn.MouseButton1Click:Connect(function()
		if rebindingFly then
			rebindingFly = false
			KeybindBtn.Text = "Key: " .. tostring(flyKeybind.Name)
			KeybindBtn.BackgroundColor3 = P.panel
		else
			rebindingFly = true
			KeybindBtn.Text = "Press key..."
			KeybindBtn.BackgroundColor3 = P.active
		end
	end)
	local hint = Instance.new("TextLabel", kbRow)
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.new(0, 0, 0, SET_ROW_H - 2)
	hint.Size = UDim2.new(1, 0, 0, 14)
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 12
	hint.TextColor3 = P.sub
	hint.TextScaled = true
	hint.Text = "WASD+Space/LCtrl  |  Shift=fast"
	hint.TextXAlignment = Enum.TextXAlignment.Left

	-- Orbit Keybind row
	local okbRow = Instance.new("Frame", SettingsContent)
	okbRow.LayoutOrder = 93
	okbRow.Size = UDim2.new(1, 0, 0, SET_ROW_H)
	okbRow.BackgroundColor3 = P.row
	okbRow.BorderSizePixel = 0
	mkCorner(okbRow, 5)
	local okbPad = Instance.new("UIPadding", okbRow)
	okbPad.PaddingLeft = UDim.new(0, 8)
	okbPad.PaddingRight = UDim.new(0, 8)
	okbPad.PaddingTop = UDim.new(0, 4)
	local okbLbl = Instance.new("TextLabel", okbRow)
	okbLbl.BackgroundTransparency = 1
	okbLbl.Position = UDim2.new(0, 0, 0, 0)
	okbLbl.Size = UDim2.new(0.5, 0, 0, 14)
	okbLbl.Font = Enum.Font.GothamSemibold
	okbLbl.TextSize = 12
	okbLbl.TextColor3 = P.sub
	okbLbl.TextXAlignment = Enum.TextXAlignment.Left
	okbLbl.Text = "Orbit Keybind"
	OrbitKeybindBtn = Instance.new("TextButton", okbRow)
	OrbitKeybindBtn.BackgroundColor3 = P.panel
	OrbitKeybindBtn.BorderSizePixel = 0
	OrbitKeybindBtn.Position = UDim2.new(0.5, 0, 0, 0)
	OrbitKeybindBtn.Size = UDim2.new(0.5, 0, 0, 22)
	OrbitKeybindBtn.Font = Enum.Font.GothamBold
	OrbitKeybindBtn.TextSize = 12
	OrbitKeybindBtn.TextColor3 = P.thumb
	OrbitKeybindBtn.Text = "Key: V"
	OrbitKeybindBtn.AutoButtonColor = false
	mkCorner(OrbitKeybindBtn, 4)
	OrbitKeybindBtn.MouseButton1Click:Connect(function()
		if rebindingOrbit then
			rebindingOrbit = false
			OrbitKeybindBtn.Text = "Key: " .. tostring(orbitKeybind.Name)
			OrbitKeybindBtn.BackgroundColor3 = P.panel
		else
			rebindingOrbit = true
			OrbitKeybindBtn.Text = "Press key..."
			OrbitKeybindBtn.BackgroundColor3 = P.active
		end
	end)
end

UserInputService.InputChanged:Connect(function(inp)
	if activeDrag and inp.UserInputType == Enum.UserInputType.MouseMovement then
		local d = activeDrag
		applyFrac(
			(inp.Position.X - d.track.AbsolutePosition.X) / d.track.AbsoluteSize.X,
			d.def,
			d.fill,
			d.thumb,
			d.valLbl
		)
	end
end)
UserInputService.InputEnded:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1 then
		activeDrag = nil
	end
end)

-- ============================================================================
-- ORBIT ENGINE
-- ============================================================================
orbitParts = {}
local function ForcePart(v)
	if
		v:IsA("BasePart")
		and not v.Anchored
		and not v:IsDescendantOf(IslandModel)
		and not v.Parent:FindFirstChildOfClass("Humanoid")
		and not v.Parent:FindFirstChild("Head")
		and v.Name ~= "Handle"
		and v ~= CenterPart
	then
		for _, x in ipairs(v:GetChildren()) do
			if x:IsA("BodyMover") or x:IsA("RocketPropulsion") then
				x:Destroy()
			end
		end
		for _, n in ipairs({ "Attachment", "AlignPosition", "Torque" }) do
			local c = v:FindFirstChild(n)
			if c then
				c:Destroy()
			end
		end
		v.CanCollide = false
		local anchor = Instance.new("Part", Folder)
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.1, 0.1, 0.1)
		anchor.CFrame = v.CFrame
		local aAtt = Instance.new("Attachment", anchor)
		local pAtt = Instance.new("Attachment", v)
		local Tq = Instance.new("Torque", v)
		Tq.Attachment0 = pAtt
		Tq.Torque = Vector3.new(1e5, 1e5, 1e5)
		local AP = Instance.new("AlignPosition", v)
		AP.MaxForce = math.huge
		AP.MaxVelocity = math.huge
		AP.Responsiveness = 200
		AP.Attachment0 = pAtt
		AP.Attachment1 = aAtt
		table.insert(orbitParts, { anchor = anchor, attachment = aAtt })
	end
end
local blackHoleActive = false
local DescendantAddedConnection
local function cleanupOrbitParts()
	for _, d in ipairs(orbitParts) do
		if d.anchor and d.anchor.Parent then
			d.anchor:Destroy()
		end
	end
	orbitParts = {}
end
local function getOrbitCenter()
	if orbitMode == "island" then
		local ok, cf = pcall(function()
			return IslandModel:GetBoundingBox()
		end)
		return ok and cf.Position or customCenter
	else
		return customCenter
	end
end
toggleOrbit = function()
	blackHoleActive = not blackHoleActive
	if blackHoleActive then
		OrbitBtn.Text = "Orbit  |  On"
		OrbitBtn.BackgroundColor3 = P.green
		cleanupOrbitParts()
		for _, v in ipairs(Workspace:GetDescendants()) do
			ForcePart(v)
		end
		DescendantAddedConnection = Workspace.DescendantAdded:Connect(function(v)
			if blackHoleActive then
				ForcePart(v)
			end
		end)
		spawn(function()
			local t = 0
			while blackHoleActive do
				local dt = RunService.RenderStepped:Wait()
				t = t + dt * Config.ORBIT_SPEED * (2 * math.pi)
				if flinging or loopFlinging then
					continue
				end
				local ok, center = pcall(getOrbitCenter)
				if not ok then
					break
				end
				local origin = center + Vector3.new(0, Config.ORBIT_HEIGHT, 0)
				local count = #orbitParts
				local shape = SHAPES[currentShapeIndex]
				for i, data in ipairs(orbitParts) do
					if data.anchor and data.anchor.Parent then
						local off = (i / math.max(count, 1)) * (2 * math.pi)
						local angle = t + off
						local x, z, yExtra = shape.fn(angle, Config.ORBIT_RADIUS, i, count, t)
						local y = (shape.name == "Helix") and yExtra
							or math.sin(t * Config.Y_WAVE_SPEED + off) * Config.Y_WAVE_AMP + yExtra
						data.anchor.CFrame = CFrame.new(origin + Vector3.new(x, y, z))
					end
				end
			end
		end)
	else
		OrbitBtn.Text = "Orbit  |  Off"
		OrbitBtn.BackgroundColor3 = P.row
		loopFlinging = false
		LoopFlingBtn.Text = " Loop Fling  |  Off"
		LoopFlingBtn.BackgroundColor3 = P.red
		if DescendantAddedConnection then
			DescendantAddedConnection:Disconnect()
			DescendantAddedConnection = nil
		end
		cleanupOrbitParts()
	end
end

-- ============================================================================
-- INIT
-- ============================================================================
buildShapeList()
buildSettingsSliders()

-- Wire OrbitBtn click directly (no Script instance needed in LocalScript context)
OrbitBtn.MouseButton1Click:Connect(function()
	toggleOrbit()
end)
