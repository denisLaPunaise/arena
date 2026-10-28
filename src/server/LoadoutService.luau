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
local Status = require(Arena:WaitForChild("Status"))

local Remotes = Arena:WaitForChild("Remotes")
local loadoutRemote = Remotes:WaitForChild("Loadout") :: RemoteEvent

local AbilityService = require(script.Parent:WaitForChild("AbilityService"))
local DownedService = require(script.Parent:WaitForChild("DownedService"))
local EffectsService = require(script.Parent:WaitForChild("EffectsService"))
local StatusService = require(script.Parent:WaitForChild("StatusService"))
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
	-- L'effet que l'explosion colle, quand elle en colle un. C'est ce qui
	-- distingue la grenade aveuglante : elle ne retire pas un PV.
	status: any,
}

-- UNE ZONE POSEE AU SOL. Six objets du catalogue en posent une, et ils ne
-- different que par `effect` : fumee, revelation, ralentissement, feu, soin,
-- brouillage. Six types separes auraient donne six boucles de mise a jour qui
-- auraient diverge a la premiere correction.
type Zone = {
	owner: Player,
	team: string,
	part: BasePart,
	until_: number,
	effect: string,
	radius: number,
	magnitude: number,
	holdSeconds: number,
	hurtsOwner: boolean,
}

