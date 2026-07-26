--!strict
--[[
	CombatService (Server)
	Murderer assassinate, sheriff shoot/arrest, death, gun drop, and round combat reset.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PlayerUtils = require(ReplicatedStorage.Shared.PlayerUtils)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoleManager = require(ReplicatedStorage.Shared.RoleManager)
local RoundManager = require(ReplicatedStorage.Shared.RoundManager)

local CombatService = {}

local assassinateCooldowns: { [Player]: number } = {}
local sheriffAmmo: { [Player]: number } = {}
local revolverTemplate: Tool? = nil

local function isRoundActive(): boolean
	return RoundManager.getState() == "Playing"
end

local function getPlayerFromHitPart(part: BasePart): Player?
	local model = part:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	return Players:GetPlayerFromCharacter(model)
end

local function getTargetInFront(attacker: Player, range: number): Player?
	local _, _, root = PlayerUtils.getCharacterHumanoid(attacker)
	if not root then
		return nil
	end

	local origin = root.Position
	local look = root.CFrame.LookVector
	local bestTarget: Player? = nil
	local bestDistance = range

	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= attacker and PlayerUtils.isAlive(otherPlayer) then
			local _, otherHumanoid, otherRoot = PlayerUtils.getCharacterHumanoid(otherPlayer)
			if otherHumanoid and otherRoot and otherHumanoid.Health > 0 then
				local offset = otherRoot.Position - origin
				local distance = offset.Magnitude
				if distance <= range and distance > 0 then
					local facing = look:Dot(offset.Unit)
					if facing > 0.35 and distance < bestDistance then
						bestTarget = otherPlayer
						bestDistance = distance
					end
				end
			end
		end
	end

	return bestTarget
end

local function getShootTarget(shooter: Player): Player?
	local _, _, root = PlayerUtils.getCharacterHumanoid(shooter)
	if not root then
		return nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { shooter.Character :: Model }

	local result = workspace:Raycast(root.Position, root.CFrame.LookVector * GameConfig.ShootRange, params)
	if not result then
		return nil
	end

	return getPlayerFromHitPart(result.Instance)
end

local function broadcastCombatState(player: Player)
	local role = RoleManager.getRole(player)
	local cooldownRemaining = 0
	local cooldownEnds = assassinateCooldowns[player]
	if cooldownEnds then
		cooldownRemaining = math.max(0, cooldownEnds - os.clock())
	end

	Remotes.get("CombatStateUpdated"):FireClient(
		player,
		role,
		sheriffAmmo[player] or 0,
		cooldownRemaining,
		PlayerUtils.hasGun(player)
	)
end

local function broadcastCombatStateToAll()
	for _, player in Players:GetPlayers() do
		broadcastCombatState(player)
	end
end

local function removeRevolverFromPlayer(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character

	if backpack then
		local tool = backpack:FindFirstChild(GameConfig.RevolverToolName)
		if tool then
			tool:Destroy()
		end
	end

	if character then
		local tool = character:FindFirstChild(GameConfig.RevolverToolName)
		if tool then
			tool:Destroy()
		end
	end

	player:SetAttribute(GameConfig.HasGunAttribute, false)
end

local function createRevolverTemplate(): Tool
	local tool = Instance.new("Tool")
	tool.Name = GameConfig.RevolverToolName
	tool.RequiresHandle = true
	tool.CanBeDropped = true

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.6, 1.2)
	handle.Color = Color3.fromRGB(50, 50, 55)
	handle.Material = Enum.Material.Metal
	handle.Parent = tool

	return tool
end

local function giveRevolver(player: Player)
	removeRevolverFromPlayer(player)

	local template = revolverTemplate or createRevolverTemplate()
	local gun = template:Clone()
	gun.Parent = player:FindFirstChildOfClass("Backpack") or player

	player:SetAttribute(GameConfig.HasGunAttribute, true)
	sheriffAmmo[player] = GameConfig.SheriffAmmo
	broadcastCombatState(player)
end

local function dropRevolver(player: Player)
	local character, _, root = PlayerUtils.getCharacterHumanoid(player)
	if not character or not root then
		return
	end

	local gun: Tool? = nil
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		gun = backpack:FindFirstChild(GameConfig.RevolverToolName) :: Tool?
	end
	if not gun and character then
		gun = character:FindFirstChild(GameConfig.RevolverToolName) :: Tool?
	end

	if not gun then
		return
	end

	gun.Parent = workspace
	local handle = gun:FindFirstChild("Handle") :: BasePart?
	if handle then
		handle.CFrame = root.CFrame * CFrame.new(0, 0, -2)
		handle.AssemblyLinearVelocity = root.CFrame.LookVector * 10
	end

	player:SetAttribute(GameConfig.HasGunAttribute, false)
end

local function setMovementLocked(player: Player, locked: boolean)
	local _, humanoid = PlayerUtils.getCharacterHumanoid(player)
	if not humanoid then
		return
	end

	if locked then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	else
		humanoid.WalkSpeed = GameConfig.DefaultWalkSpeed
		humanoid.JumpPower = GameConfig.DefaultJumpPower
	end
end

local function applyStun(target: Player)
	target:SetAttribute(GameConfig.StunnedAttribute, true)
	setMovementLocked(target, true)
	Remotes.get("PlayerStunned"):FireAllClients(target, GameConfig.ArrestStunDuration)

	task.delay(GameConfig.ArrestStunDuration, function()
		if not PlayerUtils.isAlive(target) then
			return
		end
		target:SetAttribute(GameConfig.StunnedAttribute, false)
		setMovementLocked(target, false)
	end)
end

local function enterSpectator(player: Player)
	player:SetAttribute(GameConfig.IsAliveAttribute, false)
	player:SetAttribute(GameConfig.StunnedAttribute, false)
	player:SetAttribute(GameConfig.HasGunAttribute, false)

	removeRevolverFromPlayer(player)

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end

	player.CharacterAutoLoads = false
end

function CombatService.killPlayer(victim: Player, killer: Player?)
	if not PlayerUtils.isAlive(victim) then
		return
	end

	local victimRole = RoleManager.getRole(victim)
	if victimRole == "Sheriff" then
		dropRevolver(victim)
	end

	enterSpectator(victim)
	Remotes.get("PlayerDied"):FireAllClients(victim, if killer then killer.Name else nil)
	broadcastCombatStateToAll()
	RoundManager.requestWinCheck()
end

local function canMurdererAttack(attacker: Player): boolean
	return isRoundActive()
		and PlayerUtils.isAlive(attacker)
		and not PlayerUtils.isStunned(attacker)
		and RoleManager.getRole(attacker) == "Murderer"
end

local function canUseGun(attacker: Player): boolean
	return isRoundActive()
		and PlayerUtils.isAlive(attacker)
		and not PlayerUtils.isStunned(attacker)
		and PlayerUtils.hasGun(attacker)
		and (sheriffAmmo[attacker] or 0) > 0
end

local function canArrest(attacker: Player): boolean
	return isRoundActive()
		and PlayerUtils.isAlive(attacker)
		and not PlayerUtils.isStunned(attacker)
		and RoleManager.getRole(attacker) == "Sheriff"
end

function CombatService.handleAssassinate(attacker: Player)
	if not canMurdererAttack(attacker) then
		return
	end

	local cooldownEnds = assassinateCooldowns[attacker]
	if cooldownEnds and os.clock() < cooldownEnds then
		return
	end

	local target = getTargetInFront(attacker, GameConfig.AssassinateRange)
	if not target or not PlayerUtils.isAlive(target) then
		return
	end

	local targetRole = RoleManager.getRole(target)
	if targetRole == "Murderer" then
		return
	end

	assassinateCooldowns[attacker] = os.clock() + GameConfig.AssassinateCooldown
	CombatService.killPlayer(target, attacker)
	broadcastCombatState(attacker)
end

function CombatService.handleShoot(shooter: Player)
	if not canUseGun(shooter) then
		return
	end

	local target = getShootTarget(shooter)
	if not target or not PlayerUtils.isAlive(target) then
		return
	end

	local ammo = sheriffAmmo[shooter] or 0
	if ammo <= 0 then
		return
	end

	sheriffAmmo[shooter] = ammo - 1
	broadcastCombatState(shooter)

	local targetRole = RoleManager.getRole(target)
	if targetRole == "Murderer" then
		CombatService.killPlayer(target, shooter)
	elseif targetRole == "Innocent" or targetRole == "Sheriff" then
		-- Friendly fire
		CombatService.killPlayer(target, shooter)
	end

	if sheriffAmmo[shooter] == 0 then
		removeRevolverFromPlayer(shooter)
	end
end

function CombatService.handleArrest(officer: Player)
	if not canArrest(officer) then
		return
	end

	local target = getTargetInFront(officer, GameConfig.AssassinateRange)
	if not target or not PlayerUtils.isAlive(target) or PlayerUtils.isStunned(target) then
		return
	end

	applyStun(target)
end

local function onGunPickedUp(player: Player, tool: Tool)
	if tool.Name ~= GameConfig.RevolverToolName then
		return
	end
	if not isRoundActive() or not PlayerUtils.isAlive(player) then
		tool:Destroy()
		return
	end

	local role = RoleManager.getRole(player)
	if role == "Murderer" then
		tool.Parent = workspace
		return
	end

	player:SetAttribute(GameConfig.HasGunAttribute, true)
	if sheriffAmmo[player] == nil then
		sheriffAmmo[player] = GameConfig.SheriffAmmo
	end
	broadcastCombatState(player)
end

local function watchPlayerTools(player: Player)
	local function connectBackpack(backpack: Backpack)
		backpack.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				onGunPickedUp(player, child)
			end
		end)
	end

	if player:FindFirstChildOfClass("Backpack") then
		connectBackpack(player:FindFirstChildOfClass("Backpack") :: Backpack)
	end

	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			connectBackpack(child)
		end
	end)
