--!strict
--[[
	Tests de la zone qui se referme.

	Comme pour le combat, ces tests prennent les vrais reglages de Config : si
	quelqu'un change le nombre de paliers, les chiffres attendus suivent, mais
	les regles verifiees restent les memes.

	Ce qui est teste, c'est qu'une manche ne peut pas s'eterniser, que la zone
	ne se referme jamais d'un coup, et qu'elle previent avant de bouger.
]]

local Config = require("../../src/shared/Config")
local Zone = require("../../src/shared/Zone")

local harness = require("../harness")

local round = Config.round

-- Une copie des reglages avec un seul chiffre change, pour verifier les cas
-- limites sans toucher a l'equilibrage reel.
local function configWith(overrides: { [string]: any })
	local roundCopy: { [string]: any } = {}
	for key, value in round do
		roundCopy[key] = value
	end
	for key, value in overrides do
		roundCopy[key] = value
	end
	return { round = roundCopy }
end

return function(t: harness.Harness)
	local startRadius = 150

	t.section("Le repit avant le premier resserrement")

	t.equal("la zone ne bouge pas au debut", Zone.stepAt(Config, 0), 0)
	t.equal(
		"elle ne bouge pas une seconde avant l'heure",
		Zone.stepAt(Config, round.zoneFirstShrinkSeconds - 1),
		0
	)
	t.equal("le rayon de depart est intact", Zone.radiusAt(Config, startRadius, 0), startRadius)
	t.equal(
		"le premier resserrement est annonce des le debut",
		Zone.secondsUntilNextShrink(Config, 0),
		round.zoneFirstShrinkSeconds
	)

	t.section("Les paliers")

	t.equal(
		"le premier resserrement tombe a l'heure dite",
		Zone.stepAt(Config, round.zoneFirstShrinkSeconds),
		1
	)
	t.equal(
		"le deuxieme un intervalle plus tard",
		Zone.stepAt(Config, round.zoneFirstShrinkSeconds + round.zoneShrinkIntervalSeconds),
		2
	)
	t.equal(
		"le nombre de paliers est plafonne",
		Zone.stepAt(Config, round.zoneFirstShrinkSeconds + (round.zoneShrinkIntervalSeconds * 99)),
		round.zoneShrinkSteps
	)

	t.section("Le rayon decroit, et jamais d'un coup")

	local previous = startRadius
	local alwaysSmaller = true
	local neverHalvedAtOnce = true

	for step = 1, round.zoneShrinkSteps do
		local radius = Zone.radiusForStep(Config, startRadius, step)
		if radius >= previous then
			alwaysSmaller = false
		end
		-- Un palier qui retire plus de la moitie du rayon ne laisse pas le
		-- temps de se replacer : c'est le reglage qui rend une zone injuste.
		if radius < previous / 2 then
			neverHalvedAtOnce = false
		end
		previous = radius
	end

	t.check("chaque palier retire du terrain", alwaysSmaller)
	t.check("aucun palier ne divise le rayon par deux", neverHalvedAtOnce)
	t.equal(
		"le dernier palier atteint le rayon final",
		Zone.radiusForStep(Config, startRadius, round.zoneShrinkSteps),
		round.zoneFinalRadiusStuds
	)
	t.check("le rayon final laisse de quoi se battre", round.zoneFinalRadiusStuds > 8)

	t.section("L'avertissement")

	local justBefore = round.zoneFirstShrinkSeconds - (round.zoneWarningSeconds / 2)
	local wellBefore = round.zoneFirstShrinkSeconds - (round.zoneWarningSeconds * 2)

	t.check("la zone previent avant de bouger", Zone.isWarning(Config, justBefore) == true)
	t.check("elle ne previent pas trop tot", Zone.isWarning(Config, wellBefore) == false)

	t.section("La fin de la fermeture")

	local afterAll = round.zoneFirstShrinkSeconds
		+ (round.zoneShrinkIntervalSeconds * round.zoneShrinkSteps)

	t.check("la zone finit par se stabiliser", Zone.isClosed(Config, afterAll) == true)
	t.equal("plus rien n'est annonce", Zone.secondsUntilNextShrink(Config, afterAll), nil)
	t.check("elle n'est pas fermee au debut", Zone.isClosed(Config, 0) == false)

	t.section("Une manche ne peut pas s'eterniser")

	local total = Zone.totalShrinkSeconds(Config)
	t.check(string.format("la zone a fini de se refermer en %.0f s", total), total < 600)
	t.check("et elle prend quand meme le temps de laisser jouer", total > 60)

	t.section("Les degats")

	t.check("etre dehors fait mal", Zone.damageFor(Config, 1) > 0)
	t.equal(
		"les degats sont proportionnels au temps passe dehors",
		Zone.damageFor(Config, 2),
		Zone.damageFor(Config, 1) * 2
	)
	t.check("on est dehors au-dela du rayon", Zone.isOutside(51, 50) == true)
	t.check("on est dedans en dessous", Zone.isOutside(49, 50) == false)
	t.check("la bordure exacte compte comme dedans", Zone.isOutside(50, 50) == false)

	-- Sans ca, un joueur a PV plein mourrait dehors avant d'avoir le temps de
	-- revenir, et la zone deciderait les manches a la place du combat.
	local secondsToKill = 100 / round.zoneDamagePerSecond
	t.check(
		string.format("il faut %.0f s dehors pour perdre 100 PV", secondsToKill),
		secondsToKill > round.zoneWarningSeconds
	)

	t.section("Le rayon de depart s'adapte a la map")

	t.equal("une map de 300 studs donne un rayon de 150", Zone.startRadiusFor(Config, 300), 150)
	t.equal(
		"sans MapBounds, le rayon par defaut",
		Zone.startRadiusFor(Config, nil),
		round.zoneStartRadiusFallbackStuds
	)
	t.equal(
		"une taille absurde retombe aussi sur le defaut",
		Zone.startRadiusFor(Config, 0),
		round.zoneStartRadiusFallbackStuds
	)

	t.section("Les cas limites")

	local noSteps = configWith({ zoneShrinkSteps = 0 })
	t.equal("sans palier, la zone ne bouge jamais", Zone.stepAt(noSteps, 10000), 0)
	t.equal(
		"et le rayon reste celui du depart",
		Zone.radiusAt(noSteps, startRadius, 10000),
		startRadius
	)
	t.equal("rien n'est annonce", Zone.secondsUntilNextShrink(noSteps, 0), nil)

	-- Une arene plus petite que le rayon final : la zone ne doit surtout pas
	-- demarrer deja mortelle.
	local tiny = Zone.radiusForStep(Config, 10, round.zoneShrinkSteps)
	t.equal("sur une arene minuscule, la zone ne se referme pas", tiny, 10)
end
