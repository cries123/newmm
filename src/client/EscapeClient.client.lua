--!strict
--[[
	EscapeClient
	Reliable hold-to-escape using ProximityPromptService + E-key fallback.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local doorUnlocked = false
local localEscaped = false
local holdingEscape = false
local holdCompleted = false
local escapeRequestSent = false
local holdConnection: RBXScriptConnection? = nil

local function getRootPart(): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isNearEscapeZone(): boolean
	local root = getRootPart()
	if not root then
		return false
	end

	for _, inst in CollectionService:GetTagged("EscapeZone") do
		if inst:IsA("BasePart") then
			local half = inst.Size / 2
			local localPos = inst.CFrame:PointToObjectSpace(root.Position)
			if math.abs(localPos.X) <= half.X + 2
				and math.abs(localPos.Y) <= half.Y + 6
				and math.abs(localPos.Z) <= half.Z + 2
			then
				return true
			end
		end
	end

	return false
end

local function canEscapeRole(): boolean
	local role = player:GetAttribute(GameConfig.RoleAttribute)
	return role == "Innocent" or role == "Sheriff"
end

local function canStartEscape(): boolean
	return doorUnlocked
		and not localEscaped
		and player:GetAttribute(GameConfig.IsAliveAttribute) == true
		and player:GetAttribute(GameConfig.EscapedAttribute) ~= true
		and isNearEscapeZone()
		and canEscapeRole()
end

local function stopHoldLoop()
	if holdConnection then
		holdConnection:Disconnect()
		holdConnection = nil
	end
	holdingEscape = false
end

local function completeEscape()
	if escapeRequestSent or not canStartEscape() then
		return
	end
	escapeRequestSent = true
	holdCompleted = true
	stopHoldLoop()
	Remotes.get("RequestEscape"):FireServer()
end

local onEscapeHoldEnded: () -> ()

local function onEscapeHoldBegan(duration: number?)
	if holdingEscape or not canStartEscape() then
		return
	end

	holdingEscape = true
	holdCompleted = false
	escapeRequestSent = false

	local durationSeconds = duration or GameConfig.EscapeHoldDuration
	local startedAt = os.clock()

	holdConnection = RunService.Heartbeat:Connect(function()
		if not holdingEscape then
			return
		end
		if not canStartEscape() then
			onEscapeHoldEnded()
			return
		end

		local progress = (os.clock() - startedAt) / durationSeconds
		if progress >= 1 then
			completeEscape()
		end
	end)
end

onEscapeHoldEnded = function()
	if holdCompleted then
		return
	end
	stopHoldLoop()
end

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt, triggeringPlayer: Player)
	if triggeringPlayer ~= player or prompt.Name ~= "EscapePrompt" then
		return
	end
	onEscapeHoldBegan(prompt.HoldDuration)
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt, triggeringPlayer: Player)
	if triggeringPlayer ~= player or prompt.Name ~= "EscapePrompt" then
		return
	end
	onEscapeHoldEnded()
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, triggeringPlayer: Player)
	if triggeringPlayer ~= player or prompt.Name ~= "EscapePrompt" then
		return
	end
	completeEscape()
end)

UserInputService.InputBegan:Connect(function(input: InputObject, _gameProcessed: boolean)
	if input.KeyCode ~= Enum.KeyCode.E then
		return
	end
	if canStartEscape() and not holdingEscape then
		onEscapeHoldBegan()
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessed: boolean)
	if input.KeyCode == Enum.KeyCode.E then
		onEscapeHoldEnded()
	end
end)

Remotes.get("EscapeStateUpdated").OnClientEvent:Connect(function(state: { [string]: any })
	doorUnlocked = state.doorUnlocked == true
	if state.localEscaped ~= nil then
		localEscaped = state.localEscaped == true
	end
end)

Remotes.get("PlayerEscaped").OnClientEvent:Connect(function(escapedPlayer: Player)
	if escapedPlayer == player then
		localEscaped = true
		holdCompleted = true
		stopHoldLoop()
	end
end)

Remotes.get("RoundStateChanged").OnClientEvent:Connect(function(state: string)
	if state ~= "Playing" then
		doorUnlocked = false
		localEscaped = false
		holdCompleted = false
		escapeRequestSent = false
		stopHoldLoop()
	end
end)
