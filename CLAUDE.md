# Arena — notes pour l'assistant

Jeu PvP d'arène sur Roblox. Deux équipes s'affrontent en manches : la classe est
tirée au sort après une phase de bans, et l'arbre de compétences se construit
manche après manche avant d'être remis à zéro à la partie suivante.

**La conception est close.** Le cahier des charges complet, avec toutes les
décisions et leurs justifications, est la fiche « Arena — PvP à classes et
progression définitive ». Ce qui reste est du travail de construction. Si une
question de conception se pose, elle se tranche avec Josh, pas dans le code.

## Qui fait quoi

| | Rôle |
| --- | --- |
| L'assistant | Tout le code Luau, la structure du repo, la configuration, les tests, et la construction dans Studio |
| Josh | Les parties réelles avec des joueurs, le jugement sur le plaisir de jeu, la publication |

**Depuis le 25 octobre 2026, l'assistant atteint Studio directement** par le
serveur MCP de Studio : il lit l'arborescence de la place, la console et les
scripts, exécute du Luau, construit de la géométrie, génère des matériaux et des
maillages, et lance une partie de test tout seul. La procédure d'installation est
l'étape 9 du `README.md`.

Ce qui reste à Josh, et que rien ne remplace : **savoir si c'est amusant**, et le
vérifier à plusieurs. Un test en solo dans Studio dit qu'une mécanique
fonctionne ; il ne dit pas qu'un duel est tendu, ni qu'une classe est
frustrante. Donc l'habitude à garder : quand une mécanique est écrite et
vérifiée en jeu par l'assistant, dire à Josh ce qu'il faut regarder en y jouant,
et dans quel ordre.

Deux prudences, parce que l'accès direct est destructeur :

- **Publier une version de la place avant une grosse opération.** Tout n'est pas
  annulable depuis Studio.
- **Ne rien construire dans `Workspace` qui doive durer sans le dire à Josh.**
  La frontière Rojo / Team Create ci-dessous ne change pas : les maps restent
  hors de Git, donc une map construite par l'assistant n'existe que dans la
  place, et une seule mauvaise manipulation la supprime sans trace.

## Les six principes à ne jamais casser

C'est là que les erreurs coûtent le plus cher, parce qu'elles ne se voient
qu'une fois le jeu déséquilibré.

1. La puissance d'un objet est portée par son **coût en points**, jamais par sa
   rareté ni par l'ancienneté du joueur
2. Aucun achat ne donne de puissance : les Robux achètent des skins et des
   pièces de tirage, jamais une arme directement
3. L'arbre de compétences est **remis à zéro à chaque partie**, il ne porte
   aucune progression de compte
4. Les paliers donnent des **options**, pas de la puissance brute
5. Deux exemplaires du même objet sont **strictement identiques**, quel que soit
   leur propriétaire
6. Chaque classe a une **faiblesse** qui compense son pouvoir, et cette
   faiblesse n'est pas décorative

## Architecture

**La logique pure ne touche à aucune API Roblox.** Calcul de l'arbre, budget
d'équipement, tirages, Elo, économie des pièces : tout ça vit dans des modules
qui ne connaissent ni `game`, ni `Instance`, ni `Player`. Seule une couche mince
manipule les personnages et les parts. C'est ce qui permet de vérifier le travail
en ligne de commande avec Lune, sans Studio.

**Un module de logique pure ne requiert rien.** Ses dépendances arrivent en
argument : `SkillTree.usablePoints(config, roundsPlayed)` et pas un
`require(script.Parent.Config)` caché à l'intérieur. Deux raisons : Roblox
résout les `require` par arborescence d'instances (`script.Parent.X`) et Lune par
chemin de fichier (`./X`), donc un module qui requiert un autre module ne peut
pas se charger des deux côtés ; et passer la configuration en argument permet aux
tests d'injecter des chiffres modifiés.

**Tous les chiffres vont dans `src/shared/Config.luau`**, jamais en dur dans le
code. Ils seront modifiés des dizaines de fois pendant les tests. Un chiffre
écrit en dur dans un module est un bug, même si la valeur est bonne.