type Cast = {
	itemId: string,
	kind: string,
	use: any,
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
local zones: { Zone } = {}

-- COMBIEN DE COUPS IL RESTE A CETTE ARME, pour la manche. Quatre armes du
-- catalogue ont un chargeur — le fusil de chasse, le revolver lourd, le
-- revolver court, le pistolet de poche — et c'est le seul etat d'arme qui ne
-- vit pas dans les statistiques. Il se remplit avec les charges des
-- consommables, au meme moment et pour la meme raison : une manche commence
-- toujours au complet.
local shotsLeft: { [Player]: { [string]: number } } = {}

local active = false

local damageSink: ((Entry, number, string?) -> number)? = nil
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

local function dealTo(entry: Entry, amount: number, kind: string?): number
	local sink = damageSink
	if sink == nil then
		return 0
	end
	return sink(entry, amount, kind)
end

-- Les allies debout a portee, celui qui pose compris quand on le demande. Le
-- pendant exact d'`enemiesNear`, parce que trois objets soignent plutot que de
-- blesser : la transfusion, le dome de soin, et le feu qui brule les deux
-- equipes.
local function alliesNear(
	team: string,
	position: Vector3,
	radius: number,
	except: Player?
): { Entry }
	local found: { Entry } = {}
	if radius <= 0 then
		return found
	end
	for _, entry in roster do
		if entry.team ~= team or entry.player == except then
			continue
		end
		if not DownedService.isStanding(entry.player) then
			continue
		end
		local root = rootOf(entry.player)
		if root ~= nil and (root.Position - position).Magnitude <= radius then
			table.insert(found, entry)
		end
	end
	return found
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

	-- LES CHARGEURS SE REMPLISSENT AU MEME MOMENT QUE LES CHARGES, et c'est le
	-- meme raisonnement : une manche commence toujours au complet, sinon la
	-- premiere manche et la quatrieme ne se jouent pas avec la meme arme.
	local magazines: { [string]: number } = {}
	for _, itemId in LoadoutService.chosenFor(player) do
		local item = Loadout.find(Config, itemId)
		if item ~= nil and item.shotsPerRound ~= nil then
			magazines[itemId] = item.shotsPerRound
		end
	end
	shotsLeft[player] = magazines
end

-- Combien de coups il reste a cette arme. `math.huge` pour une arme sans
-- chargeur : c'est la reponse juste, et elle evite un cas particulier a chaque
-- appel.
function LoadoutService.shotsFor(player: Player, item: any): number
	if item == nil or item.shotsPerRound == nil then
		return math.huge
	end
	local magazines = shotsLeft[player]
	if magazines == nil then
		return 0
	end
	return magazines[item.id] or 0
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

		-- L'armure se porte, elle ne se sort pas : elle est visible tant
		-- qu'elle est equipee. C'est la meme raison que pour l'arme — l'adver-
		-- saire doit pouvoir lire le budget sur le corps.
		WeaponService.wear(entry.player, Loadout.wornOf(Config, items))

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

-- CETTE ARME PEUT-ELLE TIRER MAINTENANT. Trois raisons de dire non, et les
-- trois sont arrivees avec le catalogue complet :
--
--   - la cible est trop LOIN. C'etait la seule regle jusqu'ici ;
--   - la cible est trop PRES. Le fusil de precision ne tire pas en dessous de
--     dix-huit studs, et c'est tout ce qui justifie ses sept points ;
--   - le CHARGEUR est vide. Quatre armes n'ont qu'un nombre de coups par
--     manche.
--
-- Quand la principale dit non, la secondaire sort. C'etait deja le cas pour la
-- distance ; c'est maintenant vrai pour les trois, et c'est ce qui fait du
-- couple « fusil de precision plus fusil a canon scie » un assemblage qui se
-- tient.
local function weaponFires(
	player: Player,
	item: any,
	stats: Combat.Stats,
	distance: number?
): boolean
	if LoadoutService.shotsFor(player, item) <= 0 then
		return false
	end
	if distance == nil then
		return true
	end
	if distance > stats.attackRangeStuds then
		return false
	end
	local minimum = if item ~= nil then item.minRangeStuds else nil
	if minimum ~= nil and distance < minimum then
		return false
	end
	return true
end

-- Laquelle des deux armes porte ce coup. UN SEUL ENDROIT : la regle etait
-- ecrite deux fois, une pour les chiffres et une pour l'objet, et trois regles
-- qui se croisent en double exemplaire n'auraient pas tenu une correction.
local function chooseWeapon(entry: Entry, distance: number?): (Combat.Stats, number, any)
	local profile = profiles[entry.player]
	if profile == nil then
		return entry.stats, 0, nil
	end

	if weaponFires(entry.player, profile.primaryItem, profile.primary, distance) then
		return profile.primary, profile.primaryPierce, profile.primaryItem
	end

	local secondary = profile.secondary
	if
		secondary ~= nil and weaponFires(entry.player, profile.secondaryItem, secondary, distance)
	then
		return secondary, profile.secondaryPierce, profile.secondaryItem
	end

	-- Aucune des deux ne peut tirer : on rend quand meme la principale. Le coup
	-- partira dans le vide, ce qui est exactement ce qu'on veut voir — un
	-- chargeur vide doit se sentir, pas disparaitre.
	return profile.primary, profile.primaryPierce, profile.primaryItem
end

function LoadoutService.strikeWith(entry: Entry, distance: number?): (Combat.Stats, number)
	local stats, pierce = chooseWeapon(entry, distance)
	return stats, pierce
end

-- L'objet qui porte ce coup, pour ce que les statistiques ne disent pas :
-- l'effet colle a la cible, l'explosion du lance-grenades, le ralentissement
-- que la mitrailleuse s'inflige.
function LoadoutService.weaponFor(entry: Entry, distance: number?): any
	local _, _, item = chooseWeapon(entry, distance)
	return item
end

local function weaponAt(entry: Entry, distance: number?): any
	return LoadoutService.weaponFor(entry, distance)
end

-- L'exosquelette ne se fait plus repousser. La reponse vit ici parce que c'est
-- l'equipement qui la porte ; celle des pouvoirs est dans AbilityService, et
-- CombatService demande aux deux.
function LoadoutService.resistsKnockback(player: Player): boolean
	for _, itemId in LoadoutService.chosenFor(player) do
		local item = Loadout.find(Config, itemId)
		if item ~= nil and item.resistsKnockback == true then
			return true
		end
	end
	return false
end

-- Le coup est accepte : on montre l'arme qui le porte, on la fait bouger, et
-- on renvoie SA VOIX pour que le client sache quoi jouer. Appele par
-- CombatService apres la recharge, jamais avant — un coup refuse ne doit ni
-- s'animer ni s'entendre, sinon la recharge devient invisible et le joueur
-- croit que ses coups partent dans le vide.
function LoadoutService.swingWeapon(entry: Entry, distance: number?): string?
	local item = weaponAt(entry, distance)

	-- LA BALLE SE CONSOMME ICI, et nulle part ailleurs. C'est le seul point du
	-- code ou un coup est a la fois accepte et compte une seule fois :
	-- `strikeWith` est appelee avant la recharge et parfois deux fois, `onAttack`
	-- ne sait pas quelle arme a servi.
	if item ~= nil and item.shotsPerRound ~= nil then
		local magazines = shotsLeft[entry.player]
		if magazines ~= nil and (magazines[item.id] or 0) > 0 then
			magazines[item.id] -= 1
			LoadoutService.push(entry.player)
		end
	end

	-- La mitrailleuse se cloue sur place le temps de sa rafale. Ce n'est PAS un
	-- etourdissement : le plancher de vitesse s'applique, donc elle laisse
	-- toujours de quoi se decaler d'un pas. L'immobilisation complete existe,
	-- elle s'appelle grenade aveuglante et elle se paie trois points.
	if item ~= nil and item.selfSlowSeconds ~= nil then
		StatusService.apply(entry.player, Status.SLOW, item.selfSlowSeconds, 0)
	end

	if item == nil then
		-- Sans arme, le bras part quand meme : un coup de poing qui ne se voit
		-- pas est un coup qu'on croit avoir rate.
		WeaponService.swing(entry.player, nil)
		return nil
	end
	WeaponService.show(entry.player, item)
	WeaponService.swing(entry.player, item)
	return item.look and item.look.voice or nil
end

--------------------------------------------------------------------------------
-- LES OBJETS QUI SE POSENT
--------------------------------------------------------------------------------

-- CE QUI EXPLOSE, pour les mines, les grenades et la hachette de lancer. Une
-- seule formule : les trois posent la meme question — qui est dans le rayon, et
-- de combien il recule.
local function blast(
	position: Vector3,
	team: string,
	damage: number,
	radius: number,
	knockbackStuds: number,
	knockbackUpStuds: number,
	status: any
)
	EffectsService.blast(position + Vector3.new(0, 1.5, 0))

	for _, victim in enemiesNear(team, position, radius) do
		-- UNE EXPLOSION EST UNE SORTE DE DEGAT, et c'est ce qui donne un sens au
		-- gilet pare-eclats : sans ce troisieme argument, l'armure qui resiste
		-- aux explosions ne resisterait a rien.
		local passed = dealTo(victim, damage, Combat.BLAST)
		if status ~= nil then
			StatusService.apply(victim.player, status.kind, status.seconds, status.magnitude or 0)
		end
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
		status = use.status,
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

-- LES SIX ZONES EN UNE SEULE FONCTION. Ce qui change d'un objet a l'autre est
-- la couleur, la hauteur et la transparence ; ce qui ne change pas est qu'une
-- zone est une part posee au sol, qui ne gene aucun deplacement et qui s'efface
-- toute seule.
--
-- La fumee est la seule qui soit PLEINE : c'est tout son effet, et elle marche
-- parce que le moteur ne dessine pas a travers. Les cinq autres sont des
-- galettes au sol, parce qu'un cylindre opaque de soin cacherait le combat
-- qu'il est cense soutenir.
local ZONE_LOOKS: { [string]: { color: Color3, height: number, transparency: number } } = {
	smoke = { color = Color3.fromRGB(196, 198, 202), height = 16, transparency = 0.12 },
	reveal = { color = Color3.fromRGB(240, 206, 110), height = 0.5, transparency = 0.6 },
	slow = { color = Color3.fromRGB(150, 140, 120), height = 0.4, transparency = 0.45 },
	burn = { color = Color3.fromRGB(240, 120, 50), height = 0.6, transparency = 0.45 },
	heal = { color = Color3.fromRGB(120, 220, 150), height = 0.5, transparency = 0.6 },
	jam = { color = Color3.fromRGB(120, 150, 200), height = 0.5, transparency = 0.6 },
}

-- Les sortes de zone qui posent un effet temporaire sur quelqu'un, et qui
-- doivent donc dire combien de temps il tient apres qu'on en soit sorti. Le feu
-- n'y est pas : il fait mal au passage, il ne colle rien.
local HOLDING_ZONES = { slow = true, heal = true }

local function placeZone(entry: Entry, use: any): boolean
	local root = rootOf(entry.player)
	if root == nil then
		return false
	end

	local look = ZONE_LOOKS[use.effect]
	if look == nil then
		-- Une sorte de zone inconnue ne pose rien plutot que de poser une part
		-- invisible qui ne ferait rien : le demarrage du serveur refuse deja
		-- cet objet, et ceci est la deuxieme barriere.
		return false
	end

	local radius = use.radiusStuds
	local part = Instance.new("Part")
	part.Name = "ArenaZone"
	part.Size = Vector3.new(radius * 2, look.height, radius * 2)
	part.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.6 - look.height / 2, 0))
	part.Shape = Enum.PartType.Cylinder
	part.Orientation = Vector3.new(0, 0, 90)
	part.Color = look.color
	part.Material = if use.effect == "smoke"
		then Enum.Material.SmoothPlastic
		else Enum.Material.Neon
	part.Transparency = look.transparency
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = parentFolder()

	local seconds = use.seconds
	table.insert(zones, {
		owner = entry.player,
		team = entry.team,
		part = part,
		until_ = os.clock() + seconds,
		effect = use.effect,
		radius = radius,
		magnitude = use.magnitude or 0,
		holdSeconds = use.holdSeconds or 1,
		hurtsOwner = use.hurtsOwner == true,
	})

	-- Le brouilleur agit a la pose, pas au battement : il efface ce qui etait
	-- deja revele. Attendre le battement suivant le ferait passer pour casse.
	if use.effect == "jam" then
		AbilityService.addJammer(part.Position, radius, entry.team, seconds)
	end

	Debris:AddItem(part, seconds)
	return true
