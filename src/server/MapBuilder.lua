--!strict
--[[
	MapBuilder
	Builds a fully connected facility with one continuous floor and
	explicit wall segments (with real door openings between every room).
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local MapBuilder = {}

local WALL_HEIGHT = 14
local WALL_THICKNESS = 1
local FLOOR_TOP = 0

local COLORS = {
	Floor = Color3.fromRGB(38, 38, 44),
	Wall = Color3.fromRGB(58, 58, 66),
	Ceiling = Color3.fromRGB(26, 26, 30),
	Spawn = Color3.fromRGB(60, 120, 200),
	FuelCell = Color3.fromRGB(255, 200, 50),
	Generator = Color3.fromRGB(45, 50, 55),
	Key = Color3.fromRGB(220, 180, 40),
	Door = Color3.fromRGB(90, 60, 35),
	Desk = Color3.fromRGB(65, 45, 30),
	Sign = Color3.fromRGB(200, 50, 50),
}

-- World-space layout bounds (X = east/west, Z = north/south)
local MAP = {
	MinX = -44,
	MaxX = 44,
	MinZ = -70,
	MaxZ = 84,

	HallMinX = -7,
	HallMaxX = 7,

	LobbyMinX = -26,
	LobbyMaxX = 26,
	LobbyMinZ = -66,
	LobbyMaxZ = -30,

	HallMinZ = -30,
	HallMaxZ = 76,

	WestRoomMaxX = -9,
	OfficeMinZ = -14,
	OfficeMaxZ = 14,
	StorageMinZ = 18,
	StorageMaxZ = 44,
	GeneratorMinZ = 50,
	GeneratorMaxZ = 76,

	CafeteriaMinX = 9,
	CafeteriaMaxX = 42,
	CafeteriaMinZ = -10,
	CafeteriaMaxZ = 34,
}

local function tag(instance: Instance, tagName: string)
	CollectionService:AddTag(instance, tagName)
end

local function wallCenterY(): number
	return FLOOR_TOP + WALL_HEIGHT / 2
end

local function createPart(props: {
	Name: string,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material?,
	Parent: Instance,
	CanCollide: boolean?,
}): Part
	local part = Instance.new("Part")
	part.Name = props.Name
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color
	part.Material = props.Material or Enum.Material.Concrete
	part.Anchored = true
	part.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = props.Parent
	return part
end

local function fillFloor(parent: Instance, minX: number, maxX: number, minZ: number, maxZ: number)
	createPart({
		Name = "Floor",
		Size = Vector3.new(maxX - minX, 1, maxZ - minZ),
		CFrame = CFrame.new((minX + maxX) / 2, FLOOR_TOP - 0.5, (minZ + maxZ) / 2),
		Color = COLORS.Floor,
		Material = Enum.Material.Slate,
		Parent = parent,
	})
end

local function fillCeiling(parent: Instance, minX: number, maxX: number, minZ: number, maxZ: number)
	createPart({
		Name = "Ceiling",
		Size = Vector3.new(maxX - minX, 1, maxZ - minZ),
		CFrame = CFrame.new((minX + maxX) / 2, FLOOR_TOP + WALL_HEIGHT + 0.5, (minZ + maxZ) / 2),
		Color = COLORS.Ceiling,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

-- Wall running east-west (constant Z)
local function wallX(parent: Instance, name: string, z: number, minX: number, maxX: number)
	if maxX <= minX then
		return
	end
	createPart({
		Name = name,
		Size = Vector3.new(maxX - minX, WALL_HEIGHT, WALL_THICKNESS),
		CFrame = CFrame.new((minX + maxX) / 2, wallCenterY(), z),
		Color = COLORS.Wall,
		Material = Enum.Material.Brick,
		Parent = parent,
	})
end

local function wallXWithGap(
	parent: Instance,
	name: string,
	z: number,
	minX: number,
	maxX: number,
	gapMinX: number,
	gapMaxX: number
)
	wallX(parent, name .. "Left", z, minX, gapMinX)
	wallX(parent, name .. "Right", z, gapMaxX, maxX)
end

-- Wall running north-south (constant X)
local function wallZ(parent: Instance, name: string, x: number, minZ: number, maxZ: number)
	if maxZ <= minZ then
		return
	end
	createPart({
		Name = name,
		Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, maxZ - minZ),
		CFrame = CFrame.new(x, wallCenterY(), (minZ + maxZ) / 2),
		Color = COLORS.Wall,
		Material = Enum.Material.Brick,
		Parent = parent,
	})
end

local function wallZWithGap(
	parent: Instance,
	name: string,
	x: number,
	minZ: number,
	maxZ: number,
	gapMinZ: number,
	gapMaxZ: number
)
	wallZ(parent, name .. "South", x, minZ, gapMinZ)
	wallZ(parent, name .. "North", x, gapMaxZ, maxZ)
end

local function createDoor(parent: Instance, name: string, center: Vector3, size: Vector3)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	local door = createPart({
		Name = "DoorPanel",
		Size = size,
		CFrame = CFrame.new(center),
		Color = COLORS.Door,
		Material = Enum.Material.Wood,
		Parent = model,
	})
	door:SetAttribute("Locked", true)
	door:SetAttribute("RequiresPower", true)
	door:SetAttribute("RequiresKey", true)
	tag(door, "Door")
end

local function createSign(parent: Instance, text: string, position: Vector3)
	local sign = createPart({
		Name = `{text}Sign`,
		Size = Vector3.new(8, 3, 0.3),
		CFrame = CFrame.new(position),
		Color = COLORS.Sign,
		Material = Enum.Material.Neon,
		Parent = parent,
		CanCollide = false,
	})

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
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
	spawn.Transparency = 0.35
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
	light.Range = 14
	light.Parent = cell
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
	light.Range = 22
	light.Parent = generator
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
end

local function createLight(parent: Instance, position: Vector3)
	local fixture = createPart({
		Name = "Light",
		Size = Vector3.new(2, 0.4, 2),
		CFrame = CFrame.new(position),
		Color = Color3.fromRGB(255, 240, 200),
		Material = Enum.Material.Neon,
		Parent = parent,
		CanCollide = false,
	})

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 32
	light.Parent = fixture
end

local function buildHallwayWalls(parent: Instance)
	-- West hallway wall (x = -7) with 3 doorways into west rooms
	wallZ(parent, "HallWest1", MAP.HallMinX, MAP.HallMinZ, -4)
	wallZ(parent, "HallWest2", MAP.HallMinX, 4, 22)
	wallZ(parent, "HallWest3", MAP.HallMinX, 30, 56)
	wallZ(parent, "HallWest4", MAP.HallMinX, 64, MAP.HallMaxZ)

	-- East hallway wall (x = 7) with 1 doorway into cafeteria
	wallZ(parent, "HallEast1", MAP.HallMaxX, MAP.HallMinZ, 6)
	wallZ(parent, "HallEast2", MAP.HallMaxX, 18, MAP.HallMaxZ)
end

local function buildStructure(parent: Instance)
	-- One continuous floor for the whole building
	fillFloor(parent, MAP.MinX, MAP.MaxX, MAP.MinZ, MAP.MaxZ)
	fillCeiling(parent, MAP.MinX, MAP.MaxX, MAP.MinZ, MAP.MaxZ)

	-- Outer walls
	wallX(parent, "OuterSouth", MAP.MinZ, MAP.MinX, MAP.MaxX)
	wallX(parent, "OuterNorth", MAP.MaxZ, MAP.MinX, MAP.MaxX)
	wallZ(parent, "OuterWest", MAP.MinX, MAP.MinZ, MAP.MaxZ)
	wallZ(parent, "OuterEast", MAP.MaxX, MAP.MinZ, MAP.MaxZ)

	-- Lobby north wall — doorway into hallway (8 studs wide, centered)
	wallXWithGap(parent, "LobbyNorth", MAP.LobbyMaxZ, MAP.LobbyMinX, MAP.LobbyMaxX, -4, 4)

	buildHallwayWalls(parent)

	-- Locked door divider between front hallway and back hall
	wallXWithGap(parent, "HallDivider", 50, MAP.HallMinX, MAP.HallMaxX, -4, 4)

	-- West side rooms — outer walls
	wallZ(parent, "OfficeWest", MAP.MinX + 1, MAP.OfficeMinZ, MAP.OfficeMaxZ)
	wallX(parent, "OfficeSouth", MAP.OfficeMinZ, MAP.MinX, MAP.WestRoomMaxX)
	wallX(parent, "OfficeNorth", MAP.OfficeMaxZ, MAP.MinX, MAP.WestRoomMaxX)

	wallZ(parent, "StorageWest", MAP.MinX + 1, MAP.StorageMinZ, MAP.StorageMaxZ)
	wallX(parent, "StorageSouth", MAP.StorageMinZ, MAP.MinX, MAP.WestRoomMaxX)
	wallX(parent, "StorageNorth", MAP.StorageMaxZ, MAP.MinX, MAP.WestRoomMaxX)

	wallZ(parent, "GeneratorWest", MAP.MinX + 1, MAP.GeneratorMinZ, MAP.GeneratorMaxZ)
	wallX(parent, "GeneratorSouth", MAP.GeneratorMinZ, MAP.MinX, MAP.WestRoomMaxX)
	wallX(parent, "GeneratorNorth", MAP.GeneratorMaxZ, MAP.MinX, MAP.WestRoomMaxX)

	-- West room east walls — segments between hallway doorways
	wallZ(parent, "OfficeEastTop", MAP.WestRoomMaxX, MAP.OfficeMinZ, -4)
	wallZ(parent, "OfficeEastBottom", MAP.WestRoomMaxX, 4, MAP.OfficeMaxZ)

	wallZ(parent, "StorageEastTop", MAP.WestRoomMaxX, MAP.StorageMinZ, 22)
	wallZ(parent, "StorageEastBottom", MAP.WestRoomMaxX, 30, MAP.StorageMaxZ)

	wallZ(parent, "GeneratorEastTop", MAP.WestRoomMaxX, MAP.GeneratorMinZ, 56)
	wallZ(parent, "GeneratorEastBottom", MAP.WestRoomMaxX, 64, MAP.GeneratorMaxZ)

	-- Cafeteria walls
	wallZ(parent, "CafeteriaEast", MAP.CafeteriaMaxX, MAP.CafeteriaMinZ, MAP.CafeteriaMaxZ)
	wallX(parent, "CafeteriaSouth", MAP.CafeteriaMinZ, MAP.CafeteriaMinX, MAP.CafeteriaMaxX)
	wallX(parent, "CafeteriaNorth", MAP.CafeteriaMaxZ, MAP.CafeteriaMinX, MAP.CafeteriaMaxX)
	wallZ(parent, "CafeteriaWestTop", MAP.CafeteriaMinX, MAP.CafeteriaMinZ, 6)
	wallZ(parent, "CafeteriaWestBottom", MAP.CafeteriaMinX, 18, MAP.CafeteriaMaxZ)

	-- Back hall end cap (north end of hallway)
	wallX(parent, "BackHallNorth", MAP.MaxZ - 1, MAP.HallMinX, MAP.HallMaxX)
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
	Lighting.Brightness = 1.3
	Lighting.Ambient = Color3.fromRGB(35, 35, 45)
	Lighting.OutdoorAmbient = Color3.fromRGB(20, 20, 28)

	local structure = Instance.new("Folder")
	structure.Name = "Structure"
	structure.Parent = workspaceMap

	local objectives = Instance.new("Folder")
	objectives.Name = "Objectives"
	objectives.Parent = workspaceMap

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = workspaceMap

	local doors = Instance.new("Folder")
	doors.Name = "Doors"
	doors.Parent = workspaceMap

	local labels = Instance.new("Folder")
	labels.Name = "Labels"
	labels.Parent = workspaceMap

	buildStructure(structure)

	-- Spawns in lobby
	createSpawn(spawns, Vector3.new(-12, 1, -52), 1)
	createSpawn(spawns, Vector3.new(12, 1, -52), 2)
	createSpawn(spawns, Vector3.new(-12, 1, -42), 3)
	createSpawn(spawns, Vector3.new(12, 1, -42), 4)
	createSpawn(spawns, Vector3.new(0, 1, -48), 5)
	createSpawn(spawns, Vector3.new(-6, 1, -56), 6)
	createSpawn(spawns, Vector3.new(6, 1, -44), 7)
	createSpawn(spawns, Vector3.new(0, 1, -58), 8)

	-- Objectives inside their rooms
	createFuelCell(objectives, "FuelCell1", Vector3.new(-24, 2, 31)) -- Storage
	createFuelCell(objectives, "FuelCell2", Vector3.new(24, 2, 12)) -- Cafeteria
	createFuelCell(objectives, "FuelCell3", Vector3.new(0, 2, 68)) -- Back hall
	createKey(objectives, Vector3.new(-24, 5, 0)) -- Office
	createGenerator(objectives, Vector3.new(-24, 3.5, 63)) -- Generator room

	-- Locked door in hallway (blocks path to back hall — walk around isn't possible, must open)
	createDoor(doors, "MainDoor", Vector3.new(0, 5, 50), Vector3.new(14, 10, 1))

	-- Room labels
	createSign(labels, "LOBBY", Vector3.new(0, 10, -50))
	createSign(labels, "HALLWAY", Vector3.new(0, 10, 10))
	createSign(labels, "OFFICE", Vector3.new(-24, 10, 0))
	createSign(labels, "STORAGE", Vector3.new(-24, 10, 31))
	createSign(labels, "CAFETERIA", Vector3.new(24, 10, 12))
	createSign(labels, "GENERATOR", Vector3.new(-24, 10, 63))
	createSign(labels, "BACK HALL", Vector3.new(0, 10, 68))

	-- Lights in each area
	createLight(structure, Vector3.new(0, 13, -48))
	createLight(structure, Vector3.new(0, 13, 10))
	createLight(structure, Vector3.new(-24, 13, 0))
	createLight(structure, Vector3.new(-24, 13, 31))
	createLight(structure, Vector3.new(24, 13, 12))
	createLight(structure, Vector3.new(-24, 13, 63))
	createLight(structure, Vector3.new(0, 13, 68))

	print("[newmm] MapBuilder — connected facility map generated.")
	return workspaceMap
end

return MapBuilder
