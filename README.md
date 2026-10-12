# organic-deploy

*[🇫🇷 Version française](README.fr.md)*

Deployment recipes for an [Organic Economy](https://economie-organique.fr) server ([organic-webserver](https://github.com/OrganicEconomy/organic-webserver)). The server repository stays minimal — everything infrastructure-related lives here.

## Choose your deployment

| You have…                                          | Go to                | What it takes                                   |
|----------------------------------------------------|----------------------|-------------------------------------------------|
| A rented Debian VPS and a domain name              | [vps/](vps/README.md)       | One interactive script                          |
| A machine at home (Raspberry Pi or any Debian box) | [home/](home/README.md)     | A step-by-step guide                            |
| A Docker host, or a need for Postgres              | [docker/](docker/README.md) | Experimental: not verified end to end yet       |

Not sure? A VPS is the simplest: fixed IP addresses, nothing to configure on a router. Hosting at home is free, but depends on your internet box and your ISP.

## Common to every deployment

### The two keys

Every server needs two secrets:

- `ORGANIC_SECRET_KEY` (64 hex chars) is the server's identity: it signs accounts and bills.
- `ORGANIC_MASTER_KEY` isn't a blockchain key, just a passphrase: it encrypts every ecosystem's private key at rest in the database. Any long random string works, but it must stay stable: changing it later makes every already-encrypted ecosystem key unreadable.

Write both down somewhere other than the server (a password manager). Losing either is unrecoverable.

### SQLite by default

A community server has a tiny load: SQLite is all it needs. The data lives in `data/organic.sqlite`, so backing up means copying one file.

### HTTPS with Caddy

[Caddy](https://caddyserver.com) sits in front of Node and obtains and renews Let's Encrypt certificates by itself. It proxies to `127.0.0.1` rather than `localhost`: on a dual-stack system, `localhost` can resolve to `::1` first, and if Node isn't listening on the IPv6 loopback too, Caddy's proxy fails with a confusing `connection refused`.

### Verifying a deployment

From a checkout of `organic-webserver/organic-webserver` on your own computer:

```bash
E2E_BASE_URL=https://<your-hostname> npm run e2e
```

It walks through genesis, daily money creation (with catch-up), an online payment, a paper bill, and the two rejections that guard against fraud (a replayed transaction, a paper cashed twice) — printing a PASS/FAIL summary per step and exiting non-zero on any failure. The API rate limiter is active on a real deployment, so a run can pause for up to a minute mid-way while it backs off and retries — that's expected, not a hang. Each run generates unique emails, so running it against a database that already has data is fine.

## Repository layout

```
organic-deploy/
├── vps/      interactive install script for a Debian VPS, its guide and tests
├── home/     step-by-step guide for a machine at home, network special cases, DDNS scripts
└── docker/   Docker Compose with Postgres (experimental)
```

## Development

The VPS script's building blocks are tested with [bats](https://github.com/bats-core/bats-core):

```bash
npm install
npm test
```

## License

MIT — © suipotryot
