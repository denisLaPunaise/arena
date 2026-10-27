--!strict
--[[
	DraftPanel — l'ecran des bans, du relancement et de la revelation.

	Trois moments, un seul panneau, parce qu'ils s'enchainent sans respiration :
	on bannit, on accepte ou non un relancement aveugle, on decouvre sa classe.
	Un ecran par moment ferait trois ouvertures et trois fermetures pour une
	seule phase.

	LA MISE EN PAGE EST EN PIXELS, et mise a l'echelle par un UIScale. C'est la
	lecon de TreePanel : les dispositions souples de Roblox donnent des hauteurs
	nulles des qu'on les imbrique, et ce sont toujours les lignes du bas qui
	disparaissent — ici la faiblesse de la classe, c'est-a-dire exactement ce
	qu'il faut lire avant de bannir.

	Ce module n'a aucune autorite : il envoie « je vote pour » et « je relance »,
	et c'est le serveur qui decide. Un client qui voterait pour une classe deja
	bannie est ignore de l'autre cote.
]]

local DraftPanel = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Remotes = Arena:WaitForChild("Remotes")
local draftRemote = Remotes:WaitForChild("Draft") :: RemoteEvent

local Screens = require(script.Parent:WaitForChild("Screens"))

local player = Players.LocalPlayer

local PANEL_WIDTH = 1180
local PANEL_HEIGHT = 640

-- Sept cartes par rangee, donc DEUX rangees pour les quatorze classes.
-- Six par rangee en faisait trois, et la troisieme passait sous le pied de
-- page : la largeur se regle en fonction du nombre de classes, pas l'inverse.
--   7 * 148 + 6 * 10 = 1096, pour 1120 disponibles
local CARD_WIDTH = 148
local CARD_HEIGHT = 158

local BACKGROUND = Color3.fromRGB(12, 14, 20)
local CARD = Color3.fromRGB(26, 30, 40)
local CARD_VOTED = Color3.fromRGB(60, 52, 24)
local ACCENT = Color3.fromRGB(246, 200, 96)
local DANGER = Color3.fromRGB(230, 96, 86)
local MUTED = Color3.fromRGB(150, 158, 172)

local gui: ScreenGui? = nil
local scale: UIScale? = nil
local panelFrame: Frame? = nil
local fit: () -> ()
local header: TextLabel? = nil
local subheader: TextLabel? = nil
local timerLabel: TextLabel? = nil
local grid: Frame? = nil
-- Le corps libre, a la meme place que la grille. Les deux ne sont jamais
-- affiches ensemble : la grille a une disposition qui impose la taille de ses
-- enfants, donc tout ce qui n'est pas une carte de classe doit vivre ailleurs.
-- C'est ce qui ecrasait le bouton de relancement a la taille d'une carte.
local body: Frame? = nil
local bodyTitle: TextLabel? = nil
local bodyNote: TextLabel? = nil
local footer: TextLabel? = nil

local deadline = 0
local myVote: string? = nil
local cards: { [string]: TextButton } = {}

--------------------------------------------------------------------------------
-- LA CONSTRUCTION
--------------------------------------------------------------------------------

local function label(name: string, size: UDim2, position: UDim2, textSize: number): TextLabel
	local made = Instance.new("TextLabel")
	made.Name = name
	made.Size = size
	made.Position = position
	made.BackgroundTransparency = 1
	made.Font = Enum.Font.GothamMedium
	made.TextColor3 = Color3.fromRGB(240, 244, 255)
	made.TextSize = textSize
	made.TextXAlignment = Enum.TextXAlignment.Center
	made.Text = ""
	return made
end

