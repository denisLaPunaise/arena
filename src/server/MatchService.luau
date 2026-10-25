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

	La zone et l'agonie sont arrivees a l'etape 3, l'arbre de competences a
	l'etape 4. Les trois se coupent depuis Config, pour pouvoir jouer une manche
	avec et une manche sans et comparer.

	LA FORME D'UNE MANCHE, depuis l'arbre :

	    1. phase de depense   on choisit sa branche, on monte ses paliers
	    2. apparition         les statistiques achetees sont posees ICI
	    3. decompte           tout le monde est fige
	    4. combat             la zone part, les services sont actifs
	    5. fin de manche      un point a chacun, deux a qui enchaine trois pertes

	L'ordre de 1 et 2 n'est pas un detail : depenser AVANT d'apparaitre est ce
	qui empeche un achat de PV maximum d'etre un soin complet au milieu d'une
	manche. Voir Config.skillTree.spendingDuringRound.
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
local AbilityService = require(script.Parent:WaitForChild("AbilityService"))
local DownedService = require(script.Parent:WaitForChild("DownedService"))
local DraftService = require(script.Parent:WaitForChild("DraftService"))
local EffectsService = require(script.Parent:WaitForChild("EffectsService"))
local MapService = require(script.Parent:WaitForChild("MapService"))
local SkillTreeService = require(script.Parent:WaitForChild("SkillTreeService"))
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

-- La ligne d'arbre affichee en permanence : combien de points dorment, et a
-- quel palier on en est. Un point non depense doit demanger.
local function treeLineFor(player: Player): string
	local state = SkillTreeService.stateOf(player)
	if state == nil then
		return ""
	end

	local points = state.pointsEarned - state.pointsSpent
	local tierText = if state.branchId == nil
		then "aucune branche"
		else string.format("palier %d / %d", state.tier, Config.skillTree.tiers)

	if points <= 0 then
		return tierText
	end

	local plural = if points > 1 then "points" else "point"
	return string.format("%s  ·  %d %s à dépenser  [T]", tierText, points, plural)
end

