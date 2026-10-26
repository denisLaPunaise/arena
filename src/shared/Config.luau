--!strict
--[[
	Config — tous les chiffres reglables du jeu, a un seul endroit.

	Regle absolue du projet : aucun de ces nombres n'est ecrit en dur ailleurs
	dans le code. Ils seront modifies des dizaines de fois pendant les tests, et
	il faut pouvoir en changer un sans ouvrir un seul module de logique.

	Les commentaires marques "A REGLER" sont des valeurs que la fiche de
	conception ne fixait pas : ce sont des points de depart a valider en jouant.

	Ce module ne requiert rien et ne touche a aucune API Roblox : il se charge
	aussi bien dans Studio que dans les tests Lune en ligne de commande.
]]

local Config = {}

-- Numero de version du reglage, affiche au demarrage. A incrementer quand on
-- change un chiffre qui modifie l'equilibrage, pour savoir de quoi on parle
-- quand on compare deux sessions de test.
Config.version = 4

--------------------------------------------------------------------------------
-- LE CADRE : formats de partie
--------------------------------------------------------------------------------

-- Le 5v5 est ecarte au lancement : il demandait dix joueurs simultanes et ne
-- laissait aucune classe en reserve, donc pas de reroll possible.
Config.formats = {
	{ id = "1v1", playersPerTeam = 1, classesDrawn = 2, mirror = true },
	{ id = "2v2", playersPerTeam = 2, classesDrawn = 4, mirror = false },
	{ id = "3v3", playersPerTeam = 3, classesDrawn = 6, mirror = false },
	{ id = "4v4", playersPerTeam = 4, classesDrawn = 8, mirror = false },
}

-- Format de reference pour l'equilibrage : c'est celui sur lequel on tranche
-- quand deux formats disent le contraire.
Config.balanceReferenceFormat = "3v3"

--------------------------------------------------------------------------------
-- LA PARTIE ET LA MANCHE
--------------------------------------------------------------------------------

