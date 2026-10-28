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

## 27 octobre 2026 — Les six sons qui manquaient

Il manquait le soin, le relèvement, la brûlure de zone, le clic d'interface, le
début et la fin d'une manche, et l'ouverture d'une caisse. Les sept
évènements sont faits, sur dix pistes, toutes tirées de la bibliothèque
officielle de Roblox. **Je ne les ai pas écoutés**, et c'est la même réserve
que pour les quatorze premiers.

**Comment je les ai choisis, puisque je ne les entends pas.** La bibliothèque
de Roblox annonce pour chaque piste sa **durée exacte au dixième de seconde**,
sa catégorie et son auteur. C'est ce qui permet d'éliminer sans oreille les
pires erreurs : un « clic » de deux secondes est une porte de voiture, une
« brûlure » de quarante secondes est une cheminée. J'ai donc pris la durée
comme critère principal, et je me suis tenu à un seul fournisseur, celui que
Roblox publie lui-même.

**Trois décisions de fond, qui ne sont pas des choix de piste :**

- **Le soin ne sonne que s'il est voulu.** Le vol de vie du Vampire et le
  siphon du Parasite passent par la même annonce qu'une trousse de soin, et ils
  s'annoncent à chaque coup porté. Un carillon par coup, et le son du combat
  disparaît dessous. Le client ne peut pas faire la différence entre les deux
  — seul l'appelant la connaît. C'est donc le serveur qui nomme le son, et il
  ne le nomme que pour les objets de soin.
- **La brûlure de zone ne sonne que pour celui qui brûle.** Le serveur annonce
  à tout le monde chaque joueur qui brûle : à dix joueurs dehors, dix brûlures
  par seconde dans la même oreille. Ce son est un avertissement, pas une
  ambiance.
- **Gagner et perdre une manche sonnent pareil.** La bibliothèque de Roblox est
  une bibliothèque de bruitages et ne contient aucune fanfare. Plutôt que deux
  choix médiocres, une cloche grave marque la fin et le texte dit qui a gagné.
  Une vraie différence demande une piste musicale, donc l'oreille de Josh.

**Le coût en réseau est toujours nul.** Le son continue de se greffer sur des
annonces qui partaient déjà. Deux champs facultatifs ont été ajoutés au
protocole, et ils portent chacun une leçon :

- `sound`, sur l'annonce de soin, pour la raison ci-dessus ;
- `cue`, sur l'annonce d'affichage, pour le début et la fin d'une manche. Cette
  annonce-là part **quatre fois par seconde** pour tenir l'écran à jour : un
  son attaché à l'annonce elle-même sonnerait quatre fois par seconde. Seuls
  les trois appels qui marquent un moment le remplissent.

**Un test de plus, et c'est celui qui compte.** `Audio.play("zoneburn")` au
lieu de « zoneBurn » ne lève rien du tout : le jeu devient muet à cet
endroit-là pour toujours. Les tests relisent donc le code du client et du
serveur, et vérifient que chaque nom de son écrit en toutes lettres existe dans
le catalogue.

## 27 octobre 2026 — Le bras qui bouge, et l'épaule qui dit non

L'arme bougeait toute seule depuis le 26 octobre : elle tournait dans une main
immobile. Le bras bouge maintenant avec elle.

**Ce n'est pas un `Motor6D`, et c'est la découverte de la journée.** Le premier
jet visait l'épaule comme pour l'arme : on anime le `C0` de l'articulation et
le membre suit. Ça ne marche pas, et la raison ne se devine pas — elle se lit
en jeu. Sur l'avatar de test, le corps n'a **aucun `Motor6D`** : l'épaule est
un `AnimationConstraint` doublé d'un `BallSocketConstraint`, et l'animateur de
Roblox le réécrit à chaque image. Un `C0` posé là est effacé avant d'être
affiché.

Le moyen qui marche sur les deux squelettes est `IKControl` : on pose une
attache sur le torse, on dit à la main d'aller la chercher, et on fait monter
puis redescendre le **poids** du contrôle. À poids zéro, l'animation d'origine
est intacte — donc aucun saut au départ ni au retour, et rien à défaire si le
geste est interrompu en plein milieu.

**L'arme dit comment, le bras dit où.** Deux tables séparées dans `Config`, et
c'est voulu : le `C0` de l'arme la fait tourner dans la main (`weaponMotion`),
l'IK ne fait que porter la main ailleurs (`bodyMotion`), sans toucher à son
orientation. Mélanger les deux ferait tourner l'arme deux fois, une fois par
l'arme et une fois par le poignet. Les deux partent en même temps et reviennent
en même temps, sur **un seul jeton** : deux jetons séparés, et un coup rapide
reposerait l'arme en laissant le bras tendu.

**L'épaule a une butée, et aucun chiffre ne la fera céder.** Mesuré en jeu :
une demande de 2 studs déplace la main de 1,85 vers le haut, de 1,25 vers
l'avant, mais de **0,36 seulement vers l'intérieur du corps**. Le grand
moulinet qui traverse la poitrine est donc impossible, et ce n'est pas un
réglage à trouver. La machette avance surtout au lieu de faucher, et c'est la
limite du squelette, pas un choix. Un test refuse toute pose qui demande plus
de 2 studs : au-delà, le chiffre écrit dans `Config` cesse de décrire ce qui se
passe à l'écran, et on réglerait un geste à l'aveugle.

