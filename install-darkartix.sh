#!/bin/bash

GREEN="\e[38;5;22m"
RED="\e[31m"
RESET="\e[0m"
log()  { echo -e "${GREEN}==>${RESET} $1"; }
die()  { echo -e "${RED}ERROR:${RESET} $1"; exit 1; }

[[ $EUID -eq 0 ]] && die "run as a regular user with sudo access, not root"

DOTFILES_REPO="https://github.com/CyberDiary2/dotfiles"
DOT_DIR="$HOME/.dotfiles"

echo -e "${GREEN}
  ██████╗  █████╗ ██████╗ ██╗  ██╗ █████╗ ██████╗ ████████╗██╗██╗  ██╗
  ██╔══██╗██╔══██╗██╔══██╗██║ ██╔╝██╔══██╗██╔══██╗╚══██╔══╝██║╚██╗██╔╝
  ██║  ██║███████║██████╔╝█████╔╝ ███████║██████╔╝   ██║   ██║ ╚███╔╝
  ██║  ██║██╔══██║██╔══██╗██╔═██╗ ██╔══██║██╔══██╗   ██║   ██║ ██╔██╗
  ██████╔╝██║  ██║██║  ██║██║  ██╗██║  ██║██║  ██║   ██║   ██║██╔╝ ██╗
  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝╚═╝  ╚═╝
${RESET}"
echo "=== DarkArtix installer ==="
echo ""

# ============================================================
# BLACKARCH REPO
# ============================================================
if ! grep -q "\[blackarch\]" /etc/pacman.conf; then
    log "Adding BlackArch repo..."
    curl -O https://blackarch.org/strap.sh
    ACTUAL_SHA=$(sha1sum strap.sh | awk '{print $1}')
    echo ""
    echo "  BlackArch strap.sh SHA1: ${ACTUAL_SHA}"
    echo "  Verify this matches the SHA1 on blackarch.org before continuing."
    echo ""
    read -rp "  Does the SHA1 match? (yes/no): " sha_confirm
    [[ "$sha_confirm" != "yes" ]] && die "aborting."
    sudo bash strap.sh
    rm strap.sh
else
    log "BlackArch repo already present."
fi

sudo pacman -Sy --noconfirm

# ============================================================
# BASE PACKAGES
# ============================================================
log "Installing base packages..."
sudo pacman -S --noconfirm --needed \
    xfce4 xfce4-goodies \
    xfce4-terminal \
    xfce4-whiskermenu-plugin \
    xfce4-power-manager \
    lightdm lightdm-gtk-greeter \
    networkmanager \
    network-manager-applet \
    bash-completion \
    tmux \
    git curl wget \
    unzip zip p7zip unrar \
    neovim htop tree rsync \
    flameshot fastfetch \
    ranger \
    keepassxc copyq \
    picom rofi \
    papirus-icon-theme \
    conky \
    sassc imagemagick \
    pipewire pipewire-pulse pipewire-alsa wireplumber \
    pavucontrol alsa-utils \
    bluez bluez-utils blueman \
    tlp \
    noto-fonts noto-fonts-emoji noto-fonts-cjk \
    ttf-dejavu ttf-liberation ttf-hack ttf-jetbrains-mono-nerd \
    thunar-archive-plugin \
    mpv vlc \
    zathura zathura-pdf-mupdf \
    proxychains-ng \
    python-pip

# ============================================================
# BLACKARCH TOOLS
# ============================================================
log "Installing BlackArch tools..."
sudo pacman -S --noconfirm --needed \
    nmap sqlmap nikto gobuster ffuf \
    amass whatweb wfuzz \
    tcpdump wireshark-qt \
    hydra masscan openbsd-netcat \
    john hashcat \
    mitmproxy \
    theharvester recon-ng \
    responder impacket seclists \
    commix enum4linux-ng massdns \
    aircrack-ng ettercap kismet \
    binwalk macchanger exploitdb \
    dnsenum cewl reaver socat \
    burpsuite metasploit \
    bloodhound bettercap \
    volatility3 \
    crackmapexec \
    wpscan feroxbuster \
    sublist3r gitleaks sherlock \
    android-tools apktool jadx \
    ghidra medusa \
    nuclei eyewitness \
    proxychains-ng

