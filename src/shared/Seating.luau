--!strict
--[[
	Seating — qui joue, dans quelle equipe, et qui attend.

	Logique pure : aucun require, aucune API Roblox. Un joueur est un
	identifiant, comme dans Downed et Draft ; MatchService fait la traduction.

	Ce module repond a trois questions, et a rien d'autre :

	    1. quel format pour N joueurs presents
	    2. lesquels s'assoient, lesquels attendent
	    3. qui est dans l'equipe A, qui est dans l'equipe B

	POURQUOI IL EXISTE. La boucle de partie n'asseyait que les DEUX PREMIERS
	joueurs arrives, en dur, et donnait l'equipe par ordre d'arrivee : un
	troisieme joueur n'avait aucune equipe, et les quatre formats declares dans
	Config.formats n'etaient lus par personne. Tout ce qui est en aval savait
	deja compter en equipes — la fin de manche compte les equipes debout, le
	relevement cherche un coequipier, le tirage deduit la taille des equipes —
	mais rien ne les composait.

	LES QUATRE FORMATS SONT PAIRS, donc un effectif impair laisse toujours
	quelqu'un dehors : a cinq joueurs on joue a 2v2 et un joueur attend. Le
	choix est de descendre au format du dessous plutot que d'improviser un 3v2.
	Un 3v2 est injouable a juger : on ne saurait jamais si une classe est forte
	ou si elle etait simplement une de plus.

	LE SALON, en partie privee seulement. Les amis qui jouent ensemble reglent
	deux choses, et DEUX SEULEMENT : le format, et la facon de composer les
	camps. Les regles du jeu — la zone, l'agonie, l'arbre, les bans — ne sont
	pas reglables, et c'est une decision de Josh : le jeu reste le jeu.

	Le format impose ne change PAS qui joue. L'ordre du banc decide toujours de
	ca, parce que c'est une question d'equite entre les personnes, pas
	d'equilibre entre les camps. Six joueurs qui demandent du 1v1 font donc
	jouer deux personnes et en asseoir quatre, et c'est voulu.

	QUI ATTEND, ET POURQUOI CA COMPTE. Celui qui vient d'attendre passe devant.
	Sans ca, a cinq joueurs, le dernier arrive regarde les autres jouer toute la
	soiree — et le jeu n'a aucun moyen de le lui dire. C'est tout le role de
	`satOut`, et c'est pour ca qu'il entre ici par argument : ce module ne
	retient rien entre deux appels.
]]

local Seating = {}

export type Candidate = {
	id: string,
	-- Combien de parties ce joueur a passees sur le banc. Le plus grand passe
	-- devant.
	satOut: number,
	-- Le camp demande, en partie privee. Nil pour « peu importe », et ce n'est
	-- qu'un VOEU : les deux camps doivent rester egaux, donc le quatrieme a
	-- demander un camp de trois places part en face. C'est l'appelant qui
	-- decide s'il a le droit de le remplir — en partie classee, personne ne
	-- choisit son camp.
	side: string?,
}

-- Une fonction qui rend un entier entre 1 et n, comme celle du tirage des
-- classes. Elle arrive par argument : ce module ne connait pas `Random`.
export type Rng = (number) -> number

export type Lobby = {
	-- Le format impose, ou AUTO pour « le plus grand qui tienne ».
	formatId: string,
	-- Comment les camps se composent : CHOSEN (chacun demande le sien) ou
	-- RANDOM (tirage au sort, refait a chaque partie).
	teamMode: string,
}

export type Plan = {
	formatId: string,
	-- Les identifiants assis, dans l'ordre ou ils ont ete places.
	seated: { string },
	-- Ceux qui attendent la partie suivante.
	waiting: { string },
	-- L'equipe de chaque identifiant assis.
	teams: { [string]: string },
}

-- « Pas de format impose ». Ce n'est pas un format : un test verifie
-- qu'aucun identifiant de Config.formats ne porte ce nom.
Seating.AUTO = "auto"

-- Les deux facons de composer les camps.
Seating.CHOSEN = "chosen"
Seating.RANDOM = "random"

-- Les deux camps, tels que Config les nomme. Renvoyes tels quels : l'appelant
-- lit, il ne modifie pas.
function Seating.teamNames(config): { string }
	return config.seating.teams
end

-- Le plus petit effectif qui permette de jouer, DEDUIT des formats au lieu
-- d'etre recopie. C'etait un `PLAYERS_NEEDED = 2` en dur dans MatchService, et
-- un chiffre en dur qui doit s'accorder avec une table est un bug qui attend.
function Seating.playersNeeded(config): number
	local teams = #Seating.teamNames(config)
	local smallest = 0

	for _, format in config.formats do
		local total = format.playersPerTeam * teams
		if smallest == 0 or total < smallest then
			smallest = total
		end
	end

	return smallest
end

-- Les identifiants de format, AUTO en tete. C'est la liste que le salon
-- affiche : un format ajoute a Config.formats apparait donc tout seul a
-- l'ecran, sans qu'on ait a le recopier cote client.
function Seating.formatIds(config): { string }
	local ids = { Seating.AUTO }
	for _, format in config.formats do
		table.insert(ids, format.id)
	end
	return ids
end

function Seating.formatById(config, id: string)
	for _, format in config.formats do
		if format.id == id then
			return format
		end
	end
	return nil
