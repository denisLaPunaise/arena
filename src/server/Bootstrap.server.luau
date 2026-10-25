--!strict
--[[
	Bootstrap — point d'entree serveur.

	Pour l'instant il ne fait qu'une chose : prouver que la chaine complete
	fonctionne. S'il affiche ses lignes dans la console de Studio, alors Rojo
	synchronise bien, les modules partages se chargent, et le fichier de
	configuration est lisible par le serveur. C'est le jalon de l'etape 1.

	La suite se branchera ici, et nulle part ailleurs : un seul point d'entree
	serveur, qui appelle des modules.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Config = require(Arena:WaitForChild("Config"))
local Classes = require(Arena:WaitForChild("Classes"))

local function countFormats(): number
	local n = 0
	for _ in Config.formats do
		n += 1
	end
	return n
end

local function countClasses(): number
	local n = 0
	for _ in Classes.all do
		n += 1
	end
	return n
end

print("================================================")
print(string.format("[Arena] Serveur démarré — réglages version %d", Config.version))
print(
	string.format(
		"[Arena] %d classes, %d formats, budget d'équipement %d points",
		countClasses(),
		countFormats(),
		Config.loadout.budgetPoints
	)
)
print(
	string.format(
		"[Arena] Arbre à %d paliers, premier à %d manches gagnées (%d au maximum)",
		Config.skillTree.tiers,
		Config.match.roundsToWin,
		Config.match.maxRounds
	)
)
print("[Arena] Si tu lis ces lignes, l'étape 1 est validée : Rojo est branché.")
print("================================================")
