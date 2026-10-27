--!strict
--[[
	AbilityService — les douze pouvoirs de classe, appliques aux personnages.

	Le calcul qui peut se faire sans Roblox est dans Abilities, teste hors de
	Studio. Ici on fait ce que seul Roblox sait faire : poser une mine, dresser
	un mur, rendre quelqu'un invisible, lire si un pied touche le sol.

	POURQUOI CE MODULE NE REQUIERT PAS CombatService. CombatService a besoin
	d'ici (un coup du Duelliste est multiplie, un coup sur un Leurre part sur le
	clone), et d'ici on a besoin d'infliger des degats (une mine, un brasier).
	Si les deux se requeraient, Roblox refuserait de charger. Le sens de la
	dependance est donc : CombatService -> AbilityService, et les degats
	arrivent par un puits que CombatService installe au demarrage
	(`setDamageSink`). Meme chose pour DownedService : c'est AbilityService qui
	pose ses crochets de relevement dedans, jamais l'inverse.

	CE QUI EST VOLONTAIREMENT CENTRALISE ICI :
	- toutes les parts creees par un pouvoir vivent dans un seul dossier, vide
	  entre deux manches. Workspace appartient a la construction des maps.
	- tous les groupes de collision du jeu sont declares au meme endroit, parce
	  qu'une regle de collision oubliee ne se voit qu'en traversant un mur.
	- un pouvoir n'est jamais interroge par son nom depuis ailleurs : on passe
	  par `AbilityService.has`, qui refuse ce qui n'est pas code au lieu de ne
	  rien faire en silence. C'est la lecon des branches creuses.
]]

local AbilityService = {}

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Abilities = require(Arena:WaitForChild("Abilities"))
local Combat = require(Arena:WaitForChild("Combat"))
local Config = require(Arena:WaitForChild("Config"))

local Remotes = Arena:WaitForChild("Remotes")
local abilityRemote = Remotes:WaitForChild("Ability") :: RemoteEvent

local DownedService = require(script.Parent:WaitForChild("DownedService"))
local EffectsService = require(script.Parent:WaitForChild("EffectsService"))
local SkillTreeService = require(script.Parent:WaitForChild("SkillTreeService"))

-- La meme forme que CombatService.Entry, redeclaree ici pour ne pas avoir a
-- requerir CombatService. Si l'une des deux change, l'autre doit suivre : c'est
-- le prix de l'absence de cycle, et il est moins cher qu'un cycle.
export type Entry = {
	player: Player,
	team: string,
	classId: string,
	stats: Combat.Stats,
}

type Mine = {
	owner: Player,
	team: string,
	part: BasePart,
	armedAt: number,
	damage: number,
	radius: number,
}

type Fire = {
	owner: Player,
	part: BasePart,
	until_: number,
	damagePerSecond: number,
	radius: number,
	clings: boolean,
	healsOwner: boolean,
}

type Clone = {
	owner: Player,
	team: string,
	part: BasePart,
	health: number,
	until_: number,
	bursts: boolean,
}

type Slow = {
	until_: number,
	baseSpeed: number,
}

type Mark = {
	by: Player,
	until_: number,
}

local roster: { [Player]: Entry } = {}
local order: { Player } = {}
local active = false

local lastAbilityAt: { [Player]: number } = {}
local minesLeft: { [Player]: number } = {}
local rearmed: { [Player]: boolean } = {}
local phaseUntil: { [Player]: number } = {}
local bondTarget: { [Player]: Player } = {}
local markedBy: { [Player]: Mark } = {}
local clones: { Clone } = {}
local mines: { Mine } = {}
local fires: { Fire } = {}
local slowed: { [Player]: Slow } = {}
local exposedUntil: { [Player]: { until_: number, ratio: number } } = {}
local cloaked: { [Player]: boolean } = {}
local stillSince: { [Player]: number } = {}
local ambushReady: { [Player]: boolean } = {}
local riposteStacks: { [Player]: number } = {}
local revealedUntil: { [Player]: { [Player]: number } } = {}
local lastFootprintAt: { [Player]: number } = {}
local lastFootprintPos: { [Player]: Vector3 } = {}

-- Le puits de degats, installe par CombatService : il applique la reduction de
-- la cible et plafonne aux PV restants, exactement comme un coup.
local damageSink: ((Entry, number) -> number)? = nil
local healSink: ((Player, number) -> ())? = nil

local folder: Folder? = nil

--------------------------------------------------------------------------------
-- LES OUTILS COMMUNS
--------------------------------------------------------------------------------

local function parentFolder(): Folder
	local existing = folder
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end

	local made = Instance.new("Folder")
	made.Name = "ArenaAbilities"
	made.Parent = Workspace
	folder = made
	return made
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	if character == nil then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function pointOf(player: Player): Vector3?
	local root = rootOf(player)
	if root == nil then
		return nil
	end
	return root.Position + Vector3.new(0, 1.5, 0)
end

-- Les adversaires debout d'une equipe donnee, dans un rayon. Un module qui
-- cherche des cibles en cherche tout le temps : cette fonction est appelee par
-- la moitie des pouvoirs.
local function enemiesNear(team: string, position: Vector3, radius: number): { Entry }
	local found: { Entry } = {}
	for _, player in order do
		local entry = roster[player]
		if entry == nil or entry.team == team then
			continue
		end
		if not DownedService.isStanding(player) then
			continue
		end
		local root = rootOf(player)
		if root == nil then
			continue
		end
		if (root.Position - position).Magnitude <= radius then
			table.insert(found, entry)
		end
	end
	return found
end

local function alliesNear(entry: Entry, position: Vector3, radius: number): { Entry }
	local found: { Entry } = {}
	for _, player in order do
		local other = roster[player]
		if other == nil or other.team ~= entry.team or player == entry.player then
			continue
		end
		if not DownedService.isStanding(player) then
			continue
		end
		local root = rootOf(player)
		if root == nil then
			continue
		end
		if (root.Position - position).Magnitude <= radius then
			table.insert(found, other)
		end
	end
	return found
end

local function dealTo(entry: Entry, amount: number): number
	local sink = damageSink
	if sink == nil or amount <= 0 then
		return 0
	end
	return sink(entry, amount)
end

local function healPlayer(player: Player, amount: number)
	local sink = healSink
	if sink ~= nil and amount > 0 then
		sink(player, amount)
	end
end

--------------------------------------------------------------------------------
-- LES GROUPES DE COLLISION
--------------------------------------------------------------------------------
--
-- Deux pouvoirs ont besoin que certaines choses se traversent : le Spectre
-- passe les murs, et le Forgeron de palier 6 laisse passer son equipe. Les
-- groupes sont declares une fois pour toutes au demarrage, parce qu'une regle
-- posee au moment ou on en a besoin finit par etre posee deux fois, ou pas du
-- tout.

local GROUP_COVER = "ArenaCover"
local GROUP_PHASE = "ArenaPhase"
local GROUP_TEAM = { A = "ArenaTeamA", B = "ArenaTeamB" }
local GROUP_WALL_FRIENDLY = { A = "ArenaWallFriendlyA", B = "ArenaWallFriendlyB" }

local groupsReady = false

