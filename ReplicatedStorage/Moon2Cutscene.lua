--[[
    Moon2Cutscene (ModuleScript)
    Path: ReplicatedStorage
    Parent: ReplicatedStorage
    Exported: 2026-01-28 16:22:14
]]
local module = {}
module.__index = module

local transforms = require(script.transforms)
local moonUtil = require(script.MoonUtil)
local taskManager = require(script.TaskManager)

type keyframeData = {
	ease:string?,
	value:any
}

type keyframes = {
	[number]:keyframeData,
	default:any
}

type properties = {
	[string]:keyframes
}

export type cutsceneType = {
	objs:{number:properties},
	FPS:number,
	task:taskManager.manager,
	
	addObj:(self) -> nil,
	replace:(self, number) -> nil,
	setFrame:(self, timeElapsed:number) -> nil,
	
	play:(self, restart:boolean) -> nil,
	stop:(self) -> nil,
	isPlaying:(self) -> boolean,
	wait:(self) -> nil,
	
	canFindObjects:(self) -> boolean,
	waitForObjects:(self) -> nil,
}

local effects = script.Effects
module.subtitle = require(effects.subtitle)
module.vignette = require(effects.vignette)
module.fade = require(effects.fade)
module.letterbox = require(effects.letterbox)

function module.new(file:StringValue, map, dontClone:boolean?):cutsceneType
	local self = setmetatable({}, module)
	self.instance = file
	self.file = game:GetService("HttpService"):JSONDecode(file.Value)
	self.FPS = self.file.Information.FPS or 60
	self.instances = {}
	self.timeElapsed = 0
	
	self.task = taskManager.new()
	self.map = map and not dontClone and map:Clone() or map

	return self
end

function computeObjects(self:cutsceneType)
	self.objs = {}
	
	for _,v in self.instance:GetChildren() do
		module.addObj(self, v)
	end
	
	return self.objs
end

local function setPlaying(self, b:boolean)
	self.playing = b
	workspace:SetAttribute("cutscene", b and self.instance.Name or nil)
end

function module.play(self:cutsceneType, restart:boolean?)
	if restart then
		self.task:clone()
		computeObjects(self)
		self.timeElapsed = 0
	end
	
	if self.map then
		self.map.Parent = workspace
	end
	
	if not self.task.cloned then
		self.task:clone()
	end
	
	game:GetService("RunService"):BindToRenderStep("cutscene_play", Enum.RenderPriority.Camera.Value + 1, function(dt)
		self.timeElapsed += dt * self.FPS
		for i,v in self.task.cloned do
			if tonumber(i) and i <= self.timeElapsed then
				self.task.run(v)
				self.task.cloned[i] = nil
			end
		end
		
		local ended = module.setFrame(self, self.timeElapsed)
		if ended then
			self.task.run(self.task.cloned[true])
			self:stop()
		end
	end)
	
	setPlaying(self, true)
end

function module.wait(self:cutsceneType)
	if not self.playing then
		return
	end
	
	local cor = coroutine.running()
	self.task:onEnd(function()
		coroutine.resume(cor)
	end, true)
	
	return coroutine.yield()
end

function module.stop(self:cutsceneType)
	if self.playing then
		game:GetService("RunService"):UnbindFromRenderStep("cutscene_play")
		setPlaying(self, nil)
	end
end

function module.isPlaying(self:cutsceneType)
	return self.playing
end

function module.canFindObjects(self:cutsceneType)
	for _,v in self.file.Items do
		if not moonUtil.getObjectFromPath(v.Path, self.map) then
			return false, v
		end
	end
	
	return true
end

function module.waitForObjects(self:cutsceneType)
	if not self:canFindObjects() then
		repeat task.wait() until self:canFindObjects()
	end
end

local unsupported = {"MarkerTrack"}
local ignore = {"_RigContainer_collapsed", "_PropertyContainer_collapsed"}
function module.addObj(self:cutsceneType, obj:Folder)
	local objIndex = tonumber(obj.Name)
	self.objs[objIndex] = {}
	self.instances[objIndex] = self.instances[objIndex] or moonUtil.getObjectFromPath(self.file.Items[objIndex].Path, self.map)

	local function getEasingData(keyframe)
		local ease if keyframe:FindFirstChild("Eases") then
			ease = {keyframe:FindFirstChild("Eases") and keyframe.Eases["0"].Type.Value}

			if keyframe.Eases["0"]:FindFirstChild("Params") then
				ease[2] = keyframe.Eases["0"].Params.Direction.Value
			end
		end
		
		return ease
	end
	
	for _, propType in obj:GetChildren() do
		if table.find(ignore, propType.Name) then
			continue
		end
		
		if table.find(unsupported, propType.Name) then
			warn(propType, "is unsupported")
			continue
		end
		
		if propType.Name == "Rig" then
			self.objs[objIndex].Rig = {}
			
			for _, joint in propType:GetChildren() do
				if #joint._keyframes:GetChildren() == 0 then
					print(joint, joint._hier.Value, "has no keyframes")
					continue
				end
				
				local j = moonUtil.getMotor(self.instances[objIndex], joint._hier.Value)

				if not j then
					print("Missing joint")
					print("index:", objIndex)
					print("path:", joint._hier.Value)
					continue
				end
				
				local layer = #joint._hier.Value:split(".")
				self.objs[objIndex].Rig[layer] = self.objs[objIndex].Rig[layer] or {}
				self.objs[objIndex].Rig[layer][joint._hier.Value] = {default = joint.default.Value, joint = j}
				
				for _, keyframe in joint._keyframes:GetChildren() do
					local i = tonumber(keyframe.Name)
					if not i then
						continue
					end
					
					local ease = getEasingData(keyframe)
					for _,n in keyframe.Values:GetChildren() do						
						local e = tonumber(n.Name)
						if not e then continue end
						
						self.objs[objIndex].Rig[layer][joint._hier.Value][i + e] = {
							ease,
							n.Value,
						}
					end
				end
			end
			
			continue
		end
		
		local c = propType.default:GetChildren()[1]
		self.objs[objIndex][propType.Name] = {
			default = propType.default.Value,
			wrapper = c and transforms.Wrappers[c.Name]
		}
		
		if #propType:GetChildren() == 0 then
			continue
		end
		
		for _, keyframe in propType:GetChildren() do
			local i = tonumber(keyframe.Name)
			if not i then
				continue
			end
			
			local ease = getEasingData(keyframe)
			for _,n in keyframe.Values:GetChildren() do
				local e = tonumber(n.Name)
				if not e then continue end
				
				self.objs[objIndex][propType.Name][i + e] = {
					ease,
					n.Value,
				}
			end
		end
	end
