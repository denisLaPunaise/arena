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
local MaterialService = game:GetService("MaterialService")

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
-- L'EAU LISAIT COMME UNE PISCINE, et il a fallu DEUX essais. Le premier a
-- fonce le fond, ce qui etait juste : une eau parait profonde parce qu'on ne
-- voit pas son fond. Mais il avait aussi monte la reflectance a 0,70, et une
-- surface a 70 % de miroir ne montre plus sa propre couleur -- elle montre le
-- CIEL. La douve est donc ressortie bleu plastique, exactement le defaut
-- qu'on voulait corriger. Une eau se regarde toujours sous un ciel : ce qui
-- compte n'est pas la couleur ecrite, c'est ce qu'elle reflete.
local WATER = Color3.fromRGB(26, 62, 58)
local WATER_BED = Color3.fromRGB(14, 28, 24)
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

-- UN HASARD REPRODUCTIBLE. Une map est une recette : relancee deux fois elle
-- doit rendre la meme map, sinon on ne peut plus corriger ce qu'on a vu. Donc
-- pas de `math.random`, qui repart d'une graine differente a chaque session,
-- mais une suite calculee depuis une graine ecrite ici.
local seed = 20261102
local function rnd()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

--------------------------------------------------------------------------------
-- LES MATIERES GENEREES
--------------------------------------------------------------------------------

-- UNE MATIERE GENEREE SE RECONSTRUIT, SINON ELLE N'EXISTE QUE DANS LA PLACE.
-- `generate_material` depose ses variantes dans `MaterialService`, qui n'est ni
-- dans Git ni dans Rojo : une matiere generee aurait donc exactement le
-- probleme d'une map construite a la main, et une fausse manoeuvre l'effacerait
-- sans trace. Ce qui sauve le coup est que chaque variante porte QUATRE assets
-- PUBLIES -- couleur, relief, metal, rugosite -- donc la recette peut la
-- reposer a l'identique. Les identifiants ci-dessous SONT la sauvegarde.
--
-- Elles ont ete choisies EN REGARDANT les vingt-quatre variantes posees cote a
-- cote : trois des quatre pierres du Colisee lisaient comme du bois, et deux
-- des quatre glaces comme des flaques turquoise. Un generateur rend quatre
-- propositions, pas quatre reussites.
--
-- `MaterialService` est un reglage de PLACE, comme `Lighting` : la recette vide
-- donc le dossier commun avant de poser les siennes, sinon les matieres des
-- quatre maps s'y empilent.
local function materials(list)
	local folder = MaterialService:FindFirstChild("ArenaMaterials")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "ArenaMaterials"
	folder.Parent = MaterialService

	local byBase = {}
	for _, m in list do
		local v = Instance.new("MaterialVariant")
		v.Name = m.name
		v.BaseMaterial = m.base
		v.ColorMap = "rbxassetid://" .. m.color
		v.NormalMap = "rbxassetid://" .. m.normal
		v.MetalnessMap = "rbxassetid://" .. m.metal
		v.RoughnessMap = "rbxassetid://" .. m.rough
		-- Dix studs par tuile : c'est ce que rend le generateur, et a l'echelle
		-- d'une map de 160 studs ca donne un motif qu'on lit sans qu'il se
		-- repete a l'oeil. Un chiffre a regler en REGARDANT, pas en calculant.
		v.StudsPerTile = 10
		v.Parent = folder
		byBase[m.base] = m.name
	end
	return byBase
end

-- La matiere de base d'une part suffit a lui donner sa variante : la table est
-- consultee a UN SEUL endroit, dans `part()` et `wedge()`. Inscrire la variante
-- sur trois cents sites d'appel serait la meme faute qu'un chiffre recopie.
local VARIANT_FOR = materials({
	{
		name = "ArenaPierreSanctuaire",
		base = Enum.Material.Slate,
		color = 79366465018151,
		normal = 126633952247864,
		metal = 104171204484792,
		rough = 110951199573658,
	},
})

