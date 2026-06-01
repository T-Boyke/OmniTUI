#!/usr/bin/env bash
# ==============================================================================
# OmniTUI Module: dns_selector.sh
# Autor: Tobias Boyke
# Zweck: Latenz-Benchmark für DNS und sofortige systemweite Aktivierung
# ==============================================================================

set -euo pipefail

# Definition der Top 10 DNS Provider mit Primary und Secondary IPs
PROVIDERS=(
    "Cloudflare;1.1.1.1;1.0.0.1;Schnell & Privat"
    "Google;8.8.8.8;8.8.4.4;Sehr verlässlich"
    "Quad9;9.9.9.9;149.112.112.112;Sicher, blockiert Malware"
    "AdGuard;94.140.14.14;94.140.15.15;Filtert Werbung & Tracker"
    "OpenDNS;208.67.222.222;208.67.220.220;Anpassbar, Jugendschutz"
    "CleanBrowsing;185.228.168.9;185.228.169.9;Familienfreundlicher Schutz"
    "ControlD;76.76.2.0;76.76.10.0;Ungefiltert & Performant"
    "Comodo;8.26.56.26;8.20.247.20;Secure DNS-Shield"
    "Verisign;64.6.64.6;64.6.65.6;Stabilität & Datenschutz"
    "Uncensored;91.239.100.100;89.233.43.71;Zensurfreies DNS (Dänemark)"
)

# Lade gemeinsame Variablen und Funktionen
source "$(dirname "$(readlink -f "$0")")/common.sh"
W_LIST=10

TEMP_PING_LOG="/tmp/dns_benchmark.txt"
rm -f "$TEMP_PING_LOG"

# Latenzmessung in einem schönen Info-Fenster ankündigen
whiptail --title "DNS Dual-Latenz-Benchmark" --infobox "Latenzen von Primary & Secondary DNS der 10 bekanntesten Anbieter werden gemessen...\nBitte warten (20 Server werden parallel gepingt)..." 8 85

# Ping-Messung für Primary & Secondary aller Provider parallel im Hintergrund
for entry in "${PROVIDERS[@]}"; do
    IFS=';' read -r name primary secondary desc <<< "$entry"
    
    # Primary ping
    (
        if ping_out=$(ping -c 3 -W 2 "$primary" 2>/dev/null); then
            avg_rtt=$(echo "$ping_out" | tail -n 1 | awk -F '/' '{print $5}' | awk -F '.' '{print $1}')
            if [[ -z "$avg_rtt" ]]; then
                avg_rtt=$(echo "$ping_out" | grep 'rtt' | cut -d'/' -f5 | cut -d'.' -f1)
            fi
            echo "$primary:$avg_rtt ms" >> "$TEMP_PING_LOG"
        else
            echo "$primary:Offline" >> "$TEMP_PING_LOG"
        fi
    ) &
    
    # Secondary ping
    (
        if ping_out=$(ping -c 3 -W 2 "$secondary" 2>/dev/null); then
            avg_rtt=$(echo "$ping_out" | tail -n 1 | awk -F '/' '{print $5}' | awk -F '.' '{print $1}')
            if [[ -z "$avg_rtt" ]]; then
                avg_rtt=$(echo "$ping_out" | grep 'rtt' | cut -d'/' -f5 | cut -d'.' -f1)
            fi
            echo "$secondary:$avg_rtt ms" >> "$TEMP_PING_LOG"
        else
            echo "$secondary:Offline" >> "$TEMP_PING_LOG"
        fi
    ) &
done

# Warten auf alle Hintergrund-Messungen
wait

# Ergebnisse einlesen
declare -A MEASURED
if [[ -f "$TEMP_PING_LOG" ]]; then
    while IFS=: read -r ip val; do
        MEASURED["$ip"]="$val"
    done < "$TEMP_PING_LOG"
fi

# TUI-Menü-Optionen zusammenbauen (nur Primary wählbar, aber beide Latenzen sichtbar!)
MENU_OPTIONS=()
for entry in "${PROVIDERS[@]}"; do
    IFS=';' read -r name primary secondary desc <<< "$entry"
    
    p_latency="${MEASURED[$primary]:-Offline}"
    s_latency="${MEASURED[$secondary]:-Offline}"
    
    label="[Pri: $p_latency | Sec: $s_latency] $name ($desc)"
    MENU_OPTIONS+=("$primary" "$label")
done

# Whiptail Auswahlliste anzeigen
CHOICE=$(whiptail --title "DNS-Provider Auswählen (Benchmark-Ergebnisse)" \
                  --menu "Wählen Sie einen DNS-Anbieter. Es werden automatisch Primary & Secondary eingerichtet:" $W_HEIGHT $W_WIDTH $W_LIST \
                  "${MENU_OPTIONS[@]}" 3>&1 1>&2 2>&3)

if [[ -n "$CHOICE" ]]; then
    SELECTED_SECONDARY=""
    SELECTED_NAME=""
    for entry in "${PROVIDERS[@]}"; do
        IFS=';' read -r name primary secondary desc <<< "$entry"
        if [[ "$primary" == "$CHOICE" ]]; then
            SELECTED_SECONDARY="$secondary"
            SELECTED_NAME="$name"
            break
        fi
    done
    
    # 1. Temporär speichern für andere OmniTUI-Skripte
    echo "$CHOICE $SELECTED_SECONDARY" > /tmp/selected_dns.txt
    
    # 2. In config.yaml eintragen
    if [[ -f "$CONFIG_PATH" ]]; then
        python3 "$UPDATER" "$CONFIG_PATH" "global:dns_fallback" "$CHOICE $SELECTED_SECONDARY"
    fi
    
    # 3. DIREKTE SOFORTIGE SYSTEMWEITE AKTIVIERUNG (Override)
    # A. Über NetworkManager (falls aktiv)
    if command -v nmcli >/dev/null 2>&1 && nmcli -t -f NAME,DEVICE connection show --active >/dev/null 2>&1; then
        # Finde den aktiven Verbindungsnamen
        ACTIVE_CONN=$(nmcli -t -f NAME,DEVICE connection show --active | head -n 1 | cut -d':' -f1)
        if [[ -n "$ACTIVE_CONN" ]]; then
            sudo nmcli connection modify "$ACTIVE_CONN" ipv4.dns "$CHOICE $SELECTED_SECONDARY" ipv4.ignore-auto-dns yes || true
            sudo nmcli connection up "$ACTIVE_CONN" >/dev/null 2>&1 || true
        fi
    fi
    
    # B. Direkte Härtung in /etc/resolv.conf
    # Backup der alten resolv.conf
    sudo cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null || true
    # Schreibe die neuen Nameserver direkt rein
    {
        echo "# Generated by OmniTUI DNS Selector (FHD)"
        echo "nameserver $CHOICE"
        echo "nameserver $SELECTED_SECONDARY"
        echo "search linux.essentials"
    } | sudo tee /etc/resolv.conf >/dev/null
    
    whiptail --title "DNS Systemweit Aktiviert" --msgbox "Der DNS-Provider $SELECTED_NAME wurde SOFORT systemweit aktiv geschaltet!\n\n- Primary DNS: $CHOICE\n- Secondary DNS: $SELECTED_SECONDARY\n\nFolgende Aktionen wurden ausgeführt:\n1. Aktive NetworkManager-Verbindung mit neuen IPs überschrieben.\n2. /etc/resolv.conf direkt mit Nameservern aktualisiert." 16 70
fi