end

-- Le grappin et les bottes a ressort. Un seul code, parce que la difference
-- entre « ca monte » et « ca avance » tient dans deux chiffres de Config et pas
-- dans deux mecaniques.
-- UN CHIFFRE NOMME EN STUDS DOIT DONNER DES STUDS, et c'est cette conversion
-- qui le rend vrai. Elle vit ici, a un seul endroit, comme le signe du tangage
-- du buste vit a un seul endroit dans WeaponService.
--
-- Vu en jeu le 27 octobre 2026, et seule une mesure pouvait le montrer :
-- `upStuds = 40` donnait QUATRE STUDS de hauteur. Les bottes a ressort
-- sautaient donc moins haut qu'un saut ordinaire, qui monte a 7,2. Le chiffre
-- partait directement dans la vitesse, et une vitesse de 40 studs par seconde
-- contre une gravite de 196 monte a 40 au carre sur deux fois 196, soit 4,07 —
-- exactement ce qui a ete mesure. C'est la meme panne que les angles nommes
-- par leur axe au lieu de leur effet.
local function leapVelocity(use: any): (Vector3, number, number)
	local gravity = math.max(Workspace.Gravity, 1)

	-- Hauteur voulue -> vitesse de depart : v = racine(2 g h).
	local height = math.max(use.upStuds or 0, 0)
	local upward = math.sqrt(2 * gravity * height)

	if upward <= 0 then
		return Vector3.zero, 0, 0
	end

	-- Temps de vol : monter puis redescendre a la meme hauteur. C'est lui qui
	-- transforme une distance horizontale en vitesse horizontale, et c'est
	-- pour ca que les deux chiffres d'un bond ne sont PAS independants : un
	-- bond plus bas est aussi un bond plus court a vitesse egale.
	local airtime = (2 * upward) / gravity
	return Vector3.new(0, upward, 0), airtime, math.max(use.forwardStuds or 0, 0)
