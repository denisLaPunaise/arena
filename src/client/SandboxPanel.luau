--!strict
--[[
	SandboxPanel — le panneau du bac a sable, sur la touche B.

	Trois colonnes, et pas une de plus : ma classe, le mannequin, les actions.
	C'est l'ecran d'un atelier, pas d'un jeu — il n'a pas a etre beau, il a a
	etre lisible d'un coup d'oeil et cliquable sans reflechir, parce qu'on y
	revient toutes les trente secondes.

	LA MISE EN PAGE EST EN PIXELS, mise a l'echelle par un UIScale, pour la meme
	raison que LoadoutPanel : les dispositions souples de Roblox donnent des
	hauteurs nulles des qu'on les imbrique, et ce sont les lignes du bas qui
	disparaissent.

	CE MODULE N'A AUCUNE AUTORITE, et c'est important ici plus qu'ailleurs,
	puisqu'il demande des choses interdites en partie. Il envoie « donne-moi un
	point » et « mets-moi le Spectre » ; le serveur verifie que ce joueur est
	bien la session en cours du bac a sable, et un client bricole en pleine
	partie classee n'obtient rien.

	La liste des classes vient du SERVEUR, jamais d'ici : un panneau qui porte
	sa propre liste finit par afficher une classe qui n'existe plus.
]]

local SandboxPanel = {}

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Remotes = Arena:WaitForChild("Remotes")
local sandboxRemote = Remotes:WaitForChild("Sandbox") :: RemoteEvent

local Config = require(Arena:WaitForChild("Config"))

local player = Players.LocalPlayer

local MIN_SCALE = 0.4
local MARGIN = 0.94

local PADDING = 20
local HEADER_HEIGHT = 86
local FOOTER_HEIGHT = 34

-- Deux colonnes de sept, parce que quatorze classes ne tiennent pas en une
-- seule hauteur d'ecran lisible.
local CLASS_COLUMNS = 2
local CLASS_ROWS = 7
local CLASS_BUTTON_WIDTH = 178
local CLASS_BUTTON_HEIGHT = 40
local CLASS_GAP = 6

local COLUMN_GAP = 16
local GRID_WIDTH = CLASS_COLUMNS * CLASS_BUTTON_WIDTH + (CLASS_COLUMNS - 1) * CLASS_GAP
local PLATE_WIDTH = GRID_WIDTH + 2 * PADDING
local ACTIONS_WIDTH = 236

-- Ou commence chaque colonne, et la rangee du nombre de mannequins.
local DUMMY_X = PADDING + PLATE_WIDTH + COLUMN_GAP
local ACTIONS_X = DUMMY_X + PLATE_WIDTH + COLUMN_GAP
local COUNT_ROW_Y = 70
local COUNT_ROW_HEIGHT = 34
local GRID_Y_MINE = 76
local GRID_Y_DUMMY = 118
local ACTION_HEIGHT = 40
local ACTION_STEP = 46
local ACTIONS_TOP = 48
local HINT_HEIGHT = 170

-- LA TAILLE DU PANNEAU SE DEDUIT DE SON CONTENU, elle ne s'ecrit pas a la
-- main. Un chiffre ecrit en dur qui doit s'accorder avec quatre autres finit
-- toujours par ne plus s'accorder : la colonne des actions debordait de
-- 42 pixels le 26 octobre 2026, et rien dans le code ne pouvait le dire.
local PANEL_WIDTH = ACTIONS_X + ACTIONS_WIDTH + PADDING

local GRID_HEIGHT = CLASS_ROWS * CLASS_BUTTON_HEIGHT + (CLASS_ROWS - 1) * CLASS_GAP
local BODY_HEIGHT = math.max(
	GRID_Y_MINE + GRID_HEIGHT,
	GRID_Y_DUMMY + GRID_HEIGHT,
	ACTIONS_TOP + 4 * ACTION_STEP + 12 + HINT_HEIGHT
) + PADDING
local PANEL_HEIGHT = HEADER_HEIGHT + BODY_HEIGHT + FOOTER_HEIGHT + PADDING

