--!strict
--[[
	DownedService — la couche mince qui applique l'agonie aux personnages.

	Tout le calcul d'etat est dans Downed, qui est pur et teste hors de Studio.
	Ici on ne fait que ce que seul Roblox sait faire : empecher le Humanoid de
	mourir, poser la vitesse de reptation, mesurer la distance entre un blesse
	et ceux qui peuvent le relever, et afficher le compte a rebours au-dessus
	de sa tete.

	Le point delicat : un Humanoid meurt a zero PV, et une fois mort il ne
	revient pas. Un joueur a terre est donc maintenu a un PV, et tous les
	degats passent par CombatService, qui demande ici si la cible est deja a
	terre avant de retirer quoi que ce soit.
]]

local DownedService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Config = require(Arena:WaitForChild("Config"))
local Combat = require(Arena:WaitForChild("Combat"))
local Downed = require(Arena:WaitForChild("Downed"))

export type Entry = {
	player: Player,
	team: string,
	classId: string,
	stats: Combat.Stats,
}

local DOWNED_COLOR = Color3.fromRGB(220, 60, 60)
local REVIVING_COLOR = Color3.fromRGB(90, 200, 120)

local entries: { [Player]: Entry } = {}
local fighters: { [Player]: Downed.Fighter } = {}
local order: { Player } = {}
local active = false

-- Appele quand un joueur change d'etat, pour que MatchService l'annonce.
local onChanged: ((Player, Downed.Status) -> ())? = nil

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	if character == nil then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- La liste a plat, dans un ordre stable : Downed raisonne sur une liste, pas
-- sur une table indexee par Player.
local function fighterList(): { Downed.Fighter }
	local list: { Downed.Fighter } = {}
	for _, player in order do
		local fighter = fighters[player]
		if fighter then
			table.insert(list, fighter)
		end
	end
	return list
end

--------------------------------------------------------------------------------
-- L'AFFICHAGE AU-DESSUS DE LA TETE
--------------------------------------------------------------------------------

local function clearMarker(player: Player)
	local character = player.Character
	if character == nil then
		return
	end

	local highlight = character:FindFirstChild("ArenaDownedHighlight")
	if highlight then
		highlight:Destroy()
	end

	local head = character:FindFirstChild("Head")
	if head then
		local billboard = head:FindFirstChild("ArenaDownedBillboard")
		if billboard then
			billboard:Destroy()
		end
	end
end

