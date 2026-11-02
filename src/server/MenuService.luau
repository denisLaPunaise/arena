--!strict
--[[
	MenuService — l'accueil : jouer en classe, creer une partie privee,
	rejoindre avec un code.

	CE QU'IL REPARE, et qui comptait plus que l'ecran. Avant lui, le jeu
	n'avait aucun moment ou le joueur decide quoi que ce soit : on tombait
	dans un serveur et TOUTE personne presente etait assise d'office a la
	partie suivante. Quelqu'un qui arrivait pour regarder, qui lisait son
	arbre ou qui parlait a un ami se retrouvait en manche sans l'avoir
	demande. Maintenant on entre en appuyant sur « Jouer », et on en sort.

	LES TROIS CHOSES QUE ROBLOX IMPOSE, et qui expliquent la forme de ce
	service :

	1. UN JEU NE PEUT PAS CREER UN SERVEUR PRIVE. Ce que Roblox appelle
	   « serveur prive » est une fonctionnalite de sa plateforme, achetee
	   depuis la page du jeu, et aucune API ne la declenche. Ce qui existe est
	   `TeleportService:ReserveServer`, qui rend un serveur RESERVE : un
	   serveur neuf, vide, dont `PrivateServerId` est rempli — donc `Venue` le
	   voit comme prive, sans une ligne de plus.

	2. SON CODE D'ACCES EST ILLISIBLE. `ReserveServer` rend plusieurs dizaines
	   de caracteres, impossibles a dicter. Le jeu fabrique donc un code court
	   a lui, range la correspondance dans un DataStore, et c'est le code court
	   qui se partage. Toute la fabrication est dans `Lobbies`, qui est pur.

	3. LES REGLAGES VOYAGENT AVEC LE JOUEUR. Le serveur reserve n'existe pas
	   encore quand on choisit le format : les reglages partent donc en donnee
	   de teleportation, et le serveur d'arrivee les relit a l'arrivee du
	   premier joueur.

	UN REFUS DOIT FERMER, PAS FIGER. C'est la regle du panneau du salon,
	appliquee ici : chaque appel reseau est sous `pcall`, et tout echec
	renvoie une phrase au joueur et le laisse DEVANT le menu, jamais dans un
	ecran d'attente sans issue. Un teleport qui echoue est la panne la plus
	probable de tout le jeu — elle depend de la publication de la place, pas
	du code — et elle ne doit pas coincer qui que ce soit.
]]

local MenuService = {}

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Config = require(Arena:WaitForChild("Config"))
local Lobbies = require(Arena:WaitForChild("Lobbies"))
local Seating = require(Arena:WaitForChild("Seating"))

local Venue = require(script.Parent:WaitForChild("Venue"))

local Remotes = Arena:WaitForChild("Remotes")
local menuRemote = Remotes:WaitForChild("Menu") :: RemoteEvent

local random = Random.new()
local function rng(n: number): number
	return random:NextInteger(1, n)
end

-- Qui a appuye sur « Jouer ». C'est la seule chose que ce service retient de
-- vraiment important : MatchService ne compte que ceux qui sont la-dedans.
local ready: { [Player]: boolean } = {}

-- Les reglages arrives par teleportation, relus une seule fois. Nil quand ce
-- serveur n'a ete reserve par personne.
local arrived: Seating.Lobby? = nil
local arrivedRead = false

-- Le code court de CE serveur, quand il a ete cree depuis un menu. On ne peut
-- pas le deduire : c'est le createur qui le fait voyager avec lui.
local ownCode = ""

local store: DataStore? = nil
local function lobbyStore(): DataStore?
	if store == nil then
		local ok, value = pcall(function()
			return DataStoreService:GetDataStore(Config.menu.dataStoreName)
		end)
		if ok then
			store = value
		end
	end
	return store
end

local function tell(player: Player, payload: any)
	menuRemote:FireClient(player, payload)
end

--------------------------------------------------------------------------------
-- CE QUE LE MENU MONTRE
--------------------------------------------------------------------------------

