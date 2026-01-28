--[[
    TrickRampSystem (LocalScript)
    Path: StarterPlayer → StarterCharacterScripts
    Parent: StarterCharacterScripts
    Properties:
        Disabled: false
    Exported: 2026-01-28 16:22:15
]]
-- LOCAL SCRIPT : TrickRampSystem (V77 - RAMP DOCTOR & NAN SHIELD)
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
local cleanup 
local currentActionID = 0 

GameState.PhaseChanged:Connect(function(newPhase)
	if newPhase == 2 then
		isPhase2MechanicActive = true
		print("✅ TrickRamp ACTIVÉ (Phase 2)")
	else
		isPhase2MechanicActive = false
		if cleanup then cleanup(currentActionID) end 
	end
end)

if GameState:GetPhase() == 2 then isPhase2MechanicActive = true end

-- CONFIGURATION
local DEFAULT_SEQ_LENGTH = 3 
local DEFAULT_TIME_PER_KEY = 0.8 
local DEFAULT_SPEED = 120 
local DEFAULT_QTE_DISTANCE = 30 

local FALL_ANIM_ID = "rbxassetid://119021926553736" 
local ROLL_ANIM_ID = "rbxassetid://136598973225722" 
local LAND_ANIM_ID = "rbxassetid://106085806177949" 

local SFX_IDS = {FAIL="rbxassetid://125135213267585", SUCCESS="rbxassetid://115928164544633", INPUT="rbxassetid://79812549735880", URGENCY="rbxassetid://122998275603683", TENSION="rbxassetid://136289466101064"}
local SFX_VOLUME = 1.5
local BUTTON_IDS = {[Enum.KeyCode.ButtonA]="82820478009774", [Enum.KeyCode.ButtonX]="122341303036820", [Enum.KeyCode.ButtonY]="76913173810725", [Enum.KeyCode.ButtonB]="131925613200177"}
local KEY_DEFINITIONS = {["Z"]={PC=Enum.KeyCode.W, Console=Enum.KeyCode.ButtonY}, ["Q"]={PC=Enum.KeyCode.A, Console=Enum.KeyCode.ButtonX}, ["S"]={PC=Enum.KeyCode.S, Console=Enum.KeyCode.ButtonA}, ["D"]={PC=Enum.KeyCode.D, Console=Enum.KeyCode.ButtonB}, ["Jump"]={PC=Enum.KeyCode.Space, Console=Enum.KeyCode.ButtonA}}
local RANDOM_KEYS = {"Z", "Q", "S", "D"} 
local KEY_LABELS_PC = {[Enum.KeyCode.W]="Z", [Enum.KeyCode.A]="Q", [Enum.KeyCode.S]="S", [Enum.KeyCode.D]="D", [Enum.KeyCode.Space]="SPACE"}

local sounds = {}
local isActive = false; local isResolving = false; local isStageComplete = false 

-- 🏥 LE DOCTEUR : VALIDATION DE LA RAMPE
local function checkRampIntegrity(rampPart)
	local folder = rampPart.Parent
	if not folder then warn("🛑 RAMP ERROR: Pas de dossier parent !"); return false end

	-- 1. Check WIN
	local winPart = folder:FindFirstChild("Win")
	if not winPart then warn("🛑 RAMP ERROR: Pas de part 'Win' dans " .. folder.Name); return false end

	-- 2. Check Distance (Anti-NaN)
	local dist = (winPart.Position - rampPart.Position).Magnitude
	if dist < 2 then
		warn("🛑 RAMP ERROR: La part 'Win' est trop proche de 'Start' (Distance: " .. dist .. "). Cela crée un bug mathématique (NaN). Éloignez-la !")
		return false
	end

	-- 3. Check Vitesse
	local speed = rampPart:GetAttribute("Speed") or DEFAULT_SPEED
	if speed <= 0 then warn("🛑 RAMP ERROR: Vitesse nulle ou négative !"); return false end

	return true
end

