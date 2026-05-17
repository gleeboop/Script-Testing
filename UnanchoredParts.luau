local Gui = Instance.new("ScreenGui")
local Main = Instance.new("Frame")
local TitleLabel = Instance.new("TextLabel")
local TabBar = Instance.new("Frame")
local TabShapes = Instance.new("TextButton")
local TabSettings = Instance.new("TextButton")
local TabTarget = Instance.new("TextButton")
local ContentFrame = Instance.new("Frame")
local ShapesContent = Instance.new("ScrollingFrame")
local ShapesLayout = Instance.new("UIListLayout")
local ShapesPadding = Instance.new("UIPadding")
local SettingsContent = Instance.new("Frame")
local SettingsLayout = Instance.new("UIListLayout")
local TargetContent = Instance.new("Frame")
local OrbitBtn = Instance.new("TextButton")
local LoopFlingBtn = Instance.new("TextButton")
-- Dropdown overlay (parented to Main so it escapes ContentFrame clipping)
local DropdownList = Instance.new("ScrollingFrame")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local IslandModel = nil
if workspace:FindFirstChild("Island") == nil then
	IslandModel = Instance.new("Model", workspace)
else
	IslandModel = Workspace:WaitForChild("Island")
end

local Config = {
	ORBIT_RADIUS = 20,
	ORBIT_HEIGHT = 5,
	ORBIT_SPEED = 0.6,
	Y_WAVE_AMP = 2.0,
	Y_WAVE_SPEED = 1.2,
	HELIX_SPAN = 18,
}

local SETTING_DEFS = {
	{
		label = "Radius",
		key = "ORBIT_RADIUS",
		min = 2,
		max = 300,
		step = 1,
		fmt = "%.0f",
		desc = "Studs from island center",
	},
	{
		label = "Height",
		key = "ORBIT_HEIGHT",
		min = -20,
		max = 300,
		step = 1,
		fmt = "%.0f",
		desc = "Studs above bounding box",
	},
	{
		label = "Speed",
		key = "ORBIT_SPEED",
		min = 0.1,
		max = 5.0,
		step = 0.1,
		fmt = "%.1f",
		desc = "Rotations per second",
	},
	{
		label = "Wave Amp",
		key = "Y_WAVE_AMP",
		min = 0,
		max = 15,
		step = 0.5,
		fmt = "%.1f",
		desc = "Vertical bob height",
	},
	{
		label = "Wave Spd",
		key = "Y_WAVE_SPEED",
		min = 0.1,
		max = 5.0,
		step = 0.1,
		fmt = "%.1f",
		desc = "Vertical bob speed",
	},
	{
		label = "Helix H",
		key = "HELIX_SPAN",
		min = 2,
		max = 80,
		step = 2,
		fmt = "%.0f",
		desc = "Helix vertical range",
	},
}

local P = {
	bg = Color3.fromRGB(24, 24, 28),
	panel = Color3.fromRGB(36, 36, 42),
	row = Color3.fromRGB(50, 50, 58),
	rowHov = Color3.fromRGB(64, 64, 74),
	sel = Color3.fromRGB(50, 85, 200),
	tabOn = Color3.fromRGB(50, 85, 200),
	tabOff = Color3.fromRGB(42, 42, 50),
	track = Color3.fromRGB(32, 32, 40),
	fill = Color3.fromRGB(50, 85, 200),
	thumb = Color3.fromRGB(155, 180, 255),
	text = Color3.fromRGB(220, 220, 230),
	sub = Color3.fromRGB(130, 130, 150),
	green = Color3.fromRGB(38, 120, 56),
	red = Color3.fromRGB(170, 40, 40),
	orange = Color3.fromRGB(180, 100, 20),
	active = Color3.fromRGB(180, 130, 20),
	ddBg = Color3.fromRGB(28, 28, 34),
}

-- Layout constants
-- Target tab items stack to y=258+26=284; add 6px padding → 290
local CONTENT_H = 290
local ITEM_H = 30
local SET_ROW_H = 34
-- ContentFrame: y=62, h=CONTENT_H → ends at 62+290=352
-- OrbitBtn: y=352+6=358, h=28 → ends 386; Main height=386+7=393
local ORBIT_Y = 358
local MAIN_H = 393

