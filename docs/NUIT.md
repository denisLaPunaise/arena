# Nuit du 4 novembre 2026 — journal de travail autonome

Josh a confié la nuit à l'assistant (00 h 30 → 8 h), avec pouvoir de décision.
Branche : `nuit-2026-11-04`, commits locaux, **aucun push**.

Ce fichier sert à deux choses : reprendre le travail si la session s'arrête, et
écrire le rapport du matin. **Une session qui reprend lit ce fichier d'abord.**

## Battement

Dernière activité : 2026-11-04 01:52 (mettre à jour à chaque étape — une reprise
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
| 5 Test + objets | à faire | |

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