end

local function spawnPlayer(player: Player)
	player.CharacterAutoLoads = true
	player:LoadCharacter()

	local role = RoleManager.getRole(player)
	if role == "Sheriff" then
		task.defer(function()
			if PlayerUtils.isAlive(player) and RoundManager.getState() == "Playing" then
				giveRevolver(player)
			end
		end)
	end
end

function CombatService.resetForRound()
	assassinateCooldowns = {}
	sheriffAmmo = {}

	for _, player in Players:GetPlayers() do
		player:SetAttribute(GameConfig.StunnedAttribute, false)
		player:SetAttribute(GameConfig.HasGunAttribute, false)
		removeRevolverFromPlayer(player)
	end

	for _, tool in workspace:GetChildren() do
		if tool:IsA("Tool") and tool.Name == GameConfig.RevolverToolName then
			tool:Destroy()
		end
	end
end

function CombatService.preparePlayersForRound()
	for _, player in Players:GetPlayers() do
		spawnPlayer(player)
	end
end

function CombatService.cleanupRound()
	for _, player in Players:GetPlayers() do
		player:SetAttribute(GameConfig.StunnedAttribute, false)
		removeRevolverFromPlayer(player)
		player.CharacterAutoLoads = true
	end

	for _, tool in workspace:GetChildren() do
		if tool:IsA("Tool") and tool.Name == GameConfig.RevolverToolName then
			tool:Destroy()
		end
	end
