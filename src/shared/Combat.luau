--!strict
--[[
	Combat — le calcul d'un coup porte, et la regeneration hors combat.

	Logique pure : aucun require, aucune API Roblox. Les statistiques arrivent
	en argument, donc un test peut verifier le vol de vie du Vampire sans
	charger Config et sans ouvrir Studio.

	Deux choix a connaitre :

	- Les degats sont plafonnes aux PV restants de la cible. Un coup de 24 sur
	  un adversaire a 10 PV compte pour 10, pas 24. C'est ce qui evite qu'un
	  Vampire se soigne sur des degats qu'il n'a pas vraiment infliges.
	- Le vol de vie ne depasse jamais les PV maximum : pas de surcharge.

	L'ORDRE D'UN COUP, et il ne change jamais :

	    degats bruts  =  attackDamage + la charge, si la poussee existe
	    puis          *  la reduction de la cible  (damageTakenRatio)
	    puis          plafonnes aux PV restants de la cible
	    et le vol de vie se calcule SUR CE QUI EST VRAIMENT PASSE.

	Cet ordre compte : si le vol de vie se calculait sur les degats bruts, un
	Vampire se soignerait de ce que l'armure de sa cible a absorbe.

	Quatre statistiques n'existent que par l'arbre de competences, et valent
	zero pour toutes les classes de base :

	    knockbackDamage    la poussee elle-meme blesse          (Belier)
	    damageTakenRatio   ajuste les degats recus, negatif = reduction (Monolithe)
	    spreadRatio        part du coup repercutee aux ennemis proches  (Peste)
	    spreadRadiusStuds  le rayon de cette repercussion               (Peste)
]]

local Combat = {}

export type Stats = {
	maxHealth: number,
	walkSpeed: number,
	attackDamage: number,
	attackCooldownSeconds: number,
	attackRangeStuds: number,
	lifestealRatio: number,
	knockbackStuds: number,
	knockbackUpStuds: number,
	regenPerSecond: number,
	-- Ouvertes par l'arbre seulement, zero partout ailleurs.
	knockbackDamage: number,
	damageTakenRatio: number,
	spreadRatio: number,
	spreadRadiusStuds: number,

	-- LES CHIFFRES DES POUVOIRS DE CLASSE.
	--
	-- Facultatifs, parce qu'une classe ne porte que les siens : le Traqueur n'a
	-- pas de mines et l'Artificier ne lit pas de traces. Les declarer ici plutot
	-- que dans un coin a part a une raison precise — ce sont des statistiques
	-- comme les autres, donc une branche d'arbre peut les pousser, l'interface
	-- sait deja les afficher, et le verificateur de types attrape les fautes de
	-- frappe. Leurs valeurs sont dans Config.classStats, avec la classe.
	ability: string?,
	abilityCooldownSeconds: number?,
	trackRadiusStuds: number?,
	trackAgeSeconds: number?,
	mineCount: number?,
	mineDamage: number?,
	mineRadiusStuds: number?,
	phaseSeconds: number?,
	bondShareRatio: number?,
	bondRangeStuds: number?,
	duelBonusRatio: number?,
	duelPenaltyRatio: number?,
	duelRadiusStuds: number?,
	wallSeconds: number?,
	wallWidthStuds: number?,
	wallHeightStuds: number?,
	fireDamagePerSecond: number?,
	fireSeconds: number?,
	fireRadiusStuds: number?,
	cloneSeconds: number?,
	cloneExposureRatio: number?,
	slamRadiusStuds: number?,
	slamSlowRatio: number?,
	slamSeconds: number?,
	markSeconds: number?,
	markHealStealRatio: number?,
	markRangeStuds: number?,
	cloakDelaySeconds: number?,
	cloakSpeedThreshold: number?,
	reviveSpeedRatio: number?,
	reviveHealthBonusRatio: number?,
}

