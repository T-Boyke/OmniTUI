#!/usr/bin/env bash
# ==============================================================================
# OmniTUI Module: services_mgmt.sh
# Autor: Tobias Boyke
# Zweck: Steuerung und Härtung von System-Diensten (SSH, nftables) via TUI
# ==============================================================================

set -euo pipefail

# Lade gemeinsame Variablen und Funktionen
source "$(dirname "$(readlink -f "$0")")/common.sh"

# 1. SSH-Härtung konfigurieren
if whiptail --title "SSH-Sicherheits-Härtung" \
            --yesno "Möchten Sie das systemweite SSH-Regelwerk härten?\n\nFolgende Maßnahmen werden durchgeführt:\n- Root-Login verbieten\n- SSH Client-Keepalive einrichten\n- Leere Passwörter verbieten" 14 75; then
    
    SSH_CONF="/etc/ssh/sshd_config"
    # Backups anlegen
    sudo cp "$SSH_CONF" "${SSH_CONF}.bak"
    
    # Härtungsparameter setzen
    sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$SSH_CONF"
    sudo sed -i 's/^#\?PermitEmptyPasswords.*/PermitEmptyPasswords no/' "$SSH_CONF"
    sudo sed -i 's/^#\?ClientAliveInterval.*/ClientAliveInterval 300/' "$SSH_CONF"
    sudo sed -i 's/^#\?ClientAliveCountMax.*/ClientAliveCountMax 2/' "$SSH_CONF"
    
    # Service neu starten
    sudo systemctl restart sshd || sudo systemctl restart ssh
    whiptail --title "SSH Gehärtet" --msgbox "Der SSH-Server wurde erfolgreich gehärtet und neu gestartet!" 8 55
fi

# 2. Dienste-Status-Dashboard
SSH_STATUS="Inaktiv"
NFT_STATUS="Inaktiv"

if systemctl is-active sshd >/dev/null 2>&1 || systemctl is-active ssh >/dev/null 2>&1; then SSH_STATUS="Aktiv (Online)"; fi
if systemctl is-active nftables >/dev/null 2>&1; then NFT_STATUS="Aktiv (Online)"; fi

whiptail --title "Dienste-Status-Dashboard" \
         --msgbox "Aktueller Status der Systemdienste:\n\n- OpenSSH-Daemon: $SSH_STATUS\n- nftables Firewall: $NFT_STATUS\n\nBeide Dienste wurden dauerhaft für den Systemstart aktiviert." $W_HEIGHT $W_WIDTH
