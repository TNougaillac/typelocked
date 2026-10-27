# Mettre en place le mode multijoueur

Guide d'installation du mode multijoueur (spec #141, ADR 0002). Il décrit le processus prévu ; les commandes exactes seront confirmées par les tickets #142 (serveur) et #143 (pont), qui mettront ce guide à jour.

## Vue d'ensemble

```
Jeu (Game.exe)  <-- local, sur le PC -->  Pont (puis launcher)  <-- WebSocket -->  Serveur Cloudflare
                                                                                    (un Durable Object par salon)
```

- Le **serveur** est hébergé chez Cloudflare (Workers + Durable Objects). Rien à installer ni à maintenir chez soi, aucun port à ouvrir.
- Le **pont** tourne sur le PC de chaque joueur. Il tient la connexion au salon et parle au jeu en local. Le launcher (#52) le reprendra : en attendant, il se lance à part.
- Le **jeu** ne fait jamais de réseau : il interroge le pont.

## 1. Mise en place du serveur (une seule fois, par Tom)

1. Créer un compte Cloudflare gratuit (dash.cloudflare.com). Aucune carte bancaire n'est prévue pour l'offre gratuite ; ses limites exactes pour les Durable Objects sont à vérifier dans #142.
2. Installer Node.js (version LTS) sur le PC.
3. Dans le dépôt, depuis le dossier du serveur (créé par #142) :
   ```
   npm install
   npx wrangler login        # ouvre le navigateur pour autoriser le compte Cloudflare
   npx wrangler deploy       # publie le serveur
   ```
   `deploy` affiche l'adresse du serveur, du type `https://typelocked-salons.<compte>.workers.dev`.
4. Choisir une **clé de groupe** (un mot de passe partagé entre amis) et la donner au serveur :
   ```
   npx wrangler secret put GROUP_KEY
   ```
   Sans cette clé, le serveur refuse de créer ou de rejoindre un salon : le jeu reste privé (#52).
5. Écrire l'adresse et la clé dans la configuration du pont (fichier local, jamais commité), puis transmettre ce fichier aux amis avec le jeu.

## 2. Installation chez chaque joueur

1. Installer le jeu comme d'habitude.
2. Placer la configuration du pont reçue de Tom à côté du jeu.
3. Tant que le launcher n'existe pas : lancer le pont (exécutable fourni, ou `node` si Node.js est installé).
4. Au premier lancement, choisir un **pseudo**. Le pont crée un code secret et le garde à côté de la sauvegarde ; il ne faut pas le partager.

## 3. Jouer une partie multi

1. L'**hôte** crée un salon dans le pont, choisit les règles (Nuzlocke, tirage du type, même type ou un par joueur) et reçoit un code court.
2. Les amis rejoignent le salon avec ce code.
3. Chacun lance le jeu : il détecte le pont, attend que tous les joueurs soient connectés, puis démarre la partie avec la graine du salon.
4. En cas de coupure, tout le salon se met en pause ; après 5 minutes, l'hôte peut retirer le joueur absent.

## 4. Entretien

- **Mettre à jour le serveur** : `npx wrangler deploy` depuis le dossier du serveur. Les salons en cours peuvent être coupés pendant quelques secondes.
- **Voir ce qui se passe** : `npx wrangler tail` affiche les journaux du serveur en direct.
- **Changer la clé de groupe** : refaire `npx wrangler secret put GROUP_KEY`, puis redistribuer la configuration du pont.
- **Consommation** : le tableau de bord Cloudflare montre les requêtes du jour. Un petit groupe d'amis doit rester très loin des limites gratuites (à confirmer dans #142).

## Sécurité

- Pas de compte ni de données personnelles : seulement un pseudo et un code secret par joueur.
- La clé de groupe empêche les inconnus d'utiliser le serveur.
- Aucune vérification anti-triche : risque accepté entre amis (ADR 0002).
