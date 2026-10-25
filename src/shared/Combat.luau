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
}

export type HitInput = {
	attackerStats: Stats,
	attackerHealth: number,
	defenderStats: Stats,
	defenderHealth: number,
}

export type HitResult = {
	damage: number,
	healed: number,
	attackerHealth: number,
	defenderHealth: number,
	defenderDown: boolean,
}

function Combat.resolveHit(input: HitInput): HitResult
	local defenderHealth = math.max(input.defenderHealth, 0)
	local damage = math.min(input.attackerStats.attackDamage, defenderHealth)

	local missingHealth = input.attackerStats.maxHealth - input.attackerHealth
	local lifesteal = damage * input.attackerStats.lifestealRatio
	local healed = math.clamp(lifesteal, 0, math.max(missingHealth, 0))

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