# ============================================================
# EVERFOREST GTK THEME
# ============================================================
log "Installing Everforest GTK theme..."
if [ ! -d "$HOME/.themes/Everforest-Green-Dark" ]; then
    git clone --depth 1 https://github.com/Fausto-Korpsvart/Everforest-GTK-Theme.git /tmp/everforest
    /tmp/everforest/themes/install.sh -c dark -t green -d "$HOME/.themes"
    sudo mkdir -p /usr/share/themes
    sudo cp -r "$HOME/.themes/Everforest-Green-Dark" /usr/share/themes/
    rm -rf /tmp/everforest
else
    log "Everforest already installed, skipping."
fi

# ============================================================
# DOTFILES
# ============================================================
log "Syncing dotfiles..."
if [ ! -d "$DOT_DIR" ]; then
    git clone "$DOTFILES_REPO" "$DOT_DIR"
else
    git -C "$DOT_DIR" pull
fi

# wallpaper
log "Setting up wallpaper..."
mkdir -p "$HOME/wallpapers"
cp -r --no-clobber "$DOT_DIR/wallpapers/." "$HOME/wallpapers/"
sudo mkdir -p /usr/share/darkartix
sudo cp "$DOT_DIR/wallpapers/0327.jpg" /usr/share/darkartix/wallpaper.jpg

# gtk settings
log "Applying GTK settings..."
mkdir -p "$HOME/.config/gtk-3.0"
cp "$DOT_DIR/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
cp "$DOT_DIR/gtk-2.0/gtkrc-2.0" "$HOME/.gtkrc-2.0"
mkdir -p "$HOME/.config/gtk-4.0"
cat > "$HOME/.config/gtk-4.0/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=Everforest-Green-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Noto Sans 10
gtk-cursor-theme-name=Adwaita
EOF

# xfce4 configs
log "Applying XFCE4 configs..."
XFCONF_DIR="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "$XFCONF_DIR"
cp "$DOT_DIR/xfce4/xfconf/xfce-perchannel-xml/"*.xml "$XFCONF_DIR/"
sed -i "s|/home/drew/wallpapers/0327.jpg|/usr/share/darkartix/wallpaper.jpg|g" \
    "$XFCONF_DIR/xfce4-desktop.xml"
sed -i "s|/home/drew|$HOME|g" "$XFCONF_DIR/xfce4-desktop.xml"

cat > "$XFCONF_DIR/xsettings.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Everforest-Green-Dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
  </property>
  <property name="Xft" type="empty">
    <property name="Antialias" type="int" value="1"/>
    <property name="Hinting" type="int" value="1"/>
    <property name="HintStyle" type="string" value="hintslight"/>
    <property name="RGBA" type="string" value="rgb"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Noto Sans 10"/>
    <property name="MonospaceFontName" type="string" value="Noto Sans Mono 10"/>
    <property name="CursorThemeName" type="string" value="Adwaita"/>
  </property>
</channel>
EOF

cat > "$XFCONF_DIR/xfwm4.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Everforest-Green-Dark"/>
    <property name="title_font" type="string" value="Noto Sans Bold 9"/>
    <property name="title_alignment" type="string" value="center"/>
    <property name="button_layout" type="string" value="CMH|"/>
    <property name="use_compositing" type="bool" value="true"/>
  </property>
</channel>
EOF

mkdir -p "$HOME/.config/xfce4/desktop"
cp "$DOT_DIR/xfce4/desktop/accels.scm" "$HOME/.config/xfce4/desktop/"
cp "$DOT_DIR/xfce4/desktop/icons.screen0.yaml" "$HOME/.config/xfce4/desktop/"

# picom
log "Installing picom config..."
mkdir -p "$HOME/.config/picom"
cp "$DOT_DIR/picom/picom.conf" "$HOME/.config/picom/picom.conf"

