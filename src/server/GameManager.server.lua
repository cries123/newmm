--!strict
--[[
	GameManager (Server)
	Entry point for server-side game logic. Initializes remotes and starts the round loop.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundManager = require(ReplicatedStorage.Shared.RoundManager)

Remotes.init()
RoundManager.start()

print("[newmm] GameManager started — round loop running.")
