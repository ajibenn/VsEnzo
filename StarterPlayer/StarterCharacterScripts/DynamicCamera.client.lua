--[[
    DynamicCamera (LocalScript)
    Path: StarterPlayer → StarterCharacterScripts
    Parent: StarterCharacterScripts
    Properties:
        Disabled: false
    Exported: 2026-01-28 16:22:15
]]
-- LOCAL SCRIPT : DynamicCamera (V17 - SOFT FOV & SAFETY)
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameState = require(ReplicatedStorage:WaitForChild("GameStateManager"))

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- ==========================================
-- ⚙️ RÉGLAGES
-- ==========================================
-- TILT (Inclinaison caméra)
local WANT_LOOK_UP = 12 
local WANT_LOOK_DOWN = 20 
local SPEED_FOR_MAX_TILT = 2500 
local SMOOTHNESS = 0.05 

-- FOV (Effet Vitesse - DOUX)
local MAX_FOV_ADD = 10      -- Max 10 degrés de plus (c'est subtil mais suffisant)
local FOV_START_SPEED = 25  -- Commence à changer à partir de cette vitesse
local SPEED_FOR_MAX_FOV = 300 -- Vitesse à laquelle on atteint le FOV Max (plus c'est haut, plus c'est progressif)
local FOV_SMOOTHNESS = 0.05 

-- DISTANCE (Mode Libre)
local MIN_DISTANCE = 12    
local MAX_DISTANCE = 24    
local DISTANCE_START_SPEED = 10 

-- ==========================================
-- LOGIQUE
-- ==========================================
local currentTiltX = 0
local currentTiltZ = 0
local currentDistance = MIN_DISTANCE
local currentFovAdd = 0 

RunService:BindToRenderStep("DynamicCamera", Enum.RenderPriority.Camera.Value + 10, function(deltaTime)
	if humanoid.Health <= 0 then return end
	if GameState:GetCutscene() then return end

	local isCinematic = character:GetAttribute("CinematicActive") == true

	if isCinematic then
		currentTiltX = currentTiltX * 0.9 
		currentTiltZ = currentTiltZ * 0.9
		currentFovAdd = currentFovAdd * 0.9
		return 
	end

	local velocity = rootPart.AssemblyLinearVelocity
	local flatSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local vertSpeed = velocity.Y

	-- 1. TILT (AVEC CLAMP DE SÉCURITÉ V16)
	local targetTiltX = 0
	if math.abs(vertSpeed) < 5000 then
		local percent = math.clamp(math.abs(vertSpeed) / SPEED_FOR_MAX_TILT, 0, 1)
		if vertSpeed > 10 then
			targetTiltX = - (percent * WANT_LOOK_UP)
		elseif vertSpeed < -10 then
			targetTiltX = (percent * WANT_LOOK_DOWN)
		end
	end
	if humanoid.FloorMaterial ~= Enum.Material.Air then targetTiltX = 0 end

	currentTiltX = currentTiltX + (targetTiltX - currentTiltX) * SMOOTHNESS
	currentTiltX = math.clamp(currentTiltX, -WANT_LOOK_UP, WANT_LOOK_DOWN) -- Sécurité

	-- 2. ROLL
	local camRight = camera.CFrame.RightVector
	local moveRight = camRight:Dot(velocity.Unit)
	if flatSpeed < 5 then moveRight = 0 end
	local targetZ = -moveRight * 1.5
	currentTiltZ = currentTiltZ + (targetZ - currentTiltZ) * 0.1

	-- 3. FOV (SOFT & PROGRESSIF)
	local targetFovAdd = 0

	if flatSpeed > FOV_START_SPEED then
		-- Calcul de la plage : de 25 à 300 de vitesse
		local range = SPEED_FOR_MAX_FOV - FOV_START_SPEED
		local progress = flatSpeed - FOV_START_SPEED

		-- Ratio linéaire simple (0 à 1)
		local ratio = math.clamp(progress / range, 0, 1)

		-- Optionnel : Tu peux utiliser math.sqrt(ratio) pour que ça monte vite au début puis ralentisse
		-- Mais on reste sur du linéaire étiré pour l'instant, c'est le plus stable.
		targetFovAdd = ratio * MAX_FOV_ADD
	end

	-- Lissage très doux
	currentFovAdd = currentFovAdd + (targetFovAdd - currentFovAdd) * FOV_SMOOTHNESS

	-- On limite le FOV total à 110 pour éviter le "Warp Speed" moche
	local baseFov = camera.FieldOfView - currentFovAdd -- On tente de deviner la base
	local finalFov = math.min(baseFov + currentFovAdd, 110)

	camera.FieldOfView = finalFov

	-- 4. DISTANCE
	if not isCinematic then
		local targetDist = MIN_DISTANCE
		if flatSpeed > DISTANCE_START_SPEED then
			local ratio = math.clamp((flatSpeed - DISTANCE_START_SPEED) / 80, 0, 1)
			targetDist = MIN_DISTANCE + (ratio * (MAX_DISTANCE - MIN_DISTANCE))
		end

		currentDistance = currentDistance + (targetDist - currentDistance) * 0.05
		player.CameraMinZoomDistance = currentDistance
		player.CameraMaxZoomDistance = currentDistance
	end

	-- 5. APPLICATION
	camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(currentTiltX), 0, math.rad(currentTiltZ))
end)