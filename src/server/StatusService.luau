--!strict
--[[
	StatusService — ce qui colle a un combattant, applique sur de vrais
	personnages.

	Status.luau porte l'arithmetique — quel effet gagne quand deux se
	superposent, combien de PV un poison retire sur un intervalle. Ce service
	porte les Humanoid : il ralentit, il immobilise, il fait monter les nombres
	a l'ecran, et il remet tout en place quand la manche s'arrete.

	IL NE REQUIERT NI CombatService NI LoadoutService, et les deux le
	requierent. C'est la meme regle qu'AbilityService : les degats et les soins
	arrivent par des puits qu'on lui installe au demarrage. Un require croise et
	Roblox refuse de charger les deux.

	QUI COMMANDE LA VITESSE, ET POURQUOI C'EST LA SEULE VRAIE DIFFICULTE. Trois
	choses ecrivent dans `Humanoid.WalkSpeed` : CombatService quand les
	statistiques changent, DownedService quand on tombe a terre, et ce service.
	La regle qui les departage est simple et n'a pas d'exception :

	    un joueur a terre appartient a DownedService, point.

	Donc ce service ne touche a personne qui ne soit debout, et il recalcule la
	vitesse depuis `entry.stats.walkSpeed` a chaque battement plutot que de
	garder une valeur d'avant. Garder une valeur d'avant serait perime des
	qu'une branche d'arbre pousse la vitesse en pleine manche, et le joueur
	resterait lent sans raison visible.

	L'ETOURDISSEMENT PASSE PAR CombatService.setFrozen, qui existait deja pour
	le pouvoir du Sismique : un joueur gele ne se deplace pas et ne frappe pas.
	Le geler ici ET lui mettre une vitesse de zero serait deux facons de dire la
	meme chose, donc une de trop.
]]

local StatusService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Config = require(Arena:WaitForChild("Config"))
local Combat = require(Arena:WaitForChild("Combat"))
local Status = require(Arena:WaitForChild("Status"))

local DownedService = require(script.Parent:WaitForChild("DownedService"))
local EffectsService = require(script.Parent:WaitForChild("EffectsService"))

export type Entry = {
	player: Player,
	team: string,
	classId: string,
	stats: Combat.Stats,
}

local roster: { [Player]: Entry } = {}
local states: { [Player]: Status.State } = {}
local active = false

-- Les puits, installes par CombatService au demarrage. Sans eux, un poison ne
-- retire rien : c'est volontairement visible plutot que silencieux, et le
-- demarrage du serveur verifie qu'ils ont ete poses.
local damageSink: ((Entry, number, string?) -> number)? = nil
local healSink: ((Player, number) -> ())? = nil
local freezeSink: ((Player, boolean) -> ())? = nil

-- Le dernier battement de poison et de regeneration. On ne retire pas des PV a
-- chaque image : quatre fois par seconde, sinon l'ecran se remplit de nombres a
-- un chiffre et plus personne ne lit rien.
local lastTickAt = 0

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

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid
end

local function stateOf(player: Player): Status.State
	local state = states[player]
	if state == nil then
		state = Status.create()
		states[player] = state
	end
	return state
end

-- La vitesse que ce joueur doit avoir maintenant. Recalculee depuis ses
-- statistiques a chaque fois, jamais memorisee.
local function applySpeed(player: Player)
	local entry = roster[player]
	if entry == nil then
		return
	end
	if not DownedService.isStanding(player) then
		return
	end

	local humanoid = humanoidOf(player)
	if humanoid == nil then
		return
	end

	local ratio = Status.speedRatio(Config, stateOf(player), os.clock())
	humanoid.WalkSpeed = entry.stats.walkSpeed * ratio
end

local function applyFreeze(player: Player)
	local sink = freezeSink
	if sink == nil then
		return
	end
	sink(player, Status.isStunned(stateOf(player), os.clock()))
end

--------------------------------------------------------------------------------
-- POSER ET RETIRER
--------------------------------------------------------------------------------

-- Pose un effet sur un joueur. Renvoie faux si la sorte est inconnue — un objet
-- qui demanderait un effet que personne n'applique ne ferait rien du tout, en
-- silence, et c'est exactement la panne des branches creuses.
function StatusService.apply(
	player: Player,
	kind: string,
	seconds: number,
	magnitude: number
): boolean
	if not DownedService.isStanding(player) then
		return false
	end

	-- L'ETOURDISSEMENT A UN PLAFOND, et il est ici plutot que dans chaque
	-- objet : c'est le seul effet qui retire ses commandes au joueur, donc le
	-- seul dont une valeur trop grande ne se rattrape pas en jouant.
	if kind == Status.STUN then
		seconds = math.min(seconds, Config.status.maxStunSeconds)
	end

	if not Status.apply(stateOf(player), kind, seconds, magnitude, os.clock()) then
		return false
	end

	if kind == Status.STUN then
		applyFreeze(player)
	end
	if kind == Status.SLOW or kind == Status.STUN then
		applySpeed(player)
	end
	return true
