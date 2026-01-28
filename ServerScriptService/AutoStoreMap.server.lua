--[[
    AutoStoreMap (Script)
    Path: ServerScriptService
    Parent: ServerScriptService
    Properties:
        Disabled: false
        RunContext: Enum.RunContext.Legacy
    Exported: 2026-01-28 16:22:14
]]
-- SCRIPT : AutoStoreMap (CORRIGÉ ANTI-BUG)
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- Le nom exact de ton dossier map
local mapName = "Phase2MapV1"

-- 🛑 LA PAUSE CAFÉ (Crucial pour éviter le conflit)
-- On attend 0.1s pour laisser le temps au script Debug de se lancer s'il existe
task.wait(0.1) 

-- VERIFICATION DU MODE DEBUG
if Workspace:GetAttribute("Phase2DebugActive") == true then
	print("🛑 AutoStore : Mode Debug détecté ! Je ne range pas la map.")
	return -- On arrête le script ici, on ne touche à rien
end

-- LA SUITE NORMALE...
local map = Workspace:FindFirstChild(mapName)

if map then
	print("📦 Rangement automatique de la map " .. mapName .. " dans ServerStorage...")
	map.Parent = ServerStorage
else
	-- On ne met pas de warn ici, car si elle est déjà rangée c'est normal
	-- print("ℹ️ Map introuvable ou déjà rangée.")
end