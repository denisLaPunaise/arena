--!strict
--[[
	MatchService — la boucle d'une partie du prototype.

	Attendre deux joueurs, distribuer les deux classes, jouer les manches
	jusqu'a ce qu'une equipe atteigne le compte, annoncer, recommencer.

	Le score lui-meme est calcule par MatchState, qui est pur et teste hors de
	Studio. Ici on ne fait que ce qui demande Roblox : faire apparaitre les
	personnages, attendre une mort, parler aux clients.

	Ce qui n'est PAS la, et c'est voulu : pas de bans, pas de tirage au sort,
	pas d'arbre, pas d'equipement, pas de zone qui se referme, pas de fenetre
	d'agonie. Le prototype repond a une seule question : ce duel est-il amusant.
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
local MapService = require(script.Parent:WaitForChild("MapService"))

local TEAMS = { "A", "B" }
local PLAYERS_NEEDED = 2

local map: Instance? = nil
local swapClasses = false

local function className(classId: string): string
	local class = Classes.byId[classId]
	return if class then class.name else classId
end

local function tell(player: Player, title: string, status: string)
	hudRemote:FireClient(player, { title = title, status = status })
end

local function tellAll(title: string, status: string)
	for _, player in Players:GetPlayers() do
		tell(player, title, status)
	end
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	if character == nil then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
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

-- Renvoie l'equipe gagnante, ou nil si la manche n'a pas de vainqueur (un
-- joueur est parti, ou les deux sont tombes en meme temps).
local function waitForRoundEnd(entries: { CombatService.Entry }): string?
	while true do
		task.wait(0.1)

		local standing: { CombatService.Entry } = {}
		local downed = 0

		for _, entry in entries do
			if entry.player.Parent == nil then
				return nil
			end

			local humanoid = humanoidOf(entry.player)
			if humanoid == nil or humanoid.Health <= 0 then
				downed += 1
			else
				table.insert(standing, entry)
			end
		end

		if downed > 0 then
			if #standing == 1 then
				return standing[1].team
			end
			return nil
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
	CombatService.setRoster(entries)

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
		for index, entry in entries do
			spawnEntry(entry, index)
		end

		countdown(entries, state)
		CombatService.setActive(true)

		local winner = waitForRoundEnd(entries)
		CombatService.setActive(false)

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
		task.wait(Config.prototype.secondsBetweenMatches)
	end
end

function MatchService.start()
	local resolved, isTestMap = MapService.resolve(Config)
	map = resolved

	if isTestMap then
		print("[Arena] Arene de test : deux lignes de points de depart, pas de couverture.")
	end

	task.spawn(loop)
end

return MatchService
