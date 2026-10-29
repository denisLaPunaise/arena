--!strict
--[[
	Loadout — le budget d'equipement : ce qu'on peut porter, et ce que ca change.

	Logique pure : aucun require, aucune API Roblox. La configuration et la
	liste des objets choisis arrivent en argument, donc un test peut verifier
	qu'un assemblage a treize points est refuse sans ouvrir Studio.

	LES CINQ REGLES, et elles ne se negocient pas :

	    1. douze points, jamais un de plus
	    2. au moins une arme principale
	    3. une seule arme principale, une seule secondaire, une seule armure
	    4. jamais deux fois le meme objet
	    5. six objets au maximum  (une contrainte d'ergonomie, pas
	       d'equilibrage : beaucoup de joueurs Roblox sont sur telephone)

	Toutes les cinq sont dans Config.loadout, donc toutes les cinq se reglent
	sans toucher a ce fichier.

	CE QU'UN OBJET FAIT. Il ne remplace pas la classe, il la deforme. Ses
	chiffres sont des facteurs (`scale`) et des decalages (`offset`) appliques
	aux statistiques de la classe, exactement comme une branche d'arbre. Un
	Vampire au marteau frappe fort et lentement mais garde son vol de vie.

	L'ARME SECONDAIRE sert automatiquement quand la cible est hors de portee de
	la principale. C'est pour ca que ce module renvoie DEUX jeux de
	statistiques et pas un : `weaponDeltas` pour chacune, et le serveur choisit
	selon la distance au moment du coup.
]]

local Loadout = {}

export type Deltas = {
	scale: { [string]: number },
	offset: { [string]: number },
}

export type Check = {
	ok: boolean,
	reason: string?,
	spent: number,
	left: number,
}

export type Usable = {
	slot: number,
	itemId: string,
	item: any,
}

--------------------------------------------------------------------------------
-- LE CATALOGUE
--------------------------------------------------------------------------------

function Loadout.all(config): { any }
	return config.items
end

function Loadout.find(config, itemId: string): any?
	for _, item in config.items do
		if item.id == itemId then
			return item
		end
	end
	return nil
end

function Loadout.byCategory(config, categoryId: string): { any }
	local found: { any } = {}
	for _, item in config.items do
		if item.category == categoryId then
			table.insert(found, item)
		end
	end
	return found
end

function Loadout.categories(config): { any }
	return config.loadout.categories
end

function Loadout.categoryLabel(config, categoryId: string): string
	for _, category in config.loadout.categories do
		if category.id == categoryId then
			return category.label
		end
	end
	return categoryId
end

--------------------------------------------------------------------------------
-- LE PRIX
--------------------------------------------------------------------------------

function Loadout.hasAffinity(config, classId: string?, itemId: string): boolean
	if classId == nil then
		return false
	end
	local list = config.itemAffinities[classId]
	if list == nil then
		return false
	end
	for _, id in list do
		if id == itemId then
			return true
		end
	end
	return false
end

-- Le prix d'un objet POUR CETTE CLASSE. L'affinite retire un point, et le prix
-- ne descend jamais sous un : un objet gratuit serait pris par tout le monde,
-- et c'est pour ca qu'aucune affinite ne porte sur un objet a un point.
function Loadout.costOf(config, item: any, classId: string?): number
	local cost = item.cost
	if Loadout.hasAffinity(config, classId, item.id) then
		cost -= config.loadout.affinityDiscount
	end
	return math.max(cost, 1)
end

function Loadout.costOfId(config, itemId: string, classId: string?): number
	local item = Loadout.find(config, itemId)
	if item == nil then
		return 0
	end
	return Loadout.costOf(config, item, classId)
end

function Loadout.spent(config, itemIds: { string }, classId: string?): number
	local total = 0
	for _, itemId in itemIds do
		total += Loadout.costOfId(config, itemId, classId)
	end
	return total
end

function Loadout.pointsLeft(config, itemIds: { string }, classId: string?): number
	return config.loadout.budgetPoints - Loadout.spent(config, itemIds, classId)
end

--------------------------------------------------------------------------------
-- LA VALIDATION
--------------------------------------------------------------------------------

local function countByCategory(config, itemIds: { string }): { [string]: number }
	local counts: { [string]: number } = {}
	for _, itemId in itemIds do
		local item = Loadout.find(config, itemId)
		if item ~= nil then
			counts[item.category] = (counts[item.category] or 0) + 1
		end
	end
	return counts
end

-- Verifie un assemblage entier. Le message de refus est en francais et nomme la
-- regle enfreinte : c'est ce que le joueur lit, et c'est aussi ce que le
-- serveur imprime quand un client essaie de tricher.
function Loadout.validate(config, itemIds: { string }, classId: string?): Check
	local rules = config.loadout
	local spent = Loadout.spent(config, itemIds, classId)
	local check: Check = {
		ok = false,
		reason = nil,
		spent = spent,
		left = rules.budgetPoints - spent,
	}

	local seen: { [string]: boolean } = {}
	for _, itemId in itemIds do
		if Loadout.find(config, itemId) == nil then
			check.reason = string.format("Objet inconnu : %s", itemId)
			return check
		end
		if seen[itemId] and not rules.allowDuplicateItems then
			check.reason = "Deux fois le même objet"
			return check
		end
		seen[itemId] = true
	end

	if #itemIds > rules.maxItems then
		check.reason = string.format("%d objets au maximum", rules.maxItems)
		return check
	end

	local counts = countByCategory(config, itemIds)

	if (counts.primary or 0) < rules.minWeapons then
		check.reason = "Il faut une arme principale"
		return check
	end

	for categoryId, limit in rules.maxPerCategory do
		if (counts[categoryId] or 0) > limit then
			check.reason = string.format(
				"%s : %d au maximum",
				Loadout.categoryLabel(config, categoryId),
				limit
			)
			return check
		end
	end

	if spent > rules.budgetPoints then
		check.reason = string.format("%d points pour %d", spent, rules.budgetPoints)
		return check
	end

	check.ok = true
	return check
end

-- Vrai si on peut ajouter cet objet a l'assemblage courant. On valide la liste
-- COMPLETE une fois l'objet ajoute, plutot que de reecrire chaque regle ici :
-- deux endroits qui disent la meme chose finissent toujours par se contredire.
function Loadout.canAdd(
	config,
	itemIds: { string },
	classId: string?,
	itemId: string
): (boolean, string?)
	local candidate = table.clone(itemIds)
	table.insert(candidate, itemId)
	local check = Loadout.validate(config, candidate, classId)
	return check.ok, check.reason
end

-- CE QUE DONNE « JE PRENDS CET OBJET », remplacement compris.
--
-- Les categories limitees a un seul objet — l'arme principale, la secondaire,
-- l'armure — se REMPLACENT au lieu de se refuser. Cliquer sur le marteau
-- quand on porte deja la machette repose la machette et prend le marteau.
--
-- Sans ca, l'ecran verrouillait les trois armes qu'on ne porte pas et affichait
-- « une au maximum » a la place de ce qu'elles font : on ne pouvait plus lire
-- le catalogue sans d'abord rendre son arme. La regle n'a pas change, c'est la
-- facon de l'appliquer qui a change.
function Loadout.withSwap(config, itemIds: { string }, itemId: string): { string }
	local item = Loadout.find(config, itemId)
	if item == nil then
		return itemIds
	end

	local limit = config.loadout.maxPerCategory[item.category]
	if limit ~= 1 then
		return itemIds
	end

	local carried = Loadout.weaponOf(config, itemIds, item.category)
	if carried == nil or carried.id == itemId then
		return itemIds
	end

	return Loadout.remove(itemIds, carried.id)
end

function Loadout.add(config, itemIds: { string }, classId: string?, itemId: string): { string }
	local ok = Loadout.canAdd(config, itemIds, classId, itemId)
	if not ok then
		return itemIds
	end
	local next = table.clone(itemIds)
	table.insert(next, itemId)
	return next
end

function Loadout.remove(itemIds: { string }, itemId: string): { string }
	local next: { string } = {}
	local removed = false
	for _, id in itemIds do
		if id == itemId and not removed then
			removed = true
			continue
		end
		table.insert(next, id)
	end
	return next
end

function Loadout.contains(itemIds: { string }, itemId: string): boolean
	for _, id in itemIds do
		if id == itemId then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- L'ASSEMBLAGE PAR DEFAUT
--------------------------------------------------------------------------------

-- Ce que porte un joueur qui n'a rien choisi. Il doit etre LEGAL et il doit
-- depenser le budget : un joueur qui n'ouvre jamais l'ecran d'equipement ne
-- doit pas arriver en manche avec quatre points sur douze et se demander
-- pourquoi il tape comme une mouche.
--
-- DEUX TEMPS, et l'ordre est tout :
--
--   1. DE LA LARGEUR. Le moins cher de chaque categorie utile : une arme, un
--      soin, une armure, un utilitaire. Un debutant doit avoir un exemplaire
--      de chaque chose que le jeu lui demandera de comprendre.
--   2. CE QUI RESTE sur le plus cher qui tient encore, tant que quelque chose
--      tient.
--
-- Le premier temps compte plus qu'il n'y parait. La version qui prenait
-- simplement le plus cher de chaque categorie donnait l'armure lourde a tout
-- le monde : tous les debutants arrivaient lents, et la premiere chose que le
-- jeu leur apprenait etait qu'on ne court pas.
function Loadout.defaultFor(config, classId: string?): { string }
	local chosen: { string } = {}

	-- Trie une categorie par prix, puis par identifiant : deterministe, donc
	-- testable, et deux joueurs de la meme classe ont le meme defaut.
	local function sorted(categoryId: string, cheapestFirst: boolean): { any }
		local candidates = Loadout.byCategory(config, categoryId)
		table.sort(candidates, function(a, b)
			local costA = Loadout.costOf(config, a, classId)
			local costB = Loadout.costOf(config, b, classId)
			if costA == costB then
				return a.id < b.id
			end
			if cheapestFirst then
				return costA < costB
			end
			return costA > costB
		end)
		return candidates
	end

	-- 1. De la largeur. L'arme d'abord, parce qu'elle est obligatoire ; le soin
	-- ensuite, parce qu'un debutant qui meurt sans jamais pouvoir se soigner ne
	-- comprend pas ce qui lui arrive.
	for _, categoryId in { "primary", "heal", "armor", "utility" } do
		for _, item in sorted(categoryId, true) do
			local ok = Loadout.canAdd(config, chosen, classId, item.id)
			if ok then
				table.insert(chosen, item.id)
				break
			end
		end
	end

	-- 2. Ce qui reste, sur le plus cher qui tient encore. La boucle s'arrete
	-- toute seule quand plus rien ne rentre : c'est la validation complete qui
	-- le decide, pas un calcul de points en double ici.
	while true do
		local added = false
		for _, category in config.loadout.categories do
			for _, item in sorted(category.id, false) do
				local ok = Loadout.canAdd(config, chosen, classId, item.id)
				if ok then
					table.insert(chosen, item.id)
					added = true
					break
				end
			end
			if added then
				break
			end
		end
		if not added then
			break
		end
	end

	return chosen
end

--------------------------------------------------------------------------------
-- CE QUE LES OBJETS CHANGENT
--------------------------------------------------------------------------------

function Loadout.emptyDeltas(): Deltas
	return { scale = {}, offset = {} }
end

-- Fusionne deux jeux de modifications : les facteurs se multiplient, les
-- decalages s'additionnent. Deux armures ne peuvent pas se cumuler (une seule
-- est autorisee), mais trois utilitaires si.
function Loadout.combine(a: Deltas, b: Deltas): Deltas
	local merged = Loadout.emptyDeltas()
	for key, value in a.scale do
		merged.scale[key] = value
	end
	for key, value in b.scale do
		merged.scale[key] = (merged.scale[key] or 1) * value
	end
	for key, value in a.offset do
		merged.offset[key] = value
	end
	for key, value in b.offset do
		merged.offset[key] = (merged.offset[key] or 0) + value
	end
	return merged