Config.match = {
	-- Premier a quatre manches gagnees, donc sept manches au maximum. Colle a
	-- l'arbre a six paliers : une victoire nette 4-0 donne quatre points et
	-- mene au palier 5, une serie complete de sept manches en donne sept et
	-- ouvre le palier 6, qui en coute six a lui seul. C'est ce qui donne son
	-- prix a une serie qui va au bout. (Verifie par un test : le commentaire
	-- disait palier 4, c'etait faux.)
	roundsToWin = 4,
	maxRounds = 7,
}

Config.round = {
	-- Pas de chronometre : la manche se termine a l'elimination totale d'une
	-- equipe. La zone qui se referme est la seule limite de duree.
	zoneFirstShrinkSeconds = 120,

	-- A REGLER : rythme et severite du resserrement.
	zoneShrinkIntervalSeconds = 20,
	zoneShrinkSteps = 4,
	zoneDamagePerSecond = 5,
	-- Compte a rebours avant le premier resserrement : la zone doit etre
	-- lisible, sinon les joueurs trouvent le systeme injuste.
	zoneWarningSeconds = 10,

	-- La zone peut etre coupee pour comparer une manche avec et sans.
	zoneEnabled = true,

	-- Rayon de depart deduit de la largeur de MapBounds, pour qu'une petite
	-- arene et une grande se referment toutes les deux correctement sans qu'on
	-- touche a un chiffre. A 0.5, la zone couvre la map entiere au depart.
	zoneStartRadiusMapRatio = 0.5,
	-- Quand la map n'a pas de MapBounds exploitable.
	zoneStartRadiusFallbackStuds = 140,
	-- Rayon final : assez large pour que le duel final ait lieu, trop etroit
	-- pour qu'on puisse encore fuir. C'est ce chiffre qui decide si la fin de
	-- manche est un affrontement ou une course-poursuite.
	zoneFinalRadiusStuds = 16,

	-- Hauteur du cylindre affiche. Purement visuel : les degats ne regardent
	-- que la distance horizontale au centre.
	zoneHeightStuds = 200,
}

--------------------------------------------------------------------------------
-- LA FENETRE D'AGONIE
--------------------------------------------------------------------------------

-- Vaut pour toutes les classes, pas seulement en presence d'un Infirmier.
-- Consequence : tant qu'un joueur est en agonie, son equipe n'est pas encore
-- eliminee et la manche continue.
Config.downed = {
	-- L'agonie peut etre coupee : la manche revient alors a l'elimination
	-- directe de l'etape 2, ce qui permet de comparer les deux.
	enabled = true,

	windowSeconds = 10,
	-- Un joueur a terre rampe a environ un quart de sa vitesse normale.
	crawlSpeedRatio = 0.25,
	-- Le relevement doit laisser le temps d'arriver sans etre gratuit.
	reviveSeconds = 4,
	-- Il faut etre au contact : relever de loin annulerait le risque pris.
	reviveRangeStuds = 8,
	-- Un joueur releve repart diminue. Sinon tomber ne coute rien et la fenetre
	-- d'agonie ne fait qu'allonger les manches.
	reviveHealthRatio = 0.4,
	-- Le moindre degat interrompt le relevement.
	reviveInterruptedByDamage = true,
	-- Un joueur a terre peut etre acheve : sans ca l'attaquant n'a aucun moyen
	-- d'empecher le relevement et l'Infirmier devient incontournable.
	canBeFinished = true,
	-- Si plus personne dans l'equipe n'est en mesure de relever, la manche
	-- s'arrete immediatement au lieu d'imposer dix secondes de temps mort.
	endRoundWhenNoReviverLeft = true,
}

--------------------------------------------------------------------------------
-- LE DRAFT
--------------------------------------------------------------------------------

Config.draft = {
	-- Interrupteur de comparaison, comme la zone, l'agonie et l'arbre : a
	-- false, les deux classes du prototype sont distribuees en dur et la partie
	-- commence tout de suite. C'est ce qui permet de revenir au duel nu pour
	-- juger une mecanique sans la phase de bans par-dessus.
	enabled = true,

	-- Un ban par equipe, quelle que soit la taille.
	bansPerTeam = 1,
	-- Bans alternes et pas simultanes : l'equipe B voit le ban de A, ce qui
	-- transforme le ban en decision plutot qu'en pari.
	alternatingBans = true,
	-- Vote rapide de l'equipe. Egalite : tirage au sort parmi les classes qui
	-- ont reuni le plus de voix. Personne ne vote : tirage parmi toutes.
	banVoteSeconds = 20,

	-- Chaque classe n'apparait qu'une fois dans toute la partie, pas une fois
	-- par equipe.
	uniqueClassesPerMatch = true,

	-- Un relancement par joueur et par partie, aveugle : on accepte avant de
	-- voir. Sinon le reroll devient un choix deguise.
	rerollsPerPlayer = 1,
	rerollIsBlind = true,

	-- L'echange de classe entre coequipiers est abandonne : il ne servait qu'a
	-- compenser l'absence de marge en 5v5.
	allowTeammateSwap = false,

	-- Le temps laisse pour accepter ou refuser le relancement. Court exprès :
	-- le relancement est aveugle, donc il n'y a rien a peser. C'est un pari,
	-- pas une decision, et un long compte a rebours ferait croire le contraire.
	rerollSeconds = 6,

	-- Le temps pendant lequel la classe tiree reste affichee en grand avant que
	-- la manche demarre. Il faut pouvoir lire son pouvoir ET sa faiblesse.
	revealSeconds = 5,
}

--------------------------------------------------------------------------------
-- L'ARBRE DE COMPETENCES
--------------------------------------------------------------------------------

Config.skillTree = {
	-- Interrupteur de comparaison, comme la zone et l'agonie : a false, le jeu
	-- revient exactement a l'etape 3, sans arbre et sans phase de depense.
	enabled = true,

	tiers = 6,
	branchesPerClass = 3,

	-- La duree de la phase de depense, entre deux manches. Elle doit laisser le
	-- temps de LIRE les trois branches la premiere fois, et se saute d'un bouton
	-- quand tout le monde a decide. A REGLER : quinze secondes est long si les
	-- joueurs connaissent deja leur classe, court s'ils decouvrent l'arbre.
	spendWindowSeconds = 15,

	-- On ne depense JAMAIS pendant une manche. Deux raisons : monter un palier
	-- qui touche les PV maximum rendrait l'achat equivalent a un soin complet au
	-- milieu d'un echange, et un arbre qui se modifie en combat transforme une
	-- decision de strategie en reflexe d'urgence.
	spendingDuringRound = false,

	-- Cout de chaque palier, du 1er au 6e. Le palier 1 est gratuit : choisir sa
	-- branche est une decision, pas un achat. Les paliers 2 a 5 coutent un
	-- point, le 6e en coute deux. Total pour aller au bout : six points.
	tierCosts = { 0, 1, 1, 1, 1, 2 },

	-- Un point avant la premiere manche (on choisit sa premiere competence en
	-- connaissant deja le matchup), puis un point a la fin de chaque manche.
	-- Le point donne apres la derniere manche ne sert a rien, donc une partie
	-- de M manches donne M points utilisables.
	pointsBeforeFirstRound = 1,
	pointsPerRoundEnd = 1,

	-- Point de revanche : une seule fois par partie, pour l'equipe qui vient de
	-- perdre trois manches d'affilee.
	comebackPoint = {
		enabled = true,
		consecutiveRoundsLost = 3,
		oncePerMatch = true,
		points = 1,
	},

	-- Visibilite : tout est affiche pour les coequipiers, les adversaires voient
	-- avec une manche de retard (le dernier palier pris reste cache jusqu'a la
	-- fin de la manche suivante).
	teammateVisibility = "full",
	opponentVisibilityDelayRounds = 1,

	-- L'arbre est remis a zero a chaque partie : il ne porte aucune progression
	-- de compte.
	resetEveryMatch = true,

	-- LES BRANCHES
	--
	-- Une branche par partie, verrouillee des qu'elle est choisie. Le palier 1
	-- est gratuit : il declenche le bonus de depart ET le sacrifice. Les
	-- paliers 2 a 5 poussent d'un cran le chiffre de la branche. Le palier 6
	-- donne l'effet nomme, et lui seul.
	--
	-- `onUnlock` est le sacrifice : il tombe au palier 1 et ne s'aggrave
	-- jamais. Une branche est un choix, pas une dette qui se creuse. Il se
	-- dit de trois facons, selon ce qu'on veut vraiment exprimer :
	--   onUnlock      ajoute (ou retire) une quantite
	--   onUnlockScale multiplie — "reduit de moitie"
	--   onUnlockSet   impose une valeur — "aucun vol de vie" vaut zero, pas
	--                 moins mille
	-- `perTier` est le cran, applique autant de fois qu'on a de paliers,
	-- plafonne a cinq : le sixieme palier n'ajoute pas de cran.
	--
	-- `implemented = false` sur un palier 6 veut dire que l'effet est decrit
	-- mais que le systeme dont il depend n'existe pas encore. Il est alors
	-- affiche comme indisponible plutot que de ne rien faire en silence.
	-- A REGLER : tous les chiffres ci-dessous sont des points de depart.
	branches = {
		vampire = {
			{
				id = "leech",
				name = "Sangsue",
				kind = "identity",
				summary = "Vol de vie accru",
				sacrifice = "Dégâts bruts plus faibles",
				onUnlock = { attackDamage = -2.5 },
				perTier = { lifestealRatio = 0.06 },
				tier6 = {
					label = "Le vol de vie fonctionne aussi sur les dégâts de zone",
					effect = "leechFromZone",
					implemented = true,
				},
			},
			{
				id = "beast",
				name = "Fauve",
				kind = "range",
				summary = "Vitesse et dégâts en hausse",
				sacrifice = "Vol de vie réduit de moitié",
				onUnlockScale = { lifestealRatio = 0.5 },
				perTier = { walkSpeed = 1, attackDamage = 1.2 },
				tier6 = {
					label = "Un bond court vers la cible, longue recharge",
					effect = "dash",
					implemented = true,
				},
			},
			{
				id = "plague",
				name = "Peste",
				kind = "resilience",
				summary = "Les dégâts se propagent aux ennemis proches",
				sacrifice = "Aucun vol de vie",
				onUnlockSet = { lifestealRatio = 0 },
				perTier = { spreadRatio = 0.05, spreadRadiusStuds = 1.6 },
				tier6 = {
					label = "La propagation ignore les armures",
					effect = "spreadPiercesArmor",
					-- Il n'y a pas encore d'armures a ignorer.
					implemented = false,
				},
			},
		},
		colossus = {
			{
				id = "ram",
				name = "Bélier",
				kind = "identity",
				summary = "La poussée devient une charge qui blesse",
				sacrifice = "Des PV maximum",
				onUnlock = { maxHealth = -20 },
				perTier = { knockbackDamage = 4, knockbackStuds = 4 },
				tier6 = {
					label = "La charge traverse plusieurs ennemis",
					effect = "chargePierces",
					implemented = true,
				},
			},
			{
				id = "catapult",
				name = "Catapulte",
				kind = "range",
				summary = "Il projette un bloc à distance moyenne",
				sacrifice = "Sa poussée au contact",
				-- Le bloc projete n'est pas une seconde commande : c'est son
				-- attaque qui devient lointaine. Un seul bouton, et une
				-- portee qui s'allonge a chaque palier.
				onUnlockSet = { knockbackStuds = 0, knockbackUpStuds = 0 },
				perTier = { attackRangeStuds = 5, attackDamage = 1.5 },
				tier6 = {
					label = "Le bloc laisse un obstacle quelques secondes",
					effect = "thrownLeavesCover",
					implemented = true,
				},
			},
			{
				id = "monolith",
				name = "Monolithe",
				kind = "resilience",
				summary = "Réduction des dégâts reçus",
				sacrifice = "Encore de la vitesse",
				onUnlock = { walkSpeed = -2 },
				perTier = { damageTakenRatio = -0.05 },
				tier6 = {
					label = "Immobile deux secondes : immunité aux projectiles",
					effect = "projectileImmunity",
					-- Il n'y a pas encore de projectiles.
					implemented = false,
				},
			},
		},
		-- LES DOUZE AUTRES CLASSES
		--
		-- Meme patron partout : identite (on creuse le pouvoir), distance (on
		-- echange le pouvoir contre de l'allonge et des degats), resilience (on
		-- echange des degats contre de la survie). Le sacrifice du palier 1 est
		-- toujours une vraie perte, jamais un alibi.

		tracker = {
			{
				id = "hunt",
				name = "Limier",
				kind = "identity",
				summary = "Traces plus anciennes et plus lointaines",
				sacrifice = "Moins de PV",
				onUnlock = { maxHealth = -10 },
				perTier = { trackAgeSeconds = 1.2, trackRadiusStuds = 8 },
				tier6 = {
					label = "Les traces indiquent aussi les PV de leur auteur",
					effect = "trackShowsHealth",
					implemented = true,
				},
			},
			{
				id = "snare",
				name = "Collet",
				kind = "range",
				summary = "Allonge et dégâts en hausse",
				sacrifice = "Ne lit plus les traces que de près",
				onUnlock = { trackRadiusStuds = -45 },
				perTier = { attackRangeStuds = 1.5, attackDamage = 1.4 },
				tier6 = {
					label = "Un coup porté révèle sa cible dix secondes",
					effect = "hitReveals",
					implemented = true,
				},
			},
			{
				id = "scout",
				name = "Éclaireur",
				kind = "resilience",
				summary = "Vitesse et régénération",
				sacrifice = "Dégâts réduits d'un tiers",
				onUnlockScale = { attackDamage = 0.7 },
				perTier = { walkSpeed = 1.2, regenPerSecond = 0.8 },
				tier6 = {
					label = "Ne déclenche plus les mines",
					effect = "ignoresMines",
					implemented = true,
				},
			},
		},

		artificer = {
			{
				id = "demolition",
				name = "Démolition",
				kind = "identity",
				summary = "Mines plus meurtrières",
				sacrifice = "Une mine de moins en stock",
				onUnlock = { mineCount = -1 },
				perTier = { mineDamage = 5, mineRadiusStuds = 0.6 },
				tier6 = {
					label = "Ses mines s'arment instantanément",
					effect = "minesArmInstantly",
					implemented = true,
				},
			},
			{
				id = "arsenal",
				name = "Arsenal",
				kind = "range",
				summary = "Beaucoup plus de mines, posées plus vite",
				sacrifice = "Mines bien plus faibles",
				onUnlockScale = { mineDamage = 0.6 },
				perTier = { mineCount = 1, abilityCooldownSeconds = -0.3 },
				tier6 = {
					label = "Le stock se réarme une fois par manche",
					effect = "minesRearm",
					implemented = true,
				},
			},
			{
				id = "bunker",
				name = "Bunker",
				kind = "resilience",
				summary = "PV et résistance",
				sacrifice = "Nettement plus lent",
				onUnlock = { walkSpeed = -3 },
				perTier = { maxHealth = 12, damageTakenRatio = -0.03 },
				tier6 = {
					label = "Ses propres mines le projettent sans le blesser",
					effect = "minesLaunchSelf",
					implemented = true,
				},
			},
		},

		spectre = {
			{
				id = "wraith",
				name = "Revenant",
				kind = "identity",
				summary = "Traversée plus longue et plus fréquente",
				sacrifice = "Moins de PV",
				onUnlock = { maxHealth = -15 },
				perTier = { phaseSeconds = 0.5, abilityCooldownSeconds = -1 },
				tier6 = {
					label = "Sortir de traversée souffle les ennemis autour",
					effect = "phaseExitBurst",
					implemented = true,
				},
			},
			{
				id = "blink",
				name = "Éclipse",
				kind = "range",
				summary = "Vitesse et allonge",
				sacrifice = "Traversée réduite de moitié",
				onUnlockScale = { phaseSeconds = 0.5 },
				perTier = { walkSpeed = 1.3, attackRangeStuds = 0.8 },
				tier6 = {
					label = "Toucher un ennemi recharge la traversée",
					effect = "phaseRefundOnHit",
					implemented = true,
				},
			},
			{
				id = "veil",
				name = "Voile",
				kind = "resilience",
				summary = "Encaisse nettement mieux",
				sacrifice = "Plus lent",
				onUnlock = { walkSpeed = -2.5 },
				perTier = { damageTakenRatio = -0.045, maxHealth = 8 },
				tier6 = {
					label = "Invisible pendant toute la traversée",
					effect = "phaseInvisible",
					implemented = true,
				},
			},
		},

		link = {
			{
				id = "communion",
				name = "Communion",
				kind = "identity",
				summary = "Lien plus long, et il récupère mieux",
				sacrifice = "Moins de PV",
				onUnlock = { maxHealth = -15 },
				perTier = { bondRangeStuds = 10, regenPerSecond = 0.6 },
				tier6 = {
					label = "Les soins reçus par l'allié le soignent aussi",
					effect = "bondSharesHealing",
					implemented = true,
				},
			},
			{
				id = "tether",
				name = "Attache",
				kind = "range",
				summary = "Il se bat vraiment",
				sacrifice = "Lien beaucoup plus court",
				onUnlock = { bondRangeStuds = -25 },
				perTier = { attackDamage = 1.6, attackRangeStuds = 0.6 },
				tier6 = {
					label = "L'allié lié frappe plus fort",
					effect = "bondBoostsAlly",
					implemented = true,
				},
			},
			{
				id = "anchor",
				name = "Ancre",
				kind = "resilience",
				summary = "Reprend moins de dégâts de l'allié, et encaisse mieux",
				sacrifice = "Nettement plus lent",
				onUnlockScale = { walkSpeed = 0.8 },
				perTier = { bondShareRatio = -0.06, damageTakenRatio = -0.03 },
				tier6 = {
					label = "Le lien protège aussi l'allié des dégâts de zone",
					effect = "bondCoversZone",
					implemented = true,
				},
			},
		},

		duelist = {
			{
				id = "honour",
				name = "Honneur",
				kind = "identity",
				summary = "Bonus de duel bien plus fort",
				sacrifice = "Pénalité encore plus lourde face au nombre",
				onUnlock = { duelPenaltyRatio = -0.1 },
				perTier = { duelBonusRatio = 0.07 },
				tier6 = {
					label = "En duel, ses coups ignorent la résistance adverse",
					effect = "duelPierces",
					implemented = true,
				},
			},
			{
				id = "riposte",
				name = "Riposte",
				kind = "range",
				summary = "Allonge et cadence",
				sacrifice = "Bonus de duel réduit de moitié",
				onUnlockScale = { duelBonusRatio = 0.5 },
				perTier = { attackRangeStuds = 0.9, attackCooldownSeconds = -0.04 },
				tier6 = {
					label = "Chaque coup encaissé accélère le suivant",
					effect = "riposteSpeeds",
					implemented = true,
				},
			},
			{
				id = "guard",
				name = "Garde",
				kind = "resilience",
				summary = "La pénalité face au nombre s'efface",
				sacrifice = "Plus aucun bonus de duel",
				onUnlockSet = { duelBonusRatio = 0 },
				perTier = { duelPenaltyRatio = 0.05, maxHealth = 9 },
				tier6 = {
					label = "Plus aucune pénalité, quel que soit le nombre",
					effect = "guardNoPenalty",
					implemented = true,
				},
			},
		},

		smith = {
			{
				id = "bastion",
				name = "Bastion",
				kind = "identity",
				summary = "Murs plus larges et plus durables",
				sacrifice = "Plus lent",
				onUnlock = { walkSpeed = -2 },
				perTier = { wallWidthStuds = 1.6, wallSeconds = 1.5 },
				tier6 = {
					label = "Ses murs laissent passer son équipe",
					effect = "wallSparesAllies",
					implemented = true,
				},
			},
			{
				id = "forge",
				name = "Forge",
				kind = "range",
				summary = "Il frappe comme il bâtit",
				sacrifice = "Murs bien plus petits",
				onUnlockScale = { wallWidthStuds = 0.6, wallHeightStuds = 0.7 },
				perTier = { attackDamage = 2, attackRangeStuds = 0.5 },
				tier6 = {
					label = "Le mur brûle qui le touche",
					effect = "wallBurns",
					implemented = true,
				},
			},
			{
				id = "rampart",
				name = "Rempart",
				kind = "resilience",
				summary = "PV et résistance",
				sacrifice = "Recharge bien plus longue",
				onUnlock = { abilityCooldownSeconds = 4 },
				perTier = { maxHealth = 14, damageTakenRatio = -0.035 },
				tier6 = {
					label = "Un mur se dresse seul quand il tombe à terre",
					effect = "wallOnDown",
					implemented = true,
				},
			},
		},

		pyromaniac = {
			{
				id = "inferno",
				name = "Enfer",
				kind = "identity",
				summary = "Brasier plus large et plus vorace",
				sacrifice = "Moins de PV",
				onUnlock = { maxHealth = -12 },
				perTier = { fireDamagePerSecond = 2, fireRadiusStuds = 0.8 },
				tier6 = {
					label = "Les flammes s'accrochent à qui en sort",
					effect = "fireClings",
					implemented = true,
				},
			},
			{
				id = "ember",
				name = "Braise",
				kind = "range",
				summary = "Allonge et dégâts",
				sacrifice = "Brasier deux fois plus bref",
				onUnlockScale = { fireSeconds = 0.5 },
				perTier = { attackRangeStuds = 0.9, attackDamage = 1.5 },
				tier6 = {
					label = "Un coup porté enflamme la cible",
					effect = "hitIgnites",
					implemented = true,
				},
			},
			{
				id = "ash",
				name = "Cendre",
				kind = "resilience",
				summary = "Encaisse mieux, et ses flammes le soignent",
				sacrifice = "Brasier bien moins dense",
				onUnlockScale = { fireDamagePerSecond = 0.65 },
				perTier = { damageTakenRatio = -0.04, maxHealth = 10 },
				tier6 = {
					label = "Marcher dans ses propres flammes le soigne",
					effect = "fireHealsSelf",
					implemented = true,
				},
			},
		},

		decoy = {
			{
				id = "mirage",
				name = "Mirage",
				kind = "identity",
				summary = "Clone plus durable, posé plus souvent",
				sacrifice = "Encore plus vulnérable pendant qu'il le tient",
				onUnlock = { cloneExposureRatio = 0.15 },
				perTier = { cloneSeconds = 1, abilityCooldownSeconds = -1 },
				tier6 = {
					label = "Deux clones au lieu d'un",
					effect = "twinClones",
					implemented = true,
				},
			},
			{
				id = "feint",
				name = "Feinte",
				kind = "range",
				summary = "Il frappe pendant que l'autre regarde ailleurs",
				sacrifice = "Clone deux fois plus bref",
				onUnlockScale = { cloneSeconds = 0.5 },
				perTier = { attackDamage = 1.6, walkSpeed = 0.8 },
				tier6 = {
					label = "Le clone explose en disparaissant",
					effect = "cloneBursts",
					implemented = true,
				},
			},
			{
				id = "shade",
				name = "Ombre",
				kind = "resilience",
				summary = "Plus aucune vulnérabilité pendant le leurre",
				sacrifice = "Recharge bien plus longue",
				onUnlock = { abilityCooldownSeconds = 6 },
				onUnlockSet = { cloneExposureRatio = 0 },
				perTier = { maxHealth = 10, damageTakenRatio = -0.03 },
				tier6 = {
					label = "Il devient invisible tant que le clone vit",
					effect = "cloneCloaks",
					implemented = true,
				},
			},
		},

		seismic = {
			{
				id = "quake",
				name = "Séisme",
				kind = "identity",
				summary = "Onde plus large et plus longue",
				sacrifice = "Plus lent",
				onUnlock = { walkSpeed = -2 },
				perTier = { slamRadiusStuds = 4, slamSeconds = 0.5 },
				tier6 = {
					label = "L'onde blesse ceux qu'elle atteint",
					effect = "slamDamages",
					implemented = true,
				},
			},
			{
				id = "fault",
				name = "Faille",
				kind = "range",
				summary = "Allonge et dégâts",
				sacrifice = "Onde réduite de moitié",
				onUnlockScale = { slamRadiusStuds = 0.5 },
				perTier = { attackDamage = 2, attackRangeStuds = 0.7 },
				tier6 = {
					label = "Son prochain coup déclenche une onde",
					effect = "slamOnHit",
					implemented = true,
				},
			},
			{
				id = "bedrock",
				name = "Socle",
				kind = "resilience",
				summary = "PV et résistance",
				sacrifice = "Ralentissement deux fois plus faible",
				onUnlockScale = { slamSlowRatio = 0.5 },
				perTier = { maxHealth = 13, damageTakenRatio = -0.035 },
				tier6 = {
					label = "Plus rien ne le repousse",
					effect = "bedrockNoKnockback",
					implemented = true,
				},
			},
		},

		parasite = {
			{
				id = "infest",
				name = "Infestation",
				kind = "identity",
				summary = "Vol de soins accru, marque plus longue",
				sacrifice = "Moins de PV",
				onUnlock = { maxHealth = -12 },
				perTier = { markHealStealRatio = 0.08, markSeconds = 2 },
				tier6 = {
					label = "La marque saute sur un autre ennemi quand sa cible tombe",
					effect = "markJumps",
					implemented = true,
				},
			},
			{
				id = "host",
				name = "Hôte",
				kind = "range",
				summary = "Marque de bien plus loin, et frappe mieux",
				sacrifice = "Marque deux fois plus brève",
				onUnlockScale = { markSeconds = 0.5 },
				perTier = { markRangeStuds = 8, attackDamage = 1.4 },
				tier6 = {
					label = "Frapper sa cible marquée le soigne",
					effect = "markLifesteal",
					implemented = true,
				},
			},
			{
				id = "symbiosis",
				name = "Symbiose",
				kind = "resilience",
				summary = "Il se régénère vraiment",
				sacrifice = "Ne vole plus aucun soin",
				onUnlockSet = { markHealStealRatio = 0 },
				perTier = { regenPerSecond = 0.9, maxHealth = 9 },
				tier6 = {
					label = "Voit tous les ennemis blessés, marqués ou non",
					effect = "seesWounded",
					implemented = true,
				},
			},
		},

		chameleon = {
			{
				id = "ambush",
				name = "Embuscade",
				kind = "identity",
				summary = "Disparaît plus vite, frappe plus fort",
				sacrifice = "Moins de PV",
				onUnlock = { maxHealth = -10 },
				perTier = { cloakDelaySeconds = -0.15, attackDamage = 1.2 },
				tier6 = {
					label = "Le premier coup après un camouflage compte double",
					effect = "ambushDouble",
					implemented = true,
				},
			},
			{
				id = "stalk",
				name = "Traque",
				kind = "range",
				summary = "Bouge sans se révéler",
				sacrifice = "Dégâts réduits d'un tiers",
				onUnlockScale = { attackDamage = 0.7 },
				perTier = { cloakSpeedThreshold = 1.4, walkSpeed = 0.8 },
				tier6 = {
					label = "Reste invisible tant qu'il marche lentement",
					effect = "stalkWalks",
					implemented = true,
				},
			},
			{
				id = "husk",
				name = "Carapace",
				kind = "resilience",
				summary = "PV et résistance",
				sacrifice = "Bien plus long à disparaître",
				onUnlock = { cloakDelaySeconds = 1 },
				perTier = { maxHealth = 11, damageTakenRatio = -0.035 },
				tier6 = {
					label = "Être touché le recamoufle aussitôt",
					effect = "huskRecloaks",
					implemented = true,
				},
			},
		},

		medic = {
			{
				id = "triage",
				name = "Triage",
				kind = "identity",
				summary = "Relève bien plus vite, et en meilleur état",
				sacrifice = "Dégâts réduits d'un tiers",
				onUnlockScale = { attackDamage = 0.7 },
				perTier = { reviveSpeedRatio = 0.3, reviveHealthBonusRatio = 0.06 },
				tier6 = {
					label = "Relève sans avoir à s'approcher",
					effect = "remoteRevive",
					implemented = true,
				},
			},
			{
				id = "field",
				name = "Terrain",
				kind = "range",
				summary = "Il se bat au lieu d'attendre",
				sacrifice = "Relève à la vitesse de tout le monde",
				onUnlockSet = { reviveSpeedRatio = 1 },
				perTier = { attackDamage = 1.5, attackRangeStuds = 0.7 },
				tier6 = {
					label = "Ses alliés proches se régénèrent",
					effect = "fieldRegen",
					implemented = true,
				},
			},
			{
				id = "ward",
				name = "Garde-malade",
				kind = "resilience",
				summary = "PV et résistance",
				sacrifice = "Nettement plus lent",
				onUnlock = { walkSpeed = -2.5 },
				perTier = { maxHealth = 12, damageTakenRatio = -0.035 },
				tier6 = {
					label = "Un relèvement qu'il a commencé ne peut plus être interrompu",
					effect = "steadyHands",
					implemented = true,
				},
			},
		},
	},

	-- Les points en reserve, une fois l'arbre termine, vont aux ameliorations
	-- communes a toutes les classes.
	-- A REGLER : les gains exacts de ces ameliorations.
	sparePointUpgrades = {
		{ id = "health", label = "PV", amount = 10 },
		{ id = "speed", label = "Vitesse", amount = 1 },
		{ id = "cooldown", label = "Recharge", amount = -0.5 },
	},
}

--------------------------------------------------------------------------------
-- LE BUDGET D'EQUIPEMENT
--------------------------------------------------------------------------------

Config.loadout = {
	-- Douze points et pas quinze : le maximum de chaque categorie additionne
	-- fait environ vingt-trois, donc a douze on renonce a la moitie de ce qu'on
	-- pourrait porter et chaque assemblage est un vrai sacrifice.
	budgetPoints = 12,

	-- Aucun emplacement impose, mais trois garde-fous :
	-- pas deux fois le meme objet, une seule armure, six objets au maximum.
	-- Les six objets sont une contrainte d'ergonomie, pas d'equilibrage :
	-- beaucoup de joueurs Roblox sont sur telephone.
	maxItems = 6,
	minWeapons = 1,
	allowDuplicateItems = false,

	-- Un seul objet par categorie, sauf les utilitaires. L'armure est le cas
	-- evident ; l'arme principale et la secondaire le sont moins, mais une
	-- deuxieme principale ne servirait jamais : la secondaire sort toute seule
	-- quand la cible est trop loin, donc deux principales veut dire une arme
	-- payee et jamais utilisee.
	--
	-- Les utilitaires n'y figurent pas, et c'est tout l'interet de la
	-- categorie : c'est la seule ou on peut empiler.
	maxPerCategory = {
		primary = 1,
		secondary = 1,
		armor = 1,
		heal = 2,
	},

	-- Fourchettes de cout par categorie. La puissance d'un objet est portee par
	-- son cout en points, jamais par sa rarete.
	categories = {
		{ id = "primary", label = "Arme principale", minCost = 4, maxCost = 7, required = true },
		{ id = "secondary", label = "Arme secondaire", minCost = 2, maxCost = 4, required = false },
		{ id = "armor", label = "Armure", minCost = 1, maxCost = 5, required = false },
		{ id = "heal", label = "Soin", minCost = 1, maxCost = 3, required = false },
		{ id = "utility", label = "Utilitaire", minCost = 1, maxCost = 4, required = false },
	},

	-- Affinites de classe : deux ou trois objets par classe coutent un point de
	-- moins. L'identite de classe est preservee sans bloquer un objet derriere
	-- une loterie.
	affinityDiscount = 1,
	affinityItemsPerClassMin = 2,
	affinityItemsPerClassMax = 3,

	-- L'ECRAN D'EQUIPEMENT ET LES TOUCHES.
	--
	-- L'assemblage se modifie entre deux manches, jamais pendant : il est pris
	-- en compte a l'apparition suivante. Sinon on change d'armure en pleine
	-- fusillade, et le budget cesse d'etre un choix.
	editKey = "L",

	-- Les objets consommables occupent des emplacements numerotes, dans l'ordre
	-- de l'assemblage. Les chiffres plutot qu'une touche par objet : l'objet
	-- change a chaque partie, le chiffre non.
	--
	-- Quatre au maximum, parce que c'est le plus qu'on puisse porter — un soin
	-- plus trois utilitaires a un point — et parce qu'au-dela l'interface ne
	-- tient pas sur un ecran de telephone.
	maxUsableSlots = 4,
	useKeys = { "One", "Two", "Three", "Four" },

	-- Une demi-seconde entre deux utilisations, toutes charges confondues. Sans
	-- ca, deux grenades partent dans la meme seconde et la zone devient un
	-- feu d'artifice.
	useCooldownSeconds = 0.6,

	-- Les charges reviennent entre deux manches, comme les mines de
	-- l'Artificier. Une manche est l'unite de reserve du jeu.
	chargesRefillBetweenRounds = true,

	-- L'ARME SE VOIT DANS LA MAIN, et elle bouge quand on frappe.
	--
	-- Ce n'est pas de la decoration : avec treize objets, savoir qu'on a en
	-- face un fusil a pompe plutot qu'un arc change ce qu'on fait de la
	-- seconde suivante. Sans arme visible, l'equipement est une feuille de
	-- calcul que personne ne voit.
	--
	-- Les quatre mouvements disent ce que l'arme fait : `slash` fauche de
	-- cote, `overhead` s'abat de haut en bas, `recoil` recule sous le depart
	-- du coup, `draw` tire en arriere puis relache. Chacun est decrit par un
	-- angle et deux durees, jamais par une animation televersee : une
	-- animation demande un identifiant d'asset, donc un televersement, donc
	-- quelque chose que personne ne peut verifier en lisant le depot.
	weaponMotion = {
		-- La duree de depart et de retour, en secondes. La montee est plus
		-- rapide que la descente : un coup part sec et se repose.
		outSeconds = 0.07,
		backSeconds = 0.16,

		-- `pitch` LEVE la pointe quand il est positif, `yaw` la fauche vers la
		-- gauche quand il est positif, `roll` la fait tourner sur son axe, le
		-- tout en degres. `pullStuds` recule l'arme dans la main, et c'est ce
		-- qui fait un arc qu'on bande.
		--
		-- CES SIGNES ONT ETE MESURES, PAS DEVINES. Deux des quatre gestes
		-- partaient a l'envers au premier jet : le marteau se relevait au lieu
		-- de s'abattre et le fusil plongeait du canon au lieu de le lever.
		-- Rien dans les tests ne pouvait le dire, et la capture d'ecran de
		-- Studio ne montre pas la 3D. La verification est le calcul de la
		-- position de la pointe avant et apres le geste : elle est dans
		-- docs/A-TESTER.md. Avant de retoucher un signe ici, refaire ce calcul.
		--
		-- La machette fauche VERS LA GAUCHE parce que la main est la droite :
		-- un coup qui part vers l'exterieur est un elan, celui qui traverse le
		-- corps est la frappe, et c'est la frappe qui doit etre rapide.
		slash = { pitch = 10, yaw = 100, roll = -25, pullStuds = 0 },
		overhead = { pitch = -75, yaw = 0, roll = 0, pullStuds = 0 },
		recoil = { pitch = 26, yaw = 0, roll = 0, pullStuds = 0.45 },
		draw = { pitch = 0, yaw = 0, roll = 0, pullStuds = 1.4 },
	},
}

--------------------------------------------------------------------------------
-- LE CATALOGUE D'OBJETS
--------------------------------------------------------------------------------

-- Cible a terme et contenu du prototype. Douze objets suffisent a tester si le
-- systeme de budget est bon : s'il n'est pas amusant a douze, il ne le sera pas
-- davantage a soixante-deux.
--
-- Il y en a treize et pas douze, pour une raison precise : avec un seul soin,
-- la question « est-ce que je paie un point ou deux pour me soigner » ne se
-- pose pas, et c'est exactement la question que le budget doit faire naitre.
Config.itemCounts = {
	target = { primary = 24, secondary = 10, armor = 8, heal = 6, utility = 14 },
	prototype = { primary = 4, secondary = 2, armor = 2, heal = 2, utility = 3 },
}

-- LES OBJETS.
--
-- Un objet ne remplace jamais la classe : il la deforme. Ses chiffres sont des
-- FACTEURS (`scale`) et des DECALAGES (`offset`) appliques aux statistiques de
-- la classe, comme une branche d'arbre. Un Vampire au marteau frappe donc fort
-- et lentement, mais reste un Vampire : il garde son vol de vie et ses cent PV.
--
-- C'est ce qui evite le piege de l'arme a chiffres absolus, ou toutes les
-- classes portant la meme arme frappent pareil et ou l'identite de classe
-- disparait des qu'on ouvre l'equipement.
--
-- L'ARME SECONDAIRE N'EST PAS UNE DEUXIEME TOUCHE. Elle sert automatiquement
-- quand la cible est hors de portee de l'arme principale, et c'est tout ce
-- qu'elle fait. C'est litteralement ce que la fiche lui demande — « combler un
-- trou de l'arme principale » — et ca ne coute aucune touche de plus, ce qui
-- compte sur telephone.
--
-- `use` decrit un objet consommable : le joueur l'utilise, il a des charges, et
-- les charges reviennent entre deux manches. Les objets sans `use` agissent
-- tout seuls, en permanence.
Config.items = {
	------------------------------------------------------------------ principales
	{
		id = "machete",
		category = "primary",
		cost = 4,
		name = "Machette",
		summary = "Mêlée rapide, portée courte",
		-- Moins de degats par coup mais une cadence bien plus elevee : environ
		-- 30 % de degats par seconde en plus, paye par une portee reduite.
		scale = { attackDamage = 0.85, attackCooldownSeconds = 0.65, attackRangeStuds = 0.8 },
		look = {
			size = { 0.14, 0.52, 3 },
			color = { 172, 179, 192 },
			grip = { 0, -0.9, -1.1 },
			swing = "slash",
			voice = "blade",
			head = { size = { 0.2, 0.26, 0.8 }, color = { 68, 50, 38 }, atStuds = 1.3 },
		},
	},
	{
		id = "shotgun",
		category = "primary",
		cost = 5,
		name = "Fusil à pompe",
		summary = "Dévastateur à bout portant, inutile au-delà",
		-- Le coup double, la cadence s'ecroule, et la portee tombe a environ
		-- quatre studs : il faut etre colle a sa cible. C'est l'arme qui
		-- demande le plus de courage du catalogue.
		scale = { attackDamage = 2, attackCooldownSeconds = 1.45, attackRangeStuds = 0.55 },
		look = {
			size = { 0.3, 0.38, 2.2 },
			color = { 96, 78, 62 },
			grip = { 0, -0.7, -1.1 },
			swing = "recoil",
			voice = "gun",
			head = { size = { 0.22, 0.22, 2.1 }, color = { 54, 58, 66 }, atStuds = -2 },
		},
	},
	{
		id = "compositeBow",
		category = "primary",
		cost = 6,
		name = "Arc composite",
		summary = "Longue portée, traverse une partie des armures",
		-- Trois fois la portee de la classe, pour des degats par seconde un peu
		-- en dessous : on paie la distance, on ne la recoit pas gratuitement.
		scale = { attackDamage = 1.15, attackCooldownSeconds = 1.25, attackRangeStuds = 3.2 },
		-- La moitie de la reduction de degats de la cible est ignoree. C'est le
		-- seul contre aux armures lourdes du catalogue, et c'est voulu : sans
		-- lui, l'armure a cinq points n'a aucune reponse.
		armorPierceRatio = 0.5,
		look = {
			size = { 0.16, 4.4, 0.46 },
			color = { 138, 100, 62 },
			grip = { 0, -0.6, -0.9 },
			swing = "draw",
			voice = "bow",
			head = { size = { 0.07, 4.1, 0.07 }, color = { 232, 230, 220 }, atStuds = 0.5 },
		},
	},
	{
		id = "warhammer",
		category = "primary",
		cost = 7,
		name = "Marteau de guerre",
		summary = "Dégâts énormes, très lent, repousse fort",
		scale = { attackDamage = 2.4, attackCooldownSeconds = 1.9, attackRangeStuds = 1 },
		offset = { knockbackStuds = 35, knockbackUpStuds = 10 },
		look = {
			size = { 0.3, 0.3, 3.4 },
			color = { 92, 70, 52 },
			grip = { 0, -1, -1.2 },
			swing = "overhead",
			voice = "blunt",
			head = { size = { 0.9, 0.9, 0.85 }, color = { 84, 88, 98 }, atStuds = -1.4 },
		},
	},

	------------------------------------------------------------------ secondaires
	{
		id = "knife",
		category = "secondary",
		cost = 2,
		name = "Couteau",
		summary = "Rapide et faible, pour quand on n'a plus rien",
		scale = { attackDamage = 0.5, attackCooldownSeconds = 0.5, attackRangeStuds = 0.7 },
		look = {
			size = { 0.1, 0.38, 1.6 },
			color = { 198, 204, 214 },
			grip = { 0, -0.9, -0.7 },
			swing = "slash",
			voice = "blade",
			head = { size = { 0.16, 0.22, 0.5 }, color = { 54, 56, 62 }, atStuds = 0.65 },
		},
	},
	{
		id = "smg",
		category = "secondary",
		cost = 4,
		name = "Pistolet-mitrailleur",
		summary = "Rafale courte, bonne à mi-distance",
		scale = { attackDamage = 0.8, attackCooldownSeconds = 0.55, attackRangeStuds = 1.8 },
		look = {
			size = { 0.3, 0.56, 1.5 },
			color = { 52, 56, 64 },
			grip = { 0, -0.7, -0.7 },
			swing = "recoil",
			voice = "gun",
			head = { size = { 0.17, 0.17, 1.2 }, color = { 86, 90, 98 }, atStuds = -1.2 },
		},
	},

	---------------------------------------------------------------------- armures
	{
		id = "lightArmor",
		category = "armor",
		cost = 2,
		name = "Armure légère",
		summary = "Réduction légère, aucun malus",
		offset = { damageTakenRatio = -0.08 },
	},
	{
		id = "heavyArmor",
		category = "armor",
		cost = 5,
		name = "Armure lourde",
		summary = "Très forte réduction, grosse perte de vitesse",
		offset = { damageTakenRatio = -0.28 },
		scale = { walkSpeed = 0.78 },
	},

	------------------------------------------------------------------------ soins
	{
		id = "stimulant",
		category = "heal",
		cost = 1,
		name = "Stimulant",
		summary = "Petit soin instantané, une seule charge",
		-- Instantane : c'est tout ce qu'il a pour lui, et c'est beaucoup. Un
		-- point pour sortir d'un echange perdu d'un cheveu.
		use = { kind = "heal", charges = 1, amount = 25, castSeconds = 0 },
	},
	{
		id = "medkit",
		category = "heal",
		cost = 2,
		name = "Trousse de soin",
		summary = "Soin moyen, deux charges, pose lente",
		-- Presque deux fois plus de PV pour un point de plus, mais il faut une
		-- seconde et demie a l'abri, et un seul coup recu annule la pose.
		use = {
			kind = "heal",
			charges = 2,
			amount = 45,
			castSeconds = 1.6,
			interruptedByDamage = true,
		},
	},

	------------------------------------------------------------------ utilitaires
	{
		id = "lightMine",
		category = "utility",
		cost = 1,
		name = "Mine légère",
		summary = "Un piège posé au sol, une charge",
		use = {
			kind = "mine",
			charges = 1,
			damage = 22,
			radiusStuds = 8,
			armSeconds = 1.2,
			knockbackStuds = 28,
			knockbackUpStuds = 18,
		},
	},
	{
		id = "grenade",
		category = "utility",
		cost = 2,
		name = "Grenade",
		summary = "Dégâts de zone à l'impact, deux charges",
		-- Elle ne blesse que les adversaires, comme les mines de l'Artificier.
		-- Les degats aux allies sont un sujet que la fiche n'ouvre jamais, et
		-- l'ouvrir ici en cachette serait une decision de conception.
		use = {
			kind = "grenade",
			charges = 2,
			damage = 34,
			radiusStuds = 12,
			fuseSeconds = 1.6,
			throwStuds = 55,
		},
	},
	{
		id = "deployableShield",
		category = "utility",
		cost = 4,
		name = "Bouclier déployable",
		summary = "Une couverture posée devant soi, temporaire",
		-- Il bloque les deux equipes, exactement comme le mur du Forgeron. Une
		-- couverture qui ne gene que l'adversaire ne serait pas une
		-- couverture, ce serait un bouclier magique.
		use = {
			kind = "shield",
			charges = 1,
			seconds = 14,
			widthStuds = 10,
			heightStuds = 7,
			thicknessStuds = 1.6,
			aheadStuds = 6,
		},
	},
}

-- LES AFFINITES DE CLASSE : un point de moins sur deux ou trois objets.
--
-- Le catalogue n'en compte que treize, donc plusieurs classes n'ont ici qu'une
-- seule affinite, et certaines pointent vers l'equivalent le plus proche de
-- l'objet que la fiche leur donnait — le Vampire a la machette plutot qu'aux
-- griffes, qui n'existent pas encore. La liste complete est dans
-- docs/OBJETS.md et se remplira avec le catalogue.
--
-- Aucune affinite ne porte sur un objet a un point : avec la remise il
-- deviendrait gratuit, et un objet gratuit est pris par tout le monde. Un test
-- le verifie.
Config.itemAffinities = {
	vampire = { "machete", "knife" },
	colossus = { "warhammer", "deployableShield", "heavyArmor" },
	tracker = { "compositeBow" },
	artificer = { "grenade" },
	spectre = { "machete" },
	link = { "medkit" },
	duelist = { "smg", "lightArmor" },
	smith = { "deployableShield", "lightArmor" },
	pyromaniac = { "grenade" },
	decoy = { "smg" },
	seismic = { "warhammer" },
	parasite = { "knife" },
	chameleon = { "knife", "compositeBow" },
	medic = { "medkit" },
}

--------------------------------------------------------------------------------
-- LES TIRAGES
--------------------------------------------------------------------------------

Config.draws = {
	-- Equiprobabilite stricte : aucun tirage n'est un jackpot, aucun objet n'est
	-- un dechet, et la chance decide du style de jeu, jamais des matchs.
	equiprobable = true,

	-- Un tirage sur sept donne obligatoirement un objet non debloque. Sans ce
	-- filet, la fin de collection coute pres de 200 tirages. Avec, la collection
	-- complete passe d'environ 290 tirages a 175.
	guaranteedNewEveryDraws = 7,
	-- Le compteur se remet a zero des qu'un objet neuf tombe, naturellement ou
	-- par la garantie : sinon on obtient des rafales de nouveautes tous les sept
	-- tirages puis plus rien.
	counterResetsOnAnyNewItem = true,

	-- Trois tirages garantis a l'ouverture du compte, un objet de chaque type
	-- essentiel, piochés uniquement parmi les objets a cout faible : sinon un
	-- debutant tire l'arme a sept points et se retrouve avec un assemblage
	-- impossible a completer dans le budget.
	-- Le plafond doit rester AU MOINS egal a l'arme principale la moins chere,
	-- sinon la categorie n'a aucun candidat et le debutant demarre sans arme.
	-- Un test le verifie, parce que ce piege ne se voit qu'au premier compte
	-- cree — c'est-a-dire jamais pendant les tests.
	starterDraws = 3,
	starterDrawsMaxItemCost = 4,
	starterDrawsCategories = { "primary", "armor", "heal" },

	-- Les vingt premieres parties sont accelerees, sinon un nouveau joueur met
	-- des semaines avant d'avoir de quoi remplir ses douze points.
	newPlayerBoostMatches = 20,
	newPlayerCrateEveryMatches = 2,
}

--------------------------------------------------------------------------------
-- L'ECONOMIE DES PIECES
--------------------------------------------------------------------------------

-- Ces chiffres donnent une caisse toutes les trois parties en ecrasant tout,
-- quatre en gagnant serre, cinq en perdant serre, six en se faisant ecraser.
Config.economy = {
	crateCost = 1000,

	winBase = 220,
	winPerRoundNotConceded = 30,

	lossBase = 170,
	lossPerRoundWon = 10,

	-- Sur quoi mesurer la performance : pas sur les eliminations. Dans un mode
	-- ou la manche s'arrete a l'equipe entiere, recompenser les kills pousse a
	-- jouer pour soi.
	rewardKills = false,
	performanceMetrics = { "damage", "roundsSurvived", "assists" },
}

--------------------------------------------------------------------------------
-- LES FRAGMENTS ET LES SKINS
--------------------------------------------------------------------------------

-- Les doublons donnent des fragments, et les fragments ne servent qu'aux skins.
-- Pas de montee en niveau des armes, pas d'achat cible : deux exemplaires du
-- meme objet sont strictement identiques.
-- Attention : le taux de doublons pilote deux economies a la fois. Moins de
-- doublons veut dire moins de fragments, donc des skins plus rares. Ces deux
-- reglages se changent ensemble, jamais separement.
Config.cosmetics = {
	fragmentsPerDuplicate = 50,

	-- Reference du marche : Murder Mystery 2 place ses skins d'armes entre 100
	-- et 300 Robux. En dessous de 50 l'achat ne rapporte presque rien, au-dessus
	-- de 500 il faut une valeur percue tres forte.
	skinTiers = {
		{ id = "common", label = "Commun", robux = 75, fragments = 500 },
		{ id = "rare", label = "Rare", robux = 150, fragments = 1000 },
		{ id = "epic", label = "Epique", robux = 300, fragments = 2000 },
		{ id = "legendary", label = "Legendaire", robux = 500, fragments = 4000 },
	},
}

--------------------------------------------------------------------------------
-- LE CLASSEMENT
--------------------------------------------------------------------------------

Config.elo = {
	-- Le classe est le mode par defaut. Les parties privees entre amis sont
	-- natives sur Roblox et ne comptent pas : c'est la qu'on teste.
	rankedByDefault = true,
	privateMatchesRanked = false,
	-- Le 1v1 miroir est classe comme les autres formats.
	mirrorRanked = true,

	startingRating = 1000,

	-- Le coefficient K baisse avec le nombre de parties JOUEES PAR LE JOUEUR,
	-- pas avec la taille de la population. C'est la methode des systemes qui
	-- tiennent (FIDE fonctionne par paliers de ce genre) : un nouveau venu doit
	-- rejoindre son niveau reel en quelques parties, un habitue ne doit pas
	-- voir son classement sauter sur un mauvais soir.
	--
	-- 32 est la valeur par defaut courante dans les communautes de jeu, et on
	-- recommande 48 a 64 pour un petit groupe qui demarre, justement pour que
	-- le classement se stabilise vite. Les sources sont dans
	-- docs/EQUILIBRAGE.md. Si le classement reste trop nerveux a quelques
	-- dizaines de joueurs, la vraie reponse n'est pas de baisser K mais de
	-- passer a Glicko, qui porte une incertitude par joueur.
	kFactorTiers = {
		{ upToMatchesPlayed = 10, kFactor = 64 },
		{ upToMatchesPlayed = 40, kFactor = 48 },
		{ upToMatchesPlayed = math.huge, kFactor = 32 },
	},
}

--------------------------------------------------------------------------------
-- LA CAMERA
--------------------------------------------------------------------------------

Config.camera = {
	-- Premiere ou troisieme personne au choix, y compris en classe : si tout le
	-- monde peut basculer, l'avantage disparait. Consequence pour les maps : en
	-- troisieme personne on voit derriere un angle sans s'exposer, donc les
	-- couvertures doivent etre dessinees en partant de ce principe.
	allowFirstPerson = true,
	allowThirdPerson = true,
}

--------------------------------------------------------------------------------
-- LE PROTOTYPE
--------------------------------------------------------------------------------

-- Deux joueurs, deux classes, une surface plane, trois manches. L'etape 3 y a
-- ajoute la zone qui se referme et la fenetre d'agonie : les deux se coupent
-- depuis Config.round.zoneEnabled et Config.downed.enabled, pour pouvoir
-- comparer une manche avec et une manche sans.
-- Pas encore d'arbre, pas encore d'equipement.
Config.prototype = {
	enabled = true,
	classes = { "vampire", "colossus" },

	-- Premier a deux manches gagnees, donc trois manches au maximum.
	roundsToWin = 2,

	secondsBeforeRoundStarts = 3,
	secondsBetweenRounds = 4,
	secondsBetweenMatches = 8,

	-- Les deux joueurs echangent de classe d'une partie a l'autre : chacun doit
	-- juger les deux cotes du duel, pas seulement le sien.
	swapClassesBetweenMatches = true,
}

--------------------------------------------------------------------------------
-- LE COMBAT
--------------------------------------------------------------------------------

Config.combat = {
	-- Roblox regenere la vie de tout le monde par defaut, sans qu'on le lui
	-- demande. On coupe cette regeneration pour la piloter par classe : sans
	-- ca, la faiblesse du Vampire n'existe pas.
	disableDefaultRegen = true,

	-- Delai sans degat donne ni recu avant de compter comme hors combat.
	outOfCombatSeconds = 5,

	-- Les bornes de la reduction de degats (branche Monolithe). Personne ne
	-- devient invulnerable par accumulation de paliers, et personne ne prend le
	-- double : une statistique qui peut atteindre zero finit toujours par y
	-- arriver, et un joueur invincible n'est plus un joueur.
	damageTakenRatioMin = 0.5,
	damageTakenRatioMax = 2,

	-- Combien d'ennemis au maximum recoivent la propagation d'un seul coup
	-- (branche Peste). A REGLER : sans plafond, la Peste devient la meilleure
	-- branche du jeu des que les equipes grandissent.
	spreadMaxTargets = 3,
}

--------------------------------------------------------------------------------
-- CE QUI REND LE COMBAT LISIBLE
--------------------------------------------------------------------------------

-- Du decor, uniquement. Aucun de ces chiffres ne change l'etat du jeu : ils
-- decident seulement de ce qu'on voit. Mais un duel illisible ne peut pas etre
-- juge amusant, donc ils comptent autant que les autres.
Config.effects = {
	enabled = true,

	-- Les nombres qui montent au-dessus d'un coup.
	numberSeconds = 0.9,
	numberRiseStuds = 4.5,
	numberSize = 28,
	-- Un coup plus fort s'ecrit plus gros, jusqu'a cette limite. C'est ce qui
	-- fait qu'un coup de Colosse et un coup de Vampire ne se ressemblent pas,
	-- sans avoir a lire le chiffre.
	numberSizeMax = 46,
	numberSizeReference = 30,

	-- Le coup lui-meme : un trait qui part de l'attaquant. Il part MEME dans le
	-- vide : c'est comme ca qu'on apprend la portee de sa classe.
	swingSeconds = 0.18,
	swingWidthStuds = 3.2,
	swingHeightStuds = 0.5,

	-- L'eclair sur la cible touchee.
	flashSeconds = 0.22,
	flashStuds = 3.5,

	-- La trainee du bond du Fauve.
	dashSeconds = 0.35,

	-- Les degats de zone se cumulent avant d'etre annonces : sans ca, un nombre
	-- partirait a chaque image et l'ecran serait illisible.
	zoneNumberIntervalSeconds = 1,
}

--------------------------------------------------------------------------------
-- LES EFFETS DE PALIER 6
--------------------------------------------------------------------------------

-- Chaque effet nomme du dernier palier a ses chiffres ici. Les deux effets qui
-- attendent un systeme absent du jeu (armures, projectiles) n'en ont pas : leur
-- drapeau `implemented` est a false dans skillTree.branches, et l'interface les
-- affiche comme indisponibles.
Config.tier6 = {
	-- Fauve : un bond court vers la cible. La longue recharge est ce qui
	-- l'empeche d'etre une simple augmentation de vitesse.
	dash = {
		cooldownSeconds = 8,
		-- Plus loin que la portee d'attaque du Vampire (7), sinon le bond ne
		-- sert jamais : il faudrait deja etre a portee pour l'utiliser.
		rangeStuds = 34,
		speedStuds = 95,
		upStuds = 22,
	},

	-- Belier : la charge traverse. Chaque ennemi suivant prend moins, sinon un
	-- seul coup dans un groupe decide la manche.
	chargePierces = {
		maxTargets = 3,
		falloffPerTarget = 0.3,
	},

	-- Catapulte : le bloc projete reste au sol quelques secondes. C'est une
	-- couverture, donc elle collisionne — y compris pour celui qui l'a lancee.
	thrownLeavesCover = {
		seconds = 6,
		sizeStuds = { 6, 7, 6 },
	},

	-- Sangsue : le vol de vie fonctionne aussi sur les degats de zone subis par
	-- les ennemis. Le ratio est module, sinon un Vampire gagne la fin de manche
	-- en restant au centre a regarder la zone travailler pour lui.
	leechFromZone = {
		ratioOfLifesteal = 0.5,
	},
}

-- A REGLER : ce sont les chiffres les plus provisoires du fichier. Ils ne se
-- valident qu'en jouant le duel, et c'est tout l'objet de l'etape 2.
--
-- Le duel est calibre pour etre serre : le Colosse tue le Vampire en huit a
-- neuf secondes de contact continu, le Vampire met le meme temps a entamer les
-- 170 PV du Colosse. Le repoussement est l'outil du Colosse pour casser le vol
-- de vie, la vitesse est l'outil du Vampire pour revenir au contact.
-- LE SON.
--
-- Il n'y en avait aucun jusqu'au 26 octobre 2026, et c'etait le plus gros
-- manque du jeu : un coup qui touche et un coup qui rate se ressemblaient
-- exactement, alors que c'est l'information la plus urgente d'un duel.
--
-- TROIS CHOSES A SAVOIR AVANT DE TOUCHER A CE BLOC :
--
-- 1. LE SON NE COUTE AUCUN MESSAGE RESEAU. Le client recevait deja chaque
--    coup, chaque soin et chaque chute avec sa position, par le remote des
--    effets. Le son se greffe sur ces memes annonces : aucun nouveau remote,
--    aucun octet de plus. La seule chose ajoutee au message est `voice`, le
--    nom de la famille sonore de l'arme.
--
-- 2. CES IDENTIFIANTS SONT VERIFIES, PAS DEVINES. Chacun a ete charge dans
--    Studio par `ContentProvider:PreloadAsync` et sa duree relevee : un son
--    modere ou prive echoue en SILENCE, sans erreur, et le jeu devient muet
--    sans que personne sache pourquoi. Un test de demarrage refait cette
--    verification. Avant d'ajouter un identifiant ici, le charger.
--
-- 3. JE N'AI PAS PU LES ECOUTER. Je choisis sur le nom, sur la bibliotheque
--    d'origine et sur la DUREE — un « impact » d'une seconde et demie est une
--    portiere de voiture, pas un coup de poing. C'est une selection
--    raisonnee, pas un jugement d'oreille. Celui-la revient a Josh, et c'est
--    la section 12 de docs/A-TESTER.md.
Config.sounds = {
	enabled = true,

	-- Le volume d'ensemble. Tout passe par lui, donc baisser ce seul chiffre
	-- calme tout le jeu d'un coup.
	masterVolume = 0.5,

	-- La portee d'un son dans le monde. Au-dela de `maxDistanceStuds` on
	-- n'entend plus rien : c'est ce qui empeche d'entendre un duel a l'autre
	-- bout de l'arene, et donc ce qui fait que le son RENSEIGNE au lieu de
	-- saturer. La zone de depart fait environ 90 studs de rayon.
	minDistanceStuds = 12,
	maxDistanceStuds = 110,

	-- La famille sonore d'une arme sans arme. Les poings d'une classe qui n'a
	-- rien equipe font quand meme du bruit.
	defaultVoice = "fist",

	-- Ce que chaque famille joue : au depart du coup, et a l'impact.
	-- L'arme a feu tire au depart ; la masse cogne du metal a l'arrivee.
	voices = {
		blade = { swing = "swingBlade", hit = "hitBody" },
		blunt = { swing = "swingBlunt", hit = "hitMetal" },
		gun = { swing = "swingGun", hit = "hitBody" },
		bow = { swing = "swingBow", hit = "hitBody" },
		fist = { swing = "swingFist", hit = "hitBody" },
	},

	-- Chaque evenement porte UNE OU PLUSIEURS pistes, tirees au sort, et une
	-- plage de hauteur. Les deux servent la meme chose : eviter l'effet
	-- mitraillette. Un son identique repete trois fois par seconde cesse
	-- d'etre un coup et devient un bruit de machine.
	events = {
		swingBlade = { assets = { "7118966167" }, volume = 0.45, pitch = { 0.92, 1.12 } },
		swingBlunt = {
			assets = { "9120972444", "9120972321", "9120972323" },
			volume = 0.55,
			pitch = { 0.72, 0.88 },
		},
		swingGun = { assets = { "6506930532" }, volume = 0.4, pitch = { 0.95, 1.06 } },
		-- Deux secondes pour un geste qui dure 0,07 s : la piste contient la
		-- tension de la corde ET la detente. On ne garde que le depart.
		swingBow = {
			assets = { "9113160887" },
			volume = 0.45,
			pitch = { 0.95, 1.05 },
			maxSeconds = 0.7,
		},
		swingFist = {
			assets = { "9120972321", "9120972323" },
			volume = 0.32,
			pitch = { 1.05, 1.2 },
		},

		hitBody = {
			assets = { "111982142063703", "136209410462169" },
			volume = 0.6,
			pitch = { 0.9, 1.12 },
		},
		-- `maxSeconds` COUPE la piste. C'est le seul reglage sonore qui vient
		-- d'une mesure et pas d'une oreille : ces deux pistes durent 1,3 et
		-- 2,0 secondes, et la recharge du marteau est d'environ une seconde.
		-- Sans la coupe, chaque coup sonne encore quand le suivant part, et
		-- trois coups de marteau font un bourdon continu. Un impact dit
		-- « maintenant » ; il n'a pas besoin de durer.
		hitMetal = {
			assets = { "93864237211566", "133511054265823" },
			volume = 0.62,
			pitch = { 0.85, 1 },
			maxSeconds = 0.9,
		},

		down = { assets = { "9113480915" }, volume = 0.65, pitch = { 0.95, 1.05 } },
		blast = { assets = { "3444652484" }, volume = 0.75, pitch = { 0.9, 1.06 } },
	},

	-- L'impact arrive JUSTE APRES le depart du coup, pas en meme temps. Sans
	-- ce decalage les deux sons se superposent et on n'entend qu'une bouillie ;
	-- avec, l'oreille entend un geste puis sa consequence.
	hitDelaySeconds = 0.05,
}

Config.classStats = {
	-- Quatre statistiques valent zero pour tout le monde au depart : seules des
	-- branches d'arbre les font monter. Elles sont declarees partout quand
	-- meme, pour qu'un modificateur parte toujours d'un nombre et jamais d'un
	-- nil.
	--   spreadRatio        part des degats repercutee aux ennemis proches
	--   spreadRadiusStuds  rayon de cette repercussion
	--   knockbackDamage    degats portes par la poussee elle-meme
	--   damageTakenRatio   ajustement des degats recus, negatif = reduction
	--
	-- `ability` nomme le pouvoir de la classe. Il renvoie a Config.abilities,
	-- qui dit s'il est code ou seulement decrit. Les chiffres du pouvoir sont
	-- ici, et pas dans le registre, pour une raison precise : ce sont des
	-- statistiques comme les autres, donc une branche d'arbre peut les pousser
	-- et l'interface sait deja les afficher.
	--
	-- A REGLER : tout ce bloc. Ce sont des points de depart raisonnes, et la
	-- seule facon de les valider c'est de jouer.
	vampire = {
		maxHealth = 100,
		walkSpeed = 20,
		attackDamage = 12,
		attackCooldownSeconds = 0.6,
		attackRangeStuds = 7,
		-- Son pouvoir : il se soigne d'une part des degats infliges.
		lifestealRatio = 0.35,
		knockbackStuds = 0,
		knockbackUpStuds = 0,
		-- Sa faiblesse : il ne regenere rien hors combat.
		regenPerSecond = 0,
		spreadRatio = 0,
		spreadRadiusStuds = 0,
		knockbackDamage = 0,
		damageTakenRatio = 0,
		ability = "lifesteal",
	},
	colossus = {
		maxHealth = 170,
		-- Sa faiblesse : lent, donc cible facile des qu'il perd le contact.
		walkSpeed = 12,
		attackDamage = 24,
		attackCooldownSeconds = 1.3,
		attackRangeStuds = 9,
		lifestealRatio = 0,
		-- Son pouvoir : il pousse les adversaires.
		knockbackStuds = 45,
		knockbackUpStuds = 15,
		regenPerSecond = 2,
		spreadRatio = 0,
		spreadRadiusStuds = 0,
		knockbackDamage = 0,
		damageTakenRatio = 0,
		ability = "knockback",
	},

	-- Les douze suivantes ont toutes un pouvoir qui ne tient pas dans une
	-- statistique. Elles portent donc `ability`, et les chiffres de ce pouvoir
	-- avec elles.

	tracker = {
		maxHealth = 95,
		walkSpeed = 21,
		-- Sa faiblesse : il frappe faible. Il trouve, il ne tue pas.
		attackDamage = 8,
		attackCooldownSeconds = 0.55,
		attackRangeStuds = 8,
		lifestealRatio = 0,
		knockbackStuds = 0,
		knockbackUpStuds = 0,
		regenPerSecond = 1.5,
		spreadRatio = 0,
		spreadRadiusStuds = 0,
		knockbackDamage = 0,
		damageTakenRatio = 0,
		ability = "footprints",
		-- Jusqu'ou il lit les traces, et jusqu'a quel age. Le rayon est large
		-- expres : une information qui n'arrive qu'au contact arrive trop tard.
		trackRadiusStuds = 90,
		trackAgeSeconds = 6,
	},

	artificer = {
		maxHealth = 95,
		walkSpeed = 17,
		-- Sa faiblesse : nul en combat direct. Son terrain, c'est avant.
		attackDamage = 7,
		attackCooldownSeconds = 0.8,
		attackRangeStuds = 6,
		lifestealRatio = 0,
		knockbackStuds = 0,
		knockbackUpStuds = 0,
		regenPerSecond = 2,
		spreadRatio = 0,
		spreadRadiusStuds = 0,
		knockbackDamage = 0,
		damageTakenRatio = 0,
		ability = "mines",
		abilityCooldownSeconds = 3,
		-- Sa faiblesse, l'autre moitie : le stock est limite et ne se recharge
		-- qu'entre deux manches.
		mineCount = 3,
		mineDamage = 26,
		mineRadiusStuds = 9,
	},

	spectre = {
		maxHealth = 90,
		walkSpeed = 19,
		attackDamage = 14,
		attackCooldownSeconds = 0.7,
		attackRangeStuds = 7,
		lifestealRatio = 0,
		knockbackStuds = 0,
		knockbackUpStuds = 0,
		regenPerSecond = 2,
		spreadRatio = 0,
		spreadRadiusStuds = 0,
		knockbackDamage = 0,
		damageTakenRatio = 0,
		ability = "phase",
		abilityCooldownSeconds = 14,
		-- Court expres : traverser un mur doit servir a arriver quelque part,
		-- pas a attendre la fin d'un echange a l'abri.
		phaseSeconds = 3,
	},

	link = {
		maxHealth = 130,
		walkSpeed = 16,
		attackDamage = 11,
		attackCooldownSeconds = 0.8,
		attackRangeStuds = 7,
		lifestealRatio = 0,
		knockbackStuds = 0,
		knockbackUpStuds = 0,
		regenPerSecond = 3,
		spreadRatio = 0,
		spreadRadiusStuds = 0,
		knockbackDamage = 0,
		damageTakenRatio = 0,
		ability = "bond",
		abilityCooldownSeconds = 6,
		-- Sa faiblesse : la moitie des degats de l'allie lui reviennent. C'est
		-- le prix du partage, et c'est ce qui l'empeche de lier n'importe qui.
		bondShareRatio = 0.5,
		bondRangeStuds = 60,
	},

	duelist = {
		maxHealth = 105,
		walkSpeed = 19,
		attackDamage = 13,
		attackCooldownSeconds = 0.65,
		attackRangeStuds = 7,
		lifestealRatio = 0,
		knockbackStuds = 0,
		knockbackUpStuds = 0,
		regenPerSecond = 2,
		spreadRatio = 0,
		spreadRadiusStuds = 0,
		knockbackDamage = 0,
		damageTakenRatio = 0,
		ability = "isolation",
		-- Son pouvoir et sa faiblesse sont le meme chiffre vu des deux cotes :
		-- seul contre un, il frappe plus fort ; des qu'un deuxieme ennemi est
		-- la, il frappe plus faible.
		duelBonusRatio = 0.35,
		duelPenaltyRatio = -0.25,
		duelRadiusStuds = 22,
	},

	smith = {
		maxHealth = 140,
		-- Sa faiblesse : lent a batir, et lent tout court.
		walkSpeed = 14,
		attackDamage = 15,
		attackCooldownSeconds = 1,
		attackRangeStuds = 8,
		lifestealRatio = 0,
		knockbackStuds = 0,
		knockbackUpStuds = 0,
		regenPerSecond = 2,
		spreadRatio = 0,
		spreadRadiusStuds = 0,
		knockbackDamage = 0,
		damageTakenRatio = 0,
		ability = "wall",
		abilityCooldownSeconds = 10,
		-- Le mur bloque tout le monde, son equipe comprise : c'est la faiblesse
		-- annoncee, et elle n'est pas decorative.
		wallSeconds = 12,
		wallWidthStuds = 14,
		wallHeightStuds = 9,
	},

	pyromaniac = {
		maxHealth = 100,
		walkSpeed = 18,
		attackDamage = 10,
		attackCooldownSeconds = 0.7,
		attackRangeStuds = 7,
		lifestealRatio = 0,
		knockbackStuds = 0,
		knockbackUpStuds = 0,
		regenPerSecond = 2,
		spreadRatio = 0,
		spreadRadiusStuds = 0,
		knockbackDamage = 0,
		damageTakenRatio = 0,
		ability = "fire",
		abilityCooldownSeconds = 9,
		-- Sa faiblesse : ses flammes ne font pas la difference entre lui et les
		-- autres. Poser du feu sous ses pieds, c'est bruler avec.
		fireDamagePerSecond = 9,
		fireSeconds = 7,
		fireRadiusStuds = 11,
	},

	decoy = {
		maxHealth = 95,
		walkSpeed = 19,
		attackDamage = 11,
		attackCooldownSeconds = 0.7,
		attackRangeStuds = 7,
		lifestealRatio = 0,
		knockbackStuds = 0,
		knockbackUpStuds = 0,
		regenPerSecond = 2,
		spreadRatio = 0,
		spreadRadiusStuds = 0,
		knockbackDamage = 0,
		damageTakenRatio = 0,
		ability = "clone",
		abilityCooldownSeconds = 16,
		-- Sa faiblesse : pendant que le clone vit, lui ne bouge plus et encaisse
		-- plus. Le leurre coute cher a celui qui le pose.
		cloneSeconds = 6,
		cloneExposureRatio = 0.35,
	},

	seismic = {
		maxHealth = 125,
		walkSpeed = 15,
		attackDamage = 16,
		attackCooldownSeconds = 0.95,
		attackRangeStuds = 8,
		lifestealRatio = 0,
		knockbackStuds = 0,
		knockbackUpStuds = 0,
		regenPerSecond = 2,
		spreadRatio = 0,
		spreadRadiusStuds = 0,
		knockbackDamage = 0,
		damageTakenRatio = 0,
		ability = "slam",
		abilityCooldownSeconds = 11,
		-- Sa faiblesse : rien de tout ca n'atteint quelqu'un qui ne touche pas
		-- le sol. Sauter au bon moment annule la frappe entiere.
		slamRadiusStuds = 34,
		slamSlowRatio = -0.4,
		slamSeconds = 4,
	},

	parasite = {
		maxHealth = 100,
		walkSpeed = 20,
		attackDamage = 11,
		attackCooldownSeconds = 0.65,
		attackRangeStuds = 7,
		lifestealRatio = 0,
		knockbackStuds = 0,
		knockbackUpStuds = 0,
		-- Sa faiblesse, en partie : il vit sur les autres, pas sur lui-meme.
		regenPerSecond = 1,
		spreadRatio = 0,
		spreadRadiusStuds = 0,
		knockbackDamage = 0,
		damageTakenRatio = 0,
		ability = "mark",
		abilityCooldownSeconds = 12,
		-- L'autre moitie de sa faiblesse : la marque se voit, et celui qui la
		-- porte le sait. Il sait donc aussi qu'il est suivi.
		markSeconds = 20,
		markHealStealRatio = 0.5,
		markRangeStuds = 40,
	},

	chameleon = {
		maxHealth = 90,
		walkSpeed = 20,
		-- Son coup est le plus fort du jeu hors Colosse : il n'en place qu'un.
		attackDamage = 18,
		attackCooldownSeconds = 0.9,
		attackRangeStuds = 7,
		lifestealRatio = 0,
		knockbackStuds = 0,
		knockbackUpStuds = 0,
		regenPerSecond = 2,
		spreadRatio = 0,
		spreadRadiusStuds = 0,
		knockbackDamage = 0,
		damageTakenRatio = 0,
		ability = "cloak",
		-- Sa faiblesse : le moindre deplacement le revele. Le delai est ce qui
		-- l'empeche de clignoter en se repositionnant d'un pas.
		cloakDelaySeconds = 1.2,
		cloakSpeedThreshold = 2,
	},

	medic = {
		maxHealth = 110,
		walkSpeed = 18,
		-- Sa faiblesse en combat : il frappe peu. Sa valeur est ailleurs.
		attackDamage = 9,
		attackCooldownSeconds = 0.7,
		attackRangeStuds = 7,
		lifestealRatio = 0,
		knockbackStuds = 0,
		knockbackUpStuds = 0,
		regenPerSecond = 3,
		spreadRatio = 0,
		spreadRadiusStuds = 0,
		knockbackDamage = 0,
		damageTakenRatio = 0,
		ability = "mend",
		-- Il releve deux fois plus vite que n'importe qui, et rend plus de PV.
		-- Le relevement reste long, visible et interruptible : la faiblesse est
		-- dans le fait de devoir rester la, pas dans la duree.
		reviveSpeedRatio = 2,
		reviveHealthBonusRatio = 0.25,
	},
}

--------------------------------------------------------------------------------
-- LE CONTRAT DE NOMMAGE AVEC LES MAPS
--------------------------------------------------------------------------------

-- Le code verifie ces noms au demarrage et affiche une erreur explicite s'il en
-- manque un, pour que la personne qui construit la map sache seule si elle est
-- conforme. Rojo possede ServerScriptService et ReplicatedStorage, Team Create
-- possede Workspace : ces noms sont la seule frontiere entre les deux.
--------------------------------------------------------------------------------
-- LES POUVOIRS DE CLASSE
--------------------------------------------------------------------------------
--
-- POURQUOI CE REGISTRE EXISTE. Le 25 octobre 2026, trois branches d'arbre sur
-- six poussaient un chiffre que le combat ne lisait pas : elles ne faisaient
-- rien, pendant que leur sacrifice s'appliquait. Tous les tests passaient. Un
-- pouvoir de classe peut tomber dans le meme trou, en pire, parce qu'une classe
-- entiere devient creuse.
--
-- La parade est la meme que pour les paliers 6 : un pouvoir est DECLARE ici, et
-- `implemented` dit s'il est reellement code. Rien ne l'interroge directement ;
-- tout passe par AbilityService, qui refuse ce qui n'est pas code au lieu de ne
-- rien faire en silence. Le serveur verifie au demarrage que chaque pouvoir
-- marque `implemented` a bien un gestionnaire, et s'arrete net sinon.
--
-- `kind` dit comment le pouvoir se declenche :
--   "stats"   entierement porte par les statistiques de la classe, rien a
--             executer (le vol de vie du Vampire, la poussee du Colosse)
--   "passive" le serveur l'applique tout seul, sans que le joueur agisse
--   "active"  le joueur appuie sur la touche, et il y a une recharge
--
-- Les chiffres reglables d'un pouvoir ne sont PAS ici : ils sont dans
-- Config.classStats, avec la classe. Ce qui reste ici, c'est ce qui ne se regle
-- pas par classe.
Config.abilities = {
	-- Une seule touche pour tous les pouvoirs actifs. Une touche par classe
	-- serait a reapprendre a chaque tirage, et la classe est tiree au sort.
	inputKey = "E",

	registry = {
		lifesteal = {
			name = "Vol de vie",
			kind = "stats",
			implemented = true,
			summary = "Se soigne d'une part des dégâts infligés",
		},
		knockback = {
			name = "Poussée",
			kind = "stats",
			implemented = true,
			summary = "Repousse les adversaires touchés",
		},
		footprints = {
			name = "Traces",
			kind = "passive",
			implemented = true,
			summary = "Voit les traces de pas récentes des adversaires",
		},
		mines = {
			name = "Mines",
			kind = "active",
			implemented = true,
			summary = "Pose une mine au sol, stock limité",
		},
		phase = {
			name = "Passe-muraille",
			kind = "active",
			implemented = true,
			summary = "Traverse les murs quelques secondes, sans pouvoir frapper",
		},
		bond = {
			name = "Lien",
			kind = "active",
			implemented = true,
			summary = "Partage ses PV avec l'allié le plus proche",
		},
		isolation = {
			name = "Isolement",
			kind = "passive",
			implemented = true,
			summary = "Frappe plus fort seul contre un, plus faible à plusieurs",
		},
		wall = {
			name = "Mur",
			kind = "active",
			implemented = true,
			summary = "Dresse un mur temporaire qui gêne aussi son équipe",
		},
		fire = {
			name = "Brasier",
			kind = "active",
			implemented = true,
			summary = "Laisse une zone de feu qui le brûle aussi",
		},
		clone = {
			name = "Leurre",
			kind = "active",
			implemented = true,
			summary = "Pose un clone qui attire les coups, et s'immobilise",
		},
		slam = {
			name = "Onde de choc",
			kind = "active",
			implemented = true,
			summary = "Révèle et ralentit les ennemis au sol",
		},
		mark = {
			name = "Marque",
			kind = "active",
			implemented = true,
			summary = "Marque un ennemi, le voit à travers les murs, vole ses soins",
		},
		cloak = {
			name = "Camouflage",
			kind = "passive",
			implemented = true,
			summary = "Invisible tant qu'il ne bouge pas",
		},
		mend = {
			name = "Soins",
			kind = "passive",
			implemented = true,
			summary = "Relève un allié bien plus vite, et en meilleur état",
		},
	},

	-- Les reglages qui ne sont pas des statistiques de classe : ils valent pour
	-- le pouvoir en lui-meme, quelle que soit la classe qui le porte.
	tuning = {
		-- TRACES. Une trace est posee a intervalle fixe sous chaque adversaire
		-- debout, et seul le Traqueur les recoit. L'intervalle est ce qui decide
		-- si une piste se lit comme un chemin ou comme un nuage de points.
		footprintIntervalSeconds = 0.45,
		footprintMinMoveStuds = 2,

		-- MINES. Elles s'arment apres un delai : poser une mine sous les pieds
		-- d'un ennemi deja la serait une attaque instantanee, pas un piege.
		mineArmSeconds = 1.2,
		mineLifeSeconds = 60,
		mineTriggerRadiusStuds = 7,
		mineKnockbackStuds = 40,
		mineKnockbackUpStuds = 25,

		-- PASSE-MURAILLE. Pendant la traversee il ne peut ni frapper ni etre
		-- soigne : c'est la faiblesse annoncee, et elle est appliquee ici.
		phaseTransparency = 0.6,

		-- LIEN. Les degats partages sont plafonnes pour que lier quelqu'un ne
		-- revienne jamais a mourir a sa place en une seule fois.
		bondMaxShareFraction = 0.35,

		-- MUR et BRASIER vivent dans le meme dossier temporaire que les blocs de
		-- la Catapulte, et disparaissent avec la manche.
		wallThicknessStuds = 1.6,
		fireTickSeconds = 0.5,

		-- LEURRE. Le clone encaisse les coups comme une cible : il a des PV, et
		-- les adversaires le preferent a son porteur tant qu'il est plus proche.
		cloneHealth = 60,

		-- MARQUE. Le marque est prevenu, et sa marque se voit de loin.
		markColor = { 190, 90, 220 },
		revealColor = { 255, 170, 70 },
	},
}

Config.mapContract = {
	spawnsFolderTeamA = "SpawnsA",
	spawnsFolderTeamB = "SpawnsB",
	spawnPointsPerTeam = 5,
	zoneCenterPart = "ZoneCenter",
	coverFolder = "Cover",
	boundsPart = "MapBounds",
}

return Config
