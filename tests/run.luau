--!strict
--[[
	Lanceur de tests — `lune run tests/run`.

	Il n'ouvre pas Studio et ne touche a aucune API Roblox : il charge les
	modules de logique pure et verifie leurs resultats. C'est ce qui permet de
	controler un calcul d'equilibrage en deux secondes au lieu d'un
	aller-retour dans Studio.

	Pour ajouter une suite : un fichier dans tests/specs/ qui renvoie une
	fonction prenant le harnais, puis une ligne dans la liste ci-dessous.
]]

local process = require("@lune/process")

local harness = require("./harness")

local suites = {
	{ name = "Configuration", run = require("./specs/config") },
	{ name = "Classes", run = require("./specs/classes") },
}

local t = harness.create()

print("Arena — tests de logique pure")

for _, suite in suites do
	print("")
	print("== " .. suite.name .. " ==")
	suite.run(t)
end

print("")
print(string.rep("=", 48))

if t.failures() > 0 then
	print(string.format("%d echec(s) sur %d verifications", t.failures(), t.total()))
	process.exit(1)
end

print(string.format("%d verifications, tout est coherent", t.total()))
