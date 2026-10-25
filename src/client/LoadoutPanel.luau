--!strict
--[[
	LoadoutPanel — l'ecran d'equipement, et la rangee d'objets du combat.

	Deux choses dans un seul module, parce qu'elles lisent le meme message du
	serveur :

	  - L'ECRAN, ouvert par L entre deux manches. Cinq colonnes, une par
	    categorie, treize cartes. On clique pour prendre, on reclique pour
	    rendre. Le compteur de points est en haut, en grand : c'est le seul
	    chiffre qui compte.

	  - LA RANGEE, toujours visible en bas a gauche pendant la manche. Elle dit
	    quels objets s'utilisent, sur quel chiffre, et combien de charges
	    restent. Ses cases sont des boutons cliquables, donc la rangee sert de
	    commande sur telephone et de rappel sur ordinateur.

	LA MISE EN PAGE EST EN PIXELS, mise a l'echelle par un UIScale, pour la
	meme raison que DraftPanel : les dispositions souples de Roblox donnent des
	hauteurs nulles des qu'on les imbrique, et ce sont les lignes du bas qui
	disparaissent.

	Ce module n'a aucune autorite. Il envoie « ajoute cet objet » et « utilise
	l'emplacement 2 ». Le serveur revalide tout contre Loadout.validate, qui est
	la meme fonction que celle des tests, et un assemblage a treize points est
	refuse quoi que le client raconte.
]]

local LoadoutPanel = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Remotes = Arena:WaitForChild("Remotes")
local loadoutRemote = Remotes:WaitForChild("Loadout") :: RemoteEvent

local Config = require(Arena:WaitForChild("Config"))

local player = Players.LocalPlayer

local PANEL_WIDTH = 1180
local PANEL_HEIGHT = 660
local MIN_SCALE = 0.4
local MARGIN = 0.94

-- Cinq colonnes, une par categorie. La plus garnie en compte quatre, donc
-- quatre rangees suffisent et rien ne defile : un ecran qui defile cache la
-- moitie du catalogue a quelqu'un qui decouvre le jeu.
local COLUMNS = { "primary", "secondary", "armor", "heal", "utility" }
local COLUMN_WIDTH = 216
local COLUMN_GAP = 12
local CARD_HEIGHT = 96
local CARD_GAP = 8

local BACKGROUND = Color3.fromRGB(12, 14, 20)
local CARD = Color3.fromRGB(26, 30, 40)
local CARD_TAKEN = Color3.fromRGB(28, 54, 42)
local CARD_LOCKED = Color3.fromRGB(20, 21, 26)
local ACCENT = Color3.fromRGB(246, 200, 96)
local GOOD = Color3.fromRGB(120, 220, 150)
local DANGER = Color3.fromRGB(230, 96, 86)
local MUTED = Color3.fromRGB(150, 158, 172)
local TEXT = Color3.fromRGB(240, 244, 255)

local gui: ScreenGui? = nil
local scale: UIScale? = nil
local pointsLabel: TextLabel? = nil
local footer: TextLabel? = nil
local board: Frame? = nil

local strip: ScreenGui? = nil
local slotButtons: { TextButton } = {}

local latest: any = nil
local openned = false

--------------------------------------------------------------------------------
-- LES BRIQUES
--------------------------------------------------------------------------------

local function label(name: string, size: UDim2, position: UDim2, textSize: number): TextLabel
	local made = Instance.new("TextLabel")
	made.Name = name
	made.Size = size
	made.Position = position
	made.BackgroundTransparency = 1
	made.Font = Enum.Font.GothamMedium
	made.TextColor3 = TEXT
	made.TextSize = textSize
	made.Text = ""
	return made
end