local function ensureGroups()
	if groupsReady then
		return
	end
	groupsReady = true

	local names = { GROUP_COVER, GROUP_PHASE }
	for _, name in GROUP_TEAM do
		table.insert(names, name)
	end
	for _, name in GROUP_WALL_FRIENDLY do
		table.insert(names, name)
	end

	for _, name in names do
		-- RegisterCollisionGroup leve si le groupe existe deja, ce qui arrive
		-- des la deuxieme partie d'une meme session de Studio.
		pcall(function()
			PhysicsService:RegisterCollisionGroup(name)
		end)
	end

	-- Le Spectre traverse les couverts et les murs, jamais le sol : le sol
	-- reste dans le groupe par defaut, qu'on ne touche pas.
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(GROUP_PHASE, GROUP_COVER, false)
		for _, wall in GROUP_WALL_FRIENDLY do
			PhysicsService:CollisionGroupSetCollidable(GROUP_PHASE, wall, false)
		end
		-- Un mur amical ne bloque que l'equipe d'en face.
		PhysicsService:CollisionGroupSetCollidable(GROUP_WALL_FRIENDLY.A, GROUP_TEAM.A, false)
		PhysicsService:CollisionGroupSetCollidable(GROUP_WALL_FRIENDLY.B, GROUP_TEAM.B, false)
	end)
end

local function setCharacterGroup(player: Player, group: string)
	local character = player.Character
	if character == nil then
		return
	end
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = group
		end
	end
end

-- Appelee par MapService quand une map est validee : c'est la seule facon de
-- savoir quelles parts sont des couverts, puisque les maps ne sont pas dans
-- Git et que seul le contrat de nommage les designe.
-- Le groupe de collision des couvertures de map. Le bouclier deployable de
-- l'equipement s'y met aussi : il bloque les deux equipes, et le Spectre le
-- traverse pendant sa phase, exactement comme un rocher de la map. C'est la
-- seule chose que LoadoutService a besoin de savoir des groupes.
function AbilityService.coverGroup(): string
	ensureGroups()
	return GROUP_COVER
end

function AbilityService.markCover(coverFolder: Instance)
	ensureGroups()
	for _, part in coverFolder:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = GROUP_COVER
		end
	end
	if coverFolder:IsA("BasePart") then
		coverFolder.CollisionGroup = GROUP_COVER
	end
end

--------------------------------------------------------------------------------
-- LE REGISTRE : un pouvoir decrit n'est pas un pouvoir code
--------------------------------------------------------------------------------

-- Les pouvoirs que ce fichier sait reellement executer. Le demarrage compare
-- cette liste au registre de Config et s'arrete net si l'une promet ce que
-- l'autre ne tient pas. C'est volontairement brutal : une classe creuse ne se
-- voit qu'en jeu, et trop tard.
local HANDLED: { [string]: boolean } = {
	lifesteal = true,
	knockback = true,
	footprints = true,
	mines = true,
	phase = true,
	bond = true,
	isolation = true,
	wall = true,
	fire = true,
	clone = true,
	slam = true,
	mark = true,
	cloak = true,
	mend = true,
}

-- Les effets de palier 6 que le jeu sait reellement appliquer. Quatre vivent
-- dans CombatService (le bond, la charge, le bloc jete, le vol sur la zone),
-- les autres ici. Le demarrage compare cette liste aux branches de Config.
--
-- POURQUOI CETTE LISTE EXISTE. Un palier 6 marque `implemented = true` dont
-- personne ne lit le nom coute DEUX points au joueur et ne fait rien. C'est
-- exactement la panne des trois branches creuses du 25 octobre 2026, sauf
-- qu'elle se paie au prix fort et qu'elle n'apparait qu'au bout d'une serie de
-- sept manches — autant dire jamais pendant un test.
local HANDLED_TIER6: { [string]: boolean } = {
	-- CombatService
	dash = true,
	chargePierces = true,
	spreadPiercesArmor = true,
	thrownLeavesCover = true,
	leechFromZone = true,
	-- Traqueur, Artificier, Spectre
	trackShowsHealth = true,
	hitReveals = true,
	ignoresMines = true,
	minesArmInstantly = true,
	minesRearm = true,
	minesLaunchSelf = true,
	phaseExitBurst = true,
	phaseRefundOnHit = true,
	phaseInvisible = true,
	-- Lien, Duelliste, Forgeron
	bondSharesHealing = true,
	bondBoostsAlly = true,
	bondCoversZone = true,
	duelPierces = true,
	riposteSpeeds = true,
	guardNoPenalty = true,
	wallSparesAllies = true,
	wallBurns = true,
	wallOnDown = true,
	-- Pyromane, Leurre, Sismique
	fireClings = true,
	hitIgnites = true,
	fireHealsSelf = true,
	twinClones = true,
	cloneBursts = true,
	cloneCloaks = true,
	slamDamages = true,
	slamOnHit = true,
	bedrockNoKnockback = true,
	-- Parasite, Cameleon, Infirmier
	markJumps = true,
	markLifesteal = true,
	seesWounded = true,
	ambushDouble = true,
	stalkWalks = true,
	huskRecloaks = true,
	remoteRevive = true,
	fieldRegen = true,
	steadyHands = true,
}

local function abilityOf(entry: Entry): string?
	local id = entry.stats.ability
	if typeof(id) ~= "string" then
		return nil
	end
	local declared = Config.abilities.registry[id]
	if declared == nil or not declared.implemented then
		return nil
	end
	return id
end

-- Vrai si ce joueur dispose de l'effet de palier 6 nomme. On passe toujours par
-- la : SkillTreeService renvoie faux pour un effet decrit mais pas code.
local function has(player: Player, effect: string): boolean
	return SkillTreeService.hasEffect(player, effect)
end

--------------------------------------------------------------------------------
-- VOIR CE QU'ON NE DEVRAIT PAS VOIR
--------------------------------------------------------------------------------
--
-- Reveler quelqu'un n'est pas un effet partage : le Traqueur voit la trace, pas
-- son adversaire. Le serveur envoie donc le fait a UN client, qui dessine. Si
-- on posait un Highlight sur le serveur, tout le monde le verrait, et le
-- pouvoir reviendrait a prevenir sa cible qu'elle est reperee.
local function revealTo(viewer: Player, target: Player, seconds: number)
	local byViewer = revealedUntil[viewer]
	if byViewer == nil then
		byViewer = {}
		revealedUntil[viewer] = byViewer
	end

	local now = os.clock()
	local existing = byViewer[target] or 0
	if existing >= now + seconds then
		return
	end
	byViewer[target] = now + seconds

	abilityRemote:FireClient(viewer, {
		kind = "reveal",
		target = target,
		seconds = seconds,
	})
end

local function revealToTeam(entry: Entry, target: Player, seconds: number)
	for _, player in order do
		local other = roster[player]
		if other ~= nil and other.team == entry.team then
			revealTo(player, target, seconds)
		end
	end
end

--------------------------------------------------------------------------------
-- RENDRE INVISIBLE, ET REVENIR EXACTEMENT A L'ETAT D'AVANT
--------------------------------------------------------------------------------