-- ── Helpers ──────────────────────────────────────────────────────────────────
local function mkCorner(inst, r)
	local c = Instance.new("UICorner", inst)
	c.CornerRadius = UDim.new(0, r or 6)
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

local function mkSep(parent, yPos)
	local s = Instance.new("Frame", parent)
	s.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
	s.BorderSizePixel = 0
	s.Position = UDim2.new(0, 6, 0, yPos)
	s.Size = UDim2.new(1, -12, 0, 1)
	return s
end

-- ── Main window ───────────────────────────────────────────────────────────────
Gui.Name = "OrbitGUI"
Gui.Parent = gethui()
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

Main.Parent = Gui
Main.BackgroundColor3 = P.bg
Main.BorderSizePixel = 0
Main.Position = UDim2.new(0.04, 0, 0.18, 0)
Main.Size = UDim2.new(0, 225, 0, MAIN_H)
Main.Active = true
Main.Draggable = true
mkCorner(Main, 10)

TitleLabel.Parent = Main
TitleLabel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
TitleLabel.BorderSizePixel = 0
TitleLabel.Size = UDim2.new(1, 0, 0, 34)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "  🌀  Orbit Island"
TitleLabel.TextColor3 = P.text
TitleLabel.TextSize = 14
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
mkCorner(TitleLabel, 10)

TabBar.Parent = Main
TabBar.BackgroundColor3 = P.panel
TabBar.BorderSizePixel = 0
TabBar.Position = UDim2.new(0, 0, 0, 34)
TabBar.Size = UDim2.new(1, 0, 0, 28)

local function styleTab(btn, txt, x, active)
	btn.Parent = TabBar
	btn.BorderSizePixel = 0
	btn.Position = UDim2.new(x, 2, 0, 3)
	btn.Size = UDim2.new(0.333, -4, 1, -6)
	btn.Font = Enum.Font.GothamSemibold
	btn.Text = txt
	btn.TextSize = 11
	btn.TextColor3 = active and P.text or P.sub
	btn.BackgroundColor3 = active and P.tabOn or P.tabOff
	btn.AutoButtonColor = false
	mkCorner(btn, 5)
end
styleTab(TabShapes, "⬤ Shapes", 0, true)
styleTab(TabSettings, "⚙ Settings", 0.333, false)
styleTab(TabTarget, "🎯 Target", 0.666, false)

ContentFrame.Parent = Main
ContentFrame.BackgroundColor3 = P.panel
ContentFrame.BorderSizePixel = 0
ContentFrame.Position = UDim2.new(0, 0, 0, 62)
ContentFrame.Size = UDim2.new(1, 0, 0, CONTENT_H)
ContentFrame.ClipsDescendants = true

-- ── Shapes tab ────────────────────────────────────────────────────────────────
ShapesContent.Parent = ContentFrame
ShapesContent.BackgroundTransparency = 1
ShapesContent.BorderSizePixel = 0
ShapesContent.Size = UDim2.new(1, 0, 1, 0)
ShapesContent.ScrollBarThickness = 5
ShapesContent.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 150)
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
SettingsContent.Parent = ContentFrame
SettingsContent.BackgroundTransparency = 1
SettingsContent.BorderSizePixel = 0
SettingsContent.Size = UDim2.new(1, 0, 1, 0)
SettingsContent.Visible = false

SettingsLayout.Parent = SettingsContent
SettingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
SettingsLayout.Padding = UDim.new(0, 2)

local stgPad = Instance.new("UIPadding", SettingsContent)
stgPad.PaddingTop = UDim.new(0, 5)
stgPad.PaddingLeft = UDim.new(0, 6)
stgPad.PaddingRight = UDim.new(0, 6)

-- ── Target tab ────────────────────────────────────────────────────────────────
TargetContent.Parent = ContentFrame
TargetContent.BackgroundTransparency = 1
TargetContent.BorderSizePixel = 0
TargetContent.Size = UDim2.new(1, 0, 1, 0)
TargetContent.Visible = false

local OC_Header = mkLabel(
	TargetContent,
	"📍  Orbit Center",
	UDim2.new(0, 8, 0, 6),
	UDim2.new(1, -16, 0, 16),
	nil,
	Enum.TextXAlignment.Left
)
OC_Header.Font = Enum.Font.GothamBold
OC_Header.TextColor3 = P.thumb

