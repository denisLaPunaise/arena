--!strict
--[[
	ProgressPanel — les pieces, la collection, le classement, et les cotes.

	Ouvert par P. Trois choses, du haut vers le bas :

	  - ce qu'on a : pieces, fragments, classement, collection
	  - le bouton d'ouverture d'une caisse, et ce qu'elle vient de donner
	  - LES COTES, toujours visibles sous le bouton

	LES COTES NE SONT PAS UNE OPTION, et leur presentation non plus. La
	politique de Roblox sur les objets aleatoires payants demande que chaque
	resultat possible et sa probabilite soient affiches AVANT l'achat, avec un
	total qui fait exactement 100 %, et que le lien vers ces cotes porte un MOT
	— une icone « (i) » seule est explicitement insuffisante. Ici elles sont
	affichees en permanence sous le bouton, ce qui satisfait l'exigence sans
	avoir besoin d'un lien du tout.

	La garantie du septieme tirage est un modificateur de probabilite : son
	effet est explique chiffre, et les cotes se mettent a jour quand elle est
	active. C'est le serveur qui les calcule, dans Draws.odds ; ce module ne
	fait que les peindre.

	Les Robux ne sont pas encore branches. Quand ils le seront, cet ecran est
	deja conforme et rien n'est a changer ici.
]]

local ProgressPanel = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Remotes = Arena:WaitForChild("Remotes")
local progressRemote = Remotes:WaitForChild("Progress") :: RemoteEvent

local Screens = require(script.Parent:WaitForChild("Screens"))

local player = Players.LocalPlayer

local PANEL_WIDTH = 900
local PANEL_HEIGHT = 640

local BACKGROUND = Color3.fromRGB(12, 14, 20)
local CARD = Color3.fromRGB(26, 30, 40)
local ACCENT = Color3.fromRGB(246, 200, 96)
local GOOD = Color3.fromRGB(120, 220, 150)
local DANGER = Color3.fromRGB(230, 96, 86)
local MUTED = Color3.fromRGB(150, 158, 172)
local TEXT = Color3.fromRGB(240, 244, 255)

local gui: ScreenGui? = nil
local scale: UIScale? = nil
local panelFrame: Frame? = nil
local fit: () -> ()
local wallet: TextLabel? = nil
local collection: TextLabel? = nil
local crateButton: TextButton? = nil
local oddsTitle: TextLabel? = nil
local oddsBody: TextLabel? = nil
local oddsNote: TextLabel? = nil
local flash: TextLabel? = nil

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

local function build()
	if gui ~= nil and gui.Parent ~= nil then
		return
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "ArenaProgress"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 19
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
	panelFrame = frame

	-- La fenetre change de taille, le panneau suit. BRANCHE ICI, et pas
	-- dans start() : le ScreenGui n'existe pas encore quand start() tourne,
	-- donc la connexion n'etait jamais prise et un panneau ouvert avant la
	-- premiere mise a jour du serveur se dessinait a sa taille entiere.
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fit()
	end)

	local title =
		label("Header", UDim2.fromOffset(PANEL_WIDTH - 60, 44), UDim2.fromOffset(30, 22), 32)
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Text = "PROGRESSION"
	title.Parent = frame

	local purse =
		label("Wallet", UDim2.fromOffset(PANEL_WIDTH - 60, 80), UDim2.fromOffset(30, 74), 20)
	purse.Parent = frame

	local owned =
		label("Collection", UDim2.fromOffset(PANEL_WIDTH - 60, 44), UDim2.fromOffset(30, 156), 18)
	owned.TextColor3 = MUTED
	owned.Parent = frame

	local button = Instance.new("TextButton")
	button.Name = "Crate"
	button.Size = UDim2.fromOffset(340, 52)
	button.Position = UDim2.new(0.5, 0, 0, 206)
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.BackgroundColor3 = CARD
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 19
	button.TextColor3 = TEXT
	button.Text = "Ouvrir une caisse"
	button.Parent = frame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 8)
	buttonCorner.Parent = button

	button.Activated:Connect(function()
		progressRemote:FireServer({ openCrate = true })
	end)

	local message =
		label("Flash", UDim2.fromOffset(PANEL_WIDTH - 60, 48), UDim2.fromOffset(30, 266), 19)
	message.Font = Enum.Font.GothamBold
	message.TextXAlignment = Enum.TextXAlignment.Center
	message.Parent = frame

	-- LE MOT, et pas une icone : la politique de Roblox refuse explicitement un
	-- « (i) » seul. Ici c'est un titre, et les cotes sont dessous en permanence.
	local oddsHead =
		label("OddsTitle", UDim2.fromOffset(PANEL_WIDTH - 60, 30), UDim2.fromOffset(30, 322), 19)
	oddsHead.Font = Enum.Font.GothamBold
	oddsHead.TextColor3 = ACCENT
	oddsHead.Text = "Détails des chances"
	oddsHead.Parent = frame

	local body =
		label("OddsBody", UDim2.fromOffset(PANEL_WIDTH - 60, 140), UDim2.fromOffset(30, 356), 18)
	body.Parent = frame

	local note =
		label("OddsNote", UDim2.fromOffset(PANEL_WIDTH - 60, 110), UDim2.fromOffset(30, 500), 15)
	note.TextColor3 = MUTED
	note.Parent = frame

	local hint =
		label("Hint", UDim2.fromOffset(PANEL_WIDTH - 60, 24), UDim2.fromOffset(30, 606), 15)
	hint.TextColor3 = MUTED
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.Text = "P pour fermer"
	hint.Parent = frame

	gui = screen
	scale = uiscale
	wallet = purse
	collection = owned
	crateButton = button
	oddsTitle = oddsHead
	oddsBody = body
	oddsNote = note
	flash = message
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

