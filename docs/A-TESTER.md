# Ce qu'il faut tester en jeu

Josh, c'est ta liste. Tout ce qui est ici fonctionne techniquement — je l'ai
vérifié dans Studio, seul. Ce que je **ne peux pas** vérifier, c'est si c'est
amusant, si c'est lisible dans le feu de l'action, et si ça tient à plusieurs.
C'est exactement ce que cette liste demande.

**Comment t'en servir :** joue dans l'ordre. Chaque section se teste en une ou
deux parties. Note ce qui cloche en citant le numéro — ça me suffit pour
retrouver le code.

Une remarque qui vaut pour tout : **« ça ne m'a pas plu » est un rapport de bug
valide.** Les chiffres de `Config.luau` sont des points de départ raisonnés, pas
des certitudes, et le seul moyen de les valider c'est de jouer.

---

## Avant de commencer

- [ ] **Publie une version de la place.** Tout n'est pas annulable, et j'ai
      touché à la place directement pendant cette session.
- [x] ~~Reconnecte le plugin Rojo~~ — **fait**, et tout est passé : la place a
      reçu la bonne version de tout le code, **sans doublons**, et la copie de
      `TreePanel` que j'avais éditée à la main a été écrasée par celle du dépôt.
      C'est le bon sens de l'écrasement : **le dépôt fait foi, toujours.**
- [ ] **Règle la confirmation de Rojo sur « Never ».** C'est ce qui nous a coûté
      une heure aujourd'hui. Par défaut le plugin demande une confirmation **une
      fois par session de Studio**, et tant que personne ne clique, rien ne se
      synchronise **et aucune erreur ne s'affiche** : ça a tout l'air de
      marcher. Le réglage est dans le panneau du plugin Rojo, ligne
      « Confirm behavior ».
- [ ] **Vérifie quand même qu'il n'y a pas de doublons** dans
      `ReplicatedStorage.Arena`, `ServerScriptService.Arena` et
      `StarterPlayerScripts.Arena`. J'en avais trouvé cinq en cours de route,
      dont le RemoteEvent `Tree`. Deux objets du même nom, et le jeu devient
      muet sans la moindre erreur — c'est le genre de panne qui ne se voit
      qu'en regardant l'arborescence.

---

## 1. Le duel nu — la question qui commande tout

C'est l'étape 2, et rien de ce qui suit ne vaut la peine si la réponse est non.

Pour isoler le duel, mets dans `src/shared/Config.luau` :
`round.zoneEnabled = false`, `downed.enabled = false`, `skillTree.enabled = false`.

1. **Vampire contre Colosse, à deux, trois manches.** Est-ce que c'est tendu ?
2. Est-ce que le Vampire arrive à revenir au contact après un repoussement, ou
   est-ce qu'il passe son temps à courir ?
3. Est-ce que le Colosse a l'impression de tenir le terrain, ou d'être une
   cible lente ?
4. Les classes s'échangent entre deux parties. **Joue les deux côtés** avant de
   juger : c'est fait exprès.
5. Si une manche dure trop longtemps, dis-le — c'est le signal qui justifie la
   zone.

---

## 2. La zone qui se referme

Remets `round.zoneEnabled = true`.

6. Le premier resserrement arrive après deux minutes. **Trop tard ? trop tôt ?**
7. Les quatre resserrements doivent se ressentir pareil (chacun retire environ
   43 % du rayon). Est-ce que le dernier surprend quand même ?
8. Le mur est visible ? Il change de couleur dix secondes avant de bouger —
   est-ce que tu l'as remarqué **sans le chercher** ?
9. Le bandeau orange en bord d'écran quand tu es dehors : assez clair ?
10. La zone finit à 16 studs de rayon, sur la plateforme centrale. Est-ce que la
    fin de manche devient un vrai duel, ou une bousculade ?
11. **Les murs bas près du centre** sont bas exprès, pour ne pas rendre la fin
    de manche aveugle. Est-ce que ça marche ?

---

## 3. L'agonie et le relèvement

Remets `downed.enabled = true`. **Il faut être au moins trois pour tester ça
sérieusement** : à deux, il n'y a jamais personne pour relever.

12. Tomber à terre : c'est lisible ? L'écran bat en rouge, il y a un compte à
    rebours au-dessus de la tête.
13. Relever quelqu'un demande de rester à 8 studs. **S'éloigner remet la barre à
    zéro**, elle ne se met pas en pause. Est-ce que c'est frustrant ou tendu ?
14. On repart à 40 % des PV. Trop ? Pas assez ?
15. Le coup de grâce sur un joueur à terre ne rapporte **rien** au Vampire :
    pas de vol de vie. Est-ce que ça se sent ?
16. Un joueur à terre **ne prend pas** les dégâts de zone. Est-ce que ramper
    hors de la zone pour fuir devient une tactique bizarre ?
17. Quand il ne reste personne pour relever, l'équipe tombe d'un coup. Est-ce
    que ça arrive trop vite ?

---

## 4. L'arbre de compétences — le gros morceau de cette session

Remets `skillTree.enabled = true`.

### La phase de dépense

18. Entre deux manches, un écran s'ouvre pendant **quinze secondes**. C'est
    trop long ? trop court ? Regarde surtout **la première fois**, quand tu
    découvres les trois branches : c'est là que quinze secondes se jugent.
19. Le bouton **« Prêt »** coupe la phase dès que tout le monde a appuyé. Est-ce
    que vous vous en servez, ou est-ce que vous attendez la fin ?
20. La phase est **sautée** quand personne n'a rien à dépenser. Est-ce que ça se
    remarque, ou est-ce que ça casse le rythme d'avoir une manche sans écran ?
21. **La touche T** ouvre l'arbre en lecture seule pendant une manche. Utile ?

### Le choix de branche

22. Chaque classe a trois branches : identité, distance, résilience. Est-ce que
    les trois donnent envie, ou est-ce qu'il y en a une qu'on ne prend jamais ?
23. **Le choix est définitif pour la partie.** Est-ce que ça pèse assez, ou
    est-ce qu'on choisit au hasard ?
24. Le sacrifice est affiché en rouge, aussi gros que le bonus. Est-ce qu'on le
    lit, ou est-ce qu'on clique sans le voir ?
25. **La Catapulte** retire toute la poussée du Colosse et allonge sa portée.
    Est-ce que ça reste un Colosse, ou est-ce que ça en fait autre chose ?
26. **La Peste** retire tout le vol de vie du Vampire. C'est le sacrifice le
    plus brutal du jeu. Est-ce que quelqu'un la prend ?

### Les paliers

27. Une partie de M manches donne M points. Une victoire 4-0 mène au palier 5,
    et **seule une série de sept manches ouvre le palier 6**. Est-ce que le
    palier 6 donne envie d'aller au bout d'une série serrée ?
