#!/usr/bin/env bash
# ==============================================================================
# OmniTUI Shared Library: common.sh
# Autor: Tobias Boyke
# Zweck: Gemeinsame Variablen, Pfade und Hilfsfunktionen (DRY & SOC)
# ==============================================================================

# 1. Gemeinsame Pfade ermitteln (relativ zum Skriptverzeichnis)
COMMON_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
PROJECT_DIR="$(dirname "$COMMON_DIR")"
CONFIG_PATH="${PROJECT_DIR}/config.yaml"
PARSER="${COMMON_DIR}/parse_config.py"
UPDATER="${COMMON_DIR}/update_config.py"

# 2. FHD-optimierte Whiptail-Standardgrößen
W_HEIGHT=24
W_WIDTH=95
W_LIST=16

# 3. Gemeinsame Logging-Funktionen
log_info() { echo -e "\e[34m[INFO]\e[0m $1"; }
log_success() { echo -e "\e[32m[ERFOLG]\e[0m $1"; }
log_err() { echo -e "\e[31m[FEHLER]\e[0m $1"; exit 1; }

# 4. Root-Rechteprüfung Helper
require_root() {
    if [[ $EUID -ne 0 ]]; then
        whiptail --title "Root-Privilegien benötigt" \
                 --msgbox "Dieses Skript benötigt Administratorrechte (sudo). Bitte starten Sie diesen Vorgang mit sudo." 8 75
        exit 1
    fi
}