end

-- CE QUI TIENT L'HORIZONTALE PENDANT LE VOL, et pourquoi il faut quelque chose.
--
-- Poser la vitesse horizontale une fois ne marche PAS, et ce n'est pas une
-- question de reglage. L'Humanoid de Roblox pousse en permanence la vitesse du
-- personnage vers celle que le joueur demande au clavier — zero quand personne
-- n'appuie — et il gagne, lentement pour une vitesse rapide et tout de suite
-- pour une vitesse lente que la marche. Mesures du 27 octobre 2026, 38 studs
-- demandes avec un simple coup de vitesse :
--
--   rattrapage 1,37  ->  22,8 studs parcourus
--   rattrapage 2,44  ->  67,8 studs parcourus
--
-- Pas le double pour le double : la relation n'est pas lineaire, donc AUCUN
-- facteur unique ne peut faire d'une vitesse une distance. Chercher le bon
-- chiffre etait le mauvais chantier.
--
-- Un `LinearVelocity` en mode Plan, lui, est resolu par le moteur physique et
-- pas par l'animateur : il TIENT la vitesse horizontale pendant tout le vol, et
-- laisse l'axe vertical libre pour la gravite. La distance parcourue redevient
-- alors vitesse fois duree, donc un chiffre nomme en studs donne des studs.
--
-- Le prix assume : on ne se dirige plus pendant un bond. C'est meme ce que le
-- commentaire d'a cote demandait deja — un deplacement qui ne fait pas deux
-- fois la meme chose ne s'apprend pas.
local movers: { [Player]: { attachment: Attachment, mover: LinearVelocity } } = {}