local function build()
	if gui ~= nil and gui.Parent ~= nil then
		return
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "ArenaDraft"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 20
	screen.Enabled = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.35
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

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame

	local uiscale = Instance.new("UIScale")
	uiscale.Parent = frame
	panelFrame = frame

	-- La fenetre change de taille, le panneau suit. BRANCHE ICI, et pas
	-- dans start() : le ScreenGui n'existe pas encore quand start() tourne,
	-- donc la connexion n'etait jamais prise et un panneau ouvert avant la
	-- premiere mise a jour du serveur se dessinait a sa taille entiere.
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fit()
	end)

	local title = label("Header", UDim2.fromOffset(PANEL_WIDTH, 48), UDim2.fromOffset(0, 26), 34)
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	local sub = label("Sub", UDim2.fromOffset(PANEL_WIDTH, 28), UDim2.fromOffset(0, 74), 19)
	sub.TextColor3 = MUTED
	sub.Parent = frame

	local timer = label("Timer", UDim2.fromOffset(PANEL_WIDTH, 34), UDim2.fromOffset(0, 104), 26)
	timer.Font = Enum.Font.GothamBold
	timer.TextColor3 = ACCENT
	timer.Parent = frame

	local area = Instance.new("Frame")
	area.Name = "Grid"
	area.Size = UDim2.fromOffset(PANEL_WIDTH - 60, 330)
	area.Position = UDim2.fromOffset(30, 150)
	area.BackgroundTransparency = 1
	area.Parent = frame

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = area

	local free = Instance.new("Frame")
	free.Name = "Body"
	free.Size = UDim2.fromOffset(PANEL_WIDTH - 60, 330)
	free.Position = UDim2.fromOffset(30, 150)
	free.BackgroundTransparency = 1
	free.Visible = false
	free.Parent = frame

	local bigText = label("BodyTitle", UDim2.new(1, 0, 0, 120), UDim2.fromOffset(0, 40), 27)
	bigText.TextWrapped = true
	bigText.Parent = free

	local note = label("BodyNote", UDim2.new(1, 0, 0, 90), UDim2.fromOffset(0, 168), 21)
	note.TextWrapped = true
	note.TextColor3 = DANGER
	note.Parent = free

	local foot = label("Footer", UDim2.fromOffset(PANEL_WIDTH, 60), UDim2.fromOffset(0, 500), 20)
	foot.TextColor3 = MUTED
	foot.TextWrapped = true
	foot.Parent = frame

	gui = screen
	scale = uiscale
	header = title
	subheader = sub
	timerLabel = timer
	grid = area
	body = free
	bodyTitle = bigText
	bodyNote = note
	footer = foot
end

-- Le panneau est dessine a taille fixe puis reduit pour tenir dans la fenetre.
-- Sur telephone il devient petit, mais il reste ENTIER : aucune ligne ne sort
-- du cadre, et c'est ce qui compte quand ce sont les lignes du bas qui portent
-- la faiblesse d'une classe.
function fit()
	local current = scale
	local screen = gui
	local frame = panelFrame
	if current == nil or screen == nil or frame == nil then
		return
	end
	Screens.fit(screen, frame, current, PANEL_WIDTH, PANEL_HEIGHT)
end

--------------------------------------------------------------------------------
-- LES CARTES
--------------------------------------------------------------------------------

local function showGrid(visible: boolean)
	local area = grid
	local free = body
	if area ~= nil then
		area.Visible = visible
	end
	if free ~= nil then
		free.Visible = not visible
	end
end

local function clearGrid()
	local area = grid
	if area == nil then
		return
	end
	for _, child in area:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	cards = {}
end

local function makeCard(class: any, index: number, canVote: boolean): TextButton
	local button = Instance.new("TextButton")
	button.Name = class.id
	button.LayoutOrder = index
	button.BackgroundColor3 = CARD
	button.BorderSizePixel = 0
	button.AutoButtonColor = canVote
	button.Text = ""
	button.Active = canVote

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	local name = label("Name", UDim2.new(1, -16, 0, 24), UDim2.fromOffset(8, 10), 17)
	name.Font = Enum.Font.GothamBold
	name.Parent = button

	local role = label("Role", UDim2.new(1, -16, 0, 18), UDim2.fromOffset(8, 32), 13)
	role.TextColor3 = ACCENT
	role.Text = class.role or ""
	role.Parent = button

	local power = label("Power", UDim2.new(1, -16, 0, 46), UDim2.fromOffset(8, 54), 13)
	power.TextWrapped = true
	power.TextYAlignment = Enum.TextYAlignment.Top
	power.Text = class.power or ""
	power.Parent = button

	-- La faiblesse est aussi lisible que le pouvoir, et en rouge. C'est elle
	-- qu'on bannit, pas le pouvoir : une classe se bannit parce que sa faiblesse
	-- ne la gene pas sur cette map, ou dans cette equipe.
	local weakness = label("Weakness", UDim2.new(1, -16, 0, 40), UDim2.fromOffset(8, 102), 12)
	weakness.TextWrapped = true
	weakness.TextYAlignment = Enum.TextYAlignment.Top
	weakness.TextColor3 = DANGER
	weakness.Text = class.weakness or ""
	weakness.Parent = button

	name.Text = class.name or class.id

	return button
end

--------------------------------------------------------------------------------
-- LES TROIS MOMENTS
--------------------------------------------------------------------------------

