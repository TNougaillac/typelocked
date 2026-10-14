# Fonctionnalités

## F01. Mode Nuzlocke
**Statut :** v1.1.1, écrit, **non testé**.
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

## F02. Deluxe Battle Kit (plugin externe)
**Statut :** v1.3.1 installé (Lucidious89), avec son prérequis v21.1 Hotfixes 1.0.9 (Maruno). **Non testé.**
**Dossiers :** `Plugins/[DBK_000] Deluxe Battle Kit/`, `Plugins/v21.1 Hotfixes/`, `Graphics/Plugins/Deluxe Battle Kit/`, plus quelques fichiers dans `Audio/` et `Graphics/UI/`.
**Doc :** https://lucidious89-tutorials.gitbook.io/deluxe-battle-kit-tutorial

- Ajoute des Battle Rules (`setBattleRule`), les combats de boss sauvages (`editWildPokemon` avec `:hp_level` et `:immunities`), la capture style raid et les scripts en plein combat.
- Remplace deux images de base : `Graphics/UI/Battle/icon_mega.png` et `cursor_command.png`.
- `Town Map Generator.html` (version corrigée de `townmapgen.html`) est à la racine du projet.
- Cohabitation avec le Nuzlocke : le kit efface les surnoms dans `pbStorePokemon`, le Nuzlocke remet le surnom forcé après coup. Effet visible : le message « envoyé dans la boîte » affiche le nom de l'espèce.

## Journal
| Date | Ajout | Fichiers |
|---|---|---|
| 08/10/2026 | Plugin Nuzlocke v1.0.0 | `Plugins/Nuzlocke/*` |
| 14/10/2026 | Nuzlocke v1.1.0 : shiny consomme une zone libre, morts verrouillés au PC, poison non mortel, équipe K.O. | `Plugins/Nuzlocke/*`, `docs/FEATURES.md` |
| 14/10/2026 | Deluxe Battle Kit v1.3.1 + v21.1 Hotfixes 1.0.9 ; Nuzlocke v1.1.1 : surnom conservé malgré le kit | `Plugins/[DBK_000] Deluxe Battle Kit/*`, `Plugins/v21.1 Hotfixes/*`, `Audio/`, `Graphics/`, `Plugins/Nuzlocke/004_Nicknames.rb`, `docs/FEATURES.md` |