-- L'attache ET la contrainte s'en vont ensemble, ici et nulle part ailleurs.
-- Une contrainte posee sur un personnage qui survit a ce qu'elle tient est
-- exactement le piege des quatre `ArenaGrip` dans la meme main.
local function clearMover(player: Player)
	local held = movers[player]
	if held == nil then
		return
	end
	movers[player] = nil
	held.mover:Destroy()
	held.attachment:Destroy()
end

local function holdForward(
	player: Player,
	root: BasePart,
	direction: Vector3,
	speed: number,
	seconds: number
)
	clearMover(player)

	-- DEUX NOMS DIFFERENTS, et ce n'est pas de la coquetterie. Les deux objets
	-- vivent sous la meme part : en les appelant tous les deux « ArenaLeap »,
	-- un `FindFirstChild` en designe un au hasard — exactement le piege des
	-- doublons de Rojo et des quatre `ArenaGrip` dans la meme main. La sonde
	-- qui cherchait la contrainte a lu l'attache et a conclu que la vitesse
	-- demandee valait zero.
	local attachment = Instance.new("Attachment")
	attachment.Name = "ArenaLeapAnchor"
	attachment.Parent = root

	local mover = Instance.new("LinearVelocity")
	mover.Name = "ArenaLeapMover"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World

	-- UNE LIGNE, PAS UN PLAN, et surtout SANS PLAFOND DE FORCE.
	--
	-- Le mode Ligne ne contraint que la composante le long de la direction
	-- donnee : la verticale reste de la gravite pure, et c'est ce qui garde la
	-- hauteur juste. Le mode Plan ferait la meme chose, en demandant deux axes
	-- au lieu d'un.
	--
	-- `ForceLimitsEnabled` vaut VRAI par defaut, avec `MaxForce` a 1000, et
	-- c'est ce qui a coute la premiere version : 1000 ne suffit pas a lancer un
	-- personnage, donc la contrainte epinglait la vitesse horizontale a presque
	-- zero au lieu de la pousser. Les bottes a ressort faisaient 1,8 stud au
	-- lieu de 38, et aucune erreur ne le disait. Verifie le 27 octobre 2026 en
	-- relisant la propriete : elle etait bien a 66,6, c'etait la force qui
	-- manquait.
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	mover.LineDirection = direction
	mover.LineVelocity = speed
	mover.ForceLimitsEnabled = false
	mover.Parent = root

	movers[player] = { attachment = attachment, mover = mover }

	task.delay(seconds, function()
		local held = movers[player]
		if held ~= nil and held.mover == mover then
			clearMover(player)
		end
	end)
end

local function leap(entry: Entry, use: any): boolean
	local root = rootOf(entry.player)
	if root == nil then
		return false
	end

	local upward, airtime, reach = leapVelocity(use)
	if upward.Magnitude <= 0 then
		return false
	end

	-- On ECRASE la vitesse au lieu de l'ajouter : un bond qui s'additionne a
	-- une chute donne une trajectoire differente selon qu'on saute ou pas, et
	-- un deplacement qui ne fait pas deux fois la meme chose ne s'apprend pas.
	root.AssemblyLinearVelocity = upward

	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	-- Un personnage qui regarde droit en haut n'a pas d'avant : sans ce test,
	-- `.Unit` rendrait un vecteur de NaN et le personnage disparaitrait de la
	-- carte. Il monte alors sur place, ce qui est la reponse la moins
	-- surprenante.
	if reach > 0 and flat.Magnitude > 1e-3 then
		holdForward(entry.player, root, flat.Unit, reach / airtime, airtime)
	end
	return true
end