**Le coup de poing est le geste qui comptait le plus.** C'est le seul qui n'a
pas d'arme à animer, donc le seul qui était **entièrement invisible** : une
classe sans arme équipée frappait sans que rien ne bouge. Il a sa pose, `fist`,
et c'est la seule de `bodyMotion` qui n'ait pas d'équivalent dans
`weaponMotion`.

**Les avatars R6 n'ont pas de bras à plier.** Un seul `Right Arm` pour tout le
membre : il n'y a aucune articulation intermédiaire à fléchir, donc le bras est
laissé tranquille et seule l'arme bouge, exactement comme avant. Mieux vaut ça
qu'un bras cassé.

**La position de la main au repos se mesure, elle ne s'écrit pas.** Elle dépend
de la taille de l'avatar, que le joueur choisit : un chiffre écrit dans
`Config` serait juste pour un seul corps. Elle est relevée une demi-seconde
après l'apparition du personnage — le temps que les membres finissent d'arriver
et que l'animation de repos le prenne en main.

**Vérifié en jeu, et les deux premières sondes avaient tort.** Les sept gestes
bougent la main, du bon côté, et reviennent au repos — mesuré en partie, coup
par coup. Mais mes deux premières sondes ont rapporté l'inverse : « aucun
`IKControl` » et « la main ne bouge pas d'un pouce ». Elles avaient capturé
`player.Character` une fois pour toutes, et le bac à sable en fait apparaître
un nouveau : elles regardaient un personnage détruit, qui ne bougera plus
jamais. **Une sonde qui dit « rien ne se passe » est suspecte avant que le code
ne le soit** — ici, un seul relevé direct sur le personnage courant a suffi à
retourner la conclusion.

**Un bug trouvé en chemin, qui n'a rien à voir avec le bras.** En regardant la
main, j'y ai trouvé **quatre** `ArenaGrip` empilés après cinq changements
d'arme. L'articulation vit sur la main, pas dans le modèle de l'arme : détruire
le modèle en laissait donc un orphelin derrière lui, un par changement, pour
toujours. Tous inertes, tous répondant au même nom — donc un
`FindFirstChild("ArenaGrip")` en désignait un au hasard, exactement le piège des
doublons de Rojo. C'est corrigé et revérifié en jeu : une articulation par arme,
zéro à mains nues. **Ce bug était là depuis le 26 octobre et aucun test ne
pouvait le voir** ; il a fallu aller regarder dans la main.

## 27 octobre 2026 — Le palier 6 de la Peste, qui attendait les armures

Sur les quarante-deux paliers 6 du jeu, deux étaient déclarés mais pas codés,
parce qu'ils dépendaient d'un système qui n'existait pas. **L'un des deux
n'attend plus** : « la propagation ignore les armures » attendait qu'il y ait
des armures, et elles sont arrivées à l'étape 6 avec l'équipement. Il est codé.

**Un, et pas un demi.** L'arc composite ignore la **moitié** de la réduction de
sa cible, et c'est déjà le seul contre aux armures lourdes du catalogue. La
Peste au palier 6 l'ignore **entièrement** : le libellé du palier dit
« ignore » et pas « traverse une partie », et un palier 6 qui coûte deux points
et demande sept manches doit valoir davantage qu'une arme à six points.

**Ça ne touche que la propagation.** Le coup qui la déclenche reste réduit
normalement. Sinon la branche deviendrait un contre universel aux armures, au
lieu d'un contre aux **groupes** armurés — ce qui est le sujet de la Peste.

**Le calcul de perforation est sorti du serveur.** Il vivait dans
`CombatService`, en trois lignes au milieu d'une fonction, et rien ne le
testait. Maintenant que **deux** effets s'en servent, il est en logique pure
dans `Combat.piercedRatio`, avec ses deux garde-fous testés :

- **on ne perce que ce qui EST une réduction.** Une cible déjà plus fragile que
  la normale a un ratio positif : la percer la rendrait *moins* fragile, donc
  frapper une cible vulnérable ferait moins mal qu'un coup normal. C'est
  l'inverse de ce que le mot veut dire.
- **une perforation ne dépasse pas 100 %.** Percer 150 % d'une armure
  transformerait la réduction en augmentation.

**Les perforations ne s'additionnent pas, on garde la plus forte.** Une Peste
armée de l'arc composite percerait sinon 150 % d'une armure, par le chemin
qu'on vient de fermer.

**Un test se mordait la queue, et il fallait le voir.** La suite vérifiait
qu'un effet non codé ne s'active pas, et elle prenait la Peste comme exemple,
nommée en dur. Coder la Peste faisait donc **échouer le test sur son propre
exemple**, pas sur un bug. Il demande maintenant à `Config` quels effets
attendent encore, et il dit explicitement « plus aucun » le jour où il n'y en
aura plus — sans cette ligne, la boucle cesserait de vérifier quoi que ce soit
en silence.

**Ce que je n'ai pas pu vérifier.** Que la propagation arrose vraiment un
deuxième joueur armuré : ça demande deux joueurs, et le mannequin du bac à sable
ne déclenche volontairement aucun pouvoir qui demande un vrai adversaire. J'ai
vérifié en jeu ce qui se vérifie seul : le serveur démarre, l'effet s'active au
sixième palier, et le calcul donne les bons chiffres dans la machine virtuelle
du jeu.

**Le second attend toujours**, et pour une bonne raison : « immunisé aux
projectiles » (Monolithe) demande qu'il y ait des projectiles. Les armes à feu
et l'arc touchent instantanément à portée ; rien ne vole dans ce jeu. Lui
donner un sens demande un système de projectiles, donc une décision de
conception, donc toi.

## 27 octobre 2026 — Le buste qui se penche dans le coup

