--!nolint
--[[
	BuildCargoMap — « Le Cargo ». A coller dans la barre de commande.

	POURQUOI CE FICHIER EXISTE
	Les maps vivent dans Workspace, que Rojo ne touche pas, et le .rbxl n'est
	pas dans Git. Ce script est la seule sauvegarde de la map. Il detruit la
	precedente avant de reconstruire : deux maps dans Workspace seraient un
	tirage au sort, puisque `MapService` prend la PREMIERE qui respecte le
	contrat.

	CE N'EST PAS DU CODE DE JEU : hors du projet Rojo, jamais execute en
	partie, pas verifie par Selene ni StyLua.

	CE QU'ELLE RACONTE
	Une soute de cargo orbital, de nuit, portes ouvertes sur le vide. Acier
	sombre, conteneurs rouilles, neons ambre et turquoise, un portique de grue
	au plafond et des etoiles par la baie. Tout le contraire du colisee : pas
	de ciel, pas de pierre, pas de rond.

	CE QU'ELLE FAIT JOUER
	Trois etages de circulation, et c'est la son idee :
	- LE SOL, entre deux blocs de conteneurs. Couvert, sinueux, court. C'est
	  la route du corps a corps.
	- LES DEUX COURSIVES, le long des grands cotes, a quatorze studs. Elles
	  voient tout le sol et rien l'une de l'autre : quatre escaliers y
	  montent, deux par camp, aux deux extremites.
	- LA PASSERELLE CENTRALE, qui relie les deux coursives en passant
	  au-dessus du centre. C'est la position de force, et elle est a egale
	  distance des deux camps — on s'y rend, on ne s'y trouve pas. Elle est
	  etroite, decouverte et visible de tout le sol : la tenir coute cher.

	Deux piles de conteneurs sont posees sur l'axe des camps, expres : sans
	elles les deux departs se voient en ligne droite sur cent vingt studs.

	LA TAILLE
	La soute fait 150 sur 120 studs. MapBounds est un CARRE de 170, donc la
	zone demarre a 85 de rayon : elle couvre les departs des la premiere
	seconde, et elle mord les quatre coins — c'est voulu, les coins sont du
	decor, pas du terrain.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local HALL_X = 150
local HALL_Z = 120
local BOUNDS_WIDTH = 170
local WALL_HEIGHT = 40
local DECK_HEIGHT = 14
local SPAWN_X = 62

local DECK = Color3.fromRGB(76, 82, 92)
local DECK_DARK = Color3.fromRGB(44, 48, 56)
local STEEL = Color3.fromRGB(82, 89, 100)
local STEEL_LIGHT = Color3.fromRGB(112, 121, 134)
local RUST = Color3.fromRGB(126, 74, 52)
local CRATE_TEAL = Color3.fromRGB(44, 96, 102)
local CRATE_AMBER = Color3.fromRGB(150, 110, 44)
local CRATE_GREY = Color3.fromRGB(78, 84, 94)
local NEON_AMBER = Color3.fromRGB(255, 176, 72)
local NEON_TEAL = Color3.fromRGB(96, 226, 230)
local HAZARD = Color3.fromRGB(216, 176, 60)
local COLOR_A = Color3.fromRGB(70, 130, 230)
local COLOR_B = Color3.fromRGB(230, 80, 70)

for _, name in { "ArenaMap", "ColiseeMap", "CargoMap", "SanctuaireMap" } do
	local old = Workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
-- La map apporte son sol : la Baseplate est a la meme hauteur que le pont et
-- gagne un pixel sur deux. Le point d'apparition par defaut part avec elle,
-- sinon il pose un joueur hors des deux camps.
for _, name in { "Baseplate", "SpawnLocation" } do
	local old = Workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

local map = Instance.new("Folder")
map.Name = "CargoMap"
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
	p.Color = color or STEEL
	p.Material = material or Enum.Material.Metal
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function neon(name, parent, size, cf, color)
	local p = part(name, parent, size, cf, color, Enum.Material.Neon)
	p.CanCollide = false
	return p
end

local function lamp(parent, pos, color, range, brightness)
	local anchor = part(
		"Lampe",
		parent,
		Vector3.new(2.4, 0.5, 2.4),
		CFrame.new(pos),
		color,
		Enum.Material.Neon
	)
	anchor.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Parent = anchor
	return anchor
end

-- UN CONTENEUR N'EST PAS UNE BOITE. Cinq nervures et deux battants, et la
-- meme part se lit comme de la tole pliee au lieu d'un cube peint. C'est
-- exactement la lecon des armes : la silhouette d'abord, les details ensuite,
-- mais sans les details la silhouette ne raconte rien.
local function container(name, parent, pos, yaw, len, color, hasDoors)
	local h, w = 10, 9
	-- `CorrodedMetal` PORTE SA PROPRE ROUILLE et la peint par-dessus la
	-- couleur : les conteneurs turquoise et gris sortaient orange comme les
	-- autres, et les six piles se ressemblaient toutes. Vu a l'ecran. La
	-- rouille est donc reservee a ceux qui sont censes etre rouilles.
	local mat = if color == RUST then Enum.Material.CorrodedMetal else Enum.Material.Metal
	local body = part(
		name,
		parent,
		Vector3.new(len, h, w),
		CFrame.new(pos) * CFrame.Angles(0, yaw, 0),
		color,
		mat
	)
	local ribs = math.max(3, math.floor(len / 5))
	for i = 1, ribs do
		local t = (i - 0.5) / ribs - 0.5
		part(
			string.format("%sNerv%d", name, i),
			parent,
			Vector3.new(0.7, h - 1.2, w + 0.5),
			CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.new(t * len, 0, 0),
			color,
			mat
		).CanCollide =
			false
	end
	for _, dy in { -1, 1 } do
		part(
			string.format("%sLisse%d", name, dy),
			parent,
			Vector3.new(len + 0.4, 1.1, w + 0.7),
			CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, dy * (h / 2 - 0.5), 0),
			DECK_DARK,
			Enum.Material.Metal
		).CanCollide =
			false
	end
	if hasDoors then
		for _, dz in { -1, 1 } do
			part(
				string.format("%sPorte%d", name, dz),
				parent,
				Vector3.new(0.5, h - 1.6, w / 2 - 0.6),
				CFrame.new(pos)
					* CFrame.Angles(0, yaw, 0)
					* CFrame.new(len / 2 + 0.2, 0, dz * (w / 4)),
				STEEL,
				Enum.Material.DiamondPlate
			).CanCollide =
				false
		end
	end
	return body
end

-- ===== Le pont et la coque ==============================================
part(
	"Pont",
	decor,
	Vector3.new(HALL_X, 3, HALL_Z),
	CFrame.new(0, -1.5, 0),
	DECK,
	Enum.Material.DiamondPlate
)

-- Les joints du pont : quatre lignes claires qui donnent une echelle au sol.
-- Un sol uni de dix-huit mille studs carres ne dit rien de la distance.
for i = -3, 3 do
	part(
		string.format("Joint%d", i),
		decor,
		Vector3.new(HALL_X, 0.12, 0.6),
		CFrame.new(0, 0.06, i * 17),
		DECK_DARK,
		Enum.Material.Metal
	).CanCollide =
		false
end

for _, sx in { -1, 1 } do
	part(
		string.format("Cloison%d", sx),
		decor,
		Vector3.new(3, WALL_HEIGHT, HALL_Z + 6),
		CFrame.new(sx * (HALL_X / 2 + 1.5), WALL_HEIGHT / 2, 0),
		DECK_DARK,
		Enum.Material.DiamondPlate
	)
end
for _, sz in { -1, 1 } do
	part(
		string.format("Flanc%d", sz),
		decor,
		Vector3.new(HALL_X + 6, WALL_HEIGHT, 3),
		CFrame.new(0, WALL_HEIGHT / 2, sz * (HALL_Z / 2 + 1.5)),
		DECK_DARK,
		Enum.Material.DiamondPlate
	)
	-- LA BAIE SUR LE VIDE. C'est elle qui dit « orbite » plutot que « hangar
	-- d'usine » : sans une fenetre, de l'acier sombre est de l'acier sombre.
	for i = -3, 3 do
		part(
			string.format("Baie%d_%d", sz, i),
			decor,
			Vector3.new(14, 16, 1),
			CFrame.new(i * 18, 26, sz * (HALL_Z / 2 + 1.4)),
			Color3.fromRGB(14, 18, 28),
			Enum.Material.Glass
		).Transparency =
			0.72
		part(
			string.format("Meneau%d_%d", sz, i),
			decor,
			Vector3.new(1.2, 17, 2),
			CFrame.new(i * 18 - 7, 26, sz * (HALL_Z / 2 + 1.4)),
			STEEL
		).CanCollide =
			false
	end
end

-- Les fermes du plafond : ouvertes, pour qu'on voie les etoiles. Un plafond
-- plein transformerait la soute en boite fermee, et on ne saurait plus qu'on
-- est en orbite.
-- LES FERMES SONT SOMBRES. En acier clair elles lisaient presque blanches
-- et tiraient l'oeil vers le plafond, c'est-a-dire hors du terrain. Le
-- plafond doit se deviner, pas se regarder.
for i = -4, 4 do
	part(
		string.format("Ferme%d", i),
		decor,
		Vector3.new(4, 2.2, HALL_Z + 6),
		CFrame.new(i * 16, WALL_HEIGHT - 1, 0),
		DECK_DARK
	).CanCollide =
		false
	for _, sz in { -1, 1 } do
		part(
			string.format("Jambe%d_%d", i, sz),
			decor,
			Vector3.new(2.4, 10, 2.4),
			CFrame.new(i * 16, WALL_HEIGHT - 6, sz * (HALL_Z / 2 - 2))
				* CFrame.Angles(sz * 0.2, 0, 0),
			DECK_DARK
		).CanCollide =
			false
	end
end

-- ===== Les deux coursives ================================================
-- A QUATORZE STUDS, LE LONG DES GRANDS COTES. Elles voient tout le sol, et
-- elles ne se voient PAS l'une l'autre : la passerelle centrale coupe la
-- ligne, et c'est pour ca qu'elle vaut d'etre prise.
for _, sz in { -1, 1 } do
	local z = sz * 48
	part(
		string.format("Coursive%d", sz),
		decor,
		Vector3.new(HALL_X - 10, 1.6, 12),
		CFrame.new(0, DECK_HEIGHT, z),
		STEEL,
		Enum.Material.DiamondPlate
	)
	neon(
		string.format("LisereCoursive%d", sz),
		decor,
		Vector3.new(HALL_X - 10, 0.3, 0.6),
		CFrame.new(0, DECK_HEIGHT + 0.9, z - sz * 5.8),
		NEON_AMBER
	)
	-- LA RAMBARDE EST BASSE, ET LE CHIFFRE A ETE MESURE. L'oeil d'un
	-- personnage debout est a cinq studs de ses pieds, soit 19,8 ici. A 18,2
	-- la main courante coupait encore la vue vers le sol : un rayon tire de
	-- la coursive vers le centre tapait dans son propre montant. A 17 elle
	-- laisse deux studs de marge, et elle protege toujours a mi-cuisse.
	for i = -6, 6 do
		part(
			string.format("Montant%d_%d", sz, i),
			decor,
			Vector3.new(0.5, 2.4, 0.5),
			CFrame.new(i * 11, DECK_HEIGHT + 2, z - sz * 5.6),
			STEEL_LIGHT
		).CanCollide =
			false
	end
	part(
		string.format("Lisse%d", sz),
		decor,
		Vector3.new(HALL_X - 10, 0.5, 0.5),
		CFrame.new(0, DECK_HEIGHT + 3, z - sz * 5.6),
		STEEL_LIGHT
	).CanCollide =
		false
	-- Le dessous : une poutre et des poteaux, sinon la coursive flotte.
	part(
		string.format("Poutre%d", sz),
		decor,
		Vector3.new(HALL_X - 10, 2, 2),
		CFrame.new(0, DECK_HEIGHT - 2, z),
		DECK_DARK
	).CanCollide =
		false
	for i = -3, 3 do
		part(
			string.format("Poteau%d_%d", sz, i),
			cover,
			Vector3.new(2.2, DECK_HEIGHT, 2.2),
			CFrame.new(i * 20, DECK_HEIGHT / 2, z),
			DECK_DARK
		)
	end

	-- QUATRE ESCALIERS, DEUX PAR CAMP, AUX DEUX EXTREMITES. Avec un seul par
	-- coursive, on campe la cage d'escalier et la hauteur devient imprenable.
	for _, sx in { -1, 1 } do
		for s = 1, DECK_HEIGHT do
			part(
				string.format("Marche%d_%d_%d", sz, sx, s),
				decor,
				Vector3.new(2.6, 1, 9),
				CFrame.new(sx * (HALL_X / 2 - 9) - sx * 0, s - 0.5, z - sz * (10 + s * 1.6)),
				STEEL
			)
		end
		part(
			string.format("Palier%d_%d", sz, sx),
			decor,
			Vector3.new(10, 1.6, 10),
			CFrame.new(sx * (HALL_X / 2 - 9), DECK_HEIGHT, z - sz * 2),
			STEEL,
			Enum.Material.DiamondPlate
		)
	end
end

-- ===== Les deux passerelles =============================================
-- DEUX, ET AUCUNE AU-DESSUS DU CENTRE. Il y en avait une seule, sur l'axe,
-- et la mesure l'a condamnee : un rayon tire d'une coursive vers le centre
-- tapait dans la passerelle elle-meme. Or le dernier cercle de la zone fait
-- seize studs et il est exactement la. Les deux coursives devenaient donc
-- aveugles au moment ou tout se joue, et la map entiere se resumait a tenir
-- une planche.
--
-- Ecartees de dix-huit studs de chaque cote, elles rendent le centre visible
-- d'en haut, elles donnent DEUX facons de passer d'une coursive a l'autre —
-- donc aucun goulot — et chacune reste une position de force, a egale
-- distance des deux camps puisqu'elles sont sur l'axe perpendiculaire.
for _, sx in { -1, 1 } do
	local px = sx * 18
	part(
		string.format("Passerelle%d", sx),
		decor,
		Vector3.new(9, 1.4, 96),
		CFrame.new(px, DECK_HEIGHT, 0),
		STEEL_LIGHT,
		Enum.Material.DiamondPlate
	)
	for i = -8, 8 do
		for _, dx in { -1, 1 } do
			part(
				string.format("Garde%d_%d_%d", sx, i, dx),
				decor,
				Vector3.new(0.4, 2.3, 0.4),
				CFrame.new(px + dx * 4.3, DECK_HEIGHT + 1.9, i * 5.6),
				STEEL_LIGHT
			).CanCollide =
				false
		end
	end
	for _, dx in { -1, 1 } do
		part(
			string.format("Main%d_%d", sx, dx),
			decor,
			Vector3.new(0.4, 0.4, 96),
			CFrame.new(px + dx * 4.3, DECK_HEIGHT + 2.9, 0),
			STEEL_LIGHT
		).CanCollide =
			false
		neon(
			string.format("LisereP%d_%d", sx, dx),
			decor,
			Vector3.new(0.5, 0.25, 96),
			CFrame.new(px + dx * 4.1, DECK_HEIGHT + 0.8, 0),
			NEON_TEAL
		)
	end
	-- Les piles : elles portent la passerelle ET elles couvrent au sol. Deux
	-- par passerelle, assez ecartees pour qu'on ne les contourne pas d'un pas.
	for _, sz in { -1, 1 } do
		part(
			string.format("PiedPasserelle%d_%d", sx, sz),
			cover,
			Vector3.new(4.5, DECK_HEIGHT, 4.5),
			CFrame.new(px, DECK_HEIGHT / 2, sz * 26),
			DECK_DARK
		)
	end
end

-- ===== Les conteneurs ===================================================
-- LA ROUTE BASSE. Deux blocs par camp, ecartes pour laisser trois passages :
-- le long du mur, entre les deux blocs, et par le centre. Un bloc plein
-- n'offrirait qu'un contour, donc qu'un seul chemin.
-- AUCUNE PILE AU-DELA DE 34 EN Z, et c'est une correction trouvee en montant
-- sur la coursive : deux piles doubles montaient a vingt studs juste sous
-- elle, donc depuis la position haute on ne voyait plus le sol — que de la
-- tole rouillee a hauteur d'oeil. Une position haute qui ne voit rien n'est
-- pas une position, c'est un cul-de-sac.
local STACKS = {
	-- x, z, longueur, rotation en quarts, empile, couleur
	{ 44, 24, 24, 0, true, RUST },
	{ 26, 33, 18, 0, false, CRATE_TEAL },
	{ 20, 12, 20, 1, true, CRATE_GREY },
	{ 48, -10, 20, 1, false, CRATE_AMBER },
	{ 34, -30, 26, 0, true, CRATE_TEAL },
	{ 56, -33, 16, 0, false, RUST },
}
for i, c in STACKS do
	for _, sgn in { 1, -1 } do
		-- La symetrie est une ROTATION de 180 degres, pas un miroir : un
		-- miroir donnerait deux camps qui tournent dans des sens opposes, et
		-- ce qu'un joueur apprend d'un cote ne servirait pas de l'autre.
		local x, z = c[1] * sgn, c[2] * sgn
		local yaw = c[4] * math.pi / 2 + (if sgn < 0 then math.pi else 0)
		container(
			string.format("Caisse%d_%d", i, sgn),
			cover,
			Vector3.new(x, 5, z),
			yaw,
			c[3],
			c[6],
			i % 2 == 0
		)
		if c[5] then
			container(
				string.format("Caisse%d_%dB", i, sgn),
				cover,
				Vector3.new(x + 1.5 * sgn, 15, z),
				yaw + 0.04,
				c[3] - 4,
				if c[6] == RUST then CRATE_GREY else RUST,
				false
			)
		end
	end
end

-- LES DEUX PILES DE L'AXE. Sans elles les deux departs se voient en ligne
-- droite sur cent vingt studs, et un fusil de precision decide la manche
-- avant que quiconque ait bouge. Elles sont a vingt studs du centre : juste
-- en dehors du dernier cercle de la zone, qui fait seize.
for _, sx in { -1, 1 } do
	container(
		string.format("Axe%d", sx),
		cover,
		Vector3.new(sx * 21, 5, 0),
		math.pi / 2,
		22,
		CRATE_AMBER,
		true
	)
	container(
		string.format("Axe%dB", sx),
		cover,
		Vector3.new(sx * 21, 15, 1.5 * sx),
		math.pi / 2,
		16,
		CRATE_GREY,
		false
	)
end

-- ===== Les caisses basses du centre =====================================
-- Le dernier cercle de la zone fait seize studs et il est juste sous la
-- passerelle : sans rien dedans, la fin de manche serait un echange a
-- decouvert sous quelqu'un qui tire d'en haut.
for i, c in { { 9, 7, 0.5 }, { -10, 6, -0.3 }, { 6, -11, 0.9 }, { -7, -9, -1.1 } } do
	part(
		string.format("Futaille%d", i),
		cover,
		Vector3.new(6, 4.5, 6),
		CFrame.new(c[1], 2.25, c[2]) * CFrame.Angles(0, c[3], 0),
		if i % 2 == 0 then CRATE_GREY else RUST,
		Enum.Material.CorrodedMetal
	)
	part(
		string.format("FutailleCercle%d", i),
		cover,
		Vector3.new(6.3, 0.6, 6.3),
		CFrame.new(c[1], 3.6, c[2]) * CFrame.Angles(0, c[3], 0),
		HAZARD
	).CanCollide =
		false
end

-- ===== Le portique de grue ==============================================
-- Pur decor, mais c'est lui qui remplit le volume au-dessus de la
-- passerelle : sans rien entre quatorze et quarante studs, la soute parait
-- deux fois trop haute.
part("Rail1", decor, Vector3.new(HALL_X - 10, 2, 3), CFrame.new(0, 30, -34), STEEL).CanCollide =
	false
part("Rail2", decor, Vector3.new(HALL_X - 10, 2, 3), CFrame.new(0, 30, 34), STEEL).CanCollide =
	false
part("Portique", decor, Vector3.new(6, 3, 76), CFrame.new(-14, 31, 0), STEEL_LIGHT).CanCollide =
	false
part("Chariot", decor, Vector3.new(9, 4, 9), CFrame.new(-14, 28, 10), HAZARD).CanCollide = false
part("Cable", decor, Vector3.new(0.4, 12, 0.4), CFrame.new(-14, 21, 10), DECK_DARK).CanCollide =
	false
part("Crochet", decor, Vector3.new(3, 2.5, 3), CFrame.new(-14, 15.5, 10), STEEL_LIGHT).CanCollide =
	false

-- ===== Les departs ======================================================
for _, side in { -1, 1 } do
	local team = if side < 0 then "A" else "B"
	local tint = if side < 0 then COLOR_A else COLOR_B
	local x = side * SPAWN_X

	-- Le sas : un renfoncement eclaire dans la cloison du fond. Il dit d'ou
	-- on vient et il protege les trois premieres secondes.
	part(
		"Sas" .. team,
		decor,
		Vector3.new(14, 22, 34),
		CFrame.new(x + side * 8, 11, 0),
		DECK_DARK,
		Enum.Material.DiamondPlate
	)
	for _, dz in { -1, 1 } do
		part(
			string.format("Montant%s%d", team, dz),
			decor,
			Vector3.new(16, 22, 3),
			CFrame.new(x + side * 8, 11, dz * 17),
			STEEL
		)
	end
	part("Linteau" .. team, decor, Vector3.new(16, 3, 34), CFrame.new(x + side * 8, 21, 0), STEEL)
	neon(
		"Enseigne" .. team,
		decor,
		Vector3.new(0.4, 2.4, 26),
		CFrame.new(x + side * 0.5, 19, 0),
		tint
	)
	lamp(decor, Vector3.new(x + side * 6, 17, 0), tint, 34, 2.4)

	-- Deux blocs devant le sas : on ne commence pas a decouvert, et ils
	-- separent les deux sorties.
	for _, dz in { -1, 1 } do
		container(
			string.format("Garde%s%d", team, dz),
			cover,
			Vector3.new(x - side * 13, 5, dz * 15),
			0,
			18,
			CRATE_GREY,
			false
		)
	end
	-- Bande d'avertissement au sol : elle marque la limite du camp, ce qui
	-- aide a lire ou on en est quand la zone se referme.
	neon(
		"Seuil" .. team,
		decor,
		Vector3.new(0.8, 0.12, 30),
		CFrame.new(x - side * 4, 0.08, 0),
		tint
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
		marker.Position = Vector3.new(x + side * 3, 4, (i - 3) * 6)
		marker.Parent = folder
	end
end

-- ===== Les lampes =======================================================
-- Huit, pas quarante : chaque PointLight coute, et le neon des liseres fait
-- deja le dessin. Les lampes servent a poser trois zones de clarte sur le
-- sol, pour qu'on sache ou on est sans regarder en haut.
for _, sz in { -1, 1 } do
	for _, sx in { -2, -1, 0, 1, 2 } do
		lamp(decor, Vector3.new(sx * 30, 24, sz * 34), Color3.fromRGB(230, 222, 204), 48, 1.5)
	end
end
lamp(decor, Vector3.new(0, 24, 0), NEON_TEAL, 44, 1.4)
for _, sx in { -1, 1 } do
	lamp(decor, Vector3.new(sx * 50, 10, 0), Color3.fromRGB(226, 218, 200), 30, 1.1)
end

-- DEUX BANDES AU SOL, le long des deux voies laterales. Elles ne sont pas de
-- la decoration : dans une soute noire, un joueur ne sait pas dans quelle
-- travee il court. Une ligne turquoise au sol repond a la question sans
-- qu'on leve les yeux, et elle ne coute aucune lumiere.
for _, sz in { -1, 1 } do
	neon(
		string.format("Voie%d", sz),
		decor,
		Vector3.new(HALL_X - 24, 0.1, 1.2),
		CFrame.new(0, 0.1, sz * 34),
		NEON_TEAL
	)
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
-- L'AMBIANCE EST UN REGLAGE DE PLACE, donc elle appartient a la map qui
-- tourne : chaque script de map pose la sienne entierement, et lancer un
-- autre script la remplace. Ici : nuit noire, pas de soleil, des etoiles.
Lighting.ClockTime = 0
-- L'AMBIANT PORTE TOUTE LA LUMIERE ICI. Il n'y a pas de soleil dans le vide,
-- donc `Brightness` ne sert a rien : sans un ambiant eleve, la soute etait
-- noire et on ne voyait que les neons. Regarde a l'ecran avant d'y toucher.
Lighting.Brightness = 0.4
Lighting.Ambient = Color3.fromRGB(44, 50, 62)
Lighting.OutdoorAmbient = Color3.fromRGB(34, 40, 52)
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
local sky = Instance.new("Sky")
sky.CelestialBodiesShown = false
sky.StarCount = 7000
sky.Parent = Lighting
-- PAS D'ATMOSPHERE : on est dans le vide. Avec elle, Roblox dessine un
-- horizon bleu lumineux tout autour de la soute — vu a l'ecran, ca ressemble
-- a du fond marin, pas a l'espace. C'est le seul endroit des trois maps ou
-- l'absence est le bon reglage.
local bloom = Instance.new("BloomEffect")
-- Un bloom trop fort transformait chaque lisere en tache blanche et effacait
-- le dessin qu'ils sont censes tracer.
bloom.Intensity = 0.38
bloom.Size = 22
bloom.Threshold = 1.15
bloom.Parent = Lighting
local grade = Instance.new("ColorCorrectionEffect")
grade.Saturation = 0.1
grade.Contrast = 0.14
grade.TintColor = Color3.fromRGB(226, 236, 255)
grade.Parent = Lighting

print(string.format("[Arena] Cargo construit : %d parts.", #map:GetDescendants()))
