--[[
    GameStateManager (ModuleScript)
    Path: ReplicatedStorage
    Parent: ReplicatedStorage
    Exported: 2026-01-28 16:22:14
]]
-- MODULE SCRIPT : GameStateManager (ReplicatedStorage)
local GameStateManager = {}

-- Création d'un signal pour prévenir les scripts
-- C'est grâce à ça que TrickRamp et SwingBar savent qu'ils doivent se réveiller !
local PhaseChangedEvent = Instance.new("BindableEvent")
GameStateManager.PhaseChanged = PhaseChangedEvent.Event 

-- États du jeu par défaut
GameStateManager.IsCutscene = false
GameStateManager.CurrentPhase = 1 

-- GESTION CINÉMATIQUE (Bloque les mouvements)
function GameStateManager:SetCutscene(value)
	self.IsCutscene = value
	print("🎬 GameState : Mode Cinématique = " .. tostring(value))
end

function GameStateManager:GetCutscene()
	return self.IsCutscene
end

-- GESTION DES PHASES (Active les mécaniques spéciales)
function GameStateManager:SetPhase(phaseNumber)
	-- On ne change que si c'est un nouveau numéro
	if self.CurrentPhase ~= phaseNumber then
		self.CurrentPhase = phaseNumber
		print("🌊 GameState : CHANGEMENT DE PHASE -> " .. tostring(phaseNumber))

		-- 🔔 DING DONG ! On prévient tous les scripts abonnés
		PhaseChangedEvent:Fire(phaseNumber)
	end
end

function GameStateManager:GetPhase()
	return self.CurrentPhase
end

return GameStateManager