--[[
    SwingBarSystem (LocalScript)
    Path: StarterPlayer → StarterCharacterScripts
    Parent: StarterCharacterScripts
    Properties:
        Disabled: false
    Exported: 2026-01-28 16:22:15
]]
-- LOCAL SCRIPT : SwingBarSystem (V94 - ZOMBIE STATE FIX)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local GameState = require(ReplicatedStorage:WaitForChild("GameStateManager"))

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")
local camera = Workspace.CurrentCamera

local isPhase2MechanicActive = false
GameState.PhaseChanged:Connect(function(newPhase) isPhase2MechanicActive = (newPhase == 2) end)
if GameState:GetPhase() == 2 then isPhase2MechanicActive = true end

-- CONFIG
local RING_SIZE = 14; local WIN_ANGLE = 90; local START_ANGLE = 180; local MAGNET_DISTANCE = 5; local REGRAB_COOLDOWN = 1.0 
local COL_TRACK = Color3.fromRGB(255, 100, 0); local COL_IDLE = Color3.fromRGB(0, 255, 255); local COL_ACTIVE = Color3.fromRGB(0, 255, 0) 
local SPIN_ANIM_ID = "rbxassetid://136323863859645"; local FALL_ANIM_ID = "rbxassetid://119021926553736"; local ACRO_ANIM_ID = "rbxassetid://93742617298717"
local SFX_WIN = "rbxassetid://12222216"; local SFX_FAIL = "rbxassetid://12222225"; local SFX_LOOP = "rbxassetid://12222058" 

-- ETAT
local isActive = false; local isFlying = false; local isLanding = false 
local currentBarModel = nil; local activeBarPart = nil; local visualHolder = nil; local zoneIndicators = {} 
local lastUsedBar = nil; local lastJumpTime = 0
local swingStartTime = 0; local cycleDuration = 1; local currentTolerance = 30; local savedJumpPower = 50

-- CONNEXIONS
local swingConnection = nil; local cameraConnection = nil; local flightConnection = nil; local stateConnection = nil
local loopSound = nil; local stabilizer = nil; local stabilizerAtt = nil

-- ID
local currentActionID = 0 

-- SETUP ANIM
local function loadAnim(id, priority) 
	local a = Instance.new("Animation"); a.AnimationId = id
	local t = humanoid:LoadAnimation(a); t.Priority = priority; return t 
end
local acroTrack = loadAnim(ACRO_ANIM_ID, Enum.AnimationPriority.Action4) 
local spinTrack = loadAnim(SPIN_ANIM_ID, Enum.AnimationPriority.Action3) 
local fallTrack = loadAnim(FALL_ANIM_ID, Enum.AnimationPriority.Action2) 
spinTrack.Looped = true; fallTrack.Looped = true; acroTrack.Looped = false 

-- ==========================================
-- 🛑 KILLSWITCH PHYSIQUE
-- ==========================================
local function DestroyPhysics()
	if stabilizer then stabilizer:Destroy(); stabilizer = nil end
	if stabilizerAtt then stabilizerAtt:Destroy(); stabilizerAtt = nil end

	for _, obj in pairs(rootPart:GetChildren()) do
		if obj:IsA("BodyVelocity") or obj:IsA("BodyGyro") or obj:IsA("LinearVelocity") or obj:IsA("AlignOrientation") then
			obj:Destroy()
		end
	end
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
end

local function CleanupSystem(source)
	print("⏹️ [SYSTEM] Clean via : " .. (source or "?"))

	-- 🚨 LE FIX EST ICI : ON TUE L'ÉTAT ACTIF
	isActive = false 
	isFlying = false
	isLanding = false

	currentActionID = currentActionID + 1 
	humanoid.UseJumpPower = true
	humanoid.JumpPower = (savedJumpPower > 0) and savedJumpPower or 50

	if swingConnection then swingConnection:Disconnect(); swingConnection = nil end
	if cameraConnection then cameraConnection:Disconnect(); cameraConnection = nil end
	if flightConnection then flightConnection:Disconnect(); flightConnection = nil end 
	if stateConnection then stateConnection:Disconnect(); stateConnection = nil end

	if visualHolder then visualHolder:Destroy(); visualHolder = nil end
	if loopSound then loopSound:Stop(); loopSound:Destroy(); loopSound = nil end

	DestroyPhysics()

	humanoid.PlatformStand = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true) 
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true) 
	camera.CameraType = Enum.CameraType.Custom
