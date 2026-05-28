-- LocalScript: Place inside StarterPlayer -> StarterPlayerScripts

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- ================= CONFIGURATION =================
local FLOAT_SPEED = 4 -- Speed you will drift upwards initially
-- =================================================

local player = Players.LocalPlayer

-- Dynamic character variables
local character = nil
local humanoidRootPart = nil
local humanoid = nil
local animator = nil

local isFloating = false
local zeroGravityForce = nil
local tumbleRotator = nil
local activeTrack = nil
local runServiceConnection = nil

local originalProperties = {}
local originalDamping = {}
local originalAngularDamping = {}
local touchedConnections = {}

local hasBounced = false
local floatSpeedCanceled = false
local speedToMaintain = 0

-- Highly elastic, zero friction material properties for perfect bouncing
local bounceMaterial = PhysicalProperties.new(
	0.7, -- Density
	0, -- Friction (0 means no scraping/dragging on walls)
	1, -- Elasticity (1 for a perfect bounce)
	1, -- FrictionWeight
	100 -- MAX ElasticityWeight
)

-- Dynamic R6/R15 animation loader
local function getAnimationObject(animName)
	if not character then
		return nil
	end
	local animate = character:FindFirstChild("Animate")
	if animate then
		local folder = animate:FindFirstChild(animName)
		if folder then
			for _, child in ipairs(folder:GetDescendants()) do
				if child:IsA("Animation") then
					return child
				end
			end
		end
	end

	local fallback = Instance.new("Animation")
	if animName == "walk" then
		fallback.AnimationId = "rbxassetid://913402848"
	else
		fallback.AnimationId = "rbxassetid://507766388"
	end
	return fallback
end

-- Apply custom zero-resistance physics and bounciness to all body parts (limbs stay collidable!)
local function applyBouncePhysics()
	if not character then
		return
	end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			originalProperties[part] = part.CustomPhysicalProperties
			part.CustomPhysicalProperties = bounceMaterial

			originalDamping[part] = part.AssemblyLinearDamping
			part.AssemblyLinearDamping = 0

			originalAngularDamping[part] = part.AssemblyAngularDamping
			part.AssemblyAngularDamping = 0
		end
	end
end

-- Restore original physical properties and drag
local function restoreBouncePhysics()
	for part, props in pairs(originalProperties) do
		if part and part.Parent then
			part.CustomPhysicalProperties = props
		end
	end
	originalProperties = {}

	for part, damping in pairs(originalDamping) do
		if part and part.Parent then
			part.AssemblyLinearDamping = damping
		end
	end
	originalDamping = {}

	for part, angDamping in pairs(originalAngularDamping) do
		if part and part.Parent then
			part.AssemblyAngularDamping = angDamping
		end
	end
	originalAngularDamping = {}
end

local function getCharacterMass()
	if not character then
		return 0
	end
	local totalMass = 0
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and not part.Massless then
			totalMass = totalMass + part:GetMass()
		end
	end
	return totalMass
end

-- Forward declaration of toggle function to handle cleanup on death
local toggleFloating

-- Handles the automatic vector reflection during a bounce
local function handleBounce()
	if hasBounced or not humanoidRootPart then
		return
	end
	hasBounced = true

	-- Configure raycast to ignore player's character
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	-- Cast an 8-stud ray directly ahead in the direction we are moving
	local rayDirection = humanoidRootPart.AssemblyLinearVelocity.Unit * 8
	local raycastResult = Workspace:Raycast(humanoidRootPart.Position, rayDirection, raycastParams)

	if raycastResult then
		local N = raycastResult.Normal -- The 3D normal vector of the wall we hit
		local V = humanoidRootPart.AssemblyLinearVelocity

		-- Classic 3D vector reflection formula: R = V - 2 * (V.N) * N
		local reflected = V - 2 * (V:Dot(N)) * N

		-- On the very first wall impact (not ceilings), cancel the upward float speed
		if not floatSpeedCanceled then
			-- If normal has low Y aspect, it's a vertical wall, not a ceiling
			if math.abs(N.Y) < 0.5 then
				floatSpeedCanceled = true
				reflected = Vector3.new(reflected.X, 0, reflected.Z)
			end
		end

		-- Securely lock velocity and redirect player at exactly 100% speed!
		humanoidRootPart.AssemblyLinearVelocity = reflected.Unit * speedToMaintain
	end

	-- Small cooldown to allow character to bounce away before accepting next collision
	task.wait(0.15)
	hasBounced = false
end

-- Connect touched events to character parts
local function connectTouched()
	if not character then
		return
	end
	touchedConnections = {}
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			local conn = part.Touched:Connect(function(otherPart)
				if not isFloating or hasBounced then
					return
				end
				if otherPart:IsDescendantOf(character) then
					return
				end
				if otherPart.CanCollide == false then
					return
				end

				handleBounce()
			end)
			table.insert(touchedConnections, conn)
		end
	end
