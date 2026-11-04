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
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Config = require(Arena:WaitForChild("Config"))
local MapRotation = require(Arena:WaitForChild("MapRotation"))

-- Le dossier qui tient les reglages des nuages d'une map rangee.
local CLOUDS_RECORD = "ArenaClouds"

-- Le nom de la derniere map jouee, pour ne pas la resservir.
local lastMapName: string? = nil

-- LES TROIS CHIFFRES DE LA MAP DE SECOURS VIENNENT DE CONFIG. Ils etaient en
-- dur ici, ce qui est un bug meme quand les valeurs sont bonnes : personne ne
-- peut regler une map vide sans lire ce fichier. Leur raison est a cote d'eux
-- dans `Config.mapContract`.
local SPAWN_SPACING_STUDS = Config.mapContract.fallbackSpawnSpacingStuds
local SPAWN_DISTANCE_FROM_CENTER = Config.mapContract.fallbackSpawnDistanceFromCenterStuds
local SPAWN_HEIGHT_STUDS = Config.mapContract.fallbackSpawnHeightStuds

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

	-- Rien dans Workspace, mais des maps rangees : on en sort une plutot que
	-- de fabriquer l'arene vide. Sinon la premiere partie d'un serveur se
	-- jouerait toujours sur un plancher nu.
	local storage = ServerStorage:FindFirstChild(config.maps.storageFolder)
	if storage ~= nil then
		local stored: { Instance } = {}
		for _, child in storage:GetChildren() do
			if #missingNames(child, contract) == 0 then
				table.insert(stored, child)
			end
		end
		if #stored > 0 then
			local chosen = stored[math.random(1, #stored)]
			chosen.Parent = Workspace
			MapService.applyLighting(chosen, config)
			lastMapName = chosen.Name
			print(
				string.format(
					"[Arena] Map sortie du rangement : %s (%d rangees).",
					chosen.Name,
					#stored
				)
			)
			return chosen, false
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

--------------------------------------------------------------------------------
-- LA ROTATION DES MAPS
--------------------------------------------------------------------------------

local function isEffect(config, inst: Instance): boolean
	for _, class in config.maps.lightingEffects do
		if inst:IsA(class) then
			return true
		end
	end
	return false
end

-- L'ECLAIRAGE APPARTIENT A LA MAP, mais il vit dans `Lighting`, qui est un
-- reglage de place : une map rangee doit donc emporter le sien. Recopie les
-- reglages en attributs et clone les effets dans un dossier de la map.
function MapService.snapshotLighting(map: Instance, config)
	local old = map:FindFirstChild(config.maps.lightingFolder)
	if old ~= nil then
		old:Destroy()
	end
	local preset = Instance.new("Folder")
	preset.Name = config.maps.lightingFolder
	for _, name in config.maps.lightingProperties do
		local ok, value = pcall(function()
			return (Lighting :: any)[name]
		end)
		if ok then
			preset:SetAttribute(name, value)
		end
	end
	for _, source in { Lighting, Workspace.Terrain } do
		for _, child in source:GetChildren() do
			if isEffect(config, child) then
				-- DES NUAGES NE SE RANGENT PAS EN NUAGES. Une map sortie dans
				-- Workspace emporte son dossier d'eclairage, et Roblox proteste
				-- contre TOUT `Clouds` hors du Terrain, meme eteint (« More than
				-- one Cloud instance », vu en jeu le 4 novembre 2026). On range
				-- donc leurs trois reglages en attributs, et on les recree.
				if child:IsA("Clouds") then
					local record = Instance.new("Folder")
					record.Name = CLOUDS_RECORD
					record:SetAttribute("Cover", child.Cover)
					record:SetAttribute("Density", child.Density)
					record:SetAttribute("Color", child.Color)
					record.Parent = preset
				else
					child:Clone().Parent = preset
				end
			end
		end
	end
	preset.Parent = map
end

-- Pose l'eclairage d'une map rangee. Les effets presents sont retires d'abord :
-- deux `Atmosphere` dans `Lighting` se disputent l'image.
function MapService.applyLighting(map: Instance, config): boolean
	local preset = map:FindFirstChild(config.maps.lightingFolder)
	if preset == nil then
		return false
	end
	for _, name in config.maps.lightingProperties do
		local value = preset:GetAttribute(name)
		if value ~= nil then
			pcall(function()
				(Lighting :: any)[name] = value
			end)
		end
	end
	for _, source in { Lighting, Workspace.Terrain } do
		for _, child in source:GetChildren() do
			if isEffect(config, child) then
				child:Destroy()
			end
		end
	end
	for _, child in preset:GetChildren() do
		if child.Name == CLOUDS_RECORD then
			local clouds = Instance.new("Clouds")
			clouds.Cover = child:GetAttribute("Cover") or 0.5
			clouds.Density = child:GetAttribute("Density") or 0.5
			clouds.Color = child:GetAttribute("Color") or Color3.new(1, 1, 1)
			clouds.Parent = Workspace.Terrain
		else
			child:Clone().Parent = Lighting
		end
	end
	return true
end

-- RANGE UNE MAP qu'on vient de construire (appele par `tools/StashMap.luau`, en
-- mode edition). Elle part dans ServerStorage avec son eclairage, et ses
-- matieres generees passent dans le dossier que les recettes ne detruisent pas.
function MapService.stash(map: Instance, config): Instance
	local storage = ServerStorage:FindFirstChild(config.maps.storageFolder)
	if storage == nil then
		local folder = Instance.new("Folder")
		folder.Name = config.maps.storageFolder
		folder.Parent = ServerStorage
		storage = folder
	end
	local shelf = storage :: Instance
	local existing = shelf:FindFirstChild(map.Name)
	if existing ~= nil and existing ~= map then
		-- Un seul exemplaire par nom : deux maps du meme nom, et la rotation en
		-- tirerait une au hasard sans que personne le sache.
		existing:Destroy()
	end
	MapService.snapshotLighting(map, config)
	map.Parent = shelf

	local fresh = MaterialService:FindFirstChild("ArenaMaterials")
	if fresh ~= nil then
		local keep = MaterialService:FindFirstChild(config.maps.materialsKeepFolder)
		if keep == nil then
			local folder = Instance.new("Folder")
			folder.Name = config.maps.materialsKeepFolder
			folder.Parent = MaterialService
			keep = folder
		end
		local kept = keep :: Instance
		for _, variant in fresh:GetChildren() do
			local same = kept:FindFirstChild(variant.Name)
			if same ~= nil then
				same:Destroy()
			end
			variant.Parent = kept
		end
	end
	return shelf
end

-- LA PROCHAINE MAP. Range celle qui est en jeu, en sort une autre, pose son
-- eclairage, et deplace sur elle les personnages presents : sans ca, un joueur
-- reste au menu ou sur le banc debout sur une map qui vient de disparaitre, et
-- tombe dans le vide. Rend nil quand il n'y a rien a faire tourner : pas de
-- dossier de rangement, moins de deux maps, ou la rotation coupee dans Config.
function MapService.rotate(config, current: Instance?, rng: (number) -> number): Instance?
	if not config.maps.rotate then
		return nil
	end
	local storage = ServerStorage:FindFirstChild(config.maps.storageFolder)
	if storage == nil then
		return nil
	end

	local byName: { [string]: Instance } = {}
	local names: { string } = {}
	for _, child in storage:GetChildren() do
		if #missingNames(child, config.mapContract) == 0 and byName[child.Name] == nil then
			byName[child.Name] = child
			table.insert(names, child.Name)
		end
	end

	-- La map en jeu participe au tirage, sauf l'arene de secours : celle-la
	-- n'est qu'un plancher, on la jette des qu'une vraie map existe.
	local live = current ~= nil and current ~= Workspace and current.Parent == Workspace
	local isTest = live and current ~= nil and current.Name == "ArenaTestMap"
	if live and not isTest and current ~= nil and byName[current.Name] == nil then
		byName[current.Name] = current
		table.insert(names, current.Name)
	end
	if #names == 0 or (#names < 2 and not isTest) then
		return nil
	end

	local avoid = lastMapName
	if avoid == nil and current ~= nil then
		avoid = current.Name
	end
	local chosenName = MapRotation.pick(names, avoid, rng)
	local chosen = if chosenName ~= nil then byName[chosenName] else nil
	if chosen == nil or chosen == current then
		return nil
	end

	if live and current ~= nil then
		if isTest then
			current:Destroy()
		else
			if current:FindFirstChild(config.maps.lightingFolder) == nil then
				MapService.snapshotLighting(current, config)
			end
			-- Une recette collee alors que sa map est deja rangee : celle de
			-- Workspace est la plus recente, elle remplace l'autre. Sans ca, le
			-- rangement tiendrait deux maps du meme nom.
			local same = storage:FindFirstChild(current.Name)
			if same ~= nil and same ~= current then
				same:Destroy()
			end
			current.Parent = storage
		end
	end
	chosen.Parent = Workspace
	MapService.applyLighting(chosen, config)
	lastMapName = chosen.Name

	local centre = MapService.zoneCenter(chosen, config)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil and character.Parent ~= nil then
			character:PivotTo(CFrame.new(centre + Vector3.new(0, 6, 0)))
		end
	end

	print(string.format("[Arena] Map de la partie : %s (%d en rotation).", chosen.Name, #names))
	return chosen
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