end

local function createVisualRing(bar)
	if visualHolder then visualHolder:Destroy() end
	zoneIndicators = {}
	visualHolder = Instance.new("Part"); visualHolder.Name = "SwingVisual_HOLDER"; visualHolder.Size = Vector3.new(0.1, RING_SIZE, RING_SIZE); visualHolder.Transparency = 1; visualHolder.CanCollide = false; visualHolder.Anchored = true; visualHolder.CFrame = bar.CFrame; visualHolder.Parent = Workspace 
	for _, face in pairs({Enum.NormalId.Right, Enum.NormalId.Left}) do
		local gui = Instance.new("SurfaceGui"); gui.Face = face; gui.CanvasSize = Vector2.new(800, 800); gui.Parent = visualHolder; gui.LightInfluence = 0
		local main = Instance.new("Frame"); main.Size = UDim2.new(1,0,1,0); main.BackgroundTransparency = 1; main.Parent = gui
		local ring = Instance.new("Frame"); ring.Size = UDim2.new(0.9,0,0.9,0); ring.Position = UDim2.new(0.5,0,0.5,0); ring.AnchorPoint = Vector2.new(0.5,0.5); ring.BackgroundTransparency = 1; ring.Parent = main; local uic = Instance.new("UICorner"); uic.CornerRadius = UDim.new(1,0); uic.Parent = ring; local str = Instance.new("UIStroke"); str.Thickness = 30; str.Color = COL_TRACK; str.Transparency = 0.2; str.Parent = ring
		local zoneCont = Instance.new("Frame"); zoneCont.Size = UDim2.new(1,0,1,0); zoneCont.Position = UDim2.new(0.5,0,0.5,0); zoneCont.AnchorPoint = Vector2.new(0.5,0.5); zoneCont.BackgroundTransparency = 1; zoneCont.Parent = main; local visualRotation = -WIN_ANGLE; if face == Enum.NormalId.Left then visualRotation = WIN_ANGLE end; zoneCont.Rotation = visualRotation
		local ind = Instance.new("Frame"); ind.Size = UDim2.new(1, 0, 1, 0); ind.Position = UDim2.new(0.5,0,0.5,0); ind.AnchorPoint = Vector2.new(0.5,0.5); ind.BackgroundTransparency = 1; ind.Parent = zoneCont; local indCorner = Instance.new("UICorner"); indCorner.CornerRadius = UDim.new(1,0); indCorner.Parent = ind; local indStroke = Instance.new("UIStroke"); indStroke.Thickness = 30; indStroke.Color = COL_IDLE; indStroke.Transparency = 0; indStroke.Parent = ind; local grad = Instance.new("UIGradient"); grad.Rotation = -90; local angleRad = math.rad(currentTolerance); local cutOffPoint = 0.5 + (0.5 * math.cos(angleRad)); grad.Transparency = NumberSequence.new{ NumberSequenceKeypoint.new(0.0, 1), NumberSequenceKeypoint.new(math.max(0, cutOffPoint - 0.01), 1), NumberSequenceKeypoint.new(cutOffPoint, 0), NumberSequenceKeypoint.new(1.0, 0) }; grad.Parent = indStroke; table.insert(zoneIndicators, indStroke)
	end
end

