#!/bin/bash
# -----------------------------------------------
# Fail2Ban Modular Installer (SSH / Shadowsocks)
# -----------------------------------------------

set -e

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
MODULE_DIR="${BASE_DIR}/modules"

# --- Check root privileges ---
if [ "$EUID" -ne 0 ]; then
  echo "[X] Please run this script as root (use sudo)."
  exit 1
fi

# --- Import common functions ---
source "${MODULE_DIR}/common.sh"

echo "-----------------------------------------"
echo " Fail2Ban Auto-Installer"
echo "-----------------------------------------"
echo "Select a service to protect with Fail2Ban:"
echo "1) SSH"
echo "-----------------------------------------"
read -p "Enter your choice [1]: " CHOICE

# --- Base installation ---
install_fail2ban_base

case "$CHOICE" in
  1)
    source "${MODULE_DIR}/ssh.sh"
    setup_ssh_fail2ban
    ;;
  *)
    echo "[X] Invalid choice."
    exit 1
    ;;
esac

finish_fail2ban_setup