local originalTransparency: { [Player]: { [BasePart]: number } } = {}

local function setBodyTransparency(player: Player, value: number?)
	local character = player.Character
	if character == nil then
		return
	end

	if value == nil then
		-- On ne remet pas « zero partout » : un personnage a des parts
		-- transparentes de naissance, et les ecraser laisserait des traces
		-- visibles a vie.
		local saved = originalTransparency[player]
		if saved ~= nil then
			for part, transparency in saved do
				if part.Parent ~= nil then
					part.Transparency = transparency
				end
			end
			originalTransparency[player] = nil
		end

		local humanoid = humanoidOf(player)
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		end
		return
	end

	if originalTransparency[player] == nil then
		local saved: { [BasePart]: number } = {}
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				saved[part] = part.Transparency
			end
		end
		originalTransparency[player] = saved
	end

	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = math.max(part.Transparency, value)
		end
	end

	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

--------------------------------------------------------------------------------
-- TRAQUEUR — les traces de pas
--------------------------------------------------------------------------------

local function updateFootprints(entry: Entry, now: number)
	local radius = entry.stats.trackRadiusStuds or 0
	local age = entry.stats.trackAgeSeconds or 0
	if radius <= 0 or age <= 0 then
		return
	end

	local viewerRoot = rootOf(entry.player)
	if viewerRoot == nil then
		return
	end

	local tuning = Config.abilities.tuning
	local showsHealth = has(entry.player, "trackShowsHealth")

	for _, player in order do
		local other = roster[player]
		if other == nil or other.team == entry.team then
			continue
		end
		if not DownedService.isStanding(player) then
			continue
		end

		local root = rootOf(player)
		if root == nil then
			continue
		end
		if (root.Position - viewerRoot.Position).Magnitude > radius then
			continue
		end

		-- Une trace par intervalle, et seulement si le pied a vraiment bouge :
		-- sans ca, quelqu'un d'immobile laisse un tas de traces au meme endroit
		-- et se signale mieux qu'en courant.
		local lastAt = lastFootprintAt[player] or 0
		if (now - lastAt) < tuning.footprintIntervalSeconds then
			continue
		end
		local lastPos = lastFootprintPos[player]
		if
			lastPos ~= nil
			and (root.Position - lastPos).Magnitude < tuning.footprintMinMoveStuds
		then
			continue
		end

		lastFootprintAt[player] = now
		lastFootprintPos[player] = root.Position

		local health: number? = nil
		if showsHealth then
			local humanoid = humanoidOf(player)
			health = if humanoid then math.floor(humanoid.Health + 0.5) else nil
		end

		EffectsService.footprint(entry.player, root.Position - Vector3.new(0, 2.6, 0), age, health)
	end
end

--------------------------------------------------------------------------------
-- ARTIFICIER — les mines
--------------------------------------------------------------------------------

local function placeMine(entry: Entry, now: number): boolean
	local left = minesLeft[entry.player] or 0
	if left <= 0 then
		-- Le stock se rearme une fois par manche au palier 6, et une seule.
		if has(entry.player, "minesRearm") and not rearmed[entry.player] then
			rearmed[entry.player] = true
			left = math.floor(entry.stats.mineCount or 0)
			minesLeft[entry.player] = left
		end
		if left <= 0 then
			return false
		end
	end

	local root = rootOf(entry.player)
	if root == nil then
		return false
	end

	local tuning = Config.abilities.tuning

	local part = Instance.new("Part")
	part.Name = "ArenaMine"
	part.Size = Vector3.new(2.4, 0.4, 2.4)
	part.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.6, 0))
	part.Shape = Enum.PartType.Cylinder
	part.Orientation = Vector3.new(0, 0, 90)
	part.Color = Color3.fromRGB(220, 170, 60)
	part.Material = Enum.Material.Neon
	part.Transparency = 0.35
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = parentFolder()

	-- Palier 6 « Demolition » : plus de delai d'armement. La mine cesse d'etre
	-- un piege qu'on prepare pour devenir une arme qu'on pose sous les pieds de
	-- quelqu'un, ce qui est un autre jeu.
	local armDelay = if has(entry.player, "minesArmInstantly") then 0 else tuning.mineArmSeconds

	table.insert(mines, {
		owner = entry.player,
		team = entry.team,
		part = part,
		armedAt = now + armDelay,
		damage = entry.stats.mineDamage or 0,
		radius = entry.stats.mineRadiusStuds or 0,
	})

	minesLeft[entry.player] = left - 1
	Debris:AddItem(part, tuning.mineLifeSeconds)
	return true
end

local function detonate(mine: Mine, now: number)
	local tuning = Config.abilities.tuning
	local position = mine.part.Position

	EffectsService.hit(position + Vector3.new(0, 1.5, 0), 0, nil)

	for _, victim in enemiesNear(mine.team, position, mine.radius) do
		local passed = dealTo(victim, mine.damage)
		local point = pointOf(victim.player)
		if passed > 0 and point ~= nil then
			EffectsService.hit(point, passed, victim.player)
		end

		local root = rootOf(victim.player)
		if root ~= nil then
			local away = root.Position - position
			local flat = Vector3.new(away.X, 0, away.Z)
			if flat.Magnitude > 0 then
				root.AssemblyLinearVelocity = (flat.Unit * tuning.mineKnockbackStuds)
					+ Vector3.new(0, tuning.mineKnockbackUpStuds, 0)
			end
		end
	end

	-- Au palier 6, le poseur est projete par sa propre mine sans la subir :
	-- la mine devient un moyen de se deplacer.
	if has(mine.owner, "minesLaunchSelf") then
		local root = rootOf(mine.owner)
		if root ~= nil and (root.Position - position).Magnitude <= mine.radius then
			local away = root.Position - position
			local flat = Vector3.new(away.X, 0, away.Z)
			local direction = if flat.Magnitude > 0 then flat.Unit else Vector3.zero
			root.AssemblyLinearVelocity = (direction * tuning.mineKnockbackStuds)
				+ Vector3.new(0, tuning.mineKnockbackUpStuds * 1.4, 0)
			EffectsService.dash(root.Position, direction * 10)
		end
	end

	mine.part:Destroy()
	local _ = now
end

local function updateMines(now: number)
	for index = #mines, 1, -1 do
		local mine = mines[index]
		if mine.part.Parent == nil then
			table.remove(mines, index)
			continue
		end
		if now < mine.armedAt then
			continue
		end

		local tuning = Config.abilities.tuning
		local triggered = false
		for _, victim in enemiesNear(mine.team, mine.part.Position, tuning.mineTriggerRadiusStuds) do
			-- L'Eclaireur du Traqueur ne declenche rien : c'est son palier 6.
			if has(victim.player, "ignoresMines") then
				continue
			end
			triggered = true
			break
		end

		if triggered then
			table.remove(mines, index)
			detonate(mine, now)
		end
	end
end

--------------------------------------------------------------------------------
-- SPECTRE — traverser les murs
--------------------------------------------------------------------------------

