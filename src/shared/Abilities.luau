--!strict
--[[
	Abilities — le calcul des pouvoirs de classe, sans Roblox.

	Meme regle que partout ailleurs : aucun require, aucune API Roblox, la
	configuration arrive en argument. Ce qui est ici se verifie en ligne de
	commande avec Lune ; ce qui demande un personnage, une part ou un
	Highlight est dans AbilityService.

	Ce module ne sait pas QUI porte le pouvoir, ni quand il a ete utilise pour
	de vrai. Il repond a des questions fermees : « avec ces statistiques et ce
	nombre d'ennemis autour, de combien le coup est-il multiplie ? », « cette
	part de soin revient a qui ? ». C'est ce qui le rend testable.

	LE CHOIX QUI STRUCTURE TOUT. Les chiffres d'un pouvoir sont des
	statistiques de classe ordinaires (Config.classStats), pas une table a
	part. Une branche d'arbre peut donc les pousser comme elle pousse les
	degats, et l'interface sait deja les afficher. En echange, chaque fonction
	d'ici doit accepter qu'une statistique soit absente : le Traqueur n'a pas
	de mines, l'Artificier ne lit pas de traces. D'ou les `or 0` partout, qui
	ne sont pas de la negligence mais la contrepartie assumee.
]]

local Abilities = {}

export type Stats = { [string]: any }

--------------------------------------------------------------------------------
-- LA RECHARGE, COMMUNE A TOUS LES POUVOIRS ACTIFS
--------------------------------------------------------------------------------

-- Une seule recharge par classe, et une seule touche : la classe est tiree au
-- sort, donc un jeu de touches par classe serait a reapprendre a chaque partie.
function Abilities.cooldownOf(stats: Stats): number
	return stats.abilityCooldownSeconds or 0
end

function Abilities.isReady(stats: Stats, now: number, lastUsedAt: number?): boolean
	if lastUsedAt == nil then
		return true
	end
	return (now - lastUsedAt) >= Abilities.cooldownOf(stats)
end

-- Ce qui reste a attendre, pour l'afficher. Jamais negatif.
function Abilities.cooldownLeft(stats: Stats, now: number, lastUsedAt: number?): number
	if lastUsedAt == nil then
		return 0
	end
	return math.max(Abilities.cooldownOf(stats) - (now - lastUsedAt), 0)
end

--------------------------------------------------------------------------------
-- DUELLISTE — le meme chiffre vu des deux cotes
--------------------------------------------------------------------------------

-- Seul contre un, il frappe plus fort. Des qu'un deuxieme ennemi est a portee,
-- il frappe plus faible. C'est son pouvoir ET sa faiblesse, et c'est pour ca
-- qu'une seule fonction les rend tous les deux : les separer laisserait croire
-- qu'on peut regler l'un sans l'autre.
function Abilities.duelMultiplier(stats: Stats, enemiesNear: number): number
	if stats.duelBonusRatio == nil and stats.duelPenaltyRatio == nil then
		return 1
	end

	if enemiesNear <= 1 then
		return 1 + (stats.duelBonusRatio or 0)
	end
	return math.max(1 + (stats.duelPenaltyRatio or 0), 0)
end

--------------------------------------------------------------------------------
-- LIEN — partager sans mourir a la place de l'autre
--------------------------------------------------------------------------------

-- La part des degats de l'allie qui revient au Lien. Plafonnee a une fraction
-- de ses PV maximum : sans ce plafond, lier un allie qui encaisse un coup
-- enorme tuerait le Lien d'un coup, et le pouvoir deviendrait un piege qu'on
-- n'utilise jamais deux fois.
function Abilities.bondShare(config, stats: Stats, amount: number): number
	local ratio = stats.bondShareRatio or 0
	if ratio <= 0 or amount <= 0 then
		return 0
	end

	local shared = amount * ratio
	local cap = (stats.maxHealth or 0) * config.abilities.tuning.bondMaxShareFraction
	return math.min(shared, cap)
end

-- Ce qui reste a encaisser pour l'allie. Le total ne change pas : le Lien ne
-- reduit pas les degats, il en prend une part a sa place.
function Abilities.bondRemainder(amount: number, shared: number): number
	return math.max(amount - shared, 0)
end

--------------------------------------------------------------------------------
-- PARASITE — vivre sur les soins des autres
--------------------------------------------------------------------------------

function Abilities.healSteal(stats: Stats, amount: number): number
	local ratio = stats.markHealStealRatio or 0
	if ratio <= 0 or amount <= 0 then
		return 0
	end
	return amount * ratio
end

--------------------------------------------------------------------------------
-- CAMELEON — invisible tant qu'il ne bouge pas
--------------------------------------------------------------------------------

-- Deux conditions, et les deux comptent : il doit etre presque arrete, et
-- l'etre depuis assez longtemps. Sans le delai, il clignoterait a chaque pas ;
-- sans le seuil de vitesse, marcher doucement suffirait a rester cache.
function Abilities.shouldCloak(stats: Stats, speed: number, stillSeconds: number): boolean
	if stats.cloakDelaySeconds == nil then
		return false
	end
	if speed > (stats.cloakSpeedThreshold or 0) then
		return false
	end
	return stillSeconds >= stats.cloakDelaySeconds
end

--------------------------------------------------------------------------------
-- INFIRMIER — relever vite, et mieux
--------------------------------------------------------------------------------

function Abilities.reviveSpeed(stats: Stats): number
	return math.max(stats.reviveSpeedRatio or 1, 0)
end

-- Les PV rendus a un allie releve, en part des PV maximum. L'Infirmier ajoute
-- les siens par-dessus la regle commune, et le total ne depasse jamais un.
function Abilities.reviveHealthRatio(config, stats: Stats): number
	local base = config.downed.reviveHealthRatio
	return math.min(base + (stats.reviveHealthBonusRatio or 0), 1)
end

--------------------------------------------------------------------------------
-- BRASIER, MINES, ONDE — ce qui blesse sans etre un coup
--------------------------------------------------------------------------------

function Abilities.fireTickDamage(stats: Stats, deltaSeconds: number): number
	return (stats.fireDamagePerSecond or 0) * deltaSeconds
end

-- La vitesse d'un ennemi ralenti par l'onde. Le ratio est negatif par nature,
-- et on ne descend jamais sous un quart de la vitesse de depart : immobiliser
-- quelqu'un n'est pas ralentir quelqu'un.
function Abilities.slowedSpeed(baseSpeed: number, slowRatio: number): number
	return math.max(baseSpeed * (1 + slowRatio), baseSpeed * 0.25)
end

return Abilities
