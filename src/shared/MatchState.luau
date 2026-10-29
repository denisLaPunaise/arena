--!strict
--[[
	MatchState — le score d'une partie, et rien d'autre.

	Logique pure : ce module ne requiert rien et ne connait ni Player, ni
	Instance, ni game. Il prend le nombre de manches a gagner en argument au
	lieu de lire Config, ce qui permet aux tests de verifier d'autres formats
	que celui du prototype.

	Les equipes sont des chaines ("A" et "B") et pas des objets Roblox, pour la
	meme raison.
]]

local MatchState = {}

export type State = {
	roundsToWin: number,
	scores: { [string]: number },
	roundsPlayed: number,
}

--[[
	LA LONGUEUR REELLEMENT JOUEE, et c'est un seul endroit expres.

	`Config.prototype.enabled` existait sans que personne ne le lise, et
	`MatchService` prenait `Config.prototype.roundsToWin` quoi qu'il arrive :
	le jeu jouait donc la longueur du prototype -- premier a deux manches --
	pendant que `Config.match` annoncait premier a quatre et n'etait lu par
	aucune ligne de code. La consequence etait invisible en jouant et couteuse :
	une partie de M manches donne M points d'arbre, un palier 6 en coute six a
	lui seul, donc les paliers 5 et 6 n'etaient PAS atteignables.

	C'est la meme panne que `Config.formats`, et un test de `config.luau` relie
	maintenant les deux bouts : il verifie que l'arbre complet est atteignable
	dans la longueur que cette fonction rend vraiment.
]]
function MatchState.roundsToWin(config): number
	if config.prototype.enabled then
		return config.prototype.roundsToWin
	end
	return config.match.roundsToWin
end

function MatchState.create(roundsToWin: number): State
	return {
		roundsToWin = roundsToWin,
		scores = { A = 0, B = 0 },
		roundsPlayed = 0,
	}
end

-- La manche qui va se jouer, numerotee a partir de 1 pour l'affichage.
function MatchState.roundNumber(state: State): number
	return state.roundsPlayed + 1
end

-- Nombre maximum de manches : premier a N gagnees donne 2N - 1 manches.
function MatchState.maxRounds(state: State): number
	return (state.roundsToWin * 2) - 1
end

function MatchState.recordRoundWin(state: State, team: string)
	state.scores[team] += 1
	state.roundsPlayed += 1
end

function MatchState.isOver(state: State): boolean
	for _, score in state.scores do
		if score >= state.roundsToWin then
			return true
		end
	end
	return false
end

-- L'equipe gagnante, ou nil si la partie n'est pas finie.
function MatchState.winner(state: State): string?
	for team, score in state.scores do
		if score >= state.roundsToWin then
			return team
		end
	end
	return nil
end

-- Le score sous la forme "2 - 1", vu depuis l'equipe passee en argument.
function MatchState.scoreLine(state: State, fromTeam: string): string
	local own = state.scores[fromTeam] or 0
	local other = 0
	for team, score in state.scores do
		if team ~= fromTeam then
			other = score
		end
	end
	return string.format("%d - %d", own, other)
end

return MatchState
