--!strict
--[[
	EscapeService (Server)
	Phase 4: escape zone, hold-to-escape, and escape win tracking.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatService = require(script.Parent.CombatService)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PlayerUtils = require(ReplicatedStorage.Shared.PlayerUtils)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoleManager = require(ReplicatedStorage.Shared.RoleManager)
local RoundManager = require(ReplicatedStorage.Shared.RoundManager)

local EscapeService = {}

local function isPlaying(): boolean
	return RoundManager.getState() == "Playing"
end

local function isDoorUnlocked(): boolean
	for _, inst in CollectionService:GetTagged("Door") do
		if inst:IsA("BasePart") and inst:GetAttribute("Locked") == false then
			return true
		end
	end
	return false
end

local function canEscape(player: Player): (boolean, string?)
	if not isPlaying() then
		return false, "Wait for the round to start."
	end
	if player:GetAttribute(GameConfig.EscapedAttribute) == true then
		return false, "You already escaped."
	end
	if not PlayerUtils.isAlive(player) then
		return false, "You are eliminated."
	end
	if PlayerUtils.isStunned(player) then
		return false, "You are stunned."
	end

	local role = RoleManager.getRole(player)
	if role == "Murderer" then
		return false, "Murderers cannot escape."
	end
	if role ~= "Innocent" and role ~= "Sheriff" then
		return false, "You cannot escape."
	end
	if not isDoorUnlocked() then
		return false, "Unlock the main door first."
	end

	return true, nil
end

local function isNearEscapeZone(player: Player): boolean
	local _, _, root = PlayerUtils.getCharacterHumanoid(player)
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

local function broadcastEscapeState()
	local escapedCount = RoleManager.getEscapeCount()
	local escapesRequired = RoleManager.getEscapesRequired()

	for _, player in Players:GetPlayers() do
		Remotes.get("EscapeStateUpdated"):FireClient(player, {
			escapedCount = escapedCount,
			escapesRequired = escapesRequired,
			localEscaped = player:GetAttribute(GameConfig.EscapedAttribute) == true,
			doorUnlocked = isDoorUnlocked(),
		})
	end
end

local function onPlayerEscaped(player: Player)
	local ok, reason = canEscape(player)
	if not ok then
		if reason then
			Remotes.get("EscapeAlert"):FireClient(player, reason)
		end
		return
	end
	if not isNearEscapeZone(player) then
		Remotes.get("EscapeAlert"):FireClient(player, "Get to the escape zone in the back hall.")
		return
	end

	player:SetAttribute(GameConfig.EscapedAttribute, true)
	CombatService.setPlayerSpectating(player)

	Remotes.get("PlayerEscaped"):FireAllClients(player)
	broadcastEscapeState()
	Remotes.get("EscapeAlert"):FireAllClients(`{player.Name} escaped!`)
	RoundManager.requestWinCheck()
end

local function connectEscapePrompt(zone: BasePart)
	if zone:GetAttribute("EscapeSetup") then
		return
	end
	zone:SetAttribute("EscapeSetup", true)

	local prompt = zone:FindFirstChild("EscapePrompt") :: ProximityPrompt?
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "EscapePrompt"
		prompt.ActionText = "Escape"
		prompt.ObjectText = "HOLD E TO ESCAPE"
		prompt.HoldDuration = GameConfig.EscapeHoldDuration
		prompt.MaxActivationDistance = GameConfig.EscapeZoneRange
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.Enabled = false
		prompt.Parent = zone
	end

	if prompt:GetAttribute("Connected") then
		return
	end
	prompt:SetAttribute("Connected", true)
	prompt.Triggered:Connect(function(triggeringPlayer: Player)
		onPlayerEscaped(triggeringPlayer)
	end)
end

local function updateEscapePrompts()
	local enabled = isPlaying() and isDoorUnlocked()
	for _, inst in CollectionService:GetTagged("EscapeZone") do
		if inst:IsA("BasePart") then
			connectEscapePrompt(inst)
			local prompt = inst:FindFirstChild("EscapePrompt") :: ProximityPrompt?
			if prompt then
				prompt.Enabled = enabled
			end
		end
	end
end

local function hookDoorForEscape(door: BasePart)
	if door:GetAttribute("EscapeDoorHooked") then
		return
	end
	door:SetAttribute("EscapeDoorHooked", true)
	door:GetAttributeChangedSignal("Locked"):Connect(function()
		updateEscapePrompts()
		broadcastEscapeState()
	end)
end

local function setupEscapeZones()
	for _, inst in CollectionService:GetTagged("EscapeZone") do
		if inst:IsA("BasePart") then
			connectEscapePrompt(inst)
		end
	end
	for _, inst in CollectionService:GetTagged("Door") do
		if inst:IsA("BasePart") then
			hookDoorForEscape(inst)
		end
	end
	updateEscapePrompts()
end

function EscapeService.resetForRound()
	for _, player in Players:GetPlayers() do
		player:SetAttribute(GameConfig.EscapedAttribute, false)
	end
	updateEscapePrompts()
	broadcastEscapeState()
end

function EscapeService.init()
	setupEscapeZones()

	CollectionService:GetInstanceAddedSignal("EscapeZone"):Connect(function(inst)
		task.defer(setupEscapeZones)
	end)

	CollectionService:GetInstanceAddedSignal("Door"):Connect(function(_inst)
		task.defer(updateEscapePrompts)
	end)

	Remotes.get("RequestEscape").OnServerEvent:Connect(function(player: Player)
		onPlayerEscaped(player)
	end)

	RoundManager.onStateChanged(function(state: GameConfig.RoundState)
		if state == "Playing" then
			EscapeService.resetForRound()
		else
			updateEscapePrompts()
		end
	end)

	task.spawn(function()
		while true do
			if isPlaying() then
				updateEscapePrompts()
			end
			task.wait(1)
		end
	end)

	print("[newmm] EscapeService initialized.")
end

return EscapeService
