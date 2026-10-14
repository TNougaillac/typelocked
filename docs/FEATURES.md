# Fonctionnalités

## F01. Mode Nuzlocke
**Statut :** v1.1.0, écrit, **non testé**.
**Version cible :** Essentials v21.1.
**Dossier :** `Plugins/Nuzlocke/`

### Règles
- **Activation :** choix unique et définitif au début de la partie (`Nuzlocke.setup_dialog`).
- **Une capture par zone :** une zone = une carte (fusion possible avec `ZONE_GROUPS`). La première rencontre sauvage consomme la zone, capturée ou non. Les rencontres scriptées (légendaires, statiques) consomment aussi la zone.
- **Zone Safari et Concours de Capture :** mêmes règles de zone, doublons et shiny. Au Concours, le surnom est demandé quand le Pokémon gardé est remis à la fin.
- **Combat double :** dans une zone libre, les deux Pokémon sont capturables.
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
- Événement d'intro : commande script `Nuzlocke.setup_dialog`.
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

## F02. Générateur de cartes (MapGen)
**Statut :** v1.0.0, écrit, testé hors jeu sur les données du dépôt, **non testé en jeu**.
**Version cible :** Essentials v21.1.
**Dossier :** `Plugins/MapGenerator/`, plans dans `MapGen/*.txt` (exemple : `MapGen/exemple.txt`).

### Fonctionnement
- Un plan texte décrit la carte : un caractère par case, une légende qui associe chaque caractère à 1 à 3 calques.
- Calques : `T<n>` = tuile n du tileset (n = ligne × 8 + colonne), `A1` à `A7` = autotile (raccords calculés automatiquement), `-` = vide, `T1|T2|T3` = variante au hasard (`Seed` pour un résultat reproductible).
- Lancement : menu debug > Autres éditeurs > « Générer des cartes (MapGen) ». Écrit `Data/MapXXX.rxdata` et l'ajoute à `MapInfos.rxdata`.
- Sans `MapID` : nouvelle carte (ID suivant). Avec `MapID` : la carte est remplacée, ses événements sont conservés (ceux qui sortent de la nouvelle taille sont supprimés).
- Fermer RPG Maker XP sans enregistrer avant de générer, sinon l'éditeur écrase les fichiers.

### Fichiers
| Fichier | Rôle |
|---|---|
| `meta.txt` | Déclaration du plugin. |
| `001_Settings.rb` | `FOLDER`, `EMPTY_TOKEN`. |
| `002_Parser.rb` | Lecture et validation des plans. |
| `003_Builder.rb` | Construction des calques, motifs d'autotiles, vérification des tuiles. |
| `004_Generate.rb` | Écriture des fichiers de carte, commande du menu debug. |

### Points d'accroche Essentials
Aucun alias. Utilise `TileDrawingHelper::NEIGHBORS_TO_AUTOTILE_INDEX` (même table que le rendu d'Essentials) et `MenuHandlers.add(:debug_menu, ...)`.

### Limites connues
- Pas encore d'import PNG (1 pixel = 1 case) ni de génération procédurale.
- Les objets de plusieurs cases (arbres 2×2...) se placent case par case dans la légende.

## Journal
| Date | Ajout | Fichiers |
|---|---|---|
| 08/10/2026 | Plugin Nuzlocke v1.0.0 | `Plugins/Nuzlocke/*` |
| 14/10/2026 | Nuzlocke v1.1.0 : shiny consomme une zone libre, morts verrouillés au PC, poison non mortel, équipe K.O. | `Plugins/Nuzlocke/*`, `docs/FEATURES.md` |
| 14/10/2026 | Plugin MapGenerator v1.0.0 : cartes générées depuis un plan texte | `Plugins/MapGenerator/*`, `MapGen/exemple.txt`, `docs/FEATURES.md` |
