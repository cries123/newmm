--!strict
--[[
	CombatClient
	Ability buttons for murderers and sheriff/gun holders, plus cooldown and ammo display.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local currentRole: string? = nil
local hasGun = false
local ammo = 0
local cooldownRemaining = 0
local isAlive = true
local isPlaying = false

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CombatUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local actionFrame = Instance.new("Frame")
actionFrame.Name = "Actions"
actionFrame.AnchorPoint = Vector2.new(1, 1)
actionFrame.Position = UDim2.new(1, -20, 1, -20)
actionFrame.Size = UDim2.fromOffset(220, 160)
actionFrame.BackgroundTransparency = 1
actionFrame.Visible = false
actionFrame.Parent = screenGui

local infoLabel = Instance.new("TextLabel")
infoLabel.Name = "Info"
infoLabel.Size = UDim2.new(1, 0, 0, 28)
infoLabel.BackgroundTransparency = 0.3
infoLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
infoLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 14
infoLabel.Text = ""
infoLabel.Parent = actionFrame

local function createActionButton(name: string, text: string, color: Color3, y: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = UDim2.fromOffset(0, y)
	button.Size = UDim2.new(1, 0, 0, 40)
	button.BackgroundColor3 = color
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.Text = text
	button.Parent = actionFrame
	return button
end

local assassinateButton = createActionButton(
	"Assassinate",
	"Assassinate [Q]",
	Color3.fromRGB(170, 40, 40),
	36
)
local shootButton = createActionButton("Shoot", "Shoot [F]", Color3.fromRGB(200, 160, 40), 36)
local arrestButton = createActionButton("Arrest", "Arrest [R]", Color3.fromRGB(60, 100, 200), 80)

local function updateVisibility()
	local showActions = isPlaying and isAlive
	actionFrame.Visible = showActions

	assassinateButton.Visible = currentRole == "Murderer"
	shootButton.Visible = hasGun
	arrestButton.Visible = currentRole == "Sheriff"

	if currentRole == "Murderer" then
		infoLabel.Text = if cooldownRemaining > 0
			then `Cooldown: {math.ceil(cooldownRemaining)}s`
			else "Assassinate [Q] | Sabotage at generator"
	elseif hasGun then
		infoLabel.Text = `Ammo: {ammo}`
	elseif currentRole == "Sheriff" then
		infoLabel.Text = "Find the murderers"
	else
		infoLabel.Text = "Survive and escape"
	end

	assassinateButton.AutoButtonColor = cooldownRemaining <= 0
	assassinateButton.BackgroundTransparency = if cooldownRemaining > 0 then 0.4 else 0
	shootButton.AutoButtonColor = ammo > 0
	shootButton.BackgroundTransparency = if ammo > 0 then 0 else 0.4
end

assassinateButton.MouseButton1Click:Connect(function()
	if cooldownRemaining <= 0 then
		Remotes.get("Assassinate"):FireServer()
	end
end)

shootButton.MouseButton1Click:Connect(function()
	if ammo > 0 then
		Remotes.get("Shoot"):FireServer()
	end
end)

arrestButton.MouseButton1Click:Connect(function()
	Remotes.get("Arrest"):FireServer()
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not isPlaying or not isAlive then
		return
	end

	if input.KeyCode == Enum.KeyCode.Q and currentRole == "Murderer" and cooldownRemaining <= 0 then
		Remotes.get("Assassinate"):FireServer()
	elseif input.KeyCode == Enum.KeyCode.F and hasGun and ammo > 0 then
		Remotes.get("Shoot"):FireServer()
	elseif input.KeyCode == Enum.KeyCode.R and currentRole == "Sheriff" then
		Remotes.get("Arrest"):FireServer()
	end
end)

Remotes.get("RoleAssigned").OnClientEvent:Connect(function(role: string)
	currentRole = role
	isAlive = true
	updateVisibility()
end)

Remotes.get("RoundStateChanged").OnClientEvent:Connect(function(state: string)
	isPlaying = state == "Playing"
	if state == "Intermission" or state == "RoleReveal" then
		isAlive = true
	end
	updateVisibility()
end)

Remotes.get("CombatStateUpdated").OnClientEvent:Connect(function(
	role: string?,
	newAmmo: number,
	newCooldown: number,
	newHasGun: boolean
)
	if role then
		currentRole = role
	end
	ammo = newAmmo
	cooldownRemaining = newCooldown
	hasGun = newHasGun
	updateVisibility()
end)

Remotes.get("PlayerDied").OnClientEvent:Connect(function(victim: Player?, _killerName: string?)
	if victim == player then
		isAlive = false
		updateVisibility()
	end
end)

task.spawn(function()
	while true do
		if cooldownRemaining > 0 then
			cooldownRemaining = math.max(0, cooldownRemaining - 0.1)
			updateVisibility()
		end
		task.wait(0.1)
	end
end)

updateVisibility()
