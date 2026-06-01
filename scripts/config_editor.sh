#!/usr/bin/env bash
# ==============================================================================
# OmniTUI Module: config_editor.sh
# Autor: Tobias Boyke
# Zweck: Interaktiver YAML-Konfigurations-Editor (FHD Optimiert)
# ==============================================================================

set -euo pipefail

# Lade gemeinsame Variablen und Funktionen
source "$(dirname "$(readlink -f "$0")")/common.sh"
W_LIST=10

while true; do
    # Aktuelle wichtige Werte auslesen fÃ¼r Anzeige im MenÃ¼
    DNS_FALLBACK=$(python3 "$PARSER" "$CONFIG_PATH" "global:dns_fallback")
    ROUTER_HOST=$(python3 "$PARSER" "$CONFIG_PATH" "router:hostname")
    
    CHOICE=$(whiptail --title "Zentraler YAML-Konfigurations-Editor" \
                      --menu "WÃ¤hlen Sie einen Konfigurationsparameter aus, den Sie live anpassen mÃ¶chten:" $W_HEIGHT $W_WIDTH $W_LIST \
                      "1" "Globaler DNS-Fallback (Aktuell: $DNS_FALLBACK)" \
                      "2" "Router Hostname (Aktuell: $ROUTER_HOST)" \
                      "3" "Client srv-deb-01 IP anpassen" \
                      "4" "Client ws-cachy IP anpassen" \
                      "5" "Client srv-deb-02 IP anpassen" \
                      "6" "Client ws-manjaro IP anpassen" \
                      "0" "ZurÃ¼ck zum HauptmenÃ¼" 3>&1 1>&2 2>&3)

    if [[ -z "$CHOICE" || "$CHOICE" == "0" ]]; then
        break
    fi

    case "$CHOICE" in
        "1")
            NEW_DNS=$(whiptail --title "DNS-Fallback anpassen" \
                               --inputbox "Geben Sie die neuen Nameserver ein (z. B. '1.1.1.1 8.8.8.8'):" 10 70 "$DNS_FALLBACK" 3>&1 1>&2 2>&3)
            if [[ -n "$NEW_DNS" ]]; then
                python3 "$UPDATER" "$CONFIG_PATH" "global:dns_fallback" "$NEW_DNS"
            fi
            ;;
        "2")
            NEW_ROUTER=$(whiptail --title "Router Hostname anpassen" \
                                  --inputbox "Geben Sie den neuen Hostname fÃ¼r den Router ein:" 10 70 "$ROUTER_HOST" 3>&1 1>&2 2>&3)
            if [[ -n "$NEW_ROUTER" ]]; then
                python3 "$UPDATER" "$CONFIG_PATH" "router:hostname" "$NEW_ROUTER"
            fi
            ;;
        "3")
            CUR_IP=$(python3 "$PARSER" "$CONFIG_PATH" "client:srv-deb-01:ip")
            NEW_IP=$(whiptail --title "IP-Adresse srv-deb-01" \
                             --inputbox "Geben Sie die neue IP in CIDR-Notation ein:" 10 70 "$CUR_IP" 3>&1 1>&2 2>&3)
            if [[ -n "$NEW_IP" ]]; then
                python3 "$UPDATER" "$CONFIG_PATH" "client:srv-deb-01:ip" "$NEW_IP"
            fi
            ;;
        "4")
            CUR_IP=$(python3 "$PARSER" "$CONFIG_PATH" "client:ws-cachy:ip")
            NEW_IP=$(whiptail --title "IP-Adresse ws-cachy" \
                             --inputbox "Geben Sie die neue IP in CIDR-Notation ein:" 10 70 "$CUR_IP" 3>&1 1>&2 2>&3)
            if [[ -n "$NEW_IP" ]]; then
                python3 "$UPDATER" "$CONFIG_PATH" "client:ws-cachy:ip" "$NEW_IP"
            fi
            ;;
        "5")
            CUR_IP=$(python3 "$PARSER" "$CONFIG_PATH" "client:srv-deb-02:ip")
            NEW_IP=$(whiptail --title "IP-Adresse srv-deb-02" \
                             --inputbox "Geben Sie die neue IP in CIDR-Notation ein:" 10 70 "$CUR_IP" 3>&1 1>&2 2>&3)
            if [[ -n "$NEW_IP" ]]; then
                python3 "$UPDATER" "$CONFIG_PATH" "client:srv-deb-02:ip" "$NEW_IP"
            fi
            ;;
        "6")
            CUR_IP=$(python3 "$PARSER" "$CONFIG_PATH" "client:ws-manjaro:ip")
            NEW_IP=$(whiptail --title "IP-Adresse ws-manjaro" \
                             --inputbox "Geben Sie die neue IP in CIDR-Notation ein:" 10 70 "$CUR_IP" 3>&1 1>&2 2>&3)
            if [[ -n "$NEW_IP" ]]; then
                python3 "$UPDATER" "$CONFIG_PATH" "client:ws-manjaro:ip" "$NEW_IP"
            fi
            ;;
    esac
done
