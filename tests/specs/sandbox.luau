--!strict
--[[
	Tests du bac a sable.

	CE QUE CES TESTS ATTRAPENT, et que personne ne verrait en jouant :

	  - une classe de depart ou de mannequin qui n'existe pas. Le joueur
	    arriverait sans PV et sans attaque, ou le stand de tir serait vide, et
	    rien ne le signalerait. (Le serveur refuse aussi de demarrer, mais une
	    faute de frappe dans Config doit se voir en deux secondes de test, pas
	    en lancant Studio.)
	  - un budget de bac a sable PLUS PETIT que celui du jeu. Ce serait l'exact
	    contraire du but : on vient ici pour comparer deux armes cheres dans la
	    meme minute.
	  - un garde-fou desactive par inadvertance. `maxPlayers` a deux ouvrirait
	    le bac a sable au milieu d'une vraie partie, avec le choix de classe et
	    les points d'arbre gratuits.
	  - une rangee de mannequins qui se chevauche, ou posee hors de portee de
	    toutes les armes.
]]

local Config = require("../../src/shared/Config")

local harness = require("../harness")

return function(t: harness.Harness)
	local rules = Config.sandbox

	t.section("Les garde-fous tiennent")

	-- LE test. Le bac a sable donne le choix de la classe, des points d'arbre
	-- gratuits et un budget de soixante points : il ne doit jamais pouvoir
	-- s'ouvrir avec deux joueurs, sinon c'est une partie truquee.
	t.equal("le bac à sable ne s'ouvre que seul", rules.maxPlayers, 1)
	t.equal(
		"et la fenêtre de dépense ne reste ouverte que là",
		Config.skillTree.spendWindowSeconds < rules.spendWindowSeconds,
		true
	)

	t.section("Les classes nommées existent")

	t.equal(
		"la classe de départ est une vraie classe",
		Config.classStats[rules.startingClassId] ~= nil,
		true
	)
	t.equal("celle du mannequin aussi", Config.classStats[rules.dummy.classId] ~= nil, true)

	t.section("Le budget relevé est bien relevé")

	t.equal("plus de points qu'en partie", rules.budgetPoints > Config.loadout.budgetPoints, true)
	t.equal("et plus d'objets", rules.maxItems > Config.loadout.maxItems, true)

	-- De quoi porter les deux armes les plus cheres a la fois, sinon le budget
	-- releve ne sert a rien.
	local worst = 0
	for _, item in Config.items do
		if item.category == "primary" or item.category == "secondary" then
			worst = math.max(worst, item.cost)
		end
	end
	t.equal(
		"de quoi porter les deux armes les plus chères et une armure",
		rules.budgetPoints >= worst * 2 + 5,
		true
	)

	-- Les limites par categorie du bac a sable ne doivent jamais etre PLUS
	-- serrees que celles du jeu : on ne vient pas ici pour avoir moins.
	for categoryId, limit in Config.loadout.maxPerCategory do
		local relaxed = rules.maxPerCategory[categoryId]
		t.equal(
			"« " .. categoryId .. " » n'est pas plus serré qu'en partie",
			relaxed ~= nil and relaxed >= limit,
			true
		)
	end

	t.section("La rangée de mannequins est jouable")

	local dummy = rules.dummy
	t.equal("au moins un mannequin possible", dummy.maxCount >= 1, true)
	t.equal(
		"et le nombre de départ tient dans le maximum",
		dummy.startingCount >= 0 and dummy.startingCount <= dummy.maxCount,
		true
	)

	-- Deux studs de large pour un mannequin : moins de trois studs d'ecart et
	-- ils se touchent, donc on ne sait plus lequel on frappe.
	t.equal("ils ne se chevauchent pas", dummy.spacingStuds >= 3, true)

	-- La rangee doit etre HORS de portee de la plus courte des armes, pour
	-- qu'on ait a avancer au corps-a-corps, et DANS celle de la plus longue,
	-- pour qu'on puisse tirer sans bouger. Sans ces deux conditions, le stand
	-- de tir ne dit rien de la portee, qui est justement ce qu'on vient y
	-- mesurer.
	--
	-- Une arme ne porte pas une portee, elle porte un FACTEUR : la portee
	-- reelle est celle de la classe multipliee par lui. Il faut donc balayer
	-- les deux listes, et c'est le genre de calcul qu'un test fait en deux
	-- secondes et qu'un oeil ne fait jamais.
	local shortest = math.huge
	local longest = 0
	local combinations = 0
	for _, stats in Config.classStats do
		for _, item in Config.items do
			if item.category ~= "primary" then
				continue
			end
			local factor = 1
			if item.scale ~= nil and typeof(item.scale.attackRangeStuds) == "number" then
				factor = item.scale.attackRangeStuds
			end
			local reach = stats.attackRangeStuds * factor
			shortest = math.min(shortest, reach)
			longest = math.max(longest, reach)
			combinations += 1
		end
	end

	t.equal("il y a bien des armes à mesurer", combinations > 0, true)
	t.equal(
		"la rangée est à portée de l'arme la plus longue",
		dummy.distanceStuds < longest,
		true
	)
	t.equal(
		"et hors de portée de la plus courte, donc il faut avancer",
		dummy.distanceStuds > shortest,
		true
	)

	t.section("Le retour des mannequins et du joueur")

	t.equal("le mannequin revient tout seul", dummy.respawnSeconds > 0, true)
	t.equal(
		"et le joueur est remis debout, puisque personne ne peut le relever",
		rules.reviveSeconds > 0,
		true
	)
	-- Plus long que la fenetre d'agonie et le relevement automatique
	-- arriverait apres l'elimination, ce qui est exactement ce qu'on veut
	-- pouvoir regarder : l'agonie doit avoir lieu, pas etre escamotee.
	t.equal(
		"le relèvement n'escamote pas l'agonie",
		rules.reviveSeconds < Config.downed.windowSeconds,
		true
	)
end
