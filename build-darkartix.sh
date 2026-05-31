#!/bin/bash
set -e

# colors
GREEN="\e[38;5;22m"
RED="\e[31m"
RESET="\e[0m"
log()  { echo -e "${GREEN}==>${RESET} $1"; }
die()  { echo -e "${RED}ERROR:${RESET} $1"; exit 1; }
info() { echo -e "    $1"; }

[[ $EUID -eq 0 ]] && die "run this as a regular user with sudo access, not root"

PROFILE_DIR="/usr/share/artools/iso-profiles/darkartix"
DOTFILES_REPO="https://github.com/CyberDiary2/dotfiles"

echo -e "${GREEN}
  ██████╗  █████╗ ██████╗ ██╗  ██╗ █████╗ ██████╗ ████████╗██╗██╗  ██╗
  ██╔══██╗██╔══██╗██╔══██╗██║ ██╔╝██╔══██╗██╔══██╗╚══██╔══╝██║╚██╗██╔╝
  ██║  ██║███████║██████╔╝█████╔╝ ███████║██████╔╝   ██║   ██║ ╚███╔╝
  ██║  ██║██╔══██║██╔══██╗██╔═██╗ ██╔══██║██╔══██╗   ██║   ██║ ██╔██╗
  ██████╔╝██║  ██║██║  ██║██║  ██╗██║  ██║██║  ██║   ██║   ██║██╔╝ ██╗
  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝╚═╝  ╚═╝
${RESET}"
echo "=== DarkArtix ISO build script ==="
echo ""

# ============================================================
# STEP 1: ensure galaxy repo is enabled
# ============================================================
log "Checking internet connection..."
if ! curl -s --max-time 10 --head https://archlinux.org | grep -q "200\|301\|302"; then
    die "No internet connection. Connect to wifi first then rerun the script."
fi

log "Checking mirrorlist..."
if ! grep -q "^Server" /etc/pacman.d/mirrorlist 2>/dev/null; then
    log "No active servers in mirrorlist -- uncommenting existing ones..."
    sudo sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist
fi

log "Checking Artix repos in pacman.conf..."
if ! grep -q "^\[galaxy\]" /etc/pacman.conf; then
    log "Adding system/world/galaxy repos..."
    sudo tee -a /etc/pacman.conf > /dev/null << 'EOF'

[system]
Include = /etc/pacman.d/mirrorlist

[world]
Include = /etc/pacman.d/mirrorlist

[galaxy]
Include = /etc/pacman.d/mirrorlist
EOF
fi

# ============================================================
# STEP 2: install build dependencies
# ============================================================
sudo pacman -Sy --noconfirm
sudo pacman -S --noconfirm --needed git base-devel imagemagick

log "Installing artools..."
if sudo pacman -S --noconfirm --needed artools 2>/dev/null; then
    log "artools installed from repo."
else
    log "artools not found in repos -- installing from AUR..."
    cd /tmp
    rm -rf artools-aur
    git clone https://aur.archlinux.org/artools.git artools-aur
    cd artools-aur
    makepkg -si --noconfirm
    cd ~
    rm -rf /tmp/artools-aur
fi

# ============================================================
# STEP 3: add blackarch repo
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
    [[ "$sha_confirm" != "yes" ]] && die "SHA1 mismatch -- aborting. Do not run untrusted scripts."

    sudo bash strap.sh
    rm strap.sh
    sudo pacman -Sy --noconfirm
else
    log "BlackArch repo already configured, skipping."
fi

# ============================================================
# STEP 3: create profile directory
# ============================================================
if [[ -d "$PROFILE_DIR" ]]; then
    log "Profile already exists at $PROFILE_DIR"
    read -rp "  Overwrite it? (yes/no): " overwrite
    if [[ "$overwrite" == "yes" ]]; then
        sudo rm -rf "$PROFILE_DIR"
    else
        die "Aborting to preserve existing profile."
    fi
fi

log "Creating ISO profile from base..."
sudo cp -r /usr/share/artools/iso-profiles/base "$PROFILE_DIR"

# ============================================================
# STEP 4: profiledef.sh
# ============================================================
log "Writing profiledef.sh..."
sudo tee "$PROFILE_DIR/profiledef.sh" > /dev/null << 'EOF'
iso_name="darkartix"
iso_label="DARKARTIX_$(date +%Y%m)"
iso_publisher="you"
iso_application="DarkArtix Linux"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito' 'uefi-x64.systemd-boot.esp' 'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
EOF

