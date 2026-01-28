--[[
    Debug_Phase2_Loader (Script)
    Path: ServerScriptService
    Parent: ServerScriptService
    Properties:
        Disabled: false
        RunContext: Enum.RunContext.Legacy
    Exported: 2026-01-28 16:22:14
]]
-- AJOUTE ÇA TOUT EN HAUT DU SCRIPT
local Workspace = game:GetService("Workspace")

-- On colle une étiquette sur le jeu pour dire "ON EST EN TEST !"
if script.Disabled == false then
	Workspace:SetAttribute("Phase2DebugActive", true)
end
-- SERVER SCRIPT : Debug_Phase2_Loader (V2 - OPTION TP)
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ==========================================
-- 🛑 CONFIGURATION DEBUG
-- ==========================================
local ACTIVER_DEBUG_PHASE_2 = true  -- Mettre 'false' pour jouer le jeu normal (Boss Phase 1)
local TELEPORTER_JOUEUR = false      -- Mettre 'false' pour ne pas être TP au début du parcours

if not ACTIVER_DEBUG_PHASE_2 then 
	script.Disabled = true 
	return 
end

print("🧪 MODE DEBUG PHASE 2 ACTIVÉ")

-- 1. NETTOYAGE (On vire la Phase 1 si elle traîne)
local phase1Map = Workspace:FindFirstChild("Phase1")
if phase1Map then phase1Map:Destroy() end

local bossEnzo = Workspace:FindFirstChild("Enzo")
if bossEnzo then bossEnzo:Destroy() end

-- 2. CHARGEMENT DE LA MAP PHASE 2
local mapName = "Phase2MapV1"
local storedMap = ServerStorage:FindFirstChild(mapName)
local liveMap = Workspace:FindFirstChild(mapName)

if not liveMap and storedMap then
	liveMap = storedMap:Clone()
	liveMap.Parent = Workspace
	print("🗺️ Map Phase 2 chargée depuis ServerStorage.")
else
	if liveMap then
		print("⚠️ Map déjà présente dans le Workspace.")
	else
		warn("❌ ERREUR : La map '"..mapName.."' est introuvable dans ServerStorage !")
	end
end

-- 3. TÉLÉPORTATION DES JOUEURS
local function teleportPlayer(player)
	-- Si l'option est désactivée, on arrête ici
	if not TELEPORTER_JOUEUR then return end

	local char = player.Character or player.CharacterAdded:Wait()
	local root = char:WaitForChild("HumanoidRootPart")

	-- On vérifie que la map est bien là
	if not liveMap then return end

	local startPoint = liveMap:FindFirstChild("StartPoint")

	if startPoint then
		task.wait(0.5) -- Petite pause pour être sûr que le perso est chargé
		root.CFrame = startPoint.CFrame + Vector3.new(0, 5, 0)
		print("🚀 Joueur téléporté au début du parcours !")
	else
		warn("❌ Pas de 'StartPoint' trouvé dans Phase2MapV1 ! Crée une part nommée StartPoint.")
	end
end

-- Gérer les joueurs déjà là + ceux qui arrivent
for _, p in ipairs(Players:GetPlayers()) do teleportPlayer(p) end
Players.PlayerAdded:Connect(teleportPlayer)

-- 4. MUSIQUE (PLACEHOLDER)
-- Ici, tu mettras le code pour lancer ta musique plus tard.