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

check_partitions() {
	# bios
	# fdisk -l | grep -qPx "${DEV}p1 \*.+83 Linux"
	# fdisk -l | grep -qPx "${DEV}p2.+ 32G 82 Linux swap / Solaris"

	# uefi
	fdisk -l | grep -qPx "${DEV}p1 \*.+ef EFI \(FAT-12/16/32\)"
	fdisk -l | grep -qPx "${DEV}p2 \*.+83 Linux"
	fdisk -l | grep -qPx "${DEV}p3.+ 32G 82 Linux swap / Solaris"

	return 0
}

if ! check_partitions; then

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

	# TODO: before fdisk, disk must be empty with no partitions. otherwise fdisk
	# commands will be run blindly with no error handling
	#
	# the manual way to delete partitions is to run `d` in fdisk repeatedly, but
	# this is not scriptable
	# https://phoenixnap.com/kb/delete-partition-linux

	# TODO: remove all signatures (otherwise we get extra msg after -XG, currently
	# we just workaround by pressing extra enter)
	# sudo wipefs "$DEV"

	# # bios
	# fdisk "$DEV" <<- EOF
	# 	n # new partition; use all space until last 32GB
	# 	p # primary; note: numeric inputs cannot be commented!
	# 	1
	#
	# 	-${RAM}G
	#
	# 	n
	# 	p
	# 	2
	#
	#
	# 	a # set 1st partition to bootable
	# 	1
	# 	t # set 2nd partition to swap
	# 	2
	# 	82
	# 	p # print
	# 	w # write and exit
	# EOF

	# uefi; my main machine has
	# Device             Start       End   Sectors   Size Type
	# /dev/nvme0n1p1      2048    206847    204800   100M EFI System
	# /dev/nvme0n1p5 768352256 973152255 204800000  97.7G Linux filesystem
	# (p2-p4 = windows)

	fdisk "$DEV" <<- EOF
		n # new partition; use all space until last 32GB
		p # primary; note: numeric inputs cannot be commented!
		1

		+100M

		n 
		p
		2

		-32G
		n
		p
		2


		a # set 1st partition to bootable (not sure if needed)
		1
		t # set 1st partition to type efi
		1
		ef
		t # set 3rd partition to swap
		3
		82
		p # print
		w # write and exit
	EOF

	fdisk -l | grep "$DEV"

	CHECK "Wrote partition table"

	check_partitions

	case $DEV in

	*sd*)
		mkfs.ext4 "${DEV}1"
		mkswap "${DEV}2"
		;;

	*nvme*)
		# 'contains a vfat file system' msg can be ignored?
		# mkfs.ext4 "${DEV}p1"
		# mkswap "${DEV}p2"

		mkfs.fat -F 32 "${DEV}p1" # https://wiki.archlinux.org/title/EFI_system_partition#Format_the_partition
		mkfs.ext4 "${DEV}p2"
		mkswap "${DEV}p3"
		;;

	esac

fi

case $DEV in

*sd*)
	mount "${DEV}1" /mnt
	swapon "${DEV}2"
	;;

*nvme*)
	umount /mnt || :
	swapoff "${DEV}p3" || :

	mount "${DEV}p2" /mnt
	swapon "${DEV}p3"
	;;

esac

# mkdir -p /mnt/etc/pacman.d
curl -s "https://archlinux.org/mirrorlist/?country=DE&protocol=https&ip_version=4&ip_version=6" |
	sed -r 's|^#Server|Server|' > /etc/pacman.d/mirrorlist

# remove community -- https://forum.manjaro.org/t/community-db-failed-to-download-how-do-i-resolve-this/175113
if < /etc/pacman.conf grep -P '^\[community'; then
	sed -i -r '/^\[community/,/Include/d' /etc/pacman.conf
fi

# force keyring update
pacman -Sy --noconfirm archlinux-keyring

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
< /mnt/etc/fstab grep "^UUID" || genfstab -U /mnt >> /mnt/etc/fstab

# TODO: usually i set this to USER, but it should really be the machine name
echo "Hostname:"
read -r HOSTNAME < /dev/tty

USER=joseph
ESP=/boot/EFI

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

# these 2 lines should already be present
# echo "127.0.0.1  localhost" >> /etc/hosts
# echo "::1        localhost" >> /etc/hosts
echo "127.0.1.1  $HOSTNAME" >> /etc/hosts

mkinitcpio -P

echo "Creating root password..."

passwd < /dev/tty

echo "Setting up syslinux bootloader..."

# https://wiki.archlinux.org/title/Syslinux#Manually

# /sys/firmware/efi

# mkdir -p /boot/syslinux
# cp /usr/lib/syslinux/bios/*.c32 /usr/share/syslinux/syslinux.cfg /boot/syslinux
#
# # just reports '/boot/syslinux is /dev/nv...' (?)
# extlinux --install /boot/syslinux 
#
# # copy to bootloader to start of partition
# dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/bios/mbr.bin of=$DEV

# https://wiki.archlinux.org/title/Syslinux#Deployment
mkdir -p $ESP/syslinux
cp -r /usr/lib/syslinux/efi64/* $ESP/syslinux
cp /usr/share/syslinux/syslinux.cfg $ESP/syslinux
efibootmgr --create --disk $(echo "$DEV" | cut -dp -f1) --part $(echo "$DEV" | grep -Po 'p\d') --loader /EFI/syslinux/syslinux.efi --label "Syslinux" --unicode

# i.e.
# efibootmgr --create --disk /dev/nvme0n1 --part p1 --loader /EFI/syslinux/syslinux.efi --label "Syslinux" --unicode
# (hopefully p1 and not 1)

# config should be same, regardless of bios/uefi
# traditionally APPEND root=/dev/...; consider APPEND root=UUID=...
# https://wiki.archlinux.org/title/Syslinux#Chainloading_other_Linux_systems
sed -i -r 's|/dev/sda3|$DEV|' /boot/syslinux/syslinux.cfg

# ^$USER may not work, for some reason
if ! < /etc/passwd /$USER; then
	useradd -G wheel,audio,video -m $USER

	echo "Creating user: $USER"
	passwd $USER < /dev/tty
	# usermod -G wheel $USER

	echo '%wheel ALL=(ALL) ALL' | EDITOR='tee -a' visudo
	echo "Granted $USER root privileges"

fi

if [ ! -d /home/$USER/arch ]; then
	echo "Cloning install scripts..."
	cd /home/$USER
	git clone https://github.com/hejops/arch
fi
EOF

cat << EOF
Setup complete.

Partitions:
$(fdisk -l | grep "$DEV")

# Bootloader:
# $(cat /mnt/boot/syslinux/syslinux.cfg)

fstab:
$(cat /mnt/etc/fstab)

Home:
$(ls /mnt/home/$USER)
EOF

CHECK "The system will now be rebooted. Remove the installation media and ensure Linux boot loader has top priority."
# [Aptio] Boot > UEFI Priorities

umount /mnt # not strictly required
reboot now
