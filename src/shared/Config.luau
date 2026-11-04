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

--- Comment on compose une partie avec les joueurs presents. Le calcul lui-meme
--- est dans Seating, qui est pur et teste hors de Studio.
Config.seating = {
	-- Les deux camps. Ce ne sont pas des chiffres d'equilibrage mais des noms de
	-- structure : MapService les traduit en SpawnsA et SpawnsB, et les
	-- identifiants de Config.formats ("2v2") comptent deja deux camps. Un
	-- troisieme camp demanderait une map a trois entrees et un format a trois
	-- nombres : ce n'est pas une valeur a changer, c'est un chantier. Un test
	-- verifie que les deux listes restent d'accord.
	teams = { "A", "B" },

	-- Le rythme de l'annonce d'attente, quand il manque du monde. Une seconde
	-- suffit a ce que le compteur ait l'air vivant, et ne coute qu'un texte.
	waitRefreshSeconds = 1,

	-- LE SALON, EN PARTIE PRIVEE SEULEMENT. Des amis qui jouent ensemble
	-- reglent deux choses avant de lancer : le format, et la facon de composer
	-- les camps. RIEN D'AUTRE. Les regles du jeu — la zone, l'agonie, l'arbre,
	-- les bans — ne sont pas reglables en jeu, et c'est une decision de Josh du
	-- 27 octobre 2026, dite dans ces mots : « le jeu reste le jeu, on doit pas
	-- pouvoir le modifier ». Les interrupteurs de comparaison restent donc dans
	-- Config, cote developpeur.
	--
	-- Jamais en public, et ce n'est pas de la prudence : deux amis qui
	-- choisissent le meme camp sur un serveur classe empilent un cote, et le
	-- classement de tous les autres paie l'addition. Le serveur refuse donc la
	-- demande au lieu de compter sur le client pour ne pas l'envoyer.
	lobbyInPrivate = true,

	-- La touche qui ouvre le salon. 1 a 4 servent deja aux objets
	-- (Config.loadout.useKeys) : une touche qui fait deux choses selon le
	-- moment est le genre de detail qui coute une manche. Libres au 27 octobre
	-- 2026 : tout sauf 1-4, E, T, L, P, B et le clic. Un test refuse une
	-- collision.
	lobbyKey = "C",

	-- Les reglages de depart, et ceux auxquels on revient en public. « auto »
	-- veut dire « le plus grand format que l'effectif remplit », et c'est le
	-- comportement qu'avait la boucle avant le salon.
	defaultFormat = "auto",
	-- « chosen » : chacun demande son camp, et le voeu est tenu si la place
	-- existe. « random » : tirage au sort, refait a chaque partie.
	defaultTeamMode = "chosen",

	-- « drawn » : les classes sont tirees au sort, ce que le jeu a toujours
	-- fait. « picked » : chacun choisit la sienne a son tour, et une classe
	-- prise ne revient pas.
	--
	-- LE TIRAGE RESTE LE DEFAUT, et ce n'est pas de la timidite : c'est lui
	-- qui tient le troisieme principe du jeu, en forcant a jouer ce qui tombe
	-- plutot que ce qu'on maitrise. Le choix est une facon de jouer entre
	-- amis, demandee par Josh le 2 novembre 2026, et comme tout le reste du
	-- salon il n'existe qu'en partie privee -- donc hors classement.
	defaultClassMode = "drawn",

	-- Combien de temps un changement de reglage reste affiche. L'annonce du
	-- salon est ECRASEE par le rafraichissement, qui part toutes les secondes :
	-- sans ce delai, « Josh a choisi 2v2 » clignote moins d'une seconde et
	-- personne ne le lit. Meme parade que l'annonce du bac a sable.
	noticeSeconds = 3,
}

--------------------------------------------------------------------------------
-- LE MENU D'ACCUEIL
--------------------------------------------------------------------------------

Config.menu = {
	-- A false, le jeu retrouve son comportement d'avant le menu : on tombe
	-- dans un serveur et la partie part toute seule des qu'il y a du monde.
	-- C'est l'interrupteur de comparaison, comme pour la zone et l'arbre.
	enabled = true,

	-- CE QUI CHANGE VRAIMENT, et qui vaut plus que l'ecran lui-meme : avant le
	-- menu, TOUTE personne presente etait assise d'office. Quelqu'un qui
	-- arrivait pour regarder, ou qui lisait son arbre, se retrouvait en
	-- partie. Maintenant on entre en appuyant sur « Jouer », et on en sort.
	readyRequired = true,

	-- Cinq signes font vingt-huit millions de combinaisons avec l'alphabet de
	-- Lobbies, qui n'a ni zero ni un. C'est beaucoup pour un code qui ne vit
	-- que quelques heures, et c'est court assez pour se dicter.
	codeLength = 5,

	-- Au-dela, le serveur reserve de Roblox a de bonnes chances de s'etre
	-- eteint faute de monde : le code menerait alors a un serveur neuf et
	-- vide, ce qui se lit comme un bug plutot que comme une expiration.
	codeHours = 12,

	-- Le magasin ou vivent les correspondances code court -> code de Roblox.
	-- Separe des profils : ce sont des donnees jetables, et on ne veut pas
	-- qu'une purge de codes approche des pieces de qui que ce soit.
	dataStoreName = "ArenaLobbies",

	-- La touche qui rouvre le menu. Un test refuse qu'elle en double une
	-- autre ; libres au 2 novembre 2026 : tout sauf 1-4, E, T, L, P, B, C.
	reopenKey = "M",
}

--------------------------------------------------------------------------------
-- LA MANETTE
--------------------------------------------------------------------------------

-- Demande par Josh le 4 novembre 2026 : il ne joue qu'a la manette. Chaque
-- action du clavier a son bouton, et un test refuse que deux actions prennent
-- le meme. Les noms sont ceux de `Enum.KeyCode` ; un nom faux donne un bouton
-- mort SANS ERREUR, d'ou la liste des noms connus dans le test.
--
-- LES BOUTONS QUE ROBLOX GARDE, et qui ne figurent donc nulle part ici :
--   A        sauter (et valider dans un panneau)
--   R3       le zoom de la camera a la manette
--   Select   entrer et sortir de la navigation dans l'interface
--   Start    le menu de Roblox
-- Le stick gauche deplace, le stick droit tourne la camera : rien a faire.
Config.gamepad = {
	-- Les gachettes pour les deux gestes de combat : on les presse sans
	-- lacher les sticks, donc sans cesser de bouger ni de viser.
	attack = "ButtonR2",
	ability = "ButtonL2",

	-- La croix pour les quatre objets, dans l'ordre des aiguilles d'une
	-- montre a partir du haut : objet 1 en haut, 2 a droite, 3 en bas, 4 a
	-- gauche. Dans un panneau, la croix navigue : aucun objet ne part alors.
	useButtons = { "DPadUp", "DPadRight", "DPadDown", "DPadLeft" },

	-- Les deux ecrans qu'on ouvre en partie, sur les deux boutons du pouce.
	tree = "ButtonY",
	loadout = "ButtonX",

	-- Les ecrans hors combat, sur les boutons de tranche.
	progress = "ButtonR1",
	menu = "ButtonL1",

	-- LE SALON ET LE BAC A SABLE PARTAGENT L3, parce qu'ils ne coexistent
	-- jamais vraiment : le bac a sable n'existe que seul, le salon que dans une
	-- partie privee a plusieurs. Plus un seul bouton libre sinon (R3 est a la
	-- camera). Quand le bac a sable tourne, L3 l'ouvre ; sinon, le salon.
	sandboxOrLobby = "ButtonL3",

	-- Ferme le panneau du dessus. A la manette, B est aussi le « retour » de
	-- Roblox dans une interface : les deux disent la meme chose.
	close = "ButtonB",

	-- Ce qu'on AFFICHE pour chaque bouton, dans le bandeau et les panneaux.
	-- Noms de la manette Xbox, que Roblox emploie aussi sur PlayStation.
	labels = {
		ButtonR2 = "RT",
		ButtonL2 = "LT",
		ButtonR1 = "RB",
		ButtonL1 = "LB",
		ButtonY = "Y",
		ButtonX = "X",
		ButtonB = "B",
		ButtonA = "A",
		ButtonL3 = "L3",
		DPadUp = "Croix haut",
		DPadRight = "Croix droite",
		DPadDown = "Croix bas",
		DPadLeft = "Croix gauche",
	},
}

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

	-- Le clignotement du mur quand la zone se resserre. Etait en dur dans
	-- `ZoneService` ; c'est un chiffre de lisibilite, donc il se regle.
	zoneFlashSeconds = 0.35,
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

	-- Le temps laisse a chacun pour choisir sa classe, quand le salon est en
	-- « picked ». Plus long que le vote de ban : on bannit CONTRE, ce qui se
	-- decide vite, alors qu'on choisit POUR parmi tout ce qui reste. Qui
	-- laisse passer sa fenetre est tire au sort, donc ce chiffre ne peut pas
	-- figer une partie, seulement la rendre penible s'il est trop court.
	pickSeconds = 25,

	-- Un relancement par joueur et par partie, aveugle : on accepte avant de
	-- voir. Sinon le reroll devient un choix deguise.
	rerollsPerPlayer = 1,
	rerollIsBlind = true,

	-- L'echange de classe entre coequipiers est abandonne : il ne servait qu'a
	-- compenser l'absence de marge en 5v5.
	allowTeammateSwap = false,

	-- Le temps laisse pour accepter ou refuser le relancement. Court expres :
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

	-- La touche qui ouvre l'arbre. Etait un `Enum.KeyCode.T` en dur dans
	-- `TreePanel`, hors du test des collisions de touches.
	panelKey = "T",

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
					-- Les armures sont arrivees avec l'equipement, donc cet
					-- effet a enfin quelque chose a ignorer : code le
					-- 27 octobre 2026.
					implemented = true,
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
					label = "Immobile deux secondes : immunité aux explosions",
					effect = "blastImmunity",
					implemented = true,
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
	-- communes a toutes les classes. Un point chacune, cumulables.
	-- A REGLER : les gains exacts de ces ameliorations.
	--
	-- Declare depuis la fiche et JAMAIS APPLIQUE jusqu'au 4 novembre 2026 : le
	-- septieme point d'une partie longue (et le point de revanche) tombait dans
	-- le vide une fois la branche finie. `stat` nomme la statistique poussee,
	-- et un test verifie qu'elle existe chez chaque classe — meme garde-fou que
	-- les branches creuses. Les gains passent par `Modifiers.applyDeltas`, donc
	-- par les memes planchers que tout le reste.
	sparePointUpgrades = {
		{ id = "health", label = "PV", stat = "maxHealth", amount = 10, cost = 1 },
		{ id = "speed", label = "Vitesse", stat = "walkSpeed", amount = 1, cost = 1 },
		{
			id = "cooldown",
			label = "s de recharge",
			stat = "abilityCooldownSeconds",
			amount = -0.5,
			cost = 1,
		},
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

	-- LES LANCERS ET LES EXPLOSIONS D'OBJETS. Ces trois chiffres etaient en dur
	-- dans `LoadoutService` jusqu'au 4 novembre 2026 ; valeurs inchangees.
	-- 22 studs/s vers le haut donnent la cloche d'un lancer a bout de bras ;
	-- la poussee d'une grenade est un peu moins forte que celle d'une mine,
	-- parce qu'elle se lance de loin et qu'on ne la voit pas venir.
	throwLiftStuds = 22,
	grenadeKnockbackStuds = 30,
	grenadeKnockbackUpStuds = 20,
	-- Un lancer vise ne choisit que les cibles devant soi : 0,35 de produit
	-- scalaire, soit environ 70 degres de part et d'autre du regard.
	throwTargetConeDot = 0.35,

	-- Une demi-seconde entre deux utilisations, toutes charges confondues. Sans
	-- ca, deux grenades partent dans la meme seconde et la zone devient un
	-- feu d'artifice.
	useCooldownSeconds = 0.6,

	-- L'objet reste au moins ce temps-la dans la main gauche. C'est un
	-- plancher, pas une duree : une pose de trousse qui dure 1,6 seconde le
	-- garde 1,6 seconde. Il existe parce qu'un soin instantane sortirait et
	-- rentrerait dans la meme image, donc ne se verrait jamais — et un objet
	-- qu'on ne voit pas est exactement ce que ce travail corrige.
	offhandSeconds = 0.55,

	-- UN SQUELETTE D'AVATAR, POUR L'EXAMEN SEULEMENT. Taille de chaque membre
	-- et place de son centre par rapport au torse, en studs. En jeu rien de
	-- tout ca n'est lu : l'armure se mesure sur le corps REEL du joueur, dont
	-- la taille lui appartient. Ces chiffres ne servent qu'a poser une armure
	-- dans le vide pour la regarder.
	--
	-- Ils sont MESURES, pas recopies d'une documentation : releves le
	-- 28 octobre 2026 sur un R15 propre, fabrique par
	-- `CreateHumanoidModelFromDescription` avec une description vide.
	--
	-- POURQUOI UN RIG NEUF ET PAS L'AVATAR DU JOUEUR. La premiere mesure a ete
	-- prise sur l'avatar de Josh, qui est un PIGEON : torse de 1,27 de large
	-- et bras de 0,40. L'armure dessinee la-dessus avait des facteurs calcules
	-- pour des bras minces, et sur un corps normal ses epaulieres faisaient
	-- deux studs de large. Les proportions de reference se prennent donc sur
	-- un corps standard — mais les tailles restent des FRACTIONS, parce que
	-- l'avatar du joueur, lui, peut etre n'importe quoi.
	previewRig = {
		{ limb = "UpperTorso", size = { 1.94, 1.7, 1 }, at = { 0, 0, 0 } },
		{ limb = "LowerTorso", size = { 1.99, 0.4, 1 }, at = { 0, -1, 0 } },
		{ limb = "RightUpperArm", size = { 1, 1.24, 1 }, at = { 1.5, 0.17, 0 } },
		{ limb = "LeftUpperArm", size = { 1, 1.24, 1 }, at = { -1.5, 0.17, 0 } },
		{ limb = "RightUpperLeg", size = { 0.99, 1.36, 0.97 }, at = { 0.5, -1.62, 0 } },
		{ limb = "LeftUpperLeg", size = { 0.99, 1.36, 0.97 }, at = { -0.5, -1.62, 0 } },
		-- Les mollets et les pieds sont arrives avec les bottes a ressort, qui
		-- ne se tiennent pas dans une main. Mesures le 29 octobre 2026 sur le
		-- meme corps standard que les autres, et ramenees au repere du
		-- `UpperTorso` comme eux : le `HumanoidRootPart` est vingt centiemes
		-- plus bas, d'ou le decalage si on refait la mesure.
		{ limb = "RightLowerLeg", size = { 0.99, 1.3, 0.97 }, at = { 0.5, -2.4, 0 } },
		{ limb = "LeftLowerLeg", size = { 0.99, 1.3, 0.97 }, at = { -0.5, -2.4, 0 } },
		{ limb = "RightFoot", size = { 1.01, 0.31, 1 }, at = { 0.5, -3.05, 0 } },
		{ limb = "LeftFoot", size = { 1.01, 0.31, 1 }, at = { -0.5, -3.05, 0 } },
		{ limb = "Head", size = { 1.16, 1.18, 1.16 }, at = { 0, 1.39, 0 } },
	},

	-- Les charges reviennent entre deux manches, comme les mines de
	-- l'Artificier. Une manche est l'unite de reserve du jeu.
	chargesRefillBetweenRounds = true,

	-- La hauteur d'un saut ordinaire dans Roblox, avec la gravite et le
	-- `JumpHeight` par defaut. Ce n'est pas un reglage, c'est une CONSTANTE DE
	-- COMPARAISON : un objet de deplacement qui monte moins haut que la barre
	-- d'espace ne vaut pas un point, et un test refuse desormais qu'un bond
	-- passe sous cette ligne. Elle est ici et pas dans le test pour que les
	-- deux ne puissent pas diverger.
	ordinaryJumpStuds = 7.2,

	-- La gravite de Roblox, telle qu'elle vaut dans une place neuve. Le serveur
	-- lit la vraie valeur de `Workspace.Gravity` quand il convertit un bond ;
	-- celle-ci n'existe que pour que les tests puissent refaire le calcul sans
	-- Roblox.
	referenceGravity = 196.2,

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

	-- LE BRAS. Le geste de l'arme dit COMMENT elle bouge ; celui-ci dit OU va
	-- la main. Les deux sont separes expres : l'arme tourne sur elle-meme dans
	-- la main, le bras ne fait que porter la main ailleurs. Melanger les deux
	-- ferait tourner l'arme deux fois.
	--
	-- CHAQUE POSE EST UN DEPLACEMENT DE LA MAIN, EN STUDS, dans le repere du
	-- torse : `right` vers la droite du personnage, `up` vers le haut,
	-- `forward` vers l'avant. Les noms sont des mots et pas des axes, parce
	-- que l'avant de Roblox est -Z et que c'est la source d'erreur numero un.
	--
	-- CE QUE LE BRAS PEUT REELLEMENT FAIRE, mesure en jeu le 27 octobre 2026
	-- sur un avatar R15 : une demande de 2 studs vers le haut deplace la main
	-- de 1,85, vers l'avant de 1,25, mais VERS L'INTERIEUR DU CORPS de 0,36
	-- seulement. L'epaule a une butee, et aucun chiffre ecrit ici ne la fera
	-- ceder. Un grand moulinet qui traverse le corps est donc impossible, et
	-- c'est pour ca que la machette avance surtout au lieu de faucher.
	--
	-- LE TORSE SE PENCHE ET LA TETE SUIT. Trois angles en DEGRES, et ils sont
	-- NOMMES PAR LEUR EFFET et jamais par leur axe :
	--
	--   lean      positif, le buste tombe vers l'AVANT, dans le coup
	--   headDip   positif, la tete regarde vers le BAS
	--   headTurn  positif, la tete tourne vers la GAUCHE du personnage
	--
	-- CE NOMMAGE EST UNE CICATRICE. Le penchement du buste a ete ecrit a
	-- l'envers le 27 octobre 2026 et livre comme ca : « tangage positif » avait
	-- ete lu comme « penche en avant » alors que dans Roblox un tangage positif
	-- LEVE l'avant, donc le buste partait en arriere pendant que la main allait
	-- devant. Un test existait et ne l'a pas vu, parce qu'il comparait deux de
	-- mes conventions entre elles au lieu de mesurer ou pointe la poitrine. La
	-- conversion vers les axes de Roblox se fait donc a UN SEUL endroit, dans
	-- `WeaponService`, et le test refait le calcul de Roblox avant de juger.
	--
	-- LA BUTEE DU BASSIN EST A 22 DEGRES, mesuree en jeu le 27 octobre 2026 :
	-- une demande de 20 degres donne 21,3, une demande de 45 donne 21,4, et une
	-- demande de 90 donne 22,4. Au-dela de 22, le chiffre ecrit ici ne decrit
	-- plus rien.
	--
	-- RIEN QUE LE TANGAGE POUR LE BUSTE, ET C'EST MESURE AUSSI. Le lacet et le
	-- roulis ont ete essayes : ils se battent avec l'animation d'attente, qui
	-- fait tourner le buste de son cote jusqu'a 22 degres toute seule. Un angle
	-- demande sur ces deux axes arrive donc quelque part entre ce qu'on veut et
	-- ce que l'animation voulait, et ca ne se regle pas. Le tangage, lui,
	-- revient exactement a zero.
	--
	-- LA TETE, ELLE, PREND LES DEUX AXES, et pour la meme raison mesuree :
	-- l'animation d'attente ne la bouge que de 0,7 degre de tangage et 0,1 de
	-- lacet sur trois secondes, contre 22 pour le buste. Ses butees sont a
	-- 37 degres de tangage et 48 de lacet.
	--
	-- La duree vient de `weaponMotion` : le bras, l'arme, le torse et la tete
	-- partent ensemble, sinon ils se contredisent.
	bodyMotion = {
		-- LE DELAI AVANT DE MESURER LA MAIN AU REPOS. Un personnage arrive
		-- membre par membre et l'animation de repos met un instant a le
		-- prendre en main : mesurer trop tot donne une main au mauvais
		-- endroit, et tout le geste part de travers. Une demi-seconde est
		-- largement sous le temps qu'il faut a un joueur pour frapper, donc
		-- ca ne se voit pas.
		settleSeconds = 0.5,

		-- La tete suit la lame vers la gauche : c'est le seul geste lateral du
		-- jeu, donc le seul qui merite un `headTurn`.
		slash = { right = -0.5, up = 0.15, forward = 1.2, lean = 8, headDip = 5, headTurn = 10 },
		-- LE PLUS PENCHE DE TOUS, et c'est le seul geste qui le merite : un
		-- marteau qui s'abat vient du corps entier. 18 et pas 22, pour qu'il
		-- reste de la place sous la butee — un geste cale contre sa butee ne se
		-- distingue plus d'un geste trop grand.
		-- Et la tete regarde ou le marteau va tomber. Le plus gros `headDip` du
		-- jeu, pour la meme raison que le plus gros `lean`.
		overhead = { right = 0, up = -0.1, forward = 1.5, lean = 18, headDip = 14, headTurn = 0 },
		-- Une arme a feu repousse : la main recule, elle n'avance pas, et le
		-- buste part en arriere avec elle.
		-- Le coup de feu releve la tete : c'est le seul `headDip` negatif avec
		-- l'arc, et c'est ce qui distingue un recul d'une frappe.
		recoil = { right = 0, up = 0.15, forward = -0.35, lean = -6, headDip = -8, headTurn = 0 },
		-- L'arc se bande : la main tire la corde vers soi, et le buste s'ouvre a
		-- peine. Moins que le fusil, parce que bander un arc est une traction
		-- lente et pas un choc.
		draw = { right = 0, up = 0.1, forward = -0.5, lean = -4, headDip = -3, headTurn = 0 },
		-- Sans arme. C'est le seul geste qui n'a pas d'equivalent dans
		-- `weaponMotion`, et c'est voulu : un coup de poing doit se voir. Il
		-- penche plus que la machette, parce qu'il n'a aucune arme pour se voir
		-- a sa place.
		fist = { right = -0.1, up = 0.1, forward = 1.5, lean = 12, headDip = 10, headTurn = 0 },
	},
}

--------------------------------------------------------------------------------
-- LE CATALOGUE D'OBJETS
--------------------------------------------------------------------------------

