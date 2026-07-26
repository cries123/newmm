--!strict
--[[
	PlayerUtils
	Shared helpers for alive/dead checks used by combat and round logic.
]]

local GameConfig = require(script.Parent.GameConfig)

local PlayerUtils = {}

function PlayerUtils.isAlive(player: Player): boolean
	return player:GetAttribute(GameConfig.IsAliveAttribute) == true
end

function PlayerUtils.isStunned(player: Player): boolean
	return player:GetAttribute(GameConfig.StunnedAttribute) == true
end

function PlayerUtils.hasGun(player: Player): boolean
	return player:GetAttribute(GameConfig.HasGunAttribute) == true
end

function PlayerUtils.getCharacterHumanoid(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return character, nil, nil
	end

	return character, humanoid, root
end

return PlayerUtils
