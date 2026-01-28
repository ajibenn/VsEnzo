--[[
    transforms (ModuleScript)
    Path: ReplicatedStorage → Moon2Cutscene
    Parent: Moon2Cutscene
    ⚠️  NESTED SCRIPT: This script is inside another script
    Exported: 2026-01-28 16:22:14
]]
local lerp = function(a, b, c)
	return a + c * (b - a)
end

local propertyTypes = {
	[{"Transparency", "Reflectance", "FieldOfView", "BackgroundTransparency", "ImageTransparency", "Brightness", "TextSize", "TextTransparency", "Volume", "PlaybackSpeed", "RollOffMaxDistance", "RollOffMinDistance"}] = function(property:string, obj:Instance, value:number, lastValue:number, alpha:number) 	
		obj[property] = lastValue and lerp(lastValue, value, alpha) or value
	end,
	
	[{"SetTime"}] = function(property, obj:Instance, value:number, _, alpha)
		if alpha == 1 then
			obj[property] = value
		end
	end,

	[{"Material", "RollOffMode"}] = function(property:string, obj:BasePart, value:string)
		obj[property] = Enum[property][value]
	end,

	[{"Anchored", "CastShadow", "Enabled", "Text", "Looped", "Playing", "SoundId", "Font"}] = function(property:string, obj:Instance, value:number, lastValue:number, alpha:number) 
		if alpha == 1 then
			obj[property] = value
			return
		end

		obj[property] = lastValue
	end,
	
	[{"Color", "BackgroundColor3", "TextColor3"}] = function(property:string, obj:Instance, value:Color3, lastValue:Color3, alpha:number)
		obj[property] = lastValue and lastValue:Lerp(value, alpha) or value
	end,
	
	[{"PlayOnce", "Play"}] = function(_, obj:Sound, _, _, alpha:number)
		if alpha == 1 then
			obj:Play()
		end
	end,
	
	[{"Stop", "Pause", "Resume"}] = function(v, obj:Sound, _, _, alpha:number)
		if alpha == 1 then
			obj[v](obj)
		end
	end,
}

local valueTypes = {
	["C1"] = function(obj:Instance, value:CFrame, lastValue:CFrame, alpha:number)
		if obj:IsA("Bone") then
			obj.Transform = lastValue:Lerp(value, alpha)
			
			return
		end
		
		local default = (obj.Part0.CFrame * obj.C0)
		local f_last, f_next = default * lastValue:Inverse(), default * value:Inverse()
		local desired = f_last:Lerp(f_next, alpha)

		obj.C1 = desired:Inverse() * default
	end,
 	
	["CFrame"] = function(obj:Instance, value:CFrame, lastValue:CFrame, alpha:number)
		local newValue = lastValue and lastValue:Lerp(value, alpha) or value
		if obj:IsA("Camera") then
			obj.CameraType = Enum.CameraType.Scriptable
			obj.CFrame = newValue
			obj.Focus = newValue
			return
		end
		
		(obj:IsA("Model") and obj.PrimaryPart or obj).CFrame = newValue
	end,

	["Size"] = function(obj:BasePart, value:Vector3, lastValue:Vector3, alpha:number)
		obj.Size = lastValue and lastValue:Lerp(value, alpha) or value
	end,
	
	["Emit"] = function(obj:ParticleEmitter, value:number, _, alpha:number)
		if alpha == 1 then
			obj:Emit(value)
		end
	end,
}

valueTypes.Wrappers = {
	["NumberSequence"] = function(value, lastValue, alpha)
		return NumberSequence.new(lerp(lastValue, value, alpha))
	end,
	
	["ColorSequence"] = function(value:Color3, lastvalue, alpha)
		return ColorSequence.new(lastvalue:Lerp(value, alpha))
	end,
}

for properties, fn in propertyTypes do
	for _, p in properties do
		valueTypes[p] = function(...)
			fn(p, ...)
		end
	end
end

propertyTypes = nil

return valueTypes