--!strict
--[[
	WeaponService — l'arme qu'on tient, et le geste qui part avec elle.

	POURQUOI CE SERVICE EXISTE. L'equipement etait invisible : deux joueurs
	s'affrontaient avec douze points depenses chacun et rien a l'ecran ne
	disait lequel portait un marteau et lequel un arc. Or c'est exactement
	l'information qui decide de la seconde suivante — on ne joue pas un
	corps-a-corps de la meme facon contre une portee de 60 studs. Un budget
	qu'on ne voit pas sur l'adversaire n'est pas une mecanique de jeu, c'est
	une feuille de calcul.

	AUCUNE ANIMATION TELEVERSEE. Une `Animation` Roblox demande un identifiant
	d'asset, donc un televersement sur un compte, donc quelque chose que
	personne ne peut relire dans ce depot ni rejouer ailleurs. Tout ici est
	geometrique : un `Motor6D` entre la main et l'arme, et son `C0` qu'on
	anime. Une arme neuve se decrit entierement dans `Config.items`, en six
	chiffres, sans sortir de l'editeur.

	LE CORPS BOUGE AUSSI, ET PAS PAR UN `Motor6D`. Le premier jet visait
	l'epaule, comme pour l'arme. Ca ne marche pas, et la raison se voit en
	jeu : sur les avatars d'aujourd'hui, l'epaule n'est PAS un `Motor6D` mais
	un `AnimationConstraint`, que l'animateur de Roblox reecrit a chaque
	image. Le seul moyen qui marche sur les deux squelettes est `IKControl` :
	on pose une attache sur le torse, on dit a la main d'aller la chercher, et
	on fait monter puis redescendre le poids du controle. A poids zero,
	l'animation d'origine est intacte — donc aucun saut au depart ni au
	retour, et rien a defaire si le geste est interrompu.

	L'ARME DIT COMMENT, LE BRAS DIT OU. Le `C0` de l'arme la fait tourner
	dans la main ; l'IK ne fait que porter la main ailleurs, sans toucher a
	son orientation (`IKControlType.Position`). Melanger les deux ferait
	tourner l'arme deux fois, une fois par l'arme et une fois par le poignet.

	ET LE BUSTE PENCHE, ET LA TETE SUIT, par deux autres `IKControl`, en
	`Rotation` ceux-la : on veut que le buste PLIE A LA TAILLE et pas qu'il
	quitte son bassin, et qu'une tete tourne plutot qu'elle se deplace. Les
	trois controles se composent sans se marcher dessus parce que chaque cible
	est posee sur le parent de ce qu'elle commande : la main sur le torse, la
	tete sur le torse, le torse sur le bassin. Chacun part donc avec son
	porteur et n'a rien a corriger. Mesure en jeu, et pas suppose.

	LES JAMBES NE BOUGENT PAS, ET C'EST UN REFUS MESURE. Un `IKControl` sur la
	chaine `RightUpperLeg` -> `RightFoot` marche tres bien debout. En marchant
	il GAGNE contre l'animation de marche, et c'est precisement le probleme :
	le pied, qui balance normalement de 1,68 stud, tombe a 0,10. Le personnage
	glisse alors sur une jambe figee. Une attaque dure 230 ms, la marche est a
	l'ecran en permanence — donc on ne touche pas aux jambes.

	CE SERVICE NE REQUIERT RIEN DU SERVEUR. Pas de `CombatService`, pas de
	`LoadoutService` : c'est `LoadoutService` qui l'appelle, jamais l'inverse.
	Il ne decide de rien, il montre.

	L'ARME SURVIT A LA MORT DU PERSONNAGE. On retient ce que chaque joueur
	porte, et on la reconstruit a chaque `CharacterAdded` : sans ca, elle
	disparaitrait a la premiere manche perdue et ne reviendrait qu'au prochain
	changement d'equipement, c'est-a-dire peut-etre jamais.
]]

local WeaponService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Config = require(Arena:WaitForChild("Config"))

local MODEL_NAME = "ArenaWeapon"
local GRIP_NAME = "ArenaGrip"
local WORN_MODEL = "ArenaWorn"
local WORN_NAME = "ArenaWornJoint"
local OFFHAND_MODEL = "ArenaOffhand"
local OFFHAND_NAME = "ArenaOffhandJoint"
local ARM_NAME = "ArenaArm"
local TARGET_NAME = "ArenaHandTarget"
local LEAN_NAME = "ArenaLean"
local LEAN_TARGET_NAME = "ArenaLeanTarget"
local HEAD_NAME = "ArenaHead"
local HEAD_TARGET_NAME = "ArenaHeadTarget"

-- Ce que chaque joueur est cense porter. C'est la memoire qui permet de
-- rebatir l'arme apres une mort, et de ne rien rebatir quand l'arme n'a pas
-- change — reconstruire a chaque coup ferait clignoter le modele.
local wanted: { [Player]: any } = {}
local joints: { [Player]: Motor6D } = {}
local restC0: { [Player]: CFrame } = {}