-- La hachette de lancer : un coup porte a distance, tout de suite. Elle ne vole
-- pas — RIEN NE VOLE DANS CE JEU, c'est une decision de conception qui tient
-- depuis le debut — donc elle touche a l'instant ou on la lance, comme l'arc et
-- comme les armes a feu, et le trait dessine dit au joueur ou elle est allee.
local function throwAt(entry: Entry, use: any): boolean
	local root = rootOf(entry.player)
	if root == nil then
		return false
	end

	local origin = root.Position
	local reach = use.rangeStuds

	-- La cible est le premier ennemi debout dans le cone de tir, le plus proche
	-- d'abord. C'est la meme idee que `findTarget` de CombatService, en plus
	-- simple : un objet a deux charges n'a pas besoin de viser aussi bien
	-- qu'une arme.
	local best: Entry? = nil
	local bestDistance = math.huge
	for _, victim in enemiesNear(entry.team, origin, reach) do
		local victimRoot = rootOf(victim.player)
		if victimRoot == nil then
			continue
		end
		local toward = victimRoot.Position - origin
		local distance = toward.Magnitude
		if toward.Unit:Dot(root.CFrame.LookVector) < 0.35 then
			continue
		end
		if distance < bestDistance then
			best = victim
			bestDistance = distance
		end
	end

	local landing = origin + root.CFrame.LookVector * reach
	local target = best
	if target ~= nil then
		local victimRoot = rootOf(target.player)
		if victimRoot ~= nil then
			landing = victimRoot.Position
		end
	end

	EffectsService.swing(origin + Vector3.new(0, 1.5, 0), landing - origin, target ~= nil, "blade")

	if target == nil then
		return true
	end

	blast(landing, entry.team, use.damage, use.radiusStuds, 0, 0)
	return true
end

-- UN SOIN, et ses deux variantes. Les trois chemins passent par ici — pose
-- instantanee, fin de pose, et le soin etale — pour que le nombre monte au meme
-- endroit : un soin qui se voit a un endroit et pas a l'autre se lit comme une
-- panne.
--
-- `overSeconds` en fait une regeneration plutot qu'un soin : la fiole rend
-- quarante-huit PV sur douze secondes, et AUCUN coup ne l'arrete. C'est tout ce
-- qu'elle a pour elle, et c'est ce qui la rend differente de la trousse au meme
-- prix.
local function applyHeal(player: Player, use: any)
	local root = rootOf(player)

	if use.overSeconds ~= nil and use.overSeconds > 0 then
		StatusService.apply(player, Status.REGEN, use.overSeconds, use.amount / use.overSeconds)
	else
		healPlayer(player, use.amount)
		if root ~= nil then
			EffectsService.heal(root.Position + Vector3.new(0, 1.5, 0), use.amount, player, "heal")
		end
	end

	-- La transfusion soigne aussi autour d'elle. L'allie recoit tout de suite,
	-- meme quand le porteur se regenere : le partage est le service rendu, et
	-- l'etaler le rendrait invisible.
	local allyAmount = use.allyAmount
	if allyAmount == nil or allyAmount <= 0 or root == nil then
		return
	end
	local entry = roster[player]
	if entry == nil then
		return
	end
	for _, ally in alliesNear(entry.team, root.Position, use.allyRadiusStuds or 0, player) do
		healPlayer(ally.player, allyAmount)
		local allyRoot = rootOf(ally.player)
		if allyRoot ~= nil then
			EffectsService.heal(
				allyRoot.Position + Vector3.new(0, 1.5, 0),
				allyAmount,
				ally.player,
				"heal"
			)
		end
	end
end

