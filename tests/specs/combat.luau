--!strict
--[[
	Tests du calcul de combat.

	Ces tests prennent les vraies statistiques du prototype dans Config : si
	quelqu'un change le vol de vie du Vampire, les chiffres attendus ici
	suivent, mais les regles verifiees restent les memes. Ce qui est teste,
	c'est que le pouvoir et la faiblesse de chaque classe existent vraiment
	dans le calcul, pas qu'ils valent une valeur precise.
]]

local Combat = require("../../src/shared/Combat")
local Config = require("../../src/shared/Config")

local harness = require("../harness")

local vampire = Config.classStats.vampire
local colossus = Config.classStats.colossus

return function(t: harness.Harness)
	t.section("Le pouvoir du Vampire")

	local hit = Combat.resolveHit({
		attackerStats = vampire,
		attackerHealth = 50,
		defenderStats = colossus,
		defenderHealth = colossus.maxHealth,
	})

	t.equal("le coup inflige ses degats", hit.damage, vampire.attackDamage)
	t.equal(
		"il se soigne d'une part des degats infliges",
		hit.healed,
		vampire.attackDamage * vampire.lifestealRatio
	)
	t.equal("ses PV montent d'autant", hit.attackerHealth, 50 + hit.healed)
	t.check("le vol de vie est strictement positif", hit.healed > 0)
	t.check("la cible n'est pas a terre", hit.defenderDown == false)

	t.section("Les limites du vol de vie")

	local full = Combat.resolveHit({
		attackerStats = vampire,
		attackerHealth = vampire.maxHealth,
		defenderStats = colossus,
		defenderHealth = colossus.maxHealth,
	})
	t.equal("pas de surcharge a PV plein", full.healed, 0)
	t.equal("les PV restent au maximum", full.attackerHealth, vampire.maxHealth)

	local almostFull = Combat.resolveHit({
		attackerStats = vampire,
		attackerHealth = vampire.maxHealth - 1,
		defenderStats = colossus,
		defenderHealth = colossus.maxHealth,
	})
	t.equal("le soin est plafonne aux PV manquants", almostFull.healed, 1)

	-- Un coup qui depasse les PV restants ne compte que pour ce qu'il a
	-- vraiment enleve : sinon le Vampire se soigne sur des degats fictifs.
	local overkill = Combat.resolveHit({
		attackerStats = vampire,
		attackerHealth = 10,
		defenderStats = colossus,
		defenderHealth = 5,
	})
	t.equal("les degats sont plafonnes aux PV restants", overkill.damage, 5)
	t.equal("le vol de vie suit les degats reels", overkill.healed, 5 * vampire.lifestealRatio)
	t.check("la cible est a terre", overkill.defenderDown == true)
	t.equal("ses PV ne descendent pas sous zero", overkill.defenderHealth, 0)

	t.section("Le Colosse ne vole pas de vie")

	local heavy = Combat.resolveHit({
		attackerStats = colossus,
		attackerHealth = 100,
		defenderStats = vampire,
		defenderHealth = vampire.maxHealth,
	})
	t.equal("il ne se soigne pas", heavy.healed, 0)
	t.equal("ses PV ne bougent pas", heavy.attackerHealth, 100)
	t.check("il frappe plus fort que le Vampire", colossus.attackDamage > vampire.attackDamage)
	t.check(
		"mais il frappe moins souvent",
		colossus.attackCooldownSeconds > vampire.attackCooldownSeconds
	)
	t.check("et il avance moins vite", colossus.walkSpeed < vampire.walkSpeed)
	t.check("son repoussement est reel", colossus.knockbackStuds > 0)

	t.section("La faiblesse du Vampire")

	t.equal(
		"il ne regenere rien hors combat, meme sur dix secondes",
		Combat.applyRegen(vampire, 40, 10),
		40
	)
	t.check("le Colosse, lui, regenere", Combat.applyRegen(colossus, 40, 10) > 40)
	t.equal(
		"la regeneration ne depasse pas les PV maximum",
		Combat.applyRegen(colossus, colossus.maxHealth - 1, 60),
		colossus.maxHealth
	)

	t.section("La recharge d'attaque")

	t.check("on peut frapper au premier coup", Combat.canAttack(vampire, 0, nil) == true)
	t.check(
		"on ne peut pas enchainer avant la recharge",
		Combat.canAttack(vampire, 0.1, 0) == false
	)
	t.check(
		"on peut frapper une fois la recharge ecoulee",
		Combat.canAttack(vampire, vampire.attackCooldownSeconds, 0) == true
	)

	t.section("Le duel est serre")

	-- Le temps que chacun met a tuer l'autre doit rester du meme ordre : si un
	-- cote tue deux fois plus vite, le duel n'a pas d'interet et il faut
	-- retoucher les chiffres avant meme de jouer.
	local vampireDps = vampire.attackDamage / vampire.attackCooldownSeconds
	local colossusDps = colossus.attackDamage / colossus.attackCooldownSeconds
	local vampireHeal = vampireDps * vampire.lifestealRatio

	local timeToKillColossus = colossus.maxHealth / vampireDps
	local timeToKillVampire = vampire.maxHealth / (colossusDps - vampireHeal)

	t.check(
		string.format(
			"le Vampire tue le Colosse en %.1f s, le Colosse en %.1f s",
			timeToKillColossus,
			timeToKillVampire
		),
		math.abs(timeToKillColossus - timeToKillVampire) < 4
	)
	t.check("le Colosse perce le vol de vie du Vampire", colossusDps > vampireHeal)
	t.section("La reduction de degats, et ses bornes")

	-- Monolithe : damageTakenRatio est negatif, donc les degats descendent.
	local tanky = table.clone(Config.classStats.colossus)
	tanky.damageTakenRatio = -0.25
	t.equal("une reduction de 25 % retire un quart", Combat.damageTaken(Config, tanky, 100), 75)

	-- Le garde-fou : une statistique qui peut atteindre zero finit toujours par
	-- y arriver, et un joueur invulnerable n'est plus un joueur.
	local absurd = table.clone(Config.classStats.colossus)
	absurd.damageTakenRatio = -10
	t.equal(
		"personne ne devient invulnerable",
		Combat.damageTaken(Config, absurd, 100),
		100 * Config.combat.damageTakenRatioMin
	)

	local fragile = table.clone(Config.classStats.colossus)
	fragile.damageTakenRatio = 10
	t.equal(
		"et personne ne prend plus que le plafond",
		Combat.damageTaken(Config, fragile, 100),
		100 * Config.combat.damageTakenRatioMax
	)

	t.section("Le vol de vie se calcule sur ce qui passe vraiment")

	local vampire = Config.classStats.vampire

	-- Un coup de 12 sur une cible a 3 PV ne doit soigner que de 3 x le ratio.
	local onLowTarget = Combat.resolveHit({
		attackerStats = vampire,
		attackerHealth = 50,
		defenderStats = Config.classStats.colossus,
		defenderHealth = 3,
		config = Config,
	})
	t.equal("les degats sont plafonnes aux PV restants", onLowTarget.damage, 3)
	t.equal("et le soin suit les degats passes", onLowTarget.healed, 3 * vampire.lifestealRatio)

	-- Et il ne soigne pas ce que la reduction de la cible a absorbe.
	local reduced = Combat.resolveHit({
		attackerStats = vampire,
		attackerHealth = 50,
		defenderStats = tanky,
		defenderHealth = 500,
		config = Config,
	})
	t.check(
		"une cible qui reduit soigne moins le Vampire",
		reduced.healed < vampire.attackDamage * vampire.lifestealRatio
	)

	t.section("La propagation et la charge")

	local plagued = table.clone(vampire)
	plagued.spreadRatio = 0.25
	plagued.spreadRadiusStuds = 8
	t.check("la Peste propage", Combat.spreadsDamage(plagued))
	t.equal("un quart du coup passe", Combat.spreadDamage(plagued, 40), 10)
	t.equal("un coup qui ne passe pas ne propage rien", Combat.spreadDamage(plagued, 0), 0)

	local charging = table.clone(Config.classStats.colossus)
	charging.knockbackDamage = 8
	t.equal(
		"la charge s'ajoute aux degats bruts",
		Combat.rawDamage(charging),
		charging.attackDamage + 8
	)

	-- Sans poussee, pas de charge : c'est ce qui rend « la poussee devient une
	-- charge qui blesse » litteralement vrai.
	local pushless = table.clone(charging)
	pushless.knockbackStuds = 0
	t.equal("sans poussee, pas de charge", Combat.rawDamage(pushless), pushless.attackDamage)

	t.section("Percer une armure")

	-- CE CALCUL VIVAIT DANS LE SERVEUR, OU RIEN NE LE TESTAIT. Il est sorti en
	-- logique pure le 27 octobre 2026 parce que DEUX effets s'en servent
	-- maintenant : l'arc composite, qui ignore la moitie de la reduction, et la
	-- propagation de la Peste au palier 6, qui l'ignore entierement.
	t.equal("sans perforation, la reduction reste entiere", Combat.piercedRatio(-0.28, 0), -0.28)
	t.equal("l'arc composite en ignore la moitie", Combat.piercedRatio(-0.28, 0.5), -0.14)
	t.equal("la Peste l'ignore entierement", Combat.piercedRatio(-0.28, 1), 0)

	-- LE GARDE-FOU QUI COMPTE. Une cible deja plus fragile que la normale a un
	-- ratio POSITIF : la percer la rendrait moins fragile, donc frapper une cible
	-- vulnerable ferait moins mal qu'un coup normal. C'est l'inverse de ce que le
	-- mot « percer » veut dire.
	t.equal("on ne perce pas une cible deja fragile", Combat.piercedRatio(0.4, 1), 0.4)
	t.equal("ni avec une perforation partielle", Combat.piercedRatio(0.4, 0.5), 0.4)
	t.equal("et une cible normale reste normale", Combat.piercedRatio(0, 1), 0)

	-- Et la borne haute : percer 150 % d'une armure transformerait la reduction
	-- en augmentation, donc un coup perce ferait PLUS mal que la cible nue.
	t.equal("une perforation ne depasse pas 100 %", Combat.piercedRatio(-0.28, 2.5), 0)

	t.section("La propagation de la Peste contre une armure")

	-- Le chemin complet, avec les vrais chiffres du catalogue : la cible porte
	-- l'armure lourde du jeu, et on regarde ce que la propagation lui passe.
	local armored = table.clone(colossus)
	local heavy = nil
	for _, item in Config.items do
		if item.id == "heavyArmor" then
			heavy = item
		end
	end
	t.check("l'armure lourde existe toujours dans le catalogue", heavy ~= nil)
	armored.damageTakenRatio = heavy.offset.damageTakenRatio

	local share = 10
	local reduced = Combat.damageTaken(Config, armored, share)
	local piercedStats = table.clone(armored)
	piercedStats.damageTakenRatio =
		Combat.piercedRatio(armored.damageTakenRatio, Config.tier6.spreadPiercesArmor.pierceRatio)
	local full = Combat.damageTaken(Config, piercedStats, share)

	t.check("l'armure lourde retire bien quelque chose", reduced < share)
	t.equal("la propagation du palier 6 passe la part entiere", full, share)
	t.check("donc elle fait strictement plus mal que sans le palier", full > reduced)
end
