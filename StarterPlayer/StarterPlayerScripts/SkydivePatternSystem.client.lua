--[[
    SkydivePatternSystem (LocalScript)
    Path: StarterPlayer → StarterPlayerScripts
    Parent: StarterPlayerScripts
    Properties:
        Disabled: false
    Exported: 2026-01-28 16:22:15
]]
-- LOCAL SCRIPT : SkydivePatternSystem (V10 - COLLISION GROUPS FIX)
-- PLACEMENT : StarterPlayerScripts

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService") 

local player = Players.LocalPlayer

-- ============================================================================
-- 🔍 SETUP
-- ============================================================================
local masterFolder = Workspace:WaitForChild("SkydiveProjectiles")
local templatesSource = masterFolder:WaitForChild("PatternTemplates")
local spawnersFolder = masterFolder:WaitForChild("SkydiveSpawners")

-- STORAGE
local patternsStorage = ReplicatedStorage:FindFirstChild("SkydivePatterns_Storage")
if not patternsStorage then
	patternsStorage = Instance.new("Folder")
	patternsStorage.Name = "SkydivePatterns_Storage"
	patternsStorage.Parent = ReplicatedStorage
end

local activeZonesObjects = {} 
local activeLoops = {}

print("🚀 Skydive Pattern System : PRÊT")

-- ============================================================================
-- 📦 PHASE 1 : ARCHIVAGE
-- ============================================================================
for _, folder in pairs(templatesSource:GetChildren()) do
	folder.Parent = patternsStorage
end

-- ============================================================================
-- 🛠️ OUTIL DE PHYSIQUE
-- ============================================================================
local function setupPhysicsModel(model)
	-- 1. DÉTECTION DU CENTRE
	local primary = model:FindFirstChild("Center")
	if not primary then primary = model.PrimaryPart end

	if not primary then
		local cframe, size = model:GetBoundingBox()
		local centerPos = cframe.Position 

		local autoRoot = Instance.new("Part")
		autoRoot.Name = "AutoRoot"
		autoRoot.Size = Vector3.new(1, 1, 1)
		autoRoot.Transparency = 1
		autoRoot.CanCollide = false
		autoRoot.Anchored = true 
		autoRoot.CFrame = CFrame.new(centerPos) 
		autoRoot.Parent = model

		primary = autoRoot
	end

	model.PrimaryPart = primary

	-- 2. SOUDURE ET GROUPE DE COLLISION
	for _, part in pairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false 

			-- A. Gestion Solidité
			if part.Name == "AutoRoot" or part.Name == "Center" then
				part.CanCollide = false
			else
				part.CanCollide = true -- Solide pour le joueur
			end

			-- B. ASSIGNATION AUTOMATIQUE DU GROUPE
			-- Le script met le projectile dans le groupe "Fantôme"
			pcall(function()
				part.CollisionGroup = "SkydiveProjectile"
			end)

			if part ~= primary then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primary
				weld.Part1 = part
				weld.Parent = primary
			end
		end
	end

	primary.Anchored = false
	primary.CanCollide = false

	return model
end

-- ============================================================================
-- 🧱 CONSTRUCTEUR
-- ============================================================================
local function getProjectileFromTemplate(templateFolder)
	local projectile = nil
	local existingModel = templateFolder:FindFirstChildWhichIsA("Model")

	if existingModel then
		projectile = existingModel:Clone()
		projectile.Name = templateFolder.Name .. "_Projectile"
	else
		projectile = Instance.new("Model")
		projectile.Name = templateFolder.Name .. "_Projectile"
		for _, child in pairs(templateFolder:GetChildren()) do
			local clone = child:Clone()
			clone.Parent = projectile
		end
	end
	return projectile
end

-- ============================================================================
-- 🔫 LOGIQUE DE TIR
-- ============================================================================

