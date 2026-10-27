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

## 25 octobre 2026 — Brancher l'arbre dans le jeu

### Trois branches sur six ne faisaient rien, et je ne l'avais pas vu

**Constaté, pas décidé.** En branchant l'arbre, je me suis aperçu que Peste,
Catapulte et Monolithe faisaient monter des chiffres (`spreadRadiusStuds`,
`thrownDamage`, `thrownRangeStuds`, `rangedDamageReduction`) que **le combat ne
lisait nulle part**. Leur sacrifice s'appliquait, lui. Les trois branches
rendaient donc le joueur plus faible en échange de rien, et tous les tests
passaient.

Ce qui a été fait :

- **Peste** : la propagation existe maintenant pour de bon. Un coup répercute
  `spreadRatio` de ses dégâts aux ennemis proches de la cible, au plus trois.
- **Bélier** : `knockbackDamage` est un vrai chiffre, ajouté aux dégâts — mais
  seulement si la poussée existe. « La poussée devient une charge qui blesse »
  est maintenant littéralement vrai.
- **Catapulte** : plutôt qu'inventer une commande de lancer, la branche
  **allonge sa portée d'attaque** et lui retire sa poussée. Il frappe de loin,
  ce qui est exactement la promesse, avec le bouton qui existe déjà.
- **Monolithe** : `rangedDamageReduction` devient `damageTakenRatio`, une
  réduction de **tous** les dégâts reçus, zone comprise.

**Pour revenir dessus :** quand les projectiles existeront, Monolithe pourra
redevenir une réduction à distance seulement. En attendant, une branche qui ne
réduit que des dégâts qui n'existent pas est une branche morte.

**Le garde-fou qui empêche que ça se reproduise :** un test vérifie désormais
que **toute clé touchée par une branche existe dans les statistiques de base de
la classe**. Une branche qui pousse un chiffre inventé fait échouer la suite.

### On ne dépense jamais pendant une manche

**Décidé :** la phase de dépense s'ouvre entre deux manches, avant l'apparition
des personnages, et dure quinze secondes — sautée si personne n'a rien à
décider, coupée dès que tout le monde a appuyé sur « Prêt ».

**Pourquoi :** poser les statistiques sur le personnage remet les PV au maximum.
Acheter un palier qui touche les PV maximum au milieu d'un échange serait donc
un soin complet gratuit. Et au-delà du bug, un arbre qui se modifie en combat
transforme une décision de stratégie en réflexe d'urgence.

**Interrupteur :** `Config.skillTree.spendingDuringRound`, à `false`. Le refus
est vérifié côté serveur, pas en cachant un bouton.

### Les quatre effets de palier 6 qui sont codés

- **Sangsue** — le vol de vie fonctionne sur les dégâts de zone subis par les
  ennemis, à la moitié du ratio (`Config.tier6.leechFromZone`). Modulé exprès :
  à taux plein, le Vampire gagne la fin de manche en regardant l'autre brûler.
- **Fauve** — le bond. Il n'a **pas de touche à lui** : attaquer un adversaire
  hors de portée, c'est lui sauter dessus. Un coup dans le vide devient une
  approche, ce qui évite d'ajouter une commande à apprendre.
- **Bélier** — la charge touche jusqu'à trois ennemis, chacun prenant 30 % de
  moins que le précédent. Sans cette dégressivité, un seul coup dans un groupe
  déciderait la manche.
- **Catapulte** — le coup laisse un bloc au sol six secondes. C'est une vraie
  couverture : elle gêne aussi celui qui l'a lancée.

Les deux autres (Peste, Monolithe) restent `implemented = false` : il n'y a
toujours ni armures ni projectiles.

### Les blocs temporaires vivent dans leur propre dossier

**Décidé :** les blocs de la Catapulte vont dans `Workspace.ArenaTemp`, vidé
entre deux manches.

**Pourquoi :** `Workspace` appartient à la construction des maps. Du code qui y
pose des objets en vrac finit par y laisser des traces, et personne ne saura
plus ce qui fait partie de la map. Une couverture héritée de la manche
précédente serait aussi un avantage que personne n'a payé.

### L'interface est posée en pixels, pas empilée

**Décidé :** le panneau de l'arbre a une taille de dessin fixe (1180 × hauteur
variable) et une `UIScale` qui le fait tenir dans la fenêtre.

**Pourquoi :** les deux premières versions se sont cassées en jeu. Avec un
empilement automatique, le bouton « Prêt » se dessinait par-dessus les chiffres ;
avec `UIFlexItem` pour rattraper, les cartes ont pris une hauteur nulle et ont
purement disparu. Les deux fois, les tests passaient et la capture d'écran a
tranché.

Conséquence pratique : **une fenêtre courte réduit tout, elle ne rogne rien.**
Les lignes qui servent à décider — le sacrifice, et la promesse du palier 6 —
sont celles qui disparaissaient en premier.

### Un doublon de synchronisation Rojo, trouvé par hasard

