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

local function canDoObjectives(player: Player): (boolean, string?)
	if not isPlaying() then
		return false, "Wait for the round to start."
	end
	if not PlayerUtils.isAlive(player) then
		return false, "You are eliminated."
	end
	if PlayerUtils.isStunned(player) then
		return false, "You are stunned."
	end
	if RoleManager.getRole(player) == "Murderer" then
		return false, "Murderers cannot do objectives."
	end
	return true, nil
end

local function getGenerator(): BasePart?
	for _, inst in CollectionService:GetTagged("Generator") do
		if inst:IsA("BasePart") then
			return inst
		end
	end
	return nil
end

local function notifyPlayer(player: Player)
	local carrying = player:GetAttribute(GameConfig.CarryingFuelAttribute) == true
	local hasKey = player:GetAttribute(GameConfig.HasKeyAttribute) == true

	Remotes.get("PlayerObjectivesUpdated"):FireClient(player, {
		carryingFuel = carrying,
		hasKey = hasKey,
	})

	Remotes.get("PowerStateUpdated"):FireClient(player, {
		cellsDeposited = cellsDeposited,
		cellsRequired = GameConfig.FuelCellsRequired,
		powerOn = powerOn,
		sabotageUsesLeft = sabotageUsesLeft,
		carryingFuel = carrying,
		hasKey = hasKey,
	})
end

local function broadcastPowerState()
	for _, player in Players:GetPlayers() do
		notifyPlayer(player)
	end
end

local function setPromptsEnabled(enabled: boolean)
	for _, inst in CollectionService:GetTagged("FuelCell") do
		local prompt = inst:FindFirstChildOfClass("ProximityPrompt")
		if prompt and inst:IsA("BasePart") and inst:GetAttribute("Collected") ~= true then
			prompt.Enabled = enabled
		end
	end
	for _, inst in CollectionService:GetTagged("Key") do
		local prompt = inst:FindFirstChildOfClass("ProximityPrompt")
		if prompt and inst:IsA("BasePart") and inst:GetAttribute("Collected") ~= true then
			prompt.Enabled = enabled
		end
	end
	for _, inst in CollectionService:GetTagged("Door") do
		local prompt = inst:FindFirstChildOfClass("ProximityPrompt")
		if prompt and inst:IsA("BasePart") and inst:GetAttribute("Locked") == true then
			prompt.Enabled = enabled
		end
	end
	updateGeneratorPrompts()
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

local function updateGeneratorStatusLabel(generator: BasePart)
	local gui = generator:FindFirstChild("StatusBillboard") :: BillboardGui?
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "StatusBillboard"
		gui.Size = UDim2.fromOffset(200, 50)
		gui.StudsOffset = Vector3.new(0, 5, 0)
		gui.AlwaysOnTop = true
		gui.Parent = generator

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 0.3
		label.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Parent = gui
	end

	local label = gui:FindFirstChild("Label") :: TextLabel
	if powerOn then
		label.Text = "POWER: ON"
		label.TextColor3 = Color3.fromRGB(80, 255, 120)
	elseif cellsDeposited >= GameConfig.FuelCellsRequired then
		label.Text = "HOLD E TO BOOT!"
		label.TextColor3 = Color3.fromRGB(255, 220, 80)
	else
		label.Text = `FUEL: {cellsDeposited}/{GameConfig.FuelCellsRequired}`
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

local function updateGeneratorPrompts()
	local generator = getGenerator()
	if not generator then
		return
	end

	local depositPrompt = generator:FindFirstChild("DepositPrompt") :: ProximityPrompt?
	local bootPrompt = generator:FindFirstChild("BootPrompt") :: ProximityPrompt?
	local maintainPrompt = generator:FindFirstChild("MaintainPrompt") :: ProximityPrompt?
	local sabotagePrompt = generator:FindFirstChild("SabotagePrompt") :: ProximityPrompt?
	local playing = isPlaying()
	local fuelReady = cellsDeposited >= GameConfig.FuelCellsRequired

	if depositPrompt then
		depositPrompt.ObjectText = `Generator ({cellsDeposited}/{GameConfig.FuelCellsRequired})`
		depositPrompt.Enabled = playing and not powerOn and not fuelReady
	end

	if bootPrompt then
		bootPrompt.Enabled = playing and not powerOn and fuelReady
	end

	if maintainPrompt then
		maintainPrompt.Enabled = playing and powerOn
	end

	if sabotagePrompt then
		sabotagePrompt.Enabled = playing and powerOn and sabotageUsesLeft > 0
	end

	updateGeneratorStatusLabel(generator)
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
	local ok, reason = canDoObjectives(player)
	if not ok then
		if reason then
			Remotes.get("PowerAlert"):FireClient(player, reason)
		end
		return
	end
	if cell:GetAttribute("Collected") == true then
		Remotes.get("PowerAlert"):FireClient(player, "That fuel cell is already taken.")
		return
	end
	if player:GetAttribute(GameConfig.CarryingFuelAttribute) == true then
		Remotes.get("PowerAlert"):FireClient(player, "You are already carrying a fuel cell.")
		return
	end

	player:SetAttribute(GameConfig.CarryingFuelAttribute, true)
	cell:SetAttribute("Collected", true)
	cell.Transparency = 1
	cell.CanCollide = false
	local prompt = cell:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end

	notifyPlayer(player)
	Remotes.get("PowerAlert"):FireClient(player, "Picked up fuel cell. Bring it to the generator.")
end

