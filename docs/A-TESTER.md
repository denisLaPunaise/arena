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

## Ce qui reste à faire de mon côté

Pour que tu saches où on en est, et ce que ça ne sert à rien de me signaler :

- **l'équipement, les objets, le budget de douze points** — rien n'est codé
- **les tirages, les pièces, les fragments, les skins** — les chiffres sont
  dans `Config.luau`, le système n'existe pas
- **l'Elo et le classement** — les chiffres sont posés, rien ne tourne
- **le son** — il n'y en a aucun
- **les animations d'attaque** — le coup se voit (trait, éclair, nombre) mais le
  personnage ne bouge pas. C'est sans doute le manque que tu vas sentir le
  plus, maintenant que le reste existe.
- **deux paliers 6 sur quarante-deux** attendent un système qui n'existe pas :
  « immunisé aux projectiles » (Monolithe) et « la propagation traverse les
  armures » (Peste). Ils s'affichent comme indisponibles, c'est voulu.
- **le pilotage du clone du Leurre** — voir la section suivante.
