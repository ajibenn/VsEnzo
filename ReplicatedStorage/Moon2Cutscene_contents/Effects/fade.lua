--[[
    fade (ModuleScript)
    Path: ReplicatedStorage → Moon2Cutscene → Effects
    Parent: Effects
    ⚠️  NESTED SCRIPT: This script is inside another script
    Exported: 2026-01-28 16:22:14
]]
return function(fadeInTime:number?, stayTime:number?, fadeOutTime:number?, Color:Color3?): (() -> nil, ScreenGui)
	local fade = Instance.new("ScreenGui")
	fade.Name = "fade_Moon2Cutscene"
	fade.IgnoreGuiInset = true

	local frame = Instance.new("Frame", fade)
	frame.Name = "FadeFrame"
	frame.Size = UDim2.fromScale(1,1)
	frame.BackgroundTransparency = 1
	frame.BackgroundColor3 = Color or Color3.new(0,0,0)

	fade.Parent = game:GetService("Players").LocalPlayer.PlayerGui

	return function()
		if fadeInTime then
			game:GetService("TweenService"):Create(frame, TweenInfo.new(fadeInTime), {BackgroundTransparency = 0}):Play()
			task.wait(fadeInTime)
		else
			frame.BackgroundTransparency = 0
		end

		task.wait(stayTime)

		if fadeOutTime then
			game:GetService("TweenService"):Create(frame, TweenInfo.new(fadeOutTime), {BackgroundTransparency = 1}):Play()
		else
			frame.BackgroundTransparency = 1
		end
	end, fade
end