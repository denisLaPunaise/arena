--!strict
--[[
	Bootstrap — point d'entree client.

	Deux responsabilites, et pas une de plus : envoyer l'intention d'attaque,
	et afficher ce que le serveur annonce. Aucun calcul de degats, aucun compte
	a rebours tenu ici, aucune decision : le serveur est seul juge et le client
	ne fait que peindre ce qu'on lui dit.

	L'attaque est sur le clic ET sur le tap, parce qu'une bonne partie des
	joueurs Roblox sont sur telephone.

	Le bandeau rouge en haut et en bas sert a une chose : rendre l'etat du
	joueur lisible sans qu'il ait a lire. A terre, l'ecran bat. Hors de la zone,
	il rougit. Un texte seul se rate au milieu d'un combat.

	L'arbre de competences a son propre ecran, dans TreePanel : il prend tout
	l'ecran et se pilote a la souris, donc il n'a rien a voir avec un affichage
	de combat qui doit rester lisible en bougeant.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Remotes = Arena:WaitForChild("Remotes")
local attackRemote = Remotes:WaitForChild("Attack") :: RemoteEvent
local hudRemote = Remotes:WaitForChild("Hud") :: RemoteEvent
local abilityRemote = Remotes:WaitForChild("Ability") :: RemoteEvent

local Config = require(Arena:WaitForChild("Config"))

local DraftPanel = require(script.Parent:WaitForChild("DraftPanel"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local LoadoutPanel = require(script.Parent:WaitForChild("LoadoutPanel"))
local TreePanel = require(script.Parent:WaitForChild("TreePanel"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DOWNED_COLOR = Color3.fromRGB(190, 40, 40)
local ZONE_COLOR = Color3.fromRGB(200, 90, 40)
local OUT_COLOR = Color3.fromRGB(10, 10, 14)

local BAND_HEIGHT = 0.22

local function makeLabel(name: string, size: UDim2, position: UDim2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.4
	label.TextSize = textSize
	label.TextScaled = false
	label.Text = ""
	label.ZIndex = 5
	return label
end

-- Un bandeau degrade, opaque sur le bord de l'ecran et transparent vers le
-- centre : la vue reste degagee, mais le bord de l'ecran change de couleur.
local function makeBand(name: string, atTop: boolean): Frame
	local band = Instance.new("Frame")
	band.Name = name
	band.Size = UDim2.fromScale(1, BAND_HEIGHT)
	band.Position = if atTop then UDim2.fromScale(0, 0) else UDim2.fromScale(0, 1 - BAND_HEIGHT)
	band.BackgroundColor3 = DOWNED_COLOR
	band.BackgroundTransparency = 1
	band.BorderSizePixel = 0
	band.ZIndex = 1

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = if atTop then 90 else 270
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = band

	return band
end

local gui = Instance.new("ScreenGui")
gui.Name = "ArenaHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local topBand = makeBand("TopBand", true)
topBand.Parent = gui

local bottomBand = makeBand("BottomBand", false)
bottomBand.Parent = gui

local status = makeLabel("Status", UDim2.fromScale(1, 0.06), UDim2.fromScale(0.5, 0.06), 20)
status.Parent = gui

local title = makeLabel("Title", UDim2.fromScale(1, 0.14), UDim2.fromScale(0.5, 0.3), 44)
title.Font = Enum.Font.GothamBold
title.Parent = gui

local zone = makeLabel("Zone", UDim2.fromScale(1, 0.05), UDim2.fromScale(0.5, 0.88), 18)
zone.Parent = gui

-- La ligne d'arbre : combien de points dorment, et a quel palier on en est.
-- Elle est en haut a gauche et pas au centre, parce qu'elle doit etre
-- consultable sans jamais attirer l'oeil pendant un echange.
local tree = makeLabel("Tree", UDim2.fromScale(0.6, 0.05), UDim2.fromScale(0.32, 0.12), 17)
tree.TextXAlignment = Enum.TextXAlignment.Left
tree.TextColor3 = Color3.fromRGB(246, 200, 96)
tree.Parent = gui

-- La ligne du pouvoir de classe, sous celle de l'arbre. Elle dit trois choses
-- et pas une de plus : comment il s'appelle, s'il est pret, et ce qu'il reste
-- en stock quand la notion existe. Un pouvoir qu'on doit deviner ne se joue
-- pas.
local ability = makeLabel("Ability", UDim2.fromScale(0.6, 0.05), UDim2.fromScale(0.32, 0.17), 17)
ability.TextXAlignment = Enum.TextXAlignment.Left
ability.Parent = gui

local READY_COLOR = Color3.fromRGB(150, 220, 255)
local CHARGING_COLOR = Color3.fromRGB(150, 160, 175)
local MARKED_COLOR = Color3.fromRGB(200, 120, 240)

-- Les touches des objets viennent de Config, pas d ici : une touche est un
-- reglage comme un autre, et celle de l equipement a deja change une fois.
local USE_KEYS: { Enum.KeyCode } = {}
for index, name in Config.loadout.useKeys do
	USE_KEYS[index] = (Enum.KeyCode :: any)[name]
end
local EDIT_KEY = (Enum.KeyCode :: any)[Config.loadout.editKey]

local hint = makeLabel("Hint", UDim2.fromScale(1, 0.05), UDim2.fromScale(0.5, 0.94), 16)
hint.Text = "Clic pour frapper  ·  E pouvoir  ·  1-4 objets  ·  T arbre  ·  L équipement"
hint.TextTransparency = 0.35
hint.Parent = gui

--------------------------------------------------------------------------------
-- L'ETAT AFFICHE
--------------------------------------------------------------------------------

-- "downed", "out", ou vide. Pilote la couleur et le battement des bandeaux.
local alert = ""
-- Vrai quand la ligne de zone annonce qu'on est dehors.
local outsideZone = false

local function setBandColor(color: Color3)
	topBand.BackgroundColor3 = color
	bottomBand.BackgroundColor3 = color
end

local function setBandTransparency(value: number)
	topBand.BackgroundTransparency = value
	bottomBand.BackgroundTransparency = value
end

local function onRenderStep()
	if alert == "out" then
		setBandColor(OUT_COLOR)
		setBandTransparency(0.25)
		return
	end

	if alert == "downed" then
		-- Un battement lent : l'urgence se voit du coin de l'oeil.
		setBandColor(DOWNED_COLOR)
		setBandTransparency(0.45 + (0.25 * math.sin(os.clock() * 4)))
		return
	end

	if outsideZone then
		setBandColor(ZONE_COLOR)
		setBandTransparency(0.6 + (0.15 * math.sin(os.clock() * 6)))
		return
	end

	setBandTransparency(1)
end

hudRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	title.Text = payload.title or ""
	status.Text = payload.status or ""

	tree.Text = payload.tree or ""

	local zoneText = payload.zone or ""
	zone.Text = zoneText
	outsideZone = string.find(zoneText, "HORS", 1, true) ~= nil

	-- Le serveur envoie l'alerte a chaque rafraichissement : on la remplace,
	-- on ne la cumule pas.
	alert = payload.alert or ""

	zone.TextColor3 = if outsideZone then ZONE_COLOR else Color3.fromRGB(255, 255, 255)
	title.TextColor3 = if alert == "downed" then DOWNED_COLOR else Color3.fromRGB(255, 255, 255)
end)

RunService.RenderStepped:Connect(onRenderStep)

--------------------------------------------------------------------------------
-- LE POUVOIR DE CLASSE
--------------------------------------------------------------------------------

-- Les joueurs reveles par un pouvoir, et jusqu'a quand. Le contour est cree
-- COTE CLIENT : un Highlight pose par le serveur serait vu de tout le monde, et
-- le Traqueur previendrait sa proie au lieu de la suivre.
local highlights: { [Player]: Highlight } = {}

local function reveal(target: Player, seconds: number, color: Color3)
	local character = target.Character
	if character == nil then
		return
	end

	local existing = highlights[target]
	if existing == nil or existing.Parent == nil then
		existing = Instance.new("Highlight")
		existing.FillTransparency = 0.6
		existing.OutlineTransparency = 0
		existing.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		existing.Parent = character
		highlights[target] = existing
	end

	existing.Adornee = character
	existing.FillColor = color
	existing.OutlineColor = color
	existing.Enabled = true

	local token = os.clock()
	existing:SetAttribute("Until", token + seconds)

	task.delay(seconds, function()
		local current = highlights[target]
		if current == nil or current.Parent == nil then
			return
		end
		if (current:GetAttribute("Until") :: number?) ~= token + seconds then
			return
		end
		current:Destroy()
		highlights[target] = nil
	end)
end

local markedUntil = 0

abilityRemote.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	if payload.kind == "reveal" then
		if typeof(payload.target) == "Instance" and payload.target:IsA("Player") then
			local colors = Config.abilities.tuning.revealColor
			reveal(
				payload.target,
				payload.seconds or 3,
				Color3.fromRGB(colors[1], colors[2], colors[3])
			)
		end
	elseif payload.kind == "marked" then
		-- Le marque est prevenu : c'est la faiblesse du Parasite, pas une
		-- politesse. Sans cet avertissement, la classe n'aurait pas de contre.
		markedUntil = os.clock() + (payload.seconds or 0)
	elseif payload.kind == "hud" then
		if payload.ability == nil then
			ability.Text = ""
			return
		end

		local left = payload.left or 0
		if not payload.active then
			ability.Text = string.format("%s  ·  passif", payload.ability)
			ability.TextColor3 = READY_COLOR
		elseif left > 0.05 then
			ability.Text = string.format("%s  ·  %.1fs", payload.ability, left)
			ability.TextColor3 = CHARGING_COLOR
		else
			ability.Text = string.format("%s  ·  E", payload.ability)
			ability.TextColor3 = READY_COLOR
		end

		if payload.stock ~= nil then
			ability.Text ..= string.format("  ·  %d en stock", payload.stock)
		end
	end
end)

-- L'avertissement du marque vit dans la boucle d'affichage, parce qu'il doit
-- clignoter : une ligne fixe de plus se noierait dans les autres.
RunService.RenderStepped:Connect(function()
	if os.clock() >= markedUntil then
		return
	end
	if math.fmod(os.clock(), 1) < 0.5 then
		status.Text = "MARQUÉ — il te voit à travers les murs"
		status.TextColor3 = MARKED_COLOR
	end
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end

	local kind = input.UserInputType
	if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
		attackRemote:FireServer()
		return
	end

	if input.KeyCode == Enum.KeyCode.E then
		abilityRemote:FireServer()
		return
	end

	if input.KeyCode == USE_KEYS[1] then
		LoadoutPanel.use(1)
	elseif input.KeyCode == USE_KEYS[2] then
		LoadoutPanel.use(2)
	elseif input.KeyCode == USE_KEYS[3] then
		LoadoutPanel.use(3)
	elseif input.KeyCode == USE_KEYS[4] then
		LoadoutPanel.use(4)
	elseif input.KeyCode == EDIT_KEY then
		LoadoutPanel.toggle()
	end
end)

Effects.start()
DraftPanel.start()
LoadoutPanel.start()
TreePanel.start()

print(string.format("[Arena] Client démarré pour %s", player.Name))
