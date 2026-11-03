# Pour un autre assistant qui arrive sur Arena

Bienvenue. Ce fichier existe pour une raison précise : tu vas travailler sur un
projet qui a déjà une histoire, des décisions prises, et surtout **une liste de
pièges payés cher**. Lis-le en entier avant de toucher au code — tu y gagneras
des journées.

Tu travailles pour **Josh**. Il n'est pas développeur : il juge le jeu en y
jouant, il tranche les questions de conception, et il publie. Tout le Luau, la
structure, les tests et la construction dans Studio sont à toi. **Parle-lui en
français.**

Une habitude du projet qui vaut plus que tout le reste : **on dit ce qu'on a
vérifié et ce qu'on n'a pas vérifié.** Un chiffre mesuré et une supposition ne
se présentent jamais de la même façon. Beaucoup de ce qui est écrit ici a été
appris en se trompant, puis en posant un témoin.

---

## 1. Les trois fichiers à lire, dans cet ordre

| Fichier | Ce qu'il contient | Taille |
| --- | --- | --- |
| **`CLAUDE.md`** | Les conventions, l'architecture, et **la liste des pièges**. C'est le fichier le plus important du dépôt. | ~1 250 lignes |
| **`docs/A-TESTER.md`** | Ce qui est construit mais **jamais joué par un humain**. C'est la dette réelle du projet. | ~1 700 lignes |
| **`docs/DECISIONS.md`** | Les décisions prises **sans Josh**, avec leur justification. À relire avant d'en prendre une nouvelle. | ~2 160 lignes |

`docs/ARBRE.md`, `docs/OBJETS.md` et `docs/EQUILIBRAGE.md` sont des références
de contenu (l'arbre de compétences, les 62 objets, les chiffres d'équilibrage et
les sources sur la politique Roblox des tirages payants).

La section « Les pièges » de `CLAUDE.md` n'est pas de la documentation
décorative : **chaque entrée est une panne qui a réellement coûté du temps**, et
la plupart sont des pannes *silencieuses* — le code a l'air juste, les tests
passent, et le jeu fait autre chose. Si tu n'en lis qu'une, lis celle qui
commence par « UNE TABLE DE CONFIG QUE PERSONNE NE LIT NE LEVE RIEN ».

---

## 2. Ce qu'est le jeu, en six lignes

Arène PvP sur Roblox. Deux camps, des manches. La classe est **tirée au sort**
après une phase de bans. L'arbre de compétences se construit manche après
manche et il est **remis à zéro à chaque partie** : il ne porte aucune
progression de compte. L'équipement s'achète dans un **budget de douze points**
avant chaque manche. Les Robux achètent des skins et des pièces de tirage,
**jamais de la puissance**.

Quatorze classes, soixante-deux objets, quarante-deux effets de palier 6, quatre
formats (1v1 à 4v4), quatre maps.

**La conception est close.** Le cahier des charges est la fiche « Arena — PvP à
classes et progression définitive ». Si une question de conception se pose, elle
se tranche **avec Josh**, pas dans le code. Les six principes à ne jamais casser
sont en tête de `CLAUDE.md`.

---

## 3. L'architecture en une page

```
src/shared/     ReplicatedStorage.Arena   — logique pure et donnees partagees
src/server/     ServerScriptService.Arena — autorite : etat de partie, calculs
src/client/     StarterPlayerScripts.Arena — interface et entrees joueur
tools/          une recette par map, HORS du projet Rojo
tests/          suites Lune, hors du projet Rojo
```

Trois règles structurantes :

1. **La logique pure ne touche à aucune API Roblox.** Les modules de
   `src/shared/` ne connaissent ni `game`, ni `Instance`, ni `Player`. C'est ce
   qui permet de tout vérifier en ligne de commande avec Lune, sans Studio.
2. **Un module de logique pure ne `require` rien.** Ses dépendances arrivent en
   argument. Roblox résout les `require` par arborescence et Lune par chemin de
   fichier : un module pur qui en requiert un autre ne peut pas se charger des
   deux côtés. C'est l'erreur la plus facile à commettre du projet.
3. **Tous les chiffres vont dans `src/shared/Config.luau`.** Un chiffre en dur
   est un bug même si sa valeur est bonne : il sera modifié des dizaines de fois
   pendant l'équilibrage.

Le serveur est l'autorité sur tout ce qui compte. Le client affiche et envoie
des intentions.

### La frontière Rojo / Team Create — à ne jamais franchir

