--[[
    GameManager (Script)
    Path: ServerScriptService
    Parent: ServerScriptService
    Properties:
        Disabled: false
        RunContext: Enum.RunContext.Legacy
    Exported: 2026-01-28 16:22:14
]]
-- SERVER SCRIPT : GameManager (Avec Gestion de Phase)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local BossEvent = ReplicatedStorage:WaitForChild("StartBossEvent")
local PhaseEvent = ReplicatedStorage:WaitForChild("PhaseTransitionEvent")
local SpawnPhase1 = Workspace:WaitForChild("Phase1") 
local BossSpawnPoint = Workspace:WaitForChild("BossSpawn") 

local BossTemplate = ServerStorage:WaitForChild("Enzo")
local GunTemplate = ServerStorage:WaitForChild("Pistol") 

local currentBoss = nil
local phase1Active = false

BossEvent.OnServerEvent:Connect(function(player)
	print("⚔️ MANAGER: Préparation du combat...")

	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")

	-- 1. TP JOUEUR
	if rootPart and SpawnPhase1 then
		rootPart.CFrame = SpawnPhase1.CFrame + Vector3.new(0, 3, 0)
	end

	-- 2. DONNER L'ARME
	if not character:FindFirstChild(GunTemplate.Name) then
		local newGun = GunTemplate:Clone()
		newGun.Parent = player.Backpack
		humanoid:EquipTool(newGun)
	end

	-- 3. SPAWN ENZO
	if not Workspace:FindFirstChild("Enzo") then
		currentBoss = BossTemplate:Clone()
		if BossSpawnPoint then
			currentBoss:PivotTo(BossSpawnPoint.CFrame)
		else
			currentBoss:PivotTo(SpawnPhase1.CFrame * CFrame.new(0,0,-40))
		end
		currentBoss.Parent = Workspace

		-- DÉMARRAGE SURVEILLANCE PHASE 1
		phase1Active = true
		task.spawn(function()
			monitorPhase1(currentBoss, player)
		end)
	end

	-- Dire au client d'afficher la barre de vie
	BossEvent:FireClient(player)
end)

-- FONCTION DE SURVEILLANCE PHASE 1
function monitorPhase1(bossModel, player)
	local humanoid = bossModel:WaitForChild("Humanoid")
	local maxHealth = humanoid.MaxHealth
	-- Seuil : 67% (donc il a perdu 33%)
	local threshold = maxHealth * 0.67 

	print("👀 MONITORING: Phase 1 finira à " .. threshold .. " PV.")

	while phase1Active and bossModel.Parent do
		task.wait(0.5)

		if humanoid.Health <= threshold then
			print("🚨 PHASE 1 TERMINÉE ! (PV: " .. humanoid.Health .. ")")
			phase1Active = false

			-- 1. Prévenir le Client (Barre, Caméra)
			PhaseEvent:FireClient(player, 1) -- "1" pour dire fin de phase 1

			-- 2. Retirer l'arme du joueur
			local char = player.Character
			if char then
				local weapon = char:FindFirstChild("Pistol") or player.Backpack:FindFirstChild("Pistol")
				if weapon then 
					weapon:Destroy() 
					print("🔫 Arme retirée.")
				end
			end

			-- 3. Retirer le Boss (Pour laisser place à la cinématique)
			bossModel:Destroy()
			print("👋 Boss retiré du plateau.")

			break
		end
	end
end