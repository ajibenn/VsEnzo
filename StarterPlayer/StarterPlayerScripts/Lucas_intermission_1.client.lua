--[[
    Lucas intermission 1 (LocalScript)
    Path: StarterPlayer → StarterPlayerScripts
    Parent: StarterPlayerScripts
    Properties:
        Disabled: false
    Exported: 2026-01-28 16:22:15
]]
-- LOCAL SCRIPT : CinematicTrigger (DEBUG FOV)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- MODULES
local Moon2Cutscene = require(ReplicatedStorage:WaitForChild("Moon2Cutscene"))
local GameState = require(ReplicatedStorage:WaitForChild("GameStateManager")) 

-- REFERENCES
local animFile = ReplicatedStorage:WaitForChild("Lucasfallcin")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")
local camera = Workspace.CurrentCamera
local triggerPart = Workspace:WaitForChild("TriggerCinematic2")

-- ⚙️ CONFIGURATION
local LUCAS_INDEX = 3
local MAP_FOLDER_NAME = "Phase2Map DEBUG1" 
local SPRINT_ID = "rbxassetid://91621135033649" 
local END_TP_PART_NAME = "Finintermission1" 

-- ⏱️ REGLAGES
local TRANSITION_DURATION = 2.0 
local BASE_SPRINT_SPEED = 38 

local isPlaying = false

-- === OUTILS ===

