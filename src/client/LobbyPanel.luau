--!strict
--[[
	LobbyPanel — le salon de partie privee.

	Ouvert par la touche de `Config.seating.lobbyKey`, et UNIQUEMENT en partie
	privee : le serveur dit s'il est permis, et sans sa permission ce panneau
	refuse de s'ouvrir. En partie classee, personne ne choisit ni son format ni
	son camp — deux amis qui empileraient un cote feraient payer l'addition au
	classement de tous les autres.

	DEUX REGLAGES, ET DEUX SEULEMENT :

	    Format    auto, 1v1, 2v2, 3v3, 4v4
	    Equipes   chacun choisit  |  au hasard

	Les regles du jeu — la zone, l'agonie, l'arbre, les bans — ne sont PAS
	reglables ici, et c'est une decision de Josh du 27 octobre 2026 : « le jeu
	reste le jeu, on doit pas pouvoir le modifier ». Leurs interrupteurs
	existent, mais ils restent cote developpeur, dans Config.

	CE PANNEAU NE DECIDE RIEN. Il envoie des intentions et il peint ce que le
	serveur renvoie — y compris la liste des formats, qu'il ne connait pas
	lui-meme. Un format ajoute a Config.formats apparait donc ici tout seul.

	N'IMPORTE QUI PEUT REGLER, et le changement s'annonce a tout le monde. Pas
	de « chef de partie » : entre amis dans leur propre serveur, un systeme
	d'hote serait de la complexite pour rien.
]]

local LobbyPanel = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Remotes = Arena:WaitForChild("Remotes")
local lobbyRemote = Remotes:WaitForChild("Lobby") :: RemoteEvent

local Screens = require(script.Parent:WaitForChild("Screens"))
local Audio = require(script.Parent:WaitForChild("Audio"))

local player = Players.LocalPlayer

-- La hauteur se DEDUIT des rangees, elle ne se recopie pas : une rangee
-- ajoutee et un chiffre oublie, et la derniere ligne sort de la carte. C'est
-- la lecon de la colonne du bac a sable, qui debordait de 42 pixels.
local PANEL_WIDTH = 760
local EDGE = 30
local HEADER_HEIGHT = 96
local ROW_LABEL = 26
local ROW_BUTTON = 44
local ROW_GAP = 22
local ROWS = 3
local FOOTER_HEIGHT = 56
local PANEL_HEIGHT = HEADER_HEIGHT
	+ (ROWS * (ROW_LABEL + ROW_BUTTON + ROW_GAP))
	+ FOOTER_HEIGHT
	+ EDGE

local BACKGROUND = Color3.fromRGB(12, 14, 20)
local CARD = Color3.fromRGB(26, 30, 40)
local PICKED = Color3.fromRGB(246, 200, 96)
local TEXT = Color3.fromRGB(240, 244, 255)
local DARK = Color3.fromRGB(14, 16, 22)
local MUTED = Color3.fromRGB(150, 158, 172)

local gui: ScreenGui? = nil
local scale: UIScale? = nil
local panelFrame: Frame? = nil
local fit: () -> ()

local formatRow: Frame? = nil
local teamRow: Frame? = nil
local sideRow: Frame? = nil
local sideLabel: TextLabel? = nil
local footer: TextLabel? = nil

local latest: any = nil
local openned = false

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

-- Une rangee de boutons cote a cote. La largeur de chacun se calcule a partir
-- du nombre de choix : un chiffre ecrit en dur ici devrait s'accorder avec la
-- liste des formats, qui vient du serveur et peut changer.
local function row(name: string, top: number, parent: Instance): Frame
	local made = Instance.new("Frame")
	made.Name = name
	made.Size = UDim2.fromOffset(PANEL_WIDTH - (EDGE * 2), ROW_BUTTON)
	made.Position = UDim2.fromOffset(EDGE, top)
	made.BackgroundTransparency = 1
	made.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = made

	return made
end

local function choice(text: string, width: number, picked: boolean, order: number): TextButton
	local button = Instance.new("TextButton")
	Audio.clicks(button)
	button.Name = text
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(width, ROW_BUTTON)
	button.BackgroundColor3 = if picked then PICKED else CARD
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 18
	button.TextColor3 = if picked then DARK else TEXT
	button.Text = text

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	return button
end

