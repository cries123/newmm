--!strict
--[[
	RoundManager
	Handles round state machine, timers, and win-condition checks (Phase 1).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local RoleManager = require(ReplicatedStorage.Shared.RoleManager)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type RoundState = GameConfig.RoundState
export type WinResult = {
	winner: "Innocents" | "Murderers" | "None",
	reason: string,
}

local RoundManager = {}

local currentState: RoundState = "Intermission"
local timeRemaining = 0
local running = false
local stateChangedCallbacks: { (RoundState) -> () } = {}
local pendingWinResult: WinResult? = nil

local function setState(state: RoundState, timer: number?)
	currentState = state
	if timer ~= nil then
		timeRemaining = timer
	end
	Remotes.get("RoundStateChanged"):FireAllClients(state, timeRemaining)

	for _, callback in stateChangedCallbacks do
		task.spawn(callback, state)
	end
end

local function broadcastTimer()
	Remotes.get("TimerUpdated"):FireAllClients(currentState, timeRemaining)
end

local function waitSeconds(duration: number)
	local elapsed = 0
	while elapsed < duration and running do
		local dt = task.wait(0.25)
		elapsed += dt
		timeRemaining = math.max(0, math.ceil(duration - elapsed))
		broadcastTimer()
	end
end

function RoundManager.getState(): RoundState
	return currentState
end

function RoundManager.getTimeRemaining(): number
	return timeRemaining
end

function RoundManager.onStateChanged(callback: (RoundState) -> ())
	table.insert(stateChangedCallbacks, callback)
end

function RoundManager.requestWinCheck()
	local result = RoundManager.checkWinConditions()
	if result then
		pendingWinResult = result
	end
end

function RoundManager.checkWinConditions(): WinResult?
	local escapesRequired = RoleManager.getEscapesRequired()
	local escapeCount = RoleManager.getEscapeCount()
	local aliveGood = RoleManager.getAliveInnocentsAndSheriff()
	local aliveMurderers = RoleManager.getAliveMurderers()

	if escapeCount >= escapesRequired and currentState == "Playing" then
		return {
			winner = "Innocents",
			reason = `{escapeCount} players escaped ({escapesRequired} required).`,
		}
	end

	if #aliveMurderers == 0 and currentState == "Playing" then
		return {
			winner = "Innocents",
			reason = "All murderers were eliminated.",
		}
	end

	if #aliveGood == 0 and escapeCount < escapesRequired then
		return {
			winner = "Murderers",
			reason = "No one left to escape.",
		}
	end

	return nil
end

function RoundManager.start()
	if running then
		return
	end
	running = true

	task.spawn(function()
		while running do
			-- INTERMISSION
			setState("Intermission", GameConfig.IntermissionDuration)

			while #Players:GetPlayers() < GameConfig.MinPlayers and running do
				timeRemaining = GameConfig.IntermissionDuration
				broadcastTimer()
				task.wait(1)
			end

			if not running then
				break
			end

			waitSeconds(GameConfig.IntermissionDuration)
			if not running then
				break
			end

			-- ROLE REVEAL
			RoleManager.clearRoles()
			local assignments = RoleManager.assignRoles()

			local murdererNames: { string } = {}
			for assignedPlayer, assignedRole in assignments do
				if assignedRole == "Murderer" then
					table.insert(murdererNames, assignedPlayer.Name)
				end
			end

			for player, role in assignments do
				local teammates: { string }? = nil
				if role == "Murderer" then
					teammates = {}
					for _, name in murdererNames do
						if name ~= player.Name then
							table.insert(teammates, name)
						end
					end
				end
				Remotes.get("RoleAssigned"):FireClient(player, role, teammates)
			end

			setState("RoleReveal", GameConfig.RoleRevealDuration)
			waitSeconds(GameConfig.RoleRevealDuration)
			if not running then
				break
			end

			-- PLAYING
			setState("Playing", GameConfig.RoundDuration)

			local roundEndReason: string? = nil
			local roundWinner: "Innocents" | "Murderers"? = nil

			while timeRemaining > 0 and running do
				if pendingWinResult then
					roundWinner = pendingWinResult.winner
					roundEndReason = pendingWinResult.reason
					pendingWinResult = nil
					break
				end

				local elapsed = 0
				while elapsed < 1 and timeRemaining > 0 and running and not pendingWinResult do
					task.wait(0.1)
					elapsed += 0.1
				end

				if pendingWinResult then
					roundWinner = pendingWinResult.winner
					roundEndReason = pendingWinResult.reason
					pendingWinResult = nil
					break
				end

				timeRemaining -= 1
				broadcastTimer()

				local result = RoundManager.checkWinConditions()
				if result then
					roundWinner = result.winner
					roundEndReason = result.reason
					break
				end
			end

			if not roundWinner then
				local escapeCount = RoleManager.getEscapeCount()
				local escapesRequired = RoleManager.getEscapesRequired()
				local aliveGood = RoleManager.getAliveInnocentsAndSheriff()

				if escapeCount >= escapesRequired then
					roundWinner = "Innocents"
					roundEndReason = `{escapeCount} players escaped before time ran out.`
				elseif #aliveGood > 0 then
					roundWinner = "Innocents"
					roundEndReason = "Time ran out with survivors still alive."
				else
					roundWinner = "Murderers"
					roundEndReason = "No survivors remained."
				end
			end

			-- ENDED
			setState("Ended", 5)
			Remotes.get("RoundEnded"):FireAllClients(roundWinner, roundEndReason)
			waitSeconds(5)
		end
	end)
end

function RoundManager.stop()
	running = false
end

return RoundManager