```
src/shared/     ReplicatedStorage.Arena  — logique pure et données partagées
src/server/     ServerScriptService.Arena — autorité : état de la partie, calculs
src/client/     StarterPlayerScripts.Arena — interface et entrées joueur
tests/          suites Lune, hors du projet Rojo (jamais synchronisées)
```

Le serveur est l'autorité sur tout ce qui compte : classe tirée, points d'arbre,
budget validé, pièces gagnées. Le client affiche et envoie des intentions.

## La frontière Rojo / Team Create

| Propriétaire | Ce qu'il possède |
| --- | --- |
| Rojo (ce repo) | `ServerScriptService`, `ReplicatedStorage`, `StarterPlayer` |
| Team Create (Studio) | `Workspace` — les maps se construisent, elles ne se codent pas |

Ne jamais ajouter `Workspace` à `default.project.json` : Rojo écraserait le
travail de construction. Les maps ne sont pas dans Git, et le fichier `.rbxl`
non plus.

**Les maps se sauvegardent en recette, pas en fichier.** Une map n'est ni dans
Git ni dans Rojo : elle n'existe que dans la place, et une fausse manoeuvre la
supprime sans trace. La parade est `tools/`, qui contient un script par map —
`tools/BuildArenaMap.luau` pour l'arène de duel. On le colle dans la barre de
commande de Studio et il reconstruit tout à l'identique, en détruisant d'abord
la version précédente. `tools/` est hors du projet Rojo et hors de `selene src` :
ce n'est pas du code de jeu, ça ne tourne jamais en partie.

Donc : **toute map construite dans Studio doit repartir avec son script dans
`tools/`**, sinon elle n'est pas sauvegardée.

**Le contrat de nommage** est la seule interface entre le code et les maps.
Chaque map doit contenir `SpawnsA` et `SpawnsB` (cinq points chacun), une part
`ZoneCenter`, un dossier `Cover` et une part `MapBounds`. Les noms exacts sont
dans `Config.mapContract`. Le code vérifie ces noms au démarrage et affiche une
erreur explicite s'il en manque un, pour que la personne qui construit sache
seule si sa map est conforme.

## Conventions

- **Identifiants, noms de fichiers et de modules en anglais** : ils cotoient
  l'API Roblox (`Humanoid.Health`, `Players.PlayerAdded`) et les exemples de la
  communauté.
- **Commentaires en français, sans accents** dans les fichiers `.luau`, pour que
  l'encodage ne pose jamais question entre Studio, Git et les outils. Les
  chaînes affichées (console, interface) gardent leurs accents, et le Markdown
  aussi.
- Un commentaire explique **pourquoi**, pas quoi. Les chiffres de `Config.luau`
  portent chacun la raison de leur valeur : c'est ce qui évite de les « corriger »
  par erreur.
- `--!strict` en tête de chaque fichier.
- Tabulations, 100 colonnes, formatage par StyLua : jamais de mise en forme à la
  main.
- Un seul point d'entrée par côté (`Bootstrap.server.luau`, `Bootstrap.client.luau`),
  qui appelle des modules.

## Les commandes

```sh
rokit install              # installe les outils aux versions du projet
rojo serve                 # synchronise vers Studio (plugin Rojo connecté)
lune run tests/run         # tests de logique pure, sans Studio
stylua .                   # formate
selene src                 # analyse statique
rojo build --output arena.rbxl   # construit une place sans Studio
```

GitHub Actions relance formatage, analyse, tests et build à chaque push.

## Les pièges

- **Un `require` dans un module de logique pure casse les tests Lune.** C'est
  l'erreur la plus facile à commettre et la plus pénible à défaire.
- **Un chiffre en dur** passe les tests et ruine l'équilibrage six semaines plus
  tard. Tout dans `Config.luau`.
