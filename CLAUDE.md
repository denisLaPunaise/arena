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
- **LA PLACE PEUT ETRE EN RETARD SUR LE REPO, SANS RIEN DIRE.** Vu le
  27 octobre 2026 : le plugin Rojo etait deconnecte alors que `rojo serve`
  tournait, et la place melangeait du neuf et du vieux — les remotes renommes,
  mais six scripts d'avant le renommage. La console disait
  « Infinite yield on WaitForChild("Side") » pour un remote qui n'existe plus
  nulle part dans le repo, ce qui envoie chercher un bug imaginaire.

  **La verification qui tranche en un appel : comparer les TAILLES.** La
  longueur en octets de chaque `Source` de la place contre `wc -c` sur le
  repo ; ce qui differe est en retard. Et pour rattraper sans le plugin :
  servir le repo sur `http://127.0.0.1` avec `python -m http.server`, puis
  `HttpService:GetAsync` dans `execute_luau` pour poser chaque `Source`. Il
  faut relever `HttpService.HttpEnabled` — **le remettre comme il etait a la
  fin**, c'est un reglage de la place, pas le mien.

- **Un refus doit FERMER, pas figer.** Le panneau du salon refusait de
  s'ouvrir quand le serveur disait non — donc il refusait aussi de se fermer,
  et un panneau ouvert au moment du refus restait a l'ecran pour toujours. En
  ecrivant une porte qui peut se verrouiller : elle doit laisser l'ecran dans
  l'etat le plus sur, et c'est ferme.

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

- **Le bac a sable ouvre TROIS PORTES, et elles doivent se refermer.**
  `LoadoutService.setSandbox` releve le budget et rend l'equipement modifiable
  en pleine manche, `SkillTreeService.grantSandboxPoint` distribue des points
  hors manche, et `CombatService.setPractice` branche le mannequin. Les trois
  sont inacceptables en partie, et les trois sont refermees par
  `SandboxService.teardown`. En ajoutant une porte de ce genre : la nommer, la
  mettre dans un seul service, et la refermer au meme endroit que les autres.
  Une condition semee dans quatre fichiers ne se relit pas.

  Le garde-fou qui porte vraiment est que le bac a sable ne s'ouvre que SEUL :
  aucune piece ni aucun classement n'existe avec un joueur, donc rien de ce qui
  se gagne n'est atteignable depuis lui. Ne jamais relever
  `Config.sandbox.maxPlayers` ; un test le verifie.

- **Un vrai bot n'est pas abordable, et la raison n'est pas l'intelligence.**
  Tout le jeu est indexe par `Player` : chaque service range ses tables par
  joueur, et un bot n'est pas un `Player`. Il faudrait rendre generiques les
  rosters du combat, de l'equipement, de l'arbre, des pouvoirs et de l'agonie
  d'un seul coup. Et ca n'acheterait pas ce qui manque : un bot dit qu'une
  mecanique fonctionne, jamais qu'un duel est tendu. Le mannequin du bac a
  sable est une cible, pas un adversaire, et il ne declenche volontairement
  AUCUN pouvoir qui demande un vrai adversaire — mieux vaut ne rien faire que
  faire croire que ca marche.

  **LA MEME LIMITE PORTE SUR LES OBJETS, et elle est plus large qu'elle n'en a
  l'air.** `enemiesNear` et `alliesNear` parcourent le `roster`, indexe par
  `Player` : une zone, un lancer, un effet colle et une explosion ne peuvent
  donc RIEN atteindre dans le bac a sable. La moitie offensive du catalogue est
  invisible en solo, et c'est structurel. En ecrivant une sonde pour un objet
  qui vise quelqu'un, la premiere question est : est-ce qu'il y a quelqu'un a
  viser ? Sinon la sonde dira « rien ne se passe » et le code sera juste.

- **Un `Humanoid` mort ne se soigne pas.** Des que ses PV touchent zero, Roblox
  le passe en etat Dead, et lui rendre ses PV ne le releve pas : il reste mort,
  a plein de vie. Un mannequin se RECONSTRUIT, au meme endroit. Vu le
  26 octobre 2026, et seule la sonde en jeu pouvait le montrer.

- **`AbsolutePosition` et `AbsoluteSize` ne se lisent pas dans le meme
  repere.** Avec `IgnoreGuiInset = true`, le `ScreenGui` couvre toute la
  fenetre, mais l'origine des `AbsolutePosition` reste SOUS la barre du haut :
  le bord superieur du `ScreenGui` s'y lit `-GuiService:GetGuiInset().Y`.
  Comparer un `AbsolutePosition` a `AbsoluteSize / 2` melange donc deux reperes
  et fait croire a un decalage qui n'existe pas. C'est exactement l'erreur
  commise le 26 octobre 2026 : les cinq panneaux ont ete declares « decentres
  de 58 pixels vers le haut » alors qu'ils etaient au milieu exact, et la
  « correction » appliquee au bac a sable l'a, elle, vraiment decentre de 58
  pixels vers le bas. **Une mesure d'interface ne compare que des
  `AbsolutePosition` entre eux** : le centre du panneau contre le milieu de ses
  PROPRES bords, avec deux temoins poses dans le meme `ScreenGui`. Refait comme
  ca le 27 octobre : ecart 0.0 sur les cinq.

  Ce qui restait vrai, et qui est corrige : la barre du haut se dessine
  PAR-DESSUS les `ScreenGui` qui l'ignorent, donc un grand panneau mesure
  contre la hauteur entiere passe son en-tete derriere elle. La regle vit
  maintenant a un seul endroit, `src/client/Screens.luau`, que les cinq
  panneaux appellent : elle retire la barre de la place disponible et descend
  le panneau d'une demi-barre. Ne pas en recopier une deuxieme ailleurs.