-- ==========================================
-- 🏁 ATTERRISSAGE
-- ==========================================
local function ForceLand(targetPartOrNil, reason)
	if isLanding then return end 
	print("✅ [LAND] Atterrissage (" .. (reason or "?") .. ")")
	isLanding = true; isFlying = false 
	character:SetAttribute("IsLanding", true); character:SetAttribute("SwingActive", false)

	if flightConnection then flightConnection:Disconnect(); flightConnection = nil end
	if stateConnection then stateConnection:Disconnect(); stateConnection = nil end

	DestroyPhysics()
	spinTrack:Stop(0.1); acroTrack:Stop(0.1); fallTrack:Stop(0.1)

	lastUsedBar = nil 
	local canRoll = true 
	if targetPartOrNil and targetPartOrNil:GetAttribute("CanRoll") == false then canRoll = false end

	if canRoll then
		local exitDir = rootPart.CFrame.LookVector
		if targetPartOrNil then exitDir = targetPartOrNil.CFrame.LookVector end
		local exitSpeed = 80
		if targetPartOrNil then exitSpeed = targetPartOrNil:GetAttribute("Speed") or 80 end

		rootPart.Anchored = false
		humanoid.PlatformStand = false 
		humanoid:ChangeState(Enum.HumanoidStateType.Running) 

		local rAtt = Instance.new("Attachment", rootPart)
		local rVel = Instance.new("LinearVelocity")
		rVel.Attachment0 = rAtt; rVel.MaxForce = 100000; rVel.VectorVelocity = exitDir * exitSpeed; rVel.Parent = rootPart

		local rGyro = Instance.new("AlignOrientation")
		rGyro.Mode = Enum.OrientationAlignmentMode.OneAttachment; rGyro.Attachment0 = rAtt; rGyro.RigidityEnabled = true
		rGyro.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + exitDir)
		rGyro.Parent = rootPart

		local rollAnim = Instance.new("Animation"); rollAnim.AnimationId = "rbxassetid://136598973225722"
		local rollT = humanoid:LoadAnimation(rollAnim)
		rollT.Looped = false; rollT:Play()

		task.delay(rollT.Length or 0.8, function() 
			CleanupSystem("Fin Roulade")
			character:SetAttribute("IsLanding", false) 
		end)
	else
		rootPart.Anchored = true; rootPart.AssemblyLinearVelocity = Vector3.zero
		humanoid.PlatformStand = false; humanoid:ChangeState(Enum.HumanoidStateType.Running)

		local currentPos = rootPart.Position
		if targetPartOrNil then 
			currentPos = targetPartOrNil.Position + Vector3.new(0, targetPartOrNil.Size.Y/2 + humanoid.HipHeight, 0)
			local _, rotY, _ = targetPartOrNil.CFrame:ToOrientation()
			rootPart.CFrame = CFrame.new(currentPos) * CFrame.fromOrientation(0, rotY, 0)
		end

		isActive = false; isLanding = false
		CleanupSystem("Fin Sol Fixe")
		task.delay(0.1, function() rootPart.Anchored = false; character:SetAttribute("IsLanding", false) end)
	end
end

-- ==========================================
-- 🚀 VOYAGE
-- ==========================================
local function solveBallisticArc(origin, target, heightMultiplier, gravity)
	local diff = target - origin; local verticalDiff = diff.Y; local horizontalDist = Vector3.new(diff.X, 0, diff.Z).Magnitude
	local baseHeight = math.max(10, horizontalDist / 3.5); local peakHeight = baseHeight * (heightMultiplier or 1.0); local h = math.max(peakHeight, verticalDiff + 5)
	local tUp = math.sqrt(2 * h / gravity); local tDown = math.sqrt(2 * (h - verticalDiff) / gravity); local totalTime = tUp + tDown
	local velocityY = math.sqrt(2 * gravity * h); local velocityXZ = horizontalDist / totalTime
	local dirXZ = Vector3.new(diff.X, 0, diff.Z).Unit; return (dirXZ * velocityXZ) + Vector3.new(0, velocityY, 0), totalTime
end

