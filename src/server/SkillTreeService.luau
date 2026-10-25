--!strict
--[[
	SkillTreeService — l'arbre de competences cote serveur.

	Tout le calcul est dans SkillTree et Modifiers, qui sont purs et testes hors
	de Studio. Ici on ne fait que ce que seul Roblox sait faire : garder un etat
	par joueur, ecouter un RemoteEvent, et renvoyer au client de quoi afficher
	l'arbre.

	LE SERVEUR EST SEUL JUGE. Le client n'envoie que trois intentions : « je
	choisis cette branche », « je monte d'un palier », « j'ai fini ». Il ne dit
	jamais combien de points il a, ni a quel palier il est. Un client qui mentit
	sur sa branche se fait refuser par SkillTree.chooseBranch, qui verifie que la
	branche existe pour SA classe et que rien n'est deja verrouille.

	QUAND ON DEPENSE : jamais pendant une manche. Config.skillTree
	spendingDuringRound le dit, et le refus est verifie ici, pas cote client.
	Monter un palier qui touche les PV maximum pendant un echange equivaudrait a
	un soin complet, et un arbre qui se modifie en combat n'est plus une decision
	de strategie.

	L'ARBRE EST REMIS A ZERO A CHAQUE PARTIE : beginMatch efface tout et
	redistribue le point de depart. C'est le troisieme principe du projet, et
	c'est la seule ligne de ce fichier qui ne doit jamais changer.
]]

local SkillTreeService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Classes = require(Arena:WaitForChild("Classes"))
local Config = require(Arena:WaitForChild("Config"))
local Modifiers = require(Arena:WaitForChild("Modifiers"))
local SkillTree = require(Arena:WaitForChild("SkillTree"))

local Remotes = Arena:WaitForChild("Remotes")
local treeRemote = Remotes:WaitForChild("Tree") :: RemoteEvent

type Entry = { player: Player, team: string, classId: string, stats: any }

local states: { [Player]: SkillTree.State } = {}
local ready: { [Player]: boolean } = {}
local lastRequestAt: { [Player]: number } = {}

-- La phase de depense est ouverte ou fermee. Fermee, les trois intentions du
-- client sont refusees, et l'interface s'affiche en lecture seule.
local spendingOpen = false
local spendingEndsAt: number? = nil

-- Appele quand un joueur modifie son arbre, pour que MatchService recalcule les
-- statistiques effectives sans que ce module connaisse CombatService.
local onChanged: ((Player) -> ())? = nil

--------------------------------------------------------------------------------
-- L'ETAT
--------------------------------------------------------------------------------

function SkillTreeService.isEnabled(): boolean
	return Config.skillTree.enabled
end

function SkillTreeService.stateOf(player: Player): SkillTree.State?
	return states[player]
end

-- Remise a zero complete, et le point de depart distribue. Une partie commence
-- toujours ici, et aucun etat ne survit d'une partie a l'autre.
function SkillTreeService.beginMatch(entries: { Entry })
	states = {}
	ready = {}
	spendingOpen = false
	spendingEndsAt = nil

	if not SkillTreeService.isEnabled() then
		return
	end

	for _, entry in entries do
		local state = SkillTree.create(entry.classId)
		SkillTree.grantStartingPoints(Config, state)
		states[entry.player] = state
	end
end

function SkillTreeService.endMatch()
	states = {}
	ready = {}
	spendingOpen = false
	spendingEndsAt = nil
end

-- Les points de fin de manche. Renvoie, par joueur, le nombre accorde et si le
-- point de revanche vient de tomber : MatchService s'en sert pour l'annoncer,
-- parce qu'un point qui arrive sans qu'on le dise n'est pas un point.
function SkillTreeService.grantRoundEnd(
	entries: { Entry },
	winner: string?
): { [Player]: { granted: number, comeback: boolean } }
	local report: { [Player]: { granted: number, comeback: boolean } } = {}

	if not SkillTreeService.isEnabled() then
		return report
	end

	for _, entry in entries do
		local state = states[entry.player]
		if state == nil then
			continue
		end

		local wonRound = winner ~= nil and entry.team == winner
		local granted = SkillTree.grantRoundEnd(Config, state, wonRound)
		report[entry.player] = {
			granted = granted,
			comeback = SkillTree.justUsedComeback(Config, state),
		}
	end

	return report