local function push(player: Player, notice: string?)
	tell(player, {
		kind = "menu",
		enabled = Config.menu.enabled,
		private = Venue.isPrivate(),
		ready = ready[player] == true,
		code = ownCode,
		present = #Players:GetPlayers(),
		-- Les formats viennent du serveur, comme pour le salon : une entree
		-- ajoutee a Config.formats apparait toute seule a l'ecran.
		formats = Seating.formatIds(Config),
		codeLength = Config.menu.codeLength,
		-- La touche vient du serveur, comme les formats : le panneau ne lit
		-- pas Config, et une touche changee dans Config apparait donc toute
		-- seule dans le pied de l'ecran.
		reopenKey = Config.menu.reopenKey,
		notice = notice,
	})
end

function MenuService.pushAll()
	for _, player in Players:GetPlayers() do
		push(player)
	end
end

--------------------------------------------------------------------------------
-- CREER ET REJOINDRE
--------------------------------------------------------------------------------

-- Les reglages qu'un createur a le droit de poser. On ne fait PAS confiance a
-- ce que le client envoie : un format invente ou un mode inconnu retombe sur
-- le defaut, exactement comme dans le salon.
local function cleanSettings(raw: any): Seating.Lobby
	local wanted: Seating.Lobby = {
		formatId = Config.seating.defaultFormat,
		teamMode = Config.seating.defaultTeamMode,
		classMode = Config.seating.defaultClassMode,
	}
	if typeof(raw) ~= "table" then
		return wanted
	end

	if
		typeof(raw.formatId) == "string"
		and (raw.formatId == Seating.AUTO or Seating.formatById(Config, raw.formatId) ~= nil)
	then
		wanted.formatId = raw.formatId
	end
	if raw.teamMode == Seating.CHOSEN or raw.teamMode == Seating.RANDOM then
		wanted.teamMode = raw.teamMode
	end
	if raw.classMode == Seating.DRAWN or raw.classMode == Seating.PICKED then
		wanted.classMode = raw.classMode
	end
	return wanted
end

local function create(player: Player, raw: any)
	local settings = cleanSettings(raw)

	local okReserve, accessCode = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)
	if not okReserve or typeof(accessCode) ~= "string" then
		push(player, "Impossible de réserver un salon. Le jeu doit être publié pour ça.")
		return
	end

	local db = lobbyStore()
	if db == nil then
		push(player, "Les salons ne sont pas disponibles sur ce serveur.")
		return
	end

	-- TROIS ESSAIS, PAS UN SEUL. Deux codes identiques tires de suite sont
	-- improbables -- vingt-huit millions de combinaisons -- mais « improbable »
	-- n'est pas « impossible », et ecraser le salon de quelqu'un d'autre
	-- l'enverrait chez des inconnus.
	local code = ""
	for _ = 1, 3 do
		local candidate = Lobbies.makeCode(rng, Config.menu.codeLength)
		local okRead, existing = pcall(function()
			return db:GetAsync(candidate)
		end)
		if okRead and existing == nil then
			code = candidate
			break
		end
	end
	if code == "" then
		push(player, "Impossible de créer un code pour l'instant. Réessaie.")
		return
	end

	local okWrite = pcall(function()
		db:SetAsync(code, {
			accessCode = accessCode,
			createdAt = os.time(),
			by = player.UserId,
		})
	end)
	if not okWrite then
		push(player, "Le code n'a pas pu être enregistré. Réessaie.")
		return
	end

	print(string.format("[Arena] %s crée le salon %s", player.Name, code))

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData({
		arenaLobby = settings,
		arenaCode = code,
	})

	local okGo = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not okGo then
		push(player, "La téléportation a échoué. Tu es resté ici.")
	end
end

