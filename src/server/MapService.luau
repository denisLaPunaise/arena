--!strict
--[[
	MapService — trouve la map, ou en fabrique une le temps du prototype.

	Le contrat de nommage est la seule interface entre le code et les maps :
	SpawnsA, SpawnsB, ZoneCenter, Cover, MapBounds. Ce module cherche un
	conteneur qui porte ces cinq noms, dans Workspace ou dans un de ses
	enfants, et dit precisement ce qui manque.

	Si rien ne correspond, il construit une arene de test en memoire, au
	lancement de la partie. Rien n'est enregistre, Team Create n'est pas
	touche : c'est juste de quoi jouer sur une surface plane sans avoir a
	construire quoi que ce soit d'abord.
]]

local MapService = {}

local Workspace = game:GetService("Workspace")

local SPAWN_SPACING_STUDS = 10
local SPAWN_DISTANCE_FROM_CENTER = 35
local SPAWN_HEIGHT_STUDS = 4

local function expectedNames(contract): { string }
	return {
		contract.spawnsFolderTeamA,
		contract.spawnsFolderTeamB,
		contract.zoneCenterPart,
		contract.coverFolder,
		contract.boundsPart,
	}
end

local function missingNames(container: Instance, contract): { string }
	local missing = {}
	for _, name in expectedNames(contract) do
		if container:FindFirstChild(name) == nil then
			table.insert(missing, name)
		end
	end
	return missing
end

local function createSpawnFolder(name: string, side: number, count: number): Folder
	local folder = Instance.new("Folder")
	folder.Name = name

	-- Les points sont alignes face au centre, repartis autour de z = 0.
	local firstOffset = -((count - 1) * SPAWN_SPACING_STUDS) / 2

	for index = 1, count do
		local marker = Instance.new("Part")
		marker.Name = string.format("Spawn%d", index)
		marker.Size = Vector3.new(2, 1, 2)
		marker.Anchored = true
		marker.CanCollide = false
		marker.Transparency = 1
		marker.Position = Vector3.new(
			side * SPAWN_DISTANCE_FROM_CENTER,
			SPAWN_HEIGHT_STUDS,
			firstOffset + ((index - 1) * SPAWN_SPACING_STUDS)
		)
		marker.Parent = folder
	end

	return folder
end

local function buildTestMap(contract, spawnPointsPerTeam: number): Instance
	local folder = Instance.new("Folder")
	folder.Name = "ArenaTestMap"

	createSpawnFolder(contract.spawnsFolderTeamA, -1, spawnPointsPerTeam).Parent = folder
	createSpawnFolder(contract.spawnsFolderTeamB, 1, spawnPointsPerTeam).Parent = folder

	local center = Instance.new("Part")
	center.Name = contract.zoneCenterPart
	center.Size = Vector3.new(4, 1, 4)
	center.Anchored = true
	center.CanCollide = false
	center.Transparency = 1
	center.Position = Vector3.new(0, SPAWN_HEIGHT_STUDS, 0)
	center.Parent = folder

	-- Vide, et c'est voulu : le prototype se joue sur une surface plane, sans
	-- couverture. Les obstacles arrivent avec les vraies maps.
	local cover = Instance.new("Folder")
	cover.Name = contract.coverFolder
	cover.Parent = folder

	local bounds = Instance.new("Part")
	bounds.Name = contract.boundsPart
	bounds.Size = Vector3.new(300, 1, 300)
	bounds.Anchored = true
	bounds.CanCollide = false
	bounds.Transparency = 1
	bounds.Position = Vector3.new(0, 0, 0)
	bounds.Parent = folder

	folder.Parent = Workspace
	return folder
end

-- Cherche une map conforme, sinon en fabrique une. Renvoie le conteneur et vrai
-- si c'est l'arene de test.
function MapService.resolve(config): (Instance, boolean)
	local contract = config.mapContract

	if #missingNames(Workspace, contract) == 0 then
		print("[Arena] Map conforme trouvee directement dans Workspace.")
		return Workspace, false
	end

	for _, child in Workspace:GetChildren() do
		if child:IsA("Folder") or child:IsA("Model") then
			local missing = missingNames(child, contract)
			if #missing == 0 then
				print(string.format("[Arena] Map conforme trouvee : %s", child.Name))
				return child, false
			end
		end
	end

	warn("[Arena] Aucune map conforme au contrat de nommage.")
	warn(
		string.format(
			"[Arena] Il manque, dans Workspace ou dans un dossier : %s",
			table.concat(missingNames(Workspace, contract), ", ")
		)
	)
	warn("[Arena] Une arene de test est fabriquee a la volee. Rien n'est enregistre.")

	return buildTestMap(contract, contract.spawnPointsPerTeam), true
end

-- Les positions de depart d'une equipe, dans l'ordre du dossier.
function MapService.spawnPositions(map: Instance, config, team: string): { Vector3 }
	local contract = config.mapContract
	local folderName = if team == "A"
		then contract.spawnsFolderTeamA
		else contract.spawnsFolderTeamB

	local positions = {}
	local folder = map:FindFirstChild(folderName)
	if folder then
		for _, marker in folder:GetChildren() do
			if marker:IsA("BasePart") then
				table.insert(positions, marker.Position)
			end
		end
	end

	-- Filet de securite : une map sans point de depart ne doit pas bloquer la
	-- partie, elle doit la rendre jouable et se signaler.
	if #positions == 0 then
		warn(string.format("[Arena] %s ne contient aucun point de depart.", folderName))
		local side = if team == "A" then -1 else 1
		table.insert(
			positions,
			Vector3.new(side * SPAWN_DISTANCE_FROM_CENTER, SPAWN_HEIGHT_STUDS, 0)
		)
	end

	return positions
end

function MapService.zoneCenter(map: Instance, config): Vector3
	local part = map:FindFirstChild(config.mapContract.zoneCenterPart)
	if part and part:IsA("BasePart") then
		return part.Position
	end
	return Vector3.new(0, SPAWN_HEIGHT_STUDS, 0)
end

return MapService