- **Un panneau ne suit la fenetre que si sa connexion existe vraiment.** Trois
  panneaux branchaient `AbsoluteSize` dans `start()`, ou leur `ScreenGui`
  n'existe pas encore : la connexion etait sautee en silence, et le panneau
  gardait son echelle d'origine. Le quatrieme la branchait sur
  `Workspace.CurrentCamera`, qui est remplacee a la reapparition. La connexion
  se prend dans `build()`, sur le `ScreenGui` lui-meme. A savoir aussi : un
  `ScreenGui` desactive ne met plus a jour son `AbsoluteSize`, donc il faut
  l'afficher pour le mesurer.

- **La taille d'un panneau se DEDUIT de son contenu.** La colonne des actions du
  bac a sable debordait de 42 pixels parce que la largeur etait ecrite en dur et
  devait s'accorder avec quatre autres chiffres. Un chiffre de mise en page qui
  depend d'autres chiffres se calcule, il ne se recopie pas — c'est la meme
  regle que pour `Config.luau`, appliquee a l'interface.

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

- **Un son greffe sur une annonce qui se repete sonne autant de fois qu'elle.**
  Deux cas, deux parades, et les deux sont dans le protocole :
  l'annonce d'affichage part QUATRE FOIS PAR SECONDE pour tenir l'ecran a jour,
  donc le son du debut de manche est porte par un champ `cue` que seuls les
  trois appels marquant un moment remplissent ; et l'annonce de soin sert aussi
  bien a une trousse qu'au vol de vie du Vampire, qui s'annonce a chaque coup
  porte, donc c'est l'appelant qui nomme le son dans `sound`. Dans les deux cas
  le client ne peut PAS trancher tout seul : il ne voit pas la difference entre
  un rafraichissement et un evenement, ni entre un soin voulu et un vol de vie.
  En branchant un son sur une annonce existante, la premiere question est donc :
  a quelle frequence part-elle, et sait-elle pourquoi elle part ?

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

- **Le corps d'un avatar n'a plus de `Motor6D`, donc son `C0` ne sert a rien.**
  Verifie en jeu le 27 octobre 2026 : sur l'avatar de test, les seuls `Motor6D`
  du personnage sont ceux que le jeu a poses lui-meme, plus la tete. L'epaule
  est un `AnimationConstraint` double d'un `BallSocketConstraint`, que
  l'animateur de Roblox reecrit a chaque image : une valeur ecrite la est
  effacee avant d'etre affichee. Le moyen qui marche sur les deux squelettes
  est `IKControl`, pose sur l'`Humanoid`, avec une attache sur le torse pour
  cible et son **poids** anime de 0 a 1 puis retour. A poids zero l'animation
  d'origine est intacte, donc rien ne saute et il n'y a rien a defaire si le
  geste est interrompu.

  Deux consequences a ne pas perdre : **l'epaule a une butee** — 2 studs
  demandes donnent 1,85 vers le haut, 1,25 vers l'avant et **0,36 seulement
  vers l'interieur du corps**, donc un moulinet qui traverse la poitrine est
  impossible et aucun chiffre ne l'obtiendra ; et **la position de la main au
  repos se mesure**, une demi-seconde apres l'apparition du personnage, parce
  qu'elle depend de la taille de l'avatar que le joueur choisit.

  Le buste se penche par un SECOND `IKControl` et la tete par un TROISIEME, en
  `Rotation` tous les deux, sur les chaines `LowerTorso` -> `UpperTorso` et
  `UpperTorso` -> `Head` : on veut que le buste PLIE A LA TAILLE et pas qu'il
  quitte son bassin, et qu'une tete tourne plutot qu'elle se deplace. Les
  jambes restent hors de toute chaine. Les trois controles se composent sans se
  marcher dessus parce que chaque cible est posee sur le PARENT de ce qu'elle
  commande : la main et la tete sur le torse, le torse sur le bassin. Chacun
  part donc avec son porteur. Mesure, pas suppose : buste penche de 20 degres,
  la main reste a 1,08 de son 1,01 habituel dans le repere du torse.

- **L'ANIMATION D'ATTENTE DE ROBLOX FAIT TOURNER LE BUSTE, jusqu'a 22 degres,
  en permanence.** C'est ce qui interdit de le faire tourner ou s'incliner
  lateralement : un angle demande sur le lacet ou le roulis arrive quelque part
  entre ce qu'on veut et ce que l'animation voulait, et le resultat change a
  chaque coup. Seul le TANGAGE revient exactement a zero, donc le buste se
  penche et ne se tourne pas. Et la butee du bassin est a 22 degres : demander
  45 donne 21,4, demander 90 donne 22,4.

  Consequence dans le code, et c'est la seule difference avec le bras :
  **l'orientation de repos du buste se relit au depart de chaque geste**, alors
  que la position de repos de la main se mesure une fois par personnage. Une
  orientation relevee une fois serait perimee a l'instant suivant, et le torse
  sauterait au depart du geste.

