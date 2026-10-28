--!strict
--[[
	Tests des effets temporaires : ralentir, etourdir, empoisonner, regenerer.

	CE QUE CES TESTS ATTRAPENT, et que personne ne verrait en jouant seul :

	  - des ralentissements qui se MULTIPLIENT. Deux objets a deux points
	    donneraient alors une immobilisation complete, que la grenade aveuglante
	    fait payer trois. Et un joueur a 10 % de sa vitesse ne croit pas qu'il
	    est ralenti : il croit que le jeu a casse.
	  - un poison qui s'empile. Toucher dix fois avec une dague a trois points
	    en ferait l'arme la plus forte du catalogue, et les tests de domination
	    ne peuvent pas le voir — ils lisent les degats par coup, pas ce qui
	    colle apres.
	  - un effet qui renforce par erreur un effet plus fort, parce que « le plus
	    grand gagne » est faux pour le ralentissement : la vitesse qui RESTE est
	    plus petite quand l'effet est plus fort. Un seul signe a l'envers et
	    reposer des chausse-trappes sur une cible deja ralentie la libererait.
	  - un effet qui ne finit jamais, ou qui finit sans que personne ne le sache.
	    `expire` doit nommer ce qui vient de tomber, parce que l'appelant a
	    quelque chose a defaire : rendre une vitesse, degeler un personnage.
]]

local Config = require("../../src/shared/Config")
local Status = require("../../src/shared/Status")

local harness = require("../harness")

