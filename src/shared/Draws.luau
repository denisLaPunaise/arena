--!strict
--[[
	Draws — le tirage d'objets, ses cotes, et l'affichage que Roblox exige.

	Logique pure : aucun require, aucune API Roblox. Le hasard arrive en
	argument (`rng(n)` rend un entier entre 1 et n), donc un test peut verifier
	la garantie du septieme tirage sans attendre qu'elle tombe.

	LA REGLE DE CONCEPTION : equiprobabilite stricte. Aucun objet n'est un
	jackpot, aucun n'est un dechet. La puissance est portee par le COUT EN
	POINTS, jamais par la rarete — c'est le premier principe du projet, et
	c'est ce qui rend les cotes si simples a afficher : une seule ligne pour
	tout le catalogue.

	CE QUE LA POLITIQUE DE ROBLOX DEMANDE, et que ce fichier produit.
	Les pieces de tirage s'achetent en Robux, donc le tirage est un « paid
	random item » meme indirectement, et les exigences sont precises :

	  - afficher CHAQUE resultat possible et sa probabilite, AVANT l'achat,
	    avec un total qui fait exactement 100 %. Les objets de meme
	    probabilite peuvent etre groupes sous une seule ligne, ce qui est
	    exactement notre cas.
	  - tout resultat doit donner quelque chose. Un tirage ou le joueur perd
	    simplement sa mise est interdit. Notre doublon converti en fragments
	    satisfait ca : NE JAMAIS retirer cette regle sans la remplacer.
	  - la garantie du septieme tirage est un modificateur de probabilite :
	    son effet doit etre explique chiffre, et les cotes affichees doivent
	    SE METTRE A JOUR quand elle est active. C'est ce que fait `odds`.

	Les sources sont dans docs/EQUILIBRAGE.md.
]]

local Draws = {}

export type Result = {
	itemId: string,
	isNew: boolean,
	fragments: number,
	-- Le compteur APRES ce tirage, a reporter dans le profil du joueur.
	pullsSinceNew: number,
}

export type OddsLine = {
	label: string,
	percent: number,
	detail: string,
}

export type Odds = {
	guaranteed: boolean,
	pullsUntilGuarantee: number,
	lines: { OddsLine },
	total: number,
	note: string,
}

--------------------------------------------------------------------------------
-- LE VIVIER
--------------------------------------------------------------------------------

local function owns(owned: { [string]: boolean }, itemId: string): boolean
	return owned[itemId] == true
end

function Draws.poolSize(config): number
	return #config.items
end

function Draws.newItems(config, owned: { [string]: boolean }): { string }
	local found: { string } = {}
	for _, item in config.items do
		if not owns(owned, item.id) then
			table.insert(found, item.id)
		end
	end
	return found
end

function Draws.ownedCount(config, owned: { [string]: boolean }): number
	local count = 0
	for _, item in config.items do
		if owns(owned, item.id) then
			count += 1
		end
	end
	return count
end

function Draws.isComplete(config, owned: { [string]: boolean }): boolean
	return Draws.ownedCount(config, owned) >= #config.items
end

--------------------------------------------------------------------------------
-- LA GARANTIE
--------------------------------------------------------------------------------

-- Vrai si le PROCHAIN tirage est force sur un objet non debloque. Sans ce
-- filet, la fin de collection coute pres de deux cents tirages ; avec, la
-- collection complete passe d'environ 290 a 175.
--
-- Le compteur se remet a zero des qu'un objet neuf tombe, naturellement ou par
-- la garantie : sinon on obtient des rafales de nouveautes tous les sept
-- tirages, puis plus rien.
function Draws.isGuaranteed(config, pullsSinceNew: number): boolean
	return pullsSinceNew >= (config.draws.guaranteedNewEveryDraws - 1)
end

function Draws.pullsUntilGuarantee(config, pullsSinceNew: number): number
	return math.max((config.draws.guaranteedNewEveryDraws - 1) - pullsSinceNew, 0)
end

--------------------------------------------------------------------------------
-- LES COTES, TELLES QU'ELLES S'AFFICHENT
--------------------------------------------------------------------------------

