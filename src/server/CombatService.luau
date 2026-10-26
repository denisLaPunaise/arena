--!strict
--[[
	CombatService — la couche mince qui applique le combat aux personnages.

	Tout le calcul est dans Combat, qui est pur et teste hors de Studio. Ici on
	ne fait que ce que seul Roblox sait faire : trouver la cible la plus proche,
	poser les PV sur le Humanoid, et pousser un personnage.

	Le serveur est seul juge : le client envoie une intention d'attaque, c'est
	tout. La recharge est verifiee ici, jamais cote client.

	Ce module est le SEUL endroit du jeu ou des PV sont retires. Les coups, la
	zone qui se referme, la propagation et le coup de grace passent tous par
	dealDamage. Deux chemins differents vers les degats, ce serait deux occasions
	de laisser un joueur mourir alors qu'il aurait du tomber a terre.

	dealDamage recoit des degats DEJA reduits. C'est voulu : chaque appelant sait
	quelle reduction s'applique a sa source (un coup passe par Combat.resolveHit,
	la zone et la propagation par Combat.damageTaken), et le vol de vie se calcule
	sur ce qui est reellement passe. Appliquer la reduction dans dealDamage la
	ferait tomber deux fois sur les coups.

	LES QUATRE EFFETS DE PALIER 6 qui vivent ici, avec leurs chiffres dans
	Config.tier6 :

	    dash               Fauve      un bond quand le coup part dans le vide
	    chargePierces      Belier     la charge touche plusieurs ennemis
	    thrownLeavesCover  Catapulte  le coup laisse un bloc au sol
	    leechFromZone      Sangsue    la zone qui blesse un ennemi le soigne

	Aucun n'est interroge directement depuis une branche : on passe toujours par
	SkillTreeService.hasEffect, qui renvoie faux pour un effet decrit mais pas
	code. Un palier 6 absent ne fait donc rien, au lieu de planter.
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

local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local AbilityService = require(script.Parent:WaitForChild("AbilityService"))
local DownedService = require(script.Parent:WaitForChild("DownedService"))
local LoadoutService = require(script.Parent:WaitForChild("LoadoutService"))
local EffectsService = require(script.Parent:WaitForChild("EffectsService"))
local SkillTreeService = require(script.Parent:WaitForChild("SkillTreeService"))
local ZoneService = require(script.Parent:WaitForChild("ZoneService"))

export type Entry = {
	player: Player,
	team: string,
	classId: string,
	stats: Combat.Stats,
}

local roster: { [Player]: Entry } = {}

-- L'ARME DU COUP EN COURS.
--
-- entry.stats porte l'arme principale, et c'est elle que tout le jeu lit : PV
-- maximum, vitesse, regeneration. Mais un coup peut partir avec la SECONDAIRE,
-- quand la cible est hors de portee de la principale — c'est tout ce que
-- l'arme secondaire fait, et elle n'a pas de touche a elle.
--
-- Plutot que de faire passer un jeu de statistiques dans chaque fonction du
-- chemin d'attaque (la poussee, la propagation, la charge qui traverse), on
-- note ici l'arme choisie au debut du coup et `striking` la rend. Rien
-- n'interrompt un coup, donc cette note ne peut pas se melanger entre deux
-- joueurs ni entre deux coups.
local strikeProfile: { [Player]: { stats: Combat.Stats, pierce: number } } = {}

local function striking(entry: Entry): Combat.Stats
	local profile = strikeProfile[entry.player]
	if profile == nil then
		return entry.stats
	end
	return profile.stats
end

-- La part de l'armure de la cible que l'arme ignore. Seul l'arc composite en a
-- une, et c'est le seul contre a l'armure lourde du catalogue.
local function strikingPierce(entry: Entry?): number
	if entry == nil then
		return 0
	end
	local profile = strikeProfile[entry.player]
	if profile == nil then
		return 0
	end
	return profile.pierce
end

local lastAttackAt: { [Player]: number } = {}
local lastCombatAt: { [Player]: number } = {}
local lastDashAt: { [Player]: number } = {}
local active = false

-- Les degats de zone se cumulent avant d'etre annonces. Sans ca un nombre
-- partirait a chaque image : illisible, et une inondation de messages reseau
-- pour du decor.
local zoneOwed: { [Player]: number } = {}
local zoneToldAt: { [Player]: number } = {}

-- Les blocs laisses par la Catapulte vivent la, et nulle part ailleurs dans
-- Workspace. Workspace appartient a la construction des maps, pas au code : un
-- dossier a part, vide entre deux manches, est la seule facon d'y poser quelque
-- chose sans risquer d'y laisser des traces.
local tempFolder: Folder? = nil

local function temporaryParent(): Folder
	local existing = tempFolder
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = "ArenaTemp"
	folder.Parent = Workspace
	tempFolder = folder
	return folder
end

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

	-- La plus longue des deux portees : sans ca une secondaire a longue portee
	-- ne trouverait jamais personne, puisque la recherche s'arreterait a la
	-- portee de l'arme principale.
	local searchRange = LoadoutService.searchRange(entry)

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
		if distance > searchRange then
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

-- Les adversaires debout dans un rayon autour d'un point. Sert a la propagation
-- de la Peste et a la charge du Belier, qui posent la meme question.
local function standingEnemiesNear(
	entry: Entry,
	position: Vector3,
	radius: number,
	exclude: Entry?
): { Entry }
	local found: { Entry } = {}

	for _, other in roster do
		if other.team == entry.team or other == exclude then
			continue
		end
		if not DownedService.isStanding(other.player) then
			continue
		end

		local root = rootOf(other.player)
		if root == nil then
			continue
		end
		if (root.Position - position).Magnitude <= radius then
			table.insert(found, other)
		end
	end

	return found
end

local function applyKnockback(attacker: Entry, target: Entry)
	local stats = striking(attacker)
	if stats.knockbackStuds <= 0 then
		return
	end
	-- Le Socle du Sismique ne bouge plus d'un pouce.
	if AbilityService.resistsKnockback(target.player) then
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

	targetRoot.AssemblyLinearVelocity = (flat.Unit * stats.knockbackStuds)
		+ Vector3.new(0, stats.knockbackUpStuds, 0)
end

-- Le seul endroit du jeu ou des PV sont retires. Renvoie les degats REELLEMENT
-- passes, qui sont plafonnes aux PV restants : c'est sur ce nombre que se
-- calculent le vol de vie et la propagation, jamais sur les degats demandes.
--
-- Les degats arrivent ici deja reduits. Voir l'en-tete du fichier.
-- Les statistiques de la cible TELLES QUE LE COUP LES VOIT. Deux pouvoirs s'y
-- invitent : le Leurre encaisse davantage tant que son clone vit, et le
-- Duelliste de palier 6 traverse la resistance adverse.
--
-- On lit une copie, jamais l'original : ecrire dans entry.stats laisserait la
-- modification en place pour tous les coups suivants, et l'effet se cumulerait
-- jusqu'a la fin de la manche.
local function defenderReading(target: Entry, attacker: Entry?): Combat.Stats
	local extra = AbilityService.extraDamageTakenRatio(target.player)
	local pierced = attacker ~= nil and AbilityService.piercesResistance(attacker)
	local armorPierce = strikingPierce(attacker)

	if extra == 0 and not pierced and armorPierce <= 0 then
		return target.stats
	end

	local reading = table.clone(target.stats)
	if pierced then
		reading.damageTakenRatio = 0
		return reading
	end

	local ratio = (reading.damageTakenRatio or 0) + extra

	-- L'arc composite ignore la moitie de la REDUCTION, pas la moitie des
	-- degats, et seulement quand c'en est une. Sans la condition, percer une
	-- cible deja plus fragile la rendrait moins fragile, ce qui n'a aucun sens.
	if armorPierce > 0 and ratio < 0 then
		ratio *= (1 - armorPierce)
	end

	reading.damageTakenRatio = ratio
	return reading
end

local function damageTakenBy(target: Entry, amount: number, attacker: Entry?): number
	return Combat.damageTaken(Config, defenderReading(target, attacker), amount)
end

-- Garde-fou du Lien : partager des degats inflige des degats, qui pourraient
-- repartir dans un partage. Deux Liens qui se designent mutuellement se
-- renverraient le coup sans fin.
local sharingDamage = false

local function dealDamage(target: Entry, amount: number): number
	if amount <= 0 then
		return 0
	end

	local humanoid = humanoidOf(target.player)
	if humanoid == nil then
		return 0
	end

	-- Un joueur deja a terre ne perd plus de PV : il perd du temps. C'est la
	-- fenetre d'agonie qui le decompte, et le coup de grace qui l'arrete.
	if not DownedService.isStanding(target.player) then
		return 0
	end

	-- Le Lien prend une part des degats a la place de son allie, avant que les
	-- PV ne bougent.
	if not sharingDamage then
		sharingDamage = true
		amount = AbilityService.shareDamage(target, amount)
		sharingDamage = false
		if amount <= 0 then
			return 0
		end
	end

	-- Le moindre degat recu annule le relevement que la cible etait en train
	-- de faire : on ne releve pas quelqu'un au milieu d'un echange de coups.
	DownedService.interruptRevivesBy(target.player)
	lastCombatAt[target.player] = os.clock()
	AbilityService.onDamaged(target, amount)
	-- Et il annule la pose d'une trousse de soin : on ne se bande pas le bras
	-- sous le feu.
	LoadoutService.onDamaged(target.player)

	local passed = math.min(amount, humanoid.Health)
	local remaining = humanoid.Health - passed

	if remaining > 0 then
		humanoid.Health = remaining
	else
		DownedService.knockDown(target.player)
	end

	return passed
end

-- A hauteur de poitrine, pas aux pieds : un nombre au sol se perd dans le
-- decor, et un nombre au-dessus de la tete se confond avec le pseudo.
local function effectPoint(target: Entry): Vector3?
	local root = rootOf(target.player)
	if root == nil then
		return nil
	end
	return root.Position + Vector3.new(0, 1.5, 0)
end

local function healTo(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	-- Le Spectre ne peut pas etre soigne pendant qu'il traverse : c'est la
	-- faiblesse annoncee de son pouvoir, et c'est ici qu'elle s'applique.
	if not AbilityService.canBeHealed(player) then
		return
	end
	local humanoid = humanoidOf(player)
	if humanoid == nil then
		return
	end

	local before = humanoid.Health
	humanoid.Health = math.min(humanoid.Health + amount, humanoid.MaxHealth)

	-- Le Parasite vit sur les soins des autres : il prend sa part de ce qui a
	-- reellement ete rendu, pas de ce qui etait demande.
	AbilityService.onHealed(player, humanoid.Health - before)
end

--------------------------------------------------------------------------------
-- LES EFFETS DE PALIER 6
--------------------------------------------------------------------------------

-- Peste : une part du coup se repercute sur les ennemis proches de la cible.
-- Elle se calcule sur les degats VRAIMENT passes, donc frapper un adversaire a
-- un PV n'arrose pas ses coequipiers.
local function spreadFrom(entry: Entry, target: Entry, damageDealt: number)
	local stats = striking(entry)
	if damageDealt <= 0 or not Combat.spreadsDamage(stats) then
		return
	end

	local targetRoot = rootOf(target.player)
	if targetRoot == nil then
		return
	end

	local share = Combat.spreadDamage(stats, damageDealt)
	if share <= 0 then
		return
	end

	local nearby = standingEnemiesNear(entry, targetRoot.Position, stats.spreadRadiusStuds, target)
	for index, other in nearby do
		if index > Config.combat.spreadMaxTargets then
			break
		end
		local passed = dealDamage(other, damageTakenBy(other, share, entry))
		local point = effectPoint(other)
		if passed > 0 and point ~= nil then
			EffectsService.spread(point, passed, other.player)
		end
	end
end

-- Belier, palier 6 : la charge traverse. Chaque ennemi suivant prend moins,
-- sinon un seul coup dans un groupe decide la manche.
local function pierceFrom(entry: Entry, target: Entry, rawDamage: number)
	if not SkillTreeService.hasEffect(entry.player, "chargePierces") then
		return
	end

	local attackerRoot = rootOf(entry.player)
	if attackerRoot == nil then
		return
	end

	local settings = Config.tier6.chargePierces
	local nearby =
		standingEnemiesNear(entry, attackerRoot.Position, striking(entry).attackRangeStuds, target)

	for index, other in nearby do
		if index >= settings.maxTargets then
			break
		end
		local falloff = math.max(1 - (settings.falloffPerTarget * index), 0)
		local passed = dealDamage(other, damageTakenBy(other, rawDamage * falloff, entry))
		local point = effectPoint(other)
		if passed > 0 and point ~= nil then
			EffectsService.hit(point, passed, other.player)
		end
		applyKnockback(entry, other)
		spreadFrom(entry, other, passed)
	end
end

-- Catapulte, palier 6 : le bloc projete reste au sol quelques secondes. C'est
-- une vraie couverture, donc elle genera aussi celui qui l'a lancee.
local function leaveCover(entry: Entry, target: Entry)
	if not SkillTreeService.hasEffect(entry.player, "thrownLeavesCover") then
		return
	end

	local targetRoot = rootOf(target.player)
	if targetRoot == nil then
		return
	end

	local settings = Config.tier6.thrownLeavesCover
	local size = Vector3.new(settings.sizeStuds[1], settings.sizeStuds[2], settings.sizeStuds[3])

	local block = Instance.new("Part")
	block.Name = "ThrownCover"
	block.Size = size
	-- Pose au sol sous la cible, pas a sa hauteur : un bloc apparu dans le
	-- personnage le ferait traverser le decor.
	block.CFrame =
		CFrame.new(targetRoot.Position - Vector3.new(0, 2.5, 0) + Vector3.new(0, size.Y / 2, 0))
	block.Anchored = true
	block.Color = Color3.fromRGB(96, 102, 114)
	block.Material = Enum.Material.Slate
	block.Parent = temporaryParent()

	Debris:AddItem(block, settings.seconds)
end

-- Fauve, palier 6 : le bond. Il remplace un coup parti dans le vide, ce qui
-- veut dire qu'il n'a pas besoin d'une touche a lui : attaquer un adversaire
-- hors de portee, c'est lui sauter dessus.
local function tryDash(entry: Entry): boolean
	if not SkillTreeService.hasEffect(entry.player, "dash") then
		return false
	end

	local settings = Config.tier6.dash
	local now = os.clock()
	local last = lastDashAt[entry.player]
	if last ~= nil and (now - last) < settings.cooldownSeconds then
		return false
	end

	local attackerRoot = rootOf(entry.player)
	if attackerRoot == nil then
		return false
	end

	-- La cible la plus proche dans la portee du bond. Elle est forcement hors
	-- de portee d'attaque, puisqu'on n'arrive ici qu'apres un coup dans le vide.
	local nearby = standingEnemiesNear(entry, attackerRoot.Position, settings.rangeStuds, nil)
	local best: Entry? = nil
	local bestDistance = math.huge
	for _, other in nearby do
		local root = rootOf(other.player)
		if root == nil then
			continue
		end
		local distance = (root.Position - attackerRoot.Position).Magnitude
		if distance < bestDistance then
			best = other
			bestDistance = distance
		end
	end

	local chosen = best
	if chosen == nil then
		return false
	end

	local targetRoot = rootOf(chosen.player)
	if targetRoot == nil then
		return false
	end

	local away = targetRoot.Position - attackerRoot.Position
	local flat = Vector3.new(away.X, 0, away.Z)
	if flat.Magnitude <= 0 then
		return false
	end

	lastDashAt[entry.player] = now
	attackerRoot.AssemblyLinearVelocity = (flat.Unit * settings.speedStuds)
		+ Vector3.new(0, settings.upStuds, 0)
	EffectsService.dash(attackerRoot.Position, flat)
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

	-- Le Spectre ne frappe pas pendant qu'il traverse les murs. On sort avant
	-- de consommer la recharge : le pouvoir interdit le coup, il ne le gaspille
	-- pas.
	if not AbilityService.canAttack(player) then
		return
	end

	local now = os.clock()
	local attackerRoot = rootOf(player)
	local target = findTarget(entry)

	-- QUELLE ARME. On cherche la cible AVANT de verifier la recharge, parce que
	-- c'est la distance a la cible qui decide de l'arme, et que c'est l'arme
	-- qui porte la recharge. Un couteau a une demi-seconde de recharge, un
	-- marteau presque deux : verifier la recharge du marteau pour un coup de
	-- couteau serait faux dans les deux sens.
	local distance: number? = nil
	if target ~= nil and attackerRoot ~= nil then
		local targetRoot = rootOf(target.player)
		if targetRoot ~= nil then
			distance = (targetRoot.Position - attackerRoot.Position).Magnitude
		end
	end

	local stats, pierce = LoadoutService.strikeWith(entry, distance)
	strikeProfile[player] = { stats = stats, pierce = pierce }

	if not Combat.canAttack(stats, now, lastAttackAt[player]) then
		return
	end

	-- La recharge est consommee meme si le coup part dans le vide : frapper au
	-- hasard doit couter quelque chose.
	lastAttackAt[player] = now

	-- Le geste de l'arme, une fois le coup accepte et pas avant. Il part meme
	-- sans cible, comme le trait : c'est le meme principe, rater doit se voir
	-- et s'entendre. La voix renvoyee dit au client quel son jouer.
	local voice = LoadoutService.swingWeapon(entry, distance)

	-- Le trait part AVANT de savoir si on a touche, et il part meme dans le
	-- vide : rater doit se voir, sinon on n'apprend jamais la portee de sa
	-- classe.
	if attackerRoot ~= nil then
		-- La portee dessinee va jusqu'a la cible quand il y en a une, sinon
		-- droit devant sur toute la portee de la classe. On relit la position
		-- de la cible au lieu de la supposer : findTarget garantit qu'elle
		-- existait a l'instant d'avant, pas qu'elle existe encore.
		local reach = attackerRoot.CFrame.LookVector * LoadoutService.searchRange(entry)
		if target ~= nil then
			local targetRoot = rootOf(target.player)
			if targetRoot ~= nil then
				reach = targetRoot.Position - attackerRoot.Position
			end
		end
		EffectsService.swing(
			attackerRoot.Position + Vector3.new(0, 1.5, 0),
			reach,
			target ~= nil,
			voice
		)
	end

	-- Frapper revele le Cameleon : son camouflage tient tant qu'il ne fait
	-- rien, pas tant qu'il ne touche personne.
	AbilityService.noteAttack(player)

	if target == nil then
		-- Un coup dans le vide, c'est l'occasion du bond : le Fauve du palier 6
		-- n'a pas de touche a lui, attaquer un adversaire trop loin suffit.
		tryDash(entry)
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
		attackerStats = stats,
		attackerHealth = attackerHumanoid.Health,
		defenderStats = defenderReading(target, entry),
		defenderHealth = targetHumanoid.Health,
		config = Config,
	})

	-- Ce que les pouvoirs du frappeur font au coup : l'isolement du Duelliste,
	-- l'embuscade du Cameleon, le renfort du Lien.
	local damage = result.damage * AbilityService.outgoingMultiplier(entry)

	-- Le clone du Leurre s'interpose quand il est plus pres que son porteur.
	-- C'est ce que « attire l'attention » veut dire ici : personne ne choisit sa
	-- cible a la main, donc le leurre doit se mettre physiquement devant.
	if
		attackerRoot ~= nil and AbilityService.absorbAttack(attackerRoot.Position, target, damage)
	then
		return
	end

	local passed = dealDamage(target, damage)

	local point = effectPoint(target)
	if passed > 0 and point ~= nil then
		EffectsService.hit(point, passed, target.player)
	end

	-- Le vol de vie se recalcule sur ce qui est VRAIMENT passe : dealDamage
	-- plafonne aux PV restants, et un coup de 24 sur une cible a 3 PV ne doit
	-- pas soigner comme un coup de 24.
	local healed = Combat.lifestealFor(stats, attackerHumanoid.Health, passed)
	healTo(player, healed)

	if healed >= 1 and attackerRoot ~= nil then
		EffectsService.heal(attackerRoot.Position + Vector3.new(0, 1.5, 0), healed, player)
	end

	AbilityService.onHit(entry, target, passed)

	applyKnockback(entry, target)
	spreadFrom(entry, target, passed)
	pierceFrom(entry, target, Combat.rawDamage(stats))
	leaveCover(entry, target)