local ModeLabel = mkLabel(
	TargetContent,
	"Mode:  Island  (workspace.Island)",
	UDim2.new(0, 8, 0, 26),
	UDim2.new(1, -16, 0, 22),
	P.panel,
	Enum.TextXAlignment.Left
)
ModeLabel.TextColor3 = P.sub
ModeLabel.TextSize = 11
mkCorner(ModeLabel, 4)
local mlPad = Instance.new("UIPadding", ModeLabel)
mlPad.PaddingLeft = UDim.new(0, 5)

local PlaceBtn = mkBtn(TargetContent, "🖱  Click to Place Center", UDim2.new(0, 8, 0, 52), UDim2.new(1, -16, 0, 26))
local IslandBtn = mkBtn(
	TargetContent,
	"🏝  Reset to Island Orbit",
	UDim2.new(0, 8, 0, 82),
	UDim2.new(1, -16, 0, 26),
	Color3.fromRGB(40, 80, 50)
)

mkSep(TargetContent, 116)

local PL_Header = mkLabel(
	TargetContent,
	"💥  Player Fling",
	UDim2.new(0, 8, 0, 122),
	UDim2.new(1, -16, 0, 16),
	nil,
	Enum.TextXAlignment.Left
)
PL_Header.Font = Enum.Font.GothamBold
PL_Header.TextColor3 = Color3.fromRGB(255, 140, 140)

-- Status row showing who is selected
local PlayerLabel = mkLabel(
	TargetContent,
	"No player selected",
	UDim2.new(0, 8, 0, 142),
	UDim2.new(1, -16, 0, 22),
	P.panel,
	Enum.TextXAlignment.Left
)
PlayerLabel.TextColor3 = P.sub
PlayerLabel.TextSize = 11
mkCorner(PlayerLabel, 4)
local plPad = Instance.new("UIPadding", PlayerLabel)
plPad.PaddingLeft = UDim.new(0, 5)

-- Dropdown button (replaces "Click a Player" button)
local DropdownBtn = mkBtn(TargetContent, "▾  Select Player", UDim2.new(0, 8, 0, 168), UDim2.new(1, -16, 0, 26))

local FlingBtn = mkBtn(TargetContent, "💥  Fling!", UDim2.new(0, 8, 0, 198), UDim2.new(1, -16, 0, 26), P.red)

LoopFlingBtn.Parent = TargetContent
LoopFlingBtn.BackgroundColor3 = P.red
LoopFlingBtn.BorderSizePixel = 0
LoopFlingBtn.Position = UDim2.new(0, 8, 0, 228)
LoopFlingBtn.Size = UDim2.new(1, -16, 0, 26)
LoopFlingBtn.Font = Enum.Font.GothamBold
LoopFlingBtn.Text = "🔁  Loop Fling  |  Off"
LoopFlingBtn.TextColor3 = P.text
LoopFlingBtn.TextSize = 12
LoopFlingBtn.AutoButtonColor = false
mkCorner(LoopFlingBtn, 5)

-- Spectate button
local SpectateBtn = mkBtn(TargetContent, "👁  Spectate", UDim2.new(0, 8, 0, 258), UDim2.new(1, -16, 0, 26))

-- ── Dropdown overlay (parented to Main, above ContentFrame clip) ──────────────
-- It appears right below the DropdownBtn in screen space.
-- DropdownBtn is at TargetContent y=168; ContentFrame starts at Main y=62
-- So in Main coords: dropdown top = 62 + 168 + 26 = 256
local DD_MAX_H = 110 -- max visible height before scrolling
DropdownList.Parent = Main
DropdownList.BackgroundColor3 = P.ddBg
DropdownList.BorderSizePixel = 0
DropdownList.Position = UDim2.new(0, 8, 0, 256)
DropdownList.Size = UDim2.new(1, -16, 0, DD_MAX_H)
DropdownList.ScrollBarThickness = 4
DropdownList.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 150)
DropdownList.ScrollingDirection = Enum.ScrollingDirection.Y
DropdownList.CanvasSize = UDim2.new(0, 0, 0, 0)
DropdownList.Visible = false
DropdownList.ZIndex = 20
mkCorner(DropdownList, 5)

