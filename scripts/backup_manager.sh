#!/usr/bin/env bash
# ==============================================================================
# OmniTUI Module: backup_manager.sh
# Autor: Tobias Boyke
# Zweck: Systemkonfigurations-Backup & Wiederherstellung (FHD Optimiert)
# ==============================================================================

set -euo pipefail

# Lade gemeinsame Variablen und Funktionen
source "$(dirname "$(readlink -f "$0")")/common.sh"
W_LIST=8

BACKUP_DIR="/var/backups/omnitui"
sudo mkdir -p "$BACKUP_DIR"

ACTION=$(whiptail --title "Backup & Wiederherstellungs Manager" \
                  --menu "Wählen Sie eine Backup-Aktion aus:" $W_HEIGHT $W_WIDTH $W_LIST \
                  "CREATE" "Neues System-Backup erstellen" \
                  "RESTORE" "Bestehendes System-Backup wiederherstellen" \
                  "LIST" "Vorhandene Backups auflisten" 3>&1 1>&2 2>&3)

if [[ -z "$ACTION" ]]; then
    exit 0
fi

case "$ACTION" in
    "CREATE")
        whiptail --title "Backup wird erstellt" --infobox "Komprimiere System-Konfigurationen..." 8 60
        
        DATE=$(date +%Y%m%d_%H%M%S)
        FILE_PATH="${BACKUP_DIR}/omnitui_backup_${DATE}.tar.gz"
        
        # Liste der zu sichernden Pfade
        PATHS_TO_BACKUP=(
            "/etc/nftables.conf"
            "/etc/sysctl.d/99-network-tweaks.conf"
            "/etc/ssh/sshd_config"
            "/etc/resolv.conf"
            "$(dirname "$0")/../config.yaml"
        )
        
        # Nur existierende Pfade sichern
        VALID_PATHS=()
        for p in "${PATHS_TO_BACKUP[@]}"; do
            if [[ -f "$p" ]]; then
                VALID_PATHS+=("$p")
            fi
        done
        
        if [[ ${#VALID_PATHS[@]} -eq 0 ]]; then
            whiptail --title "Backup-Fehler" --msgbox "Es wurden keine zu sichernden Dateien auf diesem System gefunden!" 10 55
            exit 1
        fi
        
        # Tarball erstellen
        if sudo tar -czf "$FILE_PATH" "${VALID_PATHS[@]}" 2>/dev/null; then
            whiptail --title "Backup-Erfolg" --msgbox "System-Backup erfolgreich angelegt!\n\nDatei: $FILE_PATH\nSicherungsgröße: $(sudo du -sh "$FILE_PATH" | awk '{print $1}')" 12 65
        else
            whiptail --title "Backup-Fehler" --msgbox "Fehler beim Erstellen des tar.gz-Archivs!" 10 55
        fi
        ;;
        
    "RESTORE")
        # Alle tar.gz Dateien im Backup-Verzeichnis auflisten
        BACKUPS=($(sudo find "$BACKUP_DIR" -name "omnitui_backup_*.tar.gz" -printf "%f\n" 2>/dev/null | sort -r))
        
        if [[ ${#BACKUPS[@]} -eq 0 ]]; then
            whiptail --title "Keine Backups" --msgbox "Es wurden keine Backup-Dateien in $BACKUP_DIR gefunden!" 10 55
            exit 0
        fi
        
        MENU_OPTIONS=()
        for b in "${BACKUPS[@]}"; do
            size=$(sudo du -sh "${BACKUP_DIR}/$b" | awk '{print $1}')
            MENU_OPTIONS+=("$b" "Sicherungsarchiv (Größe: $size)")
        done
        
        SELECTED_BACKUP=$(whiptail --title "Backup wiederherstellen" \
                                   --menu "Wählen Sie das wiederherzustellende Backup aus:" $W_HEIGHT $W_WIDTH $W_LIST \
                                   "${MENU_OPTIONS[@]}" 3>&1 1>&2 2>&3)
                                   
        if [[ -n "$SELECTED_BACKUP" ]]; then
            if whiptail --title "Wiederherstellung bestätigen" \
                        --yesno "Möchten Sie das Backup '$SELECTED_BACKUP' wirklich wiederherstellen?\nAlle aktuellen Konfigurationen werden überschrieben!" 12 70; then
                
                whiptail --title "Wiederherstellung läuft" --infobox "Entpacke Konfigurationen..." 8 60
                
                if sudo tar -xzf "${BACKUP_DIR}/${SELECTED_BACKUP}" -C / 2>/dev/null; then
                    # SSH und nftables neu starten falls Konfig zurückgespielt
                    sudo systemctl restart sshd || sudo systemctl restart ssh || true
                    sudo systemctl restart nftables || true
                    
                    whiptail --title "Erfolg" --msgbox "Die Konfigurationsdateien wurden erfolgreich wiederhergestellt und die betroffenen Dienste neu geladen!" 10 65
                else
                    whiptail --title "Fehler" --msgbox "Fehler beim Entpacken der Backup-Datei!" 10 55
                fi
            fi
        fi
        ;;
        
    "LIST")
        BACKUPS_LIST=$(sudo find "$BACKUP_DIR" -name "omnitui_backup_*.tar.gz" -exec ls -lh {} \; 2>/dev/null || echo "Keine Backups vorhanden.")
        TEMP_LIST_FILE="/tmp/omnitui_backups_list.txt"
        echo "$BACKUPS_LIST" > "$TEMP_LIST_FILE"
        whiptail --title "Vorhandene System-Backups" --scrolltext --textbox "$TEMP_LIST_FILE" $W_HEIGHT $W_WIDTH
        ;;
esac
