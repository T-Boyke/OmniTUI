#!/usr/bin/env bash
# ==============================================================================
# OmniTUI Module: subnet_scanner.sh
# Autor: Tobias Boyke
# Zweck: Paralleler Hochgeschwindigkeits-Subnetz-Scanner (FHD Optimiert)
# ==============================================================================

set -euo pipefail

# Lade gemeinsame Variablen und Funktionen
source "$(dirname "$(readlink -f "$0")")/common.sh"
W_LIST=8

SUBNET_CHOICE=$(whiptail --title "Subnetz-Scanner & Discovery" \
                         --menu "WÃ¤hlen Sie das zu scannende LAN-Segment aus:" $W_HEIGHT $W_WIDTH $W_LIST \
                         "NETZ_A" "Netz A: 172.16.7.32/27 (IPs .33 bis .62)" \
                         "NETZ_B" "Netz B: 172.16.7.96/27 (IPs .97 bis .126)" 3>&1 1>&2 2>&3)

if [[ -z "$SUBNET_CHOICE" ]]; then
    exit 0
fi

START_IP=0
END_IP=0
BASE_NET=""

case "$SUBNET_CHOICE" in
    "NETZ_A")
        BASE_NET="172.16.7"
        START_IP=33
        END_IP=62
        ;;
    "NETZ_B")
        BASE_NET="172.16.7"
        START_IP=97
        END_IP=126
        ;;
esac

TEMP_SCAN_LOG="/tmp/mnbtui_scan.txt"
rm -f "$TEMP_SCAN_LOG"

whiptail --title "Scan lÃ¤uft" --infobox "Scanne $BASE_NET.$START_IP bis $BASE_NET.$END_IP parallel im Hintergrund...\nBitte warten (Dauer: ca. 2 Sek.)..." 8 75

# Paralleler Ping-Sweep
for i in $(seq "$START_IP" "$END_IP"); do
    target_ip="${BASE_NET}.${i}"
    (
        # 1 Ping, Timeout 1 Sekunde
        if ping -c 1 -W 1 "$target_ip" >/dev/null 2>&1; then
            # Hostname rÃ¼ckauflÃ¶sen falls DNS funktioniert
            host_name=$(getent hosts "$target_ip" | awk '{print $2}' || echo "")
            if [[ -n "$host_name" ]]; then
                echo "  âžœ $target_ip: [ONLINE] ($host_name)" >> "$TEMP_SCAN_LOG"
            else
                echo "  âžœ $target_ip: [ONLINE]" >> "$TEMP_SCAN_LOG"
            fi
        else
            echo "  âžœ $target_ip: [offline]" >> "$TEMP_SCAN_LOG"
        fi
    ) &
done

# Warten auf alle Pings
wait

# Bericht zusammenbauen
REPORT_FILE="/tmp/subnet_report.txt"
{
    echo "============================================================================="
    echo "               OMNITUI SUB-NETZWERK-SCANNER BERICHT"
    echo "============================================================================="
    echo "Scan-Bereich: $BASE_NET.$START_IP - $BASE_NET.$END_IP (Netzmaske: /27)"
    echo "Zeitpunkt: $(date)"
    echo ""
    echo "--- Aktive Hosts im Netzwerk ---"
    grep "ONLINE" "$TEMP_SCAN_LOG" | sort -V || echo "Keine aktiven Hosts gefunden."
    echo ""
    echo "--- Inaktive / Freie IP-Adressen ---"
    grep "offline" "$TEMP_SCAN_LOG" | sort -V || echo "Keine inaktiven IPs."
    echo "============================================================================="
} > "$REPORT_FILE"

whiptail --title "Scan-Ergebnisse - Subnetz-Discovery" --scrolltext --textbox "$REPORT_FILE" 24 85
