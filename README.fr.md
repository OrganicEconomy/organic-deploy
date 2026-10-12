# organic-deploy

*[🇬🇧 English version](README.md)*

Recettes de déploiement d'un serveur [Économie Organique](https://economie-organique.fr) ([organic-webserver](https://github.com/OrganicEconomy/organic-webserver)). Le dépôt du serveur reste minimal — tout ce qui touche à l'infrastructure vit ici.

## Choisir son déploiement

| Tu as…                                                 | Va dans                        | Ce que ça demande                                 |
|--------------------------------------------------------|--------------------------------|---------------------------------------------------|
| Un VPS Debian loué et un nom de domaine                | [vps/](vps/README.fr.md)       | Un script interactif                              |
| Une machine chez toi (Raspberry Pi ou autre Debian)    | [home/](home/README.fr.md)     | Un guide pas à pas                                |
| Un hôte Docker, ou besoin de Postgres                  | [docker/](docker/README.fr.md) | Expérimental : pas encore vérifié de bout en bout |

Pas sûr ? Le VPS est le plus simple : adresses IP fixes, rien à configurer sur un routeur. L'hébergement à la maison est gratuit, mais dépend de ta box et de ton FAI.

## Commun à tous les déploiements

### Les deux clés

Chaque serveur a besoin de deux secrets :

- `ORGANIC_SECRET_KEY` (64 caractères hexadécimaux) est l'identité du serveur : elle signe les comptes et les billets.
- `ORGANIC_MASTER_KEY` n'est pas une clé de blockchain, juste une phrase de passe : elle chiffre en base la clé privée de chaque écosystème. N'importe quelle longue chaîne aléatoire convient, mais elle doit rester stable : la changer rend illisibles toutes les clés d'écosystème déjà chiffrées.

Note les deux ailleurs que sur le serveur (un gestionnaire de mots de passe). Perdre l'une ou l'autre est irréversible.

### SQLite par défaut

Un serveur communautaire a une charge minime : SQLite suffit. Les données vivent dans `data/organic.sqlite`, donc sauvegarder revient à copier un fichier.

### HTTPS avec Caddy

[Caddy](https://caddyserver.com) se place devant Node et obtient puis renouvelle seul les certificats Let's Encrypt. Il redirige vers `127.0.0.1` plutôt que `localhost` : sur un système dual-stack, `localhost` peut se résoudre en `::1` en premier, et si Node n'écoute pas aussi sur le loopback IPv6, le proxy échoue avec un `connection refused` déroutant.

### Vérifier un déploiement

Depuis un clone de `organic-webserver/organic-webserver` sur ton propre ordinateur :

```bash
E2E_BASE_URL=https://<ton-nom-d-hote> npm run e2e
```

Le scénario parcourt la genèse, la création de monnaie quotidienne (avec rattrapage), un paiement en ligne, un billet papier, et les deux rejets qui protègent de la fraude (une transaction rejouée, un billet encaissé deux fois) — avec un résumé PASS/FAIL par étape et un code de sortie non nul au moindre échec. Le limiteur de débit de l'API est actif sur un vrai déploiement, donc une exécution peut marquer une pause d'une minute en cours de route, le temps de réessayer — c'est normal, pas un blocage. Chaque exécution génère des emails uniques : le lancer sur une base qui contient déjà des données ne pose pas de problème.

## Contenu du dépôt

```
organic-deploy/
├── vps/      script d'installation interactif pour un VPS Debian, son guide et ses tests
├── home/     guide pas à pas pour une machine à la maison, cas particuliers réseau, scripts DDNS
└── docker/   Docker Compose avec Postgres (expérimental)
```

## Développer

Les briques du script VPS sont testées avec [bats](https://github.com/bats-core/bats-core) :

```bash
npm install
npm test
```

## Licence

MIT — © suipotryot
