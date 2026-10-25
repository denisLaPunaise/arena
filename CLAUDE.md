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
| L'assistant | Tout le code Luau, la structure du repo, la configuration, les tests |
| Josh | Tout ce qui passe par Roblox Studio : maps, lancement des parties, tests de jeu, publication |

Le Luau ne s'exécute que dans Studio. **Josh est la seule boucle de test en
jeu** : l'assistant ne peut jamais vérifier lui-même qu'une mécanique
fonctionne, ni juger si elle est amusante. D'où la règle d'architecture
ci-dessous, et d'où l'habitude à prendre : quand une mécanique est écrite, dire
à Josh précisément quoi faire dans Studio pour la vérifier, et quoi observer.

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
- **Rojo écrase, il ne fusionne pas.** Une modification faite dans Studio sur un
  script synchronisé est perdue à la prochaine synchro. Le code s'écrit dans le
  repo, jamais dans Studio.
- **Les tirages payants sont réglementés par Roblox.** Comme les Robux achètent
  des pièces de tirage, il faudra afficher la probabilité exacte de chaque
  résultat avec un total de 100 %, mettre ces cotes à jour par joueur (la
  garantie tous les sept tirages compte comme un modificateur de probabilité),
  et bloquer le tirage dans les régions où ces mécaniques sont interdites. À
  budgéter dès la conception de l'écran de tirage, pas après.
- **Le taux de doublons pilote deux économies à la fois** : moins de doublons,
  moins de fragments, donc des skins plus rares. Ces deux réglages se changent
  ensemble.
- **Ne pas prendre de l'avance sur l'ordre des étapes.** Douze objets suffisent
  à tester si le budget est bon ; s'il n'est pas amusant à douze, il ne le sera
  pas à soixante-deux.

## L'ordre des étapes

1. Squelette du repo : Rojo, Rokit, Wally, StyLua, Selene, `CLAUDE.md`, fichier
   de configuration, GitHub Actions. **Jalon : un message dans la console de
   Studio.**
2. Prototyper le Vampire contre le Colosse sur une map vide, en trois manches
3. Ajouter la zone qui se referme, puis l'agonie et le relèvement
4. Ajouter l'arbre à six paliers sur ces deux classes seulement
5. Seulement ensuite : les douze autres classes, puis l'équipement et les
   tirages

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
