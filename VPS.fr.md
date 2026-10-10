# Déployer sur un VPS

*[🇬🇧 English version](VPS.md)*

`deploy-vps.sh` installe un serveur communautaire sur un VPS **Debian** neuf, en une seule exécution interactive : SQLite, systemd, et Caddy pour le HTTPS. Il reprend [RASPBERRY_PI.fr.md](RASPBERRY_PI.fr.md), sans tout ce dont un VPS n'a pas besoin : ses IPv4 et IPv6 publiques sont fixes, donc pas de DNS dynamique, de redirection de port ni de CGNAT à gérer.

## Avant de commencer

- Un VPS **Debian 12 ou 13**, avec l'accès root (ou sudo) fourni par ton hébergeur.
- Un **domaine ou sous-domaine** dont tu peux modifier la zone DNS (ex. `test.economie-organique.fr` chez OVH).
- Une **paire de clés SSH** sur ton ordinateur. Si tu n'en as pas encore : `ssh-keygen -t ed25519`. Le script te demandera d'en coller la partie publique, que tu peux afficher avec :
  - macOS/Linux : `cat ~/.ssh/id_ed25519.pub`
  - Windows (PowerShell) : `type $env:USERPROFILE\.ssh\id_ed25519.pub`
- Un **gestionnaire de mots de passe** sous la main : le script affiche deux clés à noter impérativement.

## Installer

Se connecter au VPS avec l'accès fourni par l'hébergeur, puis :

```bash
sudo apt update && sudo apt install -y git
sudo git clone https://github.com/OrganicEconomy/organic-deploy.git /opt/organic-deploy
sudo bash /opt/organic-deploy/deploy-vps.sh
```

Le script commence par demander tout ce dont il a besoin : nom de l'admin, clé publique SSH, domaine, nom du serveur, origines CORS en plus, et nombre de jours de sauvegardes à garder. Il affiche un récapitulatif, attend `yes`, puis installe étape par étape.

Trois moments demandent ton intervention :

1. **La vérification SSH.** Le script crée ton utilisateur admin, puis te demande d'ouvrir **un autre terminal** et d'y lancer `ssh <admin>@<ip>` suivi de `sudo -v`. Ne tape la phrase demandée (`<admin> can log in and sudo`) qu'une fois que les deux marchent : la connexion root et les mots de passe sont désactivés juste après, et une erreur à ce moment-là te bloquerait dehors. Garde en tête la console web de ton hébergeur (KVM/VNC) comme dernier recours.
2. **Les clés.** `ORGANIC_SECRET_KEY` (l'identité du serveur) et `ORGANIC_MASTER_KEY` (qui déchiffre toutes les clés d'écosystème en base) ne sont affichées **qu'une fois**. Note-les ailleurs que sur le serveur, puis tape `noted`. Leur perte est irréversible.
3. **Le DNS.** Le script affiche l'IPv4 et l'IPv6 publiques du VPS. Crée les enregistrements **A** et **AAAA** correspondants pour ton domaine, puis appuie sur Entrée jusqu'à ce qu'il soit résolu. Caddy ne peut pas obtenir de certificat HTTPS avant.

Relancer le script ne présente aucun risque : les utilisateurs existants, le code du serveur et surtout les clés du `.env` sont conservés tels quels.

## Vérifier le déploiement

Depuis ton ordinateur, dans `organic-webserver/organic-webserver` :

```bash
E2E_BASE_URL=https://<ton-domaine> npm run e2e
```

Essaie aussi le serveur depuis un réseau sans IPv6 (un VPN, par exemple) : il doit répondre là aussi.

## Mettre à jour le serveur

```bash
ssh <admin>@<ton-domaine>
sudo git -C /opt/organic-deploy pull
sudo bash /opt/organic-deploy/deploy-vps.sh update
```

`update` sauvegarde la base, récupère le dernier code du serveur, installe ses dépendances, redémarre le service et vérifie qu'il répond.

## Sauvegardes

Chaque jour à 3 h, `/usr/local/bin/organic-backup` copie la base dans `/var/backups/organic/organic-<date>.sqlite` et supprime les copies plus anciennes que la durée choisie. Il utilise `sqlite3 .backup`, sans danger pendant que le serveur tourne.

Ces sauvegardes restent **sur le VPS**, donc elles ne survivraient pas à sa perte : copies-en une ailleurs de temps en temps. Sur le VPS :

```bash
sudo install -o "$USER" /var/backups/organic/organic-<date>.sqlite ~/
```

puis depuis ton ordinateur :

```bash
scp <admin>@<ton-domaine>:organic-<date>.sqlite .
```

Pour en restaurer une :

```bash
sudo systemctl stop organic-webserver
sudo cp /var/backups/organic/organic-<date>.sqlite /home/organic/organic-webserver/organic-webserver/data/organic.sqlite
sudo chown organic:organic /home/organic/organic-webserver/organic-webserver/data/organic.sqlite
sudo systemctl start organic-webserver
```

Une sauvegarde n'est utilisable qu'avec la `ORGANIC_MASTER_KEY` avec laquelle elle a été faite.

## Commandes utiles

```bash
sudo systemctl status organic-webserver caddy   # les deux en active (running)
journalctl -u organic-webserver -f              # logs du serveur en direct
journalctl -u caddy                             # problèmes de certificat HTTPS
```
