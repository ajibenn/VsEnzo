--[[
    LedgeJumpMechanic (LocalScript)
    Path: StarterPlayer → StarterCharacterScripts
    Parent: StarterCharacterScripts
    Properties:
        Disabled: false
    Exported: 2026-01-28 16:22:15
]]
-- LOCAL SCRIPT : LedgeJumpMechanic (V11 - HEAD SCAN LOGIC)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(ReplicatedStorage:WaitForChild("GameStateManager"))

local player = Players.LocalPlayer
local character = script.Parent or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- === CONFIGURATION ===
local DEFAULT_BOOST_AVANT = 100 
local DEFAULT_BOOST_HAUT = 90  
local DEFAULT_MOMENTUM = false
local DEFAULT_SUSTAIN = false 

local VITESSE_MINIMALE = 20
local COOLDOWN = 0.8 

-- 📡 SCANNER
local SCAN_DISTANCES = {5, 10, 16} 
local SCORE_POUR_ACTIVER = 2 
local PROFONDEUR_SCAN = 30 -- On scanne bien profond
local HAUTEUR_YEUX = 3.5 -- Le rayon part de cette hauteur (Tête)
-- ===================

local isPhase2MechanicActive = false
GameState.PhaseChanged:Connect(function(newPhase) isPhase2MechanicActive = (newPhase == 2) end)
if GameState:GetPhase() == 2 then isPhase2MechanicActive = true end

local canBoost = true
local sustainVelocity = nil
local landingConnection = nil

local function cleanupSustain()
	if sustainVelocity then sustainVelocity:Destroy(); sustainVelocity = nil end
	if landingConnection then landingConnection:Disconnect(); landingConnection = nil end
end

humanoid.StateChanged:Connect(function(old, new)
	if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
		cleanupSustain()
	end
end)

humanoid.Jumping:Connect(function(isJumping)
	if not isPhase2MechanicActive then return end
	if GameState:GetCutscene() then return end
	if not isJumping or not canBoost then return end
	if humanoid.FloorMaterial == Enum.Material.Air then return end

	local currentVelocity = rootPart.AssemblyLinearVelocity * Vector3.new(1,0,1)
	local speed = currentVelocity.Magnitude

	if speed < VITESSE_MINIMALE then return end

	local directionAvant = rootPart.CFrame.LookVector

	-- SCANNER "HEAD-HIGH" (TÊTE HAUTE)
	local videCount = 0 
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {character}
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	for _, distance in ipairs(SCAN_DISTANCES) do
		-- 1. On calcule le point cible devant, MAIS EN HAUTEUR (Tête)
		-- Cela évite d'être "dans le sol" ou de taper une petite marche
		local originHigh = rootPart.Position + (directionAvant * distance) + Vector3.new(0, HAUTEUR_YEUX, 0)

		-- 2. SÉCURITÉ MUR (Front Check)
		-- On vérifie d'abord s'il n'y a pas un mur entre nous et le point de saut
		-- On tire un rayon de la tête vers le point cible en l'air
		local wallCheckDir = originHigh - (rootPart.Position + Vector3.new(0, HAUTEUR_YEUX, 0))
		local wallHit = Workspace:Raycast(rootPart.Position + Vector3.new(0, HAUTEUR_YEUX, 0), wallCheckDir, rayParams)

		if wallHit then
			-- ❌ On a touché un mur devant nous, ce n'est pas un vide, c'est un obstacle !
			-- On ne compte pas de point.
		else
			-- ✅ C'est libre devant, maintenant on regarde EN BAS (Down Check)
			local downDir = Vector3.new(0, -PROFONDEUR_SCAN, 0)
			local groundHit = Workspace:Raycast(originHigh, downDir, rayParams)

			if not groundHit then 
				-- Le rayon vers le bas n'a RIEN touché -> C'est du vide !
				videCount = videCount + 1 
			end
		end
	end

	-- ⚡ ACTIVATION DU SAUT
	if videCount >= SCORE_POUR_ACTIVER then
		canBoost = false
		cleanupSustain() 

		local power = character:GetAttribute("LedgeJumpPower") or DEFAULT_BOOST_AVANT
		local height = character:GetAttribute("LedgeJumpHeight") or DEFAULT_BOOST_HAUT
		local useMomentum = character:GetAttribute("LedgeJumpMomentum")
		if useMomentum == nil then useMomentum = DEFAULT_MOMENTUM end
		local useSustain = character:GetAttribute("LedgeJumpSustain")
		if useSustain == nil then useSustain = DEFAULT_SUSTAIN end

		print("⚡ SAUT DE CORNICHE ! (Head Scan)")

		rootPart.CFrame = rootPart.CFrame + Vector3.new(0, 1, 0)

		local mass = 0
		for _, part in pairs(character:GetDescendants()) do
			if part:IsA("BasePart") then mass = mass + part:GetMass() end
		end

		local finalForce = power
		if useMomentum then finalForce = finalForce + (speed * 0.8) end

		local vectorForce = directionAvant * (finalForce * mass) + Vector3.new(0, height * mass, 0)
		rootPart:ApplyImpulse(vectorForce)

		if useSustain then
			local targetSpeed = speed + (power / 5) 
			if useMomentum then targetSpeed = targetSpeed + (speed * 0.2) end

			sustainVelocity = Instance.new("BodyVelocity")
			sustainVelocity.Name = "LedgeSustain"
			sustainVelocity.Velocity = directionAvant * targetSpeed
			sustainVelocity.MaxForce = Vector3.new(100000, 0, 100000) 
			sustainVelocity.P = 20000
			sustainVelocity.Parent = rootPart

			task.delay(3, cleanupSustain)
		end

		local sound = Instance.new("Sound", rootPart)
		sound.SoundId = "rbxassetid://906161822"
		sound.Volume = 1.5; sound:Play(); Debris:AddItem(sound, 1.5)

		task.delay(COOLDOWN, function() canBoost = true end)
	end
end)