local function startPhase(entry: Entry, now: number): boolean
	local seconds = entry.stats.phaseSeconds or 0
	if seconds <= 0 then
		return false
	end

	phaseUntil[entry.player] = now + seconds
	setCharacterGroup(entry.player, GROUP_PHASE)
	setBodyTransparency(
		entry.player,
		if has(entry.player, "phaseInvisible") then 1 else Config.abilities.tuning.phaseTransparency
	)

	local point = pointOf(entry.player)
	if point ~= nil then
		EffectsService.dash(point, Vector3.new(0, 1, 0))
	end
	return true
end

local function endPhase(player: Player)
	phaseUntil[player] = nil
	setBodyTransparency(player, nil)

	local entry = roster[player]
	if entry ~= nil then
		setCharacterGroup(player, GROUP_TEAM[entry.team] or "Default")

		-- Palier 6 : sortir de traversee souffle ce qui est autour. Les degats
		-- sont ceux d'un coup ordinaire, pas davantage : l'interet est la
		-- surprise et le placement, pas la puissance brute.
		if has(player, "phaseExitBurst") then
			local root = rootOf(player)
			if root ~= nil then
				for _, victim in enemiesNear(entry.team, root.Position, 14) do
					local passed = dealTo(victim, Combat.rawDamage(entry.stats))
					local point = pointOf(victim.player)
					if passed > 0 and point ~= nil then
						EffectsService.hit(point, passed, victim.player)
					end
				end
				EffectsService.hit(root.Position + Vector3.new(0, 1.5, 0), 0, nil)
			end
		end
	end
end

function AbilityService.isPhasing(player: Player): boolean
	local untilAt = phaseUntil[player]
	return untilAt ~= nil and os.clock() < untilAt
end

--------------------------------------------------------------------------------
-- LIEN — partager ses PV
--------------------------------------------------------------------------------

local function makeBond(entry: Entry, now: number): boolean
	local root = rootOf(entry.player)
	if root == nil then
		return false
	end

	local candidates = alliesNear(entry, root.Position, entry.stats.bondRangeStuds or 0)
	if #candidates == 0 then
		return false
	end

	-- Le plus proche, et pas un choix : viser un coequipier precis demanderait
	-- une interface de ciblage que la classe n'a pas, et le Lien se joue au
	-- placement de toute facon.
	local best = candidates[1]
	local bestDistance = math.huge
	for _, ally in candidates do
		local allyRoot = rootOf(ally.player)
		if allyRoot == nil then
			continue
		end
		local distance = (allyRoot.Position - root.Position).Magnitude
		if distance < bestDistance then
			best = ally
			bestDistance = distance
		end
	end

	bondTarget[entry.player] = best.player

	local point = pointOf(best.player)
	if point ~= nil then
		EffectsService.heal(point, 0, best.player)
	end

	local _ = now
	return true
end

-- Le Lien prend une part des degats a la place de son allie. Appelee depuis
-- CombatService avant que les degats soient appliques : elle renvoie ce qui
-- reste a encaisser pour l'allie.
function AbilityService.shareDamage(target: Entry, amount: number): number
	if amount <= 0 then
		return amount
	end

	for _, player in order do
		if bondTarget[player] ~= target.player then
			continue
		end

		local link = roster[player]
		if link == nil or not DownedService.isStanding(player) then
			continue
		end

		local shared = Abilities.bondShare(Config, link.stats, amount)
		if shared <= 0 then
			continue
		end

		local passed = dealTo(link, shared)
		local point = pointOf(player)
		if passed > 0 and point ~= nil then
			EffectsService.hit(point, passed, player)
		end

		return Abilities.bondRemainder(amount, shared)
	end

	return amount
end

--------------------------------------------------------------------------------
-- FORGERON — le mur
--------------------------------------------------------------------------------

local function raiseWall(entry: Entry, position: Vector3, facing: Vector3): boolean
	local width = entry.stats.wallWidthStuds or 0
	local height = entry.stats.wallHeightStuds or 0
	local seconds = entry.stats.wallSeconds or 0
	if width <= 0 or height <= 0 or seconds <= 0 then
		return false
	end

	local flat = Vector3.new(facing.X, 0, facing.Z)
	if flat.Magnitude <= 0 then
		return false
	end
	flat = flat.Unit

	local centre = position + (flat * 6)
	local part = Instance.new("Part")
	part.Name = "ArenaWall"
	part.Size = Vector3.new(width, height, Config.abilities.tuning.wallThicknessStuds)
	part.CFrame = CFrame.lookAt(centre + Vector3.new(0, height / 2 - 2.6, 0), centre + flat)
	part.Color = Color3.fromRGB(120, 130, 150)
	part.Material = Enum.Material.Metal
	part.Anchored = true
	part.CanCollide = true
	part.Parent = parentFolder()

	-- Palier 6 : le mur laisse passer son equipe. C'est la seule facon de lever
	-- la faiblesse annoncee de la classe, et elle coute deux points.
	if has(entry.player, "wallSparesAllies") then
		ensureGroups()
		part.CollisionGroup = GROUP_WALL_FRIENDLY[entry.team] or "Default"
	end

	-- Palier 6 : le mur brule qui le touche.
	if has(entry.player, "wallBurns") then
		part.Color = Color3.fromRGB(190, 90, 60)
		table.insert(fires, {
			owner = entry.player,
			part = part,
			until_ = os.clock() + seconds,
			damagePerSecond = Combat.rawDamage(entry.stats) * 0.5,
			radius = math.max(width, height) * 0.6,
			clings = false,
			healsOwner = false,
		})
	end

	Debris:AddItem(part, seconds)
	return true
end

--------------------------------------------------------------------------------
-- PYROMANE — le brasier
--------------------------------------------------------------------------------

local function lightFire(entry: Entry, now: number): boolean
	local radius = entry.stats.fireRadiusStuds or 0
	local seconds = entry.stats.fireSeconds or 0
	if radius <= 0 or seconds <= 0 then
		return false
	end

	local root = rootOf(entry.player)
	if root == nil then
		return false
	end

	local part = Instance.new("Part")
	part.Name = "ArenaFire"
	part.Size = Vector3.new(radius * 2, 0.6, radius * 2)
	part.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.6, 0))
	part.Shape = Enum.PartType.Cylinder
	part.Orientation = Vector3.new(0, 0, 90)
	part.Color = Color3.fromRGB(240, 120, 50)
	part.Material = Enum.Material.Neon
	part.Transparency = 0.45
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = parentFolder()

	table.insert(fires, {
		owner = entry.player,
		part = part,
		until_ = now + seconds,
		damagePerSecond = entry.stats.fireDamagePerSecond or 0,
		radius = radius,
		clings = has(entry.player, "fireClings"),
		healsOwner = has(entry.player, "fireHealsSelf"),
	})

	Debris:AddItem(part, seconds)
	return true
end

