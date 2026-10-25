--!strict
--[[
	Bootstrap — point d'entree serveur, et le seul.

	Il n'y a aucune logique ici : il affiche l'etat des reglages, puis demarre
	les services dans l'ordre. Toute nouvelle mecanique se branche sur cette
	liste, et nulle part ailleurs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Config = require(Arena:WaitForChild("Config"))
local Classes = require(Arena:WaitForChild("Classes"))

local CombatService = require(script.Parent:WaitForChild("CombatService"))
local MatchService = require(script.Parent:WaitForChild("MatchService"))

local function count(list): number
	local n = 0
	for _ in list do
		n += 1
	end
	return n
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
		"[Arena] %d classes, %d formats, budget d'équipement %d points",
		count(Classes.all),
		count(Config.formats),
		Config.loadout.budgetPoints
	)
)
print(
	string.format(
		"[Arena] Prototype : %s, premier à %d manches gagnées",
		describePrototype(),
		Config.prototype.roundsToWin
	)
)
print("================================================")

CombatService.init()
MatchService.start()
