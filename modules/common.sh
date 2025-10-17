#!/bin/bash
# -----------------------------------------------
# Common functions for Fail2Ban installer
# -----------------------------------------------

install_fail2ban_base() {
  echo "[*] Starting Fail2Ban base installation..."

  # Check existing status
  if systemctl is-active --quiet fail2ban; then
    echo "[!] Fail2Ban is already active. Continuing setup..."
  fi

  apt update -y
  apt install -y fail2ban curl

  mkdir -p /etc/fail2ban/jail.d

  # Detect firewall backend
  echo "[~] Detecting firewall backend..."
  if command -v nft >/dev/null 2>&1; then
    echo "[+] nftables detected."
    BAN_ACTION="nftables-allports"
  elif command -v iptables >/dev/null 2>&1; then
    echo "[+] iptables detected."
    BAN_ACTION="iptables-allports"
  else
    echo "[!] Installing iptables..."
    apt install -y iptables
    if command -v iptables >/dev/null 2>&1; then
      echo "[+] iptables installed successfully."
      BAN_ACTION="iptables-allports"
    else
      echo "[X] Failed to install iptables. Please install manually."
      exit 1
    fi
  fi

  export BAN_ACTION

  # Detect public IP safely
  MYIP=$(curl -fsSL https://api.ipify.org)
  [ -z "$MYIP" ] && MYIP=$(hostname -I | awk '{print $1}')
  export MYIP
  echo "[i] Detected IP for whitelist: ${MYIP}"

  setup_telegram
}

setup_telegram() {
  read -p "[+] Enter Telegram Bot Token (leave empty to skip): " TG_TOKEN
  if [ -n "$TG_TOKEN" ]; then
    read -p "[+] Enter Telegram Chat ID: " TG_CHATID
    if [ -z "$TG_CHATID" ]; then
      echo "[!] Chat ID not provided — Telegram notifications disabled."
      TG_TOKEN=""
    fi
    read -p "[+] Enter Server Name: " SERVER_NAME
    if [ -z "$SERVER_NAME" ]; then
      echo "[!] Server name not provided — Telegram notifications disabled."
      TG_TOKEN=""
    fi
  fi

  if [ -n "$TG_TOKEN" ]; then
    cat <<CONF > /etc/fail2ban/telegram.conf
BOT_TOKEN="${TG_TOKEN}"
CHAT_ID="${TG_CHATID}"
SERVER_NAME="${SERVER_NAME}"
CONF
    chmod 600 /etc/fail2ban/telegram.conf
    chown root:root /etc/fail2ban/telegram.conf

    cat <<'BINSCRIPT' > /usr/local/bin/fail2ban-telegram.sh
#!/bin/bash
set +e
CONF="/etc/fail2ban/telegram.conf"
[ ! -f "$CONF" ] && exit 0
source "$CONF"
[ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ] && exit 0

ACTION="$1"; JAIL="$2"; IP="$3"; FAILURES="$4"; TIME="$5"
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%SZ (UTC)")

if [ "$ACTION" = "ban" ]; then
  TEXT="🚨 Fail2Ban Alert 🚨

💻 Server: ${SERVER_NAME}
🔒 Jail: ${JAIL}
🌐 IP Blocked: ${IP}
❌ Failed Attempts: ${FAILURES}
🕒 Time: ${TIMESTAMP}"
else
  TEXT="ℹ️ Fail2Ban Notice ℹ️

💻 Server: ${SERVER_NAME}
🔓 Jail: ${JAIL}
🌐 IP: ${IP}
⚠️ Action performed: ${ACTION}
🕒 Time: ${TIMESTAMP}"
fi

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="${CHAT_ID}" \
  --data-urlencode "text=${TEXT}" >/dev/null 2>&1 || true
exit 0
BINSCRIPT

    chmod 750 /usr/local/bin/fail2ban-telegram.sh
    chown root:root /usr/local/bin/fail2ban-telegram.sh

    cat <<'ACTION' > /etc/fail2ban/action.d/telegram.conf
[Definition]
actionstart =
actionstop =
actioncheck =
actionban = /usr/local/bin/fail2ban-telegram.sh ban <name> <ip> <failures> <time>
actionunban =
ACTION

    chmod 644 /etc/fail2ban/action.d/telegram.conf
  fi

  export TG_TOKEN
}

finish_fail2ban_setup() {
  echo "[~] Enabling and starting Fail2Ban..."
  systemctl enable fail2ban >/dev/null 2>&1
  systemctl restart fail2ban
  sleep 5

  if systemctl is-active --quiet fail2ban; then
    echo "[OK] Fail2Ban is running."
  else
    echo "[X] Fail2Ban failed to start. Check logs with:"
    echo "    journalctl -u fail2ban -xe"
  fi

  echo "[~] Reloading Fail2Ban configuration..."
  fail2ban-client reload >/dev/null 2>&1 || true

  echo "[~] Checking Fail2Ban status..."
  if fail2ban-client ping >/dev/null 2>&1; then
    echo "[✔] Fail2Ban is responsive."
  else
    echo "[!] Fail2Ban did not respond. Check service logs."
  fi

  cat <<'INFO'

[✔] Fail2Ban installation and configuration completed successfully!

General status:
  sudo fail2ban-client status

List active jails:
  sudo fail2ban-client status | grep "Jail list"

To check a specific jail (example: sshd):
  sudo fail2ban-client status <jailname>

View banned IPs for a jail:
  sudo fail2ban-client get <jailname> banned

Unban a specific IP:
  sudo fail2ban-client set <jailname> unbanip <IP_ADDRESS>

INFO
}
