--!strict
--[[
	ProgressService — les pieces, la collection, les fragments et le classement.

	C'est le seul endroit du jeu qui ECRIT quelque chose de durable. Tout le
	reste est remis a zero a chaque partie, l'arbre de competences compris :
	c'est le troisieme principe du projet.

	LA REGLE QUI PROTEGE LES SAUVEGARDES, et elle est plus importante que tout
	le reste de ce fichier : SI LA LECTURE A ECHOUE, ON N'ECRIT PAS. Un profil
	qu'on n'a pas su lire n'est pas un profil vide — c'est un profil inconnu, et
	l'ecraser par des valeurs neuves efface une collection entiere.

	Dans Studio, les DataStore ne repondent pas tant que « Enable Studio Access
	to API Services » n'est pas coche. Le service tourne quand meme, en memoire,
	et le dit dans la console. C'est voulu : un test local ne doit pas dependre
	d'un reglage de Studio, et il ne doit pas non plus faire croire que ses
	pieces sont gardees.

	CE QUI N'EST PAS ENCORE LA, et qui compte : la vente de pieces en Robux.
	Tant qu'elle n'existe pas, les pieces ne s'obtiennent qu'en jouant, donc le
	tirage n'est pas un objet aleatoire payant et la politique de Roblox ne
	s'applique pas encore. L'ecran des cotes est deja conforme, pour qu'elle
	s'applique sans rien changer le jour ou la vente arrive. Voir
	docs/EQUILIBRAGE.md.
]]

local ProgressService = {}

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Config = require(Arena:WaitForChild("Config"))
local Draws = require(Arena:WaitForChild("Draws"))
local Economy = require(Arena:WaitForChild("Economy"))
local Loadout = require(Arena:WaitForChild("Loadout"))
local Rating = require(Arena:WaitForChild("Rating"))

local Venue = require(script.Parent:WaitForChild("Venue"))

local Remotes = Arena:WaitForChild("Remotes")
local progressRemote = Remotes:WaitForChild("Progress") :: RemoteEvent

export type Profile = {
	coins: number,
	fragments: number,
	owned: { [string]: boolean },
	pullsSinceNew: number,
	rating: number,
	matchesPlayed: number,
	starterDone: boolean,
	-- Faux quand la lecture a echoue. Un profil non charge ne se sauvegarde
	-- JAMAIS : voir l'en-tete.
	loaded: boolean,
}

export type Entry = {
	player: Player,
	team: string,
	classId: string,
}

local STORE_NAME = "ArenaProfiles_v1"
local LOAD_ATTEMPTS = 3

local profiles: { [Player]: Profile } = {}
-- Les lectures en cours. Deux appels a profileOf pendant la meme lecture
-- lanceraient deux lectures, et la seconde ecraserait la premiere : vu dans
-- Studio, ou l'initialisation et PlayerAdded tombent dans la meme seconde.
local loading: { [Player]: boolean } = {}
local store: DataStore? = nil
local storeWorks = true

--------------------------------------------------------------------------------
-- LE PROFIL
--------------------------------------------------------------------------------

local function blank(): Profile
	return {
		coins = 0,
		fragments = 0,
		owned = {},
		pullsSinceNew = 0,
		rating = Config.elo.startingRating,
		matchesPlayed = 0,
		starterDone = false,
		loaded = true,
	}
end

