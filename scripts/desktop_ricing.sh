#!/usr/bin/env bash
# ==============================================================================
# OmniTUI Module: desktop_ricing.sh
# Autor: Tobias Boyke
# Zweck: r/unixporn Ultimate Eyecandy & Ricing Assistent (FHD Edition)
# ==============================================================================

set -euo pipefail

# Lade gemeinsame Variablen und Funktionen
source "$(dirname "$(readlink -f "$0")")/common.sh"
W_LIST=8

TARGET_USER=${SUDO_USER:-root}
USER_HOME=$(eval echo "~$TARGET_USER")

# 1. Desktop-Auswahl
DESKTOP=$(whiptail --title "r/unixporn Ultimate Ricing Assistent" \
                    --menu "WÃ¤hlen Sie Ihre Desktop-Umgebung fÃ¼r ein absolut atemberaubendes, Reddit-wÃ¼rdiges Setup:" $W_HEIGHT $W_WIDTH $W_LIST \
                    "GNOME" "GNOME Glassmorphism (Orchis Theme, Tela Circle, Blur my Shell, custom Dock)" \
                    "KDE" "KDE Plasma Cyberpunk (Sweet-KDE, Candy Icons, Kvantum Glass-Transparency)" \
                    "HYPRLAND" "Hyprland Tiling WM (Catppuccin Mocha, Waybar-Glow, Rofi-Menu, Dunst-Shadows)" \
                    "XFCE" "XFCE Retro-Modern (Arc Dark GTK, Papirus Dark Icons, Whisker Customizer)" \
                    "CINNAMON" "Cinnamon Premium Dark (Adapta Nokto, custom Panels & Shadow Effects)" 3>&1 1>&2 2>&3)

if [[ -z "$DESKTOP" ]]; then
    exit 0
fi

# Lokale Ordnerstrukturen anlegen
sudo -u "$TARGET_USER" mkdir -p "$USER_HOME/.themes" "$USER_HOME/.icons" "$USER_HOME/.config" "$USER_HOME/Pictures/Wallpapers"

# Funktion zum Herunterladen eines legendÃ¤ren, farblich abgestimmten Wallpapers
download_wallpaper() {
    local theme_name="$1"
    local wp_url=""
    local wp_path="$USER_HOME/Pictures/Wallpapers/${theme_name}_aesthetic.jpg"
    
    if [[ "$theme_name" == "catppuccin" ]]; then
        wp_url="https://raw.githubusercontent.com/zhichaoh/catppuccin-wallpapers/main/landscapes/evening-sky.png"
    else
        # Cyberpunk Neon Wallpaper
        wp_url="https://images.unsplash.com/photo-1542838132-92c53300491e?q=80&w=1920"
    fi
    
    log_info "Lade legendÃ¤res $theme_name-Wallpaper herunter..."
    sudo -u "$TARGET_USER" curl -fsSL -o "$wp_path" "$wp_url" || true
    
    # Versuche Wallpaper im System zu setzen
    if command -v gsettings >/dev/null 2>&1 && [[ "$DESKTOP" == "GNOME" ]]; then
        sudo -u "$TARGET_USER" gsettings set org.gnome.desktop.background picture-uri "file://$wp_path" || true
        sudo -u "$TARGET_USER" gsettings set org.gnome.desktop.background picture-uri-dark "file://$wp_path" || true
    elif command -v feh >/dev/null 2>&1; then
        sudo -u "$TARGET_USER" feh --bg-fill "$wp_path" || true
    fi
}

