# Self-hosting on a Raspberry Pi

*[🇫🇷 Version française](RASPBERRY_PI.fr.md)*

A worked, reproducible version of ["the simple way"](README.md#the-simple-way-recommended-for-community-servers) for a community server run from home: SQLite, no Docker, Caddy in front for TLS. A neighborhood-scale server has a tiny load — a Raspberry Pi handles it comfortably.

**Hardware**: any Raspberry Pi 3 or later (64-bit capable, ARMv8+). The original Pi 1 (Model A/B, 2012) won't work — it's ARMv6, which current Node.js releases no longer support.

## 1. Flash the OS

Use the official [Raspberry Pi Imager](https://www.raspberrypi.com/software/). In the OS picker, **Raspberry Pi OS Lite (64-bit)** isn't one of the options shown up front — look under the more generic/less common Raspberry Pi OS entries to find it. The app then walks you, as part of the regular install flow (no separate icon or shortcut to hunt for), through setting a hostname, enabling SSH, and configuring Wi-Fi if you're not on Ethernet — this gets you a fully headless setup with no monitor/keyboard needed.

Once booted (1-2 minutes), find it on the network (`ping <hostname>.local` or your router's client list) and SSH in.

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades   # keep security patches current automatically
```

## 2. Network

- **Reserve a fixed local IP for the Pi in your router** (DHCP reservation by MAC address) — do this before setting up port forwarding, or it'll break on the next DHCP lease renewal. Get the Pi's current IP and MAC address first:
  ```bash
  hostname -I
  ip link show | grep -A1 "eth0\|wlan0"
  ```
  Then reserve that MAC's IP in your router's admin interface (often `192.168.1.1` or `192.168.0.1`).

- **Switch SSH to key-only auth.** If you don't have an SSH key pair yet, generate one on the machine you'll connect *from* (not the Pi): `ssh-keygen -t ed25519`. Then copy the public key to the Pi.

  On macOS/Linux:
  ```bash
  ssh-copy-id pi@<pi-ip>
  ```
  On Windows (PowerShell — `ssh-copy-id` isn't available by default):
  ```powershell
  type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh pi@<pi-ip> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
  ```
  Reconnect once to confirm key-based login works, *then* disable password auth on the Pi:
  ```bash
  sudo nano /etc/ssh/sshd_config
  # set: PasswordAuthentication no
  sudo systemctl restart ssh
  ```

- **Don't forward the SSH port (22) to the internet.** Only 80 and 443 need to be reachable from outside — administer the Pi from the local network (or a VPN) instead.

## 3. Firewall

```bash
sudo apt install -y ufw
sudo ufw allow from 192.168.1.0/24 to any port 22   # most home routers use this — if `ip -4 addr show` gives you a different subnet, use that instead
sudo ufw allow 80,443/tcp
sudo ufw enable
```

Optional but recommended for a box left exposed long-term: `sudo apt install fail2ban` to ban brute-force attempts against SSH/HTTP.

## 4. A dedicated service user

```bash
sudo adduser --system --group --home /home/organic --shell /bin/bash organic
```

No password (system accounts can't log in with one) — the Node process shouldn't run as `pi` or root. A real home directory and shell are still needed here so `sudo -u organic -i` (used below to clone and install the app) works; plain `adduser --system` without `--home`/`--shell` leaves the account pointed at `/nonexistent` with no shell, which breaks that.

## 5. Node.js

Install from the official NodeSource repository (ships arm64 builds; Debian's own package is usually too old):

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs build-essential python3 git
```

`build-essential`/`python3` are a safety net in case `sqlite3` (a native dependency) has to compile from source for lack of a prebuilt binary on this exact OS/arch combo — not always needed, but avoids a confusing failure if it is. `git` isn't included in Raspberry Pi OS Lite by default either, and is needed for the clone in the next step.

## 6. Deploy the server

```bash
sudo -u organic -i
git clone https://github.com/OrganicEconomy/organic-webserver.git
cd organic-webserver/organic-webserver
npm install --omit=dev
```

Generate `ORGANIC_SECRET_KEY` (64 hex chars — the key the server signs as referent with) and `ORGANIC_MASTER_KEY` (a long random passphrase — not a blockchain key, it encrypts every ecosystem's private key at rest in the database):

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"   # run twice, once per key
```

**Write both down somewhere other than the Pi too** (a password manager) — losing either is unrecoverable: `ORGANIC_SECRET_KEY` for the server's own identity, `ORGANIC_MASTER_KEY` for every ecosystem's key already encrypted with it. SD cards die.

Create `.env` at the repo root:

```
ORGANIC_SECRET_KEY=<your 64-hex key>
ORGANIC_MASTER_KEY=<your other 64-hex key>
ORGANIC_SERVER_NAME=<your server's display name>
```

## 7. Run it as a systemd service

`/etc/systemd/system/organic-webserver.service`:

```ini
[Unit]
Description=Organic Economy webserver
After=network.target

[Service]
Type=simple
User=organic
WorkingDirectory=/home/organic/organic-webserver/organic-webserver
EnvironmentFile=/home/organic/organic-webserver/organic-webserver/.env
ExecStart=/usr/bin/node --import tsx server.ts
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now organic-webserver
sudo systemctl status organic-webserver     # should read active (running)
journalctl -u organic-webserver -f          # live logs
```

## 8. A public hostname (DuckDNS)

No domain of your own? [DuckDNS](https://www.duckdns.org) gives a free subdomain (`<name>.duckdns.org`) with a built-in dynamic-IP updater.

1. Sign in on [duckdns.org](https://www.duckdns.org) and reserve a subdomain (e.g. `my-neighborhood-currency` → `my-neighborhood-currency.duckdns.org`). Note the **token** shown on your account page.
2. On the Pi, in your own (non-`organic`) account — no `sudo` needed here, `~/duckdns` is your own home directory:
   ```bash
   mkdir ~/duckdns && cd ~/duckdns
   echo 'echo url="https://www.duckdns.org/update?domains=<your-subdomain>&token=<your-token>&ip=" | curl -k -o ~/duckdns/duck.log -K -' > duck.sh
   chmod 700 duck.sh
   ./duck.sh
   cat duck.log   # should print "OK"
   ```
3. Schedule it to run every 5 minutes so it keeps tracking your home IP as it changes:
   ```bash
   crontab -e
   ```
   add:
   ```
   */5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1
   ```
   (A systemd timer is more robust than cron if you want to go further, but cron is plenty reliable for this.)

## 9. Port forwarding

In your router, forward external ports **80** and **443** to the Pi's fixed local IP, same ports on the Pi side — this keeps the Caddy config below simple (no custom ports).

### If your ISP blocks this (CGNAT / no public IPv4)

Some ISPs — in France, this is common on SFR/Red by SFR fiber lines — put residential connections behind Carrier-Grade NAT (often via DS-Lite): you get a real public IPv6 but only a private, shared IPv4, and the router's IPv4 port-forwarding menu either disappears or silently does nothing. Signs you're affected: that menu is missing/grayed out, or the connection is otherwise clearly not a real public IPv4.

Two ways out:

1. **Ask your ISP for a public IPv4 / "CGNAT rollback"** — for SFR/Red by SFR, technical support can do this on request (usually within about a week). Keeps the rest of this guide unchanged.
2. **Go IPv6-only instead** — works immediately, no ISP ticket, and stays fully self-hosted (no third-party tunnel). The one real tradeoff: visitors on IPv4-only networks (uncommon in France — [~73% IPv6 adoption in 2026](https://www.arcep.fr/fileadmin/reprise/observatoire/ipv6/Arcep_2025_Barometer_of_the_Transition_to_IPv6.pdf) — but not zero) simply can't reach the server.

   - Find the Pi's global IPv6 address:
     ```bash
     ip -6 addr show eth0   # the "scope global" line, not fe80::...
     ```
   - In the router, look for a separate **IPv6 firewall** section (not the IPv4 NAT one) and open inbound TCP 80/443 to that address — a firewall rule, not port forwarding, since IPv6 has no NAT to traverse.
   - Point DuckDNS at an **AAAA** record too, re-reading the address each run since it can change with the delegated prefix:
     ```bash
     cd ~/duckdns
     cat > duck.sh << 'SCRIPT'
     IP6=$(ip -6 addr show eth0 | grep "scope global" | awk '{print $2}' | cut -d/ -f1)
     echo url="https://www.duckdns.org/update?domains=<your-subdomain>&token=<your-token>&ip=&ipv6=${IP6}" | curl -k -o ~/duckdns/duck.log -K -
     SCRIPT
     chmod 700 duck.sh
     ./duck.sh && cat duck.log   # should print "OK"
     ```
     (the same cron entry from step 8 keeps this current — no change needed there)
   - Caddy (next step) needs no changes — it listens on both address families by default.

## 10. Caddy (automatic TLS)

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install caddy
```

Adapt [Caddyfile.example](Caddyfile.example) with your real hostname and copy it to `/etc/caddy/Caddyfile`:

```
<your-name>.duckdns.org {
    reverse_proxy 127.0.0.1:8080
}
```

(`127.0.0.1` rather than `localhost` — on a dual-stack system `localhost` can resolve to `::1` first, and if Node isn't listening on the IPv6 loopback too, the proxy fails with a confusing `connection refused` even though everything else is working.)

```bash
sudo systemctl reload caddy
```

Caddy obtains and renews its Let's Encrypt certificate on its own — this only works once ports 80/443 are actually reachable from the internet (step 9).

## 11. Backups

`data/organic.sqlite` is a single file. A daily cron job copying it elsewhere is enough:

```
0 3 * * * cp /home/organic/organic-webserver/organic-webserver/data/organic.sqlite /path/to/backup/organic-$(date +\%F).sqlite
```

Add a simple rotation (keep the last N days) so backups don't fill the disk. Longer-term, consider booting from a USB SSD rather than the SD card — SD cards are the most common failure point on a Pi that runs continuously.

## Verifying the deployment

From a machine outside your LAN (phone on mobile data works well, to make sure you're really going out over the internet):

```bash
E2E_BASE_URL=https://<your-name>.duckdns.org npm run e2e
```

(same scenario as [the docker deployment's verification](README.md#verifying-a-deployment) — genesis, daily money creation, an online payment, a paper bill, and the two fraud rejections.)

**If you went the IPv6-only route** (step 9) and this hangs/times out from a Windows machine that otherwise looks fine, check whether IPv6 is actually enabled on its network adapter before suspecting the server — it's sometimes switched off by default or by an old tweak, even when the ISP box itself has working IPv6:
```powershell
Get-NetAdapterBinding -ComponentID ms_tcpip6   # look for Enabled: False on your real adapter
Enable-NetAdapterBinding -Name "Ethernet" -ComponentID ms_tcpip6   # run as Administrator
```

Also check that the HTTPS certificate is valid (no browser warning), and that both services survive a reboot:

```bash
sudo reboot
# after it comes back up:
sudo systemctl status organic-webserver caddy   # both active (running)
```

## Updating the server

No new dependency or environment variable → a plain pull and restart:

```bash
sudo -u organic -i
cd organic-webserver/organic-webserver
git pull origin main
exit
sudo systemctl restart organic-webserver
sudo systemctl status organic-webserver   # should read active (running)
```

If a change did add a new dependency, run `npm install --omit=dev` (still as `organic`) before restarting the service.
