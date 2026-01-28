--[[
    IntroCutscene (LocalScript)
    Path: StarterPlayer → StarterPlayerScripts
    Parent: StarterPlayerScripts
    Properties:
        Disabled: false
    Exported: 2026-01-28 16:22:15
]]
-- LOCAL SCRIPT : IntroCutscene (STOP MUSIQUE FIN)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local ContentProvider = game:GetService("ContentProvider")
local ContextActionService = game:GetService("ContextActionService")

local Moon2Cutscene = require(ReplicatedStorage:WaitForChild("Moon2Cutscene"))
local animFile = ReplicatedStorage:WaitForChild("IntroFinal1")
local Trigger = Workspace:WaitForChild("TriggerCinematic")
local BossEvent = ReplicatedStorage:WaitForChild("StartBossEvent")

-- LISTE DES ACTEURS
local ACTEURS_A_RESET = {
	"Gaby", "Ghjise", "Lucas", "Matteo", 
	"Frite1", "Frite2", "Frite3", "Frite5", 
	"PistolNuget", "Camera", "Part3"
}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local hasPlayed = false
local musicTrack = nil
local positionsDeDepart = {}

player.CharacterAdded:Connect(function(newChar)
	hasPlayed = false
	Trigger = Workspace:WaitForChild("TriggerCinematic", 5) 
end)

local musicAsset = Instance.new("Sound")
musicAsset.SoundId = "rbxassetid://75018990843801"
task.spawn(function()
	pcall(function() ContentProvider:PreloadAsync({animFile, musicAsset}, function() end) end)
end)

local function disableSprint()
	ContextActionService:BindAction("DisableSprint", function() return Enum.ContextActionResult.Sink end, false, Enum.KeyCode.LeftShift)
end

local function capturerPositions()
	positionsDeDepart = {}
	for _, nom in ipairs(ACTEURS_A_RESET) do
		local objet = Workspace:FindFirstChild(nom)
		if objet then positionsDeDepart[objet] = objet:GetPivot() end
	end
end

local function startCutscene()
	if hasPlayed then return end
	hasPlayed = true
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")

	capturerPositions()

	local gui = Instance.new("ScreenGui", player.PlayerGui)
	gui.IgnoreGuiInset = true; gui.ResetOnSpawn = false; gui.Name = "CutsceneFade"
	local frame = Instance.new("Frame", gui)
	frame.Size = UDim2.new(1,0,1,0); frame.BackgroundColor3 = Color3.new(0,0,0); frame.BackgroundTransparency = 1; frame.ZIndex = 10
	TweenService:Create(frame, TweenInfo.new(1), {BackgroundTransparency = 0}):Play()

	if rootPart then rootPart.Anchored = true end
	disableSprint() 

	task.wait(1.2)
	camera.CameraType = Enum.CameraType.Scriptable

	musicTrack = musicAsset:Clone()
	musicTrack.Parent = SoundService
	musicTrack.Volume = 0.75
	musicTrack.Looped = true
	musicTrack:Play()

	local cutscene = Moon2Cutscene.new(animFile)
	cutscene:play()

	task.wait(0.5)
	TweenService:Create(frame, TweenInfo.new(2), {BackgroundTransparency = 1}):Play()

	cutscene:wait()

	pcall(function() cutscene:stop() end)

	for objet, pos in pairs(positionsDeDepart) do
		if objet.Parent then objet:PivotTo(pos) end
	end

	pcall(function() cutscene:reset() end)
	pcall(function() cutscene:destroy() end)
	local ghost = Workspace:FindFirstChild("IntroFinal1_MoonAnimator")
	if ghost then ghost:Destroy() end

	camera.CameraType = Enum.CameraType.Custom
	if humanoid then camera.CameraSubject = humanoid end
	if rootPart then rootPart.Anchored = false end

	gui:Destroy()

	local script1 = player:WaitForChild("PlayerScripts"):FindFirstChild("ClientWeaponsScript")
	local script2 = player:WaitForChild("PlayerGui"):FindFirstChild("ClientWeaponsScript")
	if script1 then script1.Disabled = false
	elseif script2 then script2.Disabled = false end

	-- === COUPURE MUSIQUE AVANT LE COMBAT ===
	if musicTrack then
		musicTrack:Stop()
		musicTrack:Destroy()
		musicTrack = nil
	end
	-- =======================================

	BossEvent:FireServer()
end

Trigger.Touched:Connect(function(hit)
	local hitPlayer = Players:GetPlayerFromCharacter(hit.Parent)
	if hitPlayer == player then
		startCutscene()
		Trigger:Destroy() 
	end
end)