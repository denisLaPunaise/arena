--!strict
--[[
	MapRotation — quelle map pour la prochaine partie.

	Logique pure : aucun require, aucune API Roblox. Les noms des maps
	disponibles arrivent en argument, le tirage aussi.

	LA REGLE : au hasard parmi les maps disponibles, mais JAMAIS DEUX FOIS DE
	SUITE la meme. Une rotation fixe s'apprend (« apres le Bazar vient la
	Serre ») et donne un avantage a qui la connait ; un hasard sans memoire
	ressert la meme map trois fois et donne l'impression qu'il n'y en a qu'une.
	Decide le 4 novembre 2026, sans Josh.
]]

local MapRotation = {}

-- Les noms tries : le tirage doit dependre du seul generateur, pas de l'ordre
-- dans lequel Roblox rend les enfants d'un dossier.
function MapRotation.pick(names: { string }, last: string?, rng: (number) -> number): string?
	if #names == 0 then
		return nil
	end
	local sorted = table.clone(names)
	table.sort(sorted)
	if #sorted == 1 then
		return sorted[1]
	end
	local candidates: { string } = {}
	for _, name in sorted do
		if name ~= last then
			table.insert(candidates, name)
		end
	end
	if #candidates == 0 then
		return sorted[1]
	end
	return candidates[rng(#candidates)]
end

return MapRotation
