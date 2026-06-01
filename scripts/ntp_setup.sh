#!/usr/bin/env bash
# ==============================================================================
# OmniTUI Module: ntp_setup.sh
# Autor: Tobias Boyke
# Zweck: NTP Zeitsynchronisation & Server-Auswahl (FHD Optimiert)
# ==============================================================================

set -euo pipefail

# Lade gemeinsame Variablen und Funktionen
source "$(dirname "$(readlink -f "$0")")/common.sh"
W_LIST=8

# 1. Zeitserver-Auswahl
NTP_SERVER=$(whiptail --title "NTP Zeitserver-Auswahl" \
                       --menu "Wählen Sie den primären NTP-Zeitserver-Pool aus (LPIC-1 relevant):" $W_HEIGHT $W_WIDTH $W_LIST \
                       "de.pool.ntp.org" "Deutschland Pool (Sehr empfohlen)" \
                       "europe.pool.ntp.org" "Europa Pool (Empfohlen)" \
                       "pool.ntp.org" "Globaler NTP-Pool (Standard)" \
                       "time.cloudflare.com" "Cloudflare High-Security (NTS)" \
                       "time.google.com" "Google NTP-Zeitserver" 3>&1 1>&2 2>&3)

if [[ -z "$NTP_SERVER" ]]; then
    exit 0
fi

whiptail --title "NTP wird eingerichtet" --infobox "Konfiguriere Zeitsynchronisation und starte Dienste..." 8 60

# 2. Ermittle aktiven NTP-Dienst
NTP_CLIENT=""
if systemctl list-unit-files | grep -q "chronyd.service"; then
    NTP_CLIENT="CHRONY"
elif systemctl list-unit-files | grep -q "systemd-timesyncd.service"; then
    NTP_CLIENT="TIMESYNCD"
else
    # Installiere Chrony als Standard falls keins vorhanden
    if command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y chrony >/dev/null 2>&1 || true
        NTP_CLIENT="CHRONY"
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get install -y chrony >/dev/null 2>&1 || true
        NTP_CLIENT="CHRONY"
    fi
fi

# 3. Konfiguration schreiben
if [[ "$NTP_CLIENT" == "CHRONY" ]]; then
    # Chrony konfigurieren
    CHRONY_CONF="/etc/chrony.conf"
    if [[ ! -f "$CHRONY_CONF" ]]; then CHRONY_CONF="/etc/chrony/chrony.conf"; fi
    
    if [[ -f "$CHRONY_CONF" ]]; then
        sudo cp "$CHRONY_CONF" "${CHRONY_CONF}.bak"
        # Lösche alte Server-Einträge
        sudo sed -i '/^server/d' "$CHRONY_CONF" || true
        sudo sed -i '/^pool/d' "$CHRONY_CONF" || true
        # Füge neuen Server hinzu
        echo "server $NTP_SERVER iburst" | sudo tee -a "$CHRONY_CONF" >/dev/null
        
        sudo systemctl enable chronyd --now >/dev/null 2>&1 || true
        sudo systemctl restart chronyd >/dev/null 2>&1 || true
    fi
    
elif [[ "$NTP_CLIENT" == "TIMESYNCD" ]]; then
    # systemd-timesyncd konfigurieren
    TIMESYNC_CONF="/etc/systemd/timesyncd.conf"
    sudo cp "$TIMESYNC_CONF" "${TIMESYNC_CONF}.bak"
    
    # Setze NTP Server in timesyncd.conf
    sudo sed -i "s/^#\?NTP.*/NTP=$NTP_SERVER/" "$TIMESYNC_CONF"
    
    sudo systemctl enable systemd-timesyncd --now >/dev/null 2>&1 || true
    sudo systemctl restart systemd-timesyncd >/dev/null 2>&1 || true
fi

# 4. Zeitsynchronisation erzwingen & Status lesen
sudo timedatectl set-ntp true >/dev/null 2>&1 || true

# Warte kurz auf Synchronisation
sleep 2

STATUS_LOG="/tmp/ntp_status.txt"
{
    echo "============================================================================="
    echo "                NTP ZEIT-SYNCHRONISATIONSSTATUS"
    echo "============================================================================="
    echo "Genutzter NTP-Client: $NTP_CLIENT"
    echo "Konfigurierter Server: $NTP_SERVER"
    echo ""
    echo "--- System-Zeitstatus ---"
    timedatectl status || echo "timedatectl nicht verfügbar"
    echo ""
    
    if [[ "$NTP_CLIENT" == "CHRONY" ]] && command -v chronyc >/dev/null 2>&1; then
        echo "--- Chrony Quellen ---"
        sudo chronyc sources -v || true
        echo ""
        echo "--- Chrony Tracking ---"
        sudo chronyc tracking || true
    fi
    echo "============================================================================="
} > "$STATUS_LOG"

whiptail --title "Zeitsynchronisation Erfolgreich" --scrolltext --textbox "$STATUS_LOG" $W_HEIGHT $W_WIDTH