-- Audio Setup
for name, id in pairs(SFX_IDS) do local s=Instance.new("Sound"); s.Name="SFX_"..name; s.SoundId=id; s.Volume=SFX_VOLUME; s.Parent=rootPart; sounds[name]=s end
task.spawn(function() local a={}; for _,s in pairs(sounds) do table.insert(a,s) end; pcall(function() ContentProvider:PreloadAsync(a) end) end)
local function getSound(n) return rootPart:FindFirstChild("SFX_"..n) end
local function playInstant(n) local s=getSound(n); if s then s:Stop(); s.TimePosition=0; s:Play() end end
local function playTensionSmart(t) local s=getSound("TENSION"); if not s then return end; s:Stop(); if s.TimeLength==0 then s.Loaded:Wait() end; local l=s.TimeLength; s.PlaybackSpeed=1; s.Volume=SFX_VOLUME; if t>=l then task.delay(t-l, function() if isActive and not isResolving and not isStageComplete then s.TimePosition=0; s:Play() end end) else s.TimePosition=l-t; s:Play() end end
local function stopTension() local s=getSound("TENSION"); if s then s:Stop() end end

-- GUI Setup
local rampGui = Instance.new("ScreenGui"); rampGui.Name="TrickRamp_HUD"; rampGui.Parent=playerGui; rampGui.Enabled=false
local mainFrame = Instance.new("Frame"); mainFrame.Size=UDim2.new(0,400,0,150); mainFrame.Position=UDim2.new(0.5,-200,0.7,0); mainFrame.BackgroundTransparency=1; mainFrame.Parent=rampGui
local buttonsContainer = Instance.new("Frame"); buttonsContainer.Size=UDim2.new(1,0,0,80); buttonsContainer.BackgroundTransparency=1; buttonsContainer.Parent=mainFrame
local layout = Instance.new("UIListLayout"); layout.FillDirection=Enum.FillDirection.Horizontal; layout.HorizontalAlignment=Enum.HorizontalAlignment.Center; layout.Padding=UDim.new(0,15); layout.Parent=buttonsContainer
local timerBG = Instance.new("Frame"); timerBG.Name="TimerBG"; timerBG.Size=UDim2.new(0.6,0,0,10); timerBG.Position=UDim2.new(0.2,0,0.9,0); timerBG.BackgroundColor3=Color3.fromRGB(50,50,50); timerBG.BorderSizePixel=0; timerBG.Parent=mainFrame; Instance.new("UICorner",timerBG).CornerRadius=UDim.new(1,0)
local timerFill = Instance.new("Frame"); timerFill.Name="Fill"; timerFill.Size=UDim2.new(1,0,1,0); timerFill.BackgroundColor3=Color3.fromRGB(255,255,0); timerFill.BorderSizePixel=0; timerFill.Parent=timerBG; Instance.new("UICorner",timerFill).CornerRadius=UDim.new(1,0)

local function createButtonDisplay(k, c)
	local f=Instance.new("Frame"); f.Size=UDim2.new(0,70,0,70); f.BackgroundColor3=Color3.fromRGB(0,0,0); f.BackgroundTransparency=0.4; Instance.new("UICorner",f).CornerRadius=UDim.new(1,0); local s=Instance.new("UIStroke"); s.Thickness=3; s.Color=Color3.fromRGB(255,255,255); s.Parent=f
	if c and BUTTON_IDS[k] then local i=Instance.new("ImageLabel"); i.Size=UDim2.new(0.8,0,0.8,0); i.AnchorPoint=Vector2.new(0.5,0.5); i.Position=UDim2.new(0.5,0,0.5,0); i.BackgroundTransparency=1; i.Image="rbxthumb://type=Asset&id="..BUTTON_IDS[k].."&w=420&h=420"; i.ScaleType=Enum.ScaleType.Fit; i.ZIndex=5; i.Parent=f
	else local t=Instance.new("TextLabel"); t.Size=UDim2.new(1,0,1,0); t.BackgroundTransparency=1; t.TextColor3=Color3.fromRGB(255,255,255); t.TextSize=24; t.Font=Enum.Font.FredokaOne; t.Text=KEY_LABELS_PC[k] or k.Name; t.ZIndex=5; t.Parent=f end
	return f