28. Le palier 6 coûte deux points. Est-ce qu'on hésite vraiment entre « monter
    au bout » et « garder un point » ?
29. **Le point de revanche** : l'équipe qui perd trois manches d'affilée reçoit
    un point de plus, une seule fois par partie. Est-ce que ça se sent ? Est-ce
    que ça rattrape trop, ou pas assez ?
30. Le bloc « CE QUE ÇA DONNE, EN CHIFFRES » montre ce que la branche a changé.
    Est-ce que c'est clair, ou est-ce que c'est du jargon ?

### Les quatre effets de palier 6

Il faut une série de sept manches pour les voir. Ils sont neufs et jamais
testés par quelqu'un d'autre que moi.

31. **Sangsue** — le vol de vie fonctionne sur les dégâts de zone subis par les
    ennemis, à moitié. Est-ce que ça pousse le Vampire à jouer passivement ?
32. **Fauve** — le bond. Il n'a **pas de touche** : attaquer quelqu'un hors de
    portée te fait lui sauter dessus (recharge de huit secondes). Est-ce que
    c'est intuitif, ou est-ce que tu bondis sans le vouloir ?
33. **Bélier** — la charge touche jusqu'à trois ennemis. Visible à deux ?
34. **Catapulte** — le coup laisse un bloc au sol six secondes. **Ce bloc te
    gêne aussi.** Est-ce que c'est un outil, ou un piège pour soi-même ?
35. **Peste** et **Monolithe** affichent « pas encore en jeu » sur leur palier 6,
    et c'est normal : il n'y a ni armures ni projectiles. Est-ce que l'affichage
    est clair, ou est-ce qu'on croit à un bug ?

---

## 5. L'écran, et tout ce qui se lit

36. Teste sur **téléphone** si tu peux. Le panneau de l'arbre se met à l'échelle
    et les trois cartes s'empilent en dessous de 700 pixels de large.
37. La ligne d'arbre en haut à gauche (« palier 3 / 6 · 2 points à dépenser »)
    gêne pendant un combat ?
38. Quand une manche se termine, le gain de point est annoncé. Visible ?
39. Les accents s'affichent bien partout ? (C'est le genre de chose qui casse
    entre Studio et le jeu publié.)

---

## 5 bis. Les coups se voient enfin — vérifié, sauf les nombres

Rojo a resynchronisé, j'ai donc pu voir tourner cette partie. **Vu de mes
yeux** : le trait du coup, les éclairs, et le fait que tout se crée dans
`Workspace.ArenaEffects` puis disparaît proprement.

**Pas vu de mes yeux : les nombres eux-mêmes.** Pas parce qu'ils manquent —
j'ai interrogé le client en direct pendant un combat, et ils sont là : affichés,
à l'écran, au bon endroit, de la bonne couleur, avec la transparence qui monte
bien de 0 à 1 pendant qu'ils s'effacent. C'est l'outil de capture d'écran de
Studio qui ne photographie pas ce type d'affichage. Je l'ai prouvé proprement :
une part rouge et un panneau vert posés côte à côte au même instant, la part
apparaît sur la capture, le panneau non.

Donc les nombres sont **vérifiés par instrumentation, pas à l'œil** — c'est
moins solide, et c'est pour ça qu'ils restent en tête de ta liste. La même
réserve vaut pour le **compte à rebours au-dessus d'un joueur à terre**
(point 12), que je n'ai jamais pu voir non plus.

À regarder en premier, donc :

- [ ] **Le trait du coup** part de l'attaquant à chaque attaque, qu'elle touche
      ou non. C'est fait exprès : rater doit se voir, sinon on n'apprend jamais
      la portée de sa classe.
- [ ] **Les nombres qui montent.** Rouge quand tu encaisses, clair quand tu
      donnes, vert pour le vol de vie, violet pour la propagation de la Peste,
      orange pour la zone. Un coup plus fort s'écrit plus gros.
- [ ] Les dégâts de zone sont **cumulés une seconde** avant d'être annoncés,
      sinon un nombre partirait à chaque image.
- [ ] Un éclair sur la cible touchée, et sur qui tombe ou se relève.
- [ ] **Si l'écran devient illisible**, `Config.effects.enabled = false` coupe
      tout d'un coup, et le jeu revient exactement à avant.

---

## 6. Ce que je ne peux pas tester du tout

Ça ne dépend pas d'un réglage, ça dépend d'avoir du monde :

40. **Le 2v2 et le 3v3.** Tout est écrit pour, rien n'a jamais tourné à plus de
    deux. C'est là que la propagation de la Peste et la charge du Bélier
    prennent leur sens, et c'est là que les bugs de roster sortiront.
41. **Deux joueurs qui quittent en pleine partie.** Le code prévoit une manche
    sans vainqueur, mais ça n'a jamais été vu en vrai.
42. **La latence.** Tout est serveur-autoritaire, donc un coup part avec le
    délai du réseau. À quel point ça se sent ?

---

## 7. Les bans et le tirage — **jamais vu tourner en vrai**

Honnêteté d'abord : j'ai vérifié **l'écran** (il s'affiche, les quatorze classes
sont lisibles, les accents passent) et **la logique** (872 vérifications, dont
l'unicité des classes, le miroir du 1v1 et le fait qu'une classe bannie ne
ressort jamais). Mais une phase de bans demande **deux équipes qui votent**, et
je suis seul dans Studio. Toute cette section est donc à regarder avec méfiance.

`Config.draft.enabled = false` ramène au duel Vampire contre Colosse si ça gêne.

43. **La durée totale.** Deux bans de vingt secondes, puis six secondes de
    relancement, puis cinq de révélation : **près d'une minute avant la
    première manche**, pour un match en deux manches gagnantes. C'est le
    premier chiffre que je changerais si ça traîne —
    `Config.draft.banVoteSeconds`.
44. **La fenêtre de ban s'écoule en entier**, même si tout le monde a déjà voté.
    C'est fait exprès : l'équipe d'en face doit avoir le temps de lire ce qui
    vient d'être écarté. Est-ce que ça se ressent comme du respect ou comme de
    l'attente ?
45. **Le vote est à la majorité de l'équipe**, égalité tranchée au sort. À deux
    ou trois, est-ce que vous vous concertez, ou est-ce que chacun clique dans
    son coin ?
46. **Personne ne vote** : une classe est écartée au hasard et la partie
    continue. Testez-le exprès — c'est ce qui arrivera avec un joueur qui
    découvre.
