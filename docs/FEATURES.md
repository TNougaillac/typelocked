# Fonctionnalités

## F01. Mode Nuzlocke
**Statut :** v1.3.0, écrit, **non testé**.
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
- **Mort définitive :** un Pokémon du joueur qui tombe K.O. est mort tout de suite (un rappel en combat ne le sauve pas). En fin de combat il part dans une boîte « Cimetière N », créée au besoin avec le fond « City » (`GRAVEYARD_BACKGROUND`). Le message de sa mort s'affiche avec son panneau d'équipe (icône, nom, niveau, PV). Il reste visible dans le PC mais ne peut plus être retiré, mis dans l'équipe, relâché ni soigné.
- **Poison hors combat :** il laisse le Pokémon à 1 PV puis disparaît.
- **Équipe entièrement K.O. :** retour au dernier Centre Pokémon, les morts vont au cimetière et la partie continue avec les Pokémon du PC. S'il ne reste plus aucun Pokémon vivant (équipe et PC), le run est perdu : le mode se désactive et l'aventure continue normalement.
- **Sauvegarde à la défaite** (`SAVE_ON_DEFEAT`) : après une défaite (retour au Centre), une fois les morts enterrés, la partie est sauvegardée. On ne peut donc pas recharger une sauvegarde d'avant la défaite.

### Fichiers
| Fichier | Rôle |
|---|---|
| `meta.txt` | Déclaration du plugin. |
| `001_Settings.rb` | `ZONE_GROUPS`, `DUPLICATE_BY_FAMILY`, `SHINY_CONSUMES_FREE_ZONE`, `GRAVEYARD_NAME`, `GRAVEYARD_BACKGROUND`, `SAVE_ON_DEFEAT`. |
| `002_Data.rb` | Données de sauvegarde (`$nuzlocke`), zones utilisées, boîtes cimetière. |
| `003_Encounters.rb` | Zones, doublons, shiny, blocage des Poké Balls. |
| `004_Nicknames.rb` | Surnoms obligatoires (« Surnom de … ? »). |
| `005_Permadeath.rb` | Mort, cimetière (fond, panneau du mort), verrou des PV, équipe K.O., sauvegarde à la défaite. |
| `006_Setup.rb` | Fenêtre de choix du début de partie, inscrite auprès de NewGameSetup. |
| `007_Storage.rb` | Verrous du PC sur les Pokémon morts. |
| `008_FieldPoison.rb` | Poison hors combat. |

### Intégration
- Début de partie : la fenêtre s'affiche seule (plugin NewGameSetup requis). `Nuzlocke.setup_dialog` reste utilisable dans un événement.
- Regrouper des cartes : `Nuzlocke::ZONE_GROUPS = { id_secondaire => id_principal }`.

### Points d'accroche Essentials (alias/prepend, aucun script de base modifié)
`pbStartBattle`, `pbThrowPokeBall`, `pbStorePokemon` (sur `Battle` et `SafariBattle`, qui n'hérite pas de `Battle`), `Battle::Battler#pbFaint`, `ItemHandlers.triggerCanUseInBattle`, `Battle::Scene#pbToggleBallInfo` (menu des Poké Balls de l'Enhanced Battle UI), `pbNickname`, `Pokemon#hp=`, `Pokemon#heal_HP`, `PokemonStorageScreen#pbWithdraw/pbPlace/pbSwap/pbRelease`, `pbStartOver`, handlers `:on_end_battle` et `:poison_party` (remplacé).

### À vérifier au premier lancement
- Les points d'accroche ont été vérifiés contre les scripts v21.1 du dépôt (`Data/Scripts.rxdata`), mais le plugin n'a pas encore tourné en jeu.
- Combat double avec une cible non capturable : la Poké Ball est rendue mais le tour est perdu.

### Limites connues
- Pas de mode hardcore pour l'instant (poison mortel, K.O. de l'équipe = fin de partie) : à ajouter plus tard.
- Les œufs qui éclosent ne forcent pas de surnom.
- Les cadeaux ne consomment pas la zone.
- Couper le jeu pendant un combat perdu, avant la fin du combat, évite encore la sauvegarde à la défaite.
- Les boîtes Cimetière créées avant la v1.3.0 gardent leur fond.

## F02. Deluxe Battle Kit (plugin externe)
**Statut :** v1.3.1 installé (Lucidious89), avec son prérequis v21.1 Hotfixes 1.0.9 (Maruno). **Non testé.**
**Dossiers :** `Plugins/[DBK_000] Deluxe Battle Kit/`, `Plugins/v21.1 Hotfixes/`, `Graphics/Plugins/Deluxe Battle Kit/`, plus quelques fichiers dans `Audio/` et `Graphics/UI/`.
**Doc :** https://lucidious89-tutorials.gitbook.io/deluxe-battle-kit-tutorial

- Ajoute des Battle Rules (`setBattleRule`), les combats de boss sauvages (`editWildPokemon` avec `:hp_level` et `:immunities`), la capture style raid et les scripts en plein combat.
- Remplace deux images de base : `Graphics/UI/Battle/icon_mega.png` et `cursor_command.png`.
- `Town Map Generator.html` (version corrigée de `townmapgen.html`) est à la racine du projet.
- Cohabitation avec le Nuzlocke : le kit efface les surnoms dans `pbStorePokemon`, le Nuzlocke remet le surnom forcé après coup. Effet visible : le message « envoyé dans la boîte » affiche le nom de l'espèce.

## F03. Générateur de cartes (MapGen)
**Statut :** v1.14.0, écrit, testé hors jeu sur les données du dépôt, **non testé en jeu**.
**Version cible :** Essentials v21.1.
**Dossier :** `Plugins/MapGenerator/`, plans dans `MapGen/*.txt` (exemples : `MapGen/exemple.txt`, `MapGen/exemple_calques.txt`, `MapGen/exemple_porte_dehors.txt` + `MapGen/exemple_porte_maison.txt`, `MapGen/place_ville.txt`, plan du monde `MapGen/exemple_monde.txt`).