end

-- Sangsue, palier 6 : chaque point de degat que la zone retire a un ennemi
-- soigne les Vampires de l'equipe adverse qui ont cet effet. Volontairement
-- sans condition de distance : la zone est un evenement de map, pas un coup, et
-- une portee la rendrait illisible.
local function leechFromZone(victim: Entry, damageDealt: number)
	local ratio = Config.tier6.leechFromZone.ratioOfLifesteal

	for player, entry in roster do
		if entry.team == victim.team then
			continue
		end
		if not DownedService.isStanding(player) then
			continue
		end
		if not SkillTreeService.hasEffect(player, "leechFromZone") then
			continue
		end
		healTo(player, damageDealt * entry.stats.lifestealRatio * ratio)
	end
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
		if root == nil or not ZoneService.isOutside(root.Position) then
			continue
		end

		-- Palier 6 « Ancre » : le Lien couvre son allie meme contre la zone.
		if AbilityService.coversZone(player) then
			continue
		end

		local passed = dealDamage(entry, damageTakenBy(entry, amount, nil))

		if passed > 0 then
			zoneOwed[player] = (zoneOwed[player] or 0) + passed

			local now = os.clock()
			local toldAt = zoneToldAt[player] or 0
			local owed = zoneOwed[player]
			if (now - toldAt) >= Config.effects.zoneNumberIntervalSeconds and owed >= 1 then
				zoneToldAt[player] = now
				zoneOwed[player] = 0
				EffectsService.zone(root.Position + Vector3.new(0, 1.5, 0), owed, player)
			end
		end

		-- Sangsue, palier 6 : la zone travaille pour le Vampire. Le ratio est
		-- module dans Config.tier6, sinon il gagne la fin de manche en restant
		-- au centre a regarder l'autre bruler.
		if passed > 0 then
			leechFromZone(entry, passed)
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
	AbilityService.step(deltaSeconds)
	LoadoutService.step(deltaSeconds)
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
		strikeProfile[player] = nil
		lastAttackAt[player] = nil
		lastCombatAt[player] = nil
		lastDashAt[player] = nil
		zoneOwed[player] = nil
		zoneToldAt[player] = nil
	end)

	-- LE PUITS DE DEGATS. AbilityService ne requiert pas ce module (ce serait un
	-- cycle), donc c'est ce module qui lui donne de quoi blesser et soigner. Une
	-- mine et un brasier passent ainsi exactement par le meme chemin qu'un coup :
	-- meme reduction, meme plafond aux PV restants, meme passage par l'agonie.
	AbilityService.setDamageSink(function(entry: Entry, amount: number): number
		return dealDamage(entry, damageTakenBy(entry, amount, nil))
	end)
	AbilityService.setHealSink(healTo)
	AbilityService.init()

	-- Le meme puits pour l'equipement : une mine legere et une grenade
	-- traversent exactement le meme chemin qu'un coup d'epee, donc la reduction
	-- d'armure, le plafond aux PV restants et le passage par l'agonie
	-- s'appliquent sans que LoadoutService ait a les connaitre.
	LoadoutService.setDamageSink(function(entry: Entry, amount: number): number
		return dealDamage(entry, damageTakenBy(entry, amount, nil))
	end)
	LoadoutService.setHealSink(healTo)
	LoadoutService.init()

	attackRemote.OnServerEvent:Connect(onAttack)
	RunService.Heartbeat:Connect(onHeartbeat)
end

function CombatService.setRoster(entries: { Entry })
	roster = {}
	lastAttackAt = {}
	lastCombatAt = {}
	lastDashAt = {}
	zoneOwed = {}
	zoneToldAt = {}
	strikeProfile = {}
	for _, entry in entries do
		roster[entry.player] = entry
	end
	AbilityService.setRoster(entries)
	LoadoutService.setRoster(entries)
end

-- Les blocs de la Catapulte ne survivent pas a la manche. Appele entre deux
-- manches : une couverture heritee de la manche precedente serait un avantage
-- que personne n'a paye.
function CombatService.clearTemporary()
	local folder = tempFolder
	if folder ~= nil and folder.Parent ~= nil then
		folder:ClearAllChildren()
	end
	AbilityService.endRound()
	LoadoutService.endRound()
end

function CombatService.setActive(value: boolean)
	active = value
	AbilityService.setActive(value)
	LoadoutService.setActive(value)
	if value then
		AbilityService.beginRound()
		LoadoutService.beginRound()
	end
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
