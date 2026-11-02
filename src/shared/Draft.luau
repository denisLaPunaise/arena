--!strict
--[[
	Draft — les bans, puis le tirage au sort des classes.

	Logique pure : aucun require, aucune API Roblox, pas de Player. Les joueurs
	sont designes par une CLE opaque (le service passe l'identifiant Roblox),
	ce qui permet de derouler une partie entiere de bans et de tirage en ligne
	de commande, sans Studio et sans personne connecte.

	LE HASARD ARRIVE EN ARGUMENT. Toutes les fonctions qui tirent au sort
	recoivent une fonction `rng(n)` qui rend un entier entre 1 et n. En jeu
	c'est `math.random` ; dans les tests c'est une suite choisie, ce qui rend
	un tirage reproductible. Sans ca, on ne pourrait verifier ni l'unicite des
	classes, ni le miroir, ni le comportement quand le vivier est trop petit.

	CE QUE LA FICHE DEMANDE, ET QUI EST TENU ICI :
	- un ban par equipe, alternes : l'equipe B voit le ban de A avant de
	  choisir, ce qui transforme le ban en decision plutot qu'en pari
	- chaque classe n'apparait qu'une fois dans toute la partie, pas une fois
	  par equipe
	- en 1v1 le tirage est un miroir : les deux joueurs ont la meme classe,
	  donc l'equilibrage est parfait par construction
	- en 1v1 les classes qui ciblent un coequipier sont retirees du vivier :
	  sans allie leurs branches sont vides des deux cotes
	- un relancement par joueur et par partie, AVEUGLE : on accepte avant de
	  voir ce qu'on obtient, sinon le relancement devient un choix deguise
]]

local Draft = {}

export type Vote = { team: string, classId: string }

export type State = {
	-- Les classes encore disponibles, dans l'ordre. On retire au fur et a
	-- mesure : bannie, puis tiree.
	pool: { string },
	-- Qui a banni quoi. Sert a l'affichage et a empecher un deuxieme ban.
	bans: { { team: string, classId: string } },
	-- La classe de chaque joueur, une fois le tirage fait.
	assigned: { [string]: string },
	-- Les relancements deja utilises.
	rerolled: { [string]: boolean },
}

export type Rng = (number) -> number

--------------------------------------------------------------------------------
-- LE VIVIER
--------------------------------------------------------------------------------

-- `classes` est la liste complete, telle que Classes.all la donne. On ne
-- requiert pas Classes ici : un module pur ne requiert rien, et le service sait
-- tres bien passer la liste.
function Draft.createPool(classes: { any }, playersPerTeam: number): { string }
	local pool: { string } = {}
	for _, class in classes do
		-- En 1v1, une classe qui cible un coequipier n'a personne a cibler, et
		-- le miroir donnerait deux joueurs a pouvoir eteint.
		if playersPerTeam <= 1 and class.needsAllies then
			continue
		end
		table.insert(pool, class.id)
	end
	return pool
end

function Draft.create(classes: { any }, playersPerTeam: number): State
	return {
		pool = Draft.createPool(classes, playersPerTeam),
		bans = {},
		assigned = {},
		rerolled = {},
	}
end

local function indexOf(list: { string }, value: string): number?
	for index, item in list do
		if item == value then
			return index
		end
	end
	return nil
end

function Draft.isAvailable(state: State, classId: string): boolean
	return indexOf(state.pool, classId) ~= nil
end

--------------------------------------------------------------------------------
-- LES BANS
--------------------------------------------------------------------------------

-- L'ordre dans lequel les equipes bannissent. Alterne, et autant de tours que
-- `bansPerTeam` : A, B, A, B...
function Draft.banOrder(config, teams: { string }): { string }
	local order: { string } = {}
	for _ = 1, config.draft.bansPerTeam do
		for _, team in teams do
			table.insert(order, team)
		end
	end
	return order
end

function Draft.ban(state: State, team: string, classId: string): boolean
	local index = indexOf(state.pool, classId)
	if index == nil then
		return false
	end
	table.remove(state.pool, index)
	table.insert(state.bans, { team = team, classId = classId })
	return true
end

-- Le depouillement d'un vote d'equipe. La classe la plus citee gagne ; a
-- egalite on tire au sort parmi celles qui sont en tete, et si personne n'a
-- vote on tire parmi tout le vivier.
--
-- PERSONNE NE VOTE EST UN CAS NORMAL, pas une erreur : un joueur qui decouvre
-- le jeu ne saura pas quoi bannir, et la partie doit commencer quand meme.
function Draft.tallyBan(state: State, votes: { string }, rng: Rng): string?
	if #state.pool == 0 then
		return nil
	end

	local counts: { [string]: number } = {}
	local best = 0
	for _, classId in votes do
		if not Draft.isAvailable(state, classId) then
			continue
		end
		counts[classId] = (counts[classId] or 0) + 1
		if counts[classId] > best then
			best = counts[classId]
		end
	end

	if best == 0 then
		return state.pool[rng(#state.pool)]
	end

	local leaders: { string } = {}
	for classId, count in counts do
		if count == best then
			table.insert(leaders, classId)
		end
	end
	-- Les cles d'une table n'ont pas d'ordre garanti, et un tirage doit etre
	-- reproductible : on trie avant de tirer.
	table.sort(leaders)

	return leaders[rng(#leaders)]
end

--------------------------------------------------------------------------------
-- LE TIRAGE
--------------------------------------------------------------------------------

local function take(state: State, rng: Rng): string?
	if #state.pool == 0 then
		return nil
	end
	local index = rng(#state.pool)
	local classId = state.pool[index]
	table.remove(state.pool, index)
	return classId
end

-- `teamRosters` associe chaque equipe a la liste des cles de ses joueurs.
--
-- Le miroir du 1v1 n'est pas un cas particulier bricole : c'est la seule
-- facon d'avoir un format ou l'equilibrage est parfait par construction, et
-- il est classe comme les autres pour cette raison.
-- LE MIROIR SE LIT DANS LE FORMAT, jamais devine : c'est une decision de
-- conception, pas une consequence du nombre de joueurs presents. Sorti de
-- `assign` le 2 novembre 2026 parce que le choix de classe a besoin de la
-- meme reponse, et qu'une regle recopiee a deux endroits finit par diverger
-- — c'est la lecon des planchers de statistiques et de `piercedRatio`.
function Draft.mirrors(config, teamRosters: { [string]: { string } }): boolean
	local teams = 0
	local playersPerTeam = 0
	for _, keys in teamRosters do
		teams += 1
		playersPerTeam = math.max(playersPerTeam, #keys)
	end

	for _, format in config.formats do
		if format.playersPerTeam == playersPerTeam then
			return format.mirror == true and teams == 2
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- LE CHOIX DE CLASSE
--------------------------------------------------------------------------------

-- EN PARTIE PRIVEE SEULEMENT, et a la place du tirage. Chacun choisit sa
-- classe a son tour, et une classe prise ne revient pas : c'est le vivier
-- lui-meme qui garantit « une seule personne par classe », puisque choisir
-- retire du vivier exactement comme tirer le fait.
--
-- L'ORDRE EST UN SERPENTIN -- A, B, puis B, A, puis A, B -- et pas une simple
-- alternance. Avec une alternance, le camp qui passe en premier prend la
-- meilleure classe restante a CHAQUE tour, et l'autre ne rattrape jamais : au
-- quatrieme tour l'ecart est de quatre rangs. En serpentin, celui qui choisit
-- en dernier a un tour choisit en premier au suivant, donc l'avantage du
-- premier choix se paie tout de suite. C'est la reponse standard, et elle ne
-- coute qu'une inversion d'indice.
function Draft.pickOrder(teamRosters: { [string]: { string } }): { string }
	local teams: { string } = {}
	for team in teamRosters do
		table.insert(teams, team)
	end
	table.sort(teams)

	local maxSize = 0
	for _, keys in teamRosters do
		maxSize = math.max(maxSize, #keys)
	end

	local order: { string } = {}
	for position = 1, maxSize do
		for index = 1, #teams do
			local team = if position % 2 == 1 then teams[index] else teams[#teams - index + 1]
			local key = teamRosters[team][position]
			if key ~= nil then
				table.insert(order, key)
			end
		end
	end
	return order
end

-- Un choix. Rend false et ne touche a rien si la classe n'est plus
-- disponible ou si ce joueur a deja la sienne : le serveur peut donc relayer
-- n'importe quel message de client sans le verifier lui-meme.
function Draft.pick(state: State, key: string, classId: string): boolean
	if state.assigned[key] ~= nil then
		return false
	end

	local index = indexOf(state.pool, classId)
	if index == nil then
		return false
	end

	table.remove(state.pool, index)
	state.assigned[key] = classId
	return true
end

-- QUI N'A PAS CHOISI EST TIRE AU SORT, et c'est la regle qui empeche la
-- partie de se figer. Un joueur parti, une fenetre laissee passer, un client
-- muet : le choix doit FERMER, pas attendre. Meme regle que le panneau du
-- salon qui doit pouvoir se fermer quand le serveur dit non.
function Draft.fillRemaining(state: State, keys: { string }, rng: Rng): number
	local filled = 0
	for _, key in keys do
		if state.assigned[key] ~= nil then
			continue
		end
		local classId = take(state, rng)
		if classId ~= nil then
			state.assigned[key] = classId
			filled += 1
		end
	end
	return filled
end

function Draft.assign(
	config,
	state: State,
	teamRosters: { [string]: { string } },
	rng: Rng
): { [string]: string }
	local teams: { string } = {}
	for team in teamRosters do
		table.insert(teams, team)
	end
	table.sort(teams)

	if Draft.mirrors(config, teamRosters) then
		local classId = take(state, rng)
		if classId ~= nil then
			for _, team in teams do
				for _, key in teamRosters[team] do
					state.assigned[key] = classId
				end
			end
		end
		return state.assigned
	end

	-- Hors miroir, on distribue joueur par joueur en alternant les equipes :
	-- si le vivier s'epuise, les deux equipes sont servies autant l'une que
	-- l'autre au lieu que la premiere prenne tout.
	local maxSize = 0
	for _, keys in teamRosters do
		maxSize = math.max(maxSize, #keys)
	end

	for position = 1, maxSize do
		for _, team in teams do
			local key = teamRosters[team][position]
			if key == nil then
				continue
			end
			local classId = take(state, rng)
			if classId ~= nil then
				state.assigned[key] = classId
			end
		end
	end

	return state.assigned
end

-- Un relancement, aveugle et unique. Il rend l'ancienne classe au vivier avant
-- d'en tirer une autre : sans ca, relancer retirerait une classe de la partie
-- sans que personne ne la joue.
function Draft.reroll(config, state: State, key: string, rng: Rng): string?
	if config.draft.rerollsPerPlayer <= 0 then
		return nil
	end
	if state.rerolled[key] then
		return nil
	end

	local current = state.assigned[key]
	if current == nil then
		return nil
	end

	-- L'ORDRE COMPTE. On tire D'ABORD le remplacant, et on rend l'ancienne
	-- classe au vivier ENSUITE. Dans l'autre sens, le tirage pourrait rendre
	-- la classe qu'on vient de relancer, et un relancement qui ne change rien
	-- est pire que pas de relancement du tout.
	local replacement = take(state, rng)
	if replacement == nil then
		-- Vivier vide : rien ne change, et le relancement n'est pas consomme.
		return nil
	end

	table.insert(state.pool, current)
	table.sort(state.pool)

	state.rerolled[key] = true
	state.assigned[key] = replacement
	return replacement
end

return Draft