end

function module.replace(self:cutsceneType, objIndex:number, newInstance:Instance)
	self.instances[objIndex] = newInstance
end

local function isEmpty(t)
	for _,v in t do
		return false
	end
	
	return true
end

function module.reset(self:cutsceneType)
	computeObjects(self)
	local frames:{Rig:{}, Properties:{}} = moonUtil.getKeyFrames(self)
	for joint, keyframes:keyframes in frames.Rig do
		joint.C1 = keyframes.default
	end
	
	for obj, property:{} in frames.Properties do
		obj[property[1]] = property[2].default 
	end
end

function module.setFrame(self:cutsceneType, timeElapsed:number)
	self.objs = self.objs or computeObjects(self)

	for objIndex:number, properties:properties in self.objs do
		for property:string, keyframes:keyframes in properties do
			if property == "Rig" then
				for layer_ind, layer in keyframes do
					for jointKey, keyframes:keyframes in layer do						
						local function set(alpha:number, flast, fnext)
							if not fnext or not fnext[2] then
								return
							end
							
							transforms.C1(keyframes.joint, fnext[2], flast and flast[2] or keyframes.default, alpha)
						end
						
						local sorted,
						flast: keyframeData,	flastNum:number,
						fnext: keyframeData,	fnextNum:number
							= moonUtil.getFrames(timeElapsed, keyframes)
						
						if not fnext then
							flast = keyframes[sorted[#sorted-1]]
							fnext = keyframes[sorted[#sorted]]

							set(1, flast, fnext)

							self.objs[objIndex][property][layer_ind][jointKey] = nil
							if isEmpty(self.objs[objIndex][property][layer_ind]) then
								self.objs[objIndex][property][layer_ind] = nil
								
								if isEmpty(self.objs[objIndex][property]) then
									self.objs[objIndex][property] = nil
									
									if isEmpty(self.objs[objIndex]) then
										self.objs[objIndex] = nil
									end
								end
							end
							
							continue
						end

						local alpha = moonUtil.getEase(flast and flast[1])(math.min((timeElapsed-(flastNum or 0))/(fnextNum-(flastNum or 0)), 1))
						set(alpha, flast, fnext)
					end
				end
				
				continue
			end
			
			local function set(alpha:number, lastValue:any, nextValue:any)
				if not nextValue then
					return
				end
				
				if not transforms[property] then
					warn("invalid property", property)
					return
				end
				
				if keyframes.wrapper then
					transforms[property](self.instances[objIndex], keyframes.wrapper(nextValue[2], lastValue and lastValue[2] or keyframes.default, alpha))
					return
				end
				
				transforms[property](self.instances[objIndex], nextValue[2], lastValue and lastValue[2] or keyframes.default, alpha)
			end
			
			local sorted,
				  flast: keyframeData,	flastNum:number,
				  fnext: keyframeData,	fnextNum:number
			= moonUtil.getFrames(timeElapsed, keyframes)
			
			if not fnext then
				flast = keyframes[sorted[#sorted-1]]
				fnext = keyframes[sorted[#sorted]]
				
				keyframes.lF = fnextNum
				
				set(1, flast, fnext)
				
				self.objs[objIndex][property] = nil
				if isEmpty(self.objs[objIndex]) then
					self.objs[objIndex] = nil
				end

				continue
			end
			
			if flastNum then
				if not keyframes.lF or keyframes.lF ~= flastNum then
					set(1, keyframes[sorted[flastNum-1]], flast)
				end
			end
			
			local alpha = moonUtil.getEase(flast and flast[1])(math.clamp((timeElapsed-(flastNum or 0))/(fnextNum-(flastNum or 0)), 0, 1))
			keyframes.lF = alpha == 1 and fnextNum or flastNum
			
			set(alpha, flast, fnext)
		end
	end
	
	if isEmpty(self.objs) then
		return true
	end
end

return module