- **UN TANGAGE POSITIF LEVE L'AVANT D'UNE PART, et ca a coute une journee.**
  Le penchement du buste a ete ecrit a l'envers le 27 octobre 2026 et livre
  comme ca : des angles d'Euler avaient ete mesures, et « +18 degres » lu comme
  « penche en avant ». Verifie par un temoin, `CFrame.Angles(+18, 0, 0)` donne a
  l'avant du buste un Y de +0,30 et a son sommet un Z de +0,29 : une poitrine
  qui regarde le ciel et un buste qui part EN ARRIERE, pendant que la main
  allait devant. Les cinq gestes etaient faux.

  **Un angle d'Euler ne dit pas ou pointe une part.** La mesure qui compte est
  `LookVector` et `UpVector` dans le repere du parent. Trois parades, et les
  trois sont en place : les angles de `bodyMotion` sont NOMMES PAR LEUR EFFET
  (`lean` positif fait tomber la poitrine devant, `headDip` positif fait
  regarder en bas, `headTurn` positif tourne vers la gauche) ; la conversion
  vers les axes de Roblox se fait a UN SEUL endroit, dans `WeaponService`, avec
  son signe moins et la mesure citee a cote ; et le test refait le calcul de
  Roblox puis regarde ou pointe la part.

- **Un test de direction qui compare deux noms ne teste rien.** Celui du buste
  comparait `pose.forward > 0` a `pose.lean > 0` — deux de mes conventions,
  mises face a face. Elles etaient d'accord entre elles et toutes les deux
  fausses, donc il passait sur un geste integralement a l'envers. Un test de
  direction REPRODUIT le calcul de Roblox, verifie d'abord qu'il retrouve les
  chiffres d'un temoin releve en jeu, et juge les signes seulement apres. C'est
  la structure du test de la pointe de l'arme, qui avait deja attrape deux
  signes inverses le 26 octobre : l'employer tout de suite.

- **LA TETE PREND SES DEUX AXES, LE BUSTE UN SEUL, ET LES JAMBES AUCUN.** Les
  trois reponses viennent de la meme mesure : de combien l'animation de Roblox
  tient-elle le membre ? Sur trois secondes, l'animation d'attente bouge la tete
  de 0,7 degre de tangage et 0,1 de lacet, et le buste de 22 degres de lacet.
  D'ou tangage plus lacet pour la tete, tangage seul pour le buste. Butees
  mesurees : 37 degres de tangage et 48 de lacet pour le cou, 22 pour le bassin.

  **Les jambes sont un refus, pas un oubli.** Un `IKControl` sur
  `RightUpperLeg` -> `RightFoot` marche tres bien debout. En marchant il GAGNE
  contre l'animation de marche : le pied, qui balance de 1,68 stud par cycle,
  tombe a 0,10, et le personnage glisse sur une jambe figee. Casser la marche,
  qui est a l'ecran en permanence, pour decorer une attaque de 230 ms, est un
  mauvais echange. Ne pas le refaire sans en parler a Josh.

- **Le corps et l'arme sont deux tables, un seul geste.** `weaponMotion` dit
  COMMENT l'arme tourne dans la main, `bodyMotion` dit OU va la main et DE
  COMBIEN le buste penche : les melanger ferait tourner l'arme deux fois. Ils
  partagent la duree et **un seul jeton**, parce qu'ils doivent revenir ensemble
  ou pas du tout. Un geste de plus dans l'une des deux tables sans son
  equivalent dans l'autre ne leve rien : le bras reste immobile pendant que
  l'arme part, et un test le refuse desormais dans les deux sens.

  Dans `bodyMotion`, `right`, `up` et `forward` sont des DISTANCES, et `lean`,
  `headDip` et `headTurn` des ANGLES. Rien dans le code ne lie les six, ils sont
  juste voisins : un buste qui part en arriere pendant que la main avance n'est
  pas un geste, c'est une convulsion, et ca ne se verrait qu'a l'ecran. Un test
  verifie donc que la main, la poitrine et la tete sont d'accord sur « avant »,
  en mesurant ou chacune pointe.

- **Une articulation posee sur un membre ne meurt pas avec le modele qu'elle
  tient.** `WeaponService` soude l'arme par un `Motor6D` parente a LA MAIN :
  detruire le modele de l'arme laisse donc l'articulation derriere lui, une par
  changement d'arme, pour toujours. Vu en jeu le 27 octobre 2026 : QUATRE
  `ArenaGrip` dans la meme main apres cinq changements, toutes inertes et
  toutes repondant au meme nom, donc un `FindFirstChild` en designait une au
  hasard — le meme piege que les doublons de Rojo. En posant une contrainte,
  une attache ou une articulation sur un personnage : la detruire au meme
  endroit et au meme moment que ce qu'elle tient.

- **Une sonde qui dit « rien ne se passe » est suspecte avant le code.** Deux
  sondes de suite ont rapporte « aucun `IKControl` » et « la main ne bouge pas
  d'un pouce » alors que le geste marchait. Elles avaient capture
  `player.Character` une fois pour toutes, et le bac a sable en fait apparaitre
  un nouveau : elles regardaient un personnage detruit, qui ne bougera plus
  jamais. **Une sonde relit `player.Character` a chaque mesure**, jamais une
  seule fois au demarrage.

- **Un test qui nomme son exemple en dur se mord la queue.** La suite verifiait
  qu'un palier 6 non code ne s'active pas, et elle prenait la Peste comme
  exemple, nommee en dur. Coder la Peste faisait donc ECHOUER le test sur son
  propre exemple, et pas sur un bug : on cherche alors une regression qui
  n'existe pas. Un test qui verifie « ce qui n'est pas encore fait » doit
  demander a `Config` ce qui ne l'est pas, et dire explicitement « plus rien »
  le jour ou la liste se vide — sinon sa boucle cesse de verifier quoi que ce
  soit en silence.

