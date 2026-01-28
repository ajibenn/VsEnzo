--[[
    SonicActionChain (LocalScript)
    Path: StarterPlayer → StarterCharacterScripts
    Parent: StarterCharacterScripts
    Properties:
        Disabled: false
    Exported: 2026-01-28 16:22:15
]]
-- LOCAL SCRIPT : SonicActionChain (V46 - SMART TRACKING & DECISION LOCK)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider") 
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(ReplicatedStorage:WaitForChild("GameStateManager"))

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

local isPhase2MechanicActive = false
GameState.PhaseChanged:Connect(function(newPhase) isPhase2MechanicActive = (newPhase == 2) end)
if GameState:GetPhase() == 2 then isPhase2MechanicActive = true end

-- ==========================================
-- ⚙️ REGLAGES
-- ==========================================
local DEFAULT_SPEED = 60
local DEFAULT_PAUSE = 0.2
local DEFAULT_QTE_TIME = 0.8
local SFX_VOLUME = 2.0 
local CAM_SMOOTH = 0.2 
local MOVEMENT_THRESHOLD = 0.1 -- Si le pad bouge de moins de 0.1 studs, on considère qu'il est fixe (Stabilité)

-- ANIMATIONS
local ROLL_ANIM_ID = "rbxassetid://136598973225722"
local WALL_IDLE_ID = "rbxassetid://136323863859645" 
local FALL_ANIM_ID = "rbxassetid://119021926553736"

-- 🔊 SONS
local SFX_FIRST_LAUNCH = "rbxassetid://100797890482357" 
local SFX_DETACH = "rbxassetid://100797890482357" 
local SFX_ATTACH = "rbxassetid://97818906451861" 

-- 🎮 IMAGES MANETTE
local BUTTON_IDS = {
	[Enum.KeyCode.ButtonA] = "82820478009774",    
	[Enum.KeyCode.ButtonX] = "122341303036820",   
	[Enum.KeyCode.ButtonY] = "76913173810725",    
	[Enum.KeyCode.ButtonB] = "131925613200177"    
}

local KEY_DEFINITIONS = {
	["Z"] = {PC = Enum.KeyCode.W, Console = Enum.KeyCode.ButtonY}, 
	["Q"] = {PC = Enum.KeyCode.A, Console = Enum.KeyCode.ButtonX}, 
	["S"] = {PC = Enum.KeyCode.S, Console = Enum.KeyCode.ButtonA}, 
	["D"] = {PC = Enum.KeyCode.D, Console = Enum.KeyCode.ButtonB}, 
	["Jump"] = {PC = Enum.KeyCode.Space, Console = Enum.KeyCode.ButtonA} 
}
local RANDOM_KEYS = {"Z", "Q", "S", "D"} 
local KEY_LABELS_PC = {[Enum.KeyCode.W]="Z", [Enum.KeyCode.A]="Q", [Enum.KeyCode.S]="S", [Enum.KeyCode.D]="D", [Enum.KeyCode.Space]="SPACE"}

-- SETUP SONS & GUI
local soundFirst = Instance.new("Sound"); soundFirst.Name="SfxFirst"; soundFirst.SoundId=SFX_FIRST_LAUNCH; soundFirst.Volume=SFX_VOLUME; soundFirst.Parent=rootPart
local soundDetach = Instance.new("Sound"); soundDetach.Name="SfxDetach"; soundDetach.SoundId=SFX_DETACH; soundDetach.Volume=SFX_VOLUME; soundDetach.Parent=rootPart
local soundAttach = Instance.new("Sound"); soundAttach.Name="SfxAttach"; soundAttach.SoundId=SFX_ATTACH; soundAttach.Volume=SFX_VOLUME; soundAttach.Parent=rootPart

local screenGui = Instance.new("ScreenGui"); screenGui.Name = "SonicQTE_HUD"; screenGui.Parent = playerGui; screenGui.Enabled = false
local preloadFolder = Instance.new("Folder"); preloadFolder.Name = "PreloadedAssets"; preloadFolder.Parent = screenGui
task.spawn(function()
	local assets = {soundFirst, soundDetach, soundAttach}
	for _, id in pairs(BUTTON_IDS) do
		local img = Instance.new("ImageLabel"); img.Size=UDim2.new(0,1,0,1); img.Position=UDim2.new(2,0,2,0); img.Image="rbxthumb://type=Asset&id="..id.."&w=420&h=420"; img.Parent=preloadFolder; table.insert(assets, img)
	end
	pcall(function() ContentProvider:PreloadAsync(assets) end)
end)

