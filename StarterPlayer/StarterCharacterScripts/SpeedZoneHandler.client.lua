--[[
    SpeedZoneHandler (LocalScript)
    Path: StarterPlayer → StarterCharacterScripts
    Parent: StarterCharacterScripts
    Properties:
        Disabled: false
    Exported: 2026-01-28 16:22:15
]]
-- LOCAL SCRIPT : SmartSpeedGate (V5 - HÉRITAGE & SUSTAIN)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

local GATES_FOLDER_NAME = "SpeedGates"
local gatesFolder = Workspace:WaitForChild(GATES_FOLDER_NAME, 5)

if not gatesFolder then return end

-- === VALEURS PAR DÉFAUT (Uniquement pour le tout début) ===
local DEFAULTS = {
	Walk = 16,
	Sprint = 38,
	JumpPower = 100,
	JumpHeight = 90,
	Momentum = false, -- Le boost explosif au départ
	Sustain = false   -- (NOUVEAU) Garder la vitesse tout le long du vol
}

-- 📚 L'HISTORIQUE
local settingsStack = {
	table.clone(DEFAULTS)
}

local debounceList = {}

-- Applique les valeurs sur le personnage
local function applySettings(data)
	character:SetAttribute("BaseWalkSpeed", data.Walk)
	character:SetAttribute("BaseSprintSpeed", data.Sprint)

	character:SetAttribute("LedgeJumpPower", data.JumpPower)
	character:SetAttribute("LedgeJumpHeight", data.JumpHeight)
	character:SetAttribute("LedgeJumpMomentum", data.Momentum)
	character:SetAttribute("LedgeJumpSustain", data.Sustain) -- NOUVEAU

	-- print("🚀 [GATE] Applied. Walk:", data.Walk, "Sustain:", data.Sustain)
end

local function onGateTouched(hit, gate)
	if not rootPart then return end
	if not hit:IsDescendantOf(character) then return end

	if debounceList[gate] and (tick() - debounceList[gate] < 0.5) then return end
	debounceList[gate] = tick()

	local playerVelocity = rootPart.AssemblyLinearVelocity
	local gateDirection = gate.CFrame.LookVector
	local dotProduct = playerVelocity:Dot(gateDirection)

	-- 1. On récupère les réglages ACTUELS (le sommet de la pile)
	-- C'est la clé de "l'héritage" : on part de ce qu'on a déjà.
	local currentSettings = settingsStack[#settingsStack]

	-- 2. On lit la porte
	local gWalk = gate:GetAttribute("TargetWalk")
	local gSprint = gate:GetAttribute("TargetSprint")
	local gPower = gate:GetAttribute("TargetJumpPower")
	local gHeight = gate:GetAttribute("TargetJumpHeight")
	local gMom = gate:GetAttribute("TargetMomentum") -- Booléen
	local gSus = gate:GetAttribute("TargetSustain")   -- Booléen

	if dotProduct > 0 then
		-- ➡ SENS AVANT : On crée une nouvelle couche de réglages
		-- Si la porte dit 0 ou nil, on garde 'currentSettings' (Héritage)

		local newSettings = {
			Walk = (gWalk and gWalk > 0) and gWalk or currentSettings.Walk,
			Sprint = (gSprint and gSprint > 0) and gSprint or currentSettings.Sprint,
			JumpPower = (gPower and gPower > 0) and gPower or currentSettings.JumpPower,
			JumpHeight = (gHeight and gHeight > 0) and gHeight or currentSettings.JumpHeight,

			-- Pour les booléens, nil veut dire "hériter", mais false veut dire "désactiver"
			-- Donc on vérifie juste si l'attribut existe sur la porte
			Momentum = (gMom ~= nil) and gMom or currentSettings.Momentum,
			Sustain = (gSus ~= nil) and gSus or currentSettings.Sustain
		}

		table.insert(settingsStack, newSettings)
		applySettings(newSettings)
	else
		-- ⬅ SENS ARRIERE : On dépile pour revenir à l'état d'avant
		if #settingsStack > 1 then
			table.remove(settingsStack)
		end
		applySettings(settingsStack[#settingsStack])
	end

	local h = Instance.new("Highlight")
	h.Parent = gate
	h.FillColor = (dotProduct > 0) and Color3.new(0,1,0) or Color3.new(1,0,0)
	h.OutlineTransparency = 1
	game.Debris:AddItem(h, 0.3)
end

local function setupGate(gate)
	if gate:IsA("BasePart") then
		gate.Transparency = 1; gate.CanCollide = false
		gate.Touched:Connect(function(hit) onGateTouched(hit, gate) end)
	end
end

for _, gate in ipairs(gatesFolder:GetChildren()) do setupGate(gate) end
gatesFolder.ChildAdded:Connect(function(gate) setupGate(gate) end)

applySettings(DEFAULTS)