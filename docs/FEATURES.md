# Fonctionnalités

## F01. Mode Nuzlocke
**Statut :** v1.1.2, écrit, **non testé**.
**Version cible :** Essentials v21.1.
**Dossier :** `Plugins/Nuzlocke/`

### Règles
- **Activation :** choix unique et définitif, proposé automatiquement au début de la partie par le plugin Monotype (ou `Nuzlocke.setup_dialog` dans un événement).
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
| `006_Setup.rb` | Fenêtre de choix du début de partie. |
| `007_Storage.rb` | Verrous du PC sur les Pokémon morts. |
| `008_FieldPoison.rb` | Poison hors combat. |

### Intégration
- Début de partie : la fenêtre s'affiche seule (déclenchée par le plugin Monotype). `Nuzlocke.setup_dialog` reste utilisable dans un événement.
- Regrouper des cartes : `Nuzlocke::ZONE_GROUPS = { id_secondaire => id_principal }`.

### Points d'accroche Essentials (alias/prepend, aucun script de base modifié)
`pbStartBattle`, `pbThrowPokeBall`, `pbStorePokemon` (sur `Battle` et `SafariBattle`, qui n'hérite pas de `Battle`), `Battle::Battler#pbFaint`, `ItemHandlers.triggerCanUseInBattle`, `pbNickname`, `Pokemon#hp=`, `Pokemon#heal_HP`, `PokemonStorageScreen#pbWithdraw/pbPlace/pbSwap/pbRelease`, handlers `:on_end_battle` et `:poison_party` (remplacé).

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
**Statut :** v1.6.0, écrit, testé hors jeu sur les données du dépôt, **non testé en jeu**.
**Version cible :** Essentials v21.1.
**Dossier :** `Plugins/MapGenerator/`, plans dans `MapGen/*.txt` (exemples : `MapGen/exemple.txt`, `MapGen/exemple_calques.txt`, `MapGen/exemple_porte_dehors.txt` + `MapGen/exemple_porte_maison.txt`, `MapGen/place_ville.txt`).

### Fonctionnement
- Un plan texte décrit la carte : un caractère par case, une légende qui associe chaque caractère à 1 à 3 calques.
- Calques : `T<n>` = tuile n du tileset (n = ligne × 8 + colonne), `A1` à `A7` = autotile (raccords calculés automatiquement), `-` = vide, `T1|T2|T3` = variante au hasard (`Seed` pour un résultat reproductible).
- Objets multi-cases (section `[Objects]`) : `H = T400 3x4` déclare un bloc de 3×4 tuiles à partir de la tuile 400. Dans `[Map]`, le symbole couvre toute la surface de l'objet (`HHH` sur 4 lignes). Une zone plus grande contient plusieurs copies, découpées depuis le coin haut-gauche (`HHHHHH` sur 4 lignes = deux objets). Une zone incomplète provoque une erreur qui indique la case fautive. Options : `L1` à `L3` pour le calque (`L2` par défaut), `@<symbole>` pour le sol sous l'objet (sinon la clé `Ground`).
- Grilles de calques (sections `[Layer2]` et `[Layer3]`, facultatives, même taille que `[Map]`) : dessinées par-dessus `[Map]`. `.` = rien ; un symbole de `[Legend]` est posé à partir de ce calque (un symbole à 2 calques dans `[Layer2]` remplit les calques 2 et 3) ; un objet de `[Objects]` est posé sur ce calque, quel que soit son `L`.
- Terrains à raccords automatiques (section `[Terrains]`) : `P = T274 N=T266 S=T282 W=T273 E=T275 NW=T265 NE=T267 SW=T281 SE=T283 iNW=T286 iNE=T284 iSW=T270 iSE=T268` déclare la tuile intérieure, les bords, les coins et les angles rentrants (`i…`). Dans la grille, on écrit seulement `P` : chaque case reçoit la tuile qui correspond à ses voisines. Un rôle absent prend la tuile intérieure. Options : `with=D` (terrains qui se raccordent sans bord), `L1` à `L3` (calque dans `[Map]`, `L1` par défaut), `@<symbole>` (sol dessous si le calque n'est pas `L1`). Un terrain marche aussi dans `[Layer2]` / `[Layer3]`.
- Portes et étages (sections `[Warps]` et `[Events]`) : `1 = Maison 1 4,7 haut` déclare une téléportation vers la carte nommée « Maison 1 » (ou son ID), case 4,7 (comptée depuis 0), regard vers le haut (`haut`, `bas`, `gauche`, `droite`, ou direction conservée). La grille `[Events]` (même taille que `[Map]`, `.` = rien) place ces symboles. Chaque porte devient un événement « MapGen warp » (contact du joueur, commande « Téléporter le joueur ») ; Essentials le transforme en porte animée à la compilation si la case ressemble à une entrée. À chaque génération, les anciens « MapGen warp » de la carte sont remplacés. Avec « Tous », une porte vers une carte générée plus tard dans la même série est reliée après coup.
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

### Points d'accroche Essentials
Aucun alias. Utilise `TileDrawingHelper::NEIGHBORS_TO_AUTOTILE_INDEX` (même table que le rendu d'Essentials) et `MenuHandlers.add(:debug_menu, ...)`.

### Limites connues
- Pas encore d'import PNG (1 pixel = 1 case) ni de génération procédurale.
- Un terrain choisit un seul angle rentrant par case : une case entourée de plusieurs angles rentrants prend le premier (haut-gauche, haut-droite, bas-gauche, bas-droite).

## F04. Mode Monotype
**Statut :** v1.3.0, écrit, **non testé**.
**Version cible :** Essentials v21.1.
**Dossier :** `Plugins/Monotype/`

### Règles
- **Activation :** choix unique et définitif, proposé automatiquement en début de partie (après le choix Nuzlocke), au premier pas du joueur ou juste avant le premier Pokémon reçu. **Normal** : le type est tiré au hasard. **Facile** : le joueur choisit parmi les 18 types.
- **Capture :** seuls les Pokémon qui ont le type imposé (simple ou double type), ou dont une évolution l'a, sont capturables (ex. Eau : Azurill grâce à Marill, Évoli grâce à Aquali). Les Poké Balls sont grisées, ou rendues en combat double si la cible n'est pas capturable. Le type compte pour la forme (Motisma Lavage = Électrik/Eau).
- **Évolutions :** le sens inverse ne compte pas. Un Pokémon qui perd le type en évoluant (Évoli → Pyroli en Eau) devient inutilisable et part au PC.
- **Dons et échanges hors du type :** envoyés directement au PC, présents mais inutilisables.
- **Inutilisable :** ne peut pas quitter le PC pour l'équipe. Un Pokémon inutilisable dans l'équipe (évolution, échange, Pension) est envoyé au PC à la fin du combat ou au pas suivant.
- **Starter :** le premier Pokémon reçu reste utilisable jusqu'à la première capture (Concours de Capture compris). Il n'est jamais utilisable dans une arène ni à la Ligue : avant le combat contre un dresseur d'arène, un champion, un membre du Conseil 4 ou le Maître, sa période de grâce prend fin et il retourne au PC. Sans Pokémon du type dans l'équipe, le message « Seuls les Pokémon de type X peuvent combattre dans les arènes et à la Ligue » s'affiche à la place du combat, et le dresseur n'est pas battu.
- **CT et capacités :** aucune restriction de type, seulement celles des Pokémon.
- **Avec le Nuzlocke :** cumulable. Une rencontre hors du type ne consomme pas la zone.

### Fichiers
| Fichier | Rôle |
|---|---|
| `meta.txt` | Déclaration du plugin. |
| `001_Settings.rb` | `EXCLUDED_TYPES` (types impossibles à tirer ou choisir), `GYM_MAP_PATTERN` (nom des cartes d'arène et de Ligue dans l'éditeur), `GYM_LEADER_PATTERN` (types de dresseur des champions, du Conseil 4 et du Maître). |
| `002_Data.rb` | Données de sauvegarde (`$monotype`), test du type avec les évolutions. |
| `003_Setup.rb` | Fenêtres de choix du début de partie (Nuzlocke puis Monotype), déclenchées automatiquement. |
| `004_Capture.rb` | Blocage des captures, fin de la grâce du starter. |
| `005_Party.rb` | Starter, combats d'arène et de Ligue, dons au PC, Pokémon inutilisables, verrous du PC. |

### Intégration
- Rien à placer dans l'éditeur : les choix de mode s'affichent seuls en début de partie, les dresseurs d'arène et de Ligue sont reconnus par le nom de la carte dans l'éditeur (« Gym », « Arène », « League » ou « Ligue », réglable avec `GYM_MAP_PATTERN`), et les champions, le Conseil 4 et le Maître par leur type de dresseur (`LEADER_…`, `ELITEFOUR_…`, `CHAMPION…`, réglable avec `GYM_LEADER_PATTERN`).
- Facultatif : `Monotype.setup_dialog` ou `Nuzlocke.setup_dialog` dans un événement pour choisir le moment exact.

### Points d'accroche Essentials (alias/prepend, aucun script de base modifié)
`pbThrowPokeBall`, `pbStorePokemon` (sur `Battle` et `SafariBattle`), `ItemHandlers.triggerCanUseInBattle`, `TrainerBattle.start_core`, `BugContestState#pbEnd`, `pbStorePokemon` global (dons), `pbAddPokemon/pbAddPokemonSilent/pbAddToParty/pbAddToPartySilent/pbAddForeignPokemon`, `PokemonStorageScreen#pbWithdraw/pbPlace/pbSwap`, handlers `:on_end_battle` et `:on_player_step_taken`.

### À vérifier au premier lancement
- La liste des 18 types tient à l'écran (la fenêtre défile normalement).
- Les fenêtres de choix apparaissent au premier pas dans la chambre, après l'intro.

### Limites connues
- L'équipe ne peut pas être vide : un Pokémon inutilisable qui est seul dans l'équipe y reste (il ne peut pas combattre dans une arène ni à la Ligue).
- Si le PC est plein, un Pokémon inutilisable reste dans l'équipe.

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
