--[[
    BossManager (Script)
    Path: ServerStorage → Enzo
    Parent: Enzo
    Properties:
        Disabled: false
        RunContext: Enum.RunContext.Legacy
    Exported: 2026-01-28 16:22:15
]]
-- SCRIPT PRINCIPAL : Boss Manager
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BOSS = script.Parent

print("🔵 Manager: Script Démarré.")

local HUMANOID = BOSS:WaitForChild("Humanoid")
if not HUMANOID then warn("🔴 ERREUR: Humanoid manquant."); return end

local rootPart = BOSS:FindFirstChild("HumanoidRootPart")
if rootPart then BOSS.PrimaryPart = rootPart else warn("🔴 ERREUR: RootPart manquant."); return end

local Phase1Module = ServerStorage:WaitForChild("Phase1Module")
local BALLOON_MODEL = ReplicatedStorage:WaitForChild("foot", 10)
local FLAG_MODEL = ReplicatedStorage:WaitForChild("Portugalflag", 10)

if not Phase1Module or not BALLOON_MODEL or not FLAG_MODEL then
	warn("🔴 ERREUR: Modèles ou Module manquants !")
	return
end
local Phase1Logic = require(Phase1Module)
print("🔵 Manager: Module Chargé.")

-- CHARGEMENT ANIMATIONS
local walkTrack = Phase1Logic.SetupWalkAnimation(HUMANOID) 
local spellTrack = Phase1Logic.SetupSpellAnimation(HUMANOID) 
local preparationTrack, dashTrack = Phase1Logic.SetupDashAnimations(HUMANOID)
local aoeTrack = Phase1Logic.SetupAoeAnimation(HUMANOID) 
local idleTrack = Phase1Logic.SetupIdleAnimation(HUMANOID) 

-- Connexion de la logique (Vide, mais on garde pour compatibilité)
Phase1Logic.ConnectAnimationLogic(HUMANOID, walkTrack, idleTrack)

print("🔵 Manager: Prêt.")

local function getTargetPlayer()
	local allPlayers = Players:GetPlayers()
	for _, player in ipairs(allPlayers) do
		if player.Character and player.Character.PrimaryPart then
			return player
		end
	end
	return nil
end

while true do
	local targetPlayer = getTargetPlayer()

	if targetPlayer then
		Phase1Logic.StartChase(BOSS, targetPlayer, spellTrack, walkTrack, preparationTrack, dashTrack, aoeTrack, idleTrack) 
	end

	task.wait(Phase1Logic.UPDATE_RATE)
end