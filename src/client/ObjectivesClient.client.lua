--!strict
--[[
	ObjectivesClient
	Phase 3 UI: fuel cells, power status, key, and alerts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ObjectivesUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.fromOffset(16, 120)
panel.Size = UDim2.fromOffset(260, 130)
panel.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
panel.BackgroundTransparency = 0.2
panel.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = "OBJECTIVES"
title.Parent = panel

local fuelLabel = Instance.new("TextLabel")
fuelLabel.Size = UDim2.new(1, -12, 0, 22)
fuelLabel.Position = UDim2.fromOffset(6, 32)
fuelLabel.BackgroundTransparency = 1
fuelLabel.Font = Enum.Font.Gotham
fuelLabel.TextSize = 14
fuelLabel.TextXAlignment = Enum.TextXAlignment.Left
fuelLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
fuelLabel.Text = "Fuel: 0/3"
fuelLabel.Parent = panel

local powerLabel = Instance.new("TextLabel")
powerLabel.Size = UDim2.new(1, -12, 0, 22)
powerLabel.Position = UDim2.fromOffset(6, 54)
powerLabel.BackgroundTransparency = 1
powerLabel.Font = Enum.Font.Gotham
powerLabel.TextSize = 14
powerLabel.TextXAlignment = Enum.TextXAlignment.Left
powerLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
powerLabel.Text = "Power: OFF"
powerLabel.Parent = panel

local keyLabel = Instance.new("TextLabel")
keyLabel.Size = UDim2.new(1, -12, 0, 22)
keyLabel.Position = UDim2.fromOffset(6, 76)
keyLabel.BackgroundTransparency = 1
keyLabel.Font = Enum.Font.Gotham
keyLabel.TextSize = 14
keyLabel.TextXAlignment = Enum.TextXAlignment.Left
keyLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
keyLabel.Text = "Key: Not found"
keyLabel.Parent = panel

local carryLabel = Instance.new("TextLabel")
carryLabel.Size = UDim2.new(1, -12, 0, 22)
carryLabel.Position = UDim2.fromOffset(6, 98)
carryLabel.BackgroundTransparency = 1
carryLabel.Font = Enum.Font.Gotham
carryLabel.TextSize = 14
carryLabel.TextXAlignment = Enum.TextXAlignment.Left
carryLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
carryLabel.Text = ""
carryLabel.Parent = panel

local alertLabel = Instance.new("TextLabel")
alertLabel.AnchorPoint = Vector2.new(0.5, 0)
alertLabel.Position = UDim2.new(0.5, 0, 0, 14)
alertLabel.Size = UDim2.fromOffset(500, 36)
alertLabel.BackgroundTransparency = 0.35
alertLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
alertLabel.Font = Enum.Font.GothamBold
alertLabel.TextSize = 16
alertLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
alertLabel.Text = ""
alertLabel.Visible = false
alertLabel.Parent = screenGui

local function refreshLocal()
	local carrying = player:GetAttribute(GameConfig.CarryingFuelAttribute) == true
	local hasKey = player:GetAttribute(GameConfig.HasKeyAttribute) == true
	carryLabel.Text = if carrying then "Carrying fuel cell" else ""
	keyLabel.Text = if hasKey then "Key: Collected" else "Key: Not found"
	keyLabel.TextColor3 = if hasKey
		then Color3.fromRGB(80, 220, 120)
		else Color3.fromRGB(180, 180, 180)
end

local function showAlert(message: string)
	alertLabel.Text = message
	alertLabel.Visible = true
	task.delay(4, function()
		alertLabel.Visible = false
	end)
end

local function updateFromState(state: { [string]: any })
	local deposited = state.cellsDeposited or 0
	local required = state.cellsRequired or GameConfig.FuelCellsRequired
	local on = state.powerOn == true

	fuelLabel.Text = `Fuel: {deposited}/{required}`
	powerLabel.Text = if on then "Power: ON" else "Power: OFF"
	powerLabel.TextColor3 = if on
		then Color3.fromRGB(80, 220, 120)
		else Color3.fromRGB(180, 180, 180)

	refreshLocal()
end

Remotes.get("PowerStateUpdated").OnClientEvent:Connect(updateFromState)
Remotes.get("PowerAlert").OnClientEvent:Connect(showAlert)

Remotes.get("RoundStateChanged").OnClientEvent:Connect(function(state: string)
	panel.Visible = state == "Playing"
	if state ~= "Playing" then
		alertLabel.Visible = false
	end
end)

player:GetAttributeChangedSignal(GameConfig.CarryingFuelAttribute):Connect(refreshLocal)
player:GetAttributeChangedSignal(GameConfig.HasKeyAttribute):Connect(refreshLocal)

panel.Visible = false
refreshLocal()