# ============================================================
# STEP 5: pacman.conf
# ============================================================
log "Writing pacman.conf..."
sudo tee "$PROFILE_DIR/pacman.conf" > /dev/null << 'EOF'
[options]
HoldPkg = pacman glibc
Architecture = auto
SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional

[system]
Include = /etc/pacman.d/mirrorlist

[world]
Include = /etc/pacman.d/mirrorlist

[galaxy]
Include = /etc/pacman.d/mirrorlist

[blackarch]
Include = /etc/pacman.d/blackarch-mirrorlist
EOF

# ============================================================
# STEP 6: packages.x86_64
# ============================================================
log "Writing packages.x86_64..."
sudo tee "$PROFILE_DIR/packages.x86_64" > /dev/null << 'EOF'
# base
base
openrc
eudev
elogind
linux
linux-firmware
grub
efibootmgr
os-prober
sudo
dbus
dbus-openrc

# network
networkmanager
networkmanager-openrc

# ssh
openssh
openssh-openrc

# live tools
archlinux-keyring
artix-keyring
blackarch-keyring
memtest86+

# calamares
calamares
calamares-base-openrc
python
python-yaml

# desktop
xorg-server
xorg-xinit
xfce4
xfce4-terminal
lightdm
lightdm-openrc
lightdm-gtk-greeter
picom
rofi

# theming
papirus-icon-theme
noto-fonts
ttf-jetbrains-mono-nerd
sassc

# plymouth
plymouth
plymouth-openrc

# tools
fastfetch
git
nano
imagemagick

# blackarch tools
nmap
wireshark-qt
burpsuite
metasploit
sqlmap
EOF

# ============================================================
# STEP 7: airootfs directories
# ============================================================
log "Creating airootfs directory structure..."
sudo mkdir -p "$PROFILE_DIR/airootfs/root"
sudo mkdir -p "$PROFILE_DIR/airootfs/etc/calamares/modules"
sudo mkdir -p "$PROFILE_DIR/airootfs/etc/calamares/branding/darkartix"
sudo mkdir -p "$PROFILE_DIR/airootfs/etc/default"
sudo mkdir -p "$PROFILE_DIR/airootfs/etc/lightdm"
sudo mkdir -p "$PROFILE_DIR/airootfs/boot/grub/themes/darkartix"
sudo mkdir -p "$PROFILE_DIR/airootfs/usr/share/plymouth/themes/darkartix"
sudo mkdir -p "$PROFILE_DIR/airootfs/usr/share/darkartix"
sudo mkdir -p "$PROFILE_DIR/airootfs/home/liveuser/Desktop"

# ============================================================
# STEP 8: generate logo with imagemagick
# ============================================================
log "Generating DarkArtix logo..."
convert -size 200x200 xc:'#2d353b' \
    -fill '#a7c080' \
    -font 'DejaVu-Sans-Bold' \
    -pointsize 16 \
    -gravity center \
    -annotate 0 'DarkArtix' \
    /tmp/darkartix-logo.png

sudo cp /tmp/darkartix-logo.png "$PROFILE_DIR/airootfs/etc/calamares/branding/darkartix/logo.png"
sudo cp /tmp/darkartix-logo.png "$PROFILE_DIR/airootfs/usr/share/darkartix/logo.png"
sudo cp /tmp/darkartix-logo.png "$PROFILE_DIR/airootfs/usr/share/plymouth/themes/darkartix/logo.png"
rm /tmp/darkartix-logo.png
info "logo.png created at 200x200 -- replace with a real one later if you want"

# ============================================================
# STEP 9: customize_airootfs.sh
# ============================================================
log "Writing customize_airootfs.sh..."
sudo tee "$PROFILE_DIR/airootfs/root/customize_airootfs.sh" > /dev/null << 'CUSTOMIZE'
#!/bin/bash
set -e

DOTFILES_REPO="https://github.com/CyberDiary2/dotfiles"
DOT_DIR="/tmp/dotfiles"

GREEN="\e[38;5;22m"
RESET="\e[0m"
log() { echo -e "${GREEN}==>${RESET} $1"; }

echo "=== DarkArtix ISO build customization ==="

# users
log "Creating live user..."
useradd -m -G wheel,audio,video,network,storage -s /bin/bash liveuser
echo "liveuser:liveuser" | chpasswd
echo "root:toor" | chpasswd
sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

# services
log "Enabling services..."
rc-update add dbus default
rc-update add elogind default
rc-update add NetworkManager default
rc-update add lightdm default

# lightdm autologin
log "Configuring LightDM autologin..."
sed -i 's/#autologin-user=/autologin-user=liveuser/' /etc/lightdm/lightdm.conf
sed -i 's/#autologin-session=/autologin-session=xfce/' /etc/lightdm/lightdm.conf

