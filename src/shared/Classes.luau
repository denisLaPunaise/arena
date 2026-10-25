--!strict
--[[
	Classes — la liste des quatorze classes, telle qu'elle est arretee dans la
	fiche de conception.

	Chaque classe tient en trois lignes : un pouvoir, une faiblesse qui le
	compense, un role. La faiblesse n'est pas decorative, c'est elle qui empeche
	la classe de dominer : si on en retire une, il faut retirer le pouvoir avec.

	`prototype = true` marque les deux classes du premier jalon de jeu : le
	Vampire contre le Colosse sur une map vide. Les douze autres ne se codent
	qu'une fois ce duel amusant.

	`needsAllies = true` marque les trois classes dont le pouvoir cible un
	coequipier. Elles sont retirees du tirage en 1v1 : sans allie leurs trois
	branches d'arbre sont vides, et comme le miroir donne la meme classe aux
	deux joueurs, le duel se jouerait a pouvoirs eteints des deux cotes. La
	raison du choix est dans docs/DECISIONS.md.

	Ce module ne contient aucun chiffre d'equilibrage : ils vont dans Config.
	Il ne requiert rien et ne touche a aucune API Roblox.
]]

local Classes = {}

Classes.all = {
	{
		id = "vampire",
		name = "Vampire",
		power = "Se soigne d'une part des degats infliges",
		weakness = "Ne regenere rien hors combat",
		role = "Duelliste d'usure",
		prototype = true,
	},
	{
		id = "colossus",
		name = "Colosse",
		power = "Beaucoup de PV, pousse les adversaires",
		weakness = "Lent, cible facile a distance",
		role = "Avance et bloque",
		prototype = true,
	},
	{
		id = "tracker",
		name = "Traqueur",
		power = "Voit les traces de pas recentes",
		weakness = "Degats faibles en melee",
		role = "Information",
	},
	{
		id = "artificer",
		name = "Artificier",
		power = "Pose pieges et mines",
		weakness = "Stock limite, nul en combat direct",
		role = "Controle de zone",
	},
	{
		id = "spectre",
		name = "Spectre",
		power = "Traverse les murs quelques secondes",
		weakness = "Ne peut ni attaquer ni etre soigne pendant",
		role = "Contournement",
	},
	{
		id = "link",
		name = "Lien",
		power = "Partage ses PV avec un allie cible",
		weakness = "Subit la moitie des degats de l'allie",
		role = "Soutien",
		needsAllies = true,
	},
	{
		id = "duelist",
		name = "Duelliste",
		power = "Degats accrus seul face a un seul ennemi",
		weakness = "Penalise des que deux ennemis sont proches",
		role = "Isolement",
	},
	{
		id = "smith",
		name = "Forgeron",
		power = "Deploie des murs de couverture temporaires",
		weakness = "Construction lente, ses murs genent aussi son equipe",
		role = "Terrain",
	},
	{
		id = "pyromaniac",
		name = "Pyromane",
		power = "Laisse des zones de feu persistantes",
		weakness = "Subit ses propres flammes",
		role = "Anti-camp",
	},
	{
		id = "decoy",
		name = "Leurre",
		power = "Pilote un clone qui attire l'attention",
		weakness = "Reste immobile et vulnerable pendant qu'il le pilote",
		role = "Diversion",
		needsAllies = true,
	},
	{
		id = "seismic",
		name = "Sismique",
		power = "Frappe le sol : revele et ralentit tout ennemi au contact du sol",
		weakness = "Aucun effet sur un ennemi en l'air ou en hauteur",
		role = "Revelation de zone",
	},
	{
		id = "parasite",
		name = "Parasite",
		power = "Marque un ennemi, le voit a travers les murs, vole une part des soins qu'il recoit",
		weakness = "La marque previent sa cible qu'elle est marquee",
		role = "Harcelement",
	},
	{
		id = "chameleon",
		name = "Cameleon",
		power = "Invisible tant qu'il ne bouge pas",
		weakness = "Redevient visible au moindre deplacement",
		role = "Embuscade",
	},
	{
		id = "medic",
		name = "Infirmier",
		power = "Remet debout un allie pendant sa fenetre d'agonie",
		weakness = "Relevement long, visible et interruptible",
		role = "Anti-elimination",
		needsAllies = true,
	},
}

-- Acces par identifiant, construit une seule fois au chargement du module.
-- Les classes qui peuvent sortir au tirage pour ce format. En 1v1 on retire
-- celles qui ont besoin d'un coequipier ; partout ailleurs, les quatorze.
function Classes.drawable(playersPerTeam: number): { any }
	local list: { any } = {}
	for _, class in Classes.all do
		if playersPerTeam <= 1 and class.needsAllies then
			continue
		end
		table.insert(list, class)
	end
	return list
end

local byId: { [string]: any } = {}
for _, class in Classes.all do
	byId[class.id] = class
end
Classes.byId = byId

return Classes
