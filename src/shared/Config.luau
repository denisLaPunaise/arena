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
	maxArmor = 1,
	allowDuplicateItems = false,

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
}

--------------------------------------------------------------------------------
-- LE CATALOGUE D'OBJETS
--------------------------------------------------------------------------------

-- Cible a terme et contenu du prototype. Douze objets suffisent a tester si le
-- systeme de budget est bon : s'il n'est pas amusant a douze, il ne le sera pas
-- davantage a soixante-deux.
Config.itemCounts = {
	target = { primary = 24, secondary = 10, armor = 8, heal = 6, utility = 14 },
	prototype = { primary = 4, secondary = 2, armor = 2, heal = 1, utility = 3 },
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
	starterDraws = 3,
	starterDrawsMaxItemCost = 3,
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
Config.classStats = {
	-- Trois statistiques valent zero pour tout le monde au depart : seules des
	-- branches d'arbre les font monter. Elles sont declarees ici quand meme,
	-- pour qu'un modificateur parte toujours d'un nombre et jamais d'un nil.
	--   spreadRatio        part des degats repercutee aux ennemis proches
	--   spreadRadiusStuds  rayon de cette repercussion
	--   knockbackDamage    degats portes par la poussee elle-meme
	--   damageTakenRatio   ajustement des degats recus, negatif = reduction
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
	},
}

--------------------------------------------------------------------------------
-- LE CONTRAT DE NOMMAGE AVEC LES MAPS
--------------------------------------------------------------------------------

-- Le code verifie ces noms au demarrage et affiche une erreur explicite s'il en
-- manque un, pour que la personne qui construit la map sache seule si elle est
-- conforme. Rojo possede ServerScriptService et ReplicatedStorage, Team Create
-- possede Workspace : ces noms sont la seule frontiere entre les deux.
Config.mapContract = {
	spawnsFolderTeamA = "SpawnsA",
	spawnsFolderTeamB = "SpawnsB",
	spawnPointsPerTeam = 5,
	zoneCenterPart = "ZoneCenter",
	coverFolder = "Cover",
	boundsPart = "MapBounds",
}

return Config
