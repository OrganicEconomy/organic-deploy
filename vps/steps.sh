#!/usr/bin/env bash

SERVER_REPOSITORY=https://github.com/OrganicEconomy/organic-webserver.git
SERVICE_HOME=/home/$SERVICE_USER
SYSTEMD_UNIT_FILE=/etc/systemd/system/organic-webserver.service
SSHD_DROP_IN_FILE=/etc/ssh/sshd_config.d/00-organic.conf
CADDYFILE=/etc/caddy/Caddyfile
HEALTH_URL=http://127.0.0.1:$NODE_PORT/api/v1/info

announce() {
  printf '\n==> %s\n' "$1"
}

fail() {
  echo "Error: $1" >&2
  exit 1
}

ensure_running_as_root() {
  [[ "$(id -u)" == 0 ]] || fail "this command must be run as root (try: sudo bash deploy-vps.sh)."
}

ensure_debian_with_systemd() {
  grep -q '^ID=debian' /etc/os-release 2>/dev/null || fail "this script only supports Debian."
  [[ -d /run/systemd/system ]] || fail "systemd is not running on this machine."
}

ask_installation_settings() {
  announce "A few questions before installing"
  ADMIN_USER="$(ask_until_valid "Admin username (your own SSH login, not root)" is_valid_username)"
  ADMIN_PUBLIC_KEY="$(ask_until_valid "Your SSH public key (content of ~/.ssh/id_ed25519.pub)" is_valid_ssh_public_key)"
  DOMAIN="$(ask_until_valid "Domain name of the server (e.g. test.economie-organique.fr)" is_valid_domain)"
  SERVER_NAME="$(ask_until_valid "Server name shown in the app" is_not_empty)"
  CORS_EXTRA_ORIGINS="$(ask "Extra CORS origins, comma-separated (leave empty if unsure)")"
  BACKUP_RETENTION_DAYS="$(ask_until_valid "Days of daily backups to keep" is_positive_integer 14)"
}

confirm_installation_settings() {
  cat <<SUMMARY

  Admin user      : $ADMIN_USER
  SSH public key  : ${ADMIN_PUBLIC_KEY:0:40}...
  Domain          : $DOMAIN
  Server name     : $SERVER_NAME
  CORS origins    : ${CORS_EXTRA_ORIGINS:-(none)}
  Backups kept    : $BACKUP_RETENTION_DAYS days

SUMMARY
  echo "Press Ctrl+C now to abort and start over with other answers."
  wait_for_word yes
}

upgrade_system_packages() {
  announce "Upgrading system packages"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl git build-essential python3 ufw sqlite3 openssl sudo ca-certificates gnupg
}

create_admin_user() {
  announce "Creating the admin user $ADMIN_USER"
  id -u "$ADMIN_USER" >/dev/null 2>&1 || useradd --create-home --shell /bin/bash "$ADMIN_USER"
  usermod -aG sudo "$ADMIN_USER"
  install_admin_public_key
  echo "Choose a password for $ADMIN_USER. It is only used by sudo: SSH will accept keys only."
  until passwd "$ADMIN_USER"; do :; done
}

install_admin_public_key() {
  local ssh_dir="/home/$ADMIN_USER/.ssh"
  install -d -m 700 -o "$ADMIN_USER" -g "$ADMIN_USER" "$ssh_dir"
  touch "$ssh_dir/authorized_keys"
  grep -qxF "$ADMIN_PUBLIC_KEY" "$ssh_dir/authorized_keys" || echo "$ADMIN_PUBLIC_KEY" >> "$ssh_dir/authorized_keys"
  chown "$ADMIN_USER:$ADMIN_USER" "$ssh_dir/authorized_keys"
  chmod 600 "$ssh_dir/authorized_keys"
}

public_ipv4() {
  curl -4 -fsS --max-time 5 https://api.ipify.org || echo "none"
}

public_ipv6() {
  curl -6 -fsS --max-time 5 https://api6.ipify.org || echo "none"
}

harden_ssh_once_admin_login_works() {
  announce "Locking SSH down to $ADMIN_USER, with keys only"
  cat <<INSTRUCTIONS
Before root and password logins get disabled, check that your key works.
Keep this terminal open and, in ANOTHER one, run:

    ssh $ADMIN_USER@$(public_ipv4)

and then, once logged in:

    sudo -v

INSTRUCTIONS
  wait_for_word ok
  render_sshd_hardening "$ADMIN_USER" > "$SSHD_DROP_IN_FILE"
  sshd -t || { rm -f "$SSHD_DROP_IN_FILE"; fail "the SSH configuration is invalid, nothing was changed."; }
  systemctl reload ssh
}