local function tell(player: Player, title: string, status: string, zone: string?, alert: string?)
	hudRemote:FireClient(player, {
		title = title,
		status = status,
		zone = zone or "",
		alert = alert or "",
		tree = treeLineFor(player),
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

-- La phase de depense, entre deux manches. Elle est sautee quand personne n'a
-- rien a decider, et se coupe des que tout le monde a appuye sur « Prêt » :
-- quinze secondes de silence entre deux manches tuent le rythme d'une serie.
local function spendPhase(entries: { CombatService.Entry }, state: MatchState.State)
	if not SkillTreeService.isEnabled() or not SkillTreeService.anyoneCanSpend() then
		return
	end

	local seconds = Config.skillTree.spendWindowSeconds
	SkillTreeService.openSpending(seconds)

	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		for _, entry in entries do
			if entry.player.Parent == nil then
				SkillTreeService.closeSpending()
				return
			end
		end

		if SkillTreeService.everyoneDone() then
			break
		end

		local left = math.max(math.ceil(deadline - os.clock()), 0)
		for _, entry in entries do
			tell(
				entry.player,
				"Arbre de compétences",
				string.format("Manche %d dans %d s", MatchState.roundNumber(state), left)
			)
		end

		task.wait(0.25)
	end

	SkillTreeService.closeSpending()
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

-- Qui joue dans quelle equipe. On en a besoin AVANT le tirage, puisque les
-- bans se votent par equipe.
local function teamsFor(players: { Player }): { [Player]: string }
	local teams: { [Player]: string } = {}
	for index, player in players do
		teams[player] = TEAMS[index]
	end
	return teams
end

-- La classe du prototype, utilisee quand le tirage est coupe ou qu'il n'a pas
-- pu servir tout le monde. Mieux vaut un Vampire de secours qu'un joueur sans
-- classe, qui n'aurait ni PV ni attaque et ne comprendrait pas pourquoi.
local function fallbackClass(index: number): string
	local classes = Config.prototype.classes
	local classIndex = index
	if swapClasses then
		classIndex = (#classes + 1) - index
	end
	return classes[((classIndex - 1) % #classes) + 1]
end

local function buildEntries(
	players: { Player },
	teams: { [Player]: string },
	drawn: { [Player]: string }?
): { CombatService.Entry }
	local entries: { CombatService.Entry } = {}

	for index, player in players do
		local classId = if drawn then drawn[player] else nil
		if classId == nil or Config.classStats[classId] == nil then
			classId = fallbackClass(index)
		end

		table.insert(entries, {
			player = player,
			team = teams[player] or TEAMS[index],
			classId = classId,
			-- Les statistiques de la classe nue. L'arbre les remplace avant
			-- chaque apparition, par SkillTreeService.refreshStats.
			stats = Config.classStats[classId],
		})
	end

	return entries
end

local function runMatch(players: { Player })
	local teams = teamsFor(players)

	-- Les bans, puis le tirage. Coupe, on retombe sur les deux classes du
	-- prototype : c'est l'interrupteur de comparaison qui permet de rejuger le
	-- duel nu sans la phase de bans par-dessus.
	local drawn: { [Player]: string }? = nil
	if Config.draft.enabled then
		tellAll("PHASE DE BANS", "Votez pour la classe à écarter")
		drawn = DraftService.run(players, teams)
	end

	local entries = buildEntries(players, teams, drawn)
	roundEntries = entries
	CombatService.setRoster(entries)
	DownedService.setRoster(entries)

	-- L'arbre est remis a zero a chaque partie. C'est le troisieme principe du
	-- projet, et c'est cette ligne qui le tient.
	SkillTreeService.beginMatch(entries)

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
		CombatService.clearTemporary()

		-- On depense AVANT d'apparaitre : les statistiques achetees sont celles
		-- du personnage qui se leve, et aucun achat ne soigne en pleine manche.
		spendPhase(entries, state)
		SkillTreeService.refreshStats(entries)

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

		-- Les points de fin de manche, point de revanche compris. Un point qui
		-- arrive sans qu'on le dise n'est pas un point : chacun l'apprend ici.
		local granted = SkillTreeService.grantRoundEnd(entries, winner)

		for _, entry in entries do
			local verdict = if entry.team == winner then "Manche gagnée" else "Manche perdue"
			local award = granted[entry.player]
			local line = statusFor(entry, state)

			if award ~= nil and award.granted > 0 then
				if award.comeback then
					line = string.format(
						"%s  ·  +%d points (dont le point de revanche)",
						line,
						award.granted
					)
				else
					local plural = if award.granted > 1 then "points" else "point"
					line = string.format("%s  ·  +%d %s d'arbre", line, award.granted, plural)
				end
			end

			tell(entry.player, verdict, line)
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

	SkillTreeService.endMatch()
	CombatService.clearTemporary()

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

	-- Tomber et se relever sont les deux moments ou personne ne lit du texte :
	-- un eclair au bon endroit porte plus loin qu'une ligne de HUD.
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		local point = root.Position + Vector3.new(0, 1.5, 0)
		if status == "standing" then
			EffectsService.revive(point, player)
		else
			EffectsService.down(point, player)
		end
	end

	if status ~= "standing" then
		AbilityService.onDowned(player)
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

	-- Le Spectre traverse les couverts, et seuls le contrat de nommage et cette
	-- ligne savent lesquels le sont : les maps ne sont pas dans Git, donc rien
	-- d'autre ne peut les designer.
	local cover = resolved:FindFirstChild(Config.mapContract.coverFolder)
	if cover ~= nil then
		AbilityService.markCover(cover)
	end

	DownedService.onStatusChanged(onStatusChanged)

	-- Un achat recalcule les statistiques tout de suite, meme si elles ne seront
	-- posees sur le personnage qu'a la prochaine apparition : l'interface lit le
	-- meme etat que le combat, et ne peut donc pas en mentir.
	SkillTreeService.onChanged(function()
		SkillTreeService.refreshStats(roundEntries)
	end)

	if isTestMap then
		print("[Arena] Arene de test : deux lignes de points de depart, pas de couverture.")
	end

	task.spawn(loop)
end

return MatchService
