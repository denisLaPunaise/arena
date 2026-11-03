--!strict
--[[
	Une regle que seuls les tests appellent est une regle qui ne s'applique pas.

	C'est la panne la plus couteuse du projet, et elle est arrivee QUATRE fois :
	`Config.formats` que personne ne lisait, `Rating.counts` qu'aucun service
	n'appelait, `Config.match` contre `Config.prototype`, et le 4 novembre 2026
	l'acceleration des nouveaux joueurs (`Economy.isBoosted`), ecrite, testee,
	commentee dans `ProgressService` comme si elle tournait, et jamais appelee.

	Ce test relit chaque module de `src/shared/` et exige que chaque fonction
	qu'il exporte soit nommee AILLEURS que sur sa ligne de definition, quelque
	part dans `src/`. Celles qui ne le sont pas doivent etre dans la liste
	ci-dessous AVEC LEUR RAISON : une fonction qu'on garde exprès pour les
	tests ou pour plus tard se declare, elle ne se tolere pas en silence.
]]

local fs = require("@lune/fs")

local harness = require("../harness")

-- Nom complet -> raison. Une raison qui dit « pas encore » doit disparaitre le
-- jour ou la fonctionnalite arrive.
local NOT_WIRED_ON_PURPOSE: { [string]: string } = {
	["Classes.drawable"] = "Draft porte sa propre copie du filtre needsAllies ; celle-ci sert aux tests",
	["Downed.reviveHealth"] = "DownedService multiplie par un ratio que les pouvoirs peuvent changer",
	["Downed.isEliminated"] = "le jeu juge la fin de manche par Downed.roundIsOver, plus large",
	["Draws.apply"] = "ProgressService.openCrate applique le resultat sur place, meme effet",
	["Draws.isComplete"] = "une collection complete ne change rien au tirage : tout devient fragments",
	["Economy.canAffordSkin"] = "les skins ne sont pas encore construits",
	["Economy.duplicatesPerSkin"] = "les skins ne sont pas encore construits",
	["Loadout.all"] = "lecture de catalogue pour les tests",
	["Loadout.categories"] = "lecture de catalogue pour les tests",
	["Loadout.pointsLeft"] = "les panneaux calculent le reste a partir du budget envoye",
	["Rating.starting"] = "ProgressService lit Config.elo.startingRating, meme valeur",
	["Rating.newEntry"] = "ProgressService construit son profil complet lui-meme",
	["SkillTree.usablePoints"] = "verification de la regle d'un point par manche, cote tests",
	["SkillTree.maxTier"] = "lecture de Config pour les tests",
	["SkillTree.fullBranchCost"] = "le cout de l'arbre complet est verifie par les tests",
	["SkillTree.activeTier"] = "lecture d'etat pour les tests",
	["Zone.totalShrinkSeconds"] = "verification de la duree de zone, cote tests",
}

local function sources(): { [string]: string }
	local out: { [string]: string } = {}
	for _, folder in { "src/shared", "src/server", "src/client" } do
		for _, fileName in fs.readDir(folder) do
			if string.match(fileName, "%.luau$") ~= nil then
				local path = folder .. "/" .. fileName
				out[path] = fs.readFile(path)
			end
		end
	end
	return out
end

local function countPlain(haystack: string, needle: string): number
	local count = 0
	local start = 1
	while true do
		local i, j = string.find(haystack, needle, start, true)
		if i == nil or j == nil then
			return count
		end
		-- Un nom plus long qui commence pareil (`isBoosted` dans `isBoostedX`)
		-- n'est pas un appel.
		local after = string.sub(haystack, j + 1, j + 1)
		if string.match(after, "[%w_]") == nil then
			count += 1
		end
		start = j + 1
	end
end

return function(t: harness.Harness)
	t.section("Toute fonction pure exportee est appelee par le jeu")

	local all = sources()
	local checked = 0
	local stale: { string } = {}

	for path, source in all do
		local moduleName = string.match(path, "^src/shared/([%w_]+)%.luau$")
		if moduleName == nil then
			continue
		end
		for fnName in string.gmatch(source, "\nfunction " .. moduleName .. "%.([%w_]+)%(") do
			local full = moduleName .. "." .. fnName
			checked += 1
			local uses = 0
			for _, other in all do
				uses += countPlain(other, full)
			end
			-- Une occurrence est la definition elle-meme.
			local wired = uses > 1
			local excused = NOT_WIRED_ON_PURPOSE[full]
			if wired and excused ~= nil then
				table.insert(stale, full)
			elseif not wired then
				t.equal(full .. " est appelee par le jeu, ou excusee", excused ~= nil, true)
			end
		end
	end

	t.equal("le balayage a bien trouve des fonctions", checked > 100, true)

	-- Une excuse qui n'excuse plus rien ment a son tour : la fonction est
	-- branchee, la raison ecrite ici est donc fausse.
	table.sort(stale)
	t.equal("aucune excuse perimee (" .. table.concat(stale, ", ") .. ")", #stale, 0)
end
