# Deploying on a VPS

*[🇫🇷 Version française](VPS.fr.md)*

`deploy-vps.sh` sets up a community server on a fresh **Debian** VPS in one interactive run: SQLite, systemd, and Caddy for HTTPS. It follows [RASPBERRY_PI.md](RASPBERRY_PI.md), minus everything a VPS doesn't need: its public IPv4 and IPv6 are fixed, so there's no dynamic DNS, port forwarding or CGNAT to deal with.

## Before you start

- A **Debian 12 or 13** VPS, and its root (or sudo) access from your hosting provider.
- A **domain or subdomain** whose DNS zone you can edit (e.g. `test.economie-organique.fr` at OVH).
- An **SSH key pair** on your own computer. If you don't have one yet: `ssh-keygen -t ed25519`. You'll be asked to paste the public part, which you can display with:
  - macOS/Linux: `cat ~/.ssh/id_ed25519.pub`
  - Windows (PowerShell): `type $env:USERPROFILE\.ssh\id_ed25519.pub`
- A **password manager** at hand: the script shows two keys you must write down.

## Install

Connect to the VPS with the access your provider gave you, then:

```bash
sudo apt update && sudo apt install -y git
sudo git clone https://github.com/OrganicEconomy/organic-deploy.git /opt/organic-deploy
sudo bash /opt/organic-deploy/deploy-vps.sh
```

The script first asks for everything it needs: admin username, SSH public key, domain, server name, extra CORS origins, and how many days of backups to keep. It shows a summary and waits for `yes`, then installs step by step.

Three moments need you:

1. **The SSH check.** The script creates your admin user, then asks you to open **another terminal** and run `ssh <admin>@<ip>` followed by `sudo -v`. Type `ok` only once that works. Root login and password logins get disabled right after, so a mistake there would lock you out.
2. **The keys.** `ORGANIC_SECRET_KEY` (the server's identity) and `ORGANIC_MASTER_KEY` (which decrypts every ecosystem key in the database) are shown **once**. Write them down outside the server, then type `noted`. Losing them is irreversible.
3. **DNS.** The script shows the VPS public IPv4 and IPv6. Create the matching **A** and **AAAA** records for your domain, then press Enter until it resolves. Caddy can't get an HTTPS certificate before that.

Running the script again is safe: existing users, the server checkout and above all the keys in `.env` are kept as they are.

## Check the deployment

From your computer, in `organic-webserver/organic-webserver`:

```bash
E2E_BASE_URL=https://<your-domain> npm run e2e
```

Also try the server from a network without IPv6 (a VPN, for instance): it must answer too.

## Update the server

```bash
ssh <admin>@<your-domain>
sudo git -C /opt/organic-deploy pull
sudo bash /opt/organic-deploy/deploy-vps.sh update
```

`update` backs up the database, pulls the latest server code, installs its dependencies, restarts the service and checks that it answers.

## Backups

Every day at 3am, `/usr/local/bin/organic-backup` copies the database into `/var/backups/organic/organic-<date>.sqlite` and deletes copies older than the retention you chose. It uses `sqlite3 .backup`, which is safe while the server is running.

These backups stay **on the VPS**, so they won't survive its loss: copy one elsewhere from time to time. On the VPS:

```bash
sudo install -o "$USER" /var/backups/organic/organic-<date>.sqlite ~/
```

then from your computer:

```bash
scp <admin>@<your-domain>:organic-<date>.sqlite .
```

To restore one:

```bash
sudo systemctl stop organic-webserver
sudo cp /var/backups/organic/organic-<date>.sqlite /home/organic/organic-webserver/organic-webserver/data/organic.sqlite
sudo chown organic:organic /home/organic/organic-webserver/organic-webserver/data/organic.sqlite
sudo systemctl start organic-webserver
```

A backup is only usable with the `ORGANIC_MASTER_KEY` it was made with.

## Useful commands

```bash
sudo systemctl status organic-webserver caddy   # both active (running)
journalctl -u organic-webserver -f              # live server logs
journalctl -u caddy                             # HTTPS certificate issues
```
