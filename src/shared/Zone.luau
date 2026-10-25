--!strict
--[[
	Zone — le calcul de la zone qui se referme.

	Logique pure : aucun require, aucune API Roblox. Le temps arrive en
	argument, sous la forme de secondes ecoulees depuis le debut de la manche,
	et les reglages aussi. ZoneService se charge de dessiner le cylindre et
	d'enlever des PV ; ici on ne fait que dire ou en est la zone.

	Le decoupage du temps :

	    0                    T1              T1+I            T1+2I
	    |------ repit -------|--- palier 1 ---|--- palier 2 ---| ...

	T1 vaut zoneFirstShrinkSeconds, I vaut zoneShrinkIntervalSeconds. Apres
	zoneShrinkSteps resserrements la zone ne bouge plus : elle a atteint son
	rayon final et la manche se decide au contact.

	Deux decisions qui comptent :

	- Le rayon change d'un coup, pas progressivement. Une zone qui glisse en
	  continu est jolie mais illisible : on ne sait jamais si on est dedans.
	  Un palier franc, annonce zoneWarningSeconds a l'avance, se comprend.
	- Les paliers sont geometriques et pas lineaires : chaque resserrement
	  retire la meme PROPORTION du rayon, pas la meme largeur. En lineaire, du
	  rayon de depart au rayon final en quatre paliers, le dernier divisait le
	  rayon par trois d'un seul coup pendant que le premier le touchait a
	  peine. Un test le verifie et casse si on revient en arriere.
	- Les degats ne dependent pas de la distance. Etre dehors coute le meme
	  prix a un pas ou a cinquante, sinon on apprend a longer la bordure et la
	  zone ne pousse plus personne vers le centre.
]]

local Zone = {}

-- Le palier atteint : 0 tant que la zone n'a pas bouge, puis 1, 2... jusqu'a
-- zoneShrinkSteps.
function Zone.stepAt(config, elapsedSeconds: number): number
	local round = config.round
	if round.zoneShrinkSteps <= 0 or elapsedSeconds < round.zoneFirstShrinkSeconds then
		return 0
	end

	local sinceFirst = elapsedSeconds - round.zoneFirstShrinkSeconds
	local step = 1 + math.floor(sinceFirst / round.zoneShrinkIntervalSeconds)
	return math.min(step, round.zoneShrinkSteps)
end

-- Le rayon a un palier donne.
--
-- L'interpolation est geometrique : chaque palier multiplie le rayon par la
-- meme constante, donc tous les resserrements se ressentent pareil. Le dernier
-- ne doit pas etre celui qui tue la manche.
function Zone.radiusForStep(config, startRadius: number, step: number): number
	local round = config.round
	if round.zoneShrinkSteps <= 0 then
		return startRadius
	end

	-- Sur une map plus petite que le rayon final, la zone ne se referme pas :
	-- mieux vaut une zone inutile qu'une zone deja mortelle au spawn.
	local finalRadius = math.min(round.zoneFinalRadiusStuds, startRadius)

	if step <= 0 then
		return startRadius
	end
	-- Sortie exacte au dernier palier : l'elevation a la puissance laisserait
	-- une poussiere de virgule, et le rayon final est un chiffre qu'on compare.
	if step >= round.zoneShrinkSteps then
		return finalRadius
	end
	if startRadius <= 0 or finalRadius <= 0 then
		return finalRadius
	end

	return startRadius * ((finalRadius / startRadius) ^ (step / round.zoneShrinkSteps))
end

function Zone.radiusAt(config, startRadius: number, elapsedSeconds: number): number
	return Zone.radiusForStep(config, startRadius, Zone.stepAt(config, elapsedSeconds))
end

-- Secondes avant le prochain resserrement, ou nil quand la zone a fini de se
-- refermer.
function Zone.secondsUntilNextShrink(config, elapsedSeconds: number): number?
	local round = config.round
	if round.zoneShrinkSteps <= 0 then
		return nil
	end

	local step = Zone.stepAt(config, elapsedSeconds)
	if step >= round.zoneShrinkSteps then
		return nil
	end

	local nextAt = round.zoneFirstShrinkSeconds + (step * round.zoneShrinkIntervalSeconds)
	return math.max(nextAt - elapsedSeconds, 0)
end

-- Vrai pendant le compte a rebours qui precede un resserrement.
function Zone.isWarning(config, elapsedSeconds: number): boolean
	local remaining = Zone.secondsUntilNextShrink(config, elapsedSeconds)
	return remaining ~= nil and remaining <= config.round.zoneWarningSeconds
end

-- Vrai quand la zone ne bougera plus.
function Zone.isClosed(config, elapsedSeconds: number): boolean
	return Zone.secondsUntilNextShrink(config, elapsedSeconds) == nil
end

function Zone.isOutside(distanceFromCenter: number, radius: number): boolean
	return distanceFromCenter > radius
end

function Zone.damageFor(config, deltaSeconds: number): number
	return config.round.zoneDamagePerSecond * deltaSeconds
end

-- Le rayon de depart, deduit de la largeur de la map pour qu'une petite arene
-- et une grande se referment toutes les deux sans qu'on touche a un chiffre.
function Zone.startRadiusFor(config, mapWidthStuds: number?): number
	local round = config.round
	if mapWidthStuds == nil or mapWidthStuds <= 0 then
		return round.zoneStartRadiusFallbackStuds
	end
	return mapWidthStuds * round.zoneStartRadiusMapRatio
end

-- Combien de temps une manche peut durer avant que la zone ait fini de se
-- refermer. Sert a verifier qu'une manche ne peut pas s'eterniser.
function Zone.totalShrinkSeconds(config): number
	local round = config.round
	if round.zoneShrinkSteps <= 0 then
		return math.huge
	end
	return round.zoneFirstShrinkSeconds
		+ ((round.zoneShrinkSteps - 1) * round.zoneShrinkIntervalSeconds)
end

return Zone
