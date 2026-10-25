--!strict
--[[
	DraftService — la phase de bans, puis le tirage des classes.

	Tout le calcul est dans Draft, qui est pur et teste hors de Studio : le
	vivier, l'ordre des bans, le depouillement, l'unicite des classes, le
	miroir du 1v1, le relancement. Ici on ne fait que ce que seul Roblox sait
	faire : attendre vingt secondes, recevoir les votes des clients, et
	raconter ce qui se passe.

	LE SERVEUR EST SEUL JUGE, comme partout ailleurs. Le client envoie « je vote
	pour bannir le Spectre » et « je relance » ; il ne decide ni ce qui est
	banni, ni ce qui est tire. Un client qui enverrait le nom d'une classe deja
	bannie, ou le vote d'une equipe qui n'est pas la sienne, est simplement
	ignore.

	LE RELANCEMENT EST AVEUGLE, et l'ordre des etapes est ce qui le garantit :
	on tire, on demande « tu relances ? » SANS rien montrer, on applique les
	relancements, et seulement apres on revele. Montrer la classe avant de
	proposer le relancement en ferait un choix deguise, et la fiche s'y oppose.
]]

local DraftService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Classes = require(Arena:WaitForChild("Classes"))
local Config = require(Arena:WaitForChild("Config"))
local Draft = require(Arena:WaitForChild("Draft"))

local Remotes = Arena:WaitForChild("Remotes")
local draftRemote = Remotes:WaitForChild("Draft") :: RemoteEvent

-- Le hasard du jeu. Les tests en injectent un autre, choisi, c'est tout
-- l'interet d'avoir sorti le calcul d'ici.
local random = Random.new()
local function rng(n: number): number
	if n <= 1 then
		return 1
	end
	return random:NextInteger(1, n)
end

-- Les votes recus pendant le tour de ban en cours, et les relancements
-- demandes. Vides en dehors de ces fenetres : un message qui arrive hors
-- fenetre n'a nulle part ou atterrir, et c'est voulu.
local banVotes: { [Player]: string } = {}
local rerollAsked: { [Player]: boolean } = {}
local listening = false

local function teamOf(player: Player, teams: { [Player]: string }): string?
	return teams[player]
end

local function tellAll(payload: any)
	for _, player in Players:GetPlayers() do
		draftRemote:FireClient(player, payload)
	end
end

local function poolView(state: Draft.State): { any }
	local view: { any } = {}
	for _, classId in state.pool do
		local class = Classes.byId[classId]
		if class == nil then
			continue
		end
		table.insert(view, {
			id = class.id,
			name = class.name,
			power = class.power,
			weakness = class.weakness,
			role = class.role,
		})
	end
	return view
end

local function banPhase(state: Draft.State, teams: { [Player]: string }, teamNames: { string })
	for _, banningTeam in Draft.banOrder(Config, teamNames) do
		if #state.pool == 0 then
			break
		end

		banVotes = {}

		local seconds = Config.draft.banVoteSeconds
		for _, player in Players:GetPlayers() do
			draftRemote:FireClient(player, {
				kind = "bans",
				pool = poolView(state),
				banning = banningTeam,
				mine = teamOf(player, teams) == banningTeam,
				seconds = seconds,
				bans = state.bans,
			})
		end

		-- On attend la fenetre entiere, meme si tout le monde a vote : un
		-- compte a rebours qui se termine tot priverait l'equipe d'en face du
		-- temps de lire ce qui vient d'etre banni.
		task.wait(seconds)

		local votes: { string } = {}
		for player, classId in banVotes do
			if teamOf(player, teams) == banningTeam then
				table.insert(votes, classId)
			end
		end

		local banned = Draft.tallyBan(state, votes, rng)
		if banned ~= nil then
			Draft.ban(state, banningTeam, banned)
			local class = Classes.byId[banned]
			tellAll({
				kind = "banned",
				team = banningTeam,
				classId = banned,
				name = if class then class.name else banned,
			})
			print(
				string.format(
					"[Arena] Equipe %s bannit %s",
					banningTeam,
					if class then class.name else banned
				)
			)
		end

		task.wait(1.5)
	end

	banVotes = {}
end

local function rerollPhase(state: Draft.State, players: { Player })
	if Config.draft.rerollsPerPlayer <= 0 then
		return
	end

	rerollAsked = {}

	local seconds = Config.draft.rerollSeconds
	for _, player in players do
		draftRemote:FireClient(player, { kind = "reroll", seconds = seconds })
	end

	task.wait(seconds)

	for _, player in players do
		if not rerollAsked[player] then
			continue
		end
		local replacement = Draft.reroll(Config, state, tostring(player.UserId), rng)
		if replacement ~= nil then
			print(string.format("[Arena] %s relance sa classe", player.Name))
		end
	end

	rerollAsked = {}
end

-- Deroule bans, tirage, relancement et revelation. Renvoie la classe de chaque
-- joueur. En cas de vivier insuffisant, un joueur peut repartir sans classe :
-- l'appelant doit le gerer, et MatchService lui donne alors une classe du
-- prototype plutot que de le laisser sans rien.
function DraftService.run(players: { Player }, teams: { [Player]: string }): { [Player]: string }
	listening = true

	local teamNames: { string } = {}
	local seenTeam: { [string]: boolean } = {}
	local rosters: { [string]: { string } } = {}
	local playersPerTeam = 0

	for _, player in players do
		local team = teams[player]
		if team == nil then
			continue
		end
		if not seenTeam[team] then
			seenTeam[team] = true
			table.insert(teamNames, team)
			rosters[team] = {}
		end
		table.insert(rosters[team], tostring(player.UserId))
		playersPerTeam = math.max(playersPerTeam, #rosters[team])
	end
	table.sort(teamNames)

	local state = Draft.create(Classes.all, playersPerTeam)

	banPhase(state, teams, teamNames)
	Draft.assign(Config, state, rosters, rng)
	rerollPhase(state, players)

	-- La revelation, enfin. C'est le premier moment ou quelqu'un voit sa
	-- classe, et c'est voulu.
	local result: { [Player]: string } = {}
	for _, player in players do
		local classId = state.assigned[tostring(player.UserId)]
		if classId == nil then
			continue
		end
		result[player] = classId

		local class = Classes.byId[classId]
		draftRemote:FireClient(player, {
			kind = "class",
			classId = classId,
			name = if class then class.name else classId,
			power = if class then class.power else nil,
			weakness = if class then class.weakness else nil,
			role = if class then class.role else nil,
			seconds = Config.draft.revealSeconds,
		})
	end

	task.wait(Config.draft.revealSeconds)
	tellAll({ kind = "close" })
	listening = false

	return result
end

function DraftService.init()
	draftRemote.OnServerEvent:Connect(function(player: Player, payload: any)
		-- Hors fenetre, on ignore : c'est la facon la plus simple de ne pas
		-- avoir a se demander ce qu'un vote veut dire pendant une manche.
		if not listening or typeof(payload) ~= "table" then
			return
		end

		if typeof(payload.vote) == "string" then
			banVotes[player] = payload.vote
		elseif payload.reroll == true then
			rerollAsked[player] = true
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		banVotes[player] = nil
		rerollAsked[player] = nil
	end)
end

return DraftService