-- Les resultats possibles et leur probabilite, pour l'ecran d'achat.
--
-- Deux lignes seulement, et c'est permis : les objets de meme probabilite se
-- groupent sous une seule ligne, et les notres sont tous equiprobables. Le
-- groupement se fait par RESULTAT — objet neuf, ou doublon converti — parce
-- que c'est ce que le joueur recoit, et c'est ce que la regle demande
-- d'annoncer.
--
-- Le total fait exactement 100 % par construction : les deux lignes comptent
-- des objets du meme vivier, et leurs effectifs s'additionnent au vivier.
function Draws.odds(config, owned: { [string]: boolean }, pullsSinceNew: number): Odds
	local pool = Draws.poolSize(config)
	local fresh = #Draws.newItems(config, owned)
	local duplicates = pool - fresh
	local fragments = config.cosmetics.fragmentsPerDuplicate
	local guaranteed = Draws.isGuaranteed(config, pullsSinceNew) and fresh > 0

	local lines: { OddsLine } = {}

	if guaranteed then
		-- La garantie est active : les cotes DOIVENT le refleter, c'est
		-- litteralement ce que la politique demande d'un modificateur de
		-- probabilite.
		table.insert(lines, {
			label = "Objet non débloqué",
			percent = 100,
			detail = string.format(
				"%d objets possibles, %.2f %% chacun — garantie du %de tirage active",
				fresh,
				100 / fresh,
				config.draws.guaranteedNewEveryDraws
			),
		})
	elseif fresh == 0 then
		-- Collection complete : tout devient des fragments, et c'est dit avant
		-- l'achat. Un tirage qui ne peut plus rien apporter de neuf doit
		-- l'annoncer.
		table.insert(lines, {
			label = string.format("Doublon converti en %d fragments", fragments),
			percent = 100,
			detail = string.format(
				"Collection complète : %d objets sur %d débloqués",
				pool,
				pool
			),
		})
	else
		table.insert(lines, {
			label = "Objet non débloqué",
			percent = (fresh / pool) * 100,
			detail = string.format("%d objets possibles, %.2f %% chacun", fresh, 100 / pool),
		})
		-- Une ligne a zero pour cent n'est pas un resultat possible, donc on
		-- ne l'affiche pas. C'est le cas d'un compte tout neuf, ou rien n'est
		-- encore debloque et ou le doublon ne peut pas tomber.
		if duplicates > 0 then
			table.insert(lines, {
				label = string.format("Doublon converti en %d fragments", fragments),
				percent = (duplicates / pool) * 100,
				detail = string.format(
					"%d objets déjà débloqués, %.2f %% chacun",
					duplicates,
					100 / pool
				),
			})
		end
	end

	local total = 0
	for _, line in lines do
		total += line.percent
	end

	return {
		guaranteed = guaranteed,
		pullsUntilGuarantee = Draws.pullsUntilGuarantee(config, pullsSinceNew),
		lines = lines,
		total = total,
		-- L'arrondi est permis a condition d'etre mentionne. Les pourcentages
		-- par objet sont arrondis au centieme, les pourcentages de ligne ne le
		-- sont pas : ce sont eux qui font 100.
		note = string.format(
			"Tous les objets ont la même probabilité. Un tirage sur %d donne obligatoirement"
				.. " un objet non débloqué, et le compteur repart à zéro dès qu'un objet neuf"
				.. " tombe. Les pourcentages par objet sont arrondis au centième ;"
				.. " le total des résultats fait exactement 100 %%.",
			config.draws.guaranteedNewEveryDraws
		),
	}
end

--------------------------------------------------------------------------------
-- LE TIRAGE
--------------------------------------------------------------------------------

-- Un tirage. `rng(n)` doit rendre un entier entre 1 et n.
function Draws.draw(
	config,
	owned: { [string]: boolean },
	pullsSinceNew: number,
	rng: (number) -> number
): Result
	local fresh = Draws.newItems(config, owned)
	local fragments = config.cosmetics.fragmentsPerDuplicate

	-- La garantie ne tire que dans les objets non debloques. Quand il n'en
	-- reste aucun, elle ne s'applique pas : il n'y a plus rien a garantir.
	if Draws.isGuaranteed(config, pullsSinceNew) and #fresh > 0 then
		local itemId = fresh[rng(#fresh)]
		return { itemId = itemId, isNew = true, fragments = 0, pullsSinceNew = 0 }
	end

	local item = config.items[rng(#config.items)]
	local isNew = not owns(owned, item.id)

	return {
		itemId = item.id,
		isNew = isNew,
		-- Tout resultat donne quelque chose : l'objet, ou des fragments.
		fragments = if isNew then 0 else fragments,
		pullsSinceNew = if isNew then 0 else pullsSinceNew + 1,
	}
end

-- Applique un resultat a un profil. Rend un NOUVEAU profil : rien n'est
-- modifie sur place, pour la meme raison que l'arbre de competences — un etat
-- modifie en place se cumule tout seul quand on le relit.
function Draws.apply(
	owned: { [string]: boolean },
	fragments: number,
	result: Result
): ({ [string]: boolean }, number)
	local next = table.clone(owned)
	next[result.itemId] = true
	return next, fragments + result.fragments
end

--------------------------------------------------------------------------------
-- LES TIRAGES D'OUVERTURE
--------------------------------------------------------------------------------

-- Les trois tirages offerts a l'ouverture du compte : un objet de chaque type
-- essentiel, et UNIQUEMENT parmi les objets a cout faible.
--
-- La contrainte de cout n'est pas de la pingrerie : sans elle, un debutant
-- tire l'arme a sept points et se retrouve avec un assemblage impossible a
-- completer dans le budget. Le jeu lui aurait donne son meilleur objet et une
-- impression de pauvrete.
function Draws.starterItems(config, rng: (number) -> number): { string }
	local given: { string } = {}

	for _, categoryId in config.draws.starterDrawsCategories do
		local candidates: { any } = {}
		for _, item in config.items do
			if
				item.category == categoryId
				and item.cost <= config.draws.starterDrawsMaxItemCost
			then
				table.insert(candidates, item)
			end
		end
		if #candidates > 0 then
			table.insert(given, candidates[rng(#candidates)].id)
		end
	end

	return given
end

return Draws
