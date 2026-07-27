--!strict
--[[
	MapBuilder — open floor plan with tagged objectives for Phase 3.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local MapBuilder = {}

-- Bumped when layout changes — check Output or Workspace.Map.MapVersion on Play
local MAP_VERSION = "open-floor-v2"

local WALL_H = 14
local FLOOR_Y = 0

local COLORS = {
	Lobby = Color3.fromRGB(50, 50, 58),
	Hall = Color3.fromRGB(44, 44, 50),
	Office = Color3.fromRGB(55, 48, 42),
	Storage = Color3.fromRGB(48, 52, 55),
	Cafe = Color3.fromRGB(52, 50, 44),
	Generator = Color3.fromRGB(42, 46, 50),
	Back = Color3.fromRGB(38, 38, 44),
	Wall = Color3.fromRGB(60, 60, 68),
	Ceiling = Color3.fromRGB(25, 25, 28),
	Spawn = Color3.fromRGB(60, 120, 200),
	FuelCell = Color3.fromRGB(255, 200, 50),
	GeneratorObj = Color3.fromRGB(50, 55, 60),
	Key = Color3.fromRGB(220, 180, 40),
	Door = Color3.fromRGB(90, 60, 35),
	Desk = Color3.fromRGB(65, 45, 30),
	Escape = Color3.fromRGB(50, 200, 100),
}

local B = {
	MinX = -50,
	MaxX = 50,
	MinZ = -70,
	MaxZ = 80,
	DoorZ = 42,
}

local function tag(inst: Instance, name: string)
	CollectionService:AddTag(inst, name)
end

local function part(props: {
	Name: string,
	Size: Vector3,
	Pos: Vector3,
	Color: Color3,
	Parent: Instance,
	Material: Enum.Material?,
	CanCollide: boolean?,
}): Part
	local p = Instance.new("Part")
	p.Name = props.Name
	p.Size = props.Size
	p.CFrame = CFrame.new(props.Pos)
	p.Color = props.Color
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	p.Parent = props.Parent
	return p
end

local function zoneFloor(parent: Instance, name: string, minX: number, maxX: number, minZ: number, maxZ: number, color: Color3)
	part({
		Name = name,
		Size = Vector3.new(maxX - minX, 0.5, maxZ - minZ),
		Pos = Vector3.new((minX + maxX) / 2, FLOOR_Y, (minZ + maxZ) / 2),
		Color = color,
		Material = Enum.Material.Slate,
		Parent = parent,
	})
end

local function wallX(parent: Instance, z: number, minX: number, maxX: number)
	part({
		Name = "Wall",
		Size = Vector3.new(maxX - minX, WALL_H, 1),
		Pos = Vector3.new((minX + maxX) / 2, FLOOR_Y + WALL_H / 2, z),
		Color = COLORS.Wall,
		Material = Enum.Material.Brick,
		Parent = parent,
	})
end

local function wallZ(parent: Instance, x: number, minZ: number, maxZ: number)
	part({
		Name = "Wall",
		Size = Vector3.new(1, WALL_H, maxZ - minZ),
		Pos = Vector3.new(x, FLOOR_Y + WALL_H / 2, (minZ + maxZ) / 2),
		Color = COLORS.Wall,
		Material = Enum.Material.Brick,
		Parent = parent,
	})
end

local function wallXGap(parent: Instance, z: number, minX: number, maxX: number, gapMin: number, gapMax: number)
	if gapMin > minX then
		wallX(parent, z, minX, gapMin)
	end
	if gapMax < maxX then
		wallX(parent, z, gapMax, maxX)
	end
end

local function sign(parent: Instance, text: string, pos: Vector3)
	local s = part({
		Name = text,
		Size = Vector3.new(8, 2, 0.2),
		Pos = pos,
		Color = Color3.fromRGB(200, 50, 50),
		Material = Enum.Material.Neon,
		Parent = parent,
		CanCollide = false,
	})
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(160, 40)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.Parent = s
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.Parent = bb
end

local function spawn(parent: Instance, pos: Vector3, i: number)
	local s = Instance.new("SpawnLocation")
	s.Name = `Spawn{i}`
	s.Size = Vector3.new(6, 1, 6)
	s.CFrame = CFrame.new(pos)
	s.Anchored = true
	s.CanCollide = false
	s.Neutral = true
	s.Duration = 0
	s.Color = COLORS.Spawn
	s.Material = Enum.Material.Neon
	s.Transparency = 0.3
	s.Parent = parent
	tag(s, "Spawn")
end

local function fuelCell(parent: Instance, name: string, pos: Vector3)
	local c = part({
		Name = name,
		Size = Vector3.new(3, 3, 3),
		Pos = pos,
		Color = COLORS.FuelCell,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	c:SetAttribute("Collected", false)
	tag(c, "FuelCell")
	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 14
	light.Parent = c
end

local function generator(parent: Instance, pos: Vector3)
	local g = part({
		Name = "Generator",
		Size = Vector3.new(7, 5, 5),
		Pos = pos,
		Color = COLORS.GeneratorObj,
		Material = Enum.Material.DiamondPlate,
		Parent = parent,
	})
	g:SetAttribute("PowerOn", false)
	g:SetAttribute("CellsDeposited", 0)
	tag(g, "Generator")
	local light = Instance.new("PointLight")
	light.Name = "PowerLight"
	light.Brightness = 0
	light.Range = 22
	light.Parent = g
end

local function key(parent: Instance, pos: Vector3)
	part({
		Name = "Desk",
		Size = Vector3.new(5, 3, 3),
		Pos = pos + Vector3.new(0, -1.5, 0),
		Color = COLORS.Desk,
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	local k = part({
		Name = "Key",
		Size = Vector3.new(1.5, 0.5, 2),
		Pos = pos + Vector3.new(0, 0.5, 0),
		Color = COLORS.Key,
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	k:SetAttribute("Collected", false)
	tag(k, "Key")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "KeyPrompt"
	prompt.ActionText = "Take Key"
	prompt.ObjectText = "Office Key"
	prompt.MaxActivationDistance = 10
	prompt.Parent = k
end

local function door(parent: Instance, pos: Vector3)
	local d = part({
		Name = "DoorPanel",
		Size = Vector3.new(16, 11, 1),
		Pos = pos,
		Color = COLORS.Door,
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	d:SetAttribute("Locked", true)
	d:SetAttribute("RequiresPower", true)
	d:SetAttribute("RequiresKey", true)
	tag(d, "Door")
end

local function light(parent: Instance, pos: Vector3)
	local l = part({
		Name = "Light",
		Size = Vector3.new(2, 0.4, 2),
		Pos = pos,
		Color = Color3.fromRGB(255, 240, 200),
		Material = Enum.Material.Neon,
		Parent = parent,
		CanCollide = false,
	})
	tag(l, "MapLight")
	local pl = Instance.new("PointLight")
	pl.Brightness = 0
	pl.Enabled = false
	pl.Range = 40
	pl.Parent = l
end

local function escapeZone(parent: Instance, pos: Vector3)
	local z = part({
		Name = "EscapeZone",
		Size = Vector3.new(28, 0.6, 14),
		Pos = pos,
		Color = COLORS.Escape,
		Material = Enum.Material.Neon,
		Parent = parent,
		CanCollide = false,
	})
	z.Transparency = 0.35
	tag(z, "EscapeZone")
end

local function clearLegacyMapArtifacts()
	-- Old MapBuilder versions used a "Rooms" folder; remove if a previous session left it behind
	local legacyNames = { "Rooms", "Doors", "Facility", "MapStructure" }
	for _, name in legacyNames do
		local legacy = workspace:FindFirstChild(name)
		if legacy then
			legacy:Destroy()
			warn(`[newmm] Removed legacy workspace folder: {name}`)
		end
	end

	local map = workspace:FindFirstChild("Map")
	if map then
		for _, child in map:GetChildren() do
			child:Destroy()
		end
	end
end

function MapBuilder.build()
	clearLegacyMapArtifacts()

	local map = workspace:FindFirstChild("Map") :: Folder?
	if not map then
		map = Instance.new("Folder")
		map.Name = "Map"
		map.Parent = workspace
	end

	for _, c in map:GetChildren() do
		c:Destroy()
	end

	map:SetAttribute("MapVersion", MAP_VERSION)

	local base = workspace:FindFirstChild("Baseplate")
	if base and base:IsA("BasePart") then
		base.Transparency = 1
		base.CanCollide = false
	end

	Lighting.ClockTime = 0
	Lighting.Brightness = 1.1
	Lighting.Ambient = Color3.fromRGB(28, 28, 36)

	local structure = Instance.new("Folder")
	structure.Name = "Structure"
	structure.Parent = map

	local objectives = Instance.new("Folder")
	objectives.Name = "Objectives"
	objectives.Parent = map

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = map

	zoneFloor(structure, "LobbyFloor", B.MinX, B.MaxX, B.MinZ, -10, COLORS.Lobby)
	zoneFloor(structure, "MainFloor", B.MinX, B.MaxX, -10, B.DoorZ, COLORS.Hall)
	zoneFloor(structure, "BackFloor", B.MinX, B.MaxX, B.DoorZ, B.MaxZ, COLORS.Back)
	zoneFloor(structure, "OfficeZone", -48, -15, -5, 20, COLORS.Office)
	zoneFloor(structure, "StorageZone", -48, -15, 20, B.DoorZ, COLORS.Storage)
	zoneFloor(structure, "CafeZone", 15, 48, -5, 35, COLORS.Cafe)
	zoneFloor(structure, "GeneratorZone", -48, -15, 35, B.DoorZ, COLORS.Generator)

	part({
		Name = "Ceiling",
		Size = Vector3.new(B.MaxX - B.MinX, 1, B.MaxZ - B.MinZ),
		Pos = Vector3.new(0, FLOOR_Y + WALL_H + 0.5, (B.MinZ + B.MaxZ) / 2),
		Color = COLORS.Ceiling,
		Parent = structure,
	})

	wallX(structure, B.MinZ, B.MinX, B.MaxX)
	wallX(structure, B.MaxZ, B.MinX, B.MaxX)
	wallZ(structure, B.MinX, B.MinZ, B.MaxZ)
	wallZ(structure, B.MaxX, B.MinZ, B.MaxZ)
	wallXGap(structure, B.DoorZ, B.MinX, B.MaxX, -8, 8)

	spawn(spawns, Vector3.new(-15, 1, -55), 1)
	spawn(spawns, Vector3.new(15, 1, -55), 2)
	spawn(spawns, Vector3.new(-15, 1, -40), 3)
	spawn(spawns, Vector3.new(15, 1, -40), 4)
	spawn(spawns, Vector3.new(0, 1, -50), 5)
	spawn(spawns, Vector3.new(-8, 1, -60), 6)
	spawn(spawns, Vector3.new(8, 1, -45), 7)
	spawn(spawns, Vector3.new(0, 1, -35), 8)

	key(objectives, Vector3.new(-30, 5, 8))
	fuelCell(objectives, "FuelCell1", Vector3.new(-30, 2, 30))
	fuelCell(objectives, "FuelCell2", Vector3.new(30, 2, 15))
	generator(objectives, Vector3.new(-30, 3.5, 38))
	fuelCell(objectives, "FuelCell3", Vector3.new(0, 2, 60))
	door(objectives, Vector3.new(0, 6, B.DoorZ))
	escapeZone(objectives, Vector3.new(0, 1.5, 74))

	sign(structure, "LOBBY", Vector3.new(0, 8, -50))
	sign(structure, "OFFICE", Vector3.new(-30, 8, 8))
	sign(structure, "STORAGE", Vector3.new(-30, 8, 30))
	sign(structure, "CAFETERIA", Vector3.new(30, 8, 15))
	sign(structure, "GENERATOR", Vector3.new(-30, 8, 38))
	sign(structure, "BACK HALL", Vector3.new(0, 8, 60))
	sign(structure, "ESCAPE", Vector3.new(0, 8, 74))

	light(structure, Vector3.new(0, 13, -50))
	light(structure, Vector3.new(-30, 13, 8))
	light(structure, Vector3.new(-30, 13, 30))
	light(structure, Vector3.new(30, 13, 15))
	light(structure, Vector3.new(-30, 13, 38))
	light(structure, Vector3.new(0, 13, 20))
	light(structure, Vector3.new(0, 13, 60))

	print(`[newmm] MapBuilder {MAP_VERSION} — open floor plan ready (NO sealed rooms).`)
	return map
end

function MapBuilder.getVersion(): string
	return MAP_VERSION
end

return MapBuilder