local function updateFires(deltaSeconds: number, now: number)
	for index = #fires, 1, -1 do
		local fire = fires[index]
		if now >= fire.until_ or fire.part.Parent == nil then
			table.remove(fires, index)
			continue
		end

		local ownerEntry = roster[fire.owner]
		if ownerEntry == nil then
			continue
		end

		local amount =
			Abilities.fireTickDamage({ fireDamagePerSecond = fire.damagePerSecond }, deltaSeconds)
		if amount <= 0 then
			continue
		end

		local position = fire.part.Position

		for _, victim in enemiesNear(ownerEntry.team, position, fire.radius) do
			dealTo(victim, amount)
			-- Palier 6 : les flammes s'accrochent. Sortir du brasier ne suffit
			-- plus, il faut tenir quelques secondes de plus.
			if fire.clings then
				revealToTeam(ownerEntry, victim.player, 2)
			end
		end

		-- Le Pyromane brule dans ses propres flammes : c'est sa faiblesse, et
		-- elle est appliquee ici, pas decrite ailleurs.
		local ownerRoot = rootOf(fire.owner)
		if
			ownerRoot ~= nil
			and DownedService.isStanding(fire.owner)
			and (ownerRoot.Position - position).Magnitude <= fire.radius
		then
			if fire.healsOwner then
				healPlayer(fire.owner, amount)
			else
				dealTo(ownerEntry, amount)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- LEURRE — le clone
--------------------------------------------------------------------------------

local function spawnClone(entry: Entry, now: number): boolean
	local seconds = entry.stats.cloneSeconds or 0
	if seconds <= 0 then
		return false
	end

	local root = rootOf(entry.player)
	if root == nil then
		return false
	end

	local count = if has(entry.player, "twinClones") then 2 else 1
	local bursts = has(entry.player, "cloneBursts")

	for index = 1, count do
		local offset = if count == 1
			then root.CFrame.LookVector * 5
			else (root.CFrame.RightVector * (if index == 1 then 5 else -5))

		local part = Instance.new("Part")
		part.Name = "ArenaClone"
		part.Size = Vector3.new(2, 5, 1)
		part.CFrame =
			CFrame.new(root.Position + offset, root.Position + offset + root.CFrame.LookVector)
		part.Color = Color3.fromRGB(150, 160, 200)
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = 0.25
		part.Anchored = true
		part.CanCollide = false
		part.Parent = parentFolder()

		table.insert(clones, {
			owner = entry.player,
			team = entry.team,
			part = part,
			health = Config.abilities.tuning.cloneHealth,
			until_ = now + seconds,
			bursts = bursts,
		})

		Debris:AddItem(part, seconds)
	end

	-- Sa faiblesse, les deux moities : il ne bouge plus, et il encaisse
	-- davantage, tant que le clone vit.
	--
	-- Elle est tenue a cote des statistiques, jamais dedans. Modifier
	-- `entry.stats` en place reviendrait a laisser la penalite en vigueur apres
	-- la disparition du clone, puis a l'empiler au leurre suivant : c'est
	-- exactement la facon dont un arbre se cumule tout seul d'une manche a
	-- l'autre, et on ne la refait pas ici.
	local humanoid = humanoidOf(entry.player)
	if humanoid ~= nil then
		slowed[entry.player] = { until_ = now + seconds, baseSpeed = entry.stats.walkSpeed }
		humanoid.WalkSpeed = 0
	end

	local exposure = entry.stats.cloneExposureRatio or 0
	if exposure > 0 then
		exposedUntil[entry.player] = { until_ = now + seconds, ratio = exposure }
	end

	if has(entry.player, "cloneCloaks") then
		setBodyTransparency(entry.player, 1)
	end

	return true
end

-- Ce qui s'ajoute aux degats recus par un joueur, en dehors de ses
-- statistiques. Seul le Leurre s'en sert aujourd'hui, le temps que son clone
-- vive. CombatService l'ajoute a damageTakenRatio au moment du calcul.
function AbilityService.extraDamageTakenRatio(player: Player): number
	local exposure = exposedUntil[player]
	if exposure == nil then
		return 0
	end
	if os.clock() >= exposure.until_ then
		exposedUntil[player] = nil
		return 0
	end
	return exposure.ratio
end

local function removeClone(index: number, clone: Clone)
	table.remove(clones, index)

	if clone.bursts then
		local ownerEntry = roster[clone.owner]
		if ownerEntry ~= nil then
			local position = clone.part.Position
			for _, victim in enemiesNear(clone.team, position, 12) do
				local passed = dealTo(victim, Combat.rawDamage(ownerEntry.stats))
				local point = pointOf(victim.player)
				if passed > 0 and point ~= nil then
					EffectsService.hit(point, passed, victim.player)
				end
			end
			EffectsService.hit(position + Vector3.new(0, 1.5, 0), 0, nil)
		end
	end

	if clone.part.Parent ~= nil then
		clone.part:Destroy()
	end
end

-- Un coup dirige vers le porteur part sur le clone si le clone est plus pres.
-- C'est ce que « attire l'attention » veut dire quand personne ne choisit sa
-- cible a la main : le clone s'interpose.
function AbilityService.absorbAttack(
	attackerPosition: Vector3,
	target: Entry,
	amount: number
): boolean
	local targetRoot = rootOf(target.player)
	if targetRoot == nil then
		return false
	end
	local targetDistance = (targetRoot.Position - attackerPosition).Magnitude

	for index = #clones, 1, -1 do
		local clone = clones[index]
		if clone.owner ~= target.player or clone.part.Parent == nil then
			continue
		end
		if (clone.part.Position - attackerPosition).Magnitude >= targetDistance then
			continue
		end

		clone.health -= amount
		EffectsService.hit(clone.part.Position + Vector3.new(0, 1.5, 0), amount, nil)
		if clone.health <= 0 then
			removeClone(index, clone)
		end
		return true
	end

	return false
end

--------------------------------------------------------------------------------
-- SISMIQUE — l'onde de choc
--------------------------------------------------------------------------------

local function slam(entry: Entry, now: number): boolean
	local radius = entry.stats.slamRadiusStuds or 0
	local seconds = entry.stats.slamSeconds or 0
	if radius <= 0 or seconds <= 0 then
		return false
	end

	local root = rootOf(entry.player)
	if root == nil then
		return false
	end

	EffectsService.hit(root.Position - Vector3.new(0, 2, 0), 0, nil)

	local damages = has(entry.player, "slamDamages")

	for _, victim in enemiesNear(entry.team, root.Position, radius) do
		-- Sa faiblesse : rien n'atteint qui ne touche pas le sol. Sauter au bon
		-- moment annule la frappe entiere, et c'est voulu.
		local humanoid = humanoidOf(victim.player)
		if humanoid == nil or humanoid.FloorMaterial == Enum.Material.Air then
			continue
		end

		revealToTeam(entry, victim.player, seconds)

		local base = victim.stats.walkSpeed
		humanoid.WalkSpeed = Abilities.slowedSpeed(base, entry.stats.slamSlowRatio or 0)
		slowed[victim.player] = { until_ = now + seconds, baseSpeed = base }

		if damages then
			local passed = dealTo(victim, Combat.rawDamage(entry.stats) * 0.5)
			local point = pointOf(victim.player)
			if passed > 0 and point ~= nil then
				EffectsService.hit(point, passed, victim.player)
			end
		end
	end

	return true
end

local function updateSlows(now: number)
	for player, slow in slowed do
		if now < slow.until_ then
			continue
		end
		slowed[player] = nil
		local humanoid = humanoidOf(player)
		if humanoid ~= nil then
			humanoid.WalkSpeed = slow.baseSpeed
		end
	end