Le bras bougeait depuis ce matin, le reste du corps non. **Le buste se penche
maintenant avec le geste** : vers l'avant quand le coup part devant, vers
l'arrière quand l'arme repousse.

**Le même moyen que pour le bras, mais pas le même réglage.** `Waist` est un
`AnimationConstraint`, comme l'épaule : rien ne s'y écrit. C'est donc un second
`IKControl`, mais en **`Rotation`** et pas en `Position` — on veut que le buste
**plie à la taille**, pas qu'il quitte son bassin. La chaîne ne contient que
l'articulation du bassin, donc les jambes ne bougent pas.

**Les deux contrôles se composent, et c'est mesuré.** Avec le buste penché de
20 degrés, la main reste à 1,08 de son 1,01 habituel *dans le repère du torse*.
La cible de la main étant posée **sur** le torse, elle part en même temps que
lui et le bras n'a rien à corriger. Mieux : la main va un peu plus loin qu'avant
en valeur absolue, parce que le buste l'emmène — 1,21 stud pour la machette
contre 1,11 sans le penchement.

**La butée du bassin est à 22 degrés.** Mesurée : demander 20 donne 21,3,
demander 45 donne 21,4, demander 90 donne 22,4. Le marteau est réglé à 18 et
pas à 22, pour qu'il reste de la place sous la butée — un geste calé contre sa
butée ne se distingue plus d'un geste trop grand.

**Rien que le tangage, et c'est une décision prise sur une mesure.** J'ai essayé
le lacet et le roulis — la torsion et l'inclinaison latérale. Ils ne marchent
pas, et pas par manque de réglage : **l'animation d'attente de Roblox fait
tourner le buste de son côté, jusqu'à 22 degrés, en permanence.** Un angle
demandé sur ces deux axes arrive quelque part entre ce qu'on veut et ce que
l'animation voulait, et le résultat change à chaque coup. Le tangage, lui,
revient exactement à zéro : les cinq gestes mesurés reviennent à moins d'un
degré de leur départ.

**Conséquence dans le code, et c'est la seule différence avec le bras :
l'orientation de repos du buste se relit au départ de chaque geste.** Pour la
main, la position de repos est relevée une fois par personnage, parce qu'elle
dépend de la taille du corps. Pour le buste, une orientation relevée une fois
serait périmée à l'instant suivant, et le torse sauterait au départ du geste.

**Un test attrape la contradiction que l'œil seul verrait.** Un buste qui part
en arrière pendant que la main avance n'est pas un geste, c'est une convulsion.
Rien dans le code ne lie les deux chiffres — ils sont voisins dans `Config` et
c'est tout — donc une faute de signe sur l'un ne se verrait qu'à l'écran. La
suite vérifie désormais que les deux sont d'accord sur « avant », pour les cinq
gestes.

**Ce qui ne bouge toujours pas** : les jambes, la tête et le bras gauche. Les
jambes jouent la marche de Roblox et c'est ce qu'on veut ; la tête et le bras
gauche n'ont rien à faire pendant une attaque à une main.

## 27 octobre 2026 — La tête, les jambes refusées, et un signe faux pendant un jour

Tu m'as demandé les jambes et la tête. **La tête est faite. Les jambes, non, et
c'est une mesure qui l'a décidé.** Et en mesurant, j'ai trouvé que le
penchement du buste que je t'avais livré le matin même partait à l'envers.

### Le signe du buste était faux, et mon test ne pouvait pas le voir

J'avais mesuré des **angles d'Euler** et conclu « +18 degrés, donc penche en
avant ». C'est faux : dans Roblox, un tangage positif **lève** l'avant d'une
part. Vérifié par un témoin — `CFrame.Angles(+18, 0, 0)` donne à l'avant du
buste un Y de **+0,30** et à son sommet un Z de **+0,29** : une poitrine qui
regarde le ciel, un buste qui part **en arrière**. Les cinq gestes penchaient
donc à l'envers, la main devant et le torse derrière.

**Et j'avais écrit un test exactement pour ça, qui a laissé passer.** Il
comparait `pose.forward > 0` à `pose.lean > 0` : deux de **mes** conventions,
mises face à face. Elles étaient d'accord entre elles et toutes les deux
fausses. Un test de direction qui compare deux noms ne teste rien.

Trois choses ont changé pour que ça ne se reproduise pas :

- **les angles sont nommés par leur effet**, jamais par leur axe : `lean`
  positif fait tomber la poitrine vers l'avant, `headDip` positif fait regarder
  vers le bas, `headTurn` positif tourne vers la gauche du personnage ;
- **la conversion vers les axes de Roblox se fait à un seul endroit**, dans
  `WeaponService`, avec le signe moins et la mesure citée à côté ;
- **le test refait le calcul de Roblox et regarde où pointe la part**, après
  avoir vérifié qu'il reproduit bien les chiffres du témoin. C'est la même
  structure que le test de la pointe de l'arme, qui avait déjà attrapé deux
  signes inversés le 26 octobre — j'aurais dû l'employer tout de suite.

### La tête prend ses deux axes, et c'est mesuré

Le `Neck` est un `AnimationConstraint` comme l'épaule et la taille, donc même
moyen : un `IKControl` en `Rotation` sur la chaîne `UpperTorso` → `Head`.

Mais contrairement au buste, **la tête prend le tangage ET le lacet**, et pour
une raison chiffrée : l'animation d'attente ne la bouge que de **0,7 degré** de
tangage et **0,1** de lacet sur trois secondes, contre **22 degrés** pour le
buste. Il y a donc de la place pour piloter. Ses butées sont à 37 degrés de
tangage et 48 de lacet, et les valeurs s'arrêtent bien en dessous.

