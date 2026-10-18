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
**Statut :** v1.7.1, écrit, testé hors jeu sur les données du dépôt, **non testé en jeu**.
**Version cible :** Essentials v21.1.
**Dossier :** `Plugins/MapGenerator/`, plans dans `MapGen/*.txt` (exemples : `MapGen/exemple.txt`, `MapGen/exemple_calques.txt`, `MapGen/exemple_porte_dehors.txt` + `MapGen/exemple_porte_maison.txt`, `MapGen/place_ville.txt`, plan du monde `MapGen/exemple_monde.txt`).

### Fonctionnement
- Un plan texte décrit la carte : un caractère par case, une légende qui associe chaque caractère à 1 à 3 calques.
- Calques : `T<n>` = tuile n du tileset (n = ligne × 8 + colonne), `A1` à `A7` = autotile (raccords calculés automatiquement), `-` = vide, `T1|T2|T3` = variante au hasard (`Seed` pour un résultat reproductible).
- Objets multi-cases (section `[Objects]`) : `H = T400 3x4` déclare un bloc de 3×4 tuiles à partir de la tuile 400. Dans `[Map]`, le symbole couvre toute la surface de l'objet (`HHH` sur 4 lignes). Une zone plus grande contient plusieurs copies, découpées depuis le coin haut-gauche (`HHHHHH` sur 4 lignes = deux objets). Une zone incomplète provoque une erreur qui indique la case fautive. Options : `L1` à `L3` pour le calque (`L2` par défaut), `@<symbole>` pour le sol sous l'objet (sinon la clé `Ground`).
- Grilles de calques (sections `[Layer2]` et `[Layer3]`, facultatives, même taille que `[Map]`) : dessinées par-dessus `[Map]`. `.` = rien ; un symbole de `[Legend]` est posé à partir de ce calque (un symbole à 2 calques dans `[Layer2]` remplit les calques 2 et 3) ; un objet de `[Objects]` est posé sur ce calque, quel que soit son `L`.
- Terrains à raccords automatiques (section `[Terrains]`) : `P = T274 N=T266 S=T282 W=T273 E=T275 NW=T265 NE=T267 SW=T281 SE=T283 iNW=T286 iNE=T284 iSW=T270 iSE=T268` déclare la tuile intérieure, les bords, les coins et les angles rentrants (`i…`). Dans la grille, on écrit seulement `P` : chaque case reçoit la tuile qui correspond à ses voisines. Un rôle absent prend la tuile intérieure. Options : `with=D` (terrains qui se raccordent sans bord), `L1` à `L3` (calque dans `[Map]`, `L1` par défaut), `@<symbole>` (sol dessous si le calque n'est pas `L1`). Un terrain marche aussi dans `[Layer2]` / `[Layer3]`.
- Portes et étages (sections `[Warps]` et `[Events]`) : `1 = Maison 1 4,7 haut` déclare une téléportation vers la carte nommée « Maison 1 » (ou son ID), case 4,7 (comptée depuis 0), regard vers le haut (`haut`, `bas`, `gauche`, `droite`, ou direction conservée). La grille `[Events]` (même taille que `[Map]`, `.` = rien) place ces symboles. Chaque porte devient un événement « MapGen warp » (contact du joueur, commande « Téléporter le joueur ») ; Essentials le transforme en porte animée à la compilation si la case ressemble à une entrée. À chaque génération, les anciens « MapGen warp » de la carte sont remplacés. Avec « Tous », une porte vers une carte générée plus tard dans la même série est reliée après coup.
- Plan du monde (un plan qui contient la clé `World`) : décrit la région entière. `World = nom de la région`, `Region = n°` (carte de région de `town_map.txt`, 0 par défaut), `Cell = 20` (tuiles par case), `Origin = x,y` (case de la carte de région où commence le plan), `Image = monde.png` (image de la carte de région, `mapRegion<Region>.png` par défaut), `Tileset` / `Ground` (cartes créées vides). Section `[Places]` : `A = Bourg Typelock vol=12,8` associe un symbole à une carte, trouvée par son nom (`vol=x,y` = point d'arrivée de Vol, `type=ville|route|lieu` = dessin sur la carte de région, deviné sinon : « Route… » = route, avec `vol` = ville, sinon lieu). Section `[World]` : un caractère par case de la carte de région, `.` = rien, chaque lieu forme un rectangle plein. Section `[NoLinks]` (facultative) : `A B` = deux lieux qui se touchent sans être reliés.
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
**Statut :** v1.5.2, écrit, **non testé**.
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
**Statut :** v1.1.0, écrit, **non testé en jeu** (conversion testée hors jeu avec le compilateur réel d'Essentials).
**Version cible :** Essentials v21.1. Plugin séparé de MapGen (aucune dépendance obligatoire).
**Dossier :** `Plugins/MapEvents/`, plans dans `MapEvents/*.txt` (exemple : `MapEvents/exemple.txt`, sur la carte de `MapGen/exemple.txt`).

### Règles
- **Un plan par carte :** `Map = Route 1` (nom dans l'arbre des cartes, ou ID). `BGM = Route 1` (facultatif, `nom[,volume[,hauteur]]`) règle la musique de la carte.
- **Un événement par section**, placé avec `Pos = x,y` (case comptée depuis 0, comme MapGen). Le nom après le type (`[Npc A]`) est une étiquette unique dans le fichier.
- **`[Npc A]` (PNJ ou pancarte) :** `Graphic` (sans graphisme = pancarte), `Facing` (`haut`, `bas`, `gauche`, `droite`), puis des `Text` (une boîte de message chacun) et des `Script` (une ligne de script chacun, ex. `pbPokemonMart([:POKEBALL, :POTION])`), exécutés dans l'ordre du fichier.
- **Déplacements (PNJ et dresseurs) :** `Move = fixe` (par défaut), `vers_joueur` (s'approche du joueur) ou `ronde`. `Route = droite*3, attendre 60, gauche*3, regard_bas` est un trajet répété en boucle (pas : `haut`, `bas`, `gauche`, `droite`, `*n` pour répéter, `regard_<direction>`, `attendre <images>`) ; il implique `Move = ronde`, doit revenir à `Pos` et rester dans la carte (vérifié). `Speed` et `Frequency` de 1 à 6 comme dans l'éditeur, `Through = oui` pour traverser les autres. Pas de déplacement aléatoire (un PNJ ne peut pas être tenu dans une zone).
- **`[Trainer B]` (dresseur) :** `Type`, `Name`, `Battle` obligatoires ; `Sight` (portée de vue, 3 par défaut) ; `Graphic` (sinon celui du type de dresseur) ; `Facing`. Les autres clés sont les commentaires de dresseur d'Essentials : `EndBattle`, `BattleID`, `DoubleBattle` / `Continue` (`oui`/`non`), `Backdrop`, `EndIfSwitch`, `VanishIfSwitch`, `Outcome`, `RegSpeech`. Plusieurs `Battle` = revanches. L'équipe est celle de `PBS/trainers.txt`.
- **Champion d'arène :** un `[Trainer]` avec, après une victoire, `Win` (texte, codes de message acceptés comme `\me[Badge get]`), `Badge = n` (badge 1 à 8), `Gift = TM39` (objet donné), `Switch = n` (interrupteur activé). Le Monotype le reconnaît par son type `LEADER_…`.
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
**Statut :** v0.8.1, prototype écrit, **non testé en jeu**.
**Version cible :** Essentials v21.1. Dépend de MapGenerator (`Requires = MapGenerator`), sans le modifier.
**Dossier :** `Plugins/MapProceduralGenerator/`, lieux dans `MapProc/*.txt` (`ville.txt`, `route.txt`, monde `monde.txt`), briques dans `MapProc/Briques/*.txt`.

### Règles

- Une ville ou une route est assemblée à partir de briques faites main (bâtiments, herbes, décor) : chaque graine donne un résultat différent, la même graine redonne le même.
- Les herbes sont de deux sortes : les hautes herbes normales (T6) et des touffes d'herbes très hautes (T7 posé sur son pied T15, une rangée de pied sous la touffe, comme dans les cartes d'exemple d'Essentials ; on n'y court pas). La CI (`check_mapproc.rb`, `SPILL_BELOW`) refuse toute plante sur deux tuiles posée sans sa partie basse.
- Les lacs décoratifs (`lac` dans `[Briques]`) ne se posent jamais sur le passage.
- Relief : des montagnes (massifs de roche, terrain `^`) se posent sur les routes et parfois dans les villes ; certaines ont un escalier taillé dans leur face sud qui mène sur le dessus. Les routes ont aussi des corniches, que l'on saute vers le sud sans pouvoir les remonter. Ces briques ne barrent jamais le passage.
- Ambiances (`[Ambiance nom]` dans `ville.txt` et `route.txt`) : chaque lieu tire son sol et ses rues selon un poids. L'herbe reste la plus courante ; quelques villes ont des chemins de terre, un sol de prairie, de sable, minéral ou de terre battue, quelques routes un sol de prairie, de sable ou de terre battue.
- Un monde (`monde.txt`) tire une chaîne de villes reliées par des routes :
  - au plus une arène par ville, jamais dans la ville de départ ;
  - la ville où l'on obtient Surf est tirée parmi les villes à arène, à partir de la 2e arène au minimum (`Surf`) ;
  - un chenal ou un lac ne barre une route qu'après cette ville ;
  - une route peut être barrée par un mur de rochers, avec une entrée de grotte de chaque côté ;
  - des routes de montagne (`Montagnes`) se découpent en niveaux (sol, niveau 1, niveau 2) séparés par des falaises ou des rebords, que l'on passe par des escaliers ; les sorties et l'eau restent au sol. Une route de montagne peut aussi être coupée par un chenal ou un lac, ou, si elle va du nord au sud sans être coupée, être longée par une rivière au pied des falaises, en parallèle du chemin (`RiviereMontagne`, en %). Elle a une grotte en cul-de-sac selon `GrotteMontagne` (en %). Sur les niveaux ne se posent que des rochers et des buttes (briques `rocaille`) ;
  - la ville où l'on obtient Plongée est tirée parmi les villes à arène, à partir de la 3e arène au minimum (`Plongee`) et toujours après la ville de Surf, car il faut Surf pour plonger ;
  - une zone sous-marine (`Fonds`) n'apparaît que sur une route d'eau située après la ville de Plongée : la route reçoit une tache d'eau profonde, et sa carte de fonds (tileset Underwater) est reliée par `DiveMap`.
  - démesure (`Demesure`, en % par lieu, 25 par défaut) : de temps en temps un lieu est hors norme. Routes : forêt profonde (arbres serrés partout), mer d'herbes (hautes herbes sur toute la route, chemin compris), chaos rocheux (montagnes soudées en crêtes), lac géant (l'eau envahit la route, le chemin reste au sec), montagne colossale (autant de niveaux que la route en tient, routes de montagne seulement), route interminable (trois fois la longueur maximale). Villes : ville-jardin (tapis de fleurs, arbres partout, rues en terre), cité lacustre (la ville bâtie sur l'eau), grande foire. Les excès ne touchent que les briques facultatives et la place libre : le chemin, les portes et les sorties restent toujours praticables, et un lac géant n'oblige jamais à surfer. Le monde note chaque excès en commentaire (`# Démesure : …`). Les excès se règlent dans `EXCESSES` (`001_Settings.rb`).
- Une grotte est une carte à part (tileset Dungeon cave, `Dungeon = true`) : Essentials dessine son intérieur et y place les deux sorties. Elle reste la même à chaque visite pour une même graine du monde.
- Une zone sous-marine est une carte à part, de la taille de la route : on y plonge depuis l'eau profonde, on remonte là où l'eau au-dessus est profonde.
- Si les briques d'un lieu ne tiennent pas (route étroite coupée par l'eau ou les rochers), le lieu est retiré avec une graine dérivée de la sienne : le monde reste le même pour une même graine.
- Lancement : menu debug > Autres éditeurs > « Générer un lieu (MapProc) ». Les raccords, les métadonnées, la carte de région et les points de vol sont écrits par MapGen.
- **Nouvelle partie :** chaque nouvelle partie tire un monde (`NEW_GAME_WORLD`, `monde.txt` par défaut, `nil` = désactivé) avec une graine au hasard. Seules les cartes sont générées, sans événements (pas de MapEvents) ; les rencontres sauvages sont écrites par ProceduralEncounters (F13). La partie commence directement dans la première ville du monde, devant le Centre Pokémon (sinon devant la première porte) : l'intro de l'éditeur (carte 1) est sautée, le joueur choisit seulement son nom (`pbTrainerName`, personnage 1). Sans monde (`NEW_GAME_WORLD = nil` ou génération ratée), l'intro d'origine se joue. Aucun message au joueur : la graine, Surf et Plongée sont écrits dans la console. La graine est gardée dans la sauvegarde.
- **Partie non sauvegardée :** au lancement suivant du jeu (écran de chargement), les cartes sur le disque sont remises d'accord avec la sauvegarde :
  - pas de sauvegarde (ou une sauvegarde sans monde) : les cartes du monde sont supprimées (`Data/MapXXX.rxdata`, arbre des cartes, raccords, métadonnées, points de la carte de région, graines des grottes) et la région de `town_map.txt` est remise comme avant le premier monde ;
  - sauvegarde d'un autre monde : ce monde est redessiné depuis sa graine (mêmes numéros de carte), les cartes en trop du monde abandonné sont supprimées.
- Pendant la génération ou la suppression, un écran noir affiche « Le monde se prépare... ». Les fichiers PBS réécrits sont ensuite datés juste avant leurs données compilées, pour qu'Essentials ne recompile pas tout au lancement suivant.
- Générer le même monde depuis le menu debug le détache de la partie : il n'est plus jamais supprimé ni redessiné tout seul.

### Points d'accroche Essentials (alias, aucun script de base modifié)

- `Game_Map#setup` (alias `__mapproc_setup`) : avant de charger une grotte générée, fixe `$PokemonGlobal.dungeon_rng_seed` avec la graine enregistrée dans `Data/MapProcCaves.rxdata`.
- `Game.start_new` (alias `__mapproc_start_new`) : tire le monde avant le début de la partie, la graine va dans `$mapproc_world` (`SaveData.register(:mapproc_world)`).
- `Game.start_new` : `$data_system.start_map_id` / `start_x` / `start_y` remplacés le temps de l'appel par la première ville ; `Scene_Map#update` (alias `__mapproc_update`) pour la saisie du nom, une fois la carte affichée.
- `PokemonLoadScreen#initialize` (alias `__mapproc_initialize`) : compare la graine de la sauvegarde au monde du disque (`Data/MapProcWorld.rxdata`), supprime ou redessine.

### À vérifier au premier lancement

- Entrer dans une grotte par chaque entrée, en ressortir, y revenir : la grotte doit être identique.
- Sauvegarder dans une grotte puis recharger : non vérifié.
- Plonger sur l'eau profonde d'une route, remonter : il faut aussi le badge `Settings::BADGE_FOR_DIVE` et un Pokémon qui connaît Plongée.
- Nouvelle partie : durée de la génération (environ 6 s hors jeu pour `monde.txt`, écran noir pendant ce temps), puis quitter sans sauvegarder et relancer : plus de « Ville générée » dans l'arbre des cartes.
- Sauvegarder, lancer une nouvelle partie, quitter sans sauvegarder, relancer puis Continuer : on retrouve son monde, au même endroit.
- Jouer depuis RPG Maker XP (test) : l'éditeur ne voit pas les cartes écrites par le jeu, ne pas enregistrer le projet après (il écraserait `MapInfos.rxdata`).

### Limites connues

- Pas encore de dresseurs, d'objets ni d'intérieurs derrière les portes. Les rencontres sauvages sont écrites par ProceduralEncounters (F13).
- L'obtention de Surf et de Plongée elle-même n'est pas encore placée : seule la ville est tirée.

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

### Intégration
- PNJ qui remet un objet : commande Script `pbReceiveItem(:MACHETE)` dans l'événement (ou `Script = pbReceiveItem(:MACHETE)` dans un plan MapEvents). Un lieutenant peut aussi la donner après sa victoire avec `Gift = MACHETE`.

### Points d'accroche Essentials (alias, aucun script de base modifié)
`Player#get_pokemon_with_move`, `pbCheckHiddenMoveBadge` (toujours vrai), `pbHiddenMoveAnimation`, `HiddenMoveHandlers.hasHandler` (menu de l'équipe), handlers `UseFromBag` / `UseInField` des deux objets.

### Limites connues
- En mode test (lancement depuis l'éditeur), Essentials autorise déjà toutes les capacités de terrain : tester le blocage en lançant `Game.exe` directement.
- Les messages d'utilisation restent ceux d'Essentials, en anglais.

## F13. Rencontres sauvages générées (ProceduralEncounters)
**Statut :** v1.1.0, écrit, testé hors jeu (CI), **non testé en jeu**.
**Version cible :** Essentials v21.1. Dépend de MapProceduralGenerator (`Requires = MapProceduralGenerator`), sans le modifier.
**Dossier :** `Plugins/ProceduralEncounters/`

### Règles
- Quand un monde MapProc est généré (menu debug ou nouvelle partie), chaque carte reçoit ses rencontres dans `PBS/encounters.txt` : `Land` s'il y a des hautes herbes, `Water` et les trois cannes s'il y a de l'eau, `Cave` pour chaque grotte. Seules les sections des cartes du monde sont remplacées (ou retirées si la carte n'a plus ni herbe, ni eau, ni grotte), puis le fichier est recompilé. Une copie est écrite dans `MapProc/Export/<monde>_<graine>_rencontres.txt`.
- Source : les 400 de `docs/roster/liste-400.csv` (types, types Monotype, force, famille) et les évolutions de `PBS/pokemon.txt` / `pokemon_forms.txt`. Modifier la liste change les rencontres à la prochaine génération du monde.
- **Pokémon du monde :** si la liste en a plus de `WORLD_SPECIES` (300), chaque graine tire des familles entières jusqu'à 300 Pokémon : d'abord au moins `TYPE_FAMILIES` (4) familles capturables par type imposé, puis au hasard. Une liste de 300 ou moins est prise entière.
- **Niveaux :** les sceaux d'une carte = les arènes avant elle dans la chaîne. Les niveaux montent du cap précédent vers 80 % de l'écart jusqu'au cap suivant (caps de LevelCap, sinon `CAPS`), en commençant à 3. Cannes : Canne -6, Super Canne -3, Méga Canne +2.
- **Biomes :** ville, montagne, grotte, eau, sinon le sol de la route (herbe, prairie, sable, terre battue). La démesure peut le remplacer (forêt profonde et ville-jardin = forêt, mer d'herbes = prairie, chaos rocheux et montagne colossale = montagne). Chaque biome donne un poids par type (`BIOMES`) ; un Pokémon prend le meilleur de ses types. L'eau et les cannes n'ont que des Pokémon de type Eau, la Canne seulement des faibles non évolués.
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
- Ajouter un biome (sol, démesure) demande de compléter `BIOMES`, `GROUND_BIOMES` ou `EXCESS_BIOMES` dans ce plugin.

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
