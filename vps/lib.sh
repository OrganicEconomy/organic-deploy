#!/usr/bin/env bash

NODE_PORT=8080
SERVICE_USER=organic
SERVER_DIR=/home/$SERVICE_USER/organic-webserver/organic-webserver
ENV_FILE=$SERVER_DIR/.env

resolve_command() {
  local argument="${1:-install}"
  case "$argument" in
    install | update) echo "$argument" ;;
    help | -h | --help) echo "help" ;;
    *) return 1 ;;
  esac
}

print_usage() {
  cat <<'USAGE'
Usage: sudo bash deploy-vps.sh [command]

Commands:
  install   Interactively set up an Organic Economy server on this VPS (default)
  update    Back up the database, pull the latest server code and restart it
  help, -h, --help
            Show this help

The install and update commands must be run as root, on a Debian VPS.
USAGE
}

generate_secret_key() {
  openssl rand -hex 32
}

is_valid_domain() {
  local domain="$1"
  local label='[a-z0-9]([a-z0-9-]*[a-z0-9])?'
  [[ "$domain" =~ ^($label\.)+[a-z]{2,}$ ]]
}

is_valid_ssh_public_key() {
  local public_key="$1"
  local key_type="(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp[0-9]+)"
  local base64_body="[A-Za-z0-9+/=]+"
  local public_key_pattern="^$key_type $base64_body"
  [[ "$public_key" =~ $public_key_pattern ]]
}

is_valid_username() {
  local username="$1"
  [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] && ! is_reserved_username "$username"
}

is_reserved_username() {
  local username="$1"
  [[ "$username" == "root" || "$username" == "$SERVICE_USER" ]]
}

render_env() {
  local secret_key="$1" master_key="$2" server_name="$3" cors_extra_origins="$4"
  cat <<ENV
ORGANIC_SECRET_KEY=$secret_key
ORGANIC_MASTER_KEY=$master_key
ORGANIC_SERVER_NAME=$server_name
CORS_EXTRA_ORIGINS=$cors_extra_origins
NODE_LOCAL_PORT=$NODE_PORT
ENV
}

render_systemd_unit() {
  cat <<UNIT
[Unit]
Description=Organic Economy webserver
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$SERVER_DIR
EnvironmentFile=$ENV_FILE
ExecStart=/usr/bin/node --import tsx server.ts
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
}

render_caddyfile() {
  local domain="$1"
  cat <<CADDYFILE
$domain {
    reverse_proxy 127.0.0.1:$NODE_PORT
}
CADDYFILE
}

render_sshd_hardening() {
  local admin_user="$1"
  cat <<SSHD
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
AllowUsers $admin_user
SSHD
}

render_backup_script() {
  local database_file="$1" backup_dir="$2" retention_days="$3"
  cat <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
sqlite3 "$database_file" ".backup '$backup_dir/organic-\$(date +%F).sqlite'"
find "$backup_dir" -name 'organic-*.sqlite' -mtime +$retention_days -delete
SCRIPT
}

render_backup_cron() {
  local backup_script="$1"
  echo "0 3 * * * root $backup_script"
}

has_server_keys() {
  local env_file="$1"
  grep -q "^ORGANIC_MASTER_KEY=." "$env_file" 2>/dev/null
}

ask() {
  local question="$1" default="${2:-}"
  local answer
  printf "%s%s: " "$question" "${default:+ [$default]}" >&2
  read -r answer || return 1
  echo "${answer:-$default}"
}

ask_until_valid() {
  local question="$1" validator="$2" default="${3:-}"
  local answer
  while answer="$(ask "$question" "$default")"; do
    if "$validator" "$answer"; then
      echo "$answer"
      return 0
    fi
    echo "Invalid value, please try again." >&2
  done
  return 1
}

is_positive_integer() {
  local value="$1"
  [[ "$value" =~ ^[1-9][0-9]*$ ]]
}

is_not_empty() {
  local value="$1"
  [[ -n "$value" ]]
}

wait_for_word() {
  local expected_word="$1"
  local answer
  while answer="$(ask "Type '$expected_word' to continue")"; do
    [[ "$answer" == "$expected_word" ]] && return 0
  done
  return 1
}
