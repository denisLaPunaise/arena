--!strict
--[[
	Bootstrap — point d'entree serveur, et le seul.

	Il n'y a aucune logique ici : il affiche l'etat des reglages, puis demarre
	les services dans l'ordre. Toute nouvelle mecanique se branche sur cette
	liste, et nulle part ailleurs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Body = require(Arena:WaitForChild("Body"))
local Config = require(Arena:WaitForChild("Config"))
local Classes = require(Arena:WaitForChild("Classes"))
local MatchState = require(Arena:WaitForChild("MatchState"))

local BodyService = require(script.Parent:WaitForChild("BodyService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local DownedService = require(script.Parent:WaitForChild("DownedService"))
local DraftService = require(script.Parent:WaitForChild("DraftService"))
local MatchService = require(script.Parent:WaitForChild("MatchService"))
local ProgressService = require(script.Parent:WaitForChild("ProgressService"))
local SandboxService = require(script.Parent:WaitForChild("SandboxService"))
local SkillTreeService = require(script.Parent:WaitForChild("SkillTreeService"))
local ZoneService = require(script.Parent:WaitForChild("ZoneService"))

local function count(list): number
	local n = 0
	for _ in list do
		n += 1
	end
	return n
end

-- Le cout d'une branche menee au palier 6. Annonce a cote de la longueur de
-- partie, parce que c'est la comparaison des deux qui dit si le dernier palier
-- existe vraiment.
local function fullTreeCost(): number
	local total = 0
	for _, cost in Config.skillTree.tierCosts do
		total += cost
	end
	return total
end

local function describePrototype(): string
	local names = {}
	for _, classId in Config.prototype.classes do
		local class = Classes.byId[classId]
		table.insert(names, if class then class.name else classId)
	end
	return table.concat(names, " contre ")
end

print("================================================")
print(string.format("[Arena] Serveur démarré — réglages version %d", Config.version))
print(
	string.format(
		"[Arena] %d classes, %d objets, %d formats, budget d'équipement %d points",
		count(Classes.all),
		count(Config.items),
		count(Config.formats),
		Config.loadout.budgetPoints
	)
)
-- LA LONGUEUR REELLEMENT JOUEE S'ANNONCE, et c'est ce qui aurait montre le
-- trou plus tot : la banniere disait « premier a 2 manches » depuis des
-- semaines sans que personne ne rapproche ce chiffre du cout d'un palier 6.
local roundsToWin = MatchState.roundsToWin(Config)
print(
	string.format(
		"[Arena] Partie : premier à %d manches gagnées, donc %d manches au maximum "
			.. "— %d points d'arbre, et l'arbre complet en coûte %d",
		roundsToWin,
		(roundsToWin * 2) - 1,
		(roundsToWin * 2) - 1,
		fullTreeCost()
	)
)
if Config.prototype.enabled then
	print(
		string.format(
			"[Arena] Prototype ACTIVÉ : %s. La longueur du prototype remplace celle de "
				.. "Config.match.",
			describePrototype()
		)
	)
else
	print(
		string.format(
			"[Arena] Classe de secours si le tirage ne sert pas tout le monde : %s",
			describePrototype()
		)
	)
end
print(
	string.format(
		"[Arena] Zone %s · agonie %s · arbre %s",
		if Config.round.zoneEnabled then "activée" else "coupée",
		if Config.downed.enabled then "activée" else "coupée",
		if Config.skillTree.enabled then "activé" else "coupé"
	)
)
print(string.format("[Arena] Corps : %s", Body.describe(Config)))
if Config.sandbox.enabled then
	print(
		string.format(
			"[Arena] Bac à sable : seul en jeu, panneau sur la touche %s. Pas en partie.",
			Config.sandbox.toggleKey
		)
	)
end
if not Config.effects.enabled then
	print("[Arena] Les effets visuels sont coupés : les coups seront invisibles.")
end
if Config.skillTree.enabled then
	print(
		string.format(
			"[Arena] Arbre : %d paliers, %d branches par classe, %d s pour dépenser",
			Config.skillTree.tiers,
			Config.skillTree.branchesPerClass,
			Config.skillTree.spendWindowSeconds
		)
	)
end
print("================================================")

-- L'ordre compte : DownedService et ZoneService branchent leurs boucles avant
-- que CombatService ne les interroge, et MatchService demarre en dernier.
-- Le corps en premier : il repose le personnage, et tout ce qui s'accroche
-- dessus — l'arme, l'armure — doit le trouver deja normalise.
BodyService.init()
DownedService.init()
ZoneService.init()
SkillTreeService.init()
CombatService.init()
DraftService.init()
ProgressService.init()
-- Le bac a sable s'initialise avant MatchService, parce que c'est la boucle de
-- partie qui lui passe la main quand il n'y a qu'un joueur.
SandboxService.init()
MatchService.start()
