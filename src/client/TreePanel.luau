--!strict
--[[
	TreePanel — l'interface de l'arbre de competences.

	Le client ne decide rien. Il affiche l'etat que le serveur lui envoie sur le
	RemoteEvent Tree, et renvoie trois intentions : « je choisis cette branche »,
	« je monte d'un palier », « j'ai fini ». Si le serveur refuse, l'etat suivant
	arrive inchange et l'ecran ne bouge pas. Il n'y a donc rien a tricher ici :
	cacher un bouton n'est pas une securite, et ce n'est pas ce que ces boutons
	font.

	CE QUE L'ECRAN DOIT FAIRE COMPRENDRE, dans cet ordre :

	    1. ce que la branche DONNE
	    2. ce qu'elle COUTE — le sacrifice, en rouge, jamais en petit
	    3. ce qu'elle promet au palier 6, et si cette promesse est tenue

	Le sacrifice est la raison d'etre du systeme : une branche sans sacrifice
	n'est qu'une augmentation. Il est donc affiche aussi gros que le bonus.

	Un palier 6 decrit mais pas encore code s'affiche grise et annonce qu'il
	n'est pas en jeu. Mieux vaut une promesse visiblement en attente qu'une
	option qui se vend deux points et ne fait rien.

	LA MISE EN PAGE EST POSEE A LA MAIN, en pixels, et pas empilee par un
	UIListLayout qui devinerait les hauteurs. Premiere version faite comme ca :
	le bouton « Prêt » se dessinait par-dessus les chiffres. La tentative de
	rattrapage avec UIFlexItem a fait pire, en donnant une hauteur nulle aux
	cartes, qui ont purement disparu. Une barre en haut, une barre en bas, et
	tout le reste au milieu : ca se verifie d'un coup d'oeil, et rien ne depend
	de l'ordre dans lequel les textes arrivent.
]]

local TreePanel = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Remotes = Arena:WaitForChild("Remotes")
local treeRemote = Remotes:WaitForChild("Tree") :: RemoteEvent

local Screens = require(script.Parent:WaitForChild("Screens"))

local player = Players.LocalPlayer

--------------------------------------------------------------------------------
-- LES COULEURS ET LES MESURES
--------------------------------------------------------------------------------

local PANEL = Color3.fromRGB(18, 20, 26)
local CARD = Color3.fromRGB(28, 31, 39)
local CARD_CHOSEN = Color3.fromRGB(36, 42, 52)
local TEXT = Color3.fromRGB(236, 238, 244)
local TEXT_DIM = Color3.fromRGB(150, 156, 170)
local TEXT_OFF = Color3.fromRGB(96, 100, 112)
local SACRIFICE = Color3.fromRGB(226, 96, 88)
local GAIN = Color3.fromRGB(120, 210, 140)
local POINTS = Color3.fromRGB(246, 200, 96)
local READY = Color3.fromRGB(120, 210, 140)
local INK = Color3.fromRGB(16, 18, 22)

local PAD = 18
local HEADER_HEIGHT = 36
local SUBHEADER_HEIGHT = 24
local TOP_HEIGHT = HEADER_HEIGHT + SUBHEADER_HEIGHT + 8
local FOOTER_HEIGHT = 42
local HINT_HEIGHT = 20
local BOTTOM_HEIGHT = FOOTER_HEIGHT + HINT_HEIGHT + 8

local TRACK_HEIGHT = 48
local HEAD_HEIGHT = 92
-- Le bloc des chiffres suit le nombre de lignes, entre ces bornes. Une hauteur
-- fixe laisse un grand vide au palier 1, quand la branche n'a change que deux
-- statistiques.
local CHANGES_MIN_HEIGHT = 96
local CHANGES_MAX_HEIGHT = 230
local CHANGES_LINE = 21
local CHOOSE_BUTTON_ROOM = 46

