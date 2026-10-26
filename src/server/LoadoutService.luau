--!strict
--[[
	LoadoutService — l'equipement en jeu : ce qu'il change, et ce qu'il pose.

	Le serveur est seul juge. Le client envoie « ajoute cet objet » et « utilise
	l'emplacement 2 », jamais « j'ai 45 PV de plus » ni « j'ai une armure
	lourde » : chaque intention est revalidee ici contre Loadout.validate, qui
	est la meme fonction que celle des tests.

	TROIS CHOSES A SAVOIR AVANT DE LIRE :

	1. L'equipement se modifie ENTRE deux manches, jamais pendant. Il est pris
	   en compte a l'apparition suivante. Sinon on change d'armure en pleine
	   fusillade, et le budget cesse d'etre un choix.

	2. Les statistiques se recalculent en TROIS couches, dans cet ordre :
	       classe nue  ->  arbre de competences  ->  equipement
	   Donc l'armure lourde retire 22 % de la vitesse QUE L'ARBRE A DEJA
	   DONNEE, et le marteau multiplie les degats deja pousses par la branche.
	   C'est voulu, et c'est explique dans Modifiers.applyDeltas.

	3. L'ARME SECONDAIRE sort toute seule quand la cible est hors de portee de
	   la principale. Elle n'a pas de touche, et c'est pour ca que ce service
	   garde DEUX jeux de statistiques par joueur et que CombatService lui
	   demande lequel utiliser au moment du coup.

	Comme AbilityService, ce service ne requiert PAS CombatService : il recoit
	ses fonctions de degats et de soin a l'initialisation. Les deux dans le
	meme sens, et le graphe de dependances reste acyclique.
]]

local LoadoutService = {}

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Config = require(Arena:WaitForChild("Config"))
local Combat = require(Arena:WaitForChild("Combat"))
local Loadout = require(Arena:WaitForChild("Loadout"))
local Modifiers = require(Arena:WaitForChild("Modifiers"))

local Remotes = Arena:WaitForChild("Remotes")
local loadoutRemote = Remotes:WaitForChild("Loadout") :: RemoteEvent

local AbilityService = require(script.Parent:WaitForChild("AbilityService"))
local DownedService = require(script.Parent:WaitForChild("DownedService"))
local EffectsService = require(script.Parent:WaitForChild("EffectsService"))
local WeaponService = require(script.Parent:WaitForChild("WeaponService"))

export type Entry = {
	player: Player,
	team: string,
	classId: string,
	stats: Combat.Stats,
}

type Profile = {
	primary: Combat.Stats,
	secondary: Combat.Stats?,
	primaryPierce: number,
	secondaryPierce: number,

	-- Les objets eux-memes, et pas seulement leurs deltas : c'est ce qui
	-- permet de mettre la bonne arme dans la main. Les chiffres suffisaient
	-- tant que l'equipement etait invisible.
	primaryItem: any,
	secondaryItem: any,
}

type Mine = {
	owner: Player,
	team: string,
	part: BasePart,
	armedAt: number,
	damage: number,
	radius: number,
	knockbackStuds: number,
	knockbackUpStuds: number,
}

type Grenade = {
	owner: Player,
	team: string,
	part: BasePart,
	explodesAt: number,
	damage: number,
	radius: number,
}

type Cast = {
	itemId: string,
	kind: string,
	amount: number,
	endsAt: number,
	interruptedByDamage: boolean,
}

local roster: { [Player]: Entry } = {}
local chosen: { [Player]: { string } } = {}
local charges: { [Player]: { [string]: number } } = {}
local profiles: { [Player]: Profile } = {}
local lastUseAt: { [Player]: number } = {}
local casting: { [Player]: Cast } = {}

local mines: { Mine } = {}
local grenades: { Grenade } = {}

local active = false

local damageSink: ((Entry, number) -> number)? = nil
local healSink: ((Player, number) -> ())? = nil

--------------------------------------------------------------------------------
-- LES OUTILS
--------------------------------------------------------------------------------

