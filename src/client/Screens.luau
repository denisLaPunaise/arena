--!strict
--[[
	Screens — ou se pose un panneau, ecrit a un seul endroit.

	Les cinq panneaux du jeu (arbre, equipement, pieces, bans, bac a sable)
	sont dessines a taille fixe, puis reduits par un UIScale pour tenir dans la
	fenetre. La regle tenait en trois lignes recopiees cinq fois, et c'est
	exactement comme ca qu'elle s'est trompee.

	CE QUI A ETE MESURE le 27 octobre 2026, fenetre de 1016x387, encart de 58 :

	- `AbsolutePosition` ne se lit PAS dans le meme repere que `AbsoluteSize`.
	  Avec `IgnoreGuiInset = true`, le ScreenGui couvre toute la fenetre, donc
	  387 pixels de haut, mais l'origine des `AbsolutePosition` reste sous la
	  barre du haut : le bord superieur du ScreenGui s'y lit -58, et son bord
	  inferieur 329. Comparer un `AbsolutePosition` a `AbsoluteSize / 2`
	  melange donc deux reperes et fait croire a un decalage de 58 pixels qui
	  n'existe pas. C'est l'erreur qui a ete commise le 26 octobre, et le
	  « rattrapage » de 58 pixels ajoute au bac a sable etait, lui, un vrai
	  decalage. La sonde qui tranche ne compare que des `AbsolutePosition`
	  entre eux : le centre du panneau contre le milieu de ses PROPRES bords.

	- `UDim2.fromScale(0.5, 0.5)` avec un `AnchorPoint` au centre pose donc
	  deja le panneau au milieu exact du ScreenGui. Ecart mesure : 0.0.

	CE QUI RESTE VRAI, et que ce module corrige : la barre du haut de Roblox se
	dessine PAR-DESSUS les ScreenGui qui l'ignorent. Un panneau centre sur la
	fenetre entiere, et mesure contre sa hauteur entiere, passe donc son
	en-tete derriere cette barre des qu'il est grand. On retire la barre de la
	place disponible, et on descend le panneau d'une demi-barre pour le centrer
	sur ce qui reste visible.
]]

local GuiService = game:GetService("GuiService")

local Screens = {}

-- Un panneau qui touche exactement les bords ressemble a un bug d'affichage.
local MARGIN = 0.94

-- En dessous, les libelles ne se lisent plus. Mieux vaut un panneau qui
-- deborde un peu qu'un panneau illisible : c'est le prix d'un objet qui est
-- ecrit en bas de sa carte.
local MIN_SCALE = 0.4

-- La hauteur est un argument, et pas une constante du module, parce que le
-- panneau de l'arbre change de hauteur selon qu'une branche est choisie ou
-- non.
function Screens.fit(
	screen: ScreenGui,
	panel: GuiObject,
	scale: UIScale,
	width: number,
	height: number
)
	local room = screen.AbsoluteSize
	if room.X <= 0 or room.Y <= 0 then
		return
	end

	-- Un ScreenGui qui respecte l'encart commence deja sous la barre : il n'y
	-- a alors rien a retirer ni a decaler.
	local inset = if screen.IgnoreGuiInset then GuiService:GetGuiInset().Y else 0
	local usable = room.Y - inset

	-- La plus contraignante des deux dimensions decide.
	local byWidth = (room.X * MARGIN) / width
	local byHeight = (usable * MARGIN) / height
	scale.Scale = math.clamp(math.min(byWidth, byHeight), MIN_SCALE, 1)

	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, inset / 2)
end

return Screens
