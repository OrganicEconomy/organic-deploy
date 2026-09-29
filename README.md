# organic-deploy

Deployment recipes for an [Organic Economy](https://economie-organique.fr) server ([organic-webserver](https://github.com/OrganicEconomy/organic-webserver)). The server repository stays minimal — everything infrastructure-related lives here.

## The simple way (recommended for community servers)

A community server has a tiny load: SQLite (the default) is all you need, and backing up means copying one file.

```bash
git clone https://github.com/OrganicEconomy/organic-webserver.git
cd organic-webserver/organic-webserver
npm install
ORGANIC_SECRET_KEY=<64-hex-secret-key> ORGANIC_MASTER_KEY=<a-long-random-passphrase> ORGANIC_SERVER_NAME="My server" npm start
```

`ORGANIC_MASTER_KEY` isn't a blockchain key, just a passphrase — it encrypts every ecosystem's private key at rest in the database. Any long random string works, but it must stay stable: changing it later makes every already-encrypted ecosystem key unreadable.

Data lands in `./data/organic.sqlite`. Back it up with `cp`.

**TLS**: put [Caddy](https://caddyserver.com) in front rather than terminating HTTPS in Node — it obtains and renews Let's Encrypt certificates by itself. See [Caddyfile.example](Caddyfile.example):

```
my-server.example.org {
    reverse_proxy 127.0.0.1:8080
}
```

(`127.0.0.1` rather than `localhost` — on a dual-stack system, `localhost` can resolve to `::1` first, and if Node isn't listening on the IPv6 loopback too, Caddy's proxy fails with a confusing `connection refused`.)

**Running this from home?** See [RASPBERRY_PI.md](RASPBERRY_PI.md) (or [in French](RASPBERRY_PI.fr.md)) for a full, reproducible walkthrough — OS flashing, firewall, systemd service, DuckDNS, port forwarding, and Caddy, start to finish.

## The docker way (bigger hosts, Postgres)

Expected layout — both repositories cloned side by side:

```
.
├── organic-deploy/      ← this repository
└── organic-webserver/   ← the server
```

```bash
cp .env.example .env     # then edit it
docker compose up -d
```

The compose file runs the server against a Postgres instance (`DB_DIALECT=postgres`). TLS is still Caddy's job, on the host or as an extra service.

### Verifying a deployment

Once `docker compose up -d` is up, run the end-to-end scenario against it from `organic-webserver/organic-webserver` (the sibling checkout, not inside the container):

```bash
E2E_BASE_URL=http://localhost:8080 npm run e2e
```

It walks through genesis, daily money creation (with catch-up), an online payment, a paper bill, and the two rejections that guard against fraud (a replayed transaction, a paper cashed twice) — printing a PASS/FAIL summary per step and exiting non-zero on any failure. The API rate limiter is active in this deployment (no `NODE_ENV=test` override), so a run can pause for up to a minute mid-way while it backs off and retries — that's expected, not a hang.

Run it against a fresh database (`docker compose down -v` first) or don't worry about it — each run generates unique emails, so a persistent database doesn't cause collisions.

## License

MIT — © suipotryot
