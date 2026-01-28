--[[
    Script (Script)
    Path: ReplicatedStorage → Frite
    Parent: Frite
    Properties:
        Disabled: false
        RunContext: Enum.RunContext.Legacy
    Exported: 2026-01-28 16:22:14
]]
-- Script serveur pour faire mourir le joueur en touchant une frite
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

-- Fonction quand un objet touche une frite
local function onFriteTouched(frite, hit)
	local character = hit.Parent
	if character and character:FindFirstChild("Humanoid") then
		local humanoid = character.Humanoid
		humanoid.Health = 0 -- tue le joueur
	end
end

-- Vérifie toutes les frites dans Workspace et connecte l'événement
local function monitorFrite(frite)
	if frite:IsA("BasePart") then
		frite.Touched:Connect(function(hit)
			onFriteTouched(frite, hit)
		end)
	end
end

-- Ajout des frites existantes dans Workspace
for _, frite in pairs(Workspace:GetChildren()) do
	if frite.Name == "Frite" then
		monitorFrite(frite)
	end
end

-- Surveille les nouvelles frites qui apparaissent
Workspace.ChildAdded:Connect(function(child)
	if child.Name == "Frite" then
		monitorFrite(child)
	end
end)