local function onDepositFuelCell(player: Player)
	local ok, reason = canDoObjectives(player)
	if not ok then
		if reason then
			Remotes.get("PowerAlert"):FireClient(player, reason)
		end
		return
	end
	if player:GetAttribute(GameConfig.CarryingFuelAttribute) ~= true then
		Remotes.get("PowerAlert"):FireClient(player, "You are not carrying a fuel cell.")
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
		Remotes.get("PowerAlert"):FireClient(
			player,
			"All fuel deposited! Go to generator — HOLD E for 5 seconds on 'Boot Generator'."
		)
	end
end

local function onDepositInteract(player: Player)
	if not isPlaying() or powerOn then
		return
	end

	if player:GetAttribute(GameConfig.CarryingFuelAttribute) == true then
		onDepositFuelCell(player)
		return
	end

	Remotes.get("PowerAlert"):FireClient(player, "Bring a fuel cell here first.")
end

local function onBootGenerator(player: Player)
	local ok, reason = canDoObjectives(player)
	if not ok then
		if reason then
			Remotes.get("PowerAlert"):FireClient(player, reason)
		end
		return
	end
	if cellsDeposited < GameConfig.FuelCellsRequired then
		return
	end
	if powerOn then
		return
	end

	PowerService.turnOnPower()
	Remotes.get("PowerAlert"):FireClient(player, "Generator booted! Power is ON.")
end

local function onMaintainPower(player: Player)
	local ok, reason = canDoObjectives(player)
	if not ok then
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
	local ok, reason = canDoObjectives(player)
	if not ok then
		if reason then
			Remotes.get("PowerAlert"):FireClient(player, reason)
		end
		return
	end
	if key:GetAttribute("Collected") == true then
		Remotes.get("PowerAlert"):FireClient(player, "The key is already taken.")
		return
	end
	if player:GetAttribute(GameConfig.HasKeyAttribute) == true then
		Remotes.get("PowerAlert"):FireClient(player, "You already have the key.")
		return
	end

	player:SetAttribute(GameConfig.HasKeyAttribute, true)
	key:SetAttribute("Collected", true)
	key.Transparency = 1
	key.CanCollide = false
	local prompt = key:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end

	notifyPlayer(player)
	Remotes.get("PowerAlert"):FireClient(player, "You picked up the office key.")
end

local function onTryOpenDoor(player: Player, door: BasePart)
	local ok, reason = canDoObjectives(player)
	if not ok then
		if reason then
			Remotes.get("PowerAlert"):FireClient(player, reason)
		end
		return
	end
	if door:GetAttribute("Locked") ~= true then
		return
	end
	if not powerOn then
		Remotes.get("PowerAlert"):FireClient(player, "Power is off. Boot the generator first.")
		return
	end
	local needsKey = door:GetAttribute("RequiresKey")
	if needsKey ~= false and player:GetAttribute(GameConfig.HasKeyAttribute) ~= true then
		Remotes.get("PowerAlert"):FireClient(player, "You need the office key.")
		return
	end

	unlockDoor(door)
	Remotes.get("PowerAlert"):FireAllClients(`{player.Name} unlocked the door!`)
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
	deposit.MaxActivationDistance = 12
	deposit.RequiresLineOfSight = false
	deposit.KeyboardKeyCode = Enum.KeyCode.E
	deposit.GamepadKeyCode = Enum.KeyCode.ButtonX
	deposit.Enabled = false
	deposit.Parent = generator
	connectNamedPrompt(generator, "DepositPrompt", onDepositInteract)

	local boot = Instance.new("ProximityPrompt")
	boot.Name = "BootPrompt"
	boot.ActionText = "Boot Generator"
	boot.ObjectText = "READY — HOLD E!"
	boot.HoldDuration = GameConfig.GeneratorBootDuration
	boot.MaxActivationDistance = 12
	boot.RequiresLineOfSight = false
	boot.KeyboardKeyCode = Enum.KeyCode.E
	boot.GamepadKeyCode = Enum.KeyCode.ButtonX
	boot.Enabled = false
	boot.Parent = generator
	connectNamedPrompt(generator, "BootPrompt", onBootGenerator)

	local maintain = Instance.new("ProximityPrompt")
	maintain.Name = "MaintainPrompt"
	maintain.ActionText = "Maintain Power"
	maintain.ObjectText = "Generator (ON)"
	maintain.HoldDuration = 2
	maintain.MaxActivationDistance = 12
	maintain.RequiresLineOfSight = false
	maintain.KeyboardKeyCode = Enum.KeyCode.E
	maintain.GamepadKeyCode = Enum.KeyCode.ButtonX
	maintain.Enabled = false
	maintain.Parent = generator
	connectNamedPrompt(generator, "MaintainPrompt", onMaintainPower)

	local sabotage = Instance.new("ProximityPrompt")
	sabotage.Name = "SabotagePrompt"
	sabotage.ActionText = "Sabotage"
	sabotage.ObjectText = "Generator"
	sabotage.HoldDuration = 3
	sabotage.MaxActivationDistance = 12
	sabotage.RequiresLineOfSight = false
	sabotage.UIOffset = Vector2.new(0, 50)
	sabotage.Enabled = false
	sabotage.Parent = generator
	connectNamedPrompt(generator, "SabotagePrompt", onSabotage)

	updateGeneratorStatusLabel(generator)
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
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
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
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 12
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
	setPromptsEnabled(true)
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

	Remotes.get("RequestBootGenerator").OnServerEvent:Connect(function(player: Player)
		onBootGenerator(player)
	end)

	RoundManager.onStateChanged(function(state: GameConfig.RoundState)
		if state == "Playing" then
			PowerService.resetForRound()
		elseif state == "Ended" or state == "Intermission" or state == "RoleReveal" then
			stopDecayLoop()
			setPowerVisuals(false)
			setPromptsEnabled(false)
		end
	end)

	print("[newmm] PowerService initialized.")
end

return PowerService