- **Les perforations d'armure ne s'additionnent pas, on garde la plus forte.**
  Deux effets percent : l'arc composite de moitie, et la propagation de la
  Peste au palier 6 entierement. Une Peste armee de l'arc percerait sinon 150 %
  d'une armure, ce qui transforme une reduction en augmentation. Le calcul vit
  en logique pure dans `Combat.piercedRatio`, avec ses deux garde-fous testes :
  on ne perce que ce qui EST une reduction (percer une cible deja fragile la
  rendrait moins fragile), et jamais plus de 100 %. Ne pas en recopier une
  deuxieme version ailleurs — c'est la meme regle que les planchers de
  `Modifiers.luau`.

- **UNE TABLE DE CONFIG QUE PERSONNE NE LIT NE LEVE RIEN.**
  `Config.formats` declarait le 1v1, le 2v2, le 3v3 et le 4v4 — avec leurs
  commentaires, et `balanceReferenceFormat = "3v3"` par-dessus — pendant que
  `MatchService` portait un `PLAYERS_NEEDED = 2` en dur et asseyait
  `players[1], players[2]`. Personne ne lisait la table. Le format de reference
  pour l'equilibrage n'avait jamais fait tourner une ligne de code, et un
  troisieme joueur n'avait **aucune equipe**.

  C'est la meme panne que les branches creuses et que les paliers 6 declares
  sans etre executes, et le projet a deja un garde-fou pour celle-la : le
  serveur refuse de demarrer quand `Config` annonce ce qu'aucun service
  n'applique. La lecon est d'y penser pour les TABLES aussi, pas seulement pour
  les listes de pouvoirs. Le moyen le moins cher est un test qui relie les deux
  bouts : celui de `tests/specs/seating.luau` verifie que chaque identifiant de
  format dit bien sa taille (`"2v2"` pour `playersPerTeam = 2`) et qu'il y a
  exactement deux camps dans `Config.seating.teams`. Les deux listes ne peuvent
  plus diverger en silence.

  LA MEME PANNE, LE MEME JOUR, UN ETAGE PLUS LOIN. `Rating.counts(config,
  private)` portait la regle « une partie privee ne compte pas », etait teste
  dans Lune, et n'etait appele par AUCUN service : `ProgressService.awardMatch`
  distribuait l'Elo et les pieces dans tous les cas. Une partie d'essai entre
  amis deplacait donc les vrais classements. Le signal commun aux trois cas
  (branches creuses, formats, mode prive) : **une fonction pure que seuls les
  tests appellent est une regle qui ne s'applique pas.** Un `grep` du nom dans
  `src/` repond en deux secondes, et il vaut d'etre fait pour chaque regle
  qu'on croit en place.

  Le contraire etait vrai, et vaut d'etre su : **tout ce qui etait en aval
  savait deja compter en equipes.** `Downed.roundIsOver` compte les equipes
  debout, le relevement cherche un coequipier, `DraftService` deduit la taille
  des equipes de la table qu'on lui passe et ignore les votes de qui n'en a
  pas. Rien ne les composait, voila tout — donc avant de croire qu'un chantier
  est gros, lire ce qui est en aval.

- **Un depart ne doit pas annuler ce qui concerne les autres.**
  `waitForRoundEnd` abandonnait la partie des qu'un joueur quittait. A deux
  joueurs c'etait la seule reponse possible ; a six, une coupure de reseau
  faisait perdre leur serie aux cinq autres. Les services se nettoient deja
  seuls (chacun a son `PlayerRemoving`), donc la fin de manche se resout toute
  seule : il ne restait qu'a retirer le partant de la liste de MatchService.

  **Et une partie qui perd un camp entier ne paie personne.** Deux raisons qui
  tiennent ensemble : le profil de celui qui part est deja ecrit et ferme par le
  `PlayerRemoving` de `ProgressService`, donc on ne peut rien lui retirer ; et
  crediter le camp restant se farmerait a deux comptes, l'un quittant pour
  l'autre. En ajoutant une recompense, la question a se poser est donc : qui
  peut provoquer cette issue expres, et avec combien de comptes ?

- **Deux reglages peuvent reclamer la meme touche, en silence.** Les touches
  sont a trois endroits de `Config` — `loadout.useKeys`, `loadout.editKey`,
  `sandbox.toggleKey`, et maintenant `seating.lobbyKey` — et rien ne les
  comparait. Le choix du camp a failli prendre « 1 », qui sert deja au premier
  objet : une touche qui fait deux choses selon le moment coute une manche, et
  ca ne leve aucune erreur. Un test de `tests/specs/config.luau` les reunit
  maintenant toutes et refuse une collision ; en ajoutant une touche, l'y
  inscrire.

  A savoir aussi : une touche dont le nom ne correspond a aucun `KeyCode` donne
  un `KeyCode` nil cote client, la branche du `elseif` ne se declenche jamais,
  et la touche est morte **sans la moindre erreur**. Verifier le nom dans
  Studio, pas seulement dans Config.

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
- **UN CHIFFRE NOMME EN STUDS DOIT DONNER DES STUDS, et il a fallu trois
  essais.** `upStuds = 40` donnait QUATRE studs de hauteur : le chiffre partait
  tel quel dans la vitesse du personnage, et 40 studs par seconde contre une
  gravite de 196 monte a 4,07. Les bottes a ressort sautaient donc moins haut
  que la barre d'espace, et mille quatre cent quatre-vingt-dix tests passaient
  — aucun ne savait ce que « stud » voulait dire. Vu le 27 octobre 2026.

  La HAUTEUR se convertit par `v = racine(2 g h)`, et c'est exact : 20 demandes
  donnent 19,8 mesures. L'HORIZONTALE, non, et c'est la le piege. L'Humanoid de
  Roblox pousse en permanence la vitesse du personnage vers celle que le joueur
  demande au clavier — zero quand personne n'appuie — donc un simple coup de
  vitesse est mange, et **pas proportionnellement** : un rattrapage de 1,37
  donnait 22,8 studs, un de 2,44 en donnait 67,8. Chercher le bon facteur etait
  le mauvais chantier.

  Ce qui marche est un `LinearVelocity` en mode Ligne, resolu par le moteur
  physique et pas par l'animateur. **Et il a rate aussi, une fois**, parce que
  `ForceLimitsEnabled` vaut VRAI par defaut avec `MaxForce` a 1000 : tres loin
  de ce qu'il faut pour lancer un personnage, donc la contrainte epinglait la
  vitesse a presque zero au lieu de la pousser, sans la moindre erreur. En
  posant un `LinearVelocity`, `AngularVelocity` ou n'importe quel acteur
  physique sur un personnage : **couper la limite de force, ou la regler
  expres**.

  Deux choses a savoir en prime. `knockbackStuds` et `knockbackUpStuds` sont
  des vitesses aussi, mais TOUTES, donc elles sont coherentes entre elles : les
  convertir serait un reequilibrage de la poussee, pas une correction. Et le
  personnage GLISSE a l'atterrissage, une fraction de seconde apres la fin du
  vol : 38 studs demandes en parcourent 43, et cette part-la ne se commande pas.

