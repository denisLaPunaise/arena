--!strict
--[[
	SandboxService — le bac a sable, quand on est seul.

	POURQUOI CE SERVICE EXISTE. Une partie demande deux joueurs, et la boucle de
	MatchService attend indefiniment le deuxieme. Seul dans sa propre place, il
	n'y avait donc aucun moyen d'essayer une classe, une arme ou un pouvoir :
	l'ecran disait « en attente d'un deuxieme joueur » et c'etait tout. Quatorze
	classes, treize objets et quarante-deux paliers 6 etaient injouables sans
	trouver quelqu'un.

	CE SERVICE N'EST PAS UN BOT, et la difference n'est pas un detail. Tout le
	combat est indexe par `Player` — qui a quelle classe, quels points, quel
	equipement, qui est a terre. Un adversaire qui se bat vraiment demanderait
	de rendre generiques les rosters du combat, de l'equipement, de l'arbre et
	de l'agonie d'un seul coup, ce qui mettrait en risque tout l'equilibrage
	deja pose. Et il ne repondrait pas a la question qui compte : un bot dit
	qu'une mecanique fonctionne, il ne dit jamais qu'un duel est tendu. Le
	mannequin est une cible, pas un adversaire, et c'est assume.

	TROIS GARDE-FOUS, verifies a chaque ouverture :
	  1. `Config.sandbox.enabled`,
	  2. on est SEUL — c'est le plus solide, parce qu'aucune partie, aucun
	     classement et aucune piece ne peut exister avec un seul joueur, donc
	     rien de ce qui se gagne n'est atteignable depuis ici,
	  3. on est en partie privee ou dans Studio.
	Des qu'un deuxieme joueur arrive, le bac a sable se referme et la vraie
	boucle reprend la main.

	CE SERVICE NE DECIDE DE RIEN DU JEU. Il ne fait qu'appeler les services
	existants dans le bon ordre — exactement celui de MatchService, arbre puis
	equipement — et leur ouvrir trois portes nommees : `LoadoutService.setSandbox`
	pour le budget, `SkillTreeService.grantSandboxPoint` pour les points, et
	`CombatService.setPractice` pour le mannequin. Ces trois portes sont refermees
	en sortant.

	C'est MatchService qui l'appelle, jamais l'inverse.
]]

local SandboxService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Classes = require(Arena:WaitForChild("Classes"))
local Combat = require(Arena:WaitForChild("Combat"))
local ClassLooks = require(Arena:WaitForChild("ClassLooks"))
local Config = require(Arena:WaitForChild("Config"))
local RemoteGuard = require(script.Parent:WaitForChild("RemoteGuard"))

local Remotes = Arena:WaitForChild("Remotes")
local hudRemote = Remotes:WaitForChild("Hud") :: RemoteEvent
local sandboxRemote = Remotes:WaitForChild("Sandbox") :: RemoteEvent

local CombatService = require(script.Parent:WaitForChild("CombatService"))
local DownedService = require(script.Parent:WaitForChild("DownedService"))
local LoadoutService = require(script.Parent:WaitForChild("LoadoutService"))
local MapService = require(script.Parent:WaitForChild("MapService"))
local SkillTreeService = require(script.Parent:WaitForChild("SkillTreeService"))
local Venue = require(script.Parent:WaitForChild("Venue"))
local WeaponService = require(script.Parent:WaitForChild("WeaponService"))
local ZoneService = require(script.Parent:WaitForChild("ZoneService"))

local FOLDER_NAME = "ArenaSandbox"
-- Le joueur est en equipe A. Le mannequin n'est dans aucune equipe : il
-- n'entre pas dans le roster du combat, donc la question ne se pose pas.
local TEAM = "A"

type Dummy = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	stats: Combat.Stats,
	-- Retenu pour pouvoir le rebatir exactement au meme endroit : un mannequin
	-- mort se RECONSTRUIT, il ne se soigne pas.
	at: CFrame,
	deadUntil: number?,
}

-- L'ETAT. Il n'y a qu'un joueur, par construction, donc une seule session.
local entry: CombatService.Entry? = nil
local running = false
local map: Instance? = nil

local dummies: { Dummy } = {}
-- Combien on en veut. Separe de `#dummies` parce que c'est un reglage que le
-- joueur change, alors que la liste suit les morts et les retours.
local wantedDummies = Config.sandbox.dummy.startingCount
local dummyClassId = Config.sandbox.dummy.classId

