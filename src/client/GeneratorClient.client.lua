--!strict
--[[
	GeneratorClient
	Progressive lighting while holding E to boot the generator.
	Also fires RequestBootGenerator when the hold completes (reliable vs server-only prompts).
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local defaultAmbient = Lighting.Ambient
local defaultBrightness = Lighting.Brightness
local powerAmbient = Color3.fromRGB(55, 55, 65)
local powerBrightness = 1.6
local generatorLightBrightness = 2.5
local mapLightBrightness = 1.2

local holdingBoot = false
local holdCompleted = false
local holdConnection: RBXScriptConnection? = nil
local bootPrompt: ProximityPrompt? = nil

local function getGenerator(): BasePart?
	for _, inst in CollectionService:GetTagged("Generator") do
		if inst:IsA("BasePart") then
			return inst
		end
	end
	return nil
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

local function onBootHoldBegan()
	if holdingBoot then
		return
	end

	local prompt = bootPrompt
	if not prompt then
		return
	end

	holdingBoot = true
	holdCompleted = false
	local duration = prompt.HoldDuration
	if duration <= 0 then
		duration = GameConfig.GeneratorBootDuration
	end

	local startedAt = os.clock()
	holdConnection = RunService.Heartbeat:Connect(function()
		if not holdingBoot then
			return
		end

		local progress = (os.clock() - startedAt) / duration
		setBootPreview(progress)

		if progress >= 1 then
			holdCompleted = true
			stopHoldLoop()
			setBootPreview(1)
			Remotes.get("RequestBootGenerator"):FireServer()
		end
	end)
end

local function onBootHoldEnded()
	if holdCompleted then
		return
	end
	stopHoldLoop()
	resetBootPreview()
end

local function hookBootPrompt(prompt: ProximityPrompt)
	if prompt:GetAttribute("BootClientHooked") then
		return
	end
	prompt:SetAttribute("BootClientHooked", true)
	bootPrompt = prompt

	prompt.PromptButtonHoldBegan:Connect(function(triggeringPlayer: Player)
		if triggeringPlayer == player then
			onBootHoldBegan()
		end
	end)

	prompt.PromptButtonHoldEnded:Connect(function(triggeringPlayer: Player)
		if triggeringPlayer == player then
			onBootHoldEnded()
		end
	end)

	prompt.Triggered:Connect(function(triggeringPlayer: Player)
		if triggeringPlayer == player then
			holdCompleted = true
			stopHoldLoop()
			setBootPreview(1)
		end
	end)
end

local function setupGenerator(generator: BasePart)
	local prompt = generator:FindFirstChild("BootPrompt") :: ProximityPrompt?
	if prompt then
		hookBootPrompt(prompt)
	end
end

for _, inst in CollectionService:GetTagged("Generator") do
	if inst:IsA("BasePart") then
		setupGenerator(inst)
	end
end

CollectionService:GetInstanceAddedSignal("Generator"):Connect(function(inst)
	if inst:IsA("BasePart") then
		task.defer(function()
			setupGenerator(inst)
		end)
	end
end)

Remotes.get("PowerStateUpdated").OnClientEvent:Connect(function(state: { [string]: any })
	if state.powerOn == true then
		stopHoldLoop()
		setBootPreview(1)
	elseif not holdingBoot then
		resetBootPreview()
	end
end)

Remotes.get("RoundStateChanged").OnClientEvent:Connect(function(state: string)
	if state ~= "Playing" then
		holdCompleted = false
		stopHoldLoop()
		resetBootPreview()
	end
end)

defaultAmbient = Lighting.Ambient
defaultBrightness = Lighting.Brightness
