--!nolint
--[[
	BuildBazarMap — « Le Bazar ». A coller dans la barre de commande, ou a
	charger par le pont MCP (voir CLAUDE.md, « loadstring est verrouille »).

	POURQUOI CE FICHIER EXISTE
	Les maps vivent dans Workspace, que Rojo ne touche pas, et le .rbxl n'est
	pas dans Git. Ce script est la seule sauvegarde de la map. Il detruit toute
	autre map conforme avant de construire.

	CE N'EST PAS DU CODE DE JEU : hors du projet Rojo, jamais execute en partie.

	CE QU'ELLE RACONTE
	Un marche de nuit, ferme sur lui-meme : des rangees d'etals sous des toiles
	de couleur, des guirlandes de lanternes, une fontaine au carrefour. La seule
	map de nuit, et la seule ou la lumiere est portee par le decor au lieu du
	ciel. Construite le 4 novembre 2026, sans Josh.

	CE QU'ELLE FAIT JOUER, et c'est une question qu'aucune des quatre autres ne
	pose : QUELLE ALLEE PRENDRE.
	- TROIS ALLEES PARALLELES relient les deux camps : celle du milieu, la plus
	  courte, passe par la place de la fontaine ; les deux du bord sont plus
	  longues et encombrees d'echoppes.
	- Les deux rangees d'etals qui les separent sont des murs. On ne voit pas
	  d'une allee a l'autre : on ENTEND, et on devine.
	- Deux ruelles de traverse par rangee permettent de changer d'allee. C'est
	  la que se jouent les prises a revers.
	- Aucune allee ne se tient en enfilade : dans l'axe d'une allee, la vue
	  s'arrete avant soixante studs. Les armes de tir longues y perdent leur
	  avantage ; la melee et les classes qui surprennent y gagnent. C'est
	  voulu : la Carriere et le Colisee font l'inverse.
	  LES DIAGONALES, ELLES, PORTENT LOIN : a travers un carrefour, vers la
	  cour ouverte d'un camp, la mesure trouve jusqu'a 89 studs. Fermer les
	  cours aurait coupe les allees de leurs camps. C'est donc la que se
	  placent les tireurs, et c'est une information pour Josh, pas un oubli.

	Symetrie de ROTATION autour du centre ((x, z) -> (-x, -z)), comme la
	Carriere : les deux camps ont exactement le meme chemin.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

--------------------------------------------------------------------------------
-- LES COTES
--------------------------------------------------------------------------------

local BOUNDS = 156
local HALF = 74 -- face interieure des facades du pourtour
local SPAWN_X = 62
local SPAWN_Y = 4
local SPAWN_SPREAD = 4
local ROW_IN = 16 -- face des rangees d'etals cote allee centrale
local ROW_OUT = 24 -- face des rangees cote allees du bord
local ROW_HEIGHT = 10
-- LES RUELLES NE SONT PAS EN FACE L'UNE DE L'AUTRE. Alignees (x = +-18 des
-- deux cotes), elles ouvraient une vue de 115 studs a travers toute la map,
-- d'une facade a l'autre : la mesure de la recette l'a dit a la premiere
-- construction. Decalees, la ruelle d'en face donne sur un mur d'etals.
local ALLEY_A = -26 -- les deux ruelles de la rangee nord ; la rangee sud
local ALLEY_B = 10 -- les recoit tournees d'un demi-tour, donc en +26 et -10
local ALLEY_WIDE = 8
local ROW_END = 46 -- les rangees s'arretent avant les cours des camps
local PLAZA = 15 -- rayon de la place de la fontaine

local COBBLE = Color3.fromRGB(92, 84, 78)
local COBBLE_DARK = Color3.fromRGB(64, 58, 56)
local PLASTER = Color3.fromRGB(176, 150, 118)
local PLASTER_DARK = Color3.fromRGB(128, 106, 84)
local BRICK = Color3.fromRGB(122, 74, 56)
local TIMBER = Color3.fromRGB(86, 60, 42)
local TIMBER_LIGHT = Color3.fromRGB(128, 94, 62)
local BRASS = Color3.fromRGB(190, 150, 70)
local WATER = Color3.fromRGB(40, 78, 92)
local LANTERN = Color3.fromRGB(255, 184, 96)
-- Les toiles : quatre couleurs, et pas une de plus. Un marche a cent couleurs
-- est un bruit ; quatre teintes sourdes qui reviennent deviennent un rythme.
local CANVAS = {
	Color3.fromRGB(156, 46, 40),
	Color3.fromRGB(196, 128, 44),
	Color3.fromRGB(44, 108, 112),
	Color3.fromRGB(112, 60, 104),
}
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
-- Aucune matiere generee ici : on vide le dossier commun, sinon les matieres
-- d'une autre map restent posees sur les memes matieres de base.
do
	local MaterialService = game:GetService("MaterialService")
	local folder = MaterialService:FindFirstChild("ArenaMaterials")
	if folder then
		folder:Destroy()
	end
end

local map = Instance.new("Folder")
map.Name = "BazarMap"
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
	p.Material = material or Enum.Material.Fabric
	p.Parent = parent
	return p
end

-- Un decor qu'on traverse : pas de collision, pas de requete. Une toile ou une
-- guirlande qui arreterait un rayon fausserait la mesure des lignes de tir, et
-- un joueur qui se cogne a une guirlande ne comprend pas ce qui l'arrete.
local function ghost(p)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

-- LA SYMETRIE SE POSE A UN SEUL ENDROIT. Chaque piece de jeu existe deux fois,
-- la seconde tournee d'un demi-tour autour du centre : ecrire la paire a la
-- main, c'est la garantie qu'un jour l'une des deux bouge sans l'autre.
local function twice(fn)
	fn(1)
	fn(-1)
end

local function rotated(s, cf)
	if s == 1 then
		return cf
	end
	return CFrame.Angles(0, math.pi, 0) * cf
end

local function lantern(parent, pos, withLight)
	local glass = ghost(
		part("Lanterne", parent, Vector3.new(0.9, 1.2, 0.9), CFrame.new(pos), LANTERN, Enum.Material.Neon)
	)
	ghost(part("LanterneChapeau", parent, Vector3.new(1.2, 0.3, 1.2), CFrame.new(pos + Vector3.new(0, 0.75, 0)), TIMBER))
	if withLight then
		local light = Instance.new("PointLight")
		light.Color = LANTERN
		light.Range = 20
		light.Brightness = 0.9
		light.Shadows = true
		light.Parent = glass
	end
	return glass
end

--------------------------------------------------------------------------------
-- LE SOL ET LE POURTOUR
--------------------------------------------------------------------------------

part("Pave", decor, Vector3.new(BOUNDS, 2, BOUNDS), CFrame.new(0, -1, 0), COBBLE, Enum.Material.Cobblestone)
-- Une bande de pave plus sombre au milieu de chaque allee : le chemin qu'on
-- prend, use par les pas. Elle dit a l'oeil OU sont les trois allees.
for _, z in { 0, 41, -41 } do
	part(
		"Usure",
		decor,
		Vector3.new(2 * ROW_END + 20, 0.1, 6),
		CFrame.new(0, 0.05, z),
		COBBLE_DARK,
		Enum.Material.Cobblestone
	)
end

-- Les facades du pourtour : hautes, aveugles en bas, fenetres eclairees en
-- haut. Elles ferment la map sans qu'on voie un mur invisible.
for _, side in { 1, -1 } do
	for _, axis in { "x", "z" } do
		local size = if axis == "x"
			then Vector3.new(2 * HALF + 8, 16, 4)
			else Vector3.new(4, 16, 2 * HALF + 8)
		local pos = if axis == "x"
			then Vector3.new(0, 8, side * (HALF + 2))
			else Vector3.new(side * (HALF + 2), 8, 0)
		part("Facade", decor, size, CFrame.new(pos), PLASTER, Enum.Material.Brick)
		-- Un soubassement plus sombre et une corniche : la facade a un bas et
		-- un haut, donc une echelle.
		local base = if axis == "x" then Vector3.new(size.X, 3, 4.6) else Vector3.new(4.6, 3, size.Z)
		part("Soubassement", decor, base, CFrame.new(pos.X, 1.5, pos.Z), PLASTER_DARK, Enum.Material.Brick)
		local top = if axis == "x" then Vector3.new(size.X, 1, 5.4) else Vector3.new(5.4, 1, size.Z)
		part("Corniche", decor, top, CFrame.new(pos.X, 16.2, pos.Z), PLASTER_DARK, Enum.Material.Concrete)
		-- Les fenetres eclairees, a l'etage : une sur trois seulement, sinon
		-- c'est une guirlande et plus une rue.
		for i = -6, 6 do
			if (i + (if axis == "x" then 0 else 1)) % 3 ~= 0 then
				continue
			end
			local along = i * 11
			local wpos = if axis == "x"
				then Vector3.new(along, 11, side * HALF)
				else Vector3.new(side * HALF, 11, along)
			local wsize = if axis == "x" then Vector3.new(2.4, 3.4, 0.4) else Vector3.new(0.4, 3.4, 2.4)
			ghost(part("Fenetre", decor, wsize, CFrame.new(wpos), Color3.fromRGB(255, 196, 120), Enum.Material.Neon))
		end
	end
end

--------------------------------------------------------------------------------
-- LES DEUX RANGEES D'ETALS
--------------------------------------------------------------------------------

-- LE MUR QUI SEPARE LES ALLEES. Chaque rangee est coupee en trois troncons par
-- les deux ruelles de traverse. Chaque troncon est un bloc plein (on ne voit
-- pas au travers) habille cote allee : comptoirs, toiles en auvent, jarres.
local function stallBlock(name, x0, x1, zIn, zOut, s, colorIndex)
	local cx = (x0 + x1) / 2
	local w = x1 - x0
	local depth = zOut - zIn
	local zc = (zIn + zOut) / 2
	-- Le bloc : murs de planches, toit plat. C'est lui le couvert.
	part(
		name,
		cover,
		Vector3.new(w, ROW_HEIGHT, depth),
		rotated(s, CFrame.new(cx, ROW_HEIGHT / 2, zc)),
		TIMBER,
		Enum.Material.WoodPlanks
	)
	part(
		name .. "Toit",
		decor,
		Vector3.new(w + 1, 0.6, depth + 1),
		rotated(s, CFrame.new(cx, ROW_HEIGHT + 0.3, zc)),
		TIMBER_LIGHT,
		Enum.Material.Wood
	)
	-- Les etals des deux faces : un comptoir bas, une toile en pente au-dessus,
	-- un poteau a chaque bout. Repetes tous les huit studs, ce qui donne a la
	-- rangee son rythme d'echoppes.
	for _, face in { -1, 1 } do
		local zFace = if face < 0 then zIn else zOut
		local n = math.floor(w / 8)
		for i = 0, n - 1 do
			local sx = x0 + 4 + i * 8
			local c = CANVAS[((colorIndex + i) % #CANVAS) + 1]
			part(
				name .. "Comptoir",
				cover,
				Vector3.new(6.4, 3.2, 2),
				rotated(s, CFrame.new(sx, 1.6, zFace + face * 1)),
				TIMBER_LIGHT,
				Enum.Material.Wood
			)
			-- La toile : un coin dont l'arete haute est contre le bloc.
			ghost(
				wedge(
					name .. "Toile",
					decor,
					Vector3.new(7.2, 1.6, 4),
					rotated(
						s,
						CFrame.new(sx, 7.2, zFace + face * 2)
							* CFrame.Angles(0, if face > 0 then 0 else math.pi, 0)
					),
					c
				)
			)
			ghost(
				part(
					name .. "Poteau",
					decor,
					Vector3.new(0.4, 6.4, 0.4),
					rotated(s, CFrame.new(sx + 3.4, 3.2, zFace + face * 3.8)),
					TIMBER
				)
			)
			-- Des marchandises sur le comptoir, de trois sortes : ce qui fait
			-- d'un comptoir un etal.
			local kind = (i + colorIndex) % 3
			if kind == 0 then
				for k = -1, 1 do
					local jar = part(
						name .. "Jarre",
						decor,
						Vector3.new(1.1, 1.1, 1.1),
						rotated(s, CFrame.new(sx + k * 1.8, 3.75, zFace + face * 1)),
						Color3.fromRGB(170, 96, 58),
						Enum.Material.Slate
					)
					jar.Shape = Enum.PartType.Ball
					ghost(jar)
				end
			elseif kind == 1 then
				ghost(
					part(
						name .. "Etoffes",
						decor,
						Vector3.new(4.6, 0.9, 1.4),
						rotated(s, CFrame.new(sx, 3.65, zFace + face * 1)),
						CANVAS[((i + 2) % #CANVAS) + 1],
						Enum.Material.Fabric
					)
				)
			else
				for k = -1, 1, 2 do
					ghost(
						part(
							name .. "Cagette",
							decor,
							Vector3.new(1.6, 0.8, 1.2),
							rotated(s, CFrame.new(sx + k * 1.3, 3.6, zFace + face * 1)),
							Color3.fromRGB(150, 160, 70),
							Enum.Material.Wood
						)
					)
				end
			end
		end
	end
end

twice(function(s)
	local tag = if s == 1 then "N" else "S"
	-- Trois troncons par rangee, separes par les deux ruelles de traverse.
	stallBlock("Rangee" .. tag .. "1", -ROW_END, ALLEY_A - ALLEY_WIDE / 2, ROW_IN, ROW_OUT, s, 0)
	stallBlock("Rangee" .. tag .. "2", ALLEY_A + ALLEY_WIDE / 2, ALLEY_B - ALLEY_WIDE / 2, ROW_IN, ROW_OUT, s, 1)
	stallBlock("Rangee" .. tag .. "3", ALLEY_B + ALLEY_WIDE / 2, ROW_END, ROW_IN, ROW_OUT, s, 2)

	-- Les ruelles de traverse ont un porche : deux piliers et un linteau, plus
	-- une lanterne. Un passage qu'on ne voit pas est un passage qu'on oublie.
	for _, ax in { ALLEY_A, ALLEY_B } do
		for _, dx in { -1, 1 } do
			part(
				"Pilier",
				cover,
				Vector3.new(1.2, ROW_HEIGHT + 2, 1.2),
				rotated(s, CFrame.new(ax + dx * (ALLEY_WIDE / 2 + 0.6), (ROW_HEIGHT + 2) / 2, ROW_IN + 0.6)),
				BRICK,
				Enum.Material.Brick
			)
		end
		ghost(
			part(
				"Linteau",
				decor,
				Vector3.new(ALLEY_WIDE + 2.4, 1.4, 1.6),
				rotated(s, CFrame.new(ax, ROW_HEIGHT + 1.4, ROW_IN + 0.6)),
				BRICK,
				Enum.Material.Brick
			)
		)
		lantern(decor, (rotated(s, CFrame.new(ax, ROW_HEIGHT - 1, ROW_IN + 0.6))).Position, true)
	end
end)

--------------------------------------------------------------------------------
-- LES ALLEES DU BORD : DES ECHOPPES EN QUINCONCE
--------------------------------------------------------------------------------

-- LE BORD EST LE CHEMIN LONG, ET IL FAUT QU'IL LE SOIT POUR UNE RAISON. Des
-- echoppes isolees, alternees contre la facade et contre la rangee, obligent
-- a zigzaguer : on avance de couvert en couvert, et personne ne tient
-- l'allee entiere d'un bout.
local BOOTHS = {
	{ x = -34, z = 52 },
	{ x = -12, z = 31 },
	{ x = 8, z = 52 },
	{ x = 30, z = 31 },
	{ x = 50, z = 48 },
}
twice(function(s)
	for i, b in BOOTHS do
		local cf = rotated(s, CFrame.new(b.x, 0, b.z))
		local c = CANVAS[(i % #CANVAS) + 1]
		-- L'echoppe : trois cotes en planches, ouverte vers l'allee, haute
		-- comme un homme et demi. Assez pour couvrir, pas assez pour aveugler
		-- au-dessus.
		part("Echoppe", cover, Vector3.new(7, 8.6, 0.8), cf * CFrame.new(0, 4.3, 2.8), TIMBER, Enum.Material.WoodPlanks)
		part("Echoppe", cover, Vector3.new(0.8, 8.6, 6.4), cf * CFrame.new(-3.1, 4.3, 0), TIMBER, Enum.Material.WoodPlanks)
		part("Echoppe", cover, Vector3.new(0.8, 8.6, 6.4), cf * CFrame.new(3.1, 4.3, 0), TIMBER, Enum.Material.WoodPlanks)
		part("EchoppeComptoir", cover, Vector3.new(5.4, 3.2, 1.6), cf * CFrame.new(0, 1.6, -2.2), TIMBER_LIGHT, Enum.Material.Wood)
		ghost(wedge("EchoppeToit", decor, Vector3.new(8, 1.8, 7.6), cf * CFrame.new(0, 9.5, 0) * CFrame.Angles(0, math.pi, 0), c))
		lantern(decor, (cf * CFrame.new(0, 7.4, -3.4)).Position, i % 2 == 1)
	end

	-- LES ILOTS AU MILIEU DE L'ALLEE. Les echoppes alternees contre la facade
	-- et contre la rangee laissaient libre la ligne du milieu : 114 studs de
	-- vue d'un bout a l'autre de l'allee, mesures a la premiere construction.
	-- Un ilot de marchandises entre deux echoppes oblige a contourner, et
	-- coupe la ligne.
	for i, x in { -23, 19 } do
		local cf = rotated(s, CFrame.new(x, 0, 41))
		part("Ilot", cover, Vector3.new(6, 3.4, 10), cf * CFrame.new(0, 1.7, 0), TIMBER_LIGHT, Enum.Material.WoodPlanks)
		for k = -1, 1 do
			part(
				"Ballot",
				cover,
				Vector3.new(4.4, 3.4, 2.8),
				cf * CFrame.new(0, 5.1, k * 3.2) * CFrame.Angles(0, k * 0.2, 0),
				CANVAS[((i + k + 1) % #CANVAS) + 1],
				Enum.Material.Fabric
			)
		end
		lantern(decor, (cf * CFrame.new(0, 8.4, 0)).Position, false)
	end

	-- Des tonneaux et des caisses le long des facades : des couverts bas, a
	-- hauteur de taille, qu'on contourne ou par-dessus lesquels on tire.
	for i, x in { -50, -24, 0, 22, 40 } do
		local z = if i % 2 == 0 then 64 else 60
		local barrel = part(
			"Tonneau",
			cover,
			Vector3.new(3.6, 2.6, 2.6),
			rotated(s, CFrame.new(x, 1.8, z) * CFrame.Angles(0, 0, math.pi / 2)),
			TIMBER_LIGHT,
			Enum.Material.Wood
		)
		barrel.Shape = Enum.PartType.Cylinder
		part("Caisse", cover, Vector3.new(3, 3, 3), rotated(s, CFrame.new(x + 3.2, 1.5, z + 0.6) * CFrame.Angles(0, 0.3, 0)), TIMBER, Enum.Material.WoodPlanks)
	end
end)

--------------------------------------------------------------------------------
-- L'ALLEE DU MILIEU ET LA PLACE DE LA FONTAINE
--------------------------------------------------------------------------------

-- LA PLACE EST LE DERNIER CERCLE. La fontaine au centre coupe la ligne droite
-- d'un camp a l'autre ; quatre bornes a lanterne autour donnent de quoi se
-- disputer la place sans qu'elle devienne aveugle.
do
	local basin = part("Bassin", cover, Vector3.new(2.4, 11, 11), CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2), PLASTER_DARK, Enum.Material.Concrete)
	basin.Shape = Enum.PartType.Cylinder
	local water = ghost(part("Eau", decor, Vector3.new(0.3, 9.6, 9.6), CFrame.new(0, 2.3, 0) * CFrame.Angles(0, 0, math.pi / 2), WATER, Enum.Material.SmoothPlastic))
	water.Shape = Enum.PartType.Cylinder
	water.Reflectance = 0.2
	local column = part("Colonne", cover, Vector3.new(12, 2.4, 2.4), CFrame.new(0, 6, 0) * CFrame.Angles(0, 0, math.pi / 2), PLASTER, Enum.Material.Concrete)
	column.Shape = Enum.PartType.Cylinder
	local bowl = part("Vasque", decor, Vector3.new(1, 5, 5), CFrame.new(0, 9, 0) * CFrame.Angles(0, 0, math.pi / 2), BRASS, Enum.Material.Metal)
	bowl.Shape = Enum.PartType.Cylinder
	local crown = ghost(part("Flamme", decor, Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 12.6, 0), LANTERN, Enum.Material.Neon))
	crown.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = LANTERN
	light.Range = 30
	light.Brightness = 1.3
	light.Shadows = true
	light.Parent = crown

	-- Le dallage de la place, plus clair que les allees : on sait qu'on y est.
	local floor = part("Dallage", decor, Vector3.new(0.12, 2 * PLAZA, 2 * PLAZA), CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(128, 116, 104), Enum.Material.Pavement)
	floor.Shape = Enum.PartType.Cylinder

	-- Quatre lampadaires sur les axes, plus hauts que l'oeil : ce sont eux qui
	-- coupent les deux diagonales d'un camp a l'autre qui passaient a cote de
	-- la fontaine.
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2
		local x, z = math.cos(a) * 13, math.sin(a) * 13
		-- Fer sombre et pas laiton : en laiton, sous les lanternes, les quatre
		-- futs sortaient jaune vif et se lisaient comme des piliers geants. Et pas
		-- plus minces que 1,6 : a 1,2, deux diagonales d'un camp a l'autre se
		-- sont rouvertes, la mesure l'a dit a la construction suivante.
		part("Lampadaire", cover, Vector3.new(1.6, 9, 1.6), CFrame.new(x, 4.5, z), Color3.fromRGB(46, 46, 52), Enum.Material.Metal)
		lantern(decor, Vector3.new(x, 10, z), i % 2 == 0)
	end
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local x, z = math.cos(a) * 10, math.sin(a) * 10
		part("Borne", cover, Vector3.new(2.2, 5.6, 2.2), CFrame.new(x, 2.8, z) * CFrame.Angles(0, a, 0), PLASTER_DARK, Enum.Material.Concrete)
		lantern(decor, Vector3.new(x, 6.4, z), false)
	end
end

-- DEUX CHARRETTES DANS L'ALLEE DU MILIEU, decalees chacune d'un cote. Sans
-- elles l'allee centrale est un couloir de tir de cent vingt studs d'un camp
-- a l'autre, et la fontaine seule ne le coupe qu'en son milieu. Hautes de
-- neuf studs a cause de leur bache : l'oeil d'un joueur est a sept et demi.
twice(function(s)
	local cf = rotated(s, CFrame.new(-32, 0, -4))
	part("Charrette", cover, Vector3.new(8, 3, 9), cf * CFrame.new(0, 2.5, 0), TIMBER_LIGHT, Enum.Material.WoodPlanks)
	part("Bache", cover, Vector3.new(7.4, 5, 8.6), cf * CFrame.new(0, 6.5, 0), CANVAS[2], Enum.Material.Fabric)
	for _, dz in { -3.2, 3.2 } do
		local wheel = part("Roue", decor, Vector3.new(0.6, 3.2, 3.2), cf * CFrame.new(4.3, 1.6, dz), TIMBER, Enum.Material.Wood)
		wheel.Shape = Enum.PartType.Cylinder
	end
	part("Brancard", decor, Vector3.new(6, 0.4, 0.4), cf * CFrame.new(-6.8, 1.4, -1.6), TIMBER, Enum.Material.Wood)
	part("Brancard", decor, Vector3.new(6, 0.4, 0.4), cf * CFrame.new(-6.8, 1.4, 1.6), TIMBER, Enum.Material.Wood)
end)

--------------------------------------------------------------------------------
-- LES GUIRLANDES
--------------------------------------------------------------------------------

-- LA LUMIERE DE LA MAP. Des guirlandes de lanternes tendues en travers des
-- trois allees. Une lanterne sur quatre seulement porte une vraie lumiere :
-- cent lumieres a ombre feraient tomber les images par seconde, et l'oeil ne
-- compte pas.
twice(function(s)
	for k, x in { -38, -6, 26 } do
		for _, zc in { 0, 41 } do
			if zc == 0 and s == -1 then
				continue
			end
			local span = if zc == 0 then 2 * ROW_IN else 2 * (HALF - ROW_OUT) * 0.5
			local z0 = zc - span / 2
			-- Le fil : sans lui les lanternes flottent, et des lumieres qui
			-- flottent se lisent comme un bug d'affichage, pas comme une fete.
			ghost(
				part(
					"Fil",
					decor,
					Vector3.new(0.22, 0.22, span),
					rotated(s, CFrame.new(x + k, 13.5, zc)),
					Color3.fromRGB(70, 58, 48),
					Enum.Material.Fabric
				)
			)
			for i = 0, 6 do
				local z = z0 + i * span / 6
				local sag = math.sin(i / 6 * math.pi) * 1.6
				local pos = (rotated(s, CFrame.new(x + k, 12.4 - sag * 0.4, z))).Position
				lantern(decor, pos, i == 3)
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- LES COURS DES CAMPS
--------------------------------------------------------------------------------

-- Chaque camp part d'une cour fermee par un portail, la ou les trois allees
-- naissent. Le portail porte la couleur du camp, en haut, hors du champ de
-- tir : c'est la que la banniere du Sanctuaire avait pris la moitie de
-- l'ecran.
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
	local cf = rotated(s, CFrame.new(SPAWN_X + 8, 0, 0))
	ghost(part("Tapis" .. team, decor, Vector3.new(8, 0.1, 22), cf * CFrame.new(-8, 0.05, 0), tint, Enum.Material.Fabric))
	part("PortailG" .. team, decor, Vector3.new(3, 18, 3), cf * CFrame.new(3, 9, -13), BRICK, Enum.Material.Brick)
	part("PortailD" .. team, decor, Vector3.new(3, 18, 3), cf * CFrame.new(3, 9, 13), BRICK, Enum.Material.Brick)
	ghost(part("Fronton" .. team, decor, Vector3.new(3, 3, 29), cf * CFrame.new(3, 17.5, 0), tint, Enum.Material.Fabric))
	lantern(decor, (cf * CFrame.new(1, 14, -13)).Position, true)
	lantern(decor, (cf * CFrame.new(1, 14, 13)).Position, false)
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
-- L'ECLAIRAGE : LA NUIT
--------------------------------------------------------------------------------

for _, old in Workspace.Terrain:GetChildren() do
	if old:IsA("Clouds") then
		old:Destroy()
	end
end
for _, class in { "Atmosphere", "Sky", "BloomEffect", "ColorCorrectionEffect", "SunRaysEffect", "DepthOfFieldEffect" } do
	for _, old in Lighting:GetChildren() do
		if old:IsA(class) then
			old:Destroy()
		end
	end
end

-- UNE NUIT JOUABLE N'EST PAS UNE NUIT NOIRE. L'ambiance exterieure reste
-- assez haute pour lire une silhouette a trente studs ; ce sont les
-- lanternes qui font le chaud et le contraste. Une nuit ou l'on ne voit pas
-- l'adversaire n'est pas une ambiance, c'est une injustice envers celui qui
-- ne connait pas la map.
-- Le brouillard court du Bois brumeux est un reglage de PLACE : sans cette
-- remise a zero il resterait pose sur la map suivante.
Lighting.FogStart = 0
Lighting.FogEnd = 100000
Lighting.ClockTime = 21.2
Lighting.GeographicLatitude = 30
-- LE FROID FAIT LE CHAUD. Premier essai : une ambiance tiede et une
-- exposition relevee, et toute la map est sortie orange d'un bout a l'autre,
-- bois, pave et toiles confondus. Une lanterne ne se lit comme chaude que
-- contre un fond froid : l'ambiance est donc bleue lune, et c'est elle qui
-- separe les matieres.
Lighting.Brightness = 0.6
Lighting.Ambient = Color3.fromRGB(40, 44, 62)
Lighting.OutdoorAmbient = Color3.fromRGB(78, 92, 138)
Lighting.ColorShift_Top = Color3.fromRGB(96, 116, 170)
Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
Lighting.ExposureCompensation = 0
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.25
Lighting.EnvironmentDiffuseScale = 0.3
Lighting.EnvironmentSpecularScale = 0.5

local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.32
atmosphere.Offset = 0.1
atmosphere.Color = Color3.fromRGB(70, 66, 96)
atmosphere.Decay = Color3.fromRGB(40, 34, 52)
atmosphere.Glare = 0
atmosphere.Haze = 1.6
atmosphere.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.35
bloom.Size = 18
bloom.Threshold = 1.9
bloom.Parent = Lighting

local grade = Instance.new("ColorCorrectionEffect")
grade.Saturation = -0.12
grade.Contrast = 0.14
grade.Brightness = 0
grade.TintColor = Color3.fromRGB(236, 240, 255)
grade.Parent = Lighting

pcall(function()
	Lighting.Technology = Enum.Technology.Future
end)

--------------------------------------------------------------------------------
-- CE QUE LA MAP SE MESURE A ELLE-MEME
--------------------------------------------------------------------------------

-- Les memes trois mesures que les quatre autres recettes, et la quatrieme qui
-- est la question de CETTE map : la plus longue ligne de vue depuis le milieu
-- de chaque allee. Si elle depasse cinquante studs, la promesse « pas de tir
-- long » est cassee et il faut le savoir a la construction.
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
	local found = if ok and type(conf) == "table" and type(conf.round) == "table"
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
		warn(string.format("[Arena]   Departs : %d lignes degagees sur %d, la plus longue %.0f studs.", open, couples, longest))
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
		if Workspace:Raycast(origin, Vector3.new(math.cos(angle), 0, math.sin(angle)) * FINAL_RADIUS, probe) then
			covered += 1
		end
	end
	print(string.format("  Cercle final : %d directions sur 16 trouvent un couvert dans les %d studs.", covered, FINAL_RADIUS))
	if covered < 4 or covered > 12 then
		alarms += 1
		warn("[Arena]   Le cercle final est trop nu ou trop encombre.")
	end
end

-- LA PROMESSE DE CETTE MAP. Depuis le milieu de chaque allee, a hauteur
-- d'yeux : la plus longue vue DANS L'AXE (la promesse, qui avertit), et la
-- plus longue en diagonale (une information, qui s'imprime). La premiere
-- version ne distinguait pas les deux et avertissait sur des diagonales que
-- rien ne peut fermer sans couper les allees de leurs camps.
do
	local axis, diagonal, where = 0, 0, ""
	for _, z in { 0, 41, -41 } do
		for _, x in { -40, -20, 20, 40 } do
			local origin = Vector3.new(x, 0.5 + EYE, z)
			for step = 0, 15 do
				local angle = step / 16 * math.pi * 2
				local direction = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 200
				local hit = Workspace:Raycast(origin, direction, probe)
				local length = if hit then hit.Distance else 200
				if step % 8 == 0 then
					if length > axis then
						axis = length
						where = string.format("(%d, %d)", x, z)
					end
				else
					diagonal = math.max(diagonal, length)
				end
			end
		end
	end
	if axis > 60 then
		alarms += 1
		warn(string.format("[Arena]   Une allee se tient en enfilade : %.0f studs depuis %s.", axis, where))
	else
		print(string.format("  Enfilade la plus longue dans l'axe des allees : %.0f studs. Bon.", axis))
	end
	print(string.format("  Diagonale la plus longue, a travers les carrefours : %.0f studs.", diagonal))
end

local count = 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
print(string.format("[Arena] Bazar construit : %d parts. %s", count, if alarms == 0 then "Rien a signaler." else alarms .. " point(s) a regarder."))