local function join(player: Player, raw: any)
	local text = if typeof(raw) == "string" then raw else ""
	local code = Lobbies.normalise(text, Config.menu.codeLength)
	if not Lobbies.isValid(code, Config.menu.codeLength) then
		push(player, string.format("Un code fait %d signes.", Config.menu.codeLength))
		return
	end

	local db = lobbyStore()
	if db == nil then
		push(player, "Les salons ne sont pas disponibles sur ce serveur.")
		return
	end

	local okRead, entry = pcall(function()
		return db:GetAsync(code)
	end)
	if not okRead then
		push(player, "Impossible de lire le code pour l'instant. Réessaie.")
		return
	end
	if typeof(entry) ~= "table" or typeof(entry.accessCode) ~= "string" then
		push(player, string.format("Aucun salon ne porte le code %s.", code))
		return
	end
	if Lobbies.isExpired(entry.createdAt or 0, os.time(), Config.menu.codeHours) then
		push(player, string.format("Le salon %s a expiré.", code))
		return
	end

	local okGo = pcall(function()
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = entry.accessCode
		options:SetTeleportData({ arenaCode = code })
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not okGo then
		push(player, "La téléportation a échoué. Tu es resté ici.")
	end
end

--------------------------------------------------------------------------------
-- CE QUE MATCHSERVICE DEMANDE
--------------------------------------------------------------------------------

-- A false dans Config, tout le monde est pret : c'est l'interrupteur de
-- comparaison, et il rend au jeu son comportement d'avant le menu.
function MenuService.isReady(player: Player): boolean
	if not Config.menu.enabled or not Config.menu.readyRequired then
		return true
	end
	return ready[player] == true
end

-- Les reglages apportes par celui qui a cree ce salon, lus UNE SEULE FOIS a
-- la premiere demande. Les relire a chaque partie annulerait ce que les amis
-- auraient regle dans le salon depuis leur arrivee.
function MenuService.arrivedLobby(): Seating.Lobby?
	if arrivedRead then
		return arrived
	end
	arrivedRead = true

	for _, player in Players:GetPlayers() do
		local ok, data = pcall(function()
			return player:GetJoinData().TeleportData
		end)
		if ok and typeof(data) == "table" then
			if typeof(data.arenaCode) == "string" and ownCode == "" then
				ownCode = data.arenaCode
			end
			if arrived == nil and typeof(data.arenaLobby) == "table" then
				arrived = cleanSettings(data.arenaLobby)
			end
		end
	end
	return arrived
end

--------------------------------------------------------------------------------

function MenuService.init()
	-- Le code du salon se releve des la premiere arrivee, pour que l'ecran
	-- puisse l'afficher a tout le monde : c'est lui qu'on partage, et le
	-- chercher dans un chat serait absurde quand le jeu le connait.
	local function noteCode(player: Player)
		if ownCode ~= "" then
			return
		end
		local ok, data = pcall(function()
			return player:GetJoinData().TeleportData
		end)
		if ok and typeof(data) == "table" and typeof(data.arenaCode) == "string" then
			ownCode = data.arenaCode
			MenuService.pushAll()
		end
	end

	for _, player in Players:GetPlayers() do
		noteCode(player)
	end
	Players.PlayerAdded:Connect(function(player: Player)
		noteCode(player)
		-- Le compteur de presents bouge pour tout le monde, pas que pour lui.
		MenuService.pushAll()
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		ready[player] = nil
		MenuService.pushAll()
	end)

	menuRemote.OnServerEvent:Connect(function(player: Player, payload: any)
		if typeof(payload) ~= "table" then
			return
		end

		if payload.query == true then
			push(player)
			return
		end

		if payload.ready ~= nil then
			ready[player] = payload.ready == true or nil
			print(
				string.format(
					"[Arena] %s %s",
					player.Name,
					if ready[player] then "entre en partie" else "retourne au menu"
				)
			)
			push(player)
			return
		end

		-- CREER ET REJOINDRE N'EXISTENT PAS DANS UN SALON. On y est deja, et
		-- un bouton qui creerait un salon depuis un salon enverrait l'hote
		-- ailleurs en laissant ses amis derriere lui.
		if Venue.isPrivate() then
			push(player, "Tu es déjà dans un salon.")
			return
		end

		if payload.create ~= nil then
			create(player, payload.create)
		elseif payload.join ~= nil then
			join(player, payload.join)
		end
	end)

	print(
		string.format(
			"[Arena] Menu d'accueil : %s%s",
			if Config.menu.enabled then "ouvert" else "coupé (Config.menu.enabled)",
			if Venue.isPrivate() then "  ·  salon privé" else "  ·  serveur public"
		)
	)
end

return MenuService
