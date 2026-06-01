#!/usr/bin/env bash
# ==============================================================================
# OmniTUI Module: diagnostics.sh
# Autor: Tobias Boyke
# Zweck: Netzwerk-Diagnose & Automatisierter Self-Healing Doctor (FHD)
# ==============================================================================

set -euo pipefail

# Lade gemeinsame Variablen und Funktionen
source "$(dirname "$(readlink -f "$0")")/common.sh"

CURRENT_HOST=$(hostname -s)
DIAG_LOG="/tmp/omnitui_diagnostics.txt"
rm -f "$DIAG_LOG"

whiptail --title "Netzwerk-Diagnose & Doctor" --infobox "FÃ¼hre automatisierte Latenz- & Routingtests im Subnetz durch..." 8 75

# Heiler-Status-Variablen
HEAL_DNS=false
HEAL_GW=false
ACTIVE_CONN=""
GATEWAY_IP=""

# Header schreiben
{
    echo "============================================================================="
    echo "            OMNITUI NETZWERK-DIAGNOSEBERICHT  --  $(date)"
    echo "============================================================================="
    echo "Lokaler Hostname: $CURRENT_HOST"
    echo ""
} >> "$DIAG_LOG"

# 1. Lokale Interfaces & IPs
{
    echo "--- [1] Lokale Netzwerkschnittstellen ---"
    ip -br -4 a || echo "Fehler beim Lesen der IP-Adressen"
    echo ""
} >> "$DIAG_LOG"

# 2. Lokale Routing-Tabelle
{
    echo "--- [2] Routing-Tabelle ---"
    ip route show || echo "Fehler beim Lesen der Routing-Tabelle"
    echo ""
} >> "$DIAG_LOG"

# 3. DNS-AuflÃ¶sungs-Check & Self-Healing Triggers
{
    echo "--- [3] DNS-AuflÃ¶sung & Internet-Check ---"
    if curl -sI --connect-timeout 3 https://www.google.com >/dev/null; then
        echo "[OK] Internetverbindung steht (HTTPS-Test erfolgreich)."
    else
        echo "[WARNUNG] Keine direkte HTTPS-Verbindung ins Internet."
    fi
    
    # DNS-PrÃ¼fung
    if host_out=$(host google.com 2>/dev/null); then
        echo "[OK] DNS-AuflÃ¶sung aktiv (google.com gelÃ¶st)."
    elif ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
        echo "[FEHLER] Ping an 1.1.1.1 erfolgreich, aber DNS-AuflÃ¶sung fehlgeschlagen!"
        echo "        -> Der 'Doctor' empfiehlt: DNS-Nameserver neu einrichten."
        HEAL_DNS=true
    else
        echo "[FEHLER] Keine InternetkonnektivitÃ¤t (Weder Ping noch DNS)."
    fi
    echo ""
} >> "$DIAG_LOG"

# 4. Topologie-Verbindungstests
{
    echo "--- [4] Topologie-KonnektivitÃ¤tstests ---"
    
    ROUTER_HOST=$(python3 "$PARSER" "$CONFIG_PATH" "router:hostname")
    
    if [[ "$CURRENT_HOST" == "$ROUTER_HOST" ]]; then
        echo "Rolle: Router. Pinge konfigurierte Clients an..."
        CLIENTS=$(python3 "$PARSER" "$CONFIG_PATH" "clients_list")
        for client in $CLIENTS; do
            client_ip=$(python3 "$PARSER" "$CONFIG_PATH" "client:$client:ip" | cut -d'/' -f1)
            if [[ -n "$client_ip" ]]; then
                if ping -c 2 -W 2 "$client_ip" >/dev/null 2>&1; then
                    echo "  âžœ Client $client ($client_ip): [ONLINE]"
                else
                    echo "  âžœ Client $client ($client_ip): [OFFLINE / UNREACHABLE]"
                fi
            fi
        done
    else
        echo "Rolle: Client. Pinge Gateways an..."
        CLIENT_GW=$(python3 "$PARSER" "$CONFIG_PATH" "client:$CURRENT_HOST:gateway")
        GATEWAY_IP="$CLIENT_GW"
        if [[ -n "$CLIENT_GW" ]]; then
            if ping -c 2 -W 2 "$CLIENT_GW" >/dev/null 2>&1; then
                echo "  âžœ Standard-Gateway $CLIENT_GW: [ONLINE] (Verbindung zum Router steht)."
            else
                echo "  âžœ Standard-Gateway $CLIENT_GW: [OFFLINE] (Keine Verbindung zum Router!)."
                HEAL_GW=true
            fi
        else
            echo "  [FEHLER] Kein Standard-Gateway in config.yaml fÃ¼r diesen Client deklariert."
        fi
    fi
    echo "============================================================================="
} >> "$DIAG_LOG"

