--!strict
--[[
	Status — ce qui colle a un combattant pendant quelques secondes.

	Logique pure : aucun require, aucune API Roblox. Un combattant est un etat
	anonyme, comme dans Downed ; StatusService fait la traduction vers les
	Humanoid.

	QUATRE EFFETS, ET PAS UN DE PLUS :

	    slow    la vitesse est multipliee, le temps que ca dure
	    stun    on ne peut ni frapper ni avancer
	    poison  des degats par seconde, qui ne viennent de personne en face
	    regen   des soins par seconde

	POURQUOI CE MODULE EXISTE. Onze objets du catalogue posent un de ces quatre
	effets — la dague empoisonnee, le pistolet a flechettes, les chausse-trappes,
	la grenade aveuglante, la fiole regenerante, le dome de soin, la grenade
	incendiaire... Sans un endroit commun, chacun aurait ecrit sa propre boucle,
	avec sa propre idee de ce qui se passe quand deux se superposent. C'est la
	meme raison que les planchers de Modifiers : une regle de ce genre n'a le
	droit d'exister qu'une fois.

	UN SEUL EFFET PAR SORTE, ET C'EST LA DECISION QUI COMPTE. Deux ralentissements
	ne se multiplient pas : on garde le plus fort, et la duree la plus longue des
	deux. Trois raisons, et la troisieme suffirait :

	  - des ralentissements qui se multiplient font une immobilisation, qui est
	    une autre mecanique. Personne ne l'a achetee, et deux objets a 2 points
	    donneraient gratuitement ce qu'une grenade aveuglante a 3 points fait
	    payer ;
	  - un poison qui s'empile transforme une arme secondaire a 3 points en la
	    plus forte du catalogue des qu'on touche deux fois ;
	  - et surtout : ca se voit en jouant comme une panne, pas comme une regle.
	    Un joueur ralenti a 10 % de sa vitesse croit que le jeu a casse.

	LE TEMPS ENTRE PAR ARGUMENT. Ce module ne lit aucune horloge : `now` est
	toujours passe. C'est ce qui permet aux tests de faire passer dix secondes
	sans attendre dix secondes.
]]

local Status = {}

Status.SLOW = "slow"
Status.STUN = "stun"
Status.POISON = "poison"
Status.REGEN = "regen"

export type Effect = {
	kind: string,
	-- L'instant ou l'effet s'arrete, dans la meme horloge que `now`.
	until_: number,
	-- Pour `slow`, la part de vitesse QUI RESTE (0,6 = 40 % plus lent). Pour
	-- `poison` et `regen`, les points par seconde. Ignore pour `stun`.
	magnitude: number,
}

export type State = {
	effects: { [string]: Effect },
}

function Status.create(): State
	return { effects = {} }
end

-- La sorte est-elle une de celles qu'on sait appliquer ? Le serveur passe par
-- la avant de poser quoi que ce soit : un objet qui demanderait un effet
-- inconnu ne ferait rien du tout, en silence, et c'est exactement la panne des
-- branches creuses.
function Status.isKnown(kind: string): boolean
	return kind == Status.SLOW
		or kind == Status.STUN
		or kind == Status.POISON
		or kind == Status.REGEN
end

-- Le plus fort des deux l'emporte, et la duree la plus longue aussi. Les deux
-- sont pris separement : un poison faible et long qui arrive sur un poison fort
-- et court laisse le fort, mais etend la duree. C'est le choix le plus lisible
-- en jouant — un effet ne s'affaiblit jamais parce qu'on l'a repose.
local function stronger(kind: string, left: number, right: number): number
	if kind == Status.SLOW then
		-- Pour un ralentissement, « plus fort » veut dire une vitesse restante
		-- PLUS PETITE. C'est le seul des quatre a marcher dans ce sens, et
		-- l'oublier donnerait l'inverse exact de ce qu'on veut.
		return math.min(left, right)
	end
	return math.max(left, right)
end

-- Pose un effet, ou renforce celui qui est deja la. Renvoie faux si la sorte
-- est inconnue ou si la duree est nulle, pour que l'appelant puisse le dire.
function Status.apply(
	state: State,
	kind: string,
	seconds: number,
	magnitude: number,
	now: number
): boolean
	if not Status.isKnown(kind) or seconds <= 0 then
		return false
	end

	local current = state.effects[kind]
	if current == nil then
		state.effects[kind] = {
			kind = kind,
			until_ = now + seconds,
			magnitude = magnitude,
		}
		return true
	end

	current.until_ = math.max(current.until_, now + seconds)
	current.magnitude = stronger(kind, current.magnitude, magnitude)
	return true
end

-- Retire ce qui est arrive a terme. Renvoie la liste des sortes qui viennent de
-- finir, parce que l'appelant a quelque chose a defaire pour chacune : rendre
-- sa vitesse, degeler le personnage.
function Status.expire(state: State, now: number): { string }
	local done: { string } = {}
	for kind, effect in state.effects do
		if now >= effect.until_ then
			table.insert(done, kind)
		end
	end
	for _, kind in done do
		state.effects[kind] = nil
	end
	table.sort(done)
	return done
end

function Status.has(state: State, kind: string, now: number): boolean
	local effect = state.effects[kind]
	return effect ~= nil and now < effect.until_
end

-- La part de vitesse qui reste. Un etourdissement vaut zero : il immobilise,
-- donc il n'a pas besoin d'un ralentissement en plus pour ca.
function Status.speedRatio(config, state: State, now: number): number
	if Status.has(state, Status.STUN, now) then
		return 0
	end

	local slow = state.effects[Status.SLOW]
	if slow == nil or now >= slow.until_ then
		return 1
	end

	return math.clamp(slow.magnitude, config.status.minSpeedRatio, 1)
end

function Status.isStunned(state: State, now: number): boolean
	return Status.has(state, Status.STUN, now)
end

-- Ce que les effets continus doivent retirer et rendre pendant cet intervalle.
-- Les deux sont rendus separement plutot que soustraits l'un de l'autre : une
-- fiole regenerante qui annule un poison exactement n'afficherait aucun nombre,
-- et le joueur ne saurait pas qu'il est empoisonne.
function Status.tick(state: State, now: number, deltaSeconds: number): (number, number)
	if deltaSeconds <= 0 then
		return 0, 0
	end

	local damage = 0
	local heal = 0

	local poison = state.effects[Status.POISON]
	if poison ~= nil and now < poison.until_ then
		damage = poison.magnitude * deltaSeconds
	end

	local regen = state.effects[Status.REGEN]
	if regen ~= nil and now < regen.until_ then
		heal = regen.magnitude * deltaSeconds
	end

	return damage, heal
end

-- Tout retirer d'un coup, a la fin d'une manche. Renvoie les sortes retirees,
-- pour la meme raison qu'`expire` : il y a quelque chose a defaire.
function Status.clear(state: State): { string }
	local kinds: { string } = {}
	for kind in state.effects do
		table.insert(kinds, kind)
	end
	table.sort(kinds)
	state.effects = {}
	return kinds
end

-- Ce que l'interface affiche. Trie, pour que deux appels de suite ne changent
-- pas l'ordre a l'ecran.
function Status.describe(state: State, now: number): { { kind: string, secondsLeft: number } }
	local out: { { kind: string, secondsLeft: number } } = {}
	for kind, effect in state.effects do
		if now < effect.until_ then
			table.insert(out, { kind = kind, secondsLeft = effect.until_ - now })
		end
	end
	table.sort(out, function(left, right): boolean
		return left.kind < right.kind
	end)
	return out
end

return Status