end

function CombatService.init()
	revolverTemplate = createRevolverTemplate()
	revolverTemplate.Parent = ServerStorage

	Remotes.get("Assassinate").OnServerEvent:Connect(function(player: Player)
		CombatService.handleAssassinate(player)
	end)

	Remotes.get("Shoot").OnServerEvent:Connect(function(player: Player)
		CombatService.handleShoot(player)
	end)

	Remotes.get("Arrest").OnServerEvent:Connect(function(player: Player)
		CombatService.handleArrest(player)
	end)

	for _, player in Players:GetPlayers() do
		watchPlayerTools(player)
	end

	Players.PlayerAdded:Connect(function(player)
		watchPlayerTools(player)
		player.CharacterAdded:Connect(function()
			if not PlayerUtils.isAlive(player) and RoundManager.getState() == "Playing" then
				task.defer(function()
					if player.Character then
						local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
						if humanoid then
							humanoid.Health = 0
						end
					end
				end)
			elseif PlayerUtils.isAlive(player) then
				setMovementLocked(player, PlayerUtils.isStunned(player))
			end
		end)
	end)

	RoundManager.onStateChanged(function(state: GameConfig.RoundState)
		if state == "Playing" then
			CombatService.resetForRound()
			task.delay(0.5, function()
				CombatService.preparePlayersForRound()
				broadcastCombatStateToAll()
			end)
		elseif state == "Ended" or state == "Intermission" then
			CombatService.cleanupRound()
			broadcastCombatStateToAll()
		end
	end)

	print("[newmm] CombatService initialized.")
end

return CombatService