| Propriétaire | Ce qu'il possède |
| --- | --- |
| Rojo (ce dépôt) | `ServerScriptService`, `ReplicatedStorage`, `StarterPlayer` |
| Studio | `Workspace` — les maps se construisent, elles ne se codent pas |

**Ne jamais ajouter `Workspace` à `default.project.json`** : Rojo écrase, il ne
fusionne pas, et il effacerait tout le travail de construction. Les maps ne sont
ni dans Git ni dans le `.rbxl`.

**D'où `tools/` : une map se sauvegarde en RECETTE.** Un script par map, qui la
reconstruit à l'identique en détruisant d'abord la précédente. Toute map
construite dans Studio doit repartir avec son script dans `tools/`, sinon elle
n'est pas sauvegardée — une seule fausse manoeuvre la supprime sans trace.

---

## 4. Les commandes

```sh
rokit install              # installe les outils aux versions du projet
rojo serve                 # synchronise vers Studio (plugin Rojo connecte)
lune run tests/run         # ~1580 verifications, sans Studio
stylua .                   # formate (line_endings = Unix)
selene src                 # analyse statique
```

GitHub Actions relance les quatre à chaque push. **`stylua` veut des fins de
ligne Unix** : si tu modifies un fichier depuis un script Python sous Windows,
écris avec `newline="\n"`, sinon tu poses du CRLF et le contrôle de format
échoue en CI.

Et un piège de contrôle, parce qu'il a déjà menti ici : **ne termine jamais une
vérification par un tuyau** (`stylua --check . | tail`). Le code de sortie
devient celui de `tail`, donc un échec passe pour une réussite. Regarde `$?`.

---

## 5. Où en est le projet

Dix-huit étapes sont faites (la liste complète et à jour est à la fin de
`CLAUDE.md`). En résumé :

**Ce qui existe et tourne** — les quatorze classes avec leurs pouvoirs et leurs
trois branches d'arbre ; les bans et le tirage ; l'arbre à six paliers et ses
quarante-deux effets de palier 6 ; les soixante-deux objets avec leur allure
géométrique, leur budget, l'économie des pièces, les tirages conformes à la
politique Roblox, et l'Elo ; la zone qui se referme, l'agonie et le relèvement ;
l'arme visible dans la main et le geste du corps (trois `IKControl`, **aucune
animation téléversée**) ; le son ; le bac à sable solo ; les équipes et les
quatre formats ; le salon des parties privées ; l'écran d'accueil ; quatre maps.

**La dette, et elle est honnête** : presque **rien n'a jamais été joué à plus
d'une personne**. Les tests disent que les mécaniques fonctionnent ; ils ne
disent pas qu'un duel est tendu. `docs/A-TESTER.md` liste section par section ce
qu'il reste à vérifier en jouant, et dans quel ordre. C'est le document à
mettre à jour quand tu livres quelque chose.

