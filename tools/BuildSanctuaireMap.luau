--!nolint
--[[
	BuildSanctuaireMap — « Le Sanctuaire noye ». Barre de commande de Studio.

	POURQUOI CE FICHIER EXISTE
	Les maps vivent dans Workspace, que Rojo ne touche pas, et le .rbxl n'est
	pas dans Git. Ce script est la seule sauvegarde de la map. Il detruit les
	trois autres avant de construire : `MapService` prend la PREMIERE map
	conforme de Workspace, donc en laisser deux serait un tirage au sort.

	CE N'EST PAS DU CODE DE JEU : hors du projet Rojo, jamais execute en
	partie, pas verifie par Selene ni StyLua.

	CE QU'ELLE RACONTE
	Un temple de jungle a moitie noye, sous une pluie fine. Pierre verte de
	mousse, eau peu profonde, racines, brume. Lumiere plate et verte : ni le
	soleil du colisee, ni la nuit du cargo.

	CE QU'ELLE FAIT JOUER
	C'est une map en DIAGONALE, et c'est sa difference : les deux camps sont
	a deux coins opposes, pas face a face. On n'avance donc pas « tout droit
	vers l'ennemi », on choisit un cote.
	- L'AUTEL, au milieu, trois gradins et dix studs de haut. Il voit tout,
	  et il est vu de partout : c'est une position qu'on prend pour un moment,
	  pas une ou l'on s'installe. Quatre escaliers y montent, un par face.
	- LE DOUVE d'eau qui l'entoure, franchie par quatre chaussees. L'eau ne
	  ralentit personne — c'est du decor — mais elle dessine le dernier
	  cercle de la zone, qu'on apprend ainsi sans le lire.
	- LES DEUX TOURS en ruine, aux deux coins NEUTRES. Elles sont a egale
	  distance des deux camps, elles ont une rampe chacune, et elles tiennent
	  les deux diagonales que l'autel ne voit pas.

	LA TAILLE
	La dalle fait 150 sur 150 studs. MapBounds est un carre de 165, donc la
	zone demarre a 82 de rayon : les departs sont a 73 du centre, donc dedans
	des la premiere seconde, et les quatre coins sont mordus — c'est voulu,
	les coins sont du decor.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local PLAZA = 150
local BOUNDS_WIDTH = 165
local SPAWN_XZ = 52
local ALTAR_BASE = 24
local ALTAR_TOP = 10
local MOAT_INNER = 21
local MOAT_OUTER = 31

local MOSS = Color3.fromRGB(96, 112, 82)
local MOSS_DARK = Color3.fromRGB(64, 76, 58)
local LIME = Color3.fromRGB(152, 158, 134)
local LIME_DARK = Color3.fromRGB(112, 118, 98)
local WATER = Color3.fromRGB(62, 118, 110)
local GOLD = Color3.fromRGB(184, 152, 72)
local LEAF = Color3.fromRGB(48, 92, 50)
local LEAF_DARK = Color3.fromRGB(34, 68, 40)
local BARK = Color3.fromRGB(72, 58, 44)
local COLOR_A = Color3.fromRGB(70, 130, 230)
local COLOR_B = Color3.fromRGB(230, 80, 70)

for _, name in { "ArenaMap", "ColiseeMap", "CargoMap", "SanctuaireMap" } do
	local old = Workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
for _, name in { "Baseplate", "SpawnLocation" } do
	local old = Workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

local map = Instance.new("Folder")
map.Name = "SanctuaireMap"
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
	p.Color = color or MOSS
	p.Material = material or Enum.Material.Slate
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function pillar(name, parent, radius, height, x, z, y, color, material, tilt)
	local p = part(
		name,
		parent,
		Vector3.new(height, radius * 2, radius * 2),
		CFrame.new(x, y + height / 2, z) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(tilt or 0, 0, 0),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- ===== Le sol ===========================================================
part("Jungle", decor, Vector3.new(900, 8, 900), CFrame.new(0, -5, 0), LEAF_DARK, Enum.Material.Grass)
part("Dalle", decor, Vector3.new(PLAZA, 3, PLAZA), CFrame.new(0, -1.5, 0), MOSS, Enum.Material.Slate)

-- Les joints de la dalle : sans eux, cent cinquante studs de pierre unie ne
-- disent rien de la distance, et on ne sait plus ou on court.
for i = -4, 4 do
	if i ~= 0 then
		part(string.format("JointX%d", i), decor, Vector3.new(PLAZA, 0.14, 0.8), CFrame.new(0, 0.07, i * 16), MOSS_DARK).CanCollide = false
		part(string.format("JointZ%d", i), decor, Vector3.new(0.8, 0.14, PLAZA), CFrame.new(i * 16, 0.07, 0), MOSS_DARK).CanCollide = false
	end
end

-- ===== La douve =========================================================
-- QUATRE BANDES, PAS UN ANNEAU : la douve est carree comme le temple. Elle
-- ne ralentit personne, elle DESSINE le dernier cercle de la zone pour qu'on
-- l'apprenne sans lire la ligne du haut de l'ecran.
for _, s in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
	local wide = MOAT_OUTER * 2
	local thin = MOAT_OUTER - MOAT_INNER
	local sx, sz = s[1], s[2]
	part(
		string.format("Bassin%d_%d", sx, sz),
		decor,
		Vector3.new(if sx ~= 0 then thin else wide, 1.6, if sz ~= 0 then thin else wide),
		CFrame.new(sx * (MOAT_INNER + thin / 2), -0.8, sz * (MOAT_INNER + thin / 2)),
		LIME_DARK
	)
	local w = part(
		string.format("Eau%d_%d", sx, sz),
		decor,
		Vector3.new(if sx ~= 0 then thin - 1 else wide - 2, 0.9, if sz ~= 0 then thin - 1 else wide - 2),
		CFrame.new(sx * (MOAT_INNER + thin / 2), -0.3, sz * (MOAT_INNER + thin / 2)),
		WATER,
		Enum.Material.Glass
	)
	w.Transparency = 0.45
	w.CanCollide = false
	w.Reflectance = 0.25
end

-- Les quatre chaussees, sur les DIAGONALES : les faces portent deja les
-- escaliers de l'autel, et une chaussee qui debouche sur un escalier ferait
-- un seul chemin au lieu de deux.
for _, d in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
	part(
		string.format("Chaussee%d_%d", d[1], d[2]),
		decor,
		Vector3.new(10, 2, 24),
		CFrame.new(d[1] * 19, 0, d[2] * 19) * CFrame.Angles(0, d[1] * d[2] * math.rad(45), 0),
		LIME
	)
end

-- ===== L'autel ==========================================================
for tier = 1, 3 do
	local w = ALTAR_BASE - (tier - 1) * 6
	local y = (tier - 1) * (ALTAR_TOP / 3)
	part(
		string.format("Gradin%d", tier),
		decor,
		Vector3.new(w, ALTAR_TOP / 3 + 0.4, w),
		CFrame.new(0, y + ALTAR_TOP / 6, 0),
		if tier == 3 then LIME else MOSS
	)
	part(
		string.format("GradinBord%d", tier),
		decor,
		Vector3.new(w + 1, 0.5, w + 1),
		CFrame.new(0, y + ALTAR_TOP / 3 - 0.1, 0),
		LIME_DARK
	).CanCollide = false
end

-- UN ESCALIER PAR FACE. L'autel voit tout : s'il n'avait qu'une montee, une
-- personne la tiendrait et la position deviendrait imprenable au lieu d'etre
-- disputee.
for i, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
	for s = 1, 10 do
		local r = ALTAR_BASE / 2 + 5 - s * 0.9
		part(
			string.format("Degre%d_%d", i, s),
			decor,
			Vector3.new(if d[1] ~= 0 then 1.4 else 11, 1, if d[2] ~= 0 then 1.4 else 11),
			CFrame.new(d[1] * r, s - 0.5, d[2] * r),
			MOSS
		)
	end
end

-- Les quatre colonnes du sommet et leur linteau d'or : c'est la seule chose
-- doree de la map, donc c'est elle qu'on vise des qu'on cherche le centre.
for _, c in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
	pillar(string.format("Fut%d_%d", c[1], c[2]), cover, 1.3, 9, c[1] * 4.5, c[2] * 4.5, ALTAR_TOP, LIME)
end
part("Linteau", decor, Vector3.new(13, 1.6, 13), CFrame.new(0, ALTAR_TOP + 9.8, 0), GOLD, Enum.Material.Metal).CanCollide = false
part("Pierre", cover, Vector3.new(5, 2.4, 5), CFrame.new(0, ALTAR_TOP + 1.2, 0), GOLD, Enum.Material.Metal)

-- ===== Les deux tours des coins neutres =================================
-- AUX COINS QUE PERSONNE N'HABITE, donc a egale distance des deux camps.
-- Elles tiennent les deux diagonales que l'autel ne voit pas, elles ont une
-- rampe chacune, et leur plancher est a huit studs : assez pour dominer la
-- dalle, pas assez pour voir par-dessus l'autel.
for _, c in { { 1, -1 }, { -1, 1 } } do
	local x, z = c[1] * SPAWN_XZ, c[2] * SPAWN_XZ
	part(string.format("Socle%d", c[1]), decor, Vector3.new(26, 8, 26), CFrame.new(x, 4, z), LIME_DARK)
	part(string.format("Plancher%d", c[1]), decor, Vector3.new(27, 1, 27), CFrame.new(x, 8.3, z), LIME)
	-- Trois pans de mur en ruine, pas quatre : un carre ferme serait une
	-- boite dont on ne sort que par la rampe.
	for i, w in { { 1, 0 }, { 0, 1 }, { 0.72, 0.72 } } do
		part(
			string.format("Pan%d_%d", c[1], i),
			cover,
			Vector3.new(if w[1] > 0.9 then 2.2 else 20, 9 - i * 1.6, if w[2] > 0.9 then 2.2 else 20),
			CFrame.new(x + c[1] * w[1] * 12, 13 - i * 0.8, z + c[2] * w[2] * 12) * CFrame.Angles(0, if i == 3 then c[1] * c[2] * math.rad(45) else 0, 0),
			MOSS
		)
	end
	-- La rampe, cote centre : on monte en s'exposant, ce qui est le prix de
	-- la hauteur.
	part(
		string.format("Rampe%d", c[1]),
		decor,
		Vector3.new(11, 1.4, 19),
		-- LE SIGNE DU TANGAGE EST NEGATIF, et il a ete mesure. Un tangage
		-- positif fait DESCENDRE le bout +Z de la part ; apres le lacet de
		-- -45 degres ce bout-la regarde la tour, donc la rampe montait vers
		-- le centre et descendait vers le plancher qu'elle est censee
		-- atteindre. Verifie en echantillonnant la hauteur du sol le long de
		-- la rampe, pas en relisant le calcul : c'est la meme lecon que les
		-- gestes d'arme partis a l'envers.
		CFrame.new(x - c[1] * 15, 4.2, z - c[2] * 15)
			* CFrame.Angles(0, c[1] * c[2] * math.rad(45), 0)
			* CFrame.Angles(-math.atan2(8, 16), 0, 0),
		LIME_DARK
	)
	pillar(string.format("TourFut%d", c[1]), decor, 2, 22, x + c[1] * 10, z + c[2] * 10, 8, LIME, Enum.Material.Slate)
end

-- ===== Les deux camps ===================================================
for _, side in { -1, 1 } do
	local team = if side < 0 then "A" else "B"
	local tint = if side < 0 then COLOR_A else COLOR_B
	local x, z = side * SPAWN_XZ, side * SPAWN_XZ

	part("Parvis" .. team, decor, Vector3.new(30, 4, 30), CFrame.new(x, 2, z), LIME)
	-- Le portique : deux rangees de colonnes et un toit. Il abrite, il dit de
	-- quel cote on est, et il coupe la vue depuis le centre vers le depart.
	for _, dx in { -1, 1 } do
		for _, dz in { -1, 1 } do
			pillar(string.format("Col%s%d%d", team, dx, dz), decor, 1.6, 11, x + dx * 10, z + dz * 10, 4, LIME)
		end
	end
	-- LE TOIT EST PLUS PETIT QUE LE PARVIS ET PLUS BAS. A trente studs de
	-- cote et dix-neuf de haut il ecrasait la moitie de la map a l'ecran :
	-- un abri de depart doit se voir, pas dominer le temple qui est le sujet.
	part("Toit" .. team, decor, Vector3.new(25, 1.6, 25), CFrame.new(x, 15.6, z), MOSS_DARK).CanCollide = false
	part("Faitage" .. team, decor, Vector3.new(27, 0.8, 27), CFrame.new(x, 16.6, z), LIME_DARK).CanCollide = false
	part("Fronton" .. team, decor, Vector3.new(22, 2.2, 1), CFrame.new(x - side * 1, 14, z - side * 12), tint, Enum.Material.Fabric).CanCollide = false
	part("Fronton2" .. team, decor, Vector3.new(1, 2.2, 22), CFrame.new(x - side * 12, 14, z - side * 1), tint, Enum.Material.Fabric).CanCollide = false

	-- DEUX SORTIES, pas une : un camp a une seule issue se fait enfermer par
	-- une personne. Le mur du fond les separe et couvre le depart.
	part("Fond" .. team, cover, Vector3.new(26, 11, 3), CFrame.new(x + side * 2, 9.5, z + side * 14), MOSS)
	part("Fond2" .. team, cover, Vector3.new(3, 11, 26), CFrame.new(x + side * 14, 9.5, z + side * 2), MOSS)

	-- Deux blocs devant, pour ne pas aborder la dalle a decouvert.
	for i, b in { { -18, -6 }, { -6, -18 } } do
		part(
			string.format("Bloc%s%d", team, i),
			cover,
			Vector3.new(9, 5.5, 7),
			CFrame.new(x + side * b[1], 2.75, z + side * b[2]) * CFrame.Angles(0, i * 0.5, 0),
			MOSS_DARK
		)
	end

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
		marker.Position = Vector3.new(x + (i - 3) * 5, 7, z - (i - 3) * 5)
		marker.Parent = folder
	end
end

-- ===== La couverture de la dalle ========================================
-- LE RYTHME. Entre la douve et les camps il y a une trentaine de studs de
-- pierre nue de chaque cote : on y traverse a decouvert, et une traversee a
-- decouvert se joue toute seule. Colonnes tombees, pans de mur et racines,
-- a hauteur de poitrine pour la moitie.
local DEBRIS = {
	{ 44, 10, "colonne", 16 },
	{ 30, 32, "mur", 14 },
	{ 14, 46, "colonne", 13 },
	{ 46, -26, "mur", 12 },
	{ 24, -40, "racine", 0 },
	{ 8, -30, "colonne", 11 },
	{ 38, 46, "racine", 0 },
	{ 52, 28, "mur", 10 },
}
for i, d in DEBRIS do
	for _, sgn in { 1, -1 } do
		-- Symetrie de ROTATION, pas de miroir : un miroir donnerait deux camps
		-- qui tournent dans des sens opposes, et ce qu'un joueur apprend d'un
		-- cote ne servirait pas de l'autre.
		local x, z = d[1] * sgn, d[2] * sgn
		local name = string.format("Debris%d_%d", i, sgn)
		if d[3] == "colonne" then
			local p = pillar(name, cover, 1.7, d[4], x, z, 0, LIME)
			p.CFrame = CFrame.new(x, 1.7, z) * CFrame.Angles(0, i * 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, math.rad(90), 0)
			p.Size = Vector3.new(d[4], 3.4, 3.4)
		elseif d[3] == "mur" then
			part(name, cover, Vector3.new(d[4], 6.5, 2.6), CFrame.new(x, 3.25, z) * CFrame.Angles(0, i * 0.8, 0), MOSS)
			part(name .. "Bas", cover, Vector3.new(d[4] * 0.6, 3.4, 2.6), CFrame.new(x + 2, 1.7, z + 5) * CFrame.Angles(0, i * 0.8 + 0.4, 0), MOSS_DARK)
		else
			-- Une racine : trois boudins qui sortent du sol en travers. C'est
			-- la seule chose de la map qui ne soit pas taillee, et c'est elle
			-- qui dit que la jungle reprend le temple.
			for k = 1, 3 do
				local p = pillar(string.format("%sR%d", name, k), cover, 1.1 + k * 0.2, 12 - k, x + k * 2.2, z - k * 1.4, 0, BARK, Enum.Material.Wood)
				p.CFrame = CFrame.new(x + k * 2.2, 1 + k * 0.3, z - k * 1.4)
					* CFrame.Angles(0, i + k * 0.5, 0)
					* CFrame.Angles(0, 0, math.rad(90))
					* CFrame.Angles(0, math.rad(74), 0)
			end
		end
	end
end

-- ===== La jungle autour =================================================
-- Elle borne la dalle sans mur : on voit qu'on sort du temple parce que la
-- pierre s'arrete et que les arbres commencent.
for i = 1, 40 do
	local a = i / 40 * math.pi * 2 + (i % 3) * 0.08
	-- CENT DIX STUDS, PAS QUATRE-VINGT-SIX. La dalle fait 150 de cote, donc
	-- son bord est a 75 : a 86 les troncs etaient a onze studs du bord et les
	-- boules de feuillage, larges de vingt, debordaient SUR le terrain. On
	-- jouait dans les arbres sans les voir venir.
	local r = 110 + (i % 4) * 11
	local x, z = math.sin(a) * r, math.cos(a) * r
	local h = 24 + (i % 7) * 9
	pillar(string.format("Tronc%d", i), decor, 2.4 + (i % 3) * 0.5, h, x, z, -1, BARK, Enum.Material.Wood)
	for k = 1, 3 do
		local ball = part(
			string.format("Feuillage%d_%d", i, k),
			decor,
			Vector3.new(20 + (i % 4) * 4, 15, 20 + (k % 3) * 5),
			CFrame.new(x + (k - 2) * 6, h - 2 + k * 3, z + (k - 2) * 5),
			if k == 2 then LEAF_DARK else LEAF,
			Enum.Material.Grass
		)
		ball.Shape = Enum.PartType.Ball
		ball.CanCollide = false
	end
end

-- Le mur d'enceinte en ruine : il marque la limite de la dalle sans enfermer.
for _, s in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
	for i = -3, 3 do
		if math.abs(i) ~= 1 then
			local along = i * 20
			part(
				string.format("Enceinte%d_%d_%d", s[1], s[2], i),
				cover,
				Vector3.new(if s[1] ~= 0 then 3 else 16, 7 - math.abs(i), if s[2] ~= 0 then 3 else 16),
				CFrame.new(
					s[1] * (PLAZA / 2 - 3) + (if s[1] == 0 then along else 0),
					3.5 - math.abs(i) / 2,
					s[2] * (PLAZA / 2 - 3) + (if s[2] == 0 then along else 0)
				),
				MOSS_DARK
			)
		end
	end
end

-- ===== La pluie =========================================================
-- QUATRE EMETTEURS, posees haut et larges. Roblox emet depuis le VOLUME de
-- la part, donc une grande dalle plate couvre la map entiere sans qu'un
-- script ait a suivre le joueur — et un script, une map n'en a pas.
for i, c in { { -40, -40 }, { 40, -40 }, { -40, 40 }, { 40, 40 } } do
	local sheet = part(
		string.format("Pluie%d", i),
		decor,
		Vector3.new(82, 2, 82),
		CFrame.new(c[1], 48, c[2]),
		WATER
	)
	sheet.Transparency = 1
	sheet.CanCollide = false
	local rain = Instance.new("ParticleEmitter")
	rain.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	rain.Color = ColorSequence.new(Color3.fromRGB(190, 212, 210))
	rain.Transparency = NumberSequence.new(0.55)
	rain.Size = NumberSequence.new(0.22)
	rain.Lifetime = NumberRange.new(2.6, 3.2)
	rain.Rate = 140
	rain.Speed = NumberRange.new(60, 72)
	rain.SpreadAngle = Vector2.new(4, 4)
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Acceleration = Vector3.new(0, -24, 0)
	rain.LockedToPart = false
	rain.Parent = sheet
end

-- ===== Le contrat =======================================================
local centre = Instance.new("Part")
centre.Name = "ZoneCenter"
centre.Size = Vector3.new(4, 1, 4)
centre.Position = Vector3.new(0, 1, 0)
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

-- ===== La lumiere =======================================================
-- Ciel couvert, lumiere plate et verte, brume courte. Chaque script de map
-- pose tout son eclairage : Lighting est un reglage de place, donc lancer un
-- autre script le remplace entierement.
Lighting.ClockTime = 11
Lighting.GeographicLatitude = 4
Lighting.Brightness = 1.1
Lighting.Ambient = Color3.fromRGB(78, 90, 76)
Lighting.OutdoorAmbient = Color3.fromRGB(104, 120, 100)
Lighting.ExposureCompensation = 0
Lighting.FogEnd = 100000
for _, old in Lighting:GetChildren() do
	if old:IsA("Atmosphere") or old:IsA("Sky") or old:IsA("BloomEffect") or old:IsA("ColorCorrectionEffect") then
		old:Destroy()
	end
end
local air = Instance.new("Atmosphere")
-- UNE BRUME DENSE, et c'est elle qui fait la pluie autant que les
-- particules : sans elle le ciel restait d'un bleu franc, ce qui contredit
-- tout le reste de la map. Elle donne aussi de la profondeur a une dalle
-- plate de cent cinquante studs.
air.Density = 0.62
air.Haze = 4.4
air.Glare = 0.05
air.Color = Color3.fromRGB(176, 192, 172)
air.Decay = Color3.fromRGB(96, 116, 96)
air.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.3
bloom.Size = 26
bloom.Threshold = 1.3
bloom.Parent = Lighting
local grade = Instance.new("ColorCorrectionEffect")
grade.Saturation = 0.06
grade.Contrast = 0.05
grade.TintColor = Color3.fromRGB(236, 250, 236)
grade.Parent = Lighting

print(string.format("[Arena] Sanctuaire construit : %d parts.", #map:GetDescendants()))
