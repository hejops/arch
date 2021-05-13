#!/usr/bin/env sh
set -eu #o pipefail

# set up locale, configure bootloader, create user(s)
# this has been subsumed into install.sh, but will be left here for reference
# WARNING: ALL COMMANDS HERE ARE RUN AS ROOT

[ "$(pwd)" != /root ] && exit

# hostname does not work when chrooted

# https://unix.stackexchange.com/a/14346
# [ "$(awk '$5=="/" {print $1}' </proc/1/mountinfo)" != "$(awk '$5=="/" {print $1}' </proc/$$/mountinfo)" ]

ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc

sed -i -r '/#en_US/ s|#||' /etc/locale.gen
echo "LANG=en_US.UTF-8" >/etc/locale.conf
locale-gen

echo "Hostname:"
read -r HOSTNAME < /dev/tty

echo "$HOSTNAME" >/etc/hostname

# localdomain has been omitted
cat <<EOF >/etc/hosts
127.0.0.1  localhost
::1        localhost
127.0.1.1  $HOSTNAME
EOF

mkinitcpio -P

passwd

# syslinux is less of a pain to configure than grub

mkdir -p /boot/syslinux
# omitting the copy gives menu-less boot
cp /usr/lib/syslinux/bios/*.c32 /boot/syslinux/
extlinux --install /boot/syslinux
sed -i -r 's|sda3|sda1|' /boot/syslinx/syslinux.cfg
dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/bios/mbr.bin of=/dev/sda

USER=joseph

useradd -m $USER
passwd $USER
usermod -G wheel $USER

# https://stackoverflow.com/a/28382838
echo '%wheel ALL=(ALL) ALL' | EDITOR='tee -a' visudo

echo "Granted $USER root privileges"
