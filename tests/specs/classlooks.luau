--!strict
--[[
	Tests des couvre-chefs de classe.

	Aucun de ces tests ne dit si un couvre-chef est BEAU ni s'il se pose bien :
	ca ne se voit qu'a l'ecran, et c'est la que les quatorze ont ete regles.
	Ils attrapent ce qui casse en silence : une classe sans couvre-chef (elle ne
	se reconnait plus, sans erreur), un identifiant mal recopie (la tete reste
	nue), et deux classes qui partageraient le meme maillage (on les
	confondrait, ce qui est exactement ce que le couvre-chef doit empecher).
]]

local ClassLooks = require("../../src/shared/ClassLooks")
local Classes = require("../../src/shared/Classes")
local Config = require("../../src/shared/Config")

local harness = require("../harness")

return function(t: harness.Harness)
	t.section("Chaque classe a son couvre-chef, et un seul")

	local known: { [string]: boolean } = {}
	for _, class in Classes.all do
		known[class.id] = true
		t.equal(class.id .. " a un couvre-chef", (ClassLooks :: any)[class.id] ~= nil, true)
	end
	for id in ClassLooks :: any do
		t.equal("« " .. tostring(id) .. " » est bien une classe", known[id] == true, true)
	end

	t.section("Chaque maillage est complet et posable")

	local limbs: { [string]: boolean } = {}
	for _, bone in Config.loadout.previewRig do
		limbs[bone.limb] = true
	end

	local owner: { [string]: string } = {}
	for id, look in ClassLooks :: any do
		t.equal(
			id .. " se porte sur la tete par defaut",
			look.worn ~= nil and look.worn.limb,
			"Head"
		)
		t.equal(
			id .. " a au moins un maillage",
			type(look.meshes) == "table" and #look.meshes > 0,
			true
		)
		local names: { [string]: boolean } = {}
		for _, mesh in look.meshes or {} do
			local label = id .. "/" .. tostring(mesh.name)
			t.equal(
				label .. " a un nom unique",
				type(mesh.name) == "string" and not names[mesh.name],
				true
			)
			names[mesh.name] = true
			t.equal(
				label .. " a un maillage",
				string.match(mesh.meshId or "", "^rbxassetid://%d+$") ~= nil,
				true
			)
			t.equal(
				label .. " a une texture",
				string.match(mesh.textureId or "", "^rbxassetid://%d+$") ~= nil,
				true
			)
			-- Une largeur hors de cette fourchette est une faute de frappe : a
			-- 0,5 le couvre-chef disparait dans le crane, a 3 il fait une ombrelle.
			t.equal(
				label .. " a une largeur plausible",
				type(mesh.width) == "number" and mesh.width >= 0.5 and mesh.width <= 3,
				true
			)
			t.equal(
				label .. " a trois coordonnees",
				type(mesh.at) == "table" and #mesh.at == 3,
				true
			)
			local limb = mesh.limb or look.worn.limb
			t.equal(
				label .. " se pose sur un membre connu (" .. tostring(limb) .. ")",
				limbs[limb] == true,
				true
			)

			local already = owner[mesh.meshId]
			t.equal(
				label .. " n'est pas le maillage d'une autre classe",
				already == nil or already == id,
				true
			)
			owner[mesh.meshId] = id
		end
	end
end