end

function Loadout.deltasOf(item: any): Deltas
	local deltas = Loadout.emptyDeltas()
	for key, value in item.scale or {} do
		deltas.scale[key] = value
	end
	for key, value in item.offset or {} do
		deltas.offset[key] = value
	end
	return deltas
end

-- Ce que portent les objets qui agissent en permanence : armure, soins,
-- utilitaires. Les armes en sont exclues parce qu'elles ne s'appliquent qu'au
-- coup porte, et qu'il y en a deux.
function Loadout.passiveDeltas(config, itemIds: { string }): Deltas
	local deltas = Loadout.emptyDeltas()
	for _, itemId in itemIds do
		local item = Loadout.find(config, itemId)
		if item ~= nil and item.category ~= "primary" and item.category ~= "secondary" then
			deltas = Loadout.combine(deltas, Loadout.deltasOf(item))
		end
	end
	return deltas
end

function Loadout.weaponOf(config, itemIds: { string }, categoryId: string): any?
	for _, itemId in itemIds do
		local item = Loadout.find(config, itemId)
		if item ~= nil and item.category == categoryId then
			return item
		end
	end
	return nil
end

-- Les armures equipees, dans l'ordre du catalogue. Une liste et pas un seul
-- objet : rien dans les regles n'interdit d'en porter deux, et une fonction qui
-- renverrait la premiere trouvee rendrait la seconde invisible sans le dire.
function Loadout.wornOf(config, itemIds: { string }): { any }
	local found = {}
	for _, itemId in itemIds do
		local item = Loadout.find(config, itemId)
		-- CE QUI SE PORTE EST CE QUI DIT SE PORTER, pas ce qui est range dans
		-- la categorie « armure ». Les bottes a ressort sont un utilitaire, et
		-- les montrer dans la main gauche le temps d'un saut serait absurde :
		-- on ne tient pas ses bottes. Un objet qui declare un bloc `worn` est
		-- donc habille, quelle que soit sa categorie.
		local wearable = item ~= nil
			and (item.category == "armor" or (item.look ~= nil and item.look.worn ~= nil))
		if wearable then
			table.insert(found, item)
		end
	end
	return found
