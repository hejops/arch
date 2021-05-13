#!/usr/bin/env sh
set -eu #o pipefail

[ "$(pwd)" != /root ] && exit

# hostname does not work when chrooted

# https://unix.stackexchange.com/a/14346
# [ "$(awk '$5=="/" {print $1}' </proc/1/mountinfo)" != "$(awk '$5=="/" {print $1}' </proc/$$/mountinfo)" ]

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

echo "Hostname:"
read -r HOSTNAME < /dev/tty

echo "$HOSTNAME" >/etc/hostname

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

# https://unix.stackexchange.com/a/329954
# produces warning:
# warning: File system `ext2' doesn't support embedding.
# but this can be ignored, allegedly

# # --recheck
# grub-install /dev/sda #|| :
# grub-mkconfig -o /boot/grub/grub.cfg

mkdir -p /boot/syslinux
# omitting the copy gives menu-less boot
cp /usr/lib/syslinux/bios/*.c32 /boot/syslinux/
extlinux --install /boot/syslinux
sed -i -r 's|sda3|sda1|' /boot/syslinx/syslinux.cfg
dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/bios/mbr.bin of=/dev/sda

echo "Setup complete. Exit from chroot, then reboot the system"

# umount -R /mnt
# echo "Rebooting in 5 seconds..."
# sleep 5
# reboot now