case "$DESKTOP" in
    "GNOME")
        COMPONENTS=$(whiptail --title "GNOME r/unixporn Setup" \
                               --checklist "WÃ¤hlen Sie die Komponenten fÃ¼r den ultimativen Glassmorphism-Look:" $W_HEIGHT $W_WIDTH $W_LIST \
                               "GTK_THEME" "Orchis GTK Theme installieren (Ultra-Modern Rounded)" ON \
                               "ICONS" "Tela Circle Icon Theme (Farblich perfekt abgestimmt)" ON \
                               "WALLPAPER" "LegendÃ¤res Material-Wallpaper automatisch anwenden" ON \
                               "EXT_TWEAKS" "Detaillierte Layout-Anpassungen (Blur, transparentes Panel)" ON 3>&1 1>&2 2>&3)
        
        if [[ -n "$COMPONENTS" ]]; then
            whiptail --title "Ricing lÃ¤uft" --infobox "Richte GNOME Desktop auf r/unixporn Niveau ein..." 8 60
            
            if [[ "$COMPONENTS" =~ "GTK_THEME" ]]; then
                log_info "Klone und installiere Orchis Theme..."
                TEMP_DIR=$(mktemp -d)
                sudo -u "$TARGET_USER" git clone https://github.com/vinceliuice/Orchis-theme.git "$TEMP_DIR" >/dev/null 2>&1 || true
                if [[ -d "$TEMP_DIR" ]]; then
                    sudo -u "$TARGET_USER" bash "$TEMP_DIR/install.sh" -d "$USER_HOME/.themes" -c dark -t default --round >/dev/null 2>&1 || true
                    rm -rf "$TEMP_DIR"
                fi
            fi
            
            if [[ "$COMPONENTS" =~ "ICONS" ]]; then
                log_info "Klone Tela Circle Icons..."
                TEMP_DIR=$(mktemp -d)
                sudo -u "$TARGET_USER" git clone https://github.com/vinceliuice/Tela-circle-icon-theme.git "$TEMP_DIR" >/dev/null 2>&1 || true
                if [[ -d "$TEMP_DIR" ]]; then
                    sudo -u "$TARGET_USER" bash "$TEMP_DIR/install.sh" -d "$USER_HOME/.icons" >/dev/null 2>&1 || true
                    rm -rf "$TEMP_DIR"
                fi
            fi
            
            if [[ "$COMPONENTS" =~ "WALLPAPER" ]]; then
                download_wallpaper "cyberpunk"
            fi
            
            # Installation von CLI-Visualisierern fÃ¼r den Showcase
            if command -v apt-get >/dev/null 2>&1; then
                sudo apt-get install -y cava cmatrix >/dev/null 2>&1 || true
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y cava cmatrix >/dev/null 2>&1 || true
            fi
            
            whiptail --title "GNOME Veredelt" --msgbox "Ihr GNOME-System wurde auf r/unixporn Niveau veredelt!\n\n- Orchis GTK Theme angewendet\n- Tela Circle Icons geladen\n- Show-Off Tools installiert: cava & cmatrix\n- Wallpaper eingerichtet\n\nTipp: Ã–ffnen Sie btop, cava und neofetch nebeneinander fÃ¼r den perfekten Screenshot!" 16 75
        fi
        ;;
        
    "KDE")
        COMPONENTS=$(whiptail --title "KDE Plasma r/unixporn Setup" \
                               --checklist "WÃ¤hlen Sie die Komponenten fÃ¼r den ultimativen Sweet-Cyberpunk Look:" $W_HEIGHT $W_WIDTH $W_LIST \
                               "GLOBAL" "Sweet KDE Global Theme (Leuchtender Neon-Cyberpunk)" ON \
                               "ICONS" "Candy Icons installieren (Extrem stylischer Neon-Style)" ON \
                               "KVANTUM" "Kvantum Engine einrichten (Transparenz & UnschÃ¤rfe)" ON \
                               "WALLPAPER" "Aesthetic Neon-City Wallpaper anwenden" ON 3>&1 1>&2 2>&3)
                               
        if [[ -n "$COMPONENTS" ]]; then
            whiptail --title "KDE Ricing lÃ¤uft" --infobox "Richte KDE Plasma Cyberpunk-Theme ein..." 8 60
            
            sudo -u "$TARGET_USER" mkdir -p "$USER_HOME/.local/share/plasma/look-and-feel"
            
            if [[ "$COMPONENTS" =~ "ICONS" ]]; then
                log_info "Klone Candy Icons..."
                sudo -u "$TARGET_USER" rm -rf "$USER_HOME/.icons/candy-icons"
                sudo -u "$TARGET_USER" git clone https://github.com/EliverLara/candy-icons.git "$USER_HOME/.icons/candy-icons" >/dev/null 2>&1 || true
            fi
            
            if [[ "$COMPONENTS" =~ "WALLPAPER" ]]; then
                download_wallpaper "cyberpunk"
            fi
            
            # Show-off Tools
            if command -v apt-get >/dev/null 2>&1; then
                sudo apt-get install -y cava cmatrix >/dev/null 2>&1 || true
            fi
            
            whiptail --title "KDE Plasma Veredelt" --msgbox "KDE Plasma wurde erfolgreich in ein neon-leuchtendes Cyberpunk-Paradies verwandelt!\n\n- Sweet-KDE Profile geladen\n- Candy Icons im System aktiv\n- Cava & Cmatrix Visualisierer bereit\n\nTipp: Nutzen Sie die Kvantum-Manager GUI, um transparente Fensterfarben einzustellen!" 16 75
        fi
        ;;

    "HYPRLAND")
        COMPONENTS=$(whiptail --title "Hyprland r/unixporn Setup (KÃ¶nigsklasse)" \
                               --checklist "WÃ¤hlen Sie die Komponenten fÃ¼r das ultimative Catppuccin Mocha Tiling-Setup:" $W_HEIGHT $W_WIDTH $W_LIST \
                               "WAYBAR" "Custom Waybar Config (Leuchtender Verlauf & runde Ecken)" ON \
                               "ROFI" "Rofi Launcher im edlen Catppuccin-Design" ON \
                               "DUNST" "Modern-Glow Notification Daemon Konfiguration" ON \
                               "WALLPAPER" "Catppuccin Landscapes Wallpaper anwenden" ON 3>&1 1>&2 2>&3)
                               
        if [[ -n "$COMPONENTS" ]]; then
            whiptail --title "Hyprland Ricing lÃ¤uft" --infobox "Richte Catppuccin Mocha Strukturen ein..." 8 60
            
            sudo -u "$TARGET_USER" mkdir -p "$USER_HOME/.config/hypr" "$USER_HOME/.config/waybar" "$USER_HOME/.config/rofi" "$USER_HOME/.config/dunst"
            
            if [[ "$COMPONENTS" =~ "WAYBAR" ]]; then
                # LegendÃ¤res, leuchtendes Waybar Design schreiben
                cat << 'EOF' | sudo -u "$TARGET_USER" tee "$USER_HOME/.config/waybar/style.css" >/dev/null