# dotfiles
log "Cloning dotfiles..."
git clone --depth 1 "$DOTFILES_REPO" "$DOT_DIR"

# wallpaper
log "Installing wallpaper..."
mkdir -p /usr/share/darkartix
cp "$DOT_DIR/wallpapers/0327.jpg" /usr/share/darkartix/wallpaper.jpg
mkdir -p /etc/skel/wallpapers
cp -r "$DOT_DIR/wallpapers/." /etc/skel/wallpapers/

# copy wallpaper to grub theme and plymouth dirs
cp /usr/share/darkartix/wallpaper.jpg /boot/grub/themes/darkartix/background.png
cp /usr/share/darkartix/wallpaper.jpg /usr/share/plymouth/themes/darkartix/background.png

# everforest gtk theme
log "Installing Everforest GTK theme..."
git clone --depth 1 https://github.com/Fausto-Korpsvart/Everforest-GTK-Theme.git /tmp/everforest
/tmp/everforest/themes/install.sh -c dark -t green -d /usr/share/themes
rm -rf /tmp/everforest

# gtk settings
log "Writing GTK settings..."
mkdir -p /etc/skel/.config/gtk-3.0
cp "$DOT_DIR/gtk-3.0/settings.ini" /etc/skel/.config/gtk-3.0/settings.ini
mkdir -p /etc/skel/.config/gtk-4.0
cat > /etc/skel/.config/gtk-4.0/settings.ini << 'EOF'
[Settings]
gtk-theme-name=Everforest-Green-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Noto Sans 10
gtk-cursor-theme-name=Adwaita
EOF
cp "$DOT_DIR/gtk-2.0/gtkrc-2.0" /etc/skel/.gtkrc-2.0

# lightdm greeter
log "Configuring LightDM greeter..."
cat > /etc/lightdm/lightdm-gtk-greeter.conf << 'EOF'
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

# xfce4 configs
log "Writing XFCE4 configs..."
XFCONF_SKEL="/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "$XFCONF_SKEL"
cp "$DOT_DIR/xfce4/xfconf/xfce-perchannel-xml/"*.xml "$XFCONF_SKEL/"
sed -i 's|/home/drew/wallpapers/0327.jpg|/usr/share/darkartix/wallpaper.jpg|g' \
    "$XFCONF_SKEL/xfce4-desktop.xml"

cat > "$XFCONF_SKEL/xsettings.xml" << 'EOF'
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
    <property name="DPI" type="int" value="-1"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Noto Sans 10"/>
    <property name="MonospaceFontName" type="string" value="Noto Sans Mono 10"/>
    <property name="CursorThemeName" type="string" value="Adwaita"/>
    <property name="CursorThemeSize" type="int" value="0"/>
  </property>
</channel>
EOF

cat > "$XFCONF_SKEL/xfwm4.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Everforest-Green-Dark"/>
    <property name="title_font" type="string" value="Noto Sans Bold 9"/>
    <property name="title_alignment" type="string" value="center"/>
    <property name="button_layout" type="string" value="CMH|"/>
    <property name="use_compositing" type="bool" value="true"/>
    <property name="frame_opacity" type="int" value="100"/>
    <property name="inactive_opacity" type="int" value="100"/>
  </property>
</channel>
EOF

mkdir -p /etc/skel/.config/xfce4/desktop
cp "$DOT_DIR/xfce4/desktop/accels.scm" /etc/skel/.config/xfce4/desktop/
cp "$DOT_DIR/xfce4/desktop/icons.screen0.yaml" /etc/skel/.config/xfce4/desktop/

# picom
log "Installing picom config..."
mkdir -p /etc/skel/.config/picom
cp "$DOT_DIR/picom/picom.conf" /etc/skel/.config/picom/picom.conf

# rofi
log "Installing rofi config..."
mkdir -p /etc/skel/.config/rofi
cp "$DOT_DIR/rofi/config.rasi" /etc/skel/.config/rofi/config.rasi

# tmux
log "Installing tmux config..."
cp "$DOT_DIR/.tmux.conf" /etc/skel/.tmux.conf

# nanorc
log "Installing nanorc..."
cp "$DOT_DIR/nanorc.nanorc" /etc/skel/.nanorc

# autostart
log "Installing autostart entries..."
mkdir -p /etc/skel/.config/autostart
cp "$DOT_DIR/autostart/"*.desktop /etc/skel/.config/autostart/

