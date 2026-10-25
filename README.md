# Arena

Jeu PvP d'arène sur Roblox. Deux équipes s'affrontent en manches : la classe est
tirée au sort après une phase de bans, et l'arbre de compétences se construit
manche après manche avant d'être remis à zéro à la partie suivante.

La conception complète est dans la fiche « Arena — PvP à classes et progression
définitive ». Les notes de travail pour l'assistant sont dans
[CLAUDE.md](CLAUDE.md).

---

## Installation, pas à pas

À faire une seule fois. Tout se passe dans **PowerShell** (bouton Démarrer,
taper « PowerShell », Entrée) et dans **Roblox Studio**.

### 1. Installer Rokit

Rokit est le gestionnaire d'outils : il installe Rojo, Wally, StyLua, Selene et
Lune aux versions exactes notées dans `rokit.toml`, pour que tout le monde
travaille avec les mêmes.

```powershell
Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
```

**Ferme PowerShell et rouvre-le ensuite**, sinon la commande `rokit` reste
introuvable : le chemin d'installation n'est ajouté qu'au démarrage d'un
terminal.

Pour vérifier :

```powershell
rokit --version
```

### 2. Installer les outils du projet

```powershell
cd "$HOME\OneDrive\Desktop\Arena"
rokit install
```

La première fois, Rokit demande de confirmer chaque outil qu'il va télécharger
(une question par outil) — réponds oui. C'est sa protection contre un outil
ajouté en douce dans le fichier de configuration.

Pour vérifier :

```powershell
rojo --version; lune --version; stylua --version; selene --version
```

### 3. Vérifier que les tests passent

C'est le test qui ne demande pas Studio : il charge les modules de calcul et
vérifie que les chiffres de la configuration ne se contredisent pas.

```powershell
lune run tests/run
```

Tu dois voir une liste de lignes `ok` et, à la fin, « tout est cohérent ».

### 4. Installer Roblox Studio

Va sur [create.roblox.com](https://create.roblox.com), connecte-toi avec ton
compte Roblox, et clique sur le bouton de téléchargement de Studio. L'installeur
fait le reste.

### 5. Créer la place vide du projet

Dans Studio : **New** → modèle **Baseplate** → puis **File → Save to Roblox**.
Donne-lui un nom (« Arena »), enregistre. C'est cette place en ligne qui servira
de terrain commun ; elle n'a pas besoin d'être publiée au public.

Pour que plusieurs personnes puissent construire les maps en même temps, active
le Team Create : **File → Collaboration** (ou l'onglet *View* → *Team Create*
selon la version), puis **Enable**.

### 6. Installer le plugin Rojo dans Studio

Dans PowerShell, dans le dossier du projet :

```powershell
rojo plugin install
```

Ferme et rouvre Studio. Un bouton **Rojo** apparaît dans l'onglet *Plugins*.

### 7. Brancher le code sur Studio

Dans PowerShell, dans le dossier du projet :

```powershell
rojo serve
```

Laisse cette fenêtre ouverte — c'est le serveur de synchronisation. Puis dans
Studio : onglet *Plugins* → bouton **Rojo** → **Connect**. L'adresse proposée
(`localhost:34872`) est la bonne.

Dès que c'est connecté, les dossiers `Arena` apparaissent dans
`ReplicatedStorage`, `ServerScriptService` et `StarterPlayer`.

### 8. Vérifier le jalon de l'étape 1

Dans Studio, lance une partie de test : bouton **Play** (ou F5). Ouvre la
console : **View → Output** (ou F9 en jeu).

Tu dois lire :

```
================================================
[Arena] Serveur démarré — réglages version 1
[Arena] 14 classes, 4 formats, budget d'équipement 12 points
[Arena] Arbre à 6 paliers, premier à 4 manches gagnées (7 au maximum)
[Arena] Si tu lis ces lignes, l'étape 1 est validée : Rojo est branché.
================================================
[Arena] Client démarré pour <ton pseudo> — réglages version 1
```

Si ces lignes s'affichent, l'étape 1 est finie : le code du repo s'exécute dans
Studio.

---

## Le travail de tous les jours

```powershell
rojo serve                 # synchronise le repo vers Studio (à laisser tourner)
lune run tests/run         # les tests de calcul, sans Studio
stylua .                   # remet le code en forme
selene src                 # cherche les erreurs courantes
```

Le code s'écrit **dans le repo**, jamais dans Studio : Rojo écrase les scripts
synchronisés à chaque modification de fichier, donc une ligne tapée dans Studio
est perdue.

Les maps, elles, se construisent **uniquement dans Studio** : Rojo n'y touche
pas. Chaque map doit contenir `SpawnsA` et `SpawnsB` (cinq points de spawn
chacun), une part `ZoneCenter`, un dossier `Cover` et une part `MapBounds`.

## Structure du repo

```
default.project.json   ce que Rojo synchronise, et vers où
rokit.toml             les outils et leurs versions
src/shared/            ReplicatedStorage.Arena — logique pure et données
  Config.luau          tous les chiffres réglables du jeu, à un seul endroit
  Classes.luau         les quatorze classes
src/server/            ServerScriptService.Arena — l'autorité
src/client/            StarterPlayerScripts.Arena — interface et entrées
tests/                 suites Lune, hors du projet Rojo
.github/workflows/     formatage, analyse, tests et build à chaque push
```

Tous les chiffres d'équilibrage sont dans `src/shared/Config.luau`, avec la
raison de chaque valeur en commentaire. C'est le seul fichier à ouvrir pour
régler le jeu.