end

-- Combien de joueurs ce format demande en tout.
function Seating.seatsFor(config, format): number
	return format.playersPerTeam * #Seating.teamNames(config)
end

-- Le format a jouer. Avec un format impose, c'est celui-la ou rien : on ne
-- retombe PAS en silence sur le format du dessous. Demander du 3v3 et se
-- retrouver en 2v2 sans l'avoir vu passer serait pire que d'attendre — et
-- l'ecran dit alors combien il manque de monde.
--
-- Sans format impose (AUTO), c'est le plus grand que l'effectif remplit.
function Seating.formatFor(config, present: number, wanted: string?)
	if wanted ~= nil and wanted ~= Seating.AUTO then
		local format = Seating.formatById(config, wanted)
		if format == nil then
			return nil
		end
		if Seating.seatsFor(config, format) <= present then
			return format
		end
		return nil
	end

	local best = nil
	local bestTotal = 0

	for _, format in config.formats do
		local total = Seating.seatsFor(config, format)
		if total <= present and total > bestTotal then
			best = format
			bestTotal = total
		end
	end

	return best
end

function Seating.plan(config, candidates: { Candidate }, lobby: Lobby?, rng: Rng?): Plan?
	local format = Seating.formatFor(config, #candidates, if lobby then lobby.formatId else nil)
	if format == nil then
		return nil
	end

	local teams = Seating.teamNames(config)
	local seats = Seating.seatsFor(config, format)

	-- L'ordre de passage : le plus longtemps sur le banc d'abord, puis l'ordre
	-- d'arrivee. On trie sur une cle a DEUX niveaux plutot que de se fier a
	-- table.sort, qui n'est pas stable en Luau : deux joueurs a egalite
	-- changeraient d'ordre d'un appel a l'autre, et le banc deviendrait un
	-- tirage au sort au lieu d'une file.
	local ranked: { { index: number, candidate: Candidate } } = {}
	for index, candidate in candidates do
		table.insert(ranked, { index = index, candidate = candidate })
	end
	table.sort(ranked, function(left, right): boolean
		if left.candidate.satOut ~= right.candidate.satOut then
			return left.candidate.satOut > right.candidate.satOut
		end
		return left.index < right.index
	end)

	local plan: Plan = {
		formatId = format.id,
		seated = {},
		waiting = {},
		teams = {},
	}

	for position, row in ranked do
		if position > seats then
			table.insert(plan.waiting, row.candidate.id)
		else
			table.insert(plan.seated, row.candidate.id)
		end
	end

	local wishOf: { [string]: string } = {}
	for position = 1, seats do
		local candidate = ranked[position].candidate
		if candidate.side ~= nil then
			wishOf[candidate.id] = candidate.side
		end
	end

	-- L'ORDRE DANS LEQUEL LES CAMPS SE REMPLISSENT, et c'est tout ce que le
	-- tirage au sort change. Qui JOUE reste decide par l'ordre du banc dans les
	-- deux cas : melanger les places serait une loterie sur le droit de jouer,
	-- alors que le tirage au sort ne porte que sur le camp.
	local order = table.clone(plan.seated)
	local honourWishes = true

	if lobby ~= nil and lobby.teamMode == Seating.RANDOM and rng ~= nil then
		honourWishes = false

		-- Melange de Fisher-Yates, avec le meme `rng(n)` que le tirage des
		-- classes : un entier entre 1 et n, fourni par l'appelant, donc un test
		-- peut le rendre previsible.
		for index = #order, 2, -1 do
			local pick = rng(index)
			order[index], order[pick] = order[pick], order[index]
		end
	end

	local perTeam: { [string]: number } = {}
	for _, team in teams do
		perTeam[team] = 0
	end

	-- PREMIERE PASSE : les voeux qu'on peut tenir, dans l'ordre du banc. C'est
	-- ce qui permet d'arranger un 3v3 entre amis — trois qui demandent A sont
	-- tous les trois en A — et l'ordre du banc tranche quand un camp est
	-- sur-demande : celui qui a le moins attendu passe en face. Sautee
	-- entierement au tirage au sort, sinon ce ne serait pas un tirage.
	if honourWishes then
		for _, id in order do
			local wish = wishOf[id]

			if wish == nil or perTeam[wish] == nil then
				continue
			end
			if perTeam[wish] >= format.playersPerTeam then
				continue
			end

			plan.teams[id] = wish
			perTeam[wish] += 1
		end
	end

	-- DEUXIEME PASSE : tout le monde d'autre va dans le camp le moins rempli.
	-- Quand personne n'a rien demande, les deux camps sont a egalite a chaque
	-- tour et ca ALTERNE — ce qui est exactement ce qu'on veut, parce que les
	-- deux joueurs qui ont le plus attendu se retrouvent dans des camps
	-- opposes, et le banc ne fabrique pas une equipe entiere de joueurs frais
	-- contre une equipe fatiguee. C'est aussi cette passe qui, sur l'ordre
	-- melange, compose les camps du tirage au sort.
	for _, id in order do
		if plan.teams[id] ~= nil then
			continue
		end

		local chosen = teams[1]
		for _, team in teams do
			if perTeam[team] < perTeam[chosen] then
				chosen = team
			end
		end

		plan.teams[id] = chosen
		perTeam[chosen] += 1
	end

	return plan
end

return Seating