end

function Loadout.weaponDeltas(config, itemIds: { string }, categoryId: string): Deltas
	local weapon = Loadout.weaponOf(config, itemIds, categoryId)
	if weapon == nil then
		return Loadout.emptyDeltas()
	end
	return Loadout.deltasOf(weapon)
end

-- La part de la reduction de degats de la cible que l'arme ignore. Seul l'arc
-- composite en a : c'est le contre a l'armure lourde, et sans contre une
-- armure a cinq points n'a pas de reponse.
function Loadout.armorPierceOf(config, itemIds: { string }, categoryId: string): number
	local weapon = Loadout.weaponOf(config, itemIds, categoryId)
	if weapon == nil then
		return 0
	end
	return weapon.armorPierceRatio or 0
end

--------------------------------------------------------------------------------
-- LES OBJETS CONSOMMABLES
--------------------------------------------------------------------------------

-- Les objets qui s'utilisent, dans l'ordre du CATALOGUE et pas dans l'ordre ou
-- le joueur les a cliques. Deux raisons : l'emplacement 1 est toujours le meme
-- objet d'une manche a l'autre, et le serveur et le client tombent sur la meme
-- numerotation sans se l'echanger.
function Loadout.usables(config, itemIds: { string }): { Usable }
	local found: { Usable } = {}
	for _, item in config.items do
		if item.use == nil then
			continue
		end
		if not Loadout.contains(itemIds, item.id) then
			continue
		end
		if #found >= config.loadout.maxUsableSlots then
			break
		end
		table.insert(found, { slot = #found + 1, itemId = item.id, item = item })
	end
	return found
end

function Loadout.usableAt(config, itemIds: { string }, slot: number): Usable?
	for _, usable in Loadout.usables(config, itemIds) do
		if usable.slot == slot then
			return usable
		end
	end
	return nil
end

return Loadout