end

--------------------------------------------------------------------------------
-- PARASITE — la marque
--------------------------------------------------------------------------------

local function placeMark(entry: Entry, now: number): boolean
	local seconds = entry.stats.markSeconds or 0
	local range = entry.stats.markRangeStuds or 0
	if seconds <= 0 or range <= 0 then
		return false
	end

	local root = rootOf(entry.player)
	if root == nil then
		return false
	end

	local candidates = enemiesNear(entry.team, root.Position, range)
	if #candidates == 0 then
		return false
	end

	local best = candidates[1]
	local bestDistance = math.huge
	for _, victim in candidates do
		local victimRoot = rootOf(victim.player)
		if victimRoot == nil then
			continue
		end
		local distance = (victimRoot.Position - root.Position).Magnitude
		if distance < bestDistance then
			best = victim
			bestDistance = distance
		end
	end

	markedBy[best.player] = { by = entry.player, until_ = now + seconds }
	revealTo(entry.player, best.player, seconds)

	-- Sa faiblesse : le marque le sait. Sans cet avertissement, la marque
	-- serait de l'information gratuite, et la classe n'aurait plus de contre.
	abilityRemote:FireClient(best.player, { kind = "marked", seconds = seconds })

	return true
end

-- Une part des soins recus par le marque revient au Parasite, et le Lien de
-- palier 6 profite des soins de son allie. Appelee depuis CombatService, la ou
-- les soins sont appliques.
function AbilityService.onHealed(player: Player, amount: number)
	if amount <= 0 then
		return
	end

	-- Palier 6 « Communion ». La moitie seulement : un partage integral ferait
	-- de chaque soin un soin double, et deux Liens qui se soignent l'un l'autre
	-- deviendraient impossibles a tuer.
	for linkPlayer, target in bondTarget do
		if target == player and has(linkPlayer, "bondSharesHealing") then
			healPlayer(linkPlayer, amount * 0.5)
			break
		end
	end

	local mark = markedBy[player]
	if mark == nil then
		return
	end

	local parasite = roster[mark.by]
	if parasite == nil or not DownedService.isStanding(mark.by) then
		return
	end

	local stolen = Abilities.healSteal(parasite.stats, amount)
	if stolen <= 0 then
		return
	end

	healPlayer(mark.by, stolen)
	local point = pointOf(mark.by)
	if point ~= nil then
		EffectsService.heal(point, stolen, mark.by)
	end
end

local function updateMarks(now: number)
	for player, mark in markedBy do
		if now >= mark.until_ then
			markedBy[player] = nil
			continue
		end

		-- Palier 6 « Infestation » : la marque saute sur un autre ennemi quand
		-- sa cible tombe. Elle garde la duree qui lui restait : sans ca, tomber
		-- rapidement relancerait une marque pleine a chaque fois.
		if DownedService.isStanding(player) then
			continue
		end
		if not has(mark.by, "markJumps") then
			continue
		end

		local parasite = roster[mark.by]
		local root = rootOf(mark.by)
		if parasite == nil or root == nil then
			continue
		end

		markedBy[player] = nil
		local candidates =
			enemiesNear(parasite.team, root.Position, parasite.stats.markRangeStuds or 0)
		for _, victim in candidates do
			if markedBy[victim.player] == nil then
				markedBy[victim.player] = { by = mark.by, until_ = mark.until_ }
				revealTo(mark.by, victim.player, mark.until_ - now)
				abilityRemote:FireClient(
					victim.player,
					{ kind = "marked", seconds = mark.until_ - now }
				)
				break
			end
		end
	end
end

-- Palier 6 « Symbiose » : le Parasite voit tous les ennemis blesses, marques ou
-- non. Le seuil compte autant que l'effet : voir tout le monde en permanence
-- serait une carte, voir les blesses est une piste.
local function updateWoundedSight(entry: Entry)
	if not has(entry.player, "seesWounded") then
		return
	end

	for _, player in order do
		local other = roster[player]
		if other == nil or other.team == entry.team then
			continue
		end
		local humanoid = humanoidOf(player)
		if humanoid == nil or humanoid.MaxHealth <= 0 then
			continue
		end
		if (humanoid.Health / humanoid.MaxHealth) <= 0.5 then
			revealTo(entry.player, player, 1.5)
		end
	end
end

--------------------------------------------------------------------------------
-- CAMELEON — invisible tant qu'il ne bouge pas
--------------------------------------------------------------------------------

local function updateCloak(entry: Entry, now: number)
	if entry.stats.cloakDelaySeconds == nil then
		return
	end

	local root = rootOf(entry.player)
	if root == nil or not DownedService.isStanding(entry.player) then
		return
	end

	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

	-- Palier 6 : marcher doucement ne le revele plus. On compare alors a sa
	-- vitesse de marche plutot qu'au seuil de la classe.
	local threshold = entry.stats.cloakSpeedThreshold or 0
	if has(entry.player, "stalkWalks") then
		threshold = math.max(threshold, entry.stats.walkSpeed * 0.75)
	end

	local since = stillSince[entry.player]
	if speed > threshold then
		stillSince[entry.player] = nil
		if cloaked[entry.player] then
			cloaked[entry.player] = nil
			setBodyTransparency(entry.player, nil)
		end
		return
	end

	if since == nil then
		stillSince[entry.player] = now
		since = now
	end

	local stillFor = now - since
	local reading = {
		cloakDelaySeconds = entry.stats.cloakDelaySeconds,
		cloakSpeedThreshold = threshold,
	}
	if not cloaked[entry.player] and Abilities.shouldCloak(reading, speed, stillFor) then
		cloaked[entry.player] = true
		ambushReady[entry.player] = true
		setBodyTransparency(entry.player, 1)
	end
end

local function breakCloak(player: Player)
	if not cloaked[player] then
		return
	end
	cloaked[player] = nil
	stillSince[player] = nil
	setBodyTransparency(player, nil)
end

--------------------------------------------------------------------------------
-- CE QUE LE COMBAT VIENT DEMANDER ICI
--------------------------------------------------------------------------------

-- Le multiplicateur applique au coup qui part. Trois choses s'y accumulent :
-- l'isolement du Duelliste, le coup d'embuscade du Cameleon, et le renfort que
-- le Lien donne a son allie.
function AbilityService.outgoingMultiplier(attacker: Entry): number
	local multiplier = 1

	local root = rootOf(attacker.player)
	if root ~= nil and attacker.stats.duelRadiusStuds ~= nil then
		local count = #enemiesNear(attacker.team, root.Position, attacker.stats.duelRadiusStuds)
		-- Palier 6 « Garde » : plus aucune penalite, quel que soit le nombre.
		if count > 1 and has(attacker.player, "guardNoPenalty") then
			count = 1
		end
		multiplier *= Abilities.duelMultiplier(attacker.stats, count)
	end

	-- Palier 6 « Embuscade » : le premier coup apres un camouflage compte
	-- double. Il se consomme, sinon le Cameleon frapperait double tout le temps.
	if ambushReady[attacker.player] and has(attacker.player, "ambushDouble") then
		ambushReady[attacker.player] = nil
		multiplier *= 2
	end

	-- Palier 6 « Attache » : l'allie lie frappe plus fort.
	for linkPlayer, target in bondTarget do
		if target == attacker.player and has(linkPlayer, "bondBoostsAlly") then
			multiplier *= 1.25
			break
		end
	end

	-- Palier 6 « Riposte » : chaque coup encaisse accelere le suivant.
	local stacks = riposteStacks[attacker.player]
	if stacks ~= nil and stacks > 0 and has(attacker.player, "riposteSpeeds") then
		riposteStacks[attacker.player] = 0
		multiplier *= 1 + math.min(stacks * 0.08, 0.4)
	end

	return multiplier