end

local currentSequence={}; local currentIndex=1; local guiElements={}; local currentSequenceFolder=nil; local currentRampSpeed=DEFAULT_SPEED; local currentRampPart=nil
local stagesList={}; local currentStageIndex=0; local approachConnection=nil; local flightConnection=nil; local cameraConnection=nil; local stageTimerStart=0; local stageDuration=0

local function loadAnim(id, loop) if not id or id=="" then return nil end; if type(id)=="string" and not id:match("rbxassetid://") then id="rbxassetid://"..id end; local a=Instance.new("Animation"); a.AnimationId=id; local t=humanoid:LoadAnimation(a); t.Priority=Enum.AnimationPriority.Action4; t.Looped=loop; return t end
local fallTrack=loadAnim(FALL_ANIM_ID,true); local rollTrack=loadAnim(ROLL_ANIM_ID,false); local landTrack=loadAnim(LAND_ANIM_ID,false); local specialTrickTrack=nil; local trickConn=nil

cleanup = function(sourceID)
	if sourceID ~= currentActionID then return end
	isActive=false; isResolving=false; isStageComplete=false; rampGui.Enabled=false
	character:SetAttribute("ActionChainActive",false); character:SetAttribute("IsResolvingQTE",false)
	stopTension(); RunService:UnbindFromRenderStep("TrickVisEnforcer")
	for _,v in pairs(guiElements) do v:Destroy() end; guiElements={}; stagesList={}; currentStageIndex=0
	if approachConnection then approachConnection:Disconnect(); approachConnection=nil end
	if flightConnection then flightConnection:Disconnect(); flightConnection=nil end
	if cameraConnection then cameraConnection:Disconnect(); cameraConnection=nil end
	if trickConn then trickConn:Disconnect(); trickConn=nil end
	if fallTrack then fallTrack:Stop(0.2) end
	if specialTrickTrack then specialTrickTrack:Stop(0.2); specialTrickTrack=nil end
	if rollTrack then rollTrack:Stop(0.1) end
	if landTrack then landTrack:Stop(0.1) end

	player.CameraMinZoomDistance = 0.5 
	for _, part in pairs(character:GetDescendants()) do if part:IsA("BasePart") then part.LocalTransparencyModifier = 0 end end
	rootPart.Anchored=false; humanoid.PlatformStand=false; humanoid.AutoRotate=true; camera.CameraType=Enum.CameraType.Custom
end

local function enableVisibilityEnforcer()
	RunService:BindToRenderStep("TrickVisEnforcer", Enum.RenderPriority.Last.Value, function()
		for _, part in pairs(character:GetDescendants()) do if part:IsA("BasePart") and part.Name~="HumanoidRootPart" then part.LocalTransparencyModifier = 0 end end
	end)
end

local function startCameraTracking(mode)
	if cameraConnection then cameraConnection:Disconnect() end
	camera.CameraType = Enum.CameraType.Scriptable
	local CAM_QTE_OFFSET = Vector3.new(0, 2.5, 9); local CAM_FLY_OFFSET = Vector3.new(0, 4, 14); local CAM_SMOOTHNESS = 0.15 

	cameraConnection = RunService.RenderStepped:Connect(function(dt)
		if not rootPart then return end

		-- 🛑 MODIFICATION ICI : SI UNE ZONE CAMERA EST ACTIVE, ON LÂCHE L'AFFAIRE
		if character:GetAttribute("ZoneCameraOverride") == true then
			return -- On laisse le script de zone gérer la caméra
		end

		local targetOffset = (mode == "Approach") and CAM_QTE_OFFSET or CAM_FLY_OFFSET
		local playerCF = rootPart.CFrame
		local idealCamPos = rootPart.Position - (playerCF.LookVector * targetOffset.Z) + Vector3.new(0, targetOffset.Y, 0)
		local lookAtPos = rootPart.Position + (playerCF.LookVector * 10)
		if (idealCamPos - rootPart.Position).Magnitude < 1 then idealCamPos = rootPart.Position - (playerCF.LookVector * 5) + Vector3.new(0, 5, 0) end

		camera.Focus = playerCF
		local goalCF = CFrame.lookAt(idealCamPos, lookAtPos)
		camera.CFrame = camera.CFrame:Lerp(goalCF, CAM_SMOOTHNESS)
	end)
