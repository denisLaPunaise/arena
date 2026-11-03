--!strict
--[[
	Throttle — un seau de jetons, pour les messages que les clients envoient.

	Logique pure : aucun require, aucune API Roblox. L'horloge arrive en
	argument, ce qui permet aux tests de faire passer le temps.

	POURQUOI UN SEAU ET PAS UN INTERVALLE MINIMAL. Le premier garde-fou du
	projet refusait tout message arrive moins de 0,1 s apres le precedent. Un
	panneau qui envoie « ouvre » puis « donne-moi l'etat » dans la meme image
	perdrait alors le second EN SILENCE, et le panneau resterait vide — la pire
	sorte de bug, parce qu'elle ne se reproduit qu'au hasard du reseau. Un seau
	laisse passer une rafale courte (un double clic, deux messages d'un meme
	geste) et ne coupe que ce qu'aucun humain ne produit : un debit tenu.
]]

local Throttle = {}

export type Bucket = {
	tokens: number,
	at: number,
}

export type Settings = {
	burst: number,
	perSecond: number,
}

-- Vrai si ce message passe. Le seau se remplit de `perSecond` jetons par
-- seconde, jamais au-dela de `burst`, et chaque message en coute un.
function Throttle.allow(
	buckets: { [any]: Bucket },
	key: any,
	now: number,
	settings: Settings
): boolean
	local bucket = buckets[key]
	if bucket == nil then
		bucket = { tokens = settings.burst, at = now }
		buckets[key] = bucket
	end

	-- Une horloge qui recule (elle ne devrait pas) ne doit pas vider le seau.
	local elapsed = math.max(now - bucket.at, 0)
	bucket.tokens = math.min(settings.burst, bucket.tokens + (elapsed * settings.perSecond))
	bucket.at = now

	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

return Throttle