**Constaté.** Chaque module ajouté depuis la dernière synchronisation complète
existait **en double** dans la place, `Remotes.Tree` compris. Un
`WaitForChild("Tree")` côté client et côté serveur pouvait donc désigner deux
RemoteEvent différents — l'arbre aurait simplement été muet, sans erreur.

C'est noté dans `CLAUDE.md`. Le réflexe à garder : après avoir ajouté des
fichiers, **vérifier la liste des enfants dans la place** avant de conclure que
quelque chose ne marche pas.

### Pourquoi Rojo avait cessé de synchroniser

**Constaté.** Le serveur Rojo tournait, Studio était connecté en TCP, et
pourtant plus rien n'arrivait dans la place — sans une seule erreur nulle part.
Preuve : une fonction écrite dix minutes plus tôt (`changesHeight`) était
absente de la copie de `TreePanel` dans Studio.

**La cause.** Le plugin Rojo demande une **confirmation avant d'appliquer un
patch**, et son réglage par défaut (« Initial ») la demande **une fois par
projet et par session de Studio**. J'avais redémarré le serveur, donc une
nouvelle confirmation attendait un clic que je ne pouvais pas donner. Tant
qu'elle attend, la synchronisation est silencieusement à l'arrêt.

**Décision.** Recommander à Josh de passer ce réglage sur « Never ». Le risque
que ça couvre — Rojo écrase du travail fait dans Studio — ne nous concerne pas :
par construction, le code ne s'écrit jamais dans Studio ici, et `Workspace`
n'est pas dans le projet Rojo. La confirmation ne protège donc rien et coûte
une panne muette.

### L'outil de capture d'écran ne voit pas les `BillboardGui`

**Constaté.** Les nombres de dégâts n'apparaissaient sur aucune capture, alors
qu'une interrogation du client en direct les montrait bien présents, affichés,
à l'écran, avec la transparence qui montait de 0 à 1.

**La preuve.** Une part rouge opaque et un panneau vert opaque, créés au même
instant, côte à côte, tous deux confirmés à l'écran par
`WorldToViewportPoint`. Sur la capture : la part est là, le panneau n'y est
pas.

**Conséquence, et c'est elle qui compte.** J'ai failli partir corriger du code
qui n'avait rien. La règle que j'en tire, notée dans `CLAUDE.md` : quand un
affichage « ne marche pas », vérifier d'abord que **mon moyen de regarder** sait
le montrer. Et dire la différence à Josh : *vérifié par instrumentation* n'est
pas *vu de mes yeux*, et `docs/A-TESTER.md` le dit maintenant pour les nombres
de dégâts et pour le compte à rebours de l'agonie.

### Les chiffres des douze classes, et de leurs trente-six branches

**Ce que j'ai inventé.** Tout. Statistiques de base, portées, recharges, durées,
rayons, sacrifices de branche, crans par palier, effets de palier 6. La fiche
donne un pouvoir, une faiblesse et un rôle par classe, en une phrase chacun ;
elle ne donne aucun nombre pour les douze qui n'étaient pas prototypées.

**Comment je m'y suis pris.** J'ai pris le Vampire (100 PV, 20 de vitesse, 12 de
dégâts) et le Colosse (170, 12, 24) comme les deux bornes, et j'ai placé les
douze autres entre les deux selon leur rôle. Une classe d'information frappe
faible, une classe de terrain est lente et solide, une classe d'embuscade a le
coup le plus fort et la cadence la plus basse.

**Ce que ça vaut.** Rien, tant que personne n'a joué. Ce sont des points de
départ cohérents entre eux, pas un équilibrage. La seule chose que je peux
garantir, c'est qu'aucune classe n'arrive sans faiblesse appliquée dans le code,
et qu'aucune branche ne pousse un chiffre que le combat ne lit pas.

### Les chiffres d'un pouvoir sont des statistiques, pas une table à part

**Le choix.** `mineCount`, `phaseSeconds`, `markHealStealRatio` et les vingt-huit
autres vivent dans `Config.classStats`, avec la classe, et pas dans un coin
réservé aux pouvoirs.

**Pourquoi.** Trois conséquences, toutes voulues : une branche d'arbre peut les
pousser comme elle pousse les dégâts (c'est ce qui rend « Arsenal » possible :
cinq mines de plus au palier 5) ; l'interface de l'arbre sait déjà les afficher,
avec leur libellé en français et la bonne couleur ; et le vérificateur de types
attrape une faute de frappe, parce qu'ils sont déclarés dans `Combat.Stats`.

**Le prix.** Chaque fonction qui lit un de ces chiffres doit accepter qu'il soit
absent — le Traqueur n'a pas de mines. D'où les `or 0` dans `Abilities.luau`.
Ce n'est pas de la négligence, c'est la contrepartie assumée.

### Une seule touche pour tous les pouvoirs

**La décision.** `E`, pour les quatorze classes.

**Pourquoi.** La classe est **tirée au sort**. Une touche par classe serait à
réapprendre à chaque partie, et on la chercherait au moment où on en a besoin.
Le réglage est `Config.abilities.inputKey`.

