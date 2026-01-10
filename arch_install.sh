#!/bin/bash
set -e

read -p 'Root partition: ' root_part
read -p 'ESP partition: ' esp_part
read -p 'Username: ' username
read -p 'User password: ' user_passwd
read -p 'Root password: ' root_passwd
read -p 'Hostname: ' hostname
read -p 'Time zone: ' timezone

BASE_SYSTEM_PACKAGES='base base-devel linux linux-firmware linux-headers efibootmgr bash-completion nano networkmanager'
FONTS='noto-fonts noto-fonts-emoji ttf-jetbrains-mono ttf-fira-code'
USER_PACKAGES='code nvim cq'
FLAGS='--noconfirm --quiet --noprogressbar'

Install() {
    pacstrap /mnt $FLAGS "$@"
}

echo 'Configurating Mirrors...'
reflector --latest 10 --sort rate --save /etc/pacman.d/mirrorlist

echo 'Formating Partitions...'
mkfs.ext4 -F -q -L root /dev/$root_part
mkfs.fat -F32 -q -L boot /dev/$esp_part

echo 'Mounting Partitions...'
mount /dev/$root_part /mnt
mount --mkdir /mnt/boot
mount /dev/$esp_part /mnt/boot

echo 'Installing base system...'
Install $BASE_SYSTEM_PACKAGES

echo 'Installing fonts...'
Install $FONTS

echo 'Installing user packages...'
Install $USER_PACKAGES

echo 'Configurating base system...'
genfstab /mnt > /mnt/etc/fstab
echo -e "en_US.UTF-8 UTF-8\nru_RU.UTF-8 UTF-8" > /mnt/etc/locale.gen
echo 'LANG=en_US.UTF-8' > /mnt/etc/locale.conf
locale-gen

echo 'Configurating in chroot...'
root_uuid=$(lsblk -no UUID /dev/"$root_part")
arch-chroot /mnt /bin/bash << EOF

useradd -m "$username"
echo "$username:$user_passwd" | chpasswd
echo "root:$root_passwd" | chpasswd

systemctl enable NetworkManager
hostnamectl set-hostname "$hostname"
timedatectl set-timezone "$timezone"

bootctl install
cat > /boot/loader/entries/arch.conf << ARCH_EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=PARTUUID=\$root_uuid rw
ARCH_EOF

cat > /boot/loader/loader.conf << LOADER_EOF
default archlinux
timeout 5
editor 0
LOADER_EOF
EOF

read -p 'Done, Reboot? [Y\n] ' agree

umount -R /mnt

if [ ${agree,,} == 'y' ]; then
	reboot
fi