-- Remet un profil lu dans la forme attendue. Une sauvegarde ecrite par une
-- version precedente peut manquer un champ, et il vaut mieux une valeur par
-- defaut qu'une erreur qui bloque la connexion du joueur.
local function normalise(raw: any): Profile
	local profile = blank()
	if typeof(raw) ~= "table" then
		return profile
	end

	profile.coins = if typeof(raw.coins) == "number" then raw.coins else 0
	profile.fragments = if typeof(raw.fragments) == "number" then raw.fragments else 0
	profile.pullsSinceNew = if typeof(raw.pullsSinceNew) == "number" then raw.pullsSinceNew else 0
	profile.rating = if typeof(raw.rating) == "number"
		then raw.rating
		else Config.elo.startingRating
	profile.matchesPlayed = if typeof(raw.matchesPlayed) == "number" then raw.matchesPlayed else 0
	profile.starterDone = raw.starterDone == true

	if typeof(raw.owned) == "table" then
		for itemId, value in raw.owned do
			-- On ne recopie que les objets qui existent ENCORE. Un objet retire
			-- du catalogue ne doit pas rester dans la collection : il fausserait
			-- les cotes et la garantie du septieme tirage.
			if value == true and typeof(itemId) == "string" and Loadout.find(Config, itemId) then
				profile.owned[itemId] = true
			end
		end
	end

	return profile
end

local function keyFor(player: Player): string
	return string.format("player_%d", player.UserId)
end

local function openStore(): DataStore?
	if store ~= nil then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		return store
	end
	storeWorks = false
	return nil
end

-- Les trois tirages offerts a l'ouverture du compte. Un objet de chaque type
-- essentiel, pris parmi les objets a cout faible : sinon le debutant tire
-- l'arme a sept points et se retrouve avec un assemblage impossible a
-- completer dans son budget.
local function grantStarter(profile: Profile)
	if profile.starterDone then
		return
	end
	for _, itemId in
		Draws.starterItems(Config, function(n)
			return math.random(1, n)
		end)
	do
		profile.owned[itemId] = true
	end
	profile.starterDone = true
end

local function load(player: Player): Profile
	local opened = openStore()
	if opened == nil then
		local profile = blank()
		profile.loaded = false
		grantStarter(profile)
		return profile
	end

	local lastError: string? = nil
	for attempt = 1, LOAD_ATTEMPTS do
		local ok, result = pcall(function()
			return opened:GetAsync(keyFor(player))
		end)
		if ok then
			local profile = normalise(result)
			grantStarter(profile)
			return profile
		end

		lastError = tostring(result)

		-- Un refus d'acces n'est pas une panne passagere : reessayer ne peut
		-- pas marcher, et six secondes d'attente a chaque connexion dans
		-- Studio rendent chaque test penible pour rien.
		if string.find(lastError, "Studio access to APIs", 1, true) ~= nil then
			storeWorks = false
			break
		end

		task.wait(attempt)
	end

	-- Trois echecs : on laisse le joueur jouer, mais on n'ecrira RIEN. Mieux
	-- vaut une session dont la progression est perdue qu'une collection
	-- effacee pour de bon.
	warn(
		string.format(
			"[Arena] Profil de %s illisible (%s). Il joue sans sauvegarde cette session.",
			player.Name,
			tostring(lastError)
		)
	)
	local profile = blank()
	profile.loaded = false
	grantStarter(profile)
	return profile
end

local function save(player: Player)
	local profile = profiles[player]
	if profile == nil or not profile.loaded then
		return
	end
	local opened = openStore()
	if opened == nil then
		return
	end

	local ok, err = pcall(function()
		opened:SetAsync(keyFor(player), {
			coins = profile.coins,
			fragments = profile.fragments,
			owned = profile.owned,
			pullsSinceNew = profile.pullsSinceNew,
			rating = profile.rating,
			matchesPlayed = profile.matchesPlayed,
			starterDone = profile.starterDone,
		})
	end)

	if not ok then
		warn(string.format("[Arena] Sauvegarde de %s refusee : %s", player.Name, tostring(err)))
	end
end

function ProgressService.profileOf(player: Player): Profile
	local existing = profiles[player]
	if existing ~= nil then
		return existing
	end

	-- Une lecture est deja en cours : on l'attend au lieu d'en lancer une
	-- deuxieme. Celle qui finirait la derniere ecraserait l'autre, et avec
	-- elle tout ce qui aurait ete gagne entre-temps.
	if loading[player] then
		while loading[player] and player.Parent ~= nil do
			task.wait(0.1)
		end
		local loaded = profiles[player]
		if loaded ~= nil then
			return loaded
		end
	end

	loading[player] = true
	local profile = load(player)
	profiles[player] = profile
	loading[player] = nil
	return profile
