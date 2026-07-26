--!strict
--[[
	Remotes
	Creates and returns all RemoteEvents / RemoteFunctions used by the game.
	Server requires this once at startup; clients wait for instances in ReplicatedStorage.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local function getOrCreateFolder(): Folder
	local shared = ReplicatedStorage:WaitForChild("Shared")
	local remotes = shared:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = shared
	end
	return remotes :: Folder
end

local function getOrCreateRemote(name: string, className: "RemoteEvent" | "RemoteFunction"): Instance
	local folder = getOrCreateFolder()
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end

	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = folder
	return remote
end

-- Called by server during init
function Remotes.init()
	getOrCreateRemote("RoundStateChanged", "RemoteEvent")
	getOrCreateRemote("RoleAssigned", "RemoteEvent")
	getOrCreateRemote("TimerUpdated", "RemoteEvent")
	getOrCreateRemote("RoundEnded", "RemoteEvent")

	-- Phase 2: combat
	getOrCreateRemote("Assassinate", "RemoteEvent")
	getOrCreateRemote("Shoot", "RemoteEvent")
	getOrCreateRemote("Arrest", "RemoteEvent")
	getOrCreateRemote("PlayerDied", "RemoteEvent")
	getOrCreateRemote("CombatStateUpdated", "RemoteEvent")
	getOrCreateRemote("PlayerStunned", "RemoteEvent")
end

function Remotes.get(name: string): RemoteEvent
	local folder = getOrCreateFolder()
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