### Fonctionnement
- Un plan texte décrit la carte : un caractère par case, une légende qui associe chaque caractère à 1 à 3 calques.
- Calques : `T<n>` = tuile n du tileset (n = ligne × 8 + colonne), `A1` à `A7` = autotile (raccords calculés automatiquement), `-` = vide, `T1|T2|T3` = variante au hasard (`Seed` pour un résultat reproductible).
- Objets multi-cases (section `[Objects]`) : `H = T400 3x4` déclare un bloc de 3×4 tuiles à partir de la tuile 400. Dans `[Map]`, le symbole couvre toute la surface de l'objet (`HHH` sur 4 lignes). Une zone plus grande contient plusieurs copies, découpées depuis le coin haut-gauche (`HHHHHH` sur 4 lignes = deux objets). Une zone incomplète provoque une erreur qui indique la case fautive. Options : `L1` à `L3` pour le calque (`L2` par défaut), `@<symbole>` pour le sol sous l'objet (sinon la clé `Ground`), `halo=4x4@1,1/0,3` pour un dessin plus grand que le bloc (v1.13.0) : un dessin de 4×4 tuiles dont le bloc commence en colonne 1, ligne 1 ; ses autres tuiles sont posées sur le calque 3 autour du bloc, seulement où ce calque est vide, sauf les cases vides listées après `/` (numérotées ligne par ligne depuis 0). Le halo ne change ni la place que prend l'objet ni ses passages. `forest=T<n>` (v1.14.0) fait d'un objet 2×2 un arbre de forêt : son bloc est un dessin de 6×6 tuiles (la paire d'arbres de SirMalo : rangées pointes, haut du feuillage, bas du feuillage sur les pointes de l'arbre de devant, haut du feuillage sur l'arbre de derrière, bas du feuillage, troncs ; colonnes débord gauche, moitié gauche, moitié droite sous l'arbre suivant, moitié gauche sur l'arbre précédent, moitié droite, débord droit) et `T<n>` sa copie aux passages d'un halo. Chaque case est dessinée selon sa place dans la forêt : un arbre qui a un arbre dessous montre le haut du feuillage de celui-ci, un arbre du bas montre son tronc, deux arbres côte à côte se rejoignent si leurs rangées concordent. Le haut du feuillage et les pointes au-dessus de la forêt et les débords sur ses côtés sont un halo sur le calque 3 (sur le calque 2 dessous quand un autre halo y est déjà).
- Grilles de calques (sections `[Layer2]` et `[Layer3]`, facultatives, même taille que `[Map]`) : dessinées par-dessus `[Map]`. `.` = rien ; un symbole de `[Legend]` est posé à partir de ce calque (un symbole à 2 calques dans `[Layer2]` remplit les calques 2 et 3) ; un objet de `[Objects]` est posé sur ce calque, quel que soit son `L`.
- Terrains à raccords automatiques (section `[Terrains]`) : `P = T274 N=T266 S=T282 W=T273 E=T275 NW=T265 NE=T267 SW=T281 SE=T283 iNW=T286 iNE=T284 iSW=T270 iSE=T268` déclare la tuile intérieure, les bords, les coins et les angles rentrants (`i…`). Dans la grille, on écrit seulement `P` : chaque case reçoit la tuile qui correspond à ses voisines. Un rôle absent prend la tuile intérieure ; une tuile intérieure `-` ne dessine que les bords (rien par-dessus le reste de la case). Options : `with=D` (terrains qui se raccordent sans bord), `L1` à `L3` (calque dans `[Map]`, `L1` par défaut), `@<symbole>` (sol dessous si le calque n'est pas `L1`). Un terrain marche aussi dans `[Layer2]` / `[Layer3]`.
- Portes et étages (sections `[Warps]` et `[Events]`) : `1 = Maison 1 4,7 haut` déclare une téléportation vers la carte nommée « Maison 1 » (ou son ID), case 4,7 (comptée depuis 0), regard vers le haut (`haut`, `bas`, `gauche`, `droite`, ou direction conservée). La grille `[Events]` (même taille que `[Map]`, `.` = rien) place ces symboles. Chaque porte devient un événement « MapGen warp » (contact du joueur, commande « Téléporter le joueur ») ; Essentials le transforme en porte animée à la compilation si la case ressemble à une entrée. À chaque génération, les anciens « MapGen warp » de la carte sont remplacés. Avec « Tous », une porte vers une carte générée plus tard dans la même série est reliée après coup.
- Plan du monde (un plan qui contient la clé `World`) : décrit la région entière. `World = nom de la région`, `Region = n°` (carte de région de `town_map.txt`, 0 par défaut), `Cell = 20` (tuiles par case), `Origin = x,y` (case de la carte de région où commence le plan), `Image = monde.png` (image de la carte de région, `mapRegion<Region>.png` par défaut), `Tileset` / `Ground` (cartes créées vides). Section `[Places]` : `A = Bourg Typelock vol=12,8` associe un symbole à une carte, trouvée par son nom (`vol=x,y` = point d'arrivée de Vol, `type=ville|route|lieu` = dessin sur la carte de région, deviné sinon : « Route… » = route, avec `vol` = ville, sinon lieu, `nom=Port Lucca` = nom affiché en jeu dans les métadonnées et la carte de région, la carte gardant le sien ; `masque=10/11` = les cases de son rectangle que le lieu couvre, ligne par ligne (les autres restent hors de la carte de région : pas de `Point`, `MapSize` avec ses 0, côte dessinée autour des cases couvertes) ; `trace=1,1/3,1/3,4` = le tracé d'une route sur la carte de région, en demi-cases depuis le coin haut-gauche de son rectangle ; une région dessinée par le plan (`Image`) ne garde que les points du plan). Section `[World]` : un caractère par case de la carte de région, `.` = rien, chaque lieu forme un rectangle plein. Section `[NoLinks]` (facultative) : `A B` = deux lieux qui se touchent sans être reliés.
  - Une carte absente est générée depuis le plan MapGen de même `Name`, sinon créée vide (taille du rectangle × `Cell`). Chaque lieu doit couvrir dans `[World]` autant de cases que sa carte compte de fois `Cell` tuiles (arrondi) : une ville de 40x20 avec `Cell = 20` s'écrit `VV`. Sinon un message indique la bonne taille (« doit couvrir 2x1 cases »).
  - Deux lieux qui se touchent sont raccordés bord à bord (`PBS/map_connections.txt`), avec le décalage calculé depuis la grille.
  - `type=decor` (cartes de décor de MapProc, #119) : un décor est raccordé aux lieux qu'il touche, aussi par un coin (raccord côté est, décalé au-delà du coin), jamais à un autre décor. Il n'a ni point sur la carte de région, ni `ShowArea`, `MapPosition` ou `MapSize`, et n'est pas dessiné sur l'image de la région.
  - Chaque lieu reçoit `Name`, `Outdoor`, `ShowArea`, `MapPosition` et `MapSize` dans `PBS/map_metadata.txt` (les autres clés de la section sont gardées), et ses cases dans la région de `PBS/town_map.txt` (`Point`, avec la destination de Vol).
  - L'image de la carte de région est dessinée dans `Graphics/UI/Town Map/` (480x320 au minimum, cases de 16 px), avec les couleurs et les formes de `mapRegion0.png` : côte arrondie avec sable et eau peu profonde, routes blanches dans un bandeau sombre qui suivent les raccords, villes en blocs rouges, autres lieux en cases sombres à point vert. Une image existante n'est remplacée que si MapGen l'a dessinée (les images faites à la main, comme `mapRegion0.png`, sont gardées).
  - Seules les lignes qui concernent les cartes du monde sont réécrites ; les trois fichiers PBS sont recompilés tout de suite.
- **Caméra aux bords** (#119, toutes les cartes) : sur un bord sans carte raccordée en vue, la caméra s'arrête au bord de la carte au lieu de montrer du noir (comme la métadonnée `SnapEdges`, mais seulement de ce côté). Là où une carte voisine est en vue, elle continue de défiler. Une carte plus petite que l'écran (intérieur) garde la caméra d'Essentials sur cet axe.
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
| `008_EdgeCamera.rb` | Caméra arrêtée aux bords sans carte voisine. |

### Points d'accroche Essentials
Alias de `Game_Map#display_x=` et `display_y=` (caméra aux bords) et de `MapFactoryHelper.clear`. Utilise `Compiler.compile_connections`, `compile_map_metadata` et `compile_town_map` (plans du monde), `TileDrawingHelper::NEIGHBORS_TO_AUTOTILE_INDEX` (même table que le rendu d'Essentials) et `MenuHandlers.add(:debug_menu, ...)`.

### Limites connues
- Pas encore d'import PNG (1 pixel = 1 case) ni de génération procédurale.
- Plan du monde : chaque lieu est un rectangle (pas de lieu en L), et l'image de la carte de région n'a ni relief, ni arbres, ni rivières.
- Un terrain choisit un seul angle rentrant par case : une case entourée de plusieurs angles rentrants prend le premier (haut-gauche, haut-droite, bas-gauche, bas-droite).
- Caméra aux bords : une carte voisine qui ne couvre qu'une partie de la vue laisse encore voir du noir à côté d'elle (coins). En longeant un bord, la caméra peut sauter quand la carte voisine sort de la vue. Le décor n'est pas prolongé (cartes de remplissage à venir, #119).

## F04. Mode Monotype
**Statut :** v1.7.0, écrit, **non testé**.
**Version cible :** Essentials v21.1.
**Dossier :** `Plugins/Monotype/`

### Règles
- **Activation :** choix unique et définitif, proposé automatiquement en début de partie par le plugin NewGameSetup (après le choix Nuzlocke), au premier pas du joueur ou juste avant le premier Pokémon reçu. **Normal** : le type est tiré au hasard. **Facile** : le joueur choisit parmi les 18 types.
- **Capture :** seuls les Pokémon qui ont le type imposé (simple ou double type), ou dont une évolution l'a, sont capturables (ex. Eau : Azurill grâce à Marill, Évoli grâce à Aquali). Les Poké Balls sont grisées, ou rendues en combat double si la cible n'est pas capturable. Le type compte pour la forme (Motisma Lavage = Électrik/Eau).
- **Évolutions :** le sens inverse ne compte pas. Un Pokémon qui perd le type en évoluant (Évoli → Pyroli en Eau) devient inutilisable et part au PC.
- **Dons et échanges hors du type :** envoyés directement au PC, présents mais inutilisables.
- **Inutilisable :** ne peut pas quitter le PC pour l'équipe. Un Pokémon inutilisable dans l'équipe (évolution, échange, Pension) est envoyé au PC à la fin du combat ou au pas suivant.
- **Starter :** le joueur choisit son starter, niveau 5, parmi 3 Pokémon tirés au hasard pour la partie. Ils viennent de tout le Pokédex des rencontres (`docs/roster/pokedex.csv`, 806 espèces hors légendaires) : formes de base (leur pré-évolution n'est pas dans la liste) qui respectent la règle de capture et évoluent en un Pokémon de la liste (#115), sans les pseudo-légendaires (évolution finale à plus de `STARTER_MAX_FINAL_STATS` = 599 de stats de base). Le tirage est gardé dans la sauvegarde pour que chaque Poké Ball du professeur garde son Pokémon.
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
| `006_Roster.rb` | `ROSTER` : les 806 Pokémon du jeu, copie de `docs/roster/pokedex.csv` (vérifiée par la CI, qui vérifie aussi qu'il y a au moins 3 starters possibles par type). |

### Intégration
- Rien à placer dans l'éditeur : les choix de mode s'affichent seuls en début de partie, les dresseurs d'arène et de Ligue sont reconnus par le nom de la carte dans l'éditeur (« Gym », « Arène », « League » ou « Ligue », réglable avec `GYM_MAP_PATTERN`), et les champions, le Conseil 4 et le Maître par leur type de dresseur (`LEADER_…`, `ELITEFOUR_…`, `CHAMPION…`, et ceux de la Famille `LIEUTENANT_…`, `ANCIEN_…`, `PARRAIN`, réglable avec `GYM_LEADER_PATTERN`).
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
**Statut :** v1.5.0, écrit, **non testé en jeu** (conversion testée hors jeu avec le compilateur réel d'Essentials).
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
- **`When`, `Wait`, `Gift` et `Once` (PNJ) :** `When = S4` (ou `V7>=1`) : le PNJ ne dit ses `Text`, ne lance ses `Script` et ne donne ses `Gift` qu'une fois la condition vraie, et dit ses `Wait` avant (une page de plus avant la sienne). `Gift = MACHETE` donne l'objet (`pbReceiveItem`), dans l'ordre du fichier avec les textes. `Once = Bonne route !` : le PNJ ne le fait qu'une fois (interrupteur local A), puis dit ses `Once` ; obligatoire avec un `Gift`, et incompatible avec `Hide = A`. Le nombre de sceaux passe par l'interrupteur du lieutenant (`S4` à `S11`).
- **`[Copy N]` :** `From = 24,2` copie l'événement 2 de la carte 24 tel quel (pages, graphismes, commandes) sur `Pos`. Il garde son numéro s'il est libre, pour les événements qui le nomment (l'infirmière et sa machine de soin) : les copies sont placées avant les autres événements. `Graphic = …` remplace son apparence, sur toutes ses pages et dans ses déplacements (#114). `Confirm = script` est placé au début de la première réponse de son premier choix : si le script renvoie faux, l'événement s'arrête.
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
**Statut :** v0.31.0, prototype écrit, **non testé en jeu**.
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
  - **Briques réservées :** un fichier de brique peut lister ses ambiances (`Ambiances = sable, minérale`, séparées par des virgules) : elle n'est alors tirée que dans ces ambiances. Un type dont aucune brique ne convient à l'ambiance est sauté. Le type `decor` regroupe les briques de pur décor (quantité `decor = 0` dans `[Briques]`, donnée par chaque ambiance). Le décor obligatoire d'une ambiance se pose après les autres briques obligatoires, pour ne jamais leur prendre la place. La CI refuse une ambiance inconnue et vérifie qu'aucune brique réservée n'est posée ailleurs.
  - **Sable :** flèches rocheuses brunes, rochers et cailloux bruns, peu d'arbres, pas de parc sur les routes. **Minérale** (villes et routes) : flèches et éboulis gris, rochers gris, la roche grise à la place de la brune (montagnes, rochers, corniches ; les escaliers restent bruns), pas de lac.
  - **Verdoyante :** bois mélangés (grands pins, arbres ronds, cyprès), buissons. **Prairie :** fleurs, buissons, cyprès, haies taillées, peu d'arbres. **Terre battue et chemins de terre :** champs labourés, haies, arbres ronds et grands pins (chemins de terre).
  - **Nouvelles ambiances :** **automne** (routes et villes : arbres et buissons jaunes) et **forêt tropicale** (routes : grands arbres à canopée, buissons serrés), chacune au poids 1. Les arbres de bordure restent des pins.
  - **Objets de décor par ambiance (#110) :** 49 objets tirés de tilesets libres de fans (`tools/art/import_props.py`, crédits dans `docs/CREDITS.md` : Emerald Outdoors, KingTapir Sandstream Desert et Alola Misc), ajoutés sous le tileset Outside (T4216 à T4383) avec leurs passages et priorités, les ombres grises opaques de KingTapir rendues transparentes : poteries, caisses, jardinière, pots et bacs de fleurs, rochers moussus, blancs, rouges et gros rochers bruns, bûches et rondins, arbres en fleurs, acacia, parasols, cactus tonneaux, touffes sèches (on marche dessus), aiguilles de grès, palmiers verts et bleus, buissons tropicaux, tikis, parasol de paille, brouette, caisse en bois. Le haut d'un objet de plusieurs cases de haut passe au-dessus du joueur, comme la cime d'un arbre ; un palmier ou le parasol de paille ne bloque que son tronc. Symboles `ā ē ī ū ő ű ŵ ģ ļ` (`[Legend]`, plusieurs variantes tirées au hasard pour `ā ē ū ő ŵ ļ`) et `ń ď ž š ą þ ð æ œ ß ÿ ý ñ ķ ŗ ş ţ ȩ ǎ ǐ ǒ ǔ ă ĕ ĭ ŏ ņ ǖ ǘ` (`[Objects]`) dans `ville.txt` et `route.txt`, 21 briques `decor` réservées à leurs ambiances (`poteries`, `cactus_tonneaux`, `aiguilles_gres`, `palmeraie`, `palmiers`, `palmiers_bleus`, `plage`, `parasol_plage`, `gros_rochers_bruns`, `arbres_en_fleurs`, `verger_en_fleurs`, `jardin_fleuri`, `rochers_moussus`, `rochers_blancs`, `reserve`, `bucher`, `brouette`, `tikis`, `acacias`, `buissons_exotiques`, `caisse_bois`). Les grottes (autre tileset) n'en ont pas encore.
  - **Passe large dans les packs (#162) :** 57 objets de plus (tileset Outside T4359 à T4895, placés dans les trous laissés par #110 puis à la suite) : arbres et aiguille rouge d'Emerald (`ǚ ǜ ȁ ȍ`), lampadaire, statue blanche, étal du marché, parterre octogonal, fontaine, poteau fleuri, bassin rocheux, haie basse, lanterne de pierre (Emerald), arbres de Galar, panneaux, boîte aux lettres, distributeur et machines à boules, rondins, double lampadaire, menhir moussu (KingTapir Galar Misc), tableaux d'affichage, cône, caisses, lanterne de Corrifey, bancs (Stow-on-Side), arbre mort géant (Agate Village), statues, totems, cyprès, stèles, panneaux en bois, lanterne suspendue, torches, tablette, camion, bloc gravé, rocher blanc, banc de bois (Alola Misc). Symboles `Ā` à `Ņ` dans `[Objects]`. 35 briques : 3 + 18 `decor` réservées à leurs ambiances (`grand_arbre_rond`, `bosquet_sapins`, `aiguilles_rouges`, `arbres_galar`, `haie_basse`, `bassin_rocheux`, `poteaux_fleuris`, `lanternes_pierre`, `menhir`, `statues_anciennes`, `totem_miroir`, `steles`, `bloc_grave`, `statue_chauve_souris`, `cypres_alola`, `sanctuaire_tiki`, `totems`, `portique_totems`, `chantier`, `panneaux_bois`, `arbre_mort_geant`), 8 `lampe` le long des rues des villes (`lampe_lampadaire`, `lampe_double`, `lampe_corrifey`, `lampe_suspendue`, `lampe_boite_lettres`, `lampe_gachas`, `lampe_bancs`, `lampe_banc_bois`) et 6 `foire` (`foire_etal`, `foire_fontaine`, `foire_parterre`, `foire_camion`, `foire_tableaux`, `foire_panneaux_galar`). Écartés : les buttes de roche d'Emerald (coins opaques), les bâtiments, les sols et les falaises (rôles à recaler sur Essentials).
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
  - des routes marines (`Mers`, `1..2` dans `monde.txt`), après la ville de Surf elles aussi, sont presque entièrement de mer, comme les routes 105 à 134 de Hoenn : une plage de 3 à 6 rangées à chaque bout (`SEA_ROUTE`), des crêtes de roche qui suivent la route et des massifs qui serpentent (terrain `RocherMarin`, `ŕ` dans `route.txt`, sur la couche 3 au-dessus de l'eau), de petits rochers et des bancs de sable ; un couloir de 2 cases autour du trajet reste libre pour surfer. Chaque banc de sable (un au moins) est un îlot avec son butin (recoin `ilot`), où l'on accoste en surfant, comme les objets des îlots de Hoenn. Tirages à part (`SEA_ROUTE_SALT`). Les briques qui n'ont pas la place sur les plages sont laissées de côté ;
  - une route peut être barrée par un mur de rochers, avec une entrée de grotte de chaque côté ;
  - des routes de montagne (`Montagnes`) se découpent en niveaux séparés par des falaises, que l'on passe par des escaliers ; les sorties et l'eau restent au sol. Autant de niveaux que `Relief` a de symboles (6 dans `route.txt` : `¬ & k K m M` ; les niveaux impairs ont les bords du niveau 1, les pairs ceux du niveau 2). Comme sur les cartes officielles (carte 21 de la démo, Route 204, Survival Area), un niveau est un **plateau** : son dessus garde le sol de l'ambiance, son bord nord est un rebord fin (`{rive}`, la rive de l'ambiance, que l'on ne franchit pas vers le nord), ses côtés et son bord sud une falaise de roche ; en ambiance minérale, les bords sont de roche grise. Une route nord-sud a 5 à 8 frontières de niveau (`MOUNTAIN_FACES`), la suivante monte 7 fois sur 10 (`MOUNTAIN_CLIMB`) ; une montagne colossale en a autant que la route en tient. Les bords ondulent d'une ou deux cases (`FACE_WAVE`) ou, 6 fois sur 10, descendent en pente sur jusqu'à 5 rangées (`SLOPE_CHANCE`, `SLOPE_BIAS`, `SLOPE_WAVE`) ; un rebord nord reste presque plat. Ils sont à plat là où un chemin les traverse (l'escalier) ; une bande garde au moins 3 rangées (`BAND_MIN`). Une bande s'arrête avant un côté de la carte 6 fois sur 10 (`SIDE_TRIM`, à `SIDE_GAP` cases au moins de ses chemins), sa coupe serpentant de 3 colonnes au plus (`SIDE_WAVE`) : elle forme un plateau isolé ; de petits plateaux ovales (`MOUNTAIN_PEAKS`) s'élèvent d'un niveau. Tirages à part (`RELIEF_SALT`). Une falaise = toute case d'un niveau qui touche (8 voisins) une case plus basse ; un tirage de niveaux qui coupe une sortie d'une autre est rejeté. Les niveaux sont dessinés sur la couche 3 du plan (`[Layer3]`, terrains sans tuile intérieure, MapGenerator 1.12.0) : la carte garde leur sol, leurs chemins (visibles sur les plateaux) et leurs briques (arbres, herbes, maisons...), sauf l'eau, les massifs de roche, les grottes et le port (`LOWLAND`) ; une case de falaise est `ɸ` sur la carte, un escalier ou un arbre de bordure `ʘ` sur la couche 3 (rien, joint aux niveaux). Des hautes herbes (`HerbeHaute = n`) poussent en taches sur les niveaux (`MOUNTAIN_GRASS`, rencontres sauvages comprises). Les massifs (`montagne`), les buttes (`rocaille`) et les recoins sont de roche (terrain `^`). Une route de montagne peut aussi être coupée par un chenal ou un lac, ou, si elle va du nord au sud sans être coupée, être longée par une rivière au pied des falaises, en parallèle du chemin (`RiviereMontagne`, en %). Elle a une grotte en cul-de-sac selon `GrotteMontagne` (en %), ouverte au pied d'une falaise quand une place s'y prête. Les buttes (briques `rocaille`) ne se posent que sur les niveaux ;
  - villes en terrasses : 65 fois sur 100 (`TERRACE_CHANCE`, tirages à part `TERRACE_SALT`), une ville assez grande pour une place (pas un port, une île, un canal ni un lieu à masque) monte en gradins, comme Oreburgh ou Ever Grande : 2 à 4 falaises (`TERRACE_FACES`) à au moins 7 rangées l'une de l'autre (`TERRACE_DEPTH`), jusqu'au 2e niveau quand les sorties le permettent ; les bandes des sorties et de l'eau restent en bas, les côtés sont coupés en plateau. Des jardins surélevés en boîte (`TERRACE_PEAKS`) s'y ajoutent, un niveau au-dessus de leur sol. Les rues franchissent les falaises par des escaliers aussi larges qu'elles (avenues et place comprises) ; maisons, arbres et décor s'y posent comme en bas (`Relief = ¬ ł`, `Escalier` dans `ville.txt`). Si ses briques ne tiennent pas, d'autres terrasses sont tirées (`TERRACE_TRIES` en tout), puis la ville est reconstruite à plat ;
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
- **Performances (#162) :** la place d'une brique se cherche sur une grille des cases interdites (prises, au mauvais niveau ou collées à une autre brique), calculée une fois par brique au lieu de revérifier les voisines à chaque emplacement ; les distances aux rues ne revérifient plus chaque case pour chacune de ses voisines ; le masque d'une route n'est dessiné que pour les tracés retenus. Mêmes mondes qu'avant pour une même graine, 3 à 5 fois plus vite (graines 1 à 3 de `monde.txt` : 25, 15 et 38 s → 8, 5 et 7 s hors jeu).
- Lancement : menu debug > Autres éditeurs > « Générer un lieu (MapProc) ». Les raccords, les métadonnées, la carte de région et les points de vol sont écrits par MapGen.
- **Nouvelle partie :** chaque nouvelle partie tire un monde (`NEW_GAME_WORLD`, `monde.txt` par défaut, `nil` = désactivé) avec une graine au hasard. Les cartes sont générées avec leurs événements (WorldEvents, F15) ; les rencontres sauvages sont écrites par ProceduralEncounters (F13). La partie commence directement dans la première ville du monde, devant le Centre Pokémon (sinon devant la première porte) : l'intro de l'éditeur (carte 1) est sautée, le joueur choisit seulement son nom (`pbTrainerName`, personnage 1). Sans monde (`NEW_GAME_WORLD = nil` ou génération ratée), l'intro d'origine se joue. Aucun message au joueur : la graine, Surf et Plongée sont écrits dans la console. La graine est gardée dans la sauvegarde.
- **Génération pendant l'intro :** le tirage du monde (le calcul en Ruby pur de `generate_world`, `compute_world`) tourne dans un thread de basse priorité (`WORLD_THREAD_PRIORITY`, tranches de temps courtes pour garder la fluidité de l'intro) pendant que l'intro (IntroScene, F14) se joue. La partie démarre sur la carte de départ de l'éditeur, puis, avant que la première carte s'affiche (`Scene_Map#main`), les cartes sont écrites et le joueur est déplacé au départ du monde (nouvelle `PokemonMapFactory`, `moveto`, rencontres, musique de la carte). L'écran « Le monde se prépare... » ne reste que le temps d'écrire les cartes, plus la fin du calcul s'il n'est pas fini. Même graine, même monde qu'avant. Si le thread échoue, le monde est tiré à ce moment-là, comme avant (message dans la console).
- **Partie non sauvegardée :** à la fermeture du jeu (`at_exit`), si aucune sauvegarde ne contient de monde, les fichiers `Data/MapXXX.rxdata` du monde et leurs entrées dans l'arbre des cartes sont supprimés tout de suite (sans compilateur, la fenêtre n'existe plus). Le reste est fait au lancement suivant (écran de chargement), où les cartes sur le disque sont remises d'accord avec la sauvegarde :
  - pas de sauvegarde (ou une sauvegarde sans monde) : les cartes du monde sont supprimées (`Data/MapXXX.rxdata`, arbre des cartes, raccords, métadonnées, points de la carte de région, graines des grottes) la région de `town_map.txt` et son image (`typelocked_proc.png`) sont remises comme avant le premier monde, les plans exportés de ce monde (`MapProc/Export/monde_<graine>.txt` et ses rencontres) supprimés ;
  - sauvegarde d'un autre monde : ce monde est redessiné depuis sa graine (mêmes numéros de carte), les cartes en trop et les plans exportés du monde abandonné sont supprimés.
- **Noms de lieux :** avec `Toponymie = Lore/noms.txt` dans `monde.txt`, les noms affichés en jeu (panneau d'entrée, Carte de la région, métadonnées) sont tirés avec la graine dans `MapProc/Lore/noms.txt` (voir `docs/LORE.md`) : la première ville et les villes sans arène sont des villages (Bourg Lucca, Beaumont County), les villes portuaires et les cités lacustres des ports (Port Hudson, Salerno Dock), les autres des villes (Morettiville, Caruso City) ; les routes sont numérotées (Route 1), les grottes nommées (Grotte Rossini, Hudson Cave), la région aussi (Omerta...). Langue du nom de base tirée à parts égales, jamais deux fois le même nom. Les cartes gardent leur nom généré dans l'arbre des cartes (« Ville générée 3 »), pour que les numéros de carte restent les mêmes d'un monde à l'autre ; le nom affiché passe par l'option `nom=` de `[Places]` (MapGen). Les tirages ont leur propre graine : le reste du monde ne change pas.
- **Inventaire (`009_Atlas.rb`) :** chaque monde garde, pour chaque carte, ses emplacements : sorties, portes avec leur type de bâtiment, cases libres au bord des rues (et la direction de la rue, `facing`), hautes herbes, culs-de-sac (toutes accessibles à pied depuis une sortie ou une porte), toutes les cases où l'on marche (`ground`, pour WorldEvents seulement : ni sauvegardé ni exporté, #115), et pour le monde entier la ville de départ, l'ordre des arènes (l'arène d'une île juste après son port), les villes de Surf et de Plongée. Sauvegardé avec les cartes dans `Data/MapProcAtlas.rxdata` (par numéro de carte), exporté en texte dans `MapProc/Export/monde_<graine>_inventaire.txt`. En jeu : `MapProceduralGenerator.spots(map_id)` (nil hors du monde généré) et `MapProceduralGenerator.atlas`. La CI vérifie sur chaque graine que les portes sont celles des briques, que les autres cases sont praticables, et que la même graine donne le même inventaire.
- **Bordures naturelles :** au-delà de sa première rangée d'arbres, la bordure d'une ville gagne 0 à 1 rangée d'arbres de plus vers l'intérieur, celle d'une route 0 à 2 (`BORDER_DEPTH`, `001_Settings.rb`). La profondeur change d'une rangée au plus tous les 2 à 5 arbres le long de chaque côté (`BORDER_STRETCH`), pour que la lisière serpente comme dans les cartes officielles, sans dépasser 20 % de la carte en travers (`BORDER_SHARE`). Les rues des sorties la traversent. Pas sur les lieux à masque (L, U) ni sur les îles. Tirages à part (`BORDER_SALT`) : le reste du lieu suit les mêmes tirages qu'avant.
- **Places et avenues :** une ville d'au moins 30 tuiles de côté a une place pavée de 9 à 12 x 8 à 10 tuiles autour de son carrefour, avec une fontaine ronde au milieu (`PLAZA`, brique « fontaine »). Les deux premières rues d'une ville partent de ses sorties en avenues de 3 de large (`AVENUE_MARGIN`). Les portes d'une ville donnent directement sur une rue (`DOOR_SLACK`), et une porte n'est retenue que si son chemin vers la rue ne passe pas par sa propre brique.
- **Plans de ville :** une ville à place tire son plan (`TOWN_PLANS`, tirages à part `PLAN_SALT`) : « carrefour » (rues des sorties vers la place, le plan d'avant), « grille » (un quadrillage de rues en plus, `GRID`), « canal » (un canal du nord au sud, de 4 à 5 de large, traversé par des ponts en bois, `CANAL`) ou « clairière » (pas de place, au moins trois fois le maximum d'arbres). Pas dans un port, sur une île ni sur un lieu à masque. Si ses briques ne tiennent pas dans son plan, la ville est reconstruite en « carrefour ». La CI construit chaque plan sur 5 graines.
- **Monument :** une statue de la Famille (brique `monument`) se pose à 3 tuiles au plus de la place (`MONUMENT_REACH`), ailleurs dans la ville s'il n'y a pas de place, et elle est laissée de côté si elle ne tient pas.
- **Sentiers sinueux :** sur une route de plaine (pas de montagne, de masque, de traversée, de verrou ni d'île), les rues serpentent : un pas de côté de 1 à 4 tuiles tous les 3 à 6 pas (`TRAIL`, tirages à part `TRAIL_SALT`). Chaque ambiance donne à la rue d'une route un sol de terre, de sable ou de gravier (`Rue` d'une ambiance de `route.txt`). Nouvelles briques : taches d'herbes irrégulières (`herbes_tache`, `herbes_tache_longue`) et grand bosquet (`bosquet_large`, verdoyante et automne). Une brique obligatoire qui ne tient pas essaie la plus petite de son type.
- **Étendues de sable :** une route de plaine verdoyante ou d'automne d'au moins 60 tuiles de long est traversée 40 fois sur 100 par une bande de sable de 14 à 22 tuiles, aux bords irréguliers, semée de quelques rochers (`TRANSITION`, tirages à part `TRANSITION_SALT`). Les briques ne s'y posent pas. Si la route ne tient pas avec, elle est reconstruite sans.
- **Mer vivante :** comme autour des îles, la mer d'un port et l'eau qui traverse une route (chenal, lac) reçoivent 1 à 3 rochers et 0 à 2 bancs de sable (`SEA_LIFE`, tirages à part `SEA_LIFE_SALT` ; `Recif` et `Banc` dans le lieu), à 2 tuiles au moins du rivage et à 3 tuiles au moins d'une rue, pour garder le passage en Surf.
- **Refuges :** une route a 0 à 1 maison isolée (brique `refuge` : maison en bois ou maison verte), reliée au sentier par un chemin. Sa porte mène à l'intérieur d'une maison, comme en ville (`INTERIORS`).
- **Rives :** l'autotile de mer (A1) ne dessine pas son bord du bas. La rangée sous chaque eau prend donc une tuile de rive (`Rive = !'?` dans le lieu : bout gauche, milieu, bout droit), sur l'herbe (T848 à T850), le sable (T832 à T834) ou la terre battue (T840 à T842) selon l'ambiance (`Rive` d'une ambiance ; prairie et minérale gardent la rive d'herbe). Cette rangée reste libre (pas de rue, de brique ni d'arbre de bordure) ; une brique d'eau ne se pose pas au-dessus d'une rue en ville. L'eau trop fine (hors de tout bloc 2x2, le bord de carte compte comme de l'eau) est retirée. La CI refuse toute eau sans rive, eau, relief ou bord de carte dessous, et toute eau trop fine.
- **Cartes de décor (`013_Fillers.rb`, #119) :** chaque case vide du monde à côté d'un lieu (côtés et coins) devient du décor non praticable, pour qu'on ne voie jamais de noir au-delà du bord d'un lieu : la mer au-delà du côté mer d'un port, le dessus d'une montagne (roche et quelques rochers, `FILLER_ROCKS`) à côté d'une route de montagne, sinon une forêt des arbres de bordure du lieu voisin, dans son ambiance (les rangées en trop prennent ses buissons). Le lieu copié est celui qui touche le plus la case (côtés avant coins). Les cases de même décor (même type, même fichier, même ambiance) sont regroupées en rectangles, une carte chacun (« Décor généré N », environ 50 par monde). Elles sont dans le plan du monde avec `type=decor` (symboles grecs et cyrilliques, `FILLER_SYMBOLS`) : MapGen les raccorde aux lieux qu'elles touchent, coins compris, et les laisse hors de la carte de région. `FILLERS = false` les retire. La CI vérifie leurs tuiles, leur taille, qu'elles n'ont pas de sol praticable et qu'aucune case vide ne reste à côté d'un lieu.
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
**Statut :** v1.1.0, écrit, **non testé**.
**Version cible :** Essentials v21.1.
**Dossier :** `Plugins/LevelCap/`

### Règles
- Le niveau maximum dépend du nombre de sceaux : c'est le niveau du Pokémon le plus fort du prochain lieutenant (avec 8 sceaux, celui du Parrain), lu dans `PBS/trainers.txt`. Les lieutenants sont listés dans l'ordre dans `LEADERS`.
- Un lieutenant pas encore défini (`nil` dans `LEADERS` ou absent de `trainers.txt`) utilise `FALLBACK_CAPS` (provisoire : 16, 24, 27, 33, 41, 49, 54, 57, 72, soit +2 à la première arène et le même facteur 16/14 sur les autres, #116). Une valeur `nil` = pas de limite. Tous les `LEADERS` sont à `nil` (Brock et Blue de la démo ne fixent plus les plafonds).
- Au niveau maximum, un Pokémon ne gagne plus d'expérience en combat (il gagne toujours ses EV). Un gain qui dépasserait la limite s'arrête pile au niveau maximum.
- Super Bonbon et Bonbons Exp. : refusés au niveau maximum (« X ne peut pas dépasser le niveau N pour l'instant. »), et la quantité proposée s'arrête à la limite.
- Un Pokémon déjà au-dessus de la limite (capturé, reçu) garde son niveau.
- **Indicateur :** « MAX » à côté du niveau d'un Pokémon au niveau maximum, en combat (boîtes de données du côté du joueur, en rouge) et dans l'écran de l'équipe (en jaune).

### Fichiers
| Fichier | Rôle |
|---|---|
| `meta.txt` | Déclaration du plugin. |
| `001_Settings.rb` | `LEADERS`, `FALLBACK_CAPS`, `LEVEL_ITEMS`. |
| `002_LevelCap.rb` | Calcul de la limite, limite d'expérience en combat et pour les objets. |
| `003_Display.rb` | « MAX » à côté du niveau, en combat et dans l'équipe. |

### Intégration
- À chaque nouveau lieutenant écrit dans `trainers.txt`, remplacer le `nil` correspondant de `LEADERS` par `[:TYPE_DE_DRESSEUR, "Nom"]`. La limite suit ensuite son équipe toute seule.

### Points d'accroche Essentials (alias, aucun script de base modifié)
`Battle#pbGainExpOne`, `Pokemon#growth_rate` (remplacé par une version plafonnée pendant le gain, Essentials fait le reste), `ItemHandlers.triggerUseOnPokemon` et `triggerUseOnPokemonMaximum`, `Battle::Scene::PokemonDataBox#draw_level`, `PokemonPartyPanel#draw_level`.

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
**Statut :** v1.4.1, écrit, testé hors jeu (CI), **non testé en jeu**.
**Version cible :** Essentials v21.1. Dépend de MapProceduralGenerator (`Requires = MapProceduralGenerator`), sans le modifier.
**Dossier :** `Plugins/ProceduralEncounters/`

### Règles
- Quand un monde MapProc est généré (menu debug ou nouvelle partie), chaque carte reçoit ses rencontres dans `PBS/encounters.txt` : `Land` s'il y a des hautes herbes, `Water` et les trois cannes s'il y a de l'eau, `Cave` pour chaque grotte. Seules les sections des cartes du monde sont remplacées (ou retirées si la carte n'a plus ni herbe, ni eau, ni grotte), puis le fichier est recompilé. Une copie est écrite dans `MapProc/Export/<monde>_<graine>_rencontres.txt`.
- Source : les 806 espèces de `docs/roster/pokedex.csv` (types, types Monotype, génération, force, famille) et les évolutions de `PBS/pokemon.txt` / `pokemon_forms.txt`. C'est tout le Pokédex d'Essentials v21.1 moins les légendaires, fabuleux et Ultra-Chimères. Modifier le fichier change les rencontres à la prochaine génération du monde.
- **Pokémon du monde :** si la liste en a plus de `WORLD_SPECIES` (300), chaque graine tire des familles entières jusqu'à 300 Pokémon : d'abord au moins `TYPE_FAMILIES` (4) familles capturables par type imposé, puis, à chaque tour, la plus équilibrante (types, forces, générations) parmi `WORLD_SAMPLE` (6) tirées au hasard. Deux mondes partagent environ 55 % de leurs Pokémon. Une liste de 300 ou moins est prise entière.
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
| `001_Settings.rb` | Fichiers lus, tuiles d'herbe et d'eau, `BIOMES`, `TABLES`, types dominants, couverture, niveaux, poids, tirage du monde. |
| `002_Species.rb` | Lecture du Pokédex et des évolutions (niveau ou sceaux minimum), tirage des familles du monde. |
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
**Statut :** v1.15.0, écrit, **non testé en jeu**. Spec #93, tickets #94 (socle et starter), #95 (services), #96 (dresseurs et Cousins), #97 (lieutenants et sceaux), #98 (objets trouvés et donnés), #99 (Ligue) et #100 (habitants et dialogues), puis sets des lieutenants et de la Ligue, et sprites de la Famille (#103).
**Version cible :** Essentials v21.1.
**Dossier :** `Plugins/WorldEvents/`

### Règles
- **Quand :** chaque fois que MapProc écrit un monde (nouvelle partie ou menu debug), ses événements sont tirés avec la même graine, à partir de l'inventaire (F07), puis placés par MapEvents (F06) sur ses cartes. Un générateur aléatoire à part : tirer les événements ne change pas le monde.
- **Plans :** les événements prennent la forme de plans MapEvents (un par carte), exportés dans `MapProc/Export/<monde>_<graine>_evenements.txt`. Copiés dans `MapEvents/`, ils se rejouent avec le placeur.
- **Professeur et starter :**
  - si la ville de départ a son labo, le Professeur Castellane s'y tient avec trois Poké Balls (`LAB_PROFESSOR`, `LAB_BALLS`). Parler au professeur ouvre le choix (interrupteur 3 « Choosing starter »), chaque Poké Ball propose un des trois starters (`Monotype.starter_ball`) et disparaît une fois prise ;
  - sinon, il attend dehors, sur la case `professor` de l'inventaire, et propose les trois starters dans une liste (`Monotype.starter_dialog`) ;
  - il ne raconte plus le Pacte, déjà dit pendant l'intro (F14) ;
  - il donne le Pokédex avec le starter (#115, `give_pokedex`, section `[professeur_pokedex]`).
- **Centres Pokémon :** chaque Centre (îles et plateau compris) reçoit l'infirmière, le PC et la machine de soin de son gabarit de la démo (`CENTRE_EVENTS`), copiés tels quels. Le point de soin du Centre vient déjà de MapProc (`HealingSpot`).
- **Infirmière de la Famille (#114) :** l'infirmière porte une tenue de la Famille (`NURSE_GRAPHIC`, `NPC Famille infirmiere`, recoloriée par `tools/art/family_nurse.py` à partir de `NPC 16`). Dans chaque Centre, les 3 premiers soins sont gratuits (`FREE_HEALS`), puis chaque soin coûte selon les sceaux gagnés (`HEAL_PRICES` : 100, 200, 300, 400, 600, 800, 1000, 1200, 1500 $). Avant de soigner, elle annonce le prix et demande oui ou non (`WorldEvents.nurse_pay`, sections `[infirmiere_fin_gratuit]` au premier soin payant, puis `[infirmiere_prix]`). Sans assez d'argent, elle refuse (`[infirmiere_sans_argent]`). Le compteur est gardé par Centre dans la sauvegarde (`$PokemonGlobal.centre_heals`). Les soins après une défaite restent gratuits.
- **Boutiques :** le vendeur est un membre de la Famille (`CLERK_GRAPHIC`, texte d'accueil `MART_SPEECH`). Son stock dépend des sceaux gagnés avant sa ville (une île compte comme son port) : chaque ligne de `MART_STOCK` ajoute ses objets à partir de ce nombre de sceaux (Poké Balls et Potions au départ, Super Balls à 2, Hyper Balls à 4, Guérison à 7).
- **Dresseurs :** 1 à 2 par case de route (`ROUTE_TRAINERS`), 1 à 2 par étage de grotte (pas dans les grottes sombres), placés au bord du chemin et tournés vers lui (inventaire `facing`), à 3 cases au moins des autres événements, jamais sur une sortie, une porte, la case devant une porte ou près d'une échelle, et leur vue (3 à 4 cases) n'atteint aucun de ces endroits. Le type de dresseur suit l'ambiance de la route (`TRAINER_TYPES` : montagne, grotte, sable, prairie...), le nom est tiré dans `TRAINER_NAMES` selon le genre du type (`FEMALE_TYPES`).
- **Combats doubles (#123) :** à partir de 3 sceaux gagnés avant la zone (`DOUBLE_FROM`), 25 % des dresseurs des routes, des grottes et des villes (`DOUBLE_CHANCE`) combattent en double (`DoubleBattle = oui`, 2 Pokémon au moins). Un joueur qui n'a qu'un Pokémon en état de combattre affronte ce dresseur en simple (alias de `TrainerBattle.start_core`). Les lieutenants et la Ligue restent en simple.
- **Carte de la région (#115) :** sur la première route du chemin où c'est possible, un Cousin se tient au bord de la rue, sa vue (jusqu'à 6 cases, `MAP_GIVER_SIGHT`) barrant le passage entre deux sorties : on ne peut pas le contourner. Battu, il donne la Carte (`MAP_ITEM`, `TOWNMAP`) avec une réplique de `[cousin_carte]`. La CI vérifie qu'il y en a un, et un seul, et qu'on ne le contourne pas.
- **Cousins de la Famille :** un dresseur de route sur quatre est un Cousin ou une Cousine (`COUSIN_CHANCE`, types `COUSIN_M` et `COUSIN_F` ajoutés à `trainer_types.txt`, graphismes de la Team Rocket copiés), et chaque ville en a 0 ou 1 (`TOWN_COUSINS`), sauf la ville de départ. Leurs textes parlent de la Famille.
- **Équipes :** tirées parmi les Pokémon sauvages de la zone (hautes herbes ou grotte, sinon l'eau, sinon la zone d'avant), au niveau le plus haut de la zone, moins 0 à 2 (`PARTY_LEVEL_SPREAD`), donc jamais au-dessus du plafond. Taille selon les sceaux gagnés avant (`PARTY_SIZES` : 1 à 2 au départ, 5 à 6 avec 8 sceaux). Écrites dans `PBS/trainers.txt` avec la version 100 (`TRAINER_VERSION`) : un nouveau monde remplace celles du précédent, et elles partent avec le monde supprimé. Les dresseurs faits main (autres versions) restent. Exportées dans `MapProc/Export/<monde>_<graine>_dresseurs.txt`.
- **Lieutenants (champions d'arène) :** chaque arène du monde (îles comprises) a son lieutenant, au fond de l'arène (`GYM_LAYOUTS`). Son type favori est tiré avec la graine, jamais deux fois le même, parmi les types qui ont des Pokémon dans le roster et une CT utile. Son type de dresseur est celui de son type favori (`LEADER_TYPES` : `LIEUTENANT_FIRE`, `LIEUTENANT_WATER`... « Lieutenant » en jeu), donc son sprite aussi ; la règle d'arène du Monotype (F04) s'applique. Équipe de son type : 2 Pokémon au 1er sceau, 6 au 8e (`LEADER_PARTY_SIZES`), les plus évolués d'abord, le plus fort au plafond de niveau du tronçon, les autres jusqu'à 3 niveaux en dessous (`LEADER_LEVEL_SPREAD`).
- **Sceau et CT :** battu, il remet sa chevalière (le badge `i`, interrupteur `3 + i`, « Gym 1 » à « Gym 8 » de la démo) puis une CT aléatoire de son type, jamais la même que celle d'un autre lieutenant. Une CT « utile » : puissance 70 ou plus (`TM_MIN_POWER`), 50 ou plus pour les 3 premiers lieutenants (`EARLY_GYMS`, `EARLY_TM_MIN_POWER`), ou une attaque de statut de la liste `TM_STATUS` (Danse-Lames, Toxik, Abri, Feu Follet...).
- **Membres d'arène :** 2 à 4 membres de la Famille (Cousins, `GYM_MEMBERS`) par arène, de son type, 2 à 4 niveaux sous le lieutenant (`MEMBER_LEVEL_GAP`). L'un d'eux est toujours posé de façon à ce que sa vue couvre le chemin vers le lieutenant (places `blocking` de `GYM_LAYOUTS`) : il ne bloque pas le passage, il force le combat quand le joueur passe devant lui, comme dans les jeux officiels.
- **Plafond de niveau :** les lieutenants sont tirés avec les plafonds de LevelCap (`ProceduralEncounters.level_caps`), donc le plafond avant le sceau `i` est toujours le niveau du Pokémon le plus fort du lieutenant `i`. LevelCap ne lit pas les équipes générées.
- **Ligue :** dans les salles de la Ligue de l'inventaire (`LEAGUE_ROOMS`), dans l'ordre : les quatre Anciens, le Parrain, puis Arceus, au milieu de la salle (`LEAGUE_LAYOUTS`). La porte vers la salle suivante reste fermée (un événement devant elle renvoie le joueur d'un pas, `LEAGUE_DOOR_TEXT`) tant que la salle n'est pas gagnée : chaque victoire allume l'interrupteur `LEAGUE_SWITCH + n` (59 à 64). Les victoires restent acquises : un Ancien battu ne se rebat pas après une défaite plus haut.
  - **Anciens :** types de dresseur `ANCIEN_1` à `ANCIEN_4` (« Ancien » en jeu, règle d'arène du Monotype), un type tiré chacun, jamais le même entre eux ; 5, 5, 6 et 6 Pokémon de ce type (`ELDER_PARTY_SIZES`). Le plus fort monte du plafond du dernier lieutenant à celui du Parrain (avec les plafonds par défaut : 60, 63, 66, 69).
  - **Parrain :** type de dresseur `PARRAIN`, sans type de Pokémon fixe : 6 Pokémon parmi les plus évolués du roster, de types principaux différents, le plus fort au plafond avec tous les sceaux (72).
  - **Arceus :** boss d'OverworldBoss (`ARCEUS_BOSS` : PV x3, Attaque et Attaque Spé. x1,2, Jugement, Vitesse Extrême, Soin, Force Cosmique), 5 niveaux au-dessus du Parrain (`ARCEUS_LEVEL_BONUS`). Battu ou capturé, il ouvre la porte du Panthéon et le Pacte est brisé (`ARCEUS_END`). Graphisme `boss_ARCEUS`, fait à partir de son icône.
- **Sprites de la Famille (#103) :** chaque type de dresseur de la Famille a sa copie d'un sprite d'Essentials (combat dans `Graphics/Trainers/`, déplacement dans `Graphics/Characters/trainer_*`), faite par `tools/art/family_sprites.rb` (planche : `docs/sprites/famille.png`) :

  | Rôle | Sprite | Rôle | Sprite |
  |---|---|---|---|
  | Normal | `RIVAL1` | Vol | `TAMER` |
  | Feu | `LEADER_Blaine` | Psy | `LEADER_Sabrina` |
  | Eau | `ROCKER` | Insecte | `LEADER_Koga` |
  | Plante | `POKEMONRANGER_M` | Roche | `ELITEFOUR_Bruno` |
  | Électrik | `ENGINEER` | Spectre | `CHANNELER` |
  | Glace | `SUPERNERD` | Dragon | `ELITEFOUR_Lance` |
  | Combat | `BLACKBELT` | Ténèbres | `BURGLAR` |
  | Poison | `SCIENTIST` | Acier | `CUEBALL` |
  | Sol | `BIKER` | Fée | `PSYCHIC_F` |
  | Anciens 1 à 4 | `ELITEFOUR_Agatha`, `GENTLEMAN`, `GAMBLER`, `LEADER_Surge` | Parrain | `ROCKETBOSS` |

  Des personnages à l'air menaçant ou louche, champions d'arène et Conseil 4 des jeux compris. Chacun n'existe qu'une fois : aucun dresseur de route ou de grotte (`TRAINER_TYPES`), Cousin ni PNJ (`*_GRAPHIC`) ne reprend un de ces sprites, ce que la CI vérifie (`check_world_events.rb` lit la table du script). Le vendeur des boutiques est une Cousine (`trainer_COUSIN_F`).

  Les Cousins (sbires) sont redessinés en style mafia par `tools/art/family_henchmen.py` à partir des sbires Rocket d'Essentials : tout en marron : costume à fines rayures en tweed brun, casquette plate (coppola) d'un ton plus foncé, chemise blanche et cravate bordeaux à la place du R, gants et chaussures en cuir brun foncé, boucle de ceinture dorée, cheveux noirs pour la Cousine. Le script réécrit `COUSIN_M` et `COUSIN_F` (combat et déplacement) ; les sbires Rocket d'origine restent intacts. Un sprite qui ne colle pas à son type sera recoloré dans la couleur du type (piste A de #103) : son fichier remplace la copie et sa ligne sort du script.
- **Équipes des lieutenants et de la Ligue :** seulement des Pokémon atteignables à ce niveau et avec ces sceaux, et pas encore évolués à ce niveau (`final_forms` : pas de Togepi au niveau 55).
- **Sets des lieutenants et de la Ligue :** chaque Pokémon a un vrai set écrit dans `trainers.txt` (sous-clés `Moves`, `AbilityIndex`, `Item`, `Nature`, `IV`), tiré dans ses capacités de `pokemon.txt` : celles apprises par niveau jusqu'à son niveau, les CT du jeu et, à partir de 3 sceaux (`SET_EGG_SEALS`), les capacités de reproduction de sa famille. Les CT et capacités de reproduction ont une puissance plafonnée selon les sceaux du joueur (`SET_MAX_POWER` : 60 sans sceau, puis 65, 75, 80, 90, 100, 120, 120, 150), un cran plus haut pour le type du dresseur. Les 4 attaques : la meilleure du type du dresseur, celle de l'autre type du Pokémon, une de couverture, une attaque de statut à partir de 2 sceaux (`SET_STATUS`), puis les meilleures restantes ; le score tient compte de la puissance, de la précision, du STAB et de la meilleure statistique d'attaque, avec un peu de hasard. Aucune attaque exclue (recharge, deux tours, autodestruction comprises). Objet tenu selon les sceaux (`SET_ITEMS` : Baie Oran, puis Baie Sitrus et objet de type, puis Restes et Ceinture Pro, à la Ligue Orbe Vie et Ceinture Force), sans doublon dans l'équipe tant qu'il en reste. Talent caché à partir de 4 sceaux (`SET_HIDDEN_SEALS`), sinon un talent normal au hasard. Nature Rigide ou Modeste selon la meilleure attaque. IV de 10 à 30 du 1er au 8e lieutenant (`LEADER_IVS`), 31 à la Ligue. Les membres des arènes et les dresseurs des routes gardent les attaques par défaut d'Essentials.
- **Objets :** un seul tirage pour tout le monde. 1 à 2 objets par case de route (`ROUTE_ITEMS`, aucun sur une route marine : ses objets sont les butins de ses bancs de sable), 2 à 3 par ville ou île (`TOWN_ITEMS`), 1 à 2 par étage de grotte (`CAVE_ITEMS`, pas dans les grottes sombres). Chacun reçoit une source (`ITEM_SOURCES`) : au sol (une Poké Ball, d'abord au bout des impasses), caché (Cherch'Objet) ou donné par un habitant (« Don », fréquent : au moins `GIFT_SHARE` %, 40 %). L'objet suit les sceaux gagnés avant la carte (`ITEM_TABLE` : soins et Poké Balls au début, puis baies, pierres, CT, Super Bonbons, vitamines ; `TM` = une CT du jeu au hasard, jamais deux fois ni celle d'un lieutenant). Posés sur les cases accessibles de l'inventaire (`street`, `grass`, `dead_ends`, sol des grottes), jamais sur une sortie, une porte ou dans la vue d'un dresseur. Un objet ramassé ne revient pas (Essentials), un habitant ne donne qu'une fois (`Once`).
- **Butin des recoins :** chaque recoin (poche, îlot, paroi du Grappin, grotte sombre) a son objet sur sa case de butin, tiré dans `NOOK_TABLE` (plus rare) selon les sceaux gagnés quand il s'ouvre : ceux de sa carte, ou le sceau qui donne l'objet de terrain qui l'ouvre si c'est plus tard.
- **Objets de terrain :** chaque objet de terrain (Machette, Lanterne, Pioche, Harnais, Grappin, Vol, Surf, Plongée) est donné par un membre de la Famille dans la ville de l'inventaire, une fois le lieutenant de cette ville battu (`When` sur son interrupteur) ; avant, il dit `FIELD_WAIT`. Pas d'exemplaire en plus sur la carte.
- **CT de météo (#120) :** quand le type imposé (Monotype) joue avec une météo, ses CT et sa roche sont placées dans 85 % des parties (`WEATHER_CHANCE`), une fois chacune, à la place d'autres objets. La CT qui lance la météo vient en premier. Elles occupent au plus la moitié des recoins, répartis le long du chemin, et le reste va aux autres objets. Il n'y a rien de plus si un lieutenant donne déjà la CT. Dans les 15 % restants, la météo peut ne pas apparaître.

  | Météo | Types | Objets (`WEATHER_ITEMS`) |
  |---|---|---|
  | Pluie | Eau, Électrik, Vol | CT18 Danse Pluie, CT25 Fatal-Foudre, CT102 Vent Violent, CT103 Ball'Météo, Roche Humide |
  | Soleil | Feu, Plante | CT11 Zénith, CT22 Lance-Soleil, CT103 Ball'Météo, Roche Chaude |
  | Sable | Roche, Sol, Acier | CT37 Tempête de Sable, CT103 Ball'Météo, Roche Lisse |
  | Grêle | Glace | CT07 Grêle, CT14 Blizzard, CT103 Ball'Météo, Roche Glace |

  CT102 (Vent Violent) et CT103 (Ball'Météo) sont ajoutées à `items.txt`. Ball'Météo compte comme une attaque de 100 de puissance pour les CT utiles des lieutenants (`TM_POWER_OVERRIDES`).
- **Écailles Cœur :** `HEART_SCALES` (10) par partie, à la place d'autres objets, réparties à intervalles réguliers le long du chemin (toutes sources mêlées, la première tôt).
- **Encens du Pacte (#160) :** 0 à 3 par partie (`PACT_INCENSES`, tiré selon la graine), dans des recoins ou donnés par des habitants, répartis le long du chemin à la place d'autres objets (jamais d'une Écaille Cœur ni d'un objet de météo).
- **Maître des Capacités :** un dans une ville atteinte avec au plus 1 sceau (avant le 2e), puis avec au plus 4 et 7 (`RELEARNERS`), jamais deux dans la même ville, et pas dans la ville de départ si une autre convient. Il fait retrouver une capacité contre une Écaille Cœur (`pbRelearnMoveScreen`, l'Écaille n'est prise que si le Pokémon apprend). Pas de rappel depuis le menu : « Remember Move » de l'écran Résumé (MUI) ne s'affiche qu'en génération 9, et `MECHANICS_GENERATION` vaut 8.
- **Habitants :** 2 à 4 dans les rues de chaque ville (îles comprises, pas la ville de départ, `TOWN_HABITANTS`), au bord de la rue comme les dresseurs, et 1 à 2 dans chaque maison, immeuble, maison du port ou bâtiment spécial (`HOUSE_HABITANTS`), sur les cases où la démo a ses personnages (`HOUSE_SPOTS`). Ils parlent de la Famille, du Pacte ou de la vie de la région, et appellent le joueur par son nom.
- **Policiers (#122) :** dans les rues, 20 % des habitants sont des policiers (`POLICE_CHANCE`, sprite `NPC 01`, que personne d'autre ne porte). Leurs répliques viennent de la section `[policier]` de `dialogues.txt`. La plupart sont payés par la Famille et ferment les yeux, et quelques-uns enquêtent en douce (anciens désignés, Pacte, Castellane).
- **Textes :** tous dans `MapProc/Lore/dialogues.txt`, une section par rôle (habitant, dresseurs, Cousins, professeur, vendeur, Maître des Capacités, dons, objets de terrain, lieutenants, membres, Anciens, Parrain, Arceus, portes de la Ligue). Chaque PNJ tire une réplique de sa section, jamais deux fois la même dans une partie tant qu'il en reste ; « | » coupe une réplique en plusieurs boîtes de message. Jetons : `{joueur}` (le nom du joueur, `\PN`), `{ville}`, `{region}`, `{type}` (professeur), chacun permis seulement dans certaines sections (`DIALOGUE_SECTIONS`) : les répliques dites en combat (`*_fin`, texte de défaite) ne peuvent pas nommer le joueur (Essentials ne remplace pas `\PN` en combat), celles dites en jeu (professeur, vendeur...) ne connaissent ni ville ni région. Une section inconnue, un jeton inconnu ou interdit, une section absente ou vide arrêtent la génération avec le fichier et la ligne. Les répliques dites en jeu (professeur, vendeur, Maître des Capacités, portes, fin d'Arceus) sont lues au moment où elles sont dites.
- **Garde des sorties :** sur la rangée intérieure de chaque sortie de la ville de départ, un événement invisible renvoie le joueur d'un pas en arrière (« Tu ne peux pas partir sans Pokémon ») tant que la variable 7 (« Starter choice ») vaut 0. Le starter pris, elle vaut 1 à 3 et la garde disparaît.

### Fichiers
| Fichier | Rôle |
|---|---|
| `meta.txt` | Déclaration du plugin (requiert MapEvents, MapProceduralGenerator, ProceduralEncounters, Monotype, OverworldBoss). |
| `001_Settings.rb` | Places du professeur et des Poké Balls au labo, graphismes, interrupteur et variable du starter, événements des Centres, vendeur et stocks des boutiques, objets, sets, Ligue, habitants, sections de `dialogues.txt` et leurs jetons. |
| `002_Dialogues.rb` | Lecture et vérification de `MapProc/Lore/dialogues.txt`, tirage des répliques sans répétition (`Lines`), répliques dites en jeu (`say`, `line`). |
| `003_World.rb` | `WorldEvents.world_events(result, seed, zones:, encounters:, species:, tms:, caps:, dialogues:, dex:, type:)` : les plans MapEvents du monde, les équipes des dresseurs, les lieutenants, la Ligue, les objets et les habitants, en Ruby pur (vérifié par la CI). |
| `004_Trainers.rb` | Dresseurs et Cousins : places, types, noms, équipes. |
| `005_Gyms.rb` | Lieutenants et membres des arènes (type favori, équipes, sceau et CT), Anciens, Parrain et Arceus. |
| `006_Sets.rb` | Sets des lieutenants et de la Ligue : lecture des capacités (`load_dex`, `pokemon.txt` et `moves.txt`), tirage (`Sets`), sous-lignes de `trainers.txt`. |
| `007_Items.rb` | Objets : emplacements, sources, tables, butin des recoins, CT de météo, Écailles Cœur, Encens du Pacte, objets de terrain, Maîtres des Capacités. |
| `008_Runtime.rb` | Appelé par les événements en jeu : `professor`, `starter_ball`, `mart`, `gate`, `relearner`, `league_door`, `arceus`. |
| `009_Write.rb` | Liste des CT du jeu, écriture des dresseurs dans `trainers.txt` puis des plans après les cartes et les rencontres, export, retrait avec le monde. |

### Intégration
- Rien à faire : actif dès que MapProc génère un monde.
- CI : `tools/ci/check_world_events.rb` tire les événements de `monde.txt` sur `WORLD_SEEDS` graines (3 par défaut, `WORLD_SEEDS=20` ou `WORLD_SEEDS=6..8` en local). Elle vérifie que chaque plan se lit, qu'aucun événement n'est sur une sortie, une porte, la case devant une porte ou hors de l'inventaire, l'arrivée ou la sortie d'un intérieur, que le professeur est au labo ou dehors (jamais les deux), qu'il y a trois Poké Balls au labo, que chaque sortie de la ville de départ est gardée, que chaque Centre a son infirmière, son PC et sa machine et chaque boutique son vendeur, que `CENTRE_EVENTS` et `MART_STOCK` nomment des événements et des objets qui existent, que chaque route a ses dresseurs, que chaque dresseur a son équipe (taille selon les sceaux, espèces connues, niveau au plus au plafond, un seul par type et nom), que les plus forts dresseurs d'un tronçon ne sont jamais plus faibles que ceux du tronçon d'avant, que la vue d'un dresseur n'atteint ni sortie ni porte, que chaque arène a son lieutenant (types tous différents, équipe de son type, plus fort au plafond, CT utile de son type et jamais deux fois la même) et 2 à 4 membres de son type, qu'on ne peut pas atteindre le lieutenant à pied sans passer dans la vue d'un membre, que les types de dresseur existent avec leurs graphismes et leur genre, que les attaques de `TM_STATUS` et `SET_STATUS` et les objets de `SET_ITEMS` existent, que chaque Pokémon des lieutenants et de la Ligue a un set de 1 à 4 attaques qu'il peut connaître (niveau, CT ou reproduction sous le plafond de puissance), une attaque du type du dresseur s'il en apprend une par niveau, un talent caché seulement s'il en a un et un objet qui existe, que la Ligue a ses quatre Anciens (types différents), son Parrain et Arceus dans l'ordre des salles, chaque porte fermée par l'interrupteur de sa salle, des niveaux croissants au-dessus du dernier lieutenant, le Parrain au plafond, que chaque recoin a son butin, que chaque objet de terrain est donné dans sa ville après son sceau, qu'il y a `HEART_SCALES` Écailles Cœur, que les Encens du Pacte sont au plus le nombre tiré et seulement dans des recoins ou des dons, un Maître des Capacités avant le 2e sceau, que chaque don est unique et que les dons atteignent `GIFT_SHARE` %, que les objets des tables et les graphismes existent, que `dialogues.txt` se lit (avec le fichier et la ligne de l'erreur sinon), qu'aucune réplique n'est redite avant que sa section soit épuisée, que chaque ville (sauf la première) a ses habitants et chaque maison 1 à 2, que les cases de `HOUSE_SPOTS` sont libres et ne coupent aucun passage, et que la même graine redonne les mêmes événements.

### Points d'accroche Essentials (alias, aucun script de base modifié)
`MapProceduralGenerator.generate_world`, `generate_world_maps`, `remove_world_now` et `delete_exports` (après ProceduralEncounters, d'où le `Requires`) ; `Compiler.compile_trainers` ; `TrainerBattle.start_core` (combat double en simple avec un seul Pokémon en état).

### À vérifier au premier lancement
- Au labo : les Poké Balls ne proposent rien avant d'avoir parlé au professeur, puis chacune propose son starter ; celle qui est prise disparaît, les autres ne donnent plus rien.
- Sans labo : le professeur dehors propose la liste des trois starters.
- Les dresseurs repèrent le joueur et combattent avec l'équipe tirée ; les Cousins et Cousines ont le graphisme de la Team Rocket. Recompiler les PBS (Ctrl au lancement) la première fois, pour les nouveaux types de dresseur.
- Au Centre : l'infirmière soigne avec l'animation de la machine ; le PC s'ouvre. À la boutique : le vendeur accueille au nom de la Famille et vend le stock du tronçon.
- À l'arène : le membre posé sur le chemin repère le joueur et force le combat ; le lieutenant se bat avec la règle d'arène du Monotype, remet sa chevalière (badge dans la carte dresseur) puis la CT ; lui reparler ne redonne rien.
- Habitants : ils parlent avec le nom du joueur à la place de `{joueur}` ; dans les maisons, ils ne bloquent pas le passage.
- Sets : dans le combat d'un lieutenant ou de la Ligue, les Pokémon ont les attaques, l'objet et le talent du `_dresseurs.txt` exporté.
- Ligue : la porte d'une salle renvoie en arrière avant la victoire, puis s'ouvre ; les Anciens et le Parrain combattent avec la règle d'arène du Monotype ; Arceus se bat en boss (pas de fuite), puis disparaît et ouvre le Panthéon.
- Objets : une Poké Ball au sol se ramasse et ne revient pas ; un objet caché se trouve avec le Cherch'Objet ; un habitant donne son objet une fois, puis dit sa phrase d'après. Le membre de la Famille de l'objet de terrain refuse avant le sceau de la ville, puis le donne.
- Maître des Capacités : sans Écaille Cœur il refuse ; avec, il ouvre l'écran des capacités, et l'Écaille n'est prise que si une capacité est apprise.
- Avant le starter, marcher sur une sortie de la ville de départ affiche le message et fait reculer d'un pas ; après, la sortie est libre (aussi après une sauvegarde et un rechargement).

### Limites connues
- Un habitant passe son tour s'il n'a pas de place au bord de la rue : son objet devient caché.
- L'infirmière garde les textes anglais de la démo (copie telle quelle). Les types de dresseur gardent leurs noms anglais d'Essentials (Youngster...).
- Pas de dresseur sur les îles ni dans les routes sous-marines.
- Un dresseur posé au bord du chemin pourrait, rarement, boucher un passage étroit vers des hautes herbes ou un cul-de-sac (la CI ne refait pas le chemin à pied avec les dresseurs en place).

## F16. Historique des parties (RunHistory)
**Statut :** v1.1.1, écrit, **non testé en jeu**. Issue #48.
**Version cible :** Essentials v21.1. Dépend de Nuzlocke, Monotype, MapProceduralGenerator et WorldEvents (`Requires`).
**Dossier :** `Plugins/RunHistory/`

### Règles
- **Une entrée par partie :** un identifiant est tiré à la nouvelle partie et gardé dans la sauvegarde (`$run_history_id`). L'entrée garde la graine du monde, le nom de la région, le type imposé (Monotype), le dernier lieu, l'équipe (espèce, surnom, niveau, mort au Nuzlocke), le temps de jeu et les dates.
- **Quand :** une seule partie à la fois, comme dans les jeux. À chaque sauvegarde, l'entrée de la partie est créée ou mise à jour (« En cours ») ; une partie jamais sauvegardée n'entre pas dans l'historique, même perdue ou gagnée. L'entrée est figée quand la partie se termine :
  - **Défaite :** le run Nuzlocke est perdu (plus aucun Pokémon en vie), avec l'équipe d'avant l'enterrement des derniers morts ;
  - **Victoire :** Arceus est battu ou capturé à la Ligue ;
  - **Abandon :** une nouvelle partie est sauvegardée par-dessus une partie encore en cours.
- **Combien :** les `SIZE` (20) dernières parties, la plus récente en premier.
- **Où :** dans `RunHistory.rxdata`, à côté du fichier de sauvegarde (jamais dans le dossier du jeu) : une nouvelle version du jeu ou le launcher (#52) ne l'efface pas, et il survit à la suppression du monde.
- **Écran titre :** un panneau « Dernières parties » sous « New Game » montre la dernière partie avant celle de la sauvegarde : région, type, issue et les icônes de son équipe (un Pokémon mort au Nuzlocke est pâli). Les panneaux défilent pour suivre le choix. Le choisir ouvre la liste de toutes les parties : une carte par partie (mêmes informations), `CARDS_SHOWN` (3) à l'écran, Haut et Bas pour choisir, Valider pour les détails (graine, date, temps de jeu, dernier lieu, équipe avec « (mort) »), Retour pour revenir.
- **Score :** chaque partie a un score, calculé à chaque enregistrement (réglages dans `001_Settings.rb`) :
  - progression : 100 par sceau, 150 par Ancien, 300 pour le Parrain, 500 pour Arceus (interrupteurs `LEAGUE_SWITCH` + 1 à 6) ;
  - combats : 5 par dresseur battu, 20 par membre d'arène (événement MapEvents « Membre ») ; lieutenants, Anciens et Parrain ne comptent que par leur sceau ou interrupteur ;
  - −25 par Pokémon mort (boîtes Cimetière et équipe) ;
  - victoire seulement : bonus de vitesse `max(0, 1000 − minutes de jeu)` ;
  - puis × le multiplicateur du type (`TYPE_MULTIPLIERS`, tous à 1,0 pour l'instant), × 0,5 sans Nuzlocke (marqué « sans Nuzlocke » dans les détails) ; jamais sous 0 ;
  - une défaite ou un abandon garde le score atteint.
- **Où voir le score :** à droite de chaque carte (panneau de l'écran titre, liste), dans les détails d'une partie, et pour la partie en cours sur la carte de dresseur (ligne « Score » ajoutée sous le n° ID). Dans la liste, Gauche ou Droite bascule sur les `BEST_SIZE` (5) meilleurs scores de tous les temps, le meilleur en premier : le fichier les garde même au-delà des 20 dernières parties.
- **Rejouer cette graine :** après les détails d'une partie, le joueur peut lancer une nouvelle partie dans la même région (même graine, `MapProceduralGenerator.next_game_seed`). Le type imposé et le reste sont tirés à nouveau.

### Fichiers
| Fichier | Rôle |
|---|---|
| `meta.txt` | Déclaration du plugin. |
| `001_Settings.rb` | Nom du fichier, nombre de parties gardées, noms des issues. |
| `002_Data.rb` | Entrées (`Entry`, `Member`), lecture et écriture du fichier, `record`, `abandon`, identifiant de partie dans la sauvegarde. |
| `003_Hooks.rb` | Enregistrement à la sauvegarde, à la défaite Nuzlocke et à la victoire contre Arceus ; abandon. |
| `004_Screen.rb` | Panneau « Dernières parties » de l'écran titre, détails d'une partie, commande insérée sous New Game. |
| `005_List.rb` | Liste de toutes les parties (`ListScene`), une carte avec les icônes de l'équipe par partie ; vue « Meilleurs scores ». |
| `006_Score.rb` | Score d'une partie, dresseurs et membres d'arène battus (`$run_history_wins`, dans la sauvegarde), ligne « Score » de la carte de dresseur. |

### Points d'accroche Essentials (alias, aucun script de base modifié)
`MapProceduralGenerator.next_game_seed=` (graine de la prochaine partie, ajoutée en v0.25.0), `Game.save`, `Nuzlocke.bury_dead_party_members`, `WorldEvents.arceus`, `PokemonLoad_Scene#pbStartScene`, `#pbChoose` et `#pbUpdate`, `TrainerBattle.start_core` (après l'alias de Monotype), `PokemonTrainerCard_Scene#pbDrawTrainerCardFront`.

### À vérifier au premier lancement
- Après une sauvegarde, la liste des dernières parties montre la partie « En cours » (le panneau de l'écran titre, lui, montre la précédente) ; une partie jamais sauvegardée n'y est pas.
- À l'écran titre, le panneau « Dernières parties » apparaît sous « New Game » avec les icônes de l'équipe de la partie précédente ; descendre jusqu'à « Quit Game » fait défiler les panneaux. Le choisir ouvre la liste, Haut et Bas la font défiler.
- Perdre le run Nuzlocke : l'entrée passe en « Défaite » avec l'équipe d'avant la mort.
- Nouvelle partie puis sauvegarde : l'ancienne partie passe en « Abandon ».
- Battre un dresseur puis un membre d'arène : le score de la carte de dresseur monte de 5 puis de 20 ; battre le lieutenant ajoute 100 (le sceau), pas 5.
- Dans la liste, Gauche/Droite affiche « Meilleurs scores » ; les détails montrent le score et « (sans Nuzlocke) » en mode normal.
- « Rejouer cette graine » lance une nouvelle partie dont la console affiche la même graine, avec la même région.

### Limites connues
- Sans Nuzlocke actif, une partie ne se termine que par la victoire ou l'abandon.
- Un fichier `RunHistory.rxdata` écrit par la v1.0.0 (sans score) n'est plus lisible : l'historique repart de zéro.
- Les dresseurs battus avant la v1.1.0 dans une sauvegarde existante ne sont pas comptés.

## F17. Serveur des salons (multijoueur)
**Statut :** v1.0.0, écrit et testé hors jeu (tests d'intégration), **non déployé**. Spec #141, ticket #142, ADR 0002.
**Dossier :** `online/server/` (Worker Cloudflare en JavaScript, hors du jeu).

### Règles
- **Clé de groupe :** chaque requête porte `Authorization: Bearer <GROUP_KEY>` ; sans elle, rien n'est possible (le jeu reste privé).
- **Créer un salon :** `POST /rooms` avec le pseudo, le code secret de l'hôte et les règles (`nuzlocke` : `required`/`free`, `typeDraw` : `required`/`free`, `sameType` : `true`/`false`). Renvoie un code de 6 caractères sans 0/O ni 1/I/L. Un Durable Object par salon tire la graine (0 à 999 999, comme MapProc).
- **Voir un salon :** `GET /rooms/<code>` donne les règles, si la partie a démarré et les joueurs (connectés ou non).
- **Rejoindre :** WebSocket sur `/rooms/<code>/ws?name=&secret=`. L'identifiant d'un joueur vient de son code secret : deux pseudos identiques restent distincts, et le même code secret retrouve sa place (nouvelle connexion, retour après une coupure). 8 joueurs au plus ; après le départ, seuls les joueurs déjà inscrits peuvent revenir.
- **Messages reçus :** `welcome` (son identifiant, l'hôte, les règles, la graine), `presence` (joueurs, connectés, `allConnected`), `start` (graine et règles), `event` (événement d'un autre joueur), `error`.
- **Messages envoyés :** `event` (objet libre de 8 Ko au plus, relayé aux autres joueurs) et `start` (hôte seulement, quand tout le monde est connecté).
- **Coût :** API Hibernation des WebSockets, donc un salon au repos ne consomme pas de durée.

### Offre gratuite de Cloudflare (vérifiée le 27/10/2026)
100 000 requêtes par jour (un message reçu compte pour 1/20 de requête, les messages envoyés sont gratuits), 13 000 Go-s de durée par jour, 5 millions de lignes SQLite lues et 100 000 écrites par jour, 5 Go stockés. Remise à zéro à minuit UTC. Un salon de 4 joueurs reste très loin de ces limites.

### Fichiers
| Fichier | Rôle |
|---|---|
| `src/index.js` | Clé de groupe, création d'un salon, aiguillage vers le Durable Object. |
| `src/room.js` | Le salon : règles, graine, joueurs, présence, départ, relais des événements. |
| `src/protocol.js` | Règles du protocole (codes, règles du salon, pseudos, identifiants). |
| `test/room.test.js` | Tests d'intégration (`npm test`, runtime Workers local). |
| `wrangler.jsonc` | Configuration du Worker et migration du Durable Object (SQLite). |

## F18. Partie multi (Online et pont local)
**Statut :** Online v1.5.0 écrit, **non testé en jeu** ; pont testé hors jeu (tests et essai à deux ponts contre le serveur local). Spec #141, ticket #143, ADR 0002.
**Dossiers :** `Plugins/Online/` (jeu), `online/bridge/` (pont Node.js 22.4 ou plus, repris plus tard par le launcher #52).

### Règles
- **Pont :** `node online/bridge/src/cli.js create --name Tom [--nuzlocke required] [--type-draw required] [--same-type]` crée un salon et affiche son code ; `node online/bridge/src/cli.js join <code> [--name Léo]` le rejoint. Le pseudo n'est demandé qu'une fois : il est gardé avec un code secret dans `%APPDATA%/TypeLocked/online/player.json`. L'adresse du serveur (`SERVER_URL`), la clé de groupe (`GROUP_KEY`) et le port (`BRIDGE_PORT`) sont lus dans `Plugins/Online/001_Settings.rb` : le jeu et son pont se règlent au même endroit. Par défaut, ce sont ceux du serveur local (`online/serveur-local.bat` à double-cliquer : installe les dépendances la première fois puis lance `npm run dev`, clé `test`), donc un essai en local ne demande aucune configuration. `online/test-multi.bat` ouvre d'un coup le serveur local, le pont de l'hôte qui crée le salon (règles en tête du fichier) et celui d'un 2e joueur simulé qui le rejoint (dossier `online/joueur2/`, port 47121) ; il reste à lancer une Nouvelle partie puis à taper `go` chez l'hôte. `online/bridge/config.json` ou les variables `TYPELOCKED_SERVER`, `TYPELOCKED_KEY` et `TYPELOCKED_PORT` peuvent les remplacer. Quand tout le monde est connecté, l'hôte tape `go` dans la fenêtre du pont.
- **Service local :** le pont écoute sur `127.0.0.1:47120` (`BRIDGE_URL`) : `GET /state` (le salon), `GET /events?after=N` (événements des autres joueurs), `POST /event` (envoi aux autres). Il se reconnecte seul après une coupure et garde les envois faits pendant ce temps.
- **Nouvelle partie :** si le pont est dans un salon, la nouvelle partie est une **partie multi**. Tant que l'hôte n'a pas lancé, une fenêtre attend (« Salon X : en attente du lancement… », avec le nombre de joueurs connectés) ; Retour joue en solo. La graine du monde est celle du salon. Sans pont, une nouvelle partie est une partie solo, inchangée.
- **Règles du salon :** appliquées avant les choix de mode (`NewGameSetup`, ordre 5). Nuzlocke obligatoire : le mode est activé sans le choix, avec un message. Même type pour tous : le type est tiré de la graine du salon, donc identique chez chacun. Tirage obligatoire : le type de chaque joueur est tiré au hasard. Sinon, le joueur choisit comme en solo. Le Monotype reste imposé (ADR 0001).
- **Événements :** sur la carte, le jeu lit ceux des autres joueurs toutes les `POLL_INTERVAL` (0,5 s) dans `Online.inbox` ; `Online.publish(données)` les envoie. Les tickets suivants (#144 à #148) s'en servent. Si le pont ne répond pas, le jeu ne le rappelle pas avant `RETRY_AFTER` (10 s), pour ne jamais ralentir.

- **Course en direct (#144) :** toutes les `STATUS_INTERVAL` (2 s) sur la carte, le jeu compare la progression du joueur (sceaux, lieu, équipe, morts, Anciens, Parrain, Arceus, score RunHistory, run Nuzlocke perdu) à la dernière envoyée ; si elle a changé, il l'envoie au salon avec ses annonces (sceau gagné, Pokémon perdu, Ancien, Parrain, Arceus, élimination). Le serveur garde la dernière progression de chacun (`GET /rooms/<code>`, pour le launcher).
- **Annonces :** celles des autres joueurs s'affichent en haut à droite pendant `NEWS_TIME` (3 s), l'une après l'autre, jamais pendant un message, un événement ou un combat.
- **Vainqueur :** le premier à battre Arceus gagne la course ; tout le salon l'apprend. Un joueur qui perd son run Nuzlocke devient spectateur : il continue l'aventure et garde le panneau du salon.
- **Panneau du salon :** menu Pause > Salon (partie multi seulement) : pour chaque joueur (8 au plus), pseudo, hôte, absent, spectateur ou vainqueur, sceaux, morts, score, lieu et icônes de l'équipe (les morts grisés).

- **Pause du salon (#145) :** dès qu'un joueur est déconnecté, tout le salon se met en pause sur la carte (hors messages) : « Partie en pause : Léo déconnecté depuis 1:23. » Le jeu reprend seul à son retour. Le joueur coupé, lui, voit « connexion au salon perdue » (ou « le pont ne répond plus »). Après `KICK_AFTER` (5 min), l'hôte peut retirer l'absent (touche Z, avec confirmation) : les autres reprennent et l'annonce « Léo a été retiré du salon » s'affiche ; le joueur retiré l'apprend à sa reconnexion et continue en solo. Un joueur coupé depuis 5 min peut aussi quitter le salon (Retour) et jouer en solo. Le serveur garde l'heure de départ de chaque absent et refuse un retrait trop tôt.

- **Combats entre joueurs (#146) :** menu Pause > Salon, flèches pour choisir un autre joueur connecté, C puis « Un combat ». Le défi part une fois revenu sur la carte ; le défiant attend la réponse `CHALLENGE_TIME` (30 s, Retour : annuler). Le défié le voit dès qu'il est libre sur la carte (hors message, événement, menu ou combat) : « Tom te défie en combat ! Accepter ? ». Un joueur déjà en duel ou défié refuse seul (« Léo est déjà occupé »). Il faut au moins un Pokémon capable de combattre.
- **Le combat :** simple, en direct, chacun choisit ses actions ; l'autre attend (« En attente de Léo… », Retour : abandonner). Les équipes sont prises telles qu'elles sont (PV, statuts, PP, objets tenus) puis **copiées** : après le combat, l'équipe est exactement comme avant. Ni objets du Sac, ni Méga-Évolution, ni expérience, ni argent, ni évolution ; le Nuzlocke ne s'applique pas (un K.O. n'est pas une mort) ; pas de plafond de niveau. Ni météo, ni terrain, ni environnement : les deux joueurs ne sont pas sur la même carte.
- **Même combat sur les deux écrans :** les deux jeux jouent le même combat avec les mêmes nombres aléatoires (graine du défi) ; l'ordre des égalités de vitesse est tiré dans l'ordre du défiant chez les deux. Anticipation, Prédiction et Fouille marchent pour les deux camps (sinon un seul jeu tirerait un nombre). Chaque choix envoyé porte le tour et les PV des deux équipes : si l'autre jeu ne voit pas la même chose, le combat est annulé (« les deux parties ne voient plus le même combat »).
- **Fin :** victoire, défaite, abandon (Fuite ou Retour pendant l'attente : l'autre gagne), ou annulation (perdu pour personne) dès que le salon se met en pause (coupure d'un joueur ou du pont).

- **Échanges entre joueurs (#147) :** menu Pause > Salon, un joueur connecté, C puis « Un échange ». Comme un défi : réponse attendue 30 s, refus automatique si l'autre est occupé. Ensuite : celui qui propose choisit son Pokémon, l'autre le voit (« Tom propose Dracaufeu (Nv. 36) ») et choisit le sien, puis celui qui propose confirme ; les deux jeux font alors l'échange (scène d'échange d'Essentials, évolutions par échange, nom du dresseur d'origine).
- **Règles :** on ne donne qu'un Pokémon du type de celui qui le reçoit (Monotype ; grisé sinon dans l'écran d'équipe), jamais un Pokémon mort, un Œuf, un Pokémon verrouillé ni son dernier Pokémon capable de combattre. Le receveur revérifie le Pokémon reçu (type, mort) avant de choisir le sien. Un Pokémon reçu n'est pas une capture : la zone Nuzlocke n'est pas consommée (il compte seulement comme possédé dans le Pokédex, comme tout échange).
- **Coupure (échange) :** avant la confirmation, l'échange est annulé et personne ne donne rien. Après avoir donné son Pokémon, le receveur ne peut plus annuler (Retour) : celui qui propose est peut-être déjà en train d'échanger.

- **Les autres joueurs dans le monde (#148) :** un ami sur la même carte y apparaît avec son sprite du moment (marche, course, vélo…) et son pseudo au-dessus, et refait les mêmes cases que lui avec un léger retard (≈ 0,5 à 1 s). Il ne bloque pas le passage. Il disparaît quand il change de carte et réapparaît sur la nouvelle si on y est. Lui parler (C en face de lui) : « Défier / Échanger / Retour », comme depuis le panneau du salon.
- **Envoi :** la carte, les cases parcourues, la direction, le sprite et la vitesse partent toutes les `POLL_INTERVAL` (0,5 s) tant qu'ils changent, et toutes les `POS_REFRESH` (10 s) sinon. Un personnage en retard de `CATCH_UP_STEPS` (3) cases marche une vitesse plus vite ; au-delà de `MAX_STEPS` (16), il saute. Coût Cloudflare : 8 joueurs qui marchent sans arrêt font environ 2 900 requêtes par heure (un message reçu compte pour 1/20 de requête), loin des 100 000 par jour.
- **Hypothèse :** les mondes des joueurs viennent de la même graine, donc leurs numéros de carte sont les mêmes.

### Fichiers
| Fichier | Rôle |
|---|---|
| `Plugins/Online/001_Settings.rb` | Serveur, clé de groupe et port du pont (lus aussi par le pont), intervalles. |
| `Plugins/Online/002_Json.rb` | Lecture et écriture JSON (le Ruby du jeu n'a pas de bibliothèque JSON). |
| `Plugins/Online/003_Rules.rb` | Règles du salon : Nuzlocke imposé, type imposé ou commun. |
| `Plugins/Online/004_Data.rb` | Salon de la partie, dans la sauvegarde (`$online`). |
| `Plugins/Online/005_Bridge.rb` | Requêtes au pont (`HTTPLite`). |
| `Plugins/Online/006_Game.rb` | Nouvelle partie multi, attente, règles, lecture des événements. |
| `Plugins/Online/007_News.rb` | Annonces tirées de deux progressions d'un joueur. |
| `Plugins/Online/008_Race.rb` | Progression envoyée, événements reçus, vainqueur, fenêtre d'annonce. |
| `Plugins/Online/009_Panel.rb` | Panneau du salon (menu Pause). |
| `Plugins/Online/010_Pause.rb` | Pause du salon, retrait d'un absent, départ en solo. |
| `Plugins/Online/011_Duel.rb` | Défi, réponse, messages d'un duel, choix envoyés et contrôle. |
| `Plugins/Online/012_DuelBattle.rb` | Équipes envoyées et recréées, combat du duel (`Online::DuelBattle < Battle`). |
| `Plugins/Online/013_Trade.rb` | Proposition d'échange, choix des Pokémon, règles, échange (`pbStartTrade`). |
| `Plugins/Online/014_Ghosts.rb` | Position envoyée, personnages des autres joueurs sur la carte (`Online::Ghost < Game_Character`), pseudo, dialogue. |
| `online/bridge/src/*.js` | Pont : identité, configuration, connexion au salon, service local, ligne de commande. |
| `tools/ci/check_online.rb` | Contrôle CI du JSON, des règles du salon, des annonces, de la pause, des messages d'un duel et des règles et messages d'un échange, des pas des autres joueurs. |

### Points d'accroche Essentials (alias, aucun script de base modifié)
`Game.start_new` (après l'alias de MapProceduralGenerator, pour donner la graine avant le tirage du monde), `NewGameSetup.add(:online, 5)`, `EventHandlers :on_frame_update`, `MenuHandlers :pause_menu`. Duel : sous-classe de `Battle` (`pbRandom`, `pbCalculatePriority`, `pbCommandPhaseLoop`, `pbSwitchInBetween`, `pbRun`, `pbOwnedByPlayer?`, `pbCanMegaEvolve?`), gestionnaires `Battle::AbilityEffects::OnSwitchIn` d'Anticipation, Prédiction et Fouille enveloppés (après le Deluxe Battle Kit).

## F19. Textes en français (FrenchTexts)
**Version cible :** Essentials v21.1. **Statut :** écrit, non testé (#113).

### Règles
- **Langue unique :** le jeu est en français. `Settings::LANGUAGES` ne contient que « Français », donc Essentials charge `Data/messages_french_core.dat` au lancement sans demander de langue.
- **Données :** noms, catégories et entrées du Pokédex des 898 espèces, noms des formes, noms et descriptions des attaques, talents et objets, classes de dresseurs. CT/DT/CS deviennent CT01, DT01, CS01.
- **Textes des scripts :** menus, combat, Sac, PC, Pokédex, Résumé, options, boutique, Safari, Deluxe Battle Kit et Modular UI (1 987 textes traduits à la main).
- **Efficacité ×4 :** une attaque au moins quatre fois efficace affiche « C'est hyper efficace ! » (« C'est hyper efficace sur … ! » quand elle touche plusieurs cibles) au lieu de « super efficace ».
- **Surnom (Nuzlocke) :** la question devient « Surnom de … ? » ; le surnom reste obligatoire.
- **Noms en combat :** « Rattata ennemi », « Rattata sauvage », « Rattata allié » (sans article, pour éviter « de le »).

### Fichiers
| Fichier | Rôle |
|---|---|
| `Plugins/FrenchTexts/001_Battle.rb` | Message d'efficacité ×4. |
| `Plugins/FrenchTexts/002_Language.rb` | Déclare le français comme seule langue. |
| `Text_french_core/*.txt` | Textes traduits, au format « Text_<langue>_core » d'Essentials (ligne anglaise, puis ligne française). Généré. |
| `Data/messages_french_core.dat` | Fichier compilé lu par le jeu. Généré. |
| `tools/translate/manual/*.txt` | Traductions écrites à la main (textes des scripts, formes, classes de dresseurs, corrections). |
| `tools/translate/build_texts.rb` | Construit `Text_french_core/` depuis les PBS, les tables CSV de PokeAPI et les fichiers `manual/`. |
| `tools/translate/compile_texts.rb` | Compile `Text_french_core/` en `Data/messages_french_core.dat`. |
| `tools/ci/check_translations.rb` | CI : codes conservés ({1}, \\c[1], sauts de ligne) et fichier compilé à jour. |
| `Plugins/Nuzlocke/004_Nicknames.rb` | Question du surnom sans « (obligatoire) ». |

### Mettre à jour les textes
1. Modifier une traduction : éditer `tools/translate/manual/<SECTION>.txt` (ou directement `Text_french_core/`, puis reporter le changement dans `manual/` pour qu'il survive à la prochaine génération).
2. `ruby tools/translate/build_texts.rb <dossier des CSV PokeAPI>` (CSV de github.com/PokeAPI/pokeapi, `data/v2/csv`), utile seulement si les PBS changent.
3. `ruby tools/translate/compile_texts.rb`. En jeu, le menu Debug « Compile Translated Text » donne le même fichier.

### Points d'accroche Essentials (alias, aucun script de base modifié)
- `Battle::Move#pbEffectivenessMessage` (alias `__french_pbEffectivenessMessage`). Le plugin se charge avant le Deluxe Battle Kit (ordre alphabétique des dossiers), qui aliase à son tour la méthode pour ses déclencheurs.
- `Settings::LANGUAGES` redéfini (`remove_const`), lu par `Game.initialize` et l'écran de chargement.

### Limites connues
- Restent en anglais : textes du menu Debug et des éditeurs, mini-jeux, Zone de Combat, Cadeau Mystère, téléphone, lettres, rubans, et les textes des cartes de démo d'Essentials.
- Textes construits par interpolation Ruby (`_INTL("#{...}")`) : non traduisibles par fichier.
- Descriptions issues de PokeAPI : la plus récente qui tient dans la place de la version anglaise, sinon la plus courte ; à vérifier dans les fenêtres du Résumé et du Sac. 20 descriptions d'objets (lettres, objets de démo) restent en anglais.
- Les Pokédex des formes régionales reprennent l'entrée de l'espèce de base en anglais (PokeAPI ne les sépare pas).

## F20. Encens du Pacte (PactIncense)
**Version cible :** Essentials v21.1. **Statut :** écrit, non testé (#160).

### Règles
- **Objet :** Encens du Pacte (`PACTINCENSE`), poche Objets, usage unique depuis le Sac, ne se vend pas. 0 à 3 par partie, placés par WorldEvents (recoins, dons).
- **Effet :** la prochaine rencontre sauvage est un Pokémon capturable : du type imposé ou qui l'obtient en évoluant (Monotype), dans une zone libre et pas en doublon (Nuzlocke), quand ces modes sont actifs.
- **Aucun ajout :** l'encens choisit seulement parmi les Pokémon de la table de la carte pour le terrain en cours (herbe, grotte, eau, pêche), avec leurs poids et leurs niveaux.
- **Refus :** si aucune table de la carte n'a de Pokémon capturable à cette heure, ou si un encens agit déjà, il n'est pas consommé et un message le dit.
- **Attente :** si la rencontre suivante a lieu sur un terrain sans Pokémon capturable (ex. dans l'eau), l'encens attend la suivante. Il n'est dépensé qu'à la création du Pokémon : un Repousse qui annule la rencontre ne le gaspille pas.
- La rencontre reste en combat simple.

### Fichiers
| Fichier | Rôle |
|---|---|
| `Plugins/PactIncense/001_Incense.rb` | Usage depuis le Sac, choix de l'espèce, drapeau dans la sauvegarde (`$PokemonGlobal.pact_incense`). |
| `PBS/items.txt` | Objet `PACTINCENSE`. |
| `Graphics/Items/PACTINCENSE.png` | Icône provisoire (copie de l'Encens Pur). |
| `Plugins/WorldEvents/007_Items.rb` | Placement des encens dans le monde. |

### Points d'accroche Essentials (aucun script de base modifié)
- `ItemHandlers::UseInField` pour `PACTINCENSE` (FieldUse = Direct).
- `EventHandlers` `:on_wild_species_chosen` (choix de l'espèce et du niveau) et `:on_wild_pokemon_created` (encens dépensé).
- `PokemonEncounters#table` ajouté (lecture de la table de la carte), `PokemonGlobalMetadata#pact_incense`, `Game_Temp#pact_incense_species`.

### Limites connues
- Après une rencontre d'un Pokémon errant, l'encens attend la rencontre suivante.
- `PBS/items.txt` change : recompiler les PBS (mode debug) pour que l'objet existe en jeu.

## F21. Graphismes 4G (#177)
**Version cible :** Essentials v21.1. **Statut :** ticket 1 (#193 : sols, herbes, arbres) et forêts serrées écrits, **non testés en jeu**.

### Règles
- **Tileset Outside 4G** (ID 24, `Graphics/Tilesets/Outside 4G.png`) : une copie d'Outside (ID 1), utilisée par les lieux générés (`Tileset = 24`). Les tuiles 4G sont reprises **telles quelles** : tuiles entières de SirMalo (HGSS, 16 px), agrandies ×2 au plus proche voisin, jamais rognées ni redessinées. Le rose des feuilles est transparent.
- **Sols et herbes, à la même place :** herbe (`T1`-`T3`), chemin de terre et ses bords (`T97`-`T118`, `T106` sert aussi de sol « terre battue »), sable (`T162`), hautes herbes (`T6`, `T7`, `T15` et leurs copies sur prairie, sable, terre battue, minérale), buisson (`T475` et ses copies). Les `T<n>` de MapProc, les passages et les priorités ne changent pas.
- **Forêts serrées (HGSS) :** l'arbre de bordure (`t`) fait 2×2 cases, et les arbres d'une forêt se serrent tous les 2 rangs et toutes les 2 colonnes, comme dans HGSS. Ses tuiles sont la paire d'arbres de SirMalo entière (6×6 tuiles), copiée deux fois par sol : bloquante (les arbres) et praticable sous le joueur (le halo). MapGen choisit chaque case selon sa place (option `forest=`, F03), et les chevauchements sont ceux que SirMalo a dessinés. La bordure plante ses arbres d'abord sur une grille de 2×2 (MapProceduralGenerator v0.37.0) pour qu'ils s'alignent, puis là où il reste de la place. Les briques `arbre`, `bosquet` et `bosquet_large` sont à la nouvelle taille.
- **Arbres entiers, sous l'ancien tileset :** grand pin (`é`), arbre rond (`è`), arbre jaune (`ü`), cyprès (`ê`), arbrisseau (`ë`). Un arbre 4G est plus grand que le bloc que MapProc lui donne : le bloc garde sa taille et ses passages (la mise en page des lieux ne change pas) et le reste du dessin (pointe, côtés qui débordent sur les voisins) est posé sur le calque 3 par le halo de MapGen (F03), là où on marche dessous. Le grand pin est pris dans les paires de pins de SirMalo : la moitié gauche des arbres de gauche et la moitié droite des arbres de droite, qui sont le même dessin. Les cimes des anciens arbres ronds (`T484`, `T532`) sont vides.
- **Autres sols :** sur prairie, sable, terre battue et minéral, l'herbe 4G sous les arbres devient transparente et ses ombres le sol assombri (seule retouche des tuiles). Une copie de chaque arbre par sol.
- **Pas encore remplacé :** roches et falaises, bâtiments, mer, objets importés…, jusqu'aux tickets suivants de #177.
- Les cartes déjà générées gardent l'ancien tileset : regénérer le monde (nouvelle partie ou menu debug).

### Fichiers
| Fichier | Rôle |
|---|---|
| `tools/art/outside_4g.py` | Construit `Outside 4G.png` depuis `Outside.png` et les feuilles de SirMalo, donne leurs passages aux tuiles ajoutées et affiche les lignes `[Objects]` des arbres. |
| `tools/art/tileset_clone.rb` | Copie le tileset 1 vers l'ID 24 dans `Data/Tilesets.rxdata` (nom et image changés, passages et priorités gardés). |
| `Graphics/Tilesets/Outside 4G.png` | Le tileset 4G. |
| `Data/Tilesets.rxdata` | Tileset 24 « Outside 4G ». |
| `MapProc/route.txt`, `MapProc/ville.txt` | `Tileset = 24`, arbres 4G avec leur halo, arbre de forêt `t`. |
| `MapProc/Briques/arbre.txt`, `bosquet.txt`, `bosquet_large.txt` | Arbres de forêt en 2×2. |
| `Plugins/MapGenerator/002_Parser.rb`, `003_Builder.rb` | Options `halo=` et `forest=` des objets. |
| `Plugins/MapProceduralGenerator/003_Builder.rb` | Bordure plantée d'abord sur la grille de ses arbres. |

### Mettre à jour le tileset
Après un changement d'`Outside.png` ou du tileset 1 (`import_props.py`, `ground_variants.py`), relancer, depuis la racine du dépôt, puis recopier les lignes affichées dans `route.txt` et `ville.txt` si les numéros changent :
```
ruby tools/art/tileset_clone.rb 1 24 "Outside 4G" "Outside 4G"
python3 tools/art/outside_4g.py "<dossier des feuilles de SirMalo>"
```

### Limites connues
- Un arbre de forêt hors de la grille (là où la bordure n'a pas la place d'un arbre aligné) a des rangées décalées par rapport à ses voisins : il ne s'y raccorde pas, ses débords passent par-dessus.
- Deux halos sur la même case : le second va sur le calque 2. Les deux ont la même priorité ; l'ordre d'affichage entre les calques 2 et 3 est à vérifier en jeu.
- Le halo ne se pose que sur un calque 3 vide : une pointe d'arbre sous un autre objet du calque 3 n'est pas dessinée.

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
| 25/10/2026 | Pokédex des rencontres : il garde aussi les familles à moins de 5 de variété d'attaques (806 espèces) | `docs/roster/pokedex.*`, `docs/FEATURES.md` |
| 23/10/2026 | ProceduralEncounters v1.3.0 : les rencontres piochent dans tout le Pokédex (`docs/roster/pokedex.csv`, 665 espèces), 300 par monde tirées par familles équilibrantes ; `docs/roster/liste-400.*` supprimée | `Plugins/ProceduralEncounters/*`, `docs/roster/*`, `docs/FEATURES.md` |
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
| 25/10/2026 | WorldEvents v1.1.0 (#95) : infirmière, PC et machine de soin copiés des Centres de la démo, vendeur de la Famille dans chaque boutique avec un stock selon les sceaux ; MapEvents v1.3.0 (section `[Copy]`) ; contrôles CI des services | `Plugins/WorldEvents/*`, `Plugins/MapEvents/*`, `tools/ci/check_world_events.rb`, `tools/ci/check_mapevents.rb`, `docs/FEATURES.md` |
| 25/10/2026 | WorldEvents v1.2.0 (#96) : dresseurs des routes et des grottes, Cousins de la Famille sur les routes et dans les villes, équipes tirées dans les Pokémon de la zone et écrites dans `trainers.txt` (version 100) ; types `COUSIN_M` et `COUSIN_F` ; MapProceduralGenerator v0.24.1 : l'inventaire de certaines routes était vide (la rue de sortie traverse la bordure, la marche à pied s'y arrêtait), et il donne la direction de la rue (`facing`) | `Plugins/WorldEvents/*`, `Plugins/MapProceduralGenerator/003_Builder.rb`, `Plugins/MapProceduralGenerator/meta.txt`, `PBS/trainer_types.txt`, `Graphics/Trainers/COUSIN_*.png`, `Graphics/Characters/trainer_COUSIN_*.png`, `tools/ci/check_world_events.rb`, `docs/FEATURES.md` |
| 25/10/2026 | WorldEvents v1.3.0 (#97) : lieutenant dans chaque arène (type favori tiré, équipe de son type au plafond, sceau puis CT utile de son type) et 2 à 4 membres de la Famille, dont un dont la vue couvre le chemin ; contrôles CI des arènes (chemin à pied jusqu'au lieutenant) | `Plugins/WorldEvents/*`, `tools/ci/check_world_events.rb`, `docs/FEATURES.md` |
| 25/10/2026 | WorldEvents v1.4.0 (#98) : objets du monde (au sol, cachés, donnés, butin des recoins) selon les sceaux, objets de terrain donnés dans leur ville après le sceau, Écailles Cœur et Maîtres des Capacités ; MapEvents v1.4.0 (clés `When`, `Wait`, `Gift`, `Once` des PNJ) | `Plugins/WorldEvents/*`, `Plugins/MapEvents/*`, `tools/ci/check_world_events.rb`, `tools/ci/check_mapevents.rb`, `docs/FEATURES.md` |
| 25/10/2026 | WorldEvents v1.5.0 (#99) : Ligue (quatre Anciens d'un type tiré, Parrain, Arceus en boss), portes fermées jusqu'à la victoire ; équipes sans Pokémon pas encore évolués ; CT des 3 premiers lieutenants dès 50 de puissance ; graphisme `boss_ARCEUS` | `Plugins/WorldEvents/*`, `Graphics/Characters/boss_ARCEUS.png`, `tools/ci/check_world_events.rb`, `docs/FEATURES.md` |
| 25/10/2026 | WorldEvents v1.6.0 (#100) : habitants dans les rues et les maisons ; tous les textes dans `MapProc/Lore/dialogues.txt` (sections par rôle, jetons, sans répétition), vérifiés par la CI | `Plugins/WorldEvents/*`, `MapProc/Lore/dialogues.txt`, `tools/ci/check_world_events.rb`, `docs/FEATURES.md`, `docs/LORE.md` |
| 25/10/2026 | LevelCap v1.0.1, ProceduralEncounters v1.4.0 : plafond de la 5e arène ramené de 43 à 36 (la 6e reste à 43) ; fusion avec la v1.3.0 de main (tout le Pokédex) | `Plugins/LevelCap/001_Settings.rb`, `Plugins/ProceduralEncounters/001_Settings.rb`, `docs/FEATURES.md` |
| 25/10/2026 | WorldEvents v1.7.0 : vrais sets pour les lieutenants et la Ligue (attaques du type du dresseur, de couverture et de statut tirées dans les capacités par niveau, CT et reproduction sous un plafond de puissance selon les sceaux ; objet tenu, talent caché dès 4 sceaux, nature, IV 10 à 31), contrôlés par la CI | `Plugins/WorldEvents/*`, `tools/ci/check_world_events.rb`, `docs/FEATURES.md` |
| 25/10/2026 | WorldEvents v1.7.1 : les sets peuvent prendre les attaques à deux tours et d'autodestruction | `Plugins/WorldEvents/001_Settings.rb`, `Plugins/WorldEvents/meta.txt`, `docs/FEATURES.md` |
| 25/10/2026 | WorldEvents v1.7.2 : plus aucune attaque exclue des sets (`SET_BANNED` supprimé) | `Plugins/WorldEvents/*`, `tools/ci/check_world_events.rb`, `docs/FEATURES.md` |
| 25/10/2026 | WorldEvents v1.7.3 : un Pokémon sans attaque offensive (Queulorior) garde ce qu'il sait (Gribouille) | `Plugins/WorldEvents/006_Sets.rb`, `docs/FEATURES.md` |
| 25/10/2026 | RunHistory v1.0.0 (#48) : historique des 20 dernières parties (graine, région, type, dernier lieu, équipe, issue), mis à jour à chaque sauvegarde, figé à la défaite Nuzlocke, à la victoire contre Arceus ou à l'abandon (une partie jamais sauvegardée n'y entre pas) ; panneau « Dernières parties » sous New Game à l'écran titre (partie précédente et icônes de son équipe) et liste de toutes les parties, avec « Rejouer cette graine » ; MapProceduralGenerator v0.25.0 (`next_game_seed=`) | `Plugins/RunHistory/*`, `Plugins/MapProceduralGenerator/007_NewGame.rb`, `Plugins/MapProceduralGenerator/meta.txt`, `docs/FEATURES.md` |
| 25/10/2026 | Sprites de la Famille (#103) : 18 types de dresseur `LIEUTENANT_<TYPE>`, `ANCIEN_1` à `ANCIEN_4` et `PARRAIN`, sprites copiés d'Essentials ; WorldEvents v1.8.0 (le lieutenant prend le sprite de son type), Monotype v1.5.4 (règle d'arène pour ces types) | `PBS/trainer_types.txt`, `Graphics/Trainers/`, `Graphics/Characters/`, `tools/art/family_sprites.rb`, `Plugins/WorldEvents/*`, `Plugins/Monotype/*`, `tools/ci/check_world_events.rb`, `docs/FEATURES.md` |
| 25/10/2026 | RunHistory v1.1.0 : score d'une partie (sceaux, Anciens, Parrain, Arceus, dresseurs et membres d'arène battus, morts, bonus de vitesse à la victoire, multiplicateur de type, ×0,5 sans Nuzlocke), sur les cartes, dans les détails, sur la carte de dresseur et dans la vue « Meilleurs scores » (5 meilleurs de tous les temps) ; un Pokémon mort reste pâli après la défaite | `Plugins/RunHistory/*`, `docs/FEATURES.md` |
| 26/10/2026 | MapGenerator v1.10.0 (#119) : la caméra s'arrête aux bords sans carte voisine en vue, plus de noir au bord du monde | `Plugins/MapGenerator/008_EdgeCamera.rb`, `Plugins/MapGenerator/meta.txt`, `docs/FEATURES.md` |
| 26/10/2026 | MapProceduralGenerator v0.27.0, MapGenerator v1.11.0 (#119) : cartes de décor autour des lieux (forêt, mer, montagne selon le voisin), `type=decor` dans les plans du monde, raccords par les coins ; contrôles CI | `Plugins/MapProceduralGenerator/*`, `Plugins/MapGenerator/006_World.rb`, `Plugins/MapGenerator/007_RegionImage.rb`, `tools/ci/check_mapproc.rb`, `tools/ci/check_world_events.rb`, `tools/ci/check_encounters.rb`, `docs/FEATURES.md` |
| 26/10/2026 | Nuzlocke v1.3.0 (#117) : sauvegarde automatique après une défaite, panneau d'équipe du Pokémon mort avec le message de sa mort, fond « City » pour les nouvelles boîtes Cimetière | `Plugins/Nuzlocke/*`, `docs/FEATURES.md` |
| 26/10/2026 | WorldEvents v1.13.0, MapEvents v1.5.0 (#114) : infirmière de la Famille (nouvelle apparence), 3 soins gratuits par Centre puis payants selon les sceaux ; clés `Graphic` et `Confirm` des copies ; lore et glossaire | `Plugins/WorldEvents/*`, `Plugins/MapEvents/*`, `Graphics/Characters/NPC Famille infirmiere.png`, `tools/art/family_nurse.py`, `MapProc/Lore/dialogues.txt`, `tools/ci/check_world_events.rb`, `docs/LORE.md`, `GLOSSARY.md`, `docs/FEATURES.md` |
| 26/10/2026 | Début de partie (#115) : WorldEvents v1.14.0 (Pokédex donné avec le starter, Carte donnée par un Cousin non contournable de la première route), Monotype v1.6.0 (starters qui évoluent), MapProceduralGenerator v0.28.0 (cases où l'on marche dans l'inventaire) ; contrôles CI | `Plugins/WorldEvents/*`, `Plugins/Monotype/*`, `Plugins/MapProceduralGenerator/003_Builder.rb`, `Plugins/MapProceduralGenerator/009_Atlas.rb`, `MapProc/Lore/dialogues.txt`, `tools/ci/check_world_events.rb`, `tools/ci/check_pbs.rb`, `docs/FEATURES.md` |
| 26/10/2026 | MapProceduralGenerator v0.29.0 : d'après l'analyse des cartes officielles, bordures naturelles, places et avenues, plans de ville (carrefour, grille, canal, clairière), monument, sentiers sinueux, étendues de sable, rochers et bancs de sable dans les ports et les traversées, refuges sur les routes | `Plugins/MapProceduralGenerator/001_Settings.rb`, `Plugins/MapProceduralGenerator/003_Builder.rb`, `Plugins/MapProceduralGenerator/meta.txt`, `docs/FEATURES.md` |
| 26/10/2026 | MapProceduralGenerator v0.30.0, MapGenerator v1.12.0 (#111) : relief d'après les cartes officielles : niveaux en plateaux du sol de l'ambiance (rebord fin au nord, falaise sur les côtés et au sud), falaises en pente, plateaux isolés aux bords serpentants, chemins et briques sur les plateaux (niveaux dessinés sur la couche 3), villes en gradins avec jardins surélevés et escaliers larges ; massifs, buttes et recoins de roche ; terrain sans tuile intérieure (`-`) dans MapGenerator | `Plugins/MapProceduralGenerator/*`, `Plugins/MapGenerator/002_Parser.rb`, `Plugins/MapGenerator/meta.txt`, `MapProc/route.txt`, `MapProc/ville.txt`, `MapProc/Briques/rocaille_*.txt`, `tools/ci/check_mapproc.rb`, `tools/ci/check_world_events.rb`, `docs/FEATURES.md` |
| 27/10/2026 | MapProceduralGenerator v0.31.0 : routes marines (`Mers`) d'après les routes de Hoenn : mer d'un bout à l'autre, plages aux bouts, crêtes et massifs de roche sur l'eau (`RocherMarin`), rochers et bancs de sable, couloir libre pour surfer, butins sur les bancs de sable ; WorldEvents v1.15.0 (pas d'objets ordinaires sur une route marine) | `Plugins/MapProceduralGenerator/*`, `Plugins/WorldEvents/*`, `MapProc/route.txt`, `MapProc/monde.txt`, `tools/ci/check_mapproc.rb`, `docs/FEATURES.md` |
| 27/10/2026 | Serveur des salons v1.0.0 (#142) : Worker Cloudflare, un Durable Object par salon (code, règles, graine, présence, départ, relais des événements), clé de groupe ; tests d'intégration et CI | `online/server/*`, `.github/workflows/online.yml`, `docs/FEATURES.md` |
| 27/10/2026 | Online v1.0.0 et pont local (#143) : partie multi lancée depuis un salon (attente de l'hôte, graine du salon, règles imposées), lecture et envoi des événements des joueurs ; pont Node.js (identité, connexion, service local) ; contrôle CI | `Plugins/Online/*`, `online/bridge/*`, `tools/ci/check_online.rb`, `.github/workflows/*`, `docs/FEATURES.md` |
| 27/10/2026 | Online v1.1.0 (#144) : course en direct (progression envoyée quand elle change, annonces des autres joueurs, vainqueur, spectateur), panneau du salon dans le menu Pause ; le serveur garde la dernière progression de chaque joueur | `Plugins/Online/*`, `online/server/src/room.js`, `online/server/test/room.test.js`, `tools/ci/check_online.rb`, `docs/FEATURES.md` |
| 27/10/2026 | Online v1.2.0 (#145) : pause de tout le salon pendant une coupure, retrait d'un absent par l'hôte après 5 minutes, départ en solo d'un joueur coupé ; serveur et pont : heure de départ des absents, retrait | `Plugins/Online/*`, `online/server/src/*`, `online/bridge/src/*`, tests, `tools/ci/check_online.rb`, `docs/FEATURES.md` |
| 27/10/2026 | Online v1.3.0 (#146) : combats en direct entre joueurs (défi depuis le panneau du salon, même combat sur les deux écrans par graine partagée et choix échangés, équipes copiées, abandon, annulation à la coupure ou en cas de désaccord) | `Plugins/Online/*`, `tools/ci/check_online.rb`, `docs/FEATURES.md` |
| 27/10/2026 | Online v1.4.0 (#147) : échanges entre joueurs depuis le panneau du salon (type du receveur, ni mort ni Œuf ni dernier Pokémon, pas une capture, annulés à la coupure) | `Plugins/Online/*`, `tools/ci/check_online.rb`, `docs/FEATURES.md` |
| 27/10/2026 | Online v1.5.0 (#148) : les autres joueurs visibles sur la même carte (sprite, pseudo, déplacements suivis), leur parler propose un combat ou un échange | `Plugins/Online/*`, `tools/ci/check_online.rb`, `docs/FEATURES.md` |
| 27/10/2026 | Monotype v1.7.0 : les starters sont tirés dans tout le Pokédex des rencontres (806 espèces, 481 starters possibles au lieu de 176) et plus dans la liste des 300 | `Plugins/Monotype/*`, `tools/ci/check_pbs.rb`, `docs/FEATURES.md` |

| 27/10/2026 | MapProceduralGenerator v0.32.0 (#110) : 49 objets de décor tirés de tilesets libres (Emerald Outdoors, KingTapir) pour les ambiances (tileset Outside T4216 à T4383), 21 briques de décor ; le décor obligatoire se pose après les autres briques obligatoires | `Plugins/MapProceduralGenerator/003_Builder.rb`, `tools/art/import_props.py`, `docs/CREDITS.md`, `Graphics/Tilesets/Outside.png`, `Data/Tilesets.rxdata`, `MapProc/ville.txt`, `MapProc/route.txt`, `MapProc/Briques/*`, `docs/FEATURES.md` |
| 27/10/2026 | MapProceduralGenerator v0.34.0 (#162) : passe large dans les packs, 57 objets de plus (Emerald Outdoors, KingTapir Galar Misc, Stow-on-Side, Agate Village, Alola Misc ; tileset Outside jusqu'à T4895), 21 briques de décor par ambiance, 8 de rue (`lampe`) et 6 de place (`foire`) | `tools/art/import_props.py`, `docs/CREDITS.md`, `Graphics/Tilesets/Outside.png`, `Data/Tilesets.rxdata`, `MapProc/ville.txt`, `MapProc/route.txt`, `MapProc/Briques/*`, `docs/FEATURES.md` |
| 27/10/2026 | MapProceduralGenerator v0.34.1 (#162) : la brique `cypres` (rangée de cyprès, verdoyante et prairie) écrasée par la passe large est rétablie ; les cyprès d'Alola passent dans `cypres_alola` | `MapProc/Briques/cypres.txt`, `MapProc/Briques/cypres_alola.txt`, `docs/FEATURES.md` |
| 27/10/2026 | MapProceduralGenerator v0.35.0 (#162) : génération 3 à 5 fois plus rapide, mêmes mondes pour une même graine | `Plugins/MapProceduralGenerator/003_Builder.rb`, `Plugins/MapProceduralGenerator/004_World.rb`, `docs/FEATURES.md` |
| 01/11/2026 | MapProceduralGenerator v0.35.1 : le constructeur des lieux (`003_Builder.rb`, 2 200 lignes) est découpé en six fichiers par thème (cœur, rues, briques, mer et port, traversées, relief), sans changer le code : mêmes mondes pour une même graine ; outil `tools/ci/world_fingerprint.rb` qui donne l'empreinte des mondes de quelques graines, pour vérifier qu'une refonte ne les change pas | `Plugins/MapProceduralGenerator/003_Builder*.rb`, `Plugins/MapProceduralGenerator/meta.txt`, `tools/ci/world_fingerprint.rb`, `tools/ci/check_mapproc.rb`, `tools/ci/check_encounters.rb`, `tools/ci/check_world_events.rb`, `docs/FEATURES.md` |
| 06/11/2026 | FrenchTexts v1.0.0 : jeu en français (données PokeAPI, textes des scripts, message ×4) ; Nuzlocke v1.3.1 (#113) : « C'est hyper efficace ! » pour une attaque ×4, question du surnom sans « (obligatoire) » | `Plugins/FrenchTexts/*`, `Text_french_core/*`, `Data/messages_french_core.dat`, `tools/translate/*`, `tools/ci/check_translations.rb`, `.github/workflows/ci.yml`, `Plugins/Nuzlocke/004_Nicknames.rb`, `Plugins/Nuzlocke/meta.txt`, `docs/FEATURES.md` |
| 06/11/2026 | PactIncense v1.0.0 et WorldEvents v1.16.0 (#160) : Encens du Pacte, la prochaine rencontre sauvage est capturable ; 0 à 3 par partie dans les recoins et les dons | `Plugins/PactIncense/*`, `Plugins/WorldEvents/*`, `PBS/items.txt`, `Graphics/Items/PACTINCENSE.png`, `tools/ci/check_world_events.rb`, `docs/FEATURES.md` |
| 06/11/2026 | Graphismes 4G, ticket 1 (#193, #177) : tileset Outside 4G (ID 24), herbe, chemins, sable et hautes herbes HGSS (SirMalo) à la place des anciennes tuiles, arbres 4G entiers ajoutés sous le tileset ; les lieux générés l'utilisent (MapProceduralGenerator v0.36.0) ; MapGenerator v1.13.0 : option `halo=` des objets, un dessin plus grand que le bloc posé sur le calque 3 | `tools/art/outside_4g.py`, `tools/art/tileset_clone.rb`, `Graphics/Tilesets/Outside 4G.png`, `Data/Tilesets.rxdata`, `MapProc/route.txt`, `MapProc/ville.txt`, `Plugins/MapGenerator/*`, `Plugins/MapProceduralGenerator/meta.txt`, `docs/CREDITS.md`, `docs/FEATURES.md` |
| 06/11/2026 | Forêts 4G serrées façon HGSS (#223) : arbre de bordure `t` en 2×2 tiré de la paire d'arbres de SirMalo, arbres tous les 2 rangs ; MapGenerator v1.14.0 : option `forest=` des objets (chaque case dessinée selon sa place dans la forêt) ; MapProceduralGenerator v0.37.0 : bordure plantée d'abord sur une grille | `tools/art/outside_4g.py`, `Graphics/Tilesets/Outside 4G.png`, `Data/Tilesets.rxdata`, `MapProc/route.txt`, `MapProc/ville.txt`, `MapProc/Briques/arbre.txt`, `MapProc/Briques/bosquet.txt`, `MapProc/Briques/bosquet_large.txt`, `Plugins/MapGenerator/*`, `Plugins/MapProceduralGenerator/003_Builder.rb`, `Plugins/MapProceduralGenerator/meta.txt`, `docs/FEATURES.md` |