local function showBans(payload: any)
	build()
	clearGrid()
	myVote = nil

	local screen = gui
	local area = grid
	if screen == nil or area == nil then
		return
	end

	showGrid(true)

	local mine = payload.mine == true
	deadline = os.clock() + (payload.seconds or 0)

	if header then
		header.Text = if mine then "À VOUS DE BANNIR" else "L'AUTRE ÉQUIPE BANNIT"
		header.TextColor3 = if mine then ACCENT else Color3.fromRGB(240, 244, 255)
	end
	if subheader then
		subheader.Text = if mine
			then "Choisissez la classe à écarter. La plus citée dans l'équipe l'emporte."
			else "Regardez ce qu'ils écartent : c'est une information sur leur jeu."
	end
	if footer then
		footer.Text = if mine
			then "Aucun vote ? Une classe est écartée au hasard, et la partie continue."
			else ""
	end

	for index, class in payload.pool do
		local card = makeCard(class, index, mine)
		card.Parent = area

		if mine then
			card.Activated:Connect(function()
				-- Un seul vote a la fois : revoter remplace, il n'ajoute pas.
				if myVote ~= nil and cards[myVote] ~= nil then
					cards[myVote].BackgroundColor3 = CARD
				end
				myVote = class.id
				card.BackgroundColor3 = CARD_VOTED
				draftRemote:FireServer({ vote = class.id })
			end)
		end

		cards[class.id] = card
	end

	screen.Enabled = true
	fit()
end

local function showBanned(payload: any)
	if subheader then
		subheader.Text = string.format(
			"L'équipe %s écarte %s.",
			tostring(payload.team),
			tostring(payload.name)
		)
	end
	local card = cards[payload.classId]
	if card ~= nil then
		card.BackgroundColor3 = Color3.fromRGB(44, 20, 20)
		local name = card:FindFirstChild("Name")
		if name and name:IsA("TextLabel") then
			name.TextColor3 = DANGER
		end
	end
end

local function showReroll(payload: any)
	build()
	clearGrid()
	showGrid(false)

	local screen = gui
	local free = body
	if screen == nil or free == nil then
		return
	end

	for _, child in free:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	deadline = os.clock() + (payload.seconds or 0)

	if header then
		header.Text = "TA CLASSE EST TIRÉE"
		header.TextColor3 = ACCENT
	end
	if subheader then
		subheader.Text = "Tu peux la relancer une fois — sans la voir."
	end
	if footer then
		-- Dire pourquoi, sinon le joueur croit a une brimade.
		footer.Text = "Le relancement est aveugle exprès : s'il montrait la classe d'abord, "
			.. "ce ne serait plus un pari mais un choix, et tout le monde prendrait la même."
	end

	if bodyTitle then
		bodyTitle.Text = ""
	end
	if bodyNote then
		bodyNote.Text = ""
	end

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(320, 76)
	button.Position = UDim2.new(0.5, 0, 0, 90)
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.BackgroundColor3 = CARD
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 22
	button.TextColor3 = Color3.fromRGB(240, 244, 255)
	button.Text = "Relancer"
	button.Parent = free

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	button.Activated:Connect(function()
		button.Text = "Relancée"
		button.BackgroundColor3 = CARD_VOTED
		button.Active = false
		button.AutoButtonColor = false
		draftRemote:FireServer({ reroll = true })
	end)

	screen.Enabled = true
	fit()
end

local function showClass(payload: any)
	build()
	clearGrid()
	showGrid(false)

	local screen = gui
	local free = body
	if screen == nil or free == nil then
		return
	end

	for _, child in free:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	deadline = os.clock() + (payload.seconds or 0)

	if header then
		header.Text = tostring(payload.name)
		header.TextColor3 = ACCENT
	end
	if subheader then
		subheader.Text = tostring(payload.role or "")
	end

	-- Le pouvoir en grand, la faiblesse juste dessous et en rouge, aussi
	-- lisible. Les deux se lisent ensemble ou pas du tout : une classe dont on
	-- ne connait que le pouvoir se joue mal pendant toute la premiere manche.
	if bodyTitle then
		bodyTitle.Text = tostring(payload.power or "")
	end
	if bodyNote then
		bodyNote.Text = string.format("Faiblesse : %s", tostring(payload.weakness or ""))
	end
	if footer then
		footer.Text = "La manche commence dans un instant."
	end

	screen.Enabled = true
	fit()
end

local function close()
	local screen = gui
	if screen ~= nil then
		screen.Enabled = false
	end
	deadline = 0
	myVote = nil
	clearGrid()
end

--------------------------------------------------------------------------------
-- LE COMPTE A REBOURS
--------------------------------------------------------------------------------

local function onRenderStep()
	local screen = gui
	if screen == nil or not screen.Enabled then
		return
	end

	local left = deadline - os.clock()
	if timerLabel ~= nil then
		timerLabel.Text = if left > 0 then string.format("%d", math.ceil(left)) else ""
		timerLabel.TextColor3 = if left <= 5 then DANGER else ACCENT
	end
end

function DraftPanel.start()
	build()

	draftRemote.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end

		if payload.kind == "bans" then
			showBans(payload)
		elseif payload.kind == "banned" then
			showBanned(payload)
		elseif payload.kind == "reroll" then
			showReroll(payload)
		elseif payload.kind == "class" then
			showClass(payload)
		elseif payload.kind == "close" then
			close()
		end
	end)

	RunService.RenderStepped:Connect(onRenderStep)
end

return DraftPanel
