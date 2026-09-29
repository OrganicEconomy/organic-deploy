# Auto-hébergement sur Raspberry Pi

*[🇬🇧 English version](RASPBERRY_PI.md)*

Une version concrète et reproductible de [« la voie simple »](README.md#the-simple-way-recommended-for-community-servers) : un serveur communautaire hébergé chez soi — SQLite, pas de Docker, Caddy devant pour le TLS. À l'échelle d'un quartier, la charge est minime — un Raspberry Pi encaisse ça sans problème.

**Matériel** : n'importe quel Raspberry Pi 3 ou plus récent (compatible 64 bits, ARMv8+). Le tout premier Pi (Model A/B, 2012) ne convient pas — il est en ARMv6, que les versions actuelles de Node.js ne supportent plus.

## 1. Flasher l'OS

Utiliser l'outil officiel [Raspberry Pi Imager](https://www.raspberrypi.com/software/). Choisir **Raspberry Pi OS Lite (64-bit)** — pas besoin de bureau graphique pour un serveur. Avant d'écrire, ouvrir les options avancées (icône en forme de roue crantée, ou `Ctrl+Shift+X`) pour définir un nom d'hôte, activer SSH, et configurer le wifi si ce n'est pas en Ethernet — de quoi obtenir une installation entièrement headless, sans écran ni clavier à brancher.

Une fois démarré (1 à 2 minutes), le retrouver sur le réseau (`ping <nom-hote>.local`, ou la liste des clients de ton routeur) et s'y connecter en SSH.

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades   # maintient les correctifs de sécurité à jour tout seul
```

## 2. Réseau

- **Réserver une IP locale fixe pour le Pi dans le routeur** (réservation DHCP par adresse MAC) — à faire avant de configurer la redirection de port, sinon elle casse au prochain renouvellement de bail DHCP. Récupérer d'abord l'IP et l'adresse MAC actuelles du Pi :
  ```bash
  hostname -I
  ip link show | grep -A1 "eth0\|wlan0"
  ```
  Puis réserver l'IP de cette MAC dans l'interface d'admin du routeur (souvent `192.168.1.1` ou `192.168.0.1`).

- **Passer SSH en authentification par clé uniquement.** Si tu n'as pas encore de paire de clés SSH, en générer une sur la machine depuis laquelle tu te connectes (pas sur le Pi) : `ssh-keygen -t ed25519`. Puis copier la clé publique sur le Pi.

  Sous macOS/Linux :
  ```bash
  ssh-copy-id pi@<ip-du-pi>
  ```
  Sous Windows (PowerShell — `ssh-copy-id` n'est pas disponible par défaut) :
  ```powershell
  type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh pi@<ip-du-pi> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
  ```
  Se reconnecter une fois pour confirmer que la connexion par clé fonctionne, *puis seulement* désactiver l'authentification par mot de passe sur le Pi :
  ```bash
  sudo nano /etc/ssh/sshd_config
  # mettre : PasswordAuthentication no
  sudo systemctl restart ssh
  ```

- **Ne pas rediriger le port SSH (22) vers l'extérieur.** Seuls 80 et 443 doivent être joignables depuis internet — administrer le Pi depuis le réseau local (ou via un VPN) à la place.

## 3. Pare-feu

```bash
sudo apt install -y ufw
sudo ufw allow from 192.168.1.0/24 to any port 22   # la plupart des routeurs domestiques utilisent ce sous-réseau — si `ip -4 addr show` t'en donne un autre, utilise-le à la place
sudo ufw allow 80,443/tcp
sudo ufw enable
```

Optionnel mais recommandé si le Pi reste exposé longtemps : `sudo apt install fail2ban`, pour bannir les tentatives de force brute contre SSH/HTTP.

## 4. Un utilisateur dédié pour le service

```bash
sudo adduser --system --group organic
```

Pas de shell de connexion, pas de mot de passe — le process Node ne doit tourner ni sous `pi` ni sous root.

## 5. Node.js

Installer depuis le dépôt officiel NodeSource (fournit des builds arm64 ; le paquet Debian est généralement trop ancien) :

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs build-essential python3
```

`build-essential`/`python3` servent de filet de sécurité au cas où `sqlite3` (une dépendance native) doive se recompiler faute de binaire préconstruit pour cette combinaison OS/architecture — pas systématiquement nécessaire, mais évite un échec déroutant si c'est le cas.

## 6. Déployer le serveur

```bash
sudo -u organic -i
git clone https://github.com/OrganicEconomy/organic-webserver.git
cd organic-webserver/organic-webserver
npm install --omit=dev
```

Générer `ORGANIC_SECRET_KEY` (64 caractères hexadécimaux — la clé avec laquelle le serveur signe en tant que référent). **La noter aussi ailleurs que sur le Pi** (un gestionnaire de mots de passe) — sa perte est irréversible pour l'identité de ce serveur, et une carte SD peut mourir.

Créer `.env` à la racine du dépôt :

```
ORGANIC_SECRET_KEY=<ta clé de 64 caractères hex>
ORGANIC_SERVER_NAME=<le nom affiché de ton serveur>
```

## 7. Le faire tourner comme service systemd

`/etc/systemd/system/organic-webserver.service` :

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
sudo systemctl status organic-webserver     # doit afficher active (running)
journalctl -u organic-webserver -f          # logs en direct
```

## 8. Un nom d'hôte public (DuckDNS)

Pas de nom de domaine à toi ? [DuckDNS](https://www.duckdns.org) fournit un sous-domaine gratuit (`<nom>.duckdns.org`) avec une mise à jour d'IP dynamique intégrée. Créer un compte, réserver un nom, puis lancer leur script de mise à jour sur un intervalle régulier (un timer systemd toutes les 5 minutes est plus fiable qu'un simple cron) pour qu'il reste pointé sur ton IP domicile à chaque changement.

## 9. Redirection de port

Dans ton routeur, rediriger les ports externes **80** et **443** vers l'IP locale fixe du Pi, mêmes ports côté Pi — ça garde la config Caddy ci-dessous simple (pas de port personnalisé).

## 10. Caddy (TLS automatique)

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install caddy
```

Adapter [Caddyfile.example](Caddyfile.example) avec ton vrai nom d'hôte et le copier vers `/etc/caddy/Caddyfile` :

```
<ton-nom>.duckdns.org {
    reverse_proxy localhost:8080
}
```

```bash
sudo systemctl reload caddy
```

Caddy obtient et renouvelle seul son certificat Let's Encrypt — ça ne fonctionne qu'une fois les ports 80/443 réellement joignables depuis internet (étape 9).

## 11. Sauvegardes

`data/organic.sqlite` est un fichier unique. Un cron quotidien qui le copie ailleurs suffit :

```
0 3 * * * cp /home/organic/organic-webserver/organic-webserver/data/organic.sqlite /chemin/vers/backup/organic-$(date +\%F).sqlite
```

Ajouter une rotation simple (garder les N derniers jours) pour que les sauvegardes ne remplissent pas le disque. À plus long terme, envisager un démarrage sur SSD USB plutôt que sur la carte SD — les cartes SD sont le point de panne le plus fréquent sur un Pi qui tourne en continu.

## Vérifier le déploiement

Depuis une machine hors de ton LAN (un téléphone en 4G convient bien, pour être sûr de sortir vraiment par internet) :

```bash
E2E_BASE_URL=https://<ton-nom>.duckdns.org npm run e2e
```

(même scénario que [la vérification du déploiement docker](README.md#verifying-a-deployment) — genèse, création de monnaie quotidienne, un paiement en ligne, un billet papier, et les deux rejets de fraude.) Vérifier aussi que le certificat HTTPS est valide (pas d'avertissement navigateur), et que les deux services survivent à un redémarrage :

```bash
sudo reboot
# une fois redémarré :
sudo systemctl status organic-webserver caddy   # les deux en active (running)
```
