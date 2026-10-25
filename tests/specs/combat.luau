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
end
