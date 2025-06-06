#!/usr/bin/env sh
set -eu

# configure partitions, locale, timezone, bootloader, account(s), all within
# the archiso image. then reboot and run post.sh.

if ! fdisk -l; then
	echo "Try a different USB port."
	echo "If this error persists, Arch ISO is possibly corrupt."
	exit 1
fi

# hostname not available in archiso
# $USER is root
[ "$(uname -n)" != archiso ] && exit

# https://wiki.archlinux.org/title/Installation_guide
# https://github.com/wincent/wincent/blob/master/contrib/arch-linux/arch-linux-install.sh

# https://wiki.archlinux.org/title/Iwd#Connect_to_a_network
ip link
ping -c 1 archlinux.org > /dev/null
echo "Network OK"

CHECK() {
	# "local" is not POSIX-compliant
	echo "$1"
	echo "Proceed? [Y/n]"
	read -r ans < /dev/tty
	[ "$ans" = n ] && exit 1
	unset ans
}

# lsblk | grep 'sd. ' | grep -v T | cut -d' ' -f1
DEV=/dev/sda

# https://serverfault.com/a/250845
lsblk | grep sda1 && {
	CHECK "Disk $DEV is not empty. All data on it will be irreversibly erased before proceeding. This cannot be undone."
	dd if=/dev/zero of=/dev/sda bs=512 count=1 conv=notrunc
}

# ls /usr/share/kbd/keymaps/**/*.map.gz
# loadkeys LAYOUT

# the "post-MBR gap" refers to the 2048 kB before the first partition
# fdisk typically leaves it in place
# this script uses MBR / BIOS
# parted -l / ls /sys...

timedatectl set-ntp true
timedatectl status

if ls /sys/firmware/efi/efivars; then
	# MODE=UEFI
	echo "UEFI mode"
else
	# MODE=BIOS
	echo "BIOS mode"
fi

fdisk -l "$DEV"

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

CHECK "Will create main partition and $RAM GB swap partition in $DEV"

fdisk "$DEV" << EOF
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
swapon "${DEV}2"

mount "${DEV}1" /mnt

curl -s "https://archlinux.org/mirrorlist/?country=DE&protocol=https&ip_version=4&ip_version=6" |
	sed -r 's|^#Server|Server|' > /mnt/etc/pacman.d/mirrorlist

# reflector

# gvim has clipboard support (has('clipboard')), vim-minimal doesn't
if ! pacstrap /mnt base linux linux-firmware vi gvim git networkmanager syslinux sudo; then
	echo "Newer Arch ISO required"
	exit 1
fi

# TODO: consider noatime?
# https://opensource.com/article/20/6/linux-noatime
#
# "When using Mutt or other applications that need to know if a file has been
# read since the last time it was modified, the noatime option should not be
# used; using the relatime option is acceptable and still provides a
# performance improvement."
# https://wiki.archlinux.org/title/Fstab#atime_options
grep "^UUID" /mnt/etc/fstab || genfstab -U /mnt >> /mnt/etc/fstab

echo "Hostname:"
read -r HOSTNAME < /dev/tty

USER=joseph

cat << EOF | arch-chroot /mnt
set -eu

[ "$(pwd)" != /root ] && exit

echo "Setting up locale..."

ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc

sed -i -r '/#en_US\./ s|#||' /etc/locale.gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
locale-gen

echo "$HOSTNAME" > /etc/hostname

echo "127.0.0.1  localhost" >> /etc/hosts
echo "::1        localhost" >> /etc/hosts
echo "127.0.1.1  $HOSTNAME" >> /etc/hosts

mkinitcpio -P

echo "Creating root password..."

passwd < /dev/tty

echo "Setting up syslinux bootloader..."

mkdir -p /boot/syslinux
cp /usr/lib/syslinux/bios/*.c32 /boot/syslinux/
extlinux --install /boot/syslinux
sed -i -r 's|sda3|sda1|' /boot/syslinux/syslinux.cfg
dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/bios/mbr.bin of=/dev/sda

echo "Creating user: $USER"

useradd -G wheel,audio,video -m $USER
passwd $USER < /dev/tty
# usermod -G wheel $USER

echo '%wheel ALL=(ALL) ALL' | EDITOR='tee -a' visudo
echo "Granted $USER root privileges"

echo "Cloning install scripts..."

cd /home/joseph
git clone https://github.com/hejops/arch
EOF

cat << EOF
Setup complete.

Partitions:
$(fdisk -l | grep "$DEV")

Bootloader:
$(cat /mnt/boot/syslinux/syslinux.cfg)

fstab:
$(cat /mnt/etc/fstab)

Home:
$(ls /mnt/home/$USER)
EOF

CHECK "The system will now be rebooted. Remove the installation media and ensure Linux boot loader has top priority."
# [Aptio] Boot > UEFI Priorities

# umount not strictly required
reboot now
