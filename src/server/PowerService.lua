--!strict
--[[
	PowerService (Server)
	Phase 3: fuel cells, generator boot, power decay, murderer sabotage, keys, and doors.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PlayerUtils = require(ReplicatedStorage.Shared.PlayerUtils)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoleManager = require(ReplicatedStorage.Shared.RoleManager)
local RoundManager = require(ReplicatedStorage.Shared.RoundManager)

local PowerService = {}

local cellsDeposited = 0
local powerOn = false
local sabotageUsesLeft = GameConfig.MurdererSabotageUses
local decayTask: thread? = nil
local defaultAmbient = Lighting.Ambient
local defaultBrightness = Lighting.Brightness

local function isPlaying(): boolean
	return RoundManager.getState() == "Playing"
end

local function canDoObjectives(player: Player): boolean
	return isPlaying()
		and PlayerUtils.isAlive(player)
		and not PlayerUtils.isStunned(player)
		and RoleManager.getRole(player) ~= "Murderer"
end

local function getGenerator(): BasePart?
	for _, inst in CollectionService:GetTagged("Generator") do
		if inst:IsA("BasePart") then
			return inst
		end
	end
	return nil
end

local function broadcastPowerState()
	Remotes.get("PowerStateUpdated"):FireAllClients({
		cellsDeposited = cellsDeposited,
		cellsRequired = GameConfig.FuelCellsRequired,
		powerOn = powerOn,
		sabotageUsesLeft = sabotageUsesLeft,
	})
end

local function setPowerVisuals(on: boolean)
	local generator = getGenerator()
	if generator then
		generator:SetAttribute("PowerOn", on)
		local light = generator:FindFirstChildOfClass("PointLight")
		if light then
			light.Brightness = if on then 2.5 else 0
		end
	end

	if on then
		Lighting.Ambient = Color3.fromRGB(55, 55, 65)
		Lighting.Brightness = 1.6
	else
		Lighting.Ambient = defaultAmbient
		Lighting.Brightness = defaultBrightness
	end

	for _, inst in CollectionService:GetTagged("MapLight") do
		if inst:IsA("BasePart") then
			local light = inst:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = on
			end
		end
	end
end

local function stopDecayLoop()
	if decayTask then
		task.cancel(decayTask)
		decayTask = nil
	end
end

local function startDecayLoop()
	stopDecayLoop()
	decayTask = task.spawn(function()
		task.wait(GameConfig.PowerDecayDuration)
		if powerOn and isPlaying() then
			powerOn = false
			setPowerVisuals(false)
			lockAllDoors()
			broadcastPowerState()
			Remotes.get("PowerAlert"):FireAllClients("Power has gone out! Restore the generator.")
		end
	end)
end

local function lockAllDoors()
	for _, inst in CollectionService:GetTagged("Door") do
		if inst:IsA("BasePart") then
			inst.CanCollide = true
			inst.Transparency = 0
			inst:SetAttribute("Locked", true)
		end
	end
end

local function unlockDoor(door: BasePart)
	door.CanCollide = false
	door.Transparency = 1
	door:SetAttribute("Locked", false)
end

local function resetFuelCells()
	for _, inst in CollectionService:GetTagged("FuelCell") do
		if inst:IsA("BasePart") then
			inst:SetAttribute("Collected", false)
			inst.Transparency = 0
			inst.CanCollide = true
			local prompt = inst:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Enabled = true
			end
		end
	end
end

local function resetKey()
	for _, inst in CollectionService:GetTagged("Key") do
		if inst:IsA("BasePart") then
			inst:SetAttribute("Collected", false)
			inst.Transparency = 0
			inst.CanCollide = true
			local prompt = inst:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Enabled = true
			end
		end
	end
end

local function updateGeneratorPrompts()
	local generator = getGenerator()
	if not generator then
		return
	end

	local bootPrompt = generator:FindFirstChild("BootPrompt") :: ProximityPrompt?
	local depositPrompt = generator:FindFirstChild("DepositPrompt") :: ProximityPrompt?
	local sabotagePrompt = generator:FindFirstChild("SabotagePrompt") :: ProximityPrompt?
	local maintainPrompt = generator:FindFirstChild("MaintainPrompt") :: ProximityPrompt?

	if depositPrompt then
		depositPrompt.Enabled = isPlaying() and not powerOn
	end
	if bootPrompt then
		bootPrompt.Enabled = isPlaying()
			and not powerOn
			and cellsDeposited >= GameConfig.FuelCellsRequired
	end
	if sabotagePrompt then
		sabotagePrompt.Enabled = isPlaying() and powerOn and sabotageUsesLeft > 0
	end
	if maintainPrompt then
		maintainPrompt.Enabled = isPlaying() and powerOn
	end
end

function PowerService.turnOnPower()
	powerOn = true
	setPowerVisuals(true)
	updateGeneratorPrompts()
	startDecayLoop()
	broadcastPowerState()
	Remotes.get("PowerAlert"):FireAllClients("Power is ON! Get the key and unlock the door.")
end

function PowerService.turnOffPower(reason: string)
	powerOn = false
	setPowerVisuals(false)
	stopDecayLoop()
	lockAllDoors()
	updateGeneratorPrompts()
	broadcastPowerState()
	Remotes.get("PowerAlert"):FireAllClients(reason)
end

local function onPickupFuelCell(player: Player, cell: BasePart)
	if not canDoObjectives(player) then
		return
	end
	if cell:GetAttribute("Collected") == true then
		return
	end
	if player:GetAttribute(GameConfig.CarryingFuelAttribute) == true then
		return
	end

	cell:SetAttribute("Collected", true)
	cell.Transparency = 1
	cell.CanCollide = false
	local prompt = cell:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end

	player:SetAttribute(GameConfig.CarryingFuelAttribute, true)
	broadcastPowerState()
end

local function onDepositFuelCell(player: Player)
	if not canDoObjectives(player) then
		return
	end
	if player:GetAttribute(GameConfig.CarryingFuelAttribute) ~= true then
		return
	end
	if cellsDeposited >= GameConfig.FuelCellsRequired then
		return
	end

	player:SetAttribute(GameConfig.CarryingFuelAttribute, false)
	cellsDeposited += 1

	local generator = getGenerator()
	if generator then
		generator:SetAttribute("CellsDeposited", cellsDeposited)
	end

	updateGeneratorPrompts()
	broadcastPowerState()

	if cellsDeposited >= GameConfig.FuelCellsRequired then
		Remotes.get("PowerAlert"):FireAllClients("All fuel cells deposited! Boot the generator.")
	end
end

local function onBootGenerator(player: Player)
	if not canDoObjectives(player) then
		return
	end
	if cellsDeposited < GameConfig.FuelCellsRequired then
		return
	end
	if powerOn then
		return
	end

	PowerService.turnOnPower()
end

local function onMaintainPower(player: Player)
	if not canDoObjectives(player) then
		return
	end
	if not powerOn then
		return
	end
	startDecayLoop()
	Remotes.get("PowerAlert"):FireClient(player, "Power stabilized.")
end

local function onSabotage(player: Player)
	if not isPlaying() or not PlayerUtils.isAlive(player) then
		return
	end
	if RoleManager.getRole(player) ~= "Murderer" then
		return
	end
	if not powerOn or sabotageUsesLeft <= 0 then
		return
	end

	sabotageUsesLeft -= 1
	PowerService.turnOffPower("A murderer sabotaged the generator!")
	updateGeneratorPrompts()
end

local function onPickupKey(player: Player, key: BasePart)
	if not canDoObjectives(player) then
		return
	end
	if key:GetAttribute("Collected") == true then
		return
	end
	if player:GetAttribute(GameConfig.HasKeyAttribute) == true then
		return
	end

	key:SetAttribute("Collected", true)
	key.Transparency = 1
	key.CanCollide = false
	local prompt = key:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end

	player:SetAttribute(GameConfig.HasKeyAttribute, true)
	broadcastPowerState()
	Remotes.get("PowerAlert"):FireClient(player, "You picked up the office key.")
end

local function onTryOpenDoor(player: Player, door: BasePart)
	if not canDoObjectives(player) then
		return
	end
	if door:GetAttribute("Locked") ~= true then
		return
	end
	if not powerOn then
		Remotes.get("PowerAlert"):FireClient(player, "The door needs power.")
		return
	end
	if door:GetAttribute("RequiresKey") == true and player:GetAttribute(GameConfig.HasKeyAttribute) ~= true then
		Remotes.get("PowerAlert"):FireClient(player, "You need the office key.")
		return
	end

	unlockDoor(door)
	Remotes.get("PowerAlert"):FireAllClients(`{player.Name} unlocked a door!`)
end

local function connectNamedPrompt(parent: Instance, promptName: string, handler: (Player) -> ())
	local prompt = parent:FindFirstChild(promptName) :: ProximityPrompt?
	if not prompt then
		return
	end
	if prompt:GetAttribute("Connected") then
		return
	end
	prompt:SetAttribute("Connected", true)
	prompt.Triggered:Connect(handler)
end

local function setupGenerator(generator: BasePart)
	generator:SetAttribute("CellsDeposited", 0)

	local deposit = Instance.new("ProximityPrompt")
	deposit.Name = "DepositPrompt"
	deposit.ActionText = "Deposit Fuel Cell"
	deposit.ObjectText = "Generator"
	deposit.HoldDuration = 0
	deposit.MaxActivationDistance = 10
	deposit.Parent = generator
	connectNamedPrompt(generator, "DepositPrompt", onDepositFuelCell)

	local boot = Instance.new("ProximityPrompt")
	boot.Name = "BootPrompt"
	boot.ActionText = "Boot Generator"
	boot.ObjectText = "Generator"
	boot.HoldDuration = GameConfig.GeneratorBootDuration
	boot.MaxActivationDistance = 10
	boot.Enabled = false
	boot.Parent = generator
	connectNamedPrompt(generator, "BootPrompt", onBootGenerator)

	local maintain = Instance.new("ProximityPrompt")
	maintain.Name = "MaintainPrompt"
	maintain.ActionText = "Maintain Power"
	maintain.ObjectText = "Generator"
	maintain.HoldDuration = 3
	maintain.MaxActivationDistance = 10
	maintain.Enabled = false
	maintain.Parent = generator
	connectNamedPrompt(generator, "MaintainPrompt", onMaintainPower)

	local sabotage = Instance.new("ProximityPrompt")
	sabotage.Name = "SabotagePrompt"
	sabotage.ActionText = "Sabotage"
	sabotage.ObjectText = "Generator"
	sabotage.HoldDuration = 4
	sabotage.MaxActivationDistance = 10
	sabotage.Enabled = false
	sabotage.Parent = generator
	connectNamedPrompt(generator, "SabotagePrompt", onSabotage)
end

local function hookFuelCell(inst: BasePart)
	if inst:GetAttribute("PowerHooked") then
		return
	end
	inst:SetAttribute("PowerHooked", true)

	local prompt = inst:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "FuelPrompt"
		prompt.ActionText = "Take Fuel Cell"
		prompt.ObjectText = "Fuel Cell"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.Parent = inst
	end
	connectNamedPrompt(inst, prompt.Name, function(player: Player)
		onPickupFuelCell(player, inst)
	end)
end

local function hookDoor(inst: BasePart)
	if inst:GetAttribute("PowerHooked") then
		return
	end
	inst:SetAttribute("PowerHooked", true)

	local prompt = inst:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "DoorPrompt"
		prompt.ActionText = "Unlock Door"
		prompt.ObjectText = "Locked Door"
		prompt.HoldDuration = 1
		prompt.MaxActivationDistance = 10
		prompt.Parent = inst
	end
	connectNamedPrompt(inst, prompt.Name, function(player: Player)
		onTryOpenDoor(player, inst)
	end)
end

local function hookKey(inst: BasePart)
	if inst:GetAttribute("PowerHooked") then
		return
	end
	inst:SetAttribute("PowerHooked", true)

	local prompt = inst:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	if prompt.Name == "ProximityPrompt" then
		prompt.Name = "KeyPrompt"
	end
	connectNamedPrompt(inst, prompt.Name, function(player: Player)
		onPickupKey(player, inst)
	end)
end

local function setupWorldObjects()
	for _, inst in CollectionService:GetTagged("FuelCell") do
		if inst:IsA("BasePart") then
			hookFuelCell(inst)
		end
	end

	for _, inst in CollectionService:GetTagged("Key") do
		if inst:IsA("BasePart") then
			hookKey(inst)
		end
	end

	for _, inst in CollectionService:GetTagged("Door") do
		if inst:IsA("BasePart") then
			hookDoor(inst)
		end
	end

	for _, inst in CollectionService:GetTagged("Generator") do
		if inst:IsA("BasePart") and not inst:GetAttribute("GeneratorSetup") then
			inst:SetAttribute("GeneratorSetup", true)
			setupGenerator(inst)
		end
	end
end

function PowerService.resetForRound()
	cellsDeposited = 0
	powerOn = false
	sabotageUsesLeft = GameConfig.MurdererSabotageUses
	stopDecayLoop()
	setPowerVisuals(false)
	resetFuelCells()
	resetKey()
	lockAllDoors()

	for _, player in Players:GetPlayers() do
		player:SetAttribute(GameConfig.CarryingFuelAttribute, false)
		player:SetAttribute(GameConfig.HasKeyAttribute, false)
	end

	local generator = getGenerator()
	if generator then
		generator:SetAttribute("CellsDeposited", 0)
	end

	updateGeneratorPrompts()
	broadcastPowerState()
end

function PowerService.init()
	defaultAmbient = Lighting.Ambient
	defaultBrightness = Lighting.Brightness

	setupWorldObjects()

	CollectionService:GetInstanceAddedSignal("FuelCell"):Connect(function(inst)
		task.defer(setupWorldObjects)
	end)
	CollectionService:GetInstanceAddedSignal("Generator"):Connect(function(inst)
		task.defer(setupWorldObjects)
	end)
	CollectionService:GetInstanceAddedSignal("Door"):Connect(function(inst)
		task.defer(setupWorldObjects)
	end)
	CollectionService:GetInstanceAddedSignal("Key"):Connect(function(inst)
		task.defer(setupWorldObjects)
	end)

	RoundManager.onStateChanged(function(state: GameConfig.RoundState)
		if state == "Playing" then
			PowerService.resetForRound()
		elseif state == "Ended" or state == "Intermission" then
			stopDecayLoop()
			setPowerVisuals(false)
		end
	end)

	print("[newmm] PowerService initialized.")
end

return PowerService
