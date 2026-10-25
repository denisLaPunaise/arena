--!strict
--[[
	Downed — l'agonie et le relevement.

	Logique pure : aucun require, aucune API Roblox. Un combattant est
	represente par une table avec un identifiant, une equipe et un etat ;
	DownedService fait le lien avec les Humanoid, pose la vitesse de reptation
	et surveille les distances. Ici on ne decide que des etats.

	Trois etats, et un seul chemin entre eux :

	    debout --(PV a zero)--> a terre --(fenetre ecoulee)--> elimine
	       ^                       |  --(acheve par l'ennemi)--^
	       |                       |
	       +---(releve par un coequipier)

	Les regles qui comptent, et pourquoi :

	- Un joueur a terre peut etre acheve. Sans ca, l'attaquant n'a aucun moyen
	  d'empecher un relevement, et la classe qui releve devient incontournable.
	- Le moindre degat sur celui qui releve remet la barre a zero. Relever au
	  milieu d'un echange de coups doit etre impossible, sinon la fenetre
	  d'agonie annule le fait d'avoir gagne l'echange.
	- Si plus personne dans l'equipe n'est debout, les joueurs a terre sont
	  perdus d'avance : on les elimine tout de suite plutot que d'imposer dix
	  secondes de temps mort a tout le monde.
]]

local Downed = {}

export type Status = "standing" | "downed" | "out"

export type Fighter = {
	id: string,
	team: string,
	status: Status,
	-- L'horloge du moment ou il est tombe, pour mesurer la fenetre.
	downedAt: number?,
	-- Secondes de relevement deja accumulees.
	reviveProgress: number,
}

function Downed.create(id: string, team: string): Fighter
	return {
		id = id,
		team = team,
		status = "standing",
		downedAt = nil,
		reviveProgress = 0,
	}
end

local function putOut(fighter: Fighter)
	fighter.status = "out"
	fighter.downedAt = nil
	fighter.reviveProgress = 0
end

-- Les PV sont tombes a zero. Quand l'agonie est coupee, le joueur est elimine
-- directement : la manche revient alors a l'elimination de l'etape 2.
function Downed.knockDown(config, fighter: Fighter, now: number): Status
	if fighter.status ~= "standing" then
		return fighter.status
	end

	if not config.downed.enabled then
		putOut(fighter)
		return fighter.status
	end

	fighter.status = "downed"
	fighter.downedAt = now
	fighter.reviveProgress = 0
	return fighter.status
end

function Downed.finish(config, fighter: Fighter): boolean
	if fighter.status ~= "downed" or not config.downed.canBeFinished then
		return false
	end
	putOut(fighter)
	return true
end

-- Secondes qu'il reste avant l'elimination. Zero des que la fenetre est passee.
function Downed.secondsLeft(config, fighter: Fighter, now: number): number
	local downedAt = fighter.downedAt
	if fighter.status ~= "downed" or downedAt == nil then
		return 0
	end
	return math.max(config.downed.windowSeconds - (now - downedAt), 0)
end

-- Renvoie vrai si la fenetre vient de se refermer sur ce combattant.
function Downed.expire(config, fighter: Fighter, now: number): boolean
	if fighter.status ~= "downed" then
		return false
	end
	if Downed.secondsLeft(config, fighter, now) > 0 then
		return false
	end
	putOut(fighter)
	return true
end

-- Avance le relevement. Renvoie vrai quand il aboutit.
function Downed.addReviveProgress(config, fighter: Fighter, deltaSeconds: number): boolean
	if fighter.status ~= "downed" then
		return false
	end

	fighter.reviveProgress += deltaSeconds
	if fighter.reviveProgress < config.downed.reviveSeconds then
		return false
	end

	fighter.status = "standing"
	fighter.downedAt = nil
	fighter.reviveProgress = 0
	return true
end

function Downed.interruptRevive(config, fighter: Fighter)
	if not config.downed.reviveInterruptedByDamage then
		return
	end
	fighter.reviveProgress = 0
end

-- Avancement du relevement entre 0 et 1, pour la barre affichee.
function Downed.reviveRatio(config, fighter: Fighter): number
	if fighter.status ~= "downed" or config.downed.reviveSeconds <= 0 then
		return 0
	end
	return math.clamp(fighter.reviveProgress / config.downed.reviveSeconds, 0, 1)
end

function Downed.reviveHealth(config, maxHealth: number): number
	return maxHealth * config.downed.reviveHealthRatio
end

function Downed.crawlSpeed(config, walkSpeed: number): number
	return walkSpeed * config.downed.crawlSpeedRatio
end

--------------------------------------------------------------------------------
-- LECTURE D'ENSEMBLE
--------------------------------------------------------------------------------

function Downed.countWithStatus(fighters: { Fighter }, team: string, status: Status): number
	local count = 0
	for _, fighter in fighters do
		if fighter.team == team and fighter.status == status then
			count += 1
		end
	end
	return count
end

-- Quelqu'un est encore debout dans cette equipe, donc capable de relever.
function Downed.hasReviver(fighters: { Fighter }, team: string): boolean
	return Downed.countWithStatus(fighters, team, "standing") > 0
end

function Downed.isEliminated(fighters: { Fighter }, team: string): boolean
	local present = false
	for _, fighter in fighters do
		if fighter.team == team then
			present = true
			if fighter.status ~= "out" then
				return false
			end
		end
	end
	return present
end

-- Elimine les joueurs a terre dont l'equipe n'a plus personne pour les relever.
-- Renvoie la liste de ceux qui viennent d'etre elimines, pour pouvoir
-- l'annoncer.
function Downed.collapseTeamsWithoutReviver(config, fighters: { Fighter }): { Fighter }
	local collapsed: { Fighter } = {}
	if not config.downed.endRoundWhenNoReviverLeft then
		return collapsed
	end

	for _, fighter in fighters do
		if fighter.status == "downed" and not Downed.hasReviver(fighters, fighter.team) then
			putOut(fighter)
			table.insert(collapsed, fighter)
		end
	end

	return collapsed
end

-- L'equipe gagnante, ou nil si la manche continue. Nil aussi quand tout le
-- monde est elimine : une manche nulle n'attribue aucun point.
function Downed.roundWinner(fighters: { Fighter }): string?
	local alive: { [string]: boolean } = {}
	for _, fighter in fighters do
		if fighter.status ~= "out" then
			alive[fighter.team] = true
		end
	end

	local winner: string? = nil
	local teamsAlive = 0
	for team in alive do
		winner = team
		teamsAlive += 1
	end

	return if teamsAlive == 1 then winner else nil
end

-- Vrai des qu'au plus une equipe tient encore debout ou a terre.
function Downed.roundIsOver(fighters: { Fighter }): boolean
	local alive: { [string]: boolean } = {}
	local teamsAlive = 0
	for _, fighter in fighters do
		if fighter.status ~= "out" and not alive[fighter.team] then
			alive[fighter.team] = true
			teamsAlive += 1
		end
	end
	return teamsAlive <= 1
end

return Downed
