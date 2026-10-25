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
end
