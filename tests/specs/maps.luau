--!strict
--[[
	Tests de la rotation des maps.

	La regle tenue ici : au hasard, jamais deux fois de suite la meme. Le reste
	de la rotation (ranger une map, poser son eclairage) touche Roblox et se
	verifie dans Studio — c'est fait, et c'est dans A-TESTER.
]]

local Config = require("../../src/shared/Config")
local MapRotation = require("../../src/shared/MapRotation")

local harness = require("../harness")

return function(t: harness.Harness)
	t.section("La rotation des maps")

	local names = { "SerreMap", "BazarMap", "BoisMap", "ColiseeMap" }

	t.equal(
		"rien a tirer, rien de tire",
		MapRotation.pick({}, nil, function(_)
			return 1
		end),
		nil
	)
	t.equal(
		"une seule map revient toujours, meme si c'etait la derniere",
		MapRotation.pick({ "BoisMap" }, "BoisMap", function(_)
			return 1
		end),
		"BoisMap"
	)

	-- Mille tirages avec un vrai generateur : jamais la derniere, et toutes
	-- les autres sortent.
	-- Lune n'a pas `Random` : un generateur congruentiel suffit, et il est
	-- deterministe, donc le test ne depend pas de la chance.
	local state = 42
	local random = {
		NextInteger = function(_, lo: number, hi: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return lo + (state % (hi - lo + 1))
		end,
	}
	local seen: { [string]: number } = {}
	local repeats = 0
	local last: string? = nil
	for _ = 1, 1000 do
		local pick = MapRotation.pick(names, last, function(n)
			return random:NextInteger(1, n)
		end)
		if pick == last then
			repeats += 1
		end
		if pick ~= nil then
			seen[pick] = (seen[pick] or 0) + 1
		end
		last = pick
	end
	t.equal("jamais deux fois de suite la meme map", repeats, 0)
	for _, name in names do
		t.equal(name .. " sort au moins une fois sur mille", (seen[name] or 0) > 0, true)
	end

	-- L'ordre dans lequel Roblox rend les enfants d'un dossier ne doit pas
	-- changer le tirage : avec le meme generateur, deux ordres, meme map.
	local a = MapRotation.pick({ "B", "A", "C" }, nil, function(_)
		return 2
	end)
	local b = MapRotation.pick({ "C", "B", "A" }, nil, function(_)
		return 2
	end)
	t.equal("le tirage ne depend pas de l'ordre des dossiers", a, b)

	t.section("Les reglages de la rotation sont complets")

	t.equal("le dossier de rangement est nomme", type(Config.maps.storageFolder) == "string", true)
	t.equal("le dossier d'eclairage est nomme", type(Config.maps.lightingFolder) == "string", true)
	-- Le brouillard court du Bois brumeux est un reglage de place : s'il
	-- n'etait pas dans la liste, il resterait pose sur la map suivante.
	local has: { [string]: boolean } = {}
	for _, name in Config.maps.lightingProperties do
		has[name] = true
	end
	for _, needed in
		{ "ClockTime", "GeographicLatitude", "FogEnd", "FogStart", "Ambient", "OutdoorAmbient" }
	do
		t.equal("l'eclairage range emporte " .. needed, has[needed] == true, true)
	end
	local effects: { [string]: boolean } = {}
	for _, class in Config.maps.lightingEffects do
		effects[class] = true
	end
	for _, needed in { "Atmosphere", "Clouds", "ColorCorrectionEffect", "BloomEffect" } do
		t.equal("les effets ranges comprennent " .. needed, effects[needed] == true, true)
	end
end
