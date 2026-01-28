--[[
    SkydiveController (LocalScript)
    Path: StarterPlayer → StarterCharacterScripts
    Parent: StarterCharacterScripts
    Properties:
        Disabled: false
    Exported: 2026-01-28 16:22:15
]]
-- LOCAL SCRIPT : SkydiveController (V53 - CUSTOM SPEED ATTRIBUTE)
-- PLACEMENT : StarterCharacterScripts

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local character = script.Parent
local rootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")
local camera = Workspace.CurrentCamera

-- ============================================================================
-- ⚙️ RÉGLAGES PAR DÉFAUT
-- ============================================================================
local SKYDIVE_ANIM_ID = "rbxassetid://109859398939771"

local DEFAULT_FALL_SPEED = -120 -- Vitesse par défaut si pas d'attribut
local MOVE_SPEED = 70        
local MANEUVERABILITY = 0.08 

-- INCLINAISON
local MAX_TILT_ROLL = 45     
local MAX_TILT_PITCH = 40 

local SCRIPT_LOCO_NAME = "AdvancedLocomotion"
local SCRIPT_CAM_NAME = "DynamicCamera"

-- VARIABLES D'ÉTAT
local isSkydiving = false
local skydiveTrack = nil
local bodyVelocity = nil
local bodyGyro = nil
local currentMoveVector = Vector3.zero 
local currentFallSpeed = DEFAULT_FALL_SPEED -- Stocke la vitesse de la chute actuelle

-- 🧭 RÉFÉRENCES
local refLookVector = Vector3.new(0, 0, -1)
local refRightVector = Vector3.new(1, 0, 0)

-- ============================================================================
-- 🛠️ FONCTIONS
-- ============================================================================

local function toggleNormalScripts(active)
	local loco = character:FindFirstChild(SCRIPT_LOCO_NAME)
	local cam = character:FindFirstChild(SCRIPT_CAM_NAME)
	if loco then loco.Disabled = not active end
	if cam then cam.Disabled = not active end
end

local function stopAllAnimations()
	if skydiveTrack then skydiveTrack:Stop(0) end
	for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
		track:Stop(0) 
	end
end

local function startSkydive(triggerPart)
	if isSkydiving or humanoid.Health <= 0 then return end
	isSkydiving = true
	print("🪂 SKYDIVE V53 : DÉMARRAGE")

	-- 🆕 RÉCUPÉRATION DE LA VITESSE PERSONNALISÉE
	-- On regarde si le trigger a un attribut "FallSpeed", sinon on prend la défaut
	local customSpeed = triggerPart:GetAttribute("FallSpeed")
	if customSpeed then
		currentFallSpeed = -math.abs(customSpeed) -- On force le négatif pour que ça descende
	else
		currentFallSpeed = DEFAULT_FALL_SPEED
	end

	-- 🛡️ SÉCURITÉ 1 : MATHÉMATIQUES
	local look = triggerPart.CFrame.LookVector
	if math.abs(look.X) < 0.001 and math.abs(look.Z) < 0.001 then
		refLookVector = Vector3.new(0, 0, -1) 
	else
		refLookVector = Vector3.new(look.X, 0, look.Z).Unit
	end
	refRightVector = triggerPart.CFrame.RightVector

	-- 🛡️ SÉCURITÉ 2 : PHYSIQUE DU TRIGGER
	triggerPart.CanCollide = false

	-- 🛡️ SÉCURITÉ 3 : TEMPO
	RunService.Heartbeat:Wait()

	-- 1. DÉSACTIVATION
	toggleNormalScripts(false)

	-- 2. RESET PERSO
	stopAllAnimations()
	humanoid.PlatformStand = true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

	rootPart.AssemblyLinearVelocity = Vector3.zero

	-- 3. ORIENTATION INITIALE
	rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + refLookVector)

	-- 4. ANIMATION
	local anim = Instance.new("Animation")
	anim.AnimationId = SKYDIVE_ANIM_ID
	skydiveTrack = humanoid:LoadAnimation(anim)
	skydiveTrack.Priority = Enum.AnimationPriority.Action4
	skydiveTrack:Play(0.2) 

	-- 5. PHYSIQUE
	bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
	bodyVelocity.Velocity = Vector3.new(0, currentFallSpeed, 0) -- Utilise la vitesse variable
	bodyVelocity.Parent = rootPart

	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(500000, 500000, 500000)
	bodyGyro.D = 100  
	bodyGyro.P = 10000 
	bodyGyro.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + refLookVector)
	bodyGyro.Parent = rootPart

	-- 6. CAMÉRA
	camera.CameraType = Enum.CameraType.Scriptable
end

local function stopSkydive()
	if not isSkydiving then return end
	isSkydiving = false
	print("🪂 SKYDIVE : ARRÊT NET")

	if bodyVelocity then bodyVelocity:Destroy() end
	if bodyGyro then bodyGyro:Destroy() end

	stopAllAnimations()
	humanoid.PlatformStand = false

	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)

	task.wait() 

	camera.CameraType = Enum.CameraType.Custom
	toggleNormalScripts(true)
end

-- ============================================================================
-- 🎮 BOUCLE PHYSIQUE
-- ============================================================================

RunService.RenderStepped:Connect(function(dt)
	if not isSkydiving then return end
	if not rootPart or not rootPart.Parent then return end

	local inputDir = Vector3.zero

	-- Clavier
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then inputDir += Vector3.new(0, 1, 0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then inputDir -= Vector3.new(0, 1, 0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then inputDir -= Vector3.new(1, 0, 0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then inputDir += Vector3.new(1, 0, 0) end

	-- Manette
	local gamepadState = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
	for _, state in pairs(gamepadState) do
		if state.KeyCode == Enum.KeyCode.Thumbstick1 then
			if state.Position.Magnitude > 0.15 then
				inputDir = Vector3.new(state.Position.X, state.Position.Y, 0)
			end
		end
	end

	currentMoveVector = currentMoveVector:Lerp(inputDir, MANEUVERABILITY)

	local sideMove = refRightVector * (currentMoveVector.X) 
	local fwdMove = refLookVector * currentMoveVector.Y
	local move3D = fwdMove + sideMove

	if bodyVelocity then
		bodyVelocity.Velocity = Vector3.new(
			move3D.X * MOVE_SPEED, 
			currentFallSpeed, -- Mise à jour constante avec la vitesse choisie
			move3D.Z * MOVE_SPEED
		)
	end

	if bodyGyro then
		local baseCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + refLookVector)
		local roll = math.rad(-currentMoveVector.X * MAX_TILT_ROLL) 
		local pitch = math.rad(-currentMoveVector.Y * MAX_TILT_PITCH)
		bodyGyro.CFrame = baseCFrame * CFrame.Angles(pitch, 0, roll)
	end

	local camPos = rootPart.Position + Vector3.new(0, 35, 0)

	if (camPos - rootPart.Position).Magnitude > 0 then
		camera.CFrame = CFrame.lookAt(camPos, rootPart.Position, refLookVector)
	end
end)

-- ============================================================================
-- 📡 DÉTECTION
-- ============================================================================
rootPart.Touched:Connect(function(hit)
	if hit.Name == "SkydiveStart" and not isSkydiving then
		startSkydive(hit)
	elseif hit.Name == "SkydiveEnd" then
		stopSkydive()
	end
end)