# 5. Ermittle aktive Verbindung
if command -v nmcli >/dev/null 2>&1 && nmcli -t -f NAME,DEVICE connection show --active >/dev/null 2>&1; then
    ACTIVE_CONN=$(nmcli -t -f NAME,DEVICE connection show --active | head -n 1 | cut -d':' -f1 || true)
fi

# Ergebnis in scrollbarer TUI-Textbox ausgeben
whiptail --title "System- & Netzwerk-Diagnoseergebnisse" --scrolltext --textbox "$DIAG_LOG" $W_HEIGHT $W_WIDTH

# --- AUTOMATISIERTER SELF-HEALING DOCTOR ---

# A. Doctor Heilung fÃ¼r DNS-Fehler
if [[ "$HEAL_DNS" == "true" ]]; then
    if whiptail --title "ðŸ©¹ Doctor-Modus: DNS-Heilung" \
                --yesno "Der Doctor hat ein Nameserver-Problem festgestellt (Ping klappt, DNS-AuflÃ¶sung scheitert).\n\nMÃ¶chten Sie, dass ich jetzt das DNS-Benchmark-Tool starte, um einen funktionierenden Nameserver einzurichten?" 14 75; then
        bash "$(dirname "$0")/dns_selector.sh"
    fi
fi

# B. Doctor Heilung fÃ¼r Gateway-Fehler (Interface Reset)
if [[ "$HEAL_GW" == "true" && -n "$ACTIVE_CONN" ]]; then
    if whiptail --title "ðŸ©¹ Doctor-Modus: Gateway-Heilung" \
                --yesno "Die Verbindung zu Ihrem Gateway ($GATEWAY_IP) ist unterbrochen.\n\nMÃ¶chten Sie, dass ich die aktive Netzwerkschnittstelle '$ACTIVE_CONN' neu starte, um die Verbindung wiederherzustellen?" 14 75; then
        
        whiptail --title "Interface-Reset" --infobox "Starte Schnittstelle '$ACTIVE_CONN' neu..." 8 55
        nmcli connection down "$ACTIVE_CONN" >/dev/null 2>&1 || true
        sleep 1
        nmcli connection up "$ACTIVE_CONN" >/dev/null 2>&1 || true
        
        # Erneuter Schnellcheck
        if ping -c 2 -W 2 "$GATEWAY_IP" >/dev/null 2>&1; then
            whiptail --title "ðŸ©¹ Doctor-Heilung erfolgreich" --msgbox "Die Verbindung zum Gateway ($GATEWAY_IP) wurde durch den Schnittstellen-Reset erfolgreich wiederhergestellt!" 10 65
        else
            whiptail --title "ðŸ©¹ Doctor-Heilung fehlgeschlagen" --msgbox "Der Reset der Schnittstelle brachte leider keinen Erfolg. Bitte prÃ¼fen Sie Ihre physischen Verbindungen / LAN-Segmente in VMware." 12 70
        fi
    fi
fi