-- ── Orbit toggle button (fixed below content, parent = Main) ─────────────────
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

-- ── Tab switching ─────────────────────────────────────────────────────────────
local tabBtns = { TabShapes, TabSettings, TabTarget }
local tabPanels = { ShapesContent, SettingsContent, TargetContent }

local function switchTab(idx)
	-- Always close dropdown when switching away from Target
	DropdownList.Visible = false
	for i = 1, 3 do
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
TabTarget.MouseButton1Click:Connect(function()
	switchTab(3)
end)

-- ── Hide / show whole GUI ─────────────────────────────────────────────────────
local mainVisible = true

-- ── World objects ─────────────────────────────────────────────────────────────
local CenterPart = Instance.new("Part")
CenterPart.Name = "_OrbitCenter"
CenterPart.Size = Vector3.new(1, 1, 1)
CenterPart.Anchored = true
CenterPart.CanCollide = false
CenterPart.CastShadow = false
CenterPart.Material = Enum.Material.Neon
CenterPart.Color = Color3.fromRGB(59, 218, 10)
CenterPart.Transparency = 1
CenterPart.Parent = Workspace

local CenterHL = Instance.new("Highlight")
CenterHL.FillColor = Color3.fromRGB(59, 218, 10)
CenterHL.FillTransparency = 0.45
CenterHL.OutlineColor = Color3.fromRGB(59, 218, 10)
CenterHL.OutlineTransparency = 0
CenterHL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
CenterHL.Adornee = CenterPart
CenterHL.Parent = CenterPart

local PlayerHL = Instance.new("Highlight")
PlayerHL.FillColor = Color3.fromRGB(80, 200, 255)
PlayerHL.FillTransparency = 0.35
PlayerHL.OutlineColor = Color3.fromRGB(80, 200, 255)
PlayerHL.OutlineTransparency = 0
PlayerHL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
PlayerHL.Adornee = nil
PlayerHL.Parent = nil

-- ── State ─────────────────────────────────────────────────────────────────────
local orbitMode = "island"
local customCenter = Vector3.new(0, 0, 0)
local clickMode = nil -- nil | "place"
local selectedPlayer = nil
local charAddedConn = nil -- tracks respawn for highlight
local spectateConn = nil
local flinging = false
local loopFlinging = false
local spectating = false
-- Fly state
local flyEnabled = false
local flyKey = Enum.KeyCode.F
local flySpeed = 50
local rebindingFly = false
local flyBV, flyBG, flyConn

-- ── Helpers ───────────────────────────────────────────────────────────────────
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

local function setModeLabel(txt)
	ModeLabel.Text = "Mode:  " .. txt
end

local function cancelClickMode()
	clickMode = nil
	PlaceBtn.BackgroundColor3 = P.row
	PlaceBtn.Text = "🖱  Click to Place Center"
end

-- ── Player selection helpers ──────────────────────────────────────────────────
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
	DropdownBtn.Text = "▾  Select Player"
	-- Stop dependent modes
	if spectating then
		spectating = false
		SpectateBtn.Text = "👁  Spectate"
		SpectateBtn.BackgroundColor3 = P.row
		pcall(function()
			local myHum = LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid")
			if myHum then
				Workspace.CurrentCamera.CameraSubject = myHum
			end
		end)
	end
	loopFlinging = false
	LoopFlingBtn.Text = "🔁  Loop Fling  |  Off"
	LoopFlingBtn.BackgroundColor3 = P.red
end

local function applyHighlight(char)
	if char then
		PlayerHL.Parent = char
	end
end

local function selectPlayer(p)
	-- Detach from previous
	if charAddedConn then
		charAddedConn:Disconnect()
		charAddedConn = nil
	end
	if spectateConn then
		spectateConn:Disconnect()
		spectateConn = nil
	end
	selectedPlayer = p
	DropdownBtn.Text = "▾  " .. p.Name
	PlayerLabel.Text = "Target:  " .. p.Name
	PlayerLabel.TextColor3 = Color3.fromRGB(255, 160, 160)
	-- Highlight current character
	applyHighlight(p.Character)
	-- Re-apply on respawn
	charAddedConn = p.CharacterAdded:Connect(function(char)
		task.wait(0.1)
		applyHighlight(char)
		-- Re-attach spectate camera on respawn
		if spectating then
			task.wait(0.2)
			local hum = char:FindFirstChildWhichIsA("Humanoid")
			if hum and spectating then
				Workspace.CurrentCamera.CameraSubject = hum
			end
		end
	end)
