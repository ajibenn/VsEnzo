--[[
    MoonUtil (ModuleScript)
    Path: ReplicatedStorage → Moon2Cutscene
    Parent: Moon2Cutscene
    ⚠️  NESTED SCRIPT: This script is inside another script
    Exported: 2026-01-28 16:22:14
]]
local module = {}
local easingFunctions = require(script.Parent.easingFunctions)
local effects = script.Parent.Effects

local _, _, vignette = require(effects.vignette)()
vignette.ImageTransparency = 1

local effects = {
	Letterbox = require(effects.letterbox)(),
	Vignette = vignette,
	["Screen Cover"] = require(effects.screen_cover)(),
	["Subtitles"] = require(effects.subtitle)()
}

function module.getObjectFromPath(path:table, map)
	if path.ItemType and path.ItemType == "Camera" then
		return workspace.CurrentCamera
	end
	
	if path.InstanceNames[3] == "MoonAnimatorEffects" then
		if effects[path.InstanceNames[4]] then
			return effects[path.InstanceNames[4]]
		end
	end

	local obj = map or game
	for i, n in path.InstanceNames do
		if i <= (map and 2 or 1) then
			continue
		end

		local hasNotFound = true
		for _,v in obj:GetChildren() do
			if v.Name == n and v:IsA(path.InstanceTypes[i]) then
				obj = v
				hasNotFound = nil
				break
			end
		end

		if hasNotFound then
			return
		end
	end

	return obj
end

local function findFirstDescendantWhichIsAOfName(a:string, name:string, ancestor:Instance)
	for _,v in ancestor:GetDescendants() do
		if v:IsA(a) and v.Name == name then
			return v
		end
	end
end

function module.getMotor(rig, name:string):Motor6D
	local path = string.split(name, ".")
	local obj = findFirstDescendantWhichIsAOfName("BasePart", path[#path], rig)

	for _, v: Instance in rig:GetDescendants() do
		if v:IsA("Motor6D") then
			if v.Part1 == obj then
				return v
			end
		end
	end
	
	-- motor not found, check bones
	
	for _, v: Instance in rig:GetDescendants() do
		if v:IsA("Bone") and v.Name == path[1] then
			for i = 2, #path do
				v = v:FindFirstChild(path[i])
				if not v then
					break
				end
			end
			
			if not v then
				continue
			end
			
			return v
		end
	end
end

function module.getEase(ease:{string}|nil)
	ease = ease or {}
	ease[1] = ease[1] or "Linear"
	ease[2] = ease[2] or ""

	return easingFunctions[ease[1]..ease[2]]
end

function module.getFrames(timeElapsed:number, keyframes:keyframes) : keyframeData
	local orderedFrames = {}
	for frame in keyframes do
		if tonumber(frame) then
			table.insert(orderedFrames, frame)
		end
	end

	local flast, fnext
	table.sort(orderedFrames)

	for index, frame in orderedFrames do
		if frame > timeElapsed then
			flast, fnext = index-1, index
			break
		end
	end

	flast, fnext = orderedFrames[flast], orderedFrames[fnext]
	return 	orderedFrames,
			keyframes[flast], flast or 0,
			keyframes[fnext], fnext
end

function module.getKeyFrames(self)
	local f = {Rig = {}, Properties = {}}
	
	for objIndex:number, properties:properties in self.objs do
		for property:string, keyframes:keyframes in properties do
			if property == "Rig" then
				for layer_ind, layer in keyframes do
					for jointKey, keyframes:keyframes in layer do
						local joint = module.getMotor(self.instances[objIndex], jointKey)						
						f.Rig[joint] = keyframes
					end
				end
				
				continue
			end
			
			f.Properties[self.instances[objIndex]] = {property, keyframes}
		end
	end
	
	return f
end

return module