export type HitInput = {
	attackerStats: Stats,
	attackerHealth: number,
	defenderStats: Stats,
	defenderHealth: number,
	-- La configuration, pour les bornes de la reduction de degats. Facultative :
	-- sans elle, la reduction s'applique telle quelle. Un module pur ne requiert
	-- rien, donc elle arrive en argument comme tout le reste.
	config: any?,
}

export type HitResult = {
	damage: number,
	healed: number,
	attackerHealth: number,
	defenderHealth: number,
	defenderDown: boolean,
}

-- Les degats bruts d'un coup, avant toute reduction.
--
-- La charge du Belier ne compte que si la poussee existe reellement : une
-- branche qui annule la poussee (la Catapulte) ne doit pas encaisser au passage
-- des degats de charge qu'elle ne porte plus. C'est aussi ce qui rend la phrase
-- « la poussee devient une charge qui blesse » litteralement vraie.
function Combat.rawDamage(stats: Stats): number
	local damage = stats.attackDamage
	if stats.knockbackStuds > 0 then
		damage += stats.knockbackDamage or 0
	end
	return damage
end

-- Les degats reellement recus par une cible, reduction comprise. Tout ce qui
-- retire des PV passe par ici : les coups, la zone, la propagation.
function Combat.damageTaken(config, defenderStats: Stats, amount: number): number
	local ratio = 1 + (defenderStats.damageTakenRatio or 0)

	if config ~= nil then
		ratio =
			math.clamp(ratio, config.combat.damageTakenRatioMin, config.combat.damageTakenRatioMax)
	end

	return math.max(amount * ratio, 0)
end

-- Ce qu'un coup repercute sur un ennemi proche (branche Peste). Se calcule sur
-- les degats VRAIMENT passes sur la cible principale, pas sur les degats bruts :
-- frapper un adversaire a un PV ne doit pas arroser ses coequipiers.
function Combat.spreadDamage(stats: Stats, damageDealt: number): number
	local ratio = stats.spreadRatio or 0
	if ratio <= 0 then
		return 0
	end
	return damageDealt * ratio
end

function Combat.spreadsDamage(stats: Stats): boolean
	return (stats.spreadRatio or 0) > 0 and (stats.spreadRadiusStuds or 0) > 0
end

-- Le soin rendu par le vol de vie, sur une quantite de degats deja passee.
function Combat.lifestealFor(stats: Stats, attackerHealth: number, damageDealt: number): number
	local missingHealth = stats.maxHealth - attackerHealth
	return math.clamp(damageDealt * stats.lifestealRatio, 0, math.max(missingHealth, 0))
end

function Combat.resolveHit(input: HitInput): HitResult
	local defenderHealth = math.max(input.defenderHealth, 0)

	local raw = Combat.rawDamage(input.attackerStats)
	local afterReduction = Combat.damageTaken(input.config, input.defenderStats, raw)
	local damage = math.min(afterReduction, defenderHealth)

	local healed = Combat.lifestealFor(input.attackerStats, input.attackerHealth, damage)
	local remaining = defenderHealth - damage

	return {
		damage = damage,
		healed = healed,
		attackerHealth = input.attackerHealth + healed,
		defenderHealth = remaining,
		defenderDown = remaining <= 0,
	}
end

-- Combien de PV une classe recupere en restant hors combat pendant ce temps.
-- Le Vampire a regenPerSecond a zero : c'est sa faiblesse, pas un oubli.
function Combat.applyRegen(stats: Stats, health: number, deltaSeconds: number): number
	if stats.regenPerSecond <= 0 then
		return health
	end
	local healed = stats.regenPerSecond * deltaSeconds
	return math.min(health + healed, stats.maxHealth)
end

-- Vrai si l'attaque est autorisee : la recharge de la classe est ecoulee.
-- Le serveur est seul juge, le client ne fait qu'envoyer une intention.
function Combat.canAttack(stats: Stats, now: number, lastAttackAt: number?): boolean
	if lastAttackAt == nil then
		return true
	end
	return (now - lastAttackAt) >= stats.attackCooldownSeconds
end

return Combat
