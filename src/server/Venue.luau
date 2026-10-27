--!strict
--[[
	Venue — ou est-ce qu'on joue, et est-ce que ca compte.

	Deux lignes de Roblox, et un seul endroit qui les dit. Trois choses ont
	besoin de la reponse : le bac a sable pour s'autoriser, la progression pour
	payer ou non, la boucle de partie pour laisser choisir son camp. La meme
	condition semee dans trois fichiers ne se relit pas — c'est la regle des
	planchers de Modifiers, appliquee a une question de lieu.

	CE QUE LA FICHE A DECIDE, et que personne ne lisait : « le classe est le
	mode par defaut, les parties privees entre amis sont natives sur Roblox et
	ne comptent pas : c'est la qu'on teste. » Cette intention vivait dans
	Config.elo.privateMatchesRanked et dans Rating.counts, appeles par aucun
	service — donc une partie d'essai entre amis deplacait les vrais
	classements. C'est ce module qui ferme le trou.

	STUDIO COMPTE COMME PRIVE. Sans ca, chacun de mes tests deplacerait un
	classement reel, et c'est exactement ce qu'on ne veut pas d'un test. Pour
	verifier le chemin du classe malgre tout, il y a les deux interrupteurs de
	Config plutot qu'une exception cachee ici.
]]

local Venue = {}

local RunService = game:GetService("RunService")

-- Un serveur prive, ou Studio. `PrivateServerId` est rempli pour un serveur
-- reserve comme pour un serveur prive achete par un joueur ; il est vide en
-- partie publique.
function Venue.isPrivate(): boolean
	return RunService:IsStudio() or game.PrivateServerId ~= ""
end

-- La phrase a afficher quand rien n'est en jeu. Elle existe parce qu'une
-- partie qui ne compte pas et ne le dit pas se lit comme un bug : le joueur
-- gagne, ne voit aucune piece arriver, et n'a aucun moyen de savoir pourquoi.
function Venue.describe(): string
	if Venue.isPrivate() then
		return "Partie privée  ·  aucune pièce, aucun classement"
	end
	return ""
end

return Venue