local zoneOn = Config.sandbox.zoneOnByDefault

-- La derniere chose annoncee au joueur, pour que la boucle n'ecrase pas un
-- message d'un quart de seconde.
local notice = ""
local noticeUntil = 0

--------------------------------------------------------------------------------
-- LES GARDE-FOUS
--------------------------------------------------------------------------------

-- Vrai si le bac a sable peut s'ouvrir maintenant. Renvoie aussi la raison du
-- refus, pour que la console le dise au lieu de ne rien faire.
function SandboxService.availability(): (boolean, string)
	local rules = Config.sandbox
	if not rules.enabled then
		return false, "coupé dans Config.sandbox.enabled"
	end

	local players = Players:GetPlayers()
	if #players == 0 then
		return false, "personne en jeu"
	end
	if #players > rules.maxPlayers then
		return false, "plus d'un joueur en jeu"
	end
	-- La reponse a « sommes-nous en prive » vient de Venue : la progression et
	-- la boucle de partie posent la meme question, et trois copies de la meme
	-- condition finissent par ne plus dire la meme chose.
	if rules.privateOnly and not Venue.isPrivate() then
		return false, "partie publique (Config.sandbox.privateOnly)"
	end

	return true, ""
end

function SandboxService.isRunning(): boolean
	return running
end

--------------------------------------------------------------------------------
-- LE MANNEQUIN
--------------------------------------------------------------------------------

local function folder(): Folder
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = FOLDER_NAME
	made.Parent = Workspace
	return made
end

local function className(classId: string): string
	local class = Classes.byId[classId]
	return if class then class.name else classId
end

local function piece(name: string, size: Vector3, color: Color3): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	-- On se cogne dedans, mais aucun rayon ne le voit : un mannequin qui
	-- arreterait un rayon de visee passerait pour une couverture, et le
	-- Spectre comme le Traqueur liraient le decor de travers.
	part.CanCollide = true
	part.CanQuery = false
	part.CanTouch = false
	part.Anchored = true
	return part
end

local function destroyDummies()
	for index = #dummies, 1, -1 do
		dummies[index].model:Destroy()
		table.remove(dummies, index)
	end
end

-- Ou se pose le mannequin numero `index` : devant le joueur, aligne. Devant et
-- pas autour, pour qu'on puisse en frapper un sans toucher ses voisins.
local function dummyCFrame(index: number, count: number): CFrame?
	local player = if entry ~= nil then entry.player else nil
	if player == nil then
		return nil
	end

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end

	local rules = Config.sandbox.dummy
	-- Centre la rangee sur l'axe du regard : avec trois mannequins, celui du
	-- milieu est pile devant.
	local offset = (index - (count + 1) / 2) * rules.spacingStuds
	local base = root.CFrame * CFrame.new(offset, 0, -rules.distanceStuds)

	-- Face au joueur, et d'aplomb : on reprend la hauteur du joueur plutot que
	-- celle du point calcule, qui a pivote avec la camera.
	local at = Vector3.new(base.Position.X, root.Position.Y, base.Position.Z)
	return CFrame.lookAt(at, Vector3.new(root.Position.X, at.Y, root.Position.Z))
end

