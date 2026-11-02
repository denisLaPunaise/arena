--!strict
--[[
	Tests de l'accueil et des codes de salon.

	CE QUE CES TESTS ATTRAPENT, et que personne ne verrait en jouant :

	  - UN GENERATEUR ET UN VALIDATEUR QUI NE SONT PAS D'ACCORD. C'est la
	    panne la plus chere de ce module, et la plus silencieuse : un code
	    fabrique que `isValid` refuserait donnerait « Un code fait 5 signes »
	    a quelqu'un qui recopie exactement ce que le jeu lui a montre. Le test
	    fait tourner les deux bouts l'un contre l'autre, sur tout l'alphabet.
	  - un caractere ambigu glisse dans l'alphabet. Un « 0 » et un « O » dans
	    la meme liste, et un code sur six se dicte de travers. Celui qui
	    « completerait » l'alphabet ne verrait rien de cassé.
	  - un code trop court pour etre unique. Cinq signes sur trente et un font
	    vingt-huit millions de combinaisons ; trois en feraient trente mille,
	    et deux salons se marcheraient dessus.
	  - une peremption qui tombe du mauvais cote. Un code valable zero heure,
	    ou valable pour toujours alors que le serveur reserve, lui, s'eteint.
]]

local Config = require("../../src/shared/Config")
local Lobbies = require("../../src/shared/Lobbies")

local harness = require("../harness")

