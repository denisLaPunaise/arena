--!strict
--[[
	MatchService — la boucle d'une partie du prototype.

	Attendre deux joueurs, distribuer les deux classes, jouer les manches
	jusqu'a ce qu'une equipe atteigne le compte, annoncer, recommencer.

	Le score lui-meme est calcule par MatchState, qui est pur et teste hors de
	Studio. Ici on ne fait que ce qui demande Roblox : faire apparaitre les
	personnages, attendre une mort, parler aux clients.

	Ce qui n'est PAS la, et c'est voulu : pas de bans, pas de tirage au sort,
	pas d'arbre, pas d'equipement. Le prototype repond a une seule question :
	ce duel est-il amusant.

	La zone et l'agonie sont arrivees a l'etape 3. Elles se coupent toutes les
	deux depuis Config, pour pouvoir jouer une manche avec et une manche sans
	et comparer.
]]

local MatchService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Config = require(Arena:WaitForChild("Config"))
local Classes = require(Arena:WaitForChild("Classes"))
local MatchState = require(Arena:WaitForChild("MatchState"))

local Remotes = Arena:WaitForChild("Remotes")
local hudRemote = Remotes:WaitForChild("Hud") :: RemoteEvent

local CombatService = require(script.Parent:WaitForChild("CombatService"))
local DownedService = require(script.Parent:WaitForChild("DownedService"))
local MapService = require(script.Parent:WaitForChild("MapService"))
local ZoneService = require(script.Parent:WaitForChild("ZoneService"))

local TEAMS = { "A", "B" }
local PLAYERS_NEEDED = 2

local map: Instance? = nil
local swapClasses = false
local roundEntries: { CombatService.Entry } = {}

local function className(classId: string): string
	local class = Classes.byId[classId]
	return if class then class.name else classId
end

local function tell(player: Player, title: string, status: string, zone: string?, alert: string?)
	hudRemote:FireClient(player, {
		title = title,
		status = status,
		zone = zone or "",
		alert = alert or "",
	})
end

local function tellAll(title: string, status: string)
	for _, player in Players:GetPlayers() do
		tell(player, title, status)
	end
end

-- La largeur de MapBounds, d'ou la zone deduit son rayon de depart. Nil quand
-- la map n'en a pas : Zone retombe alors sur son rayon par defaut.
local function mapWidth(): number?
	local currentMap = map
	if currentMap == nil then
		return nil
	end
	local bounds = currentMap:FindFirstChild(Config.mapContract.boundsPart)
	if bounds and bounds:IsA("BasePart") then
		return math.min(bounds.Size.X, bounds.Size.Z)
	end
	return nil
end

-- La ligne de zone affichee a ce joueur. Elle dit toujours deux choses : si on
-- est dedans, et dans combien de temps ca bouge.
local function zoneLineFor(entry: CombatService.Entry): string
	if not ZoneService.isActive() then
		return ""
	end

	local outside = false
	local character = entry.player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		outside = ZoneService.isOutside(root.Position)
	end

	local snapshot = ZoneService.snapshot()
	local where = if outside then "⚠ HORS DE LA ZONE" else "Zone"

	local remaining = snapshot.secondsUntilNextShrink
	if remaining == nil then
		return string.format("%s  ·  refermée", where)
	end

	return string.format("%s  ·  resserrement dans %d s", where, math.ceil(remaining))
end

local function statusFor(entry: CombatService.Entry, state: MatchState.State): string
	return string.format(
		"%s  ·  %s  ·  manche %d / %d",
		className(entry.classId),
		MatchState.scoreLine(state, entry.team),
		MatchState.roundNumber(state),
		MatchState.maxRounds(state)
	)
end