end

--------------------------------------------------------------------------------
-- LES STATISTIQUES EFFECTIVES
--------------------------------------------------------------------------------

-- Les statistiques du joueur, branche et paliers compris. Modifiers.apply
-- recopie avant de modifier, donc les statistiques de classe de Config ne sont
-- jamais ecrasees : sans ca, l'arbre se cumulerait d'une manche a l'autre.
function SkillTreeService.effectiveStats(player: Player, baseStats: any): any
	local state = states[player]
	if state == nil or not SkillTreeService.isEnabled() then
		return baseStats
	end

	local branch = SkillTree.currentBranch(Config, state)
	return Modifiers.apply(Config, baseStats, branch, state.tier)
end

-- Recalcule les statistiques de chaque entree du roster, sur place. Appele
-- avant chaque manche, et apres chaque achat.
function SkillTreeService.refreshStats(entries: { Entry })
	for _, entry in entries do
		entry.stats =
			SkillTreeService.effectiveStats(entry.player, Config.classStats[entry.classId])
	end
end

-- L'effet nomme du palier 6, ou nil : palier non atteint, ou effet decrit mais
-- pas encore code. Les services de combat interrogent ceci, jamais la branche
-- directement, pour qu'un effet non implemente ne fasse rien au lieu de planter.
function SkillTreeService.effectOf(player: Player): string?
	local state = states[player]
	if state == nil or not SkillTreeService.isEnabled() then
		return nil
	end
	return SkillTree.activeTier6Effect(Config, state)
end

function SkillTreeService.hasEffect(player: Player, effect: string): boolean
	return SkillTreeService.effectOf(player) == effect
end

function SkillTreeService.onChanged(callback: (Player) -> ())
	onChanged = callback
end

--------------------------------------------------------------------------------
-- LA PHASE DE DEPENSE
--------------------------------------------------------------------------------

-- Vrai si au moins un joueur a quelque chose a faire de ses points. Sans ca on
-- ouvrirait une phase de quinze secondes ou personne n'a rien a decider, et
-- c'est le genre de temps mort qui tue le rythme d'une serie.
function SkillTreeService.anyoneCanSpend(): boolean
	if not SkillTreeService.isEnabled() then
		return false
	end

	for _, state in states do
		if state.branchId == nil then
			return true
		end
		if SkillTree.canAdvance(Config, state) then
			return true
		end
	end
	return false
end

function SkillTreeService.openSpending(seconds: number)
	if not SkillTreeService.isEnabled() then
		return
	end

	spendingOpen = true
	spendingEndsAt = os.clock() + seconds
	ready = {}
	SkillTreeService.pushAll()
end

function SkillTreeService.closeSpending()
	spendingOpen = false
	spendingEndsAt = nil
	SkillTreeService.pushAll()
end

function SkillTreeService.secondsLeft(): number?
	local endsAt = spendingEndsAt
	if endsAt == nil then
		return nil
	end
	return math.max(endsAt - os.clock(), 0)
end

-- Vrai quand plus personne n'a de raison d'attendre : tout le monde a appuye sur
-- « Prêt », ou n'a plus rien a depenser. Ca permet de couper une phase de
-- quinze secondes des que les decisions sont prises.
function SkillTreeService.everyoneDone(): boolean
	for player, state in states do
		if player.Parent == nil then
			continue
		end
		if ready[player] then
			continue
		end
		if state.branchId == nil or SkillTree.canAdvance(Config, state) then
			return false
		end
	end
	return true
end

--------------------------------------------------------------------------------
-- CE QUE LE CLIENT RECOIT
--------------------------------------------------------------------------------

