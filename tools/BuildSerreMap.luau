--!nolint
--[[
	BuildSerreMap — « La Serre ». A coller dans la barre de commande, ou a
	charger par le pont MCP (voir CLAUDE.md, « loadstring est verrouille »).

	POURQUOI CE FICHIER EXISTE
	Les maps vivent dans Workspace, que Rojo ne touche pas, et le .rbxl n'est
	pas dans Git. Ce script est la seule sauvegarde de la map. Il detruit toute
	autre map conforme avant de construire.

	CE N'EST PAS DU CODE DE JEU : hors du projet Rojo, jamais execute en partie.

	CE QU'ELLE RACONTE
	Un grand jardin d'hiver sous verre, un midi d'hiver au soleil bas : des palmiers, des massifs,
	des allees de pierre claire, une rotonde a fontaine au centre et une
	charpente de fer peinte en vert. Construite le 4 novembre 2026, sans Josh.

	CE QU'ELLE FAIT JOUER, et c'est une question qu'aucune des autres ne pose :
	ON VOIT TOUT, ON NE PASSE PAS.
	- Les cloisons sont de VERRE. On voit a travers, de part en part : on sait
	  toujours ou est l'adversaire. Mais le verre arrete un joueur ET un coup
	  — une attaque demande une ligne de vue depuis le 4 novembre 2026, et le
	  verre a de la collision.
	- Donc voir quelqu'un ne veut pas dire pouvoir l'atteindre. Le plan est un
	  labyrinthe rayonnant : une couronne de verre a quatre ouvertures, deux
	  cloisons qui coupent l'anneau interieur en deux, et une rotonde a quatre
	  portes. Le chemin le plus court vers quelqu'un qu'on voit a dix studs
	  peut en faire cinquante.
	- C'est la map de la LECTURE : on voit venir, on voit ou l'autre va
	  deboucher, et on s'y place. Le Cameleon y perd une partie de son interet,
	  le Traqueur aussi ; c'est le prix d'une map qui pose une autre question.

	Symetrie de ROTATION autour du centre ((x, z) -> (-x, -z)).
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local BOUNDS = 156
local HALF = 74
local SPAWN_X = 62
local SPAWN_Y = 4
local SPAWN_SPREAD = 4
local ROTUNDA = 18 -- rayon des cloisons de la rotonde
local RING = 44 -- rayon de la couronne de verre
local WALL_H = 10 -- hauteur des cloisons de verre

local STONE = Color3.fromRGB(206, 198, 182)
local STONE_DARK = Color3.fromRGB(150, 142, 128)
local IRON = Color3.fromRGB(44, 74, 60)
local GLASS = Color3.fromRGB(196, 226, 222)
local SOIL = Color3.fromRGB(78, 58, 42)
local LEAF = Color3.fromRGB(64, 120, 58)
local LEAF_DARK = Color3.fromRGB(40, 88, 46)
local LEAF_LIGHT = Color3.fromRGB(108, 156, 70)
local BARK = Color3.fromRGB(122, 98, 70)
local TERRACOTTA = Color3.fromRGB(176, 96, 64)
local WATER = Color3.fromRGB(60, 118, 120)
local BLOOM =
	{ Color3.fromRGB(214, 70, 82), Color3.fromRGB(240, 190, 70), Color3.fromRGB(236, 236, 226) }
local COLOR_A = Color3.fromRGB(70, 130, 230)
local COLOR_B = Color3.fromRGB(230, 80, 70)

for _, old in Workspace:GetChildren() do
	if old:FindFirstChild("SpawnsA") and old:FindFirstChild("SpawnsB") then
		old:Destroy()
	end
end
for _, name in { "Baseplate", "SpawnLocation" } do
	local old = Workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
do
	local folder = game:GetService("MaterialService"):FindFirstChild("ArenaMaterials")
	if folder then
		folder:Destroy()
	end
end

local map = Instance.new("Folder")
map.Name = "SerreMap"
local cover = Instance.new("Folder")
cover.Name = "Cover"
cover.Parent = map
local decor = Instance.new("Folder")
decor.Name = "Decor"
decor.Parent = map

local function part(name, parent, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function wedge(name, parent, size, cf, color, material)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.Grass
	p.Parent = parent
	return p
end

local function ghost(p)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function cylinder(name, parent, length, diameter, cf, color, material)
	local p = part(name, parent, Vector3.new(length, diameter, diameter), cf, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function rotated(s, cf)
	if s == 1 then
		return cf
	end
	return CFrame.Angles(0, math.pi, 0) * cf
end

local function twice(fn)
	fn(1)
	fn(-1)
end

--------------------------------------------------------------------------------
-- LE VERRE
--------------------------------------------------------------------------------

-- UNE VITRE : un pan de verre dans un cadre de fer, tenu en bas par un muret
-- de pierre. Le verre est le sujet de la map, donc il doit se LIRE comme du
-- verre et pas comme un mur invisible : le cadre, le muret et une legere
-- teinte font qu'on sait ou il est meme quand on regarde au travers.
--
-- LE GLASS DE ROBLOX REFLECHIT TOUT SEUL, et tres fort (piege du Sanctuaire).
-- Il est garde ici parce que c'est vraiment du verre, avec une transparence
-- haute pour que ce qu'on voit au travers l'emporte sur le reflet du ciel.
local function pane(name, a, b, height)
	local mid = (a + b) / 2
	local length = (b - a).Magnitude
	local cf = CFrame.lookAt(mid, b) -- longueur sur -Z
	local glass = part(
		name,
		cover,
		Vector3.new(0.3, height - 1.4, length),
		cf * CFrame.new(0, (height - 1.4) / 2 + 1.4, 0) - Vector3.new(0, mid.Y, 0),
		GLASS,
		Enum.Material.Glass
	)
	-- 0,62 au premier essai : le verre disparaissait, et seul le cadre disait
	-- qu'il y avait un mur. Un mur qu'on ne voit pas est un piege, pas une
	-- regle du jeu.
	glass.Transparency = 0.5
	glass.Reflectance = 0.05
	glass.CastShadow = false
	part(
		name .. "Muret",
		cover,
		Vector3.new(0.9, 1.4, length),
		cf * CFrame.new(0, 0.7, 0) - Vector3.new(0, mid.Y, 0),
		STONE_DARK,
		Enum.Material.Limestone
	)
	part(
		name .. "Lisse",
		decor,
		Vector3.new(0.5, 0.4, length),
		cf * CFrame.new(0, height, 0) - Vector3.new(0, mid.Y, 0),
		IRON,
		Enum.Material.Metal
	)
	-- Les montants : un a chaque bout et un tous les quatre studs.
	local n = math.max(1, math.floor(length / 4))
	for i = 0, n do
		local t = i / n
		local p = a:Lerp(b, t)
		-- Sans collision : le verre arrete deja tout, et des montants solides
		-- tous les quatre studs coupaient la vue qu'on voulait garder (la
		-- mesure du centre est tombee a zero sur dix a la premiere construction).
		ghost(
			part(
				name .. "Montant",
				decor,
				Vector3.new(0.4, height, 0.4),
				CFrame.new(p.X, height / 2, p.Z) * (cf - cf.Position),
				IRON,
				Enum.Material.Metal
			)
		)
	end
end

-- Un anneau de vitres en polygone de seize cotes, centres sur les multiples
-- de 22,5 degres. `skip` nomme les cotes laisses ouverts : ce sont les portes.
local function ring(name, radius, height, skip)
	for i = 0, 15 do
		if skip[i] then
			continue
		end
		local a0 = math.rad(i * 22.5 - 11.25)
		local a1 = math.rad(i * 22.5 + 11.25)
		pane(
			string.format("%s%d", name, i),
			Vector3.new(math.cos(a0) * radius, 0, math.sin(a0) * radius),
			Vector3.new(math.cos(a1) * radius, 0, math.sin(a1) * radius),
			height
		)
	end
	-- Une colonne de fonte a chaque angle, ouvert ou non : c'est elle qui
	-- dessine l'anneau quand on le regarde de loin.
	for i = 0, 15 do
		local a = math.rad(i * 22.5 + 11.25)
		cylinder(
			name .. "Colonne",
			cover,
			height + 1,
			1.1,
			CFrame.new(math.cos(a) * radius, (height + 1) / 2, math.sin(a) * radius)
				* CFrame.Angles(0, 0, math.pi / 2),
			IRON,
			Enum.Material.Metal
		)
	end
end

--------------------------------------------------------------------------------
-- LE SOL
--------------------------------------------------------------------------------

part(
	"Sol",
	decor,
	Vector3.new(BOUNDS, 2, BOUNDS),
	CFrame.new(0, -1, 0),
	STONE,
	Enum.Material.Limestone
)
-- Les massifs : de la terre et de l'herbe entre les allees, dans les quatre
-- coins de l'anneau exterieur et dans l'anneau interieur. Plus bas que les
-- allees de cinq centimetres : un massif se marche, il ne se contourne pas.
for _, c in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
	part(
		"Massif",
		decor,
		Vector3.new(36, 0.2, 36),
		CFrame.new(c[1] * 52, 0.02, c[2] * 52),
		LEAF_DARK,
		Enum.Material.LeafyGrass
	)
end
do
	local lawn = cylinder(
		"Pelouse",
		decor,
		0.16,
		2 * RING - 4,
		CFrame.new(0, 0.04, 0) * CFrame.Angles(0, 0, math.pi / 2),
		LEAF,
		Enum.Material.Grass
	)
	local path = cylinder(
		"Promenoir",
		decor,
		0.2,
		2 * ROTUNDA + 6,
		CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.pi / 2),
		STONE,
		Enum.Material.Limestone
	)
	local _ = lawn and path
end
-- Les allees de pierre qui menent des camps aux ouvertures : on lit le chemin
-- par terre, ce qui compte dans une map ou les murs se voient a peine.
twice(function(s)
	part(
		"AlleeCamp",
		decor,
		Vector3.new(26, 0.22, 6),
		rotated(s, CFrame.new(57, 0.1, 0)),
		STONE,
		Enum.Material.Limestone
	)
	part(
		"AlleeTour",
		decor,
		Vector3.new(6, 0.22, 60),
		rotated(s, CFrame.new(57, 0.1, 30)),
		STONE,
		Enum.Material.Limestone
	)
end)

--------------------------------------------------------------------------------
-- LES CLOISONS
--------------------------------------------------------------------------------

-- LA COURONNE. Seize vitres a quarante-quatre studs, quatre ouvertes : a 45 et
-- 225 degres (une pres de chaque camp, rendues l'une a l'autre par la
-- symetrie), et a 90 et 270 (les deux cotes, communes aux deux camps). Le
-- cote a 0 degre est fermé, et c'est lui qui coupe toute ligne droite d'un
-- camp a l'autre.
ring("Couronne", RING, WALL_H, { [2] = true, [4] = true, [10] = true, [12] = true })

-- LA ROTONDE. Seize vitres a dix-huit studs, quatre portes en diagonale. Le
-- dernier cercle de la zone fait seize de rayon : on s'y bat derriere du
-- verre qui laisse tout voir de dehors.
ring("Rotonde", ROTUNDA, WALL_H + 2, { [2] = true, [6] = true, [10] = true, [14] = true })

-- LES DEUX REFENDS, sur l'axe des camps, de la rotonde a la couronne. Ils
-- coupent l'anneau interieur en deux moities : entre par le nord, on ne
-- rejoint le sud qu'en passant par la rotonde.
twice(function(s)
	pane(
		"Refend" .. s,
		Vector3.new(s * (ROTUNDA + 0.6), 0, 0),
		Vector3.new(s * (RING - 0.6), 0, 0),
		WALL_H
	)
end)

-- LE POURTOUR : du verre aussi, sur un muret plus haut, avec une charpente.
for _, side in { 1, -1 } do
	pane("Pourtour", Vector3.new(-HALF, 0, side * HALF), Vector3.new(HALF, 0, side * HALF), 18)
	pane("Pourtour", Vector3.new(side * HALF, 0, -HALF), Vector3.new(side * HALF, 0, HALF), 18)
end

--------------------------------------------------------------------------------
-- LES PLANTES
--------------------------------------------------------------------------------

-- UN PALMIER. Un tronc en quatre troncons qui s'inclinent un peu plus a chaque
-- fois, et une couronne de palmes en coins tombants. Le tronc a de la
-- collision (c'est un couvert mince), les palmes non : on ne se cogne pas a
-- une feuille a huit metres de haut, et une palme ne doit pas arreter un coup.
local function palm(name, base, height, lean, turn)
	local cf = CFrame.new(base) * CFrame.Angles(0, turn, 0)
	local segment = height / 4
	local pos = cf
	for i = 1, 4 do
		local tilt = CFrame.Angles(math.rad(lean * i), 0, 0)
		pos = pos * tilt
		local piece = cylinder(
			name .. "Tronc" .. i,
			cover,
			segment + 0.3,
			1.5 - i * 0.18,
			pos * CFrame.new(0, segment / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			BARK,
			Enum.Material.Wood
		)
		piece.CastShadow = true
		pos = pos * CFrame.new(0, segment, 0) * tilt:Inverse()
	end
	local top = pos.Position
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		ghost(
			wedge(
				name .. "Palme",
				decor,
				Vector3.new(1.2, 0.6, 7),
				CFrame.new(top)
					* CFrame.Angles(0, a, 0)
					* CFrame.new(0, -0.6, -3.4)
					* CFrame.Angles(math.rad(-24 - (k % 2) * 10), 0, 0),
				if k % 2 == 0 then LEAF else LEAF_LIGHT,
				Enum.Material.Grass
			)
		)
	end
	ghost(
		part(
			name .. "Coeur",
			decor,
			Vector3.new(1.4, 1.4, 1.4),
			CFrame.new(top),
			LEAF_DARK,
			Enum.Material.Grass
		)
	).Shape =
		Enum.PartType.Ball
end

-- UN BAC A PLANTES : une caisse de pierre a hauteur de taille, de la terre,
-- et une touffe qui depasse a hauteur d'homme. C'est le couvert principal :
-- on tire par-dessus le bac, on se cache derriere la touffe.
local function planter(name, cf, w, d, tall, bloom)
	part(
		name,
		cover,
		Vector3.new(w, 3, d),
		cf * CFrame.new(0, 1.5, 0),
		STONE_DARK,
		Enum.Material.Limestone
	)
	part(
		name .. "Terre",
		decor,
		Vector3.new(w - 0.8, 0.2, d - 0.8),
		cf * CFrame.new(0, 3.05, 0),
		SOIL,
		Enum.Material.Ground
	)
	if tall then
		-- La touffe : trois boules de vert decalees, jamais une seule (le
		-- piege des couronnes du Sanctuaire : une boule sur un baton est une
		-- sucette). Elle a de la collision : c'est elle qui couvre la tete.
		for k = -1, 1 do
			local b = part(
				name .. "Touffe",
				cover,
				Vector3.new(3.2, 3.2, 3.2),
				cf * CFrame.new(k * (w / 3.4), 4.6 + (k % 2) * 0.6, (k % 2) * 0.4),
				if k == 0 then LEAF_LIGHT else LEAF,
				Enum.Material.Grass
			)
			b.Shape = Enum.PartType.Ball
		end
	end
	if bloom then
		for k = 0, 4 do
			local f = ghost(
				part(
					name .. "Fleur",
					decor,
					Vector3.new(0.6, 0.6, 0.6),
					cf * CFrame.new((k - 2) * (w / 5.5), 3.5, (k % 2 - 0.5) * (d / 3)),
					BLOOM[(k % #BLOOM) + 1],
					Enum.Material.SmoothPlastic
				)
			)
			f.Shape = Enum.PartType.Ball
		end
	end
end

twice(function(s)
	-- L'anneau exterieur : des palmiers aux quatre coins et le long des
	-- cotes, des bacs en quinconce. Les palmiers montent jusqu'a la charpente
	-- et donnent a la serre sa hauteur.
	for i, p in
		{
			{ 52, 52, 26, 5, 0.3 },
			{ 30, 60, 22, 6, 2.1 },
			{ 60, 28, 20, 4, 4.0 },
			{ -24, 60, 24, 5, 1.2 },
			{ -52, 54, 22, 6, 5.1 },
		}
	do
		local base = rotated(s, CFrame.new(p[1], 0, p[2])).Position
		palm(
			string.format("Palmier%d_%d", s, i),
			base,
			p[3],
			p[4],
			p[5] + (if s < 0 then math.pi else 0)
		)
	end
	for i, b in
		{
			{ 30, 0, 44, 6, 10, false, true },
			{ 60, 46, 0, 8, 5, true, false },
			{ 10, 58, 0, 10, 5, true, true },
			{ -40, 60, 0, 9, 5, true, false },
			{ 46, 18, 0.5, 6, 5, false, true },
		}
	do
		local cf = rotated(s, CFrame.new(b[1], 0, b[2]) * CFrame.Angles(0, b[3] * 0.01, 0))
		planter(string.format("Bac%d_%d", s, i), cf, b[4], b[5], b[6], b[7])
	end

	-- L'anneau interieur : deux grands bacs par moitie, et un banc de
	-- rempotage. Pas de palmier : on doit voir la rotonde au travers.
	for i, b in { { 30, 14, 8, 4, true }, { 14, 32, 4, 8, true }, { 28, 30, 5, 5, false } } do
		planter(
			string.format("BacInt%d_%d", s, i),
			rotated(s, CFrame.new(b[1], 0, b[2])),
			b[3],
			b[4],
			b[5],
			true
		)
	end
	part(
		"Etabli" .. s,
		cover,
		Vector3.new(7, 3.2, 2.4),
		rotated(s, CFrame.new(-30, 1.6, 16) * CFrame.Angles(0, 0.4, 0)),
		Color3.fromRGB(112, 86, 60),
		Enum.Material.WoodPlanks
	)
	for k = -1, 1 do
		local pot = cylinder(
			"Pot",
			decor,
			1.2,
			1.2,
			rotated(
				s,
				CFrame.new(-30, 0, 16)
					* CFrame.Angles(0, 0.4, 0)
					* CFrame.new(k * 2, 3.8, 0)
					* CFrame.Angles(0, 0, math.pi / 2)
			),
			TERRACOTTA,
			Enum.Material.Slate
		)
		ghost(pot)
	end
end)

--------------------------------------------------------------------------------
-- LA ROTONDE ET SA FONTAINE
--------------------------------------------------------------------------------

do
	local basin = cylinder(
		"Vasque",
		cover,
		1.8,
		9,
		CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.pi / 2),
		STONE_DARK,
		Enum.Material.Limestone
	)
	local water = ghost(
		cylinder(
			"Eau",
			decor,
			0.2,
			7.8,
			CFrame.new(0, 1.7, 0) * CFrame.Angles(0, 0, math.pi / 2),
			WATER,
			Enum.Material.SmoothPlastic
		)
	)
	water.Reflectance = 0.15
	local _ = basin
	cylinder(
		"Fut",
		cover,
		6,
		1.6,
		CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.pi / 2),
		STONE,
		Enum.Material.Limestone
	)
	cylinder(
		"Coupe",
		decor,
		0.6,
		4,
		CFrame.new(0, 6.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		STONE,
		Enum.Material.Limestone
	)
	-- Quatre bacs hauts dans la rotonde, entre les portes. PAS SUR LES AXES :
	-- poses a 0 et 180 degres, ils cachaient le centre a tous les departs, et
	-- la map perdait la seule chose qu'elle promet. Decales de 22,5 degres.
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.rad(22.5)
		planter(
			"BacRotonde" .. i,
			CFrame.new(math.cos(a) * 10, 0, math.sin(a) * 10) * CFrame.Angles(0, -a, 0),
			3,
			5,
			true,
			true
		)
	end
end

--------------------------------------------------------------------------------
-- LA CHARPENTE
--------------------------------------------------------------------------------

-- LE TOIT N'EXISTE PAS, SEULE SA CHARPENTE EXISTE. Un toit de verre jetterait
-- une ombre grise sur toute la map et doublerait les reflets ; des arcs de fer
-- suffisent a dire « serre », et ils laissent passer le soleil rasant qui
-- donne leur ombre aux palmiers. Aucun n'a de collision.
for i = -3, 3 do
	local x = i * 20
	for k = 0, 11 do
		local a0 = k / 12 * math.pi
		local a1 = (k + 1) / 12 * math.pi
		local p0 = Vector3.new(x, 18 + math.sin(a0) * 14, -HALF + (1 - math.cos(a0)) * HALF)
		local p1 = Vector3.new(x, 18 + math.sin(a1) * 14, -HALF + (1 - math.cos(a1)) * HALF)
		local mid = (p0 + p1) / 2
		local rib = ghost(
			part(
				"Arc",
				decor,
				Vector3.new(0.5, 0.5, (p1 - p0).Magnitude + 0.2),
				CFrame.lookAt(mid, p1),
				IRON,
				Enum.Material.Metal
			)
		)
		rib.CastShadow = false
	end
end
for _, z in { -50, -25, 0, 25, 50 } do
	local y = 18 + math.sin(math.acos(1 - (z + HALF) / HALF)) * 14
	local purlin = ghost(
		part(
			"Panne",
			decor,
			Vector3.new(2 * HALF, 0.4, 0.4),
			CFrame.new(0, y, z),
			IRON,
			Enum.Material.Metal
		)
	)
	purlin.CastShadow = false
end

--------------------------------------------------------------------------------
-- LES CAMPS
--------------------------------------------------------------------------------

twice(function(s)
	local team = if s == 1 then "B" else "A"
	local tint = if s == 1 then COLOR_B else COLOR_A
	local folder = Instance.new("Folder")
	folder.Name = "Spawns" .. team
	folder.Parent = map
	for i = 1, 5 do
		local marker = Instance.new("Part")
		marker.Name = string.format("Spawn%d", i)
		marker.Size = Vector3.new(2, 1, 2)
		marker.Anchored = true
		marker.CanCollide = false
		marker.Transparency = 1
		marker.Position = Vector3.new(s * SPAWN_X, SPAWN_Y, (i - 3) * SPAWN_SPREAD)
		marker.Parent = folder
	end
	-- Le vestibule : un auvent de toile a la couleur du camp, haut, contre le
	-- pourtour. Hors du champ de tir et hors de la vue de depart.
	ghost(
		part(
			"Auvent" .. team,
			decor,
			Vector3.new(10, 0.4, 26),
			rotated(s, CFrame.new(70, 16, 0)),
			tint,
			Enum.Material.Fabric
		)
	)
	ghost(
		part(
			"Tapis" .. team,
			decor,
			Vector3.new(10, 0.1, 22),
			rotated(s, CFrame.new(64, 0.15, 0)),
			tint,
			Enum.Material.Fabric
		)
	)
end)

--------------------------------------------------------------------------------
-- LE CONTRAT
--------------------------------------------------------------------------------

local centre = Instance.new("Part")
centre.Name = "ZoneCenter"
centre.Size = Vector3.new(4, 1, 4)
centre.Position = Vector3.new(0, 0.5, 0)
centre.Anchored = true
centre.CanCollide = false
centre.Transparency = 1
centre.Parent = map

local bounds = Instance.new("Part")
bounds.Name = "MapBounds"
bounds.Size = Vector3.new(BOUNDS, 1, BOUNDS)
bounds.Position = Vector3.new(0, -20, 0)
bounds.Anchored = true
bounds.CanCollide = false
bounds.Transparency = 1
bounds.Parent = map

map.Parent = Workspace

--------------------------------------------------------------------------------
-- L'ECLAIRAGE : UN MIDI D'HIVER, HUMIDE
--------------------------------------------------------------------------------

for _, old in Workspace.Terrain:GetChildren() do
	if old:IsA("Clouds") then
		old:Destroy()
	end
end
for _, class in
	{
		"Atmosphere",
		"Sky",
		"BloomEffect",
		"ColorCorrectionEffect",
		"SunRaysEffect",
		"DepthOfFieldEffect",
	}
do
	for _, old in Lighting:GetChildren() do
		if old:IsA(class) then
			old:Destroy()
		end
	end
end

-- Soleil rasant, et PERPENDICULAIRE a l'axe des camps : la mesure de l'ombre
-- en bas de la recette le verifie (le piege du Sanctuaire, qui logeait un camp
-- au soleil et l'autre a l'ombre).
-- Trouve par balayage, pas choisi : midi, latitude -48, soit 18,5 degres
-- d'elevation et un azimut exactement perpendiculaire aux camps. Le premier
-- reglage (9 h 24, latitude 58) logeait un camp entier au soleil et l'autre
-- entier a l'ombre, cinq departs sur cinq.
-- Le brouillard court du Bois brumeux est un reglage de PLACE : sans cette
-- remise a zero il resterait pose sur la map suivante.
Lighting.FogStart = 0
Lighting.FogEnd = 100000
Lighting.ClockTime = 12
Lighting.GeographicLatitude = -48
Lighting.Brightness = 2.4
Lighting.Ambient = Color3.fromRGB(92, 104, 96)
Lighting.OutdoorAmbient = Color3.fromRGB(150, 164, 150)
Lighting.ColorShift_Top = Color3.fromRGB(255, 240, 214)
Lighting.ColorShift_Bottom = Color3.fromRGB(70, 90, 70)
Lighting.ExposureCompensation = 0.1
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.35
Lighting.EnvironmentDiffuseScale = 0.5
Lighting.EnvironmentSpecularScale = 0.6

local clouds = Instance.new("Clouds")
clouds.Cover = 0.45
clouds.Density = 0.4
clouds.Color = Color3.fromRGB(250, 250, 246)
clouds.Parent = Workspace.Terrain

-- L'HUMIDITE : une brume verdatre legere, qui adoucit le fond de la serre sans
-- cacher le centre. C'est la seule map ou l'on doit voir LOIN : la brume reste
-- faible exprès.
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.3
atmosphere.Offset = 0.1
atmosphere.Color = Color3.fromRGB(214, 230, 214)
atmosphere.Decay = Color3.fromRGB(150, 176, 150)
atmosphere.Glare = 0.2
atmosphere.Haze = 1.4
atmosphere.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.25
bloom.Size = 20
bloom.Threshold = 2
bloom.Parent = Lighting

local sunrays = Instance.new("SunRaysEffect")
sunrays.Intensity = 0.06
sunrays.Spread = 0.6
sunrays.Parent = Lighting

local grade = Instance.new("ColorCorrectionEffect")
grade.Saturation = 0.04
grade.Contrast = 0.1
grade.Brightness = 0.01
grade.TintColor = Color3.fromRGB(248, 255, 244)
grade.Parent = Lighting

pcall(function()
	Lighting.Technology = Enum.Technology.Future
end)

--------------------------------------------------------------------------------
-- CE QUE LA MAP SE MESURE A ELLE-MEME
--------------------------------------------------------------------------------

local alarms = 0
local probe = RaycastParams.new()
probe.FilterType = Enum.RaycastFilterType.Include
probe.FilterDescendantsInstances = { map }
probe.RespectCanCollide = true

local FINAL_RADIUS = 16
do
	local arena = game:GetService("ReplicatedStorage"):FindFirstChild("Arena")
	local module = arena and arena:FindFirstChild("Config")
	local ok, conf = false, nil
	if module then
		ok, conf = pcall(require, module)
	end
	local found = if ok
			and type(conf) == "table"
			and type(conf.round) == "table"
		then tonumber(conf.round.zoneFinalRadiusStuds)
		else nil
	if found then
		FINAL_RADIUS = found
	end
end
local EYE = 3.5

print("")
print(string.format("[Arena] ===== %s se mesure =====", map.Name))

do
	local open, longest, couples = 0, 0, 0
	for _, a in map.SpawnsA:GetChildren() do
		for _, b in map.SpawnsB:GetChildren() do
			couples += 1
			local from = a.Position + Vector3.new(0, EYE, 0)
			local delta = (b.Position + Vector3.new(0, EYE, 0)) - from
			if Workspace:Raycast(from, delta, probe) == nil then
				open += 1
				longest = math.max(longest, delta.Magnitude)
			end
		end
	end
	if open == 0 then
		print(string.format("  Departs : aucune des %d lignes n'est degagee. Bon.", couples))
	else
		alarms += 1
		warn(
			string.format(
				"[Arena]   Departs : %d lignes degagees sur %d, la plus longue %.0f studs.",
				open,
				couples,
				longest
			)
		)
	end
	local floating = 0
	for _, folder in { map.SpawnsA, map.SpawnsB } do
		for _, marker in folder:GetChildren() do
			if Workspace:Raycast(marker.Position, Vector3.new(0, -12, 0), probe) == nil then
				floating += 1
			end
		end
	end
	if floating == 0 then
		print("  Departs : tous ont du sol sous eux. Bon.")
	else
		alarms += 1
		warn(string.format("[Arena]   %d point(s) de depart flottent.", floating))
	end
end

do
	local origin = centre.Position + Vector3.new(0, EYE, 0)
	local covered = 0
	for step = 0, 15 do
		local angle = step / 16 * math.pi * 2
		if
			Workspace:Raycast(
				origin,
				Vector3.new(math.cos(angle), 0, math.sin(angle)) * FINAL_RADIUS,
				probe
			)
		then
			covered += 1
		end
	end
	print(
		string.format(
			"  Cercle final : %d directions sur 16 trouvent un couvert dans les %d studs.",
			covered,
			FINAL_RADIUS
		)
	)
	if covered < 4 or covered > 12 then
		alarms += 1
		warn("[Arena]   Le cercle final est trop nu ou trop encombre.")
	end
end

-- LA PROMESSE DE CETTE MAP : on voit le centre de partout. Depuis chaque
-- point de depart, on compte ce qui cache le centre en ne regardant QUE le
-- decor opaque (le verre est exclu de ce rayon-la, puisqu'il ne cache rien).
-- Et a l'inverse, le chemin de marche jusqu'au centre doit etre bien plus
-- long que la distance a vol d'oiseau : sinon la map ne pose plus sa question.
do
	local glassParts = {}
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Glass then
			table.insert(glassParts, d)
		end
	end
	local sight = RaycastParams.new()
	sight.FilterType = Enum.RaycastFilterType.Exclude
	sight.FilterDescendantsInstances = glassParts
	sight.RespectCanCollide = true
	local seen, total = 0, 0
	for _, folder in { map.SpawnsA, map.SpawnsB } do
		for _, s in folder:GetChildren() do
			total += 1
			local from = s.Position + Vector3.new(0, EYE, 0)
			local to = centre.Position + Vector3.new(0, EYE, 0)
			local hit = Workspace:Raycast(from, to - from, sight)
			if hit == nil or not hit.Instance:IsDescendantOf(map) then
				seen += 1
			elseif (hit.Position - to).Magnitude < 6 then
				-- Le fut de la fontaine, au centre exact : c'est ce qu'on vise.
				seen += 1
			end
		end
	end
	print(
		string.format(
			"  Le centre se voit au travers du verre depuis %d departs sur %d.",
			seen,
			total
		)
	)
	if seen < total / 2 then
		alarms += 1
		warn("[Arena]   Le decor opaque cache le centre : la map ne tient plus sa promesse.")
	end
end

-- L'OMBRE TOMBE-T-ELLE PAREIL SUR LES DEUX CAMPS ?
do
	local sun = Lighting:GetSunDirection()
	local counts = {}
	for _, side in { "SpawnsA", "SpawnsB" } do
		local shaded = 0
		for _, s in map:FindFirstChild(side):GetChildren() do
			if Workspace:Raycast(s.Position + Vector3.new(0, EYE, 0), sun * 400, probe) then
				shaded += 1
			end
		end
		table.insert(counts, shaded)
	end
	local elevation = math.deg(math.asin(sun.Y))
	print(
		string.format(
			"  Soleil a %.1f degres ; ombre aux departs : %d et %d sur 5.",
			elevation,
			counts[1],
			counts[2]
		)
	)
	if math.abs(counts[1] - counts[2]) >= 2 then
		alarms += 1
		warn("[Arena]   L'ombre est inegale entre les deux camps.")
	end
end

local count = 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
print(
	string.format(
		"[Arena] Serre construite : %d parts. %s",
		count,
		if alarms == 0 then "Rien a signaler." else alarms .. " point(s) a regarder."
	)
)