local function buildDummy(at: CFrame): Dummy?
	local stats = Config.classStats[dummyClassId]
	if stats == nil then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = "Mannequin"

	-- Un rig R6 reduit a l'essentiel : un torse, une tete, et la racine que
	-- tout le code de combat cherche par son nom.
	local root = piece("HumanoidRootPart", Vector3.new(2, 2, 1), Color3.fromRGB(70, 76, 92))
	root.Transparency = 1
	root.CFrame = at
	root.Parent = model
	model.PrimaryPart = root

	local torso = piece("Torso", Vector3.new(2, 2, 1), Color3.fromRGB(96, 104, 124))
	torso.CFrame = at
	torso.Parent = model

	local head = piece("Head", Vector3.new(1.4, 1.4, 1.4), Color3.fromRGB(216, 196, 150))
	head.CFrame = at * CFrame.new(0, 1.7, 0)
	head.Parent = model

	-- Une bande de couleur a hauteur de poitrine : c'est elle qu'on vise, et
	-- elle rend le mannequin reconnaissable d'un coup d'oeil au milieu du decor.
	local band = piece("Band", Vector3.new(2.1, 0.5, 1.1), Color3.fromRGB(230, 96, 86))
	band.CFrame = at * CFrame.new(0, 0.4, 0)
	band.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = stats.maxHealth
	humanoid.Health = stats.maxHealth
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.DisplayName = string.format("Mannequin · %s", className(dummyClassId))
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.Parent = model

	-- Sans ca il se croit en train de tomber, pour toujours : toutes ses parts
	-- sont ancrees, donc il ne touche jamais le sol. L'etat Physics arrete sa
	-- machine a etats, qui n'a rien a decider sur un mannequin immobile.
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	model.Parent = folder()

	-- Le mannequin porte le couvre-chef de sa classe : c'est le seul endroit
	-- du jeu ou l'on peut voir les quatorze sans quatorze joueurs.
	task.spawn(WeaponService.attachHeadgear, model, (ClassLooks :: any)[dummyClassId])

	return {
		model = model,
		humanoid = humanoid,
		root = root,
		stats = stats,
		at = at,
		deadUntil = nil,
	}
end

-- Reconstruit la rangee au nombre voulu. Appele au changement de nombre, de
-- classe, et a chaque reapparition du joueur : la rangee se pose devant lui,
-- donc elle doit suivre.
local function placeDummies()
	destroyDummies()

	local count = math.clamp(wantedDummies, 0, Config.sandbox.dummy.maxCount)
	for index = 1, count do
		local at = dummyCFrame(index, count)
		if at == nil then
			break
		end
		local made = buildDummy(at)
		if made ~= nil then
			table.insert(dummies, made)
		end
	end
end

-- Le mannequin le plus proche a portee. C'est le premier des deux crochets que
-- CombatService consulte, et seulement quand aucun adversaire joueur n'est a
-- portee — ce qui, seul, est toujours le cas.
local function resolvePractice(attacker: CombatService.Entry, range: number): BasePart?
	local character = attacker.player.Character
	local from = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if from == nil or not from:IsA("BasePart") then
		return nil
	end

	-- Les mannequins ne se font pas bouclier entre eux, comme les joueurs.
	local bodies: { Instance } = {}
	for _, dummy in dummies do
		table.insert(bodies, dummy.model)
	end

	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, dummy in dummies do
		if dummy.humanoid.Health <= 0 then
			continue
		end
		local distance = (dummy.root.Position - from.Position).Magnitude
		if
			distance <= range
			and distance < bestDistance
			and CombatService.inSight(from, dummy.root, bodies)
		then
			best = dummy.root
			bestDistance = distance
		end
	end
	return best
end

local function dummyOf(part: BasePart): Dummy?
	for _, dummy in dummies do
		if dummy.root == part then
			return dummy
		end
	end
	return nil
end

-- Le coup sur le mannequin. Il traverse `Combat.resolveHit`, la MEME fonction
-- que le combat reel, avec les statistiques d'une vraie classe : c'est ce qui
-- rend le chiffre utile plutot qu'indicatif.
local function strikePractice(part: BasePart, stats: Combat.Stats, attackerHealth: number): number
	local dummy = dummyOf(part)
	if dummy == nil or dummy.humanoid.Health <= 0 then
		return 0
	end

	local result = Combat.resolveHit({
		attackerStats = stats,
		attackerHealth = attackerHealth,
		defenderStats = dummy.stats,
		defenderHealth = dummy.humanoid.Health,
		config = Config,
	})

	local passed = math.min(result.damage, dummy.humanoid.Health)
	dummy.humanoid.Health -= passed
	return passed
end

