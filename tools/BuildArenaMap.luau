--!nolint
--[[
	BuildArenaMap — la recette de l'arene de duel, a coller dans la barre de
	commande de Studio.

	POURQUOI CE FICHIER EXISTE
	Les maps vivent dans Workspace, que Rojo ne touche pas, et le fichier .rbxl
	n'est pas dans Git. Une map construite a la main n'existe donc que dans la
	place : une fausse manoeuvre et elle est perdue sans trace. Ce script est
	la sauvegarde. Il reconstruit l'arene a l'identique, et il commence par
	detruire la precedente, donc on peut le relancer autant qu'on veut.

	CE N'EST PAS DU CODE DE JEU. Il n'est pas synchronise par Rojo (il vit dans
	tools/, hors du projet Rojo), il ne tourne jamais en partie, et il n'est
	pas verifie par Selene ni StyLua.

	COMMENT S'EN SERVIR
	Dans Studio : View -> Command Bar, coller tout le contenu, Entree.

	CE QU'IL CONSTRUIT
	Une arene circulaire de 95 studs de rayon, a symetrie de rotation de 180
	degres : les deux equipes ont exactement le meme terrain. Sur un duel,
	toute asymetrie devient un desequilibre.

	    - un sol en ardoise sombre, borde d'un anneau lumineux
	    - une plateforme centrale cerclee, la ou la zone finit de se refermer
	    - quatre piliers hauts a mi-distance, qui coupent les longues lignes de
	      vue : c'est ce dont le Vampire a besoin pour revenir au contact apres
	      un repoussement du Colosse
	    - quatre murs bas de 3 studs pres du centre. Bas exprès : le dernier
	      cercle de la zone fait 16 studs de rayon, et une couverture haute a
	      cet endroit rendrait la fin de manche aveugle
	    - huit blocs devant les departs, pour ne pas commencer a decouvert
	    - les cinq noms du contrat : SpawnsA, SpawnsB, ZoneCenter, Cover,
	      MapBounds

	MapBounds fait 180 studs de large, donc la zone demarre a un rayon de 90 —
	juste a l'interieur du sol. Changer cette taille change la zone, et rien
	d'autre n'est a toucher.
]]

local Workspace = game:GetService("Workspace")

local FLOOR_RADIUS = 95
local BOUNDS_WIDTH = 180
local SPAWN_DISTANCE = 70
local SPAWN_SPACING = 9
local SPAWN_HEIGHT = 4

local COLOR_FLOOR = Color3.fromRGB(58, 63, 74)
local COLOR_RING = Color3.fromRGB(120, 170, 220)
local COLOR_CENTER = Color3.fromRGB(86, 94, 108)
local COLOR_COVER = Color3.fromRGB(96, 102, 114)
local COLOR_A = Color3.fromRGB(80, 140, 220)
local COLOR_B = Color3.fromRGB(220, 90, 80)

local existing = Workspace:FindFirstChild("ArenaMap")
if existing then
	existing:Destroy()
end

local map = Instance.new("Folder")
map.Name = "ArenaMap"

local function part(name, parent, size, cf)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Un cylindre Roblox est couche sur l'axe X : Size.X est sa hauteur, et il
-- faut le redresser d'un quart de tour.
local function disc(name, parent, radius, height, y)
	local p = part(
		name,
		parent,
		Vector3.new(height, radius * 2, radius * 2),
		CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90))
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Un cylindre plein n'est pas un anneau : il recouvre tout le disque. Un vrai
-- anneau se fabrique en segments tangents.
local function ring(name, radius, segments, height, y, thickness)
	local folder = Instance.new("Folder")
	folder.Name = name

	local width = ((2 * math.pi * radius) / segments) * 1.08
	for index = 1, segments do
		local angle = (index - 1) * ((2 * math.pi) / segments)
		local segment = part(
			string.format("Segment%d", index),
			folder,
			Vector3.new(width, height, thickness),
			CFrame.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
				* CFrame.Angles(0, -angle + (math.pi / 2), 0)
		)
		segment.CanCollide = false
		segment.CanQuery = false
		segment.CastShadow = false
		segment.Color = COLOR_RING
		segment.Material = Enum.Material.Neon
	end

	folder.Parent = map
