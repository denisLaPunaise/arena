--!strict
--[[
	Tests des pouvoirs de classe.

	Ce qui est verifie ici est ce qui casse l'equilibrage en silence :

	  - le Duelliste doit vraiment basculer d'un cote a l'autre selon le nombre
	    d'ennemis. Son pouvoir ET sa faiblesse sont le meme chiffre, et un signe
	    inverse donnerait une classe qui frappe plus fort a plusieurs.
	  - le Lien ne doit jamais mourir a la place de son allie d'un seul coup.
	  - le Cameleon ne doit pas pouvoir se camoufler en courant.
	  - un pouvoir absent doit rester sans effet, puisque chaque classe ne porte
	    que ses propres chiffres et qu'ils sont tous facultatifs.
]]

local Abilities = require("../../src/shared/Abilities")
local Config = require("../../src/shared/Config")

local harness = require("../harness")

return function(t: harness.Harness)
	t.section("La recharge, commune a tous les pouvoirs actifs")

	local artificer = Config.classStats.artificer

	t.check("sans usage precedent, le pouvoir est pret", Abilities.isReady(artificer, 100, nil))
	t.check("juste apres usage, il ne l'est plus", Abilities.isReady(artificer, 100, 99.5) == false)
	t.check(
		"une fois la recharge ecoulee, il revient",
		Abilities.isReady(artificer, 100, 100 - artificer.abilityCooldownSeconds)
	)
	t.equal(
		"ce qui reste a attendre ne descend jamais sous zero",
		Abilities.cooldownLeft(artificer, 100, 0),
		0
	)

	t.section("Duelliste : le meme chiffre vu des deux cotes")

	local duelist = Config.classStats.duelist

	-- Un seul ennemi : le bonus. Deux ou plus : la penalite. C'est la bascule
	-- qui fait la classe, et elle doit tomber exactement a deux.
	t.check("seul contre un, il frappe plus fort", Abilities.duelMultiplier(duelist, 1) > 1)
	t.check("sans personne, le bonus vaut quand meme", Abilities.duelMultiplier(duelist, 0) > 1)
	t.check("a deux ennemis, il frappe plus faible", Abilities.duelMultiplier(duelist, 2) < 1)
	t.check(
		"a cinq ennemis, pas pire qu'a deux",
		Abilities.duelMultiplier(duelist, 5) == Abilities.duelMultiplier(duelist, 2)
	)

	-- Le multiplicateur ne doit jamais s'inverser : une penalite qui depasse
	-- cent pour cent rendrait les coups soignants.
	t.check("le coup ne devient jamais negatif", Abilities.duelMultiplier({
		duelBonusRatio = 0,
		duelPenaltyRatio = -5,
	}, 3) >= 0)

	-- Une classe qui n'est pas Duelliste ne doit rien y gagner ni y perdre.
	t.equal(
		"une classe sans isolement frappe normalement",
		Abilities.duelMultiplier(Config.classStats.vampire, 3),
		1
	)

	t.section("Lien : partager sans mourir a la place de l'autre")

	local link = Config.classStats.link

	local shared = Abilities.bondShare(Config, link, 40)
	t.check("il prend bien une part", shared > 0)
	t.check("et pas la totalite", shared < 40)
	t.equal(
		"ce qui reste a l'allie complete exactement",
		math.floor((shared + Abilities.bondRemainder(40, shared)) + 0.5),
		40
	)

	-- LE TEST QUI COMPTE. Un coup enorme ne doit pas traverser le plafond :
	-- sans lui, lier un allie reviendrait a mourir avec lui.
	local huge = Abilities.bondShare(Config, link, 10000)
	t.check(
		"un coup enorme reste plafonne",
		huge <= link.maxHealth * Config.abilities.tuning.bondMaxShareFraction + 1e-6
	)

	t.equal(
		"une classe sans lien ne partage rien",
		Abilities.bondShare(Config, Config.classStats.vampire, 50),
		0
	)

	t.section("Parasite : vivre sur les soins des autres")

	local parasite = Config.classStats.parasite
	t.check("il prend une part des soins", Abilities.healSteal(parasite, 20) > 0)
	t.check("et jamais plus que le soin lui-meme", Abilities.healSteal(parasite, 20) <= 20)
	t.equal(
		"une classe sans marque ne vole rien",
		Abilities.healSteal(Config.classStats.smith, 20),
		0
	)

	t.section("Cameleon : immobile, et depuis assez longtemps")

	local chameleon = Config.classStats.chameleon

	t.check(
		"arrete depuis assez longtemps, il disparait",
		Abilities.shouldCloak(chameleon, 0, chameleon.cloakDelaySeconds + 0.1)
	)
	t.check(
		"arrete depuis trop peu, il est encore visible",
		Abilities.shouldCloak(chameleon, 0, chameleon.cloakDelaySeconds - 0.1) == false
	)
	t.check(
		"en mouvement, il ne disparait jamais",
		Abilities.shouldCloak(chameleon, chameleon.cloakSpeedThreshold + 1, 100) == false
	)
	t.check(
		"une classe sans camouflage ne disparait pas",
		Abilities.shouldCloak(Config.classStats.colossus, 0, 100) == false
	)

	t.section("Infirmier : relever plus vite et mieux")

	local medic = Config.classStats.medic

	t.check("il releve plus vite que les autres", Abilities.reviveSpeed(medic) > 1)
	t.equal(
		"les autres relevent a vitesse normale",
		Abilities.reviveSpeed(Config.classStats.smith),
		1
	)

	local ratio = Abilities.reviveHealthRatio(Config, medic)
	t.check("il rend plus de PV que la regle commune", ratio > Config.downed.reviveHealthRatio)
	t.check("mais jamais plus que la totalite", ratio <= 1)

	t.section("Brasier et onde de choc")

	local pyro = Config.classStats.pyromaniac
	t.equal(
		"le brasier blesse au prorata du temps passe dedans",
		Abilities.fireTickDamage(pyro, 2),
		pyro.fireDamagePerSecond * 2
	)
	t.equal("une classe sans flammes ne brule personne", Abilities.fireTickDamage(medic, 2), 0)

	local seismic = Config.classStats.seismic
	local slowSpeed = Abilities.slowedSpeed(20, seismic.slamSlowRatio)
	t.check("l'onde ralentit vraiment", slowSpeed < 20)
	-- Ralentir n'est pas immobiliser : quelqu'un qui ne peut plus bouger du tout
	-- n'a plus de decision a prendre, et la manche se joue sans lui.
	t.check("mais n'immobilise jamais", slowSpeed >= 20 * 0.25 - 1e-6)
end