local function part(name, parent, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color or MOSS
	p.Material = material or Enum.Material.Slate
	p.MaterialVariant = VARIANT_FOR[p.Material] or ""
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- LE PREMIER BISEAU DE CETTE MAP. Les trois recettes n'utilisaient que des
-- boites : d'ou des toits plats, et des abris de camp qui lisaient comme des
-- tables de pique-nique. Un coin coute exactement le meme prix qu'une boite.
-- Sa pente descend le long de son axe Z : la face inclinee regarde +Y et +Z,
-- donc l'arete haute est du cote -Z.
local function wedge(name, parent, size, cf, color, material)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.Color = color or MOSS
	p.Material = material or Enum.Material.Slate
	p.MaterialVariant = VARIANT_FOR[p.Material] or ""
	p.Parent = parent
	return p
end

local function pillar(name, parent, radius, height, x, z, y, color, material, tilt)
	local p = part(
		name,
		parent,
		Vector3.new(height, radius * 2, radius * 2),
		CFrame.new(x, y + height / 2, z)
			* CFrame.Angles(0, 0, math.pi / 2)
			* CFrame.Angles(tilt or 0, 0, 0),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- ===== Le sol ===========================================================
part(
	"Jungle",
	decor,
	Vector3.new(900, 8, 900),
	CFrame.new(0, -5, 0),
	LEAF_DARK,
	Enum.Material.Grass
)
part(
	"Dalle",
	decor,
	Vector3.new(PLAZA, 3, PLAZA),
	CFrame.new(0, -1.5, 0),
	MOSS,
	Enum.Material.Slate
)

-- Les joints de la dalle : sans eux, cent cinquante studs de pierre unie ne
-- disent rien de la distance, et on ne sait plus ou on court.
for i = -4, 4 do
	if i ~= 0 then
		part(
			string.format("JointX%d", i),
			decor,
			Vector3.new(PLAZA, 0.14, 0.8),
			CFrame.new(0, 0.07, i * 16),
			MOSS_DARK
		).CanCollide =
			false
		part(
			string.format("JointZ%d", i),
			decor,
			Vector3.new(0.8, 0.14, PLAZA),
			CFrame.new(i * 16, 0.07, 0),
			MOSS_DARK
		).CanCollide =
			false
	end
end

-- LE DAMIER NE SUFFIT PAS. Les joints disent la distance, mais ils la disent
-- PARTOUT PAREIL : cent cinquante studs de dalle reguliere lisent comme un
-- sol de test. Ce qui sauve une grande surface plate est l'irregularite --
-- des plaques de mousse et des flaques, qui donnent a chaque coin de la dalle
-- quelque chose qui n'appartient qu'a lui.
--
-- Un disque s'ecrit [epaisseur, diametre, diametre] et se couche : un
-- `Cylinder` prend toujours le plus PETIT de ses deux cotes de section, donc
-- deux cotes differents en feraient jeter un par Roblox.
for i = 1, 70 do
	local x = (rnd() - 0.5) * (PLAZA - 14)
	local z = (rnd() - 0.5) * (PLAZA - 14)
	local loin = math.max(math.abs(x), math.abs(z))
	-- Ni sur l'autel, ni dans la douve : la mousse ne flotte pas, et une
	-- plaque posee sur l'escalier passerait au travers.
	if loin > 15 and (loin < 19 or loin > 33) then
		local flaque = rnd() < 0.3
		local d = 4 + rnd() * (if flaque then 7 else 11)
		local p = part(
			string.format(if flaque then "Flaque%d" else "Mousse%d", i),
			decor,
			Vector3.new(0.12, d, d),
			CFrame.new(x, 0.06, z) * CFrame.Angles(0, rnd() * math.pi, math.pi / 2),
			if flaque then WATER else (if rnd() < 0.5 then MOSS_DARK else LEAF_DARK),
			if flaque then Enum.Material.SmoothPlastic else Enum.Material.Grass
		)
		p.Shape = Enum.PartType.Cylinder
		p.CanCollide = false
		if flaque then
			-- UNE FLAQUE EST UN MIROIR AU SOL, et c'est la seule chose de la
			-- map qui attrape le soleil rasant. C'est pour elle qu'on a
			-- descendu l'heure.
			p.Reflectance = 0.42
			p.Transparency = 0.25
		end
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
		WATER_BED,
		Enum.Material.Slate
	)
	local w = part(
		string.format("Eau%d_%d", sx, sz),
		decor,
		Vector3.new(
			if sx ~= 0 then thin - 1 else wide - 2,
			0.9,
			if sz ~= 0 then thin - 1 else wide - 2
		),
		CFrame.new(sx * (MOAT_INNER + thin / 2), -0.3, sz * (MOAT_INNER + thin / 2)),
		WATER,
		Enum.Material.SmoothPlastic
	)
	-- LE `Glass` DE ROBLOX REFLECHIT TOUT SEUL, et `Reflectance` n'y change
	-- rien. C'est ce qui a coute deux essais : la reflectance est passee de
	-- 0,70 a 0,25 et la douve est restee du meme bleu cobalt, parce que ce
	-- bleu ne venait pas d'elle. En rendu `Future`, le verre recoit un reflet
	-- et une refraction propres a la matiere, donc une nappe de verre sous un
	-- ciel bleu est un ruban bleu, quelle que soit sa couleur ecrite.
	--
	-- `SmoothPlastic` ne reflete que ce qu'on lui demande. La douve montre
	-- alors sa propre couleur, le fond noir-vert se devine a travers, et le
	-- quart de reflet qui reste suffit a poser le ciel dessus.
	w.Transparency = 0.42
	w.CanCollide = false
	w.Reflectance = 0.22
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
	).CanCollide =
		false
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
	pillar(
		string.format("Fut%d_%d", c[1], c[2]),
		cover,
		1.3,
		9,
		c[1] * 4.5,
		c[2] * 4.5,
		ALTAR_TOP,
		LIME
	)
