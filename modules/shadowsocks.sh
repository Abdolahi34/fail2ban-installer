#!/bin/bash
# -----------------------------------------------
# Shadowsocks Jail Configuration for Fail2Ban
# -----------------------------------------------

setup_shadowsocks_fail2ban() {
  echo "[*] Setting up Fail2Ban for Shadowsocks..."

  read -p "[+] Select Shadowsocks version: 
  1) shadowsocks-libev
  2) shadowsocks-rust
  Choice [1-2]: " SS_TYPE
  SS_TYPE=${SS_TYPE:-1}

  if [ "$SS_TYPE" = "1" ]; then
    BACKEND="auto"
    LOGPATH="/var/log/shadowsocks-libev/ss-server.log"
  elif [ "$SS_TYPE" = "2" ]; then
    BACKEND="systemd"
    LOGPATH="%(systemd_journal)s"
  else
    echo "[X] Invalid choice."
    exit 1
  fi

  if [ "$BACKEND" = "systemd" ]; then
    LOG_LINE="logpath = %(systemd_journal)s"
  else
    LOG_LINE="logpath = ${LOGPATH}"
  fi

  # Ask user for port number
  read -p "[+] Enter Shadowsocks port [default: 8388]: " SS_PORT
  SS_PORT=${SS_PORT:-8388}
  if [ -z "$SS_PORT" ]; then
    echo "[!] Shadowsocks port not provided. Use Default port."
  fi

  # Filter
  cat <<'EOF' > /etc/fail2ban/filter.d/shadowsocks.conf
[Definition]
failregex = ^.*ERROR.*invalid password or cipher from <HOST>:.*$
            ^.*WARNING.*can not parse header when handling connection from <HOST>:.*$
ignoreregex =
EOF

  local JAIL_FILE="/etc/fail2ban/jail.d/shadowsocks.local"

  cat <<EOF > "$JAIL_FILE"
[shadowsocks]
enabled = true
port = ${SS_PORT}
filter = shadowsocks
${LOG_LINE}
backend = ${BACKEND}
maxretry = 5
findtime = 10m
bantime = 1h
ignoreip = 127.0.0.1/8 ::1 ${MYIP:-127.0.0.1}
EOF

  # Remove duplicate action lines if any
  sed -i '/^action/d' "$JAIL_FILE"

  if [ -n "$TG_TOKEN" ]; then
    cat <<EOF >> "$JAIL_FILE"
action = ${BAN_ACTION}
         telegram
EOF
  else
    echo "action = ${BAN_ACTION}" >> "$JAIL_FILE"
  fi

  echo "[+] Shadowsocks jail configured for port ${SS_PORT}."

  # --- Check jail status ---
  sleep 3
  echo "[~] Checking Shadowsocks jail status..."
  if fail2ban-client status shadowsocks >/dev/null 2>&1; then
    echo "[✔] Shadowsocks jail is active."
  else
    echo "[!] Shadowsocks jail not detected yet. Try: sudo fail2ban-client status shadowsocks"
  fi
}
