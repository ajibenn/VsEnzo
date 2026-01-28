--[[
    vignette (ModuleScript)
    Path: ReplicatedStorage → Moon2Cutscene → Effects
    Parent: Effects
    ⚠️  NESTED SCRIPT: This script is inside another script
    Exported: 2026-01-28 16:22:14
]]
return function(image:string?): (() -> nil, ScreenGui, ImageLabel)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "vignette_Moon2Cutscene"
	screenGui.ClipToDeviceSafeArea = false
	screenGui.IgnoreGuiInset = true

	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.BackgroundColor3 = Color3.fromRGB(0,0,0)
	label.ImageTransparency = .5
	label.Size = UDim2.fromScale(1,1)
	label.Image = image or "rbxassetid://12175750943"

	label.Parent = screenGui
	screenGui.Parent = game:GetService("Players").LocalPlayer.PlayerGui

	return function()
		screenGui:Destroy()
	end, screenGui, label
end