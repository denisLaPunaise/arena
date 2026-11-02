--!nolint
--[[
	BuildCarriereMap — « La Carriere ». A coller dans la barre de commande.

	POURQUOI CE FICHIER EXISTE
	Les maps vivent dans Workspace, que Rojo ne touche pas, et le .rbxl n'est
	pas dans Git. Ce script est la seule sauvegarde de la map. Il detruit les
	autres avant de construire : deux maps dans Workspace seraient un tirage au
	sort, puisque `MapService` prend la PREMIERE qui respecte le contrat.

	CE N'EST PAS DU CODE DE JEU : hors du projet Rojo, jamais execute en
	partie, pas verifie par Selene ni StyLua.

	CE QU'ELLE RACONTE
	Une carriere de glace a l'aube, par temps couvert. Trois gradins taillles
	dans la roche noire, un lac gele au fond, et au centre un chevalement
	d'extraction rouille qui tient tout le dessin : c'est lui qu'on voit de
	partout, et c'est lui qui dit ou est le milieu. Pas un gramme de sable, pas
	un neon, pas une feuille — le contraire des trois autres.

	CE QU'ELLE FAIT JOUER, et c'est une question qu'aucune des trois autres ne
	pose : ON DESCEND VITE, ON REMONTE LENTEMENT.

	- LA MARGELLE, a vingt-quatre studs, fait le tour complet. Les deux camps
	  y partent, face a face. De la on voit tout le fond.
	- On DESCEND de n'importe ou, en se laissant tomber : douze studs vers un
	  gradin sur les cotes des camps, vingt-quatre d'un coup vers le lac sur
	  les deux autres cotes. C'est gratuit et instantane.
	- On REMONTE par quatre rampes seulement, longues, nues, et placees en
	  DIAGONALE l'une de l'autre : la rampe qui sort du lac est a l'autre bout
	  du gradin que celle qui mene a la margelle. Revenir en haut veut donc
	  dire traverser tout un gradin a decouvert, sous les yeux de ceux qui sont
	  restes en haut.
	- LA PASSERELLE enjambe la carriere de part en part, au niveau de la
	  margelle et sous le chevalement. Elle est etroite et vue de tout le fond.
	  C'est le seul moyen de changer de cote sans descendre, et elle se paie.

	Descendre est donc un ENGAGEMENT. La zone se referme sur le lac, alors tout
	le monde finit par devoir le prendre ; la question est quand, et avec qui.

	LA SYMETRIE EST DE ROTATION, PAS DE MIROIR. Les quatre rampes forment deux
	paires opposees : la map se superpose a elle-meme en tournant d'un
	demi-tour, donc les deux camps ont exactement le meme chemin. Un miroir
	aurait donne a un camp la rampe de gauche et a l'autre celle de droite, ce
	qui n'est pas la meme chose quand on tire en courant.

	LA TAILLE
	La fosse fait 148 studs de cote, MapBounds un carre de 160. La zone demarre
	a 80 de rayon : elle couvre les deux departs, et elle mord les quatre coins
	de la margelle — c'est voulu, les coins sont du decor.

	CE QU'ELLE SE MESURE ELLE-MEME
	La fin du fichier lance des rayons et imprime ce qu'elle trouve : les lignes
	de tir entre les deux departs, la couverture autour du centre, et le SENS de
	chaque rampe. Les trois defauts de jeu trouves dans les maps du 29 octobre
	l'ont tous ete au rayon, aucun en regardant — alors la map le fait toute
	seule, a chaque construction, et imprime un verdict.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

-- ===== Les cotes de la fosse ============================================
-- Tout le reste se deduit de ces six chiffres. Un gradin deplace, et les
-- rampes, les murs et les departs suivent : c'est la regle de Config.luau
-- appliquee a de la geometrie.
local RIM_OUT = 74 -- bord exterieur de la margelle
local RIM_IN = 58 -- bord interieur : la-dessous, c'est le vide
local LEDGE_IN = 38 -- bord interieur des gradins, et bord du lac
local RIM_Y = 24 -- dessus de la margelle
local LEDGE_Y = 12 -- dessus des gradins
local BOUNDS = 160

local SPAWN_X = RIM_OUT - 8 -- 66 : au milieu de la margelle
local SPAWN_Y = RIM_Y + 4 -- comme les trois autres maps : quatre au-dessus du sol
local SPAWN_SPREAD = 4 -- cinq points de -8 a +8

-- Les deux rampes du bas sortent du lac en z = +RAMP_Z cote ouest, et en
-- -RAMP_Z cote est ; les deux rampes du haut font l'inverse. C'est ce
-- croisement qui oblige a traverser le gradin pour remonter.
local RAMP_Z = 30
local RAMP_RUN = 22 -- longueur au sol d'une rampe
local RAMP_WIDE = 9

local ICE = Color3.fromRGB(196, 216, 230)
local ICE_DEEP = Color3.fromRGB(118, 150, 176)
local LAKE = Color3.fromRGB(168, 196, 214)
local SNOW = Color3.fromRGB(236, 242, 248)
local ROCK = Color3.fromRGB(62, 66, 74)
local ROCK_DARK = Color3.fromRGB(40, 43, 50)
local ROCK_LIGHT = Color3.fromRGB(94, 100, 110)
local STEEL = Color3.fromRGB(96, 104, 116)
local STEEL_DARK = Color3.fromRGB(56, 62, 72)
local TIMBER = Color3.fromRGB(104, 80, 58)
local SODIUM = Color3.fromRGB(255, 198, 128)
local HAZARD = Color3.fromRGB(226, 182, 64)
local COLOR_A = Color3.fromRGB(70, 130, 230)
local COLOR_B = Color3.fromRGB(230, 80, 70)

for _, name in { "ArenaMap", "ColiseeMap", "CargoMap", "SanctuaireMap", "CarriereMap" } do
	local old = Workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
-- La map apporte son sol : la Baseplate est a la meme hauteur que le lac et
-- gagne un pixel sur deux. Le point d'apparition par defaut part avec elle,
-- sinon il pose un joueur hors des deux camps.
for _, name in { "Baseplate", "SpawnLocation" } do
	local old = Workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

local map = Instance.new("Folder")
map.Name = "CarriereMap"
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
	p.Color = color or ROCK
	p.Material = material or Enum.Material.Slate
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
	p.Color = color or ROCK
	p.Material = material or Enum.Material.Slate
	p.Parent = parent
	return p
end

local function lamp(parent, pos, color, range, brightness)
	local anchor = part(
		"Projecteur",
		parent,
		Vector3.new(2.6, 1, 2.6),
		CFrame.new(pos),
		color,
		Enum.Material.Neon
	)
	anchor.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = true
	light.Parent = anchor
	return anchor
end

--------------------------------------------------------------------------------
-- LA FOSSE
--------------------------------------------------------------------------------

-- LE LAC. Une seule dalle, et c'est la plus grande surface de jeu de la map :
-- la zone s'y referme, donc c'est la qu'on finit. `Ice` porte sa propre teinte
-- bleue, comme `CorrodedMetal` porte sa rouille — ici c'est exactement ce
-- qu'on veut, donc la couleur reste proche de ce que la matiere fait seule.
local lakeSpan = RIM_IN * 2
part(
	"Lac",
	map,
	Vector3.new(LEDGE_IN * 2, 4, lakeSpan),
	CFrame.new(0, -2, 0),
	LAKE,
	Enum.Material.Ice
)

-- Les fissures du lac : trois traits plus sombres, a peine en creux. Sans
-- elles la dalle est un aplat de 76 sur 116 et l'oeil n'a rien pour mesurer
-- la distance.
for index, line in { { -16, -6 }, { 8, 3 }, { -2, 14 } } do
	local p = part(
		string.format("Fissure%d", index),
		decor,
		Vector3.new(1.4, 0.3, lakeSpan - 20),
		CFrame.new(line[1], 0.02, line[2]) * CFrame.Angles(0, math.rad(line[1] * 0.4), 0),
		ICE_DEEP,
		Enum.Material.Ice
	)
	p.CanCollide = false
end

-- LES DEUX GRADINS, sur les cotes des camps. Massifs du fond jusqu'a leur
-- dessus : un gradin creux laisserait voir sous lui depuis le lac.
for _, side in { -1, 1 } do
	local width = RIM_IN - LEDGE_IN
	local centre = side * (LEDGE_IN + width / 2)
	part(
		string.format("Gradin%d", side),
		map,
		Vector3.new(width, LEDGE_Y + 8, lakeSpan),
		CFrame.new(centre, (LEDGE_Y - 8) / 2, 0),
		ROCK,
		Enum.Material.Slate
	)
	-- La neige du dessus, en lamelle posee : elle ne change rien au jeu et
	-- c'est elle qui fait lire « carriere » et pas « bunker ».
	local snow = part(
		string.format("NeigeGradin%d", side),
		decor,
		Vector3.new(width - 3, 0.4, lakeSpan - 8),
		CFrame.new(centre, LEDGE_Y + 0.2, 0),
		SNOW,
		Enum.Material.Snow
	)
	snow.CanCollide = false
end

-- LA MARGELLE. Quatre masses, et les deux grands cotes portent la totalite de
-- la largeur pour que les coins soient pleins.
for _, side in { -1, 1 } do
	local width = RIM_OUT - RIM_IN
	local centre = side * (RIM_IN + width / 2)
	part(
		string.format("MargelleZ%d", side),
		map,
		Vector3.new(RIM_OUT * 2, RIM_Y + 8, width),
		CFrame.new(0, (RIM_Y - 8) / 2, centre),
		ROCK,
		Enum.Material.Slate
	)
	part(
		string.format("MargelleX%d", side),
		map,
		Vector3.new(width, RIM_Y + 8, RIM_IN * 2),
		CFrame.new(centre, (RIM_Y - 8) / 2, 0),
		ROCK,
		Enum.Material.Slate
	)
end

-- La neige de la margelle, et le lisere de roche claire a l'arete : c'est lui
-- qui dessine le bord du vide. Un bord qu'on ne voit pas est un bord ou on
-- tombe par accident, et tomber doit etre un choix sur cette map.
for _, side in { -1, 1 } do
	local snowZ = part(
		string.format("NeigeZ%d", side),
		decor,
		Vector3.new(RIM_OUT * 2 - 6, 0.4, RIM_OUT - RIM_IN - 4),
		CFrame.new(0, RIM_Y + 0.2, side * (RIM_IN + (RIM_OUT - RIM_IN) / 2)),
		SNOW,
		Enum.Material.Snow
	)
	snowZ.CanCollide = false
	local snowX = part(
		string.format("NeigeX%d", side),
		decor,
		Vector3.new(RIM_OUT - RIM_IN - 4, 0.4, RIM_IN * 2 - 6),
		CFrame.new(side * (RIM_IN + (RIM_OUT - RIM_IN) / 2), RIM_Y + 0.2, 0),
		SNOW,
		Enum.Material.Snow
	)
	snowX.CanCollide = false

	local edgeZ = part(
		string.format("AreteZ%d", side),
		decor,
		Vector3.new(RIM_IN * 2, 0.6, 1.6),
		CFrame.new(0, RIM_Y + 0.3, side * RIM_IN),
		ROCK_LIGHT,
		Enum.Material.Rock
	)
	edgeZ.CanCollide = false
	local edgeX = part(
		string.format("AreteX%d", side),
		decor,
		Vector3.new(1.6, 0.6, RIM_IN * 2),
		CFrame.new(side * RIM_IN, RIM_Y + 0.3, 0),
		ROCK_LIGHT,
		Enum.Material.Rock
	)
	edgeX.CanCollide = false
end

-- LES STRATES DES PAROIS. La roche d'une carriere est taillee par passes, et
-- sans ces lignes une paroi de vingt-quatre studs est un mur gris. Elles ne
-- depassent que de vingt centimetres : rien ne s'y accroche, rien ne s'y
-- cache.
for _, side in { -1, 1 } do
	for level = 1, 5 do
		local y = level * 4
		local p = part(
			string.format("StrateZ%d_%d", side, level),
			decor,
			Vector3.new(RIM_IN * 2, 0.5, 0.5),
			CFrame.new(0, y, side * (RIM_IN - 0.2)),
			ROCK_DARK,
			Enum.Material.Rock
		)
		p.CanCollide = false
	end
	for level = 1, 2 do
		local y = level * 4
		local p = part(
			string.format("StrateX%d_%d", side, level),
			decor,
			Vector3.new(0.5, 0.5, lakeSpan - 4),
			CFrame.new(side * (LEDGE_IN - 0.2), y, 0),
			ROCK_DARK,
			Enum.Material.Rock
		)
		p.CanCollide = false
	end
end

--------------------------------------------------------------------------------
-- LES QUATRE RAMPES
--------------------------------------------------------------------------------

-- UN SENS DE RAMPE NE SE RELIT PAS, IL SE MESURE. Une rampe du Sanctuaire
-- etait posee a l'envers le 29 octobre et ca ne se voyait sur aucune capture.
-- Donc : le raisonnement est ecrit, les deux bouts sont donnes en toutes
-- lettres au lieu d'etre calcules par un signe, et la fin du fichier verifie
-- au rayon que le sol monte vraiment.
--
-- Le calcul, une fois pour les deux sens. Une part tournee de `roll` autour de
-- Z amene son bout +X local sur (cos roll, sin roll, 0) ; on veut que ce bout
-- tombe sur le HAUT de la rampe, donc (cos, sin) doit valoir (run, rise)
-- normalise, d'ou `roll = atan2(rise, run)` avec un `run` SIGNE. Pour une
-- rampe qui court en Z, la rotation est autour de X et le bout +Z local part
-- sur (0, -sin pitch, cos pitch), d'ou `pitch = atan2(-rise, run)`.

local ramps = {}

local function rampDeck(name, size, cf, alongX, low, high, rise)
	part(name, map, size, cf, ROCK_LIGHT, Enum.Material.Concrete)
	table.insert(ramps, { name = name, low = low, high = high, rise = rise })

	-- Les deux bordures : elles empechent de glisser hors de la rampe en
	-- courant, et elles la rendent VISIBLE d'en haut. Une rampe qu'on ne
	-- trouve pas est une rampe qui n'existe pas.
	--
	-- `alongX` DIT SUR QUEL AXE LOCAL LA RAMPE EST LONGUE, et il fallait le
	-- dire : une bordure posee sur l'axe de la longueur au lieu de celui de la
	-- largeur traverse la rampe au milieu au lieu de la border. On pose donc
	-- chaque bordure dans le repere de la rampe elle-meme, par un produit de
	-- CFrame, et pas en recalculant ses axes a cote.
	for _, edge in { -1, 1 } do
		local offset = if alongX
			then CFrame.new(0, 1.1, edge * RAMP_WIDE / 2)
			else CFrame.new(edge * RAMP_WIDE / 2, 1.1, 0)
		local length = if alongX then size.X else size.Z
		local kerb = part(
			string.format("%sBordure%d", name, edge),
			decor,
			if alongX then Vector3.new(length, 0.7, 0.8) else Vector3.new(0.8, 0.7, length),
			cf * offset,
			HAZARD,
			Enum.Material.Concrete
		)
		kerb.CanCollide = false
	end
end

-- UNE RAMPE QUI COURT EN X : du lac vers un gradin. Vingt-deux studs de course
-- pour douze de montee, posee sur le lac et appuyee contre la paroi.
local function rampX(name, lowX, highX, z, baseY, rise)
	local run = highX - lowX
	local length = math.sqrt(run * run + rise * rise)
	local roll = math.atan2(rise, run)
	rampDeck(
		name,
		Vector3.new(length, 1.6, RAMP_WIDE),
		CFrame.new((lowX + highX) / 2, baseY + rise / 2, z) * CFrame.Angles(0, 0, roll),
		true,
		Vector3.new(lowX, baseY, z),
		Vector3.new(highX, baseY + rise, z),
		rise
	)
end

-- UNE RAMPE QUI COURT EN Z : du gradin vers la margelle. Elle ne peut PAS
-- courir en X comme celle du bas — le gradin ne fait que vingt studs de large,
-- et il en faudrait vingt-deux. Elle longe donc la paroi sur toute sa
-- longueur, et on debouche sur la margelle par le cote. C'est ce qui rend la
-- remontee longue, et c'est l'idee de la map.
local function rampZ(name, x, lowZ, highZ, baseY, rise)
	local run = highZ - lowZ
	local length = math.sqrt(run * run + rise * rise)
	local pitch = math.atan2(-rise, run)
	rampDeck(
		name,
		Vector3.new(RAMP_WIDE, 1.6, length),
		CFrame.new(x, baseY + rise / 2, (lowZ + highZ) / 2) * CFrame.Angles(pitch, 0, 0),
		false,
		Vector3.new(x, baseY, lowZ),
		Vector3.new(x, baseY + rise, highZ),
		rise
	)
end

-- LES QUATRE, et leur croisement. Du lac vers le gradin : ouest en z positif,
-- est en z negatif. Du gradin vers la margelle : L'INVERSE. Sortir du lac a
-- l'ouest depose donc en z = +30, et la rampe suivante part de z = -41 :
-- soixante-dix studs de gradin a decouvert entre les deux.
local LEDGE_LANE = RIM_IN - RAMP_WIDE / 2 - 0.5 -- 53 : la voie collee a la paroi

rampX("RampeBasOuest", -(LEDGE_IN - RAMP_RUN), -LEDGE_IN, RAMP_Z, 0, LEDGE_Y)
rampX("RampeBasEst", LEDGE_IN - RAMP_RUN, LEDGE_IN, -RAMP_Z, 0, LEDGE_Y)

rampZ("RampeHautOuest", -LEDGE_LANE, -RAMP_Z - 11, -RAMP_Z + 11, LEDGE_Y, RIM_Y - LEDGE_Y)
rampZ("RampeHautEst", LEDGE_LANE, RAMP_Z + 11, RAMP_Z - 11, LEDGE_Y, RIM_Y - LEDGE_Y)

--------------------------------------------------------------------------------
-- LE CHEVALEMENT
--------------------------------------------------------------------------------

-- CE QUI SEPARE LES DEUX DEPARTS. Sans lui, les deux camps se voient en ligne
-- droite sur cent trente-deux studs — c'est le defaut qui a ete trouve au
-- rayon dans la map du cargo, et il est traite ici des le dessin.
--
-- La salle des molettes est posee AU-DESSUS de la margelle, de vingt-six a
-- trente-quatre studs : c'est la hauteur des yeux de quelqu'un qui part, donc
-- c'est elle qui coupe la ligne. Les quatre pieds, eux, laissent le centre du
-- lac OUVERT : la zone s'y referme, et un centre plein serait un cercle final
-- qu'on ne peut pas se disputer.
local LEG = 9
local HOUSE_Y = 26
local HOUSE_TOP = 34

for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do
		part(
			string.format("Pied%d_%d", sx, sz),
			cover,
			Vector3.new(3.2, HOUSE_Y, 3.2),
			CFrame.new(sx * LEG, HOUSE_Y / 2, sz * LEG),
			STEEL_DARK,
			Enum.Material.CorrodedMetal
		)
	end
end

-- Les croisillons. Trois etages, et ils ne portent rien : ils donnent au
-- chevalement sa silhouette d'ossature, qui est tout ce qui le distingue d'un
-- pilier. Traversables, pour qu'ils ne hachent pas le combat au fond.
for level = 1, 3 do
	local y = level * 7
	for _, sz in { -1, 1 } do
		for _, dir in { -1, 1 } do
			local p = part(
				string.format("Croisillon%d_%d_%d", level, sz, dir),
				decor,
				Vector3.new(LEG * 2.3, 0.6, 0.6),
				CFrame.new(0, y, sz * LEG) * CFrame.Angles(0, 0, dir * 0.55),
				STEEL,
				Enum.Material.CorrodedMetal
			)
			p.CanCollide = false
		end
	end
	for _, sx in { -1, 1 } do
		for _, dir in { -1, 1 } do
			local p = part(
				string.format("CroisillonZ%d_%d_%d", level, sx, dir),
				decor,
				Vector3.new(0.6, 0.6, LEG * 2.3),
				CFrame.new(sx * LEG, y, 0) * CFrame.Angles(dir * 0.55, 0, 0),
				STEEL,
				Enum.Material.CorrodedMetal
			)
			p.CanCollide = false
		end
	end
end

-- La salle des molettes, et les deux roues qui lui donnent son nom.
part(
	"SalleDesMolettes",
	map,
	Vector3.new(26, HOUSE_TOP - HOUSE_Y, 24),
	CFrame.new(0, (HOUSE_Y + HOUSE_TOP) / 2, 0),
	STEEL_DARK,
	Enum.Material.CorrodedMetal
)
for index, sz in { -1, 1 } do
	local wheel = part(
		string.format("Molette%d", index),
		decor,
		Vector3.new(2, 11, 11),
		CFrame.new(0, HOUSE_TOP + 4, sz * 6) * CFrame.Angles(0, 0, math.rad(90)),
		STEEL,
		Enum.Material.CorrodedMetal
	)
	wheel.Shape = Enum.PartType.Cylinder
	wheel.CanCollide = false
end
-- Le toit en deux pans : un cube au sommet d'une tour se lit comme une boite
-- posee, deux pentes se lisent comme un batiment.
for _, dir in { 1, -1 } do
	wedge(
		string.format("Pan%d", dir),
		decor,
		Vector3.new(26, 4, 12),
		CFrame.new(0, HOUSE_TOP + 2, dir * 6)
			* CFrame.Angles(0, if dir > 0 then 0 else math.pi, 0),
		STEEL_DARK,
		Enum.Material.CorrodedMetal
	).CanCollide =
		false
end

-- LES DEUX COULOIRS A MINERAI, du chevalement vers chaque gradin. Ils
-- descendent en pente franche, et c'est la seule diagonale de la map : tout
-- le reste est horizontal ou vertical, donc ce sont eux qui donnent l'echelle
-- de la fosse a l'oeil.
for _, side in { -1, 1 } do
	local fromX = side * 13
	local toX = side * (LEDGE_IN + 10)
	local fromY = HOUSE_Y
	local toY = LEDGE_Y + 3
	local run = toX - fromX
	local drop = toY - fromY
	local length = math.sqrt(run * run + drop * drop)
	local p = part(
		string.format("Couloir%d", side),
		decor,
		Vector3.new(length, 2.2, 6),
		CFrame.new((fromX + toX) / 2, (fromY + toY) / 2, 0)
			* CFrame.Angles(0, 0, math.atan2(drop, run)),
		STEEL,
		Enum.Material.CorrodedMetal
	)
	p.CanCollide = false
end

--------------------------------------------------------------------------------
-- LA PASSERELLE
--------------------------------------------------------------------------------

-- ELLE EST SUR L'AXE DU MILIEU, et pas decalee, parce que la map doit se
-- superposer a elle-meme en tournant d'un demi-tour. Une passerelle a x = -24
-- aurait donne un raccourci a un camp et pas a l'autre, ce qui ne se voit pas
-- sur une capture et se paie en partie.
local WALK_WIDE = 5
part(
	"Passerelle",
	map,
	Vector3.new(WALK_WIDE, 1, RIM_OUT * 2),
	CFrame.new(0, RIM_Y - 0.5, 0),
	STEEL,
	Enum.Material.DiamondPlate
)
-- Garde-corps BAS, et c'est mesure ailleurs : un garde-corps a 18,2 studs
-- bouchait la vue vers le bas depuis un oeil a 19,8 dans les maps du
-- 29 octobre. Un metre vingt laisse voir le fond.
for _, side in { -1, 1 } do
	local rail = part(
		string.format("RambardePasserelle%d", side),
		decor,
		Vector3.new(0.4, 0.3, RIM_OUT * 2),
		CFrame.new(side * (WALK_WIDE / 2), RIM_Y + 1.2, 0),
		HAZARD,
		Enum.Material.Metal
	)
	rail.CanCollide = false
	for index = -6, 6 do
		local post = part(
			string.format("PoteauPasserelle%d_%d", side, index),
			decor,
			Vector3.new(0.4, 1.2, 0.4),
			CFrame.new(side * (WALK_WIDE / 2), RIM_Y + 0.6, index * 11),
			HAZARD,
			Enum.Material.Metal
		)
		post.CanCollide = false
	end
end

--------------------------------------------------------------------------------
-- LA RAMBARDE DE LA MARGELLE
--------------------------------------------------------------------------------

-- SEULEMENT SUR LE BORD EXTERIEUR. C'est la lecon du 29 octobre, prise a
-- l'endroit : un garde-corps du cote du vide empeche de tirer vers le bas, et
-- tirer vers le bas est tout ce que la position haute achete sur cette map.
-- Dehors, il empeche de tomber de la carriere par l'arriere.
for _, side in { -1, 1 } do
	local railZ = part(
		string.format("RambardeZ%d", side),
		decor,
		Vector3.new(RIM_OUT * 2, 2.4, 0.5),
		CFrame.new(0, RIM_Y + 1.2, side * (RIM_OUT - 0.4)),
		STEEL_DARK,
		Enum.Material.Metal
	)
	railZ.CanCollide = true
	local railX = part(
		string.format("RambardeX%d", side),
		decor,
		Vector3.new(0.5, 2.4, RIM_OUT * 2),
		CFrame.new(side * (RIM_OUT - 0.4), RIM_Y + 1.2, 0),
		STEEL_DARK,
		Enum.Material.Metal
	)
	railX.CanCollide = true
end

--------------------------------------------------------------------------------
-- LES COUVERTS
--------------------------------------------------------------------------------

local function crate(name, parent, pos, size, color, material)
	return part(name, parent, size, CFrame.new(pos), color, material)
end

-- AU FOND : des blocs de glace extraits, abandonnes sur le lac. Ce sont les
-- seuls couverts du cercle final, donc ils comptent plus que tous les autres.
-- Sept, places en anneau large autour du chevalement : assez pour qu'on ait
-- toujours quelque chose a contourner, pas assez pour qu'on s'y terre.
local blocks = {
	{ -26, -34, 7, 6 },
	{ 24, -22, 6, 8 },
	{ -14, 20, 8, 6 },
	{ 22, 30, 7, 7 },
	{ -28, 6, 6, 9 },
	{ 10, -44, 8, 6 },
	{ -6, 44, 7, 7 },
}
for index, b in blocks do
	local h = 5.5 + (index % 3)
	crate(
		string.format("BlocGlace%d", index),
		cover,
		Vector3.new(b[1], h / 2, b[2]),
		Vector3.new(b[3], h, b[4]),
		ICE,
		Enum.Material.Ice
	)
	-- Un eclat couche a cote : un bloc seul se lit comme une caisse, deux
	-- morceaux se lisent comme de la glace cassee.
	local chip = part(
		string.format("Eclat%d", index),
		decor,
		Vector3.new(b[3] * 0.6, 1.1, b[4] * 0.5),
		CFrame.new(b[1] + b[3] * 0.8, 0.55, b[2] - b[4] * 0.6)
			* CFrame.Angles(0, math.rad(index * 37), 0),
		ICE,
		Enum.Material.Ice
	)
	chip.CanCollide = false
end

-- LES DEUX WAGONNETS DU FOND, a demi enfonces. Ils donnent au lac deux
-- couverts qui ne sont pas de la glace, donc deux reperes de couleur dans une
-- etendue blanche.
for _, side in { -1, 1 } do
	crate(
		string.format("Wagonnet%d", side),
		cover,
		Vector3.new(side * 30, 1.6, side * 48),
		Vector3.new(6, 3.4, 9),
		STEEL_DARK,
		Enum.Material.CorrodedMetal
	)
	for _, wz in { -1, 1 } do
		local wheel = part(
			string.format("RoueWagonnet%d_%d", side, wz),
			decor,
			Vector3.new(0.8, 2.4, 2.4),
			CFrame.new(side * 30 + 3.2, 1.2, side * 48 + wz * 3)
				* CFrame.Angles(0, 0, math.rad(90)),
			STEEL,
			Enum.Material.CorrodedMetal
		)
		wheel.Shape = Enum.PartType.Cylinder
		wheel.CanCollide = false
	end
end

-- SUR LES GRADINS : ce qui rend la traversee survivable. Sans eux, remonter
-- serait vingt-deux studs a decouvert, et personne ne le tenterait jamais —
-- un chemin qu'on ne prend pas est un chemin qui n'existe pas. Avec eux c'est
-- un pari, et c'est ce qu'on veut.
for _, side in { -1, 1 } do
	-- x = 45 et pas 48 : la voie de la rampe du haut longe la paroi de 49 a
	-- 58, et une caisse posee dedans boucherait le seul chemin vers le haut.
	local x = side * 45
	for index, z in { -46, -16, 4, 24, 46 } do
		local height = 4.5 + (index % 2) * 1.6
		crate(
			string.format("CaisseGradin%d_%d", side, index),
			cover,
			Vector3.new(x + ((index % 2) * 5 - 2.5) * side, LEDGE_Y + height / 2, z),
			Vector3.new(7, height, 6),
			TIMBER,
			Enum.Material.WoodPlanks
		)
	end
	-- Le tas de deblais : deux coins, donc un couvert qu'on peut gravir d'un
	-- cote et pas de l'autre. C'est le seul endroit de la map ou la hauteur
	-- s'achete sans rampe.
	for _, dir in { 1, -1 } do
		wedge(
			string.format("Deblais%d_%d", side, dir),
			cover,
			Vector3.new(10, 5, 7),
			CFrame.new(side * 44, LEDGE_Y + 2.5, dir * 12)
				* CFrame.Angles(0, if dir > 0 then 0 else math.pi, 0),
			ROCK_LIGHT,
			Enum.Material.Rock
		)
	end
end

-- SUR LA MARGELLE : une cabane de treuil par cote court, et des piles de
-- tuyaux. Les deux cotes courts sont ceux qui n'ont pas de gradin sous eux,
-- donc ceux d'ou on tombe de vingt-quatre studs d'un coup : il faut une raison
-- d'y aller, et une cabane en est une.
for _, side in { -1, 1 } do
	local z = side * 66
	crate(
		string.format("CabaneTreuil%d", side),
		cover,
		Vector3.new(0, RIM_Y + 4, z),
		Vector3.new(16, 8, 10),
		TIMBER,
		Enum.Material.WoodPlanks
	)
	for _, dir in { 1, -1 } do
		wedge(
			string.format("ToitCabane%d_%d", side, dir),
			decor,
			Vector3.new(16, 3.2, 5),
			CFrame.new(0, RIM_Y + 9.6, z + dir * 2.5)
				* CFrame.Angles(0, if dir > 0 then 0 else math.pi, 0),
			STEEL_DARK,
			Enum.Material.Metal
		).CanCollide =
			false
	end

	for index, x in { -42, -20, 22, 44 } do
		crate(
			string.format("Tuyaux%d_%d", side, index),
			cover,
			Vector3.new(x, RIM_Y + 2, z + (index % 2) * 4 - 2),
			Vector3.new(9, 4, 5),
			STEEL,
			Enum.Material.CorrodedMetal
		)
	end
end

-- Et deux abris sur les cotes des camps, pour que la margelle ne soit pas une
-- piste nue entre le depart et la rampe.
for _, side in { -1, 1 } do
	local x = side * 66
	for _, z in { -44, 44 } do
		crate(
			string.format("Abri%d_%d", side, z),
			cover,
			Vector3.new(x, RIM_Y + 3, z),
			Vector3.new(10, 6, 8),
			STEEL_DARK,
			Enum.Material.CorrodedMetal
		)
	end
end

--------------------------------------------------------------------------------
-- LES DEUX CAMPS
--------------------------------------------------------------------------------

for _, team in { "A", "B" } do
	local side = if team == "A" then -1 else 1
	local tint = if team == "A" then COLOR_A else COLOR_B
	local x = side * SPAWN_X

	local pad = part(
		"Plateforme" .. team,
		decor,
		Vector3.new(12, 0.3, SPAWN_SPREAD * 4 + 8),
		CFrame.new(x, RIM_Y + 0.25, 0),
		tint,
		Enum.Material.Concrete
	)
	pad.CanCollide = false

	-- Deux balises hautes : de l'autre bout de la carriere on ne distingue pas
	-- une dalle peinte, on distingue une lumiere. C'est aussi ce qui dit a
	-- quelqu'un qui remonte vers quelle rampe il court.
	for _, sz in { -1, 1 } do
		local mast = part(
			string.format("Balise%s%d", team, sz),
			decor,
			Vector3.new(0.8, 9, 0.8),
			CFrame.new(x, RIM_Y + 4.5, sz * (SPAWN_SPREAD * 2 + 5)),
			STEEL_DARK,
			Enum.Material.Metal
		)
		mast.CanCollide = false
		lamp(
			decor,
			Vector3.new(x, RIM_Y + 9.4, sz * (SPAWN_SPREAD * 2 + 5)),
			tint,
			26,
			2.2
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
		marker.Position = Vector3.new(x, SPAWN_Y, (i - 3) * SPAWN_SPREAD)
		marker.Parent = folder
	end
end

--------------------------------------------------------------------------------
-- LES PROJECTEURS
--------------------------------------------------------------------------------

-- LA SEULE COULEUR CHAUDE DE LA MAP. Tout le reste est bleu, blanc ou noir :
-- huit lampes sodium donnent a l'oeil un point de comparaison, et c'est ce qui
-- fait que le bleu se lit comme du froid et pas comme une teinte d'ecran.
for _, sz in { -1, 1 } do
	for _, sx in { -1, 1 } do
		local x = sx * 40
		local z = sz * 62
		local mast = part(
			string.format("Mat%d_%d", sx, sz),
			decor,
			Vector3.new(1.2, 16, 1.2),
			CFrame.new(x, RIM_Y + 8, z),
			STEEL_DARK,
			Enum.Material.Metal
		)
		mast.CanCollide = false
		lamp(decor, Vector3.new(x, RIM_Y + 16, z), SODIUM, 70, 3.4)
	end
end
-- Deux au fond, sous le chevalement : le lac est la plus grande surface de la
-- map et la zone s'y referme, donc c'est la qu'il faut y voir.
for _, sz in { -1, 1 } do
	lamp(decor, Vector3.new(0, 15, sz * 26), SODIUM, 52, 2.6)
end

--------------------------------------------------------------------------------
-- LE CONTRAT
--------------------------------------------------------------------------------

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
bounds.Size = Vector3.new(BOUNDS, 1, BOUNDS)
bounds.Position = Vector3.new(0, -20, 0)
bounds.Anchored = true
bounds.CanCollide = false
bounds.Transparency = 1
bounds.Parent = map

map.Parent = Workspace

--------------------------------------------------------------------------------
-- L'ECLAIRAGE
--------------------------------------------------------------------------------

-- `Clouds` se parente au TERRAIN et pas a `Lighting`, et rien ne detruit le
-- Terrain : chaque recette doit donc effacer les nuages des autres, meme celle
-- qui en veut.
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

-- LE CIEL PAR DEFAUT DE ROBLOX EST UNE TEXTURE DE PLEIN JOUR, pas un degrade
-- calcule : ni `ClockTime`, ni `Atmosphere.Color`, ni une correction de
-- couleur ne la teintent. Le seul levier qui marche est `Clouds`, et une
-- carriere par temps couvert est exactement ce qu'il sait faire.
local clouds = Instance.new("Clouds")
clouds.Cover = 0.92
clouds.Density = 0.72
clouds.Color = Color3.fromRGB(226, 232, 240)
clouds.Parent = Workspace.Terrain

-- UN CIEL COUVERT ASSOMBRIT TOUT, et c'est l'erreur du colisee : des nuages a
-- 0,88 avaient mange les ombres qu'on venait d'acheter. La parade est de
-- remonter la clarte ET l'ambiance exterieure : on veut un gris LUMINEUX, pas
-- une nuit.
Lighting.ClockTime = 8.4
Lighting.GeographicLatitude = 62
Lighting.Brightness = 3.2
Lighting.Ambient = Color3.fromRGB(66, 76, 92)
Lighting.OutdoorAmbient = Color3.fromRGB(132, 146, 168)
Lighting.ColorShift_Top = Color3.fromRGB(208, 224, 248)
Lighting.ColorShift_Bottom = Color3.fromRGB(96, 112, 136)
Lighting.ExposureCompensation = 0.1

local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.54
atmosphere.Offset = 0.2
atmosphere.Color = Color3.fromRGB(212, 226, 246)
atmosphere.Decay = Color3.fromRGB(148, 166, 194)
atmosphere.Glare = 0.18
atmosphere.Haze = 3.4
atmosphere.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.3
bloom.Size = 18
bloom.Threshold = 2.1
bloom.Parent = Lighting

-- LA GLACE A BESOIN DE CONTRASTE ET PAS DE SATURATION. Une carriere gelee
-- saturee devient un decor de dessin animé ; desaturee et contrastee, elle
-- devient froide.
local grade = Instance.new("ColorCorrectionEffect")
grade.Saturation = -0.14
grade.Contrast = 0.16
grade.Brightness = 0.01
grade.TintColor = Color3.fromRGB(228, 238, 255)
grade.Parent = Lighting

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
Lighting.ShadowSoftness = 0.3

Lighting.EnvironmentDiffuseScale = 0.45
Lighting.EnvironmentSpecularScale = 0.7

local dof = Instance.new("DepthOfFieldEffect")
dof.FocusDistance = 70
dof.InFocusRadius = 120
dof.NearIntensity = 0
dof.FarIntensity = 0.5
dof.Parent = Lighting

--------------------------------------------------------------------------------
-- CE QUE LA MAP SE MESURE A ELLE-MEME
--------------------------------------------------------------------------------

-- UNE MAP NE SE JUGE PAS A L'OEIL, ELLE SE MESURE AU RAYON. Les trois defauts
-- de jeu reels des maps du 29 octobre ont tous ete trouves comme ca, aucun en
-- regardant. Alors la recette le fait elle-meme, a chaque construction : elle
-- imprime ce qu'elle trouve, et quelqu'un qui deplace un bloc voit tout de
-- suite ce que ca casse.

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { map }

local EYE = 4.5 -- hauteur des yeux au-dessus du sol sur lequel on se tient

local function clearLine(from, to)
	local delta = to - from
	local hit = Workspace:Raycast(from, delta, params)
	return hit == nil, if hit then (hit.Position - from).Magnitude else delta.Magnitude
end

print("")
print("[Arena] ===== La Carriere se mesure =====")

-- 1. LES LIGNES DE TIR ENTRE LES DEUX DEPARTS. Une ligne degagee de cent
-- vingt studs entre deux departs est le defaut qui a ete trouve au rayon dans
-- la soute : le premier a cliquer gagne l'echange sans que personne ait joue.
local spawnsA = map:FindFirstChild("SpawnsA")
local spawnsB = map:FindFirstChild("SpawnsB")
local open, worst, pairs_ = 0, 0, 0
for _, a in spawnsA:GetChildren() do
	for _, b in spawnsB:GetChildren() do
		pairs_ += 1
		local from = a.Position + Vector3.new(0, EYE - 0.5, 0)
		local to = b.Position + Vector3.new(0, EYE - 0.5, 0)
		local isClear, distance = clearLine(from, to)
		if isClear then
			open += 1
			worst = math.max(worst, distance)
		end
	end
end
if open == 0 then
	print(string.format("  Departs : aucune des %d lignes n'est degagee. Bon.", pairs_))
else
	warn(
		string.format(
			"[Arena]   Departs : %d lignes degagees sur %d, la plus longue %.0f studs. "
				.. "Le chevalement ne coupe pas assez.",
			open,
			pairs_,
			worst
		)
	)
end

-- 2. LA COUVERTURE DU CERCLE FINAL. Deux coursives aveugles sur le cercle
-- final a cause d'une passerelle centrale : c'est l'autre defaut du
-- 29 octobre. On tire seize rayons a l'horizontale depuis le centre et on
-- compte ceux qui trouvent quelque chose a moins de vingt-cinq studs.
local covered = 0
for step = 0, 15 do
	local angle = step / 16 * math.pi * 2
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 25
	local hit = Workspace:Raycast(Vector3.new(0, EYE, 0), direction, params)
	if hit then
		covered += 1
	end
end
print(
	string.format(
		"  Cercle final : %d directions sur 16 trouvent un couvert a moins de 25 studs.",
		covered
	)
)
if covered < 4 then
	warn("[Arena]   Le cercle final est trop nu : on s'y fait tirer de partout.")
elseif covered > 11 then
	warn("[Arena]   Le cercle final est trop encombre : on ne peut plus s'y disputer.")
end

-- 3. LE SENS DES RAMPES. Une rampe du Sanctuaire etait posee a l'envers et ca
-- ne se voyait sur aucune capture : on echantillonne la hauteur du sol le long
-- du chemin, et on regarde si elle monte.
local wrong = 0
for _, r in ramps do
	local function groundAt(fraction)
		local at = r.low:Lerp(r.high, fraction)
		local hit = Workspace:Raycast(
			Vector3.new(at.X, r.high.Y + 8, at.Z),
			Vector3.new(0, -(r.rise + 24), 0),
			params
		)
		return if hit then hit.Position.Y else -99
	end
	local climbs = groundAt(0.85) - groundAt(0.15)
	if climbs < r.rise * 0.5 then
		wrong += 1
		warn(
			string.format(
				"[Arena]   %s ne monte pas : %.1f stud gagne la ou %.0f etaient attendus.",
				r.name,
				climbs,
				r.rise
			)
		)
	else
		print(string.format("  %s monte de %.1f studs. Bon.", r.name, climbs))
	end
end

-- 4. ON DESCEND VITE, ON REMONTE LENTEMENT : la promesse de la map, mesuree.
-- Du bas de la rampe du lac jusqu'au haut de celle de la margelle, par le
-- gradin — c'est le chemin qu'un joueur doit vraiment parcourir.
local climb = math.abs(RAMP_Z - (-RAMP_Z)) + RAMP_RUN * 2
print(
	string.format(
		"  Remonter du lac a la margelle : %.0f studs de chemin a decouvert, "
			.. "pour %d studs de chute dans l'autre sens.",
		climb,
		RIM_Y
	)
)

print(
	string.format(
		"[Arena] Carriere construite : %d parts.%s",
		#map:GetDescendants(),
		if open == 0 and wrong == 0 then " Rien a signaler." else " VOIR LES AVERTISSEMENTS."
	)
)
