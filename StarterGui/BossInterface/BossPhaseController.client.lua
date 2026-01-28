--[[
    BossPhaseController (LocalScript)
    Path: StarterGui → BossInterface
    Parent: BossInterface
    Properties:
        Disabled: false
    Exported: 2026-01-28 16:22:15
]]
-- LOCAL SCRIPT : BossPhaseController (FIX MOUVEMENT & UI)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService") -- Pour couper la camera loop

local player = Players.LocalPlayer
local gui = script.Parent
local container = gui:WaitForChild("HealthContainer")
local fill = container:WaitForChild("Fill")
local nameLabel = container:WaitForChild("BossName")

local BossEvent = ReplicatedStorage:WaitForChild("StartBossEvent")
local PhaseEvent = ReplicatedStorage:WaitForChild("PhaseTransitionEvent")

local currentBossHumanoid = nil

-- 1. ANIMATION BARRE DE VIE
local function updateHealth()
	if currentBossHumanoid then
		local percent = math.clamp(currentBossHumanoid.Health / currentBossHumanoid.MaxHealth, 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Size = UDim2.new(percent, 0, 1, 0)}):Play()
		local color = Color3.fromRGB(255, 0, 0):Lerp(Color3.fromRGB(85, 255, 0), percent)
		TweenService:Create(fill, TweenInfo.new(0.3), {BackgroundColor3 = color}):Play()
	end
end

-- 2. DÉMARRAGE COMBAT
BossEvent.OnClientEvent:Connect(function()
	local boss = Workspace:WaitForChild("Enzo", 10)
	if boss then
		local hum = boss:WaitForChild("Humanoid", 5)
		if hum then
			currentBossHumanoid = hum
			gui.Enabled = true
			fill.Size = UDim2.new(1,0,1,0)
			nameLabel.Text = "ENZO"
			hum.HealthChanged:Connect(updateHealth)
		end
	end
end)

-- 3. FIN DE PHASE (PROTOCOL DE DÉSINTOXICATION)
PhaseEvent.OnClientEvent:Connect(function(phaseNumber)
	if phaseNumber == 1 then
		print("🛑 Fin Phase 1 : Nettoyage complet...")

		-- A. Cacher la barre de vie du Boss
		gui.Enabled = false

		-- B. Désactiver le Script d'Arme (Logique)
		local script1 = player:WaitForChild("PlayerScripts"):FindFirstChild("ClientWeaponsScript")
		local script2 = player:WaitForChild("PlayerGui"):FindFirstChild("ClientWeaponsScript")
		if script1 then script1.Disabled = true end
		if script2 then script2.Disabled = true end

		-- C. CACHER LE VISEUR (WeaponsSystemGui) -> C'est ça qui affichait ton viseur !
		local weaponGui = player:WaitForChild("PlayerGui"):FindFirstChild("WeaponsSystemGui")
		if weaponGui then
			weaponGui.Enabled = false
			print("🎯 Viseur désactivé.")
		end

		-- D. RÉTABLIR LE PERSONNAGE (Fix direction bloquée)
		local char = player.Character
		if char then
			local hum = char:FindFirstChild("Humanoid")
			if hum then 
				-- C'est LA ligne magique qui te rend ta liberté de mouvement :
				hum.AutoRotate = true 
				hum.PlatformStand = false

				-- On remet la caméra sur le joueur
				Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
				Workspace.CurrentCamera.CameraSubject = hum

				-- On arrête l'animation de tenue du pistolet
				for _, track in pairs(hum:GetPlayingAnimationTracks()) do
					track:Stop()
				end
			end
		end

		print("✅ Joueur réinitialisé : Liberté de mouvement rendue.")
	end
end)