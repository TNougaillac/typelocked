# Recherche : interface 4G (#196)

Ressources d'interface au style DPPt / HGSS pour Essentials v21.1, relevées le 08/11/2026 sur Eevee Expo. Les écrans de combat sont hors périmètre.

## Déjà dans Essentials v21.1

- **Fenêtres de texte :** `SPEECH_WINDOWSKINS` propose déjà `speech hgss 1` à `20` (cadre par défaut : `speech hgss 1`), plus `speech pl 1` à `20` et `speech dp 1` à `20` dans `Graphics/Windowskins`.
- **Menus :** `MENU_WINDOWSKINS` utilise `choice 1` à `28`, les cadres de choix de la 4G.
- **Panneaux de lieu :** `sign hgss loc`, `sign hgss town`, `sign hgss dir`, `sign hgss tt`.

Rien à télécharger pour ces trois points : il suffit de garder ces cadres (ou d'en fixer un par défaut).

## Ressources trouvées

| Écran | Ressource | Auteurs (crédits) | Version | Contenu | Hébergement | Verdict |
|---|---|---|---|---|---|---|
| Menu de pause | [Marin's DP Pause Menu v21.1](https://eeveeexpo.com/resources/1865/) | Marin (script), Maryn (portage v21.1), ChromeValiant (ajouts), Spaceemotion, PurpleZaffre (icônes) | v21.1 | Menu DP (Pokédex, Pokémon, Sac, Carte dresseur, Sauvegarde, Options), plus Pokégear, carte, Safari | GitHub via Eevee Expo | **Oui.** Script à repackager en plugin TypeLocked (il remplace `call_menu`) et à brancher sur nos entrées de menu (Monotype, Nuzlocke, RunHistory, Online). |
| Sac | [ChromusSama's Bag UI](https://eeveeexpo.com/resources/1570/) | ChromusSama | v21 / v21.1 | Images seules de `Graphics/UI/Bag`, inspirées de Platine | MediaFire | **Oui.** Aucun script : on remplace les images. |
| Options | [HGSS Options Screen](https://eeveeexpo.com/resources/1322/) | LinKazamine, Richard PT (fond) | 20.1+ (testé en 20.1) | Plugin et fond HGSS clair ou sombre | MEGA | **Oui, à tester en v21.1.** |
| Pokégear | [Pokegear Themes](https://eeveeexpo.com/resources/1321/) | LinKazamine, Jackster (extraction HGSS), CynderHydra | 20.1+ (testé en 20.1) | 7 thèmes HGSS pour le Pokégear, la carte et le téléphone | MEGA | **Images seulement.** Le script écrase les scripts de base (Pokégear, carte, téléphone) : on n'en prend que les images du thème par défaut, en particulier le fond de la carte de région. |
| Résumé | [DP Summary Screen](https://eeveeexpo.com/resources/390/) | Mr. Gela, Jenkkrystal ; ne pas redistribuer | v18.1 | Résumé façon DP, IV en hexagone | MEGA / Dropbox | **Images seulement.** Script trop ancien pour v21.1 ; les images peuvent remplacer celles de `Graphics/UI/Summary` si les tailles collent. |
| Carte dresseur | [HGSS Trainer Card Scene](https://eeveeexpo.com/resources/388/) | Mr. Gela, Vendily, HDrawer ; ne pas redistribuer | v18 | Carte HGSS animée, recto verso, 6 couleurs | MEGA / Dropbox | **Images seulement**, même raison. |
| Fenêtres | [Mr. Gela's Windowskin Pack](https://eeveeexpo.com/resources/196/) | Mr. Gela ; ne pas redistribuer | non précisée | Cadre doré 4G, panneaux HGSS | MEGA | Facultatif : Essentials a déjà les cadres 4G. |

Écartées : [Voltseon's Pause Menu](https://eeveeexpo.com/resources/1140) et [Menu Makeover](https://eeveeexpo.com/resources/1680/) (pas en style 4G), [Emerald UI Pack](https://eeveeexpo.com/resources/965/) et [FRLG Summary](https://eeveeexpo.com/resources/988) (3G), [SV Summary](https://eeveeexpo.com/resources/1768/) (9G).

## Sans ressource 4G trouvée

- **Équipe (`Graphics/UI/Party`)** : aucune ressource v21. À recolorier par script dans les teintes de DPPt, comme la météo.
- **Carte de région (`Graphics/UI/Town Map`)** : le fond du thème Pokégear HGSS si on le prend, sinon recoloriage.
- **Écrans de nos plugins** (Monotype, Nuzlocke, RunHistory, Online, NewGameSetup, IntroScene) : ils reprennent les cadres et les fonds choisis ci-dessus.

## Ce qu'il faut de Tom

Les packs sont sur MEGA, MediaFire et Dropbox : il faut les télécharger et les déposer dans les fichiers du projet, dans `tilesets/4g/interface/`, comme pour l'overworld.
