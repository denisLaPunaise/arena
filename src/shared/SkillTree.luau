--!strict
--[[
	SkillTree — les points d'arbre, le choix de branche et la montee en palier.

	Logique pure : aucun require, aucune API Roblox. La configuration arrive en
	argument, ce qui permet aux tests de verifier un format a sept manches sans
	toucher aux reglages du jeu.

	LA REGLE, en une phrase : une branche par partie, verrouillee des qu'elle
	est choisie, et six points pour aller jusqu'au bout.

	    palier 1   gratuit   la branche prend effet : son bonus ET son sacrifice
	    paliers 2-5  1 point  un cran de plus sur le chiffre de la branche
	    palier 6     2 points l'effet nomme, qui ne s'obtient que la

	D'ou viennent les points : un avant la premiere manche, pour que le premier
	choix se fasse en connaissant le matchup, puis un a la fin de chaque
	manche. Le point donne apres la derniere manche ne sert a rien, donc une
	partie de M manches en donne M d'utilisables.

	Le point de revanche s'ajoute une seule fois par partie, a l'equipe qui
	vient de perdre trois manches d'affilee. Ce n'est pas un rattrapage
	automatique : c'est une option de plus pour celui qui est mene, et il doit
	encore savoir quoi en faire.

	L'arbre est remis a zero a chaque partie. Il ne porte aucune progression de
	compte, et c'est le troisieme principe du projet.
]]

local SkillTree = {}

export type State = {
	classId: string,
	-- Nil tant que le joueur n'a pas choisi. Une fois pose, c'est definitif.
	branchId: string?,
	tier: number,
	pointsEarned: number,
	pointsSpent: number,
	-- Manches perdues d'affilee, remises a zero par la moindre victoire.
	consecutiveLosses: number,
	comebackUsed: boolean,
}

function SkillTree.create(classId: string): State
	return {
		classId = classId,
		branchId = nil,
		tier = 0,
		pointsEarned = 0,
		pointsSpent = 0,
		consecutiveLosses = 0,
		comebackUsed = false,
	}
end

--------------------------------------------------------------------------------
-- LES POINTS
--------------------------------------------------------------------------------

-- Combien de points une partie de M manches rend utilisables. Sert a verifier
-- qu'aller au bout d'une branche reste atteignable dans une serie serree.
function SkillTree.usablePoints(config, roundsPlayed: number): number
	local tree = config.skillTree
	return tree.pointsBeforeFirstRound + (tree.pointsPerRoundEnd * math.max(roundsPlayed - 1, 0))
end

function SkillTree.availablePoints(state: State): number
	return state.pointsEarned - state.pointsSpent
end

function SkillTree.grantStartingPoints(config, state: State): number
	local granted = config.skillTree.pointsBeforeFirstRound
	state.pointsEarned += granted
	return granted
end

-- Les points de fin de manche, point de revanche compris. Renvoie le total
-- accorde, pour pouvoir l'annoncer au joueur.
function SkillTree.grantRoundEnd(config, state: State, wonRound: boolean): number
	local tree = config.skillTree
	local granted = tree.pointsPerRoundEnd

	if wonRound then
		state.consecutiveLosses = 0
	else
		state.consecutiveLosses += 1
	end

	local comeback = tree.comebackPoint
	if
		comeback.enabled
		and not wonRound
		and state.consecutiveLosses >= comeback.consecutiveRoundsLost
		and not (comeback.oncePerMatch and state.comebackUsed)
	then
		granted += comeback.points
		state.comebackUsed = true
	end

	state.pointsEarned += granted
	return granted
end

-- Vrai si le point de revanche vient d'etre accorde sur cette manche.
function SkillTree.justUsedComeback(config, state: State): boolean
	local comeback = config.skillTree.comebackPoint
	return comeback.enabled
		and state.comebackUsed
		and state.consecutiveLosses == comeback.consecutiveRoundsLost
end

--------------------------------------------------------------------------------
-- LES BRANCHES
--------------------------------------------------------------------------------

function SkillTree.branchesFor(config, classId: string): { any }
	return config.skillTree.branches[classId] or {}
end

function SkillTree.findBranch(config, classId: string, branchId: string): any?
	for _, branch in SkillTree.branchesFor(config, classId) do
		if branch.id == branchId then
			return branch
		end
	end
	return nil
end

function SkillTree.currentBranch(config, state: State): any?
	local branchId = state.branchId
	if branchId == nil then
		return nil
	end
	return SkillTree.findBranch(config, state.classId, branchId)
end

-- Choisir sa branche. Le palier 1 est gratuit, donc le choix fait monter tout
-- de suite au premier palier : sans ca on aurait un etat ou la branche est
-- posee mais ne fait rien, qui ne veut rien dire.
function SkillTree.chooseBranch(config, state: State, branchId: string): boolean
	if state.branchId ~= nil then
		return false
	end
	if SkillTree.findBranch(config, state.classId, branchId) == nil then
		return false
	end

	state.branchId = branchId
	state.tier = 1
	return true
end

--------------------------------------------------------------------------------
-- LES PALIERS
--------------------------------------------------------------------------------

function SkillTree.maxTier(config): number
	return config.skillTree.tiers
end

-- Le cout du palier suivant, ou nil quand la branche est terminee.
function SkillTree.costOfNextTier(config, state: State): number?
	local tree = config.skillTree
	local nextTier = state.tier + 1
	if nextTier > tree.tiers then
		return nil
	end
	return tree.tierCosts[nextTier]
end

function SkillTree.canAdvance(config, state: State): boolean
	if state.branchId == nil then
		return false
	end
	local cost = SkillTree.costOfNextTier(config, state)
	if cost == nil then
		return false
	end
	return SkillTree.availablePoints(state) >= cost
end

function SkillTree.advance(config, state: State): boolean
	if not SkillTree.canAdvance(config, state) then
		return false
	end
	local cost = SkillTree.costOfNextTier(config, state)
	if cost == nil then
		return false
	end

	state.pointsSpent += cost
	state.tier += 1
	return true
end

function SkillTree.isComplete(config, state: State): boolean
	return state.tier >= config.skillTree.tiers
end

-- Le cout total pour aller du palier courant au bout de la branche.
function SkillTree.remainingCost(config, state: State): number
	local tree = config.skillTree
	local total = 0
	for tier = state.tier + 1, tree.tiers do
		total += tree.tierCosts[tier] or 0
	end
	return total
end

-- Le cout d'une branche complete, depuis rien.
function SkillTree.fullBranchCost(config): number
	local total = 0
	for _, cost in config.skillTree.tierCosts do
		total += cost
	end
	return total
end

--------------------------------------------------------------------------------
-- L'EFFET NOMME DU PALIER 6
--------------------------------------------------------------------------------

-- L'identifiant de l'effet du dernier palier, seulement s'il est atteint ET
-- reellement implemente. Un effet decrit mais pas code renvoie nil : il vaut
-- mieux une option affichee comme indisponible qu'une option qui ne fait rien
-- en silence.
function SkillTree.activeTier6Effect(config, state: State): string?
	if not SkillTree.isComplete(config, state) then
		return nil
	end

	local branch = SkillTree.currentBranch(config, state)
	if branch == nil or branch.tier6 == nil then
		return nil
	end
	if not branch.tier6.implemented then
		return nil
	end

	return branch.tier6.effect
end

return SkillTree
