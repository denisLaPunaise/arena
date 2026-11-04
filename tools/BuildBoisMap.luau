--!nolint
--[[
	BuildBoisMap — « Le Bois brumeux ». A coller dans la barre de commande, ou
	a charger par le pont MCP (voir CLAUDE.md, « loadstring est verrouille »).

	POURQUOI CE FICHIER EXISTE
	Les maps vivent dans Workspace, que Rojo ne touche pas, et le .rbxl n'est
	pas dans Git. Ce script est la seule sauvegarde de la map. Il detruit toute
	autre map conforme avant de construire.

	CE N'EST PAS DU CODE DE JEU : hors du projet Rojo, jamais execute en partie.

	CE QU'ELLE RACONTE
	Une foret d'automne dans le brouillard du matin : des troncs gris, des
	feuillages rouille et or tres haut, des rochers moussus, des arbres tombes,
	et au milieu une chapelle de pierre en ruine dont il ne reste que les
	murs. Construite le 4 novembre 2026, sans Josh.

	CE QU'ELLE FAIT JOUER, et c'est l'inverse exact de la Serre : ON NE VOIT
	RIEN VENIR.
	- Le brouillard ferme la vue a une quarantaine de studs. Au-dela, une
	  silhouette n'est qu'une ombre, puis plus rien.
	- Les troncs sont partout et irreguliers : pas de couloir, pas d'allee,
	  pas de ligne qu'on tient. Chaque arbre est un couvert, et chaque couvert
	  peut cacher quelqu'un.
	- C'est la map de l'EMBUSCADE. Le Cameleon et le Traqueur y sont chez eux ;
	  les armes a longue portee y valent ce que vaut la vue, c'est-a-dire peu.
	- La chapelle au centre est le seul endroit ou l'on sait d'ou l'on sera
	  attaque : quatre breches, et des murs entre elles. C'est la que la zone
	  se referme.

	LES ARBRES SONT TIRES AU SORT, MAIS TOUJOURS LES MEMES. Une graine fixe :
	la recette reconstruit la meme foret au tronc pres. Et chaque arbre a son
	jumeau tourne d'un demi-tour autour du centre, pour que les deux camps
	traversent la meme foret.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local BOUNDS = 156
local HALF = 74
local SPAWN_X = 62
local SPAWN_Y = 4
local SPAWN_SPREAD = 4
local SEED = 20261104
local CHAPEL = 11 -- demi-cote interieur de la chapelle

local GROUND = Color3.fromRGB(84, 74, 52)
local MOSS = Color3.fromRGB(78, 96, 58)
local LEAVES_FLOOR =
	{ Color3.fromRGB(150, 84, 40), Color3.fromRGB(122, 64, 36), Color3.fromRGB(170, 120, 48) }
local BARK = Color3.fromRGB(92, 86, 80)
local BARK_DARK = Color3.fromRGB(62, 56, 52)
local CROWN = {
	Color3.fromRGB(176, 82, 36),
	Color3.fromRGB(196, 132, 44),
	Color3.fromRGB(140, 56, 34),
	Color3.fromRGB(162, 150, 60),
}
local ROCK = Color3.fromRGB(112, 112, 108)
local STONE = Color3.fromRGB(150, 144, 132)
local STONE_DARK = Color3.fromRGB(104, 100, 92)
local FIRE = Color3.fromRGB(255, 150, 60)
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
map.Name = "BoisMap"
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

local function ball(name, parent, diameter, pos, color, material)
	local p = part(
		name,
		parent,
		Vector3.new(diameter, diameter, diameter),
		CFrame.new(pos),
		color,
		material
	)
	p.Shape = Enum.PartType.Ball
	return p
end

local rng = Random.new(SEED)

--------------------------------------------------------------------------------
-- LE SOL
--------------------------------------------------------------------------------

part(
	"Sol",
	decor,
	Vector3.new(BOUNDS, 2, BOUNDS),
	CFrame.new(0, -1, 0),
	GROUND,
	Enum.Material.Ground
)
-- Des nappes de feuilles mortes et de mousse : un sol de foret n'est jamais
-- d'une seule couleur, et ces taches sont ce qui donne l'echelle quand le
-- brouillard a mange le reste.
for i = 1, 70 do
	local x, z = rng:NextNumber(-70, 70), rng:NextNumber(-70, 70)
	local w, d = rng:NextNumber(6, 16), rng:NextNumber(6, 16)
	local isMoss = i % 4 == 0
	local color = if isMoss then MOSS else LEAVES_FLOOR[(i % #LEAVES_FLOOR) + 1]
	for _, s in { 1, -1 } do
		ghost(
			part(
				"Feuilles",
				decor,
				Vector3.new(w, 0.1, d),
				CFrame.new(s * x, 0.02 + (i % 5) * 0.01, s * z)
					* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				color,
				if isMoss then Enum.Material.Grass else Enum.Material.LeafyGrass
			)
		)
	end
end

--------------------------------------------------------------------------------
-- LES ZONES INTERDITES AUX ARBRES
--------------------------------------------------------------------------------

-- La clairiere de chaque camp, la chapelle et son parvis, et le bord : un
-- tronc dans un point de depart ou dans une breche de la chapelle est un
-- defaut qu'aucune capture ne montre.
local function forbidden(x, z)
	if math.abs(x) > HALF - 3 or math.abs(z) > HALF - 3 then
		return true
	end
	if math.abs(x) > SPAWN_X - 12 and math.abs(z) < 16 then
		return true
	end
	if math.abs(x) < CHAPEL + 8 and math.abs(z) < CHAPEL + 8 then
		return true
	end
	return false
end

local placed = {}
local function farEnough(x, z, gap)
	for _, p in placed do
		if (p.X - x) ^ 2 + (p.Z - z) ^ 2 < gap * gap then
			return false
		end
	end
	return true
end

--------------------------------------------------------------------------------
-- LES ARBRES
--------------------------------------------------------------------------------

-- UN ARBRE D'AUTOMNE. Un tronc droit et gris (la seule chose qu'on voit dans
-- le brouillard, donc la seule qui doit avoir de la collision), deux ou trois
-- branches, et une couronne HAUTE, au-dessus de la tete et de la vue : les
-- couronnes font le ciel de la map, pas ses murs. Chaque couronne est une
-- grappe de petites boules decalees et de couleurs voisines — le piege du
-- Sanctuaire : trois grosses spheres empilees redonnent une sucette.
local function tree(name, x, z, s)
	local height = rng:NextNumber(20, 30)
	local girth = rng:NextNumber(1.6, 2.8)
	local lean = rng:NextNumber(-0.05, 0.05)
	local turn = rng:NextNumber(0, math.pi * 2)
	-- Tout ce qui est tire au sort l'est AVANT les deux jumeaux : un tirage
	-- dans la boucle donnerait a chaque jumeau sa propre valeur, et la
	-- symetrie casserait en silence.
	local r = rng:NextNumber(5, 8)
	for _, sign in { 1, -1 } do
		local px, pz = sign * x, sign * z
		local base = CFrame.new(px, 0, pz)
			* CFrame.Angles(lean, turn + (if sign < 0 then math.pi else 0), 0)
		cylinder(
			name .. "Tronc",
			cover,
			height,
			girth,
			base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			BARK,
			Enum.Material.Wood
		)
		-- Pas de racines : trois coins au pied se lisaient comme des briques
		-- noires semees autour du tronc. Vu a l'ecran, retire.
		local top = (base * CFrame.new(0, height, 0)).Position
		local tint = CROWN[(math.floor(x * 7 + z * 3) % #CROWN) + 1]
		for k = 1, 9 do
			local dx = math.cos(k * 2.4) * r * 0.55
			local dz = math.sin(k * 2.4) * r * 0.55
			local dy = (k % 3) * 1.2 - 1
			ghost(
				ball(
					name .. "Feuillage",
					decor,
					r * (0.65 + (k % 4) * 0.08),
					top + Vector3.new(sign * dx, dy, sign * dz),
					if k % 3 == 0 then CROWN[((k + math.floor(x)) % #CROWN) + 1] else tint,
					Enum.Material.LeafyGrass
				)
			).CastShadow =
				true
		end
		-- Deux branches nues, qui sortent sous la couronne.
		for k = 0, 1 do
			local a = turn + k * math.pi * 0.9
			ghost(
				cylinder(
					name .. "Branche",
					decor,
					r * 0.9,
					girth * 0.3,
					CFrame.new(top - Vector3.new(0, 3 + k * 2, 0))
						* CFrame.Angles(0, a, 0)
						* CFrame.Angles(0, 0, math.rad(25))
						* CFrame.new(r * 0.4, 0, 0),
					BARK_DARK,
					Enum.Material.Wood
				)
			)
		end
	end
end

-- LA DENSITE SE CALCULE, ELLE NE SE DEVINE PAS. La premiere foret avait 68
-- troncs et une vue mediane de 160 studs : un rayon a hauteur d'yeux passe en
-- moyenne 1 / (densite x diametre) avant de toucher un tronc, soit 130 studs
-- pour cette densite-la. Pour une vue mediane d'une quarantaine de studs il
-- en faut a peu pres le triple, d'ou 64 paires de grands arbres a huit studs
-- d'ecart au moins, et les jeunes arbres plus bas.
local trees = 0
local attempts = 0
while trees < 64 and attempts < 6000 do
	attempts += 1
	local x, z = rng:NextNumber(-70, 70), rng:NextNumber(-70, 70)
	if
		forbidden(x, z)
		or not farEnough(x, z, 8)
		or not farEnough(-x, -z, 8)
		or (x * x + z * z) < 64
	then
		continue
	end
	table.insert(placed, Vector3.new(x, 0, z))
	table.insert(placed, Vector3.new(-x, 0, -z))
	trees += 1
	tree(string.format("Arbre%d", trees), x, z, 1)
end

-- LES JEUNES ARBRES : un tronc mince et clair, trois touffes de feuilles a
-- hauteur de tete. Ils remplissent les trous entre les grands sans fermer le
-- ciel, et ils sont ce qui fait qu'on ne tient jamais une ligne.
local saplings = 0
attempts = 0
while saplings < 60 and attempts < 6000 do
	attempts += 1
	local x, z = rng:NextNumber(-70, 70), rng:NextNumber(-70, 70)
	if forbidden(x, z) or not farEnough(x, z, 4.5) or not farEnough(-x, -z, 4.5) then
		continue
	end
	table.insert(placed, Vector3.new(x, 0, z))
	table.insert(placed, Vector3.new(-x, 0, -z))
	saplings += 1
	local height = rng:NextNumber(9, 14)
	local tint = CROWN[(saplings % #CROWN) + 1]
	for _, sign in { 1, -1 } do
		local px, pz = sign * x, sign * z
		cylinder(
			"JeuneTronc",
			cover,
			height,
			0.9,
			CFrame.new(px, height / 2, pz) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(176, 170, 156),
			Enum.Material.Wood
		)
		for k = 1, 3 do
			ghost(
				ball(
					"JeuneFeuillage",
					decor,
					3.4 - k * 0.4,
					Vector3.new(
						px + sign * math.cos(k * 2.1) * 1.2,
						height - 1 + k * 0.9,
						pz + sign * math.sin(k * 2.1) * 1.2
					),
					tint,
					Enum.Material.LeafyGrass
				)
			)
		end
	end
end

--------------------------------------------------------------------------------
-- LES ROCHERS ET LES ARBRES TOMBES
--------------------------------------------------------------------------------

-- Des couverts BAS, entre les troncs. Un rocher moussu a hauteur de taille,
-- un tronc couche a hauteur de genou : on tire par-dessus, on s'accroupit
-- derriere — sauf que le jeu n'a pas d'accroupi, donc ils couvrent le corps et
-- laissent la tete. C'est voulu : la foret couvre deja la tete.
local rocks = 0
attempts = 0
while rocks < 14 and attempts < 2000 do
	attempts += 1
	local x, z = rng:NextNumber(-68, 68), rng:NextNumber(-68, 68)
	if forbidden(x, z) or not farEnough(x, z, 7) or not farEnough(-x, -z, 7) then
		continue
	end
	table.insert(placed, Vector3.new(x, 0, z))
	table.insert(placed, Vector3.new(-x, 0, -z))
	rocks += 1
	local size = Vector3.new(rng:NextNumber(4, 7), rng:NextNumber(2.6, 4.2), rng:NextNumber(3.5, 6))
	local spin = rng:NextNumber(0, math.pi)
	local isLog = rocks % 3 == 0
	for _, sign in { 1, -1 } do
		local cf = CFrame.new(sign * x, 0, sign * z)
			* CFrame.Angles(0, spin + (if sign < 0 then math.pi else 0), 0)
		if isLog then
			local log = cylinder(
				"Grume",
				cover,
				size.X * 2,
				2.4,
				cf * CFrame.new(0, 1.1, 0),
				BARK,
				Enum.Material.Wood
			)
			local _ = log
			ghost(
				part(
					"GrumeMousse",
					decor,
					Vector3.new(size.X * 1.6, 0.3, 1.6),
					cf * CFrame.new(0, 2.3, 0),
					MOSS,
					Enum.Material.Grass
				)
			)
		else
			part(
				"Rocher",
				cover,
				size,
				cf * CFrame.new(0, size.Y / 2 - 0.3, 0) * CFrame.Angles(0.1, 0, 0.12),
				ROCK,
				Enum.Material.Rock
			)
			part(
				"RocherBis",
				cover,
				size * 0.6,
				cf
					* CFrame.new(size.X * 0.4, size.Y * 0.3 - 0.3, size.Z * 0.2)
					* CFrame.Angles(-0.2, 0.5, 0.1),
				ROCK,
				Enum.Material.Rock
			)
			ghost(
				part(
					"RocherMousse",
					decor,
					Vector3.new(size.X * 0.8, 0.3, size.Z * 0.7),
					cf * CFrame.new(0, size.Y - 0.25, 0) * CFrame.Angles(0.1, 0, 0.12),
					MOSS,
					Enum.Material.Grass
				)
			)
		end
	end
end

--------------------------------------------------------------------------------
-- LA CHAPELLE
--------------------------------------------------------------------------------

-- QUATRE MURS ET QUATRE BRECHES. Les murs sont plus hauts que l'oeil : de
-- l'interieur on sait exactement d'ou l'on peut etre vu. LES BRECHES NE SONT
-- PAS AU MILIEU : au milieu, celles des murs est et ouest etaient sur l'axe
-- des camps, et cinq lignes droites d'un camp a l'autre traversaient la
-- chapelle de part en part. Decalees de quatre studs, toujours du meme cote
-- dans le repere du mur, elles ne s'alignent plus jamais deux a deux. C'est le dernier cercle, et c'est le seul endroit
-- calme de la map — ce qui le rend dangereux.
do
	local thick = 1.6
	local gap = 6
	local shift = 4
	for side = 0, 3 do
		local rot = CFrame.Angles(0, side * math.pi / 2, 0)
		for _, dir in { -1, 1 } do
			-- Un pan de mur de part et d'autre de la breche. Les hauteurs
			-- varient d'un pan a l'autre : une ruine dont tous les murs ont la
			-- meme hauteur est un enclos.
			local h = 7 + ((side + (if dir > 0 then 1 else 0)) % 3) * 2.2
			local edge = shift + dir * gap / 2 -- bord de la breche
			local far = dir * CHAPEL -- coin du mur
			local seg = math.abs(far - edge)
			local center = (edge + far) / 2
			part(
				"Mur",
				cover,
				Vector3.new(seg, h, thick),
				rot * CFrame.new(center, h / 2, CHAPEL + thick / 2),
				STONE,
				Enum.Material.Cobblestone
			)
			-- Le sommet casse : un bloc de travers.
			part(
				"MurCasse",
				decor,
				Vector3.new(seg * 0.5, 1.2, thick + 0.2),
				rot
					* CFrame.new(center + dir * seg * 0.2, h + 0.4, CHAPEL + thick / 2)
					* CFrame.Angles(0, 0, dir * 0.25),
				STONE_DARK,
				Enum.Material.Cobblestone
			)
			-- Des pierres tombees au pied, dehors.
			part(
				"Eboulis",
				cover,
				Vector3.new(2.4, 1.6, 2),
				rot
					* CFrame.new(center + dir * 2, 0.8, CHAPEL + 3.2)
					* CFrame.Angles(0.2, dir * 0.6, 0.1),
				STONE_DARK,
				Enum.Material.Cobblestone
			)
		end
		-- Les contreforts aux angles.
		part(
			"Contrefort",
			cover,
			Vector3.new(2.6, 12, 2.6),
			rot * CFrame.new(CHAPEL + 0.8, 6, CHAPEL + 0.8),
			STONE_DARK,
			Enum.Material.Cobblestone
		)
	end
	-- Le dallage de la nef, mange de mousse.
	part(
		"Dallage",
		decor,
		Vector3.new(2 * CHAPEL, 0.2, 2 * CHAPEL),
		CFrame.new(0, 0.1, 0),
		STONE_DARK,
		Enum.Material.Slate
	)
	-- L'autel renverse et deux bancs de pierre : de quoi se couvrir a
	-- l'interieur, sans boucher les breches.
	part(
		"Autel",
		cover,
		Vector3.new(4, 3.4, 2.2),
		CFrame.new(0, 1.7, 0) * CFrame.Angles(0, 0.3, 0.06),
		STONE,
		Enum.Material.Limestone
	)
	for _, s in { 1, -1 } do
		part(
			"Banc",
			cover,
			Vector3.new(1.6, 2.6, 5),
			CFrame.new(s * 6, 1.3, s * 5) * CFrame.Angles(0, s * 0.2, 0),
			STONE_DARK,
			Enum.Material.Cobblestone
		)
	end
	-- Une lumiere chaude dans la nef, la seule de la foret avec les feux de
	-- camp : elle dit ou est le centre quand le brouillard cache tout.
	local glow = ghost(ball("Lueur", decor, 0.8, Vector3.new(0, 4, 0), FIRE, Enum.Material.Neon))
	local light = Instance.new("PointLight")
	light.Color = FIRE
	light.Range = 26
	light.Brightness = 1.2
	light.Shadows = true
	light.Parent = glow
	-- Un cierge sur l'autel pour porter cette lueur.
	cylinder(
		"Cierge",
		decor,
		1.2,
		0.5,
		CFrame.new(0, 3.9, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(232, 224, 200),
		Enum.Material.SmoothPlastic
	)
end

--------------------------------------------------------------------------------
-- LES CAMPS
--------------------------------------------------------------------------------

for _, s in { 1, -1 } do
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
	-- Le feu de camp, derriere les departs : la seule lumiere vive du camp,
	-- et le repere de chacun dans le brouillard.
	local fx = s * (SPAWN_X + 6)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		cylinder(
			"Pierre",
			decor,
			0.6,
			0.9,
			CFrame.new(fx + math.cos(a) * 1.6, 0.3, math.sin(a) * 1.6)
				* CFrame.Angles(0, 0, math.pi / 2),
			ROCK,
			Enum.Material.Rock
		)
	end
	local flame = ghost(
		part(
			"Feu",
			decor,
			Vector3.new(1.2, 1.6, 1.2),
			CFrame.new(fx, 0.9, 0) * CFrame.Angles(0, 0.6, 0),
			FIRE,
			Enum.Material.Neon
		)
	)
	local light = Instance.new("PointLight")
	light.Color = FIRE
	light.Range = 24
	light.Brightness = 1.4
	light.Shadows = true
	light.Parent = flame
	-- LA PIERRE LEVEE au bord de la clairiere. Deux lignes droites d'un camp a
	-- l'autre passaient encore entre les troncs, toutes les deux a z = -7 en
	-- arrivant chez B (et, par la symetrie, a +7 chez A). Un menhir plus haut
	-- que l'oeil les coupe, et une foret avec une pierre levee a sa lisiere
	-- se lit comme un lieu.
	part(
		"Menhir" .. team,
		cover,
		Vector3.new(2.8, 9.5, 2.2),
		CFrame.new(s * 48, 4.4, -s * 7) * CFrame.Angles(0.05, s * 0.4, -0.04),
		ROCK,
		Enum.Material.Rock
	)
	ghost(
		part(
			"MenhirMousse" .. team,
			decor,
			Vector3.new(2.9, 1.4, 2.3),
			CFrame.new(s * 48, 0.6, -s * 7) * CFrame.Angles(0, s * 0.4, 0),
			MOSS,
			Enum.Material.Grass
		)
	)

	-- Une banniere sur un piquet, haute, dans la couleur du camp.
	ghost(
		cylinder(
			"Piquet",
			decor,
			14,
			0.4,
			CFrame.new(fx + s * 3, 7, 9) * CFrame.Angles(0, 0, math.pi / 2),
			BARK_DARK,
			Enum.Material.Wood
		)
	)
	ghost(
		part(
			"Banniere" .. team,
			decor,
			Vector3.new(0.2, 4, 3),
			CFrame.new(fx + s * 3, 12, 10.6),
			tint,
			Enum.Material.Fabric
		)
	)
end

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
-- L'ECLAIRAGE : LE BROUILLARD
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

Lighting.ClockTime = 12
Lighting.GeographicLatitude = -50
Lighting.Brightness = 1.6
Lighting.Ambient = Color3.fromRGB(86, 86, 84)
Lighting.OutdoorAmbient = Color3.fromRGB(138, 136, 128)
Lighting.ColorShift_Top = Color3.fromRGB(230, 214, 190)
Lighting.ColorShift_Bottom = Color3.fromRGB(60, 56, 50)
Lighting.ExposureCompensation = 0.15
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.6
Lighting.EnvironmentDiffuseScale = 0.4
Lighting.EnvironmentSpecularScale = 0.3

local clouds = Instance.new("Clouds")
clouds.Cover = 0.85
clouds.Density = 0.6
clouds.Color = Color3.fromRGB(214, 212, 206)
clouds.Parent = Workspace.Terrain

-- LE BROUILLARD EST LE SUJET, ET L'ATMOSPHERE DE ROBLOX NE SAIT PAS LE FAIRE.
-- Premier essai a `Atmosphere.Density = 0.62` : a l'ecran, la chapelle etait
-- nette a quarante studs. L'`Atmosphere` epaissit sur des CENTAINES de studs,
-- c'est un voile d'horizon. Un brouillard qui ferme la vue a quarante studs
-- est l'ancien brouillard de `Lighting` (`FogStart`, `FogEnd`), et il ne
-- s'applique QUE s'il n'y a aucune `Atmosphere` — c'est pour ca qu'il n'y en
-- a pas ici, et que les autres recettes la detruisent toutes.
--
-- A REGLER EN JOUANT : `FogEnd` decide de toute la map, et une capture ne dit
-- pas si un duel y est tendu ou simplement aveugle.
Lighting.FogColor = Color3.fromRGB(196, 192, 182)
Lighting.FogStart = 12
Lighting.FogEnd = 85

local grade = Instance.new("ColorCorrectionEffect")
grade.Saturation = -0.05
grade.Contrast = 0.08
grade.TintColor = Color3.fromRGB(255, 248, 236)
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
print(
	string.format(
		"  %d paires d'arbres, %d paires de rochers et de grumes (graine %d).",
		trees,
		rocks,
		SEED
	)
)

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

-- LA PROMESSE DE CETTE MAP : pas de couloir. Depuis une grille de points, la
-- vue mediane avant le premier tronc ou rocher, a hauteur d'yeux. Le
-- brouillard ferme la vue au-dela ; la geometrie doit la fermer aussi souvent,
-- sinon le brouillard porte seul toute la map et un joueur qui baisse les
-- reglages graphiques voit tout.
do
	local lengths = {}
	for gx = -60, 60, 20 do
		for gz = -60, 60, 20 do
			if math.abs(gx) < 16 and math.abs(gz) < 16 then
				continue
			end
			local origin = Vector3.new(gx, 0.5 + EYE, gz)
			for step = 0, 7 do
				local angle = step / 8 * math.pi * 2
				local hit = Workspace:Raycast(
					origin,
					Vector3.new(math.cos(angle), 0, math.sin(angle)) * 160,
					probe
				)
				table.insert(lengths, if hit then hit.Distance else 160)
			end
		end
	end
	table.sort(lengths)
	local median = lengths[math.floor(#lengths / 2)]
	local long = 0
	for _, l in lengths do
		if l > 80 then
			long += 1
		end
	end
	print(
		string.format(
			"  Vue mediane avant un obstacle : %.0f studs ; %d visees sur %d portent au-dela de 80.",
			median,
			long,
			#lengths
		)
	)
	if median > 45 then
		alarms += 1
		warn("[Arena]   La foret est trop claire : sans le brouillard, on y verrait loin.")
	end
end

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
	print(
		string.format(
			"  Soleil a %.1f degres ; ombre aux departs : %d et %d sur 5.",
			math.deg(math.asin(sun.Y)),
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
		"[Arena] Bois construit : %d parts. %s",
		count,
		if alarms == 0 then "Rien a signaler." else alarms .. " point(s) a regarder."
	)
)
