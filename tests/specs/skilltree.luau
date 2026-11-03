--!strict
--[[
	Tests de l'arbre de competences.

	Trois choses sont verifiees ici, et ce sont celles qui cassent l'equilibrage
	si elles derivent :

	  - combien de points une partie donne vraiment, selon qu'elle est courte
	    ou serree. C'est ce qui decide si le palier 6 vaut la peine d'exister.
	  - que le sacrifice d'une branche tombe une seule fois et ne se cumule pas
	    d'une manche a l'autre.
	  - que le point de revanche reste une option et pas un rattrapage
	    automatique.
]]

local Combat = require("../../src/shared/Combat")
local Config = require("../../src/shared/Config")
local Modifiers = require("../../src/shared/Modifiers")
local MatchState = require("../../src/shared/MatchState")
local SkillTree = require("../../src/shared/SkillTree")

local harness = require("../harness")

return function(t: harness.Harness)
	local tree = Config.skillTree

	t.section("Le cout d'une branche complete")

	t.equal("aller au bout coute six points", SkillTree.fullBranchCost(Config), 6)
	t.equal("le premier palier est gratuit", tree.tierCosts[1], 0)
	t.equal("le dernier en coute deux", tree.tierCosts[tree.tiers], 2)

	t.section("Combien de points une partie donne")

	-- Une partie de M manches donne M points utilisables : un avant la
	-- premiere, puis un par fin de manche, et celui de la derniere ne sert
	-- plus a rien.
	t.equal("une partie de 4 manches donne 4 points", SkillTree.usablePoints(Config, 4), 4)
	t.equal("une partie de 7 manches en donne 7", SkillTree.usablePoints(Config, 7), 7)

	-- A quel palier on arrive avec N points, en montant tout ce qu'on peut.
	local function tierReachedWith(points: number): number
		local state = SkillTree.create("vampire")
		state.pointsEarned = points
		SkillTree.chooseBranch(Config, state, "leech")
		while SkillTree.advance(Config, state) do
		end
		return state.tier
	end

	-- Une victoire nette en 4 manches : la serie courte n'ouvre pas le palier
	-- 6, et c'est ce qui donne son prix a une serie qui va au bout.
	t.equal("une victoire 4-0 mene au palier 5", tierReachedWith(4), 5)
	t.equal("une serie complete de 7 manches ouvre le palier 6", tierReachedWith(7), 6)
	t.check("et il reste un point en reserve", 7 - SkillTree.fullBranchCost(Config) == 1)

	t.section("Le choix de branche")

	local state = SkillTree.create("vampire")
	t.equal("on commence sans branche", state.branchId, nil)
	t.equal("et au palier zero", state.tier, 0)
	t.check("on ne peut pas monter sans branche", SkillTree.canAdvance(Config, state) == false)

	t.check(
		"une branche inconnue est refusee",
		SkillTree.chooseBranch(Config, state, "inexistante") == false
	)
	t.check(
		"choisir une vraie branche marche",
		SkillTree.chooseBranch(Config, state, "leech") == true
	)
	t.equal("le palier 1 est atteint tout de suite", state.tier, 1)
	t.equal("et il n'a rien coute", state.pointsSpent, 0)

	-- Le verrou : la fiche dit que le choix tient jusqu'a la fin de la partie.
	t.check(
		"on ne change plus de branche ensuite",
		SkillTree.chooseBranch(Config, state, "beast") == false
	)
	t.equal("la branche n'a pas bouge", state.branchId, "leech")

	t.section("Monter les paliers")

	t.check("sans point, on ne monte pas", SkillTree.canAdvance(Config, state) == false)
	SkillTree.grantStartingPoints(Config, state)
	t.equal("un point avant la premiere manche", SkillTree.availablePoints(state), 1)
	t.check("et on peut monter", SkillTree.advance(Config, state) == true)
	t.equal("palier 2", state.tier, 2)
	t.equal("le point est depense", SkillTree.availablePoints(state), 0)

	state.pointsEarned += 10
	while SkillTree.advance(Config, state) do
	end
	t.equal("avec assez de points on va au bout", state.tier, tree.tiers)
	t.check("et la branche est terminee", SkillTree.isComplete(Config, state) == true)
	t.equal("il n'y a plus de palier suivant", SkillTree.costOfNextTier(Config, state), nil)
	t.check("on ne monte plus", SkillTree.advance(Config, state) == false)
	t.equal("le total depense fait bien six", state.pointsSpent, 6)

	t.section("Le point de revanche")

	local loser = SkillTree.create("colossus")
	SkillTree.grantRoundEnd(Config, loser, false)
	SkillTree.grantRoundEnd(Config, loser, false)
	t.equal("deux defaites ne declenchent rien", loser.pointsEarned, tree.pointsPerRoundEnd * 2)
	t.check("et rien n'est consomme", loser.comebackUsed == false)

	local granted = SkillTree.grantRoundEnd(Config, loser, false)
	t.equal(
		"la troisieme defaite d'affilee donne un point de plus",
		granted,
		tree.pointsPerRoundEnd + tree.comebackPoint.points
	)
	t.check("le point de revanche est consomme", loser.comebackUsed == true)

	SkillTree.grantRoundEnd(Config, loser, false)
	local again = SkillTree.grantRoundEnd(Config, loser, false)
	t.equal("il ne revient pas une seconde fois dans la partie", again, tree.pointsPerRoundEnd)

	-- Une victoire remet le compteur a zero : la revanche recompense une serie
	-- noire, pas un cumul de defaites eparpillees.
	local mixed = SkillTree.create("vampire")
	SkillTree.grantRoundEnd(Config, mixed, false)
	SkillTree.grantRoundEnd(Config, mixed, false)
	SkillTree.grantRoundEnd(Config, mixed, true)
	t.equal("une victoire efface la serie", mixed.consecutiveLosses, 0)
	SkillTree.grantRoundEnd(Config, mixed, false)
	t.check("et la revanche n'est pas declenchee", mixed.comebackUsed == false)

	t.section("Le sacrifice tombe une fois, les crans s'empilent")

	local base = Config.classStats.vampire
	local leech = SkillTree.findBranch(Config, "vampire", "leech")

	local atOne = Modifiers.apply(Config, base, leech, 1)
	local atFive = Modifiers.apply(Config, base, leech, 5)
	local atSix = Modifiers.apply(Config, base, leech, 6)

	t.equal(
		"le sacrifice est le meme au palier 1 et au palier 5",
		atOne.attackDamage,
		atFive.attackDamage - 0
	)
	t.check("les degats ont bien baisse", atOne.attackDamage < base.attackDamage)
	t.check("le vol de vie monte avec les paliers", atFive.lifestealRatio > atOne.lifestealRatio)
	t.equal("le palier 6 n'ajoute pas de cran", atSix.lifestealRatio, atFive.lifestealRatio)
	t.equal("les statistiques de base ne sont jamais ecrasees", base.lifestealRatio, 0.35)

	t.section("Chaque branche fait vraiment ce qu'elle annonce")

	local beast = SkillTree.findBranch(Config, "vampire", "beast")
	local beastFive = Modifiers.apply(Config, base, beast, 5)
	t.check("le Fauve va plus vite", beastFive.walkSpeed > base.walkSpeed)
	t.check("il frappe plus fort", beastFive.attackDamage > base.attackDamage)
	t.check("et son vol de vie est bien ampute", beastFive.lifestealRatio < base.lifestealRatio)

	local plague = SkillTree.findBranch(Config, "vampire", "plague")
	local plagueOne = Modifiers.apply(Config, base, plague, 1)
	t.equal("la Peste supprime tout le vol de vie", plagueOne.lifestealRatio, 0)

	local colossusBase = Config.classStats.colossus
	local ram = SkillTree.findBranch(Config, "colossus", "ram")
	local ramFive = Modifiers.apply(Config, colossusBase, ram, 5)
	t.check("le Belier perd des PV", ramFive.maxHealth < colossusBase.maxHealth)
	t.check("et pousse plus fort", ramFive.knockbackStuds > colossusBase.knockbackStuds)

	local catapult = SkillTree.findBranch(Config, "colossus", "catapult")
	local catapultOne = Modifiers.apply(Config, colossusBase, catapult, 1)
	local catapultFive = Modifiers.apply(Config, colossusBase, catapult, 5)
	t.equal("la Catapulte perd sa poussee au contact", catapultOne.knockbackStuds, 0)
	t.check(
		"et frappe de plus en plus loin",
		catapultFive.attackRangeStuds > colossusBase.attackRangeStuds
	)

	-- La charge du Belier ne compte que si la poussee existe : la Catapulte,
	-- qui n'a plus de poussee, ne doit pas encaisser de degats de charge.
	t.equal(
		"la Catapulte ne porte aucune charge",
		Combat.rawDamage(catapultFive),
		catapultFive.attackDamage
	)
	t.check("le Belier, lui, en porte une", Combat.rawDamage(ramFive) > ramFive.attackDamage)

	local monolith = SkillTree.findBranch(Config, "colossus", "monolith")
	local monolithFive = Modifiers.apply(Config, colossusBase, monolith, 5)
	t.check("le Monolithe reduit les degats recus", monolithFive.damageTakenRatio < 0)
	t.check(
		"et cette reduction se voit vraiment sur un coup",
		Combat.damageTaken(Config, monolithFive, 100) < 100
	)
	t.check(
		"mais elle ne rend jamais invulnerable",
		Combat.damageTaken(Config, monolithFive, 100) > 0
	)

	local plagueFive = Modifiers.apply(Config, base, plague, 5)
	t.check("la Peste propage vraiment", Combat.spreadsDamage(plagueFive))
	t.check("et la classe nue ne propage rien", Combat.spreadsDamage(base) == false)

	t.section("Les planchers tiennent")

	local brutal = {
		id = "test",
		onUnlock = { maxHealth = -10000, walkSpeed = -10000, attackDamage = -10000 },
	}
	local floored = Modifiers.apply(Config, colossusBase, brutal, 3)
	t.check("personne ne tombe a zero PV", floored.maxHealth > 0)
	t.check("personne n'est immobilise par une branche", floored.walkSpeed > 0)
	t.check("et tout le monde fait au moins un degat", floored.attackDamage > 0)

	t.section("Le palier 6 ne ment pas")

	-- UN EFFET MARQUE NON CODE NE DOIT PAS S'ACTIVER. Il doit se declarer
	-- indisponible, pas ne rien faire en silence : un palier 6 coute deux points
	-- et demande une serie de sept manches, donc un effet creux ne se verrait
	-- jamais en jouant.
	--
	-- On ne nomme PAS la branche en dur. Celle qui servait d'exemple ici etait la
	-- Peste, et elle a ete codee le 27 octobre 2026 des que les armures ont
	-- existe : le test tombait alors sur son propre exemple, pas sur un bug. On
	-- demande donc a Config qui attend encore.
	local pending = 0
	for classId, branches in tree.branches do
		for _, branch in branches do
			if branch.tier6 == nil or branch.tier6.implemented then
				continue
			end
			pending += 1
			local waiting = SkillTree.create(classId)
			SkillTree.chooseBranch(Config, waiting, branch.id)
			waiting.pointsEarned = 20
			while SkillTree.advance(Config, waiting) do
			end
			t.equal(
				"« "
					.. branch.tier6.effect
					.. " » est decrit mais pas code, donc il ne s'active pas",
				SkillTree.activeTier6Effect(Config, waiting),
				nil
			)
		end
	end

	-- Sans cette ligne, le jour ou tout sera code, la boucle ci-dessus ne
	-- verifierait plus rien et le dirait en passant.
	if pending == 0 then
		t.check("plus aucun palier 6 n'attend un systeme absent", true)
	end

	local coded = SkillTree.create("vampire")
	SkillTree.chooseBranch(Config, coded, "leech")
	coded.pointsEarned = 20
	while SkillTree.advance(Config, coded) do
	end
	t.equal("un effet code s'active", SkillTree.activeTier6Effect(Config, coded), "leechFromZone")

	t.section("Aucune branche ne pousse un chiffre que le combat ne lit pas")

	-- LE TEST LE PLUS IMPORTANT DE CE FICHIER.
	--
	-- Une branche qui fait monter `thrownRangeStuds` alors que rien dans le
	-- combat ne lit ce nom passe tous les autres tests, s'affiche correctement
	-- dans l'interface, et ne fait RIEN. Pire : son sacrifice s'applique quand
	-- meme, donc la branche rend le joueur plus faible en echange de zero.
	-- C'est exactement ce qui s'etait produit sur trois des six branches.
	--
	-- La regle que ce test fige : toute cle touchee par une branche doit exister
	-- dans les statistiques de base de la classe. Si on ajoute une statistique
	-- a une branche, il faut l'ajouter aux classes, donc le combat la verra.
	for classId, branches in tree.branches do
		local base = Config.classStats[classId]
		t.check(string.format("%s a des statistiques de base", classId), base ~= nil)

		for _, branch in branches do
			local blocks = {
				onUnlock = branch.onUnlock,
				onUnlockScale = branch.onUnlockScale,
				onUnlockSet = branch.onUnlockSet,
				perTier = branch.perTier,
			}

			for blockName, block in blocks do
				for key in block or {} do
					t.check(
						string.format(
							"%s / %s : %s.%s existe sur la classe",
							classId,
							branch.id,
							blockName,
							key
						),
						base[key] ~= nil
					)
				end
			end
		end
	end

	t.section("Chaque branche change vraiment quelque chose a chaque palier")

	-- Une branche dont le palier 3 ne change rien par rapport au palier 2 fait
	-- payer un point pour rien. Le palier 6 est exclu : il ne donne pas de cran,
	-- il donne l'effet nomme.
	for classId, branches in tree.branches do
		local base = Config.classStats[classId]
		for _, branch in branches do
			local differentAtEachTier = true
			for tier = 2, tree.tiers - 1 do
				local before = Modifiers.apply(Config, base, branch, tier - 1)
				local after = Modifiers.apply(Config, base, branch, tier)
				if #Modifiers.differences(before, after) == 0 then
					differentAtEachTier = false
				end
			end
			t.check(
				string.format(
					"%s / %s : aucun palier ne coute un point pour rien",
					classId,
					branch.id
				),
				differentAtEachTier
			)
		end
	end

	t.section("Les branches des quatorze classes sont bien formees")

	-- Toutes les classes, pas seulement celles du prototype : une classe tiree
	-- au sort dont l'arbre est incomplet donne un joueur qui ne peut pas
	-- depenser ses points, et ca ne se voit qu'en jeu.
	local classIds: { string } = {}
	for classId in Config.classStats do
		table.insert(classIds, classId)
	end
	table.sort(classIds)
	t.equal("quatorze classes ont un arbre", #classIds, 14)

	for _, classId in classIds do
		local branches = SkillTree.branchesFor(Config, classId)
		t.equal(string.format("%s a trois branches", classId), #branches, 3)

		local kinds: { [string]: number } = {}
		for _, branch in branches do
			kinds[branch.kind] = (kinds[branch.kind] or 0) + 1
			t.check(
				string.format("%s / %s est complete", classId, branch.id),
				branch.name ~= nil
					and branch.summary ~= nil
					and branch.sacrifice ~= nil
					and branch.tier6 ~= nil
					and branch.tier6.label ~= nil
					and branch.tier6.effect ~= nil
			)
		end

		-- Une branche d'identite, une de distance, une de resilience : trois
		-- problemes differents, pas trois saveurs du meme pouvoir.
		t.check(
			string.format("%s couvre les trois questions", classId),
			kinds.identity == 1 and kinds.range == 1 and kinds.resilience == 1
		)
	end

	t.section("Aucun palier 6 ne promet deux fois la meme chose")

	-- Deux branches qui nomment le meme effet, c'est presque toujours une
	-- copie oubliee : la seconde ferait ce que la premiere fait deja, et le
	-- joueur paierait deux points pour un effet qu'il a peut-etre deja.
	local seenEffects: { [string]: string } = {}
	for classId, branches in tree.branches do
		for _, branch in branches do
			local effect = branch.tier6.effect
			t.check(
				string.format("%s / %s : effet de palier 6 unique", classId, branch.id),
				seenEffects[effect] == nil
			)
			seenEffects[effect] = classId .. "/" .. branch.id
		end
	end

	t.section("Les points en reserve")

	do
		local classId = "vampire"
		local branch = SkillTree.branchesFor(Config, classId)[1]
		local state = SkillTree.create(classId)
		state.pointsEarned = SkillTree.fullBranchCost(Config) + 2
		SkillTree.chooseBranch(Config, state, branch.id)

		local first = Config.skillTree.sparePointUpgrades[1]
		t.equal(
			"rien a acheter tant que la branche n'est pas finie",
			SkillTree.canBuySpare(Config, state, first.id),
			false
		)
		while SkillTree.advance(Config, state) do
		end
		t.equal("la branche est finie", SkillTree.isComplete(Config, state), true)
		t.equal("il reste deux points", SkillTree.availablePoints(state), 2)
		t.equal("une amelioration s'achete", SkillTree.buySpare(Config, state, first.id), true)
		t.equal("et coute ses points", SkillTree.availablePoints(state), 2 - first.cost)
		t.equal(
			"un identifiant inconnu ne s'achete pas",
			SkillTree.buySpare(Config, state, "nimporte"),
			false
		)
		SkillTree.buySpare(Config, state, first.id)
		t.equal(
			"sans point, plus rien ne s'achete",
			SkillTree.buySpare(Config, state, first.id),
			false
		)

		local deltas = SkillTree.spareDeltas(Config, state)
		t.equal(
			"deux achats donnent deux fois le gain",
			deltas.offset[first.stat],
			first.amount * 2
		)

		-- Le meme garde-fou que les branches creuses : une amelioration qui
		-- pousse une statistique que la classe n'a pas ne ferait rien, et son
		-- point serait perdu en silence.
		for id in Config.classStats do
			local offered = 0
			for _, upgrade in Config.skillTree.sparePointUpgrades do
				if SkillTree.spareApplies(Config, id, upgrade) then
					offered += 1
				else
					local probe = SkillTree.create(id)
					probe.tier = Config.skillTree.tiers
					probe.pointsEarned = 99
					t.equal(
						string.format(
							"%s n'est pas proposee a %s, qui n'a pas %s",
							upgrade.id,
							id,
							upgrade.stat
						),
						SkillTree.canBuySpare(Config, probe, upgrade.id),
						false
					)
				end
			end
			t.equal(id .. " a au moins deux ameliorations possibles", offered >= 2, true)
		end

		-- Et le chiffre arrive bien dans les statistiques, planchers compris.
		local base = Config.classStats[classId]
		local withTree = Modifiers.apply(Config, base, branch, state.tier)
		local final = Modifiers.applyDeltas(withTree, deltas)
		t.equal(
			"les PV de reserve s'ajoutent apres la branche",
			final[first.stat],
			withTree[first.stat] + first.amount * 2
		)
	end

	t.section("Une partie longue laisse bien des points en reserve")

	-- Sans ce test, les ameliorations seraient un ecran que personne n'atteint.
	t.equal(
		"une partie au maximum de manches donne plus que l'arbre complet",
		Config.skillTree.pointsBeforeFirstRound
				+ Config.skillTree.pointsPerRoundEnd * (MatchState.maxRounds(
					MatchState.create(MatchState.roundsToWin(Config))
				) - 1)
			> SkillTree.fullBranchCost(Config),
		true
	)
end