local function StartTravelSequence(targetPart, isWin)
	if not targetPart then CleanupSystem("No Target"); return end
	currentActionID = currentActionID + 1
	local myActionID = currentActionID

	print("🚀 [JUMP] Vers: " .. targetPart.Name)

	if swingConnection then swingConnection:Disconnect(); swingConnection = nil end
	if visualHolder then visualHolder:Destroy() end
	if loopSound then loopSound:Stop() end
	spinTrack:Stop(0)

	local startPos = rootPart.Position
	local endPos = targetPart.Position
	local hMult = targetPart:GetAttribute("HeightMult") or 1.0
	local gravity = Workspace.Gravity

	local launchVelocity, flightDuration = solveBallisticArc(startPos, endPos, hMult, gravity)

	DestroyPhysics() 

	rootPart.Anchored = false
	humanoid.PlatformStand = true 
	rootPart.AssemblyLinearVelocity = launchVelocity 

	stabilizerAtt = Instance.new("Attachment", rootPart)
	stabilizer = Instance.new("AlignOrientation")
	stabilizer.Mode = Enum.OrientationAlignmentMode.OneAttachment
	stabilizer.Attachment0 = stabilizerAtt
	stabilizer.RigidityEnabled = true; stabilizer.Parent = rootPart
	stabilizer.CFrame = CFrame.lookAt(startPos, Vector3.new(endPos.X, startPos.Y, endPos.Z))

	isFlying = true
	character:SetAttribute("SwingActive", false)

	fallTrack:Stop(); acroTrack:Play() 
	task.defer(function()
		if acroTrack.IsPlaying then
			local ratio = math.clamp(acroTrack.Length / flightDuration, 0.8, 1.5)
			acroTrack:AdjustSpeed(ratio)
		end
	end)

	local launchTime = tick()
	local animationPhase = "TRICK" 

	flightConnection = RunService.RenderStepped:Connect(function()
		if currentActionID ~= myActionID then 
			if flightConnection then flightConnection:Disconnect() end
			return 
		end

		local elapsed = tick() - launchTime

		if stabilizer then
			local currentDir = (targetPart.Position - rootPart.Position) * Vector3.new(1,0,1)
			if currentDir.Magnitude > 0.1 then stabilizer.CFrame = CFrame.lookAt(Vector3.zero, currentDir) end
		end

		if elapsed > flightDuration - 0.1 and animationPhase == "TRICK" then
			animationPhase = "FALL"
			humanoid.PlatformStand = false
			acroTrack:Stop(0.3); fallTrack:Play(0.3)
		end

		local dist = (rootPart.Position - targetPart.Position).Magnitude
		if dist < MAGNET_DISTANCE then ForceLand(targetPart, "Magnet"); return end

		if rootPart.AssemblyLinearVelocity.Y < 0 then
			local rayParams = RaycastParams.new()
			local barsFolder = Workspace:FindFirstChild("SwingBars")
			local filterList = {character}
			if barsFolder then table.insert(filterList, barsFolder) end
			rayParams.FilterDescendantsInstances = filterList
			rayParams.FilterType = Enum.RaycastFilterType.Exclude

			local hit = Workspace:Raycast(rootPart.Position, Vector3.new(0, -3, 0), rayParams)
			if hit then
				local n = hit.Instance.Name
				if not (n == "Win" or n == "Loose" or n == "Bar" or hit.Instance:FindFirstChild("SwingVisual_HOLDER")) then
					ForceLand(nil, "Raycast Ground") 
				end
			end
		end
	end)

	local useCine = targetPart:GetAttribute("UseCinematicCamera")
	if useCine then
		camera.CameraType = Enum.CameraType.Scriptable
		cameraConnection = RunService.RenderStepped:Connect(function()
			if currentActionID ~= myActionID then return end 
			local travelDir = (targetPart.Position - rootPart.Position).Unit
			local camPos = rootPart.Position - (travelDir * 15) + Vector3.new(0, 8, 0)
			camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(camPos, targetPart.Position), 0.2)
		end)
	end
end

-- Helpers
local function getTimelineAngle() local elapsed = tick() - swingStartTime; local progress = (elapsed % cycleDuration) / cycleDuration; return (START_ANGLE + (progress * 360)) % 360 end
local function checkTolerance() local current = getTimelineAngle(); local diff = math.abs(current - WIN_ANGLE); if diff > 180 then diff = 360 - diff end; return (diff <= currentTolerance) end
local function updateVisuals() local col = checkTolerance() and COL_ACTIVE or COL_IDLE; for _, stroke in pairs(zoneIndicators) do stroke.Color = col end end

