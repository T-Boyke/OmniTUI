#!/usr/bin/env bash
# ==============================================================================
# OmniTUI Module: router_setup.sh
# Autor: Tobias Boyke
# Zweck: Einrichtung Netzwerk-Interfaces, IP-Forwarding & nftables auf dem Router
# ==============================================================================

set -euo pipefail

# Lade gemeinsame Variablen und Funktionen
source "$(dirname "$(readlink -f "$0")")/common.sh"

# Überprüfen ob Router
CURRENT_HOST=$(hostname -s)
ROUTER_HOST=$(python3 "$PARSER" "$CONFIG_PATH" "router:hostname")

if [[ "$CURRENT_HOST" != "$ROUTER_HOST" ]]; then
    whiptail --title "Fehler: Host-Rolle" --msgbox "Dieses Skript kann nur auf dem Router ($ROUTER_HOST) ausgeführt werden.\nDer aktuelle Hostname lautet: $CURRENT_HOST" 10 55
    exit 1
fi

whiptail --title "Router-Konfiguration" --infobox "Richte Schnittstellen und Forwarding für Router ein..." 8 50

# Werte parsen
DNS_SERVER=$(python3 "$PARSER" "$CONFIG_PATH" "global:dns_fallback")
WAN_MAC=$(python3 "$PARSER" "$CONFIG_PATH" "wan:mac")
LAN_A_MAC=$(python3 "$PARSER" "$CONFIG_PATH" "lan_a:mac")
LAN_A_IP=$(python3 "$PARSER" "$CONFIG_PATH" "lan_a:ip")
LAN_B_MAC=$(python3 "$PARSER" "$CONFIG_PATH" "lan_b:mac")
LAN_B_IP=$(python3 "$PARSER" "$CONFIG_PATH" "lan_b:ip")

# Falls MAC-Werte leer sind, nutzen wir Standard-Fallback
WAN_MAC=${WAN_MAC:-"00:0C:29:9E:B3:12"}
LAN_A_MAC=${LAN_A_MAC:-"00:0C:29:9E:B3:26"}
LAN_B_MAC=${LAN_B_MAC:-"00:0C:29:9E:B3:1C"}

# 1. NetworkManager bereinigen & neu konfigurieren
for conn in $(nmcli -t -f UUID con show); do
    nmcli con delete uuid "$conn" >/dev/null 2>&1 || true
done

# Profile erstellen
nmcli con add type ethernet con-name ens160 ifname ens160 mac "$WAN_MAC" ipv4.method auto ipv4.dns "$DNS_SERVER"
nmcli con add type ethernet con-name ens161 ifname ens161 mac "$LAN_A_MAC" ipv4.addresses "$LAN_A_IP" ipv4.method manual
nmcli con add type ethernet con-name ens256 ifname ens256 mac "$LAN_B_MAC" ipv4.addresses "$LAN_B_IP" ipv4.method manual

# Profile aktivieren
nmcli con up ens160
nmcli con up ens161
nmcli con up ens256

# 2. Kernel-Forwarding aktivieren
sysctl -w net.ipv4.ip_forward=1 >/dev/null
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/99-ip-forward.conf >/dev/null

# 3. nftables Firewall schreiben (spezifisch für Router)
sudo systemctl stop firewalld >/dev/null 2>&1 || true
sudo systemctl disable firewalld >/dev/null 2>&1 || true

cat << EOF | sudo tee /etc/nftables.conf >/dev/null
flush ruleset
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        iif "lo" accept
        ct state established,related accept
        tcp dport 22 accept
        ip protocol icmp accept
    }
    chain forward {
        type filter hook forward priority 0; policy drop;
        ct state established,related accept
        iifname "ens161" accept
        iifname "ens256" accept
    }
}
table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100; policy accept;
        oifname "ens160" masquerade
    }
}
EOF

sudo systemctl enable nftables --now >/dev/null 2>&1 || true

whiptail --title "Router-Erfolg" --msgbox "Der Router $ROUTER_HOST wurde erfolgreich eingerichtet!\n\n- Schnittstellen konfiguriert\n- Kernel IP-Forwarding aktiv\n- nftables NAT-Masquerading läuft" 12 55