-- Les cartes ont une hauteur FIXE, et la zone defile quand elles n'y tiennent
-- pas. La version precedente leur donnait toute la hauteur disponible, ce qui
-- marche sur un grand ecran et rogne le sacrifice et le palier 6 sur une
-- fenetre courte — autrement dit, ca cachait exactement les deux lignes qui
-- servent a decider.
local CARD_HEIGHT = 196
local STACKED_CARD_HEIGHT = 178

-- Une couleur par question posee par la branche : identite, distance,
-- resilience. Trois problemes differents, donc trois couleurs differentes.
local KIND_COLOR: { [string]: Color3 } = {
	identity = Color3.fromRGB(246, 200, 96),
	range = Color3.fromRGB(110, 170, 240),
	resilience = Color3.fromRGB(120, 210, 140),
}

local KIND_LABEL: { [string]: string } = {
	identity = "IDENTITÉ",
	range = "DISTANCE",
	resilience = "RÉSILIENCE",
}

--------------------------------------------------------------------------------
-- LES BRIQUES
--------------------------------------------------------------------------------

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function padding(parent: Instance, pixels: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, pixels)
	p.PaddingBottom = UDim.new(0, pixels)
	p.PaddingLeft = UDim.new(0, pixels)
	p.PaddingRight = UDim.new(0, pixels)
	p.Parent = parent
end

local function text(
	parent: Instance,
	content: string,
	size: number,
	color: Color3,
	bold: boolean
): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, size + 6)
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	label.TextSize = size
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.Text = content
	label.Parent = parent
	return label
end

-- Un texte dont la hauteur suit son contenu. A n'utiliser QUE dans une pile
-- verticale : ailleurs, une hauteur qui change toute seule deplace ses voisins.
local function flowing(label: TextLabel, minHeight: number, order: number): TextLabel
	label.Size = UDim2.new(1, 0, 0, minHeight)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.LayoutOrder = order
	return label
end

local function button(parent: Instance, content: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.TextColor3 = INK
	b.Text = content
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 6)
	return b
end

local function column(parent: Instance, gap: number): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.Parent = parent
	return layout
end

--------------------------------------------------------------------------------
-- L'ECRAN
--------------------------------------------------------------------------------

local gui: ScreenGui
local panel: Frame
local panelScale: UIScale
local header: TextLabel
local subheader: TextLabel
local cardArea: Frame
local cardLayout: UIListLayout
local footer: Frame
local advanceButton: TextButton
local readyButton: TextButton
local hint: TextLabel

local view: any = nil
-- Ouvert a la main par le joueur, en dehors de la phase de depense. L'ecran est
-- alors en lecture seule : on consulte son arbre, on ne l'achete pas.
local manuallyOpen = false

-- La hauteur pour laquelle le panneau est dessine. En dessous, tout retrecit
-- d'un bloc plutot que de se faire rogner : une fenetre Studio courte, un
-- telephone en paysage et un ecran 1080 doivent montrer les MEMES informations,
-- parce que ce sont elles qui servent a decider.
-- Le panneau est dessine a une taille FIXE, puis mis a l'echelle. Une taille en
-- pourcentage combinee a une echelle retrecirait deux fois, et la correction
-- serait invisible tant qu'on ne teste pas sur deux ecrans differents.
local PANEL_WIDTH = 1180
-- La hauteur du panneau suit son contenu, entre ces deux bornes : un ecran de
-- choix tient en 370 pixels, un arbre deja choisi en demande 545. Une hauteur
-- fixe laisserait soit un grand vide sous les cartes, soit une liste coupee.
local PANEL_MIN_HEIGHT = 300
local PANEL_MAX_HEIGHT = 620

local panelHeight = PANEL_MAX_HEIGHT

local function fitToViewport()
	if gui == nil or panel == nil or panelScale == nil then
		return
	end
	-- La hauteur varie : 370 pixels pour l'ecran de choix, 545 une fois la
	-- branche prise. C'est pour ca qu'elle se passe en argument.
	Screens.fit(gui, panel, panelScale, PANEL_WIDTH, panelHeight)
