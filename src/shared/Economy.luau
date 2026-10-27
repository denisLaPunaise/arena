--!strict
--[[
	Economy — les pieces gagnees en jouant, et les fragments des doublons.

	Logique pure : aucun require, aucune API Roblox. Les chiffres arrivent de
	Config, le resultat de la partie arrive en argument.

	LE PRINCIPE QUE CE FICHIER TIENT : aucun achat ne donne de puissance. Les
	pieces s'obtiennent en jouant et ne servent qu'a ouvrir des caisses ; les
	fragments viennent des doublons et ne servent qu'aux skins. Rien ici ne
	touche aux statistiques, et c'est volontaire.

	ON NE RECOMPENSE PAS LES ELIMINATIONS. Dans un mode ou la manche s'arrete a
	l'equipe entiere, payer les kills pousse a jouer pour soi, a voler les
	achevements d'un coequipier et a ignorer un allie a terre. Le reglage est
	`config.economy.rewardKills`, et il vaut faux.

	CE QUE « MANCHE NON CONCEDEE » VEUT DIRE : les manches gagnees moins les
	manches perdues, jamais moins de zero. Une victoire deux a zero en vaut
	deux, une victoire deux a un n'en vaut qu'une. C'est ce qui fait qu'un
	match serre rapporte moins qu'une demonstration, sans jamais rapporter
	moins qu'une defaite.
]]

local Economy = {}

export type Outcome = {
	won: boolean,
	roundsWon: number,
	roundsLost: number,
}

export type Reward = {
	coins: number,
	-- Combien de parties de CE niveau il faudrait pour une caisse. Sert aux
	-- tests et a l'affichage, jamais au calcul.
	matchesPerCrate: number,
}

function Economy.roundsNotConceded(outcome: Outcome): number
	return math.max(outcome.roundsWon - outcome.roundsLost, 0)
end

-- Les pieces d'une partie. Une defaite rapporte toujours quelque chose : une
-- partie qui ne rapporte rien est une partie qu'on quitte avant la fin.
function Economy.coinsFor(config, outcome: Outcome): number
	local settings = config.economy

	if outcome.won then
		return settings.winBase
			+ (settings.winPerRoundNotConceded * Economy.roundsNotConceded(outcome))
	end

	return settings.lossBase + (settings.lossPerRoundWon * outcome.roundsWon)
end

-- Vrai si cette partie paie des pieces. Le pendant exact de Rating.counts, et
-- pour la meme raison : une partie privee est une partie d'essai. Les deux se
-- changent ensemble — payer sans classer recompenserait un serveur prive a deux
-- joueurs complaisants, classer sans payer serait incomprehensible.
function Economy.paysIn(config, private: boolean): boolean
	if private then
		return config.economy.privateMatchesPay
	end
	return true
end

function Economy.rewardFor(config, outcome: Outcome): Reward
	local coins = Economy.coinsFor(config, outcome)
	return {
		coins = coins,
		matchesPerCrate = math.ceil(config.economy.crateCost / math.max(coins, 1)),
	}
end

-- Les nouveaux joueurs sont accelerees : sans ca, il faut des semaines avant
-- d'avoir de quoi remplir ses douze points, et on ne decouvre jamais ce que le
-- budget a d'interessant.
function Economy.isBoosted(config, matchesPlayed: number): boolean
	return matchesPlayed < config.draws.newPlayerBoostMatches
end

function Economy.matchesPerCrateWhileBoosted(config): number
	return config.draws.newPlayerCrateEveryMatches
end

-- Combien de caisses une reserve de pieces ouvre, et ce qui reste apres.
function Economy.cratesAffordable(config, coins: number): (number, number)
	local cost = config.economy.crateCost
	local count = math.floor(coins / cost)
	return count, coins - (count * cost)
end

function Economy.spendOnCrate(config, coins: number): (boolean, number)
	local cost = config.economy.crateCost
	if coins < cost then
		return false, coins
	end
	return true, coins - cost
end

--------------------------------------------------------------------------------
-- LES FRAGMENTS
--------------------------------------------------------------------------------

-- Ce que rapporte un doublon. C'est ce qui fait qu'AUCUN tirage ne rend rien,
-- ce que la politique de Roblox exige pour un objet aleatoire payant : un
-- tirage ou le joueur perd simplement sa mise est interdit.
--
-- Ne jamais retirer cette regle sans la remplacer par une autre qui donne
-- quelque chose a chaque tirage.
function Economy.fragmentsForDuplicate(config): number
	return config.cosmetics.fragmentsPerDuplicate
end

function Economy.skinTier(config, tierId: string): any?
	for _, tier in config.cosmetics.skinTiers do
		if tier.id == tierId then
			return tier
		end
	end
	return nil
end

function Economy.canAffordSkin(config, fragments: number, tierId: string): boolean
	local tier = Economy.skinTier(config, tierId)
	if tier == nil then
		return false
	end
	return fragments >= tier.fragments
end

-- Combien de doublons il faut pour un skin de ce palier. Le chiffre qui relie
-- les deux economies : baisser le taux de doublons rend les skins plus rares,
-- et c'est pour ca que les deux reglages se changent ensemble.
function Economy.duplicatesPerSkin(config, tierId: string): number?
	local tier = Economy.skinTier(config, tierId)
	if tier == nil then
		return nil
	end
	return math.ceil(tier.fragments / Economy.fragmentsForDuplicate(config))
end

return Economy
