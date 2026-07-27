--!strict
--[[
	RoleManager
	Assigns Sheriff, Murderers, and Innocents each round.
]]

local Players = game:GetService("Players")

local GameConfig = require(script.Parent.GameConfig)

export type Role = GameConfig.Role

local RoleManager = {}

local function shuffle<T>(list: { T }): { T }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = math.random(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

local function getRoleCounts(playerCount: number): (number, number)
	if playerCount < GameConfig.MinPlayers then
		return 0, 0
	end

	local murderers = if playerCount >= 8 then GameConfig.MurdererCount else 1
	local sheriff = GameConfig.SheriffCount

	-- Need at least 1 innocent
	if murderers + sheriff >= playerCount then
		murderers = math.max(1, playerCount - sheriff - 1)
	end

	return murderers, sheriff
end

function RoleManager.clearRoles()
	for _, player in Players:GetPlayers() do
		player:SetAttribute(GameConfig.RoleAttribute, nil)
		player:SetAttribute(GameConfig.IsAliveAttribute, nil)
		player:SetAttribute(GameConfig.EscapedAttribute, nil)
		player:SetAttribute(GameConfig.HasGunAttribute, nil)
		player:SetAttribute(GameConfig.StunnedAttribute, nil)
		player:SetAttribute(GameConfig.HasKeyAttribute, nil)
		player:SetAttribute(GameConfig.CarryingFuelAttribute, nil)
	end
end

function RoleManager.assignRoles(): { [Player]: Role }
	local players = shuffle(Players:GetPlayers())
	local assignments: { [Player]: Role } = {}

	local murdererCount, sheriffCount = getRoleCounts(#players)
	local index = 1

	for _ = 1, murdererCount do
		local player = players[index]
		if player then
			assignments[player] = "Murderer"
			index += 1
		end
	end

	for _ = 1, sheriffCount do
		local player = players[index]
		if player then
			assignments[player] = "Sheriff"
			index += 1
		end
	end

	for i = index, #players do
		local player = players[i]
		if player then
			assignments[player] = "Innocent"
		end
	end

	for player, role in assignments do
		player:SetAttribute(GameConfig.RoleAttribute, role)
		player:SetAttribute(GameConfig.IsAliveAttribute, true)
		player:SetAttribute(GameConfig.EscapedAttribute, false)
	end

	return assignments
end

function RoleManager.getRole(player: Player): Role?
	local role = player:GetAttribute(GameConfig.RoleAttribute)
	if typeof(role) == "string" then
		return role :: Role
	end
	return nil
end

function RoleManager.getPlayersByRole(role: Role): { Player }
	local result: { Player } = {}
	for _, player in Players:GetPlayers() do
		if RoleManager.getRole(player) == role then
			table.insert(result, player)
		end
	end
	return result
end

function RoleManager.getAlivePlayers(): { Player }
	local result: { Player } = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute(GameConfig.IsAliveAttribute) == true then
			table.insert(result, player)
		end
	end
	return result
end

function RoleManager.getAliveInnocentsAndSheriff(): { Player }
	local result: { Player } = {}
	for _, player in Players:GetPlayers() do
		local role = RoleManager.getRole(player)
		local alive = player:GetAttribute(GameConfig.IsAliveAttribute) == true
		if alive and (role == "Innocent" or role == "Sheriff") then
			table.insert(result, player)
		end
	end
	return result
end

function RoleManager.getAliveMurderers(): { Player }
	local result: { Player } = {}
	for _, player in Players:GetPlayers() do
		local role = RoleManager.getRole(player)
		local alive = player:GetAttribute(GameConfig.IsAliveAttribute) == true
		if alive and role == "Murderer" then
			table.insert(result, player)
		end
	end
	return result
end

function RoleManager.getEscapedInnocentsAndSheriff(): { Player }
	local result: { Player } = {}
	for _, player in Players:GetPlayers() do
		local role = RoleManager.getRole(player)
		if player:GetAttribute(GameConfig.EscapedAttribute) == true
			and (role == "Innocent" or role == "Sheriff")
		then
			table.insert(result, player)
		end
	end
	return result
end

function RoleManager.getEscapeCount(): number
	return #RoleManager.getEscapedInnocentsAndSheriff()
end

function RoleManager.getGoodPlayerCount(): number
	local count = 0
	for _, player in Players:GetPlayers() do
		local role = RoleManager.getRole(player)
		if role == "Innocent" or role == "Sheriff" then
			count += 1
		end
	end
	return count
end

function RoleManager.getEscapesRequired(): number
	local goodCount = RoleManager.getGoodPlayerCount()
	if goodCount <= 0 then
		return GameConfig.EscapesRequiredForWin
	end
	return math.min(GameConfig.EscapesRequiredForWin, math.max(1, goodCount - 1))
end

return RoleManager
