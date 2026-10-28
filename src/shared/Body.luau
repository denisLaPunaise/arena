--!strict
--[[
	Body — le corps standard de l'arene.

	Logique pure : aucun require, aucune API Roblox.

	POURQUOI IMPOSER UN CORPS. Dans un jeu PvP, lire son adversaire fait partie
	du savoir jouer : sa classe, son armure, la portee de son arme. Un avatar
	Roblox peut etre un pigeon de trois studs, un geant, ou un maillage qui
	n'a plus rien d'humain — et ces corps-la ne se lisent pas pareil, ce qui
	n'a aucun rapport avec l'habilete de qui que ce soit. C'est le sixieme
	principe applique au corps : deux joueurs du meme etat doivent se lire
	pareil.

	L'ARMURE A RENDU LA QUESTION CONCRETE. Une armure portee se fixe aux parts
	du personnage et se met a l'echelle de leur taille. Sur un bundle, le
	maillage VISIBLE n'a aucun rapport avec cette taille : l'armure disparait
	simplement sous l'oiseau. Verifie le 28 octobre 2026 sur l'avatar de Josh.
	Aucun chiffre ne corrige ca, parce qu'il n'existe pas de liste des bundles
	et qu'il en sort en permanence.

	CE QUI EST NORMALISE ET CE QUI NE L'EST PAS. On touche a la GEOMETRIE du
	corps — les six parties qu'un bundle remplace, et les six echelles — et a
	rien d'autre. Les vetements, le visage et les couleurs restent ceux du
	joueur : ils ne changent pas une silhouette, donc ils ne coutent rien a la
	lecture, et ce sont eux qui porteront les skins. C'est d'ailleurs un
	argument pour : un skin ne se voit que si le corps en dessous est
	previsible.

	CE MODULE NE CONNAIT PAS `HumanoidDescription`. Il dit quels champs porter
	a quelle valeur ; c'est `BodyService` qui les ecrit. La seule chose qu'il
	sait de Roblox est le NOM des champs, qui est une donnee, pas une API.
]]

local Body = {}

-- Les six echelles d'une `HumanoidDescription`. Un nom hors de cette liste ne
-- leve rien quand on l'ecrit : la propriete est simplement ajoutee a la table
-- Luau et personne ne la lit jamais. D'ou le garde-fou.
Body.scaleFields = {
	HeightScale = true,
	WidthScale = true,
	DepthScale = true,
	HeadScale = true,
	BodyTypeScale = true,
	ProportionScale = true,
}

-- Les six parties du corps qu'un bundle remplace. Les remettre a zero rend
-- les parts classiques.
Body.bodyPartFields = {
	Head = true,
	Torso = true,
	LeftArm = true,
	RightArm = true,
	LeftLeg = true,
	RightLeg = true,
}

--[[
	Le premier nom d'echelle que `Config` demande et que Roblox ne connait
	pas, ou nil si tout va bien. Une faute de frappe ici ne leve AUCUNE erreur
	a l'execution — on ecrit un champ qui n'existe pas, et le corps garde son
	echelle d'origine sans que personne le sache.
]]
function Body.unknownScale(config): string?
	for name in config.body.scales do
		if not Body.scaleFields[name] then
			return name
		end
	end
	return nil
end

--[[
	Pareil pour les parties du corps. Une « LeftHand » au lieu de « LeftArm »
	laisserait un bras de pigeon au milieu d'une armure.
]]
function Body.unknownBodyPart(config): string?
	for _, name in config.body.bodyParts do
		if not Body.bodyPartFields[name] then
			return name
		end
	end
	return nil
end

--[[
	Est-ce que ce corps a besoin d'etre normalise ? Repond faux quand le
	reglage est coupe, pour que l'appelant n'ait pas a connaitre le detail.
]]
function Body.enabled(config): boolean
	return config.body.enabled == true
end

--[[
	Ce que le serveur annonce au demarrage. Une ligne qui dit exactement ce
	qu'on touche : sans elle, « corps standard » ne veut rien dire et personne
	ne saurait que les vetements sont gardes.
]]
function Body.describe(config): string
	if not Body.enabled(config) then
		return "corps du joueur gardé tel quel"
	end

	local kept = {}
	if config.body.keepClothing then
		table.insert(kept, "vêtements")
	end
	if config.body.keepAccessories then
		table.insert(kept, "accessoires")
	end

	local parts = 0
	for _ in config.body.bodyParts do
		parts += 1
	end

	return string.format(
		"corps standard imposé (%d parties, %d échelles)%s",
		parts,
		(function(): number
			local n = 0
			for _ in config.body.scales do
				n += 1
			end
			return n
		end)(),
		if #kept == 0 then "" else " — gardés : " .. table.concat(kept, ", ")
	)
end

return Body
