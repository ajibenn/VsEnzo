--[[
    subtitle (ModuleScript)
    Path: ReplicatedStorage → Moon2Cutscene → Effects
    Parent: Effects
    ⚠️  NESTED SCRIPT: This script is inside another script
    Exported: 2026-01-28 16:22:14
]]
local subtitlesUi = script.Subtitles
return function(text:string, properties:{})
	subtitlesUi.Parent = game:GetService("Players").LocalPlayer.PlayerGui
	
	if text then
		for i,v in properties or {} do
			subtitlesUi.Subtitles[i] = v
		end

		subtitlesUi.Subtitles.Text = text
	end

	return subtitlesUi.Subtitles
end