La machette est le seul geste qui **tourne** la tête, parce que c'est le seul
geste latéral du jeu : la tête suit la lame vers la gauche. Un test vérifie que
c'est le seul, pour qu'un deuxième soit une décision et pas un oubli.

### Les jambes : refusées, et voici le chiffre

Un `IKControl` sur la chaîne `RightUpperLeg` → `RightFoot` marche très bien
**debout** : un pied demandé un stud en avant arrive à 0,72, et revient à 0,01.

**En marchant, il gagne contre l'animation de marche, et c'est ça le
problème.** Le pied, qui balance normalement de **1,68 stud** pendant un cycle
de marche, tombe à **0,10** quand l'IK le tient. Le personnage glisserait sur
une jambe figée.

Ce n'est pas le même échec que la torsion du buste, où l'animation gagnait et
rendait le résultat imprévisible. Ici l'IK gagne — et il casse la marche, qui
est à l'écran **en permanence**, pour décorer une attaque qui dure 230 ms.
C'est un mauvais échange.

Il y avait une porte de sortie — ne piloter les jambes que lorsque le
personnage est immobile. Je ne l'ai pas prise : une attaque qui change d'allure
selon qu'on bouge ou non est un signal incohérent, et dans une arène PvP la
plupart des coups partent en mouvement. Si tu veux ce pas planté malgré tout,
c'est faisable, mais c'est ton appel.

### Une idée que je n'ai pas prise, et qui t'appartient

La tête pourrait **regarder sa cible** plutôt que suivre le geste. Ça se lirait
très bien : on verrait qui quelqu'un attaque. Je ne l'ai pas fait, parce que
c'est une **information nouvelle donnée à l'adversaire** — un signal avant le
coup. Ce n'est pas de la décoration, donc ce n'est pas à moi de le décider.

---

## 27 octobre 2026 — Les équipes, qui n'existaient pas

En relisant la boucle de partie pour te proposer la suite, j'ai trouvé une
chose plus grosse que prévu : **le jeu n'avait jamais eu d'équipes.**

`MatchService` portait un `PLAYERS_NEEDED = 2` en dur et appelait
`runMatch({ players[1], players[2] })`. Il asseyait les deux premiers joueurs
arrivés, et l'équipe était donnée par ordre d'arrivée dans une liste de deux
noms : un troisième joueur n'avait **aucune équipe**. Les quatre formats de
`Config.formats` — 1v1, 2v2, 3v3, 4v4 — étaient déclarés, commentés, et lus par
personne. Le 3v3, qui est le format de référence pour l'équilibrage, n'avait
jamais fait tourner une ligne de code.

Ce qui est frappant, c'est que **tout le reste savait déjà compter en
équipes** : `Downed.roundIsOver` compte les équipes encore debout,
`Downed.roundWinner` renvoie la dernière qui tient, le relèvement cherche « un
coéquipier debout, assez proche », et `DraftService` déduit tout seul la taille
des équipes depuis la table qu'on lui passe. Rien ne les composait, voilà tout.

### Les décisions que j'ai prises

**Les effectifs impairs descendent d'un format au lieu d'improviser.** À cinq
joueurs on joue en 2v2 et un joueur attend ; je n'ai pas fait de 3v2. Un 3v2
est injouable à juger : on ne saurait jamais si une classe est forte ou si elle
était simplement une de plus. C'est le raisonnement de la fiche appliqué au
placement — les quatre formats sont pairs, donc le surplus attend.

**Le banc tourne, et c'est la seule chose qu'il retient.** Celui qui vient
d'attendre passe devant tout le monde à la partie suivante. Sans ça, à cinq
joueurs, le dernier arrivé regarderait les autres jouer toute la soirée sans
que le jeu ait un moyen de le lui dire. Le compteur meurt avec le serveur : il
sert à répartir une soirée, pas à porter une progression de compte — ce serait
le troisième principe cassé.

**Les équipes s'alternent au lieu d'être coupées en deux blocs.** Les deux
joueurs qui ont le plus attendu se retrouvent donc face à face. Coupées en
blocs, le banc fabriquerait une équipe entière de joueurs frais contre une
équipe qui vient d'enchaîner une série.

**Les équipes ne sont PAS équilibrées par le classement.** C'est volontaire et
c'est ton appel : l'Elo existe, donc on pourrait répartir les forts et les
faibles. Je ne l'ai pas fait pour deux raisons — ça demande une lecture de
profil avant chaque partie, donc un aller-retour DataStore sur le chemin
critique ; et surtout, équilibrer les équipes et classer les joueurs tirent
dans deux directions opposées. Si tu veux des parties serrées entre amis de
niveaux différents, dis-le et je le code.

**Un départ ne tue plus la partie.** `waitForRoundEnd` abandonnait la partie
dès qu'un joueur quittait. À deux joueurs c'était la seule réponse possible ; à
six, une coupure de réseau faisait perdre leur série aux cinq autres. Le
partant est maintenant retiré de la liste et la manche se résout toute seule,
puisque les services en aval le retirent déjà de leurs rosters.

**Une partie qui perd un camp entier ne paie PERSONNE**, et c'est délibérément
sévère. Deux raisons qui tiennent ensemble. Le profil de celui qui part est
déjà écrit et fermé par le `PlayerRemoving` de `ProgressService`, donc il est
impossible de lui retirer quoi que ce soit. Et un classement qui créditerait le
camp restant **se farmerait à deux comptes**, l'un quittant pour l'autre.
Personne n'a rien gagné dans une partie comme ça, donc personne n'est payé.