- **Rojo peut ajouter un doublon au lieu de remplacer.** Vu le 25 octobre 2026 :
  chaque module ajouté depuis la dernière synchronisation complète existait en
  double dans la place, `Remotes.Tree` compris. Deux RemoteEvent du même nom, et
  `WaitForChild` en désigne un au hasard : le client et le serveur parlent alors
  à deux objets différents, **sans la moindre erreur**. Après avoir ajouté ou
  recréé des fichiers, lister les enfants de `ReplicatedStorage.Arena`,
  `ServerScriptService.Arena` et `StarterPlayerScripts.Arena` avant de conclure
  que quelque chose ne marche pas. Supprimer un fichier et le recréer déclenche
  le problème.
- **Rojo écrase, il ne fusionne pas.** Une modification faite dans Studio sur un
  script synchronisé est perdue à la prochaine synchro. Le code s'écrit dans le
  repo, jamais dans Studio.
- **Les tirages payants sont réglementés par Roblox**, et les exigences sont
  précises. Comme les Robux achètent des pièces de tirage, le tirage est un
  *paid random item* même indirectement. Ce que la politique officielle demande,
  vérifié le 25 octobre 2026 :
  - afficher **chaque** résultat possible et sa probabilité en pourcentage,
    **avant** l'achat, avec un total qui fait exactement 100 % ; l'arrondi est
    permis avec une mention, et les objets de même probabilité peuvent être
    regroupés sous une seule ligne — ce qui simplifie beaucoup notre cas, les
    62 objets étant équiprobables
  - le lien vers ces cotes doit porter un **mot** (« Détails », « Infos ») : une
    icône « (i) » seule est explicitement insuffisante
  - **tout résultat doit donner quelque chose au joueur** : un tirage où il perd
    simplement sa mise est interdit. Notre règle des doublons convertis en
    fragments satisfait déjà ça — ne jamais la retirer sans la remplacer
  - la garantie tous les sept tirages est un modificateur de probabilité : son
    effet doit être expliqué chiffré, et les cotes affichées doivent se mettre à
    jour quand elle est active
  - le blocage régional se fait avec `PolicyService:GetPolicyInfoForPlayerAsync`
    et l'attribut **`ArePaidRandomItemsRestricted`**. Quand il vaut `true`, on
    retire la vente de pièces à ce joueur. Roblox cite explicitement « proposer
    une voie gratuite pour obtenir l'objet » comme alternative acceptable :
    notre économie de pièces gagnées en jouant est cette voie.

  À budgéter dès la conception de l'écran de tirage, pas après. Sources dans
  `docs/EQUILIBRAGE.md`.
