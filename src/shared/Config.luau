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
Config.version = 1

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
	-- l'arbre a six paliers : une serie serree permet d'aller au bout, une
	-- victoire nette s'arrete au palier 4.
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
}

--------------------------------------------------------------------------------
-- LA FENETRE D'AGONIE
--------------------------------------------------------------------------------

-- Vaut pour toutes les classes, pas seulement en presence d'un Infirmier.
-- Consequence : tant qu'un joueur est en agonie, son equipe n'est pas encore
-- eliminee et la manche continue.
Config.downed = {
	windowSeconds = 10,
	-- Un joueur a terre rampe a environ un quart de sa vitesse normale.
	crawlSpeedRatio = 0.25,
	-- Le relevement doit laisser le temps d'arriver sans etre gratuit.
	reviveSeconds = 4,
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
	tiers = 6,
	branchesPerClass = 3,

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
	-- A quelques dizaines de joueurs un classement bouge tres lentement : on
	-- monte le coefficient au lancement, on le baisse quand la population
	-- grandit.
	kFactorLaunch = 64,
	kFactorMature = 24,
	kFactorSwitchAtPlayerCount = 500,
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
