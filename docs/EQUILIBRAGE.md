# Équilibrage — d'où vient chaque chiffre

Josh a confié les équilibrages à l'assistant, à charge pour lui de les sourcer
plutôt que de les poser au feeling. Ce document dit, pour chaque réglage de
`src/shared/Config.luau`, d'où vient sa valeur et à quel point on peut s'y fier.

Dernière mise à jour : 25 octobre 2026.

## Les trois niveaux de confiance

| Niveau | Ce que ça veut dire |
| --- | --- |
| **Vérifié** | Une source officielle ou réglementaire le dit. On ne change pas sans raison. |
| **Documenté** | Plusieurs jeux comparables convergent. Bon point de départ, à ajuster. |
| **À jouer** | Aucune source ne peut répondre. La valeur est raisonnée, le test tranche. |

Ce dernier niveau est le point important : **aucune recherche ne dira si ce
duel-là est amusant pour ce groupe-là.** La documentation donne les bons ordres
de grandeur et évite les erreurs connues ; elle ne remplace pas une partie. Les
réglages « à jouer » sont ceux à regarder en premier après une session.

---

## Monétisation et tirages — vérifié

Source : [Paid random items policy guidelines](https://create.roblox.com/docs/production/monetization/paid-random-items)
(Creator Hub, documentation officielle) et
[Clarifying Requirements for Paid Random Items](https://devforum.roblox.com/t/clarifying-requirements-for-paid-random-items/4654622)
(annonce Roblox, 2026).

Ce n'est pas de l'équilibrage, c'est de la conformité : ces points ne se
négocient pas et ils contraignent la conception de l'écran de tirage.

| Exigence | Conséquence sur notre design |
| --- | --- |
| Afficher chaque résultat et sa probabilité, total exactement 100 % | Les 62 objets étant équiprobables, ils peuvent être regroupés sous une seule ligne : la politique autorise le regroupement des objets de probabilité identique |
| Le lien vers les cotes doit porter un mot, pas une icône « (i) » seule | Bouton « Détails » sur l'écran de tirage |
| Tout résultat doit donner quelque chose au joueur | Les doublons donnant des fragments, c'est satisfait. Cette règle est la raison de ne jamais retirer les fragments sans remplacement |
| Un modificateur de probabilité doit être expliqué chiffré, cotes mises à jour quand il est actif | La garantie tous les sept tirages en est un : deux tables à afficher, celle des tirages 1 à 6 et celle du septième |
| Blocage régional | `PolicyService:GetPolicyInfoForPlayerAsync`, attribut `ArePaidRandomItemsRestricted` |
| Alternative acceptable citée par Roblox : une voie gratuite pour obtenir l'objet | Nos pièces gagnées en jouant sont cette voie, donc les joueurs restreints gardent accès à toute la collection |

À noter : les tirages payants sont restreints pour les mineurs au Royaume-Uni.
C'est le même attribut `ArePaidRandomItemsRestricted` qui le signale, donc rien
de plus à coder.

## Le classement Elo — documenté

Sources : [playerbenchmark.com](https://playerbenchmark.com/blog/what-is-elo-rating),
[teamupgg.com](https://teamupgg.com/blog/what-is-elo-rating-competitive-gaming),
[omnicalculator.com](https://www.omnicalculator.com/sports/elo),
[debateladder.com](https://debateladder.com/blog/elo-rating-explained),
[Convergence and stationary distribution of Elo rating systems](https://arxiv.org/pdf/2410.09180)
(arXiv).

Ce que les sources disent, et qui a changé notre réglage :

- **K = 32** est la valeur par défaut courante dans les communautés de jeu.
- Pour un **petit groupe qui démarre**, on recommande **48 à 64**, afin que le
  classement se stabilise vite.
- La bonne pratique est de **faire baisser K avec le nombre de parties jouées
  par le joueur**, comme le fait la FIDE par paliers — et non avec la taille de
  la population, ce que faisait notre première version.
- Un K élevé rend le classement bruyant quand il y a peu de résultats : un
  classement bâti sur une poignée de parties est une estimation grossière.
- Si ça reste trop nerveux, la vraie réponse n'est pas de baisser K mais de
  passer à **Glicko** ou **TrueSkill**, qui portent une incertitude explicite
  par joueur.

D'où les paliers retenus : K = 64 sur les dix premières parties, 48 jusqu'à la
quarantième, 32 ensuite.

## Les tirages et la garantie — documenté, avec un écart assumé

Sources : comparatifs de systèmes de pitié
([bahomu.com](https://www.bahomu.com/blogs/news/gacha-pity-systems-hsr-vs-genshin-impact-comparison-guide),
[sabertoothgames.com](https://sabertoothgames.com/how-gacha-pity-systems-work-across-genshin-honkai-and-zenless-compared/),
[mwm.ai](https://mwm.ai/glossary/pity-system)).

Il n'existe pas de standard. Le schéma commun des gros jeux est : taux de base
faible, montée progressive des chances (*soft pity*), plafond garanti (*hard
pity*) — 90 tirages chez Genshin Impact et Honkai: Star Rail, 80 sur la bannière
d'armes de Genshin, 200 chez Nikke.

**Notre design s'en écarte volontairement, et c'est cohérent :** ces plafonds à
80-90 existent parce que ces jeux ont des raretés, donc un objet désirable et
beaucoup de déchet. Nous avons l'équiprobabilité stricte et la puissance portée
par le coût en points : il n'y a pas d'objet jackpot, donc pas besoin d'une
montée progressive. La garantie d'un objet neuf tous les sept tirages n'est pas
un *soft pity*, c'est un plafond court contre la fin de collection, qui fait
passer la collection complète d'environ 290 tirages à 175.

## Les prix de skins — documenté

Repère retenu dans la fiche de conception : Murder Mystery 2, qui se monétise
uniquement par du cosmétique et place ses skins entre 100 et 300 Robux. Les
paliers à 75 / 150 / 300 / 500 Robux en découlent.

**Non revérifié par l'assistant à ce jour.** Deux choses à confirmer avant de
mettre les skins en vente : les prix actuels de MM2, et le taux de prélèvement
de Roblox sur les achats en jeu (la fiche dit environ 30 %).

## Le combat — à jouer

Sources consultées : discussions de conception sur la durée de combat
([ResetEra](https://www.resetera.com/threads/do-you-prefer-high-ttk-or-low-ttk-in-fps-games-time-to-kill.32583/),
[Splitgate](https://steamcommunity.com/app/677620/discussions/0/1653297026037083000/),
[Time-to-kill](https://moderncombat.fandom.com/wiki/Time-to-kill)) et un
calculateur de bandes de durée
([calculatorsuniverse.com](https://calculatorsuniverse.com/games/ttk-calculator)).

**La recherche ne tranche pas, et il faut le dire franchement.** Il n'y a pas
d'étude, seulement des posts de forum et des calculateurs. Ce qui en ressort :

- Les durées de combat des jeux de tir se comptent en **fractions de seconde à
  deux secondes**. Sans objet pour nous : ce sont des armes à distance avec un
  seul échange décisif.
- Les joueurs de jeux d'arène penchent pour une **durée longue**, au motif que
  ça rend les armes distinctes et laisse place à l'esquive et au terrain. C'est
  l'argument le plus proche de notre cas.
- La durée seule ne veut rien dire : vitesse de déplacement, échelle de la map
  et exigence de visée changent complètement son ressenti.

Nos chiffres actuels donnent un duel de **8,5 secondes** dans un sens et **8,7
dans l'autre** — un test le vérifie et casse si un réglage rompt cet équilibre.
C'est long pour un jeu de tir, cohérent pour un duel au corps à corps avec vol
de vie et repoussement. Mais c'est une valeur raisonnée, pas une valeur sourcée.

**Ce qu'il faut regarder en jouant, dans cet ordre :**

1. Le duel dure-t-il trop longtemps ? Si oui, monter les dégâts avant de baisser
   les PV : baisser les PV du Colosse efface son identité.
2. Le repoussement du Colosse est-il satisfaisant ou juste agaçant ? C'est le
   seul réglage qui peut rendre le jeu désagréable sans être déséquilibré.
3. Le Vampire arrive-t-il à revenir au contact après avoir été poussé ? Si non,
   le vol de vie ne sert à rien et le duel est plié.
4. Trois manches, est-ce trop court pour ressentir quelque chose, ou juste assez ?

La vitesse de déplacement par défaut de Roblox est de 16 studs par seconde ;
le Vampire est à 20 et le Colosse à 12. Aucune source utile trouvée sur les
paliers de vitesse en combat : les recherches ne renvoient que des pages de
tutoriel génériques. À jouer également.

## Ce qui reste à chercher

- Prix de skins actuels sur Roblox et prélèvement réel de la plateforme
- Rythme de distribution des caisses comparé à d'autres jeux Roblox compétitifs
- Ergonomie des commandes sur téléphone : nombre de boutons tenable au pouce,
  pour valider la limite de six objets
- Durée d'une partie complète comparable en PvP par manches
