--!strict
--[[
	Tests du score d'une partie.

	Le format du prototype est premier a deux manches gagnees, mais les tests
	verifient aussi le format reel du jeu (premier a quatre) : c'est le meme
	module qui servira, et autant savoir tout de suite qu'il tient.
]]

local MatchState = require("../../src/shared/MatchState")

local harness = require("../harness")

return function(t: harness.Harness)
	t.section("Le debut de partie")

	local state = MatchState.create(2)
	t.equal("le score part de zero pour A", state.scores.A, 0)
	t.equal("le score part de zero pour B", state.scores.B, 0)
	t.equal("la premiere manche porte le numero 1", MatchState.roundNumber(state), 1)
	t.check("la partie n'est pas finie", MatchState.isOver(state) == false)
	t.check("il n'y a pas de gagnant", MatchState.winner(state) == nil)

	t.section("Le deroulement d'une partie du prototype")

	MatchState.recordRoundWin(state, "A")
	t.equal("A mene 1-0", MatchState.scoreLine(state, "A"), "1 - 0")
	t.equal("vu de B, c'est 0-1", MatchState.scoreLine(state, "B"), "0 - 1")
	t.equal("la deuxieme manche porte le numero 2", MatchState.roundNumber(state), 2)
	t.check("la partie continue a 1-0", MatchState.isOver(state) == false)

	MatchState.recordRoundWin(state, "B")
	t.check("la partie continue a 1-1", MatchState.isOver(state) == false)
	t.equal("deux manches jouees", state.roundsPlayed, 2)

	MatchState.recordRoundWin(state, "A")
	t.check("la partie est finie a 2-1", MatchState.isOver(state) == true)
	t.equal("A gagne", MatchState.winner(state), "A")
	t.equal("trois manches au maximum en premier a deux", MatchState.maxRounds(state), 3)

	t.section("Le format reel du jeu")

	local long = MatchState.create(4)
	t.equal("sept manches au maximum en premier a quatre", MatchState.maxRounds(long), 7)

	for _ = 1, 3 do
		MatchState.recordRoundWin(long, "B")
	end
	t.check("un 3-0 ne termine pas la partie", MatchState.isOver(long) == false)

	MatchState.recordRoundWin(long, "B")
	t.check("un 4-0 la termine", MatchState.isOver(long) == true)
	t.equal("B gagne", MatchState.winner(long), "B")
	t.equal("quatre manches jouees", long.roundsPlayed, 4)
end
