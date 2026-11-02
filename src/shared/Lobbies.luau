--!strict
--[[
	Lobbies — les codes de partie privee.

	Logique pure : aucun require, aucune API Roblox. Elle fabrique un code,
	elle le nettoie, elle dit s'il est valide. Tout ce qui touche au reseau --
	reserver un serveur, ranger le code, teleporter -- vit dans MenuService.

	POURQUOI UN CODE, ET PAS LE CODE DE ROBLOX. `TeleportService:ReserveServer`
	rend un `accessCode` de plusieurs dizaines de caracteres, illisible et
	impossible a dicter a un ami. Le jeu fabrique donc un code court a lui,
	range la correspondance, et c'est le code court qui se partage.

	L'ALPHABET N'A NI ZERO NI UN, ni O ni I ni L. Un code se lit a voix haute
	ou se recopie depuis une capture d'ecran, et « 0 » contre « O » est
	l'erreur la plus facile du monde. Trente et un caracteres suffisent
	largement : cinq signes font vingt-huit millions de combinaisons, pour un
	code qui ne vit que quelques heures.
]]

local Lobbies = {}

Lobbies.ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

-- Le meme contrat que le tirage des classes : une fonction qui rend un entier
-- entre 1 et n. En jeu c'est `math.random`, dans les tests une suite choisie,
-- ce qui rend un code reproductible.
export type Rng = (number) -> number

function Lobbies.makeCode(rng: Rng, length: number): string
	local letters: { string } = {}
	local size = #Lobbies.ALPHABET
	for _ = 1, length do
		local pick = rng(size)
		table.insert(letters, string.sub(Lobbies.ALPHABET, pick, pick))
	end
	return table.concat(letters)
end

-- CE QUE LE JOUEUR TAPE N'EST PAS CE QU'IL VOULAIT TAPER. Minuscules, espaces,
-- tirets colles par un copier-coller depuis un message : tout ca doit devenir
-- un code, pas un refus. On jette ce qui n'est pas de l'alphabet au lieu de
-- renvoyer le joueur a son clavier.
function Lobbies.normalise(text: string, length: number): string
	local kept: { string } = {}
	for index = 1, #text do
		local char = string.upper(string.sub(text, index, index))
		if string.find(Lobbies.ALPHABET, char, 1, true) ~= nil then
			table.insert(kept, char)
			if #kept >= length then
				break
			end
		end
	end
	return table.concat(kept)
end

function Lobbies.isValid(code: string, length: number): boolean
	return #code == length and Lobbies.normalise(code, length) == code
end

-- Un code perime n'ouvre plus rien. La raison n'est pas la place occupee --
-- un code pese quelques octets -- mais qu'un serveur reserve de Roblox finit
-- par s'eteindre quand il se vide : rejoindre un code d'hier mene alors a un
-- serveur neuf et vide, ce qui se lit comme un bug.
function Lobbies.isExpired(createdAt: number, now: number, hours: number): boolean
	return now - createdAt > hours * 3600
end

return Lobbies
