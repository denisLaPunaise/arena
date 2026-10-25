# Journal des décisions

Josh m'a donné champ libre et m'a demandé de noter tout ce que je tranche seul,
pour qu'il puisse le relire plus tard. C'est ce fichier. Il est tenu à jour au
fil de la construction, décision par décision, avec à chaque fois **ce que j'ai
choisi, pourquoi, et ce qui se passe si on revient dessus.**

Rien ici n'est définitif. Chaque entrée peut être annulée — c'est écrit pour que
ça soit possible, pas pour que ça soit figé.

---

## 25 octobre 2026 — Les deux questions ouvertes de l'arbre

### Le 1v1 exclut trois classes

**Décidé :** le Lien, le Leurre et l'Infirmier ne sortent pas au tirage en 1v1.
Le duel se joue sur onze classes.

**Pourquoi :** leur pouvoir cible un coéquipier. En 1v1 il n'y en a pas, donc
leurs trois branches d'arbre sont vides. Et comme le 1v1 est miroir, les deux
joueurs auraient la même classe éteinte : un duel parfaitement équilibré et
parfaitement creux.

L'autre option était de leur donner un effet de repli en 1v1 — le Lien se lie à
lui-même, l'Infirmier se relève seul. Je l'ai écartée parce qu'elle viole le
cinquième principe du projet : deux exemplaires de la même chose sont
strictement identiques. Une classe qui change de pouvoir selon le format n'est
plus la même classe.

**Où c'est codé :** le drapeau `needsAllies` dans `src/shared/Classes.luau`, et
`Classes.drawable(playersPerTeam)`. Huit vérifications dans
`tests/specs/classes.luau` cassent si quelqu'un déplace ou oublie un drapeau.

**Pour revenir dessus :** retirer les trois `needsAllies = true`. Le 1v1
retrouve ses quatorze classes immédiatement.

### Garrot reste tel quel

**Décidé :** la branche Garrot de l'Infirmier continue de lui retirer
complètement le relèvement, en échange d'un soin sur les alliés debout.

**Pourquoi :** c'est exactement le modèle de Peste chez le Vampire, qui retire
tout le vol de vie. Le principe « une branche sacrifie quelque chose de réel »
ne souffre pas d'exception sans raison, et je n'en ai pas trouvé.

**Mais c'est le premier truc à regarder en jouant.** Si personne ne prend jamais
Garrot, la branche est morte et il faudra la remplacer — pas l'adoucir, la
remplacer, parce qu'une branche tiède est pire qu'une branche refusée. La
solution de repli que je proposerais : Garrot garde le relèvement mais le rend
beaucoup plus lent, et ajoute le soin de zone.

---

## 25 octobre 2026 — L'étape 3

### La zone se resserre géométriquement, pas linéairement

**Décidé :** chaque palier multiplie le rayon par une constante, au lieu de lui
retirer une largeur fixe.

**Pourquoi :** c'est un test qui l'a trouvé, pas moi. En linéaire, du rayon de
départ (150) au rayon final (16) en quatre paliers, on obtient 150 → 116 → 83 →
49 → 16 : le premier palier retire 22 % du rayon, le dernier en retire 68 %. Le
resserrement qui décide la manche était trois fois plus brutal que celui qui
l'ouvre, et personne ne l'aurait vu venir.

En géométrique on obtient 150 → 86 → 49 → 28 → 16 : chaque palier retire 43 %.
Tous les resserrements se ressentent pareil.

**Où c'est codé :** `Zone.radiusForStep` dans `src/shared/Zone.luau`. Le test
« aucun palier ne divise le rayon par deux » dans `tests/specs/zone.luau` casse
si on revient au linéaire — c'est lui qui a levé le lièvre.

### Le rayon de départ se déduit de la map

**Décidé :** la zone démarre à `0.5 × la plus petite dimension de MapBounds`, et
retombe sur 140 studs quand la map n'a pas de `MapBounds` exploitable.

**Pourquoi :** sinon il faudrait régler la zone map par map, et une nouvelle
arène construite dans Studio arriverait avec une zone fausse sans que personne
le remarque. Là, le contrat de nommage suffit : une map conforme a une zone
correcte.

### Les dégâts de zone ne touchent pas les joueurs à terre

**Décidé :** un joueur en agonie qui rampe hors de la zone ne prend pas de
dégâts de zone.

**Pourquoi :** il a déjà un compte à rebours. En ajouter un second ne change
rien à l'issue — la fenêtre dure dix secondes, il n'a pas le temps de guérir —
et rend l'affichage incompréhensible : deux chronomètres pour une seule mort.

### Un seul chemin pour les dégâts

**Décidé :** `CombatService.dealDamage` est le seul endroit du jeu où des PV
sont retirés. Les coups, la zone et le coup de grâce passent tous par là.

**Pourquoi :** un Humanoid meurt à zéro PV et ne revient pas. Si deux bouts de
code différents peuvent descendre les PV, il suffit d'en oublier un pour qu'un
joueur meure au lieu de tomber à terre — et ce bug n'apparaîtrait qu'au moment
précis où la mécanique compte.