end

-- Remove selection if player leaves
Players.PlayerRemoving:Connect(function(p)
	if selectedPlayer == p then
		clearSelectedPlayer()
	end
end)

-- ── Dropdown logic ────────────────────────────────────────────────────────────
local dropdownOpen = false
local DD_ITEM_H = 24

local function closeDropdown()
	dropdownOpen = false
	DropdownList.Visible = false
end

local function populateAndOpenDropdown()
	-- Rebuild list
	for _, c in pairs(DropdownList:GetChildren()) do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end

	local entries = {}
	table.insert(entries, { label = "  ✕  No one", player = nil })
	for _, p in pairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			table.insert(entries, { label = "  " .. p.Name, player = p })
		end
	end

	for i, entry in ipairs(entries) do
		local row = Instance.new("TextButton", DropdownList)
		row.Size = UDim2.new(1, 0, 0, DD_ITEM_H)
		row.Position = UDim2.new(0, 0, 0, (i - 1) * DD_ITEM_H)
		row.BackgroundColor3 = (selectedPlayer == entry.player) and P.sel or P.row
		row.BorderSizePixel = 0
		row.Font = Enum.Font.Gotham
		row.TextSize = 12
		row.TextColor3 = P.text
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = entry.label
		row.AutoButtonColor = false
		row.ZIndex = 21
		mkCorner(row, 4)
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

	local totalH = #entries * DD_ITEM_H
	DropdownList.CanvasSize = UDim2.new(0, 0, 0, totalH)
	-- Shrink list height if fewer entries than max
	local clampH = math.min(totalH, DD_MAX_H)
	DropdownList.Size = UDim2.new(1, -16, 0, clampH)
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

-- ── Orbit center controls ─────────────────────────────────────────────────────
PlaceBtn.MouseButton1Click:Connect(function()
	if clickMode == "place" then
		cancelClickMode()
	else
		cancelClickMode()
		clickMode = "place"
		PlaceBtn.BackgroundColor3 = P.active
		PlaceBtn.Text = "🖱  Click world to place..."
	end
end)

IslandBtn.MouseButton1Click:Connect(function()
	orbitMode = "island"
	CenterPart.Transparency = 1
	setModeLabel("Island  (workspace.Island)")
	cancelClickMode()
end)

-- ── Fling buttons ─────────────────────────────────────────────────────────────
FlingBtn.MouseButton1Click:Connect(function()
	if flinging then
		return
	end
	if not selectedPlayer or not selectedPlayer.Character then
		PlayerLabel.Text = "⚠  No player selected!"
		PlayerLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
		return
	end
	flinging = true
	FlingBtn.Text = "💥  Flinging..."
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
			for _, data in ipairs(orbitParts) do
				if data.anchor and data.anchor.Parent then
					data.anchor.CFrame = CFrame.new(hrp.Position)
				end
			end
		end
		flinging = false
		FlingBtn.Text = "💥  Fling!"
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
		LoopFlingBtn.Text = "🔁  Loop Fling  |  On"
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
				for _, data in ipairs(orbitParts) do
					if data.anchor and data.anchor.Parent then
						data.anchor.CFrame = CFrame.new(hrp.Position)
					end
				end
			end
			loopFlinging = false
			LoopFlingBtn.Text = "🔁  Loop Fling  |  Off"
			LoopFlingBtn.BackgroundColor3 = P.red
		end)
	else
		loopFlinging = false
		LoopFlingBtn.Text = "🔁  Loop Fling  |  Off"
		LoopFlingBtn.BackgroundColor3 = P.red
	end
end)

