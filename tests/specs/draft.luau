--!strict
--[[
	Tests des bans et du tirage.

	Ce qui est verifie ici est ce que personne ne remarquerait en jouant une
	seule partie, et qui ruinerait les suivantes :

	  - deux joueurs ne doivent jamais recevoir la meme classe, sauf dans le
	    miroir du 1v1 ou c'est au contraire la regle
	  - une classe bannie ne doit jamais ressortir au tirage
	  - un relancement doit toujours changer quelque chose
	  - le jeu doit continuer quand personne ne vote, et quand le vivier est
	    plus petit que le nombre de joueurs
]]

local Classes = require("../../src/shared/Classes")
local Config = require("../../src/shared/Config")
local Draft = require("../../src/shared/Draft")

local harness = require("../harness")

-- Un hasard qui n'en est pas un : il rend toujours le premier element. C'est
-- ce qui rend un tirage verifiable.
local function first(_: number): number
	return 1
end

-- Un hasard qui rend toujours le dernier.
local function last(n: number): number
	return n
end

return function(t: harness.Harness)
	t.section("Le vivier")

	local full = Draft.createPool(Classes.all, 3)
	t.equal("a trois contre trois, les quatorze classes sont tirables", #full, 14)

	local duel = Draft.createPool(Classes.all, 1)
	t.equal("en 1v1, les trois classes de soutien sortent du vivier", #duel, 11)

	local hasLink = false
	for _, id in duel do
		if id == "link" or id == "decoy" or id == "medic" then
			hasLink = true
		end
	end
	t.check("et aucune d'elles ne reste", hasLink == false)

	t.section("Les bans")

	local state = Draft.create(Classes.all, 3)
	local before = #state.pool

	t.check("on peut bannir une classe du vivier", Draft.ban(state, "A", "vampire"))
	t.equal("le vivier perd une classe", #state.pool, before - 1)
	t.check("la classe bannie n'est plus disponible", Draft.isAvailable(state, "vampire") == false)
	t.check("on ne peut pas la bannir deux fois", Draft.ban(state, "B", "vampire") == false)

	local order = Draft.banOrder(Config, { "A", "B" })
	t.equal("un ban par equipe fait deux tours", #order, 2)
	t.check("et ils alternent", order[1] ~= order[2])

	t.section("Le depouillement d'un vote")

	local voting = Draft.create(Classes.all, 3)
	t.equal(
		"la classe la plus citee l'emporte",
		Draft.tallyBan(voting, { "colossus", "colossus", "spectre" }, first),
		"colossus"
	)

	-- Personne ne vote n'est pas une erreur : un joueur qui decouvre le jeu ne
	-- saura pas quoi bannir, et la partie doit commencer quand meme.
	local silent = Draft.tallyBan(voting, {}, first)
	t.check("personne ne vote : une classe sort quand meme", silent ~= nil)

	-- Un vote pour une classe deja bannie ne doit pas compter.
	local banned = Draft.create(Classes.all, 3)
	Draft.ban(banned, "A", "vampire")
	t.equal(
		"un vote pour une classe deja bannie est ignore",
		Draft.tallyBan(banned, { "vampire", "vampire", "colossus" }, first),
		"colossus"
	)

	t.section("Le tirage : chacun sa classe")

	local match = Draft.create(Classes.all, 3)
	local assigned = Draft.assign(Config, match, {
		A = { "a1", "a2", "a3" },
		B = { "b1", "b2", "b3" },
	}, first)

	local seen: { [string]: boolean } = {}
	local count = 0
	for _, classId in assigned do
		count += 1
		t.check(string.format("%s n'est distribuee qu'une fois", classId), seen[classId] == nil)
		seen[classId] = true
	end
	t.equal("les six joueurs ont une classe", count, 6)

	-- LE TEST QUI COMPTE. Une classe bannie qui ressort au tirage rendrait le
	-- ban decoratif, et personne ne s'en apercevrait avant plusieurs parties.
	local afterBan = Draft.create(Classes.all, 3)
	Draft.ban(afterBan, "A", "vampire")
	Draft.ban(afterBan, "B", "colossus")
	local drawn = Draft.assign(Config, afterBan, {
		A = { "a1", "a2", "a3" },
		B = { "b1", "b2", "b3" },
	}, last)
	for key, classId in drawn do
		t.check(
			string.format("%s ne recoit pas une classe bannie", key),
			classId ~= "vampire" and classId ~= "colossus"
		)
	end

	t.section("Le miroir du 1v1")

	local duelState = Draft.create(Classes.all, 1)
	local pair = Draft.assign(Config, duelState, { A = { "a1" }, B = { "b1" } }, first)
	t.equal("les deux joueurs ont la meme classe", pair.a1, pair.b1)
	t.check("et elle existe", pair.a1 ~= nil)

	t.section("Le relancement, aveugle et unique")

	local rerollState = Draft.create(Classes.all, 3)
	Draft.assign(Config, rerollState, { A = { "a1" }, B = { "b1" } }, first)

	local was = rerollState.assigned.a1
	local now = Draft.reroll(Config, rerollState, "a1", first)
	t.check("le relancement donne une classe", now ~= nil)
	-- Un relancement qui rend la meme classe est pire que pas de relancement :
	-- le joueur a depense sa seule chance pour rien.
	t.check("et jamais la meme qu'avant", now ~= was)
	t.check("l'ancienne classe retourne au vivier", Draft.isAvailable(rerollState, was))
	t.check("on ne relance pas deux fois", Draft.reroll(Config, rerollState, "a1", first) == nil)

	t.section("Quand le vivier s'epuise")

	-- Un vivier plus petit que le nombre de joueurs ne doit pas planter : il
	-- doit servir autant les deux equipes, pas donner tout a la premiere.
	local small = Draft.create(Classes.all, 3)
	while #small.pool > 3 do
		table.remove(small.pool)
	end
	local short = Draft.assign(Config, small, {
		A = { "a1", "a2" },
		B = { "b1", "b2" },
	}, first)

	local served = { A = 0, B = 0 }
	for key in short do
		served[string.upper(string.sub(key, 1, 1))] += 1
	end
	t.check(
		"les deux equipes sont servies aussi mal l'une que l'autre",
		math.abs(served.A - served.B) <= 1
	)
end
