--!nolint
--[[
	StashMap — range la map qu'on vient de construire, pour la rotation.

	A COLLER DANS LA BARRE DE COMMANDE, JUSTE APRES UNE RECETTE. La recette
	construit sa map dans Workspace et pose son eclairage ; ce script la range
	dans `ServerStorage.ArenaMaps` AVEC cet eclairage et ses matieres generees.
	On peut alors coller la recette suivante : elle detruit les maps de
	Workspace, pas celles qui sont rangees.

	Pour remplir la rotation, sept fois de suite :
	    recette -> StashMap -> recette -> StashMap -> ...

	Le travail est fait par `MapService.stash`, pour que ce script et le jeu ne
	tiennent pas deux versions de « ce qu'est l'eclairage d'une map ».

	Pour retirer une map de la rotation : la supprimer de ServerStorage.ArenaMaps.
	Pour couper la rotation : `Config.maps.rotate = false`.
]]

local MapService = require(game:GetService("ServerScriptService").Arena.MapService)
local Config = require(game:GetService("ReplicatedStorage").Arena.Config)

local stashed = {}
for _, child in workspace:GetChildren() do
	if child:FindFirstChild("SpawnsA") and child:FindFirstChild("SpawnsB") then
		MapService.stash(child, Config)
		table.insert(stashed, child.Name)
	end
end

local storage = game:GetService("ServerStorage"):FindFirstChild(Config.maps.storageFolder)
local all = {}
if storage then
	for _, child in storage:GetChildren() do
		table.insert(all, child.Name)
	end
end
table.sort(all)

if #stashed == 0 then
	warn("[Arena] Aucune map dans Workspace a ranger. Coller d'abord une recette de tools/.")
else
	print(
		string.format(
			"[Arena] Rangee : %s. En rotation : %s.",
			table.concat(stashed, ", "),
			table.concat(all, ", ")
		)
	)
end
