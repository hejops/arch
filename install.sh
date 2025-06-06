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

if [ -d ./tmp ]; then
	# transfer files to another machine on same network. transferring the
	# files back to the machine is an exercise left to the reader

	# mount /dev/nvme0n1p2 /mnt
	local_ip=$(ip a | grep -P 'inet .+wlan0$' | awk '{print $2}' | xargs dirname)
	echo "ip: $local_ip"
	python -m http.server -d ./tmp
fi

# machines usually use nvme (ssd) these days

# if ls /dev/nvme*; then
# 	DEV=$(ls /dev/nvme* | head -n1) # /dev/nvme0
# else
# 	DEV=$(ls /dev/sd* | head -n1) # /dev/sda
# fi

DEV=$(ls /dev/nvme*n* | head -n1 || # /dev/nvme0n1 (not /dev/nvme0)
	ls /dev/sd* | head -n1)            # /dev/sda

# TODO: ensure dev is unmounted?
# ls /mnt/* | head -n1
# umount /mnt

# https://serverfault.com/a/250845
lsblk | grep "$(basename "$DEV")" && {
	CHECK "Disk $DEV is not empty. All data on it will be irreversibly erased before proceeding. This cannot be undone."
	dd if=/dev/zero of="$DEV" bs=512 count=1 conv=notrunc
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

umount /mnt || :
swapon "${DEV}p2" || :

# TODO: before fdisk, disk must be empty with no partitions. otherwise fdisk
# commands will be run blindly with no error handling
#
# the manual way to delete partitions is to run `d` in fdisk repeatedly, but
# this is not scriptable
# https://phoenixnap.com/kb/delete-partition-linux

# TODO: remove all signatures (otherwise we get extra msg after -XG, currently
# we just workaround by pressing extra enter)

fdisk "$DEV" << EOF
n # new partition
p # primary
1 # partition number

-${RAM}G # use all space until last 32GB

n
p
2


a # set 1st partition to bootable
1
t # set 2nd partition to swap
2
82
p # print
w # write and exit
EOF

# lsblk -f

fdisk -l | grep "$DEV"
fdisk -l | grep -qPx "${DEV}p1 \*.+83 Linux"
fdisk -l | grep -qPx "${DEV}p2.+ 32G 82 Linux swap / Solaris"

CHECK "Wrote partition table"

case $DEV in

*sd*)
	mkfs.ext4 "${DEV}1"
	mkswap "${DEV}2"
	swapon "${DEV}2"
	mount "${DEV}1" /mnt
	;;

*nvme*)
	# 'contains a vfat file system' msg can be ignored?
	mkfs.ext4 "${DEV}p1"
	mkswap "${DEV}p2"
	swapon "${DEV}p2"
	mount "${DEV}p1" /mnt
	;;

esac

# mkdir -p /mnt/etc/pacman.d
curl -s "https://archlinux.org/mirrorlist/?country=DE&protocol=https&ip_version=4&ip_version=6" |
	sed -r 's|^#Server|Server|' > /etc/pacman.d/mirrorlist

# TODO: remove community -- https://forum.manjaro.org/t/community-db-failed-to-download-how-do-i-resolve-this/175113
# /etc/pacman.conf

# force keyring update
pacman -Sy archlinux-keyring

# gvim has clipboard support (has('clipboard')), vim-minimal doesn't
# 1.65 GB
pacstrap /mnt base linux linux-firmware vi gvim git networkmanager syslinux sudo

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

# https://wiki.archlinux.org/title/Syslinux#Manually

mkdir -p /boot/syslinux
cp /usr/lib/syslinux/bios/*.c32 /boot/syslinux/

# just reports '/boot/syslinux is /dev/nv...' (?)
extlinux --install /boot/syslinux 

# TODO: is this file supposed to exist?
if [ -f /boot/syslinux/syslinux.cfg ]; then
	sed -i -r 's|sda3|sda1|' /boot/syslinux/syslinux.cfg
fi

# copy to bootloader to start of partition
dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/bios/mbr.bin of=$DEV

echo "Creating user: $USER"

useradd -G wheel,audio,video -m $USER
passwd $USER < /dev/tty
# usermod -G wheel $USER

echo '%wheel ALL=(ALL) ALL' | EDITOR='tee -a' visudo
echo "Granted $USER root privileges"

echo "Cloning install scripts..."

cd /home/$USER
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
