--!strict
--[[
	Tests du placement : qui joue, dans quelle equipe, et qui attend.

	CE QUE CES TESTS ATTRAPENT, et que personne ne verrait en jouant seul :

	  - des equipes de tailles differentes. C'est LE bug de ce module : avec un
	    nombre de places pair et une erreur d'un cran dans l'alternance, on
	    obtient un 3v1 qui s'annonce comme un 2v2, et l'equilibrage de toutes
	    les classes devient illisible.
	  - un joueur assis dans aucune equipe, ou dans une equipe qui n'existe pas.
	    Il ne serait jamais compte comme elimine, donc la manche ne finirait
	    PLUS JAMAIS : le serveur tournerait sans rien dire.
	  - un joueur perdu entre les deux listes, ou present dans les deux.
	  - un banc qui ne tourne pas. A cinq joueurs, le cinquieme regarderait les
	    autres jouer toute la soiree, et rien dans le jeu ne le signalerait.
	  - un ordre non deterministe. table.sort n'est pas stable en Luau : deux
	    joueurs a egalite de banc pourraient changer de place d'un appel a
	    l'autre, et le banc deviendrait un tirage au sort.
	  - Config.formats et Config.seating.teams qui ne parlent plus de la meme
	    chose. Les identifiants de format (« 2v2 ») comptent DEUX camps : un
	    troisieme camp dans la liste des equipes rendrait tous les totaux faux
	    sans que rien ne leve.
]]

local Config = require("../../src/shared/Config")
local Seating = require("../../src/shared/Seating")

local harness = require("../harness")

-- Un effectif de n joueurs, tous frais du banc.
local function roster(n: number): { Seating.Candidate }
	local candidates: { Seating.Candidate } = {}
	for index = 1, n do
		table.insert(candidates, { id = "p" .. index, satOut = 0 })
	end
	return candidates
end

