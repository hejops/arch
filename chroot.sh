#!/usr/bin/env sh
set -eu #o pipefail

# [ "$(hostname)" != root ] && exit

ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc

locale-gen
sed -i -r '/#en_US/ s|#||' /etc/locale.gen

echo "LANG=en_US.UTF-8" >/etc/locale.conf

# probably won't need most of these, but these were generated by manjaro
# LANG=en_US.UTF-8
# LC_ADDRESS=en_GB.UTF-8
# LC_IDENTIFICATION=en_GB.UTF-8
# LC_MEASUREMENT=en_GB.UTF-8
# LC_MONETARY=en_GB.UTF-8
# LC_NAME=en_GB.UTF-8
# LC_NUMERIC=en_GB.UTF-8
# LC_PAPER=en_GB.UTF-8
# LC_TELEPHONE=en_GB.UTF-8
# LC_TIME=en_GB.UTF-8

HOSTNAME=joseph

echo $HOSTNAME >/etc/hostname

# localdomain has been omitted
cat <<EOF >/etc/hosts
127.0.0.1  localhost
::1        localhost
127.0.1.1  $HOSTNAME
EOF

# Net
# nmtui

mkinitcpio -P

passwd

# maybe not in chroot
# systemctl start NetworkManager.service
# systemctl enable NetworkManager.service

pacman -S grub

grub-install --target=i386-pc /dev/sda

# mkdir -p /boot/grub
grub-mkconfig -o /boot/grub/grub.cfg

exit

# umount -R /mnt
# echo "Rebooting in 5 seconds..."
# sleep 5
# reboot now