local function playSoundInstant(soundObject) if soundObject.IsPlaying then soundObject:Stop() end; soundObject.TimePosition = 0; soundObject:Play() end

-- GUI CONSTRUCTION
local frame = Instance.new("Frame"); frame.Size = UDim2.new(0, 300, 0, 100); frame.Position = UDim2.new(0.5, -150, 0.75, 0); frame.BackgroundTransparency = 1; frame.Parent = screenGui
local iconContainer = Instance.new("Frame"); iconContainer.Size = UDim2.new(0, 80, 0, 80); iconContainer.Position = UDim2.new(0.5, -40, 0, 0); iconContainer.BackgroundColor3 = Color3.fromRGB(0, 0, 0); iconContainer.BackgroundTransparency = 0.4; iconContainer.Parent = frame
local uiCorner = Instance.new("UICorner"); uiCorner.CornerRadius = UDim.new(1,0); uiCorner.Parent = iconContainer; local uiStroke = Instance.new("UIStroke"); uiStroke.Thickness = 4; uiStroke.Color = Color3.fromRGB(255, 255, 255); uiStroke.Parent = iconContainer
local buttonImage = Instance.new("ImageLabel"); buttonImage.Size = UDim2.new(0.8, 0, 0.8, 0); buttonImage.AnchorPoint = Vector2.new(0.5, 0.5); buttonImage.Position = UDim2.new(0.5, 0, 0.5, 0); buttonImage.BackgroundTransparency = 1; buttonImage.ScaleType = Enum.ScaleType.Fit; buttonImage.Parent = iconContainer
local buttonText = Instance.new("TextLabel"); buttonText.Size = UDim2.new(1, 0, 1, 0); buttonText.BackgroundTransparency = 1; buttonText.TextColor3 = Color3.fromRGB(255, 255, 255); buttonText.TextSize = 35; buttonText.Font = Enum.Font.FredokaOne; buttonText.Parent = iconContainer
local timeBarBG = Instance.new("Frame"); timeBarBG.Size = UDim2.new(1, 0, 0, 15); timeBarBG.Position = UDim2.new(0, 0, 0.9, 0); timeBarBG.BackgroundColor3 = Color3.fromRGB(40, 40, 40); timeBarBG.BorderSizePixel = 0; timeBarBG.Parent = frame; local barCorner1 = Instance.new("UICorner"); barCorner1.Parent = timeBarBG
local timeBarFill = Instance.new("Frame"); timeBarFill.Size = UDim2.new(1, 0, 1, 0); timeBarFill.BackgroundColor3 = Color3.fromRGB(0, 255, 255); timeBarFill.BorderSizePixel = 0; timeBarFill.Parent = timeBarBG; local barCorner2 = Instance.new("UICorner"); barCorner2.Parent = timeBarFill

local function updateIcon(keyCode)
	local isConsole = (UserInputService:GetLastInputType() == Enum.UserInputType.Gamepad1)
	if isConsole and BUTTON_IDS[keyCode] then buttonText.Visible = false; buttonImage.Visible = true; buttonImage.Image = "rbxthumb://type=Asset&id=" .. BUTTON_IDS[keyCode] .. "&w=420&h=420"
	else buttonImage.Visible = false; buttonText.Visible = true; buttonText.Text = KEY_LABELS_PC[keyCode] or keyCode.Name end
end

-- ==============================================================================
-- VARIABLES LOGIQUES
-- ==============================================================================
local isActive = false
local currentTween = nil
local alphaValue = nil
local alphaConnection = nil
local qteSuccess = false
local isQTEComplete = false
local waitingForInput = false
local waitingAtTarget = false 
local currentSequenceFolder = nil
local currentTargetPart = nil 
local expectedKeyCode = nil
local currentTravelSpeed = 60
local cameraConnection = nil
local currentStickerConnection = nil 

-- VERROU GLOBAL
local isProcessingStep = false

local function loadAnim(id, loop)
	local anim = Instance.new("Animation"); anim.AnimationId = id
	local track = humanoid:LoadAnimation(anim); track.Priority = Enum.AnimationPriority.Action4; track.Looped = loop
	return track
