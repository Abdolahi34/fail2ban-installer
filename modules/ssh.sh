#!/bin/bash
# -----------------------------------------------
# SSH Jail Configuration for Fail2Ban
# -----------------------------------------------

setup_ssh_fail2ban() {
  echo "[*] Setting up Fail2Ban for SSH..."

  local JAIL_FILE="/etc/fail2ban/jail.d/ssh.local"

  cat <<EOF > "$JAIL_FILE"
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = %(sshd_log)s
backend = systemd
maxretry = 5
findtime = 10m
bantime = 1h
ignoreip = 127.0.0.1/8 ::1 ${MYIP:-127.0.0.1}
EOF

  # Remove duplicate action lines
  sed -i '/^action/d' "$JAIL_FILE"

  if [ -n "$TG_TOKEN" ]; then
    cat <<EOF >> "$JAIL_FILE"
action = ${BAN_ACTION}
         telegram
EOF
  else
    echo "action = ${BAN_ACTION}" >> "$JAIL_FILE"
  fi

  echo "[+] SSH jail configured."

  # --- Check jail status ---
  sleep 3
  echo "[~] Checking SSH jail status..."
  if fail2ban-client status sshd >/dev/null 2>&1; then
    echo "[✔] SSH jail is active."
  else
    echo "[!] SSH jail not detected yet. Try: sudo fail2ban-client status sshd"
  fi
}
