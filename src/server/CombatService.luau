--!strict
--[[
	CombatService — la couche mince qui applique le combat aux personnages.

	Tout le calcul est dans Combat, qui est pur et teste hors de Studio. Ici on
	ne fait que ce que seul Roblox sait faire : trouver la cible la plus proche,
	poser les PV sur le Humanoid, et pousser un personnage.

	Le serveur est seul juge : le client envoie une intention d'attaque, c'est
	tout. La recharge est verifiee ici, jamais cote client.

	Ce module est le SEUL endroit du jeu ou des PV sont retires. Les coups, la
	zone qui se referme et le coup de grace passent tous par dealDamage. Deux
	chemins differents vers les degats, ce serait deux occasions de laisser un
	joueur mourir alors qu'il aurait du tomber a terre.
]]

local CombatService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Config = require(Arena:WaitForChild("Config"))
local Combat = require(Arena:WaitForChild("Combat"))

local Remotes = Arena:WaitForChild("Remotes")
local attackRemote = Remotes:WaitForChild("Attack") :: RemoteEvent

local DownedService = require(script.Parent:WaitForChild("DownedService"))
local ZoneService = require(script.Parent:WaitForChild("ZoneService"))

export type Entry = {
	player: Player,
	team: string,
	classId: string,
	stats: Combat.Stats,
}

local roster: { [Player]: Entry } = {}
local lastAttackAt: { [Player]: number } = {}
local lastCombatAt: { [Player]: number } = {}
local active = false

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
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Roblox ajoute un script "Health" dans chaque personnage, qui regenere la vie
-- de tout le monde. Sans le retirer, la faiblesse du Vampire n'existe pas.
local function stripDefaultRegen(character: Model)
	if not Config.combat.disableDefaultRegen then
		return
	end

	local function destroyHealthScript(child: Instance)
		if child.Name == "Health" and child:IsA("Script") then
			child:Destroy()
		end
	end

	for _, child in character:GetChildren() do
		destroyHealthScript(child)
	end

	-- Le script arrive parfois juste apres le personnage, d'ou l'ecoute.
	character.ChildAdded:Connect(destroyHealthScript)
end

-- La cible la plus proche dans une autre equipe, a portee.
--
-- Un adversaire debout passe toujours avant un adversaire a terre : sans cette
-- priorite, on se retrouve a achever quelqu'un pendant que son coequipier vous
-- frappe dans le dos, ce qui n'est jamais le coup qu'on voulait porter.
local function findTarget(entry: Entry): Entry?
	local attackerRoot = rootOf(entry.player)
	if attackerRoot == nil then
		return nil
	end

	local bestStanding: Entry? = nil
	local bestStandingDistance = math.huge
	local bestDowned: Entry? = nil
	local bestDownedDistance = math.huge

	for _, other in roster do
		if other.team == entry.team then
			continue
		end

		local root = rootOf(other.player)
		if root == nil then
			continue
		end

		local distance = (root.Position - attackerRoot.Position).Magnitude
		if distance > entry.stats.attackRangeStuds then
			continue
		end

		local status = DownedService.statusOf(other.player)
		if status == "standing" and distance < bestStandingDistance then
			bestStanding = other
			bestStandingDistance = distance
		elseif status == "downed" and distance < bestDownedDistance then
			bestDowned = other
			bestDownedDistance = distance
		end
	end

	return if bestStanding ~= nil then bestStanding else bestDowned
end

local function applyKnockback(attacker: Entry, target: Entry)
	if attacker.stats.knockbackStuds <= 0 then
		return
	end

	local attackerRoot = rootOf(attacker.player)
	local targetRoot = rootOf(target.player)
	if attackerRoot == nil or targetRoot == nil then
		return
	end

	local away = targetRoot.Position - attackerRoot.Position
	local flat = Vector3.new(away.X, 0, away.Z)
	if flat.Magnitude <= 0 then
		return
	end

	targetRoot.AssemblyLinearVelocity = (flat.Unit * attacker.stats.knockbackStuds)
		+ Vector3.new(0, attacker.stats.knockbackUpStuds, 0)
end

-- Le seul endroit du jeu ou des PV sont retires. Renvoie vrai si le coup a mis
-- la cible a terre.
local function dealDamage(target: Entry, amount: number): boolean
	if amount <= 0 then
		return false
	end

	local humanoid = humanoidOf(target.player)
	if humanoid == nil then
		return false
	end

	-- Un joueur deja a terre ne perd plus de PV : il perd du temps. C'est la
	-- fenetre d'agonie qui le decompte, et le coup de grace qui l'arrete.
	if not DownedService.isStanding(target.player) then
		return false
	end

	-- Le moindre degat recu annule le relevement que la cible etait en train
	-- de faire : on ne releve pas quelqu'un au milieu d'un echange de coups.
	DownedService.interruptRevivesBy(target.player)
	lastCombatAt[target.player] = os.clock()

	local remaining = humanoid.Health - amount
	if remaining > 0 then
		humanoid.Health = remaining
		return false
	end

	DownedService.knockDown(target.player)
	return true