### Ce que j'ai pu vérifier, et ce que je n'ai pas pu

Vérifié dans la vraie machine virtuelle de Roblox, pas seulement dans les
tests : les formats se déduisent correctement de 1 à 9 joueurs, les deux camps
ont toujours le même effectif, le banc tourne, et dix plans identiques à six
joueurs donnent exactement le même placement — le tri de Roblox est d'accord
avec celui de Lune sur les égalités. La map a bien cinq points de départ par
équipe, espacés de 9 studs, donc un 4v4 ne superpose personne.

**Ce que je ne peux pas vérifier : la chose elle-même.** Mon outil de test de
Studio ne lance qu'une partie solo. Un vrai 2v2 ne se verra qu'avec toi et des
amis, et c'est le point 140 d'`A-TESTER.md`.

---

## 27 octobre 2026 — Le mode privé, et un interrupteur que personne ne lisait

Tu as demandé pourquoi le placement par ordre d'arrivée, puisqu'en classé on
devrait arriver en équipe. En allant vérifier ce que le projet avait décidé,
j'ai trouvé que `Config.elo` le disait depuis le début :

> Le classé est le mode par défaut. Les parties privées entre amis sont natives
> sur Roblox et ne comptent pas : c'est là qu'on teste.

Donc pas de lobby, pas de file d'attente : serveur public pour le classé,
serveur privé Roblox pour les essais. Mais `Rating.counts`, la fonction qui
porte cette règle, **n'était appelée par aucun service** — seulement par les
tests. `ProgressService.awardMatch` distribuait l'Elo et les pièces dans tous
les cas. Une partie d'essai entre amis aurait déplacé vos vrais classements,
exactement pendant le test que je venais de te demander de faire.

C'est la troisième fois que la même panne apparaît : une intention écrite dans
`Config`, lue par personne. Les branches creuses, les quatre formats, et
maintenant le mode privé.

### Les décisions

**Les pièces suivent le classement.** `Config.economy.privateMatchesPay` est
nouveau et vaut `false`, et un test vérifie que les deux interrupteurs disent la
même chose. Payer sans classer récompenserait un serveur privé à deux joueurs
complaisants — une caisse toutes les trois minutes ; classer sans payer serait
incompréhensible. C'est le même raisonnement que le bac à sable, qui n'existe
qu'avec un seul joueur pour que rien ne s'y gagne.

**Le compte de parties n'avance pas non plus** dans une partie qui ne compte
pas. Il pilote le coefficient K et l'accélération des nouveaux joueurs : le
laisser monter userait les deux à blanc sans qu'aucun classement ne bouge.

**Une partie qui ne compte pas le dit à l'écran.** « Partie privée · aucune
pièce, aucun classement ». Sans ça le joueur gagne, ne voit rien arriver, et
n'a aucun moyen de savoir si c'est voulu ou cassé.

**Studio compte comme privé.** Sinon chacun de mes tests déplacerait un
classement réel. Pour vérifier le chemin du classé malgré tout, il y a les deux
interrupteurs de `Config`, pas une exception cachée dans le code.

**La question « sommes-nous en privé » vit à un seul endroit**, `Venue.luau`.
Elle avait déjà une copie dans `SandboxService` ; trois copies de la même
condition finissent par ne plus dire la même chose. C'est la règle des planchers
de `Modifiers`, appliquée à une question de lieu.

### Le choix du camp

**C'est une préférence, pas une garantie, et je n'ai pas pu faire autrement.**
Les deux camps doivent rester égaux — un 3v1 annoncé comme un 2v2 rend tout
l'équilibrage illisible. Donc quand quatre joueurs demandent un camp de trois
places, le quatrième part en face, et c'est l'ordre du banc qui le désigne. Un
test vérifie les trois cas : trois amis qui demandent le même camp l'obtiennent,
un camp sur-demandé ne déborde pas, et quatre vœux pour le même camp laissent
quand même deux camps égaux.

**Jamais en partie classée, et ce n'est pas de la prudence.** Deux amis qui
choisissent le même camp sur un serveur public empileraient un côté, et le
classement de tous les autres paierait l'addition. Le serveur refuse la demande
au lieu de compter sur le client pour ne pas l'envoyer.

**Une seule touche, `C`.** Trois touches auraient été plus directes, mais 1 à 4
servent déjà aux objets. Un test vérifie maintenant qu'aucun réglage ne réclame
la même touche qu'un autre — les touches sont à trois endroits différents de
`Config`, et le camp a failli prendre « 1 ».

Cette touche faisait d'abord tourner A, puis B, puis auto, sans rien afficher.
Elle ouvre maintenant le salon, décrit juste en dessous : le camp y est une
rangée de boutons parmi trois.

---

## 27 octobre 2026 — Le salon : le format et les équipes, et rien d'autre

Tu as demandé de pouvoir lancer le jeu avec tes amis et de gérer vous-mêmes le
mode de jeu et les équipes, avec le choix entre composer les camps vous-mêmes et
les tirer au sort. Puis tu as fermé la porte au reste : « sinon le jeu reste le
jeu, on doit pas pouvoir le modifier ».

C'est cette deuxième phrase qui a décidé de la forme. Un panneau qui réglerait
aussi la zone, l'agonie ou l'arbre serait un éditeur de règles : chaque partie
privée deviendrait un jeu différent, et plus aucune ne dirait quoi que ce soit
sur le jeu qu'on est en train de construire. Le salon ne touche donc qu'à deux
choses, et les deux ne changent pas les règles : combien on est par camp, et
qui est avec qui.

