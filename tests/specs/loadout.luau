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

	t.equal("treize objets", #Config.items, 13)

	local prototype = Config.itemCounts.prototype
	for category, expected in prototype do
		t.equal(
			string.format("%s : %d objets comme annonce", category, expected),
			countOf(category),
			expected
		)
	end

	local totalAnnounced = 0
	for _, expected in prototype do
		totalAnnounced += expected
	end
	t.equal("le total annonce fait bien treize", totalAnnounced, 13)

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

	local dominated: string? = nil
	for _, category in { "primary", "secondary" } do
		local weapons = Loadout.byCategory(Config, category)
		for _, a in weapons do
			for _, b in weapons do
				if a.id == b.id or a.cost > b.cost then
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
			local reductionA = -((a.offset or {}).damageTakenRatio or 0)
			local reductionB = -((b.offset or {}).damageTakenRatio or 0)
			local speedA = (a.scale or {}).walkSpeed or 1
			local speedB = (b.scale or {}).walkSpeed or 1
			if reductionA >= reductionB and speedA >= speedB then
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
		if (use.kind == "mine" or use.kind == "grenade") and (use.damage or 0) <= 0 then
			broken = item.id .. " : aucun degat"
		end
		if use.kind == "shield" and (use.seconds or 0) <= 0 then
			broken = item.id .. " : aucune duree"
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
	local badHead: string? = nil

	for _, item in Config.items do
		-- Seules les armes se tiennent. Une armure ou une trousse de soin n'a
		-- rien a montrer dans la main.
		if item.category ~= "primary" and item.category ~= "secondary" then
			continue
		end

		local look = item.look
		if look == nil then
			missing = item.id
			continue
		end

		if #look.size ~= 3 or #look.color ~= 3 or #look.grip ~= 3 then
			missing = item.id .. " : taille, couleur ou prise incomplete"
		end

		if motion[look.swing] == nil then
			unknownSwing = item.id .. " : " .. tostring(look.swing)
		end

		local head = look.head
		if head ~= nil and (#head.size ~= 3 or #head.color ~= 3 or head.atStuds == nil) then
			badHead = item.id
		end
	end

	t.equal("aucune arme sans allure", missing, nil)
	t.equal("aucun mouvement inconnu", unknownSwing, nil)
	t.equal("aucune piece rapportee incomplete", badHead, nil)

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

		-- La pointe : le bout de la lame, ou le haut de l'arc quand l'arme
		-- est plus longue en hauteur qu'en profondeur.
		local axis = { 0, 0, -look.size[3] / 2 }
		if look.size[2] > look.size[3] then
			axis = { 0, look.size[2] / 2, 0 }
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
	t.equal("le calcul reproduit celui de Studio (marteau, y)", near(hammer[2], -1.64), true)
	t.equal("le calcul reproduit celui de Studio (marteau, z)", near(hammer[3], 1.26), true)
	local bow = tipTravel("compositeBow")
	t.equal("le calcul reproduit celui de Studio (arc, z)", near(bow[3], 1.4), true)
	local blade = tipTravel("machete")
	t.equal("le calcul reproduit celui de Studio (machette, x)", near(blade[1], -1.48), true)

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
end