### Un adversaire debout passe avant un adversaire à terre

**Décidé :** quand les deux sont à portée, le coup part sur celui qui est
debout.

**Pourquoi :** sans cette priorité, on achève quelqu'un pendant que son
coéquipier vous frappe dans le dos. Ce n'est jamais le coup qu'on voulait
porter.

### Le coup de grâce ne rapporte rien

**Décidé :** achever un joueur à terre n'inflige aucun dégât et ne déclenche
aucun vol de vie. Le Vampire ne se soigne pas en achevant.

**Pourquoi :** sinon achever devient la meilleure source de soin du jeu, et le
Vampire a intérêt à laisser ses adversaires à terre pour s'en servir de trousse
de secours.

### Deux réglages ajoutés à l'agonie

**Décidé :** `reviveRangeStuds = 8` (il faut être au contact pour relever) et
`reviveHealthRatio = 0.4` (on repart à 40 % de ses PV).

**Pourquoi :** la fiche ne les fixait pas et le relèvement ne marche pas sans.
Relever de loin annulerait le risque pris ; relever à PV plein rendrait le fait
de tomber gratuit, et la fenêtre d'agonie ne ferait qu'allonger les manches.

### Le relèvement ne se met pas en pause

**Décidé :** s'éloigner d'un blessé remet sa barre de relèvement à zéro, au lieu
de la geler.

**Pourquoi :** avec une barre qui se garde, deux joueurs peuvent relever en
alternance en esquivant entre deux passages, et le relèvement cesse d'être un
engagement. Il faut rester, et rester est dangereux.

### La fenêtre gagne contre la barre

**Décidé :** quand le compte à rebours expire à l'instant exact où la barre de
relèvement se remplit, c'est la fenêtre qui l'emporte : le joueur est éliminé.

**Pourquoi :** il faut une règle, et celle-ci est la seule qu'on peut expliquer
en une phrase. L'autre sens produirait des relèvements qui semblent venir de
nulle part.

### Deux interrupteurs pour comparer

**Décidé :** `Config.round.zoneEnabled` et `Config.downed.enabled` coupent
chacun leur mécanique, et le jeu revient exactement au comportement de
l'étape 2.

**Pourquoi :** la seule façon de savoir si une mécanique améliore le jeu est de
jouer une manche avec et une manche sans, dans la foulée. Sans interrupteur,
cette comparaison demande de modifier du code entre deux parties, donc personne
ne la fait.

---

## 25 octobre 2026 — L'étape 4

### Une victoire nette mène au palier 5, pas 4

**Constaté, pas décidé :** `Config.luau` affirmait qu'une victoire nette
s'arrêtait au palier 4 de l'arbre. C'est faux : une partie 4-0 donne quatre
points utilisables, et les paliers 2 à 5 coûtent un point chacun, donc on
atteint le palier 5. Le palier 6 en coûte deux de plus et demande une série de
sept manches.

Le commentaire est corrigé et un test le fige désormais. Le principe que le
commentaire voulait exprimer — une série serrée doit valoir la peine d'être
jouée jusqu'au bout — reste vrai, et il est même plus net qu'annoncé : seul un
7 manches ouvre le dernier palier.

### Un effet décrit mais pas codé se déclare indisponible

**Décidé :** chaque palier 6 porte un drapeau `implemented`. Quand il est faux,
`SkillTree.activeTier6Effect` renvoie `nil` et l'interface affiche l'option
comme indisponible, au lieu de la proposer et de ne rien faire.

**Pourquoi :** deux paliers 6 dépendent de systèmes qui n'existent pas encore —
« la propagation ignore les armures » (pas d'armures) et « immunité aux
projectiles » (pas de projectiles). Une option qui se vend deux points et ne
fait rien est pire qu'une option absente : le joueur croit avoir mal compris.

**Pour revenir dessus :** passer le drapeau à `true` quand le système arrive.

### Trois façons d'écrire un sacrifice

**Décidé :** `onUnlock` ajoute ou retire, `onUnlockScale` multiplie,
`onUnlockSet` impose une valeur.

**Pourquoi :** « aucun vol de vie » vaut zéro, pas moins mille. Mon premier jet
écrivait `knockbackStuds = -1000` pour annuler une poussée, ce qui marche par
accident et ment sur l'intention.

### Des planchers sur les statistiques

**Décidé :** aucune branche ne peut descendre un joueur sous 20 PV, 4 de
vitesse ou 1 de dégâts.

**Pourquoi :** ce sont des garde-fous, pas de l'équilibrage. Si une branche
touche un plancher, c'est que ses chiffres sont à revoir — mais entre-temps,
personne ne se retrouve immobile et invincible-par-erreur dans une partie.

---

## Ce qui reste à Josh de toute façon

Ces décisions-là ne sont pas les miennes et ne le seront jamais : savoir si
c'est amusant, tester à plusieurs, publier, créer les produits payants, valider
la conformité de l'écran de tirage, et la direction artistique. Le détail est
dans `CLAUDE.md`, section « Qui fait quoi ».