### Ce que le salon fait

**La touche `C`, en partie privée seulement.** Trois rangées de boutons :
FORMAT (auto, 1v1, 2v2, 3v3, 4v4), ÉQUIPES (chacun choisit, au hasard), et TON
CAMP (peu importe, équipe A, équipe B). Chaque réglage s'annonce dans le bandeau
pendant trois secondes, pour que les autres le voient sans avoir le panneau
ouvert.

**La rangée TON CAMP disparaît quand les équipes sont tirées au sort.** Un
bouton qui ne fait rien se lit comme une panne. C'est la même règle que les
armes verrouillées sans explication du panneau d'équipement.

**La liste des formats est déduite de `Config.formats`.** Un cinquième format
ajouté à la table apparaîtrait tout seul à l'écran. Rien n'est recopié côté
client — c'est la même raison que les chiffres de `Config` : une liste recopiée
est une liste qui se désaccorde.

### Les trois décisions que j'ai prises seul

**Un format imposé ne change pas qui joue.** Six joueurs qui demandent du 1v1
font jouer deux personnes et en asseoir quatre. J'aurais pu refuser le réglage,
ou faire tourner plusieurs duels : le premier vous enlève un outil utile — se
mettre à deux pour regarder un duel est exactement ce qu'on veut pour juger une
classe — et le second est un autre jeu. Qui joue reste décidé par l'ordre du
banc, qui est une question d'équité entre les personnes, pas d'équilibre entre
les camps.

**Un format trop grand ne retombe pas au format du dessous.** Demander du 3v3 à
deux et se retrouver en 1v1 sans l'avoir vu passer serait pire qu'attendre :
personne ne saurait pourquoi les camps sont petits. Le pied du panneau dit
alors « 1 joueur sur les 6 que ce format demande ».

**Le tirage au sort ignore les vœux de camp, et ne touche pas au banc.** Il
mélange l'ordre dans lequel les camps se remplissent, pas l'ordre dans lequel
on s'assoit : mélanger les places serait une loterie sur le droit de jouer,
alors que tu as demandé un tirage sur les équipes. Et il est refait à chaque
partie, donc deux amis qui tombent ensemble ne le restent pas.

### Deux garde-fous, et pourquoi il en faut deux

Le serveur refuse toute modification hors partie privée, et le panneau refuse
de s'ouvrir quand le serveur a répondu non. Le deuxième ne sert à rien contre
un tricheur — il est là pour que la touche ne fasse rien du tout en partie
classée, au lieu d'ouvrir un panneau dont chaque bouton serait ignoré.

Pour la même raison, **la ligne des touches en bas de l'écran ne mentionne `C`
que là où elle sert**. Annoncer une touche inerte est pire que de la taire.

### Ce que la vérification en jeu a attrapé

Deux choses, et aucune des deux n'apparaît dans les 1386 tests.

**Le panneau restait ouvert pour toujours** si le salon lui était retiré
pendant qu'il était affiché : la touche refusait de le rouvrir, donc elle
refusait aussi de le fermer. Un refus doit laisser l'écran dans l'état le plus
sûr, qui est fermé.

**« 1 joueurs sur les 2 »**, et c'est le cas qu'on voit le plus : celui qui
ouvre le salon en premier est tout seul.

### Ce que j'ai pu vérifier, et ce que je n'ai pas pu

Vérifié en jeu, dans Studio : le panneau s'ouvre et se ferme, les cinq formats
et les deux modes s'allument quand on les choisit, la rangée TON CAMP
disparaît et revient avec le mode, le pied compte juste, le serveur annonce
chaque changement dans la console, le panneau est centré à 0,0 pixel près, et
la ligne des touches gagne puis perd « C salon » selon ce que le serveur
répond.

**Je n'ai toujours pas appuyé sur `C` ni cliqué sur un bouton.** Mes frappes
synthétiques partent dans la fenêtre de Studio et pas dans le jeu. J'ai piloté
le panneau en appelant directement ce que la touche appelle, et les boutons en
envoyant exactement ce qu'ils envoient — donc tout le chemin est vérifié sauf
son premier centimètre. C'est le point 156 d'`A-TESTER.md`.

---

## 27 octobre 2026 — Les quarante-neuf objets qui manquaient

Le catalogue passe de treize objets à soixante-deux, et le dernier palier 6 non
codé est codé. Le jeu est complet au sens où plus rien de ce que `Config`
annonce n'est absent du code.

### Ce que ça a vraiment demandé

Beaucoup moins que prévu, et pour une raison qui mérite d'être notée : **tout ce
qui était en aval savait déjà faire**. Les quarante-neuf objets n'ont ajouté que
trois sortes d'utilisation (`zone`, `leap`, `throw`), un module de logique pure
(`Status`) et un service (`StatusService`). Le reste réemploie ce qui existait :

- la faux de la Peste réutilise le `spreadRatio` que son palier 6 avait déjà ;
- l'exosquelette réutilise le chemin de résistance à la poussée du Sismique ;
- la grenade incendiaire réutilise le feu du Pyromane ;
- le brouilleur réutilise les révélations du Traqueur, en les effaçant.

C'est la même leçon que les équipes : **avant de croire qu'un chantier est gros,
lire ce qui est en aval.**

### Deux résistances nouvelles, et pourquoi