end

local function disconnectTouched()
	for _, conn in ipairs(touchedConnections) do
		conn:Disconnect()
	end
	touchedConnections = {}
end

toggleFloating = function()
	if not character or not humanoidRootPart or not humanoid or not animator then
		return
	end

	isFloating = not isFloating

	if isFloating then
		hasBounced = false
		floatSpeedCanceled = false

		-- 1. Eject if currently sitting
		if humanoid.Sit then
			humanoid.Sit = false
			task.wait(0.1)
		end

		-- 2. Prevent sitting on any seats/vehicles while floating
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

		-- 3. Grab current speed (inertia)
		local currentVel = humanoidRootPart.AssemblyLinearVelocity
		local isWalking = humanoid.MoveDirection.Magnitude > 0

		-- 4. Play walk or idle animation
		local animObj = getAnimationObject(isWalking and "walk" or "idle")
		if animObj and animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:Stop()
			end

			activeTrack = animator:LoadAnimation(animObj)
			activeTrack.Looped = true
			activeTrack.Priority = Enum.AnimationPriority.Action
			activeTrack:Play()
		end

		-- 5. Enable PlatformStand to make character physically responsive
		humanoid.PlatformStand = true

		-- 6. Neutralize vertical gravity perfectly (0 weight)
		local mass = getCharacterMass()
		local counterForce = mass * Workspace.Gravity

		zeroGravityForce = Instance.new("BodyForce")
		zeroGravityForce.Name = "ZeroG_GravityCounter"
		zeroGravityForce.Force = Vector3.new(0, counterForce, 0)
		zeroGravityForce.Parent = humanoidRootPart

		-- 7. Apply launch velocity and lock our speed magnitude
		local initialVelocity
		if isWalking then
			initialVelocity = Vector3.new(currentVel.X, FLOAT_SPEED, currentVel.Z)
		else
			initialVelocity = Vector3.new(0, FLOAT_SPEED, 0)
		end
		speedToMaintain = initialVelocity.Magnitude
		humanoidRootPart.AssemblyLinearVelocity = initialVelocity

		-- 8. Apply slow tumble rotation
		tumbleRotator = Instance.new("BodyAngularVelocity")
		tumbleRotator.Name = "ZeroG_Tumble"
		tumbleRotator.MaxTorque = Vector3.new(10000, 10000, 10000)
		tumbleRotator.AngularVelocity =
			Vector3.new(math.random(-10, 10) / 20, math.random(-10, 10) / 20, math.random(-10, 10) / 20)
		tumbleRotator.Parent = humanoidRootPart

		-- 9. Remove air friction, apply perfect bounciness
		applyBouncePhysics()
		connectTouched()

		-- 10. Start speed lock loop (glides you at a constant speed, but allows other players to push you!)
		runServiceConnection = RunService.Heartbeat:Connect(function()
			if not isFloating or not humanoidRootPart then
				return
			end
			local currentVelocity = humanoidRootPart.AssemblyLinearVelocity
			if currentVelocity.Magnitude > 0.1 then
				-- Keep speed locked, but preserve the current direction (which changes on bounce or push!)
				humanoidRootPart.AssemblyLinearVelocity = currentVelocity.Unit * speedToMaintain
			end
		end)

		print("Lossless Rigid Zero-G: Enabled!")
	else
		-- Restore normal gravity, materials, drag, and controls
		if zeroGravityForce then
			zeroGravityForce:Destroy()
			zeroGravityForce = nil
		end
		if tumbleRotator then
			tumbleRotator:Destroy()
			tumbleRotator = nil
		end
		if activeTrack then
			activeTrack:Stop()
			activeTrack = nil
		end
		if runServiceConnection then
			runServiceConnection:Disconnect()
			runServiceConnection = nil
		end

		disconnectTouched()
		restoreBouncePhysics()

		humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
		humanoid.PlatformStand = false

		print("Lossless Rigid Zero-G: Disabled.")
	end
end

-- ================= CHARACTER SETUP & PERSISTENCE =================
local function setupCharacter(char)
	character = player.Character -- assignment: character value = player.Character
	humanoidRootPart = char:WaitForChild("HumanoidRootPart")
	humanoid = char:WaitForChild("Humanoid")
	animator = humanoid:WaitForChild("Animator")

	humanoid.Died:Connect(function()
		if isFloating then
			toggleFloating() -- Reset on death cleanly
		end
	end)
end

if player.Character then
	setupCharacter(player.Character)
end
player.CharacterAdded:Connect(setupCharacter)

-- Listen for K key press
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.K then
		toggleFloating()
	end
end)