local function build()
	if gui ~= nil and gui.Parent ~= nil then
		return
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "ArenaLobby"
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

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame

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

	local title = label(
		"Header",
		UDim2.fromOffset(PANEL_WIDTH - (EDGE * 2), 40),
		UDim2.fromOffset(EDGE, 22),
		30
	)
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Text = "SALON"
	title.Parent = frame

	local note = label(
		"Note",
		UDim2.fromOffset(PANEL_WIDTH - (EDGE * 2), 26),
		UDim2.fromOffset(EDGE, 62),
		15
	)
	note.TextXAlignment = Enum.TextXAlignment.Center
	note.TextColor3 = MUTED
	note.Text =
		"Partie privée. Le format et les équipes se règlent ici ; les règles du jeu, non."
	note.Parent = frame

	local top = HEADER_HEIGHT

	local formatTitle = label(
		"FormatLabel",
		UDim2.fromOffset(PANEL_WIDTH - (EDGE * 2), ROW_LABEL),
		UDim2.fromOffset(EDGE, top),
		17
	)
	formatTitle.TextColor3 = MUTED
	formatTitle.Text = "FORMAT"
	formatTitle.Parent = frame
	formatRow = row("FormatRow", top + ROW_LABEL, frame)
	top += ROW_LABEL + ROW_BUTTON + ROW_GAP

	local teamTitle = label(
		"TeamLabel",
		UDim2.fromOffset(PANEL_WIDTH - (EDGE * 2), ROW_LABEL),
		UDim2.fromOffset(EDGE, top),
		17
	)
	teamTitle.TextColor3 = MUTED
	teamTitle.Text = "ÉQUIPES"
	teamTitle.Parent = frame
	teamRow = row("TeamRow", top + ROW_LABEL, frame)
	top += ROW_LABEL + ROW_BUTTON + ROW_GAP

	local mine = label(
		"SideLabel",
		UDim2.fromOffset(PANEL_WIDTH - (EDGE * 2), ROW_LABEL),
		UDim2.fromOffset(EDGE, top),
		17
	)
	mine.TextColor3 = MUTED
	mine.Text = "TON CAMP"
	mine.Parent = frame
	sideLabel = mine
	sideRow = row("SideRow", top + ROW_LABEL, frame)
	top += ROW_LABEL + ROW_BUTTON + ROW_GAP

	local tail = label(
		"Footer",
		UDim2.fromOffset(PANEL_WIDTH - (EDGE * 2), FOOTER_HEIGHT),
		UDim2.fromOffset(EDGE, top),
		16
	)
	tail.TextXAlignment = Enum.TextXAlignment.Center
	tail.TextColor3 = MUTED
	tail.Parent = frame
	footer = tail
end

function fit()
	local current = scale
	local screen = gui
	local frame = panelFrame
	if current == nil or screen == nil or frame == nil then
		return
	end
	Screens.fit(screen, frame, current, PANEL_WIDTH, PANEL_HEIGHT)
end