local function spawnPattern(emitter, patternName, speed, lifetime, zoneRef)
	local templateFolder = patternsStorage:FindFirstChild(patternName)
	if not templateFolder then warn("❌ Pattern introuvable : " .. tostring(patternName)); return end

	local projectile = getProjectileFromTemplate(templateFolder)
	if not projectile then return end

	if not setupPhysicsModel(projectile) then 
		projectile:Destroy()
		return 
	end

	projectile:PivotTo(emitter.CFrame)
	projectile.Parent = Workspace

	local root = projectile.PrimaryPart

	if root then
		-- Vitesse + Inertie
		local bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		local launchVel = emitter.CFrame.LookVector * speed
		local inertia = emitter.AssemblyLinearVelocity 
		bv.Velocity = launchVel + inertia
		bv.Parent = root

		-- Gyroscope
		local bg = Instance.new("BodyGyro")
		bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		bg.D = 0 
		bg.P = 50000
		bg.CFrame = emitter.CFrame 
		bg.Parent = root
	end

	if zoneRef then
		table.insert(activeZonesObjects[zoneRef], projectile)
	end

	Debris:AddItem(projectile, lifetime)
end

-- ============================================================================
-- 🔄 BOUCLE D'ÉMISSION
-- ============================================================================

local function startEmitter(emitter, zoneRef)
	local rawSequence = emitter:GetAttribute("PatternSequence") or ""
	local speed = emitter:GetAttribute("Speed") or 100
	local spawnRate = emitter:GetAttribute("SpawnRate") or 2
	local startDelay = emitter:GetAttribute("StartDelay") or 0
	local rndMin = emitter:GetAttribute("RandomMin") or 0
	local rndMax = emitter:GetAttribute("RandomMax") or 0
	local lifetime = emitter:GetAttribute("Lifetime") or 5

	local sequence = {}
	if rawSequence ~= "" then
		rawSequence = string.gsub(rawSequence, " ", "")
		sequence = string.split(rawSequence, ",")
	end

	task.spawn(function()
		if startDelay > 0 then task.wait(startDelay) end
		local index = 1

		while activeLoops[zoneRef] do
			local patternName = ""

			if #sequence > 0 then
				patternName = sequence[index]
				index = index + 1
				if index > #sequence then index = 1 end
			else
				local available = patternsStorage:GetChildren()
				if #available > 0 then
					patternName = available[math.random(1, #available)].Name
				end
			end

			if patternName ~= "" then
				spawnPattern(emitter, patternName, speed, lifetime, zoneRef)
			end

			local waitTime = spawnRate
			if rndMin > 0 and rndMax > 0 then
				waitTime = math.random() * (rndMax - rndMin) + rndMin
			end

			task.wait(waitTime)
		end
	end)
end

-- ============================================================================
-- ⚡ GESTION DE ZONE
-- ============================================================================

local function onZoneEnter(zoneFolder)
	if activeLoops[zoneFolder] then return end
	activeLoops[zoneFolder] = true
	activeZonesObjects[zoneFolder] = {}

	for _, child in pairs(zoneFolder:GetChildren()) do
		if child.Name == "Emitter" and child:IsA("BasePart") then
			startEmitter(child, zoneFolder)
		end
	end
end

local function onZoneExit(zoneFolder)
	if not activeLoops[zoneFolder] then return end
	activeLoops[zoneFolder] = false

	local clearOnExit = false
	local firstEmitter = zoneFolder:FindFirstChild("Emitter")
	if firstEmitter and firstEmitter:GetAttribute("ClearOnExit") == true then
		clearOnExit = true
	end

	if clearOnExit and activeZonesObjects[zoneFolder] then
		for _, obj in pairs(activeZonesObjects[zoneFolder]) do
			if obj then obj:Destroy() end
		end
	end

	activeZonesObjects[zoneFolder] = nil
end

-- ============================================================================
-- 📡 INITIALISATION
-- ============================================================================

for _, zoneFolder in pairs(spawnersFolder:GetChildren()) do
	local trigger = zoneFolder:FindFirstChild("TriggerZone")
	if trigger then
		trigger.Transparency = 1 
		trigger.CanCollide = false
		trigger.Touched:Connect(function(hit)
			if hit.Parent == player.Character then onZoneEnter(zoneFolder) end
		end)
		trigger.TouchEnded:Connect(function(hit)
			if hit.Parent == player.Character then onZoneExit(zoneFolder) end
		end)
	end
end