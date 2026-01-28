--[[
    Phase1Module (ModuleScript)
    Path: ServerStorage
    Parent: ServerStorage
    Exported: 2026-01-28 16:22:15
]]
-- MODULESCRIPT : Phase1Module (VERSION FINALE - ANTI-CHUTE)
local Phase1 = {}

-- SERVICES
local task = task
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

-- ==========================================
-- 🛠️ CONFIGURATION
-- ==========================================

-- VISUEL DRAPEAUX
Phase1.FLAG_VERTICAL_FIX = 0    
Phase1.FLAG_HIDDEN_DEPTH = 15   
Phase1.FLAG_RISE_HEIGHT = 30    

-- ESPACEMENT & ZONE
Phase1.AOE_RADIUS = 3.2         
Phase1.MIN_SPACING = 11.0       
Phase1.AOE_HITBOX_HEIGHT = 50   

-- GAMEPLAY BOSS
Phase1.STOP_RANGE = 8           
Phase1.VITESSE = 17 
Phase1.UPDATE_RATE = 0.1
Phase1.GLOBAL_COOLDOWN_TIME = 0.8 

-- IDs ANIMATIONS
Phase1.IDLE_ANIM_ID = "rbxassetid://86580915614930"
Phase1.WALK_ANIM_ID = "rbxassetid://98268863317729"
Phase1.SPELL_ANIM_ID = "rbxassetid://115145622000352"
Phase1.PREPARE_ANIM_ID = "rbxassetid://85635640764116"
Phase1.DASH_ANIM_ID = "rbxassetid://122165938127940"
Phase1.AOE_ANIM_ID = "rbxassetid://134931473247771"

-- COMBAT
Phase1.AOE_TRIGGER_RANGE = 14    
Phase1.AOE_PROBA_FAR = 5 

-- STATS MODE NORMAL
Phase1.AOE_DAMAGE_NORMAL = 35           
Phase1.AOE_KNOCKBACK_NORMAL = 3500
Phase1.AOE_COOLDOWN_NORMAL = 8.0   
Phase1.AOE_ANIM_SPEED_NORMAL = 1.0      

-- STATS MODE PUNITION
Phase1.AOE_DAMAGE_PUNISH = 60           
Phase1.AOE_KNOCKBACK_PUNISH = 6000      
Phase1.AOE_COOLDOWN_PUNISH = 3.5        
Phase1.AOE_WARNING_PUNISH = 0.6         
Phase1.AOE_ANIM_SPEED_PUNISH = 2.0      

local FLAG_MODEL_NAME = "Portugalflag"
local BALLOON_MODEL_NAME = "foot"

Phase1.DISTANCE_MIN = 16
Phase1.DISTANCE_MAX = 60
Phase1.COOLDOWN_SPELL = 4.0
Phase1.DAMAGE_SPELL = 20
Phase1.PROJECTILE_SPEED = 90
Phase1.LAUNCH_OFFSET = 5
Phase1.SPELL_CAST_TIME = 0.8 

-- DASH STATS
Phase1.DASH_COOLDOWN = 7.0
Phase1.DASH_DAMAGE = 30
Phase1.DASH_KNOCKBACK_FORCE = 70 
Phase1.DASH_KNOCKBACK_UP = 90    
Phase1.TIME_PREPARATION = 1.5
Phase1.TIME_DASH_DURATION = 0.9   
Phase1.DASH_HITBOX_SIZE = Vector3.new(9, 7, 9) 

-- ÉTAT
local isAttacking = false
local lastSpellTime = 0
local lastDashTime = 0
local lastAoeTime = 0
local globalCooldownEnd = 0

-- UTILITAIRES
local function getDistance(posA, posB) 
	return (posA - posB).Magnitude 
end

local function dealDamage(targetHumanoid, amount)
	if targetHumanoid and targetHumanoid.Health > 0 then
		targetHumanoid:TakeDamage(amount)
	end
end

local function faceTarget(root, targetPos)
	local lookPos = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
	root.CFrame = CFrame.lookAt(root.Position, lookPos)
end

local function weldParts(part0, part1)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part0
	return weld
end

