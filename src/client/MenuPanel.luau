--!strict
--[[
	MenuPanel — l'ecran d'accueil, le premier que le joueur voit.

	CE QU'IL REPARE. Avant lui, arriver dans le jeu voulait dire tomber
	directement dans la file d'une partie classee : aucun moment ou on decide,
	aucune facon de lire son classement avant de jouer, et aucune facon de
	monter un salon entre amis autrement qu'en passant par la fonction de
	serveur prive de Roblox. Maintenant il y a une porte, et elle a trois
	poignees : jouer en classe, creer un salon, rejoindre avec un code.

	LA TOUCHE NE CHANGE JAMAIS L'ETAT. La touche du menu ouvre et ferme
	l'affichage, et c'est tout ; entrer dans la file ou en sortir se fait par un
	bouton, nomme, qui dit ce qu'il fait. C'est la lecon du panneau du salon
	prise a l'envers : la, un refus figeait l'ecran ; ici, le risque serait une
	touche qui vous sort de la file sans le dire. Un etat qui compte ne se
	change pas par une touche qu'on a pu presser par erreur.

	IL NE DECIDE DE RIEN. Les formats, le classement, les pieces, le code du
	salon : tout vient du serveur, et ce panneau ne fait que peindre. Un format
	ajoute a Config.formats apparait donc ici tout seul, comme dans le salon.

	LES STATISTIQUES NE COUTENT AUCUN MESSAGE DE PLUS. Le classement et les
	pieces arrivent deja par le remote de la progression, qui part a chaque
	arrivee et a chaque gain : ce panneau s'y branche en lecture, exactement
	comme le son s'est greffe sur les annonces d'effets. Un remote de plus pour
	afficher un chiffre qu'on a deja serait une erreur.
]]

local MenuPanel = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Remotes = Arena:WaitForChild("Remotes")
local menuRemote = Remotes:WaitForChild("Menu") :: RemoteEvent
local progressRemote = Remotes:WaitForChild("Progress") :: RemoteEvent

local Config = require(Arena:WaitForChild("Config"))
local Screens = require(script.Parent:WaitForChild("Screens"))
local Audio = require(script.Parent:WaitForChild("Audio"))
local Gamepad = require(script.Parent:WaitForChild("Gamepad"))

local player = Players.LocalPlayer

-- La hauteur se DEDUIT de ce qu'il y a dedans, elle ne se recopie pas. C'est
-- la lecon de la colonne du bac a sable, qui debordait de 42 pixels parce
-- qu'une largeur ecrite en dur devait s'accorder avec quatre autres chiffres.
local PANEL_WIDTH = 920
local EDGE = 34
local HEADER_HEIGHT = 118
local STATS_HEIGHT = 74
local GAP = 20
local VIEW_HEIGHT = 280
local FOOTER_HEIGHT = 48
local PANEL_HEIGHT = EDGE
	+ HEADER_HEIGHT
	+ STATS_HEIGHT
	+ GAP
	+ VIEW_HEIGHT
	+ GAP
	+ FOOTER_HEIGHT
	+ EDGE

local INNER = PANEL_WIDTH - (EDGE * 2)
local CARD_GAP = 18
local CARDS = 3
local CARD_WIDTH = math.floor((INNER - (CARD_GAP * (CARDS - 1))) / CARDS)
local STAT_WIDTH = math.floor((INNER - (CARD_GAP * 3)) / 4)

-- Les rangees de reglages du salon a creer, memes proportions que le panneau
-- du salon pour que les deux ecrans se ressemblent.
local ROW_LABEL = 22
local ROW_BUTTON = 40
local ROW_GAP = 14
local ROW_HEIGHT = ROW_LABEL + ROW_BUTTON + ROW_GAP

