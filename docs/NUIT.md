# Nuit du 4 novembre 2026 — journal de travail autonome

Josh a confié la nuit à l'assistant (00 h 30 → 8 h), avec pouvoir de décision.
Branche : `nuit-2026-11-04`, commits locaux, **aucun push**.

Ce fichier sert à deux choses : reprendre le travail si la session s'arrête, et
écrire le rapport du matin. **Une session qui reprend lit ce fichier d'abord.**

## Battement

Dernière activité : 2026-11-04 05:19 (mettre à jour à chaque étape — une reprise
automatique ne démarre pas si ce battement a moins de 40 minutes)

## Mandat, dans l'ordre

1. Corriger ce qu'il y a à corriger (défauts connus des maps, etc.)
2. Checkup complet : bugs, incohérences, corriger
3. Un couvre-chef par classe (14), reconnaissable, beau, purement visuel
4. Trois nouvelles maps, différentes des quatre autres, stratégies nouvelles
5. Tester en jeu, éventuellement nouveaux objets
6. Rapport complet au matin

## État

| Étape | État | Notes |
| --- | --- | --- |
| 1-2 Checkup + corrections | fait | voir journal |
| 3 Couvre-chefs | fait | 14 maillages générés, regardés, posés en jeu |
| 4 Trois maps | fait | Bazar, Serre, Bois brumeux |
| 5 Test + objets | fait | tests solo des 14 classes ; pas de nouvel objet (raison dans le rapport) |

## Journal