end

local function isNarrow(): boolean
	if gui == nil then
		return false
	end
	-- En dessous de 700 pixels de large, trois cartes cote a cote font des
	-- colonnes de texte illisibles : on les empile.
	return gui.AbsoluteSize.X < 700
end

local function build(parent: Instance)
	gui = Instance.new("ScreenGui")
	gui.Name = "ArenaTree"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Enabled = false
	gui.Parent = parent

	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.BorderSizePixel = 0
	shade.Parent = gui

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, panelHeight)
	panel.BackgroundColor3 = PANEL
	panel.BorderSizePixel = 0
	-- Rien ne depasse du panneau, jamais : un debordement silencieux est
	-- exactement le defaut qu'on ne voit pas en le codant.
	panel.ClipsDescendants = true
	panel.Parent = gui
	corner(panel, 12)
	padding(panel, PAD)

	panelScale = Instance.new("UIScale")
	panelScale.Parent = panel
	fitToViewport()

	-- On suit la taille du ScreenGui, et pas celle de la camera : la camera du
	-- joueur est remplacee a chaque reapparition, et la connexion mourait avec
	-- elle. Vu le 27 octobre 2026, l'arbre etait le seul panneau a ne plus
	-- suivre la fenetre.
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToViewport)

	header = text(panel, "", 26, TEXT, true)
	header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)

	subheader = text(panel, "", 15, TEXT_DIM, false)
	subheader.Position = UDim2.fromOffset(0, HEADER_HEIGHT + 4)
	subheader.Size = UDim2.new(1, 0, 0, SUBHEADER_HEIGHT)

	-- Tout ce qui tient entre la barre du haut et celle du bas. Ca defile :
	-- aucun ecran n'est garanti assez haut, et une carte a moitie coupee est
	-- pire qu'une carte a faire defiler.
	cardArea = Instance.new("ScrollingFrame")
	cardArea.Name = "Cards"
	cardArea.BackgroundTransparency = 1
	cardArea.BorderSizePixel = 0
	cardArea.Position = UDim2.fromOffset(0, TOP_HEIGHT)
	cardArea.Size = UDim2.new(1, 0, 1, -(TOP_HEIGHT + BOTTOM_HEIGHT))
	cardArea.CanvasSize = UDim2.new()
	cardArea.AutomaticCanvasSize = Enum.AutomaticSize.Y
	cardArea.ScrollBarThickness = 4
	cardArea.ScrollBarImageColor3 = TEXT_DIM
	cardArea.ClipsDescendants = true
	cardArea.Parent = panel

	cardLayout = Instance.new("UIListLayout")
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Padding = UDim.new(0, 10)
	cardLayout.Parent = cardArea

	footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.BackgroundTransparency = 1
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.new(0, 0, 1, -(HINT_HEIGHT + 6))
	footer.Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT)
	footer.Parent = panel

	advanceButton = button(footer, "", POINTS)
	advanceButton.Size = UDim2.new(0.62, -5, 1, 0)

	readyButton = button(footer, "Prêt", READY)
	readyButton.AnchorPoint = Vector2.new(1, 0)
	readyButton.Position = UDim2.fromScale(1, 0)
	readyButton.Size = UDim2.new(0.38, -5, 1, 0)

	hint = text(panel, "", 13, TEXT_DIM, false)
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.fromScale(0, 1)
	hint.Size = UDim2.new(1, 0, 0, HINT_HEIGHT)
	hint.TextXAlignment = Enum.TextXAlignment.Center

	advanceButton.MouseButton1Click:Connect(function()
		treeRemote:FireServer({ action = "advance" })
	end)

	readyButton.MouseButton1Click:Connect(function()
		treeRemote:FireServer({ action = "ready" })
	end)
end

--------------------------------------------------------------------------------
-- LES CARTES DE BRANCHE
--------------------------------------------------------------------------------

