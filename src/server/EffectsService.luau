--!strict
--[[
	EffectsService — ce que le serveur annonce aux clients pour que le combat se
	voie.

	POURQUOI CE MODULE EXISTE. Jusqu'ici, un coup porte etait invisible : la
	barre de vie descendait, et c'est tout. On ne savait pas si on avait touche,
	si on avait rate, ni si on venait d'encaisser. Un duel illisible ne peut pas
	etre juge amusant ou non, donc la question que tout le prototype doit
	trancher ne pouvait meme pas etre posee.

	CE N'EST QUE DU DECOR. Aucune de ces annonces ne change l'etat du jeu : le
	serveur a deja applique les degats quand il les envoie. Un client qui ne les
	recoit pas joue exactement la meme partie, en moins lisible — c'est pour ca
	que le RemoteEvent est de type Unreliable : ces messages partent souvent, et
	en perdre un pendant une rafale vaut mieux que retarder le reste.

	Le serveur n'envoie que des positions et des nombres, jamais d'instruction
	d'affichage : c'est le client qui decide a quoi ressemble un coup. Ca evite
	qu'une modification d'apparence demande de toucher au code du combat.
]]

local EffectsService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Remotes = Arena:WaitForChild("Remotes")
local effectsRemote = Remotes:WaitForChild("Effects") :: UnreliableRemoteEvent

export type Kind = "swing" | "hit" | "heal" | "spread" | "zone" | "down" | "revive" | "dash"

-- Un evenement d'affichage. `amount` n'est rempli que quand il y a un nombre a
-- montrer, et `target` quand l'effet se joue sur un personnage precis.
local function send(kind: Kind, position: Vector3, amount: number?, target: Player?)
	effectsRemote:FireAllClients({
		kind = kind,
		position = position,
		amount = amount,
		target = target,
	})
end

-- Un coup part, qu'il touche ou non. Frapper dans le vide doit se voir : c'est
-- ce qui apprend la portee de sa classe.
function EffectsService.swing(from: Vector3, direction: Vector3, hit: boolean)
	effectsRemote:FireAllClients({
		kind = "swing" :: Kind,
		position = from,
		direction = direction,
		hit = hit,
	})
end

function EffectsService.hit(position: Vector3, amount: number, target: Player?)
	send("hit", position, amount, target)
end

function EffectsService.spread(position: Vector3, amount: number, target: Player?)
	send("spread", position, amount, target)
end

function EffectsService.heal(position: Vector3, amount: number, target: Player?)
	send("heal", position, amount, target)
end

function EffectsService.zone(position: Vector3, amount: number, target: Player?)
	send("zone", position, amount, target)
end

function EffectsService.down(position: Vector3, target: Player?)
	send("down", position, nil, target)
end

function EffectsService.revive(position: Vector3, target: Player?)
	send("revive", position, nil, target)
end

function EffectsService.dash(from: Vector3, direction: Vector3)
	effectsRemote:FireAllClients({
		kind = "dash" :: Kind,
		position = from,
		direction = direction,
	})
end

return EffectsService
