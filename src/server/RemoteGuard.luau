--!strict
--[[
	RemoteGuard — le garde-fou contre l'inondation, a UN SEUL endroit.

	Le controle du 3 novembre 2026 a trouve quatre remotes sur huit sans aucune
	limite de debit : le salon, la progression, le bac a sable et le tirage.
	Personne ne pouvait en tirer de la puissance — tout est valide cote serveur
	— mais un client bricole pouvait faire travailler le serveur pour rien, et
	le salon annonce a TOUS les autres a chaque message. Une porte a fermer
	avant la publication.

	Chaque service enveloppe son gestionnaire : `RemoteGuard.wrap("Lobby", f)`.
	Un message en trop est jete sans reponse : un client honnete n'en envoie
	jamais autant, et repondre a une inondation serait la nourrir.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Config = require(Arena:WaitForChild("Config"))
local Throttle = require(Arena:WaitForChild("Throttle"))

local RemoteGuard = {}

local bucketsByRemote: { [string]: { [Player]: Throttle.Bucket } } = {}
local warned: { [Player]: boolean } = {}

function RemoteGuard.wrap(
	remoteName: string,
	handler: (Player, ...any) -> ()
): (Player, ...any) -> ()
	local buckets: { [Player]: Throttle.Bucket } = {}
	bucketsByRemote[remoteName] = buckets
	local settings = Config.network.remoteThrottle

	return function(player: Player, ...: any)
		if not Throttle.allow(buckets, player, os.clock(), settings) then
			-- Une seule ligne par joueur et par session : une inondation qui
			-- remplit aussi la console cacherait tout le reste.
			if not warned[player] then
				warned[player] = true
				warn(
					string.format(
						"[Arena] %s envoie trop de messages sur %s : ignorés",
						player.Name,
						remoteName
					)
				)
			end
			return
		end
		handler(player, ...)
	end
end

Players.PlayerRemoving:Connect(function(player: Player)
	for _, buckets in bucketsByRemote do
		buckets[player] = nil
	end
	warned[player] = nil
end)

return RemoteGuard