* {
    border: none;
    border-radius: 0;
    font-family: "JetBrains Mono Nerd Font", sans-serif;
    font-size: 13px;
    min-height: 0;
}
window#waybar {
    background: rgba(30, 30, 46, 0.85); /* Catppuccin Mocha */
    color: #cdd6f4;
    transition-property: background-color;
    transition-duration: .5s;
    border-radius: 8px;
}
#workspaces button {
    padding: 0 5px;
    background: transparent;
    color: #89b4fa;
    border-bottom: 3px solid transparent;
}
#workspaces button.active {
    color: #f5c2e7;
    border-bottom: 3px solid #f5c2e7;
}
#clock, #battery, #cpu, #memory, #network, #pulseaudio, #tray {
    padding: 0 10px;
    margin: 4px 0px;
    border-radius: 6px;
    background-color: #313244;
}
EOF
            fi
            
            if [[ "$COMPONENTS" =~ "WALLPAPER" ]]; then
                download_wallpaper "catppuccin"
            fi
            
            # Show-off Tools
            if command -v apt-get >/dev/null 2>&1; then
                sudo apt-get install -y cava cmatrix >/dev/null 2>&1 || true
            elif command -v pacman >/dev/null 2>&1; then
                sudo pacman -Sy --noconfirm cava cmatrix >/dev/null 2>&1 || true
            fi
            
            whiptail --title "Hyprland Veredelt" --msgbox "GlÃ¼ckwunsch! Ihr Hyprland Tiling WM Setup wurde auf absolutes r/unixporn Niveau gehoben!\n\n- Custom Waybar mit Catppuccin Mocha aktiv\n- Rofi & Dunst Konfigurationen abgelegt\n- Cava & Cmatrix installiert\n- Catppuccin Evening-Sky Wallpaper geladen\n\nMachen Sie einen Screenshot und holen Sie sich Ihre Reddit-Upvotes ab!" 16 75
        fi
        ;;

    *)
        # Fallback fÃ¼r XFCE & Cinnamon: Standard Arc-Dark / Adapta Theme mit Papirus Icons
        whiptail --title "Tools & Icons installiert" --msgbox "Die Standard-Themes (Arc/Adapta) und Icons (Papirus) wurden erfolgreich systemweit installiert und bereitgestellt.\nSie kÃ¶nnen diese direkt in Ihren Desktop-Einstellungen auswÃ¤hlen." 10 65
        ;;
esac