Les dégâts portent maintenant une **sorte** — un coup, une explosion, un poison.
Sans ça, le gilet pare-éclats et le plastron de cuir ne pouvaient pas exister :
une armure « forte contre les explosions » dont le chiffre n'entre dans aucun
calcul ne réduit rien, en silence. Un test croise les deux armures et les deux
sortes dans les quatre sens, parce qu'une seule colonne passerait même si la
sorte était ignorée partout.

### Le palier 6 du Monolithe — **une décision prise sans toi**

Il promettait une « immunité aux projectiles » dans un jeu où **rien ne vole** :
les armes à feu et l'arc touchent instantanément à portée. Il était déclaré non
implémenté depuis le début et s'affichait comme indisponible.

Les sortes de dégât ont rendu possible la lecture la plus proche de son
intention : **immunité aux explosions** quand on reste immobile deux secondes.
Une classe qui s'ancre pour ne plus craindre ce qui arrive de loin, c'est ce que
le palier voulait dire. Deux secondes parce que c'est assez long pour être un
choix — on renonce à se déplacer — et assez court pour être atteignable dans un
vrai combat.

C'est une immunité et pas une réduction, donc elle court-circuite le calcul au
lieu d'y entrer : faire passer zéro par les bornes de `Config.combat` le
ramènerait à la moitié des dégâts.

**Si cette lecture ne te plaît pas, elle se défait en une ligne** — le drapeau
`implemented` revient à `false` et le palier redevient indisponible.

### Neuf armes rééquilibrées, parce que les tests ont refusé

Les tests de domination ont attrapé quatre dominations strictes en ajoutant les
quarante-neuf objets : l'arbalète de poing écrasait le pistolet à fléchettes, le
plastron de cuir écrasait le gilet pare-éclats, la grenade aveuglante ne faisait
aucun dégât, et le pistolet-mitrailleur sur le Spectre tirait plus vite que son
propre geste. Les tests ont aussi dû apprendre les nouveaux axes de puissance —
effet collé, explosion d'arme, portée minimale, chargeur — sinon ils auraient
déclaré dominées des armes qui ne le sont pas.

**Ce que ces tests ne disent pas** : qu'un objet est utile. Ne dominer personne
et n'intéresser personne sont deux choses différentes, et la deuxième ne se voit
qu'en jouant.

### La marge entre la recharge la plus courte et le geste : 23 millisecondes

Le Traqueur avec les griffes frappe toutes les 0,253 seconde, et le geste d'arme
dure 0,23. Il reste vingt-trois millisecondes pour que le bras revienne au
repos. C'est légal — un test le vérifie — mais c'est tendu, et c'est le premier
endroit où un geste paraîtra haché si ça se voit en jouant.

### Les bonds, qui mentaient sur leur unité — et deux corrections ratées avant la bonne

**C'est la trouvaille de la journée, et seule une mesure pouvait la faire.**

`upStuds = 40` donnait **quatre studs** de hauteur. Les bottes à ressort
sautaient donc moins haut que la barre d'espace, qui monte à 7,2. Le chiffre
partait directement dans la vitesse du personnage, et une vitesse de 40 studs
par seconde contre une gravité de 196 monte à 4,07 — exactement ce qui a été
mesuré. Mille quatre cent quatre-vingt-dix tests passaient : **aucun ne savait
ce que « stud » voulait dire.**

La première correction a converti la hauteur correctement — et ça marche, 20
demandés donnent 19,8 mesurés. L'horizontale, non : l'Humanoid de Roblox pousse
en permanence la vitesse du personnage vers celle que le joueur demande au
clavier, c'est-à-dire zéro quand personne n'appuie.

La deuxième correction a ajouté un facteur de rattrapage, et c'était le mauvais
chantier : 1,37 donnait 22,8 studs, 2,44 en donnait 67,8. **Pas le double pour
le double** — la relation n'est pas linéaire, donc aucun facteur unique ne peut
faire d'une vitesse une distance.

La bonne correction est un `LinearVelocity` en mode Ligne, résolu par le moteur
physique et pas par l'animateur : il tient la vitesse horizontale pendant tout
le vol et laisse l'axe vertical à la gravité. **Et elle a raté aussi, une
fois**, parce que `ForceLimitsEnabled` vaut vrai par défaut avec `MaxForce` à
1000 — très loin de ce qu'il faut pour lancer un personnage. Les bottes
faisaient 1,8 stud au lieu de 38, sans la moindre erreur.

Mesures finales : grappin 20 demandés / **19,8 mesurés** en hauteur et 3 / 3,1
devant ; bottes 8 / **7,9** en hauteur et 38 / **43** devant. Les cinq studs de
trop sont le glissement à l'atterrissage, et c'est la seule part de ces chiffres
qui ne se commande pas.

Le prix assumé : **on ne se dirige plus pendant un bond.** C'est même ce que le
commentaire d'à côté demandait déjà — un déplacement qui ne fait pas deux fois
la même chose ne s'apprend pas.

### La poussée ment sur son unité aussi, et je n'y ai pas touché

`knockbackStuds` et `knockbackUpStuds` sont des vitesses, comme les bonds
l'étaient. La différence est que **tous** ces chiffres sont dans la même unité,
donc ils sont cohérents entre eux : aucun ne promet une distance que l'autre ne
tient pas. Les renommer ne changerait rien au jeu ; les convertir en distances
serait un rééquilibrage de la poussée entière, déguisé en correction.

Je te le signale plutôt que de le faire : **si tu veux, je renomme les champs
pour que le nom dise « vitesse »**, sans toucher à une seule valeur.

### Un chiffre qui se cachait dans un repli