-- ── Spectate ──────────────────────────────────────────────────────────────────
SpectateBtn.MouseButton1Click:Connect(function()
	if not spectating then
		if not selectedPlayer then
			PlayerLabel.Text = "⚠  No player selected!"
			PlayerLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
			return
		end
		spectating = true
		SpectateBtn.Text = "👁  Unspectate"
		SpectateBtn.BackgroundColor3 = P.active
		local char = selectedPlayer.Character
		if char then
			local hum = char:FindFirstChildWhichIsA("Humanoid")
			if hum then
				Workspace.CurrentCamera.CameraSubject = hum
			end
		end
	else
		spectating = false
		SpectateBtn.Text = "👁  Spectate"
		SpectateBtn.BackgroundColor3 = P.row
		pcall(function()
			local myHum = LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid")
			if myHum then
				Workspace.CurrentCamera.CameraSubject = myHum
			end
		end)
	end
end)

-- ── Fly system ────────────────────────────────────────────────────────────────
local function stopFly()
	flyEnabled = false
	if flyBV and flyBV.Parent then
		flyBV:Destroy()
	end
	if flyBG and flyBG.Parent then
		flyBG:Destroy()
	end
	if flyConn then
		flyConn:Disconnect()
		flyConn = nil
	end
	flyBV, flyBG = nil, nil
	pcall(function()
		local hum = LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid")
		if hum then
			hum.PlatformStand = false
		end
	end)
end

local function startFly()
	local char = LocalPlayer.Character
	if not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local hum = char:FindFirstChildWhichIsA("Humanoid")
	if hum then
		hum.PlatformStand = true
	end

	flyBV = Instance.new("BodyVelocity")
	flyBV.Velocity = Vector3.new(0, 0, 0)
	flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	flyBV.P = 1e4
	flyBV.Parent = hrp

	flyBG = Instance.new("BodyGyro")
	flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	flyBG.P = 1e6
	flyBG.D = 100
	flyBG.CFrame = hrp.CFrame
	flyBG.Parent = hrp

	flyEnabled = true

	flyConn = RunService.RenderStepped:Connect(function()
		if not flyEnabled then
			return
		end
		local cam = Workspace.CurrentCamera
		local dir = Vector3.new(0, 0, 0)
		local spd = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and flySpeed * 2 or flySpeed
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			dir = dir + cam.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			dir = dir - cam.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			dir = dir - cam.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			dir = dir + cam.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			dir = dir + Vector3.new(0, 1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			dir = dir - Vector3.new(0, 1, 0)
		end
		if dir.Magnitude > 0 then
			dir = dir.Unit
		end
		flyBV.Velocity = dir * spd
		flyBG.CFrame = cam.CFrame
	end)
end

local FlyBtn -- forward-declared; created in Settings section below
local KeybindBtn

-- ── Input handler (mouse clicks + fly keybind + GUI hide) ────────────────────
UserInputService.InputBegan:Connect(function(input, gpe)
	-- GUI visibility toggle (never eaten by game)
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
			flyKey = input.KeyCode
			rebindingFly = false
			KeybindBtn.Text = "⌨  Key: " .. tostring(flyKey.Name)
			KeybindBtn.BackgroundColor3 = P.row
		end
		return
	end

	-- Fly keybind toggle
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == flyKey then
		if flyEnabled then
			stopFly()
			if FlyBtn then
				FlyBtn.Text = "✈  Fly  |  Off"
				FlyBtn.BackgroundColor3 = P.row
			end
		else
			startFly()
			if FlyBtn then
				FlyBtn.Text = "✈  Fly  |  On"
				FlyBtn.BackgroundColor3 = P.green
			end
		end
		return
	end

	-- Escape: cancel click modes / close dropdown
	if input.KeyCode == Enum.KeyCode.Escape then
		cancelClickMode()
		closeDropdown()
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	-- World raycasting for place mode
	if clickMode == "place" then
		local camera = Workspace.CurrentCamera
		local mPos = UserInputService:GetMouseLocation()
		local unitRay = camera:ViewportPointToRay(mPos.X, mPos.Y)
		local exclude = { CenterPart, Folder }
		if LocalPlayer.Character then
			table.insert(exclude, LocalPlayer.Character)
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclude
		local hit = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, params)
		if hit then
			customCenter = hit.Position
			orbitMode = "custom"
			CenterPart.CFrame = CFrame.new(customCenter)
			CenterPart.Transparency = 0
			setModeLabel("Custom Point")
		end
		cancelClickMode()
	end
end)