local ACT_HEIGHT = 46
-- Hauteur de la carte quand elle reste seule (serveur prive) : elle n'a plus
-- qu'une ligne a dire, donc elle se deduit de ce qu'elle porte au lieu de
-- garder la hauteur de trois cartes.
local LONE_HEIGHT = 24 + 56 + 8 + 44 + 18 + ACT_HEIGHT + 22

local BACKGROUND = Color3.fromRGB(12, 14, 20)
local CARD = Color3.fromRGB(26, 30, 40)
local CARD_HOT = Color3.fromRGB(34, 40, 54)
local ACCENT = Color3.fromRGB(246, 200, 96)
local TEXT = Color3.fromRGB(240, 244, 255)
local DARK = Color3.fromRGB(14, 16, 22)
local MUTED = Color3.fromRGB(150, 158, 172)
local WARN = Color3.fromRGB(246, 130, 110)

local gui: ScreenGui? = nil
local scale: UIScale? = nil
-- Hauteur du panneau quand il ne porte qu'une carte : la meme chose moins
-- la vue a trois cartes, plus la carte seule.
local LONE_PANEL_HEIGHT = PANEL_HEIGHT - VIEW_HEIGHT + LONE_HEIGHT
local panelHeight = PANEL_HEIGHT

local panelFrame: Frame? = nil
local fit: () -> ()

local serverLine: TextLabel? = nil
local footerLine: TextLabel? = nil
local paintKeys: () -> ()
local noticeLine: TextLabel? = nil

local homeView: Frame? = nil
local createView: Frame? = nil
local joinView: Frame? = nil

local playCard: Frame? = nil
local createCard: Frame? = nil
local joinCard: Frame? = nil
local playTitle: TextLabel? = nil
local playBody: TextLabel? = nil
local playButton: TextButton? = nil
local createButton: TextButton? = nil

local formatRow: Frame? = nil
local teamRow: Frame? = nil
local classRow: Frame? = nil

local ratingValue: TextLabel? = nil
local coinsValue: TextLabel? = nil
local fragmentsValue: TextLabel? = nil
local collectionValue: TextLabel? = nil

-- Ce que le serveur a dit en dernier, et ce que ce client a choisi sans encore
-- l'envoyer. Les reglages d'un salon a creer n'existent que sur ce client
-- jusqu'au bouton « Creer » : ils ne concernent personne d'autre, puisque le
-- salon n'existe pas encore.
local latest: any = nil
local profile: any = nil
local wanted = { formatId = "auto", teamMode = "chosen", classMode = "drawn" }

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
	made.TextXAlignment = Enum.TextXAlignment.Left
	made.TextYAlignment = Enum.TextYAlignment.Top
	made.TextWrapped = true
	made.Text = ""
	return made
end