-- Les mannequins morts reviennent tout seuls. Sans ca, la premiere serie de
-- coups vide le stand de tir et il faut recliquer pour continuer.
--
-- DEUX CHOSES QUE SEULE LA SONDE A MONTREES, le 26 octobre 2026 :
--
-- 1. UN `Humanoid` MORT NE SE SOIGNE PAS. Des que ses PV touchent zero, Roblox
--    le fait entrer dans l'etat Dead, et lui rendre ses PV ne le releve pas :
--    il reste mort, a plein de vie. Un mannequin se RECONSTRUIT donc, au meme
--    endroit, et c'est pour ca qu'on retient son `CFrame`.
-- 2. LA MORT SE CONSTATE ICI, elle n'est pas notee par le coup qui l'a causee.
--    La premiere version posait l'echeance dans le chemin du coup, donc un
--    mannequin mort autrement ne revenait jamais. Constater l'etat plutot que
--    l'annoncer n'oublie aucun cas, et c'est deux lignes de moins.
local function reviveDummies()
	local now = os.clock()
	-- A l'envers, parce qu'un mannequin peut disparaitre de la liste au passage.
	for index = #dummies, 1, -1 do
		local dummy = dummies[index]
		if dummy.humanoid.Health > 0 then
			dummy.deadUntil = nil
			continue
		end

		local deadline = dummy.deadUntil
		if deadline == nil then
			dummy.deadUntil = now + Config.sandbox.dummy.respawnSeconds
			continue
		end
		if now < deadline then
			continue
		end

		local at = dummy.at
		dummy.model:Destroy()
		local rebuilt = buildDummy(at)
		if rebuilt ~= nil then
			dummies[index] = rebuilt
		else
			table.remove(dummies, index)
		end
	end
end

--------------------------------------------------------------------------------
-- LE JOUEUR
--------------------------------------------------------------------------------

local function tell(title: string, status: string)
	local current = entry
	if current == nil then
		return
	end

	local zone = ""
	if ZoneService.isActive() then
		local snapshot = ZoneService.snapshot()
		local remaining = snapshot.secondsUntilNextShrink
		zone = if remaining == nil
			then "Zone  ·  refermée"
			else string.format("Zone  ·  resserrement dans %d s", math.ceil(remaining))
	end

	local tree = ""
	local state = SkillTreeService.stateOf(current.player)
	if state ~= nil then
		local points = state.pointsEarned - state.pointsSpent
		local tier = if state.branchId == nil
			then "aucune branche"
			else string.format("palier %d / %d", state.tier, Config.skillTree.tiers)
		tree = if points > 0
			then string.format("%s  ·  %d à dépenser  [T]", tier, points)
			else tier
	end

	hudRemote:FireClient(current.player, {
		title = title,
		status = status,
		zone = zone,
		alert = "",
		tree = tree,
	})
end

local function say(message: string)
	notice = message
	noticeUntil = os.clock() + 3
end

-- Les trois couches de statistiques, dans l'ordre et jamais autrement : classe
-- nue, puis arbre, puis equipement. C'est le meme ordre que MatchService, et
-- c'est ce qui fait que l'armure lourde retire un pourcentage de la vitesse que
-- l'arbre a deja donnee.
local function refreshStats()
	local current = entry
	if current == nil then
		return
	end
	SkillTreeService.refreshStats({ current })
	LoadoutService.refreshStats({ current })
end

local function spawnPlayer()
	local current = entry
	local currentMap = map
	if current == nil or currentMap == nil then
		return
	end

	refreshStats()

	local positions = MapService.spawnPositions(currentMap, Config, TEAM)
	current.player:LoadCharacter()

	local character = current.player.Character
	if character == nil then
		return
	end

	local center = MapService.zoneCenter(currentMap, Config)
	local position = positions[1]
	character:PivotTo(CFrame.lookAt(position, Vector3.new(center.X, position.Y, center.Z)))

	CombatService.applyStats(current.player, current.stats)

	-- La rangee se pose devant le joueur, donc elle se repose a chaque
	-- apparition : sinon on reapparait dos aux mannequins.
	placeDummies()
end

-- Depuis quand le joueur n'est plus debout. Un compteur plutot qu'un
-- `task.wait` : attendre dans la boucle figerait l'affichage et les mannequins
-- pendant trois secondes.
local downSince: number? = nil

-- Remet le joueur debout et vivant. Il n'y a personne pour le relever, donc
-- l'agonie se termine toujours ainsi — mais elle a bien lieu, et c'est le seul
-- moyen de la regarder sans un deuxieme joueur.
local function reviveIfNeeded()
	local current = entry
	if current == nil then
		return
	end

	local status = DownedService.statusOf(current.player)
	local character = current.player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local dead = humanoid == nil or humanoid.Health <= 0

	if status == "standing" and not dead then
		downSince = nil
		return
	end

	local since = downSince
	if since == nil then
		downSince = os.clock()
		return
	end
	if (os.clock() - since) < Config.sandbox.reviveSeconds then
		return
	end

	downSince = nil
	DownedService.resetRound()
	spawnPlayer()
	say("Remis debout")
