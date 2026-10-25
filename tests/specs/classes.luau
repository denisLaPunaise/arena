--!strict
--[[
	Tests de coherence du catalogue de classes.

	Le principe a ne jamais casser : chaque classe a une faiblesse qui compense
	son pouvoir. Un test ne peut pas juger si une faiblesse est suffisante, mais
	il peut garantir qu'aucune classe n'arrive sans la sienne.
]]

local Classes = require("../../src/shared/Classes")
local Config = require("../../src/shared/Config")

local harness = require("../harness")

return function(t: harness.Harness)
	t.section("Le catalogue de classes")

	local seenIds = {}
	local seenNames = {}
	local prototypeCount = 0

	for _, class in Classes.all do
		t.check(
			string.format("%s a un identifiant unique", class.name),
			class.id ~= nil and seenIds[class.id] == nil
		)
		t.check(
			string.format("%s a un nom unique", class.name),
			class.name ~= nil and seenNames[class.name] == nil
		)
		t.check(string.format("%s a un pouvoir", class.name), (class.power or "") ~= "")
		t.check(string.format("%s a une faiblesse", class.name), (class.weakness or "") ~= "")
		t.check(string.format("%s a un role", class.name), (class.role or "") ~= "")

		seenIds[class.id] = true
		seenNames[class.name] = true

		if class.prototype then
			prototypeCount += 1
		end
	end

	t.equal("deux classes marquees pour le prototype", prototypeCount, 2)

	local vampire = Classes.byId.vampire
	local colossus = Classes.byId.colossus
	t.check("le Vampire est dans le prototype", vampire ~= nil and vampire.prototype == true)
	t.check("le Colosse est dans le prototype", colossus ~= nil and colossus.prototype == true)

	local indexComplete = true
	for _, class in Classes.all do
		if Classes.byId[class.id] ~= class then
			indexComplete = false
		end
	end
	t.check("l'index par identifiant est complet", indexComplete)

	t.section("Le tirage selon le format")

	local anyFormat = Classes.drawable(3)
	local duel = Classes.drawable(1)

	t.equal("a trois contre trois, les quatorze classes sortent", #anyFormat, #Classes.all)
	t.check("en 1v1 il y en a moins", #duel < #anyFormat)

	-- Sans coequipier, le Lien, le Leurre et l'Infirmier n'ont aucune cible
	-- pour leur pouvoir, et le miroir les eteindrait des deux cotes.
	local excluded = { link = true, decoy = true, medic = true }
	local foundExcluded = false
	for _, class in duel do
		if excluded[class.id] then
			foundExcluded = true
		end
	end
	t.check("les classes qui ciblent un allie en sont retirees", foundExcluded == false)
	t.equal("il en reste onze", #duel, #Classes.all - 3)

	-- Un drapeau mal pose casserait le 1v1 sans qu'on s'en apercoive.
	local flagged = 0
	for _, class in Classes.all do
		if class.needsAllies then
			flagged += 1
			t.check(string.format("%s cible bien un allie", class.name), excluded[class.id] == true)
		end
	end
	t.equal("trois classes exactement portent le drapeau", flagged, 3)

	t.section("Chaque classe est reellement jouable")

	-- CE QUI EST FIGE ICI. Une classe sans statistiques, ou dont le pouvoir
	-- n'existe que dans sa description, se tire au sort comme les autres et
	-- donne un joueur sans rien. C'est le meme piege que les branches creuses
	-- du 25 octobre 2026, a l'echelle d'une classe entiere.
	local registry = Config.abilities.registry

	for _, class in Classes.all do
		local stats = Config.classStats[class.id]
		t.check(string.format("%s a des statistiques", class.name), stats ~= nil)

		if stats == nil then
			continue
		end

		-- Les huit chiffres sans lesquels le combat ne sait pas quoi faire.
		for _, key in
			{
				"maxHealth",
				"walkSpeed",
				"attackDamage",
				"attackCooldownSeconds",
				"attackRangeStuds",
				"lifestealRatio",
				"knockbackStuds",
				"regenPerSecond",
			}
		do
			t.check(
				string.format("%s : %s est renseigne", class.name, key),
				typeof(stats[key]) == "number"
			)
		end

		t.check(
			string.format("%s declare un pouvoir", class.name),
			typeof(stats.ability) == "string"
		)

		local ability = registry[stats.ability]
		t.check(
			string.format("%s : le pouvoir %s est au registre", class.name, tostring(stats.ability)),
			ability ~= nil
		)

		if ability == nil then
			continue
		end

		t.check(
			string.format("%s : le pouvoir est decrit", class.name),
			(ability.name or "") ~= "" and (ability.summary or "") ~= ""
		)
		t.check(
			string.format("%s : le pouvoir dit comment il se declenche", class.name),
			ability.kind == "stats" or ability.kind == "passive" or ability.kind == "active"
		)

		-- Un pouvoir qui s'active a besoin d'une recharge, sinon il part a
		-- chaque image et la faiblesse de la classe ne pese plus rien.
		if ability.kind == "active" then
			t.check(
				string.format("%s : le pouvoir actif a une recharge", class.name),
				typeof(stats.abilityCooldownSeconds) == "number"
					and stats.abilityCooldownSeconds > 0
			)
		end
	end

	t.section("Le registre des pouvoirs ne contient rien d'orphelin")

	-- Un pouvoir au registre que plus aucune classe ne porte est du code mort
	-- qui donne l'illusion d'une fonctionnalite.
	local carried: { [string]: boolean } = {}
	for _, class in Classes.all do
		local stats = Config.classStats[class.id]
		if stats ~= nil and typeof(stats.ability) == "string" then
			carried[stats.ability] = true
		end
	end

	for abilityId in registry do
		t.check(
			string.format("le pouvoir %s est porte par une classe", abilityId),
			carried[abilityId] == true
		)
	end
end
