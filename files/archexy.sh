#!/bin/bash
# Archexy v1.2
# This script requires manual editing for your needs - applications, system services, etc.
# After editing, make sure all your Arch partitions are mounted.
# This script is intended to be run only in arch-chroot.

# ---- Colors ----
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
LIGHT_BLUE='\033[1;34m'
NC='\033[0m'

# NOTE: don't name this function `info` — it would shadow /usr/bin/info,
# and if the definition is ever missing bash runs GNU info with your
# message as a node name ("no such node"). Use `msg` instead.
msg()     { echo -e "${BOLD}$*${NC}"; }
success() { echo -e "${GREEN}$*${NC}"; }
warn()    { echo -e "${YELLOW}$*${NC}"; }
error()   { echo -e "${RED}$*${NC}"; }

# ---- Clear screen ----
command -v clear >/dev/null 2>&1 && clear

echo -e "${LIGHT_BLUE}Archexy v2.0${NC}"
error "You have not edited the script!"
echo "If you want to customize it, please install vim/nano/micro. If it is already present - run: vim archauto.sh or nano archauto.sh"
echo "If you want to continue and do not care about editing - press Enter or wait 15 seconds."
echo ""

if ! read -r -t 15 -s -p "Press Enter to continue..."; then
    echo ""
    warn "Time is up. Continuing automatically..."
else
    echo ""
fi

# ---- Base packages ----
msg "Installing missing packages."
# libnewt -> whiptail, pciutils -> lspci for GPU detection
pacman -Syu --noconfirm grub efibootmgr networkmanager git curl sudo libnewt pciutils

# ---- Timezone ----
msg "Setting the time zone."
ln -sf /usr/share/zoneinfo/Europe/Minsk /etc/localtime
hwclock --systohc

# ---- Locale ----
msg "Setting the locale."
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# ---- Hostname ----
msg "Setting the hostname."
echo "arch" > /etc/hostname

# ---- Root password ----
msg "Enter your root password, please:"
passwd

# ---- User ----
msg "Enter your account password, please:"
useradd -m -G wheel,audio,video,storage -s /bin/bash user
passwd user

# ---- Sudo (drop-in file instead of editing /etc/sudoers directly) ----
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-wheel-nopasswd
chmod 440 /etc/sudoers.d/10-wheel-nopasswd

# ---- GRUB ----
msg "Installing GRUB."
grub-install --efi-directory=/boot/efi --target=x86_64-efi
grub-mkconfig -o /boot/grub/grub.cfg

# ---- NetworkManager ----
msg "Enabling NetworkManager."
systemctl enable NetworkManager

# ---- Audio: PipeWire ----
msg "Installing audio stack (PipeWire)."
pacman -S --noconfirm \
    pipewire pipewire-alsa pipewire-pulse pipewire-jack \
    wireplumber alsa-utils sof-firmware pavucontrol

# ---- GPU detection & drivers ----
msg "Detecting GPU..."
GPU_INFO=$(lspci 2>/dev/null | grep -iE 'vga|3d|display')
echo "$GPU_INFO"
GPU_LOWER=$(echo "$GPU_INFO" | tr '[:upper:]' '[:lower:]')

INSTALLED_GPU=0

if echo "$GPU_LOWER" | grep -q 'nvidia'; then
    msg "NVIDIA GPU detected. Installing drivers."
    NV_PKGS="nvidia-utils nvidia-settings"
    # Pick driver for whichever kernel(s) are installed
    pacman -Q linux     &>/dev/null && NV_PKGS="$NV_PKGS nvidia"
    pacman -Q linux-lts &>/dev/null && NV_PKGS="$NV_PKGS nvidia-lts"
    pacman -S --noconfirm $NV_PKGS
    INSTALLED_GPU=1
fi

if echo "$GPU_LOWER" | grep -qE 'amd|ati|radeon'; then
    msg "AMD GPU detected. Installing drivers."
    pacman -S --noconfirm \
        mesa xf86-video-amdgpu vulkan-radeon \
        libva-mesa-driver mesa-vdpau
    INSTALLED_GPU=1
fi

if echo "$GPU_LOWER" | grep -q 'intel'; then
    msg "Intel GPU detected. Installing drivers."
    pacman -S --noconfirm mesa vulkan-intel intel-media-driver
    INSTALLED_GPU=1
fi

if [ "$INSTALLED_GPU" -eq 0 ]; then
    warn "No known GPU detected. Installing generic Mesa drivers."
    pacman -S --noconfirm mesa
fi

# ---- DE/WM selection via whiptail ----
CHOICE=$(whiptail --title "Desktop Environment / Window Manager" \
    --menu "Select the desktop environment or window manager to install:" \
    15 70 3 \
    "KDE"   "KDE Plasma + Plasma Login Manager" \
    "GNOME" "GNOME + GDM" \
    "Niri"  "Niri + Noctalia (with preconfigured setup)" \
    3>&1 1>&2 2>&3)

if [ $? -ne 0 ] || [ -z "$CHOICE" ]; then
    error "DE/WM installation cancelled by user."
    echo "You can install a desktop environment manually later."
else
    case "$CHOICE" in
        KDE)
            msg "Installing KDE Plasma..."
            pacman -S --noconfirm plasma plasma-login-manager
            systemctl enable plasmalogin
            ;;
        GNOME)
            msg "Installing GNOME..."
            pacman -S --noconfirm gnome gdm
            systemctl enable gdm
            ;;
        Niri)
            msg "Installing Niri + Noctalia..."
            pacman -S --noconfirm niri noctalia kitty dolphin sddm
            git clone https://github.com/ayonelnx/niri-noctalia-config.git /tmp/niri-config
            mkdir -p /home/user/.config/niri
            cp /tmp/niri-config/config.kdl /home/user/.config/niri/config.kdl
            chown -R user:user /home/user/.config
            rm -rf /tmp/niri-config
            systemctl enable sddm
            ;;
    esac
fi

success "Installation completed successfully!"
echo "You remain in the system to install additional packages. If you do not wish to do so, please run the following commands:"
echo -e "${BOLD}exit${NC}"
echo -e "${BOLD}umount -Rl /mnt${NC}"
echo -e "${BOLD}reboot${NC}"
