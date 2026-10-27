--!strict
--[[
	MatchService — la boucle d'une partie du prototype.

	Attendre assez de monde, composer deux equipes, distribuer les classes,
	jouer les manches jusqu'a ce qu'une equipe atteigne le compte, annoncer,
	recommencer.

	QUI JOUE N'EST PLUS DECIDE ICI. Le format, les places et les equipes sont
	calcules par Seating, qui est pur et teste hors de Studio ; cette boucle ne
	fait que traduire ses identifiants en joueurs. Avant ca, elle asseyait les
	DEUX PREMIERS joueurs arrives, en dur, et un troisieme n'avait aucune
	equipe.

	UN DEPART NE TUE PLUS LA PARTIE. Le partant est retire de la liste a chaque
	tour de boucle ; la manche se resout toute seule puisque Downed compte les
	equipes qui tiennent encore. Si un camp entier s'en va, la partie s'arrete
	et NE PAIE PERSONNE : voir le commentaire au-dessus de awardMatch.

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
local Seating = require(Arena:WaitForChild("Seating"))

local Remotes = Arena:WaitForChild("Remotes")
local hudRemote = Remotes:WaitForChild("Hud") :: RemoteEvent
local lobbyRemote = Remotes:WaitForChild("Lobby") :: RemoteEvent

local CombatService = require(script.Parent:WaitForChild("CombatService"))
local AbilityService = require(script.Parent:WaitForChild("AbilityService"))
local DownedService = require(script.Parent:WaitForChild("DownedService"))
local DraftService = require(script.Parent:WaitForChild("DraftService"))
local EffectsService = require(script.Parent:WaitForChild("EffectsService"))
local LoadoutService = require(script.Parent:WaitForChild("LoadoutService"))
local ProgressService = require(script.Parent:WaitForChild("ProgressService"))
local MapService = require(script.Parent:WaitForChild("MapService"))
local SandboxService = require(script.Parent:WaitForChild("SandboxService"))
local SkillTreeService = require(script.Parent:WaitForChild("SkillTreeService"))
local Venue = require(script.Parent:WaitForChild("Venue"))
local ZoneService = require(script.Parent:WaitForChild("ZoneService"))

local map: Instance? = nil
local swapClasses = false
local roundEntries: { CombatService.Entry } = {}

-- Combien de parties chacun a passees sur le banc. C'est tout ce que la
-- rotation du banc a besoin de retenir, et ca meurt avec le serveur : un joueur
-- qui revient demain repart a zero. C'est voulu — ce compteur sert a repartir
-- une soiree, pas a porter une progression de compte.
local benched: { [Player]: number } = {}

-- Ceux qui regardent la partie en cours parce que le format etait plein. Ils
-- recoivent le meme rafraichissement que les joueurs, sinon leur ecran garde
-- l'annonce d'attente pendant toute la partie et ils croient le jeu casse.
local watching: { Player } = {}

-- Le format de la partie en cours ("2v2"), pour les annonces. Vide hors partie.
local currentFormat = ""

-- Le camp que chacun a demande, en partie privee. Nil veut dire « peu
-- importe », et ce n'est jamais qu'un voeu : Seating garde les camps egaux.
local wantedSide: { [Player]: string } = {}

-- LE SALON : le format et la facon de composer les camps, regles par les
-- joueurs en partie privee. Rien d'autre n'est reglable en jeu.
local lobby: Seating.Lobby = {
	formatId = Config.seating.defaultFormat,
	teamMode = Config.seating.defaultTeamMode,
}

-- Le tirage des camps. Un seul generateur pour toute la vie du serveur : en
-- creer un par partie le re-sèmerait sur l'horloge, et deux parties lancees
-- dans la meme seconde composeraient les memes camps.
local shuffle = Random.new()

-- L'annonce d'un changement de reglage, et jusqu'a quand elle tient. Le
-- rafraichissement du salon part toutes les secondes et ecraserait le message
-- aussitot : il faut donc qu'il le PORTE, au lieu de le poser une fois.
local notice = ""
local noticeUntil = 0

-- Qui a le salon ouvert. L'etat ne part qu'a ceux qui le regardent : un
-- panneau ferme n'a rien a rafraichir, et le reste du temps ce remote ne coute
-- rien du tout.
local watchingLobby: { [Player]: boolean } = {}

local function rng(n: number): number
	return shuffle:NextInteger(1, n)
end

-- EN PARTIE PRIVEE SEULEMENT. Le serveur tranche, pas le client : en partie
-- classee, deux amis qui demandent le meme camp empileraient un cote, et le
-- classement de tous les autres paierait l'addition. Un client modifie qui
-- envoie quand meme sa demande se fait donc ignorer ici.
local function lobbyAllowed(): boolean
	return Config.seating.lobbyInPrivate and Venue.isPrivate()
end

-- Les reglages en vigueur. En public, ce sont ceux de Config et pas ceux que
-- quelqu'un aurait reussi a poser : c'est la deuxieme barriere, apres le refus
-- de la demande elle-meme.
local function lobbyNow(): Seating.Lobby
	if not lobbyAllowed() then
		return {
			formatId = Config.seating.defaultFormat,
			teamMode = Config.seating.defaultTeamMode,
		}
	end
	return lobby
end

-- Le libelle d'un format pour l'affichage. « auto » n'est pas un format, donc
-- il se dit en toutes lettres.
local function formatLabel(id: string): string
	if id == Seating.AUTO then
		return "auto"
	end
	return id
end

local function teamModeLabel(mode: string): string
	if mode == Seating.RANDOM then
		return "au hasard"
	end
	return "chacun choisit"
end

-- Combien de joueurs il faut MAINTENANT. Avec un format impose, c'est le sien
-- et pas le minimum du jeu : sinon l'ecran annonce « 2 / 2 joueurs » alors que
-- le 4v4 demande en attend huit, et personne ne comprend pourquoi ca ne part
-- pas.
local function neededNow(): number
	local current = lobbyNow()
	if current.formatId ~= Seating.AUTO then
		local format = Seating.formatById(Config, current.formatId)
		if format ~= nil then
			return Seating.seatsFor(Config, format)
		end
	end
	return Seating.playersNeeded(Config)
end

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

-- Les deux moments que la boucle de partie fait sonner. Ils sont nommes ici
-- plutot qu'ecrits dans l'appel, parce qu'un nom de son qui ne correspond a
-- rien dans `Config.sounds.events` est un SILENCE, sans la moindre erreur :
-- `tests/specs/sound.luau` verifie que ces deux-la existent.
local ROUND_START_SOUND = "roundStart"
local ROUND_END_SOUND = "roundEnd"

-- `cue` NOMME UN SON, une seule fois. Cette annonce part quatre fois par
-- seconde pour tenir l'affichage a jour : un son attache a l'annonce elle-meme
-- sonnerait quatre fois par seconde. Il n'est donc rempli que par les trois
-- appels qui marquent un moment — le debut d'une manche, sa fin, la fin de la
-- partie — et le rafraichissement le laisse vide.
local function tell(
	player: Player,
	title: string,
	status: string,
	zone: string?,
	alert: string?,
	cue: string?
)
	hudRemote:FireClient(player, {
		title = title,
		status = status,
		zone = zone or "",
		alert = alert or "",
		tree = treeLineFor(player),
		cue = cue,
	})
end

-- La ligne du salon. Vide hors partie privee : en classe personne ne regle
-- quoi que ce soit, donc rien a l'ecran ne doit le suggerer.
local function lobbyLineFor(player: Player): string
	if not lobbyAllowed() then
		return ""
	end

	local current = lobbyNow()
	local mine = if current.teamMode == Seating.RANDOM
		then "tirage au sort"
		else "ton camp : " .. (wantedSide[player] or "auto")

	return string.format(
		"Salon : %s  ·  %s  ·  %s pour régler",
		formatLabel(current.formatId),
		mine,
		Config.seating.lobbyKey
	)
end

local function tellAll(title: string, status: string)
	for _, player in Players:GetPlayers() do
		tell(player, title, status)
	end
end

-- L'etat du salon, tel que ce joueur doit le voir.
local function pushLobby(player: Player)
	local current = lobbyNow()
	lobbyRemote:FireClient(player, {
		kind = "lobby",
		allowed = lobbyAllowed(),
		formatId = current.formatId,
		teamMode = current.teamMode,
		side = wantedSide[player] or Seating.AUTO,
		present = #Players:GetPlayers(),
		needed = neededNow(),
		-- Les formats possibles viennent du serveur : le panneau ne les
		-- invente pas, et une entree ajoutee a Config.formats apparait toute
		-- seule a l'ecran.
		formats = Seating.formatIds(Config),
	})
end

local function pushLobbyToWatchers()
	for player in watchingLobby do
		if player.Parent ~= nil then
			pushLobby(player)
		end
	end
end

-- L'annonce hors partie. Meme titre pour tout le monde, mais la ligne du bas
-- est PERSONNELLE : le camp demande l'est. Elle voyage dans le champ `zone`,
-- qui ne sert a rien tant qu'aucune manche ne tourne — un champ de plus dans le
-- protocole pour une ligne de texte serait du gaspillage.
local function tellLobby(title: string, status: string)
	local showing = if os.clock() < noticeUntil then notice else title
	for _, player in Players:GetPlayers() do
		tell(player, showing, status, lobbyLineFor(player))
	end
	pushLobbyToWatchers()
end

-- Un changement de reglage, dit a tout le monde. Il remplace le titre du salon
-- le temps qu'on le lise, et le rafraichissement le reconduit tout seul.
local function announce(text: string)
	notice = text
	noticeUntil = os.clock() + Config.seating.noticeSeconds
	print("[Arena] " .. text)
	pushLobbyToWatchers()
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

-- Les identifiants du plan de placement sont ceux de Downed et de Draft :
-- l'UserId en texte. La traduction se fait ici et nulle part ailleurs.
local function idOf(player: Player): string
	return tostring(player.UserId)
end

local function candidatesFor(players: { Player }): { Seating.Candidate }
	local candidates: { Seating.Candidate } = {}
	for _, player in players do
		table.insert(candidates, {
			id = idOf(player),
			satOut = benched[player] or 0,
			side = if lobbyAllowed() then wantedSide[player] else nil,
		})
	end
	return candidates
end

-- Retire de la liste ceux qui ont quitte, et renvoie combien. CombatService et
-- DownedService ont chacun leur PlayerRemoving et se nettoient tout seuls ;
-- cette liste-ci est celle qui sert a parler aux joueurs, a les faire
-- apparaitre et a payer la fin de partie, donc elle doit suivre.
local function dropLeavers(entries: { CombatService.Entry })
	for index = #entries, 1, -1 do
		local entry = entries[index]
		if entry.player.Parent == nil then
			table.remove(entries, index)
			print(string.format("[Arena] %s a quitte la partie.", entry.player.Name))
		end
	end
end

-- Vrai quand un camp n'a plus personne du tout, donc vrai aussi sur une liste
-- vide : aucun camp n'y est present.
local function aTeamIsEmpty(entries: { CombatService.Entry }): boolean
	local present: { [string]: boolean } = {}
	for _, entry in entries do
		present[entry.team] = true
	end

	for _, team in Seating.teamNames(Config) do
		if not present[team] then
			return true
		end
	end

	return false
end

-- `seat` est le rang DANS SON EQUIPE, pas dans la liste de la partie : a 2v2,
-- les deux joueurs de l'equipe A sont les entrees 1 et 3, et prendre leur rang
-- global ferait apparaitre un coequipier a l'autre bout de sa ligne de depart.
local function spawnEntry(entry: CombatService.Entry, seat: number)
	local currentMap = map
	if currentMap == nil then
		return
	end

	local positions = MapService.spawnPositions(currentMap, Config, entry.team)

	-- Le contrat de nommage demande cinq points par equipe, donc de quoi tenir
	-- un 4v4. Une map qui en a moins empile deux joueurs sur le meme point, et
	-- ca ne se voit qu'en jouant a plusieurs : la personne qui a construit la
	-- map doit l'apprendre de la console, pas d'un bug.
	if seat > #positions then
		warn(
			string.format(
				"[Arena] L'equipe %s a %d joueurs pour %d point(s) de depart.",
				entry.team,
				seat,
				#positions
			)
		)
	end

	local position = positions[((seat - 1) % #positions) + 1]

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

-- Renvoie l'equipe gagnante, ou nil quand la manche n'a plus de vainqueur
-- possible : plus personne en piste, ou deux equipes tombees dans le meme
-- instant.
--
-- Ce n'est plus l'etat des Humanoid qui decide : un joueur a terre est encore
-- a un PV et son equipe n'est pas eliminee tant que sa fenetre court.
local function waitForRoundEnd(entries: { CombatService.Entry }, state: MatchState.State): string?
	local lastHud = 0

	while true do
		task.wait(0.1)

		-- UN DEPART N'ANNULE PLUS LA PARTIE. A deux joueurs, abandonner etait la
		-- seule reponse possible ; a six, une coupure de reseau faisait perdre
		-- leur serie aux cinq autres. Le partant est retire des rosters par les
		-- services eux-memes, donc la fin de manche se resout d'elle-meme :
		-- Downed.roundIsOver compte les equipes qui tiennent encore, et une
		-- equipe vide ne tient pas.
		dropLeavers(entries)

		if #entries == 0 then
			return nil
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

			-- Et le banc. Sans cette boucle, leur ecran garde l'annonce
			-- d'attente pendant toute la partie et ils croient le jeu casse.
			for _, viewer in watching do
				if viewer.Parent ~= nil then
					tell(
						viewer,
						"Spectateur",
						string.format("%s en cours  ·  tu joues la partie suivante", currentFormat)
					)
				end
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
		tell(entry.player, "Combat !", statusFor(entry, state), nil, nil, ROUND_START_SOUND)
	end
end

-- Qui joue dans quelle equipe. On en a besoin AVANT le tirage, puisque les
-- bans se votent par equipe.
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
		local team = teams[player]
		if team == nil then
			-- Ne peut pas arriver : le plan de placement donne une equipe a
			-- chaque joueur assis. Mais un joueur sans equipe ne serait jamais
			-- compte comme elimine et la manche ne finirait plus jamais, donc on
			-- refuse de l'asseoir plutot que d'esperer.
			warn(string.format("[Arena] %s n'a pas d'equipe, il ne joue pas.", player.Name))
			continue
		end

		local classId = if drawn then drawn[player] else nil
		if classId == nil or Config.classStats[classId] == nil then
			classId = fallbackClass(index)
		end

		table.insert(entries, {
			player = player,
			team = team,
			classId = classId,
			-- Les statistiques de la classe nue. L'arbre les remplace avant
			-- chaque apparition, par SkillTreeService.refreshStats.
			stats = Config.classStats[classId],
		})
	end

	return entries
end

local function runMatch(players: { Player }, teams: { [Player]: string }, formatId: string)
	currentFormat = formatId

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

	print(string.format("[Arena] Partie en %s.", formatId))

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
		-- Un depart pendant la phase de depense ou entre deux manches tombe
		-- hors de waitForRoundEnd : sans ce passage, on ferait apparaitre le
		-- personnage d'un joueur qui n'est plus la.
		dropLeavers(entries)
		if aTeamIsEmpty(entries) then
			break
		end

		DownedService.resetRound()
		CombatService.clearTemporary()

		-- On depense AVANT d'apparaitre : les statistiques achetees sont celles
		-- du personnage qui se leve, et aucun achat ne soigne en pleine manche.
		spendPhase(entries, state)
		SkillTreeService.refreshStats(entries)
		-- L'equipement est la DERNIERE couche, apres l'arbre : c'est ce qui fait
		-- que l'armure lourde retire un pourcentage de la vitesse que l'arbre a
		-- deja donnee, et pas l'inverse.
		LoadoutService.refreshStats(entries)

		local seats: { [string]: number } = {}
		for _, entry in entries do
			local seat = (seats[entry.team] or 0) + 1
			seats[entry.team] = seat
			spawnEntry(entry, seat)
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
			SkillTreeService.endMatch()
			CombatService.clearTemporary()
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

			tell(entry.player, verdict, line, nil, nil, ROUND_END_SOUND)
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

	-- UN CAMP VIDE NE PAIE RIEN, et c'est deliberement severe. Deux raisons qui
	-- tiennent ensemble : le profil de celui qui part est deja ecrit et ferme
	-- par le PlayerRemoving de ProgressService, donc il est impossible de lui
	-- retirer quoi que ce soit ; et un classement qui crediterait le camp
	-- restant se farmerait a deux comptes, l'un quittant pour l'autre. Personne
	-- n'a rien gagne ici, donc personne n'est paye.
	dropLeavers(entries)
	if aTeamIsEmpty(entries) then
		tellAll("Partie interrompue", "Une équipe n'a plus de joueurs")
		print("[Arena] Partie non comptee : une equipe n'avait plus de joueurs.")
		SkillTreeService.endMatch()
		CombatService.clearTemporary()
		return
	end

	local winner = MatchState.winner(state)
	for _, entry in entries do
		local verdict = if entry.team == winner then "Partie gagnee" else "Partie perdue"
		tell(entry.player, verdict, statusFor(entry, state), nil, nil, ROUND_END_SOUND)
	end

	print(
		string.format(
			"[Arena] Partie remportee par l'equipe %s, %s.",
			tostring(winner),
			MatchState.scoreLine(state, "A")
		)
	)

	-- Les pieces et le classement, une seule fois, a la fin de la partie. Pas
	-- a la fin d'une manche : une serie se joue en entier, et payer la manche
	-- recompenserait celui qui abandonne apres en avoir gagne une.
	ProgressService.awardMatch(entries, winner, state.scores)

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
		local plan = Seating.plan(Config, candidatesFor(players), lobbyNow(), rng)

		if plan == nil then
			-- SEUL : le bac a sable prend la place de l'attente. Il ne rend la
			-- main que quand un deuxieme joueur arrive, et c'est tout ce que
			-- cette boucle a besoin de savoir de lui — elle reprend alors son
			-- cours exactement ici.
			local ok, why = SandboxService.availability()
			if ok then
				SandboxService.run(map :: Instance, players[1])
				CombatService.setRoster({})
				DownedService.setRoster({})
				roundEntries = {}
				continue
			end

			local note = Venue.describe()
			tellLobby(
				"En attente de joueurs",
				string.format(
					"%d / %d joueurs%s%s",
					#players,
					neededNow(),
					if note ~= "" then "  ·  " .. note else "",
					if why ~= "" then "  ·  bac à sable : " .. why else ""
				)
			)
			task.wait(Config.seating.waitRefreshSeconds)
			continue
		end

		-- Le plan parle en identifiants, parce qu'il est pur. On revient aux
		-- joueurs ici, et c'est le seul endroit qui fait les deux traductions.
		local byId: { [string]: Player } = {}
		for _, player in players do
			byId[idOf(player)] = player
		end

		local seated: { Player } = {}
		local teams: { [Player]: string } = {}
		for _, id in plan.seated do
			local player = byId[id]
			if player ~= nil then
				table.insert(seated, player)
				teams[player] = plan.teams[id]
			end
		end

		watching = {}
		for _, id in plan.waiting do
			local player = byId[id]
			if player ~= nil then
				table.insert(watching, player)
			end
		end

		-- Le banc avance d'un cran pour ceux qui attendent et se remet a zero
		-- pour ceux qui jouent. C'est ce qui fait tourner les places a cinq
		-- joueurs : sans ces deux boucles, le cinquieme arrive regarde les
		-- autres jouer toute la soiree.
		for _, player in seated do
			benched[player] = 0
		end
		for _, player in watching do
			benched[player] = (benched[player] or 0) + 1
		end

		if #watching > 0 then
			print(string.format("[Arena] %s : %d joueur(s) sur le banc.", plan.formatId, #watching))
		end

		runMatch(seated, teams, plan.formatId)

		watching = {}
		currentFormat = ""
		CombatService.setRoster({})
		DownedService.setRoster({})
		roundEntries = {}

		-- L'entre-deux-parties n'est pas un temps mort : c'est LE moment ou on
		-- arrange les equipes en partie privee. L'annonce y tourne donc au lieu
		-- d'attendre en silence, et chacun voit le camp qu'il a demande.
		local note = Venue.describe()
		local deadline = os.clock() + Config.prototype.secondsBetweenMatches
		while os.clock() < deadline do
			tellLobby(
				"Partie suivante",
				string.format(
					"dans %d s%s",
					math.ceil(deadline - os.clock()),
					if note ~= "" then "  ·  " .. note else ""
				)
			)
			task.wait(Config.seating.waitRefreshSeconds)
		end
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

	-- Sans ca, le compteur du banc garde une reference sur chaque joueur qui a
	-- traverse le serveur, et celui qui revient retrouve son rang d'il y a deux
	-- heures.
	Players.PlayerRemoving:Connect(function(player)
		benched[player] = nil
		wantedSide[player] = nil
		watchingLobby[player] = nil
	end)

	-- LE SALON. Trois reglages sur un seul remote, parce qu'ils vivent au meme
	-- moment et au meme endroit de l'ecran : le format, la facon de composer
	-- les camps, et le camp qu'on demande. Tout ce qui n'est pas reconnu est
	-- jete, et la demande entiere est ignoree hors partie privee — c'est le
	-- serveur qui tranche, pas le client.
	--
	-- N'IMPORTE QUI PEUT REGLER, et le changement s'annonce. Pas de « chef de
	-- partie » : entre amis dans leur propre serveur, un systeme d'hote serait
	-- de la complexite pour rien, et quelqu'un qui embete les autres est un
	-- probleme d'amis, pas de code.
	lobbyRemote.OnServerEvent:Connect(function(player: Player, payload: any)
		if typeof(payload) ~= "table" then
			return
		end

		-- Ouvrir, fermer et demander l'etat repondent TOUJOURS, meme en partie
		-- classee : la reponse dit alors `allowed = false`, et le panneau sait
		-- qu'il ne doit pas s'ouvrir. Sans reponse, il ne saurait pas faire la
		-- difference entre « interdit » et « le serveur n'a pas encore parle ».
		if payload.query == true then
			pushLobby(player)
			return
		end
		if payload.open == true then
			watchingLobby[player] = lobbyAllowed() or nil
			pushLobby(player)
			return
		end
		if payload.close == true then
			watchingLobby[player] = nil
			return
		end

		-- Tout ce qui MODIFIE un reglage s'arrete ici en partie classee.
		if not lobbyAllowed() then
			return
		end

		-- LE CAMP. Nil ramene a « auto ».
		if payload.side ~= nil or payload.clearSide == true then
			local asked = payload.side
			if asked == nil or asked == Seating.AUTO then
				wantedSide[player] = nil
			elseif typeof(asked) == "string" then
				for _, team in Seating.teamNames(Config) do
					if asked == team then
						wantedSide[player] = asked
						break
					end
				end
			end
			pushLobby(player)
		end

		-- LE FORMAT. « auto » est accepte, et c'est le seul nom qui ne soit pas
		-- celui d'un format.
		if typeof(payload.formatId) == "string" then
			local asked = payload.formatId
			if asked == Seating.AUTO or Seating.formatById(Config, asked) ~= nil then
				if lobby.formatId ~= asked then
					lobby.formatId = asked
					announce(
						string.format("%s a choisi le format : %s", player.Name, formatLabel(asked))
					)
				end
			end
		end

		-- LA FACON DE COMPOSER LES CAMPS.
		if typeof(payload.teamMode) == "string" then
			local asked = payload.teamMode
			if asked == Seating.CHOSEN or asked == Seating.RANDOM then
				if lobby.teamMode ~= asked then
					lobby.teamMode = asked
					announce(
						string.format(
							"%s a choisi les équipes : %s",
							player.Name,
							teamModeLabel(asked)
						)
					)
				end
			end
		end
	end)

	-- Un achat recalcule les statistiques tout de suite, meme si elles ne seront
	-- posees sur le personnage qu'a la prochaine apparition : l'interface lit le
	-- meme etat que le combat, et ne peut donc pas en mentir.
	SkillTreeService.onChanged(function()
		SkillTreeService.refreshStats(roundEntries)
		LoadoutService.refreshStats(roundEntries)
	end)

	if isTestMap then
		print("[Arena] Arene de test : deux lignes de points de depart, pas de couverture.")
	end

	task.spawn(loop)
end

return MatchService
