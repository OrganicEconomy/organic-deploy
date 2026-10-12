# Déploiement Docker (expérimental)

*[🇬🇧 English version](README.md)*

> **Expérimental** : ce déploiement n'a pas encore été vérifié de bout en bout. Pour un serveur communautaire, préfère [le script VPS](../vps/README.fr.md) ou [le guide maison](../home/README.fr.md).

Fait tourner le serveur avec une base Postgres (`DB_DIALECT=postgres`), pour des hébergements plus conséquents.

Organisation attendue — les deux dépôts clonés côte à côte :

```
.
├── organic-deploy/      ← ce dépôt
└── organic-webserver/   ← le serveur
```

Depuis `organic-deploy/docker` :

```bash
cp .env.example .env     # puis l'éditer
docker compose up -d
```

`.env` contient les identifiants Postgres, les ports et [les deux clés](../README.fr.md#les-deux-clés).

Le TLS reste le travail de Caddy, sur l'hôte ou comme service supplémentaire (voir [HTTPS avec Caddy](../README.fr.md#https-avec-caddy)).

## Vérifier le déploiement

Lancer [le scénario de bout en bout](../README.fr.md#vérifier-un-déploiement) sur `http://localhost:8080`. Pour repartir d'une base vide, lancer d'abord `docker compose down -v`.
