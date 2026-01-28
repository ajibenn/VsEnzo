--[[
    Autopsy (LocalScript)
    Path: StarterPlayer → StarterCharacterScripts
    Parent: StarterCharacterScripts
    Properties:
        Disabled: false
    Exported: 2026-01-28 16:22:15
]]
-- SCRIPT : Autopsy (Mouchard de mort)
local char = script.Parent
local humanoid = char:WaitForChild("Humanoid")
local root = char:WaitForChild("HumanoidRootPart")

humanoid.Died:Connect(function()
	print("💀 MORT DÉTECTÉE !")
	print("📍 Altitude (Y) : " .. root.Position.Y)

	-- 1. Vérification de la limite du monde
	if root.Position.Y < workspace.FallenPartsDestroyHeight + 50 then
		warn("📉 CAUSE : Tu es tombé trop bas dans le vide (FallenPartsDestroyHeight) !")
		return
	end

	-- 2. Vérification des joints (Le "Crunch")
	if not char:FindFirstChild("Head") or not char.Head:FindFirstChild("Neck") then
		warn("🦴 CAUSE : Dislocation physique (Crunch). Le perso a été écrasé ou tiré trop fort.")
		return
	end

	print("❓ CAUSE : Dégâts inconnus ou script tiers.")
end)