### Le Leurre ne pilote pas son clone — **et c'est une réduction**

**C'est la seule chose de cette session qui s'écarte de la fiche**, et elle doit
être relue par Josh.

La fiche dit : « Pilote un clone qui attire l'attention », faiblesse « Reste
immobile et vulnérable pendant qu'il le pilote ».

**Ce qui est codé** : le clone est *posé* devant lui, il vit six secondes, il
s'interpose physiquement (un coup dirigé vers le Leurre part sur le clone quand
le clone est plus proche de l'attaquant), et pendant ce temps le Leurre **ne
bouge plus et encaisse 35 % de plus**. La faiblesse est donc intégralement
appliquée. C'est le **pilotage** qui manque.

**Pourquoi je ne l'ai pas fait.** Piloter un clone demande de déplacer la caméra
du joueur, de prendre ses entrées de déplacement, de les appliquer à un modèle
qui n'est pas son personnage, et de tout rendre au bon moment ou en cas de
déconnexion. C'est un chantier à part entière, du même ordre que tout le reste
des pouvoirs réunis, et il aurait mangé la session sans que les onze autres
classes existent.

**Ce que ça change pour le jeu.** Le Leurre devient une classe de placement
plutôt qu'une classe de diversion active. C'est jouable et honnête, mais ce
n'est pas ce que la fiche décrit. **À trancher avec Josh** : soit on code le
pilotage, soit on corrige la fiche.

### « Les mines épargnent ses alliés » ne voulait rien dire

Le palier 6 de la Démolition promettait que les mines épargneraient les alliés.
Mais une mine ne blesse **que** les adversaires : l'effet n'aurait rien changé,
tout en coûtant deux points. C'est précisément la panne des branches creuses,
repérée cette fois avant d'être écrite.

**Remplacé par** : les mines s'arment instantanément. Ça change vraiment le jeu
de la branche — la mine cesse d'être un piège qu'on prépare pour devenir une
arme qu'on pose sous les pieds de quelqu'un.

### Le Lien choisit l'allié le plus proche, et ne peut pas mourir à sa place

**Le ciblage.** Pas de visée : l'allié le plus proche dans la portée. Une
interface de ciblage n'existe pas, et le Lien se joue au placement de toute
façon.

**Le plafond.** La part reprise à l'allié ne dépasse jamais 35 % des PV maximum
du Lien (`bondMaxShareFraction`). Sans ce plafond, lier quelqu'un qui encaisse
un coup énorme tuerait le Lien d'un coup, et le pouvoir deviendrait un piège
qu'on n'utilise jamais deux fois.

### Le relancement tire avant de rendre l'ancienne classe

Dans l'autre ordre, le tirage pouvait rendre la classe qu'on venait de
relancer. Un relancement qui ne change rien est pire que pas de relancement du
tout : le joueur a dépensé sa seule chance pour rien. Un test le fige.

### La fenêtre de ban s'écoule en entier

Même quand toute l'équipe a voté. L'équipe d'en face doit avoir le temps de lire
ce qui vient d'être écarté — c'est ce qui fait du ban une information plutôt
qu'une formalité. **À rejuger en jouant** : si ça traîne, c'est
`Config.draft.banVoteSeconds`.

### Deux garde-fous qui arrêtent le serveur au démarrage

Le serveur refuse de démarrer si `Config` annonce un pouvoir de classe ou un
effet de palier 6 que rien n'exécute, et le message nomme le coupable.

**C'est volontairement brutal.** Une classe creuse ou un palier 6 muet ne se
voient qu'en jouant, et le palier 6 demande une série de sept manches — autant
dire jamais pendant un test. Un serveur qui ne démarre pas se remarque tout de
suite ; une classe qui ne fait rien, non.

### Des groupes de collision, pour deux pouvoirs

Le Spectre traverse les couverts, et le mur du Forgeron de palier 6 laisse
passer son équipe. Les deux demandent des règles de collision, déclarées une
fois pour toutes au démarrage dans `AbilityService`.

Le sol reste dans le groupe par défaut, qu'on ne touche pas : un Spectre qui
traverse les murs doit continuer à marcher dessus. Les couverts sont désignés
par le contrat de nommage (`Cover`), parce que les maps ne sont pas dans Git et
que rien d'autre ne peut les reconnaître.

### Les classes retrouvent leurs accents

`Classes.luau` écrivait « Degats faibles en melee ». Ces chaînes ne sont pas des
commentaires : elles s'affichent aux joueurs, sur l'écran de bans et à la
révélation. La convention du projet leur donne raison, et c'était une faute.

### Un objet déforme la classe, il ne la remplace pas

**Le choix.** Les chiffres d'un objet sont des **facteurs** et des **décalages**
appliqués aux statistiques de la classe, comme une branche d'arbre. Le marteau
multiplie les dégâts par 2,4 et la recharge par 1,9 ; il ne dit pas « 29 dégâts
toutes les 1,14 seconde ».

