-- LocalScript: Place inside StarterPlayer -> StarterPlayerScripts

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

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

local originalProperties = {}
local originalDamping = {}
local originalAngularDamping = {}
local originalCollisions = {}
local touchedConnections = {}

local hasBounced = false
local floatSpeedCanceled = false

-- Highly elastic, zero friction material properties for perfect bouncing
local bounceMaterial = PhysicalProperties.new(
	0.7, -- Density
	0, -- Friction
	1, -- Elasticity (1 for a perfect lossless bounce)
	1, -- FrictionWeight
	100 -- MAX ElasticityWeight (Forces your bounciness to override all other game objects)
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

-- Apply custom zero-resistance physics, bounciness, and make limbs non-collidable
local function applyBouncePhysics()
	if not character then
		return
	end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			-- Save and apply physical bounciness materials
			originalProperties[part] = part.CustomPhysicalProperties
			part.CustomPhysicalProperties = bounceMaterial

			-- Save and remove air resistance (linear damping) completely so we glide forever
			originalDamping[part] = part.AssemblyLinearDamping
			part.AssemblyLinearDamping = 0

			-- Save and remove spin friction (angular damping) so we tumble smoothly
			originalAngularDamping[part] = part.AssemblyAngularDamping
			part.AssemblyAngularDamping = 0

			-- Make limbs non-collidable so they don't act like shock absorbers and ruin the bounce
			if part.Name ~= "HumanoidRootPart" then
				originalCollisions[part] = part.CanCollide
				part.CanCollide = false
			end
		end
	end
end

-- Restore original physical properties, collisions, and drag
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

	for part, canCollide in pairs(originalCollisions) do
		if part and part.Parent then
			part.CanCollide = canCollide
		end
	end
	originalCollisions = {}
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

-- Handles canceling the upward float speed on the very first collision
local function handleBounce()
	if hasBounced then
		return
	end
	hasBounced = true

	-- Wait 1 frame for Roblox to complete the physical bounce calculation
	task.wait()
	if not isFloating or not humanoidRootPart then
		hasBounced = false
		return
	end

	local currentVelocity = humanoidRootPart.AssemblyLinearVelocity

	-- On the very first collision, cancel the vertical float speed up if we hit a wall
	if not floatSpeedCanceled then
		floatSpeedCanceled = true
		if currentVelocity.Y > -0.5 then
			humanoidRootPart.AssemblyLinearVelocity = Vector3.new(currentVelocity.X, 0, currentVelocity.Z) -- Halt vertical rising
		end
	end

	-- Wait a small cooldown so we bounce away from the wall before we can trigger another bounce check
	task.wait(0.15)
	hasBounced = false
end

-- Only connect touch listeners to the rigid HumanoidRootPart for 100% collision accuracy
local function connectTouched()
	if not humanoidRootPart then
		return
	end
	touchedConnections = {}

	local conn = humanoidRootPart.Touched:Connect(function(otherPart)
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

		-- 5. Enable PlatformStand to make character limp and physically responsive
		humanoid.PlatformStand = true

		-- 6. Neutralize vertical gravity perfectly (0 weight)
		local mass = getCharacterMass()
		local counterForce = mass * Workspace.Gravity

		zeroGravityForce = Instance.new("BodyForce")
		zeroGravityForce.Name = "ZeroG_GravityCounter"
		zeroGravityForce.Force = Vector3.new(0, counterForce, 0)
		zeroGravityForce.Parent = humanoidRootPart

		-- 7. Apply launch velocity
		local initialVelocity
		if isWalking then
			initialVelocity = Vector3.new(currentVel.X, FLOAT_SPEED, currentVel.Z)
		else
			initialVelocity = Vector3.new(0, FLOAT_SPEED, 0)
		end
		humanoidRootPart.AssemblyLinearVelocity = initialVelocity

		-- 8. Apply slow tumble rotation
		tumbleRotator = Instance.new("BodyAngularVelocity")
		tumbleRotator.Name = "ZeroG_Tumble"
		tumbleRotator.MaxTorque = Vector3.new(10000, 10000, 10000)
		tumbleRotator.AngularVelocity =
			Vector3.new(math.random(-10, 10) / 20, math.random(-10, 10) / 20, math.random(-10, 10) / 20)
		tumbleRotator.Parent = humanoidRootPart

		-- 9. Remove air friction, apply perfect bounciness, and phase out limb collisions
		applyBouncePhysics()
		connectTouched()

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
