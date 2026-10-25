--!strict
--[[
	CombatService — la couche mince qui applique le combat aux personnages.

	Tout le calcul est dans Combat, qui est pur et teste hors de Studio. Ici on
	ne fait que trois choses que seul Roblox sait faire : trouver la cible la
	plus proche, poser les PV sur le Humanoid, et pousser un personnage.

	Le serveur est seul juge : le client envoie une intention d'attaque, c'est
	tout. La recharge est verifiee ici, jamais cote client.
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

-- La cible la plus proche dans une autre equipe, a portee et encore debout.
local function findTarget(entry: Entry): Entry?
	local attackerRoot = rootOf(entry.player)
	if attackerRoot == nil then
		return nil
	end

	local best: Entry? = nil
	local bestDistance = math.huge

	for _, other in roster do
		if other.team == entry.team then
			continue
		end

		local humanoid = humanoidOf(other.player)
		local root = rootOf(other.player)
		if humanoid == nil or root == nil or humanoid.Health <= 0 then
			continue
		end

		local distance = (root.Position - attackerRoot.Position).Magnitude
		if distance <= entry.stats.attackRangeStuds and distance < bestDistance then
			best = other
			bestDistance = distance
		end
	end

	return best
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

local function onAttack(player: Player)
	if not active then
		return
	end

	local entry = roster[player]
	if entry == nil then
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

	local result = Combat.resolveHit({
		attackerStats = entry.stats,
		attackerHealth = attackerHumanoid.Health,
		defenderStats = target.stats,
		defenderHealth = targetHumanoid.Health,
	})

	targetHumanoid.Health = result.defenderHealth
	attackerHumanoid.Health = result.attackerHealth

	lastCombatAt[player] = now
	lastCombatAt[target.player] = now

	applyKnockback(entry, target)
end

-- Regeneration hors combat, pilotee par classe. Le Vampire a zero.
local function onHeartbeat(deltaSeconds: number)
	if not active then
		return
	end

	local now = os.clock()
	for player, entry in roster do
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
