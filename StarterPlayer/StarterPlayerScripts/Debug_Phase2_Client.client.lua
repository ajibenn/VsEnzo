--[[
    Debug_Phase2_Client (LocalScript)
    Path: StarterPlayer → StarterPlayerScripts
    Parent: StarterPlayerScripts
    Properties:
        Disabled: false
    Exported: 2026-01-28 16:22:15
]]
-- LOCAL SCRIPT : Debug_Phase2_Client
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameState = require(ReplicatedStorage:WaitForChild("GameStateManager"))

local ACTIVER_DEBUG = true 

if not ACTIVER_DEBUG then 
	script.Disabled = true 
	return 
end

task.wait(2) -- On laisse le temps à la map de charger

print("🧪 DEBUG : Simulation Transition Phase 2...")

-- 1. On s'assure qu'on n'est pas en cinématique
GameState:SetCutscene(false)

-- 2. LE SIGNAL MAGIQUE
-- En mettant la phase à 2, le GameStateManager va crier à tous les scripts : "ACTIVEZ-VOUS !"
GameState:SetPhase(2) 

print("✅ DEBUG : Phase 2 Forcée. Mécaniques devraient être actives.")