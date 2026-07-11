-- ============================================================================
-- ORBIT ISLAND  |  WindUI Edition
-- Tabs: Shapes • Settings • Protect • Target • Config
-- ============================================================================

-- ── Services ─────────────────────────────────────────────────────────────────
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
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
	ORBIT_TILT_X = 0,
	ORBIT_TILT_Z = 0,
	RING_COUNT = 1,
	TILT_FACTOR = 0,
}

-- ── Multi-ring state ─────────────────────────────────────────────────────────
local MAX_RINGS = 8

local SETTING_DEFS = {
	{ label = "Radius", key = "ORBIT_RADIUS", min = 2, max = 300, step = 1, fmt = "%.0f" },
	{ label = "Height", key = "ORBIT_HEIGHT", min = -20, max = 300, step = 1, fmt = "%.0f" },
	{ label = "Speed", key = "ORBIT_SPEED", min = 0.1, max = 5.0, step = 0.1, fmt = "%.1f" },
	{ label = "Wave Amp", key = "Y_WAVE_AMP", min = 0, max = 15, step = 0.5, fmt = "%.1f" },
	{ label = "Wave Spd", key = "Y_WAVE_SPEED", min = 0.1, max = 5.0, step = 0.1, fmt = "%.1f" },
	{ label = "Helix H", key = "HELIX_SPAN", min = 2, max = 80, step = 2, fmt = "%.0f" },
	{ label = "Tilt X", key = "ORBIT_TILT_X", min = -90, max = 90, step = 1, fmt = "%.0f" },
	{ label = "Tilt Z", key = "ORBIT_TILT_Z", min = -90, max = 90, step = 1, fmt = "%.0f" },
}

-- ── Load WindUI ──────────────────────────────────────────────────────────────
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

-- ── State ────────────────────────────────────────────────────────────────────
local orbitMode = "island"
local customCenter = Vector3.new(0, 0, 0)
local clickMode = nil
local selectedPlayer = nil
local charAddedConn = nil
local spectateConn = nil
local flinging = false
local loopFlinging = false
local spectating = false

-- Protection state
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
local toggleOrbit -- forward declaration
local playerDropdown
local themeDrop
local flyKeybind = Enum.KeyCode.F
local orbitKeybind = Enum.KeyCode.V
local UIToggle = Enum.KeyCode.RightControl
local flying = false
local flySpeed = 50
local flySpeedMult = 3
local flyCharacter, flyHumanoid, flyRoot
local flyAttachment, flyLV, flyAO

-- PlayerModule (fly controls)
local PlayerModule = require(LocalPlayer.PlayerScripts:WaitForChild("PlayerModule"))
local Controls = PlayerModule:GetControls()

-- ============================================================================
-- PROTECTION SYSTEMS
-- ============================================================================

-- ── Godmode ──────────────────────────────────────────────────────────────────
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
local godEnabled = false
local setGodmode
setGodmode = function(on)
	godEnabled = on
	if on then
		if godLoopConn then
			pcall(function() godLoopConn:Disconnect() end)
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
			pcall(function() godRespawnConn:Disconnect() end)
		end
		godRespawnConn = LocalPlayer.CharacterAdded:Connect(function(char)
			if godEnabled then
				applyGodProps(char)
			end
		end)
	else
		if godLoopConn then
			pcall(function() godLoopConn:Disconnect() end)
			godLoopConn = nil
		end
		if godRespawnConn then
			pcall(function() godRespawnConn:Disconnect() end)
			godRespawnConn = nil
		end
		if LocalPlayer.Character then
			restoreGodProps(LocalPlayer.Character)
		end
	end
end

