--!strict
--[[
	Effects — ce qu'on voit quand un coup part, touche, ou soigne.

	Le serveur annonce des faits : « un coup est parti d'ici dans cette
	direction », « douze degats ont ete passes la ». C'est ce module qui decide
	a quoi ca ressemble. La separation compte : changer l'apparence d'un coup ne
	doit jamais demander d'ouvrir le code du combat.

	TOUT EST JETABLE. Chaque effet cree une ou deux parts, les anime, et les
	detruit. Rien n'est garde, rien n'est mis en cache, et Debris s'assure que
	meme une animation interrompue finit par disparaitre — un decor qui fuit
	remplit la place sans que personne le remarque avant la chute du nombre
	d'images.

	Ces effets vivent dans un dossier a part, et jamais en vrac dans Workspace :
	Workspace appartient a la construction des maps.
]]

local Effects = {}

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Config = require(Arena:WaitForChild("Config"))

local Remotes = Arena:WaitForChild("Remotes")
local effectsRemote = Remotes:WaitForChild("Effects") :: UnreliableRemoteEvent

local player = Players.LocalPlayer

--------------------------------------------------------------------------------
-- LES COULEURS
--------------------------------------------------------------------------------

-- Un coup recu et un coup donne ne se lisent pas pareil : c'est la seule chose
-- qui differe d'un ecran a l'autre, et c'est ce qui permet de suivre un echange
-- sans compter les points de vie.
local DEALT = Color3.fromRGB(255, 236, 170)
local TAKEN = Color3.fromRGB(255, 118, 104)
local HEAL = Color3.fromRGB(130, 230, 150)
local SPREAD = Color3.fromRGB(190, 150, 240)
local ZONE = Color3.fromRGB(240, 150, 80)
local SWING = Color3.fromRGB(230, 236, 255)
local DASH = Color3.fromRGB(180, 120, 240)
local TRACK = Color3.fromRGB(120, 210, 255)

local folder: Folder? = nil

local function parent(): Folder
	local existing = folder
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end

	local made = Instance.new("Folder")
	made.Name = "ArenaEffects"
	made.Parent = Workspace
	folder = made
	return made
end

local function makePart(size: Vector3, cf: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent()
	return part
end

--------------------------------------------------------------------------------
-- LES NOMBRES QUI MONTENT
--------------------------------------------------------------------------------

local function numberColor(kind: string, mine: boolean): Color3
	if kind == "heal" then
		return HEAL
	elseif kind == "spread" then
		return SPREAD
	elseif kind == "zone" then
		return ZONE
	end
	return if mine then TAKEN else DEALT
end

local function floatingNumber(position: Vector3, amount: number, kind: string, mine: boolean)
	local settings = Config.effects

	-- Un coup plus fort s'ecrit plus gros. On lit la violence d'un echange sans
	-- lire les chiffres eux-memes.
	local scale = math.clamp(amount / settings.numberSizeReference, 0.6, 1)
	local size = settings.numberSize
		+ ((settings.numberSizeMax - settings.numberSize) * (scale - 0.6) / 0.4)

	local anchor = Instance.new("Part")
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(position)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Parent = parent()

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 60)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = size
	label.TextColor3 = numberColor(kind, mine)
	label.TextStrokeTransparency = 0.25
	label.Text = if kind == "heal"
		then string.format("+%d", math.max(math.floor(amount + 0.5), 1))
		else tostring(math.max(math.floor(amount + 0.5), 1))
	label.Parent = billboard

	local seconds = settings.numberSeconds
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	TweenService:Create(anchor, info, {
		CFrame = CFrame.new(position + Vector3.new(0, settings.numberRiseStuds, 0)),
	}):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()

	Debris:AddItem(anchor, seconds + 0.1)
end

--------------------------------------------------------------------------------
-- LE COUP, L'ECLAIR, LE BOND
--------------------------------------------------------------------------------

local function fadeOut(part: Part, seconds: number, grow: Vector3?)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goal: { [string]: any } = { Transparency = 1 }
	if grow ~= nil then
		goal.Size = grow
	end
	TweenService:Create(part, info, goal):Play()
	Debris:AddItem(part, seconds + 0.1)
end