end

--------------------------------------------------------------------------------
-- CE QUE LE CLIENT VOIT
--------------------------------------------------------------------------------

local function viewFor(player: Player): any
	local profile = ProgressService.profileOf(player)
	local odds = Draws.odds(Config, profile.owned, profile.pullsSinceNew)

	local collection: { any } = {}
	for _, item in Config.items do
		table.insert(collection, {
			id = item.id,
			name = item.name,
			owned = profile.owned[item.id] == true,
		})
	end

	local crates, rest = Economy.cratesAffordable(Config, profile.coins)

	return {
		kind = "progress",
		coins = profile.coins,
		fragments = profile.fragments,
		rating = Rating.rounded(profile.rating),
		matchesPlayed = profile.matchesPlayed,
		crateCost = Config.economy.crateCost,
		cratesAffordable = crates,
		coinsTowardNext = rest,
		owned = Draws.ownedCount(Config, profile.owned),
		total = #Config.items,
		collection = collection,
		odds = odds,
		saved = profile.loaded and storeWorks,
		skinTiers = Config.cosmetics.skinTiers,
	}
end

function ProgressService.push(player: Player)
	progressRemote:FireClient(player, viewFor(player))
end

--------------------------------------------------------------------------------
-- OUVRIR UNE CAISSE
--------------------------------------------------------------------------------

-- Renvoie un message en francais quand l'ouverture est refusee, nil quand elle
-- part. Le serveur est seul juge : le client ne fait qu'envoyer l'intention.
function ProgressService.openCrate(player: Player): string?
	local profile = ProgressService.profileOf(player)

	local spent, left = Economy.spendOnCrate(Config, profile.coins)
	if not spent then
		return string.format("Il manque %d pièces", Config.economy.crateCost - profile.coins)
	end

	local result = Draws.draw(Config, profile.owned, profile.pullsSinceNew, function(n)
		return math.random(1, n)
	end)

	profile.coins = left
	profile.owned[result.itemId] = true
	profile.fragments += result.fragments
	profile.pullsSinceNew = result.pullsSinceNew

	local item = Loadout.find(Config, result.itemId)
	local name = if item ~= nil then item.name else result.itemId

	progressRemote:FireClient(player, {
		kind = "drawn",
		itemId = result.itemId,
		name = name,
		summary = if item ~= nil then item.summary else "",
		isNew = result.isNew,
		fragments = result.fragments,
	})

	ProgressService.push(player)
	save(player)
	return nil
end

--------------------------------------------------------------------------------
-- LA FIN D'UNE PARTIE
--------------------------------------------------------------------------------