Le dôme de soin n'avait pas de `holdSeconds`, et retombait sur un `or 1` caché
dans `LoadoutService`. La valeur était bonne, mais **illisible depuis `Config`**
— exactement ce que la règle « tous les chiffres dans Config » interdit. Un test
l'a attrapé, le chiffre est maintenant écrit avec sa raison, et le serveur
refuse de démarrer si une zone colle un effet sans dire combien de temps il
tient.

### Ce que j'ai pu vérifier, et ce que je n'ai pas pu

**Vérifié dans la machine virtuelle de Roblox :** le serveur démarre avec les 62
objets et les 42 paliers 6, les quatre listes de garde-fous à jour. Les
vingt-et-un objets utilisables s'utilisent tous sans une seule erreur. Les six
soins rendent exactement ce qu'ils annoncent, poses lentes comprises. Les sept
zones se posent et **disparaissent toutes à la fin de la manche**. Les deux
bonds montent et avancent de ce qu'ils disent. Les trois couches de
statistiques tiennent sur les 62 objets et deux classes, sans un chiffre
aberrant.

**Pas pu vérifier, et c'est une limite de structure :** tout ce que les nouveaux
objets font *à un adversaire*. Les zones, les lancers et les effets collés
cherchent leurs cibles dans le `roster`, qui est indexé par `Player` — et le
mannequin du bac à sable n'est pas un `Player`. Il n'y a donc **aucun moyen**,
seul en jeu, de voir un ralentissement, un poison, un étourdissement ou une
explosion toucher quelqu'un. C'est la même raison qui rend un bot inabordable,
et elle est déjà dans `CLAUDE.md`.

Autrement dit : **la moitié offensive des quarante-neuf objets n'a jamais touché
personne.** C'est la section 21 d'`A-TESTER.md`, et c'est à deux.

### Les outils de génération 3D, essayés pour de vrai

Tu m'as demandé si je pouvais faire une belle map et de belles armes. J'ai
essayé les outils plutôt que de deviner :

- **`generate_material` marche très bien.** Un appel, et quatre variantes de
  matériau complètes arrivent — couleur, relief, métal, rugosité. C'est ce qui
  change le plus l'allure d'une map pour le moins d'effort.
- **`generate_mesh` marche.** Un katana texturé en 4000 triangles, à la taille
  demandée, publié comme asset Roblox réutilisable. Environ une minute et demie
  par maillage.
- **`search_asset` ne marche pas.** « katana sword » renvoie un point
  d'apparition, un ciel, un panneau d'administration et un NPC. « sword » en
  MeshPart renvoie une canette, des cheveux d'anime et un fusil G36. Ce n'est
  pas une recherche par le sens : prendre une arme toute faite dans la
  bibliothèque n'est pas quelque chose que je peux faire d'ici.
- **Je ne peux pas regarder le résultat.** `screen_capture` est revenu avec la
  vue 3D entièrement vide — vérifié par un témoin neon rouge posé devant la
  caméra et confirmé à l'écran par `WorldToViewportPoint` : il n'apparaît pas
  non plus. C'est le gel de rendu déjà connu, qui arrive quand la fenêtre de
  Studio passe en arrière-plan.

Donc la réponse honnête : **je peux fabriquer, je ne peux pas juger.** Ce que je
produirais serait raisonné sur les proportions et les matériaux, exactement
comme les sons ont été choisis au nom et à la durée sans jamais être écoutés.

---

## 28 octobre 2026 — Six objets d'essai, et trois choix faits sans Josh

Josh a demandé trois armes, une armure, un soin et un utilitaire, pour regarder
avant qu'on continue. Trois décisions ont été prises en les dessinant.

**Le format d'allure a changé pour tout le monde, pas seulement pour les six.**
Un objet avait une taille, une couleur et une pièce rapportée ; il a maintenant
une liste de pièces. Les 56 objets non redessinés ont été convertis
mécaniquement vers le nouveau format, à l'identique. Pourquoi tout convertir
plutôt que faire cohabiter les deux : deux formats veulent deux chemins de
construction dans `WeaponService`, et le jour où l'un des deux change, l'autre
cesse de dire la vérité en silence. C'est exactement la panne des listes de
garde-fous, et le projet en a déjà payé trois.

**Aucun chiffre d'équilibrage n'a bougé.** C'est le premier des six principes,
et il a été tenu à la lettre : le bloc `look` ne contient que des tailles, des
couleurs, des matières et des angles, et aucun de ses chiffres n'entre dans un
calcul de dégâts, de portée ou de budget. Un marteau dont la tête a doublé de
volume frappe exactement comme avant.

**L'armure est la plus faible des six, et je ne peux pas y faire grand-chose.**
Le torse d'un avatar Roblox est une boîte de 2 x 1,6 x 1 stud. Une armure de
plaques posée dessus reste une boîte : on peut la faire saillir, lui donner une
arête de laiton, une ceinture, des épaulières et des rivets — c'est fait — mais
la silhouette ne change pas. Les armes, elles, se dessinent dans le vide et
n'ont pas cette contrainte. Si Josh veut mieux que ça pour les armures, le seul
moyen est un maillage, et `generate_mesh` a rendu un disque plat la seule fois
où je l'ai essayé.

---

## Ce qui reste à Josh de toute façon

Ces décisions-là ne sont pas les miennes et ne le seront jamais : savoir si
c'est amusant, tester à plusieurs, publier, créer les produits payants, valider
la conformité de l'écran de tirage, et la direction artistique. Le détail est
dans `CLAUDE.md`, section « Qui fait quoi ».