# rofi
log "Installing rofi config..."
mkdir -p "$HOME/.config/rofi"
cp "$DOT_DIR/rofi/config.rasi" "$HOME/.config/rofi/config.rasi"

# tmux
cp "$DOT_DIR/.tmux.conf" "$HOME/.tmux.conf"

# nanorc
cp "$DOT_DIR/nanorc.nanorc" "$HOME/.nanorc"

# autostart
mkdir -p "$HOME/.config/autostart"
cp "$DOT_DIR/autostart/"*.desktop "$HOME/.config/autostart/"

# ============================================================
# LIGHTDM
# ============================================================
log "Configuring LightDM..."
sudo tee /etc/lightdm/lightdm-gtk-greeter.conf > /dev/null << 'EOF'
[greeter]
background=/usr/share/darkartix/wallpaper.jpg
theme-name=Everforest-Green-Dark
icon-theme-name=Papirus-Dark
font-name=JetBrainsMono Nerd Font 12
user-background=false
position=50%,center 50%,center
clock-format=%A, %B %d   %H:%M
indicators=~host;~spacer;~clock;~spacer;~session;~power
EOF

# ============================================================
# FASTFETCH (DarkArtix branding)
# ============================================================
log "Writing fastfetch config..."
mkdir -p "$HOME/.config/fastfetch"
cat > "$HOME/.config/fastfetch/config.jsonc" << 'EOF'
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": { "source": "none" },
    "display": {
        "separator": "  ",
        "color": { "keys": "green", "title": "green" }
    },
    "modules": [
        {
            "type": "custom",
            "format": "[38;5;22m\n  ██████╗  █████╗ ██████╗ ██╗  ██╗ █████╗ ██████╗ ████████╗██╗██╗  ██╗\n  ██╔══██╗██╔══██╗██╔══██╗██║ ██╔╝██╔══██╗██╔══██╗╚══██╔══╝██║╚██╗██╔╝\n  ██║  ██║███████║██████╔╝█████╔╝ ███████║██████╔╝   ██║   ██║ ╚███╔╝ \n  ██║  ██║██╔══██║██╔══██╗██╔═██╗ ██╔══██║██╔══██╗   ██║   ██║ ██╔██╗ \n  ██████╔╝██║  ██║██║  ██║██║  ██╗██║  ██║██║  ██║   ██║   ██║██╔╝ ██╗\n  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝╚═╝  ╚═╝\n[0m"
        },
        "break",
        "OS", "Kernel", "Uptime", "Packages", "Shell",
        "DE", "WM", "Terminal", "CPU", "GPU", "Memory",
        "break"
    ]
}
EOF

# add fastfetch to bashrc if not already there
if ! grep -q "fastfetch" "$HOME/.bashrc"; then
    echo "" >> "$HOME/.bashrc"
    echo "command -v fastfetch &>/dev/null && fastfetch" >> "$HOME/.bashrc"
fi

# ============================================================
# APPLY LIVE IF IN A DESKTOP SESSION
# ============================================================
if command -v xfconf-query &>/dev/null && [ -n "$DISPLAY" ]; then
    log "Applying theme live..."
    xfconf-query -c xsettings -p /Net/ThemeName -s "Everforest-Green-Dark" --create -t string
    xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark" --create -t string
    xfconf-query -c xsettings -p /Gtk/FontName -s "Noto Sans 10" --create -t string
    xfconf-query -c xfwm4 -p /general/theme -s "Everforest-Green-Dark" --create -t string
    xfconf-query -c xfce4-desktop -l 2>/dev/null | grep last-image | while read -r path; do
        xfconf-query -c xfce4-desktop -p "$path" -s "/usr/share/darkartix/wallpaper.jpg" 2>/dev/null || true
    done
fi

echo ""
echo -e "${GREEN}=== DarkArtix install complete ===${RESET}"
echo ""
echo "  Log out and back in for all changes to take effect."
echo ""