local function triggerJump()
	if not isActive then return end

	local isGood = checkTolerance()
	local targetName = isGood and "Win" or "Loose"
	local target = currentBarModel:FindFirstChild(targetName)

	if not target then CleanupSystem("Target Missing"); return end

	local sfx = isGood and SFX_WIN or SFX_FAIL
	local s = Instance.new("Sound", rootPart); s.SoundId = sfx; s:Play(); Debris:AddItem(s,2)

	lastUsedBar = activeBarPart
	lastJumpTime = tick()

	StartTravelSequence(target, isGood)
end

local function startSwing(bar)
	print("✊ [GRAB] Barre : " .. bar.Parent.Name)
	currentActionID = currentActionID + 1 

	if flightConnection then flightConnection:Disconnect(); flightConnection = nil end
	if cameraConnection then cameraConnection:Disconnect(); cameraConnection = nil end
	if visualHolder then visualHolder:Destroy(); visualHolder = nil end
	if loopSound then loopSound:Stop(); loopSound:Destroy(); loopSound = nil end

	DestroyPhysics()
	if stateConnection then stateConnection:Disconnect() end 

	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero

	if not isActive then savedJumpPower = humanoid.JumpPower end
	humanoid.UseJumpPower = true; humanoid.JumpPower = 0

	isActive = true; isLanding = false; isFlying = false 
	currentBarModel = bar.Parent; activeBarPart = bar

	local spd = bar:GetAttribute("SpinSpeed") or 1.5; if spd <= 0 then spd = 1 end
	cycleDuration = 1 / spd; currentTolerance = bar:GetAttribute("Difficulty") or 30

	loopSound = Instance.new("Sound", rootPart); loopSound.SoundId = SFX_LOOP; loopSound.Looped = true; loopSound.Volume = 0.5; loopSound:Play()
	character:SetAttribute("SwingActive", true); character:SetAttribute("IsLanding", false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false); humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	rootPart.Anchored = true; humanoid.PlatformStand = true; humanoid.AutoRotate = false; rootPart.AssemblyAngularVelocity = Vector3.zero

	fallTrack:Stop(0); acroTrack:Stop(0) 
	spinTrack:Play(0.1) 

	createVisualRing(bar); swingStartTime = tick()

	swingConnection = RunService.RenderStepped:Connect(function()
		if not isActive then return end
		humanoid.AutoRotate = false; updateVisuals()
		local rad = math.rad(-getTimelineAngle())
		character:PivotTo(bar.CFrame * CFrame.Angles(rad, 0, 0) * CFrame.new(0, -3.5, 0) * CFrame.Angles(0, math.pi, 0))
	end)
end

UserInputService.InputBegan:Connect(function(input)
	if not isActive then return end
	if isFlying then return end 

	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
		-- DEBUG : On vérifie si l'input est accepté
		print("🎮 [INPUT] Jump demandé. Active: "..tostring(isActive))
		triggerJump() 
	end
end)

RunService.RenderStepped:Connect(function()
	if not isPhase2MechanicActive or character:GetAttribute("IsInCutscene") then return end
	if isActive and not isFlying and not isLanding then return end 

	local overlap = OverlapParams.new(); overlap.FilterDescendantsInstances = {character}; overlap.FilterType = Enum.RaycastFilterType.Exclude
	local parts = Workspace:GetPartBoundsInBox(rootPart.CFrame, Vector3.new(5, 8, 5), overlap)

	for _, hit in ipairs(parts) do
		if hit.Name == "Bar" and hit.Parent and hit.Parent.Parent and hit.Parent.Parent.Name == "SwingBars" then
			if hit == lastUsedBar and (tick() - lastJumpTime < REGRAB_COOLDOWN) then
				-- Rien
			else
				startSwing(hit)
				break 
			end
		end
	end
end)