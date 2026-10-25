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
- [ ] **Reconnecte le plugin Rojo** (bouton Connect). J'ai dû redémarrer le
      serveur, et la place contient une copie de `TreePanel` que j'ai éditée à
      la main pour pouvoir vérifier l'affichage. **Le dépôt fait foi** : dès que
      Rojo est reconnecté, il remet la bonne version, qui est légèrement plus
      récente que celle de la place.
- [ ] **Vérifie qu'il n'y a pas de doublons** dans `ReplicatedStorage.Arena`,
      `ServerScriptService.Arena` et `StarterPlayerScripts.Arena`. J'en ai
      trouvé cinq cette fois, dont le RemoteEvent `Tree`. Deux modules du même
      nom, et le jeu devient muet sans la moindre erreur.

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

## Ce qui reste à faire de mon côté

Pour que tu saches où on en est, et ce que ça ne sert à rien de me signaler :

- **les douze autres classes** — seuls le Vampire et le Colosse existent
- **l'équipement, les objets, le budget de douze points** — rien n'est codé
- **les tirages, les pièces, les fragments, les skins** — les chiffres sont
  dans `Config.luau`, le système n'existe pas
- **les bans et le tirage au sort des classes** — le prototype distribue les
  deux classes en dur
- **l'Elo et le classement** — les chiffres sont posés, rien ne tourne
- **le son** — il n'y en a aucun
- **les animations d'attaque** — un coup est aujourd'hui invisible, à part les
  PV qui descendent et la poussée. C'est sans doute le premier manque que tu
  vas sentir, et c'est normal.
