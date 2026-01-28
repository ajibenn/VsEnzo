--[[
    StrafeControl (LocalScript)
    Path: StarterPlayer → StarterCharacterScripts
    Parent: StarterCharacterScripts
    Properties:
        Disabled: false
    Exported: 2026-01-28 16:22:15
]]
-- LOCAL SCRIPT : StrafeControl (V9 - CINEMATIC AWARE)
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService") 
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(ReplicatedStorage:WaitForChild("GameStateManager"))

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local camera = Workspace.CurrentCamera

-- Par défaut, on veut que le perso tourne avec la caméra
humanoid.AutoRotate = false 

RunService.RenderStepped:Connect(function()
	if humanoid.Health <= 0 then return end

	-- 1. SI CUTSCENE DU JEU (Lancement, Fin de niveau...)
	if GameState:GetCutscene() == true then 
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		return 
	end

	-- 2. SI CAMÉRA GLVL ACTIVE (NOUVEAU)
	-- On libère le joueur pour qu'il puisse courir vers la caméra ou sur les côtés
	if character:GetAttribute("CinematicActive") == true then
		humanoid.AutoRotate = true -- Le joueur regarde où il marche
		-- Optionnel : Garder le MouseLock ou non. Souvent en plan fixe, on préfère voir la souris.
		-- UserInputService.MouseBehavior = Enum.MouseBehavior.Default 
		return 
	end

	-- 3. ACTIONS SPÉCIALES (Combats, Swing...)
	if character:GetAttribute("SwingActive") == true 
		or character:GetAttribute("ActionChainActive") == true then
		return 
	end

	-- 4. MODE STRAFE CLASSIQUE (Shift Lock)
	humanoid.AutoRotate = false -- On force la rotation manuelle
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

	local camLook = camera.CFrame.LookVector
	local lookDirection = Vector3.new(camLook.X, 0, camLook.Z).Unit

	if lookDirection.Magnitude > 0 then
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + lookDirection)
	end
end)