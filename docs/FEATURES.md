# Fonctionnalités

## F01. Mode Nuzlocke
**Statut :** v1.2.2, écrit, **non testé**.
**Version cible :** Essentials v21.1.
**Dossier :** `Plugins/Nuzlocke/`

### Règles
- **Activation :** choix unique et définitif, proposé automatiquement au début de la partie par le plugin NewGameSetup, avant le choix Monotype (ou `Nuzlocke.setup_dialog` dans un événement).
- **Une capture par zone :** une zone = une carte (fusion possible avec `ZONE_GROUPS`). La première rencontre sauvage consomme la zone, capturée ou non. Les rencontres scriptées (légendaires, statiques) consomment aussi la zone.
- **Zone Safari et Concours de Capture :** mêmes règles de zone, doublons et shiny. Au Concours, le surnom est demandé quand le Pokémon gardé est remis à la fin.
- **Combat double :** dans une zone libre, les deux Pokémon sont capturables.
- **Avec le Monotype :** une rencontre hors du type imposé ne consomme pas la zone.
- **Clause des doublons :** une espèce déjà capturée (famille d'évolution comprise) n'est pas capturable et ne consomme pas la zone.
- **Clause du shiny :** un shiny est toujours capturable. S'il est la première rencontre d'une zone libre, il consomme la zone.
- **Surnoms obligatoires :** captures, cadeaux et événements. Redemandé tant que le surnom est vide ou égal au nom de l'espèce.
- **Mort définitive :** un Pokémon du joueur qui tombe K.O. est mort tout de suite (un rappel en combat ne le sauve pas). En fin de combat il part dans une boîte « Cimetière N », créée au besoin. Il reste visible dans le PC mais ne peut plus être retiré, mis dans l'équipe, relâché ni soigné.
- **Poison hors combat :** il laisse le Pokémon à 1 PV puis disparaît.
- **Équipe entièrement K.O. :** retour au dernier Centre Pokémon, les morts vont au cimetière et la partie continue avec les Pokémon du PC. S'il ne reste plus aucun Pokémon vivant (équipe et PC), le run est perdu : le mode se désactive et l'aventure continue normalement.

### Fichiers
| Fichier | Rôle |
|---|---|
| `meta.txt` | Déclaration du plugin. |
| `001_Settings.rb` | `ZONE_GROUPS`, `DUPLICATE_BY_FAMILY`, `SHINY_CONSUMES_FREE_ZONE`, `GRAVEYARD_NAME`. |
| `002_Data.rb` | Données de sauvegarde (`$nuzlocke`), zones utilisées, boîtes cimetière. |
| `003_Encounters.rb` | Zones, doublons, shiny, blocage des Poké Balls. |
| `004_Nicknames.rb` | Surnoms obligatoires. |
| `005_Permadeath.rb` | Mort, cimetière, verrou des PV, équipe K.O. |
| `006_Setup.rb` | Fenêtre de choix du début de partie, inscrite auprès de NewGameSetup. |
| `007_Storage.rb` | Verrous du PC sur les Pokémon morts. |
| `008_FieldPoison.rb` | Poison hors combat. |

### Intégration
- Début de partie : la fenêtre s'affiche seule (plugin NewGameSetup requis). `Nuzlocke.setup_dialog` reste utilisable dans un événement.
- Regrouper des cartes : `Nuzlocke::ZONE_GROUPS = { id_secondaire => id_principal }`.

### Points d'accroche Essentials (alias/prepend, aucun script de base modifié)
`pbStartBattle`, `pbThrowPokeBall`, `pbStorePokemon` (sur `Battle` et `SafariBattle`, qui n'hérite pas de `Battle`), `Battle::Battler#pbFaint`, `ItemHandlers.triggerCanUseInBattle`, `Battle::Scene#pbToggleBallInfo` (menu des Poké Balls de l'Enhanced Battle UI), `pbNickname`, `Pokemon#hp=`, `Pokemon#heal_HP`, `PokemonStorageScreen#pbWithdraw/pbPlace/pbSwap/pbRelease`, handlers `:on_end_battle` et `:poison_party` (remplacé).

### À vérifier au premier lancement
- Les points d'accroche ont été vérifiés contre les scripts v21.1 du dépôt (`Data/Scripts.rxdata`), mais le plugin n'a pas encore tourné en jeu.
- Combat double avec une cible non capturable : la Poké Ball est rendue mais le tour est perdu.

### Limites connues
- Pas de mode hardcore pour l'instant (poison mortel, K.O. de l'équipe = fin de partie) : à ajouter plus tard.
- Les œufs qui éclosent ne forcent pas de surnom.
- Les cadeaux ne consomment pas la zone.

## F02. Deluxe Battle Kit (plugin externe)
**Statut :** v1.3.1 installé (Lucidious89), avec son prérequis v21.1 Hotfixes 1.0.9 (Maruno). **Non testé.**
**Dossiers :** `Plugins/[DBK_000] Deluxe Battle Kit/`, `Plugins/v21.1 Hotfixes/`, `Graphics/Plugins/Deluxe Battle Kit/`, plus quelques fichiers dans `Audio/` et `Graphics/UI/`.
**Doc :** https://lucidious89-tutorials.gitbook.io/deluxe-battle-kit-tutorial

- Ajoute des Battle Rules (`setBattleRule`), les combats de boss sauvages (`editWildPokemon` avec `:hp_level` et `:immunities`), la capture style raid et les scripts en plein combat.
- Remplace deux images de base : `Graphics/UI/Battle/icon_mega.png` et `cursor_command.png`.
- `Town Map Generator.html` (version corrigée de `townmapgen.html`) est à la racine du projet.
- Cohabitation avec le Nuzlocke : le kit efface les surnoms dans `pbStorePokemon`, le Nuzlocke remet le surnom forcé après coup. Effet visible : le message « envoyé dans la boîte » affiche le nom de l'espèce.

## F03. Générateur de cartes (MapGen)
**Statut :** v1.9.0, écrit, testé hors jeu sur les données du dépôt, **non testé en jeu**.
**Version cible :** Essentials v21.1.
**Dossier :** `Plugins/MapGenerator/`, plans dans `MapGen/*.txt` (exemples : `MapGen/exemple.txt`, `MapGen/exemple_calques.txt`, `MapGen/exemple_porte_dehors.txt` + `MapGen/exemple_porte_maison.txt`, `MapGen/place_ville.txt`, plan du monde `MapGen/exemple_monde.txt`).

