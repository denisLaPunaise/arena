--!strict
--[[
	ClassLooks — le couvre-chef de chaque classe.

	Donnees pures : aucun require, aucune API Roblox. Pose par
	`WeaponService.attachHeadgear`, sur les joueurs comme sur les mannequins.

	CE SONT DES MAILLAGES GENERES, PAS DES PIECES. La premiere version etait
	faite de boites, comme les armes, et elle a ete jetee apres l'avoir
	regardee : sur une tete ronde, des plaques droites flottent, et quatorze
	couvre-chefs en boites lisaient comme une maquette. `generate_mesh` (le
	pont MCP de Studio) rend un maillage texture, publie comme asset ; les
	identifiants ci-dessous SONT la sauvegarde, exactement comme les matieres
	des maps dans les recettes de `tools/`. Genere et regarde le 4 novembre
	2026, classe par classe, sur un corps standard, de face et de trois quarts.

	UN MAILLAGE NE S'ECRIT PAS EN JEU : `MeshId` n'est modifiable que par un
	plugin. Le jeu fait donc creer la piece par `CreateMeshPartAsync` au
	demarrage, puis la clone. Si un asset est modere ou supprime, la console le
	nomme au demarrage du serveur (« Couvre-chefs : … MANQUENT »).

	POURQUOI UN MODULE A PART ET PAS DANS CONFIG. Config fait 319 000
	caracteres, et le pont MCP coupe une `Source` a 200 000 : impossible de le
	recharger dans Studio pour regarder un reglage qu'on vient de changer. Or
	un couvre-chef ne se regle qu'en le regardant.

	RIEN DE VISUEL NE TOUCHE A L'EQUILIBRAGE. Aucun chiffre d'ici n'entre dans
	un calcul, et les pieces ne heurtent rien (ni collision, ni requete
	spatiale). Le couvre-chef dit QUELLE classe joue, a tout le monde : voulu
	par Josh le 4 novembre 2026.

	LE REPERE de chaque maillage :
	  `width`  la largeur du maillage, en FRACTION de la largeur du membre. Les
	           proportions du maillage sont gardees : un chapeau etire sur un
	           seul axe se verrait tout de suite.
	  `at`     la position de son centre, en fractions du membre, depuis le
	           centre du membre. +Y en haut, le visage vers -Z, +X a droite.
	  `limb`   le membre porteur, la tete par defaut. La cape du Vampire est
	           sur le torse : elle doit suivre les epaules, pas la tete.
	  `tipUp`  en degres, positif leve l'avant (meme convention que les armes).
]]

local ClassLooks = {}

local function look(meshes: { { [string]: any } }): any
	return {
		worn = { limb = "Head", at = { 0, 0, 0 }, fit = true },
		meshes = meshes,
	}
end

local function mesh(
	name: string,
	meshId: number,
	textureId: number,
	width: number,
	at: { number },
	extra: { [string]: any }?
): { [string]: any }
	local m: { [string]: any } = {
		name = name,
		meshId = "rbxassetid://" .. meshId,
		textureId = "rbxassetid://" .. textureId,
		width = width,
		at = at,
	}
	if extra ~= nil then
		for k, v in extra do
			m[k] = v
		end
	end
	return m
end

-- VAMPIRE — cheveux plaques noirs a pointe sur le front, et la courte cape au
-- col dresse qui monte derriere la tete. Le maillage des cheveux modele aussi
-- un crane pale : recule de 0,2 il passe DANS la vraie tete, et seuls les
-- cheveux depassent. Pose plus en avant, il couvre les yeux d'un masque blanc.
ClassLooks.vampire = look({
	mesh("Cape", 124058937333812, 140648326688913, 1.3, { 0, 0.74, 0.3 }, { limb = "UpperTorso" }),
	mesh("Cheveux", 99464122570560, 99894632779762, 1.2, { 0, 0.3, 0.2 }),
})