-- Une carte de branche. `interactive` dit si on peut encore choisir : hors
-- phase de depense, et une fois la branche verrouillee, la carte se lit mais ne
-- se clique plus.
local function makeCard(branch: any, order: number, interactive: boolean, stacked: boolean): Frame
	local card = Instance.new("Frame")
	card.Name = "Branch_" .. tostring(branch.id)
	card.LayoutOrder = order
	card.BackgroundColor3 = if branch.chosen then CARD_CHOSEN else CARD
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.Size = if stacked
		then UDim2.new(1, 0, 0, STACKED_CARD_HEIGHT)
		else UDim2.new(1 / 3, -7, 0, CARD_HEIGHT)
	corner(card, 10)
	padding(card, 12)

	local accent = KIND_COLOR[branch.kind] or TEXT

	if branch.chosen then
		local stroke = Instance.new("UIStroke")
		stroke.Color = accent
		stroke.Thickness = 2
		stroke.Parent = card
	end

	-- Le bouton est colle en bas de la carte, donc les trois cartes ont leur
	-- bouton a la meme hauteur quelle que soit la longueur des phrases. Trois
	-- boutons en escalier font hesiter pour rien.
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, 0, 1, if interactive then -CHOOSE_BUTTON_ROOM else 0)
	body.ClipsDescendants = true
	body.Parent = card
	column(body, 5)

	flowing(text(body, KIND_LABEL[branch.kind] or "", 11, accent, true), 14, 1)
	flowing(text(body, branch.name or branch.id, 20, TEXT, true), 24, 2)
	flowing(text(body, branch.summary or "", 14, TEXT, false), 18, 3)

	-- Le sacrifice, en rouge et de la meme taille que le bonus. C'est la moitie
	-- de la decision : l'afficher en petit serait mentir par mise en page.
	flowing(text(body, "− " .. (branch.sacrifice or ""), 14, SACRIFICE, false), 18, 4)

	local tier6Text = "Palier 6 : " .. (branch.tier6Label or "")
	if not branch.tier6Available then
		tier6Text ..= "   (pas encore en jeu)"
	end
	local tier6 =
		text(body, tier6Text, 12, if branch.tier6Available then TEXT_DIM else TEXT_OFF, false)
	flowing(tier6, 16, 5)

	if interactive then
		local choose = button(card, "Choisir", accent)
		choose.AnchorPoint = Vector2.new(0, 1)
		choose.Position = UDim2.fromScale(0, 1)
		choose.Size = UDim2.new(1, 0, 0, 38)
		choose.MouseButton1Click:Connect(function()
			treeRemote:FireServer({ action = "choose", branchId = branch.id })
		end)
	end

	return card
end

-- La piste des paliers : un pave par palier, allume jusqu'au palier atteint, et
-- chacun portant son cout. C'est ce qui rend lisible d'un coup d'oeil que le
-- dernier palier coute le double.
local function makeTierTrack(current: any, order: number): Frame
	local track = Instance.new("Frame")
	track.Name = "Tiers"
	track.LayoutOrder = order
	track.BackgroundTransparency = 1
	track.Size = UDim2.new(1, 0, 0, TRACK_HEIGHT)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = track

	for tier = 1, current.tiers do
		local reached = tier <= current.tier
		local cost = current.tierCosts[tier] or 0

		local pip = Instance.new("Frame")
		pip.Name = "Tier" .. tostring(tier)
		pip.LayoutOrder = tier
		pip.Size = UDim2.new(1 / current.tiers, -6, 1, 0)
		pip.BackgroundColor3 = if reached then POINTS else CARD
		pip.BorderSizePixel = 0
		pip.Parent = track
		corner(pip, 6)

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.TextColor3 = if reached then INK else TEXT_DIM
		label.Text = if cost == 0
			then string.format("%d\nofferte", tier)
			else string.format("%d\n%d pt", tier, cost)
		label.Parent = pip
	end

	return track
