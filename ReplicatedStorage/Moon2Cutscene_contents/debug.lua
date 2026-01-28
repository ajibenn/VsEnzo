--[[
    debug (ModuleScript)
    Path: ReplicatedStorage → Moon2Cutscene
    Parent: Moon2Cutscene
    ⚠️  NESTED SCRIPT: This script is inside another script
    Exported: 2026-01-28 16:22:14
]]
local module = {}
local folder = Instance.new("Model", workspace)

function module.clearParts()
	folder:ClearAllChildren()
end

function module.createPart(color:Color3, ...)
	for _,v in {...} do
		local part = Instance.new("Part")
		part.CFrame = v
		part.Anchored = true
		part.Size = Vector3.one
		part.Material = Enum.Material.Metal
		Instance.new("Highlight", part).FillColor = color

		local s = Instance.new("SurfaceGui")
		local l = Instance.new("TextLabel", s)
		l.Size = UDim2.fromScale(1,1)
		l.Text = "Front"
		l.TextScaled = true
		s.Face = Enum.NormalId.Front
		s.Parent = part
		
		part.Parent = folder
	end
end

return module