-- CE QU'ON PORTE RESTE, CE QU'ON SORT PASSE. L'armure est visible tant qu'elle
-- est equipee ; l'objet de la main gauche n'apparait que pendant son
-- utilisation. Les deux repondent a la meme regle que l'arme — un budget qu'on
-- ne voit pas sur l'adversaire n'est pas une mecanique de jeu — mais pas de la
-- meme facon : une armure se porte en permanence, alors qu'un joueur qui a
-- quatre utilitaires ne peut pas les tenir tous les quatre en meme temps.
local wornItems: { [Player]: { any } } = {}
local offhandToken: { [Player]: number } = {}

-- Un jeton par joueur pour le retour du geste. Sans lui, le retour d'un coup
-- lance il y a 70 ms repose l'arme en plein milieu du coup suivant, et une
-- arme rapide comme le couteau tremble au lieu de frapper.
local swingToken: { [Player]: number } = {}

-- LE BRAS. `armRest` est la position de la main au repos, DANS LE REPERE DU
-- TORSE. Elle se mesure et ne s'ecrit pas : elle depend de la taille de
-- l'avatar, que le joueur choisit, et un chiffre ecrit ici serait juste pour un
-- seul corps.
local armControl: { [Player]: IKControl } = {}
local armTarget: { [Player]: Attachment } = {}
local armRest: { [Player]: Vector3 } = {}

-- LE TORSE. Pas de `leanRest` ici, et c'est la difference importante avec le
-- bras : l'animation d'attente fait tourner le buste de son cote, jusqu'a 22
-- degres, en permanence. Une orientation de repos relevee une fois serait donc
-- perimee a l'instant suivant, et pencher par rapport a elle ferait sauter le
-- torse. On la relit au depart de chaque geste. La main, elle, se mesure une
-- fois, parce que sa position de repos depend de la taille du corps et pas de
-- ce que l'animation est en train de faire.
local leanControl: { [Player]: IKControl } = {}
local leanTarget: { [Player]: Attachment } = {}

-- LA TETE. Meme traitement que le buste, et pour une raison mesuree :
-- l'animation d'attente ne la bouge que de 0,7 degre sur trois secondes, contre
-- 22 pour le buste. Ses DEUX axes sont donc utilisables, la ou le buste n'en
-- avait qu'un. Son orientation de repos se relit quand meme au depart de chaque
-- geste : 0,7 degre n'est pas zero.
local headControl: { [Player]: IKControl } = {}
local headTarget: { [Player]: Attachment } = {}

local function forgetBody(player: Player)
	local held = {
		armControl[player],
		armTarget[player],
		leanControl[player],
		leanTarget[player],
		headControl[player],
		headTarget[player],
	}
	for _, one in held do
		if one ~= nil then
			one:Destroy()
		end
	end
	armControl[player] = nil
	armTarget[player] = nil
	armRest[player] = nil
	leanControl[player] = nil
	leanTarget[player] = nil
	headControl[player] = nil
	headTarget[player] = nil
end

-- Prepare le bras droit ET le buste du personnage actuel. Renvoie faux quand le
-- squelette ne s'y prete pas : un avatar R6 n'a qu'une seule part pour tout le
-- bras et une seule pour tout le tronc, donc il n'y a aucune articulation a
-- flechir ni a pencher. Dans ce cas l'arme bouge et le corps non, exactement
-- comme avant — mieux vaut ca qu'un bras casse.
--
-- LES DEUX CONTROLES SE COMPOSENT SANS SE MARCHER DESSUS, et ce n'est pas une
-- supposition : mesure en jeu le 27 octobre 2026, avec le buste penche de 20
-- degres, la main reste a 1,08 de son 1,01 habituel DANS LE REPERE DU TORSE.
-- La cible de la main etant posee sur le torse, elle part en meme temps que lui
-- et le bras n'a rien a corriger.
local function prepareBody(player: Player): boolean
	local existing = armControl[player]
	if existing ~= nil and existing.Parent ~= nil then
		return true
	end
	forgetBody(player)

	local character = player.Character
	if character == nil then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local torso = character:FindFirstChild("UpperTorso")
	local hand = character:FindFirstChild("RightHand")
	local upper = character:FindFirstChild("RightUpperArm")
	local hips = character:FindFirstChild("LowerTorso")
	local skull = character:FindFirstChild("Head")
	if humanoid == nil or upper == nil then
		return false
	end
	if torso == nil or not torso:IsA("BasePart") then
		return false
	end
	if hand == nil or not hand:IsA("BasePart") then
		return false
	end
	if hips == nil or not hips:IsA("BasePart") then
		return false
	end
	if skull == nil or not skull:IsA("BasePart") then
		return false
	end

	-- L'attache est posee SUR LE TORSE, et pas dans le monde : elle suit donc
	-- le personnage qui court, qui tourne et qui tombe sans qu'une seule ligne
	-- de code s'en occupe.
	local target = Instance.new("Attachment")
	target.Name = TARGET_NAME
	target.CFrame = torso.CFrame:ToObjectSpace(hand.CFrame)
	target.Parent = torso

	local control = Instance.new("IKControl")
	control.Name = ARM_NAME
	-- `Position` et pas `Transform` : l'orientation de la main reste celle de
	-- l'animation de Roblox, et c'est le `C0` de l'arme qui tourne.
	control.Type = Enum.IKControlType.Position
	control.ChainRoot = upper
	control.EndEffector = hand
	control.Target = target
	-- Poids zero : le controle existe mais ne fait rien. C'est l'etat de repos,
	-- et c'est ce qui permet de le laisser en place en permanence.
	control.Weight = 0
	control.Parent = humanoid

	-- Le buste. `Rotation` et pas `Position` : on veut qu'il PENCHE, pas qu'il
	-- se deplace — un torse qu'on tire vers l'avant quitte son bassin, un torse
	-- qu'on incline plie a la taille. La chaine ne contient que l'articulation
	-- du bassin, donc les jambes ne bougent pas.
	local leanAt = Instance.new("Attachment")
	leanAt.Name = LEAN_TARGET_NAME
	leanAt.CFrame = hips.CFrame:ToObjectSpace(torso.CFrame)
	leanAt.Parent = hips

	local bend = Instance.new("IKControl")
	bend.Name = LEAN_NAME
	bend.Type = Enum.IKControlType.Rotation
	bend.ChainRoot = hips
	bend.EndEffector = torso
	bend.Target = leanAt
	bend.Weight = 0
	bend.Parent = humanoid

	-- La tete, sur la chaine du cou seulement : `UpperTorso` -> `Head`. En
	-- `Rotation` comme le buste, parce qu'une tete tourne, elle ne se deplace
	-- pas.
	local headAt = Instance.new("Attachment")
	headAt.Name = HEAD_TARGET_NAME
	headAt.CFrame = torso.CFrame:ToObjectSpace(skull.CFrame)
	headAt.Parent = torso

	local neck = Instance.new("IKControl")
	neck.Name = HEAD_NAME
	neck.Type = Enum.IKControlType.Rotation
	neck.ChainRoot = torso
	neck.EndEffector = skull
	neck.Target = headAt
	neck.Weight = 0
	neck.Parent = humanoid

	armControl[player] = control
	armTarget[player] = target
	armRest[player] = target.CFrame.Position
	leanControl[player] = bend
	leanTarget[player] = leanAt
	headControl[player] = neck
	headTarget[player] = headAt
	return true
