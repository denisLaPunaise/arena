--!strict
--[[
	Tests de l'agonie et du relevement.

	Ce qui est verifie ici n'est pas une valeur mais une regle de jeu : qu'un
	joueur a terre puisse etre acheve, qu'un relevement interrompu reparte de
	zero, et qu'une equipe sans personne pour relever ne fasse pas attendre
	tout le monde dix secondes pour rien.
]]

local Config = require("../../src/shared/Config")
local Downed = require("../../src/shared/Downed")

local harness = require("../harness")

local downed = Config.downed

-- Une copie des reglages avec quelques chiffres changes, pour verifier les
-- interrupteurs sans toucher a l'equilibrage reel.
local function configWith(overrides: { [string]: any })
	local copy: { [string]: any } = {}
	for key, value in downed do
		copy[key] = value
	end
	for key, value in overrides do
		copy[key] = value
	end
	return { downed = copy }
end

return function(t: harness.Harness)
	t.section("Tomber")

	local fighter = Downed.create("1", "A")
	t.equal("on commence debout", fighter.status, "standing")

	Downed.knockDown(Config, fighter, 0)
	t.equal("a zero PV on passe a terre, pas mort", fighter.status, "downed")
	t.equal("la fenetre est pleine", Downed.secondsLeft(Config, fighter, 0), downed.windowSeconds)

	-- Un deuxieme coup ne doit pas relancer la fenetre : sinon se faire frapper
	-- a terre rallonge la vie au lieu de la raccourcir.
	Downed.knockDown(Config, fighter, 5)
	t.equal(
		"un second coup ne relance pas la fenetre",
		Downed.secondsLeft(Config, fighter, 5),
		downed.windowSeconds - 5
	)

	t.section("La fenetre se referme")

	t.check(
		"elle ne se referme pas avant l'heure",
		Downed.expire(Config, fighter, downed.windowSeconds - 1) == false
	)
	t.check(
		"elle se referme a l'heure dite",
		Downed.expire(Config, fighter, downed.windowSeconds) == true
	)
	t.equal("et le joueur est elimine", fighter.status, "out")
	t.equal("un elimine n'a plus de temps", Downed.secondsLeft(Config, fighter, 0), 0)

	t.section("Le coup de grace")

	local victim = Downed.create("2", "B")
	t.check("on n'acheve pas quelqu'un debout", Downed.finish(Config, victim) == false)

	Downed.knockDown(Config, victim, 0)
	t.check("on acheve quelqu'un a terre", Downed.finish(Config, victim) == true)
	t.equal("il est elimine", victim.status, "out")
	t.check("on ne l'acheve pas deux fois", Downed.finish(Config, victim) == false)

	local protected = Downed.create("3", "B")
	Downed.knockDown(Config, protected, 0)
	t.check(
		"avec le coup de grace coupe, il reste a terre",
		Downed.finish(configWith({ canBeFinished = false }), protected) == false
	)
	t.equal("son etat ne change pas", protected.status, "downed")

	t.section("Le relevement")

	local hurt = Downed.create("4", "A")
	Downed.knockDown(Config, hurt, 0)

	t.equal("la barre part de zero", Downed.reviveRatio(Config, hurt), 0)
	t.check("une seconde ne suffit pas", Downed.addReviveProgress(Config, hurt, 1) == false)
	t.check("la barre a avance", Downed.reviveRatio(Config, hurt) > 0)
	t.check("mais elle n'est pas pleine", Downed.reviveRatio(Config, hurt) < 1)

	-- Le moindre degat remet a zero : relever au milieu d'un echange de coups
	-- doit etre impossible, sinon gagner l'echange ne sert a rien.
	Downed.interruptRevive(Config, hurt)
	t.equal("un degat recu remet la barre a zero", Downed.reviveRatio(Config, hurt), 0)
	t.equal("et le joueur est toujours a terre", hurt.status, "downed")

	t.check(
		"le relevement complet remet debout",
		Downed.addReviveProgress(Config, hurt, downed.reviveSeconds) == true
	)
	t.equal("il est debout", hurt.status, "standing")
	t.check(
		"on ne releve pas quelqu'un de debout",
		Downed.addReviveProgress(Config, hurt, 10) == false
	)

	t.section("Se relever coute quelque chose")

	local revived = Downed.reviveHealth(Config, 100)
	t.check("on repart avec des PV", revived > 0)
	t.check("mais pas a PV plein : tomber doit couter", revived < 100)
	t.check("et a terre on rampe", Downed.crawlSpeed(Config, 20) < 20)
	t.check("sans etre immobile", Downed.crawlSpeed(Config, 20) > 0)

	t.section("L'agonie coupee")

	local off = configWith({ enabled = false })
	local direct = Downed.create("5", "A")
	Downed.knockDown(off, direct, 0)
	t.equal("sans agonie, zero PV elimine directement", direct.status, "out")

	t.section("Lecture d'equipe")

	local a1 = Downed.create("a1", "A")
	local a2 = Downed.create("a2", "A")
	local b1 = Downed.create("b1", "B")
	local squad = { a1, a2, b1 }

	t.check("tout le monde peut relever au depart", Downed.hasReviver(squad, "A") == true)
	t.check("personne n'est elimine", Downed.isEliminated(squad, "A") == false)
	t.equal("la manche n'a pas de vainqueur", Downed.roundWinner(squad), nil)
	t.check("et elle n'est pas finie", Downed.roundIsOver(squad) == false)

	Downed.knockDown(Config, a1, 0)
	t.check("un blesse n'elimine pas son equipe", Downed.isEliminated(squad, "A") == false)
	t.check("son coequipier debout peut le relever", Downed.hasReviver(squad, "A") == true)
	t.check("la manche continue", Downed.roundIsOver(squad) == false)

	t.section("Plus personne pour relever")

	Downed.knockDown(Config, a2, 0)
	t.check("l'equipe n'a plus de releveur", Downed.hasReviver(squad, "A") == false)

	local collapsed = Downed.collapseTeamsWithoutReviver(Config, squad)
	t.equal("les deux blesses sont elimines d'un coup", #collapsed, 2)
	t.check("l'equipe est eliminee", Downed.isEliminated(squad, "A") == true)
	t.equal("l'autre equipe gagne la manche", Downed.roundWinner(squad), "B")
	t.check("la manche est finie", Downed.roundIsOver(squad) == true)

	t.section("L'interrupteur du temps mort")

	local keep = configWith({ endRoundWhenNoReviverLeft = false })
	local c1 = Downed.create("c1", "A")
	local c2 = Downed.create("c2", "B")
	local pair = { c1, c2 }
	Downed.knockDown(Config, c1, 0)

	t.equal(
		"avec le reglage coupe, on laisse la fenetre courir",
		#Downed.collapseTeamsWithoutReviver(keep, pair),
		0
	)
	t.equal("le blesse reste a terre", c1.status, "downed")

	t.section("La manche nulle")

	local d1 = Downed.create("d1", "A")
	local d2 = Downed.create("d2", "B")
	local both = { d1, d2 }
	Downed.knockDown(Config, d1, 0)
	Downed.knockDown(Config, d2, 0)
	Downed.expire(Config, d1, downed.windowSeconds)
	Downed.expire(Config, d2, downed.windowSeconds)

	t.equal("tout le monde elimine ne donne aucun vainqueur", Downed.roundWinner(both), nil)
	t.check("mais la manche est bien finie", Downed.roundIsOver(both) == true)

	t.section("La fenetre laisse le temps d'arriver")

	-- Si relever prend plus de temps que la fenetre n'en laisse, le relevement
	-- est decoratif : personne ne peut jamais finir la barre.
	t.check(
		string.format(
			"relever prend %.0f s pour une fenetre de %.0f s",
			downed.reviveSeconds,
			downed.windowSeconds
		),
		downed.reviveSeconds < downed.windowSeconds
	)
	t.check(
		"et il reste du temps pour traverser la map",
		(downed.windowSeconds - downed.reviveSeconds) >= 4
	)
end
