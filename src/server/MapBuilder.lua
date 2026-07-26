--!strict
--[[
	MapBuilder
	Procedurally builds the test facility map on server start.
	No manual Studio building required — syncs through Rojo.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local MapBuilder = {}

local WALL_HEIGHT = 14
local WALL_THICKNESS = 1

type GapSide = "North" | "South" | "East" | "West"

local COLORS = {
	Floor = Color3.fromRGB(35, 35, 40),
	Wall = Color3.fromRGB(55, 55, 62),
	Ceiling = Color3.fromRGB(28, 28, 32),
	Spawn = Color3.fromRGB(60, 120, 200),
	FuelCell = Color3.fromRGB(255, 200, 50),
	Generator = Color3.fromRGB(45, 50, 55),
	Key = Color3.fromRGB(220, 180, 40),
	Door = Color3.fromRGB(90, 60, 35),
	Desk = Color3.fromRGB(65, 45, 30),
	Sign = Color3.fromRGB(200, 50, 50),
}

local function tag(instance: Instance, tagName: string)
	CollectionService:AddTag(instance, tagName)
end

local function createPart(props: {
	Name: string,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material?,
	Transparency: number?,
	Parent: Instance,
	Anchored: boolean?,
	CanCollide: boolean?,
}): Part
	local part = Instance.new("Part")
	part.Name = props.Name
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color
	part.Material = props.Material or Enum.Material.Concrete
	part.Transparency = props.Transparency or 0
	part.Anchored = if props.Anchored == nil then true else props.Anchored
	part.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = props.Parent
	return part
end

local function createWallSegment(parent: Instance, name: string, size: Vector3, position: Vector3)
	createPart({
		Name = name,
		Size = size,
		CFrame = CFrame.new(position),
		Color = COLORS.Wall,
		Material = Enum.Material.Brick,
		Parent = parent,
	})
end

local function createWallWithGap(
	parent: Instance,
	name: string,
	axis: "X" | "Z",
	center: Vector3,
	length: number,
	gapCenter: number,
	gapWidth: number
)
	local segmentLength = (length - gapWidth) / 2
	if segmentLength <= 0 then
		return
	end

	if axis == "X" then
		local z = center.Z
		local y = center.Y
		createWallSegment(
			parent,
			name .. "A",
			Vector3.new(segmentLength, WALL_HEIGHT, WALL_THICKNESS),
			Vector3.new(center.X - gapWidth / 2 - segmentLength / 2, y, z)
		)
		createWallSegment(
			parent,
			name .. "B",
			Vector3.new(segmentLength, WALL_HEIGHT, WALL_THICKNESS),
			Vector3.new(center.X + gapWidth / 2 + segmentLength / 2, y, z)
		)
	else
		local x = center.X
		local y = center.Y
		createWallSegment(
			parent,
			name .. "A",
			Vector3.new(WALL_THICKNESS, WALL_HEIGHT, segmentLength),
			Vector3.new(x, y, center.Z - gapWidth / 2 - segmentLength / 2)
		)
		createWallSegment(
			parent,
			name .. "B",
			Vector3.new(WALL_THICKNESS, WALL_HEIGHT, segmentLength),
			Vector3.new(x, y, center.Z + gapWidth / 2 + segmentLength / 2)
		)
	end
end

local function createRoom(
	parent: Instance,
	name: string,
	center: Vector3,
	size: Vector3,
	gaps: { [GapSide]: number? }?
): Folder
	local room = Instance.new("Folder")
	room.Name = name
	room.Parent = parent

	local floorY = center.Y - WALL_HEIGHT / 2
	local halfX = size.X / 2
	local halfZ = size.Z / 2
	local wallY = floorY + WALL_HEIGHT / 2

	createPart({
		Name = "Floor",
		Size = Vector3.new(size.X, 1, size.Z),
		CFrame = CFrame.new(center.X, floorY, center.Z),
		Color = COLORS.Floor,
		Material = Enum.Material.Slate,
		Parent = room,
	})

	createPart({
		Name = "Ceiling",
		Size = Vector3.new(size.X, 1, size.Z),
		CFrame = CFrame.new(center.X, floorY + WALL_HEIGHT + 0.5, center.Z),
		Color = COLORS.Ceiling,
		Material = Enum.Material.SmoothPlastic,
		Parent = room,
	})

	local gapNorth = gaps and gaps.North
	local gapSouth = gaps and gaps.South
	local gapWest = gaps and gaps.West
	local gapEast = gaps and gaps.East

	if gapNorth then
		createWallWithGap(room, "NorthWall", "X", Vector3.new(center.X, wallY, center.Z - halfZ), size.X, center.X, gapNorth)
	else
		createWallSegment(room, "NorthWall", Vector3.new(size.X, WALL_HEIGHT, WALL_THICKNESS), Vector3.new(center.X, wallY, center.Z - halfZ))
	end

	if gapSouth then
		createWallWithGap(room, "SouthWall", "X", Vector3.new(center.X, wallY, center.Z + halfZ), size.X, center.X, gapSouth)
	else
		createWallSegment(room, "SouthWall", Vector3.new(size.X, WALL_HEIGHT, WALL_THICKNESS), Vector3.new(center.X, wallY, center.Z + halfZ))
	end

	if gapWest then
		createWallWithGap(room, "WestWall", "Z", Vector3.new(center.X - halfX, wallY, center.Z), size.Z, center.Z, gapWest)
	else
		createWallSegment(room, "WestWall", Vector3.new(WALL_THICKNESS, WALL_HEIGHT, size.Z), Vector3.new(center.X - halfX, wallY, center.Z))
	end

	if gapEast then
		createWallWithGap(room, "EastWall", "Z", Vector3.new(center.X + halfX, wallY, center.Z), size.Z, center.Z, gapEast)
	else
		createWallSegment(room, "EastWall", Vector3.new(WALL_THICKNESS, WALL_HEIGHT, size.Z), Vector3.new(center.X + halfX, wallY, center.Z))
	end

	return room
end

local function createDoorway(parent: Instance, name: string, cframe: CFrame, size: Vector3)
	local frame = Instance.new("Model")
	frame.Name = name
	frame.Parent = parent

	local door = createPart({
		Name = "DoorPanel",
		Size = size,
		CFrame = cframe,
		Color = COLORS.Door,
		Material = Enum.Material.Wood,
		Parent = frame,
	})
	door:SetAttribute("Locked", true)
	door:SetAttribute("RequiresPower", true)
	door:SetAttribute("RequiresKey", true)
	tag(door, "Door")

	return frame
end

local function createLabel(parent: Instance, text: string, offset: Vector3)
	local anchor = createPart({
		Name = text .. "Sign",
		Size = Vector3.new(6, 2.5, 0.2),
		CFrame = CFrame.new(offset),
		Color = COLORS.Sign,
		Material = Enum.Material.Neon,
		Parent = parent,
		CanCollide = false,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
end

local function createSpawn(parent: Instance, position: Vector3, index: number)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = `Spawn{index}`
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(position)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = COLORS.Spawn
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.4
	spawn.Parent = parent
	tag(spawn, "Spawn")
end

local function createFuelCell(parent: Instance, name: string, position: Vector3)
	local cell = createPart({
		Name = name,
		Size = Vector3.new(2.5, 3, 2.5),
		CFrame = CFrame.new(position),
		Color = COLORS.FuelCell,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	cell:SetAttribute("Collected", false)
	tag(cell, "FuelCell")

	local light = Instance.new("PointLight")
	light.Color = COLORS.FuelCell
	light.Brightness = 2
	light.Range = 12
	light.Parent = cell

	return cell
end

local function createGenerator(parent: Instance, position: Vector3)
	local generator = createPart({
		Name = "Generator",
		Size = Vector3.new(6, 5, 4),
		CFrame = CFrame.new(position),
		Color = COLORS.Generator,
		Material = Enum.Material.DiamondPlate,
		Parent = parent,
	})
	generator:SetAttribute("PowerOn", false)
	generator:SetAttribute("CellsDeposited", 0)
	tag(generator, "Generator")

	local light = Instance.new("PointLight")
	light.Name = "PowerLight"
	light.Color = Color3.fromRGB(80, 255, 120)
	light.Brightness = 0
	light.Range = 20
	light.Parent = generator

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GeneratorPrompt"
	prompt.ActionText = "Boot Generator"
	prompt.ObjectText = "Generator"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Enabled = false
	prompt.Parent = generator

	return generator
end

local function createKey(parent: Instance, position: Vector3)
	createPart({
		Name = "Desk",
		Size = Vector3.new(5, 3, 3),
		CFrame = CFrame.new(position + Vector3.new(0, -1.5, 0)),
		Color = COLORS.Desk,
		Material = Enum.Material.Wood,
		Parent = parent,
	})

	local key = createPart({
		Name = "Key",
		Size = Vector3.new(1.2, 0.4, 2),
		CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)),
		Color = COLORS.Key,
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	key:SetAttribute("Collected", false)
	tag(key, "Key")

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take Key"
	prompt.ObjectText = "Office Key"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.Parent = key

	return key
end

local function createLight(parent: Instance, position: Vector3)
	local fixture = createPart({
		Name = "LightFixture",
		Size = Vector3.new(2, 0.5, 2),
		CFrame = CFrame.new(position),
		Color = Color3.fromRGB(255, 240, 200),
		Material = Enum.Material.Neon,
		Parent = parent,
		CanCollide = false,
	})

	local light = Instance.new("PointLight")
	light.Brightness = 1.5
	light.Range = 30
	light.Parent = fixture
end

local function clearExistingMap(mapFolder: Folder)
	for _, child in mapFolder:GetChildren() do
		child:Destroy()
	end
end

function MapBuilder.build()
	local workspaceMap = workspace:WaitForChild("Map") :: Folder
	clearExistingMap(workspaceMap)

	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Transparency = 1
		baseplate.CanCollide = false
	end

	Lighting.ClockTime = 0
	Lighting.Brightness = 1.2
	Lighting.Ambient = Color3.fromRGB(30, 30, 40)
	Lighting.OutdoorAmbient = Color3.fromRGB(20, 20, 30)

	local rooms = Instance.new("Folder")
	rooms.Name = "Rooms"
	rooms.Parent = workspaceMap

	local objectives = Instance.new("Folder")
	objectives.Name = "Objectives"
	objectives.Parent = workspaceMap

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = workspaceMap

	local doors = Instance.new("Folder")
	doors.Name = "Doors"
	doors.Parent = workspaceMap

	local roomY = WALL_HEIGHT / 2

	-- Lobby (south) opens north into hallway
	createRoom(rooms, "Lobby", Vector3.new(0, roomY, -50), Vector3.new(50, WALL_HEIGHT, 36), { North = 10 })
	-- Main hallway runs north-south
	createRoom(rooms, "Hallway", Vector3.new(0, roomY, 10), Vector3.new(12, WALL_HEIGHT, 70), { South = 10 })
	-- Side rooms open toward hallway
	createRoom(rooms, "Office", Vector3.new(-28, roomY, 0), Vector3.new(22, WALL_HEIGHT, 22), { East = 8 })
	createRoom(rooms, "Storage", Vector3.new(-28, roomY, 35), Vector3.new(22, WALL_HEIGHT, 22), { East = 8 })
	createRoom(rooms, "Cafeteria", Vector3.new(28, roomY, 5), Vector3.new(24, WALL_HEIGHT, 28), { West = 8 })
	createRoom(rooms, "GeneratorRoom", Vector3.new(-28, roomY, 68), Vector3.new(22, WALL_HEIGHT, 22), { East = 8 })
	createRoom(rooms, "BackHall", Vector3.new(0, roomY, 62), Vector3.new(12, WALL_HEIGHT, 30), { South = 10 })

	-- Spawns
	local spawnY = 1
	createSpawn(spawns, Vector3.new(-10, spawnY, -55), 1)
	createSpawn(spawns, Vector3.new(10, spawnY, -55), 2)
	createSpawn(spawns, Vector3.new(-10, spawnY, -45), 3)
	createSpawn(spawns, Vector3.new(10, spawnY, -45), 4)
	createSpawn(spawns, Vector3.new(0, spawnY, -50), 5)
	createSpawn(spawns, Vector3.new(-5, spawnY, -52), 6)
	createSpawn(spawns, Vector3.new(5, spawnY, -48), 7)
	createSpawn(spawns, Vector3.new(0, spawnY, -58), 8)

	-- Objectives (spread across map for Phase 3)
	createFuelCell(objectives, "FuelCell1", Vector3.new(-28, 2, 38)) -- Storage
	createFuelCell(objectives, "FuelCell2", Vector3.new(28, 2, 8)) -- Cafeteria
	createFuelCell(objectives, "FuelCell3", Vector3.new(0, 2, 72)) -- Back hall
	createKey(objectives, Vector3.new(-28, 5, 0)) -- Office desk
	createGenerator(objectives, Vector3.new(-28, 3.5, 68)) -- Generator room

	-- Locked door blocking back hall
	createDoorway(doors, "MainDoor", CFrame.new(0, 5, 48), Vector3.new(10, 10, 1))

	-- Signs
	createLabel(rooms, "LOBBY", Vector3.new(0, 8, -66))
	createLabel(rooms, "OFFICE", Vector3.new(-38, 8, 0))
	createLabel(rooms, "STORAGE", Vector3.new(-38, 8, 35))
	createLabel(rooms, "CAFETERIA", Vector3.new(38, 8, 5))
	createLabel(rooms, "GENERATOR", Vector3.new(-38, 8, 68))
	createLabel(rooms, "BACK HALL", Vector3.new(0, 8, 78))

	-- Lights
	for _, pos in {
		Vector3.new(0, 12, -50),
		Vector3.new(0, 12, 10),
		Vector3.new(-28, 12, 0),
		Vector3.new(-28, 12, 35),
		Vector3.new(28, 12, 5),
		Vector3.new(-28, 12, 68),
		Vector3.new(0, 12, 62),
	} do
		createLight(rooms, pos)
	end

	print("[newmm] MapBuilder — facility map generated.")
	return workspaceMap
end

return MapBuilder