-- Le trait du coup. Il part meme quand le coup ne touche rien : rater doit se
-- voir, sinon on ne comprend jamais la portee de sa classe.
local function swing(position: Vector3, direction: Vector3, hit: boolean)
	local settings = Config.effects

	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude <= 0 then
		return
	end

	local length = direction.Magnitude
	local centre = position + (flat.Unit * (length / 2))

	local part = makePart(
		Vector3.new(settings.swingWidthStuds, settings.swingHeightStuds, length),
		CFrame.lookAt(centre, centre + flat.Unit),
		SWING
	)
	part.Transparency = if hit then 0.25 else 0.7

	fadeOut(part, settings.swingSeconds)
end

local function flash(position: Vector3, color: Color3)
	local settings = Config.effects
	local part = makePart(Vector3.one * 0.6, CFrame.new(position), color)
	part.Shape = Enum.PartType.Ball
	part.Transparency = 0.15
	fadeOut(part, settings.flashSeconds, Vector3.one * settings.flashStuds)
end

-- Une trace de pas. Elle n'arrive qu'au Traqueur : le serveur ne l'envoie qu'a
-- lui. Elle s'efface sur toute sa duree de vie plutot que de disparaitre d'un
-- coup, parce que c'est la difference de transparence entre deux traces qui dit
-- dans quel sens quelqu'un courait.
local function footprint(position: Vector3, seconds: number, health: number?)
	local part = makePart(Vector3.new(1.4, 0.08, 2.2), CFrame.new(position), TRACK)
	part.Transparency = 0.3
	fadeOut(part, seconds)

	if health ~= nil then
		-- Palier 6 du Limier : la trace dit aussi dans quel etat etait son
		-- auteur. Plus petit qu'un nombre de degats, et sans montee : c'est une
		-- information a lire, pas un evenement a remarquer.
		local anchor = Instance.new("Part")
		anchor.Size = Vector3.one
		anchor.CFrame = CFrame.new(position + Vector3.new(0, 1.6, 0))
		anchor.Transparency = 1
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Parent = parent()

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(90, 34)
		billboard.AlwaysOnTop = true
		billboard.Parent = anchor

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 18
		label.TextColor3 = TRACK
		label.TextStrokeTransparency = 0.4
		label.Text = string.format("%d PV", math.max(math.floor(health + 0.5), 0))
		label.Parent = billboard

		local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 })
			:Play()
		Debris:AddItem(anchor, seconds + 0.1)
	end
end

local function dash(position: Vector3, direction: Vector3)
	local settings = Config.effects
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude <= 0 then
		return
	end

	local length = math.min(flat.Magnitude, 20)
	local centre = position + (flat.Unit * (length / 2))

	local part =
		makePart(Vector3.new(0.8, 0.8, length), CFrame.lookAt(centre, centre + flat.Unit), DASH)
	part.Transparency = 0.35
	fadeOut(part, settings.dashSeconds)
end

--------------------------------------------------------------------------------
-- LA RECEPTION
--------------------------------------------------------------------------------

local function onEffect(payload: any)
	if not Config.effects.enabled then
		return
	end
	if typeof(payload) ~= "table" or typeof(payload.position) ~= "Vector3" then
		return
	end

	local kind = payload.kind
	if typeof(kind) ~= "string" then
		return
	end

	-- Vrai quand l'effet me concerne : c'est ce qui decide si le nombre
	-- s'affiche en rouge (je le prends) ou en clair (je le donne).
	local mine = payload.target == player

	if kind == "footprint" then
		footprint(payload.position, payload.seconds or 4, payload.amount)
	elseif kind == "swing" then
		swing(payload.position, payload.direction, payload.hit == true)
	elseif kind == "dash" then
		dash(payload.position, payload.direction)
	elseif kind == "down" then
		flash(payload.position, TAKEN)
	elseif kind == "revive" then
		flash(payload.position, HEAL)
	elseif typeof(payload.amount) == "number" then
		if kind == "hit" then
			flash(payload.position, if mine then TAKEN else DEALT)
		elseif kind == "spread" then
			flash(payload.position, SPREAD)
		end
		floatingNumber(payload.position, payload.amount, kind, mine)
	end
end

function Effects.start()
	effectsRemote.OnClientEvent:Connect(onEffect)
end

return Effects