end
part(
	"Linteau",
	decor,
	Vector3.new(13, 1.6, 13),
	CFrame.new(0, ALTAR_TOP + 9.8, 0),
	GOLD,
	Enum.Material.Metal
).CanCollide =
	false
part(
	"Pierre",
	cover,
	Vector3.new(5, 2.4, 5),
	CFrame.new(0, ALTAR_TOP + 1.2, 0),
	GOLD,
	Enum.Material.Metal
)

-- ===== Les deux tours des coins neutres =================================
-- AUX COINS QUE PERSONNE N'HABITE, donc a egale distance des deux camps.
-- Elles tiennent les deux diagonales que l'autel ne voit pas, elles ont une
-- rampe chacune, et leur plancher est a huit studs : assez pour dominer la
-- dalle, pas assez pour voir par-dessus l'autel.
for _, c in { { 1, -1 }, { -1, 1 } } do
	local x, z = c[1] * SPAWN_XZ, c[2] * SPAWN_XZ
	part(
		string.format("Socle%d", c[1]),
		decor,
		Vector3.new(26, 8, 26),
		CFrame.new(x, 4, z),
		LIME_DARK
	)
	part(
		string.format("Plancher%d", c[1]),
		decor,
		Vector3.new(27, 1, 27),
		CFrame.new(x, 8.3, z),
		LIME
	)
	-- Trois pans de mur en ruine, pas quatre : un carre ferme serait une
	-- boite dont on ne sort que par la rampe.
	for i, w in { { 1, 0 }, { 0, 1 }, { 0.72, 0.72 } } do
		part(
			string.format("Pan%d_%d", c[1], i),
			cover,
			Vector3.new(if w[1] > 0.9 then 2.2 else 20, 9 - i * 1.6, if w[2] > 0.9 then 2.2 else 20),
			CFrame.new(x + c[1] * w[1] * 12, 13 - i * 0.8, z + c[2] * w[2] * 12)
				* CFrame.Angles(0, if i == 3 then c[1] * c[2] * math.rad(45) else 0, 0),
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
	pillar(
		string.format("TourFut%d", c[1]),
		decor,
		2,
		22,
		x + c[1] * 10,
		z + c[2] * 10,
		8,
		LIME,
		Enum.Material.Slate
	)
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
			pillar(
				string.format("Col%s%d%d", team, dx, dz),
				decor,
				1.6,
				11,
				x + dx * 10,
				z + dz * 10,
				4,
				LIME
			)
		end
	end
	-- LE TOIT EST PLUS PETIT QUE LE PARVIS ET PLUS BAS. A trente studs de
	-- cote et dix-neuf de haut il ecrasait la moitie de la map a l'ecran :
	-- un abri de depart doit se voir, pas dominer le temple qui est le sujet.
	--
	-- ET IL EST A DEUX PANS, pas plat. Une dalle posee sur quatre colonnes
	-- est une table de pique-nique, et c'est exactement ce a quoi les deux
	-- camps ressemblaient. Deux coins dos a dos font un vrai toit, avec une
	-- arete, et ca ne coute pas une part de plus que la dalle plus son
	-- faitage. C'est le defaut le plus visible que le biseau repare.
	part("Sablière" .. team, decor, Vector3.new(26, 1, 26), CFrame.new(x, 15.4, z), LIME_DARK).CanCollide =
		false
	for _, dir in { 1, -1 } do
		wedge(
			string.format("Pan%s%d", team, dir),
			decor,
			Vector3.new(26, 5.5, 13),
			CFrame.new(x, 18.65, z + dir * 6.5)
				* CFrame.Angles(0, if dir > 0 then 0 else math.pi, 0),
			MOSS_DARK
		)
	end
	part("Faitage" .. team, decor, Vector3.new(27, 0.7, 1.1), CFrame.new(x, 21.6, z), LIME_DARK).CanCollide =
		false
	part(
		"Fronton" .. team,
		decor,
		Vector3.new(22, 2.2, 1),
		CFrame.new(x - side * 1, 14, z - side * 12),
		tint,
		Enum.Material.Fabric
	).CanCollide =
		false
	part(
		"Fronton2" .. team,
		decor,
		Vector3.new(1, 2.2, 22),
		CFrame.new(x - side * 12, 14, z - side * 1),
		tint,
		Enum.Material.Fabric
	).CanCollide =
		false

	-- DEUX SORTIES, pas une : un camp a une seule issue se fait enfermer par
	-- une personne. Le mur du fond les separe et couvre le depart.
	part(
		"Fond" .. team,
		cover,
		Vector3.new(26, 11, 3),
		CFrame.new(x + side * 2, 9.5, z + side * 14),
		MOSS
	)
	part(
		"Fond2" .. team,
		cover,
		Vector3.new(3, 11, 26),
		CFrame.new(x + side * 14, 9.5, z + side * 2),
		MOSS
	)

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
			p.CFrame = CFrame.new(x, 1.7, z)
				* CFrame.Angles(0, i * 0.7, 0)
				* CFrame.Angles(0, 0, math.rad(90))
				* CFrame.Angles(0, math.rad(90), 0)
			p.Size = Vector3.new(d[4], 3.4, 3.4)
		elseif d[3] == "mur" then
			part(
				name,
				cover,
				Vector3.new(d[4], 6.5, 2.6),
				CFrame.new(x, 3.25, z) * CFrame.Angles(0, i * 0.8, 0),
				MOSS
			)
			part(
				name .. "Bas",
				cover,
				Vector3.new(d[4] * 0.6, 3.4, 2.6),
				CFrame.new(x + 2, 1.7, z + 5) * CFrame.Angles(0, i * 0.8 + 0.4, 0),
				MOSS_DARK
			)
		else
			-- Une racine : trois boudins qui sortent du sol en travers. C'est
			-- la seule chose de la map qui ne soit pas taillee, et c'est elle
			-- qui dit que la jungle reprend le temple.
			for k = 1, 3 do
				local p = pillar(
					string.format("%sR%d", name, k),
					cover,
					1.1 + k * 0.2,
					12 - k,
					x + k * 2.2,
					z - k * 1.4,
					0,
					BARK,
					Enum.Material.Wood
				)
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
--
-- QUARANTE SUCETTES NE FONT PAS UNE JUNGLE. La premiere version posait un
-- cylindre droit et trois boules par arbre, tous a la meme hauteur : vu de la
-- dalle, ca lisait comme une rangee de lampadaires verts. Ce qui fait une
-- foret est la SUPERPOSITION -- quelques geants qui percent, une voute dense
-- au milieu, et du sous-bois dessous. Trois etages, donc, et aucun arbre ne
-- se tient parfaitement droit.
local LEAF_PALE = Color3.fromRGB(70, 118, 62)
local BARK_PALE = Color3.fromRGB(94, 78, 58)

-- UN TRONC QUI PENCHE GARDE SON PIED AU SOL. `pillar` ne sait pas pencher :
-- son argument `tilt` tourne le cylindre AUTOUR DE SA PROPRE LONGUEUR, ce qui
-- ne se voit pas sur une forme ronde. Il faut donc composer la rotation
-- soi-meme, et surtout placer le CENTRE a une demi-hauteur le long de l'axe
-- penche -- sinon le pied s'enfonce ou decolle.
local function trunk(name, radius, height, base, lean, leanDir, color)
	local rot = CFrame.Angles(0, leanDir, 0) * CFrame.Angles(0, 0, math.pi / 2 - lean)
	local axis = rot.RightVector
	local p = part(
		name,
		decor,
		Vector3.new(height, radius * 2, radius * 2),
		CFrame.new(base + axis * (height / 2)) * rot,
		color,
		Enum.Material.Wood
	)
	p.Shape = Enum.PartType.Cylinder
	return base + axis * height
end

-- UNE COURONNE EST UNE GRAPPE, PAS UNE BOULE. Trois spheres larges posees
-- l'une sur l'autre redonnent une sphere : de loin le contour reste un rond
-- parfait, et un rond parfait sur un baton est une sucette. Ce qui fait un
-- arbre est un contour IRREGULIER, donc beaucoup de petites spheres dont
-- aucune ne depasse, chacune decalee et d'un vert un peu different.
local function crown(name, centre, diameter, color)
	for k = 1, 5 do
		local d = diameter * (0.52 + rnd() * 0.4)
		local b = part(
			string.format("%s_%d", name, k),
			decor,
			Vector3.new(d, d, d),
			CFrame.new(
				centre
					+ Vector3.new(
						(rnd() - 0.5) * diameter * 0.9,
						(rnd() - 0.5) * diameter * 0.5,
						(rnd() - 0.5) * diameter * 0.9
					)
			),
			if rnd() < 0.35 then LEAF_DARK else color,
			Enum.Material.Grass
		)
		b.Shape = Enum.PartType.Ball
		b.CanCollide = false
	end
end

for i = 1, 40 do
	local a = i / 40 * math.pi * 2 + (i % 3) * 0.08
	-- CENT DIX STUDS, PAS QUATRE-VINGT-SIX. La dalle fait 150 de cote, donc
	-- son bord est a 75 : a 86 les troncs etaient a onze studs du bord et les
	-- boules de feuillage, larges de vingt, debordaient SUR le terrain. On
	-- jouait dans les arbres sans les voir venir.
	local r = 110 + (i % 4) * 11
	local x, z = math.sin(a) * r, math.cos(a) * r
	local base = Vector3.new(x, -1, z)
	local etage = i % 3
	local lean = 0.03 + rnd() * 0.09
	local leanDir = rnd() * math.pi * 2
	local ecorce = if i % 4 == 0 then BARK_PALE else BARK

	if etage == 0 then
		-- L'EMERGENT : il perce la voute, donc il est haut et sa couronne est
		-- petite. C'est lui qui donne une silhouette a la foret de loin.
		local h = 46 + rnd() * 14
		local top = trunk(
			string.format("Tronc%d", i),
			2.0 + rnd() * 0.5,
			h,
			base,
			lean * 0.5,
			leanDir,
			ecorce
		)
		for k = 1, 2 do
			local d = 16 + rnd() * 7
			crown(
				string.format("Feuillage%d_%d", i, k),
				top + Vector3.new((rnd() - 0.5) * 11, -3 + k * 4, (rnd() - 0.5) * 11),
				d,
				if k == 2 then LEAF_DARK else LEAF
			)
		end
		-- Les contreforts : un grand arbre tropical s'assoit sur des ailerons,
		-- et sans eux un tronc de cinquante studs a l'air plante dans le sol
		-- comme un poteau.
		for k = 1, 4 do
			local ang = k / 4 * math.pi * 2 + i
			local p = part(
				string.format("Contrefort%d_%d", i, k),
				decor,
				Vector3.new(0.9, 7, 4.5),
				CFrame.new(x + math.sin(ang) * 2.2, 2.2, z + math.cos(ang) * 2.2)
					* CFrame.Angles(0, -ang, 0)
					* CFrame.Angles(0.42, 0, 0),
				ecorce,
				Enum.Material.Wood
			)
			p.CanCollide = false
		end
	elseif etage == 1 then
		-- LA VOUTE : la plus large, la plus sombre, et c'est elle qui ferme
		-- l'horizon derriere la dalle.
		local h = 26 + rnd() * 10
		local top =
			trunk(string.format("Tronc%d", i), 2.6 + rnd() * 0.6, h, base, lean, leanDir, ecorce)
		for k = 1, 3 do
			local d = 21 + rnd() * 11
			crown(
				string.format("Feuillage%d_%d", i, k),
				top + Vector3.new((rnd() - 0.5) * 14, -5 + k * 3.5, (rnd() - 0.5) * 14),
				d,
				if k % 2 == 0 then LEAF_DARK else LEAF
			)
		end
		-- Deux lianes : verticales, fines, elles cassent la rondeur des boules
		-- et disent la hauteur de la voute mieux que les boules elles-memes.
		for k = 1, 2 do
			local len = 9 + rnd() * 11
			local lx, lz = x + (rnd() - 0.5) * 13, z + (rnd() - 0.5) * 13
			pillar(
				string.format("Liane%d_%d", i, k),
				decor,
				0.22,
				len,
				lx,
				lz,
				top.Y - 4 - len,
				LEAF_DARK,
				Enum.Material.Grass
			).CanCollide =
				false
		end
	else
		-- LE SOUS-BOIS : bas, clair, dense. Il remplit le vide entre les pieds
		-- des grands, qui sinon laissent voir le vide derriere la foret.
		local h = 12 + rnd() * 8
		local top = trunk(
			string.format("Tronc%d", i),
			1.6 + rnd() * 0.5,
			h,
			base,
			lean * 1.6,
			leanDir,
			ecorce
		)
		for k = 1, 2 do
			local d = 14 + rnd() * 8
			crown(
				string.format("Feuillage%d_%d", i, k),
				top + Vector3.new((rnd() - 0.5) * 9, -2 + k * 2.5, (rnd() - 0.5) * 9),
				d,
				if k == 1 then LEAF_PALE else LEAF
			)
		end
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
				Vector3.new(
					if s[1] ~= 0 then 3 else 16,
					7 - math.abs(i),
					if s[2] ~= 0 then 3 else 16
				),
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
-- UN SOLEIL AU ZENITH NE PORTE AUCUNE OMBRE, et c'est ce qui rendait la map
-- plate. A onze heures, sous une latitude de 4 degres, le soleil est droit
-- au-dessus : chaque arbre pose son ombre sous lui-meme et la dalle reste un
-- aplat uniforme. Toute la geometrie ecrite -- quarante arbres, les colonnes,
-- l'autel a etages -- ne se voyait pas, faute de relief.
--
-- A 6h50 il rase l'horizon : les ombres traversent la dalle entiere, la foret
-- projette sur la pierre, l'autel se detache -- et surtout le ciel procedural
-- de Roblox passe a l'orange. C'est le second gain, et il est gratuit : le
-- bleu franc de midi est la marque d'une place vide, et aucune brume ne l'en
-- enleve completement. Une heure le fait.
--
-- Il faut monter la luminosite avec, parce qu'un soleil bas traverse beaucoup
-- plus d'air, et baisser l'ambiante -- une ombre n'existe que si ce qui la
-- remplit est plus sombre que ce qui l'entoure. Mais pas trop : c'est une
-- arene PvP, et on doit voir son adversaire.
--
-- Chaque script de map pose tout son eclairage : Lighting est un reglage de
-- place, donc lancer un autre script le remplace entierement.
Lighting.ClockTime = 6.9
Lighting.GeographicLatitude = 4
Lighting.Brightness = 3.3
Lighting.Ambient = Color3.fromRGB(54, 66, 56)
Lighting.OutdoorAmbient = Color3.fromRGB(106, 120, 104)
Lighting.ExposureCompensation = 0
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
-- UNE BRUME DENSE, et c'est elle qui fait la pluie autant que les
-- particules : sans elle le ciel restait d'un bleu franc, ce qui contredit
-- tout le reste de la map. Elle donne aussi de la profondeur a une dalle
-- plate de cent cinquante studs.
-- LE CIEL RESTAIT D'UN BLEU DE PLACE VIDE, et descendre l'heure n'y suffisait
-- pas : a 6h50 il etait toujours aussi bleu. L'explication est que
-- l'`Atmosphere` REMPLACE le degrade du ciel procedural, donc c'est elle qui
-- decide de sa couleur, pas l'heure. Deux champs la commandent, et ils ne
-- font pas la meme chose : `Color` teinte la brume, c'est-a-dire le ciel pres
-- du soleil et l'horizon ; `Decay` teinte ce qui est LOIN du soleil, donc le
-- zenith. Un ciel ecrit avec les deux neutres reste bleu quelle que soit
-- l'heure -- ce qui etait exactement le cas.
--
-- Donc : une brume chaude pres du soleil, un zenith qui part vers le vert
-- sombre, et une densite assez haute pour que ca se voie. L'eclat monte avec,
-- parce que c'est lui qui fait les rais de lumiere entre les troncs.
air.Density = 0.6
air.Haze = 4.8
air.Glare = 0.45
air.Color = Color3.fromRGB(226, 186, 132)
air.Decay = Color3.fromRGB(74, 96, 92)
air.Parent = Lighting
local bloom = Instance.new("BloomEffect")
-- LE SOLEIL ETAIT UN PATE BLANC. Un disque solaire bas entre dans le cadre,
-- et un bloom large pose dessus le fait deborder sur un quart de l'ecran.
-- Le seuil monte pour que seul le soleil lui-meme deborde, et la taille
-- baisse pour qu'il deborde moins loin.
bloom.Intensity = 0.22
bloom.Size = 14
bloom.Threshold = 2
bloom.Parent = Lighting
local grade = Instance.new("ColorCorrectionEffect")
grade.Saturation = 0.14
grade.Contrast = 0.12
grade.TintColor = Color3.fromRGB(246, 244, 226)
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
-- Couvert et bas : il pleut sur cette map, et un ciel degage au-dessus de la
-- pluie serait le genre de detail qui dit « c'est une maquette ».
-- SEPT DIXIEMES, PAS NEUF. A 0,88 le ciel etait superbe et la dalle etait
-- SOMBRE : les nuages mangent le soleil, donc ils mangent aussi les ombres
-- longues qu'on etait alle chercher en descendant l'heure. Une arene se joue
-- avant d'etre jolie, et on doit voir son adversaire.
nuages.Cover = 0.72
nuages.Density = 0.6
nuages.Color = Color3.fromRGB(150, 158, 152)
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
local alarms = 0
local tech = "inconnue"
pcall(function()
	Lighting.Technology = Enum.Technology.Future
end)
pcall(function()
	tech = Lighting.Technology.Name
end)
if tech == "inconnue" then
	-- Ecrit sans erreur, mais illisible : c'est le cas quand la recette passe
	-- par le pont MCP, qui n'a pas le droit de RELIRE cette propriete. On ne
	-- sait donc pas, et on le dit comme tel.
	print(
		"  Rendu : réglage envoyé, mais impossible à relire d'ici. À vérifier une "
			.. "fois dans Explorer → Lighting → Properties → Technology = Future."
	)
elseif tech ~= "Future" then
	alarms += 1
	warn(
		string.format(
			"[Arena] Rendu en « %s » et pas « Future ». C'est le réglage qui change le "
				.. "plus l'allure du jeu, et il ne se pose pas depuis un script : "
				.. "dans Studio, Explorer → Lighting → Properties → Technology → Future. "
				.. "À faire une seule fois, ça reste avec la place.",
			tech
		)
	)
else
	print("  Rendu : Future. Bon.")
end
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.5

-- Ces deux-la decident de combien le CIEL se reflete dans les matieres. A zero
-- (le defaut de certaines places) la pierre est plate et le metal est gris.
Lighting.EnvironmentDiffuseScale = 0.75
Lighting.EnvironmentSpecularScale = 0.5

for _, old in Lighting:GetChildren() do
	if old:IsA("SunRaysEffect") or old:IsA("DepthOfFieldEffect") then
		old:Destroy()
	end
end
local rays = Instance.new("SunRaysEffect")
rays.Intensity = 0.2
rays.Spread = 1
rays.Parent = Lighting

-- La profondeur de champ ne sert pas a flouter le jeu : `FarIntensity` reste
-- bas et `FocusDistance` couvre toute l'arene, donc ce qu'on combat est net et
-- seul le lointain s'adoucit. C'est ce qui separe le decor du terrain.
local dof = Instance.new("DepthOfFieldEffect")
dof.FocusDistance = 80
dof.InFocusRadius = 140
dof.NearIntensity = 0
dof.FarIntensity = 0.65
dof.Parent = Lighting

--------------------------------------------------------------------------------
-- CE QUE LA MAP SE MESURE A ELLE-MEME
--------------------------------------------------------------------------------

-- UNE MAP NE SE JUGE PAS A L'OEIL, ELLE SE MESURE AU RAYON. Les trois defauts
-- de jeu reels trouves dans les maps le 29 octobre 2026 l'ont tous ete comme
-- ca, aucun en regardant : une ligne de tir degagee de 120 studs entre les deux
-- departs, deux coursives aveugles sur le cercle final, et une rampe posee a
-- l'envers. L'oeil dit si c'est joli ; le rayon dit si ca se joue.
--
-- Alors la recette le fait elle-meme, a chaque construction, et elle AVERTIT.
-- Une mesure qu'il faut penser a refaire ne se refait pas : celle-ci part toute
-- seule, et quelqu'un qui deplace un bloc voit tout de suite ce que ca casse.

local probe = RaycastParams.new()
probe.FilterType = Enum.RaycastFilterType.Include
probe.FilterDescendantsInstances = { map }
-- UNE SONDE QUI COMPTE LE DECOR COMPTE N'IMPORTE QUOI. Elle annoncait
-- 14 directions couvertes sur 16, et le temoin a nomme les coupables : les
-- croisillons du chevalement, des batons de 0,6 stud poses a
-- `CanCollide = false` pour qu'on les traverse. Un rayon les arrete, un joueur
-- passe au travers -- donc ce n'etait pas un couvert, et la mesure est tombee
-- a 4 des qu'on a demande au rayon de respecter les collisions. La mesure
-- etait precise et mesurait autre chose : meme famille que les deux
-- `AbsolutePosition` lus dans deux reperes le 26 octobre.
probe.RespectCanCollide = true

-- ET LA PORTEE DE LA MESURE EST LE DERNIER CERCLE LUI-MEME, pas un chiffre
-- rond. Un couvert a vingt-huit studs du centre ne sert a rien dans un cercle
-- qui en fait seize de rayon : la version d'avant portait a vingt-cinq et
-- comptait donc des blocs hors du cercle ou la couverture compte. Le chiffre
-- se demande a `Config` plutot que d'etre recopie, parce qu'une copie se
-- perime en silence le jour ou Josh resserre la zone.
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
	else
		-- UN AVERTISSEMENT QUI MENT COUTE PLUS CHER QUE PAS D'AVERTISSEMENT. La
		-- premiere version disait « la place n'est pas synchronisee » quoi
		-- qu'il arrive -- et elle l'a dit sur une place a jour au caractere
		-- pres, parce que la cle vit dans `Config.round` et pas a la racine.
		-- On part alors chercher un probleme de synchro qui n'existe pas,
		-- exactement comme l'« Infinite yield » du 27 octobre. Donc le message
		-- nomme ce qui manque VRAIMENT.
		print(
			string.format(
				"  (couverture mesuree sur %d studs : %s)",
				FINAL_RADIUS,
				if module == nil
					then "ReplicatedStorage.Arena.Config est absent, la place n'est pas synchronisee"
					else "Config est la mais round.zoneFinalRadiusStuds ne s'y lit pas, la cle a bouge"
			)
		)
	end
end

-- Hauteur des yeux au-dessus du point d'apparition. Un point de depart est
-- pose quatre studs au-dessus de son sol dans les quatre recettes, et la tete
-- arrive a peu pres a cette hauteur-la.
local EYE = 3.5

print("")
print(string.format("[Arena] ===== %s se mesure =====", map.Name))

local spawnsA = map:FindFirstChild("SpawnsA")
local spawnsB = map:FindFirstChild("SpawnsB")

-- 1. LES LIGNES DE TIR ENTRE LES DEUX DEPARTS. Le premier a cliquer gagne
-- l'echange sans que personne ait joue : c'est le defaut qui a ete trouve dans
-- la soute du cargo, et c'est le plus cher parce qu'il frappe a chaque manche.
if spawnsA and spawnsB then
	local open, longest, couples = 0, 0, 0
	for _, a in spawnsA:GetChildren() do
		for _, b in spawnsB:GetChildren() do
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
				"[Arena]   Departs : %d lignes degagees sur %d, la plus longue %.0f studs. "
					.. "Il manque un obstacle sur l'axe des deux camps.",
				open,
				couples,
				longest
			)
		)
	end

	-- 2. CHAQUE POINT DE DEPART A-T-IL DU SOL SOUS LUI ? Un point pose dans un
	-- mur ou au-dessus du vide ne se voit sur aucune capture, et il coute une
	-- manche entiere au joueur qui tombe dessus.
	local floating = 0
	for _, folder in { spawnsA, spawnsB } do
		for _, marker in folder:GetChildren() do
			local hit = Workspace:Raycast(marker.Position, Vector3.new(0, -12, 0), probe)
			if hit == nil then
				floating += 1
			end
		end
	end
	if floating == 0 then
		print("  Departs : tous ont du sol sous eux. Bon.")
	else
		alarms += 1
		warn(
			string.format(
				"[Arena]   %d point(s) de depart n'ont rien a moins de douze studs "
					.. "sous eux : le joueur apparaitra en chute.",
				floating
			)
		)
	end
