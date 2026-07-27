--!strict
--[[
	GameManager (Server)
	Entry point for server-side game logic. Initializes remotes and starts the round loop.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CombatService = require(script.Parent.CombatService)
local MapBuilder = require(script.Parent.MapBuilder)
local PowerService = require(script.Parent.PowerService)
local EscapeService = require(script.Parent.EscapeService)
local RoundManager = require(ReplicatedStorage.Shared.RoundManager)

Remotes.init()
MapBuilder.build()
PowerService.init()
EscapeService.init()
CombatService.init()
RoundManager.start()

print(`[newmm] GameManager started — map {MapBuilder.getVersion()}, power, escape, combat, and rounds running.`)
