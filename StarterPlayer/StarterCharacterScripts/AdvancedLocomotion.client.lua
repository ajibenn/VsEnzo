--[[
    AdvancedLocomotion (LocalScript)
    Path: StarterPlayer → StarterCharacterScripts
    Parent: StarterCharacterScripts
    Properties:
        Disabled: false
    Exported: 2026-01-28 16:22:15
]]
-- LOCAL SCRIPT : AdvancedLocomotion (V42 - PURE PHYSICS / NO CAM)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Connexion au Cerveau
local GameState = require(ReplicatedStorage:WaitForChild("GameStateManager"))

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- ====================================================
-- 1. CONFIGURATION INITIALE
-- ====================================================
local ANIMATIONS = {
	Idle 		= "rbxassetid://81798177707618",
	Jump 		= "rbxassetid://122174121162911", 
	Fall 		= "rbxassetid://119021926553736", 
	-- MARCHE
	WalkFwd 	= "rbxassetid://114553681604458",
	WalkBwd 	= "rbxassetid://114553681604458", 
	WalkLeft 	= "rbxassetid://129100250685562",
	WalkRight 	= "rbxassetid://95689109531090",
	-- SPRINT
	SprintFwd 	= "rbxassetid://91621135033649",
	SprintBwd 	= "rbxassetid://91621135033649", 
	SprintLeft 	= "rbxassetid://124820288839753",
	SprintRight = "rbxassetid://137468862684942",

	Slide 		= "rbxassetid://99512748947217" 
}

local MAX_ANIM_PLAYBACK_SPEED = 1.8 

local DEFAULT_WALK = 16
local DEFAULT_SPRINT = 38
local DEFAULT_SLIDE = 85

if not character:GetAttribute("BaseWalkSpeed") then character:SetAttribute("BaseWalkSpeed", DEFAULT_WALK) end
if not character:GetAttribute("BaseSprintSpeed") then character:SetAttribute("BaseSprintSpeed", DEFAULT_SPRINT) end

local SLIDE_DURATION = 0.9  
local SLIDE_COOLDOWN = 1.2
local NORMAL_HIP_HEIGHT = 2 
local SLIDE_HIP_HEIGHT = 0.5 
local RAYCAST_DISTANCE = 3.8 

local HITBOX_PARTS = {"Head", "UpperTorso", "LowerTorso", "Torso"} 

-- ====================================================
-- 2. CHARGEMENT
-- ====================================================
local tracks = {}
NORMAL_HIP_HEIGHT = humanoid.HipHeight

for name, id in pairs(ANIMATIONS) do
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local success, track = pcall(function() return humanoid:LoadAnimation(anim) end)
	if success then
		tracks[name] = track
		-- Priorités corrigées (V41)
		if name == "Slide" then
			track.Priority = Enum.AnimationPriority.Action3 
		elseif name == "Fall" or name == "Jump" then
			track.Priority = Enum.AnimationPriority.Movement 
		else
			track.Priority = Enum.AnimationPriority.Movement
		end
	end
end

local function stopAllTracks()
	for _, t in pairs(tracks) do
		if t.IsPlaying then t:Stop(0.2) end 
	end
end

-- ====================================================
-- 3. GLISSADE & HITBOX DYNAMIQUE
-- ====================================================
local isSliding = false
local canSlide = true

local function toggleSlideHitbox(active)
	for _, partName in pairs(HITBOX_PARTS) do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			part.CanCollide = not active 
		end
	end
end

local function isSprintPressed()
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then return true end
	local gamepads = UserInputService:GetConnectedGamepads()
	for _, gamepad in ipairs(gamepads) do
		if UserInputService:IsGamepadButtonDown(gamepad, Enum.KeyCode.ButtonL3) then return true end
	end
	return false
end

-- ❌ FONCTION updateFOV SUPPRIMÉE (Géré par DynamicCamera V15)