local function createMarker(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	clearMarker(player)

	-- Un contour rouge visible a travers les murs : on doit pouvoir decider
	-- d'aller relever quelqu'un sans l'avoir dans son champ de vision.
	local highlight = Instance.new("Highlight")
	highlight.Name = "ArenaDownedHighlight"
	highlight.FillColor = DOWNED_COLOR
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = DOWNED_COLOR
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character

	local head = character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ArenaDownedBillboard"
	billboard.Size = UDim2.fromOffset(160, 44)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 250
	billboard.Parent = head

	local countdown = Instance.new("TextLabel")
	countdown.Name = "Countdown"
	countdown.Size = UDim2.new(1, 0, 0, 24)
	countdown.BackgroundTransparency = 1
	countdown.Font = Enum.Font.GothamBold
	countdown.TextSize = 20
	countdown.TextColor3 = DOWNED_COLOR
	countdown.TextStrokeTransparency = 0.3
	countdown.Text = ""
	countdown.Parent = billboard

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(0.8, 0, 0, 6)
	track.Position = UDim2.new(0.1, 0, 0, 28)
	track.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	track.BackgroundTransparency = 0.4
	track.BorderSizePixel = 0
	track.Parent = billboard

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = REVIVING_COLOR
	fill.BorderSizePixel = 0
	fill.Parent = track
end

local function updateMarker(player: Player, fighter: Downed.Fighter, now: number)
	local character = player.Character
	if character == nil then
		return
	end
	local head = character:FindFirstChild("Head")
	if head == nil then
		return
	end
	local billboard = head:FindFirstChild("ArenaDownedBillboard")
	if billboard == nil then
		return
	end

	local countdown = billboard:FindFirstChild("Countdown")
	if countdown and countdown:IsA("TextLabel") then
		countdown.Text = string.format("%.0f", Downed.secondsLeft(Config, fighter, now))
	end

	local track = billboard:FindFirstChild("Track")
	local fill = if track then track:FindFirstChild("Fill") else nil
	if fill and fill:IsA("Frame") then
		fill.Size = UDim2.fromScale(Downed.reviveRatio(Config, fighter), 1)
	end
end

--------------------------------------------------------------------------------
-- LES EFFETS SUR LE PERSONNAGE
--------------------------------------------------------------------------------

local function applyCrawl(player: Player, entry: Entry)
	local humanoid = humanoidOf(player)
	if humanoid == nil then
		return
	end
	humanoid.WalkSpeed = Downed.crawlSpeed(Config, entry.stats.walkSpeed)
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.Health = math.max(humanoid.Health, 1)
end

local function applyStanding(player: Player, entry: Entry, health: number)
	local humanoid = humanoidOf(player)
	if humanoid == nil then
		return
	end
	humanoid.WalkSpeed = entry.stats.walkSpeed
	humanoid.JumpPower = 50
	humanoid.JumpHeight = 7.2
	humanoid.Health = health
end

local function applyOut(player: Player)
	local humanoid = humanoidOf(player)
	if humanoid == nil then
		return
	end
	humanoid.Health = 0
end

local function announce(player: Player, status: Downed.Status)
	local callback = onChanged
	if callback then
		callback(player, status)
	end
end

--------------------------------------------------------------------------------
-- L'API
--------------------------------------------------------------------------------

function DownedService.setRoster(list: { Entry })
	for player in fighters do
		clearMarker(player)
	end

	entries = {}
	fighters = {}
	order = {}

	for _, entry in list do
		entries[entry.player] = entry
		fighters[entry.player] = Downed.create(tostring(entry.player.UserId), entry.team)
		table.insert(order, entry.player)
	end
end

function DownedService.setActive(value: boolean)
	active = value
end

function DownedService.onStatusChanged(callback: (Player, Downed.Status) -> ())
	onChanged = callback
end

function DownedService.statusOf(player: Player): Downed.Status?
	local fighter = fighters[player]
	return if fighter then fighter.status else nil
end

function DownedService.isDowned(player: Player): boolean
	return DownedService.statusOf(player) == "downed"
end

function DownedService.isStanding(player: Player): boolean
	return DownedService.statusOf(player) == "standing"
end

-- Les PV sont tombes a zero. Renvoie le nouvel etat.
function DownedService.knockDown(player: Player): Downed.Status?
	local fighter = fighters[player]
	local entry = entries[player]
	if fighter == nil or entry == nil then
		return nil
	end

	local status = Downed.knockDown(Config, fighter, os.clock())
	if status == "downed" then
		applyCrawl(player, entry)
		createMarker(player)
	else
		clearMarker(player)
		applyOut(player)
	end

	announce(player, status)
	return status
end

-- Achever un joueur a terre. Renvoie vrai si le coup l'a elimine.
function DownedService.finish(player: Player): boolean
	local fighter = fighters[player]
	if fighter == nil or not Downed.finish(Config, fighter) then
		return false
	end

	clearMarker(player)
	applyOut(player)
	announce(player, "out")
	return true
end

-- Un degat recu interrompt le relevement que ce joueur etait en train de faire.
function DownedService.interruptRevivesBy(player: Player)
	local reviver = fighters[player]
	if reviver == nil then
		return
	end

	for _, other in order do
		local fighter = fighters[other]
		if fighter and fighter.status == "downed" and fighter.team == reviver.team then
			Downed.interruptRevive(Config, fighter)
		end
	end
end

function DownedService.roundWinner(): string?
	return Downed.roundWinner(fighterList())
end

function DownedService.roundIsOver(): boolean
	return Downed.roundIsOver(fighterList())
end

-- Remet tout le monde debout pour la manche suivante.
function DownedService.resetRound()
	for _, player in order do
		clearMarker(player)
		local entry = entries[player]
		local team = if entry then entry.team else "A"
		fighters[player] = Downed.create(tostring(player.UserId), team)
	end
end

--------------------------------------------------------------------------------
-- LA BOUCLE
--------------------------------------------------------------------------------

-- Qui peut relever ce blesse : un coequipier debout, assez proche.
local function reviverFor(player: Player, fighter: Downed.Fighter): Player?
	local downedRoot = rootOf(player)
	if downedRoot == nil then
		return nil
	end

	for _, other in order do
		if other == player then
			continue
		end

		local otherFighter = fighters[other]
		if otherFighter == nil or otherFighter.status ~= "standing" then
			continue
		end
		if otherFighter.team ~= fighter.team then
			continue
		end

		local otherRoot = rootOf(other)
		if otherRoot == nil then
			continue
		end

		if
			(otherRoot.Position - downedRoot.Position).Magnitude <= Config.downed.reviveRangeStuds
		then
			return other
		end
	end

	return nil
end

local function onHeartbeat(deltaSeconds: number)
	if not active then
		return
	end

	local now = os.clock()

	for _, player in order do
		local fighter = fighters[player]
		local entry = entries[player]
		if fighter == nil or entry == nil or fighter.status ~= "downed" then
			continue
		end

		-- La fenetre passe avant le relevement : une barre terminee au moment
		-- exact ou le compte a rebours expire doit perdre, sinon on ne sait
		-- plus ce qui s'est joue.
		if Downed.expire(Config, fighter, now) then
			clearMarker(player)
			applyOut(player)
			announce(player, "out")
			continue
		end

		if reviverFor(player, fighter) ~= nil then
			if Downed.addReviveProgress(Config, fighter, deltaSeconds) then
				clearMarker(player)
				applyStanding(player, entry, Downed.reviveHealth(Config, entry.stats.maxHealth))
				announce(player, "standing")
				continue
			end
		else
			-- Le relevement ne se met pas en pause : s'eloigner le perd.
			fighter.reviveProgress = 0
		end

		updateMarker(player, fighter, now)
	end

	for _, collapsed in Downed.collapseTeamsWithoutReviver(Config, fighterList()) do
		for _, player in order do
			if fighters[player] == collapsed then
				clearMarker(player)
				applyOut(player)
				announce(player, "out")
			end
		end
	end
end

function DownedService.init()
	Players.PlayerRemoving:Connect(function(player)
		entries[player] = nil
		fighters[player] = nil
		for index, other in order do
			if other == player then
				table.remove(order, index)
				break
			end
		end
	end)

	RunService.Heartbeat:Connect(onHeartbeat)
end

return DownedService
