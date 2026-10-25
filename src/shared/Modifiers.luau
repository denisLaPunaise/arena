--!strict
--[[
	Modifiers — les statistiques effectives d'un joueur, branche et palier
	compris.

	Logique pure : aucun require, aucune API Roblox. On donne les statistiques
	de base de la classe, la branche choisie et le palier atteint, on recupere
	un nouveau jeu de statistiques. Rien n'est modifie sur place : les
	statistiques de classe de Config ne doivent jamais etre ecrasees, sinon la
	manche suivante part de valeurs deja modifiees et l'arbre se cumule tout
	seul d'une manche a l'autre.

	L'ordre d'application compte, et il est le meme pour toutes les branches :

	    1. le sacrifice du palier 1  (onUnlock, onUnlockScale, onUnlockSet)
	    2. les crans de palier       (perTier, autant de fois qu'il y a de crans)
	    3. les planchers             (rien ne passe sous zero, personne n'est
	                                  immobile ni a zero PV)

	Le palier 6 n'ajoute pas de cran : il donne un effet nomme, que
	SkillTree.activeTier6Effect designe et que les services appliquent.
]]

local Modifiers = {}

-- Les valeurs sous lesquelles on ne descend jamais, quoi que fasse une
-- branche. Ce sont des garde-fous, pas de l'equilibrage : si une branche
-- touche un de ces planchers, c'est que ses chiffres sont a revoir.
local FLOORS = {
	maxHealth = 20,
	walkSpeed = 4,
	attackDamage = 1,
	attackCooldownSeconds = 0.1,
	attackRangeStuds = 1,
	lifestealRatio = 0,
	knockbackStuds = 0,
	knockbackUpStuds = 0,
	regenPerSecond = 0,
}

-- Combien de crans valent un palier donne. Les paliers 1 a 5 en donnent un
-- chacun ; le sixieme n'en donne pas, il donne l'effet nomme.
function Modifiers.notches(config, tier: number): number
	if tier <= 0 then
		return 0
	end
	return math.min(tier, config.skillTree.tiers - 1)
end

function Modifiers.apply(config, baseStats, branch, tier: number): { [string]: any }
	-- Copie superficielle : les statistiques de classe de Config ne doivent
	-- jamais etre ecrasees, sinon l'arbre se cumule d'une manche a l'autre.
	local stats: { [string]: any } = table.clone(baseStats)

	if branch == nil or tier <= 0 then
		return stats
	end

	-- 1. Le sacrifice, une seule fois, au palier 1.
	for key, amount in branch.onUnlock or {} do
		stats[key] = (stats[key] or 0) + amount
	end
	for key, factor in branch.onUnlockScale or {} do
		stats[key] = (stats[key] or 0) * factor
	end
	for key, value in branch.onUnlockSet or {} do
		stats[key] = value
	end

	-- 2. Les crans.
	local notches = Modifiers.notches(config, tier)
	for key, amount in branch.perTier or {} do
		stats[key] = (stats[key] or 0) + (amount * notches)
	end

	-- 3. Les planchers.
	for key, floor in FLOORS do
		if stats[key] ~= nil and stats[key] < floor then
			stats[key] = floor
		end
	end

	return stats
end

-- Ce que la branche a change, pour pouvoir l'afficher au joueur sans lui faire
-- lire deux tableaux de chiffres. Renvoie une liste de { key, from, to }.
function Modifiers.differences(
	baseStats,
	effectiveStats
): { { key: string, from: number, to: number } }
	local changes: { { key: string, from: number, to: number } } = {}

	for key, after in effectiveStats do
		if typeof(after) ~= "number" then
			continue
		end
		local before = baseStats[key]
		if typeof(before) ~= "number" then
			before = 0
		end
		if math.abs(after - before) > 1e-6 then
			table.insert(changes, { key = key, from = before, to = after })
		end
	end

	table.sort(changes, function(a, b)
		return a.key < b.key
	end)

	return changes
end

return Modifiers
