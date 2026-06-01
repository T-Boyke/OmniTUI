#!/usr/bin/env bash
# ==============================================================================
# OmniTUI Module: tools_installer.sh
# Autor: Tobias Boyke
# Zweck: Premium Tools-Installer, ZSH-Plugins, Fastfetch & Terminal Emulatoren TUI
# ==============================================================================

set -euo pipefail

# Lade gemeinsame Variablen und Funktionen
source "$(dirname "$(readlink -f "$0")")/common.sh"
W_LIST=8

TARGET_USER=${SUDO_USER:-root}
USER_HOME=$(eval echo "~$TARGET_USER")

# 1. TUI-Selektionsmenü für die Installationen
CHOICES=$(whiptail --title "Zentraler Tools & Shell-Installer" \
                   --checklist "Wählen Sie die Komponenten aus, die Sie einrichten möchten:" $W_HEIGHT $W_WIDTH $W_LIST \
                   "SYS_TOOLS" "Installiere CLI-Tools (btop, ncdu, micro, bat, ripgrep, fd, fzf, tldr)" ON \
                   "ZSH_SHELL" "ZSH als Standard-Shell & Oh My Zsh aktivieren" ON \
                   "PLUGINS"   "Premium ZSH-Plugins (Highlighting, Suggestions, completions, search tools)" ON \
                   "TERMINALS" "Moderne Terminal-Emulatoren installieren & konfigurieren (Ghostty, Alacritty, Kitty)" ON \
                   "ALIASES"   "Legendäre Admin-Aliases & Shortcuts (ipbrief, fwlist, ports...)" ON \
                   "FASTFETCH" "Legendäres Fastfetch-Branding & System-Dashboard" ON 3>&1 1>&2 2>&3)

if [[ -z "$CHOICES" ]]; then
    exit 0
fi

# 2. System-Tools installieren
if [[ "$CHOICES" =~ "SYS_TOOLS" ]]; then
    whiptail --title "Tools Installation" --infobox "Installiere btop, ncdu, micro, bat, ripgrep, fd, fzf, tldr..." 8 60
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -y >/dev/null
        sudo apt-get install -y btop ncdu micro zsh git curl wget bat ripgrep fd-find fzf tldr >/dev/null
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y epel-release >/dev/null || true
        sudo dnf install -y btop ncdu micro zsh git curl wget bat ripgrep fd fzf tldr >/dev/null
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm btop ncdu micro zsh git curl wget bat ripgrep fd fzf tldr >/dev/null
    fi
    log_success "CLI-Tools installiert."
fi

# 3. ZSH & Oh My Zsh
if [[ "$CHOICES" =~ "ZSH_SHELL" ]]; then
    whiptail --title "ZSH-Aktivierung" --infobox "Richte ZSH als Standard-Shell für $TARGET_USER ein..." 8 60
    zsh_path=$(command -v zsh)
    sudo chsh -s "$zsh_path" "$TARGET_USER"

    ohmyzsh_dir="$USER_HOME/.oh-my-zsh"
    if [[ ! -d "$ohmyzsh_dir" ]]; then
        sudo -u "$TARGET_USER" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended >/dev/null || true
    fi
    log_success "ZSH & Oh My Zsh eingerichtet."
fi

# 4. Premium Plugins
if [[ "$CHOICES" =~ "PLUGINS" ]]; then
    ohmyzsh_dir="$USER_HOME/.oh-my-zsh"
    if [[ -d "$ohmyzsh_dir" ]]; then
        whiptail --title "Premium Plugins" --infobox "Lade erweiterte ZSH-Plugins herunter..." 8 60
        plugin_dir="${ohmyzsh_dir}/custom/plugins"
        sudo -u "$TARGET_USER" mkdir -p "$plugin_dir"

        # Autosuggestions
        if [[ ! -d "$plugin_dir/zsh-autosuggestions" ]]; then
            sudo -u "$TARGET_USER" git clone https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir/zsh-autosuggestions" >/dev/null 2>&1 || true
        fi
        # Syntax Highlighting
        if [[ ! -d "$plugin_dir/zsh-syntax-highlighting" ]]; then
            sudo -u "$TARGET_USER" git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugin_dir/zsh-syntax-highlighting" >/dev/null 2>&1 || true
        fi
        # Completions
        if [[ ! -d "$plugin_dir/zsh-completions" ]]; then
            sudo -u "$TARGET_USER" git clone https://github.com/zsh-users/zsh-completions "$plugin_dir/zsh-completions" >/dev/null 2>&1 || true
        fi
        # History Substring Search
        if [[ ! -d "$plugin_dir/zsh-history-substring-search" ]]; then
            sudo -u "$TARGET_USER" git clone https://github.com/zsh-users/zsh-history-substring-search "$plugin_dir/zsh-history-substring-search" >/dev/null 2>&1 || true
        fi

        # In .zshrc eintragen
        zshrc_file="$USER_HOME/.zshrc"
        if [[ -f "$zshrc_file" ]]; then
            sudo -u "$TARGET_USER" sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions zsh-history-substring-search sudo copypath copyfile colored-man-pages extract web-search command-not-found dirhistory systemd)/' "$zshrc_file"
        fi
        log_success "ZSH-Plugins erfolgreich integriert."
    fi