local function redraw(view: any)
	build()

	local purse = wallet
	if purse ~= nil then
		local lines = {
			string.format(
				"%d pièces  ·  %d fragments  ·  classement %d  ·  %d parties",
				view.coins,
				view.fragments,
				view.rating,
				view.matchesPlayed
			),
			string.format(
				"Une caisse coûte %d pièces. Il en manque %d.",
				view.crateCost,
				math.max(view.crateCost - view.coins, 0)
			),
		}
		if not view.saved then
			-- Honnetete elementaire : si rien n'est sauvegarde, le dire avant
			-- que le joueur ne depense sa soiree a remplir une collection qui
			-- disparaitra en quittant.
			table.insert(lines, "Progression NON sauvegardée sur ce serveur.")
		end
		purse.Text = table.concat(lines, "\n")
		purse.TextColor3 = if view.saved then TEXT else DANGER
	end

	local owned = collection
	if owned ~= nil then
		owned.Text = string.format("Collection : %d objets sur %d", view.owned, view.total)
	end

	local button = crateButton
	if button ~= nil then
		button.Text = if view.cratesAffordable > 0
			then string.format("Ouvrir une caisse  (%d pièces)", view.crateCost)
			else string.format("Ouvrir une caisse  —  %d / %d", view.coins, view.crateCost)
		button.TextColor3 = if view.cratesAffordable > 0 then TEXT else MUTED
	end

	local head = oddsTitle
	if head ~= nil then
		head.Text = if view.odds.guaranteed
			then "Détails des chances  —  garantie active"
			else string.format(
				"Détails des chances  —  garantie dans %d tirages",
				view.odds.pullsUntilGuarantee
			)
	end

	local body = oddsBody
	if body ~= nil then
		local lines = {}
		for _, line in view.odds.lines do
			table.insert(
				lines,
				string.format("%.2f %%   %s\n          %s", line.percent, line.label, line.detail)
			)
		end
		-- Le total s'affiche, et il fait exactement 100 : c'est l'exigence, et
		-- c'est aussi la seule facon pour un joueur de verifier qu'on ne lui
		-- cache pas un resultat.
		table.insert(lines, string.format("Total : %.0f %%", view.odds.total))
		body.Text = table.concat(lines, "\n")
		body.TextColor3 = if view.odds.guaranteed then GOOD else TEXT
	end

	local note = oddsNote
	if note ~= nil then
		note.Text = view.odds.note
	end

	fit()
end

function ProgressPanel.toggle()
	openned = not openned
	if openned then
		progressRemote:FireServer({ open = true })
		if latest ~= nil then
			redraw(latest)
		end
	end
	local screen = gui
	if screen ~= nil then
		screen.Enabled = openned
	end
end

local function say(text: string, color: Color3)
	local message = flash
	if message == nil then
		return
	end
	message.Text = text
	message.TextColor3 = color
end

function ProgressPanel.start()
	build()

	progressRemote.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end

		if payload.kind == "progress" then
			latest = payload
			if openned then
				redraw(payload)
			end
		elseif payload.kind == "drawn" then
			if payload.isNew then
				say(string.format("NOUVEAU : %s", payload.name), GOOD)
			else
				say(
					string.format(
						"%s en double  ·  +%d fragments",
						payload.name,
						payload.fragments
					),
					ACCENT
				)
			end
		elseif payload.kind == "refused" then
			say(tostring(payload.reason), DANGER)
		elseif payload.kind == "match" then
			-- Ce message arrive meme panneau ferme : c'est la recompense de la
			-- partie, et elle ne doit pas attendre qu'on pense a ouvrir un
			-- ecran pour exister.
			say(
				string.format(
					"%+d pièces  ·  classement %d (%+d)",
					payload.coins,
					payload.rating,
					payload.ratingDelta
				),
				if payload.won then GOOD else MUTED
			)
		end
	end)
end

return ProgressPanel
