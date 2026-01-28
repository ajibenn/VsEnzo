--[[
    CameraZoneSystem (LocalScript)
    Path: StarterPlayer → StarterPlayerScripts
    Parent: StarterPlayerScripts
    Properties:
        Disabled: false
    Exported: 2026-01-28 16:22:15
]]
-- LOCAL SCRIPT : CameraZoneSystem (V27 - TRIGGER MEMORY FIX)
-- PLACEMENT : StarterPlayerScripts

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

local sysFolder = Workspace:WaitForChild("CameraSystem", 5)
local triggersFolder = sysFolder:WaitForChild("Triggers")
local boardsFolder = sysFolder:WaitForChild("Boards") 
local nodesFolder = sysFolder:WaitForChild("Nodes")

-- 🎛️ DEBUG
local SHOW_DEBUG_ZONES = true 

-- VARIABLES D'ÉTAT
local currentTargetNode = nil 
local activeNode = nil        
local lastUsedNode = nil      

-- MÉMOIRE
local lastGateNode = nil       -- Mémoire des Boards (Passages)
local lastValidTriggerNode = nil -- 🆕 Mémoire des Triggers (Zones d'action)

-- TRANSITION
local transitionAlpha = 0     
local currentCinematicCFrame = nil 

-- LISSAGE
local smoothCamPos = nil 
local smoothLookAt = nil 

-- ====================================================================
-- 🛠️ SETUP VISUEL
-- ====================================================================
local function setupParts(folder, color)
	for _, part in ipairs(folder:GetChildren()) do
		if part:IsA("BasePart") then
			part.Transparency = 1 
			part.CanCollide = false
			part.CastShadow = false
			part.CanQuery = true 
			part.CanTouch = true
			part.Anchored = true

			if SHOW_DEBUG_ZONES then
				local h = Instance.new("SelectionBox"); h.Adornee = part; h.Color3 = color
				h.LineThickness = 0.05; h.Transparency = 0.5; h.Parent = part
				if folder.Name == "Nodes" then
					local f = Instance.new("SurfaceGui"); f.Face = Enum.NormalId.Front; f.Parent = part
					local t = Instance.new("Frame"); t.Size = UDim2.new(1,0,1,0); t.BackgroundColor3 = color; t.BackgroundTransparency = 0.5; t.Parent = f
				end
			end
			part.Touched:Connect(function() end) 
		end
	end
end
setupParts(triggersFolder, Color3.new(0, 1, 0)) 
setupParts(boardsFolder, Color3.new(1, 0, 0))   
setupParts(nodesFolder, Color3.new(1, 0, 1))    

local function getPriority(part)
	return part:GetAttribute("Priority") or 0
end

-- ====================================================================
-- 🎥 BOUCLE PRINCIPALE
-- ====================================================================
RunService:BindToRenderStep("GLVL_CameraSystem", Enum.RenderPriority.Camera.Value + 5, function(dt)
	if not rootPart then return end

	-- 1. DETECTION SPATIALE
	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = {character}
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	local partsInZone = Workspace:GetPartBoundsInBox(rootPart.CFrame, Vector3.new(4, 4, 4), overlapParams)

	local bestTriggerNode = nil
	local bestTriggerPriority = -99999
	local touchedBoard = nil

	for _, part in ipairs(partsInZone) do
		if part.Parent == triggersFolder then
			local prio = getPriority(part)
			if prio > bestTriggerPriority then
				local targetName = part:GetAttribute("TargetNode")
				local node = nodesFolder:FindFirstChild(targetName or "")
				if node then
					bestTriggerPriority = prio
					bestTriggerNode = node
				end
			end
		end
		if part.Parent == boardsFolder then touchedBoard = part end
	end

	-- 🆕 MISE A JOUR MÉMOIRE TRIGGER
	-- Si on voit un Trigger valide, on le sauvegarde comme "Le dernier Trigger vu"
	if bestTriggerNode then
		lastValidTriggerNode = bestTriggerNode
	end

	-- 2. ETAT DU JOUEUR (LOCK)
	local isLockedByAction = (character:GetAttribute("SwingActive") == true and rootPart.Anchored == true)

	-- 3. MISE A JOUR MÉMOIRE GATE (Seulement si pas locké)
	if not isLockedByAction and touchedBoard then
		local relPos = touchedBoard.CFrame:PointToObjectSpace(rootPart.Position)
		if relPos.Z < 0 then 
			local targetName = touchedBoard:GetAttribute("TargetNode")
			local node = nodesFolder:FindFirstChild(targetName or "")
			if node then lastGateNode = node end
		else 
			local prevName = touchedBoard:GetAttribute("PreviousNode")
			local node = nodesFolder:FindFirstChild(prevName or "")
			if node then lastGateNode = node else lastGateNode = nil end
		end
	end

	-- 4. LE JUGE (HIÉRARCHIE AVEC FILET DE SÉCURITÉ)
	local winnerNode = nil

	if isLockedByAction then
		-- 🔒 MODE VERROUILLÉ (Sur la barre)
		if bestTriggerNode then
			-- Cas A : Tout va bien, on est dans la zone
			winnerNode = bestTriggerNode
		elseif lastValidTriggerNode then
			-- Cas B (LE FIX) : On est sorti un peu de la zone, MAIS on est toujours sur la barre.
			-- On force l'utilisation du dernier Trigger connu au lieu de retomber sur le Board.
			winnerNode = lastValidTriggerNode
		else
			-- Cas C : Vraiment perdu (rare), on garde ce qu'on a
			winnerNode = currentTargetNode 
		end
	else
		-- 🔓 MODE LIBRE
		-- On reset la mémoire trigger "forcée" pour ne pas rester bloqué dessus plus tard
		-- (Optionnel, mais plus propre : on laisse la priorité gérer)

		if bestTriggerNode then
			winnerNode = bestTriggerNode
		elseif lastGateNode then
			winnerNode = lastGateNode
		else
			winnerNode = nil
		end
	end

	-- 5. CHANGEMENT DE CIBLE
	if winnerNode ~= currentTargetNode then
		currentTargetNode = winnerNode

		if currentTargetNode then
			activeNode = currentTargetNode
			if not currentCinematicCFrame then currentCinematicCFrame = camera.CFrame end
			smoothCamPos = nil
			smoothLookAt = nil
		end
	end

	-- ====================================================================
	-- SUITE STANDARD (VISUEL)
	-- ====================================================================

	-- 6. CALCUL ALPHA
	local easeInTime = 0.5
	local easeOutTime = 0.5
	local refNode = currentTargetNode or lastUsedNode
	if refNode then
		easeInTime = refNode:GetAttribute("EaseEnter") or 0.5
		easeOutTime = refNode:GetAttribute("EaseExit") or 0.5
	end

	local targetAlpha = 0
	local alphaSpeed = 1

	if currentTargetNode then
		targetAlpha = 1
		alphaSpeed = 1 / math.max(0.01, easeInTime)
		lastUsedNode = currentTargetNode 
	else
		targetAlpha = 0
		alphaSpeed = 1 / math.max(0.01, easeOutTime)
	end

	if transitionAlpha < targetAlpha then
		transitionAlpha = math.min(transitionAlpha + (dt * alphaSpeed), targetAlpha)
	elseif transitionAlpha > targetAlpha then
		transitionAlpha = math.max(transitionAlpha - (dt * alphaSpeed), targetAlpha)
	end

	if transitionAlpha <= 0 and not currentTargetNode then
		character:SetAttribute("CinematicActive", false)
		currentCinematicCFrame = nil 
		return 
	end

	character:SetAttribute("CinematicActive", true)

	-- 7. CALCUL TARGET POSITION
	local targetCFrame = camera.CFrame 

	if lastUsedNode then
		local camMode = lastUsedNode:GetAttribute("Mode")
		local node = lastUsedNode

		if camMode == "FIXED" then
			targetCFrame = node.CFrame

		elseif camMode == "PAN" then
			targetCFrame = CFrame.lookAt(node.Position, rootPart.Position)

		elseif camMode == "PARALLEL" or camMode == "POINT" then
			local offX = node:GetAttribute("OffsetX") or 0
			local offY = node:GetAttribute("OffsetY") or 10
			local offZ = node:GetAttribute("OffsetZ") or 20

			local relativeOffset = Vector3.new(offX, offY, offZ)
			local forceDist = node:GetAttribute("Distance")
			if forceDist and forceDist > 0 and relativeOffset.Magnitude > 0 then
				relativeOffset = relativeOffset.Unit * forceDist
				player.CameraMinZoomDistance = forceDist; player.CameraMaxZoomDistance = forceDist
			end

			local rotatedOffset = node.CFrame:VectorToWorldSpace(relativeOffset)
			local targetPos = rootPart.Position + rotatedOffset
			local targetLook = rootPart.Position

			if camMode == "PARALLEL" then
				local lookAhead = node:GetAttribute("LookAhead") or 1.5
				local velocity = rootPart.AssemblyLinearVelocity
				targetLook = rootPart.Position + (velocity * 0.1 * lookAhead)
			elseif camMode == "POINT" then
				targetLook = node.Position
			end

			if not smoothCamPos then smoothCamPos = targetPos end
			if not smoothLookAt then smoothLookAt = targetLook end

			smoothCamPos = smoothCamPos:Lerp(targetPos, 0.2)

			if camMode == "PARALLEL" then
				smoothLookAt = smoothLookAt:Lerp(targetLook, 0.2)
				targetCFrame = CFrame.lookAt(smoothCamPos, smoothLookAt)
			else
				targetCFrame = CFrame.lookAt(smoothCamPos, node.Position)
			end
		end
	end

	-- 8. LISSAGE GLOBAL
	if not currentCinematicCFrame then currentCinematicCFrame = camera.CFrame end
	local globalSmoothFactor = math.clamp(dt * (3 / math.max(0.1, easeInTime)), 0, 1)

	if isLockedByAction then globalSmoothFactor = globalSmoothFactor * 0.5 end

	local mode = lastUsedNode and lastUsedNode:GetAttribute("Mode")
	if mode == "FIXED" or mode == "PAN" then
		currentCinematicCFrame = currentCinematicCFrame:Lerp(targetCFrame, globalSmoothFactor)
	else
		currentCinematicCFrame = currentCinematicCFrame:Lerp(targetCFrame, 0.5)
	end

	-- 9. BLEND
	local playerCamCFrame = camera.CFrame
	local blendFactor = TweenService:GetValue(transitionAlpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	if transitionAlpha >= 0.99 then
		camera.CFrame = currentCinematicCFrame
	else
		camera.CFrame = playerCamCFrame:Lerp(currentCinematicCFrame, blendFactor)
	end

	local customFOV = lastUsedNode and lastUsedNode:GetAttribute("FOV") or 70
	local currentBaseFOV = 70
	camera.FieldOfView = currentBaseFOV + (customFOV - currentBaseFOV) * blendFactor
end)