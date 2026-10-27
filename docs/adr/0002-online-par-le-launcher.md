# Le mode online passe par le launcher et un serveur Cloudflare

Le mode online est en direct (course, combats, échanges), mais le moteur (mkxp-z) n'a que des requêtes HTTP bloquantes, sans sockets. Le jeu ne parle donc jamais au réseau lui-même : le launcher (#52) garde la connexion WebSocket ouverte et le jeu lui parle en local. Le serveur est un Worker Cloudflare avec un Durable Object par salon, pour n'avoir aucune machine à maintenir.

## Options écartées

- **Sockets dans le jeu via `Win32API`** (DLL de Windows) : possible, mais fragile, réservé à Windows et difficile à déboguer en Ruby.
- **Simple stockage de résultats** (sans serveur temps réel) : suffisait pour un classement, pas pour le direct demandé.

## Conséquences

- Pas de partie multi sans le launcher.
- Aucune vérification anti-triche côté serveur : le risque est accepté entre amis.