-- Un hasard choisi, pour que le meme appel rende toujours le meme code. C'est
-- tout l'interet d'avoir sorti le tirage des codes de MenuService : en jeu
-- c'est `Random`, ici c'est une suite qu'on connait.
local function cycling(values: { number }): (number) -> number
	local at = 0
	return function(n: number): number
		at += 1
		local picked = values[((at - 1) % #values) + 1]
		return math.clamp(picked, 1, n)
	end
end

return function(t: harness.Harness)
	local rules = Config.menu
	local alphabet = Lobbies.ALPHABET
	local length = rules.codeLength

	t.section("L'alphabet des codes")

	-- LE test de ce module. Un code se dicte a voix haute ou se recopie depuis
	-- une capture d'ecran : « zero » contre « O » et « un » contre « I » sont
	-- les deux erreurs les plus faciles du monde.
	for _, forbidden in { "0", "O", "1", "I", "L" } do
		t.equal(
			string.format("« %s » n'est pas dans l'alphabet", forbidden),
			string.find(alphabet, forbidden, 1, true),
			nil
		)
	end

	-- Deux fois la meme lettre dans l'alphabet biaiserait le tirage sans rien
	-- casser : un code sur trente et un serait deux fois plus probable.
	local seen: { [string]: boolean } = {}
	local twice = ""
	for index = 1, #alphabet do
		local char = string.sub(alphabet, index, index)
		if seen[char] then
			twice = char
		end
		seen[char] = true
	end
	t.equal("aucune lettre n'y figure deux fois", twice, "")

	t.section("Assez de codes pour que deux salons ne se croisent pas")

	-- Un chiffre MESURE, pas suppose. Il tient compte des deux reglages a la
	-- fois : raccourcir le code ou raccourcir l'alphabet le fait tomber, et
	-- c'est exactement ce qu'on veut savoir.
	-- LES PARENTHESES COMPTENT : `^` lie plus fort que `#`, donc `#a ^ n` est
	-- la longueur de `a ^ n` et pas la longueur de `a` a la puissance `n`.
	local combinations = (#alphabet) ^ length
	t.check(
		string.format("%d signes sur %d en font %d", length, #alphabet, math.floor(combinations)),
		combinations >= 1e6
	)

	t.section("Le generateur et le validateur sont d'accord")

	-- LES DEUX BOUTS, l'un contre l'autre. On fabrique un code pour CHAQUE
	-- lettre de l'alphabet et on verifie que le validateur l'accepte. Ce que
	-- ca garde est une regle ajoutee d'un seul cote : le jour ou `normalise`
	-- ecartera quelque chose de plus — une lettre, une suite interdite — le
	-- generateur pourra encore le produire, et le joueur lira « un code fait
	-- cinq signes » en recopiant exactement ce que le jeu lui a montre.
	-- Verifie en cassant le test expres : `normalise` qui ecarte le Z, et il
	-- nomme « ZZZZZ ».
	local refused = ""
	for index = 1, #alphabet do
		local code = Lobbies.makeCode(cycling({ index }), length)
		if not Lobbies.isValid(code, length) then
			refused = code
		end
		if Lobbies.normalise(code, length) ~= code then
			refused = code
		end
	end
	t.equal("tout code fabriqué est un code valide", refused, "")

	local code = Lobbies.makeCode(cycling({ 1, 2, 3 }), length)
	t.equal(
		"le même hasard rend le même code",
		code,
		Lobbies.makeCode(cycling({ 1, 2, 3 }), length)
	)
	t.equal("et il fait la longueur demandée", #code, length)

	t.section("Ce que le joueur tape devient un code")

	-- Un code arrive rarement propre : il est recopie d'un message, avec sa
	-- casse d'origine et parfois un tiret au milieu. Refuser serait le plus
	-- facile et le plus desagreable.
	t.equal("les minuscules montent", Lobbies.normalise("abcde", 5), "ABCDE")
	t.equal("les espaces disparaissent", Lobbies.normalise(" AB CD E ", 5), "ABCDE")
	t.equal("les tirets aussi", Lobbies.normalise("AB-CD-E", 5), "ABCDE")
	t.equal("ce qui dépasse est coupé", Lobbies.normalise("ABCDEFGH", 5), "ABCDE")

	-- Les caracteres ecartes de l'alphabet sont justement ceux qu'on tape par
	-- erreur : ils tombent, ils ne glissent pas dans le code.
	t.equal("un zéro n'entre pas", Lobbies.normalise("AB0CD", 5), "ABCD")
	t.equal("un O non plus", Lobbies.normalise("ABOCD", 5), "ABCD")

	t.section("Un code valide, et seulement lui")

	t.equal("trop court, refusé", Lobbies.isValid("ABCD", 5), false)
	t.equal("trop long, refusé", Lobbies.isValid("ABCDEF", 5), false)
	t.equal("vide, refusé", Lobbies.isValid("", 5), false)
	t.equal("avec une lettre interdite, refusé", Lobbies.isValid("ABCD0", 5), false)
	t.equal("en minuscules, refusé tel quel", Lobbies.isValid("abcde", 5), false)
	t.equal("propre, accepté", Lobbies.isValid("ABCDE", 5), true)

	t.section("La péremption")

	local hours = rules.codeHours
	t.check("un code ne vit pas zéro heure", hours > 0)
	t.equal("neuf, il ouvre", Lobbies.isExpired(1000, 1000, hours), false)
	t.equal(
		"une seconde avant la limite, il ouvre encore",
		Lobbies.isExpired(1000, 1000 + (hours * 3600), hours),
		false
	)
	t.equal(
		"une seconde après, il est mort",
		Lobbies.isExpired(1000, 1000 + (hours * 3600) + 1, hours),
		true
	)

	t.section("Les réglages de l'accueil sont lus")

	-- LA PANNE QUI S'EST PRODUITE TROIS FOIS : une valeur de Config que seuls
	-- les tests touchent est une regle qui ne s'applique pas. Ici on verifie
	-- que chaque reglage de `Config.menu` a une forme utilisable par le code
	-- qui le lit, et pas seulement qu'il existe.
	t.equal("la longueur du code est un entier", length, math.floor(length))
	t.check("le nom du DataStore n'est pas vide", #rules.dataStoreName > 0)
	t.check("la touche de retour au menu est nommée", #rules.reopenKey > 0)

	-- `readyRequired` a false rend au jeu son comportement d'avant le menu :
	-- tout le monde est assis d'office. C'est l'interrupteur de comparaison,
	-- et il doit rester vrai par defaut, sinon le menu est decoratif.
	t.equal("l'accueil est ouvert", rules.enabled, true)
	t.equal("et on entre en partie en appuyant sur Jouer", rules.readyRequired, true)
end