fi

# 5. Moderne Terminal-Emulatoren & Auto-Config
if [[ "$CHOICES" =~ "TERMINALS" ]]; then
    SELECTED_TERMS=$(whiptail --title "Moderne Terminal-Emulatoren" \
                              --checklist "Wählen Sie die Terminal-Emulatoren zur Installation & Konfiguration aus:" $W_HEIGHT $W_WIDTH $W_LIST \
                              "GHOSTTY" "Ghostty (GPU-beschleunigt, Zig, ultra-modern)" ON \
                              "ALACRITTY" "Alacritty (GPU-beschleunigt, Rust, minimalistisch)" ON \
                              "KITTY" "Kitty (GPU-beschleunigt, feature-reich, Tabs/Images)" ON 3>&1 1>&2 2>&3)
                              
    if [[ -n "$SELECTED_TERMS" ]]; then
        whiptail --title "Terminals werden eingerichtet" --infobox "Installiere und konfiguriere ausgewählte Terminals..." 8 60
        
        # Installationsversuche
        if [[ "$SELECTED_TERMS" =~ "GHOSTTY" ]]; then
            log_info "Bereite Ghostty-Setup vor..."
            if command -v pacman >/dev/null 2>&1; then
                sudo pacman -S --noconfirm ghostty >/dev/null 2>&1 || true
            fi
            
            # Catppuccin Mocha Konfiguration für Ghostty schreiben
            sudo -u "$TARGET_USER" mkdir -p "$USER_HOME/.config/ghostty"
            cat << 'EOF' | sudo -u "$TARGET_USER" tee "$USER_HOME/.config/ghostty/config" >/dev/null
theme = catppuccin-mocha
font-family = "JetBrains Mono"
font-size = 12
window-padding-x = 8
window-padding-y = 8
background-opacity = 0.9
EOF
        fi
        
        if [[ "$SELECTED_TERMS" =~ "ALACRITTY" ]]; then
            log_info "Installiere Alacritty..."
            if command -v apt-get >/dev/null 2>&1; then sudo apt-get install -y alacritty >/dev/null 2>&1 || true;
            elif command -v dnf >/dev/null 2>&1; then sudo dnf install -y alacritty >/dev/null 2>&1 || true;
            elif command -v pacman >/dev/null 2>&1; then sudo pacman -S --noconfirm alacritty >/dev/null 2>&1 || true; fi
            
            # Catppuccin Mocha Konfiguration für Alacritty (TOML) schreiben
            sudo -u "$TARGET_USER" mkdir -p "$USER_HOME/.config/alacritty"
            cat << 'EOF' | sudo -u "$TARGET_USER" tee "$USER_HOME/.config/alacritty/alacritty.toml" >/dev/null
[window]
padding = { x = 8, y = 8 }
opacity = 0.9

[font]
normal = { family = "JetBrains Mono", style = "Regular" }
size = 11.0

[colors.primary]
background = "#1e1e2e" # Catppuccin Mocha Base
foreground = "#cdd6f4" # Text
EOF
        fi
        
        if [[ "$SELECTED_TERMS" =~ "KITTY" ]]; then
            log_info "Installiere Kitty..."
            if command -v apt-get >/dev/null 2>&1; then sudo apt-get install -y kitty >/dev/null 2>&1 || true;
            elif command -v dnf >/dev/null 2>&1; then sudo dnf install -y kitty >/dev/null 2>&1 || true;
            elif command -v pacman >/dev/null 2>&1; then sudo pacman -S --noconfirm kitty >/dev/null 2>&1 || true; fi
            
            # Catppuccin Mocha Konfiguration für Kitty schreiben
            sudo -u "$TARGET_USER" mkdir -p "$USER_HOME/.config/kitty"
            cat << 'EOF' | sudo -u "$TARGET_USER" tee "$USER_HOME/.config/kitty/kitty.conf" >/dev/null
background          #1e1e2e
foreground          #cdd6f4
background_opacity  0.9
font_family         JetBrains Mono
font_size           11.0
window_padding_width 8
EOF
        fi
        log_success "Terminal-Emulatoren und Ricing-Profile wurden erfolgreich eingerichtet."
    fi
fi