end

-- Le Spectre ne frappe pas pendant qu'il traverse, et le Cameleon se revele en
-- frappant. Les deux se decident au moment ou le coup part.
function AbilityService.canAttack(player: Player): boolean
	if AbilityService.isPhasing(player) then
		return false
	end
	return true
end

function AbilityService.noteAttack(player: Player)
	breakCloak(player)
end

function AbilityService.canBeHealed(player: Player): boolean
	return not AbilityService.isPhasing(player)
end

-- Appelee quand un coup a reellement porte. C'est le point naturel de plusieurs
-- paliers 6, parce que c'est le seul instant ou l'on sait qui a touche qui.
function AbilityService.onHit(attacker: Entry, target: Entry, passed: number)
	if passed <= 0 then
		return
	end

	if has(attacker.player, "hitReveals") then
		revealToTeam(attacker, target.player, 10)
	end

	if has(attacker.player, "hitIgnites") then
		local root = rootOf(target.player)
		if root ~= nil then
			table.insert(fires, {
				owner = attacker.player,
				part = (function(): BasePart
					local part = Instance.new("Part")
					part.Name = "ArenaFireCling"
					part.Size = Vector3.new(6, 0.5, 6)
					part.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.6, 0))
					part.Color = Color3.fromRGB(240, 120, 50)
					part.Material = Enum.Material.Neon
					part.Transparency = 0.6
					part.Anchored = true
					part.CanCollide = false
					part.CanQuery = false
					part.CanTouch = false
					part.Parent = parentFolder()
					Debris:AddItem(part, 3)
					return part
				end)(),
				until_ = os.clock() + 3,
				damagePerSecond = (attacker.stats.fireDamagePerSecond or 0) * 0.5,
				radius = 3,
				clings = false,
				healsOwner = false,
			})
		end
	end

	if has(attacker.player, "phaseRefundOnHit") then
		lastAbilityAt[attacker.player] = nil
	end

	-- Palier 6 « Faille » : le prochain coup declenche une onde. On la declenche
	-- directement sur ce coup-ci, ce qui revient au meme et se lit mieux.
	if has(attacker.player, "slamOnHit") then
		slam(attacker, os.clock())
	end

	local mark = markedBy[target.player]
	if mark ~= nil and mark.by == attacker.player and has(attacker.player, "markLifesteal") then
		healPlayer(attacker.player, passed * 0.4)
	end
end

-- Appelee quand un joueur encaisse, quelle que soit la source.
function AbilityService.onDamaged(target: Entry, amount: number)
	if amount <= 0 then
		return
	end

	breakCloak(target.player)

	if has(target.player, "huskRecloaks") then
		-- La carapace se recamoufle aussitot : on remet le compteur a zero plutot
		-- que d'attendre le delai complet.
		stillSince[target.player] = os.clock() - (target.stats.cloakDelaySeconds or 0)
	end

	riposteStacks[target.player] = (riposteStacks[target.player] or 0) + 1
end

-- Le Socle du Sismique ne bouge plus d'un pouce.
function AbilityService.resistsKnockback(player: Player): boolean
	return has(player, "bedrockNoKnockback")
end

-- Palier 6 « Honneur » : en duel, le coup ignore la resistance adverse. La
-- condition du duel compte autant que l'effet — a deux ennemis ou plus, le
-- Duelliste est deja penalise, et traverser les armures en prime effacerait sa
-- faiblesse au lieu de recompenser sa situation.
function AbilityService.piercesResistance(attacker: Entry): boolean
	if not has(attacker.player, "duelPierces") then
		return false
	end
	local root = rootOf(attacker.player)
	if root == nil or attacker.stats.duelRadiusStuds == nil then
		return false
	end
	return #enemiesNear(attacker.team, root.Position, attacker.stats.duelRadiusStuds) <= 1
end

-- Le Lien de palier 6 protege son allie des degats de zone.
function AbilityService.coversZone(player: Player): boolean
	for linkPlayer, target in bondTarget do
		if target == player and has(linkPlayer, "bondCoversZone") then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- L'INFIRMIER, VU DEPUIS LE RELEVEMENT
--------------------------------------------------------------------------------

local function reviveHooks()
	DownedService.setReviveHooks({
		speedFor = function(player: Player): number
			local entry = roster[player]
			if entry == nil then
				return 1
			end
			return Abilities.reviveSpeed(entry.stats)
		end,
		rangeFor = function(player: Player): number
			local base = Config.downed.reviveRangeStuds
			if has(player, "remoteRevive") then
				return base * 4
			end
			return base
		end,
		healthRatioFor = function(player: Player): number
			local entry = roster[player]
			if entry == nil then
				return Config.downed.reviveHealthRatio
			end
			return Abilities.reviveHealthRatio(Config, entry.stats)
		end,
		uninterruptible = function(player: Player): boolean
			return has(player, "steadyHands")
		end,
	})
end

--------------------------------------------------------------------------------
-- LA TOUCHE, ET CE QU'ELLE DECLENCHE
--------------------------------------------------------------------------------

local function pushHud(player: Player)
	local entry = roster[player]
	if entry == nil then
		return
	end

	local id = abilityOf(entry)
	if id == nil then
		abilityRemote:FireClient(player, { kind = "hud", ability = nil })
		return
	end

	local declared = Config.abilities.registry[id]
	local now = os.clock()

	abilityRemote:FireClient(player, {
		kind = "hud",
		ability = declared.name,
		active = declared.kind == "active",
		left = Abilities.cooldownLeft(entry.stats, now, lastAbilityAt[player]),
		cooldown = Abilities.cooldownOf(entry.stats),
		stock = if id == "mines" then minesLeft[player] else nil,
	})
end

local function useAbility(player: Player)
	if not active then
		return
	end

	local entry = roster[player]
	if entry == nil or not DownedService.isStanding(player) then
		return
	end

	local id = abilityOf(entry)
	if id == nil then
		return
	end

	local declared = Config.abilities.registry[id]
	if declared.kind ~= "active" then
		return
	end

	local now = os.clock()
	if not Abilities.isReady(entry.stats, now, lastAbilityAt[player]) then
		return
	end

	local root = rootOf(player)
	if root == nil then
		return
	end

	local used = false
	if id == "mines" then
		used = placeMine(entry, now)
	elseif id == "phase" then
		used = startPhase(entry, now)
	elseif id == "bond" then
		used = makeBond(entry, now)
	elseif id == "wall" then
		used = raiseWall(entry, root.Position, root.CFrame.LookVector)
	elseif id == "fire" then
		used = lightFire(entry, now)
	elseif id == "clone" then
		used = spawnClone(entry, now)
	elseif id == "slam" then
		used = slam(entry, now)
	elseif id == "mark" then
		used = placeMark(entry, now)
	end

	-- La recharge ne part QUE si le pouvoir a reellement fait quelque chose.
	-- Sinon appuyer sans allie a portee couterait la meme chose qu'un lien
	-- reussi, et le joueur n'aurait aucun moyen de comprendre pourquoi.
	if used then
		lastAbilityAt[player] = now
		breakCloak(player)
		pushHud(player)
	end
