--!nolint
--[[
	BuildColiseeMap — « L'Arene de sable ». A coller dans la barre de commande.

	POURQUOI CE FICHIER EXISTE
	Les maps vivent dans Workspace, que Rojo ne touche pas, et le .rbxl n'est
	pas dans Git. Une map construite a la main n'existe que dans la place : une
	fausse manoeuvre et elle est perdue sans trace. Ce script est la
	sauvegarde. Il detruit la map precedente avant de reconstruire, donc on
	peut le relancer autant qu'on veut, et deux maps ne cohabitent jamais —
	`MapService` prend la PREMIERE qui respecte le contrat, donc en laisser
	deux dans Workspace serait un tirage au sort.

	CE N'EST PAS DU CODE DE JEU : hors du projet Rojo, jamais execute en
	partie, pas verifie par Selene ni StyLua.

	CE QU'ELLE RACONTE
	Un colisee de pierre chaude en plein soleil. Gradins aveugles, facade a
	deux etages d'arcades, et au milieu une FOSSE : six studs plus bas, ronde,
	bordee de colonnes brisees. Le sable est clair, la pierre est ocre, la
	lumiere est rasante.

	CE QU'ELLE FAIT JOUER
	- La fosse est le point bas, et c'est la que la zone finit de se refermer
	  (rayon final 16 studs, fosse de 30). La fin de manche se joue donc en
	  contrebas, sous le regard de ceux qui tiennent le bord : c'est le moment
	  le plus tendu de la map, et il est voulu.
	- Le bord de la fosse est la vraie position de force, mais il est expose
	  de tous les cotes : on ne peut pas le tenir a une seule personne.
	- Douze colonnes a mi-distance coupent les longues lignes de vue. C'est ce
	  dont une classe de corps a corps a besoin pour revenir au contact apres
	  un repoussement — sans elles l'arc et le fusil de precision decident
	  tout.
	- Quatre escaliers descendent dans la fosse, aux quatre diagonales :
	  jamais moins de deux chemins pour s'en sortir, sinon un seul joueur la
	  verrouille.
	- Les deux departs sont sur des terrasses surelevees, face a face. Les
	  terrasses NE voient PAS la fosse : deux murs bas les en separent, pour
	  qu'on ne tire pas dans le dos d'un releve depuis son propre depart.

	LA TAILLE
	MapBounds fait 190 studs de cote, donc la zone demarre a 95 de rayon,
	c'est-a-dire tout le sol. Le carre est voulu meme si l'arene est ronde :
	la zone prend le PLUS PETIT cote de MapBounds, donc un rectangle long
	laisserait des departs hors zone des la premiere seconde.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local FLOOR_RADIUS = 78
local BOUNDS_WIDTH = 162
local PIT_RADIUS = 28
local PIT_DEPTH = 6
local SPAWN_DISTANCE = 60
local TERRACE_HEIGHT = 6
local SIDE_HEIGHT = 7

-- TOUT ETAIT DU MEME BEIGE, et c'etait le defaut le plus net de cette map :
-- le sable, les gradins, les piliers et les dunes tenaient dans un ecart de
-- vingt niveaux. Un batiment se detache de son terrain par la COULEUR avant
-- de se detacher par la forme, donc la pierre part vers le calcaire pale et
-- legerement FROID pendant que le sable part vers le jaune chaud. C'est le
-- meme ecart que dans la realite : un monument romain est gris-blanc, le
-- desert autour est dore.
local SAND = Color3.fromRGB(212, 180, 124)
local SAND_DARK = Color3.fromRGB(174, 144, 94)
local STONE = Color3.fromRGB(224, 216, 198)
local STONE_DARK = Color3.fromRGB(160, 150, 132)
local STONE_WARM = Color3.fromRGB(192, 162, 120)
local COLOR_A = Color3.fromRGB(70, 110, 190)
local COLOR_B = Color3.fromRGB(190, 70, 60)

for _, name in { "ArenaMap", "ColiseeMap", "CargoMap", "SanctuaireMap" } do
	local old = Workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

-- LA MAP APPORTE SON SOL. La Baseplate de Studio est a la meme hauteur que
-- le sable et gagne un pixel sur deux : l'arene apparaissait grise et
-- quadrillee au lieu d'etre en sable. Le point d'apparition par defaut part
-- avec elle, sinon il pose un joueur hors des deux camps.
for _, name in { "Baseplate", "SpawnLocation" } do
	local old = Workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

local map = Instance.new("Folder")
map.Name = "ColiseeMap"

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
	p.Color = color or STONE
	p.Material = material or Enum.Material.Sandstone
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- UN CYLINDRE ROBLOX EST COUCHE SUR X : Size.X est sa longueur, et son
-- diametre est le PLUS PETIT de Size.Y et Size.Z — jamais une ellipse. Pour
-- une colonne ou un disque, on le redresse d'un quart de tour sur Z.
local function pillar(name, parent, radius, height, x, z, y, color, material)
	local p = part(
		name,
		parent,
		Vector3.new(height, radius * 2, radius * 2),
		CFrame.new(x, y + height / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function disc(name, parent, radius, height, y, color, material)
	return pillar(name, parent, radius, height, 0, 0, y - height / 2, color, material)
end

-- Un anneau de dalles : c'est comme ca qu'on fabrique un sol troue sans
-- toucher a la geometrie soustraite, qui ne se reconstruit pas depuis un
-- script. Les dalles se chevauchent un peu, sinon le polygone laisse voir le
-- vide entre deux segments.
local function annulus(name, parent, inner, outer, y, thickness, segments, color, material)
	local mid = (inner + outer) / 2
	local chord = 2 * math.pi * outer / segments * 1.25
	for i = 1, segments do
		local a = (i - 1) / segments * math.pi * 2
		part(
			string.format("%s%d", name, i),
			parent,
			Vector3.new(chord, thickness, outer - inner),
			CFrame.new(math.sin(a) * mid, y - thickness / 2, math.cos(a) * mid)
				* CFrame.Angles(0, a, 0),
			color,
			material
		)
	end
end

-- ===== Le sol =============================================================
-- Un anneau de sable autour de la fosse, et la fosse six studs plus bas.
annulus("Sol", decor, PIT_RADIUS, FLOOR_RADIUS, 0, 4, 72, SAND, Enum.Material.Sand)
disc("Fosse", decor, PIT_RADIUS + 1, 4, -PIT_DEPTH, SAND_DARK, Enum.Material.Sand)

-- La paroi de la fosse, et sa margelle de pierre : c'est elle qui dessine le
-- cercle quand on regarde de loin.
annulus("Paroi", decor, PIT_RADIUS - 1, PIT_RADIUS + 1, 0, PIT_DEPTH, 72, STONE_DARK)
annulus("Margelle", decor, PIT_RADIUS - 1.6, PIT_RADIUS + 1.6, 0.6, 0.6, 72, STONE)

-- ===== Les quatre escaliers ==============================================
-- AUX DIAGONALES, pas sur les axes : les axes portent deja les departs, et
-- une sortie de fosse qui debouche face a un depart se tient trop facilement.
for _, a in { 45, 135, 225, 315 } do
	local rad = math.rad(a)
	local steps = PIT_DEPTH
	for s = 1, steps do
		local r = PIT_RADIUS + 2 - s * 1.6
		local y = -s
		part(
			string.format("Marche%d_%d", a, s),
			decor,
			Vector3.new(9, 1, 2.6),
			CFrame.new(math.sin(rad) * r, y + 0.5, math.cos(rad) * r) * CFrame.Angles(0, rad, 0),
			STONE
		)
	end
end

-- ===== Les douze colonnes ================================================
-- Hauteurs inegales exprès : douze colonnes identiques se lisent comme une
-- grille, et une grille s'apprend par coeur. Trois brisees donnent des
-- couvertures basses, ou on peut tirer par-dessus.
-- Les douze hauteurs sont symetriques a 180 degres (i et i+6 sont egales) :
-- c'est la seule chose a verifier en les changeant. L'anneau est decale d'un
-- demi-pas pour qu'AUCUNE colonne ne tombe sur un axe de camp : posee la,
-- elle arrive a un stud du bord de la terrasse et mure la sortie au lieu de
-- couvrir le terrain.
local HEIGHTS = { 21, 14, 7, 21, 14, 21, 7, 14, 21, 14, 7, 21 }
for i = 1, 12 do
	local a = (i - 1) / 12 * math.pi * 2 + math.pi / 12
	local x, z = math.sin(a) * 46, math.cos(a) * 46
	local h = HEIGHTS[i]
	pillar(string.format("Colonne%d", i), cover, 3.3, h, x, z, 0, STONE)
	-- Le socle et le chapiteau : deux blocs qui transforment un cylindre en
	-- colonne. C'est la seule difference entre « un tube » et « de la pierre
	-- taillee ».
	part(
		string.format("Socle%d", i),
		decor,
		Vector3.new(8.4, 1.4, 8.4),
		CFrame.new(x, 0.7, z) * CFrame.Angles(0, a, 0),
		STONE_DARK
	)
	if h > 8 then
		part(
			string.format("Chapiteau%d", i),
			decor,
			Vector3.new(8.2, 1.8, 8.2),
			CFrame.new(x, h - 0.9, z) * CFrame.Angles(0, a, 0),
			STONE
		)
	end
end

-- ===== Les deux steles =================================================
-- LA LIGNE DEPART-A-DEPART SE COUPE ICI. Verifie par un rayon tire d'une
-- terrasse a l'autre a hauteur de poitrine : sans elles il passait, soit
-- cent vingt studs de ligne de tir des la premiere seconde, et un fusil de
-- precision decidait la manche avant que quiconque ait bouge. La fosse ne
-- coupe rien, c'est un creux.
--
-- A mi-chemin (36 studs) et pas sur l'anneau : contre la terrasse ce serait
-- un mur devant la porte, au centre ce serait dans la fosse. Elles se
-- contournent des deux cotes, donc elles couvrent sans enfermer.
for _, side in { -1, 1 } do
	local x = side * 36
	pillar(string.format("Stele%d", side), cover, 3.6, 24, x, 0, 0, STONE)
	part(
		string.format("SteleSocle%d", side),
		decor,
		Vector3.new(10, 1.6, 10),
		CFrame.new(x, 0.8, 0),
		STONE_DARK
	)
	-- Le chapiteau brise : une stele a sommet plat se lit comme un poteau.
	part(
		string.format("SteleTete%d", side),
		decor,
		Vector3.new(9, 3, 9),
		CFrame.new(x, 23, 0) * CFrame.Angles(0, 0.3, side * 0.06),
		STONE
	)
end

-- ===== Les blocs epars ==================================================
-- LE RYTHME DE LA COUVERTURE. Entre l'anneau de colonnes et la facade il y
-- avait soixante studs de sable nu : on y traverse a decouvert, et une
-- traversee a decouvert se joue toute seule. Huit blocs tombes, hauts de
-- poitrine pour la moitie et de taille d'homme pour l'autre, donnent de quoi
-- avancer par sauts. Poses a douze paires de distance pour qu'aucun ne soit
-- a l'abri du suivant.
local RUBBLE = {
	{ 64, 1.0, 7, 5.5 },
	{ 64, 2.1, 6, 3.2 },
	{ 62, 3.4, 8, 4.6 },
	{ 34, 0.6, 6, 3.0 },
	{ 36, 2.6, 7, 4.8 },
	{ 38, 4.4, 5, 2.8 },
}
for i, r in RUBBLE do
	for _, side in { 1, -1 } do
		local a = r[2] * side + (if side < 0 then math.pi else 0)
		local x, z = math.sin(a) * r[1], math.cos(a) * r[1]
		part(
			string.format("Bloc%d_%d", i, side),
			cover,
			Vector3.new(r[3], r[4], r[3] * 0.8),
			CFrame.new(x, r[4] / 2, z) * CFrame.Angles(0, a + i * 0.4, 0),
			if i % 2 == 0 then STONE_DARK else STONE
		)
	end
end

-- ===== Les tambours tombes dans la fosse =================================
-- La fosse est le dernier cercle de la zone : sans rien dedans, la fin de
-- manche est un echange a decouvert ou le plus gros tas de PV gagne. Quatre
-- tambours bas cassent ca sans rendre la fosse aveugle.
for i = 1, 4 do
	local a = (i - 1) / 4 * math.pi * 2 + math.pi / 4
	local x, z = math.sin(a) * 15, math.cos(a) * 15
	local drum = pillar(string.format("Tambour%d", i), cover, 2.6, 5.4, x, z, -PIT_DEPTH, STONE)
	-- Couche, pas debout : un tambour tombe se lit tout de suite comme une
	-- ruine, et il fait une couverture a hauteur de poitrine.
	drum.CFrame = CFrame.new(x, -PIT_DEPTH + 2.6, z) * CFrame.Angles(0, a + math.pi / 2, 0)
	drum.Size = Vector3.new(5.4, 5.2, 5.2)
end

-- ===== Les deux balcons lateraux =========================================
-- LA POSITION DE FORCE EST A EGALE DISTANCE DES DEUX DEPARTS, et c'est tout
-- le point : elle est sur l'axe PERPENDICULAIRE a celui des camps, donc
-- personne ne l'a « sur son chemin ». On s'y rend, on ne s'y trouve pas.
-- Deux rampes par balcon, une de chaque cote : avec une seule, un joueur le
-- verrouille, et une hauteur imprenable n'est plus une position mais une
-- punition.
for _, side in { -1, 1 } do
	local z = side * 54
	part(
		string.format("Balcon%d", side),
		decor,
		Vector3.new(38, SIDE_HEIGHT, 16),
		CFrame.new(0, SIDE_HEIGHT / 2, z),
		STONE_WARM
	)
	-- Le parapet, cote fosse, et ses creneaux : on tire PAR les creneaux, donc
	-- la hauteur protege sans rendre aveugle.
	for i = -2, 2 do
		part(
			string.format("Creneau%d_%d", side, i),
			cover,
			Vector3.new(6, 3.4, 1.8),
			CFrame.new(i * 8, SIDE_HEIGHT + 1.7, z - side * 7.2),
			STONE
		)
	end
	for _, dx in { -1, 1 } do
		local rise = SIDE_HEIGHT
		local run = 13
		local len = math.sqrt(run * run + rise * rise) + 1.5
		part(
			string.format("Rampe%d_%d", side, dx),
			decor,
			Vector3.new(len, 1.4, 11),
			CFrame.new(dx * (19 + run / 2), rise / 2, z)
				* CFrame.Angles(0, 0, -dx * math.atan2(rise, run)),
			STONE_WARM
		)
		-- Un garde-corps d'un seul cote de la rampe : il la fait lire comme un
		-- escalier plutot que comme une planche, et il coupe une ligne de vue
		-- qui prenait la rampe en enfilade depuis l'autre balcon.
		part(
			string.format("Garde%d_%d", side, dx),
			decor,
			Vector3.new(len, 2.6, 1),
			CFrame.new(dx * (19 + run / 2), rise / 2 + 1.8, z + side * 5)
				* CFrame.Angles(0, 0, -dx * math.atan2(rise, run)),
			STONE_DARK
		)
	end
	-- Deux blocs tombes au pied de chaque balcon : sans eux on aborde la rampe
	-- a decouvert, et la rampe est le seul endroit ou on ne peut pas esquiver.
	for _, dx in { -1, 1 } do
		part(
			string.format("Bloc%d_%d", side, dx),
			cover,
			Vector3.new(7, 4.5, 5),
			CFrame.new(dx * 36, 2.25, z - side * 10) * CFrame.Angles(0, dx * 0.3, 0),
			STONE_DARK
		)
	end
end

-- ===== Les deux terrasses de depart ======================================
local SPAWNS = {}
for _, side in { -1, 1 } do
	local team = if side < 0 then "A" else "B"
	local tint = if side < 0 then COLOR_A else COLOR_B
	local x = side * SPAWN_DISTANCE

	part(
		"Terrasse" .. team,
		decor,
		Vector3.new(26, TERRACE_HEIGHT, 34),
		CFrame.new(x, TERRACE_HEIGHT / 2, 0),
		STONE_WARM
	)
	part(
		"Bordure" .. team,
		decor,
		Vector3.new(2, 1.2, 34),
		CFrame.new(x - side * 13, TERRACE_HEIGHT + 0.6, 0),
		STONE
	)

	-- DEUX ESCALIERS, PAS UN. Un camp qui n'a qu'une sortie se fait enfermer
	-- par une seule personne postee devant : la manche se gagne alors en
	-- campant un escalier, ce qui n'est pas un duel. Deux sorties ecartees de
	-- dix-huit studs ne se tiennent pas a une personne.
	for _, dz in { -1, 1 } do
		for s = 1, TERRACE_HEIGHT do
			part(
				string.format("Degre%s%d_%d", team, dz, s),
				decor,
				Vector3.new(2.4, 1, 12),
				CFrame.new(x - side * (13 + s * 2.2), TERRACE_HEIGHT - s + 0.5, dz * 9),
				STONE_WARM
			)
		end
	end
	-- Entre les deux, un eperon de pierre : il separe les sorties pour de bon,
	-- et il couvre celui qui attend son tour de descendre.
	part(
		"Eperon" .. team,
		cover,
		Vector3.new(16, 5, 6),
		CFrame.new(x - side * 20, 2.5, 0),
		STONE_DARK
	)

	-- DEUX MURS QUI COUPENT LA VUE DEPUIS LE DEPART. Sans eux on tire sur un
	-- coequipier en train de relever, depuis sa propre terrasse, sans jamais
	-- entrer dans la map.
	for _, dz in { -1, 1 } do
		part(
			string.format("MurBas%s%d", team, dz),
			cover,
			Vector3.new(3, 4, 16),
			CFrame.new(x - side * 26, 2, dz * 13),
			STONE_DARK
		)
	end

	-- L'arche de sortie, derriere le depart : elle ferme la terrasse et elle
	-- dit de quel cote on est.
	for _, dz in { -1, 1 } do
		part(
			string.format("Pied%s%d", team, dz),
			decor,
			Vector3.new(4, 20, 4),
			CFrame.new(x + side * 10, 10 + TERRACE_HEIGHT, dz * 13),
			STONE
		)
	end
	part(
		"Linteau" .. team,
		decor,
		Vector3.new(4, 4, 30),
		CFrame.new(x + side * 10, 22 + TERRACE_HEIGHT, 0),
		STONE
	)
	part(
		"Fanion" .. team,
		decor,
		Vector3.new(0.6, 6, 22),
		CFrame.new(x + side * 8, 16 + TERRACE_HEIGHT, 0),
		tint,
		Enum.Material.Fabric
	)

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
		marker.Position = Vector3.new(x, TERRACE_HEIGHT + 3, (i - 3) * 7)
		marker.Parent = folder
	end
	table.insert(SPAWNS, folder)
end

-- ===== La facade : deux etages d'arcades =================================
-- C'est elle qui fait un colisee plutot qu'un rond de sable. Quarante-huit
-- piles, leurs arcs, et une corniche qui court tout autour.
local PIERS = 48
for i = 1, PIERS do
	local a = (i - 1) / PIERS * math.pi * 2
	local x, z = math.sin(a) * (FLOOR_RADIUS + 4), math.cos(a) * (FLOOR_RADIUS + 4)
	part(
		string.format("Pile%d", i),
		decor,
		Vector3.new(5, 24, 8),
		CFrame.new(x, 12, z) * CFrame.Angles(0, a, 0),
		STONE
	)
	-- L'arc, en deux claveaux inclines : deux blocs suffisent a faire lire une
	-- arcade de loin, et une vraie voussure couterait cent parts par arche.
	local b = a + math.pi / PIERS
	local bx, bz = math.sin(b) * (FLOOR_RADIUS + 4), math.cos(b) * (FLOOR_RADIUS + 4)
	for _, tilt in { -1, 1 } do
		part(
			string.format("Claveau%d_%d", i, tilt),
			decor,
			Vector3.new(4, 9, 6),
			CFrame.new(
				bx - math.sin(b + tilt * math.pi / 2) * 3,
				19,
				bz - math.cos(b + tilt * math.pi / 2) * 3
			) * CFrame.Angles(0, b, tilt * math.rad(32)),
			STONE_DARK
		)
	end
	part(
		string.format("Etage%d", i),
		decor,
		Vector3.new(5, 14, 7),
		CFrame.new(x, 31, z) * CFrame.Angles(0, a, 0),
		STONE_WARM
	)
end
annulus("Corniche", decor, FLOOR_RADIUS - 1, FLOOR_RADIUS + 10, 25, 2, 72, STONE_DARK)
annulus("Attique", decor, FLOOR_RADIUS - 1, FLOOR_RADIUS + 10, 39, 2.4, 72, STONE)

-- Le mur de podium : c'est lui qu'on ne franchit pas, et il est a
-- l'INTERIEUR des piles, pour qu'on ne puisse pas se coincer dans la facade.
annulus("Podium", decor, FLOOR_RADIUS - 2, FLOOR_RADIUS, 9, 9, 72, STONE_WARM)

-- ===== Le desert autour ==================================================
-- SANS LUI LE COLISEE FLOTTE DANS LE CIEL. On ne joue jamais dessus, mais on
-- le voit par chaque arcade et par-dessus le mur : c'est lui qui dit que le
-- batiment est pose sur la terre. Un sol lointain coute six parts.
disc("Desert", decor, 600, 10, -8, Color3.fromRGB(198, 168, 114), Enum.Material.Sand)
annulus("Socle", decor, FLOOR_RADIUS - 2, FLOOR_RADIUS + 12, 0, 9, 72, STONE_WARM)
annulus("Assise", decor, FLOOR_RADIUS + 2, FLOOR_RADIUS + 18, -6, 3, 72, STONE_DARK)

-- DES DOMES, PAS DES DUNES. Les trois premieres etaient des spheres enfoncees
-- a moitie : ca donne une calotte aussi haute que large, c'est-a-dire une
-- bulle posee sur le sable. Une dune est BASSE ET LARGE -- donc une sphere
-- beaucoup plus grosse, enfoncee presque entierement, dont on ne garde qu'un
-- huitieme. Et il en faut plus de trois : trois bosses sur un horizon vide se
-- comptent, sept se lisent comme un relief.
--
-- A savoir : un `Ball` ne garde que le PLUS PETIT de ses trois cotes, donc
-- une dune aplatie ne s'ecrit pas, elle s'enfonce.
for i, d in
	{
		{ 260, 40, 150 },
		{ -200, 150, 220 },
		{ 60, -280, 190 },
		{ -310, -120, 170 },
		{ 180, 300, 240 },
		{ -90, 330, 130 },
		{ 340, -210, 200 },
	}
do
	local r = d[3]
	local dune = part(
		string.format("Dune%d", i),
		decor,
		Vector3.new(r * 2, r * 2, r * 2),
		CFrame.new(d[1], -r * 0.88, d[2]),
		if i % 2 == 0 then Color3.fromRGB(206, 176, 122) else Color3.fromRGB(190, 160, 106),
		Enum.Material.Sand
	)
	dune.Shape = Enum.PartType.Ball
	dune.CanCollide = false
end

-- ===== Le contrat ========================================================
local centre = Instance.new("Part")
centre.Name = "ZoneCenter"
centre.Size = Vector3.new(4, 1, 4)
centre.Position = Vector3.new(0, -PIT_DEPTH + 1, 0)
centre.Anchored = true
centre.CanCollide = false
centre.Transparency = 1
centre.Parent = map

local bounds = Instance.new("Part")
bounds.Name = "MapBounds"
bounds.Size = Vector3.new(BOUNDS_WIDTH, 1, BOUNDS_WIDTH)
bounds.Position = Vector3.new(0, -20, 0)
bounds.Anchored = true
bounds.CanCollide = false
bounds.Transparency = 1
bounds.Parent = map

map.Parent = Workspace

-- ===== La lumiere ========================================================
-- L'AMBIANCE EST UN REGLAGE DE PLACE, donc elle appartient a la map qui
-- tourne : chaque script de map pose la sienne, et lancer un autre script la
-- remplace entierement. Sans ca les trois maps partageraient un seul ciel.
-- LES BARRES D'OMBRE DES PILIERS SONT L'IMAGE MEME D'UN COLISEE, et a 15h30
-- il n'y en avait aucune : le soleil etait mesure a 37 degres au-dessus de
-- l'horizon, donc chaque pilier posait son ombre a son pied. A 17h il rase,
-- et les quarante-huit piliers de l'arcade rayent le sol de l'arene.
Lighting.ClockTime = 17
Lighting.GeographicLatitude = 20
Lighting.Brightness = 3.1
Lighting.Ambient = Color3.fromRGB(78, 68, 58)
Lighting.OutdoorAmbient = Color3.fromRGB(134, 120, 98)
Lighting.ExposureCompensation = 0.1
Lighting.FogEnd = 100000
for _, old in Lighting:GetChildren() do
	if
		old:IsA("Atmosphere")
		or old:IsA("Sky")
		or old:IsA("BloomEffect")
		or old:IsA("ColorCorrectionEffect")
	then
		old:Destroy()
	end
end
local air = Instance.new("Atmosphere")
air.Density = 0.36
air.Haze = 2.2
air.Glare = 0.4
air.Color = Color3.fromRGB(216, 196, 164)
air.Decay = Color3.fromRGB(176, 146, 110)
air.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.5
bloom.Size = 24
bloom.Threshold = 1.1
bloom.Parent = Lighting
local grade = Instance.new("ColorCorrectionEffect")
-- L'ETALONNAGE EST LE SEUL LEVIER QUI ATTEIGNE LE CIEL. Le ciel par defaut de
-- Roblox est une texture de plein jour : ni l'heure ni l'`Atmosphere` ne la
-- teintent, verifie trois fois sur le sanctuaire. Mais `ColorCorrection`
-- passe APRES le rendu, donc lui touche tout, ciel compris. Un desert a 17h
-- sous un ciel cyan ne tient pas ensemble ; une teinte chaude le repare, et
-- elle va dans le sens du sable plutot que contre lui.
grade.Saturation = 0.2
grade.Contrast = 0.1
grade.TintColor = Color3.fromRGB(255, 226, 186)
grade.Parent = Lighting

-- ===== Le ciel ==========================================================
-- LE CIEL PAR DEFAUT DE ROBLOX EST UNE TEXTURE, PAS UN DEGRADE CALCULE. Ca a
-- coute trois essais : l'heure est descendue de 11h a 6h50 et l'`Atmosphere`
-- a recu une brume chaude, et le ciel est reste exactement aussi bleu, avec
-- les memes petits nuages blancs de plein jour. Ni `ClockTime` ni
-- `Atmosphere.Color` ne teintent une image. Le soleil, lui, a bien bouge --
-- mesure a 12,7 degres au-dessus de l'horizon -- donc les ombres etaient
-- gagnees ; c'est le ciel seul qui ne suivait pas.
--
-- Le seul levier procedural qui reste, sans aller chercher un asset, est
-- `Clouds`, qui se parente au TERRAIN et pas a Lighting. Il dessine de
-- vrais nuages volumetriques, eclaires par le soleil de la scene -- donc
-- eux SUIVENT l'heure, et ils couvrent la texture.
for _, old in Workspace.Terrain:GetChildren() do
	if old:IsA("Clouds") then
		old:Destroy()
	end
end
local nuages = Instance.new("Clouds")
-- Rares et hauts : un desert a un ciel vide, et c'est ce vide qui ecrase.
-- Quelques nuages suffisent a donner une echelle au ciel sans le fermer.
nuages.Cover = 0.42
nuages.Density = 0.5
nuages.Color = Color3.fromRGB(255, 238, 214)
nuages.Parent = Workspace.Terrain

--------------------------------------------------------------------------------
-- LE RENDU
--------------------------------------------------------------------------------

-- LE PLUS GROS LEVIER DE ROBLOX EST `Lighting.Technology`, et il ne coute rien.
-- En `Legacy` ou `ShadowMap`, une lampe n'eclaire rien, le metal ne brille pas
-- et les ombres sont dures. En `Future`, chaque lumiere eclaire vraiment, les
-- surfaces repondent au ciel, et les ombres s'adoucissent avec la distance.
--
-- MAIS C'EST UNE PROPRIETE PROTEGEE : seul un script lance a la main dans la
-- barre de commande peut y toucher, et encore. Un `pcall` muet autour serait
-- le piege du chiffre cache dans un repli -- la map aurait l'air terne et
-- personne ne saurait pourquoi. Donc on essaie, on RELIT, et on le DIT.
local tech = "inconnue"
pcall(function()
	Lighting.Technology = Enum.Technology.Future
end)
pcall(function()
	tech = Lighting.Technology.Name
end)
if tech ~= "Future" then
	warn(
		string.format(
			"[Arena] Rendu en « %s » et pas « Future ». C'est le réglage qui change le "
				.. "plus l'allure du jeu, et il ne se pose pas depuis un script : "
				.. "dans Studio, Explorer → Lighting → Properties → Technology → Future. "
				.. "À faire une seule fois, ça reste avec la place.",
			tech
		)
	)
end
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.35

-- Ces deux-la decident de combien le CIEL se reflete dans les matieres. A zero
-- (le defaut de certaines places) la pierre est plate et le metal est gris.
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.55

for _, old in Lighting:GetChildren() do
	if old:IsA("SunRaysEffect") or old:IsA("DepthOfFieldEffect") then
		old:Destroy()
	end
end
local rays = Instance.new("SunRaysEffect")
rays.Intensity = 0.14
rays.Spread = 0.9
rays.Parent = Lighting

-- La profondeur de champ ne sert pas a flouter le jeu : `FarIntensity` reste
-- bas et `FocusDistance` couvre toute l'arene, donc ce qu'on combat est net et
-- seul le lointain s'adoucit. C'est ce qui separe le decor du terrain.
local dof = Instance.new("DepthOfFieldEffect")
dof.FocusDistance = 90
dof.InFocusRadius = 150
dof.NearIntensity = 0
dof.FarIntensity = 0.5
dof.Parent = Lighting

print(string.format("[Arena] Colisee construit : %d parts.", #map:GetDescendants()))
