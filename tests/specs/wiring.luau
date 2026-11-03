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

local Config = require("../../src/shared/Config")
local Throttle = require("../../src/shared/Throttle")

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

	t.section("Le garde-fou contre l'inondation")

	do
		local settings = Config.network.remoteThrottle
		local buckets = {}
		local passed = 0
		for _ = 1, settings.burst do
			if Throttle.allow(buckets, "p", 0, settings) then
				passed += 1
			end
		end
		t.equal("une rafale de la taille du seau passe entiere", passed, settings.burst)
		t.equal(
			"le message suivant, au meme instant, est refuse",
			Throttle.allow(buckets, "p", 0, settings),
			false
		)
		t.equal("un autre joueur n'en paie rien", Throttle.allow(buckets, "q", 0, settings), true)
		t.equal(
			"une seconde plus tard, ca repasse",
			Throttle.allow(buckets, "p", 1, settings),
			true
		)

		-- Un humain : un clic tous les 150 ms pendant une minute.
		local human = {}
		local refused = 0
		for i = 0, 400 do
			if not Throttle.allow(human, "h", i * 0.15, settings) then
				refused += 1
			end
		end
		t.equal("un humain qui clique toutes les 150 ms n'est jamais coupe", refused, 0)

		-- Un script : cent messages par seconde pendant dix secondes.
		local bot = {}
		local through = 0
		for i = 0, 999 do
			if Throttle.allow(bot, "b", i * 0.01, settings) then
				through += 1
			end
		end
		t.equal(
			"un script a cent par seconde est ramene au debit du seau",
			through <= settings.burst + (10 * settings.perSecond) + 1,
			true
		)
		t.equal(
			"une horloge qui recule ne remplit ni ne vide rien",
			Throttle.allow({ x = { tokens = 0, at = 5 } }, "x", 4, settings),
			false
		)
	end
end