local function parentFolder(): Folder
	local existing = Workspace:FindFirstChild("ArenaTemporary")
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "ArenaTemporary"
	folder.Parent = Workspace
	return folder
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function enemiesNear(team: string, position: Vector3, radius: number): { Entry }
	local found: { Entry } = {}
	if radius <= 0 then
		return found
	end
	for _, entry in roster do
		if entry.team == team then
			continue
		end
		if not DownedService.isStanding(entry.player) then
			continue
		end
		local root = rootOf(entry.player)
		if root == nil then
			continue
		end
		if (root.Position - position).Magnitude <= radius then
			table.insert(found, entry)
		end
	end
	return found
end

local function dealTo(entry: Entry, amount: number): number
	local sink = damageSink
	if sink == nil then
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
-- QUI PORTE QUOI
--------------------------------------------------------------------------------

-- La classe du joueur, quand il en a une. L'ecran d'equipement s'ouvre aussi
-- hors partie, donc l'affinite peut etre inconnue : le prix affiche est alors
-- le prix plein, ce qui est la seule reponse honnete.
local function classOf(player: Player): string?
	local entry = roster[player]
	if entry == nil then
		return nil
	end
	return entry.classId
end

--------------------------------------------------------------------------------
-- LA PORTE DU BAC A SABLE
--------------------------------------------------------------------------------

-- UNE SEULE PORTE, ouverte par SandboxService et par rien d'autre. Elle fait
-- deux choses, toutes deux inacceptables en partie : elle releve le budget, et
-- elle rend l'assemblage modifiable PENDANT la manche. Le budget de douze
-- points est le coeur de l'equipement, et changer d'armure en pleine fusillade
-- le viderait de son sens. Mais les deux sont indispensables pour essayer une
-- arme : on veut porter le marteau et le fusil dans la meme minute et basculer
-- de l'un a l'autre sans attendre une fin de manche.
--
-- Elle est nil partout ailleurs, et SandboxService la referme en sortant.
local sandbox: any = nil

-- La configuration que lit la VALIDATION. C'est exactement le motif pour lequel
-- la logique pure recoit sa configuration en argument : on recopie la seule
-- table concernee, on y change les trois chiffres du budget, et `Loadout`
-- valide contre celle-la sans savoir qu'elle a ete fabriquee. Config elle-meme
-- n'est jamais touchee.
local function budgetConfig(): any
	if sandbox == nil then
		return Config
	end
	local loadout = table.clone(Config.loadout)
	loadout.budgetPoints = sandbox.budgetPoints
	loadout.maxItems = sandbox.maxItems
	loadout.maxPerCategory = sandbox.maxPerCategory
	local copy = table.clone(Config)
	copy.loadout = loadout
	return copy
end

function LoadoutService.setSandbox(rules: any)
	sandbox = rules
	LoadoutService.pushAll()
end

--------------------------------------------------------------------------------
-- L'ASSEMBLAGE CHOISI
--------------------------------------------------------------------------------

function LoadoutService.chosenFor(player: Player): { string }
	local list = chosen[player]
	if list == nil then
		-- Un joueur qui n'ouvre jamais l'ecran ne doit pas arriver en manche
		-- avec quatre points sur douze sans comprendre pourquoi il tape comme
		-- une mouche. L'assemblage par defaut est legal et depense le budget.
		list = Loadout.defaultFor(Config, classOf(player))
		chosen[player] = list
	end
	return list
end

-- Pose un assemblage, apres validation. Renvoie faux et ne change rien si
-- l'assemblage est illegal : c'est la seule porte d'entree, donc un client qui
-- raconte n'importe quoi ne peut pas la contourner.
function LoadoutService.setChosen(player: Player, itemIds: { string }): boolean
	if not Loadout.validate(budgetConfig(), itemIds, classOf(player)).ok then
		return false
	end
	chosen[player] = itemIds
	LoadoutService.push(player)
	return true
end

-- Vrai si l'assemblage peut encore se modifier : hors manche uniquement, ou
-- a tout moment dans le bac a sable.
function LoadoutService.isEditable(): boolean
	return sandbox ~= nil or not active
end

--------------------------------------------------------------------------------
-- LES CHARGES
--------------------------------------------------------------------------------

local function refillCharges(player: Player)
	local stock: { [string]: number } = {}
	for _, usable in Loadout.usables(Config, LoadoutService.chosenFor(player)) do
		stock[usable.itemId] = usable.item.use.charges
	end
	charges[player] = stock
	casting[player] = nil
end

function LoadoutService.chargesLeft(player: Player, itemId: string): number
	local stock = charges[player]
	if stock == nil then
		return 0
	end
	return stock[itemId] or 0