local function rounded(object: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = object
end

local function button(
	name: string,
	text: string,
	size: UDim2,
	position: UDim2,
	primary: boolean
): TextButton
	local made = Instance.new("TextButton")
	Audio.clicks(made)
	made.Name = name
	made.Size = size
	made.Position = position
	made.BackgroundColor3 = if primary then ACCENT else CARD_HOT
	made.BorderSizePixel = 0
	made.AutoButtonColor = true
	made.Font = Enum.Font.GothamBold
	made.TextSize = 17
	made.TextColor3 = if primary then DARK else TEXT
	made.Text = text
	rounded(made, 8)
	return made
end

-- Une rangee de choix exclusifs. La largeur de chaque bouton se calcule a
-- partir de leur nombre : la liste des formats vient du serveur et peut
-- changer, donc un chiffre ecrit en dur ici serait faux un jour.
local function row(name: string, top: number, parent: Instance): Frame
	local made = Instance.new("Frame")
	made.Name = name
	made.Size = UDim2.fromOffset(INNER, ROW_BUTTON)
	made.Position = UDim2.fromOffset(0, top)
	made.BackgroundTransparency = 1
	made.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = made

	return made
end

local function fill(
	into: Frame?,
	choices: { { id: string, text: string } },
	current: string,
	pick: (string) -> ()
)
	local parent = into
	if parent == nil then
		return
	end

	for _, child in parent:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local gaps = 10 * math.max(#choices - 1, 0)
	local width = math.floor((INNER - gaps) / math.max(#choices, 1))

	for index, option in choices do
		local picked = option.id == current
		local made = Instance.new("TextButton")
		Audio.clicks(made)
		made.Name = option.id
		made.LayoutOrder = index
		made.Size = UDim2.fromOffset(width, ROW_BUTTON)
		-- UN ACCENT DEPENSE PARTOUT NE DESIGNE PLUS RIEN. Les trois rangees
		-- remplissaient leur choix en jaune plein, et le bouton « creer le
		-- salon » est jaune lui aussi : quatre pavés de la même couleur, donc
		-- l'oeil ne trouvait plus l'action. Un choix retenu se marque par son
		-- CONTOUR et son texte, le plein reste au seul bouton qui agit. Meme
		-- arbitrage que la rambarde de la Carriere, ou le jaune n'a survecu
		-- que sur les quatre rampes.
		made.BackgroundColor3 = if picked then CARD_HOT else CARD
		made.BorderSizePixel = 0
		made.Font = Enum.Font.GothamBold
		made.TextSize = 16
		made.TextColor3 = if picked then ACCENT else MUTED
		made.Text = option.text
		rounded(made, 8)
		if picked then
			local edge = Instance.new("UIStroke")
			-- UN UIStroke SUR UN TextButton CERNE LE TEXTE, PAS LE CADRE. Son
			-- mode vaut `Contextual` par defaut, et sur un bouton le contexte
			-- est la police : les trois libelles retenus sont sortis baveux et
			-- illisibles. Ca ne leve rien et ca ne se voit qu'a l'ecran.
			edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			edge.Color = ACCENT
			edge.Thickness = 2
			edge.Parent = made
		end
		made.Parent = parent
		made.Activated:Connect(function()
			pick(option.id)
		end)
	end
end

local function rowTitle(name: string, text: string, top: number, parent: Instance)
	local made = label(name, UDim2.fromOffset(INNER, ROW_LABEL), UDim2.fromOffset(0, top), 15)
	made.TextColor3 = MUTED
	made.Text = text
	made.Parent = parent
end

-- Une carte d'action : un titre, son explication, un bouton en bas. Le bouton
-- est colle au BAS de la carte et pas sous le texte : trois cartes dont les
-- boutons ne sont pas alignes se lisent comme un defaut d'affichage.
local function card(
	name: string,
	order: number,
	parent: Instance
): (Frame, TextLabel, TextLabel, TextButton)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.LayoutOrder = order
	frame.Size = UDim2.fromOffset(CARD_WIDTH, VIEW_HEIGHT)
	frame.BackgroundColor3 = CARD
	frame.BorderSizePixel = 0
	frame.Parent = parent
	rounded(frame, 12)

	local title = label("Title", UDim2.new(1, -44, 0, 56), UDim2.fromOffset(22, 24), 22)
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	local body = label("Body", UDim2.new(1, -44, 0, 132), UDim2.fromOffset(22, 84), 15)
	body.TextColor3 = MUTED
	body.Parent = frame

	local act = button(
		"Act",
		"",
		UDim2.new(1, -44, 0, ACT_HEIGHT),
		UDim2.new(0, 22, 1, -ACT_HEIGHT - 22),
		false
	)
	act.Parent = frame

	return frame, title, body, act
end

local function stat(caption: string, order: number, parent: Instance): TextLabel
	local frame = Instance.new("Frame")
	frame.Name = order .. caption
	frame.LayoutOrder = order
	frame.Size = UDim2.fromOffset(STAT_WIDTH, STATS_HEIGHT)
	frame.BackgroundColor3 = CARD
	frame.BorderSizePixel = 0
	frame.Parent = parent
	rounded(frame, 10)

	local head =
		label("Caption", UDim2.fromOffset(STAT_WIDTH - 28, 18), UDim2.fromOffset(14, 12), 13)
	head.TextColor3 = MUTED
	head.Text = caption
	head.Parent = frame

	local value =
		label("Value", UDim2.fromOffset(STAT_WIDTH - 28, 34), UDim2.fromOffset(14, 32), 24)
	value.Font = Enum.Font.GothamBold
	value.Text = "—"
	value.Parent = frame

	return value
end

--------------------------------------------------------------------------------
-- LES TROIS VUES
--------------------------------------------------------------------------------

local function showView(which: string)
	local home = homeView
	local create = createView
	local join = joinView
	if home ~= nil then
		home.Visible = which == "home"
	end
	if create ~= nil then
		create.Visible = which == "create"
	end
	if join ~= nil then
		join.Visible = which == "join"
	end
end

local function send(payload: any)
	menuRemote:FireServer(payload)
end

local function buildHome(top: number, parent: Instance)
	local holder = Instance.new("Frame")
	holder.Name = "Home"
	holder.Size = UDim2.fromOffset(INNER, VIEW_HEIGHT)
	holder.Position = UDim2.fromOffset(EDGE, top)
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	homeView = holder

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, CARD_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder

	local oneFrame, oneTitle, oneBody, oneAct = card("Ranked", 1, holder)
	playCard = oneFrame
	playTitle = oneTitle
	playBody = oneBody
	playButton = oneAct
	oneAct.Activated:Connect(function()
		send({ ready = latest == nil or latest.ready ~= true })
	end)

	local two, twoTitle, twoBody, twoAct = card("Create", 2, holder)
	twoTitle.Text = "CRÉER UN SALON"
	twoBody.Text = "Entre amis, dans ton propre serveur. Tu choisis le format, la façon "
		.. "de composer les camps et celle dont les classes arrivent. Le jeu te donne "
		.. "un code à partager."
	twoAct.Text = "RÉGLER ET CRÉER"
	twoAct.Activated:Connect(function()
		showView("create")
	end)
	createCard = two

	local three, threeTitle, threeBody, threeAct = card("Join", 3, holder)
	threeTitle.Text = "REJOINDRE"
	threeBody.Text = "Quelqu'un t'a donné un code ? Tape-le et tu arrives directement "
		.. "dans son salon."
	threeAct.Text = "ENTRER UN CODE"
	threeAct.Activated:Connect(function()
		showView("join")
	end)
	joinCard = three
end

local function buildCreate(top: number, parent: Instance)
	local holder = Instance.new("Frame")
	holder.Name = "Create"
	holder.Size = UDim2.fromOffset(INNER, VIEW_HEIGHT)
	holder.Position = UDim2.fromOffset(EDGE, top)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = parent
	createView = holder

	local at = 0
	rowTitle("FormatLabel", "FORMAT", at, holder)
	formatRow = row("FormatRow", at + ROW_LABEL, holder)
	at += ROW_HEIGHT

	rowTitle("TeamLabel", "ÉQUIPES", at, holder)
	teamRow = row("TeamRow", at + ROW_LABEL, holder)
	at += ROW_HEIGHT

	rowTitle("ClassLabel", "CLASSES", at, holder)
	classRow = row("ClassRow", at + ROW_LABEL, holder)

	local back = button(
		"Back",
		"← Retour",
		UDim2.fromOffset(170, ACT_HEIGHT),
		UDim2.fromOffset(0, VIEW_HEIGHT - ACT_HEIGHT),
		false
	)
	back.Parent = holder
	back.Activated:Connect(function()
		showView("home")
	end)

	local go = button(
		"Go",
		"CRÉER LE SALON",
		UDim2.fromOffset(INNER - 180, ACT_HEIGHT),
		UDim2.fromOffset(180, VIEW_HEIGHT - ACT_HEIGHT),
		true
	)
	go.Parent = holder
	go.Activated:Connect(function()
		-- UNE RESERVATION PREND UNE SECONDE OU DEUX, et pendant ce temps-la
		-- rien ne bouge a l'ecran : un bouton qui garde son libelle invite a
		-- cliquer une deuxieme fois, donc a reserver deux serveurs. Le refus
		-- ou la reussite redonnent son nom au bouton.
		go.Text = "RÉSERVATION…"
		send({ create = wanted })
	end)
	createButton = go
end

local function buildJoin(top: number, parent: Instance)
	local holder = Instance.new("Frame")
	holder.Name = "Join"
	holder.Size = UDim2.fromOffset(INNER, VIEW_HEIGHT)
	holder.Position = UDim2.fromOffset(EDGE, top)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = parent
	joinView = holder

	local note = label("Note", UDim2.fromOffset(INNER, 46), UDim2.fromOffset(0, 6), 17)
	note.TextColor3 = MUTED
	note.Text = "Le code du salon, tel qu'on te l'a donné. Les minuscules, les espaces et "
		.. "les tirets n'ont pas d'importance."
	note.Parent = holder

	local box = Instance.new("TextBox")
	box.Name = "Code"
	box.Size = UDim2.fromOffset(INNER, 92)
	box.Position = UDim2.fromOffset(0, 66)
	box.BackgroundColor3 = CARD
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.GothamBold
	box.TextSize = 54
	box.TextColor3 = ACCENT
	box.PlaceholderText = "CODE"
	box.PlaceholderColor3 = Color3.fromRGB(70, 76, 90)
	box.Text = ""
	rounded(box, 12)
	box.Parent = holder

	-- ON LE MET EN MAJUSCULES SOUS LES DOIGTS. Le code s'ecrit en capitales
	-- partout ailleurs, et un champ qui l'affiche en minuscules fait croire
	-- qu'on s'est trompe. Le serveur nettoie de son cote de toute facon : ici
	-- c'est pour l'oeil, pas pour la validite.
	box:GetPropertyChangedSignal("Text"):Connect(function()
		local up = string.upper(box.Text)
		if up ~= box.Text then
			box.Text = up
		end
	end)

	local back = button(
		"Back",
		"← Retour",
		UDim2.fromOffset(170, ACT_HEIGHT),
		UDim2.fromOffset(0, VIEW_HEIGHT - ACT_HEIGHT),
		false
	)
	back.Parent = holder
	back.Activated:Connect(function()
		showView("home")
	end)

	local go = button(
		"Go",
		"REJOINDRE",
		UDim2.fromOffset(INNER - 180, ACT_HEIGHT),
		UDim2.fromOffset(180, VIEW_HEIGHT - ACT_HEIGHT),
		true
	)
	go.Parent = holder
	go.Activated:Connect(function()
		send({ join = box.Text })
	end)
end

local function build()
	if gui ~= nil and gui.Parent ~= nil then
		return
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "ArenaMenu"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	-- AU-DESSUS DE TOUT LE RESTE. C'est le seul panneau qui s'ouvre tout seul,
	-- donc le seul qui puisse se faire recouvrir par un autre sans que
	-- personne l'ait demande.
	screen.DisplayOrder = 24
	screen.Enabled = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.25
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
	rounded(frame, 16)

	local uiscale = Instance.new("UIScale")
	uiscale.Parent = frame

	gui = screen
	scale = uiscale
	panelFrame = frame

	-- BRANCHE ICI, et pas dans start() : le ScreenGui n'existe pas encore
	-- quand start() tourne, donc la connexion serait sautee en silence et le
	-- panneau garderait son echelle d'origine.
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fit()
	end)

	local title = label("Title", UDim2.fromOffset(INNER, 52), UDim2.fromOffset(EDGE, 24), 44)
	title.Font = Enum.Font.GothamBlack
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Text = "ARÈNE"
	title.Parent = frame

	local tag = label("Tagline", UDim2.fromOffset(INNER, 24), UDim2.fromOffset(EDGE, 76), 15)
	tag.TextXAlignment = Enum.TextXAlignment.Center
	tag.TextColor3 = MUTED
	tag.Text = "Deux camps, une classe tirée au sort, un arbre qui repart de zéro chaque partie."
	tag.Parent = frame

	local where = label("Server", UDim2.fromOffset(INNER, 22), UDim2.fromOffset(EDGE, 100), 14)
	where.TextXAlignment = Enum.TextXAlignment.Center
	where.TextColor3 = ACCENT
	where.Parent = frame
	serverLine = where

	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.Size = UDim2.fromOffset(INNER, STATS_HEIGHT)
	stats.Position = UDim2.fromOffset(EDGE, EDGE + HEADER_HEIGHT)
	stats.BackgroundTransparency = 1
	stats.Parent = frame

	local statsLayout = Instance.new("UIListLayout")
	statsLayout.FillDirection = Enum.FillDirection.Horizontal
	statsLayout.Padding = UDim.new(0, CARD_GAP)
	statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statsLayout.Parent = stats

	ratingValue = stat("CLASSEMENT", 1, stats)
	coinsValue = stat("PIÈCES", 2, stats)
	fragmentsValue = stat("FRAGMENTS", 3, stats)
	collectionValue = stat("COLLECTION", 4, stats)

	local viewTop = EDGE + HEADER_HEIGHT + STATS_HEIGHT + GAP
	buildHome(viewTop, frame)
	buildCreate(viewTop, frame)
	buildJoin(viewTop, frame)

	-- Le pied s'accroche au BAS du panneau : pose a un chiffre absolu il ne
	-- pouvait pas suivre un panneau qui change de hauteur.
	local footUp = EDGE + FOOTER_HEIGHT
	local said = label("Notice", UDim2.fromOffset(INNER, 22), UDim2.new(0, EDGE, 1, -footUp), 15)
	said.TextXAlignment = Enum.TextXAlignment.Center
	said.TextColor3 = WARN
	said.Parent = frame
	noticeLine = said

	local keys = label("Keys", UDim2.fromOffset(INNER, 22), UDim2.new(0, EDGE, 1, -footUp + 24), 14)
	keys.TextXAlignment = Enum.TextXAlignment.Center
	keys.TextColor3 = MUTED
	keys.Parent = frame
	footerLine = keys
end

function fit()
	local current = scale
	local screen = gui
	local frame = panelFrame
	if current == nil or screen == nil or frame == nil then
		return
	end
	Screens.fit(screen, frame, current, PANEL_WIDTH, panelHeight)
end

--------------------------------------------------------------------------------
-- LA PEINTURE
--------------------------------------------------------------------------------

-- LE PIED DIT CE QU'ON A DANS LES MAINS : les touches au clavier, les
-- boutons a la manette. Il se repeint a chaque bascule, pas seulement quand
-- le serveur parle. Les touches viennent de Config ; la touche du menu, du
-- serveur, qui l'envoie avec l'etat.
function paintKeys()
	local keys = footerLine
	if keys == nil then
		return
	end
	local pad = Config.gamepad
	local reopen = if latest ~= nil then latest.reopenKey else nil
	keys.Text = string.format(
		"%s pour revenir ici  ·  %s arbre  ·  %s équipement  ·  %s pièces",
		Gamepad.key(Config, reopen or Config.menu.reopenKey, pad.menu),
		Gamepad.key(Config, Config.skillTree.panelKey, pad.tree),
		Gamepad.key(Config, Config.loadout.editKey, pad.loadout),
		Gamepad.key(Config, Config.economy.panelKey, pad.progress)
	)
end

local function redraw()
	build()

	local state = latest
	if state == nil then
		return
	end

	local where = serverLine
	if where ~= nil then
		if state.code ~= nil and state.code ~= "" then
			where.Text = string.format(
				"Salon privé  ·  code %s  ·  partage-le pour qu'on te rejoigne",
				state.code
			)
		elseif state.private then
			where.Text = "Serveur privé  ·  rien n'y compte : aucune pièce, aucun classement"
		else
			where.Text = "Serveur public  ·  les parties classées comptent"
		end
	end

	-- LA CARTE DU CLASSE CHANGE DE ROLE selon qu'on est dans la file ou non.
	-- Un bouton « Jouer » qui reste « Jouer » alors qu'on y est deja ne dit
	-- rien de l'etat, et on appuie dessus pour voir.
	local act = playButton
	local body = playBody
	local head = playTitle
	if act ~= nil and body ~= nil and head ~= nil then
		if state.ready then
			head.Text = "TU ES DANS LA FILE"
			body.Text = string.format(
				"%s\n\nQuitter la file ne t'enlève pas de la partie en cours : ça prend "
					.. "effet à la prochaine.",
				if (state.present or 0) <= 1
					then "Il n'y a personne d'autre sur ce serveur pour l'instant."
					else string.format("%d joueurs sont sur ce serveur.", state.present)
			)
			act.Text = "QUITTER LA FILE"
			act.BackgroundColor3 = CARD_HOT
			act.TextColor3 = TEXT
		elseif state.private then
			head.Text = "LANCER LA PARTIE"
			body.Text = "Ce serveur est privé : rien n'y compte, et c'est fait pour ça. "
				.. "Les réglages se changent en jeu avec la touche du salon."
			act.Text = "JOUER"
			act.BackgroundColor3 = ACCENT
			act.TextColor3 = DARK
		else
			head.Text = "JOUER EN CLASSÉ"
			body.Text = "La file publique. Les équipes se composent toutes seules, les "
				.. "classes se tirent au sort après les bans, et le résultat compte : "
				.. "classement et pièces."
			act.Text = "JOUER"
			act.BackgroundColor3 = ACCENT
			act.TextColor3 = DARK
		end
	end

	local formats: { { id: string, text: string } } = {}
	for _, id in state.formats or {} do
		table.insert(formats, { id = id, text = if id == "auto" then "auto" else id })
	end
	fill(formatRow, formats, wanted.formatId, function(id)
		wanted.formatId = id
		redraw()
	end)

	fill(
		teamRow,
		{
			{ id = "chosen", text = "chacun choisit son camp" },
			{ id = "random", text = "camps au hasard" },
		},
		wanted.teamMode,
		function(mode)
			wanted.teamMode = mode
			redraw()
		end
	)

	fill(
		classRow,
		{
			{ id = "drawn", text = "classes tirées au sort" },
			{ id = "picked", text = "chacun choisit sa classe" },
		},
		wanted.classMode,
		function(mode)
			wanted.classMode = mode
			redraw()
		end
	)

	-- CREER ET REJOINDRE N'EXISTENT PAS DANS UN SALON : on y est deja, et
	-- creer depuis la enverrait l'hote ailleurs en laissant ses amis derriere
	-- lui. Les cartes partent plutot que de refuser au clic — un bouton qui
	-- ne sert a rien se lit comme un bug.
	local two = createCard
	local three = joinCard
	if two ~= nil then
		two.Visible = not state.private
	end
	if three ~= nil then
		three.Visible = not state.private
	end

	-- Et elle prend toute la largeur quand elle reste seule : ses enfants sont
	-- dimensionnes en fraction d'elle, donc il n'y a qu'un chiffre a poser.
	local alone = playCard
	if alone ~= nil then
		alone.Size = if state.private
			then UDim2.fromOffset(INNER, LONE_HEIGHT)
			else UDim2.fromOffset(CARD_WIDTH, VIEW_HEIGHT)
	end

	-- ET LE PANNEAU SUIT SA CARTE. Rendre la carte compacte sans toucher au
	-- panneau n'a fait que remonter le vide d'un etage.
	local wantedHeight = if state.private then LONE_PANEL_HEIGHT else PANEL_HEIGHT
	if wantedHeight ~= panelHeight then
		panelHeight = wantedHeight
		local shell = panelFrame
		if shell ~= nil then
			shell.Size = UDim2.fromOffset(PANEL_WIDTH, panelHeight)
		end
		fit()
	end

	local said = noticeLine
	if said ~= nil then
		said.Text = state.notice or ""
	end

	-- Le bouton de creation retrouve son nom des que le serveur a reparle,
	-- qu'il ait accepte ou refuse : sinon il resterait sur « Reservation… »
	-- pour toujours apres un refus.
	local go = createButton
	if go ~= nil then
		go.Text = "CRÉER LE SALON"
	end

	paintKeys()

	local mine = profile
	if mine ~= nil then
		local rating = ratingValue
		local coins = coinsValue
		local fragments = fragmentsValue
		local collection = collectionValue
		if rating ~= nil then
			rating.Text = tostring(mine.rating)
		end
		if coins ~= nil then
			coins.Text = tostring(mine.coins)
		end
		if fragments ~= nil then
			fragments.Text = tostring(mine.fragments)
		end
		if collection ~= nil then
			collection.Text = string.format("%d / %d", mine.owned or 0, mine.total or 0)
		end
	end

	fit()
end

--------------------------------------------------------------------------------

local function show(on: boolean)
	openned = on
	local screen = gui
	if screen ~= nil then
		screen.Enabled = on
	end
	if on then
		redraw()
	end
end

function MenuPanel.toggle()
	build()
	if latest == nil then
		-- Pas encore de reponse du serveur. On redemande, et on ne s'ouvre pas
		-- sur un ecran vide.
		send({ query = true })
		return
	end
	if latest.enabled ~= true then
		-- Coupe dans Config : la touche ne fait alors rien du tout, et l'ecran
		-- reste dans l'etat le plus sur, qui est ferme.
		show(false)
		return
	end
	show(not openned)
end

function MenuPanel.isOpen(): boolean
	return openned
end

function MenuPanel.start()
	build()
	showView("home")
	Gamepad.onChanged(function()
		paintKeys()
	end)

	menuRemote.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" or payload.kind ~= "menu" then
			return
		end

		local first = latest == nil
		local wasReady = latest ~= nil and latest.ready == true
		latest = payload

		if payload.enabled ~= true then
			show(false)
			return
		end

		-- LE MENU S'OUVRE TOUT SEUL A L'ARRIVEE, et c'est tout son interet :
		-- un menu qu'il faut savoir ouvrir n'est pas un accueil. Il ne
		-- s'ouvre que la PREMIERE fois, et seulement si on n'est pas deja
		-- dans la file, pour qu'un rafraichissement ne le remette pas a
		-- l'ecran au milieu d'une manche.
		if first then
			if payload.ready ~= true then
				showView("home")
				show(true)
			end
			return
		end

		-- ENTRER DANS LA FILE FERME LE MENU, en sortir le rouvre. Le panneau
		-- suit l'etat au lieu de le deviner : c'est le serveur qui dit qui est
		-- dans la file, et lui seul.
		if payload.ready == true and not wasReady then
			show(false)
			return
		end
		if payload.ready ~= true and wasReady then
			showView("home")
			show(true)
			return
		end

		if openned then
			redraw()
		end
	end)

	-- Les chiffres du profil arrivent par le remote de la progression, qui
	-- part deja a chaque arrivee : aucun message de plus pour les afficher.
	progressRemote.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" or payload.kind ~= "progress" then
			return
		end
		profile = payload
		if openned then
			redraw()
		end
	end)

	send({ query = true })
end

return MenuPanel