**Pourquoi.** Avec des chiffres absolus, toutes les classes portant la même arme
frappent pareil, et l'identité de classe disparaît dès qu'on ouvre l'équipement.
Un Vampire au marteau garde son vol de vie, ses cent points de vie et sa
fragilité ; il frappe simplement plus fort et plus lentement.

**Le prix.** Une arme forte est plus forte sur une classe qui frappe fort. Le
Colosse au marteau fait 58 de dégâts par coup. C'est un effet multiplicatif
assumé, et c'est exactement ce que les tests d'équilibrage devront surveiller
en premier.

### L'arme secondaire n'a pas de touche

**Le choix.** Elle sort automatiquement quand la cible est hors de portée de
l'arme principale, et uniquement dans ce cas.

**Pourquoi.** C'est littéralement ce que la fiche lui demande : « combler un
trou de l'arme principale ». Une touche de changement d'arme coûterait une
touche de plus sur un jeu qui en a déjà quatre, serait illisible sur téléphone,
et obligerait à changer d'arme au moment précis où on n'a pas le temps.

**Ce que ça change.** Le jeu décide quelque chose à la place du joueur, ce qui
est toujours un risque. **À rejuger en jouant** : si on ne comprend pas pourquoi
on tape parfois mou, c'est ce mécanisme qu'il faut rendre visible, pas enlever.

### Treize objets, pas douze

Avec un seul soin, la question « est-ce que je paie un point ou deux pour me
soigner » ne se pose pas. Le stimulant à un point et la trousse à deux sont la
question du budget en miniature, et le catalogue n'en vaudrait rien sans elle.

### Une arme en remplace une autre au lieu d'être refusée

L'écran verrouillait les trois armes qu'on ne porte pas et affichait « une au
maximum » à la place de ce qu'elles font. Il fallait rendre son arme pour lire
le catalogue. Maintenant, cliquer une arme repose celle qu'on porte — la règle
n'a pas changé, c'est la façon de l'appliquer qui a changé.

### L'assemblage par défaut prend de la largeur avant de prendre cher

**La première version** prenait le plus cher de chaque catégorie qui rentrait.
Résultat : l'armure lourde pour les quatorze classes, et la première chose que
le jeu apprenait à un débutant était qu'on ne court pas.

**Maintenant** : le moins cher de chaque catégorie utile d'abord — une arme, un
soin, une armure, un utilitaire — puis le reste du budget sur le plus cher qui
tient. Ça donne machette + stimulant + armure légère + mine légère +
pistolet-mitrailleur, à onze points sur douze, qui est un bon assemblage de
départ **et** qui fait découvrir l'arme secondaire. Deux tests gèlent les deux
propriétés.

### La grenade ne blesse que les adversaires

La fiche n'ouvre jamais le sujet des dégâts aux alliés. L'ouvrir ici en cachette
serait une décision de conception prise dans un coin de code, donc la grenade se
comporte comme les mines de l'Artificier. Le bouclier déployable, lui, bloque
les deux équipes — mais une couverture qui ne gêne que l'adversaire ne serait
pas une couverture.

### Une pose de soin interrompue rend sa charge

Perdre une trousse de soin sur une balle perdue serait la punition la plus amère
du jeu, et la recharge d'utilisation empêche déjà d'en abuser. **C'est le levier
d'équilibrage de la catégorie** : si se soigner devient trop facile, on garde
l'annulation et on retire le remboursement. Une ligne dans `LoadoutService`.

### Les objets ne sont pas encore verrouillés derrière les tirages

La collection existe, les tirages fonctionnent, les trois objets d'ouverture
sont donnés — mais **les treize objets restent disponibles pour tout le monde**.

À treize objets, bloquer l'équipement derrière une loterie rendrait le test du
budget impossible : la moitié des assemblages intéressants seraient hors
d'atteinte. C'est le budget qu'on teste maintenant, pas la collection. Le
verrou se rebranche quand le catalogue sera assez grand pour que la collection
veuille dire quelque chose.

### Les cotes sont conformes avant que les Robux n'existent

Les pièces ne s'achètent pas encore, donc le tirage n'est pas un objet aléatoire
payant et la politique de Roblox ne s'applique pas. L'écran la respecte quand
même intégralement : chaque résultat possible et son pourcentage, un total à
exactement 100 % vérifié à chacun des quatorze états de la collection, un *mot*
(« Détails des chances ») et pas une icône, aucun résultat qui ne rende rien, et
les cotes qui se mettent à jour quand la garantie du septième tirage est active.

**Pourquoi maintenant.** Ces règles sont structurelles : elles décident de la
forme de l'écran et de la forme du tirage. Les ajouter après coup voudrait dire
refaire les deux, au moment où la vente de pièces est prête et où on voudra
publier vite. Les sources sont dans `docs/EQUILIBRAGE.md`.

### L'économie ne tombe pas sur la fourchette annoncée

**À trancher par Josh.** Le récapitulatif de la fiche promet « une caisse toutes
les trois à six parties ». Avec les coefficients de `Config.economy`, c'est
**quatre à six** : écraser tout le monde rapporte 280 pièces, et il en faudrait
334 pour que trois parties suffisent.