- **`execute_luau` a son propre cache de modules.** Le code envoyé par le pont
  MCP ne tourne PAS dans la machine virtuelle du jeu : il a sa propre copie de
  chaque module. Un `require(ZoneService)` depuis `execute_luau` renvoie une
  instance neuve, avec son propre état, sans les connexions que `Bootstrap` a
  branchées. On peut donc démarrer un service et constater qu'il « ne fait
  rien » alors que le code est juste — c'est simplement l'autre copie qui
  tourne. Vérifié le 25 octobre 2026, en faisant répondre les deux contextes à
  la même question : le jeu disait `zone active = false`, `execute_luau` disait
  `true`.

  **Pour piloter les modules du jeu, il faut injecter un `Script`** dans
  `ServerScriptService` et le détruire après : lui tourne dans la bonne machine
  virtuelle. `execute_luau` reste parfait pour inspecter le DataModel (les
  parts, les propriétés, l'arborescence), qui est partagé, lui.

- **Un son Roblox modere, prive ou du mauvais type echoue en SILENCE.** Aucune
  erreur, le son ne sort pas, et le jeu devient muet sans que personne sache
  pourquoi. Le garde-fou est `Audio.verify`, qui recharge tout le catalogue au
  demarrage du client par `ContentProvider:PreloadAsync` avec un rappel de
  statut, et nomme dans la console ce qui n'est pas arrive : ne pas le retirer.
  Avant d'ajouter un identifiant dans `Config.sounds.events`, le charger dans
  Studio et relever sa duree.

- **`Sound.TimeLength` vaut 0 a l'instant ou on pose le son**, meme pour une
  piste deja prechargee : elle arrive de facon asynchrone cote client. Vu le
  26 octobre 2026 — un nettoyage calcule sur `TimeLength` retombait donc
  TOUJOURS sur son repli, et les sons s'empilaient dans le Workspace sans que
  ca s'entende ni se voie. La bonne facon est `sound.Ended`, plus un `Debris`
  en filet.

- **Je ne peux pas ecouter un son.** Le choix se fait sur le nom, la
  bibliotheque d'origine et la DUREE — un « impact » d'une seconde et demie est
  une portiere de voiture. C'est une selection raisonnee, et il faut le dire
  comme tel a Josh : le jugement d'oreille n'existe pas tant qu'il ne l'a pas
  fait. Meme regle que pour l'allure des armes.

- **Le son ne coute aucun message reseau, et ca doit rester vrai.** Le client
  recoit deja chaque coup, chaque chute et chaque explosion avec sa position
  par le remote des effets ; `Audio` se greffe sur ces memes annonces. La seule
  chose que le son a ajoutee au protocole est `voice`, cinq lettres. Un nouveau
  remote pour du son serait une erreur : c'est aussi ce qui garantit que
  l'image et le son partent ensemble, puisqu'ils lisent le meme message.

- **`screen_capture` peut cesser de rendre la 3D, sans la moindre erreur.**
  Vu le 26 octobre 2026 : toutes les captures sont revenues avec l'interface
  intacte et la vue 3D vide, en mode jeu comme en mode edition, et deux
  captures de scenes differentes etaient rigoureusement identiques au pixel.
  Verifie par un temoin plutot que suppose — une part neon rouge de douze
  studs, posee a dix studs devant la camera et confirmee a l'ecran par
  `WorldToViewportPoint`, n'apparait pas sur l'image. Les `ViewportFrame` non
  plus, alors qu'ils sont de l'interface : c'est tout le moteur de rendu qui
  ne produit plus d'image, probablement parce que la fenetre de Studio est
  passee en arriere-plan.

  Donc : **avant de conclure qu'un objet 3D ne s'affiche pas, poser un
  temoin.** Et quand le rendu est gele, il n'y a pas de contournement par
  l'interface — il faut demander a Josh de ramener Studio au premier plan, ou
  verifier par le calcul en le disant comme tel.

- **Un geste anime ne se verifie pas en le relisant.** Deux des quatre
  mouvements d'arme partaient a l'envers le 26 octobre 2026, et les mille
  tests passaient. Le moyen est de calculer ou va la POINTE de l'arme entre le
  repos et le bout du geste, avec de vrais `CFrame`, et de regarder le signe de
  chaque axe : dans Roblox l'avant est -Z, donc un `pitch` positif LEVE la
  pointe et un `yaw` positif la fauche vers la gauche. Ce calcul est fige dans
  `tests/specs/loadout.luau`, et il verifie d'abord qu'il reproduit Roblox
  avant de juger des signes : ne pas retirer cette premiere moitie, c'est elle
  qui rend la seconde credible.

- **Rien de visuel ne touche a l'equilibrage.** Le bloc `look` d'un objet ne
  contient que des tailles, des couleurs et des angles, et aucun de ses
  chiffres n'entre dans un calcul de degats, de portee ou de budget. C'est le
  premier des six principes. Une arme plus grosse n'est pas une arme plus
  forte.

- **`screen_capture` ne photographie pas les `BillboardGui`.** La scène 3D, les
  parts et les `ScreenGui` apparaissent normalement ; tout ce qui est accroché à
  un `BillboardGui` est absent de l'image, sans la moindre erreur. On peut donc
  conclure qu'un affichage ne marche pas alors qu'il marche très bien, et partir
  corriger du code qui n'a rien. Vérifié le 25 octobre 2026 par un témoin : une
  part rouge et un panneau vert créés au même instant, côte à côte, tous deux
  confirmés à l'écran par `WorldToViewportPoint` — la part apparaît sur la
  capture, le panneau non.

  Ça touche les **nombres de dégâts** et le **compte à rebours de l'agonie**.
  Pour les vérifier, il faut interroger le client (`Enabled`, `Visible`,
  `TextTransparency`, `WorldToViewportPoint`) et le dire comme tel — c'est
  vérifié par instrumentation, pas vu de ses yeux — ou demander à Josh.

- **Le taux de doublons pilote deux économies à la fois** : moins de doublons,
  moins de fragments, donc des skins plus rares. Ces deux réglages se changent
  ensemble.
- **Un pouvoir de classe ou un palier 6 déclaré mais pas exécuté ne fait rien,
  en silence.** C'est la même panne que les branches creuses, en plus cher : un
  palier 6 coûte deux points, et il faut une série de sept manches pour le
  voir. Le serveur refuse donc de démarrer si `Config.abilities.registry` ou un
  `tier6.implemented` annonce ce qu'aucun service n'applique. Les deux listes
  de référence sont `HANDLED` et `HANDLED_TIER6` dans `AbilityService` : **en
  ajoutant un pouvoir ou un effet, il faut les tenir à jour**, sinon le serveur
  s'arrête avec un message qui nomme le coupable.
- **`AbilityService` ne requiert jamais `CombatService` ni l'inverse.** Le
  combat a besoin des pouvoirs et les pouvoirs ont besoin d'infliger des
  dégâts : un `require` croisé et Roblox refuse de charger les deux. Le sens
  est `CombatService -> AbilityService`, et les dégâts arrivent par un puits
  que `CombatService` installe au démarrage. Même chose pour le relèvement :
  `AbilityService` pose ses crochets dans `DownedService`, jamais l'inverse.
- **Une branche d'arbre qui pousse un chiffre que le combat ne lit pas ne fait
  rien, mais son sacrifice s'applique quand même.** Trois branches sur six
  étaient dans cet état le 25 octobre 2026, et tous les tests passaient. Un test
  vérifie désormais que toute clé touchée par une branche existe dans les
  statistiques de base de la classe : ne pas le retirer.
- **Ne pas prendre de l'avance sur l'ordre des étapes.** Douze objets suffisent
  à tester si le budget est bon ; s'il n'est pas amusant à douze, il ne le sera
  pas à soixante-deux.
- **Les chaînes affichées gardent leurs accents, les commentaires non.** La
  faute a été commise deux fois : dans `Classes.luau`, puis dans le catalogue
  d'objets de `Config.luau`. Un nom d'objet, une description, un message de
  refus et un libellé de catégorie sont lus par les joueurs. Au moindre doute :
  est-ce que quelqu'un verra cette chaîne à l'écran ?
- **Un écran qui « marche » et un écran lisible sont deux choses.** Le panneau
  d'équipement a fonctionné du premier coup et était inutilisable : trois armes
  verrouillées sans explication, une description remplacée par un message
  d'erreur, du texte qui débordait de sa carte. Rien de tout ça n'apparaît dans
  les tests. **Regarder l'écran** fait partie du travail, et le moyen est
  `screen_capture` plus `user_mouse_input` pour cliquer dedans.
- **Les planchers de statistiques n'existent qu'à un seul endroit**, dans
  `Modifiers.luau`. L'arbre passe par `Modifiers.apply`, l'équipement par
  `Modifiers.applyDeltas`, et les deux partagent la même table `FLOORS`. Ne
  jamais en recopier une deuxième ailleurs.
- **L'ordre des trois couches de statistiques ne change pas** : classe nue,
  puis arbre, puis équipement. C'est ce qui fait que l'armure lourde retire un
  pourcentage de la vitesse *que l'arbre a déjà donnée*. Chaque appel à
  `SkillTreeService.refreshStats` doit être suivi de
  `LoadoutService.refreshStats`, sinon l'équipement disparaît silencieusement.
- **Si la lecture d'un profil échoue, on n'écrit pas.** Un profil illisible
  n'est pas un profil vide. `ProgressService` porte ce garde-fou, et c'est la
  seule chose de ce fichier qui peut détruire quelque chose d'irremplaçable.
- **Les trois listes de garde-fous doivent rester à jour** : `HANDLED` et
  `HANDLED_TIER6` dans `AbilityService`, et la table `handled` des sortes
  d'utilisation dans `LoadoutService.init`. Le serveur refuse de démarrer si
  `Config` annonce quelque chose qu'aucun service n'exécute, et le message
  nomme le coupable. C'est volontairement brutal : un objet qui coûte des
  points et ne fait rien ne se voit jamais en jouant.

## L'ordre des étapes

1. Squelette du repo : Rojo, Rokit, Wally, StyLua, Selene, `CLAUDE.md`, fichier
   de configuration, GitHub Actions. **Jalon : un message dans la console de
   Studio.**
2. Prototyper le Vampire contre le Colosse sur une map vide, en trois manches
3. Ajouter la zone qui se referme, puis l'agonie et le relèvement
4. Ajouter l'arbre à six paliers sur ces deux classes seulement — **fait**,
   logique pure, branchement serveur, interface et quatre effets de palier 6
5. Les douze autres classes — **fait** : statistiques, pouvoirs, trois branches
   chacune, plus les bans et le tirage au sort
6. L'équipement et son budget de douze points, les pièces, les tirages et le
   classement — **fait** : treize objets sur soixante-deux, l'écran
   d'équipement, l'économie, l'Elo, et les cotes conformes à Roblox
7. L'arme visible dans la main et son geste — **fait**, en géométrie pure,
   sans une seule animation téléversée ; l'arme bouge, le bras non
8. Le son — **fait** : cinq familles sonores greffées sur les annonces
   d'effets, quatorze pistes vérifiées, zéro message réseau de plus. Choisi au
   nom et à la durée, **jamais écouté** : section 12 d'`A-TESTER.md`
9. Ce qui reste : le mouvement du corps, les quarante-neuf autres objets, les
   skins, l'achat de pièces en Robux, et six sons laissés vides (soin,
   relèvement, brûlure de zone, interface, début et fin de manche, caisse)