end

--------------------------------------------------------------------------------
-- LES STATISTIQUES
--------------------------------------------------------------------------------

-- Recalcule les statistiques de chaque entree, equipement compris. A appeler
-- APRES SkillTreeService.refreshStats : l'equipement est la derniere couche,
-- et c'est ce qui fait que l'armure retire un pourcentage de la vitesse que
-- l'arbre a deja donnee.
function LoadoutService.refreshStats(entries: { Entry })
	for _, entry in entries do
		local items = LoadoutService.chosenFor(entry.player)

		-- La couche permanente : armure, soins, utilitaires. Elle vaut pour les
		-- deux armes, donc elle s'applique avant de les separer.
		local withPassive = Modifiers.applyDeltas(entry.stats, Loadout.passiveDeltas(Config, items))

		local primaryItem = Loadout.weaponOf(Config, items, "primary")
		local secondaryItem = Loadout.weaponOf(Config, items, "secondary")

		local primary =
			Modifiers.applyDeltas(withPassive, Loadout.weaponDeltas(Config, items, "primary"))

		local secondary: Combat.Stats? = nil
		if secondaryItem ~= nil then
			secondary =
				Modifiers.applyDeltas(withPassive, Loadout.weaponDeltas(Config, items, "secondary"))
		end

		profiles[entry.player] = {
			primary = primary,
			secondary = secondary,
			primaryPierce = Loadout.armorPierceOf(Config, items, "primary"),
			secondaryPierce = Loadout.armorPierceOf(Config, items, "secondary"),
			primaryItem = primaryItem,
			secondaryItem = secondaryItem,
		}

		-- L'arme principale passe dans la main des maintenant. La secondaire
		-- n'y viendra qu'au moment ou elle sortira : on porte ce qu'on compte
		-- utiliser, pas tout son budget a la fois.
		WeaponService.show(entry.player, primaryItem)

		-- entry.stats porte l'arme PRINCIPALE : c'est le profil par defaut, et
		-- c'est lui que tout le reste du jeu lit (PV maximum, vitesse,
		-- regeneration). La secondaire ne sort qu'au moment d'un coup trop
		-- lointain.
		entry.stats = primary
	end
end

-- Jusqu'ou chercher une cible : la plus longue des deux portees. Sans ca, une
-- secondaire a longue portee ne trouverait jamais personne, puisque la
-- recherche s'arreterait a la portee de l'arme principale.
function LoadoutService.searchRange(entry: Entry): number
	local profile = profiles[entry.player]
	if profile == nil then
		return entry.stats.attackRangeStuds
	end
	local range = profile.primary.attackRangeStuds
	local secondary = profile.secondary
	if secondary ~= nil then
		range = math.max(range, secondary.attackRangeStuds)
	end
	return range
end

-- Avec quelle arme ce coup part. La principale des que la cible est dedans :
-- elle est toujours la plus chere, donc elle a la priorite. La secondaire
-- seulement pour ce que la principale n'atteint pas.
function LoadoutService.strikeWith(entry: Entry, distance: number?): (Combat.Stats, number)
	local profile = profiles[entry.player]
	if profile == nil then
		return entry.stats, 0
	end

	local secondary = profile.secondary
	if
		distance ~= nil
		and secondary ~= nil
		and distance > profile.primary.attackRangeStuds
		and distance <= secondary.attackRangeStuds
	then
		return secondary, profile.secondaryPierce
	end

	return profile.primary, profile.primaryPierce
end

-- L'objet qui porte ce coup. La meme regle de distance que `strikeWith`,
-- separee parce que les deux ne sont pas appelees au meme moment : l'arme est
-- choisie AVANT la verification de recharge, le geste ne part qu'APRES.
local function weaponAt(entry: Entry, distance: number?): any
	local profile = profiles[entry.player]
	if profile == nil then
		return nil
	end

	local secondary = profile.secondary
	if
		distance ~= nil
		and secondary ~= nil
		and distance > profile.primary.attackRangeStuds
		and distance <= secondary.attackRangeStuds
	then
		return profile.secondaryItem
	end

	return profile.primaryItem
end

