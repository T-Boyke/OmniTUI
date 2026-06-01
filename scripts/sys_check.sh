#!/usr/bin/env bash
# ==============================================================================
# OmniTUI Module: sys_check.sh
# Autor: Tobias Boyke
# Zweck: SystemprÃ¼fungen, Root/Sudoers-HÃ¤rtung und Paket-AbhÃ¤ngigkeiten
# ==============================================================================

set -euo pipefail

# Lade gemeinsame Variablen und Funktionen
source "$(dirname "$(readlink -f "$0")")/common.sh"

# 1. Root / Sudo-Rechte PrÃ¼fung
CURRENT_USER=$(whoami)

if [[ "$CURRENT_USER" != "root" ]]; then
    # PrÃ¼fen, ob der User in sudoers ist
    if ! sudo -n true 2>/dev/null; then
        log_info "Benutzer $CURRENT_USER ist nicht in der sudoers-Datei oder benÃ¶tigt Passwort."
        
        # Versuche, den User in sudoers hinzuzufÃ¼gen
        echo "=========================================================="
        echo "SUDOERS-ASSISTENT: Autorisierung als Root erforderlich..."
        echo "=========================================================="
        
        if command -v su >/dev/null 2>&1; then
            # HinzufÃ¼gen zur Wheel-Gruppe (RHEL/Arch) oder Sudo-Gruppe (Debian)
            if [ -f /etc/debian_version ]; then
                su -c "usermod -aG sudo $CURRENT_USER" || log_err "Root-Passwort inkorrekt oder 'su' fehlgeschlagen"
            else
                su -c "usermod -aG wheel $CURRENT_USER" || log_err "Root-Passwort inkorrekt oder 'su' fehlgeschlagen"
            fi
            log_success "Benutzer $CURRENT_USER wurde erfolgreich zu den Administratoren hinzugefÃ¼gt!"
            log_info "Bitte Ã¶ffnen Sie ein neues Terminal, damit die Gruppenrechte aktiv werden, und starten Sie das Skript erneut."
            exit 0
        else
            log_err "Befehl 'su' ist nicht verfÃ¼gbar. Bitte fÃ¼gen Sie den User manuell zur sudoers hinzu."
        fi
    fi
fi

# 2. Distribution & Paketmanager erkennen
log_info "Erkenne Linux-Distribution..."
if [ -f /etc/debian_version ]; then
    DISTRO="DEBIAN"
    INSTALL_CMD="sudo apt-get update -y && sudo apt-get install -y"
elif [ -f /etc/redhat-release ]; then
    DISTRO="ROCKY"
    INSTALL_CMD="sudo dnf install -y"
elif [ -f /etc/arch-release ]; then
    DISTRO="ARCH"
    INSTALL_CMD="sudo pacman -Sy --noconfirm"
else
    log_err "Nicht unterstÃ¼tzte Distribution."
fi
log_success "Distribution erkannt: $DISTRO"

# 3. AbhÃ¤ngigkeiten prÃ¼fen und installieren
DEPS=(whiptail ping curl git python3 nftables)

log_info "ÃœberprÃ¼fe erforderliche Pakete..."
for dep in "${DEPS[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        log_info "Paket '$dep' fehlt. Installiere..."
        # Mappe Paketnamen passend zur Distro falls abweichend
        PKG_NAME="$dep"
        if [[ "$dep" == "ping" ]]; then
            if [[ "$DISTRO" == "DEBIAN" ]]; then PKG_NAME="iputils-ping"; fi
        elif [[ "$dep" == "whiptail" ]]; then
            if [[ "$DISTRO" == "ROCKY" ]]; then PKG_NAME="newt"; fi
        fi
        
        $INSTALL_CMD "$PKG_NAME" || log_err "Installation von $PKG_NAME fehlgeschlagen."
        log_success "'$dep' erfolgreich installiert."
    fi
done

log_success "Alle System- und Software-AbhÃ¤ngigkeiten sind erfÃ¼llt!"