Je n'ai pas touché aux chiffres : l'économie est une décision de conception, pas
un détail d'implémentation. Les deux sorties possibles sont dans
`docs/A-TESTER.md`, point 82.

### Si la lecture d'un profil échoue, on n'écrit pas

Un profil qu'on n'a pas su lire n'est pas un profil vide — c'est un profil
inconnu, et l'écraser par des valeurs neuves efface une collection entière. Le
joueur joue quand même, sa session n'est simplement pas gardée, et l'écran le
lui dit **en rouge**.

C'est la règle la plus importante de `ProgressService`, et elle prime sur tout
le reste du fichier.

### Une partie sans adversaire ne touche pas au classement

Vu en jeu : un joueur seul perdait soixante-quatre points de classement. La
moyenne d'une liste vide vaut zéro, donc l'adversaire était noté zéro, donc la
défaite coûtait le coefficient K entier. Un test le gèle.

C'est le genre de panne qui n'arrive qu'en vrai, sur un serveur presque vide, un
soir — c'est-à-dire exactement quand on ne regarde pas.

### Le plafond de coût des objets d'ouverture valait trois, pour une arme à quatre

Les trois tirages offerts à l'ouverture du compte ne pouvaient piocher que parmi
les objets à trois points ou moins. L'arme principale la moins chère en coûte
quatre : **la catégorie n'avait aucun candidat**, et le débutant démarrait sans
arme. Le plafond est passé à quatre, et un test vérifie désormais que chaque
catégorie d'ouverture a au moins un candidat.

Ce piège-là ne se voit qu'au premier compte créé, c'est-à-dire jamais pendant
les tests.

---

## 26 octobre 2026 — L'arme visible et son geste

Tu m'avais dit de continuer tout ce qui était possible. Voilà ce que j'ai
tranché seul sur ce morceau.

### Rendre l'arme visible, plutôt que d'attaquer le son

C'était le choix de départ : la liste disait « le son, puis les animations ».
J'ai pris les armes d'abord, pour une raison que je crois solide. Un son
demande un fichier audio téléversé sur un compte Roblox — donc un identifiant
d'asset que je ne peux ni créer ni vérifier, et que tu devrais contrôler à
l'oreille de toute façon. L'arme visible, elle, se décrit entièrement en six
chiffres dans `Config.items`, se relit dans le dépôt, et répond à un problème
de jeu réel : **avec treize objets, on ne voyait pas ce que portait
l'adversaire.** Un budget de douze points qu'on ne voit pas sur l'autre n'est
pas une mécanique, c'est une feuille de calcul.

Si tu préfères que je prenne le son d'abord malgré ça, dis-le — il faudra
juste que tu me donnes des identifiants d'assets audio, ou que tu valides
ceux de la bibliothèque Roblox.

### Aucune animation téléversée, rien que de la géométrie

Le geste est un `Motor6D` entre la main et l'arme, dont on anime le `C0`. Pas
une seule `Animation` Roblox. Conséquence assumée : **seule l'arme bouge, pas
le bras.** C'est plus pauvre qu'une vraie animation, et c'est le prix d'un
système entièrement relisible dans le dépôt, où une arme neuve se décrit en
six chiffres sans sortir de l'éditeur. Point 93 d'`A-TESTER`.

### Quatre mouvements, pas un par arme

`slash`, `overhead`, `recoil`, `draw`. Une arme choisit le sien. J'aurais pu
donner à chacune son mouvement propre ; quatre familles suffisent à dire ce
que l'arme fait, et elles resteront lisibles à soixante-deux objets, ce qu'une
liste de soixante-deux mouvements ne serait pas.

### Le marteau et le fusil ont deux morceaux, les autres un seul

Un bloc de 0,9 × 0,9 × 3,4 n'est pas un marteau, c'est une poutre. Le marteau
a donc un manche fin et une tête, et le fusil un corps et un canon. Les quatre
autres armes se lisent avec une seule pièce. C'est un réglage facultatif
(`look.head`) et pas une règle : si une autre arme en a besoin, c'est trois
lignes.

### Le coût de l'arme ne change pas

Rien de visuel ne touche à l'équilibrage. `look` ne contient que des tailles,
des couleurs et des angles ; aucun chiffre de `look` n'entre dans un calcul de
dégâts, de portée ou de budget. C'est le premier des six principes : la
puissance est portée par le coût en points, et rien d'autre.

### Ce que j'ai dû corriger, et comment

**Deux des quatre gestes partaient à l'envers** : le marteau se relevait au
lieu de s'abattre, les armes à feu plongeaient du canon au lieu de le lever.
Les mille tests du dépôt passaient tous. Ce qui l'a attrapé, c'est un calcul
de la position de la pointe de l'arme avant et après le geste, fait avec de
vrais `CFrame` dans Studio — et ce calcul est maintenant un test, qui vérifie
d'abord qu'il reproduit bien Roblox avant de juger des signes.