end
local rollTrack = loadAnim(ROLL_ANIM_ID, false); local wallIdleTrack = loadAnim(WALL_IDLE_ID, true); local fallTrack = loadAnim(FALL_ANIM_ID, true) 

local function getSettings(part, settingName, defaultVal) local val = part:GetAttribute(settingName); if val ~= nil then return val end; return defaultVal end

local function getNextPart(currentPart) 
	if not currentPart or not currentSequenceFolder then return nil end
	local num = tonumber(currentPart.Name)
	if not num then return nil end
	return currentSequenceFolder:FindFirstChild(tostring(num + 1))
end

local function stopCinematicCamera() 
	if cameraConnection then cameraConnection:Disconnect(); cameraConnection = nil end; 
	camera.CameraType = Enum.CameraType.Custom 
end

local function cleanupMovement() 
	if currentTween then currentTween:Cancel(); currentTween = nil end
	if alphaConnection then alphaConnection:Disconnect(); alphaConnection = nil end
	if alphaValue then alphaValue:Destroy(); alphaValue = nil end
	if currentStickerConnection then currentStickerConnection:Disconnect(); currentStickerConnection = nil end
	stopCinematicCamera()
	if fallTrack then fallTrack:Stop(0.1) end 
end

local function stickPlayerTo(padPart)
	if currentStickerConnection then currentStickerConnection:Disconnect() end
	-- print("🧲 [DEBUG] Collage activé sur " .. padPart.Name)
	currentStickerConnection = RunService.RenderStepped:Connect(function()
		if not isActive or not padPart then 
			if currentStickerConnection then currentStickerConnection:Disconnect() end
			return 
		end
		rootPart.CFrame = padPart.CFrame * CFrame.Angles(0, math.pi, 0)
	end)
end

local function failSequence()
	if isQTEComplete and qteSuccess then return end 
	print("❌ [DEBUG] ECHEC SEQUENCE")
	isActive = false; isProcessingStep = false
	waitingForInput = false; waitingAtTarget = false; screenGui.Enabled = false
	character:SetAttribute("ActionChainActive", false) 
	currentSequenceFolder = nil
	cleanupMovement(); wallIdleTrack:Stop(0.1); task.delay(1, function() if fallTrack then fallTrack:Stop(0.2) end end)
	rootPart.Anchored = false; humanoid.AutoRotate = true; 
	local dir = rootPart.CFrame.LookVector; humanoid.PlatformStand = true; 
	rootPart.AssemblyLinearVelocity = dir * (currentTravelSpeed * 0.5); 
	task.delay(0.5, function() humanoid.PlatformStand = false end)
end

local function safeLookAt(origin, target)
	if (origin - target).Magnitude < 0.1 then return CFrame.new(origin) end
	return CFrame.lookAt(origin, target)
end

local function startCinematicCamera(targetPart)
	if cameraConnection then cameraConnection:Disconnect() end; camera.CameraType = Enum.CameraType.Scriptable

	local diff = (targetPart.Position - rootPart.Position)
	local startDir = (diff.Magnitude > 0.1) and diff.Unit or rootPart.CFrame.LookVector
	local rightVec = startDir:Cross(Vector3.new(0,1,0))
	local dynamicOffset = (-startDir * 15) + (Vector3.new(0, 8, 0)) + (rightVec * 5)

	cameraConnection = RunService.RenderStepped:Connect(function()
		if not rootPart or not targetPart then return end
		local idealPos = rootPart.Position + dynamicOffset
		local goalCF = safeLookAt(idealPos, targetPart.Position)
		camera.CFrame = camera.CFrame:Lerp(goalCF, CAM_SMOOTH)
	end)
end