# fastfetch
log "Writing fastfetch config..."
mkdir -p /etc/skel/.config/fastfetch
cat > /etc/skel/.config/fastfetch/config.jsonc << 'EOF'
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

cat >> /etc/skel/.bashrc << 'EOF'

command -v fastfetch &>/dev/null && fastfetch
EOF

# apply skel to live user
log "Applying configs to live user..."
cp -r /etc/skel/. /home/liveuser/
chown -R liveuser:liveuser /home/liveuser/

# plymouth
log "Setting Plymouth theme..."
plymouth-set-default-theme darkartix
mkinitcpio -p linux

# cleanup
rm -rf "$DOT_DIR"

log "DarkArtix build customization complete."
CUSTOMIZE

sudo chmod +x "$PROFILE_DIR/airootfs/root/customize_airootfs.sh"

# ============================================================
# STEP 10: Plymouth theme
# ============================================================
log "Writing Plymouth theme..."
sudo tee "$PROFILE_DIR/airootfs/usr/share/plymouth/themes/darkartix/darkartix.plymouth" > /dev/null << 'EOF'
[Plymouth Theme]
Name=DarkArtix
Description=DarkArtix boot splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/darkartix
ScriptFile=/usr/share/plymouth/themes/darkartix/darkartix.script
EOF

sudo tee "$PROFILE_DIR/airootfs/usr/share/plymouth/themes/darkartix/darkartix.script" > /dev/null << 'EOF'
wallpaper_image = Image("background.png");
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();
scaled_wallpaper = wallpaper_image.Scale(screen_width, screen_height);
wallpaper_sprite = Sprite(scaled_wallpaper);
wallpaper_sprite.SetZ(-100);

logo_image = Image("logo.png");
logo_sprite = Sprite(logo_image);
logo_sprite.SetX(screen_width / 2 - logo_image.GetWidth() / 2);
logo_sprite.SetY(screen_height / 2 - logo_image.GetHeight() / 2);

progress_box = Rectangle();
progress_box.SetWidth(400);
progress_box.SetHeight(4);
progress_box.SetColor(0.65, 0.75, 0.50, 1.0);

fun BootProgress.Update(time, progress) {
    progress_box.SetX(screen_width / 2 - 200);
    progress_box.SetY(screen_height * 0.75);
    progress_box.SetWidth(400 * progress);
}
EOF

# ============================================================
# STEP 11: GRUB theme
# ============================================================
log "Writing GRUB theme..."
sudo tee "$PROFILE_DIR/airootfs/boot/grub/themes/darkartix/theme.txt" > /dev/null << 'EOF'
desktop-image: "background.png"
desktop-color: "#2d353b"
title-text: ""

+ boot_menu {
    left = 30%
    top = 30%
    width = 40%
    height = 40%
    item_font = "DejaVu Sans Regular 14"
    item_color = "#d3c6aa"
    selected_item_color = "#ffffff"
    item_height = 36
    item_spacing = 4
    scrollbar_width = 4
}

+ label {
    left = 30%
    top = 80%
    width = 40%
    align = "center"
    text = "DarkArtix"
    font = "DejaVu Sans Bold 24"
    color = "#a7c080"
}
EOF

sudo tee "$PROFILE_DIR/airootfs/etc/default/grub" > /dev/null << 'EOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="DarkArtix"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX=""
GRUB_THEME="/boot/grub/themes/darkartix/theme.txt"
GRUB_BACKGROUND="/boot/grub/themes/darkartix/background.png"
EOF

# ============================================================
# STEP 12: Calamares settings.conf
# ============================================================
log "Writing Calamares settings.conf..."
sudo tee "$PROFILE_DIR/airootfs/etc/calamares/settings.conf" > /dev/null << 'EOF'
modules-search: [ local, /usr/lib/calamares/modules ]

sequence:
  - show:
    - welcome
    - locale
    - keyboard
    - partition
    - users
    - summary
  - exec:
    - partition
    - mount
    - unpackfs
    - machineid
    - fstab
    - locale
    - keyboard
    - localecfg
    - users
    - networkcfg
    - hwclock
    - services-openrc
    - packages
    - bootloader
    - umount
  - show:
    - finished

brand: darkartix
prompt-install: false
dont-chroot: false
EOF

# ============================================================
# STEP 13: Calamares branding
# ============================================================
log "Writing Calamares branding..."
sudo tee "$PROFILE_DIR/airootfs/etc/calamares/branding/darkartix/branding.desc" > /dev/null << 'EOF'
componentName: darkartix

welcomeStyleCalamares: false
welcomeExpandingLogo: true

