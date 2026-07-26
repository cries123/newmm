--!strict
--[[
	ClientUI
	Phase 1 UI: role reveal, round state, timer, and end-screen.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ROLE_COLORS = {
	Innocent = Color3.fromRGB(80, 180, 255),
	Murderer = Color3.fromRGB(220, 60, 60),
	Sheriff = Color3.fromRGB(255, 200, 60),
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GameUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.AnchorPoint = Vector2.new(0.5, 0)
statusLabel.Position = UDim2.fromScale(0.5, 0.02)
statusLabel.Size = UDim2.fromOffset(400, 40)
statusLabel.BackgroundTransparency = 0.35
statusLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 20
statusLabel.Text = "Waiting for players..."
statusLabel.Parent = screenGui

local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "Timer"
timerLabel.AnchorPoint = Vector2.new(0.5, 0)
timerLabel.Position = UDim2.fromScale(0.5, 0.08)
timerLabel.Size = UDim2.fromOffset(200, 32)
timerLabel.BackgroundTransparency = 1
timerLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
timerLabel.Font = Enum.Font.Gotham
timerLabel.TextSize = 18
timerLabel.Text = ""
timerLabel.Parent = screenGui

local roleFrame = Instance.new("Frame")
roleFrame.Name = "RoleReveal"
roleFrame.AnchorPoint = Vector2.new(0.5, 0.5)
roleFrame.Position = UDim2.fromScale(0.5, 0.5)
roleFrame.Size = UDim2.fromOffset(420, 220)
roleFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
roleFrame.BackgroundTransparency = 0.1
roleFrame.Visible = false
roleFrame.Parent = screenGui

local roleTitle = Instance.new("TextLabel")
roleTitle.Name = "RoleTitle"
roleTitle.Size = UDim2.new(1, 0, 0, 60)
roleTitle.BackgroundTransparency = 1
roleTitle.Font = Enum.Font.GothamBold
roleTitle.TextSize = 36
roleTitle.Text = "You are..."
roleTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
roleTitle.Parent = roleFrame

local roleSubtitle = Instance.new("TextLabel")
roleSubtitle.Name = "RoleSubtitle"
roleSubtitle.Position = UDim2.fromOffset(0, 70)
roleSubtitle.Size = UDim2.new(1, 0, 0, 120)
roleSubtitle.BackgroundTransparency = 1
roleSubtitle.Font = Enum.Font.Gotham
roleSubtitle.TextSize = 18
roleSubtitle.TextWrapped = true
roleSubtitle.TextColor3 = Color3.fromRGB(200, 200, 200)
roleSubtitle.Text = ""
roleSubtitle.Parent = roleFrame

local function formatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%d:%02d", mins, secs)
end

local function setStatus(text: string)
	statusLabel.Text = text
end

local function setTimer(state: string, seconds: number)
	if state == "Intermission" then
		timerLabel.Text = `Starting in {formatTime(seconds)}`
	elseif state == "RoleReveal" then
		timerLabel.Text = `Roles revealed — {formatTime(seconds)}`
	elseif state == "Playing" then
		timerLabel.Text = `Round — {formatTime(seconds)}`
	elseif state == "Ended" then
		timerLabel.Text = ""
	else
		timerLabel.Text = formatTime(seconds)
	end
end

local function showRoleReveal(role: string, teammates: { string }?)
	roleFrame.Visible = true
	roleTitle.Text = `You are the {role}`
	roleTitle.TextColor3 = ROLE_COLORS[role] or Color3.fromRGB(255, 255, 255)

	if role == "Murderer" and teammates and #teammates > 0 then
		roleSubtitle.Text = `Your partner: {table.concat(teammates, ", ")}\nEliminate everyone before they escape.`
	elseif role == "Murderer" then
		roleSubtitle.Text = "Eliminate everyone before they escape."
	elseif role == "Sheriff" then
		roleSubtitle.Text = "Protect the innocents. Find and stop the murderers."
	else
		roleSubtitle.Text = "Restore power, unlock doors, and escape."
	end

	task.delay(GameConfig.RoleRevealDuration, function()
		roleFrame.Visible = false
	end)
end

Remotes.get("RoundStateChanged").OnClientEvent:Connect(function(state: string, seconds: number)
	if state == "Intermission" then
		setStatus("Intermission — waiting for players")
	elseif state == "RoleReveal" then
		setStatus("Study your role")
	elseif state == "Playing" then
		setStatus("Survive or hunt")
	elseif state == "Ended" then
		setStatus("Round over")
	end
	setTimer(state, seconds)
end)

Remotes.get("TimerUpdated").OnClientEvent:Connect(function(state: string, seconds: number)
	setTimer(state, seconds)
end)

Remotes.get("RoleAssigned").OnClientEvent:Connect(function(role: string, teammates: { string }?)
	showRoleReveal(role, teammates)
end)

Remotes.get("RoundEnded").OnClientEvent:Connect(function(winner: string, reason: string)
	setStatus(`{winner} win — {reason}`)
	roleTitle.Text = `{winner} Win!`
	roleSubtitle.Text = reason
	roleTitle.TextColor3 = if winner == "Innocents"
		then Color3.fromRGB(80, 200, 120)
		else Color3.fromRGB(220, 80, 80)
	roleFrame.Visible = true

	task.delay(5, function()
		roleFrame.Visible = false
	end)
end)