local function spawnEntry(entry: CombatService.Entry, index: number)
	local currentMap = map
	if currentMap == nil then
		return
	end

	local positions = MapService.spawnPositions(currentMap, Config, entry.team)
	local position = positions[((index - 1) % #positions) + 1]

	entry.player:LoadCharacter()

	local character = entry.player.Character
	if character == nil then
		return
	end

	-- Face au centre : sans ca les joueurs apparaissent dos a dos et perdent
	-- deux secondes a se chercher.
	local center = MapService.zoneCenter(currentMap, Config)
	local lookAt = Vector3.new(center.X, position.Y, center.Z)
	character:PivotTo(CFrame.lookAt(position, lookAt))

	CombatService.applyStats(entry.player, entry.stats)
end

-- Le titre affiche pendant la manche, selon l'etat du joueur.
local function titleFor(entry: CombatService.Entry): string
	local status = DownedService.statusOf(entry.player)
	if status == "downed" then
		return "À TERRE"
	elseif status == "out" then
		return "Éliminé"
	end
	return ""
end

-- L'alerte voyage dans CHAQUE rafraichissement, jamais une seule fois au
-- changement d'etat : sinon le rafraichissement suivant, un quart de seconde
-- plus tard, efface le bandeau rouge que l'evenement venait d'allumer.
local function alertFor(entry: CombatService.Entry): string
	local status = DownedService.statusOf(entry.player)
	if status == "downed" or status == "out" then
		return status
	end
	return ""
end

-- Renvoie l'equipe gagnante, ou nil si la manche n'a pas de vainqueur (un
-- joueur est parti, ou les deux sont tombes en meme temps).
--
-- Ce n'est plus l'etat des Humanoid qui decide : un joueur a terre est encore
-- a un PV et son equipe n'est pas eliminee tant que sa fenetre court.
local function waitForRoundEnd(entries: { CombatService.Entry }, state: MatchState.State): string?
	local lastHud = 0

	while true do
		task.wait(0.1)

		for _, entry in entries do
			if entry.player.Parent == nil then
				return nil
			end
		end

		-- Quatre rafraichissements par seconde suffisent pour un compte a
		-- rebours, et evitent d'inonder le reseau pour rien.
		local now = os.clock()
		if (now - lastHud) >= 0.25 then
			lastHud = now
			for _, entry in entries do
				tell(
					entry.player,
					titleFor(entry),
					statusFor(entry, state),
					zoneLineFor(entry),
					alertFor(entry)
				)
			end
		end

		if DownedService.roundIsOver() then
			return DownedService.roundWinner()
		end
	end
end

local function countdown(entries: { CombatService.Entry }, state: MatchState.State)
	for _, entry in entries do
		CombatService.setFrozen(entry.player, true)
	end

	for remaining = Config.prototype.secondsBeforeRoundStarts, 1, -1 do
		for _, entry in entries do
			tell(
				entry.player,
				string.format("Manche %d dans %d", MatchState.roundNumber(state), remaining),
				statusFor(entry, state)
			)
		end
		task.wait(1)
	end

	for _, entry in entries do
		CombatService.setFrozen(entry.player, false)
		tell(entry.player, "Combat !", statusFor(entry, state))
	end
end

local function buildEntries(players: { Player }): { CombatService.Entry }
	local entries: { CombatService.Entry } = {}
	local classes = Config.prototype.classes

	for index, player in players do
		local classIndex = index
		if swapClasses then
			classIndex = (#classes + 1) - index
		end

		local classId = classes[classIndex]
		table.insert(entries, {
			player = player,
			team = TEAMS[index],
			classId = classId,
			stats = Config.classStats[classId],
		})
	end

	return entries
end

local function runMatch(players: { Player })
	local entries = buildEntries(players)
	roundEntries = entries
	CombatService.setRoster(entries)
	DownedService.setRoster(entries)

	local state = MatchState.create(Config.prototype.roundsToWin)

	for _, entry in entries do
		print(
			string.format(
				"[Arena] %s joue le %s (equipe %s)",
				entry.player.Name,
				className(entry.classId),
				entry.team
			)
		)
	end

	while not MatchState.isOver(state) do
		DownedService.resetRound()

		for index, entry in entries do
			spawnEntry(entry, index)
		end

		countdown(entries, state)

		-- La zone ne demarre qu'au signal de combat : son compte a rebours ne
		-- doit pas tourner pendant que tout le monde est encore fige.
		local currentMap = map
		if currentMap then
			ZoneService.start(MapService.zoneCenter(currentMap, Config), mapWidth())
		end

		CombatService.setActive(true)
		DownedService.setActive(true)

		local winner = waitForRoundEnd(entries, state)

		CombatService.setActive(false)
		DownedService.setActive(false)
		ZoneService.stop()

		if winner == nil then
			tellAll("Manche interrompue", "")
			print("[Arena] Manche sans vainqueur, partie abandonnee.")
			return
		end

		MatchState.recordRoundWin(state, winner)

		for _, entry in entries do
			local verdict = if entry.team == winner then "Manche gagnee" else "Manche perdue"
			tell(entry.player, verdict, statusFor(entry, state))
		end

		print(
			string.format(
				"[Arena] Manche %d remportee par l'equipe %s. Score %s.",
				state.roundsPlayed,
				winner,
				MatchState.scoreLine(state, "A")
			)
		)

		task.wait(Config.prototype.secondsBetweenRounds)
	end

	local winner = MatchState.winner(state)
	for _, entry in entries do
		local verdict = if entry.team == winner then "Partie gagnee" else "Partie perdue"
		tell(entry.player, verdict, statusFor(entry, state))
	end

	print(
		string.format(
			"[Arena] Partie remportee par l'equipe %s, %s.",
			tostring(winner),
			MatchState.scoreLine(state, "A")
		)
	)

	if Config.prototype.swapClassesBetweenMatches then
		swapClasses = not swapClasses
	end
end

-- Annonce les changements d'etat au fil de la manche. L'affichage complet est
-- rafraichi par waitForRoundEnd ; ici on ne fait que reagir tout de suite, pour
-- que tomber et se relever soient immediatement lisibles.
local function onStatusChanged(player: Player, status: string)
	local entry: CombatService.Entry? = nil
	for _, candidate in roundEntries do
		if candidate.player == player then
			entry = candidate
			break
		end
	end
	if entry == nil then
		return
	end

	if status == "downed" then
		tell(player, "À TERRE", "Un coéquipier peut te relever", zoneLineFor(entry), "downed")
	elseif status == "out" then
		tell(player, "Éliminé", "", zoneLineFor(entry), "out")
	else
		tell(player, "Relevé !", "", zoneLineFor(entry), "")
	end

	print(string.format("[Arena] %s : %s", player.Name, status))
end

local function loop()
	while true do
		local players = Players:GetPlayers()

		if #players < PLAYERS_NEEDED then
			tellAll(
				"En attente d'un deuxieme joueur",
				string.format("%d / %d joueurs", #players, PLAYERS_NEEDED)
			)
			task.wait(1)
			continue
		end

		runMatch({ players[1], players[2] })
		CombatService.setRoster({})
		DownedService.setRoster({})
		roundEntries = {}
		task.wait(Config.prototype.secondsBetweenMatches)
	end
end

function MatchService.start()
	local resolved, isTestMap = MapService.resolve(Config)
	map = resolved

	DownedService.onStatusChanged(onStatusChanged)

	if isTestMap then
		print("[Arena] Arene de test : deux lignes de points de depart, pas de couverture.")
	end

	task.spawn(loop)
end

return MatchService