47. **Le relancement est aveugle** : on accepte avant de voir. Est-ce que c'est
    un pari excitant ou juste frustrant ? (Le texte explique pourquoi ; est-ce
    qu'on le lit ?)
48. **La révélation** montre le pouvoir ET la faiblesse. Cinq secondes, est-ce
    que ça suffit pour une classe qu'on ne connaît pas ?
49. **En 1v1, les deux joueurs ont la même classe** (miroir), et les trois
    classes qui ciblent un coéquipier sortent du vivier. Vérifiez que le
    Lien, le Leurre et l'Infirmier n'apparaissent **jamais** en 1v1.

---

## 8. Les douze autres classes — **aucune n'a jamais été jouée**

Tout est codé et vérifié techniquement : le serveur refuse de démarrer si une
classe annonce un pouvoir que rien n'exécute, et j'ai vu l'Artificier poser ses
mines en jeu, avec le stock qui descend et la recharge qui bloque. Mais
**personne n'a jamais joué aucune de ces classes contre quelqu'un.** Les
chiffres sont des points de départ raisonnés, rien de plus.

**La touche du pouvoir est `E` pour toutes.** La classe est tirée au sort, donc
une touche différente par classe serait à réapprendre à chaque partie.

### Ce qu'il faut regarder sur chacune

50. **Traqueur** — les traces de pas apparaissent sous les adversaires, **et
    seulement pour lui**. Vérifiez que personne d'autre ne les voit : si tout
    le monde les voit, le pouvoir est à l'envers.
51. **Artificier** — trois mines par manche, armées après un délai. Le stock
    ne se recharge **qu'entre deux manches**. Trois, c'est assez ?
52. **Spectre** — trois secondes pour traverser un mur, pendant lesquelles il
    **ne peut ni frapper ni être soigné**. Est-ce que trois secondes suffisent
    pour arriver quelque part ?
53. **Lien** — il choisit **l'allié le plus proche**, pas un allié désigné.
    Est-ce que ça suffit, ou est-ce qu'on veut viser ?
54. **Duelliste** — plus fort seul contre un, plus faible dès qu'un deuxième
    ennemi est à moins de 22 studs. **C'est la bascule à vérifier** : est-ce
    qu'elle se sent, ou est-ce qu'on ne comprend pas pourquoi on tape mou ?
55. **Forgeron** — son mur **bloque aussi son équipe**. C'est la faiblesse
    annoncée. Est-ce que c'est un outil ou une punition ?
56. **Pyromane** — ses flammes **le brûlent aussi**. Pareil : outil ou
    punition ?
57. **Leurre** — **lu attentivement, c'est important** : le clone est *posé*,
    pas piloté. Voir la section « Ce que j'ai décidé seul » plus bas. Pendant
    que le clone vit, il ne bouge plus et encaisse 35 % de plus.
58. **Sismique** — l'onde **n'atteint personne en l'air**. Sauter au bon moment
    l'annule entièrement. Est-ce que c'est un contre satisfaisant ou injuste ?
59. **Parasite** — le marqué **est prévenu** (bandeau violet clignotant).
    Vérifiez que le message arrive bien, c'est toute la faiblesse de la classe.
60. **Caméléon** — invisible après 1,2 s d'immobilité, visible au moindre
    mouvement **et dès qu'il frappe**. Est-ce qu'on arrive à en faire quelque
    chose, ou est-ce qu'il clignote en permanence ?
61. **Infirmier** — il relève **deux fois plus vite** et rend plus de PV. À
    trois ou plus, est-ce qu'il devient incontournable ?

### Les questions qui valent pour les douze

62. **Est-ce qu'une classe est clairement la meilleure ?** C'est la question
    qui compte le plus. Si une classe est bannie à chaque partie, dites-le.
63. **Est-ce qu'une classe est injouable ?** Même chose dans l'autre sens.
64. **Est-ce que la faiblesse se sent ?** Chaque classe en a une qui n'est pas
    décorative. Si elle ne gêne jamais, elle est mal réglée.
65. **Les pouvoirs à plusieurs.** Le Lien, le Leurre et l'Infirmier n'ont de
    sens qu'en équipe. Rien de tout ça n'a jamais tourné à plus de deux.
66. **La ligne du pouvoir en haut à gauche** dit le nom, la recharge et le
    stock. Assez clair ? Trop discrète ?

---

## 9. L'équipement et son budget — **la grosse nouveauté, jamais jouée**

Treize objets, douze points, un seul assemblage à la fois. J'ai vérifié en jeu
que tout fonctionne : les statistiques se cumulent dans le bon ordre, l'arme
secondaire sort à la bonne distance, les charges descendent, les objets se
posent, et le clic de l'écran ajoute, retire et remplace. **Mais personne n'a
jamais choisi un assemblage contre quelqu'un.** C'est là que tout se joue.

**`L` ouvre l'écran d'équipement**, entre deux manches seulement. **`1` à `4`
utilisent les objets**, et les cases en bas à gauche sont cliquables, donc ça
marche aussi au doigt.

### Les trois questions qui décident si le budget est bon

67. **Est-ce que tout le monde joue le même assemblage ?** C'est l'échec le
    plus probable et le plus silencieux. Si au bout de dix parties vous portez
    tous la machette, l'armure légère et deux utilitaires à un point, le budget
    ne crée pas de choix, il a une bonne réponse. Le premier réglage serait de
    passer les utilitaires à un point à deux.
68. **Est-ce que l'arme à sept points vaut ses sept points ?** Le marteau coûte
    plus de la moitié du budget : il ne reste que cinq points pour tout le
    reste. S'il gagne quand même, il est trop fort ; si personne ne le prend,
    il est trop cher. Les deux se corrigent dans `Config.items`.
69. **Est-ce que l'arme secondaire se remarque ?** Elle sort toute seule quand
    la cible est trop loin pour l'arme principale, sans aucune touche. Est-ce
    que ça se sent comme une bonne surprise, ou est-ce qu'on ne comprend pas
    pourquoi on tape parfois mou ? **C'est le mécanisme dont je suis le moins
    sûr**, parce qu'il décide quelque chose à votre place.

### Le reste, objet par objet

70. **Le fusil à pompe** porte à **quatre studs**. Il faut être collé. Est-ce
    jouable, ou juste frustrant ?
71. **L'arc composite** ignore la moitié de la réduction d'armure. C'est le
    seul contre à l'armure lourde du catalogue : sans lui, cinq points
    d'armure n'ont aucune réponse. Est-ce que ça se voit ?
72. **L'armure lourde** retire 22 % de la vitesse. À douze points elle ne laisse
    place qu'à une arme à quatre ou cinq points, rien d'autre. Assemblage
    viable ou piège ?
73. **La trousse de soin** demande 1,6 s à l'abri, et **un seul coup reçu
    annule la pose**. La charge est rendue — j'ai choisi de ne pas la faire
    perdre, pour un premier test. Si se soigner devient trop facile, c'est le
    premier levier.
74. **Le stimulant** à un point soigne 25 instantanément, une seule fois. La
    vraie question du budget : un point instantané, ou deux pour 45 à l'abri ?
75. **La grenade** rebondit et explose après 1,6 s. Elle ne blesse **que les
    adversaires** — la fiche n'ouvre jamais le sujet des dégâts aux alliés, et
    je ne l'ai pas ouvert à sa place.
76. **Le bouclier déployable** bloque **les deux équipes**, comme le mur du
    Forgeron. Outil ou punition ?
77. **Les affinités de classe** font un point de moins sur deux ou trois
    objets. Elles sont annoncées sur la carte (« 3 pts au lieu de 4 »). Est-ce
    qu'on les remarque, et est-ce qu'elles donnent envie de jouer sa classe
    autrement ?
78. **L'assemblage par défaut** est machette + stimulant + armure légère + mine
    légère + pistolet-mitrailleur, à 11 points sur 12. Quelqu'un qui n'ouvre
    jamais l'écran doit pouvoir jouer. Est-ce que c'est le cas ?
79. **Six objets au maximum**, et un seul par catégorie sauf les utilitaires.
    C'est la seule catégorie où on peut empiler, donc c'est elle qui crée les
    styles de jeu. Trop permissive ?

---

## 10. Les pièces, les tirages et le classement — **aucun n'a d'effet sur le jeu**

À lire avant d'y toucher : **les treize objets sont disponibles pour tout le
monde**. La collection existe, les tirages fonctionnent, mais rien n'est encore
verrouillé derrière eux. C'est volontaire : à treize objets, bloquer
l'équipement derrière une loterie rendrait le test du budget impossible, et
c'est le budget qu'on teste maintenant.

**`P` ouvre l'écran de progression.**

80. **« Progression NON sauvegardée sur ce serveur »** s'affiche en rouge tant
    que « Enable Studio Access to API Services » est décoché dans Studio, et
    dans une place non publiée. **Vérifie que ce message disparaît** une fois
    publiée : s'il reste, les profils ne sont pas écrits, et il ne faut
    surtout pas laisser des joueurs remplir une collection qui s'efface.
81. **Les pièces d'une partie** : 280 en écrasant, 250 en gagnant serré, 180 en
    perdant serré, 170 en se faisant écraser. Une caisse coûte 1000.
82. **Ton récapitulatif disait « une caisse toutes les trois à six parties ».**
    Avec ces chiffres, c'est **quatre à six**. Écraser tout le monde rapporte
    280, il en faudrait 334 pour que trois parties suffisent. Deux façons de
    trancher : soit on monte `winBase` de 220 à 280 et `lossPerRoundWon` de 10
    à 30, soit on corrige le récapitulatif. **C'est toi qui décides, c'est ton
    économie.**
83. **Trois objets sont offerts à l'ouverture du compte** : une arme, une
    armure, un soin, tous à bas prix. Un débutant ne doit pas tirer l'arme à
    sept points et se retrouver avec un assemblage impossible à compléter.
84. **L'écran des cotes est affiché en permanence sous le bouton**, et il est
    déjà conforme aux exigences de Roblox sur les objets aléatoires payants —
    chaque résultat, son pourcentage, un total à exactement 100 %, un *mot* et
    pas une icône, et les cotes qui changent quand la garantie du septième
    tirage est active. **À ne pas simplifier** : ces règles coûtent la
    publication si elles sautent. Elles ne s'appliquent pas encore, puisque les
    pièces ne s'achètent pas ; l'écran est prêt pour le jour où.
85. **Le classement** démarre à 1000 et bouge beaucoup les dix premières
    parties, puis de moins en moins. Dans une équipe, **le plus faible gagne le
    plus** quand elle l'emporte. Est-ce que ça se ressent comme juste ?

---

## 11. L'arme se voit dans la main — **regardée, jamais jouée**

J'ai fini par les voir, une fois Studio ramené au premier plan : le rendu se
fige dès que la fenêtre passe derrière, et aucune capture ne le dit. Ce que
j'ai vu m'a fait corriger cinq armes sur six, et rien de tout ça n'apparaissait
dans les mille tests.

Ce qui était faux, et que seul l'oeil pouvait dire :

- **les lames étaient des fils de fer.** Une section carrée de 0,22 stud
  disparaît complètement à distance de combat. La machette et le couteau sont
  devenus des lames plates, et les deux ont reçu une poignée sombre — sans
  elle, une lame claire flotte à côté de la main au lieu d'être tenue par elle.
- **l'arc était un bâton.** Un barreau de section carrée ne se lit pas comme un
  arc : c'est maintenant une branche plate avec une corde claire.
- **le pistolet-mitrailleur était un moignon sombre.** Il a reçu un canon,
  comme le fusil.
- **le manche du marteau tenait du cure-dent** sous une tête de 0,9.

Ce qui marchait déjà : le marteau se lit parfaitement, le fusil à pompe aussi.

Reste donc à juger **en jouant**, ce que je ne peux pas faire :

86. **Est-ce qu'on voit l'arme ?** Chaque arme est un objet tenu dans la main
    droite, visible par tout le monde. C'est la raison d'être de tout ce
    morceau : avec treize objets, savoir que l'adversaire porte un fusil à
    pompe plutôt qu'un arc change ce qu'on fait de la seconde suivante.
87. **Est-ce que les tailles sont crédibles ?** La machette fait 3 studs, le
    marteau 3,4 avec une tête de 0,9, le couteau 1,5, l'arc 4,2 de haut. Un
    personnage Roblox fait environ 5 studs. Si quelque chose a l'air d'un
    mât ou d'un cure-dent, c'est une ligne de `Config.items` à changer, rien
    d'autre — `look.size`.
88. **Est-ce que l'arme est bien dans la main**, et pas plantée dans le bras ou
    flottant à côté ? Le réglage est `look.grip`, trois chiffres.
89. **Les quatre gestes.** Chacun dit ce que l'arme fait :
    - la **machette** et le **couteau** fauchent vers la gauche, en travers du
      corps, parce que la main est la droite ;
    - le **marteau** s'abat vers le bas ;
    - le **fusil à pompe** et le **pistolet-mitrailleur** lèvent le canon, comme
      un recul ;
    - l'**arc** recule dans la main, comme une corde qu'on tend.

    **Deux de ces quatre partaient à l'envers** au premier jet — le marteau se
    relevait, les armes à feu plongeaient du canon. Rien dans les mille tests
    ne le voyait. Ce qui l'a attrapé est un calcul de la position de la pointe
    avant et après le geste, fait avec de vrais `CFrame` dans Studio, et ce
    calcul est maintenant figé dans la suite de tests. Mais **un geste juste au
    calcul peut quand même être laid**, et ça, seul ton oeil le dira.
90. **Le geste part vite et revient lentement** (0,07 s puis 0,16 s). Est-ce que
    ça donne du poids au coup, ou est-ce que ça traîne ? C'est
    `Config.loadout.weaponMotion.outSeconds` et `backSeconds`.
91. **L'arme secondaire sort toute seule** quand la cible est trop loin pour la
    principale — et depuis cette session, **elle se voit changer dans la main**.
    Est-ce que ce changement se comprend, ou est-ce qu'il surprend ?
92. **L'arme survit à la mort.** Elle est reconstruite à chaque réapparition.
    Si tu meurs et que tu reviens les mains vides, c'est un vrai bug, dis-le.
93. **Le bras ne bouge pas.** Seule l'arme tourne dans la main. C'est assumé :
    une animation de bras demande un fichier téléversé sur un compte, donc
    quelque chose que personne ne peut relire dans le dépôt. Si ça te paraît
    trop pauvre une fois en jeu, c'est une décision à prendre ensemble — elle
    a un coût.

---

## 12. Le son — **vérifié par instrumentation, jamais écouté**

Il n'y avait aucun son. Il y en a maintenant, et il faut que tu saches
exactement ce que j'ai vérifié et ce que je n'ai pas pu vérifier, parce que
l'écart est important.

**Ce qui est vérifié, en jeu, dans Studio.** J'ai fait partir de vraies
annonces de coup depuis le serveur, une par famille d'arme, et j'ai regardé ce
que le client en faisait. Les quatorze pistes chargent, chaque famille déclenche
le bon son de départ et le bon son d'impact, un coup raté ne joue que le départ,
le volume et la hauteur sont ceux qui sont écrits dans la configuration, et rien
ne s'empile derrière. La chaîne fonctionne, de bout en bout.

**Ce que je n'ai pas pu faire : écouter.** Je choisis une piste sur son nom, sur
la bibliothèque d'où elle vient et sur sa **durée** — un « impact » d'une
seconde et demie est une portière de voiture, pas un coup de poing. C'est une
sélection raisonnée, ce n'est pas un jugement d'oreille. **Celui-là n'existe
pas tant que tu ne l'as pas fait.**

94. **Est-ce qu'un coup qui touche et un coup qui rate s'entendent
    différemment ?** C'est toute la raison d'être de ce travail. Quand on rate,
    on n'entend que le sifflement de l'arme ; quand on touche, le sifflement
    puis l'impact, 0,05 s après. Si tu n'entends pas la différence sans regarder
    l'écran, c'est raté et il faut me le dire.
95. **Est-ce que chaque arme sonne comme ce qu'elle est ?** Cinq familles :
    - la **machette** et le **couteau** sifflent (lame) ;
    - le **marteau** fait un bruit sourd et grave, et son impact est métallique ;
    - le **fusil à pompe** et le **pistolet-mitrailleur** tirent ;
    - l'**arc** fait une corde ;
    - les **poings** d'une classe sans arme font un bruit d'air, plus aigu et
      plus discret.

    Si une de ces cinq sonne faux, dis-moi **laquelle** et **ce qu'elle devrait
    faire** : c'est une ligne d'identifiant à changer dans
    `Config.sounds.events`, rien de plus.
96. **Est-ce que c'est trop fort, ou pas assez ?** Un seul chiffre commande
    tout : `Config.sounds.masterVolume`, à 0,5 aujourd'hui. Dis-moi « deux fois
    trop fort » et c'est réglé en une ligne.
97. **Est-ce qu'on entend les duels des autres ?** Un son porte à 110 studs et
    commence à faiblir à 12. L'arène fait environ 90 studs de rayon. Si en 5v5
    on n'entend plus son propre combat sous le bruit des autres, il faut baisser
    les 110 — c'est le réglage qui fait qu'un son **renseigne** au lieu de
    saturer.
98. **Est-ce que la rafale devient un bruit de machine ?** Chaque son tire sa
    piste et sa hauteur au sort, précisément pour éviter ça. Le
    pistolet-mitrailleur est le cas limite : il frappe vite.
99. **Est-ce qu'on entend une coupure sèche ?** Deux pistes sont trop longues
    pour leur usage et je les coupe volontairement — l'impact métallique à 0,9 s
    (elle dure 2 s) et la corde de l'arc à 0,7 s (2 s aussi). Sans la coupe, un
    coup de marteau sonne encore quand le suivant part. Mais une coupe nette
    peut faire un « clac » ; si tu l'entends, ça se règle avec un fondu, et je
    ne l'ai pas mis parce que je ne pouvais pas juger s'il était nécessaire.
100. **La chute et l'explosion.** Tomber en agonie a son propre son, et une
     grenade aussi — avant, une grenade qui ne touchait personne était
     silencieuse. Est-ce que l'explosion s'entend assez pour qu'on recule ?

**Les six sons qui manquaient sont faits**, et ils ont leur propre section
plus bas.

---

## 13. Le bac a sable — **la reponse a ta question**

Tu demandais si un bot ou un bac a sable etait simple. Le bac a sable l'etait,
et il est fait. Un vrai bot ne l'est pas, et la raison est plus bas.

**Ce que c'est.** Quand tu es **seul** en jeu — dans Studio ou en partie
privee — la boucle de partie ne t'attend plus : elle ouvre une salle
d'entrainement. Tu apparais, tu peux bouger, frapper, utiliser ton pouvoir et
tes objets. La touche **B** ouvre un panneau a trois colonnes : ta classe, le
mannequin, les actions.

101. **Choisir n'importe laquelle des quatorze classes**, d'un clic, sans bans
     ni tirage. Changer de classe remet l'arbre a zero — c'est la verite du
     jeu, un arbre appartient a une classe.
102. **T'offrir des points d'arbre**, un par clic. C'etait le seul moyen de
     regarder un palier 6 : en partie il faut une serie de sept manches.
     L'ecran de l'arbre (**T**) reste ouvert en permanence ici, meme en pleine
     action.
103. **Poser jusqu'a quatre mannequins**, et choisir **leur classe**. Un
     mannequin a les statistiques d'une vraie classe, pas un sac de points de
     vie invente : « combien de coups de machette pour un Colosse » est donc
     une vraie reponse, que tu peux compter. Le Colosse par defaut, parce qu'il
     encaisse le plus longtemps. Ils reviennent tout seuls quatre secondes
     apres leur mort.
104. **Allumer ou couper la zone**, te soigner a fond, reapparaitre.
105. **Equiper ce que tu veux** : l'ecran d'equipement (**L**) reste modifiable
     en pleine action, et le budget passe de douze a **soixante** points avec
     dix objets au lieu de six. C'est pour pouvoir porter le marteau et le
     fusil dans la meme minute et les comparer. Un bandeau le dit en haut de
     l'ecran, pour que tu ne prennes pas ca pour un equilibrage.

**Ce que le mannequin teste vraiment, et c'est important de le savoir :** la
portee, la recharge, le passage automatique a l'arme secondaire quand il est
trop loin, le chiffre des degats, le geste de l'arme, le son, et le vol de vie
du Vampire. **Ce qu'il ne teste pas** : tout ce qui demande un vrai
adversaire — la propagation de la Peste, la poussee, le partage du Lien, le
clone du Leurre qui s'interpose. Ces pouvoirs-la ne se jugent qu'a deux, et le
mannequin ne fait pas semblant de les declencher.

**Pourquoi pas un bot.** Ce n'est pas l'intelligence qui coince. Faire courir
un personnage vers toi et frapper a portee est faisable. Ce qui coince est
structurel : **tout le jeu est indexe par joueur.** Chaque service garde ses
tables rangees par `Player` — qui a quelle classe, quels points, quel
equipement, qui est a terre. Un bot n'est pas un `Player` et on ne peut pas en
fabriquer un. Il faudrait donc reecrire le combat, l'equipement, l'arbre, les
pouvoirs et l'agonie pour qu'ils parlent de « combattants », ce qui met en
risque tout l'equilibrage deja pose. Et meme construit, **il te dirait qu'une
mecanique fonctionne, jamais qu'un duel est tendu.** C'est cher, et ca
n'achete pas ce qui manque.

**Les trois garde-fous**, parce que ce panneau donne des pouvoirs qui n'ont
rien a faire en partie :

106. Il faut etre **seul**. C'est le garde-fou qui porte vraiment : aucun
     classement, aucune piece et aucune partie ne peut exister avec un seul
     joueur, donc rien de ce qui se gagne n'est atteignable depuis le bac a
     sable.
107. Il faut etre en **partie privee ou dans Studio**. C'est de la prudence et
     pas une necessite : un serveur public avec un seul joueur est une salle
     d'attente, et y mettre un stand de tir serait sans doute mieux pour le
     joueur que l'ecran « en attente ». **C'est une decision de conception, donc
     elle est a toi** — un reglage a passer a `false` et c'est fait.
108. **Un deuxieme joueur ferme tout** : les mannequins disparaissent, le
     budget redevient douze points, l'arbre repart a zero, et la vraie partie
     commence. A verifier en jouant : est-ce que ca se passe proprement quand
     quelqu'un te rejoint au milieu d'un essai ?

**Ce qui est verifie, en jeu, par instrumentation** : le bac a sable s'ouvre
tout seul quand on est seul ; le changement de classe, les points d'arbre, le
nombre et la classe des mannequins, la zone et le soin repondent ; un mannequin
Colosse a bien 170 points de vie et en perd quand on le frappe ; un assemblage
de 23 points et 8 objets, refuse par le jeu, est accepte ici ; le mannequin mort
revient tout seul au meme endroit ; et le panneau tient dans l'ecran.

**Ce qui n'est pas verifie** : si tout ca est agreable a utiliser. Le panneau
n'a jamais ete regarde par un oeil — le rendu de Studio ne me rend plus
d'image. Je l'ai mesure au lieu de le regarder : chaque plaque est a sa place et
rien ne deborde. Mais « mesure » et « lisible » sont deux choses, et c'est la
meme reserve qu'a la section 11.

---

## 14. Les panneaux et la barre du haut — **mesuré et regardé**

Tu m'as demandé de corriger le décalage des quatre autres panneaux. En les
remesurant, j'ai trouvé que **le décalage n'existait pas** : c'est ma mesure de
la veille qui était fausse, et c'est le bac à sable, que j'avais « corrigé »,
qui était devenu le seul vraiment décentré. Le détail est dans `DECISIONS.md`.

Trois choses ont quand même changé, et celles-là sont de vraies corrections :

110. **Ouvre les cinq panneaux** — l'arbre (**T**), l'équipement (**L**), les
     pièces (**P**), le bac à sable (**B**), et les bans au début d'une partie.
     Aucun titre, aucun pied de page, aucun bouton ne doit être coupé ni
     passer derrière les icônes de Roblox en haut de l'écran.
111. **Change la taille de la fenêtre pendant qu'un panneau est ouvert.** Il
     doit se remettre à l'échelle tout seul. Avant, trois panneaux sur cinq ne
     suivaient pas du tout, et un quatrième cessait de suivre après une
     réapparition.
112. **Regarde les deux lignes en haut à gauche** — l'arbre et le pouvoir de
     classe. Elles passaient derrière les icônes de Roblox sur une petite
     fenêtre ; elles sont maintenant sous la barre. En plein écran ça ne se
     voyait pas.

**Ce qui est vérifié** : les cinq panneaux sont centrés au pixel sur la partie
visible de la fenêtre, avec la même marge en haut et en bas, et aucun ne
dépasse. L'affichage de jeu, lui, a été **regardé sur une capture** avant et
après : la ligne de l'arbre était bien derrière les icônes, elle ne l'est plus.

**Ce qui n'est pas vérifié** : ta fenêtre à toi. J'ai mesuré dans une fenêtre
de Studio de 1016 sur 387, où la barre fait 58 pixels ; en plein écran elle en
fait moins, et la marge sera plus confortable, pas moins.

---

## 15. Les six sons qui manquaient — **vérifiés en jeu, jamais écoutés**

Il reste la même réserve qu'à la section 12, et elle ne bougera pas tant que tu
ne les auras pas entendus : **je choisis une piste sur son nom, sa provenance
et sa durée**, pas à l'oreille. Toutes viennent cette fois de la bibliothèque
officielle de Roblox (ProSoundEffects), qui annonce la durée exacte de chaque
piste au dixième de seconde — c'est le seul critère que je puisse vérifier
seul, et c'est celui qui attrape les pires erreurs.

| Ce qui sonne | Ce que c'est | Durée |
| --- | --- | --- |
| Le soin | un carillon doux, deux pistes | coupé à 1,2 s |
| Le relèvement | une montée courte | 1,4 s |
| La brûlure de zone | une brûlure brève, deux pistes | coupée à 0,8 s |
| Le clic d'interface | un interrupteur sec, deux pistes | 0,4 et 0,5 s |
| Le début d'une manche | un coup de cloche clair | coupé à 2 s |
| La fin d'une manche | une cloche grave | coupée à 2,5 s |
| L'ouverture d'une caisse | un carillon qui tournoie | 2,5 s |

**Trois choix que j'ai faits seul, et qui se discutent à l'oreille :**

120. **Le soin ne sonne que s'il est voulu.** Un stimulant, une trousse : oui.
     Le vol de vie du Vampire : non. Il passe par la même annonce, et il
     s'annonce à chaque coup porté — un carillon par coup, et le son du combat
     disparaîtrait dessous. Si tu trouves qu'un Vampire qui se soigne devrait
     s'entendre, c'est une ligne à changer.
121. **La brûlure de zone ne sonne que pour toi.** Le serveur annonce à tout le
     monde chaque joueur qui brûle ; à dix joueurs dehors, ça ferait dix
     brûlures par seconde dans la même oreille. Ce son est un avertissement
     — « bouge » — pas une ambiance.
122. **Gagner et perdre une manche sonnent pareil.** La bibliothèque de Roblox
     est une bibliothèque de bruitages, pas de musique : il n'y a pas de
     fanfare de victoire dedans. Une cloche grave marque la fin, et c'est le
     texte qui dit qui a gagné. Si tu veux une différence, il faudra une piste
     musicale, donc un choix à ton oreille.

**Ce qui est vérifié, en jeu, dans Studio** : les seize évènements chargent
(« toutes les pistes chargées » au démarrage du client) ; chacun des six sons
part pour de bon, avec le bon identifiant, le bon volume et la bonne hauteur ;
le clic a été déclenché par un **vrai clic sur un vrai bouton** du panneau ; et
les trois silences voulus sont silencieux — le vol de vie ne carillonne pas, la
brûlure d'un autre joueur ne s'entend pas, et le rafraîchissement de
l'affichage, qui part quatre fois par seconde, ne sonne pas.

123. **À écouter en priorité : le clic.** C'est le seul son qu'on entend des
     dizaines de fois par partie. Je l'ai mis au volume le plus bas du
     catalogue. S'il agace au bout de cinq minutes, c'est ce chiffre-là qu'il
     faut baisser, ou le son qu'il faut retirer.
124. **Puis la brûlure.** Elle revient toutes les secondes tant que tu es
     dehors. Est-ce qu'elle presse de rentrer, ou est-ce qu'elle agace ?
125. **Et le début de manche.** Il arrive sur le « Combat ! », au moment où
     tout le monde se dégele. Est-ce qu'il lance la manche, ou est-ce qu'il
     passe inaperçu ?

---

## 16. Le corps bouge aussi — **mesuré en jeu, jamais regardé**

Depuis le 26 octobre, l'arme tournait dans une main immobile. Le bras part
maintenant avec elle, **et le buste se penche dans le coup** : la main avance,
recule ou se lève selon le geste, le torse plie à la taille du même côté, et
les deux reviennent au repos aussitôt après.

**Les sept gestes ont été mesurés en partie**, en lançant chaque coup et en
relevant où la main arrive, dans le repère du torse. Les sept bougent, les
sept partent du bon côté, et les sept reviennent au repos :

| geste | la main part | de combien |
| --- | --- | --- |
| machette, couteau | vers l'avant et vers le corps | 1,10 – 1,14 stud |
| marteau | vers l'avant | 1,01 stud |
| fusil, pistolet-mitrailleur | vers l'**arrière** | 0,54 stud |
| arc | vers l'**arrière** | 0,67 stud |
| mains nues | vers l'avant | 1,17 stud |

**Et le buste, mesuré de la même façon**, en degrés de tangage dans le repère du
bassin. Les cinq reviennent à moins d'un degré de leur départ :

| geste | le buste | demandé → obtenu |
| --- | --- | --- |
| machette | se penche en avant | +8° → +9,0° |
| marteau | **le plus penché de tous** | +18° → +20,2° |
| fusil | part en **arrière** | −6° → −6,6° |
| arc | part en arrière, à peine | −4° → −4,3° |
| mains nues | se penche en avant | +12° → +13,8° |

Le penchement emmène la main avec lui, donc elle va un peu plus loin qu'avant :
1,21 stud pour la machette contre 1,11 sans le buste.

**Donc ce n'est pas à toi de vérifier que ça marche : c'est à toi de dire si
c'est beau.** Un chiffre ne dit pas si un geste a l'air d'un coup. C'est la
même réserve que pour les sons, qui partent au bon moment sans que je sache
s'ils sonnent juste.

**Une chose à regarder en particulier.** L'épaule relève la main de 0,38 stud
quand le bras s'étend, qu'on le demande ou non. Pour le marteau, j'avais
demandé que la main descende légèrement (− 0,10) et elle **monte** de 0,38 :
l'arme s'abat bien, mais la main qui la tient monte un peu. Est-ce que ça se
voit, et est-ce que ça gêne ?

126. **Frappe à mains nues, d'abord.** C'est le point le plus important de la
     section : avant aujourd'hui, un coup de poing ne faisait **rien bouger du
     tout**. Est-ce qu'on voit enfin qu'on frappe ?
127. **Puis le marteau.** C'est le geste le plus ample du jeu : l'arme s'abat,
     la main avance d'un stud et le buste pique de 20 degrés. Est-ce que
     l'ensemble a l'air d'un coup qui s'abat, ou d'un bonhomme qui se casse en
     deux ? 20 degrés est tout près de la butée du bassin, qui est à 22 — donc
     si c'est trop, il faut **baisser**, il n'y a pas de marge au-dessus.
128. **Puis le fusil.** La main recule de 0,54 stud et le buste part de 6 degrés
     en arrière. Est-ce que ça se lit comme un recul, ou est-ce trop petit pour
     se voir ?
129. **Puis la machette.** La main avance et rentre vers le corps. C'est le seul
     geste latéral du jeu, et c'est celui que l'épaule bride le plus.
130. **Frappe très vite, plusieurs fois de suite, avec le couteau.** Le geste
     dure 0,23 s et le couteau peut frapper plus vite que ça sur certaines
     classes. Est-ce que le bras tremble, ou est-ce qu'il enchaîne ? Si l'arme
     se repose en laissant le bras tendu, dis-le : c'est un bug de jeton.
131. **Regarde un adversaire frapper, de loin.** Le mouvement sert surtout à
     ça : savoir qu'un coup est parti sans voir la barre de vie descendre. Le
     buste est ce qui doit porter le plus loin, parce qu'il déplace une grande
     surface. Est-ce que ça se lit à dix studs ? À trente ?
132. **Cours, saute, tombe, et frappe pendant.** Le penchement s'ajoute à
     l'animation de Roblox au lieu de la remplacer, donc frapper en pleine
     course devrait marcher — mais c'est là que ça se verrait si les deux se
     contredisaient.
133. **Change d'avatar pour un corps très grand ou très petit**, et refrappe.
     La position de repos de la main se mesure sur chaque corps, donc ça devrait
     marcher partout — mais je n'ai mesuré que sur le tien.
134. **Si tu joues en R6** (un avatar à six parties, pas quinze), le bras ne
     bougera **pas** et le buste non plus, et c'est voulu : ce squelette n'a ni
     coude ni taille à plier. L'arme bouge quand même.
135. **Change d'arme plusieurs fois de suite, puis frappe.** Un bug trouvé en
     vérifiant ce geste : chaque changement d'arme laissait une articulation
     morte dans la main, quatre après cinq changements. C'est corrigé et
     revérifié en jeu — mais si une arme se met à pendre de travers après
     plusieurs changements, c'est là qu'il faut regarder.

**Un geste ample est impossible, et ce n'est pas un réglage.** Mesuré en jeu :
l'épaule laisse la main monter de 1,85 stud et avancer de 1,25, mais ne la
laisse rentrer vers le corps que de **0,36**. Un moulinet qui traverse la
poitrine ne se fera jamais avec ce moyen-là. Si le geste te paraît trop petit,
la réponse n'est pas un chiffre plus grand — c'est une animation téléversée, et
c'est une décision à prendre ensemble.

---

## 17. La Peste ignore les armures — **à deux, et seulement à deux**

Le palier 6 de la branche Peste était déclaré et affiché **indisponible** depuis
le début, parce qu'il attendait qu'il y ait des armures à ignorer. Elles sont
arrivées à l'étape 6. Il est codé.

**Ce que ça fait.** Un Vampire qui monte la branche Peste jusqu'au bout voit sa
propagation **ignorer entièrement** la réduction de dégâts de ceux qu'elle
arrose. Pas le coup lui-même — seulement ce qui se propage aux voisins. C'est
la réponse de la branche aux équipes qui empilent de l'armure, et ce n'est pas
un contre universel : frapper **un** adversaire armuré fait toujours aussi peu.

**Ce que j'ai pu vérifier seul**, en jeu : le serveur démarre, l'effet s'active
bien au sixième palier (il renvoyait « rien » avant aujourd'hui), et le calcul
donne les bons chiffres dans la machine virtuelle du jeu. **Ce que je n'ai pas
pu vérifier** : que ça arrose vraiment quelqu'un. La propagation demande un
deuxième joueur, et le mannequin du bac à sable ne déclenche volontairement
aucun pouvoir de ce genre.

136. **À trois, idéalement.** Un Vampire branche Peste, et deux adversaires
     côte à côte dont **un seul** porte l'armure lourde (5 points). Frappe
     celui qui n'en porte pas, et regarde les dégâts qui s'affichent sur
     l'armuré à côté.
137. **Refais-le sans le sixième palier** (cinq paliers, pas six). L'armuré doit
     prendre nettement moins. C'est la seule comparaison qui dit si le palier
     vaut ses deux points.
138. **Est-ce que ça se comprend ?** Rien à l'écran ne dit « l'armure est
     ignorée » : le joueur voit seulement un nombre plus gros. Si l'effet est
     invisible une fois en jeu, c'est un problème d'affichage à régler, pas un
     problème de calcul.
139. **Et est-ce que c'est trop fort ?** La Peste paie son pouvoir par « aucun
     vol de vie », ce qui est cher pour un Vampire. Mais contre une équipe
     groupée et armurée, elle ignore maintenant la défense de tout le monde à
     la fois.

---

## Ce qui reste à faire de mon côté

Pour que tu saches où on en est, et ce que ça ne sert à rien de me signaler :

- **je n'ai pas pu écouter les sons** — je les ai choisis au nom, à la
  bibliothèque et à la durée, et vérifié en jeu qu'ils partent bien. Savoir
  s'ils sonnent juste demande une oreille. Section 12.
- **les quarante-neuf autres objets** — treize sur soixante-deux sont codés.
  Les autres attendent de savoir si le budget est bon à treize.
- **les skins** — les fragments s'accumulent et ne servent encore à rien.
  Aucune boutique, aucun skin.
- **l'achat de pièces en Robux** — rien n'est branché, et c'est volontaire :
  tant que les pièces ne s'achètent pas, le tirage n'est pas un objet aléatoire
  payant. L'écran des cotes est déjà conforme pour le jour où.
- **les objets débloqués ne verrouillent pas l'équipement** — tout le monde a
  accès aux treize. À rebrancher quand le catalogue sera plus grand.
- **le geste du corps reste petit** — le bras bouge maintenant avec l'arme,
  sans une seule animation téléversée, mais l'épaule de Roblox a une butée
  mesurée : la main ne rentre vers le corps que de 0,36 stud. Un vrai moulinet
  demande une animation téléversée sur un compte, donc un identifiant d'asset
  que personne ne peut vérifier en lisant le dépôt. C'est à décider ensemble,
  et seulement si le geste actuel ne suffit pas. Section 16.
- **les jambes, la tête et le bras gauche ne bougent pas** — le bras droit et
  le buste répondent aux attaques, le reste joue les animations par défaut de
  Roblox. C'est voulu : les jambes doivent marcher, et la tête comme le bras
  gauche n'ont rien à faire pendant une attaque à une main.
- **le buste ne se tourne pas, il ne fait que se pencher** — la torsion et
  l'inclinaison latérale ont été essayées et abandonnées : l'animation
  d'attente de Roblox fait tourner le buste de son côté jusqu'à 22 degrés en
  permanence, donc un angle demandé sur ces axes arrive n'importe où. Le
  pourquoi est dans `docs/DECISIONS.md`.
- **le couteau reste à peine visible** — 1,6 stud de lame sur un personnage de
  5, c'est honnête pour un objet à 2 points dont la portée est réduite de 30 %,
  mais si ça gêne en jouant, c'est un choix à faire : l'agrandir mentirait sur
  sa portée. Section 11, point 87.
- **le rendu de Studio se fige quand la fenêtre passe en arrière-plan** — donc
  si tu veux que je regarde quelque chose à l'écran, il faut que Studio soit
  devant. Aucune erreur ne le signale, les captures reviennent simplement
  identiques.
- **un palier 6 sur quarante-deux** attend encore un système qui n'existe pas :
  « immunisé aux projectiles » (Monolithe). Les armes à feu et l'arc touchent
  instantanément à portée, donc **rien ne vole dans ce jeu** : lui donner un
  sens demande un système de projectiles, donc une décision à prendre ensemble.
  Il s'affiche comme indisponible, c'est voulu. Celui de la Peste, lui, est codé
  depuis le 27 octobre — section 17.
- **le pilotage du clone du Leurre** — le clone est posé, pas piloté. Le
  pourquoi est dans `docs/DECISIONS.md`, et le point à regarder est le 57.