-- ── Network / physics harness ─────────────────────────────────────────────────
local Folder = Instance.new("Folder", Workspace)

if not getgenv().Network then
	getgenv().Network = {
		BaseParts = {},
		Velocity = Vector3.new(14.46262424, 14.46262424, 14.46262424),
	}
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

-- ── Shape math ────────────────────────────────────────────────────────────────
local function polygonPoint(a, R, n)
	local s = (2 * math.pi) / n
	local t = (a % s) - s / 2
	if math.abs(math.cos(t)) < 1e-6 then
		t = t + 1e-6
	end
	return math.cos(a) * (R * math.cos(s / 2) / math.cos(t)), math.sin(a) * (R * math.cos(s / 2) / math.cos(t))
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

local SHAPES = {
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
		name = "Star (5pt)",
		icon = "★",
		fn = function(a, R, i, n, t)
			local x, z = starPoint(a, R, R * 0.42, 5)
			return x, z, 0
		end,
	},
	{
		name = "Star (6pt)",
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
local currentShapeIndex = 1
local shapeButtons = {}

local function buildShapeList()
	for idx, shape in ipairs(SHAPES) do
		local btn = Instance.new("TextButton", ShapesContent)
		btn.LayoutOrder = idx
		btn.Size = UDim2.new(1, 0, 0, ITEM_H)
		btn.BackgroundColor3 = idx == 1 and P.sel or P.row
		btn.BorderSizePixel = 0
		btn.Font = Enum.Font.Gotham
		btn.TextSize = 13
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

-- ── Settings sliders ──────────────────────────────────────────────────────────
local activeDrag = nil

local function applyFrac(frac, def, fill, thumb, valLbl)
	frac = math.clamp(frac, 0, 1)
	local v =
		math.clamp(math.floor((def.min + frac * (def.max - def.min)) / def.step + 0.5) * def.step, def.min, def.max)
	Config[def.key] = v
	valLbl.Text = string.format(def.fmt, v)
	fill.Size = UDim2.new(frac, 0, 1, 0)
	thumb.Position = UDim2.new(frac, -6, 0.5, -6)
end

local function buildSettingsSliders()
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

		local fill = Instance.new("Frame", track)
		fill.BackgroundColor3 = P.fill
		fill.BorderSizePixel = 0
		local frac0 = (Config[def.key] - def.min) / (def.max - def.min)
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

	-- ── Fly section (appended to Settings tab after sliders) ──────────────────
	local flySepRow = Instance.new("Frame", SettingsContent)
	flySepRow.LayoutOrder = 100
	flySepRow.Size = UDim2.new(1, 0, 0, 14)
	flySepRow.BackgroundTransparency = 1
	flySepRow.BorderSizePixel = 0
	local flySep = Instance.new("Frame", flySepRow)
	flySep.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
	flySep.BorderSizePixel = 0
	flySep.Position = UDim2.new(0, 0, 0.5, 0)
	flySep.Size = UDim2.new(1, 0, 0, 1)
	local flyHdrLbl = Instance.new("TextLabel", flySepRow)
	flyHdrLbl.BackgroundTransparency = 1
	flyHdrLbl.Position = UDim2.new(0, 0, 0, 0)
	flyHdrLbl.Size = UDim2.new(1, 0, 1, 0)
	flyHdrLbl.Font = Enum.Font.GothamBold
	flyHdrLbl.TextSize = 11
	flyHdrLbl.TextColor3 = P.thumb
	flyHdrLbl.Text = "✈  Fly"
	flyHdrLbl.TextXAlignment = Enum.TextXAlignment.Left

	-- Fly toggle button
	local flyRow = Instance.new("Frame", SettingsContent)
	flyRow.LayoutOrder = 101
	flyRow.Size = UDim2.new(1, 0, 0, SET_ROW_H - 4)
	flyRow.BackgroundColor3 = P.row
	flyRow.BorderSizePixel = 0
	mkCorner(flyRow, 5)
	FlyBtn = Instance.new("TextButton", flyRow)
	FlyBtn.BackgroundTransparency = 1
	FlyBtn.Size = UDim2.new(1, 0, 1, 0)
	FlyBtn.Font = Enum.Font.GothamSemibold
	FlyBtn.TextSize = 12
	FlyBtn.TextColor3 = P.text
	FlyBtn.Text = "✈  Fly  |  Off"
	FlyBtn.AutoButtonColor = false
	FlyBtn.MouseButton1Click:Connect(function()
		if flyEnabled then
			stopFly()
			FlyBtn.Text = "✈  Fly  |  Off"
			FlyBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			FlyBtn.BackgroundTransparency = 1
		else
			startFly()
			FlyBtn.Text = "✈  Fly  |  On"
			FlyBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			FlyBtn.BackgroundTransparency = 1
		end
	end)

	-- Keybind row
	local kbRow = Instance.new("Frame", SettingsContent)
	kbRow.LayoutOrder = 102
	kbRow.Size = UDim2.new(1, 0, 0, SET_ROW_H)
	kbRow.BackgroundColor3 = P.row
	kbRow.BorderSizePixel = 0
	mkCorner(kbRow, 5)
	local kbPad = Instance.new("UIPadding", kbRow)
	kbPad.PaddingLeft = UDim.new(0, 8)
	kbPad.PaddingRight = UDim.new(0, 8)
	kbPad.PaddingTop = UDim.new(0, 4)

	local kbLabel = Instance.new("TextLabel", kbRow)
	kbLabel.BackgroundTransparency = 1
	kbLabel.Position = UDim2.new(0, 0, 0, 0)
	kbLabel.Size = UDim2.new(0.45, 0, 0, 14)
	kbLabel.Font = Enum.Font.GothamSemibold
	kbLabel.TextSize = 11
	kbLabel.TextColor3 = P.sub
	kbLabel.Text = "Fly Keybind"
	kbLabel.TextXAlignment = Enum.TextXAlignment.Left

	KeybindBtn = Instance.new("TextButton", kbRow)
	KeybindBtn.BackgroundColor3 = P.panel
	KeybindBtn.BorderSizePixel = 0
	KeybindBtn.Position = UDim2.new(0.45, 0, 0, 0)
	KeybindBtn.Size = UDim2.new(0.55, 0, 0, 22)
	KeybindBtn.Font = Enum.Font.GothamBold
	KeybindBtn.TextSize = 11
	KeybindBtn.TextColor3 = P.thumb
	KeybindBtn.Text = "⌨  Key: F"
	KeybindBtn.AutoButtonColor = false
	mkCorner(KeybindBtn, 4)
	KeybindBtn.MouseButton1Click:Connect(function()
		if rebindingFly then
			-- Cancel rebind
			rebindingFly = false
			KeybindBtn.Text = "⌨  Key: " .. tostring(flyKey.Name)
			KeybindBtn.BackgroundColor3 = P.panel
		else
			rebindingFly = true
			KeybindBtn.Text = "⌨  Press any key..."
			KeybindBtn.BackgroundColor3 = P.active
		end
	end)

	-- Fly speed label hint
	local spd = Instance.new("TextLabel", kbRow)
	spd.BackgroundTransparency = 1
	spd.Position = UDim2.new(0, 0, 0, 18)
	spd.Size = UDim2.new(1, 0, 0, 12)
	spd.Font = Enum.Font.Gotham
	spd.TextSize = 10
	spd.TextColor3 = P.sub
	spd.Text = "WASD + Space/LCtrl to move  •  Shift = fast"
	spd.TextXAlignment = Enum.TextXAlignment.Left
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

-- ── Orbit engine ──────────────────────────────────────────────────────────────
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
		Tq.Torque = Vector3.new(100000, 100000, 100000)
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

local function toggleOrbit()
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
		LoopFlingBtn.Text = "🔁  Loop Fling  |  Off"
		LoopFlingBtn.BackgroundColor3 = P.red
		if DescendantAddedConnection then
			DescendantAddedConnection:Disconnect()
			DescendantAddedConnection = nil
		end
		cleanupOrbitParts()
	end
end

buildShapeList()
buildSettingsSliders()

local function wireOrbit()
	local s = Instance.new("Script", OrbitBtn)
	s.Parent.MouseButton1Click:Connect(toggleOrbit)
end
coroutine.wrap(wireOrbit)()