return function(t: harness.Harness)
	t.section("Les quatre sortes, et rien d'autre")

	for _, kind in { Status.SLOW, Status.STUN, Status.POISON, Status.REGEN } do
		t.equal(string.format("« %s » est une sorte connue", kind), Status.isKnown(kind), true)
	end
	t.equal("« frozen » n'en est pas une", Status.isKnown("frozen"), false)
	t.equal("ni la chaine vide", Status.isKnown(""), false)

	-- Un objet qui demanderait une sorte inconnue ne doit poser RIEN, pas poser
	-- un effet muet : c'est la meme panne que les branches creuses.
	local unknown = Status.create()
	t.equal("une sorte inconnue ne pose rien", Status.apply(unknown, "frozen", 5, 1, 0), false)
	t.equal("et une duree nulle non plus", Status.apply(unknown, Status.SLOW, 0, 0.5, 0), false)

	t.section("Le ralentissement ne s'empile pas")

	local slowed = Status.create()
	Status.apply(slowed, Status.SLOW, 5, 0.6, 0)
	t.equal("un ralentissement a 60 % laisse 60 %", Status.speedRatio(Config, slowed, 1), 0.6)

	-- Deux ralentissements : on garde le PLUS FORT, c'est-a-dire la vitesse
	-- restante la plus petite. S'ils se multipliaient on tomberait a 0,36.
	Status.apply(slowed, Status.SLOW, 5, 0.8, 1)
	t.equal("un deuxieme, plus faible, ne libere pas", Status.speedRatio(Config, slowed, 2), 0.6)

	Status.apply(slowed, Status.SLOW, 5, 0.45, 2)
	t.equal("un troisieme, plus fort, l'emporte", Status.speedRatio(Config, slowed, 3), 0.45)

	-- Et le plancher tient, quoi qu'on pose.
	local floored = Status.create()
	Status.apply(floored, Status.SLOW, 5, 0, 0)
	t.equal(
		"une vitesse demandee a zero remonte au plancher",
		Status.speedRatio(Config, floored, 1),
		Config.status.minSpeedRatio
	)
	t.check("et ce plancher laisse de quoi bouger", Config.status.minSpeedRatio > 0)

	t.section("La duree la plus longue l'emporte, separement de la force")

	-- Un effet faible et long pose sur un effet fort et court garde la force du
	-- fort ET la duree du long. Les deux se decident separement, parce qu'un
	-- effet qui s'affaiblirait parce qu'on l'a repose se lirait comme un bug.
	local mixed = Status.create()
	Status.apply(mixed, Status.POISON, 2, 10, 0)
	Status.apply(mixed, Status.POISON, 8, 3, 0)

	local damage = select(1, Status.tick(mixed, 0, 1))
	t.equal("la force la plus grande reste", damage, 10)
	t.equal(
		"et l'effet court encore a la cinquieme seconde",
		Status.has(mixed, Status.POISON, 5),
		true
	)
	t.equal("mais plus a la neuvieme", Status.has(mixed, Status.POISON, 9), false)

	t.section("L'etourdissement immobilise, et il se termine")

	local stunned = Status.create()
	Status.apply(stunned, Status.STUN, 1.5, 0, 0)
	t.equal("etourdi, on ne bouge plus du tout", Status.speedRatio(Config, stunned, 0.5), 0)
	t.equal("et le jeu le sait", Status.isStunned(stunned, 0.5), true)

	local done = Status.expire(stunned, 2)
	t.equal("ce qui vient de finir est nomme", table.concat(done, " "), Status.STUN)
	t.equal("et on rebouge", Status.speedRatio(Config, stunned, 2), 1)

	-- Un etourdissement par-dessus un ralentissement gagne tant qu'il dure,
	-- puis rend la main au ralentissement. C'est le cas qui a casse une fois :
	-- degeler quelqu'un lui rendait sa pleine vitesse alors qu'il marchait
	-- encore dans les chausse-trappes.
	local both = Status.create()
	Status.apply(both, Status.SLOW, 10, 0.5, 0)
	Status.apply(both, Status.STUN, 1, 0, 0)
	t.equal("etourdi dans un ralentissement : zero", Status.speedRatio(Config, both, 0.5), 0)
	Status.expire(both, 1.5)
	t.equal(
		"l'etourdissement passe, le ralentissement reste",
		Status.speedRatio(Config, both, 1.5),
		0.5
	)

	t.section("Le poison et la regeneration se comptent separement")

	local tended = Status.create()
	Status.apply(tended, Status.POISON, 10, 8, 0)
	Status.apply(tended, Status.REGEN, 10, 5, 0)

	local hurt, healed = Status.tick(tended, 1, 0.5)
	-- QUATRE ET DEUX ET DEMI, PAS « UN ET DEMI DE DEGAT ». Un poison annule
	-- exactement par une fiole n'afficherait aucun nombre, et le joueur ne
	-- saurait pas qu'il est empoisonne.
	t.equal("le poison retire sa part", hurt, 4)
	t.equal("la regeneration rend la sienne", healed, 2.5)

	local noTime = select(1, Status.tick(tended, 1, 0))
	t.equal("un intervalle nul ne retire rien", noTime, 0)

	local after = select(1, Status.tick(tended, 11, 1))
	t.equal("et un effet fini ne retire plus rien", after, 0)

	t.section("Tout retirer d'un coup")

	local messy = Status.create()
	Status.apply(messy, Status.SLOW, 9, 0.5, 0)
	Status.apply(messy, Status.POISON, 9, 4, 0)
	Status.apply(messy, Status.STUN, 9, 0, 0)

	t.equal("trois effets sont decrits", #Status.describe(messy, 1), 3)

	local cleared = Status.clear(messy)
	t.equal("les trois sont nommes en partant", #cleared, 3)
	t.equal("et dans un ordre stable", table.concat(cleared, " "), "poison slow stun")
	t.equal("il ne reste rien a decrire", #Status.describe(messy, 1), 0)
	t.equal("la vitesse est rendue", Status.speedRatio(Config, messy, 1), 1)
	t.equal("et on n'est plus etourdi", Status.isStunned(messy, 1), false)

	t.section("Le catalogue ne nomme que des sortes connues")

	-- LE MEME GARDE-FOU QUE CELUI DU SERVEUR, mais sans Roblox : le serveur
	-- refuse de demarrer si un objet colle une sorte inconnue, et ce test le dit
	-- en deux secondes au lieu d'attendre un lancement de Studio.
	--
	-- Ce qu'il attrape : la dague empoisonnee et le pistolet a flechettes
	-- frappent moins fort que tout le reste de leur prix, et ne valent QUE par
	-- ce qu'ils collent. Une faute de frappe dans le nom de la sorte les rend
	-- inutiles, et `Status.apply` renvoie faux sans que personne ne le lise.
	local stuck = 0
	for _, item in Config.items do
		local onHit = item.onHit
		if onHit == nil then
			continue
		end
		stuck += 1
		t.equal(
			string.format("« %s » colle une sorte connue (%s)", item.id, tostring(onHit.kind)),
			Status.isKnown(onHit.kind),
			true
		)
		-- Une duree nulle ne poserait rien non plus, et pour la meme raison.
		t.check(
			string.format("et pour une duree reelle (%s)", tostring(onHit.seconds)),
			type(onHit.seconds) == "number" and onHit.seconds > 0
		)
	end
	t.check("il y a bien des armes qui collent quelque chose", stuck >= 2)

	-- Les zones qui posent un effet temporaire, meme regle. Celles qui ne
	-- passent pas par Status — la fumee, le brouilleur, la balise — n'ont rien a
	-- declarer ici.
	local STATUS_ZONES = { slow = Status.SLOW, heal = Status.REGEN, burn = nil }
	for _, item in Config.items do
		local use = item.use
		if use == nil or use.kind ~= "zone" then
			continue
		end
		local expected = STATUS_ZONES[use.effect]
		if expected == nil then
			continue
		end
		t.equal(
			string.format("la zone de « %s » pose une sorte connue", item.id),
			Status.isKnown(expected),
			true
		)
		-- Et elle doit coller pour une duree et une force reelles, sinon elle
		-- pose une part qui ne fait rien.
		t.check(
			string.format("et « %s » tient son effet un temps reel", item.id),
			type(use.holdSeconds) == "number" and use.holdSeconds > 0
		)
	end
end
