# TypeLocked

Fan game Pokémon Essentials v21.1 (RPG Maker XP). Langue de travail : français ; code, fichiers et identifiants en anglais. Fonctionnalités : `docs/FEATURES.md`. Univers : `docs/LORE.md` et `GLOSSARY.md`.

## Agent skills

### Issue tracker

Les issues vivent dans les GitHub Issues de `tnougaillac/typelocked`. See `docs/agents/issue-tracker.md`.

### Triage labels

Les cinq labels par défaut (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context : `GLOSSARY.md` et `docs/adr/` à la racine. See `docs/agents/domain.md`.

## Génération procédurale

Pour améliorer la génération procédurale (MapProc), piocher notamment dans les tilesets libres importés : packs complets dans le dossier `tilesets/` des fichiers du projet (Emerald Outdoor, KingTapir, Ekat's Tiny Interiors), import dans le tileset Outside avec `tools/art/import_props.py`, crédits à tenir à jour dans `docs/CREDITS.md`.

Règles fixes du rendu (`docs/FEATURES.md`, « contours entiers ») : aucun bâtiment coupé (après `tools/art/outside_4g.py`, toujours lancer `tools/art/building_edges_4g.py` ; les deux s'arrêtent sur un dessin qui dépasse de son cadre), aucun coin rentrant nord sur un niveau ni rôle `iNW`/`iNE` sur un massif à dessus (contrôle `check_cliff_corners` de la CI). Ne jamais contourner ces arrêts : corriger le dessin ou la génération.
