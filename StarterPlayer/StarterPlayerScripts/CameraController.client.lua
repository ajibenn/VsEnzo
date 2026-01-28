--[[
    CameraController (LocalScript)
    Path: StarterPlayer → StarterPlayerScripts
    Parent: StarterPlayerScripts
    Properties:
        Disabled: false
    Exported: 2026-01-28 16:22:15
]]
-- ---------------------------
-- LocalScript: CameraController (StarterPlayerScripts.CameraController)
-- ---------------------------
-- Place this LocalScript in StarterPlayerScripts
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local rep = game:GetService("ReplicatedStorage")
local cameraModule = require(rep:WaitForChild("Modules"):WaitForChild("CameraModule"))
local cam = cameraModule:Create(player)


cam:Enable()


local UIS = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local aiming = false


-- toggle ADS when right mouse button down/up or hold
UIS.InputBegan:Connect(function(input, gameProcessed)
if gameProcessed then return end
if input.UserInputType == Enum.UserInputType.MouseButton2 then
cam:SetADS(true)
end
end)
UIS.InputEnded:Connect(function(input, gameProcessed)
if input.UserInputType == Enum.UserInputType.MouseButton2 then
cam:SetADS(false)
end
end)


-- Optional: change camera when character spawns
player.CharacterAdded:Connect(function(char)
wait(0.1)
cam.Character = char
end)


-- Handle sensitivity while ADS (reduces look sensitivity)
local mouse = player:GetMouse()
local originalCamera = workspace.CurrentCamera
-- We'll reduce sensitivity by adjusting mouse delta effect on camera rotation indirectly by letting Roblox handle camera rotation
-- For Scriptable camera we must implement rotation by capturing mouse delta; but to keep it simple we will not override rotation here.


-- NOTE: For advanced aim you'd implement custom rotation using MouseDelta events and change cam orientation. This sample keeps a simple over-the-shoulder camera.


-- Clean up on leave
player.AncestryChanged:Connect(function()
if not player:IsDescendantOf(game) then cam:Disable() end
end)


-- ---------------------------
-- Tool: AssaultRifle (StarterPack.AssaultRifle)
-- Tool hierarchy: Tool -> Handle (Part) -> MuzzleAttachment
-- Add RemoteEvent: ReplicatedStorage.RemoteEvents.FireEvent