-- Le coup est accepte : on montre l'arme qui le porte, on la fait bouger, et
-- on renvoie SA VOIX pour que le client sache quoi jouer. Appele par
-- CombatService apres la recharge, jamais avant — un coup refuse ne doit ni
-- s'animer ni s'entendre, sinon la recharge devient invisible et le joueur
-- croit que ses coups partent dans le vide.
function LoadoutService.swingWeapon(entry: Entry, distance: number?): string?
	local item = weaponAt(entry, distance)
	if item == nil then
		return nil
	end
	WeaponService.show(entry.player, item)
	WeaponService.swing(entry.player, item)
	return item.look and item.look.voice or nil
end

--------------------------------------------------------------------------------
-- LES OBJETS QUI SE POSENT
--------------------------------------------------------------------------------

local function placeMine(entry: Entry, use: any): boolean
	local root = rootOf(entry.player)
	if root == nil then
		return false
	end

	local part = Instance.new("Part")
	part.Name = "LoadoutMine"
	part.Size = Vector3.new(2, 0.35, 2)
	part.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.6, 0))
	part.Shape = Enum.PartType.Cylinder
	part.Orientation = Vector3.new(0, 0, 90)
	part.Color = Color3.fromRGB(190, 200, 120)
	part.Material = Enum.Material.Neon
	part.Transparency = 0.4
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = parentFolder()

	table.insert(mines, {
		owner = entry.player,
		team = entry.team,
		part = part,
		armedAt = os.clock() + use.armSeconds,
		damage = use.damage,
		radius = use.radiusStuds,
		knockbackStuds = use.knockbackStuds or 0,
		knockbackUpStuds = use.knockbackUpStuds or 0,
	})

	Debris:AddItem(part, Config.abilities.tuning.mineLifeSeconds)
	return true
end

local function throwGrenade(entry: Entry, use: any): boolean
	local root = rootOf(entry.player)
	if root == nil then
		return false
	end

	local direction = root.CFrame.LookVector

	local part = Instance.new("Part")
	part.Name = "LoadoutGrenade"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1.2, 1.2, 1.2)
	part.CFrame = CFrame.new(root.Position + (direction * 3) + Vector3.new(0, 1, 0))
	part.Color = Color3.fromRGB(110, 130, 100)
	part.Material = Enum.Material.Metal
	part.Anchored = false
	part.CanCollide = true
	part.Parent = parentFolder()

	-- Une vraie grenade : elle part en cloche et elle rebondit. Une explosion
	-- posee a l'endroit vise serait plus facile a coder et beaucoup moins
	-- interessante a jouer, parce qu'on ne pourrait pas la rater.
	part.AssemblyLinearVelocity = (direction * use.throwStuds) + Vector3.new(0, 22, 0)

	table.insert(grenades, {
		owner = entry.player,
		team = entry.team,
		part = part,
		explodesAt = os.clock() + use.fuseSeconds,
		damage = use.damage,
		radius = use.radiusStuds,
	})

	return true
end

local function deployShield(entry: Entry, use: any): boolean
	local root = rootOf(entry.player)
	if root == nil then
		return false
	end

	local facing = root.CFrame.LookVector
	local flat = Vector3.new(facing.X, 0, facing.Z)
	if flat.Magnitude <= 0 then
		return false
	end
	flat = flat.Unit

	local centre = root.Position + (flat * use.aheadStuds)

	local part = Instance.new("Part")
	part.Name = "LoadoutShield"
	part.Size = Vector3.new(use.widthStuds, use.heightStuds, use.thicknessStuds)
	part.CFrame =
		CFrame.lookAt(centre + Vector3.new(0, use.heightStuds / 2 - 2.6, 0), centre + flat)
	part.Color = Color3.fromRGB(150, 160, 180)
	part.Material = Enum.Material.Metal
	part.Transparency = 0.15
	part.Anchored = true
	part.CanCollide = true
	part.Parent = parentFolder()

	-- Il est marque comme une couverture de map : il bloque les deux equipes,
	-- et le Spectre le traverse pendant sa phase. Une couverture qui ne gene
	-- que l'adversaire ne serait pas une couverture.
	part.CollisionGroup = AbilityService.coverGroup()

	Debris:AddItem(part, use.seconds)
	return true
end

--------------------------------------------------------------------------------
-- UTILISER UN OBJET
--------------------------------------------------------------------------------

