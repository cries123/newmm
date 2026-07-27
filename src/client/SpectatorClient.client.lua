--!strict
--[[
	SpectatorClient
	Puts eliminated players into spectator mode for the rest of the round.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local isSpectating = false
local spectateIndex = 1
local spectateTargets: { Player } = {}

local function refreshTargets()
	spectateTargets = {}
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= player and otherPlayer:GetAttribute(GameConfig.IsAliveAttribute) == true then
			local character = otherPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				table.insert(spectateTargets, otherPlayer)
			end
		end
	end
end

local function focusTarget(targetPlayer: Player?)
	if not targetPlayer then
		return
	end

	local character = targetPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function startSpectating()
	if isSpectating then
		return
	end
	isSpectating = true

	refreshTargets()
	if #spectateTargets == 0 then
		camera.CameraType = Enum.CameraType.Fixed
		return
	end

	spectateIndex = 1
	camera.CameraType = Enum.CameraType.Custom
	focusTarget(spectateTargets[spectateIndex])

	player.CharacterAdded:Connect(function(character)
		if isSpectating then
			local humanoid = character:WaitForChild("Humanoid", 5)
			if humanoid then
				humanoid.Health = 0
			end
		end
	end)
end

local function stopSpectating()
	isSpectating = false
	camera.CameraType = Enum.CameraType.Custom
	if player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

Remotes.get("PlayerDied").OnClientEvent:Connect(function(victim: Player?)
	if victim == player then
		startSpectating()
	end
end)

Remotes.get("PlayerEscaped").OnClientEvent:Connect(function(escapedPlayer: Player?)
	if escapedPlayer == player then
		startSpectating()
	end
end)

Remotes.get("RoundStateChanged").OnClientEvent:Connect(function(state: string)
	if state == "Intermission" or state == "RoleReveal" then
		stopSpectating()
	end
end)

game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
	if processed or not isSpectating then
		return
	end

	if input.KeyCode == Enum.KeyCode.Right then
		refreshTargets()
		if #spectateTargets > 0 then
			spectateIndex = (spectateIndex % #spectateTargets) + 1
			focusTarget(spectateTargets[spectateIndex])
		end
	elseif input.KeyCode == Enum.KeyCode.Left then
		refreshTargets()
		if #spectateTargets > 0 then
			spectateIndex = ((spectateIndex - 2) % #spectateTargets) + 1
			focusTarget(spectateTargets[spectateIndex])
		end
	end
end)