local BACKGROUND = Color3.fromRGB(12, 14, 20)
local PLATE = Color3.fromRGB(20, 23, 31)
local BUTTON = Color3.fromRGB(32, 37, 49)
local BUTTON_ON = Color3.fromRGB(28, 54, 42)
local ACCENT = Color3.fromRGB(246, 200, 96)
local GOOD = Color3.fromRGB(120, 220, 150)
local MUTED = Color3.fromRGB(150, 158, 172)
local TEXT = Color3.fromRGB(240, 244, 255)

local gui: ScreenGui? = nil
local panelFrame: Frame? = nil
local scale: UIScale? = nil
local opened = false

-- Ce que le serveur a envoye la derniere fois. Nil tant que rien n'est arrive,
-- ce qui veut dire que le bac a sable n'est pas ouvert pour nous.
local latest: any = nil

local header: TextLabel? = nil
local subheader: TextLabel? = nil
local footer: TextLabel? = nil
local mineButtons: { [string]: TextButton } = {}
local dummyButtons: { [string]: TextButton } = {}
local countButtons: { [number]: TextButton } = {}
local zoneButton: TextButton? = nil

--------------------------------------------------------------------------------
-- LES BRIQUES
--------------------------------------------------------------------------------

local function rounded(instance: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

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
	made.Text = ""
	return made
end

local function plate(name: string, size: UDim2, position: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = PLATE
	frame.BorderSizePixel = 0
	rounded(frame, 10)
	return frame
end

local function button(name: string, size: UDim2, position: UDim2, text: string): TextButton
	local made = Instance.new("TextButton")
	made.Name = name
	made.Size = size
	made.Position = position
	made.BackgroundColor3 = BUTTON
	made.BorderSizePixel = 0
	made.AutoButtonColor = true
	made.Font = Enum.Font.GothamMedium
	made.TextColor3 = TEXT
	made.TextSize = 15
	made.Text = text
	rounded(made, 8)
	return made
end

local function ask(payload: any)
	sandboxRemote:FireServer(payload)
end

--------------------------------------------------------------------------------
-- L'ECRAN
--------------------------------------------------------------------------------

-- Une colonne de quatorze classes, en deux colonnes de sept. Renvoie la table
-- des boutons par identifiant, pour que le rafraichissement puisse les
-- recolorier sans les reconstruire.
local function buildClassGrid(
	parent: Frame,
	atY: number,
	classes: { any },
	onPick: (string) -> ()
): { [string]: TextButton }
	local buttons: { [string]: TextButton } = {}

	for index, class in classes do
		local column = (index - 1) % CLASS_COLUMNS
		local row = math.floor((index - 1) / CLASS_COLUMNS)
		if row >= CLASS_ROWS then
			break
		end

		local made = button(
			class.id,
			UDim2.fromOffset(CLASS_BUTTON_WIDTH, CLASS_BUTTON_HEIGHT),
			UDim2.fromOffset(
				column * (CLASS_BUTTON_WIDTH + CLASS_GAP),
				atY + row * (CLASS_BUTTON_HEIGHT + CLASS_GAP)
			),
			class.name
		)
		made.Parent = parent
		made.Activated:Connect(function()
			onPick(class.id)
		end)
		buttons[class.id] = made
	end

	return buttons
end

local function build(view: any)
	if gui ~= nil and gui.Parent ~= nil then
		return
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "ArenaSandbox"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 12
	screen.Enabled = false
	screen.Parent = player:WaitForChild("PlayerGui")
	gui = screen

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = BACKGROUND
	panel.BorderSizePixel = 0
	rounded(panel, 14)
	panel.Parent = screen

	panelFrame = panel

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = panel
	scale = uiScale

	header = label(
		"Header",
		UDim2.fromOffset(PANEL_WIDTH - 2 * PADDING, 34),
		UDim2.fromOffset(PADDING, PADDING),
		26
	)
	local madeHeader = header :: TextLabel
	madeHeader.Font = Enum.Font.GothamBold
	madeHeader.TextColor3 = ACCENT
	madeHeader.Text = "BAC À SABLE"
	madeHeader.Parent = panel

	subheader = label(
		"Sub",
		UDim2.fromOffset(PANEL_WIDTH - 2 * PADDING, 36),
		UDim2.fromOffset(PADDING, PADDING + 32),
		14
	)
	local madeSub = subheader :: TextLabel
	madeSub.TextColor3 = MUTED
	madeSub.TextWrapped = true
	madeSub.Parent = panel

	local bodyY = HEADER_HEIGHT
	local bodyHeight = BODY_HEIGHT

	-- COLONNE 1 : ma classe.
	local mine =
		plate("Mine", UDim2.fromOffset(PLATE_WIDTH, bodyHeight), UDim2.fromOffset(PADDING, bodyY))
	mine.Parent = panel

	local mineTitle =
		label("Title", UDim2.fromOffset(GRID_WIDTH, 22), UDim2.fromOffset(PADDING, 14), 15)
	mineTitle.Font = Enum.Font.GothamBold
	mineTitle.Text = "TA CLASSE"
	mineTitle.Parent = mine

	local mineNote =
		label("Note", UDim2.fromOffset(GRID_WIDTH, 32), UDim2.fromOffset(PADDING, 36), 12)
	mineNote.TextColor3 = MUTED
	mineNote.TextWrapped = true
	mineNote.Text = "Changer de classe remet l'arbre à zéro, comme en partie."
	mineNote.Parent = mine

	local mineInner = Instance.new("Frame")
	mineInner.Name = "Grid"
	mineInner.Size = UDim2.fromOffset(GRID_WIDTH, bodyHeight - GRID_Y_MINE)
	mineInner.Position = UDim2.fromOffset(PADDING, GRID_Y_MINE)
	mineInner.BackgroundTransparency = 1
	mineInner.Parent = mine
	mineButtons = buildClassGrid(mineInner, 0, view.classes, function(classId)
		ask({ what = "class", classId = classId })
	end)

	-- COLONNE 2 : le mannequin.
	local dummy =
		plate("Dummy", UDim2.fromOffset(PLATE_WIDTH, bodyHeight), UDim2.fromOffset(DUMMY_X, bodyY))
	dummy.Parent = panel

	local dummyTitle =
		label("Title", UDim2.fromOffset(GRID_WIDTH, 22), UDim2.fromOffset(PADDING, 14), 15)
	dummyTitle.Font = Enum.Font.GothamBold
	dummyTitle.Text = "LE MANNEQUIN"
	dummyTitle.Parent = dummy

	local dummyNote =
		label("Note", UDim2.fromOffset(GRID_WIDTH, 32), UDim2.fromOffset(PADDING, 36), 12)
	dummyNote.TextColor3 = MUTED
	dummyNote.TextWrapped = true
	dummyNote.Text = "Une cible, pas un adversaire : il encaisse, il ne rend rien."
	dummyNote.Parent = dummy

	-- La rangee du nombre, avant la grille : c'est le reglage qu'on touche le
	-- plus souvent.
	local countRow = Instance.new("Frame")
	countRow.Name = "Count"
	countRow.Size = UDim2.fromOffset(GRID_WIDTH, COUNT_ROW_HEIGHT)
	countRow.Position = UDim2.fromOffset(PADDING, COUNT_ROW_Y)
	countRow.BackgroundTransparency = 1
	countRow.Parent = dummy

	local countWidth = math.floor((GRID_WIDTH - view.dummyMax * CLASS_GAP) / (view.dummyMax + 1))
	countButtons = {}
	for count = 0, view.dummyMax do
		local made = button(
			tostring(count),
			UDim2.fromOffset(countWidth, COUNT_ROW_HEIGHT),
			UDim2.fromOffset(count * (countWidth + CLASS_GAP), 0),
			tostring(count)
		)
		made.Parent = countRow
		made.Activated:Connect(function()
			ask({ what = "dummies", count = count })
		end)
		countButtons[count] = made
	end

	local dummyInner = Instance.new("Frame")
	dummyInner.Name = "Grid"
	dummyInner.Size = UDim2.fromOffset(GRID_WIDTH, bodyHeight - GRID_Y_DUMMY)
	dummyInner.Position = UDim2.fromOffset(PADDING, GRID_Y_DUMMY)
	dummyInner.BackgroundTransparency = 1
	dummyInner.Parent = dummy
	dummyButtons = buildClassGrid(dummyInner, 0, view.classes, function(classId)
		ask({ what = "dummyClass", classId = classId })
	end)

	-- COLONNE 3 : les actions.
	local actions = plate(
		"Actions",
		UDim2.fromOffset(ACTIONS_WIDTH, bodyHeight),
		UDim2.fromOffset(ACTIONS_X, bodyY)
	)
	actions.Parent = panel

	local actionsTitle = label(
		"Title",
		UDim2.fromOffset(ACTIONS_WIDTH - 2 * PADDING, 22),
		UDim2.fromOffset(PADDING, 14),
		15
	)
	actionsTitle.Font = Enum.Font.GothamBold
	actionsTitle.Text = "ACTIONS"
	actionsTitle.Parent = actions

	local actionWidth = ACTIONS_WIDTH - 2 * PADDING
	local rows = {
		{ text = "+1 point d'arbre", payload = { what = "points" } },
		{ text = "Soigner à fond", payload = { what = "heal" } },
		{ text = "Réapparaître", payload = { what = "respawn" } },
	}
	for index, row in rows do
		local made = button(
			"Action" .. index,
			UDim2.fromOffset(actionWidth, ACTION_HEIGHT),
			UDim2.fromOffset(PADDING, ACTIONS_TOP + (index - 1) * ACTION_STEP),
			row.text
		)
		made.Parent = actions
		made.Activated:Connect(function()
			ask(row.payload)
		end)
	end

	local made = button(
		"Zone",
		UDim2.fromOffset(actionWidth, ACTION_HEIGHT),
		UDim2.fromOffset(PADDING, ACTIONS_TOP + #rows * ACTION_STEP),
		"Zone"
	)
	made.Parent = actions
	made.Activated:Connect(function()
		local current = latest
		ask({ what = "zone", on = not (current ~= nil and current.zoneOn == true) })
	end)
	zoneButton = made

	local hint = label(
		"Hint",
		UDim2.fromOffset(actionWidth, HINT_HEIGHT),
		UDim2.fromOffset(PADDING, ACTIONS_TOP + (#rows + 1) * ACTION_STEP + 12),
		12
	)
	hint.TextColor3 = MUTED
	hint.TextWrapped = true
	hint.TextYAlignment = Enum.TextYAlignment.Top
	hint.Text = string.format(
		"T pour l'arbre, L pour l'équipement — les deux restent ouverts ici, même en pleine action.\n\nLe budget est relevé à %d points : c'est pour comparer deux armes dans la même minute, pas un équilibrage.",
		Config.sandbox.budgetPoints
	)
	hint.Parent = actions

	footer = label(
		"Footer",
		UDim2.fromOffset(PANEL_WIDTH - 2 * PADDING, 24),
		UDim2.fromOffset(PADDING, PANEL_HEIGHT - FOOTER_HEIGHT),
		13
	)
	local madeFooter = footer :: TextLabel
	madeFooter.TextColor3 = MUTED
	madeFooter.Parent = panel
end

-- Met le panneau a l'echelle de la fenetre, ET LE RECENTRE.
--
-- LE RECENTRAGE N'EST PAS DECORATIF. Avec `IgnoreGuiInset = true`, l'espace du
-- ScreenGui ne commence pas a zero : il commence a MOINS la hauteur de la barre
-- du haut, tandis que sa taille reste celle de la fenetre entiere. Un
-- `Position = fromScale(0.5, 0.5)` tombe donc trop haut de la moitie de cet
-- encart. Mesure le 26 octobre 2026 dans Studio : encart de 58 px, panneau
-- centre a 135 au lieu de 193, et le titre sortait de l'ecran.
--
-- On rajoute donc l'encart. Les quatre autres panneaux du jeu derivent
-- exactement de la meme facon, et de la meme quantite.
local function fit()
	local screen = gui
	local madeScale = scale
	local panel = panelFrame
	if screen == nil or madeScale == nil or panel == nil then
		return
	end
	local size = screen.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end

	local factor = math.min(size.X / PANEL_WIDTH, size.Y / PANEL_HEIGHT) * MARGIN
	madeScale.Scale = math.max(math.min(factor, 1), MIN_SCALE)
	panel.Position = UDim2.new(0.5, 0, 0.5, GuiService:GetGuiInset().Y)
end

local function paint()
	local view = latest
	if view == nil then
		return
	end

	for classId, made in mineButtons do
		local on = classId == view.classId
		made.BackgroundColor3 = if on then BUTTON_ON else BUTTON
		made.TextColor3 = if on then GOOD else TEXT
	end
	for classId, made in dummyButtons do
		local on = classId == view.dummyClassId
		made.BackgroundColor3 = if on then BUTTON_ON else BUTTON
		made.TextColor3 = if on then GOOD else TEXT
	end
	for count, made in countButtons do
		local on = count == view.dummyCount
		made.BackgroundColor3 = if on then BUTTON_ON else BUTTON
		made.TextColor3 = if on then GOOD else TEXT
	end

	local madeZone = zoneButton
	if madeZone ~= nil then
		madeZone.Text = if view.zoneOn then "Zone : allumée" else "Zone : coupée"
		madeZone.BackgroundColor3 = if view.zoneOn then BUTTON_ON else BUTTON
		madeZone.TextColor3 = if view.zoneOn then GOOD else TEXT
	end

	local madeSub = subheader
	if madeSub ~= nil then
		madeSub.Text =
			"Il ne s'ouvre que seul en jeu, en partie privée. Rien de ce qui se décide ici ne compte : aucune pièce, aucun classement, et l'arbre repart à zéro."
	end

	local madeFooter = footer
	if madeFooter ~= nil then
		local line = string.format(
			"%d point(s) d'arbre à dépenser  ·  palier %d / %d",
			view.points or 0,
			view.tier or 0,
			Config.skillTree.tiers
		)
		if view.notice ~= nil and view.notice ~= "" then
			line = string.format("%s  ·  %s", view.notice, line)
		end
		madeFooter.Text = line
	end
end

--------------------------------------------------------------------------------
-- L'API
--------------------------------------------------------------------------------

function SandboxPanel.isOpen(): boolean
	return opened
end

function SandboxPanel.toggle()
	-- Rien n'est arrive du serveur : le bac a sable n'est pas ouvert pour nous,
	-- et il vaut mieux le dire que de montrer un ecran vide.
	if latest == nil then
		opened = false
		local screen = gui
		if screen ~= nil then
			screen.Enabled = false
		end
		return
	end

	build(latest)
	local screen = gui
	if screen == nil then
		return
	end

	opened = not opened
	screen.Enabled = opened
	if opened then
		fit()
		paint()
		ask({ what = "state" })
	end
end

function SandboxPanel.start()
	sandboxRemote.OnClientEvent:Connect(function(view: any)
		if typeof(view) ~= "table" or view.kind ~= "sandbox" then
			return
		end

		if view.running ~= true then
			-- La session s'est fermee : un deuxieme joueur est arrive, et le
			-- panneau n'a plus rien a piloter.
			latest = nil
			opened = false
			local screen = gui
			if screen ~= nil then
				screen.Enabled = false
			end
			return
		end

		latest = view
		if opened then
			build(view)
			paint()
		end
	end)

	-- La fenetre change de taille, le panneau suit. Sans ca, un ecran de
	-- telephone n'affiche qu'un quart du panneau.
	task.spawn(function()
		while true do
			task.wait(1)
			if opened then
				fit()
			end
		end
	end)
end

return SandboxPanel