end

--------------------------------------------------------------------------------
-- CE QUE LE JOUEUR DEMANDE
--------------------------------------------------------------------------------

-- Change de classe. L'arbre repart de zero, et c'est la verite du jeu : un
-- arbre est attache a une classe, et le troisieme principe du projet est qu'il
-- se remet a zero.
local function setClass(classId: string)
	local current = entry
	if current == nil or Config.classStats[classId] == nil then
		return
	end

	current.classId = classId
	current.stats = Config.classStats[classId]

	-- Le roster se repose en entier : il recalcule les affinites d'equipement
	-- et previent AbilityService, qui range ses pouvoirs par classe.
	CombatService.setRoster({ current })
	DownedService.setRoster({ current })
	DownedService.resetRound()
	SkillTreeService.beginMatch({ current })
	SkillTreeService.openSpending(Config.sandbox.spendWindowSeconds)

	spawnPlayer()
	LoadoutService.push(current.player)
	say(string.format("Classe : %s", className(classId)))
end

local function setDummyClass(classId: string)
	if Config.classStats[classId] == nil then
		return
	end
	dummyClassId = classId
	placeDummies()
	say(string.format("Mannequin : %s", className(classId)))
end

local function setDummyCount(count: number)
	wantedDummies = math.clamp(math.floor(count), 0, Config.sandbox.dummy.maxCount)
	placeDummies()
	say(string.format("%d mannequin(s)", wantedDummies))
end

local function setZone(on: boolean)
	local currentMap = map
	zoneOn = on
	if currentMap == nil then
		return
	end
	if on then
		ZoneService.start(MapService.zoneCenter(currentMap, Config), nil)
		say("Zone allumée")
	else
		ZoneService.stop()
		say("Zone coupée")
	end
end

local function grantPoints()
	local current = entry
	if current == nil then
		return
	end
	local granted = SkillTreeService.grantSandboxPoint(current.player)
	if granted <= 0 then
		say("L'arbre est coupé dans Config")
		return
	end
	refreshStats()
	say(string.format("+%d point d'arbre", granted))
end

local function healFull()
	local current = entry
	if current == nil then
		return
	end
	local character = current.player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil then
		return
	end
	humanoid.Health = humanoid.MaxHealth
	say("Soigné")
end

-- Ce que le panneau voit. Tout vient du serveur : le client n'a aucune liste de
-- classes a lui, donc il ne peut pas en afficher une qui n'existe plus.
local function viewFor(): any
	local current = entry

	local classList: { any } = {}
	for _, class in Classes.all do
		table.insert(classList, { id = class.id, name = class.name })
	end
	table.sort(classList, function(a, b)
		return a.name < b.name
	end)

	local state = if current ~= nil then SkillTreeService.stateOf(current.player) else nil

	return {
		kind = "sandbox",
		running = running,
		classId = if current ~= nil then current.classId else nil,
		classes = classList,
		dummyClassId = dummyClassId,
		dummyCount = wantedDummies,
		dummyMax = Config.sandbox.dummy.maxCount,
		zoneOn = zoneOn,
		budget = Config.sandbox.budgetPoints,
		points = if state ~= nil then state.pointsEarned - state.pointsSpent else 0,
		tier = if state ~= nil then state.tier else 0,
		notice = if os.clock() < noticeUntil then notice else "",
	}
end

local function push()
	local current = entry
	if current == nil then
		return
	end
	sandboxRemote:FireClient(current.player, viewFor())
end

local function onClientEvent(player: Player, payload: any)
	-- Le serveur ne croit rien : il verifie que ce joueur EST la session en
	-- cours. Sans ca, un client bricole pourrait s'offrir une classe pendant
	-- une vraie partie, ce qui est precisement ce que les garde-fous
	-- interdisent.
	local current = entry
	if not running or current == nil or current.player ~= player then
		return
	end
	if typeof(payload) ~= "table" then
		return
	end

	local what = payload.what
	if what == "class" and typeof(payload.classId) == "string" then
		setClass(payload.classId)
	elseif what == "dummyClass" and typeof(payload.classId) == "string" then
		setDummyClass(payload.classId)
	elseif what == "dummies" and typeof(payload.count) == "number" then
		setDummyCount(payload.count)
	elseif what == "zone" then
		setZone(payload.on == true)
	elseif what == "points" then
		grantPoints()
	elseif what == "heal" then
		healFull()
	elseif what == "respawn" then
		spawnPlayer()
		say("Réapparu")
	end

	push()