local function startCast(player: Player, usable: any)
	local use = usable.item.use
	casting[player] = {
		itemId = usable.itemId,
		kind = use.kind,
		-- L'objet entier et pas seulement son nombre de PV : la transfusion a
		-- une pose ET un allie a soigner, donc la fin de pose a besoin de tout
		-- ce que l'objet dit.
		use = use,
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
			applyHeal(player, use)
			fired = true
		end
	elseif use.kind == "mine" then
		fired = placeMine(entry, use)
	elseif use.kind == "grenade" then
		fired = throwGrenade(entry, use)
	elseif use.kind == "shield" then
		fired = deployShield(entry, use)
	elseif use.kind == "zone" then
		fired = placeZone(entry, use)
	elseif use.kind == "leap" then
		fired = leap(entry, use)
	elseif use.kind == "throw" then
		fired = throwAt(entry, use)
	end

	if not fired then
		return nil
	end

	-- L'objet sort dans la main gauche pendant qu'on s'en sert. La duree est
	-- celle de la pose quand il y en a une : une trousse de soin reste en main
	-- le temps de ses 1,6 seconde, une grenade part tout de suite.
	WeaponService.flashOffhand(player, usable.item, use.castSeconds or 0)

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
			applyHeal(player, cast.use)
		end
		LoadoutService.push(player)
	end
end

--------------------------------------------------------------------------------
-- LE BATTEMENT
--------------------------------------------------------------------------------

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
		blast(position, grenade.team, grenade.damage, grenade.radius, 30, 20, grenade.status)
	end
end

-- LE BATTEMENT DES ZONES. Quatre des six font quelque chose a chaque passage ;
-- la fumee ne fait rien du tout — elle EST son effet, puisqu'on ne voit pas a
-- travers — et le brouilleur a tout fait a la pose.
--
-- POURQUOI LES DUREES SONT COURTES ET PAS LES RAYONS. Un effet colle par une
-- zone dure `holdSeconds` apres qu'on en soit sorti, et pas une seconde de
-- plus : c'est ce qui fait qu'en sortir SERT. Une zone qui collerait son effet
-- pour dix secondes serait une grenade avec un rayon, et on ne saurait plus
-- pourquoi on est lent.
local function updateZones(now: number, deltaSeconds: number)
	for index = #zones, 1, -1 do
		local zone = zones[index]
		if now >= zone.until_ or zone.part.Parent == nil then
			table.remove(zones, index)
			continue
		end

		local position = zone.part.Position
		local effect = zone.effect

		if effect == "slow" then
			for _, victim in enemiesNear(zone.team, position, zone.radius) do
				StatusService.apply(victim.player, Status.SLOW, zone.holdSeconds, zone.magnitude)
			end
		elseif effect == "reveal" then
			-- Deux secondes et pas la duree de la zone : celui qui sort de la
			-- balise redevient invisible presque tout de suite, donc la balise
			-- dit « il est passe la », pas « je le suis partout ».
			for _, victim in enemiesNear(zone.team, position, zone.radius) do
				AbilityService.revealForTeam(zone.team, victim.player, 2)
			end
		elseif effect == "burn" then
			local amount = zone.magnitude * deltaSeconds
			if amount > 0 then
				for _, victim in enemiesNear(zone.team, position, zone.radius) do
					local passed = dealTo(victim, amount, Combat.DOT)
					local root = rootOf(victim.player)
					if passed > 0 and root ~= nil then
						EffectsService.hit(
							root.Position + Vector3.new(0, 1.5, 0),
							passed,
							victim.player
						)
					end
				end

				-- Le feu brule les DEUX equipes, comme les flammes du Pyromane.
				-- Une zone de feu qui saurait qui l'a posee serait un piege
				-- magique, pas une zone de feu.
				if zone.hurtsOwner then
					for _, friend in alliesNear(zone.team, position, zone.radius, nil) do
						local passed = dealTo(friend, amount, Combat.DOT)
						local root = rootOf(friend.player)
						if passed > 0 and root ~= nil then
							EffectsService.hit(
								root.Position + Vector3.new(0, 1.5, 0),
								passed,
								friend.player
							)
						end
					end
				end
			end
		elseif effect == "heal" then
			for _, friend in alliesNear(zone.team, position, zone.radius, nil) do
				StatusService.apply(friend.player, Status.REGEN, zone.holdSeconds, zone.magnitude)
			end
		end
	end
end

function LoadoutService.step(deltaSeconds: number)
	if not active then
		return
	end
	local now = os.clock()
	updateMines(now)
	updateGrenades(now)
	updateZones(now, deltaSeconds)
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

function LoadoutService.setDamageSink(sink: (Entry, number, string?) -> number)
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
	-- Et la contrainte d'un bond en cours : une manche qui s'arrete pendant
	-- qu'un joueur est en l'air le laisserait filer tout droit dans la
	-- suivante.
	for player in movers do
		clearMover(player)
	end
	-- Les zones aussi : une galette de feu qui survit a la manche brule les
	-- joueurs de la suivante, et personne ne comprendrait pourquoi.
	for index = #zones, 1, -1 do
		zones[index].part:Destroy()
		table.remove(zones, index)
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
		shotsLeft[player] = nil
		clearMover(player)
		roster[player] = nil
	end)

	-- Un garde-fou dans le meme esprit que celui des pouvoirs : si un objet
	-- declare une sorte d'utilisation que ce service ne sait pas executer, il
	-- coute des points et ne fait rien. Le serveur refuse de demarrer, et le
	-- message nomme le coupable.
	local handled = {
		heal = true,
		mine = true,
		grenade = true,
		shield = true,
		zone = true,
		leap = true,
		throw = true,
	}

	-- LES SIX SORTES DE ZONE, pour la meme raison exactement. Une zone
	-- « effect = fumigene » au lieu de « smoke » poserait une part invisible et
	-- ne ferait rien : l'objet couterait un point et le joueur chercherait
	-- pourquoi il ne voit pas de fumee.
	local zoneEffects = {
		smoke = true,
		reveal = true,
		slow = true,
		burn = true,
		heal = true,
		jam = true,
	}

	for _, item in Config.items do
		-- LA TROISIEME LISTE, et elle manquait. Une arme qui collerait un
		-- « bleed » a sa cible ne collerait RIEN : `Status.apply` refuse une
		-- sorte inconnue et renvoie faux, que personne ne lit. La dague
		-- empoisonnee et le pistolet a flechettes ne valent QUE par cet effet —
		-- ils frappent moins fort que tout le reste de leur prix — donc une
		-- faute de frappe les rendrait inutiles sans la moindre erreur.
		local onHit = item.onHit
		if onHit ~= nil and not Status.isKnown(onHit.kind) then
			error(
				string.format(
					"[Arena] « %s » colle « %s » a sa cible, que Status ne connait pas.",
					item.name,
					tostring(onHit.kind)
				)
			)
		end

		-- LA CINQUIEME LISTE : L'ALLURE. Une sorte de piece ou une matiere mal
		-- orthographiee retombe en silence sur une boite grise en plastique
		-- lisse, et un membre inconnu ne pose simplement RIEN. Les trois fautes
		-- ont la meme forme que les precedentes — l'objet a l'air de marcher,
		-- son allure n'est pas celle qui est ecrite, et seul un regard a
		-- l'ecran pourrait s'en apercevoir.
		local look = item.look
		if look ~= nil and look.pieces ~= nil then
			for _, piece in look.pieces do
				local shape = piece.shape or "Block"
				if not WeaponService.knowsShape(shape) then
					error(
						string.format(
							"[Arena] La piece « %s » de « %s » est de sorte « %s », inconnue.",
							tostring(piece.name),
							item.name,
							tostring(shape)
						)
					)
				end
				if not WeaponService.knowsMaterial(piece.material or "SmoothPlastic") then
					error(
						string.format(
							"[Arena] La piece « %s » de « %s » est en « %s », inconnu.",
							tostring(piece.name),
							item.name,
							tostring(piece.material)
						)
					)
				end
				-- Une piece d'armure peut nommer SON membre. Un nom inconnu ne
				-- leve rien : le groupe est simplement saute, et la piece
				-- n'apparait nulle part. C'est la faute la plus discrete de la
				-- famille, parce que le reste de l'armure s'affiche tres bien.
				if piece.limb ~= nil and not WeaponService.knowsLimb(piece.limb) then
					error(
						string.format(
							"[Arena] La piece « %s » de « %s » se porte sur « %s », qui n'est un membre sur aucun rig.",
							tostring(piece.name),
							item.name,
							tostring(piece.limb)
						)
					)
				end
			end
			if look.worn ~= nil and not WeaponService.knowsLimb(look.worn.limb) then
				error(
					string.format(
						"[Arena] « %s » se porte sur « %s », qui n'est un membre sur aucun rig.",
						item.name,
						tostring(look.worn.limb)
					)
				)
			end
		end

		local use = item.use

		-- UNE ZONE QUI COLLE UN EFFET DOIT DIRE COMBIEN DE TEMPS IL TIENT.
		-- Sans ce test, un oubli retombe sur le repli de `placeZone` et le
		-- chiffre devient illisible depuis Config — c'est arrive au dome de
		-- soin.
		if use ~= nil and use.kind == "zone" and HOLDING_ZONES[use.effect] then
			if type(use.holdSeconds) ~= "number" or use.holdSeconds <= 0 then
				error(
					string.format(
						"[Arena] La zone de « %s » colle un effet sans dire combien de temps (holdSeconds = %s).",
						item.name,
						tostring(use.holdSeconds)
					)
				)
			end
		end

		if use ~= nil and use.kind == "zone" and not zoneEffects[use.effect] then
			error(
				string.format(
					"[Arena] La zone de « %s » est « %s », que LoadoutService ne sait pas poser.",
					item.name,
					tostring(use.effect)
				)
			)
		end
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