return function(t: harness.Harness)
	t.section("Les formats et les camps parlent de la meme chose")

	-- Ce test vaut tout le reste du fichier : il est le seul a verifier
	-- l'hypothese sur laquelle repose chaque calcul de ce module.
	t.equal("il y a exactement deux camps", #Config.seating.teams, 2)
	for _, format in Config.formats do
		t.equal(
			string.format("l'identifiant « %s » dit bien sa taille", format.id),
			format.id,
			string.format("%dv%d", format.playersPerTeam, format.playersPerTeam)
		)
	end

	t.section("Le format se deduit de l'effectif")

	t.equal("a zéro joueur, aucun format", Seating.formatFor(Config, 0), nil)
	t.equal("a un joueur, aucun format", Seating.formatFor(Config, 1), nil)

	-- Le plus petit effectif jouable est DEDUIT des formats. C'etait un
	-- « PLAYERS_NEEDED = 2 » en dur dans MatchService.
	t.equal("il faut deux joueurs pour jouer", Seating.playersNeeded(Config), 2)

	local expected: { [number]: string } = {
		[2] = "1v1",
		[3] = "1v1",
		[4] = "2v2",
		[5] = "2v2",
		[6] = "3v3",
		[7] = "3v3",
		[8] = "4v4",
		[9] = "4v4",
		[40] = "4v4",
	}

	for count, id in expected do
		local format = Seating.formatFor(Config, count)
		t.equal(
			string.format("à %d joueurs, on joue en %s", count, id),
			if format then format.id else nil,
			id
		)
	end

	t.section("Les deux equipes ont la meme taille")

	-- Pour chaque effectif de 0 a 11, le plan doit etre coherent de bout en
	-- bout. Un seul passage ecrit a la main raterait le cas impair.
	for count = 0, 11 do
		local plan = Seating.plan(Config, roster(count))

		if count < 2 then
			t.equal(string.format("à %d joueur(s), pas de partie", count), plan, nil)
			continue
		end

		assert(plan ~= nil, "un plan etait attendu")

		local perTeam: { [string]: number } = {}
		for _, team in Config.seating.teams do
			perTeam[team] = 0
		end

		local unknownTeam = false
		for _, id in plan.seated do
			local team = plan.teams[id]
			if team == nil or perTeam[team] == nil then
				unknownTeam = true
			else
				perTeam[team] += 1
			end
		end

		t.equal(
			string.format("à %d : chaque joueur assis a une équipe connue", count),
			unknownTeam,
			false
		)

		local sizes: { number } = {}
		for _, team in Config.seating.teams do
			table.insert(sizes, perTeam[team])
		end
		t.equal(
			string.format("à %d : les deux camps ont le même effectif", count),
			sizes[1],
			sizes[2]
		)

		-- Personne n'est perdu, personne n'est compte deux fois.
		t.equal(
			string.format("à %d : tout le monde est assis ou sur le banc", count),
			#plan.seated + #plan.waiting,
			count
		)

		local seen: { [string]: boolean } = {}
		local twice = false
		for _, id in plan.seated do
			if seen[id] then
				twice = true
			end
			seen[id] = true
		end
		for _, id in plan.waiting do
			if seen[id] then
				twice = true
			end
			seen[id] = true
		end
		t.equal(string.format("à %d : personne dans les deux listes", count), twice, false)

		-- Et le banc tient exactement le reste : les formats sont pairs, donc
		-- un effectif impair laisse forcement quelqu'un dehors.
		local format = Seating.formatFor(Config, count)
		assert(format ~= nil, "un format etait attendu")
		t.equal(
			string.format("à %d : %d place(s) assises", count, #plan.seated),
			#plan.seated,
			format.playersPerTeam * #Config.seating.teams
		)
	end

	t.section("Le banc tourne")

	-- Cinq joueurs, un seul banc : celui qui vient d'attendre doit passer
	-- devant les quatre autres a la partie suivante.
	local five = roster(5)
	five[5].satOut = 1

	local rotated = Seating.plan(Config, five)
	assert(rotated ~= nil, "un plan etait attendu")

	local seatedFive: { [string]: boolean } = {}
	for _, id in rotated.seated do
		seatedFive[id] = true
	end
	t.equal("celui qui a attendu joue", seatedFive["p5"], true)
	t.equal("et quelqu'un d'autre prend sa place sur le banc", #rotated.waiting, 1)
	t.equal("qui n'est pas lui", rotated.waiting[1] ~= "p5", true)

	-- LA propriete qui compte, verifiee en simulant la soiree au lieu d'un seul
	-- appel : a cinq joueurs, personne ne doit rester dehors indefiniment.
	local soiree = roster(5)
	local played: { [string]: number } = {}
	for _, candidate in soiree do
		played[candidate.id] = 0
	end

	for _ = 1, 5 do
		local plan = Seating.plan(Config, soiree)
		assert(plan ~= nil, "un plan etait attendu")

		local onBench: { [string]: boolean } = {}
		for _, id in plan.waiting do
			onBench[id] = true
		end

		for _, candidate in soiree do
			if onBench[candidate.id] then
				candidate.satOut += 1
			else
				candidate.satOut = 0
				played[candidate.id] += 1
			end
		end
	end

	local neverPlayed = 0
	for _, count in played do
		if count == 0 then
			neverPlayed += 1
		end
	end
	t.equal("en cinq parties à cinq joueurs, personne n'est resté dehors", neverPlayed, 0)

	t.section("Le meme effectif donne toujours le meme plan")

	-- table.sort n'est pas stable : sans la cle a deux niveaux, deux joueurs a
	-- egalite de banc changeraient de camp d'un appel a l'autre.
	local first = Seating.plan(Config, roster(6))
	local second = Seating.plan(Config, roster(6))
	assert(first ~= nil and second ~= nil, "deux plans etaient attendus")

	local stable = true
	for index, id in first.seated do
		if second.seated[index] ~= id or second.teams[id] ~= first.teams[id] then
			stable = false
		end
	end
	t.equal("deux appels identiques donnent le même placement", stable, true)

	t.section("Le camp demande, en partie privee")

	-- CE QUE CE BLOC PROTEGE : un voeu de camp qui casse l'egalite des deux
	-- camps. C'est la seule chose qui ne doit jamais ceder, parce qu'un 3v1
	-- annonce comme un 2v2 rend tout l'equilibrage illisible.

	-- Trois amis sur six demandent le meme camp : ils doivent l'avoir, et les
	-- trois autres se retrouvent en face.
	local party = roster(6)
	party[1].side = "A"
	party[2].side = "A"
	party[3].side = "A"

	local together = Seating.plan(Config, party)
	assert(together ~= nil, "un plan etait attendu")
	local function sidesOf(plan: Seating.Plan, ids: { string }): string
		local out: { string } = {}
		for _, id in ids do
			table.insert(out, plan.teams[id] or "-")
		end
		return table.concat(out, " ")
	end

	t.equal(
		"les trois amis sont dans le camp demandé",
		sidesOf(together, { "p1", "p2", "p3" }),
		"A A A"
	)
	t.equal("et les trois autres sont en face", sidesOf(together, { "p4", "p5", "p6" }), "B B B")

	-- Un camp sur-demande : quatre voeux pour trois places. Le quatrieme part
	-- en face, et c'est l'ordre du banc qui le designe — ici p4, qui a le moins
	-- attendu des quatre.
	local crowded = roster(6)
	for index = 1, 4 do
		crowded[index].side = "A"
	end

	local overflow = Seating.plan(Config, crowded)
	assert(overflow ~= nil, "un plan etait attendu")

	local inA = 0
	for _, id in overflow.seated do
		if overflow.teams[id] == "A" then
			inA += 1
		end
	end
	t.equal("un camp sur-demandé ne déborde pas", inA, 3)
	t.equal("et c'est le dernier du banc qui passe en face", overflow.teams["p4"], "B")

	-- Tout le monde du meme cote : impossible a tenir, et les camps restent
	-- egaux quand meme. C'est le cas qui casserait tout si la deuxieme passe
	-- faisait confiance au voeu.
	local everyone = roster(4)
	for _, candidate in everyone do
		candidate.side = "A"
	end

	local impossible = Seating.plan(Config, everyone)
	assert(impossible ~= nil, "un plan etait attendu")

	local counts: { [string]: number } = { A = 0, B = 0 }
	for _, id in impossible.seated do
		counts[impossible.teams[id]] += 1
	end
	t.equal("quatre voeux pour le même camp : les camps restent égaux", counts["A"], counts["B"])

	-- Un camp qui n'existe pas ne doit pas laisser un joueur sans equipe. Le
	-- serveur filtre deja, mais un joueur sans equipe ne serait jamais compte
	-- comme elimine et la manche ne finirait plus : deux garde-fous valent
	-- mieux qu'un pour celui-la.
	local bogus = roster(4)
	bogus[1].side = "Z"
	bogus[2].side = ""

	local filtered = Seating.plan(Config, bogus)
	assert(filtered ~= nil, "un plan etait attendu")

	local allSeated = true
	for _, id in filtered.seated do
		local team = filtered.teams[id]
		if team ~= "A" and team ~= "B" then
			allSeated = false
		end
	end
	t.equal("un camp inconnu est ignoré, personne ne reste sans équipe", allSeated, true)

	-- Et sans aucun voeu, le placement est exactement celui d'avant : les camps
	-- alternent. Ce test est la pour que l'ajout du voeu n'ait rien change au
	-- cas courant, qui est le seul des deux a tourner en partie classee.
	local plain = Seating.plan(Config, roster(4))
	assert(plain ~= nil, "un plan etait attendu")
	t.equal(
		"sans voeu, les camps alternent comme avant",
		sidesOf(plain, { "p1", "p2", "p3", "p4" }),
		"A B A B"
	)

	t.section("Le banc ne fabrique pas une equipe de revanchards")

	-- Quatre places, et les deux joueurs qui ont le plus attendu. Les camps
	-- s'alternent, donc ils doivent se retrouver face a face : s'ils tombaient
	-- dans le meme camp, le banc donnerait une equipe entiere de joueurs frais
	-- contre une equipe qui vient d'enchainer une serie.
	local waited = roster(6)
	waited[5].satOut = 2
	waited[6].satOut = 2

	local split = Seating.plan(Config, waited)
	assert(split ~= nil, "un plan etait attendu")
	t.equal(
		"les deux qui ont le plus attendu ne sont pas dans le même camp",
		split.teams["p5"] ~= split.teams["p6"],
		true
	)

	t.section("Le format impose par le salon")

	-- AUTO n'est pas un format. Si un jour quelqu'un nommait un format « auto »,
	-- il deviendrait impossible a imposer : formatFor le lirait comme « pas de
	-- format impose » et choisirait tout seul.
	t.equal(
		"« auto » n'est pas un identifiant de format",
		Seating.formatById(Config, Seating.AUTO),
		nil
	)

	-- La liste affichee par le salon est DEDUITE de Config.formats : un format
	-- ajoute a la table apparait a l'ecran sans qu'on recopie rien.
	local ids = Seating.formatIds(Config)
	t.equal("le salon propose auto plus chaque format", #ids, #Config.formats + 1)
	t.equal("et auto vient en tête", ids[1], Seating.AUTO)

	local chosenMode = { formatId = Seating.AUTO, teamMode = Seating.CHOSEN }

	-- Six joueurs qui demandent du 1v1 : DEUX jouent, quatre attendent. C'est
	-- le point le moins evident du salon, et c'est voulu — le format dit la
	-- taille des camps, pas qui a le droit de jouer.
	local small = Seating.plan(Config, roster(6), { formatId = "1v1", teamMode = Seating.CHOSEN })
	assert(small ~= nil, "un plan etait attendu")
	t.equal("six joueurs en 1v1 : c'est bien un 1v1", small.formatId, "1v1")
	t.equal("deux jouent", #small.seated, 2)
	t.equal("et quatre attendent", #small.waiting, 4)

	-- L'INVERSE NE CEDE PAS. Demander du 3v3 a deux ne doit pas lancer un 1v1 :
	-- un format impose qu'on obtient sans l'avoir vu passer est pire qu'une
	-- attente, parce que personne ne saurait pourquoi les camps sont petits.
	t.equal(
		"du 3v3 à deux joueurs : on attend, on ne retombe pas en 1v1",
		Seating.plan(Config, roster(2), { formatId = "3v3", teamMode = Seating.CHOSEN }),
		nil
	)
	t.equal(
		"un format inconnu ne lance rien",
		Seating.plan(Config, roster(4), { formatId = "9v9", teamMode = Seating.CHOSEN }),
		nil
	)

	-- Et le salon en auto doit se comporter EXACTEMENT comme pas de salon du
	-- tout, sinon la partie classee changerait de comportement en silence.
	local autoPlan = Seating.plan(Config, roster(5), chosenMode)
	local noLobby = Seating.plan(Config, roster(5))
	assert(autoPlan ~= nil and noLobby ~= nil, "deux plans etaient attendus")
	t.equal("en auto, le salon ne change rien", autoPlan.formatId, noLobby.formatId)
	t.equal(
		"ni les camps",
		sidesOf(autoPlan, { "p1", "p2", "p3", "p4" }),
		sidesOf(noLobby, { "p1", "p2", "p3", "p4" })
	)

	t.section("Le tirage au sort des camps")

	local randomMode = { formatId = Seating.AUTO, teamMode = Seating.RANDOM }

	-- Un rng previsible : toujours 1. Le melange de Fisher-Yates devient donc
	-- un calcul verifiable a la main, et ce test attrape une inversion de
	-- boucle que « les camps sont egaux » laisserait passer.
	local function always(_: number): number
		return 1
	end

	local drawn = Seating.plan(Config, roster(4), randomMode, always)
	assert(drawn ~= nil, "un plan etait attendu")
	t.equal("le tirage ne change pas qui joue", table.concat(drawn.seated, " "), "p1 p2 p3 p4")
	t.equal("mais il change les camps", sidesOf(drawn, { "p1", "p2", "p3", "p4" }), "B A B A")

	-- LE VOEU NE COMPTE PLUS. C'est toute la difference entre les deux modes :
	-- en tirage au sort, un camp demande est ignore, sinon ce ne serait pas un
	-- tirage. Quatre voeux identiques, et les camps restent coupes en deux.
	local wishing = roster(4)
	for _, candidate in wishing do
		candidate.side = "A"
	end

	local ignored = Seating.plan(Config, wishing, randomMode, always)
	assert(ignored ~= nil, "un plan etait attendu")

	local drawnPerTeam: { [string]: number } = { A = 0, B = 0 }
	for _, id in ignored.seated do
		drawnPerTeam[ignored.teams[id]] += 1
	end
	t.equal("au tirage au sort, le camp demandé est ignoré", drawnPerTeam["A"], 2)

	-- Et les camps restent egaux quel que soit le tirage. Vingt tirages
	-- differents, parce qu'un melange ecrit a l'envers peut tomber juste sur un.
	local seed = 7
	local function pseudo(n: number): number
		seed = (seed * 31 + 17) % 1000
		return (seed % n) + 1
	end

	local uneven = 0
	local allInOne = 0
	for _ = 1, 20 do
		local plan = Seating.plan(Config, roster(6), randomMode, pseudo)
		assert(plan ~= nil, "un plan etait attendu")

		local counts: { [string]: number } = { A = 0, B = 0 }
		for _, id in plan.seated do
			counts[plan.teams[id]] += 1
		end
		if counts["A"] ~= counts["B"] then
			uneven += 1
		end
		if #plan.seated ~= 6 then
			allInOne += 1
		end
	end
	t.equal("vingt tirages, et les camps restent toujours égaux", uneven, 0)
	t.equal("et tout le monde joue toujours", allInOne, 0)
end
