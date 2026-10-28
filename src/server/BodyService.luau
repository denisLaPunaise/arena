--!strict
--[[
	BodyService — impose le corps standard de l'arene.

	Le pourquoi est dans `Body.luau`, qui porte la regle en logique pure. Ici
	il n'y a que l'ecriture : prendre la description appliquee au personnage,
	remettre sa geometrie a la norme, et la reappliquer.

	POURQUOI ON PART DE LA DESCRIPTION DU JOUEUR plutot que d'une neuve. Une
	`HumanoidDescription` vide effacerait aussi la chemise, le pantalon, le
	visage et les couleurs — c'est-a-dire tout ce qui fait qu'un joueur se
	reconnait, et tout ce sur quoi les skins se poseront. On ne touche qu'a ce
	qui change la SILHOUETTE.

	CE QUE CE SERVICE NE PEUT PAS FAIRE : forcer le R15. Le type d'avatar est
	un reglage de place (Game Settings -> Avatar), qu'aucune API ne change a
	l'execution. Le service le CONSTATE et le dit dans la console, parce qu'un
	R6 au milieu de R15 porterait l'armure autrement — et personne ne devinerait
	pourquoi en regardant le code.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Config = require(Arena:WaitForChild("Config"))
local Body = require(Arena:WaitForChild("Body"))

local BodyService = {}

-- On ne veut prevenir qu'UNE FOIS par joueur qu'il est en R6 : le message
-- part a chaque reapparition sinon, et une console qui repete n'est plus lue.
local warnedRig: { [Player]: boolean } = {}

--[[
	La description du joueur, ramenee a la geometrie standard. On la modifie
	en place : c'est une copie, `GetAppliedDescription` ne rend jamais l'objet
	vivant du personnage.
]]
local function normalise(description: HumanoidDescription)
	local body = Config.body

	for name, value in body.scales do
		(description :: any)[name] = value
	end

	for _, name in body.bodyParts do
		(description :: any)[name] = 0
	end

	if not body.keepAccessories then
		-- `SetAccessories({}, true)` ET PAS LES HUIT CHAMPS D'EMPLACEMENT.
		-- `HatAccessory`, `HairAccessory` et les six autres ne couvrent que
		-- les accessoires RIGIDES d'autrefois. Un accessoire moderne — et les
		-- vetements en couches — vivent dans une liste a part, que ces champs
		-- ne voient pas.
		--
		-- Vu en jeu le 28 octobre 2026 : les huit champs vides, l'application
		-- reussie, et le pigeon toujours sur le dos du joueur. Le `true`
		-- demande d'inclure les rigides, donc ce seul appel les retire tous.
		description:SetAccessories({}, true)
	end

	if not body.keepClothing then
		description.Shirt = 0
		description.Pants = 0
		description.GraphicTShirt = 0
	end
end

--[[
	Pose le corps standard sur ce personnage.

	`ApplyDescription` part sur le reseau et peut echouer — un joueur qui
	garde son pigeon toute la partie parce qu'un paquet s'est perdu serait
	exactement le probleme qu'on vient de resoudre. D'ou les essais.
]]
local function enforce(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid == nil then
		return
	end

	-- Le R15 est un reglage de place : on ne peut que le constater.
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 and not warnedRig[player] then
		warnedRig[player] = true
		warn(
			string.format(
				"[Arena] %s joue en %s. Le type d'avatar est un réglage de place "
					.. "(Game Settings → Avatar → Avatar Type = R15) : les armures "
					.. "seront plus hautes sur ce corps.",
				player.Name,
				humanoid.RigType.Name
			)
		)
	end

	for attempt = 1, Config.body.applyAttempts do
		local ok, description = pcall(function()
			return humanoid:GetAppliedDescription()
		end)
		if ok and description ~= nil then
			normalise(description)
			local applied = pcall(function()
				humanoid:ApplyDescription(description, Enum.AssetTypeVerification.Always)
			end)
			if applied then
				return
			end
		end
		if attempt < Config.body.applyAttempts then
			task.wait(Config.body.retrySeconds)
		end
	end

	-- On le DIT quand on n'y arrive pas. Un corps non normalise est visible a
	-- l'ecran et inexplicable sans cette ligne.
	warn(
		string.format(
			"[Arena] Le corps standard n'a pas pu être appliqué à %s après %d essais.",
			player.Name,
			Config.body.applyAttempts
		)
	)
end

function BodyService.init()
	-- LE GARDE-FOU, de la meme famille que les autres. Un nom de champ qui
	-- n'existe pas sur une `HumanoidDescription` ne leve RIEN quand on
	-- l'ecrit : la valeur part dans le vide et le corps garde son echelle
	-- d'origine. Le serveur refuse donc de demarrer, et le message nomme le
	-- coupable.
	if Body.enabled(Config) then
		local badScale = Body.unknownScale(Config)
		if badScale ~= nil then
			error(
				string.format(
					"[Arena] Config.body.scales nomme « %s », qui n'est pas une échelle "
						.. "de HumanoidDescription.",
					badScale
				)
			)
		end
		local badPart = Body.unknownBodyPart(Config)
		if badPart ~= nil then
			error(
				string.format(
					"[Arena] Config.body.bodyParts nomme « %s », qui n'est pas une partie "
						.. "du corps d'une HumanoidDescription.",
					badPart
				)
			)
		end
	end

	if not Body.enabled(Config) then
		return
	end

	local function watch(player: Player)
		player.CharacterAppearanceLoaded:Connect(function(character)
			enforce(player, character)
		end)
		-- `CharacterAppearanceLoaded` ne part pas quand l'apparence est coupee
		-- ou deja chargee : on couvre les deux, et `enforce` est sans effet
		-- quand il repasse sur un corps deja normalise.
		player.CharacterAdded:Connect(function(character)
			enforce(player, character)
		end)
		if player.Character ~= nil then
			task.spawn(enforce, player, player.Character)
		end
	end

	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		warnedRig[player] = nil
	end)
end

return BodyService
