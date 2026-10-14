# TypeLocked

Fan game non commercial sous RPG Maker XP + Pokémon Essentials **v21.1**.

Ce dépôt contient le projet RPG Maker XP complet : cartes et bases de données (`Data/*.rxdata`), graphismes, sons, plugins Ruby, fichiers PBS, plans MapGen et docs.

## Installation d'un plugin
Copier le dossier `Plugins/<Nom>/` dans le dossier `Plugins/` du projet Essentials, puis lancer le jeu pour qu'il soit compilé.

## Fonctionnalités
Voir [docs/FEATURES.md](docs/FEATURES.md).

## CI
À chaque push sur `main` et à chaque PR qui touche `Plugins/`, `PBS/`, `MapGen/` ou `Data/`, GitHub Actions lance des vérifications statiques (le jeu lui-même ne tourne pas en CI) :

| Vérification | Script | Ce qu'elle attrape |
|---|---|---|
| Syntaxe des plugins | `tools/ci/check_ruby_syntax.rb` | `end` ou parenthèse manquants dans `Plugins/**/*.rb` |
| Références des PBS | `tools/ci/check_pbs.rb` | attaque, talent, objet, type, espèce ou type de dresseur inconnu ; ID en double ; carte absente de `Data/` dans `encounters`, `map_metadata`, `map_connections`, `metadata`, `town_map` |
| Plans MapGen | `tools/ci/check_mapgen.rb` | erreurs du parseur du plugin, tuiles hors tileset, `MapID`/`Parent` inexistants, portes vers une carte inconnue |
| Plugins et encodage | `tools/ci/check_plugins.rb` | `meta.txt` incomplet, `Requires` absent ou trop ancien, texte non UTF-8 |
| RuboCop (règles `Lint` seulement) | `.rubocop.yml` | variables inutilisées, conditions ambiguës (hors Deluxe Battle Kit et Hotfixes) |

Lancer une vérification en local : `ruby tools/ci/check_pbs.rb` (Ruby 3.1 ou plus).