end

local function performLanding(targetPart)
	if specialTrickTrack then specialTrickTrack:Stop(0.1) end
	if fallTrack then fallTrack:Stop(0.1) end
	rootPart.Anchored=false; humanoid.PlatformStand=false; rootPart.AssemblyLinearVelocity=Vector3.zero 
	local exitDirection=targetPart.CFrame.LookVector; local canRoll=targetPart:GetAttribute("CanRoll"); if canRoll==nil then canRoll=true end 
	if canRoll then
		humanoid.PlatformStand=true; rollTrack:Play()
		local rollSpeed=targetPart:GetAttribute("RollSpeed") or currentRampSpeed
		local flatDir=Vector3.new(exitDirection.X,0,exitDirection.Z).Unit
		local bodyVel=Instance.new("BodyVelocity"); bodyVel.Velocity=flatDir*rollSpeed; bodyVel.MaxForce=Vector3.new(100000,0,100000); bodyVel.P=50000; bodyVel.Parent=rootPart
		local gyro=Instance.new("BodyGyro"); gyro.MaxTorque=Vector3.new(400000,400000,400000); gyro.CFrame=CFrame.lookAt(rootPart.Position,rootPart.Position+flatDir); gyro.Parent=rootPart
		task.wait(rollTrack.Length*0.9)
		rootPart.AssemblyLinearVelocity=flatDir*rollSpeed
		if bodyVel then bodyVel:Destroy() end; if gyro then gyro:Destroy() end
		humanoid.PlatformStand=false
		local isShift=UserInputService:IsKeyDown(Enum.KeyCode.LeftShift); local isL3=UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL3)
		if isShift or isL3 then character:SetAttribute("ForceSprint",true); task.delay(0.2, function() character:SetAttribute("ForceSprint",false) end) end
	else
		landTrack:Play(); rootPart.AssemblyLinearVelocity=exitDirection*(currentRampSpeed*0.5); task.wait(0.2)
	end
	rootPart.AssemblyLinearVelocity=Vector3.new(exitDirection.X,0,exitDirection.Z).Unit*currentRampSpeed 
	cleanup(currentActionID)
end

local function flyToDestination(targetPart, success)
	rampGui.Enabled=false; stopTension(); startCameraTracking("Flight")
	local startPos=rootPart.Position; local endPos=targetPart.Position; local distance=(endPos-startPos).Magnitude; local duration=distance/currentRampSpeed
	local arcHeight=(targetPart:GetAttribute("ArcHeight") and targetPart:GetAttribute("ArcHeight")>0) and targetPart:GetAttribute("ArcHeight") or (distance/4)
	local startTime=tick(); local lookDirection=CFrame.lookAt(startPos, endPos).Rotation
	flightConnection = RunService.Heartbeat:Connect(function()
		humanoid.PlatformStand=true 
		local isTrickPlaying=(specialTrickTrack and specialTrickTrack.IsPlaying)
		if not isTrickPlaying and fallTrack and not fallTrack.IsPlaying then fallTrack:Play(0); fallTrack:AdjustWeight(1.0) end
		local elapsed=tick()-startTime; local t=math.clamp(elapsed/duration, 0, 1)
		local linearPos=startPos:Lerp(endPos, t); local heightCurve=arcHeight*4*t*(1-t); local nextPos=linearPos+Vector3.new(0,heightCurve,0)

		-- 🛡️ PROTECTION NAN (Not A Number)
		if nextPos.X~=nextPos.X or nextPos.Y~=nextPos.Y or nextPos.Z~=nextPos.Z then
			warn("🛑 FATAL ERROR: Position invalide (NaN) détectée en vol ! Arrêt d'urgence."); cleanup(currentActionID); return
		end

		rootPart.CFrame=CFrame.new(nextPos)*lookDirection
		if t>=1 then flightConnection:Disconnect(); performLanding(targetPart) end
	end)
