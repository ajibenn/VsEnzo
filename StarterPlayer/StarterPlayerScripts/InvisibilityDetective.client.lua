--[[
    InvisibilityDetective (LocalScript)
    Path: StarterPlayer → StarterPlayerScripts
    Parent: StarterPlayerScripts
    Properties:
        Disabled: true
    Exported: 2026-01-28 16:22:15
]]
-- LOCAL SCRIPT : RampVisualizer (DIAGNOSTIC)
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- CONFIGURATION
local SHOW_LASERS = true

local function DrawLaser(startPos, endPos, color)
	local distance = (endPos - startPos).Magnitude
	local p = Instance.new("Part")
	p.Name = "DEBUG_LASER"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.new(0.5, 0.5, distance)
	p.CFrame = CFrame.lookAt(startPos, endPos) * CFrame.new(0, 0, -distance/2)
	p.Parent = Workspace
	return p
end

-- Scan des rampes
task.wait(2) -- On attend que la map charge un peu
print("🕵️ VISUALIZER : Analyse de la zone problématique...")

local count = 0
for _, obj in pairs(Workspace:GetDescendants()) do
	if obj.Name == "Start" and obj:IsA("BasePart") then
		local folder = obj.Parent -- Le dossier de la rampe
		if folder then
			local winPart = folder:FindFirstChild("Win")

			if winPart then
				-- CAS 1 : Tout va bien, on dessine le chemin
				if SHOW_LASERS then
					DrawLaser(obj.Position, winPart.Position, Color3.new(0, 1, 0)) -- VERT = OK
				end
				count = count + 1
			else
				-- CAS 2 : PAS DE WIN TROUVÉ (C'est sûrement ça le bug ici)
				warn("🚨 ALERTE : La rampe '"..folder.Name.."' (Parent: "..folder.Parent.Name..") N'A PAS DE POINT 'Win' !")

				-- On met un gros cube rouge sur le Start pour te montrer laquelle bug
				local h = Instance.new("Highlight")
				h.FillColor = Color3.new(1, 0, 0)
				h.Parent = obj
			end
		end
	end
end

print("✅ VISUALIZER : " .. count .. " rampes valides trouvées.")