- **UN CHIFFRE QUI SE CACHE DANS UN REPLI EST AUSSI GRAVE QU'UN CHIFFRE EN
  DUR.** Le dome de soin n'avait pas de `holdSeconds` et retombait sur un
  `or 1` au fond de `LoadoutService`. La valeur etait bonne, et **illisible
  depuis `Config`** : personne ne pouvait la regler sans lire le service. Un
  repli est legitime pour ce qui n'a VRAIMENT pas de valeur (une zone de fumee
  ne colle rien), jamais pour ce qui en a une. La parade est la meme que pour
  les listes de pouvoirs : le serveur refuse de demarrer si une zone colle un
  effet sans dire combien de temps il tient.

- **`search_asset` n'est pas une recherche par le sens.** Verifie le 27 octobre
  2026 : « katana sword » en Model renvoie un point d'apparition, un ciel, un
  panneau d'administration et un NPC ; « sword » en MeshPart renvoie une
  canette, des cheveux d'anime et un fusil G36. **Prendre un objet tout fait
  dans la bibliotheque n'est pas faisable d'ici**, et il ne faut pas le
  promettre a Josh.

  Ce qui marche, en revanche : `generate_material` rend QUATRE variantes
  completes par appel — couleur, relief, metal, rugosite — et c'est ce qui
  change le plus l'allure d'une map pour le moins d'effort ; `generate_mesh`
  rend un maillage texture a la taille demandee, publie comme asset reutilisable,
  en une minute et demie environ. Les variantes arrivent dans
  `MaterialService.AssistantMaterials`, pas a la racine du service — les chercher
  par `GetDescendants`, sinon on conclut a tort que l'outil n'a rien fait.

- **Les listes de garde-fous doivent rester à jour** : `HANDLED` et
  `HANDLED_TIER6` dans `AbilityService`, et dans `LoadoutService.init` la table
  `handled` des sortes d'utilisation, celle `zoneEffects` des sortes de zone,
  plus trois vérifications de la même famille — qu'un effet collé par une arme
  (`onHit`) nomme une sorte que `Status` connaît, qu'une zone qui colle un
  effet dise combien de temps il tient, et que **chaque pièce d'une allure**
  nomme une sorte, une matière et un membre que `WeaponService` connaît
  (`knowsShape`, `knowsMaterial`, `knowsLimb` — les trois listent depuis le
  service, pour que le garde-fou n'en tienne pas une copie). Le serveur refuse
  de démarrer si `Config` annonce quelque chose qu'aucun service n'exécute, et
  le message nomme le coupable. C'est volontairement brutal : un objet qui
  coûte des points et ne fait rien ne se voit jamais en jouant.

- **UNE ALLURE EST UNE LISTE DE PIÈCES, ET ELLE NE SE RELIT PAS.** Un objet
  n'a plus une taille et une couleur : il a vingt pièces, chacune avec sa
  sorte, sa matière, sa position et ses deux angles. Trois emplacements, et un
  seul par objet : `grip` (main droite), `offhand` (main gauche, le temps d'un
  usage) et `worn` (un membre, pour une armure). Une armure déclare
  `fit = true` et ses chiffres deviennent des **fractions du membre** — la
  taille de l'avatar appartient au joueur, et un plastron écrit en studs
  flotterait autour d'un grand corps.

  Le moyen de vérifier est `WeaponService.preview`, qui pose les pièces dans le
  vide avec **exactement** le même calcul que la vraie pose, plus
  `screen_capture`. Les 1509 tests ne disent rien de l'allure : ils ont laissé
  passer un maillet, une grenade à anneaux de Saturne et une armure en porte de
  frigo. **Regarder fait partie du travail.**

- **LE CORPS DES JOUEURS EST IMPOSÉ DANS L'ARÈNE**, décidé par Josh le
  28 octobre 2026. `BodyService` remet la géométrie du corps à la norme à
  chaque apparition — les six parties qu'un bundle remplace, les six échelles
  — et retire les accessoires. Les vêtements, le visage et les couleurs
  restent au joueur : ils ne changent pas une silhouette, et ce sont eux qui
  porteront les skins.

  Trois pièges, tous vus en jeu le même jour :
  - **`HatAccessory` et les sept autres champs d'emplacement ne retirent que
    les accessoires RIGIDES d'autrefois.** Un accessoire moderne vit dans une
    liste à part. Les huit champs vidés, l'application réussie, et le pigeon
    toujours sur le dos du joueur. C'est `SetAccessories({}, true)` qu'il faut.
  - **`ApplyDescription` échoue au premier chargement**, le temps que les
    maillages de l'avatar arrivent du réseau, et l'erreur ne dit pas ça. Trois
    essais espacés d'une demi-seconde n'y suffisaient pas ; c'est cinq essais
    d'une seconde.
  - **`BodyTypeScale` et `ProportionScale` valent ZÉRO**, pas un. À un, le
    corps glisse vers les proportions « Rthro », qui ne sont pas celles contre
    lesquelles les armures et les armes sont dessinées.

  Et **le type d'avatar R15 reste un réglage de place** (Game Settings →
  Avatar), qu'aucune API ne change à l'exécution. Le service le constate et
  prévient dans la console ; c'est à Josh de le mettre.