local function finishSequence(finalPart)
	print("🏁 [DEBUG] FIN SEQUENCE")
	isActive = false; isProcessingStep = false
	screenGui.Enabled = false
	stopCinematicCamera()
	wallIdleTrack:Stop(0.1); fallTrack:Stop(0.1); rootPart.Anchored = false; humanoid.PlatformStand = true 
	rootPart.CFrame = rootPart.CFrame + Vector3.new(0, 2, 0)

	local exitSpeed = getSettings(finalPart, "RollSpeed", DEFAULT_SPEED)
	local exitDirection = finalPart.CFrame.LookVector

	rollTrack:Play()
	local bodyVel = Instance.new("BodyVelocity"); bodyVel.Velocity = exitDirection * exitSpeed; bodyVel.MaxForce = Vector3.new(100000, 100000, 100000); bodyVel.P = 50000; bodyVel.Parent = rootPart
	local gyro = Instance.new("BodyGyro"); gyro.MaxTorque = Vector3.new(400000, 400000, 400000)
	gyro.CFrame = safeLookAt(rootPart.Position, rootPart.Position + exitDirection)
	gyro.Parent = rootPart

	task.wait(rollTrack.Length * 0.9)
	rootPart.AssemblyLinearVelocity = exitDirection * exitSpeed
	if bodyVel then bodyVel:Destroy() end; if gyro then gyro:Destroy() end
	cleanupMovement()
	humanoid.PlatformStand = false; humanoid.AutoRotate = true; 
	character:SetAttribute("ActionChainActive", false)
	currentSequenceFolder = nil
	camera.CameraType = Enum.CameraType.Custom
end

local travelTo 

local function proceedSuccess(targetPart)
	-- ✅ PARE-FEU LOGIQUE : Si une décision a déjà été prise pour ce pad, on ignore les appels suivants.
	if isProcessingStep then 
		-- print("🔒 [DEBUG] Appel bloqué (Déjà traité)") 
		return 
	end
	isProcessingStep = true 

	print("✅ [DEBUG] Succès Pad " .. targetPart.Name)
	screenGui.Enabled = false; waitingForInput = false; waitingAtTarget = false; qteSuccess = true; isQTEComplete = true 

	rootPart.Anchored = true; rootPart.AssemblyLinearVelocity = Vector3.zero

	stickPlayerTo(targetPart)

	fallTrack:Stop(0.1); wallIdleTrack:Play(0.1)
	local pauseDuration = getSettings(targetPart, "Pause", DEFAULT_PAUSE); local nextPartObj = getNextPart(targetPart)

	task.delay(pauseDuration, function() 
		if not isActive then return end

		if currentStickerConnection then currentStickerConnection:Disconnect(); currentStickerConnection = nil end
		wallIdleTrack:Stop(0.1)

		if nextPartObj then 
			travelTo(targetPart, nextPartObj) 
		else 
			finishSequence(targetPart) 
		end 
	end)
end