end

--------------------------------------------------------------------------------
-- LA SESSION
--------------------------------------------------------------------------------

local function teardown()
	running = false

	CombatService.setActive(false)
	DownedService.setActive(false)
	ZoneService.stop()
	CombatService.setPractice(nil)
	LoadoutService.setSandbox(nil)
	SkillTreeService.closeSpending()
	SkillTreeService.setSandbox(false)
	SkillTreeService.endMatch()

	destroyDummies()
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	CombatService.setRoster({})
	DownedService.setRoster({})
	CombatService.clearTemporary()

	entry = nil
	push()
end

-- Ouvre le bac a sable pour ce joueur et ne rend la main que quand il doit se
-- fermer : un deuxieme joueur est arrive, ou celui-la est parti. C'est
-- MatchService qui appelle, dans sa boucle, exactement la ou il attendait.
function SandboxService.run(resolvedMap: Instance, player: Player)
	map = resolvedMap

	local current: CombatService.Entry = {
		player = player,
		team = TEAM,
		classId = Config.sandbox.startingClassId,
		stats = Config.classStats[Config.sandbox.startingClassId],
	}
	entry = current
	running = true

	-- Les trois portes. Elles sont refermees par `teardown`, quoi qu'il arrive.
	LoadoutService.setSandbox({
		budgetPoints = Config.sandbox.budgetPoints,
		maxItems = Config.sandbox.maxItems,
		maxPerCategory = Config.sandbox.maxPerCategory,
	})
	CombatService.setPractice({
		resolve = resolvePractice,
		strike = strikePractice,
	})

	CombatService.setRoster({ current })
	DownedService.setRoster({ current })
	DownedService.resetRound()
	SkillTreeService.beginMatch({ current })
	SkillTreeService.setSandbox(true)
	SkillTreeService.openSpending(Config.sandbox.spendWindowSeconds)

	CombatService.setActive(true)
	DownedService.setActive(true)

	spawnPlayer()
	setZone(zoneOn)

	print(
		string.format(
			"[Arena] Bac a sable ouvert pour %s (%s). Panneau : touche %s.",
			player.Name,
			className(current.classId),
			Config.sandbox.toggleKey
		)
	)

	push()

	while running do
		task.wait(0.25)

		if player.Parent == nil then
			break
		end
		if #Players:GetPlayers() > Config.sandbox.maxPlayers then
			break
		end
		if not Config.sandbox.enabled then
			break
		end

		-- La fenetre de depense reste ouverte : dans un bac a sable, pouvoir
		-- monter un palier au milieu d'un essai est tout l'interet.
		if SkillTreeService.secondsLeft() == nil then
			SkillTreeService.openSpending(Config.sandbox.spendWindowSeconds)
		end

		reviveDummies()
		reviveIfNeeded()

		local showing = if os.clock() < noticeUntil then notice else "BAC À SABLE"
		local alive = 0
		for _, dummy in dummies do
			if dummy.humanoid.Health > 0 then
				alive += 1
			end
		end
		tell(
			showing,
			string.format(
				"%s  ·  %d mannequin(s)  ·  %s pour le panneau",
				className(current.classId),
				alive,
				Config.sandbox.toggleKey
			)
		)
		push()
	end

	print(string.format("[Arena] Bac a sable ferme pour %s.", player.Name))
	teardown()
end

function SandboxService.init()
	sandboxRemote.OnServerEvent:Connect(RemoteGuard.wrap("Sandbox", onClientEvent))

	-- Un garde-fou dans l'esprit des autres : une classe de depart ou de
	-- mannequin qui n'existe pas donnerait un joueur sans PV ni attaque, ou un
	-- stand de tir vide, sans la moindre erreur.
	for label, classId in
		{
			["Config.sandbox.startingClassId"] = Config.sandbox.startingClassId,
			["Config.sandbox.dummy.classId"] = Config.sandbox.dummy.classId,
		}
	do
		if Config.classStats[classId] == nil then
			error(
				string.format(
					"[Arena] %s vaut « %s », qui n'est pas une classe connue.",
					label,
					tostring(classId)
				)
			)
		end
	end
end

return SandboxService