-- === ANIMATIONS ===
function Phase1.SetupWalkAnimation(humanoid) 
	local a = Instance.new("Animation"); a.AnimationId = Phase1.WALK_ANIM_ID
	local t = humanoid:WaitForChild("Animator"):LoadAnimation(a); t.Priority = Enum.AnimationPriority.Movement
	return t
end
function Phase1.SetupIdleAnimation(humanoid) 
	local a = Instance.new("Animation"); a.AnimationId = Phase1.IDLE_ANIM_ID
	local t = humanoid:WaitForChild("Animator"):LoadAnimation(a); t.Priority = Enum.AnimationPriority.Idle
	return t
end
function Phase1.SetupSpellAnimation(humanoid) 
	local a = Instance.new("Animation"); a.AnimationId = Phase1.SPELL_ANIM_ID
	local t = humanoid:WaitForChild("Animator"):LoadAnimation(a); t.Priority = Enum.AnimationPriority.Action
	return t
end
function Phase1.SetupDashAnimations(humanoid)
	local a1 = Instance.new("Animation"); a1.AnimationId = Phase1.PREPARE_ANIM_ID
	local t1 = humanoid:WaitForChild("Animator"):LoadAnimation(a1); t1.Priority = Enum.AnimationPriority.Action
	local a2 = Instance.new("Animation"); a2.AnimationId = Phase1.DASH_ANIM_ID
	local t2 = humanoid:WaitForChild("Animator"):LoadAnimation(a2); t2.Priority = Enum.AnimationPriority.Action
	return t1, t2 
end
function Phase1.SetupAoeAnimation(humanoid)
	local a = Instance.new("Animation"); a.AnimationId = Phase1.AOE_ANIM_ID
	local t = humanoid:WaitForChild("Animator"):LoadAnimation(a); t.Priority = Enum.AnimationPriority.Action
	return t
end

-- GESTION ÉTAT MOUVEMENT
local function updateMovementState(isMoving, walkTrack, idleTrack)
	if isAttacking then 
		if walkTrack.IsPlaying then walkTrack:Stop() end
		if idleTrack.IsPlaying then idleTrack:Stop() end
		return 
	end
	if isMoving then
		if not walkTrack.IsPlaying then walkTrack:Play() end
		if idleTrack.IsPlaying then idleTrack:Stop() end
	else
		if walkTrack.IsPlaying then walkTrack:Stop() end
		if not idleTrack.IsPlaying then idleTrack:Play() end
	end
end
function Phase1.ConnectAnimationLogic(humanoid, walkTrack, idleTrack) end 

-- === ATTAQUES ===