end

--------------------------------------------------------------------------------
-- LE RENDU
--------------------------------------------------------------------------------

-- La hauteur dont l'ecran a besoin, avant mise a l'echelle. Calculee a partir
-- des memes constantes que la mise en page, pour qu'ajuster une carte ajuste le
-- panneau sans qu'on ait a y penser.
-- La hauteur du bloc des chiffres : le titre, une ligne par statistique
-- changee, la ligne du palier 6, et la marge interieure.
local function changesHeight(current: any): number
	local lines = #current.changes + 2
	return math.clamp(24 + (lines * CHANGES_LINE) + 24, CHANGES_MIN_HEIGHT, CHANGES_MAX_HEIGHT)
end

local function heightFor(current: any, stacked: boolean): number
	local content
	if current.branchId == nil then
		content = if stacked then (STACKED_CARD_HEIGHT * 3) + 20 else CARD_HEIGHT
	else
		content = HEAD_HEIGHT + TRACK_HEIGHT + changesHeight(current) + 20
	end

	local total = TOP_HEIGHT + content + BOTTOM_HEIGHT + (PAD * 2)
	return math.clamp(total, PANEL_MIN_HEIGHT, PANEL_MAX_HEIGHT)
end

local function renderChoice(current: any, interactive: boolean)
	local stacked = isNarrow()
	cardLayout.FillDirection = if stacked
		then Enum.FillDirection.Vertical
		else Enum.FillDirection.Horizontal

	for order, branch in current.branches do
		makeCard(branch, order, interactive, stacked).Parent = cardArea
	end
end

local function renderChosen(current: any)
	cardLayout.FillDirection = Enum.FillDirection.Vertical

	local chosen: any = nil
	for _, branch in current.branches do
		if branch.chosen then
			chosen = branch
		end
	end
	if chosen == nil then
		return
	end

	local accent = KIND_COLOR[chosen.kind] or TEXT

	local head = Instance.new("Frame")
	head.Name = "Chosen"
	head.LayoutOrder = 1
	head.BackgroundColor3 = CARD_CHOSEN
	head.BorderSizePixel = 0
	head.Size = UDim2.new(1, 0, 0, HEAD_HEIGHT)
	head.ClipsDescendants = true
	head.Parent = cardArea
	corner(head, 10)
	padding(head, 12)
	column(head, 4)

	flowing(text(head, chosen.name, 22, accent, true), 26, 1)
	flowing(text(head, chosen.summary or "", 14, TEXT, false), 18, 2)
	flowing(text(head, "− " .. (chosen.sacrifice or ""), 13, SACRIFICE, false), 17, 3)

	makeTierTrack(current, 2).Parent = cardArea

	-- Ce que la branche a reellement change sur les statistiques. Le joueur n'a
	-- pas a croire la promesse : il voit les chiffres. La liste defile, parce
	-- qu'une branche qui touche beaucoup de statistiques doit rester lisible
	-- sur un petit ecran.
	local changes = Instance.new("ScrollingFrame")
	changes.Name = "Numbers"
	changes.LayoutOrder = 3
	changes.BackgroundColor3 = CARD
	changes.BorderSizePixel = 0
	changes.Size = UDim2.new(1, 0, 0, changesHeight(current))
	changes.CanvasSize = UDim2.new()
	changes.AutomaticCanvasSize = Enum.AutomaticSize.Y
	changes.ScrollBarThickness = 4
	changes.ScrollBarImageColor3 = TEXT_DIM
	changes.Parent = cardArea
	corner(changes, 10)
	padding(changes, 12)
	column(changes, 3)

	flowing(text(changes, "CE QUE ÇA DONNE, EN CHIFFRES", 11, TEXT_DIM, true), 14, 1)

	for order, change in current.changes do
		local line = text(changes, change.text, 14, if change.gain then GAIN else SACRIFICE, false)
		flowing(line, 18, order + 1)
	end

	local tier6Line = "Palier 6 — " .. (chosen.tier6Label or "")
	if not chosen.tier6Available then
		tier6Line ..= "  (pas encore en jeu)"
	elseif current.complete then
		tier6Line = "Palier 6 actif — " .. (chosen.tier6Label or "")
	end

	local active = current.complete and chosen.tier6Available
	flowing(text(changes, tier6Line, 13, if active then POINTS else TEXT_DIM, active), 18, 99)
