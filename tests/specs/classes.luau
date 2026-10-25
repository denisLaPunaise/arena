--!strict
--[[
	Tests de coherence du catalogue de classes.

	Le principe a ne jamais casser : chaque classe a une faiblesse qui compense
	son pouvoir. Un test ne peut pas juger si une faiblesse est suffisante, mais
	il peut garantir qu'aucune classe n'arrive sans la sienne.
]]

local Classes = require("../../src/shared/Classes")

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
end
