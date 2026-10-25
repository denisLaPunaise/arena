--!strict
--[[
	Bootstrap — point d'entree client.

	Meme role que son equivalent serveur : prouver que la synchronisation
	atteint aussi StarterPlayerScripts. Toute l'interface et toutes les entrees
	joueur se brancheront ici.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Config = require(Arena:WaitForChild("Config"))

print(
	string.format(
		"[Arena] Client démarré pour %s — réglages version %d",
		Players.LocalPlayer.Name,
		Config.version
	)
)