-- COLOSSE — le heaume d'acier a fente et a croix, et sa crete rouge. Le
-- couvre-chef le plus lisible du jeu, et c'est la classe qu'on doit voir venir.
ClassLooks.colossus = look({
	mesh("Heaume", 138681015308028, 107287909999677, 1.3, { 0, 0.3, 0 }),
})

-- TRAQUEUR — la capuche verte du chasseur, sa pointe qui tombe dans le dos.
-- Plus large que la tete de presque moitie : a 1,35 le visage sortait devant.
ClassLooks.tracker = look({
	mesh("Capuche", 93317019636097, 114501344647635, 1.8, { 0, 0.18, 0.12 }),
})

-- ARTIFICIER — la calotte d'aviateur en cuir, les lunettes de soudeur vertes
-- remontees sur le front et la roue dentee sur la tempe.
ClassLooks.artificer = look({
	mesh("Calotte", 73958902405011, 127095509647712, 1.15, { 0, 0.22, 0 }),
})

-- SPECTRE — la capuche violette dechiree et le masque de porcelaine. Le
-- masque doit passer DEVANT le visage : d'ou le recul de -0,1.
ClassLooks.spectre = look({
	mesh("Capuche", 81584680939301, 125692448546937, 1.7, { 0, 0.12, -0.1 }),
})

-- LIEN — une couronne d'argent sertie de cristaux turquoise. Une premiere
-- version, un fin bandeau a deux anneaux, etait juste et invisible a vingt
-- studs : remplacee.
ClassLooks.link = look({
	mesh("Couronne", 103511607368928, 84536992393022, 1.32, { 0, 0.46, 0 }),
})

-- DUELLISTE — le feutre bordeaux a large bord et sa plume blanche. Le bord
-- releve de quatre degres, sinon il tombe sur les yeux.
ClassLooks.duelist = look({
	mesh("Feutre", 119834430257961, 98728884985208, 1.95, { 0, 0.88, 0.02 }, { tipUp = 4 }),
})

-- FORGERON — le chapel de fer a large bord, riveté, au marteau sur le devant.
-- Visage ouvert : l'oppose exact du heaume du Colosse.
ClassLooks.smith = look({
	mesh("Chapel", 92750485816019, 133586828359875, 1.45, { 0, 0.42, 0 }),
})

-- PYROMANE — une couronne de flammes sur un bandeau noirci.
ClassLooks.pyromaniac = look({
	mesh("Flammes", 108716493994678, 105888459777742, 1.3, { 0, 0.66, 0 }),
})

-- LEURRE — le bonnet de bouffon a deux pointes et grelots. Le trompeur se lit
-- de tres loin, ironie assumee.
ClassLooks.decoy = look({
	mesh("Bonnet", 136760839049611, 138465740435256, 1.9, { 0, 0.55, 0 }),
})

-- SISMIQUE — la couronne de pierre fendue de lave, et deux cornes de belier.
ClassLooks.seismic = look({
	mesh("Couronne", 96985547674461, 119306520015624, 1.6, { 0, 0.5, 0 }),
})

-- PARASITE — le casque d'insecte vert aux yeux rouges et aux antennes.
ClassLooks.parasite = look({
	mesh("Carapace", 84078874109821, 89163951125680, 1.4, { 0, 0.32, 0 }),
})

-- CAMELEON — la casquette de camouflage. Le generateur n'a pas rendu la
-- cagoule demandee ; le camouflage dit la meme chose, plus vite.
ClassLooks.chameleon = look({
	mesh("Casquette", 101061826081024, 86533870288582, 1.3, { 0, 0.32, 0.02 }),
})

-- INFIRMIER — la coiffe blanche a croix rouge.
ClassLooks.medic = look({
	mesh("Coiffe", 87755406157870, 107601177110343, 1.15, { 0, 0.42, 0 }),
})

return ClassLooks
