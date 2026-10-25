--!strict
--[[
	Rating — le classement Elo.

	Logique pure : aucun require, aucune API Roblox.

	LE COEFFICIENT K BAISSE AVEC LE NOMBRE DE PARTIES DU JOUEUR, pas avec la
	taille de la population. C'est la methode des systemes qui tiennent : un
	nouveau venu doit rejoindre son niveau reel en quelques parties, un habitue
	ne doit pas voir son classement sauter sur un mauvais soir. Les paliers
	sont dans `config.elo.kFactorTiers`, et les sources dans
	docs/EQUILIBRAGE.md.

	UNE EQUIPE COMPTE POUR LA MOYENNE DE SES MEMBRES. C'est le choix le plus
	simple qui reste juste : battre une equipe forte rapporte a tous ses
	adversaires, y compris au plus faible d'entre eux, et c'est exactement ce
	qu'on veut dans un jeu ou on ne choisit pas ses coequipiers.

	LE MIROIR DU 1V1 EST CLASSE comme les autres formats. L'equilibrage y etant
	parfait par construction, il n'y a aucune raison d'en faire un mode detente
	hors classement : c'est au contraire le format ou le classement veut dire
	le plus de choses.

	Si le classement reste trop nerveux a quelques dizaines de joueurs, la
	vraie reponse n'est pas de baisser K mais de passer a Glicko, qui porte une
	incertitude par joueur. Ce module serait alors a remplacer, pas a regler.
]]

local Rating = {}

export type Entry = {
	rating: number,
	matchesPlayed: number,
}

export type Change = {
	before: number,
	after: number,
	delta: number,
	kFactor: number,
	expected: number,
}

function Rating.starting(config): number
	return config.elo.startingRating
end

function Rating.newEntry(config): Entry
	return { rating = config.elo.startingRating, matchesPlayed = 0 }
end

-- Le coefficient K de ce joueur. Les paliers sont lus dans l'ordre, et le
-- dernier a `math.huge` pour borne : il attrape tout le monde.
function Rating.kFactor(config, matchesPlayed: number): number
	for _, tier in config.elo.kFactorTiers do
		if matchesPlayed <= tier.upToMatchesPlayed then
			return tier.kFactor
		end
	end
	return config.elo.kFactorTiers[#config.elo.kFactorTiers].kFactor
end

-- La probabilite qu'un joueur a `rating` batte un joueur a `against`. La
-- formule d'Elo, et rien d'autre : 400 points d'ecart valent dix contre un.
function Rating.expected(rating: number, against: number): number
	return 1 / (1 + 10 ^ ((against - rating) / 400))
end

-- Le classement d'une equipe : la moyenne de ses membres.
function Rating.teamRating(ratings: { number }): number
	if #ratings == 0 then
		return 0
	end
	local total = 0
	for _, value in ratings do
		total += value
	end
	return total / #ratings
end

-- Le nouveau classement d'un joueur. `score` vaut 1 pour une victoire, 0 pour
-- une defaite ; il n'y a pas de match nul dans ce jeu, mais la formule
-- l'accepte si un format en introduit un.
function Rating.update(config, entry: Entry, opponentRating: number, score: number): Change
	local k = Rating.kFactor(config, entry.matchesPlayed)
	local expected = Rating.expected(entry.rating, opponentRating)
	local delta = k * (score - expected)

	return {
		before = entry.rating,
		after = entry.rating + delta,
		delta = delta,
		kFactor = k,
		expected = expected,
	}
end

-- Vrai si cette partie compte pour le classement. Les parties privees entre
-- amis sont natives sur Roblox et ne comptent pas : c'est la qu'on teste, et
-- un test ne doit pas abimer le classement de qui veut bien nous aider.
function Rating.counts(config, private: boolean): boolean
	if private then
		return config.elo.privateMatchesRanked
	end
	return config.elo.rankedByDefault
end

-- Le resultat complet d'une partie : qui gagne combien.
--
-- `entries` associe une cle de joueur a son classement et son compte de
-- parties ; `teams` associe la meme cle a "A" ou "B". Les cles sont opaques,
-- comme pour le tirage des classes : ce module ne connait pas `Player`.
function Rating.applyMatch(
	config,
	entries: { [string]: Entry },
	teams: { [string]: string },
	winningTeam: string
): { [string]: Change }
	local byTeam: { [string]: { number } } = {}
	for key, entry in entries do
		local team = teams[key]
		if team == nil then
			continue
		end
		local list = byTeam[team]
		if list == nil then
			list = {}
			byTeam[team] = list
		end
		table.insert(list, entry.rating)
	end

	local averages: { [string]: number } = {}
	for team, ratings in byTeam do
		averages[team] = Rating.teamRating(ratings)
	end

	local changes: { [string]: Change } = {}
	for key, entry in entries do
		local team = teams[key]
		if team == nil then
			continue
		end

		-- Le classement adverse est la moyenne de TOUTES les autres equipes.
		-- A deux equipes c'est simplement l'autre ; la formulation generale
		-- evite d'avoir a reecrire ce module le jour ou un format en aura
		-- trois.
		local others: { number } = {}
		for otherTeam, average in averages do
			if otherTeam ~= team then
				table.insert(others, average)
			end
		end

		-- AUCUNE EQUIPE EN FACE : le classement ne bouge pas.
		--
		-- Sans ce garde-fou, la moyenne d'une liste vide vaut zero, donc
		-- l'adversaire est note zero, donc la victoire est certaine et la
		-- defaite coute le coefficient K entier. Un joueur reste seul sur un
		-- serveur, la partie s'arrete faute d'adversaire, et il perd sa soiree
		-- de classement sans avoir joue contre personne.
		if #others == 0 then
			continue
		end

		local opponent = Rating.teamRating(others)
		local score = if team == winningTeam then 1 else 0
		changes[key] = Rating.update(config, entry, opponent, score)
	end

	return changes
end

-- Arrondi a l'entier pour l'affichage et le stockage. Un classement a
-- virgule n'apporte rien a un joueur et grossit la sauvegarde.
function Rating.rounded(value: number): number
	return math.floor(value + 0.5)
end

return Rating