end

local function tweenWeight(control: IKControl?, seconds: number, weight: number)
	if control == nil or control.Parent == nil then
		return
	end
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(control, info, { Weight = weight }):Play()
end

-- La main part chercher un point et le buste se penche. `pose` porte le meme
-- nom que le geste de l'arme — « slash », « overhead »... — plus « fist » quand
-- il n'y a pas d'arme du tout.
local function reachOut(player: Player, pose: string)
	if not prepareBody(player) then
		return
	end
	local move = Config.loadout.bodyMotion[pose]
	local target = armTarget[player]
	local rest = armRest[player]
	if move == nil or target == nil or rest == nil then
		return
	end

	local seconds = Config.loadout.weaponMotion.outSeconds

	-- L'avant de Roblox est -Z. C'est la seule conversion de tout le fichier, et
	-- elle est ici pour que `Config` parle en mots plutot qu'en axes.
	target.CFrame = CFrame.new(rest + Vector3.new(move.right, move.up, -move.forward))
	tweenWeight(armControl[player], seconds, 1)

	-- LE BUSTE ET LA TETE PARTENT DE LA OU ILS SONT, et c'est pour ca qu'on
	-- relit leur orientation ici plutot que de l'avoir gardee : l'animation
	-- d'attente les fait tourner en permanence, donc une orientation relevee une
	-- fois pour toutes serait perimee et le corps sauterait au depart du geste.
	local bend = leanControl[player]
	local leanAt = leanTarget[player]
	local neck = headControl[player]
	local headAt = headTarget[player]
	local character = player.Character
	local hips = character ~= nil and character:FindFirstChild("LowerTorso") or nil
	local torso = character ~= nil and character:FindFirstChild("UpperTorso") or nil
	local skull = character ~= nil and character:FindFirstChild("Head") or nil
	if bend == nil or leanAt == nil or not hips or not torso then
		return
	end
	if not hips:IsA("BasePart") or not torso:IsA("BasePart") then
		return
	end

	-- LA SEULE CONVERSION D'ANGLE DU FICHIER, ET ELLE PORTE UN SIGNE MOINS.
	-- Dans Roblox un tangage positif LEVE l'avant de la part : verifie par un
	-- temoin le 27 octobre 2026, `CFrame.Angles(+18, 0, 0)` donne a l'avant du
	-- buste un Y de +0,30 et a son sommet un Z de +0,29, c'est-a-dire une
	-- poitrine qui regarde le ciel et un buste qui part EN ARRIERE. Or `lean`
	-- est nomme par son effet et vaut 18 pour le marteau, qui s'abat. D'ou le
	-- moins.
	--
	-- Ce signe a ete faux pendant une journee entiere, et le test qui devait
	-- l'attraper comparait deux de mes conventions entre elles. Il mesure
	-- maintenant ou pointe la poitrine.
	leanAt.CFrame = hips.CFrame:ToObjectSpace(torso.CFrame)
		* CFrame.Angles(math.rad(-move.lean), 0, 0)
	tweenWeight(bend, seconds, 1)

	-- Meme signe moins pour `headDip`, meme raison. `headTurn` n'en a pas : un
	-- lacet positif tourne bien vers la gauche du personnage, mesure a +30
	-- degres demandes pour un avant de tete a -0,45 en X, et le X d'une part est
	-- sa droite.
	if neck == nil or headAt == nil or skull == nil or not skull:IsA("BasePart") then
		return
	end
	headAt.CFrame = torso.CFrame:ToObjectSpace(skull.CFrame)
		* CFrame.Angles(math.rad(-move.headDip), math.rad(move.headTurn), 0)
	tweenWeight(neck, seconds, 1)
