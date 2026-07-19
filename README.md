# organic-deploy

Deployment recipes for an [Organic Economy](https://economie-organique.fr) server ([organic-webserver](https://github.com/OrganicEconomy/organic-webserver)). The server repository stays minimal — everything infrastructure-related lives here.

## The simple way (recommended for community servers)

A community server has a tiny load: SQLite (the default) is all you need, and backing up means copying one file.

```bash
git clone https://github.com/OrganicEconomy/organic-webserver.git
cd organic-webserver/organic-webserver
npm install
ORGANIC_SECRET_KEY=<64-hex-secret-key> ORGANIC_SERVER_NAME="My server" npm start
```

Data lands in `./data/organic.sqlite`. Back it up with `cp`.

**TLS**: put [Caddy](https://caddyserver.com) in front rather than terminating HTTPS in Node — it obtains and renews Let's Encrypt certificates by itself. See [Caddyfile.example](Caddyfile.example):

```
my-server.example.org {
    reverse_proxy localhost:8080
}
```

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

## License

MIT — © suipotryot