# 6. Legendäre Aliases
if [[ "$CHOICES" =~ "ALIASES" ]]; then
    zshrc_file="$USER_HOME/.zshrc"
    if [[ -f "$zshrc_file" ]]; then
        sudo sed -i '/### OmniTUI ADMIN ALIASES ###/,/fastfetch --logo os/d' "$zshrc_file" || true
        
        cat << 'EOF' | sudo -u "$TARGET_USER" tee -a "$zshrc_file" >/dev/null

### OmniTUI ADMIN ALIASES ###
# Netzwerk & Verbindungen
alias ipbrief="ip -br -4 a"
alias fwlist="sudo nft list ruleset"
alias ports="sudo ss -tulpen"
alias checknet="ping -c 3 1.1.1.1"
alias dnsbench="bash $(dirname "$(readlink -f "$0")")/dns_selector.sh"

# Systemdiagnose
alias sysinfo="fastfetch"
alias cpuinfo="lscpu | grep -E 'Model name|Core\(s\) per socket|Socket\(s\)|Thread\(s\) per core|CPU\(s\):'"
alias meminfo="free -h -t"
alias diskusage="ncdu"

# Editoren & Modern CLI-Helpers
alias edit="micro"
alias cls="clear"
alias h="history"
alias help="tldr"

# Dynamische Aliases für modern CLI-Tools (Debian/RHEL/Arch Kompatibilität)
if command -v batcat >/dev/null 2>&1; then alias cat="batcat"; elif command -v bat >/dev/null 2>&1; then alias cat="bat"; fi
if command -v fdfind >/dev/null 2>&1; then alias find="fdfind"; elif command -v fd >/dev/null 2>&1; then alias find="fd"; fi
if command -v rg >/dev/null 2>&1; then alias grep="rg"; fi

# Führe fastfetch beim Login aus
if [ -f ~/.config/fastfetch/config.jsonc ]; then
    fastfetch
else
    fastfetch --logo os
fi
EOF
        log_success "Admin-Aliases erfolgreich eingerichtet."
    fi
fi

# 7. Legendäres Fastfetch-Branding
if [[ "$CHOICES" =~ "FASTFETCH" ]]; then
    whiptail --title "Fastfetch Branding" --infobox "Erstelle legendäres System-Dashboard..." 8 60
    
    FASTFETCH_CONFIG_DIR="$USER_HOME/.config/fastfetch"
    sudo -u "$TARGET_USER" mkdir -p "$FASTFETCH_CONFIG_DIR"
    
    cat << 'EOF' | sudo -u "$TARGET_USER" tee "$FASTFETCH_CONFIG_DIR/config.jsonc" >/dev/null
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        "type": "small",
        "color": {
            "1": "cyan",
            "2": "blue"
        },
        "padding": {
            "top": 2,
            "left": 2
        }
    },
    "display": {
        "separator": "  ➜  ",
        "color": {
            "keys": "cyan",
            "values": "white"
        }
    },
    "modules": [
        "title",
        {
            "type": "custom",
            "format": "┌──────────────────────────────────────────────┐",
            "outputColor": "blue"
        },
        {
            "type": "os",
            "key": "  󰣇 OS",
            "format": "{3} ({12})"
        },
        {
            "type": "kernel",
            "key": "  󰻠 Kernel"
        },
        {
            "type": "uptime",
            "key": "  󱎫 Uptime"
        },
        {
            "type": "packages",
            "key": "  󰏖 Packages"
        },
        {
            "type": "shell",
            "key": "  󱆃 Shell"
        },
        {
            "type": "custom",
            "format": "├────── HARDWARE STATUS ───────────────────────┤",
            "outputColor": "blue"
        },
        {
            "type": "cpu",
            "key": "  󰘚 CPU",
            "format": "{1} ({5} Cores)"
        },
        {
            "type": "memory",
            "key": "  󰍛 Memory",
            "format": "{1} / {2} ({3})"
        },
        {
            "type": "disk",
            "key": "  󰋊 Disk",
            "format": "{1} / {2} ({3})"
        },
        {
            "type": "custom",
            "format": "├────── NETWORK & TOPOLOGY ────────────────────┤",
            "outputColor": "blue"
        },
        {
            "type": "localip",
            "key": "  󰩟 IPv4",
            "showLoop": false
        },
        {
            "type": "dns",
            "key": "  󰅍 DNS"
        },
        {
            "type": "custom",
            "format": "└──────────────────────────────────────────────┘",
            "outputColor": "blue"
        },
        "break",
        "colors"
    ]
}
EOF
    log_success "Fastfetch Branding erfolgreich eingerichtet."
fi

# Abschluss-Meldung
whiptail --title "Setup Komplett" --msgbox "Das Einrichten des TUI-Tools- & Shell-Systems wurde erfolgreich abgeschlossen!" $W_HEIGHT $W_WIDTH
