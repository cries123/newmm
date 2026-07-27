--!strict
--[[
	GeneratorClient
	Progressive lighting while holding E to boot the generator.
	Uses ProximityPromptService + direct E-key hold so boot works even if prompt hook timing fails.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local BOOT_RANGE = 14

local defaultAmbient = Lighting.Ambient
local defaultBrightness = Lighting.Brightness
local powerAmbient = Color3.fromRGB(55, 55, 65)
local powerBrightness = 1.6
local generatorLightBrightness = 2.5
local mapLightBrightness = 1.2

local cellsDeposited = 0
local cellsRequired = GameConfig.FuelCellsRequired
local powerOn = false

local holdingBoot = false
local holdCompleted = false
local bootRequestSent = false
local holdConnection: RBXScriptConnection? = nil
local bootDuration = GameConfig.GeneratorBootDuration

local function getGenerator(): BasePart?
	for _, inst in CollectionService:GetTagged("Generator") do
		if inst:IsA("BasePart") then
			return inst
		end
	end
	return nil
end

local function getRootPart(): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isBootReady(): boolean
	return not powerOn and cellsDeposited >= cellsRequired
end

local function isNearGenerator(): boolean
	local generator = getGenerator()
	local root = getRootPart()
	if not generator or not root then
		return false
	end
	return (root.Position - generator.Position).Magnitude <= BOOT_RANGE
end

local function canStartBoot(): boolean
	return isBootReady() and isNearGenerator()
end

local function setBootPreview(progress: number)
	local t = math.clamp(progress, 0, 1)

	Lighting.Ambient = defaultAmbient:Lerp(powerAmbient, t)
	Lighting.Brightness = defaultBrightness + (powerBrightness - defaultBrightness) * t

	local generator = getGenerator()
	if generator then
		local light = generator:FindFirstChild("PowerLight") :: PointLight?
		if light then
			light.Brightness = generatorLightBrightness * t
		end
	end

	for _, inst in CollectionService:GetTagged("MapLight") do
		if inst:IsA("BasePart") then
			local light = inst:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = t > 0.05
				light.Brightness = mapLightBrightness * t
			end
		end
	end
end

local function resetBootPreview()
	setBootPreview(0)
end

local function stopHoldLoop()
	if holdConnection then
		holdConnection:Disconnect()
		holdConnection = nil
	end
	holdingBoot = false
end

local function completeBoot()
	if bootRequestSent or not isBootReady() then
		return
	end
	bootRequestSent = true
	holdCompleted = true
	stopHoldLoop()
	setBootPreview(1)
	Remotes.get("RequestBootGenerator"):FireServer()
end

local onBootHoldEnded: () -> ()

local function onBootHoldBegan(duration: number?)
	if holdingBoot or not canStartBoot() then
		return
	end

	holdingBoot = true
	holdCompleted = false
	bootRequestSent = false

	local durationSeconds = duration or bootDuration
	if durationSeconds <= 0 then
		durationSeconds = bootDuration
	end

	local startedAt = os.clock()
	holdConnection = RunService.Heartbeat:Connect(function()
		if not holdingBoot then
			return
		end

		if not canStartBoot() then
			onBootHoldEnded()
			return
		end

		local progress = (os.clock() - startedAt) / durationSeconds
		setBootPreview(progress)

		if progress >= 1 then
			completeBoot()
		end
	end)
end

onBootHoldEnded = function()
	if holdCompleted then
		return
	end
	stopHoldLoop()
	resetBootPreview()
end

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt, triggeringPlayer: Player)
	if triggeringPlayer ~= player or prompt.Name ~= "BootPrompt" then
		return
	end
	bootDuration = if prompt.HoldDuration > 0 then prompt.HoldDuration else GameConfig.GeneratorBootDuration
	onBootHoldBegan(bootDuration)
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt, triggeringPlayer: Player)
	if triggeringPlayer ~= player or prompt.Name ~= "BootPrompt" then
		return
	end
	onBootHoldEnded()
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, triggeringPlayer: Player)
	if triggeringPlayer ~= player or prompt.Name ~= "BootPrompt" then
		return
	end
	completeBoot()
end)

UserInputService.InputBegan:Connect(function(input: InputObject, _gameProcessed: boolean)
	if input.KeyCode ~= Enum.KeyCode.E then
		return
	end
	if canStartBoot() and not holdingBoot then
		onBootHoldBegan()
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessed: boolean)
	if input.KeyCode == Enum.KeyCode.E then
		onBootHoldEnded()
	end
end)

local function applyPowerState(state: { [string]: any })
	cellsDeposited = state.cellsDeposited or cellsDeposited
	cellsRequired = state.cellsRequired or cellsRequired
	powerOn = state.powerOn == true

	if powerOn then
		bootRequestSent = false
		holdCompleted = false
		stopHoldLoop()
		setBootPreview(1)
	elseif not holdingBoot then
		bootRequestSent = false
		resetBootPreview()
	end
end

Remotes.get("PowerStateUpdated").OnClientEvent:Connect(applyPowerState)

Remotes.get("RoundStateChanged").OnClientEvent:Connect(function(state: string)
	if state ~= "Playing" then
		bootRequestSent = false
		holdCompleted = false
		cellsDeposited = 0
		powerOn = false
		stopHoldLoop()
		resetBootPreview()
	end
end)

defaultAmbient = Lighting.Ambient
defaultBrightness = Lighting.Brightness