local function startCast(player: Player, usable: any)
	local use = usable.item.use
	casting[player] = {
		itemId = usable.itemId,
		kind = use.kind,
		amount = use.amount,
		endsAt = os.clock() + use.castSeconds,
		interruptedByDamage = use.interruptedByDamage == true,
	}
end

-- Renvoie un message en francais quand l'utilisation est refusee, nil quand
-- elle part. Le message remonte au joueur : « plus de charges » se comprend,
-- un echec silencieux fait croire que la touche ne marche pas.
function LoadoutService.use(player: Player, slot: number): string?
	if not active then
		return "La manche n'a pas commence"
	end

	local entry = roster[player]
	if entry == nil then
		return nil
	end

	if not DownedService.isStanding(player) then
		return "À terre"
	end

	local usable = Loadout.usableAt(Config, LoadoutService.chosenFor(player), slot)
	if usable == nil then
		return nil
	end

	if casting[player] ~= nil then
		return "Déjà en cours"
	end

	-- Les charges AVANT la recharge d'utilisation : « plus de charges » est le
	-- message utile, et dans l'autre ordre il etait avale par une demi-seconde
	-- de recharge chaque fois qu'on reappuyait tout de suite — c'est-a-dire
	-- exactement quand on vient de vider sa derniere charge.
	if LoadoutService.chargesLeft(player, usable.itemId) <= 0 then
		return "Plus de charges"
	end

	local now = os.clock()
	local last = lastUseAt[player]
	if last ~= nil and (now - last) < Config.loadout.useCooldownSeconds then
		return nil
	end

	local use = usable.item.use
	local fired = false

	if use.kind == "heal" then
		if use.castSeconds > 0 then
			startCast(player, usable)
			fired = true
		else
			healPlayer(player, use.amount)
			local root = rootOf(player)
			if root ~= nil then
				EffectsService.heal(root.Position + Vector3.new(0, 1.5, 0), use.amount, player)
			end
			fired = true
		end
	elseif use.kind == "mine" then
		fired = placeMine(entry, use)
	elseif use.kind == "grenade" then
		fired = throwGrenade(entry, use)
	elseif use.kind == "shield" then
		fired = deployShield(entry, use)
	end

	if not fired then
		return nil
	end

	local stock = charges[player]
	if stock ~= nil then
		stock[usable.itemId] = math.max((stock[usable.itemId] or 0) - 1, 0)
	end
	lastUseAt[player] = now
	LoadoutService.push(player)
	return nil
end

-- Un coup recu annule une pose en cours. La charge est RENDUE : perdre une
-- trousse de soin sur une balle perdue serait la punition la plus amere du
-- jeu, et la recharge d'utilisation empeche deja d'en abuser.
--
-- C'est le levier d'equilibrage de la categorie. Si se soigner devient trop
-- facile, c'est cette ligne qui change — on garde l'annulation et on retire le
-- remboursement.
function LoadoutService.onDamaged(player: Player)
	local cast = casting[player]
	if cast == nil or not cast.interruptedByDamage then
		return
	end

	casting[player] = nil

	local stock = charges[player]
	if stock ~= nil then
		stock[cast.itemId] = (stock[cast.itemId] or 0) + 1
	end
	LoadoutService.push(player)
end

local function finishCasts(now: number)
	for player, cast in casting do
		if now < cast.endsAt then
			continue
		end
		casting[player] = nil
		if cast.kind == "heal" then
			healPlayer(player, cast.amount)
			local root = rootOf(player)
			if root ~= nil then
				EffectsService.heal(root.Position + Vector3.new(0, 1.5, 0), cast.amount, player)
			end
		end
		LoadoutService.push(player)
	end
end

--------------------------------------------------------------------------------
-- LE BATTEMENT
--------------------------------------------------------------------------------

local function blast(
	position: Vector3,
	team: string,
	damage: number,
	radius: number,
	knockbackStuds: number,
	knockbackUpStuds: number
)
	EffectsService.blast(position + Vector3.new(0, 1.5, 0))

	for _, victim in enemiesNear(team, position, radius) do
		local passed = dealTo(victim, damage)
		local root = rootOf(victim.player)
		if passed > 0 and root ~= nil then
			EffectsService.hit(root.Position + Vector3.new(0, 1.5, 0), passed, victim.player)
		end
		if root ~= nil and knockbackStuds > 0 then
			local away = root.Position - position
			local flat = Vector3.new(away.X, 0, away.Z)
			if flat.Magnitude > 0 then
				root.AssemblyLinearVelocity = (flat.Unit * knockbackStuds)
					+ Vector3.new(0, knockbackUpStuds, 0)
			end
		end
	end