local function setControls(active)
	local controls = require(player.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
	if active then controls:Enable() else controls:Disable() end
end

local function setRealCharVisible(isVisible)
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Transparency = isVisible and 0 or 1
		elseif part:IsA("Decal") then
			part.Transparency = isVisible and 0 or 1
		end
	end
end

local function toggleRealCharacter(active)
	local animateScript = character:FindFirstChild("Animate")
	if animateScript then animateScript.Disabled = not active end

	if not active then
		humanoid.PlatformStand = true 
		rootPart.Anchored = true
		rootPart.Velocity = Vector3.new(0,0,0)
	else
		humanoid.PlatformStand = false
		rootPart.Anchored = false
	end
end

local function setupClone(cloneChar)
	for _, child in pairs(cloneChar:GetChildren()) do
		if child:IsA("Script") or child:IsA("LocalScript") then child:Destroy() end
	end
	if cloneChar:FindFirstChild("HumanoidRootPart") then
		cloneChar.HumanoidRootPart.Anchored = true
	end
	if cloneChar:FindFirstChild("Humanoid") then
		cloneChar.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

-- ☢️ RESET CAMÉRA NUCLÉAIRE
local function nuclearCameraReset(destinationPart)
	camera.CameraType = Enum.CameraType.Scriptable
	if destinationPart then
		camera.CFrame = destinationPart.CFrame + Vector3.new(0, 5, 10)
		camera.Focus = destinationPart.CFrame
	end
	RunService.RenderStepped:Wait()
	if humanoid then camera.CameraSubject = humanoid end
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
end

-- === MAIN LOGIC ===

local function playCinematic()
	if isPlaying then return end
	isPlaying = true

	print("🔍 [DEBUG FOV] 1. Démarrage...")

	-- 1. SAUVEGARDE
	local startPlayerCFrame = rootPart.CFrame
	local startCameraCFrame = camera.CFrame
	local startFOV = camera.FieldOfView

	print("🔍 [DEBUG FOV] 2. FOV Joueur Actuel: " .. tostring(startFOV))

	local endPart = Workspace:FindFirstChild(END_TP_PART_NAME)
	if not endPart then warn("⚠️ ERREUR : Part d'arrivée introuvable !") return end

	-- 2. CRÉATION DES CLONES
	character.Archivable = true

	-- Clone A
	local stuntMan = character:Clone() 
	stuntMan.Name = "Lucas_Actor"
	setupClone(stuntMan)

	-- Clone B (Dummy)
	local calcDummy = character:Clone()
	calcDummy.Name = "Calc_Dummy"
	setupClone(calcDummy)

	character.Archivable = false 

	for _, part in pairs(stuntMan:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("Decal") then
			if part.Name ~= "HumanoidRootPart" then part.Transparency = 0 end
		end
	end

	stuntMan.Parent = Workspace
	stuntMan:PivotTo(startPlayerCFrame)

	calcDummy.Parent = Workspace 
	calcDummy:PivotTo(startPlayerCFrame) 

	-- 3. CACHER LE VRAI JOUEUR
	GameState:SetCutscene(true)
	setControls(false)
	toggleRealCharacter(false) 
	setRealCharVisible(false)  
	rootPart.CFrame = endPart.CFrame + Vector3.new(0, 3, 0)

	-- 4. FLASH CALCUL (AVEC LOGS)
	print("🔍 [DEBUG FOV] 3. Préparation Flash...")

	-- On force le mode scriptable pour que Moon puisse écrire dans la caméra
	camera.CameraType = Enum.CameraType.Scriptable

	local calcCutscene = Moon2Cutscene.new(animFile) 
	calcCutscene:replace(LUCAS_INDEX, calcDummy) 

	calcCutscene:play()

	-- On attend 3 frames pour être sûr que Moon a appliqué ses valeurs
	RunService.RenderStepped:Wait() 
	RunService.RenderStepped:Wait()
	RunService.RenderStepped:Wait()

	-- LECTURE DES VALEURS PENDANT LE FLASH
	local targetCamCFrame = camera.CFrame
	local targetFOV = camera.FieldOfView 
	local targetCharCFrame = calcDummy.HumanoidRootPart.CFrame 
	local targetPosition = targetCharCFrame.Position

	print("🔍 [DEBUG FOV] 4. PENDANT LE FLASH -> Camera FOV: " .. tostring(targetFOV))

	calcCutscene:stop()
	calcCutscene = nil
	calcDummy:Destroy() 

	-- Reset Caméra pour la transition
	camera.CFrame = startCameraCFrame
	camera.FieldOfView = startFOV
	print("🔍 [DEBUG FOV] 5. Reset FOV avant transition: " .. tostring(camera.FieldOfView))

	-- 5. CALCULS VITESSE
	local distance = (targetPosition - startPlayerCFrame.Position).Magnitude
	local requiredSpeed = distance / TRANSITION_DURATION 
	local animSpeedRatio = requiredSpeed / BASE_SPRINT_SPEED
	if animSpeedRatio < 0.1 then animSpeedRatio = 1 end

	-- 6. PHASE 1 : COURSE
	local stuntRoot = stuntMan:WaitForChild("HumanoidRootPart")
	local stuntHumanoid = stuntMan:WaitForChild("Humanoid")

	local stuntAnim = Instance.new("Animation")
	stuntAnim.AnimationId = SPRINT_ID
	local stuntTrack = stuntHumanoid:LoadAnimation(stuntAnim)
	stuntTrack.Priority = Enum.AnimationPriority.Action4
	stuntTrack.Looped = true
	stuntTrack:Play()
	stuntTrack:AdjustSpeed(animSpeedRatio)

	local tweenStyle = TweenInfo.new(TRANSITION_DURATION, Enum.EasingStyle.Linear)

	print("🔍 [DEBUG FOV] 6. Lancement Tween vers FOV Cible: " .. tostring(targetFOV))

	local cameraGoals = {CFrame = targetCamCFrame, FieldOfView = targetFOV}

	local camTween = TweenService:Create(camera, tweenStyle, cameraGoals)
	local stuntTween = TweenService:Create(stuntRoot, tweenStyle, {CFrame = targetCharCFrame})

	local lookAtPos = Vector3.new(targetPosition.X, startPlayerCFrame.Position.Y, targetPosition.Z)
	stuntRoot.CFrame = CFrame.lookAt(startPlayerCFrame.Position, lookAtPos)

	camTween:Play()
	stuntTween:Play()

	stuntTween.Completed:Wait()

	print("🔍 [DEBUG FOV] 7. Fin Transition. FOV Actuel: " .. tostring(camera.FieldOfView))

	-- 7. PHASE 2 : CINÉMATIQUE
	stuntTrack:Stop(0) 

	local finalCutscene = Moon2Cutscene.new(animFile)
	finalCutscene:replace(LUCAS_INDEX, stuntMan)

	finalCutscene:play()

	-- Petit check juste après le play
	RunService.RenderStepped:Wait()
	print("🔍 [DEBUG FOV] 8. Cinématique lancée. FOV: " .. tostring(camera.FieldOfView))

	finalCutscene:wait()

	print("🏁 Fin Scène.")

	-- 8. NETTOYAGE
	pcall(function() finalCutscene:stop() end)
	finalCutscene = nil

	local ghostName = animFile.Name .. "_MoonAnimator"
	local ghost = Workspace:FindFirstChild(ghostName)
	if ghost then ghost:Destroy() end

	-- 9. RETOUR
	stuntMan:Destroy()

	rootPart.CFrame = endPart.CFrame + Vector3.new(0, 3, 0)
	rootPart.Velocity = Vector3.new(0,0,0)

	toggleRealCharacter(true)
	setRealCharVisible(true)

	nuclearCameraReset(endPart)

	setControls(true)
	GameState:SetCutscene(false)
	GameState:SetPhase(2)
	isPlaying = false

	print("✅ SUCCÈS TOTAL.")
end

triggerPart.Touched:Connect(function(hit)
	if hit.Parent == character and not isPlaying then
		playCinematic()
	end
end)