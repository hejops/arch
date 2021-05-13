#!/usr/bin/env sh
set -eu #o pipefail

[ "$(hostname)" != archiso ] && exit

CHECK() {
	# "local" is not POSIX-compliant
	echo "$1"
	echo "Proceed? [Y/n]"
	read -r ans </dev/tty
	[ "$ans" = n ] && exit 1
	unset ans
}

# https://wiki.archlinux.org/title/Installation_guide

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

fdisk -l

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

# lsblk | grep 'sd. ' | grep -v T | cut -d' ' -f1
DEV=/dev/sda

# TODO: MBR

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

lsblk
fdisk -l | grep "$DEV"
CHECK "Wrote partition table"

mkfs.ext4 "${DEV}1"
mkswap "${DEV}2"

mount "${DEV}1" /mnt
swapon "${DEV}2"

reflector

pacstrap /mnt base linux linux-firmware vim git networkmanager syslinux

grep "^UUID" /mnt/etc/fstab || genfstab -U /mnt >>/mnt/etc/fstab

cat <<EOF
Pre-chroot setup complete
After chroot, run
	git clone https://github.com/hejops/arch
	cd arch
	sh chroot.sh
EOF

arch-chroot /mnt