local function rounded(instance: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

--------------------------------------------------------------------------------
-- LA RANGEE D'OBJETS, PENDANT LA MANCHE
--------------------------------------------------------------------------------

local function buildStrip()
	if strip ~= nil and strip.Parent ~= nil then
		return
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "ArenaSlots"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 8
	screen.Parent = player:WaitForChild("PlayerGui")

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.Size = UDim2.fromOffset(4 * 148, 52)
	row.Position = UDim2.new(0, 24, 1, -92)
	row.BackgroundTransparency = 1
	row.Parent = screen

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	for index = 1, Config.loadout.maxUsableSlots do
		local button = Instance.new("TextButton")
		button.Name = "Slot" .. index
		button.Size = UDim2.fromOffset(140, 52)
		button.LayoutOrder = index
		button.BackgroundColor3 = CARD
		button.BackgroundTransparency = 0.25
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamMedium
		button.TextSize = 15
		button.TextColor3 = TEXT
		button.TextWrapped = true
		button.Text = ""
		button.Visible = false
		button.Parent = row
		rounded(button, 8)

		button.Activated:Connect(function()
			loadoutRemote:FireServer({ use = index })
		end)

		slotButtons[index] = button
	end

	strip = screen
end

local function refreshStrip(view: any)
	buildStrip()

	local slots = view.slots or {}
	for index, button in slotButtons do
		local slot = slots[index]
		if slot == nil then
			button.Visible = false
			continue
		end

		button.Visible = true
		button.Text =
			string.format("%d  %s\n%d / %d", index, slot.name, slot.charges, slot.maxCharges)

		-- Vide, la case s'eteint sans disparaitre : savoir qu'on n'a plus de
		-- grenade fait partie de l'information, et une case qui disparait se
		-- lit comme un bug.
		if slot.charges <= 0 then
			button.TextColor3 = MUTED
			button.BackgroundTransparency = 0.6
		else
			button.TextColor3 = TEXT
			button.BackgroundTransparency = 0.25
		end
	end
end

--------------------------------------------------------------------------------
-- L'ECRAN D'EQUIPEMENT
--------------------------------------------------------------------------------

local function build()
	if gui ~= nil and gui.Parent ~= nil then
		return
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "ArenaLoadout"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 18
	screen.Enabled = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.3
	backdrop.BorderSizePixel = 0
	backdrop.Parent = screen

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = BACKGROUND
	frame.BorderSizePixel = 0
	frame.Parent = screen
	rounded(frame, 14)

	local uiscale = Instance.new("UIScale")
	uiscale.Parent = frame

	local title = label("Header", UDim2.fromOffset(PANEL_WIDTH, 44), UDim2.fromOffset(0, 22), 32)
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Text = "ÉQUIPEMENT"
	title.Parent = frame

	local points = label("Points", UDim2.fromOffset(PANEL_WIDTH, 36), UDim2.fromOffset(0, 66), 26)
	points.Font = Enum.Font.GothamBold
	points.TextXAlignment = Enum.TextXAlignment.Center
	points.TextColor3 = ACCENT
	points.Parent = frame

	local area = Instance.new("Frame")
	area.Name = "Board"
	area.Size = UDim2.fromOffset(PANEL_WIDTH - 60, 440)
	area.Position = UDim2.fromOffset(30, 112)
	area.BackgroundTransparency = 1
	area.Parent = frame

	local foot =
		label("Footer", UDim2.fromOffset(PANEL_WIDTH - 60, 64), UDim2.fromOffset(30, 560), 18)
	foot.TextColor3 = MUTED
	foot.TextWrapped = true
	foot.TextXAlignment = Enum.TextXAlignment.Center
	foot.Parent = frame

	local reset = Instance.new("TextButton")
	reset.Name = "Reset"
	reset.Size = UDim2.fromOffset(220, 40)
	reset.Position = UDim2.new(0.5, 0, 0, 608)
	reset.AnchorPoint = Vector2.new(0.5, 0)
	reset.BackgroundColor3 = CARD
	reset.BorderSizePixel = 0
	reset.Font = Enum.Font.GothamBold
	reset.TextSize = 17
	reset.TextColor3 = TEXT
	reset.Text = "Assemblage par défaut"
	reset.Parent = frame
	rounded(reset, 8)
	reset.Activated:Connect(function()
		loadoutRemote:FireServer({ reset = true })
	end)

	gui = screen
	scale = uiscale
	pointsLabel = points
	footer = foot
	board = area
end

-- Dessine a taille fixe puis reduit pour tenir dans la fenetre. Sur telephone
-- il devient petit mais il reste ENTIER, et c'est ce qui compte : le prix d'un
-- objet est en bas de sa carte.
local function fit()
	local current = scale
	local screen = gui
	if current == nil or screen == nil then
		return
	end

	local viewport = screen.AbsoluteSize
	if viewport.X <= 0 or viewport.Y <= 0 then
		return
	end

	local factor =
		math.min((viewport.X * MARGIN) / PANEL_WIDTH, (viewport.Y * MARGIN) / PANEL_HEIGHT, 1)
	current.Scale = math.max(factor, MIN_SCALE)
end

local function cardFor(item: any, parent: Frame, order: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = item.id
	button.Size = UDim2.fromOffset(COLUMN_WIDTH, CARD_HEIGHT)
	button.Position = UDim2.fromOffset(0, (order - 1) * (CARD_HEIGHT + CARD_GAP))
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 14
	button.Text = ""
	button.Parent = parent
	rounded(button, 8)

	local name = label("Name", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 8), 17)
	name.Font = Enum.Font.GothamBold
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = item.name
	name.Parent = button

	local summary = label("Summary", UDim2.new(1, -20, 0, 40), UDim2.fromOffset(10, 30), 13)
	summary.TextWrapped = true
	summary.TextXAlignment = Enum.TextXAlignment.Left
	summary.TextYAlignment = Enum.TextYAlignment.Top
	summary.TextColor3 = MUTED
	summary.Text = item.summary
	summary.Parent = button

	local price = label("Price", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 70), 16)
	price.Font = Enum.Font.GothamBold
	price.TextXAlignment = Enum.TextXAlignment.Left
	-- L'affinite se voit sur la carte, prix plein barre a cote : sans ca le
	-- joueur ne sait pas que sa classe lui fait un prix, et l'affinite ne joue
	-- plus son role d'identite.
	if item.affinity then
		price.Text = string.format("%d pts   (au lieu de %d)", item.cost, item.fullCost)
		price.TextColor3 = GOOD
	else
		price.Text = string.format("%d pts", item.cost)
		price.TextColor3 = ACCENT
	end
	price.Parent = button

	if item.carried then
		button.BackgroundColor3 = CARD_TAKEN
	elseif item.addable then
		button.BackgroundColor3 = CARD
	else
		-- Hors budget ou interdit par une regle : la carte s'eteint et la
		-- raison remplace la description. C'est la que le joueur apprend les
		-- regles, et il les apprend en essayant.
		button.BackgroundColor3 = CARD_LOCKED
		name.TextColor3 = MUTED
		price.TextColor3 = DANGER
		if item.refusal ~= nil then
			summary.Text = item.refusal
			summary.TextColor3 = DANGER
		end
	end

	button.Activated:Connect(function()
		if item.carried then
			loadoutRemote:FireServer({ remove = item.id })
		else
			loadoutRemote:FireServer({ add = item.id })
		end
	end)

	return button