end

local function onAttack(player: Player)
	if not active then
		return
	end

	local entry = roster[player]
	if entry == nil then
		return
	end

	-- A terre, on rampe : on ne frappe pas.
	if not DownedService.isStanding(player) then
		return
	end

	local attackerHumanoid = humanoidOf(player)
	if attackerHumanoid == nil or attackerHumanoid.Health <= 0 then
		return
	end

	local now = os.clock()
	if not Combat.canAttack(entry.stats, now, lastAttackAt[player]) then
		return
	end

	-- La recharge est consommee meme si le coup part dans le vide : frapper au
	-- hasard doit couter quelque chose.
	lastAttackAt[player] = now

	local target = findTarget(entry)
	if target == nil then
		return
	end

	local targetHumanoid = humanoidOf(target.player)
	if targetHumanoid == nil then
		return
	end

	lastCombatAt[player] = now

	-- Le coup de grace : il ne rapporte ni degats ni vol de vie, il ferme une
	-- fenetre. Un Vampire ne se soigne donc pas en achevant.
	if DownedService.isDowned(target.player) then
		DownedService.finish(target.player)
		applyKnockback(entry, target)
		return
	end

	local result = Combat.resolveHit({
		attackerStats = entry.stats,
		attackerHealth = attackerHumanoid.Health,
		defenderStats = target.stats,
		defenderHealth = targetHumanoid.Health,
	})

	attackerHumanoid.Health = result.attackerHealth
	dealDamage(target, result.damage)

	applyKnockback(entry, target)
end

-- Les degats de la zone. Ils ne touchent que les joueurs debout : un blesse
-- qui rampe dehors a deja son compte a rebours, en ajouter un deuxieme ne
-- changerait rien a l'issue et rendrait l'affichage incomprehensible.
local function applyZoneDamage(deltaSeconds: number)
	if not ZoneService.isActive() then
		return
	end

	local amount = ZoneService.damageFor(deltaSeconds)
	for player, entry in roster do
		if not DownedService.isStanding(player) then
			continue
		end
		local root = rootOf(player)
		if root ~= nil and ZoneService.isOutside(root.Position) then
			dealDamage(entry, amount)
		end
	end
end

-- Regeneration hors combat, pilotee par classe. Le Vampire a zero.
local function applyRegen(deltaSeconds: number)
	local now = os.clock()
	for player, entry in roster do
		if not DownedService.isStanding(player) then
			continue
		end

		local since = lastCombatAt[player]
		if since ~= nil and (now - since) < Config.combat.outOfCombatSeconds then
			continue
		end

		local humanoid = humanoidOf(player)
		if humanoid == nil or humanoid.Health <= 0 then
			continue
		end

		humanoid.Health = Combat.applyRegen(entry.stats, humanoid.Health, deltaSeconds)
	end
end

local function onHeartbeat(deltaSeconds: number)
	if not active then
		return
	end

	applyZoneDamage(deltaSeconds)
	applyRegen(deltaSeconds)
end

function CombatService.init()
	for _, player in Players:GetPlayers() do
		if player.Character then
			stripDefaultRegen(player.Character)
		end
		player.CharacterAdded:Connect(stripDefaultRegen)
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(stripDefaultRegen)
	end)

	Players.PlayerRemoving:Connect(function(player)
		roster[player] = nil
		lastAttackAt[player] = nil
		lastCombatAt[player] = nil
	end)

	attackRemote.OnServerEvent:Connect(onAttack)
	RunService.Heartbeat:Connect(onHeartbeat)
end

function CombatService.setRoster(entries: { Entry })
	roster = {}
	lastAttackAt = {}
	lastCombatAt = {}
	for _, entry in entries do
		roster[entry.player] = entry
	end
end

function CombatService.setActive(value: boolean)
	active = value
end

-- Pose les PV et la vitesse de la classe sur le personnage.
function CombatService.applyStats(player: Player, stats: Combat.Stats)
	local humanoid = humanoidOf(player)
	if humanoid == nil then
		return
	end
	humanoid.MaxHealth = stats.maxHealth
	humanoid.Health = stats.maxHealth
	humanoid.WalkSpeed = stats.walkSpeed
end

-- Immobilise pendant le compte a rebours d'avant-manche.
function CombatService.setFrozen(player: Player, frozen: boolean)
	local entry = roster[player]
	local humanoid = humanoidOf(player)
	if entry == nil or humanoid == nil then
		return
	end

	if frozen then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	else
		humanoid.WalkSpeed = entry.stats.walkSpeed
		humanoid.JumpPower = 50
		humanoid.JumpHeight = 7.2
	end
end

return CombatService