**Et une chose que je dois te dire franchement : je n'ai pas vu ces armes.**
La capture d'écran de Studio ne me rend plus la vue 3D. Je l'ai vérifié plutôt
que de le supposer : une part néon rouge de douze studs, posée à dix studs
devant la caméra et confirmée à l'écran par `WorldToViewportPoint`, n'apparaît
pas sur l'image. Les `ViewportFrame` non plus, alors qu'ils sont de
l'interface. Donc la géométrie est juste au calcul, et l'allure n'a jamais été
jugée par un oeil — c'est la section 11 d'`A-TESTER`, et c'est ce que tu dois
regarder en premier.

---

## 26 octobre 2026 — Le son

Tu m'as dit d'attaquer le son et de te dire ce dont j'ai besoin de toi. Voilà
ce que j'ai tranché seul en attendant ta réponse, pour que le travail ne reste
pas bloqué.

### Des pistes de la bibliothèque Roblox, pas des fichiers à toi

J'ai pris quatorze sons dans la bibliothèque Roblox, tous gratuits et tous
chargés avec succès dans Studio. C'est **réversible et sans coût** : chaque son
est une ligne d'identifiant dans `Config.sounds.events`, donc remplacer une
piste par une des tiennes, c'est changer un nombre. Si tu préfères téléverser
tes propres fichiers, rien n'est à défaire.

Je l'ai fait dans cet ordre parce que l'alternative était d'attendre. Mais il
faut dire la chose comme elle est : **je ne peux pas écouter.** Je choisis une
piste sur son nom, sur la bibliothèque d'où elle vient, et sur sa durée — c'est
d'ailleurs la durée qui a éliminé le plus de candidats, un « impact » d'une
seconde et demie étant une portière de voiture et pas un coup de poing. C'est
une sélection raisonnée, ce n'est pas un jugement d'oreille.

### Cinq familles sonores, pas un son par objet

`blade`, `blunt`, `gun`, `bow`, `fist`. Chaque arme déclare la sienne dans son
bloc `look`. C'est la même logique que les quatre gestes : à soixante-deux
objets, une liste de soixante-deux sons serait illisible, et cinq familles
disent déjà ce qu'il faut savoir — est-ce que ça coupe, ça écrase, ça tire ou ça
décoche.

La masse est la seule à avoir un impact **métallique** plutôt que charnel. Pas
par réalisme : parce qu'il faut pouvoir reconnaître à l'oreille qu'on vient de
se faire toucher par le gros dégât, et c'est le seul moyen gratuit de le dire.

### Aucun message réseau de plus

Le client recevait déjà chaque coup, chaque chute et chaque explosion avec sa
position, par le remote des effets. Le son se greffe sur ces mêmes annonces.
La seule chose ajoutée au protocole est `voice`, le nom de la famille de l'arme
— une chaîne de cinq lettres. **C'est aussi ce qui garantit que l'image et le
son partent ensemble** : ils lisent le même message.

### Le son du coup se décide sur l'annonce du coup, pas sur celle du dégât

Il y avait deux endroits possibles. L'annonce du dégât sait combien on a pris,
mais pas avec quoi ; l'annonce du coup sait avec quoi, et **elle part aussi
quand le coup rate**. C'est décisif : un coup dans le vide doit s'entendre,
c'est ce qui apprend la portée de sa classe. Donc les deux sons — le départ et
l'impact — partent de l'annonce du coup, l'impact décalé de 0,05 s. Superposés,
ils ne font qu'une bouillie.

### L'explosion a enfin son propre message

Une grenade envoyait jusqu'ici un « coup à zéro dégât ». Ça suffisait pour
l'image et ça ne suffit pas pour le son : une grenade qui ne touche personne
doit quand même s'entendre. C'est un nouveau genre d'annonce, `blast`.

### Je coupe deux pistes, et c'est le seul réglage qui vient d'une mesure

L'impact métallique dure 2 s et la corde de l'arc aussi, alors que la recharge
du marteau est d'environ une seconde. Sans coupe, chaque coup sonne encore
quand le suivant part, et trois coups de marteau font un bourdon continu. Je
les coupe à 0,9 s et 0,7 s. **Mais une coupe nette peut faire un « clac »**, et
ça, je ne peux pas l'entendre : point 99 d'`A-TESTER`. Si tu l'entends, le
remède est un fondu, et je ne l'ai pas mis d'avance parce que ça aurait été
ajouter du code contre un problème supposé.

### Six sons laissés vides exprès

Le soin, le relèvement, la brûlure de la zone, les clics de l'interface, le
début et la fin d'une manche, l'ouverture d'une caisse. J'ai cherché, et ce que
la bibliothèque m'a rendu pour ces cas-là ne valait pas d'être branché à
l'aveugle. Autant les choisir quand quelqu'un pourra les écouter.

### Ce que j'ai dû corriger, et comment

**Un son modéré ou retiré échoue en silence.** Aucune erreur, le son ne sort
simplement pas, et le jeu devient muet sans que personne sache pourquoi. Le
garde-fou est `Audio.verify`, qui recharge tout le catalogue au démarrage du
client et nomme ce qui manque dans la console. Tu verras maintenant une ligne
« Son : 9 évènements, toutes les pistes chargées » quand tout va bien.