travelTo = function(originPart, targetPart)
	isProcessingStep = false -- On déverrouille pour le nouveau saut
	-- print("🚀 [DEBUG] Saut " .. originPart.Name .. " -> " .. targetPart.Name)

	cleanupMovement()

	local nextPartObj = getNextPart(targetPart); local isFinalJump = (nextPartObj == nil) 
	if originPart.Name == "1" then playSoundInstant(soundFirst) else playSoundInstant(soundDetach) end

	currentTargetPart = targetPart; waitingAtTarget = false; qteSuccess = false; isQTEComplete = false
	rootPart.Anchored = true; humanoid.PlatformStand = true; humanoid.AutoRotate = false; wallIdleTrack:Stop(); fallTrack:Play(0.1) 
	currentTravelSpeed = getSettings(originPart, "Speed", DEFAULT_SPEED); local customKeyName = getSettings(targetPart, "Key", ""); local qteTimeAllowed = getSettings(targetPart, "QteTime", DEFAULT_QTE_TIME); local arcHeight = getSettings(originPart, "ArcHeight", nil) 

	local startPos = rootPart.Position 
	-- 🧠 SMART TRACKING - ETAPE 1 : Capture Position Initiale de la Cible
	local initialTargetPos = targetPart.Position

	local initialDist = (initialTargetPos - startPos).Magnitude
	local duration = initialDist / currentTravelSpeed
	if arcHeight == nil then arcHeight = initialDist / 4.5 end

	local useCine = targetPart:GetAttribute("CinematicCamera"); if useCine == true then startCinematicCamera(targetPart) else stopCinematicCamera() end
	if not isFinalJump then task.delay(math.max(0, duration - 0.25), function() if isActive and not waitingAtTarget then fallTrack:Stop(0.2); wallIdleTrack:Play(0.2) end end) end

	alphaValue = Instance.new("NumberValue"); alphaValue.Value = 0

	-- 🧠 SMART TRACKING - ETAPE 2 : Boucle de mouvement intelligente
	alphaConnection = alphaValue.Changed:Connect(function(t)
		local currentTargetPos = targetPart.Position

		-- DÉTECTION DE MOUVEMENT
		-- Si la plateforme n'a quasiment pas bougé depuis le début du saut, on utilise la position FIXE initiale
		-- Cela évite les tremblements et les conflits de calcul
		if (currentTargetPos - initialTargetPos).Magnitude < MOVEMENT_THRESHOLD then
			currentTargetPos = initialTargetPos -- Mode Statique (Stable)
		else
			-- Mode Dynamique (La plateforme bouge vraiment, on suit)
		end

		local linearPos = startPos:Lerp(currentTargetPos, t)

		local curveOffset = Vector3.new(0,0,0)
		if arcHeight > 0 then local height = arcHeight * 4 * t * (1 - t); curveOffset = Vector3.new(0, height, 0) end

		local lookCF = safeLookAt(rootPart.Position, currentTargetPos)
		rootPart.CFrame = CFrame.new(linearPos + curveOffset) * lookCF.Rotation
	end)

	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear); currentTween = TweenService:Create(alphaValue, tweenInfo, {Value = 1}); currentTween:Play()

	if not isFinalJump then
		task.spawn(function()
			local startTimeDelay = math.max(0, duration - qteTimeAllowed)
			task.wait(startTimeDelay); if not isActive or isQTEComplete then return end
			waitingForInput = true; local keyNameSelection = customKeyName; if keyNameSelection == "" then keyNameSelection = RANDOM_KEYS[math.random(1, #RANDOM_KEYS)] end
			local inputType = UserInputService:GetLastInputType(); if inputType == Enum.UserInputType.Gamepad1 then expectedKeyCode = KEY_DEFINITIONS[keyNameSelection].Console else expectedKeyCode = KEY_DEFINITIONS[keyNameSelection].PC end
			screenGui.Enabled = true; updateIcon(expectedKeyCode); timeBarFill.BackgroundColor3 = Color3.fromRGB(0, 255, 255) 
			local timerStart = tick()
			while (tick() - timerStart) < qteTimeAllowed and waitingForInput and isActive and not isQTEComplete do
				local percent = 1 - ((tick() - timerStart) / qteTimeAllowed); timeBarFill.Size = UDim2.new(percent, 0, 1, 0); RunService.Heartbeat:Wait()
			end
			if isActive and not isQTEComplete then if qteSuccess then return end; failSequence() end
		end)
	end

	currentTween.Completed:Connect(function()
		if not isActive then return end
		if currentTween then currentTween:Cancel(); currentTween = nil end
		if alphaConnection then alphaConnection:Disconnect(); alphaConnection = nil end
		if alphaValue then alphaValue:Destroy(); alphaValue = nil end

		if isFinalJump then
			finishSequence(targetPart)
		else
			playSoundInstant(soundAttach)
			rootPart.Anchored = true; rootPart.CFrame = targetPart.CFrame * CFrame.Angles(0, math.pi, 0)

			-- Décision Unique
			if qteSuccess then 
				proceedSuccess(targetPart)
			else 
				waitingAtTarget = true; fallTrack:Stop(0.1); wallIdleTrack:Play(0.1)
				stickPlayerTo(targetPart)
			end
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not isActive or not waitingForInput or isQTEComplete then return end

	if input.KeyCode == expectedKeyCode then
		isQTEComplete = true; waitingForInput = false; qteSuccess = true
		timeBarFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0) 
		buttonImage.Visible = false; buttonText.Visible = true; buttonText.Text = "OK!"

		if waitingAtTarget then 
			if currentStickerConnection then currentStickerConnection:Disconnect() end
			proceedSuccess(currentTargetPart) 
		end
	else
		local isGameKey = false; for _, def in pairs(KEY_DEFINITIONS) do if input.KeyCode == def.PC or input.KeyCode == def.Console then isGameKey = true break end end
		if isGameKey then failSequence() end
	end
end)

rootPart.Touched:Connect(function(hit)
	if isActive then return end
	if not isPhase2MechanicActive then return end
	if character:GetAttribute("IsInCutscene") then return end
	if hit.Name == "1" and hit.Parent and hit.Parent.Parent and hit.Parent.Parent.Name == "ActionSequences" then
		currentSequenceFolder = hit.Parent; local part2 = getNextPart(hit)
		if part2 then isActive = true; character:SetAttribute("ActionChainActive", true); timeBarFill.BackgroundColor3 = Color3.fromRGB(0, 255, 255); humanoid.AutoRotate = false; travelTo(hit, part2) end
	end
end)