end

local function updateMines(now: number)
	local trigger = Config.abilities.tuning.mineTriggerRadiusStuds
	for index = #mines, 1, -1 do
		local mine = mines[index]
		if mine.part.Parent == nil then
			table.remove(mines, index)
			continue
		end
		if now < mine.armedAt then
			continue
		end
		if #enemiesNear(mine.team, mine.part.Position, trigger) == 0 then
			continue
		end

		table.remove(mines, index)
		local position = mine.part.Position
		mine.part:Destroy()
		blast(
			position,
			mine.team,
			mine.damage,
			mine.radius,
			mine.knockbackStuds,
			mine.knockbackUpStuds
		)
	end
end

local function updateGrenades(now: number)
	for index = #grenades, 1, -1 do
		local grenade = grenades[index]
		if grenade.part.Parent == nil then
			table.remove(grenades, index)
			continue
		end
		if now < grenade.explodesAt then
			continue
		end

		table.remove(grenades, index)
		local position = grenade.part.Position
		grenade.part:Destroy()
		-- La grenade ne blesse que les adversaires, comme les mines de
		-- l'Artificier. Les degats aux allies sont un sujet que la fiche
		-- n'ouvre jamais, et l'ouvrir ici en cachette serait une decision de
		-- conception.
		blast(position, grenade.team, grenade.damage, grenade.radius, 30, 20)
	end
end

function LoadoutService.step(_deltaSeconds: number)
	if not active then
		return
	end
	local now = os.clock()
	updateMines(now)
	updateGrenades(now)
	finishCasts(now)
end

--------------------------------------------------------------------------------
-- CE QUE LE CLIENT VOIT
--------------------------------------------------------------------------------

local function viewFor(player: Player): any
	local classId = classOf(player)
	local items = LoadoutService.chosenFor(player)
	local rules = budgetConfig()
	local check = Loadout.validate(rules, items, classId)

	local catalogue: { any } = {}
	for _, item in Config.items do
		local carried = Loadout.contains(items, item.id)
		local addable = false
		local refusal: string? = nil
		local replaces: string? = nil
		if not carried then
			-- La vue doit dire la verite sur ce qui se passera au clic, donc
			-- elle valide le MEME assemblage candidat que le clic : avec le
			-- remplacement d'une arme ou d'une armure deja portee.
			local candidate = Loadout.withSwap(rules, items, item.id)
			addable, refusal = Loadout.canAdd(rules, candidate, classId, item.id)
			if #candidate < #items then
				local dropped = Loadout.weaponOf(Config, items, item.category)
				replaces = if dropped ~= nil then dropped.name else nil
			end
		end

		table.insert(catalogue, {
			id = item.id,
			name = item.name,
			summary = item.summary,
			category = item.category,
			categoryLabel = Loadout.categoryLabel(Config, item.category),
			cost = Loadout.costOf(Config, item, classId),
			fullCost = item.cost,
			affinity = Loadout.hasAffinity(Config, classId, item.id),
			carried = carried,
			addable = addable,
			refusal = refusal,
			replaces = replaces,
		})
	end

	local slots: { any } = {}
	for _, usable in Loadout.usables(Config, items) do
		-- Hors manche, la reserve n'est pas encore remplie : on affiche ce
		-- qu'on aura. Montrer « 0 / 1 » a quelqu'un qui vient de choisir son
		-- stimulant se lit comme une panne.
		local left = if active
			then LoadoutService.chargesLeft(player, usable.itemId)
			else usable.item.use.charges

		table.insert(slots, {
			slot = usable.slot,
			name = usable.item.name,
			charges = left,
			maxCharges = usable.item.use.charges,
		})
	end

	local cast = casting[player]

	return {
		kind = "loadout",
		budget = rules.loadout.budgetPoints,
		spent = check.spent,
		left = check.left,
		ok = check.ok,
		reason = check.reason,
		editable = LoadoutService.isEditable(),
		maxItems = rules.loadout.maxItems,
		-- Le panneau d'equipement affiche un bandeau quand le budget n'est pas
		-- celui du jeu : un ecran qui annonce soixante points sans dire pourquoi
		-- se lirait comme un bug.
		sandbox = sandbox ~= nil,
		items = catalogue,
		chosen = items,
		slots = slots,
		casting = if cast ~= nil then cast.itemId else nil,
	}