- **UNE ARMURE SE PORTE SUR PLUSIEURS MEMBRES, et c'est ce qui la fait
  exister.** Une plaque posée sur le seul torse décore l'avant d'une boîte :
  la silhouette du personnage ne change pas, donc l'oeil continue de voir un
  corps nu avec un rectangle dessus. Chaque pièce peut nommer son `limb`, et
  chaque groupe reçoit son propre modèle, à l'échelle de **son** membre — un
  seul modèle ne pourrait pas, puisque toutes ses pièces pendent de la
  première par un `Motor6D` et suivraient donc le même membre.

  Deux conséquences à ne pas perdre. **La coque doit être plus GRANDE que le
  membre**, pas plus petite : c'est ce qui fait disparaître le corps derrière
  elle. Et **habiller une jambe n'a rien à voir avec l'animer** — la pièce est
  soudée et suit l'animation de marche sans la contrarier. Le refus de
  l'étape 10 portait sur les `IKControl`, qui eux gagnent contre l'animation.

- **CE QUI SE PORTE EST CE QUI DIT SE PORTER**, pas ce qui est rangé dans la
  catégorie « armure ». Les bottes à ressort sont un utilitaire, et elles
  s'affichaient dans la main gauche le temps d'un saut : personne ne tient
  ses bottes pour sauter avec. `Loadout.wornOf` regarde donc le bloc `worn`
  et non la catégorie. Conséquence à connaître : le squelette d'examen de
  `Config.loadout.previewRig` doit contenir tout membre qu'une pièce nomme,
  mollets et pieds compris, sinon l'aperçu saute le groupe **en silence** et
  on conclut que la pièce n'existe pas.

- **RIEN DE CE QU'ON MET SOUS UNE SEMELLE NE SE VOIT.** Un personnage de
  Roblox pose la plante de son pied au sol : ajouter des pièces dessous ne le
  soulève pas, ça les enterre. Mesuré le 29 octobre 2026 — le ressort des
  bottes descendait 0,63 stud sous le pied, donc entièrement dans le
  plancher. Il est passé derrière la cheville, où il se voit de face comme de
  profil. Même famille que la butée de l'épaule : la question n'est pas « où
  est-ce que je veux le mettre » mais « où est-ce que ça se verra ».

- **LES PROPORTIONS DE RÉFÉRENCE SE PRENNENT SUR UN CORPS STANDARD, JAMAIS SUR
  L'AVATAR QU'ON A SOUS LA MAIN.** La première mesure a été prise sur l'avatar
  de Josh, qui est un **pigeon** : torse de 1,27 stud de large et bras de 0,40.
  L'armure dessinée là-dessus portait des facteurs calculés pour des bras
  minces, et sur un corps normal ses épaulières faisaient deux studs. Le rig de
  référence se fabrique avec `CreateHumanoidModelFromDescription` et une
  `HumanoidDescription` vide ; ses mesures sont dans `Config.loadout.previewRig`.

  Mais les tailles restent des **fractions du membre**, parce que l'avatar d'un
  joueur peut être n'importe quoi. Et un *bundle* non humanoïde avale l'armure
  quoi qu'on fasse : son maillage visible n'a aucun rapport avec la taille de
  la part. Ça ne se règle pas par des chiffres — c'est une décision de
  conception, notée dans `docs/DECISIONS.md`.

- **DANS CE JEU UNE ARME POINTE VERS -Z**, et ce n'est pas un choix : c'est ce
  que les 34 armes disaient déjà avant le changement de format. De là les deux
  angles, nommés par leur effet et convertis **à un seul endroit** dans
  `WeaponService` : `tipUp` positif lève le bout avant, `tipLeft` positif le
  fauche vers la gauche. Même règle que le penchement du buste, qui a coûté une
  journée en étant écrit à l'envers.

- **LE `Ball` DE ROBLOX IGNORE LES TAILLES NON UNIFORMES.** Une part de sorte
  `Ball` dessine toujours une sphère parfaite du **plus petit** de ses trois
  côtés : `{ 0.42, 0.52, 0.42 }` ne donne pas un ovoïde, mais une bille de
  0,42. La grenade a donc porté des rainures calculées sur une hauteur qui
  n'existait pas, et elles dépassaient du corps comme les anneaux de Saturne.
  Un rayon se calcule sur ce que Roblox dessine, pas sur ce qu'on a écrit.

