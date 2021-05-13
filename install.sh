#!/usr/bin/env sh
set -eu #o pipefail

# https://wiki.archlinux.org/title/Installation_guide
# set up partitions for use with chroot

[ "$(hostname)" != archiso ] && exit

CHECK() {
	# "local" is not POSIX-compliant
	echo "$1"
	echo "Proceed? [Y/n]"
	read -r ans </dev/tty
	[ "$ans" = n ] && exit 1
	unset ans
}

# lsblk | grep 'sd. ' | grep -v T | cut -d' ' -f1
DEV=/dev/sda

# https://serverfault.com/a/250845
lsblk
CHECK "All data on $DEV will be irreversibly erased. This cannot be undone."
dd if=/dev/zero of=/dev/sda bs=512 count=1 conv=notrunc

# ls /usr/share/kbd/keymaps/**/*.map.gz
# loadkeys LAYOUT

# the "post-MBR gap" refers to the 2048 kB before the first partition
# fdisk typically leaves it in place
# this script uses MBR / BIOS
# parted -l / ls /sys...

if ls /sys/firmware/efi/efivars; then
	MODE=UEFI
	echo "UEFI mode"
else
	MODE=BIOS
	echo "BIOS mode"
fi

ip link

# https://wiki.archlinux.org/title/Iwd#Connect_to_a_network
# TODO:
# iwctl --passphrase [passphrase] station [device] connect [SSID]
until ping -c 1 archlinux.org; do iwctl; done

timedatectl set-ntp true

fdisk -l $DEV

# typical windows scenario
# sda1: 50 MB (HPFS/NTFS/exFAT)
# sda2: most of the disk
# sda3: 500 MB (Hidden NTFS WinRE)

# RAM should be measured in gigs
RAM=$(free -g | awk '/Mem/ {print $2}')
RAM=$((RAM + 1))

# backup partition table
# sfdisk -d /dev/sda > sda.dump

# BIOS mode is used, root and 8GB swap (no home)
# this is obviously a hacky way to automate fdisk; use at your own risk!
# https://wiki.archlinux.org/title/Partitioning#Partitioning_tools
# https://gist.github.com/tuxfight3r/c640ab9d8eb3806a22b989581bcbed43
# https://www.thegeekstuff.com/2017/05/sfdisk-examples/

# TODO: MBR

CHECK "Will create main partition and $RAM GB swap partition in $DEV"

fdisk "$DEV" <<EOF
n
p
1

-${RAM}G
n
p
2


a
1
t
2
82
p
w
EOF

# lsblk
fdisk -l | grep "$DEV"
CHECK "Wrote partition table"

mkfs.ext4 "${DEV}1"
mkswap "${DEV}2"

mount "${DEV}1" /mnt
swapon "${DEV}2"

reflector

pacstrap /mnt base linux linux-firmware vi vim git networkmanager syslinux sudo

grep "^UUID" /mnt/etc/fstab || genfstab -U /mnt >>/mnt/etc/fstab

echo "Hostname:"
read -r HOSTNAME </dev/tty

USER=joseph

cat <<EOF | arch-chroot /mnt
set -eu #o pipefail

[ "$(pwd)" != /root ] && exit

ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc

sed -i -r '/#en_US/ s|#||' /etc/locale.gen
echo "LANG=en_US.UTF-8" >/etc/locale.conf
locale-gen

echo "$HOSTNAME" >/etc/hostname

echo "127.0.0.1  localhost" >> /etc/hosts
echo "::1        localhost" >> /etc/hosts
echo "127.0.1.1  $HOSTNAME" >> /etc/hosts

mkinitcpio -P

passwd < /dev/tty

mkdir -p /boot/syslinux
cp /usr/lib/syslinux/bios/*.c32 /boot/syslinux/
extlinux --install /boot/syslinux
sed -i -r 's|sda3|sda1|' /boot/syslinux/syslinux.cfg
dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/bios/mbr.bin of=/dev/sda

useradd -m $USER
passwd $USER < /dev/tty
usermod -G wheel $USER

echo '%wheel ALL=(ALL) ALL' | EDITOR='tee -a' visudo
echo "Granted $USER root privileges"
EOF

cat << EOF 
Setup complete.
Reboot into the new system, then clone the repo for post-installation
EOF

sleep 5
reboot now
