# Pokédex du jeu (TypeLocked)

Toutes les espèces d'Essentials v21.1 hors légendaires : 806 espèces, 383 familles, sur les 898 de `PBS/pokemon.txt` (les plugins n'ajoutent aucune espèce). Chaque monde les prend toutes (plugin ProceduralEncounters). Données brutes : [pokedex.csv](pokedex.csv).

## Règles

- **Exclus :** légendaires, fabuleux (Manaphy et Phione compris) et Ultra-Chimères. Formes régionales non comptées à part.
- **Variété d'attaques** (colonnes `variete_*`, pour information) : nombre de types d'attaques offensives qu'un Pokémon peut apprendre, sans compter le type du run ; une attaque par niveau compte 1, une attaque seulement par CT/tuteur 0,5. Elle n'écarte aucune famille.
- **Force** = total des stats de base de la forme finale : **faible** < 480, **moyen** 480 à 514, **fort** ≥ 515.
- **Types** comptés comme le plugin Monotype (une espèce compte aussi pour les types de ses évolutions).

## Répartition

| Type | Faible | Moyen | Fort | Total |
|---|---|---|---|---|
| Normal | 52 | 41 | 17 | 110 |
| Combat | 17 | 26 | 20 | 63 |
| Vol | 49 | 33 | 26 | 108 |
| Poison | 22 | 34 | 11 | 67 |
| Sol | 18 | 32 | 25 | 75 |
| Roche | 8 | 33 | 21 | 62 |
| Insecte | 46 | 27 | 8 | 81 |
| Spectre | 9 | 28 | 13 | 50 |
| Acier | 8 | 25 | 20 | 53 |
| Feu | 6 | 22 | 38 | 66 |
| Eau | 40 | 51 | 45 | 136 |
| Plante | 28 | 38 | 36 | 102 |
| Électrik | 16 | 21 | 14 | 51 |
| Psy | 22 | 32 | 19 | 73 |
| Glace | 10 | 13 | 20 | 43 |
| Dragon | 0 | 12 | 35 | 47 |
| Ténèbres | 17 | 27 | 20 | 64 |
| Fée | 18 | 17 | 16 | 51 |

| Génération | Faible | Moyen | Fort | Total |
|---|---|---|---|---|
| 1 | 43 | 57 | 46 | 146 |
| 2 | 41 | 28 | 25 | 94 |
| 3 | 62 | 25 | 38 | 125 |
| 4 | 25 | 29 | 39 | 93 |
| 5 | 26 | 79 | 38 | 143 |
| 6 | 14 | 28 | 24 | 66 |
| 7 | 17 | 29 | 15 | 61 |
| 8 | 16 | 45 | 17 | 78 |
| **Total** | 244 | 320 | 242 | 806 |
