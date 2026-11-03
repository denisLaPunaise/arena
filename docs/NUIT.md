# Nuit du 4 novembre 2026 — journal de travail autonome

Josh a confié la nuit à l'assistant (00 h 30 → 8 h), avec pouvoir de décision.
Branche : `nuit-2026-11-04`, commits locaux, **aucun push**.

Ce fichier sert à deux choses : reprendre le travail si la session s'arrête, et
écrire le rapport du matin. **Une session qui reprend lit ce fichier d'abord.**

## Battement

Dernière activité : 2026-11-04 00:50 (mettre à jour à chaque étape — une reprise
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
| 1-2 Checkup + corrections | en cours | |
| 3 Couvre-chefs | à faire | |
| 4 Trois maps | à faire | |
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