Ce qui a été construit et ce qu'il reste à vérifier en jouant est dans
`docs/A-TESTER.md`. Les décisions prises sans Josh sont dans
`docs/DECISIONS.md`.

**Première chose à coder** : une map vide, deux joueurs, deux classes, trois
manches, pas d'arbre, pas d'équipement. Si le Vampire contre le Colosse est déjà
amusant dans ces conditions, tout le reste vaut la peine d'être construit.

## Arbitrages du 25 octobre 2026

La fiche se contredisait sur trois points. Josh a tranché, et **la fiche a été
corrigée** : elle dit maintenant la même chose que `Config.luau`. Ces trois
décisions sont notées ici parce que les anciennes valeurs traînent peut-être
encore dans une conversation ou une capture d'écran.

- **Un point d'arbre par manche**, pas deux. L'étape 6 de la boucle de partie
  disait « deux points d'arbre pour tout le monde », ce qui contredisait le
  tableau des issues de partie. Un point avant la première manche, puis un par
  fin de manche, donc une partie de M manches donne M points utilisables.
- **Le point de revanche** est accordé une seule fois par partie, à l'équipe qui
  vient de perdre **trois manches d'affilée** (la fiche disait « menée de deux
  manches ou plus »).
- **L'économie des pièces** suit les gains détaillés de la section « Les pièces »
  (caisse toutes les trois à six parties), pas la fourchette « quatre à huit »
  du récapitulatif.
- **Le 1v1 miroir est classé** comme les autres formats : l'équilibrage étant
  parfait par construction, il n'y a plus de raison d'en faire un mode détente
  hors classement.

Tous les chiffres sont des points de départ raisonnés, pas des certitudes. Le
seul moyen de les valider, c'est de jouer.