**Ce qui reste à construire** : les skins, l'achat de pièces en Robux, l'allure
des armes à repasser, et deux refus mesurés qu'il ne faut pas rouvrir sans
parler à Josh (piloter les jambes casse l'animation de marche ; la tête qui
suivrait sa cible donnerait une information de plus à l'adversaire).

---

## 6. Ce qui se passe en ce moment (3 novembre 2026)

Travail en cours sur **l'allure des quatre maps**, avec deux outils du pont MCP
de Studio :

- `generate_material` rend quatre variantes complètes par appel (couleur,
  relief, métal, rugosité), publiées comme assets. Les identifiants sont
  **inscrits dans les recettes de `tools/`** — c'est ça la sauvegarde, puisque
  `MaterialService` n'est ni dans Git ni dans Rojo.
- `generate_mesh` rend un maillage texturé publié comme asset (~90 s).
  **Pas encore employé.**

Deux pannes trouvées en regardant l'écran le 3 novembre, et aucune par les
1 578 tests :

1. **Une matière jugée sur un panneau plat ment.** La pierre du Colisée lisait
   comme un petit appareil de pierre sur un panneau d'essai, et comme de la
   **faïence bleu et or** à trois studs sur une arche. Une matière se juge **sur
   la map, à distance de joueur**.
2. **Une liste de noms en dur se périme.** Les trois premières recettes
   détruisaient `{ ArenaMap, ColiseeMap, CargoMap, SanctuaireMap }` — la
   Carrière, écrite après, n'y était pas. Le Colisée s'est donc construit
   *autour* d'elle, deux maps dans `Workspace`, et `MapService` prend la
   première : l'une des deux ne sert jamais. Remplacé par un test du contrat
   (`SpawnsA` et `SpawnsB`), qui ne peut pas se périmer.
3. **Trois teintes ne font pas trois pierres.** Les trois familles de pierre du
   Colisée étaient toutes en `Sandstone` ; comme une variante s'attache à une
   matière de **base**, elles portaient forcément la même texture. Chacune a
   maintenant la sienne.
4. **Un camo n'est pas une texture, c'est une texture et une teinte.** Le
   Sanctuaire lisait comme un treillis militaire. Générer d'autres pierres
   sombres a donné quatre fois le même résultat : ce qui tue le camo est la
   **structure** — des joints, des assises — pas une autre tache.

### Si tu reprends ce chantier

Ce qui reste de visuel, dans l'ordre où ça rapporte :

- **`generate_mesh` n'a jamais servi.** Zéro `MeshPart` dans le projet. C'est
  le seul outil du pont qui n'a pas été essayé sur les maps.
- **La bannière de camp du Sanctuaire** occupe la moitié haute de l'écran
  depuis le point de départ (`FrontonA`, 22 studs de large à 11,4 studs de
  l'oeil). Mesuré, pas corrigé.
- **Trois défauts de jeu mesurés au rayon** et laissés tels quels, parce qu'ils
  déplacent l'équilibre d'une map et que ça se tranche avec Josh : lignes de tir
  dégagées entre les départs au Sanctuaire (147 studs) et au Colisée (121), et
  couverture du cercle final du Colisée à 4 directions sur 16.
- **56,6 % de la surface du Cargo** ne porte aucune matière générée.

---

## 7. Travailler dans Studio par le pont MCP

Tu peux lire l'arborescence, exécuter du Luau, construire, générer des matières
et des maillages, et lancer une partie de test. Cinq choses à savoir tout de
suite, parce qu'elles ne lèvent aucune erreur :

- **`execute_luau` a son propre cache de modules.** Le code du pont ne tourne
  pas dans la machine virtuelle du jeu : un `require` y rend une instance neuve,
  sans les connexions que `Bootstrap` a branchées. Parfait pour inspecter le
  DataModel, inutilisable pour piloter un service vivant — pour ça, il faut
  injecter un `Script` et le détruire après.
- **La caméra ne se pilote qu'en mode jeu.** En mode édition, Studio garde la
  position qu'on lui donne et **impose son orientation**. Pire : il ne la
  réécrit qu'à l'image suivante, donc une relecture immédiate rend ta propre
  valeur et te fait croire qu'elle obéit. En mode jeu, le moyen qui marche est
  un `CFrameValue` dans `Workspace` et une boucle `RenderStepped` côté client
  qui la tient à chaque image.
- **`screen_capture` ne photographie pas les `BillboardGui`**, et il lui arrive
  de cesser de rendre la 3D sans la moindre erreur. Avant de conclure qu'un
  objet ne s'affiche pas, **pose un témoin**.
- **`loadstring` est verrouillé depuis le pont.** Pour charger une recette de
  `tools/` sans la coller à la main : `python -m http.server` à la racine du
  dépôt, puis un `ModuleScript` jetable dont on pose la `Source` par
  `HttpService:GetAsync`, un `require`, un `Destroy`. L'erreur « Module code did
  not return exactly one value » est normale, le code a tourné. **Remets
  `HttpService.HttpEnabled` comme il était** : c'est un réglage de la place.
- **`search_asset` n'est pas une recherche par le sens.** « katana sword »
  renvoie un point d'apparition et un ciel. Prendre un objet tout fait dans la
  bibliothèque n'est pas faisable d'ici — ne le promets pas à Josh.

Deux prudences, parce que l'accès direct est destructeur : **publier une version
de la place avant une grosse opération**, et **ne rien construire dans
`Workspace` qui doive durer sans le dire à Josh**.

---

## 8. Les quatre réflexes qui font la différence

**1. Une règle que seuls les tests appellent est une règle qui ne s'applique
pas.** C'est la panne la plus coûteuse du projet, et elle est arrivée **trois
fois** : `Config.formats` déclarait quatre formats que `MatchService` ne lisait
pas ; `Rating.counts` portait la règle du mode privé sans être appelée par un
seul service ; `Config.match` annonçait « premier à quatre manches » pendant que
le jeu en jouait deux — ce qui rendait les paliers 5 et 6 **inatteignables**, et
les quarante-deux effets codés ne pouvaient jamais partir. Les tests passaient à
chaque fois. Un `grep` du nom dans `src/` répond en deux secondes. Et quand tu
écris le test qui ferme la panne, **fais-lui lire ce que le jeu lit** (ici
`MatchState.roundsToWin(Config)`), pas le chiffre d'à côté : il doit échouer sur
l'ancienne configuration, c'est la seule preuve qu'il sert.

**2. Mesure, ne suppose pas — et mesure la bonne chose.** Un `AbsolutePosition`
comparé à un `AbsoluteSize / 2` mélange deux repères et invente un décalage de
58 pixels. Un angle d'Euler ne dit pas où pointe une part ; `LookVector` et
`UpVector`, oui. Une sonde de couverture qui ignore `CanCollide` compte le
décor. Une sonde qui capture `player.Character` une fois regarde un personnage
détruit. **Une sonde qui dit « rien ne se passe » est suspecte avant le code.**

**3. Regarder l'écran fait partie du travail.** Les tests n'ont rien dit du
maillet raté, de la grenade à anneaux de Saturne, de l'armure en porte de frigo,
du ressort enterré sous une semelle, ni de la faïence bleu et or. Un écran qui
« marche » et un écran lisible sont deux choses.

**4. Un avertissement qui ment coûte plus cher que pas d'avertissement.**
`BodyService` se plaignait à chaque démarrage que le corps standard n'était pas
appliqué, alors qu'il l'était du premier coup — on part alors chercher un bug
qui n'existe pas. Un service **mesure son résultat** au lieu de croire son
appel, et une erreur qu'on signale **se nomme** (un `pcall` dont on jette le
second retour est un aveu qu'on ne saura jamais pourquoi).

---

## 9. Les garde-fous à tenir à jour

Le serveur **refuse de démarrer** si `Config` annonce quelque chose qu'aucun
service n'exécute, et le message nomme le coupable. C'est volontairement brutal :
un objet qui coûte des points et ne fait rien ne se voit jamais en jouant. En
ajoutant un pouvoir, un effet ou une pièce d'allure, il faut tenir à jour :

- `HANDLED` et `HANDLED_TIER6` dans `AbilityService`
- dans `LoadoutService.init` : la table `handled` des sortes d'utilisation,
  `zoneEffects` des sortes de zone, et les vérifications qu'un effet collé par
  une arme nomme une sorte que `Status` connaît et qu'une zone dise combien de
  temps son effet tient
- `knowsShape`, `knowsMaterial` et `knowsLimb` dans `WeaponService`
- les touches de `Config` (`loadout.useKeys`, `loadout.editKey`,
  `sandbox.toggleKey`, `seating.lobbyKey`, `menu.reopenKey`) — un test refuse
  les collisions, et une touche dont le nom ne correspond à aucun `KeyCode` est
  morte sans la moindre erreur

Et les endroits uniques, à ne jamais recopier ailleurs : les planchers de
statistiques (`Modifiers.luau`), la perforation d'armure (`Combat.piercedRatio`),
la règle d'écran (`src/client/Screens.luau`), la conversion des angles du corps
(`WeaponService`).

---

## 10. Trois choses que Josh seul peut faire

- **Jouer à plusieurs.** Rien ne le remplace. Un test en solo dit qu'une
  mécanique fonctionne ; il ne dit pas qu'un duel est tendu ni qu'une classe est
  frustrante. Quand tu livres une mécanique, dis-lui **ce qu'il faut regarder en
  y jouant, et dans quel ordre**.
- **Écouter.** Les quatorze pistes sonores ont été choisies au nom, à la
  bibliothèque d'origine et à la **durée** — jamais écoutées. Dis-le comme tel.
- **Publier.** Et c'est bloquant pour une partie du jeu :
  `TeleportService:ReserveServer` exige un jeu publié, donc le salon privé et
  les codes à cinq signes **ne sont pas atteignables depuis Studio**. C'est le
  seul morceau du jeu qu'un assistant ne peut pas vérifier.

Il reste aussi un réglage de place à poser à la main : **Game Settings → Avatar
→ Avatar Type = R15**. Aucune API ne le change à l'exécution ; `BodyService` le
constate et prévient dans la console.

---

Bon courage. Si quelque chose a l'air de ne pas marcher, la réponse est
presque toujours dans « Les pièges » de `CLAUDE.md` — et si tu en trouves un
nouveau, **écris-le là-bas**. C'est le fichier qui fait que ce projet avance
plus vite qu'il ne régresse.