strings:
  productName: DarkArtix
  shortProductName: DarkArtix
  version: 2024
  shortVersion: 2024
  versionedName: DarkArtix 2024
  shortVersionedName: DarkArtix 2024
  bootloaderEntryName: DarkArtix
  productUrl: ""
  supportUrl: ""
  knownIssuesUrl: ""
  releaseNotesUrl: ""

images:
  productLogo: "logo.png"
  productIcon: "logo.png"
  productWelcome: "logo.png"

slideshow: "show.qml"
slideshowAPI: 2

style:
  sidebarBackground: "#2d353b"
  sidebarText: "#d3c6aa"
  sidebarTextSelect: "#ffffff"
  sidebarTextHighlight: "#a7c080"
EOF

sudo tee "$PROFILE_DIR/airootfs/etc/calamares/branding/darkartix/show.qml" > /dev/null << 'EOF'
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Slide {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            color: "#2d353b"
        }
        Text {
            anchors.centerIn: parent
            text: "Installing DarkArtix..."
            color: "#d3c6aa"
            font.pixelSize: 24
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }
}
EOF

# ============================================================
# STEP 14: Calamares modules
# ============================================================
log "Writing Calamares module configs..."

sudo tee "$PROFILE_DIR/airootfs/etc/calamares/modules/services-openrc.conf" > /dev/null << 'EOF'
services:
  - name: dbus
    runlevel: default
  - name: elogind
    runlevel: default
  - name: NetworkManager
    runlevel: default
  - name: lightdm
    runlevel: default
EOF

sudo tee "$PROFILE_DIR/airootfs/etc/calamares/modules/unpackfs.conf" > /dev/null << 'EOF'
unpack:
  - source: "/run/artix/bootmnt/artix/x86_64/airootfs.sfs"
    sourcefs: "squashfs"
    destination: ""
EOF

sudo tee "$PROFILE_DIR/airootfs/etc/calamares/modules/bootloader.conf" > /dev/null << 'EOF'
efiBootloaderId: "darkartix"
kernel: "/boot/vmlinuz-linux"
kernelModulePath: "."
kernelSearchDirs:
  - /boot
grubInstall: "grub-install"
grubMkconfig: "grub-mkconfig"
grubCfg: "/boot/grub/grub.cfg"
grubProbe: "grub-probe"
efiBootMgr: "efibootmgr"
EOF

sudo tee "$PROFILE_DIR/airootfs/etc/calamares/modules/users.conf" > /dev/null << 'EOF'
defaultGroups:
  - name: users
    state: must-exist
  - name: lp
    state: must-exist
  - name: video
    state: must-exist
  - name: network
    state: must-exist
  - name: storage
    state: must-exist
  - name: wheel
    state: must-exist
  - name: audio
    state: must-exist

autologinGroup: autologin
doAutologin: false
sudoersGroup: wheel
setRootPassword: true
doReusePassword: false
passwordRequirements:
  minLength: 6
EOF

# ============================================================
# STEP 15: Calamares desktop launcher
# ============================================================
log "Writing Calamares desktop launcher..."
sudo tee "$PROFILE_DIR/airootfs/home/liveuser/Desktop/install.desktop" > /dev/null << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Install DarkArtix
Comment=Install DarkArtix to disk
Exec=pkexec calamares
Icon=calamares
Terminal=false
Categories=System;
EOF

# ============================================================
# STEP 16: build the ISO
# ============================================================
echo ""
log "All files written. Ready to build."
echo ""
read -rp "  Build the ISO now? this takes 20-60 minutes (yes/no): " build_now

if [[ "$build_now" == "yes" ]]; then
    log "Building DarkArtix ISO..."
    cd /usr/share/artools/iso-profiles
    sudo buildiso -p darkartix -x

    ISO_PATH=$(ls /var/cache/artools/iso/darkartix-*.iso 2>/dev/null | tail -1)
    echo ""
    echo -e "${GREEN}=== Build complete ===${RESET}"
    echo ""
    echo "  ISO: $ISO_PATH"
    echo ""
    echo "  Transfer to your host machine with:"
    echo "    scp builder@<this-vm-ip>:$ISO_PATH ~/Desktop/"
    echo ""
    echo "  Find this VM's IP with: ip addr"
else
    echo ""
    echo "  Profile is ready. Build manually when ready with:"
    echo "    cd /usr/share/artools/iso-profiles"
    echo "    sudo buildiso -p darkartix -x"
    echo ""
    echo "  Output will be at: /var/cache/artools/iso/darkartix-<date>-x86_64.iso"
fi