end

local function render()
	local current = view
	if current == nil then
		gui.Enabled = false
		return
	end

	-- `pinned` et pas `open` : dans le bac a sable la depense est ouverte en
	-- permanence, et un ecran plein qui ne se fermerait jamais cacherait tout
	-- le reste.
	local visible = current.pinned == true or manuallyOpen
	gui.Enabled = visible
	if not visible then
		return
	end

	for _, child in cardArea:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local plural = if current.points > 1 then "points" else "point"
	header.Text = string.format("%s  ·  %d %s", current.className, current.points, plural)
	header.TextColor3 = if current.points > 0 then POINTS else TEXT

	if current.open and current.pinned ~= true then
		subheader.Text = "Bac à sable — dépense ouverte en permanence. T pour fermer."
	elseif current.open then
		local seconds = current.seconds
		subheader.Text = if seconds ~= nil
			then string.format("Phase de dépense — %d s avant la manche", math.ceil(seconds))
			else "Phase de dépense"
	elseif current.branchId == nil then
		subheader.Text = "Aucune branche choisie. Le choix s'ouvrira entre deux manches."
	else
		subheader.Text = "Consultation — la dépense s'ouvre entre deux manches."
	end

	-- La hauteur du panneau avant d'y poser quoi que ce soit : les tailles en
	-- pourcentage des enfants se calculent sur elle.
	panelHeight = heightFor(current, isNarrow())
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, panelHeight)
	fitToViewport()

	-- On ne choisit qu'une fois par partie, et seulement pendant la phase.
	local canChoose = current.open and current.branchId == nil

	if current.branchId == nil then
		renderChoice(current, canChoose)
	else
		renderChosen(current)
	end

	footer.Visible = current.open

	-- Pas de bouton de montee quand il n'y a rien a monter : branche pas encore
	-- choisie, ou branche terminee.
	if current.branchId == nil or current.complete then
		advanceButton.Visible = false
	else
		advanceButton.Visible = true
		advanceButton.Active = current.canAdvance
		advanceButton.AutoButtonColor = current.canAdvance
		advanceButton.BackgroundColor3 = if current.canAdvance then POINTS else CARD
		advanceButton.TextColor3 = if current.canAdvance then INK else TEXT_DIM

		local cost = current.nextCost or 0
		local costPlural = if cost > 1 then "points" else "point"
		advanceButton.Text =
			string.format("Monter au palier %d  —  %d %s", current.tier + 1, cost, costPlural)
	end

	readyButton.Text = if current.ready then "En attente…" else "Prêt"
	readyButton.BackgroundColor3 = if current.ready then CARD else READY
	readyButton.TextColor3 = if current.ready then TEXT_DIM else INK

	hint.Text = if current.open
		then "Le choix de branche est définitif pour la partie."
		else "T pour fermer"
end

--------------------------------------------------------------------------------
-- LE BRANCHEMENT
--------------------------------------------------------------------------------

function TreePanel.start()
	local playerGui = player:WaitForChild("PlayerGui")
	build(playerGui)

	treeRemote.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		view = payload
		render()
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode ~= Enum.KeyCode.T then
			return
		end

		-- Pendant la phase de depense, l'ecran ne se ferme pas : la manche
		-- suivante part avec ou sans le choix, et le rater par inadvertance
		-- serait une manche jouee avec une classe nue.
		if view ~= nil and view.pinned == true then
			return
		end

		manuallyOpen = not manuallyOpen
		render()
	end)
end

return TreePanel