### Fonctionnement
- Un plan texte décrit la carte : un caractère par case, une légende qui associe chaque caractère à 1 à 3 calques.
- Calques : `T<n>` = tuile n du tileset (n = ligne × 8 + colonne), `A1` à `A7` = autotile (raccords calculés automatiquement), `-` = vide, `T1|T2|T3` = variante au hasard (`Seed` pour un résultat reproductible).
- Objets multi-cases (section `[Objects]`) : `H = T400 3x4` déclare un bloc de 3×4 tuiles à partir de la tuile 400. Dans `[Map]`, le symbole couvre toute la surface de l'objet (`HHH` sur 4 lignes). Une zone plus grande contient plusieurs copies, découpées depuis le coin haut-gauche (`HHHHHH` sur 4 lignes = deux objets). Une zone incomplète provoque une erreur qui indique la case fautive. Options : `L1` à `L3` pour le calque (`L2` par défaut), `@<symbole>` pour le sol sous l'objet (sinon la clé `Ground`).
- Grilles de calques (sections `[Layer2]` et `[Layer3]`, facultatives, même taille que `[Map]`) : dessinées par-dessus `[Map]`. `.` = rien ; un symbole de `[Legend]` est posé à partir de ce calque (un symbole à 2 calques dans `[Layer2]` remplit les calques 2 et 3) ; un objet de `[Objects]` est posé sur ce calque, quel que soit son `L`.
- Terrains à raccords automatiques (section `[Terrains]`) : `P = T274 N=T266 S=T282 W=T273 E=T275 NW=T265 NE=T267 SW=T281 SE=T283 iNW=T286 iNE=T284 iSW=T270 iSE=T268` déclare la tuile intérieure, les bords, les coins et les angles rentrants (`i…`). Dans la grille, on écrit seulement `P` : chaque case reçoit la tuile qui correspond à ses voisines. Un rôle absent prend la tuile intérieure. Options : `with=D` (terrains qui se raccordent sans bord), `L1` à `L3` (calque dans `[Map]`, `L1` par défaut), `@<symbole>` (sol dessous si le calque n'est pas `L1`). Un terrain marche aussi dans `[Layer2]` / `[Layer3]`.
- Portes et étages (sections `[Warps]` et `[Events]`) : `1 = Maison 1 4,7 haut` déclare une téléportation vers la carte nommée « Maison 1 » (ou son ID), case 4,7 (comptée depuis 0), regard vers le haut (`haut`, `bas`, `gauche`, `droite`, ou direction conservée). La grille `[Events]` (même taille que `[Map]`, `.` = rien) place ces symboles. Chaque porte devient un événement « MapGen warp » (contact du joueur, commande « Téléporter le joueur ») ; Essentials le transforme en porte animée à la compilation si la case ressemble à une entrée. À chaque génération, les anciens « MapGen warp » de la carte sont remplacés. Avec « Tous », une porte vers une carte générée plus tard dans la même série est reliée après coup.
- Plan du monde (un plan qui contient la clé `World`) : décrit la région entière. `World = nom de la région`, `Region = n°` (carte de région de `town_map.txt`, 0 par défaut), `Cell = 20` (tuiles par case), `Origin = x,y` (case de la carte de région où commence le plan), `Image = monde.png` (image de la carte de région, `mapRegion<Region>.png` par défaut), `Tileset` / `Ground` (cartes créées vides). Section `[Places]` : `A = Bourg Typelock vol=12,8` associe un symbole à une carte, trouvée par son nom (`vol=x,y` = point d'arrivée de Vol, `type=ville|route|lieu` = dessin sur la carte de région, deviné sinon : « Route… » = route, avec `vol` = ville, sinon lieu, `nom=Port Lucca` = nom affiché en jeu dans les métadonnées et la carte de région, la carte gardant le sien ; `masque=10/11` = les cases de son rectangle que le lieu couvre, ligne par ligne (les autres restent hors de la carte de région : pas de `Point`, `MapSize` avec ses 0, côte dessinée autour des cases couvertes) ; `trace=1,1/3,1/3,4` = le tracé d'une route sur la carte de région, en demi-cases depuis le coin haut-gauche de son rectangle ; une région dessinée par le plan (`Image`) ne garde que les points du plan). Section `[World]` : un caractère par case de la carte de région, `.` = rien, chaque lieu forme un rectangle plein. Section `[NoLinks]` (facultative) : `A B` = deux lieux qui se touchent sans être reliés.
  - Une carte absente est générée depuis le plan MapGen de même `Name`, sinon créée vide (taille du rectangle × `Cell`). Chaque lieu doit couvrir dans `[World]` autant de cases que sa carte compte de fois `Cell` tuiles (arrondi) : une ville de 40x20 avec `Cell = 20` s'écrit `VV`. Sinon un message indique la bonne taille (« doit couvrir 2x1 cases »).
  - Deux lieux qui se touchent sont raccordés bord à bord (`PBS/map_connections.txt`), avec le décalage calculé depuis la grille.
  - Chaque lieu reçoit `Name`, `Outdoor`, `ShowArea`, `MapPosition` et `MapSize` dans `PBS/map_metadata.txt` (les autres clés de la section sont gardées), et ses cases dans la région de `PBS/town_map.txt` (`Point`, avec la destination de Vol).
  - L'image de la carte de région est dessinée dans `Graphics/UI/Town Map/` (480x320 au minimum, cases de 16 px), avec les couleurs et les formes de `mapRegion0.png` : côte arrondie avec sable et eau peu profonde, routes blanches dans un bandeau sombre qui suivent les raccords, villes en blocs rouges, autres lieux en cases sombres à point vert. Une image existante n'est remplacée que si MapGen l'a dessinée (les images faites à la main, comme `mapRegion0.png`, sont gardées).
  - Seules les lignes qui concernent les cartes du monde sont réécrites ; les trois fichiers PBS sont recompilés tout de suite.
- Lancement : menu debug > Autres éditeurs > « Générer des cartes (MapGen) ». Écrit `Data/MapXXX.rxdata` et l'ajoute à `MapInfos.rxdata`.
- Sans `MapID` : nouvelle carte (ID suivant). Avec `MapID` : la carte est remplacée, ses événements sont conservés (ceux qui sortent de la nouvelle taille sont supprimés).
- Après la génération, si RPG Maker XP est ouvert, le jeu propose de le rouvrir : il le ferme sans enregistrer (`taskkill /F`, sinon il écraserait les cartes) puis rouvre `Game.rxproj`. Même action seule : menu debug > Autres éditeurs > « Rouvrir RPG Maker XP (MapGen) ». Windows uniquement.

### Fichiers
| Fichier | Rôle |
|---|---|
| `meta.txt` | Déclaration du plugin. |
| `001_Settings.rb` | `FOLDER`, `EMPTY_TOKEN`. |
| `002_Parser.rb` | Lecture et validation des plans. |
| `003_Builder.rb` | Construction des calques, motifs d'autotiles, vérification des tuiles. |
| `004_Generate.rb` | Écriture des fichiers de carte, commandes du menu debug. |
| `005_Editor.rb` | Fermeture et réouverture de RPG Maker XP. |
| `006_World.rb` | Plans du monde : lieux, raccords, métadonnées et carte de région. |
| `007_RegionImage.rb` | Dessin de l'image de la carte de région (PNG écrit avec Zlib). |

### Points d'accroche Essentials
Aucun alias. Utilise `Compiler.compile_connections`, `compile_map_metadata` et `compile_town_map` (plans du monde), `TileDrawingHelper::NEIGHBORS_TO_AUTOTILE_INDEX` (même table que le rendu d'Essentials) et `MenuHandlers.add(:debug_menu, ...)`.

### Limites connues
- Pas encore d'import PNG (1 pixel = 1 case) ni de génération procédurale.
- Plan du monde : chaque lieu est un rectangle (pas de lieu en L), et l'image de la carte de région n'a ni relief, ni arbres, ni rivières.
- Un terrain choisit un seul angle rentrant par case : une case entourée de plusieurs angles rentrants prend le premier (haut-gauche, haut-droite, bas-gauche, bas-droite).

## F04. Mode Monotype
**Statut :** v1.5.3, écrit, **non testé**.
**Version cible :** Essentials v21.1.
**Dossier :** `Plugins/Monotype/`

### Règles
- **Activation :** choix unique et définitif, proposé automatiquement en début de partie par le plugin NewGameSetup (après le choix Nuzlocke), au premier pas du joueur ou juste avant le premier Pokémon reçu. **Normal** : le type est tiré au hasard. **Facile** : le joueur choisit parmi les 18 types.
- **Capture :** seuls les Pokémon qui ont le type imposé (simple ou double type), ou dont une évolution l'a, sont capturables (ex. Eau : Azurill grâce à Marill, Évoli grâce à Aquali). Les Poké Balls sont grisées, ou rendues en combat double si la cible n'est pas capturable. Le type compte pour la forme (Motisma Lavage = Électrik/Eau).
- **Évolutions :** le sens inverse ne compte pas. Un Pokémon qui perd le type en évoluant (Évoli → Pyroli en Eau) devient inutilisable et part au PC.
- **Dons et échanges hors du type :** envoyés directement au PC, présents mais inutilisables.
- **Inutilisable :** ne peut pas quitter le PC pour l'équipe. Un Pokémon inutilisable dans l'équipe (évolution, échange, Pension) est envoyé au PC à la fin du combat ou au pas suivant.
- **Starter :** le joueur choisit son starter, niveau 5, parmi 3 Pokémon tirés au hasard pour la partie. Ils viennent des 300 Pokémon du jeu (`docs/roster/liste-300.csv`) : formes de base (leur pré-évolution n'est pas dans la liste) qui respectent la règle de capture, sans les pseudo-légendaires (évolution finale à plus de `STARTER_MAX_FINAL_STATS` = 599 de stats de base). Le tirage est gardé dans la sauvegarde pour que chaque Poké Ball du professeur garde son Pokémon.
- **Où :** chez le professeur (carte 4) : chacune des 3 Poké Balls appelle `Monotype.starter_ball(0)`, `(1)` ou `(2)` et propose « Tu veux X (type) ? ». Avec `STARTER_AT_SETUP = true`, le choix s'affiche à la place juste après celui du type, dans une seule liste (`Monotype.starter_dialog`).
- **Arènes et Ligue :** avant le combat contre un dresseur d'arène, un champion, un membre du Conseil 4 ou le Maître, s'il n'y a aucun Pokémon du type dans l'équipe (par exemple un seul Pokémon qui a perdu le type en évoluant), le message « Seuls les Pokémon de type X peuvent combattre dans les arènes et à la Ligue » s'affiche à la place du combat, et le dresseur n'est pas battu.
- **CT et capacités :** aucune restriction de type, seulement celles des Pokémon.
- **Avec le Nuzlocke :** cumulable. Une rencontre hors du type ne consomme pas la zone.

### Fichiers
| Fichier | Rôle |
|---|---|
| `meta.txt` | Déclaration du plugin. |
| `001_Settings.rb` | `EXCLUDED_TYPES` (types impossibles à tirer ou choisir), `STARTER_COUNT`, `STARTER_LEVEL`, `STARTER_MAX_FINAL_STATS` (exclut les pseudo-légendaires), `STARTER_AT_SETUP` (choix du starter en début de partie ou par événement), `GYM_MAP_PATTERN` (nom des cartes d'arène et de Ligue dans l'éditeur), `GYM_LEADER_PATTERN` (types de dresseur des champions, du Conseil 4 et du Maître). |
| `002_Data.rb` | Données de sauvegarde (`$monotype`), test du type avec les évolutions, starters possibles. |
| `003_Setup.rb` | Fenêtres du début de partie (type puis starter), inscrites auprès de NewGameSetup. |
| `004_Capture.rb` | Blocage des captures. |
| `005_Party.rb` | Combats d'arène et de Ligue, dons au PC, Pokémon inutilisables, verrous du PC. |
| `006_Roster.rb` | `ROSTER` : les 300 Pokémon du jeu, copie de `docs/roster/liste-300.csv` (vérifiée par la CI, qui vérifie aussi qu'il y a au moins 3 starters possibles par type). |

### Intégration
- Rien à placer dans l'éditeur : les choix de mode s'affichent seuls en début de partie, les dresseurs d'arène et de Ligue sont reconnus par le nom de la carte dans l'éditeur (« Gym », « Arène », « League » ou « Ligue », réglable avec `GYM_MAP_PATTERN`), et les champions, le Conseil 4 et le Maître par leur type de dresseur (`LEADER_…`, `ELITEFOUR_…`, `CHAMPION…`, réglable avec `GYM_LEADER_PATTERN`).
- Facultatif : `Monotype.setup_dialog` ou `Nuzlocke.setup_dialog` dans un événement pour choisir le moment exact.
- Labo du professeur (carte 4) : les 3 Poké Balls de la démo appellent `Monotype.starter_ball(i)` dans une condition « Script » ; si le joueur prend le Pokémon, elles gardent leurs effets (interrupteur 3, variable 7 = 1, 2 ou 3 selon la Poké Ball, interrupteur local A). Pour un autre lieu, recopier ces 3 événements.

### Points d'accroche Essentials (alias/prepend, aucun script de base modifié)
`pbThrowPokeBall` (sur `Battle` et `SafariBattle`), `ItemHandlers.triggerCanUseInBattle`, `Battle::Scene#pbToggleBallInfo` (menu des Poké Balls de l'Enhanced Battle UI), `TrainerBattle.start_core`, `pbStorePokemon` global (dons), `PokemonStorageScreen#pbWithdraw/pbPlace/pbSwap`, handlers `:on_end_battle` et `:on_player_step_taken`.

### À vérifier au premier lancement
- La liste des 18 types tient à l'écran (la fenêtre défile normalement).
- Les fenêtres de choix apparaissent au premier pas dans la chambre, après l'intro.
- Au labo, chaque Poké Ball propose un starter différent du type, et le Pokémon pris arrive dans l'équipe ; refuser laisse la Poké Ball en place.

### Limites connues
- L'équipe ne peut pas être vide : un Pokémon inutilisable qui est seul dans l'équipe y reste (il ne peut pas combattre dans une arène ni à la Ligue).
- Si le PC est plein, un Pokémon inutilisable reste dans l'équipe.

## F05. Pokémon boss (OverworldBoss)
**Statut :** v1.0.0, écrit, **non testé**.
**Version cible :** Essentials v21.1, Deluxe Battle Kit 1.3.1 (requis).
**Dossier :** `Plugins/OverworldBoss/`

### Règles
- **Boss :** Pokémon sauvage fort, visible sur la carte (événement), placé plutôt au bout des zones. Les Pokémon normaux restent dans les hautes herbes (`encounters.txt`).
- **Stats :** multiplicateurs par stat (`stats: { HP: 3, ATTACK: 1.5 }`). Les PV passent par le `hp_level` du Deluxe Battle Kit (barre de vie et dégâts gérés par le kit), les autres stats sont multipliées après le calcul normal.
- **Talent :** n'importe quel talent, même hors de ceux de l'espèce (`ability: :LEVITATE`).
- **Immunités (kit) :** `:FLINCH`, `:OHKO`, `:SELFKO`, `:ESCAPE`. Par défaut : peur, K.O. en un coup, fuite.
- **Combat :** fuite impossible. Battu ou capturé : l'interrupteur local A de l'événement s'active et le boss disparaît définitivement (effacé, sans page 2). Perdu : le boss reste.
- **Capture :** le boss garde son talent de boss, mais perd ses multiplicateurs et ses immunités (`KEEP_ABILITY_ON_CAPTURE = false` pour lui rendre aussi son talent normal). IVs, nature et capacités restent.
- **Avec le Nuzlocke :** règle normale, capturable seulement s'il est la première rencontre de la zone.
- **Avec le Monotype :** règle normale, capturable seulement s'il a le type.

### Fichiers
| Fichier | Rôle |
|---|---|
| `meta.txt` | Déclaration du plugin (requiert le Deluxe Battle Kit). |
| `001_Settings.rb` | `DEFAULT_IVS`, `DEFAULT_IMMUNITIES`, `KEEP_ABILITY_ON_CAPTURE`, `SELF_SWITCH`. |
| `002_Boss.rb` | Création du boss, multiplicateurs de stats, retour à la normale à la capture, `boss_battle` pour les événements. |

### Intégration
- Événement page 1 : graphisme du Pokémon, déclenchement « Touche action » ou « Contact avec le joueur », commande Script :
  `boss_battle(:GYARADOS, 30, stats: { HP: 3, ATTACK: 1.5 }, ability: :INTIMIDATE, moves: [:DRAGONDANCE, :WATERFALL])`
- Options : `stats`, `ability`, `moves`, `immunities`, `ivs`, `item`, `nature`, `shiny` (faux par défaut).

### Points d'accroche Essentials (prepend, aucun script de base modifié)
`Pokemon#calc_stats`, `Battle#pbStorePokemon`, `Game_Event#refresh`, nouvelle méthode `Interpreter#boss_battle`.

### À vérifier au premier lancement
- Les PV affichés du boss et ses PV après capture (doivent revenir à la normale).

## F06. Placeur d'événements (MapEvents)
**Statut :** v1.2.0, écrit, **non testé en jeu** (conversion testée hors jeu avec le compilateur réel d'Essentials).
**Version cible :** Essentials v21.1. Plugin séparé de MapGen (aucune dépendance obligatoire).
**Dossier :** `Plugins/MapEvents/`, plans dans `MapEvents/*.txt` (exemple : `MapEvents/exemple.txt`, sur la carte de `MapGen/exemple.txt`).

### Règles
- **Un plan par carte :** `Map = Route 1` (nom dans l'arbre des cartes, ou ID). `BGM = Route 1` (facultatif, `nom[,volume[,hauteur]]`) règle la musique de la carte.
- **Un événement par section**, placé avec `Pos = x,y` (case comptée depuis 0, comme MapGen). Le nom après le type (`[Npc A]`) est une étiquette unique dans le fichier.
- **`[Npc A]` (PNJ ou pancarte) :** `Graphic` (sans graphisme = pancarte), `Facing` (`haut`, `bas`, `gauche`, `droite`), puis des `Text` (une boîte de message chacun) et des `Script` (une ligne de script chacun, ex. `pbPokemonMart([:POKEBALL, :POTION])`), exécutés dans l'ordre du fichier.
- **Déplacements (PNJ et dresseurs) :** `Move = fixe` (par défaut), `vers_joueur` (s'approche du joueur) ou `ronde`. `Route = droite*3, attendre 60, gauche*3, regard_bas` est un trajet répété en boucle (pas : `haut`, `bas`, `gauche`, `droite`, `*n` pour répéter, `regard_<direction>`, `attendre <images>`) ; il implique `Move = ronde`, doit revenir à `Pos` et rester dans la carte (vérifié). `Speed` et `Frequency` de 1 à 6 comme dans l'éditeur, `Through = oui` pour traverser les autres. Pas de déplacement aléatoire (un PNJ ne peut pas être tenu dans une zone).
- **`[Trainer B]` (dresseur) :** `Type`, `Name`, `Battle` obligatoires ; `Sight` (portée de vue, 3 par défaut) ; `Graphic` (sinon celui du type de dresseur) ; `Facing`. Les autres clés sont les commentaires de dresseur d'Essentials : `EndBattle`, `BattleID`, `DoubleBattle` / `Continue` (`oui`/`non`), `Backdrop`, `EndIfSwitch`, `VanishIfSwitch`, `Outcome`, `RegSpeech`. Plusieurs `Battle` = revanches. L'équipe est celle de `PBS/trainers.txt`.
- **Champion d'arène :** un `[Trainer]` avec, après une victoire, `Win` (texte, codes de message acceptés comme `\me[Badge get]`), `Badge = n` (badge 1 à 8), `Gift = TM39` (objet donné), `Switch = n` (interrupteur activé). Le Monotype le reconnaît par son type `LEADER_…`.
- **`Trigger` et `Hide` (PNJ) :** `Trigger = contact` déclenche le PNJ quand le joueur marche dessus ou le heurte (`action` par défaut). `Hide = V7>=1` le fait disparaître dès que la condition est vraie (une page vide qui se traverse prend le relais) : `A` à `D` (interrupteur local), `S25` (interrupteur 25 activé), `V7>=1` (variable 7 au moins à 1).
- **`[Item C]` :** `Item = POTION`, `Hidden = oui` pour un objet caché.
- **`[Metadata]` :** lignes `Clé = valeur` fusionnées dans la section de la carte de `PBS/map_metadata.txt` (les autres clés sont gardées), ex. `HealingSpot`, `Outdoor`, `BattleBack`.
- **`[Encounters]` :** mêmes lignes que dans `PBS/encounters.txt` (`Land,21` puis `40,PIDGEY,2,4`) ; elles remplacent la section de la carte. Les deux PBS sont recompilés aussitôt. **Convention du projet : ne pas l'utiliser**, les rencontres se gèrent uniquement dans `PBS/encounters.txt`.
- **Relance :** chaque événement écrit porte « MapEvents <étiquette> » dans son nom ; relancer un plan remplace ces événements et garde ceux placés à la main dans l'éditeur. Une case déjà occupée par un autre événement donne un avertissement.

### Fichiers
| Fichier | Rôle |
|---|---|
| `meta.txt` | Déclaration du plugin. |
| `001_Settings.rb` | `FOLDER` (dossier des plans), `TAG` (mot ajouté au nom des événements), chemins des PBS. |
| `002_Parser.rb` | Lecture et vérification des plans (format en tête du fichier). |
| `003_Events.rb` | Construction des événements : PNJ directement, dresseurs et objets écrits sous la forme courte d'Essentials (nom `Trainer(n)` + commentaires, nom `Item:X`) puis convertis par `Compiler.convert_to_trainer_event` / `convert_to_item_event` ; récompenses de champion insérées dans la branche de victoire. |
| `004_Generate.rb` | Écriture dans `Data/MapXXX.rxdata`, mise à jour de `encounters.txt` et `map_metadata.txt`, menu debug. |

### Intégration
- Générer d'abord la carte (MapGen ou à la main), puis menu debug > Autres éditeurs > « Placer les événements (MapEvents) », un plan ou « Tous ». Si MapGen est installé, la réouverture de RPG Maker XP est proposée ensuite.
- CI : `tools/ci/check_mapevents.rb` vérifie les plans, la carte visée, les types de dresseur, les dresseurs, les objets et les espèces.

### Points d'accroche Essentials (aucun script de base modifié)
Appels à `Compiler.convert_to_trainer_event`, `Compiler.convert_to_item_event`, `Compiler::TrainerChecker`, `Compiler.compile_encounters`, `Compiler.compile_map_metadata` ; nouvelle entrée du menu debug.

### À vérifier au premier lancement
- Le dresseur repère le joueur à sa portée et le combat se lance ; le champion donne badge, CT et texte de victoire.
- Les objets (visible et caché) se ramassent une seule fois.

### Limites connues
- Pas de scènes scénarisées (déplacements ponctuels, plusieurs pages conditionnelles) : seulement PNJ à dialogue/script, rondes en boucle, dresseurs, champions et objets.
- Dans `Battle` et `EndBattle`, la séquence `\m` coupe le texte en deux boîtes (comportement d'Essentials) : éviter `\me[...]` dans ces clés.

## F07. Génération procédurale (MapProceduralGenerator)
**Statut :** v0.24.0, prototype écrit, **non testé en jeu**.
**Version cible :** Essentials v21.1. Dépend de MapGenerator (`Requires = MapGenerator`), sans le modifier.
**Dossier :** `Plugins/MapProceduralGenerator/`, lieux dans `MapProc/*.txt` (`ville.txt`, `route.txt`, monde `monde.txt`), briques dans `MapProc/Briques/*.txt`.

### Règles

- Une ville ou une route est assemblée à partir de briques faites main (bâtiments, herbes, décor) : chaque graine donne un résultat différent, la même graine redonne le même.
- Les herbes sont de deux sortes : les hautes herbes normales (T6) et des touffes d'herbes très hautes (T7 posé sur son pied T15, une rangée de pied sous la touffe, comme dans les cartes d'exemple d'Essentials ; on n'y court pas). La CI (`check_mapproc.rb`, `SPILL_BELOW`) refuse toute plante sur deux tuiles posée sans sa partie basse.
- Les lacs décoratifs (`lac` dans `[Briques]`) ne se posent jamais sur le passage.
- Collines (`colline` dans `[Briques]`) : une butte de roche de forme ovale dessinée pour sa place, avec un escalier au milieu de sa face sud (un chemin y mène). Sur les routes (0 à 1 par case de 20×20) et rarement en ville (`HILL_TOWN_CHANCE`, 20 % des fois où elle est tirée).
- Relief : des montagnes (massifs de roche, terrain `^`) se posent sur les routes et parfois dans les villes ; certaines ont un escalier taillé dans leur face sud qui mène sur le dessus. Les routes ont aussi des corniches, que l'on saute vers le sud sans pouvoir les remonter. Ces briques ne barrent jamais le passage.
- Ambiances (`[Ambiance nom]` dans `ville.txt` et `route.txt`) : chaque lieu tire son sol et ses rues selon un poids. L'herbe reste la plus courante ; quelques villes ont des chemins de terre, un sol de prairie, de sable, minéral ou de terre battue, quelques routes un sol de prairie, de sable ou de terre battue.
  - **Décor par ambiance :** une ambiance peut redéfinir un symbole de la palette (une ligne `t = T520 2x3` dans la section de l'ambiance, avec la syntaxe de sa section d'origine, `{sol}` compris) et changer la quantité d'un type de `[Briques]` (`arbre = 0..1 par case`). Seuls les lieux qui tirent l'ambiance en tiennent compte ; le plateau de la Ligue et les îles gardent les quantités fixées par le monde (le décor redéfini s'applique quand même). Symbole ou type inconnu : erreur avec le fichier et la ligne. La CI génère chaque ambiance sur 3 graines.
  - **Briques réservées :** un fichier de brique peut lister ses ambiances (`Ambiances = sable, minérale`, séparées par des virgules) : elle n'est alors tirée que dans ces ambiances. Un type dont aucune brique ne convient à l'ambiance est sauté. Le type `decor` regroupe les briques de pur décor (quantité `decor = 0` dans `[Briques]`, donnée par chaque ambiance). La CI refuse une ambiance inconnue et vérifie qu'aucune brique réservée n'est posée ailleurs.
  - **Sable :** flèches rocheuses brunes, rochers et cailloux bruns, peu d'arbres, pas de parc sur les routes. **Minérale** (villes et routes) : flèches et éboulis gris, rochers gris, la roche grise à la place de la brune (montagnes, rochers, corniches ; les escaliers restent bruns), pas de lac.
  - **Verdoyante :** bois mélangés (grands pins, arbres ronds, cyprès), buissons. **Prairie :** fleurs, buissons, cyprès, haies taillées, peu d'arbres. **Terre battue et chemins de terre :** champs labourés, haies, arbres ronds et grands pins (chemins de terre).
  - **Nouvelles ambiances :** **automne** (routes et villes : arbres et buissons jaunes) et **forêt tropicale** (routes : grands arbres à canopée, buissons serrés), chacune au poids 1. Les arbres de bordure restent des pins.
  - **En attente de graphismes** (absents du tileset Outside) : neige, marais, volcan, plage à palmiers, désert à cactus, rive sous l'eau pour le gravier (la minérale n'a pas de lac, mais une rivière y garde la rive d'herbe).
- Un monde (`monde.txt`) tire une chaîne de villes reliées par des routes :
  - grille du monde : jusqu'à 32×24 cases (`Taille = 32x24`, `Origin = 0,0` dans `monde.txt`), tout l'écran de la carte de région (512×384, cases de 16) ; l'image de région dessinée par MapGen n'ajoute plus de marge. `Marge` (0 par défaut, 1 dans `monde.txt`) garde ce nombre de cases libres au bord de la grille, pour que la côte ne soit pas coupée par le bord de l'écran. Une fois tracé, le monde est décalé pour être centré sur la grille (`center_world`) ;
  - routes de 1 à 4 cases de long (`Longueur = 1..4`) et de 1 ou 2 cases de large (`Largeur = 1..2`, 1 par défaut) : le chemin, les herbes, l'eau et les grottes s'étalent sur toute la largeur ;
  - formes des routes (`FormesRoutes`, `droite` par défaut, `droite, L, U` dans `monde.txt`) : une route en L tourne une fois (au moins sa largeur + 2 cases de long), une route en U revient vers une ville posée à côté de celle qu'elle quitte, du même côté. Une route qui tourne garde tout son rectangle sur la grille du monde (MapGen exige un rectangle par carte) avec un masque des cases de son tracé : les cases hors du tracé sont remplies d'arbres comme la bordure (les trous entre les arbres sont bouchés par `Comble`, un buisson), les sorties ne sont que sur les bords du tracé, et les rues se rejoignent dans les coudes. Sur la carte de région, la route suit son tracé (option `trace=` de MapGen). Seules les routes droites sont coupées par l'eau ou une grotte, ou deviennent des routes de montagne. La CI vérifie sur chaque graine qu'aucune case hors du tracé ne s'atteint à pied ou en surfant, et que chaque sortie est sur le tracé ;
  - tailles des villes (`TaillesVilles`, `2x2` par défaut, `1x1, 1x2, 2x2, L` dans `monde.txt`) : village d'une case (Centre, boutique, quelques maisons, jamais d'arène, seulement là où une ville sans arène reste à placer), 1×2 ou 2×1, 2×2, ou L (un 2×2 sans une de ses cases, les rues passent par le coude). La première ville fait au moins 1×2 (le labo). Les quantités de briques des villes se comptent par case (`par case` dans `ville.txt`, décor des ambiances compris), pour qu'un village ne soit pas surchargé. La CI vérifie que chaque ville a son Centre et sa boutique (et son arène), et qu'une ville à arène couvre au moins 2 cases ;
  - boucles (`Boucles`, 0 par défaut, `1..3` dans `monde.txt`) : une route de plus entre deux zones de la chaîne (villes ou routes droites, au plus `EXTRA_REACH` cases l'une de l'autre) sans ville à arène entre elles, ouverte dès le début. Une route ajoutée peut faire jusqu'à `EXTRA_REACH` (6) cases de long, pour contourner la chaîne ; une ville n'a jamais plus de sorties que de cases (un village n'en reçoit pas) ;
  - raccourcis (`Raccourcis`, 0 par défaut, `1..3` dans `monde.txt`) : une route entre deux zones plus éloignées, fermée près de son bout le plus proche du départ par un obstacle (`LOCKS`) : une bande de rochers avec un couloir d'une case où se tient un arbre à couper (Machette), un rocher fissuré (Pioche) ou un rocher à pousser (Harnais), une paroi sans passage à franchir au Grappin, ou une bande d'eau à surfer. L'objet qui l'ouvre s'obtient au plus tôt dans la dernière ville à arène avant son autre bout : un raccourci ne fait jamais sauter d'arène. Chaque route ajoutée a un palier, la zone de la chaîne d'où on peut l'emprunter (une boucle : son bout le plus proche du départ ; un raccourci : la ville de son objet, ou son autre bout s'il vient avant) : ses rencontres (F13) et son recoin éventuel suivent ce palier. Elles ne touchent les autres zones qu'en coin (pas de raccord). Ce qui ne trouve pas de place est noté dans la console et en commentaire du monde (`# Boucle : …`, `# Raccourci : …`). La CI vérifie sur chaque graine que tout s'atteint sans les raccourcis, qu'aucune boucle n'a d'arène entre ses bouts, que l'objet d'un raccourci vient au plus tôt à la dernière arène avant son autre bout, et que l'obstacle ferme bien la route (et s'ouvre avec son objet) ;
  - au plus une arène par ville, jamais dans la ville de départ ;
  - la ville où l'on obtient Surf est tirée parmi les villes à arène, à partir de la 2e arène au minimum (`Surf`) ;
  - un chenal ou un lac ne barre une route qu'après cette ville ;
  - une route peut être barrée par un mur de rochers, avec une entrée de grotte de chaque côté ;
  - des routes de montagne (`Montagnes`) se découpent en niveaux séparés par des falaises ou des rebords, que l'on passe par des escaliers ; les sorties et l'eau restent au sol. Autant de niveaux que `Relief` a de symboles (6 dans `route.txt` : `^ & k K m M`, chaque niveau son symbole pour que ses bords se voient ; les niveaux impairs ont les bords du niveau 1, les pairs ceux du niveau 2). Une route nord-sud a 5 à 8 frontières de niveau (`MOUNTAIN_FACES`), la suivante monte 7 fois sur 10 (`MOUNTAIN_CLIMB`) ; une montagne colossale en a autant que la route en tient. Les bords ondulent d'une ou deux cases (`FACE_WAVE`), à plat là où un chemin les traverse (l'escalier) ; une bande garde au moins 3 rangées (`BAND_MIN`). Une falaise = toute case d'un niveau qui touche (8 voisins) une case plus basse ; un tirage de niveaux qui coupe une sortie d'une autre est rejeté. Des hautes herbes (`HerbeHaute = n`, roche + T6) poussent en taches sur les niveaux (`MOUNTAIN_GRASS`, rencontres sauvages comprises). Les buttes (`rocaille`) se dressent un niveau au-dessus de celui où elles sont posées. Une route de montagne peut aussi être coupée par un chenal ou un lac, ou, si elle va du nord au sud sans être coupée, être longée par une rivière au pied des falaises, en parallèle du chemin (`RiviereMontagne`, en %). Elle a une grotte en cul-de-sac selon `GrotteMontagne` (en %), ouverte au pied d'une falaise quand une place s'y prête. Sur les niveaux ne se posent que des rochers et des buttes (briques `rocaille`) ;
  - la ville où l'on obtient Plongée est tirée parmi les villes à arène, à partir de la 3e arène au minimum (`Plongee`) et toujours après la ville de Surf, car il faut Surf pour plonger ;
  - une zone sous-marine (`Fonds`) n'apparaît que sur une route d'eau située après la ville de Plongée : la route reçoit une tache d'eau profonde, et sa carte de fonds (tileset Underwater) est reliée par `DiveMap`.
  - démesure (`Demesure`, en % par lieu, 25 par défaut) : de temps en temps un lieu est hors norme. Routes : forêt profonde (arbres serrés partout), mer d'herbes (hautes herbes sur toute la route, chemin compris), chaos rocheux (montagnes soudées en crêtes), lac géant (l'eau envahit la route, le chemin reste au sec), montagne colossale (autant de niveaux que la route en tient, routes de montagne seulement), route interminable (trois fois la longueur maximale). Villes : ville-jardin (tapis de fleurs, arbres partout, rues en terre), cité lacustre (la ville bâtie sur l'eau), grande foire. Hors de la chaîne aussi : une île prend un excès de ville (village) ou de route (île sauvage, sans route interminable ni montagne colossale) ; une grotte peut être une grotte immense ou un dédale (presque que des couloirs) (voir Grottes) ; des fonds peuvent être un abysse (le fond s'ouvre bien plus loin autour de l'eau profonde) ou une forêt d'algues. Les excès ne touchent que les briques facultatives et la place libre : le chemin, les portes et les sorties restent toujours praticables, et un lac géant n'oblige jamais à surfer. Le monde note chaque excès en commentaire (`# Démesure : …`), îles, grottes et fonds compris. Les excès se règlent dans `EXCESSES` (`001_Settings.rb`).
  - villes portuaires (`Ports`, 0 par défaut, `1..2` dans `monde.txt`) : la mer occupe un côté sans sortie, un quai en bois longe l'eau sur toute la largeur, derrière une promenade pavée reliée à la place ; 2 à 4 pontons avancent dans la mer, et une gare maritime sur pilotis (on y entre par le haut, depuis le ponton) se tient au bout de l'un d'eux, mer au sud, ou accrochée sous un ponton, mer à l'est ou à l'ouest. Des entrepôts (briques `port`) se posent le long de la promenade. Une ville nommée Port, Dock ou Harbour (`Noms`) est toujours un port, en plus des villes tirées. Le côté de la mer est tiré parmi ceux sans sortie qui laissent assez de place aux rues des côtés voisins ; la mer au nord seulement faute d'autre côté, et alors sans gare maritime (elle ferait face à la terre). Dans un port, les briques de décor (arbres, parcs) qui ne tiennent plus sont laissées de côté. Le monde note chaque port en commentaire (`# Port : …`). Hors monde, `Port = est` dans `ville.txt` fait un port.
  - îles (`Iles`, en % par port, 0 par défaut, 50 dans `monde.txt`) : un port qui a une gare maritime (mer au sud, à l'est ou à l'ouest) peut avoir un bateau vers une île, une carte à part hors de la grille du monde. L'île est un village (Centre Pokémon, boutique, maisons) ou une île sauvage (hautes herbes, arbres, rochers, rencontres sauvages), tirée à parts égales (`ISLAND_KINDS`, `001_Settings.rb`). Une île peut avoir sa propre arène (`IlesArene`, en %, 0 par défaut, 50 dans `monde.txt`), même si son port a la sienne : l'île est alors un village, et son arène se place juste après le port dans l'ordre des arènes. Le nombre d'arènes (`Arenes`) ne change pas : une ville plus loin dans la chaîne cède la sienne (à défaut, le port), jamais la ville de Surf ou de Plongée. Si l'île ne peut pas être construite, cette ville récupère son arène. Elle est entourée d'eau, avec son propre quai, ses pontons et sa gare maritime au sud ; une fois sur deux son sol est du sable. Autour de l'île, la mer a des bancs de sable (`ISLAND_BANKS`) et des rochers (`ISLAND_REEFS`, blocs de 2×2 au moins, comme sur les cartes faites à la main) ; un bateau est amarré à côté de chaque gare maritime reliée, au port comme sur l'île. Son nom vient des noms du lore (`MapProc/Lore/noms.txt`) : « Île … » ou un nom de ville seul. Entrer dans la porte d'une gare maritime (en haut du bâtiment, depuis le ponton) fait prendre le bateau vers l'autre gare. Sur la carte de région, l'île est à la case de son port ; ses rencontres suivent le niveau de son port (ProceduralEncounters). Le monde note chaque île en commentaire (`# Île : …`).
- **Grottes (`006_Caves.rb`, `010_CavePainter.rb`) :** une grotte est deux cartes fixes (tileset Dungeon cave) : le 1er étage et le sous-sol (« Grotte générée N (sous-sol) »), reliés par une échelle. Les galeries sont creusées par MapProc sur une grille de blocs de 2×2 cases : des salles de forme ronde irrégulière reliées par des tunnels sinueux (chaque salle à la plus proche, plus quelques boucles), un seul morceau par étage, jamais deux cases reliées seulement en diagonale. Quand la carte est écrite, le générateur de donjon d'Essentials dessine les murs et les décorations autour de ces galeries (une seule fois, depuis la graine de l'étage), puis la carte est enregistrée telle quelle : plus de `Dungeon = true`, la grotte est la même à chaque visite. Une grotte qui barre une route se traverse : entrée A → 1er étage → échelle → sous-sol → entrée B. Une grotte de montagne est un cul-de-sac : entrée et échelle au 1er étage, le fond au sous-sol. Grotte immense (plus grande, salles plus vastes) et dédale (petites salles, tunnels étroits, beaucoup de boucles) se règlent dans `CAVE_SHAPES` (`001_Settings.rb`). Les rencontres couvrent les deux étages (une zone par étage). La CI fait tourner le vrai code de murs d'Essentials (lu dans `Data/Scripts.rxdata`) sur chaque étage de chaque graine.
- **Intérieurs (`011_Interiors.rb`) :** chaque porte d'un bâtiment généré (Centre, Boutique, maison, immeuble, arène, entrepôt, bâtiments spéciaux) mène à son intérieur : une copie d'une carte de la démo tirée parmi les gabarits de son type (`INTERIORS`, `001_Settings.rb` : Centres 9/24/53, Boutiques 25/54, maisons 6/8/26/27, immeubles 12/11, arène 10…), vidée de ses événements, sa sortie ramenant devant la porte. Les métadonnées viennent du gabarit (fond de combat…), avec le nom du lieu ; le Centre Pokémon porte le point de soin de sa ville (`HealingSpot`, utilisé par Téléport ; le retour après un K.O. viendra de l'infirmière posée par MapEvents). Les intérieurs s'appellent « Ville générée 3 - maison 2 » dans l'arbre des cartes (sous leur lieu), sont supprimés et redessinés avec le monde, et entrent dans l'inventaire (`kind: "interieur"`, type de bâtiment, gabarit, sortie ; chaque porte du lieu nomme son intérieur). Les grottes, la gare maritime et les escaliers de montagne gardent leur propre passage (`NO_INTERIOR`). La CI vérifie que chaque type de bâtiment à porte a un gabarit, que la sortie de chaque gabarit est bien là où `INTERIORS` le dit, et que chaque porte mène à son intérieur.
- **Labo du Professeur :** la ville de départ reçoit le labo du Professeur Castellane (brique `labo`, objet `L = T3088 8x5` de `ville.txt`, le bâtiment de Lappet Town en entier), dont l'intérieur est le labo de la démo (carte 4). S'il ne tient pas, la ville est refaite sans labo et l'inventaire marque `professor` : la case libre au bord d'une rue la plus proche du Centre, où le professeur attendra dehors. L'inventaire dit `lab` (la ville de départ si elle a son labo). La CI vérifie qu'il y a toujours l'un ou l'autre, jamais les deux.
- **Route Victoire et Ligue :** chaque monde finit, après sa dernière ville, par la Route Victoire (« Route générée N », une route de montagne nord-sud de la plus grande `Longueur`, avec sa grotte, « Grotte Victoire ») puis le plateau de la Ligue (« Plateau généré », une ville de la taille des autres, avec seulement un Centre, le bâtiment de la Ligue, des lampes, des arbres et parfois un parc : `PLATEAU_BRICKS`). Ils sont tirés après les arènes, Surf, Plongée, les ports et les démesures, qui ne les touchent jamais ; leurs noms affichés sont fixes (`VICTORY_ROAD`, `VICTORY_CAVE`, `PLATEAU`). Le bâtiment de la Ligue (brique `ligue`, objet `I = T3136 8x5` de `ville.txt`, celui du Plateau Indigo de la démo) mène à ses salles, l'une après l'autre (`LEAGUE_ROOMS`) : entrée (carte 36, sa sortie ramène dehors), Ancien 1 à 4, Parrain, Arceus (carte 37 chacune) puis Panthéon (carte 38). Chaque salle n'a que sa porte vers la suivante, sans retour. L'inventaire dit `victory` (la Route Victoire) et `league` (les salles dans l'ordre), et chaque salle a son rôle (`role`), son arrivée (`arrival`) et sa porte vers la suivante (`onward`). La CI vérifie sur chaque graine que la chaîne finit par la Route Victoire (montagne, grotte) et le plateau, et que les salles s'enchaînent dans l'ordre.
- **Objets de terrain et recoins (`012_Nooks.rb`) :** chaque objet de terrain (F12) s'obtient dans une ville à arène : celle de la n-ième arène ou la suivante, n réglable dans `monde.txt` (`Machette = 1`, `Lanterne = 2`, `Pioche = 3`, `Harnais = 4`, `Grappin = 5`, `Vol = 6`, valeurs par défaut dans `FIELD_ITEMS`), tirées dans l'ordre de ces numéros (jamais un objet avant un objet de numéro plus petit) ; Surf et Plongée gardent leurs clés. Chaque lieu de la chaîne a `Recoins` % de chances (30 dans `monde.txt`) d'avoir un recoin facultatif, fermé par un obstacle qu'ouvre un objet obtenu dans une ville plus tôt dans la chaîne (`NOOKS`) : arbre à couper (Machette), rocher fissuré (Pioche) ou rocher à pousser (Harnais) à l'entrée d'une poche creusée dans la roche (3 cases de large, pour contourner le rocher poussé), îlot dans un étang (Surf), grotte sombre en cul-de-sac (Lanterne, routes seulement : une carte d'un étage, `DarkMap = true`, le butin au fond). Le recoin se pose après les bâtiments, avant le décor ; s'il ne tient pas, le lieu n'en a pas. Les obstacles sont copiés des événements de la démo (`NOOK_EVENTS` : arbre et rocher de la Route 3, rocher à pousser de la Grotte de glace), nommés `MapProc CutTree`… et remplacés à chaque génération. L'inventaire dit `items` (objet → ville, Surf et Plongée compris) et, par lieu, `nooks` : `[x, y, obstacle, ox, oy]` (case du butin, case de l'obstacle ; pour une grotte sombre, son entrée, le butin étant `loot` de la grotte). Le butin lui-même sera posé par MapEvents. La CI vérifie sur chaque graine l'ordre des villes d'obtention, qu'un recoin vient après la ville de son objet, que son butin est inaccessible sans l'obstacle (ou sans Surf) et accessible avec, et que chaque grotte sombre ramène devant son entrée. Grappin : la poche est fermée par une paroi de roche sans passage ; un événement invisible sur chacune de ses faces (`MapProc Grapple`, `pbMapProcGrapple`) fait sauter le joueur par-dessus avec le Grappin (le même obstacle ferme certains raccourcis) ; l'entrée de l'inventaire a alors la case de l'autre face (`[x, y, "grappin", ox, oy, fx, fy]`). Cascade reportée : pas de tuiles de cascade.
- Une zone sous-marine est une carte à part, de la taille de la route : on y plonge depuis l'eau profonde, on remonte là où l'eau au-dessus est profonde.
- Si les briques d'un lieu ne tiennent pas (route étroite coupée par l'eau ou les rochers, port refait sans son île), le lieu est retiré avec une graine dérivée de la sienne ; après 4 essais, tout le monde est retracé (jusqu'à `WORLD_TRIES` fois), plus loin dans les tirages de la graine : le monde reste le même pour une même graine.
- Lancement : menu debug > Autres éditeurs > « Générer un lieu (MapProc) ». Les raccords, les métadonnées, la carte de région et les points de vol sont écrits par MapGen.
- **Nouvelle partie :** chaque nouvelle partie tire un monde (`NEW_GAME_WORLD`, `monde.txt` par défaut, `nil` = désactivé) avec une graine au hasard. Les cartes sont générées avec leurs événements (WorldEvents, F15) ; les rencontres sauvages sont écrites par ProceduralEncounters (F13). La partie commence directement dans la première ville du monde, devant le Centre Pokémon (sinon devant la première porte) : l'intro de l'éditeur (carte 1) est sautée, le joueur choisit seulement son nom (`pbTrainerName`, personnage 1). Sans monde (`NEW_GAME_WORLD = nil` ou génération ratée), l'intro d'origine se joue. Aucun message au joueur : la graine, Surf et Plongée sont écrits dans la console. La graine est gardée dans la sauvegarde.
- **Génération pendant l'intro :** le tirage du monde (le calcul en Ruby pur de `generate_world`, `compute_world`) tourne dans un thread de basse priorité (`WORLD_THREAD_PRIORITY`, tranches de temps courtes pour garder la fluidité de l'intro) pendant que l'intro (IntroScene, F14) se joue. La partie démarre sur la carte de départ de l'éditeur, puis, avant que la première carte s'affiche (`Scene_Map#main`), les cartes sont écrites et le joueur est déplacé au départ du monde (nouvelle `PokemonMapFactory`, `moveto`, rencontres, musique de la carte). L'écran « Le monde se prépare... » ne reste que le temps d'écrire les cartes, plus la fin du calcul s'il n'est pas fini. Même graine, même monde qu'avant. Si le thread échoue, le monde est tiré à ce moment-là, comme avant (message dans la console).
- **Partie non sauvegardée :** à la fermeture du jeu (`at_exit`), si aucune sauvegarde ne contient de monde, les fichiers `Data/MapXXX.rxdata` du monde et leurs entrées dans l'arbre des cartes sont supprimés tout de suite (sans compilateur, la fenêtre n'existe plus). Le reste est fait au lancement suivant (écran de chargement), où les cartes sur le disque sont remises d'accord avec la sauvegarde :
  - pas de sauvegarde (ou une sauvegarde sans monde) : les cartes du monde sont supprimées (`Data/MapXXX.rxdata`, arbre des cartes, raccords, métadonnées, points de la carte de région, graines des grottes) la région de `town_map.txt` et son image (`typelocked_proc.png`) sont remises comme avant le premier monde, les plans exportés de ce monde (`MapProc/Export/monde_<graine>.txt` et ses rencontres) supprimés ;
  - sauvegarde d'un autre monde : ce monde est redessiné depuis sa graine (mêmes numéros de carte), les cartes en trop et les plans exportés du monde abandonné sont supprimés.
- **Noms de lieux :** avec `Toponymie = Lore/noms.txt` dans `monde.txt`, les noms affichés en jeu (panneau d'entrée, Carte de la région, métadonnées) sont tirés avec la graine dans `MapProc/Lore/noms.txt` (voir `docs/LORE.md`) : la première ville et les villes sans arène sont des villages (Bourg Lucca, Beaumont County), les villes portuaires et les cités lacustres des ports (Port Hudson, Salerno Dock), les autres des villes (Morettiville, Caruso City) ; les routes sont numérotées (Route 1), les grottes nommées (Grotte Rossini, Hudson Cave), la région aussi (Omerta...). Langue du nom de base tirée à parts égales, jamais deux fois le même nom. Les cartes gardent leur nom généré dans l'arbre des cartes (« Ville générée 3 »), pour que les numéros de carte restent les mêmes d'un monde à l'autre ; le nom affiché passe par l'option `nom=` de `[Places]` (MapGen). Les tirages ont leur propre graine : le reste du monde ne change pas.
- **Inventaire (`009_Atlas.rb`) :** chaque monde garde, pour chaque carte, ses emplacements : sorties, portes avec leur type de bâtiment, cases libres au bord des rues, hautes herbes, culs-de-sac (toutes accessibles à pied depuis une sortie ou une porte), et pour le monde entier la ville de départ, l'ordre des arènes (l'arène d'une île juste après son port), les villes de Surf et de Plongée. Sauvegardé avec les cartes dans `Data/MapProcAtlas.rxdata` (par numéro de carte), exporté en texte dans `MapProc/Export/monde_<graine>_inventaire.txt`. En jeu : `MapProceduralGenerator.spots(map_id)` (nil hors du monde généré) et `MapProceduralGenerator.atlas`. La CI vérifie sur chaque graine que les portes sont celles des briques, que les autres cases sont praticables, et que la même graine donne le même inventaire.
- **Rives :** l'autotile de mer (A1) ne dessine pas son bord du bas. La rangée sous chaque eau prend donc une tuile de rive (`Rive = !'?` dans le lieu : bout gauche, milieu, bout droit), sur l'herbe (T848 à T850), le sable (T832 à T834) ou la terre battue (T840 à T842) selon l'ambiance (`Rive` d'une ambiance ; prairie et minérale gardent la rive d'herbe). Cette rangée reste libre (pas de rue, de brique ni d'arbre de bordure) ; une brique d'eau ne se pose pas au-dessus d'une rue en ville. L'eau trop fine (hors de tout bloc 2x2, le bord de carte compte comme de l'eau) est retirée. La CI refuse toute eau sans rive, eau, relief ou bord de carte dessous, et toute eau trop fine.
- Pendant la génération ou la suppression, un écran noir affiche « Le monde se prépare... ». Les fichiers PBS réécrits sont ensuite datés juste avant leurs données compilées, pour qu'Essentials ne recompile pas tout au lancement suivant.
- Générer le même monde depuis le menu debug le détache de la partie : il n'est plus jamais supprimé ni redessiné tout seul.

### Points d'accroche Essentials (alias, aucun script de base modifié)

- `RandomDungeon::Dungeon` : sous-classe `MapProceduralGenerator::CaveDungeon` (redéfinit `generate` et `generate_layout`), utilisée seulement à l'écriture des cartes.
- `Game.start_new` (alias `__mapproc_start_new`) : lance le tirage du monde dans un thread ; la graine va dans `$mapproc_world` (`SaveData.register(:mapproc_world)`) une fois le monde écrit.
- `Scene_Map#main` (alias `__mapproc_main`) : écrit le monde et déplace le joueur à son départ avant que la carte se dessine ; `Scene_Map#update` (alias `__mapproc_update`) pour la saisie du nom (sans IntroScene), une fois la carte affichée.
- `PokemonLoadScreen#initialize` (alias `__mapproc_initialize`) : compare la graine de la sauvegarde au monde du disque (`Data/MapProcWorld.rxdata`), supprime ou redessine.

### À vérifier au premier lancement

- Entrer dans une grotte par chaque entrée, prendre l'échelle dans les deux sens, ressortir par l'autre entrée : arrivée devant la sortie ou l'échelle, murs bien dessinés (pas de trou noir ni de mur flottant).
- Les anciennes grottes d'un monde déjà sur le disque sont réécrites à la prochaine génération (`Data/MapProcCaves.rxdata` n'est plus utilisé, il peut être supprimé).
- Entrer dans chaque type de bâtiment et en ressortir : arrivée sur le paillasson, retour devant la porte.
- Recoins : couper l'arbre, briser le rocher, pousser le rocher (puis le contourner), surfer jusqu'à l'îlot, entrer dans une grotte sombre avec et sans la Lanterne. Après une nouvelle génération, pas d'ancien obstacle resté sur la carte.
- Grappin (recoin ou raccourci) : face à la paroi, sans le Grappin un message ; avec, le joueur saute par-dessus, dans les deux sens.
- Raccourcis : l'obstacle bloque bien toute la largeur de la route (pas de passage par la bordure) ; le rocher poussé dans le couloir ressort de l'autre côté sans bloquer le chemin.
- Routes en L et en U, villes en L, routes larges : pas de trou dans la bordure, rues qui passent par les coudes, carte de région qui suit le tracé.
- Traverser la Ligue : entrée, porte du haut, chaque salle jusqu'au Panthéon (arrivée en bas de chaque salle, face au nord). Les dresseurs (Anciens, Parrain, Arceus) viendront de MapEvents.
- Rives : sous un lac, une rivière, la mer d'un port ou d'une île, le bas de l'eau montre son rebord ; on marche sur la rive mais on ne remonte pas dans l'eau sans Surf.
- Prendre le bateau dans les deux sens : arrivée sur le ponton devant la gare, face au nord ; non vérifié en jeu.
- Plonger sur l'eau profonde d'une route, remonter : il faut aussi le badge `Settings::BADGE_FOR_DIVE` et un Pokémon qui connaît Plongée.
- Nouvelle partie : l'intro s'affiche tout de suite et reste fluide pendant le tirage (environ 6 s hors jeu pour `monde.txt`) ; à la fin de l'intro, l'écran « Le monde se prépare... » ne dure que l'écriture des cartes ; on arrive devant le Centre de la première ville, avec sa musique. Si le moteur refuse les threads, le tirage se fait à la fin de l'intro (message dans la console). Puis quitter sans sauvegarder et relancer : plus de « Ville générée » dans l'arbre des cartes.
- Sauvegarder, lancer une nouvelle partie, quitter sans sauvegarder, relancer puis Continuer : on retrouve son monde, au même endroit.
- Jouer depuis RPG Maker XP (test) : l'éditeur ne voit pas les cartes écrites par le jeu, ne pas enregistrer le projet après (il écraserait `MapInfos.rxdata`).

### Limites connues

- Pas encore de dresseurs ni d'objets ; les intérieurs n'ont aucun personnage (infirmière, vendeur : à poser par MapEvents). Les rencontres sauvages sont écrites par ProceduralEncounters (F13).
- L'obtention de Surf et de Plongée elle-même n'est pas encore placée : seule la ville est tirée.
- Le bateau est un simple transfert quand on entre dans la gare maritime : pas encore de marin ni de question « Embarquer ? ». Une gare d'un port au nord, ou d'un port sans île, n'a pas d'événement.

## F08. Choix de mode en début de partie (NewGameSetup)
**Statut :** v1.0.0, écrit, **non testé**.
**Version cible :** Essentials v21.1.
**Dossier :** `Plugins/NewGameSetup/`

### Règles
- Affiche les fenêtres de choix de mode inscrites par les autres plugins, dans l'ordre (Nuzlocke = 10, puis Monotype = 20), au premier pas du joueur ou juste avant le premier Pokémon reçu.
- Chaque mode reste indépendant : sans le Monotype, le choix Nuzlocke s'affiche quand même, et inversement.
- Plus rien ne s'affiche une fois que le joueur a un Pokémon ou que les choix sont faits.

### Fichiers
| Fichier | Rôle |
|---|---|
| `meta.txt` | Déclaration du plugin. Nuzlocke et Monotype ont `Requires = NewGameSetup`. |
| `001_Setup.rb` | `NewGameSetup.add(clé, ordre) { ... }`, déclencheurs du début de partie. |

### Intégration
- Nouveau mode : `NewGameSetup.add(:mon_mode, 30) { MonMode.setup_dialog }`, le bloc doit sortir tout de suite si le choix est déjà fait.

### Points d'accroche Essentials (alias, aucun script de base modifié)
`pbAddPokemon/pbAddPokemonSilent/pbAddToParty/pbAddToPartySilent/pbAddForeignPokemon`, handler `:on_player_step_taken`.

### À vérifier au premier lancement
- Nouvelle partie avec les deux modes : Nuzlocke puis Monotype, une seule fois.
- Sans le dossier `Plugins/Monotype/` : le choix Nuzlocke s'affiche quand même.
- Sauvegarde existante dont les choix sont faits : aucune fenêtre.

## F09. Multi Exp permanent (ExpAll)
**Statut :** v1.0.0, écrit, **non testé**.
**Version cible :** Essentials v21.1.
**Dossier :** `Plugins/ExpAll/`

### Règles
- Le Multi Exp est actif dès le début de la partie et ne se désactive pas (issue #30).
- Comportement des jeux récents (Gen 6+) : les Pokémon qui ont combattu gagnent toute leur part, ceux de l'équipe qui n'ont pas combattu gagnent la moitié. Les Pokémon K.O. ne gagnent rien. Les EV sont donnés à toute l'équipe.

### Fichiers
| Fichier | Rôle |
|---|---|
| `meta.txt` | Déclaration du plugin. |
| `001_ExpAll.rb` | `ExpAll::ALWAYS_ON` et redéfinition de `Player#has_exp_all`. |

### Points d'accroche Essentials (alias, aucun script de base modifié)
`Player#has_exp_all`, lu par `Battle#pbGainExp`. Le calcul reste celui d'Essentials (`MECHANICS_GENERATION = 8`).

### Limites connues
- L'objet Multi Exp (`EXPALL`) et l'option de débogage n'ont plus d'effet tant que `ALWAYS_ON` vaut `true`.

## F10. Rythme rapide (FastPace)
**Statut :** v1.0.0, écrit, **non testé**.
**Version cible :** Essentials v21.1.
**Dossier :** `Plugins/FastPace/`

Une partie doit pouvoir se finir vite (issue #30). Tous les réglages sont dans `001_Settings.rb`.

### Règles
- **Expérience ×4** (`EXP_MULTIPLIER`) : toute l'expérience gagnée en combat est multipliée.
- **Chaussures de course** dès le début.
- **Déplacements plus rapides** (`MOVE_SPEEDS`) : course 0,1 s/case (Essentials : 0,125), vélo 0,05 s/case (0,1), surf 0,1 s/case (0,125). La marche reste à 0,25 s/case. Les déplacements imposés par un événement gardent leur vitesse.
- **Options par défaut d'une nouvelle partie :** course activée par défaut (maintenir Retour pour marcher) et texte rapide. Le joueur peut les changer dans les Options.

### Fichiers
| Fichier | Rôle |
|---|---|
| `meta.txt` | Déclaration du plugin. |
| `001_Settings.rb` | Tous les réglages. |
| `002_ExpMultiplier.rb` | `Pokemon#base_exp` multiplié. |
| `003_Movement.rb` | Chaussures de course, vitesses du joueur, options par défaut. |

### Points d'accroche Essentials (alias, aucun script de base modifié)
`Pokemon#base_exp` (lu uniquement par `Battle#pbGainExpOne`), `Player#has_running_shoes`, `Game_Player#set_movement_type`, `PokemonSystem#initialize`.

### Limites connues
- Les options par défaut ne s'appliquent que si aucune sauvegarde n'existe encore (Essentials garde les options d'une partie à l'autre).

## F11. Niveau maximum par sceau (LevelCap)
**Statut :** v1.0.0, écrit, **non testé**.
**Version cible :** Essentials v21.1.
**Dossier :** `Plugins/LevelCap/`

### Règles
- Le niveau maximum dépend du nombre de sceaux : c'est le niveau du Pokémon le plus fort du prochain lieutenant (avec 8 sceaux, celui du Parrain), lu dans `PBS/trainers.txt`. Les lieutenants sont listés dans l'ordre dans `LEADERS`.
- Un lieutenant pas encore défini (`nil` dans `LEADERS` ou absent de `trainers.txt`) utilise `FALLBACK_CAPS` (provisoire : champions de la démo Kanto, 14, 21, 24, 29, 43, 43, 47, 50, 63). Une valeur `nil` = pas de limite.
- Au niveau maximum, un Pokémon ne gagne plus d'expérience en combat (il gagne toujours ses EV). Un gain qui dépasserait la limite s'arrête pile au niveau maximum.
- Super Bonbon et Bonbons Exp. : refusés au niveau maximum (« X ne peut pas dépasser le niveau N pour l'instant. »), et la quantité proposée s'arrête à la limite.
- Un Pokémon déjà au-dessus de la limite (capturé, reçu) garde son niveau.

### Fichiers
| Fichier | Rôle |
|---|---|
| `meta.txt` | Déclaration du plugin. |
| `001_Settings.rb` | `LEADERS`, `FALLBACK_CAPS`, `LEVEL_ITEMS`. |
| `002_LevelCap.rb` | Calcul de la limite, limite d'expérience en combat et pour les objets. |

### Intégration
- À chaque nouveau lieutenant écrit dans `trainers.txt`, remplacer le `nil` correspondant de `LEADERS` par `[:TYPE_DE_DRESSEUR, "Nom"]`. La limite suit ensuite son équipe toute seule.

### Points d'accroche Essentials (alias, aucun script de base modifié)
`Battle#pbGainExpOne`, `Pokemon#growth_rate` (remplacé par une version plafonnée pendant le gain, Essentials fait le reste), `ItemHandlers.triggerUseOnPokemon` et `triggerUseOnPokemonMaximum`.

### Limites connues
- La Pension n'est pas limitée.

## F12. Objets de terrain (FieldItems)
**Statut :** v1.0.0, écrit, **non testé**.
**Version cible :** Essentials v21.1.
**Dossiers :** `Plugins/FieldItems/`, `PBS/items.txt`

### Règles
- Les capacités de terrain sont remplacées par des objets clés remis par des PNJ : c'est le joueur qui utilise l'objet (« Tom used Cut! »). Aucun sceau ni aucun Pokémon n'est nécessaire (indispensable avec le Monotype).
- Objets : Machette (Coupe), Pioche (Éclate-Roc), Harnais (Force), Selle de Surf (Surf), Grappin (Cascade), Scaphandre (Plongée), Selle de Vol (Vol), Lanterne (Flash).
- Hors combat, les Pokémon ne proposent plus ces capacités dans le menu de l'équipe, même s'ils les connaissent.
- Coupe, Éclate-Roc, Force, Surf, Cascade et Plongée se déclenchent devant l'obstacle, comme d'habitude. La Selle de Vol et la Lanterne s'utilisent depuis le Sac.
- Les CS n'existent plus : ces attaques s'apprennent et s'oublient comme les autres, avec les CT du jeu (CT70 Flash, CT93 Coupe, CT94 Vol, CT95 Surf, CT96 Force, CT98 Éclate-Roc, CT99 Cascade) et la nouvelle CT101 Plongée.

### Fichiers
| Fichier | Rôle |
|---|---|
| `meta.txt` | Déclaration du plugin. |
| `001_Settings.rb` | `ITEMS` : capacité de terrain → objet clé. |
| `002_FieldItems.rb` | Remplacement des capacités par les objets, utilisation depuis le Sac. |
| `PBS/items.txt` | CS01 à CS06 retirées, CT101 Plongée et les 8 objets clés ajoutés. |
| `Graphics/Items/` | Icônes des 8 objets clés (48×48), dessinées par `tools/art/field_item_icons.rb` (pixel art 24×24 doublé, contour et trois tons comme les icônes d'Essentials). Relancer `ruby tools/art/field_item_icons.rb` après une retouche. |

### Intégration
- PNJ qui remet un objet : commande Script `pbReceiveItem(:MACHETE)` dans l'événement (ou `Script = pbReceiveItem(:MACHETE)` dans un plan MapEvents). Un lieutenant peut aussi la donner après sa victoire avec `Gift = MACHETE`.

### Points d'accroche Essentials (alias, aucun script de base modifié)
`Player#get_pokemon_with_move`, `pbCheckHiddenMoveBadge` (toujours vrai), `pbHiddenMoveAnimation`, `HiddenMoveHandlers.hasHandler` (menu de l'équipe), handlers `UseFromBag` / `UseInField` des deux objets.

### Limites connues
- En mode test (lancement depuis l'éditeur), Essentials autorise déjà toutes les capacités de terrain : tester le blocage en lançant `Game.exe` directement.
- Les messages d'utilisation restent ceux d'Essentials, en anglais.
- Les obstacles sur la carte gardent les graphismes d'Essentials (`Object tree 1`, `Object rock`, `Object boulder`, copiés des événements de la démo).

## F13. Rencontres sauvages générées (ProceduralEncounters)
**Statut :** v1.3.0, écrit, testé hors jeu (CI), **non testé en jeu**.
**Version cible :** Essentials v21.1. Dépend de MapProceduralGenerator (`Requires = MapProceduralGenerator`), sans le modifier.
**Dossier :** `Plugins/ProceduralEncounters/`

### Règles
- Quand un monde MapProc est généré (menu debug ou nouvelle partie), chaque carte reçoit ses rencontres dans `PBS/encounters.txt` : `Land` s'il y a des hautes herbes, `Water` et les trois cannes s'il y a de l'eau, `Cave` pour chaque grotte. Seules les sections des cartes du monde sont remplacées (ou retirées si la carte n'a plus ni herbe, ni eau, ni grotte), puis le fichier est recompilé. Une copie est écrite dans `MapProc/Export/<monde>_<graine>_rencontres.txt`.
- Source : les 400 de `docs/roster/liste-400.csv` (types, types Monotype, force, famille) et les évolutions de `PBS/pokemon.txt` / `pokemon_forms.txt`. Modifier la liste change les rencontres à la prochaine génération du monde.
- **Pokémon du monde :** si la liste en a plus de `WORLD_SPECIES` (300), chaque graine tire des familles entières jusqu'à 300 Pokémon : d'abord au moins `TYPE_FAMILIES` (4) familles capturables par type imposé, puis au hasard. Une liste de 300 ou moins est prise entière.
- **Niveaux :** les sceaux d'une carte = les arènes avant elle dans la chaîne. Les niveaux montent du cap précédent vers 80 % de l'écart jusqu'au cap suivant (caps de LevelCap, sinon `CAPS`), en commençant à 3. Cannes : Canne -6, Super Canne -3, Méga Canne +2.
- **Boucles et raccourcis :** une route hors de la chaîne prend les sceaux et les niveaux de la zone de son palier (là où on peut l'emprunter au plus tôt). La CI (`check_encounters.rb`) le vérifie sur chaque graine.
- **Îles :** une île en bateau a ses propres rencontres, aux sceaux et aux niveaux de son port. L'arène d'une île compte à la place de son port pour les sceaux des lieux suivants.
- **Biomes :** ville, montagne, grotte, eau, sinon l'ambiance de la route (`AMBIANCE_BIOMES` : prairie, sable, terre battue = terre, minérale = minéral, automne, forêt tropicale = tropical ; verdoyante = herbe). La CI vérifie que chaque ambiance de la table existe dans `route.txt` et que son biome existe. La démesure peut le remplacer (forêt profonde et ville-jardin = forêt, mer d'herbes = prairie, chaos rocheux et montagne colossale = montagne). Chaque biome donne un poids par type (`BIOMES`) ; un Pokémon prend le meilleur de ses types. L'eau et les cannes n'ont que des Pokémon de type Eau, la Canne seulement des faibles non évolués.
- **Identité d'un lieu :** chaque table d'herbe ou de grotte tire 2 types dominants selon son biome (ceux du lieu précédent 4 fois moins probables, pour que deux voisins diffèrent). Les Pokémon de ces types font 60 % des rencontres.
- **Tirage :** chaque table tire 4 à 7 Pokémon (environ 60 % d'entre eux des types dominants) selon le biome, la force (faible 3, moyen 2, fort 0,5 + 0,25 par sceau), le stade (divisé par le stade) et l'usage (moins probable s'il est déjà ailleurs). Une famille n'apparaît qu'une fois par table.
- **Évolutions :** une évolution par niveau apparaît à partir de ce niveau ; par pierre, bonheur, échange… à partir de 3 sceaux (stade 2) ou 6 sceaux (stade 3).
- **Couverture Monotype :** chaque type imposé a au moins un Pokémon capturable dans un lieu du tronçon ou du tronçon précédent (herbe, grotte, ou surf une fois Surf obtenu ; les cannes ne comptent pas). Les manquants sont ajoutés au tronçon, d'abord ceux qui couvrent le plus de types d'un coup, à 5 % chacun.
- **Couverture du Pokédex :** chaque famille tirée pour le monde apparaît au moins une fois dans le monde, à 5 %.
- **Taille des tables :** 8 Pokémon en herbe, 7 en grotte, 5 en surf. La couverture remplit d'abord jusque-là, puis dépasse en dernier recours (14 / 12 / 8). Garder les 149 familles fait monter environ un tiers des tables à 10-12 Pokémon (choix assumé, plutôt que des familles absentes).
- Même graine du monde = mêmes rencontres.
- Nouvelle partie : écrites en silence (console seulement). Quand le monde d'une partie non sauvegardée est supprimé, les sections de ses cartes sont retirées ; quand celui de la sauvegarde est redessiné, ses rencontres sont réécrites.

### Fichiers
| Fichier | Rôle |
|---|---|
| `meta.txt` | Déclaration du plugin. |
| `001_Settings.rb` | Fichiers lus, tuiles d'herbe et d'eau, `BIOMES`, `TABLES`, types dominants, couverture, niveaux, poids. |
| `002_Species.rb` | Lecture de la liste des 400 et des évolutions (niveau ou sceaux minimum), tirage des familles du monde. |
| `003_Tables.rb` | Types dominants, tirage des tables, couverture des types et des familles, pourcentages, lignes PBS. |
| `004_World.rb` | Zones d'un monde généré : sceaux, niveaux, biome, types de rencontre. |
| `005_Generate.rb` | Écriture dans `encounters.txt` et accroche à MapProc. |
| `tools/ci/check_encounters.rb` | CI : 3 graines par monde, lignes, niveaux, pourcentages, couverture. |

### Points d'accroche (alias, aucun script de base modifié)
`MapProceduralGenerator.generate_world` et `generate_world_maps` (alias `__encounters_…`), `Compiler.compile_encounters`.

### À vérifier au premier lancement
- Générer un monde, puis marcher dans les hautes herbes d'une route, pêcher et surfer dans une ville à lac, entrer dans une grotte.
- La console liste les types ou familles sans Pokémon s'il y en a (la CI vérifie qu'il n'y en a aucun sur 3 graines).

### Limites connues
- Pas de rencontres de nuit, Éclate-Roc, Poké Radar ni sous l'eau (fonds marins).
- Les évolutions de Galar (Perrserker, Obstagoon, Cursola, M. Glaquette…) sont tirées comme les autres, mais leur pré-évolution sauvage reste la forme normale.
- Ajouter un biome (ambiance, démesure) demande de compléter `BIOMES`, `AMBIANCE_BIOMES` ou `EXCESS_BIOMES` dans ce plugin.

## F14. Intro du professeur (IntroScene)
**Statut :** v1.0.0, écrit, testé en jeu par le joueur.
**Version cible :** Essentials v21.1.
**Dossier :** `Plugins/IntroScene/`

### Règles
- **Quand :** une nouvelle partie dans un monde généré (F07), avant que la première ville apparaisse. Elle remplace la simple saisie du nom de MapProc. Sans monde généré, l'intro de la carte de départ de l'éditeur reste celle d'Essentials. Pendant l'intro, MapProc tire le monde en arrière-plan (F07, « Génération pendant l'intro ») ; ses cartes sont écrites juste après.
- **Déroulé :** le Professeur Castellane, affiché sur le fond d'intro, raconte le Pacte dans sa version flatteuse (4 bulles). Le joueur choisit son personnage (Garçon : Red, Fille : Leaf), puis son nom. Viennent ensuite les choix de mode de NewGameSetup (Nuzlocke, difficulté Monotype) en fenêtres neutres. Le professeur annonce enfin le type imposé (« Le Pacte a parlé : type X »), à la place du message « Le hasard a choisi » du Monotype, puis fondu sur la ville.
- **Pas de bouton pour passer l'intro** (texte court).

### Fichiers
| Fichier | Rôle |
|---|---|
| `meta.txt` | Déclaration du plugin (requiert MapProceduralGenerator, Monotype, NewGameSetup). |
| `001_Settings.rb` | `BACKGROUND`, `PROFESSOR` (images de `Graphics/Pictures`), `CHARACTERS` (personnages jouables de `PBS/metadata.txt`), `PICTURE_BASELINE`, `FADE_TIME`. |
| `002_Scene.rb` | La scène (images, textes, choix du personnage et du nom) et son lancement en fin de `Game.start_new`. |

### Points d'accroche Essentials (alias, aucun script de base modifié)
`Game.start_new` (après l'alias de MapProc, d'où le `Requires`). Pendant l'intro, `$scene` vaut `nil` pour que les messages ne mettent pas à jour la carte, dont les sprites n'existent pas encore. Côté Monotype : `Monotype.quiet_draw { ... }` masque le message du tirage.

### À vérifier au premier lancement
- Le professeur, puis Red et Leaf, s'affichent bien au-dessus de la fenêtre de message.
- Après le fondu, la ville apparaît sans nouvelle demande de nom ni nouveaux choix de mode au premier pas.
- En mode Facile, le type choisi est bien celui annoncé.

### Limites connues
- Seuls Red et Leaf ont tous leurs sprites (course, vélo, surf, pêche). Brendan et May pourront s'ajouter avec `[3]` et `[4]` dans `metadata.txt` quand leurs sprites existeront.
- `introOak` est l'image d'Essentials, à remplacer par un portrait de Castellane.

## F15. Événements des mondes générés (WorldEvents)
**Statut :** v1.0.0, écrit, **non testé en jeu**. Spec #93, ticket #94 (socle et starter).
**Version cible :** Essentials v21.1.
**Dossier :** `Plugins/WorldEvents/`

### Règles
- **Quand :** chaque fois que MapProc écrit un monde (nouvelle partie ou menu debug), ses événements sont tirés avec la même graine, à partir de l'inventaire (F07), puis placés par MapEvents (F06) sur ses cartes. Un générateur aléatoire à part : tirer les événements ne change pas le monde.
- **Plans :** les événements prennent la forme de plans MapEvents (un par carte), exportés dans `MapProc/Export/<monde>_<graine>_evenements.txt`. Copiés dans `MapEvents/`, ils se rejouent avec le placeur.
- **Professeur et starter :**
  - si la ville de départ a son labo, le Professeur Castellane s'y tient avec trois Poké Balls (`LAB_PROFESSOR`, `LAB_BALLS`). Parler au professeur ouvre le choix (interrupteur 3 « Choosing starter »), chaque Poké Ball propose un des trois starters (`Monotype.starter_ball`) et disparaît une fois prise ;
  - sinon, il attend dehors, sur la case `professor` de l'inventaire, et propose les trois starters dans une liste (`Monotype.starter_dialog`) ;
  - il ne raconte plus le Pacte, déjà dit pendant l'intro (F14).
- **Garde des sorties :** sur la rangée intérieure de chaque sortie de la ville de départ, un événement invisible renvoie le joueur d'un pas en arrière (« Tu ne peux pas partir sans Pokémon ») tant que la variable 7 (« Starter choice ») vaut 0. Le starter pris, elle vaut 1 à 3 et la garde disparaît.

### Fichiers
| Fichier | Rôle |
|---|---|
| `meta.txt` | Déclaration du plugin (requiert MapEvents, MapProceduralGenerator, ProceduralEncounters, Monotype). |
| `001_Settings.rb` | Places du professeur et des Poké Balls au labo, graphismes, interrupteur et variable du starter, textes. |
| `002_World.rb` | `WorldEvents.world_events(result, seed)` : les plans MapEvents du monde, en Ruby pur (vérifié par la CI). |
| `003_Runtime.rb` | Appelé par les événements en jeu : `professor`, `starter_ball`, `gate`. |
| `004_Write.rb` | Écriture des plans après les cartes et les rencontres, export. |

### Intégration
- Rien à faire : actif dès que MapProc génère un monde.
- CI : `tools/ci/check_world_events.rb` tire les événements de `monde.txt` sur `WORLD_SEEDS` graines (3 par défaut, `WORLD_SEEDS=20` ou `WORLD_SEEDS=6..8` en local). Elle vérifie que chaque plan se lit, qu'aucun événement n'est sur une sortie, une porte, la case devant une porte ou hors de l'inventaire, l'arrivée ou la sortie d'un intérieur, que le professeur est au labo ou dehors (jamais les deux), qu'il y a trois Poké Balls au labo, que chaque sortie de la ville de départ est gardée, et que la même graine redonne les mêmes événements.

### Points d'accroche Essentials (alias, aucun script de base modifié)
`MapProceduralGenerator.generate_world` et `generate_world_maps` (après ProceduralEncounters, d'où le `Requires`).

### À vérifier au premier lancement
- Au labo : les Poké Balls ne proposent rien avant d'avoir parlé au professeur, puis chacune propose son starter ; celle qui est prise disparaît, les autres ne donnent plus rien.
- Sans labo : le professeur dehors propose la liste des trois starters.
- Avant le starter, marcher sur une sortie de la ville de départ affiche le message et fait reculer d'un pas ; après, la sortie est libre (aussi après une sauvegarde et un rechargement).

### Limites connues
- Les textes sont encore dans `001_Settings.rb` ; ils iront dans `MapProc/Lore/dialogues.txt` (#100).

## F03. Add-ons du Deluxe Battle Kit
**Statut :** installés, **non testés**.

| Plugin | Version | Dossier | Ajout |
|---|---|---|---|
| Modular UI Scenes | 2.0.9 | `Plugins/[MUI_000] Modular UI Scenes/` | Écrans Résumé et Pokédex en pages modulaires (`UIHandlers`), couleurs des commandes du menu d'équipe. |
| [DBK] Enhanced Battle UI | 2.1.1 | `Plugins/[DBK_001] Enhanced Battle UI/` | Fenêtres d'infos sur les attaques et les combattants, menu de sélection de Ball. |
| [DBK] Animated Pokémon System | 1.1.3 | `Plugins/[DBK_009] Animated Pokemon System/` | Sprites animés, ombres, motifs de statut, Sprite Editor remanié. |

- Sprites animés (gén. 1 à 9) copiés dans `Graphics/Pokemon/` : ils remplacent les sprites de base du même nom. Les sprites des espèces de gén. 9 restent inutilisés tant que le Generation 9 Pack n'est pas installé.
- Métriques : `PBS/pokemon_metrics.txt` remplacé, plus `_female`, `_forms` et `_gmax`. `pokemon_metrics_Gen_9_Pack.txt` volontairement **non copié** : ses 127 espèces n'existent pas dans `pokemon.txt` et bloqueraient la compilation.
- Écrans Résumé et Pokédex : nouvelles images dans `Graphics/UI/Summary/` et `Graphics/UI/Pokedex/` (5 remplacées).
- Nuzlocke : la sélection de Ball de l'Enhanced Battle UI passe par `ItemHandlers.triggerCanUseInBattle`, donc les Balls restent grisées quand aucune capture n'est permise.
- Non installé : Customizable Battle UI (décision du 14/10/2026).

## Journal
| Date | Ajout | Fichiers |
|---|---|---|
| 08/10/2026 | Plugin Nuzlocke v1.0.0 | `Plugins/Nuzlocke/*` |
| 14/10/2026 | Nuzlocke v1.1.0 : shiny consomme une zone libre, morts verrouillés au PC, poison non mortel, équipe K.O. | `Plugins/Nuzlocke/*`, `docs/FEATURES.md` |
| 14/10/2026 | Deluxe Battle Kit v1.3.1 + v21.1 Hotfixes 1.0.9 ; Nuzlocke v1.1.1 : surnom conservé malgré le kit | `Plugins/[DBK_000] Deluxe Battle Kit/*`, `Plugins/v21.1 Hotfixes/*`, `Audio/`, `Graphics/`, `Plugins/Nuzlocke/004_Nicknames.rb`, `docs/FEATURES.md` |
| 14/10/2026 | Plugin MapGenerator v1.0.0 : cartes générées depuis un plan texte | `Plugins/MapGenerator/*`, `MapGen/exemple.txt`, `docs/FEATURES.md` |
| 14/10/2026 | MapGenerator v1.1.0 : objets multi-cases `[Objects]`, plan `place_ville.txt` (place de ville d'après une illustration) | `Plugins/MapGenerator/*`, `MapGen/place_ville.txt`, `docs/FEATURES.md` |
| 14/10/2026 | MapGenerator v1.2.0 : réouverture automatique de RPG Maker XP après génération | `Plugins/MapGenerator/*`, `docs/FEATURES.md` |
| 14/10/2026 | MapGenerator v1.3.0 : le symbole d'un objet couvre toute sa surface dans le plan | `Plugins/MapGenerator/*`, `MapGen/place_ville.txt`, `docs/FEATURES.md` |
| 14/10/2026 | MapGenerator v1.4.0 : grilles de calques `[Layer2]` / `[Layer3]` | `Plugins/MapGenerator/*`, `MapGen/exemple_calques.txt`, `docs/FEATURES.md` |
| 14/10/2026 | MapGenerator v1.5.0 : terrains à raccords automatiques `[Terrains]`, place de ville réécrite avec | `Plugins/MapGenerator/*`, `MapGen/place_ville.txt`, `docs/FEATURES.md` |
| 14/10/2026 | MapGenerator v1.6.0 : portes et étages `[Warps]` / `[Events]` | `Plugins/MapGenerator/*`, `MapGen/exemple_porte_*.txt`, `docs/FEATURES.md` |
| 14/10/2026 | Plugin Monotype v1.0.0 ; Nuzlocke v1.1.2 : une rencontre hors du type ne consomme pas la zone | `Plugins/Monotype/*`, `Plugins/Nuzlocke/003_Encounters.rb`, `docs/FEATURES.md` |
| 14/10/2026 | Monotype v1.1.0 : choix de mode automatiques en début de partie, starter bloqué contre les champions sans événement, Concours de Capture compté comme capture | `Plugins/Monotype/*`, `docs/FEATURES.md` |
| 14/10/2026 | Monotype v1.2.0 : la règle d'arène s'applique à tous les dresseurs des cartes d'arène | `Plugins/Monotype/*`, `docs/FEATURES.md` |
| 14/10/2026 | Monotype v1.3.0 : la règle d'arène s'applique aussi à la Ligue (Conseil 4, Maître) | `Plugins/Monotype/*`, `docs/FEATURES.md` |
| 14/10/2026 | MapGenerator v1.7.0 : plans du monde (lieux, raccords entre cartes, carte de région et son image) | `Plugins/MapGenerator/*`, `MapGen/exemple_monde.txt`, `docs/FEATURES.md` |
| 14/10/2026 | Plugin OverworldBoss v1.0.0 : Pokémon boss sur la carte (multiplicateurs de stats, talent imposé, immunités) | `Plugins/OverworldBoss/*`, `docs/FEATURES.md` |
| 15/10/2026 | Plugin MapEvents v1.0.0 : PNJ, dresseurs, champions, objets, rencontres et métadonnées de carte depuis un plan texte | `Plugins/MapEvents/*`, `MapEvents/exemple.txt`, `tools/ci/check_mapevents.rb`, `.github/workflows/ci.yml`, `README.md`, `docs/FEATURES.md` |
| 15/10/2026 | MapEvents v1.1.0 : déplacements des PNJ et dresseurs (`vers_joueur`, rondes en boucle `Route`, `Speed`, `Frequency`, `Through`) | `Plugins/MapEvents/*`, `MapEvents/exemple.txt`, `docs/FEATURES.md` |
| 15/10/2026 | Plans MapEvents sans `[Encounters]` : les rencontres restent dans `PBS/encounters.txt` | `MapEvents/exemple.txt`, `docs/FEATURES.md` |
| 15/10/2026 | Modular UI Scenes 2.0.9, Enhanced Battle UI 2.1.1, Animated Pokémon System 1.1.3 + sprites animés | `Plugins/[MUI_000]*`, `Plugins/[DBK_001]*`, `Plugins/[DBK_009]*`, `Graphics/`, `PBS/pokemon_metrics*.txt`, `docs/FEATURES.md` |
| 15/10/2026 | Plugin MapProceduralGenerator v0.2.0 (prototype) : villes, routes et monde générés, lacs, chenaux, grottes | `Plugins/MapProceduralGenerator/*`, `MapProc/*`, `tools/ci/check_mapproc.rb`, `.github/workflows/ci.yml`, `docs/FEATURES.md` |
| 16/10/2026 | Plugin NewGameSetup v1.0.0 : chaque mode inscrit son choix de début de partie ; Nuzlocke v1.2.0 et Monotype v1.4.0 découplés | `Plugins/NewGameSetup/*`, `Plugins/Nuzlocke/006_Setup.rb`, `Plugins/Monotype/003_Setup.rb`, `meta.txt` des deux, `docs/FEATURES.md` |
| 16/10/2026 | MapProceduralGenerator v0.3.0 : ambiances, des sols et des rues différents d'un lieu à l'autre | `Plugins/MapProceduralGenerator/*`, `MapProc/ville.txt`, `MapProc/route.txt`, `tools/ci/check_mapproc.rb`, `docs/FEATURES.md` |
| 16/10/2026 | MapProceduralGenerator v0.4.0 : Plongée et zones sous-marines (eau profonde sur les routes, cartes de fonds reliées par `DiveMap`) | `Plugins/MapProceduralGenerator/*`, `MapProc/route.txt`, `MapProc/monde.txt`, `tools/ci/check_mapproc.rb`, `docs/FEATURES.md` |
| 16/10/2026 | MapProceduralGenerator v0.5.0 : relief, montagnes, plateaux à escalier et corniches | `Plugins/MapProceduralGenerator/meta.txt`, `MapProc/ville.txt`, `MapProc/route.txt`, `MapProc/Briques/montagne_*.txt`, `MapProc/Briques/corniche_*.txt`, `docs/FEATURES.md` |
| 16/10/2026 | MapProceduralGenerator v0.6.0 : routes de montagne à niveaux et escaliers, avec ou sans rivière et grotte | `Plugins/MapProceduralGenerator/*`, `MapProc/route.txt`, `MapProc/monde.txt`, `MapProc/Briques/rocaille_*.txt`, `docs/FEATURES.md` |
| 16/10/2026 | MapProceduralGenerator v0.7.0 : démesure, des lieux hors norme de temps en temps (forêt profonde, lac géant, route interminable, cité lacustre…) ; rivière le long des routes de montagne | `Plugins/MapProceduralGenerator/*`, `MapProc/monde.txt`, `docs/FEATURES.md` |
| 16/10/2026 | Lore : le Pacte avec Arceus, la Famille et ses rangs, le parcours du joueur, la fin ; table des noms de lieux ; Monotype obligatoire (ADR 0001) | `docs/LORE.md`, `GLOSSARY.md`, `docs/adr/0001-monotype-obligatoire.md`, `MapProc/Lore/noms.txt`, `docs/FEATURES.md` |
| 16/10/2026 | Monotype v1.5.0 : starter à choisir chez le professeur parmi 3 Pokémon du type tirés au hasard à chaque partie (sans pseudo-légendaires), fin de la période de grâce du starter | `Plugins/Monotype/*`, `Data/Map004.rxdata`, `tools/ci/check_pbs.rb`, `docs/FEATURES.md` |
| 17/10/2026 | Plugin ProceduralEncounters v1.0.0 : rencontres sauvages des mondes MapProc générées depuis la liste des 300 (biomes, niveaux par sceau, couverture Monotype et Pokédex), contrôle CI (issue #25) | `Plugins/ProceduralEncounters/*`, `tools/ci/check_encounters.rb`, `.github/workflows/ci.yml`, `docs/FEATURES.md` |
| 17/10/2026 | MapProceduralGenerator v0.8.0 : un monde tiré à chaque nouvelle partie, supprimé (ou celui de la sauvegarde redessiné) si la partie n'est pas sauvegardée, la partie commence dans sa première ville, intro remplacée par la seule saisie du nom ; ProceduralEncounters v1.0.1 suit la nouvelle signature sans écrire de rencontres pour une nouvelle partie ; fonds sous-marins reproductibles ; correction : regénérer un monde depuis le menu debug ne bute plus sur « la carte N s'appelle déjà » ; MapGenerator v1.7.1 : génération du monde sans message | `Plugins/MapProceduralGenerator/*`, `Plugins/MapGenerator/006_World.rb`, `Plugins/MapGenerator/meta.txt`, `Plugins/ProceduralEncounters/005_Generate.rb`, `Plugins/ProceduralEncounters/meta.txt`, `.gitignore`, `docs/FEATURES.md` |
| 17/10/2026 | ProceduralEncounters v1.0.2 : rencontres écrites aussi pour le monde d'une nouvelle partie (en silence), retirées avec les cartes d'une partie non sauvegardée | `Plugins/ProceduralEncounters/005_Generate.rb`, `Plugins/ProceduralEncounters/meta.txt`, `docs/FEATURES.md` |
| 17/10/2026 | MapProceduralGenerator v0.8.1 : écran « Le monde se prépare... » pendant la génération, plus de recompilation complète au lancement suivant ; correction : écran noir après « Nouvelle partie » (la saisie du nom s'ouvrait avant l'affichage de la carte) | `Plugins/MapProceduralGenerator/005_Debug.rb`, `Plugins/MapProceduralGenerator/007_NewGame.rb`, `Plugins/MapProceduralGenerator/meta.txt`, `docs/FEATURES.md` |
| 17/10/2026 | ProceduralEncounters v1.1.0 : identité des lieux (2 types dominants à 60 %), couverture Monotype sur le tronçon et le précédent, Pokémon de couverture à 5 %, tables plus courtes, 300 Pokémon tirés par monde parmi les 400 de la liste ; « Tronçon » au glossaire | `Plugins/ProceduralEncounters/*`, `GLOSSARY.md`, `docs/FEATURES.md` |
| 18/10/2026 | MapProceduralGenerator v0.9.0 : villes portuaires (mer sur un côté, quai, pontons, gare maritime sur pilotis, entrepôts), choisies par le monde (`Ports`) ou par leur nom (Port, Dock, Harbour) ; contrôle CI d'un port sur chaque côté libre | `Plugins/MapProceduralGenerator/002_Parser.rb`, `Plugins/MapProceduralGenerator/003_Builder.rb`, `Plugins/MapProceduralGenerator/004_World.rb`, `Plugins/MapProceduralGenerator/meta.txt`, `MapProc/ville.txt`, `MapProc/monde.txt`, `MapProc/Briques/gare_maritime.txt`, `MapProc/Briques/entrepot.txt`, `tools/ci/check_mapproc.rb`, `docs/FEATURES.md` |
| 18/10/2026 | MapProceduralGenerator v0.10.0 : îles en bateau depuis les gares maritimes (`Iles`), village ou île sauvage, nommées d'après le lore ; ProceduralEncounters v1.1.1 : rencontres des îles au niveau de leur port ; contrôle CI des liaisons en bateau | `Plugins/MapProceduralGenerator/001_Settings.rb`, `Plugins/MapProceduralGenerator/002_Parser.rb`, `Plugins/MapProceduralGenerator/003_Builder.rb`, `Plugins/MapProceduralGenerator/004_World.rb`, `Plugins/MapProceduralGenerator/005_Debug.rb`, `Plugins/MapProceduralGenerator/meta.txt`, `Plugins/ProceduralEncounters/004_World.rb`, `Plugins/ProceduralEncounters/meta.txt`, `MapProc/monde.txt`, `tools/ci/check_mapproc.rb`, `docs/FEATURES.md` |
| 18/10/2026 | MapProceduralGenerator v0.10.1 : bancs de sable et rochers dans la mer autour des îles, bateau amarré près des gares maritimes reliées à une île ; rivage des îles plus large | `MapProc/ville.txt`, `Plugins/MapProceduralGenerator/001_Settings.rb`, `Plugins/MapProceduralGenerator/002_Parser.rb`, `Plugins/MapProceduralGenerator/003_Builder.rb`, `Plugins/MapProceduralGenerator/004_World.rb`, `Plugins/MapProceduralGenerator/meta.txt`, `docs/FEATURES.md` |
| 18/10/2026 | MapProceduralGenerator v0.11.0 : une île peut avoir sa propre arène, en plus de celle de son port (`IlesArene`) ; démesures pour les îles, les grottes (grotte immense, dédale) et les fonds (abysse, forêt d'algues) ; ProceduralEncounters v1.1.2 : arène d'une île comptée dans les sceaux ; contrôle CI du nombre d'arènes posées | `MapProc/monde.txt`, `PBS/dungeon_parameters.txt`, `Plugins/MapProceduralGenerator/001_Settings.rb`, `Plugins/MapProceduralGenerator/004_World.rb`, `Plugins/MapProceduralGenerator/005_Debug.rb`, `Plugins/MapProceduralGenerator/006_Caves.rb`, `Plugins/MapProceduralGenerator/meta.txt`, `Plugins/ProceduralEncounters/004_World.rb`, `Plugins/ProceduralEncounters/meta.txt`, `tools/ci/check_mapproc.rb`, `docs/FEATURES.md` |
| 18/10/2026 | MapProceduralGenerator v0.12.0 : vrais noms de lieux tirés avec la graine dans `MapProc/Lore/noms.txt` (villes, ports, villages, grottes, région ; routes numérotées) au lieu de « Ville générée 3 » ; une partie non sauvegardée efface aussi l'image de sa région et ses plans exportés ; MapGenerator v1.8.0 : option `nom=` dans `[Places]` (nom affiché, la carte garde le sien) | `Plugins/MapProceduralGenerator/*`, `Plugins/MapGenerator/006_World.rb`, `Plugins/MapGenerator/meta.txt`, `MapProc/monde.txt`, `MapProc/Lore/noms.txt`, `tools/ci/check_mapproc.rb`, `docs/LORE.md`, `docs/FEATURES.md` |
| 23/10/2026 | ProceduralEncounters v1.1.3 : suit le paramètre `computed:` de `generate_world_maps` (monde tiré pendant l'intro, #67) ; corrige « unknown keyword: :computed » après le dialogue du professeur | `Plugins/ProceduralEncounters/005_Generate.rb`, `Plugins/ProceduralEncounters/meta.txt`, `docs/FEATURES.md` |
| 23/10/2026 | MapProceduralGenerator v0.22.0 : décor propre à chaque ambiance (surcharges de palette, quantités, briques réservées `decor`), sable et minérale poussés, nouvelles ambiances automne et forêt tropicale ; ProceduralEncounters v1.2.0 : biome tiré de l'ambiance (#73, #74 à #79) | `MapProc/ville.txt`, `MapProc/route.txt`, `MapProc/Briques/*`, `Plugins/MapProceduralGenerator/002_Parser.rb`, `Plugins/MapProceduralGenerator/003_Builder.rb`, `Plugins/MapProceduralGenerator/004_World.rb`, `Plugins/ProceduralEncounters/001_Settings.rb`, `Plugins/ProceduralEncounters/004_World.rb`, `tools/ci/check_mapproc.rb`, `tools/ci/check_encounters.rb`, `docs/FEATURES.md` |
| 23/10/2026 | MapProc : jardinière des villes en tuile alignée (T997, une par case) au lieu de l'objet 2x1 coupé à mi-hauteur | `MapProc/ville.txt`, `docs/FEATURES.md` |
| 23/10/2026 | MapProc : rive sous l'eau droite d'un bout à l'autre (tuile du milieu aux deux bouts, comme la mare de Cedolan City), les coins de T848/T850 tournaient dans le mauvais sens ; idem pour le sable et la terre | `MapProc/ville.txt`, `MapProc/route.txt`, `docs/FEATURES.md` |
| 23/10/2026 | MapProceduralGenerator v0.21.1 : plus de « Errno::ENOENT … Map076.rxdata » dans la console de debug au lancement (au lancement, les cartes déjà supprimées à la fermeture ne sont plus effacées une seconde fois) | `Plugins/MapProceduralGenerator/007_NewGame.rb`, `Plugins/MapProceduralGenerator/meta.txt`, `docs/FEATURES.md` |
| 23/10/2026 | MapProceduralGenerator v0.21.2 : à la fermeture, les lignes PBS (raccords, métadonnées, points de la carte de région) des cartes supprimées partent aussi, sans changer la date des fichiers ; plus d'avertissement « Map N … was not found » en recompilant au lancement | `Plugins/MapProceduralGenerator/007_NewGame.rb`, `Plugins/MapProceduralGenerator/meta.txt`, `docs/FEATURES.md` |
| 23/10/2026 | MapProceduralGenerator v0.22.1, ProceduralEncounters v1.2.1 : hautes herbes posées sur le sol de l'ambiance (sable, terre, gravier, roche des montagnes) au lieu d'un carré vert : 5 tuiles ajoutées au tileset Outside (T124, T125, T133, T147, T148, cases barrées inutilisées), tag de terrain Herbe, comptées comme herbes par les rencontres | `Graphics/Tilesets/Outside.png`, `Data/Tilesets.rxdata`, `MapProc/route.txt`, `MapProc/ville.txt`, `Plugins/ProceduralEncounters/001_Settings.rb`, `Plugins/ProceduralEncounters/meta.txt`, `Plugins/MapProceduralGenerator/meta.txt`, `docs/FEATURES.md` |
| 23/10/2026 | Hautes herbes de la prairie (T143) et pied des herbes très hautes sur la prairie, le sable, la terre et le gravier (T151, T175, T181, T189), ajoutés au tileset Outside ; contrôle CI des moitiés de plante mis à jour | `Graphics/Tilesets/Outside.png`, `Data/Tilesets.rxdata`, `MapProc/route.txt`, `MapProc/ville.txt`, `Plugins/ProceduralEncounters/001_Settings.rb`, `tools/ci/check_mapproc.rb`, `docs/FEATURES.md` |
| 23/10/2026 | Sols d'ambiance (prairie, sable, terre, gravier) : arbres, grand pin, arbre rond, cyprès, arbrisseau, haies et buissons redessinés sur chaque sol (ombres sans vert), fleurs, rive et rue de la prairie ; 176 tuiles ajoutées sous le tileset Outside (T4016 à T4199) par `tools/art/ground_variants.py`, tables du tileset agrandies par `tools/art/tileset_tables.rb` ; jardin fleuri et massif de fleurs réservés aux ambiances herbeuses | `Graphics/Tilesets/Outside.png`, `Data/Tilesets.rxdata`, `MapProc/route.txt`, `MapProc/ville.txt`, `MapProc/Briques/maison_jardin.txt`, `MapProc/Briques/parc_fleurs.txt`, `tools/art/ground_variants.py`, `tools/art/tileset_tables.rb`, `docs/FEATURES.md` |
| 23/10/2026 | Monde non linéaire (#82) : MapGenerator v1.9.0 (masque et tracé des zones, image de région sans marge), MapProceduralGenerator v0.24.0 (monde 32x24, routes de 1 à 4 cases de long et 1 ou 2 de large, routes en L et en U, villes 1x1, 1x2, 2x2 et en L, boucles, raccourcis fermés par un obstacle, Grappin pour les raccourcis et les recoins), ProceduralEncounters v1.3.0 (rencontres au palier des routes ajoutées) ; contrôles CI (masque, villes, accessibilité sans raccourci, pas de saut d'arène, obstacles) | `MapProc/monde.txt`, `MapProc/ville.txt`, `MapProc/route.txt`, `Plugins/MapGenerator/*`, `Plugins/MapProceduralGenerator/*`, `Plugins/ProceduralEncounters/*`, `tools/ci/check_mapproc.rb`, `tools/ci/check_encounters.rb`, `docs/FEATURES.md` |
| 25/10/2026 | WorldEvents v1.0.0 (#94) : événements des mondes générés tirés avec la graine depuis l'inventaire et placés par MapEvents ; Professeur Castellane au labo (trois Poké Balls) ou dehors, sorties de la ville de départ gardées jusqu'au starter ; MapEvents v1.2.0 (clés `Trigger` et `Hide` des PNJ) ; CI `check_world_events.rb` | `Plugins/WorldEvents/*`, `Plugins/MapEvents/002_Parser.rb`, `Plugins/MapEvents/003_Events.rb`, `Plugins/MapEvents/meta.txt`, `tools/ci/check_world_events.rb`, `.github/workflows/ci.yml`, `docs/FEATURES.md` |