end

local function onStageComplete()
	isStageComplete=true 
	if currentStageIndex<#stagesList then
		playInstant("SUCCESS"); currentStageIndex=currentStageIndex+1; local cfg=stagesList[currentStageIndex]
		for _,v in pairs(guiElements) do v:Destroy() end; guiElements={}; currentSequence={}; currentIndex=1
		local isConsole=(UserInputService:GetLastInputType()==Enum.UserInputType.Gamepad1)
		for i=1,cfg.Length do
			local rk=RANDOM_KEYS[math.random(1,#RANDOM_KEYS)]; local kd=KEY_DEFINITIONS[rk]; local ak=isConsole and kd.Console or kd.PC
			table.insert(currentSequence,ak); local btn=createButtonDisplay(ak,isConsole); btn.Parent=buttonsContainer; table.insert(guiElements,btn)
		end
		stageDuration=cfg.Time*cfg.Length; stageTimerStart=tick(); playTensionSmart(stageDuration)
		isResolving=false; isStageComplete=false; character:SetAttribute("IsResolvingQTE",false)
	else
		if approachConnection then approachConnection:Disconnect() end
		stopTension(); playInstant("SUCCESS"); timerFill.BackgroundColor3=Color3.new(0,1,0)
		if specialTrickTrack then if fallTrack then fallTrack:Stop(0.1) end; specialTrickTrack:Play(0.1)
		else if fallTrack then fallTrack:Stop(); fallTrack.Looped=true; fallTrack:Play(0); fallTrack:AdjustWeight(1.0) end end
		local winP=currentSequenceFolder:FindFirstChild("Win"); flyToDestination(winP, true)
	end
end

local function failTrick()
	if isActive==false or isResolving or isStageComplete then return end
	isResolving=true; character:SetAttribute("IsResolvingQTE",true)
	for _,v in pairs(guiElements) do v.BackgroundColor3=Color3.new(1,0,0) end
	local loosePart=currentSequenceFolder:FindFirstChild("Loose")
	if loosePart then 
		if approachConnection then approachConnection:Disconnect() end; stopTension(); playInstant("FAIL"); timerFill.BackgroundColor3=Color3.new(1,0,0)
		if specialTrickTrack then specialTrickTrack:Stop(0.1) end; if fallTrack then fallTrack:Stop(); fallTrack:Play(0) end
		flyToDestination(loosePart, false)
	else cleanup(currentActionID) end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not isActive or isResolving or isStageComplete or not rampGui.Enabled then return end 
	if not isPhase2MechanicActive or GameState:GetCutscene() then return end
	if input.KeyCode==currentSequence[currentIndex] then
		local btn=guiElements[currentIndex]; btn.BackgroundColor3=Color3.fromRGB(0,255,0); btn.UIStroke.Color=Color3.fromRGB(0,255,0); playInstant("INPUT"); currentIndex=currentIndex+1
		if currentIndex>#currentSequence then isResolving=true; isStageComplete=true; character:SetAttribute("IsResolvingQTE",true); task.wait(0.05); onStageComplete() end
	else
		local isGameKey=false; for _,def in pairs(KEY_DEFINITIONS) do if input.KeyCode==def.PC or input.KeyCode==def.Console then isGameKey=true; break end end
		if isGameKey then failTrick() end
	end
end)

local function startTrickSequence(rampPart)
	-- 🏥 CHECKUP AVANT LANCEMENT
	if not checkRampIntegrity(rampPart) then return end

	currentActionID=currentActionID+1; isActive=true; isResolving=false; isStageComplete=false
	character:SetAttribute("ActionChainActive",true); character:SetAttribute("IsResolvingQTE",false)
	player.CameraMinZoomDistance=10; enableVisibilityEnforcer()
	currentSequenceFolder=rampPart.Parent; currentRampPart=rampPart; stagesList={}
	local stageCount=1
	while true do local len=rampPart:GetAttribute("Stage"..stageCount.."_Len"); local time=rampPart:GetAttribute("Stage"..stageCount.."_Time"); if len and time and len>0 then table.insert(stagesList,{Length=len,Time=time}); stageCount=stageCount+1 else break end end
	if #stagesList==0 then local dl=rampPart:GetAttribute("SequenceLength") or DEFAULT_SEQ_LENGTH; local dt=rampPart:GetAttribute("TimePerKey") or DEFAULT_TIME_PER_KEY; table.insert(stagesList,{Length=dl,Time=dt}) end
	currentRampSpeed=rampPart:GetAttribute("Speed") or DEFAULT_SPEED; local qteDist=rampPart:GetAttribute("QTEDistance") or DEFAULT_QTE_DISTANCE
	rootPart.Anchored=true; humanoid.PlatformStand=true; startCameraTracking("Approach")
	local anims=humanoid:FindFirstChild("Animator"); if anims then for _,t in pairs(anims:GetPlayingAnimationTracks()) do t:Stop(0) end end
	if fallTrack then fallTrack:Stop() end; fallTrack=loadAnim(FALL_ANIM_ID,true); if fallTrack then fallTrack:Play(0) end
	if specialTrickTrack then specialTrickTrack:Stop(); specialTrickTrack=nil end
	local airTrickID=currentRampPart:GetAttribute("AirTrickID"); if airTrickID then specialTrickTrack=loadAnim(airTrickID,false) end
	currentStageIndex=1; local firstCfg=stagesList[1]; currentSequence={}; guiElements={}; currentIndex=1
	for _,v in pairs(buttonsContainer:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end
	local isConsole=(UserInputService:GetLastInputType()==Enum.UserInputType.Gamepad1)
	for i=1,firstCfg.Length do local rk=RANDOM_KEYS[math.random(1,#RANDOM_KEYS)]; local kd=KEY_DEFINITIONS[rk]; local ak=isConsole and kd.Console or kd.PC; table.insert(currentSequence,ak); local btn=createButtonDisplay(ak,isConsole); btn.Parent=buttonsContainer; table.insert(guiElements,btn) end
	local winP=currentSequenceFolder:FindFirstChild("Win"); if not winP then cleanup(currentActionID); return end
	rampGui.Enabled=true; stageDuration=firstCfg.Time*firstCfg.Length; stageTimerStart=tick(); playTensionSmart(stageDuration)
	local startPos=rootPart.Position; local moveDir=(winP.Position-startPos).Unit; local distanceTraveled=0; local urgencyPlayed=false
	if approachConnection then approachConnection:Disconnect() end
	approachConnection=RunService.Heartbeat:Connect(function()
		if not isActive or isStageComplete then return end
		local now=tick(); local elapsedStage=now-stageTimerStart
		local currentSpeed=currentRampSpeed; local progress=distanceTraveled/qteDist
		if progress<0.5 then currentSpeed=currentRampSpeed elseif progress<1.0 then local sf=(progress-0.5)*2; currentSpeed=currentRampSpeed*(1-sf)+(5*sf) else currentSpeed=5 end
		local stepDist=currentSpeed*RunService.Heartbeat:Wait(); distanceTraveled=distanceTraveled+stepDist
		rootPart.CFrame=CFrame.lookAt(rootPart.Position+(moveDir*stepDist),winP.Position)
		local timeLeft=stageDuration-elapsedStage; local uiPercent=math.clamp(timeLeft/stageDuration,0,1)
		timerFill.Size=UDim2.new(uiPercent,0,1,0); timerFill.BackgroundColor3=Color3.fromHSV(uiPercent*0.3,1,1)
		if uiPercent<0.3 and not urgencyPlayed then urgencyPlayed=true; playInstant("URGENCY") elseif uiPercent>0.5 then urgencyPlayed=false end
		if elapsedStage>stageDuration then failTrick() end
	end)
end

rootPart.Touched:Connect(function(hit)
	if not isPhase2MechanicActive or GameState:GetCutscene() then return end
	if hit.Name == "Start" and hit.Parent and hit.Parent.Parent and hit.Parent.Parent.Name == "TrickRamps" then startTrickSequence(hit) end
end)