-- Les pieces et le classement d'une partie terminee. `roundsWon` compte les
-- manches par equipe, pas par joueur : dans ce mode la manche s'arrete a
-- l'equipe entiere, donc c'est l'equipe qui gagne, pas l'individu.
function ProgressService.awardMatch(
	entries: { Entry },
	winningTeam: string?,
	roundsWon: { [string]: number }
)
	if winningTeam == nil then
		return
	end

	-- CE QUI COMPTE, ET OU. Une partie privee est une partie d'essai : elle ne
	-- paie pas et ne classe pas. L'intention etait dans Config et dans
	-- Rating.counts depuis le debut, et aucun service ne l'appelait — donc une
	-- partie entre amis deplacait les vrais classements. Les deux interrupteurs
	-- sont lus separement et pas comme un seul : si l'un est retourne pour un
	-- essai, l'autre doit continuer a dire la verite.
	local private = Venue.isPrivate()
	local ranked = Rating.counts(Config, private)
	local pays = Economy.paysIn(Config, private)

	-- Le classement d'abord, parce qu'il se calcule sur les valeurs AVANT la
	-- partie : un joueur dont le compte de parties vient d'avancer n'a plus le
	-- meme coefficient K.
	local ratingEntries: { [string]: Rating.Entry } = {}
	local teams: { [string]: string } = {}
	local byKey: { [string]: Player } = {}

	for _, entry in entries do
		local key = tostring(entry.player.UserId)
		local profile = ProgressService.profileOf(entry.player)
		ratingEntries[key] = { rating = profile.rating, matchesPlayed = profile.matchesPlayed }
		teams[key] = entry.team
		byKey[key] = entry.player
	end

	local changes: { [string]: Rating.Change } = {}
	if ranked then
		changes = Rating.applyMatch(Config, ratingEntries, teams, winningTeam)
	end

	for _, entry in entries do
		local player = entry.player
		local profile = ProgressService.profileOf(player)
		local key = tostring(player.UserId)

		local won = entry.team == winningTeam
		local mine = roundsWon[entry.team] or 0
		local theirs = 0
		for team, count in roundsWon do
			if team ~= entry.team then
				theirs = math.max(theirs, count)
			end
		end

		local reward = Economy.rewardFor(Config, {
			won = won,
			roundsWon = mine,
			roundsLost = theirs,
		})

		local coins = if pays then reward.coins else 0
		profile.coins += coins

		-- Le compte de parties n'avance pas non plus dans une partie qui ne
		-- compte pas : il pilote le coefficient K et l'acceleration des
		-- nouveaux, donc le laisser monter userait les deux a blanc.
		if ranked or pays then
			profile.matchesPlayed += 1
		end

		local change = changes[key]
		if change ~= nil then
			profile.rating = change.after
		end

		-- UNE PARTIE QUI NE COMPTE PAS LE DIT. Sans ca le joueur gagne, ne voit
		-- rien arriver, et n'a aucun moyen de savoir si c'est voulu ou casse.
		progressRemote:FireClient(player, {
			kind = "match",
			won = won,
			coins = coins,
			totalCoins = profile.coins,
			rating = Rating.rounded(profile.rating),
			ratingDelta = if change ~= nil then Rating.rounded(change.delta) else 0,
			crateCost = Config.economy.crateCost,
			counted = ranked or pays,
			note = if ranked and pays then "" else Venue.describe(),
		})

		if ranked or pays then
			print(
				string.format(
					"[Arena] %s : %+d pieces (total %d), classement %d (%+d)",
					player.Name,
					coins,
					profile.coins,
					Rating.rounded(profile.rating),
					if change ~= nil then Rating.rounded(change.delta) else 0
				)
			)

			ProgressService.push(player)
			save(player)
		else
			print(
				string.format(
					"[Arena] %s : partie non comptee (privee). Rien n'est ecrit.",
					player.Name
				)
			)
		end
	end

	local _ = byKey
end

--------------------------------------------------------------------------------
-- LE CYCLE DE VIE
--------------------------------------------------------------------------------

local function onClientEvent(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	if payload.openCrate == true then
		local refusal = ProgressService.openCrate(player)
		if refusal ~= nil then
			progressRemote:FireClient(player, { kind = "refused", reason = refusal })
		end
		return
	end

	-- Toute autre demande est une demande d'etat frais.
	ProgressService.push(player)
end

function ProgressService.init()
	openStore()

	if not storeWorks or RunService:IsStudio() then
		-- Dans Studio sans acces aux API, le premier GetAsync echouera et le
		-- dira joueur par joueur. On previent une fois, ici, plutot que de
		-- laisser croire que la progression est gardee.
		print(
			"[Arena] Progression : si « Enable Studio Access to API Services » est décoché,"
				.. " les profils ne sont ni lus ni écrits et tout repart à zéro à chaque test."
		)
	end

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			ProgressService.profileOf(player)
			ProgressService.push(player)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		ProgressService.profileOf(player)
		ProgressService.push(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
		loading[player] = nil
	end)

	-- Sans ca, la derniere partie avant un arret de serveur n'est jamais
	-- ecrite, et c'est precisement celle que le joueur vient de jouer.
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end)

	progressRemote.OnServerEvent:Connect(onClientEvent)
end

return ProgressService
