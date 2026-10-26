--!strict
--[[
	WeaponService — l'arme qu'on tient, et le geste qui part avec elle.

	POURQUOI CE SERVICE EXISTE. L'equipement etait invisible : deux joueurs
	s'affrontaient avec douze points depenses chacun et rien a l'ecran ne
	disait lequel portait un marteau et lequel un arc. Or c'est exactement
	l'information qui decide de la seconde suivante — on ne joue pas un
	corps-a-corps de la meme facon contre une portee de 60 studs. Un budget
	qu'on ne voit pas sur l'adversaire n'est pas une mecanique de jeu, c'est
	une feuille de calcul.

	AUCUNE ANIMATION TELEVERSEE. Une `Animation` Roblox demande un identifiant
	d'asset, donc un televersement sur un compte, donc quelque chose que
	personne ne peut relire dans ce depot ni rejouer ailleurs. Tout ici est
	geometrique : un `Motor6D` entre la main et l'arme, et son `C0` qu'on
	anime. Le prix a payer est qu'on ne bouge que l'arme, pas le bras ; le
	gain est qu'une arme neuve se decrit entierement dans `Config.items`, en
	six chiffres, sans sortir de l'editeur.

	CE SERVICE NE REQUIERT RIEN DU SERVEUR. Pas de `CombatService`, pas de
	`LoadoutService` : c'est `LoadoutService` qui l'appelle, jamais l'inverse.
	Il ne decide de rien, il montre.

	L'ARME SURVIT A LA MORT DU PERSONNAGE. On retient ce que chaque joueur
	porte, et on la reconstruit a chaque `CharacterAdded` : sans ca, elle
	disparaitrait a la premiere manche perdue et ne reviendrait qu'au prochain
	changement d'equipement, c'est-a-dire peut-etre jamais.
]]

local WeaponService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Config = require(Arena:WaitForChild("Config"))

local MODEL_NAME = "ArenaWeapon"
local GRIP_NAME = "ArenaGrip"

-- Ce que chaque joueur est cense porter. C'est la memoire qui permet de
-- rebatir l'arme apres une mort, et de ne rien rebatir quand l'arme n'a pas
-- change — reconstruire a chaque coup ferait clignoter le modele.
local wanted: { [Player]: any } = {}
local joints: { [Player]: Motor6D } = {}
local restC0: { [Player]: CFrame } = {}

-- Un jeton par joueur pour le retour du geste. Sans lui, le retour d'un coup
-- lance il y a 70 ms repose l'arme en plein milieu du coup suivant, et une
-- arme rapide comme le couteau tremble au lieu de frapper.
local swingToken: { [Player]: number } = {}