-- Combien d'objets chaque categorie doit compter. C'etait une cible et un
-- contenu de prototype tant que le catalogue n'en avait que treize ; le
-- prototype a repondu a sa question — le budget a douze points tient — donc il
-- ne reste que la cible, et elle est atteinte.
--
-- Cette table n'a pas disparu avec le prototype parce qu'elle est le seul
-- endroit qui dit combien d'objets le catalogue DOIT contenir. Un test compare
-- ces chiffres au catalogue reel : un objet oublie ou ajoute en double se voit
-- tout de suite, au lieu de se decouvrir en jouant.
Config.itemCounts = {
	target = { primary = 24, secondary = 10, armor = 8, heal = 6, utility = 14 },
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
-- LA PALETTE DES OBJETS. Elle existe pour que soixante-deux objets aient l'air
-- d'appartenir au meme jeu plutot que d'etre soixante-deux decisions separees.
-- Trois regles, et elles viennent du premier objet dessine :
--   les matieres s'opposent — du metal froid contre du tissu mat ;
--   une SEULE touche chaude, le laiton, et jamais deux sur le meme objet ;
--   le contraste est porte par la matiere, pas par la couleur, donc tout est
--   sourd sauf le tranchant.
-- Un objet qui a besoin d'une couleur qui n'est pas la dedans est un objet qui
-- sort du style : ajouter la couleur ici, pas dans l'objet.
local PALETTE = {
	steel = { 206, 212, 222 }, -- l'acier d'une lame, mat
	-- L'acier d'une ARMURE, plus sombre que celui d'une lame. Une armure
	-- entiere en `steel` lit comme un frigo : une lame est un eclat, une
	-- cuirasse est une surface, et une grande surface claire ecrase tout le
	-- reste. Le clair sert desormais de liseret, pas de fond.
	plate = { 148, 157, 172 },
	edge = { 240, 246, 255 }, -- le fil, la seule chose qui accroche la lumiere
	iron = { 46, 48, 54 }, -- le fer des gardes, des canons et des plaques
	gun = { 38, 40, 46 }, -- le polymere mat des armes a feu
	brass = { 176, 142, 78 }, -- la touche chaude, une par objet
	cord = { 28, 30, 36 }, -- la corde des poignees
	wrap = { 58, 48, 44 }, -- le cuir des tresses et des ceintures
	wood = { 124, 92, 62 }, -- les manches et les crosses
	cloth = { 226, 228, 232 }, -- la toile claire des trousses
	alert = { 198, 54, 58 }, -- le rouge de la croix, et rien d'autre
	olive = { 74, 86, 62 }, -- le vert des grenades
	shade = { 56, 66, 48 }, -- son ombre, pour les rainures
	glass = { 120, 170, 190 }, -- les optiques
}

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
			grip = { 0, -0.85, -0.2 },
			swing = "slash",
			voice = "blade",
			pieces = {
				{
					name = "Handle",
					size = { 0.28, 0.294, 0.7 },
					at = { 0, 0, 0.3 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Wrap1",
					size = { 0.3248, 0.336, 0.07 },
					at = { 0, 0, 0.1467 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Wrap2",
					size = { 0.3248, 0.336, 0.07 },
					at = { 0, 0, 0.34 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Wrap3",
					size = { 0.3248, 0.336, 0.07 },
					at = { 0, 0, 0.5333 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Pommel",
					size = { 0.322, 0.322, 0.322 },
					at = { 0, 0, 0.75 },
					shape = "Ball",
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Guard",
					size = { 0.884, 0.07, 0.17 },
					at = { 0, 0, -0.13 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Quillon1",
					size = { 0.091, 0.0875, 0.24 },
					at = { -0.442, 0, -0.13 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Quillon2",
					size = { 0.091, 0.0875, 0.24 },
					at = { 0.442, 0, -0.13 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Collar",
					size = { 0.364, 0.364, 0.16 },
					at = { 0, 0, -0.27 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Blade1",
					size = { 0.14, 0.52, 0.6267 },
					at = { 0, 0, -0.6583 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge1",
					size = { 0.1456, 0.104, 0.6287 },
					at = { 0, -0.208, -0.6583 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Blade2",
					size = { 0.14, 0.4923, 0.6267 },
					at = { 0, 0, -1.275 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge2",
					size = { 0.1456, 0.0985, 0.6287 },
					at = { 0, -0.1969, -1.275 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Blade3",
					size = { 0.14, 0.4645, 0.6267 },
					at = { 0, 0, -1.8917 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge3",
					size = { 0.1456, 0.0929, 0.6287 },
					at = { 0, -0.1858, -1.8917 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Tip",
					size = { 0.14, 0.2621, 0.4 },
					at = { 0, -0.0786, -2.4 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
			},
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
			grip = { 0, -0.7, -1.1 },
			swing = "recoil",
			voice = "gun",
			pieces = {
				{
					name = "Hold",
					size = { 0.19, 0.5, 0.3 },
					at = { 0, -0.3, 0.06 },
					tipUp = 20,
					color = PALETTE.gun,
					material = "Plastic",
				},
				{
					name = "Palm",
					size = { 0.235, 0.34, 0.24 },
					at = { 0, -0.32, 0.07 },
					tipUp = 20,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "TriggerGuard",
					size = { 0.09, 0.14, 0.34 },
					at = { 0, -0.21, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "GuardFront",
					size = { 0.09, 0.14, 0.09 },
					at = { 0, -0.14, -0.42 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Trigger",
					size = { 0.06, 0.15, 0.06 },
					at = { 0, -0.14, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Receiver",
					size = { 0.26, 0.4, 1.1 },
					at = { 0, 0.05, -0.29 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Ejection",
					size = { 0.27, 0.16, 0.34 },
					at = { 0.01, 0.12, -0.44 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Charger",
					size = { 0.36, 0.09, 0.09 },
					at = { 0.16, 0.12, -0.44 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Wrist",
					size = { 0.24, 0.3, 0.6 },
					at = { 0, -0.02, 0.5 },
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Stock",
					size = { 0.24, 0.44, 1.05 },
					at = { 0, -0.06, 1.305 },
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Comb",
					size = { 0.22, 0.12, 0.693 },
					at = { 0, 0.2, 1.2465 },
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Butt",
					size = { 0.26, 0.52, 0.1 },
					at = { 0, -0.08, 1.89 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Barrel",
					size = { 1.85, 0.22, 0.22 },
					at = { 0, 0.08, -1.665 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "BarrelMuzzle",
					size = { 0.3, 0.308, 0.308 },
					at = { 0, 0.08, -2.49 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "BarrelBore",
					size = { 0.12, 0.121, 0.121 },
					at = { 0, 0.08, -2.61 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Pump",
					size = { 0.3, 0.26, 0.7 },
					at = { 0, -0.12, -0.39 },
					color = PALETTE.gun,
					material = "Plastic",
				},
				{
					name = "Groove1",
					size = { 0.31, 0.06, 0.06 },
					at = { 0, -0.12, -0.54 },
					color = PALETTE.shade,
					material = "Plastic",
				},
				{
					name = "Groove2",
					size = { 0.31, 0.06, 0.06 },
					at = { 0, -0.12, -0.32 },
					color = PALETTE.shade,
					material = "Plastic",
				},
				{
					name = "Groove3",
					size = { 0.31, 0.06, 0.06 },
					at = { 0, -0.12, -0.1 },
					color = PALETTE.shade,
					material = "Plastic",
				},
				{
					name = "Tube",
					size = { 1.4, 0.14, 0.14 },
					at = { 0, -0.12, -1.515 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "FrontSight",
					size = { 0.07, 0.14, 0.07 },
					at = { 0, 0.25, -0.7 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "FrontGuard",
					size = { 0.15, 0.112, 0.06 },
					at = { 0, 0.27, -0.7 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RearSight",
					size = { 0.17, 0.098, 0.08 },
					at = { 0, 0.229, -0.34 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RearNotch",
					size = { 0.05, 0.098, 0.09 },
					at = { 0, 0.249, -0.34 },
					color = PALETTE.shade,
					material = "Metal",
				},
			},
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
			grip = { 0, -0.6, -0.9 },
			swing = "draw",
			voice = "bow",
			pieces = {
				{
					name = "Riser",
					size = { 0.198, 1.064, 0.34 },
					at = { 0, 0, 0 },
					color = PALETTE.wrap,
					material = "Wood",
				},
				{
					name = "Grip",
					size = { 0.234, 0.5054, 0.38 },
					at = { 0, -0.06, 0.03 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Shelf",
					size = { 0.306, 0.08, 0.26 },
					at = { 0, 0.415, -0.09 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Limb11",
					size = { 0.18, 0.5016, 0.3 },
					at = { 0, 0.7565, 0.0396 },
					tipUp = 10,
					color = PALETTE.wrap,
					material = "Wood",
				},
				{
					name = "Sinew11",
					size = { 0.234, 0.0775, 0.36 },
					at = { 0, 0.9264, 0.0697 },
					tipUp = 10,
					color = PALETTE.cloth,
					material = "Fabric",
				},
				{
					name = "Limb12",
					size = { 0.1512, 0.5016, 0.245 },
					at = { 0, 1.1785, 0.1932 },
					tipUp = 30,
					color = PALETTE.wrap,
					material = "Wood",
				},
				{
					name = "Sinew12",
					size = { 0.234, 0.0775, 0.305 },
					at = { 0, 1.3213, 0.2798 },
					tipUp = 30,
					color = PALETTE.cloth,
					material = "Fabric",
				},
				{
					name = "Limb13",
					size = { 0.1224, 0.5016, 0.19 },
					at = { 0, 1.5951, 0.2443 },
					tipUp = -16,
					color = PALETTE.wrap,
					material = "Wood",
				},
				{
					name = "Sinew13",
					size = { 0.234, 0.0775, 0.25 },
					at = { 0, 1.7596, 0.1966 },
					tipUp = -16,
					color = PALETTE.cloth,
					material = "Fabric",
				},
				{
					name = "Nock1",
					size = { 0.171, 0.17, 0.17 },
					at = { 0, 1.8143, 0.1815 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Limb21",
					size = { 0.18, 0.5016, 0.3 },
					at = { 0, -0.7565, 0.0396 },
					tipUp = -10,
					color = PALETTE.wrap,
					material = "Wood",
				},
				{
					name = "Sinew21",
					size = { 0.234, 0.0775, 0.36 },
					at = { 0, -0.9264, 0.0697 },
					tipUp = -10,
					color = PALETTE.cloth,
					material = "Fabric",
				},
				{
					name = "Limb22",
					size = { 0.1512, 0.5016, 0.245 },
					at = { 0, -1.1785, 0.1932 },
					tipUp = -30,
					color = PALETTE.wrap,
					material = "Wood",
				},
				{
					name = "Sinew22",
					size = { 0.234, 0.0775, 0.305 },
					at = { 0, -1.3213, 0.2798 },
					tipUp = -30,
					color = PALETTE.cloth,
					material = "Fabric",
				},
				{
					name = "Limb23",
					size = { 0.1224, 0.5016, 0.19 },
					at = { 0, -1.5951, 0.2443 },
					tipUp = 16,
					color = PALETTE.wrap,
					material = "Wood",
				},
				{
					name = "Sinew23",
					size = { 0.234, 0.0775, 0.25 },
					at = { 0, -1.7596, 0.1966 },
					tipUp = 16,
					color = PALETTE.cloth,
					material = "Fabric",
				},
				{
					name = "Nock2",
					size = { 0.171, 0.17, 0.17 },
					at = { 0, -1.8143, 0.1815 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "String",
					size = { 0.05, 3.6286, 0.05 },
					at = { 0, 0, 0.1815 },
					color = PALETTE.cloth,
					material = "SmoothPlastic",
				},
				{
					name = "Serving",
					size = { 0.08, 0.3, 0.08 },
					at = { 0, 0, 0.1815 },
					color = PALETTE.wrap,
					material = "Leather",
				},
			},
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
			grip = { 0, -0.9, -0.15 },
			swing = "overhead",
			voice = "blunt",
			pieces = {
				{
					name = "Shaft",
					size = { 3.2, 0.26, 0.26 },
					at = { 0, 0, -0.9 },
					tipLeft = 90,
					shape = "Cylinder",
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Wrap1",
					size = { 0.18, 0.3, 0.3 },
					at = { 0, 0, 0.52 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Fabric",
				},
				{
					name = "Wrap2",
					size = { 0.18, 0.3, 0.3 },
					at = { 0, 0, 0.3 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Fabric",
				},
				{
					name = "Wrap3",
					size = { 0.18, 0.3, 0.3 },
					at = { 0, 0, 0.08 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Fabric",
				},
				{
					name = "Wrap4",
					size = { 0.18, 0.3, 0.3 },
					at = { 0, 0, -0.14 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Fabric",
				},
				{
					name = "Pommel",
					size = { 0.16, 0.34, 0.34 },
					at = { 0, 0, 0.74 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.1,
				},
				{
					name = "Collar",
					size = { 0.18, 0.42, 0.42 },
					at = { 0, 0, -1.78 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "LangetLeft",
					size = { 0.06, 0.24, 0.66 },
					at = { -0.14, 0, -1.97 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.1,
				},
				{
					name = "LangetRight",
					size = { 0.06, 0.24, 0.66 },
					at = { 0.14, 0, -1.97 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.1,
				},
				{
					name = "Head",
					size = { 0.6, 0.78, 0.68 },
					at = { 0, 0, -2.4 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Face",
					size = { 0.68, 0.86, 0.14 },
					at = { 0, 0, -2.7 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Beak",
					size = { 0.24, 0.42, 0.56 },
					at = { 0, 0.06, -1.98 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Rivet1",
					size = { 0.09, 0.09, 0.09 },
					at = { -0.32, 0.24, -2.4 },
					shape = "Ball",
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Rivet2",
					size = { 0.09, 0.09, 0.09 },
					at = { 0.32, 0.24, -2.4 },
					shape = "Ball",
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Rivet3",
					size = { 0.09, 0.09, 0.09 },
					at = { -0.32, -0.24, -2.4 },
					shape = "Ball",
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Rivet4",
					size = { 0.09, 0.09, 0.09 },
					at = { 0.32, -0.24, -2.4 },
					shape = "Ball",
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
			},
		},
	},

	{
		id = "fastPistol",
		category = "primary",
		cost = 4,
		name = "Pistolet rapide",
		summary = "Tir léger, cadence élevée, dégâts faibles",
		-- L'arme principale la moins chere qui tire : elle rend moins de la
		-- moitie des degats d'un coup de classe, trois fois plus souvent. A
		-- quatre points elle laisse huit points pour tout le reste, et c'est
		-- tout son interet.
		scale = { attackDamage = 0.59, attackCooldownSeconds = 0.5, attackRangeStuds = 1.9 },
		look = {
			grip = { 0, -0.7, -0.5 },
			swing = "recoil",
			voice = "gun",
			pieces = {
				{
					name = "Hold",
					size = { 0.19, 0.5, 0.3 },
					at = { 0, -0.3, 0.06 },
					tipUp = 16,
					color = PALETTE.gun,
					material = "Plastic",
				},
				{
					name = "Palm",
					size = { 0.235, 0.34, 0.24 },
					at = { 0, -0.32, 0.07 },
					tipUp = 16,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "TriggerGuard",
					size = { 0.09, 0.14, 0.34 },
					at = { 0, -0.21, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "GuardFront",
					size = { 0.09, 0.14, 0.09 },
					at = { 0, -0.14, -0.42 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Trigger",
					size = { 0.06, 0.15, 0.06 },
					at = { 0, -0.14, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Frame",
					size = { 0.2, 0.22, 0.86 },
					at = { 0, 0, -0.18 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Slide",
					size = { 0.22, 0.28, 1.15 },
					at = { 0, 0.22, -0.835 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Breech",
					size = { 0.23, 0.3, 0.26 },
					at = { 0, 0.21, -0.1 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Serration1",
					size = { 0.235, 0.22, 0.05 },
					at = { 0, 0.22, -0.16 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Serration2",
					size = { 0.235, 0.22, 0.05 },
					at = { 0, 0.22, -0.26 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Serration3",
					size = { 0.235, 0.22, 0.05 },
					at = { 0, 0.22, -0.36 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Baseplate",
					size = { 0.21, 0.07, 0.34 },
					at = { 0, -0.55, 0.14 },
					tipUp = 16,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Bore",
					size = { 0.12, 0.1, 0.1 },
					at = { 0, 0.22, -1.39 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "FrontSight",
					size = { 0.07, 0.1, 0.07 },
					at = { 0, 0.37, -1.27 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "FrontGuard",
					size = { 0.15, 0.08, 0.06 },
					at = { 0, 0.39, -1.27 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RearSight",
					size = { 0.17, 0.07, 0.08 },
					at = { 0, 0.355, -0.14 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RearNotch",
					size = { 0.05, 0.07, 0.09 },
					at = { 0, 0.375, -0.14 },
					color = PALETTE.shade,
					material = "Metal",
				},
			},
		},
	},
	{
		id = "lightCrossbow",
		category = "primary",
		cost = 4,
		name = "Arbalète légère",
		summary = "Un carreau précis, rechargement lent",
		-- Presque deux fois les degats d'un coup, mais il faut attendre entre
		-- deux. Rater un carreau coute une seconde et demie, donc elle punit
		-- l'approximation comme aucune autre arme a quatre points.
		scale = { attackDamage = 1.75, attackCooldownSeconds = 1.6, attackRangeStuds = 2.6 },
		look = {
			grip = { 0, -0.7, -0.8 },
			swing = "draw",
			voice = "bow",
			pieces = {
				{
					name = "Tiller",
					size = { 0.2, 0.24, 2.6 },
					at = { 0, 0, -0.8 },
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Butt",
					size = { 0.24, 0.46, 0.26 },
					at = { 0, -0.08, 0.42 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Comb",
					size = { 0.18, 0.12, 0.7 },
					at = { 0, 0.17, 0.08 },
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Groove",
					size = { 0.09, 0.08, 1.56 },
					at = { 0, 0.14, -0.945 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Hold",
					size = { 0.17, 0.42, 0.26 },
					at = { 0, -0.26, -0.18 },
					tipUp = 18,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Lever",
					size = { 0.07, 0.3, 0.1 },
					at = { 0, -0.2, -0.04 },
					tipUp = 30,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Nut",
					size = { 0.24, 0.2, 0.2 },
					at = { 0, 0.1, 0.16 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Bridle",
					size = { 0.26, 0.28, 0.24 },
					at = { 0, 0.02, -1.8 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Stirrup",
					size = { 0.3, 0.3, 0.1 },
					at = { 0, -0.2, -2.22 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Foot",
					size = { 0.1, 0.28, 0.1 },
					at = { 0, -0.1, -2.22 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Lath11",
					size = { 0.4033, 0.16, 0.2 },
					at = { 0.2815, 0.02, -1.7745 },
					tipLeft = -8,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Lath12",
					size = { 0.4033, 0.14, 0.17 },
					at = { 0.6354, 0.02, -1.6863 },
					tipLeft = -20,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Lath13",
					size = { 0.4033, 0.12, 0.14 },
					at = { 0.9596, 0.02, -1.521 },
					tipLeft = -34,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Tip1",
					size = { 0.1, 0.14, 0.14 },
					at = { 1.1116, 0.02, -1.4185 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Lath21",
					size = { 0.4033, 0.16, 0.2 },
					at = { -0.2815, 0.02, -1.7745 },
					tipLeft = 8,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Lath22",
					size = { 0.4033, 0.14, 0.17 },
					at = { -0.6354, 0.02, -1.6863 },
					tipLeft = 20,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Lath23",
					size = { 0.4033, 0.12, 0.14 },
					at = { -0.9596, 0.02, -1.521 },
					tipLeft = 34,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Tip2",
					size = { 0.1, 0.14, 0.14 },
					at = { -1.1116, 0.02, -1.4185 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "String",
					size = { 2.2233, 0.05, 0.05 },
					at = { 0, 0.02, -1.4185 },
					color = PALETTE.cloth,
					material = "SmoothPlastic",
				},
				{
					name = "Bolt",
					size = { 0.07, 0.07, 1.352 },
					at = { 0, 0.19, -0.882 },
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "BoltHead",
					size = { 0.08, 0.08, 0.2 },
					at = { 0, 0.19, -1.7 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
			},
		},
	},
	{
		id = "club",
		category = "primary",
		cost = 4,
		name = "Gourdin",
		summary = "Mêlée lente, repousse légèrement",
		-- La poussee est son vrai texte : elle ne tue pas, elle donne de
		-- l'espace. C'est l'arme de qui joue autour d'une couverture.
		scale = { attackDamage = 1.4, attackCooldownSeconds = 1.15, attackRangeStuds = 0.9 },
		offset = { knockbackStuds = 14, knockbackUpStuds = 4 },
		look = {
			grip = { 0, -0.85, -0.3 },
			swing = "overhead",
			voice = "blunt",
			pieces = {
				{
					name = "Shaft",
					size = { 2.4, 0.1872, 0.1872 },
					at = { 0, 0, -0.8 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Butt",
					size = { 0.14, 0.2621, 0.2621 },
					at = { 0, 0, 0.38 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Hold1",
					size = { 0.16, 0.2434, 0.2434 },
					at = { 0, 0, 0.12 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Hold2",
					size = { 0.16, 0.2434, 0.2434 },
					at = { 0, 0, -0.1 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Hold3",
					size = { 0.16, 0.2434, 0.2434 },
					at = { 0, 0, -0.32 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Swell4",
					size = { 0.4, 0.666, 0.666 },
					at = { 0, 0, -1.6 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Swell3",
					size = { 0.4, 0.5688, 0.5688 },
					at = { 0, 0, -1.22 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Swell2",
					size = { 0.4, 0.468, 0.468 },
					at = { 0, 0, -0.84 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Swell1",
					size = { 0.4, 0.378, 0.378 },
					at = { 0, 0, -0.46 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Cap",
					size = { 0.666, 0.666, 0.666 },
					at = { 0, 0, -1.7 },
					shape = "Ball",
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Band",
					size = { 0.14, 0.3888, 0.3888 },
					at = { 0, 0, -0.28 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Stud1",
					size = { 0.17, 0.17, 0.17 },
					at = { 0.2722, 0, -1.34 },
					shape = "Ball",
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Stud2",
					size = { 0.17, 0.17, 0.17 },
					at = { -0.2722, 0, -1.34 },
					shape = "Ball",
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Stud3",
					size = { 0.17, 0.17, 0.17 },
					at = { 0, 0.2722, -1.34 },
					shape = "Ball",
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Stud4",
					size = { 0.17, 0.17, 0.17 },
					at = { 0, -0.2722, -1.34 },
					shape = "Ball",
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
			},
		},
	},
	{
		id = "sling",
		category = "primary",
		cost = 4,
		name = "Fronde",
		summary = "Projectile en cloche, longue portée, dégâts faibles",
		-- Trois fois la portee de la classe pour des degats par seconde en
		-- dessous de tout le reste : on achete de la distance, et on la paie.
		scale = { attackDamage = 0.7, attackCooldownSeconds = 0.75, attackRangeStuds = 3 },
		look = {
			grip = { 0, -0.6, -0.4 },
			swing = "slash",
			voice = "bow",
			pieces = {
				{
					name = "Loop",
					size = { 0.1, 0.3, 0.3 },
					at = { 0, 0, 0.04 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Knot",
					size = { 0.13, 0.13, 0.13 },
					at = { 0, -0.11, 0.02 },
					shape = "Ball",
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Cord11",
					size = { 0.055, 0.055, 0.55 },
					at = { -0.09, -0.2005, -0.2426 },
					tipUp = -14,
					color = PALETTE.wood,
					material = "Leather",
				},
				{
					name = "Cord12",
					size = { 0.055, 0.055, 0.55 },
					at = { -0.09, -0.2871, -0.7338 },
					tipUp = -6,
					color = PALETTE.wood,
					material = "Leather",
				},
				{
					name = "Cord13",
					size = { 0.055, 0.055, 0.55 },
					at = { -0.09, -0.2958, -1.2318 },
					tipUp = 4,
					color = PALETTE.wood,
					material = "Leather",
				},
				{
					name = "Seam1",
					size = { 0.1, 0.1, 0.11 },
					at = { -0.09, -0.2783, -1.4812 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Cord21",
					size = { 0.055, 0.055, 0.55 },
					at = { 0.09, -0.2005, -0.2426 },
					tipUp = -14,
					color = PALETTE.wood,
					material = "Leather",
				},
				{
					name = "Cord22",
					size = { 0.055, 0.055, 0.55 },
					at = { 0.09, -0.2871, -0.7338 },
					tipUp = -6,
					color = PALETTE.wood,
					material = "Leather",
				},
				{
					name = "Cord23",
					size = { 0.055, 0.055, 0.55 },
					at = { 0.09, -0.2958, -1.2318 },
					tipUp = 4,
					color = PALETTE.wood,
					material = "Leather",
				},
				{
					name = "Seam2",
					size = { 0.1, 0.1, 0.11 },
					at = { 0.09, -0.2783, -1.4812 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Pouch",
					size = { 0.3, 0.3, 0.46 },
					at = { 0, -0.3183, -1.6812 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Cradle",
					size = { 0.36, 0.165, 0.3 },
					at = { 0, -0.3883, -1.6812 },
					color = PALETTE.wood,
					material = "Leather",
				},
				{
					name = "Stone",
					size = { 0.26, 0.26, 0.26 },
					at = { 0, -0.2483, -1.6812 },
					shape = "Ball",
					color = PALETTE.plate,
					material = "Slate",
				},
			},
		},
	},
	{
		id = "claws",
		category = "primary",
		cost = 4,
		name = "Griffes",
		summary = "Deux coups très rapides, portée minimale",
		-- Les degats par seconde les plus eleves des armes a quatre points, pour
		-- une portee de moins de quatre studs : il faut etre colle, et y rester.
		scale = { attackDamage = 0.64, attackCooldownSeconds = 0.46, attackRangeStuds = 0.5 },
		look = {
			grip = { 0, -0.5, -0.2 },
			swing = "slash",
			voice = "blade",
			pieces = {
				{
					name = "Bar",
					size = { 0.78, 0.15, 0.18 },
					at = { 0, -0.02, 0.1 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Strap",
					size = { 0.7, 0.1, 0.3 },
					at = { 0, -0.13, 0.26 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Rivet",
					size = { 0.1, 0.1, 0.1 },
					at = { 0, 0.07, 0.12 },
					shape = "Ball",
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Claw11",
					size = { 0.1, 0.2, 0.4189 },
					at = { -0.26, -0.006, -0.1852 },
					tipUp = -8,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Claw12",
					size = { 0.08, 0.15, 0.4189 },
					at = { -0.26, -0.1081, -0.5412 },
					tipUp = -24,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Claw13",
					size = { 0.06, 0.1, 0.4189 },
					at = { -0.26, -0.3044, -0.8553 },
					tipUp = -40,
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Knuckle1",
					size = { 0.16, 0.16, 0.16 },
					at = { -0.26, 0.05, 0.06 },
					shape = "Ball",
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Claw21",
					size = { 0.1, 0.2, 0.4189 },
					at = { 0, -0.006, -0.1852 },
					tipUp = -8,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Claw22",
					size = { 0.08, 0.15, 0.4189 },
					at = { 0, -0.1081, -0.5412 },
					tipUp = -24,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Claw23",
					size = { 0.06, 0.1, 0.4189 },
					at = { 0, -0.3044, -0.8553 },
					tipUp = -40,
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Knuckle2",
					size = { 0.16, 0.16, 0.16 },
					at = { 0, 0.05, 0.06 },
					shape = "Ball",
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Claw31",
					size = { 0.1, 0.2, 0.4189 },
					at = { 0.26, -0.006, -0.1852 },
					tipUp = -8,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Claw32",
					size = { 0.08, 0.15, 0.4189 },
					at = { 0.26, -0.1081, -0.5412 },
					tipUp = -24,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Claw33",
					size = { 0.06, 0.1, 0.4189 },
					at = { 0.26, -0.3044, -0.8553 },
					tipUp = -40,
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Knuckle3",
					size = { 0.16, 0.16, 0.16 },
					at = { 0.26, 0.05, 0.06 },
					shape = "Ball",
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
			},
		},
	},
	{
		id = "shortSword",
		category = "primary",
		cost = 5,
		name = "Épée courte",
		summary = "Mêlée équilibrée, sans défaut ni éclat",
		-- Volontairement sans particularite. Le catalogue a besoin d'au moins
		-- une arme qui ne demande rien a personne : c'est elle qu'on prend quand
		-- les sept points restants servent ailleurs.
		scale = { attackDamage = 1.1, attackCooldownSeconds = 0.8, attackRangeStuds = 1 },
		look = {
			grip = { 0, -0.85, -0.2 },
			swing = "slash",
			voice = "blade",
			pieces = {
				{
					name = "Handle",
					size = { 0.28, 0.294, 0.8 },
					at = { 0, 0, 0.35 },
					color = PALETTE.cord,
					material = "Leather",
				},
				{
					name = "Wrap1",
					size = { 0.3248, 0.336, 0.07 },
					at = { 0, 0, 0.1633 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Wrap2",
					size = { 0.3248, 0.336, 0.07 },
					at = { 0, 0, 0.39 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Wrap3",
					size = { 0.3248, 0.336, 0.07 },
					at = { 0, 0, 0.6167 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Pommel",
					size = { 0.322, 0.322, 0.322 },
					at = { 0, 0, 0.85 },
					shape = "Ball",
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Guard",
					size = { 0.748, 0.07, 0.17 },
					at = { 0, 0, -0.13 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Quillon1",
					size = { 0.091, 0.0875, 0.24 },
					at = { -0.374, 0, -0.13 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Quillon2",
					size = { 0.091, 0.0875, 0.24 },
					at = { 0.374, 0, -0.13 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Collar",
					size = { 0.364, 0.364, 0.16 },
					at = { 0, 0, -0.27 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Blade1",
					size = { 0.14, 0.44, 0.66 },
					at = { 0, 0, -0.675 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge1",
					size = { 0.1456, 0.088, 0.662 },
					at = { 0, -0.176, -0.675 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Blade2",
					size = { 0.14, 0.4165, 0.66 },
					at = { 0, 0, -1.325 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge2",
					size = { 0.1456, 0.0833, 0.662 },
					at = { 0, -0.1666, -1.325 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Blade3",
					size = { 0.14, 0.3931, 0.66 },
					at = { 0, 0, -1.975 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge3",
					size = { 0.1456, 0.0786, 0.662 },
					at = { 0, -0.1572, -1.975 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Tip",
					size = { 0.14, 0.2218, 0.4 },
					at = { 0, -0.0665, -2.5 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
			},
		},
	},
	{
		id = "bow",
		category = "primary",
		cost = 5,
		name = "Arc",
		summary = "Tir chargé, précis, silencieux",
		-- L'arc composite sans la perforation, pour un point de moins. C'est la
		-- paire qui dit le mieux ce que vaut un point dans ce jeu.
		scale = { attackDamage = 1.5, attackCooldownSeconds = 1.3, attackRangeStuds = 2.8 },
		look = {
			grip = { 0, -0.6, -0.9 },
			swing = "draw",
			voice = "bow",
			pieces = {
				{
					name = "Riser",
					size = { 0.165, 1.176, 0.34 },
					at = { 0, 0, 0 },
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Grip",
					size = { 0.195, 0.5586, 0.38 },
					at = { 0, -0.06, 0.03 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Shelf",
					size = { 0.255, 0.08, 0.26 },
					at = { 0, 0.4586, -0.09 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Limb11",
					size = { 0.15, 0.5544, 0.3 },
					at = { 0, 0.8386, 0.0263 },
					tipUp = 6,
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Limb12",
					size = { 0.126, 0.5544, 0.245 },
					at = { 0, 1.326, 0.1389 },
					tipUp = 20,
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Limb13",
					size = { 0.102, 0.5544, 0.19 },
					at = { 0, 1.7718, 0.366 },
					tipUp = 34,
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Nock1",
					size = { 0.1425, 0.17, 0.17 },
					at = { 0, 1.9807, 0.5069 },
					color = PALETTE.wood,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Limb21",
					size = { 0.15, 0.5544, 0.3 },
					at = { 0, -0.8386, 0.0263 },
					tipUp = -6,
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Limb22",
					size = { 0.126, 0.5544, 0.245 },
					at = { 0, -1.326, 0.1389 },
					tipUp = -20,
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Limb23",
					size = { 0.102, 0.5544, 0.19 },
					at = { 0, -1.7718, 0.366 },
					tipUp = -34,
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Nock2",
					size = { 0.1425, 0.17, 0.17 },
					at = { 0, -1.9807, 0.5069 },
					color = PALETTE.wood,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "String",
					size = { 0.05, 3.9614, 0.05 },
					at = { 0, 0, 0.5069 },
					color = PALETTE.cloth,
					material = "SmoothPlastic",
				},
				{
					name = "Serving",
					size = { 0.08, 0.3, 0.08 },
					at = { 0, 0, 0.5069 },
					color = PALETTE.wrap,
					material = "Leather",
				},
			},
		},
	},
	{
		id = "spear",
		category = "primary",
		cost = 5,
		name = "Lance",
		summary = "Portée de mêlée longue, coups lents",
		-- Dix studs et demi sur un Vampire : elle touche depuis l'endroit ou une
		-- machette ne touche pas encore. La lenteur est le prix de ce pas
		-- d'avance.
		scale = { attackDamage = 1.5, attackCooldownSeconds = 1.15, attackRangeStuds = 1.5 },
		look = {
			grip = { 0, -0.8, -0.8 },
			swing = "overhead",
			voice = "blade",
			pieces = {
				{
					name = "Shaft",
					size = { 4.8, 0.16, 0.16 },
					at = { 0, 0, -2 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Butt",
					size = { 0.14, 0.224, 0.224 },
					at = { 0, 0, 0.38 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Hold1",
					size = { 0.16, 0.208, 0.208 },
					at = { 0, 0, 0.1 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Hold2",
					size = { 0.16, 0.208, 0.208 },
					at = { 0, 0, -0.5 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Hold3",
					size = { 0.16, 0.208, 0.208 },
					at = { 0, 0, -1.1 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Ferrule",
					size = { 0.4, 0.288, 0.288 },
					at = { 0, 0, -4.14 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Socket",
					size = { 0.208, 0.208, 0.32 },
					at = { 0, 0, -4.42 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Leaf1",
					size = { 0.11, 0.34, 0.42 },
					at = { 0, 0, -4.72 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Leaf2",
					size = { 0.11, 0.52, 0.44 },
					at = { 0, 0, -5.12 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Leaf3",
					size = { 0.11, 0.44, 0.42 },
					at = { 0, 0, -5.52 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Leaf4",
					size = { 0.1, 0.3, 0.42 },
					at = { 0, 0, -5.9 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Point",
					size = { 0.09, 0.14, 0.4 },
					at = { 0, 0, -6.26 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Fuller",
					size = { 0.118, 0.05, 1.3 },
					at = { 0, 0, -5.35 },
					color = PALETTE.iron,
					material = "Metal",
				},
			},
		},
	},
	{
		id = "submachineGun",
		category = "primary",
		cost = 5,
		name = "Mitraillette",
		summary = "Cadence élevée, dégâts faibles, imprécise",
		-- Le plus fort rendement du palier a cinq points, pour une portee a
		-- peine superieure a une lance. « Imprecise » est dit par la portee :
		-- au-dela, elle ne touche simplement plus.
		scale = { attackDamage = 0.625, attackCooldownSeconds = 0.5, attackRangeStuds = 1.6 },
		look = {
			grip = { 0, -0.7, -0.8 },
			swing = "recoil",
			voice = "gun",
			pieces = {
				{
					name = "Hold",
					size = { 0.19, 0.5, 0.3 },
					at = { 0, -0.3, 0.06 },
					tipUp = 20,
					color = PALETTE.gun,
					material = "Plastic",
				},
				{
					name = "Palm",
					size = { 0.235, 0.34, 0.24 },
					at = { 0, -0.32, 0.07 },
					tipUp = 20,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "TriggerGuard",
					size = { 0.09, 0.14, 0.34 },
					at = { 0, -0.21, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "GuardFront",
					size = { 0.09, 0.14, 0.09 },
					at = { 0, -0.14, -0.42 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Trigger",
					size = { 0.06, 0.15, 0.06 },
					at = { 0, -0.14, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Receiver",
					size = { 0.26, 0.4, 1.05 },
					at = { 0, 0.05, -0.265 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Ejection",
					size = { 0.27, 0.16, 0.34 },
					at = { 0.01, 0.12, -0.39 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Charger",
					size = { 0.36, 0.09, 0.09 },
					at = { 0.16, 0.12, -0.39 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Rail1",
					size = { 0.06, 0.07, 0.85 },
					at = { 0, 0.16, 0.845 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Rail2",
					size = { 0.06, 0.07, 0.85 },
					at = { 0, -0.14, 0.845 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Plate",
					size = { 0.22, 0.42, 0.09 },
					at = { 0, 0.01, 1.27 },
					color = PALETTE.gun,
					material = "Plastic",
				},
				{
					name = "Hinge",
					size = { 0.2, 0.2, 0.18 },
					at = { 0, 0.02, 0.4 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Handguard",
					size = { 0.25, 0.26, 0.5 },
					at = { 0, 0.02, -1.04 },
					color = PALETTE.gun,
					material = "Plastic",
				},
				{
					name = "Vent1",
					size = { 0.26, 0.07, 0.07 },
					at = { 0, 0.02, -0.97 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Vent2",
					size = { 0.26, 0.07, 0.07 },
					at = { 0, 0.02, -1.21 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Vent3",
					size = { 0.26, 0.07, 0.07 },
					at = { 0, 0.02, -1.45 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Barrel",
					size = { 1.05, 0.13, 0.13 },
					at = { 0, 0.08, -1.715 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "BarrelMuzzle",
					size = { 0.3, 0.182, 0.182 },
					at = { 0, 0.08, -2.14 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "BarrelBore",
					size = { 0.12, 0.0715, 0.0715 },
					at = { 0, 0.08, -2.26 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Mag1",
					size = { 0.19, 0.2688, 0.4 },
					at = { 0, -0.2793, -0.2775 },
					tipUp = 84,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.1,
				},
				{
					name = "Mag2",
					size = { 0.19, 0.2688, 0.4 },
					at = { 0, -0.5128, -0.2278 },
					tipUp = 72,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.1,
				},
				{
					name = "Mag3",
					size = { 0.19, 0.2688, 0.4 },
					at = { 0, -0.7309, -0.1307 },
					tipUp = 60,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.1,
				},
				{
					name = "FrontSight",
					size = { 0.07, 0.14, 0.07 },
					at = { 0, 0.25, -1.15 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "FrontGuard",
					size = { 0.15, 0.112, 0.06 },
					at = { 0, 0.27, -1.15 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RearSight",
					size = { 0.17, 0.098, 0.08 },
					at = { 0, 0.229, -0.29 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RearNotch",
					size = { 0.05, 0.098, 0.09 },
					at = { 0, 0.249, -0.29 },
					color = PALETTE.shade,
					material = "Metal",
				},
			},
		},
	},
	{
		id = "throwingAxe",
		category = "primary",
		cost = 5,
		name = "Hachette de lancer",
		summary = "Mêlée correcte, plus deux lancers par manche",
		-- La seule arme principale qui porte un objet utilisable. Les deux
		-- lancers reviennent entre deux manches, comme toutes les charges : une
		-- hachette qu'on ramasserait au sol demanderait de suivre un objet dans
		-- le monde, et ca ne vaut pas ce que ca coute.
		scale = { attackDamage = 1.1, attackCooldownSeconds = 0.85, attackRangeStuds = 0.95 },
		use = {
			kind = "throw",
			charges = 2,
			damage = 38,
			rangeStuds = 60,
			radiusStuds = 3,
		},
		look = {
			grip = { 0, -0.8, -0.2 },
			swing = "overhead",
			voice = "blade",
			pieces = {
				{
					name = "Shaft",
					size = { 1.7, 0.15, 0.15 },
					at = { 0, 0, -0.45 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Butt",
					size = { 0.14, 0.21, 0.21 },
					at = { 0, 0, 0.38 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Hold1",
					size = { 0.16, 0.195, 0.195 },
					at = { 0, 0, 0.1 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Hold2",
					size = { 0.16, 0.195, 0.195 },
					at = { 0, 0, -0.12 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Hold3",
					size = { 0.16, 0.195, 0.195 },
					at = { 0, 0, -0.34 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Socket",
					size = { 0.46, 0.24, 0.24 },
					at = { 0, 0, -0.94 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Bit1",
					size = { 0.1829, 0.3564, 0.2145 },
					at = { 0, -0.033, -1.2458 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Bit2",
					size = { 0.1706, 0.506, 0.2145 },
					at = { 0, -0.099, -1.4174 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Bit3",
					size = { 0.1584, 0.6556, 0.2145 },
					at = { 0, -0.165, -1.589 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Bit4",
					size = { 0.1461, 0.8052, 0.2145 },
					at = { 0, -0.231, -1.7606 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge",
					size = { 0.077, 0.8448, 0.14 },
					at = { 0, -0.2464, -1.8764 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
			},
		},
	},
	{
		id = "longSword",
		category = "primary",
		cost = 6,
		name = "Épée longue",
		summary = "Mêlée forte, coups lents",
		scale = { attackDamage = 1.8, attackCooldownSeconds = 1.25, attackRangeStuds = 1.2 },
		look = {
			grip = { 0, -0.9, -0.3 },
			swing = "overhead",
			voice = "blade",
			pieces = {
				{
					name = "Handle",
					size = { 0.32, 0.336, 1.2 },
					at = { 0, 0, 0.55 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Wrap1",
					size = { 0.3712, 0.384, 0.07 },
					at = { 0, 0, 0.23 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Wrap2",
					size = { 0.3712, 0.384, 0.07 },
					at = { 0, 0, 0.59 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Wrap3",
					size = { 0.3712, 0.384, 0.07 },
					at = { 0, 0, 0.95 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Pommel",
					size = { 0.368, 0.368, 0.368 },
					at = { 0, 0, 1.25 },
					shape = "Ball",
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Guard",
					size = { 0.85, 0.08, 0.17 },
					at = { 0, 0, -0.13 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Quillon1",
					size = { 0.104, 0.1, 0.24 },
					at = { -0.425, 0, -0.13 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Quillon2",
					size = { 0.104, 0.1, 0.24 },
					at = { 0.425, 0, -0.13 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Collar",
					size = { 0.416, 0.416, 0.16 },
					at = { 0, 0, -0.27 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Blade1",
					size = { 0.16, 0.5, 0.9267 },
					at = { 0, 0, -0.8083 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge1",
					size = { 0.1664, 0.1, 0.9287 },
					at = { 0, -0.2, -0.8083 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Blade2",
					size = { 0.16, 0.4733, 0.9267 },
					at = { 0, 0, -1.725 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge2",
					size = { 0.1664, 0.0947, 0.9287 },
					at = { 0, -0.1893, -1.725 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Blade3",
					size = { 0.16, 0.4467, 0.9267 },
					at = { 0, 0, -2.6417 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge3",
					size = { 0.1664, 0.0893, 0.9287 },
					at = { 0, -0.1787, -2.6417 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Tip",
					size = { 0.16, 0.252, 0.4 },
					at = { 0, -0.0756, -3.3 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.35,
				},
			},
		},
	},
	{
		id = "huntingRifle",
		category = "primary",
		cost = 6,
		name = "Fusil de chasse",
		summary = "Deux balles par manche, précis à distance moyenne",
		-- Deux coups par manche et rien apres : c'est ce que « deux balles »
		-- veut dire, et c'est la seule arme principale a qui le chargeur peut
		-- manquer. Avec une secondaire, c'est un choix ; sans, c'est un risque.
		scale = { attackDamage = 1.9, attackCooldownSeconds = 1.5, attackRangeStuds = 2.9 },
		shotsPerRound = 2,
		look = {
			grip = { 0, -0.7, -1.3 },
			swing = "recoil",
			voice = "gun",
			pieces = {
				{
					name = "Hold",
					size = { 0.19, 0.5, 0.3 },
					at = { 0, -0.3, 0.06 },
					tipUp = 20,
					color = PALETTE.wood,
					material = "Plastic",
				},
				{
					name = "Palm",
					size = { 0.235, 0.34, 0.24 },
					at = { 0, -0.32, 0.07 },
					tipUp = 20,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "TriggerGuard",
					size = { 0.09, 0.14, 0.34 },
					at = { 0, -0.21, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "GuardFront",
					size = { 0.09, 0.14, 0.09 },
					at = { 0, -0.14, -0.42 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Trigger",
					size = { 0.06, 0.15, 0.06 },
					at = { 0, -0.14, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Receiver",
					size = { 0.26, 0.4, 1.25 },
					at = { 0, 0.05, -0.365 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Ejection",
					size = { 0.27, 0.16, 0.34 },
					at = { 0.01, 0.12, -0.59 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Charger",
					size = { 0.36, 0.09, 0.09 },
					at = { 0.16, 0.12, -0.59 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Wrist",
					size = { 0.24, 0.3, 0.6 },
					at = { 0, -0.02, 0.5 },
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Stock",
					size = { 0.24, 0.44, 1.1 },
					at = { 0, -0.06, 1.33 },
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Comb",
					size = { 0.22, 0.12, 0.726 },
					at = { 0, 0.2, 1.263 },
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Butt",
					size = { 0.26, 0.52, 0.1 },
					at = { 0, -0.08, 1.94 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Handguard",
					size = { 0.25, 0.26, 0.75 },
					at = { 0, 0.02, -1.365 },
					color = PALETTE.wood,
					material = "Plastic",
				},
				{
					name = "Vent1",
					size = { 0.26, 0.07, 0.07 },
					at = { 0, 0.02, -1.17 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Vent2",
					size = { 0.26, 0.07, 0.07 },
					at = { 0, 0.02, -1.41 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Vent3",
					size = { 0.26, 0.07, 0.07 },
					at = { 0, 0.02, -1.65 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Barrel",
					size = { 1.85, 0.15, 0.15 },
					at = { 0, 0.08, -2.565 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "BarrelMuzzle",
					size = { 0.3, 0.21, 0.21 },
					at = { 0, 0.08, -3.39 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "BarrelBore",
					size = { 0.12, 0.0825, 0.0825 },
					at = { 0, 0.08, -3.51 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Magazine",
					size = { 0.19, 0.3, 0.34 },
					at = { 0, -0.29, -0.47 },
					tipUp = -8,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.1,
				},
				{
					name = "MagLip",
					size = { 0.21, 0.1, 0.357 },
					at = { 0, -0.16, -0.47 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "ScopeTube",
					size = { 1.3, 0.26, 0.26 },
					at = { 0, 0.4, -0.24 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "ScopeBell",
					size = { 0.3, 0.34, 0.34 },
					at = { 0, 0.4, -0.83 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Lens",
					size = { 0.06, 0.28, 0.28 },
					at = { 0, 0.4, -0.95 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.glass,
					material = "Glass",
					reflectance = 0.5,
				},
				{
					name = "Ring1",
					size = { 0.12, 0.3, 0.3 },
					at = { 0, 0.4, 0.11 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Ring2",
					size = { 0.12, 0.3, 0.3 },
					at = { 0, 0.4, -0.59 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Turret",
					size = { 0.16, 0.16, 0.16 },
					at = { 0.13, 0.46, -0.24 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
			},
		},
	},
	{
		id = "mace",
		category = "primary",
		cost = 6,
		name = "Masse d'armes",
		summary = "Dégâts forts et repoussement",
		scale = { attackDamage = 1.9, attackCooldownSeconds = 1.4, attackRangeStuds = 0.95 },
		offset = { knockbackStuds = 26, knockbackUpStuds = 8 },
		look = {
			grip = { 0, -0.85, -0.3 },
			swing = "overhead",
			voice = "blunt",
			pieces = {
				{
					name = "Shaft",
					size = { 2.5, 0.21, 0.21 },
					at = { 0, 0, -0.85 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
				},
				{
					name = "Butt",
					size = { 0.14, 0.294, 0.294 },
					at = { 0, 0, 0.38 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Hold1",
					size = { 0.16, 0.273, 0.273 },
					at = { 0, 0, 0.12 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Hold2",
					size = { 0.16, 0.273, 0.273 },
					at = { 0, 0, -0.1 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Hold3",
					size = { 0.16, 0.273, 0.273 },
					at = { 0, 0, -0.32 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Collar",
					size = { 0.18, 0.357, 0.357 },
					at = { 0, 0, -0.78 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Back",
					size = { 0.16, 0.504, 0.504 },
					at = { 0, 0, -0.88 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Head",
					size = { 0.58, 0.63, 0.63 },
					at = { 0, 0, -1.24 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Nose",
					size = { 0.567, 0.567, 0.567 },
					at = { 0, 0, -1.5 },
					shape = "Ball",
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Spike1A",
					size = { 0.22, 0.2, 0.2 },
					at = { 0.395, 0, -1.24 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Spike1B",
					size = { 0.2, 0.09, 0.09 },
					at = { 0.595, 0, -1.24 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Spike2A",
					size = { 0.22, 0.2, 0.2 },
					at = { -0.395, 0, -1.24 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Spike2B",
					size = { 0.2, 0.09, 0.09 },
					at = { -0.595, 0, -1.24 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Spike3A",
					size = { 0.2, 0.22, 0.2 },
					at = { 0, 0.395, -1.24 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Spike3B",
					size = { 0.09, 0.2, 0.09 },
					at = { 0, 0.595, -1.24 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Spike4A",
					size = { 0.2, 0.22, 0.2 },
					at = { 0, -0.395, -1.24 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Spike4B",
					size = { 0.09, 0.2, 0.09 },
					at = { 0, -0.595, -1.24 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Tip1",
					size = { 0.2, 0.2, 0.26 },
					at = { 0, 0, -1.74 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Tip2",
					size = { 0.09, 0.09, 0.24 },
					at = { 0, 0, -1.98 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
			},
		},
	},
	{
		id = "scythe",
		category = "primary",
		cost = 6,
		name = "Faux",
		summary = "Arc de mêlée large, touche plusieurs ennemis",
		-- Elle se sert de la propagation, qui existait deja pour la Peste : le
		-- coup repercute une part de ses degats sur les ennemis proches de la
		-- cible. A un contre un elle ne vaut pas la masse d'armes, et c'est
		-- exactement ce qu'on veut d'une arme de nombre.
		scale = { attackDamage = 1.5, attackCooldownSeconds = 1.2, attackRangeStuds = 1.3 },
		offset = { spreadRatio = 0.45, spreadRadiusStuds = 9 },
		look = {
			grip = { 0, -0.85, -0.9 },
			swing = "slash",
			voice = "blade",
			pieces = {
				{
					name = "Shaft",
					size = { 4.6, 0.18, 0.18 },
					at = { 0, 0, -1.9 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Butt",
					size = { 0.14, 0.252, 0.252 },
					at = { 0, 0, 0.38 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Hold1",
					size = { 0.16, 0.234, 0.234 },
					at = { 0, 0, 0.1 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Hold2",
					size = { 0.16, 0.234, 0.234 },
					at = { 0, 0, -0.9 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Hold3",
					size = { 0.16, 0.234, 0.234 },
					at = { 0, 0, -2 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Ferrule",
					size = { 0.36, 0.324, 0.324 },
					at = { 0, 0, -3.9 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Blade1",
					size = { 0.09, 0.34, 0.616 },
					at = { 0, 0.0486, -4.3557 },
					tipUp = 10,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge1",
					size = { 0.05, 0.1156, 0.616 },
					at = { 0, 0.1893, -4.3309 },
					tipUp = 10,
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Blade2",
					size = { 0.09, 0.3, 0.616 },
					at = { 0, 0.2156, -4.8853 },
					tipUp = 25,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge2",
					size = { 0.05, 0.102, 0.616 },
					at = { 0, 0.3298, -4.832 },
					tipUp = 25,
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Blade3",
					size = { 0.09, 0.26, 0.616 },
					at = { 0, 0.5139, -5.3535 },
					tipUp = 40,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge3",
					size = { 0.05, 0.0884, 0.616 },
					at = { 0, 0.5975, -5.2833 },
					tipUp = 40,
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Blade4",
					size = { 0.09, 0.22, 0.616 },
					at = { 0, 0.9232, -5.7286 },
					tipUp = 55,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge4",
					size = { 0.05, 0.0748, 0.616 },
					at = { 0, 0.9762, -5.6529 },
					tipUp = 55,
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Blade5",
					size = { 0.09, 0.18, 0.616 },
					at = { 0, 1.4157, -5.985 },
					tipUp = 70,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge5",
					size = { 0.05, 0.0612, 0.616 },
					at = { 0, 1.4416, -5.9139 },
					tipUp = 70,
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Blade6",
					size = { 0.09, 0.14, 0.616 },
					at = { 0, 1.9578, -6.1051 },
					tipUp = 85,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge6",
					size = { 0.05, 0.0476, 0.616 },
					at = { 0, 1.9629, -6.0466 },
					tipUp = 85,
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
			},
		},
	},
	{
		id = "heavyRevolver",
		category = "primary",
		cost = 6,
		name = "Revolver lourd",
		summary = "Gros dégâts par balle, six coups par manche",
		scale = { attackDamage = 2.2, attackCooldownSeconds = 1.55, attackRangeStuds = 2.3 },
		shotsPerRound = 6,
		look = {
			grip = { 0, -0.7, -0.6 },
			swing = "recoil",
			voice = "gun",
			pieces = {
				{
					name = "Hold",
					size = { 0.19, 0.5, 0.3 },
					at = { 0, -0.3, 0.06 },
					tipUp = 18,
					color = PALETTE.wood,
					material = "Plastic",
				},
				{
					name = "Palm",
					size = { 0.235, 0.34, 0.24 },
					at = { 0, -0.32, 0.07 },
					tipUp = 18,
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "TriggerGuard",
					size = { 0.09, 0.14, 0.34 },
					at = { 0, -0.21, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "GuardFront",
					size = { 0.09, 0.14, 0.09 },
					at = { 0, -0.14, -0.42 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Trigger",
					size = { 0.06, 0.15, 0.06 },
					at = { 0, -0.14, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Frame",
					size = { 0.2, 0.34, 0.5 },
					at = { 0, 0.06, -0.1 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Shroud",
					size = { 0.2, 0.28, 0.24 },
					at = { 0, 0.08, -0.9 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Topstrap",
					size = { 0.18, 0.09, 0.84 },
					at = { 0, 0.26, -0.4 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Hammer",
					size = { 0.09, 0.22, 0.14 },
					at = { 0, 0.26, 0.17 },
					tipUp = -30,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Cylinder",
					size = { 0.48, 0.46, 0.46 },
					at = { 0, 0.06, -0.58 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Crane",
					size = { 0.1, 0.5, 0.5 },
					at = { 0, 0.06, -0.34 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Ejector",
					size = { 0.945, 0.12, 0.12 },
					at = { 0, -0.1, -1.625 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Flute1",
					size = { 0.1, 0.1, 0.34 },
					at = { 0, 0.25, -0.58 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Flute2",
					size = { 0.1, 0.1, 0.34 },
					at = { 0.1645, 0.155, -0.58 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Flute3",
					size = { 0.1, 0.1, 0.34 },
					at = { 0.1645, -0.035, -0.58 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Flute4",
					size = { 0.1, 0.1, 0.34 },
					at = { 0, -0.13, -0.58 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Flute5",
					size = { 0.1, 0.1, 0.34 },
					at = { -0.1645, -0.035, -0.58 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Flute6",
					size = { 0.1, 0.1, 0.34 },
					at = { -0.1645, 0.155, -0.58 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Barrel",
					size = { 1.46, 0.18, 0.18 },
					at = { 0, 0.08, -1.57 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "BarrelMuzzle",
					size = { 0.3, 0.252, 0.252 },
					at = { 0, 0.08, -2.2 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "BarrelBore",
					size = { 0.12, 0.099, 0.099 },
					at = { 0, 0.08, -2.32 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "FrontSight",
					size = { 0.07, 0.12, 0.07 },
					at = { 0, 0.24, -2.1 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "FrontGuard",
					size = { 0.15, 0.096, 0.06 },
					at = { 0, 0.26, -2.1 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RearSight",
					size = { 0.17, 0.084, 0.08 },
					at = { 0, 0.222, -0.2 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RearNotch",
					size = { 0.05, 0.084, 0.09 },
					at = { 0, 0.242, -0.2 },
					color = PALETTE.shade,
					material = "Metal",
				},
			},
		},
	},
	{
		id = "heavyRifle",
		category = "primary",
		cost = 7,
		name = "Fusil lourd",
		summary = "Dégâts forts à toute distance, très lent",
		-- L'arme de l'assemblage du tireur de la fiche : sept points, et il
		-- reste cinq points pour une armure legere, une trousse et un fumigene.
		scale = { attackDamage = 2.6, attackCooldownSeconds = 1.8, attackRangeStuds = 3 },
		look = {
			grip = { 0, -0.7, -1.5 },
			swing = "recoil",
			voice = "gun",
			pieces = {
				{
					name = "Hold",
					size = { 0.19, 0.5, 0.3 },
					at = { 0, -0.3, 0.06 },
					tipUp = 20,
					color = PALETTE.gun,
					material = "Plastic",
				},
				{
					name = "Palm",
					size = { 0.235, 0.34, 0.24 },
					at = { 0, -0.32, 0.07 },
					tipUp = 20,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "TriggerGuard",
					size = { 0.09, 0.14, 0.34 },
					at = { 0, -0.21, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "GuardFront",
					size = { 0.09, 0.14, 0.09 },
					at = { 0, -0.14, -0.42 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Trigger",
					size = { 0.06, 0.15, 0.06 },
					at = { 0, -0.14, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Receiver",
					size = { 0.26, 0.4, 1.45 },
					at = { 0, 0.05, -0.465 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Ejection",
					size = { 0.27, 0.16, 0.34 },
					at = { 0.01, 0.12, -0.79 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Charger",
					size = { 0.36, 0.09, 0.09 },
					at = { 0.16, 0.12, -0.79 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Wrist",
					size = { 0.24, 0.3, 0.6 },
					at = { 0, -0.02, 0.5 },
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Stock",
					size = { 0.24, 0.44, 1.15 },
					at = { 0, -0.06, 1.355 },
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Comb",
					size = { 0.22, 0.12, 0.759 },
					at = { 0, 0.2, 1.2795 },
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Butt",
					size = { 0.26, 0.52, 0.1 },
					at = { 0, -0.08, 1.99 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Handguard",
					size = { 0.25, 0.26, 0.85 },
					at = { 0, 0.02, -1.615 },
					color = PALETTE.gun,
					material = "Plastic",
				},
				{
					name = "Vent1",
					size = { 0.26, 0.07, 0.07 },
					at = { 0, 0.02, -1.37 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Vent2",
					size = { 0.26, 0.07, 0.07 },
					at = { 0, 0.02, -1.61 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Vent3",
					size = { 0.26, 0.07, 0.07 },
					at = { 0, 0.02, -1.85 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Barrel",
					size = { 2.2, 0.2, 0.2 },
					at = { 0, 0.08, -3.04 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "BarrelMuzzle",
					size = { 0.3, 0.28, 0.28 },
					at = { 0, 0.08, -4.04 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "BarrelBore",
					size = { 0.12, 0.11, 0.11 },
					at = { 0, 0.08, -4.16 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Magazine",
					size = { 0.19, 0.42, 0.42 },
					at = { 0, -0.35, -0.67 },
					tipUp = -8,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.1,
				},
				{
					name = "MagLip",
					size = { 0.21, 0.1, 0.441 },
					at = { 0, -0.16, -0.67 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Leg1",
					size = { 0.07, 0.56, 0.07 },
					at = { -0.22, -0.3, -1.84 },
					roll = -18,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Leg2",
					size = { 0.07, 0.56, 0.07 },
					at = { 0.22, -0.3, -1.84 },
					roll = 18,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "ScopeTube",
					size = { 1.3, 0.26, 0.26 },
					at = { 0, 0.4, -0.44 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "ScopeBell",
					size = { 0.3, 0.34, 0.34 },
					at = { 0, 0.4, -1.03 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Lens",
					size = { 0.06, 0.28, 0.28 },
					at = { 0, 0.4, -1.15 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.glass,
					material = "Glass",
					reflectance = 0.5,
				},
				{
					name = "Ring1",
					size = { 0.12, 0.3, 0.3 },
					at = { 0, 0.4, -0.09 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Ring2",
					size = { 0.12, 0.3, 0.3 },
					at = { 0, 0.4, -0.79 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Turret",
					size = { 0.16, 0.16, 0.16 },
					at = { 0.13, 0.46, -0.44 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
			},
		},
	},
	{
		id = "sniperRifle",
		category = "primary",
		cost = 7,
		name = "Fusil de précision",
		summary = "Très fort au loin, ne tire pas au contact",
		-- LE SEUL OBJET DU CATALOGUE AVEC UNE PORTEE MINIMALE. En dessous, il ne
		-- tire pas du tout et c'est l'arme secondaire qui sort — donc il demande
		-- d'en porter une, et sept plus deux font neuf des douze points. C'est
		-- l'assemblage le plus contraint du jeu, et c'est voulu.
		scale = { attackDamage = 3.6, attackCooldownSeconds = 2.4, attackRangeStuds = 4.5 },
		minRangeStuds = 18,
		look = {
			grip = { 0, -0.7, 0 },
			swing = "recoil",
			voice = "gun",
			pieces = {
				{
					name = "Stock",
					size = { 0.24, 0.42, 1.1 },
					at = { 0, -0.04, 1.02 },
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Wrist",
					size = { 0.24, 0.3, 0.6 },
					at = { 0, 0, 0.32 },
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Butt",
					size = { 0.26, 0.5, 0.1 },
					at = { 0, -0.06, 1.6 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Comb",
					size = { 0.22, 0.12, 0.72 },
					at = { 0, 0.22, 0.86 },
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Receiver",
					size = { 0.26, 0.4, 1.5 },
					at = { 0, 0.04, -0.5 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Bolt",
					size = { 0.4, 0.1, 0.1 },
					at = { 0.17, 0.1, -0.3 },
					shape = "Cylinder",
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Magazine",
					size = { 0.19, 0.36, 0.44 },
					at = { 0, -0.3, -0.62 },
					color = PALETTE.iron,
					material = "Metal",
				},
				{
					name = "Hold",
					size = { 0.19, 0.5, 0.3 },
					at = { 0, -0.3, 0.06 },
					tipUp = 20,
					color = PALETTE.gun,
					material = "Plastic",
				},
				{
					name = "TriggerGuard",
					size = { 0.09, 0.15, 0.32 },
					at = { 0, -0.22, -0.3 },
					color = PALETTE.iron,
					material = "Metal",
				},
				{
					name = "Handguard",
					size = { 0.24, 0.24, 1.1 },
					at = { 0, 0.02, -1.55 },
					color = PALETTE.gun,
					material = "Plastic",
				},
				{
					name = "Barrel",
					size = { 2.5, 0.15, 0.15 },
					at = { 0, 0.06, -2.5 },
					tipLeft = 90,
					shape = "Cylinder",
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Muzzle",
					size = { 0.32, 0.21, 0.21 },
					at = { 0, 0.06, -3.8 },
					tipLeft = 90,
					shape = "Cylinder",
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "ScopeTube",
					size = { 1.3, 0.21, 0.21 },
					at = { 0, 0.38, -0.6 },
					tipLeft = 90,
					shape = "Cylinder",
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.18,
				},
				{
					name = "LensFront",
					size = { 0.06, 0.19, 0.19 },
					at = { 0, 0.38, -1.26 },
					tipLeft = 90,
					shape = "Cylinder",
					color = PALETTE.glass,
					material = "Glass",
					reflectance = 0.5,
				},
				{
					name = "LensRear",
					size = { 0.06, 0.19, 0.19 },
					at = { 0, 0.38, 0.06 },
					tipLeft = 90,
					shape = "Cylinder",
					color = PALETTE.glass,
					material = "Glass",
					reflectance = 0.5,
				},
				{
					name = "MountFront",
					size = { 0.11, 0.18, 0.13 },
					at = { 0, 0.26, -1.0 },
					color = PALETTE.iron,
					material = "Metal",
				},
				{
					name = "MountRear",
					size = { 0.11, 0.18, 0.13 },
					at = { 0, 0.26, -0.2 },
					color = PALETTE.iron,
					material = "Metal",
				},
				{
					name = "BipodLeft",
					size = { 0.06, 0.54, 0.06 },
					at = { -0.12, -0.26, -2.8 },
					roll = 15,
					color = PALETTE.iron,
					material = "Metal",
				},
				{
					name = "BipodRight",
					size = { 0.06, 0.54, 0.06 },
					at = { 0.12, -0.26, -2.8 },
					roll = -15,
					color = PALETTE.iron,
					material = "Metal",
				},
			},
		},
	},
	{
		id = "grenadeLauncher",
		category = "primary",
		cost = 7,
		name = "Lance-grenades",
		summary = "Dégâts de zone, se blesse soi-même de près",
		-- Le coup explose autour de la cible, et l'explosion ne fait pas le tri :
		-- tirer sur quelqu'un de colle a soi, c'est se tirer dessus. Sa
		-- faiblesse n'est pas decorative, elle est dans le meme calcul que ses
		-- degats.
		scale = { attackDamage = 1.9, attackCooldownSeconds = 1.7, attackRangeStuds = 2.4 },
		weaponBlast = { radiusStuds = 11, selfRatio = 0.6 },
		look = {
			grip = { 0, -0.7, -1.1 },
			swing = "recoil",
			voice = "gun",
			pieces = {
				{
					name = "Hold",
					size = { 0.19, 0.5, 0.3 },
					at = { 0, -0.3, 0.06 },
					tipUp = 20,
					color = PALETTE.gun,
					material = "Plastic",
				},
				{
					name = "Palm",
					size = { 0.235, 0.34, 0.24 },
					at = { 0, -0.32, 0.07 },
					tipUp = 20,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "TriggerGuard",
					size = { 0.09, 0.14, 0.34 },
					at = { 0, -0.21, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "GuardFront",
					size = { 0.09, 0.14, 0.09 },
					at = { 0, -0.14, -0.42 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Trigger",
					size = { 0.06, 0.15, 0.06 },
					at = { 0, -0.14, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Receiver",
					size = { 0.3, 0.36, 0.7 },
					at = { 0, 0.04, -0.1 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Wrist",
					size = { 0.24, 0.3, 0.5 },
					at = { 0, -0.02, 0.46 },
					color = PALETTE.gun,
					material = "Plastic",
				},
				{
					name = "Plate",
					size = { 0.24, 0.44, 0.1 },
					at = { 0, -0.04, 0.74 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Tube",
					size = { 1.5, 0.44, 0.44 },
					at = { 0, 0.18, -1.1 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.olive,
					material = "Metal",
					reflectance = 0.1,
				},
				{
					name = "Mouth",
					size = { 0.22, 0.5368, 0.5368 },
					at = { 0, 0.18, -1.92 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Bore",
					size = { 0.14, 0.3256, 0.3256 },
					at = { 0, 0.18, -2.01 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Latch",
					size = { 0.34, 0.18, 0.22 },
					at = { 0, 0.18, -0.3 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Foregrip",
					size = { 0.17, 0.4, 0.24 },
					at = { 0, -0.16, -1.4 },
					tipUp = 10,
					color = PALETTE.gun,
					material = "Plastic",
				},
				{
					name = "Ladder",
					size = { 0.1, 0.4, 0.07 },
					at = { 0, 0.44, -0.2 },
					tipUp = -14,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Band1",
					size = { 0.1, 0.4752, 0.4752 },
					at = { 0, 0.18, -0.7 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Band2",
					size = { 0.1, 0.4752, 0.4752 },
					at = { 0, 0.18, -1.2 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Band3",
					size = { 0.1, 0.4752, 0.4752 },
					at = { 0, 0.18, -1.7 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.shade,
					material = "Metal",
				},
			},
		},
	},
	{
		id = "katana",
		category = "primary",
		cost = 7,
		name = "Katana",
		summary = "Mêlée très rapide et très forte, aucune portée",
		-- Les degats par seconde les plus eleves du catalogue, pour quatre studs
		-- de portee sur un Vampire. C'est l'arme qui demande d'etre dans le
		-- visage de l'adversaire en permanence.
		scale = { attackDamage = 1.5, attackCooldownSeconds = 0.75, attackRangeStuds = 0.6 },
		look = {
			grip = { 0, -0.85, -0.1 },
			swing = "slash",
			voice = "blade",
			pieces = {
				{
					name = "Handle",
					size = { 0.17, 0.3, 1.15 },
					at = { 0, 0, 0.1 },
					color = PALETTE.cord,
					material = "Fabric",
				},
				{
					name = "Wrap1",
					size = { 0.2, 0.33, 0.1 },
					at = { 0, 0, -0.37 },
					tipUp = 32,
					color = PALETTE.wrap,
					material = "Fabric",
				},
				{
					name = "Wrap2",
					size = { 0.2, 0.33, 0.1 },
					at = { 0, 0, -0.13 },
					tipUp = 32,
					color = PALETTE.wrap,
					material = "Fabric",
				},
				{
					name = "Wrap3",
					size = { 0.2, 0.33, 0.1 },
					at = { 0, 0, 0.11 },
					tipUp = 32,
					color = PALETTE.wrap,
					material = "Fabric",
				},
				{
					name = "Wrap4",
					size = { 0.2, 0.33, 0.1 },
					at = { 0, 0, 0.35 },
					tipUp = 32,
					color = PALETTE.wrap,
					material = "Fabric",
				},
				{
					name = "Wrap5",
					size = { 0.2, 0.33, 0.1 },
					at = { 0, 0, 0.59 },
					tipUp = 32,
					color = PALETTE.wrap,
					material = "Fabric",
				},
				{
					name = "Pommel",
					size = { 0.2, 0.33, 0.12 },
					at = { 0, 0, 0.73 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.1,
				},
				{
					name = "Guard",
					size = { 0.07, 0.78, 0.78 },
					at = { 0, 0, -0.55 },
					tipLeft = 90,
					shape = "Cylinder",
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.08,
				},
				{
					name = "Collar",
					size = { 0.14, 0.33, 0.2 },
					at = { 0, 0, -0.71 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Blade1",
					size = { 0.1, 0.34, 0.53 },
					at = { 0, 0.0, -1.07 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.22,
				},
				{
					name = "Blade2",
					size = { 0.1, 0.32, 0.53 },
					at = { 0, -0.01, -1.59 },
					tipUp = -2.1,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.22,
				},
				{
					name = "Blade3",
					size = { 0.1, 0.3, 0.53 },
					at = { 0, -0.038, -2.11 },
					tipUp = -4.2,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.22,
				},
				{
					name = "Blade4",
					size = { 0.1, 0.28, 0.53 },
					at = { 0, -0.086, -2.63 },
					tipUp = -6.3,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.22,
				},
				{
					name = "Blade5",
					size = { 0.1, 0.26, 0.53 },
					at = { 0, -0.152, -3.15 },
					tipUp = -8.4,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.22,
				},
				{
					name = "Edge1",
					size = { 0.105, 0.07, 0.532 },
					at = { 0, -0.14, -1.07 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Edge2",
					size = { 0.105, 0.07, 0.532 },
					at = { 0, -0.139, -1.59 },
					tipUp = -2.1,
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Edge3",
					size = { 0.105, 0.07, 0.532 },
					at = { 0, -0.158, -2.11 },
					tipUp = -4.2,
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Edge4",
					size = { 0.105, 0.07, 0.532 },
					at = { 0, -0.195, -2.63 },
					tipUp = -6.3,
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Edge5",
					size = { 0.105, 0.07, 0.532 },
					at = { 0, -0.251, -3.15 },
					tipUp = -8.4,
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Tip",
					size = { 0.1, 0.26, 0.44 },
					at = { 0, -0.23, -3.62 },
					tipUp = -10.5,
					roll = 180,
					shape = "Wedge",
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.22,
				},
			},
		},
	},
	{
		id = "machineGun",
		category = "primary",
		cost = 7,
		name = "Mitrailleuse",
		summary = "Cadence très élevée, cloue presque sur place pendant le tir",
		-- ELLE RALENTIT AU PLANCHER, ELLE N'IMMOBILISE PAS, et la nuance est
		-- une decision. Une immobilisation complete existe deja dans le jeu —
		-- c'est l'etourdissement, et la grenade aveuglante le fait payer trois
		-- points. En donner une deuxieme version a une arme aurait fait deux
		-- mecaniques pour une seule idee, et la premiere a un plancher que la
		-- seconde n'aurait pas eu.
		--
		-- Concretement : a 35 % de sa vitesse, on se decale d'un pas, on ne
		-- rompt pas le combat. Tenir une position devient tres fort, partir
		-- devient cher.
		scale = { attackDamage = 1.06, attackCooldownSeconds = 0.46, attackRangeStuds = 2.1 },
		selfSlowSeconds = 0.45,
		look = {
			grip = { 0, -0.7, -1.4 },
			swing = "recoil",
			voice = "gun",
			pieces = {
				{
					name = "Hold",
					size = { 0.19, 0.5, 0.3 },
					at = { 0, -0.3, 0.06 },
					tipUp = 20,
					color = PALETTE.gun,
					material = "Plastic",
				},
				{
					name = "Palm",
					size = { 0.235, 0.34, 0.24 },
					at = { 0, -0.32, 0.07 },
					tipUp = 20,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "TriggerGuard",
					size = { 0.09, 0.14, 0.34 },
					at = { 0, -0.21, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "GuardFront",
					size = { 0.09, 0.14, 0.09 },
					at = { 0, -0.14, -0.42 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Trigger",
					size = { 0.06, 0.15, 0.06 },
					at = { 0, -0.14, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Receiver",
					size = { 0.26, 0.4, 1.5 },
					at = { 0, 0.05, -0.49 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Ejection",
					size = { 0.27, 0.16, 0.34 },
					at = { 0.01, 0.12, -0.84 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Charger",
					size = { 0.36, 0.09, 0.09 },
					at = { 0.16, 0.12, -0.84 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Wrist",
					size = { 0.24, 0.3, 0.6 },
					at = { 0, -0.02, 0.5 },
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Stock",
					size = { 0.24, 0.44, 1 },
					at = { 0, -0.06, 1.28 },
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Comb",
					size = { 0.22, 0.12, 0.66 },
					at = { 0, 0.2, 1.23 },
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Butt",
					size = { 0.26, 0.52, 0.1 },
					at = { 0, -0.08, 1.84 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Handguard",
					size = { 0.25, 0.26, 0.8 },
					at = { 0, 0.02, -1.64 },
					color = PALETTE.gun,
					material = "Plastic",
				},
				{
					name = "Vent1",
					size = { 0.26, 0.07, 0.07 },
					at = { 0, 0.02, -1.42 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Vent2",
					size = { 0.26, 0.07, 0.07 },
					at = { 0, 0.02, -1.66 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Vent3",
					size = { 0.26, 0.07, 0.07 },
					at = { 0, 0.02, -1.9 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Barrel",
					size = { 2, 0.19, 0.19 },
					at = { 0, 0.08, -2.94 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "BarrelMuzzle",
					size = { 0.3, 0.266, 0.266 },
					at = { 0, 0.08, -3.84 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "BarrelBore",
					size = { 0.12, 0.1045, 0.1045 },
					at = { 0, 0.08, -3.96 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Drum",
					size = { 0.26, 0.62, 0.62 },
					at = { 0, -0.47, -0.74 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "DrumHub",
					size = { 0.3, 0.2108, 0.2108 },
					at = { 0, -0.47, -0.74 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Belt",
					size = { 0.16, 0.12, 0.5 },
					at = { 0.06, -0.14, -0.99 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Leg1",
					size = { 0.07, 0.56, 0.07 },
					at = { -0.22, -0.3, -1.84 },
					roll = -18,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Leg2",
					size = { 0.07, 0.56, 0.07 },
					at = { 0.22, -0.3, -1.84 },
					roll = 18,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "FrontSight",
					size = { 0.07, 0.14, 0.07 },
					at = { 0, 0.25, -1.9 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "FrontGuard",
					size = { 0.15, 0.112, 0.06 },
					at = { 0, 0.27, -1.9 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RearSight",
					size = { 0.17, 0.098, 0.08 },
					at = { 0, 0.229, -0.74 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RearNotch",
					size = { 0.05, 0.098, 0.09 },
					at = { 0, 0.249, -0.74 },
					color = PALETTE.shade,
					material = "Metal",
				},
			},
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
			grip = { 0, -0.8, -0.1 },
			swing = "slash",
			voice = "blade",
			pieces = {
				{
					name = "Handle",
					size = { 0.2, 0.21, 0.45 },
					at = { 0, 0, 0.175 },
					color = PALETTE.cord,
					material = "Leather",
				},
				{
					name = "Wrap1",
					size = { 0.232, 0.24, 0.07 },
					at = { 0, 0, 0.105 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Wrap2",
					size = { 0.232, 0.24, 0.07 },
					at = { 0, 0, 0.215 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Wrap3",
					size = { 0.232, 0.24, 0.07 },
					at = { 0, 0, 0.325 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Pommel",
					size = { 0.23, 0.23, 0.23 },
					at = { 0, 0, 0.5 },
					shape = "Ball",
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Guard",
					size = { 0.646, 0.05, 0.17 },
					at = { 0, 0, -0.13 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Quillon1",
					size = { 0.065, 0.0625, 0.24 },
					at = { -0.323, 0, -0.13 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Quillon2",
					size = { 0.065, 0.0625, 0.24 },
					at = { 0.323, 0, -0.13 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Collar",
					size = { 0.26, 0.26, 0.16 },
					at = { 0, 0, -0.27 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Blade1",
					size = { 0.1, 0.38, 0.2433 },
					at = { 0, 0, -0.4667 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge1",
					size = { 0.104, 0.076, 0.2453 },
					at = { 0, -0.152, -0.4667 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Blade2",
					size = { 0.1, 0.3597, 0.2433 },
					at = { 0, 0, -0.7 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge2",
					size = { 0.104, 0.0719, 0.2453 },
					at = { 0, -0.1439, -0.7 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Blade3",
					size = { 0.1, 0.3395, 0.2433 },
					at = { 0, 0, -0.9333 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge3",
					size = { 0.104, 0.0679, 0.2453 },
					at = { 0, -0.1358, -0.9333 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Tip",
					size = { 0.1, 0.1915, 0.4 },
					at = { 0, -0.0575, -1.25 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
			},
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
			grip = { 0, -0.7, -0.7 },
			swing = "recoil",
			voice = "gun",
			pieces = {
				{
					name = "Hold",
					size = { 0.19, 0.5, 0.3 },
					at = { 0, -0.3, 0.06 },
					tipUp = 20,
					color = PALETTE.gun,
					material = "Plastic",
				},
				{
					name = "Palm",
					size = { 0.235, 0.34, 0.24 },
					at = { 0, -0.32, 0.07 },
					tipUp = 20,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "TriggerGuard",
					size = { 0.09, 0.14, 0.34 },
					at = { 0, -0.21, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "GuardFront",
					size = { 0.09, 0.14, 0.09 },
					at = { 0, -0.14, -0.42 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Trigger",
					size = { 0.06, 0.15, 0.06 },
					at = { 0, -0.14, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Receiver",
					size = { 0.26, 0.4, 0.9 },
					at = { 0, 0.05, -0.19 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Ejection",
					size = { 0.27, 0.16, 0.34 },
					at = { 0.01, 0.12, -0.24 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Charger",
					size = { 0.36, 0.09, 0.09 },
					at = { 0.16, 0.12, -0.24 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Cap",
					size = { 0.24, 0.4, 0.14 },
					at = { 0, 0, 0.34 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Handguard",
					size = { 0.25, 0.26, 0.34 },
					at = { 0, 0.02, -0.81 },
					color = PALETTE.gun,
					material = "Plastic",
				},
				{
					name = "Vent1",
					size = { 0.26, 0.07, 0.07 },
					at = { 0, 0.02, -0.82 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Vent2",
					size = { 0.26, 0.07, 0.07 },
					at = { 0, 0.02, -1.06 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Vent3",
					size = { 0.26, 0.07, 0.07 },
					at = { 0, 0.02, -1.3 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Barrel",
					size = { 0.8, 0.12, 0.12 },
					at = { 0, 0.08, -1.28 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "BarrelMuzzle",
					size = { 0.3, 0.168, 0.168 },
					at = { 0, 0.08, -1.58 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "BarrelBore",
					size = { 0.12, 0.066, 0.066 },
					at = { 0, 0.08, -1.7 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Magazine",
					size = { 0.19, 0.66, 0.3 },
					at = { 0, -0.47, -0.12 },
					tipUp = -8,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.1,
				},
				{
					name = "MagLip",
					size = { 0.21, 0.1, 0.315 },
					at = { 0, -0.16, -0.12 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "FrontSight",
					size = { 0.07, 0.14, 0.07 },
					at = { 0, 0.25, -0.84 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "FrontGuard",
					size = { 0.15, 0.112, 0.06 },
					at = { 0, 0.27, -0.84 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RearSight",
					size = { 0.17, 0.098, 0.08 },
					at = { 0, 0.229, -0.14 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RearNotch",
					size = { 0.05, 0.098, 0.09 },
					at = { 0, 0.249, -0.14 },
					color = PALETTE.shade,
					material = "Metal",
				},
			},
		},
	},

	{
		id = "pocketPistol",
		category = "secondary",
		cost = 2,
		name = "Pistolet de poche",
		summary = "Deux balles par manche, puis plus rien",
		-- Deux coups, et il devient un objet mort pour le reste de la manche.
		-- C'est le pari a deux points : de quoi finir un adversaire a dix studs,
		-- a condition de ne pas les avoir gaspilles.
		scale = { attackDamage = 1.1, attackCooldownSeconds = 1.1, attackRangeStuds = 2 },
		shotsPerRound = 2,
		look = {
			grip = { 0, -0.6, -0.4 },
			swing = "recoil",
			voice = "gun",
			pieces = {
				{
					name = "Hold",
					size = { 0.19, 0.5, 0.3 },
					at = { 0, -0.3, 0.06 },
					tipUp = 16,
					color = PALETTE.gun,
					material = "Plastic",
				},
				{
					name = "Palm",
					size = { 0.235, 0.34, 0.24 },
					at = { 0, -0.32, 0.07 },
					tipUp = 16,
					color = PALETTE.cord,
					material = "Leather",
				},
				{
					name = "TriggerGuard",
					size = { 0.09, 0.14, 0.34 },
					at = { 0, -0.21, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "GuardFront",
					size = { 0.09, 0.14, 0.09 },
					at = { 0, -0.14, -0.42 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Trigger",
					size = { 0.06, 0.15, 0.06 },
					at = { 0, -0.14, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Frame",
					size = { 0.2, 0.22, 0.86 },
					at = { 0, 0, -0.18 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Slide",
					size = { 0.22, 0.28, 0.72 },
					at = { 0, 0.22, -0.62 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Breech",
					size = { 0.23, 0.3, 0.26 },
					at = { 0, 0.21, -0.1 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Serration1",
					size = { 0.235, 0.22, 0.05 },
					at = { 0, 0.22, -0.16 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Serration2",
					size = { 0.235, 0.22, 0.05 },
					at = { 0, 0.22, -0.26 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Serration3",
					size = { 0.235, 0.22, 0.05 },
					at = { 0, 0.22, -0.36 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Baseplate",
					size = { 0.21, 0.07, 0.34 },
					at = { 0, -0.55, 0.14 },
					tipUp = 16,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Bore",
					size = { 0.12, 0.1, 0.1 },
					at = { 0, 0.22, -0.96 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "FrontSight",
					size = { 0.07, 0.1, 0.07 },
					at = { 0, 0.37, -0.84 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "FrontGuard",
					size = { 0.15, 0.08, 0.06 },
					at = { 0, 0.39, -0.84 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RearSight",
					size = { 0.17, 0.07, 0.08 },
					at = { 0, 0.355, -0.14 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RearNotch",
					size = { 0.05, 0.07, 0.09 },
					at = { 0, 0.375, -0.14 },
					color = PALETTE.shade,
					material = "Metal",
				},
			},
		},
	},
	{
		id = "shuriken",
		category = "secondary",
		cost = 2,
		name = "Shuriken",
		summary = "Lancer court, silencieux",
		-- Il ne demande aucune touche : l'arme secondaire sort toute seule quand
		-- la cible est hors de portee de la principale. C'est ce qui fait d'un
		-- objet a deux points la reponse la moins chere au « il recule ».
		scale = { attackDamage = 0.55, attackCooldownSeconds = 0.6, attackRangeStuds = 1.9 },
		look = {
			grip = { 0, -0.5, -0.2 },
			swing = "slash",
			voice = "blade",
			pieces = {
				{
					name = "Core",
					size = { 0.31, 0.07, 0.31 },
					at = { 0, 0, 0 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Hole",
					size = { 0.1, 0.09, 0.1 },
					at = { 0, 0, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Point11",
					size = { 0.21, 0.065, 0.26 },
					at = { 0, 0, -0.22 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Point12",
					size = { 0.13, 0.057, 0.21 },
					at = { 0, 0, -0.41 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Point13",
					size = { 0.06, 0.049, 0.15 },
					at = { 0, 0, -0.56 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Point21",
					size = { 0.21, 0.065, 0.26 },
					at = { 0, 0, 0.22 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Point22",
					size = { 0.13, 0.057, 0.21 },
					at = { 0, 0, 0.41 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Point23",
					size = { 0.06, 0.049, 0.15 },
					at = { 0, 0, 0.56 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Point31",
					size = { 0.26, 0.065, 0.21 },
					at = { -0.22, 0, 0 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Point32",
					size = { 0.21, 0.057, 0.13 },
					at = { -0.41, 0, 0 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Point33",
					size = { 0.15, 0.049, 0.06 },
					at = { -0.56, 0, 0 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Point41",
					size = { 0.26, 0.065, 0.21 },
					at = { 0.22, 0, 0 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Point42",
					size = { 0.21, 0.057, 0.13 },
					at = { 0.41, 0, 0 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Point43",
					size = { 0.15, 0.049, 0.06 },
					at = { 0.56, 0, 0 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
			},
		},
	},
	{
		id = "shortRevolver",
		category = "secondary",
		cost = 3,
		name = "Revolver court",
		summary = "Six coups par manche, dégâts moyens",
		scale = { attackDamage = 1, attackCooldownSeconds = 0.85, attackRangeStuds = 2.2 },
		shotsPerRound = 6,
		look = {
			grip = { 0, -0.6, -0.5 },
			swing = "recoil",
			voice = "gun",
			pieces = {
				{
					name = "Hold",
					size = { 0.19, 0.5, 0.3 },
					at = { 0, -0.3, 0.06 },
					tipUp = 18,
					color = PALETTE.cord,
					material = "Plastic",
				},
				{
					name = "Palm",
					size = { 0.235, 0.34, 0.24 },
					at = { 0, -0.32, 0.07 },
					tipUp = 18,
					color = PALETTE.cord,
					material = "Wood",
				},
				{
					name = "TriggerGuard",
					size = { 0.09, 0.14, 0.34 },
					at = { 0, -0.21, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "GuardFront",
					size = { 0.09, 0.14, 0.09 },
					at = { 0, -0.14, -0.42 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Trigger",
					size = { 0.06, 0.15, 0.06 },
					at = { 0, -0.14, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Frame",
					size = { 0.2, 0.34, 0.5 },
					at = { 0, 0.06, -0.1 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Shroud",
					size = { 0.2, 0.28, 0.24 },
					at = { 0, 0.08, -0.9 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Topstrap",
					size = { 0.18, 0.09, 0.84 },
					at = { 0, 0.26, -0.4 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Hammer",
					size = { 0.09, 0.22, 0.14 },
					at = { 0, 0.26, 0.17 },
					tipUp = -30,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Cylinder",
					size = { 0.48, 0.46, 0.46 },
					at = { 0, 0.06, -0.58 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Crane",
					size = { 0.1, 0.5, 0.5 },
					at = { 0, 0.06, -0.34 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Ejector",
					size = { 0.434, 0.12, 0.12 },
					at = { 0, -0.1, -1.26 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Flute1",
					size = { 0.1, 0.1, 0.34 },
					at = { 0, 0.25, -0.58 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Flute2",
					size = { 0.1, 0.1, 0.34 },
					at = { 0.1645, 0.155, -0.58 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Flute3",
					size = { 0.1, 0.1, 0.34 },
					at = { 0.1645, -0.035, -0.58 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Flute4",
					size = { 0.1, 0.1, 0.34 },
					at = { 0, -0.13, -0.58 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Flute5",
					size = { 0.1, 0.1, 0.34 },
					at = { -0.1645, -0.035, -0.58 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Flute6",
					size = { 0.1, 0.1, 0.34 },
					at = { -0.1645, 0.155, -0.58 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Barrel",
					size = { 0.73, 0.18, 0.18 },
					at = { 0, 0.08, -1.205 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "BarrelMuzzle",
					size = { 0.3, 0.252, 0.252 },
					at = { 0, 0.08, -1.47 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "BarrelBore",
					size = { 0.12, 0.099, 0.099 },
					at = { 0, 0.08, -1.59 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "FrontSight",
					size = { 0.07, 0.12, 0.07 },
					at = { 0, 0.24, -1.37 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "FrontGuard",
					size = { 0.15, 0.096, 0.06 },
					at = { 0, 0.26, -1.37 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RearSight",
					size = { 0.17, 0.084, 0.08 },
					at = { 0, 0.222, -0.2 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RearNotch",
					size = { 0.05, 0.084, 0.09 },
					at = { 0, 0.242, -0.2 },
					color = PALETTE.shade,
					material = "Metal",
				},
			},
		},
	},
	{
		id = "poisonDagger",
		category = "secondary",
		cost = 3,
		name = "Dague empoisonnée",
		summary = "Dégâts continus légers après le coup",
		-- Le poison ne s'empile pas : toucher dix fois ne fait pas dix poisons,
		-- ca rafraichit le meme. Sans cette regle, une arme a trois points
		-- deviendrait la plus forte du catalogue des le deuxieme coup.
		scale = { attackDamage = 0.5, attackCooldownSeconds = 0.55, attackRangeStuds = 0.7 },
		onHit = { kind = "poison", seconds = 5, magnitude = 4 },
		look = {
			grip = { 0, -0.8, -0.1 },
			swing = "slash",
			voice = "blade",
			pieces = {
				{
					name = "Handle",
					size = { 0.2, 0.21, 0.4 },
					at = { 0, 0, 0.15 },
					color = PALETTE.shade,
					material = "Leather",
				},
				{
					name = "Wrap1",
					size = { 0.232, 0.24, 0.07 },
					at = { 0, 0, 0.0967 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Wrap2",
					size = { 0.232, 0.24, 0.07 },
					at = { 0, 0, 0.19 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Wrap3",
					size = { 0.232, 0.24, 0.07 },
					at = { 0, 0, 0.2833 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Pommel",
					size = { 0.23, 0.23, 0.23 },
					at = { 0, 0, 0.45 },
					shape = "Ball",
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Guard",
					size = { 0.51, 0.05, 0.17 },
					at = { 0, 0, -0.13 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Quillon1",
					size = { 0.065, 0.0625, 0.24 },
					at = { -0.255, 0, -0.13 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Quillon2",
					size = { 0.065, 0.0625, 0.24 },
					at = { 0.255, 0, -0.13 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Collar",
					size = { 0.26, 0.26, 0.16 },
					at = { 0, 0, -0.27 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Blade1",
					size = { 0.1, 0.3, 0.1933 },
					at = { 0, 0, -0.4417 },
					color = PALETTE.olive,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge1",
					size = { 0.104, 0.06, 0.1953 },
					at = { 0, -0.12, -0.4417 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Blade2",
					size = { 0.1, 0.284, 0.1933 },
					at = { 0, 0, -0.625 },
					color = PALETTE.olive,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge2",
					size = { 0.104, 0.0568, 0.1953 },
					at = { 0, -0.1136, -0.625 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Blade3",
					size = { 0.1, 0.268, 0.1933 },
					at = { 0, 0, -0.8083 },
					color = PALETTE.olive,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge3",
					size = { 0.104, 0.0536, 0.1953 },
					at = { 0, -0.1072, -0.8083 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Tip",
					size = { 0.1, 0.1512, 0.4 },
					at = { 0, -0.0454, -1.1 },
					color = PALETTE.olive,
					material = "Metal",
					reflectance = 0.35,
				},
			},
		},
	},
	{
		id = "handCrossbow",
		category = "secondary",
		cost = 3,
		name = "Arbalète de poing",
		summary = "Un carreau qui traverse les armures légères",
		-- La deuxieme perforation du catalogue, apres l'arc composite. Les deux
		-- ne s'additionnent pas si on les porte ensemble : on garde la plus
		-- forte, et le calcul vit dans Combat.piercedRatio.
		scale = { attackDamage = 1.2, attackCooldownSeconds = 1.2, attackRangeStuds = 2.4 },
		armorPierceRatio = 0.5,
		look = {
			grip = { 0, -0.6, -0.5 },
			swing = "draw",
			voice = "bow",
			pieces = {
				{
					name = "Tiller",
					size = { 0.2, 0.24, 1.7 },
					at = { 0, 0, -0.35 },
					color = PALETTE.shade,
					material = "Wood",
				},
				{
					name = "Butt",
					size = { 0.24, 0.46, 0.26 },
					at = { 0, -0.08, 0.42 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Comb",
					size = { 0.18, 0.12, 0.7 },
					at = { 0, 0.17, 0.08 },
					color = PALETTE.shade,
					material = "Wood",
				},
				{
					name = "Groove",
					size = { 0.09, 0.08, 1.02 },
					at = { 0, 0.14, -0.54 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Hold",
					size = { 0.17, 0.42, 0.26 },
					at = { 0, -0.26, -0.18 },
					tipUp = 18,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Lever",
					size = { 0.07, 0.3, 0.1 },
					at = { 0, -0.2, -0.04 },
					tipUp = 30,
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Nut",
					size = { 0.24, 0.2, 0.2 },
					at = { 0, 0.1, 0.16 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Bridle",
					size = { 0.26, 0.28, 0.24 },
					at = { 0, 0.02, -0.9 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Stirrup",
					size = { 0.3, 0.3, 0.1 },
					at = { 0, -0.2, -1.32 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Foot",
					size = { 0.1, 0.28, 0.1 },
					at = { 0, -0.1, -1.32 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Lath11",
					size = { 0.2383, 0.16, 0.2 },
					at = { 0.2073, 0.02, -0.8849 },
					tipLeft = -8,
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Lath12",
					size = { 0.2383, 0.14, 0.17 },
					at = { 0.4164, 0.02, -0.8328 },
					tipLeft = -20,
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Lath13",
					size = { 0.2383, 0.12, 0.14 },
					at = { 0.608, 0.02, -0.7352 },
					tipLeft = -34,
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Tip1",
					size = { 0.1, 0.14, 0.14 },
					at = { 0.6978, 0.02, -0.6746 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Lath21",
					size = { 0.2383, 0.16, 0.2 },
					at = { -0.2073, 0.02, -0.8849 },
					tipLeft = 8,
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Lath22",
					size = { 0.2383, 0.14, 0.17 },
					at = { -0.4164, 0.02, -0.8328 },
					tipLeft = 20,
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Lath23",
					size = { 0.2383, 0.12, 0.14 },
					at = { -0.608, 0.02, -0.7352 },
					tipLeft = 34,
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Tip2",
					size = { 0.1, 0.14, 0.14 },
					at = { -0.6978, 0.02, -0.6746 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "String",
					size = { 1.3956, 0.05, 0.05 },
					at = { 0, 0.02, -0.6746 },
					color = PALETTE.cloth,
					material = "SmoothPlastic",
				},
				{
					name = "Bolt",
					size = { 0.07, 0.07, 0.884 },
					at = { 0, 0.19, -0.504 },
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "BoltHead",
					size = { 0.08, 0.08, 0.2 },
					at = { 0, 0.19, -0.8 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
			},
		},
	},
	{
		id = "shortAxe",
		category = "secondary",
		cost = 4,
		name = "Hache courte",
		summary = "Dégâts de mêlée notables",
		-- La secondaire de qui a pris une arme principale a longue portee et se
		-- fait rattraper. Elle frappe presque aussi fort qu'une epee courte.
		scale = { attackDamage = 1.2, attackCooldownSeconds = 0.78, attackRangeStuds = 0.85 },
		look = {
			grip = { 0, -0.8, -0.15 },
			swing = "overhead",
			voice = "blade",
			pieces = {
				{
					name = "Shaft",
					size = { 1.5, 0.14, 0.14 },
					at = { 0, 0, -0.35 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wood,
					material = "Wood",
				},
				{
					name = "Butt",
					size = { 0.14, 0.196, 0.196 },
					at = { 0, 0, 0.38 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Hold1",
					size = { 0.16, 0.182, 0.182 },
					at = { 0, 0, 0.1 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Hold2",
					size = { 0.16, 0.182, 0.182 },
					at = { 0, 0, -0.12 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Hold3",
					size = { 0.16, 0.182, 0.182 },
					at = { 0, 0, -0.34 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Socket",
					size = { 0.46, 0.224, 0.224 },
					at = { 0, 0, -0.74 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Bit1",
					size = { 0.1698, 0.3078, 0.1852 },
					at = { 0, -0.0285, -1.0341 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Bit2",
					size = { 0.1584, 0.437, 0.1852 },
					at = { 0, -0.0855, -1.1823 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Bit3",
					size = { 0.1471, 0.5662, 0.1852 },
					at = { 0, -0.1425, -1.3305 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Bit4",
					size = { 0.1357, 0.6954, 0.1852 },
					at = { 0, -0.1995, -1.4787 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Edge",
					size = { 0.0715, 0.7296, 0.14 },
					at = { 0, -0.2128, -1.5828 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.45,
				},
			},
		},
	},
	{
		id = "sawedOff",
		category = "secondary",
		cost = 4,
		name = "Fusil à canon scié",
		summary = "Un coup dévastateur à bout portant",
		-- Le contraire exact du shuriken : il ne couvre pas le trou du loin, il
		-- couvre celui du tres pres. C'est la secondaire du fusil de precision.
		scale = { attackDamage = 2.5, attackCooldownSeconds = 1.5, attackRangeStuds = 0.6 },
		look = {
			grip = { 0, -0.7, -0.6 },
			swing = "recoil",
			voice = "gun",
			pieces = {
				{
					name = "Hold",
					size = { 0.19, 0.5, 0.3 },
					at = { 0, -0.3, 0.06 },
					tipUp = 20,
					color = PALETTE.gun,
					material = "Plastic",
				},
				{
					name = "Palm",
					size = { 0.235, 0.34, 0.24 },
					at = { 0, -0.32, 0.07 },
					tipUp = 20,
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "TriggerGuard",
					size = { 0.09, 0.14, 0.34 },
					at = { 0, -0.21, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "GuardFront",
					size = { 0.09, 0.14, 0.09 },
					at = { 0, -0.14, -0.42 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Trigger",
					size = { 0.06, 0.15, 0.06 },
					at = { 0, -0.14, -0.26 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Receiver",
					size = { 0.26, 0.4, 0.7 },
					at = { 0, 0.05, -0.09 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Ejection",
					size = { 0.27, 0.16, 0.34 },
					at = { 0.01, 0.12, -0.04 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Charger",
					size = { 0.36, 0.09, 0.09 },
					at = { 0.16, 0.12, -0.04 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Cap",
					size = { 0.24, 0.4, 0.14 },
					at = { 0, 0, 0.34 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Barrel",
					size = { 0.95, 0.2, 0.2 },
					at = { -0.11, 0.08, -0.815 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "BarrelMuzzle",
					size = { 0.3, 0.28, 0.28 },
					at = { -0.11, 0.08, -1.19 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "BarrelBore",
					size = { 0.12, 0.11, 0.11 },
					at = { -0.11, 0.08, -1.31 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Second",
					size = { 0.95, 0.2, 0.2 },
					at = { 0.11, 0.08, -0.815 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "SecondMuzzle",
					size = { 0.3, 0.28, 0.28 },
					at = { 0.11, 0.08, -1.19 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "SecondBore",
					size = { 0.12, 0.11, 0.11 },
					at = { 0.11, 0.08, -1.31 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Rib",
					size = { 0.26, 0.06, 0.765 },
					at = { 0, 0.19, -0.865 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
			},
		},
	},
	{
		id = "dartPistol",
		category = "secondary",
		cost = 4,
		name = "Pistolet à fléchettes",
		summary = "Dégâts faibles, ralentit la cible",
		-- Il ne tue personne : il empeche de partir. Quatre points pour une arme
		-- qui touche a peine, parce que ce qu'on achete est le ralentissement —
		-- et le ralentissement a un plancher, donc deux ne valent pas mieux
		-- qu'un.
		scale = { attackDamage = 0.4, attackCooldownSeconds = 0.7, attackRangeStuds = 2.2 },
		onHit = { kind = "slow", seconds = 2.5, magnitude = 0.65 },
		look = {
			grip = { 0, -0.6, -0.5 },
			swing = "recoil",
			voice = "gun",
			pieces = {
				{
					name = "Hold",
					size = { 0.19, 0.5, 0.3 },
					at = { 0, -0.3, 0.06 },
					tipUp = 16,
					color = PALETTE.olive,
					material = "Plastic",
				},
				{
					name = "Palm",
					size = { 0.235, 0.34, 0.24 },
					at = { 0, -0.32, 0.07 },
					tipUp = 16,
					color = PALETTE.shade,
					material = "Leather",
				},
				{
					name = "TriggerGuard",
					size = { 0.09, 0.14, 0.34 },
					at = { 0, -0.21, -0.26 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "GuardFront",
					size = { 0.09, 0.14, 0.09 },
					at = { 0, -0.14, -0.42 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Trigger",
					size = { 0.06, 0.15, 0.06 },
					at = { 0, -0.14, -0.26 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Frame",
					size = { 0.2, 0.22, 0.86 },
					at = { 0, 0, -0.18 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Slide",
					size = { 0.22, 0.28, 0.95 },
					at = { 0, 0.22, -0.735 },
					color = PALETTE.olive,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Breech",
					size = { 0.23, 0.3, 0.26 },
					at = { 0, 0.21, -0.1 },
					color = PALETTE.olive,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Serration1",
					size = { 0.235, 0.22, 0.05 },
					at = { 0, 0.22, -0.16 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Serration2",
					size = { 0.235, 0.22, 0.05 },
					at = { 0, 0.22, -0.26 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Serration3",
					size = { 0.235, 0.22, 0.05 },
					at = { 0, 0.22, -0.36 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Baseplate",
					size = { 0.21, 0.07, 0.34 },
					at = { 0, -0.55, 0.14 },
					tipUp = 16,
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Bore",
					size = { 0.12, 0.1, 0.1 },
					at = { 0, 0.22, -1.19 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Port1",
					size = { 0.1, 0.07, 0.1 },
					at = { 0, 0.35, -0.91 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Port2",
					size = { 0.1, 0.07, 0.1 },
					at = { 0, 0.35, -0.69 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "FrontSight",
					size = { 0.07, 0.1, 0.07 },
					at = { 0, 0.37, -1.07 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "FrontGuard",
					size = { 0.15, 0.08, 0.06 },
					at = { 0, 0.39, -1.07 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RearSight",
					size = { 0.17, 0.07, 0.08 },
					at = { 0, 0.355, -0.14 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RearNotch",
					size = { 0.05, 0.07, 0.09 },
					at = { 0, 0.375, -0.14 },
					color = PALETTE.shade,
					material = "Metal",
				},
			},
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
		look = {
			worn = { limb = "UpperTorso", at = { 0, 0, 0 }, fit = true },
			pieces = {
				{
					name = "Ring1",
					size = { 1.05, 0.17, 1.24 },
					at = { 0, 0.44, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Ring2",
					size = { 1.08, 0.17, 1.27 },
					at = { 0, 0.28, 0 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Ring3",
					size = { 1.05, 0.17, 1.24 },
					at = { 0, 0.12, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Ring4",
					size = { 1.08, 0.17, 1.27 },
					at = { 0, -0.04, 0 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Ring5",
					size = { 1.05, 0.17, 1.24 },
					at = { 0, -0.2, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Ring6",
					size = { 1.08, 0.17, 1.27 },
					at = { 0, -0.36, 0 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Ring7",
					size = { 1.05, 0.17, 1.24 },
					at = { 0, -0.52, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Hem",
					size = { 1.0815, 0.08, 1.2772 },
					at = { 0, -0.6, 0 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Belt",
					size = { 0.966, 0.2, 1.1408 },
					at = { 0, -0.52, 0 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Buckle",
					size = { 0.22, 0.2, 0.12 },
					at = { 0, -0.52, -0.62 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "RPauldron",
					limb = "RightUpperArm",
					size = { 1.34, 0.4, 1.3 },
					at = { 0, 0.42, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "RPauldronRim",
					limb = "RightUpperArm",
					size = { 1.36, 0.1, 1.32 },
					at = { 0, 0.26, 0 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "LPauldron",
					limb = "LeftUpperArm",
					size = { 1.34, 0.4, 1.3 },
					at = { 0, 0.42, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "LPauldronRim",
					limb = "LeftUpperArm",
					size = { 1.36, 0.1, 1.32 },
					at = { 0, 0.26, 0 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
			},
		},
	},
	{
		id = "heavyArmor",
		category = "armor",
		cost = 5,
		name = "Armure lourde",
		summary = "Très forte réduction, grosse perte de vitesse",
		offset = { damageTakenRatio = -0.28 },
		scale = { walkSpeed = 0.78 },
		look = {
			worn = { limb = "UpperTorso", at = { 0, 0, 0 }, fit = true },
			pieces = {
				{
					name = "Cuirass",
					size = { 1.09, 0.72, 1.32 },
					at = { 0, 0.11, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.32,
				},
				{
					name = "Waist",
					size = { 0.9592, 0.26, 1.1616 },
					at = { 0, -0.3, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.32,
				},
				{
					name = "Placket",
					size = { 0.16, 0.76, 1.3728 },
					at = { 0, 0.1, 0 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.42,
				},
				{
					name = "ChestRim",
					size = { 1.1009, 0.09, 1.3332 },
					at = { 0, 0.43, 0 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.42,
				},
				{
					name = "Collar",
					size = { 0.7848, 0.2, 1.1352 },
					at = { 0, 0.52, 0 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Belt",
					size = { 1.0028, 0.2, 1.2144 },
					at = { 0, -0.52, 0 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Buckle",
					size = { 0.22, 0.2, 0.12 },
					at = { 0, -0.52, -0.66 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Tasset1",
					limb = "LowerTorso",
					size = { 1.04, 0.5, 1.2 },
					at = { 0, -0.3, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.32,
				},
				{
					name = "Tasset2",
					limb = "LowerTorso",
					size = { 1, 0.5, 1.15 },
					at = { 0, -0.85, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.32,
				},
				{
					name = "RPauldron",
					limb = "RightUpperArm",
					size = { 1.5, 0.5, 1.44 },
					at = { 0, 0.4, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.32,
				},
				{
					name = "RPauldronTop",
					limb = "RightUpperArm",
					size = { 1.3, 0.22, 1.26 },
					at = { 0, 0.66, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.32,
				},
				{
					name = "RPauldronRim",
					limb = "RightUpperArm",
					size = { 1.54, 0.12, 1.46 },
					at = { 0, 0.18, 0 },
					roll = -12,
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.42,
				},
				{
					name = "RRerebrace",
					limb = "RightUpperArm",
					size = { 1.24, 0.5, 1.22 },
					at = { 0, -0.2, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.32,
				},
				{
					name = "LPauldron",
					limb = "LeftUpperArm",
					size = { 1.5, 0.5, 1.44 },
					at = { 0, 0.4, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.32,
				},
				{
					name = "LPauldronTop",
					limb = "LeftUpperArm",
					size = { 1.3, 0.22, 1.26 },
					at = { 0, 0.66, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.32,
				},
				{
					name = "LPauldronRim",
					limb = "LeftUpperArm",
					size = { 1.54, 0.12, 1.46 },
					at = { 0, 0.18, 0 },
					roll = 12,
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.42,
				},
				{
					name = "LRerebrace",
					limb = "LeftUpperArm",
					size = { 1.24, 0.5, 1.22 },
					at = { 0, -0.2, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.32,
				},
				{
					name = "RCuisse",
					limb = "RightUpperLeg",
					size = { 1.2, 0.86, 1.22 },
					at = { 0, 0.1, -0.06 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.32,
				},
				{
					name = "RCuisseRim",
					limb = "RightUpperLeg",
					size = { 1.22, 0.1, 1.24 },
					at = { 0, -0.34, -0.06 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.42,
				},
				{
					name = "RPoleyn",
					limb = "RightUpperLeg",
					size = { 1.1, 0.34, 1.16 },
					at = { 0, -0.52, -0.12 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.32,
				},
				{
					name = "LCuisse",
					limb = "LeftUpperLeg",
					size = { 1.2, 0.86, 1.22 },
					at = { 0, 0.1, -0.06 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.32,
				},
				{
					name = "LCuisseRim",
					limb = "LeftUpperLeg",
					size = { 1.22, 0.1, 1.24 },
					at = { 0, -0.34, -0.06 },
					color = PALETTE.edge,
					material = "Metal",
					reflectance = 0.42,
				},
				{
					name = "LPoleyn",
					limb = "LeftUpperLeg",
					size = { 1.1, 0.34, 1.16 },
					at = { 0, -0.52, -0.12 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.32,
				},
			},
		},
	},

	{
		id = "paddedVest",
		category = "armor",
		cost = 1,
		name = "Veste rembourrée",
		summary = "Réduction très légère, aucun malus",
		-- L'armure du budget serre : un point, aucune perte de vitesse, et de
		-- quoi survivre a un coup de justesse. Elle existe pour que « pas
		-- d'armure » ne soit jamais le choix par defaut.
		offset = { damageTakenRatio = -0.04 },
		look = {
			worn = { limb = "UpperTorso", at = { 0, 0, 0 }, fit = true },
			pieces = {
				{
					name = "Roll1",
					size = { 1.06, 0.2, 1.26 },
					at = { 0, 0.42, 0 },
					color = PALETTE.wood,
					material = "Fabric",
				},
				{
					name = "Roll2",
					size = { 1.09, 0.2, 1.29 },
					at = { 0, 0.22, 0 },
					color = PALETTE.wrap,
					material = "Fabric",
				},
				{
					name = "Roll3",
					size = { 1.06, 0.2, 1.26 },
					at = { 0, 0.02, 0 },
					color = PALETTE.wood,
					material = "Fabric",
				},
				{
					name = "Roll4",
					size = { 1.09, 0.2, 1.29 },
					at = { 0, -0.18, 0 },
					color = PALETTE.wrap,
					material = "Fabric",
				},
				{
					name = "Roll5",
					size = { 1.06, 0.2, 1.26 },
					at = { 0, -0.38, 0 },
					color = PALETTE.wood,
					material = "Fabric",
				},
				{
					name = "Seam",
					size = { 0.1, 1.04, 1.2852 },
					at = { 0, 0.06, 0 },
					color = PALETTE.wood,
					material = "Fabric",
				},
				{
					name = "Belt",
					size = { 0.9752, 0.2, 1.1592 },
					at = { 0, -0.52, 0 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Buckle",
					size = { 0.22, 0.2, 0.12 },
					at = { 0, -0.52, -0.63 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "RRoll",
					limb = "RightUpperArm",
					size = { 1.36, 0.36, 1.34 },
					at = { 0, 0.44, 0 },
					color = PALETTE.wrap,
					material = "Fabric",
				},
				{
					name = "RRoll2",
					limb = "RightUpperArm",
					size = { 1.32, 0.3, 1.3 },
					at = { 0, 0.16, 0 },
					color = PALETTE.wood,
					material = "Fabric",
				},
				{
					name = "RBand",
					limb = "RightUpperArm",
					size = { 1.28, 0.26, 1.26 },
					at = { 0, -0.1, 0 },
					color = PALETTE.wrap,
					material = "Fabric",
				},
				{
					name = "LRoll",
					limb = "LeftUpperArm",
					size = { 1.36, 0.36, 1.34 },
					at = { 0, 0.44, 0 },
					color = PALETTE.wrap,
					material = "Fabric",
				},
				{
					name = "LRoll2",
					limb = "LeftUpperArm",
					size = { 1.32, 0.3, 1.3 },
					at = { 0, 0.16, 0 },
					color = PALETTE.wood,
					material = "Fabric",
				},
				{
					name = "LBand",
					limb = "LeftUpperArm",
					size = { 1.28, 0.26, 1.26 },
					at = { 0, -0.1, 0 },
					color = PALETTE.wrap,
					material = "Fabric",
				},
			},
		},
	},
	{
		id = "leatherChest",
		category = "armor",
		cost = 2,
		name = "Plastron de cuir",
		summary = "Réduction légère, bien meilleure contre les poisons et le feu",
		-- Meme prix que l'armure legere, et volontairement moins bonne contre
		-- les coups : ce qu'elle achete est ailleurs. C'est la reponse a la
		-- Peste, au Pyromane et a la dague empoisonnee, et c'est la seule.
		offset = { damageTakenRatio = -0.06, dotTakenRatio = -0.35 },
		look = {
			worn = { limb = "UpperTorso", at = { 0, 0, 0 }, fit = true },
			pieces = {
				{
					name = "Front",
					size = { 1.0176, 0.86, 0.6552 },
					at = { 0, 0.06, -0.3276 },
					color = PALETTE.wood,
					material = "Leather",
					reflectance = 0,
				},
				{
					name = "Back",
					size = { 1.0176, 0.86, 0.6552 },
					at = { 0, 0.06, 0.3276 },
					color = PALETTE.wood,
					material = "Leather",
					reflectance = 0,
				},
				{
					name = "Side1",
					size = { 0.53, 0.74, 1.2348 },
					at = { 0.4876, 0.04, 0 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Side2",
					size = { 0.53, 0.74, 1.2348 },
					at = { -0.4876, 0.04, 0 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Strap1",
					size = { 0.24, 0.5, 1.3104 },
					at = { -0.3, 0.4, 0 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Strap2",
					size = { 0.24, 0.5, 1.3104 },
					at = { 0.3, 0.4, 0 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Collar",
					size = { 0.7632, 0.2, 1.0836 },
					at = { 0, 0.52, 0 },
					color = PALETTE.wrap,
					material = "Leather",
					reflectance = 0.08,
				},
				{
					name = "Belt",
					size = { 0.9752, 0.2, 1.1592 },
					at = { 0, -0.52, 0 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Buckle",
					size = { 0.22, 0.2, 0.12 },
					at = { 0, -0.52, -0.63 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Pouch1",
					size = { 0.3, 0.3, 0.26 },
					at = { -0.318, -0.3, -0.6552 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Flap1",
					size = { 0.32, 0.12, 0.22 },
					at = { -0.318, -0.16, -0.6804 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Pouch2",
					size = { 0.3, 0.3, 0.26 },
					at = { 0, -0.3, -0.6552 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Flap2",
					size = { 0.32, 0.12, 0.22 },
					at = { 0, -0.16, -0.6804 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "RPauldron",
					limb = "RightUpperArm",
					size = { 1.34, 0.4, 1.3 },
					at = { 0, 0.42, 0 },
					color = PALETTE.wood,
					material = "Leather",
					reflectance = 0,
				},
				{
					name = "RPauldronRim",
					limb = "RightUpperArm",
					size = { 1.36, 0.1, 1.32 },
					at = { 0, 0.26, 0 },
					color = PALETTE.wrap,
					material = "Leather",
					reflectance = 0.1,
				},
				{
					name = "LPauldron",
					limb = "LeftUpperArm",
					size = { 1.34, 0.4, 1.3 },
					at = { 0, 0.42, 0 },
					color = PALETTE.wood,
					material = "Leather",
					reflectance = 0,
				},
				{
					name = "LPauldronRim",
					limb = "LeftUpperArm",
					size = { 1.36, 0.1, 1.32 },
					at = { 0, 0.26, 0 },
					color = PALETTE.wrap,
					material = "Leather",
					reflectance = 0.1,
				},
			},
		},
	},
	{
		id = "chainmail",
		category = "armor",
		cost = 3,
		name = "Cotte de mailles",
		summary = "Réduction moyenne, légère perte de vitesse",
		offset = { damageTakenRatio = -0.14 },
		scale = { walkSpeed = 0.94 },
		look = {
			worn = { limb = "UpperTorso", at = { 0, 0, 0 }, fit = true },
			pieces = {
				{
					name = "Ring1",
					size = { 1.06, 0.17, 1.26 },
					at = { 0, 0.44, 0 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Ring2",
					size = { 1.09, 0.17, 1.29 },
					at = { 0, 0.28, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Ring3",
					size = { 1.06, 0.17, 1.26 },
					at = { 0, 0.12, 0 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Ring4",
					size = { 1.09, 0.17, 1.29 },
					at = { 0, -0.04, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Ring5",
					size = { 1.06, 0.17, 1.26 },
					at = { 0, -0.2, 0 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Ring6",
					size = { 1.09, 0.17, 1.29 },
					at = { 0, -0.36, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Ring7",
					size = { 1.06, 0.17, 1.26 },
					at = { 0, -0.52, 0 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Hem",
					size = { 1.0918, 0.08, 1.2978 },
					at = { 0, -0.6, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Collar",
					size = { 0.7632, 0.2, 1.0836 },
					at = { 0, 0.52, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.38,
				},
				{
					name = "Belt",
					size = { 0.9752, 0.2, 1.1592 },
					at = { 0, -0.52, 0 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Buckle",
					size = { 0.22, 0.2, 0.12 },
					at = { 0, -0.52, -0.63 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Tasset1",
					limb = "LowerTorso",
					size = { 1.04, 0.5, 1.2 },
					at = { 0, -0.3, 0 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "RRoll",
					limb = "RightUpperArm",
					size = { 1.36, 0.36, 1.34 },
					at = { 0, 0.44, 0 },
					color = PALETTE.iron,
					material = "Metal",
				},
				{
					name = "RRoll2",
					limb = "RightUpperArm",
					size = { 1.32, 0.3, 1.3 },
					at = { 0, 0.16, 0 },
					color = PALETTE.plate,
					material = "Metal",
				},
				{
					name = "RBand",
					limb = "RightUpperArm",
					size = { 1.28, 0.26, 1.26 },
					at = { 0, -0.1, 0 },
					color = PALETTE.iron,
					material = "Metal",
				},
				{
					name = "LRoll",
					limb = "LeftUpperArm",
					size = { 1.36, 0.36, 1.34 },
					at = { 0, 0.44, 0 },
					color = PALETTE.iron,
					material = "Metal",
				},
				{
					name = "LRoll2",
					limb = "LeftUpperArm",
					size = { 1.32, 0.3, 1.3 },
					at = { 0, 0.16, 0 },
					color = PALETTE.plate,
					material = "Metal",
				},
				{
					name = "LBand",
					limb = "LeftUpperArm",
					size = { 1.28, 0.26, 1.26 },
					at = { 0, -0.1, 0 },
					color = PALETTE.iron,
					material = "Metal",
				},
			},
		},
	},
	{
		id = "fragVest",
		category = "armor",
		cost = 3,
		name = "Gilet pare-éclats",
		summary = "Forte contre les explosions, faible contre le reste",
		-- La reponse a l'Artificier, au lance-grenades et aux grenades. Comme le
		-- plastron de cuir, elle se paie en reduction ordinaire : une armure
		-- specialisee qui serait aussi bonne partout ne serait pas un choix.
		offset = { damageTakenRatio = -0.06, blastTakenRatio = -0.45 },
		look = {
			worn = { limb = "UpperTorso", at = { 0, 0, 0 }, fit = true },
			pieces = {
				{
					name = "Front",
					size = { 1.0176, 0.86, 0.6552 },
					at = { 0, 0.06, -0.3276 },
					color = PALETTE.olive,
					material = "Fabric",
					reflectance = 0,
				},
				{
					name = "Back",
					size = { 1.0176, 0.86, 0.6552 },
					at = { 0, 0.06, 0.3276 },
					color = PALETTE.olive,
					material = "Fabric",
					reflectance = 0,
				},
				{
					name = "Side1",
					size = { 0.53, 0.74, 1.2348 },
					at = { 0.4876, 0.04, 0 },
					color = PALETTE.shade,
					material = "Fabric",
				},
				{
					name = "Side2",
					size = { 0.53, 0.74, 1.2348 },
					at = { -0.4876, 0.04, 0 },
					color = PALETTE.shade,
					material = "Fabric",
				},
				{
					name = "Strap1",
					size = { 0.24, 0.5, 1.3104 },
					at = { -0.3, 0.4, 0 },
					color = PALETTE.shade,
					material = "Fabric",
				},
				{
					name = "Strap2",
					size = { 0.24, 0.5, 1.3104 },
					at = { 0.3, 0.4, 0 },
					color = PALETTE.shade,
					material = "Fabric",
				},
				{
					name = "Collar",
					size = { 0.7632, 0.2, 1.0836 },
					at = { 0, 0.52, 0 },
					color = PALETTE.shade,
					material = "Fabric",
					reflectance = 0.08,
				},
				{
					name = "Belt",
					size = { 0.9752, 0.2, 1.1592 },
					at = { 0, -0.52, 0 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Buckle",
					size = { 0.22, 0.2, 0.12 },
					at = { 0, -0.52, -0.63 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Pouch1",
					size = { 0.3, 0.3, 0.26 },
					at = { -0.318, -0.3, -0.6552 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Flap1",
					size = { 0.32, 0.12, 0.22 },
					at = { -0.318, -0.16, -0.6804 },
					color = PALETTE.shade,
					material = "Fabric",
				},
				{
					name = "Pouch2",
					size = { 0.3, 0.3, 0.26 },
					at = { 0, -0.3, -0.6552 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Flap2",
					size = { 0.32, 0.12, 0.22 },
					at = { 0, -0.16, -0.6804 },
					color = PALETTE.shade,
					material = "Fabric",
				},
				{
					name = "Pouch3",
					size = { 0.3, 0.3, 0.26 },
					at = { 0.318, -0.3, -0.6552 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Flap3",
					size = { 0.32, 0.12, 0.22 },
					at = { 0.318, -0.16, -0.6804 },
					color = PALETTE.shade,
					material = "Fabric",
				},
				{
					name = "RPauldron",
					limb = "RightUpperArm",
					size = { 1.34, 0.4, 1.3 },
					at = { 0, 0.42, 0 },
					color = PALETTE.olive,
					material = "Fabric",
					reflectance = 0,
				},
				{
					name = "RPauldronRim",
					limb = "RightUpperArm",
					size = { 1.36, 0.1, 1.32 },
					at = { 0, 0.26, 0 },
					color = PALETTE.shade,
					material = "Fabric",
					reflectance = 0.1,
				},
				{
					name = "LPauldron",
					limb = "LeftUpperArm",
					size = { 1.34, 0.4, 1.3 },
					at = { 0, 0.42, 0 },
					color = PALETTE.olive,
					material = "Fabric",
					reflectance = 0,
				},
				{
					name = "LPauldronRim",
					limb = "LeftUpperArm",
					size = { 1.36, 0.1, 1.32 },
					at = { 0, 0.26, 0 },
					color = PALETTE.shade,
					material = "Fabric",
					reflectance = 0.1,
				},
			},
		},
	},
	{
		id = "plateArmor",
		category = "armor",
		cost = 4,
		name = "Armure de plaques",
		summary = "Forte réduction, perte de vitesse notable",
		offset = { damageTakenRatio = -0.22 },
		scale = { walkSpeed = 0.85 },
		look = {
			worn = { limb = "UpperTorso", at = { 0, 0, 0 }, fit = true },
			pieces = {
				{
					name = "Cuirass",
					size = { 1.08, 0.74, 1.3 },
					at = { 0, 0.1, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.22,
				},
				{
					name = "CuirassWaist",
					size = { 0.94, 0.26, 1.14 },
					at = { 0, -0.26, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.22,
				},
				{
					name = "Placket",
					size = { 0.05, 0.66, 0.05 },
					at = { 0, 0.08, -0.68 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "ChestRim",
					size = { 1.1, 0.055, 1.32 },
					at = { 0, 0.46, 0 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Gorget",
					size = { 0.5, 0.17, 1.04 },
					at = { 0, 0.53, -0.02 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "GorgetRim",
					size = { 0.54, 0.055, 1.08 },
					at = { 0, 0.61, -0.02 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Belt",
					size = { 0.98, 0.1, 1.18 },
					at = { 0, -0.37, 0 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Buckle",
					size = { 0.1, 0.13, 0.07 },
					at = { 0, -0.37, -0.62 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Fauld1",
					size = { 1.06, 0.13, 1.28 },
					at = { 0, -0.46, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Fauld2",
					size = { 1.16, 0.12, 1.4 },
					at = { 0, -0.57, 0 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "FauldRim",
					size = { 1.18, 0.045, 1.42 },
					at = { 0, -0.63, 0 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Rivet1",
					size = { 0.04, 0.045, 0.05 },
					at = { -0.33, 0.3, -0.67 },
					shape = "Ball",
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Rivet2",
					size = { 0.04, 0.045, 0.05 },
					at = { 0.33, 0.3, -0.67 },
					shape = "Ball",
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Rivet3",
					size = { 0.04, 0.045, 0.05 },
					at = { -0.31, -0.1, -0.67 },
					shape = "Ball",
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Rivet4",
					size = { 0.04, 0.045, 0.05 },
					at = { 0.31, -0.1, -0.67 },
					shape = "Ball",
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "PauldronRight",
					limb = "RightUpperArm",
					size = { 1.2, 0.46, 1.02 },
					at = { 0.12, 0.4, 0 },
					roll = -12,
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.22,
				},
				{
					name = "PauldronTopRight",
					limb = "RightUpperArm",
					size = { 0.98, 0.17, 0.84 },
					at = { 0.08, 0.66, 0 },
					roll = -12,
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.22,
				},
				{
					name = "PauldronRimRight",
					limb = "RightUpperArm",
					size = { 1.26, 0.08, 1.08 },
					at = { 0.12, 0.17, 0 },
					roll = -12,
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "RerebraceRight",
					limb = "RightUpperArm",
					size = { 1.14, 0.56, 1.1 },
					at = { 0.02, -0.12, 0 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "PauldronLeft",
					limb = "LeftUpperArm",
					size = { 1.2, 0.46, 1.02 },
					at = { -0.12, 0.4, 0 },
					roll = 12,
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.22,
				},
				{
					name = "PauldronTopLeft",
					limb = "LeftUpperArm",
					size = { 0.98, 0.17, 0.84 },
					at = { -0.08, 0.66, 0 },
					roll = 12,
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.22,
				},
				{
					name = "PauldronRimLeft",
					limb = "LeftUpperArm",
					size = { 1.26, 0.08, 1.08 },
					at = { -0.12, 0.17, 0 },
					roll = 12,
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "RerebraceLeft",
					limb = "LeftUpperArm",
					size = { 1.14, 0.56, 1.1 },
					at = { -0.02, -0.12, 0 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "CuisseRight",
					limb = "RightUpperLeg",
					size = { 1.1, 0.5, 1.16 },
					at = { 0, 0.1, 0 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "CuisseRimRight",
					limb = "RightUpperLeg",
					size = { 1.14, 0.07, 1.2 },
					at = { 0, 0.33, 0 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "PoleynRight",
					limb = "RightUpperLeg",
					size = { 1.16, 0.18, 1.24 },
					at = { 0, -0.3, -0.06 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "CuisseLeft",
					limb = "LeftUpperLeg",
					size = { 1.1, 0.5, 1.16 },
					at = { 0, 0.1, 0 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "CuisseRimLeft",
					limb = "LeftUpperLeg",
					size = { 1.14, 0.07, 1.2 },
					at = { 0, 0.33, 0 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "PoleynLeft",
					limb = "LeftUpperLeg",
					size = { 1.16, 0.18, 1.24 },
					at = { 0, -0.3, -0.06 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.25,
				},
			},
		},
	},
	{
		id = "exoskeleton",
		category = "armor",
		cost = 4,
		name = "Exosquelette",
		summary = "Réduction moyenne, et ne se fait plus repousser",
		-- Elle annule la poussee, pas les degats de la poussee. C'est la reponse
		-- au Colosse, au Sismique, au marteau et a la masse — quatre choses qui
		-- gagnent en deplacant les gens plutot qu'en les blessant.
		offset = { damageTakenRatio = -0.14 },
		resistsKnockback = true,
		look = {
			worn = { limb = "UpperTorso", at = { 0, 0, 0 }, fit = true },
			pieces = {
				{
					name = "Shell",
					size = { 1.1024, 1.04, 1.3104 },
					at = { 0, 0.08, 0 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "ShellRim",
					size = { 1.1342, 0.14, 1.3482 },
					at = { 0, -0.44, 0 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Spine",
					size = { 0.3, 1.3, 0.34 },
					at = { 0, 0.05, 0.63 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Plate",
					size = { 0.742, 0.72, 0.3 },
					at = { 0, 0.14, -0.6552 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Core",
					size = { 0.3, 0.153, 0.26 },
					at = { 0, 0.14, -0.7812 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.glass,
					material = "Neon",
				},
				{
					name = "Waist",
					size = { 0.954, 0.3, 1.134 },
					at = { 0, -0.62, 0 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Rib1",
					size = { 1.166, 0.14, 1.3608 },
					at = { 0, 0.4, 0 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Rib2",
					size = { 1.166, 0.14, 1.3608 },
					at = { 0, 0.1, 0 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Rib3",
					size = { 1.166, 0.14, 1.3608 },
					at = { 0, -0.2, 0 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "RServo",
					limb = "RightUpperArm",
					size = { 1.3, 0.44, 1.3 },
					at = { 0, 0.42, 0 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RAxle",
					limb = "RightUpperArm",
					size = { 1.46, 0.29, 0.36 },
					at = { 0, 0.42, 0 },
					shape = "Cylinder",
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "RStrut",
					limb = "RightUpperArm",
					size = { 0.3, 1, 0.3 },
					at = { 0.55, -0.1, 0 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "LServo",
					limb = "LeftUpperArm",
					size = { 1.3, 0.44, 1.3 },
					at = { 0, 0.42, 0 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "LAxle",
					limb = "LeftUpperArm",
					size = { 1.46, 0.29, 0.36 },
					at = { 0, 0.42, 0 },
					shape = "Cylinder",
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "LStrut",
					limb = "LeftUpperArm",
					size = { 0.3, 1, 0.3 },
					at = { -0.55, -0.1, 0 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RRail",
					limb = "RightUpperLeg",
					size = { 0.26, 1.1, 0.26 },
					at = { 0.52, 0, -0.1 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RKnee",
					limb = "RightUpperLeg",
					size = { 0.3, 0.83, 1.16 },
					at = { 0, -0.56, 0 },
					shape = "Cylinder",
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "LRail",
					limb = "LeftUpperLeg",
					size = { 0.26, 1.1, 0.26 },
					at = { -0.52, 0, -0.1 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "LKnee",
					limb = "LeftUpperLeg",
					size = { 0.3, 0.83, 1.16 },
					at = { 0, -0.56, 0 },
					shape = "Cylinder",
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.3,
				},
			},
		},
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
		look = {
			offhand = { 0, -0.4, -0.2 },
			pieces = {
				{
					name = "Barrel",
					size = { 0.648, 0.22, 0.22 },
					at = { 0, 0, -0.396 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.glass,
					material = "Glass",
					reflectance = 0.3,
				},
				{
					name = "Fluid",
					size = { 0.45, 0.176, 0.176 },
					at = { 0, 0, -0.45 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.glass,
					material = "SmoothPlastic",
				},
				{
					name = "Collar",
					size = { 0.1, 0.253, 0.253 },
					at = { 0, 0, -0.738 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Needle",
					size = { 0.234, 0.044, 0.044 },
					at = { 0, 0, -0.846 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "Plunger",
					size = { 0.27, 0.077, 0.077 },
					at = { 0, 0, 0.1 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.glass,
					material = "SmoothPlastic",
				},
				{
					name = "Thumb",
					size = { 0.08, 0.286, 0.286 },
					at = { 0, 0, 0.22 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.cloth,
					material = "SmoothPlastic",
				},
				{
					name = "Flange",
					size = { 0.08, 0.308, 0.308 },
					at = { 0, 0, -0.02 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.cloth,
					material = "SmoothPlastic",
				},
			},
		},
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
		look = {
			offhand = { 0, -0.45, -0.25 },
			pieces = {
				{
					name = "Case",
					size = { 0.6, 0.44, 0.3 },
					at = { 0, 0, 0 },
					color = PALETTE.cloth,
					material = "SmoothPlastic",
				},
				{
					name = "Seam",
					size = { 0.62, 0.05, 0.32 },
					at = { 0, 0.1, 0 },
					color = PALETTE.iron,
					material = "SmoothPlastic",
				},
				{
					name = "CrossUp",
					size = { 0.09, 0.28, 0.02 },
					at = { 0, -0.02, -0.16 },
					color = PALETTE.alert,
					material = "SmoothPlastic",
				},
				{
					name = "CrossAcross",
					size = { 0.28, 0.09, 0.02 },
					at = { 0, -0.02, -0.16 },
					color = PALETTE.alert,
					material = "SmoothPlastic",
				},
				{
					name = "Handle",
					size = { 0.26, 0.09, 0.06 },
					at = { 0, 0.26, 0 },
					color = PALETTE.iron,
					material = "Plastic",
				},
				{
					name = "LatchLeft",
					size = { 0.07, 0.1, 0.04 },
					at = { -0.2, 0.08, -0.16 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "LatchRight",
					size = { 0.07, 0.1, 0.04 },
					at = { 0.2, 0.08, -0.16 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Corner1",
					size = { 0.06, 0.06, 0.32 },
					at = { -0.27, 0.19, 0 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Corner2",
					size = { 0.06, 0.06, 0.32 },
					at = { 0.27, 0.19, 0 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Corner3",
					size = { 0.06, 0.06, 0.32 },
					at = { -0.27, -0.19, 0 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
				{
					name = "Corner4",
					size = { 0.06, 0.06, 0.32 },
					at = { 0.27, -0.19, 0 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.15,
				},
			},
		},
	},

	{
		id = "bandage",
		category = "heal",
		cost = 1,
		name = "Bandage",
		summary = "Petit soin, pose lente, deux charges",
		-- Le meme prix que le stimulant, et l'inverse exact : plus de PV en
		-- tout, mais il faut deux secondes et demie a l'abri, et un seul coup
		-- recu annule la pose. C'est la question que le budget doit faire
		-- naitre — est-ce que j'ai le temps, ou est-ce que je paie pour ne pas
		-- en avoir besoin.
		use = {
			kind = "heal",
			charges = 2,
			amount = 30,
			castSeconds = 2.5,
			interruptedByDamage = true,
		},
		look = {
			offhand = { 0, -0.4, -0.2 },
			pieces = {
				{
					name = "Roll",
					size = { 0.2, 0.44, 0.44 },
					at = { 0, 0, 0 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.cloth,
					material = "Fabric",
				},
				{
					name = "Wrap1",
					size = { 0.14, 0.47, 0.47 },
					at = { 0.04, 0, 0 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.cloth,
					material = "Fabric",
				},
				{
					name = "Wrap2",
					size = { 0.1, 0.49, 0.49 },
					at = { -0.05, 0, 0 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.cloth,
					material = "Fabric",
				},
				{
					name = "Core",
					size = { 0.22, 0.16, 0.16 },
					at = { 0, 0, 0 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.shade,
					material = "Fabric",
				},
				{
					name = "Tail1",
					size = { 0.18, 0.05, 0.3 },
					at = { 0, -0.22, -0.12 },
					tipUp = -18,
					color = PALETTE.cloth,
					material = "Fabric",
				},
				{
					name = "Tail2",
					size = { 0.18, 0.05, 0.26 },
					at = { 0, -0.32, -0.3 },
					tipUp = -40,
					color = PALETTE.cloth,
					material = "Fabric",
				},
				{
					name = "Clip",
					size = { 0.2, 0.06, 0.06 },
					at = { 0, -0.4, -0.42 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Band",
					size = { 0.22, 0.12, 0.12 },
					at = { 0, 0.2, 0.08 },
					color = PALETTE.alert,
					material = "Fabric",
				},
			},
		},
	},
	{
		id = "regenVial",
		category = "heal",
		cost = 2,
		name = "Fiole régénérante",
		summary = "Soin étalé dans le temps, continue même en courant",
		-- LE SEUL SOIN QU'UN COUP N'ARRETE PAS. Il rend quarante-huit PV, mais
		-- sur douze secondes : si l'echange dure trois secondes, il n'en aura
		-- rendu que douze. Il ne sauve pas d'un coup, il gagne une guerre
		-- d'usure.
		use = {
			kind = "heal",
			charges = 2,
			amount = 48,
			overSeconds = 12,
			castSeconds = 0,
		},
		look = {
			offhand = { 0, -0.4, -0.2 },
			pieces = {
				{
					name = "Glass",
					size = { 0.56, 0.26, 0.26 },
					at = { 0, 0, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.glass,
					material = "Glass",
					reflectance = 0.4,
				},
				{
					name = "Fluid",
					size = { 0.3696, 0.208, 0.208 },
					at = { 0, -0.0784, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.olive,
					material = "Neon",
				},
				{
					name = "Neck",
					size = { 0.112, 0.169, 0.169 },
					at = { 0, 0.3136, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.glass,
					material = "Glass",
					reflectance = 0.4,
				},
				{
					name = "Cap",
					size = { 0.112, 0.221, 0.221 },
					at = { 0, 0.3808, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.brass,
					material = "SmoothPlastic",
				},
				{
					name = "Label",
					size = { 0.273, 0.168, 0.065 },
					at = { 0, -0.056, -0.13 },
					color = PALETTE.cloth,
					material = "SmoothPlastic",
				},
				{
					name = "Base",
					size = { 0.0448, 0.286, 0.286 },
					at = { 0, -0.28, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.glass,
					material = "Glass",
					reflectance = 0.4,
				},
			},
		},
	},
	{
		id = "fullHeal",
		category = "heal",
		cost = 3,
		name = "Soin complet",
		summary = "Gros soin, une charge, pose très lente",
		-- Trois secondes immobile, annulees par le moindre degat. C'est l'objet
		-- de l'assemblage du tank de la fiche, et il demande de rompre le
		-- combat pour de vrai.
		use = {
			kind = "heal",
			charges = 1,
			amount = 90,
			castSeconds = 3,
			interruptedByDamage = true,
		},
		look = {
			offhand = { 0, -0.5, -0.3 },
			pieces = {
				{
					name = "Case",
					size = { 0.78, 0.56, 0.36 },
					at = { 0, 0, 0 },
					color = PALETTE.cloth,
					material = "SmoothPlastic",
				},
				{
					name = "Seam",
					size = { 0.7956, 0.05, 0.3708 },
					at = { 0, 0.112, 0 },
					color = PALETTE.iron,
					material = "SmoothPlastic",
				},
				{
					name = "Edge",
					size = { 0.7878, 0.5656, 0.0216 },
					at = { 0, 0, -0.18 },
					color = PALETTE.iron,
					material = "SmoothPlastic",
				},
				{
					name = "Handle",
					size = { 0.312, 0.1, 0.18 },
					at = { 0, 0.3248, 0 },
					color = PALETTE.iron,
					material = "SmoothPlastic",
				},
				{
					name = "HandleBar",
					size = { 0.312, 0.14, 0.08 },
					at = { 0, 0.2912, 0 },
					color = PALETTE.iron,
					material = "SmoothPlastic",
				},
				{
					name = "Latch1",
					size = { 0.1, 0.12, 0.07 },
					at = { -0.2028, 0.112, -0.1872 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Latch2",
					size = { 0.1, 0.12, 0.07 },
					at = { 0.2028, 0.112, -0.1872 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "CrossV",
					size = { 0.1, 0.2912, 0.04 },
					at = { 0, -0.0672, -0.1872 },
					color = PALETTE.alert,
					material = "SmoothPlastic",
				},
				{
					name = "CrossH",
					size = { 0.2652, 0.1, 0.04 },
					at = { 0, -0.0672, -0.1872 },
					color = PALETTE.alert,
					material = "SmoothPlastic",
				},
			},
		},
	},
	{
		id = "transfusion",
		category = "heal",
		cost = 3,
		name = "Transfusion",
		summary = "Soin moyen qui soigne aussi un allié proche",
		-- Le seul soin qui sort du joueur qui le porte. A un contre un il ne
		-- vaut pas la trousse ; a trois contre trois il en vaut deux, et c'est
		-- le genre d'objet qui rend un format different d'un autre.
		use = {
			kind = "heal",
			charges = 2,
			amount = 40,
			castSeconds = 1.2,
			interruptedByDamage = true,
			allyAmount = 32,
			allyRadiusStuds = 22,
		},
		look = {
			offhand = { 0, -0.45, -0.25 },
			pieces = {
				{
					name = "Bag",
					size = { 0.5, 0.6, 0.18 },
					at = { 0, 0, 0 },
					color = PALETTE.alert,
					material = "SmoothPlastic",
					reflectance = 0.08,
				},
				{
					name = "Sheen",
					size = { 0.4, 0.5, 0.22 },
					at = { 0, 0.02, 0 },
					color = PALETTE.alert,
					material = "Glass",
					reflectance = 0.25,
				},
				{
					name = "Top",
					size = { 0.5, 0.16, 0.18 },
					at = { 0, 0.36, 0 },
					shape = "Cylinder",
					color = PALETTE.cloth,
					material = "SmoothPlastic",
				},
				{
					name = "Hanger",
					size = { 0.1, 0.14, 0.06 },
					at = { 0, 0.48, 0 },
					color = PALETTE.cloth,
					material = "SmoothPlastic",
				},
				{
					name = "Label",
					size = { 0.3, 0.2, 0.04 },
					at = { 0, 0.08, -0.1 },
					color = PALETTE.cloth,
					material = "SmoothPlastic",
				},
				{
					name = "Spout",
					size = { 0.14, 0.18, 0.14 },
					at = { 0, -0.36, 0 },
					color = PALETTE.cloth,
					material = "SmoothPlastic",
				},
				{
					name = "Tube1",
					size = { 0.07, 0.299, 0.07 },
					at = { 0, -0.5822, -0.0445 },
					tipUp = 70,
					color = PALETTE.alert,
					material = "SmoothPlastic",
				},
				{
					name = "Tube2",
					size = { 0.07, 0.299, 0.07 },
					at = { 0, -0.8009, -0.1759 },
					tipUp = 48,
					color = PALETTE.alert,
					material = "SmoothPlastic",
				},
				{
					name = "Tube3",
					size = { 0.07, 0.299, 0.07 },
					at = { 0, -0.9545, -0.3797 },
					tipUp = 26,
					color = PALETTE.alert,
					material = "SmoothPlastic",
				},
				{
					name = "Tube4",
					size = { 0.07, 0.299, 0.07 },
					at = { 0, -1.0206, -0.6263 },
					tipUp = 4,
					color = PALETTE.alert,
					material = "SmoothPlastic",
				},
				{
					name = "Needle",
					size = { 0.05, 0.05, 0.2 },
					at = { 0, -1.0497, -0.856 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.45,
				},
			},
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
		look = {
			offhand = { 0, -0.4, -0.2 },
			pieces = {
				{
					name = "Shell",
					size = { 0.14, 0.6, 0.6 },
					at = { 0, 0, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Rim",
					size = { 0.056, 0.63, 0.63 },
					at = { 0, 0, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Dome",
					size = { 0.21, 0.33, 0.33 },
					at = { 0, 0.056, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Lamp",
					size = { 0.084, 0.12, 0.12 },
					at = { 0, 0.126, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.alert,
					material = "Neon",
				},
				{
					name = "Prong1",
					size = { 0.09, 0.196, 0.09 },
					at = { 0, 0.112, 0.21 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Prong2",
					size = { 0.09, 0.196, 0.09 },
					at = { 0.1819, 0.112, -0.105 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Prong3",
					size = { 0.09, 0.196, 0.09 },
					at = { -0.1819, 0.112, -0.105 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
			},
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
		look = {
			offhand = { 0, -0.35, -0.2 },
			pieces = {
				{
					name = "Body",
					size = { 0.46, 0.46, 0.46 },
					at = { 0, 0, 0 },
					shape = "Ball",
					color = PALETTE.olive,
					material = "Metal",
					reflectance = 0.08,
				},
				{
					name = "Belt",
					size = { 0.03, 0.45, 0.45 },
					at = { 0, 0, 0 },
					roll = 90,
					shape = "Cylinder",
					color = PALETTE.shade,
					material = "Metal",
					reflectance = 0,
				},
				{
					name = "Band1",
					size = { 0.025, 0.41, 0.41 },
					at = { 0, 0.1, 0 },
					roll = 90,
					shape = "Cylinder",
					color = PALETTE.shade,
					material = "Metal",
					reflectance = 0,
				},
				{
					name = "Band2",
					size = { 0.025, 0.41, 0.41 },
					at = { 0, -0.1, 0 },
					roll = 90,
					shape = "Cylinder",
					color = PALETTE.shade,
					material = "Metal",
					reflectance = 0,
				},
				{
					name = "Neck",
					size = { 0.1, 0.17, 0.17 },
					at = { 0, 0.26, 0 },
					roll = 90,
					shape = "Cylinder",
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0,
				},
				{
					name = "Cap",
					size = { 0.05, 0.21, 0.21 },
					at = { 0, 0.33, 0 },
					roll = 90,
					shape = "Cylinder",
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.1,
				},
				{
					name = "Lever",
					size = { 0.035, 0.28, 0.08 },
					at = { 0.15, 0.1, 0 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.18,
				},
				{
					name = "Ring",
					size = { 0.025, 0.12, 0.12 },
					at = { -0.13, 0.26, 0 },
					shape = "Cylinder",
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.25,
				},
			},
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
		look = {
			offhand = { 0, -0.5, -0.35 },
			pieces = {
				{
					name = "Panel",
					size = { 0.9, 1, 0.16 },
					at = { 0, 0, -0.1 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Fold",
					size = { 0.86, 0.9, 0.14 },
					at = { 0, -0.06, 0.06 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Window",
					size = { 0.4, 0.22, 0.05 },
					at = { 0, 0.3, -0.2 },
					color = PALETTE.glass,
					material = "Glass",
					reflectance = 0.4,
				},
				{
					name = "Grip",
					size = { 0.14, 0.42, 0.14 },
					at = { 0, -0.1, 0.2 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Hinge",
					size = { 0.9, 0.1, 0.12 },
					at = { 0, 0.46, 0 },
					shape = "Cylinder",
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Vane1",
					size = { 0.86, 0.07, 0.07 },
					at = { 0, 0.26, -0.19 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Vane2",
					size = { 0.86, 0.07, 0.07 },
					at = { 0, -0.04, -0.19 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Vane3",
					size = { 0.86, 0.07, 0.07 },
					at = { 0, -0.34, -0.19 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Foot1",
					size = { 0.12, 0.26, 0.3 },
					at = { -0.36, -0.58, -0.04 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Foot2",
					size = { 0.12, 0.26, 0.3 },
					at = { 0.36, -0.58, -0.04 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
			},
		},
	},
	{
		id = "smokeBomb",
		category = "utility",
		cost = 1,
		name = "Fumigène",
		summary = "Bloque la vue quelques secondes",
		-- Le seul objet du catalogue qui ne touche ni aux PV ni aux
		-- statistiques : il pose un mur qu'on ne voit pas a travers, et les
		-- balles le traversent. C'est de la couverture pretee, pas de la
		-- protection.
		use = {
			kind = "zone",
			effect = "smoke",
			charges = 2,
			seconds = 8,
			radiusStuds = 11,
		},
		look = {
			offhand = { 0, -0.4, -0.2 },
			pieces = {
				{
					name = "Body",
					size = { 0.66, 0.32, 0.32 },
					at = { 0, 0.198, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.1,
				},
				{
					name = "Cap",
					size = { 0.12, 0.336, 0.336 },
					at = { 0, 0.488, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Base",
					size = { 0.12, 0.336, 0.336 },
					at = { 0, -0.092, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Band1",
					size = { 0.14, 0.3424, 0.3424 },
					at = { 0, 0.3432, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.cloth,
					material = "SmoothPlastic",
				},
				{
					name = "Band2",
					size = { 0.14, 0.3424, 0.3424 },
					at = { 0, 0.0528, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.cloth,
					material = "SmoothPlastic",
				},
				{
					name = "Lever",
					size = { 0.1, 0.363, 0.1 },
					at = { 0, 0.2508, -0.152 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Spoon",
					size = { 0.12, 0.14, 0.14 },
					at = { 0, 0.468, -0.152 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Ring",
					size = { 0.05, 0.22, 0.22 },
					at = { 0.144, 0.548, 0 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Pin",
					size = { 0.16, 0.05, 0.05 },
					at = { 0.072, 0.548, 0 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Port1",
					size = { 0.12, 0.12, 0.12 },
					at = { 0, -0.0132, 0.1376 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Port2",
					size = { 0.12, 0.12, 0.12 },
					at = { 0.1376, -0.0132, 0 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Port3",
					size = { 0.12, 0.12, 0.12 },
					at = { 0, -0.0132, -0.1376 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Port4",
					size = { 0.12, 0.12, 0.12 },
					at = { -0.1376, -0.0132, 0 },
					color = PALETTE.shade,
					material = "Metal",
				},
			},
		},
	},
	{
		id = "beacon",
		category = "utility",
		cost = 1,
		name = "Balise",
		summary = "Révèle une petite zone en continu",
		-- Posee ou on ne regarde pas : un couloir, un angle. Elle ne sert a rien
		-- seul, et beaucoup a plusieurs — c'est voulu, la categorie des
		-- utilitaires est celle qui fabrique les styles de jeu.
		use = {
			kind = "zone",
			effect = "reveal",
			charges = 1,
			seconds = 45,
			radiusStuds = 16,
		},
		look = {
			offhand = { 0, -0.45, -0.25 },
			pieces = {
				{
					name = "Stake",
					size = { 0.12, 0.9, 0.12 },
					at = { 0, -0.4, 0 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Point",
					size = { 0.1, 0.26, 0.1 },
					at = { 0, -0.96, 0 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Body",
					size = { 0.34, 0.44, 0.34 },
					at = { 0, 0.16, 0 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Collar",
					size = { 0.08, 0.4, 0.4 },
					at = { 0, 0.38, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Lamp",
					size = { 0.3, 0.3, 0.3 },
					at = { 0, 0.52, 0 },
					shape = "Ball",
					color = PALETTE.alert,
					material = "Neon",
				},
				{
					name = "Cage1",
					size = { 0.34, 0.05, 0.05 },
					at = { 0, 0.52, 0 },
					shape = "Cylinder",
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Cage2",
					size = { 0.34, 0.05, 0.05 },
					at = { 0, 0.52, 0 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Switch",
					size = { 0.12, 0.1, 0.1 },
					at = { 0.18, 0.16, 0 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
			},
		},
	},
	{
		id = "grapple",
		category = "utility",
		cost = 2,
		name = "Grappin",
		summary = "Déplacement vertical, recharge longue",
		-- Il monte, il n'avance pas : c'est ce qui le distingue des bottes a
		-- ressort, et ce qui le rend bon sur une map a etages et nul sur une map
		-- plate. Les deux coexistent pour cette raison.
		-- VINGT STUDS DE HAUT POUR DE VRAI, soit presque trois sauts
		-- ordinaires empiles. Les anciens chiffres etaient des vitesses prises
		-- pour des distances : « 85 » montait a 18, et « 15 » vers l'avant
		-- portait a 0,3 stud. Ceux-ci sont ce que le commentaire ci-dessus
		-- demandait depuis le debut.
		--
		-- Mesure en jeu du 27 octobre 2026 : 19,8 de haut et 3,1 devant. Neuf
		-- dixiemes de seconde de vol, et on redescend ou on est parti : c'est
		-- long quand on est a decouvert, et c'est le prix du raccourci.
		use = {
			kind = "leap",
			charges = 2,
			upStuds = 20,
			-- Trois studs devant, et pas zero : le grappin monte, il n'avance
			-- pas, mais retomber exactement sur sa propre trace est penible
			-- quand on cherchait un rebord.
			forwardStuds = 3,
		},
		look = {
			offhand = { 0, -0.5, -0.4 },
			pieces = {
				{
					name = "Hold",
					size = { 0.19, 0.44, 0.28 },
					at = { 0, -0.26, 0.1 },
					tipUp = 16,
					color = PALETTE.gun,
					material = "Plastic",
				},
				{
					name = "Body",
					size = { 0.24, 0.3, 0.8 },
					at = { 0, 0.02, -0.26 },
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Trigger",
					size = { 0.06, 0.14, 0.06 },
					at = { 0, -0.12, -0.2 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Drum",
					size = { 0.18, 0.46, 0.46 },
					at = { 0, 0.04, 0.12 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Rope",
					size = { 0.14, 0.4, 0.4 },
					at = { 0, 0.04, 0.12 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.wood,
					material = "Fabric",
				},
				{
					name = "Rail",
					size = { 0.1, 0.1, 0.9 },
					at = { 0, 0.22, -0.4 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Shaft",
					size = { 0.11, 0.11, 0.5 },
					at = { 0, 0.1, -0.78 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Fluke1",
					size = { 0.08, 0.3, 0.34 },
					at = { 0, 0.22, -1.04 },
					tipUp = -38,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Fluke2",
					size = { 0.08, 0.3, 0.34 },
					at = { 0.1039, 0.04, -1.04 },
					tipUp = -38,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Fluke3",
					size = { 0.08, 0.3, 0.34 },
					at = { -0.1039, 0.04, -1.04 },
					tipUp = -38,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
			},
		},
	},
	{
		id = "detector",
		category = "utility",
		cost = 2,
		name = "Détecteur",
		summary = "Révèle les ennemis proches de soi, un moment",
		-- La balise qu'on emporte : elle part de la ou on est au moment de
		-- l'allumer. Plus courte et plus large que la balise, et deux fois plus
		-- chere, parce qu'elle revele la ou le combat est.
		use = {
			kind = "zone",
			effect = "reveal",
			charges = 2,
			seconds = 10,
			radiusStuds = 34,
		},
		look = {
			offhand = { 0, -0.45, -0.2 },
			pieces = {
				{
					name = "Case",
					size = { 0.46, 0.6, 0.22 },
					at = { 0, 0, 0 },
					color = PALETTE.gun,
					material = "Plastic",
				},
				{
					name = "Bezel",
					size = { 0.48, 0.62, 0.05 },
					at = { 0, 0, -0.12 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Screen",
					size = { 0.34, 0.3, 0.04 },
					at = { 0, 0.1, -0.15 },
					color = PALETTE.glass,
					material = "Neon",
				},
				{
					name = "Grip",
					size = { 0.3, 0.2, 0.26 },
					at = { 0, -0.38, 0.02 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Dial",
					size = { 0.08, 0.14, 0.14 },
					at = { -0.12, -0.18, -0.14 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Button",
					size = { 0.1, 0.08, 0.06 },
					at = { 0.12, -0.18, -0.14 },
					color = PALETTE.alert,
					material = "SmoothPlastic",
				},
				{
					name = "Mast1",
					size = { 0.05, 0.56, 0.05 },
					at = { 0, 0.56, 0.04 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Tip1",
					size = { 0.09, 0.09, 0.09 },
					at = { 0, 0.84, 0.04 },
					shape = "Ball",
					color = PALETTE.alert,
					material = "Neon",
				},
			},
		},
	},
	{
		id = "caltrops",
		category = "utility",
		cost = 2,
		name = "Chausse-trappes",
		summary = "Ralentissent qui marche dessus",
		-- Le ralentissement ne s'empile pas avec celui du pistolet a
		-- flechettes : on garde le plus fort. Deux objets qui se multiplieraient
		-- donneraient une immobilisation a quatre points, et l'immobilisation
		-- est ce que la grenade aveuglante fait payer trois.
		use = {
			kind = "zone",
			effect = "slow",
			charges = 2,
			seconds = 20,
			radiusStuds = 9,
			magnitude = 0.6,
			holdSeconds = 1.5,
		},
		look = {
			offhand = { 0, -0.4, -0.2 },
			pieces = {
				{
					name = "Pouch",
					size = { 0.46, 0.4, 0.34 },
					at = { 0, -0.1, 0 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Mouth",
					size = { 0.5, 0.1, 0.38 },
					at = { 0, 0.12, 0 },
					color = PALETTE.wood,
					material = "Leather",
				},
				{
					name = "Cord",
					size = { 0.52, 0.06, 0.4 },
					at = { 0, 0.06, 0 },
					color = PALETTE.cord,
					material = "Leather",
				},
				{
					name = "Spike11",
					size = { 0.07, 0.24, 0.07 },
					at = { 0, 0.24, 0.05 },
					roll = 0,
					tipUp = 24,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Spike12",
					size = { 0.07, 0.24, 0.07 },
					at = { 0.0433, 0.24, -0.025 },
					roll = 20.7846,
					tipUp = -12,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Spike13",
					size = { 0.07, 0.24, 0.07 },
					at = { -0.0433, 0.24, -0.025 },
					roll = -20.7846,
					tipUp = -12,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Spike21",
					size = { 0.07, 0.24, 0.07 },
					at = { -0.0979, 0.2, 0.1183 },
					roll = 15.4269,
					tipUp = 18.3851,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Spike22",
					size = { 0.07, 0.24, 0.07 },
					at = { -0.1129, 0.2, 0.033 },
					roll = 8.2085,
					tipUp = -22.5526,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Spike23",
					size = { 0.07, 0.24, 0.07 },
					at = { -0.1792, 0.2, 0.0887 },
					roll = -23.6354,
					tipUp = 4.1676,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Spike31",
					size = { 0.07, 0.24, 0.07 },
					at = { 0.1792, 0.21, -0.0613 },
					roll = 23.6354,
					tipUp = 4.1676,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Spike32",
					size = { 0.07, 0.24, 0.07 },
					at = { 0.1129, 0.21, -0.117 },
					roll = -8.2085,
					tipUp = -22.5526,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Spike33",
					size = { 0.07, 0.24, 0.07 },
					at = { 0.0979, 0.21, -0.0317 },
					roll = -15.4269,
					tipUp = 18.3851,
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
			},
		},
	},
	{
		id = "flashbang",
		category = "utility",
		cost = 3,
		name = "Grenade aveuglante",
		summary = "Étourdit brièvement, ne blesse pas",
		-- Elle ne retire aucun PV : ce qu'elle achete est une seconde et demie
		-- ou l'adversaire ne peut ni frapper ni avancer. C'est le seul objet du
		-- catalogue qui prive quelqu'un de ses commandes, et c'est pour ca
		-- qu'elle est courte.
		use = {
			kind = "grenade",
			charges = 2,
			damage = 0,
			radiusStuds = 14,
			fuseSeconds = 1.2,
			throwStuds = 50,
			status = { kind = "stun", seconds = 1.5, magnitude = 0 },
		},
		look = {
			offhand = { 0, -0.4, -0.2 },
			pieces = {
				{
					name = "Body",
					size = { 0.6, 0.3, 0.3 },
					at = { 0, 0.18, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.1,
				},
				{
					name = "Cap",
					size = { 0.12, 0.315, 0.315 },
					at = { 0, 0.44, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Base",
					size = { 0.12, 0.315, 0.315 },
					at = { 0, -0.08, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Band1",
					size = { 0.14, 0.321, 0.321 },
					at = { 0, 0.312, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.edge,
					material = "SmoothPlastic",
				},
				{
					name = "Band2",
					size = { 0.14, 0.321, 0.321 },
					at = { 0, 0.048, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.edge,
					material = "SmoothPlastic",
				},
				{
					name = "Lever",
					size = { 0.1, 0.33, 0.1 },
					at = { 0, 0.228, -0.1425 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Spoon",
					size = { 0.12, 0.14, 0.14 },
					at = { 0, 0.42, -0.1425 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Ring",
					size = { 0.05, 0.22, 0.22 },
					at = { 0.135, 0.5, 0 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Pin",
					size = { 0.16, 0.05, 0.05 },
					at = { 0.0675, 0.5, 0 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Port1",
					size = { 0.12, 0.12, 0.12 },
					at = { 0, -0.012, 0.129 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Port2",
					size = { 0.12, 0.12, 0.12 },
					at = { 0.129, -0.012, 0 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Port3",
					size = { 0.12, 0.12, 0.12 },
					at = { 0, -0.012, -0.129 },
					color = PALETTE.shade,
					material = "Metal",
				},
				{
					name = "Port4",
					size = { 0.12, 0.12, 0.12 },
					at = { -0.129, -0.012, 0 },
					color = PALETTE.shade,
					material = "Metal",
				},
			},
		},
	},
	{
		id = "heavyMine",
		category = "utility",
		cost = 3,
		name = "Mine lourde",
		summary = "Gros dégâts, une charge",
		-- Trois fois les degats de la mine legere pour trois fois le prix. Le
		-- catalogue garde les deux parce qu'a un point on peut en poser une « au
		-- cas ou », et qu'a trois points on la pose ou on sait qu'ils passeront.
		use = {
			kind = "mine",
			charges = 1,
			damage = 62,
			radiusStuds = 11,
			armSeconds = 1.6,
			knockbackStuds = 40,
			knockbackUpStuds = 24,
		},
		look = {
			offhand = { 0, -0.45, -0.25 },
			pieces = {
				{
					name = "Shell",
					size = { 0.2, 0.84, 0.84 },
					at = { 0, 0, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.gun,
					material = "Metal",
					reflectance = 0.12,
				},
				{
					name = "Rim",
					size = { 0.08, 0.882, 0.882 },
					at = { 0, 0, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Dome",
					size = { 0.3, 0.462, 0.462 },
					at = { 0, 0.08, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Lamp",
					size = { 0.12, 0.168, 0.168 },
					at = { 0, 0.18, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.alert,
					material = "Neon",
				},
				{
					name = "Prong1",
					size = { 0.09, 0.28, 0.09 },
					at = { 0, 0.16, 0.294 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Prong2",
					size = { 0.09, 0.28, 0.09 },
					at = { 0.2796, 0.16, 0.0909 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Prong3",
					size = { 0.09, 0.28, 0.09 },
					at = { 0.1728, 0.16, -0.2379 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Prong4",
					size = { 0.09, 0.28, 0.09 },
					at = { -0.1728, 0.16, -0.2379 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Prong5",
					size = { 0.09, 0.28, 0.09 },
					at = { -0.2796, 0.16, 0.0909 },
					color = PALETTE.steel,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Leg1",
					size = { 0.08, 0.44, 0.08 },
					at = { 0, -0.22, 0.3612 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Leg2",
					size = { 0.08, 0.44, 0.08 },
					at = { 0.3128, -0.22, -0.1806 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Leg3",
					size = { 0.08, 0.44, 0.08 },
					at = { -0.3128, -0.22, -0.1806 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
			},
		},
	},
	{
		id = "springBoots",
		category = "utility",
		cost = 3,
		name = "Bottes à ressort",
		summary = "Un bond long, recharge moyenne",
		-- Elles avancent, le grappin monte. Trois charges parce que c'est un
		-- objet de deplacement : une seule et on ne l'achete jamais, on la garde
		-- pour le moment parfait qui n'arrive pas.
		-- Un bond plat et long : huit studs de haut, trente-huit devant. Huit,
		-- c'est a peine plus qu'un saut ordinaire (7,2), et c'est voulu — ce
		-- qu'on achete ici est la distance, pas la hauteur.
		--
		-- Mesure en jeu du 27 octobre 2026 : 7,9 de haut et 43 devant. Les cinq
		-- studs de trop sont le GLISSEMENT A L'ATTERRISSAGE : la contrainte
		-- s'arrete pile a la fin du vol, et le personnage emporte encore sa
		-- vitesse un dixieme de seconde. C'est la seule part de ces deux
		-- chiffres qui ne se commande pas, et elle grandit avec la vitesse.
		use = {
			kind = "leap",
			charges = 3,
			upStuds = 8,
			forwardStuds = 38,
		},
		look = {
			worn = { limb = "RightFoot", at = { 0, 0, 0 }, fit = true },
			pieces = {
				{
					name = "RGreave",
					limb = "RightLowerLeg",
					size = { 1.2, 0.8, 1.2 },
					at = { 0, 0.1, 0 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RGreaveRim",
					limb = "RightLowerLeg",
					size = { 1.24, 0.1, 1.24 },
					at = { 0, 0.46, 0 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "RStrap",
					limb = "RightLowerLeg",
					size = { 1.26, 0.14, 1.26 },
					at = { 0, -0.2, 0 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "RBoot",
					limb = "RightFoot",
					size = { 1.2, 1.5, 1.14 },
					at = { 0, 0.3, -0.06 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "RToe",
					limb = "RightFoot",
					size = { 1.1, 0.9, 0.5 },
					at = { 0, 0, -0.7 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "RCoil1",
					limb = "RightLowerLeg",
					size = { 0.62, 0.1, 0.26 },
					at = { 0, -0.3, 0.78 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "RCoil2",
					limb = "RightLowerLeg",
					size = { 0.62, 0.1, 0.26 },
					at = { 0, -0.52, 0.78 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "RCoil3",
					limb = "RightLowerLeg",
					size = { 0.62, 0.1, 0.26 },
					at = { 0, -0.74, 0.78 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "RPost1",
					limb = "RightLowerLeg",
					size = { 0.1, 0.62, 0.1 },
					at = { -0.22, -0.52, 0.78 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "RPost2",
					limb = "RightLowerLeg",
					size = { 0.1, 0.62, 0.1 },
					at = { 0.22, -0.52, 0.78 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "RPiston",
					limb = "RightLowerLeg",
					size = { 0.16, 0.5, 0.16 },
					at = { 0, 0.18, 0.74 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "RSole",
					limb = "RightFoot",
					size = { 1.12, 0.35, 1.16 },
					at = { 0, -0.75, 0.04 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "LGreave",
					limb = "LeftLowerLeg",
					size = { 1.2, 0.8, 1.2 },
					at = { 0, 0.1, 0 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "LGreaveRim",
					limb = "LeftLowerLeg",
					size = { 1.24, 0.1, 1.24 },
					at = { 0, 0.46, 0 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "LStrap",
					limb = "LeftLowerLeg",
					size = { 1.26, 0.14, 1.26 },
					at = { 0, -0.2, 0 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "LBoot",
					limb = "LeftFoot",
					size = { 1.2, 1.5, 1.14 },
					at = { 0, 0.3, -0.06 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "LToe",
					limb = "LeftFoot",
					size = { 1.1, 0.9, 0.5 },
					at = { 0, 0, -0.7 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "LCoil1",
					limb = "LeftLowerLeg",
					size = { 0.62, 0.1, 0.26 },
					at = { 0, -0.3, 0.78 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "LCoil2",
					limb = "LeftLowerLeg",
					size = { 0.62, 0.1, 0.26 },
					at = { 0, -0.52, 0.78 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "LCoil3",
					limb = "LeftLowerLeg",
					size = { 0.62, 0.1, 0.26 },
					at = { 0, -0.74, 0.78 },
					color = PALETTE.plate,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "LPost1",
					limb = "LeftLowerLeg",
					size = { 0.1, 0.62, 0.1 },
					at = { -0.22, -0.52, 0.78 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "LPost2",
					limb = "LeftLowerLeg",
					size = { 0.1, 0.62, 0.1 },
					at = { 0.22, -0.52, 0.78 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "LPiston",
					limb = "LeftLowerLeg",
					size = { 0.16, 0.5, 0.16 },
					at = { 0, 0.18, 0.74 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.45,
				},
				{
					name = "LSole",
					limb = "LeftFoot",
					size = { 1.12, 0.35, 1.16 },
					at = { 0, -0.75, 0.04 },
					color = PALETTE.wrap,
					material = "Leather",
				},
			},
		},
	},
	{
		id = "jammer",
		category = "utility",
		cost = 4,
		name = "Brouilleur",
		summary = "Annule les révélations ennemies dans une zone",
		-- Le contre du Traqueur, du Parasite, de la balise et du detecteur. Il
		-- ne rend invisible personne : il efface ce qui avait ete revele, et
		-- empeche de reveler tant qu'il tient.
		use = {
			kind = "zone",
			effect = "jam",
			charges = 1,
			seconds = 16,
			radiusStuds = 26,
		},
		look = {
			offhand = { 0, -0.45, -0.2 },
			pieces = {
				{
					name = "Case",
					size = { 0.46, 0.6, 0.22 },
					at = { 0, 0, 0 },
					color = PALETTE.iron,
					material = "Plastic",
				},
				{
					name = "Bezel",
					size = { 0.48, 0.62, 0.05 },
					at = { 0, 0, -0.12 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.2,
				},
				{
					name = "Screen",
					size = { 0.34, 0.3, 0.04 },
					at = { 0, 0.1, -0.15 },
					color = PALETTE.alert,
					material = "Neon",
				},
				{
					name = "Grip",
					size = { 0.3, 0.2, 0.26 },
					at = { 0, -0.38, 0.02 },
					color = PALETTE.wrap,
					material = "Leather",
				},
				{
					name = "Dial",
					size = { 0.08, 0.14, 0.14 },
					at = { -0.12, -0.18, -0.14 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.35,
				},
				{
					name = "Button",
					size = { 0.1, 0.08, 0.06 },
					at = { 0.12, -0.18, -0.14 },
					color = PALETTE.alert,
					material = "SmoothPlastic",
				},
				{
					name = "Mast1",
					size = { 0.05, 0.56, 0.05 },
					at = { -0.16, 0.56, 0.04 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Tip1",
					size = { 0.09, 0.09, 0.09 },
					at = { -0.16, 0.84, 0.04 },
					shape = "Ball",
					color = PALETTE.alert,
					material = "Neon",
				},
				{
					name = "Mast2",
					size = { 0.05, 0.56, 0.05 },
					at = { 0.16, 0.56, 0.04 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Tip2",
					size = { 0.09, 0.09, 0.09 },
					at = { 0.16, 0.84, 0.04 },
					shape = "Ball",
					color = PALETTE.alert,
					material = "Neon",
				},
				{
					name = "Mast3",
					size = { 0.05, 0.56, 0.05 },
					at = { 0.48, 0.56, 0.04 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Tip3",
					size = { 0.09, 0.09, 0.09 },
					at = { 0.48, 0.84, 0.04 },
					shape = "Ball",
					color = PALETTE.alert,
					material = "Neon",
				},
			},
		},
	},
	{
		id = "incendiaryGrenade",
		category = "utility",
		cost = 4,
		name = "Grenade incendiaire",
		summary = "Crée une zone de feu temporaire",
		-- Elle brule les deux equipes, comme les flammes du Pyromane : une zone
		-- de feu qui saurait qui l'a posee serait un piege magique, pas une
		-- zone de feu.
		use = {
			kind = "zone",
			effect = "burn",
			charges = 1,
			seconds = 12,
			radiusStuds = 13,
			magnitude = 11,
			hurtsOwner = true,
		},
		look = {
			offhand = { 0, -0.4, -0.2 },
			pieces = {
				{
					name = "Body",
					size = { 0.68, 0.34, 0.34 },
					at = { 0, 0.204, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.olive,
					material = "Metal",
					reflectance = 0.1,
				},
				{
					name = "Cap",
					size = { 0.12, 0.357, 0.357 },
					at = { 0, 0.504, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Base",
					size = { 0.12, 0.357, 0.357 },
					at = { 0, -0.096, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
				{
					name = "Band1",
					size = { 0.14, 0.3638, 0.3638 },
					at = { 0, 0.3536, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.alert,
					material = "SmoothPlastic",
				},
				{
					name = "Band2",
					size = { 0.14, 0.3638, 0.3638 },
					at = { 0, 0.0544, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.alert,
					material = "SmoothPlastic",
				},
				{
					name = "Lever",
					size = { 0.1, 0.374, 0.1 },
					at = { 0, 0.2584, -0.1615 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Spoon",
					size = { 0.12, 0.14, 0.14 },
					at = { 0, 0.484, -0.1615 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.3,
				},
				{
					name = "Ring",
					size = { 0.05, 0.22, 0.22 },
					at = { 0.153, 0.564, 0 },
					shape = "Cylinder",
					tipLeft = 90,
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.4,
				},
				{
					name = "Pin",
					size = { 0.16, 0.05, 0.05 },
					at = { 0.0765, 0.564, 0 },
					color = PALETTE.brass,
					material = "Metal",
					reflectance = 0.4,
				},
			},
		},
	},
	{
		id = "healDome",
		category = "utility",
		cost = 4,
		name = "Dôme de soin",
		summary = "Zone qui soigne lentement les alliés",
		-- Quatre points pour quatre-vingt-dix PV rendus si on y reste tout le
		-- temps, ce que personne ne fait. C'est un objet de position : il dit a
		-- son equipe ou se replier, et a l'autre ou aller.
		use = {
			kind = "zone",
			effect = "heal",
			charges = 1,
			seconds = 15,
			radiusStuds = 18,
			magnitude = 6,
			-- Une seconde apres etre sorti, et pas plus : le dome est un objet
			-- de POSITION, donc ce qu'il achete est d'y rester. Une
			-- regeneration qui suivrait le joueur dix secondes ferait de lui
			-- une trousse de soin a quatre points, et plus personne ne se
			-- replierait sur le dome.
			--
			-- Ce chiffre etait absent et retombait sur un repli cache dans
			-- LoadoutService : meme valeur, mais personne ne pouvait la lire
			-- ici. Un test le refuse maintenant.
			holdSeconds = 1,
		},
		look = {
			offhand = { 0, -0.45, -0.25 },
			pieces = {
				{
					name = "Base",
					size = { 0.14, 0.44, 0.44 },
					at = { 0, -0.18, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.cloth,
					material = "SmoothPlastic",
				},
				{
					name = "Rim",
					size = { 0.06, 0.48, 0.48 },
					at = { 0, -0.1, 0 },
					shape = "Cylinder",
					roll = 90,
					color = PALETTE.alert,
					material = "SmoothPlastic",
				},
				{
					name = "Dome",
					size = { 0.42, 0.42, 0.42 },
					at = { 0, -0.06, 0 },
					shape = "Ball",
					color = PALETTE.glass,
					material = "Glass",
					reflectance = 0.35,
				},
				{
					name = "Core",
					size = { 0.16, 0.16, 0.16 },
					at = { 0, -0.04, 0 },
					shape = "Ball",
					color = PALETTE.alert,
					material = "Neon",
				},
				{
					name = "CrossV",
					size = { 0.07, 0.24, 0.04 },
					at = { 0, -0.18, -0.22 },
					color = PALETTE.alert,
					material = "SmoothPlastic",
				},
				{
					name = "CrossH",
					size = { 0.2, 0.07, 0.04 },
					at = { 0, -0.18, -0.22 },
					color = PALETTE.alert,
					material = "SmoothPlastic",
				},
				{
					name = "Clamp",
					size = { 0.1, 0.1, 0.12 },
					at = { 0.2, -0.18, 0 },
					color = PALETTE.iron,
					material = "Metal",
					reflectance = 0.25,
				},
			},
		},
	},
}

-- LES AFFINITES DE CLASSE : un point de moins sur deux ou trois objets.
--
-- Trois objets par classe, exactement comme la fiche les donne. Les affinites
-- etaient provisoires tant que le catalogue n'en comptait que treize : plusieurs
-- classes pointaient vers l'equivalent le plus proche de ce qu'elles devaient
-- avoir, le Vampire ayant la machette plutot que les griffes. Le catalogue est
-- complet, donc ce tableau est maintenant celui de docs/OBJETS.md, sans
-- substitution.
--
-- Aucune affinite ne porte sur un objet a un point : avec la remise il
-- deviendrait gratuit, et un objet gratuit est pris par tout le monde. Un test
-- le verifie, et c'est ce qui interdit de donner le fumigene au Spectre.
Config.itemAffinities = {
	vampire = { "claws", "katana", "poisonDagger" },
	colossus = { "warhammer", "deployableShield", "heavyArmor" },
	tracker = { "compositeBow", "bow", "detector" },
	artificer = { "heavyMine", "grenadeLauncher", "grenade" },
	spectre = { "shuriken", "machete", "springBoots" },
	link = { "transfusion", "healDome", "shortSword" },
	duelist = { "longSword", "heavyRevolver", "springBoots" },
	smith = { "mace", "deployableShield", "exoskeleton" },
	pyromaniac = { "incendiaryGrenade", "grenadeLauncher", "fragVest" },
	decoy = { "smg", "flashbang", "submachineGun" },
	seismic = { "warhammer", "caltrops", "exoskeleton" },
	parasite = { "poisonDagger", "handCrossbow", "sling" },
	chameleon = { "sniperRifle", "knife", "shuriken" },
	medic = { "medkit", "fullHeal", "regenVial" },
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
	-- essentiel, pioches uniquement parmi les objets a cout faible : sinon un
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
	-- COMBIEN DE FOIS ON RELIT UN PROFIL AVANT D'ABANDONNER. Etait en dur dans
	-- `ProgressService` sous le nom `LOAD_ATTEMPTS`. Trois essais espaces de
	-- 1, 2 puis 3 secondes : au-dela, le DataStore est en panne et pas occupe.
	-- Un profil illisible ne devient JAMAIS un profil vide -- c'est la seule
	-- regle de ce fichier qui peut detruire quelque chose d'irremplacable --
	-- donc ce chiffre decide seulement combien de temps on insiste, jamais ce
	-- qu'on ecrit.
	profileLoadAttempts = 3,

	crateCost = 1000,

	-- La touche du panneau des pieces et des caisses. Etait un
	-- `Enum.KeyCode.P` en dur dans le client, hors du test des collisions.
	panelKey = "P",

	winBase = 220,
	winPerRoundNotConceded = 30,

	lossBase = 170,
	lossPerRoundWon = 10,

	-- Sur quoi mesurer la performance : pas sur les eliminations. Dans un mode
	-- ou la manche s'arrete a l'equipe entiere, recompenser les kills pousse a
	-- jouer pour soi.
	rewardKills = false,
	performanceMetrics = { "damage", "roundsSurvived", "assists" },

	-- Les parties privees ne paient pas, comme elles ne classent pas
	-- (Config.elo.privateMatchesRanked). Les deux vont ensemble et pour la
	-- meme raison : une partie entre amis est une partie d'essai, et un
	-- serveur prive a deux joueurs complaisants ferait tomber une caisse
	-- toutes les trois minutes. C'est le meme garde-fou que le bac a sable,
	-- qui n'existe qu'avec un seul joueur pour que rien ne s'y gagne.
	privateMatchesPay = false,
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
	-- L'INTERRUPTEUR DU PROTOTYPE, et il en est un depuis le 29 octobre 2026.
	-- Avant, ce champ existait sans que personne ne le lise : `MatchService`
	-- prenait `roundsToWin` ci-dessous quoi qu'il arrive, donc le jeu jouait la
	-- longueur du prototype -- premier a deux manches -- pendant que
	-- `Config.match` annoncait premier a quatre sans etre lu par une seule
	-- ligne de code. Une partie de M manches donne M points d'arbre et un
	-- palier 6 en coute six a lui seul : les paliers 5 et 6 etaient donc
	-- INATTEIGNABLES, ce qui ne se voit jamais en jouant.
	--
	-- A `false`, la longueur vient de `Config.match`. Le remettre a `true`
	-- rejoue les trois manches de l'etape 2, et c'est le seul mot a changer.
	--
	-- CE QUI RESTE LU DANS CETTE TABLE QUOI QU'IL ARRIVE : `classes` (la classe
	-- de secours quand le tirage ne sert pas tout le monde) et les trois
	-- `seconds...` (les temps d'attente de la boucle de partie). Seul
	-- `roundsToWin` est sous l'interrupteur.
	enabled = false,
	classes = { "vampire", "colossus" },

	-- Premier a deux manches gagnees, donc trois manches au maximum. N'est lu
	-- que quand `enabled` vaut `true`.
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

	-- LA LIGNE DE VUE. Jusqu'au 4 novembre 2026, une attaque prenait l'ennemi
	-- le plus proche dans la portee, SANS regarder s'il y avait un mur entre
	-- les deux : un fusil a soixante studs tirait a travers le decor, et tout
	-- le travail de couverture des quatre maps ne protegeait de rien. La
	-- cible est maintenant le plus proche ennemi EN VUE. L'interrupteur existe
	-- pour comparer, comme la zone et l'agonie.
	requireLineOfSight = true,
	-- La hauteur, au-dessus de la racine du personnage, d'ou part et ou arrive
	-- le rayon : la poitrine haute. Un couvert a hauteur de taille laisse donc
	-- tirer par-dessus, un mur non.
	lineOfSightHeightStuds = 1.5,

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
-- CE QUI COLLE A UN COMBATTANT
--------------------------------------------------------------------------------

-- Les quatre effets temporaires — ralentissement, etourdissement, poison,
-- regeneration — que onze objets du catalogue posent. Leurs durees et leurs
-- forces sont dans les objets eux-memes ; ici ne vivent que les bornes
-- communes, pour la meme raison que les planchers de Modifiers : une borne
-- semee dans onze objets ne se relit pas.
Config.status = {
	-- Le plancher de vitesse. Un ralentissement ne peut pas descendre en
	-- dessous, meme pose par l'objet le plus fort : en dessous d'un tiers de sa
	-- vitesse, un joueur ne joue plus, il attend. L'immobilisation existe, elle
	-- s'appelle etourdissement et elle se paie trois points.
	minSpeedRatio = 0.35,

	-- Le plafond d'etourdissement. Aucun objet ne depasse une seconde et demie
	-- aujourd'hui ; ce chiffre existe pour que ca reste vrai si un jour on en
	-- ajoute un, parce que c'est le seul effet qui retire ses commandes au
	-- joueur.
	maxStunSeconds = 2,

	-- A quelle frequence les poisons et les regenerations retirent ou rendent
	-- des PV. Quatre fois par seconde : assez pour que ca se voie monter, assez
	-- peu pour ne pas noyer l'ecran de nombres.
	tickSeconds = 0.25,
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

-- Chaque effet nomme du dernier palier a ses chiffres ici. Les quarante-deux
-- sont maintenant executes : le dernier qui attendait, celui du Monolithe,
-- promettait une « immunite aux projectiles » dans un jeu ou RIEN NE VOLE. Il
-- promet maintenant l'immunite aux EXPLOSIONS, ce que les sortes de degat
-- rendent possible, et ce qui est la lecture la plus proche de son intention :
-- une classe qui s'ancre pour ne plus craindre ce qui arrive de loin.
--
-- C'est une decision prise sans Josh, et elle est notee dans docs/DECISIONS.md.
Config.tier6 = {
	-- Monolithe : s'ancrer deux secondes rend insensible aux explosions —
	-- grenades, mines, lance-grenades, hachette de lancer. Deux secondes parce
	-- que c'est assez long pour etre un choix (on renonce a se deplacer) et
	-- assez court pour etre atteignable dans un combat reel.
	blastImmunity = {
		stillSeconds = 2,
		-- En dessous de cette vitesse, on compte comme immobile. Pas zero : un
		-- personnage pose sur un sol irregulier derive de quelques centiemes,
		-- et une condition a zero exact ne se declencherait jamais.
		speedThreshold = 1.5,
	},

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

	-- Peste : la propagation ignore les armures. UN, et pas 0,5 comme l'arc
	-- composite : le libelle du palier dit « ignore », pas « traverse une
	-- partie », et un palier 6 qui coute deux points doit valoir davantage
	-- qu'une arme a six points. Ca ne touche que la propagation — le coup qui
	-- la declenche reste reduit normalement, sinon la branche deviendrait un
	-- contre universel aux armures au lieu d'un contre aux groupes armures.
	spreadPiercesArmor = {
		pierceRatio = 1,
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

		-- LES SIX QUI MANQUAIENT. Toutes ces pistes viennent de la
		-- bibliotheque officielle de Roblox (ProSoundEffects) : elle est
		-- libre d'usage et sa duree est annoncee au dixieme de seconde, ce
		-- qui est le seul critere que je puisse verifier sans oreille.

		-- Le soin ne sonne QUE pour un soin voulu — un stimulant, une
		-- trousse. Le vol de vie du Vampire passe par le meme message et
		-- s'annonce a chaque coup porte : un carillon par coup, et le son du
		-- combat disparait dessous. C'est le serveur qui tranche, parce que
		-- le client ne peut pas distinguer les deux.
		heal = {
			assets = { "9116394545", "9116394876" },
			volume = 0.45,
			pitch = { 0.95, 1.08 },
			maxSeconds = 1.2,
		},

		-- Un relevement est rare et il compte : il s'entend en entier.
		revive = { assets = { "9117885276" }, volume = 0.6, pitch = { 0.97, 1.05 } },

		-- La brulure de zone revient toutes les secondes
		-- (`Config.round.zoneNumberIntervalSeconds`), donc la piste est
		-- coupee bien avant la suivante : sans ca, deux brulures se
		-- superposent et le son devient un grondement continu qui ne
		-- previent plus de rien.
		zoneBurn = {
			assets = { "9126221312", "9126219755" },
			volume = 0.4,
			pitch = { 0.9, 1.1 },
			maxSeconds = 0.8,
		},

		-- Le clic de l'interface est le seul son qu'on entend des dizaines de
		-- fois par partie : il est volontairement le plus discret du
		-- catalogue.
		uiClick = {
			assets = { "9119717523", "9119717529" },
			volume = 0.35,
			pitch = { 0.96, 1.06 },
		},

		-- Le debut d'une manche est un coup de cloche clair ; la fin, une
		-- cloche grave. Les deux sont coupees : la piste de fin dure vingt et
		-- une secondes, et une manche enchaine sur la suivante.
		roundStart = {
			assets = { "9116224192" },
			volume = 0.55,
			pitch = { 0.98, 1.02 },
			maxSeconds = 2,
		},
		roundEnd = {
			assets = { "9126005605" },
			volume = 0.5,
			pitch = { 0.98, 1.02 },
			maxSeconds = 2.5,
		},

		-- La caisse. C'est le seul son de recompense du jeu, donc il a le
		-- droit de durer.
		crate = { assets = { "9125644661" }, volume = 0.5, pitch = { 0.95, 1.05 } },
	},

	-- L'impact arrive JUSTE APRES le depart du coup, pas en meme temps. Sans
	-- ce decalage les deux sons se superposent et on n'entend qu'une bouillie ;
	-- avec, l'oreille entend un geste puis sa consequence.
	hitDelaySeconds = 0.05,
}

-- LE BAC A SABLE.
--
-- Une partie a deux joueurs minimum, et Josh est souvent seul : la boucle de
-- partie l'attendait indefiniment, donc il n'y avait aucun moyen d'essayer une
-- classe, une arme ou un pouvoir sans trouver un deuxieme joueur. Le bac a
-- sable est cette salle d'entrainement — il remplace la boucle de partie quand
-- on est seul, et lui rend la main des qu'un deuxieme joueur arrive.
--
-- CE QU'IL N'EST PAS : un bot. Tout le combat est indexe par `Player`, et un
-- adversaire qui se bat vraiment demanderait de rendre generique le roster du
-- combat, de l'equipement, de l'arbre et de l'agonie d'un seul coup. Et il ne
-- repondrait pas a la question qui compte : un bot dit qu'une mecanique
-- fonctionne, il ne dit jamais qu'un duel est tendu. Le mannequin ci-dessous
-- est une cible, pas un adversaire.
--
-- CE BLOC DONNE DES POUVOIRS QUI N'ONT RIEN A FAIRE EN PARTIE : choisir sa
-- classe, s'offrir des points d'arbre, depasser le budget de douze points.
-- Trois garde-fous, et ils se verifient a chaque ouverture :
--   1. `enabled` ici,
--   2. on est SEUL (`maxPlayers`),
--   3. on est en partie privee ou dans Studio (`privateOnly`).
-- Le deuxieme est le plus solide : aucun classement, aucune piece et aucune
-- partie ne peut exister avec un seul joueur, donc rien de ce qui se gagne
-- n'est atteignable depuis ici.
-- LE CORPS STANDARD DE L'ARENE
--
-- Un avatar Roblox peut etre un pigeon de trois studs, un geant, ou un
-- maillage qui n'a plus rien d'humain. Dans un jeu PvP ou lire son adversaire
-- fait partie du savoir jouer, ces corps-la ne se lisent pas pareil — et ca
-- n'a aucun rapport avec l'habilete de qui que ce soit. C'est le sixieme
-- principe applique au corps.
--
-- La question est devenue concrete avec l'armure : une armure portee se fixe
-- aux parts du personnage et se met a l'echelle de LEUR taille, alors qu'un
-- bundle remplace leur MAILLAGE. L'armure disparait donc sous l'oiseau.
--
-- Decide par Josh le 28 octobre 2026. Le detail du raisonnement, et ce qui a
-- ete tranche sans lui, sont dans docs/DECISIONS.md.
Config.body = {
	enabled = true,

	-- LES SIX ECHELLES, avec la valeur qui redonne le corps classique. Les
	-- deux dernieres valent ZERO et pas un : `BodyTypeScale` fait glisser le
	-- corps vers les proportions « Rthro », et `ProportionScale` l'affine.
	-- A zero on retrouve le corps anguleux, qui est celui contre lequel les
	-- armures et les armes sont dessinees.
	scales = {
		HeightScale = 1,
		WidthScale = 1,
		DepthScale = 1,
		HeadScale = 1,
		BodyTypeScale = 0,
		ProportionScale = 0,
	},

	-- Les six parties qu'un bundle remplace. A zero, Roblox remet les parts
	-- classiques.
	bodyParts = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" },

	-- LES VETEMENTS RESTENT CEUX DU JOUEUR. Une chemise ne change pas une
	-- silhouette, donc elle ne coute rien a la lecture — et c'est elle qui
	-- portera les skins. Un skin ne se voit que si le corps en dessous est
	-- previsible, donc imposer le corps rend les skins VISIBLES au lieu de les
	-- noyer.
	keepClothing = true,

	-- LES ACCESSOIRES, EUX, PARTENT, et c'est un choix fait sans Josh : un
	-- chapeau de dix studs cache une ligne de vue et change ce qu'on croit
	-- voir arriver. C'est le seul reglage de cette table qui soit discutable
	-- plutot que technique — le passer a `true` le rend aux joueurs, et rien
	-- d'autre ne bouge.
	keepAccessories = false,

	-- Combien de fois on reessaie d'appliquer le corps. `ApplyDescription`
	-- part sur le reseau et peut echouer : trois essais espaces valent mieux
	-- qu'un joueur qui garde son pigeon toute la partie parce qu'un paquet
	-- s'est perdu.
	-- Cinq essais, pas trois : au tout premier chargement d'un personnage, les
	-- maillages de son avatar arrivent encore du reseau et `ApplyDescription`
	-- refuse tant qu'ils manquent. Vu en jeu le 28 octobre 2026 — trois essais
	-- espaces d'une demi-seconde n'y suffisaient pas, et le joueur gardait son
	-- avatar d'origine toute la partie.
	applyAttempts = 5,
	retrySeconds = 1,
}

Config.sandbox = {
	enabled = true,

	-- Seul, et seulement seul. Un deuxieme joueur rend la main a la vraie
	-- boucle de partie, sans rien demander a personne.
	maxPlayers = 1,

	-- En partie publique, non — par prudence et pas par necessite. Un serveur
	-- public avec un seul joueur est une salle d'attente, et y mettre un stand
	-- de tir a la place de l'ecran « en attente » serait sans doute mieux pour
	-- le joueur. C'est une decision de conception, donc elle revient a Josh :
	-- passer ce reglage a false suffit.
	privateOnly = true,

	-- La classe au demarrage. Le Vampire parce que c'est la classe de
	-- reference du prototype : sa faiblesse se sent tout de suite.
	startingClassId = "vampire",

	-- Combien de points d'arbre un clic donne. Un par clic plutot qu'un gros
	-- paquet : monter l'arbre palier par palier est justement ce qu'on veut
	-- pouvoir refaire a la main.
	treePointsPerGrant = 1,

	-- LE BUDGET RELEVE. Soixante points au lieu de douze, et dix objets au lieu
	-- de six. Ce n'est pas un equilibrage, c'est l'inverse : le but est de
	-- pouvoir porter le marteau ET le fusil pour les comparer dans la meme
	-- minute, ce que douze points interdisent. Rien de ce qui se decide ici ne
	-- sort du bac a sable.
	budgetPoints = 60,
	maxItems = 10,

	-- Les limites par categorie restent presque les memes, et pas par
	-- timidite : une deuxieme arme principale ne servirait a rien de plus,
	-- puisque la secondaire ne sort que quand la cible est hors de portee de la
	-- principale. Seuls les soins s'empilent davantage, pour tester une rafale
	-- de trousses.
	maxPerCategory = {
		primary = 1,
		secondary = 1,
		armor = 1,
		heal = 4,
	},

	-- Combien de temps on reste au sol avant d'etre remis debout. Personne ne
	-- peut relever personne quand on est seul, donc l'agonie se termine
	-- toujours ainsi — mais elle a bien lieu, et c'est le seul moyen de la
	-- regarder sans un deuxieme joueur.
	reviveSeconds = 3,

	-- La zone est coupee au depart. Elle se rallume d'un clic, mais commencer
	-- par elle serait absurde : on vient tester une arme, pas courir.
	zoneOnByDefault = false,

	-- La fenetre de depense reste ouverte en permanence, re-ouverte par la
	-- boucle quand elle expire. Consequence assumee : acheter des PV maximum
	-- SOIGNE, ce qui est interdit en partie (Config.skillTree.spendingDuringRound
	-- existe pour ca). Dans un bac a sable c'est exactement ce qu'on veut.
	spendWindowSeconds = 3600,

	-- LE MANNEQUIN D'ENTRAINEMENT.
	dummy = {
		-- Les statistiques d'une vraie classe, pas un sac de PV invente. C'est
		-- ce qui rend le chiffre utile : « combien de coups de machette pour un
		-- Colosse » est une vraie reponse, pas une approximation. Le Colosse
		-- par defaut parce qu'il encaisse le plus longtemps.
		classId = "colossus",

		-- Quatre au maximum. Au-dela on ne sait plus lequel on frappe, et la
		-- recherche de cible prend le plus proche.
		maxCount = 4,
		startingCount = 1,

		-- Ou ils apparaissent : devant le joueur, alignes. Seize studs parce
		-- que c'est au-dela de la portee du couteau (10) et en dessous de celle
		-- de l'arc (60) : on doit avoir a avancer pour le corps-a-corps et pas
		-- pour le tir.
		distanceStuds = 16,
		spacingStuds = 7,

		-- Il revient tout seul apres sa mort. Sans ca, la premiere serie de
		-- coups vide le stand de tir.
		respawnSeconds = 4,
	},

	-- La touche qui ouvre le panneau. B pour « bac a sable ».
	toggleKey = "B",
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
		-- Les deux reductions par sorte de degat. A zero pour tout le monde : une
		-- classe n'en porte jamais, seules deux armures du catalogue en donnent.
		blastTakenRatio = 0,
		dotTakenRatio = 0,
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
		-- Les deux reductions par sorte de degat. A zero pour tout le monde : une
		-- classe n'en porte jamais, seules deux armures du catalogue en donnent.
		blastTakenRatio = 0,
		dotTakenRatio = 0,
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
		-- Les deux reductions par sorte de degat. A zero pour tout le monde : une
		-- classe n'en porte jamais, seules deux armures du catalogue en donnent.
		blastTakenRatio = 0,
		dotTakenRatio = 0,
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
		-- Les deux reductions par sorte de degat. A zero pour tout le monde : une
		-- classe n'en porte jamais, seules deux armures du catalogue en donnent.
		blastTakenRatio = 0,
		dotTakenRatio = 0,
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
		-- Les deux reductions par sorte de degat. A zero pour tout le monde : une
		-- classe n'en porte jamais, seules deux armures du catalogue en donnent.
		blastTakenRatio = 0,
		dotTakenRatio = 0,
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
		-- Les deux reductions par sorte de degat. A zero pour tout le monde : une
		-- classe n'en porte jamais, seules deux armures du catalogue en donnent.
		blastTakenRatio = 0,
		dotTakenRatio = 0,
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
		-- Les deux reductions par sorte de degat. A zero pour tout le monde : une
		-- classe n'en porte jamais, seules deux armures du catalogue en donnent.
		blastTakenRatio = 0,
		dotTakenRatio = 0,
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
		-- Les deux reductions par sorte de degat. A zero pour tout le monde : une
		-- classe n'en porte jamais, seules deux armures du catalogue en donnent.
		blastTakenRatio = 0,
		dotTakenRatio = 0,
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
		-- Les deux reductions par sorte de degat. A zero pour tout le monde : une
		-- classe n'en porte jamais, seules deux armures du catalogue en donnent.
		blastTakenRatio = 0,
		dotTakenRatio = 0,
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
		-- Les deux reductions par sorte de degat. A zero pour tout le monde : une
		-- classe n'en porte jamais, seules deux armures du catalogue en donnent.
		blastTakenRatio = 0,
		dotTakenRatio = 0,
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
		-- Les deux reductions par sorte de degat. A zero pour tout le monde : une
		-- classe n'en porte jamais, seules deux armures du catalogue en donnent.
		blastTakenRatio = 0,
		dotTakenRatio = 0,
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
		-- Les deux reductions par sorte de degat. A zero pour tout le monde : une
		-- classe n'en porte jamais, seules deux armures du catalogue en donnent.
		blastTakenRatio = 0,
		dotTakenRatio = 0,
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
		-- Les deux reductions par sorte de degat. A zero pour tout le monde : une
		-- classe n'en porte jamais, seules deux armures du catalogue en donnent.
		blastTakenRatio = 0,
		dotTakenRatio = 0,
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
		-- Les deux reductions par sorte de degat. A zero pour tout le monde : une
		-- classe n'en porte jamais, seules deux armures du catalogue en donnent.
		blastTakenRatio = 0,
		dotTakenRatio = 0,
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

	-- LES CHIFFRES DES PALIERS 6, sortis d'`AbilityService` le 4 novembre 2026
	-- ou ils etaient ecrits en dur — dix-neuf valeurs que personne ne pouvait
	-- regler sans lire le service. Les valeurs sont celles du code, inchangees :
	-- ce deplacement n'est PAS un reequilibrage.
	tier6 = {
		-- Mine (Artificier) : le proprietaire saute plus haut qu'il n'est pousse
		-- de cote, parce que la mine est un tremplin et pas une arme contre soi.
		mineSelfUpRatio = 1.4,
		mineSelfDashStuds = 10,
		-- Traversee (Spectre) : le souffle de sortie couvre une piece, pas une
		-- map. Degats d'un coup ordinaire : la surprise fait le travail.
		phaseExitBurstRadiusStuds = 14,
		-- Mur (Forgeron) : pose a six studs devant soi, assez pour ne pas
		-- s'enfermer dedans.
		wallForwardStuds = 6,
		-- Mur brulant : la moitie d'un coup par seconde, sur une zone un peu
		-- plus large que le mur pour qu'on brule en le longeant.
		wallBurnDamageRatio = 0.5,
		wallBurnRadiusRatio = 0.6,
		-- Clone (Leurre) : cinq studs, assez pour qu'on hesite entre les
		-- deux silhouettes, pas assez pour qu'elles se lisent comme deux joueurs.
		cloneOffsetStuds = 5,
		cloneBurstRadiusStuds = 12,
		-- Onde de choc (Sismique) : le palier qui fait mal au sol en fait la moitie
		-- d'un coup, parce qu'il touche tout le monde a la fois.
		slamDamageRatio = 0.5,
		-- Communion (Lien) : la moitie seulement. Un partage integral ferait de
		-- chaque soin un soin double, et deux Liens qui se soignent l'un
		-- l'autre deviendraient impossibles a tuer.
		bondShareRatio = 0.5,
		-- Symbiose (Parasite) : un blesse sous la moitie de sa vie se voit, une
		-- seconde et demie, renouvelee tant qu'il le reste.
		woundedRevealHealthRatio = 0.5,
		woundedRevealSeconds = 1.5,
		-- Pas de loup (Cameleon) : marcher sous les trois quarts de sa vitesse ne revele
		-- plus. A pleine vitesse, la faiblesse de la classe reste entiere.
		stalkWalkSpeedRatio = 0.75,
		-- Riposte (Duelliste) : +8 % par coup encaisse, plafonne a +40 %, soit cinq coups.
		riposteBonusPerStack = 0.08,
		riposteBonusMax = 0.4,
		-- Coup revelateur (Traqueur) : dix secondes, la duree d'une poursuite.
		hitRevealSeconds = 10,
		-- Brasier colle (Pyromane) : une flaque de trois studs, trois secondes,
		-- a la moitie du feu ordinaire.
		clingingFireSeconds = 3,
		clingingFireRadiusStuds = 3,
		clingingFireDamageRatio = 0.5,
		-- Marque vampirique (Parasite) : quarante pour cent des degats portes
		-- au marque reviennent en vie.
		markLifestealRatio = 0.4,
		-- Relevement a distance (Infirmier) : quatre fois la portee normale.
		remoteReviveRangeRatio = 4,
		-- Champ regenerant : quatre PV par seconde dans un rayon de 24 studs.
		fieldRegenRadiusStuds = 24,
		fieldRegenPerSecond = 4,
	},
}

--------------------------------------------------------------------------------
-- LE RESEAU
--------------------------------------------------------------------------------

Config.network = {
	-- Le debit qu'un client peut tenir sur un remote d'interface (salon, menu,
	-- caisses, bac a sable, tirage, equipement). Un seau de douze jetons qui se
	-- remplit de huit par seconde : un humain qui clique comme un forcene
	-- plafonne vers six, et une rafale de douze couvre un panneau qui envoie
	-- plusieurs messages d'un meme geste. Au-dela, c'est un script.
	remoteThrottle = { burst = 12, perSecond = 8 },
}

--------------------------------------------------------------------------------
-- LA ROTATION DES MAPS
--------------------------------------------------------------------------------

-- Sept maps et une seule jouee : `MapService` prenait la premiere map conforme
-- de Workspace, et chaque recette detruit les autres. Les maps se rangent
-- maintenant dans `ServerStorage` par `tools/StashMap.luau`, avec leur
-- eclairage, et la partie suivante en sort une. Sans dossier de rangement,
-- rien ne change : la map de Workspace est jouee, comme avant.
Config.maps = {
	rotate = true,
	-- Le dossier de ServerStorage ou attendent les maps rangees.
	storageFolder = "ArenaMaps",
	-- Le dossier, DANS chaque map, qui porte son eclairage : les reglages de
	-- `Lighting` en attributs, et des copies des effets et des nuages.
	lightingFolder = "ArenaLighting",
	-- Les reglages de `Lighting` qu'une recette pose et qu'il faut donc
	-- remettre avec la map. Une seule liste, lue a la fois par le rangement et
	-- par la rotation : deux listes qui doivent s'accorder divergent toujours.
	lightingProperties = {
		"ClockTime",
		"GeographicLatitude",
		"Brightness",
		"Ambient",
		"OutdoorAmbient",
		"ColorShift_Top",
		"ColorShift_Bottom",
		"ExposureCompensation",
		"FogStart",
		"FogEnd",
		"FogColor",
		"GlobalShadows",
		"ShadowSoftness",
		"EnvironmentDiffuseScale",
		"EnvironmentSpecularScale",
	},
	-- Les effets qu'une recette pose dans `Lighting` (et `Clouds`, qui vit sous
	-- le Terrain). Ceux-la sont retires avant de poser ceux de la map choisie.
	lightingEffects = {
		"Atmosphere",
		"Sky",
		"BloomEffect",
		"ColorCorrectionEffect",
		"SunRaysEffect",
		"DepthOfFieldEffect",
		"BlurEffect",
		"Clouds",
	},
	-- Ou les variantes de matiere generees des maps rangees attendent. Chaque
	-- recette DETRUIT le dossier `ArenaMaterials` en construisant : sans ce
	-- second dossier, ranger une map puis en construire une autre effacerait
	-- les matieres de la premiere.
	materialsKeepFolder = "ArenaMaterialsKeep",
}

Config.mapContract = {
	spawnsFolderTeamA = "SpawnsA",
	spawnsFolderTeamB = "SpawnsB",
	spawnPointsPerTeam = 5,
	zoneCenterPart = "ZoneCenter",
	coverFolder = "Cover",
	boundsPart = "MapBounds",

	-- LA MAP DE SECOURS, quand aucune map conforme n'est dans Workspace. Ces
	-- trois chiffres etaient en dur dans `MapService`, ce qui est un bug meme
	-- quand les valeurs sont bonnes : personne ne peut regler une map vide sans
	-- lire le service. Trouve au controle du 29 octobre 2026.
	--
	-- 10 studs entre deux points d'apparition : un personnage fait 4 studs de
	-- large, donc dix laissent passer deux joueurs cote a cote sans qu'ils se
	-- poussent a l'apparition. 35 studs du centre, soit 70 entre les deux
	-- camps : assez pour se voir arriver, trop peu pour se perdre, et c'est
	-- volontairement plus serre que les vraies maps parce qu'une map vide n'a
	-- rien a traverser. 4 studs de haut pose les pieds au sol d'une part de
	-- 1 stud d'epaisseur.
	fallbackSpawnSpacingStuds = 10,
	fallbackSpawnDistanceFromCenterStuds = 35,
	fallbackSpawnHeightStuds = 4,
}

return Config