local function fill(
	into: Frame?,
	choices: { { id: string, text: string } },
	current: string,
	send: (string) -> ()
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

	-- La largeur se partage : la rangee des formats en a cinq, celle des camps
	-- trois, et aucune ne doit deborder.
	local gaps = 10 * math.max(#choices - 1, 0)
	local width = math.floor(((PANEL_WIDTH - (EDGE * 2)) - gaps) / math.max(#choices, 1))

	for index, option in choices do
		local button = choice(option.text, width, option.id == current, index)
		button.Parent = parent
		button.Activated:Connect(function()
			send(option.id)
		end)
	end
end

local function redraw(view: any)
	build()

	local formats: { { id: string, text: string } } = {}
	for _, id in view.formats do
		table.insert(formats, { id = id, text = if id == "auto" then "auto" else id })
	end
	fill(formatRow, formats, view.formatId, function(id)
		lobbyRemote:FireServer({ formatId = id })
	end)

	fill(
		teamRow,
		{
			{ id = "chosen", text = "chacun choisit" },
			{ id = "random", text = "au hasard" },
		},
		view.teamMode,
		function(mode)
			lobbyRemote:FireServer({ teamMode = mode })
		end
	)

	-- Le camp n'a aucun sens quand les equipes sont tirees au sort : la rangee
	-- disparait plutot que de rester la sans effet. Un bouton qui ne fait rien
	-- se lit comme un bug.
	local chosen = view.teamMode == "chosen"
	local mine = sideLabel
	if mine ~= nil then
		mine.Visible = chosen
	end
	local row3 = sideRow
	if row3 ~= nil then
		row3.Visible = chosen
	end

	if chosen then
		fill(
			sideRow,
			{
				{ id = "auto", text = "peu importe" },
				{ id = "A", text = "équipe A" },
				{ id = "B", text = "équipe B" },
			},
			view.side,
			function(side)
				lobbyRemote:FireServer({ side = side, clearSide = true })
			end
		)
	end

	local tail = footer
	if tail ~= nil then
		local needed = view.needed or 0
		local present = view.present or 0
		-- « 1 joueurs » se lit comme une panne d'affichage, et c'est le cas qu'on
		-- voit le plus : celui qui ouvre le salon le premier est tout seul.
		local who = if present == 1 then "1 joueur" else string.format("%d joueurs", present)
		if present >= needed then
			tail.Text = string.format("%s présent(s). La partie peut partir.", who)
		else
			tail.Text = string.format("%s sur les %d que ce format demande.", who, needed)
		end
	end

	fit()
end

-- Le panneau ne s'ouvre QUE si le serveur a dit que le salon est permis. En
-- partie classee, la touche ne fait donc rien du tout — comme celle du bac a
-- sable.
-- Un panneau que le serveur vient d'interdire se FERME, il ne se fige pas.
-- Vu en jeu le 27 octobre 2026 : la touche refusait de rouvrir, donc elle
-- refusait aussi de fermer, et le panneau restait a l'ecran pour toujours. Un
-- refus doit toujours laisser l'ecran dans l'etat le plus sur, qui est ferme.
local function shut()
	openned = false
	local screen = gui
	if screen ~= nil then
		screen.Enabled = false
	end
end

function LobbyPanel.toggle()
	if latest == nil or latest.allowed ~= true then
		-- Interdit, ou pas encore de reponse. On redemande et on ne s'ouvre
		-- pas : en partie classee cette touche ne doit rien faire du tout.
		shut()
		lobbyRemote:FireServer({ query = true })
		return
	end

	openned = not openned
	if openned then
		lobbyRemote:FireServer({ open = true })
		redraw(latest)
	else
		lobbyRemote:FireServer({ close = true })
	end

	local screen = gui
	if screen ~= nil then
		screen.Enabled = openned
	end
end

-- QUI PEUT SAVOIR QUE LA TOUCHE EXISTE. Seul le serveur sait si le salon est
-- permis, et il le dit apres que le HUD soit dessine : la ligne des touches ne
-- peut donc pas s'ecrire une fois pour toutes. Elle s'abonne ici plutot que
-- d'aller lire `Venue` cote client, qui n'y a pas acces.
--
-- Annoncer la touche en partie classee serait pire que de la taire : elle ne
-- fait rien du tout, et on chercherait pourquoi.
local told: boolean? = nil
local watchers: { (boolean) -> () } = {}

function LobbyPanel.onAllowed(watcher: (boolean) -> ())
	table.insert(watchers, watcher)
	if told ~= nil then
		watcher(told)
	end
end

function LobbyPanel.start()
	build()

	lobbyRemote.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" or payload.kind ~= "lobby" then
			return
		end

		latest = payload
		if openned then
			redraw(payload)
		end

		local allowed = payload.allowed == true
		if not allowed then
			shut()
		end
		if told ~= allowed then
			told = allowed
			for _, watcher in watchers do
				watcher(allowed)
			end
		end
	end)

	-- On demande l'etat une fois au demarrage : sans ca, la premiere pression
	-- sur la touche ne ferait que le demander, et il faudrait appuyer deux
	-- fois pour ouvrir le panneau.
	lobbyRemote:FireServer({ query = true })
end

return LobbyPanel