- **UN `Cylinder` NE DESSINE PAS D'ELLIPSE NON PLUS.** Comme un `Ball`, il
  prend le **plus petit** de ses deux côtés de section comme diamètre.
  Vérifié par témoin le 29 octobre 2026 : trois cylindres de sections 1×3,
  3×3 et 3×1 donnent des rondes de 1, 3 et 1. Écrire deux côtés différents,
  c'est donc en écrire un que Roblox jette, et la pièce sort beaucoup plus
  mince que voulu — assez pour disparaître dans ce qu'elle habille. Les cinq
  boudins du gambison y sont passés : l'armure lisait comme un corps nu, et
  les 1524 tests passaient. **Un disque s'écrit `[épaisseur, diamètre,
  diamètre]`** et se couche par `roll` ou `tipLeft`. Un test refuse désormais
  tout rapport au-delà de 1,2, **mesuré après la mise à l'échelle du membre**
  — un bras fait 1,00 de large pour 1,24 de haut, donc deux fractions égales
  n'y donnent pas deux côtés égaux.

- **UN `Cylinder` TIRE SA LONGUEUR DE `Size.X`**, pas de l'axe où on croit le
  poser. Deux conséquences, et les deux ont mordu le même jour : pour le
  coucher vers l'avant il faut un **lacet** de 90 degrés (`tipLeft = 90`) et
  pas un roulis — un roulis le met debout, ce qui a dispersé le marteau sur
  toute sa longueur ; et un manchon de poignée écrit `{ 0.3, 0.3, 0.18 }` fait
  0,3 de **long** et 0,18 de large, donc il disparaît dans un manche de 0,26.

- **Un objet qui change d'allure déplace sa pointe, et le témoin du geste avec
  elle.** Le test de `tests/specs/loadout.luau` déduit la pointe des pièces, ce
  qui est juste — mais son témoin, lui, est une mesure relevée dans Studio.
  Déplacer quatre rivets du devant de la tête du marteau sur ses joues a
  raccourci la pointe de 2,805 à 2,77 stud et fait échouer le test. La réponse
  est de **remesurer dans Studio**, jamais de recalculer la valeur attendue
  dans le test : c'est la première moitié du test qui rend la seconde crédible.

- **UNE MAP NE SE JUGE PAS A L'OEIL, ELLE SE MESURE AU RAYON.** Les trois
  defauts de jeu reels des maps du 29 octobre 2026 ont tous ete trouves par
  `Workspace:Raycast`, aucun en regardant : une ligne de tir degagee de 120
  studs entre les deux departs, deux coursives aveugles sur le cercle final a
  cause d'une passerelle centrale, et un garde-corps a 18,2 studs qui bouchait
  la vue vers le bas depuis un oeil a 19,8. **Et le sens d'une rampe se
  verifie en echantillonnant la hauteur du sol le long du chemin** : une rampe
  du Sanctuaire etait posee a l'envers et ca ne se voyait pas sur une capture.
  L'oeil dit si c'est joli ; le rayon dit si ca se joue.

- **LES MAPS NE PEUVENT PAS COHABITER, ET L'ECLAIRAGE APPARTIENT A LA MAP.**
  `MapService` prend la PREMIERE map conforme de `Workspace`, donc deux maps
  presentes veut dire que la seconde ne sert jamais : chaque recette de
  `tools/` detruit les autres avant de construire. Et comme `Lighting` est un
  reglage de place et pas un enfant de la map, chaque recette pose aussi tout
  son eclairage — lancer une autre recette le remplace entierement. Une map
  sans son eclairage herite de celui de la precedente, et un desert eclaire a
  minuit ne ressemble a rien.

- **La `Baseplate` gagne un pixel sur deux.** Un sol de map pose au meme
  niveau que la Baseplate laisse apparaitre la grille grise par plaques, de
  facon aleatoire selon l'angle de vue. Chaque recette detruit donc la
  `Baseplate` ET le `SpawnLocation` — ce dernier fait apparaitre les joueurs
  hors de leur camp.

- **`CorrodedMetal` peint sa propre rouille PAR-DESSUS la couleur.** Les six
  piles de conteneurs du Cargo etaient de trois couleurs differentes dans le
  code et toutes orange a l'ecran. Un materiau Roblox qui porte sa propre
  teinte (`CorrodedMetal`, `Grass`, `Sand` a un moindre degre) ne se choisit
  pas pour sa texture en esperant garder sa couleur.

- **LA CAMERA NE SE PILOTE QU'EN MODE JEU.** En mode edition Studio garde la
  POSITION qu'on lui donne mais IMPOSE son orientation : un `CFrame.lookAt` ne
  cadre rien, et la mesure le dit — `LookVector` releve a 0,510 / 0,137 /
  -0,849 pour un 0,642 / -0,420 / -0,642 demande. En mode jeu elle obeit, mais
  le jeu la rend au personnage a chaque apparition, donc il faut la reprendre a
  chaque image. Le moyen employe est un `CFrameValue` dans `Workspace` et une
  boucle `RenderStepped` cote client qui la tient et masque les `ScreenGui` ;
  detruire le `CFrameValue` rend la camera et reaffiche l'interface.

- **`loadstring` est verrouille depuis le pont MCP**, et le message ne le dit
  pas : `ServerScriptService.LoadStringEnabled is not a valid member`. Le moyen
  de charger une recette de `tools/` dans Studio sans la coller a la main est
  un `ModuleScript` jetable dont on pose la `Source`, suivi d'un `require` puis
  d'un `Destroy`. La recette arrive par `HttpService:GetAsync` depuis un
  `python -m http.server` lance a la racine du depot — et `HttpService.HttpEnabled`
  **se remet comme il etait**, c'est un reglage de la place.

- **`execute_luau` sert la version en cache d'un module, indexee sur
  l'INSTANCE.** Modifier `Config.luau` par Rojo et relancer `execute_luau` ne
  change rien : le pont rend l'ancienne copie. Vu le 29 octobre 2026, un
  `previewRig` a sept os la ou le depot en declarait neuf, donc un objet qui
  rendait zero part sans la moindre erreur. Le moyen est de RENOMMER le module
  vivant, de parenter un clone neuf sous le nom d'origine, de lancer, puis de
  remettre les noms.

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
   classement — **fait** : l'écran d'équipement, l'économie, l'Elo, et les
   cotes conformes à Roblox. Treize objets d'abord, **les soixante-deux
   depuis le 27 octobre** — étape 13
7. L'arme visible dans la main et son geste — **fait**, en géométrie pure,
   sans une seule animation téléversée ; l'arme bouge, le bras non
8. Le son — **fait** : cinq familles sonores greffées sur les annonces
   d'effets, quatorze pistes vérifiées, zéro message réseau de plus. Choisi au
   nom et à la durée, **jamais écouté** : section 12 d'`A-TESTER.md`
9. Le bac à sable solo et son mannequin d'entraînement — **fait** : seul en
   jeu, choix de la classe, points d'arbre à la demande, budget relevé, jusqu'à
   quatre mannequins aux statistiques d'une vraie classe. Pas un bot, et la
   raison est dans les pièges ci-dessus
10. Le corps qui bouge pendant les attaques — **fait et mesuré par témoin** :
   la main avance, recule ou se lève avec le geste de l'arme, le buste plie à
   la taille du même côté, et la tête baisse, se lève ou tourne avec eux —
   trois `IKControl`, pas une seule animation téléversée. Le coup de poing se
   voit enfin. **Les jambes sont un refus mesuré** : les piloter casse la
   marche. L'épaule, le bassin et le cou ont des butées mesurées, donc un
   geste plus ample est impossible par ce moyen. Reste à savoir si c'est beau,
   et ça ne se mesure pas
11. Les équipes dans la boucle de partie — **fait, et c'était un trou** : le
   format se choisit d'après le nombre de joueurs présents, les deux camps se
   composent, le banc tourne à effectif impair, et un départ ne tue plus la
   partie. Avant ça la boucle asseyait les deux premiers joueurs arrivés et un
   troisième n'avait aucune équipe. Avec, le **mode privé** que `Config`
   annonçait sans que personne ne le lise : une partie privée ne paie plus et
   ne classe plus, et on y choisit son camp. Vérifié par les tests et dans la
   machine virtuelle de Roblox ; **jamais joué à plus d'un**, sections 18 et 19
   d'`A-TESTER.md`
12. Le salon des parties privées — **fait** : touche `C`, trois rangées, et
   rien d'autre. Le format (auto, ou l'un des quatre imposé) et la composition
   des camps (chacun demande le sien, ou tirage au sort refait à chaque
   partie). **Les règles du jeu ne sont pas réglables**, et c'est une décision
   de Josh : le jeu reste le jeu. Un format imposé ne change jamais QUI joue,
   et un format trop grand fait attendre au lieu de retomber en silence sur le
   format du dessous
13. Les quarante-neuf objets qui manquaient, et le dernier palier 6 —
   **fait** : soixante-deux objets sur soixante-deux, quarante-deux paliers 6
   sur quarante-deux. Trois sortes d'utilisation de plus (`zone`, `leap`,
   `throw`), un module de logique pure (`Status`) pour les quatre effets
   temporaires, et deux résistances nouvelles pour que les armures
   spécialisées existent. Le palier 6 du Monolithe promettait une immunité
   aux projectiles dans un jeu où rien ne vole : **relu comme une immunité aux
   explosions, et c'est une décision prise sans Josh**. Vérifié en jeu pour
   tout ce qui ne vise personne ; **la moitié offensive n'a jamais touché
   personne**, section 21 d'`A-TESTER.md`
14. **L'allure des objets, un par un** — **fait** : les soixante-deux objets
   ont une allure à pièces, et chacun a été **regardé à l'écran**. Treize
   armes de mêlée, dix-huit armes de tir, sept armures, cinq soins, treize
   utilitaires, plus les six objets d'essai. Les familles sont dessinées par
   des générateurs partagés, pour que soixante-deux objets parlent une seule
   langue visuelle. Quatre défauts trouvés en regardant et aucun par les
   tests : le diamètre des cylindres, un rail non miroité, un ressort enterré
   sous une semelle, et trois grenades présentées par leur fond. Verdict
   honnête, inchangé : les armes se lisent bien, **les armures restent les
   plus faibles** et la raison est structurelle — un torse Roblox est une
   boîte, et seules les épaulières, les tassettes et les cuissards changent
   vraiment une silhouette
15. **Trois maps, trois univers** — faites : le Colisée de sable, la soute du
   cargo et le sanctuaire noyé, une recette chacune dans `tools/`. Toutes les
   trois autour de 160 studs de côté, `MapBounds` carré, matériaux d'origine
   seulement, et chacune bâtie autour d'une question tactique differente : le
   trou central, la position haute, le passage obligé. **Elles ne peuvent pas
   cohabiter**, puisque `MapService` prend la première conforme. Mesurées au
   rayon, jamais jouées — section 26 d'`A-TESTER.md`
16. Ce qui reste : les jambes si Josh en veut malgré le coût, la tête qui
   regarderait sa cible (une information de plus donnée à l'adversaire, donc
   une décision de conception), **l'allure des armes**, les skins, et l'achat
   de pièces en Robux

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
