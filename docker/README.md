# Docker deployment (experimental)

*[🇫🇷 Version française](README.fr.md)*

> **Experimental**: this deployment hasn't been verified end to end yet. For a community server, prefer [the VPS script](../vps/README.md) or [the home guide](../home/README.md).

Runs the server against a Postgres instance (`DB_DIALECT=postgres`), for bigger hosts.

Expected layout — both repositories cloned side by side:

```
.
├── organic-deploy/      ← this repository
└── organic-webserver/   ← the server
```

From `organic-deploy/docker`:

```bash
cp .env.example .env     # then edit it
docker compose up -d
```

`.env` holds the Postgres credentials, the ports and [the two keys](../README.md#the-two-keys).

TLS is still Caddy's job, on the host or as an extra service (see [HTTPS with Caddy](../README.md#https-with-caddy)).

## Verifying the deployment

Run [the end-to-end scenario](../README.md#verifying-a-deployment) against `http://localhost:8080`. To start from an empty database, run `docker compose down -v` first.