enable_firewall() {
  announce "Enabling the firewall (SSH, HTTP, HTTPS only)"
  ufw allow 22/tcp
  ufw allow 80,443/tcp
  ufw --force enable
}

create_service_user() {
  announce "Creating the $SERVICE_USER service user"
  id -u "$SERVICE_USER" >/dev/null 2>&1 ||
    adduser --system --group --home "$SERVICE_HOME" --shell /bin/bash "$SERVICE_USER"
}

install_nodejs() {
  announce "Installing Node.js 22"
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
}

run_as_service_user() {
  runuser -l "$SERVICE_USER" -c "$1"
}

install_server_code() {
  announce "Installing the server code"
  [[ -d "$SERVER_DIR" ]] || run_as_service_user "git clone $SERVER_REPOSITORY"
  run_as_service_user "cd $SERVER_DIR && npm install --omit=dev"
}

write_server_keys() {
  announce "Server keys"
  if has_server_keys "$ENV_FILE"; then
    echo "$ENV_FILE already holds keys: keeping them untouched."
    return
  fi
  local secret_key master_key
  secret_key="$(generate_secret_key)"
  master_key="$(generate_secret_key)"
  install -m 600 -o "$SERVICE_USER" -g "$SERVICE_USER" /dev/null "$ENV_FILE"
  render_env "$secret_key" "$master_key" "$SERVER_NAME" "$CORS_EXTRA_ORIGINS" > "$ENV_FILE"
  show_keys_to_write_down "$secret_key" "$master_key"
}

show_keys_to_write_down() {
  cat <<KEYS

  ################################################################################
  #  WRITE THESE DOWN in a password manager, NOT only on this server.            #
  #  Losing them is irreversible:                                                #
  #    - ORGANIC_SECRET_KEY is the identity of this server,                      #
  #    - ORGANIC_MASTER_KEY decrypts every ecosystem key stored in the database. #
  ################################################################################

  ORGANIC_SECRET_KEY=$1
  ORGANIC_MASTER_KEY=$2

KEYS
  wait_for_word noted
  clear || true
}

install_systemd_service() {
  announce "Starting the server as a systemd service"
  render_systemd_unit > "$SYSTEMD_UNIT_FILE"
  systemctl daemon-reload
  systemctl enable organic-webserver
  systemctl restart organic-webserver
}

wait_for_server_health() {
  for _ in $(seq 1 30); do
    if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
      echo "The server answers on $HEALTH_URL."
      return
    fi
    sleep 1
  done
  fail "the server does not answer on $HEALTH_URL (see: journalctl -u organic-webserver)."
}

wait_for_dns() {
  announce "DNS"
  local ipv4 ipv6
  ipv4="$(public_ipv4)"
  ipv6="$(public_ipv6)"
  cat <<INSTRUCTIONS
In your DNS zone (OVH manager), point $DOMAIN to this server:

    A     $ipv4
    AAAA  $ipv6

Caddy cannot get an HTTPS certificate until the domain resolves here.
INSTRUCTIONS
  until domain_points_here "$ipv4"; do
    local answer
    answer="$(ask "Not resolved yet. Press Enter to check again, or type 'skip'")"
    [[ "$answer" == skip ]] && return
  done
  echo "$DOMAIN resolves to $ipv4."
}

domain_points_here() {
  local ipv4="$1"
  getent ahostsv4 "$DOMAIN" | awk '{ print $1 }' | grep -qxF "$ipv4"
}

install_caddy() {
  announce "Installing Caddy (automatic HTTPS)"
  DEBIAN_FRONTEND=noninteractive apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' |
    gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' > /etc/apt/sources.list.d/caddy-stable.list
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y caddy
  render_caddyfile "$DOMAIN" > "$CADDYFILE"
  systemctl reload caddy
}

check_https() {
  for _ in $(seq 1 12); do
    if curl -fsS "https://$DOMAIN/api/v1/info" >/dev/null 2>&1; then
      echo "https://$DOMAIN answers."
      return
    fi
    sleep 5
  done
  echo "https://$DOMAIN does not answer yet. Once DNS is right, check: journalctl -u caddy"
}

print_installation_summary() {
  cat <<SUMMARY

Installation complete.

  Server      : https://$DOMAIN
  SSH         : ssh $ADMIN_USER@$DOMAIN (root and passwords are disabled)
  Logs        : journalctl -u organic-webserver -f

Check the deployment from your computer, in organic-webserver/organic-webserver:

    E2E_BASE_URL=https://$DOMAIN npm run e2e

SUMMARY
}
