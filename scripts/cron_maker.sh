#!/usr/bin/env bash
# ==============================================================================
# OmniTUI Module: cron_maker.sh
# Autor: Tobias Boyke
# Zweck: Interaktiver Cronjob Generator via Whiptail TUI (FHD Optimiert)
# ==============================================================================

set -euo pipefail

# Lade gemeinsame Variablen und Funktionen
source "$(dirname "$(readlink -f "$0")")/common.sh"
W_LIST=8

# 1. Intervall-Auswahl
INTERVAL=$(whiptail --title "Cronjob Generator - Intervall" \
                    --menu "Wählen Sie die Ausführungshäufigkeit für den neuen Cronjob:" $W_HEIGHT $W_WIDTH $W_LIST \
                    "HOURLY" "Stündlich ausführen" \
                    "DAILY" "Täglich ausführen (um 02:00 Uhr nachts)" \
                    "WEEKLY" "Wöchentlich ausführen (Sonntags um 03:00 Uhr)" \
                    "MONTHLY" "Monatlich ausführen (am 1. des Monats)" \
                    "CUSTOM" "Eigene Cron-Syntax eingeben" 3>&1 1>&2 2>&3)

if [[ -z "$INTERVAL" ]]; then
    exit 0
fi

CRON_TIME=""
case "$INTERVAL" in
    "HOURLY") CRON_TIME="0 * * * *" ;;
    "DAILY") CRON_TIME="0 2 * * *" ;;
    "WEEKLY") CRON_TIME="0 3 * * 0" ;;
    "MONTHLY") CRON_TIME="0 4 1 * *" ;;
    "CUSTOM")
        CRON_TIME=$(whiptail --title "Custom Cron-Syntax" \
                             --inputbox "Geben Sie die 5-stellige Cron-Zeitsyntax ein (z. B. '*/15 * * * *' für alle 15 Minuten):" 10 70 "*/15 * * * *" 3>&1 1>&2 2>&3)
        if [[ -z "$CRON_TIME" ]]; then exit 0; fi
        ;;
esac

# 2. Aufgaben-Auswahl
TASK=$(whiptail --title "Cronjob Generator - Aufgabe" \
                --menu "Wählen Sie die auszuführende System-Aufgabe:" $W_HEIGHT $W_WIDTH $W_LIST \
                "UPDATE" "Automatisches Paket-Update (apt/dnf)" \
                "CLEAN" "/tmp Verzeichnis von alten Dateien befreien" \
                "BACKUP" "Sicherung von /etc in ein tar-Archiv schreiben" \
                "CUSTOM" "Eigene Konsolen-Befehlszeile eingeben" 3>&1 1>&2 2>&3)

if [[ -z "$TASK" ]]; then
    exit 0
fi

CRON_CMD=""
case "$TASK" in
    "UPDATE")
        if command -v apt-get >/dev/null 2>&1; then
            CRON_CMD="apt-get update && apt-get upgrade -y > /var/log/cron_updates.log 2>&1"
        elif command -v dnf >/dev/null 2>&1; then
            CRON_CMD="dnf upgrade -y > /var/log/cron_updates.log 2>&1"
        else
            CRON_CMD="pacman -Syu --noconfirm > /var/log/cron_updates.log 2>&1"
        fi
        ;;
    "CLEAN")
        CRON_CMD="find /tmp -type f -atime +7 -delete"
        ;;
    "BACKUP")
        CRON_CMD="tar -czf /var/backups/etc_backup_\$(date +\%Y\%m\%d).tar.gz /etc"
        ;;
    "CUSTOM")
        CRON_CMD=$(whiptail --title "Custom Befehlszeile" \
                            --inputbox "Geben Sie die komplette Konsolen-Befehlszeile ein:" 10 75 "logger 'Hallo Welt aus dem Cronjob'" 3>&1 1>&2 2>&3)
        if [[ -z "$CRON_CMD" ]]; then exit 0; fi
        ;;
esac

# 3. Cronjob eintragen
FULL_CRON_LINE="$CRON_TIME $CRON_CMD"

# Bestätigungs-Dialog
if whiptail --title "Cronjob bestätigen" \
            --yesno "Möchten Sie folgenden Cronjob aktiv einrichten?\n\n$FULL_CRON_LINE" 12 75; then
    
    (sudo crontab -l 2>/dev/null || true; echo "$FULL_CRON_LINE") | sudo crontab -
    whiptail --title "Erfolg" --msgbox "Der Cronjob wurde erfolgreich in die System-Crontab eingetragen!" 8 60
fi
