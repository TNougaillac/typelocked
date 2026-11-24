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
## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- When graphify-out/graph.json exists, run `graphify query "<question>"` before your first grep, search or source-file read for a codebase question, and put this rule in every subagent prompt that explores code. Read raw files only for lines the graph or an earlier read already located. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. When the answer is under a Markdown heading, `graphify section "<heading>"` prints that section's text, so the .md need not be opened. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
- graphify-out/ is gitignored: the cloud setup script rebuilds it in each fresh container. If it is missing, run `graphify update .` first. Never commit it.
