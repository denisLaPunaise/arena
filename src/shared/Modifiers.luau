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
	knockbackDamage = 0,
	spreadRatio = 0,
	spreadRadiusStuds = 0,
	-- damageTakenRatio n'a pas de plancher ici : il est negatif par nature, et
	-- ses bornes sont dans Config.combat, la ou les degats sont calcules.

	-- Les chiffres des pouvoirs de classe. Ils vivent dans les statistiques,
	-- comme les autres, pour qu'une branche puisse les pousser et que
	-- l'interface sache les afficher sans rien savoir des pouvoirs.
	abilityCooldownSeconds = 0.5,
	trackRadiusStuds = 5,
	trackAgeSeconds = 0.5,
	mineCount = 1,
	mineDamage = 1,
	mineRadiusStuds = 1,
	phaseSeconds = 0.5,
	bondShareRatio = 0,
	bondRangeStuds = 5,
	duelBonusRatio = 0,
	duelRadiusStuds = 2,
	wallSeconds = 1,
	wallWidthStuds = 2,
	wallHeightStuds = 2,
	fireDamagePerSecond = 0,
	fireSeconds = 1,
	fireRadiusStuds = 1,
	cloneSeconds = 1,
	cloneExposureRatio = 0,
	slamRadiusStuds = 2,
	slamSeconds = 0.5,
	markSeconds = 2,
	markHealStealRatio = 0,
	markRangeStuds = 5,
	cloakDelaySeconds = 0,
	cloakSpeedThreshold = 0,
	reviveSpeedRatio = 0.25,
	reviveHealthBonusRatio = 0,
	-- duelPenaltyRatio et slamSlowRatio sont negatifs par nature, comme
	-- damageTakenRatio : un plancher a zero les annulerait.
}

-- Le nom lisible de chaque statistique, et comment l'ecrire. Ces libelles sont
-- ici et pas dans Config parce que Config ne contient que des chiffres a
-- regler : un libelle ne se regle pas, il se traduit.
--
--   unit = "ratio" s'affiche en pourcentage, "studs" en distance, nil en brut
--   better = 1 quand monter est bon, -1 quand monter est mauvais. C'est ce qui
--   decide la couleur affichee, et c'est pour ca que damageTakenRatio vaut -1 :
--   une reduction est un nombre negatif, donc une BONNE nouvelle qui descend.
local LABELS: { [string]: { text: string, unit: string?, better: number } } = {
	maxHealth = { text = "PV maximum", better = 1 },
	walkSpeed = { text = "Vitesse", better = 1 },
	attackDamage = { text = "Dégâts", better = 1 },
	attackCooldownSeconds = { text = "Recharge", unit = "seconds", better = -1 },
	attackRangeStuds = { text = "Portée", unit = "studs", better = 1 },
	lifestealRatio = { text = "Vol de vie", unit = "ratio", better = 1 },
	knockbackStuds = { text = "Poussée", unit = "studs", better = 1 },
	knockbackUpStuds = { text = "Poussée verticale", unit = "studs", better = 1 },
	regenPerSecond = { text = "Régénération", better = 1 },
	knockbackDamage = { text = "Dégâts de charge", better = 1 },
	damageTakenRatio = { text = "Dégâts reçus", unit = "ratio", better = -1 },
	spreadRatio = { text = "Propagation", unit = "ratio", better = 1 },
	spreadRadiusStuds = { text = "Rayon de propagation", unit = "studs", better = 1 },

	-- Les pouvoirs de classe. Un joueur ne doit jamais lire `mineCount` dans
	-- l'interface : il lit « Mines en stock ».
	abilityCooldownSeconds = { text = "Recharge du pouvoir", unit = "seconds", better = -1 },
	trackRadiusStuds = { text = "Portée des traces", unit = "studs", better = 1 },
	trackAgeSeconds = { text = "Âge des traces lues", unit = "seconds", better = 1 },
	mineCount = { text = "Mines en stock", better = 1 },
	mineDamage = { text = "Dégâts de mine", better = 1 },
	mineRadiusStuds = { text = "Rayon de mine", unit = "studs", better = 1 },
	phaseSeconds = { text = "Durée de traversée", unit = "seconds", better = 1 },
	bondShareRatio = { text = "Dégâts repris de l'allié", unit = "ratio", better = -1 },
	bondRangeStuds = { text = "Portée du lien", unit = "studs", better = 1 },
	duelBonusRatio = { text = "Bonus en duel", unit = "ratio", better = 1 },
	duelPenaltyRatio = { text = "Pénalité face au nombre", unit = "ratio", better = 1 },
	duelRadiusStuds = { text = "Rayon de duel", unit = "studs", better = 1 },
	wallSeconds = { text = "Durée du mur", unit = "seconds", better = 1 },
	wallWidthStuds = { text = "Largeur du mur", unit = "studs", better = 1 },
	wallHeightStuds = { text = "Hauteur du mur", unit = "studs", better = 1 },
	fireDamagePerSecond = { text = "Dégâts du brasier", better = 1 },
	fireSeconds = { text = "Durée du brasier", unit = "seconds", better = 1 },
	fireRadiusStuds = { text = "Rayon du brasier", unit = "studs", better = 1 },
	cloneSeconds = { text = "Durée du clone", unit = "seconds", better = 1 },
	cloneExposureRatio = { text = "Vulnérabilité pendant le leurre", unit = "ratio", better = -1 },
	slamRadiusStuds = { text = "Rayon de l'onde", unit = "studs", better = 1 },
	slamSlowRatio = { text = "Ralentissement infligé", unit = "ratio", better = -1 },
	slamSeconds = { text = "Durée du ralentissement", unit = "seconds", better = 1 },
	markSeconds = { text = "Durée de la marque", unit = "seconds", better = 1 },
	markHealStealRatio = { text = "Soins volés au marqué", unit = "ratio", better = 1 },
	markRangeStuds = { text = "Portée de la marque", unit = "studs", better = 1 },
	cloakDelaySeconds = { text = "Délai avant camouflage", unit = "seconds", better = -1 },
	cloakSpeedThreshold = { text = "Vitesse tolérée camouflé", unit = "studs", better = 1 },
	reviveSpeedRatio = { text = "Vitesse de relèvement", better = 1 },
	reviveHealthBonusRatio = { text = "PV rendus en plus", unit = "ratio", better = 1 },
}

function Modifiers.label(key: string): string
	local entry = LABELS[key]
	return if entry then entry.text else key
end

-- Vrai si voir ce chiffre monter est une bonne nouvelle pour le joueur.
function Modifiers.isGain(key: string, from: number, to: number): boolean
	local entry = LABELS[key]
	local direction = if entry then entry.better else 1
	return (to - from) * direction > 0
end

local function formatValue(key: string, value: number): string
	local entry = LABELS[key]
	local unit = if entry then entry.unit else nil

	if unit == "ratio" then
		return string.format("%d%%", math.floor((value * 100) + 0.5))
	elseif unit == "studs" then
		return string.format("%.4g", value)
	elseif unit == "seconds" then
		return string.format("%.2fs", value)
	end
	return string.format("%.4g", value)
end

-- Une ligne lisible pour l'interface : « Dégâts  12 → 15 ».
function Modifiers.describe(key: string, from: number, to: number): string
	return string.format(
		"%s  %s → %s",
		Modifiers.label(key),
		formatValue(key, from),
		formatValue(key, to)
	)
end

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