- 00:32 — branche créée, fichier de suivi posé.
- Checkup code : tests/selene/stylua verts au départ (1578). Place = dépôt octet pour octet.
- Trouvé et corrigé : **l'accélération des nouveaux joueurs n'était jamais appliquée** (Economy.isBoosted). Branchée + test.
- Nouveau test `wiring` : toute fonction pure exportée doit être appelée par le jeu, ou excusée par écrit.
- 19 chiffres des paliers 6 en dur → `Config.abilities.tier6` ; 4 chiffres de lancer/grenade → `Config.loadout` (valeurs inchangées).
- Touches E, T, P en dur → lues dans Config, ajoutées au test des collisions. Vérifié en jeu : toutes les touches résolvent.
- Garde-fou d'inondation sur les 6 remotes d'interface (`Throttle` + `RemoteGuard`), seau 12 jetons / 8 par s. Vérifié : démarrage propre.
- **Points en réserve branchés** (déclarés dans Config, jamais appliqués) : vérifié en jeu, 2 achats → PV max 100 → 120 après réapparition ; recharge masquée pour les classes passives (le test l'a attrapé).
- Remote de l'arbre : l'ancien intervalle de 0,1 s (qui jetait un double clic) remplacé par `RemoteGuard`.
- **Bandeau des touches coupé aux deux bords** sur fenêtre étroite → rétrécit pour tenir. Vu à l'écran, corrigé, revu.
- **Colisée** : 3 lignes de tir dégagées (121 studs) → 0 sur 25. Deux tronçons de colonne flanquent chaque stèle (portique en ruine). Cercle final 4/16 → 8/16 (quatre chapiteaux à hauteur d'homme dans la fosse ; la 1re version à hauteur de poitrine passait sous le regard de la sonde, la 2e montait à 13/16, trop encombré).
- **Sanctuaire** : 2 lignes de 147 studs → 0 sur 25. Quatre lanternes de pierre aux angles du 2e gradin, aucun chemin touché. Regardé à l'écran.
- Cargo et Carrière : rien à signaler à la reconstruction. Les quatre maps sont propres. La place finit sur le Sanctuaire, comme au départ.
- **Couvre-chefs** : 1re version en pièces (boîtes) écrite, regardée, jetée — flottait sur la tête ronde. Remplacée par 15 maillages `generate_mesh` (14 classes + cheveux du Vampire), réglés un par un sur un corps R15 standard, de face et de trois quarts. Chargés par `CreateMeshPartAsync` au démarrage : console « Couvre-chefs : 15 maillages chargés ». Vérifié en jeu : joueur + 3 mannequins coiffés, changement de classe suivi.
- Limite rencontrée : `generate_mesh` lancé 13 fois en parallèle → 7 refus « Too Many Requests ». Relancés un par un, tous passés.
- **BUG MAJEUR trouvé : les attaques traversaient les murs.** Le ciblage prenait l'ennemi le plus proche dans la portée, sans ligne de vue. Corrigé : le plus proche ennemi EN VUE. Mannequins du bac à sable soumis à la même règle — vérifié en jeu : 3 coups derrière un mur = 0 dégât, 3 coups sans mur = 29 dégâts.
- **Map 5 — Le Bazar** (`tools/BuildBazarMap.luau`) : marché de nuit, trois allées parallèles, ruelles de traverse décalées. Mesures : 0/25 lignes, cercle 8/16, enfilade max 54 studs, diagonale max 89 (dit tel quel). Trois défauts trouvés par la mesure (ruelles alignées → 115 studs ; ligne médiane des allées du bord → 114 ; lampadaires amincis → 2 lignes rouvertes) et deux à l'écran (tout orange ; fûts laiton).
- **Map 6 — La Serre** (`tools/BuildSerreMap.luau`) : jardin d'hiver sous verre, labyrinthe rayonnant ; on voit le centre de partout (10/10 départs, mesuré), on ne passe pas. Repose sur la nouvelle règle de ligne de vue. Mesures : 0/25 lignes, cercle 4/16 (le plancher), ombre 0/0, soleil 18,5° trouvé par balayage.
- **Map 7 — Le Bois brumeux** (`tools/BuildBoisMap.luau`) : forêt d'automne dans le brouillard, chapelle en ruine au centre, arbres tirés au sort par graine fixe et jumeaux par rotation. Mesures : 0/25 lignes, cercle 12/16, vue médiane 30 studs. Trouvé : densité trop faible (vue médiane 160 → calculée et triplée), brèches de chapelle sur l'axe des camps (5 lignes ouvertes), `Atmosphere` incapable de faire un brouillard court (→ ancien brouillard `FogEnd`, et remise à zéro ajoutée à trois autres recettes).
- 01:56 → 05:12 : session interrompue par la limite d'usage, reprise à 05:12. La reprise automatique de 04:29 n'a rien modifié.
- **Rotation des maps** : `MapRotation` (pur, testé), `MapService.rotate/stash/applyLighting`, `tools/StashMap.luau`. Les 7 maps rangées dans `ServerStorage.ArenaMaps` avec leur éclairage et leurs 8 matières. Vérifié dans la VM du jeu : une map à la fois, éclairage qui suit (brouillard du Bois compris), jamais deux fois de suite. Trouvé en route : une collision de nom de matière (`ArenaGrainClair` au Colisée ET au Sanctuaire, renommée), et les nuages rangés qui faisaient protester Roblox (rangés en attributs). **La place doit être enregistrée.**

---

## Rapport du matin

Douze commits sur la branche `nuit-2026-11-04`, rien de poussé, `main`
intact. 1 818 vérifications (1 578 au départ), Selene et StyLua propres.

### Les deux choses à faire en premier

1. **Enregistrer la place dans Studio** (Ctrl+S ou publier). Les sept maps
   rangées pour la rotation n'existent que dans la place ouverte.
2. **Jouer à deux, en regardant d'abord les tirs.** Les attaques ne
   traversent plus les murs, et c'est ce qui change le plus le jeu.

### Ce qui a été corrigé

- **Les attaques traversaient les murs.** Le ciblage ne regardait pas la ligne
  de vue. Corrigé et vérifié seul sur un mannequin : 0 dégât derrière un mur,
  29 sans le mur.
- **L'accélération des nouveaux joueurs n'était jamais appliquée.** Branchée.
- **Les points d'arbre en réserve tombaient dans le vide.** Ils achètent
  maintenant les améliorations communes que la fiche prévoyait. Vérifié en
  jeu : 100 → 120 PV.
- **Lignes de tir d'un camp à l'autre** : Colisée (121 studs) et Sanctuaire
  (147 studs), refermées. Cercle final du Colisée : 4/16 → 8/16.
- Garde-fou contre l'inondation sur les sept remotes d'interface ; 23 chiffres
  en dur passés dans `Config` ; touches E, T, P lues dans `Config` ; bandeau
  des touches qui débordait de l'écran.
- Un nouveau test refuse toute règle écrite que le jeu n'appelle pas : c'est la
  panne qui avait déjà coûté le plus cher, quatre fois.

### Ce qui a été construit

- **Un couvre-chef par classe** : quatorze maillages générés, regardés et
  réglés un par un, posés en jeu sur les joueurs et les mannequins.
- **Trois maps** : le Bazar (nuit, trois allées), la Serre (sous verre, on voit
  tout et on ne passe pas), le Bois brumeux (brouillard, embuscade).
- **La rotation des sept maps** : une par partie, jamais deux fois de suite,
  avec son éclairage.

### Ce que je n'ai pas fait, et pourquoi

- **De nouveaux objets** : les 62 sont équiprobables et leurs cotes s'affichent
  pour respecter Roblox. Un objet de plus change les cotes, la collection et le
  budget, et la fiche dit d'abord d'équilibrer à 62.
- **Les matières du Cargo** (56,6 % de sa surface sans matière générée) :
  du visuel, gardé pour après les vrais tests.
- **Jouer à plusieurs** : impossible seul. Tout ce qui vise quelqu'un n'a
  touché que des mannequins.

Le détail de ce qu'il faut regarder en jouant, dans l'ordre : section 36
d'`A-TESTER.md`. Les décisions prises sans toi : fin de `DECISIONS.md`.
