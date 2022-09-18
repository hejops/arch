#!/usr/bin/env sh
set -eu

# https://wiki.gentoo.org/wiki/UEFI_Dual_boot_with_Windows_7/8#Create_partitions
# https://www.jbellamydev.com/systemd_boot/
# https://youtube.com/watch?v=LGhifbn6088

# windows disk management
# 100 MB EFI
# x GB C:
# 98 GB unalloc
# 1.7 GB recovery

# fdisk -l
# /dev/nvme0n1p[1-4]: EFI / reserved / basic data (C:) / recovery
# /dev/sda[1-2]: empty / EFI (FAT) -- arch iso

# TODO: no need to fdisk if already partitioned ("No enough free sectors available")

timedatectl set-ntp true

DEV=/dev/nvme0n1
mk_partition() {
	# create linux partition only; no swap, no extra efi
	fdisk "$DEV" << EOF
n



p
w
EOF
}

# TODO: assert only 1 of each
EFI=$(fdisk -l | grep -m1 'EFI System' | awk '{print $1}')
LINUX=$(fdisk -l | grep -m1 'Linux filesystem' | awk '{print $1}')

mkfs.ext4 "$LINUX"

mount "$LINUX" /mnt
reflector --country Germany # not that fast
pacstrap /mnt base linux linux-firmware vi gvim git networkmanager sudo ntfs-3g

# /boot already exists because windows makes it, so arch must be installed there too
mkdir -p /mnt/boot
mount "$EFI" /mnt/boot # mount existing efi partition

grep "^UUID" /mnt/etc/fstab || genfstab -U /mnt >> /mnt/etc/fstab

HOSTNAME=joseph

cat << EOF | arch-chroot /mnt
set -eu

[ "$(pwd)" != / ] && exit

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

echo "Creating user: $USER"

useradd -G wheel,audio,video -m $USER
passwd $USER < /dev/tty

echo '%wheel ALL=(ALL) ALL' | EDITOR='tee -a' visudo
echo "Granted $USER root privileges"

pacman -S --noconfirm efibootmgr os-prober
bootctl install

echo "Cloning install scripts..."
cd /home/joseph
git clone https://github.com/hejops/arch

EOF

exit 0

# TODO: can probably be done before chroot?
cat << EOF > /boot/loader/loader.conf
default arch*
timeout 5
EOF

# https://wiki.archlinux.org/title/systemd-boot#Manual_entry_using_efibootmgr
# https://www.linuxserver.io/blog/2018-05-17-how-to-configure-systemd-boot
# paths are relative to /boot

cat << EOF > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=PARTUUID=$(blkid -s PARTUUID -o value "$LINUX") rw
EOF

cat << EOF > /boot/loader/entries/arch.conf
title Windows
efi /EFI/Microsoft/Boot/bootmgfw.efi
EOF

CHECK "The system will now be rebooted."

reboot now