local function branchView(state: SkillTree.State, branch: any): any
	local tier6 = branch.tier6 or {}
	return {
		id = branch.id,
		name = branch.name,
		kind = branch.kind,
		summary = branch.summary,
		sacrifice = branch.sacrifice,
		tier6Label = tier6.label,
		-- Un effet decrit mais pas code s'affiche comme indisponible. Mieux vaut
		-- une option barree qu'une option qui se vend deux points sans rien faire.
		tier6Available = tier6.implemented == true,
		chosen = state.branchId == branch.id,
	}
end

-- Ce que la branche a change par rapport a la classe nue, en lignes lisibles.
local function changesView(state: SkillTree.State): { any }
	local branch = SkillTree.currentBranch(Config, state)
	if branch == nil then
		return {}
	end

	local base = Config.classStats[state.classId]
	local effective = Modifiers.apply(Config, base, branch, state.tier)

	local lines: { any } = {}
	for _, change in Modifiers.differences(base, effective) do
		table.insert(lines, {
			text = Modifiers.describe(change.key, change.from, change.to),
			gain = Modifiers.isGain(change.key, change.from, change.to),
		})
	end
	return lines
end

function SkillTreeService.viewFor(player: Player): any?
	local state = states[player]
	if state == nil then
		return nil
	end

	local class = Classes.byId[state.classId]
	local branches: { any } = {}
	for _, branch in SkillTree.branchesFor(Config, state.classId) do
		table.insert(branches, branchView(state, branch))
	end

	return {
		open = spendingOpen,
		seconds = SkillTreeService.secondsLeft(),
		ready = ready[player] == true,

		className = if class then class.name else state.classId,
		branchId = state.branchId,
		tier = state.tier,
		tiers = Config.skillTree.tiers,
		tierCosts = Config.skillTree.tierCosts,

		points = SkillTree.availablePoints(state),
		nextCost = SkillTree.costOfNextTier(Config, state),
		canAdvance = spendingOpen and SkillTree.canAdvance(Config, state),
		complete = SkillTree.isComplete(Config, state),
		remainingCost = SkillTree.remainingCost(Config, state),

		branches = branches,
		changes = changesView(state),
	}
end

function SkillTreeService.push(player: Player)
	local view = SkillTreeService.viewFor(player)
	if view == nil then
		return
	end
	treeRemote:FireClient(player, view)
end

function SkillTreeService.pushAll()
	for player in states do
		if player.Parent ~= nil then
			SkillTreeService.push(player)
		end
	end
end

--------------------------------------------------------------------------------
-- LES INTENTIONS DU CLIENT
--------------------------------------------------------------------------------

-- Le client peut envoyer n'importe quoi, y compris rien. Tout est verifie ici.
local function onTreeRequest(player: Player, payload: any)
	if not SkillTreeService.isEnabled() then
		return
	end
	if typeof(payload) ~= "table" then
		return
	end

	local state = states[player]
	if state == nil then
		return
	end

	-- Un garde-fou minimal contre l'inondation : dix requetes par seconde
	-- suffisent largement a un humain qui clique, et rien de ce qui suit ne
	-- coute cher de toute facon.
	local now = os.clock()
	local last = lastRequestAt[player]
	if last ~= nil and (now - last) < 0.1 then
		return
	end
	lastRequestAt[player] = now

	local action = payload.action
	if typeof(action) ~= "string" then
		return
	end

	-- Le refus de depenser pendant une manche est verifie ICI. Le client cache
	-- bien les boutons, mais un client ne prouve rien.
	local canSpend = spendingOpen or Config.skillTree.spendingDuringRound
	local changed = false

	if action == "choose" then
		if not canSpend then
			return
		end
		if typeof(payload.branchId) ~= "string" then
			return
		end
		changed = SkillTree.chooseBranch(Config, state, payload.branchId)
	elseif action == "advance" then
		if not canSpend then
			return
		end
		changed = SkillTree.advance(Config, state)
	elseif action == "ready" then
		ready[player] = true
	end

	if changed and onChanged ~= nil then
		onChanged(player)
	end

	SkillTreeService.push(player)
end

function SkillTreeService.init()
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		ready[player] = nil
		lastRequestAt[player] = nil
	end)

	treeRemote.OnServerEvent:Connect(onTreeRequest)
end

return SkillTreeService
