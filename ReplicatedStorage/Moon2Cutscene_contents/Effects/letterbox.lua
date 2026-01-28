--[[
    letterbox (ModuleScript)
    Path: ReplicatedStorage → Moon2Cutscene → Effects
    Parent: Effects
    ⚠️  NESTED SCRIPT: This script is inside another script
    Exported: 2026-01-28 16:22:14
]]
return function():Frame
	local gui = Instance.new("ScreenGui")
	gui.Name = "letterbox_Moon2Cutscene"
	gui.IgnoreGuiInset = true

	local function createFrame():Frame
		local frame = Instance.new("Frame")
		frame.Name = "Letterbox"
		frame.Size = UDim2.fromScale(1, .122)
		frame.BackgroundTransparency = 1
		frame.ZIndex = -499
		frame.Selectable = false
		frame.BackgroundColor3 = Color3.new(0,0,0)
		frame.Parent = gui
		
		return frame
	end
	
	local upperFrame = createFrame()
	local lowerFrame = createFrame()
	lowerFrame.Position = UDim2.fromScale(0, 1)
	lowerFrame.AnchorPoint = Vector2.new(0, 1)
	lowerFrame.Changed:Connect(function(prop)
		pcall(function()
			upperFrame[prop] = lowerFrame[prop]
		end)
	end)
	
	lowerFrame.Destroying:Connect(function()
		gui:Destroy()
	end)

	gui.Parent = game:GetService("Players").LocalPlayer.PlayerGui
	
	return lowerFrame
end