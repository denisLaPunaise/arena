--!strict
--[[
	Tests du corps standard de l'arene.

	CE QUE CES TESTS ATTRAPENT, et que personne ne verrait en jouant :

	  - un nom de champ qui n'existe pas sur une `HumanoidDescription`. L'ecrire
	    ne leve RIEN : la valeur part dans une table Luau que personne ne lit,
	    et le corps garde l'echelle du joueur. On verrait un geant au milieu de
	    l'arene sans le moindre message.
	  - une partie du corps mal nommee — « LeftHand » au lieu de « LeftArm » —
	    qui laisserait un bras de pigeon au milieu d'une armure.
	  - un reglage que personne ne lit. C'est la panne qui a coute les formats
	    et le mode prive : une table de `Config` tres bien commentee pendant
	    qu'aucun service ne l'applique. Ici on relie les deux bouts en
	    verifiant que CHAQUE champ annonce est un champ que Roblox connait, et
	    que les six echelles y sont vraiment toutes.
]]

local Body = require("../../src/shared/Body")
local Config = require("../../src/shared/Config")

local harness = require("../harness")

return function(t: harness.Harness)
	t.section("Ce que Config demande, Roblox le connait")

	t.equal("aucune échelle inconnue", Body.unknownScale(Config), nil)
	t.equal("aucune partie du corps inconnue", Body.unknownBodyPart(Config), nil)

	-- UNE FAUTE DE FRAPPE DOIT ETRE ATTRAPEE, et le seul moyen de le prouver
	-- est d'en commettre une expres. Sans ca le test ci-dessus passerait tout
	-- aussi bien si la fonction renvoyait toujours nil.
	local broken = {
		body = {
			enabled = true,
			scales = { HeightScale = 1, LargeurEchelle = 1 },
			bodyParts = { "Torso" },
			keepClothing = true,
			keepAccessories = false,
		},
	}
	t.equal("une échelle inventée est nommée", Body.unknownScale(broken), "LargeurEchelle")

	local brokenPart = {
		body = {
			enabled = true,
			scales = { HeightScale = 1 },
			bodyParts = { "Torso", "LeftHand" },
			keepClothing = true,
			keepAccessories = false,
		},
	}
	t.equal("une partie inventée est nommée", Body.unknownBodyPart(brokenPart), "LeftHand")

	t.section("La norme est complète")

	-- LES SIX ECHELLES, PAS CINQ. En oublier une laisse exactement la porte
	-- qu'on voulait fermer : un joueur deux fois plus large se lit autrement,
	-- et c'est tout le propos.
	local scaleCount = 0
	for _ in Config.body.scales do
		scaleCount += 1
	end
	t.equal("les six échelles sont normalisées", scaleCount, 6)

	local partCount = 0
	for _ in Config.body.bodyParts do
		partCount += 1
	end
	t.equal("les six parties du corps sont remises à zéro", partCount, 6)

	-- LES DEUX DERNIERES VALENT ZERO, et c'est contre-intuitif : a un, le
	-- corps glisse vers les proportions « Rthro », qui ne sont pas celles
	-- contre lesquelles les armures sont dessinees.
	t.equal("BodyTypeScale ramène au corps anguleux", Config.body.scales.BodyTypeScale, 0)
	t.equal("ProportionScale ramène au corps anguleux", Config.body.scales.ProportionScale, 0)
	t.equal("HeightScale vaut un", Config.body.scales.HeightScale, 1)

	t.section("Ce qui reste au joueur")

	-- Les vetements restent, et c'est une decision : ils ne changent pas une
	-- silhouette, et ce sont eux qui porteront les skins.
	t.equal("les vêtements restent ceux du joueur", Config.body.keepClothing, true)

	t.section("Le service a de quoi insister")

	-- `ApplyDescription` part sur le reseau. Un seul essai et un paquet perdu
	-- laisse un joueur avec son avatar d'origine toute la partie.
	t.check("plusieurs essais d'application", Config.body.applyAttempts >= 2)
	t.check("une attente entre deux essais", Config.body.retrySeconds > 0)

	t.section("Le réglage s'annonce")

	-- Une ligne de console qui ne dit pas ce qu'elle fait ne sert a rien :
	-- « corps standard » tout seul ne dirait pas que les vetements sont
	-- gardes, et quelqu'un chercherait le bug.
	t.check(
		"la description nomme ce qui est gardé",
		string.find(Body.describe(Config), "vêtements") ~= nil
	)
	t.equal(
		"coupé, le réglage le dit aussi",
		Body.describe({ body = { enabled = false } }),
		"corps du joueur gardé tel quel"
	)
end
