#!/usr/bin/env bash
# ==============================================================================
# OmniTUI Module: system_tweaks.sh
# Autor: Tobias Boyke
# Zweck: System Tuning, Kernel Optimierung, DNS-Cache & Default Editor (TUI)
# ==============================================================================

set -euo pipefail

# Lade gemeinsame Variablen und Funktionen
source "$(dirname "$(readlink -f "$0")")/common.sh"
W_LIST=8

TARGET_USER=${SUDO_USER:-root}
USER_HOME=$(eval echo "~$TARGET_USER")

# 1. MenÃ¼ zur Auswahl der System-Tweaks
TWEAKS=$(whiptail --title "System Tuning & Optimierungen" \
                  --checklist "WÃ¤hlen Sie die gewÃ¼nschten Kernel- und Netzwerk-Tweaks:" $W_HEIGHT $W_WIDTH $W_LIST \
                  "BBR" "Google BBR Congestion Control (TCP Staukontrolle)" ON \
                  "TCP" "TCP/IP Buffer Tuning (Performance fÃ¼r hohe Bandbreiten)" ON \
                  "FASTOPEN" "TCP Fast Open (Reduziert Verbindungs-Overhead)" ON \
                  "DNSCACHE" "Lokalen DNS-Caching Resolver (systemd-resolved/dnsmasq)" ON \
                  "LIMITS" "Systemlimits erhÃ¶hen (maximale offene Dateien in limits.conf)" ON 3>&1 1>&2 2>&3)

# 2. MenÃ¼ zur Auswahl des Standard-Editors
SELECTED_EDITOR=$(whiptail --title "Standard-Editor (EDITOR)" \
                            --menu "WÃ¤hlen Sie den standardmÃ¤ÃŸigen CLI-Editor fÃ¼r ZSH und Bash:" $W_HEIGHT $W_WIDTH $W_LIST \
                            "micro" "Modern, intuitiv, MausunterstÃ¼tzung & Shortcuts (Empfohlen)" \
                            "nano" "Einfach, minimalistisch, Standard-Editor" \
                            "vim" "Erweiterter vi-Editor mit Syntax-Highlighting" \
                            "vi" "Klassischer, ressourcenschonender vi-Standard" 3>&1 1>&2 2>&3)

# Verarbeiten der System-Tweaks
if [[ -n "$TWEAKS" ]]; then
    # Erstelle temporÃ¤re sysctl Datei
    SYSCTL_CONF="/etc/sysctl.d/99-network-tweaks.conf"
    sudo mkdir -p /etc/sysctl.d
    sudo rm -f "$SYSCTL_CONF"

    whiptail --title "Tuning lÃ¤uft" --infobox "Die ausgewÃ¤hlten Optimierungen werden angewendet..." 8 50

    # BBR
    if [[ "$TWEAKS" =~ "BBR" ]]; then
        {
            echo "# Google BBR Congestion Control"
            echo "net.core.default_qdisc = fq"
            echo "net.ipv4.tcp_congestion_control = bbr"
        } | sudo tee -a "$SYSCTL_CONF" >/dev/null
    fi

    # TCP Buffers
    if [[ "$TWEAKS" =~ "TCP" ]]; then
        {
            echo ""
            echo "# High-Performance TCP/IP Tuning"
            echo "net.ipv4.tcp_rmem = 4096 87380 16777216"
            echo "net.ipv4.tcp_wmem = 4096 65536 16777216"
            echo "net.core.rmem_max = 16777216"
            echo "net.core.wmem_max = 16777216"
            echo "net.ipv4.tcp_mtu_probing = 1"
        } | sudo tee -a "$SYSCTL_CONF" >/dev/null
    fi

    # Fast Open
    if [[ "$TWEAKS" =~ "FASTOPEN" ]]; then
        {
            echo ""
            echo "# TCP Fast Open"
            echo "net.ipv4.tcp_fastopen = 3"
        } | sudo tee -a "$SYSCTL_CONF" >/dev/null
    fi

    # Sysctl anwenden
    sudo sysctl --system >/dev/null

    # DNS Cache
    if [[ "$TWEAKS" =~ "DNSCACHE" ]]; then
        if systemctl list-unit-files | grep -q "systemd-resolved.service"; then
            sudo systemctl enable systemd-resolved --now >/dev/null 2>&1 || true
            sudo mkdir -p /etc/systemd/resolved.conf.d
            echo -e "[Resolve]\nCache=yes\nDNSStubListener=yes" | sudo tee /etc/systemd/resolved.conf.d/cache.conf >/dev/null
            sudo systemctl restart systemd-resolved >/dev/null 2>&1 || true
        elif command -v apt-get >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
            if command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y dnsmasq >/dev/null 2>&1 || true
            elif command -v apt-get >/dev/null 2>&1; then
                sudo apt-get install -y dnsmasq >/dev/null 2>&1 || true
            fi
            
            if command -v dnsmasq >/dev/null 2>&1; then
                echo -e "listen-address=127.0.0.1\ncache-size=1000" | sudo tee /etc/dnsmasq.d/cache.conf >/dev/null 2>&1 || echo -e "listen-address=127.0.0.1\ncache-size=1000" | sudo tee -a /etc/dnsmasq.conf >/dev/null
                sudo systemctl enable dnsmasq --now >/dev/null 2>&1 || true
            fi
        fi
    fi

    # Limits.conf
    if [[ "$TWEAKS" =~ "LIMITS" ]]; then
        LIMITS_CONF="/etc/security/limits.d/99-performance.conf"
        sudo mkdir -p /etc/security/limits.d
        {
            echo "# Performance Limits"
            echo "* soft nofile 65535"
            echo "* hard nofile 65535"
            echo "* soft nproc 65535"
            echo "* hard nproc 65535"
        } | sudo tee "$LIMITS_CONF" >/dev/null
    fi
fi

# Verarbeiten des Standard-Editors
if [[ -n "$SELECTED_EDITOR" ]]; then
    whiptail --title "Editor wird konfiguriert" --infobox "Setze $SELECTED_EDITOR als System-Standard..." 8 50
    
    # Entferne alte EintrÃ¤ge falls vorhanden in .bashrc und .zshrc
    for rc_file in "$USER_HOME/.bashrc" "$USER_HOME/.zshrc"; do
        if [[ -f "$rc_file" ]]; then
            sudo -u "$TARGET_USER" sed -i '/export EDITOR=/d' "$rc_file" || true
            sudo -u "$TARGET_USER" sed -i '/export VISUAL=/d' "$rc_file" || true
            
            # Neue Zuweisung eintragen
            {
                echo "export EDITOR=\"$SELECTED_EDITOR\""
                echo "export VISUAL=\"$SELECTED_EDITOR\""
            } | sudo -u "$TARGET_USER" tee -a "$rc_file" >/dev/null
        fi
    done
fi

# Abschluss-Meldung
whiptail --title "Optimierung abgeschlossen" --msgbox "Die Anpassungen wurden erfolgreich durchgefÃ¼hrt!\n\n- System-Tweaks wurden geladen.\n- Standard-Editor fÃ¼r Bash/Zsh wurde auf '$SELECTED_EDITOR' gesetzt." $W_HEIGHT $W_WIDTH