end

--------------------------------------------------------------------------------
-- LE BATTEMENT
--------------------------------------------------------------------------------

local hudPushedAt = 0

function AbilityService.step(deltaSeconds: number)
	if not active then
		return
	end

	local now = os.clock()

	for _, player in order do
		local entry = roster[player]
		if entry == nil then
			continue
		end

		local id = abilityOf(entry)
		if id == "footprints" then
			updateFootprints(entry, now)
		elseif id == "cloak" then
			updateCloak(entry, now)
		elseif id == "mark" then
			updateWoundedSight(entry)
		end

		local phaseEnd = phaseUntil[player]
		if phaseEnd ~= nil and now >= phaseEnd then
			endPhase(player)
		end
	end

	-- Palier 6 « Terrain » : les allies proches de l'Infirmier se regenerent.
	for _, player in order do
		local entry = roster[player]
		if entry == nil or not has(player, "fieldRegen") then
			continue
		end
		local root = rootOf(player)
		if root == nil then
			continue
		end
		for _, ally in alliesNear(entry, root.Position, 24) do
			healPlayer(ally.player, 4 * deltaSeconds)
		end
	end

	updateMines(now)
	updateFires(deltaSeconds, now)
	updateSlows(now)
	updateMarks(now)

	for index = #clones, 1, -1 do
		local clone = clones[index]
		if now >= clone.until_ or clone.part.Parent == nil then
			removeClone(index, clone)
			local owner = roster[clone.owner]
			if owner ~= nil and has(clone.owner, "cloneCloaks") then
				setBodyTransparency(clone.owner, nil)
			end
		end
	end

	if (now - hudPushedAt) >= 0.25 then
		hudPushedAt = now
		for _, player in order do
			pushHud(player)
		end
	end
end

--------------------------------------------------------------------------------
-- L'API
--------------------------------------------------------------------------------

-- Palier 6 « Rempart » : un mur se dresse seul quand le Forgeron tombe a terre.
-- Appelee par MatchService, qui est le seul a savoir quand un etat change.
function AbilityService.onDowned(player: Player)
	breakCloak(player)

	local entry = roster[player]
	if entry == nil or not has(player, "wallOnDown") then
		return
	end

	local root = rootOf(player)
	if root == nil then
		return
	end

	-- Dos a l'attaquant plutot que face a lui : le mur sert a couvrir le corps
	-- le temps qu'un coequipier arrive, pas a gagner l'echange qui vient d'etre
	-- perdu.
	raiseWall(entry, root.Position, -root.CFrame.LookVector)
end

function AbilityService.setDamageSink(sink: (Entry, number) -> number)
	damageSink = sink
end

function AbilityService.setHealSink(sink: (Player, number) -> ())
	healSink = sink
end

function AbilityService.setRoster(entries: { Entry })
	roster = {}
	order = {}
	for _, entry in entries do
		roster[entry.player] = entry
		table.insert(order, entry.player)
	end
end

-- Remise a zero complete entre deux manches. Tout ce qu'un pouvoir a pose dans
-- le monde disparait : une mine oubliee d'une manche sur l'autre serait une
-- surprise que personne ne peut anticiper.
function AbilityService.beginRound()
	ensureGroups()

	for _, player in order do
		local entry = roster[player]
		if entry == nil then
			continue
		end
		lastAbilityAt[player] = nil
		minesLeft[player] = math.floor(entry.stats.mineCount or 0)
		rearmed[player] = nil
		bondTarget[player] = nil
		markedBy[player] = nil
		slowed[player] = nil
		cloaked[player] = nil
		stillSince[player] = nil
		ambushReady[player] = nil
		riposteStacks[player] = nil
		exposedUntil[player] = nil
		revealedUntil[player] = nil
		setBodyTransparency(player, nil)
		setCharacterGroup(player, GROUP_TEAM[entry.team] or "Default")
		pushHud(player)
	end
end

function AbilityService.endRound()
	for index = #clones, 1, -1 do
		local clone = clones[index]
		table.remove(clones, index)
		if clone.part.Parent ~= nil then
			clone.part:Destroy()
		end
	end
	mines = {}
	fires = {}

	for player in slowed do
		local humanoid = humanoidOf(player)
		local slow = slowed[player]
		if humanoid ~= nil and slow ~= nil then
			humanoid.WalkSpeed = slow.baseSpeed
		end
	end
	slowed = {}

	for _, player in order do
		phaseUntil[player] = nil
		exposedUntil[player] = nil
		setBodyTransparency(player, nil)
	end

	local existing = folder
	if existing ~= nil then
		existing:ClearAllChildren()
	end
end

function AbilityService.setActive(value: boolean)
	active = value
	if not value then
		AbilityService.endRound()
	end
end

function AbilityService.init()
	ensureGroups()
	reviveHooks()

	-- LE CONTROLE QUI EVITE UNE CLASSE CREUSE. Config dit qu'un pouvoir est
	-- code ; ce fichier dit lesquels il sait faire. Si les deux divergent, on
	-- s'arrete ici plutot que de laisser un joueur tirer une classe qui ne fait
	-- rien. Le message nomme le coupable.
	for abilityId, declared in Config.abilities.registry do
		if declared.implemented and not HANDLED[abilityId] then
			error(
				string.format(
					"[Arena] Le pouvoir « %s » est marqué codé dans Config mais AbilityService "
						.. "ne sait pas l'exécuter. Soit on l'écrit, soit on met implemented = false.",
					abilityId
				)
			)
		end
	end

	-- Le meme controle pour les paliers 6 : deux points depenses pour un effet
	-- que personne n'applique, ca ne se voit pas en jouant.
	for classId, branches in Config.skillTree.branches do
		for _, branch in branches do
			local tier6 = branch.tier6
			if tier6.implemented and not HANDLED_TIER6[tier6.effect] then
				error(
					string.format(
						"[Arena] %s / %s : le palier 6 « %s » est marqué codé dans Config "
							.. "mais aucun service ne l'applique. Soit on l'écrit, soit on met "
							.. "implemented = false.",
						classId,
						branch.id,
						tier6.effect
					)
				)
			end
		end
	end

	abilityRemote.OnServerEvent:Connect(function(player: Player)
		useAbility(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		roster[player] = nil
		lastAbilityAt[player] = nil
		minesLeft[player] = nil
		bondTarget[player] = nil
		markedBy[player] = nil
		slowed[player] = nil
		cloaked[player] = nil
		exposedUntil[player] = nil
		originalTransparency[player] = nil
	end)
end

return AbilityService
