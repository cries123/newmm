--!strict
--[[
	GameConfig
	Central place for tunable game constants.
	Change values here instead of hunting through scripts.
]]

local GameConfig = {
	-- Lobby / round flow
	MinPlayers = 4,
	IntermissionDuration = 20,
	RoundDuration = 360, -- 6 minutes
	RoleRevealDuration = 5,

	-- Role counts (for 8+ players; scaled down for smaller lobbies)
	MurdererCount = 2,
	SheriffCount = 1,

	-- Combat (Phase 2)
	SheriffAmmo = 5,
	ArrestStunDuration = 5,
	AssassinateCooldown = 10,
	AssassinateRange = 8,
	ShootRange = 120,
	DefaultWalkSpeed = 16,
	DefaultJumpPower = 50,

	-- Power system (Phase 3)
	FuelCellsRequired = 2,
	GeneratorBootDuration = 10,
	PowerDecayDuration = 120,
	MurdererSabotageUses = 2,

	-- Win conditions
	EscapesRequiredForWin = 3,

	-- Attribute names (stored on Player)
	RoleAttribute = "Role",
	IsAliveAttribute = "IsAlive",
	EscapedAttribute = "Escaped",
	HasGunAttribute = "HasGun",
	StunnedAttribute = "Stunned",
	HasKeyAttribute = "HasKey",
	CarryingFuelAttribute = "CarryingFuel",

	RevolverToolName = "Revolver",
}

export type Role = "Innocent" | "Murderer" | "Sheriff"

export type RoundState = "Intermission" | "RoleReveal" | "Playing" | "Ended"

return GameConfig