**Et le nettoyage était faux, ce que seule la sonde en jeu a montré.** Je
calculais la durée de vie de chaque son sur sa durée réelle — sauf que
`TimeLength` vaut 0 à l'instant où le son est posé, même pour une piste déjà
préchargée, parce qu'elle arrive de façon asynchrone. Mon calcul retombait donc
toujours sur son repli de trois secondes, et les sons s'empilaient : à la
deuxième annonce il y en avait quatre dans le monde au lieu de deux. Corrigé en
écoutant la fin réelle du son. **Ça ne s'entendait probablement pas et ça ne se
voyait pas du tout** — c'est le genre de chose qui n'apparaît que si on va
regarder.

---

## 26 octobre 2026 — Le bac à sable, et pourquoi pas un bot

Tu m'as demandé si un bot ou un bac à sable était simple à faire. Voilà ce que
j'ai tranché, et pourquoi.

### Le bac à sable, pas le bot

Le bac à sable était simple parce que tout existait déjà : les services savent
poser une classe, recalculer un arbre, valider un équipement et allumer une
zone. Il ne fait que les appeler dans le bon ordre — celui de MatchService,
classe puis arbre puis équipement — quand il n'y a qu'un joueur.

Le bot ne l'était pas, et pas pour la raison qu'on imagine. Ce n'est pas
l'intelligence : faire courir un personnage vers toi et frapper à portée est
faisable. C'est que **tout le jeu est indexé par `Player`**. Chaque service
garde ses tables rangées par joueur, et un bot n'est pas un joueur — on ne peut
pas en fabriquer un. Il faudrait rendre génériques les rosters du combat, de
l'équipement, de l'arbre, des pouvoirs et de l'agonie d'un seul coup, ce qui met
en risque tout l'équilibrage déjà posé.

Et il ne vaudrait pas ce prix : **un bot dit qu'une mécanique fonctionne, il ne
dit jamais qu'un duel est tendu.** Le mannequin est une cible, pas un
adversaire, et il ne fait pas semblant d'être autre chose — il ne déclenche
aucun pouvoir qui demande un vrai adversaire, plutôt que de faire croire qu'ils
marchent.

### Trois portes nommées, et pas une de plus

Le bac à sable demande des choses interdites en partie. Plutôt que de les
disperser, chaque service en expose **une seule porte nommée**, que seul
SandboxService ouvre et qu'il referme en sortant : `LoadoutService.setSandbox`
pour le budget, `SkillTreeService.grantSandboxPoint` pour les points,
`CombatService.setPractice` pour le mannequin. Une porte se relit et se ferme ;
des conditions semées dans quatre fichiers, non.

Le crochet du mannequin est consulté à **un seul endroit** du chemin d'attaque :
quand aucun adversaire joueur n'est à portée. En partie il vaut `nil`, et le
combat est exactement celui d'avant.

### Le mannequin a les statistiques d'une vraie classe

Pas un sac de points de vie inventé. Il traverse `Combat.resolveHit`, la même
fonction que le combat réel, avec les statistiques du Colosse par défaut. C'est
ce qui rend le chiffre utile : « combien de coups de machette pour un Colosse »
devient une vraie réponse, comptable, et pas une approximation. Et tu peux
changer sa classe pour mesurer ton arme contre une armure différente.

### Le budget passe à soixante points

C'est l'inverse d'un équilibrage, et c'est assumé : avec douze points on ne peut
pas porter le marteau et le fusil, donc on ne peut pas les comparer dans la même
minute. Un bandeau le dit en haut de l'écran d'équipement, parce qu'un écran qui
annonce soixante points sans expliquer pourquoi se lit comme un bug.

L'écran reste aussi **modifiable en pleine action**, ce qui est interdit en
partie pour une bonne raison : changer d'armure en pleine fusillade viderait le
budget de son sens. Ici c'est exactement ce qu'on veut.

### Le bac à sable ne s'ouvre qu'en partie privée — et c'est à toi de trancher

Trois garde-fous : coupable depuis Config, seul uniquement, et privé uniquement.
Le deuxième est celui qui porte : rien de ce qui se gagne — pièces, classement —
ne peut exister avec un seul joueur.

Le troisième est de la prudence et pas une nécessité. Un serveur public avec un
seul joueur est une salle d'attente, et y mettre un stand de tir serait
probablement mieux pour le joueur que l'écran « en attente d'un deuxième
joueur ». Mais ça change l'expérience publique, donc c'est une décision de
conception : `Config.sandbox.privateOnly` à `false` et c'est fait. **Je ne l'ai
pas fait seul.**

### Ce que j'ai dû corriger, et comment

Quatre choses, et aucune des quatre ne se voyait en relisant le code.

