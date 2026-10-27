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

	LE BRAS BOUGE AUSSI, ET PAS PAR UN `Motor6D`. Le premier jet visait
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
local ARM_NAME = "ArenaArm"
local TARGET_NAME = "ArenaHandTarget"

-- Ce que chaque joueur est cense porter. C'est la memoire qui permet de
-- rebatir l'arme apres une mort, et de ne rien rebatir quand l'arme n'a pas
-- change — reconstruire a chaque coup ferait clignoter le modele.
local wanted: { [Player]: any } = {}
local joints: { [Player]: Motor6D } = {}
local restC0: { [Player]: CFrame } = {}

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

local function forgetArm(player: Player)
	local control = armControl[player]
	if control ~= nil then
		control:Destroy()
	end
	local target = armTarget[player]
	if target ~= nil then
		target:Destroy()
	end
	armControl[player] = nil
	armTarget[player] = nil
	armRest[player] = nil
end

-- Prepare le bras droit du personnage actuel. Renvoie faux quand le squelette
-- ne s'y prete pas : un avatar R6 n'a qu'une seule part pour tout le bras, donc
-- il n'y a aucune articulation a flechir. Dans ce cas l'arme bouge et le bras
-- non, exactement comme avant — mieux vaut ca qu'un bras casse.
local function prepareArm(player: Player): boolean
	local existing = armControl[player]
	if existing ~= nil and existing.Parent ~= nil then
		return true
	end
	forgetArm(player)

	local character = player.Character
	if character == nil then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local torso = character:FindFirstChild("UpperTorso")
	local hand = character:FindFirstChild("RightHand")
	local upper = character:FindFirstChild("RightUpperArm")
	if humanoid == nil or upper == nil then
		return false
	end
	if torso == nil or not torso:IsA("BasePart") then
		return false
	end
	if hand == nil or not hand:IsA("BasePart") then
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

	armControl[player] = control
	armTarget[player] = target
	armRest[player] = target.CFrame.Position
	return true
end

-- La main part chercher un point. `pose` porte le meme nom que le geste de
-- l'arme — « slash », « overhead »... — plus « fist » quand il n'y a pas d'arme
-- du tout.
local function reachOut(player: Player, pose: string)
	if not prepareArm(player) then
		return
	end
	local move = Config.loadout.bodyMotion[pose]
	local target = armTarget[player]
	local control = armControl[player]
	local rest = armRest[player]
	if move == nil or target == nil or control == nil or rest == nil then
		return
	end

	-- L'avant de Roblox est -Z. C'est la seule conversion de tout le fichier, et
	-- elle est ici pour que `Config` parle en mots plutot qu'en axes.
	target.CFrame = CFrame.new(rest + Vector3.new(move.right, move.up, -move.forward))

	local out = TweenInfo.new(
		Config.loadout.weaponMotion.outSeconds,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	TweenService:Create(control, out, { Weight = 1 }):Play()
end

local function comeBack(player: Player)
	local control = armControl[player]
	if control == nil or control.Parent == nil then
		return
	end
	local back = TweenInfo.new(
		Config.loadout.weaponMotion.backSeconds,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	TweenService:Create(control, back, { Weight = 0 }):Play()
end

local function triple(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

local function colorOf(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- La main droite, R15 ou R6. Les deux rigs existent encore sur Roblox et le
-- choix appartient au joueur, pas au jeu : il faut savoir lire les deux.
local function handOf(character: Model): BasePart?
	local r15 = character:FindFirstChild("RightHand")
	if r15 ~= nil and r15:IsA("BasePart") then
		return r15
	end
	local r6 = character:FindFirstChild("Right Arm")
	if r6 ~= nil and r6:IsA("BasePart") then
		return r6
	end
	return nil
end

-- Une piece d'arme : jamais de collision, jamais de masse, jamais de requete
-- spatiale. Une arme qui pousse son porteur ou qui intercepte un rayon de
-- visee serait un bug de combat ne d'un element decoratif.
local function makePiece(name: string, size: { number }, color: { number }): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = triple(size)
	part.Color = colorOf(color)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- L'ARTICULATION NE VIT PAS DANS LE MODELE, ELLE VIT SUR LA MAIN. Detruire
-- le modele de l'arme laisse donc un `Motor6D` orphelin derriere lui, un par
-- changement d'arme, pour toujours. Vu en jeu le 27 octobre 2026 : QUATRE
-- `ArenaGrip` empiles dans la meme main apres cinq changements, tous inertes
-- (`Part1` vide) et tous repondant au meme nom, donc un `FindFirstChild`
-- en designe un au hasard. C'est le meme piege que les doublons de Rojo.
local function dropGrips(character: Model)
	local hand = handOf(character)
	if hand == nil then
		return
	end
	for _, child in hand:GetChildren() do
		if child.Name == GRIP_NAME then
			child:Destroy()
		end
	end
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

	local model = Instance.new("Model")
	model.Name = MODEL_NAME

	local body = makePiece(item.id, look.size, look.color)
	model.PrimaryPart = body
	body.Parent = model

	-- La tete du marteau et le canon du fusil. Un deuxieme `Motor6D` plutot
	-- qu'une soudure : la soudure a besoin que les deux pieces soient deja
	-- placees dans le monde, et elles ne le sont pas encore ici.
	local head = look.head
	if head ~= nil then
		local piece = makePiece("Head", head.size, head.color)
		piece.Parent = model
		local link = Instance.new("Motor6D")
		link.Name = "Head"
		link.Part0 = body
		link.Part1 = piece
		link.C0 = CFrame.new(0, 0, head.atStuds)
		link.Parent = body
	end

	local rest = CFrame.new(triple(look.grip))

	local grip = Instance.new("Motor6D")
	grip.Name = GRIP_NAME
	grip.Part0 = hand
	grip.Part1 = body
	grip.C0 = rest
	grip.Parent = hand

	model.Parent = character
	return grip
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
			forgetArm(player)
			task.delay(Config.loadout.bodyMotion.settleSeconds, function()
				-- Le bras se prepare pour TOUT LE MONDE, arme ou pas : un coup
				-- de poing bouge le bras aussi.
				prepareArm(player)
			end)
			task.defer(function()
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
		forgetArm(player)
		wanted[player] = nil
		joints[player] = nil
		restC0[player] = nil
		swingToken[player] = nil
	end)
end

return WeaponService
