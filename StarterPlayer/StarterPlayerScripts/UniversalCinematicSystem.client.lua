--[[
    UniversalCinematicSystem (LocalScript)
    Path: StarterPlayer → StarterPlayerScripts
    Parent: StarterPlayerScripts
    Properties:
        Disabled: false
    Exported: 2026-01-28 16:22:15
]]
-- LOCAL SCRIPT : CinematicManager (V41 - AUDIO SYNC & PRELOAD)
-- PLACEMENT : StarterPlayerScripts

--[[ 
    ===========================================================================
    📚 GUIDE DES ATTRIBUTS (Sur le Trigger)
    ===========================================================================
    
    🆕 SoundTrack (String) : Syntaxe -> "Secondes:ID | Secondes:ID"
         Exemple : "0:123456 | 3.5:987654" 
         (Joue le son 1 dès le début (Frame 0), et le son 2 à 3.5s.)
         (Les sons sont préchargés et ne s'arrêtent pas à la fin de la cutscene.)

    🆕 ImpactFrames (String) : Syntaxe -> "Secondes:ID | Secondes:ID"
    
    ... (Autres attributs inchangés) ...
    ===========================================================================
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

-- MODULES
local Moon2Cutscene = require(ReplicatedStorage:WaitForChild("Moon2Cutscene"))
local hasGameState, GameState = pcall(function() return require(ReplicatedStorage:WaitForChild("GameStateManager")) end)

-- DOSSIERS
local zonesFolder = Workspace:WaitForChild("CinematicZones", 10)

-- JOUEUR
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")
local camera = Workspace.CurrentCamera

-- GUI IMPACT FRAME
local impactGui = Instance.new("ScreenGui")
impactGui.Name = "CinematicImpactGui"
impactGui.IgnoreGuiInset = true
impactGui.Enabled = false
impactGui.ResetOnSpawn = false
impactGui.Parent = player:WaitForChild("PlayerGui")

local impactImage = Instance.new("ImageLabel")
impactImage.Name = "ImpactFrame"
impactImage.Size = UDim2.fromScale(1, 1)
impactImage.BackgroundTransparency = 1
impactImage.ImageTransparency = 0
impactImage.ZIndex = 100
impactImage.Parent = impactGui

-- VERROUS & MÉMOIRE
local isBlockingCutscenePlaying = false 
local activeLoops = {} 
local collisionSnapshot = {}

print("🎬 Cinematic Manager V41 : PRÊT (Audio Preload + Zero Latency)")

-- ============================================================================
-- ⚡ SYSTÈME D'IMPACT FRAMES (IMAGE)
-- ============================================================================

local function parseImpactString(str)
	local impacts = {}
	if not str or str == "" then return impacts end
	str = string.gsub(str, " ", "")
	local entries = string.split(str, "|")
	for _, entry in pairs(entries) do
		local parts = string.split(entry, ":")
		if #parts == 2 then
			local timeStamp = tonumber(parts[1])
			local imgID = parts[2]
			if not string.find(imgID, "rbxassetid://") then imgID = "rbxassetid://" .. imgID end
			if timeStamp then table.insert(impacts, {Time = timeStamp, Image = imgID, Played = false}) end
		end
	end
	task.spawn(function()
		local assets = {}
		for _, v in pairs(impacts) do table.insert(assets, v.Image) end
		if #assets > 0 then
			local p = Instance.new("ImageLabel")
			for _, id in pairs(assets) do p.Image = id; ContentProvider:PreloadAsync({p}) end
		end
	end)
	return impacts
end

local function runImpactTrack(impactData)
	if #impactData == 0 then return nil end
	local startTime = os.clock()
	local connection
	local FRAME_DURATION = 0.1 
	connection = RunService.RenderStepped:Connect(function()
		local now = os.clock() - startTime
		for _, hit in pairs(impactData) do
			if not hit.Played and now >= hit.Time then
				hit.Played = true
				impactImage.Image = hit.Image
				impactGui.Enabled = true
				task.delay(FRAME_DURATION, function()
					if impactImage.Image == hit.Image then impactGui.Enabled = false end
				end)
			end
		end
	end)
	return connection
end

-- ============================================================================
-- 🔊 SYSTÈME SOUND TRACK (PRÉCHARGEMENT AGRESSIF)
-- ============================================================================

local function parseSoundString(str)
	local sounds = {}
	if not str or str == "" then return sounds end
	str = string.gsub(str, " ", "") -- Nettoyage espaces

	local entries = string.split(str, "|")
	for _, entry in pairs(entries) do
		local parts = string.split(entry, ":")
		if #parts == 2 then
			local timeStamp = tonumber(parts[1])
			local sndID = parts[2]
			if not string.find(sndID, "rbxassetid://") then sndID = "rbxassetid://" .. sndID end

			if timeStamp then 
				-- On crée l'instance Sound TOUT DE SUITE pour qu'elle soit prête
				local soundInstance = Instance.new("Sound")
				soundInstance.Name = "CinematicSFX_Preloaded"
				soundInstance.SoundId = sndID
				soundInstance.Volume = 1

				-- On stocke l'instance prête à tirer
				table.insert(sounds, {Time = timeStamp, SoundObj = soundInstance, Played = false}) 
			end
		end
	end

	-- ⚡ PRÉCHARGEMENT BLOQUANT (Async mais lancé en spawn pour ne pas freeze le script principal)
	-- Cela force le téléchargement avant l'utilisation
	task.spawn(function()
		local instancesToLoad = {}
		for _, v in pairs(sounds) do table.insert(instancesToLoad, v.SoundObj) end
		if #instancesToLoad > 0 then
			ContentProvider:PreloadAsync(instancesToLoad)
			-- print("🔊 Sons préchargés en mémoire !")
		end
	end)

	return sounds
end

local function runSoundTrack(soundData)
	if #soundData == 0 then return nil end
	local startTime = os.clock()
	local connection

	-- BOUCLE HAUTE PRÉCISION
	connection = RunService.RenderStepped:Connect(function()
		local now = os.clock() - startTime

		for _, sData in pairs(soundData) do
			-- La condition 'now >= sData.Time' gère le cas 0. 
			-- Si Time est 0, et que now est 0.001, c'est VRAI -> Le son part direct.
			if not sData.Played and now >= sData.Time then
				sData.Played = true

				-- RÉCUPÉRATION DU SON PRÉPARÉ
				local sound = sData.SoundObj
				sound.Parent = SoundService -- On le met dans le service global pour qu'il survive
				sound:Play()

				-- NETTOYAGE AUTO
				sound.Ended:Connect(function()
					sound:Destroy()
				end)
			end
		end
	end)
	return connection
end

-- ============================================================================
-- 🛠️ OUTILS & FONCTIONS
-- ============================================================================

local function takeCollisionSnapshot()
	local cp = character:FindFirstChild("CollisionPart")
	if cp then
		collisionSnapshot = {
			Transparency = cp.Transparency,
			CanCollide = cp.CanCollide,
			LocalModifier = cp.LocalTransparencyModifier
		}
	else
		collisionSnapshot = nil
	end
end

local function restoreCollisionPart()
	local cp = character:FindFirstChild("CollisionPart")
	if cp and collisionSnapshot then
		cp.Transparency = collisionSnapshot.Transparency
		cp.CanCollide = collisionSnapshot.CanCollide
		cp.LocalTransparencyModifier = collisionSnapshot.LocalModifier
	end
end

local function setControls(active)
	local playerModule = player.PlayerScripts:FindFirstChild("PlayerModule")
	if playerModule then
		local controls = require(playerModule):GetControls()
		if active then controls:Enable() else controls:Disable() end
	end
end

local function setRealCharVisible(isVisible)
	local trans = isVisible and 0 or 1
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			if part.Name == "CollisionPart" then
				if not isVisible then part.Transparency = 1 end
			else
				part.Transparency = trans
			end
		elseif part:IsA("Decal") then
			part.Transparency = trans
		end
	end
end

local function toggleRealCharacter(active)
	local animateScript = character:FindFirstChild("Animate")
	if animateScript then animateScript.Disabled = not active end
	if not active then
		humanoid.PlatformStand = true 
		rootPart.Anchored = true
		rootPart.AssemblyLinearVelocity = Vector3.zero
	else
		humanoid.PlatformStand = false
		rootPart.Anchored = false
	end
end

local function setupClone(cloneChar)
	local badPart = cloneChar:FindFirstChild("CollisionPart")
	if badPart then badPart:Destroy() end

	for _, child in pairs(cloneChar:GetChildren()) do
		if child:IsA("Script") or child:IsA("LocalScript") then child:Destroy() end
	end
	if cloneChar:FindFirstChild("HumanoidRootPart") then
		cloneChar.HumanoidRootPart.Anchored = true
		cloneChar.HumanoidRootPart.CanCollide = false
	end
	if cloneChar:FindFirstChild("Humanoid") then
		cloneChar.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		cloneChar.Humanoid.PlatformStand = true
	end
	for _, p in pairs(cloneChar:GetDescendants()) do
		if p:IsA("BasePart") then
			if p.Name == "CollisionPart" then 
				p:Destroy() 
			else
				p.LocalTransparencyModifier = 0
				if p.Name ~= "HumanoidRootPart" then p.Transparency = 0 end
			end
		elseif p:IsA("Decal") then
			p.Transparency = 0
		end
	end
end

local function nuclearCameraReset(destinationPart)
	camera.CameraType = Enum.CameraType.Scriptable
	if destinationPart then
		camera.CFrame = destinationPart.CFrame + Vector3.new(0, 5, 10)
		camera.Focus = destinationPart.CFrame
	end
	RunService.RenderStepped:Wait()
	if humanoid then camera.CameraSubject = humanoid end
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
end

-- ============================================================================
-- 1️⃣ PRESET 1 : MODE COMPLET
-- ============================================================================
local function runPreset_1(zone, animFileSource)
	print("🚀 Lancement Preset [1] : Transition")
	isBlockingCutscenePlaying = true 
	takeCollisionSnapshot() 

	local rigIndex = zone:GetAttribute("TargetRigIndex")
	local endName = zone:GetAttribute("EndPointName")
	local delayTime = zone:GetAttribute("StartDelay") or 0 

	-- RECUP DATA (Parsing + Preloading immédiat)
	local impactData = parseImpactString(zone:GetAttribute("ImpactFrames"))
	local soundData = parseSoundString(zone:GetAttribute("SoundTrack"))

	if not rigIndex or rigIndex == 0 then warn("⚠️ Preset 1 : TargetRigIndex requis"); isBlockingCutscenePlaying = false; return end
	local endPart = nil
	if endName then endPart = Workspace:FindFirstChild(endName, true) end
	if not endPart then warn("⚠️ Preset 1 : EndPointName requis"); isBlockingCutscenePlaying = false; return end

	if delayTime > 0 then task.wait(delayTime) end

	local uniqueAnim = animFileSource:Clone()
	uniqueAnim.Name = "P1_" .. HttpService:GenerateGUID(false)
	uniqueAnim.Parent = ReplicatedStorage

	local TRANSITION_DURATION = 2.0
	local BASE_SPEED = 38
	local SPRINT_ID = "rbxassetid://91621135033649"

	local startPlayerCF = rootPart.CFrame
	local startCamCF = camera.CFrame
	local startFOV = camera.FieldOfView

	character.Archivable = true
	local stuntMan = character:Clone()
	stuntMan.Name = "StuntMan"
	setupClone(stuntMan)
	stuntMan.Parent = Workspace
	stuntMan:PivotTo(startPlayerCF)

	local calcDummy = character:Clone()
	calcDummy.Name = "CalcDummy"
	setupClone(calcDummy)
	for _, p in pairs(calcDummy:GetDescendants()) do
		if p:IsA("BasePart") or p:IsA("Decal") then p.Transparency = 1 end
	end
	calcDummy.Parent = Workspace
	calcDummy:PivotTo(startPlayerCF)
	character.Archivable = false

	if hasGameState then GameState:SetCutscene(true) end
	setControls(false)
	toggleRealCharacter(false)
	setRealCharVisible(false)
	rootPart.CFrame = endPart.CFrame + Vector3.new(0, 3, 0)

	camera.CameraType = Enum.CameraType.Scriptable
	local calcCutscene = Moon2Cutscene.new(uniqueAnim)
	calcCutscene:replace(rigIndex, calcDummy)
	calcCutscene:play()
	RunService.RenderStepped:Wait(); RunService.RenderStepped:Wait(); RunService.RenderStepped:Wait()

	local targetCamCF = camera.CFrame
	local targetFOV = camera.FieldOfView
	local targetCharCF = calcDummy.HumanoidRootPart.CFrame

	calcCutscene:stop()
	calcDummy:Destroy()
	camera.CFrame = startCamCF
	camera.FieldOfView = startFOV

	local dist = (targetCharCF.Position - startPlayerCF.Position).Magnitude
	local reqSpeed = dist / TRANSITION_DURATION
	local speedRatio = reqSpeed / BASE_SPEED
	if speedRatio < 0.1 then speedRatio = 1 end

	local sAnim = Instance.new("Animation"); sAnim.AnimationId = SPRINT_ID
	local sTrack = stuntMan.Humanoid:LoadAnimation(sAnim)
	sTrack:Play(); sTrack:AdjustSpeed(speedRatio)

	local tInfo = TweenInfo.new(TRANSITION_DURATION, Enum.EasingStyle.Linear)
	local camTw = TweenService:Create(camera, tInfo, {CFrame = targetCamCF, FieldOfView = targetFOV})
	local charTw = TweenService:Create(stuntMan.HumanoidRootPart, tInfo, {CFrame = targetCharCF})
	local lookPos = Vector3.new(targetCharCF.Position.X, stuntMan.HumanoidRootPart.Position.Y, targetCharCF.Position.Z)
	stuntMan:PivotTo(CFrame.lookAt(stuntMan.HumanoidRootPart.Position, lookPos))

	camTw:Play(); charTw:Play()
	charTw.Completed:Wait()
	sTrack:Stop(0)

	-- ACTION
	local finalCutscene = Moon2Cutscene.new(uniqueAnim)
	finalCutscene:replace(rigIndex, stuntMan)

	-- START TRACKERS (IMPACT & SOUND)
	local impactTrack = runImpactTrack(impactData)
	local soundTrack = runSoundTrack(soundData)

	finalCutscene:play()

	local watchdog = RunService.RenderStepped:Connect(function()
		if stuntMan and stuntMan.Parent then
			for _, p in pairs(stuntMan:GetDescendants()) do
				if p:IsA("BasePart") then p.LocalTransparencyModifier = 0 end
			end
		end
	end)

	RunService.RenderStepped:Wait()
	finalCutscene:wait()

	-- STOP TRACKERS
	if impactTrack then impactTrack:Disconnect() end
	if soundTrack then soundTrack:Disconnect() end 
	impactGui.Enabled = false

	if watchdog then watchdog:Disconnect() end
	pcall(function() finalCutscene:stop() end)

	local ghostName = uniqueAnim.Name .. "_MoonAnimator"
	local ghost = Workspace:FindFirstChild(ghostName)
	if ghost then ghost:Destroy() end
	uniqueAnim:Destroy()
	stuntMan:Destroy()

	toggleRealCharacter(true)
	setRealCharVisible(true)
	restoreCollisionPart()
	nuclearCameraReset(endPart)
	setControls(true)
	if hasGameState then GameState:SetCutscene(false) end

	local nextPhase = zone:GetAttribute("SetPhaseAtEnd")
	if nextPhase and nextPhase > 0 and hasGameState then GameState:SetPhase(nextPhase) end

	if zone and zone:GetAttribute("PlayOnce") == true then
		zone:Destroy() 
	end

	isBlockingCutscenePlaying = false 
end

-- ============================================================================
-- 3️⃣ PRESET 3 : MODE INSTANTANÉ
-- ============================================================================
local function runPreset_3(zone, animFileSource)
	print("🚀 Lancement Preset [3] : Instantané")
	isBlockingCutscenePlaying = true 
	takeCollisionSnapshot() 

	local rigIndex = zone:GetAttribute("TargetRigIndex")
	local endName = zone:GetAttribute("EndPointName")
	local delayTime = zone:GetAttribute("StartDelay") or 0 

	-- RECUP DATA (Parsing + Preloading immédiat)
	local impactData = parseImpactString(zone:GetAttribute("ImpactFrames"))
	local soundData = parseSoundString(zone:GetAttribute("SoundTrack"))

	if not rigIndex or rigIndex == 0 then warn("⚠️ Preset 3 : TargetRigIndex requis"); isBlockingCutscenePlaying = false; return end
	local endPart = nil
	if endName then endPart = Workspace:FindFirstChild(endName, true) end
	if not endPart then warn("⚠️ Preset 3 : EndPointName requis"); isBlockingCutscenePlaying = false; return end

	if delayTime > 0 then task.wait(delayTime) end

	local uniqueAnim = animFileSource:Clone()
	uniqueAnim.Name = "P3_" .. HttpService:GenerateGUID(false)
	uniqueAnim.Parent = ReplicatedStorage

	local startPlayerCF = rootPart.CFrame

	character.Archivable = true
	local stuntMan = character:Clone()
	stuntMan.Name = "StuntMan_Instant"
	setupClone(stuntMan)
	stuntMan.Parent = Workspace
	stuntMan:PivotTo(startPlayerCF)

	local calcDummy = character:Clone()
	calcDummy.Name = "CalcDummy"
	setupClone(calcDummy)
	for _, p in pairs(calcDummy:GetDescendants()) do
		if p:IsA("BasePart") or p:IsA("Decal") then p.Transparency = 1 end
	end
	calcDummy.Parent = Workspace
	calcDummy:PivotTo(startPlayerCF)
	character.Archivable = false

	if hasGameState then GameState:SetCutscene(true) end
	setControls(false)
	toggleRealCharacter(false)
	setRealCharVisible(false)
	rootPart.CFrame = endPart.CFrame + Vector3.new(0, 3, 0)

	camera.CameraType = Enum.CameraType.Scriptable
	local calcCutscene = Moon2Cutscene.new(uniqueAnim)
	calcCutscene:replace(rigIndex, calcDummy)
	calcCutscene:play()
	RunService.RenderStepped:Wait(); RunService.RenderStepped:Wait(); RunService.RenderStepped:Wait()

	local targetCamCF = camera.CFrame
	local targetCharCF = calcDummy.HumanoidRootPart.CFrame

	calcCutscene:stop()
	calcDummy:Destroy()

	camera.CFrame = targetCamCF
	stuntMan:PivotTo(targetCharCF)

	local finalCutscene = Moon2Cutscene.new(uniqueAnim)
	finalCutscene:replace(rigIndex, stuntMan)

	-- START TRACKERS
	local impactTrack = runImpactTrack(impactData)
	local soundTrack = runSoundTrack(soundData)

	finalCutscene:play()

	local watchdog = RunService.RenderStepped:Connect(function()
		if stuntMan and stuntMan.Parent then
			for _, p in pairs(stuntMan:GetDescendants()) do
				if p:IsA("BasePart") then p.LocalTransparencyModifier = 0 end
			end
		end
	end)

	RunService.RenderStepped:Wait()
	finalCutscene:wait()

	-- STOP TRACKERS
	if impactTrack then impactTrack:Disconnect() end
	if soundTrack then soundTrack:Disconnect() end -- Les sons continuent
	impactGui.Enabled = false

	if watchdog then watchdog:Disconnect() end
	pcall(function() finalCutscene:stop() end)

	local ghostName = uniqueAnim.Name .. "_MoonAnimator"
	local ghost = Workspace:FindFirstChild(ghostName)
	if ghost then ghost:Destroy() end
	uniqueAnim:Destroy()
	stuntMan:Destroy()

	toggleRealCharacter(true)
	setRealCharVisible(true)
	restoreCollisionPart()
	nuclearCameraReset(endPart)
	setControls(true)
	if hasGameState then GameState:SetCutscene(false) end

	local nextPhase = zone:GetAttribute("SetPhaseAtEnd")
	if nextPhase and nextPhase > 0 and hasGameState then GameState:SetPhase(nextPhase) end

	if zone and zone:GetAttribute("PlayOnce") == true then
		zone:Destroy() 
	end

	isBlockingCutscenePlaying = false 
end


-- ============================================================================
-- 2️⃣ PRESET 2 : MODE ENVIRONNEMENT
-- ============================================================================
local function runPreset_2(zone, animFileSource)
	if activeLoops[zone] then return end 

	local hideHUD = zone:GetAttribute("HideHUD") == true
	if hideHUD then player.PlayerGui.Enabled = false end

	local keepChanges = zone:GetAttribute("KeepChanges") == true 
	local isLooping = zone:GetAttribute("Loop") == true
	local delayTime = zone:GetAttribute("StartDelay") or 0 

	if isLooping then activeLoops[zone] = true end 

	task.spawn(function() 
		if delayTime > 0 then task.wait(delayTime) end

		while true do
			local uniqueID = HttpService:GenerateGUID(false)
			local uniqueAnim = animFileSource:Clone()
			uniqueAnim.Name = "P2_" .. uniqueID
			uniqueAnim.Parent = ReplicatedStorage 

			local cutscene = Moon2Cutscene.new(uniqueAnim)
			cutscene:play()

			RunService.RenderStepped:Wait()
			cutscene:wait()

			if not isLooping then
				if not keepChanges then
					pcall(function() cutscene:stop() end)
					local ghost = Workspace:FindFirstChild(uniqueAnim.Name .. "_MoonAnimator")
					if ghost then ghost:Destroy() end
				end
				uniqueAnim:Destroy()
				break 
			else
				pcall(function() cutscene:stop() end)
				local ghost = Workspace:FindFirstChild(uniqueAnim.Name .. "_MoonAnimator")
				if ghost then ghost:Destroy() end
				uniqueAnim:Destroy()

				task.wait(0.1) 

				if not zone or not zone.Parent then break end
			end
		end

		if hideHUD then player.PlayerGui.Enabled = true end

		if zone and zone:GetAttribute("PlayOnce") == true then 
			zone:Destroy() 
		else
			if not isLooping then activeLoops[zone] = nil end
		end
	end)
end

-- ============================================================================
-- 🎮 SELECTEUR
-- ============================================================================

local function playCinematic(zone)
	local presetID = zone:GetAttribute("Preset")

	if (presetID == 1 or presetID == 3) and isBlockingCutscenePlaying then return end

	if zone:GetAttribute("PlayOnce") == true then
		zone.CanTouch = false 
	end

	local cutName = zone:GetAttribute("CutsceneName")
	if not cutName then warn("🔴 CutsceneName manquant"); return end

	local animFile = ReplicatedStorage:FindFirstChild(cutName)
	if not animFile then
		local requestRemote = ReplicatedStorage:FindFirstChild("RequestCutscene")
		if requestRemote then
			animFile = requestRemote:InvokeServer(cutName)
			if animFile then animFile.Parent = ReplicatedStorage end
		end
	end

	if not animFile then warn("🔴 Anim introuvable : " .. cutName); return end

	if presetID == 1 then
		runPreset_1(zone, animFile)
	elseif presetID == 2 then
		runPreset_2(zone, animFile)
	elseif presetID == 3 then
		runPreset_3(zone, animFile)
	else
		warn("⚠️ Preset inconnu : " .. tostring(presetID))
	end
end

if zonesFolder then
	for _, zone in pairs(zonesFolder:GetChildren()) do
		if zone:IsA("BasePart") then
			zone.Touched:Connect(function(hit)
				if hit.Parent == character then playCinematic(zone) end
			end)
		end
	end
end