-- A. ZONE PORTUGAL
local function executeAoeAttack(bossModel, targetCharacter, aoeTrack, walkTrack, idleTrack, isPunishment)
	if isAttacking then return end

	local flagModelRef = ReplicatedStorage:FindFirstChild(FLAG_MODEL_NAME)
	if not flagModelRef then return end 

	isAttacking = true
	local humanoid = bossModel:FindFirstChild("Humanoid")
	local root = bossModel.PrimaryPart

	faceTarget(root, targetCharacter.PrimaryPart.Position)

	-- CONFIGURATION
	local dmg = isPunishment and Phase1.AOE_DAMAGE_PUNISH or Phase1.AOE_DAMAGE_NORMAL
	local force = isPunishment and Phase1.AOE_KNOCKBACK_PUNISH or Phase1.AOE_KNOCKBACK_NORMAL
	local warnTime = isPunishment and Phase1.AOE_WARNING_PUNISH or 1.0
	local flagCount = isPunishment and 30 or 12 
	local zoneRadius = isPunishment and 25 or 40
	local animSpeed = isPunishment and Phase1.AOE_ANIM_SPEED_PUNISH or Phase1.AOE_ANIM_SPEED_NORMAL

	humanoid:MoveTo(root.Position)
	humanoid.WalkSpeed = 0

	if walkTrack.IsPlaying then walkTrack:Stop() end
	if idleTrack.IsPlaying then idleTrack:Stop() end

	if aoeTrack then 
		aoeTrack.Looped = false
		aoeTrack:Play()
		aoeTrack:AdjustSpeed(animSpeed)
	end

	task.spawn(function()
		local success, err = pcall(function()
			local centerPos = root.Position
			local warningFolder = Instance.new("Folder", workspace)
			warningFolder.Name = "AoeWarnings"
			Debris:AddItem(warningFolder, 10)

			local rayParams = RaycastParams.new()
			rayParams.FilterDescendantsInstances = {bossModel, warningFolder, targetCharacter}
			rayParams.FilterType = Enum.RaycastFilterType.Exclude

			local validSpawnPoints = {} 
			local attempts = 0
			local maxAttempts = 200 

			if isPunishment and targetCharacter and targetCharacter.PrimaryPart then
				local playerPos = targetCharacter.PrimaryPart.Position
				local rayOrigin = playerPos + Vector3.new(0, 5, 0)
				local rayResult = workspace:Raycast(rayOrigin, Vector3.new(0, -20, 0), rayParams)

				if rayResult then
					table.insert(validSpawnPoints, rayResult.Position)
					local zone = Instance.new("Part")
					zone.Parent = warningFolder
					zone.Shape = Enum.PartType.Cylinder
					zone.Color = Color3.fromRGB(255, 0, 0)
					zone.Material = Enum.Material.Neon
					zone.Transparency = 0.5
					zone.Anchored = true; zone.CanCollide = false; zone.CastShadow = false
					zone.Size = Vector3.new(0.2, Phase1.AOE_RADIUS * 2, Phase1.AOE_RADIUS * 2) 
					zone.CFrame = CFrame.new(rayResult.Position) * CFrame.Angles(0, 0, math.rad(90))
				end
			end

			while #validSpawnPoints < flagCount and attempts < maxAttempts do
				attempts += 1
				local angle = math.rad(math.random(0, 360))
				local r = math.random(40, zoneRadius * 10) / 10 
				local offsetX = math.cos(angle) * r
				local offsetZ = math.sin(angle) * r

				local rayOrigin = centerPos + Vector3.new(offsetX, 5, offsetZ)
				local rayDir = Vector3.new(0, -50, 0)
				local rayResult = workspace:Raycast(rayOrigin, rayDir, rayParams)

				if rayResult then 
					local finalPos = rayResult.Position
					local tooClose = false
					local spacing = Phase1.MIN_SPACING

					for _, existingPoint in ipairs(validSpawnPoints) do
						if (finalPos - existingPoint).Magnitude < spacing then
							tooClose = true; break
						end
					end

					if not tooClose then
						table.insert(validSpawnPoints, finalPos)
						local zone = Instance.new("Part")
						zone.Parent = warningFolder
						zone.Shape = Enum.PartType.Cylinder
						zone.Color = Color3.fromRGB(255, 0, 0)
						zone.Material = Enum.Material.Neon
						zone.Transparency = 0.5
						zone.Anchored = true; zone.CanCollide = false; zone.CastShadow = false
						zone.Size = Vector3.new(0.2, Phase1.AOE_RADIUS * 2, Phase1.AOE_RADIUS * 2) 
						zone.CFrame = CFrame.new(finalPos) * CFrame.Angles(0, 0, math.rad(90))
					end
				end
			end

			task.wait(warnTime) 
			warningFolder:Destroy()

			for _, pos in ipairs(validSpawnPoints) do
				for _, player in ipairs(Players:GetPlayers()) do
					if player.Character and player.Character.PrimaryPart then
						local pPos = player.Character.PrimaryPart.Position
						local distH = (Vector3.new(pPos.X, 0, pPos.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
						local distV = math.abs(pPos.Y - pos.Y)
						if distH <= Phase1.AOE_RADIUS and distV <= Phase1.AOE_HITBOX_HEIGHT then
							local hum = player.Character:FindFirstChild("Humanoid")
							if hum then
								dealDamage(hum, dmg) 
								local hrp = player.Character:FindFirstChild("HumanoidRootPart")
								if hrp then hrp:ApplyImpulse(Vector3.new(0, force, 0)) end 
							end
						end
					end
				end
			end

			local activeFlags = {}
			for i, pos in ipairs(validSpawnPoints) do
				local flag = flagModelRef:Clone()
				flag.Parent = workspace

				if not flag.PrimaryPart then
					for _, desc in pairs(flag:GetDescendants()) do
						if desc:IsA("BasePart") then flag.PrimaryPart = desc; break end
					end
				end

				if flag.PrimaryPart then
					flag.PrimaryPart.Anchored = true 
					flag.PrimaryPart.CanCollide = false
					for _, desc in pairs(flag:GetDescendants()) do
						if desc:IsA("BasePart") and desc ~= flag.PrimaryPart then
							desc.Anchored = false 
							desc.CanCollide = false
							weldParts(flag.PrimaryPart, desc)
						end
					end

					local groundPos = pos + Vector3.new(0, Phase1.FLAG_VERTICAL_FIX, 0)
					local startPos = groundPos - Vector3.new(0, Phase1.FLAG_HIDDEN_DEPTH, 0)
					local startCF = CFrame.new(startPos) * CFrame.Angles(0, math.rad(math.random(0,360)), 0)

					flag:PivotTo(startCF)
					table.insert(activeFlags, flag)

					local targetCF = startCF + Vector3.new(0, Phase1.FLAG_RISE_HEIGHT, 0)
					local tween = TweenService:Create(flag.PrimaryPart, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {CFrame = targetCF})
					tween:Play()
				else
					flag:Destroy()
				end
			end

			task.wait(1.5) 

			for _, flag in ipairs(activeFlags) do
				if flag.PrimaryPart then
					local downCF = flag.PrimaryPart.CFrame - Vector3.new(0, Phase1.FLAG_RISE_HEIGHT, 0)
					local tween = TweenService:Create(flag.PrimaryPart, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {CFrame = downCF})
					tween:Play()
				end
			end

			task.wait(0.5) 
			for _, flag in ipairs(activeFlags) do flag:Destroy() end
		end)

		if not success then warn("🔴 CRASH AOE: " .. tostring(err)) end

		if aoeTrack then aoeTrack:Stop() end
		humanoid.WalkSpeed = Phase1.VITESSE
		lastAoeTime = os.clock()
		globalCooldownEnd = os.clock() + Phase1.GLOBAL_COOLDOWN_TIME
		updateMovementState(false, walkTrack, idleTrack) 
		isAttacking = false 
	end)
end

-- B. SORT
local function executeSpellAttack(bossModel, targetCharacter, spellTrack, walkTrack, idleTrack)
	if isAttacking then return end
	local BALLOON_REF = ReplicatedStorage:FindFirstChild(BALLOON_MODEL_NAME)
	if not BALLOON_REF then return end

	isAttacking = true
	local humanoid = bossModel:FindFirstChild("Humanoid")
	local root = bossModel.PrimaryPart

	faceTarget(root, targetCharacter.PrimaryPart.Position)
	humanoid:MoveTo(root.Position)
	humanoid.WalkSpeed = 0
	if walkTrack.IsPlaying then walkTrack:Stop() end
	if idleTrack.IsPlaying then idleTrack:Stop() end
	if spellTrack then spellTrack:Play() end

	task.spawn(function()
		task.wait(Phase1.SPELL_CAST_TIME) 
		if targetCharacter and targetCharacter.PrimaryPart then
			local startPos = root.Position + (root.CFrame.LookVector * Phase1.LAUNCH_OFFSET) + Vector3.new(0, 2, 0)
			local direction = (targetCharacter.PrimaryPart.Position - startPos).Unit
			local projectile = BALLOON_REF:Clone()
			projectile.Parent = workspace

			local pPart = projectile.PrimaryPart or projectile:FindFirstChildWhichIsA("BasePart")
			if pPart then
				pPart.CFrame = CFrame.new(startPos, startPos + direction)
				pPart.AssemblyLinearVelocity = direction * Phase1.PROJECTILE_SPEED
				local bf = Instance.new("BodyForce", pPart)
				bf.Force = Vector3.new(0, pPart:GetMass() * workspace.Gravity, 0)
				local hitCo
				hitCo = pPart.Touched:Connect(function(hit)
					if hit:IsDescendantOf(bossModel) then return end
					local h = hit.Parent:FindFirstChild("Humanoid")
					if h then
						dealDamage(h, Phase1.DAMAGE_SPELL)
						local hrp = hit.Parent:FindFirstChild("HumanoidRootPart")
						if hrp then hrp:ApplyImpulse(direction * 500) end
						hitCo:Disconnect(); projectile:Destroy()
					else
						task.delay(0.1, function() projectile:Destroy() end)
					end
				end)
				Debris:AddItem(projectile, 3)
			else projectile:Destroy() end
		end
		task.wait(0.6) 
		if spellTrack then spellTrack:Stop() end
		humanoid.WalkSpeed = Phase1.VITESSE
		lastSpellTime = os.clock()
		globalCooldownEnd = os.clock() + Phase1.GLOBAL_COOLDOWN_TIME 
		updateMovementState(false, walkTrack, idleTrack)
		isAttacking = false
	end)
end

-- C. DASH (ANTI-CHUTE ABSOLU)
local function executeDashAttack(bossModel, targetCharacter, preparationTrack, dashTrack, walkTrack, idleTrack)
	if isAttacking then return end
	local humanoid = bossModel:FindFirstChild("Humanoid")
	local root = bossModel.PrimaryPart
	isAttacking = true

	faceTarget(root, targetCharacter.PrimaryPart.Position)
	humanoid:MoveTo(root.Position)
	humanoid.WalkSpeed = 0
	if walkTrack.IsPlaying then walkTrack:Stop() end
	if idleTrack.IsPlaying then idleTrack:Stop() end

	local distToPlayer = (targetCharacter.PrimaryPart.Position - root.Position).Magnitude
	local calculatedSpeed = math.clamp(distToPlayer * 2.5, 60, 110) 

	if preparationTrack then preparationTrack:Play() end
	local startPrep = os.clock()
	while (os.clock() - startPrep) < Phase1.TIME_PREPARATION do
		if targetCharacter and targetCharacter.PrimaryPart then
			faceTarget(root, targetCharacter.PrimaryPart.Position)
		end
		RunService.Heartbeat:Wait()
	end
	if preparationTrack then preparationTrack:Stop() end

	local dashDirection = root.CFrame.LookVector
	local flatDir = Vector3.new(dashDirection.X, 0, dashDirection.Z).Unit 
	humanoid.PlatformStand = true
	local bodyVel = Instance.new("BodyVelocity")
	bodyVel.MaxForce = Vector3.new(100000, 100000, 100000) 
	bodyVel.Velocity = flatDir * calculatedSpeed
	bodyVel.Parent = root
	local bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bodyGyro.CFrame = root.CFrame
	bodyGyro.Parent = root
	if dashTrack then dashTrack:Play() end

	local hasHit = false
	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = {bossModel} 
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	local startDash = os.clock()

	while (os.clock() - startDash) < Phase1.TIME_DASH_DURATION do
		if hasHit then break end
		local boxCenter = root.CFrame * CFrame.new(0, 3, 0)
		local hits = workspace:GetPartBoundsInBox(boxCenter, Phase1.DASH_HITBOX_SIZE, overlapParams)
		for _, part in ipairs(hits) do
			local char = part.Parent
			local hum = char:FindFirstChild("Humanoid")
			if hum and char == targetCharacter then
				hasHit = true

				-- 1. IMPACT JOUEUR (COURBE)
				dealDamage(hum, Phase1.DASH_DAMAGE)
				local enemyRoot = char:FindFirstChild("HumanoidRootPart")
				if enemyRoot then 
					local kickDir = (enemyRoot.Position - root.Position).Unit * Vector3.new(1,0,1)
					enemyRoot.AssemblyLinearVelocity = kickDir * Phase1.DASH_KNOCKBACK_FORCE + Vector3.new(0, Phase1.DASH_KNOCKBACK_UP, 0)
				end

				-- 2. RESET PHYSIQUE INSTANTANÉ
				if root:FindFirstChild("BodyVelocity") then root.BodyVelocity:Destroy() end
				if root:FindFirstChild("BodyGyro") then root.BodyGyro:Destroy() end

				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero

				-- 3. REDRESSEUR DE TORTS (LE FIX)
				-- On force le Boss a être parfaitement droit avant de l'ancrer
				local currentY = root.Rotation.Y
				root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.rad(currentY), 0)

				-- 4. FREEZE
				root.Anchored = true
				humanoid.PlatformStand = false

				if dashTrack then dashTrack:Stop() end
				if idleTrack then idleTrack:Play() end

				task.wait(1.0) 
				root.Anchored = false 
				break 

			elseif part.CanCollide and not hum then
				if part.Name ~= "Baseplate" and part.Name ~= "Terrain" then hasHit = true; break end
			end
		end
		RunService.Heartbeat:Wait()
	end

	if root:FindFirstChild("BodyVelocity") then root.BodyVelocity:Destroy() end
	if root:FindFirstChild("BodyGyro") then root.BodyGyro:Destroy() end

	root.AssemblyLinearVelocity = Vector3.zero
	humanoid.PlatformStand = false
	root.Anchored = false

	if dashTrack then dashTrack:Stop() end
	task.wait(0.5)
	humanoid.WalkSpeed = Phase1.VITESSE
	lastDashTime = os.clock()
	globalCooldownEnd = os.clock() + Phase1.GLOBAL_COOLDOWN_TIME
	updateMovementState(false, walkTrack, idleTrack)
	isAttacking = false
end

-- === CERVEAU ===
function Phase1.StartChase(bossModel, targetPlayer, spellTrack, walkTrack, preparationTrack, dashTrack, aoeTrack, idleTrack)
	local humanoid = bossModel:WaitForChild("Humanoid")
	local character = targetPlayer.Character
	if not character or not character.PrimaryPart or humanoid.Health <= 0 then return end
	local bossRoot = bossModel.PrimaryPart
	local distance = getDistance(bossRoot.Position, character.PrimaryPart.Position)
	if bossRoot.Anchored then bossRoot.Anchored = false end
	if isAttacking then return end

	-- 0. PUNITION CORPS-A-CORPS
	if distance < 10 then 
		if (os.clock() - lastAoeTime) >= Phase1.AOE_COOLDOWN_PUNISH then
			executeAoeAttack(bossModel, character, aoeTrack, walkTrack, idleTrack, true)
			return
		end
	end

	-- GLOBAL COOLDOWN
	if os.clock() < globalCooldownEnd then
		humanoid.WalkSpeed = Phase1.VITESSE
		if distance > Phase1.STOP_RANGE then
			humanoid:MoveTo(character.PrimaryPart.Position)
			updateMovementState(true, walkTrack, idleTrack)
		else
			humanoid:MoveTo(bossRoot.Position)
			faceTarget(bossRoot, character.PrimaryPart.Position)
			updateMovementState(false, walkTrack, idleTrack)
		end
		return
	end

	-- 1. Attaque Zone Normale
	if distance < Phase1.AOE_TRIGGER_RANGE then
		if (os.clock() - lastAoeTime) >= Phase1.AOE_COOLDOWN_NORMAL then
			executeAoeAttack(bossModel, character, aoeTrack, walkTrack, idleTrack, false)
			return
		end
	end

	-- 2. RNG Lointaine
	if distance > 25 and (os.clock() - lastAoeTime) >= Phase1.AOE_COOLDOWN_NORMAL then
		local rng = math.random(1, 100)
		if rng <= Phase1.AOE_PROBA_FAR then
			executeAoeAttack(bossModel, character, aoeTrack, walkTrack, idleTrack, false)
			return
		end
	end

	-- 3. Dash
	if distance >= 20 and distance <= 65 then
		if (os.clock() - lastDashTime) >= Phase1.DASH_COOLDOWN then
			executeDashAttack(bossModel, character, preparationTrack, dashTrack, walkTrack, idleTrack)
			return
		end
	end

	-- 4. Sort
	if distance >= Phase1.DISTANCE_MIN and distance <= Phase1.DISTANCE_MAX then
		if (os.clock() - lastSpellTime) >= Phase1.COOLDOWN_SPELL then
			executeSpellAttack(bossModel, character, spellTrack, walkTrack, idleTrack)
			return
		end
	end

	-- 5. Marche
	humanoid.WalkSpeed = Phase1.VITESSE
	if distance > Phase1.STOP_RANGE then
		humanoid:MoveTo(character.PrimaryPart.Position)
		updateMovementState(true, walkTrack, idleTrack)
	else
		humanoid:MoveTo(bossRoot.Position)
		faceTarget(bossRoot, character.PrimaryPart.Position)
		updateMovementState(false, walkTrack, idleTrack)
	end
end

return Phase1