**Un `Humanoid` mort ne se soigne pas.** Dès que ses points de vie touchent
zéro, Roblox le fait entrer dans l'état Dead, et lui rendre ses PV ne le relève
pas : il reste mort, à plein de vie. Le mannequin se **reconstruit** donc, au
même endroit — vérifié en jeu, écart de 0,00 stud.

**Et il ne revenait pas s'il mourait autrement qu'au corps-à-corps.** Je notais
l'échéance de son retour dans le chemin du coup, donc une mort venue d'ailleurs
ne la posait jamais. Corrigé en **constatant** son état à chaque tour de boucle
plutôt qu'en l'annonçant au moment du coup : deux lignes de moins, et plus de cas
oublié.

**L'écran de l'arbre restait ouvert par-dessus tout**, avec le texte absurde
« Phase de dépense — 3600 s avant la manche ». En partie, cet écran s'impose
exprès : la manche suivante part avec ou sans le choix, et le rater serait une
manche jouée avec une classe nue. Mais dans le bac à sable la dépense est
ouverte en permanence, donc un écran plein qui ne se ferme jamais cache tout le
reste. « On peut dépenser » et « l'écran s'impose » sont maintenant deux choses
séparées. **Trouvé en regardant une capture d'écran**, pas autrement.

**La colonne des actions débordait du panneau de 42 pixels.** La largeur était
écrite en dur et devait s'accorder avec quatre autres chiffres ; elle ne
s'accordait plus. Elle se **déduit** désormais de son contenu, donc elle ne peut
plus mentir. Et j'ai cru que le panneau sortait de l'écran par le haut, comme
les quatre autres : **c'était une erreur de mesure de ma part**, défaite le
27 octobre et racontée plus bas. Le « rattrapage » de 58 pixels que j'avais
appliqué ici décentrait en réalité le panneau vers le bas.

---

## 27 octobre 2026 — Le centrage des panneaux, et une erreur de mesure

Tu m'as demandé de corriger le décalage des quatre autres panneaux. **Il n'y
avait pas de décalage.** Avant de recopier la correction quatre fois, je l'ai
remesurée, et c'est ma mesure de la veille qui était fausse.

`AbsolutePosition` et `AbsoluteSize` ne se lisent pas dans le même repère.
Quand un `ScreenGui` ignore la barre du haut, il couvre bien toute la fenêtre,
mais l'origine des `AbsolutePosition` reste **sous** cette barre : le bord
supérieur s'y lit − 58. J'avais comparé le centre du panneau, lu dans ce
repère-là, à la moitié de `AbsoluteSize`, qui est dans l'autre. D'où un écart
de 58 pixels qui n'existait que dans ma soustraction. La sonde qui tranche ne
compare plus que des `AbsolutePosition` entre eux : le centre du panneau contre
le milieu de ses propres bords, deux témoins posés dans le même `ScreenGui`.
Écart mesuré : 0.0, sur les cinq panneaux.

Donc la vraie correction a porté sur le bac à sable, que mon « rattrapage » de
la veille avait descendu de 58 pixels pour de bon.

**Ce qui était vrai quand même**, et que j'ai corrigé pendant que j'y étais :

- **La barre du haut se dessine par-dessus les panneaux.** Un grand panneau
  mesuré contre la hauteur entière de la fenêtre passe son en-tête derrière
  elle. On retire désormais la barre de la place disponible, et on descend le
  panneau d'une demi-barre pour le centrer sur ce qui reste visible.
- **Trois panneaux ne suivaient pas la fenêtre du tout.** L'équipement, les
  pièces et les bans branchaient leur écoute de redimensionnement dans
  `start()`, à un moment où leur `ScreenGui` n'existe pas encore : la connexion
  était sautée en silence. Le panneau de l'arbre, lui, l'avait branchée sur la
  caméra, qui est remplacée à chaque réapparition. Les cinq écoutent maintenant
  leur propre `ScreenGui`, et la connexion se prend là où il est construit.
- **L'affichage de jeu passait derrière les icônes de Roblox.** Les lignes de
  l'arbre et du pouvoir se placent en pourcentage de la hauteur, et la barre
  mange les quinze premiers pour cent d'une petite fenêtre. L'affichage
  respecte maintenant la barre ; les panneaux continuent à l'ignorer, pour que
  leur voile sombre couvre tout l'écran. **Vu sur une capture**, pas autrement.

La règle de placement vit maintenant dans un seul fichier, `src/client/Screens.luau`,
que les cinq panneaux appellent — même raison que les planchers de
statistiques : une règle recopiée cinq fois est une règle qui se trompe cinq
fois.

**Ce que ça te coûte à vérifier : rien de plus que d'ouvrir les panneaux.** Si
un titre ou un pied de page est coupé chez toi, c'est que ma mesure ne vaut pas
pour ta fenêtre, et je veux le savoir.

---

## Ce qui reste à Josh de toute façon

Ces décisions-là ne sont pas les miennes et ne le seront jamais : savoir si
c'est amusant, tester à plusieurs, publier, créer les produits payants, valider
la conformité de l'écran de tirage, et la direction artistique. Le détail est
dans `CLAUDE.md`, section « Qui fait quoi ».