end

-- 3. LA COUVERTURE DU CERCLE FINAL. Trop nu, on s'y fait tirer de partout ;
-- trop encombre, on ne peut plus s'y disputer. Les deux sont des defauts, donc
-- l'avertissement part dans les deux sens.
local centreMark = map:FindFirstChild("ZoneCenter")
if centreMark then
	local origin = centreMark.Position + Vector3.new(0, EYE, 0)
	local covered = 0
	for step = 0, 15 do
		local angle = step / 16 * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle)) * FINAL_RADIUS
		if Workspace:Raycast(origin, direction, probe) then
			covered += 1
		end
	end
	print(
		string.format(
			"  Cercle final : %d directions sur 16 trouvent un couvert dans les %d studs du dernier cercle.",
			covered,
			FINAL_RADIUS
		)
	)
	if covered < 4 then
		alarms += 1
		warn("[Arena]   Le cercle final est trop nu : on s'y fait tirer de partout.")
	elseif covered > 12 then
		alarms += 1
		warn("[Arena]   Le cercle final est trop encombre : on ne peut plus s'y disputer.")
	end
end

if alarms == 0 then
	print("  Rien a signaler.")
else
	warn(string.format("[Arena] %d point(s) a regarder ci-dessus.", alarms))
end
print("")

print(string.format("[Arena] Sanctuaire construit : %d parts.", #map:GetDescendants()))
