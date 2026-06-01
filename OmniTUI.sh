#!/usr/bin/env bash
# ==============================================================================
# Master TUI: OmniTUI.sh
# Autor: Tobias Boyke
# Zweck: Zentrale Interaktive Steuerung fÃ¼r Netzwerk, Services & Tweaks (FHD Optimiert)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONFIG_PATH="${SCRIPT_DIR}/config.yaml"
PARSER="${SCRIPT_DIR}/scripts/parse_config.py"

# Automatische Berechtigungserteilung fÃ¼r alle Sub-Skripte beim Start
chmod +x "${SCRIPT_DIR}/OmniTUI.sh" "${SCRIPT_DIR}"/scripts/*.sh "${SCRIPT_DIR}"/scripts/*.py 2>/dev/null || true

# FHD-optimierte Whiptail-GrÃ¶ÃŸen
W_HEIGHT=24
W_WIDTH=95
W_LIST=16

# Stellt sicher, dass das Terminal nach dem Beenden wieder sauber aussieht
cleanup() {
    clear
}
trap cleanup EXIT

# 1. SystemprÃ¼fungen beim Start
bash "${SCRIPT_DIR}/scripts/sys_check.sh"

# Hostname ermitteln
CURRENT_HOST=$(hostname -s)

while true; do
    CHOICE=$(whiptail --title "OmniTUI (OmniTUI) - Day 17 [FHD Edition]" \
                      --menu "Zentrales VerwaltungsmenÃ¼ (Host: $CURRENT_HOST)\nBitte wÃ¤hlen Sie eine Administrations-Aufgabe:" $W_HEIGHT $W_WIDTH $W_LIST \
                      "1" "SystemprÃ¼fungen & AbhÃ¤ngigkeiten (sys_check)" \
                      "2" "DNS-Latenz-Benchmark & Selektor (dns_selector)" \
                      "3" "Router-Setup (IP, Forwarding, nftables-NAT)" \
                      "4" "Client-Setup (Schnittstellen & Profiling)" \
                      "5" "Dienste verwalten & SSH-HÃ¤rtung (services)" \
                      "6" "System Tuning & TCP/BBR Optimierung (tweaks)" \
                      "7" "Uniforme CLI-Tools, ZSH & Aliases (tools)" \
                      "8" "Cronjob Maker TUI (cron_maker)" \
                      "9" "Desktop Ricing & Premium Eyecandy (ricing)" \
                      "10" "System- & Netzwerk-Diagnose / Doctor (diagnostics)" \
                      "11" "Subnetz-Scanner / Host-Discovery (subnet_scanner)" \
                      "12" "NTP Zeitsynchronisation & Zeitserver (ntp_setup)" \
                      "13" "Backup & Wiederherstellungs Manager (backup_manager)" \
                      "14" "YAML-Konfiguration interaktiv editieren (config_editor)" \
                      "15" "YAML-Konfiguration roh anzeigen (config.yaml)" \
                      "16" "Alles sequenziell ausfÃ¼hren (Voll-Setup)" \
                      "0" "Beenden" 3>&1 1>&2 2>&3)

    if [[ -z "$CHOICE" || "$CHOICE" == "0" ]]; then
        break
    fi

    case "$CHOICE" in
        "1")
            bash "${SCRIPT_DIR}/scripts/sys_check.sh"
            whiptail --title "Check Komplett" --msgbox "Die SystemprÃ¼fung war erfolgreich." 8 $W_WIDTH
            ;;
        "2")
            bash "${SCRIPT_DIR}/scripts/dns_selector.sh"
            ;;
        "3")
            sudo bash "${SCRIPT_DIR}/scripts/router_setup.sh"
            ;;
        "4")
            sudo bash "${SCRIPT_DIR}/scripts/client_setup.sh"
            ;;
        "5")
            sudo bash "${SCRIPT_DIR}/scripts/services_mgmt.sh"
            ;;
        "6")
            sudo bash "${SCRIPT_DIR}/scripts/system_tweaks.sh"
            ;;
        "7")
            sudo bash "${SCRIPT_DIR}/scripts/tools_installer.sh"
            ;;
        "8")
            sudo bash "${SCRIPT_DIR}/scripts/cron_maker.sh"
            ;;
        "9")
            sudo bash "${SCRIPT_DIR}/scripts/desktop_ricing.sh"
            ;;
        "10")
            sudo bash "${SCRIPT_DIR}/scripts/diagnostics.sh"
            ;;
        "11")
            sudo bash "${SCRIPT_DIR}/scripts/subnet_scanner.sh"
            ;;
        "12")
            sudo bash "${SCRIPT_DIR}/scripts/ntp_setup.sh"
            ;;
        "13")
            sudo bash "${SCRIPT_DIR}/scripts/backup_manager.sh"
            ;;
        "14")
            sudo bash "${SCRIPT_DIR}/scripts/config_editor.sh"
            ;;
        "15")
            # Config Datei formatiert in Textbox ausgeben
            whiptail --title "Konfigurations-Struktur (config.yaml)" --scrolltext --textbox "$CONFIG_PATH" 22 85
            ;;
        "16")
            # VollstÃ¤ndiges sequenzielles Setup ausfÃ¼hren
            if whiptail --title "Voll-Setup bestÃ¤tigen" --yesno "MÃ¶chten Sie das komplette System-Setup sequenziell ausfÃ¼hren?" 10 70; then
                sudo bash "${SCRIPT_DIR}/scripts/sys_check.sh"
                
                # Rolle ermitteln
                ROUTER_HOST=$(python3 "$PARSER" "$CONFIG_PATH" "router:hostname")
                if [[ "$CURRENT_HOST" == "$ROUTER_HOST" ]]; then
                    sudo bash "${SCRIPT_DIR}/scripts/router_setup.sh"
                else
                    sudo bash "${SCRIPT_DIR}/scripts/client_setup.sh"
                fi
                
                sudo bash "${SCRIPT_DIR}/scripts/system_tweaks.sh"
                sudo bash "${SCRIPT_DIR}/scripts/services_mgmt.sh"
                sudo bash "${SCRIPT_DIR}/scripts/tools_installer.sh"
                sudo bash "${SCRIPT_DIR}/scripts/ntp_setup.sh"
                
                whiptail --title "Voll-Setup beendet" --msgbox "Alle Skripte wurden erfolgreich nacheinander ausgefÃ¼hrt!" 8 60
            fi
            ;;
    esac
done
