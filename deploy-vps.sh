#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DEPLOY_DIR/vps/lib.sh"
source "$DEPLOY_DIR/vps/steps.sh"

install_server() {
  ensure_running_as_root
  ensure_debian_with_systemd
  ask_installation_settings
  confirm_installation_settings
  upgrade_system_packages
  create_admin_user
  harden_ssh_once_admin_login_works
  enable_firewall
  create_service_user
  install_nodejs
  install_server_code
  write_server_keys
  install_systemd_service
  wait_for_server_health
  wait_for_dns
  install_caddy
  check_https
  print_installation_summary
}

main() {
  local command
  if ! command="$(resolve_command "${1:-}")"; then
    print_usage
    exit 1
  fi
  case "$command" in
    help) print_usage ;;
    install) install_server ;;
    update) fail "the update command is not available yet." ;;
  esac
}

main "$@"