-- ── Anti-Fall ────────────────────────────────────────────────────────────────
local antiFallEnabled = false
local function hookAntiFall(char)
	task.spawn(function()
		local r = char:WaitForChild("HumanoidRootPart", 10)
		if not r or not antiFallEnabled then
			return
		end
		if antiFallLoopConn then
			pcall(function() antiFallLoopConn:Disconnect() end)
		end
		local z = Vector3.zero
		antiFallLoopConn = RunService.Heartbeat:Connect(function()
			if not antiFallEnabled or not r.Parent then
				pcall(function() antiFallLoopConn:Disconnect() end)
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
local setAntiFall
setAntiFall = function(on)
	antiFallEnabled = on
	if on then
		if LocalPlayer.Character then
			hookAntiFall(LocalPlayer.Character)
		end
		if antiFallRespawnConn then
			pcall(function() antiFallRespawnConn:Disconnect() end)
		end
		antiFallRespawnConn = LocalPlayer.CharacterAdded:Connect(function(char)
			if antiFallEnabled then
				hookAntiFall(char)
			end
		end)
	else
		if antiFallLoopConn then
			pcall(function() antiFallLoopConn:Disconnect() end)
			antiFallLoopConn = nil
		end
		if antiFallRespawnConn then
			pcall(function() antiFallRespawnConn:Disconnect() end)
			antiFallRespawnConn = nil
		end
	end
end

-- ── Anti-Fling ───────────────────────────────────────────────────────────────
local antiFlingEnabled = false
local setAntiFling
setAntiFling = function(on)
	antiFlingEnabled = on
	if on then
		local char = LocalPlayer.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			lastSafeCFrame = char.HumanoidRootPart.CFrame
		end
		if antiFlingLoopConn then
			pcall(function() antiFlingLoopConn:Disconnect() end)
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
			pcall(function() antiFlingLoopConn:Disconnect() end)
			antiFlingLoopConn = nil
		end
		lastSafeCFrame = nil
		isRecovering = false
	end
end

-- ── Noclip ───────────────────────────────────────────────────────────────────
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
		pcall(function() noclipLoopConn:Disconnect() end)
	end
	if noclipAddedConn then
		pcall(function() noclipAddedConn:Disconnect() end)
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
			pcall(function() noclipLoopConn:Disconnect() end)
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
	if on then
		if LocalPlayer.Character then
			hookNoclip(LocalPlayer.Character)
		end
		if noclipRespawnConn then
			pcall(function() noclipRespawnConn:Disconnect() end)
		end
		noclipRespawnConn = LocalPlayer.CharacterAdded:Connect(function(char)
			if noclipEnabled then
				hookNoclip(char)
			end
		end)
	else
		if noclipLoopConn then
			pcall(function() noclipLoopConn:Disconnect() end)
			noclipLoopConn = nil
		end
		if noclipRespawnConn then
			pcall(function() noclipRespawnConn:Disconnect() end)
			noclipRespawnConn = nil
		end
		if noclipAddedConn then
			pcall(function() noclipAddedConn:Disconnect() end)
			noclipAddedConn = nil
		end
		if LocalPlayer.Character then
			restoreNoclip(LocalPlayer.Character)
		end
	end
end

-- ============================================================================
-- FLY ENGINE
-- ============================================================================
local function stopFly()
	flying = false
	local lv, ao, att, root, hum, char = flyLV, flyAO, flyAttachment, flyRoot, flyHumanoid, flyCharacter
	flyLV, flyAO, flyAttachment, flyRoot = nil, nil, nil, nil
	task.spawn(function()
		if lv and lv.Parent then
			lv.VectorVelocity = Vector3.zero
		end
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
			pcall(function() hum.PlatformStand = false end)
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
PlayerHL.FillColor = Color3.fromRGB(0, 130, 255)
PlayerHL.FillTransparency = 0.35
PlayerHL.OutlineColor = Color3.fromRGB(0, 130, 255)
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
	if spectating then
		spectating = false
		pcall(function()
			local h = LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid")
			if h then
				Workspace.CurrentCamera.CameraSubject = h
			end
		end)
	end
	loopFlinging = false
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

-- ============================================================================
-- INPUT HANDLER
-- ============================================================================
local Folder -- forward-declared, used in raycast excludes
local function cancelClickMode()
	clickMode = nil
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then
		return
	end
	-- Fly keybind
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == flyKeybind then
		toggleFly()
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
		return
	end
	-- Raycast for click modes
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
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
				WindUI:Notify({ Title = "Ring Center", Content = "Custom point set", Duration = 3 })
			end
			cancelClickMode()
		elseif clickMode == "player" then
			if hit and hit.Instance then
				for _, p in pairs(Players:GetPlayers()) do
					if p ~= LocalPlayer and p.Character and hit.Instance:IsDescendantOf(p.Character) then
						selectPlayer(p)
						local dn = p.DisplayName ~= "" and p.DisplayName or p.Name
						if playerDropdown then
							pcall(function() playerDropdown:Select(dn) end)
						end
						WindUI:Notify({ Title = "Player Selected", Content = dn, Duration = 3 })
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

local SHAPES = {
	{ name = "Circle", fn = function(a, R, i, n, t) return math.cos(a) * R, math.sin(a) * R, 0 end },
	{ name = "Square", fn = function(a, R, i, n, t) local x, z = polygonPoint(a, R, 4) return x, z, 0 end },
	{ name = "Triangle", fn = function(a, R, i, n, t) local x, z = polygonPoint(a, R, 3) return x, z, 0 end },
	{ name = "Diamond", fn = function(a, R, i, n, t) local x, z = polygonPoint(a + math.pi / 4, R, 4) return x, z, 0 end },
	{ name = "Pentagon", fn = function(a, R, i, n, t) local x, z = polygonPoint(a, R, 5) return x, z, 0 end },
	{ name = "Hexagon", fn = function(a, R, i, n, t) local x, z = polygonPoint(a, R, 6) return x, z, 0 end },
	{ name = "Star(5pt)", fn = function(a, R, i, n, t) local x, z = starPoint(a, R, R * 0.42, 5) return x, z, 0 end },
	{ name = "Star(6pt)", fn = function(a, R, i, n, t) local x, z = starPoint(a, R, R * 0.50, 6) return x, z, 0 end },
	{ name = "Figure-8", fn = function(a, R, i, n, t) return math.cos(a) * R, math.sin(2 * a) * (R * 0.5), 0 end },
	{ name = "Flower", fn = function(a, R, i, n, t) local x, z = rosePoint(a, R, 4) return x, z, 0 end },
	{ name = "Spiral", fn = function(a, R, i, n, t) local x, z = spiralPoint(a, R, t) return x, z, 0 end },
	{ name = "Helix", fn = function(a, R, i, n, t)
		local frac = (i - 1) / math.max(n - 1, 1)
		return math.cos(a) * R, math.sin(a) * R, (frac * 2 - 1) * (Config.HELIX_SPAN / 2)
	end },
}
local currentShapeIndex = 1

-- ============================================================================
-- ORBIT ENGINE
-- ============================================================================
local orbitParts = {}
local blackHoleActive = false
local DescendantAddedConnection

local function ForcePart(v)
	if
		v:IsA("BasePart")
		and not v.Anchored
		and not v:IsDescendantOf(IslandModel)
		and not v:IsDescendantOf(LocalPlayer.Character)
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
	elseif orbitMode == "self" then
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			customCenter = hrp.Position
			return hrp.Position
		end
		return customCenter
	elseif orbitMode == "player" then
		local char = selectedPlayer and selectedPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			customCenter = hrp.Position
			return hrp.Position
		end
		return customCenter
	else
		return customCenter
	end
end

local orbitToggleRef -- will hold the WindUI toggle element

toggleOrbit = function()
	blackHoleActive = not blackHoleActive
	if blackHoleActive then
		cleanupOrbitParts()
		for _, v in ipairs(workspace:GetDescendants()) do
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
				local ringCount = math.clamp(math.floor(Config.RING_COUNT), 1, MAX_RINGS)
				local perRing = math.max(1, math.ceil(count / ringCount))

				-- precompute each ring's tilt trig once per frame
				-- rings fan out evenly across 180°, scaled by TILT_FACTOR
				local rCosX, rSinX, rCosZ, rSinZ = {}, {}, {}, {}
				for r = 1, ringCount do
					local spread = (ringCount > 1) and ((r - 1) / ringCount) * 180 or 0
					local rx = math.rad(Config.ORBIT_TILT_X + spread * Config.TILT_FACTOR)
					local rz = math.rad(Config.ORBIT_TILT_Z)
					rCosX[r], rSinX[r] = math.cos(rx), math.sin(rx)
					rCosZ[r], rSinZ[r] = math.cos(rz), math.sin(rz)
				end

				for i, data in ipairs(orbitParts) do
					if data.anchor and data.anchor.Parent then
						local ringIndex = math.min(math.floor((i - 1) / perRing) + 1, ringCount)
						local inRing = (i - 1) % perRing
						local off = (inRing / perRing) * (2 * math.pi)
						local angle = t + off
						local x, z, yExtra = shape.fn(angle, Config.ORBIT_RADIUS, i, count, t)
						local y = (shape.name == "Helix") and yExtra
							or math.sin(t * Config.Y_WAVE_SPEED + off) * Config.Y_WAVE_AMP + yExtra
						local cosX, sinX = rCosX[ringIndex], rSinX[ringIndex]
						local cosZ, sinZ = rCosZ[ringIndex], rSinZ[ringIndex]
						local y1 = y * cosX - z * sinX
						local z1 = y * sinX + z * cosX
						local x2 = x * cosZ - y1 * sinZ
						local y2 = x * sinZ + y1 * cosZ
						data.anchor.CFrame = CFrame.new(origin + Vector3.new(x2, y2, z1))
					end
				end
			end
		end)
		if orbitToggleRef then
			orbitToggleRef:Set(true)
		end
		WindUI:Notify({ Title = "Super Ring", Content = "Super Ring activated", Icon = "check", Duration = 3 })
	else
		loopFlinging = false
		if DescendantAddedConnection then
			DescendantAddedConnection:Disconnect()
			DescendantAddedConnection = nil
		end
		cleanupOrbitParts()
		if orbitToggleRef then
			orbitToggleRef:Set(false)
		end
		WindUI:Notify({ Title = "Super Ring", Content = "Super Ring deactivated", Icon = "x", Duration = 3 })
	end
end

-- ============================================================================
-- WINDUI WINDOW
-- ============================================================================

local Window = WindUI:CreateWindow({
	Title = "SUPER RINGS REIMAGINED",
	Folder = "OrbitIsland",
	Icon = "solar:star-ring-bold-duotone",
	Theme = "Plant",
	HideSearchBar = true,
	OpenButton = {
		Title = "Open SUPER RINGS REIMAGINED",
		Enabled = true,
		Draggable = true,
	},
--[[
	KeySystem = {
		Title = "Access Required",
		Note = "Get your key at discord.gg/zr3N3bJnym",

		KeyValidator = function(key)
			local validKeys = {"holy poop fart"}
			return table.find(validKeys, key) ~= nil
		end,

		SaveKey = false,
		URL = "https://discord.gg/zr3N3bJnym", -- link to get keys
	},]]
})

Window:SetToggleKey(UIToggle)

-- ── Colors ───────────────────────────────────────────────────────────────────
local Blue = Color3.fromHex("#257AF7")
local Green = Color3.fromHex("#10C550")
local Red = Color3.fromHex("#EF4F1D")
local Purple = Color3.fromHex("#7775F2")
local Yellow = Color3.fromHex("#ECA201")
local Grey = Color3.fromHex("#83889E")


-- ============================================================================
-- TAB 2: SETTINGS
-- ============================================================================


local MainSection = Window:Section({
	Title = "Main Center",
})

local RingsSettings = MainSection:Tab({
	Title = "Rings Settings",
	Icon = "solar:star-ring-bold-duotone",
	Border = true,
})

local shapeNames = {}
for _, s in ipairs(SHAPES) do
	table.insert(shapeNames, s.name)
end

RingsSettings:Section({ Title = "Ring Shape" })

local ringDrop
ringDrop = RingsSettings:Dropdown({
	Title = "Select Shape",
	Flag = "Shape",
	Values = shapeNames,
	Value = 1,
	Callback = function(value)
		for i, s in ipairs(SHAPES) do
			if s.name == value then
				currentShapeIndex = i
				break
			end
		end
		if ringDrop then
			pcall(function() ringDrop:Close() end)
		end
		WindUI:Notify({ Title = "Shape", Content = "Selected: " .. value, Duration = 3 })
	end,
})

RingsSettings:Space()
RingsSettings:Divider()

RingsSettings:Section({ Title = "Rings" })

for _, def in ipairs(SETTING_DEFS) do
	RingsSettings:Slider({
		Title = def.label,
		Flag = def.key,
		Step = def.step,
		Value = {
			Min = def.min,
			Max = def.max,
			Default = Config[def.key],
		},
		Callback = function(value)
			Config[def.key] = value
		end,
	})
end

RingsSettings:Space()
RingsSettings:Divider()
RingsSettings:Section({ Title = "Multi-Ring" })

RingsSettings:Slider({
	Title = "Ring Count",
	Flag = "RingCount",
	Step = 1,
	Value = { Min = 1, Max = MAX_RINGS, Default = Config.RING_COUNT },
	Callback = function(value)
		Config.RING_COUNT = value
	end,
})

RingsSettings:Space()

RingsSettings:Slider({
	Title = "Tilt Factor",
	Flag = "TiltFactor",
	Step = 0.05,
	Value = { Min = 0, Max = 2, Default = Config.TILT_FACTOR },
	Callback = function(value)
		Config.TILT_FACTOR = value
	end,
})

RingsSettings:Space()



-- ============================================================================
-- TAB 3: PROTECT
-- ============================================================================

local SettingSection = Window:Section({
	Title = "Settings",
})

local ProtectTab = SettingSection:Tab({
	Title = "Protection",
	Icon = "solar:shield-check-bold-duotone",
	Border = true,
})

ProtectTab:Toggle({
	Title = "Godmode",
	Flag = "Godmode",
	Desc = "Infinite health + state protection",
	Value = false,
	Callback = function(state)
		setGodmode(state)
	end,
})

ProtectTab:Space()

ProtectTab:Toggle({
	Title = "Anti-Fall",
	Flag = "AntiFall",
	Desc = "Prevents fall damage",
	Value = false,
	Callback = function(state)
		setAntiFall(state)
	end,
})

ProtectTab:Space()

ProtectTab:Toggle({
	Title = "Anti-Fling",
	Flag = "AntiFling",
	Desc = "Detects and reverses fling attempts",
	Value = false,
	Callback = function(state)
		setAntiFling(state)
	end,
})

local KeybindSection = SettingSection:Tab({
	Title = "Keybinds",
	Icon = "solar:keyboard-bold-duotone",
	Border = true,
})


KeybindSection:Section({ Title = "Fly" })

KeybindSection:Toggle({
	Title = "Fly System",
	Flag = "FlySystem",
	Desc = "Enable/disable the fly engine",
	Value = flySystemEnabled,
	Callback = function(state)
		flySystemEnabled = state
		if not flySystemEnabled and flying then
			stopFly()
		end
	end,
})

KeybindSection:Button({
	Title = "Toggle Fly",
	Desc = "Turn fly on/off",
	Icon = "bird",
	Callback = function()
		toggleFly()
	end,
})

KeybindSection:Space()
KeybindSection:Divider()
KeybindSection:Space()

KeybindSection:Keybind({
	Title = "Fly Keybind",
	Flag = "FlyKeybind",
	Value = tostring(flyKeybind.Name),
	Callback = function(key)
		flyKeybind = Enum.KeyCode[key]
	end,
})

KeybindSection:Keybind({
	Title = "Ring Keybind",
	Flag = "OrbitKeybind",
	Value = tostring(orbitKeybind.Name),
	Callback = function(key)
		orbitKeybind = Enum.KeyCode[key]
	end,
})

KeybindSection:Keybind({
	Title = "Toggle UI",
	Flag = "UIToggle",
	Value = tostring(UIToggle.Name),
	Callback = function(key)
		UIToggle = Enum.KeyCode[key]
		Window:SetToggleKey(UIToggle)
	end,
})

-- ============================================================================
-- TAB 4: TARGET
-- ============================================================================
local TargetTab = MainSection:Tab({
	Title = "Ring Target",
	Icon = "solar:target-line-duotone",
	Border = true,
})

-- ── Orbit Center ─────────────────────────────────────────────────────────────
TargetTab:Section({ Title = "Ring Center" })

TargetTab:Space()

orbitToggleRef = TargetTab:Toggle({
	Title = "Super Ring",
	Flag = "Orbit",
	Desc = "Toggle the ring on/off",
	Value = false,
	Callback = function(state)
		if state ~= blackHoleActive then
			toggleOrbit()
		end
	end,
})

TargetTab:Space()

local targetDrop
targetDrop = TargetTab:Dropdown({
	Title = "Ring Center",
	Desc = "Select what the ring revolves around. Island only works on Natural Disaster Survival.",
	Values = { "Self", "Player", "Click to Place", "Island" },
	Value = "Self",
	Callback = function(value)
		if value == "Island" then
			orbitMode = "island"
			CenterPart.Transparency = 1
			WindUI:Notify({ Title = "Ring Mode", Content = "Island", Duration = 3 })
		elseif value == "Self" then
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				customCenter = hrp.Position
			end
			orbitMode = "self"
			CenterPart.Transparency = 1
			WindUI:Notify({ Title = "Ring Mode", Content = "Self Ring", Duration = 3 })
		elseif value == "Player" then
			if not selectedPlayer then
				WindUI:Notify({ Title = "Ring Player", Content = "No player selected", Duration = 4 })
				return
			end
			orbitMode = "player"
			CenterPart.Transparency = 1
			local dn = selectedPlayer.DisplayName ~= "" and selectedPlayer.DisplayName or selectedPlayer.Name
			WindUI:Notify({ Title = "Orbit Mode", Content = "Player: " .. dn, Duration = 3 })
		elseif value == "Click to Place" then
			cancelClickMode()
			clickMode = "place"
			WindUI:Notify({ Title = "Place Center", Content = "Click anywhere to set center", Duration = 5 })
		end

		if targetDrop then
			pcall(function() targetDrop:Close() end)
		end
	end,
})
-- ── Player Fling ─────────────────────────────────────────────────────────────
TargetTab:Space()

TargetTab:Section({ Title = "Player Fling" })

-- Build player list
local function getPlayerNames()
	local names = { "None" }
	for _, p in pairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			local dn = p.DisplayName ~= "" and p.DisplayName or p.Name
			table.insert(names, dn)
		end
	end
	return names
end

playerDropdown = TargetTab:Dropdown({
	Title = "Select Player",
	Flag = "SelectedPlayer",
	Values = getPlayerNames(),
	Value = "None",
	Callback = function(value)
		if value == "None" then
			clearSelectedPlayer()
		else
			for _, p in pairs(Players:GetPlayers()) do
				if p ~= LocalPlayer then
					local dn = p.DisplayName ~= "" and p.DisplayName or p.Name
					if dn == value then
						selectPlayer(p)
						break
					end
				end
			end
		end
		if playerDropdown then
			pcall(function() playerDropdown:Close() end)
		end
	end,
})

-- Refresh player list when players join/leave
Players.PlayerAdded:Connect(function()
	task.wait(0.5)
	if playerDropdown then
		local refreshed = getPlayerNames()
		playerDropdown:Refresh(refreshed)
	end
end)

Players.PlayerRemoving:Connect(function()
	task.wait(0.5)
	if playerDropdown then
		local refreshed = getPlayerNames()
		playerDropdown:Refresh(refreshed)
	end
end)

TargetTab:Space()

TargetTab:Button({
	Title = "Click to Select Player",
	Desc = "Click on a player to select them",
	Icon = "mouse",
	Callback = function()
		if clickMode == "player" then
			cancelClickMode()
		else
			cancelClickMode()
			clickMode = "player"
			WindUI:Notify({ Title = "Select Player", Content = "Click on a player to select", Duration = 5 })
		end
	end,
})

TargetTab:Space()

TargetTab:Button({
	Title = "Fling",
	Desc = "Fling the selected player (3 seconds)",
	Icon = "zap",
	Callback = function()
		if flinging then
			return
		end
		if not selectedPlayer or not selectedPlayer.Character then
			WindUI:Notify({ Title = "Fling", Content = "No player selected!", Duration = 4 })
			return
		end
		flinging = true
		WindUI:Notify({ Title = "Fling", Content = "Attempting to fling the selected player.", Duration = 4 })
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
		end)
	end,
})

TargetTab:Space()

local loopFlingToggle
loopFlingToggle = TargetTab:Toggle({
	Title = "Loop Fling",
	Flag = "LoopFling",
	Desc = "Continuously fling the selected player",
	Value = false,
	Callback = function(state)
		if state then
			if not selectedPlayer or not selectedPlayer.Character then
				WindUI:Notify({ Title = "Loop Fling", Content = "No player selected!", Duration = 4 })
				if loopFlingToggle then
					loopFlingToggle:Set(false)
				end
				return
			end
			loopFlinging = true
			WindUI:Notify({ Title = "Loop Fling", Content = "Attempting to fling the selected player.", Duration = 4 })
			task.spawn(function()
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
				if loopFlingToggle then
					loopFlingToggle:Set(false)
				end
			end)
		else
			loopFlinging = false
		end
	end,
})

TargetTab:Space()

local spectateToggle
spectateToggle = TargetTab:Toggle({
	Title = "Spectate",
	Flag = "Spectate",
	Desc = "Spectate the selected player",
	Value = false,
	Callback = function(state)
		if state then
			if not selectedPlayer then
				WindUI:Notify({ Title = "Spectate", Content = "No player selected!", Duration = 4 })
				if spectateToggle then
					spectateToggle:Set(false)
				end
				return
			end
			spectating = true
			local char = selectedPlayer.Character
			if char then
				local h = char:FindFirstChildWhichIsA("Humanoid")
				if h then
					Workspace.CurrentCamera.CameraSubject = h
				end
			end
		else
			spectating = false
			pcall(function()
				local h = LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid")
				if h then
					Workspace.CurrentCamera.CameraSubject = h
				end
			end)
		end
	end,
})

-- ============================================================================
-- TAB 5: CONFIG
-- ============================================================================
local ConfigTab = SettingSection:Tab({
	Title = "Config",
	Icon = "solar:folder-open-bold-duotone",
	Border = true,
})

ConfigTab:Section({ Title = "Config Management" })

local configNameValue = ""
local configsDropdown -- forward-declared so save/delete callbacks can reference it

local configNameInput = ConfigTab:Input({
	Title = "Config Name",
	Flag = "ConfigName",
	Placeholder = "Enter config name...",
	Callback = function(value)
		configNameValue = value
	end,
})

ConfigTab:Space()

ConfigTab:Button({
	Title = "Save Config",
	Icon = "save",
	Justify = "Center",
	Callback = function()
		local name = configNameValue
		if not name or name == "" then
			WindUI:Notify({ Title = "Config", Content = "Enter a config name first", Duration = 4 })
			return
		end
		local CM = Window.ConfigManager
		Window.CurrentConfig = CM:Config(name)
		if Window.CurrentConfig:Save() then
			WindUI:Notify({ Title = "Config Saved", Content = "'" .. name .. "' saved", Icon = "check", Duration = 4 })
		end
		if configsDropdown then
			configsDropdown:Refresh(CM:AllConfigs())
		end
	end,
})

ConfigTab:Space()

ConfigTab:Button({
	Title = "Load Config",
	Icon = "refresh-cw",
	Justify = "Center",
	Callback = function()
		local name = configNameValue
		if not name or name == "" then
			WindUI:Notify({ Title = "Config", Content = "Enter a config name first", Duration = 4 })
			return
		end
		local CM = Window.ConfigManager
		Window.CurrentConfig = CM:CreateConfig(name)
		if Window.CurrentConfig:Load() then
			-- force theme to match the loaded dropdown value
			pcall(function()
				local v = themeDrop and themeDrop.Value
				if v then WindUI:SetTheme(tostring(v):gsub(" ", "")) end
			end)
			WindUI:Notify({ Title = "Config Loaded", Content = "'" .. name .. "' loaded", Icon = "check", Duration = 4 })
		end
	end,
})

ConfigTab:Space()

-- Saved configs dropdown
local CM = Window.ConfigManager
local allConfigs = CM:AllConfigs()
if #allConfigs == 0 then
	allConfigs = { "No saved configs" }
end

configsDropdown = ConfigTab:Dropdown({
	Title = "Saved Configs",
	Flag = "SavedConfigs",
	Values = allConfigs,
	Value = 1,
	Callback = function(value)
		configNameValue = value
		configNameInput:Set(value)
		if configsDropdown then
			pcall(function() configsDropdown:Close() end)
		end
	end,
})

ConfigTab:Space()

ConfigTab:Button({
	Title = "Delete Config",
	Icon = "trash",
	Color = Red,
	Justify = "Center",
	Callback = function()
		local name = configNameValue
		if not name or name == "" then
			WindUI:Notify({ Title = "Config", Content = "Enter a config name first", Duration = 4 })
			return
		end
		pcall(function()
			CM:DeleteConfig(name)
		end)
		if configsDropdown then
			local refreshed = CM:AllConfigs()
			if #refreshed == 0 then
				refreshed = { "No saved configs" }
			end
			configsDropdown:Refresh(refreshed)
		end
		WindUI:Notify({ Title = "Config Deleted", Content = "'" .. name .. "' deleted", Duration = 4 })
	end,
})

-- ============================================================================
-- TAB 5: Games
-- ============================================================================
--[[
local SupportedGames = Window:Tab({
	Title = "Games",
	Icon = "solar:gamepad-minimalistic-bold-duotone",
	Border = true,
})

SupportedGames:Button({
	Title = "Natural Disaster Survival",
	Callback = function()
		TeleportService:Teleport(189707, LocalPlayer)
		WindUI:Notify({ Title = "Teleporting", Content = "Connecting "..LocalPlayer.DisplayName.." to Natural Disaster Survival.", Duration = 4})
	end
})

SupportedGames:Button({
	Title = "when the",
	Desc = "Natural Disaster Survival clone",
	Callback = function()
		TeleportService:Teleport(7057417395, LocalPlayer)
		WindUI:Notify({ Title = "Teleporting", Content = "Connecting "..LocalPlayer.DisplayName.." to when the.", Duration = 4})

	end
})
]]

local Info = Window:Tab({
	Title = "Info",
	Icon = "solar:info-circle-line-duotone"
})

ConfigTab:Select()

themeDrop = Info:Dropdown({
	Title = "Theme",
	Flag = "Theme",
	Values = {
		"Dark", "Light", "Rose", "Plant", "Red", "Indigo", "Sky",
		"Amber", "Emerald", "Midnight", "Crimson", "Monokai Pro",
		"Cotton Candy", "Mellowsi",
	},
	Value = "Plant",
	Callback = function(value)
		local ok = pcall(function() WindUI:SetTheme(tostring(value):gsub(" ","")) end)
		if not ok then
			WindUI:Notify({ Title = "Theme", Content = value .. " isn't available", Duration = 4 })
		end
		if themeDrop then
			pcall(function() themeDrop:Close() end)
		end
	end,
})

Info:Section({ Title = "Server" })

local HttpService = game:GetService("HttpService")

local function serverHop()
	local placeId = game.PlaceId
	local jobId = game.JobId
	WindUI:Notify({ Title = "Server Hop", Content = "Finding a new server...", Duration = 3 })
	local cursor = ""
	for _ = 1, 5 do
		local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(placeId)
		if cursor ~= "" then
			url = url .. "&cursor=" .. cursor
		end
		local ok, body = pcall(function()
			return game:HttpGet(url)
		end)
		if not ok then
			WindUI:Notify({ Title = "Server Hop", Content = "Request failed, try again", Duration = 4 })
			return
		end
		local decoded
		local decodeOk = pcall(function()
			decoded = HttpService:JSONDecode(body)
		end)
		if not decodeOk or type(decoded) ~= "table" then
			WindUI:Notify({ Title = "Server Hop", Content = "Could not read server list", Duration = 4 })
			return
		end
		if decoded.data then
			-- shuffle so we don't always hit the same server
			local servers = {}
			for _, s in ipairs(decoded.data) do
				table.insert(servers, s)
			end
			for i = #servers, 2, -1 do
				local j = math.random(i)
				servers[i], servers[j] = servers[j], servers[i]
			end
			for _, s in ipairs(servers) do
				if s.id ~= jobId and type(s.playing) == "number" and type(s.maxPlayers) == "number" and s.playing < s.maxPlayers then
					local tpOk = pcall(function()
						TeleportService:TeleportToPlaceInstance(placeId, s.id, LocalPlayer)
					end)
					if tpOk then
						WindUI:Notify({ Title = "Server Hop", Content = "Teleporting to a new server...", Duration = 4 })
						queueonteleport("loadstring(game:HttpGet(('https://raw.githubusercontent.com/gleeboop/Script-Testing/refs/heads/main/UnanchoredParts.luau'),true))()")
						return
					end
				end
			end
		end
		if decoded.nextPageCursor and decoded.nextPageCursor ~= "" then
			cursor = decoded.nextPageCursor
			task.wait(0.2)
		else
			break
		end
	end
	WindUI:Notify({ Title = "Server Hop", Content = "No other servers found", Duration = 4 })
end

Info:Button({
	Title = "Server Hop",
	Desc = "Teleport to a different public server",
	Icon = "server",
	Callback = function()
		serverHop()
	end,
})

Info:Section({
	Title = "Credits",
	Desc = "Super Rings created by Lukas.\nUI Library used: WindUI.\nCreated by gleebfreak."
})

-- ============================================================================
-- INIT
-- ============================================================================
WindUI:Notify({
	Title = "SUPER RING REIMAGINED",
	Content = "Loaded! V = Super Ring, F = fly, RightCtrl = toggle UI",
	Icon = "check",
	Duration = 5,
})