local function triple(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

local function colorOf(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- La main droite, R15 ou R6. Les deux rigs existent encore sur Roblox et le
-- choix appartient au joueur, pas au jeu : il faut savoir lire les deux.
local function handOf(character: Model): BasePart?
	local r15 = character:FindFirstChild("RightHand")
	if r15 ~= nil and r15:IsA("BasePart") then
		return r15
	end
	local r6 = character:FindFirstChild("Right Arm")
	if r6 ~= nil and r6:IsA("BasePart") then
		return r6
	end
	return nil
end

-- Une piece d'arme : jamais de collision, jamais de masse, jamais de requete
-- spatiale. Une arme qui pousse son porteur ou qui intercepte un rayon de
-- visee serait un bug de combat ne d'un element decoratif.
local function makePiece(name: string, size: { number }, color: { number }): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = triple(size)
	part.Color = colorOf(color)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

function WeaponService.clear(player: Player)
	joints[player] = nil
	restC0[player] = nil

	local character = player.Character
	if character == nil then
		return
	end
	local existing = character:FindFirstChild(MODEL_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
end

-- Pose l'arme sur CE personnage et renvoie l'articulation qui la tient.
--
-- Separee de `build` pour une raison precise : la capture d'ecran de Studio
-- ne photographie pas la vue 3D en mode jeu, seulement l'interface. Verifie
-- le 26 octobre 2026 — la camera voyait le sol a 28 studs et le personnage
-- etait a l'ecran d'apres `WorldToViewportPoint`, et la capture etait noire.
-- La seule facon de REGARDER une arme est donc de la poser en mode edition,
-- ce qui demande une fonction qui ne connaisse pas `Player`.
function WeaponService.attach(character: Model, item: any): Motor6D?
	local hand = handOf(character)
	if hand == nil then
		return nil
	end

	local look = item.look
	if look == nil then
		return nil
	end

	local existing = character:FindFirstChild(MODEL_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = MODEL_NAME

	local body = makePiece(item.id, look.size, look.color)
	model.PrimaryPart = body
	body.Parent = model

	-- La tete du marteau et le canon du fusil. Un deuxieme `Motor6D` plutot
	-- qu'une soudure : la soudure a besoin que les deux pieces soient deja
	-- placees dans le monde, et elles ne le sont pas encore ici.
	local head = look.head
	if head ~= nil then
		local piece = makePiece("Head", head.size, head.color)
		piece.Parent = model
		local link = Instance.new("Motor6D")
		link.Name = "Head"
		link.Part0 = body
		link.Part1 = piece
		link.C0 = CFrame.new(0, 0, head.atStuds)
		link.Parent = body
	end

	local rest = CFrame.new(triple(look.grip))

	local grip = Instance.new("Motor6D")
	grip.Name = GRIP_NAME
	grip.Part0 = hand
	grip.Part1 = body
	grip.C0 = rest
	grip.Parent = hand

	model.Parent = character
	return grip
end

-- Construit l'arme sur le personnage actuel du joueur. Silencieux s'il n'y a
-- pas de personnage ou pas de main : ce n'est pas une erreur, c'est un joueur
-- en train de reapparaitre, et `CharacterAdded` repassera.
local function build(player: Player, item: any)
	local character = player.Character
	if character == nil then
		return
	end

	WeaponService.clear(player)

	local grip = WeaponService.attach(character, item)
	if grip == nil then
		return
	end

	joints[player] = grip
	restC0[player] = grip.C0
end

-- Montre cette arme, ou rien si `item` est nil. Ne reconstruit que si l'arme
-- a change : c'est appele a chaque coup, et a chaque recalcul de
-- statistiques.
function WeaponService.show(player: Player, item: any)
	local current = wanted[player]
	if current ~= nil and item ~= nil and current.id == item.id then
		-- Meme arme, mais le personnage a pu reapparaitre entre-temps : on
		-- verifie que l'articulation est encore vivante avant de ne rien
		-- faire.
		local grip = joints[player]
		if grip ~= nil and grip.Parent ~= nil then
			return
		end
	end

	wanted[player] = item
	if item == nil then
		WeaponService.clear(player)
		return
	end
	build(player, item)
end

-- Le geste. Il part vite et il revient lentement : un coup est sec, un retour
-- au repos ne l'est pas. Les angles sont ceux de `Config.loadout.weaponMotion`
-- et dependent de l'arme, pas de la classe — c'est le marteau qui s'abat, pas
-- le Colosse.
function WeaponService.swing(player: Player, item: any)
	local grip = joints[player]
	if grip == nil or grip.Parent == nil then
		return
	end
	local rest = restC0[player]
	if rest == nil then
		return
	end

	local look = item ~= nil and item.look or nil
	if look == nil then
		return
	end

	local motion = Config.loadout.weaponMotion
	local kind = motion[look.swing]
	if kind == nil then
		return
	end

	local target = rest
		* CFrame.new(0, 0, kind.pullStuds)
		* CFrame.Angles(math.rad(kind.pitch), math.rad(kind.yaw), math.rad(kind.roll))

	local out = TweenInfo.new(motion.outSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(grip, out, { C0 = target }):Play()

	local token = (swingToken[player] or 0) + 1
	swingToken[player] = token

	task.delay(motion.outSeconds, function()
		-- Un coup plus recent est parti : c'est lui qui decidera du retour.
		if swingToken[player] ~= token then
			return
		end
		local still = joints[player]
		local home = restC0[player]
		if still == nil or still.Parent == nil or home == nil then
			return
		end
		local back =
			TweenInfo.new(motion.backSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(still, back, { C0 = home }):Play()
	end)
end

local started = false

function WeaponService.init()
	if started then
		return
	end
	started = true

	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			-- Le personnage arrive membre par membre : la main n'existe pas
			-- forcement a l'instant ou l'evenement part.
			task.defer(function()
				local item = wanted[player]
				if item == nil then
					return
				end
				joints[player] = nil
				build(player, item)
			end)
		end)
	end

	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)

	Players.PlayerRemoving:Connect(function(player)
		wanted[player] = nil
		joints[player] = nil
		restC0[player] = nil
		swingToken[player] = nil
	end)
end

return WeaponService