end

local function comeBack(player: Player)
	local seconds = Config.loadout.weaponMotion.backSeconds
	tweenWeight(armControl[player], seconds, 0)
	tweenWeight(leanControl[player], seconds, 0)
	tweenWeight(headControl[player], seconds, 0)
end

local function triple(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

local function colorOf(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- La main droite, R15 ou R6. Les deux rigs existent encore sur Roblox et le
-- choix appartient au joueur, pas au jeu : il faut savoir lire les deux.
local R6_FOR: { [string]: string } = {
	RightHand = "Right Arm",
	LeftHand = "Left Arm",
	UpperTorso = "Torso",
	LowerTorso = "Torso",
	Head = "Head",
	-- Les quatre membres d'une armure complete. HABILLER une jambe n'a rien a
	-- voir avec l'ANIMER : la piece est soudee au membre et suit l'animation
	-- de marche sans la contrarier, exactement comme l'arme dans la main. Le
	-- refus de l'etape 10 portait sur les `IKControl`, qui eux gagnent contre
	-- l'animation et font glisser le personnage sur une jambe figee.
	RightUpperArm = "Right Arm",
	LeftUpperArm = "Left Arm",
	RightUpperLeg = "Right Leg",
	LeftUpperLeg = "Left Leg",
	RightLowerLeg = "Right Leg",
	LeftLowerLeg = "Left Leg",
	RightFoot = "Right Leg",
	LeftFoot = "Left Leg",
}

local function limbOf(character: Model, name: string): BasePart?
	local r15 = character:FindFirstChild(name)
	if r15 ~= nil and r15:IsA("BasePart") then
		return r15
	end
	local fallback = R6_FOR[name]
	if fallback == nil then
		return nil
	end
	local r6 = character:FindFirstChild(fallback)
	if r6 ~= nil and r6:IsA("BasePart") then
		return r6
	end
	return nil
end

local function handOf(character: Model): BasePart?
	return limbOf(character, "RightHand")
end

-- LES DEUX LISTES DE REFERENCE DE L'ALLURE. Un nom de sorte ou de matiere qui
-- n'est pas la dedans est refuse au demarrage du serveur, par le meme
-- mecanisme que les pouvoirs et les sortes d'utilisation : un objet qui
-- retomberait en silence sur une boite grise aurait l'air de marcher, et
-- personne ne verrait jamais que son allure n'est pas celle qui est ecrite.
-- En ajoutant une sorte ou une matiere, l'inscrire ici.
local SHAPES: { [string]: Enum.PartType } = {
	Block = Enum.PartType.Block,
	Cylinder = Enum.PartType.Cylinder,
	Ball = Enum.PartType.Ball,
}

local MATERIALS: { [string]: Enum.Material } = {
	SmoothPlastic = Enum.Material.SmoothPlastic,
	Plastic = Enum.Material.Plastic,
	Metal = Enum.Material.Metal,
	DiamondPlate = Enum.Material.DiamondPlate,
	CorrodedMetal = Enum.Material.CorrodedMetal,
	Wood = Enum.Material.Wood,
	WoodPlanks = Enum.Material.WoodPlanks,
	Fabric = Enum.Material.Fabric,
	Leather = Enum.Material.Leather,
	Glass = Enum.Material.Glass,
	Neon = Enum.Material.Neon,
	Granite = Enum.Material.Granite,
	Slate = Enum.Material.Slate,
}

-- Les deux listes se relisent de l'exterieur, pour que le garde-fou du
-- demarrage n'en tienne pas une copie. Deux listes qui doivent s'accorder
-- finissent toujours par diverger en silence.
function WeaponService.knowsShape(name: string): boolean
	return SHAPES[name] ~= nil or name == "Wedge"
end

function WeaponService.knowsMaterial(name: string): boolean
	return MATERIALS[name] ~= nil
end

-- Et le membre d'une armure portee, pour la meme raison. `attachAt` renvoie
-- simplement faux quand il ne trouve pas le membre : une armure posee sur un
-- « Chest » qui n'existe sur aucun des deux rigs couterait ses points et
-- n'apparaitrait nulle part, sans la moindre erreur.
function WeaponService.knowsLimb(name: string): boolean
	return R6_FOR[name] ~= nil
end

-- LES DEUX ANGLES SONT NOMMES PAR LEUR EFFET, ET LE SENS EST VERIFIE.
--
-- DANS CE JEU, UNE ARME POINTE VERS -Z. Ce n'est pas un choix fait ici, c'est
-- ce que les 34 armes disent deja : le canon du fusil de precision est pose a
-- -3,6, la tete du marteau a -1,4, et le pommeau du katana a +2,2. Le bout
-- utile est du cote -Z, le cote du porteur est +Z. C'est aussi la convention
-- du reste du projet — dans Roblox l'avant est -Z.
--
-- De la, le signe de chaque angle, par le calcul et par une mesure :
--   `CFrame.Angles(t, 0, 0)` envoie (0, 0, -1) sur (0, sin t, -cos t), donc un
--   X positif LEVE le bout avant. Mesure concordante relevee dans la place le
--   28 octobre 2026 sur le katana d'essai, dont les segments pointaient vers
--   +Z : poses a +2,1 degre chacun, leur bout +Z est DESCENDU de 0,010 puis
--   0,038 puis 0,086 puis 0,152 stud. Le bout +Z descend, donc le bout -Z
--   monte : c'est la meme phrase.
--   `CFrame.Angles(0, y, 0)` envoie (0, 0, -1) sur (-sin y, 0, -cos y), donc
--   un Y positif emmene le bout avant vers -X, c'est-a-dire a GAUCHE.
--
-- Les deux conversions n'existent qu'ICI. C'est la regle qui a coute une
-- journee sur le penchement du buste, ecrit a l'envers parce que des angles
-- d'Euler avaient ete lus comme des directions : un angle se nomme par son
-- effet, et la conversion vers les axes de Roblox se fait a un seul endroit.
local function anglesOf(piece: any): CFrame
	return CFrame.Angles(
		math.rad(piece.tipUp or 0),
		math.rad(piece.tipLeft or 0),
		math.rad(piece.roll or 0)
	)
end

-- Ou se pose une piece dans le repere de l'objet, dont l'origine est le point
-- tenu par la main (ou le centre du membre, pour une armure portee).
--
-- `scale` n'est pas nil pour une armure : ses tailles et ses positions sont
-- alors des FRACTIONS du membre, pas des studs. C'est la meme lecon que la
-- position de la main au repos, qui se mesure au lieu de s'ecrire — la taille
-- de l'avatar appartient au joueur, et un plastron ecrit en studs flotterait
-- autour d'un grand corps et rentrerait dans un petit.
local function frameOf(piece: any, scale: Vector3?): CFrame
	local at = triple(piece.at)
	if scale ~= nil then
		at = at * scale
	end
	return CFrame.new(at) * anglesOf(piece)
end

-- Une piece : jamais de collision, jamais de masse, jamais de requete
-- spatiale. Une arme qui pousse son porteur ou qui intercepte un rayon de
-- visee serait un bug de combat ne d'un element decoratif.
local function makePiece(piece: any, scale: Vector3?): BasePart
	local shaped: string = piece.shape or "Block"
	local part: BasePart
	if shaped == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local block = Instance.new("Part")
		block.Shape = SHAPES[shaped] or Enum.PartType.Block
		part = block
	end

	part.Name = piece.name
	part.Size = if scale ~= nil then triple(piece.size) * scale else triple(piece.size)
	part.Color = colorOf(piece.color)
	part.Material = MATERIALS[piece.material or "SmoothPlastic"] or Enum.Material.SmoothPlastic
	part.Reflectance = piece.reflectance or 0
	part.Transparency = piece.transparency or 0
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Assemble les pieces en un modele. La PREMIERE piece porte toutes les autres
-- par des `Motor6D` — une soudure a besoin que les deux pieces soient deja
-- placees dans le monde, et elles ne le sont pas encore ici.
--
-- Renvoie aussi le repere de la premiere piece, parce que c'est lui qu'il faut
-- composer avec la prise : sans ca, une premiere piece qui n'est pas a
-- l'origine deplacerait tout l'objet dans la main.
-- `only` restreint la construction a un sous-ensemble de pieces. C'est ce qui
-- permet a UNE armure de couvrir CINQ membres : chaque membre recoit son
-- propre modele, bati avec ses seules pieces et mis a l'echelle de SA taille.
-- Un seul modele ne pourrait pas, parce que toutes ses pieces pendent de la
-- premiere par un `Motor6D` et suivraient donc le meme membre.
local function buildModel(
	modelName: string,
	look: any,
	scale: Vector3?,
	only: { any }?
): (Model?, BasePart?, CFrame?)
	local pieces = if only ~= nil then only else look.pieces
	if pieces == nil or #pieces == 0 then
		return nil, nil, nil
	end

	local model = Instance.new("Model")
	model.Name = modelName

	local root = makePiece(pieces[1], scale)
	local rootFrame = frameOf(pieces[1], scale)
	model.PrimaryPart = root
	root.Parent = model

	for index = 2, #pieces do
		local piece = pieces[index]
		local part = makePiece(piece, scale)
		part.Parent = model

		local link = Instance.new("Motor6D")
		link.Name = piece.name
		link.Part0 = root
		link.Part1 = part
		link.C0 = rootFrame:Inverse() * frameOf(piece, scale)
		link.Parent = root
	end

	return model, root, rootFrame
end

-- L'ARTICULATION NE VIT PAS DANS LE MODELE, ELLE VIT SUR LA MAIN. Detruire
-- le modele de l'arme laisse donc un `Motor6D` orphelin derriere lui, un par
-- changement d'arme, pour toujours. Vu en jeu le 27 octobre 2026 : QUATRE
-- `ArenaGrip` empiles dans la meme main apres cinq changements, tous inertes
-- (`Part1` vide) et tous repondant au meme nom, donc un `FindFirstChild`
-- en designe un au hasard. C'est le meme piege que les doublons de Rojo.
local function dropJoints(character: Model, jointName: string)
	-- Le membre a pu changer entre deux poses (R15 puis R6 n'arrive pas, mais
	-- un personnage neuf, si), donc on balaie le corps entier plutot que le
	-- seul membre attendu. Une articulation orpheline ne coute rien a chercher
	-- et coute une arme fantome a oublier.
	for _, descendant in character:GetDescendants() do
		if descendant.Name == jointName and descendant:IsA("Motor6D") then
			descendant:Destroy()
		end
	end
end

local function dropGrips(character: Model)
	dropJoints(character, GRIP_NAME)
end

function WeaponService.clear(player: Player)
	joints[player] = nil
	restC0[player] = nil

	local character = player.Character
	if character == nil then
		return
	end
	dropGrips(character)
	local existing = character:FindFirstChild(MODEL_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
end

-- Pose l'arme sur CE personnage et renvoie l'articulation qui la tient.
--
-- Separee de `build` pour une raison precise : la capture d'ecran de Studio
-- ne photographie pas la vue 3D en mode jeu, seulement l'interface. Verifie
-- le 26 octobre 2026 — la camera voyait le sol a 28 studs et le personnage
-- etait a l'ecran d'apres `WorldToViewportPoint`, et la capture etait noire.
-- La seule facon de REGARDER une arme est donc de la poser en mode edition,
-- ce qui demande une fonction qui ne connaisse pas `Player`.
function WeaponService.attach(character: Model, item: any): Motor6D?
	local hand = handOf(character)
	if hand == nil then
		return nil
	end

	local look = item.look
	if look == nil then
		return nil
	end

	local existing = character:FindFirstChild(MODEL_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
	-- Et les articulations de la main, que le modele n'emporte pas avec lui.
	-- `attach` s'appelle aussi en mode edition, sans passer par `clear` : elle
	-- ne peut pas compter sur quelqu'un d'autre pour nettoyer.
	dropGrips(character)

	local model, root, rootFrame = buildModel(MODEL_NAME, look)
	if model == nil or root == nil or rootFrame == nil then
		return nil
	end

	local grip = Instance.new("Motor6D")
	grip.Name = GRIP_NAME
	grip.Part0 = hand
	grip.Part1 = root
	-- La prise porte le repere de la premiere piece : sans ca, une premiere
	-- piece qui n'est pas a l'origine deplacerait tout l'objet dans la main.
	grip.C0 = CFrame.new(triple(look.grip)) * rootFrame
	grip.Parent = hand

	model.Parent = character
	return grip
end

-- UNE ARMURE COUVRE PLUSIEURS MEMBRES, et c'est ce qui la fait lire comme
-- une armure. Une plaque posee sur le seul torse decore l'avant d'une boite :
-- la silhouette du personnage ne change pas, donc l'oeil continue de voir un
-- corps nu avec un rectangle dessus. Chaque piece peut donc nommer son
-- `limb` ; celles qui n'en nomment pas vont sur le membre par defaut, celui
-- de `look.worn.limb`.
--
-- Chaque groupe est mis a l'echelle de SON membre, parce qu'un bras ne fait
-- pas la taille d'un torse : mesure sur un avatar reel le 28 octobre 2026,
-- un torse de 1,27 stud de large porte des bras de 0,40. Une epauliere ecrite
-- en fraction du bras serait minuscule, d'ou des facteurs superieurs a 1.
local function groupByLimb(look: any): { [string]: { any } }
	local groups: { [string]: { any } } = {}
	for _, piece in look.pieces do
		local limbName: string = piece.limb or look.worn.limb
		local group = groups[limbName]
		if group == nil then
			group = {}
			groups[limbName] = group
		end
		table.insert(group, piece)
	end
	return groups
end

-- REGARDER CE QU'ON FABRIQUE. Pose les pieces d'une allure dans le monde,
-- sans personnage et sans articulation, pour pouvoir l'examiner en mode
-- edition. C'est le seul moyen de verifier une allure autrement qu'en la
-- relisant — et relire ne marche pas, deux gestes d'arme sont deja partis a
-- l'envers en passant tous les tests.
--
-- Elle appelle `makePiece` et `frameOf`, c'est-a-dire EXACTEMENT le calcul de
-- la vraie pose : une deuxieme version finirait par mentir sur ce que le jeu
-- montre. La seule difference est qu'elle place chaque piece directement au
-- lieu de l'accrocher a la premiere, ce qui est la meme chose — le `C0` d'une
-- articulation vaut `rootFrame:Inverse() * frameOf(piece)`.
function WeaponService.preview(look: any, pivot: CFrame, parent: Instance): Model?
	local pieces = look.pieces
	if pieces == nil or #pieces == 0 then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = "ArenaPreview"

	-- Une armure se regarde SUR UN CORPS. Posee en tas elle ne dit rien : la
	-- question qu'on lui pose est justement de savoir quelle silhouette elle
	-- donne. Chaque groupe part donc a la place de son membre, a l'echelle de
	-- ce membre, d'apres le squelette mesure de `Config`.
	local function placeAt(group: { any }, where: CFrame, scale: Vector3?)
		for _, piece in group do
			local part = makePiece(piece, scale)
			part.Anchored = true
			part.CFrame = where * frameOf(piece, scale)
			part.Parent = model
		end
	end

	if look.worn ~= nil then
		local fit = look.worn.fit == true
		local origin = triple(look.worn.at)
		for limbName, group in groupByLimb(look) do
			local bone = nil
			for _, entry in Config.loadout.previewRig do
				if entry.limb == limbName then
					bone = entry
				end
			end
			if bone == nil then
				continue
			end
			placeAt(
				group,
				pivot * CFrame.new(triple(bone.at) + origin),
				if fit then triple(bone.size) else nil
			)
		end
	else
		placeAt(pieces, pivot, nil)
	end

	model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
	model.Parent = parent
	return model
end

-- Le corps nu qui va dessous, aux memes mesures. Sans lui on ne voit pas si
-- l'armure couvre : c'est tout l'enjeu.
function WeaponService.previewBody(pivot: CFrame, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "ArenaPreviewBody"
	for _, bone in Config.loadout.previewRig do
		local part = Instance.new("Part")
		part.Name = bone.limb
		part.Size = triple(bone.size)
		part.CFrame = pivot * CFrame.new(triple(bone.at))
		part.Anchored = true
		part.CanCollide = false
		part.Color = Color3.fromRGB(196, 158, 128)
		part.Material = Enum.Material.SmoothPlastic
		part.Parent = model
	end
	model.Parent = parent
	return model
end

-- Les deux autres emplacements. Meme assemblage, autre membre, autre nom
-- d'articulation — et le meme soin : l'articulation vit sur le MEMBRE, donc
-- detruire le modele ne suffit pas a la faire disparaitre.
local function stripSlot(character: Model, modelName: string, jointName: string)
	for _, child in character:GetChildren() do
		if child.Name == modelName then
			child:Destroy()
		end
	end
	dropJoints(character, jointName)
end

local function attachAt(
	character: Model,
	look: any,
	modelName: string,
	jointName: string,
	limbName: string,
	origin: Vector3,
	fit: boolean,
	only: { any }?
): boolean
	local limb = limbOf(character, limbName)
	if limb == nil then
		return false
	end

	local scale = if fit then limb.Size else nil
	local model, root, rootFrame = buildModel(modelName, look, scale, only)
	if model == nil or root == nil or rootFrame == nil then
		return false
	end

	local joint = Instance.new("Motor6D")
	joint.Name = jointName
	joint.Part0 = limb
	joint.Part1 = root
	joint.C0 = CFrame.new(origin) * rootFrame
	joint.Parent = limb

	model.Parent = character
	return true
end

-- Habille ce personnage de toutes les armures passees. Un joueur peut en
-- porter plusieurs, donc on balaie par NOM plutot que de chercher un enfant
-- unique : deux modeles du meme nom et `FindFirstChild` en designe un au
-- hasard, c'est le piege des doublons de Rojo repris sur un personnage.
local function dressWorn(character: Model, items: { any })
	stripSlot(character, WORN_MODEL, WORN_NAME)
	for _, item in items do
		local look = if item ~= nil then item.look else nil
		if look == nil or look.worn == nil then
			continue
		end
		local origin = triple(look.worn.at)
		local fit = look.worn.fit == true
		for limbName, group in groupByLimb(look) do
			attachAt(character, look, WORN_MODEL, WORN_NAME, limbName, origin, fit, group)
		end
	end
end

-- L'armure qu'on porte. Rejouee a chaque reapparition, comme l'arme : sinon
-- elle disparaitrait a la premiere manche perdue.
function WeaponService.wear(player: Player, items: { any })
	wornItems[player] = items
	local character = player.Character
	if character == nil then
		return
	end
	dressWorn(character, items)
end

-- L'objet sort dans la main gauche le temps de s'en servir, puis repart. Le
-- garder en main entre deux usages dirait « il se soigne » en permanence, ce
-- qui est une information fausse — et la fausse information est pire que pas
-- d'information du tout.
function WeaponService.flashOffhand(player: Player, item: any, seconds: number)
	local character = player.Character
	if character == nil then
		return
	end
	local look = if item ~= nil then item.look else nil
	if look == nil or look.offhand == nil then
		return
	end

	-- Un jeton, pour la meme raison que le geste d'arme : une utilisation
	-- lancee il y a deux secondes ne doit pas ranger l'objet de celle qui vient
	-- de partir.
	local token = (offhandToken[player] or 0) + 1
	offhandToken[player] = token

	stripSlot(character, OFFHAND_MODEL, OFFHAND_NAME)
	attachAt(character, look, OFFHAND_MODEL, OFFHAND_NAME, "LeftHand", triple(look.offhand), false)

	local held = math.max(seconds, Config.loadout.offhandSeconds)
	task.delay(held, function()
		if offhandToken[player] ~= token then
			return
		end
		local current = player.Character
		if current ~= nil then
			stripSlot(current, OFFHAND_MODEL, OFFHAND_NAME)
		end
	end)
end

-- Construit l'arme sur le personnage actuel du joueur. Silencieux s'il n'y a
-- pas de personnage ou pas de main : ce n'est pas une erreur, c'est un joueur
-- en train de reapparaitre, et `CharacterAdded` repassera.
local function build(player: Player, item: any)
	local character = player.Character
	if character == nil then
		return
	end

	WeaponService.clear(player)

	local grip = WeaponService.attach(character, item)
	if grip == nil then
		return
	end

	joints[player] = grip
	restC0[player] = grip.C0
end

-- Montre cette arme, ou rien si `item` est nil. Ne reconstruit que si l'arme
-- a change : c'est appele a chaque coup, et a chaque recalcul de
-- statistiques.
function WeaponService.show(player: Player, item: any)
	local current = wanted[player]
	if current ~= nil and item ~= nil and current.id == item.id then
		-- Meme arme, mais le personnage a pu reapparaitre entre-temps : on
		-- verifie que l'articulation est encore vivante avant de ne rien
		-- faire.
		local grip = joints[player]
		if grip ~= nil and grip.Parent ~= nil then
			return
		end
	end

	wanted[player] = item
	if item == nil then
		WeaponService.clear(player)
		return
	end
	build(player, item)
end

-- Le geste, bras et arme ensemble. Il part vite et il revient lentement : un
-- coup est sec, un retour au repos ne l'est pas. Les chiffres viennent de
-- `Config.loadout.weaponMotion` pour l'arme et de `bodyMotion` pour la main, et
-- dependent de l'arme, pas de la classe — c'est le marteau qui s'abat, pas le
-- Colosse.
function WeaponService.swing(player: Player, item: any)
	local motion = Config.loadout.weaponMotion
	local look = if item ~= nil then item.look else nil

	-- LE BRAS PART MEME SANS ARME. `item` vaut nil quand la classe frappe a
	-- mains nues, et un coup de poing dont rien ne bouge est un coup qu'on croit
	-- avoir rate. C'est le seul geste du jeu qui n'a pas d'arme a animer, donc
	-- le seul qui serait entierement invisible.
	reachOut(player, if look ~= nil then look.swing else "fist")

	-- UN SEUL JETON POUR LES DEUX, parce que c'est un seul geste : le bras et
	-- l'arme doivent revenir ensemble, ou pas du tout. Deux jetons separes et un
	-- coup rapide reposerait l'arme en laissant le bras tendu.
	local token = (swingToken[player] or 0) + 1
	swingToken[player] = token

	local grip = joints[player]
	local rest = restC0[player]
	local kind = if look ~= nil then motion[look.swing] else nil
	if kind ~= nil and grip ~= nil and grip.Parent ~= nil and rest ~= nil then
		local target = rest
			* CFrame.new(0, 0, kind.pullStuds)
			* CFrame.Angles(math.rad(kind.pitch), math.rad(kind.yaw), math.rad(kind.roll))

		local out =
			TweenInfo.new(motion.outSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(grip, out, { C0 = target }):Play()
	end

	task.delay(motion.outSeconds, function()
		-- Un coup plus recent est parti : c'est lui qui decidera du retour.
		if swingToken[player] ~= token then
			return
		end
		comeBack(player)

		local still = joints[player]
		local home = restC0[player]
		if still == nil or still.Parent == nil or home == nil then
			return
		end
		local back =
			TweenInfo.new(motion.backSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(still, back, { C0 = home }):Play()
	end)
end

local started = false

function WeaponService.init()
	if started then
		return
	end
	started = true

	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			-- Le personnage arrive membre par membre : la main n'existe pas
			-- forcement a l'instant ou l'evenement part.
			forgetBody(player)
			task.delay(Config.loadout.bodyMotion.settleSeconds, function()
				-- Le corps se prepare pour TOUT LE MONDE, arme ou pas : un coup
				-- de poing bouge le bras et le buste aussi.
				prepareBody(player)
			end)
			task.defer(function()
				-- L'armure d'abord : elle ne depend pas de l'arme, et un joueur
				-- qui n'a pas d'arme principale en porte quand meme une.
				local character = player.Character
				local dressed = wornItems[player]
				if character ~= nil and dressed ~= nil then
					dressWorn(character, dressed)
				end

				local item = wanted[player]
				if item == nil then
					return
				end
				joints[player] = nil
				build(player, item)
			end)
		end)
	end

	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)

	Players.PlayerRemoving:Connect(function(player)
		forgetBody(player)
		wanted[player] = nil
		joints[player] = nil
		restC0[player] = nil
		swingToken[player] = nil
		wornItems[player] = nil
		offhandToken[player] = nil
	end)
end

return WeaponService