end

-- LE SOL
local floor = disc("Floor", map, FLOOR_RADIUS, 2, 0)
floor.Color = COLOR_FLOOR
floor.Material = Enum.Material.Slate

ring("Rim", FLOOR_RADIUS + 0.5, 84, 0.8, 1.4, 1.6)

-- LE CENTRE
local centerPad = disc("CenterPad", map, 20, 1.4, 1.2)
centerPad.Color = COLOR_CENTER
centerPad.Material = Enum.Material.Concrete

ring("CenterRing", 20.5, 40, 0.5, 2.0, 1.0)

local zoneCenter = part("ZoneCenter", map, Vector3.new(4, 1, 4), CFrame.new(0, SPAWN_HEIGHT, 0))
zoneCenter.Transparency = 1
zoneCenter.CanCollide = false
zoneCenter.CanQuery = false

-- LES COUVERTURES
local cover = Instance.new("Folder")
cover.Name = "Cover"
cover.Parent = map

local function placeAround(prefix, count, radius, size, offsetDegrees)
	for index = 1, count do
		local angle = math.rad(offsetDegrees + ((index - 1) * (360 / count)))
		local block = part(
			string.format("%s%d", prefix, index),
			cover,
			size,
			CFrame.new(math.cos(angle) * radius, 1 + (size.Y / 2), math.sin(angle) * radius)
				* CFrame.Angles(0, -angle, 0)
		)
		block.Color = COLOR_COVER
		block.Material = Enum.Material.Concrete
	end
end

placeAround("Pillar", 4, 46, Vector3.new(10, 16, 10), 45)
placeAround("LowWall", 4, 26, Vector3.new(16, 3, 3), 0)
placeAround("SpawnBlockA", 4, 58, Vector3.new(12, 7, 3), 22)
placeAround("SpawnBlockB", 4, 58, Vector3.new(12, 7, 3), 158)

-- LES DEPARTS
local function spawnFolder(name, side, color)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = map

	local first = -((5 - 1) * SPAWN_SPACING) / 2
	for index = 1, 5 do
		local z = first + ((index - 1) * SPAWN_SPACING)
		local x = side * SPAWN_DISTANCE

		-- Le marqueur est le point de depart : invisible, c'est une donnee.
		local marker = part(
			string.format("Spawn%d", index),
			folder,
			Vector3.new(2, 1, 2),
			CFrame.new(x, SPAWN_HEIGHT, z)
		)
		marker.Transparency = 1
		marker.CanCollide = false
		marker.CanQuery = false

		-- La dalle coloree est du decor : elle dit a qui est ce cote.
		local pad = part(
			string.format("%sPad%d", name, index),
			map,
			Vector3.new(0.4, 6, 6),
			CFrame.new(x, 1.2, z) * CFrame.Angles(0, 0, math.rad(90))
		)
		pad.Shape = Enum.PartType.Cylinder
		pad.Color = color
		pad.Material = Enum.Material.Neon
		pad.Transparency = 0.5
		pad.CanCollide = false
	end
end

spawnFolder("SpawnsA", -1, COLOR_A)
spawnFolder("SpawnsB", 1, COLOR_B)

-- LES LIMITES : invisible, c'est la mesure dont la zone deduit son rayon.
local bounds =
	part("MapBounds", map, Vector3.new(BOUNDS_WIDTH, 1, BOUNDS_WIDTH), CFrame.new(0, 0, 0))
bounds.Transparency = 1
bounds.CanCollide = false
bounds.CanQuery = false

map.Parent = Workspace

print(string.format("[Arena] ArenaMap reconstruite : %d objets", #map:GetDescendants()))