end

function LoadoutService.push(player: Player)
	loadoutRemote:FireClient(player, viewFor(player))
end

function LoadoutService.pushAll()
	for _, player in Players:GetPlayers() do
		LoadoutService.push(player)
	end
end

--------------------------------------------------------------------------------
-- LA BOUCLE DE PARTIE
--------------------------------------------------------------------------------

function LoadoutService.setDamageSink(sink: (Entry, number) -> number)
	damageSink = sink
end

function LoadoutService.setHealSink(sink: (Player, number) -> ())
	healSink = sink
end

function LoadoutService.setRoster(entries: { Entry })
	roster = {}
	for _, entry in entries do
		roster[entry.player] = entry
	end
	-- La classe vient d'etre tiree, donc les affinites changent et un
	-- assemblage choisi pour une autre classe peut etre devenu illegal. On
	-- verifie, et on retombe sur le defaut si c'est le cas.
	for _, entry in entries do
		local items = chosen[entry.player]
		if items ~= nil and not Loadout.validate(budgetConfig(), items, entry.classId).ok then
			chosen[entry.player] = Loadout.defaultFor(Config, entry.classId)
		end
	end
	LoadoutService.pushAll()
end

function LoadoutService.beginRound()
	for _, entry in roster do
		refillCharges(entry.player)
	end
	LoadoutService.pushAll()
end

function LoadoutService.endRound()
	casting = {}
	for index = #mines, 1, -1 do
		mines[index].part:Destroy()
		table.remove(mines, index)
	end
	for index = #grenades, 1, -1 do
		grenades[index].part:Destroy()
		table.remove(grenades, index)
	end
	LoadoutService.pushAll()
end

function LoadoutService.setActive(value: boolean)
	active = value
	LoadoutService.pushAll()
end

--------------------------------------------------------------------------------
-- LES INTENTIONS DU CLIENT
--------------------------------------------------------------------------------

local function onClientEvent(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	-- Utiliser un objet marche PENDANT la manche, modifier l'assemblage
	-- seulement entre deux. Les deux arrivent par le meme message, donc les
	-- deux portes se verifient separement.
	if typeof(payload.use) == "number" then
		LoadoutService.use(player, payload.use)
		return
	end

	if not LoadoutService.isEditable() then
		return
	end

	local classId = classOf(player)
	local items = LoadoutService.chosenFor(player)

	if payload.reset == true then
		LoadoutService.setChosen(player, Loadout.defaultFor(Config, classId))
	elseif typeof(payload.add) == "string" then
		local rules = budgetConfig()
		local candidate = Loadout.withSwap(rules, items, payload.add)
		LoadoutService.setChosen(player, Loadout.add(rules, candidate, classId, payload.add))
	elseif typeof(payload.remove) == "string" then
		LoadoutService.setChosen(player, Loadout.remove(items, payload.remove))
	else
		-- Une simple demande d'etat frais, a l'ouverture de l'ecran.
		LoadoutService.push(player)
	end
end

function LoadoutService.init()
	WeaponService.init()

	loadoutRemote.OnServerEvent:Connect(onClientEvent)

	Players.PlayerRemoving:Connect(function(player)
		chosen[player] = nil
		charges[player] = nil
		profiles[player] = nil
		casting[player] = nil
		lastUseAt[player] = nil
		roster[player] = nil
	end)

	-- Un garde-fou dans le meme esprit que celui des pouvoirs : si un objet
	-- declare une sorte d'utilisation que ce service ne sait pas executer, il
	-- coute des points et ne fait rien. Le serveur refuse de demarrer, et le
	-- message nomme le coupable.
	local handled = { heal = true, mine = true, grenade = true, shield = true }
	for _, item in Config.items do
		local use = item.use
		if use ~= nil and not handled[use.kind] then
			error(
				string.format(
					"[Arena] L'objet « %s » utilise « %s », que LoadoutService ne sait pas executer.",
					item.name,
					tostring(use.kind)
				)
			)
		end
	end
end

return LoadoutService
