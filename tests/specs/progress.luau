--!strict
--[[
	Tests des pieces, des tirages et du classement.

	Deux sortes de verifications ici, et elles n'ont pas le meme statut.

	LES REGLES DE CONCEPTION, qu'on peut casser par inadvertance :
	  - une defaite rapporte toujours quelque chose
	  - une victoire rapporte toujours plus qu'une defaite
	  - un debutant peut toujours tirer une arme principale
	  - un classement remonte quand on bat plus fort que soi

	LES EXIGENCES DE ROBLOX sur les objets aleatoires payants, qui ne sont pas
	negociables et qui coutent la publication si elles sautent :
	  - le total des cotes affichees fait EXACTEMENT 100 %
	  - aucun resultat ne rend rien au joueur
	  - les cotes CHANGENT quand la garantie du septieme tirage est active
]]

local Config = require("../../src/shared/Config")
local Draws = require("../../src/shared/Draws")
local Economy = require("../../src/shared/Economy")
local Loadout = require("../../src/shared/Loadout")
local Rating = require("../../src/shared/Rating")

local harness = require("../harness")

local function first(_: number): number
	return 1
end

local function last(n: number): number
	return n
end

return function(t: harness.Harness)
	t.section("L'acceleration des nouveaux joueurs")

	do
		local cost = Config.economy.crateCost
		local every = Config.draws.newPlayerCrateEveryMatches
		local boostMatches = Config.draws.newPlayerBoostMatches
		local worstLoss = Economy.coinsFor(Config, { won = false, roundsWon = 0, roundsLost = 2 })
		-- La regle annoncee : une caisse toutes les `every` parties, meme en perdant.
		local paid = Economy.paidCoins(Config, worstLoss, 0)
		t.equal(
			"un debutant qui perd tout ouvre une caisse en " .. every .. " parties",
			paid * every >= cost,
			true
		)
		t.equal(
			"la derniere partie acceleree l'est encore",
			Economy.paidCoins(Config, worstLoss, boostMatches - 1),
			paid
		)
		t.equal(
			"la suivante ne l'est plus",
			Economy.paidCoins(Config, worstLoss, boostMatches),
			worstLoss
		)
		local bigWin = cost
		t.equal(
			"une partie qui rapporte deja plus ne perd rien",
			Economy.paidCoins(Config, bigWin, 0),
			bigWin
		)
	end

	t.section("Les pieces")

	local crush = Economy.rewardFor(Config, { won = true, roundsWon = 2, roundsLost = 0 })
	local tightWin = Economy.rewardFor(Config, { won = true, roundsWon = 2, roundsLost = 1 })
	local tightLoss = Economy.rewardFor(Config, { won = false, roundsWon = 1, roundsLost = 2 })
	local crushLoss = Economy.rewardFor(Config, { won = false, roundsWon = 0, roundsLost = 2 })

	t.equal("ecraser rapporte 280", crush.coins, 280)
	t.equal("gagner serre rapporte 250", tightWin.coins, 250)
	t.equal("perdre serre rapporte 180", tightLoss.coins, 180)
	t.equal("se faire ecraser rapporte 170", crushLoss.coins, 170)

	t.check("gagner serre rapporte moins qu'ecraser", tightWin.coins < crush.coins)
	t.check("mais plus que perdre serre", tightWin.coins > tightLoss.coins)
	t.check("et perdre serre plus que se faire ecraser", tightLoss.coins > crushLoss.coins)

	-- Une partie qui ne rapporte rien est une partie qu'on quitte avant la fin.
	t.check("une defaite rapporte toujours quelque chose", crushLoss.coins > 0)

	-- La fourchette annoncee dans Config : une caisse toutes les trois a six
	-- parties. Les quatre cas doivent y tomber.
	local worst = math.max(
		crush.matchesPerCrate,
		tightWin.matchesPerCrate,
		tightLoss.matchesPerCrate,
		crushLoss.matchesPerCrate
	)
	local best = math.min(
		crush.matchesPerCrate,
		tightWin.matchesPerCrate,
		tightLoss.matchesPerCrate,
		crushLoss.matchesPerCrate
	)
	t.check(
		string.format("une caisse toutes les %d a %d parties", best, worst),
		best >= 3 and worst <= 6
	)

	t.check("les eliminations ne rapportent rien", Config.economy.rewardKills == false)

	local affordable, rest = Economy.cratesAffordable(Config, 2300)
	t.equal("2300 pieces ouvrent deux caisses", affordable, 2)
	t.equal("et il reste 300 pieces", rest, 300)

	local spent, left = Economy.spendOnCrate(Config, 1200)
	t.check("on peut ouvrir avec 1200", spent)
	t.equal("il reste 200", left, 200)

	local refused, kept = Economy.spendOnCrate(Config, 900)
	t.check("on ne peut pas ouvrir avec 900", not refused)
	t.equal("et on garde ses pieces", kept, 900)

	t.section("Les fragments et les skins")

	t.equal("un doublon donne 50 fragments", Economy.fragmentsForDuplicate(Config), 50)
	t.equal("un skin commun coute 10 doublons", Economy.duplicatesPerSkin(Config, "common"), 10)
	t.equal("un legendaire en coute 80", Economy.duplicatesPerSkin(Config, "legendary"), 80)
	t.check("500 fragments achetent un commun", Economy.canAffordSkin(Config, 500, "common"))
	t.check("mais pas un rare", not Economy.canAffordSkin(Config, 500, "rare"))

	t.section("Le tirage, et ce que Roblox exige d'afficher")

	local nothing: { [string]: boolean } = {}
	local odds = Draws.odds(Config, nothing, 0)
	t.equal("collection vide : une seule ligne", #odds.lines, 1)
	t.check("et elle fait 100 %", math.abs(odds.total - 100) < 1e-9)

	-- EXIGENCE ROBLOX : le total fait exactement 100 %, a tous les etats de la
	-- collection. On les parcourt tous, du vide au complet.
	local badTotal: string? = nil
	local emptyLines: string? = nil
	local owned: { [string]: boolean } = {}
	for index, item in Config.items do
		local state = Draws.odds(Config, owned, 0)
		if math.abs(state.total - 100) > 1e-9 then
			badTotal = string.format("%d objets possedes : %.6f %%", index - 1, state.total)
		end
		if #state.lines == 0 then
			emptyLines = tostring(index - 1)
		end
		owned[item.id] = true
	end
	local complete = Draws.odds(Config, owned, 0)
	if math.abs(complete.total - 100) > 1e-9 then
		badTotal = "collection complete"
	end
	t.equal("le total fait 100 % a tous les etats de la collection", badTotal, nil)
	t.equal("et il y a toujours au moins une ligne", emptyLines, nil)

	t.check("collection complete : une seule ligne", #complete.lines == 1)
	t.check(
		"et elle annonce les fragments",
		string.find(complete.lines[1].label, "fragments", 1, true) ~= nil
	)

	-- EXIGENCE ROBLOX : les cotes se mettent a jour quand la garantie est
	-- active. C'est un modificateur de probabilite, donc son effet doit etre
	-- visible AVANT l'achat.
	local half: { [string]: boolean } = {}
	for index, item in Config.items do
		if index <= 6 then
			half[item.id] = true
		end
	end

	local normal = Draws.odds(Config, half, 0)
	t.equal("a mi-collection, deux lignes", #normal.lines, 2)
	t.check("et le total fait 100 %", math.abs(normal.total - 100) < 1e-9)
	t.check("la garantie n'est pas active", not normal.guaranteed)
	t.equal("il reste six tirages avant elle", normal.pullsUntilGuarantee, 6)

	local guaranteed = Draws.odds(Config, half, 6)
	t.check("au septieme tirage, la garantie est active", guaranteed.guaranteed)
	t.equal("les cotes passent a une seule ligne", #guaranteed.lines, 1)
	t.equal("a 100 % d'objet neuf", guaranteed.lines[1].percent, 100)
	t.check("et le texte explique la garantie chiffree", string.find(guaranteed.note, "7") ~= nil)

	-- EXIGENCE ROBLOX : aucun resultat ne rend rien.
	local empty: string? = nil
	for _, state in { odds, normal, guaranteed, complete } do
		for _, line in state.lines do
			if line.percent > 0 and line.label == "" then
				empty = line.detail
			end
		end
	end
	t.equal("chaque resultat possible porte un libelle", empty, nil)

	t.section("La garantie tombe vraiment")

	-- Un hasard qui rend toujours le dernier objet : avec une collection ou
	-- seul le dernier est possede, chaque tirage normal est donc un doublon,
	-- et seule la garantie peut rendre du neuf.
	local justLast: { [string]: boolean } = {}
	justLast[Config.items[#Config.items].id] = true

	local counter = 0
	local news = 0
	for _ = 1, Config.draws.guaranteedNewEveryDraws do
		local result = Draws.draw(Config, justLast, counter, last)
		counter = result.pullsSinceNew
		if result.isNew then
			news += 1
		end
	end
	t.equal("sur sept tirages malchanceux, un objet neuf tombe", news, 1)
	t.equal("et le compteur est reparti a zero", counter, 0)

	local duplicate = Draws.draw(Config, justLast, 0, last)
	t.check("un doublon n'est pas neuf", not duplicate.isNew)
	t.equal("et il donne des fragments", duplicate.fragments, 50)
	t.equal("le compteur avance", duplicate.pullsSinceNew, 1)

	local fresh = Draws.draw(Config, justLast, 0, first)
	t.check("un objet neuf est neuf", fresh.isNew)
	t.equal("et il ne donne pas de fragments", fresh.fragments, 0)
	t.equal("le compteur repart a zero", fresh.pullsSinceNew, 0)

	-- Collection complete : la garantie ne peut plus rien garantir, et le
	-- tirage doit continuer a fonctionner plutot que de boucler ou de planter.
	local full = Draws.draw(Config, owned, 99, first)
	t.check("collection complete : le tirage rend un doublon", not full.isNew)
	t.equal("et des fragments", full.fragments, 50)

	local nextOwned, nextFragments = Draws.apply(justLast, 100, duplicate)
	t.equal("appliquer un doublon ajoute ses fragments", nextFragments, 150)
	t.check("et ne retire rien de la collection", nextOwned[Config.items[#Config.items].id] == true)

	t.section("Les trois tirages d'ouverture")

	local starter = Draws.starterItems(Config, first)
	t.equal("trois objets offerts", #starter, #Config.draws.starterDrawsCategories)

	-- LE PIEGE : si le plafond de cout descend sous l'arme principale la moins
	-- chere, la categorie n'a plus de candidat et le debutant demarre SANS
	-- ARME. Ca ne se voit qu'au premier compte cree, c'est-a-dire jamais.
	local missing: string? = nil
	local tooExpensive: string? = nil
	for _, categoryId in Config.draws.starterDrawsCategories do
		local count = 0
		for _, item in Loadout.byCategory(Config, categoryId) do
			if item.cost <= Config.draws.starterDrawsMaxItemCost then
				count += 1
			end
		end
		if count == 0 then
			missing = categoryId
		end
	end
	for _, itemId in starter do
		local item = Loadout.find(Config, itemId)
		if item ~= nil and item.cost > Config.draws.starterDrawsMaxItemCost then
			tooExpensive = itemId
		end
	end
	t.equal("chaque categorie d'ouverture a un candidat", missing, nil)
	t.equal("et aucun objet offert ne depasse le plafond", tooExpensive, nil)

	-- Ce qu'on offre doit former un assemblage legal : un debutant ne doit pas
	-- decouvrir le jeu avec des objets qu'il ne peut pas porter ensemble.
	local starterCheck = Loadout.validate(Config, starter, nil)
	t.check("les trois objets offerts forment un assemblage legal", starterCheck.ok)
	t.check("et il reste des points a depenser", starterCheck.left > 0)

	t.section("Le classement")

	t.equal("on demarre a 1000", Rating.starting(Config), 1000)
	t.equal("un debutant a K = 64", Rating.kFactor(Config, 0), 64)
	t.equal("a dix parties encore 64", Rating.kFactor(Config, 10), 64)
	t.equal("a onze parties, 48", Rating.kFactor(Config, 11), 48)
	t.equal("a quarante, 48", Rating.kFactor(Config, 40), 48)
	t.equal("au-dela, 32", Rating.kFactor(Config, 41), 32)
	t.equal("et tres au-dela, toujours 32", Rating.kFactor(Config, 5000), 32)

	t.check("a egalite, une chance sur deux", math.abs(Rating.expected(1000, 1000) - 0.5) < 1e-9)
	t.check(
		"400 points d'ecart valent dix contre un",
		math.abs(Rating.expected(1400, 1000) - (10 / 11)) < 1e-6
	)

	local rookie = { rating = 1000, matchesPlayed = 0 }
	local beatStronger = Rating.update(Config, rookie, 1400, 1)
	local beatWeaker = Rating.update(Config, rookie, 600, 1)
	t.check("battre plus fort que soi rapporte gros", beatStronger.delta > 50)
	t.check("battre plus faible que soi rapporte peu", beatWeaker.delta < 10)
	t.check("et les deux font monter", beatStronger.delta > 0 and beatWeaker.delta > 0)

	local lostToStronger = Rating.update(Config, rookie, 1400, 0)
	local lostToWeaker = Rating.update(Config, rookie, 600, 0)
	t.check("perdre contre plus fort coute peu", lostToStronger.delta > -10)
	t.check("perdre contre plus faible coute cher", lostToWeaker.delta < -50)

	-- Un habitue bouge moins qu'un debutant sur exactement la meme partie.
	local veteran = { rating = 1000, matchesPlayed = 100 }
	local veteranWin = Rating.update(Config, veteran, 1400, 1)
	t.check("un habitue bouge moins qu'un debutant", veteranWin.delta < beatStronger.delta)

	-- Une partie entiere : trois contre trois, l'equipe A gagne.
	local entries = {
		a1 = { rating = 1200, matchesPlayed = 50 },
		a2 = { rating = 1000, matchesPlayed = 50 },
		a3 = { rating = 800, matchesPlayed = 50 },
		b1 = { rating = 1000, matchesPlayed = 50 },
		b2 = { rating = 1000, matchesPlayed = 50 },
		b3 = { rating = 1000, matchesPlayed = 50 },
	}
	local teams = { a1 = "A", a2 = "A", a3 = "A", b1 = "B", b2 = "B", b3 = "B" }
	local changes = Rating.applyMatch(Config, entries, teams, "A")

	local winnersUp = true
	local losersDown = true
	for key, change in changes do
		if teams[key] == "A" and change.delta <= 0 then
			winnersUp = false
		end
		if teams[key] == "B" and change.delta >= 0 then
			losersDown = false
		end
	end
	t.check("tous les gagnants montent", winnersUp)
	t.check("tous les perdants descendent", losersDown)

	-- Les deux equipes sont a 1000 de moyenne, donc la partie etait equilibree
	-- et ce qui monte d'un cote descend de l'autre.
	local sum = 0
	for _, change in changes do
		sum += change.delta
	end
	t.check("a moyennes egales, le classement est a somme nulle", math.abs(sum) < 1e-6)

	-- Le plus faible de l'equipe gagnante gagne le plus : il etait le moins
	-- attendu a gagner. C'est ce qui rend le classement juste quand on ne
	-- choisit pas ses coequipiers.
	t.check("le plus faible des gagnants gagne le plus", changes.a3.delta > changes.a1.delta)

	-- Une partie sans adversaire ne doit RIEN couter. Sans garde-fou, la
	-- moyenne d'une liste vide vaut zero, l'adversaire est note zero, et la
	-- defaite coute le coefficient K entier : un joueur reste seul sur un
	-- serveur perdrait sa soiree de classement sans avoir joue contre
	-- personne. Vu en jeu, le 25 octobre 2026.
	local alone = { solo = { rating = 1000, matchesPlayed = 0 } }
	local soloTeam = { solo = "A" }
	local soloWin = Rating.applyMatch(Config, alone, soloTeam, "A")
	local soloLoss = Rating.applyMatch(Config, alone, soloTeam, "B")
	t.equal("gagner sans adversaire ne rapporte rien", soloWin.solo, nil)
	t.equal("et perdre sans adversaire ne coute rien", soloLoss.solo, nil)

	t.check("le classe est le mode par defaut", Rating.counts(Config, false))
	t.check("les parties privees ne comptent pas", not Rating.counts(Config, true))
	t.check("le miroir du 1v1 est classe", Config.elo.mirrorRanked)

	-- LES PIECES SUIVENT LE CLASSEMENT. Les deux interrupteurs ont ete ecrits
	-- le meme jour et lus par personne pendant des semaines : Rating.counts
	-- existait, etait teste ici, et aucun service ne l'appelait — donc une
	-- partie d'essai entre amis deplacait les vrais classements. Les deux
	-- repondent maintenant a Venue.isPrivate dans ProgressService.awardMatch.
	t.check("une partie publique paie", Economy.paysIn(Config, false))
	t.check("une partie privee ne paie pas", not Economy.paysIn(Config, true))
	t.equal(
		"et les deux interrupteurs disent la meme chose",
		Economy.paysIn(Config, true),
		Rating.counts(Config, true)
	)

	t.equal("un classement s'arrondit a l'entier", Rating.rounded(1042.6), 1043)
end
