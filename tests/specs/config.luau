--!strict
--[[
	Tests de coherence du fichier de configuration.

	Ils ne verifient pas que le jeu est amusant — ca, seule une partie le dit.
	Ils verifient que les chiffres ne se contredisent pas entre eux, parce que
	c'est exactement le genre d'erreur qui ne se voit qu'une fois le jeu
	desequilibre.
]]

local Config = require("../../src/shared/Config")
local Classes = require("../../src/shared/Classes")
local MatchState = require("../../src/shared/MatchState")
local Draft = require("../../src/shared/Draft")

local harness = require("../harness")

local function sum(list: { number }): number
	local total = 0
	for _, value in list do
		total += value
	end
	return total
end

local function count(list: { any }): number
	local n = 0
	for _ in list do
		n += 1
	end
	return n
end

return function(t: harness.Harness)
	t.section("L'arbre de competences")

	t.equal("aller au bout de l'arbre coute six points", sum(Config.skillTree.tierCosts), 6)
	t.equal("il y a un cout par palier", count(Config.skillTree.tierCosts), Config.skillTree.tiers)
	t.equal("le premier palier est gratuit", Config.skillTree.tierCosts[1], 0)
	t.equal(
		"le dernier palier coute deux points",
		Config.skillTree.tierCosts[Config.skillTree.tiers],
		2
	)

	-- Une partie de M manches distribue un point avant la premiere manche puis
	-- un par fin de manche ; le dernier ne sert a rien, donc M points utilisables.
	local function usablePoints(roundsPlayed: number): number
		return Config.skillTree.pointsBeforeFirstRound
			+ (roundsPlayed * Config.skillTree.pointsPerRoundEnd)
			- Config.skillTree.pointsPerRoundEnd
	end

	t.equal("un 4-0 (4 manches) donne 4 points", usablePoints(4), 4)
	t.equal("un 4-1 (5 manches) donne 5 points", usablePoints(5), 5)
	t.equal("un 4-2 (6 manches) donne l'arbre complet", usablePoints(6), 6)
	t.equal("un 4-3 (7 manches) donne 7 points", usablePoints(7), 7)
	t.check(
		"l'arbre complet n'est atteignable qu'a partir du 4-2",
		usablePoints(5) < sum(Config.skillTree.tierCosts)
			and usablePoints(6) >= sum(Config.skillTree.tierCosts)
	)

	t.section("La partie")

	t.equal(
		"premier a quatre manches donne sept manches au maximum",
		Config.match.maxRounds,
		(Config.match.roundsToWin * 2) - 1
	)

	-- LE TEST QUI RELIE LES DEUX BOUTS, et il manquait. Les quatre assertions
	-- ci-dessus lisaient `Config.match`, qu'AUCUN service ne lisait : le jeu
	-- jouait `Config.prototype.roundsToWin`, donc trois manches, donc trois
	-- points, donc les paliers 5 et 6 inatteignables. Les tests passaient tous.
	-- Celui-ci ne regarde plus un chiffre de Config mais la longueur que le jeu
	-- joue VRAIMENT, et il refuse qu'un palier declare soit hors d'atteinte.
	local playedToWin = MatchState.roundsToWin(Config)
	local playedRounds = (playedToWin * 2) - 1
	t.check(
		"la longueur reellement jouee rend l'arbre complet atteignable",
		usablePoints(playedRounds) >= sum(Config.skillTree.tierCosts)
	)
	t.check(
		"et elle ne le rend pas atteignable des la premiere manche",
		usablePoints(1) < sum(Config.skillTree.tierCosts)
	)

	t.section("Le draft")

	-- LA MEME REGLE EXISTE DEUX FOIS, ET C'EST STRUCTUREL : `Draft.createPool`
	-- ne peut pas appeler `Classes.drawable`, parce qu'un module de logique
	-- pure ne requiert rien -- c'est le piege numero un du projet. Les deux
	-- copies du filtre `needsAllies` sont donc condamnees a cohabiter, et rien
	-- ne les empechait de diverger : changer la regle d'un cote laissait
	-- l'autre en place, sans la moindre erreur. Ce test les attache l'une a
	-- l'autre. Trouve au controle du 29 octobre 2026.
	for _, playersPerTeam in { 1, 2, 3, 4 } do
		local fromClasses: { [string]: boolean } = {}
		for _, class in Classes.drawable(playersPerTeam) do
			fromClasses[class.id] = true
		end
		local fromDraft = Draft.createPool(Classes.all, playersPerTeam)

		local sameCount = count(fromClasses) == #fromDraft
		local allPresent = true
		for _, id in fromDraft do
			if not fromClasses[id] then
				allPresent = false
			end
		end
		t.check(
			string.format(
				"les deux filtres de classes jouables s'accordent en %dv%d",
				playersPerTeam,
				playersPerTeam
			),
			sameCount and allPresent
		)
	end

	t.equal("quatorze classes dans le catalogue", count(Classes.all), 14)
	local bans = Config.draft.bansPerTeam * 2
	t.equal("deux bans au total", bans, 2)

	-- Il doit toujours rester des classes en reserve, sinon le reroll ne veut
	-- plus rien dire. C'est la raison pour laquelle le 5v5 est ecarte.
	for _, format in Config.formats do
		local available = count(Classes.all) - bans
		local reserve = available - format.classesDrawn
		t.check(
			string.format(
				"le reroll reste possible en %s (%d classes en reserve)",
				format.id,
				reserve
			),
			reserve >= 1
		)
		t.equal(
			string.format("le %s tire deux classes par joueur present", format.id),
			format.classesDrawn,
			format.playersPerTeam * 2
		)
	end

	t.section("Le budget d'equipement")

	-- En additionnant le maximum de chaque categorie on arrive autour de
	-- vingt-trois points : a douze, chaque assemblage renonce a la moitie de ce
	-- qu'il pourrait porter, et c'est exactement l'intention.
	local maxCostTotal = 0
	for _, category in Config.loadout.categories do
		maxCostTotal += category.maxCost
	end

	t.check(
		"le budget est inferieur au total des maximums de categorie",
		Config.loadout.budgetPoints < maxCostTotal
	)
	t.check(
		"le budget permet au moins une arme principale la plus chere",
		Config.loadout.budgetPoints >= Config.loadout.categories[1].maxCost
	)

	t.section("Le catalogue d'objets")

	local targetTotal = 0
	for _, n in Config.itemCounts.target do
		targetTotal += n
	end
	t.equal("soixante-deux objets a terme", targetTotal, 62)

	-- Et le catalogue reel les contient tous. Ce test et celui de
	-- tests/specs/loadout.luau disent la meme chose par les deux bouts : celui
	-- la verifie que la cible annoncee fait bien soixante-deux, l'autre que le
	-- catalogue la remplit categorie par categorie.
	t.equal("et le catalogue en compte autant", #Config.items, targetTotal)

	t.section("L'economie des pieces")

	-- Les gains de la fiche doivent donner une caisse toutes les trois a six
	-- parties. C'est le reglage qui pilote tout le rythme de collection.
	local gains = {
		["victoire 4-0"] = Config.economy.winBase + (4 * Config.economy.winPerRoundNotConceded),
		["victoire 4-3"] = Config.economy.winBase + (1 * Config.economy.winPerRoundNotConceded),
		["defaite 3-4"] = Config.economy.lossBase + (3 * Config.economy.lossPerRoundWon),
		["defaite 0-4"] = Config.economy.lossBase + (0 * Config.economy.lossPerRoundWon),
	}

	t.equal("une victoire 4-0 rapporte 340 pieces", gains["victoire 4-0"], 340)
	t.equal("une victoire 4-3 rapporte 250 pieces", gains["victoire 4-3"], 250)
	t.equal("une defaite 3-4 rapporte 200 pieces", gains["defaite 3-4"], 200)
	t.equal("une defaite 0-4 rapporte 170 pieces", gains["defaite 0-4"], 170)

	for label, gain in gains do
		local matches = math.ceil(Config.economy.crateCost / gain)
		t.check(
			string.format("une caisse en 3 a 6 parties (%s : %d parties)", label, matches),
			matches >= 3 and matches <= 6
		)
	end

	t.section("Les skins et les fragments")

	-- Le prix en fragments doit monter avec le prix en Robux, sinon un palier
	-- devient le seul choix rationnel.
	local previousRobux = 0
	local previousFragments = 0
	for _, tier in Config.cosmetics.skinTiers do
		t.check(
			string.format("le palier %s est plus cher que le precedent", tier.id),
			tier.robux > previousRobux and tier.fragments > previousFragments
		)
		previousRobux = tier.robux
		previousFragments = tier.fragments
	end

	t.check("aucun skin en dessous de 50 Robux", Config.cosmetics.skinTiers[1].robux >= 50)

	t.section("Les touches ne se marchent pas dessus")

	-- CE QUE CE BLOC ATTRAPE : deux reglages qui reclament la meme touche. Ca
	-- ne leve rien, ca ne se voit pas en relisant Config — les touches sont a
	-- trois endroits differents du fichier — et en jeu une touche fait alors
	-- deux choses selon le moment. Le camp demande a failli prendre « 1 », qui
	-- sert deja au premier objet.
	local taken: { [string]: string } = {}
	local collisions: { string } = {}

	local function claim(key: string?, who: string)
		-- Une touche absente de Config arrivait ici en nil et faisait PLANTER
		-- le test au lieu de l'echouer : vu en renommant sideKey en lobbyKey.
		-- Un test qui plante ne dit pas ce qui ne va pas.
		if key == nil then
			table.insert(collisions, string.format("%s n'a aucune touche dans Config", who))
			return
		end

		local already = taken[key]
		if already ~= nil then
			table.insert(collisions, string.format("%s et %s veulent « %s »", already, who, key))
			return
		end
		taken[key] = who
	end

	for index, key in Config.loadout.useKeys do
		claim(key, string.format("l'objet %d", index))
	end
	claim(Config.loadout.editKey, "l'écran d'équipement")
	claim(Config.sandbox.toggleKey, "le bac à sable")
	claim(Config.seating.lobbyKey, "le salon")
	claim(Config.menu.reopenKey, "le menu d'accueil")

	t.equal(if #collisions > 0 then collisions[1] else "aucune collision", #collisions, 0)

	t.section("Ce qui compte en partie privee")

	-- Les deux interrupteurs se changent ENSEMBLE : payer sans classer
	-- recompenserait un serveur prive a deux joueurs complaisants, et classer
	-- sans payer serait incomprehensible. Ce test est la pour qu'on ne retourne
	-- pas l'un en oubliant l'autre.
	t.equal(
		"les pièces et le classement disent la même chose du privé",
		Config.economy.privateMatchesPay,
		Config.elo.privateMatchesRanked
	)
	t.check("et le privé ne compte pas", not Config.elo.privateMatchesRanked)
	t.check("alors que le public, oui", Config.elo.rankedByDefault)
end