local function startSlide()
	if not canSlide or isSliding then return end
	local rayOrigin = rootPart.Position
	local rayDir = Vector3.new(0, -RAYCAST_DISTANCE, 0)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {character}
	local hit = Workspace:Raycast(rayOrigin, rayDir, rayParams)
	if not hit then return end 
	if character:GetAttribute("IsWallRunning") then return end
	if character:GetAttribute("SwingActive") then return end
	if character:GetAttribute("ActionChainActive") then return end 
	if GameState:GetCutscene() then return end 

	isSliding = true; canSlide = false
	character:SetAttribute("IsSliding", true)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	toggleSlideHitbox(true)

	if tracks.Slide then
		tracks.Slide:Play(0.1)
		if tracks.Slide.Length > 0 then tracks.Slide:AdjustSpeed(tracks.Slide.Length / SLIDE_DURATION) end
	end

	local sound = Instance.new("Sound", rootPart); sound.SoundId = "rbxassetid://9119713916"; sound.Volume = 1; sound:Play(); Debris:AddItem(sound, 1.5)

	local downTween = TweenService:Create(humanoid, TweenInfo.new(0.1), {HipHeight = SLIDE_HIP_HEIGHT}); downTween:Play()
	humanoid.WalkSpeed = 0 

	local slideDirection = rootPart.CFrame.LookVector
	local bodyVel = Instance.new("BodyVelocity")
	bodyVel.Velocity = slideDirection * DEFAULT_SLIDE
	bodyVel.MaxForce = Vector3.new(100000, 0, 100000) 
	bodyVel.P = 5000
	bodyVel.Parent = rootPart

	local currentSprintSpeed = character:GetAttribute("BaseSprintSpeed") or DEFAULT_SPRINT
	local targetVel = slideDirection * currentSprintSpeed

	TweenService:Create(bodyVel, TweenInfo.new(SLIDE_DURATION, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Velocity = targetVel}):Play()

	-- ❌ FOV TWEEN SUPPRIMÉ (DynamicCamera gère ça avec la vitesse)

	local recoveryTime = 0.2
	task.delay(SLIDE_DURATION - recoveryTime, function()
		local upTween = TweenService:Create(humanoid, TweenInfo.new(recoveryTime), {HipHeight = NORMAL_HIP_HEIGHT}); upTween:Play()
	end)

	task.delay(SLIDE_DURATION, function()
		if bodyVel then bodyVel:Destroy() end
		humanoid.HipHeight = NORMAL_HIP_HEIGHT
		toggleSlideHitbox(false)
		isSliding = false
		character:SetAttribute("IsSliding", false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		-- ❌ updateFOV() SUPPRIMÉ
		task.delay(SLIDE_COOLDOWN - SLIDE_DURATION, function() canSlide = true end)
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if GameState:GetCutscene() then return end 
	if character:GetAttribute("ActionChainActive") then return end 
	-- ❌ INPUT LEFT SHIFT SUPPRIMÉ (Ne servait qu'au FOV ici)
	if input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.ButtonB then startSlide() end
end)

-- ❌ INPUT ENDED SUPPRIMÉ (Ne servait qu'au FOV)

-- ====================================================
-- 4. SYSTÈME D'ANIMATION
-- ====================================================
local function stopTrack(name, fade) 
	if tracks[name] and tracks[name].IsPlaying then tracks[name]:Stop(fade or 0.2) end 
end

local function syncAndPlay(masterName, slaveName, weight, speed)
	local master = tracks[masterName]
	local slave = tracks[slaveName]
	if not master or not slave then return end

	if not slave.IsPlaying then slave:Play(0.2) end
	if master.IsPlaying and master.Length > 0 and slave.Length > 0 then
		local relativeTime = master.TimePosition / master.Length
		if math.abs(slave.TimePosition - (relativeTime * slave.Length)) > 0.1 then
			slave.TimePosition = relativeTime * slave.Length
		end
	end
	slave:AdjustWeight(weight, 0.1) 
	slave:AdjustSpeed(speed)
end

local function adjustTrack(name, weight, speed)
	local track = tracks[name]; if not track then return end
	if not track.IsPlaying then track:Play(0.2) end
	track:AdjustWeight(weight, 0.1)
	track:AdjustSpeed(speed)
end

RunService.RenderStepped:Connect(function(dt)
	local isTrickActive = character:GetAttribute("ActionChainActive") == true
	local isCutscene = GameState:GetCutscene() == true

	if isTrickActive or isCutscene then stopAllTracks(); return end
	if character:GetAttribute("SwingActive") == true then stopAllTracks(); return end
	if character:GetAttribute("IsFlying") == true then stopAllTracks(); return end 

	if isSliding then
		for k,v in pairs(ANIMATIONS) do if k ~= "Slide" then stopTrack(k, 0.1) end end
		return 
	end
	stopTrack("Slide", 0.2)

	local rayOrigin = rootPart.Position
	local rayDir = Vector3.new(0, -RAYCAST_DISTANCE, 0) 
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {character}
	local rayResult = Workspace:Raycast(rayOrigin, rayDir, rayParams)
	local isTrulyAirborne = (rayResult == nil)
	local isWallRunning = character:GetAttribute("IsWallRunning") == true

	local velocity = rootPart.AssemblyLinearVelocity * Vector3.new(1,0,1)
	local speed = velocity.Magnitude

	local currentWalk = character:GetAttribute("BaseWalkSpeed") or DEFAULT_WALK
	local currentSprint = character:GetAttribute("BaseSprintSpeed") or DEFAULT_SPRINT

	local wantsToSprint = isSprintPressed()

	if not isTrulyAirborne and not isWallRunning then 
		local relativeVel = rootPart.CFrame:VectorToObjectSpace(velocity)
		local fwdDot = -relativeVel.Z 

		local targetSpeed = currentWalk 
		if wantsToSprint and fwdDot > -0.5 then 
			targetSpeed = currentSprint 
		end

		humanoid.WalkSpeed = targetSpeed 
	end

	-- GESTION SAUT / CHUTE
	if isTrulyAirborne or isWallRunning then
		if isWallRunning then
			adjustTrack("SprintFwd", 1, 1.2)
			stopTrack("Fall", 0.1); stopTrack("Jump", 0.1)
		else
			for k,v in pairs(ANIMATIONS) do if k ~= "Fall" then stopTrack(k, 0.1) end end
			adjustTrack("Fall", 1, 1) 
		end
		return 
	end

	stopTrack("Jump", 0.1); stopTrack("Fall", 0.2)

	if speed < 0.5 then
		adjustTrack("Idle", 1, 1)
		for k,v in pairs(ANIMATIONS) do 
			if k:match("Walk") or k:match("Sprint") then stopTrack(k, 0.2) end 
		end
	else
		stopTrack("Idle", 0.2)
		local relativeVel = rootPart.CFrame:VectorToObjectSpace(velocity)
		local fwd = -relativeVel.Z 
		local right = relativeVel.X 

		local totalSpeed = math.abs(fwd) + math.abs(right)
		if totalSpeed > 1 then fwd = fwd / totalSpeed; right = right / totalSpeed end

		local prefix = (wantsToSprint and fwd > -0.1) and "Sprint" or "Walk"

		local refSpeed = (prefix == "Sprint") and 22 or 16
		local rawAnimSpeed = speed / refSpeed
		local baseAnimSpeed = math.clamp(rawAnimSpeed, 0.1, MAX_ANIM_PLAYBACK_SPEED)

		local wFwd = math.clamp(fwd, 0, 1)       
		local wBwd = math.clamp(-fwd, 0, 1)      
		local wRight = math.clamp(right, 0, 1)   
		local wLeft = math.clamp(-right, 0, 1)   

		local mainAnimName = nil
		if wFwd > 0.01 then
			mainAnimName = prefix.."Fwd"
			adjustTrack(mainAnimName, wFwd, baseAnimSpeed)
			stopTrack(prefix.."Bwd", 0.2)
		elseif wBwd > 0.01 then
			mainAnimName = prefix.."Bwd"
			adjustTrack(mainAnimName, wBwd, -baseAnimSpeed) 
			stopTrack(prefix.."Fwd", 0.2)
		else
			stopTrack(prefix.."Fwd", 0.2); stopTrack(prefix.."Bwd", 0.2)
		end

		if wBwd > 0.5 then 
			if wRight > 0.01 then
				if mainAnimName then syncAndPlay(mainAnimName, prefix.."Left", wRight, -baseAnimSpeed)
				else adjustTrack(prefix.."Left", wRight, -baseAnimSpeed) end
				stopTrack(prefix.."Right", 0.2)
			elseif wLeft > 0.01 then
				if mainAnimName then syncAndPlay(mainAnimName, prefix.."Right", wLeft, -baseAnimSpeed)
				else adjustTrack(prefix.."Right", wLeft, -baseAnimSpeed) end
				stopTrack(prefix.."Left", 0.2)
			else
				stopTrack(prefix.."Right", 0.2); stopTrack(prefix.."Left", 0.2)
			end
		else 
			if wRight > 0.01 then
				if mainAnimName then syncAndPlay(mainAnimName, prefix.."Right", wRight, baseAnimSpeed)
				else adjustTrack(prefix.."Right", wRight, baseAnimSpeed) end
				stopTrack(prefix.."Left", 0.2)
			elseif wLeft > 0.01 then
				if mainAnimName then syncAndPlay(mainAnimName, prefix.."Left", wLeft, baseAnimSpeed)
				else adjustTrack(prefix.."Left", wLeft, baseAnimSpeed) end
				stopTrack(prefix.."Right", 0.2)
			else
				stopTrack(prefix.."Right", 0.2); stopTrack(prefix.."Left", 0.2)
			end
		end

		local otherPrefix = (prefix == "Sprint") and "Walk" or "Sprint"
		stopTrack(otherPrefix.."Fwd"); stopTrack(otherPrefix.."Bwd")
		stopTrack(otherPrefix.."Left"); stopTrack(otherPrefix.."Right")
	end
end)