end

local function redraw(view: any)
	build()

	local area = board
	local screen = gui
	if area == nil or screen == nil then
		return
	end

	area:ClearAllChildren()

	local byCategory: { [string]: { any } } = {}
	for _, item in view.items do
		local list = byCategory[item.category]
		if list == nil then
			list = {}
			byCategory[item.category] = list
		end
		table.insert(list, item)
	end

	for index, categoryId in COLUMNS do
		local column = Instance.new("Frame")
		column.Name = categoryId
		column.Size = UDim2.fromOffset(COLUMN_WIDTH, 440)
		column.Position = UDim2.fromOffset((index - 1) * (COLUMN_WIDTH + COLUMN_GAP), 26)
		column.BackgroundTransparency = 1
		column.Parent = area

		local items = byCategory[categoryId] or {}

		local heading =
			label("Heading", UDim2.fromOffset(COLUMN_WIDTH, 22), UDim2.fromOffset(0, -26), 15)
		heading.Font = Enum.Font.GothamBold
		heading.TextXAlignment = Enum.TextXAlignment.Left
		heading.TextColor3 = MUTED
		heading.Text = string.upper(if items[1] then items[1].categoryLabel else categoryId)
		heading.Parent = column

		for order, item in items do
			cardFor(item, column, order)
		end
	end

	local points = pointsLabel
	if points ~= nil then
		points.Text = string.format("%d / %d points", view.spent, view.budget)
		points.TextColor3 = if view.ok then ACCENT else DANGER
	end

	local foot = footer
	if foot ~= nil then
		local lines = {}
		if not view.editable then
			table.insert(
				lines,
				"La manche est en cours : l'assemblage se modifie entre deux manches."
			)
		end
		if view.reason ~= nil then
			table.insert(lines, view.reason)
		end
		table.insert(
			lines,
			string.format(
				"Au moins une arme principale  ·  %d objets au maximum  ·  L pour fermer",
				view.maxItems
			)
		)
		foot.Text = table.concat(lines, "\n")
		foot.TextColor3 = if view.reason ~= nil then DANGER else MUTED
	end

	fit()
end

--------------------------------------------------------------------------------
-- L'OUVERTURE
--------------------------------------------------------------------------------

function LoadoutPanel.toggle()
	openned = not openned

	if openned then
		-- On demande l'etat frais a l'ouverture : la classe a pu changer depuis
		-- le dernier message, et avec elle tous les prix.
		loadoutRemote:FireServer({ open = true })
		if latest ~= nil then
			redraw(latest)
		end
	end

	local screen = gui
	if screen ~= nil then
		screen.Enabled = openned
	end
end

function LoadoutPanel.isOpen(): boolean
	return openned
end

function LoadoutPanel.use(slot: number)
	loadoutRemote:FireServer({ use = slot })
end

function LoadoutPanel.start()
	build()
	buildStrip()

	loadoutRemote.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" or payload.kind ~= "loadout" then
			return
		end

		latest = payload
		refreshStrip(payload)

		if openned then
			redraw(payload)
		end
	end)

	local screen = gui
	if screen ~= nil then
		screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	end
end

return LoadoutPanel