end

function StatusService.has(player: Player, kind: string): boolean
	return Status.has(stateOf(player), kind, os.clock())
end

function StatusService.isStunned(player: Player): boolean
	return Status.isStunned(stateOf(player), os.clock())
end

-- Ce que l'interface affiche pour ce joueur. Trie, pour que l'ordre a l'ecran
-- ne danse pas d'un rafraichissement a l'autre.
function StatusService.describe(player: Player): { { kind: string, secondsLeft: number } }
	return Status.describe(stateOf(player), os.clock())
end

-- Tout retirer d'un joueur : fin de manche, mort, depart. On remet la vitesse
-- et on degele, parce qu'un effet retire qui laisse sa consequence derriere lui
-- est pire qu'un effet qui dure.
function StatusService.clearFor(player: Player)
	local state = states[player]
	if state == nil then
		return
	end
	local kinds = Status.clear(state)
	if #kinds == 0 then
		return
	end
	applyFreeze(player)
	applySpeed(player)
end

function StatusService.clearAll()
	for player in states do
		StatusService.clearFor(player)
	end
	states = {}
end

--------------------------------------------------------------------------------
-- LE BATTEMENT
--------------------------------------------------------------------------------

function StatusService.step(_deltaSeconds: number)
	if not active then
		return
	end

	local now = os.clock()

	-- CE QUI VIENT DE FINIR, D'ABORD. Un joueur dont le ralentissement expire
	-- doit retrouver sa vitesse meme si rien d'autre ne se passe, et ce n'est
	-- vrai que si on repasse par `applySpeed` apres l'avoir retire.
	for player, state in states do
		local done = Status.expire(state, now)
		if #done == 0 then
			continue
		end
		-- Le degel D'ABORD : il remet la vitesse de base, donc le calcul du
		-- ralentissement doit passer apres lui. Dans l'autre ordre, sortir d'un
		-- etourdissement rendait sa pleine vitesse a quelqu'un qui marchait
		-- encore dans les chausse-trappes.
		for _, kind in done do
			if kind == Status.STUN then
				applyFreeze(player)
			end
		end
		for _, kind in done do
			if kind == Status.SLOW or kind == Status.STUN then
				applySpeed(player)
			end
		end
	end

	if (now - lastTickAt) < Config.status.tickSeconds then
		return
	end
	local elapsed = now - lastTickAt
	lastTickAt = now

	for player, state in states do
		local entry = roster[player]
		if entry == nil or not DownedService.isStanding(player) then
			continue
		end

		local damage, heal = Status.tick(state, now, elapsed)
		local root = rootOf(player)

		if damage > 0 then
			local sink = damageSink
			-- LE POISON EST UNE SORTE DE DEGAT, et c'est ce qui donne un sens
			-- au plastron de cuir : sans ce troisieme argument, l'armure qui
			-- resiste aux poisons ne resisterait a rien.
			local passed = if sink ~= nil then sink(entry, damage, Combat.DOT) else 0
			if passed > 0 and root ~= nil then
				EffectsService.hit(root.Position + Vector3.new(0, 1.5, 0), passed, player)
			end
		end

		if heal > 0 then
			local sink = healSink
			if sink ~= nil then
				sink(player, heal)
			end
			if root ~= nil then
				EffectsService.heal(root.Position + Vector3.new(0, 1.5, 0), heal, player, "heal")
			end
		end

		-- Et la vitesse se reapplique tant qu'un ralentissement court : une
		-- branche d'arbre prise en pleine manche change `entry.stats`, et sans
		-- ca le joueur garderait l'ancienne vitesse jusqu'a la fin de l'effet.
		if Status.has(state, Status.SLOW, now) then
			applySpeed(player)
		end
	end
end

--------------------------------------------------------------------------------
-- LES BRANCHEMENTS
--------------------------------------------------------------------------------

function StatusService.setDamageSink(sink: (Entry, number, string?) -> number)
	damageSink = sink
end

function StatusService.setHealSink(sink: (Player, number) -> ())
	healSink = sink
end

function StatusService.setFreezeSink(sink: (Player, boolean) -> ())
	freezeSink = sink
end

function StatusService.setRoster(entries: { Entry })
	roster = {}
	for _, entry in entries do
		roster[entry.player] = entry
	end
end

function StatusService.setActive(value: boolean)
	active = value
	lastTickAt = os.clock()
	if not value then
		StatusService.clearAll()
	end
end

return StatusService
