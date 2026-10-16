#!/bin/bash
# This script requires manual editing for your needs - applications, system services, etc.
# After editing, make sure all your Arch partitions are mounted.
# This script is intended to be run only in arch-chroot.
clear
echo -e "\e[31mYou have not edited the script!\e[0m"
echo "If you want to customize it, please install vim/nano. If it is already present - run: vim archauto.sh or nano archauto.sh"
echo "If you want to continue and do not care about editing - press Enter or wait 15 seconds."
read -t 15 -s -p "Press Enter to continue..."
echo ""
# Before starting - install required packages
pacman -Syu grub efibootmgr networkmanager git curl
# Timezone
ln -sf /usr/share/zoneinfo/Europe/Minsk /etc/localtime
hwclock --systohc
# Language - in other words, locale
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
# Hostname
echo "love.gnu" > /etc/hostname
# passwd
passwd
# User account and password (be sure to change user to your nickname)
useradd -mG wheel,audio,video,storage -s /bin/bash user
passwd user
# GRUB
grub-install --efi-directory=/boot/efi --target=x86_64-efi
grub-mkconfig -o /boot/grub/grub.cfg
# NetworkManager
systemctl enable NetworkManager
# Other packages
# Some people want Plasma, some GNOME, some Niri. For you, I commented out the commands to choose.

# 1. KDE
# pacman -S plasma plasma-login-manager && systemctl enable plasmalogin

# 2. GNOME
# pacman -S gnome gdm && systemctl enable gdm

# 3. Niri + Noctalia (with my config)
# pacman -S niri noctalia kitty dolphin sddm && git clone https://github.com/ayonelnx/niri-noctalia-config.git && cd niri-noctalia-config && mkdir -p ~/.config/niri && cp config.kdl ~/.config/niri/config.kdl && systemctl enable sddm
sleep 3
echo "Installation completed successfully"
