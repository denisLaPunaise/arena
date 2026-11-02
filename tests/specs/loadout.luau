--!strict
--[[
	Tests de l'equipement et de son budget.

	Ce que ces tests attrapent, et que personne ne verrait en jouant :

	  - un objet qui pousse une statistique que le combat ne lit pas. C'est la
	    panne des branches creuses, transposee aux objets : l'objet coute ses
	    points et ne fait rien.
	  - une affinite sur un objet a un point, qui le rendrait GRATUIT, donc pris
	    par tout le monde, donc plus un choix.
	  - un objet strictement meilleur qu'un autre moins cher ou au meme prix.
	    Celui-la ruine le budget en silence : il n'y a plus de choix, il y a une
	    bonne reponse.
	  - un assemblage par defaut illegal, ou qui laisse des points sur la table.
	  - les planchers, qu'un facteur agressif pourrait traverser.
]]

local Config = require("../../src/shared/Config")
local Loadout = require("../../src/shared/Loadout")
local Modifiers = require("../../src/shared/Modifiers")

local harness = require("../harness")

local function countOf(category: string): number
	return #Loadout.byCategory(Config, category)
end

return function(t: harness.Harness)
	t.section("Le catalogue")

	-- LE NOMBRE N'EST PAS ECRIT ICI, et c'est delibere : un test qui nomme son
	-- chiffre en dur se mord la queue le jour ou le catalogue change, et on
	-- cherche alors une regression qui n'existe pas. C'est Config qui dit
	-- combien d'objets chaque categorie doit contenir.
	local target = Config.itemCounts.target
	local totalAnnounced = 0
	for category, expected in target do
		t.equal(
			string.format("%s : %d objets comme annonce", category, expected),
			countOf(category),
			expected
		)
		totalAnnounced += expected
	end
	t.equal("et le catalogue tient dans ce total", #Config.items, totalAnnounced)

	local ids: { [string]: boolean } = {}
	local duplicateId = false
	local missingText = false
	for _, item in Config.items do
		if ids[item.id] then
			duplicateId = true
		end
		ids[item.id] = true
		if item.name == nil or item.summary == nil then
			missingText = true
		end
	end
	t.check("aucun identifiant en double", not duplicateId)
	t.check("chaque objet a un nom et une description", not missingText)

	-- Le cout porte la puissance, donc il doit rester dans la fourchette de sa
	-- categorie : une arme principale a deux points casserait le barem entier.
	local outOfRange: string? = nil
	for _, item in Config.items do
		local range: any = nil
		for _, category in Config.loadout.categories do
			if category.id == item.category then
				range = category
			end
		end
		if range == nil then
			outOfRange = item.id .. " (categorie inconnue)"
		elseif item.cost < range.minCost or item.cost > range.maxCost then
			outOfRange = item.id
		end
	end
	t.equal("chaque cout tient dans la fourchette de sa categorie", outOfRange, nil)

	t.section("Aucun objet ne pousse une statistique morte")

	-- Le meme garde-fou que pour les branches d'arbre : si un objet modifie une
	-- cle qui n'existe pas dans les statistiques de base de chaque classe, il
	-- coute ses points et ne fait rien. Le combat ne lira jamais cette cle.
	local deadKey: string? = nil
	for _, item in Config.items do
		local touched: { [string]: boolean } = {}
		for key in item.scale or {} do
			touched[key] = true
		end
		for key in item.offset or {} do
			touched[key] = true
		end
		for key in touched do
			for classId, stats in Config.classStats do
				if stats[key] == nil then
					deadKey = string.format("%s pousse %s, absent du %s", item.id, key, classId)
				end
			end
		end
	end
	t.equal("toute cle touchee par un objet existe dans chaque classe", deadKey, nil)

	-- Un objet sans `use` et sans aucune modification ne fait litteralement
	-- rien. Il n'y en a aucun, et il ne doit jamais y en avoir.
	local inert: string? = nil
	for _, item in Config.items do
		local hasScale = item.scale ~= nil and next(item.scale) ~= nil
		local hasOffset = item.offset ~= nil and next(item.offset) ~= nil
		local hasUse = item.use ~= nil
		local hasPierce = (item.armorPierceRatio or 0) > 0
		if not (hasScale or hasOffset or hasUse or hasPierce) then
			inert = item.id
		end
	end
	t.equal("aucun objet inerte", inert, nil)

	t.section("Les affinites")

	local unknownAffinity: string? = nil
	local cheapAffinity: string? = nil
	local tooMany: string? = nil
	local missingClass: string? = nil

	for classId in Config.classStats do
		if Config.itemAffinities[classId] == nil then
			missingClass = classId
		end
	end
	t.equal("chaque classe a une liste d'affinites", missingClass, nil)

	for classId, list in Config.itemAffinities do
		if Config.classStats[classId] == nil then
			unknownAffinity = classId .. " n'est pas une classe"
		end
		if #list > Config.loadout.affinityItemsPerClassMax then
			tooMany = classId
		end
		for _, itemId in list do
			local item = Loadout.find(Config, itemId)
			if item == nil then
				unknownAffinity = classId .. " → " .. itemId
			elseif item.cost <= Config.loadout.affinityDiscount then
				-- Avec la remise, il tomberait a zero : gratuit, donc pris par
				-- tout le monde, donc plus un choix du tout.
				cheapAffinity = classId .. " → " .. itemId
			end
		end
	end

	t.equal("toute affinite pointe vers un objet qui existe", unknownAffinity, nil)
	t.equal("aucune affinite sur un objet a un point", cheapAffinity, nil)
	t.equal("jamais plus de trois affinites par classe", tooMany, nil)

	-- Les deux exemples que la fiche donne doivent tomber juste a l'unite.
	t.equal(
		"le Traqueur paie l'arc composite cinq au lieu de six",
		Loadout.costOfId(Config, "compositeBow", "tracker"),
		5
	)
	t.equal(
		"le Colosse paie le bouclier trois au lieu de quatre",
		Loadout.costOfId(Config, "deployableShield", "colossus"),
		3
	)
	t.equal(
		"et il paie l'arc plein tarif, faute d'affinite",
		Loadout.costOfId(Config, "compositeBow", "colossus"),
		6
	)

	t.section("Le budget")

	local rules = Config.loadout
	t.equal("douze points", rules.budgetPoints, 12)

	-- L'assemblage du tireur de la fiche, avec les objets qui existent.
	local marksman = { "warhammer", "lightArmor", "medkit", "lightMine" }
	local check = Loadout.validate(Config, marksman, "vampire")
	t.check("marteau + armure legere + trousse + mine : valide", check.ok)
	t.equal("et il depense exactement douze points", check.spent, 12)
	t.equal("il ne reste rien", check.left, 0)

	-- Sept plus cinq fait douze : c'est l'assemblage du tank, deux objets et
	-- rien d'autre, et il est parfaitement legal. Il n'y a plus un point pour
	-- se soigner, et c'est tout le sujet du budget.
	local tank = Loadout.validate(Config, { "warhammer", "heavyArmor" }, "vampire")
	t.check("marteau + armure lourde : valide, et il ne reste rien", tank.ok)
	t.equal("douze points pile", tank.spent, 12)
	t.check("aucun consommable", #Loadout.usables(Config, { "warhammer", "heavyArmor" }) == 0)

	local far = Loadout.validate(Config, { "warhammer", "heavyArmor", "medkit" }, "vampire")
	t.check("y ajouter une trousse : refuse", not far.ok)
	t.equal("quatorze points pour douze", far.spent, 14)

	local noWeapon = Loadout.validate(Config, { "lightArmor", "medkit" }, "vampire")
	t.check("sans arme principale : refuse", not noWeapon.ok)
	t.equal("et le refus le dit", noWeapon.reason, "Il faut une arme principale")

	local twoArmors = Loadout.validate(Config, { "machete", "lightArmor", "heavyArmor" }, "vampire")
	t.check("deux armures : refuse", not twoArmors.ok)

	local twoPrimaries = Loadout.validate(Config, { "machete", "shotgun" }, "vampire")
	t.check("deux armes principales : refuse", not twoPrimaries.ok)

	local duplicated = Loadout.validate(Config, { "machete", "lightMine", "lightMine" }, "vampire")
	t.check("deux fois le meme objet : refuse", not duplicated.ok)
	t.equal("et le refus le dit", duplicated.reason, "Deux fois le même objet")

	local unknown = Loadout.validate(Config, { "machete", "lancepierre" }, "vampire")
	t.check("un objet inconnu : refuse", not unknown.ok)

	-- Sept objets, meme a budget tenu, restent refuses : six au maximum.
	local crowded = Loadout.validate(Config, {
		"machete",
		"stimulant",
		"lightMine",
		"grenade",
		"lightArmor",
		"knife",
		"medkit",
	}, "vampire")
	t.check("sept objets : refuse", not crowded.ok)

	t.section("L'affinite change ce qui rentre dans le budget")

	-- Le meme assemblage, pour deux classes : l'affinite du Colosse lui fait
	-- rentrer ce que le Vampire ne peut pas se payer. C'est litteralement le
	-- role des affinites, et c'est verifiable.
	local heavy = { "warhammer", "heavyArmor" }
	t.equal("le Vampire paie cet assemblage douze", Loadout.spent(Config, heavy, "vampire"), 12)
	t.equal("le Colosse le paie dix", Loadout.spent(Config, heavy, "colossus"), 10)
	local colossusOk, _ = Loadout.canAdd(Config, heavy, "colossus", "medkit")
	t.check("donc le Colosse peut encore y ajouter une trousse de soin", colossusOk)
	local vampireOk, _ = Loadout.canAdd(Config, heavy, "vampire", "medkit")
	t.check("et le Vampire ne peut pas", not vampireOk)

	t.section("Une arme en remplace une autre")

	-- Les categories limitees a un seul objet se remplacent au lieu de se
	-- refuser : sans ca, l'ecran verrouille les trois armes qu'on ne porte pas
	-- et affiche « une au maximum » a la place de ce qu'elles font.
	local carried = { "machete", "lightArmor", "stimulant" }

	local swapped = Loadout.withSwap(Config, carried, "warhammer")
	t.check("prendre le marteau repose la machette", not Loadout.contains(swapped, "machete"))
	t.check("et garde le reste", Loadout.contains(swapped, "lightArmor"))

	local swappedArmor = Loadout.withSwap(Config, carried, "heavyArmor")
	t.check(
		"prendre l'armure lourde repose la legere",
		not Loadout.contains(swappedArmor, "lightArmor")
	)
	t.check("et garde l'arme", Loadout.contains(swappedArmor, "machete"))

	-- Les utilitaires s'empilent, donc rien a remplacer : c'est tout l'interet
	-- de la categorie, et le remplacement ne doit surtout pas s'y appliquer.
	local stacked = Loadout.withSwap(Config, carried, "grenade")
	t.equal("un utilitaire ne remplace rien", #stacked, #carried)

	local same = Loadout.withSwap(Config, carried, "machete")
	t.equal("se reprendre son arme ne la repose pas", #same, #carried)

	-- Et le remplacement doit rester soumis au budget : prendre le marteau a
	-- la place de la machette coute quatre points de plus, et c'est refuse s'ils
	-- ne sont pas la.
	local rich = Loadout.withSwap(Config, carried, "warhammer")
	local richOk = Loadout.canAdd(Config, rich, "vampire", "warhammer")
	t.check("le remplacement passe quand le budget suit", richOk)

	local tight = { "machete", "heavyArmor", "stimulant", "lightMine" }
	local tightOk =
		Loadout.canAdd(Config, Loadout.withSwap(Config, tight, "warhammer"), "vampire", "warhammer")
	t.check("et il est refuse quand il ne suit pas", not tightOk)

	t.section("L'assemblage par defaut")

	-- Un joueur qui n'ouvre jamais l'ecran d'equipement doit quand meme arriver
	-- en manche avec un assemblage legal et son budget depense.
	local worstLeftover = -1
	local illegal: string? = nil
	for classId in Config.classStats do
		local default = Loadout.defaultFor(Config, classId)
		local defaultCheck = Loadout.validate(Config, default, classId)
		if not defaultCheck.ok then
			illegal = classId .. " : " .. tostring(defaultCheck.reason)
		end
		if defaultCheck.left > worstLeftover then
			worstLeftover = defaultCheck.left
		end
	end
	t.equal("legal pour les quatorze classes", illegal, nil)
	t.check(
		string.format("et il ne laisse jamais plus d'un point de cote (%d)", worstLeftover),
		worstLeftover <= 1
	)

	-- DE LA LARGEUR, et c'est un garde-fou contre une vraie regression : la
	-- premiere version prenait le plus cher de chaque categorie, donc l'armure
	-- lourde pour les quatorze classes. Tous les debutants arrivaient lents, et
	-- la premiere chose que le jeu leur apprenait etait qu'on ne court pas.
	local narrow: string? = nil
	local slow: string? = nil
	for classId in Config.classStats do
		local default = Loadout.defaultFor(Config, classId)
		local seen: { [string]: boolean } = {}
		for _, itemId in default do
			local item = Loadout.find(Config, itemId)
			if item ~= nil then
				seen[item.category] = true
			end
		end
		local breadth = 0
		for _ in seen do
			breadth += 1
		end
		if breadth < 4 then
			narrow = classId
		end
		local armor = Loadout.weaponOf(Config, default, "armor")
		if armor ~= nil and (armor.scale or {}).walkSpeed ~= nil then
			slow = classId
		end
	end
	t.equal("il touche au moins quatre categories", narrow, nil)
	t.equal("et il ne met personne en armure qui ralentit", slow, nil)

	local defaultVampire = Loadout.defaultFor(Config, "vampire")
	t.check(
		"il contient une arme principale",
		Loadout.weaponOf(Config, defaultVampire, "primary") ~= nil
	)
	t.check("et de quoi se soigner", #Loadout.usables(Config, defaultVampire) > 0)

	t.section("Aucun objet n'est strictement meilleur qu'un autre")

	-- Si une arme est a la fois plus forte et plus longue qu'une autre qui
	-- coute autant ou plus, le budget n'a plus de sens : il y a une bonne
	-- reponse au lieu d'un choix. On compare les degats par seconde et la
	-- portee, en facteurs, parce que c'est ce que l'objet applique vraiment.
	local function dpsFactor(item: any): number
		local scale = item.scale or {}
		return (scale.attackDamage or 1) / (scale.attackCooldownSeconds or 1)
	end
	local function rangeFactor(item: any): number
		return (item.scale or {}).attackRangeStuds or 1
	end

	-- DEUX AXES QUE LES DEGATS PAR SECONDE NE MONTRENT PAS, et sans lesquels ce
	-- test accuse a tort. Une arme qui ralentit sa cible, qui perce une armure
	-- ou qui pousse n'est pas « moins bonne » parce qu'elle frappe moins fort :
	-- elle achete autre chose. Et une arme qui ne tire que six fois par manche,
	-- qui ne tire pas au contact ou qui cloue sur place n'est pas « meilleure »
	-- parce qu'elle frappe plus fort : elle le paie ailleurs.
	--
	-- Donc la regle est : A n'ecrase B que si A n'a aucun inconvenient de plus
	-- que B, et B aucun atout de plus que A. Sur les armes sans particularite —
	-- la moitie du catalogue, et celles ou le danger est reel — le test garde
	-- exactement les dents qu'il avait.
	local PERKS = { "armorPierceRatio", "onHit", "weaponBlast", "use", "offset" }
	local DRAWBACKS = { "minRangeStuds", "selfSlowSeconds", "shotsPerRound" }

	local function hasExtra(left: any, right: any, keys: { string }): boolean
		for _, key in keys do
			if left[key] ~= nil and right[key] == nil then
				return true
			end
		end
		return false
	end

	local dominated: string? = nil
	for _, category in { "primary", "secondary" } do
		local weapons = Loadout.byCategory(Config, category)
		for _, a in weapons do
			for _, b in weapons do
				if a.id == b.id or a.cost > b.cost then
					continue
				end
				if hasExtra(a, b, DRAWBACKS) or hasExtra(b, a, PERKS) then
					continue
				end
				local betterDps = dpsFactor(a) >= dpsFactor(b)
				local betterRange = rangeFactor(a) >= rangeFactor(b)
				local strictly = dpsFactor(a) > dpsFactor(b) or rangeFactor(a) > rangeFactor(b)
				if betterDps and betterRange and strictly then
					dominated = string.format("%s ecrase %s", a.id, b.id)
				end
			end
		end
	end
	t.equal("aucune arme n'ecrase une arme aussi chere ou plus chere", dominated, nil)

	local armorDominated: string? = nil
	for _, a in Loadout.byCategory(Config, "armor") do
		for _, b in Loadout.byCategory(Config, "armor") do
			if a.id == b.id or a.cost > b.cost then
				continue
			end
			-- QUATRE AXES, PAS DEUX. Deux armures du catalogue ne se
			-- distinguent QUE par une reduction specialisee : le plastron de
			-- cuir tient contre les poisons, le gilet pare-eclats contre les
			-- explosions, et les deux ont la meme reduction ordinaire. En ne
			-- regardant que la reduction et la vitesse, ce test declarait l'une
			-- ecrasee par l'autre alors qu'elles repondent a deux menaces
			-- differentes.
			local function axes(item: any): { number }
				local offset = item.offset or {}
				return {
					-(offset.damageTakenRatio or 0),
					-(offset.dotTakenRatio or 0),
					-(offset.blastTakenRatio or 0),
					(item.scale or {}).walkSpeed or 1,
				}
			end

			local left, right = axes(a), axes(b)
			local everywhere = true
			for index, value in left do
				if value < right[index] then
					everywhere = false
				end
			end
			-- Un atout que les chiffres ne portent pas : l'exosquelette ne se
			-- fait plus repousser, ce qui ne se lit dans aucune statistique.
			if a.resistsKnockback == nil and b.resistsKnockback ~= nil then
				everywhere = false
			end
			if everywhere then
				armorDominated = string.format("%s ecrase %s", a.id, b.id)
			end
		end
	end
	t.equal("aucune armure n'ecrase une armure aussi chere", armorDominated, nil)

	t.section("Ce que les objets changent vraiment")

	local base = Config.classStats.vampire

	local withHammer =
		Modifiers.applyDeltas(base, Loadout.weaponDeltas(Config, { "warhammer" }, "primary"))
	t.equal("le marteau multiplie les degats du Vampire par 2,4", withHammer.attackDamage, 12 * 2.4)
	t.equal(
		"il ajoute trente-cinq studs de poussee",
		withHammer.knockbackStuds,
		base.knockbackStuds + 35
	)
	t.check("et le Vampire garde son vol de vie", withHammer.lifestealRatio == base.lifestealRatio)
	t.check("et ses cent PV", withHammer.maxHealth == base.maxHealth)

	local armored = Modifiers.applyDeltas(base, Loadout.passiveDeltas(Config, { "heavyArmor" }))
	t.equal("l'armure lourde retire 28 % des degats recus", armored.damageTakenRatio, -0.28)
	t.check("et 22 % de la vitesse", math.abs(armored.walkSpeed - 20 * 0.78) < 1e-9)

	-- L'ordre compte : les facteurs d'abord, les decalages ensuite. L'armure
	-- retire un pourcentage de la vitesse QUE LE JOUEUR A VRAIMENT.
	local boosted = table.clone(base)
	boosted.walkSpeed = 30
	local boostedArmored =
		Modifiers.applyDeltas(boosted, Loadout.passiveDeltas(Config, { "heavyArmor" }))
	t.check(
		"et elle la retire de la vitesse deja modifiee par l'arbre",
		math.abs(boostedArmored.walkSpeed - 30 * 0.78) < 1e-9
	)

	-- Les planchers sont les memes que pour l'arbre, et ils tiennent.
	local brutal = Modifiers.applyDeltas(base, { scale = { walkSpeed = 0 }, offset = {} })
	t.equal("un facteur a zero s'arrete au plancher de vitesse", brutal.walkSpeed, 4)

	t.section("Les armes se combinent, les permanents s'empilent")

	-- Deux armures sont interdites par la validation, mais l'addition doit
	-- quand meme etre juste : trois utilitaires qui touchent la meme
	-- statistique passeront par ce chemin.
	local stacked = Loadout.passiveDeltas(Config, { "heavyArmor", "lightArmor" })
	t.check(
		"deux reductions s'additionnent",
		math.abs(stacked.offset.damageTakenRatio - -0.36) < 1e-9
	)

	local merged = Loadout.combine(
		{ scale = { attackDamage = 2 }, offset = { knockbackStuds = 5 } },
		{ scale = { attackDamage = 3 }, offset = { knockbackStuds = 7 } }
	)
	t.equal("les facteurs se multiplient", merged.scale.attackDamage, 6)
	t.equal("les decalages s'additionnent", merged.offset.knockbackStuds, 12)

	t.equal(
		"seul l'arc composite ignore une part des armures",
		Loadout.armorPierceOf(Config, { "compositeBow" }, "primary"),
		0.5
	)
	t.equal(
		"le marteau n'ignore rien",
		Loadout.armorPierceOf(Config, { "warhammer" }, "primary"),
		0
	)

	t.section("Les emplacements d'objets")

	local full = { "machete", "stimulant", "lightMine", "grenade", "deployableShield" }
	local usables = Loadout.usables(Config, full)
	t.equal("quatre consommables au maximum", #usables, 4)
	t.equal("le premier emplacement est le soin", usables[1].itemId, "stimulant")
	t.equal("la machette n'occupe aucun emplacement", Loadout.usableAt(Config, full, 5), nil)

	-- L'ordre vient du catalogue, jamais de l'ordre des clics : l'emplacement 1
	-- doit etre le meme objet d'une manche a l'autre.
	local shuffled = { "grenade", "machete", "stimulant" }
	local shuffledUsables = Loadout.usables(Config, shuffled)
	t.equal(
		"l'ordre des clics ne change pas la numerotation",
		shuffledUsables[1].itemId,
		"stimulant"
	)
	t.equal("et la grenade reste en deuxieme", shuffledUsables[2].itemId, "grenade")

	t.section("Chaque consommable est utilisable")

	-- Une charge a zero, ou un soin a zero PV, est un objet qui coute des points
	-- et ne fait rien. Meme garde-fou que les branches creuses.
	local broken: string? = nil
	for _, item in Config.items do
		local use = item.use
		if use == nil then
			continue
		end
		if (use.charges or 0) < 1 then
			broken = item.id .. " : aucune charge"
		end
		if use.kind == "heal" and (use.amount or 0) <= 0 then
			broken = item.id .. " : soigne zero"
		end
		-- UNE GRENADE PEUT NE FAIRE AUCUN DEGAT, a condition de faire autre
		-- chose. La grenade aveuglante ne retire pas un PV : ce qu'elle achete
		-- est une seconde et demie sans commandes. Sans ce cas, ce test refuse
		-- le seul objet du catalogue qui prive quelqu'un de ses touches.
		if (use.kind == "mine" or use.kind == "grenade") and (use.damage or 0) <= 0 then
			if use.status == nil then
				broken = item.id .. " : aucun degat et aucun effet"
			end
		end
		if use.kind == "shield" and (use.seconds or 0) <= 0 then
			broken = item.id .. " : aucune duree"
		end
		if use.kind == "zone" then
			if (use.seconds or 0) <= 0 or (use.radiusStuds or 0) <= 0 then
				broken = item.id .. " : une zone sans duree ni rayon"
			end
			-- Trois des six sortes de zone ont besoin d'une force : ralentir de
			-- rien, bruler de rien ou soigner de rien ne se voit pas en jouant,
			-- et ne leve aucune erreur. La fumee, la revelation et le brouillage
			-- n'ont pas de force : ils sont ou ils ne sont pas.
			local needsMagnitude = use.effect == "slow"
				or use.effect == "burn"
				or use.effect == "heal"
			if needsMagnitude and (use.magnitude or 0) <= 0 then
				broken = item.id .. " : une zone sans force"
			end
		end
		if use.kind == "leap" and (use.upStuds or 0) + (use.forwardStuds or 0) <= 0 then
			broken = item.id .. " : un bond qui ne va nulle part"
		end
		if use.kind == "throw" and (use.damage or 0) <= 0 then
			broken = item.id .. " : un lancer sans degat"
		end
	end
	t.equal("aucun consommable sans effet", broken, nil)

	-- Le catalogue decrit aussi ce qu'on TIENT, pas seulement ce que ca change.
	-- Une arme sans allure est invisible dans la main, et un mouvement mal nomme
	-- ne fait rien : les deux passent les autres tests sans rien signaler.
	t.section("Toute arme a une allure")

	local motion = Config.loadout.weaponMotion

	local missing: string? = nil
	local unknownSwing: string? = nil
	local badPiece: string? = nil
	local badSlot: string? = nil
	local twiceNamed: string? = nil
	local pointless: string? = nil
	local unseated: string? = nil
	local flattened: string? = nil

	-- UNE ARMURE NE SE REGARDE QUE SUR UN CORPS, donc tout membre qu'une piece
	-- nomme doit avoir sa place dans le squelette d'examen. Sans ca `preview`
	-- saute le groupe en silence et on conclut que la piece n'existe pas,
	-- alors qu'elle s'afficherait tres bien en jeu. C'est la meme panne que
	-- deux listes de garde-fous qui divergent : deux listes qui doivent
	-- s'accorder finissent toujours par ne plus s'accorder.
	local seated: { [string]: boolean } = {}
	local bones: { [string]: { number } } = {}
	for _, bone in Config.loadout.previewRig do
		seated[bone.limb] = true
		bones[bone.limb] = bone.size
	end

	for _, item in Config.items do
		local look = item.look

		-- Toute ARME doit avoir une allure. Les autres objets n'y sont pas
		-- obliges — une armure ou une trousse sans allure est simplement
		-- invisible, et c'est un manque, pas une panne.
		local isWeapon = item.category == "primary" or item.category == "secondary"
		if isWeapon and look == nil then
			missing = item.id
			continue
		end
		if look == nil then
			continue
		end
		if isWeapon and motion[look.swing] == nil then
			unknownSwing = item.id .. " : " .. tostring(look.swing)
		end

		-- UN SEUL EMPLACEMENT, ET UN AU MOINS. Deux emplacements declares et
		-- c'est le service qui tranche en silence ; aucun, et l'objet est
		-- decrit en detail pour n'apparaitre nulle part.
		local slots = 0
		if look.grip ~= nil then
			slots += 1
			if #look.grip ~= 3 then
				badSlot = item.id .. " : prise incomplete"
			end
		end
		if look.offhand ~= nil then
			slots += 1
			if #look.offhand ~= 3 then
				badSlot = item.id .. " : main gauche incomplete"
			end
		end
		if look.worn ~= nil then
			slots += 1
			if look.worn.limb == nil or #look.worn.at ~= 3 then
				badSlot = item.id .. " : armure sans membre ou sans position"
			elseif not seated[look.worn.limb] then
				unseated = item.id .. " : " .. look.worn.limb
			end
		end
		if slots ~= 1 then
			badSlot = item.id .. " : " .. tostring(slots) .. " emplacements"
		end

		local pieces = look.pieces
		if pieces == nil or #pieces == 0 then
			badPiece = item.id .. " : aucune piece"
			continue
		end
		-- Le membre de reference de ce qui se porte, ou `nil` pour ce qui se
		-- tient : c'est lui qui donne l'echelle des fractions.
		local worn = look.worn
		local fitLimb: string? = if worn ~= nil and worn.fit == true then worn.limb else nil

		local seen: { [string]: boolean } = {}
		local reach = 0
		for _, piece in pieces do
			if piece.name == nil or #piece.size ~= 3 or #piece.at ~= 3 or #piece.color ~= 3 then
				badPiece = item.id .. " : piece incomplete"
				continue
			end
			-- DEUX PIECES DU MEME NOM DONNENT DEUX `Motor6D` DU MEME NOM sur la
			-- meme part, et `FindFirstChild` en designe un au hasard. C'est le
			-- piege des doublons de Rojo, repris sur un modele d'arme — et il
			-- a deja coute quatre `ArenaGrip` empiles dans la meme main.
			if seen[piece.name] then
				twiceNamed = item.id .. " : " .. piece.name
			end
			seen[piece.name] = true
			if piece.limb ~= nil and not seated[piece.limb] then
				unseated = item.id .. " : " .. piece.limb
			end
			-- UN `Cylinder` NE DESSINE PAS D'ELLIPSE. Comme un `Ball`, il prend
			-- le PLUS PETIT de ses deux cotes de section comme diametre :
			-- verifie par temoin le 29 octobre 2026, trois cylindres de
			-- sections 1x3, 3x3 et 3x1 donnent des rondes de 1, 3 et 1. Ecrire
			-- deux cotes differents, c'est donc en ecrire un que Roblox jette,
			-- et la piece sort beaucoup plus mince que voulu — assez pour
			-- disparaitre dans le membre qu'elle habille. Les cinq boudins du
			-- gambison y sont passes : l'armure lisait comme un corps nu.
			--
			-- Le rapport se mesure APRES la mise a l'echelle du membre, parce
			-- que c'est la taille finale qui est dessinee : un bras fait 1,00
			-- de large pour 1,24 de haut, donc deux fractions egales n'y
			-- donnent pas deux cotes egaux.
			if piece.shape == "Cylinder" then
				local y, z = piece.size[2], piece.size[3]
				if fitLimb ~= nil then
					local bone = bones[piece.limb or fitLimb]
					if bone ~= nil then
						y, z = y * bone[2], z * bone[3]
					end
				end
				if math.max(y, z) > math.min(y, z) * 1.2 then
					flattened = item.id .. " : " .. piece.name
				end
			end
			reach = math.max(reach, -(piece.at[3] - piece.size[3] / 2))
			reach = math.max(reach, piece.at[2] + piece.size[2] / 2)
		end

		-- UNE ARME DESSINEE A L'ENVERS NE LEVE RIEN. Dans ce jeu le bout utile
		-- est du cote -Z : une arme dont aucune piece ne depasse vers l'avant
		-- ni vers le haut est une arme tenue par le mauvais bout, et ca ne se
		-- verrait qu'a l'ecran.
		if isWeapon and reach <= 0 then
			pointless = item.id
		end
	end

	t.equal("aucune arme sans allure", missing, nil)
	t.equal("aucun mouvement inconnu", unknownSwing, nil)
	t.equal("un seul emplacement par objet", badSlot, nil)
	t.equal("aucun membre sans place dans le squelette d'examen", unseated, nil)
	t.equal("aucune piece incomplete", badPiece, nil)
	t.equal("aucun nom de piece en double", twiceNamed, nil)
	t.equal("aucun cylindre dont le diametre serait ignore", flattened, nil)
	t.equal("aucune arme tenue par le mauvais bout", pointless, nil)

	t.section("Chaque mouvement est complet")

	-- Les quatre angles doivent exister sur chacun : un `nil` dans un
	-- CFrame.Angles leve une erreur au premier coup porte, en pleine manche.
	local incomplete: string? = nil
	for _, name in { "slash", "overhead", "recoil", "draw" } do
		local kind = motion[name]
		if kind == nil then
			incomplete = name .. " : absent"
			continue
		end
		if kind.pitch == nil or kind.yaw == nil or kind.roll == nil or kind.pullStuds == nil then
			incomplete = name .. " : angle manquant"
		end
	end
	t.equal("les quatre mouvements sont complets", incomplete, nil)

	t.equal("le coup part plus vite qu'il ne revient", motion.outSeconds < motion.backSeconds, true)

	t.section("Le geste tient dans la recharge")

	-- Un geste plus long que la recharge de l'arme ne se repose jamais : le
	-- coup suivant repart d'une position intermediaire et l'arme derive. Le
	-- couteau est le cas serre, avec une demi-seconde de recharge.
	local gesture = motion.outSeconds + motion.backSeconds
	local tooSlow: string? = nil
	local tightest = math.huge
	for _, item in Config.items do
		if item.category ~= "primary" and item.category ~= "secondary" then
			continue
		end
		local factor = 1
		if item.scale ~= nil and item.scale.attackCooldownSeconds ~= nil then
			factor = item.scale.attackCooldownSeconds
		end
		for classId, stats in Config.classStats do
			local cooldown = stats.attackCooldownSeconds * factor
			if cooldown < tightest then
				tightest = cooldown
			end
			if gesture > cooldown then
				tooSlow = item.id .. " sur " .. classId
			end
		end
	end
	t.equal("aucune arme ne frappe plus vite que son geste", tooSlow, nil)

	-- Le cas le plus serre du jeu, note ici pour qu'une baisse de recharge
	-- dans Config se fasse les yeux ouverts : passer sous la duree du geste
	-- ne leve aucune erreur, l'arme derive simplement de sa position de repos.
	t.equal("et il reste de la marge sur le cas le plus serre", tightest > gesture, true)

	-- OU VA LA POINTE DE L'ARME. C'est le seul test du depot qui refait un
	-- calcul de Roblox a la main, et c'est delibere : la capture d'ecran de
	-- Studio ne montre pas la 3D, donc personne ne peut REGARDER un geste.
	-- Deux des quatre signes etaient inverses au premier jet, et aucun test
	-- ne le voyait.
	--
	-- Les chiffres attendus ci-dessous ont ete mesures dans Studio avec de
	-- vrais CFrame, le 26 octobre 2026. Si ce calcul-ci s'en ecarte, c'est
	-- que la reimplementation est fausse, et le test le dit avant de parler
	-- des signes.
	t.section("Le geste part dans le bon sens")

	-- CFrame.Angles(x, y, z) applique Rx * Ry * Rz, dans cet ordre.
	local function rotate(v: { number }, pitch: number, yaw: number, roll: number): { number }
		local a, b, c = math.rad(pitch), math.rad(yaw), math.rad(roll)
		local x, y, z = v[1], v[2], v[3]

		-- Rz
		local x1 = x * math.cos(c) - y * math.sin(c)
		local y1 = x * math.sin(c) + y * math.cos(c)
		local z1 = z
		-- Ry
		local x2 = x1 * math.cos(b) + z1 * math.sin(b)
		local y2 = y1
		local z2 = -x1 * math.sin(b) + z1 * math.cos(b)
		-- Rx
		local x3 = x2
		local y3 = y2 * math.cos(a) - z2 * math.sin(a)
		local z3 = y2 * math.sin(a) + z2 * math.cos(a)

		return { x3, y3, z3 }
	end

	-- Le deplacement de la pointe entre le repos et le bout du geste.
	local function tipTravel(itemId: string): { number }
		local item = Loadout.find(Config, itemId)
		local look = item.look
		local kind = Config.loadout.weaponMotion[look.swing]

		-- La pointe : le point le plus eloigne de la main vers l'avant, ou le
		-- plus haut quand l'arme monte plus qu'elle n'avance — c'est le cas de
		-- l'arc, qu'on tient par le milieu.
		--
		-- Elle se DEDUIT des pieces et ne se recopie pas : une allure a vingt
		-- pieces n'a plus de « taille », et un chiffre de pointe ecrit a cote
		-- aurait cesse d'etre vrai au premier reglage.
		local far, high = 0, 0
		for _, piece in look.pieces do
			far = math.max(far, -(piece.at[3] - piece.size[3] / 2))
			high = math.max(high, piece.at[2] + piece.size[2] / 2)
		end
		local axis = { 0, 0, -far }
		if high > far then
			axis = { 0, high, 0 }
		end

		local turned = rotate(axis, kind.pitch, kind.yaw, kind.roll)
		return {
			turned[1] - axis[1],
			turned[2] - axis[2],
			turned[3] + kind.pullStuds - axis[3],
		}
	end

	local function near(actual: number, expected: number): boolean
		return math.abs(actual - expected) < 0.02
	end

	-- D'abord : ce calcul donne-t-il la meme chose que Roblox ?
	local hammer = tipTravel("warhammer")
	-- Le marteau a ete redessine le 28 octobre 2026 et sa pointe a bouge deux
	-- fois : 1,70 stud, puis 2,81, puis 2,77 quand les rivets sont passes du
	-- devant de la tete sur ses joues. Le temoin a ete REMESURE dans Studio a
	-- chaque fois, jamais recalcule ici — c'est tout l'interet de cette
	-- premiere moitie : elle verifie que le calcul du test retrouve celui de
	-- Roblox, et c'est elle qui rend credible la seconde, qui juge les signes.
	-- Le deplacement par stud n'a pas bouge (-0,966 les trois fois), ce qui
	-- est la preuve que seul l'axe a change et pas le geste.
	t.equal("le calcul reproduit celui de Studio (marteau, y)", near(hammer[2], -2.676), true)
	t.equal("le calcul reproduit celui de Studio (marteau, z)", near(hammer[3], 2.053), true)
	local bow = tipTravel("compositeBow")
	t.equal("le calcul reproduit celui de Studio (arc, z)", near(bow[3], 1.4), true)
	local blade = tipTravel("machete")
	-- La machette a ete redessinee le 28 octobre 2026 : son bout est passe de
	-- 1,50 a 2,56 puis a 2,60 stud quand la garde s'est etalee, et son temoin
	-- a ete REMESURE dans Studio a chaque fois, comme celui du marteau. Le
	-- deplacement par stud n'a pas bouge (-0,985 les trois fois), ce qui
	-- prouve que seul l'axe a change et pas le geste.
	t.equal("le calcul reproduit celui de Studio (machette, x)", near(blade[1], -2.56), true)

	-- Ensuite seulement : les gestes vont-ils ou on veut ?
	t.equal("le marteau s'abat vers le bas", hammer[2] < -1, true)
	t.equal("l'arc recule dans la main", bow[3] > 1, true)
	t.equal(
		"et il ne part ni en haut ni de cote",
		math.abs(bow[1]) < 0.01 and math.abs(bow[2]) < 0.01,
		true
	)

	-- La main est la droite : la frappe traverse le corps vers la gauche.
	t.equal("la machette fauche vers la gauche", blade[1] < -0.5, true)
	t.equal("le couteau aussi", tipTravel("knife")[1] < -0.3, true)

	-- Une arme a feu leve le canon, elle ne le plonge pas.
	t.equal("le fusil leve son canon", tipTravel("shotgun")[2] > 0.2, true)
	t.equal("le pistolet-mitrailleur aussi", tipTravel("smg")[2] > 0.2, true)

	-- LE BRAS, MAINTENANT. Meme panne possible que pour l'arme, et pire : une
	-- pose absente ne leve rien, le bras reste simplement immobile pendant que
	-- l'arme part, et personne ne sait que le geste est a moitie la.
	t.section("Le bras a une pose pour chaque geste")

	local body = Config.loadout.bodyMotion

	-- CHAQUE GESTE D'ARME A SA POSE DE BRAS, et c'est la premiere chose a
	-- verifier : ajouter un geste dans `weaponMotion` sans sa pose ici est
	-- l'erreur naturelle, puisque les deux tables sont voisines mais separees.
	for kindName, kind in motion do
		if typeof(kind) ~= "table" then
			continue
		end
		t.equal("le geste « " .. kindName .. " » a une pose de bras", body[kindName] ~= nil, true)
	end

	-- Le poing est le seul geste sans arme, donc le seul que `weaponMotion` ne
	-- nomme pas. C'est aussi celui qui compte le plus : sans arme, le bras est
	-- la SEULE chose qui bouge.
	t.equal("et le poing a la sienne", body.fist ~= nil, true)

	-- L'INVERSE AUSSI. Une pose que plus aucun geste ne nomme ne fait rien et
	-- ne se voit pas : c'est la meme panne que les branches creuses de l'arbre.
	local orphan: string? = nil
	for poseName, pose in body do
		if typeof(pose) ~= "table" then
			continue
		end
		if poseName ~= "fist" and motion[poseName] == nil then
			orphan = poseName
		end
	end
	t.equal("aucune pose ne traine sans geste", orphan, nil)

	-- La duree n'est ecrite qu'a un seul endroit. Si elle existait ici aussi,
	-- le bras et l'arme pourraient partir ensemble et revenir separement, et
	-- rien ne le dirait.
	t.equal("la duree reste celle de l'arme", body.outSeconds, nil)
	t.equal("le retour aussi", body.backSeconds, nil)

	t.section("Chaque pose deplace vraiment la main")

	-- Une pose a trois zeros se declare, se verifie, et ne fait rien du tout.
	for poseName, pose in body do
		if typeof(pose) ~= "table" then
			continue
		end
		for _, axis in { "right", "up", "forward" } do
			t.equal(
				"« " .. poseName .. " » nomme son axe « " .. axis .. " »",
				typeof(pose[axis]),
				"number"
			)
		end
		local reach = math.abs(pose.right) + math.abs(pose.up) + math.abs(pose.forward)
		t.equal("« " .. poseName .. " » bouge la main", reach > 0.1, true)

		-- L'inclinaison du buste est un ANGLE, pas une distance : elle a sa
		-- propre unite et sa propre butee, donc son propre test.
		t.equal("« " .. poseName .. " » a une inclinaison", typeof(pose.lean), "number")
		t.equal("et elle n'est pas nulle", math.abs(pose.lean) > 0.5, true)

		-- LA BUTEE DU BASSIN EST A 22 DEGRES, mesuree en jeu le 27 octobre 2026 :
		-- demander 45 donne 21,4, demander 90 donne 22,4. Au-dela, le chiffre
		-- ecrit dans Config ne decrit plus ce qui se passe a l'ecran, et on
		-- reglerait un geste a l'aveugle — meme regle que les 2 studs de l'epaule.
		t.equal("et elle reste sous la butee du bassin", math.abs(pose.lean) <= 22, true)

		-- L'EPAULE A UNE BUTEE, mesuree en jeu le 27 octobre 2026 : une demande
		-- de 2 studs deplace la main de 1,85 vers le haut mais de 0,36
		-- seulement vers l'interieur du corps. Au-dela de 2, le chiffre ecrit
		-- dans Config cesse de decrire ce qui se passe a l'ecran, et on reglerait
		-- un geste a l'aveugle.
		t.equal(
			"et elle reste dans ce que l'epaule peut donner",
			math.max(math.abs(pose.right), math.abs(pose.up), math.abs(pose.forward)) <= 2,
			true
		)
	end

	t.section("La main part dans le bon sens")

	-- LA SEULE CONVERSION DU SERVICE, REFAITE ICI. `WeaponService` pose la
	-- cible a `rest + Vector3.new(right, up, -forward)`, parce que l'avant de
	-- Roblox est -Z. Un signe oublie la et « recoil » pousserait la main en
	-- avant au lieu de la faire reculer : le fusil avancerait en tirant.
	local function handTravel(poseName: string): { number }
		local pose = body[poseName]
		return { pose.right, pose.up, -pose.forward }
	end

	-- Une arme a feu repousse, un arc se bande : dans les deux cas la main
	-- recule, donc elle part vers le +Z du torse.
	t.equal("le fusil recule la main", handTravel("recoil")[3] > 0, true)
	t.equal("l'arc la tire vers soi", handTravel("draw")[3] > 0, true)

	-- Les trois autres frappent devant, donc vers le -Z.
	t.equal("la machette avance", handTravel("slash")[3] < 0, true)
	t.equal("le marteau aussi", handTravel("overhead")[3] < 0, true)
	t.equal("et le poing autant que les armes", handTravel("fist")[3] < 0, true)

	-- La main est la droite : une frappe qui traverse le corps va vers la
	-- gauche, c'est-a-dire vers le -X. C'est la meme logique que pour la pointe
	-- de la machette ci-dessus, un etage plus haut dans le bras.
	t.equal("la machette ramene la main vers le corps", handTravel("slash")[1] < 0, true)

	t.section("Ou pointe vraiment la poitrine, et ou pointe la tete")

	-- CE TEST A DEJA MANQUE UN BUG, ET VOICI POURQUOI IL EST REECRIT.
	--
	-- Sa premiere version comparait `pose.forward > 0` a `pose.lean > 0` : deux de
	-- MES conventions, mises face a face. Elles etaient d'accord entre elles et
	-- toutes les deux fausses — dans Roblox un tangage positif LEVE l'avant d'une
	-- part, donc le buste partait en arriere pendant que la main allait devant,
	-- sur les cinq gestes, et le test passait. Verifie par un temoin en jeu le
	-- 27 octobre 2026 : `CFrame.Angles(+18, 0, 0)` donne a l'avant du buste un Y
	-- de +0,30 et a son sommet un Z de +0,29.
	--
	-- La lecon, et elle vaut pour tout ce fichier : **un test de direction ne
	-- compare pas deux noms, il refait le calcul de Roblox et regarde ou pointe
	-- la part.** Et il verifie d'abord qu'il reproduit Roblox, avant de juger.
	--
	-- `WeaponService` applique `CFrame.Angles(math.rad(-lean), 0, 0)`, donc le
	-- moins est ici aussi : on teste ce que le code fait, pas ce qu'on voudrait.
	local function chestForward(leanDegrees: number): { number }
		return rotate({ 0, 0, -1 }, -leanDegrees, 0, 0)
	end

	-- D'abord : ce calcul donne-t-il la meme chose que Studio ? Les deux chiffres
	-- attendus sont ceux du temoin, pour un `lean` de 18 et son oppose.
	t.equal(
		"le calcul reproduit celui de Studio (buste a +18)",
		near(chestForward(-18)[2], 0.309),
		true
	)
	t.equal("et a -18", near(chestForward(18)[2], -0.309), true)

	-- Ensuite seulement : chaque geste penche-t-il du bon cote ?
	--
	-- L'avant d'une part est -Z et son haut est +Y. Une poitrine qui tombe vers
	-- l'avant a donc son avant qui PIQUE VERS LE SOL, c'est-a-dire un Y negatif.
	local disagreeing: string? = nil
	for poseName, pose in body do
		if typeof(pose) ~= "table" then
			continue
		end
		local handGoesForward = pose.forward > 0
		local chestGoesForward = chestForward(pose.lean)[2] < 0
		if handGoesForward ~= chestGoesForward then
			disagreeing = poseName
		end
	end
	t.equal("aucun geste ne penche a l'envers de sa main", disagreeing, nil)

	-- Et nommement, pour que l'intention soit lisible sans relire Config.
	t.equal(
		"le marteau pique du buste vers le sol",
		chestForward(body.overhead.lean)[2] < -0.2,
		true
	)
	t.equal("le fusil renverse le buste en arriere", chestForward(body.recoil.lean)[2] > 0.05, true)

	-- Et le marteau est le plus penche de tous, parce que c'est le seul geste du
	-- jeu qui vient du corps entier. Si un autre le depasse un jour, c'est une
	-- decision, pas un accident : ce test la rend visible.
	local steepest = ""
	local steepestLean = -math.huge
	for poseName, pose in body do
		if typeof(pose) == "table" and pose.lean > steepestLean then
			steepestLean = pose.lean
			steepest = poseName
		end
	end
	t.equal("le marteau est le geste le plus penche", steepest, "overhead")

	t.section("La tete regarde ou le coup part")

	-- Meme methode, meme signe moins : `WeaponService` applique
	-- `CFrame.Angles(math.rad(-headDip), math.rad(headTurn), 0)`.
	local function headForward(dip: number, turn: number): { number }
		return rotate({ 0, 0, -1 }, -dip, turn, 0)
	end

	-- La reproduction d'abord, contre les chiffres du temoin : une demande de
	-- +20 degres de tangage a donne un avant de tete a +0,47 en Y, et +30 de
	-- lacet un avant a -0,45 en X.
	t.equal("le calcul reproduit Studio (tete, tangage)", near(headForward(-20, 0)[2], 0.342), true)
	t.equal("et en lacet", near(headForward(0, 30)[1], -0.5), true)

	for poseName, pose in body do
		if typeof(pose) ~= "table" then
			continue
		end
		t.equal("« " .. poseName .. " » a un abaissement de tete", typeof(pose.headDip), "number")
		t.equal("et une rotation de tete", typeof(pose.headTurn), "number")

		-- LES BUTEES DU COU, mesurees en jeu : 37 degres de tangage et 48 de
		-- lacet. On s'arrete bien en dessous, pour la meme raison que le marteau
		-- s'arrete a 18 sur 22 — un geste cale contre sa butee ne se distingue
		-- plus d'un geste trop grand.
		t.equal("la tete reste sous sa butee de tangage", math.abs(pose.headDip) <= 30, true)
		t.equal("et sous celle de lacet", math.abs(pose.headTurn) <= 40, true)

		-- LA TETE REGARDE DU MEME COTE QUE LE BUSTE. Une tete qui se leve pendant
		-- que la poitrine tombe est la meme convulsion qu'avant, un etage plus
		-- haut, et elle serait tout aussi invisible dans les tests.
		local chestDown = chestForward(pose.lean)[2] < 0
		local headDown = headForward(pose.headDip, pose.headTurn)[2] < 0
		t.equal(
			"« " .. poseName .. " » : la tete et la poitrine regardent du meme cote",
			headDown,
			chestDown
		)
	end

	-- La machette est le seul geste lateral, donc le seul qui tourne la tete. Le
	-- X d'une part est sa droite, donc un avant de tete negatif en X est une tete
	-- tournee vers la GAUCHE, du cote ou la lame s'en va.
	t.equal(
		"la tete suit la machette vers la gauche",
		headForward(body.slash.headDip, body.slash.headTurn)[1] < -0.1,
		true
	)
	local turning = 0
	for _, pose in body do
		if typeof(pose) == "table" and math.abs(pose.headTurn) > 0.5 then
			turning += 1
		end
	end
	t.equal("et c'est le seul geste qui la tourne", turning, 1)

	t.section("Les bonds montent vraiment de ce qu'ils annoncent")

	--[[
		CE TEST A LA STRUCTURE DE CELUI DE LA POINTE DE L'ARME, et pour la meme
		raison : il REFAIT le calcul de Roblox avant de juger quoi que ce soit.

		Ce qu'il attrape est arrive. `upStuds = 40` donnait quatre studs de
		hauteur, parce que le chiffre partait tel quel dans la vitesse du
		personnage. Les bottes a ressort sautaient donc moins haut que la barre
		d'espace, et les mille verifications passaient : aucune ne savait ce que
		« stud » voulait dire.

		La premiere moitie verifie que la simulation retrouve la physique de
		Roblox sur un cas connu. La seconde juge les chiffres de Config. Retirer
		la premiere rendrait la seconde sans valeur.
	]]

	local gravity = Config.loadout.referenceGravity

	local function near(label: string, actual: number, expected: number, tolerance: number)
		t.check(
			string.format("%s (%.2f pour %.2f)", label, actual, expected),
			math.abs(actual - expected) <= tolerance
		)
	end

	-- La conversion du serveur, refaite ici : hauteur voulue -> vitesse.
	local function launchSpeed(height: number): number
		return math.sqrt(2 * gravity * height)
	end

	-- Et la physique, pas a pas, sans formule : on lache le personnage avec
	-- cette vitesse et on regarde ou il monte. Mille pas par seconde.
	local function simulateApex(speed: number): number
		local step = 0.001
		local y = 0
		local velocity = speed
		local apex = 0
		for _ = 1, 5000 do
			-- La moyenne des deux vitesses du pas, et pas celle d'arrivee : sous
			-- une acceleration constante c'est exact, alors que prendre l'une des
			-- deux accumule une erreur qui grandit avec la duree du vol. Vu ici :
			-- 35 studs demandes rendaient 34,94.
			local next = velocity - gravity * step
			y += 0.5 * (velocity + next) * step
			velocity = next
			apex = math.max(apex, y)
			if velocity < 0 and y <= 0 then
				break
			end
		end
		return apex
	end

	-- TEMOIN. Une vitesse de 40 studs par seconde monte a 4,08 studs : c'est le
	-- chiffre mesure en jeu le 27 octobre 2026 (4,0 releve), et c'est ce qui
	-- prouve que la simulation ci-dessus est celle de Roblox et pas la mienne.
	near("40 studs par seconde montent a 4,08", simulateApex(40), 4.08, 0.05)
	near("85 en montent 18,4", simulateApex(85), 18.4, 0.1)

	-- Donc la conversion rend bien la hauteur demandee, et c'est ca qui compte.
	for _, height in { 7.2, 8, 20, 35 } do
		near(
			string.format("demander %g studs en donne %g", height, height),
			simulateApex(launchSpeed(height)),
			height,
			0.05
		)
	end

	-- UN BOND QUI MONTE MOINS QU'UN SAUT NE VAUT PAS UN POINT. C'est exactement
	-- l'etat dans lequel les bottes a ressort ont ete livrees, et c'est la
	-- seule ligne de ce test qui regarde Config.
	local leaps = 0
	for _, item in Config.items do
		local use = item.use
		if use == nil or use.kind ~= "leap" then
			continue
		end
		leaps += 1
		t.check(
			string.format(
				"%s monte plus haut que la barre d'espace (%g > %g)",
				item.id,
				use.upStuds,
				Config.loadout.ordinaryJumpStuds
			),
			use.upStuds > Config.loadout.ordinaryJumpStuds
		)
		-- Et le temps de vol reste un prix payable : au-dela de deux secondes en
		-- l'air on est une cible, pas un acrobate.
		local airtime = (2 * launchSpeed(use.upStuds)) / gravity
		t.check(
			string.format("%s retombe en moins de deux secondes (%.2f s)", item.id, airtime),
			airtime < 2
		)
	end
	t.check("il y a bien des bonds a verifier", leaps >= 2)

	--------------------------------------------------------------------------
	t.section("Aucune arme n'est morte")

	-- UN OBJET QU'ON NE PRENDRAIT JAMAIS EST UN OBJET MORT, et il coute aussi
	-- cher a dessiner, a equilibrer et a lire que les autres. Une arme est
	-- morte quand une autre de la MEME categorie coute autant ou moins, frappe
	-- aussi fort ou plus, porte aussi loin ou plus, apporte tout ce qu'elle
	-- apporte, et subit tout ce qu'elle subit. Personne ne la prendrait, et ca
	-- ne se voit jamais en jouant : on prend l'autre, voila tout.
	--
	-- Le catalogue en est exempt au 2 novembre 2026, et c'est justement
	-- pourquoi ce test vaut d'exister : il attrapera la soixante-troisieme
	-- arme, pas les soixante-deux d'aujourd'hui.
	local BONUS = {
		"armorPierceRatio",
		"onHit",
		"offset",
		"use",
		"weaponBlast",
		"resistsKnockback",
	}
	local MALUS = { "minRangeStuds", "selfSlowSeconds", "shotsPerRound" }

	type Arme = {
		id: string,
		category: string,
		cost: number,
		dps: number,
		range: number,
		bonus: { [string]: boolean },
		malus: { [string]: boolean },
	}

	local armes: { Arme } = {}
	for _, raw in Config.items do
		local item = raw :: any
		if item.category ~= "primary" and item.category ~= "secondary" then
			continue
		end
		local bonus: { [string]: boolean } = {}
		for _, key in BONUS do
			if item[key] ~= nil then
				bonus[key] = true
			end
		end
		local malus: { [string]: boolean } = {}
		for _, key in MALUS do
			if item[key] ~= nil then
				malus[key] = true
			end
		end
		table.insert(armes, {
			id = item.id,
			category = item.category,
			cost = item.cost,
			-- Les degats par seconde, qui sont la seule facon de comparer une
			-- arme lente et forte a une arme rapide et faible.
			dps = item.scale.attackDamage / item.scale.attackCooldownSeconds,
			range = item.scale.attackRangeStuds,
			bonus = bonus,
			malus = malus,
		})
	end
	t.check("il y a bien des armes a comparer", #armes >= 30)

	local function couvre(a: Arme, b: Arme): boolean
		for key in b.bonus do
			if not a.bonus[key] then
				return false
			end
		end
		for key in a.malus do
			if not b.malus[key] then
				return false
			end
		end
		return true
	end

	local mortes: { string } = {}
	for _, b in armes do
		for _, a in armes do
			if a.id == b.id or a.category ~= b.category then
				continue
			end
			if a.cost > b.cost or a.dps < b.dps or a.range < b.range then
				continue
			end
			if a.cost == b.cost and a.dps == b.dps and a.range == b.range then
				continue
			end
			if couvre(a, b) then
				table.insert(mortes, string.format("%s (par %s)", b.id, a.id))
			end
		end
	end
	t.equal(
		"aucune arme n'en domine une autre de sa categorie : " .. table.concat(mortes, ", "),
		#mortes,
		0
	)
end
