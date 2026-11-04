--!strict
--[[
	Gamepad — jouer a la manette, panneaux compris.

	Demande par Josh le 4 novembre 2026 : il ne joue qu'a la manette. Les
	boutons sont dans `Config.gamepad` ; ce module ne fait que trois choses.

	1. SAVOIR SI ON JOUE A LA MANETTE, d'apres la DERNIERE entree recue. Un
	   joueur qui branche une manette sans la toucher joue encore au clavier,
	   et l'affichage doit parler de ce qu'il a dans les mains.

	2. DONNER LA MAIN AUX PANNEAUX. Un panneau se pilote a la souris ; a la
	   manette, il faut qu'un bouton soit SELECTIONNE pour que la croix et le
	   stick naviguent et que A valide. Sans ca, un panneau ouvert a la manette
	   est un mur : on le voit, on ne peut rien y faire. Ce module donne donc la
	   selection au panneau du dessus des qu'il s'ouvre, et la retire quand il
	   se ferme — sinon le stick continue de naviguer dans un ecran disparu et
	   le personnage ne bouge plus.

	   LES PANNEAUX SE RECONSTRUISENT A CHAQUE MESSAGE DU SERVEUR, l'arbre
	   compris, qui en recoit un par seconde pendant la phase de depense. Le
	   bouton selectionne est alors detruit, et une selection qui repartirait
	   du premier bouton ferait sauter le curseur en haut de l'ecran chaque
	   seconde. On retient donc le CHEMIN du bouton (noms et rangs depuis le
	   panneau) et on le retrouve dans la version reconstruite.

	3. FERMER AVEC B le panneau du dessus, comme partout sur console. Le choix
	   de classe ne se ferme pas : c'est un choix, pas un ecran de consultation.

	Aucun message reseau : la manette ne change que la facon de presser.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Gamepad = {}

type Panel = {
	close: (() -> ())?,
}

-- Les panneaux qu'on pilote, par le nom de leur ScreenGui. `close` nil veut
-- dire que B ne le ferme pas.
local panels: { [string]: Panel } = {}
-- Les ScreenGui des panneaux, dans l'ordre ou ils se sont OUVERTS : le dernier
-- ouvert est celui du dessus.
local opened: { ScreenGui } = {}
-- Le chemin du dernier bouton selectionne, et dans quel panneau.
local lastPath: { string }? = nil
local lastScreen: ScreenGui? = nil
-- Quand le panneau du dessus s'est ouvert : voir `settle`.
local openedAt = 0
-- Le dernier bouton que le joueur (ou nous) avons choisi, et quand il a pousse
-- la croix ou le stick pour la derniere fois : voir `settle`.
local lastSelected: GuiObject? = nil
local navigatedAt = 0
local NAVIGATION_SECONDS = 0.3

local padListeners: { (boolean) -> () } = {}
local padNow = false

local function isPadInput(kind: Enum.UserInputType): boolean
	return string.sub(kind.Name, 1, 7) == "Gamepad"
end

-- UN BOUTON DE MANETTE SE RECONNAIT A SON NOM, PAS SEULEMENT A SON ORIGINE.
-- Vu le 4 novembre 2026 : l'outil de test de Studio envoie « ButtonL1 » avec
-- une origine `Keyboard`, et un jeu qui ne regardait que l'origine ne voyait
-- jamais la manette. Aucun clavier ne produit ces noms, donc les deux
-- criteres ensemble ne se trompent jamais.
function Gamepad.isPadCode(code: Enum.KeyCode): boolean
	local name = code.Name
	return string.sub(name, 1, 6) == "Button"
		or string.sub(name, 1, 4) == "DPad"
		or string.sub(name, 1, 10) == "Thumbstick"
end

local function isPad(input: InputObject): boolean
	return isPadInput(input.UserInputType) or Gamepad.isPadCode(input.KeyCode)
end

function Gamepad.active(): boolean
	return padNow
end

-- Appele a chaque bascule clavier <-> manette, et une fois tout de suite.
function Gamepad.onChanged(listener: (boolean) -> ())
	table.insert(padListeners, listener)
	listener(padNow)
end

-- Ce qu'on affiche pour un bouton (« RT », « Croix haut »).
function Gamepad.label(config: any, button: string): string
	return config.gamepad.labels[button] or button
end

-- La touche OU le bouton, selon ce qu'on a dans les mains.
function Gamepad.key(config: any, keyName: string, button: string): string
	if padNow then
		return Gamepad.label(config, button)
	end
	return keyName
end

local function keyCode(name: string): Enum.KeyCode?
	local ok, value = pcall(function()
		return (Enum.KeyCode :: any)[name]
	end)
	if ok then
		return value
	end
	return nil
end

-- Le nom d'un bouton de Config en `KeyCode`. Un nom faux PREVIENT au lieu de
-- donner un bouton mort en silence.
function Gamepad.code(name: string): Enum.KeyCode?
	local code = keyCode(name)
	if code == nil then
		warn(string.format("[Arena] Manette : « %s » n'est pas un bouton de Roblox.", name))
	end
	return code
end

--------------------------------------------------------------------------------
-- LA SELECTION DANS LES PANNEAUX
--------------------------------------------------------------------------------

local function topPanel(): ScreenGui?
	for index = #opened, 1, -1 do
		local screen = opened[index]
		if screen.Parent ~= nil and screen.Enabled then
			return screen
		end
	end
	return nil
end

local function insideOpenPanel(object: GuiObject): ScreenGui?
	local screen = object:FindFirstAncestorOfClass("ScreenGui")
	if screen ~= nil and screen.Enabled and panels[screen.Name] ~= nil then
		return screen
	end
	return nil
end

-- Un objet est utilisable s'il est visible jusqu'a son panneau, ET dessine :
-- un bouton tout juste cree n'a pas encore de taille, et Roblox refuse alors de
-- le selectionner en le disant dans la console (« Setting
-- GuiService.SelectedObject to invalid GuiObject »), vu le 4 novembre 2026.
local function shown(object: GuiObject, screen: ScreenGui): boolean
	if object.AbsoluteSize.X <= 0 or object.AbsoluteSize.Y <= 0 then
		return false
	end
	local current: Instance? = object
	while current ~= nil and current ~= screen do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		current = current.Parent
	end
	return current == screen
end

-- LE CHEMIN : pour chaque etage, le nom et le rang parmi les freres du meme
-- nom. Les panneaux recreent leurs boutons dans le meme ordre, donc le meme
-- chemin designe le meme bouton apres une reconstruction.
local function pathOf(object: Instance, screen: ScreenGui): { string }
	local path = {}
	local current = object
	while current ~= screen and current.Parent ~= nil do
		local parent = current.Parent :: Instance
		local rank = 0
		for _, sibling in parent:GetChildren() do
			if sibling.Name == current.Name then
				rank += 1
			end
			if sibling == current then
				break
			end
		end
		table.insert(path, 1, string.format("%s#%d", current.Name, rank))
		current = parent
	end
	return path
end

local function follow(screen: ScreenGui, path: { string }): GuiObject?
	local current: Instance = screen
	for _, step in path do
		local name, rankText = string.match(step, "^(.*)#(%d+)$")
		if name == nil or rankText == nil then
			return nil
		end
		local wanted = tonumber(rankText) :: number
		local rank = 0
		local found: Instance? = nil
		for _, child in current:GetChildren() do
			if child.Name == name then
				rank += 1
				if rank == wanted then
					found = child
					break
				end
			end
		end
		if found == nil then
			return nil
		end
		current = found
	end
	if current:IsA("GuiObject") and current.Selectable and shown(current, screen) then
		return current
	end
	return nil
end

-- Le premier bouton visible, en lisant de haut en bas puis de gauche a droite.
-- `GuiService:Select` existe, mais il prend le premier ENFANT, qui n'est pas
-- forcement le premier qu'on voit.
local function firstButton(screen: ScreenGui): GuiObject?
	local best: GuiObject? = nil
	for _, object in screen:GetDescendants() do
		if object:IsA("GuiButton") and object.Selectable and shown(object, screen) then
			local position = object.AbsolutePosition
			local size = object.AbsoluteSize
			if size.X > 0 and size.Y > 0 then
				local current = best
				if current == nil then
					best = object
				else
					local other = current.AbsolutePosition
					if
						position.Y < other.Y - 4
						or (math.abs(position.Y - other.Y) <= 4 and position.X < other.X)
					then
						best = object
					end
				end
			end
		end
	end
	return best
end

local function settle()
	if not padNow then
		return
	end
	local selected = GuiService.SelectedObject
	local top = topPanel()

	if top == nil then
		-- Plus aucun panneau : on rend le stick au personnage.
		if selected ~= nil and selected:FindFirstAncestorOfClass("ScreenGui") ~= nil then
			local screen = selected:FindFirstAncestorOfClass("ScreenGui") :: ScreenGui
			if panels[screen.Name] ~= nil then
				GuiService.SelectedObject = nil
			end
		end
		return
	end

	-- UN PANNEAU QUI VIENT DE S'OUVRIR n'a peut-etre pas encore ses boutons : il
	-- s'affiche, PUIS le serveur ou le rendu le remplit. Vu le 4 novembre 2026,
	-- l'equipement prenait la selection sur « Assemblage par defaut », seul
	-- bouton present a l'instant de l'ouverture, au lieu de la premiere carte.
	-- Tant que le joueur n'a pas bouge la selection depuis l'ouverture, elle
	-- suit donc le premier bouton. Un delai fixe ne suffisait pas : la premiere
	-- ouverture attend la reponse du serveur, et elle arrivait apres lui.
	if navigatedAt < openedAt and lastScreen == top then
		local first = firstButton(top)
		if first ~= nil and first ~= selected then
			GuiService.SelectedObject = first
			lastPath = pathOf(first, top)
			lastSelected = first
			return
		end
	end

	-- ROBLOX DEPLACE LA SELECTION TOUT SEUL quand le bouton selectionne est
	-- detruit : il saute au voisin le plus proche, n'importe ou. Mesure le
	-- 4 novembre 2026 — une carte d'equipement reconstruite par le serveur
	-- envoyait la selection sur « Assemblage par defaut », et elle y restait
	-- puisque ce bouton est bien dans le panneau. Une selection qui change
	-- SANS que le joueur ait pousse la croix ou le stick n'est donc pas la
	-- sienne : on la remet sur le bouton qu'il avait, s'il existe encore.
	if
		selected ~= lastSelected
		and os.clock() - navigatedAt > NAVIGATION_SECONDS
		and lastScreen == top
		and lastPath ~= nil
	then
		local back = follow(top, lastPath :: { string })
		if back ~= nil and back ~= selected then
			GuiService.SelectedObject = back
			lastSelected = back
			return
		end
	end

	if selected ~= nil then
		local screen = insideOpenPanel(selected)
		if screen ~= nil and shown(selected, screen) then
			lastPath = pathOf(selected, screen)
			lastScreen = screen
			lastSelected = selected
			return
		end
	end

	-- La selection est perdue (bouton reconstruit) ou ailleurs : on la retrouve
	-- au meme endroit si on peut, sinon au premier bouton du panneau du dessus.
	local target: GuiObject? = nil
	if lastScreen == top and lastPath ~= nil then
		target = follow(top, lastPath :: { string })
	end
	if target == nil then
		target = firstButton(top)
	end
	if target ~= nil then
		GuiService.SelectedObject = target
		lastPath = pathOf(target, top)
		lastScreen = top
		lastSelected = target
	end
end

local function watch(screen: ScreenGui)
	if panels[screen.Name] == nil then
		return
	end
	local function onEnabled()
		local index = table.find(opened, screen)
		if index ~= nil then
			table.remove(opened, index)
		end
		if screen.Enabled then
			table.insert(opened, screen)
			-- Un panneau qui s'ouvre prend la main, en partant de son premier
			-- bouton : on ne reprend pas un chemin d'une ouverture precedente.
			lastScreen = screen
			lastPath = nil
			openedAt = os.clock()
		end
		task.defer(settle)
	end
	screen:GetPropertyChangedSignal("Enabled"):Connect(onEnabled)
	if screen.Enabled then
		onEnabled()
	end
end

-- Inscrit les panneaux : nom du ScreenGui -> fonction qui le ferme, ou `false`
-- pour un panneau que B ne ferme pas.
function Gamepad.start(config: any, closers: { [string]: (() -> ()) | boolean })
	for name, closer in closers do
		panels[name] = { close = if typeof(closer) == "function" then closer else nil }
	end

	padNow = isPadInput(UserInputService:GetLastInputType())
	local function heard(input: InputObject)
		local kind = input.UserInputType
		local name = input.KeyCode.Name
		if string.sub(name, 1, 4) == "DPad" or input.KeyCode == Enum.KeyCode.Thumbstick1 then
			-- Le stick gauche bavarde meme au repos : seul un vrai mouvement compte.
			if input.KeyCode ~= Enum.KeyCode.Thumbstick1 or input.Position.Magnitude > 0.5 then
				navigatedAt = os.clock()
			end
		end
		-- Le focus de la fenetre ne dit rien de ce qu'on a dans les mains.
		if kind == Enum.UserInputType.Focus or kind == Enum.UserInputType.None then
			return
		end
		local now = isPad(input)
		if now == padNow then
			return
		end
		padNow = now
		for _, listener in padListeners do
			listener(now)
		end
		if now then
			task.defer(settle)
		end
	end
	-- `InputChanged` en plus de `InputBegan` : un stick qu'on pousse ou une
	-- souris qu'on bouge disent aussi ce qu'on a dans les mains.
	UserInputService.InputBegan:Connect(heard)
	UserInputService.InputChanged:Connect(heard)

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, child in playerGui:GetChildren() do
		if child:IsA("ScreenGui") then
			watch(child)
		end
	end
	playerGui.ChildAdded:Connect(function(child)
		if child:IsA("ScreenGui") then
			watch(child)
		end
	end)

	-- Un filet, pas le mecanisme : les reconstructions de panneaux ne previennent
	-- personne, donc on verifie dix fois par seconde que la selection existe.
	local since = 0
	RunService.Heartbeat:Connect(function(step: number)
		since += step
		if since < 0.1 then
			return
		end
		since = 0
		settle()
	end)

	-- B FERME LE PANNEAU DU DESSUS. `processed` n'est pas regarde : quand un
	-- bouton est selectionne, Roblox consomme B pour lui-meme, et c'est
	-- justement la qu'on veut fermer.
	local closeCode = Gamepad.code(config.gamepad.close)
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.KeyCode ~= closeCode then
			return
		end
		local top = topPanel()
		if top == nil then
			return
		end
		local panel = panels[top.Name]
		if panel ~= nil and panel.close ~= nil then
			panel.close()
		end
		task.defer(settle)
	end)
end

-- Vrai quand un panneau a la main : la croix et les gachettes servent alors a
-- l'interface, pas au combat.
function Gamepad.panelHasFocus(): boolean
	return padNow and topPanel() ~= nil
end

return Gamepad
